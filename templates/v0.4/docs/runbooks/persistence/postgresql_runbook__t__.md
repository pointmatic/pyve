# PostgreSQL Operations Runbook

## Overview

PostgreSQL is an open-source relational database known for its reliability, feature robustness, and performance. This runbook provides specific commands and procedures for production PostgreSQL operations.

**Key capabilities:**
- ACID compliance
- Advanced indexing (B-tree, Hash, GiST, GIN, BRIN)
- Full-text search
- JSON/JSONB support
- Extensions (PostGIS, pg_stat_statements, pgcrypto, etc.)
- Streaming replication
- Logical replication (publish/subscribe)

**Versions covered:** PostgreSQL 12+

---

## Installation & Setup

### Installation

**Ubuntu/Debian:**
```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install PostgreSQL
sudo apt update
sudo apt install postgresql-15 postgresql-contrib-15
```

**RHEL/CentOS:**
```bash
# Install repository
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Install PostgreSQL
sudo dnf -qy module disable postgresql
sudo dnf install -y postgresql15-server postgresql15-contrib

# Initialize database
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
```

**macOS:**
```bash
# Using Homebrew
brew install postgresql@15

# Start service
brew services start postgresql@15
```

### Initial Configuration

**Create database and user:**
```sql
-- Connect as postgres user
sudo -u postgres psql

-- Create database
CREATE DATABASE myapp;

-- Create user with password
CREATE USER myapp_user WITH PASSWORD 'secure_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;

-- Grant schema privileges (PostgreSQL 15+)
\c myapp
GRANT ALL ON SCHEMA public TO myapp_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO myapp_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO myapp_user;
```

**Basic postgresql.conf settings:**
```ini
# Connection settings
listen_addresses = '*'
port = 5432
max_connections = 100

# Memory settings (adjust for your server)
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# WAL settings
wal_level = replica
max_wal_size = 1GB
min_wal_size = 80MB

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%m [%p] %u@%d '
log_timezone = 'UTC'
```

**pg_hba.conf (authentication):**
```ini
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             all                                     md5

# IPv4 local connections
host    all             all             127.0.0.1/32            md5

# IPv4 remote connections (adjust subnet)
host    all             all             10.0.0.0/8              md5

# Replication connections
host    replication     replicator      10.0.0.0/8              md5
```

---

## Backup & Recovery

### Logical Backup (pg_dump)

**Backup single database:**
```bash
# Plain SQL format (human-readable)
pg_dump -h localhost -U postgres -d mydb > backup.sql

# Custom format (compressed, supports parallel restore)
pg_dump -h localhost -U postgres -d mydb -Fc -f backup.dump

# Directory format (parallel dump and restore)
pg_dump -h localhost -U postgres -d mydb -Fd -j 4 -f backup_dir/

# With compression
pg_dump -h localhost -U postgres -d mydb | gzip > backup.sql.gz
```

**Backup all databases:**
```bash
pg_dumpall -h localhost -U postgres > all_databases.sql

# Backup only globals (roles, tablespaces)
pg_dumpall -h localhost -U postgres --globals-only > globals.sql
```

**Backup specific tables:**
```bash
pg_dump -h localhost -U postgres -d mydb -t users -t orders > tables.sql
```

**Restore from backup:**
```bash
# Restore SQL dump
psql -h localhost -U postgres -d mydb < backup.sql

# Restore custom format
pg_restore -h localhost -U postgres -d mydb backup.dump

# Restore with parallel jobs
pg_restore -h localhost -U postgres -d mydb -j 4 backup_dir/

# Restore specific table
pg_restore -h localhost -U postgres -d mydb -t users backup.dump
```

### Physical Backup (pg_basebackup)

**Full physical backup:**
```bash
# Binary format with compression
pg_basebackup -h localhost -U postgres -D /backup/dir -Ft -z -P

# Options:
# -D: Output directory
# -Ft: Tar format
# -z: gzip compression
# -P: Show progress
# -X stream: Include WAL files

# With WAL streaming
pg_basebackup -h localhost -U postgres -D /backup/dir -Ft -z -P -X stream
```

