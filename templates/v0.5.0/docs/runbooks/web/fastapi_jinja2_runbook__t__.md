# FastAPI + Jinja2 Operations Runbook

## Overview

FastAPI is a modern, async Python web framework. Jinja2 provides templating for HTML generation.

**Key features:**
- Fast (async)
- Automatic API docs
- Type hints
- Modern Python features

**Best for:** API + frontend combo, modern async apps, when you need speed

---

## Installation

```bash
pip install fastapi uvicorn jinja2 python-multipart
```

---

## Basic App

```python
from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

app = FastAPI()
templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**templates/index.html:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>My App</title>
</head>
<body>
    <h1>Hello FastAPI!</h1>
</body>
</html>
```

---

## Forms

```python
from fastapi import Form

@app.post("/submit")
async def submit(
    name: str = Form(...),
    email: str = Form(...)
):
    # Save to database
    return {"message": f"Saved {name}!"}
```

**HTML:**
```html
<form action="/submit" method="post">
    <input type="text" name="name" required>
    <input type="email" name="email" required>
    <button type="submit">Submit</button>
</form>
```

---

## HTMX Integration

```html
<script src="https://unpkg.com/htmx.org@1.9.10"></script>

<button hx-get="/api/users" hx-target="#user-list">
    Load Users
</button>

<div id="user-list"></div>
```

```python
@app.get("/api/users")
async def get_users(request: Request):
    users = await get_users_from_db()
    return templates.TemplateResponse(
        "users_partial.html",
        {"request": request, "users": users}
    )
```

---

## API Endpoints

```python
from pydantic import BaseModel

class User(BaseModel):
    name: str
    email: str

@app.post("/api/users")
async def create_user(user: User):
    # Save to database
    return {"id": 1, **user.dict()}

@app.get("/api/users/{user_id}")
async def get_user(user_id: int):
    # Get from database
    return {"id": user_id, "name": "Alice"}
```

**Automatic API docs:** http://localhost:8000/docs

---

## Authentication

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

@app.get("/protected")
async def protected_route(user = Depends(verify_token)):
    return {"message": f"Hello {user['username']}"}
```

---

## WebSockets

```python
from fastapi import WebSocket

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"Echo: {data}")
```

**HTML:**
```html
<script>
const ws = new WebSocket("ws://localhost:8000/ws");
ws.onmessage = (event) => {
    console.log(event.data);
};
ws.send("Hello");
</script>
```

---

## Background Tasks

```python
from fastapi import BackgroundTasks

def send_email(email: str):
    # Send email
    pass

@app.post("/register")
async def register(email: str, background_tasks: BackgroundTasks):
    background_tasks.add_task(send_email, email)
    return {"message": "Registration successful"}
```

---

## Deployment

### Uvicorn

```bash
# Development
uvicorn app:app --reload

# Production
uvicorn app:app --host 0.0.0.0 --port 8000 --workers 4
```

### Docker

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## References

- **FastAPI:** https://fastapi.tiangolo.com/
- **Jinja2:** https://jinja.palletsprojects.com/

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **Flask Runbook:** `flask_htmx_runbook__t__.md`
