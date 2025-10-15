# Security Specification

## Purpose
This specification defines security requirements and best practices for all projects. It serves as a checklist for development, deployment, and maintenance of secure applications.

**For implementation details**, see:
- [Auth Guide](../guides/web/web_auth_guide__t__.md)
- [Flask Auth Runbook](../runbooks/web/flask_auth_runbook__t__.md)
- [FastAPI Auth Runbook](../runbooks/web/fastapi_auth_runbook__t__.md)

## Scope
- Authentication requirements
- Authorization requirements
- Data protection
- Secrets management
- Monitoring and logging
- Incident response

---

## Authentication Requirements

### Password-Based Authentication

**If implementing password auth (not recommended - use OAuth instead):**

- [ ] **Password hashing:** Use bcrypt, scrypt, or Argon2 (never MD5/SHA1)
- [ ] **Minimum length:** 12 characters (or 8 with complexity requirements)
- [ ] **Complexity:** Mix of uppercase, lowercase, numbers, special characters
- [ ] **Common password check:** Block passwords from breach databases
- [ ] **Password strength meter:** Show real-time feedback in UI
- [ ] **Secure password reset:** Time-limited tokens, email verification
- [ ] **No password hints:** Don't store or display password hints

**Example (Python):**
```python
from werkzeug.security import generate_password_hash, check_password_hash

# Hash password
password_hash = generate_password_hash(password, method='scrypt')

# Verify password
is_valid = check_password_hash(password_hash, password)
```

---

### OAuth 2.0 / OpenID Connect (Recommended)

**For customer-facing applications:**

- [ ] **Use trusted providers:** Google, GitHub, Microsoft, Auth0
- [ ] **HTTPS only:** OAuth flows must use HTTPS
- [ ] **State parameter:** Prevent CSRF attacks in OAuth flow
- [ ] **Token validation:** Verify signature, expiry, audience
- [ ] **Scope limitation:** Request minimum necessary scopes
- [ ] **Redirect URI validation:** Whitelist exact redirect URIs

**Providers by use case:**
- **Google:** Most common, trusted by users
- **GitHub:** Developer tools, technical products
- **Microsoft:** Enterprise applications
- **Auth0/Supabase:** Multi-provider support, managed service

---

### Session Management

**For session-based authentication:**

- [ ] **Secure cookies:** `Secure`, `HttpOnly`, `SameSite=Lax` flags
- [ ] **Session timeout:** 30 minutes inactivity, 24 hours maximum
- [ ] **Session regeneration:** New session ID after login
- [ ] **Logout functionality:** Clear session on logout
- [ ] **Concurrent session limits:** Optional, based on requirements

**Example (Flask):**
```python
app.config.update(
    SESSION_COOKIE_SECURE=True,      # HTTPS only
    SESSION_COOKIE_HTTPONLY=True,    # No JavaScript access
    SESSION_COOKIE_SAMESITE='Lax',   # CSRF protection
    PERMANENT_SESSION_LIFETIME=86400  # 24 hours
)
```

---

### Multi-Factor Authentication (MFA)

**Required for:**
- [ ] Admin accounts (always)
- [ ] Accounts with sensitive data access
- [ ] Financial transactions
- [ ] Healthcare data

**Implementation options:**
- **TOTP (Time-based OTP):** Google Authenticator, Authy
- **SMS:** Less secure, but better than nothing
- **Email:** Backup method
- **Hardware keys:** Most secure (WebAuthn/FIDO2)

**Example (TOTP with pyotp):**
```python
import pyotp

# Generate secret
secret = pyotp.random_base32()

# Create provisioning URI for QR code
totp = pyotp.TOTP(secret)
uri = totp.provisioning_uri(name=user.email, issuer_name='Your App')

# Verify code
is_valid = totp.verify(user_code, valid_window=1)
```

---

## Authorization Requirements

### Role-Based Access Control (RBAC)

**Minimum roles:**
- [ ] **Admin:** Full access, user management
- [ ] **Editor/User:** Standard access, create/edit own resources
- [ ] **Viewer:** Read-only access

**Role hierarchy:**
```
Admin > Editor > Viewer
(Admin has all Editor permissions, Editor has all Viewer permissions)
```

**Implementation:**
```python
class Role(Enum):
    ADMIN = "admin"
    EDITOR = "editor"
    VIEWER = "viewer"

def has_role(user, required_role):
    hierarchy = {
        Role.ADMIN: [Role.ADMIN, Role.EDITOR, Role.VIEWER],
        Role.EDITOR: [Role.EDITOR, Role.VIEWER],
        Role.VIEWER: [Role.VIEWER]
    }
    return required_role in hierarchy.get(user.role, [])
```

