# Streamlit Operations Runbook

## Overview

Streamlit is a Python framework for building data apps and dashboards with minimal code. Write only Python, get instant UI.

**Key features:**
- Pure Python (no HTML/CSS/JS needed)
- Instant hot-reload
- Rich component library
- Great for data visualization
- Active community

**Best for:** Data apps, dashboards, ML demos, rapid prototyping

---

## Installation

```bash
# Install Streamlit
pip install streamlit

# Verify installation
streamlit hello

# Create first app
echo 'import streamlit as st
st.title("Hello Streamlit!")
st.write("Welcome to your first app")' > app.py

# Run app
streamlit run app.py
```

**Access:** http://localhost:8501

---

## Basic Concepts

### Script Re-runs

Streamlit re-runs your entire script on every interaction:
- User changes widget → script re-runs top to bottom
- Use `st.session_state` to persist data between runs
- Use `@st.cache_data` to cache expensive computations

### Execution Model

```python
import streamlit as st

# This runs on every interaction
st.title("My App")

# Widget creates a variable
name = st.text_input("Your name")

# Use the variable
st.write(f"Hello {name}!")
```

---

## Components

### Text Elements

```python
import streamlit as st

# Headers
st.title("Main Title")
st.header("Header")
st.subheader("Subheader")

# Text
st.text("Fixed-width text")
st.write("Markdown **bold** and *italic*")
st.markdown("# Markdown heading")
st.caption("Small caption text")

# Code
st.code("print('Hello')", language="python")

# LaTeX
st.latex(r"\sum_{i=1}^{n} x_i")
```

### Data Display

```python
import pandas as pd
import numpy as np

# DataFrame
df = pd.DataFrame({
    'col1': [1, 2, 3],
    'col2': [4, 5, 6]
})

st.dataframe(df)  # Interactive table
st.table(df)  # Static table

# Metrics
st.metric("Revenue", "$1.2M", "+12%")

# JSON
st.json({'key': 'value'})
```

### Charts

```python
# Line chart
st.line_chart(df)

# Bar chart
st.bar_chart(df)

# Area chart
st.area_chart(df)

# Map
map_data = pd.DataFrame({
    'lat': [37.76, 37.77],
    'lon': [-122.4, -122.41]
})
st.map(map_data)

# Plotly
import plotly.express as px
fig = px.scatter(df, x='col1', y='col2')
st.plotly_chart(fig)

# Matplotlib
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([1, 2, 3])
st.pyplot(fig)
```

### Input Widgets

```python
# Text input
name = st.text_input("Name", value="John")
text = st.text_area("Description", height=100)

# Number input
age = st.number_input("Age", min_value=0, max_value=120, value=25)
rating = st.slider("Rating", 0, 10, 5)

# Select
option = st.selectbox("Choose", ["A", "B", "C"])
options = st.multiselect("Choose multiple", ["A", "B", "C"])

# Radio
choice = st.radio("Pick one", ["Option 1", "Option 2"])

# Checkbox
agree = st.checkbox("I agree")

# Date/Time
date = st.date_input("Date")
time = st.time_input("Time")

# File upload
file = st.file_uploader("Upload file", type=['csv', 'txt'])

# Button
if st.button("Click me"):
    st.write("Button clicked!")

# Download button
st.download_button("Download", data="file content", file_name="file.txt")
```

---

## State Management

### Session State

```python
import streamlit as st

# Initialize state
if 'count' not in st.session_state:
    st.session_state.count = 0

# Increment function
def increment():
    st.session_state.count += 1

# Display and button
st.write(f"Count: {st.session_state.count}")
st.button("Increment", on_click=increment)
```

### Callbacks

```python
def handle_change():
    st.session_state.result = st.session_state.input_value * 2

st.number_input(
    "Enter number",
    key="input_value",
    on_change=handle_change
)

if 'result' in st.session_state:
    st.write(f"Result: {st.session_state.result}")
```

---

## Layouts

### Columns

