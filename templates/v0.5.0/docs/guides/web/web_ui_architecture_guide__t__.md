# Web UI Architecture Guide

## Purpose
This guide covers architectural patterns, design principles, and best practices for building web UIs with Python. It complements the [Web UI Guide](web_ui_guide__t__.md) by focusing on how to structure and organize your UI code.

**For framework-specific implementation**, see the [UI runbooks](../../runbooks/ui/).

## Scope
- Architectural patterns (MVC, MVVM, MVP, Component-based)
- State management patterns
- Common UI patterns
- Design principles
- Best practices (accessibility, performance, responsive design, error handling)

---

## Architectural Patterns

### MVC (Model-View-Controller)

**Traditional web pattern, server-side rendering**

```
User → Controller → Model → Database
         ↓
       View (HTML)
```

**Best for:**
- Flask/FastAPI + Jinja2 apps
- Server-rendered applications
- Traditional CRUD apps

**Example (Flask):**
```python
# Model
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80))

# Controller
@app.route('/users/<int:user_id>')
def show_user(user_id):
    user = User.query.get_or_404(user_id)
    return render_template('user.html', user=user)

# View (user.html)
# <h1>{{ user.name }}</h1>
```

**Pros:**
- Clear separation of concerns
- Well-understood pattern
- Good for server-side apps

**Cons:**
- Full page reloads
- Less interactive
- Tight coupling between layers

---

### MVVM (Model-View-ViewModel)

**Modern pattern for reactive UIs**

```
View ←→ ViewModel ←→ Model
(UI)    (State)      (Data)
```

**Best for:**
- Streamlit, Reflex, Dash (Python)
- Vue.js (JavaScript)
- Reactive frameworks
- Data-driven UIs

**Example (Reflex):**
```python
# Model
class User:
    name: str
    email: str

# ViewModel (State)
class UserState(rx.State):
    users: list[User] = []
    
    def load_users(self):
        self.users = fetch_users()  # Model interaction
    
    def add_user(self, name: str, email: str):
        new_user = User(name=name, email=email)
        save_user(new_user)  # Model interaction
        self.load_users()

# View
def user_list():
    return rx.foreach(
        UserState.users,
        lambda user: rx.text(user.name)
    )
```

**Pros:**
- Two-way data binding
- Reactive updates
- Clean separation

**Cons:**
- Can be complex
- Memory overhead
- Learning curve

**JavaScript Example (Vue.js):**

Vue is explicitly designed as an MVVM framework:

```javascript
// Model (plain data)
const userData = {
  name: 'Alice',
  email: 'alice@example.com'
}

// ViewModel (Vue component)
export default {
  data() {
    return {
      users: []  // Reactive state
    }
  },
  computed: {
    activeUsers() {  // Derived state
      return this.users.filter(u => u.active)
    }
  },
  methods: {
    async loadUsers() {
      this.users = await fetchUsers()  // Updates Model
    }
  }
}

// View (template with two-way binding)
// <div>
//   <h1>{{ users.length }} Users</h1>
//   <div v-for="user in activeUsers" :key="user.id">
//     {{ user.name }}
//   </div>
// </div>
```

**When to use Vue with Python:**
- Customer-facing apps needing rich interactivity
- FastAPI/Flask backend + Vue frontend
- Team has JavaScript experience
- Need professional polish and full control

---

### MVP (Model-View-Presenter)

**Variation of MVC with passive view**

```
View ←→ Presenter ←→ Model
(Dumb)  (Logic)      (Data)
```

**Best for:**
- Testing-focused apps
- Complex business logic
- Gradio applications

**Example (Gradio):**
```python
# Model
def fetch_prediction(input_data):
    return model.predict(input_data)

# Presenter
class PredictionPresenter:
    def __init__(self, model):
        self.model = model
    
    def handle_input(self, text):
        # Business logic
        processed = self.preprocess(text)
        result = fetch_prediction(processed)
        return self.format_output(result)
    
    def preprocess(self, text):
        return text.lower().strip()
    
    def format_output(self, result):
        return f"Prediction: {result:.2f}"

# View (passive)
presenter = PredictionPresenter(model)
interface = gr.Interface(
    fn=presenter.handle_input,
    inputs="text",
    outputs="text"
)
```