**Restore from physical backup:**
```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove old data directory
sudo rm -rf /var/lib/postgresql/15/main/*

# Extract backup
sudo tar -xzf /backup/dir/base.tar.gz -C /var/lib/postgresql/15/main/

# Set permissions
sudo chown -R postgres:postgres /var/lib/postgresql/15/main

# Start PostgreSQL
sudo systemctl start postgresql
```

### Continuous Archiving (WAL)

**Configure WAL archiving (postgresql.conf):**
```ini
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'
archive_timeout = 300  # Force WAL switch every 5 minutes

# For production, use more robust archive command:
# archive_command = 'rsync -a %p backup-server:/archive/%f'
```

**Point-in-time recovery (PITR):**
```bash
# 1. Restore base backup
sudo systemctl stop postgresql
sudo rm -rf /var/lib/postgresql/15/main/*
sudo tar -xzf /backup/base.tar.gz -C /var/lib/postgresql/15/main/

# 2. Create recovery.signal file
sudo touch /var/lib/postgresql/15/main/recovery.signal

# 3. Configure recovery (postgresql.conf or recovery.conf for older versions)
restore_command = 'cp /archive/%f %p'
recovery_target_time = '2024-01-15 14:30:00'  # Or use recovery_target_xid, recovery_target_name

# 4. Start PostgreSQL (will recover to target time)
sudo systemctl start postgresql

# 5. Check recovery status
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"

# 6. Promote to primary (if satisfied with recovery)
sudo -u postgres psql -c "SELECT pg_promote();"
```

### Automated Backup Script

```bash
#!/bin/bash
# backup_postgres.sh

set -e

# Configuration
DB_HOST="localhost"
DB_USER="postgres"
BACKUP_DIR="/backups/postgres"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup all databases
pg_dumpall -h "$DB_HOST" -U "$DB_USER" | gzip > "$BACKUP_DIR/all_databases_$TIMESTAMP.sql.gz"

# Backup specific database (custom format)
pg_dump -h "$DB_HOST" -U "$DB_USER" -d mydb -Fc -f "$BACKUP_DIR/mydb_$TIMESTAMP.dump"

# Remove old backups
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $TIMESTAMP"
```

**Schedule with cron:**
```bash
# Edit crontab
crontab -e

# Run daily at 2 AM
0 2 * * * /path/to/backup_postgres.sh >> /var/log/postgres_backup.log 2>&1
```

---

## Replication & High Availability

### Streaming Replication

**Primary server configuration (postgresql.conf):**
```ini
wal_level = replica
max_wal_senders = 3
wal_keep_size = 1GB  # Or wal_keep_segments for older versions
hot_standby = on
```

**Create replication user:**
```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_password';
```

**Primary pg_hba.conf:**
```ini
# Allow replication connections
host    replication     replicator      10.0.0.0/8              md5
```

**Replica server setup:**
```bash
# Stop replica PostgreSQL
sudo systemctl stop postgresql

# Remove data directory
sudo rm -rf /var/lib/postgresql/15/main/*

# Create base backup from primary
pg_basebackup -h primary-host -U replicator -D /var/lib/postgresql/15/main -P -X stream

# Set permissions
sudo chown -R postgres:postgres /var/lib/postgresql/15/main

# Create standby.signal file (PostgreSQL 12+)
sudo -u postgres touch /var/lib/postgresql/15/main/standby.signal

# Configure replica connection (postgresql.conf)
primary_conninfo = 'host=primary-host port=5432 user=replicator password=repl_password'

# Start replica
sudo systemctl start postgresql
```

**Check replication status:**
```sql
-- On primary
SELECT client_addr, state, sync_state, replay_lag
FROM pg_stat_replication;

-- On replica
SELECT pg_is_in_recovery();
SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();
```

### Synchronous Replication

