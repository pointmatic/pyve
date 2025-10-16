# Reflex Authentication Runbook

## Purpose
Guide to implementing authentication and authorization in Reflex applications using pure Python. Covers session management, OAuth integration, and state-based permissions.

**For general auth concepts**, see [Auth Guide](../../guides/web/web_auth_guide__t__.md).

## Quick Start

### Installation

```bash
pip install reflex
pip install python-dotenv
pip install httpx  # For OAuth
```

---

## Basic Authentication

### Project Structure

```
myapp/
├── myapp/
│   ├── __init__.py
│   ├── myapp.py
│   ├── auth.py
│   ├── models.py
│   └── pages/
│       ├── login.py
│       ├── dashboard.py
│       └── admin.py
├── .env
└── rxconfig.py
```

### models.py

```python
from enum import Enum

class Role(str, Enum):
    ADMIN = "admin"
    USER = "user"
    VIEWER = "viewer"

class User:
    def __init__(self, id: int, email: str, name: str, role: Role):
        self.id = id
        self.email = email
        self.name = name
        self.role = role
    
    def has_role(self, required_role: Role) -> bool:
        """Check if user has at least this role"""
        hierarchy = {
            Role.ADMIN: [Role.ADMIN, Role.USER, Role.VIEWER],
            Role.USER: [Role.USER, Role.VIEWER],
            Role.VIEWER: [Role.VIEWER]
        }
        return required_role in hierarchy.get(self.role, [])
```

### auth.py

```python
import reflex as rx
from typing import Optional
from models import User, Role

# Simulated user database (replace with real database)
USERS_DB = {
    "admin@example.com": {
        "id": 1,
        "email": "admin@example.com",
        "name": "Admin User",
        "password": "admin123",  # In production: use hashed passwords
        "role": Role.ADMIN
    },
    "user@example.com": {
        "id": 2,
        "email": "user@example.com",
        "name": "Regular User",
        "password": "user123",
        "role": Role.USER
    }
}

class AuthState(rx.State):
    """Authentication state"""
    
    # Current user
    user: Optional[dict] = None
    is_authenticated: bool = False
    
    # Login form
    email: str = ""
    password: str = ""
    error_message: str = ""
    
    def login(self):
        """Handle login"""
        user_data = USERS_DB.get(self.email)
        
        if not user_data:
            self.error_message = "Invalid email or password"
            return
        
        if user_data["password"] != self.password:
            self.error_message = "Invalid email or password"
            return
        
        # Login successful
        self.user = {
            "id": user_data["id"],
            "email": user_data["email"],
            "name": user_data["name"],
            "role": user_data["role"]
        }
        self.is_authenticated = True
        self.error_message = ""
        self.password = ""  # Clear password
        
        # Redirect to dashboard
        return rx.redirect("/dashboard")
    
    def logout(self):
        """Handle logout"""
        self.user = None
        self.is_authenticated = False
        self.email = ""
        self.password = ""
        return rx.redirect("/")
    
    def check_auth(self):
        """Check if user is authenticated"""
        if not self.is_authenticated:
            return rx.redirect("/login")
    
    def has_role(self, required_role: Role) -> bool:
        """Check if current user has required role"""
        if not self.is_authenticated or not self.user:
            return False
        
        user_role = self.user.get("role")
        if not user_role:
            return False
        
        hierarchy = {
            Role.ADMIN: [Role.ADMIN, Role.USER, Role.VIEWER],
            Role.USER: [Role.USER, Role.VIEWER],
            Role.VIEWER: [Role.VIEWER]
        }
        return required_role in hierarchy.get(user_role, [])
    
    def require_role(self, required_role: Role):
        """Require specific role, redirect if not authorized"""
        if not self.has_role(required_role):
            return rx.redirect("/unauthorized")
```

### pages/login.py