**Pros:**
- Highly testable
- Clear responsibilities
- Passive view (easy to swap)

**Cons:**
- More boilerplate
- Can be over-engineered
- Presenter can get bloated

---

### Component-Based Architecture

**Modern approach, composable UI elements**

```
App
├── Header
│   ├── Logo
│   └── Navigation
├── Main
│   ├── Sidebar
│   └── Content
│       ├── Card
│       └── Card
└── Footer
```

**Best for:**
- Reflex (Python)
- React, Svelte (JavaScript)
- Reusable UI elements
- Large applications

**Example (Reflex):**
```python
# Reusable components
def card(title: str, content: str):
    return rx.box(
        rx.heading(title, size="md"),
        rx.text(content),
        padding="1em",
        border="1px solid #ddd",
        border_radius="8px"
    )

def sidebar():
    return rx.box(
        rx.heading("Menu"),
        rx.link("Home", href="/"),
        rx.link("About", href="/about"),
        width="200px"
    )

def layout(content):
    return rx.hstack(
        sidebar(),
        rx.box(content, flex="1"),
        spacing="2em"
    )

# Compose
def home_page():
    return layout(
        rx.vstack(
            card("Welcome", "This is the home page"),
            card("Features", "Check out our features")
        )
    )
```

**Pros:**
- Highly reusable
- Easy to maintain
- Composable
- Testable in isolation

**Cons:**
- Can lead to prop drilling
- Component hierarchy complexity
- Performance considerations

**JavaScript Examples:**

**React (Component-based with Virtual DOM):**
```javascript
// React uses component-based architecture with JSX
function UserCard({ user }) {
  return (
    <div className="card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  )
}

function UserList() {
  const [users, setUsers] = useState([])
  
  useEffect(() => {
    fetchUsers().then(setUsers)
  }, [])
  
  return (
    <div>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  )
}
```

**Pros:** Large ecosystem, mature, widely adopted
**Cons:** Heavy runtime, complex tooling, JSX learning curve

**Svelte (Compiler-based Components - Recommended):**
```svelte
<script>
  // Svelte compiles to vanilla JS - no runtime framework
  let users = []
  
  // Reactive declarations (computed values)
  $: activeUsers = users.filter(u => u.active)
  
  async function loadUsers() {
    users = await fetchUsers()
  }
  
  onMount(loadUsers)
</script>

<!-- Direct binding, no virtual DOM -->
<h1>{users.length} Users</h1>
{#each activeUsers as user}
  <div class="card">
    <h3>{user.name}</h3>
    <p>{user.email}</p>
  </div>
{/each}
```

**Pros:** 
- **Smallest bundle size** - compiles to vanilla JS
- **Best performance** - no virtual DOM overhead
- **Simpler syntax** - less boilerplate than React/Vue
- **Built-in reactivity** - no hooks or computed properties needed
- **Great DX** - intuitive and fast to write

**Cons:** 
- Smaller ecosystem than React/Vue
- Fewer third-party components
- Less enterprise adoption (growing)

**When to use Svelte with Python:**
- **Recommended for most Python + JS projects**
- FastAPI/Flask backend + Svelte frontend
- Performance-critical applications
- Smaller bundle sizes matter
- Team wants simpler, more intuitive code
- Modern greenfield projects

**Framework Comparison:**

| Framework | Pattern | Runtime | Bundle Size | Performance | Complexity |
|-----------|---------|---------|-------------|-------------|------------|
| **Vue** | MVVM | Yes | Medium | Good | Medium |
| **React** | Component | Yes (Virtual DOM) | Large | Good | High |
| **Svelte** | Component | No (Compiled) | **Smallest** | **Best** | **Low** |

**Recommendation:** For Python developers building modern web UIs, **Svelte** offers the best balance of simplicity, performance, and developer experience. Use Vue if you need MVVM patterns or have existing Vue expertise. Use React only if you need its massive ecosystem or have existing React developers.

---

## State Management Patterns

### Local State

**State within a single component**

**Best for:**
- Form inputs
- Toggle states
- Component-specific data