**Primary configuration (postgresql.conf):**
```ini
synchronous_commit = on
synchronous_standby_names = 'replica1,replica2'  # First available becomes sync
# Or for all replicas: synchronous_standby_names = '*'
```

**Check sync status:**
```sql
SELECT application_name, sync_state, sync_priority
FROM pg_stat_replication;
```

### Failover Procedures

**Manual failover:**
```bash
# 1. Stop primary (if still running)
sudo systemctl stop postgresql

# 2. Promote replica to primary
sudo -u postgres pg_ctl promote -D /var/lib/postgresql/15/main
# Or using SQL:
sudo -u postgres psql -c "SELECT pg_promote();"

# 3. Update application connection strings to point to new primary

# 4. Reconfigure old primary as replica (when recovered)
# - Remove standby.signal
# - Configure primary_conninfo
# - Create standby.signal
# - Start PostgreSQL
```

**Automatic failover with Patroni:**

See infrastructure runbooks for Patroni setup with etcd/Consul/ZooKeeper.

---

## Performance Tuning

### Configuration Parameters

**Memory settings (for 16GB RAM server):**
```ini
shared_buffers = 4GB              # 25% of RAM
effective_cache_size = 12GB       # 75% of RAM
work_mem = 64MB                   # Per query operation
maintenance_work_mem = 1GB        # For VACUUM, CREATE INDEX
```

**Connection settings:**
```ini
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'
```

**WAL settings:**
```ini
wal_buffers = 16MB
checkpoint_completion_target = 0.9
max_wal_size = 2GB
min_wal_size = 1GB
```

**Query planner:**
```ini
random_page_cost = 1.1            # Lower for SSD (default 4.0)
effective_io_concurrency = 200    # Higher for SSD (default 1)
```

### Identifying Slow Queries

**Enable pg_stat_statements:**
```sql
-- Add to postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all

-- Restart PostgreSQL
-- Then create extension
CREATE EXTENSION pg_stat_statements;
```

**View slow queries:**
```sql
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Enable slow query logging (postgresql.conf):**
```ini
log_min_duration_statement = 1000  # Log queries taking >1s
log_statement = 'all'               # Or 'ddl', 'mod'
```

**View logs:**
```bash
tail -f /var/log/postgresql/postgresql-15-main.log
```

### Query Analysis

**Use EXPLAIN:**
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'alice@example.com';

-- Look for:
-- - Seq Scan (bad, should use index)
-- - Index Scan (good)
-- - Bitmap Heap Scan (good for multiple matches)
-- - Nested Loop (can be slow for large datasets)
-- - Hash Join (good for large datasets)
```

**Analyze query plan:**
```sql
-- Update statistics
ANALYZE users;

-- Verbose explain
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT ...;
```

### Indexing

**Create indexes:**
```sql
-- Single column index
CREATE INDEX idx_users_email ON users(email);

-- Composite index
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Partial index
CREATE INDEX idx_active_users ON users(email) WHERE active = true;

-- Covering index (INCLUDE clause, PostgreSQL 11+)
CREATE INDEX idx_users_email_name ON users(email) INCLUDE (name);

-- Expression index
CREATE INDEX idx_users_lower_email ON users(LOWER(email));

-- GIN index for full-text search
CREATE INDEX idx_posts_content ON posts USING GIN(to_tsvector('english', content));

-- BRIN index for time-series data
CREATE INDEX idx_events_created ON events USING BRIN(created_at);
```

**Check index usage:**
```sql
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexname NOT LIKE 'pg_toast%';
```

### Vacuuming

**Manual vacuum:**
```sql
-- Vacuum single table
VACUUM users;

-- Vacuum and analyze
VACUUM ANALYZE users;

-- Full vacuum (locks table, reclaims space)
VACUUM FULL users;
```

**Autovacuum configuration (postgresql.conf):**
```ini
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.2
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.1
```

**Check vacuum status:**
```sql
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    n_dead_tup,
    n_live_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

---

## Monitoring & Alerting

### Key Metrics

**Database size:**
```sql
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