```python
col1, col2, col3 = st.columns(3)

with col1:
    st.metric("Metric 1", "100")

with col2:
    st.metric("Metric 2", "200")

with col3:
    st.metric("Metric 3", "300")

# Unequal columns
col1, col2 = st.columns([2, 1])  # 2:1 ratio
```

### Sidebar

```python
# Sidebar elements
st.sidebar.title("Filters")
category = st.sidebar.selectbox("Category", ["All", "A", "B"])
date_range = st.sidebar.date_input("Date Range")

# Main content
st.title("Dashboard")
st.write(f"Showing: {category}")
```

### Tabs

```python
tab1, tab2, tab3 = st.tabs(["Overview", "Details", "Settings"])

with tab1:
    st.write("Overview content")

with tab2:
    st.write("Details content")

with tab3:
    st.write("Settings content")
```

### Expander

```python
with st.expander("Show more"):
    st.write("Hidden content")
    st.image("image.png")
```

### Container

```python
container = st.container()
container.write("This is inside a container")

# Add to container later
container.write("Added later")
```

---

## Forms

```python
with st.form("my_form"):
    st.write("User Registration")
    
    name = st.text_input("Name")
    email = st.text_input("Email")
    age = st.number_input("Age", min_value=0)
    
    # Form submit button
    submitted = st.form_submit_button("Submit")
    
    if submitted:
        if not name or not email:
            st.error("All fields required")
        else:
            st.success(f"Registered {name}!")
            # Save to database
```

---

## Caching

### Cache Data

```python
@st.cache_data
def load_data():
    # Expensive operation
    df = pd.read_csv("large_file.csv")
    return df

# Cached - only runs once
df = load_data()
```

### Cache Resource

```python
@st.cache_resource
def get_database_connection():
    # Create connection once
    return create_connection()

# Reuse connection
conn = get_database_connection()
```

### Clear Cache

```python
if st.button("Clear cache"):
    st.cache_data.clear()
    st.rerun()
```

---

## Multi-Page Apps

### File Structure

```
app.py
pages/
├── 1_📊_Dashboard.py
├── 2_📈_Analytics.py
└── 3_⚙️_Settings.py
```

### Main Page (app.py)

```python
import streamlit as st

st.set_page_config(page_title="My App", page_icon="📊")

st.title("Welcome")
st.write("Navigate using the sidebar")
```

### Sub-page (pages/1_📊_Dashboard.py)

```python
import streamlit as st

st.title("Dashboard")
st.write("Dashboard content")
```

**Navigation:** Automatic sidebar navigation

---

## Authentication

**For general auth concepts**, see [Auth Guide](../../guides/web/web_auth_guide__t__.md).

### Simple Password Protection

**For internal tools with single password:**

```python
import streamlit as st

def check_password():
    """Simple password check"""
    if 'authenticated' not in st.session_state:
        st.session_state.authenticated = False
    
    if not st.session_state.authenticated:
        st.title("Login")
        password = st.text_input("Password", type="password", key="password")
        
        if st.button("Login"):
            if password == st.secrets["password"]:  # Store in .streamlit/secrets.toml
                st.session_state.authenticated = True
                st.rerun()
            else:
                st.error("Incorrect password")
        return False
    return True

# Use in app
if check_password():
    st.title("Protected Content")
    st.write("You are logged in!")
    
    if st.sidebar.button("Logout"):
        st.session_state.authenticated = False
        st.rerun()
```

**secrets.toml:**
```toml
# .streamlit/secrets.toml (add to .gitignore)
password = "your-secret-password"
```

---

### Multi-User Authentication

**Using streamlit-authenticator:**

```bash
pip install streamlit-authenticator
```

**Generate password hashes:**
```python
import streamlit_authenticator as stauth

# Generate hashed password
hashed_password = stauth.Hasher(['password123']).generate()[0]
print(hashed_password)
```

**Complete implementation:**

