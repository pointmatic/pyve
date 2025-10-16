# Analytics & Business Intelligence Guide

## Purpose
This guide helps you choose and implement analytics and business intelligence (BI) tools for data visualization, reporting, and self-service analytics. It complements the persistence guides by focusing on the presentation and consumption layer of your data infrastructure.

**For platform-specific implementation details**, see the [analytics runbooks](../runbooks/analytics/).

## Scope
- Choosing BI tools and platforms
- Architecture patterns for analytics
- Data modeling for analytics (metrics, dimensions, semantic layers)
- Performance optimization
- Embedding analytics in applications
- Self-service analytics enablement

---

## What is Business Intelligence?

**Business Intelligence (BI)** tools help users:
- Visualize data through charts, graphs, and dashboards
- Explore data interactively without writing SQL
- Create reports for stakeholders
- Monitor KPIs and metrics
- Perform ad-hoc analysis

**BI tools are consumers of data**, not storage systems. They connect to:
- Data warehouses (BigQuery, Redshift, Snowflake)
- OLTP databases (PostgreSQL, MySQL)
- Data lakes (S3, GCS, Azure Blob)
- APIs and SaaS applications

---

## Choosing BI Tools

### Decision Matrix

| Factor | Self-Hosted Open-Source | Cloud Open-Source | Commercial Cloud |
|--------|------------------------|-------------------|------------------|
| **Cost** | Low (infrastructure only) | Medium (hosting + support) | High (per-user licensing) |
| **Setup** | Complex | Medium | Simple |
| **Maintenance** | High (self-managed) | Low (managed service) | Minimal (fully managed) |
| **Customization** | High | Medium | Limited |
| **Scalability** | Manual | Auto-scaling | Auto-scaling |
| **Support** | Community | Community + paid | Enterprise |
| **Examples** | Metabase, Superset | Metabase Cloud, Preset | Looker, Tableau, Power BI |

### Tool Categories

**Open-Source (Self-Hosted):**
- **Metabase** - Simple, user-friendly, great for small teams
- **Apache Superset** - Feature-rich, Python-based, extensible
- **Redash** - SQL-focused, supports many data sources
- **Grafana** - Best for metrics/monitoring, time-series data

**Open-Source (Cloud):**
- **Metabase Cloud** - Managed Metabase
- **Preset** - Managed Superset (by original creators)

**Commercial (Cloud):**
- **Looker** (Google Cloud) - Semantic modeling (LookML), embedded analytics
- **Tableau** - Industry leader, powerful visualizations
- **Power BI** (Microsoft) - Excel integration, enterprise features
- **Mode Analytics** - SQL + notebooks + dashboards
- **Sisense** - Embedded analytics, white-labeling

**Specialized:**
- **Amplitude** - Product analytics
- **Mixpanel** - User behavior analytics
- **Heap** - Automatic event tracking

### Selection Criteria

**Team size:**
- **Small (<10 users):** Metabase, Redash
- **Medium (10-100 users):** Superset, Looker, Power BI
- **Large (100+ users):** Tableau, Looker, Power BI

**Technical expertise:**
- **Non-technical users:** Metabase, Tableau, Power BI
- **SQL-comfortable users:** Redash, Mode, Superset
- **Data engineers:** Superset, Looker (LookML)

**Use case:**
- **Internal dashboards:** Metabase, Superset, Redash
- **Embedded analytics:** Looker, Sisense, Metabase
- **Executive reporting:** Tableau, Power BI
- **Product analytics:** Amplitude, Mixpanel
- **Metrics/monitoring:** Grafana

**Budget:**
- **Minimal:** Metabase, Superset (self-hosted)
- **Medium:** Metabase Cloud, Preset, Power BI
- **Enterprise:** Looker, Tableau

---

## Architecture Patterns

### Centralized Analytics

**Pattern:** Single BI tool for entire organization

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
┌──────▼──────┐
│  BI Tool    │
└──────┬──────┘
       │
┌──────▼──────┐
│ Data Warehouse│
└─────────────┘
```

**Pros:**
- Single source of truth
- Easier governance
- Centralized access control

**Cons:**
- Single point of failure
- Can become bottleneck
- One-size-fits-all approach

**Use when:** Small to medium organization, strong data team

### Self-Service Analytics

**Pattern:** Enable users to create their own reports and dashboards

```
┌─────────────────────────────┐
│  Business Users             │
│  (Create own dashboards)    │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│  BI Tool with Semantic Layer│
│  (Pre-defined metrics)      │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│  Data Warehouse             │
└─────────────────────────────┘
```

**Pros:**
- Empowers business users
- Reduces data team workload
- Faster insights

**Cons:**
- Risk of inconsistent metrics
- Requires training
- Governance challenges

**Use when:** Data-literate users, mature data infrastructure

### Embedded Analytics

**Pattern:** Embed dashboards/reports in your application

```
┌─────────────┐
│ Your App    │
│ ┌─────────┐ │
│ │Dashboard│ │ ← Embedded
│ └─────────┘ │
└──────┬──────┘
       │
