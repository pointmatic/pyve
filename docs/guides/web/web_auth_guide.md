# Authentication & Authorization Guide

## Purpose
This guide covers authentication (who you are) and authorization (what you can do) for Python web applications. It focuses on practical patterns for small-to-moderate scale applications where security is critical.

**For framework-specific implementations**, see the auth runbooks:
- [Flask Auth](../../runbooks/web/flask_auth_runbook__t__.md) - Recommended for CRUD apps
- [FastAPI Auth](../../runbooks/web/fastapi_auth_runbook__t__.md) - For APIs
- [Reflex Auth](../../runbooks/web/reflex_auth_runbook__t__.md) - Pure Python
- [Streamlit Auth](../../runbooks/web/streamlit_runbook__t__.md#authentication) - Internal tools

**For security requirements**, see [Security Spec](../specs/security_spec__t__.md).

## Scope
- Authentication strategies (session, token, OAuth)
- Authorization patterns (RBAC, permissions)
- Security best practices
- Secrets management
- Production considerations

---

## Authentication Strategies

### Session-Based Authentication

**How it works:** Server stores session data, client gets session ID in cookie

```
User logs in → Server creates session → Cookie with session ID
Next request → Cookie sent → Server looks up session → User identified
```

**Best for:**
- Traditional web apps
- Server-side rendering
- Flask + HTMX, Django
- Internal tools

**Pros:**
- Simple to implement
- Server controls everything
- Easy to revoke (delete session)
- Works without JavaScript

**Cons:**
- Server must store sessions
- Harder to scale horizontally
- CSRF protection required

**Example (Flask):**
```python
from flask import Flask, session, redirect, url_for
from flask_login import LoginManager, login_user, logout_user

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY')

login_manager = LoginManager()
login_manager.init_app(app)

@app.route('/login', methods=['POST'])
def login():
    user = authenticate(request.form['email'], request.form['password'])
    if user:
        login_user(user, remember=True)  # Creates session
        return redirect(url_for('dashboard'))
    return 'Invalid credentials', 401

@app.route('/logout')
def logout():
    logout_user()  # Destroys session
    return redirect(url_for('home'))
```

---

### Token-Based Authentication (JWT)

**How it works:** Server issues signed token, client stores it, sends with each request

```
User logs in → Server creates JWT → Client stores token
Next request → Token in header → Server verifies signature → User identified
```

**Best for:**
- APIs
- Mobile apps
- Single-page applications (SPAs)
- Microservices

**Pros:**
- Stateless (no server storage)
- Scales horizontally
- Works across domains
- Mobile-friendly

**Cons:**
- Can't revoke easily (until expiry)
- Token size (sent with every request)
- XSS vulnerability if stored in localStorage

**Example (FastAPI):**
```python
from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from datetime import datetime, timedelta

app = FastAPI()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

SECRET_KEY = os.getenv('JWT_SECRET_KEY')
ALGORITHM = "HS256"

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

@app.post("/token")
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate(form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token = create_access_token(
        data={"sub": user.email},
        expires_delta=timedelta(hours=24)
    )
    return {"access_token": access_token, "token_type": "bearer"}

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401)
        return get_user_by_email(email)
    except JWTError:
        raise HTTPException(status_code=401)

@app.get("/users/me")
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user
```

**Token refresh pattern:**
```python
# Issue two tokens: short-lived access + long-lived refresh
def create_tokens(user):
    access_token = create_access_token(
        data={"sub": user.email},
        expires_delta=timedelta(minutes=15)  # Short-lived
    )
    refresh_token = create_access_token(
        data={"sub": user.email, "type": "refresh"},
        expires_delta=timedelta(days=30)  # Long-lived
    )
    return access_token, refresh_token

@app.post("/token/refresh")
def refresh_token(refresh_token: str):
    payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401)
    
    new_access_token = create_access_token(data={"sub": payload["sub"]})
    return {"access_token": new_access_token}
```

---

### OAuth 2.0 / OpenID Connect

**How it works:** Delegate authentication to trusted provider (Google, GitHub, etc.)

```
User clicks "Login with Google" → Redirect to Google → User approves
→ Google redirects back with code → Exchange code for token → User info
```

**Best for:**
- Customer-facing apps
- When you don't want to manage passwords
- Need social login
- Want built-in MFA

**Pros:**
- No password management
- Users trust providers
- Built-in MFA (if user enables)
- Reduced liability

**Cons:**
- Dependency on external service
- More complex flow
- User must have provider account

**Providers:**
- **Google** - Most common, trusted
- **GitHub** - Developer tools
- **Microsoft** - Enterprise apps
- **Auth0** - Managed auth service (supports multiple providers)

**Example (Flask + Google):**
```python
from authlib.integrations.flask_client import OAuth

oauth = OAuth(app)

google = oauth.register(
    name='google',
    client_id=os.getenv('GOOGLE_CLIENT_ID'),
    client_secret=os.getenv('GOOGLE_CLIENT_SECRET'),
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

@app.route('/login/google')
def login_google():
    redirect_uri = url_for('authorize_google', _external=True)
    return google.authorize_redirect(redirect_uri)

@app.route('/authorize/google')
def authorize_google():
    token = google.authorize_access_token()
    user_info = token['userinfo']
    
    # Get or create user
    user = User.query.filter_by(email=user_info['email']).first()
    if not user:
        user = User(
            email=user_info['email'],
            name=user_info['name'],
            google_id=user_info['sub']
        )
        db.session.add(user)
        db.session.commit()
    
    login_user(user)
    return redirect(url_for('dashboard'))
```

---

### Passwordless Authentication

**Magic Links:**
```python
# User enters email → Send link with token → Click link → Logged in

@app.route('/login/magic-link', methods=['POST'])
def send_magic_link():
    email = request.form['email']
    user = User.query.filter_by(email=email).first()
    
    if user:
        token = create_magic_link_token(user)
        send_email(
            to=email,
            subject='Login to App',
            body=f'Click here to login: {url_for("verify_magic_link", token=token, _external=True)}'
        )
    
    return 'Check your email for login link'

@app.route('/login/verify/<token>')
def verify_magic_link(token):
    user = verify_magic_link_token(token)
    if user:
        login_user(user)
        return redirect(url_for('dashboard'))
    return 'Invalid or expired link', 401
```

**WebAuthn (Biometric):**
- Fingerprint, Face ID, security keys
- Most secure option
- Requires HTTPS
- Browser support varies

---

## Authorization Patterns

### Role-Based Access Control (RBAC)

**Concept:** Users have roles, roles have permissions

```
User → Role → Permissions
Alice → Admin → [create, read, update, delete]
Bob → Editor → [create, read, update]
Carol → Viewer → [read]
```

**Best for:**
- Most applications
- Clear hierarchy
- Simple to understand
- Easy to implement

**Example (Flask):**
```python
from enum import Enum
from functools import wraps

class Role(Enum):
    ADMIN = "admin"
    EDITOR = "editor"
    VIEWER = "viewer"

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True)
    role = db.Column(db.Enum(Role), default=Role.VIEWER)
    
    def has_role(self, role):
        role_hierarchy = {
            Role.ADMIN: [Role.ADMIN, Role.EDITOR, Role.VIEWER],
            Role.EDITOR: [Role.EDITOR, Role.VIEWER],
            Role.VIEWER: [Role.VIEWER]
        }
        return role in role_hierarchy.get(self.role, [])

def require_role(role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not current_user.is_authenticated:
                return redirect(url_for('login'))
            if not current_user.has_role(role):
                return 'Forbidden', 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

@app.route('/admin/users')
@require_role(Role.ADMIN)
def admin_users():
    return render_template('admin/users.html')

@app.route('/posts/create')
@require_role(Role.EDITOR)
def create_post():
    return render_template('posts/create.html')
```

---

### Permission-Based Authorization

**Concept:** Check specific permissions, not roles

```
User → Permissions (directly or via roles)
Alice → [posts:create, posts:delete, users:manage]
Bob → [posts:create, posts:update]
```

**Best for:**
- Complex permission requirements
- Fine-grained control
- When roles aren't enough

**Example:**
```python
class Permission(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True)  # e.g., "posts:create"

class User(db.Model):
    permissions = db.relationship('Permission', secondary='user_permissions')
    
    def has_permission(self, permission_name):
        return any(p.name == permission_name for p in self.permissions)

def require_permission(permission):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not current_user.has_permission(permission):
                return 'Forbidden', 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

@app.route('/posts/<int:post_id>/delete', methods=['DELETE'])
@require_permission('posts:delete')
def delete_post(post_id):
    post = Post.query.get_or_404(post_id)
    db.session.delete(post)
    db.session.commit()
    return '', 204
```

---

### Resource-Level Authorization

**Concept:** Check if user can access specific resource

```
Can Alice edit Post #123?
→ Check: Is Alice the author? OR Is Alice an admin?
```

**Example:**
```python
class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    author_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    author = db.relationship('User')
    
    def can_edit(self, user):
        return user.id == self.author_id or user.has_role(Role.ADMIN)
    
    def can_delete(self, user):
        return user.has_role(Role.ADMIN)

@app.route('/posts/<int:post_id>/edit')
@login_required
def edit_post(post_id):
    post = Post.query.get_or_404(post_id)
    if not post.can_edit(current_user):
        return 'Forbidden', 403
    return render_template('posts/edit.html', post=post)
```

---

## Security Best Practices

### Password Security

**Never store plain text passwords:**
```python
from werkzeug.security import generate_password_hash, check_password_hash

class User(db.Model):
    password_hash = db.Column(db.String(255))
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
```

**Password requirements:**
- Minimum 12 characters (or 8 with complexity)
- Mix of uppercase, lowercase, numbers, symbols
- No common passwords (use library like `zxcvbn`)
- Password strength meter in UI

**Example validation:**
```python
import re

def validate_password(password):
    errors = []
    
    if len(password) < 12:
        errors.append("Password must be at least 12 characters")
    
    if not re.search(r'[A-Z]', password):
        errors.append("Password must contain uppercase letter")
    
    if not re.search(r'[a-z]', password):
        errors.append("Password must contain lowercase letter")
    
    if not re.search(r'\d', password):
        errors.append("Password must contain number")
    
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        errors.append("Password must contain special character")
    
    # Check against common passwords
    with open('common_passwords.txt') as f:
        if password.lower() in f.read().lower():
            errors.append("Password is too common")
    
    return errors
```

---

### Multi-Factor Authentication (MFA)

**TOTP (Time-based One-Time Password):**
```python
import pyotp

class User(db.Model):
    mfa_secret = db.Column(db.String(32))
    mfa_enabled = db.Column(db.Boolean, default=False)
    
    def enable_mfa(self):
        self.mfa_secret = pyotp.random_base32()
        self.mfa_enabled = True
        return pyotp.totp.TOTP(self.mfa_secret).provisioning_uri(
            name=self.email,
            issuer_name='Your App'
        )
    
    def verify_mfa(self, token):
        if not self.mfa_enabled:
            return True
        totp = pyotp.TOTP(self.mfa_secret)
        return totp.verify(token, valid_window=1)

@app.route('/login', methods=['POST'])
def login():
    user = authenticate(request.form['email'], request.form['password'])
    if not user:
        return 'Invalid credentials', 401
    
    if user.mfa_enabled:
        session['pending_user_id'] = user.id
        return redirect(url_for('verify_mfa'))
    
    login_user(user)
    return redirect(url_for('dashboard'))

@app.route('/verify-mfa', methods=['GET', 'POST'])
def verify_mfa():
    if request.method == 'POST':
        user_id = session.get('pending_user_id')
        user = User.query.get(user_id)
        
        if user.verify_mfa(request.form['token']):
            session.pop('pending_user_id')
            login_user(user)
            return redirect(url_for('dashboard'))
        
        return 'Invalid code', 401
    
    return render_template('verify_mfa.html')
```

---

### Rate Limiting

**Prevent brute force attacks:**
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/login', methods=['POST'])
@limiter.limit("5 per minute")  # Max 5 login attempts per minute
def login():
    # ... login logic
    pass
```

**Track failed attempts:**
```python
class User(db.Model):
    failed_login_attempts = db.Column(db.Integer, default=0)
    locked_until = db.Column(db.DateTime)
    
    def is_locked(self):
        if self.locked_until and self.locked_until > datetime.utcnow():
            return True
        return False
    
    def record_failed_login(self):
        self.failed_login_attempts += 1
        if self.failed_login_attempts >= 5:
            self.locked_until = datetime.utcnow() + timedelta(minutes=30)
        db.session.commit()
    
    def record_successful_login(self):
        self.failed_login_attempts = 0
        self.locked_until = None
        db.session.commit()
```

---

### CSRF Protection

**Required for session-based auth:**
```python
from flask_wtf.csrf import CSRFProtect

csrf = CSRFProtect(app)

# In templates
# <form method="POST">
#   {{ csrf_token() }}
#   ...
# </form>

# For HTMX requests
# <div hx-post="/users" hx-headers='{"X-CSRFToken": "{{ csrf_token() }}"}'>
```

---

### Session Security

**Configuration:**
```python
app.config.update(
    SESSION_COOKIE_SECURE=True,      # HTTPS only
    SESSION_COOKIE_HTTPONLY=True,    # No JavaScript access
    SESSION_COOKIE_SAMESITE='Lax',   # CSRF protection
    PERMANENT_SESSION_LIFETIME=timedelta(hours=24)
)
```

**Session timeout:**
```python
from datetime import datetime

@app.before_request
def check_session_timeout():
    if current_user.is_authenticated:
        last_activity = session.get('last_activity')
        if last_activity:
            if datetime.utcnow() - last_activity > timedelta(minutes=30):
                logout_user()
                return redirect(url_for('login', timeout=True))
        session['last_activity'] = datetime.utcnow()
```

---

## Secrets Management

### Environment Variables

**Never commit secrets to git:**
```python
# .env (add to .gitignore)
SECRET_KEY=your-secret-key-here
DATABASE_URL=postgresql://user:pass@localhost/db
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
JWT_SECRET_KEY=your-jwt-secret

# Load in app
from dotenv import load_dotenv
load_dotenv()

app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
```

**Generate strong secrets:**
```python
import secrets

# Generate secret key
secret_key = secrets.token_urlsafe(32)
print(f"SECRET_KEY={secret_key}")

# Generate JWT secret
jwt_secret = secrets.token_urlsafe(32)
print(f"JWT_SECRET_KEY={jwt_secret}")
```

---

### Secret Managers (Production)

**AWS Secrets Manager:**
```python
import boto3
from botocore.exceptions import ClientError

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='us-east-1')
    try:
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except ClientError as e:
        raise e