**Example (Streamlit):**
```python
# Session state for local component
if 'counter' not in st.session_state:
    st.session_state.counter = 0

if st.button("Increment"):
    st.session_state.counter += 1

st.write(f"Count: {st.session_state.counter}")
```

**Pros:**
- Simple
- No dependencies
- Fast

**Cons:**
- Hard to share
- Can duplicate logic
- Limited scope

---

### Global State

**Shared state across entire application**

**Best for:**
- User authentication
- App-wide settings
- Shared data

**Example (Reflex):**
```python
class AppState(rx.State):
    user: Optional[User] = None
    theme: str = "light"
    
    def login(self, username: str, password: str):
        self.user = authenticate(username, password)
    
    def toggle_theme(self):
        self.theme = "dark" if self.theme == "light" else "light"

# Access from any component
def header():
    return rx.cond(
        AppState.user,
        rx.text(f"Welcome, {AppState.user.name}"),
        rx.link("Login", href="/login")
    )
```

**Pros:**
- Easy to share
- Single source of truth
- Consistent state

**Cons:**
- Can become bloated
- Hard to debug
- Performance impact

---

### Reactive State

**State that automatically updates UI**

**Best for:**
- Real-time dashboards
- Live data feeds
- Collaborative apps

**Example (Dash):**
```python
@app.callback(
    Output('live-graph', 'figure'),
    Input('interval-component', 'n_intervals')
)
def update_graph(n):
    # Fetch latest data
    data = get_latest_metrics()
    
    # Update figure
    fig = go.Figure(data=[
        go.Scatter(x=data['time'], y=data['value'])
    ])
    return fig

# Auto-refresh every second
app.layout = html.Div([
    dcc.Graph(id='live-graph'),
    dcc.Interval(id='interval-component', interval=1000)
])
```

**Pros:**
- Automatic updates
- Real-time feel
- Declarative

**Cons:**
- Complexity
- Performance overhead
- Debugging challenges

---

### Immutable State

**State that never changes, only replaced**

**Best for:**
- Predictable updates
- Time-travel debugging
- Undo/redo functionality

**Example (Python pattern):**
```python
from dataclasses import dataclass, replace

@dataclass(frozen=True)
class AppState:
    users: tuple[User, ...]
    selected_id: Optional[int]
    
    def add_user(self, user: User) -> 'AppState':
        return replace(self, users=self.users + (user,))
    
    def select_user(self, user_id: int) -> 'AppState':
        return replace(self, selected_id=user_id)

# Usage
state = AppState(users=(), selected_id=None)
state = state.add_user(User("Alice"))
state = state.select_user(1)
```

**Pros:**
- Predictable
- Easy to debug
- Thread-safe

**Cons:**
- Memory overhead
- Performance cost
- Verbose

---

## Common UI Patterns

### Forms

**Data input and validation**

**Pattern:**
```python
# 1. Define form fields
# 2. Validate input
# 3. Handle submission
# 4. Show feedback

# Example (Streamlit)
with st.form("user_form"):
    name = st.text_input("Name")
    email = st.text_input("Email")
    age = st.number_input("Age", min_value=0, max_value=120)
    
    submitted = st.form_submit_button("Submit")
    
    if submitted:
        if not name or not email:
            st.error("Name and email are required")
        elif not is_valid_email(email):
            st.error("Invalid email format")
        else:
            save_user(name, email, age)
            st.success("User created successfully!")
```

**Best practices:**
- Validate on client and server
- Show clear error messages
- Disable submit during processing
- Provide feedback immediately

---

### Navigation

**Moving between pages/views**

**Pattern:**
```python
# Multi-page app structure
# pages/
#   home.py
#   about.py
#   contact.py

# Streamlit multi-page
# pages/home.py
import streamlit as st
st.title("Home")
st.write("Welcome!")

# Reflex routing
app = rx.App()
app.add_page(home, route="/")
app.add_page(about, route="/about")
app.add_page(contact, route="/contact")
```

**Best practices:**
- Clear navigation structure
- Breadcrumbs for deep hierarchies
- Active state indication
- Mobile-friendly menus

