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

### Simple Password

```python
import streamlit as st

def check_password():
    if 'authenticated' not in st.session_state:
        st.session_state.authenticated = False
    
    if not st.session_state.authenticated:
        password = st.text_input("Password", type="password")
        if st.button("Login"):
            if password == "secret123":
                st.session_state.authenticated = True
                st.rerun()
            else:
                st.error("Incorrect password")
        return False
    return True

if check_password():
    st.title("Protected Content")
    st.write("You are logged in!")
    
    if st.button("Logout"):
        st.session_state.authenticated = False
        st.rerun()
```

### streamlit-authenticator

```bash
pip install streamlit-authenticator
```

```python
import streamlit as st
import streamlit_authenticator as stauth

# User credentials (hashed passwords)
credentials = {
    'usernames': {
        'jsmith': {
            'name': 'John Smith',
            'password': '$2b$12$...'  # Hashed password
        }
    }
}

authenticator = stauth.Authenticate(
    credentials,
    'cookie_name',
    'signature_key',
    cookie_expiry_days=30
)

name, authentication_status, username = authenticator.login('Login', 'main')

if authentication_status:
    authenticator.logout('Logout', 'sidebar')
    st.write(f'Welcome *{name}*')
elif authentication_status == False:
    st.error('Username/password is incorrect')
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
