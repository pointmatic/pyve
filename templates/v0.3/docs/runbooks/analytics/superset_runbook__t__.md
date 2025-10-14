# Apache Superset Operations Runbook

## Overview

Apache Superset is an open-source data exploration and visualization platform designed for enterprise-scale deployments.

**Key features:**
- Rich visualizations (40+ chart types)
- SQL Lab (SQL IDE)
- Semantic layer
- Extensible (Python-based)
- Enterprise features (caching, security)

**Deployment:** Self-hosted (Docker, Kubernetes, pip) or Preset (managed)

---

## Installation

### Docker Compose (Recommended)

```bash
# Clone repository
git clone https://github.com/apache/superset.git
cd superset

# Start with Docker Compose
docker-compose -f docker-compose-non-dev.yml up -d

# Access at http://localhost:8088
# Default credentials: admin / admin
```

### Kubernetes (Helm)

```bash
# Add Superset Helm repository
helm repo add superset https://apache.github.io/superset
helm repo update

# Install
helm install superset superset/superset \
  --set postgresql.enabled=true \
  --set redis.enabled=true

# Get admin password
kubectl get secret superset -o jsonpath="{.data.admin-password}" | base64 --decode
```

### pip (Production)

```bash
# Install dependencies
pip install apache-superset psycopg2-binary redis

# Initialize database
superset db upgrade

# Create admin user
export FLASK_APP=superset
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@example.com \
  --password admin

# Load examples (optional)
superset load_examples

# Initialize
superset init

# Run server
superset run -h 0.0.0.0 -p 8088 --with-threads --reload --debugger
```

### Preset (Managed)

```
Visit: https://preset.io
Sign up for free trial or paid plan
```

---

## Configuration

### superset_config.py

```python
# superset_config.py

# Database connection
SQLALCHEMY_DATABASE_URI = 'postgresql://superset:password@localhost/superset'

# Redis cache
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': 'localhost',
    'CACHE_REDIS_PORT': 6379,
    'CACHE_REDIS_DB': 1,
}

# Celery (async queries)
CELERY_CONFIG = {
    'broker_url': 'redis://localhost:6379/0',
    'result_backend': 'redis://localhost:6379/0',
}

# Secret key
SECRET_KEY = 'your-secret-key-here'

# Feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
}

# Row limit
ROW_LIMIT = 50000
```

---

## Data Sources

### Connecting Databases

**Supported databases:**
- PostgreSQL, MySQL, SQLite
- BigQuery, Redshift, Snowflake
- Presto, Trino, Druid
- 40+ connectors

**Add database:**
```
Settings > Database Connections > + Database

Database: PostgreSQL
SQLAlchemy URI: postgresql://user:password@host:5432/database

Advanced:
- Expose in SQL Lab: Yes
- Allow CREATE TABLE AS: Yes
- Allow DML: No

Test Connection > Connect
```

**Connection string examples:**
```
# PostgreSQL
postgresql://user:password@host:5432/database

# MySQL
mysql://user:password@host:3306/database

# BigQuery
bigquery://project-id

# Redshift
redshift+psycopg2://user:password@host:5439/database

# Snowflake
snowflake://user:password@account/database/schema?warehouse=warehouse&role=role
```

### Datasets

**Add dataset:**
```
Data > Datasets > + Dataset

Database: Production DB
Schema: public
Table: orders

Save
```

**Virtual dataset (SQL):**
```sql
SELECT
  DATE(created_at) as date,
  product_category,
  SUM(amount) as total_revenue,
  COUNT(*) as order_count
FROM orders
WHERE status = 'completed'
GROUP BY date, product_category
```

---

## SQL Lab

### Query Editor

**Features:**
- Syntax highlighting
- Auto-completion
- Query history
- Multiple tabs
- Save queries

**Run query:**
```sql
SELECT
  product_category,
  COUNT(*) as order_count,
  SUM(amount) as total_revenue
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY product_category
ORDER BY total_revenue DESC
LIMIT 10;
```