```python
import reflex as rx
from ..auth import AuthState

def login_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.heading("Login", size="2xl"),
            
            rx.cond(
                AuthState.error_message != "",
                rx.callout(
                    AuthState.error_message,
                    icon="alert-circle",
                    color_scheme="red",
                ),
            ),
            
            rx.form(
                rx.vstack(
                    rx.input(
                        placeholder="Email",
                        type="email",
                        value=AuthState.email,
                        on_change=AuthState.set_email,
                        required=True,
                    ),
                    rx.input(
                        placeholder="Password",
                        type="password",
                        value=AuthState.password,
                        on_change=AuthState.set_password,
                        required=True,
                    ),
                    rx.button(
                        "Login",
                        type="submit",
                        width="100%",
                    ),
                    spacing="4",
                    width="100%",
                ),
                on_submit=AuthState.login,
                width="100%",
            ),
            
            spacing="6",
            width="400px",
            padding="2em",
        ),
        center_content=True,
        height="100vh",
    )
```

### pages/dashboard.py

```python
import reflex as rx
from ..auth import AuthState

def dashboard_page() -> rx.Component:
    return rx.fragment(
        AuthState.check_auth(),  # Redirect if not authenticated
        rx.container(
            rx.vstack(
                rx.heading(f"Welcome, {AuthState.user['name']}!", size="2xl"),
                
                rx.card(
                    rx.vstack(
                        rx.text(f"Email: {AuthState.user['email']}"),
                        rx.text(f"Role: {AuthState.user['role']}"),
                        spacing="2",
                    ),
                ),
                
                rx.hstack(
                    rx.cond(
                        AuthState.has_role("admin"),
                        rx.link(
                            rx.button("Admin Panel"),
                            href="/admin",
                        ),
                    ),
                    rx.button(
                        "Logout",
                        on_click=AuthState.logout,
                        color_scheme="red",
                    ),
                    spacing="4",
                ),
                
                spacing="6",
                padding="2em",
            ),
        ),
    )
```

### pages/admin.py

```python
import reflex as rx
from ..auth import AuthState
from ..models import Role

def admin_page() -> rx.Component:
    return rx.fragment(
        AuthState.check_auth(),
        AuthState.require_role(Role.ADMIN),  # Admin only
        rx.container(
            rx.vstack(
                rx.heading("Admin Panel", size="2xl"),
                rx.text("This page is only visible to administrators."),
                
                rx.button(
                    "Back to Dashboard",
                    on_click=lambda: rx.redirect("/dashboard"),
                ),
                
                spacing="6",
                padding="2em",
            ),
        ),
    )
```

### myapp.py

```python
import reflex as rx
from .pages import login, dashboard, admin

app = rx.App()

app.add_page(login.login_page, route="/login")
app.add_page(dashboard.dashboard_page, route="/dashboard")
app.add_page(admin.admin_page, route="/admin")

# Redirect root to login
@rx.page(route="/")
def index():
    return rx.redirect("/login")
```

---

## Database Integration

### With SQLAlchemy

```python
from sqlalchemy import create_engine, Column, Integer, String, Enum as SQLEnum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from werkzeug.security import generate_password_hash, check_password_hash

Base = declarative_base()
engine = create_engine("sqlite:///users.db")
SessionLocal = sessionmaker(bind=engine)

class UserModel(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True)
    email = Column(String, unique=True, nullable=False)
    name = Column(String)
    password_hash = Column(String, nullable=False)
    role = Column(SQLEnum(Role), default=Role.USER)

Base.metadata.create_all(engine)

class AuthState(rx.State):
    # ... previous state variables ...
    
    def login(self):
        """Login with database"""
        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(
                UserModel.email == self.email
            ).first()
            
            if not user:
                self.error_message = "Invalid email or password"
                return
            
            if not check_password_hash(user.password_hash, self.password):
                self.error_message = "Invalid email or password"
                return
            
            # Login successful
            self.user = {
                "id": user.id,
                "email": user.email,
                "name": user.name,
                "role": user.role.value
            }
            self.is_authenticated = True
            self.error_message = ""
            self.password = ""
            
            return rx.redirect("/dashboard")
        finally:
            db.close()
    
    def register(self, email: str, name: str, password: str):
        """Register new user"""
        db = SessionLocal()
        try:
            # Check if user exists
            existing = db.query(UserModel).filter(
                UserModel.email == email
            ).first()
            
            if existing:
                self.error_message = "Email already registered"
                return
            
            # Create user
            user = UserModel(
                email=email,
                name=name,
                password_hash=generate_password_hash(password),
                role=Role.USER
            )
            db.add(user)
            db.commit()
            
            return rx.redirect("/login")
        finally:
            db.close()
```

