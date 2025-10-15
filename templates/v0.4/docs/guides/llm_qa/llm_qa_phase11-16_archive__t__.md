# Phase 3: Secure/Compliance Questions

## Overview

**Phase:** 3 (Secure/Compliance)  
**When:** For secure Quality level or regulated industries  
**Duration:** 60-120 minutes  
**Questions:** 40-80 (comprehensive security and compliance)  
**Outcome:** Compliance-ready specifications

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is only required for projects with Quality level = **secure**. If your project is experiment, prototype, or production Quality, you can skip Phase 3.

## Topics Covered

- Advanced security (threat modeling, hardening, penetration testing)
- Compliance requirements (GDPR, HIPAA, PCI DSS, SOC 2)
- Audit logging and incident response (formal procedures)
- Security governance and risk management

## Question Templates

### Threat Modeling (Required for secure)

**Context:** Understanding potential threats helps you build appropriate defenses.

---

**Question 1: Threat Identification**
```
What are the main threats to your application?

Common threats:
- **Data breach:** Unauthorized access to sensitive data
- **Account takeover:** Attackers gain access to user accounts
- **Denial of service:** Attackers make your app unavailable
- **Data tampering:** Attackers modify data
- **Privilege escalation:** Users gain unauthorized permissions
- **Supply chain attacks:** Compromised dependencies

For your application, which threats are most critical?

Example: "Healthcare app: Data breach (patient records), account takeover (admin accounts), data tampering (medical records)"

Critical threats: ___________
```

**Fills:** `docs/specs/security_spec.md` (Threat Modeling section), `docs/specs/technical_design_spec.md` (Security & Privacy section)

---

**Question 2: Attack Surfaces**
```
What are the entry points attackers could exploit?

Attack surfaces:
- **Web UI:** XSS, CSRF, clickjacking
- **API endpoints:** Injection, broken auth, excessive data exposure
- **Database:** SQL injection, unauthorized access
- **File uploads:** Malicious files, path traversal
- **Third-party integrations:** Compromised APIs, data leaks
- **Infrastructure:** Misconfigured servers, exposed ports

Example: "Web UI (forms, file uploads), REST API (all endpoints), PostgreSQL database, S3 file storage, Stripe integration"

Attack surfaces: ___________
```

**Fills:** `docs/specs/security_spec.md` (Threat Modeling section)

---

**Question 3: Threat Mitigations**
```
For each critical threat, what mitigations will you implement?

Example:
- **Data breach:** Encryption at rest, access controls, audit logging, regular security audits
- **Account takeover:** MFA required, rate limiting, account lockout, suspicious activity detection
- **Data tampering:** Audit logs, data integrity checks, role-based permissions

Mitigations: ___________
```

**Fills:** `docs/specs/security_spec.md` (Threat Modeling section), `docs/specs/technical_design_spec.md` (Security & Privacy section)

---

### Compliance Requirements (Required for secure)

**Context:** Regulated industries have specific compliance requirements that must be met.

---

**Question 4: Applicable Regulations**
```
Which regulations apply to your application?

Common regulations:
- **GDPR:** EU users (data privacy)
- **HIPAA:** US healthcare (patient data)
- **PCI DSS:** Payment card data
- **SOC 2:** Security and availability controls
- **CCPA:** California residents (data privacy)
- **FERPA:** US education (student records)

Example: "HIPAA (we handle patient health records), GDPR (we have EU users)"

Applicable regulations: ___________
```

**Fills:** `docs/specs/security_spec.md` (Compliance section)

---

**Question 5: GDPR Requirements** (if applicable)
```
For GDPR compliance, how will you handle:

- **Consent:** How do you obtain explicit consent for data collection?
- **Right to access:** How can users export their data?
- **Right to deletion:** How can users delete their data?
- **Right to portability:** What format for data export?
- **Breach notification:** Process for notifying users within 72 hours?
- **Data Protection Officer:** Do you need a DPO?

Example: "Consent via opt-in checkbox, data export as JSON, deletion via account settings, breach notification via email + incident response team"

GDPR implementation: ___________
```

