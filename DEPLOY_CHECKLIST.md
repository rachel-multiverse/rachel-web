# Rachel Deployment Checklist

Quick reference for deploying to production.

---

## Pre-Deploy Checklist

```bash
# 1. Ensure all tests pass
mix test

# 2. Check code formatting
mix format --check-formatted

# 3. Compile without warnings
MIX_ENV=prod mix compile --warnings-as-errors

# 4. Review changes
git diff main

# 5. Check current production status
flyctl status
curl https://your-app.fly.dev/health
```

---

## Deploy to Fly.io

```bash
# Standard deployment (runs migrations automatically)
flyctl deploy

# Watch logs during deployment
flyctl logs

# Verify health after deploy
curl https://your-app.fly.dev/health

# Check status
flyctl status
```

---

## Post-Deploy Verification

```bash
# 1. Health check (should return "healthy")
curl https://your-app.fly.dev/health | jq

# 2. Check Sentry for new errors
# Visit: https://sentry.io

# 3. Test critical paths
# - Visit homepage
# - Create account / login
# - Start a game
# - Play some cards

# 4. Monitor logs for errors
flyctl logs --tail=100
```

---

## If Something Goes Wrong

### Quick Rollback

```bash
# Rollback to previous release
flyctl releases rollback

# Verify rollback worked
curl https://your-app.fly.dev/health
```

### Check What's Wrong

```bash
# View recent logs
flyctl logs --tail=200

# Check Sentry
# Visit your Sentry dashboard

# SSH into instance
flyctl ssh console

# Test database connection
flyctl ssh console -C "app/bin/rachel eval 'Ecto.Adapters.SQL.query(Rachel.Repo, \"SELECT 1\", [])'"
```

---

## Common Deployment Tasks

### Update Environment Variables

```bash
# Set new secret
flyctl secrets set KEY=VALUE

# List current secrets
flyctl secrets list

# Update non-secret env var (edit fly.toml)
vim fly.toml
flyctl deploy
```

### Run Database Migration Manually

```bash
# Migrations run automatically via release_command
# But if you need to run manually:
flyctl ssh console -C "app/bin/rachel eval 'Rachel.Release.migrate'"
```

### Scale Resources

```bash
# Scale to 2 instances
flyctl scale count 2

# Increase memory
flyctl scale memory 1024

# View current scale
flyctl scale show
```

### View Database

```bash
# Connect to Postgres
flyctl postgres connect --app your-postgres-app

# Run queries
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM games;
```

---

## Emergency Procedures

### App is Down

1. Check status: `flyctl status`
2. Check logs: `flyctl logs`
3. Check health: `curl https://your-app.fly.dev/health`
4. If needed: `flyctl releases rollback`

### Database Issues

1. Check Postgres status: `flyctl status --app your-postgres-app`
2. Check connections: `flyctl postgres connect`
3. View activity: `SELECT * FROM pg_stat_activity;`
4. If needed: Scale up database

### High Error Rate

1. Check Sentry dashboard
2. View logs: `flyctl logs | grep -i error`
3. Identify pattern
4. Roll back if critical: `flyctl releases rollback`
5. Fix and redeploy

---

## Monitoring

### Daily

- [ ] Check Sentry for new errors
- [ ] Verify health endpoint: `curl https://your-app.fly.dev/health`
- [ ] Review UptimeRobot status (if configured)

### Weekly

- [ ] Review Fly.io dashboard for resource usage
- [ ] Check database size: `flyctl postgres list`
- [ ] Review slow query logs
- [ ] Verify backups are running

### Monthly

- [ ] Review and optimize costs
- [ ] Check for dependency updates: `mix hex.outdated`
- [ ] Review Sentry error trends
- [ ] Test backup restoration

---

## Useful Commands

```bash
# Deployment
flyctl deploy                          # Deploy
flyctl releases                        # List releases
flyctl releases rollback              # Rollback

# Monitoring
flyctl logs                           # Tail logs
flyctl status                         # App status
flyctl dashboard                      # Web dashboard
curl https://app.fly.dev/health       # Health check

# Scaling
flyctl scale count 2                  # 2 instances
flyctl scale memory 1024              # 1GB RAM
flyctl scale show                     # Current scale

# Database
flyctl postgres connect               # DB console
flyctl postgres backup list           # Backups

# Configuration
flyctl secrets list                   # List secrets
flyctl secrets set KEY=VALUE          # Set secret
flyctl config display                 # Show config
```

---

## Version Control

### Tagging Releases

```bash
# After successful deploy
git tag -a v1.0.1 -m "Release 1.0.1: Bug fixes and improvements"
git push origin v1.0.1

# List tags
git tag -l
```

### Branch Strategy

- `main` - Production (auto-deploys via CI/CD if configured)
- `develop` - Staging (optional)
- `feature/*` - Feature branches

---

## Contact

- **Logs:** `flyctl logs`
- **Health:** `https://your-app.fly.dev/health`
- **Sentry:** `https://sentry.io`
- **Fly Dashboard:** `https://fly.io/dashboard`

---

**Quick Deploy:** `mix test && flyctl deploy && curl https://your-app.fly.dev/health`