┌──────▼──────┐
│  BI Tool    │
│  (Headless) │
└──────┬──────┘
       │
┌──────▼──────┐
│ App Database│
└─────────────┘
```

**Pros:**
- Seamless user experience
- White-labeling possible
- Multi-tenancy support

**Cons:**
- More complex setup
- Licensing costs (per-user or per-embed)
- Performance considerations

**Use when:** SaaS product, customer-facing analytics

### Hybrid (Data Mesh)

**Pattern:** Decentralized ownership, federated governance

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Team A   │  │ Team B   │  │ Team C   │
│ BI Tool  │  │ BI Tool  │  │ BI Tool  │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
┌────▼─────────────▼─────────────▼─────┐
│     Shared Data Platform              │
│  (Common metrics, governance)         │
└───────────────────────────────────────┘
```

**Pros:**
- Team autonomy
- Domain expertise
- Scalable

**Cons:**
- Coordination overhead
- Risk of silos
- Complex governance

**Use when:** Large organization, multiple domains

---

## Data Modeling for Analytics

### Semantic Layer

A **semantic layer** abstracts technical database details into business-friendly concepts.

**Benefits:**
- Consistent metric definitions
- Reusable business logic
- Easier for non-technical users
- Single source of truth

**Examples:**
- **Looker:** LookML
- **dbt:** Metrics layer
- **Cube.js:** Headless BI
- **MetricFlow:** Open-source semantic layer

**Example (LookML):**
```lookml
view: orders {
  sql_table_name: public.orders ;;
  
  dimension: order_id {
    primary_key: yes
    type: number
    sql: ${TABLE}.order_id ;;
  }
  
  dimension_group: created {
    type: time
    timeframes: [date, week, month, year]
    sql: ${TABLE}.created_at ;;
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

### Metrics and Dimensions

**Metrics (Measures):**
- Quantitative values (numbers)
- Aggregated (SUM, COUNT, AVG, etc.)
- Examples: Revenue, User Count, Conversion Rate

**Dimensions:**
- Qualitative attributes (categories)
- Used for grouping and filtering
- Examples: Date, Product Category, Region

**Example:**
```sql
SELECT
  DATE(created_at) as date,           -- Dimension
  product_category,                    -- Dimension
  COUNT(DISTINCT user_id) as users,   -- Metric
  SUM(revenue) as total_revenue       -- Metric
FROM orders
GROUP BY date, product_category;
```

### Star Schema

**Pattern:** Fact tables (metrics) + dimension tables (attributes)

```
        ┌──────────────┐
        │ dim_product  │
        └───────┬──────┘
                │
┌───────────────┼───────────────┐
│               │               │
│         ┌─────▼─────┐         │
│         │fact_sales │         │
│         └─────┬─────┘         │
│               │               │
┌───────▼───────┴───────▼───────┐
│ dim_date      │   dim_customer│
└───────────────┴───────────────┘
```

**Fact table (fact_sales):**
- Metrics: revenue, quantity, profit
- Foreign keys to dimensions

**Dimension tables:**
- dim_date: date, day_of_week, month, quarter, year
- dim_product: product_id, name, category, price
- dim_customer: customer_id, name, segment, region

**Benefits:**
- Fast queries (denormalized)
- Intuitive for business users
- Optimized for BI tools

---

## Performance Optimization

### Caching Strategies

**Query result caching:**
- Cache results of expensive queries
- Serve cached results for repeated queries
- TTL-based expiration

**Dashboard caching:**
- Pre-compute dashboard data
- Refresh on schedule (hourly, daily)
- Reduce load on database

**Materialized views:**
- Pre-aggregate data in database
- Refresh periodically
- Trade freshness for speed

### Pre-Aggregation

**Rollup tables:**
```sql
-- Daily aggregates
CREATE TABLE daily_sales AS
SELECT
  DATE(created_at) as date,
  product_id,
  SUM(revenue) as total_revenue,
  COUNT(*) as order_count
FROM orders
GROUP BY date, product_id;

-- Monthly aggregates
CREATE TABLE monthly_sales AS
SELECT
  DATE_TRUNC('month', created_at) as month,
  product_category,
  SUM(revenue) as total_revenue
FROM orders
GROUP BY month, product_category;
```

**Benefits:**
- Faster queries (pre-computed)
- Lower database load
- Predictable performance

**Trade-offs:**
- Storage overhead
- Refresh latency
- Maintenance complexity

### Query Optimization

**Limit data scanned:**
- Use date filters (partition pruning)
- Select only needed columns
- Limit result sets

**Optimize joins:**
- Join on indexed columns
- Use appropriate join types
- Avoid cross joins

**Use appropriate aggregations:**
- APPROX_COUNT_DISTINCT for large datasets
- Sampling for exploratory analysis
- Incremental aggregations

---

## Embedding Analytics

### Embedding Approaches

**iframe embedding:**
```html
<iframe
  src="https://bi-tool.com/embed/dashboard/123?token=xyz"
  width="100%"
  height="600"
  frameborder="0">
