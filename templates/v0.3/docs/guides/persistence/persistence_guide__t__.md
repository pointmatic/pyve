# Persistence Guide

## Purpose
This guide establishes patterns and best practices for choosing and modeling data persistence. It complements `persistence_operations_guide.md` (production operations) and the architectural decisions in `docs/specs/implementation_options_spec.md`.

## Scope
- Decision frameworks for choosing storage technologies
- Data storage patterns and architectures
- Data modeling and schema design
- When to use each persistence technology

---

## Choosing a Persistence Strategy

### Decision Matrix

Consider these factors when selecting storage technologies:

| Factor | Questions to Ask |
|--------|-----------------|
| **Data Structure** | Structured (tables) vs semi-structured (JSON) vs unstructured (blobs/files)? |
| **Access Patterns** | OLTP (transactional) vs OLAP (analytical) vs caching (fast reads)? |
| **Consistency** | ACID guarantees vs eventual consistency acceptable? |
| **Scale** | Single-node vs distributed? Read-heavy vs write-heavy? |
| **Query Complexity** | Simple key-value vs complex joins vs full-text search vs graph traversal? |
| **Latency** | <10ms (cache) vs <100ms (database) vs seconds (warehouse)? |
| **Durability** | Ephemeral (cache) vs persistent (database) vs archival (cold storage)? |
| **Cost** | Budget constraints? Managed vs self-managed trade-offs? |

### Common Architecture Patterns

#### Web Application (CRUD)
- **Primary:** PostgreSQL or MySQL (relational database)
- **Cache:** Redis or Memcached (in-memory cache)
- **Files:** S3, GCS, or Azure Blob Storage (object storage)
- **Sessions:** Redis (key-value store)

#### Analytics Platform
- **OLTP:** PostgreSQL (operational data)
- **OLAP:** BigQuery, Snowflake, or Redshift (data warehouse)
- **ETL:** Airflow or dbt (data pipelines)
- **Visualization:** Looker, Tableau, or Metabase

#### Real-Time / Event-Driven
- **Events:** Kafka or Pulsar (message queue)
- **Writes:** Cassandra or ScyllaDB (high-throughput writes)
- **Search:** Elasticsearch or Meilisearch (full-text search)
- **Metrics:** Prometheus or InfluxDB (time-series)

#### Microservices
- **Per-service databases:** Each service owns its data store
- **Event bus:** Kafka or RabbitMQ for inter-service communication
- **API gateway:** Centralized access control
- **Service mesh:** Distributed tracing and observability

---

## Data Storage Patterns

### Relational Databases (OLTP)

**Use cases:** Transactional workloads, complex queries, ACID guarantees, structured data with relationships.

**Technologies:**
- **PostgreSQL:** Feature-rich, extensible, strong community, JSON support
- **MySQL:** Fast reads, wide adoption, simpler than PostgreSQL
- **SQLite:** Embedded, serverless, great for local dev and mobile apps
- **CockroachDB:** Distributed SQL, horizontally scalable, cloud-native

**Strengths:**
- ACID transactions ensure data consistency
- Rich query language (SQL) with joins, aggregations, subqueries
- Mature tooling and ecosystem
- Schema enforcement and data integrity constraints

**Weaknesses:**
- Vertical scaling limits (single-node bottleneck)
- Schema changes can be complex (migrations)
- Horizontal scaling requires sharding (complex)

**Best Practices:**
- Normalize for consistency, denormalize for performance (selectively)
- Use indexes strategically (balance read speed vs write overhead)
- Implement connection pooling (PgBouncer, ProxySQL)
- Monitor slow queries and optimize with EXPLAIN ANALYZE
- Use read replicas for read-heavy workloads

### NoSQL Databases

#### Key-Value Stores

**Use cases:** Caching, session storage, simple lookups, high-throughput writes.

**Technologies:**
- **Redis:** In-memory, fast, supports data structures (lists, sets, sorted sets)
- **Memcached:** Simple, fast, distributed caching
- **DynamoDB:** AWS managed, serverless, auto-scaling
- **etcd:** Distributed configuration and service discovery

**Strengths:**
- Extremely fast (sub-millisecond latency)
- Simple API (GET, SET, DELETE)
- Horizontal scaling
- High availability with replication

**Weaknesses:**
- Limited query capabilities (no joins, aggregations)
- Data modeling requires careful key design
- Memory constraints (for in-memory stores)

**Best Practices:**
- Use for ephemeral data (caching) or simple lookups
- Set TTLs (time-to-live) to auto-expire stale data
- Use Redis persistence (RDB/AOF) for durability if needed
- Monitor memory usage and eviction policies

