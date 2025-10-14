# Pyve Version History

## References
- Building Guide: `docs/guides/building_guide.md`
- Planning Guide: `docs/guides/planning_guide.md`
- Testing Guide: `docs/guides/testing_guide.md`
- Dependencies Guide: `docs/guides/dependencies_guide.md`
- Decision Log: `docs/specs/decisions_spec.md`
- Codebase Spec: `docs/specs/codebase_spec.md`

## v0.3.9 Analytics & BI in Templates [Implemented]
- [x] General guidelines for analytics `docs/guides/analytics_guide__t__.md`
  - [x] Choosing BI tools (self-hosted vs cloud, open-source vs commercial)
  - [x] Architecture patterns (embedded analytics, self-service, centralized)
  - [x] Data modeling for analytics (metrics, dimensions, semantic layers)
  - [x] Performance considerations (caching, pre-aggregation, query optimization)
- [x] Analytics runbooks `docs/runbooks/analytics/`
  - [x] Looker runbook (LookML, explores, dashboards, deployment)
  - [x] Metabase runbook (setup, questions, dashboards, embedding)
  - [x] Superset runbook (installation, charts, dashboards, SQL Lab)
  - [x] Tableau runbook (workbooks, data sources, publishing)
- [x] Create README for analytics runbooks directory

### Notes
- Created `analytics_guide__t__.md` (650+ lines) covering:
  - BI tool selection criteria (team size, technical expertise, use case, budget)
  - Decision matrix comparing self-hosted open-source, cloud open-source, and commercial cloud options
  - Architecture patterns: Centralized, self-service, embedded, hybrid (data mesh)
  - Semantic layer concepts (metrics, dimensions, LookML examples)
  - Data modeling for analytics (star schema, metrics vs dimensions)
  - Performance optimization (caching strategies, pre-aggregation, query optimization)
  - Embedding analytics (iframe, JavaScript SDK, API-based, multi-tenancy)
  - Self-service enablement (data catalog, training, governance)
  - Security & governance (access control, RLS, audit logging)
  - Cost optimization strategies
- Created 4 comprehensive analytics runbooks (2,850+ lines total):
  - **Looker Runbook** (700+ lines): LookML syntax, models/views/explores, PDTs, embedding (signed URLs, SSO), user management, RLS, performance optimization, administration
  - **Metabase Runbook** (550+ lines): Docker/JAR installation, visual query builder, SQL queries, dashboards, embedding (public sharing, signed embedding), user management, sandboxing, caching, administration
  - **Superset Runbook** (650+ lines): Docker/Kubernetes/pip installation, SQL Lab, 40+ chart types, native filters, cross-filtering, semantic layer, embedding (guest tokens), RLS, async queries, Celery configuration
  - **Tableau Runbook** (650+ lines): Desktop/Server/Cloud setup, data sources, calculated fields, parameters, dashboards, publishing, embedding (JavaScript API, trusted auth), RLS, extracts, TSM administration
- Created README (50+ lines) explaining runbook structure and tool selection guidance
- Complements existing persistence documentation with analytics/visualization layer
- Provides clear separation: persistence (data storage) → analytics (data presentation)

## v0.3.8c Data Warehouse Runbook [Implemented]
- [x] Create data warehouse runbook covering OLAP databases
- [x] ClickHouse operations (table engines, partitioning, materialized views, distributed tables)
- [x] BigQuery operations (partitioning, clustering, cost optimization, scheduled queries)
- [x] Redshift operations (distribution styles, sort keys, VACUUM/ANALYZE, Spectrum)
- [x] Snowflake operations (virtual warehouses, time travel, cloning, Snowpipe)

