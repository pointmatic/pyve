# Looker Operations Runbook

## Overview

Looker is a cloud-based BI platform owned by Google Cloud, known for its semantic modeling layer (LookML) and embedded analytics capabilities.

**Key features:**
- LookML (semantic modeling language)
- Git-based version control
- Embedded analytics
- Data governance
- API-first architecture
- Multi-cloud support

**Deployment:** Cloud-only (Google Cloud Platform)

---

## Getting Started

### Access Looker

**Looker is cloud-hosted:**
- No installation required
- Access via web browser
- URL: `https://your-company.looker.com`

**Trial:**
```
Visit: https://cloud.google.com/looker
Sign up for free trial
```

### Initial Setup

**1. Create Looker instance:**
- Via Google Cloud Console
- Choose region
- Configure authentication

**2. Connect to database:**
- Navigate to Admin > Connections
- Add database connection
- Test connection

**3. Set up Git integration:**
- Admin > Projects
- Configure Git repository
- Set up deploy keys

---

## Data Sources

### Connecting Databases

**Supported databases:**
- BigQuery, Redshift, Snowflake
- PostgreSQL, MySQL, SQL Server
- MongoDB, Elasticsearch
- 60+ connectors

**Add connection:**
```
Admin > Connections > Add Connection

Name: production_db
Dialect: PostgreSQL
Host: db.example.com
Port: 5432
Database: analytics
Username: looker_user
Password: ********

Test Connection > Add Connection
```

**Connection pooling:**
```
Max Connections: 20
Connection Pool Timeout: 120 seconds
```

### PDTs (Persistent Derived Tables)

**Create derived table:**
```lookml
view: daily_sales {
  derived_table: {
    sql:
      SELECT
        DATE(created_at) as date,
        product_id,
        SUM(revenue) as total_revenue
      FROM orders
      GROUP BY 1, 2
    ;;
    
    # Rebuild daily at 2 AM
    sql_trigger_value: SELECT CURRENT_DATE ;;
    
    # Or rebuild every 24 hours
    # datagroup_trigger: daily_datagroup
    
    # Create indexes
    indexes: ["date", "product_id"]
  }
  
  dimension: date {
    type: date
    sql: ${TABLE}.date ;;
  }
  
  dimension: product_id {
    type: number
    sql: ${TABLE}.product_id ;;
  }
  
  measure: total_revenue {
    type: sum
    sql: ${TABLE}.total_revenue ;;
  }
}
```

---

## LookML (Semantic Layer)

### Project Structure

```
my_project/
├── models/
│   └── ecommerce.model.lkml
├── views/
│   ├── orders.view.lkml
│   ├── users.view.lkml
│   └── products.view.lkml
├── dashboards/
│   └── sales_overview.dashboard.lookml
└── manifest.lkml
```

### Models

**Define model:**
```lookml
# models/ecommerce.model.lkml
connection: "production_db"

include: "/views/*.view.lkml"
include: "/dashboards/*.dashboard.lookml"

datagroup: daily_datagroup {
  sql_trigger: SELECT CURRENT_DATE ;;
  max_cache_age: "24 hours"
}

explore: orders {
  join: users {
    type: left_outer
    sql_on: ${orders.user_id} = ${users.id} ;;
    relationship: many_to_one
  }
  
  join: products {
    type: left_outer
    sql_on: ${orders.product_id} = ${products.id} ;;
    relationship: many_to_one
  }
}
```

### Views

**Basic view:**
```lookml
# views/orders.view.lkml
view: orders {
  sql_table_name: public.orders ;;
  
  # Primary key
  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }
  
  # Dimensions
  dimension: user_id {
    type: number
    sql: ${TABLE}.user_id ;;
  }
  
  dimension: product_id {
    type: number
    sql: ${TABLE}.product_id ;;
  }
  
  dimension: status {
    type: string
    sql: ${TABLE}.status ;;
  }
  
  # Time dimensions
  dimension_group: created {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}.created_at ;;
  }
  
  # Measures
  measure: count {
    type: count
    drill_fields: [id, created_date, user_id, product_id]
  }
  
  measure: total_revenue {
    type: sum
    sql: ${TABLE}.amount ;;
    value_format_name: usd
  }
  
  measure: average_order_value {
    type: average
    sql: ${TABLE}.amount ;;
    value_format_name: usd
  }
}
```

**Advanced view features:**
```lookml
view: orders {
  # ... basic dimensions ...
  
  # Derived dimension
  dimension: is_high_value {
    type: yesno
    sql: ${TABLE}.amount > 100 ;;
  }
  
  # Case statement
  dimension: order_size {
    type: string
    case: {
      when: {
        sql: ${TABLE}.amount < 50 ;;
        label: "Small"
      }
      when: {
        sql: ${TABLE}.amount < 200 ;;
        label: "Medium"
      }
      else: "Large"
    }
  }
  
  # Templated filter
  filter: date_filter {
    type: date
  }
  
  # Measure with filter
  measure: high_value_orders {
    type: count
    filters: [is_high_value: "yes"]
  }
  
  # Percent of total
  measure: percent_of_total_revenue {
    type: percent_of_total
    sql: ${total_revenue} ;;
  }
}
```