**Fills:** `docs/specs/security_spec.md` (GDPR section)

---

**Question 6: HIPAA Requirements** (if applicable)
```
For HIPAA compliance, how will you handle:

- **PHI protection:** Encryption of Protected Health Information?
- **Access controls:** Who can access patient data?
- **Audit logs:** Logging all PHI access?
- **Business Associate Agreements:** BAAs with vendors?
- **Breach notification:** Process for notifying HHS and patients?
- **Risk assessment:** Annual security risk assessment?

Example: "PHI encrypted at rest and in transit, role-based access, comprehensive audit logs, BAAs with AWS and Twilio, formal breach notification process, annual risk assessment by security consultant"

HIPAA implementation: ___________
```

**Fills:** `docs/specs/security_spec.md` (HIPAA section)

---

**Question 7: PCI DSS Requirements** (if applicable)
```
For PCI DSS compliance, how will you handle:

- **Card data storage:** Do you store card numbers? (Avoid if possible)
- **Payment processor:** Using Stripe/Square/etc.? (Recommended)
- **PCI SAQ:** Which Self-Assessment Questionnaire applies?
- **Network segmentation:** Isolating payment processing?
- **Vulnerability scanning:** Quarterly scans?
- **Penetration testing:** Annual pen tests?

Example: "Use Stripe for all payment processing (never store card data), PCI SAQ A, quarterly vulnerability scans via approved vendor"

PCI DSS implementation: ___________
```

**Fills:** `docs/specs/security_spec.md` (PCI DSS section)

---

**Question 8: SOC 2 Requirements** (if applicable)
```
For SOC 2 compliance, which Trust Service Criteria apply?

- **Security:** Protection against unauthorized access
- **Availability:** System is available for operation and use
- **Processing Integrity:** System processing is complete, valid, accurate, timely
- **Confidentiality:** Confidential information is protected
- **Privacy:** Personal information is collected, used, retained, disclosed appropriately

What controls will you implement for each?

Example: "Security: MFA, encryption, access controls. Availability: 99.9% uptime, monitoring, incident response. Processing Integrity: data validation, error handling, audit logs"

SOC 2 controls: ___________
```

**Fills:** `docs/specs/security_spec.md` (SOC 2 section)

---

### Advanced Security (Required for secure)

**Question 9: Multi-Factor Authentication**
```
How will you implement MFA?

MFA requirements:
- **Who needs MFA:** All users? Admin only? Sensitive data access?
- **MFA methods:** TOTP (authenticator app), SMS, email, hardware keys?
- **Enrollment:** Required or optional? Grace period?
- **Recovery:** Backup codes? Recovery email?

Example: "MFA required for all users (no grace period), TOTP via Google Authenticator or Authy, backup codes provided, recovery via email verification"

MFA implementation: ___________
```

**Fills:** `docs/specs/security_spec.md` (Multi-Factor Authentication section)

---

**Question 10: Data Encryption Details**
```
Provide detailed encryption specifications:

**At rest:**
- Database: Which encryption? (e.g., PostgreSQL TDE, AWS RDS encryption)
- File storage: Which encryption? (e.g., S3 SSE-KMS)
- Backups: Encrypted? Key management?

**In transit:**
- TLS version: 1.2 minimum? 1.3 preferred?
- Certificate management: Let's Encrypt? AWS ACM?
- Internal communication: Encrypted? (service-to-service)

**Application-level:**
- Sensitive fields: Which encryption library? (e.g., Fernet, AES-256)
- Key management: Where stored? Rotation schedule?

Example: "PostgreSQL with AWS RDS encryption (AES-256), S3 with SSE-KMS, TLS 1.3 with AWS ACM certificates, Fernet for PII fields with keys in AWS Secrets Manager (rotated quarterly)"

Encryption details: ___________
```

**Fills:** `docs/specs/security_spec.md` (Encryption section)

---

