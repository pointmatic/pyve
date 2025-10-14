# MySQL Operations Runbook

## Overview

MySQL is an open-source relational database known for its speed, reliability, and ease of use. This runbook provides specific commands and procedures for production MySQL operations.

**Key capabilities:**
- ACID compliance (InnoDB)
- High performance for read-heavy workloads
- Replication (asynchronous, semi-synchronous)
- Partitioning
- Full-text search
- JSON support (MySQL 5.7+)
- Group replication (multi-master)

**Versions covered:** MySQL 8.0+

---

## Installation & Setup

### Installation

**Ubuntu/Debian:**
```bash
# Add MySQL repository
wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.24-1_all.deb
sudo apt update

# Install MySQL
sudo apt install mysql-server

# Secure installation
sudo mysql_secure_installation
```

**RHEL/CentOS:**
```bash
# Add MySQL repository
sudo dnf install https://dev.mysql.com/get/mysql80-community-release-el8-1.noarch.rpm

# Install MySQL
sudo dnf install mysql-server

# Start service
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Get temporary root password
sudo grep 'temporary password' /var/log/mysqld.log

# Secure installation
sudo mysql_secure_installation
```

**macOS:**
```bash
# Using Homebrew
brew install mysql

# Start service
brew services start mysql

# Secure installation
mysql_secure_installation
```

### Initial Configuration

**Connect to MySQL:**
```bash
# As root
sudo mysql

# With password
mysql -u root -p
```

**Create database and user:**
```sql
-- Create database
CREATE DATABASE myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'secure_password';
CREATE USER 'myapp_user'@'%' IDENTIFIED BY 'secure_password';  -- Remote access

-- Grant privileges
GRANT ALL PRIVILEGES ON myapp.* TO 'myapp_user'@'localhost';
GRANT ALL PRIVILEGES ON myapp.* TO 'myapp_user'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

**Basic my.cnf configuration:**
```ini
[mysqld]
# Server settings
bind-address = 0.0.0.0
port = 3306
max_connections = 150

# Memory settings (adjust for your server)
innodb_buffer_pool_size = 12G      # 70-80% of RAM
innodb_log_file_size = 512M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2  # Better performance, slight risk

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Binary logging (for replication and PITR)
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
binlog_expire_logs_seconds = 604800  # 7 days

# Slow query log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 1

# Error log
log_error = /var/log/mysql/error.log

# General log (disable in production)
# general_log = 1
# general_log_file = /var/log/mysql/general.log

[client]
default-character-set = utf8mb4
```

**Restart MySQL:**
```bash
sudo systemctl restart mysql
```

---

## Backup & Recovery

### Logical Backup (mysqldump)

**Backup single database:**
```bash
# Basic backup
mysqldump -u root -p mydb > backup.sql

# With compression
mysqldump -u root -p mydb | gzip > backup.sql.gz

# Include routines and triggers
mysqldump -u root -p --routines --triggers mydb > backup.sql

# Single transaction (consistent snapshot for InnoDB)
mysqldump -u root -p --single-transaction mydb > backup.sql
```

**Backup all databases:**
```bash
mysqldump -u root -p --all-databases > all_databases.sql

# With routines and events
mysqldump -u root -p --all-databases --routines --events > all_databases.sql
```

**Backup specific tables:**
```bash
mysqldump -u root -p mydb users orders > tables.sql
```

**Restore from backup:**
```bash
# Restore database
mysql -u root -p mydb < backup.sql

# Restore from compressed backup
gunzip < backup.sql.gz | mysql -u root -p mydb

# Restore all databases
mysql -u root -p < all_databases.sql
```

### Physical Backup (Percona XtraBackup)

**Install Percona XtraBackup:**
```bash
# Ubuntu/Debian
wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
sudo dpkg -i percona-release_latest.generic_all.deb
sudo apt update
sudo apt install percona-xtrabackup-80

# RHEL/CentOS
sudo yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sudo yum install percona-xtrabackup-80
```

**Create backup:**
```bash
# Full backup
xtrabackup --backup --target-dir=/backup/full --user=root --password=password

# Incremental backup
xtrabackup --backup --target-dir=/backup/inc1 --incremental-basedir=/backup/full --user=root --password=password
```

**Prepare backup:**
```bash
# Prepare full backup
xtrabackup --prepare --target-dir=/backup/full

# Prepare with incremental
xtrabackup --prepare --apply-log-only --target-dir=/backup/full
xtrabackup --prepare --apply-log-only --target-dir=/backup/full --incremental-dir=/backup/inc1
xtrabackup --prepare --target-dir=/backup/full
```

**Restore backup:**
```bash
# Stop MySQL
sudo systemctl stop mysql

