# Phase 5: Operations Questions

## Overview

**Phase:** 5 (Operations)  
**When:** Before deploying to production  
**Duration:** 20-25 minutes  
**Questions:** 8 total  
**Outcome:** Operational procedures and processes defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Deployment process and automation
- Health checks and readiness probes
- Rollback strategy
- Logging and log management
- Incident response procedures
- Backup and recovery
- Configuration management
- Performance monitoring

## Question Templates

### Question 1: Deployment Process (Required for production/secure)

**Context:** Reliable deployment processes reduce downtime and errors.

```
How will you deploy updates to production?

Options:
- **Manual**: Run commands manually (risky for production)
- **CI/CD**: Automated deployment on git push (recommended)
- **Blue-green**: Deploy to new environment, switch traffic
- **Canary**: Deploy to small percentage of users first
- **Rolling**: Gradually update instances

Example: "GitHub Actions deploys to staging on merge to main, manual promotion to production after testing"

Deployment process: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (CI/CD section), `docs/specs/technical_design_spec.md` (Rollout & Migration section)

---

### Question 2: Health Checks (Required for production/secure)

**Context:** Health checks ensure traffic only goes to healthy instances.

```
How will you verify your application is healthy?

Health check types:
- **Liveness**: Is the app running? (e.g., GET /health returns 200)
- **Readiness**: Is the app ready to serve traffic? (e.g., database connected)
- **Startup**: Has the app finished starting up?

Example: "GET /health endpoint checks database connection, returns 200 if healthy, 503 if not ready"

Health checks: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Rollout & Migration section)

---

### Question 3: Rollback Strategy (Required for production/secure)

**Context:** Quick rollback minimizes impact of bad deployments.

```
What will you do if a deployment goes wrong?

Rollback options:
- **Previous version**: Redeploy last known good version
- **Feature flags**: Disable new features without redeploying
- **Database migrations**: Ensure migrations are reversible
- **Rollback time**: Target time to rollback (e.g., under 5 minutes)

Example: "Keep last 3 deployments available, can rollback via Fly.io CLI in under 2 minutes. Feature flags for major changes."

Rollback strategy: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Rollout & Migration section)

---

### Question 4: Logging (Required for production/secure)

**Context:** Proper logging enables debugging and troubleshooting.

```
How will you log application events and errors?

Logging needs:
- **Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Format**: Structured logs (JSON) for easy parsing
- **Log aggregation**: Centralized log storage (CloudWatch, Datadog, Papertrail)
- **Retention**: How long to keep logs (7 days, 30 days, 1 year)

Example: "Structured JSON logs, INFO level in production, sent to Fly.io logs, 30-day retention"

Logging: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Observability section), `docs/specs/technical_design_spec.md` (Observability section)

---

### Question 5: Incident Response (Required for production/secure)

**Context:** Clear incident response procedures minimize downtime and confusion.

```
What will you do when something breaks in production?

Incident response plan:
- **Detection**: How do you know something is wrong? (monitoring, alerts, user reports)
- **Communication**: Who gets notified? (on-call rotation, Slack channel)
- **Response time**: Target response time (e.g., 15 minutes)
- **Escalation**: When to escalate? (severity levels, escalation path)
- **Postmortem**: Document what happened and how to prevent it

Example: "Alerts go to #incidents Slack channel, on-call engineer responds within 15 minutes, postmortem for all P0/P1 incidents"

Incident response: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Error Handling & Resilience section)

---

### Question 6: Backup & Recovery (Required for production/secure)

**Context:** Backups protect against data loss and enable disaster recovery.

```
How will you backup data and recover from disasters?

Backup strategy:
- **What**: Database, file storage, configuration
- **Frequency**: Hourly, daily, weekly
- **Retention**: How long to keep backups (7 days, 30 days, 1 year)
- **Testing**: Regularly test restoring from backups

Recovery targets:
- **RTO** (Recovery Time Objective): How long to restore service? (e.g., 4 hours)
- **RPO** (Recovery Point Objective): How much data loss is acceptable? (e.g., 1 hour)

Example: "Daily PostgreSQL backups via Fly.io, 30-day retention. RTO: 2 hours, RPO: 24 hours. Test restore monthly."

Backup: ___________
Recovery: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section)

---

### Question 7: Configuration Management (Required for production/secure)

**Context:** Proper configuration management prevents environment-specific bugs.

```
How will you manage configuration across environments (dev, staging, prod)?

Configuration needs:
- **Environment variables**: Different values per environment
- **Feature flags**: Enable/disable features per environment
- **Secrets**: Different secrets per environment (see Phase 4)

Example: "Environment variables for all config (DATABASE_URL, API_KEYS), stored in Fly.io secrets for prod, .env for dev"

Configuration: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Configuration section), `docs/specs/technical_design_spec.md` (Configuration section)

---

### Question 8: Performance Monitoring (Required for production/secure)

**Context:** Performance monitoring helps identify bottlenecks and degradation.

```
How will you track application performance?

Metrics to track:
- **Response time**: How fast are requests? (p50, p95, p99)
- **Error rate**: What percentage of requests fail?
- **Throughput**: How many requests per second?
- **Database queries**: Slow query detection

Tools:
- Built-in: Platform metrics (Fly.io, AWS CloudWatch)
- APM: Application Performance Monitoring (New Relic, Datadog)
- Custom: Prometheus + Grafana

Example: "Fly.io metrics for basic monitoring, track p95 response time < 200ms, error rate < 1%"

Performance monitoring: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Performance & Scalability section), `docs/specs/technical_design_spec.md` (Observability section)

---

## Summary: What Gets Filled Out

After Phase 5 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- CI/CD (deployment process, pipelines)
- Configuration (environment variables, feature flags)
- Infrastructure (backup and recovery)
- Observability (logging, metrics)

### `docs/specs/technical_design_spec.md`
- Configuration (environment management)
- Error Handling & Resilience (incident response)
- Performance & Scalability (performance monitoring)
- Observability (logging, metrics, tracing)
- Rollout & Migration (deployment mechanism, health checks, rollback, monitoring during rollout)

## Next Steps

After completing Phase 5 Q&A:

1. **Review operational specs with developer** - Confirm operational procedures
2. **Proceed to feature-specific phases** (optional):
   - Phase 6: Data & Persistence (read `llm_qa_phase6_questions__t__.md`)
   - Phase 7: User Interface (read `llm_qa_phase7_questions__t__.md`)
   - Phase 8: API Design (read `llm_qa_phase8_questions__t__.md`)
   - Phase 9: Background Jobs (read `llm_qa_phase9_questions__t__.md`)
   - Phase 10: Analytics & Observability (read `llm_qa_phase10_questions__t__.md`)
3. **Or implement operations** - Set up CI/CD, health checks, logging, monitoring, backups

**Note:** Phases 2-5 cover production readiness fundamentals. Phases 6-10 are feature-specific and can be done as needed. Phases 11-16 are for secure Quality level only.
