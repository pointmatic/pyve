# Implementation Options

## Context and Constraints
- Business goals and success criteria
- Constraints: compliance, deadlines, budget, team skills, legacy systems
- Assumptions and out-of-scope items

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

### Languages & Runtimes
- Candidates: <list>
- Considerations: team proficiency, ecosystem maturity, performance, tooling

### Frameworks (web/CLI/worker)
- Candidates: <list>
- Considerations: productivity, flexibility, community, support

### Packaging & Distribution
- Candidates: <list>
- Considerations: deployment targets, size, startup, reproducibility

### Data & State
- Candidates: <DBs / caches>
- Considerations: consistency, latency, durability, cost, ops

### Infrastructure & Hosting
- Candidates: <cloud/platform/orchestration>
- Considerations: scalability, cost, governance, platform fit

### Authentication & Security
- Candidates: <protocols/secret mgmt>
- Considerations: complexity, compliance, user experience, risk

### Observability
- Candidates: <logging/metrics/tracing>
- Considerations: visibility, cost, integration effort

### Protocols & Integration
- Candidates: <HTTP/gRPC/events>
- Considerations: interoperability, latency, versioning, error handling

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
