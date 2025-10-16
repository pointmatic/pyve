# Flask Authentication Runbook

## Purpose
Complete guide to implementing authentication and authorization in Flask applications, with focus on Google OAuth, session management, and HTMX security patterns. Perfect for CRUD applications.

**For general auth concepts**, see [Auth Guide](../../guides/web/web_auth_guide__t__.md).

## Quick Start

### Installation

```bash
# requirements.in
Flask>=3.0.0
Flask-Login>=0.6.3          # Session management
Flask-WTF>=1.2.1            # CSRF protection
Flask-SQLAlchemy>=3.1.1     # Database ORM
Authlib>=1.3.0              # OAuth (Google, GitHub, etc.)
python-dotenv>=1.0.0        # Environment variables
email-validator>=2.1.0      # Email validation
```

```bash
pip-compile requirements.in
pip install -r requirements.txt
```

---

## Google OAuth Setup

### Step 1: Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing
3. Enable Google+ API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
5. Configure OAuth consent screen:
   - User Type: External (for public apps)
   - App name, support email, developer contact
   - Scopes: `openid`, `email`, `profile`
6. Create OAuth Client ID:
   - Application type: Web application
   - Authorized redirect URIs:
     - Development: `http://localhost:5000/authorize/google`
     - Production: `https://yourdomain.com/authorize/google`
7. Save Client ID and Client Secret

### Step 2: Environment Variables

```bash
# .env (add to .gitignore!)
SECRET_KEY=your-secret-key-here-use-secrets-token-urlsafe-32
DATABASE_URL=sqlite:///app.db
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Generate secret key:
# python -c "import secrets; print(secrets.token_urlsafe(32))"
```

---

## Complete Flask App with Google OAuth

### Project Structure

```
myapp/
├── app.py
├── models.py
├── auth.py
├── decorators.py
├── templates/
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   └── users/
│       ├── list.html
│       └── _user_row.html
├── .env
├── requirements.in
└── requirements.txt
```

### models.py

```python
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
from enum import Enum

db = SQLAlchemy()

class Role(Enum):
    ADMIN = "admin"
    EDITOR = "editor"
    VIEWER = "viewer"

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    name = db.Column(db.String(100))
    google_id = db.Column(db.String(100), unique=True, index=True)
    role = db.Column(db.Enum(Role), default=Role.VIEWER, nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    def __repr__(self):
        return f'<User {self.email}>'
    
    def has_role(self, role):
        """Check if user has at least this role (hierarchical)"""
        role_hierarchy = {
            Role.ADMIN: [Role.ADMIN, Role.EDITOR, Role.VIEWER],
            Role.EDITOR: [Role.EDITOR, Role.VIEWER],
            Role.VIEWER: [Role.VIEWER]
        }
        return role in role_hierarchy.get(self.role, [])
    
    def can_edit_user(self, user_id):
        """Check if user can edit another user"""
        if self.role == Role.ADMIN:
            return True
        return self.id == user_id
    
    def can_delete_user(self, user_id):
        """Only admins can delete users"""
        return self.role == Role.ADMIN and self.id != user_id
    
    def to_dict(self):
        return {
            'id': self.id,
            'email': self.email,
            'name': self.name,
            'role': self.role.value,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_login': self.last_login.isoformat() if self.last_login else None
        }

class AuditLog(db.Model):
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    action = db.Column(db.String(50), nullable=False)
    resource_type = db.Column(db.String(50))
    resource_id = db.Column(db.Integer)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(255))
    details = db.Column(db.JSON)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    user = db.relationship('User', backref='audit_logs')
    
    def __repr__(self):
        return f'<AuditLog {self.action} by {self.user_id}>'
```

### auth.py