---

### Data Tables

**Display and interact with tabular data**

**Pattern:**
```python
# Streamlit
df = pd.DataFrame(data)
st.dataframe(
    df,
    use_container_width=True,
    hide_index=True,
    column_config={
        "price": st.column_config.NumberColumn(
            "Price",
            format="$%.2f"
        )
    }
)

# With actions
selected_rows = st.data_editor(
    df,
    num_rows="dynamic",  # Allow adding rows
    disabled=["id"],  # Disable editing ID
)
```

**Best practices:**
- Pagination for large datasets
- Sortable columns
- Filterable data
- Export functionality
- Responsive design

---

### Modals/Dialogs

**Focused interactions**

**Pattern:**
```python
# Streamlit (using expander as modal alternative)
if st.button("Delete User"):
    with st.expander("⚠️ Confirm Deletion", expanded=True):
        st.warning("This action cannot be undone!")
        col1, col2 = st.columns(2)
        if col1.button("Cancel"):
            st.rerun()
        if col2.button("Delete", type="primary"):
            delete_user(user_id)
            st.success("User deleted")
            st.rerun()

# Reflex (native modal)
def delete_modal():
    return rx.modal(
        rx.modal_overlay(
            rx.modal_content(
                rx.modal_header("Confirm Deletion"),
                rx.modal_body("Are you sure?"),
                rx.modal_footer(
                    rx.button("Cancel", on_click=State.close_modal),
                    rx.button("Delete", on_click=State.delete_user)
                )
            )
        ),
        is_open=State.modal_open
    )
```

**Best practices:**
- Clear purpose
- Easy to dismiss
- Focus management
- Accessible (ESC to close)

---

### Notifications/Toasts

**User feedback**

**Pattern:**
```python
# Streamlit
st.success("✅ Operation successful!")
st.error("❌ Something went wrong")
st.warning("⚠️ Please review")
st.info("ℹ️ Did you know...")

# With auto-dismiss
with st.spinner("Processing..."):
    time.sleep(2)
st.success("Done!", icon="✅")
```

**Best practices:**
- Appropriate severity levels
- Clear, actionable messages
- Auto-dismiss for success
- Persistent for errors
- Position consistently

---

### Loading States

**Async operation feedback**

**Pattern:**
```python
# Streamlit
with st.spinner("Loading data..."):
    data = fetch_data()

# Skeleton loading
if data is None:
    st.write("Loading...")
    st.empty()  # Placeholder
else:
    st.dataframe(data)

# Progress bar
progress_bar = st.progress(0)
for i in range(100):
    process_chunk(i)
    progress_bar.progress(i + 1)
```

**Best practices:**
- Show progress when possible
- Estimated time remaining
- Cancellable operations
- Skeleton screens for layout

---

### Infinite Scroll

**Load more data on scroll**

**Pattern (HTMX):**
```html
<div id="items">
    {% for item in items %}
        <div class="item">{{ item.name }}</div>
    {% endfor %}
</div>

<div hx-get="/items?page={{ next_page }}"
     hx-trigger="revealed"
     hx-swap="afterend">
    Loading more...
</div>
```

**Best practices:**
- Load ahead of scroll
- Show loading indicator
- Handle end of data
- Preserve scroll position

---

## Design Principles

### Separation of Concerns

**Keep different responsibilities separate**

```python
# Bad: Mixed concerns
def show_users():
    # Database logic
    users = db.query("SELECT * FROM users")
    
    # Business logic
    active_users = [u for u in users if u.is_active]
    
    # Presentation logic
    st.table(active_users)

# Good: Separated concerns
# data.py
def get_users():
    return db.query("SELECT * FROM users")

# business.py
def filter_active_users(users):
    return [u for u in users if u.is_active]

# ui.py
def show_users():
    users = get_users()
    active = filter_active_users(users)
    st.table(active)
```

---

### Composition Over Inheritance

**Build complex UIs from simple components**

