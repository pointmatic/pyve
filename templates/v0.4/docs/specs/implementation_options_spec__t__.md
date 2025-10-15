# Implementation Options

<!-- Phase 0: Project Basics -->
## Context and Constraints
- Business goals and success criteria
- Constraints: compliance, deadlines, budget, team skills, legacy systems
- Assumptions and out-of-scope items

<!-- Phase 0: Project Basics -->
## Quality
- Quality Level: experiment | prototype | production | secure
- Guidance (apply based on chosen level):
  - Experiment: speed over rigor; minimal tests; throwaway acceptable.
  - Prototype: validate function/UX; basic error handling; smoke tests.
  - Production: reliability, observability, CI/CD, SLOs, on-call readiness.
  - Secure: threat modeling, hardening, least-privilege, audits/compliance.
- Entry/Exit criteria:
  - Define minimum gates (tests, lint, coverage, reviews, security scans) per level.

## Option Matrix
Evaluate candidates for each domain. Capture tradeoffs and selection rationale.

<!-- Phase 0: Project Basics -->
### Languages & Runtimes
- Candidates: <list>
- Considerations: team proficiency, ecosystem maturity, performance, tooling

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
### Frameworks (web/CLI/worker)
- Candidates: <list>
- Considerations: productivity, flexibility, community, support

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
### Packaging & Distribution
- Candidates: <native binary | wheel | container (Docker/Podman) | zip/tarball>
- Considerations:
  - **Deployment targets:** OS compatibility, architecture (x86_64/arm64)
  - **Size:** Minimal base images (Alpine Linux) vs full-featured (Ubuntu/Debian)
  - **Container runtime:** Docker vs Podman (free and open alternative, daemonless, rootless)
  - **Startup time:** Cold start performance, initialization overhead
  - **Reproducibility:** Lockfiles, pinned base images, build caching

<!-- Phase 1: Core Technical -->
### Data & State
- Candidates: <DBs / caches>
- Considerations: consistency, latency, durability, cost, ops

<!-- Phase 0: Project Basics (deployment decision) | Phase 2: Production Readiness (details) -->
### Infrastructure & Hosting
- Candidates: <Fly.io | AWS | GCP | Azure | Heroku | on-prem | Kubernetes>
- Considerations:
  - **Deployment:** IaC (Terraform/Pulumi/CloudFormation), CLI, web console, git-push
  - **Configuration:** env vars, config files, platform-specific (fly.toml, app.yaml, Dockerfile)
  - **Secrets:** platform secret stores vs external (Vault, 1Password, AWS Secrets Manager)
  - **Scaling:** auto-scaling policies, manual controls, cost implications
  - **Monitoring:** built-in vs external (Datadog, New Relic, Prometheus, Grafana)
  - **Cost:** pricing model, egress fees, commitment discounts, cost predictability
  - **Governance:** compliance, data residency, vendor lock-in risk, multi-region support
  - **Operations:** deployment frequency, rollback ease, debugging tools, platform maturity
  - **Developer experience:** local dev parity, documentation quality, community support

<!-- Phase 2: Production Readiness | Phase 3: Secure/Compliance -->
### Authentication & Security
- Candidates: <protocols/secret mgmt>
- Considerations: complexity, compliance, user experience, risk

<!-- Phase 2: Production Readiness -->
### Observability
- Candidates: <logging/metrics/tracing>
- Considerations: visibility, cost, integration effort

<!-- Phase 1: Core Technical -->
### Protocols & Integration
- Candidates: <HTTP/gRPC/events>
- Considerations: interoperability, latency, versioning, error handling

<!-- Phase 1: Core Technical -->
### Tooling
- Candidates: <dependency managers, linters, formatters, test frameworks>
- Considerations: consistency, automation, local/CI parity

## Candidate Option (Template)
- Summary
- Pros
- Cons
- Risks & Mitigations
- Fit vs constraints
- Estimated effort
- References

## Decision
- Selected option(s) per domain with rationale
- Deferred choices and triggers to revisit

## Impact
- Consequences to code structure, operations, cost, and team processes
