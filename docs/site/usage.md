# Usage Guide

Complete reference for all Pyve commands, options, and workflows.

!!! note "Upgrading from v1.x to v2.0"
    v2.0 completes the CLI-unification arc. See [migration.md](migration.md) for a tactical upgrade guide. Quick summary:

    - `pyve doctor` → `pyve check` (diagnostics with 0/1/2 CI-safe exit codes)
    - `pyve validate` → `pyve check` (same semantics; folded together)
    - `pyve init --update` → `pyve update` (a dedicated subcommand; broader semantics)
    - `pyve python-version <ver>` → `pyve python set <ver>` (delegation removed in v2.3.0; the legacy form now falls through to the dispatcher's unknown-command path)
    - `pyve testenv --init|--install|--purge` → `pyve testenv init|install|purge` (delegation removed in v2.3.0; same fall-through)
    - New: `pyve status` — read-only project-state dashboard

    The legacy-flag catches (`pyve --init`, `pyve --purge`, etc.) remain — typing one prints a precise migration error pointing at the current subcommand.

## Command Overview

```bash
pyve <command> [options]
pyve --help | --version | --config
```

For per-command help:

```bash
pyve <command> --help
```

### Available Commands

Organized into four categories (same as `pyve --help`):

#### Environment

| Command | Description |
|---------|-------------|
| `init [<dir>]` | Initialize a Python virtual environment (auto-detects backend) |
| `purge [<dir>]` | Remove all Python environment artifacts |
| `update` | Non-destructive upgrade: refresh config + managed files + project-guide (never rebuilds the venv) |
| `python set <ver>` | Pin the project Python version |
| `python show` | Print the currently pinned Python version + source |
| `lock [--check]` | Generate or verify `conda-lock.yml` (micromamba only) |

#### Execution

| Command | Description |
|---------|-------------|
| `run <command> [args...]` | Run a command inside the project environment |
| `test [pytest args...]` | Run pytest via the dev/test runner environment |
| `testenv init\|install\|purge\|run\|list\|prune` | Manage one or more dev/test runner environments |

#### Diagnostics

| Command | Description |
|---------|-------------|
| `check` | Diagnose environment problems with CI-safe 0/1/2 exit codes |
| `status` | Read-only project-state dashboard (always exit 0) |

#### Self management

| Command | Description |
|---------|-------------|
| `self install` | Install pyve to `~/.local/bin` |
| `self uninstall` | Remove pyve from `~/.local/bin` |
| `self` | Show the self-namespace help |

### Universal Flags

| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show Pyve version |
| `--config`, `-c` | Show current configuration |

## Command Reference

### `init [<dir>]`

Initialize a Python virtual environment in the current directory.

**Usage:**

```bash
pyve init [<dir>] [options]
```

**Arguments:**

- `<dir>` (optional): Custom venv directory name (default: `.venv`)

**Options:**

- `--python-version <ver>`: Set Python version (e.g., `3.13.7`)
  - If omitted, reads from `.python-version` file
  - If no `.python-version`, uses pyve's default version
- `--backend <type>`: Backend to use: `venv`, `micromamba`, or `auto`
  - Default: auto-detect based on project files
  - If both `environment.yml` and `pyproject.toml` exist, prompts interactively (defaults to micromamba)
- `--auto-bootstrap`: Install micromamba without prompting (if needed)
- `--bootstrap-to <location>`: Where to install micromamba: `project` or `user`
- `--strict`: Error on a stale lock, or a missing lock when `conda-lock` is declared in `environment.yml` (non-strict only nudges); also opts out of scaffolding/inference
- `--no-lock`: Don't use a lock this run — resolve from `environment.yml`, ignore any present lock (never deletes it), skip the requirement (beats `--strict`), and omit `conda-lock` from a fresh scaffold
- `--env-name <name>`: Environment name (micromamba backend)
- `--no-direnv`: Skip `.envrc` creation (for CI/CD or when direnv isn't used)
- `--auto-install-deps`: Automatically install pip dependencies from `pyproject.toml` or `requirements.txt` after environment creation
- `--no-install-deps`: Skip dependency installation prompt (for CI/CD)
- `--local-env`: Copy `~/.local/.env` template into the project
- `--force`: Purge and re-initialize environment (destructive)
    - For **non-destructive** refresh (config bump + managed files + project-guide without touching the venv), use `pyve update` instead of `pyve init --force`.
- `--allow-synced-dir`: Bypass the cloud-synced directory safety check (see below)

**`project-guide` integration options** (three-step post-init hook):

- `--project-guide`: Run all three steps (install + init + shell completion), no prompt
- `--no-project-guide`: Skip all three steps, no prompt
- `--project-guide-completion`: Add shell completion only (step 3), no prompt
- `--no-project-guide-completion`: Skip shell completion only (step 3), no prompt

**Examples:**

```bash
# Initialize with defaults (auto-detect backend, default venv)
pyve init

# Use a custom venv directory name
pyve init myenv

# Pin a specific Python version
pyve init --python-version 3.13.7

# Force venv backend
pyve init --backend venv

# Force micromamba backend
pyve init --backend micromamba

# Auto-install dependencies after initialization
pyve init --auto-install-deps

# Skip dependency installation prompt (for CI/CD)
pyve init --no-install-deps

# Skip direnv (for CI/CD setups)
pyve init --no-direnv

# Force re-initialization (purges and rebuilds)
pyve init --force

# Skip the lock for this run (resolve from environment.yml; a present lock is ignored, not deleted)
pyve init --no-lock

# Bypass cloud-sync directory check (only if you have disabled sync)
pyve init --allow-synced-dir

# Install project-guide without prompting
pyve init --project-guide

# Skip project-guide entirely
pyve init --no-project-guide
```

**Cloud-Synced Directory Safety Check:**

Pyve refuses to initialize an environment inside a cloud-synced directory
(`~/Documents`, `~/Dropbox`, `~/Google Drive`, `~/OneDrive`, etc.).

Cloud sync daemons race against micromamba's package extraction, producing
non-deterministic environment corruption that can damage the Python standard
library. The failure is silent and delayed — often not detected until hours
later during a `git commit` or test run.

```
  ✘ Project is inside a cloud-synced directory.

  Path:      /Users/you/Documents/myproject
  Sync root: /Users/you/Documents (iCloud Drive)

  Recommended fix: move your project outside the synced directory.
    mv "/Users/you/Documents/myproject" ~/Developer/myproject

  If you have disabled sync for this directory and understand the risk:
    pyve init --allow-synced-dir
```

**`project-guide` integration (three-step post-init hook):**

On fresh init (or `pyve init --force`), pyve wires
[project-guide](https://pointmatic.github.io/project-guide/) into the project
as an opt-out post-init hook:

1. `pip install --upgrade project-guide` into the project environment
2. `project-guide init --no-input` to create `.project-guide.yml` and `docs/project-guide/`
3. Append a sentinel-bracketed shell completion block to `~/.zshrc` or `~/.bashrc`

**Trigger logic** (priority order, first match wins):

| Input | Behavior |
|---|---|
| `--no-project-guide` flag | Skip all three steps, no prompt |
| `--project-guide` flag | Run all three steps (overrides auto-skip) |
| `PYVE_NO_PROJECT_GUIDE=1` env var | Skip all three steps |
| `PYVE_PROJECT_GUIDE=1` env var | Run all three steps |
| `project-guide` already in project deps | Auto-skip with INFO message |
| Non-interactive (`CI=1` / `PYVE_FORCE_YES=1`) | Run install + init; skip completion |
| Interactive (default) | Prompt: `Install project-guide? [Y/n]` |

**Auto-skip safety:** If `project-guide` is already declared in `pyproject.toml`,
`requirements.txt`, or `environment.yml`, pyve will **not** auto-install or run
`project-guide init` (avoids version conflicts with your pin). Pass
`--project-guide` to override.

**CI default asymmetry:** Non-interactive mode defaults install → **install**
but completion → **skip** (editing user rc files in CI is surprising; opt in
via `PYVE_PROJECT_GUIDE_COMPLETION=1` or `--project-guide-completion`).

**`pyve update` runs step 2 (project-guide refresh) independently** of the full three-step hook. The v2.0 `pyve update` subcommand refreshes `project-guide update --no-input` but does not install/upgrade the project-guide package itself (step 1) and does not touch shell completion (step 3). Users who want a full three-step run should use `pyve init --force`.

**Interactive Prompts:**

When both `environment.yml` and `pyproject.toml` exist, Pyve will prompt:

```
Detected files:
  • environment.yml (conda/micromamba)
  • pyproject.toml (Python project)

Initialize with micromamba backend? [Y/n]:
```

After successful initialization, if `pyproject.toml` or `requirements.txt` exists:

```
Install pip dependencies from pyproject.toml? [Y/n]:
```

These prompts are skipped in CI mode (when `CI` environment variable is set).

**What it does:**

1. Detects or installs the specified Python version
2. Creates the virtual environment (`.venv` for venv, `.pyve/envs/<name>` for micromamba)
3. Generates `.envrc` for direnv (if installed and `--no-direnv` not passed)
4. Updates `.gitignore` with Pyve-managed patterns
5. Creates `.python-version` if it doesn't exist
6. Optionally runs the project-guide three-step hook (see above)

**Notes:**

- Homebrew-managed installations cannot use `init` (managed by Homebrew)
- Re-running `init` with a different `--python-version` only updates `.python-version`; use `--force` to recreate the environment
- Backend is auto-detected from `environment.yml` or `conda-lock.yml` (micromamba) vs `requirements.txt` / `pyproject.toml` (venv)

---

### `purge [<dir>]`

Remove the virtual environment and clean up Pyve-managed files.

**Usage:**

```bash
pyve purge [<dir>] [options]
```

**Arguments:**

- `<dir>` (optional): Custom venv directory name (default: `.venv`)

**Options:**

- `--keep-testenv`: Preserve `.pyve/testenvs/` (every dev/test runner environment) across purge

**Examples:**

```bash
# Remove .pyve and the venv
pyve purge

# Preserve the testenv across purge
pyve purge --keep-testenv

# Remove a custom-named venv
pyve purge custom_venv
```

**What it does:**

1. Removes the virtual environment directory
2. Deletes `.envrc` file
3. Removes Pyve-managed entries from `.gitignore`
4. Preserves `.python-version` and dependency files
5. Preserves `.project-guide.yml` and `docs/project-guide/` (committable artifacts)

**Notes:**

- Homebrew-managed installations cannot use `purge` (use `brew uninstall pyve`)
- Does not remove `.python-version`, `requirements.txt`, or `environment.yml`
- Every testenv under `.pyve/testenvs/` is removed by default; pass `--keep-testenv` to preserve them all
- Safe to run multiple times

---

### `python set <ver>` / `python show`

Manage the project Python-version pin without creating an environment.

**Usage:**

```bash
pyve python set <version>    # Pin a version (writes .tool-versions or .python-version)
pyve python show             # Print the current pin + its source
```

**Arguments:**

- `<version>`: Python version in `#.#.#` form (e.g., `3.13.7`)

**Description:**

`pyve python set <ver>` writes the version to `.tool-versions` (asdf) or
`.python-version` (pyenv) so subsequent `pyve init` invocations pick it up.
Does not create or modify any virtual environment.

`pyve python show` reads the currently pinned version from `.tool-versions` →
`.python-version` → `.pyve/config` (first match wins) and prints it along
with its source. Read-only; never installs or modifies anything.

**Examples:**

```bash
# Pin the project to Python 3.13.7
pyve python set 3.13.7

# Confirm what pyve will use
pyve python show
# → Python 3.13.7 (from .tool-versions)
```

**Legacy form (deprecated; removed in v3.0).**

`pyve python-version <ver>` still works in v2.x — it emits a one-shot stderr
deprecation warning and delegates to `pyve python set <ver>`. Update your
scripts at your leisure; they will fail after v3.0.

---

### `lock [--check] [--env <name>|--all]`

Generate or update lock files. Without arguments, locks the main env (`environment.yml` → `conda-lock.yml`). With `--env <name>` or `--all`, also locks conda-backed testenvs declared in `[tool.pyve.testenvs]`.

**Usage:**

```bash
pyve lock                   # generate / update conda-lock.yml (main env)
pyve lock --check           # verify conda-lock.yml is current (exit 0) or stale/missing (exit 1)
pyve lock --env <name>      # lock one conda-backed testenv → <manifest>-lock.yml
pyve lock --all             # main env + every conda-backed testenv
```

`--env <name>` writes the lock file sibling to the env's `manifest` (`tests/env.yml` → `tests/env-lock.yml`). Hard-errors for venv-backed names, undeclared names, the reserved `root`, and missing `manifest` declarations / files. `--all` iterates: locks the main env first (in a subshell so its exit-paths don't halt the loop), then every micromamba-backed env; venv-backed envs are silently skipped; per-env failures `warn` and accumulate into a non-zero exit.

**Prerequisites:**

- `conda-lock` must be available on PATH. Add it to `environment.yml` dependencies:
  ```yaml
  dependencies:
    - conda-lock
  ```
  Then run `pyve init --force` to install it, after which `pyve lock` is available.
- `environment.yml` must exist in the current directory.
- Project must use the micromamba backend.

**What it does:**

1. Checks that the project uses the micromamba backend (fails with a clear message for venv projects)
2. Verifies `conda-lock` is on PATH
3. Verifies `environment.yml` exists
4. Detects the current platform automatically (`osx-arm64`, `osx-64`, `linux-64`, `linux-aarch64`)
5. Runs `conda-lock -f environment.yml -p <platform>`
6. If the spec hasn't changed, prints an up-to-date message and exits without modifying the file
7. On success, suppresses the misleading `conda-lock install` post-run message and prints actionable next steps

**Example output (file updated):**

```
  ▸ Generating conda-lock.yml for osx-arm64...

✓ conda-lock.yml updated for osx-arm64.

To rebuild the environment from the new lock file:
  pyve init --force

If the environment is already initialized and you only need to commit the updated
lock file, rebuilding is optional.
```

**Example output (already up to date):**

```
  ▸ Generating conda-lock.yml for osx-arm64...

✓ conda-lock.yml is already up to date for osx-arm64. No changes made.
```

**`--check` flag:**

Compares `environment.yml` and `conda-lock.yml` modification times without
invoking `conda-lock`. Useful as a CI gate to catch `environment.yml` changes
that weren't accompanied by a `pyve lock` run. Does not require `conda-lock`
to be installed.

```
# Up to date:
✓ conda-lock.yml is up to date.

# Stale (exit 1):
✗ conda-lock.yml is stale — environment.yml has been modified since the lock was generated. Run: pyve lock

# Missing (exit 1):
✗ conda-lock.yml not found. Run: pyve lock
```

**Workflow:**

```bash
# After adding a new package to environment.yml
pyve lock               # regenerate conda-lock.yml
git add conda-lock.yml
git commit -m "Add numpy to environment"
pyve init --force       # rebuild environment from new lock file
```

---

### `run <command> [args...]`

Execute a command within the project's virtual environment.

**Usage:**

```bash
pyve run <command> [args...]
```

**Arguments:**

- `<command>`: Command to execute
- `args`: Arguments to pass to the command

**Examples:**

```bash
# Run a Python script
pyve run python script.py

# Run the Python version check
pyve run python --version

# Run an installed CLI tool
pyve run pytest tests/ -v

# Chain commands
pyve run python -m pip install requests
```

**Notes:**

- Activates the virtual environment before running the command
- Useful for CI/CD, Docker, and `--no-direnv` setups
- Exit code matches the executed command

---

### `test [pytest args...]`

Run tests via the dev/test runner environment.

**Usage:**

```bash
pyve test [--env <name>[,<name>...]] [pytest args...]
```

**Arguments:**

- `--env <name>[,<name>...]` (optional): which environment(s) to run pytest in.
    - **No `--env`:** routes to `[tool.pyve.testenvs].default` if declared, else the implicit `testenv` at `.pyve/testenvs/testenv/venv/`.
    - **Reserved `root`:** routes pytest to the project's root env (equivalent to `pyve run python -m pytest`) — the first-class form of the `pyve run python -m pytest` workaround for bundled-env setups.
    - **Reserved `testenv`:** explicit selection of the implicit-default testenv.
    - **`<declared-name>`:** any name declared in `[tool.pyve.testenvs.<name>]` — venv-backed only (conda-backed envs hard-error; use `--env root` or `micromamba run` as a fallback). Lazy envs (`lazy = true`) auto-provision on first targeted use; suppress with `PYVE_NO_AUTO_PROVISION=1`.
    - **Comma-separated list (matrix mode):** `--env a,b,c` runs pytest against each named env sequentially with `=== Env: <name> ===` headers; exit code is the worst-case aggregate; iteration never halts on a failing env. `--parallel` is out of scope.
    - **Legacy `--env main`** now hard-errors with the rename hint (renamed to `--env root` in v2.7.1; Category-B deprecation-removal policy).
- `pytest args` (optional): Arguments passed directly to pytest.

**Examples:**

```bash
# Run all tests (default env)
pyve test

# Run specific test file
pyve test tests/test_module.py

# Run with verbose output
pyve test -v

# Run quiet
pyve test -q

# Run with coverage
pyve test --cov=mypackage

# Run a specific test
pyve test tests/test_module.py::test_function

# Run against the ROOT env (for envs that bundle pytest + the stack
# under test in the root env — see the trap note below)
pyve test --env root tests/integration/test_e2e.py -m hardware

# Run against a declared named env (requires [tool.pyve.testenvs.smoke])
pyve test --env smoke

# Matrix: run against two envs sequentially
pyve test --env smoke,integration
```

**What it does:**

1. Resolves `--env` per the rules above. Comma in the value triggers matrix mode.
2. For each target env: auto-installs pytest if `PYVE_TEST_AUTO_INSTALL_PYTEST=1` (CI mode) or prompts (interactive); lazy envs auto-provision on first use (unless `PYVE_NO_AUTO_PROVISION=1`).
3. Runs pytest with the provided arguments. `.state.last_used_at` is touched per env on the success path so `pyve testenv list` / `prune --unused-since` can see it.

**Notes:**

- Default routing uses the dev/test runner environment, not the project environment — keeps test tools isolated from the project's dependency graph.
- Set `PYVE_TEST_AUTO_INSTALL_PYTEST=1` for CI environments.
- Exit code matches pytest's (single env) or the worst-case aggregate (matrix mode).
- Default routing is equivalent to `pyve testenv run python -m pytest [args...]` with auto-install support; `--env root` is equivalent to `pyve run python -m pytest [args...]`.
- The silent-skip advisory scans every other env (`root` + declared names) for pytest-importability and prints a one-line hint listing alternatives. Suppress with `PYVE_NO_TESTENV_ADVISORY=1` (matrix mode sets it automatically).

!!! warning "The bundled-env trap — when to use `--env root`"

    `pyve test` routes to the **testenv** by default, which is correct for a normal repo checkout (the root env holds only runtime deps; pytest lives in the testenv). But if you built your environment from an `environment.yml` that bundles **both** pytest **and** the stack your tests import (e.g. a micromamba smoke env with `tensorflow`/`torch` *and* `pytest` in the root env), the default testenv won't have that stack. Tests that `pytest.importorskip("…")` will then **silently SKIP** and look green.

    When another env carries pytest, `pyve test` prints an advisory pointing at it. Use `pyve test --env root` (or `--env <named-env>`) to run pytest against the stack you actually need. See [Testing → Choosing which environment runs your tests](testing.md#choosing-which-environment-runs-your-tests).

    *Renamed in v2.7.1:* the previous value `--env main` was renamed to `--env root`. The legacy form now hard-errors with the rename hint per the Category-B deprecation-removal policy.

---

### `testenv <subcommand>`

Manage dedicated dev/test runner environments for tools like ruff, mypy, black, and pytest. The implicit-default testenv lives at `.pyve/testenvs/testenv/venv/`. Projects may also declare additional named envs in `[tool.pyve.testenvs]` (see [Testing → Named test environments](testing.md#named-test-environments)). All envs are preserved across `pyve init --force` and `pyve purge --keep-testenv`.

**Usage:**

```bash
pyve testenv init [<name>]                                  # Create an env (default: testenv)
pyve testenv install [<name>] [-r <file>] [--no-wait]       # Install dependencies
pyve testenv purge [<name>] [--force]                       # Remove env(s)
pyve testenv run [<name> --] <command> [args...]            # Run a command in an env
pyve testenv list                                           # Tabulate every known env
pyve testenv prune [--unused-since <YYYY-MM-DD>|--all] [--force]   # Remove unused envs
```

**Subcommands:**

- `init [<name>]`: Creates `.pyve/testenvs/<name>/{venv,conda}/` using the active project Python (venv backend) or `micromamba create -f <manifest>` (conda backend, when the env declares `backend = "micromamba"`).
- `install [<name>] [-r <file>] [--no-wait]`: No `<name>` iterates every declared non-lazy env. With `<name>` installs into one env. `-r <file>` overrides the declared source (`requirements` / `extra` / `manifest`); without a declared source, falls back to auto-detected `requirements-dev.txt` or bare `pytest`. `--no-wait` fast-fails if another pyve process holds the install lock.
- `purge [<name>] [--force]`: With `<name>` removes one env. Without, removes every declared env (TTY-prompted; `--force` skips the prompt; non-TTY stdin also skips).
- `run [<name> --] <command> [args...]`: Executes a command inside an env. With `<name>`, the `--` separator disambiguates env name from command. Venv-only — conda-backed envs hard-error with a `micromamba run -p <env> <cmd>` workaround hint.
- `list`: Tabulates the union of declared envs and on-disk envs with `NAME / BACKEND / SIZE / LAST-USED / STATE` columns. STATE is one of `ready`, `lazy`, `not provisioned`, `orphaned`.
- `prune`: Disk-walking removal. Default mode removes orphans (on-disk but not declared); `--unused-since <ISO-date>` removes envs whose `.state.last_used_at` is strictly older (envs never used are preserved); `--all` removes every on-disk env. Distinct from `purge` (which is config-driven, walking `[tool.pyve.testenvs]`).

**Examples:**

```bash
# Set up the default testenv
pyve testenv init
pyve testenv install -r requirements-dev.txt

# Set up a named env (requires [tool.pyve.testenvs.smoke] declaration)
pyve testenv init smoke
pyve testenv install smoke         # uses declared `requirements` / `extra` / `manifest`

# Install every declared non-lazy env in one shot
pyve testenv install

# Run dev tools from the default testenv
pyve testenv run ruff check .
pyve testenv run mypy src/
pyve testenv run black --check .

# Run a tool in a named env (note the `--` separator)
pyve testenv run smoke -- pytest -v

# See what's on disk
pyve testenv list

# Remove envs nobody has used since 2026-01-01
pyve testenv prune --unused-since 2026-01-01

# Tear down a specific env / every declared env
pyve testenv purge smoke
pyve testenv purge --force
```

**Notes:**

- Every env survives `pyve init --force` and `pyve purge --keep-testenv`; plain `pyve purge` removes them.
- `pyve test` is a convenience shortcut that runs pytest inside the resolved env with auto-install support and the silent-skip advisory.
- Exit code matches the executed command's exit code (single env) or the worst-case aggregate (`install` / `purge` no-arg iteration).
- Concurrent `pyve testenv install <same-env>` from two shells serialize via a `mkdir`-based lock at `.pyve/testenvs/<name>/.lock/`; the holder's PID is in `lock/pid`. `--no-wait` fast-fails with a "(pid N)" message instead of queuing.

**Legacy flag forms (removed in v2.3.0).**

`pyve testenv --init`, `pyve testenv --install`, and `pyve testenv --purge` were delegated-with-warning through v2.2.x and hard-removed in v2.3.0 (Story J.d). They now fall through to the dispatcher's unknown-flag path. See the [Migration guide](migration.md) for the mapping.

---

### `check`

Diagnose environment problems and suggest one actionable remediation per failure. Replaces the v1.x `pyve doctor` (diagnostics) and `pyve validate` (CI-safe exit codes) commands.

**Usage:**

```bash
pyve check
```

**What it checks:**

- `.pyve/config` presence and parseability
- Backend configured and implementation available (micromamba binary, when applicable)
- Environment path exists and has `bin/python`
- Python version matches the pinned source-of-truth (`.tool-versions` / `.python-version` / config)
- Venv path sanity (warns if project was relocated after creation)
- `distutils_shim` status on Python 3.12+
- `.envrc` / `.env` presence
- `conda-lock.yml` presence and freshness (micromamba only)
- Duplicate `.dist-info` directories in `site-packages` (micromamba only)
- iCloud-Drive collision artifacts (macOS, micromamba only)
- conda/pip native-library conflicts (micromamba only)
- testenv status (if the project uses `pyve test`)

**Exit codes:**

- `0` — all checks passed
- `1` — one or more errors (environment is broken for `pyve run` / `pyve test`)
- `2` — warnings only (environment works but is drifting)

Safe for CI use.

**Example output:**

```
Pyve Environment Check
======================

✓ Configuration: .pyve/config
✓ Backend: venv
✗ Virtual environment: .venv (missing)
  → Run: pyve init --force
⚠ .env: missing
  → touch .env

1 error, 1 warning, 2 passed
```

Every failure points at exactly one command — no chains, no cross-references.

**Legacy forms removed in v2.0.** `pyve doctor` and `pyve validate` now error out with a migration message pointing at `pyve check`. Update CI scripts that grep for "Pyve Installation Validation" to match `Pyve Environment Check` or use `pyve status` for state snapshots.

---

### `status`

Read-only project-state dashboard. Companion to `pyve check`: state here, diagnostics there.

**Usage:**

```bash
pyve status
```

**Output sections:**

- **Project** — path, backend, config version, configured Python
- **Environment** — path, Python, package count, backend-specific rows (distutils shim for venv; environment.yml + lock status for micromamba)
- **Integrations** — direnv, `.env`, project-guide, testenv

**Exit code:** always `0` unless pyve itself errors (e.g., unreadable config). Never signals problems via non-zero exit — for that contract use `pyve check`.

**Example output:**

```
Pyve project status
───────────────────

Project
  Path:           /Users/foo/Developer/bar
  Backend:        venv
  Pyve config:    v2.0.0 (current)
  Python:         3.14.4 (.tool-versions via asdf)

Environment
  Path:           .venv
  Python:         3.14.4
  Packages:       127 installed
  distutils shim: installed (Python 3.12+)

Integrations
  direnv:         .envrc present
  .env:           present
  project-guide:  installed (v2.4.1)
  testenv:        present, pytest installed
```

---

### `update`

Non-destructive upgrade path. Refreshes `.pyve/config`, managed files, and `project-guide` scaffolding without rebuilding the environment.

**Usage:**

```bash
pyve update [--no-project-guide]
```

**What it does:**

1. Rewrites `.pyve/config`'s `pyve_version` to the running pyve's `VERSION`.
2. Refreshes the Pyve-managed sections of `.gitignore`.
3. Refreshes `.vscode/settings.json` (only if it already exists — never creates one on update).
4. Refreshes `.pyve/` layout (bootstraps scaffolding if missing).
5. Runs `project-guide update --no-input` (unless `--no-project-guide` or an auto-skip condition applies).

**What it does NOT do:**

- Never rebuilds the venv / micromamba environment — use `pyve init --force` for that.
- Never creates a `.env` or `.envrc` that doesn't exist — those are user state.
- Never re-prompts for backend. The backend recorded in `.pyve/config` is preserved.
- Never prompts interactively.

**Exit codes:**

- `0` — success (including no-op when already at current version)
- `1` — failure (unwritable config, corrupt YAML, etc.)

**v1.x migration.** `pyve update` replaces the v1.x `pyve init --update` flag (removed in v2.0). The new semantics are broader: the old flag only bumped `pyve_version`; `pyve update` also refreshes managed files + `project-guide` scaffolding. Typing `pyve init --update` in v2.0 produces a migration error pointing at `pyve update`.

---

### `self install`

Install pyve to `~/.local/bin` for manual installations.

**Usage:**

```bash
# From a cloned pyve checkout
./pyve.sh self install

# After the first install, from anywhere
pyve self install
```

**What it does:**

Copies the pyve script and `lib/` modules to `~/.local/bin` and adds
`~/.local/bin` to `PATH` (via `~/.zshrc` or `~/.bashrc`) if not already
present. Idempotent — safe to run multiple times.

**Notes:**

- Only for git-clone installations
- Homebrew-managed installations show a warning
- Requires `~/.local/bin` to be in `PATH`

---

### `self uninstall`

Remove pyve from `~/.local/bin`.

**Usage:**

```bash
pyve self uninstall
```

**What it does:**

Removes the pyve script and `lib/` modules from `~/.local/bin`, plus:

- The `PATH` entry added by the installer (from `~/.zprofile` / `~/.bash_profile`)
- The pyve prompt hook (from `~/.zshrc` / `~/.bashrc`)
- The project-guide shell completion block (from `~/.zshrc` / `~/.bashrc`), if one was added by `pyve init --project-guide-completion`

Non-empty `~/.local/.env` is preserved (warn, don't delete).

**Notes:**

- Only for manual (git-clone) installations
- Homebrew-managed installations should use `brew uninstall pyve`
- Does not affect project virtual environments

---

### `self`

Show the self-namespace help (mirrors `git remote`, `kubectl config`).

**Usage:**

```bash
pyve self
pyve self --help
```

---

### `--version`

Display pyve version information.

**Usage:**

```bash
pyve --version
```

**Output:**

```
pyve version 1.13.0
```

---

### `--config`

Display the current pyve configuration and environment settings.

**Usage:**

```bash
pyve --config
```

**Output includes:**

- Pyve version
- Python version and manager (asdf/pyenv)
- Backend (venv/micromamba)
- Virtual environment path
- Direnv status
- Configuration file paths

---

### `--help`

Display the help message with command overview.

**Usage:**

```bash
pyve --help

# Per-command help
pyve init --help
pyve purge --help
pyve check --help
pyve status --help
pyve update --help
pyve python --help
pyve lock --help
pyve testenv --help
pyve self install --help
pyve self uninstall --help
```

## Environment Variables

Pyve recognizes the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PYVE_BACKEND` | Force backend (`venv` / `micromamba`) | Auto-detect |
| `PYVE_TEST_AUTO_INSTALL_PYTEST` | Auto-install pytest in `pyve test` | `0` (prompt) |
| `PYVE_PYTHON_VERSION` | Override Python version | From `.python-version` |
| `PYVE_AUTO_INSTALL_DEPS` | Auto-install dependencies without prompting | `0` (prompt) |
| `PYVE_NO_INSTALL_DEPS` | Skip dependency installation prompt | `0` (prompt) |
| `PYVE_FORCE_YES` | Skip all interactive prompts (CI mode) | `0` (interactive) |
| `PYVE_NO_LOCK` | `--no-lock` semantics: don't use a lock this run (resolve from `environment.yml`, ignore a present lock without deleting it), skip the requirement (beats `--strict`), omit `conda-lock` from a fresh scaffold | `0` |
| `PYVE_ALLOW_SYNCED_DIR` | Bypass cloud-synced directory check (same as `--allow-synced-dir`) | `0` |
| `PYVE_PROJECT_GUIDE` | Run the project-guide three-step hook (same as `--project-guide`) | Unset |
| `PYVE_NO_PROJECT_GUIDE` | Skip the project-guide three-step hook (same as `--no-project-guide`) | Unset |
| `PYVE_PROJECT_GUIDE_COMPLETION` | Add shell completion only (same as `--project-guide-completion`) | Unset |
| `PYVE_NO_PROJECT_GUIDE_COMPLETION` | Skip shell completion only (same as `--no-project-guide-completion`) | Unset |
| `CI` | Detected CI environment (auto-sets non-interactive mode) | Not set |

**Examples:**

```bash
# Force venv backend
export PYVE_BACKEND=venv
pyve init

# Enable auto-install pytest for CI
export PYVE_TEST_AUTO_INSTALL_PYTEST=1
pyve test

# Override Python version
export PYVE_PYTHON_VERSION=3.13.7
pyve init

# Skip the project-guide hook entirely (e.g. in CI or test suites)
export PYVE_NO_PROJECT_GUIDE=1
pyve init
```

## Configuration Files

### `.python-version`

Specifies the Python version for the project.

```
3.13.7
```

- Created automatically by `pyve init` if not present
- Read by asdf and pyenv
- Single line with version number

### `.envrc`

Direnv configuration for automatic environment activation. Since v2.3.2 every backend shares the same four-line template — only the bin directory, sentinel variable, env root, backend label, and env name differ.

```bash
# pyve-managed direnv configuration
# Uniform template — all backends share this shape (v2.3.2).

PATH_add ".venv/bin"
export VIRTUAL_ENV="$PWD/.venv"
export PYVE_BACKEND="venv"
export PYVE_ENV_NAME="myproj"
export PYVE_PROMPT_PREFIX="(venv:myproj) "

if [[ -f ".env" ]]; then
    dotenv
fi
```

For the micromamba backend, `PATH_add` points at `.pyve/envs/<env>/bin` and the sentinel becomes `CONDA_PREFIX`. The file is project-directory independent: `PATH_add` resolves relative paths at runtime, and `$PWD` in the sentinel export expands when direnv sources the file.

- Created by `pyve init` if direnv is installed (skipped with `--no-direnv`)
- Automatically activates the virtual environment on `cd`
- Run `direnv allow` after creation

### `.gitignore`

Pyve adds the following patterns:

```
# macOS only
.DS_Store

# Python build and test artifacts
__pycache__
*.pyc
*.pyo
*.pyd
*.egg-info
*.egg
.coverage
coverage.xml
htmlcov/
.pytest_cache/
dist/
build/

# Jupyter notebooks
.ipynb_checkpoints/
*.ipynb_checkpoints

# Pyve virtual environment
.envrc
.env
.pyve/
.venv/

```

- Automatically managed by Pyve
- Preserves user entries
- Updated on `init` and removed on `purge`

**Note:** `conda-lock.yml` is **not** added to `.gitignore` — it must be
committed like `package-lock.json` or `Cargo.lock`. Missing it is a hard
error on `pyve init` (use `--no-lock` to bypass during initial setup before
the file exists).

### `.project-guide.yml` and `docs/project-guide/`

Created by the `project-guide` three-step hook in `pyve init`. These are
committable artifacts and are **not** removed by `pyve purge`. See the
[project-guide docs](https://pointmatic.github.io/project-guide/) for details.

## Workflow Examples

### Daily Development

```bash
# Navigate to project
cd my-project

# Environment auto-activates (with direnv)
# Or manually: source .venv/bin/activate

# Install a new package
pip install requests

# Update requirements
pip freeze > requirements.txt

# Run tests
pyve test

# Check environment health (CI-safe 0/1/2 exit codes)
pyve check

# Or: read-only state snapshot
pyve status
```

### Starting a New Project

```bash
# Create and initialize
mkdir new-project && cd new-project
pyve init --python-version 3.13.7

# Create initial files
touch README.md requirements.txt

# Install dependencies
pip install pytest black ruff

# Save dependencies
pip freeze > requirements.txt

# Initialize git
git init
git add .
git commit -m "Initial commit"
```

### Switching Backends

```bash
# Current: venv backend
pyve status  # Shows: Backend: venv

# Switch to micromamba
pyve purge
pyve init --backend micromamba

# Verify
pyve status  # Shows: Backend: micromamba
```

### CI/CD Integration

```bash
# In CI script
export PYVE_TEST_AUTO_INSTALL_PYTEST=1
export PYVE_NO_PROJECT_GUIDE=1   # Skip the project-guide hook in CI

# Initialize environment (non-interactive mode)
pyve init --auto-install-deps --no-direnv

# Or use environment variables
export CI=1  # Automatically detected by Pyve
pyve init

# Validate setup (CI-safe 0/1/2 exit codes)
pyve check

# Run tests
pyve test --cov=mypackage --cov-report=xml
```

**CI Mode Behavior:**

When `CI` environment variable is set or `--auto-install-deps` is used:

- Backend selection defaults to micromamba for ambiguous cases (no prompt)
- Dependencies are auto-installed without prompting
- All interactive prompts are skipped
- The project-guide hook defaults to install + init, but skips shell completion (rc-file edits are opt-in via `PYVE_PROJECT_GUIDE_COMPLETION=1`)

## Tips and Best Practices

### Use `.python-version`

Always commit `.python-version` to ensure consistent Python versions across environments:

```bash
pyve python set 3.13.7
git add .tool-versions  # or .python-version, depending on your version manager
```

### Leverage Direnv

Install direnv for automatic environment activation:

```bash
# macOS
brew install direnv

# Add to shell config
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
```

### Pin Dependencies

Use `pip freeze` to pin exact versions:

```bash
pip freeze > requirements.txt
```

### Regular Validation

Run `pyve check` regularly to catch environment drift. Its 0/1/2 exit-code
contract is CI-safe: exit 0 on pass, 1 on broken environment, 2 on
warnings-only. For a read-only state snapshot (e.g., in dev-container
greetings or shell prompts), use `pyve status` — always exit 0.

### Backend Selection

- Use **venv** for pure Python projects
- Use **micromamba** for projects with conda dependencies (numpy, pandas, etc.)

## Next Steps

- [Backends Guide](backends.md) — Deep dive into venv vs micromamba
- [CI/CD Integration](ci-cd.md) — Using Pyve in automated pipelines
- [Getting Started](getting-started.md) — Installation and quick start
