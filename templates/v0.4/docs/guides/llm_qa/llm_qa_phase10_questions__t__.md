# Phase 10: Analytics & Observability Questions

## Overview

**Phase:** 10 (Analytics & Observability)  
**When:** When adding analytics and advanced observability  
**Duration:** 15-20 minutes  
**Questions:** 5 total  
**Outcome:** Analytics and observability strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is optional and builds on basic monitoring from Phase 2 (Infrastructure) and Phase 5 (Operations). Use this when you need business analytics or advanced observability.

## Topics Covered

- Business analytics (metrics, dashboards, reporting)
- Application metrics (custom metrics, instrumentation)
- Distributed tracing
- Alerting strategy
- Dashboard design

## Question Templates

### Question 1: Business Analytics (Optional, recommended for production)

**Context:** Business analytics help you understand user behavior and product performance.

```
What business metrics do you need to track?

Business metrics categories:
- **User metrics**: Active users (DAU, MAU), new signups, churn rate
- **Engagement metrics**: Session duration, feature usage, retention
- **Revenue metrics**: MRR, ARR, conversion rate, LTV, CAC
- **Product metrics**: Feature adoption, funnel conversion, A/B test results
- **Performance metrics**: Page load time, API response time, error rates

Analytics tools:
- **Product analytics**: Mixpanel, Amplitude, PostHog, Heap
- **Web analytics**: Google Analytics, Plausible, Fathom
- **Custom**: Build your own with database queries
- **Business intelligence**: Metabase, Looker, Tableau

Example: "Track DAU/MAU, feature usage, conversion funnel. Use Mixpanel for product analytics, custom dashboards for business metrics."

Business analytics: ___________ (or "none")
```

**Fills:** `docs/specs/technical_design_spec.md` (Observability section)

---

### Question 2: Application Metrics (Required for production/secure)

**Context:** Application metrics help you understand system behavior and performance.

```
What application metrics will you instrument?

Application metrics:
- **Request metrics**: Request count, response time (p50, p95, p99), error rate
- **Database metrics**: Query count, query duration, connection pool usage
- **Cache metrics**: Hit rate, miss rate, eviction rate
- **Business events**: Orders placed, payments processed, emails sent
- **Custom metrics**: Application-specific metrics

Instrumentation approach:
- **Framework built-in**: FastAPI metrics, Django Debug Toolbar
- **APM tools**: New Relic, Datadog APM, Dynatrace
- **Prometheus**: Open-source metrics collection
- **StatsD**: Simple metrics aggregation
- **OpenTelemetry**: Vendor-neutral observability framework

Example: "Instrument request metrics (response time, error rate), database query duration, cache hit rate. Use Prometheus + Grafana for visualization."

Application metrics: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Observability section), `docs/specs/codebase_spec.md` (Observability section)

---

### Question 3: Distributed Tracing (Optional, recommended for microservices)

**Context:** Distributed tracing helps debug complex, multi-service requests.

```
Will you implement distributed tracing?

Tracing use cases:
- **Microservices**: Track requests across multiple services
- **Performance debugging**: Identify slow operations
- **Dependency mapping**: Visualize service dependencies
- **Error debugging**: Trace errors to root cause

Tracing tools:
- **Jaeger**: Open-source, CNCF project
- **Zipkin**: Open-source, Twitter origin
- **Datadog APM**: Commercial, full-featured
- **New Relic**: Commercial, easy to use
- **AWS X-Ray**: AWS-native tracing
- **OpenTelemetry**: Vendor-neutral standard

Tracing strategy:
- **Sample rate**: Trace all requests or sample? (e.g., 10% sampling)
- **Span attributes**: What metadata to include?
- **Retention**: How long to keep traces? (e.g., 7 days)

Example: "Use Jaeger for distributed tracing, 10% sampling rate, 7-day retention. Trace across API, database, and external services."