```python
import streamlit as st
import streamlit_authenticator as stauth
import yaml
from yaml.loader import SafeLoader

# Load config
with open('config.yaml') as file:
    config = yaml.load(file, Loader=SafeLoader)

authenticator = stauth.Authenticate(
    config['credentials'],
    config['cookie']['name'],
    config['cookie']['key'],
    config['cookie']['expiry_days']
)

# Login widget
name, authentication_status, username = authenticator.login('Login', 'main')

if authentication_status:
    authenticator.logout('Logout', 'sidebar')
    st.sidebar.write(f'Welcome *{name}*')
    st.sidebar.write(f'Role: {config["credentials"]["usernames"][username]["role"]}')
    
    st.title(f'Welcome {name}!')
    st.write('You are authenticated')
    
elif authentication_status == False:
    st.error('Username/password is incorrect')
elif authentication_status == None:
    st.warning('Please enter your username and password')
```

**config.yaml:**
```yaml
credentials:
  usernames:
    admin:
      email: admin@example.com
      name: Admin User
      password: $2b$12$hashed_password_here
      role: admin
    user:
      email: user@example.com
      name: Regular User
      password: $2b$12$hashed_password_here
      role: user

cookie:
  name: auth_cookie
  key: random_signature_key  # Generate with: import secrets; secrets.token_urlsafe(32)
  expiry_days: 30
```

---

### Role-Based Access Control

**Implement RBAC with streamlit-authenticator:**

```python
import streamlit as st
import streamlit_authenticator as stauth
import yaml

# Load config
with open('config.yaml') as file:
    config = yaml.load(file, Loader=yaml.SafeLoader)

authenticator = stauth.Authenticate(
    config['credentials'],
    config['cookie']['name'],
    config['cookie']['key'],
    config['cookie']['expiry_days']
)

def get_user_role(username):
    """Get user role from config"""
    return config['credentials']['usernames'][username].get('role', 'viewer')

def has_role(username, required_role):
    """Check if user has required role (hierarchical)"""
    user_role = get_user_role(username)
    
    hierarchy = {
        'admin': ['admin', 'editor', 'viewer'],
        'editor': ['editor', 'viewer'],
        'viewer': ['viewer']
    }
    
    return required_role in hierarchy.get(user_role, [])

# Login
name, authentication_status, username = authenticator.login('Login', 'main')

if authentication_status:
    authenticator.logout('Logout', 'sidebar')
    
    # Show role in sidebar
    user_role = get_user_role(username)
    st.sidebar.write(f'**{name}** ({user_role})')
    
    # Main content
    st.title("Dashboard")
    
    # Admin-only section
    if has_role(username, 'admin'):
        st.header("Admin Panel")
        st.write("This section is only visible to admins")
        
        if st.button("Delete All Data"):
            st.warning("Admin action performed")
    
    # Editor+ section
    if has_role(username, 'editor'):
        st.header("Editor Tools")
        st.write("Create and edit content")
    
    # Everyone can view
    st.header("Content")
    st.write("This is visible to all authenticated users")
```

---

### Google OAuth Integration

**Using streamlit-oauth:**

```bash
pip install streamlit-oauth
```

```python
import streamlit as st
from streamlit_oauth import OAuth2Component
import os

# OAuth2 configuration
CLIENT_ID = st.secrets["google"]["client_id"]
CLIENT_SECRET = st.secrets["google"]["client_secret"]
REDIRECT_URI = "http://localhost:8501"  # Update for production

oauth2 = OAuth2Component(
    CLIENT_ID,
    CLIENT_SECRET,
    authorize_endpoint="https://accounts.google.com/o/oauth2/auth",
    token_endpoint="https://oauth2.googleapis.com/token",
    refresh_token_endpoint="https://oauth2.googleapis.com/token",
    revoke_token_endpoint="https://oauth2.googleapis.com/revoke"
)

if 'token' not in st.session_state:
    # Show login button
    result = oauth2.authorize_button(
        name="Login with Google",
        redirect_uri=REDIRECT_URI,
        scope="openid email profile",
        key="google_oauth",
        extras_params={"prompt": "consent", "access_type": "offline"}
    )
    
    if result and 'token' in result:
        st.session_state.token = result.get('token')
        st.rerun()
else:
    # User is logged in
    token = st.session_state.token
    
    # Get user info
    import requests
    response = requests.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {token['access_token']}"}
    )
    user_info = response.json()
    
    st.write(f"Welcome {user_info['name']}!")
    st.write(f"Email: {user_info['email']}")
    
    if st.button("Logout"):
        del st.session_state.token
        st.rerun()
```