**Question 11: Secrets Rotation**
```
What is your secrets rotation policy?

For each secret type:
- **API keys:** Rotation frequency? Automated?
- **Database passwords:** Rotation frequency? Automated?
- **JWT secrets:** Rotation frequency? Process?
- **Encryption keys:** Rotation frequency? Process?
- **OAuth secrets:** Rotation frequency? Process?

Example: "API keys: 90 days (automated via AWS Secrets Manager), Database passwords: 90 days (automated), JWT secrets: 180 days (manual), Encryption keys: 365 days (manual with key versioning)"

Rotation policy: ___________
```

**Fills:** `docs/specs/security_spec.md` (Secrets Management section)

---

**Question 12: Vulnerability Management**
```
How will you identify and remediate vulnerabilities?

Processes:
- **Dependency scanning:** Tool? Frequency? (e.g., pip-audit weekly)
- **Code scanning:** Tool? Frequency? (e.g., Bandit, SonarQube)
- **Container scanning:** Tool? Frequency? (e.g., Trivy, Snyk)
- **Remediation SLA:** How quickly to fix critical/high/medium/low?

Example: "pip-audit in CI on every commit, Bandit for Python code analysis, Trivy for container scanning. SLA: Critical 24hr, High 7 days, Medium 30 days, Low 90 days"

Vulnerability management: ___________
```

**Fills:** `docs/specs/security_spec.md` (Vulnerability Management section)

---

**Question 13: Penetration Testing**
```
What is your penetration testing plan?

Requirements:
- **Frequency:** Annual? Quarterly? After major changes?
- **Scope:** Full application? Specific components?
- **Provider:** Internal team? External firm? Bug bounty?
- **Remediation:** Process for fixing findings?
- **Reporting:** Who receives reports? Format?

Example: "Annual penetration test by external security firm, full application scope, all findings remediated before production release, reports to CTO and compliance team"

Pen testing plan: ___________
```

**Fills:** `docs/specs/security_spec.md` (Penetration Testing section)

---

**Question 14: Security Training**
```
How will you ensure team members understand security requirements?

Training needs:
- **Onboarding:** Security training for new hires?
- **Ongoing:** Annual refresher training?
- **Role-specific:** Extra training for admins/developers?
- **Compliance:** Training on GDPR/HIPAA/etc.?
- **Phishing:** Simulated phishing tests?

Example: "Security training during onboarding (2 hours), annual refresher (1 hour), developer-specific secure coding training (4 hours annually), HIPAA training for all staff (annual), quarterly phishing simulations"

Security training: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Training section)

---

### Audit Logging (Required for secure)

**Question 15: Audit Log Requirements**
```
What events must be logged for audit purposes?

Required events:
- **Authentication:** Login, logout, failed attempts, MFA events
- **Authorization:** Permission changes, role assignments, access denied
- **Data access:** Views, exports, modifications of sensitive data
- **Configuration:** Settings changes, user management, security config
- **Security events:** Suspicious activity, policy violations

For each event, log:
- **Who:** User ID, IP address
- **What:** Action performed
- **When:** Timestamp (UTC)
- **Where:** Resource/endpoint accessed
- **Result:** Success or failure

Example: "Log all authentication events, all PHI access, all admin actions, all configuration changes. Include user ID, IP, timestamp, action, resource, result. Store in immutable audit log (S3 with object lock)"

Audit log requirements: ___________
```

**Fills:** `docs/specs/security_spec.md` (Audit Logging section)

---

**Question 16: Audit Log Retention**
```
How long will you retain audit logs?

Retention requirements:
- **Compliance:** HIPAA requires 6 years, GDPR varies
- **Storage:** Where stored? (e.g., S3, CloudWatch Logs)
- **Immutability:** Logs cannot be modified or deleted?
- **Access:** Who can access audit logs?
- **Review:** How often reviewed? By whom?

Example: "Retain audit logs for 7 years (HIPAA + 1 year buffer), store in S3 with object lock (immutable), access restricted to security team and auditors, automated review for anomalies, manual review quarterly"

Retention policy: ___________
```

**Fills:** `docs/specs/security_spec.md` (Audit Logging section)

---

### Incident Response (Required for secure)

**Question 17: Incident Response Team**
```
Who is responsible for security incident response?