**Table sizes:**
```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

**Connection count:**
```sql
SELECT 
    count(*),
    state,
    usename
FROM pg_stat_activity
GROUP BY state, usename;
```

**Long-running queries:**
```sql
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE state != 'idle'
AND now() - pg_stat_activity.query_start > interval '5 minutes'
ORDER BY duration DESC;
```

**Kill long-running query:**
```sql
-- Graceful termination
SELECT pg_cancel_backend(pid);

-- Force kill
SELECT pg_terminate_backend(pid);
```

**Replication lag:**
```sql
-- On primary
SELECT 
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- On replica
SELECT 
    now() - pg_last_xact_replay_timestamp() AS replication_lag;
```

**Cache hit ratio:**
```sql
SELECT 
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

### Alerting Thresholds

- **Connection count:** >80% of max_connections
- **Replication lag:** >60 seconds
- **Cache hit ratio:** <90%
- **Disk space:** >80% full
- **Long-running queries:** >5 minutes
- **Dead tuples:** >10% of live tuples

---

## Common Operations

### User Management

**Create user:**
```sql
CREATE USER alice WITH PASSWORD 'secure_password';

-- With specific privileges
CREATE USER bob WITH LOGIN CREATEDB;
```

**Grant privileges:**
```sql
-- Database level
GRANT CONNECT ON DATABASE mydb TO alice;

-- Schema level
GRANT USAGE ON SCHEMA public TO alice;

-- Table level
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO alice;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO alice;

-- Future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO alice;
```

**Revoke privileges:**
```sql
REVOKE INSERT, UPDATE, DELETE ON users FROM alice;
```

**Change password:**
```sql
ALTER USER alice WITH PASSWORD 'new_password';
```

**Drop user:**
```sql
-- Reassign owned objects
REASSIGN OWNED BY alice TO postgres;

-- Drop owned objects
DROP OWNED BY alice;

-- Drop user
DROP USER alice;
```

### Database Maintenance

**Reindex:**
```sql
-- Reindex table
REINDEX TABLE users;

-- Reindex database
REINDEX DATABASE mydb;

-- Reindex concurrently (PostgreSQL 12+, doesn't lock table)
REINDEX INDEX CONCURRENTLY idx_users_email;
```

**Analyze:**
```sql
-- Single table
ANALYZE users;

-- All tables
ANALYZE;
```

**Check for bloat:**
```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_dead_tup,
    n_live_tup,
    round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

---

## Troubleshooting

### Common Issues

**Issue: Connection refused**
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check listening address
sudo -u postgres psql -c "SHOW listen_addresses;"

# Check pg_hba.conf for authentication rules
sudo cat /etc/postgresql/15/main/pg_hba.conf

# Check logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

**Issue: Out of disk space**
```bash
# Check disk usage
df -h

# Find large tables
sudo -u postgres psql -c "
SELECT 
    schemaname||'.'||tablename AS table,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;"

# Vacuum to reclaim space
sudo -u postgres psql -d mydb -c "VACUUM FULL;"

# Archive old WAL files
sudo -u postgres pg_archivecleanup /var/lib/postgresql/15/main/pg_wal 000000010000000000000010
```

**Issue: High CPU usage**
```sql
-- Find expensive queries
SELECT 
    pid,
    now() - query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Kill expensive query
SELECT pg_terminate_backend(pid);
```

**Issue: Replication lag**
```sql
-- Check replication status
SELECT * FROM pg_stat_replication;

-- Check WAL sender processes
SELECT * FROM pg_stat_wal_receiver;

-- Increase wal_keep_size if replica is falling behind
ALTER SYSTEM SET wal_keep_size = '2GB';
SELECT pg_reload_conf();
```

**Issue: Deadlocks**
```sql
-- Enable deadlock logging
ALTER SYSTEM SET log_lock_waits = on;
ALTER SYSTEM SET deadlock_timeout = '1s';
SELECT pg_reload_conf();

