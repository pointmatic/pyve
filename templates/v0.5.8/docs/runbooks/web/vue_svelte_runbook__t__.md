# Vue/Svelte Operations Runbook (Brief)

## Overview

Modern JavaScript frameworks for when Python-native solutions aren't enough. This runbook provides brief coverage for Python developers who need to reach for JS frameworks.

**When to use:**
- Very rich, interactive UI needed
- Real-time collaboration features
- Complex client-side state
- Mobile-like web experience

**When to avoid:**
- Python-native solution works
- Simple CRUD app
- Team is Python-only

---

## Vue

### Why Vue

**Pros:**
- Gentle learning curve
- Progressive (start small, grow big)
- Good documentation
- Large ecosystem

**Cons:**
- Need to learn JavaScript
- Build tooling complexity

### Quick Start

```bash
# Create Vue app
npm create vue@latest my-app

# Install dependencies
cd my-app
npm install

# Run dev server
npm run dev
```

### Basic Component

```vue
<template>
  <div>
    <h1>{{ title }}</h1>
    <button @click="increment">Count: {{ count }}</button>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const title = 'My App'
const count = ref(0)

function increment() {
  count.value++
}
</script>

<style scoped>
button {
  padding: 10px 20px;
}
</style>
```

### With Python Backend

**FastAPI backend:**
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],  # Vue dev server
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/users")
async def get_users():
    return [{"id": 1, "name": "Alice"}]
```

**Vue frontend:**
```vue
<script setup>
import { ref, onMounted } from 'vue'

const users = ref([])

onMounted(async () => {
  const response = await fetch('http://localhost:8000/api/users')
  users.value = await response.json()
})
</script>

<template>
  <ul>
    <li v-for="user in users" :key="user.id">
      {{ user.name }}
    </li>
  </ul>
</template>
```

---

## Svelte

### Why Svelte

**Pros:**
- Less code than React/Vue
- Fast performance (compiled)
- Simple mental model
- Growing ecosystem

**Cons:**
- Smaller ecosystem
- Newer (less mature)

### Quick Start

```bash
# Create Svelte app
npm create vite@latest my-app -- --template svelte

# Install dependencies
cd my-app
npm install

# Run dev server
npm run dev
```

### Basic Component

```svelte
<script>
  let count = 0
  
  function increment() {
    count += 1
  }
</script>

<h1>My App</h1>
<button on:click={increment}>
  Count: {count}
</button>

<style>
  button {
    padding: 10px 20px;
  }
</style>
```

### With Python Backend

**FastAPI backend:** (same as Vue example above)

**Svelte frontend:**
```svelte
<script>
  import { onMount } from 'svelte'
  
  let users = []
  
  onMount(async () => {
    const response = await fetch('http://localhost:8000/api/users')
    users = await response.json()
  })
</script>

<ul>
  {#each users as user}
    <li>{user.name}</li>
  {/each}
</ul>
```

---

## Deployment

### Build for Production

**Vue:**
```bash
npm run build
# Output in dist/
```

**Svelte:**
```bash
npm run build
# Output in dist/
```

### Serve with Python

```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# API routes
@app.get("/api/users")
async def get_users():
    return [{"id": 1, "name": "Alice"}]

# Serve Vue/Svelte build
app.mount("/", StaticFiles(directory="dist", html=True), name="static")
```

---

## Common Patterns

### State Management

**Vue (Pinia):**
```javascript
import { defineStore } from 'pinia'

export const useUserStore = defineStore('user', {
  state: () => ({
    users: []
  }),
  actions: {
    async fetchUsers() {
      const response = await fetch('/api/users')
      this.users = await response.json()
    }
  }
})
```

**Svelte (stores):**
```javascript
import { writable } from 'svelte/store'

export const users = writable([])

export async function fetchUsers() {
  const response = await fetch('/api/users')
  const data = await response.json()
  users.set(data)
}
```

### Routing

**Vue Router:**
```javascript
import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: Home },
    { path: '/about', component: About }
  ]
})
```

**SvelteKit (file-based):**
```
src/routes/
├── +page.svelte       # /
├── about/
│   └── +page.svelte   # /about
```

---

## When to Choose

**Choose Vue if:**
- Team learning frontend
- Need large ecosystem
- Want progressive adoption

**Choose Svelte if:**
- Want minimal code
- Performance critical
- Prefer compiled approach

**Choose React if:**
- Enterprise requirements
- Need every library
- Large team

**Stick with Python if:**
- Streamlit/Reflex works
- Team is Python-only
- Internal tool

---

## References

- **Vue:** https://vuejs.org/
- **Svelte:** https://svelte.dev/
- **SvelteKit:** https://kit.svelte.dev/
- **Vite:** https://vitejs.dev/

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **FastAPI Runbook:** `fastapi_jinja2_runbook__t__.md`
- **Flask Runbook:** `flask_htmx_runbook__t__.md`
