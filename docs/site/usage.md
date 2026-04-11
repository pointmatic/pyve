# Usage Guide

Complete reference for all Pyve commands, options, and workflows.

!!! note "Migration from flag-style CLI (pre-v1.11)"
    Pyve v1.11.0 migrated the top-level CLI from flags to subcommands. If you
    are coming from an older README, blog post, or LLM snippet, the following
    forms have been **removed**:

    | Old (removed) | New |
    |---|---|
    | `pyve --init [dir]` | `pyve init [dir]` |
    | `pyve --purge [dir]` | `pyve purge [dir]` |
    | `pyve --validate` | `pyve validate` |
    | `pyve --python-version <ver>` | `pyve python-version <ver>` |
    | `pyve --install` | `pyve self install` |
    | `pyve --uninstall` | `pyve self uninstall` |

    Invoking a removed flag form prints a precise migration error and exits
    non-zero. The universal flags `--help` / `--version` / `--config` are
    unchanged, and all modifier flags (`--backend`, `--force`, `--update`,
    `--no-direnv`, `--no-lock`, `--allow-synced-dir`, `--env-name`, etc.) keep
    their names and continue to attach to the renamed subcommands.

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
| `python-version <ver>` | Set Python version without creating an environment |
| `lock [--check]` | Generate or verify `conda-lock.yml` (micromamba only) |

#### Execution

| Command | Description |
|---------|-------------|
| `run <command> [args...]` | Run a command inside the project environment |
| `test [pytest args...]` | Run pytest via the dev/test runner environment |
| `testenv <subcommand>` | Manage the dev/test runner environment |

#### Diagnostics

