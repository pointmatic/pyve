# Infrastructure Guide

## Purpose
This guide establishes patterns and best practices for infrastructure management across deployment platforms. It complements the architectural decisions in `docs/specs/implementation_options_spec.md` and the as-built documentation in `docs/specs/codebase_spec.md`.

## Scope
- Infrastructure patterns and principles (platform-agnostic)
- Configuration and secrets management
- Deployment strategies and operational practices
- Vendor-specific details belong in `docs/runbooks/` (if needed)

---

## Infrastructure as Code (IaC)

### Principles
- **Declarative over imperative:** Define desired state, not steps to achieve it.
- **Version controlled:** All infrastructure definitions live in the repository.
- **Reproducible:** Same code produces identical infrastructure across environments.
- **Reviewable:** Infrastructure changes go through code review like application code.

### Tool Selection
- **Terraform:** Multi-cloud, mature ecosystem, HCL syntax, state management required.
- **Pulumi:** Multi-cloud, use familiar languages (Python/TypeScript/Go), state management required.
- **CloudFormation:** AWS-only, native integration, JSON/YAML, AWS-managed state.
- **Platform-native:** fly.toml (Fly.io), app.yaml (GCP App Engine), heroku.yml (Heroku).

### Directory Structure
```
infra/
  terraform/          # or pulumi/, cloudformation/
    modules/          # reusable components
    environments/
      dev/
      staging/
      prod/
    main.tf
    variables.tf
    outputs.tf
  fly.toml            # platform-specific config at root or infra/
  Dockerfile          # container definition (or Containerfile for Podman)
  docker-compose.yml  # local dev environment (or podman-compose.yml)
```

### State Management
- **Remote state:** Store Terraform/Pulumi state in S3, GCS, Terraform Cloud, or Pulumi Cloud.
- **State locking:** Prevent concurrent modifications (DynamoDB for Terraform on AWS).
- **State encryption:** Enable encryption at rest for sensitive data.
- **Backup:** Regular backups of state files; test restoration procedures.

---

## Configuration Management

