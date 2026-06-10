# Testing

Pyve separates the project's **runtime environment** from a dedicated **test environment** (a `test`-purpose env, named `testenv` by default). This guide explains the two-environment model, the test-env lifecycle, how its Python inheritance differs by backend, and the activation-context rules that matter when you run env commands from a non-activated shell (or from an LLM agent).

!!! note "v3 names and paths"
    In v3.0 test environments are declared as `[env.<name>]` blocks in [`pyve.toml`](pyve-toml.md) (with `purpose = "test"`) and materialize at `.pyve/envs/<name>/<backend>/`. They are managed with the **`pyve env`** namespace. This page predates the rename in places: read `pyve testenv …` as `pyve env …` (the old spelling still works, with a warning), `.pyve/testenvs/<name>/` as `.pyve/envs/<name>/`, and `[tool.pyve.testenvs]` as the manifest's `[env.<name>]` blocks. See [Named Environments](environments.md) for the canonical model.

If you only want command reference, see the [`env` namespace](usage.md) in the Usage Guide. This page is the concept and how-to companion.

## Overview

Most Python projects install their test tooling (`pytest`, `ruff`, `mypy`, etc.) into the same virtual environment as their application dependencies. Pyve takes a different default: test tooling lives in a **separate environment** at `.pyve/envs/testenv/venv/`, isolated from the project's runtime environment.

The benefit is durability:

- `pyve init --force` rebuilds the runtime environment from scratch but **preserves the test env**.
- `pyve purge --keep-testenv` removes runtime artifacts but keeps your test tooling intact.
- Swapping Python versions or backends in the runtime env doesn't force you to reinstall pytest, ruff, and friends every time.

The trade-off is one extra command (`pyve env install testenv`) when you first set up dev tooling — a small price for a test environment that survives every destructive operation pyve offers.

Two envs is the **minimum**, not the maximum. Pyve supports **named environments** — declared in [`pyve.toml`](pyve-toml.md) as `[env.<name>]` blocks, each with its own `purpose`, backend, dependency source, and lifecycle policy. The two-env defaults below describe the implicit configuration; see [Named Environments](environments.md) for the full multi-env model.

## The two-environment model

A pyve project has two environments after `pyve init` and `pyve env init testenv`:

| Concern | Project environment | Test env |
|---|---|---|
| **What for** | Your application and its runtime dependencies | Test runner + dev tooling (pytest, ruff, mypy, black, …) |
| **Created by** | `pyve init` | `pyve env init testenv` |
| **Location (venv backend)** | `.venv/` | `.pyve/envs/testenv/venv/` |
| **Location (micromamba backend)** | `.pyve/envs/root/conda/` | `.pyve/envs/testenv/venv/` (default test env is always a plain venv) |
| **Activated by direnv?** | Yes (via `.envrc`) | No — invoked explicitly via `pyve test` / `pyve env run` |
| **Survives `pyve init --force`?** | No (rebuilt) | Yes |
| **Removed by `pyve purge`?** | Yes | Yes (unless `--keep-testenv`) |

The default test env is **always a plain Python venv** regardless of the project backend. Only its *base Python* differs by backend — see the next section. (Named environments may opt into the `micromamba` backend on a per-env basis; see [Named Environments](environments.md).)

!!! note "Migrating from v2"

    v2 projects carried test environments under `.pyve/testenvs/<name>/` and declared them in `pyproject.toml` under `[tool.pyve.testenvs]`. v3 consolidates state under `.pyve/envs/<name>/` and moves the declaration into `pyve.toml`'s `[env.<name>]` blocks. `pyve self migrate` performs the move; opportunistic migration also relocates a legacy testenv the first time it's needed. See the [Migration guide](migration.md).

## Backend deltas

`pyve testenv init` runs `python -m venv .pyve/testenvs/testenv/venv` against whichever `python` resolves on PATH at that moment. The active project environment determines that resolution:

| Backend | Source of `python` when testenv is created | Testenv Python ends up as |
|---|---|---|
| **venv** | `.venv/bin/python` (when direnv has activated the project env) | The same interpreter `.venv/` was built with — i.e., the asdf/pyenv-managed version pinned in `.tool-versions` / `.python-version` |
| **micromamba** | `.pyve/envs/<name>/bin/python` (when direnv has activated the project env) | The Python recorded in `environment.yml` (e.g. `python=3.12` → 3.12.x) |