**secrets.toml:**
```toml
[google]
client_id = "your-client-id.apps.googleusercontent.com"
client_secret = "your-client-secret"
```

---

### Database-Backed Authentication

**With SQLite:**

```python
import streamlit as st
import sqlite3
import hashlib
from datetime import datetime

def hash_password(password):
    """Hash password with SHA256"""
    return hashlib.sha256(password.encode()).hexdigest()

def init_db():
    """Initialize database"""
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT DEFAULT 'user',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def authenticate(username, password):
    """Authenticate user"""
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    password_hash = hash_password(password)
    c.execute(
        'SELECT id, username, email, role FROM users WHERE username = ? AND password_hash = ?',
        (username, password_hash)
    )
    
    user = c.fetchone()
    conn.close()
    
    if user:
        return {
            'id': user[0],
            'username': user[1],
            'email': user[2],
            'role': user[3]
        }
    return None

def register_user(username, email, password):
    """Register new user"""
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    try:
        password_hash = hash_password(password)
        c.execute(
            'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)',
            (username, email, password_hash)
        )
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()

# Initialize database
init_db()

# Session state
if 'user' not in st.session_state:
    st.session_state.user = None

# Login/Register UI
if st.session_state.user is None:
    tab1, tab2 = st.tabs(["Login", "Register"])
    
    with tab1:
        st.subheader("Login")
        username = st.text_input("Username", key="login_username")
        password = st.text_input("Password", type="password", key="login_password")
        
        if st.button("Login"):
            user = authenticate(username, password)
            if user:
                st.session_state.user = user
                st.success("Logged in successfully!")
                st.rerun()
            else:
                st.error("Invalid credentials")
    
    with tab2:
        st.subheader("Register")
        new_username = st.text_input("Username", key="reg_username")
        new_email = st.text_input("Email", key="reg_email")
        new_password = st.text_input("Password", type="password", key="reg_password")
        
        if st.button("Register"):
            if register_user(new_username, new_email, new_password):
                st.success("Registration successful! Please login.")
            else:
                st.error("Username or email already exists")
else:
    # User is logged in
    user = st.session_state.user
    
    st.sidebar.write(f"**{user['username']}**")
    st.sidebar.write(f"Role: {user['role']}")
    
    if st.sidebar.button("Logout"):
        st.session_state.user = None
        st.rerun()
    
    st.title(f"Welcome {user['username']}!")
    st.write("You are authenticated")
```

---

### Secrets Management

**Store secrets in `.streamlit/secrets.toml`:**

```toml
# .streamlit/secrets.toml (add to .gitignore)

# Simple password
password = "your-secret-password"

# Database
[database]
host = "localhost"
port = 5432
database = "mydb"
user = "dbuser"
password = "dbpass"

# Google OAuth
[google]
client_id = "your-client-id"
client_secret = "your-client-secret"

# API keys
openai_api_key = "sk-..."
stripe_api_key = "sk_test_..."
```

**Access in code:**
```python
import streamlit as st

# Simple value
password = st.secrets["password"]

# Nested value
db_host = st.secrets["database"]["host"]

# API key
openai_key = st.secrets["openai_api_key"]
```

---

### Session Timeout

**Implement automatic logout:**