# Usage
secrets = get_secret('prod/myapp/database')
DATABASE_URL = secrets['url']
```

**Google Cloud Secret Manager:**
```python
from google.cloud import secretmanager

def get_secret(project_id, secret_id, version_id="latest"):
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode('UTF-8')

# Usage
DATABASE_URL = get_secret('my-project', 'database-url')
```

---

## Production Considerations

### HTTPS/TLS

**Required for production:**
- All authentication must use HTTPS
- Use Let's Encrypt for free certificates
- Redirect HTTP to HTTPS
- Set HSTS header

```python
from flask_talisman import Talisman

Talisman(app, force_https=True)
```

---

### Audit Logging

**Track security events:**
```python
class AuditLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    action = db.Column(db.String(50))  # login, logout, password_change, etc.
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(255))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    details = db.Column(db.JSON)

def log_security_event(user, action, details=None):
    log = AuditLog(
        user_id=user.id if user else None,
        action=action,
        ip_address=request.remote_addr,
        user_agent=request.user_agent.string,
        details=details
    )
    db.session.add(log)
    db.session.commit()

# Usage
@app.route('/login', methods=['POST'])
def login():
    user = authenticate(request.form['email'], request.form['password'])
    if user:
        login_user(user)
        log_security_event(user, 'login', {'method': 'password'})
        return redirect(url_for('dashboard'))
    
    log_security_event(None, 'failed_login', {'email': request.form['email']})
    return 'Invalid credentials', 401