```python
# Good: Composition
def button(text, **props):
    return rx.button(text, **props)

def primary_button(text):
    return button(text, color_scheme="blue")

def danger_button(text):
    return button(text, color_scheme="red")

def icon_button(icon, text):
    return button(
        rx.hstack(rx.icon(icon), rx.text(text))
    )

# Use
rx.vstack(
    primary_button("Save"),
    danger_button("Delete"),
    icon_button("download", "Export")
)
```

---

### Single Responsibility

**Each component does one thing well**

```python
# Bad: Component does too much
def user_dashboard():
    # Fetches data
    users = fetch_users()
    stats = calculate_stats(users)
    
    # Renders multiple things
    return rx.vstack(
        render_header(),
        render_stats(stats),
        render_user_table(users),
        render_footer()
    )

# Good: Focused components
def user_stats_card(stats):
    return rx.box(
        rx.stat(label="Total Users", value=stats.total),
        rx.stat(label="Active", value=stats.active)
    )

def user_table(users):
    return rx.table(
        rx.thead(rx.tr(rx.th("Name"), rx.th("Email"))),
        rx.tbody([
            rx.tr(rx.td(u.name), rx.td(u.email))
            for u in users
        ])
    )

def user_dashboard():
    users = fetch_users()
    stats = calculate_stats(users)
    
    return rx.vstack(
        user_stats_card(stats),
        user_table(users)
    )
```

---

### DRY (Don't Repeat Yourself)

**Extract common patterns**

```python
# Bad: Repetition
st.text_input("First Name", key="first_name")
st.text_input("Last Name", key="last_name")
st.text_input("Email", key="email")

# Good: Abstraction
def labeled_input(label, key):
    return st.text_input(label, key=key)

for field in ["First Name", "Last Name", "Email"]:
    labeled_input(field, field.lower().replace(" ", "_"))
```

---

## Best Practices

### Accessibility

**Make UIs usable for everyone**

**Key principles:**
- Semantic HTML
- Keyboard navigation
- Screen reader support
- Color contrast
- Focus indicators

```python
# Good: Accessible form
def accessible_form():
    return rx.form(
        rx.form_label("Email", html_for="email"),
        rx.input(
            id="email",
            type="email",
            aria_required="true",
            aria_describedby="email-help"
        ),
        rx.form_helper_text(
            "We'll never share your email",
            id="email-help"
        ),
        rx.button(
            "Submit",
            type="submit",
            aria_label="Submit form"
        )
    )
```

**Tools:**
- WAVE browser extension
- axe DevTools
- Lighthouse accessibility audit

---

### Performance

**Keep UIs fast and responsive**

**Strategies:**

1. **Lazy loading**
```python
# Load data only when needed
@st.cache_data
def load_large_dataset():
    return pd.read_csv("large_file.csv")

# Only load when tab is selected
tab1, tab2 = st.tabs(["Summary", "Details"])
with tab1:
    st.write("Quick summary")
with tab2:
    data = load_large_dataset()  # Only loads when tab2 is clicked
    st.dataframe(data)
```

2. **Caching**
```python
# Streamlit
@st.cache_data(ttl=3600)  # Cache for 1 hour
def fetch_data():
    return expensive_api_call()

# Reflex
class State(rx.State):
    _data_cache: dict = {}
    
    def get_data(self, key):
        if key not in self._data_cache:
            self._data_cache[key] = fetch_data(key)
        return self._data_cache[key]
```

3. **Pagination**
```python
# Limit data shown at once
page_size = 50
page = st.number_input("Page", min_value=1, value=1)
start = (page - 1) * page_size
end = start + page_size

st.dataframe(df.iloc[start:end])
```

4. **Debouncing**
```python
# HTMX: Wait for user to stop typing
<input 
    hx-get="/search"
    hx-trigger="keyup changed delay:500ms"
    hx-target="#results"
/>
```

---

### Responsive Design

**Work on all screen sizes**

**Approaches:**

1. **Mobile-first**
```python
# Streamlit: Automatic responsive
st.columns([1, 2, 1])  # Stacks on mobile

# Reflex: Responsive props
rx.box(
    width=["100%", "50%", "33%"],  # mobile, tablet, desktop
    padding=["1em", "2em", "3em"]
)
```

2. **Breakpoints**
```python
# Tailwind CSS classes
rx.box(
    class_name="w-full md:w-1/2 lg:w-1/3"
)
```

