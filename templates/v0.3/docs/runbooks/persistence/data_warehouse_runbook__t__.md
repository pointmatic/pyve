# Data Warehouse Operations Runbook

## Overview

Data warehouses are optimized for analytical queries (OLAP) rather than transactional workloads (OLTP). This runbook covers operational procedures for popular data warehouse platforms.

**Key characteristics:**
- Columnar storage for fast aggregations
- Massively parallel processing (MPP)
- Optimized for read-heavy analytical queries
- Compute/storage separation (cloud warehouses)
- SQL-based querying

**Covered platforms:**
- **ClickHouse** - Open-source, real-time analytics
- **BigQuery** - Google Cloud, serverless
- **Redshift** - AWS, managed MPP
- **Snowflake** - Multi-cloud, elastic compute

---

## ClickHouse

### Overview

ClickHouse is an open-source columnar database for real-time analytics with exceptional performance.

**Key features:**
- Columnar storage
- Real-time data ingestion
- SQL support with extensions
- Distributed queries
- Materialized views
- Multiple table engines

### Installation

**Ubuntu/Debian:**
```bash
sudo apt-get install -y apt-transport-https ca-certificates dirmngr
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

echo "deb https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list
sudo apt-get update

sudo apt-get install -y clickhouse-server clickhouse-client

sudo service clickhouse-server start
```

**Docker:**
```bash
docker run -d --name clickhouse-server \
  -p 8123:8123 -p 9000:9000 \
  --ulimit nofile=262144:262144 \
  clickhouse/clickhouse-server
```

### Table Engines

**MergeTree (most common):**
```sql
CREATE TABLE events (
    event_date Date,
    event_time DateTime,
    user_id UInt32,
    event_type String,
    value Float64
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, user_id);
```

**ReplacingMergeTree (deduplication):**
```sql
CREATE TABLE users (
    user_id UInt32,
    name String,
    email String,
    updated_at DateTime
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY user_id;
```

**Distributed (sharding):**
```sql
CREATE TABLE events_distributed AS events
ENGINE = Distributed(cluster_name, database_name, events, rand());
```

### Data Loading

**INSERT:**
```sql
INSERT INTO events VALUES
    ('2024-01-15', '2024-01-15 10:00:00', 123, 'click', 1.0),
    ('2024-01-15', '2024-01-15 10:01:00', 124, 'view', 2.0);
```

**From CSV:**
```bash
clickhouse-client --query="INSERT INTO events FORMAT CSV" < data.csv
```

**From S3:**
```sql
INSERT INTO events
SELECT * FROM s3(
    'https://bucket.s3.amazonaws.com/data/*.csv',
    'CSVWithNames'
);
```

### Query Optimization

**Use materialized views:**
```sql
CREATE MATERIALIZED VIEW daily_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, event_type)
AS SELECT
    event_date,
    event_type,
    count() as event_count,
    sum(value) as total_value
FROM events
GROUP BY event_date, event_type;
```

**Optimize partitions:**
```sql
-- Merge small parts
OPTIMIZE TABLE events PARTITION 202401;

-- Drop old partitions
ALTER TABLE events DROP PARTITION 202301;
```

### Monitoring

```sql
-- Query performance
SELECT
    query,
    elapsed,
    read_rows,
    read_bytes
FROM system.query_log
WHERE type = 'QueryFinish'
ORDER BY elapsed DESC
LIMIT 10;

-- Table sizes
SELECT
    database,
    table,
    formatReadableSize(sum(bytes)) as size
FROM system.parts
GROUP BY database, table
ORDER BY sum(bytes) DESC;
```

---

## BigQuery

### Overview

BigQuery is Google Cloud's serverless, highly scalable data warehouse with built-in machine learning.

**Key features:**
- Serverless (no infrastructure management)
- Petabyte-scale
- Standard SQL
- Built-in ML (BQML)
- Real-time analytics
- Pay-per-query pricing

### Creating Datasets and Tables

