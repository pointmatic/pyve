# Phase 13: Advanced Security Questions

## Overview

**Phase:** 13 (Advanced Security)  
**When:** For secure Quality level  
**Duration:** 20-25 minutes  
**Questions:** 5 total  
**Outcome:** Advanced security controls and practices defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is required only for secure Quality level. It's the third of six secure/compliance phases (11-16). This builds on basic security from Phase 4 (Security Basics).

## Topics Covered

- Advanced encryption (detailed specifications, key management)
- Secrets rotation (policies, automation, frequency)
- Vulnerability management (scanning, remediation SLAs)
- Penetration testing (frequency, scope, providers)
- Security training (onboarding, ongoing, role-specific)

## Question Templates

### Question 1: Advanced Encryption (Required for secure)

**Context:** Advanced encryption goes beyond basic TLS and password hashing.

```
What are your detailed encryption requirements?

Encryption at rest:
- **Database encryption**: Full disk encryption or column-level?
  - Algorithm: AES-256-GCM (recommended)
  - Key management: AWS KMS, GCP KMS, HashiCorp Vault
  - Key rotation: Automatic or manual? How often?

- **File storage encryption**: S3, GCS, Azure Blob
  - Server-side encryption (SSE) or client-side?
  - Key management: Provider-managed or customer-managed keys?

- **Application-level encryption**: Sensitive fields (SSN, credit cards, PII)
  - Algorithm: AES-256-GCM, Fernet (Python)
  - Where to encrypt: Application layer before database
  - Key storage: Separate from encrypted data

Encryption in transit:
- **TLS version**: TLS 1.3 (recommended), minimum TLS 1.2
- **Certificate management**: Let's Encrypt, AWS ACM, manual
  - Auto-renewal or manual?
  - Certificate monitoring and alerting?

- **Internal service communication**: mTLS (mutual TLS)?
  - Service mesh (Istio, Linkerd) or manual configuration?

Key management:
- **Key storage**: Hardware Security Module (HSM), KMS, Vault
- **Key rotation**: How often? (90 days recommended)
- **Key access**: Who can access encryption keys?
- **Key backup**: How are keys backed up?
- **Key destruction**: How are old keys destroyed?

Example:
"Database: AES-256-GCM full disk encryption via AWS RDS, AWS KMS for key management, automatic key rotation every 90 days
File storage: S3 SSE with customer-managed keys (CMK) in KMS
Application-level: Fernet encryption for SSN/credit card fields, keys in AWS Secrets Manager
TLS: TLS 1.3 only, Let's Encrypt with auto-renewal, certificate expiry monitoring
Internal: mTLS for service-to-service communication via Istio
Key management: AWS KMS, 90-day rotation, keys accessible only to security team, automated backup"

Advanced encryption: ___________
```

**Fills:** `docs/specs/security_spec.md` (Data Protection section, Encryption section)

---

### Question 2: Secrets Rotation (Required for secure)

**Context:** Regular secrets rotation limits the impact of compromised credentials.

```
What is your secrets rotation policy?

Secrets to rotate:
- **Database passwords**: Application database credentials
- **API keys**: Third-party service keys (Stripe, SendGrid, etc.)
- **Encryption keys**: Data encryption keys
- **Service credentials**: Service account credentials, OAuth client secrets
- **TLS certificates**: SSL/TLS certificates

Rotation frequency:
- **Critical secrets**: 30-90 days (database passwords, encryption keys)
- **Standard secrets**: 90-180 days (API keys, service credentials)
- **Certificates**: Before expiry (typically 90 days with Let's Encrypt)

Rotation process:
- **Manual**: Admin rotates secrets manually (error-prone)
- **Semi-automated**: Script-assisted rotation (recommended for most)
- **Fully automated**: Automatic rotation without human intervention (ideal)

Rotation steps:
1. Generate new secret
2. Deploy new secret to all services
3. Verify services work with new secret
4. Revoke old secret
5. Update documentation

Zero-downtime rotation:
- Support both old and new secrets during transition
- Graceful rollover period (e.g., 1 hour)
- Automated rollback if issues detected

Example:
"Database passwords: Rotate every 90 days, semi-automated with script
API keys: Rotate every 180 days, manual rotation with checklist
Encryption keys: Automatic rotation every 90 days via AWS KMS
TLS certificates: Automatic renewal via Let's Encrypt (90 days)
Rotation process: Generate new → deploy to all services → verify → revoke old → document
Zero-downtime: 1-hour overlap period where both secrets work"

Secrets rotation: ___________
```

