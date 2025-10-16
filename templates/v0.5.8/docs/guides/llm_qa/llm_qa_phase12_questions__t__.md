# Phase 12: Compliance Requirements Questions

## Overview

**Phase:** 12 (Compliance Requirements)  
**When:** For secure Quality level  
**Duration:** 20-30 minutes  
**Questions:** 5 total  
**Outcome:** Compliance requirements and strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is required only for secure Quality level. It's the second of six secure/compliance phases (11-16).

## Topics Covered

- Applicable regulations (GDPR, HIPAA, PCI DSS, SOC 2, CCPA, FERPA)
- GDPR compliance (consent, data subject rights, breach notification)
- HIPAA compliance (PHI protection, access controls, BAAs)
- PCI DSS compliance (card data storage, payment processors)
- SOC 2 compliance (Trust Service Criteria, controls)

## Question Templates

### Question 1: Applicable Regulations (Required for secure)

**Context:** Understanding which regulations apply determines your compliance obligations.

```
Which regulations apply to your application?

Common regulations:
- **GDPR** (General Data Protection Regulation): EU/EEA users
  - Applies if: You have users in EU/EEA or process EU residents' data
  - Key requirements: Consent, data subject rights, breach notification
  
- **HIPAA** (Health Insurance Portability and Accountability Act): US healthcare
  - Applies if: You handle Protected Health Information (PHI) in the US
  - Key requirements: PHI protection, access controls, BAAs, audit logs
  
- **PCI DSS** (Payment Card Industry Data Security Standard): Credit card data
  - Applies if: You store, process, or transmit credit card data
  - Key requirements: Secure storage, encryption, regular scanning
  
- **SOC 2** (Service Organization Control 2): B2B SaaS
  - Applies if: You provide services to other businesses
  - Key requirements: Trust Service Criteria (security, availability, confidentiality)
  
- **CCPA** (California Consumer Privacy Act): California residents
  - Applies if: You have California users and meet revenue/data thresholds
  - Key requirements: Privacy notices, data deletion, opt-out of sale
  
- **FERPA** (Family Educational Rights and Privacy Act): Student records
  - Applies if: You handle student education records in the US
  - Key requirements: Consent for disclosure, access rights, record security

Which regulations apply to your application?

Example: "GDPR (have EU users), HIPAA (handle patient health records), SOC 2 (B2B SaaS)"

Applicable regulations: ___________
```

**Fills:** `docs/specs/security_spec.md` (Compliance Requirements section)

---

### Question 2: GDPR Compliance (Required if GDPR applies)

**Context:** GDPR gives EU residents rights over their personal data.

```
How will you comply with GDPR requirements?

GDPR key requirements:

**Consent:**
- How will you obtain consent for data collection?
- How will users withdraw consent?
- How will you document consent?

**Data subject rights:**
- **Right to access**: How will users request their data?
- **Right to deletion**: How will you delete user data on request?
- **Right to portability**: How will you export user data?
- **Right to rectification**: How will users correct their data?

**Data protection:**
- Data minimization: Collect only necessary data
- Purpose limitation: Use data only for stated purposes
- Storage limitation: Delete data when no longer needed

**Breach notification:**
- How will you detect breaches?
- How will you notify users within 72 hours?
- How will you notify supervisory authority?

**Data Processing Agreement (DPA):**
- Do you use third-party processors?
- Do you have DPAs with all processors?

Example: 
"Consent: Explicit opt-in on signup, can withdraw in settings
Data subject rights: Self-service data export/deletion in account settings, respond to requests within 30 days
Breach notification: Automated breach detection, email notification to affected users within 72 hours, notify supervisory authority
DPAs: Have DPAs with AWS, SendGrid, Stripe"

GDPR compliance: ___________
```

**Fills:** `docs/specs/security_spec.md` (GDPR Compliance section)

---

### Question 3: HIPAA Compliance (Required if HIPAA applies)

**Context:** HIPAA protects Protected Health Information (PHI) in the US.

```
How will you comply with HIPAA requirements?

HIPAA key requirements:

**PHI protection:**
- What PHI do you handle? (medical records, diagnoses, treatment, billing)
- How will you encrypt PHI at rest and in transit?
- How will you de-identify PHI when possible?

**Access controls:**
- Who can access PHI? (role-based access)
- How will you authenticate users? (MFA required)
- How will you authorize access? (minimum necessary rule)

**Audit logs:**
- What PHI access will you log? (all access, modifications, deletions)
- How long will you retain audit logs? (6 years minimum)
- How will you protect audit log integrity?

**Business Associate Agreements (BAAs):**
- Which vendors access PHI? (hosting, email, analytics)
- Do you have BAAs with all vendors?
- Do vendors provide HIPAA-compliant services?

**Breach notification:**
- How will you detect PHI breaches?
- How will you notify affected individuals? (within 60 days)
- How will you notify HHS? (within 60 days, or annually if <500 affected)

**Administrative safeguards:**
- Who is your HIPAA Security Officer?
- Do you have written policies and procedures?
- Do you conduct regular risk assessments?

Example:
"PHI: Medical records, diagnoses, treatment plans. Encrypted with AES-256 at rest, TLS 1.3 in transit
Access controls: RBAC with MFA required, minimum necessary access, session timeouts
Audit logs: Log all PHI access/modifications, 7-year retention, immutable logs in AWS CloudWatch
BAAs: Have BAAs with AWS, Twilio, SendGrid. All are HIPAA-compliant
Breach notification: Automated detection, notify individuals within 60 days, notify HHS
Security Officer: Jane Doe, written policies, annual risk assessments"

HIPAA compliance: ___________
```

