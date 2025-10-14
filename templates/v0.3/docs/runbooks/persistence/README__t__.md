# Persistence Runbooks

This directory contains operational runbooks for specific database platforms and products. These runbooks provide concrete commands, configurations, and procedures for production operations.

## Purpose

These runbooks complement the general persistence operations guide (`docs/guides/persistence_operations_guide__t__.md`) by providing platform-specific implementation details. Use the operations guide to understand **what** to do and **when**, then refer to these runbooks for **how** to do it on your specific platform.

## Available Runbooks

### Relational Databases (OLTP)
- **[PostgreSQL Runbook](postgresql_runbook__t__.md)** - Backup, replication, performance tuning, failover procedures
- **[MySQL Runbook](mysql_runbook__t__.md)** - Backup, replication, performance tuning, failover procedures

### NoSQL Databases
- **[MongoDB Runbook](mongodb_runbook__t__.md)** - Backup, sharding, replica sets, performance tuning
- **[Redis Runbook](redis_runbook__t__.md)** - Backup, replication, clustering, persistence modes

### Data Warehouses (OLAP)
- **[Data Warehouse Runbook](data_warehouse_runbook__t__.md)** - ClickHouse, BigQuery, Redshift, Snowflake operations

### Cloud Managed Databases
- **[Cloud Databases Runbook](cloud_databases_runbook__t__.md)** - AWS RDS/Aurora, GCP Cloud SQL, Azure Database services

## Runbook Structure

Each runbook follows a consistent structure:

1. **Overview** - Platform capabilities and limitations
2. **Installation & Setup** - Initial configuration
3. **Backup & Recovery** - Specific commands and procedures
4. **Replication & High Availability** - Setup and failover procedures
5. **Performance Tuning** - Configuration parameters and optimization
6. **Monitoring & Alerting** - Key metrics and thresholds
7. **Common Operations** - Day-to-day tasks and procedures
8. **Troubleshooting** - Common issues and solutions
9. **Security** - Authentication, authorization, encryption
10. **Upgrade Procedures** - Version upgrades and migrations

## When to Use

- **Operations guide first**: Start with `persistence_operations_guide__t__.md` to understand concepts, strategies, and best practices
- **Runbook for implementation**: Once you know what you need to do, use the appropriate runbook for specific commands and configurations
- **Cross-reference**: Runbooks reference the operations guide for context and rationale

## Contributing

When adding platform-specific details:
- Keep the operations guide general and conceptual
- Put specific commands, configurations, and procedures in runbooks
- Include version information for commands and configurations
- Provide examples with realistic values
- Document common pitfalls and gotchas

## Related Documentation

- **Operations Guide**: `docs/guides/persistence_operations_guide__t__.md` - General strategies and concepts
- **Persistence Guide**: `docs/guides/persistence_guide__t__.md` - Choosing storage technologies and data modeling
- **Infrastructure Runbooks**: `docs/runbooks/infrastructure/` - Platform deployment and infrastructure operations