Team structure:
- **Incident Commander:** Who leads response?
- **Technical Lead:** Who investigates and remediates?
- **Communications Lead:** Who handles internal/external comms?
- **Legal/Compliance:** Who handles legal/regulatory requirements?
- **On-call rotation:** 24/7 coverage? Escalation path?

Example: "Incident Commander: CTO, Technical Lead: Senior Engineer (on-call rotation), Communications: Head of Customer Success, Legal: External counsel, 24/7 on-call coverage with 15-minute response SLA"

IR team: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section)

---

**Question 18: Incident Classification**
```
How will you classify security incidents?

Severity levels:
- **P0/Critical:** Active breach, data exfiltration, system compromise
- **P1/High:** Vulnerability with high risk, attempted breach
- **P2/Medium:** Vulnerability with medium risk, suspicious activity
- **P3/Low:** Vulnerability with low risk, policy violation

For each level:
- **Response time:** How quickly to respond?
- **Escalation:** Who to notify?
- **Communication:** Internal? External? Regulatory?

Example: "P0: 15-min response, notify CEO/board, external comms if data breach. P1: 1-hour response, notify CTO. P2: 4-hour response, notify security team. P3: 24-hour response, log and track"

Incident classification: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section)

---

**Question 19: Incident Response Procedures**
```
What are your formal incident response procedures?

Procedures:
1. **Detection:** How are incidents detected? (monitoring, alerts, reports)
2. **Containment:** Immediate steps to limit damage?
3. **Investigation:** How to determine scope and root cause?
4. **Eradication:** How to remove threat?
5. **Recovery:** How to restore normal operations?
6. **Post-incident:** Postmortem process? Lessons learned?

Example: "Detection via Sentry alerts and user reports. Containment: disable affected accounts, isolate systems. Investigation: review logs, forensics. Eradication: patch vulnerabilities, remove malware. Recovery: restore from backups, verify integrity. Post-incident: postmortem within 48 hours, update runbooks"

IR procedures: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section)

---

**Question 20: Breach Notification**
```
What is your data breach notification process?

Notification requirements:
- **Internal:** Who to notify internally? Timeline?
- **Users:** When to notify affected users? How?
- **Regulatory:** Which regulators to notify? Timeline? (GDPR: 72 hours, HIPAA: 60 days)
- **Public:** When to make public statement?
- **Content:** What information to include?

Example: "Internal: Notify CEO, CTO, legal within 1 hour. Users: Email within 24 hours if PII compromised. Regulatory: GDPR notification within 72 hours to supervisory authority, HIPAA notification within 60 days to HHS. Public: Statement on website if >500 users affected. Include: what happened, what data, what we're doing, what users should do"

Breach notification: ___________
```

**Fills:** `docs/specs/security_spec.md` (Incident Response section)

---

### Security Governance (Required for secure)

**Question 21: Security Policies**
```
What formal security policies will you maintain?

Required policies:
- **Acceptable Use Policy:** How employees can use systems
- **Access Control Policy:** Who gets access to what
- **Data Classification Policy:** How to classify data (public, internal, confidential, restricted)
- **Incident Response Policy:** Formal IR procedures
- **Vendor Management Policy:** Security requirements for vendors
- **Change Management Policy:** How to make security-relevant changes

Example: "Maintain all policies in wiki, reviewed annually, all employees must acknowledge, violations reported to security team"

Security policies: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Governance section)

---

**Question 22: Risk Assessment**
```
How will you conduct security risk assessments?

Risk assessment process:
- **Frequency:** Annual? After major changes?
- **Methodology:** NIST? ISO 27001? Custom?
- **Scope:** Full application? Infrastructure? Third-parties?
- **Participants:** Who conducts? Who reviews?
- **Documentation:** Risk register? Treatment plans?
- **Follow-up:** How to track remediation?

Example: "Annual risk assessment using NIST framework, covers application + infrastructure + vendors, conducted by security team with external consultant, documented in risk register, quarterly follow-up on remediation"

Risk assessment: ___________
```

**Fills:** `docs/specs/security_spec.md` (Risk Management section)

---

**Question 23: Third-Party Security**
```
How will you ensure third-party vendors meet security requirements?

