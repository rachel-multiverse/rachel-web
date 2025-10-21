# Database Backup and Monitoring Guide

## Overview

This guide covers comprehensive database backup strategies, monitoring, and disaster recovery procedures for the Rachel application.

---

## Table of Contents

1. [Backup Strategies](#backup-strategies)
2. [Automated Backup Scripts](#automated-backup-scripts)
3. [Backup Verification](#backup-verification)
4. [Restore Procedures](#restore-procedures)
5. [Database Monitoring](#database-monitoring)
6. [Performance Tuning](#performance-tuning)
7. [Disaster Recovery](#disaster-recovery)

---

## Backup Strategies

### The 3-2-1 Backup Rule

- **3** copies of your data
- **2** different storage media
- **1** offsite backup

### Backup Types

#### 1. Continuous Backups (WAL Archiving)

PostgreSQL Write-Ahead Logging for point-in-time recovery.

**Configuration** (`postgresql.conf`):
```ini
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /mnt/wal_archive/%f && cp %p /mnt/wal_archive/%f'
archive_timeout = 300  # Force archive every 5 minutes
```

**Benefits:**
- Minimal data loss (up to 5 minutes)
- Point-in-time recovery
- Continuous protection

**Drawbacks:**
- Requires more storage
- More complex restore process

#### 2. Daily Full Backups

Complete database dumps every day.

**Benefits:**
- Simple to restore
- Complete snapshot
- Easy to understand

**Drawbacks:**
- Data loss up to 24 hours
- Can be slow for large databases

#### 3. Incremental Backups

Use tools like pgBackRest or Barman for incremental backups.

---

## Automated Backup Scripts

### Daily Backup Script (Docker)

Create `/opt/rachel/backup.sh`:

```bash
#!/bin/bash
# Rachel Database Backup Script
# Schedule with cron: 0 2 * * * /opt/rachel/backup.sh

set -e

# Configuration
BACKUP_DIR="/backups/rachel"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/rachel_${DATE}.sql.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Log start
echo "[$(date)] Starting backup..." >> "$LOG_FILE"

# Create backup
if docker-compose exec -T postgres pg_dump \
    -U postgres \
    -d rachel_prod \
    --format=custom \
    --compress=9 \
    --verbose \
    2>> "$LOG_FILE" | gzip > "$BACKUP_FILE"; then

    echo "[$(date)] Backup successful: $BACKUP_FILE" >> "$LOG_FILE"

    # Verify backup integrity
    if gunzip -t "$BACKUP_FILE" 2>> "$LOG_FILE"; then
        echo "[$(date)] Backup verification passed" >> "$LOG_FILE"
    else
        echo "[$(date)] ERROR: Backup verification failed!" >> "$LOG_FILE"
        exit 1
    fi
else
    echo "[$(date)] ERROR: Backup failed!" >> "$LOG_FILE"
    exit 1
fi

# Clean up old backups
echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..." >> "$LOG_FILE"
find "$BACKUP_DIR" -name "rachel_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Report backup size
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup size: $SIZE" >> "$LOG_FILE"

# Optional: Upload to S3
if [ -n "$BACKUP_S3_BUCKET" ]; then
    echo "[$(date)] Uploading to S3..." >> "$LOG_FILE"
    aws s3 cp "$BACKUP_FILE" "s3://$BACKUP_S3_BUCKET/rachel/" && \
        echo "[$(date)] S3 upload successful" >> "$LOG_FILE" || \
        echo "[$(date)] ERROR: S3 upload failed" >> "$LOG_FILE"
fi

# Optional: Send notification
if command -v curl &> /dev/null && [ -n "$SLACK_WEBHOOK" ]; then
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"Rachel backup completed: $BACKUP_FILE ($SIZE)\"}"
fi

echo "[$(date)] Backup complete" >> "$LOG_FILE"
```

Make executable:
```bash
chmod +x /opt/rachel/backup.sh
```

### Cron Schedule

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/rachel/backup.sh

# Add weekly backup integrity check
0 3 * * 0 /opt/rachel/verify-backups.sh
```

### Backup to AWS S3

```bash
#!/bin/bash
# backup-to-s3.sh

S3_BUCKET="s3://my-rachel-backups"
BACKUP_DIR="/backups/rachel"
DATE=$(date +%Y%m%d_%H%M%S)
TEMP_FILE="/tmp/rachel_${DATE}.sql.gz"

# Create backup
docker-compose exec -T postgres pg_dump \
    -U postgres \
    -d rachel_prod \
    --format=custom | gzip > "$TEMP_FILE"

# Upload to S3 with encryption
aws s3 cp "$TEMP_FILE" \
    "$S3_BUCKET/daily/rachel_${DATE}.sql.gz" \
    --storage-class STANDARD_IA \
    --server-side-encryption AES256

# Clean up temp file
rm "$TEMP_FILE"

# Keep only last 30 days in S3
aws s3 ls "$S3_BUCKET/daily/" | \
    while read -r line; do
        createDate=$(echo "$line" | awk '{print $1" "$2}')
        createDate=$(date -d "$createDate" +%s)
        olderThan=$(date --date "30 days ago" +%s)
        if [ $createDate -lt $olderThan ]; then
            fileName=$(echo "$line" | awk '{print $4}')
            aws s3 rm "$S3_BUCKET/daily/$fileName"
        fi
    done
```

### Backup to Google Cloud Storage

```bash
#!/bin/bash
# backup-to-gcs.sh

GCS_BUCKET="gs://my-rachel-backups"
DATE=$(date +%Y%m%d_%H%M%S)
TEMP_FILE="/tmp/rachel_${DATE}.sql.gz"

# Create backup
docker-compose exec -T postgres pg_dump \
    -U postgres \
    -d rachel_prod \
    --format=custom | gzip > "$TEMP_FILE"

# Upload to GCS
gsutil cp "$TEMP_FILE" "$GCS_BUCKET/daily/rachel_${DATE}.sql.gz"

# Clean up
rm "$TEMP_FILE"

# Set lifecycle (auto-delete after 30 days)
# Configure in GCS bucket settings or:
gsutil lifecycle set lifecycle.json "$GCS_BUCKET"
```

---

## Backup Verification

### Automated Verification Script

Create `/opt/rachel/verify-backups.sh`:

```bash
#!/bin/bash
# Verify backup integrity

BACKUP_DIR="/backups/rachel"
LOG_FILE="$BACKUP_DIR/verification.log"

echo "[$(date)] Starting backup verification..." >> "$LOG_FILE"

# Find most recent backup
LATEST_BACKUP=$(ls -t $BACKUP_DIR/rachel_*.sql.gz | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "[$(date)] ERROR: No backups found!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Verifying: $LATEST_BACKUP" >> "$LOG_FILE"

# Test 1: File integrity
if gunzip -t "$LATEST_BACKUP" 2>> "$LOG_FILE"; then
    echo "[$(date)] ✓ File integrity check passed" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ File integrity check FAILED" >> "$LOG_FILE"
    exit 1
fi

# Test 2: Restore to test database
echo "[$(date)] Testing restore to verification database..." >> "$LOG_FILE"

# Create test database
docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS rachel_verify;" 2>> "$LOG_FILE"
docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE rachel_verify;" 2>> "$LOG_FILE"

# Restore backup
if gunzip -c "$LATEST_BACKUP" | docker-compose exec -T postgres pg_restore \
    -U postgres \
    -d rachel_verify \
    --no-owner \
    --no-acl 2>> "$LOG_FILE"; then

    echo "[$(date)] ✓ Restore test passed" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ Restore test FAILED" >> "$LOG_FILE"
    exit 1
fi

# Test 3: Verify data integrity
ROW_COUNT=$(docker-compose exec -T postgres psql -U postgres -d rachel_verify \
    -t -c "SELECT COUNT(*) FROM users;" 2>> "$LOG_FILE")

if [ -n "$ROW_COUNT" ] && [ "$ROW_COUNT" -gt 0 ]; then
    echo "[$(date)] ✓ Data integrity check passed (${ROW_COUNT} users)" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ Data integrity check FAILED" >> "$LOG_FILE"
    exit 1
fi

# Cleanup
docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE rachel_verify;" 2>> "$LOG_FILE"

echo "[$(date)] All verification checks passed!" >> "$LOG_FILE"
```

---

## Restore Procedures

### Full Database Restore

#### 1. Stop Application

```bash
docker-compose stop rachel
```

#### 2. Backup Current Database (just in case)

```bash
docker-compose exec postgres pg_dump -U postgres rachel_prod > current_backup.sql
```

#### 3. Restore from Backup

```bash
# Drop and recreate database
docker-compose exec postgres psql -U postgres -c "DROP DATABASE rachel_prod;"
docker-compose exec postgres psql -U postgres -c "CREATE DATABASE rachel_prod;"

# Restore
gunzip -c /backups/rachel/rachel_20250115_020000.sql.gz | \
    docker-compose exec -T postgres pg_restore \
        -U postgres \
        -d rachel_prod \
        --no-owner \
        --no-acl
```

#### 4. Restart Application

```bash
docker-compose start rachel
```

#### 5. Verify

```bash
# Check health endpoint
curl http://localhost:4000/health

# Check logs
docker-compose logs -f rachel

# Verify data
docker-compose exec postgres psql -U postgres -d rachel_prod -c "SELECT COUNT(*) FROM users;"
```

### Point-in-Time Recovery (PITR)

If using WAL archiving:

```bash
# Stop PostgreSQL
docker-compose stop postgres

# Restore base backup
gunzip -c /backups/rachel/base_backup.sql.gz | \
    docker-compose exec -T postgres pg_restore -U postgres -d rachel_prod

# Configure recovery
cat > /var/lib/postgresql/data/recovery.conf <<EOF
restore_command = 'cp /mnt/wal_archive/%f %p'
recovery_target_time = '2025-01-15 14:30:00'
EOF

# Start PostgreSQL (will replay WAL files)
docker-compose start postgres
```

### Partial Restore (Single Table)

```bash
# Restore just the users table
gunzip -c /backups/rachel/rachel_20250115_020000.sql.gz | \
    docker-compose exec -T postgres pg_restore \
        -U postgres \
        -d rachel_prod \
        --table=users \
        --clean
```

---

## Database Monitoring

### Key Metrics to Monitor

1. **Connection count**
2. **Query performance**
3. **Database size**
4. **Replication lag** (if using replicas)
5. **Cache hit ratio**
6. **Transaction rate**

### PostgreSQL Monitoring Queries

```sql
-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

-- Long-running queries (> 5 minutes)
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 minutes';

-- Database size
SELECT pg_size_pretty(pg_database_size('rachel_prod'));

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Cache hit ratio (should be > 99%)
SELECT
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit)  as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Unused indexes (candidates for removal)
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Monitoring Script

```bash
#!/bin/bash
# monitor-db.sh - Run every 5 minutes

METRICS_FILE="/var/log/rachel/db-metrics.log"

# Collect metrics
CONNECTIONS=$(docker-compose exec -T postgres psql -U postgres -d rachel_prod \
    -t -c "SELECT count(*) FROM pg_stat_activity;")

DB_SIZE=$(docker-compose exec -T postgres psql -U postgres -d rachel_prod \
    -t -c "SELECT pg_database_size('rachel_prod');")

CACHE_HIT=$(docker-compose exec -T postgres psql -U postgres -d rachel_prod \
    -t -c "SELECT ROUND(sum(heap_blks_hit) / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2) FROM pg_statio_user_tables;")

# Log metrics
echo "$(date +%s),$CONNECTIONS,$DB_SIZE,$CACHE_HIT" >> "$METRICS_FILE"

# Alert if connections > 80% of pool size
MAX_CONNECTIONS=100
if [ "$CONNECTIONS" -gt 80 ]; then
    echo "WARNING: High connection count: $CONNECTIONS" | \
        mail -s "Rachel DB Alert" admin@example.com
fi
```

### Prometheus Exporter (Advanced)

Use `postgres_exporter` for Prometheus/Grafana:

```yaml
# docker-compose.yml
services:
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:password@postgres:5432/rachel_prod?sslmode=disable"
    ports:
      - "9187:9187"
```

---

## Performance Tuning

### PostgreSQL Configuration

Optimize `postgresql.conf` for production:

```ini
# Memory
shared_buffers = 256MB          # 25% of RAM
effective_cache_size = 1GB      # 75% of RAM
work_mem = 16MB                 # Per-query memory
maintenance_work_mem = 128MB    # For VACUUM, etc.

# Connections
max_connections = 100

# Checkpoints
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Query planning
random_page_cost = 1.1          # For SSDs
effective_io_concurrency = 200  # For SSDs

# Logging
log_min_duration_statement = 1000  # Log slow queries (>1s)
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
```

### Regular Maintenance

```bash
#!/bin/bash
# maintenance.sh - Run weekly

echo "Running VACUUM ANALYZE..."
docker-compose exec postgres psql -U postgres -d rachel_prod -c "VACUUM ANALYZE;"

echo "Reindexing..."
docker-compose exec postgres psql -U postgres -d rachel_prod -c "REINDEX DATABASE rachel_prod;"

echo "Cleaning up old sessions..."
docker-compose exec rachel bin/rachel eval "Rachel.Accounts.delete_expired_sessions()"
```

---

## Disaster Recovery

### Recovery Time Objective (RTO)

Target: **< 30 minutes** from disaster to operational

### Recovery Point Objective (RPO)

Target: **< 5 minutes** of data loss

### DR Checklist

- [ ] Offsite backups configured (S3/GCS)
- [ ] Backup restoration tested monthly
- [ ] DR runbook documented
- [ ] Emergency contact list maintained
- [ ] Failover database replica (optional)

### DR Runbook

**Scenario: Complete database loss**

1. **Assess damage** (5 min)
   - Verify database is unrecoverable
   - Identify most recent backup

2. **Provision new database** (5 min)
   - Spin up new PostgreSQL instance
   - Configure networking/firewall

3. **Restore from backup** (15 min)
   - Download latest backup from S3
   - Restore to new database
   - Verify data integrity

4. **Update application** (3 min)
   - Update DATABASE_URL
   - Restart application

5. **Verify and monitor** (2 min)
   - Check health endpoint
   - Monitor error rates
   - Notify stakeholders

**Total time: ~30 minutes**

---

## Backup Checklist

Daily:
- [ ] Automated backup runs successfully
- [ ] Backup uploaded to offsite storage
- [ ] Backup size is reasonable (not 0 bytes!)

Weekly:
- [ ] Verify backup integrity (gunzip test)
- [ ] Test restore to staging database
- [ ] Review backup logs for errors

Monthly:
- [ ] Full disaster recovery drill
- [ ] Review backup retention policy
- [ ] Check backup storage capacity

Quarterly:
- [ ] Review and update DR plan
- [ ] Test restore to production (in maintenance window)
- [ ] Audit backup access controls

---

For questions or issues with backups, check `/backups/rachel/backup.log` and verify cron jobs are running with `crontab -l`.