-- View locks
SELECT * FROM pg_locks WHERE NOT granted;
```

---

## Security

### SSL/TLS

**Enable SSL (postgresql.conf):**
```ini
ssl = on
ssl_cert_file = '/etc/postgresql/15/main/server.crt'
ssl_key_file = '/etc/postgresql/15/main/server.key'
ssl_ca_file = '/etc/postgresql/15/main/root.crt'
```

**Require SSL (pg_hba.conf):**
```ini
hostssl    all             all             0.0.0.0/0               md5
```

**Client connection:**
```bash
psql "postgresql://user@host/db?sslmode=require"
```

### Row-Level Security

**Enable RLS:**
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: users see only their orders
CREATE POLICY user_orders ON orders
FOR SELECT
USING (user_id = current_setting('app.current_user_id')::int);

-- Policy: admins see all orders
CREATE POLICY admin_orders ON orders
FOR ALL
TO admin_role
USING (true);
```

**Set user context:**
```sql
SET app.current_user_id = 123;
SELECT * FROM orders;  -- Only sees orders for user 123
```

### Encryption

**Column-level encryption (pgcrypto):**
```sql
CREATE EXTENSION pgcrypto;

-- Encrypt
INSERT INTO users (email, ssn)
VALUES ('alice@example.com', pgp_sym_encrypt('123-45-6789', 'encryption_key'));

-- Decrypt
SELECT email, pgp_sym_decrypt(ssn, 'encryption_key') AS ssn
FROM users;
```

### Audit Logging

**Install pgaudit:**
```bash
sudo apt install postgresql-15-pgaudit
```

**Configure (postgresql.conf):**
```ini
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'write, ddl'
pgaudit.log_relation = on
```

**Restart and verify:**
```bash
sudo systemctl restart postgresql
sudo -u postgres psql -c "SHOW shared_preload_libraries;"
```

---

## Upgrade Procedures

### Minor Version Upgrade

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Upgrade PostgreSQL
sudo apt upgrade postgresql-15

# Restart
sudo systemctl restart postgresql
```

### Major Version Upgrade (pg_upgrade)

**Upgrade from PostgreSQL 14 to 15:**
```bash
# Install new version
sudo apt install postgresql-15

# Stop both versions
sudo systemctl stop postgresql@14-main
sudo systemctl stop postgresql@15-main

# Run pg_upgrade
sudo -u postgres /usr/lib/postgresql/15/bin/pg_upgrade \
  --old-datadir=/var/lib/postgresql/14/main \
  --new-datadir=/var/lib/postgresql/15/main \
  --old-bindir=/usr/lib/postgresql/14/bin \
  --new-bindir=/usr/lib/postgresql/15/bin \
  --check

# If check passes, run actual upgrade
sudo -u postgres /usr/lib/postgresql/15/bin/pg_upgrade \
  --old-datadir=/var/lib/postgresql/14/main \
  --new-datadir=/var/lib/postgresql/15/main \
  --old-bindir=/usr/lib/postgresql/14/bin \
  --new-bindir=/usr/lib/postgresql/15/bin

# Start new version
sudo systemctl start postgresql@15-main

# Run analyze
sudo -u postgres /usr/lib/postgresql/15/bin/vacuumdb --all --analyze-in-stages

# Remove old version (after verification)
sudo apt remove postgresql-14
```

---

## References

- **Official Documentation:** https://www.postgresql.org/docs/
- **Performance Tips:** https://www.postgresql.org/docs/current/performance-tips.html
- **pg_stat_statements:** https://www.postgresql.org/docs/current/pgstatstatements.html
- **Replication:** https://www.postgresql.org/docs/current/high-availability.html
- **pgaudit:** https://github.com/pgaudit/pgaudit

---

## Related Documentation

- **Operations Guide:** `docs/guides/persistence_operations_guide__t__.md` - General strategies and concepts
- **Persistence Guide:** `docs/guides/persistence_guide__t__.md` - Choosing storage technologies
- **Cloud Databases Runbook:** `cloud_databases_runbook__t__.md` - AWS RDS/Aurora PostgreSQL
