# Named Environments

A Pyve project can declare **many** environments, each with a name and a **purpose**. This replaces the v2 split between "the main env" and "testenvs" with one uniform model: every environment is an `[env.<name>]` block in [`pyve.toml`](pyve-toml.md), and Pyve materializes each under `.pyve/envs/<name>/<backend>/`.

The common case stays zero-config — one runtime env plus one test env — but the model scales to a lint env, a docs env, a conda-backed env for native deps, and so on, all selected by name.

## The `purpose` vocabulary

Every environment carries a `purpose` drawn from a closed set of four values:

| Purpose | Meaning |
|---|---|
| `run` | The application's runtime environment — what your code actually runs in. |
| `test` | A test-runner environment (pytest, vitest, …). `pyve test --env <name>` only accepts `test`-purpose envs. |
| `utility` | General-purpose dev tooling — formatters, linters, type checkers, project helpers. |
| `temp` | Ephemeral, one-shot environments — candidates for automatic pruning. |

`purpose` drives **purpose-gated selectors**: for example, `pyve test --env web` hard-errors if `web`'s resolved purpose is not `test`, pointing you at `pyve env run web -- …` instead. The gate keeps "run a command somewhere" and "run the test suite" from quietly blurring together.

### Name-based defaults

If you omit `purpose`, Pyve resolves it from the environment name, so the everyday shapes need no annotation:

| Env name | Default purpose |
|---|---|
| `testenv` | `test` |
| `root` | `utility` |
| anything else | `utility` |

An explicit `purpose` always wins over the default.

## Reserved names

Two names are reserved:

- **`root`** — the project's main environment (`.venv/` for venv, the conda prefix for micromamba). It is selection-only; you cannot redeclare it as a user testenv, but you *can* declare an `[env.root]` block to set its `backend`/`purpose`.
- **`testenv`** — the well-known default test environment. It resolves to `.pyve/envs/testenv/<backend>/` and **may** be redeclared to override its defaults.

## On-disk layout

Every declared environment materializes under one root, with one shape per backend:

```
.pyve/
  envs/
    root/
      venv/         # venv-backed
    testenv/
      venv/
    web/
      conda/        # micromamba-backed
```

You never construct these paths by hand — Pyve's commands resolve them for you. The single-root, one-shape-per-backend layout is what lets every plugin (and future plugins) slot in cleanly.

## The `pyve env` namespace

Named environments are managed through the `pyve env` namespace:

| Command | What it does |
|---|---|
| `pyve env init [<name>]` | Create a named environment. |
| `pyve env install [<name>] [-r <file>]` | Install dependencies into a named environment. |
| `pyve env run [<name> --] <cmd>` | Run a command inside a named environment. |
| `pyve env purge [<name>]` | Remove a named environment. |
| `pyve env list` | List declared and on-disk environments (name, backend, size, last-used, state). |
| `pyve env prune` | Remove orphaned or unused environments. |
| `pyve env sync` | Reconcile `pyve.toml` with the env spec (`docs/specs/env-dependencies.md` §4): diff, then `[Y/n]`-apply. Writes `pyve.toml` only — never materializes. |

!!! info "Planning environments"
    `pyve env sync` ingests an env spec authored by `project-guide mode plan_envs` and reconciles it into `pyve.toml` (destructive drops / backend flips default to `No`). `pyve check` surfaces drift between the spec and `pyve.toml` as an advisory warning. The full *plan → sync* workflow will get its own section in a future docs pass.

!!! note "`pyve testenv` is the old spelling"
    `pyve testenv <sub>` still works as a deprecated alias for `pyve env <sub>` — it re-dispatches with a one-shot warning. It is scheduled for removal in v4.0. New scripts should use `pyve env`.

### Selecting an env for tests

`pyve test` runs in a `test`-purpose environment. With no flag it uses the default test env; `--env` selects a specific one, and a comma-separated list runs a matrix:

```bash
pyve test                       # default test env
pyve test --env testenv         # a specific test env
pyve test --env unit,integration   # run both, serially, aggregating exit codes
```

## Dependency sources

A test or utility env declares **where its dependencies come from** via one of three mutually-exclusive fields on its `[env.<name>]` block:

```toml
[env.testenv]
purpose = "test"
requirements = ["requirements-dev.txt"]   # one or more requirements files

[env.lint]
purpose = "utility"
extra = "lint"                            # a [project.optional-dependencies] extra

[env.native]
purpose = "test"
backend = "micromamba"
manifest = "tests/env.yml"                # a conda environment.yml
```

See [`pyve.toml` Reference](pyve-toml.md) for the full field list.

## Lazy provisioning

Mark an env `lazy = true` to defer its creation until something actually targets it:

```toml
[env.integration]
purpose = "test"
lazy = true
requirements = ["requirements-integration.txt"]
```

`pyve init` skips a lazy env; the first `pyve test --env integration` provisions it on demand. Set `PYVE_NO_AUTO_PROVISION=1` (e.g. in strict CI) to turn that auto-provision into a hard error with an explicit `pyve env install` hint instead.

## Survives `pyve init --force`

Test and utility environments are declared separately from the run environment and live in their own `.pyve/envs/<name>/` slots, so a destructive `pyve init --force` rebuild of the main env **does not** wipe them. This is by design — rebuilding your app env shouldn't cost you your test toolchain.

## See also

- [`pyve.toml` Reference](pyve-toml.md) — the manifest schema.
- [Testing](testing.md) — the two-environment model and the test-env lifecycle.
- [Backends](backends.md) — what backs each environment.
