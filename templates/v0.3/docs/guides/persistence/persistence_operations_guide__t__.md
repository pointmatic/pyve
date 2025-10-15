# Persistence Operations Guide

## Purpose
This guide covers production operations for data persistence systems. It complements `persistence_guide.md` (patterns and architectures) and provides general operational strategies for backup, migration, performance, scaling, availability, security, and cost management.

**For platform-specific commands and procedures**, see the [persistence runbooks](../runbooks/persistence/):
- [PostgreSQL Runbook](../runbooks/persistence/postgresql_runbook__t__.md)
- [MySQL Runbook](../runbooks/persistence/mysql_runbook__t__.md)
- [MongoDB Runbook](../runbooks/persistence/mongodb_runbook__t__.md)
- [Redis Runbook](../runbooks/persistence/redis_runbook__t__.md)
- [Cloud Databases Runbook](../runbooks/persistence/cloud_databases_runbook__t__.md)

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

Backup tools vary by database platform. Choose tools based on your requirements:

**Logical backups:**
- Export data as SQL, JSON, or other portable formats
- Pros: Platform-independent, human-readable, selective restore
- Cons: Slower, larger size, requires database processing
- Examples: pg_dump (PostgreSQL), mysqldump (MySQL), mongodump (MongoDB)

**Physical backups:**
- Copy raw database files
- Pros: Faster, smaller size, exact replica
- Cons: Platform-specific, requires downtime or special tools
- Examples: pg_basebackup (PostgreSQL), Percona XtraBackup (MySQL), filesystem snapshots

**Continuous archiving:**
- Ship transaction logs for point-in-time recovery
- Pros: Minimal data loss (RPO in seconds)
- Cons: Complex setup, requires storage for logs
- Examples: WAL archiving (PostgreSQL), binary logs (MySQL), oplog (MongoDB)

**Managed service backups:**
- Automated backups with configurable retention
- Point-in-time recovery (PITR)
- Cross-region replication
- Examples: AWS RDS, GCP Cloud SQL, Azure Database, MongoDB Atlas