#### Document Stores

**Use cases:** Semi-structured data, flexible schemas, JSON documents, content management.

**Technologies:**
- **MongoDB:** Popular, flexible schema, rich query language
- **CouchDB:** Multi-master replication, offline-first
- **Firestore:** Google managed, real-time sync, mobile-friendly
- **DocumentDB:** AWS managed, MongoDB-compatible

**Strengths:**
- Flexible schema (no migrations for schema changes)
- Natural fit for JSON/BSON data
- Horizontal scaling with sharding
- Rich query capabilities (filters, aggregations)

**Weaknesses:**
- Eventual consistency in distributed setups
- No joins (requires denormalization or application-level joins)
- Can lead to data duplication

**Best Practices:**
- Embed related data for read performance (denormalize)
- Use references for large or frequently updated data
- Index frequently queried fields
- Monitor document size (avoid unbounded arrays)

#### Graph Databases

**Use cases:** Social networks, recommendation engines, fraud detection, knowledge graphs.

**Technologies:**
- **Neo4j:** Most popular, Cypher query language, ACID
- **Amazon Neptune:** AWS managed, supports Gremlin and SPARQL
- **ArangoDB:** Multi-model (graph, document, key-value)
- **Dgraph:** Distributed, GraphQL-native

**Strengths:**
- Efficient traversal of relationships (vs JOIN-heavy SQL)
- Natural modeling of connected data
- Pattern matching and path finding

**Weaknesses:**
- Niche use case (not general-purpose)
- Smaller ecosystem than relational databases
- Scaling can be complex

**Best Practices:**
- Model relationships as first-class entities
- Use graph algorithms (shortest path, PageRank, community detection)
- Index node properties for fast lookups
- Limit traversal depth to avoid performance issues

#### Wide-Column Stores

**Use cases:** Massive scale, high write throughput, time-series data, IoT.

**Technologies:**
- **Cassandra:** Distributed, masterless, tunable consistency
- **ScyllaDB:** Cassandra-compatible, C++ rewrite, higher performance
- **HBase:** Hadoop ecosystem, strong consistency
- **Bigtable:** Google managed, powers Google Search and Maps

**Strengths:**
- Linear horizontal scaling (add nodes for more capacity)
- High write throughput
- Tunable consistency (CAP theorem trade-offs)
- No single point of failure

**Weaknesses:**
- Eventual consistency (by default)
- Limited query capabilities (no joins, limited filtering)
- Data modeling requires understanding of partition keys

**Best Practices:**
- Design partition keys to distribute data evenly
- Avoid hot partitions (uneven data distribution)
- Use time-series data patterns (bucketing by time)
- Monitor compaction and repair operations

### Caching

**Use cases:** Reduce database load, speed up reads, session storage, rate limiting.

**Technologies:**
- **Redis:** Feature-rich, supports complex data structures, persistence
- **Memcached:** Simple, fast, distributed, no persistence
- **Varnish:** HTTP caching, reverse proxy
- **CDN:** Cloudflare, Fastly, CloudFront (edge caching)

**Strategies:**
- **Cache-aside (lazy loading):** App checks cache, loads from DB on miss, writes to cache
- **Write-through:** App writes to cache and DB simultaneously
- **Write-behind (write-back):** App writes to cache, async writes to DB
- **Refresh-ahead:** Proactively refresh cache before expiration

**Best Practices:**
- Set appropriate TTLs (balance freshness vs hit rate)
- Use cache invalidation strategies (time-based, event-based)
- Monitor cache hit rate (aim for >80%)
- Handle cache failures gracefully (fallback to DB)
- Use cache warming for predictable workloads

### Object Storage

**Use cases:** Files, images, videos, backups, static assets, data lakes.

**Technologies:**
- **Amazon S3:** Industry standard, 99.999999999% durability
- **Google Cloud Storage:** Multi-region, strong consistency
- **Azure Blob Storage:** Hot/cool/archive tiers
- **MinIO:** Self-hosted, S3-compatible, open source
- **Tigris:** Fly.io managed, globally distributed

**Strengths:**
- Unlimited scalability
- High durability (replicated across zones/regions)
- Low cost (especially cold storage tiers)
- HTTP access (CDN-friendly)

**Weaknesses:**
- Higher latency than block storage
- Not suitable for databases or frequent updates
- Eventual consistency for some operations

**Best Practices:**
- Use lifecycle policies (move to cold storage after N days)
- Enable versioning for critical data
- Use presigned URLs for secure temporary access
- Compress and optimize files before upload
- Use CDN for frequently accessed content