</iframe>
```

**JavaScript SDK:**
```javascript
import { EmbedSDK } from 'bi-tool-sdk';

const dashboard = new EmbedSDK({
  dashboardId: '123',
  container: '#dashboard-container',
  filters: { date: '2024-01-01' }
});

dashboard.render();
```

**API-based:**
- Fetch data via API
- Build custom visualizations
- Full control over UI/UX

### Multi-Tenancy

**Row-level security:**
```sql
-- Filter data by tenant
WHERE tenant_id = current_user_tenant_id()
```

**Separate databases:**
- One database per tenant
- Complete isolation
- Higher overhead

**Shared database with tenant column:**
- Single database
- Filter by tenant_id
- Most common approach

### Authentication

**Signed URLs:**
- Generate time-limited URLs
- Include user context
- Verify signature on BI tool side

**SSO integration:**
- SAML, OAuth, OpenID Connect
- Seamless user experience
- Centralized access control

---

## Self-Service Analytics

### Enablement Strategies

**Data catalog:**
- Document available datasets
- Describe columns and metrics
- Provide examples

**Training:**
- SQL basics for analysts
- BI tool tutorials
- Best practices documentation

**Governance:**
- Certified datasets
- Approved metrics
- Data quality checks

### Common Pitfalls

**Metric inconsistency:**
- Different definitions of "revenue"
- Solve with semantic layer

**Performance issues:**
- Users create expensive queries
- Solve with query limits, pre-aggregation

**Data quality:**
- Garbage in, garbage out
- Solve with data validation, monitoring

---

## Security & Governance

### Access Control

**Role-based access:**
- Viewer: Read-only access
- Editor: Create/edit dashboards
- Admin: Manage users, data sources

**Row-level security:**
- Users see only their data
- Implemented at database or BI tool level

**Column-level security:**
- Hide sensitive columns (PII, salary)
- Mask or redact data

### Audit Logging

**Track:**
- Dashboard views
- Query executions
- Data exports
- User logins

**Use for:**
- Compliance
- Usage analytics
- Security monitoring

---

## Monitoring & Observability

### Key Metrics

**Usage:**
- Active users (DAU, WAU, MAU)
- Dashboard views
- Query count

**Performance:**
- Query execution time
- Dashboard load time
- Cache hit rate

**Data freshness:**
- Last data refresh
- ETL pipeline status

**Errors:**
- Failed queries
- Broken dashboards
- Data source connection issues

---

## Cost Optimization

### Licensing Models

**Per-user:**
- Fixed cost per user
- Predictable for small teams
- Expensive at scale

**Per-query:**
- Pay for compute used
- Good for variable usage
- Can be unpredictable

**Flat-rate:**
- Unlimited users/queries
- Best for large teams
- Higher upfront cost

### Optimization Strategies

**Reduce query costs:**
- Use caching
- Pre-aggregate data
- Limit data scanned

**Right-size infrastructure:**
- Scale down during off-hours
- Use serverless options
- Monitor resource usage

**Optimize licensing:**
- Viewer-only licenses (cheaper)
- Shared accounts for infrequent users
- Self-hosted for cost control

---

## Migration Strategies

### From Spreadsheets

**Challenges:**
- Users attached to Excel
- Complex formulas
- Ad-hoc workflows

**Approach:**
- Start with simple dashboards
- Replicate key reports
- Gradual adoption

### From Legacy BI

**Challenges:**
- Existing reports and dashboards
- User training
- Data source migration

**Approach:**
- Parallel run (old + new)
- Migrate high-value dashboards first
- Sunset legacy tool gradually

---

## Best Practices

**Start simple:**
- Begin with key metrics
- Expand gradually
- Avoid over-engineering

**Define metrics clearly:**
- Document calculations
- Use semantic layer
- Ensure consistency

**Optimize for performance:**
- Cache aggressively
- Pre-aggregate data
- Monitor query costs

**Enable self-service:**
- Provide training
- Document data sources
- Create templates

**Govern effectively:**
- Certify datasets
- Control access
- Audit usage

---

## References

- **Looker:** https://cloud.google.com/looker/docs
- **Tableau:** https://help.tableau.com/
- **Power BI:** https://docs.microsoft.com/power-bi/
- **Metabase:** https://www.metabase.com/docs/
- **Apache Superset:** https://superset.apache.org/docs/
- **dbt Metrics:** https://docs.getdbt.com/docs/build/metrics
- **Cube.js:** https://cube.dev/docs/

---

## Related Documentation

- **Persistence Guide:** `persistence_guide__t__.md` - Choosing storage technologies
- **Data Warehouse Runbook:** `../runbooks/persistence/data_warehouse_runbook__t__.md` - OLAP databases
- **Analytics Runbooks:** `../runbooks/analytics/` - Platform-specific BI tool operations