### Notes
- Created `data_warehouse_runbook__t__.md` (650+ lines) covering:
  - **ClickHouse**: Installation, table engines (MergeTree, ReplacingMergeTree, Distributed), data loading, materialized views, query optimization, monitoring
  - **BigQuery**: Dataset/table creation, partitioning, clustering, query optimization, cost optimization, scheduled queries
  - **Redshift**: Cluster creation, distribution styles (KEY, ALL, EVEN), sort keys (compound, interleaved), COPY from S3, VACUUM/ANALYZE, Redshift Spectrum
  - **Snowflake**: Database/warehouse creation, clustering, external tables, data loading, Snowpipe, time travel, zero-copy cloning, cost optimization
  - Common patterns: ETL/ELT, incremental loads, data modeling (star schema)
- Complements existing OLTP database runbooks with OLAP-specific operations
- Updated persistence runbooks README to include data warehouse category

## v0.3.8b Generalize/Split Persistence Ops [Implemented]
- [x] Generalize the persistence operations guide
- [x] Split the platform/product-specific details into runbooks

### Notes
- Refactored `persistence_operations_guide__t__.md` from 913 lines to 848 lines (7% reduction)
- Removed all platform-specific commands and configurations
- Replaced with general concepts, strategies, and references to runbooks
- Created 5 comprehensive persistence runbooks (4,822 lines total):
  - **PostgreSQL Runbook** (987 lines): Installation, backup/recovery, replication, performance tuning, monitoring, troubleshooting, security, upgrades
  - **MySQL Runbook** (1,053 lines): Installation, backup/recovery (mysqldump, XtraBackup, binary logs), replication, performance tuning, monitoring, troubleshooting, security, upgrades
  - **MongoDB Runbook** (922 lines): Installation, backup/recovery (mongodump, oplog, snapshots), replica sets, sharding, performance tuning, monitoring, troubleshooting, security, upgrades
  - **Redis Runbook** (969 lines): Installation, backup/recovery (RDB, AOF), replication, Sentinel, clustering, performance tuning, monitoring, troubleshooting, security, upgrades
  - **Cloud Databases Runbook** (891 lines): AWS (RDS, Aurora, DynamoDB, ElastiCache), GCP (Cloud SQL, Spanner, Firestore, Memorystore), Azure (Azure Database, Cosmos DB, Azure Cache)
- Created README (56 lines) explaining runbook structure and usage
- Benefits of separation:
  - **Operations guide:** General strategies, concepts, decision-making (what and when)
  - **Runbooks:** Platform-specific commands, configurations, procedures (how to implement)
  - **Easier maintenance:** Update platform-specific details without changing general guide
  - **Better discoverability:** Users can jump directly to their platform's runbook
  - **Reduced cognitive load:** Focused documentation for specific use cases

## v0.3.8 Persistence in Templates [Implemented]
- [x] General guidelines for persistence `docs/guides/persistence_guide__t__.md`
  - [x] Coverage of architectures: OLTP, OLAP, NoSQL, caching, object storage, time-series, search, message queues
  - [x] Decision framework for choosing storage technologies
  - [x] Data modeling and schema design (normalization, indexing, migrations)
- [x] Production operations for persistence `docs/guides/persistence_operations_guide__t__.md`
  - [x] Backup/recovery strategies (RTO/RPO, tools, testing)
  - [x] Data migration (big bang, phased, parallel run, strangler pattern)
  - [x] Performance optimization (query tuning, database config, caching, sharding/partitioning)
  - [x] Scalability strategies (vertical/horizontal scaling, auto-scaling)
  - [x] High availability (replication, failover, multi-region)
  - [x] Security & governance (encryption, access control, audit logging, compliance)
  - [x] Data lifecycle management (storage tiers, lifecycle policies, deletion strategies)
  - [x] Cost management (optimization, pricing models)
- [x] Move infrastructure runbooks to make room for other runbooks

