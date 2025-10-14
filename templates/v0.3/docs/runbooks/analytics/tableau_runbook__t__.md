# Tableau Operations Runbook

## Overview

Tableau is an industry-leading commercial BI platform known for powerful visualizations and enterprise features.

**Key features:**
- Drag-and-drop interface
- Advanced visualizations
- Data blending
- Tableau Server/Cloud
- Mobile support
- Enterprise governance

**Deployment:** Desktop (local), Server (on-premise), Cloud (SaaS)

---

## Installation

### Tableau Desktop

**Download:**
```
Visit: https://www.tableau.com/products/desktop/download
Download installer for your OS
Install and activate with license key
```

**System requirements:**
- Windows 10/11 or macOS 10.15+
- 8GB RAM minimum (16GB recommended)
- 15GB disk space

### Tableau Server

**Linux (Ubuntu/RHEL):**
```bash
# Download installer
wget https://downloads.tableau.com/esdalt/2023.3.0/tableau-server-2023-3-0_amd64.deb

# Install
sudo dpkg -i tableau-server-2023-3-0_amd64.deb

# Initialize
sudo /opt/tableau/tableau_server/packages/scripts.*/initialize-tsm --accepteula

# Activate
tsm licenses activate -k <license-key>

# Configure
tsm settings import -f config.json

# Apply changes
tsm pending-changes apply

# Initialize server
tsm initialize

# Start server
tsm start
```

### Tableau Cloud

```
Visit: https://www.tableau.com/products/cloud
Sign up for trial or subscription
Access via web browser
```

---

## Data Sources

### Connecting to Databases

**Supported connectors:**
- PostgreSQL, MySQL, SQL Server
- Oracle, Teradata, SAP HANA
- BigQuery, Redshift, Snowflake
- Excel, CSV, JSON
- 100+ connectors

**Connect to PostgreSQL:**
```
Data > New Data Source > PostgreSQL

Server: db.example.com
Port: 5432
Database: analytics
Authentication: Username and Password
Username: tableau_user
Password: ********

Sign In
```

**Connection options:**
- **Live:** Query database in real-time
- **Extract:** Import data snapshot

### Data Extracts (.hyper)

**Create extract:**
```
Data > [Data Source] > Extract Data

Filters: (optional)
- Add filters to reduce data size

Aggregation:
- Aggregate data for visible dimensions
- Roll up dates to: Month

Number of rows:
- All rows
- Top: 1000000 rows

Extract
```

**Refresh extract:**
```
# Tableau Desktop
Data > [Extract] > Refresh

# Tableau Server (scheduled)
Server > Schedules > Create Schedule
Name: Daily Refresh
Frequency: Daily at 2 AM
```

---

## Creating Visualizations

### Worksheets

**1. Drag and drop:**
- Dimensions to Rows/Columns
- Measures to Rows/Columns or Marks
- Filters to Filters shelf

**2. Example - Sales by Date:**
```
Columns: Order Date (Month)
Rows: Sales (SUM)
Marks: Line
Filters: Order Date (Last 12 months)
```

**3. Customize:**
- Colors, sizes, labels
- Tooltips
- Formatting

### Chart Types

**Bar chart:**
```
Columns: Category
Rows: Sales
Mark type: Bar
Sort: Descending by Sales
```

**Line chart:**
```
Columns: Order Date (continuous)
Rows: Sales
Mark type: Line
Add trend line: Right-click > Trend Lines > Show Trend Lines
```

**Scatter plot:**
```
Columns: Sales
Rows: Profit
Marks: Circle
Color: Category
Size: Quantity
```

**Map:**
```
Drag: State to view
Marks: Map
Color: Sales
```

### Calculated Fields

**Create calculated field:**
```
Analysis > Create Calculated Field

Name: Profit Ratio
Formula: SUM([Profit]) / SUM([Sales])

Or right-click in Data pane > Create Calculated Field
```

**Examples:**
```
# Conditional
IF [Sales] > 1000 THEN "High" ELSE "Low" END

# Date calculation
DATEDIFF('day', [Order Date], [Ship Date])

# Aggregation
AVG([Sales])

# String manipulation
UPPER([Customer Name])

# Window calculation
WINDOW_AVG(SUM([Sales]))
```