```python
from flask import Blueprint, redirect, url_for, session, flash, request, render_template
from flask_login import LoginManager, login_user, logout_user, current_user
from authlib.integrations.flask_client import OAuth
from models import db, User, AuditLog, Role
from datetime import datetime
import os

auth_bp = Blueprint('auth', __name__)

# Initialize Flask-Login
login_manager = LoginManager()

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@login_manager.unauthorized_handler
def unauthorized():
    flash('Please log in to access this page.', 'warning')
    return redirect(url_for('auth.login'))

# Initialize OAuth
oauth = OAuth()

def init_oauth(app):
    oauth.init_app(app)
    
    oauth.register(
        name='google',
        client_id=os.getenv('GOOGLE_CLIENT_ID'),
        client_secret=os.getenv('GOOGLE_CLIENT_SECRET'),
        server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
        client_kwargs={
            'scope': 'openid email profile'
        }
    )

def log_security_event(action, user=None, details=None):
    """Log security-related events"""
    log = AuditLog(
        user_id=user.id if user else None,
        action=action,
        ip_address=request.remote_addr,
        user_agent=request.user_agent.string[:255],
        details=details
    )
    db.session.add(log)
    db.session.commit()

@auth_bp.route('/login')
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return render_template('login.html')

@auth_bp.route('/login/google')
def login_google():
    redirect_uri = url_for('auth.authorize_google', _external=True)
    return oauth.google.authorize_redirect(redirect_uri)

@auth_bp.route('/authorize/google')
def authorize_google():
    try:
        token = oauth.google.authorize_access_token()
        user_info = token.get('userinfo')
        
        if not user_info:
            flash('Failed to get user information from Google.', 'danger')
            return redirect(url_for('auth.login'))
        
        # Get or create user
        user = User.query.filter_by(email=user_info['email']).first()
        
        if not user:
            # Create new user
            user = User(
                email=user_info['email'],
                name=user_info.get('name'),
                google_id=user_info['sub'],
                role=Role.VIEWER  # Default role for new users
            )
            db.session.add(user)
            db.session.commit()
            
            log_security_event('user_registered', user, {
                'method': 'google_oauth',
                'email': user.email
            })
            
            flash(f'Welcome {user.name}! Your account has been created.', 'success')
        else:
            # Update existing user
            if not user.google_id:
                user.google_id = user_info['sub']
            user.name = user_info.get('name', user.name)
            user.last_login = datetime.utcnow()
            db.session.commit()
            
            log_security_event('login', user, {'method': 'google_oauth'})
        
        # Check if user is active
        if not user.is_active:
            flash('Your account has been deactivated. Please contact support.', 'danger')
            return redirect(url_for('auth.login'))
        
        # Log user in
        login_user(user, remember=True)
        
        # Redirect to next page or dashboard
        next_page = session.get('next')
        if next_page:
            session.pop('next')
            return redirect(next_page)
        
        return redirect(url_for('dashboard'))
        
    except Exception as e:
        flash('Authentication failed. Please try again.', 'danger')
        log_security_event('login_failed', None, {
            'method': 'google_oauth',
            'error': str(e)
        })
        return redirect(url_for('auth.login'))

@auth_bp.route('/logout')
def logout():
    if current_user.is_authenticated:
        log_security_event('logout', current_user)
    logout_user()
    flash('You have been logged out.', 'info')
    return redirect(url_for('auth.login'))

@auth_bp.before_app_request
def check_session_timeout():
    """Check for session timeout"""
    if current_user.is_authenticated:
        last_activity = session.get('last_activity')
        if last_activity:
            # 30 minute timeout
            if (datetime.utcnow() - datetime.fromisoformat(last_activity)).seconds > 1800:
                logout_user()
                flash('Your session has expired. Please log in again.', 'warning')
                return redirect(url_for('auth.login'))
        
        session['last_activity'] = datetime.utcnow().isoformat()
```

### decorators.py

