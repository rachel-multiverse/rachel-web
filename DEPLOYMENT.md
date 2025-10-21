# Rachel Web - Production Deployment Guide

This guide covers deploying the Rachel web application to production environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [Deployment Options](#deployment-options)
4. [Health Checks & Monitoring](#health-checks--monitoring)
5. [Database Management](#database-management)
6. [Troubleshooting](#troubleshooting)
7. [Security Checklist](#security-checklist)

---

## Prerequisites

### Required

- **Elixir 1.18+** and **OTP 27+**
- **PostgreSQL 17+** database
- **Domain name** with DNS configured
- **SSL certificate** (Let's Encrypt recommended)
- **Environment secrets** (see Environment Configuration)

### Recommended

- **Monitoring service** (e.g., Sentry for errors)
- **Log aggregation** (e.g., Papertrail, Datadog)
- **Backup solution** for database
- **CDN** for static assets (optional but recommended)

---

## Environment Configuration

### Required Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database connection
DATABASE_URL=ecto://postgres:PASSWORD@host/rachel_prod

# Application secrets (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=<64+ character random string>

# Public hostname
PHX_HOST=yourdomain.com

# Server configuration
PHX_SERVER=true
PORT=4000
RUBP_PORT=1982
```

### Optional Environment Variables

```bash
# Error tracking (highly recommended for production)
SENTRY_DSN=https://...@sentry.io/...
SENTRY_ENVIRONMENT=production

# Email (required for user registration/password reset)
MAILGUN_API_KEY=...
MAILGUN_DOMAIN=...

# Database tuning
POOL_SIZE=10
ECTO_IPV6=false

# Monitoring
APP_VERSION=1.0.0
```

### Generating Secrets

```bash
# Generate SECRET_KEY_BASE
mix phx.gen.secret

# Generate random password
openssl rand -base64 32
```

---

## Deployment Options

### Option 1: Docker Deployment (Recommended)

The application includes a production-ready multi-stage Dockerfile.

#### Build the Image

```bash
docker build -t rachel-web:latest .
```

#### Run with Docker Compose

```bash
# Production docker-compose.prod.yml (create this file)
version: '3.8'

services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: rachel_prod
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: unless-stopped

  rachel:
    image: rachel-web:latest
    ports:
      - "80:4000"
      - "1982:1982"
    environment:
      DATABASE_URL: ${DATABASE_URL}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST}
      PHX_SERVER: true
      SENTRY_DSN: ${SENTRY_DSN}
    depends_on:
      - postgres
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:4000/health"]
      interval: 30s
      timeout: 3s
      retries: 3

volumes:
  postgres_data:
```

```bash
# Deploy
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f rachel

# Run migrations
docker-compose -f docker-compose.prod.yml exec rachel bin/rachel eval "Rachel.Release.migrate"
```

#### Health Check

The Docker container includes a health check that calls `/health` endpoint every 30 seconds.

### Option 2: Elixir Release Deployment

#### Build the Release

```bash
# Set production environment
export MIX_ENV=prod

# Install dependencies
mix deps.get --only prod
mix deps.compile

# Compile assets
mix assets.setup
mix assets.deploy

# Create release
mix release
```

#### Deploy the Release

```bash
# The release will be in _build/prod/rel/rachel/

# Copy to server
scp -r _build/prod/rel/rachel user@server:/opt/rachel

# On server, set environment variables
export DATABASE_URL="..."
export SECRET_KEY_BASE="..."
export PHX_HOST="yourdomain.com"
export PHX_SERVER=true

# Run database migrations
/opt/rachel/bin/rachel eval "Rachel.Release.migrate"

# Start the application
/opt/rachel/bin/rachel start
```

### Option 3: Platform-as-a-Service (PaaS)

#### Fly.io

```bash
# Install flyctl
brew install flyctl

# Login
flyctl auth login

# Launch app
flyctl launch

# Set secrets
flyctl secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
flyctl secrets set DATABASE_URL="..."
flyctl secrets set SENTRY_DSN="..."

# Deploy
flyctl deploy

# Run migrations
flyctl ssh console -C "bin/rachel eval 'Rachel.Release.migrate'"
```

#### Render

1. Create new Web Service in Render dashboard
2. Connect GitHub repository
3. Configure:
   - **Build Command:** `mix deps.get --only prod && mix assets.deploy && mix release`
   - **Start Command:** `_build/prod/rel/rachel/bin/rachel start`
4. Add environment variables in dashboard
5. Deploy

#### Heroku

```bash
# Create app
heroku create rachel-web

# Add PostgreSQL
heroku addons:create heroku-postgresql:standard-0

# Set buildpacks
heroku buildpacks:add hashnuke/elixir
heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static

# Set config
heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret)
heroku config:set PHX_HOST=rachel-web.herokuapp.com
heroku config:set POOL_SIZE=18

# Deploy
git push heroku main

# Run migrations
heroku run "POOL_SIZE=2 bin/rachel eval 'Rachel.Release.migrate'"
```

---

## Health Checks & Monitoring

### Health Check Endpoint

The application provides a comprehensive health check at `/health`:

```bash
curl https://yourdomain.com/health
```

Response when healthy:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T10:30:00Z",
  "version": "0.1.0",
  "checks": {
    "database": {
      "status": "pass"
    },
    "application": {
      "status": "pass"
    }
  }
}
```

Response when unhealthy (503 Service Unavailable):
```json
{
  "status": "unhealthy",
  "timestamp": "2025-01-15T10:30:00Z",
  "version": "0.1.0",
  "checks": {
    "database": {
      "status": "fail"
    },
    "application": {
      "status": "pass"
    }
  }
}
```

### Configure Load Balancer Health Checks

**AWS Application Load Balancer:**
```
Health Check Path: /health
Health Check Port: 4000
Healthy Threshold: 2
Unhealthy Threshold: 3
Timeout: 5 seconds
Interval: 30 seconds
Success Codes: 200
```

**Kubernetes Liveness Probe:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 3
  failureThreshold: 3
```

### Sentry Error Tracking

Errors are automatically sent to Sentry when configured:

1. Create project at https://sentry.io
2. Get DSN from project settings
3. Set environment variable: `SENTRY_DSN=https://...`
4. Errors will appear in Sentry dashboard with full context

**Manual error capture:**
```elixir
Sentry.capture_message("Something went wrong", extra: %{user_id: user_id})
Sentry.capture_exception(exception, stacktrace: __STACKTRACE__)
```

### Application Monitoring

**Phoenix LiveDashboard** (development only):
- Available at: `/dev/dashboard` (dev environment only)
- Shows metrics, processes, performance data
- **Do NOT expose in production** without authentication

**Telemetry Metrics:**

The app emits telemetry events for:
- HTTP requests
- Database queries
- LiveView events
- Game state changes

You can send these to external monitoring (Datadog, New Relic, etc.)

---

## Database Management

### Running Migrations

**Docker:**
```bash
docker-compose exec rachel bin/rachel eval "Rachel.Release.migrate"
```

**Elixir Release:**
```bash
/opt/rachel/bin/rachel eval "Rachel.Release.migrate"
```

**Manual Migration Creation:**
```bash
mix ecto.gen.migration add_new_feature
mix ecto.migrate
```

### Database Backups

#### Automated Backup Script

```bash
#!/bin/bash
# backup.sh - Daily database backups

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/rachel_$DATE.sql.gz"

# Create backup
docker-compose exec -T postgres pg_dump -U postgres rachel_prod | gzip > "$BACKUP_FILE"

# Keep only last 30 days
find $BACKUP_DIR -name "rachel_*.sql.gz" -mtime +30 -delete

echo "Backup created: $BACKUP_FILE"
```

Add to crontab:
```bash
0 2 * * * /path/to/backup.sh
```

#### Restore from Backup

```bash
# Stop application
docker-compose stop rachel

# Restore database
gunzip -c /backups/rachel_20250115_020000.sql.gz | \
  docker-compose exec -T postgres psql -U postgres rachel_prod

# Start application
docker-compose start rachel
```

#### Backup to S3 (AWS)

```bash
#!/bin/bash
# backup-to-s3.sh

BUCKET="s3://my-bucket/rachel-backups"
DATE=$(date +%Y%m%d_%H%M%S)

docker-compose exec -T postgres pg_dump -U postgres rachel_prod | \
  gzip | \
  aws s3 cp - "$BUCKET/rachel_$DATE.sql.gz"
```

### Database Connection Pooling

The application uses connection pooling configured by `POOL_SIZE` environment variable.

**Recommended pool sizes:**
- **Small (1-5 concurrent users):** 10
- **Medium (5-50 concurrent users):** 20
- **Large (50+ concurrent users):** 50+

**Formula:** `POOL_SIZE = (number of web servers) × (pool size per server) ≤ (database max connections - 10)`

Example: 3 servers × 20 pool size = 60 total connections (leave room for admin connections)

---

## Troubleshooting

### Application Won't Start

**Check logs:**
```bash
docker-compose logs -f rachel
# or
journalctl -u rachel -f
```

**Common issues:**

1. **Missing environment variables:**
   ```
   Error: environment variable DATABASE_URL is missing
   ```
   Solution: Set required env vars in `.env` or docker-compose.yml

2. **Database connection failure:**
   ```
   Error: could not connect to database
   ```
   Solution: Check DATABASE_URL, ensure PostgreSQL is running

3. **Port already in use:**
   ```
   Error: failed to bind to port 4000
   ```
   Solution: Change PORT env var or stop conflicting service

### Health Check Failing

```bash
# Test health endpoint directly
curl http://localhost:4000/health

# Check if database is accessible
docker-compose exec postgres pg_isready

# Check application logs
docker-compose logs rachel | grep -i error
```

### High Memory Usage

Phoenix applications are generally memory-efficient, but check:

1. **Too many game processes:** Check game cleanup task is running
2. **Large connection pool:** Reduce POOL_SIZE
3. **Memory leak:** Check Sentry for errors, update dependencies

### Slow Response Times

1. **Check database query performance:**
   ```sql
   -- Enable slow query logging in PostgreSQL
   ALTER DATABASE rachel_prod SET log_min_duration_statement = 1000;
   ```

2. **Check connection pool exhaustion:**
   Look for "db connection checkout timeout" errors

3. **Add database indexes** if queries are slow

### SSL/TLS Issues

Ensure `force_ssl: [hsts: true]` is configured in `config/runtime.exs`.

If using a reverse proxy (nginx, etc.), configure X-Forwarded-Proto header:
```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

---

## Security Checklist

Before deploying to production:

### Application Security

- [ ] `SECRET_KEY_BASE` is randomly generated (64+ characters)
- [ ] `SECRET_KEY_BASE` is different from development
- [ ] All environment variables are set (see `.env.example`)
- [ ] HTTPS is enforced (`force_ssl` configured)
- [ ] HSTS header is enabled (production only)
- [ ] CSP headers are configured with nonces
- [ ] Rate limiting is active on auth endpoints
- [ ] Sentry error tracking is configured

### Database Security

- [ ] PostgreSQL password is strong and unique
- [ ] Database is not publicly accessible (firewall rules)
- [ ] SSL is enabled for database connections
- [ ] Regular backups are configured
- [ ] Backup restoration has been tested

### Infrastructure Security

- [ ] Firewall allows only ports 80, 443, and SSH
- [ ] SSH key authentication only (no password auth)
- [ ] Operating system is updated
- [ ] Docker images are from trusted sources
- [ ] Container runs as non-root user (Dockerfile already configured)

### Monitoring & Operations

- [ ] Health check endpoint is working
- [ ] Load balancer health checks are configured
- [ ] Sentry is receiving error reports
- [ ] Log aggregation is configured
- [ ] Alerts are set up for critical errors
- [ ] Backup monitoring/alerting is configured

### Testing

- [ ] All tests pass: `mix test`
- [ ] Production build succeeds: `MIX_ENV=prod mix release`
- [ ] Health check works in production build
- [ ] Database migrations run successfully
- [ ] Rollback procedure has been tested

---

## Production Deployment Workflow

### Standard Deployment Process

1. **Test locally:**
   ```bash
   mix test
   mix format --check-formatted
   mix compile --warnings-as-errors
   ```

2. **Update version** in `mix.exs`

3. **Commit and tag:**
   ```bash
   git add .
   git commit -m "Release v1.0.1"
   git tag v1.0.1
   git push origin main --tags
   ```

4. **Build release:**
   ```bash
   docker build -t rachel-web:v1.0.1 .
   docker tag rachel-web:v1.0.1 rachel-web:latest
   ```

5. **Deploy to staging** (if available)

6. **Run migrations:**
   ```bash
   docker-compose exec rachel bin/rachel eval "Rachel.Release.migrate"
   ```

7. **Deploy to production**

8. **Verify:**
   ```bash
   curl https://yourdomain.com/health
   ```

9. **Monitor** Sentry and logs for errors

### Rollback Procedure

If deployment fails:

```bash
# Revert to previous Docker image
docker-compose stop rachel
docker-compose up -d rachel-web:v1.0.0

# Or revert database migration (if needed)
docker-compose exec rachel bin/rachel eval "Rachel.Release.rollback"
```

---

## Support & Resources

- **Application logs:** Check Docker logs or systemd journal
- **Error tracking:** Check Sentry dashboard
- **Database issues:** Check PostgreSQL logs
- **Phoenix guides:** https://hexdocs.pm/phoenix
- **Deployment guides:** https://hexdocs.pm/phoenix/deployment.html

---

## Next Steps

1. Set up continuous deployment (CD) pipeline
2. Configure log aggregation
3. Set up application performance monitoring (APM)
4. Create runbook for common operational tasks
5. Load test the application
6. Set up staging environment

For questions or issues, check the logs first, then Sentry, then create an issue in the project repository.
