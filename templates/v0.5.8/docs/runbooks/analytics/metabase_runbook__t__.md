# Metabase Operations Runbook

## Overview

Metabase is an open-source BI tool known for its simplicity and ease of use, perfect for small to medium teams.

**Key features:**
- User-friendly interface
- No SQL required (visual query builder)
- Self-hosted or cloud
- Embedding support
- Open-source (AGPLv3)

**Deployment:** Self-hosted (Docker, JAR) or Metabase Cloud

---

## Installation

### Docker (Recommended)

```bash
# Run Metabase
docker run -d -p 3000:3000 \
  --name metabase \
  -e "MB_DB_FILE=/metabase-data/metabase.db" \
  -v ~/metabase-data:/metabase-data \
  metabase/metabase

# Access at http://localhost:3000
```

### Docker Compose with PostgreSQL

```yaml
# docker-compose.yml
version: '3.8'
services:
  metabase:
    image: metabase/metabase:latest
    ports:
      - "3000:3000"
    environment:
      MB_DB_TYPE: postgres
      MB_DB_DBNAME: metabase
      MB_DB_PORT: 5432
      MB_DB_USER: metabase
      MB_DB_PASS: metabase_password
      MB_DB_HOST: postgres
    depends_on:
      - postgres
    volumes:
      - ./metabase-data:/metabase-data
  
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: metabase
      POSTGRES_USER: metabase
      POSTGRES_PASSWORD: metabase_password
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
```

```bash
docker-compose up -d
```

### JAR File

```bash
# Download
wget https://downloads.metabase.com/latest/metabase.jar

# Run
java -jar metabase.jar
```

### Metabase Cloud

```
Visit: https://www.metabase.com/start/
Sign up for free trial or paid plan
```

---

## Initial Setup

**1. Create admin account:**
- Navigate to http://localhost:3000
- Set up admin email and password
- Configure organization name

**2. Add database:**
- Settings > Admin > Databases > Add Database
- Choose database type
- Enter connection details
- Test connection

**3. Scan database:**
- Metabase automatically scans schema
- Detects tables and columns
- Suggests field types

---

## Data Sources

### Connecting Databases

**Supported databases:**
- PostgreSQL, MySQL, SQL Server
- MongoDB, BigQuery, Redshift, Snowflake
- 20+ connectors

**Add PostgreSQL:**
```
Admin > Databases > Add Database

Database type: PostgreSQL
Name: Production DB
Host: db.example.com
Port: 5432
Database name: analytics
Username: metabase_user
Password: ********

Advanced options:
- Use SSL: Yes
- Additional JDBC options: (optional)

Save
```

**Connection pooling:**
```
Advanced options:
- Let user control scheduling: No
- Automatically run queries when doing simple filtering: Yes
- Rerun queries for simple explorations: Yes
```

---

## Creating Questions

### Visual Query Builder

**1. Create new question:**
- Click "New" > "Question"
- Choose "Simple question"

**2. Select data:**
- Pick a table (e.g., "Orders")

**3. Filter:**
- Add filter: Created At > Last 30 days
- Add filter: Status = "completed"

**4. Summarize:**
- Summarize by: Sum of Amount
- Group by: Created At (by Day)

**5. Visualize:**
- Choose visualization (Line, Bar, Pie, etc.)
- Configure settings

**6. Save:**
- Save question
- Add to dashboard (optional)

### SQL Queries

**Native SQL:**
```sql
SELECT
  DATE(created_at) as date,
  product_category,
  SUM(amount) as total_revenue,
  COUNT(*) as order_count
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
  AND status = 'completed'
GROUP BY date, product_category
ORDER BY date;
```

**Variables:**
```sql
SELECT *
FROM orders
WHERE created_at >= {{start_date}}
  AND created_at <= {{end_date}}
  AND product_category = {{category}}
```

---

## Dashboards

### Creating Dashboards

**1. Create dashboard:**
- Click "New" > "Dashboard"
- Name: "Sales Overview"

**2. Add questions:**
- Click "Add a question"
- Select existing questions
- Or create new questions

**3. Layout:**
- Drag and drop cards
- Resize cards
- Organize sections

**4. Add filters:**
- Click "Add a filter"
- Choose filter type (Date, Category, etc.)
- Connect to questions

**5. Add text cards:**
- Click "Add a text card"
- Add context, headers, descriptions

### Dashboard Filters

**Date filter:**
```
Add filter > Time
- Default: Last 30 days
- Connect to: All questions with date field
```

**Category filter:**
```
Add filter > Category
- Field: Product Category
- Default: All
- Connect to: Relevant questions
```

### Auto-refresh

```
Dashboard settings > Auto-refresh
- Every 1 minute
- Every 5 minutes
- Every 10 minutes
- Every 30 minutes
- Every 1 hour
```

---

## Embedding

### Public Sharing

**Enable public sharing:**
```
Admin > Settings > Public Sharing
Enable public sharing: On
```

**Share dashboard:**
```
Dashboard > Sharing icon
Enable sharing
Copy public link
```

### Signed Embedding

