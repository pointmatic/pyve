# Persistence Operations Guide

## Purpose
This guide covers production operations for data persistence systems. It complements `persistence_guide.md` (patterns and architectures) and provides operational procedures for backup, migration, performance, scaling, availability, security, and cost management.

## Scope
- Backup and recovery strategies
- Data migration procedures
- Performance optimization techniques
- Scalability strategies (vertical and horizontal)
- High availability and disaster recovery
- Security and governance
- Data lifecycle management
- Cost optimization

---

## Backup & Recovery

### Backup Strategies

#### Backup Types

**Full backup:** Complete copy of database
- **Pros:** Simple to restore, complete snapshot
- **Cons:** Slow, large storage requirements
- **Use for:** Weekly or monthly backups

**Incremental backup:** Changes since last backup (any type)
- **Pros:** Fast, small storage requirements
- **Cons:** Complex restore (need full + all incrementals)
- **Use for:** Hourly or daily backups

**Differential backup:** Changes since last full backup
- **Pros:** Faster restore than incremental (full + last differential)
- **Cons:** Larger than incremental, grows over time
- **Use for:** Daily backups

**Continuous backup:** Transaction log shipping (point-in-time recovery)
- **Pros:** Minimal data loss (RPO in seconds)
- **Cons:** Complex setup, higher storage costs
- **Use for:** Critical production databases

#### Backup Frequency

**Critical data (financial, healthcare):**
- Full: Daily
- Incremental: Every 15-60 minutes
- Transaction logs: Continuous

**Production data:**
- Full: Daily
- Incremental: Hourly
- Transaction logs: Every 5-15 minutes

**Development/staging:**
- Full: Weekly
- Incremental: Daily or on-demand

#### Retention Policies

**Short-term (operational recovery):**
- 7-30 days of full backups
- Use for: Accidental deletions, corruption, rollback

**Long-term (compliance, audits):**
- 1-7 years of monthly backups
- Use for: Regulatory requirements, historical analysis

**Archival (legal requirements):**
- Permanent retention
- Use for: Legal holds, industry regulations (HIPAA, SOX)

### Backup Tools

#### Relational Databases

**PostgreSQL:**
```bash
# Logical backup (SQL dump)
pg_dump -h localhost -U postgres -d mydb > backup.sql

# Physical backup (binary)
pg_basebackup -h localhost -U postgres -D /backup/dir -Ft -z -P

# Continuous archiving (WAL)
# Configure postgresql.conf:
# wal_level = replica
# archive_mode = on
# archive_command = 'cp %p /archive/%f'
```

**MySQL:**
```bash
# Logical backup
mysqldump -u root -p mydb > backup.sql

# Physical backup (Percona XtraBackup)
xtrabackup --backup --target-dir=/backup/dir
xtrabackup --prepare --target-dir=/backup/dir
```

**Managed services:**
- **AWS RDS:** Automated daily backups, 1-35 day retention, point-in-time recovery
- **GCP Cloud SQL:** Automated daily backups, 7-365 day retention, point-in-time recovery
- **Azure Database:** Automated backups, 7-35 day retention, geo-redundant backups

#### NoSQL Databases

**MongoDB:**
```bash
# Logical backup
mongodump --uri="mongodb://localhost:27017/mydb" --out=/backup/dir

# Restore
mongorestore --uri="mongodb://localhost:27017/mydb" /backup/dir

# Managed: MongoDB Atlas automated backups
```

**Redis:**
```bash
# RDB snapshot (point-in-time)
# Configure redis.conf:
# save 900 1      # Save after 900s if 1 key changed
# save 300 10     # Save after 300s if 10 keys changed
# save 60 10000   # Save after 60s if 10000 keys changed

# AOF (append-only file, more durable)
# Configure redis.conf:
# appendonly yes
# appendfsync everysec

# Manual snapshot
redis-cli BGSAVE
```

**Cassandra:**
```bash
# Snapshot (per-node)
nodetool snapshot -t backup_name keyspace_name

# Restore
# 1. Stop Cassandra
# 2. Copy snapshot files to data directory
# 3. Start Cassandra
```

#### Object Storage

