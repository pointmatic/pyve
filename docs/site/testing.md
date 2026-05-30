# Testing

Pyve separates the project's **runtime environment** from a dedicated **dev/test runner environment** (the *testenv*). This guide explains the two-environment model, the testenv lifecycle, how testenv Python inheritance differs by backend, and the activation-context rules that matter when you run testenv commands from a non-activated shell (or from an LLM agent).

If you only want command reference, see the [`testenv` subcommand](usage.md#testenv-subcommand) in the Usage Guide. This page is the concept and how-to companion.

## Overview

Most Python projects install their test tooling (`pytest`, `ruff`, `mypy`, etc.) into the same virtual environment as their application dependencies. Pyve takes a different default: test tooling lives in a **separate environment** at `.pyve/testenv/venv/`, isolated from the project's runtime environment.

The benefit is durability:

- `pyve init --force` rebuilds the runtime environment from scratch but **preserves the testenv**.
- `pyve purge --keep-testenv` removes runtime artifacts but keeps your test tooling intact.
- Swapping Python versions or backends in the runtime env doesn't force you to reinstall pytest, ruff, and friends every time.

The trade-off is one extra command (`pyve testenv install`) when you first set up dev tooling — a small price for a test environment that survives every destructive operation pyve offers.

## The two-environment model

A pyve project has two environments after `pyve init` and `pyve testenv init`:

| Concern | Project environment | Testenv |
|---|---|---|
| **What for** | Your application and its runtime dependencies | Test runner + dev tooling (pytest, ruff, mypy, black, …) |
| **Created by** | `pyve init` | `pyve testenv init` |
| **Location (venv backend)** | `.venv/` | `.pyve/testenv/venv/` |
| **Location (micromamba backend)** | `.pyve/envs/<name>/` | `.pyve/testenv/venv/` (always a plain venv) |
| **Activated by direnv?** | Yes (via `.envrc`) | No — invoked explicitly via `pyve test` / `pyve testenv run` |
| **Survives `pyve init --force`?** | No (rebuilt) | Yes |
| **Removed by `pyve purge`?** | Yes | Yes (unless `--keep-testenv`) |

The testenv is **always a plain Python venv** regardless of the project backend. Only its *base Python* differs by backend — see the next section.

## Backend deltas

`pyve testenv init` runs `python -m venv .pyve/testenv/venv` against whichever `python` resolves on PATH at that moment. The active project environment determines that resolution:

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

Four sub-commands; one file lives behind them all ([lib/commands/testenv.sh](https://github.com/pointmatic/pyve/blob/main/lib/commands/testenv.sh)).

### Create — `pyve testenv init`

One-time. Creates `.pyve/testenv/venv/` using the active project Python. Required before `install` or `run` will work — those subcommands deliberately do *not* auto-create the env.

```bash
pyve testenv init
```

### Install dependencies — `pyve testenv install [-r <file>]`

Without `-r`, installs bare `pytest`. With `-r`, installs from a requirements file:

```bash
pyve testenv install                            # just pytest
pyve testenv install -r requirements-dev.txt    # full dev stack
```

The recommended pattern: maintain a `requirements-dev.txt` so the testenv is reproducible in two commands.

### Run a tool — `pyve testenv run <cmd> [args...]`

Executes any command inside the testenv:

```bash
pyve testenv run ruff check .
pyve testenv run mypy src/
pyve testenv run pytest -v
```

### Run tests — `pyve test [pytest args]`

Convenience shortcut for the common case. Equivalent to `pyve testenv run pytest`, plus an interactive auto-install prompt if pytest isn't yet installed:

```bash
pyve test
pyve test -q
pyve test tests/integration/test_foo.py
```

If pytest is missing, `pyve test` prompts to install it (interactive) or exits with instructions (non-interactive). Set `PYVE_TEST_AUTO_INSTALL_PYTEST=1` to auto-install in CI.

### Remove — `pyve testenv purge`

Removes `.pyve/testenv/`. Re-run `pyve testenv init` (and `install`) to recreate.

```bash
pyve testenv purge
```

## Choosing which environment runs your tests

By default `pyve test` runs pytest in the **testenv** (`.pyve/testenv/venv`). That's the right choice for a normal repo checkout: the root env holds only runtime dependencies, pytest lives in the testenv, and the two stay isolated.

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

**Pyve warns you.** When the root env has pytest importable and you run the default `pyve test`, pyve prints a one-line advisory pointing at `--env root` before running — so the trap surfaces at invocation time instead of hiding behind a clean-looking skip count. In a normal repo checkout (no pytest in the root env) the advisory never fires. If you keep pytest in the root env deliberately and don't want the nudge, set `PYVE_NO_TESTENV_ADVISORY=1` to silence it.

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

The `pyvenv.cfg` `version` field in `.pyve/testenv/venv/` records the testenv's base Python; the rebuild check compares it against the active project Python and rebuilds on mismatch.

## See also

- [Usage Guide — `testenv` subcommand](usage.md#testenv-subcommand) — full command reference
- [Backends](backends.md) — venv vs micromamba selection
- [CI/CD Integration](ci-cd.md) — pipeline examples for both patterns above