**Fills:** `docs/specs/security_spec.md` (Secrets Management section)

---

### Question 3: Vulnerability Management (Required for secure)

**Context:** Proactive vulnerability management prevents security incidents.

```
How will you manage vulnerabilities?

Vulnerability scanning:
- **Dependency scanning**: Check for vulnerable packages
  - Tools: pip-audit, Snyk, Dependabot, GitHub Security Alerts
  - Frequency: Every commit (CI/CD), daily scans
  - Auto-update: Patch versions automatically?

- **Container scanning**: Scan Docker images for vulnerabilities
  - Tools: Trivy, Snyk, AWS ECR scanning, Anchore
  - Frequency: On build, daily scans of deployed images
  - Base image updates: How often to update base images?

- **Infrastructure scanning**: Scan cloud resources for misconfigurations
  - Tools: AWS Security Hub, ScoutSuite, Prowler, CloudSploit
  - Frequency: Daily or continuous
  - Auto-remediation: Automatic fixes for common issues?

- **Code scanning**: Static analysis for security issues
  - Tools: Bandit (Python), SonarQube, Semgrep, CodeQL
  - Frequency: Every commit (CI/CD)
  - Block on critical issues: Fail build on high/critical findings?

Remediation SLAs:
- **Critical**: 24 hours (actively exploited, no workaround)
- **High**: 7 days (exploitable, workaround available)
- **Medium**: 30 days (requires specific conditions)
- **Low**: 90 days (minimal risk)

Vulnerability tracking:
- How will you track vulnerabilities? (Jira, GitHub Issues, dedicated tool)
- Who is responsible for remediation?
- How will you verify fixes?

Example:
"Dependency scanning: pip-audit in CI on every commit, Dependabot for auto-updates of patch versions
Container scanning: Trivy on every build, daily scans of production images, update base images monthly
Infrastructure scanning: AWS Security Hub daily, auto-remediate common misconfigurations
Code scanning: Bandit in CI, fail build on critical findings
Remediation SLAs: Critical 24h, High 7d, Medium 30d, Low 90d
Tracking: Jira security board, security team owns remediation, verify with re-scan"

Vulnerability management: ___________
```

**Fills:** `docs/specs/security_spec.md` (Vulnerability Management section), `docs/specs/codebase_spec.md` (Security section)

---

### Question 4: Penetration Testing (Required for secure)

**Context:** Penetration testing identifies vulnerabilities that automated tools miss.

```
What is your penetration testing strategy?

Pen test frequency:
- **Annual**: Minimum for secure Quality (recommended)
- **Bi-annual**: For high-risk applications
- **After major changes**: New features, architecture changes
- **Continuous**: Bug bounty program for ongoing testing

Pen test scope:
- **Web application**: UI, API endpoints, authentication
- **Infrastructure**: Network, cloud configuration, containers
- **Mobile apps**: iOS/Android applications (if applicable)
- **Internal systems**: Admin panels, internal tools
- **Social engineering**: Phishing, physical security (optional)

Pen test type:
- **Black box**: No internal knowledge (external attacker perspective)
- **Gray box**: Some knowledge (authenticated user perspective)
- **White box**: Full knowledge (comprehensive testing)

Pen test providers:
- **External firm**: Professional pen testing company (recommended)
  - Examples: Bishop Fox, NCC Group, Cure53, Trail of Bits
- **Bug bounty**: HackerOne, Bugcrowd, Synack
- **Internal team**: In-house security team (if available)

Pen test process:
1. Define scope and rules of engagement
2. Conduct testing (1-2 weeks)
3. Receive report with findings
4. Remediate vulnerabilities
5. Re-test to verify fixes
6. Document results and improvements

Example:
"Annual penetration testing by external firm (Bishop Fox)
Scope: Web application, REST API, AWS infrastructure, admin panel
Type: Gray box (provide test account credentials)
Process: 2-week test, 2-week remediation, 1-week re-test
Also run bug bounty program on HackerOne for continuous testing
Budget: $30k for annual pen test, $10k/year for bug bounty"

Penetration testing: ___________
```