**Fills:** `docs/specs/security_spec.md` (HIPAA Compliance section)

---

### Question 4: PCI DSS Compliance (Required if PCI DSS applies)

**Context:** PCI DSS protects credit card data.

```
How will you comply with PCI DSS requirements?

PCI DSS key requirements:

**Card data handling:**
- Do you store credit card data? (strongly discouraged)
- If yes, what do you store? (never store CVV/CVC)
- How will you encrypt stored card data?

**Payment processor:**
- Which payment processor will you use? (Stripe, Square, Braintree)
- Does the processor handle card data? (recommended)
- Will you use hosted payment pages or tokenization?

**SAQ (Self-Assessment Questionnaire):**
- Which SAQ level applies?
  - **SAQ A**: Third-party hosted (Stripe Checkout, PayPal)
  - **SAQ A-EP**: E-commerce with third-party payment page
  - **SAQ D**: Direct card data handling (highest requirements)

**Network security:**
- How will you segment payment systems?
- How will you protect cardholder data environment?
- Do you use a firewall?

**Scanning and testing:**
- How often will you scan for vulnerabilities? (quarterly)
- Who will perform penetration testing? (annually)
- How will you address vulnerabilities?

**Best practice:** Use a payment processor (Stripe, Square) that handles all card data. This minimizes your PCI scope to SAQ A.

Example:
"Use Stripe for all payments, never touch card data directly
Stripe Checkout hosted payment page (SAQ A)
No card data stored in our systems
Quarterly vulnerability scans via Stripe's requirements
Annual penetration testing by third-party vendor"

PCI DSS compliance: ___________
```

**Fills:** `docs/specs/security_spec.md` (PCI DSS Compliance section)

---

### Question 5: SOC 2 Compliance (Required if SOC 2 applies)

**Context:** SOC 2 demonstrates security and operational controls to B2B customers.

```
How will you comply with SOC 2 requirements?

SOC 2 Trust Service Criteria:

**Security:**
- Access controls (authentication, authorization)
- Logical and physical access controls
- System operations (monitoring, incident response)
- Change management (code reviews, deployment process)

**Availability:**
- System uptime and performance
- Monitoring and incident response
- Disaster recovery and business continuity

**Confidentiality:**
- Data classification and handling
- Encryption at rest and in transit
- Secure data disposal

**Processing Integrity:**
- Data validation and error handling
- Quality assurance and testing
- Monitoring for processing errors

**Privacy:**
- Privacy notice and consent
- Data collection and use
- Data retention and disposal
- Data subject rights

SOC 2 Type:
- **Type I**: Controls are designed properly (point in time)
- **Type II**: Controls operate effectively over time (3-12 months)

SOC 2 process:
- Conduct readiness assessment
- Implement required controls
- Document policies and procedures
- Engage SOC 2 auditor
- Complete audit (3-6 months)
- Receive SOC 2 report

Example:
"Target SOC 2 Type II for Security and Availability
Security: RBAC, MFA, encryption, audit logging, incident response plan
Availability: 99.9% uptime SLA, monitoring, auto-scaling, disaster recovery
Engage auditor in Q2, complete audit in Q3
Document all policies and procedures
Conduct quarterly internal audits"

SOC 2 compliance: ___________
```

**Fills:** `docs/specs/security_spec.md` (SOC 2 Compliance section)

---

## Summary: What Gets Filled Out

After Phase 12 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Compliance Requirements (applicable regulations)
- GDPR Compliance (consent, data subject rights, breach notification, DPAs)
- HIPAA Compliance (PHI protection, access controls, audit logs, BAAs, breach notification)
- PCI DSS Compliance (card data handling, payment processor, SAQ level, scanning)
- SOC 2 Compliance (Trust Service Criteria, audit process)

## Next Steps

After completing Phase 12 Q&A:

1. **Review compliance requirements with legal/compliance team** - Confirm obligations and approach
2. **Proceed to Phase 13** - Advanced Security (read `llm_qa_phase13_questions__t__.md`)
3. **Or start compliance implementation** - Begin with highest priority regulations

**Note:** Phase 12 is the second of six secure/compliance phases (11-16). Compliance is complex and often requires legal counsel. Consider hiring a compliance consultant or lawyer specializing in your applicable regulations.

## Compliance Resources

- **GDPR**: https://gdpr.eu/
- **HIPAA**: https://www.hhs.gov/hipaa/
- **PCI DSS**: https://www.pcisecuritystandards.org/
- **SOC 2**: https://www.aicpa.org/soc2
- **CCPA**: https://oag.ca.gov/privacy/ccpa
- **FERPA**: https://www2.ed.gov/policy/gen/guid/fpco/ferpa/