---

### Permission-Based Authorization

**For complex requirements:**

- [ ] **Granular permissions:** e.g., `users:create`, `posts:delete`
- [ ] **Resource-level checks:** Can user edit *this specific* resource?
- [ ] **Default deny:** Explicit permission required for access
- [ ] **Least privilege:** Users get minimum necessary permissions

**Example:**
```python
def can_edit_post(user, post):
    # User is author OR user is admin
    return post.author_id == user.id or user.role == Role.ADMIN
```

---

## Data Protection

### Encryption at Rest

**Required for:**
- [ ] Passwords (hashed, not encrypted)
- [ ] API keys and secrets
- [ ] Personally Identifiable Information (PII)
- [ ] Payment information (use payment processor, don't store)
- [ ] Health information (HIPAA compliance)

**Database encryption:**
- Use database-level encryption (PostgreSQL, MySQL support)
- Or application-level encryption for sensitive fields

**Example (application-level):**
```python
from cryptography.fernet import Fernet

class User(db.Model):
    _ssn_encrypted = db.Column('ssn', db.LargeBinary)
    
    @property
    def ssn(self):
        if self._ssn_encrypted:
            f = Fernet(app.config['ENCRYPTION_KEY'])
            return f.decrypt(self._ssn_encrypted).decode()
        return None
    
    @ssn.setter
    def ssn(self, value):
        if value:
            f = Fernet(app.config['ENCRYPTION_KEY'])
            self._ssn_encrypted = f.encrypt(value.encode())
```

---

### Encryption in Transit

**HTTPS/TLS required:**
- [ ] **All production traffic:** No exceptions
- [ ] **TLS 1.2 or higher:** Disable older versions
- [ ] **Valid certificate:** Let's Encrypt (free) or commercial CA
- [ ] **HSTS header:** Force HTTPS for all requests
- [ ] **Redirect HTTP to HTTPS:** Automatic redirect

**Example (Flask with Talisman):**
```python
from flask_talisman import Talisman

Talisman(app, 
    force_https=True,
    strict_transport_security=True,
    strict_transport_security_max_age=31536000  # 1 year
)
```

---

### Data Minimization

**Collect only what you need:**
- [ ] **Purpose limitation:** Only collect data for specific purpose
- [ ] **Retention limits:** Delete data when no longer needed
- [ ] **Anonymization:** Remove PII when possible
- [ ] **Data export:** Allow users to export their data
- [ ] **Data deletion:** Allow users to delete their data

---

## Secrets Management

### Development

**Never commit secrets to git:**
- [ ] **Use .env files:** Add to `.gitignore`
- [ ] **Environment variables:** Load with `python-dotenv`
- [ ] **Example .env.example:** Provide template without secrets
- [ ] **Strong secret generation:** Use `secrets.token_urlsafe(32)`

**.gitignore:**
```
.env
.env.local
*.key
*.pem
secrets/
```

**Generate secrets:**
```python
import secrets

# Secret key (32 bytes = 256 bits)
secret_key = secrets.token_urlsafe(32)

# API key
api_key = secrets.token_urlsafe(32)

# JWT secret
jwt_secret = secrets.token_urlsafe(32)
```

---

### Production

**Use secret managers:**
- [ ] **AWS Secrets Manager:** For AWS deployments
- [ ] **Google Cloud Secret Manager:** For GCP deployments
- [ ] **Azure Key Vault:** For Azure deployments
- [ ] **HashiCorp Vault:** Self-hosted option
- [ ] **Doppler:** SaaS secret management

**Example (AWS Secrets Manager):**
```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# Usage
db_secrets = get_secret('prod/myapp/database')
DATABASE_URL = db_secrets['url']
```

---

### Secret Rotation

**Regular rotation:**
- [ ] **API keys:** Rotate every 90 days
- [ ] **Database passwords:** Rotate every 90 days
- [ ] **JWT secrets:** Rotate on security incidents
- [ ] **OAuth secrets:** Rotate on provider recommendation
- [ ] **Automated rotation:** Use secret manager features

---

## Input Validation & Sanitization

### SQL Injection Prevention

**Always use parameterized queries:**
- [ ] **ORM preferred:** SQLAlchemy, Django ORM
- [ ] **Parameterized queries:** Never string concatenation
- [ ] **Input validation:** Validate types and formats
- [ ] **Least privilege:** Database user has minimum permissions

**Bad:**
```python
# NEVER DO THIS
query = f"SELECT * FROM users WHERE email = '{email}'"
```

**Good:**
```python
# Use ORM
user = User.query.filter_by(email=email).first()

# Or parameterized query
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

---

### Cross-Site Scripting (XSS) Prevention

**Output encoding:**
- [ ] **Template auto-escaping:** Jinja2, Django templates (enabled by default)
- [ ] **Sanitize HTML:** Use bleach library if accepting HTML
- [ ] **Content Security Policy:** CSP headers
- [ ] **HttpOnly cookies:** Prevent JavaScript access to session cookies

**Example (sanitize HTML):**
```python
import bleach

allowed_tags = ['p', 'br', 'strong', 'em', 'a']
allowed_attributes = {'a': ['href', 'title']}

clean_html = bleach.clean(
    user_input,
    tags=allowed_tags,
    attributes=allowed_attributes,
    strip=True
)
```

---

### Cross-Site Request Forgery (CSRF) Prevention

**Required for state-changing operations:**
- [ ] **CSRF tokens:** Include in all forms
- [ ] **SameSite cookies:** `SameSite=Lax` or `Strict`
- [ ] **Verify origin:** Check Origin/Referer headers
- [ ] **HTMX integration:** Include CSRF token in headers

**Example (Flask-WTF):**
```python
from flask_wtf.csrf import CSRFProtect

csrf = CSRFProtect(app)

# In templates
# <form method="POST">
#   {{ csrf_token() }}
# </form>

# For HTMX
# <meta name="csrf-token" content="{{ csrf_token() }}">
```

---

## Rate Limiting

### Login Attempts

**Prevent brute force:**
- [ ] **5 attempts per IP per minute:** For login endpoints
- [ ] **Account lockout:** After 5 failed attempts (30 min lockout)
- [ ] **CAPTCHA:** After 3 failed attempts
- [ ] **Monitoring:** Alert on suspicious patterns

**Example (Flask-Limiter):**
```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=get_remote_address)

