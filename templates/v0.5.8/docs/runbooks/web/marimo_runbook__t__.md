# Marimo Operations Runbook

## Overview

Marimo is a reactive Python notebook that can be run as an app. Git-friendly, reactive, pure Python.

**Key features:**
- Reactive (auto-updates)
- Git-friendly (Python files, not JSON)
- Can run as app or notebook
- Interactive UI elements

**Best for:** Exploratory work, reactive notebooks, prototypes that become apps

---

## Installation

```bash
pip install marimo

# Create notebook
marimo edit notebook.py

# Run as app
marimo run notebook.py
```

---

## Basic Notebook

```python
import marimo as mo

# Reactive slider
slider = mo.ui.slider(0, 100, value=50)
slider

# Automatically updates when slider changes
mo.md(f"Value: {slider.value}")
```

---

## UI Elements

```python
import marimo as mo

# Text input
text_input = mo.ui.text(placeholder="Enter name")

# Number input
number_input = mo.ui.number(start=0, stop=100, value=50)

# Dropdown
dropdown = mo.ui.dropdown(["A", "B", "C"])

# Checkbox
checkbox = mo.ui.checkbox(label="I agree")

# Button
button = mo.ui.button(label="Click me")

# Date
date_picker = mo.ui.date()
```

---

## Reactive Dataframes

```python
import marimo as mo
import pandas as pd

df = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})

# Interactive table
table = mo.ui.table(df)
table

# Selected rows automatically available
mo.md(f"Selected: {table.value}")
```

---

## Deployment

```bash
# Run as web app
marimo run notebook.py --port 8000

# Export to HTML
marimo export html notebook.py > app.html
```

---

## References

- **Documentation:** https://marimo.io/docs
- **GitHub:** https://github.com/marimo-team/marimo

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **Streamlit Runbook:** `streamlit_runbook__t__.md`
