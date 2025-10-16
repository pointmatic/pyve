# Phase 14: Audit Logging Questions

## Overview

**Phase:** 14 (Audit Logging)  
**When:** For secure Quality level  
**Duration:** 10-15 minutes  
**Questions:** 2 total  
**Outcome:** Comprehensive audit logging strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is required only for secure Quality level. It's the fourth of six secure/compliance phases (11-16). This builds on basic logging from Phase 5 (Operations).

## Topics Covered

- Audit log requirements (events to log, log format, immutability)
- Audit log retention (retention period, storage, access, review)

## Question Templates

### Question 1: Audit Log Requirements (Required for secure)

**Context:** Audit logs provide a tamper-proof record of security-relevant events.

```
What events will you log in your audit logs?

Events to log:

**Authentication events:**
- Login attempts (success and failure)
- Logout events
- Password changes
- Password reset requests
- MFA enrollment and verification
- Session creation and termination
- Account lockouts

**Authorization events:**
- Permission changes (role assignments, permission grants)
- Access denials (unauthorized access attempts)
- Privilege escalation attempts
- API key creation and revocation

**Data access events:**
- Sensitive data access (PII, PHI, financial data)
- Data exports (CSV downloads, API bulk exports)
- Data modifications (create, update, delete)
- Data deletions (especially for compliance)

**Administrative events:**
- User account creation and deletion
- Configuration changes (system settings, security policies)
- Security control changes (firewall rules, encryption settings)
- Audit log access (who viewed audit logs)

**Security events:**
- Failed authorization attempts
- Suspicious activity detection
- Rate limit violations
- Security scan results
- Vulnerability detections

Log format:
- **Structured logs**: JSON format (recommended)
- **Required fields**:
  - Timestamp (ISO 8601 with timezone)
  - Event type (login, data_access, permission_change)
  - Actor (user ID, service account, API key)
  - Action (create, read, update, delete)
  - Resource (what was accessed/modified)
  - Result (success, failure, denied)
  - IP address
  - User agent
  - Request ID (for correlation)
  - Additional context (before/after values for changes)

Log immutability:
- **Write-once storage**: Logs cannot be modified or deleted
- **Cryptographic signing**: Sign logs to detect tampering
- **Separate storage**: Store audit logs separately from application logs
- **Access controls**: Restrict who can access audit logs

Example:
"Log all authentication events (login, logout, password changes, MFA)
Log all permission changes and access denials
Log all access to patient health records (HIPAA requirement)
Log all data exports and deletions
Log all admin actions (user creation, config changes)
Format: JSON with timestamp, event_type, user_id, action, resource, result, ip_address, user_agent, request_id
Immutability: AWS CloudWatch Logs with log group retention policy, cannot delete or modify logs
Cryptographic signing: Sign logs with HMAC for tamper detection"

Audit log requirements: ___________
```

**Fills:** `docs/specs/security_spec.md` (Audit Logging section), `docs/specs/codebase_spec.md` (Observability section)

---

### Question 2: Audit Log Retention (Required for secure)

**Context:** Proper retention ensures logs are available for investigations and compliance.

```
How will you retain and manage audit logs?

Retention period:
- **Compliance-driven**: Based on regulatory requirements
  - HIPAA: 6 years minimum
  - GDPR: Varies by purpose (typically 1-7 years)
  - SOC 2: 1 year minimum (for Type II)
  - PCI DSS: 1 year minimum, 3 months immediately available
  
- **Risk-based**: Based on your security needs
  - High-risk systems: 7+ years
  - Standard systems: 1-3 years
  - Low-risk systems: 90 days minimum

Storage:
- **Primary storage**: Hot storage for recent logs (e.g., 90 days)
  - AWS CloudWatch Logs, Azure Monitor, GCP Cloud Logging
  - Fast access, higher cost
  
- **Archive storage**: Cold storage for older logs (e.g., 90 days - 7 years)
  - AWS S3 Glacier, Azure Archive Storage, GCP Coldline
  - Slower access, lower cost
  
- **Backup**: Separate backup of audit logs
  - Different region or provider
  - Protect against primary storage failure

Access controls:
- **Who can access**: Security team, compliance team, auditors only
- **Access logging**: Log all access to audit logs (meta-logging)
- **Read-only**: No modification or deletion allowed
- **MFA required**: Require MFA for audit log access

Log review:
- **Automated monitoring**: Alert on suspicious patterns
  - Multiple failed logins
  - Unusual data access patterns
  - Permission changes
  - After-hours access
  
- **Manual review**: Regular review by security team
  - Weekly: Review high-priority alerts
  - Monthly: Sample review of all logs
  - Quarterly: Comprehensive audit log review
  
- **Compliance review**: Review for compliance audits
  - SOC 2: Auditor reviews logs
  - HIPAA: Annual review required
  - Internal audits: Quarterly or annual

Log search and analysis:
- **Search tools**: Elasticsearch, Splunk, Datadog, CloudWatch Insights
- **Query capabilities**: Search by user, event type, time range, resource
- **Export capabilities**: Export logs for investigations or audits

Example:
"Retention: 7 years (HIPAA requirement for healthcare data)
Storage: CloudWatch Logs for 90 days (hot), S3 Glacier for 90 days - 7 years (cold)
Backup: Replicate to separate AWS region
Access: Security team and compliance team only, MFA required, all access logged
Review: Automated alerts for suspicious activity, weekly security team review, monthly sampling, quarterly comprehensive review
Search: CloudWatch Insights for queries, can export to S3 for investigations
Cost: ~$500/month for hot storage, ~$50/month for cold storage"

Audit log retention: ___________
```

**Fills:** `docs/specs/security_spec.md` (Audit Logging section), `docs/specs/codebase_spec.md` (Observability section)

---

## Summary: What Gets Filled Out

After Phase 14 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Audit Logging (events to log, log format, immutability, retention period, storage, access controls, review process)

### `docs/specs/codebase_spec.md`
- Observability (audit logging implementation, tools)

## Next Steps

After completing Phase 14 Q&A:

1. **Review audit logging requirements with security and compliance teams** - Confirm events and retention
2. **Proceed to Phase 15** - Incident Response (read `llm_qa_phase15_questions__t__.md`)
3. **Or implement audit logging** - Set up audit log infrastructure, implement event logging

**Note:** Phase 14 is the fourth of six secure/compliance phases (11-16). Audit logging is critical for compliance (HIPAA, SOC 2, PCI DSS) and security investigations.

## Audit Logging Best Practices

- **Log before and after**: For data changes, log both old and new values
- **Don't log secrets**: Never log passwords, API keys, or tokens
- **Don't log PII unnecessarily**: Minimize PII in logs (use user IDs, not names/emails)
- **Centralize logs**: Send all audit logs to a central system
- **Separate from app logs**: Keep audit logs separate from application logs
- **Test log integrity**: Regularly verify logs haven't been tampered with
- **Plan for scale**: Audit logs can be large; plan storage and costs accordingly