**S3:**
```bash
# Enable versioning (keeps all versions of objects)
aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled

# Cross-region replication
aws s3api put-bucket-replication --bucket my-bucket --replication-configuration file://replication.json

# Lifecycle policy (automatic archival)
aws s3api put-bucket-lifecycle-configuration --bucket my-bucket --lifecycle-configuration file://lifecycle.json
```

### Recovery Procedures

#### Recovery Objectives

**RTO (Recovery Time Objective):** Maximum acceptable downtime
- **Tier 1 (Critical):** <15 minutes
- **Tier 2 (Important):** <1 hour
- **Tier 3 (Standard):** <4 hours
- **Tier 4 (Low priority):** <24 hours

**RPO (Recovery Point Objective):** Maximum acceptable data loss
- **Tier 1 (Critical):** <5 minutes (continuous backup)
- **Tier 2 (Important):** <1 hour (incremental backups)
- **Tier 3 (Standard):** <24 hours (daily backups)
- **Tier 4 (Low priority):** <7 days (weekly backups)

#### Recovery Steps

1. **Assess damage**
   - Identify what data is lost or corrupted
   - Determine scope (single table, database, entire system)
   - Estimate data loss window

2. **Select backup**
   - Choose most recent backup before corruption
   - Balance RPO (data loss) vs RTO (recovery time)
   - Verify backup integrity before restore

3. **Restore data**
   - Execute restore procedure (see backup tool commands)
   - Restore to staging environment first (if time permits)
   - Apply transaction logs for point-in-time recovery

4. **Verify integrity**
   - Check row counts, checksums
   - Run sample queries to validate data
   - Test application functionality

5. **Resume operations**
   - Bring system back online
   - Monitor for issues
   - Notify stakeholders

6. **Post-mortem**
   - Document incident timeline
   - Identify root cause
   - Update procedures to prevent recurrence

#### Testing Backups

**Quarterly restore tests:**
- Restore to non-production environment
- Measure actual RTO (time to restore)
- Verify data integrity
- Document any issues

**Disaster recovery drills:**
- Simulate complete system failure
- Practice full recovery procedure
- Involve entire team
- Update runbooks based on learnings

---

## Data Migration

### Migration Strategies

#### Big Bang Migration

**Approach:** Switch all at once during maintenance window

**Pros:**
- Simple, clean cutover
- No dual-write complexity

**Cons:**
- Downtime required
- High risk
- Difficult to rollback

**Use when:** Downtime acceptable, small dataset (<100GB)

#### Phased Migration

**Approach:** Migrate in stages (by feature, user segment, geography)

**Pros:**
- Lower risk
- Incremental validation
- Can rollback individual phases

**Cons:**
- Complex dual-write period
- Longer timeline

**Use when:** Zero downtime required, large dataset (>1TB)

#### Parallel Run

**Approach:** Run old and new systems simultaneously

**Pros:**
- Validate with production traffic
- Easy rollback

**Cons:**
- Expensive (double resources)
- Data sync complexity

**Use when:** Mission-critical system, high risk

#### Strangler Pattern

**Approach:** Gradually replace old system (feature by feature)

**Pros:**
- Continuous delivery
- Low risk

**Cons:**
- Very long transition
- Complex routing

**Use when:** Modernizing legacy system

### Migration Tools

- **AWS DMS:** Database Migration Service (heterogeneous migrations)
- **GCP Database Migration Service:** MySQL, PostgreSQL to Cloud SQL
- **Flyway/Liquibase:** Schema migrations
- **dbt:** Data transformation
- **Custom scripts:** Python, SQL, ETL tools

### Migration Best Practices

**Pre-migration:**
- Test on production-like data (anonymized)
- Measure baseline performance
- Document rollback procedure
- Set success criteria

**During migration:**
- Monitor resource usage
- Validate data incrementally
- Keep stakeholders informed
- Have rollback plan ready

**Post-migration:**
- Verify data integrity
- Compare performance
- Monitor for issues
- Document lessons learned

---

## Performance Optimization

### Query Optimization

#### Identifying Slow Queries

**PostgreSQL:**
```sql
-- Enable slow query logging
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries >1s
SELECT pg_reload_conf();

-- View slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

**MySQL:**
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;

-- View slow queries
SELECT * FROM mysql.slow_log
ORDER BY query_time DESC
LIMIT 10;
```

#### Query Analysis

**Use EXPLAIN to understand execution:**

