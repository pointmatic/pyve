# Reflex Operations Runbook

## Overview

Reflex is a modern Python framework for building full-stack web apps. Pure Python that compiles to React.

**Key features:**
- Pure Python (compiles to React)
- Component-based architecture
- Type-safe
- Built-in state management
- Can scale to complex apps

**Best for:** Full web apps, when Streamlit is too limiting, customer-facing applications

---

## Installation

```bash
pip install reflex

# Create new project
reflex init

# Run app
reflex run
```

**Access:** http://localhost:3000

---

## Basic App

```python
import reflex as rx

def index():
    return rx.container(
        rx.heading("Hello Reflex!"),
        rx.text("Welcome to your app"),
    )

app = rx.App()
app.add_page(index)
```

---

## State Management

```python
import reflex as rx

class State(rx.State):
    count: int = 0
    
    def increment(self):
        self.count += 1
    
    def decrement(self):
        self.count -= 1

def index():
    return rx.container(
        rx.heading("Counter"),
        rx.text(f"Count: {State.count}"),
        rx.button_group(
            rx.button("Increment", on_click=State.increment),
            rx.button("Decrement", on_click=State.decrement),
        ),
    )

app = rx.App()
app.add_page(index)
```

---

## Components

```python
import reflex as rx

def index():
    return rx.vstack(
        # Text
        rx.heading("Heading"),
        rx.text("Paragraph text"),
        
        # Inputs
        rx.input(placeholder="Enter text"),
        rx.text_area(placeholder="Enter description"),
        rx.select(["Option 1", "Option 2"]),
        rx.checkbox("I agree"),
        
        # Buttons
        rx.button("Click me"),
        
        # Layout
        rx.hstack(
            rx.box("Box 1"),
            rx.box("Box 2"),
        ),
        
        # Data
        rx.table(
            headers=["Name", "Age"],
            rows=[["Alice", 30], ["Bob", 25]],
        ),
    )
```

---

## Forms

```python
import reflex as rx

class FormState(rx.State):
    form_data: dict = {}
    
    def handle_submit(self, form_data):
        self.form_data = form_data

def index():
    return rx.container(
        rx.form(
            rx.vstack(
                rx.input(name="name", placeholder="Name"),
                rx.input(name="email", placeholder="Email"),
                rx.button("Submit", type="submit"),
            ),
            on_submit=FormState.handle_submit,
        ),
        rx.text(f"Submitted: {FormState.form_data}"),
    )
```

---

## Routing

```python
import reflex as rx

def index():
    return rx.text("Home Page")

def about():
    return rx.text("About Page")

app = rx.App()
app.add_page(index, route="/")
app.add_page(about, route="/about")
```

---

## Deployment

```bash
# Build for production
reflex export

# Deploy to hosting (static files in .web/_static)
```

---

## References

- **Documentation:** https://reflex.dev/docs/
- **Gallery:** https://reflex.dev/docs/gallery/

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **Streamlit Runbook:** `streamlit_runbook__t__.md`