Vendor security:
- **Assessment:** Security questionnaire? SOC 2 report?
- **Contracts:** Security requirements in contracts? BAAs?
- **Access:** Least privilege access for vendors?
- **Monitoring:** Ongoing monitoring of vendor security?
- **Offboarding:** Process for removing vendor access?

Example: "Require SOC 2 Type II reports from all vendors, security questionnaire for critical vendors, BAAs for HIPAA compliance, annual review of vendor security posture, formal offboarding process"

Third-party security: ___________
```

**Fills:** `docs/specs/security_spec.md` (Vendor Management section)

---

**Question 24: Security Metrics**
```
What security metrics will you track?

Key metrics:
- **Vulnerability metrics:** Open vulnerabilities by severity, time to remediate
- **Incident metrics:** Number of incidents, time to detect, time to resolve
- **Compliance metrics:** Audit findings, policy violations
- **Access metrics:** Failed login attempts, privilege escalations
- **Training metrics:** Training completion rates, phishing test results

Example: "Track: open vulnerabilities (target <5 high), mean time to remediate (target <7 days for high), security incidents (target <2/month), failed logins (alert on >10/hour), training completion (target 100% within 30 days of hire)"

Security metrics: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Metrics section)

---

## Example Q&A Session: Secure-Level Healthcare Platform

**LLM:** You've completed Phase 2 (production readiness). Since your Quality level is **secure** and you're handling healthcare data, we need to conduct Phase 3 for compliance and advanced security. This will take about 60-90 minutes. Ready?

**Developer:** Yes, let's do it. We need to be HIPAA compliant.

---

**LLM:** Let's start with threat modeling. What are the main threats to your healthcare application?

**Developer:** The biggest threats are data breaches of patient health records, unauthorized access to patient data, and account takeover of provider accounts.

---

**LLM:** What are the main attack surfaces where these threats could be exploited?

**Developer:** Our web UI where providers enter patient data, our REST API that mobile apps use, the PostgreSQL database with patient records, and our integration with a third-party lab system.

---

**LLM:** For each of those critical threats, what mitigations will you implement?

**Developer:** For data breaches: encryption at rest and in transit, strict access controls, comprehensive audit logging, annual penetration testing. For unauthorized access: role-based access control, MFA for all users, session timeouts. For account takeover: MFA required, rate limiting on login, account lockout after failed attempts, suspicious activity monitoring.

---

**LLM:** Which regulations apply to your application?

**Developer:** HIPAA because we handle patient health information, and GDPR because we have some EU patients.

---

**LLM:** For HIPAA compliance, let's go through the key requirements. How will you protect PHI?

**Developer:** All PHI will be encrypted at rest using AWS RDS encryption and in transit using TLS 1.3. We'll have role-based access controls so only authorized providers can access patient data. We'll log every access to PHI. We'll have Business Associate Agreements with AWS, Twilio for SMS, and our lab integration partner. We have a formal breach notification process and will conduct annual risk assessments with an external security consultant.

---

**LLM:** For GDPR, how will you handle the key requirements?

**Developer:** We'll get explicit consent via checkbox before collecting any data. Users can export their data as JSON through their account settings. They can request deletion through account settings or by contacting support. For breach notification, we have a process to notify users within 72 hours via email and notify the supervisory authority.

---

**LLM:** How will you implement multi-factor authentication?

**Developer:** MFA will be required for all users - providers and patients. We'll support TOTP via Google Authenticator or Authy. Users will get backup codes during enrollment. If they lose access, they can recover via email verification with a time-limited token.

---

**LLM:** Provide detailed encryption specifications.

**Developer:** At rest: PostgreSQL with AWS RDS encryption using AES-256, S3 for file storage with SSE-KMS, encrypted backups. In transit: TLS 1.3 for all connections using AWS ACM certificates. Application-level: We'll use Fernet to encrypt especially sensitive fields like SSNs, with keys stored in AWS Secrets Manager and rotated quarterly.

---

**LLM:** What is your secrets rotation policy?