**Via bq CLI:**
```bash
# Create dataset
bq mk --dataset --location=US my_dataset

# Create table
bq mk --table my_dataset.events \
  event_date:DATE,event_time:TIMESTAMP,user_id:INTEGER,event_type:STRING,value:FLOAT

# Load data from CSV
bq load --source_format=CSV \
  my_dataset.events \
  gs://my-bucket/data.csv \
  event_date:DATE,event_time:TIMESTAMP,user_id:INTEGER,event_type:STRING,value:FLOAT
```

**Via SQL:**
```sql
CREATE TABLE my_dataset.events (
  event_date DATE,
  event_time TIMESTAMP,
  user_id INT64,
  event_type STRING,
  value FLOAT64
)
PARTITION BY event_date
CLUSTER BY user_id, event_type;
```

### Partitioning and Clustering

**Partitioned table:**
```sql
CREATE TABLE my_dataset.events
PARTITION BY DATE(event_time)
AS SELECT * FROM source_table;

-- Query specific partition
SELECT * FROM my_dataset.events
WHERE event_time BETWEEN '2024-01-01' AND '2024-01-31';
```

**Clustered table:**
```sql
CREATE TABLE my_dataset.events
PARTITION BY DATE(event_time)
CLUSTER BY user_id, event_type
AS SELECT * FROM source_table;
```

### Query Optimization

**Use partitioning:**
```sql
-- Bad: Full table scan
SELECT * FROM events WHERE event_type = 'click';

-- Good: Partition pruning
SELECT * FROM events
WHERE event_date = '2024-01-15'
AND event_type = 'click';
```

**Avoid SELECT *:**
```sql
-- Bad
SELECT * FROM large_table;

-- Good
SELECT user_id, event_type, value FROM large_table;
```

**Use materialized views:**
```sql
CREATE MATERIALIZED VIEW my_dataset.daily_stats AS
SELECT
  DATE(event_time) as event_date,
  event_type,
  COUNT(*) as event_count,
  SUM(value) as total_value
FROM my_dataset.events
GROUP BY event_date, event_type;
```

### Cost Optimization

**Query cost estimation:**
```sql
-- Dry run to estimate cost
bq query --dry_run 'SELECT * FROM my_dataset.events'
```

**Use clustering and partitioning:**
- Reduces data scanned
- Lowers query costs

**Set maximum bytes billed:**
```sql
-- Fail query if it would scan more than 1TB
bq query --maximum_bytes_billed=1000000000000 'SELECT ...'
```

### Scheduled Queries

```sql
-- Create scheduled query
CREATE OR REPLACE TABLE my_dataset.daily_summary
OPTIONS(
  expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
) AS
SELECT
  DATE(event_time) as event_date,
  COUNT(*) as event_count
FROM my_dataset.events
WHERE DATE(event_time) = CURRENT_DATE() - 1
GROUP BY event_date;
```

---

## Amazon Redshift

### Overview

Redshift is AWS's managed data warehouse based on PostgreSQL with columnar storage and MPP architecture.

**Key features:**
- Columnar storage
- Massively parallel processing
- PostgreSQL-compatible
- Integration with AWS ecosystem
- Redshift Spectrum (query S3 data)

### Creating Cluster

**Via AWS CLI:**
```bash
aws redshift create-cluster \
  --cluster-identifier my-redshift-cluster \
  --node-type dc2.large \
  --master-username admin \
  --master-user-password SecurePassword123 \
  --cluster-type multi-node \
  --number-of-nodes 2 \
  --db-name mydb \
  --vpc-security-group-ids sg-xxxxx \
  --cluster-subnet-group-name my-subnet-group
```

### Table Design