### Parameters

**Create parameter:**
```
Data pane > Create Parameter

Name: Top N
Data type: Integer
Current value: 10
Allowable values: Range (1 to 100)
```

**Use in calculated field:**
```
# Top N filter
INDEX() <= [Top N]
```

---

## Dashboards

### Creating Dashboards

**1. Create dashboard:**
```
Dashboard > New Dashboard
Size: Automatic (responsive)
```

**2. Add sheets:**
- Drag worksheets from left panel
- Arrange on canvas

**3. Add objects:**
- Text
- Images
- Web Page
- Blank
- Navigation

**4. Add filters:**
- Drag dimension to dashboard
- Select "Apply to Worksheets" > All Using This Data Source

**5. Add actions:**
- Dashboard > Actions > Add Action
- Filter, Highlight, URL, Go to Sheet

### Dashboard Actions

**Filter action:**
```
Dashboard > Actions > Add Action > Filter

Name: Filter by Category
Source: Sales by Category
Target: All sheets
Run action on: Select

Clearing selection: Show all values
```

**URL action:**
```
Dashboard > Actions > Add Action > Go to URL

Name: Google Search
URL: https://www.google.com/search?q=<Product Name>
Run action on: Menu
```

### Layout Containers

**Horizontal container:**
- Arrange objects left to right
- Useful for headers, filters

**Vertical container:**
- Arrange objects top to bottom
- Useful for stacked charts

**Floating objects:**
- Position anywhere on dashboard
- Useful for legends, filters

---

## Publishing

### Tableau Server

**Publish workbook:**
```
Server > Publish Workbook

Project: Sales Analytics
Name: Sales Dashboard
Description: Monthly sales overview

Permissions: (configure access)
Data Sources: Embed in workbook

Publish
```

**Publish data source:**
```
Server > Publish Data Source

Project: Data Sources
Name: Production DB
Authentication: Viewer credentials

Publish
```

### Tableau Cloud

**Sign in:**
```
Server > Sign In
Server: https://your-site.online.tableau.com
Email: user@example.com
Password: ********
```

**Publish:**
- Same as Tableau Server
- Cloud-hosted, no infrastructure management

---

## Embedding

### Embed Code

**Get embed code:**
```
Tableau Server/Cloud > [Dashboard] > Share
Copy embed code
```

**Embed in webpage:**
```html
<script type='text/javascript' src='https://your-server/javascripts/api/viz_v1.js'></script>
<div class='tableauPlaceholder' style='width: 1000px; height: 800px;'>
  <object class='tableauViz' width='1000' height='800' style='display:none;'>
    <param name='host_url' value='https://your-server/' />
    <param name='embed_code_version' value='3' />
    <param name='site_root' value='' />
    <param name='name' value='SalesDashboard/Overview' />
    <param name='tabs' value='no' />
    <param name='toolbar' value='yes' />
  </object>
</div>
```

### JavaScript API

**Initialize viz:**
```javascript
var containerDiv = document.getElementById("vizContainer");
var url = "https://your-server/views/SalesDashboard/Overview";

var options = {
  hideTabs: true,
  hideToolbar: false,
  width: "1000px",
  height: "800px",
  onFirstInteractive: function() {
    console.log("Viz loaded");
  }
};

var viz = new tableau.Viz(containerDiv, url, options);
```

**Filter via API:**
```javascript
var worksheet = viz.getWorkbook().getActiveSheet();
worksheet.applyFilterAsync(
  "Category",
  ["Furniture", "Technology"],
  tableau.FilterUpdateType.REPLACE
);
```

### Trusted Authentication

**Request ticket (server-side):**
```python
import requests

def get_trusted_ticket(server, username, site=''):
    url = f"https://{server}/trusted"
    data = {
        'username': username,
        'target_site': site
    }
    response = requests.post(url, data=data)
    return response.text

ticket = get_trusted_ticket('your-server.com', 'user@example.com')
embed_url = f"https://your-server.com/trusted/{ticket}/views/Dashboard/Sheet"
```

