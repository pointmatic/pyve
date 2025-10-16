# UI Runbooks

This directory contains operational runbooks for Python-friendly web UI frameworks and tools. These runbooks provide concrete setup instructions, code examples, and best practices for building user interfaces with minimal JavaScript.

## Purpose

These runbooks complement the general UI guide (`docs/guides/ui_guide__t__.md`) by providing platform-specific implementation details. Use the UI guide to understand **what** framework to choose and **when**, then refer to these runbooks for **how** to implement it.

## Available Runbooks

### Python-Native Frameworks (Write Only Python)
- **[Streamlit Runbook](streamlit_runbook__t__.md)** - Data apps, dashboards, rapid prototyping
- **[Gradio Runbook](gradio_runbook__t__.md)** - ML model interfaces, quick demos
- **[Reflex Runbook](reflex_runbook__t__.md)** - Full web apps, component-based architecture
- **[Marimo Runbook](marimo_runbook__t__.md)** - Reactive notebooks, exploratory apps
- **[Dash Runbook](dash_runbook__t__.md)** - Analytics dashboards, Plotly-based apps

### Python Web Frameworks + Templating
- **[Flask + HTMX Runbook](flask_htmx_runbook__t__.md)** - Lightweight, server-driven interactivity
- **[FastAPI + Jinja2 Runbook](fastapi_jinja2_runbook__t__.md)** - Modern, async, API-first

### Modern JS Frameworks (Brief Coverage)
- **[Vue/Svelte Runbook](vue_svelte_runbook__t__.md)** - When Python isn't enough

## Runbook Structure

Each runbook follows a consistent structure:

1. **Overview** - Framework capabilities and use cases
2. **Installation & Setup** - Getting started quickly
3. **Basic Concepts** - Core concepts and mental models
4. **Components/Widgets** - Available UI elements
5. **State Management** - Handling application state
6. **Layouts** - Organizing UI elements
7. **Interactivity** - User interactions and events
8. **Data Handling** - Working with data sources
9. **Authentication** - User authentication patterns
10. **Deployment** - Hosting and production deployment
11. **Best Practices** - Tips and common patterns
12. **Troubleshooting** - Common issues and solutions

## When to Use

- **UI guide first**: Start with `ui_guide__t__.md` to understand the decision framework and choose the right tool
- **Runbook for implementation**: Once you've chosen a framework, use the appropriate runbook for specific setup and code examples
- **Cross-reference**: Runbooks reference the UI guide for context and rationale

## Quick Selection Guide

**For quick prototypes:**
- Start with [Streamlit](streamlit_runbook__t__.md) or [Gradio](gradio_runbook__t__.md)

**For ML model demos:**
- Use [Gradio](gradio_runbook__t__.md) - simplest for input/output interfaces

**For data dashboards:**
- Try [Streamlit](streamlit_runbook__t__.md) first, [Dash](dash_runbook__t__.md) if you need more control

**For internal tools:**
- Consider [Reflex](reflex_runbook__t__.md) or [Flask + HTMX](flask_htmx_runbook__t__.md)

**For customer-facing apps:**
- Evaluate [Reflex](reflex_runbook__t__.md), [FastAPI + HTMX](fastapi_jinja2_runbook__t__.md), or [Vue/Svelte](vue_svelte_runbook__t__.md)

**For reactive notebooks:**
- Use [Marimo](marimo_runbook__t__.md) - great for exploration that becomes an app

## Contributing

When adding platform-specific details:
- Keep the UI guide general and conceptual
- Put specific commands, code examples, and procedures in runbooks
- Include version information for frameworks and dependencies
- Provide realistic, working examples
- Document common pitfalls and solutions

## Related Documentation

- **UI Guide**: `docs/guides/ui_guide__t__.md` - Decision framework and general concepts
- **UI Architecture Guide**: `docs/guides/ui_architecture_guide__t__.md` - Design patterns and principles (v0.3.11)
- **Analytics Runbooks**: `docs/runbooks/analytics/` - BI tools for data visualization