```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'alice@example.com';

-- Look for:
-- - Seq Scan (bad, should use index)
-- - Index Scan (good)
-- - Nested Loop (can be slow for large datasets)
-- - Hash Join (good for large datasets)
```

**Common issues:**
- Missing indexes
- Unused indexes
- Inefficient joins
- SELECT * (fetching unnecessary columns)
- N+1 queries

#### Optimization Techniques

**Add indexes:**
```sql
-- Single column index
CREATE INDEX idx_users_email ON users(email);

-- Composite index
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Partial index
CREATE INDEX idx_active_users ON users(email) WHERE active = true;

-- Covering index
CREATE INDEX idx_users_email_name ON users(email) INCLUDE (name);
```

**Optimize queries:**
```sql
-- Bad: SELECT *
SELECT * FROM users WHERE id = 1;

-- Good: Select only needed columns
SELECT id, name, email FROM users WHERE id = 1;

-- Bad: N+1 queries
SELECT * FROM users;
-- Then for each: SELECT * FROM orders WHERE user_id = ?

-- Good: JOIN
SELECT users.*, orders.*
FROM users
LEFT JOIN orders ON orders.user_id = users.id;
```

### Database Tuning

#### PostgreSQL Configuration

```ini
# Memory settings (for 16GB RAM server)
shared_buffers = 4GB              # 25% of RAM
effective_cache_size = 12GB       # 75% of RAM
work_mem = 64MB                   # Per query operation
maintenance_work_mem = 1GB        # For VACUUM, CREATE INDEX

# Connection settings
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'

# WAL settings
wal_buffers = 16MB
checkpoint_completion_target = 0.9
```

#### MySQL Configuration

```ini
# Memory settings (for 16GB RAM server)
innodb_buffer_pool_size = 12GB    # 70-80% of RAM
innodb_log_file_size = 512MB
innodb_flush_log_at_trx_commit = 2

# Connection settings
max_connections = 150
thread_cache_size = 16
```

#### Connection Pooling

**PgBouncer (PostgreSQL):**
```ini
[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

**Application-level (Python):**
```python
from sqlalchemy import create_engine

engine = create_engine(
    'postgresql://user:pass@localhost/mydb',
    pool_size=20,
    max_overflow=10,
    pool_timeout=30,
    pool_recycle=3600
)
```

### Caching Strategies

**Application-level:**
```python
import redis
import json

cache = redis.Redis(host='localhost', port=6379)

def get_user(user_id):
    # Check cache
    cached = cache.get(f'user:{user_id}')
    if cached:
        return json.loads(cached)
    
    # Query database
    user = db.query(User).filter(User.id == user_id).first()
    
    # Store in cache (TTL 1 hour)
    cache.setex(f'user:{user_id}', 3600, json.dumps(user))
    
    return user
```

**Database-level (materialized views):**
```sql
-- Create materialized view
CREATE MATERIALIZED VIEW user_stats AS
SELECT user_id, COUNT(*) as order_count, SUM(total) as total_spent
FROM orders
GROUP BY user_id;

-- Refresh periodically
REFRESH MATERIALIZED VIEW user_stats;