**Template variables:**
```sql
SELECT *
FROM orders
WHERE created_at >= '{{ from_dttm }}'
  AND created_at < '{{ to_dttm }}'
  AND product_category = '{{ category }}'
```

**Save query:**
- Click "Save"
- Name query
- Add to collection

---

## Charts

### Creating Charts

**1. Create chart:**
- Charts > + Chart
- Choose dataset
- Select visualization type

**2. Configure:**
- **Dimensions:** X-axis, grouping
- **Metrics:** Y-axis, aggregations
- **Filters:** WHERE conditions
- **Time range:** Date filter

**3. Customize:**
- Colors, labels, legends
- Axis formatting
- Tooltips

**4. Save:**
- Save to dashboard (optional)

### Chart Types

**Time series:**
- Line chart
- Area chart
- Bar chart (time-based)

**Categorical:**
- Bar chart
- Pie chart
- Treemap
- Sunburst

**Tables:**
- Table
- Pivot table

**Maps:**
- Deck.gl (geospatial)
- Country map
- World map

**Advanced:**
- Sankey diagram
- Chord diagram
- Heatmap
- Box plot

---

## Dashboards

### Creating Dashboards

**1. Create dashboard:**
- Dashboards > + Dashboard
- Name: "Sales Overview"

**2. Add charts:**
- Drag charts from sidebar
- Or create new charts

**3. Layout:**
- Resize charts
- Arrange in grid
- Add tabs for organization

**4. Add filters:**
- Add native filters
- Configure filter scope
- Set default values

**5. Add markdown:**
- Add text components
- Headers, descriptions, links

### Native Filters

**Add filter:**
```
Dashboard > Edit > Filters > + Add filter

Filter type: Time range
Name: Date Range
Default value: Last 30 days

Scoping:
- Apply to: All charts with time column
```

**Filter types:**
- Time range
- Time column
- Time grain
- Value (dropdown, search)
- Numerical range

### Cross-Filtering

**Enable cross-filtering:**
```python
# superset_config.py
FEATURE_FLAGS = {
    'DASHBOARD_CROSS_FILTERS': True,
}
```

**Configure:**
- Click on chart element
- Filters other charts on dashboard
- Interactive exploration

---

## Semantic Layer

### Metrics

**Define metric:**
```
Dataset > Edit > Metrics > + Add metric

Metric name: Total Revenue
SQL expression: SUM(amount)
Metric type: SUM
```

**Calculated metrics:**
```sql
-- Average Order Value
SUM(amount) / COUNT(DISTINCT order_id)

-- Conversion Rate
COUNT(DISTINCT CASE WHEN status = 'completed' THEN order_id END) / 
COUNT(DISTINCT order_id) * 100
```

### Calculated Columns

**Add calculated column:**
```
Dataset > Edit > Calculated Columns > + Add column

Column name: is_high_value
SQL expression: CASE WHEN amount > 100 THEN 'Yes' ELSE 'No' END
```

---

## Embedding

### Public Dashboards

**Enable public access:**
```python
# superset_config.py
PUBLIC_ROLE_LIKE = 'Gamma'
```

**Share dashboard:**
```
Dashboard > Share > Copy permalink
```

### Embedded Dashboards

**1. Enable embedding:**
```python
# superset_config.py
FEATURE_FLAGS = {
    'EMBEDDED_SUPERSET': True,
}

GUEST_ROLE_NAME = 'Public'
GUEST_TOKEN_JWT_SECRET = 'your-jwt-secret'
GUEST_TOKEN_JWT_ALGO = 'HS256'
GUEST_TOKEN_JWT_EXP_SECONDS = 300
```

