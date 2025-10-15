# Phase 15: Incident Response Questions

## Overview

**Phase:** 15 (Incident Response)  
**When:** For secure Quality level  
**Duration:** 15-20 minutes  
**Questions:** 4 total  
**Outcome:** Formal incident response procedures defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is required only for secure Quality level. It's the fifth of six secure/compliance phases (11-16). This builds on basic incident response from Phase 5 (Operations).

## Topics Covered

- Incident response team (roles, on-call, escalation)
- Incident classification (severity levels, response times)
- IR procedures (detection, containment, investigation, eradication, recovery, postmortem)
- Breach notification (internal, users, regulatory, public)

## Question Templates

### Question 1: Incident Response Team (Required for secure)

**Context:** A well-defined IR team ensures rapid and coordinated incident response.

```
Who is on your incident response team?

IR team roles:

**Incident Commander:**
- Overall responsibility for incident response
- Coordinates team activities
- Makes critical decisions
- Communicates with stakeholders
- Typically: Engineering manager, CTO, or security lead

**Technical Lead:**
- Leads technical investigation
- Coordinates remediation efforts
- Works with engineers to implement fixes
- Typically: Senior engineer or security engineer

**Communications Lead:**
- Internal communications (team updates)
- External communications (customer notifications)
- Regulatory notifications (if required)
- Public relations (if needed)
- Typically: Product manager, customer success, or legal

**Security Analyst:**
- Analyzes security events
- Investigates root cause
- Documents findings
- Typically: Security team member or external consultant

**Legal/Compliance:**
- Advises on legal obligations
- Handles regulatory notifications
- Manages liability concerns
- Typically: Legal counsel or compliance officer

On-call rotation:
- **Primary on-call**: First responder (24/7 coverage)
- **Secondary on-call**: Backup if primary unavailable
- **Escalation**: Who to escalate to for critical incidents
- **Rotation schedule**: Weekly, bi-weekly, or monthly

Escalation path:
- **Level 1**: On-call engineer (P2-P3 incidents)
- **Level 2**: Technical lead + Incident Commander (P1 incidents)
- **Level 3**: CTO + Legal (P0 incidents, data breaches)
- **Level 4**: CEO + Board (major breaches, regulatory issues)

Example:
"Incident Commander: VP Engineering (Jane Doe)
Technical Lead: Senior Security Engineer (John Smith)
Communications Lead: Head of Customer Success (Alice Johnson)
Security Analyst: External consultant (Acme Security)
Legal: General Counsel (Bob Williams)

On-call: Weekly rotation, primary + secondary coverage 24/7
Escalation: L1 (on-call) → L2 (tech lead + IC) → L3 (CTO + legal) → L4 (CEO)
Contact: PagerDuty for alerting, Slack #incidents for coordination"

IR team: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section)

---

### Question 2: Incident Classification (Required for secure)

**Context:** Clear severity levels ensure appropriate response times and resources.

```
How will you classify incident severity?

Severity levels:

**P0 (Critical):**
- **Impact**: Complete service outage, data breach, security compromise
- **Examples**: Database breach, ransomware, complete system down
- **Response time**: Immediate (wake up on-call)
- **Notification**: PagerDuty phone call, Slack @channel
- **Escalation**: Immediate to Level 3 (CTO + Legal)
- **Communication**: Hourly updates to stakeholders

**P1 (High):**
- **Impact**: Major functionality broken, significant security issue
- **Examples**: Payment processing down, authentication broken, API outage
- **Response time**: 15 minutes
- **Notification**: PagerDuty, Slack #incidents
- **Escalation**: After 1 hour to Level 2 (Tech Lead + IC)
- **Communication**: Updates every 2 hours

**P2 (Medium):**
- **Impact**: Partial functionality broken, minor security issue
- **Examples**: Single feature broken, slow performance, isolated errors
- **Response time**: 1 hour
- **Notification**: Slack #incidents
- **Escalation**: After 4 hours to Level 2
- **Communication**: Daily updates

**P3 (Low):**
- **Impact**: Minor issue, cosmetic bug, no security impact
- **Examples**: UI glitch, typo, non-critical feature issue
- **Response time**: Next business day
- **Notification**: Ticket system
- **Escalation**: None
- **Communication**: As needed

Classification criteria:
- **User impact**: How many users affected? (all, many, few, none)
- **Business impact**: Revenue loss? Reputation damage?
- **Security impact**: Data breach? Unauthorized access?
- **Compliance impact**: Regulatory violation?

Example:
"P0: Complete outage, data breach, security compromise. Response: Immediate, escalate to CTO+Legal, hourly updates
P1: Major feature down, auth broken, API outage. Response: 15 min, escalate after 1h, 2-hour updates
P2: Single feature broken, slow performance. Response: 1 hour, escalate after 4h, daily updates
P3: Minor UI issue, non-critical bug. Response: Next business day, no escalation

Classification: Consider user impact (all/many/few/none), business impact (revenue/reputation), security impact (breach/access), compliance impact (violation)"

Incident classification: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section)

---

### Question 3: IR Procedures (Required for secure)

**Context:** Documented procedures ensure consistent and effective incident response.

