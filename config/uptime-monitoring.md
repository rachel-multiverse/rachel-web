# Uptime Monitoring Guide

This document describes how to set up external uptime monitoring for the Rachel application.

## Health Check Endpoints

The application provides four health check endpoints, each optimized for different monitoring scenarios:

### 1. Basic Health Check: `GET /health`

**Purpose**: Fast availability check with minimal overhead

**Use Cases**:
- Load balancer health checks
- High-frequency monitoring (every 10-30 seconds)
- Quick availability verification
- CDN health probes

**Checks**: None (immediate response)

**Response Example**:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T14:30:00Z",
  "version": "0.1.0"
}
```

**HTTP Status**: Always 200 OK (unless application is completely down)

---

### 2. Legacy Health Check: `GET /health/check`

**Purpose**: Backward-compatible comprehensive check

**Use Cases**:
- Existing monitoring setups
- Docker health checks
- General availability monitoring

**Checks**:
- Database connectivity
- Application configuration
- GameSupervisor running
- PubSub running

**Response Example**:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T14:30:00Z",
  "version": "0.1.0",
  "checks": {
    "database": {"status": "pass"},
    "application": {"status": "pass"},
    "game_supervisor": {"status": "pass"},
    "pubsub": {"status": "pass"}
  }
}
```

**HTTP Status**:
- 200: All checks pass
- 503: One or more checks fail

---

### 3. Readiness Check: `GET /health/ready`

**Purpose**: Verify service is ready to accept traffic

**Use Cases**:
- Kubernetes readiness probes
- Load balancer pool membership
- Post-deployment verification
- Rolling update orchestration

**Checks**:
- Database connectivity
- GameSupervisor running
- PubSub running

**Response Example**:
```json
{
  "status": "ready",
  "timestamp": "2025-01-15T14:30:00Z",
  "checks": {
    "database": {"status": "pass"},
    "game_supervisor": {"status": "pass"},
    "pubsub": {"status": "pass"}
  }
}
```