```python
from functools import wraps
from flask import abort, flash, redirect, url_for
from flask_login import current_user
from models import Role

def require_role(role):
    """Decorator to require specific role"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not current_user.is_authenticated:
                flash('Please log in to access this page.', 'warning')
                return redirect(url_for('auth.login'))
            
            if not current_user.has_role(role):
                flash('You do not have permission to access this page.', 'danger')
                abort(403)
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def admin_required(f):
    """Shortcut for admin-only routes"""
    return require_role(Role.ADMIN)(f)

def editor_required(f):
    """Shortcut for editor+ routes"""
    return require_role(Role.EDITOR)(f)
```

### app.py

```python
from flask import Flask, render_template, request, jsonify
from flask_login import login_required, current_user
from flask_wtf.csrf import CSRFProtect
from dotenv import load_dotenv
import os

from models import db, User, Role
from auth import auth_bp, login_manager, init_oauth, log_security_event
from decorators import admin_required, editor_required

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Session configuration
app.config['SESSION_COOKIE_SECURE'] = True  # HTTPS only in production
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
app.config['PERMANENT_SESSION_LIFETIME'] = 86400  # 24 hours

# Initialize extensions
db.init_app(app)
login_manager.init_app(app)
init_oauth(app)
csrf = CSRFProtect(app)

# Register blueprints
app.register_blueprint(auth_bp, url_prefix='/auth')

# Create tables
with app.app_context():
    db.create_all()

@app.route('/')
def index():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return redirect(url_for('auth.login'))

@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html')

# User management routes (CRUD example)

@app.route('/users')
@login_required
def list_users():
    users = User.query.order_by(User.created_at.desc()).all()
    return render_template('users/list.html', users=users)

@app.route('/users/<int:user_id>')
@login_required
def get_user(user_id):
    user = User.query.get_or_404(user_id)
    return render_template('users/_user_row.html', user=user)

@app.route('/users/<int:user_id>/edit', methods=['GET'])
@login_required
def edit_user_form(user_id):
    if not current_user.can_edit_user(user_id):
        return 'Forbidden', 403
    
    user = User.query.get_or_404(user_id)
    return render_template('users/_edit_form.html', user=user)

@app.route('/users/<int:user_id>', methods=['PUT'])
@login_required
def update_user(user_id):
    if not current_user.can_edit_user(user_id):
        return 'Forbidden', 403
    
    user = User.query.get_or_404(user_id)
    
    # Update fields
    user.name = request.form.get('name', user.name)
    
    # Only admins can change roles
    if current_user.role == Role.ADMIN:
        new_role = request.form.get('role')
        if new_role in [r.value for r in Role]:
            user.role = Role(new_role)
    
    db.session.commit()
    
    log_security_event('user_updated', current_user, {
        'target_user_id': user_id,
        'fields': ['name', 'role']
    })
    
    return render_template('users/_user_row.html', user=user)

@app.route('/users/<int:user_id>', methods=['DELETE'])
@admin_required
def delete_user(user_id):
    if not current_user.can_delete_user(user_id):
        return 'Cannot delete yourself', 403
    
    user = User.query.get_or_404(user_id)
    
    log_security_event('user_deleted', current_user, {
        'target_user_id': user_id,
        'target_email': user.email
    })
    
    db.session.delete(user)
    db.session.commit()
    
    return '', 204

@app.route('/admin/audit-logs')
@admin_required
def audit_logs():
    from models import AuditLog
    logs = AuditLog.query.order_by(AuditLog.timestamp.desc()).limit(100).all()
    return render_template('admin/audit_logs.html', logs=logs)

# Error handlers

@app.errorhandler(403)
def forbidden(e):
    return render_template('errors/403.html'), 403

@app.errorhandler(404)
def not_found(e):
    return render_template('errors/404.html'), 404

if __name__ == '__main__':
    app.run(debug=True)
```

---

## HTMX Security Patterns

### CSRF Protection for HTMX

**Include CSRF token in HTMX requests:**