### Data Warehouses & Lakes (OLAP)

**Use cases:** Business intelligence, analytics, reporting, data science, historical analysis.

**Technologies:**
- **BigQuery:** Google managed, serverless, SQL, petabyte-scale
- **Snowflake:** Multi-cloud, separation of compute/storage, easy scaling
- **Redshift:** AWS managed, columnar storage, fast queries
- **Databricks:** Unified analytics, Spark-based, data lakehouse
- **ClickHouse:** Open source, columnar, extremely fast for analytics

**Strengths:**
- Optimized for read-heavy analytical queries
- Columnar storage (fast aggregations)
- Handles massive datasets (petabytes)
- Separation of compute and storage (cost-efficient)

**Weaknesses:**
- Not suitable for OLTP (high write latency)
- Higher cost for frequent queries
- Data freshness lag (ETL pipeline delay)

**Best Practices:**
- Use partitioning and clustering for query performance
- Materialize frequently used aggregations (views, tables)
- Optimize data types (use smallest type that fits)
- Monitor query costs (BigQuery, Snowflake charge per query)
- Use incremental loading (avoid full table scans)

### Time-Series Databases

**Use cases:** Metrics, monitoring, IoT sensor data, financial tick data, logs.

**Technologies:**
- **Prometheus:** Metrics collection, alerting, PromQL query language
- **InfluxDB:** Purpose-built for time-series, high write throughput
- **TimescaleDB:** PostgreSQL extension, SQL-compatible
- **Graphite:** Metrics storage, simple, widely used

**Strengths:**
- Optimized for time-stamped data
- Efficient compression (time-series data is repetitive)
- Downsampling and retention policies
- Fast range queries (last 1 hour, last 24 hours)

**Weaknesses:**
- Not general-purpose (limited to time-series use cases)
- Limited query capabilities compared to SQL

**Best Practices:**
- Use appropriate retention policies (downsample old data)
- Tag data for efficient filtering (labels in Prometheus)
- Monitor cardinality (too many unique tag combinations = performance issues)
- Use continuous aggregates for common queries

### Search Engines

**Use cases:** Full-text search, log analysis, product search, autocomplete.

**Technologies:**
- **Elasticsearch:** Popular, distributed, JSON-based, Lucene-powered
- **Meilisearch:** Fast, typo-tolerant, easy to use, open source
- **Typesense:** Fast, typo-tolerant, simpler than Elasticsearch
- **Algolia:** Managed, fast, great developer experience

**Strengths:**
- Full-text search with relevance ranking
- Typo tolerance and fuzzy matching
- Faceted search and filtering
- Near real-time indexing

**Weaknesses:**
- Not a primary data store (eventual consistency)
- Resource-intensive (memory, CPU)
- Complex to operate at scale

**Best Practices:**
- Use as secondary index (primary data in database)
- Reindex from primary data source on failures
- Monitor cluster health and shard allocation
- Use appropriate analyzers for text fields
- Limit result set size (pagination)

### Message Queues & Event Streams

**Use cases:** Asynchronous processing, event-driven architectures, decoupling services, pub/sub.

**Technologies:**
- **Kafka:** High-throughput, durable, distributed, event streaming
- **RabbitMQ:** Flexible routing, multiple protocols, message acknowledgment
- **AWS SQS:** Managed, serverless, simple, reliable
- **Redis Streams:** Lightweight, in-memory, append-only log
- **Pulsar:** Multi-tenancy, geo-replication, unified messaging

**Strengths:**
- Decouple producers and consumers
- Handle traffic spikes (buffering)
- Enable event-driven architectures
- Durable message storage (Kafka, Pulsar)

**Weaknesses:**
- Adds complexity (another system to manage)
- Eventual consistency (messages may be delayed)
- Ordering guarantees vary by technology

**Best Practices:**
- Use idempotent consumers (handle duplicate messages)
- Monitor queue depth (alerts for backlog)
- Set appropriate retention policies
- Use dead-letter queues for failed messages
- Partition for parallelism (Kafka)

---

## Data Modeling & Schema Design

### Relational Database Design