@app.route('/login', methods=['POST'])
@limiter.limit("5 per minute")
def login():
    # ... login logic
    pass
```

---

### API Endpoints

**Prevent abuse:**
- [ ] **Per-user limits:** 100 requests per minute
- [ ] **Per-IP limits:** 1000 requests per hour
- [ ] **Burst limits:** Allow short bursts
- [ ] **Rate limit headers:** Return X-RateLimit-* headers

---

## Monitoring & Logging

### Security Event Logging

**Log these events:**
- [ ] **Authentication:** Login, logout, failed attempts
- [ ] **Authorization:** Permission denied, role changes
- [ ] **Data access:** Sensitive data views/exports
- [ ] **Configuration:** Settings changes, user management
- [ ] **Errors:** Security-related errors

**Log format:**
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "event": "login",
  "user_id": 123,
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "status": "success",
  "details": {"method": "google_oauth"}
}
```

**Example (Python):**
```python
import logging
import json

security_logger = logging.getLogger('security')

def log_security_event(event, user=None, status='success', details=None):
    log_data = {
        'timestamp': datetime.utcnow().isoformat(),
        'event': event,
        'user_id': user.id if user else None,
        'ip_address': request.remote_addr,
        'user_agent': request.user_agent.string,
        'status': status,
        'details': details
    }
    security_logger.info(json.dumps(log_data))
```

---

### Monitoring Alerts

**Alert on:**
- [ ] **Multiple failed logins:** Same user or IP
- [ ] **Permission escalation:** Role changes
- [ ] **Unusual access patterns:** Off-hours, new locations
- [ ] **Data exports:** Large data exports
- [ ] **Configuration changes:** Critical settings modified

**Tools:**
- **Sentry:** Error tracking
- **Datadog:** Application monitoring
- **CloudWatch:** AWS monitoring
- **Grafana:** Custom dashboards

---

## Incident Response

### Security Breach Procedures

**Immediate actions:**
1. [ ] **Contain:** Disable affected accounts/services
2. [ ] **Assess:** Determine scope of breach
3. [ ] **Notify:** Inform affected users (GDPR: 72 hours)
4. [ ] **Remediate:** Fix vulnerability
5. [ ] **Document:** Record incident details
6. [ ] **Review:** Post-mortem and improvements

**Breach notification template:**
```
Subject: Security Incident Notification

We are writing to inform you of a security incident that may have affected your account.

What happened: [Brief description]
What data was affected: [Specific data types]
What we're doing: [Remediation steps]
What you should do: [User actions]

We take security seriously and apologize for any inconvenience.
```

