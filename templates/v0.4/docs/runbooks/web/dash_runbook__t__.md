# Dash Operations Runbook

## Overview

Dash is a Python framework for building analytics dashboards. Built on Plotly, Flask, and React.

**Key features:**
- Excellent for data visualization
- Callback-based interactivity
- Mature, stable
- Enterprise support available

**Best for:** Analytics dashboards, Plotly-heavy apps, enterprise analytics

---

## Installation

```bash
pip install dash
```

---

## Basic App

```python
from dash import Dash, html, dcc

app = Dash(__name__)

app.layout = html.Div([
    html.H1("My Dashboard"),
    html.P("Welcome to Dash"),
    dcc.Graph(
        figure={
            'data': [{'x': [1, 2, 3], 'y': [4, 1, 2], 'type': 'bar'}],
            'layout': {'title': 'Sales'}
        }
    )
])

if __name__ == '__main__':
    app.run_server(debug=True)
```

---

## Callbacks

```python
from dash import Dash, html, dcc, callback, Input, Output
import plotly.express as px
import pandas as pd

app = Dash(__name__)

df = pd.DataFrame({
    'category': ['A', 'B', 'C'],
    'value': [10, 20, 30]
})

app.layout = html.Div([
    dcc.Dropdown(
        id='category-dropdown',
        options=[{'label': c, 'value': c} for c in df['category']],
        value='A'
    ),
    dcc.Graph(id='bar-chart')
])

@callback(
    Output('bar-chart', 'figure'),
    Input('category-dropdown', 'value')
)
def update_chart(selected_category):
    filtered_df = df[df['category'] == selected_category]
    fig = px.bar(filtered_df, x='category', y='value')
    return fig

if __name__ == '__main__':
    app.run_server(debug=True)
```

---

## Components

```python
from dash import html, dcc

layout = html.Div([
    # Text
    html.H1("Heading"),
    html.P("Paragraph"),
    
    # Inputs
    dcc.Input(placeholder="Enter text", type="text"),
    dcc.Dropdown(options=['A', 'B', 'C'], value='A'),
    dcc.Slider(min=0, max=10, value=5),
    dcc.Checklist(options=['Option 1', 'Option 2']),
    dcc.RadioItems(options=['A', 'B']),
    
    # Graphs
    dcc.Graph(figure={}),
    
    # Date
    dcc.DatePickerSingle(),
    dcc.DatePickerRange(),
])
```

---

## Multi-Page Apps

```python
from dash import Dash, html, dcc, callback, Input, Output
import dash

app = Dash(__name__, use_pages=True)

app.layout = html.Div([
    html.H1("My App"),
    dcc.Link("Home", href="/"),
    dcc.Link("Analytics", href="/analytics"),
    dash.page_container
])

if __name__ == '__main__':
    app.run_server(debug=True)
```

**pages/home.py:**
```python
import dash
from dash import html

dash.register_page(__name__, path='/')

layout = html.Div([
    html.H2("Home Page")
])
```

---

## Deployment

### Docker

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8050
CMD ["python", "app.py"]
```

### Dash Enterprise

```bash
# Deploy to Dash Enterprise
git push plotly main
```

---

## References

- **Documentation:** https://dash.plotly.com/
- **Gallery:** https://dash.gallery/

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **Streamlit Runbook:** `streamlit_runbook__t__.md`