---

## OAuth with Google

### Installation

```bash
pip install httpx
```

### Implementation

```python
import httpx
import os
from urllib.parse import urlencode

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")
REDIRECT_URI = "http://localhost:3000/auth/google/callback"

class AuthState(rx.State):
    # ... previous state ...
    
    def login_with_google(self):
        """Redirect to Google OAuth"""
        params = {
            "client_id": GOOGLE_CLIENT_ID,
            "redirect_uri": REDIRECT_URI,
            "response_type": "code",
            "scope": "openid email profile",
        }
        auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"
        return rx.redirect(auth_url)
    
    async def handle_google_callback(self, code: str):
        """Handle Google OAuth callback"""
        # Exchange code for tokens
        async with httpx.AsyncClient() as client:
            token_response = await client.post(
                "https://oauth2.googleapis.com/token",
                data={
                    "code": code,
                    "client_id": GOOGLE_CLIENT_ID,
                    "client_secret": GOOGLE_CLIENT_SECRET,
                    "redirect_uri": REDIRECT_URI,
                    "grant_type": "authorization_code",
                }
            )
            
            tokens = token_response.json()
            access_token = tokens.get("access_token")
            
            # Get user info
            user_response = await client.get(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": f"Bearer {access_token}"}
            )
            
            user_info = user_response.json()
            
            # Create or update user in database
            db = SessionLocal()
            try:
                user = db.query(UserModel).filter(
                    UserModel.email == user_info["email"]
                ).first()
                
                if not user:
                    user = UserModel(
                        email=user_info["email"],
                        name=user_info.get("name"),
                        password_hash=generate_password_hash(os.urandom(32).hex()),
                        role=Role.USER
                    )
                    db.add(user)
                    db.commit()
                
                # Login user
                self.user = {
                    "id": user.id,
                    "email": user.email,
                    "name": user.name,
                    "role": user.role.value
                }
                self.is_authenticated = True
                
                return rx.redirect("/dashboard")
            finally:
                db.close()

# Add callback page
@rx.page(route="/auth/google/callback")
def google_callback():
    return rx.fragment(
        rx.script("""
            const urlParams = new URLSearchParams(window.location.search);
            const code = urlParams.get('code');
            if (code) {
                // Call backend to handle code
                fetch('/api/auth/google', {
                    method: 'POST',
                    body: JSON.stringify({code: code}),
                    headers: {'Content-Type': 'application/json'}
                });
            }
        """)
    )
```

---

## Protected Routes

### Route Guard Component

```python
def require_auth(component):
    """Wrapper to require authentication"""
    def protected_component():
        return rx.cond(
            AuthState.is_authenticated,
            component(),
            rx.redirect("/login")
        )
    return protected_component

def require_role(role: Role):
    """Wrapper to require specific role"""
    def decorator(component):
        def protected_component():
            return rx.cond(
                AuthState.has_role(role),
                component(),
                rx.redirect("/unauthorized")
            )
        return protected_component
    return decorator

# Usage
@require_auth
def protected_page():
    return rx.text("This is protected")

@require_role(Role.ADMIN)
def admin_only_page():
    return rx.text("Admin only")
```

---

## Session Persistence

### Using Browser Storage

```python
class AuthState(rx.State):
    def on_load(self):
        """Load session from localStorage"""
        return rx.call_script(
            """
            const user = localStorage.getItem('user');
            if (user) {
                return JSON.parse(user);
            }
            """,
            callback=self.restore_session
        )
    
    def restore_session(self, user_data):
        """Restore user session"""
        if user_data:
            self.user = user_data
            self.is_authenticated = True
    
    def login(self):
        # ... login logic ...
        
        # Save to localStorage
        return rx.call_script(
            f"localStorage.setItem('user', JSON.stringify({self.user}))"
        )
    
    def logout(self):
        self.user = None
        self.is_authenticated = False
        return rx.call_script("localStorage.removeItem('user')")
```

