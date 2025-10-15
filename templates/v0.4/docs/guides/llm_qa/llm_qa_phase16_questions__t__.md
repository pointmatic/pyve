# Phase 16: Security Governance Questions

## Overview

**Phase:** 16 (Security Governance)  
**When:** For secure Quality level  
**Duration:** 15-20 minutes  
**Questions:** 4 total  
**Outcome:** Security governance framework defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is required only for secure Quality level. It's the sixth and final secure/compliance phase (11-16). Congratulations on reaching the end!

## Topics Covered

- Security policies (formal policies, review process)
- Risk assessment (methodology, frequency, documentation)
- Third-party security (vendor assessment, contracts, monitoring)
- Security metrics (KPIs, tracking, reporting)

## Question Templates

### Question 1: Security Policies (Required for secure)

**Context:** Formal security policies establish organization-wide security standards.

```
What security policies will you establish?

Required security policies:

**Information Security Policy:**
- Overall security framework and principles
- Roles and responsibilities
- Policy enforcement and violations
- Review and update process

**Acceptable Use Policy:**
- Acceptable use of company systems and data
- Prohibited activities
- Personal use guidelines
- Consequences of violations

**Access Control Policy:**
- User account management (creation, modification, deletion)
- Authentication requirements (passwords, MFA)
- Authorization principles (least privilege, role-based access)
- Access review process (quarterly, annual)

**Data Classification Policy:**
- Data classification levels (public, internal, confidential, restricted)
- Handling requirements per classification
- Data retention and disposal
- Data sharing guidelines

**Incident Response Policy:**
- Incident definition and classification
- Reporting procedures
- Response procedures
- Roles and responsibilities

**Change Management Policy:**
- Change approval process
- Testing requirements
- Rollback procedures
- Emergency changes

**Vendor Management Policy:**
- Vendor security assessment
- Contract requirements
- Ongoing monitoring
- Vendor termination

**Business Continuity/Disaster Recovery Policy:**
- RTO and RPO targets
- Backup procedures
- Recovery procedures
- Testing frequency

Policy management:
- **Review frequency**: Annual review (minimum), update as needed
- **Approval process**: Security team drafts → Legal reviews → Executive approves
- **Distribution**: All employees acknowledge policies on hire and annually
- **Version control**: Track policy versions and changes
- **Accessibility**: Policies available in company wiki/intranet

Example:
"Policies: Information Security, Acceptable Use, Access Control, Data Classification, Incident Response, Change Management, Vendor Management, BC/DR
Review: Annual review by security team, legal review, executive approval
Distribution: All employees acknowledge on hire and annually, available in Confluence
Version control: Track in Git, changelog in each policy
Enforcement: HR handles violations, security team monitors compliance"

Security policies: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Governance section)

---

### Question 2: Risk Assessment (Required for secure)

**Context:** Regular risk assessments identify and prioritize security risks.

```
How will you conduct security risk assessments?

Risk assessment methodology:

**Risk identification:**
- What risks to assess?
  - Technical risks (vulnerabilities, misconfigurations)
  - Operational risks (process failures, human error)
  - Third-party risks (vendor breaches, supply chain)
  - Compliance risks (regulatory violations)
  - Business risks (reputation damage, financial loss)

**Risk analysis:**
- **Likelihood**: How likely is the risk? (rare, unlikely, possible, likely, almost certain)
- **Impact**: What's the potential damage? (negligible, minor, moderate, major, catastrophic)
- **Risk score**: Likelihood × Impact (1-25 scale)

**Risk prioritization:**
- **Critical (20-25)**: Immediate action required
- **High (15-19)**: Action within 30 days
- **Medium (10-14)**: Action within 90 days
- **Low (5-9)**: Monitor, address as resources allow
- **Negligible (1-4)**: Accept risk

**Risk treatment:**
- **Mitigate**: Implement controls to reduce risk
- **Transfer**: Insurance, outsource to vendor
- **Accept**: Acknowledge and document risk
- **Avoid**: Eliminate the activity causing risk

Risk assessment frequency:
- **Annual**: Comprehensive risk assessment
- **Quarterly**: Review high/critical risks
- **Ad-hoc**: After major changes, incidents, or new threats

Risk documentation:
- Risk register (list of all identified risks)
- Risk treatment plans
- Risk acceptance documentation
- Risk review meeting notes

Example:
"Methodology: Identify risks (technical, operational, third-party, compliance, business), analyze likelihood × impact (1-25 scale), prioritize (critical/high/medium/low), treat (mitigate/transfer/accept/avoid)

Frequency: Annual comprehensive assessment, quarterly review of high/critical risks, ad-hoc after incidents or major changes

Documentation: Risk register in Confluence, treatment plans in Jira, acceptance signed by CTO, quarterly review meetings

Process: Security team leads assessment, involves engineering/ops/legal, presents to executive team, tracks remediation in Jira"

Risk assessment: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Governance section)

---

### Question 3: Third-Party Security (Required for secure)

**Context:** Third-party vendors can introduce significant security risks.