```
What are your incident response procedures?

IR phases:

**1. Detection:**
- How do you detect incidents?
  - Automated monitoring and alerts
  - User reports
  - Security scans
  - Audit log analysis
- Who receives alerts?
- How are incidents reported?

**2. Containment:**
- Immediate actions to limit damage
  - Isolate affected systems
  - Block malicious IPs
  - Disable compromised accounts
  - Take systems offline if necessary
- Short-term containment (stop the bleeding)
- Long-term containment (temporary fix while investigating)

**3. Investigation:**
- Determine root cause
  - Review logs (application, audit, system)
  - Analyze attack vectors
  - Identify compromised systems/data
  - Timeline reconstruction
- Preserve evidence (for legal/forensics)
- Document findings

**4. Eradication:**
- Remove threat completely
  - Delete malware
  - Close vulnerabilities
  - Revoke compromised credentials
  - Patch systems
- Verify threat is eliminated

**5. Recovery:**
- Restore normal operations
  - Restore from backups (if needed)
  - Rebuild compromised systems
  - Verify system integrity
  - Monitor for recurrence
- Gradual rollout (not all at once)

**6. Post-Incident Review (Postmortem):**
- Document what happened
  - Timeline of events
  - Root cause analysis
  - What went well
  - What went wrong
  - Action items for improvement
- Blameless postmortem (focus on process, not people)
- Share learnings with team
- Update runbooks and procedures

Example:
"Detection: Automated alerts (Datadog, AWS GuardDuty), user reports via support, daily log review
Containment: Isolate affected systems, block IPs via WAF, disable compromised accounts, take offline if critical
Investigation: Review CloudWatch logs, analyze attack vectors, identify compromised data, preserve evidence, document timeline
Eradication: Patch vulnerabilities, revoke credentials, remove malware, verify elimination
Recovery: Restore from backups if needed, rebuild systems, verify integrity, gradual rollout, monitor for 48 hours
Postmortem: Document within 48 hours, blameless review, share with team, update runbooks, track action items in Jira"

IR procedures: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section), `docs/specs/technical_design_spec.md` (Error Handling & Resilience section)

---

### Question 4: Breach Notification (Required for secure)

**Context:** Timely breach notification is legally required and maintains trust.

```
How will you handle breach notifications?

Notification requirements:

**Internal notification:**
- Who to notify immediately?
  - IR team
  - Executive team (CTO, CEO)
  - Legal counsel
  - Board of directors (for major breaches)
- How to notify? (Slack, email, phone)
- When to notify? (immediately upon detection)

**User notification:**
- When to notify users?
  - GDPR: Within 72 hours of breach discovery
  - HIPAA: Within 60 days
  - State laws: Varies (often 30-90 days)
  - Best practice: As soon as possible
- What to include?
  - What happened (breach description)
  - What data was affected
  - What you're doing about it
  - What users should do (change passwords, monitor accounts)
  - How to contact you for questions
- How to notify?
  - Email (primary method)
  - In-app notification
  - Website banner
  - Blog post

**Regulatory notification:**
- Which regulators to notify?
  - GDPR: Supervisory authority (within 72 hours)
  - HIPAA: HHS Office for Civil Rights (within 60 days)
  - State AGs: Varies by state
- What to include?
  - Nature of breach
  - Number of affected individuals
  - Types of data compromised
  - Mitigation steps taken
  - Contact information
- How to notify?
  - Online portal (GDPR, HIPAA)
  - Written notification
  - Legal counsel should handle

**Public notification:**
- When to go public?
  - Major breaches affecting many users
  - Media attention
  - Regulatory requirement
  - Transparency and trust
- What to include?
  - Factual description of breach
  - Number of affected users
  - Steps taken to address
  - Resources for affected users
- How to notify?
  - Press release
  - Blog post
  - Social media
  - Media interviews

Notification templates:
- Pre-written templates for common scenarios
- Legal review before sending
- Translations for international users

Example:
"Internal: Notify IR team + CTO + Legal immediately via PagerDuty + Slack. Notify CEO + Board for P0 incidents.

User: Notify within 72 hours (GDPR requirement). Email all affected users with: what happened, what data affected, our response, user actions needed, contact info. Also in-app notification + website banner.

Regulatory: GDPR - notify supervisory authority within 72 hours via online portal. HIPAA - notify HHS within 60 days. Legal counsel handles all regulatory notifications.

Public: For major breaches (>10k users), issue press release + blog post. Legal and PR review required.

Templates: Pre-written for common scenarios (data breach, unauthorized access, system compromise), legal review required, available in English + Spanish + French"

Breach notification: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section, Breach Notification section)

---

## Summary: What Gets Filled Out

After Phase 15 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Incident Response (IR team, roles, on-call rotation, escalation, severity levels, response times, IR procedures, breach notification)
- Breach Notification (internal, user, regulatory, public notification requirements and timelines)

### `docs/specs/technical_design_spec.md`
- Error Handling & Resilience (incident response procedures)

## Next Steps

After completing Phase 15 Q&A:

1. **Review incident response plan with security, legal, and executive teams** - Confirm procedures and responsibilities
2. **Proceed to Phase 16** - Security Governance (read `llm_qa_phase16_questions__t__.md`) - Final secure/compliance phase!
3. **Or implement incident response** - Set up on-call rotation, create runbooks, conduct tabletop exercises

**Note:** Phase 15 is the fifth of six secure/compliance phases (11-16). Incident response is critical for minimizing damage and maintaining compliance. Consider conducting regular tabletop exercises to practice your IR procedures.

## Incident Response Resources

- **NIST SP 800-61**: Computer Security Incident Handling Guide
- **SANS Incident Response**: https://www.sans.org/incident-response/
- **PagerDuty Incident Response**: https://response.pagerduty.com/
- **Atlassian Incident Management**: https://www.atlassian.com/incident-management
