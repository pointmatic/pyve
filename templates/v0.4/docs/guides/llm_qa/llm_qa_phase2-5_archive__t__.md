# Phase 2: Production Readiness Questions

## Overview

**Phase:** 2 (Production Readiness)  
**When:** Before deploying to production  
**Duration:** 30-60 minutes  
**Questions:** 20-40 (varies by Quality level)  
**Outcome:** Production-ready specifications

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Infrastructure (hosting, regions, scaling, monitoring, cost)
- Security basics (authentication, secrets, encryption, input validation)
- Operations (deployment, rollback, incident response, logging)

## Question Templates

### Infrastructure (Required for production/secure)

**Context:** Production systems need reliable infrastructure with proper scaling, monitoring, and cost management.

---

**Question 1: Hosting Platform** (production/secure only)
```
Where will you deploy your application?

Options:
- **Fly.io**: Simple, global deployment (good for small-medium apps)
- **AWS**: Full-featured cloud (ECS, Lambda, EC2)
- **GCP**: Google Cloud (Cloud Run, GKE, App Engine)
- **Azure**: Microsoft cloud (App Service, AKS)
- **Heroku**: Simple PaaS (easy but can be expensive)
- **Kubernetes**: Self-managed or managed (GKE, EKS, AKS)
- **On-prem**: Your own servers

Example: "Fly.io for simplicity, with PostgreSQL on Fly and Redis on Upstash"

Hosting platform: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section), `docs/specs/implementation_options_spec.md` (Infrastructure & Hosting section)

---

**Question 2: Regions/Availability** (production/secure only)
```
Where will your application be deployed geographically?

Consider:
- User locations (deploy close to users for low latency)
- Data residency requirements (GDPR, data sovereignty)
- High availability (multiple regions for failover)

Examples:
- "Single region: US East (most users are in US)"
- "Multi-region: US East + EU West (GDPR compliance)"
- "Global: Fly.io auto-scaling across multiple regions"

Regions: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section)

---

**Question 3: Scaling Strategy** (production/secure only)
```
How will your application scale to handle load?

Options:
- **Manual**: You adjust resources as needed
- **Auto-scaling**: Platform automatically adds/removes instances
- **Serverless**: Platform handles all scaling (Lambda, Cloud Run)

Configuration:
- Initial resources (e.g., "2 instances, 1GB RAM each")
- Scaling triggers (e.g., "Scale up at 80% CPU")
- Limits (e.g., "Max 10 instances")

Example: "Start with 2 instances (1GB RAM each), auto-scale up to 5 instances when CPU > 80%"

Scaling: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section), `docs/specs/technical_design_spec.md` (Performance & Scalability section)

---

**Question 4: Monitoring & Alerting** (production/secure only)
```
How will you monitor your application in production?

Monitoring needs:
- **Uptime**: Is the app running?
- **Performance**: Response times, error rates
- **Resources**: CPU, memory, disk usage
- **Logs**: Application and error logs

Tools:
- Built-in: CloudWatch (AWS), Stackdriver (GCP), Fly.io metrics
- Third-party: Datadog, New Relic, Sentry (errors)
- Simple: UptimeRobot (uptime checks)

Alerting:
- Who gets notified? (email, Slack, PagerDuty)
- What triggers alerts? (downtime, high error rate, high CPU)

Example: "Fly.io built-in metrics for CPU/memory, Sentry for error tracking, email alerts for downtime"

Monitoring: ___________
Alerting: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section), `docs/specs/technical_design_spec.md` (Observability section)

---

**Question 5: Cost Management** (production/secure only)
```
What's your budget and how will you track costs?

Consider:
- Initial budget (e.g., "$50/month to start")
- Cost tracking (platform dashboards, alerts)
- Optimization strategies (right-sizing, reserved capacity)

Example: "Budget: $100/month. Use Fly.io dashboard to track costs, set alert at $80. Optimize by scaling down dev instances at night."

Budget: ___________
Cost tracking: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section)

---

**Question 6: Infrastructure as Code** (production/secure only)
```
Will you use Infrastructure as Code (IaC) to manage your infrastructure?

Options:
- **None**: Manual setup via web console/CLI
- **Terraform**: Popular, multi-cloud IaC tool
- **Pulumi**: IaC with real programming languages
- **CloudFormation**: AWS-specific IaC
- **Platform-specific**: fly.toml, app.yaml, docker-compose.yml

Example: "Use fly.toml for Fly.io configuration, store in git repo"

IaC approach: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section), `docs/specs/technical_design_spec.md` (Configuration section)

---

### Security Basics (Required for production/secure)