3. **Flexible layouts**
```python
# Use flex/grid
rx.flex(
    rx.box("Item 1", flex="1"),
    rx.box("Item 2", flex="2"),
    wrap="wrap"
)
```

---

### Error Handling

**Graceful failure and recovery**

**Patterns:**

1. **Try-catch with user feedback**
```python
try:
    result = risky_operation()
    st.success("Operation completed!")
except ValueError as e:
    st.error(f"Invalid input: {e}")
except ConnectionError:
    st.error("Network error. Please try again.")
except Exception as e:
    st.error("An unexpected error occurred")
    logging.error(f"Error: {e}", exc_info=True)
```

2. **Fallback UI**
```python
def safe_render(component_fn):
    try:
        return component_fn()
    except Exception as e:
        logging.error(f"Component error: {e}")
        return rx.box(
            rx.text("Something went wrong"),
            rx.button("Retry", on_click=State.retry)
        )
```

3. **Validation**
```python
def validate_form(data):
    errors = []
    
    if not data.get("email"):
        errors.append("Email is required")
    elif not is_valid_email(data["email"]):
        errors.append("Invalid email format")
    
    if data.get("age", 0) < 18:
        errors.append("Must be 18 or older")
    
    return errors

# Use
errors = validate_form(form_data)
if errors:
    for error in errors:
        st.error(error)
else:
    save_data(form_data)
```

---

### Security

**Protect users and data**

**Key practices:**

1. **Input sanitization**
```python
import bleach

user_input = st.text_area("Comment")
safe_input = bleach.clean(user_input)
```

2. **CSRF protection**
```python
# Flask
from flask_wtf.csrf import CSRFProtect
csrf = CSRFProtect(app)

# FastAPI
from fastapi_csrf_protect import CsrfProtect
```

3. **Authentication**
```python
# Streamlit
def check_auth():
    if "authenticated" not in st.session_state:
        st.session_state.authenticated = False
    
    if not st.session_state.authenticated:
        username = st.text_input("Username")
        password = st.text_input("Password", type="password")
        
        if st.button("Login"):
            if authenticate(username, password):
                st.session_state.authenticated = True
                st.rerun()
            else:
                st.error("Invalid credentials")
        st.stop()

check_auth()
# Rest of app only runs if authenticated
```

4. **Environment variables**
```python
import os
from dotenv import load_dotenv

load_dotenv()
API_KEY = os.getenv("API_KEY")  # Never hardcode secrets
```

---

## Architecture Decision Framework

### When to use each pattern

**MVC:**
- Traditional web apps
- Server-side rendering
- Simple CRUD operations

**MVVM:**
- Reactive UIs
- Data-driven dashboards
- Two-way binding needed

**MVP:**
- Testing is critical
- Complex business logic
- Need to swap views

**Component-based:**
- Large applications
- Reusable UI elements
- Team collaboration

### State management decision

**Local state when:**
- Component-specific
- Not shared
- Simple toggle/input

**Global state when:**
- App-wide data
- User session
- Shared settings

**Reactive state when:**
- Real-time updates
- Live data feeds
- Collaborative features

**Immutable state when:**
- Predictability critical
- Undo/redo needed
- Time-travel debugging

---

## Resources

### Tools
- **Figma** - UI design and prototyping
- **Excalidraw** - Quick wireframes
- **Chrome DevTools** - Performance profiling
- **Lighthouse** - Accessibility and performance audits

### Learning
- **MDN Web Docs** - Web standards reference
- **A11y Project** - Accessibility guidelines
- **Web.dev** - Performance best practices
- **Component Gallery** - UI pattern examples

### Testing
- **Playwright** - End-to-end testing
- **pytest** - Unit testing
- **axe** - Accessibility testing
- **Lighthouse CI** - Automated audits

---

## Related Documentation

- [Web UI Guide](web_ui_guide__t__.md) - Framework selection
- [UI Runbooks](../../runbooks/ui/) - Implementation details
- [Testing Guide](../testing_guide__t__.md) - Testing strategies
- [Building Guide](../building_guide__t__.md) - Development workflow