!!! warning "Activation must be live when `pyve testenv init` runs"

    `pyve testenv init` does **not** activate the project environment for you. It uses whatever `python` is currently on PATH. If you run it from a shell where direnv hasn't activated the project env (a fresh terminal that hasn't `cd`'d in yet, a CI step, an LLM agent's subprocess), `python` will resolve to your *outer* shell's interpreter — typically an asdf/pyenv shim that may have no version pin, surfacing an error like "No version is set for command python."

    The fix is to make the project env active first, either by `cd`'ing into the directory under direnv or by wrapping the command:

    ```bash
    pyve run pyve testenv init
    pyve run pyve testenv install -r requirements-dev.txt
    ```

    See [Activation context](#activation-context) below.

If the project env's Python changes later (you bump `environment.yml` or `.tool-versions`), the testenv won't follow automatically. Pyve detects the drift the next time `pyve testenv init` runs and rebuilds the testenv against the new Python — but until then, the testenv stays on its original base.

## Testenv lifecycle

Six sub-commands; one file lives behind them all ([lib/commands/testenv.sh](https://github.com/pointmatic/pyve/blob/main/lib/commands/testenv.sh)). All `[<name>]` arguments are optional and default to the implicit `testenv`; for the named-envs case see [Named test environments](#named-test-environments).

### Create — `pyve testenv init [<name>]`

One-time. Creates `.pyve/testenvs/<name>/venv/` using the active project Python. Required before `install` or `run` will work — those subcommands deliberately do *not* auto-create the env.

```bash
pyve testenv init                  # implicit-default testenv
pyve testenv init smoke            # named env
```

### Install dependencies — `pyve testenv install [<name>] [-r <file>] [--no-wait]`

Without `<name>`, **iterates over every declared non-lazy env** (in the implicit-default config that's exactly one — the `testenv`). With `<name>`, installs into one specific env. `-r <file>` overrides any declared source for this run; declared `requirements = [...]` / `extra = "<n>"` / `manifest = "<env.yml>"` in `[tool.pyve.testenvs.<name>]` are used otherwise (see [Named test environments](#named-test-environments) for the source-precedence rules):

```bash
pyve testenv install                            # iterate all non-lazy envs (default config: just testenv with bare pytest fallback)
pyve testenv install -r requirements-dev.txt    # CLI override for the default env
pyve testenv install smoke                      # one named env, declared source
pyve testenv install heavy -r requirements-heavy.txt
```

A per-env install lock (`.pyve/testenvs/<name>/.lock/`) serializes concurrent installers of the same env; pass `--no-wait` to fast-fail instead of queuing.

The recommended pattern for the default env: maintain a `requirements-dev.txt` so the testenv is reproducible in two commands (`pyve testenv init && pyve testenv install -r requirements-dev.txt`).

### Run a tool — `pyve testenv run [<name> --] <cmd> [args...]`

Executes any command inside a testenv. With no name, runs in the implicit-default `testenv`; with a name, the `--` separator disambiguates name from command:

```bash
pyve testenv run ruff check .              # default testenv
pyve testenv run mypy src/
pyve testenv run smoke -- pytest -v        # named env: `smoke --` then the command
```

!!! note "venv-only"

    `pyve testenv run` activates the env via PATH (`<env>/bin` prepended, `VIRTUAL_ENV` exported) — sufficient for venv-backed envs but not for conda-backed ones, which need `CONDA_PREFIX` / `CONDA_PYTHON_EXE`. Conda-backed envs hard-error with a `micromamba run -p <env-path> <cmd>` workaround hint.

### Run tests — `pyve test [--env <name>[,<name>...]] [pytest args]`

Convenience shortcut for the common case. Equivalent to `pyve testenv run pytest`, plus an interactive auto-install prompt if pytest isn't yet installed and the [silent-skip advisory](#choosing-which-environment-runs-your-tests) for cross-env hints:

```bash
pyve test                                       # default env (testenv unless [tool.pyve.testenvs].default is set)
pyve test -q tests/integration/test_foo.py      # default env, pytest args pass through
pyve test --env root                            # bundled-env trap workaround (see below)
pyve test --env smoke                           # named env
pyve test --env smoke,heavy                     # matrix (sequential)
```

If pytest is missing, `pyve test` prompts to install it (interactive) or exits with instructions (non-interactive). Set `PYVE_TEST_AUTO_INSTALL_PYTEST=1` to auto-install in CI.

### List installed envs — `pyve testenv list`

Tabulates every testenv pyve knows about — the union of names declared in `[tool.pyve.testenvs]` and directories under `.pyve/testenvs/`:

```bash
pyve testenv list
```

Columns: `NAME / BACKEND / SIZE / LAST-USED / STATE`. `STATE` is one of `ready` (declared and on disk), `lazy` (declared `lazy = true`, not yet provisioned), `not provisioned` (declared non-lazy but absent from disk), or `orphaned` (on disk but not declared). `LAST-USED` is the ISO date of the most recent `pyve test --env <name>` (or `never` for envs that have never been run).

### Prune unused envs — `pyve testenv prune [--unused-since <YYYY-MM-DD>|--all] [--force]`

Three modes for clearing disk:

```bash
pyve testenv prune                          # remove every orphan (on-disk but not declared)
pyve testenv prune --unused-since 2026-01-01   # remove envs whose last use predates the cutoff
pyve testenv prune --all                    # remove every env on disk (declared and orphaned)
```

`--unused-since` reads each env's `.state.last_used_at`; envs that have never been used (`last_used_at = 0`) are preserved so freshly-provisioned envs are not eaten. Bad date format hard-errors before any disk walk.

`prune` is **disk-driven** — it walks `.pyve/testenvs/`. The distinct `pyve testenv purge` (next section) is **config-driven** — it walks `PYVE_TESTENVS_NAMES`. Both prompt `y/N` on an interactive TTY (skip with `--force`).

### Remove — `pyve testenv purge [<name>] [--force]`

With `<name>`, removes one env's directory. Without, removes every declared env (with confirmation):

```bash
pyve testenv purge                  # all declared envs (prompts y/N; --force skips)
pyve testenv purge smoke            # one env
pyve testenv purge --force          # all declared envs, no prompt
```

Backend-agnostic — works the same for venv and conda layouts. Re-run `pyve testenv init [<name>]` (and `install`) to recreate.

## Named test environments

The implicit-default config gives you one testenv (`.pyve/testenvs/testenv/venv/`). For projects that need multiple — a fast smoke env on every commit, a heavy GPU env on demand, a separate hardware-integration env, a per-Python-version matrix — declare them in `pyproject.toml`:

```toml
[tool.pyve.testenvs]
default = "smoke"            # what `pyve test` picks when --env is omitted

[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.smoke]
extra = "dev"                # resolves [project.optional-dependencies].dev

[tool.pyve.testenvs.heavy]
requirements = ["tests/heavy.txt"]
lazy = true                  # auto-provision on first `pyve test --env heavy`

[tool.pyve.testenvs.hardware]
backend = "micromamba"       # per-env backend — independent of the main env's backend
manifest = "tests/env.yml"
```

Each env materializes under `.pyve/testenvs/<name>/` (with `venv/` or `conda/` suffix depending on backend) and carries its own `.state` file tracking provisioning time and last-used time. The full schema (including the `requirements` / `extra` / `manifest` mutex and the `inherit` backend) lives in [features.md FR-11a](https://github.com/pointmatic/pyve/blob/main/docs/specs/features.md#fr-11a-named-test-environments-toolpyvetestenvs).

### Per-env dependency source

Each env declares one of three sources. The Python helper enforces the mutex at config-read time, so a single env never has more than one of these populated:

| Declaration | Backend | What gets installed |
|---|---|---|
| `requirements = ["a.txt", "b.txt"]` | venv | `pip install -r a.txt -r b.txt` |
| `extra = "dev"` | venv | `[project.optional-dependencies].dev` resolved to a package list, then `pip install ...` |
| `manifest = "env.yml"` | micromamba | `micromamba create/install -p <path> -f env.yml -y` |

If none of the three is declared on a venv-backed env, the install dispatch falls back to (in order): CLI `-r <file>` if given, auto-detected `requirements-dev.txt` in CWD, then bare `pytest`. This is what keeps the implicit-default `testenv` working without any declaration.

### Reserved names

| Name | `pyve test --env <name>` | `pyve testenv <op> <name>` |
|---|---|---|
| `root` | routes to the root project env via `run_command python -m pytest` | hard-errors — `root` is selection-only |
| `testenv` | the implicit default when no `[tool.pyve.testenvs]` block exists | always actionable (declared or implicit) |

You can't declare a user env named `root` or `testenv` — the config helper rejects it.

### Lazy provisioning

Heavy envs that you rarely use (multi-GB ML stacks, GPU runners, integration harnesses with a fragile install) should be marked `lazy = true`. Then:

- `pyve testenv install` (no name) **skips** the env in its iteration.
- `pyve test --env <lazy-name>` **auto-provisions** the env on first use: `ensure_testenv_exists` creates the venv, then the standard per-env install lock + declared-source dispatch installs dependencies, then pytest runs.
- For strict CI that prefers an explicit "is this env already built?" gate, set `PYVE_NO_AUTO_PROVISION=1` — the same flow hard-errors with a `pyve testenv install <lazy-name>` hint instead of building.

The auto-provision path acquires the same install lock (`mkdir`-based at `.pyve/testenvs/<name>/.lock/`) used by `pyve testenv install`, so two concurrent `pyve test --env <lazy-name>` calls serialize cleanly.

### Conda-backed test environments

Set `backend = "micromamba"` (with `manifest = "env.yml"`) on any named env to provision it through `micromamba create -p <path> -f <env.yml>`. This is independent of the main project backend — you can have a venv main env and a conda testenv, or vice versa. The `inherit` value resolves to whichever backend the main (`root`) env declares in `pyve.toml`.

Conda-backed envs have two current limitations:

- **`pyve testenv run` does not support them.** The activation pattern in `run` is PATH-only (`<env>/bin` prepended) which is insufficient for conda's `CONDA_PREFIX` / `CONDA_PYTHON_EXE`. Use `micromamba run -p .pyve/testenvs/<name>/conda <cmd>` as a manual workaround.
- **`pyve test --env <conda-name>` also hard-errors** for the same activation reason. Route via `--env root` against a conda main env, or run pytest via `micromamba run` manually.

For lock-file determinism on conda-backed envs, see `pyve lock --env <name>` / `pyve lock --all` below.

### Locking conda-backed envs — `pyve lock --env <name>` / `--all`

`pyve lock` (no args) locks the main env's `environment.yml` → `conda-lock.yml`. Per-env locking lands as:

```bash
pyve lock --env hardware            # one conda-backed testenv (writes tests/env-lock.yml next to env.yml)
pyve lock --all                     # main env + every conda-backed testenv
```

`--env <name>` rejects venv-backed envs (they live outside conda-lock's scope) and undeclared names. `--all` iterates: it locks the main env (in a subshell so its exit-paths don't abort the iteration), then every micromamba-backed env in `[tool.pyve.testenvs]`. Per-env failures `warn` and accumulate into a non-zero exit; venv-backed envs are silently skipped.

### Matrix execution — `pyve test --env a,b,c`

Run the same suite against multiple envs in one command:

```bash
pyve test --env smoke,integration                       # two envs sequentially
pyve test --env smoke,integration -- -k test_user_auth  # same, with pytest args
```

Each env's output is preceded by `=== Env: <name> ===` so you can find the boundary in CI logs. The run is **sequential** (no parallel execution — that's deliberately out of scope for v2.8) and **non-halting** — a failure in the first env doesn't stop the second. The aggregate exit code is the worst-case (highest failing rc); 0 only when every env passes.

Inside the matrix loop, the silent-skip advisory is auto-suppressed (the user has explicitly named multiple envs; the cross-env hint would be noise).

## Choosing which environment runs your tests

By default `pyve test` runs pytest in the **testenv** (`.pyve/testenvs/testenv/venv/`) — or, when `[tool.pyve.testenvs].default` is set, in the env named there. That's the right choice for a normal repo checkout: the root env holds only runtime dependencies, pytest lives in the testenv, and the two stay isolated.

But there's a scenario where the default is wrong — the **bundled-environment trap**:

> You build an environment from an `environment.yml` (or any setup) that puts **both** `pytest` **and** the stack your tests import — `tensorflow`, `torch`, `keras`, … — into the **root** env. (A micromamba smoke env built from a shared template is the canonical case.) Now `pyve test` still routes to the *testenv*, which is a stack-less plain venv. Every test guarded by `pytest.importorskip("tensorflow")` **skips**, and the run looks green — a silent false pass.

The failure is a **SKIP, not an error**, and skips are normal for hardware-gated or optional-dependency tests, so it blends in.

**`pyve test --env root`** routes pytest to the root env instead, so your tests run against the stack that's actually installed there:

```bash
pyve test --env root tests/integration/test_e2e_tensorflow.py -m hardware
```

This is the first-class form of the `pyve run python -m pytest …` workaround — same effect, less to type.

| Your setup | Run with |
|---|---|
| Repo checkout (runtime deps in root env, pytest in testenv) | `pyve test` (default) |
| Bundled env (pytest **and** the stack-under-test both in the root env) | `pyve test --env root` |

**Pyve warns you.** When pyve routes `pyve test` to env `<T>`, it scans every other env it knows about (`root` plus every name in `[tool.pyve.testenvs]`, skipping `<T>` itself) for pytest-importability. If **any** other env has pytest installed — meaning its dependency stack might be what the tests need — pyve prints a one-line advisory listing the alternatives before running. The original M.c form (target = `testenv`, candidate = `root`) is the canonical case; the generalized scan in M.o covers any combination of named envs.

In a normal repo checkout with one testenv (no pytest elsewhere) the advisory never fires. If you keep pytest in multiple envs deliberately and don't want the nudge, set `PYVE_NO_TESTENV_ADVISORY=1` to silence it (matrix mode does this automatically).

!!! note "Renamed in v2.7.1"

    The `--env` value was renamed `main → root` in v2.7.1 (Story M.e). The previous form `pyve test --env main` now hard-errors with the rename hint — there is no silent delegation, per the Category-B deprecation-removal policy. Update any scripts to `--env root`.

## Editable installs

When your test suite imports your project's source code (most projects), you need to decide *where* to install it editable. Two patterns:

### Library / package projects — use `pythonpath`

Preferred for projects whose tests only import the package (no CLI entry-point invocation):

```bash
pyve run pip install -e .                    # install editable into the project env
```

```toml
# pyproject.toml
[tool.pytest.ini_options]
pythonpath = ["."]   # or ["src"] for src layout
```

`pythonpath` handles import discovery cleanly. The testenv doesn't need its own editable install — pytest, running from the testenv, finds your package via `pythonpath` and runs it against the *testenv's* Python.

### CLI projects — editable install in testenv

Required when your tests invoke the project's CLI entry points (console scripts). `pythonpath` only handles imports — it doesn't register entry points — so the CLI script must be installed into whichever environment runs the test:

```bash
pyve testenv init                          # one-time, if not already created
pyve testenv run pip install -e .          # editable into the testenv
pyve testenv install -r requirements-dev.txt
```

**Rule of thumb**: `pythonpath` for library/package projects; editable install in testenv for projects whose tests exercise CLI entry points.

When `pyve init --force` purges and rebuilds the project env, the testenv (and its editable install) **survives**. You'll re-run `pyve run pip install -e .` only for the project env, not the testenv.

## `requirements-dev.txt` convention

Keep dev tooling reproducible in two commands by maintaining a `requirements-dev.txt`:

```text
pytest>=8.0
pytest-cov
ruff
mypy
types-requests
```

```bash
pyve testenv init
pyve testenv install -r requirements-dev.txt
```

Anyone (you on a fresh machine, a contributor, a CI runner) gets the same dev environment from those two commands.

!!! tip "Don't install dev tools into the project env"

    Resist the urge to `pip install -e ".[dev]"` into the main venv. That collapses the two-environment model — your runtime env now carries test-only dependencies, and `pyve init --force` will rebuild without them. Keep dev tools in the testenv.

## Activation context

Whether you need to wrap commands with `pyve run` depends on **where the command is invoked from**:

### Developer in a direnv-activated shell

If you've `cd`'d into the project and direnv has loaded `.envrc`, the project env is active. Bare commands work:

```bash
cd ~/Developer/my-project           # direnv activates the env
pyve testenv init                   # python resolves to the project env
pyve testenv install -r requirements-dev.txt
pyve test
```

This is the standard interactive flow. Most users never need anything more.

### Developer in a non-activated shell

If direnv isn't loaded (you used `--no-direnv` at init, you're in a subshell that didn't inherit direnv's state, or you haven't allowed `.envrc` yet), the project env isn't active. Wrap with `pyve run`:

```bash
pyve run pyve testenv init
pyve run pyve testenv install -r requirements-dev.txt
pyve run pyve test
```

`pyve run` activates the project env for the duration of a single command, then exits. For venv backends it execs directly from `.venv/bin/`; for micromamba backends it routes through `micromamba run -p <env>`.

### LLM agents (Claude Code, Aider, etc.)

LLM agents typically execute Bash commands via a subprocess that **does not inherit direnv state**, even when the developer's interactive shell has the env activated. From an LLM's perspective, every command runs in a non-activated shell.

The rule for LLM-internal invocation: **always wrap with `pyve run`** when running pyve sub-commands that depend on the project env. Specifically:

```bash
# ✅ LLM-internal (works regardless of activation state)
pyve run pyve testenv init
pyve run pyve testenv install -r requirements-dev.txt
pyve run pyve test

# ❌ LLM-internal (fails on non-activated shell — python falls back to asdf shim
#    with no pin, error: "No version is set for command python.")
pyve testenv init
```

This rule is specific to LLM-internal execution. Commands the LLM *suggests to the developer* should use the bare form (the developer's shell is typically activated), matching the form used throughout this documentation.

## CI/CD integration

In CI, the project env is rarely activated automatically — there's no direnv. Two viable patterns:

### Pattern 1 — pip-install pytest into the project env

Many CI workflows install pytest directly into the project's runtime env (typically via a `[dev]` extra in `pyproject.toml`) and skip the testenv entirely. This is what most of the examples in [CI/CD Integration](ci-cd.md) show — `pyve run pytest tests/`. It's the lighter-weight option when your CI doesn't benefit from the two-env survivability advantage.

### Pattern 2 — full testenv in CI

When you want the same two-env model in CI that you use locally:

```bash
pyve init --no-direnv --auto-bootstrap --strict
pyve run pyve testenv init
pyve run pyve testenv install -r requirements-dev.txt
pyve run pyve test
```

This mirrors the local developer flow and keeps test tooling out of the runtime env. The `pyve run` prefix is mandatory in CI because there's no direnv.

For full CI examples (GitHub Actions, GitLab CI, Docker), see [CI/CD Integration](ci-cd.md).

## Troubleshooting

### `pytest: command not found`

The testenv exists but pytest isn't installed in it, or you're trying to run pytest from the project env (which doesn't have it).

```bash
pyve test                                  # prompts to install if missing
# or explicitly:
pyve testenv install                       # bare pytest
pyve testenv install -r requirements-dev.txt
```

**Don't** `pip install pytest` into the project's main venv — that collapses the two-environment model.

### `Dev/test runner environment not initialized`

You ran `pyve testenv install` or `pyve testenv run` before `pyve testenv init`. The install/run subcommands do not auto-create the testenv.

```bash
pyve testenv init
pyve testenv install -r requirements-dev.txt
```

### `No version is set for command python` (from `pyve testenv init`)

You ran `pyve testenv init` from a shell where the project env wasn't active. `python -m venv` (inside `testenv init`) fell back to an asdf or pyenv shim with no pin. Fix:

```bash
pyve run pyve testenv init                 # always works
# or
cd <project-dir>                           # let direnv activate
direnv allow                               # if not yet allowed
pyve testenv init                          # bare form now works
```

See [Activation context](#activation-context) for the full explanation.

### Testenv Python doesn't match project Python after a switch

You changed `environment.yml`'s Python version (or `.tool-versions` / `.python-version`) and `pyve init --force`'d, but the testenv is still on the old version. Pyve detects this drift the next time `pyve testenv init` runs and rebuilds. To force a rebuild now:

```bash
pyve testenv purge
pyve testenv init
pyve testenv install -r requirements-dev.txt
```

The `pyvenv.cfg` `version` field in `.pyve/testenvs/testenv/venv/` records the testenv's base Python; the rebuild check compares it against the active project Python and rebuilds on mismatch.

## See also

- [Usage Guide — `testenv` subcommand](usage.md#testenv-subcommand) — full command reference
- [Backends](backends.md) — venv vs micromamba selection
- [CI/CD Integration](ci-cd.md) — pipeline examples for both patterns above
