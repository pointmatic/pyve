# Flask + HTMX Operations Runbook

## Overview

Flask is a lightweight Python web framework. HTMX adds interactivity without JavaScript frameworks.

**Key features:**
- Simple, flexible
- Server-side logic
- HTMX for interactivity
- Minimal JavaScript

**Best for:** Custom web apps, internal tools, when you need full control

---

## Installation

```bash
pip install flask
```

---

## Basic Flask App

```python
from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True)
```

**templates/index.html:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>My App</title>
</head>
<body>
    <h1>Hello Flask!</h1>
</body>
</html>
```

---

## HTMX Integration

**Add HTMX:**
```html
<script src="https://unpkg.com/htmx.org@1.9.10"></script>
```

**Load content without page reload:**
```html
<button hx-get="/api/users" hx-target="#user-list">
    Load Users
</button>

<div id="user-list"></div>
```

```python
@app.route('/api/users')
def get_users():
    users = User.query.all()
    return render_template('users_partial.html', users=users)
```

**templates/users_partial.html:**
```html
<ul>
{% for user in users %}
    <li>{{ user.name }}</li>
{% endfor %}
</ul>
```

---

## Forms with HTMX

```html
<form hx-post="/submit" hx-target="#result">
    <input type="text" name="name" required>
    <input type="email" name="email" required>
    <button type="submit">Submit</button>
</form>

<div id="result"></div>
```

```python
from flask import request

@app.route('/submit', methods=['POST'])
def submit():
    name = request.form['name']
    email = request.form['email']
    
    # Save to database
    user = User(name=name, email=email)
    db.session.add(user)
    db.session.commit()
    
    return f'<p class="success">Saved {name}!</p>'
```

---

## Delete with Confirmation

```html
<button 
    hx-delete="/api/users/{{ user.id }}"
    hx-confirm="Are you sure?"
    hx-target="closest tr"
    hx-swap="outerHTML">
    Delete
</button>
```

```python
@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    user = User.query.get_or_404(user_id)
    db.session.delete(user)
    db.session.commit()
    return ''  # Empty response removes element
```

---

## Search with Debounce

```html
<input 
    type="search"
    name="query"
    hx-get="/search"
    hx-trigger="keyup changed delay:500ms"
    hx-target="#results">

<div id="results"></div>
```

```python
@app.route('/search')
def search():
    query = request.args.get('query', '')
    results = User.query.filter(User.name.contains(query)).all()
    return render_template('results_partial.html', results=results)
```

---

## Infinite Scroll

```html
<div id="content">
    {% for item in items %}
        <div>{{ item.name }}</div>
    {% endfor %}
</div>

{% if has_more %}
<div hx-get="/load-more?page={{ page + 1 }}" 
     hx-trigger="revealed"
     hx-swap="outerHTML">
    Loading...
</div>
{% endif %}
```

```python
@app.route('/load-more')
def load_more():
    page = int(request.args.get('page', 1))
    items = Item.query.paginate(page=page, per_page=20)
    
    return render_template('items_partial.html', 
                          items=items.items,
                          page=page,
                          has_more=items.has_next)
```

---

## Authentication

```python
from flask import session, redirect, url_for
from functools import wraps

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        user = User.query.filter_by(username=username).first()
        if user and user.check_password(password):
            session['user_id'] = user.id
            return redirect(url_for('dashboard'))
        
        return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html')

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect(url_for('login'))
```

---

## Deployment

### Gunicorn

```bash
pip install gunicorn

# Run
gunicorn -w 4 -b 0.0.0.0:8000 app:app
```

### Docker

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8000", "app:app"]
```

---

## References

- **Flask:** https://flask.palletsprojects.com/
- **HTMX:** https://htmx.org/
- **HTMX Examples:** https://htmx.org/examples/

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **FastAPI Runbook:** `fastapi_jinja2_runbook__t__.md`
