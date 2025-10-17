# Phase 11: Threat Modeling Questions

## Overview

**Phase:** 11 (Threat Modeling)  
**When:** For secure Quality level  
**Duration:** 15-20 minutes  
**Questions:** 3 total  
**Outcome:** Threat model and security strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is required only for secure Quality level. It's the first of six secure/compliance phases (11-16).

## Topics Covered

- Threat identification (critical threats to application)
- Attack surfaces (entry points, vulnerabilities)
- Threat mitigations (controls, defenses)

## Question Templates

### Question 1: Threat Identification (Required for secure)

**Context:** Understanding potential threats helps you build appropriate defenses.

```
What are the main threats to your application?

Common threats:
- **Data breach**: Unauthorized access to sensitive data
  - Examples: Database compromise, API exploitation, insider threat
  
- **Account takeover**: Attackers gain access to user accounts
  - Examples: Credential stuffing, phishing, session hijacking
  
- **Denial of service**: Attackers make your app unavailable
  - Examples: DDoS, resource exhaustion, application-level DoS
  
- **Data tampering**: Attackers modify data
  - Examples: SQL injection, unauthorized updates, integrity violations
  
- **Privilege escalation**: Users gain unauthorized permissions
  - Examples: Authorization bypass, role manipulation, API abuse
  
- **Supply chain attacks**: Compromised dependencies
  - Examples: Malicious packages, compromised build pipeline

For your application, which threats are most critical?

Consider:
- What sensitive data do you handle?
- What would be the impact of each threat?
- What are the most likely attack vectors?

Example: "Healthcare app: Data breach (patient records) is critical, account takeover (admin accounts) is high risk, data tampering (medical records) is critical"

Critical threats: ___________
```

**Fills:** `docs/specs/security_spec.md` (Threat Modeling section), `docs/specs/technical_design_spec.md` (Security & Privacy section)

---

### Question 2: Attack Surfaces (Required for secure)

**Context:** Identifying attack surfaces helps you prioritize security efforts.

```
What are the entry points attackers could exploit?

Attack surfaces:
- **Web UI**: XSS, CSRF, clickjacking
  - Forms, file uploads, user-generated content
  
- **API endpoints**: Injection, broken auth, excessive data exposure
  - REST/GraphQL endpoints, webhooks, admin APIs
  
- **Database**: SQL injection, unauthorized access
  - Direct database access, query interfaces
  
- **File uploads**: Malicious files, path traversal
  - Image uploads, document uploads, profile pictures
  
- **Third-party integrations**: Compromised APIs, data leaks
  - OAuth providers, payment processors, analytics services
  
- **Infrastructure**: Misconfigured servers, exposed ports
  - Cloud services, containers, network configuration
  
- **Authentication**: Weak passwords, session management
  - Login forms, password reset, session cookies

For each attack surface, consider:
- How exposed is it? (public, authenticated, internal)
- What data can be accessed?
- What operations can be performed?

Example: "Web UI (forms, file uploads), REST API (all endpoints), PostgreSQL database, S3 file storage, Stripe integration, admin dashboard"

Attack surfaces: ___________
```

**Fills:** `docs/specs/security_spec.md` (Threat Modeling section)

---

### Question 3: Threat Mitigations (Required for secure)

**Context:** For each critical threat, define specific mitigations.

```
For each critical threat, what mitigations will you implement?

Mitigation strategies by threat:

**Data breach mitigations:**
- Encryption at rest and in transit
- Access controls (RBAC, least privilege)
- Audit logging (track all data access)
- Regular security audits and penetration testing
- Data minimization (collect only what you need)

**Account takeover mitigations:**
- MFA required for all users (especially admins)
- Rate limiting on login attempts
- Account lockout after failed attempts
- Suspicious activity detection
- Strong password requirements
- Session management (timeouts, secure cookies)

**Data tampering mitigations:**
- Input validation (prevent injection)
- Audit logs (detect unauthorized changes)
- Data integrity checks (checksums, signatures)
- Role-based permissions (limit who can modify data)
- Database constraints (enforce data rules)

**Denial of service mitigations:**
- Rate limiting (per-user, per-IP)
- Auto-scaling (handle traffic spikes)
- CDN (distribute load)
- Resource limits (prevent resource exhaustion)
- Monitoring and alerting (detect attacks early)

**Privilege escalation mitigations:**
- Principle of least privilege
- Regular permission audits
- Authorization checks on all operations
- Audit logging (track permission changes)

**Supply chain mitigations:**
- Dependency scanning (pip-audit, Snyk)
- Lockfiles with hashes (requirements.txt)
- Verify package signatures
- Regular dependency updates
- SBOM (Software Bill of Materials)

Example: 
"Data breach: Encryption at rest/transit, RBAC, comprehensive audit logging, annual pen test, data minimization
Account takeover: MFA for all users, rate limiting (5 attempts/min), account lockout (5 failures = 30 min), suspicious activity alerts
Data tampering: Input validation with Pydantic, audit logs for all changes, database constraints, role-based permissions"

Mitigations: ___________
```

**Fills:** `docs/specs/security_spec.md` (Threat Modeling section), `docs/specs/technical_design_spec.md` (Security & Privacy section)

---

## Summary: What Gets Filled Out

After Phase 11 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Threat Modeling (threats, attack surfaces, mitigations)

### `docs/specs/technical_design_spec.md`
- Security & Privacy (threat model overview and mitigations)

## Next Steps

After completing Phase 11 Q&A:

1. **Review threat model with developer and security team** - Confirm threats and mitigations
2. **Proceed to Phase 12** - Compliance Requirements (read `llm_qa_phase12_questions__t__.md`)
3. **Or implement threat mitigations** - Start with highest priority threats

**Note:** Phase 11 is the first of six secure/compliance phases (11-16). All six phases are required for secure Quality level.

## Threat Modeling Frameworks

For reference, common threat modeling frameworks:
- **STRIDE**: Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege
- **PASTA**: Process for Attack Simulation and Threat Analysis
- **VAST**: Visual, Agile, and Simple Threat modeling
- **Attack Trees**: Hierarchical diagrams of attack paths

You don't need to use a formal framework, but these can help structure your thinking about threats.