Distributed tracing: ___________ (or "none")
```

**Fills:** `docs/specs/technical_design_spec.md` (Observability section)

---

### Question 4: Alerting Strategy (Required for production/secure)

**Context:** Effective alerting ensures you know about problems before users do.

```
What is your alerting strategy?

Alert categories:
- **Critical (P0)**: Service down, data loss, security breach
  - Response: Immediate (wake up on-call)
  - Notification: PagerDuty, phone call
  
- **High (P1)**: Degraded performance, high error rate
  - Response: Within 1 hour
  - Notification: Slack, email
  
- **Medium (P2)**: Warning thresholds, resource usage
  - Response: Within 4 hours
  - Notification: Slack
  
- **Low (P3)**: Informational, trends
  - Response: Review during business hours
  - Notification: Email digest

Alert rules:
- Error rate > 5% for 5 minutes → P1
- Response time p95 > 1 second for 10 minutes → P2
- Disk usage > 80% → P2
- Service down → P0

Notification channels:
- **PagerDuty**: On-call rotation, escalation
- **Slack**: Team notifications
- **Email**: Non-urgent alerts
- **Webhook**: Custom integrations

Example: "P0: PagerDuty with phone call. P1/P2: Slack #alerts channel. Alert on error rate > 5%, response time > 1s, service down."

Alerting strategy: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Observability section)

---

### Question 5: Dashboard Design (Required for production/secure)

**Context:** Well-designed dashboards provide at-a-glance system health visibility.

```
What dashboards will you create?

Dashboard types:
- **Service health**: Uptime, error rate, response time
- **Infrastructure**: CPU, memory, disk, network
- **Business metrics**: Revenue, users, conversions
- **Application metrics**: Request rate, database queries, cache hit rate
- **On-call**: Critical metrics for incident response

Dashboard tools:
- **Grafana**: Open-source, flexible, Prometheus integration
- **Datadog**: Commercial, all-in-one
- **CloudWatch**: AWS-native dashboards
- **Custom**: Build with Recharts, Chart.js, D3.js

Key metrics per dashboard:
- **Service health**: Error rate, p95 response time, request rate, uptime
- **Infrastructure**: CPU %, memory %, disk %, network I/O
- **Business**: DAU, revenue, conversion rate, churn

Visualization best practices:
- Use appropriate chart types (line for time series, bar for comparisons)
- Include thresholds and SLOs
- Keep dashboards focused (one purpose per dashboard)
- Update in real-time or near real-time

Example: "Grafana dashboards: Service Health (error rate, response time, uptime), Infrastructure (CPU, memory, disk), Business (DAU, revenue). Update every 30 seconds."

Dashboard design: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Observability section)

---

## Summary: What Gets Filled Out

After Phase 10 Q&A, the following spec sections should be populated:

### `docs/specs/technical_design_spec.md`
- Observability (business analytics, application metrics, distributed tracing, alerting strategy, dashboard design)

### `docs/specs/codebase_spec.md`
- Observability (metrics instrumentation, monitoring tools)

## Next Steps

After completing Phase 10 Q&A:

1. **Review analytics and observability strategy with developer** - Confirm approach and tools
2. **For secure Quality, proceed to secure/compliance phases**:
   - Phase 11: Threat Modeling (read `llm_qa_phase11_questions__t__.md`)
   - Phase 12: Compliance Requirements (read `llm_qa_phase12_questions__t__.md`)
   - Phase 13: Advanced Security (read `llm_qa_phase13_questions__t__.md`)
   - Phase 14: Audit Logging (read `llm_qa_phase14_questions__t__.md`)
   - Phase 15: Incident Response (read `llm_qa_phase15_questions__t__.md`)
   - Phase 16: Security Governance (read `llm_qa_phase16_questions__t__.md`)
3. **Or implement analytics and observability** - Set up metrics, tracing, alerts, dashboards

**Note:** Phase 10 is optional and builds on basic monitoring from earlier phases. It's recommended for production applications that need business insights or advanced debugging capabilities.