# Remove old data
sudo rm -rf /var/lib/mysql/*

# Copy backup
xtrabackup --copy-back --target-dir=/backup/full

# Set permissions
sudo chown -R mysql:mysql /var/lib/mysql

# Start MySQL
sudo systemctl start mysql
```

### Binary Log Backup (Point-in-Time Recovery)

**Enable binary logging (my.cnf):**
```ini
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
binlog_expire_logs_seconds = 604800
```

**View binary logs:**
```sql
SHOW BINARY LOGS;
SHOW MASTER STATUS;
```

**Backup binary logs:**
```bash
# Flush logs (create new binary log file)
mysql -u root -p -e "FLUSH BINARY LOGS;"

# Copy binary logs to backup location
cp /var/log/mysql/mysql-bin.* /backup/binlogs/
```

**Point-in-time recovery:**
```bash
# 1. Restore full backup
mysql -u root -p < backup.sql

# 2. Apply binary logs up to specific time
mysqlbinlog --stop-datetime="2024-01-15 14:30:00" \
  /var/log/mysql/mysql-bin.000001 \
  /var/log/mysql/mysql-bin.000002 | mysql -u root -p

# Or up to specific position
mysqlbinlog --stop-position=12345 /var/log/mysql/mysql-bin.000001 | mysql -u root -p
```

### Automated Backup Script

```bash
#!/bin/bash
# backup_mysql.sh

set -e

# Configuration
DB_USER="root"
DB_PASS="password"
BACKUP_DIR="/backups/mysql"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup all databases
mysqldump -u "$DB_USER" -p"$DB_PASS" \
  --all-databases \
  --single-transaction \
  --routines \
  --events \
  --triggers | gzip > "$BACKUP_DIR/all_databases_$TIMESTAMP.sql.gz"

# Backup binary logs
mysql -u "$DB_USER" -p"$DB_PASS" -e "FLUSH BINARY LOGS;"
cp /var/log/mysql/mysql-bin.* "$BACKUP_DIR/binlogs/" 2>/dev/null || true

# Remove old backups
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $TIMESTAMP"
```

**Schedule with cron:**
```bash
# Run daily at 2 AM
0 2 * * * /path/to/backup_mysql.sh >> /var/log/mysql_backup.log 2>&1
```

---

## Replication & High Availability

### Asynchronous Replication

**Primary server configuration (my.cnf):**
```ini
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
binlog_do_db = mydb  # Optional: replicate specific database
```

**Create replication user:**
```sql
CREATE USER 'replicator'@'%' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
```

**Get primary status:**
```sql
SHOW MASTER STATUS;
-- Note the File and Position values
```

**Replica server configuration (my.cnf):**
```ini
[mysqld]
server-id = 2
relay-log = /var/log/mysql/mysql-relay-bin
log_bin = /var/log/mysql/mysql-bin.log
read_only = 1
```

**Configure replica:**
```sql
CHANGE MASTER TO
  MASTER_HOST='primary-host',
  MASTER_USER='replicator',
  MASTER_PASSWORD='repl_password',
  MASTER_LOG_FILE='mysql-bin.000001',  -- From SHOW MASTER STATUS
  MASTER_LOG_POS=12345;                -- From SHOW MASTER STATUS

START SLAVE;
```

**Check replication status:**
```sql
SHOW SLAVE STATUS\G

-- Key fields:
-- Slave_IO_Running: Yes
-- Slave_SQL_Running: Yes
-- Seconds_Behind_Master: 0 (or low number)
-- Last_Error: (should be empty)
```

### Semi-Synchronous Replication

**Install plugin on primary:**
```sql
INSTALL PLUGIN rpl_semi_sync_master SONAME 'semisync_master.so';
SET GLOBAL rpl_semi_sync_master_enabled = 1;
SET GLOBAL rpl_semi_sync_master_timeout = 1000;  -- 1 second
```

**Install plugin on replica:**
```sql
INSTALL PLUGIN rpl_semi_sync_slave SONAME 'semisync_slave.so';
SET GLOBAL rpl_semi_sync_slave_enabled = 1;
STOP SLAVE IO_THREAD;
START SLAVE IO_THREAD;
```

**Check status:**
```sql
-- On primary
SHOW STATUS LIKE 'Rpl_semi_sync_master_status';
SHOW STATUS LIKE 'Rpl_semi_sync_master_clients';

-- On replica
SHOW STATUS LIKE 'Rpl_semi_sync_slave_status';
```

### Group Replication (Multi-Master)

**Configure first node (my.cnf):**
```ini
[mysqld]
server-id = 1
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_checksum = NONE
log_slave_updates = ON
binlog_format = ROW

plugin_load_add = 'group_replication.so'
group_replication_group_name = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
group_replication_start_on_boot = OFF
group_replication_local_address = "node1:33061"
group_replication_group_seeds = "node1:33061,node2:33061,node3:33061"
group_replication_bootstrap_group = OFF
```

**Bootstrap group:**
```sql
-- On first node only
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=OFF;
```

**Add additional nodes:**
```sql
-- On other nodes
START GROUP_REPLICATION;
```

**Check group status:**
```sql
SELECT * FROM performance_schema.replication_group_members;
```

### Failover Procedures

**Manual failover:**
```bash
# 1. Stop writes to primary
mysql -u root -p -e "SET GLOBAL read_only = ON;"

# 2. Wait for replica to catch up
mysql -u root -p -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master

# 3. Promote replica to primary
mysql -u root -p -e "STOP SLAVE; RESET SLAVE ALL; SET GLOBAL read_only = OFF;"

# 4. Update application connection strings

# 5. Reconfigure old primary as replica (when recovered)
```

**Automatic failover with MHA:**

See MySQL MHA (Master High Availability) documentation for setup.

---

## Performance Tuning

### Configuration Parameters

**Memory settings (for 16GB RAM server):**
```ini
[mysqld]
innodb_buffer_pool_size = 12G      # 70-80% of RAM
innodb_log_file_size = 512M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2

# Query cache (deprecated in MySQL 8.0)
# query_cache_type = 1
# query_cache_size = 256M

# Thread cache
thread_cache_size = 16

# Table cache
table_open_cache = 2000
table_definition_cache = 1000
```

**Connection settings:**
```ini
max_connections = 150
max_connect_errors = 100
connect_timeout = 10
wait_timeout = 600
interactive_timeout = 600
```

**InnoDB settings:**
```ini
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_io_capacity = 2000          # Higher for SSD
innodb_io_capacity_max = 4000
innodb_read_io_threads = 4
innodb_write_io_threads = 4
```

### Identifying Slow Queries

**Enable slow query log (my.cnf):**
```ini
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 1
log_queries_not_using_indexes = 1
```

**Or dynamically:**
```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
SET GLOBAL log_queries_not_using_indexes = ON;
```

**View slow queries:**
```bash
# View slow query log
sudo tail -f /var/log/mysql/slow-query.log

# Analyze with pt-query-digest (Percona Toolkit)
pt-query-digest /var/log/mysql/slow-query.log
```

**Use performance_schema:**
```sql
-- Enable performance_schema (my.cnf)
performance_schema = ON

-- View slow queries
SELECT 
    DIGEST_TEXT,
    COUNT_STAR,
    AVG_TIMER_WAIT/1000000000 AS avg_ms,
    SUM_TIMER_WAIT/1000000000 AS total_ms
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;
```

### Query Analysis

**Use EXPLAIN:**
```sql
EXPLAIN SELECT * FROM users WHERE email = 'alice@example.com';

-- Extended explain
EXPLAIN FORMAT=JSON SELECT ...;

-- Analyze actual execution
EXPLAIN ANALYZE SELECT ...;  -- MySQL 8.0.18+
```

**Look for:**
- **type: ALL** (bad, full table scan)
- **type: index** (better, index scan)
- **type: range** (good, range scan)
- **type: ref** (good, index lookup)
- **type: eq_ref** (best, unique index lookup)
- **Extra: Using filesort** (bad, requires sorting)
- **Extra: Using temporary** (bad, requires temp table)

### Indexing

**Create indexes:**
```sql
-- Single column index
CREATE INDEX idx_users_email ON users(email);

-- Composite index
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Unique index
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- Full-text index
CREATE FULLTEXT INDEX idx_posts_content ON posts(content);

-- Prefix index (for long strings)
CREATE INDEX idx_users_email_prefix ON users(email(10));
```

**Check index usage:**
```sql
-- Show indexes on table
SHOW INDEX FROM users;

-- Check index statistics
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    SEQ_IN_INDEX,
    COLUMN_NAME,
    CARDINALITY
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'mydb'
AND TABLE_NAME = 'users';

-- Find unused indexes (performance_schema)
SELECT 
    object_schema,
    object_name,
    index_name
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
AND count_star = 0
AND object_schema != 'mysql'
ORDER BY object_schema, object_name;
```

### Optimization

**Optimize tables:**
```sql
-- Optimize single table
OPTIMIZE TABLE users;

-- Optimize all tables in database
SELECT CONCAT('OPTIMIZE TABLE ', table_schema, '.', table_name, ';')
FROM information_schema.tables
WHERE table_schema = 'mydb';
```

**Analyze tables:**
```sql
ANALYZE TABLE users;
```

**Check table status:**
```sql
SHOW TABLE STATUS FROM mydb LIKE 'users'\G
```

---

## Monitoring & Alerting

### Key Metrics

**Database size:**
```sql
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema
ORDER BY SUM(data_length + index_length) DESC;
```

**Table sizes:**
```sql
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
    table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = 'mydb'
ORDER BY (data_length + index_length) DESC
LIMIT 10;
```

**Connection count:**
```sql
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';

-- Active connections
SELECT 
    user,
    host,
    db,
    command,
    time,
    state
FROM information_schema.processlist
WHERE command != 'Sleep'
ORDER BY time DESC;
```

**Long-running queries:**
```sql
SELECT 
    id,
    user,
    host,
    db,
    command,
    time,
    state,
    info
FROM information_schema.processlist
WHERE command != 'Sleep'
AND time > 300  -- 5 minutes
ORDER BY time DESC;
```

**Kill query:**
```sql
KILL QUERY 12345;  -- Kill query only
KILL 12345;        -- Kill connection
```

**Replication lag:**
```sql
SHOW SLAVE STATUS\G

-- Check Seconds_Behind_Master field
```

**InnoDB status:**
```sql
SHOW ENGINE INNODB STATUS\G
```

**Buffer pool hit ratio:**
```sql
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';

-- Calculate hit ratio:
-- (Innodb_buffer_pool_read_requests - Innodb_buffer_pool_reads) / Innodb_buffer_pool_read_requests
-- Should be >99%
```

### Alerting Thresholds

- **Connection count:** >80% of max_connections
- **Replication lag:** >60 seconds
- **Buffer pool hit ratio:** <99%
- **Disk space:** >80% full
- **Long-running queries:** >5 minutes
- **Slow queries:** >100 per minute

---

## Common Operations

### User Management

**Create user:**
```sql
CREATE USER 'alice'@'localhost' IDENTIFIED BY 'secure_password';
CREATE USER 'alice'@'%' IDENTIFIED BY 'secure_password';  -- Remote access
```

**Grant privileges:**
```sql
-- Database level
GRANT ALL PRIVILEGES ON mydb.* TO 'alice'@'localhost';

-- Table level
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.users TO 'alice'@'localhost';

-- Specific privileges
GRANT SELECT, INSERT ON mydb.* TO 'alice'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;
```

**Revoke privileges:**
```sql
REVOKE INSERT, UPDATE, DELETE ON mydb.users FROM 'alice'@'localhost';
FLUSH PRIVILEGES;
```

**Change password:**
```sql
ALTER USER 'alice'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

**Drop user:**
```sql
DROP USER 'alice'@'localhost';
```

**View user privileges:**
```sql
SHOW GRANTS FOR 'alice'@'localhost';
```

### Database Maintenance

**Check tables:**
```sql
CHECK TABLE users;
CHECK TABLE users EXTENDED;
```

**Repair tables:**
```sql
REPAIR TABLE users;
```

**Analyze tables:**
```sql
ANALYZE TABLE users;
```

**Optimize tables:**
```sql
OPTIMIZE TABLE users;
```

---

## Troubleshooting

### Common Issues

**Issue: Can't connect to MySQL server**
```bash
# Check if MySQL is running
sudo systemctl status mysql

# Check listening port
sudo netstat -tlnp | grep 3306

# Check bind address
mysql -u root -p -e "SHOW VARIABLES LIKE 'bind_address';"

# Check error log
sudo tail -f /var/log/mysql/error.log
```

**Issue: Access denied for user**
```sql
-- Check user exists
SELECT User, Host FROM mysql.user WHERE User = 'alice';

-- Check privileges
SHOW GRANTS FOR 'alice'@'localhost';

-- Reset root password (if locked out)
# 1. Stop MySQL
sudo systemctl stop mysql

# 2. Start with skip-grant-tables
sudo mysqld_safe --skip-grant-tables &

# 3. Connect and reset password
mysql -u root
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';

# 4. Restart MySQL normally
sudo systemctl restart mysql
```

**Issue: Out of disk space**
```bash
# Check disk usage
df -h

# Find large tables
mysql -u root -p -e "
SELECT 
    table_schema,
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
ORDER BY (data_length + index_length) DESC
LIMIT 10;"

# Purge binary logs
mysql -u root -p -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);"

# Optimize tables to reclaim space
mysql -u root -p mydb -e "OPTIMIZE TABLE users;"
```

**Issue: Replication stopped**
```sql
-- Check slave status
SHOW SLAVE STATUS\G

-- Check Last_Error field

-- Skip one error (if safe)
STOP SLAVE;
SET GLOBAL sql_slave_skip_counter = 1;
START SLAVE;

-- Or skip specific error code
SET GLOBAL slave_skip_errors = 1062;  -- Duplicate key error
```

**Issue: Too many connections**
```sql
-- Check current connections
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';

-- Increase max_connections
SET GLOBAL max_connections = 200;

-- Kill idle connections
SELECT CONCAT('KILL ', id, ';')
FROM information_schema.processlist
WHERE command = 'Sleep'
AND time > 300;
```

**Issue: Deadlocks**
```sql
-- View deadlock information
SHOW ENGINE INNODB STATUS\G

-- Look for LATEST DETECTED DEADLOCK section

-- Enable deadlock logging
SET GLOBAL innodb_print_all_deadlocks = ON;
```

---

## Security

### SSL/TLS

**Generate SSL certificates:**
```bash
# Generate CA key and certificate
openssl genrsa 2048 > ca-key.pem
openssl req -new -x509 -nodes -days 3650 -key ca-key.pem -out ca.pem

# Generate server key and certificate
openssl req -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-req.pem
openssl rsa -in server-key.pem -out server-key.pem
openssl x509 -req -in server-req.pem -days 3650 -CA ca.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem

# Generate client key and certificate
openssl req -newkey rsa:2048 -days 3650 -nodes -keyout client-key.pem -out client-req.pem
openssl rsa -in client-key.pem -out client-key.pem
openssl x509 -req -in client-req.pem -days 3650 -CA ca.pem -CAkey ca-key.pem -set_serial 01 -out client-cert.pem
```

**Configure SSL (my.cnf):**
```ini
[mysqld]
ssl-ca=/etc/mysql/ssl/ca.pem
ssl-cert=/etc/mysql/ssl/server-cert.pem
ssl-key=/etc/mysql/ssl/server-key.pem
```

**Require SSL for user:**
```sql
ALTER USER 'alice'@'%' REQUIRE SSL;
FLUSH PRIVILEGES;
```

**Connect with SSL:**
```bash
mysql -u alice -p --ssl-ca=/path/to/ca.pem --ssl-cert=/path/to/client-cert.pem --ssl-key=/path/to/client-key.pem
```

### Audit Logging

**Install audit plugin:**
```sql
INSTALL PLUGIN audit_log SONAME 'audit_log.so';
```

**Configure (my.cnf):**
```ini
[mysqld]
audit_log_policy = ALL
audit_log_format = JSON
audit_log_file = /var/log/mysql/audit.log
```

**View audit logs:**
```bash
tail -f /var/log/mysql/audit.log
```

---

## Upgrade Procedures

### Minor Version Upgrade

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Upgrade MySQL
sudo apt upgrade mysql-server

# Restart
sudo systemctl restart mysql
```

### Major Version Upgrade

**Upgrade from MySQL 5.7 to 8.0:**
```bash
# 1. Backup all databases
mysqldump -u root -p --all-databases > backup_before_upgrade.sql

# 2. Check for incompatibilities
mysqlcheck -u root -p --all-databases --check-upgrade

# 3. Upgrade MySQL packages
sudo apt update
sudo apt install mysql-server-8.0

# 4. Run mysql_upgrade (MySQL 5.7 to 8.0)
sudo mysql_upgrade -u root -p

# 5. Restart MySQL
sudo systemctl restart mysql

# 6. Verify version
mysql -u root -p -e "SELECT VERSION();"
```

---

## References

- **Official Documentation:** https://dev.mysql.com/doc/
- **Performance Tuning:** https://dev.mysql.com/doc/refman/8.0/en/optimization.html
- **Replication:** https://dev.mysql.com/doc/refman/8.0/en/replication.html
- **High Performance MySQL:** Baron Schwartz, Peter Zaitsev, Vadim Tkachenko
- **Percona Toolkit:** https://www.percona.com/software/database-tools/percona-toolkit

---

## Related Documentation

- **Operations Guide:** `docs/guides/persistence_operations_guide__t__.md` - General strategies and concepts
- **Persistence Guide:** `docs/guides/persistence_guide__t__.md` - Choosing storage technologies
- **Cloud Databases Runbook:** `cloud_databases_runbook__t__.md` - AWS RDS/Aurora MySQL