**1. Enable embedding:**
```
Admin > Settings > Embedding
Enable embedding: On
Generate Embedding Secret Key
```

**2. Enable embedding for dashboard:**
```
Dashboard > Sharing icon
Embed this dashboard
Configure parameters (locked or editable)
```

**3. Generate signed URL (server-side):**
```python
import jwt
import time

def create_embed_url(
    site_url,
    secret_key,
    resource_type,
    resource_id,
    params=None
):
    payload = {
        "resource": {resource_type: resource_id},
        "params": params or {},
        "exp": int(time.time()) + 600  # 10 minutes
    }
    
    token = jwt.encode(payload, secret_key, algorithm="HS256")
    
    return f"{site_url}/embed/{resource_type}/{token}"

# Usage
url = create_embed_url(
    site_url="https://metabase.example.com",
    secret_key="your-secret-key",
    resource_type="dashboard",
    resource_id=1,
    params={"date_filter": "2024-01-01"}
)
```

**4. Embed in iframe:**
```html
<iframe
  src="{{ embed_url }}"
  frameborder="0"
  width="800"
  height="600"
  allowtransparency>
</iframe>
```

---

## User Management

### Roles and Permissions

**Default groups:**
- **Administrators:** Full access
- **All Users:** Can create questions and dashboards

**Create custom group:**
```
Admin > People > Groups > Create a group

Name: Analysts
Permissions:
- View data: Selected databases
- Create queries: Yes
- Download results: Yes
```

### Data Permissions

**Set database permissions:**
```
Admin > Permissions > Data

Group: Analysts
Database: Production DB
- View data: Yes
- Create queries: Yes
- Download results: Yes

Specific tables:
- Orders: Unrestricted
- Users: No access
- Payments: Sandboxed (row-level security)
```

### Row-Level Security (Sandboxing)

**Configure sandbox:**
```
Admin > Permissions > Data > [Database] > [Table]

Sandboxed access for group: Sales Team

Attribute: user_id
User attribute: user_id

SQL:
WHERE user_id = {{user_id}}
```

---

## Performance Optimization

### Caching

**Query caching:**
```
Admin > Settings > Caching

Enable caching: On
Minimum query duration: 1 second
Cache TTL multiplier: 10
Max cache entry size: 100 MB
```

**Dashboard caching:**
- Dashboards cache results automatically
- Refresh manually or on schedule

### Database Optimization

**Sync schema less frequently:**
```
Admin > Databases > [Database] > Scheduling

Database syncing:
- Scan for new tables: Daily at 2 AM
- Scan for new columns: Daily at 2 AM
```

**Disable auto-run:**
```
Admin > Databases > [Database] > Advanced options

Automatically run queries: No
Rerun queries for simple explorations: No
```

---

## Administration

### Monitoring

**Activity logs:**
```
Admin > Troubleshooting > Logs

View:
- Query execution
- User activity
- Errors
```

**Query performance:**
```
Admin > Troubleshooting > Query Inspector

Analyze:
- Slow queries
- Failed queries
- Database load
```

### Backup

**H2 database (default):**
```bash
# Backup metabase.db file
cp ~/metabase-data/metabase.db.mv.db ~/backups/metabase-$(date +%Y%m%d).db.mv.db
```

**PostgreSQL:**
```bash
pg_dump -h localhost -U metabase metabase > metabase_backup.sql
```

### Upgrades

**Docker:**
```bash
# Pull latest image
docker pull metabase/metabase:latest

# Stop and remove old container
docker stop metabase
docker rm metabase

# Run new container
docker run -d -p 3000:3000 \
  --name metabase \
  -v ~/metabase-data:/metabase-data \
  metabase/metabase:latest
```

**JAR:**
```bash
# Download new version
wget https://downloads.metabase.com/latest/metabase.jar -O metabase-new.jar

# Stop old version
# Run new version
java -jar metabase-new.jar
```

---

## Best Practices

**Questions:**
- Use descriptive names
- Add descriptions
- Save to collections for organization

**Dashboards:**
- Keep focused (5-10 cards max)
- Use filters for interactivity
- Add text cards for context

**Performance:**
- Cache expensive queries
- Use database views for complex logic
- Limit auto-refresh frequency

**Governance:**
- Use groups for access control
- Implement row-level security
- Audit user activity regularly

---

## Troubleshooting

**Slow queries:**
- Check query in SQL editor
- Add database indexes
- Use database views
- Enable caching

**Connection errors:**
- Verify database credentials
- Check network connectivity
- Review firewall rules
- Test connection in admin panel

**Embedding issues:**
- Verify secret key
- Check token expiration
- Validate parameters
- Review browser console

---

## References

- **Metabase Documentation:** https://www.metabase.com/docs/
- **Metabase Discourse:** https://discourse.metabase.com/
- **GitHub:** https://github.com/metabase/metabase

---

## Related Documentation

- **Analytics Guide:** `docs/guides/analytics_guide__t__.md`
- **Superset Runbook:** `superset_runbook__t__.md` - Alternative open-source BI tool