**HTTP Status**:
- 200: Service is ready
- 503: Service is not ready (don't route traffic)

---

### 4. Liveness Check: `GET /health/live`

**Purpose**: Detect if application is stuck or deadlocked

**Use Cases**:
- Kubernetes liveness probes
- Detecting hung processes
- Triggering container restarts
- Long-running stability monitoring

**Checks**:
- BEAM scheduler responsiveness
- Memory usage within limits (< 2GB)

**Response Example**:
```json
{
  "status": "alive",
  "timestamp": "2025-01-15T14:30:00Z",
  "checks": {
    "scheduler": {"status": "pass"},
    "memory": {"status": "pass"}
  }
}
```

**HTTP Status**:
- 200: Application is alive
- 503: Application appears stuck (restart recommended)

---

## Monitoring Service Setup

### UptimeRobot

Free tier: 50 monitors, 5-minute checks

1. Sign up at https://uptimerobot.com
2. Add New Monitor:
   - **Monitor Type**: HTTP(s)
   - **Friendly Name**: Rachel Production
   - **URL**: `https://your-domain.com/health`
   - **Monitoring Interval**: 5 minutes
   - **Monitor Timeout**: 30 seconds
3. Add Alert Contacts (email, SMS, Slack, webhook)
4. Configure Alert Thresholds:
   - Alert when down
   - Alert after 2 consecutive failures

**Recommended Settings**:
- Use `/health` for primary monitoring
- Add `/health/ready` as a secondary monitor
- Set up status page for public visibility

---

### Pingdom

Commercial service with detailed analytics

1. Sign up at https://www.pingdom.com
2. Create Uptime Check:
   - **Name**: Rachel Production
   - **URL**: `https://your-domain.com/health`
   - **Check Interval**: 1 minute (paid plans)
   - **Locations**: Multiple regions
3. Configure Alerts:
   - Email notifications
   - SMS alerts (premium)
   - PagerDuty integration
4. Set Response Time Alerts:
   - Warning: > 1000ms
   - Critical: > 2000ms

**Advanced Features**:
- Transaction monitoring (multi-step checks)
- Real User Monitoring (RUM)
- Synthetic monitoring from multiple regions

---

### Healthchecks.io

Simple, developer-friendly monitoring

1. Sign up at https://healthchecks.io
2. Create Check:
   - **Name**: Rachel Production
   - **Schedule**: Every 1 minute (Simple Cron: `* * * * *`)
   - **Grace Time**: 1 minute
3. Get the unique ping URL: `https://hc-ping.com/your-uuid`
4. Add integration for notifications (email, Slack, webhook)

**Unique Feature**: The application pings Healthchecks.io instead of being polled

**Implementation**:
```elixir
# In your application, add a periodic task:
defmodule Rachel.Monitoring.HealthchecksPing do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    # Ping every minute
    schedule_ping()
    {:ok, state}
  end

  def handle_info(:ping, state) do
    ping_url = Application.get_env(:rachel, :healthchecks_ping_url)
    if ping_url, do: Req.get(ping_url)
    schedule_ping()
    {:noreply, state}
  end

  defp schedule_ping do
    Process.send_after(self(), :ping, 60_000)
  end
end
```

---

### Better Uptime

Modern monitoring with incident management

1. Sign up at https://betteruptime.com
2. Create Monitor:
   - **URL**: `https://your-domain.com/health`
   - **Check Frequency**: 30 seconds (paid) or 3 minutes (free)
   - **Regions**: Multiple locations
3. Configure On-Call Schedule:
   - Add team members
   - Set escalation policies
   - Configure call rotations
4. Create Status Page:
   - Public visibility
   - Custom domain
   - Incident updates

**Best Features**:
- Beautiful incident reports
- Phone call alerts
- Postmortem templates
- Status page incidents

---

### DataDog

Enterprise APM and monitoring

1. Install DataDog agent on your servers
2. Configure Synthetic Monitoring:
   ```yaml
   # datadog-synthetics.yml
   - name: Rachel Health Check
     type: api
     subtype: http
     config:
       request:
         url: https://your-domain.com/health
         method: GET
       assertions:
         - type: statusCode
           operator: is
           target: 200
         - type: responseTime
           operator: lessThan
           target: 2000
     locations:
       - aws:us-east-1
       - aws:eu-west-1
     options:
       tick_every: 60
       min_failure_duration: 120
   ```

3. Set up Monitors:
   - Availability monitor
   - Response time monitor
   - Error rate monitor

**Integration**: DataDog APM can directly monitor Elixir/Phoenix telemetry

---

## Kubernetes Probes

If deploying to Kubernetes, configure probes in your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rachel-web
spec:
  template:
    spec:
      containers:
      - name: rachel-web
        image: rachel-web:latest
        ports:
        - containerPort: 4000

        # Readiness probe - determines if pod should receive traffic
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 4000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3

        # Liveness probe - determines if pod should be restarted
        livenessProbe:
          httpGet:
            path: /health/live
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3

        # Startup probe - gives application time to start
        startupProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 0
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 30  # 150 seconds max startup time
```

**Probe Guidelines**:
- **Startup Probe**: Use `/health` (fast, no dependencies)
- **Readiness Probe**: Use `/health/ready` (verifies dependencies)
- **Liveness Probe**: Use `/health/live` (detects hangs)

---

## Docker Healthcheck

Add to your `Dockerfile`:

```dockerfile
FROM elixir:1.18-alpine

# ... your build steps ...

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1
```

Or in `docker-compose.yml`:

```yaml
version: '3.8'
services:
  web:
    image: rachel-web:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s
```

---

## Load Balancer Health Checks

### AWS Application Load Balancer (ALB)

```terraform
resource "aws_lb_target_group" "rachel" {
  name     = "rachel-web"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }
}
```

### Google Cloud Load Balancer

```terraform
resource "google_compute_health_check" "rachel" {
  name               = "rachel-health-check"
  check_interval_sec = 30
  timeout_sec        = 5

  http_health_check {
    port         = 4000
    request_path = "/health"
  }
}
```

### DigitalOcean Load Balancer

```hcl
resource "digitalocean_loadbalancer" "rachel" {
  name   = "rachel-lb"
  region = "nyc3"

  healthcheck {
    port                   = 4000
    protocol               = "http"
    path                   = "/health"
    check_interval_seconds = 10
    response_timeout_seconds = 5
    unhealthy_threshold    = 3
    healthy_threshold      = 2
  }
}
```

---

## Monitoring Best Practices

### 1. Use Multiple Monitors

Don't rely on a single monitoring service:
- **Primary**: UptimeRobot or Pingdom (external)
- **Secondary**: Kubernetes probes (internal)
- **Tertiary**: DataDog or New Relic (APM)

### 2. Monitor from Multiple Regions

Check availability from different geographic locations to detect:
- Regional outages
- DNS issues
- CDN problems
- Network routing issues

### 3. Set Appropriate Check Intervals

- **Production critical services**: Every 1-5 minutes
- **Staging environments**: Every 15-30 minutes
- **Development**: No external monitoring needed

### 4. Configure Escalation Policies

1. First alert: Slack notification
2. After 5 minutes: Email primary on-call
3. After 15 minutes: SMS all engineers
4. After 30 minutes: Phone call to management

### 5. Avoid Alert Fatigue

- Don't alert for transient failures (require 2-3 consecutive failures)
- Set up maintenance windows during deployments
- Use different thresholds for warning vs. critical
- Aggregate non-critical alerts into daily digests

### 6. Monitor Response Times

Beyond availability, track:
- Average response time
- 95th percentile response time
- Response time by region

Set alerts:
- Warning: > 1000ms
- Critical: > 2000ms

---

## Troubleshooting

### Health Check Returns 503

**Possible causes**:
1. Database connection pool exhausted
2. GameSupervisor crashed
3. PubSub not running
4. Memory exhausted

**Debug steps**:
```bash
# Check logs
docker logs rachel-web | grep ERROR