**Context:** Production systems must protect user data and prevent unauthorized access.

---

**Question 7: Authentication** (production/secure only)
```
How will users authenticate (prove who they are)?

Options:
- **None**: No authentication (public app)
- **Username/password**: Traditional login
- **OAuth**: Login with Google, GitHub, etc.
- **Magic links**: Email-based passwordless login
- **API keys**: For API access
- **Multi-factor**: SMS, authenticator app (secure only)

Example: "OAuth with Google for user login, API keys for programmatic access"

Authentication: ___________
```

**Fills:** `docs/specs/security_spec.md` (Authentication section), `docs/specs/technical_design_spec.md` (Security & Privacy section)

---

**Question 8: Authorization** (production/secure only)
```
How will you control what authenticated users can do?

Options:
- **None**: All users have same permissions
- **Role-based (RBAC)**: Users have roles (admin, user, viewer)
- **Permission-based**: Fine-grained permissions per action
- **Resource-level**: Users own specific resources

Example: "RBAC with three roles: admin (full access), editor (create/edit), viewer (read-only)"

Authorization: ___________
```

**Fills:** `docs/specs/security_spec.md` (Authorization section)

---

**Question 9: Secrets Management** (production/secure only)
```
How will you manage sensitive data (API keys, database passwords, etc.)?

Options:
- **Environment variables**: Set in platform (Fly.io secrets, Heroku config vars)
- **Secret manager**: AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault
- **.env files**: For local development only (never commit to git!)

Best practices:
- Never commit secrets to git
- Rotate secrets regularly (especially for secure Quality)
- Use different secrets for dev/staging/prod

Example: "Fly.io secrets for production, .env files for local dev (gitignored)"

Secrets management: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Security section), `docs/specs/technical_design_spec.md` (Configuration section)

---

**Question 10: Data Encryption** (production/secure only)
```
How will you protect sensitive data?

Encryption needs:
- **In transit**: HTTPS/TLS for all connections (required for production)
- **At rest**: Encrypt database and file storage (secure only)
- **Application-level**: Encrypt sensitive fields (passwords, SSNs, etc.)

Example: "HTTPS for all traffic (Fly.io provides TLS), PostgreSQL encryption at rest, bcrypt for password hashing"

Encryption: ___________
```

**Fills:** `docs/specs/security_spec.md` (Data Protection section)

---

**Question 11: Input Validation** (production/secure only)
```
How will you prevent malicious input (SQL injection, XSS, etc.)?

Strategies:
- **Framework protection**: Use framework's built-in validation (FastAPI, Django)
- **Input sanitization**: Clean user input before processing
- **Parameterized queries**: Prevent SQL injection
- **Output encoding**: Prevent XSS attacks
- **Rate limiting**: Prevent abuse

Example: "Pydantic for input validation, SQLAlchemy parameterized queries, rate limiting with slowapi"

Input validation: ___________
```

**Fills:** `docs/specs/security_spec.md` (Input Validation section)

---

**Question 12: Security Audits** (secure only)
```
How will you audit and maintain security?

For secure Quality:
- **Dependency scanning**: Check for vulnerable packages (pip-audit, Snyk)
- **Code scanning**: Static analysis (Bandit for Python, SonarQube)
- **Penetration testing**: Hire security experts to test your app
- **Compliance audits**: GDPR, HIPAA, SOC 2 audits

Example: "Run pip-audit weekly in CI, annual penetration test, quarterly compliance review"

Security audits: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Security section), `docs/specs/security_spec.md` (Audits section)

---

### Operations (Required for production/secure)

**Context:** Production systems need reliable deployment, rollback, and incident response procedures.

---

**Question 13: Deployment Process** (production/secure only)
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

**Question 14: Health Checks** (production/secure only)
```
How will you verify your application is healthy?

Health check types:
- **Liveness**: Is the app running? (e.g., GET /health returns 200)
- **Readiness**: Is the app ready to serve traffic? (e.g., database connected)
- **Startup**: Has the app finished starting up?

Example: "GET /health endpoint checks database connection, returns 200 if healthy"

Health checks: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Rollout & Migration section)

---

**Question 15: Rollback Strategy** (production/secure only)
```
What will you do if a deployment goes wrong?

Rollback options:
- **Previous version**: Redeploy last known good version
- **Feature flags**: Disable new features without redeploying
- **Database migrations**: Ensure migrations are reversible

Example: "Keep last 3 deployments available, can rollback via Fly.io CLI in under 2 minutes. Feature flags for major changes."

Rollback strategy: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Rollout & Migration section)

---