#### Normalization
- **1NF:** Atomic values, no repeating groups
- **2NF:** No partial dependencies (all non-key attributes depend on entire primary key)
- **3NF:** No transitive dependencies (non-key attributes don't depend on other non-key attributes)
- **Denormalization:** Intentionally duplicate data for read performance

**When to normalize:**
- Data consistency is critical
- Write-heavy workloads
- Storage is expensive

**When to denormalize:**
- Read-heavy workloads
- Query performance is critical
- Joins are expensive

#### Indexing Strategies

**Types of indexes:**
- **B-tree:** Default, good for equality and range queries
- **Hash:** Fast equality lookups, no range queries
- **GiST/GIN:** Full-text search, JSON, arrays (PostgreSQL)
- **Covering index:** Include all columns needed by query (avoid table lookup)

**Best practices:**
- Index foreign keys (for joins)
- Index columns in WHERE, ORDER BY, GROUP BY clauses
- Avoid over-indexing (slows writes, wastes space)
- Use composite indexes for multi-column queries
- Monitor index usage (drop unused indexes)

#### Data Types

**Choose appropriate types:**
- **Integers:** Use smallest type that fits (SMALLINT, INT, BIGINT)
- **Decimals:** Use NUMERIC/DECIMAL for money (avoid FLOAT for precision)
- **Strings:** Use VARCHAR with limit, TEXT for unbounded
- **Dates:** Use TIMESTAMP WITH TIME ZONE (avoid storing as strings)
- **JSON:** Use JSONB in PostgreSQL (indexed, efficient)
- **UUIDs:** Use for distributed systems (avoid sequential IDs)

#### Constraints

- **Primary key:** Unique identifier for each row
- **Foreign key:** Enforce referential integrity
- **Unique:** Prevent duplicate values
- **Not null:** Require value (avoid nulls when possible)
- **Check:** Custom validation rules

### NoSQL Data Modeling

#### Document Store Patterns

**Embed vs Reference:**
- **Embed:** Related data accessed together (one-to-few relationships)
- **Reference:** Large or frequently updated data (one-to-many, many-to-many)

**Example (MongoDB):**
```javascript
// Embedded (good for blog post + comments)
{
  _id: ObjectId("..."),
  title: "My Post",
  content: "...",
  comments: [
    { author: "Alice", text: "Great post!" },
    { author: "Bob", text: "Thanks!" }
  ]
}

// Referenced (good for user + many posts)
// User document
{ _id: ObjectId("user1"), name: "Alice" }

// Post documents
{ _id: ObjectId("post1"), author_id: ObjectId("user1"), title: "Post 1" }
{ _id: ObjectId("post2"), author_id: ObjectId("user1"), title: "Post 2" }
```

#### Key-Value Store Patterns

**Key design:**
- Use namespaces: `user:123`, `session:abc`, `cache:product:456`
- Include version: `user:123:v2` (for schema evolution)
- Use hashes for complex keys: `hash(user_id + product_id)`

**Data structures (Redis):**
- **String:** Simple values, counters
- **Hash:** Objects with fields (user profile)
- **List:** Ordered collection (activity feed)
- **Set:** Unique values (tags, followers)
- **Sorted Set:** Ranked data (leaderboard)

### Schema Versioning & Migrations

**Strategies:**
- **Expand-contract:** Add new column, migrate data, remove old column
- **Dual writes:** Write to both old and new schema during transition
- **Feature flags:** Toggle between old and new schema
- **Backward compatibility:** New code reads old schema

**Tools:**
- **Flyway:** Java-based, SQL migrations
- **Liquibase:** XML/YAML/SQL, database-agnostic
- **Alembic:** Python, SQLAlchemy integration
- **Django migrations:** Python, ORM-based
- **Rails migrations:** Ruby, ActiveRecord

**Best practices:**
- Version migrations (sequential numbering or timestamps)
- Test migrations on staging before production
- Make migrations reversible (down migrations)
- Avoid data loss (backup before migration)
- Use transactions (rollback on failure)

---

## References

- **PostgreSQL Documentation:** https://www.postgresql.org/docs/
- **MySQL Documentation:** https://dev.mysql.com/doc/
- **MongoDB Documentation:** https://docs.mongodb.com/
- **Redis Documentation:** https://redis.io/documentation
- **Cassandra Documentation:** https://cassandra.apache.org/doc/
- **Database Design Patterns:** Martin Fowler's Patterns of Enterprise Application Architecture
- **CAP Theorem:** https://en.wikipedia.org/wiki/CAP_theorem
- **Data Modeling Best Practices:** https://www.kimballgroup.com/ (dimensional modeling)

---

## Next Steps

- **Production operations:** See `persistence_operations_guide.md` for backup, migration, performance, scaling, and availability strategies
- **Platform selection:** See `docs/specs/implementation_options_spec.md` for managed vs self-managed trade-offs
- **As-built documentation:** Document chosen persistence technologies in `docs/specs/codebase_spec.md`