**Distribution styles:**
```sql
-- KEY distribution (join optimization)
CREATE TABLE orders (
    order_id INT,
    user_id INT,
    amount DECIMAL(10,2)
)
DISTKEY(user_id)
SORTKEY(order_id);

-- ALL distribution (small dimension tables)
CREATE TABLE products (
    product_id INT,
    name VARCHAR(255)
)
DISTSTYLE ALL;

-- EVEN distribution (no join key)
CREATE TABLE logs (
    log_id INT,
    message VARCHAR(1000)
)
DISTSTYLE EVEN;
```

**Sort keys:**
```sql
-- Single column sort key
CREATE TABLE events (
    event_time TIMESTAMP,
    user_id INT
)
SORTKEY(event_time);

-- Compound sort key
CREATE TABLE events (
    event_time TIMESTAMP,
    user_id INT,
    event_type VARCHAR(50)
)
COMPOUND SORTKEY(event_time, user_id);

-- Interleaved sort key (multiple query patterns)
CREATE TABLE events (
    event_time TIMESTAMP,
    user_id INT,
    event_type VARCHAR(50)
)
INTERLEAVED SORTKEY(event_time, user_id, event_type);
```

### Data Loading

**COPY from S3:**
```sql
COPY events
FROM 's3://my-bucket/data/'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftRole'
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1
REGION 'us-east-1';
```

**COPY with manifest:**
```sql
COPY events
FROM 's3://my-bucket/manifest.json'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftRole'
MANIFEST;
```

### Maintenance

**VACUUM:**
```sql
-- Reclaim space and sort rows
VACUUM events;

-- Full vacuum
VACUUM FULL events;

-- Delete only
VACUUM DELETE ONLY events;
```

**ANALYZE:**
```sql
-- Update table statistics
ANALYZE events;

-- Analyze specific columns
ANALYZE events (event_time, user_id);
```

### Query Optimization

**Use Redshift Spectrum:**
```sql
-- Create external schema
CREATE EXTERNAL SCHEMA spectrum_schema
FROM DATA CATALOG
DATABASE 'spectrum_db'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftRole';

-- Query S3 data
SELECT *
FROM spectrum_schema.external_table
WHERE year = 2024;
```

**Monitor queries:**
```sql
-- View running queries
SELECT pid, user_name, starttime, query
FROM stv_recents
WHERE status = 'Running';

-- View query execution plan
EXPLAIN SELECT * FROM events WHERE event_time > '2024-01-01';
```

---

## Snowflake

### Overview

Snowflake is a cloud-native data warehouse with unique architecture separating storage, compute, and services.

**Key features:**
- Multi-cloud (AWS, Azure, GCP)
- Automatic scaling
- Zero-copy cloning
- Time travel
- Data sharing
- Semi-structured data support (JSON, Avro, Parquet)

### Creating Database and Warehouse

```sql
-- Create database
CREATE DATABASE my_database;

-- Create warehouse (compute)
CREATE WAREHOUSE my_warehouse
WITH WAREHOUSE_SIZE = 'SMALL'
AUTO_SUSPEND = 300
AUTO_RESUME = TRUE;

-- Use warehouse
USE WAREHOUSE my_warehouse;
```

### Table Design

**Standard table:**
```sql
CREATE TABLE events (
    event_id NUMBER,
    event_time TIMESTAMP,
    user_id NUMBER,
    event_type STRING,
    value FLOAT
);
```

**Clustered table:**
```sql
CREATE TABLE events (
    event_time TIMESTAMP,
    user_id NUMBER,
    event_type STRING
)
CLUSTER BY (event_time, user_id);
```

**External table (query S3/Azure/GCS):**
```sql
CREATE EXTERNAL TABLE events_external
WITH LOCATION = @my_stage/events/
FILE_FORMAT = (TYPE = 'PARQUET');
```

### Data Loading

**COPY INTO from S3:**
```sql
COPY INTO events
FROM s3://my-bucket/data/
CREDENTIALS = (AWS_KEY_ID='...' AWS_SECRET_KEY='...')
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);
```

**Snowpipe (continuous loading):**
```sql
CREATE PIPE events_pipe
AUTO_INGEST = TRUE
AS
COPY INTO events
FROM @my_stage
FILE_FORMAT = (TYPE = 'JSON');
```