```
How will you manage third-party security risks?

Vendor security assessment:

**Pre-contract assessment:**
- Security questionnaire (SOC 2, ISO 27001, security practices)
- Review security documentation
- Check for recent breaches or incidents
- Assess data handling practices
- Evaluate compliance certifications

**Risk categorization:**
- **Critical vendors**: Access to sensitive data or critical systems
  - Examples: Cloud hosting (AWS), database (PostgreSQL), payment (Stripe)
  - Assessment: Comprehensive security review, SOC 2 required
  
- **High-risk vendors**: Access to some data or important systems
  - Examples: Email (SendGrid), analytics (Mixpanel), monitoring (Datadog)
  - Assessment: Security questionnaire, review certifications
  
- **Low-risk vendors**: No data access or minimal access
  - Examples: Office supplies, marketing tools
  - Assessment: Basic due diligence

**Contract requirements:**
- Security and privacy terms
- Data processing agreement (DPA) for GDPR
- Business associate agreement (BAA) for HIPAA
- SLA requirements (uptime, response time)
- Breach notification requirements (within 24-72 hours)
- Right to audit
- Data deletion upon termination
- Liability and indemnification

**Ongoing monitoring:**
- Annual security review
- Monitor for security incidents or breaches
- Review SOC 2 reports annually
- Track vendor compliance with SLAs
- Quarterly business reviews for critical vendors

**Vendor offboarding:**
- Revoke all access
- Delete or return all data
- Verify data deletion
- Update documentation

Example:
"Assessment: Critical vendors (AWS, Stripe) require SOC 2 Type II + comprehensive review. High-risk vendors (SendGrid, Datadog) require security questionnaire + certifications. Low-risk vendors require basic due diligence.

Contracts: All vendors sign DPA (GDPR), critical vendors sign BAA (HIPAA), include breach notification (24h), right to audit, data deletion terms

Monitoring: Annual security review for all vendors, monitor for breaches, review SOC 2 reports annually, quarterly business reviews for critical vendors

Tracking: Vendor register in Confluence, contracts in DocuSign, security reviews in Jira

Offboarding: Revoke access, verify data deletion, document in vendor register"

Third-party security: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Governance section)

---

### Question 4: Security Metrics (Required for secure)

**Context:** Security metrics help track security posture and demonstrate improvement.

```
What security metrics will you track?

Security KPIs:

**Vulnerability metrics:**
- Open vulnerabilities by severity (critical, high, medium, low)
- Mean time to remediate (MTTR) by severity
- Vulnerability scan coverage (% of systems scanned)
- Patch compliance (% of systems up to date)

**Incident metrics:**
- Number of security incidents by severity
- Mean time to detect (MTTD)
- Mean time to respond (MTTR)
- Mean time to recover (MTTR)
- Incident recurrence rate

**Access control metrics:**
- % of users with MFA enabled
- % of accounts with least privilege
- Number of privileged accounts
- Access review completion rate
- Failed login attempts

**Compliance metrics:**
- % of policies reviewed on schedule
- % of employees trained on security
- % of vendors with current security assessments
- Audit findings (open, closed, overdue)
- Compliance violations

**Security awareness metrics:**
- % of employees completed security training
- Phishing simulation click rate
- Security incidents caused by human error
- Security policy violations

**Application security metrics:**
- % of code with security review
- Security issues found in code review
- Dependency vulnerabilities
- Security test coverage

Tracking and reporting:

**Dashboards:**
- Real-time security dashboard (Grafana, Datadog)
- Executive dashboard (high-level metrics)
- Team dashboards (detailed metrics)

**Reports:**
- Weekly: Incident summary, critical vulnerabilities
- Monthly: Comprehensive security metrics report
- Quarterly: Security posture review for executives
- Annual: Security program review for board

**Tools:**
- Vulnerability tracking: Jira, GitHub Issues
- Metrics collection: Prometheus, Datadog
- Visualization: Grafana, Tableau
- Reporting: Google Sheets, Confluence

Example:
"Vulnerabilities: Track open vulns by severity, MTTR (Critical 24h, High 7d, Medium 30d), scan coverage (target 100%), patch compliance (target 95%)

Incidents: Track incidents by severity, MTTD (target <1h), MTTR (target <4h for P1), recurrence rate (target <5%)

Access: MFA enabled (target 100%), least privilege (target 95%), quarterly access reviews (target 100% completion)

Compliance: Policies reviewed annually (100%), training completion (target 100%), vendor assessments current (target 100%)

Awareness: Training completion (target 100%), phishing click rate (target <10%)

Tracking: Jira for vulnerabilities, Datadog for metrics, Grafana for dashboards
Reporting: Weekly incident summary, monthly metrics report, quarterly executive review, annual board report"

Security metrics: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Governance section)

---

## Summary: What Gets Filled Out

After Phase 16 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Security Governance (security policies, risk assessment, third-party security, security metrics)

## Next Steps

After completing Phase 16 Q&A:

1. **Review security governance framework with security, legal, and executive teams** - Confirm policies and processes
2. **Congratulations!** You've completed all 17 phases (0-16) of the LLM Q&A guide
3. **Implement security governance** - Document policies, conduct risk assessment, assess vendors, set up metrics tracking

**Note:** Phase 16 is the sixth and final secure/compliance phase (11-16). Security governance provides the framework for maintaining and improving your security program over time.

## Congratulations! 🎉

You've completed all secure/compliance phases:
- **Phase 11**: Threat Modeling ✅
- **Phase 12**: Compliance Requirements ✅
- **Phase 13**: Advanced Security ✅
- **Phase 14**: Audit Logging ✅
- **Phase 15**: Incident Response ✅
- **Phase 16**: Security Governance ✅

Your application now has a comprehensive security and compliance framework suitable for secure Quality level!

## Security Governance Resources

- **NIST Cybersecurity Framework**: https://www.nist.gov/cyberframework
- **ISO 27001**: Information Security Management System standard
- **CIS Controls**: https://www.cisecurity.org/controls/
- **OWASP**: https://owasp.org/