---

### Password Reset Procedures

**If passwords compromised:**
1. [ ] **Force password reset:** All affected users
2. [ ] **Invalidate sessions:** Log out all users
3. [ ] **Rotate secrets:** API keys, JWT secrets
4. [ ] **Notify users:** Email with instructions
5. [ ] **Monitor:** Watch for suspicious activity

---

## Compliance

### GDPR (EU Users)

**Requirements:**
- [ ] **Consent:** Explicit consent for data collection
- [ ] **Right to access:** Users can export their data
- [ ] **Right to deletion:** Users can delete their data
- [ ] **Right to portability:** Data in machine-readable format
- [ ] **Breach notification:** Within 72 hours
- [ ] **Privacy policy:** Clear, accessible
- [ ] **Data Processing Agreement:** With third parties

**Example (data export):**
```python
@app.route('/account/export')
@login_required
def export_data():
    data = {
        'profile': current_user.to_dict(),
        'posts': [p.to_dict() for p in current_user.posts],
        'created_at': current_user.created_at.isoformat()
    }
    
    response = jsonify(data)
    response.headers['Content-Disposition'] = 'attachment; filename=my_data.json'
    return response
```

---

### HIPAA (Healthcare Data)

**If handling health information:**
- [ ] **Encryption:** At rest and in transit
- [ ] **Access controls:** Role-based, audit logs
- [ ] **Business Associate Agreement:** With vendors
- [ ] **Risk assessment:** Regular security audits
- [ ] **Breach notification:** HHS within 60 days

---

### PCI DSS (Payment Data)

**Recommendation: Don't store payment data**
- [ ] **Use payment processor:** Stripe, PayPal, Square
- [ ] **Tokenization:** Store tokens, not card numbers
- [ ] **Never log:** Card numbers, CVV codes
- [ ] **PCI compliance:** If you must store, get certified

---

## Security Checklist by Phase

### Development

- [ ] Use HTTPS in development (localhost with self-signed cert)
- [ ] Enable debug mode only in development
- [ ] Use .env files for secrets
- [ ] Never commit secrets to git
- [ ] Use ORM for database queries
- [ ] Enable CSRF protection
- [ ] Validate all inputs
- [ ] Use security linters (bandit for Python)

### Testing

- [ ] Test authentication flows
- [ ] Test authorization (role/permission checks)
- [ ] Test rate limiting
- [ ] Test CSRF protection
- [ ] Test XSS prevention
- [ ] Test SQL injection prevention
- [ ] Security scan (OWASP ZAP, Burp Suite)

### Staging

- [ ] HTTPS enabled
- [ ] Production-like secrets management
- [ ] Rate limiting enabled
- [ ] Audit logging enabled
- [ ] Error pages don't leak info
- [ ] Security headers configured
- [ ] Penetration testing

### Production

- [ ] HTTPS enforced (HSTS)
- [ ] Secrets in secret manager
- [ ] Database backups automated
- [ ] Monitoring and alerts configured
- [ ] Incident response plan documented
- [ ] Security audit completed
- [ ] Compliance requirements met
- [ ] Regular security updates scheduled

---

## Security Headers

**Required headers:**
```python
@app.after_request
def set_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['Content-Security-Policy'] = "default-src 'self'"
    return response
```

**Or use Flask-Talisman:**
```python
from flask_talisman import Talisman

Talisman(app)
```

---

## Tools & Resources

### Security Testing
- **OWASP ZAP:** Web application security scanner
- **Bandit:** Python security linter
- **Safety:** Check dependencies for vulnerabilities
- **Snyk:** Continuous security monitoring

### Monitoring
- **Sentry:** Error tracking
- **Datadog:** Application monitoring
- **CloudWatch:** AWS monitoring
- **Prometheus + Grafana:** Self-hosted monitoring

### Compliance
- **GDPR Checklist:** https://gdpr.eu/checklist/
- **HIPAA Compliance:** https://www.hhs.gov/hipaa/
- **PCI DSS:** https://www.pcisecuritystandards.org/

---

## Related Documentation

- [Auth Guide](../guides/web/web_auth_guide__t__.md) - Authentication patterns
- [Flask Auth Runbook](../runbooks/web/flask_auth_runbook__t__.md) - Flask implementation
- [FastAPI Auth Runbook](../runbooks/web/fastapi_auth_runbook__t__.md) - FastAPI implementation
- [Web UI Architecture](../guides/web/web_ui_architecture_guide__t__.md) - Security best practices