**Fills:** `docs/specs/security_spec.md` (Penetration Testing section)

---

### Question 5: Security Training (Required for secure)

**Context:** Security training ensures your team follows security best practices.

```
What security training will you provide?

Training for developers:
- **Onboarding**: Security basics for new hires
  - Topics: Secure coding, OWASP Top 10, company security policies
  - Format: Video course, workshop, documentation
  - Duration: 2-4 hours
  - Verification: Quiz or assessment

- **Ongoing training**: Regular security updates
  - Frequency: Quarterly or bi-annual
  - Topics: New threats, security incidents, tool updates
  - Format: Lunch & learn, workshops, online courses

- **Role-specific training**: Specialized training by role
  - Backend developers: API security, database security, authentication
  - Frontend developers: XSS, CSRF, secure storage
  - DevOps: Infrastructure security, secrets management, monitoring
  - Security team: Advanced topics, certifications (CISSP, CEH, OSCP)

Training content:
- **Secure coding practices**: Input validation, output encoding, parameterized queries
- **OWASP Top 10**: Common vulnerabilities and mitigations
- **Authentication & authorization**: OAuth, JWT, session management
- **Cryptography**: When and how to use encryption
- **Incident response**: What to do when you find a security issue
- **Compliance**: GDPR, HIPAA, PCI DSS (if applicable)

Training providers:
- **Internal**: In-house security team creates content
- **External**: SANS, Pluralsight, Udemy, Coursera
- **Vendor**: Security tool vendors (Snyk, Veracode)

Training verification:
- Completion tracking
- Assessments or quizzes
- Hands-on labs or exercises
- Annual recertification

Example:
"Onboarding: 4-hour security workshop covering OWASP Top 10, secure coding, company policies. Quiz required.
Ongoing: Quarterly security lunch & learns (1 hour), annual refresher course
Role-specific: Backend devs take API security course, frontend devs take XSS/CSRF course, DevOps takes cloud security course
Content: OWASP Top 10, secure coding, authentication, cryptography, incident response, HIPAA compliance
Provider: Mix of internal content and Pluralsight courses
Verification: Track completion in LMS, annual assessment required"

Security training: ___________
```

**Fills:** `docs/specs/security_spec.md` (Security Training section)

---

## Summary: What Gets Filled Out

After Phase 13 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Data Protection (advanced encryption specifications)
- Encryption (detailed encryption requirements, key management)
- Secrets Management (rotation policies, automation)
- Vulnerability Management (scanning tools, remediation SLAs, tracking)
- Penetration Testing (frequency, scope, providers, process)
- Security Training (onboarding, ongoing, role-specific, verification)

### `docs/specs/codebase_spec.md`
- Security (vulnerability scanning in CI/CD)

## Next Steps

After completing Phase 13 Q&A:

1. **Review advanced security controls with security team** - Confirm approach and tools
2. **Proceed to Phase 14** - Audit Logging (read `llm_qa_phase14_questions__t__.md`)
3. **Or implement advanced security** - Start with highest priority controls (encryption, vulnerability scanning)

**Note:** Phase 13 is the third of six secure/compliance phases (11-16). Advanced security requires ongoing investment in tools, training, and processes.