**Question 16: Logging** (production/secure only)
```
How will you log application events and errors?

Logging needs:
- **Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Structured logs**: JSON format for easy parsing
- **Log aggregation**: Centralized log storage (CloudWatch, Datadog, Papertrail)
- **Retention**: How long to keep logs (7 days, 30 days, 1 year)

Example: "Structured JSON logs, INFO level in production, sent to Fly.io logs, 30-day retention"

Logging: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Observability section), `docs/specs/technical_design_spec.md` (Observability section)

---

**Question 17: Incident Response** (production/secure only)
```
What will you do when something breaks in production?

Incident response plan:
- **Detection**: How do you know something is wrong? (monitoring, alerts, user reports)
- **Communication**: Who gets notified? (on-call rotation, Slack channel)
- **Escalation**: When to escalate? (severity levels, escalation path)
- **Postmortem**: Document what happened and how to prevent it

Example: "Alerts go to #incidents Slack channel, on-call engineer responds within 15 minutes, postmortem for all P0/P1 incidents"

Incident response: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Error Handling & Resilience section)

---

**Question 18: Backup & Recovery** (production/secure only)
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

**Question 19: Configuration Management** (production/secure only)
```
How will you manage configuration across environments (dev, staging, prod)?

Configuration needs:
- **Environment variables**: Different values per environment
- **Feature flags**: Enable/disable features per environment
- **Secrets**: Different secrets per environment

Example: "Environment variables for all config (DATABASE_URL, API_KEYS), stored in Fly.io secrets for prod, .env for dev"

Configuration: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Configuration section), `docs/specs/technical_design_spec.md` (Configuration section)

---

**Question 20: Performance Monitoring** (production/secure only)
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

## Example Q&A Session: Production-Level Web API

**LLM:** You've completed Phase 1 (core technical). Now let's prepare for production deployment with Phase 2. This should take about 30-40 minutes. Ready?

**Developer:** Yes, let's do it.

---

**LLM:** Where will you deploy your application?

**Developer:** I'm thinking Fly.io for simplicity. We'll use their PostgreSQL and maybe add Redis later.

---

**LLM:** What regions will you deploy to? Consider where your users are located.

**Developer:** Most of our users are in the US, so let's start with US East. We might add EU later if we get European customers.

---

**LLM:** How will your application scale to handle load?

**Developer:** Start with 2 instances with 1GB RAM each. Auto-scale up to 5 instances if CPU goes above 80%.

---

**LLM:** How will you monitor your application and get alerted to issues?

**Developer:** Use Fly.io's built-in metrics for CPU and memory. Add Sentry for error tracking. Send email alerts if the app goes down or error rate spikes.

---

**LLM:** What's your budget and how will you track costs?

**Developer:** Budget is $150/month to start. I'll use Fly.io's dashboard to track costs and set an alert at $120.

---

**LLM:** Will you use Infrastructure as Code?

**Developer:** Yes, we'll use fly.toml to define our Fly.io configuration and store it in the git repo.

---

**LLM:** How will users authenticate?

**Developer:** OAuth with Google for user login. We'll also support API keys for programmatic access.

---

**LLM:** How will you control what authenticated users can do?

**Developer:** Role-based access control with three roles: admin (full access), editor (can create and edit content), and viewer (read-only).

---

**LLM:** How will you manage secrets like API keys and database passwords?

**Developer:** Use Fly.io secrets for production, .env files for local development (gitignored).

---

**LLM:** How will you protect sensitive data?

**Developer:** HTTPS for all traffic (Fly.io provides TLS automatically), PostgreSQL encryption at rest, bcrypt for password hashing.

---

**LLM:** How will you prevent malicious input?

**Developer:** Pydantic for input validation in FastAPI, SQLAlchemy parameterized queries to prevent SQL injection, rate limiting with slowapi.

---

**LLM:** How will you deploy updates to production?

**Developer:** GitHub Actions will deploy to staging automatically on merge to main. Then manual promotion to production after we test on staging.

---

**LLM:** How will you verify your application is healthy?

**Developer:** A GET /health endpoint that checks the database connection and returns 200 if everything is working.

---

**LLM:** What's your rollback strategy if a deployment goes wrong?

**Developer:** Keep the last 3 deployments available. We can rollback via Fly.io CLI in under 2 minutes. Use feature flags for major changes.

---

**LLM:** How will you log application events and errors?

**Developer:** Structured JSON logs at INFO level in production, sent to Fly.io logs with 30-day retention.

---

**LLM:** What's your incident response plan?

**Developer:** Alerts go to our #incidents Slack channel. On-call engineer responds within 30 minutes. Write a postmortem for any major incidents.

---

**LLM:** How will you backup data and recover from disasters?

**Developer:** Daily PostgreSQL backups via Fly.io, keep for 30 days. Target: restore service within 2 hours, accept up to 24 hours of data loss. Test restores monthly.

---

**LLM:** How will you manage configuration across environments?

**Developer:** Environment variables for all config (DATABASE_URL, API_KEYS, etc.). Store in Fly.io secrets for prod, .env files for dev.

---

**LLM:** How will you track application performance?

**Developer:** Use Fly.io metrics for basic monitoring. Track p95 response time (target < 200ms) and error rate (target < 1%).

---

**LLM:** Perfect! Here's what I understand:

**Infrastructure:**
- Platform: Fly.io (PostgreSQL + app hosting)
- Regions: US East (single region to start)
- Scaling: 2 instances (1GB RAM), auto-scale to 5 at 80% CPU
- Monitoring: Fly.io metrics + Sentry for errors, email alerts
- Budget: $150/month, alert at $120
- IaC: fly.toml in git repo

**Security:**
- Authentication: OAuth (Google) + API keys
- Authorization: RBAC (admin, editor, viewer)
- Secrets: Fly.io secrets (prod), .env (dev, gitignored)
- Encryption: HTTPS/TLS, PostgreSQL at rest, bcrypt passwords
- Input validation: Pydantic + SQLAlchemy + rate limiting

**Operations:**
- Deployment: GitHub Actions → staging (auto), staging → prod (manual)
- Health checks: GET /health (checks database)
- Rollback: Keep last 3 deployments, <2 min rollback time, feature flags
- Logging: Structured JSON, INFO level, Fly.io logs, 30-day retention
- Incidents: #incidents Slack, 30-min response, postmortems
- Backup: Daily PostgreSQL, 30-day retention, RTO 2hr/RPO 24hr, monthly tests
- Config: Environment variables (Fly.io secrets for prod)
- Performance: Fly.io metrics, p95 < 200ms, error rate < 1%

Does this look correct?

**Developer:** Yes, that's exactly right.

---

**LLM:** Excellent! I've filled out the Phase 2 specifications in:
- `docs/specs/codebase_spec.md` (Infrastructure, Security, Configuration, Observability, CI/CD)
- `docs/specs/technical_design_spec.md` (Configuration, Error Handling, Performance, Security, Observability, Rollout)
- `docs/specs/security_spec.md` (Authentication, Authorization, Data Protection, Input Validation)
- `docs/specs/implementation_options_spec.md` (Infrastructure & Hosting)

You're ready to deploy to production!

Would you like me to:
1. Start implementing the production deployment (set up Fly.io, CI/CD, monitoring)
2. Review the specs in detail first
3. Ask about compliance and advanced security (Phase 3 - for secure Quality only)

**Developer:** Let's start implementing the production deployment.

---

## Summary: What Gets Filled Out

After Phase 2 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- Infrastructure (provider, regions, IaC, scaling, monitoring, cost, backup, access control)
- Security (secrets, permissions, supply chain, audits)
- Configuration (mechanisms, key variables)
- Observability (logging, metrics, tracing)
- CI/CD (enhanced with deployment process)

### `docs/specs/technical_design_spec.md`
- Configuration (env vars, secrets, IaC, platform config, environment parity)
- Error Handling & Resilience (failure modes, timeouts, retries, idempotency, fallback)
- Performance & Scalability (enhanced with production targets)
- Security & Privacy (threat model, permissions, data protection)
- Observability (logging, metrics, tracing, reporting)
- Rollout & Migration (deployment mechanism, health checks, monitoring, zero-downtime)

### `docs/specs/security_spec.md`
- Authentication (methods, flows, MFA)
- Authorization (RBAC, permissions, resource-level)
- Data Protection (encryption at rest/transit, data minimization)
- Input Validation (SQL injection, XSS, CSRF prevention)
- Secrets Management (development and production)
- Rate Limiting (patterns and implementation)
- Monitoring & Logging (security events, audit logs)
- Incident Response (procedures and escalation)

### `docs/specs/implementation_options_spec.md`
- Infrastructure & Hosting (enhanced with detailed considerations)

## Next Steps

After completing Phase 2 Q&A:

1. **Review specs with developer** - Confirm production readiness approach
2. **Implement production deployment** - Set up infrastructure, CI/CD, monitoring
3. **If secure Quality** - Conduct Phase 3 Q&A (read `llm_qa_phase3_questions__t__.md`)
4. **Otherwise** - Begin production deployment and operations
