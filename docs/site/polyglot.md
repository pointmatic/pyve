# Polyglot Projects

A polyglot project runs more than one language stack in a single repository — for example a Python API beside a SvelteKit front end. Pyve treats this as a first-class case: you declare each stack as a plugin at its own `path`, and Pyve composes one activation, one `.gitignore`, and one health report across both.

This is the cross-stack coordination that single-ecosystem tools leave to you: PATH ordering, double-activation, and half-purges are easy to get subtly wrong by hand. Pyve owns the composition so you don't.

## The `path` model — root vs. visitor

Exactly one plugin owns the project **root** (`path = "."`). Every other plugin is a **visitor** rooted at a sub-tree:

```toml
pyve_schema = "3.0"

[project]
name = "fullstack-app"

[plugins.python]      # owns the root
path = "."

[plugins.node]        # visitor at frontend/
path = "frontend"
```

A visitor plugin confines all of its reads and writes to its sub-tree, and emits **project-root-relative** paths so direnv resolves them from where `.envrc` lives. The result is that two plugins never collide on the root, and the front-end's `node_modules/.bin` ends up on PATH as `frontend/node_modules/.bin`, not as a path that only works from inside `frontend/`.

!!! warning "Two roots is an error"
    If two plugins both resolve to `path = "."`, the manifest is rejected with a precise diagnostic. Give the secondary stack a real sub-path.

## A worked layout

```
fullstack-app/
├── pyve.toml
├── pyproject.toml          # Python (root)
├── src/
├── tests/
└── frontend/               # Node (visitor)
    ├── package.json
    └── src/
```

```toml
pyve_schema = "3.0"

[project]
name = "fullstack-app"

[plugins.python]
path = "."

[plugins.node]
path = "frontend"

[env.root]
purpose = "run"
backend = "venv"

[env.testenv]
purpose = "test"
requirements = ["requirements-dev.txt"]

[env.web]
purpose = "run"
backend = "pnpm"
path = "frontend"
frameworks = ["sveltekit"]
```

## What gets composed

Run a single command and Pyve fans it across both plugins:

| Command | Result in a polyglot repo |
|---|---|
| `pyve init` | Materializes the Python env at the root and the Node env under `frontend/`; writes one `.envrc` and one `.gitignore` carrying both stacks' sections. |
| `pyve check` | A Python section and a Node section, each labeled (visitors are path-prefixed, e.g. `[node @ frontend]`), rolled up to one exit code. |
| `pyve status` | Both stacks' read-only sections in one snapshot. |
| `pyve purge` | A combined inventory; only Pyve-created paths across both stacks are removed, never authored files like `package.json` or `pyproject.toml`. |

### One `.envrc`, two stacks

The composed `.envrc` carries one managed block per plugin, each wrapped in its own sentinel markers:

```bash
# >>> pyve:managed:start >>>
# >>> pyve:plugin:python:activate >>>
PATH_add ".venv/bin"
export VIRTUAL_ENV="$PWD/.venv"
# <<< pyve:plugin:python:activate <<<
# >>> pyve:plugin:node:activate >>>
PATH_add "frontend/node_modules/.bin"
# <<< pyve:plugin:node:activate <<<
# <<< pyve:managed:end <<<
```

Anything you write below the managed block is preserved verbatim across re-composition.

## Detection is advisory

When you run `pyve init` on a project that has a root `package.json` next to your Python files, Pyve **surfaces an advisory** ("Node project detected") but never silently rewrites `pyve.toml`. You opt the second stack in by adding its `[plugins.<name>]` block (or accepting the composed scaffold) — Pyve won't assume a sub-tree layout on your behalf.

## See also

- [Plugins](plugins.md) — the plugin contract and the reference plugins.
- [`pyve.toml` Reference](pyve-toml.md) — the `[plugins.<name>]` and `path` keys.
- [Named Environments](environments.md) — declaring per-stack environments.