**Developer:** API keys rotate every 90 days automatically via AWS Secrets Manager. Database passwords rotate every 90 days automatically. JWT secrets rotate every 180 days manually. Encryption keys rotate annually with key versioning. OAuth secrets rotate when the provider recommends it.

---

**LLM:** How will you identify and remediate vulnerabilities?

**Developer:** We run pip-audit in CI on every commit. We use Bandit for Python static analysis. We scan our Docker containers with Trivy. Our SLA is: critical vulnerabilities fixed within 24 hours, high within 7 days, medium within 30 days, low within 90 days.

---

**LLM:** What is your penetration testing plan?

**Developer:** We'll do annual penetration testing by an external security firm that specializes in healthcare. They'll test the full application. All findings must be remediated before we go live. Reports go to our CTO and compliance officer.

---

**LLM:** How will you ensure your team understands security requirements?

**Developer:** All new hires get 2 hours of security training during onboarding. Everyone gets annual refresher training. Developers get 4 hours of secure coding training annually. All staff get HIPAA training annually. We run quarterly phishing simulations.

---

**LLM:** What events must be logged for audit purposes?

**Developer:** We log all authentication events (login, logout, failed attempts, MFA), all PHI access (views, exports, modifications), all admin actions, all configuration changes. Each log entry includes user ID, IP address, timestamp in UTC, action performed, resource accessed, and success/failure. Logs are stored in S3 with object lock so they're immutable.

---

**LLM:** How long will you retain audit logs?

**Developer:** We'll retain audit logs for 7 years to meet HIPAA's 6-year requirement plus a buffer. Logs are stored in S3 with object lock. Only the security team and external auditors can access them. We have automated anomaly detection and do manual reviews quarterly.

---

**LLM:** Who is responsible for security incident response?

**Developer:** Our CTO is the Incident Commander. We have a senior engineer on-call rotation as Technical Lead. Our Head of Customer Success handles communications. We have external legal counsel for legal and compliance issues. We have 24/7 on-call coverage with a 15-minute response SLA.

---

**LLM:** How will you classify security incidents?

**Developer:** P0/Critical: active breach or data exfiltration - 15-minute response, notify CEO and board, external communication if data breach. P1/High: high-risk vulnerability or attempted breach - 1-hour response, notify CTO. P2/Medium: medium-risk vulnerability - 4-hour response, notify security team. P3/Low: low-risk vulnerability - 24-hour response, log and track.

---

**LLM:** What are your formal incident response procedures?

**Developer:** Detection via Sentry alerts and user reports. Containment: disable affected accounts, isolate compromised systems. Investigation: review audit logs, conduct forensics. Eradication: patch vulnerabilities, remove any malware. Recovery: restore from backups, verify data integrity. Post-incident: postmortem within 48 hours, update runbooks and procedures.

---

**LLM:** What is your data breach notification process?

**Developer:** Internal: notify CEO, CTO, and legal within 1 hour. Users: email affected users within 24 hours if their PHI was compromised. Regulatory: notify HHS within 60 days per HIPAA, notify GDPR supervisory authority within 72 hours if EU patients affected. Public: post statement on website if more than 500 patients affected. Include what happened, what data was involved, what we're doing, and what users should do.

---

**LLM:** What formal security policies will you maintain?

**Developer:** We'll maintain Acceptable Use, Access Control, Data Classification, Incident Response, Vendor Management, and Change Management policies. All policies will be in our internal wiki, reviewed annually, and all employees must acknowledge them. Violations are reported to the security team.

---

**LLM:** How will you conduct security risk assessments?

**Developer:** Annual risk assessment using the NIST framework, covering our application, infrastructure, and third-party vendors. Conducted by our security team with an external consultant. We'll maintain a risk register and have quarterly follow-ups on remediation.

---

**LLM:** How will you ensure third-party vendors meet security requirements?

**Developer:** We require SOC 2 Type II reports from all vendors. Critical vendors must complete our security questionnaire. We have Business Associate Agreements with all vendors who handle PHI. We review vendor security posture annually. We have a formal offboarding process to remove vendor access.

---

**LLM:** What security metrics will you track?