```

---

### Compliance

**GDPR Considerations:**
- User consent for data collection
- Right to access data
- Right to delete data
- Data portability
- Breach notification (72 hours)

**Example:**
```python
@app.route('/account/export')
@login_required
def export_data():
    # Export all user data
    data = {
        'profile': current_user.to_dict(),
        'posts': [p.to_dict() for p in current_user.posts],
        'comments': [c.to_dict() for c in current_user.comments]
    }
    return jsonify(data)

@app.route('/account/delete', methods=['POST'])
@login_required
def delete_account():
    # Anonymize or delete user data
    user = current_user
    user.email = f"deleted_{user.id}@example.com"
    user.name = "Deleted User"
    user.is_active = False
    db.session.commit()
    logout_user()
    return redirect(url_for('home'))
```

---

## Decision Framework

### By Use Case

**Internal Tool (10-100 users):**
- **Auth:** Simple password or Google OAuth
- **Authz:** Basic roles (admin, user)
- **Security:** Standard practices
- **Example:** Flask-Login + session

**Customer-Facing App (100-10,000 users):**
- **Auth:** OAuth (Google, GitHub) + optional password
- **Authz:** RBAC with permissions
- **Security:** MFA for admins, rate limiting, audit logs
- **Example:** Authlib + OAuth + Flask-Login

**SaaS Product (10,000+ users):**
- **Auth:** Managed service (Auth0, Supabase)
- **Authz:** Fine-grained permissions, multi-tenant
- **Security:** MFA, compliance, SOC 2
- **Example:** Auth0 + custom authorization

### By Security Requirements

**Low (Internal tools, non-sensitive data):**
- Simple password auth
- Basic roles
- HTTPS

**Medium (Customer data, PII):**
- OAuth or strong passwords
- RBAC
- MFA for admins
- Rate limiting
- Audit logs

**High (Financial, healthcare, critical systems):**
- Managed auth service
- MFA required
- Fine-grained permissions
- Comprehensive audit logs
- Compliance certifications
- Regular security audits

---

## Recommended Stacks

### Flask + HTMX (CRUD Apps)
```
Auth: Google OAuth (Authlib) + Flask-Login
Authz: RBAC with decorators
Security: Flask-WTF (CSRF), Flask-Limiter
Secrets: python-dotenv + AWS Secrets Manager
```

### FastAPI (APIs)
```
Auth: JWT tokens (python-jose)
Authz: Permission-based with dependencies
Security: slowapi (rate limiting)
Secrets: python-dotenv + environment variables
```

### Reflex (Pure Python)
```
Auth: Built-in auth or custom OAuth
Authz: State-based permissions
Security: HTTPS, secure cookies
Secrets: environment variables
```

---

## Resources

### Libraries
- **Authlib** - OAuth client/server (Flask, FastAPI)
- **Flask-Login** - Session management
- **python-jose** - JWT tokens
- **pyotp** - TOTP (MFA)
- **Flask-Limiter** / **slowapi** - Rate limiting
- **Flask-WTF** - CSRF protection

### Services
- **Auth0** - Managed authentication
- **Supabase Auth** - Open-source auth
- **AWS Cognito** - AWS-native auth
- **Google Identity** - Google OAuth

### Tools
- **1Password** / **Bitwarden** - Password management
- **Have I Been Pwned** - Check compromised passwords
- **OWASP ZAP** - Security testing

---

## Related Documentation

- [Flask Auth Runbook](../../runbooks/web/flask_auth_runbook__t__.md) - Google OAuth + HTMX
- [FastAPI Auth Runbook](../../runbooks/web/fastapi_auth_runbook__t__.md) - JWT + OAuth
- [Security Spec](../specs/security_spec__t__.md) - Production security checklist
- [Web UI Architecture](web_ui_architecture_guide__t__.md) - Security best practices
