# Rachel Application Monitoring Setup Guide

This guide covers setting up comprehensive monitoring for the Rachel application in production.

---

## Table of Contents

1. [Monitoring Stack Overview](#monitoring-stack-overview)
2. [Application Metrics](#application-metrics)
3. [Error Tracking with Sentry](#error-tracking-with-sentry)
4. [Log Aggregation](#log-aggregation)
5. [Alerting](#alerting)
6. [Dashboards](#dashboards)
7. [Performance Monitoring](#performance-monitoring)

---

## Monitoring Stack Overview

### Recommended Stack

**Tier 1: Essential (Free/Low Cost)**
- **Sentry** - Error tracking (configured)
- **Health checks** - HTTP endpoint monitoring
- **Docker logs** - Basic logging

**Tier 2: Production (Moderate Cost)**
- **Datadog / New Relic** - APM and metrics
- **Papertrail / Logtail** - Log aggregation
- **PagerDuty / Opsgenie** - Alerting

**Tier 3: Enterprise (Advanced)**
- **Prometheus + Grafana** - Custom metrics
- **ELK Stack** - Log analysis
- **Distributed tracing** - Request flow

This guide covers Tier 1 and Tier 2.

---

## Application Metrics

### Key Metrics to Track

1. **Availability**
   - Uptime percentage
   - Health check status
   - Response time

2. **Performance**
   - Average response time
   - 95th/99th percentile response time
   - Database query time

3. **Usage**
   - Requests per minute
   - Active users
   - Active games

4. **Errors**
   - Error rate
   - 4xx vs 5xx errors
   - Failed requests

5. **Resources**
   - CPU usage
   - Memory usage
   - Disk usage
   - Database connections

### Health Check Monitoring

The `/health` endpoint provides application health status.

**UptimeRobot** (free for basic monitoring):

1. Sign up at https://uptimerobot.com
2. Add HTTP(s) monitor:
   - **Type:** HTTP(s)
   - **URL:** https://yourdomain.com/health
   - **Monitoring Interval:** 5 minutes
   - **Alert Contacts:** Your email/SMS
3. Monitor should expect "200 OK" response

**Pingdom** (paid, more features):

1. Create HTTP check
2. Set URL to https://yourdomain.com/health
3. Configure alerts for downtime
4. Set up status page

**Custom Health Check Script:**

```bash
#!/bin/bash
# health-check-monitor.sh

HEALTH_URL="https://yourdomain.com/health"
ALERT_EMAIL="admin@example.com"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")

if [ "$RESPONSE" != "200" ]; then
    echo "Health check failed with code: $RESPONSE" | \
        mail -s "Rachel Health Check Alert" "$ALERT_EMAIL"

    # Optional: Slack webhook
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"🚨 Rachel health check failed: HTTP $RESPONSE\"}"
    fi
fi
```

Run every 5 minutes:
```bash
*/5 * * * * /opt/rachel/health-check-monitor.sh
```

---

## Error Tracking with Sentry

Already configured in the application. Here's how to use it effectively.

### Setup

1. **Create Sentry Account**
   - Sign up at https://sentry.io
   - Create new project (Elixir/Phoenix)

2. **Get DSN**
   - Go to Settings → Client Keys (DSN)
   - Copy the DSN URL

3. **Configure Application**
   ```bash
   # Set environment variable
   export SENTRY_DSN="https://[key]@[org].ingest.sentry.io/[project]"
   export SENTRY_ENVIRONMENT="production"
   ```

4. **Verify Integration**
   ```bash
   # Test error reporting
   docker-compose exec rachel bin/rachel eval 'Sentry.capture_message("Test from production")'
   ```

### Sentry Best Practices

**1. Set up Release Tracking:**

```bash
# When deploying
export SENTRY_RELEASE=$(git rev-parse --short HEAD)

# In your deployment script
docker-compose exec rachel bin/rachel eval "
  Sentry.Config.put_config(:release, \"$SENTRY_RELEASE\")
"
```

**2. Configure Alerts:**
- Go to Alerts → Create Alert Rule
- Set thresholds:
  - New issue: Immediate notification
  - Error spike: > 100 errors in 1 hour
  - Regression: Previously resolved issue occurs again

**3. User Context:**

The application automatically captures user context in errors. Verify in Sentry dashboard under "User" section.

**4. Performance Monitoring:**

Enable Sentry Performance (additional cost):
```elixir
# config/config.exs
config :sentry,
  enable_source_code_context: true,
  traces_sample_rate: 0.1  # Sample 10% of transactions
```

### Custom Error Capture

```elixir
# In your code
try do
  dangerous_operation()
rescue
  error ->
    Sentry.capture_exception(error,
      stacktrace: __STACKTRACE__,
      extra: %{
        user_id: user_id,
        game_id: game_id,
        context: "processing game action"
      }
    )
    reraise error, __STACKTRACE__
end
```

---

## Log Aggregation

### Option 1: Papertrail (Simple, Affordable)

**Setup:**

1. Sign up at https://papertrailapp.com
2. Get your log destination (e.g., `logs7.papertrailapp.com:12345`)

3. Configure Docker to send logs:

```bash
# /etc/docker/daemon.json
{
  "log-driver": "syslog",
  "log-opts": {
    "syslog-address": "udp://logs7.papertrailapp.com:12345",
    "tag": "rachel-{{.Name}}"
  }
}
```

4. Restart Docker:
```bash
sudo systemctl restart docker
docker-compose restart
```

**Searching Logs:**
- Go to Papertrail dashboard
- Search: `program:rachel` for all app logs
- Save common searches

### Option 2: Datadog (Full APM)

**Setup:**

1. Sign up at https://www.datadoghq.com
2. Get API key

3. Add Datadog agent:

```yaml
# docker-compose.yml
services:
  datadog:
    image: datadog/agent:latest
    environment:
      - DD_API_KEY=${DATADOG_API_KEY}
      - DD_SITE=datadoghq.com
      - DD_LOGS_ENABLED=true
      - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
      - DD_PROCESS_AGENT_ENABLED=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
```

4. Label your containers:

```yaml
  rachel:
    labels:
      com.datadoghq.ad.logs: '[{"source": "elixir", "service": "rachel"}]'
```

### Option 3: Self-Hosted ELK Stack

See `docs/ELK_SETUP.md` for full guide (advanced).

### Structured Logging

The application uses structured logging. Example log format:

```
2025-01-15T10:30:45.123Z [info] method=GET path=/games/123 status=200 duration=45ms user_id=456
```

**Search queries:**
- All errors: `level:error`
- Slow requests: `duration:>1000ms`
- Specific user: `user_id:456`
- Failed auth: `status:401`

---

## Alerting

### Alert Channels

Set up multiple channels for redundancy:

1. **Email** - Primary alerts
2. **SMS** - Critical alerts
3. **Slack** - Team notifications
4. **PagerDuty** - On-call rotation

### Critical Alerts

Configure these alerts (should wake you up):

1. **Application down**
   - Health check fails 3 times in a row
   - No requests in last 5 minutes

2. **Database connection failure**
   - Health check database fails
   - Connection pool exhausted

3. **High error rate**
   - Error rate > 5% of total requests
   - 50+ errors in 1 minute

4. **Disk space critical**
   - Less than 10% free space
   - Less than 5GB free

### Warning Alerts

Configure these for awareness:

1. **High response time**
   - P95 response time > 1 second

2. **Memory usage high**
   - Memory > 80% for 10 minutes

3. **Database slow queries**
   - Queries taking > 5 seconds

4. **Backup failure**
   - Daily backup didn't run
   - Backup verification failed

### Alert Script Example

```bash
#!/bin/bash
# alert.sh - Send alerts via multiple channels

SEVERITY=$1  # critical, warning, info
MESSAGE=$2

# Email
if [ "$SEVERITY" = "critical" ]; then
    echo "$MESSAGE" | mail -s "🚨 CRITICAL: Rachel Alert" admin@example.com
fi

# Slack
if [ -n "$SLACK_WEBHOOK" ]; then
    EMOJI=$([ "$SEVERITY" = "critical" ] && echo "🚨" || echo "⚠️")
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"$EMOJI $MESSAGE\"}"
fi

# PagerDuty (for critical only)
if [ "$SEVERITY" = "critical" ] && [ -n "$PAGERDUTY_KEY" ]; then
    curl -X POST "https://events.pagerduty.com/v2/enqueue" \
        -H 'Content-Type: application/json' \
        -d "{
            \"routing_key\": \"$PAGERDUTY_KEY\",
            \"event_action\": \"trigger\",
            \"payload\": {
                \"summary\": \"$MESSAGE\",
                \"severity\": \"critical\",
                \"source\": \"rachel-monitoring\"
            }
        }"
fi
```

---

## Dashboards

### Simple Status Dashboard

Create a simple status page with:

**index.html:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Rachel Status</title>
    <meta http-equiv="refresh" content="30">
    <style>
        .status { padding: 20px; margin: 10px; border-radius: 5px; }
        .healthy { background: #10b981; color: white; }
        .unhealthy { background: #ef4444; color: white; }
    </style>
</head>
<body>
    <h1>Rachel System Status</h1>
    <div id="status" class="status">Checking...</div>

    <script>
        fetch('/health')
            .then(r => r.json())
            .then(data => {
                const el = document.getElementById('status');
                el.className = 'status ' + (data.status === 'healthy' ? 'healthy' : 'unhealthy');
                el.innerHTML = `
                    <h2>Status: ${data.status}</h2>
                    <p>Last check: ${new Date(data.timestamp).toLocaleString()}</p>
                    <p>Version: ${data.version}</p>
                    <pre>${JSON.stringify(data.checks, null, 2)}</pre>
                `;
            })
            .catch(e => {
                document.getElementById('status').innerHTML = '❌ Offline';
            });
    </script>
</body>
</html>
```

### Grafana Dashboard (Advanced)

If using Prometheus + Grafana:

1. **Install Prometheus Exporter:**

```yaml
# docker-compose.yml
services:
  prometheus-postgres-exporter:
    image: prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:password@postgres:5432/rachel_prod?sslmode=disable"
    ports:
      - "9187:9187"

  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
```

2. **Configure Prometheus** (`prometheus.yml`):

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'rachel-health'
    metrics_path: /health
    static_configs:
      - targets: ['rachel:4000']
```

3. **Import Grafana Dashboard:**
   - Go to Grafana (http://localhost:3000)
   - Import dashboard ID: 9628 (PostgreSQL)
   - Create custom dashboard for Rachel metrics

---

## Performance Monitoring

### Application Performance Monitoring (APM)

**New Relic:**

1. Sign up at https://newrelic.com
2. Add Elixir agent to `mix.exs`:

```elixir
{:new_relic_agent, "~> 1.0"}
```

3. Configure:

```elixir
# config/config.exs
config :new_relic_agent,
  app_name: "Rachel",
  license_key: System.get_env("NEW_RELIC_LICENSE_KEY")
```

**AppSignal (Elixir-specific):**

1. Sign up at https://appsignal.com
2. Add to `mix.exs`:

```elixir
{:appsignal, "~> 2.0"}
{:appsignal_phoenix, "~> 2.0"}
```

3. Configure and deploy

### Custom Metrics

```elixir
# In your code, emit custom telemetry events

:telemetry.execute(
  [:rachel, :game, :action],
  %{duration: duration_ms},
  %{action_type: "play_card", game_id: game_id}
)
```

Then collect in monitoring system.

---

## Monitoring Checklist

### Initial Setup
- [ ] Sentry configured and receiving errors
- [ ] Health check endpoint tested
- [ ] Uptime monitoring configured (UptimeRobot/Pingdom)
- [ ] Log aggregation configured
- [ ] Alert channels configured (email, Slack)
- [ ] Status dashboard accessible

### Weekly Tasks
- [ ] Review Sentry errors
- [ ] Check uptime percentage (should be > 99.9%)
- [ ] Review slow query logs
- [ ] Check disk space
- [ ] Verify backups are running

### Monthly Tasks
- [ ] Review alert thresholds
- [ ] Test alert delivery
- [ ] Review performance trends
- [ ] Update monitoring documentation
- [ ] Audit monitoring costs

### Quarterly Tasks
- [ ] Review monitoring stack effectiveness
- [ ] Update dashboards
- [ ] Conduct incident postmortems
- [ ] Review and update runbooks

---

## Incident Response

When an alert fires:

1. **Acknowledge** - Silence alert, notify team
2. **Assess** - Check dashboards, logs, Sentry
3. **Mitigate** - Restore service (rollback, scale, restart)
4. **Communicate** - Update status page, notify users
5. **Resolve** - Fix root cause
6. **Document** - Write incident report
7. **Learn** - Conduct postmortem, improve monitoring

---

## Cost Optimization

Typical monthly costs for monitoring:

| Service | Free Tier | Paid (Small) | Paid (Medium) |
|---------|-----------|--------------|---------------|
| Sentry | 5K errors/month | $26/mo (50K) | $80/mo (250K) |
| UptimeRobot | 50 monitors | N/A | N/A |
| Papertrail | 100MB/month | $7/mo (1GB) | $25/mo (10GB) |
| Datadog | 14-day trial | $15/host | $23/host |

**Budget recommendation:**
- **Minimum:** $0/mo (Sentry free + UptimeRobot free)
- **Production:** $40-60/mo (Sentry + Papertrail)
- **Enterprise:** $100+/mo (Datadog + PagerDuty)

---

For questions about monitoring setup, check application logs first, then Sentry dashboard, then contact the monitoring service support.