```python
import streamlit as st
from datetime import datetime, timedelta

TIMEOUT_MINUTES = 30

def check_session_timeout():
    """Check if session has timed out"""
    if 'last_activity' in st.session_state:
        last_activity = st.session_state.last_activity
        if datetime.now() - last_activity > timedelta(minutes=TIMEOUT_MINUTES):
            # Session expired
            st.session_state.authenticated = False
            st.session_state.user = None
            st.warning("Session expired. Please login again.")
            return False
    
    # Update last activity
    st.session_state.last_activity = datetime.now()
    return True

# Use in app
if st.session_state.get('authenticated'):
    if not check_session_timeout():
        st.stop()
    
    # Protected content
    st.write("Protected content")
```

---

### Best Practices

**Security checklist:**

- [ ] Never hardcode passwords in code
- [ ] Use `st.secrets` for sensitive data
- [ ] Hash passwords (use bcrypt, not SHA256 for production)
- [ ] Implement session timeout
- [ ] Use HTTPS in production
- [ ] Add rate limiting for login attempts
- [ ] Log authentication events
- [ ] Validate email format
- [ ] Enforce strong password requirements

**Example: Strong password validation:**

```python
import re

def validate_password(password):
    """Validate password strength"""
    if len(password) < 8:
        return False, "Password must be at least 8 characters"
    
    if not re.search(r'[A-Z]', password):
        return False, "Password must contain uppercase letter"
    
    if not re.search(r'[a-z]', password):
        return False, "Password must contain lowercase letter"
    
    if not re.search(r'\d', password):
        return False, "Password must contain number"
    
    return True, "Password is strong"

# Use in registration
password = st.text_input("Password", type="password")
is_valid, message = validate_password(password)

if not is_valid:
    st.warning(message)
```

---

## Deployment

### Streamlit Community Cloud (Free)

1. **Push to GitHub:**
```bash
git init
git add .
git commit -m "Initial commit"
git push origin main
```

2. **Deploy:**
- Visit https://share.streamlit.io/
- Connect GitHub
- Select repository
- Deploy

3. **requirements.txt:**
```
streamlit==1.29.0
pandas==2.1.0
plotly==5.17.0
```

### Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

```bash
docker build -t streamlit-app .
docker run -p 8501:8501 streamlit-app
```

### Configuration

**`.streamlit/config.toml`:**
```toml
[theme]
primaryColor = "#FF4B4B"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"
font = "sans serif"

[server]
port = 8501
enableCORS = false
enableXsrfProtection = true
```

---

## Best Practices

**Performance:**
- Use `@st.cache_data` for expensive operations
- Limit data size (filter before displaying)
- Use `st.dataframe` instead of `st.table` for large data

**State Management:**
- Initialize session state at top of script
- Use callbacks for complex state updates
- Clear unused session state

**Layout:**
- Use sidebar for filters/controls
- Use columns for metrics
- Use tabs for different views
- Keep main content focused

**User Experience:**
- Show loading spinners for slow operations
- Provide clear error messages
- Use st.success/st.info/st.warning/st.error
- Add help text to inputs

---

## Troubleshooting

**App keeps reloading:**
- Check for infinite loops
- Verify file watchers aren't triggering
- Use `st.cache_data` to prevent re-computation

**State not persisting:**
- Ensure using `st.session_state`
- Check if state is initialized before use
- Verify callbacks are working

**Slow performance:**
- Profile with `@st.cache_data`
- Reduce data size
- Use `st.dataframe` pagination
- Consider fragments (Streamlit 1.33+)

**Deployment issues:**
- Check requirements.txt versions
- Verify Python version compatibility
- Review logs in deployment platform

---

## References

- **Documentation:** https://docs.streamlit.io/
- **Gallery:** https://streamlit.io/gallery
- **Components:** https://streamlit.io/components
- **Forum:** https://discuss.streamlit.io/

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md` - Decision framework
- **Gradio Runbook:** `gradio_runbook__t__.md` - Alternative for ML demos
- **Dash Runbook:** `dash_runbook__t__.md` - Alternative for dashboards