| Command | Description |
|---------|-------------|
| `doctor` | Check environment health and show diagnostics |
| `validate` | Validate Pyve installation and configuration |

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
- `--strict`: Error on stale or missing lock files
- `--no-lock`: Bypass missing `conda-lock.yml` hard error (use during initial setup before the lock file has been generated)
- `--env-name <name>`: Environment name (micromamba backend)
- `--no-direnv`: Skip `.envrc` creation (for CI/CD or when direnv isn't used)
- `--auto-install-deps`: Automatically install pip dependencies from `pyproject.toml` or `requirements.txt` after environment creation
- `--no-install-deps`: Skip dependency installation prompt (for CI/CD)
- `--local-env`: Copy `~/.local/.env` template into the project
- `--update`: Safely update an existing installation (preserves backend)
- `--force`: Purge and re-initialize environment (destructive)
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

# Bypass missing conda-lock.yml error (initial setup only, before lock file exists)
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
ERROR: Project is inside a cloud-synced directory.

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

**`pyve init --update` does NOT run the hook** — preserves the minimal-touch
promise of update mode. Users who want to refresh project-guide on update run
`pyve init --force`.

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

- `--keep-testenv`: Preserve `.pyve/testenv` (the dev/test runner environment) across purge

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
- The testenv at `.pyve/testenv` is removed by default; pass `--keep-testenv` to preserve it
- Safe to run multiple times

---

### `python-version <ver>`

Set the Python version for the project without creating an environment.

**Usage:**

```bash
pyve python-version <version>
```

**Arguments:**

- `<version>`: Python version in `#.#.#` form (e.g., `3.13.7`)

**Description:**

Writes the version to `.python-version` (asdf/pyenv format) so subsequent
`pyve init` invocations pick it up. Does not create or modify any virtual
environment.

**Examples:**

```bash
# Pin the project to Python 3.13.7
pyve python-version 3.13.7
```

**Notes:**

- Useful when you want to set the Python version up front without committing to an environment backend
- Read by asdf and pyenv as well as `pyve init`

---

### `lock [--check]`

Generate or update `conda-lock.yml` for the current platform. Micromamba
projects only.

**Usage:**

```bash
pyve lock           # generate / update conda-lock.yml
pyve lock --check   # verify conda-lock.yml is current (exit 0) or stale/missing (exit 1)
```

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
INFO: Generating conda-lock.yml for osx-arm64...

✓ conda-lock.yml updated for osx-arm64.

To rebuild the environment from the new lock file:
  pyve init --force

If the environment is already initialized and you only need to commit the updated
lock file, rebuilding is optional.
```

**Example output (already up to date):**

```
INFO: Generating conda-lock.yml for osx-arm64...

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
pyve test [pytest args...]
```

**Arguments:**

- `pytest args` (optional): Arguments passed directly to pytest

**Examples:**

```bash
# Run all tests
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
```

**What it does:**

1. Dispatches to the dev/test runner environment (`.pyve/testenv/venv`) — same environment managed by `pyve testenv`
2. Auto-installs pytest if `PYVE_TEST_AUTO_INSTALL_PYTEST=1` (CI mode)
3. Prompts to install pytest if not found (interactive mode)
4. Runs pytest with the provided arguments

**Notes:**

- Uses the dev/test runner environment, not the project environment — keeps test tools isolated from the project's dependency graph
- Set `PYVE_TEST_AUTO_INSTALL_PYTEST=1` for CI environments
- Exit code matches the pytest exit code
- Equivalent to `pyve testenv run python -m pytest [args...]` with auto-install support

---

### `testenv <subcommand>`

Manage a dedicated dev/test runner environment for tools like ruff, mypy,
black, and pytest. This environment lives at `.pyve/testenv/venv` and is
preserved across `pyve init --force` and `pyve purge` (unless `--keep-testenv`
is omitted — see below).

**Usage:**

```bash
pyve testenv --init                                 # Create the environment
pyve testenv --install [-r requirements-dev.txt]    # Install dependencies
pyve testenv --purge                                # Remove the environment
pyve testenv run <command> [args...]                # Run a command in the testenv
```

**Subcommands:**

- `--init`: Creates `.pyve/testenv/venv` using the system Python.
- `--install [-r <file>]`: Installs packages into the testenv. Without `-r`, installs pytest only. With `-r <file>`, installs from the given requirements file.
- `--purge`: Removes the testenv entirely.
- `run <command> [args...]`: Executes a command inside the testenv by prepending its `bin/` to `PATH`. If the command binary exists in the testenv, it is executed directly; otherwise the command is run with the testenv's `bin/` on `PATH`.

**Examples:**

```bash
# Set up dev tools
pyve testenv --init
pyve testenv --install -r requirements-dev.txt

# Run dev tools from the testenv
pyve testenv run ruff check .
pyve testenv run mypy src/
pyve testenv run black --check .

# Run pytest directly (equivalent to pyve test)
pyve testenv run python -m pytest -v

# Tear down the testenv
pyve testenv --purge
```

**Notes:**

- The testenv survives `pyve init --force` and `pyve purge --keep-testenv`; plain `pyve purge` removes it
- Use `pyve testenv --purge` to remove it explicitly
- `pyve test` is a convenience shortcut that runs pytest inside the testenv with auto-install support
- Exit code matches the executed command's exit code

---

### `doctor`

Display comprehensive environment diagnostics.

**Usage:**

```bash
pyve doctor
```

**Output includes:**

- Pyve version and installation source (homebrew/installed/source)
- Active Python version and location
- Virtual environment backend (venv/micromamba) and path
- Direnv status and configuration
- Environment variables
- **Micromamba only:** Duplicate `.dist-info` directories in `site-packages` (indicates corrupted or conflicting installs)
- **Micromamba only:** Files/directories with ` 2` suffix (iCloud Drive collision artifacts from concurrent sync)
- **Micromamba only:** conda/pip native library conflicts — pip-bundled packages (torch, tensorflow, jax) coexisting with conda-linked packages (numpy, scipy) when the required shared OpenMP library is missing
- **venv only:** Relocated project detection — if the project directory was moved after venv creation, `pyvenv.cfg`'s creation path will no longer match; doctor warns with a `pyve init --force` remediation

**Example output:**

```
Pyve Environment Diagnostics
=============================

✓ Pyve: v1.13.0 (homebrew: /opt/homebrew/Cellar/pyve/1.13.0/libexec)
✓ Python: 3.13.7 (/Users/user/.asdf/installs/python/3.13.7/bin/python)
✓ Backend: venv
✓ Virtual Environment: /Users/user/project/.venv
✓ Direnv: active (.envrc present and allowed)

Environment Variables:
  VIRTUAL_ENV=/Users/user/project/.venv
  PYVE_BACKEND=venv
```

**Use cases:**

- Verify environment setup
- Debug activation issues
- Check Python version and backend
- Confirm direnv configuration

---

### `validate`

Validate Pyve installation and configuration.

**Usage:**

```bash
pyve validate
```

**What it checks:**

- Pyve version recorded in `.pyve/config` (matches, older, newer, or missing)
- Backend configuration is present and supported
- Virtual environment exists and is valid
- Python version matches `.python-version`
- Direnv setup (if installed)
- Required files are present

**Example output:**

```
Pyve Installation Validation
==============================

✓ Pyve version: 1.13.0 (current)
✓ Backend: venv
✓ Virtual environment: .venv (exists)
✓ Configuration: valid
✓ Python version: 3.13.7
✓ direnv integration: .env (exists)

All validations passed.
```

**Exit codes:**

- `0`: All validations passed
- `1`: One or more errors (blocking)
- `2`: Warnings only (non-blocking)

**Use cases:**

- Pre-commit hooks
- CI/CD validation
- Debugging environment issues

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
pyve validate --help
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
| `PYVE_NO_LOCK` | Bypass missing `conda-lock.yml` hard error (same as `--no-lock`) | `0` |
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

Direnv configuration for automatic environment activation.

```bash
# Pyve-managed direnv configuration
source_env_if_exists .env
layout python
```

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

# Check environment
pyve doctor
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
pyve doctor  # Shows: Backend: venv

# Switch to micromamba
pyve purge
pyve init --backend micromamba

# Verify
pyve doctor  # Shows: Backend: micromamba
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

# Validate setup
pyve validate

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
pyve python-version 3.13.7
git add .python-version
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

Run `pyve doctor` regularly to catch configuration issues early; run
`pyve validate` in CI or pre-commit to catch installation drift.

### Backend Selection

- Use **venv** for pure Python projects
- Use **micromamba** for projects with conda dependencies (numpy, pandas, etc.)

## Next Steps

- [Backends Guide](backends.md) — Deep dive into venv vs micromamba
- [CI/CD Integration](ci-cd.md) — Using Pyve in automated pipelines
- [Getting Started](getting-started.md) — Installation and quick start