```html
<!-- base.html -->
<head>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
    <script>
        // Add CSRF token to all HTMX requests
        document.body.addEventListener('htmx:configRequest', (event) => {
            event.detail.headers['X-CSRFToken'] = document.querySelector('meta[name="csrf-token"]').content;
        });
    </script>
</head>
```

**Alternative: Include in hx-headers:**

```html
<button 
    hx-delete="/users/{{ user.id }}"
    hx-headers='{"X-CSRFToken": "{{ csrf_token() }}"}'
    hx-confirm="Are you sure you want to delete this user?">
    Delete
</button>
```

### Protected HTMX Endpoints

```python
@app.route('/users/<int:user_id>/toggle-active', methods=['POST'])
@admin_required
def toggle_user_active(user_id):
    """HTMX endpoint to toggle user active status"""
    user = User.query.get_or_404(user_id)
    user.is_active = not user.is_active
    db.session.commit()
    
    log_security_event('user_status_changed', current_user, {
        'target_user_id': user_id,
        'new_status': user.is_active
    })
    
    # Return updated row
    return render_template('users/_user_row.html', user=user)
```

### Authentication State in Partials

```html
<!-- users/_user_row.html -->
<tr id="user-{{ user.id }}">
    <td>{{ user.name }}</td>
    <td>{{ user.email }}</td>
    <td>{{ user.role.value }}</td>
    <td>
        {% if current_user.can_edit_user(user.id) %}
            <button 
                hx-get="/users/{{ user.id }}/edit"
                hx-target="#user-{{ user.id }}"
                hx-swap="outerHTML">
                Edit
            </button>
        {% endif %}
        
        {% if current_user.can_delete_user(user.id) %}
            <button 
                hx-delete="/users/{{ user.id }}"
                hx-target="#user-{{ user.id }}"
                hx-swap="outerHTML swap:1s"
                hx-confirm="Delete {{ user.name }}?">
                Delete
            </button>
        {% endif %}
    </td>
</tr>
```

---

## Templates

### login.html

```html
{% extends "base.html" %}

{% block content %}
<div class="login-container">
    <h1>Login</h1>
    
    {% with messages = get_flashed_messages(with_categories=true) %}
        {% if messages %}
            {% for category, message in messages %}
                <div class="alert alert-{{ category }}">{{ message }}</div>
            {% endfor %}
        {% endif %}
    {% endwith %}
    
    <div class="login-options">
        <a href="{{ url_for('auth.login_google') }}" class="btn btn-google">
            <img src="/static/google-icon.svg" alt="Google">
            Sign in with Google
        </a>
    </div>
    
    <p class="help-text">
        By signing in, you agree to our Terms of Service and Privacy Policy.
    </p>
</div>
{% endblock %}
```

### dashboard.html

```html
{% extends "base.html" %}

{% block content %}
<div class="dashboard">
    <h1>Welcome, {{ current_user.name }}!</h1>
    
    <div class="user-info">
        <p><strong>Email:</strong> {{ current_user.email }}</p>
        <p><strong>Role:</strong> {{ current_user.role.value }}</p>
        <p><strong>Last Login:</strong> {{ current_user.last_login.strftime('%Y-%m-%d %H:%M') if current_user.last_login else 'First login' }}</p>
    </div>
    
    <div class="quick-links">
        <a href="{{ url_for('list_users') }}" class="btn">Manage Users</a>
        
        {% if current_user.role.value == 'admin' %}
            <a href="{{ url_for('audit_logs') }}" class="btn">Audit Logs</a>
        {% endif %}
        
        <a href="{{ url_for('auth.logout') }}" class="btn btn-secondary">Logout</a>
    </div>
</div>
{% endblock %}
```

### users/list.html

```html
{% extends "base.html" %}

{% block content %}
<div class="users-list">
    <h1>Users</h1>
    
    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            {% for user in users %}
                {% include 'users/_user_row.html' %}
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
```