### Explores

**Join types:**
```lookml
explore: orders {
  # Left outer join (most common)
  join: users {
    type: left_outer
    sql_on: ${orders.user_id} = ${users.id} ;;
    relationship: many_to_one
  }
  
  # Inner join
  join: products {
    type: inner
    sql_on: ${orders.product_id} = ${products.id} ;;
    relationship: many_to_one
  }
  
  # Many-to-many join
  join: order_items {
    type: left_outer
    sql_on: ${orders.id} = ${order_items.order_id} ;;
    relationship: one_to_many
  }
}
```

**Access grants:**
```lookml
# Restrict explore access
explore: orders {
  access_filter: {
    field: users.department
    user_attribute: department
  }
}
```

---

## Creating Visualizations

### Explore Interface

**1. Select explore:**
- Navigate to Explore menu
- Choose explore (e.g., "Orders")

**2. Select dimensions and measures:**
- Dimensions: Date, Product Category
- Measures: Total Revenue, Order Count

**3. Add filters:**
- Created Date: Last 30 days
- Status: "completed"

**4. Run query:**
- Click "Run"
- View results in table

**5. Visualize:**
- Click "Visualization"
- Choose chart type (line, bar, pie, etc.)
- Configure visualization settings

### Chart Types

**Line chart:**
- Time series data
- Trends over time

**Bar chart:**
- Comparisons across categories
- Horizontal or vertical

**Pie chart:**
- Proportions and percentages
- Limited categories (<7)

**Table:**
- Detailed data
- Multiple dimensions and measures

**Single value:**
- KPIs and metrics
- Comparison to previous period

**Map:**
- Geographic data
- Heatmaps, point maps

---

## Dashboards

### Creating Dashboards

**1. Create new dashboard:**
```
Dashboards > New Dashboard
Title: Sales Overview
```

**2. Add tiles:**
- From existing Looks
- From explores
- Text tiles for context

**3. Configure layout:**
- Drag and drop tiles
- Resize tiles
- Organize sections

**4. Add filters:**
- Dashboard-level filters
- Apply to multiple tiles

**Example dashboard:**
```lookml
# dashboards/sales_overview.dashboard.lookml
- dashboard: sales_overview
  title: Sales Overview
  layout: newspaper
  
  filters:
  - name: date_range
    title: Date Range
    type: field_filter
    default_value: 30 days
    model: ecommerce
    explore: orders
    field: orders.created_date
  
  elements:
  - name: total_revenue
    title: Total Revenue
    model: ecommerce
    explore: orders
    type: single_value
    fields: [orders.total_revenue]
    filters:
      orders.status: completed
    listen:
      date_range: orders.created_date
    row: 0
    col: 0
    width: 6
    height: 4
  
  - name: revenue_by_day
    title: Revenue by Day
    model: ecommerce
    explore: orders
    type: looker_line
    fields: [orders.created_date, orders.total_revenue]
    sorts: [orders.created_date]
    listen:
      date_range: orders.created_date
    row: 0
    col: 6
    width: 18
    height: 8
```

### Dashboard Features

**Filters:**
- Date ranges
- Categories
- Multi-select

**Drill-downs:**
- Click to explore details
- Navigate to related dashboards

**Scheduled delivery:**
- Email dashboards
- Slack integration
- Webhook delivery

---

## Embedding Analytics

### Signed Embedding

**1. Enable embedding:**
```
Admin > Platform > Embed
Enable "Embed Authentication"
Generate Embed Secret
```

**2. Create embed URL (server-side):**
```python
import time
import binascii
import hashlib
import base64
import json
from urllib.parse import quote

def create_signed_url(
    host,
    secret,
    external_user_id,
    permissions,
    models,
    dashboard_id
):
    # Create embed user
    embed_user = {
        'external_user_id': external_user_id,
        'first_name': 'Embedded',
        'last_name': 'User',
        'permissions': permissions,
        'models': models,
        'access_filters': {},
        'session_length': 3600,
        'force_logout_login': True
    }
    
    # Encode user
    json_user = json.dumps(embed_user)
    json_user_encoded = base64.b64encode(json_user.encode()).decode()
    
    # Create signature
    path = f'/embed/dashboards/{dashboard_id}'
    nonce = str(int(time.time()))
    
    string_to_sign = f"{path}\n{nonce}\n{session_length}\n{json_user_encoded}"
    signature = base64.b64encode(
        hashlib.sha1(
            f"{string_to_sign}{secret}".encode()
        ).digest()
    ).decode()
    
    # Build URL
    params = {
        'nonce': nonce,
        'time': nonce,
        'session_length': session_length,
        'external_user_id': external_user_id,
        'permissions': json.dumps(permissions),
        'models': json.dumps(models),
        'signature': signature
    }
    
    query_string = '&'.join([f"{k}={quote(str(v))}" for k, v in params.items()])
    
    return f"https://{host}{path}?{query_string}"

# Usage
url = create_signed_url(
    host='your-company.looker.com',
    secret='your-embed-secret',
    external_user_id='user-123',
    permissions=['access_data', 'see_looks'],
    models=['ecommerce'],
    dashboard_id='sales_overview'
)
```

