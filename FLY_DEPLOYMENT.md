# Rachel Web - Fly.io Deployment Guide

This guide covers deploying Rachel to Fly.io with all production features enabled.

---

## Prerequisites

1. **Fly.io account** - Sign up at https://fly.io
2. **flyctl installed** - Install with: `brew install flyctl`
3. **Logged in** - Run: `flyctl auth login`

---

## First-Time Setup

### 1. Initialize Fly App (If Not Already Done)

```bash
# Navigate to project directory
cd rachel-web

# Launch app (creates fly.toml if needed)
flyctl launch

# When prompted:
# - App name: rachel-web (or your preferred name)
# - Region: Choose closest to your users
# - PostgreSQL: YES
# - Redis: NO (not needed)
```

**Note:** The `fly.toml` in this repo is already configured. If you've already created your app, you can skip the launch and just use the existing config.

### 2. Set Secrets

Set all required secrets (never commit these to git!):

```bash
# Required secrets
flyctl secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
flyctl secrets set PHX_SERVER=true

# Database URL (if not using Fly Postgres, set manually)
# flyctl secrets set DATABASE_URL="ecto://user:pass@host/db"

# Recommended: Error tracking
flyctl secrets set SENTRY_DSN="https://YOUR_KEY@o123456.ingest.sentry.io/789"
flyctl secrets set SENTRY_ENVIRONMENT="production"

# Recommended: Email (for user registration)
flyctl secrets set MAILGUN_API_KEY="your-mailgun-key"
flyctl secrets set MAILGUN_DOMAIN="mg.yourdomain.com"

# Optional: Monitoring
flyctl secrets set APP_VERSION="0.1.0"
```

### 3. Update fly.toml

Update `fly.toml` with your app name and region:

```toml
app = "your-actual-app-name"  # Change this
primary_region = "sjc"         # Or your preferred region

[env]
  PHX_HOST = "your-app.fly.dev"  # Update with actual domain
```

### 4. Attach Fly Postgres

If you created a Postgres database during `flyctl launch`:

```bash
# List your Postgres apps
flyctl postgres list

# Attach to your app
flyctl postgres attach your-postgres-app-name
```

This automatically sets the `DATABASE_URL` secret.

---

## Deployment

### Standard Deployment

```bash
# Deploy to production
flyctl deploy

# View deployment logs
flyctl logs

# Check app status
flyctl status

# Open in browser
flyctl open
```

### First Deployment - Run Migrations

```bash
# After first deploy, run migrations
flyctl ssh console -C "app/bin/rachel eval 'Rachel.Release.migrate'"

# Or use the release_command (already configured in fly.toml)
# Migrations run automatically on each deploy
```

### Verify Deployment

```bash
# Check health endpoint
curl https://your-app.fly.dev/health

# Should return:
# {"status":"healthy","timestamp":"...","version":"0.1.0","checks":{...}}

# Check app is running
flyctl status

# View recent logs
flyctl logs --tail=100
```

---

## Custom Domain Setup

### 1. Add Domain to Fly

```bash
# Add your custom domain
flyctl certs create yourdomain.com
flyctl certs create www.yourdomain.com

# Get DNS instructions
flyctl certs show yourdomain.com
```

### 2. Update DNS

Add the following DNS records:

```
Type: CNAME
Name: yourdomain.com
Value: your-app.fly.dev
TTL: 3600

Type: CNAME
Name: www
Value: your-app.fly.dev
TTL: 3600
```

### 3. Update fly.toml

```toml
[env]
  PHX_HOST = "yourdomain.com"
```

### 4. Redeploy

```bash
flyctl deploy
```

### 5. Verify SSL

```bash
# Check certificate status
flyctl certs list

# Should show "Ready" status
```

---

## Scaling

### Vertical Scaling (More Resources)

```bash
# Scale to 1GB RAM, 1 CPU
flyctl scale memory 1024

# Scale to 2 CPUs
flyctl scale vm shared-cpu-2x

# View current scaling
flyctl scale show
```

### Horizontal Scaling (More Instances)

```bash
# Scale to 2 instances
flyctl scale count 2

# Scale to specific regions
flyctl scale count 2 --region sjc,ord

# View current instances
flyctl status
```

**Recommended for production:**
- Start: 1 instance, 512MB RAM
- Light traffic: 1-2 instances, 1GB RAM
- Medium traffic: 2-3 instances, 2GB RAM