**For specific commands and procedures**, see:
- [PostgreSQL Runbook](../runbooks/persistence/postgresql_runbook__t__.md#backup--recovery)
- [MySQL Runbook](../runbooks/persistence/mysql_runbook__t__.md#backup--recovery)
- [MongoDB Runbook](../runbooks/persistence/mongodb_runbook__t__.md#backup--recovery)
- [Redis Runbook](../runbooks/persistence/redis_runbook__t__.md#backup--recovery)
- [Cloud Databases Runbook](../runbooks/persistence/cloud_databases_runbook__t__.md)

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

**Cloud migration services:**
- **AWS DMS:** Database Migration Service (heterogeneous migrations, continuous replication)
- **GCP Database Migration Service:** MySQL, PostgreSQL to Cloud SQL
- **Azure Database Migration Service:** SQL Server, MySQL, PostgreSQL to Azure

**Schema migration tools:**
- **Flyway:** Version-controlled SQL migrations, rollback support
- **Liquibase:** Database-agnostic migrations, XML/YAML/SQL formats
- **Alembic:** Python-based migrations for SQLAlchemy
- **Django/Rails migrations:** Framework-integrated schema versioning

**Data transformation:**
- **dbt:** SQL-based transformations, testing, documentation
- **Apache Airflow:** Workflow orchestration for complex migrations
- **Talend/Pentaho:** ETL tools for data integration

**Custom scripts:**
- Python (pandas, SQLAlchemy) for data manipulation
- SQL (INSERT INTO ... SELECT) for same-database migrations
- Shell scripts for orchestration

**For platform-specific migration procedures**, see the [persistence runbooks](../runbooks/persistence/).

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

Most databases provide tools to identify slow queries:

**Slow query logging:**
- Enable logging for queries exceeding a threshold (e.g., 1 second)
- Review logs periodically to identify problematic queries
- Examples: PostgreSQL slow query log, MySQL slow query log, MongoDB profiler

**Query statistics:**
- Track query execution time, frequency, and resource usage
- Identify most expensive queries by total time or average time
- Examples: pg_stat_statements (PostgreSQL), performance_schema (MySQL), MongoDB profiler

**Application Performance Monitoring (APM):**
- Instrument application code to track database queries
- Correlate slow queries with application endpoints
- Examples: New Relic, Datadog, AppDynamics

**For platform-specific commands**, see:
- [PostgreSQL Runbook](../runbooks/persistence/postgresql_runbook__t__.md#identifying-slow-queries)
- [MySQL Runbook](../runbooks/persistence/mysql_runbook__t__.md#identifying-slow-queries)
- [MongoDB Runbook](../runbooks/persistence/mongodb_runbook__t__.md#identifying-slow-queries)

#### Query Analysis

**Use EXPLAIN to understand query execution:**
- Shows how the database plans to execute a query
- Identifies missing indexes, inefficient joins, full table scans
- Available in most relational databases (EXPLAIN in SQL, explain() in MongoDB)

**Common issues to look for:**
- **Full table/collection scans:** Database reads all rows instead of using an index
- **Missing indexes:** Queries filter or sort on unindexed columns
- **Unused indexes:** Indexes exist but aren't used by queries
- **Inefficient joins:** Wrong join order, missing indexes on join columns
- **SELECT *:** Fetching unnecessary columns increases I/O and network transfer
- **N+1 queries:** Fetching related data in a loop instead of a single query
- **Large result sets:** Returning too many rows without pagination

**For platform-specific EXPLAIN usage**, see the [persistence runbooks](../runbooks/persistence/).

#### Optimization Techniques

**Indexing strategies:**
- **Single-column indexes:** For queries filtering on one column
- **Composite indexes:** For queries filtering on multiple columns (order matters)
- **Partial indexes:** Index subset of rows matching a condition
- **Covering indexes:** Include all columns needed by query (avoid table lookup)
- **Full-text indexes:** For text search queries
- **Geospatial indexes:** For location-based queries

**Query optimization:**
- **Select only needed columns:** Avoid SELECT *, specify required fields
- **Use JOINs instead of N+1 queries:** Fetch related data in single query
- **Add WHERE clauses:** Filter data at database level, not application
- **Use pagination:** Limit result sets with LIMIT/OFFSET or cursor-based pagination
- **Avoid functions in WHERE:** Index can't be used if column is wrapped in function
- **Use prepared statements:** Reuse query plans, prevent SQL injection

**Caching:**
- Cache query results in application (Redis, Memcached)
- Use materialized views for expensive aggregations
- Cache at CDN level for static data

**For specific indexing commands**, see the [persistence runbooks](../runbooks/persistence/).

### Database Tuning

Database configuration varies by platform, but general principles apply:

**Memory settings:**
- **Buffer pool/cache:** Allocate 50-75% of RAM for database cache
- **Work memory:** Memory per query operation (sort, hash join)
- **Maintenance memory:** Memory for maintenance operations (vacuum, index creation)

**Connection settings:**
- **Max connections:** Limit concurrent connections (typically 100-500)
- **Connection pooling:** Reuse connections to reduce overhead
- **Timeouts:** Close idle connections to free resources

**Storage settings:**
- **Write-ahead logging (WAL):** Configure size and checkpointing
- **Fsync settings:** Balance durability vs. performance
- **Compression:** Enable compression for storage savings

**Query planner:**
- **Statistics:** Keep table statistics up-to-date for optimal query plans
- **Cost parameters:** Tune planner costs for SSD vs. HDD

**For platform-specific configuration**, see:
- [PostgreSQL Runbook](../runbooks/persistence/postgresql_runbook__t__.md#performance-tuning)
- [MySQL Runbook](../runbooks/persistence/mysql_runbook__t__.md#performance-tuning)
- [MongoDB Runbook](../runbooks/persistence/mongodb_runbook__t__.md#performance-tuning)
- [Redis Runbook](../runbooks/persistence/redis_runbook__t__.md#performance-tuning)

#### Connection Pooling

Connection pooling reduces overhead by reusing database connections:

**Database-level pooling:**
- Standalone proxy that pools connections
- Examples: PgBouncer (PostgreSQL), ProxySQL (MySQL)
- Pros: Centralized, language-agnostic, reduces database load
- Cons: Additional component to manage

**Application-level pooling:**
- Built into database drivers/ORMs
- Examples: SQLAlchemy (Python), HikariCP (Java), node-postgres (Node.js)
- Pros: Simple setup, no additional infrastructure
- Cons: Per-application, less efficient for microservices

**Configuration parameters:**
- **Pool size:** Number of persistent connections (typically 10-50)
- **Max overflow:** Additional connections if pool exhausted
- **Timeout:** Wait time for available connection
- **Recycle:** Close and recreate connections after duration

**For specific pooling setup**, see the [persistence runbooks](../runbooks/persistence/).

### Caching Strategies

**Application-level caching:**
- Cache query results in memory (Redis, Memcached)
- Cache at multiple levels (in-process, distributed)
- Set appropriate TTL based on data freshness requirements
- Implement cache invalidation strategy (time-based, event-based)

**Caching patterns:**
- **Cache-aside:** Application checks cache, then database
- **Write-through:** Write to cache and database simultaneously
- **Write-behind:** Write to cache, asynchronously write to database
- **Refresh-ahead:** Proactively refresh cache before expiration

**Database-level caching:**
- **Query result cache:** Database caches query results (MySQL query cache)
- **Materialized views:** Pre-computed query results stored as table
- **Read replicas:** Route read queries to replicas to reduce primary load

**CDN caching:**
- Cache static data at edge locations
- Reduce latency for geographically distributed users
- Examples: CloudFront, Cloudflare, Fastly

**For caching implementation examples**, see the [Redis Runbook](../runbooks/persistence/redis_runbook__t__.md).

### Sharding & Partitioning

**Partitioning (single database):**
- Split large table into smaller partitions
- Partitions stored in same database
- Transparent to application (queries work on partitioned table)
- Types: Range (by date), Hash (even distribution), List (by category)
- Benefits: Improved query performance, easier maintenance, parallel operations

**Sharding (multiple databases):**
- Split data across multiple database instances
- Each shard is independent database
- Application routes queries to correct shard
- Shard key determines data distribution (user_id, tenant_id, geography)
- Benefits: Horizontal scaling, improved performance, isolation

**Sharding strategies:**
- **Hash-based:** Distribute data evenly using hash function
- **Range-based:** Partition by ranges (e.g., user_id 1-1000, 1001-2000)
- **Geography-based:** Shard by region for data locality
- **Directory-based:** Lookup table maps keys to shards

**Challenges:**
- Cross-shard queries (scatter-gather, expensive)
- Rebalancing shards (data migration)
- Distributed transactions (avoid or use saga pattern)
- Hotspots (uneven data distribution)

**For platform-specific partitioning**, see:
- [PostgreSQL Runbook](../runbooks/persistence/postgresql_runbook__t__.md#sharding--partitioning)
- [MongoDB Runbook](../runbooks/persistence/mongodb_runbook__t__.md#sharding)

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

Read replicas improve read performance by distributing read queries across multiple database instances:

**Setup:**
- Configure primary database for replication
- Create replica instances that stream changes from primary
- Route write queries to primary, read queries to replicas

**Replication methods:**
- **Asynchronous:** Replica lags behind primary (eventual consistency)
- **Synchronous:** Replica confirms write before primary acknowledges (strong consistency, higher latency)
- **Semi-synchronous:** Hybrid approach (at least one replica confirms)

**Application routing:**
- Route writes to primary
- Route reads to replicas (with load balancing)
- Read from primary after write if immediate consistency needed

**Considerations:**
- **Replication lag:** Replica may be seconds to minutes behind primary
- **Eventual consistency:** Reads may return stale data
- **Read-after-write consistency:** Read from primary after write to see latest data
- **Failover:** Promote replica to primary if primary fails

**For platform-specific replication setup**, see:
- [PostgreSQL Runbook](../runbooks/persistence/postgresql_runbook__t__.md#replication--high-availability)
- [MySQL Runbook](../runbooks/persistence/mysql_runbook__t__.md#replication--high-availability)
- [MongoDB Runbook](../runbooks/persistence/mongodb_runbook__t__.md#replication--high-availability)
- [Cloud Databases Runbook](../runbooks/persistence/cloud_databases_runbook__t__.md)

#### Sharding

**Challenges:**
- Cross-shard queries (scatter-gather, slow)
- Rebalancing (data migration)
- Distributed transactions (avoid or use saga pattern)
- Hotspots (uneven distribution)

### Auto-Scaling

**Managed service auto-scaling:**
- Automatically adjust compute and storage based on load
- Pay-per-use pricing (serverless options)
- Examples: Aurora Serverless, DynamoDB on-demand, BigQuery, Cosmos DB serverless

**Self-managed auto-scaling:**
- Monitor metrics (CPU, memory, connections, query latency)
- Add/remove read replicas based on load
- Scale vertically (instance size) during maintenance windows
- Use infrastructure as code (Terraform, CloudFormation) for automation

**Auto-scaling strategies:**
- **Reactive:** Scale based on current metrics (CPU >80%, add replica)
- **Predictive:** Scale based on historical patterns (scale up before peak hours)
- **Scheduled:** Scale at specific times (scale up during business hours)

**Considerations:**
- Scaling lag (time to provision new instances)
- Connection draining (gracefully close connections before scaling down)
- Cost optimization (balance performance vs. cost)

**For cloud-specific auto-scaling**, see the [Cloud Databases Runbook](../runbooks/persistence/cloud_databases_runbook__t__.md).

---

## High Availability

### Replication

Replication provides high availability and disaster recovery by maintaining multiple copies of data:

**Synchronous replication:**
- Write confirmed only after replica(s) acknowledge
- **Pros:** Strong consistency, no data loss
- **Cons:** Higher latency (wait for replica), reduced availability if replica fails
- **Use for:** Financial transactions, critical data

**Asynchronous replication:**
- Write confirmed immediately, replica catches up
- **Pros:** Lower latency, higher availability
- **Cons:** Eventual consistency, potential data loss if primary fails
- **Use for:** Most web applications, read-heavy workloads

**Semi-synchronous replication:**
- Write confirmed after at least one replica acknowledges
- **Pros:** Balance between consistency and performance
- **Cons:** More complex configuration
- **Use for:** Important but not critical data

**For platform-specific replication configuration**, see the [persistence runbooks](../runbooks/persistence/).

### Failover

Failover is the process of switching to a standby database when the primary fails:

**Automatic failover:**
- Detect primary failure through health checks
- Elect new primary using consensus algorithm
- Promote replica to primary
- Redirect application traffic to new primary
- Rejoin old primary as replica when recovered

**Failover tools:**
- **Self-managed:** Patroni (PostgreSQL), MHA (MySQL), Redis Sentinel, MongoDB replica sets
- **Managed services:** AWS RDS Multi-AZ, GCP Cloud SQL HA, Azure Database HA (automatic)

**Failover considerations:**
- **Split-brain:** Two nodes think they're primary (use fencing/STONITH to prevent)
- **Data loss:** Asynchronous replication may lose recent writes (use synchronous for zero data loss)
- **Failover time:** Typically 30-60 seconds for automatic failover
- **Application impact:** Connection errors during failover (implement retry logic)

**Manual failover:**
- Planned maintenance or testing
- Controlled promotion of replica
- Verify data consistency before switching traffic

**For platform-specific failover procedures**, see the [persistence runbooks](../runbooks/persistence/).

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
- Encrypt data transmitted between client and database
- Use SSL/TLS for all connections
- Enforce encryption (reject non-encrypted connections)
- Use certificate validation to prevent man-in-the-middle attacks
- Examples: SSL/TLS for PostgreSQL/MySQL, TLS for MongoDB/Redis

**For platform-specific encryption setup**, see the [persistence runbooks](../runbooks/persistence/).

### Access Control

**Authentication:**
- Username/password
- IAM roles (AWS, GCP)
- Certificate-based (mTLS)
- SSO/SAML

**Authorization (RBAC):**
- Create roles with specific permissions (read, write, admin)
- Assign roles to users (principle of least privilege)
- Grant permissions at database, schema, table, or column level
- Use groups/roles for easier management

**Row-Level Security (RLS):**
- Control which rows users can access
- Implement multi-tenancy (users see only their data)
- Define policies based on user attributes
- Available in PostgreSQL, some managed services

**For platform-specific access control**, see the [persistence runbooks](../runbooks/persistence/).

### Audit Logging

**What to log:**
- Authentication attempts
- Schema changes (DDL)
- Data access (SELECT on sensitive tables)
- Data modifications (INSERT, UPDATE, DELETE)
- Permission changes (GRANT, REVOKE)

**Tools:**
- **Self-managed:** pgaudit (PostgreSQL), audit plugin (MySQL), audit logging (MongoDB)
- **Managed services:** CloudTrail (AWS), Cloud Audit Logs (GCP), Azure Monitor (Azure)
- **Third-party:** Splunk, Datadog, Sumo Logic

**For platform-specific audit logging**, see the [persistence runbooks](../runbooks/persistence/).

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