### The Twelve-Factor App
Follow [12factor.net](https://12factor.net) principles:
1. **Codebase:** One codebase tracked in version control, many deploys.
2. **Dependencies:** Explicitly declare and isolate dependencies.
3. **Config:** Store config in the environment (not in code).
4. **Backing services:** Treat backing services as attached resources.
5. **Build, release, run:** Strictly separate build and run stages.
6. **Processes:** Execute the app as one or more stateless processes.
7. **Port binding:** Export services via port binding.
8. **Concurrency:** Scale out via the process model.
9. **Disposability:** Maximize robustness with fast startup and graceful shutdown.
10. **Dev/prod parity:** Keep development, staging, and production as similar as possible.
11. **Logs:** Treat logs as event streams.
12. **Admin processes:** Run admin/management tasks as one-off processes.

### Environment Variables
- **Naming:** Use SCREAMING_SNAKE_CASE (e.g., `DATABASE_URL`, `API_KEY`).
- **Defaults:** Provide sensible defaults for non-sensitive config; fail fast if required vars are missing.
- **Documentation:** List all env vars in `docs/specs/codebase_spec.md` or README.
- **Local development:** Use `.env` files (never commit them; add to `.gitignore`).

### Platform-Specific Configuration
- **Fly.io:** `fly.toml` for app config, `fly secrets` for sensitive data.
- **AWS:** Parameter Store or Secrets Manager; CloudFormation/Terraform for resources.
- **GCP:** Secret Manager; `app.yaml` or Terraform for resources.
- **Azure:** Key Vault; ARM templates or Terraform for resources.
- **Heroku:** Config vars via CLI or dashboard; `heroku.yml` for build config.
- **Kubernetes:** ConfigMaps for config, Secrets for sensitive data; Helm charts or kustomize.
- **Containers:** Dockerfile (Docker) or Containerfile (Podman, a free and open alternative); Alpine Linux with `ash` shell is a minimal base image option.

---

## Secrets Management

### Principles
- **Never commit secrets:** No API keys, passwords, tokens, or certificates in version control.
- **Least privilege:** Grant minimal permissions; rotate credentials regularly.
- **Audit access:** Log who accessed secrets and when.
- **Encrypt at rest and in transit:** Use platform-native encryption or external vaults.

### Strategies

#### Platform Secret Stores (Recommended for simplicity)
- **Fly.io:** `fly secrets set KEY=value`
- **AWS:** Secrets Manager or Parameter Store (SecureString)
- **GCP:** Secret Manager
- **Azure:** Key Vault
- **Heroku:** Config vars (encrypted at rest)
- **Kubernetes:** Secrets (base64-encoded; consider external-secrets operator)

#### External Secret Managers (For multi-cloud or high security)
- **HashiCorp Vault:** Centralized secret storage, dynamic secrets, audit logging.
- **1Password / Bitwarden:** Team password managers with CLI access.
- **AWS Secrets Manager / GCP Secret Manager:** Cloud-native, cross-service integration.

#### Local Development
- **`.env` files:** Use `dotenv` libraries; never commit `.env` to git.
- **Dummy values:** Provide `.env.example` with placeholder values.
- **Shared secrets:** Use a team password manager or encrypted files (e.g., `sops`, `git-crypt`).

### Secret Rotation
- **Automated rotation:** Use platform features (AWS Secrets Manager, GCP Secret Manager).
- **Manual rotation:** Document process in runbooks; set calendar reminders.
- **Zero-downtime rotation:** Support multiple valid credentials during transition.

---

## Deployment Strategies

### Deployment Models

#### 1. **Rolling Update** (Default for most platforms)
- **How:** Replace instances one at a time with new version.
- **Pros:** Simple, no extra infrastructure, gradual rollout.
- **Cons:** Mixed versions during deployment, rollback requires redeployment.
- **Use when:** Low-risk changes, stateless apps, quick rollback acceptable.

#### 2. **Blue-Green Deployment**
- **How:** Run two identical environments (blue=current, green=new); switch traffic atomically.
- **Pros:** Instant rollback, full testing before cutover, zero downtime.
- **Cons:** Double infrastructure cost during deployment, database migrations tricky.
- **Use when:** High-risk changes, need instant rollback, can afford extra resources.

#### 3. **Canary Deployment**
- **How:** Route small percentage of traffic to new version; gradually increase if healthy.
- **Pros:** Early detection of issues, limited blast radius, data-driven rollout.
- **Cons:** Complex routing, requires monitoring/metrics, longer deployment time.
- **Use when:** High-traffic apps, risk-averse, good observability in place.

#### 4. **Feature Flags / Toggles**
- **How:** Deploy code with new features disabled; enable via config without redeployment.
- **Pros:** Decouple deployment from release, A/B testing, instant rollback.
- **Cons:** Code complexity, flag debt accumulation, requires flag management system.
- **Use when:** Frequent deployments, gradual feature rollout, experimentation.

### Health Checks
- **Readiness probe:** Is the app ready to receive traffic? (e.g., `/health/ready`)
- **Liveness probe:** Is the app still running? (e.g., `/health/live`)
- **Startup probe:** Has the app finished initializing? (for slow-starting apps)
- **Implementation:** Return HTTP 200 if healthy, 503 if not; check dependencies (DB, cache).

### Rollback Procedures
- **Automated:** Platform detects failed health checks and reverts (Kubernetes, Fly.io).
- **Manual:** CLI command to revert to previous version (e.g., `fly deploy --image <previous>`).
- **Database migrations:** Use backward-compatible migrations; separate schema changes from code changes.
- **Runbook:** Document rollback steps in `docs/runbooks/<platform>_runbook.md`.

---

## Scaling

### Horizontal Scaling (Scale Out)
- **Add more instances:** Handle more load by running multiple copies of the app.
- **Stateless design:** Apps must not rely on local state (use external cache/DB).
- **Load balancing:** Distribute traffic across instances (platform-provided or external).
- **Auto-scaling:** Scale based on CPU, memory, request rate, or custom metrics.

### Vertical Scaling (Scale Up)
- **Increase resources:** More CPU/memory per instance.
- **Pros:** Simple, no code changes, good for memory-intensive apps.
- **Cons:** Limited by instance size, single point of failure, downtime during resize.

### Auto-Scaling Configuration
- **Metrics:** CPU utilization, memory, request latency, queue depth.
- **Thresholds:** Scale up at 70% CPU, scale down at 30% CPU (avoid flapping).
- **Limits:** Set min/max instances to control cost and availability.
- **Cool-down:** Wait period before scaling again to avoid thrashing.

### Platform-Specific Scaling
- **Fly.io:** `fly scale count <N>` or `fly autoscale` with min/max.
- **AWS:** Auto Scaling Groups, ECS Service auto-scaling, Lambda concurrency.
- **GCP:** Managed Instance Groups, Cloud Run concurrency, App Engine auto-scaling.
- **Azure:** VM Scale Sets, App Service auto-scale rules.
- **Heroku:** `heroku ps:scale web=<N>` or auto-scaling add-on.
- **Kubernetes:** Horizontal Pod Autoscaler (HPA), Vertical Pod Autoscaler (VPA).

---

## Monitoring and Observability

### Three Pillars

#### 1. **Logs** (What happened?)
- **Structured logging:** JSON format with timestamp, level, message, context.
- **Centralized aggregation:** Ship logs to CloudWatch, Stackdriver, Datadog, Grafana Loki.
- **Retention:** Balance cost vs compliance (e.g., 30 days hot, 1 year cold storage).
- **Sensitive data:** Redact secrets, PII; never log passwords or tokens.

#### 2. **Metrics** (How much/how fast?)
- **Key metrics:** Request rate, error rate, latency (RED method); CPU, memory, disk (USE method).
- **Time-series storage:** Prometheus, CloudWatch, Datadog, Grafana Cloud.
- **Dashboards:** Visualize trends, compare environments, share with team.
- **Alerting:** Set thresholds for critical metrics (error rate > 5%, latency > 500ms).

#### 3. **Traces** (Where is time spent?)
- **Distributed tracing:** Track requests across services (Jaeger, Zipkin, AWS X-Ray, Datadog APM).
- **Instrumentation:** Use OpenTelemetry or platform SDKs.
- **Use when:** Microservices, complex request flows, performance debugging.

### Alerting Best Practices
- **Actionable:** Every alert should require human action; reduce noise.
- **Severity levels:** Critical (page on-call), Warning (investigate during business hours), Info (FYI).
- **Runbooks:** Link alerts to runbooks with investigation and mitigation steps.
- **On-call rotation:** Define escalation policy, response time SLAs.

---

## Cost Management

### Cost Optimization Strategies
- **Right-sizing:** Match instance size to actual usage; avoid over-provisioning.
- **Reserved instances:** Commit to 1-3 years for 30-70% discount (AWS, GCP, Azure).
- **Spot/Preemptible instances:** Use for fault-tolerant workloads (70-90% discount).
- **Auto-scaling:** Scale down during low-traffic periods (nights, weekends).
- **Storage tiers:** Move infrequently accessed data to cheaper storage (S3 Glacier, GCS Nearline).
- **Data transfer:** Minimize cross-region/cross-AZ traffic; use CDN for static assets.

### Cost Tracking
- **Tagging:** Tag resources with project, environment, owner for cost allocation.
- **Budgets:** Set budget alerts at 50%, 80%, 100% of monthly limit.
- **Cost dashboards:** Review monthly; identify anomalies and optimization opportunities.
- **Showback/Chargeback:** Allocate costs to teams or projects for accountability.

---

## Disaster Recovery

### Backup Strategy
- **What to back up:** Databases, file storage, configuration, secrets, IaC state.
- **Frequency:** Daily for production data, weekly for less critical, continuous for critical.
- **Retention:** 30 days for operational recovery, longer for compliance.
- **Testing:** Regularly test restoration; document recovery procedures.

### Recovery Objectives
- **RTO (Recovery Time Objective):** How long can the system be down? (e.g., 1 hour)
- **RPO (Recovery Point Objective):** How much data loss is acceptable? (e.g., 15 minutes)
- **Trade-offs:** Lower RTO/RPO = higher cost (replication, standby resources).

### High Availability Patterns
- **Multi-AZ:** Deploy across availability zones for zone failure tolerance.
- **Multi-region:** Deploy across regions for region failure tolerance (higher cost/complexity).
- **Active-passive:** Primary region handles traffic, secondary on standby.
- **Active-active:** Both regions handle traffic, requires data replication and conflict resolution.

---

## Security Best Practices

### Network Security
- **Principle of least privilege:** Only open necessary ports; use security groups/firewalls.
- **Private subnets:** Place databases and internal services in private networks.
- **VPN/Bastion:** Access private resources via VPN or bastion host, not public internet.
- **TLS everywhere:** Encrypt traffic in transit (HTTPS, TLS for DB connections).

### Access Control
- **IAM roles:** Use platform IAM (AWS IAM, GCP IAM, Azure RBAC) instead of API keys.
- **Service accounts:** Dedicated accounts for apps, not personal accounts.
- **MFA:** Require multi-factor authentication for admin access.
- **Audit logging:** Enable CloudTrail, Cloud Audit Logs, or equivalent.

### Compliance
- **Data residency:** Ensure data stays in required regions (GDPR, CCPA).
- **Encryption:** At rest (AES-256) and in transit (TLS 1.2+).
- **Vulnerability scanning:** Regularly scan containers and dependencies (Snyk, Trivy, AWS Inspector).
- **Penetration testing:** Periodic security audits for production systems.

---

## Platform-Specific Guidance

### When to Use Each Platform

#### **Fly.io**
- **Best for:** Small to medium apps, global edge deployment, developer-friendly.
- **Pros:** Simple CLI, fast deployments, built-in global load balancing, affordable.
- **Cons:** Smaller ecosystem, fewer managed services than AWS/GCP.

#### **AWS**
- **Best for:** Enterprise, complex architectures, mature ecosystem, compliance needs.
- **Pros:** Widest service catalog, global reach, strong IAM, extensive documentation.
- **Cons:** Complexity, steep learning curve, cost can spiral without governance.

#### **GCP**
- **Best for:** Data/ML workloads, Kubernetes (GKE), developer experience.
- **Pros:** Strong data/ML services, clean APIs, good Kubernetes support, competitive pricing.
- **Cons:** Smaller market share, fewer third-party integrations than AWS.

#### **Azure**
- **Best for:** Microsoft shops, hybrid cloud, enterprise integration.
- **Pros:** Tight integration with Microsoft ecosystem, strong hybrid cloud, compliance.
- **Cons:** Complex pricing, less developer-friendly than GCP/Fly.io.

#### **Heroku**
- **Best for:** Rapid prototyping, small teams, simple apps.
- **Pros:** Easiest deployment (git push), extensive add-ons, zero-config.
- **Cons:** Expensive at scale, limited customization, vendor lock-in.

#### **Kubernetes (self-managed or managed)**
- **Best for:** Microservices, multi-cloud, portability, complex orchestration.
- **Pros:** Portable, rich ecosystem, fine-grained control, community support.
- **Cons:** Operational complexity, steep learning curve, overkill for simple apps.

---

## Runbooks

For detailed operational procedures (deploy, scale, debug, destroy) on specific platforms, create vendor-specific runbooks:

```
docs/
  runbooks/
    fly_io_runbook.md
    aws_runbook.md
    gcp_runbook.md
    kubernetes_runbook.md
```

Each runbook should include:
- **Setup:** Initial provisioning and configuration.
- **Deploy:** Step-by-step deployment process.
- **Scale:** How to scale up/down manually and configure auto-scaling.
- **Monitor:** Where to find logs, metrics, dashboards.
- **Debug:** Common issues and troubleshooting steps.
- **Rollback:** How to revert to previous version.
- **Secrets:** How to add/update/rotate secrets.
- **Destroy:** How to safely tear down resources.

---

## Checklist: Infrastructure Readiness

Before deploying to production, ensure:

- [ ] Infrastructure defined as code (Terraform/Pulumi/platform config)
- [ ] Secrets stored securely (never in code)
- [ ] Environment variables documented
- [ ] Health check endpoints implemented
- [ ] Deployment strategy chosen and tested
- [ ] Rollback procedure documented and tested
- [ ] Auto-scaling configured (if needed)
- [ ] Monitoring and alerting set up
- [ ] Logs centralized and retained appropriately
- [ ] Backup and disaster recovery plan in place
- [ ] Cost tracking and budget alerts configured
- [ ] Security review completed (network, access, encryption)
- [ ] Runbook created for operational tasks
- [ ] Team trained on deployment and incident response

---

## References

- [The Twelve-Factor App](https://12factor.net)
- [Google SRE Book](https://sre.google/books/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
