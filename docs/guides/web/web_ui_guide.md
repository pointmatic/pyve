# Python-Friendly Web UI Guide

## Purpose
This guide helps you choose and implement user interfaces for Python applications, with a focus on Python-native and Python-friendly solutions. It covers frameworks where you can build UIs primarily or entirely in Python, minimizing JavaScript complexity.

**For platform-specific implementation details**, see the [UI runbooks](../runbooks/ui/).

## Scope
- Decision framework by use case
- Python-native UI frameworks (write only Python)
- Jupyter-based solutions
- Python web frameworks with templating
- HTMX for server-driven interactivity
- Modern JS frameworks (when Python isn't enough)
- Styling approaches
- Design and prototyping tools
- Common UI patterns

---

## Decision Framework

### By Use Case

**Quick Prototype / Demo (Hours to Days)**
- **Best:** Streamlit, Gradio, Marimo
- **Why:** Minimal code, instant results, no frontend expertise needed
- **Trade-offs:** Limited customization, opinionated layouts
- **Example:** ML model demo, data exploration tool, proof of concept

**Data Dashboard (Days to Weeks)**
- **Best:** Streamlit, Dash, Reflex
- **Why:** Built for data visualization, good component libraries
- **Trade-offs:** May feel "dashboardy", limited for complex interactions
- **Example:** Analytics dashboard, monitoring tool, reporting app

**Internal Tool (Weeks to Months)**
- **Best:** Reflex, NiceGUI, Flask + HTMX
- **Why:** More control, can grow with requirements, good for CRUD apps
- **Trade-offs:** More setup than Streamlit, less polish than commercial frameworks
- **Example:** Admin panel, internal workflow tool, data entry app

**Customer-Facing App (Months+)**
- **Best:** FastAPI + HTMX, Reflex, or Vue/Svelte + Python API
- **Why:** Professional polish, full control, scalable
- **Trade-offs:** More complexity, may need frontend skills
- **Example:** SaaS product, public-facing web app, e-commerce site

### By Team Skills

**Python-only team:**
- Streamlit, Gradio, Reflex, Marimo, Dash
- Flask/FastAPI + HTMX (minimal JS)

**Python + basic HTML/CSS:**
- Flask/FastAPI + Jinja2 templates
- HTMX for interactivity

**Python + JavaScript:**
- Vue or Svelte frontend + FastAPI backend
- Full flexibility, professional results

### By Complexity

**Simple (1-5 pages, basic interactions):**
- Streamlit, Gradio, NiceGUI

**Medium (5-20 pages, forms, auth):**
- Reflex, Dash, Flask + HTMX

**Complex (20+ pages, rich interactions, real-time):**
- FastAPI + Vue/Svelte, Reflex (advanced)

---

## Python-Native Frameworks

### Streamlit

**Write only Python, instant UI**

**Best for:**
- Data apps and dashboards
- ML model demos
- Internal tools
- Rapid prototyping

**Pros:**
- Extremely fast development
- Great for data visualization
- Large component ecosystem
- Active community

**Cons:**
- Opinionated layout (sidebar + main)
- Full page reloads (improving with fragments)
- Limited customization
- Not ideal for complex apps

**Example:**
```python
import streamlit as st
import pandas as pd

st.title("Sales Dashboard")

# Sidebar filters
date_range = st.sidebar.date_input("Date Range", [])
category = st.sidebar.selectbox("Category", ["All", "Electronics", "Clothing"])

# Load data
df = pd.read_csv("sales.csv")

# Display metrics
col1, col2, col3 = st.columns(3)
col1.metric("Total Sales", "$1.2M", "+12%")
col2.metric("Orders", "1,234", "+5%")
col3.metric("Customers", "567", "+8%")

# Chart
st.line_chart(df.groupby("date")["sales"].sum())

# Table
st.dataframe(df)
```

**When to use:** Quick data apps, ML demos, internal dashboards

**See:** [Streamlit Runbook](../runbooks/ui/streamlit_runbook__t__.md)

### Gradio

**ML-focused, share models instantly**

**Best for:**
- ML model interfaces
- Quick demos
- Sharing with non-technical users

**Pros:**
- Simplest for ML models
- Built-in sharing (gradio.app)
- Good for input/output interfaces
- Blocks API for custom layouts

**Cons:**
- Limited to ML/data use cases
- Less flexible than Streamlit
- Smaller ecosystem

**Example:**
```python
import gradio as gr

def predict(image):
    # Your ML model here
    return "Cat (95% confidence)"

demo = gr.Interface(
    fn=predict,
    inputs=gr.Image(type="pil"),
    outputs=gr.Label(),
    title="Image Classifier",
    description="Upload an image to classify"
)

demo.launch()
```

**When to use:** ML model demos, simple input/output interfaces

**See:** [Gradio Runbook](../runbooks/ui/gradio_runbook__t__.md)

### Reflex

**Modern, React-like but pure Python**

**Best for:**
- Full-featured web apps
- When you need more control than Streamlit
- Customer-facing applications

**Pros:**
- Pure Python (compiles to React)
- Component-based architecture
- Good performance
- Can grow to complex apps
- Modern, professional look

**Cons:**
- Steeper learning curve
- Younger ecosystem
- More boilerplate than Streamlit

**Example:**
```python
import reflex as rx

class State(rx.State):
    count: int = 0
    
    def increment(self):
        self.count += 1

def index():
    return rx.container(
        rx.heading("Counter App"),
        rx.text(f"Count: {State.count}"),
        rx.button("Increment", on_click=State.increment),
    )

app = rx.App()
app.add_page(index)
```

**When to use:** Full web apps, when Streamlit is too limiting

**See:** [Reflex Runbook](../runbooks/ui/reflex_runbook__t__.md)

### Dash (Plotly)

**Analytics dashboards with callbacks**

**Best for:**
- Interactive dashboards
- Data visualization heavy apps
- Enterprise analytics

**Pros:**
- Mature, stable
- Excellent for charts/graphs
- Good component library
- Enterprise support available

**Cons:**
- Callback-based (can get complex)
- Verbose compared to Streamlit
- Plotly-centric

**Example:**
```python
from dash import Dash, html, dcc, callback, Input, Output
import plotly.express as px

app = Dash(__name__)

app.layout = html.Div([
    html.H1("Sales Dashboard"),
    dcc.Dropdown(
        id='category-dropdown',
        options=['Electronics', 'Clothing', 'Food'],
        value='Electronics'
    ),
    dcc.Graph(id='sales-chart')
])

@callback(
    Output('sales-chart', 'figure'),
    Input('category-dropdown', 'value')
)
def update_chart(category):
    df = get_data(category)
    return px.line(df, x='date', y='sales')

if __name__ == '__main__':
    app.run_server(debug=True)
```

**When to use:** Analytics dashboards, Plotly-heavy apps

**See:** [Dash Runbook](../runbooks/ui/dash_runbook__t__.md)

### NiceGUI

**Simple, desktop-app feel**

**Best for:**
- Internal tools
- Simple CRUD apps
- Desktop-like web apps

**Pros:**
- Very simple API
- Good for forms and tables
- Can run as desktop app (with pywebview)
- Fast development

**Cons:**
- Smaller community
- Limited components
- Not for complex apps

**Example:**
```python
from nicegui import ui

def add_user():
    name = name_input.value
    users.append(name)
    ui.notify(f'Added {name}')

with ui.card():
    ui.label('User Management')
    name_input = ui.input('Name')
    ui.button('Add User', on_click=add_user)

ui.run()
```

**When to use:** Simple internal tools, desktop-like apps

---

## Jupyter-Based Solutions

### Marimo

**Reactive notebooks as apps**

**Best for:**
- Interactive notebooks
- Data exploration
- Prototypes that become apps

**Pros:**
- Reactive (no manual re-run)
- Pure Python
- Can export as standalone app
- Git-friendly (Python files, not JSON)

**Cons:**
- Notebook paradigm (not traditional app structure)
- Newer project

**Example:**
```python
import marimo as mo

# Reactive slider
slider = mo.ui.slider(0, 100, value=50)

# Automatically updates when slider changes
mo.md(f"Value: {slider.value}")
```

**When to use:** Exploratory work that needs to become an app

**See:** [Marimo Runbook](../runbooks/ui/marimo_runbook__t__.md)

### Solara

**Reactive Jupyter widgets**

**Best for:**
- Jupyter users wanting reactive apps
- Data science workflows

**Pros:**
- Reactive like React
- Works in Jupyter and standalone
- Good for data apps

**Cons:**
- Jupyter-centric
- Smaller ecosystem

### Voila

**Turn notebooks into apps**

**Best for:**
- Sharing existing notebooks
- Quick demos from notebooks

**Pros:**
- Zero code changes (just run voila)
- Hides code cells
- Good for sharing analysis

**Cons:**
- Limited interactivity
- Notebook limitations apply

---

## Python Web Frameworks + Templating

### Flask + Jinja2

**Lightweight, flexible**

**Best for:**
- Custom web apps
- When you need full control
- Learning web development

**Pros:**
- Simple, minimal
- Huge ecosystem
- Very flexible
- Well-documented

**Cons:**
- More boilerplate
- Need to know HTML/CSS
- Manual routing, forms, etc.

**Example:**
```python
from flask import Flask, render_template, request

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/submit', methods=['POST'])
def submit():
    name = request.form['name']
    return render_template('result.html', name=name)

if __name__ == '__main__':
    app.run(debug=True)
```

**When to use:** Custom apps, learning, full control needed

**See:** [Flask + HTMX Runbook](../runbooks/ui/flask_htmx_runbook__t__.md)

### FastAPI + Jinja2

**Modern, async, API-first**

**Best for:**
- API + frontend combo
- Modern async apps
- When you need speed

**Pros:**
- Fast (async)
- Great API docs (automatic)
- Type hints
- Modern Python features

**Cons:**
- Async can be complex
- Newer (less mature than Flask)

**Example:**
```python
from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

app = FastAPI()
templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/submit")
async def submit(name: str):
    return {"message": f"Hello {name}"}
```

**When to use:** Modern apps, API + frontend, async needed

**See:** [FastAPI + Jinja2 Runbook](../runbooks/ui/fastapi_jinja2_runbook__t__.md)

### Django (Brief Mention)

**Full-featured, batteries included**

**Best for:**
- Large applications
- When you need everything (auth, admin, ORM)
- Traditional web apps

**Pros:**
- Complete framework
- Excellent admin panel
- Mature, stable
- Great for traditional web apps

**Cons:**
- Heavy, opinionated
- Steeper learning curve
- Overkill for simple apps

**When to use:** Large, traditional web applications with many features

---

## HTMX Pattern

**Server-driven interactivity without JavaScript**

HTMX lets you add AJAX, WebSockets, and more with HTML attributes, keeping logic on the server (Python).

**Best for:**
- Flask/FastAPI apps needing interactivity
- Avoiding JavaScript complexity
- Progressive enhancement

**Pros:**
- Minimal JavaScript
- Server-side logic
- Simple mental model
- Works with any backend

**Cons:**
- Different paradigm
- Limited for very complex UIs
- Smaller ecosystem than React/Vue

**Example:**
```html
<!-- Button that loads content without page reload -->
<button hx-get="/api/users" hx-target="#user-list">
    Load Users
</button>

<div id="user-list"></div>
```

```python
# Flask endpoint
@app.route('/api/users')
def get_users():
    users = User.query.all()
    return render_template('users_partial.html', users=users)
```

**When to use:** Flask/FastAPI apps, avoiding JS frameworks

**See:** [Flask + HTMX Runbook](../runbooks/ui/flask_htmx_runbook__t__.md)

---

## Modern JS Frameworks (When Python Isn't Enough)

### When to Reach for JavaScript

**Consider JS frameworks when:**
- Very rich, interactive UI needed
- Real-time collaboration features
- Complex client-side state
- Mobile-like experience on web
- Team has frontend expertise

**Don't use JS frameworks if:**
- Python-native solution works
- Simple CRUD app
- Internal tool
- Team is Python-only

### Vue

**Progressive, easy to learn**

**Pros:**
- Gentle learning curve
- Can start small, grow big
- Good documentation
- Large ecosystem

**Cons:**
- Still need to learn JavaScript
- Build tooling complexity

**When to use:** Team learning frontend, progressive enhancement

### Svelte

**Compiled, minimal runtime**

**Pros:**
- Less code than React/Vue
- Fast performance
- Simple mental model
- Growing ecosystem

**Cons:**
- Smaller ecosystem than React/Vue
- Newer (less mature)

**When to use:** Modern apps, performance critical, smaller bundles

### React (Brief Mention)

**Industry standard, huge ecosystem**

**Use when:** Enterprise requirements, large team, need every library

**Skip when:** Overkill for your needs, team is Python-focused

### Angular (Brief Mention)

**Enterprise, opinionated**

**Use when:** Large enterprise app, TypeScript team

**Skip when:** Overkill, prefer flexibility

**See:** [Vue/Svelte Runbook](../runbooks/ui/vue_svelte_runbook__t__.md)

---

## Styling Approaches

### Tailwind CSS

**Utility-first CSS framework**

**Pros:**
- Fast development
- Consistent design
- No naming classes
- Highly customizable

**Cons:**
- HTML can look cluttered
- Learning curve for utilities

**Example:**
```html
<div class="flex items-center justify-between p-4 bg-white shadow rounded-lg">
    <h2 class="text-xl font-bold text-gray-800">Dashboard</h2>
    <button class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
        Action
    </button>
</div>
```

**When to use:** Modern apps, rapid development, consistent design

### Pico CSS

**Classless, minimal**

**Pros:**
- No classes needed
- Beautiful defaults
- Tiny file size
- Perfect for simple apps

**Cons:**
- Limited customization
- Not for complex layouts

**Example:**
```html
<!-- No classes needed! -->
<article>
    <h1>Dashboard</h1>
    <p>Welcome to your dashboard.</p>
    <button>Action</button>
</article>
```

**When to use:** Simple apps, prototypes, minimal styling

### DaisyUI

**Tailwind component library**

**Pros:**
- Pre-built components
- Tailwind-based
- Themes included
- Good documentation

**Cons:**
- Requires Tailwind
- Opinionated design

**When to use:** Tailwind + need components, rapid development

### Component Libraries

**For Python frameworks:**
- **Streamlit:** Built-in components + community components
- **Reflex:** Built-in components + Chakra UI
- **Dash:** Dash Bootstrap Components, Dash Mantine Components
- **NiceGUI:** Built-in components

**For JS frameworks:**
- **Vue:** Vuetify, PrimeVue, Quasar
- **Svelte:** SvelteUI, Skeleton
- **React:** Material-UI, Ant Design, shadcn/ui

---

## Design & Prototyping Tools

### Figma

**Industry standard, collaborative**

**Best for:**
- Professional designs
- Team collaboration
- Design systems
- High-fidelity mockups

**Pros:**
- Free tier
- Browser-based
- Real-time collaboration
- Huge plugin ecosystem

**Cons:**
- Can be complex
- Learning curve

**When to use:** Professional projects, team design work

### Excalidraw

**Quick sketches and diagrams**

**Best for:**
- Wireframes
- Flow diagrams
- Quick ideation
- Technical diagrams

**Pros:**
- Very fast
- Free, open-source
- Hand-drawn aesthetic
- No learning curve

**Cons:**
- Not for high-fidelity
- Limited styling

**When to use:** Quick sketches, brainstorming, technical docs

### Balsamiq

**Wireframing tool**

**Best for:**
- Low-fidelity wireframes
- Early-stage design
- Communicating ideas

**Pros:**
- Fast wireframing
- Sketch aesthetic (prevents pixel-pushing)
- Good component library

**Cons:**
- Paid only
- Not for high-fidelity

**When to use:** Early design phase, wireframes

### Penpot

**Open-source Figma alternative**

**Best for:**
- Open-source projects
- Self-hosted design tools
- Figma-like features

**Pros:**
- Free, open-source
- Similar to Figma
- Self-hostable

**Cons:**
- Smaller ecosystem
- Less mature

**When to use:** Open-source preference, self-hosting needed

---

## Common UI Patterns

### Forms

**Considerations:**
- Validation (client + server)
- Error messages
- Loading states
- Success feedback

**Python-native:**
```python
# Streamlit
with st.form("user_form"):
    name = st.text_input("Name")
    email = st.text_input("Email")
    submitted = st.form_submit_button("Submit")
    
    if submitted:
        if not name or not email:
            st.error("All fields required")
        else:
            save_user(name, email)
            st.success("User saved!")
```

**HTMX:**
```html
<form hx-post="/submit" hx-target="#result">
    <input type="text" name="name" required>
    <input type="email" name="email" required>
    <button type="submit">Submit</button>
</form>
<div id="result"></div>
```

### Authentication

**Approaches:**
- Session-based (Flask/FastAPI)
- JWT tokens (API-first)
- OAuth (social login)
- Magic links (passwordless)

**Libraries:**
- **Flask:** Flask-Login, Flask-Security
- **FastAPI:** FastAPI-Users, authlib
- **Streamlit:** streamlit-authenticator
- **Reflex:** Built-in auth (coming)

### State Management

**Local state:**
- Component-level
- Form inputs
- UI toggles

**Global state:**
- User session
- App configuration
- Shared data

**Python-native patterns:**
- **Streamlit:** st.session_state
- **Reflex:** State classes
- **Dash:** dcc.Store

### Routing

**Multi-page apps:**
- **Streamlit:** st.Page, st.navigation
- **Reflex:** rx.route decorator
- **Flask/FastAPI:** @app.route
- **Dash:** dcc.Location + callbacks

### Data Tables

**Features:**
- Sorting, filtering, pagination
- Inline editing
- Export (CSV, Excel)
- Selection

**Libraries:**
- **Streamlit:** st.dataframe (built-in)
- **Dash:** dash-ag-grid, DataTable
- **Reflex:** rx.data_table
- **JS:** AG Grid, TanStack Table

### Real-Time Updates

**Approaches:**
- Polling (simple, inefficient)
- WebSockets (real-time, complex)
- Server-Sent Events (one-way, simple)

**Python support:**
- **Streamlit:** Auto-refresh, fragments
- **Reflex:** WebSocket-based
- **FastAPI:** WebSocket support
- **Flask:** Flask-SocketIO

---

## Deployment Considerations

### Streamlit

**Options:**
- Streamlit Community Cloud (free)
- Docker + any cloud
- Streamlit Enterprise

### Gradio

**Options:**
- Hugging Face Spaces (free)
- gradio.app (temporary sharing)
- Docker + any cloud

### Reflex

**Options:**
- Reflex hosting (coming)
- Docker + any cloud
- VPS (simple deployment)

### Flask/FastAPI

**Options:**
- Traditional hosting (Heroku, Railway, Fly.io)
- Serverless (AWS Lambda, Google Cloud Run)
- Docker + Kubernetes
- VPS (DigitalOcean, Linode)

---

## Best Practices

**Start simple:**
- Use Python-native if possible
- Add complexity only when needed
- Prototype quickly

**Choose based on use case:**
- Prototype → Streamlit/Gradio
- Dashboard → Streamlit/Dash
- Internal tool → Reflex/Flask + HTMX
- Customer app → Reflex/FastAPI + Vue

**Consider team skills:**
- Python-only → Streamlit, Reflex, Gradio
- Python + HTML → Flask + HTMX
- Full-stack → FastAPI + Vue/Svelte

**Plan for growth:**
- Can this framework scale to your needs?
- Can you migrate if needed?
- Is the community active?

**Focus on UX:**
- Fast load times
- Clear feedback
- Error handling
- Responsive design

---

## References

- **Streamlit:** https://streamlit.io/
- **Gradio:** https://gradio.app/
- **Reflex:** https://reflex.dev/
- **Marimo:** https://marimo.io/
- **Dash:** https://dash.plotly.com/
- **NiceGUI:** https://nicegui.io/
- **HTMX:** https://htmx.org/
- **Flask:** https://flask.palletsprojects.com/
- **FastAPI:** https://fastapi.tiangolo.com/

---

## Related Documentation

- **UI Runbooks:** `../runbooks/ui/` - Platform-specific implementation details
- **UI Architecture Guide:** `ui_architecture_guide__t__.md` - Design patterns and principles (v0.3.11)
- **Analytics Guide:** `analytics_guide__t__.md` - BI tools for data visualization