---

## User Management

### CRUD Operations

```python
class UserManagementState(rx.State):
    users: list[dict] = []
    
    def load_users(self):
        """Load all users (admin only)"""
        if not AuthState.has_role(Role.ADMIN):
            return
        
        db = SessionLocal()
        try:
            users = db.query(UserModel).all()
            self.users = [
                {
                    "id": u.id,
                    "email": u.email,
                    "name": u.name,
                    "role": u.role.value
                }
                for u in users
            ]
        finally:
            db.close()
    
    def update_user_role(self, user_id: int, new_role: str):
        """Update user role"""
        if not AuthState.has_role(Role.ADMIN):
            return
        
        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.id == user_id).first()
            if user:
                user.role = Role(new_role)
                db.commit()
                self.load_users()  # Refresh list
        finally:
            db.close()
    
    def delete_user(self, user_id: int):
        """Delete user"""
        if not AuthState.has_role(Role.ADMIN):
            return
        
        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.id == user_id).first()
            if user:
                db.delete(user)
                db.commit()
                self.load_users()
        finally:
            db.close()

def user_management_page():
    return rx.fragment(
        AuthState.check_auth(),
        AuthState.require_role(Role.ADMIN),
        rx.container(
            rx.vstack(
                rx.heading("User Management", size="2xl"),
                
                rx.button(
                    "Refresh",
                    on_click=UserManagementState.load_users,
                ),
                
                rx.table.root(
                    rx.table.header(
                        rx.table.row(
                            rx.table.column_header_cell("Email"),
                            rx.table.column_header_cell("Name"),
                            rx.table.column_header_cell("Role"),
                            rx.table.column_header_cell("Actions"),
                        ),
                    ),
                    rx.table.body(
                        rx.foreach(
                            UserManagementState.users,
                            lambda user: rx.table.row(
                                rx.table.cell(user["email"]),
                                rx.table.cell(user["name"]),
                                rx.table.cell(user["role"]),
                                rx.table.cell(
                                    rx.button(
                                        "Delete",
                                        on_click=lambda: UserManagementState.delete_user(user["id"]),
                                        color_scheme="red",
                                        size="sm",
                                    ),
                                ),
                            ),
                        ),
                    ),
                ),
                
                spacing="6",
                padding="2em",
            ),
        ),
    )
```

---

## Security Best Practices

### Password Hashing

```python
from werkzeug.security import generate_password_hash, check_password_hash

# Hash password
password_hash = generate_password_hash(password, method='scrypt')

# Verify password
is_valid = check_password_hash(password_hash, password)
```

### Environment Variables

```python
# .env
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
DATABASE_URL=sqlite:///users.db
SECRET_KEY=your-secret-key
```

### HTTPS in Production

```bash
# Run with HTTPS
reflex run --env production --loglevel info
```

---

## Testing

```python
import pytest
from reflex.testing import AppHarness

def test_login():
    with AppHarness(app) as harness:
        # Navigate to login
        harness.goto("/login")
        
        # Fill form
        harness.fill("email", "user@example.com")
        harness.fill("password", "user123")
        
        # Submit
        harness.click("button[type=submit]")
        
        # Check redirect
        assert harness.url == "/dashboard"

def test_protected_route():
    with AppHarness(app) as harness:
        # Try to access protected route
        harness.goto("/dashboard")
        
        # Should redirect to login
        assert harness.url == "/login"
```

---

## Related Documentation

- [Auth Guide](../../guides/web/web_auth_guide__t__.md) - General auth concepts
- [Flask Auth](flask_auth_runbook__t__.md) - For web apps
- [FastAPI Auth](fastapi_auth_runbook__t__.md) - For APIs
- [Reflex Documentation](https://reflex.dev/docs/) - Official docs
