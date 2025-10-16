# Project Context

> **Purpose:** This document establishes the "who, what, why, when, where" before diving into technical "how." It serves as the agreement to "go and build" - the foundation for all technical decisions.

**Last Updated:** YYYY-MM-DD  
**Quality Level:** [experiment | prototype | production | secure]

---

## Problem Statement

**What problem does this project solve?**

[1-3 sentence description of the problem and who experiences it]

**Current situation (without this solution):**

[What happens today? What's the pain/cost?]

**Desired outcome:**

[What does success look like in concrete terms?]

---

## Stakeholders

**Decision Makers:**
- [Name/Role] - [What they approve/control]

**End Users:**
- [Who will use this? How many?]

**Maintainers:**
- [Who will support/maintain long-term?]

**Other Affected Parties:**
- [IT, compliance, customers, etc.]

**Key Contacts:**
- [Primary point of contact for requirements/decisions]

---

## Success Criteria

**How will we measure success?**

**Primary Metrics:**
- [Metric 1: e.g., "80% daily active users within 1 month"]
- [Metric 2: e.g., "Reduce manual work from 3 hours/week to 0"]
- [Metric 3: e.g., "99.9% uptime"]

**Minimum Viable Success (v1.0):**
- [What must work for this to be considered successful?]

**Failure Criteria:**
- [What would make this project a failure?]

**Measurement Plan:**
- [How will we collect/track these metrics?]

---

## Constraints

**Timeline:**
- [Hard deadlines, launch dates, milestones]
- [Flexibility: hard constraint or negotiable?]

**Budget:**
- [Development cost, infrastructure cost, ongoing maintenance]
- [Flexibility: hard constraint or negotiable?]

**Compliance:**
- [HIPAA, GDPR, SOC 2, PCI DSS, industry regulations]
- [Required certifications or audits]

**Technical:**
- [Must integrate with X, must use Y platform, language requirements]
- [Performance requirements, scale requirements]

**Organizational:**
- [Security policies, approval processes, vendor restrictions]
- [SLA requirements, support requirements]

**Deal-Breakers:**
- [Non-negotiable constraints that would kill the project]

---

## Ecosystem

**What existing systems, services, or tools does this project integrate with?**

**External Services:**
- [Third-party APIs, SaaS platforms]
- [Status: API access available? Credentials obtained?]

**Internal Systems:**
- [Existing databases, authentication systems, applications]
- [Integration points and data flow]

**Infrastructure:**
- [Cloud providers, on-premise servers, CI/CD pipelines]
- [Existing infrastructure to leverage]

**Tools & Platforms:**
- [Development tools, monitoring, deployment platforms]
- [Standards/protocols: REST, GraphQL, OAuth, etc.]

**Integration Challenges:**
- [Known limitations, API rate limits, data access issues]

---

## Scope

**What's in scope for v1.0?**

**Must Have (Core Features):**
- [Feature 1]
- [Feature 2]
- [Feature 3]

**Should Have (Important but not critical):**
- [Feature A]
- [Feature B]

**Could Have (Nice-to-haves for future):**
- [Feature X]
- [Feature Y]

**Won't Have (Explicitly out of scope for v1.0):**
- [Feature that stakeholders might expect but we're deferring]
- [Feature that's tempting but would cause scope creep]

**Future Roadmap (post-v1.0):**
- [v2.0 ideas, long-term vision]

---

## Timeline

**Target Milestones:**

- **Project Start:** [Date]
- **Phase 0 Complete:** [Date/Duration]
- **Phase 1 Complete:** [Date/Duration]
- **Beta/Testing:** [Date/Duration]
- **v1.0 Launch:** [Date] - [Hard or soft deadline?]

**Post-Launch:**
- [Maintenance plan, feature releases, support model]

**Schedule Flexibility:**
- [What happens if we slip? Negotiable or fixed?]

---

## Quality Level

**Selected Quality Level:** [experiment | prototype | production | secure]

**Rationale:**

[Why this Quality level? Based on constraints, compliance, scale, timeline]

**Implications:**

**Experiment:**
- Focus: Speed and learning
- Phases: 0-1 only
- Testing: Minimal
- Users: Solo developer or very small team
- Lifespan: Short-lived or exploratory

**Prototype:**
- Focus: Validate approach
- Phases: 0-1, 6-7 as needed
- Testing: Basic
- Users: Small team, limited external users
- Lifespan: May become production

**Production:**
- Focus: Reliability and maintainability
- Phases: 0-7 (core), 8-10 as needed
- Testing: Comprehensive
- Users: Real users depending on uptime
- Lifespan: Long-term support

**Secure:**
- Focus: Compliance and security
- Phases: 0-16 (all)
- Testing: Exhaustive + security testing
- Users: Sensitive data, regulated industry
- Lifespan: Long-term with audit trail

**Quality Gates:**
- [What must be true to maintain this Quality level?]
- [What would trigger an upgrade to higher Quality?]

---

## Open Questions / Deferred Decisions

**Questions to resolve:**
- [Question 1: Who will decide X?]
- [Question 2: How will we handle Y?]

**Deferred to later phases:**
- [Decision 1: Can be decided during Phase 1]
- [Decision 2: Can be decided after MVP validation]

**Risks & Unknowns:**
- [Risk 1: Mitigation plan]
- [Risk 2: Contingency plan]

---

## Changelog

### YYYY-MM-DD: Initial Context
- Created project context document
- Established [Quality level]
- Defined scope and constraints

### YYYY-MM-DD: [Change Description]
- [What changed and why]
- [Impact on timeline, scope, or Quality level]