-- Query (fast)
SELECT * FROM user_stats WHERE user_id = 123;
```

### Sharding & Partitioning

**Partitioning (single database):**
```sql
-- Range partitioning by date
CREATE TABLE orders (
    id SERIAL,
    user_id INT,
    created_at TIMESTAMP,
    total DECIMAL
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_01 PARTITION OF orders
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

**Sharding (multiple databases):**
```python
def get_shard(user_id):
    """Route user to shard based on ID"""
    shard_count = 4
    shard_id = user_id % shard_count
    return shard_connections[shard_id]

def get_user(user_id):
    shard = get_shard(user_id)
    return shard.query(User).filter(User.id == user_id).first()
```

---

## Scalability Strategies

### Vertical Scaling (Scale Up)

**Approach:** Increase resources of single server (CPU, RAM, disk)

**Pros:**
- Simple (no code changes)
- No distributed system complexity
- ACID guarantees preserved

**Cons:**
- Limited by hardware
- Single point of failure
- Downtime during resize

**When to use:** Small to medium workloads (<10k QPS), ACID requirements

### Horizontal Scaling (Scale Out)

#### Read Replicas

**Setup (PostgreSQL):**
```bash
# On primary, enable replication
# postgresql.conf:
wal_level = replica
max_wal_senders = 3

# Create replication user
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'password';

# On replica
pg_basebackup -h primary-host -D /var/lib/postgresql/data -U replicator -P
pg_ctl start
```

**Application routing:**
```python
# Write to primary
primary_db.execute("INSERT INTO users ...")

# Read from replica
replica_db.execute("SELECT * FROM users ...")
```

**Considerations:**
- Replication lag (seconds to minutes)
- Eventual consistency
- Read-after-write consistency (read from primary after write)

#### Sharding

**Challenges:**
- Cross-shard queries (scatter-gather, slow)
- Rebalancing (data migration)
- Distributed transactions (avoid or use saga pattern)
- Hotspots (uneven distribution)

### Auto-Scaling

**Managed services:**
- **AWS Aurora Serverless:** Auto-scales compute based on load
- **DynamoDB:** Auto-scales read/write capacity
- **BigQuery:** Serverless, auto-scales compute

**Self-managed:**
```python
# Monitor and scale read replicas
if cpu_usage > 80%:
    add_read_replica()

if cpu_usage < 20% and replica_count > min_replicas:
    remove_read_replica()
```

---

## High Availability

### Replication

**Synchronous replication:**
- Write confirmed after replica acknowledges
- Strong consistency (no data loss)
- Higher latency

**Asynchronous replication:**
- Write confirmed immediately
- Eventual consistency
- Lower latency

**Configuration (PostgreSQL):**
```ini
# Synchronous
synchronous_commit = on
synchronous_standby_names = 'replica1,replica2'

# Asynchronous
synchronous_commit = off
```

### Failover

**Automatic failover tools:**
- **Patroni (PostgreSQL):** With etcd/Consul/ZooKeeper
- **MHA (MySQL):** Master High Availability
- **Managed services:** RDS, Cloud SQL (built-in)

**Failover process:**
1. Detect primary failure (health checks)
2. Elect new primary (consensus)
3. Promote replica to primary
4. Redirect traffic
5. Rejoin old primary as replica

**Considerations:**
- **Split-brain:** Two nodes think they're primary (use fencing)
- **Data loss:** Async replication may lose recent writes
- **Failover time:** 30-60 seconds

### Multi-Region Deployments

**Active-passive:**
- Primary region serves traffic
- Secondary on standby
- Failover if primary fails

**Active-active:**
- All regions serve traffic
- Multi-master replication
- Conflict resolution required

**Read replicas in multiple regions:**
- Writes to primary region
- Reads from local region
- Lower read latency

---

## Security & Governance

### Encryption

**At rest:**
- **TDE (Transparent Data Encryption):** Encrypt database files
- **Column-level:** Encrypt sensitive columns (SSN, credit card)
- **Application-level:** Encrypt before storing

**In transit:**
```bash
# PostgreSQL: Require SSL
# postgresql.conf
ssl = on
ssl_cert_file = '/path/to/server.crt'
ssl_key_file = '/path/to/server.key'

# Client connection
psql "postgresql://user@host/db?sslmode=require"
```

### Access Control

**Authentication:**
- Username/password
- IAM roles (AWS, GCP)
- Certificate-based (mTLS)
- SSO/SAML

**Authorization (RBAC):**
```sql
-- Create roles
CREATE ROLE readonly;
CREATE ROLE readwrite;
CREATE ROLE admin;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO readwrite;
GRANT ALL PRIVILEGES ON DATABASE mydb TO admin;

-- Assign role to user
GRANT readonly TO alice;
```

**Row-Level Security (PostgreSQL):**
```sql
-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: users see only their orders
CREATE POLICY user_orders ON orders
FOR SELECT
USING (user_id = current_user_id());
```

### Audit Logging

**What to log:**
- Authentication attempts
- Schema changes (DDL)
- Data access (SELECT on sensitive tables)
- Data modifications (INSERT, UPDATE, DELETE)
- Permission changes (GRANT, REVOKE)

**Tools:**
- **PostgreSQL:** `pgaudit` extension
- **MySQL:** Audit plugin
- **Managed services:** CloudTrail, Cloud Audit Logs

### Compliance

**GDPR:**
- Right to be forgotten (delete user data)
- Data portability (export user data)
- Consent management

**HIPAA:**
- Encrypt PHI (Protected Health Information)
- Access controls
- Audit logs

**PCI DSS:**
- Never store CVV
- Encrypt cardholder data
- Restrict access

**SOC 2:**
- Security controls
- Availability controls
- Confidentiality controls

---

## Data Lifecycle Management

### Storage Tiers

**Hot storage:** Frequently accessed, high cost, low latency
- Active data, recent transactions
- SSD storage

**Warm storage:** Occasionally accessed, medium cost
- Historical data (last 90 days)
- Standard storage

**Cold storage:** Rarely accessed, low cost, high latency
- Archives (>1 year old)
- S3 Glacier, Azure Archive

**Glacier/Archive:** Almost never accessed, very low cost
- Legal holds, regulatory requirements

### Lifecycle Policies

**Automatic transitions:**
```bash
# S3 Lifecycle policy
{
  "Rules": [{
    "Status": "Enabled",
    "Transitions": [
      {"Days": 30, "StorageClass": "STANDARD_IA"},
      {"Days": 90, "StorageClass": "GLACIER"},
      {"Days": 365, "StorageClass": "DEEP_ARCHIVE"}
    ],
    "Expiration": {"Days": 2555}
  }]
}
```

**Database partitioning:**
```sql
-- Drop old partitions
DROP TABLE orders_2023_01;
```

### Data Deletion

**Soft delete:** Mark as deleted, keep data
```sql
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP;
UPDATE users SET deleted_at = NOW() WHERE id = 123;

-- Query active users
SELECT * FROM users WHERE deleted_at IS NULL;
```

**Hard delete:** Permanently remove
```sql
DELETE FROM users WHERE id = 123;
```

**Anonymization:** Remove PII, keep aggregated data
```sql
UPDATE users
SET email = 'deleted@example.com',
    name = 'Deleted User',
    phone = NULL
WHERE id = 123;
```

---

## Cost Management

### Cost Optimization Strategies

**Right-size resources:**
- Monitor actual usage (CPU, memory, IOPS)
- Downsize over-provisioned databases
- Use burstable instances for variable workloads

**Use reserved capacity:**
- **Reserved instances:** 30-70% discount for 1-3 year commitment
- **Savings plans:** Flexible commitment-based discounts

**Optimize storage:**
- Delete unused data
- Compress data
- Use appropriate storage tiers

**Optimize queries:**
- Cache frequent queries
- Use read replicas
- Optimize indexes

**Monitor costs:**
- Set budget alerts (50%, 80%, 100%)
- Tag resources for cost allocation
- Review cost reports monthly

### Pricing Models

**Managed databases:**
- **Instance-based:** Pay for instance size (RDS, Cloud SQL)
- **Serverless:** Pay per request/compute time (Aurora Serverless, DynamoDB)
- **Storage + compute:** Separate billing (Snowflake, BigQuery)

**Self-managed:**
- **Compute:** EC2, GCE, Azure VMs
- **Storage:** EBS, Persistent Disk
- **Backup:** S3, GCS, Blob Storage
- **Data transfer:** Egress fees (expensive)

**Cost comparison:**
- **Managed:** 2-3x more expensive than self-managed
- **Serverless:** Cost-effective for variable workloads
- **Self-managed:** Cheaper but requires expertise

---

## References

- **PostgreSQL Performance:** https://www.postgresql.org/docs/current/performance-tips.html
- **MySQL Performance:** https://dev.mysql.com/doc/refman/8.0/en/optimization.html
- **Database Reliability Engineering:** Charity Majors, Laine Campbell
- **Designing Data-Intensive Applications:** Martin Kleppmann
- **High Performance MySQL:** Baron Schwartz, Peter Zaitsev, Vadim Tkachenko
- **AWS Well-Architected Framework:** https://aws.amazon.com/architecture/well-architected/
- **Google Cloud Architecture Framework:** https://cloud.google.com/architecture/framework

---

## Next Steps

- **Patterns and architectures:** See `persistence_guide.md` for choosing storage technologies and data modeling
- **Platform selection:** See `docs/specs/implementation_options_spec.md` for managed vs self-managed trade-offs
- **As-built documentation:** Document operational procedures in `docs/specs/codebase_spec.md`
- **Testing:** See `docs/guides/testing_guide.md` for database testing strategies