---

## Production Deployment

### Environment Variables

```bash
# Production .env
SECRET_KEY=<strong-random-key>
DATABASE_URL=postgresql://user:pass@host:5432/dbname
GOOGLE_CLIENT_ID=<production-client-id>
GOOGLE_CLIENT_SECRET=<production-client-secret>
FLASK_ENV=production
```

### HTTPS Configuration

```python
# Force HTTPS in production
from flask_talisman import Talisman

if not app.debug:
    Talisman(app, force_https=True)
```

### Database Migration

```bash
# Install Flask-Migrate
pip install Flask-Migrate

# Initialize migrations
flask db init
flask db migrate -m "Initial migration"
flask db upgrade
```

### First Admin User

```python
# create_admin.py
from app import app, db
from models import User, Role

with app.app_context():
    admin = User(
        email='admin@example.com',
        name='Admin User',
        role=Role.ADMIN,
        is_active=True
    )
    db.session.add(admin)
    db.session.commit()
    print(f"Admin user created: {admin.email}")
```

---

## Testing

### Test Authentication

```python
import pytest
from app import app, db
from models import User, Role

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['WTF_CSRF_ENABLED'] = False
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
        yield client
        with app.app_context():
            db.drop_all()

def test_login_required(client):
    """Test that dashboard requires login"""
    response = client.get('/dashboard')
    assert response.status_code == 302
    assert '/auth/login' in response.location

def test_role_required(client):
    """Test that admin routes require admin role"""
    # Create viewer user
    with app.app_context():
        user = User(email='viewer@test.com', role=Role.VIEWER)
        db.session.add(user)
        db.session.commit()
    
    # Login as viewer
    with client.session_transaction() as sess:
        sess['_user_id'] = '1'
    
    # Try to access admin route
    response = client.get('/admin/audit-logs')
    assert response.status_code == 403
```

---

## Security Checklist

### Pre-Production

- [ ] HTTPS enabled (Let's Encrypt)
- [ ] Strong SECRET_KEY (32+ bytes)
- [ ] CSRF protection enabled
- [ ] Session cookies: Secure, HttpOnly, SameSite
- [ ] Google OAuth redirect URIs configured for production domain
- [ ] Database credentials in environment variables
- [ ] Rate limiting enabled (Flask-Limiter)
- [ ] Audit logging implemented
- [ ] Error pages don't leak information
- [ ] SQL injection prevention (use ORM, parameterized queries)
- [ ] XSS prevention (Jinja2 auto-escaping enabled)

### Post-Launch

- [ ] Monitor audit logs regularly
- [ ] Review user roles and permissions
- [ ] Test backup and restore procedures
- [ ] Set up security alerts (failed logins, permission changes)
- [ ] Regular dependency updates
- [ ] Security headers (Flask-Talisman)
- [ ] GDPR compliance (data export, deletion)

---

## Common Issues

### Issue: OAuth redirect mismatch

**Error:** `redirect_uri_mismatch`

**Solution:** Ensure redirect URI in Google Cloud Console exactly matches:
```python
url_for('auth.authorize_google', _external=True)
# Must match: http://localhost:5000/authorize/google (dev)
# Or: https://yourdomain.com/authorize/google (prod)
```

### Issue: CSRF token missing

**Error:** `400 Bad Request: The CSRF token is missing`

**Solution:** Include CSRF token in HTMX requests (see HTMX Security Patterns above)

### Issue: Session not persisting

**Solution:** Check SECRET_KEY is set and consistent across restarts

---

## Related Documentation

- [Auth Guide](../../guides/web/web_auth_guide__t__.md) - General auth concepts
- [FastAPI Auth](fastapi_auth_runbook__t__.md) - For APIs
- [Security Spec](../../specs/security_spec__t__.md) - Security requirements
- [Flask Documentation](https://flask.palletsprojects.com/) - Official Flask docs
