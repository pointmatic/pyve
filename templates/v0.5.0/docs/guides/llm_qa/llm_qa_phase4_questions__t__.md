# Phase 4: Security Basics Questions

## Overview

**Phase:** 4 (Security Basics)  
**When:** Before deploying to production  
**Duration:** 15-20 minutes  
**Questions:** 5 total  
**Outcome:** Basic security controls defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Secrets management (development and production)
- Data encryption (at rest, in transit, application-level)
- Input validation and sanitization
- Rate limiting and abuse prevention
- Basic security auditing

## Question Templates

### Question 1: Secrets Management (Required for production/secure)

**Context:** Proper secrets management prevents credential leaks and unauthorized access.

```
How will you manage sensitive data (API keys, database passwords, etc.)?

Development:
- **Environment variables**: Use .env files (gitignored)
- **Example file**: Provide .env.example template
- **Never commit**: Secrets never go in git

Production:
- **Platform secrets**: Fly.io secrets, Heroku config vars, AWS Secrets Manager
- **Secret manager**: Dedicated service (AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault)
- **Rotation**: How often to rotate secrets (90 days recommended)

Example: "Development: .env files (gitignored), .env.example in repo. Production: Fly.io secrets, rotate quarterly"

Secrets management: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Security section), `docs/specs/technical_design_spec.md` (Configuration section), `docs/specs/security_spec.md` (Secrets Management section)

---

### Question 2: Data Encryption (Required for production/secure)

**Context:** Encryption protects sensitive data from unauthorized access.

```
How will you protect sensitive data?

Encryption needs:
- **In transit**: HTTPS/TLS for all connections (required for production)
- **At rest**: Encrypt database and file storage
- **Application-level**: Encrypt sensitive fields (passwords, PII)

Implementation:
- **TLS/HTTPS**: Let's Encrypt, AWS ACM, platform-provided
- **Database encryption**: PostgreSQL encryption, AWS RDS encryption
- **Password hashing**: bcrypt, scrypt, Argon2 (never plain text)
- **Field encryption**: Fernet, AES-256 for PII

Example: "HTTPS for all traffic (Fly.io provides TLS), PostgreSQL encryption at rest, bcrypt for password hashing"

Encryption: ___________
```

**Fills:** `docs/specs/security_spec.md` (Data Protection section, Encryption section)

---

### Question 3: Input Validation (Required for production/secure)

**Context:** Input validation prevents injection attacks and data corruption.

```
How will you prevent malicious input (SQL injection, XSS, etc.)?

Strategies:
- **Framework protection**: Use framework's built-in validation (FastAPI, Django)
- **Input sanitization**: Clean user input before processing
- **Parameterized queries**: Prevent SQL injection (use ORM)
- **Output encoding**: Prevent XSS attacks
- **CSRF protection**: Use CSRF tokens for forms
- **File upload validation**: Check file types, sizes, scan for malware

Example: "Pydantic for input validation, SQLAlchemy parameterized queries, CSRF tokens in forms, file upload size limits"

Input validation: ___________
```

**Fills:** `docs/specs/security_spec.md` (Input Validation & Sanitization section)

---

### Question 4: Rate Limiting (Required for production/secure)

**Context:** Rate limiting prevents brute force attacks and API abuse.

```
How will you prevent abuse and brute force attacks?

Rate limiting needs:
- **Login endpoints**: Limit failed login attempts (e.g., 5 per minute)
- **API endpoints**: Limit requests per user (e.g., 100 per minute)
- **Account lockout**: Lock account after failed attempts (e.g., 5 failures = 30 min lockout)
- **CAPTCHA**: Add CAPTCHA after multiple failures

Implementation:
- **Libraries**: Flask-Limiter, slowapi (FastAPI), Django-ratelimit
- **Platform**: Cloudflare, AWS WAF, API Gateway
- **Storage**: Redis for rate limit counters

Example: "5 login attempts per IP per minute, 100 API requests per user per minute, account lockout after 5 failures, rate limiting with slowapi + Redis"

Rate limiting: ___________
```

**Fills:** `docs/specs/security_spec.md` (Rate Limiting & DDoS Protection section)

---

### Question 5: Security Auditing (Required for production/secure)

**Context:** Regular security audits identify vulnerabilities before attackers do.

```
How will you audit and maintain security?

Auditing needs:
- **Dependency scanning**: Check for vulnerable packages (pip-audit, Snyk)
- **Code scanning**: Static analysis (Bandit for Python, SonarQube)
- **Container scanning**: Scan Docker images (Trivy, Snyk)
- **Frequency**: How often to scan (every commit, daily, weekly)

Example: "Run pip-audit in CI on every commit, Bandit for Python code analysis, Trivy for container scanning"

Security auditing: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Security section), `docs/specs/security_spec.md` (Vulnerability Management section)

---

## Summary: What Gets Filled Out

After Phase 4 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- Security (secrets, audits)

### `docs/specs/technical_design_spec.md`
- Configuration (secrets management)
- Security & Privacy (encryption, input validation)

### `docs/specs/security_spec.md`
- Secrets Management (development, production, rotation)
- Data Protection (encryption at rest, in transit, application-level)
- Input Validation & Sanitization (SQL injection, XSS, CSRF prevention)
- Rate Limiting & DDoS Protection (login, API, account lockout)
- Vulnerability Management (dependency scanning, code scanning, container scanning)

## Next Steps

After completing Phase 4 Q&A:

1. **Review security specs with developer** - Confirm security approach
2. **Proceed to Phase 5** - Operations (read `llm_qa_phase5_questions__t__.md`)
3. **Or implement security basics** - Set up secrets management, encryption, input validation, rate limiting

**Note:** Phase 4 covers fundamental security controls. Advanced security topics (threat modeling, compliance, pen testing) are covered in Phases 11-16 for secure Quality level.
