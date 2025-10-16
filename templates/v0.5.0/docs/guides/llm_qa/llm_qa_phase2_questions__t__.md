# Phase 2: Infrastructure Questions

## Overview

**Phase:** 2 (Infrastructure)  
**When:** Before deploying to production  
**Duration:** 15-20 minutes  
**Questions:** 6 total  
**Outcome:** Infrastructure foundation for production deployment

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Hosting platform selection
- Regional deployment and availability
- Scaling strategy
- Monitoring and alerting
- Cost management
- Infrastructure as Code

## Question Templates

### Question 1: Hosting Platform (Required for production/secure)

**Context:** Choosing the right hosting platform impacts cost, complexity, and operational overhead.

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

### Question 2: Regions/Availability (Required for production/secure)

**Context:** Regional deployment affects latency, compliance, and availability.

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

### Question 3: Scaling Strategy (Required for production/secure)

**Context:** Proper scaling ensures your application handles load efficiently and cost-effectively.

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

### Question 4: Monitoring & Alerting (Required for production/secure)

**Context:** Monitoring helps you detect and respond to issues before they impact users.

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

### Question 5: Cost Management (Required for production/secure)

**Context:** Understanding and controlling costs prevents budget surprises.

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

### Question 6: Infrastructure as Code (Required for production/secure)

**Context:** IaC makes infrastructure reproducible and version-controlled.

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

## Summary: What Gets Filled Out

After Phase 2 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- Infrastructure (provider, regions, scaling, monitoring, cost, IaC)

### `docs/specs/technical_design_spec.md`
- Performance & Scalability (scaling strategies)
- Observability (monitoring, alerting)
- Configuration (IaC approach)

### `docs/specs/implementation_options_spec.md`
- Infrastructure & Hosting (platform selection, considerations)

## Next Steps

After completing Phase 2 Q&A:

1. **Review infrastructure specs with developer** - Confirm platform and approach
2. **Proceed to Phase 3** - Authentication & Authorization (read `llm_qa_phase3_questions__t__.md`)
3. **Or implement infrastructure** - Set up hosting, monitoring, IaC

**Note:** Phase 2 focuses on infrastructure foundation. Security, operations, and feature-specific concerns are covered in subsequent phases.
