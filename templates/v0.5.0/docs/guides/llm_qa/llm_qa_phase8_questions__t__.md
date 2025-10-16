# Phase 8: API Design Questions

## Overview

**Phase:** 8 (API Design)  
**When:** When designing API endpoints  
**Duration:** 15-20 minutes  
**Questions:** 5 total  
**Outcome:** API design and strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is optional and can be skipped for projects without APIs (CLI-only, UI-only with no backend API).

## Topics Covered

- API style (REST, GraphQL, gRPC)
- API versioning strategy
- API documentation
- Rate limiting
- Webhooks and event notifications

## Question Templates

### Question 1: API Style (Required if building an API)

**Context:** API style affects client integration, performance, and flexibility.

```
What API style will you use?

Options:
- **REST**: Resource-based, HTTP verbs, widely adopted
  - Pros: Simple, cacheable, stateless, well-understood
  - Cons: Over-fetching/under-fetching, multiple requests for related data
  - Best for: CRUD operations, public APIs, simple integrations

- **GraphQL**: Query language, client specifies data needs
  - Pros: Single endpoint, flexible queries, no over-fetching
  - Cons: Complexity, caching challenges, learning curve
  - Best for: Complex data relationships, mobile apps, flexible clients

- **gRPC**: Protocol Buffers, high performance, streaming
  - Pros: Fast, type-safe, bidirectional streaming
  - Cons: Not browser-friendly, requires code generation
  - Best for: Microservices, internal APIs, high-performance needs

- **Hybrid**: Combine approaches (e.g., REST + GraphQL)

Example: "REST API for simplicity and wide client support, with JSON responses"

API style: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section), `docs/specs/implementation_options_spec.md` (Protocols & Integration section)

---

### Question 2: API Versioning (Required if building an API)

**Context:** Versioning strategy affects backward compatibility and client migrations.

```
How will you version your API?

Versioning strategies:
- **URL path**: `/v1/users`, `/v2/users`
  - Pros: Clear, easy to route, explicit
  - Cons: URL changes, multiple codebases

- **Header**: `Accept: application/vnd.api+json; version=1`
  - Pros: Clean URLs, content negotiation
  - Cons: Less visible, harder to test

- **Query parameter**: `/users?version=1`
  - Pros: Simple, easy to test
  - Cons: Clutters URLs, easy to forget

- **No versioning**: Breaking changes require client updates
  - Pros: Simplest
  - Cons: Risky, breaks clients

Deprecation policy:
- How long to support old versions? (e.g., 6 months, 1 year)
- How to communicate deprecation? (headers, docs, emails)

Example: "URL path versioning (/v1/, /v2/), support old versions for 1 year, deprecation warnings in response headers"

Versioning: ___________
Deprecation policy: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section)

---

### Question 3: API Documentation (Required if building an API)

**Context:** Good documentation improves developer experience and reduces support burden.

```
How will you document your API?

Documentation approaches:
- **OpenAPI/Swagger**: Standard spec, interactive docs, code generation
  - Tools: Swagger UI, ReDoc, Stoplight
  - Pros: Interactive, standardized, tooling support
  - Cons: Requires maintenance, can be verbose

- **Postman**: Collections with examples
  - Pros: Easy to share, test directly
  - Cons: Not as standardized

- **Markdown**: Simple docs in repo
  - Pros: Version-controlled, simple
  - Cons: No interactivity, manual maintenance

- **GraphQL**: Self-documenting with introspection
  - Pros: Automatic, always up-to-date
  - Cons: GraphQL-specific

Documentation content:
- Endpoints and methods
- Request/response examples
- Authentication requirements
- Error codes and messages
- Rate limits

Example: "OpenAPI 3.0 spec with Swagger UI, include examples for all endpoints, document all error codes"

Documentation: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section)

---

### Question 4: Rate Limiting (Required for production/secure)

**Context:** Rate limiting prevents abuse and ensures fair resource usage.

```
How will you implement API rate limiting?

Rate limit strategies:
- **Per-user**: Limit based on authenticated user (e.g., 1000 requests/hour)
- **Per-IP**: Limit based on IP address (e.g., 100 requests/hour)
- **Per-endpoint**: Different limits for different endpoints
- **Tiered**: Different limits for different user tiers (free, paid, enterprise)

Rate limit headers:
- `X-RateLimit-Limit`: Total allowed requests
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: When limit resets (Unix timestamp)

Burst handling:
- Allow short bursts above limit?
- Token bucket or leaky bucket algorithm?

Example: "Per-user: 1000 requests/hour, per-IP: 100 requests/hour for unauthenticated. Include rate limit headers. Allow 10% burst."

Rate limiting: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section), `docs/specs/security_spec.md` (Rate Limiting section)

---

### Question 5: Webhooks (Optional)

**Context:** Webhooks enable event-driven integrations and real-time notifications.

```
Will you provide webhooks for event notifications?

Webhook considerations:
- **Events**: What events to notify? (user.created, order.completed, etc.)
- **Payload**: What data to include in webhook payload?
- **Security**: How to verify webhook authenticity? (HMAC signatures)
- **Retry logic**: How to handle failed deliveries? (exponential backoff, max retries)
- **Ordering**: Guarantee event order?

Webhook management:
- How do users register webhooks? (API, dashboard)
- How to test webhooks? (test events, webhook.site)
- How to monitor webhook health? (success/failure rates)

Example: "Webhooks for order.created, order.completed, payment.failed. HMAC signature verification. Retry 3 times with exponential backoff. Users register via dashboard."

Webhooks: ___________ (or "none")
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section)

---

## Summary: What Gets Filled Out

After Phase 8 Q&A, the following spec sections should be populated:

### `docs/specs/technical_design_spec.md`
- Interfaces (API style, endpoints, versioning, documentation, rate limiting, webhooks)

### `docs/specs/implementation_options_spec.md`
- Protocols & Integration (API style selection, considerations)

### `docs/specs/security_spec.md`
- Rate Limiting & DDoS Protection (API rate limiting strategy)

## Next Steps

After completing Phase 8 Q&A:

1. **Review API design with developer** - Confirm API approach and strategy
2. **Proceed to other feature-specific phases** (optional):
   - Phase 9: Background Jobs (read `llm_qa_phase9_questions__t__.md`)
   - Phase 10: Analytics & Observability (read `llm_qa_phase10_questions__t__.md`)
3. **Or implement API** - Set up API framework, versioning, documentation, rate limiting

**Note:** Phase 8 is optional and can be skipped for projects without APIs. It can be done at any point when you need to design your API layer.
