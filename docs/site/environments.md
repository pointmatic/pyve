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
| `pyve env init [<name>] [--force] [--yes]` | Create a named environment and materialize its declared setup recipe. `--force` = one-shot rebuild (purge, re-create, re-materialize); `--yes` skips the rebuild confirmation. |
| `pyve env install [<name>] [-r <file>]` | Install dependencies into a named environment. |
| `pyve env run [<name> --] <cmd>` | Run a command inside a named environment. |
| `pyve env purge [<name>\|--all]` | Remove the default env (bare), one named env, or every declared env (`--all`, with confirmation; `--yes` skips). |
| `pyve env list` | List declared and on-disk environments (name, backend, size, last-used, state). |
| `pyve env prune` | Remove orphaned or unused environments. |
| `pyve env sync` | Reconcile `pyve.toml` with the env spec (`docs/specs/env-dependencies.md` §4): diff, then `[Y/n]`-apply. Writes `pyve.toml` only — never materializes. |

!!! info "Planning environments"
    `pyve env sync` ingests an env spec authored by `project-guide mode plan_envs` and reconciles it into `pyve.toml`. See [Planning environments with project-guide](#planning-environments-with-project-guide) below for the full *plan → sync → materialize* workflow.

!!! note "`pyve testenv` is the old spelling"
    `pyve testenv <sub>` still works as a deprecated alias for `pyve env <sub>` — it re-dispatches with a one-shot warning. It is scheduled for removal in v4.0. New scripts should use `pyve env`.

### Selecting an env for tests

`pyve test` runs in a `test`-purpose environment. With no flag it uses the default test env; `--env` selects a specific one, and a comma-separated list runs a matrix:

```bash
pyve test                       # default test env
pyve test --env testenv         # a specific test env
pyve test --env unit,integration   # run both, serially, aggregating exit codes
```

## Planning environments with project-guide

For projects using [project-guide](https://pointmatic.github.io/project-guide/), the intended "configure your environments" path is a **plan → sync → materialize** loop:

1. **Plan** — `project-guide mode plan_envs` analyzes the project and authors the environment spec: §4 of `docs/specs/env-dependencies.md`, the analyzed-*ideal* env configuration at the current `spec_version`.
2. **Sync** — `pyve env sync` reconciles that spec into `pyve.toml`: it discovers the spec, diffs it against the current manifest, and applies the changes after a `[Y/n]` confirmation. Non-destructive changes default to **Yes**; **destructive** changes (dropping an env, flipping a backend) default to **No** — pass `--force` to apply those too. It writes `pyve.toml` only and never materializes anything. Exit code `6` means the spec is invalid under the closed vocabulary.
3. **Materialize** — the normal lifecycle commands build what the manifest now declares: `pyve env init <name>`, `pyve test`, `pyve init --force --all`.

The *why*: one declarative source of intent. The spec captures what the project's environments *should* be; `pyve.toml` records what you've accepted; the lifecycle commands materialize it. The spec may legitimately run ahead of what's materialized — that gap is visible, not silent.

**Drift is surfaced, never auto-applied.** When the spec and `pyve.toml` disagree (a non-empty §4 diff), `pyve check` prints an advisory warning with a "run `pyve env sync` to reconcile" hint — the exit code stays `0`. Pyve reads the spec's location from `.project-guide.yml`'s `env_spec_path` (default: `docs/specs/env-dependencies.md`).

**What syncs — the projectable subset.** Only spec attributes with a `pyve.toml` home participate in the diff: `name`, `purpose`, `backend`, `default`, `path`, `languages`, `frameworks`, `packaging`. Advisory/prose attributes (`app_type`, `require_min_version`, `manual_steps`, and the spec's narrative sections) never trigger drift. The full spec vocabulary is defined by the [env-spec contract](https://github.com/pointmatic/pyve/blob/main/docs/specs/project-guide-requests/wizard-env-contract.md).

## What `pyve init` materializes

`pyve init` materializes only what your `pyve.toml` **declares**, on a graduated *declared → materialized → operable* ladder:

- **The run (root) env** is materialized to its declared backend (`venv` / `micromamba`); an advisory `none` root is declarative-only — nothing is built (see [Backends](backends.md)).
- **The default test env** is materialized when it is declared *and* resolves to a `venv` backend. A conda-backed or additional named test env is **not** built at init (a conda solve is never run implicitly); run `pyve env init <name>` to materialize it.
- **No test env declared → none created.** `pyve init` never injects an undeclared `testenv`.

**Init installs what you declared — nothing you didn't.** A materialized env comes up with exactly what its block's [setup directives](pyve-toml.md#setup-directives-a-composable-recipe) declare: `pyve env init <name>` realizes the whole recipe in one shot, so a fully-declared env is operable immediately. A block with *no* setup directives comes up empty and populates on first `pyve test` / `pyve env install` (*empty until demand*).

A test env declared `purpose = "test"` with **no `default`** that Pyve can't unambiguously resolve is a **skeleton**: declared (so `pyve test --env <name>` and other purpose-keyed selectors resolve) and materialized on demand, but never autowired.

### Which env `pyve test` runs

With no `--env`, `pyve test` resolves the default test env:

- an explicit `default = true` always wins;
- otherwise, on a **single-backend** project (all declared envs share one backend) rooted on a Python backend with **exactly one** test env, that sole test env is auto-promoted to the default — no `default` needed;
- a **mixed-backend** project, **multiple** test envs without a default, or a non-Python / `none` root has **no** default: `pyve test` asks for an explicit `--env` rather than guessing.

## Setup directives

An env's `[env.<name>]` block declares **how the environment is set up** — a composable recipe of setup directives that layer in a fixed order (conda `manifest` → `editable` → `requirements` → `extra`):

```toml
[env.testenv]
purpose = "test"
editable = ".[corruptions]"               # editable self-install + extras
requirements = ["requirements-dev.txt"]   # composes — no mutual exclusion

[env.lint]
purpose = "utility"
extra = "lint"                            # a [project.optional-dependencies] extra

[env.native]
purpose = "test"
backend = "micromamba"
manifest = "tests/env.yml"                # the conda base; pip directives layer on top
```

A single-directive block is simply a one-item recipe. See the [`pyve.toml` Reference](pyve-toml.md#setup-directives-a-composable-recipe) for the vocabulary and ordering.

## Lazy provisioning

Mark an env `lazy = true` to defer its creation until something actually targets it:

```toml
[env.integration]
purpose = "test"
lazy = true
requirements = ["requirements-integration.txt"]
```

`pyve init` skips a lazy env; the first `pyve test --env integration` provisions it on demand. Set `PYVE_NO_AUTO_PROVISION=1` (e.g. in strict CI) to turn that auto-provision into a hard error with an explicit `pyve env install` hint instead.

## Deliberately isolated test envs

A project that runs several isolated `purpose = "test"` envs — per-framework smoke suites, a typecheck env, each with its own pytest — trips the [silent-skip advisory](testing.md#choosing-which-environment-runs-your-tests) on every `pyve test --env <name>` run. Declare the isolation to silence it:

```toml
[env.smoke-pytorch]
purpose = "test"
isolated = true
```

The advisory stays quiet when a marked env is the target, and still fires (listing all candidates, marked or not) when an unmarked env like the catch-all `testenv` is targeted. The per-shell `PYVE_NO_TESTENV_ADVISORY=1` env var remains as a one-off/CI override.

## Rebuilding — one verb per role

Because the declaration fully describes an env's setup, **rebuilding is a single command** — no purge/init/install choreography:

```bash
pyve env init testenv --force    # purge + re-create + re-materialize the recipe
```

`--force` escalates init to a destructive rebuild, so it asks `y/N` on interactive shells (`--yes` assents; CI skips the prompt automatically).

Each role has exactly one rebuild verb, and every wrong turn signposts the right one:

| Env | Rebuild | Upgrade deps | Purge | Run a command |
|---|---|---|---|---|
| `root` (the main project env) | `pyve init --force` | `pyve upgrade` | `pyve purge` | `pyve run <cmd>` |
| named (`testenv`, `lint`, …) | `pyve env init <name> --force` | `pyve upgrade --env <name>` | `pyve env purge <name>` | `pyve env run <name> -- <cmd>` |

`pyve init --force` rebuilds **only the root env** — named envs in their `.pyve/envs/<name>/` slots are untouched, by explicit contract. Rebuilding your app env never costs you your test toolchain, and `pyve env <verb> root` rejections point you back at the top-level verb that does the job. `pyve check` follows the same map: a structurally broken default test env is routed to `pyve env init testenv --force`; a healthy one that merely lacks pytest is routed to `pyve test`.

## See also

- [`pyve.toml` Reference](pyve-toml.md) — the manifest schema.
- [Testing](testing.md) — the two-environment model and the test-env lifecycle.
- [Backends](backends.md) — what backs each environment.