---

## User Management

### Roles (Tableau Server/Cloud)

**Site roles:**
- **Site Administrator Creator:** Full access
- **Creator:** Create and publish content
- **Explorer:** View and interact
- **Viewer:** View only

**Assign role:**
```
Server > Users > [User] > Site Role
Select role
Save
```

### Permissions

**Set permissions:**
```
Server > [Workbook/Data Source] > Permissions

Add user/group
Set capabilities:
- View: Allow/Deny
- Filter: Allow/Deny
- Download: Allow/Deny
- Web Edit: Allow/Deny

Save
```

### Row-Level Security

**Create user filter:**
```
Data > [Data Source] > Create Calculated Field

Name: User Filter
Formula: [Region] = USERNAME()

Or use ISMEMBEROF() for groups:
ISMEMBEROF([Sales Team])
```

**Apply filter:**
```
Drag User Filter to Filters
Select True
Right-click > Apply to Worksheets > All Using This Data Source
```

---

## Performance Optimization

### Data Extracts

**Optimize extracts:**
- Filter unnecessary data
- Aggregate to appropriate level
- Hide unused fields
- Use incremental refresh

**Incremental refresh:**
```
Data > [Extract] > Extract > Edit

Incremental refresh:
- Identify new rows using column: Order Date
- Rows with Order Date > [last refresh date]
```

### Query Optimization

**Use context filters:**
```
Filters > [Filter] > Add to Context
```
- Evaluated first
- Creates temporary table
- Improves performance for dependent filters

**Reduce marks:**
- Aggregate data
- Limit number of data points
- Use sampling for large datasets

### Caching

**Server caching:**
- Automatic query result caching
- Configurable cache timeout
- Shared across users

---

## Administration

### Tableau Server Management

**TSM (Tableau Services Manager):**
```bash
# Status
tsm status -v

# Start/stop
tsm start
tsm stop
tsm restart

# Backup
tsm maintenance backup -f backup.tsbak

# Restore
tsm maintenance restore -f backup.tsbak

# Logs
tsm maintenance ziplogs -f logs.zip
```

### Monitoring

**Admin views:**
```
Server > Status
- Server status
- Background tasks
- Data source connections
```

**Performance metrics:**
- View load times
- Query performance
- Extract refresh duration
- User activity

### Upgrades

```bash
# Backup
tsm maintenance backup -f pre-upgrade-backup.tsbak

# Download new version
wget https://downloads.tableau.com/esdalt/2024.1.0/tableau-server-2024-1-0_amd64.deb

# Stop server
tsm stop

# Upgrade
sudo dpkg -i tableau-server-2024-1-0_amd64.deb

# Apply changes
tsm pending-changes apply

# Start server
tsm start
```

---

## Best Practices

**Data modeling:**
- Use extracts for large datasets
- Optimize data sources
- Hide unused fields

**Visualizations:**
- Choose appropriate chart types
- Use color purposefully
- Add clear labels and titles

**Dashboards:**
- Keep focused (5-10 sheets)
- Use filters for interactivity
- Optimize for mobile

**Performance:**
- Use extracts instead of live connections
- Aggregate data appropriately
- Limit number of marks

**Governance:**
- Implement row-level security
- Use projects for organization
- Audit user activity

---

## Troubleshooting

**Slow performance:**
- Use extracts instead of live
- Add context filters
- Reduce number of marks
- Optimize data source

**Extract refresh failures:**
- Check database connectivity
- Verify credentials
- Review extract filters
- Check disk space

**Publishing errors:**
- Verify permissions
- Check data source authentication
- Review server logs

---

## References

- **Tableau Help:** https://help.tableau.com/
- **Tableau Community:** https://community.tableau.com/
- **Tableau Public:** https://public.tableau.com/

---

## Related Documentation

- **Analytics Guide:** `docs/guides/analytics_guide__t__.md`
- **Data Warehouse Runbook:** `docs/runbooks/persistence/data_warehouse_runbook__t__.md`