**2. Generate guest token (server-side):**
```python
import jwt
from datetime import datetime, timedelta

def create_guest_token(dashboard_id, user_email):
    payload = {
        'user': {
            'username': user_email,
            'first_name': 'Guest',
            'last_name': 'User',
        },
        'resources': [{
            'type': 'dashboard',
            'id': dashboard_id,
        }],
        'rls': [],  # Row-level security rules
        'exp': datetime.utcnow() + timedelta(minutes=5),
    }
    
    token = jwt.encode(
        payload,
        'your-jwt-secret',
        algorithm='HS256'
    )
    
    return token
```

**3. Embed:**
```html
<iframe
  src="https://superset.example.com/embedded/{{ dashboard_id }}?guest_token={{ token }}"
  width="100%"
  height="800"
  frameborder="0">
</iframe>
```

---

## User Management

### Roles

**Default roles:**
- **Admin:** Full access
- **Alpha:** Create and edit content
- **Gamma:** View and explore
- **Public:** Public dashboards only

**Create custom role:**
```
Settings > List Roles > + Add

Name: Analyst
Permissions:
- can read on Dataset
- can read on Chart
- can read on Dashboard
- can explore on Superset
```

### Row-Level Security

**Add RLS rule:**
```
Settings > Row Level Security > + Add

Filter name: Department Filter
Tables: orders, users
Roles: Sales Team

Clause:
department = '{{ current_user_department() }}'
```

---

## Performance Optimization

### Caching

**Query caching:**
```python
# superset_config.py
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 86400,  # 24 hours
}

# Per-chart cache timeout
DATA_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 3600,  # 1 hour
}
```

**Warm cache:**
```bash
# Warm cache for dashboard
superset warm-up-cache --dashboard-id 1
```

### Async Queries

**Configure Celery:**
```python
# superset_config.py
CELERY_CONFIG = {
    'broker_url': 'redis://localhost:6379/0',
    'result_backend': 'redis://localhost:6379/0',
}

# Enable async queries
FEATURE_FLAGS = {
    'GLOBAL_ASYNC_QUERIES': True,
}
```

**Start Celery workers:**
```bash
celery --app=superset.tasks.celery_app:app worker --pool=prefork -O fair -c 4
```

---

## Administration

### Monitoring

**Logs:**
```bash
# Application logs
tail -f /var/log/superset/superset.log

# Celery logs
tail -f /var/log/superset/celery.log
```

**Metrics:**
- Query performance
- Cache hit rate
- User activity
- Error rate

### Backup

**Database backup:**
```bash
# PostgreSQL
pg_dump superset > superset_backup.sql

# Restore
psql superset < superset_backup.sql
```

**Export dashboards:**
```bash
superset export-dashboards -f dashboards.zip
```

**Import dashboards:**
```bash
superset import-dashboards -p dashboards.zip
```

### Upgrades

```bash
# Backup database
pg_dump superset > backup.sql

# Pull latest version
pip install --upgrade apache-superset

# Upgrade database
superset db upgrade

# Restart Superset
superset run
```

---

## Best Practices

**Charts:**
- Use appropriate chart types
- Limit data points (<10k)
- Add clear labels and titles

**Dashboards:**
- Keep focused (5-10 charts)
- Use native filters
- Organize with tabs

**Performance:**
- Enable caching
- Use async queries
- Pre-aggregate data

**Security:**
- Use RLS for multi-tenancy
- Limit database permissions
- Audit user activity

---

## Troubleshooting

**Slow queries:**
- Check SQL in SQL Lab
- Add database indexes
- Use materialized views
- Enable caching

**Cache issues:**
- Clear cache manually
- Verify Redis connection
- Check cache configuration

**Celery not working:**
- Verify Redis connection
- Check Celery worker logs
- Restart Celery workers

---

## References

- **Superset Documentation:** https://superset.apache.org/docs/
- **GitHub:** https://github.com/apache/superset
- **Slack Community:** https://apache-superset.slack.com/

---

## Related Documentation

- **Analytics Guide:** `docs/guides/analytics_guide__t__.md`
- **Metabase Runbook:** `metabase_runbook__t__.md` - Alternative open-source BI tool
