# Analytics Runbooks

This directory contains operational runbooks for Business Intelligence (BI) and analytics platforms. These runbooks provide concrete setup instructions, configurations, and best practices for deploying and managing analytics tools.

## Purpose

These runbooks complement the general analytics guide (`docs/guides/analytics_guide__t__.md`) by providing platform-specific implementation details. Use the analytics guide to understand **what** tool to choose and **when**, then refer to these runbooks for **how** to implement and operate it.

## Available Runbooks

### Open-Source BI Tools
- **[Metabase Runbook](metabase_runbook__t__.md)** - Setup, questions, dashboards, embedding, administration
- **[Apache Superset Runbook](superset_runbook__t__.md)** - Installation, charts, dashboards, SQL Lab, security

### Commercial BI Tools
- **[Looker Runbook](looker_runbook__t__.md)** - LookML, explores, dashboards, embedded analytics, deployment
- **[Tableau Runbook](tableau_runbook__t__.md)** - Workbooks, data sources, publishing, Tableau Server

## Runbook Structure

Each runbook follows a consistent structure:

1. **Overview** - Platform capabilities and use cases
2. **Installation & Setup** - Deployment options and initial configuration
3. **Data Sources** - Connecting to databases and data warehouses
4. **Creating Visualizations** - Charts, graphs, and visual elements
5. **Dashboards** - Building and organizing dashboards
6. **Semantic Layer** - Defining metrics and business logic (if applicable)
7. **Embedding** - Integrating analytics into applications
8. **User Management** - Authentication, authorization, and access control
9. **Performance Optimization** - Caching, query optimization
10. **Administration** - Backup, monitoring, upgrades

## When to Use

- **Analytics guide first**: Start with `analytics_guide__t__.md` to understand BI concepts, architecture patterns, and tool selection criteria
- **Runbook for implementation**: Once you've chosen a tool, use the appropriate runbook for specific setup and configuration steps
- **Cross-reference**: Runbooks reference the analytics guide for context and rationale

## Tool Selection Quick Reference

**For small teams (<10 users):**
- Start with [Metabase](metabase_runbook__t__.md) - Simple, user-friendly

**For SQL-comfortable users:**
- Consider [Superset](superset_runbook__t__.md) - Powerful, extensible

**For embedded analytics:**
- Evaluate [Looker](looker_runbook__t__.md) - Semantic modeling, white-labeling

**For enterprise reporting:**
- Review [Tableau](tableau_runbook__t__.md) - Industry leader, advanced visualizations

## Contributing

When adding platform-specific details:
- Keep the analytics guide general and conceptual
- Put specific commands, configurations, and procedures in runbooks
- Include version information for tools and dependencies
- Provide examples with realistic data
- Document common pitfalls and troubleshooting steps

## Related Documentation

- **Analytics Guide**: `docs/guides/analytics_guide__t__.md` - General concepts and strategies
- **Persistence Runbooks**: `docs/runbooks/persistence/` - Database and data warehouse operations
- **Data Warehouse Runbook**: `docs/runbooks/persistence/data_warehouse_runbook__t__.md` - OLAP databases