### Notes
- Created `templates/v0.3/docs/guides/persistence_guide__t__.md` (500+ lines) covering:
  - Decision matrix for choosing storage technologies (8 factors: data structure, access patterns, consistency, scale, query complexity, latency, durability, cost)
  - Common architecture patterns (web app, analytics, real-time/event-driven, microservices)
  - Data storage patterns:
    - Relational databases (PostgreSQL, MySQL, SQLite, CockroachDB)
    - NoSQL: Key-value stores (Redis, Memcached, DynamoDB), Document stores (MongoDB, Firestore), Graph databases (Neo4j, Neptune), Wide-column stores (Cassandra, ScyllaDB)
    - Caching (Redis, Memcached, Varnish, CDN) with strategies (cache-aside, write-through, write-behind, refresh-ahead)
    - Object storage (S3, GCS, Azure Blob, MinIO, Tigris)
    - Data warehouses & lakes (BigQuery, Snowflake, Redshift, Databricks, ClickHouse)
    - Time-series databases (Prometheus, InfluxDB, TimescaleDB)
    - Search engines (Elasticsearch, Meilisearch, Typesense, Algolia)
    - Message queues & event streams (Kafka, RabbitMQ, SQS, Redis Streams, Pulsar)
  - Data modeling & schema design:
    - Relational design (normalization, indexing strategies, data types, constraints)
    - NoSQL patterns (embed vs reference, key design, data structures)
    - Schema versioning & migrations (expand-contract, dual writes, tools: Flyway, Liquibase, Alembic)
- Created `templates/v0.3/docs/guides/persistence_operations_guide__t__.md` (900+ lines) covering:
  - Backup & recovery:
    - Backup types (full, incremental, differential, continuous) with frequency and retention policies
    - Tools for relational (PostgreSQL, MySQL, RDS), NoSQL (MongoDB, Redis, Cassandra), object storage (S3)
    - Recovery procedures (RTO/RPO tiers, recovery steps, testing backups)
  - Data migration:
    - Strategies (big bang, phased, parallel run, strangler pattern) with pros/cons
    - Tools (AWS DMS, GCP Database Migration Service, Flyway, Liquibase, dbt)
    - Best practices (pre/during/post-migration)
  - Performance optimization:
    - Query optimization (identifying slow queries, EXPLAIN analysis, indexing, query rewriting)
    - Database tuning (PostgreSQL/MySQL configuration, connection pooling with PgBouncer/ProxySQL)
    - Caching strategies (application-level with Redis, database-level with materialized views)
    - Sharding & partitioning (range/hash partitioning, application-level sharding)
  - Scalability strategies:
    - Vertical scaling (scale up) vs horizontal scaling (scale out)
    - Read replicas (setup, routing, replication lag considerations)
    - Auto-scaling (managed services, self-managed monitoring)
  - High availability:
    - Replication (synchronous vs asynchronous, configuration)
    - Failover (automatic tools: Patroni, MHA; failover process; split-brain prevention)
    - Multi-region deployments (active-passive, active-active, read replicas)
  - Security & governance:
    - Encryption (at rest: TDE, column-level, application-level; in transit: SSL/TLS, VPN)
    - Access control (authentication methods, RBAC, row-level security)
    - Audit logging (what to log, tools: pgaudit, managed services)
    - Compliance (GDPR, HIPAA, PCI DSS, SOC 2)
  - Data lifecycle management:
    - Storage tiers (hot, warm, cold, glacier/archive)
    - Lifecycle policies (automatic transitions, S3 lifecycle, database partitioning)
    - Data deletion (soft delete, hard delete, anonymization)
  - Cost management:
    - Optimization strategies (right-sizing, reserved capacity, storage optimization, query optimization)
    - Pricing models (instance-based, serverless, storage+compute)
    - Cost comparison (managed vs self-managed vs serverless)
- Separation of concerns (Option B):
  - `persistence_guide.md`: Patterns, architectures, decision-making, data modeling (what and when)
  - `persistence_operations_guide.md`: Production operations, procedures, commands (how to operate)
  - Designed to avoid token limit issues for LLMs while maintaining comprehensive coverage
  - Cross-references between guides for easy navigation