**3. Embed in iframe:**
```html
<iframe
  src="{{ signed_url }}"
  width="100%"
  height="800"
  frameborder="0">
</iframe>
```

### SSO Embedding

**Configure SAML:**
```
Admin > Authentication > SAML
IdP URL: https://idp.example.com/saml
IdP Issuer: https://idp.example.com
X.509 Certificate: [paste certificate]
```

---

## User Management

### Roles and Permissions

**Default roles:**
- **Admin:** Full access
- **Developer:** Create LookML, dashboards
- **User:** View and explore data
- **Viewer:** View dashboards only

**Custom roles:**
```
Admin > Roles > New Role

Name: Analyst
Permissions:
- access_data
- see_looks
- see_user_dashboards
- explore
- create_table_calculations
```

### Row-Level Security

**User attributes:**
```
Admin > Users > User Attributes

Name: department
Type: String
Default Value: all
```

**Apply in LookML:**
```lookml
explore: orders {
  access_filter: {
    field: users.department
    user_attribute: department
  }
}
```

**Set user attribute:**
```
Admin > Users > [Select User]
User Attributes > department: sales
```

---

## Performance Optimization

### Caching

**Datagroups:**
```lookml
datagroup: hourly_datagroup {
  sql_trigger: SELECT FLOOR(EXTRACT(EPOCH FROM NOW()) / 3600) ;;
  max_cache_age: "1 hour"
}

explore: orders {
  persist_with: hourly_datagroup
}
```

**Query caching:**
- Automatic for identical queries
- Configurable cache duration
- Clear cache manually if needed

### Aggregate Awareness

**Create aggregate table:**
```lookml
view: orders_daily {
  derived_table: {
    sql:
      SELECT
        DATE(created_at) as date,
        product_id,
        SUM(amount) as total_revenue,
        COUNT(*) as order_count
      FROM orders
      GROUP BY 1, 2
    ;;
    datagroup_trigger: daily_datagroup
  }
}

# Use in explore
explore: orders {
  aggregate_table: orders_daily {
    query: {
      dimensions: [created_date, product_id]
      measures: [total_revenue, count]
    }
    
    materialization: {
      datagroup_trigger: daily_datagroup
    }
  }
}
```

---

## Administration

### Monitoring

**System Activity:**
```
Admin > System Activity

View:
- Query performance
- User activity
- Error logs
- Cache hit rates
```

**Performance dashboard:**
- Query runtime
- Database connections
- PDT build times

### Backup

**Git-based backup:**
- LookML is version-controlled in Git
- Automatic backup of code

**Content backup:**
```
Admin > Platform > API
Use Looker API to export:
- Dashboards
- Looks
- User content
```

### Upgrades

**Looker is cloud-managed:**
- Automatic updates
- No manual upgrades required
- Release notes provided

---

## Best Practices

**LookML:**
- Use consistent naming conventions
- Document complex logic
- Leverage reusable code (extends, refinements)
- Test changes in development mode

**Performance:**
- Use PDTs for expensive queries
- Implement aggregate awareness
- Monitor query performance
- Optimize database indexes

**Governance:**
- Use access grants for sensitive data
- Implement row-level security
- Audit user activity
- Certify official content

**Development workflow:**
- Use Git branches for features
- Code review before merging
- Test in development mode
- Deploy to production carefully

---

## Troubleshooting

**Slow queries:**
- Check query in SQL Runner
- Optimize database indexes
- Use PDTs or aggregate tables
- Reduce data scanned

**PDT build failures:**
- Check SQL syntax
- Verify database permissions
- Review error logs
- Test SQL in SQL Runner

**Embedding issues:**
- Verify embed secret
- Check signature generation
- Validate user permissions
- Review browser console errors

---

## References

- **Looker Documentation:** https://cloud.google.com/looker/docs
- **LookML Reference:** https://cloud.google.com/looker/docs/reference/lookml-quick-reference
- **Looker API:** https://cloud.google.com/looker/docs/reference/looker-api/latest
- **Looker Community:** https://community.looker.com/

---

## Related Documentation

- **Analytics Guide:** `docs/guides/analytics_guide__t__.md` - General concepts and strategies
- **Data Warehouse Runbook:** `docs/runbooks/persistence/data_warehouse_runbook__t__.md` - BigQuery, Redshift, Snowflake