### Database Scaling

```bash
# Scale your Postgres instance
flyctl postgres list
flyctl postgres update your-postgres-app --vm-size shared-cpu-2x
flyctl postgres update your-postgres-app --volume-size 20
```

---

## Monitoring & Debugging

### View Logs

```bash
# Tail logs in real-time
flyctl logs

# Last 200 lines
flyctl logs --tail=200

# Filter by instance
flyctl logs --instance your-app-instance-id
```

### SSH into Instance

```bash
# Open SSH console
flyctl ssh console

# Run Elixir commands
flyctl ssh console -C "app/bin/rachel remote"

# Run one-off commands
flyctl ssh console -C "app/bin/rachel eval 'IO.puts(\"Hello\")'"
```

### Health Check Debugging

```bash
# Check health endpoint
curl https://your-app.fly.dev/health

# View health check status in Fly dashboard
flyctl status

# If health checks are failing:
flyctl logs | grep health
```

### Sentry Integration

Verify Sentry is working:

```bash
# Send test error
flyctl ssh console -C "app/bin/rachel eval 'Sentry.capture_message(\"Test from Fly.io\")'"

# Check Sentry dashboard for the event
```

---

## Database Management

### Backups

Fly Postgres includes automatic daily backups.

```bash
# List backups
flyctl postgres backup list --app your-postgres-app

# Restore from backup
flyctl postgres restore --app your-postgres-app backup-id
```

**Additional backup strategy (recommended):**

```bash
# Create manual backup script on your local machine
# backup-fly.sh

#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backups/rachel_fly_${DATE}.sql.gz"

# Get database credentials
DATABASE_URL=$(flyctl secrets list | grep DATABASE_URL | awk '{print $2}')

# Create backup via fly ssh
flyctl ssh console -C "app/bin/rachel eval '
  {:ok, conn} = Ecto.Adapters.SQL.Repo.pool_size(Rachel.Repo, 1)
  System.cmd(\"pg_dump\", [System.get_env(\"DATABASE_URL\")])
'" | gzip > "$BACKUP_FILE"

echo "Backup created: $BACKUP_FILE"
```

### Running Migrations

Migrations run automatically on deploy via `release_command` in `fly.toml`.

**Manual migration:**

```bash
flyctl ssh console -C "app/bin/rachel eval 'Rachel.Release.migrate'"
```

### Database Console

```bash
# Connect to Postgres
flyctl postgres connect --app your-postgres-app

# Run SQL
\dt  # List tables
SELECT COUNT(*) FROM users;
```

---

## Environment Variables

### View Current Secrets

```bash
# List all secrets (values hidden)
flyctl secrets list

# View non-secret env vars
cat fly.toml | grep -A 10 "\[env\]"
```

### Update Secrets

```bash
# Set/update a secret
flyctl secrets set KEY=VALUE

# Set multiple
flyctl secrets set KEY1=VALUE1 KEY2=VALUE2

# Remove a secret
flyctl secrets unset KEY
```

**Note:** Setting secrets triggers a redeploy.

---

## Cost Optimization

### Free Tier

Fly.io free tier includes:
- Up to 3 shared-cpu-1x VMs (256MB RAM)
- 3GB persistent storage
- 160GB outbound bandwidth

**Rachel requirements for free tier:**
- 1 app instance (512MB) - **Partially covered**
- 1 Postgres instance - **Covered**

**Estimated cost:** $0-5/month (512MB instance is slightly over free tier)

### Production Tier (Recommended)

- 2 app instances (1GB RAM each) - $15/month
- 1 Postgres instance (shared-cpu-1x, 10GB) - $5/month
- **Total:** ~$20/month

### Monitoring Costs

```bash
# Check current usage
flyctl dashboard

# View billing
flyctl billing show
```

---

## Troubleshooting

### App Won't Start

1. **Check logs:**
   ```bash
   flyctl logs
   ```

2. **Common issues:**
   - Missing `SECRET_KEY_BASE` → `flyctl secrets set SECRET_KEY_BASE=...`
   - Missing `DATABASE_URL` → Attach Postgres with `flyctl postgres attach`
   - Missing `PHX_SERVER` → `flyctl secrets set PHX_SERVER=true`

3. **Verify secrets:**
   ```bash
   flyctl secrets list
   ```

