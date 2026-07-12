# `pyve.toml` Reference

From v3.0, every Pyve project is described by a single root-level **`pyve.toml`** manifest. It declares the project's environments and which language plugins own them; Pyve reads it to materialize, activate, diagnose, and tear down everything in the project.

`pyve.toml` is the **declaration**. Everything under `.pyve/` is materialized **state** (environments, locks, sentinels, backups) — never configuration. You edit `pyve.toml`; Pyve manages `.pyve/`.

!!! note "Coming from v2?"
    v2 split configuration across `.pyve/config` (YAML) and `[tool.pyve.testenvs.*]` in `pyproject.toml`. v3 consolidates both into `pyve.toml`, and as of v3.1 the v2 sources are no longer read — re-run `pyve init` to generate the manifest (see [Migration](migration.md)). You rarely write it by hand: `pyve init` generates it, and [`pyve env sync`](environments.md#planning-environments-with-project-guide) reconciles a planned env spec into it.

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
name = "demo"                  # display name; optional
pyve_defaults_version = "1"    # stamped by pyve init; see below
```

`pyve_defaults_version` records which **defaults-set** the project was created with. A default is resolved once and frozen into the manifest — a later Pyve release changing a built-in default never mutates an existing repo. When the repo's stamp trails the current set, `pyve check` reports the changed defaults in an info-only `[defaults]` section (never applied automatically).

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

# Setup directives (composable — they layer in a fixed order)
editable     = ".[dev]"
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
| `isolated` | bool | `false` | This env is deliberately isolated: the [silent-skip advisory](testing.md#choosing-which-environment-runs-your-tests) stays quiet when the env is the `pyve test --env` target. Target-side only — a marked env still appears as a candidate when another env is targeted. |
| `app_type` | string | `""` | Advisory metadata. |
| `languages` | list | `[]` | Advisory metadata, surfaced in `check`/`status`. |
| `frameworks` | list | `[]` | Advisory metadata (e.g. `["sveltekit"]`). |
| `editable` | string | `""` | Setup directive — editable self-install target with optional extras (`pip install -e <value>`, e.g. `".[dev]"`). |
| `requirements` | list | `[]` | Setup directive — requirements files (`pip install -r <file> …`). |
| `extra` | string | `""` | Setup directive — a `[project.optional-dependencies]` extra, resolved to its package list. |
| `manifest` | string | `""` | Setup directive — a conda `environment.yml` (micromamba backends; the conda base layer). |
| `manual_steps` | list | `[]` | Advisory steps Pyve prints but never executes. |

### Setup directives — a composable recipe

An `[env.<name>]` block declares **how the environment is set up**: a composable recipe of setup directives, each a high-level intent the owning plugin knows how to realize. The directives layer — declare any combination — and materialize in one fixed order:

1. `manifest` — the conda base (micromamba backends only; solved first so pip layers sit on top)
2. `editable` — editable self-install with extras
3. `requirements` — requirements files
4. `extra` — the resolved optional-dependency group

`pyve env init <name>` materializes the **whole recipe in one shot**, and validates it up front — a bad directive (missing requirements file, unresolvable extra) fails before any layer installs. Rebuilding is a single command: `pyve env init <name> --force` purges and re-materializes the env from its declaration. A block that declares a single directive is simply a one-item recipe, so pre-existing manifests behave exactly as before.

The vocabulary is **closed and declarative** — directives are plugin-interpreted intents, never shell steps. (The v2 `[tool.pyve.testenvs.*]` surface keeps its historical pick-at-most-one rule; composition is a `pyve.toml` capability.)

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
4. At most one plugin may resolve to `path = "."`.

Setup directives (`editable` / `requirements` / `extra` / `manifest`) **compose** — declaring several in one block is valid and materializes in the fixed order above.

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

=== "CLI project (composed recipe)"

    ```toml
    pyve_schema = "3.0"

    [project]
    name = "my-cli"

    [env.root]
    purpose = "utility"
    backend = "venv"

    # Tests exercise console entry points, so the test env carries an
    # editable self-install (with an extras group) AND the dev tooling —
    # one `pyve env init testenv` materializes both.
    [env.testenv]
    purpose = "test"
    editable = ".[corruptions]"
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