## v0.3.7 Infrastructure in Templates [Implemented]
- [x] Add infrastructure templates to the Pyve repo
- [x] Add mentions of Podman, Alpine Linux, `ash` shell
- [x] Add operational runbooks for major platforms

### Notes
- Created comprehensive `templates/v0.3/docs/guides/infrastructure_guide__t__.md` (400+ lines) covering:
  - Infrastructure as Code (IaC): principles, tool selection, directory structure, state management
  - Configuration Management: 12-factor app principles, env vars, platform-specific config
  - Secrets Management: principles, strategies (platform stores, external managers), rotation
  - Deployment Strategies: rolling, blue-green, canary, feature flags, health checks, rollback
  - Scaling: horizontal/vertical scaling, auto-scaling configuration, platform-specific guidance
  - Monitoring & Observability: logs, metrics, traces, alerting best practices
  - Cost Management: optimization strategies, tracking, budgets
  - Disaster Recovery: backup strategy, RTO/RPO, high availability patterns
  - Security: network security, access control, compliance
  - Platform-Specific Guidance: when to use Fly.io, AWS, GCP, Azure, Heroku, Kubernetes
  - Runbooks: structure for vendor-specific operational procedures
  - Infrastructure Readiness Checklist
- Enhanced `templates/v0.3/docs/specs/implementation_options_spec__t__.md`:
  - Expanded "Infrastructure & Hosting" section with detailed considerations (deployment, configuration, secrets, scaling, monitoring, cost, governance, operations, developer experience)
  - Expanded "Packaging & Distribution" section with container runtime comparison (Docker vs Podman), base image options (Alpine Linux vs Ubuntu/Debian), and deployment considerations
- Enhanced `templates/v0.3/docs/specs/technical_design_spec__t__.md`:
  - Added IaC, platform-specific config (Dockerfile/Containerfile, docker-compose.yml/podman-compose.yml), and environment parity to Configuration section
  - Added deployment mechanism, health checks, monitoring during rollout, and zero-downtime strategies to Rollout & Migration section
- Enhanced `templates/v0.3/docs/specs/codebase_spec__t__.md`:
  - Added Docker/Podman clarification to Build & Packaging section
  - Added new "Infrastructure (if deployed)" section with provider, regions, IaC, platform config, container runtime (Docker vs Podman), base images (Alpine Linux with `ash` shell), secrets, scaling, monitoring, cost tracking, disaster recovery, and access control