### Health Checks Failing

```bash
# Check health endpoint manually
curl https://your-app.fly.dev/health

# View health check logs
flyctl logs | grep health

# Check if app is listening on correct port
flyctl ssh console -C "netstat -tlnp"
```

### Database Connection Issues

```bash
# Verify DATABASE_URL is set
flyctl secrets list | grep DATABASE

# Test database connection
flyctl ssh console -C "app/bin/rachel eval 'Ecto.Adapters.SQL.query(Rachel.Repo, \"SELECT 1\", [])'"

# Check Postgres is running
flyctl status --app your-postgres-app
```

### Slow Response Times

1. **Check instance resources:**
   ```bash
   flyctl status
   flyctl scale show
   ```

2. **Scale up if needed:**
   ```bash
   flyctl scale memory 1024
   ```

3. **Check database performance:**
   ```bash
   flyctl postgres connect --app your-postgres-app
   -- Run: SELECT * FROM pg_stat_activity;
   ```

### Out of Memory

```bash
# Check current memory usage
flyctl ssh console -C "free -m"

# Scale up memory
flyctl scale memory 1024

# Or scale to larger VM
flyctl scale vm shared-cpu-2x
```

---

## CI/CD with GitHub Actions

Already configured! The `.github/workflows/ci.yml` runs tests on every push.

**To add automatic deployment:**

1. **Get Fly API token:**
   ```bash
   flyctl auth token
   ```

2. **Add to GitHub secrets:**
   - Go to repo Settings → Secrets
   - Add `FLY_API_TOKEN` with the token

3. **Update `.github/workflows/ci.yml`:**

```yaml
# Add this job after the test job
deploy:
  name: Deploy to Fly.io
  runs-on: ubuntu-latest
  needs: test  # Only deploy if tests pass
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - uses: superfly/flyctl-actions/setup-flyctl@master

    - name: Deploy to Fly.io
      run: flyctl deploy --remote-only
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

---

## Rollback Procedure

### Quick Rollback

```bash
# List recent releases
flyctl releases

# Rollback to previous version
flyctl releases rollback
```

### Manual Rollback

```bash
# Deploy specific git tag/commit
git checkout v1.0.0
flyctl deploy
git checkout main
```

---

## Production Checklist

Before going live:

- [ ] All secrets set (`flyctl secrets list`)
- [ ] Custom domain configured and SSL ready
- [ ] Health check passing (`curl https://your-app.fly.dev/health`)
- [ ] Database backups configured
- [ ] Sentry receiving errors (send test error)
- [ ] Monitoring set up (UptimeRobot, etc.)
- [ ] Scaled appropriately (at least 2 instances for production)
- [ ] Tested user registration/login flow
- [ ] Load tested (optional but recommended)

---

## Useful Commands Reference

```bash
# Deployment
flyctl deploy                    # Deploy app
flyctl releases                  # View releases
flyctl releases rollback         # Rollback

# Monitoring
flyctl logs                      # View logs
flyctl status                    # App status
flyctl dashboard                 # Open web dashboard

# Scaling
flyctl scale show               # Current scale
flyctl scale count 2            # Scale to 2 instances
flyctl scale memory 1024        # Scale to 1GB RAM

# Database
flyctl postgres connect         # Connect to Postgres
flyctl postgres backup list     # List backups

# Secrets
flyctl secrets list             # List secrets
flyctl secrets set KEY=VALUE    # Set secret
flyctl secrets unset KEY        # Remove secret

# SSH
flyctl ssh console              # Open console
flyctl ssh console -C "cmd"     # Run command

# Configuration
flyctl config display           # Show current config
flyctl config save              # Save config

# Domains
flyctl certs list               # List certificates
flyctl certs create domain.com  # Add domain
```

---

## Support

- **Fly.io Docs:** https://fly.io/docs/
- **Fly.io Community:** https://community.fly.io/
- **Phoenix on Fly:** https://fly.io/docs/elixir/
- **Rachel Docs:** See `DEPLOYMENT.md` for general deployment info

For Rachel-specific issues, check:
1. Application logs (`flyctl logs`)
2. Health endpoint (`curl https://your-app.fly.dev/health`)
3. Sentry dashboard
4. `DEPLOYMENT.md` troubleshooting section

---

**You're all set for Fly.io deployment! 🚀**