# Check database connections
psql -h localhost -U rachel -c "SELECT count(*) FROM pg_stat_activity"

# Check process tree
docker exec rachel-web ps aux

# Check memory usage
docker stats rachel-web
```

### Health Check Times Out

**Possible causes**:
1. Application completely hung
2. Network connectivity issues
3. Load balancer misconfiguration
4. Database connection timeout

**Debug steps**:
```bash
# Try local health check
curl http://localhost:4000/health

# Check if process is running
ps aux | grep beam

# Check network connectivity
nc -zv your-domain.com 4000

# Check firewall rules
iptables -L -n
```

### False Positives

**Possible causes**:
1. Transient network issues
2. Database maintenance
3. Scheduled restarts
4. Check interval too aggressive

**Solutions**:
- Require multiple consecutive failures
- Set up maintenance windows
- Increase check interval
- Use health check timeouts wisely

---

## Cost Comparison

| Service | Free Tier | Paid Plans | Best For |
|---------|-----------|------------|----------|
| UptimeRobot | 50 monitors, 5-min checks | $7/mo for 1-min checks | Small teams, budget-conscious |
| Pingdom | 14-day trial | $10-$72/mo | Enterprise, detailed analytics |
| Healthchecks.io | 20 checks | $5-$80/mo | Developers, cron monitoring |
| Better Uptime | 10 monitors | $18-$69/mo | Modern startups, status pages |
| DataDog | 14-day trial | $15+/host/mo | Enterprise APM, full observability |

---

## Next Steps

1. ✅ Health check endpoints implemented
2. 🔄 Choose external monitoring service
3. 🔄 Configure Kubernetes probes (if applicable)
4. 🔄 Set up Docker healthcheck
5. 🔄 Configure load balancer health checks
6. 🔄 Test failover scenarios
7. 🔄 Document on-call procedures

---

## Support

For questions about health check implementation:
- Check application logs: `docker logs rachel-web`
- Review Phoenix endpoint configuration: `config/runtime.exs`
- Test health checks locally: `curl http://localhost:4000/health`