### Time Travel

```sql
-- Query historical data
SELECT * FROM events AT(TIMESTAMP => '2024-01-15 10:00:00');

-- Query before statement
SELECT * FROM events BEFORE(STATEMENT => '01a2b3c4-...');

-- Restore table
CREATE TABLE events_restored CLONE events AT(TIMESTAMP => '2024-01-15 10:00:00');
```

### Zero-Copy Cloning

```sql
-- Clone table (instant, no storage cost initially)
CREATE TABLE events_dev CLONE events;

-- Clone database
CREATE DATABASE my_database_dev CLONE my_database;
```

### Query Optimization

**Use clustering:**
```sql
-- Check clustering
SELECT SYSTEM$CLUSTERING_INFORMATION('events', '(event_time, user_id)');

-- Manually cluster
ALTER TABLE events RECLUSTER;
```

**Result caching:**
```sql
-- Disable result cache for query
SELECT * FROM events WHERE event_time > CURRENT_TIMESTAMP();
```

**Materialized views:**
```sql
CREATE MATERIALIZED VIEW daily_stats AS
SELECT
    DATE(event_time) as event_date,
    event_type,
    COUNT(*) as event_count
FROM events
GROUP BY event_date, event_type;
```

### Cost Optimization

**Auto-suspend warehouses:**
```sql
ALTER WAREHOUSE my_warehouse SET AUTO_SUSPEND = 60;
```

**Right-size warehouses:**
```sql
-- Scale up
ALTER WAREHOUSE my_warehouse SET WAREHOUSE_SIZE = 'LARGE';

-- Scale down
ALTER WAREHOUSE my_warehouse SET WAREHOUSE_SIZE = 'SMALL';
```

**Monitor credit usage:**
```sql
SELECT
    warehouse_name,
    SUM(credits_used) as total_credits
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

---

## Common Patterns

### ETL/ELT

**Extract, Transform, Load (ETL):**
- Transform data before loading into warehouse
- Use tools: Apache Airflow, dbt, Fivetran, Stitch

**Extract, Load, Transform (ELT):**
- Load raw data, transform in warehouse
- Leverage warehouse compute power
- More common with modern cloud warehouses

### Incremental Loads

**Append-only:**
```sql
-- Load only new data
INSERT INTO events
SELECT * FROM staging_events
WHERE event_time > (SELECT MAX(event_time) FROM events);
```

**Upsert (merge):**
```sql
-- Snowflake
MERGE INTO events target
USING staging_events source
ON target.event_id = source.event_id
WHEN MATCHED THEN UPDATE SET
    target.value = source.value
WHEN NOT MATCHED THEN INSERT
    (event_id, event_time, value)
VALUES
    (source.event_id, source.event_time, source.value);
```

### Data Modeling

**Star schema:**
```sql
-- Fact table
CREATE TABLE fact_sales (
    sale_id INT,
    date_key INT,
    product_key INT,
    customer_key INT,
    amount DECIMAL(10,2)
);

-- Dimension tables
CREATE TABLE dim_date (date_key INT, date DATE, year INT, month INT);
CREATE TABLE dim_product (product_key INT, name STRING, category STRING);
CREATE TABLE dim_customer (customer_key INT, name STRING, segment STRING);
```

---

## References

- **ClickHouse:** https://clickhouse.com/docs
- **BigQuery:** https://cloud.google.com/bigquery/docs
- **Redshift:** https://docs.aws.amazon.com/redshift/
- **Snowflake:** https://docs.snowflake.com/

---

## Related Documentation

- **Persistence Guide:** `docs/guides/persistence_guide__t__.md` - Choosing storage technologies
- **Operations Guide:** `docs/guides/persistence_operations_guide__t__.md` - General strategies
- **Cloud Databases Runbook:** `cloud_databases_runbook__t__.md` - Managed database services