- Updated `templates/v0.3/docs/guides/llm_onramp_guide__t__.md`:
  - Added infrastructure_guide.md to reading order (position #7)
  - Updated minimal prompt to include infrastructure guide
- Podman mentions throughout:
  - Consistently referenced as "Podman (free and open alternative)" or "Podman (a free and open alternative)"
  - Noted as daemonless and rootless in implementation_options_spec
  - Containerfile mentioned alongside Dockerfile
  - podman-compose.yml mentioned alongside docker-compose.yml
- Alpine Linux and `ash` shell mentions:
  - Specifically called out as minimal base image option
  - Noted in codebase_spec Infrastructure section: "Alpine Linux (minimal, uses `ash` shell)"
  - Included in implementation_options_spec considerations for container size optimization
- Created operational runbooks in `templates/v0.3/docs/runbooks/`:
  - `README__t__.md`: Overview, best practices, runbook structure, integration with other docs, quick reference commands
  - `fly_io_runbook__t__.md`: Complete operational procedures for Fly.io (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - `aws_runbook__t__.md`: Complete operational procedures for AWS ECS/Fargate (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - `gcp_runbook__t__.md`: Complete operational procedures for GCP Cloud Run/GKE (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - `kubernetes_runbook__t__.md`: Complete operational procedures for Kubernetes (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - Each runbook includes platform-specific commands, configuration examples, troubleshooting guides, and cost optimization tips
  - Runbooks complement infrastructure_guide.md by providing concrete, executable procedures vs general patterns

## v0.3.6 Template Upgrade [Implemented]
Change `pyve.sh` to upgrade the local git repository from the user's home directory on `--upgrade` flag (similar to `--init`)
- [x] Read the `{old_version}` (e.g., `v0.3.0`) from the local git repo `./.pyve/version` file
- [x] Check if there is a newer version (e.g., `v0.3.1`) in `~/.pyve/templates/` directory. If so:
  - [x] Compare and conditionally copy any files that would normally be copied by `--init`, but don't fail if any files are not identical.
    - [x] Identical to older version: copy the new file and overwrite the old file
    - [x] Not identical to older version: copy the new file and suffix it with `__t__{newer_version}` and warn the user that the newer version was not applied for that file.
- [x] Track whether the upgrade process completed 
  - [x] Use some status file and write the arguments that were passed to `pyve.sh` script.
  - [x] The status file should be named `./.pyve/status/upgrade`
  - [x] At the beginning of the upgrade operation, if any file is already present in the `./.pyve/status` directory, something might be broken, so fail...don't make it worse.
- [x] Change the version in `./.pyve/version` file to the new version.

### Notes
- Perform guarded copy/compare; never overwrite non-identical files silently.
- Use `./.pyve/status/upgrade` to ensure idempotency and to fail fast if a previous run left state.
- Implemented `upgrade_templates()` function that reads the current project version and compares with available templates.
- Uses `upgrade_status_fail_if_any_present()` to enforce status cleanliness before starting.
- For each template file:
  - If the local file is identical to the old template version, it overwrites with the new version.
  - If the local file has been modified, it creates a new file with suffix `__t__{newer_version}` and warns the user.
  - If the file doesn't exist locally, it adds it.
- Updates `./.pyve/version` file to the new version after successful upgrade.
- Writes status to `./.pyve/status/upgrade` with timestamp and arguments.
- Provides clear summary of upgraded/added files and skipped modified files.

## v0.3.5 Template Update [Implemented]
Change `pyve.sh` to perform an update from of Pyve repo template documents into the user's home directory on `--update` flag (similar to `--install`).
- [x] Read the source path from `~/.pyve/source_path` file
- [x] Check if there is a newer version in Pyve `{source_path}/templates/` than is in the home directory `~/.pyve/templates/` directory. If so, copy the newer version to `~/.pyve/templates/{newer_version}`, which could have multiple versions.
- [x] Change the version in `./.pyve/version` file to the new version.

### Notes
- Keep `~/.pyve/templates/{version}` immutable once written; add newer versions side-by-side.
- Reuse install-time copy logic; do not mutate `source_path` here.
- Implemented `update_templates()` function that reads source path, compares versions, and copies newer templates.
- Version comparison uses string comparison which works for v0.X format.
- Templates are kept immutable; if a version already exists in `~/.pyve/templates/`, it won't be overwritten.
- Updates `~/.pyve/version` file to track the pyve version that performed the update.

## v0.3.4 Documentation Revision [Implemented]
With all the new documentation templates, I updated Pyve's documents to be in line with its templates. 
- [x] Added missing docs (`implementation_options_spec.md`, `python_guide.md`)
- [x] Filled in Pyve-specific details in other docs
- [x] Updated README

## v0.3.3 Template Purge [Implemented]
Change `pyve.sh` to remove the special Pyve documents in local git repo on --purge flag
- [x] Obtain the version from the local git repo `./.pyve/version` file
- [x] Remove only documents that are identical to the files in `~/.pyve/templates/{version}/*`
- [x] Warn with file names not identical, but don't remove those. 
- [x] Track whether the purge process completed 
  - [x] Use some status file and write the arguments that were passed to `pyve.sh` script.
  - [x] The status file should be named `./.pyve/status/purge`
  - [x] At the beginning of the purge operation, if any file is already present in the `./.pyve/status` directory, something might be broken, so fail...don't make it worse.

### Notes
- Only delete files that are byte-for-byte identical to the corresponding template for the recorded version.
- Use `./.pyve/status/purge` to track and guard runs; never remove modified files.
- Init message ordering: the `direnv allow` reminder is printed last in `--init` for visibility.
- Template copy noise suppression during `--init`:
  - Disables shell tracing within copy routine.
  - Avoids subshell/process substitution in loops.
  - Redirects detailed copy logs to `./.pyve/status/init_copy.log`.
- Idempotent re-init behavior:
  - If `./.pyve/status/init` exists (and only benign files like `init_copy.log`/`.DS_Store`), template copy is skipped with a clear message.
  - Unexpected extra files under `./.pyve/status/` still trigger a safe abort.
- Robust install handoff logic:
  - Outside the source repo, `--install` hands off to the recorded source path (`~/.pyve/source_path`).
  - Inside the source repo but invoked via the installed binary, `--install` hands off to local `./pyve.sh` to ensure the latest source and `VERSION` are used.
- Install identical-target handling: if `~/.local/bin/pyve.sh` is identical, skip copying without error but ensure the executable bit and symlink are correct.

## v0.3.2a Bugfixes [Implemented]
- [x] Several rounds of fixes and tests to remove noisy template copying, skip gracefully on re-init. `--install` and `--init` tested. `--init` fresh and re-installs work correctly. 

## v0.3.2 Template Initialization [Implemented]
Change `pyve.sh` so the initialization process copies the latest version of certain templates from the user's `~/.pyve/templates/{version}/*` directory into the user's local git repo (current user directory, invoked at the root of a codebase project) when the `--init` flag is used.  
- [x] Check first to see if any files in the local git repo would be overwritten by the template files and are not identical to the template files. If so, fail the init process with a message.
- [x] Record the now current version of the Pyve command in a version config file in the local git repo: (e.g., `~/pyve.sh --version > ./.pyve/version`)
- [x] Track whether the init process completed 
  - [x] Use some status file and write the arguments that were passed to `pyve.sh` script.
  - [x] The status file should be named `./.pyve/status/init`
  - [x] At the beginning of the init operation, if any file is already present in the `./.pyve/status` directory, something might be broken, so fail...don't make it worse.
- [x] When copying template files (all of which have a suffix `__t__*.md`, where `*` is any characters or no characters), copy files to the local git repo with the suffix removed, but retain the file extension. (e.g., `my_template__t__1234abc.md` -> `my_template.md`)
- [x] Root Docs: `~/.pyve/templates/{version}/*` to `.`
- [x] Guides: `~/.pyve/templates/{version}/docs/guides/*` to `./docs/guides/`
- [x] Specs: `~/.pyve/templates/{version}/docs/specs/*` to `./docs/specs/`
- [x] Languages: `~/.pyve/templates/{version}/docs/specs/lang/{lang}_spec.md` to `./docs/specs/lang/` (depending on which languages are initialized with asdf) 
- [x] Change the version in `./.pyve/version` file to the new version.

### Notes
- Preflight: if any target file would be overwritten and is not identical, abort with a clear message.
- Record run state in `./.pyve/status/init` and the active template version in `./.pyve/version`.

## v0.3.1 Template Installation [Implemented]
- [x] Change `pyve.sh` so that on the `--install` flag (which must be run from the git repo root of the Pyve codebase), it records the current path (`pwd`) in a new `~/.pyve/source_path` file. 
- [x] Change `pyve.sh` so that if the `~/.pyve/source_path` file already exists, handoff control (`{source_path}/pyve.sh --install`) so the newer version can replace the existing `~/.local/bin/pyve.sh`.
- [x] Change `pyve.sh` to install the latest version of templates from this codebase directory structure `templates` directory in the user's home directory (e.g., `~/.pyve/templates/`) when the `--install` flag is used. So if `v0.3` is the latest version, it will copy the template files as-is from `./templates/v0.3` into `~/.pyve/templates/v0.3/`.
- [x] Change `pyve.sh` to remove the `~/.pyve` directory when the `--uninstall` flag is used.

### Notes
- Record `pwd` to `~/.pyve/source_path` on `--install`.
- Copy current latest templates to `~/.pyve/templates/{latest}` on `--install`.
- `--uninstall` should remove `~/.pyve` cleanly.

## v0.3.0 Template Generalization [Implemented]
This is a complex change, so please ask questions if there are any ambiguities. 
The `templates` directory contains versioned meta documents that Pyve will use when developers need to initialize or upgrade documentation stubs in a local git repository. It will help them create a consistent codebase structure with ideal, industry standard documentation and instructions. And an LLM can help support those standards and policies. Currently, the `templates` directory contains the `v0.3` directory, which will be a release of Pyve documentation templates accompanying any v0.3.x of Pyve. 
- [x] Let's first make sure all the templates in `./templates/v0.3` are generic:
  - [x] No Python-specific language details (unless it's just an example, and except of course `/templates/v0.3/docs/specs/lang/python_spec.md`)
  - [x] No project-specific details. (e.g., anything about "Pyve" or "Data Merge")
  - [x] Do not change the anchors or references. Since when Pyve copies the files to another location, they will have the correct anchors and references in an initialized project.
- [x] Add a quality model to give context to the codebase spec and the technical design spec
- [x] Add an implementation options spec to bridge the gap between the codebase spec and the technical design spec
- [x] Add an LLM on-ramp guide to give an LLM a single point of entry to the codebase. 

### Notes
- `templates/v0.3/` inventory confirmed (e.g., `README__t__.md`, `CONTRIBUTING__t__.md`, `docs/guides/*_guide__t__.md`, `docs/specs/*__t__.md`).
- Allowed mention retained: `templates/v0.3/CONTRIBUTING__t__.md` includes “Consider using Pyve…”.
- Completed genericization work:
  - `templates/v0.3/docs/specs/technical_design_spec__t__.md`: replaced project-specific content with a neutral technical design template (structure preserved).
  - `templates/v0.3/docs/guides/dependencies_guide__t__.md`: rewritten to be language-agnostic and to reference `docs/guides/lang/`.
  - `templates/v0.3/docs/guides/lang/python_guide__t__.md`: created; moved Python dependency/version guidance here.
  - `templates/v0.3/docs/specs/codebase_spec__t__.md`: neutralized repository name/summary and genericized paths/entrypoints examples.
  - `templates/v0.3/README__t__.md`: rewritten to a framework‑neutral README template; includes a recommendation to consider using Pyve for Python environment setup.
  - Quality model: added `## Quality` section with level selector and entry/exit gates to `templates/v0.3/docs/specs/technical_design_spec__t__.md` (after `## Architecture`) and to `templates/v0.3/docs/specs/codebase_spec__t__.md` (after `## Repository`).
  - Implementation options: added `templates/v0.3/docs/specs/implementation_options_spec__t__.md` to bridge between high-level design and detailed codebase spec.
  - LLM on‑ramp: added `templates/v0.3/docs/guides/llm_onramp_guide__t__.md` and cross‑linked from `templates/v0.3/README__t__.md` (Getting Started, Development).
- Remaining to genericize in v0.3.0:
- Constraints:
  - Preserve all anchors and relative links; only change copy to be generic and relocate language-specific docs under `docs/guides/lang/`.
- Decision references: none yet.

## v0.2.8 Documentation Templates [Implemented]
Note that the directory structure in `docs` directory has changed,
- [x] Re-read all those `doc` directory documents and root documents (README.md, CONTRIBUTING.md)
- [x] Update any anchors, links, and references to reflect the new structure and doc names. 

### Notes
- Updated references in specs and guides to use `docs/guides/*_guide.md` and `docs/specs/*_spec.md` paths.
- Fixed links to versions spec, decisions spec, and technical design spec where applicable.

## v0.2.7 Tweak doc directories [Implemented]
- [x] Move Guides to `docs/guides/`(typically read only files)
- [x] Move Specs to `docs/specs/` (edited as the codebase evolves)
- [x] Suffix the filenames with `_guide` or `_spec` for easy identification of the purpose and use of the file.

### Notes
- Implemented manually

## v0.2.6 Codebase Specification [Implemented]
Provide a generic way to specify any codebase's structure and dependencies in a language-neutral way. This will help Pyve to generate the appropriate files for any codebase.
- [x] Implement `docs/specs/codebase_spec.md` (general doc)
- [x] Implement `docs/specs/lang/<lang>.md` (language-specific docs) for Python and Shell
- [x] Update the format of this file. 

### Notes
- Implemented manually

## v0.2.5 Requirements [Implemented]
Add an --install flag to the pyve.sh script that will... 
- [x] create a $HOME/.local/bin directory (if not already created)
- [x] add $HOME/.local/bin to the PATH (if not already in the PATH)
- [x] copy pyve.sh from the current directory to $HOME/.local/bin
- [x] make pyve.sh executable ($HOME/.local/bin/pyve.sh)
- [x] update the README.md to include the --install flag
- [x] create a symlink from $HOME/.local/bin/pyve to $HOME/.local/bin/pyve.sh
- [x] update the README.md to mention the easy usage of the pyve symlink (without the .sh extension)

### Notes
- Implemented `--install` with idempotent operations:
  - Created `$HOME/.local/bin` when missing.
  - Ensured `$HOME/.local/bin` is on PATH by appending an export line to `~/.zprofile` if needed, and sourcing it in the current shell for immediate availability.
  - Copied the running script to `$HOME/.local/bin/pyve.sh` and set executable bit.
  - Created/updated symlink `$HOME/.local/bin/pyve` -> `$HOME/.local/bin/pyve.sh`.
- Nuances:
  - PATH persistence is applied via `~/.zprofile` (Z shell on macOS). If users rely on different startup files, they may need to adjust accordingly.
  - Script path resolution uses `$0` with a fallback to `readlink -f` (or `greadlink -f` if available). If invoked in a way where `$0` is not a file path, the installer will prompt with an ERROR.
  - README updated to document `--install` and examples using the `pyve` symlink.
  - Added a complementary `--uninstall` command that removes `$HOME/.local/bin/pyve` and `$HOME/.local/bin/pyve.sh` without modifying PATH automatically.

## v0.2.4 Requirements [Implemented]
- [x] Change --pythonversion to --python-version
- [x] Remove the -pv parameter abbreviation since it is a non-standard abbreviation
- [x] Change default Python version 3.11.11 to 3.13.7
- [x] If the prescribed --python-version is not installed (by asdf or pyenv), check to see if it is available to install. If so, install it in asdf or pyenv and try again. If not, exit with an error message.
- [x] Add support for setting the --python-version without the --init flag. This will set the Python version in the current directory without creating a virtual environment.

### Notes
- Implemented the requirements for 0.2.4 as follows:
  - Switched to `--python-version` (removed `-pv`) across comments, help, and argument parsing.
  - Added standalone `--python-version <ver>` command to set only the local Python version (no venv/direnv changes).
  - Introduced helpers to detect version manager and auto-install the requested Python version if available (asdf: `asdf install python <ver>`, pyenv: `pyenv install -s <ver>`), preserving the existing asdf shims PATH check.
  - Updated usage text to show the new forms.
  - Bumped `VERSION` to `0.2.4` and `DEFAULT_PYTHON_VERSION` to `3.13.7`.
  - Kept ERROR message style (`ERROR:`) consistent with current codebase.
  - Maintained the requirement for `direnv` in the `--init` flow; not required for standalone `--python-version`.
  - Updated `README.md` examples and version references to reflect these changes.
  - Refactored `init_ready()` into helper functions (`source_shell_profiles`, `check_homebrew_warning`, `detect_version_manager`, `ensure_python_version_installed`, `check_direnv_installed`) to improve readability.

## v0.2.3 [Implemented]
- [x] Initial documented release
