# `pyve.toml` Reference

From v3.0, every Pyve project is described by a single root-level **`pyve.toml`** manifest. It declares the project's environments and which language plugins own them; Pyve reads it to materialize, activate, diagnose, and tear down everything in the project.

`pyve.toml` is the **declaration**. Everything under `.pyve/` is materialized **state** (environments, locks, sentinels, backups) — never configuration. You edit `pyve.toml`; Pyve manages `.pyve/`.

!!! note "Coming from v2?"
    v2 split configuration across `.pyve/config` (YAML) and `[tool.pyve.testenvs.*]` in `pyproject.toml`. v3 consolidates both into `pyve.toml`. Run [`pyve self migrate`](migration.md) to generate it from your v2 sources — you rarely need to write it by hand.

## A minimal manifest

The smallest useful manifest names the project and declares one environment:

```toml
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
```

In practice you rarely need even this much: a project with **no** `pyve.toml` (or one with no `[plugins.*]` blocks) is treated as an implicit single-Python project rooted at `.`. The manifest earns its keep once you have more than one environment, more than one language, or a sub-tree layout.

## Top-level keys

| Key | Type | Default | Notes |
|---|---|---|---|
| `pyve_schema` | string | `"3.0"` | Manifest schema version. `"3.0"` is the only valid value today; any other literal is a hard error. |

```toml
[project]
name = "demo"   # display name; optional
```

## `[env.<name>]` — environment blocks

Each `[env.<name>]` block declares one project environment. The name keys the on-disk state directory (`.pyve/envs/<name>/<backend>/`) and is how you select the environment (`pyve test --env <name>`, `pyve env run <name> -- …`). Every field is optional — Pyve applies documented defaults.

```toml
[env.root]
purpose  = "utility"     # run | test | utility | temp
backend  = "venv"        # plugin-registered backend name
path     = "."           # working / detection root (monorepo support)
default  = false          # at most one env may set true
lazy     = false          # opt-in lazy provisioning

# Structured, advisory attributes (surfaced in check / status)
app_type   = "library"
languages  = ["python"]
frameworks = ["sveltekit"]

# Dependency source (mutually exclusive: pick at most one)
requirements = ["requirements-dev.txt"]
extra        = "dev"
manifest     = "tests/env.yml"

# Optional advisory steps Pyve surfaces but never runs
manual_steps = ["Open Xcode and accept the license"]

[env.testenv]
purpose = "test"
default = true
```

### Field semantics

| Field | Type | Default | Notes |
|---|---|---|---|
| `purpose` | enum | name-based (see below) | One of `run`, `test`, `utility`, `temp`. Drives purpose-gated selectors. |
| `backend` | string | plugin default | A backend the owning plugin registered (e.g. `venv`, `micromamba`, `pnpm`). |
| `path` | string | `"."` | Working / detection root. Non-`.` makes the env a *visitor* at a sub-tree (monorepos). |
| `default` | bool | `false` | At most one env per manifest may set `true`. |
| `lazy` | bool | `false` | Provision on first targeted use instead of at `init`. |
| `app_type` | string | `""` | Advisory metadata. |
| `languages` | list | `[]` | Advisory metadata, surfaced in `check`/`status`. |
| `frameworks` | list | `[]` | Advisory metadata (e.g. `["sveltekit"]`). |
| `requirements` | list | `[]` | Dependency source — requirements files. Mutually exclusive with `extra` / `manifest`. |
| `extra` | string | `""` | Dependency source — a `[project.optional-dependencies]` extra. Mutually exclusive. |
| `manifest` | string | `""` | Dependency source — a conda `environment.yml` (micromamba backends). Mutually exclusive. |
| `manual_steps` | list | `[]` | Advisory steps Pyve prints but never executes. |

### Name-based purpose defaults

When `purpose` is omitted, Pyve resolves it from the env name:

| Env name | Default purpose |
|---|---|
| `testenv` | `test` |
| `root` | `utility` |
| anything else | `utility` |

An explicit `purpose` always wins. The closed vocabulary (`run`, `test`, `utility`, `temp`) and its meaning are documented on the [Named Environments](environments.md) page.

## `[plugins.<name>]` — language plugins

A `[plugins.<name>]` block activates a language plugin and tells it which sub-tree it owns. The only core key is `path`; every other key is **provider-private** and passed through to the plugin verbatim.

```toml
[plugins.python]
path = "."

[plugins.node]
path = "frontend"
```

If you declare **no** `[plugins.*]` blocks at all, Pyve implicitly activates the Python plugin at `path = "."` — this is the migration shape for every v2-era project. Declaring any plugin block turns the implicit behavior off, so a Node-only project declares `[plugins.node]` explicitly.

!!! warning "One plugin owns the root"
    At most one plugin may resolve to `path = "."`. Two plugins both claiming the project root is a manifest error. In a polyglot repo, give the secondary stack its own sub-path (e.g. `path = "frontend"`). See [Polyglot Projects](polyglot.md).

## Validation

Pyve validates the manifest at read time and reports precise, line-attributed errors:

1. `pyve_schema` must equal `"3.0"` (absent ⇒ defaulted; any other value ⇒ error).
2. Each env's `purpose`, when present, must be one of `run` / `test` / `utility` / `temp`.
3. At most one env may declare `default = true`.
4. Per env, at most one of `requirements` / `extra` / `manifest` may be declared.
5. At most one plugin may resolve to `path = "."`.

## Worked examples

=== "Single Python project"

    ```toml
    pyve_schema = "3.0"

    [project]
    name = "my-lib"

    [env.root]
    purpose = "utility"
    backend = "venv"

    [env.testenv]
    purpose = "test"
    requirements = ["requirements-dev.txt"]
    ```

=== "Node-only project"

    ```toml
    pyve_schema = "3.0"

    [project]
    name = "web-app"

    [plugins.node]
    path = "."

    [env.root]
    purpose = "run"
    backend = "pnpm"
    ```

=== "Polyglot (Python API + SvelteKit)"

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

    [env.web]
    purpose = "run"
    backend = "pnpm"
    path = "frontend"
    frameworks = ["sveltekit"]
    ```

## See also

- [Named Environments](environments.md) — the `purpose` vocabulary and the multi-env model.
- [Backends](backends.md) — what `backend` values mean and how they are categorized.
- [Plugins](plugins.md) — the plugin contract and the reference plugins.
- [Polyglot Projects](polyglot.md) — the `path` model for multi-stack repos.
- [Migration](migration.md) — generating `pyve.toml` from a v2 project.