**Developer:** Open vulnerabilities by severity (target: less than 5 high-severity), mean time to remediate (target: under 7 days for high), security incidents per month (target: under 2), failed login attempts (alert on more than 10 per hour), security training completion (target: 100% within 30 days of hire).

---

**LLM:** Excellent! Here's what I understand:

**Threat Model:**
- Critical threats: Data breach, unauthorized access, account takeover
- Attack surfaces: Web UI, REST API, PostgreSQL, third-party lab integration
- Mitigations: Encryption, access controls, audit logging, MFA, rate limiting, pen testing

**Compliance:**
- HIPAA: PHI encryption, access controls, audit logs, BAAs, breach notification, annual risk assessments
- GDPR: Explicit consent, data export, deletion, 72-hour breach notification

**Advanced Security:**
- MFA: Required for all users, TOTP, backup codes, email recovery
- Encryption: AES-256 at rest, TLS 1.3 in transit, Fernet for sensitive fields, quarterly key rotation
- Secrets: 90-day rotation (automated), AWS Secrets Manager
- Vulnerabilities: pip-audit + Bandit + Trivy, 24hr SLA for critical
- Pen testing: Annual by external firm
- Training: Onboarding + annual refresher + HIPAA + phishing tests

**Audit Logging:**
- Events: Auth, PHI access, admin actions, config changes
- Retention: 7 years, S3 with object lock, quarterly review

**Incident Response:**
- Team: CTO (commander), on-call engineer (technical), customer success (comms), external legal
- Classification: P0 (15min), P1 (1hr), P2 (4hr), P3 (24hr)
- Procedures: Detect → Contain → Investigate → Eradicate → Recover → Postmortem
- Breach notification: Internal (1hr), users (24hr), HHS (60 days), GDPR (72hr)

**Governance:**
- Policies: Acceptable Use, Access Control, Data Classification, IR, Vendor, Change Management
- Risk assessment: Annual NIST-based with external consultant
- Third-party: SOC 2 reports, security questionnaires, BAAs, annual reviews
- Metrics: Vulnerabilities, incidents, failed logins, training completion

Does this look correct?

**Developer:** Yes, that's comprehensive and accurate.

---

**LLM:** Perfect! I've filled out the Phase 3 specifications in:
- `docs/specs/security_spec.md` (All advanced sections: Threat Modeling, HIPAA, GDPR, MFA, Encryption, Vulnerability Management, Pen Testing, Audit Logging, Incident Response, Compliance, Governance)
- `docs/specs/technical_design_spec.md` (Enhanced Security & Privacy section)

Your application is now ready for secure Quality deployment with full HIPAA and GDPR compliance!

Would you like me to:
1. Start implementing the security hardening
2. Review the compliance documentation
3. Create security runbooks and procedures

**Developer:** Let's start implementing the security hardening.

---

## Summary: What Gets Filled Out

After Phase 3 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Threat Modeling (threats, attack surfaces, mitigations)
- Compliance (GDPR, HIPAA, PCI DSS, SOC 2, CCPA, FERPA)
- Multi-Factor Authentication (detailed implementation)
- Advanced Encryption (detailed specifications)
- Secrets Rotation (policies and procedures)
- Vulnerability Management (scanning, remediation, SLAs)
- Penetration Testing (frequency, scope, providers)
- Security Training (onboarding, ongoing, role-specific)
- Audit Logging (events, retention, access, review)
- Incident Response (team, classification, procedures, breach notification)
- Security Governance (policies, risk assessment, vendor management, metrics)

### `docs/specs/technical_design_spec.md`
- Security & Privacy (enhanced with threat model and detailed mitigations)

## Next Steps

After completing Phase 3 Q&A:

1. **Review specs with developer and compliance team** - Ensure all requirements are met
2. **Implement security hardening** - MFA, encryption, audit logging, etc.
3. **Complete compliance documentation** - Policies, procedures, risk assessments
4. **Conduct security audits** - Penetration testing, vulnerability scans
5. **Deploy to production** - With full security and compliance controls in place

Phase 3 represents the highest level of security rigor and is only required for applications handling sensitive data in regulated industries.
