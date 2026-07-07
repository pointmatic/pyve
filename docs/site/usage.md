# Usage Guide

Complete reference for all Pyve commands, options, and workflows. The per-command reference lives on four group pages under this Reference tab — [Project Lifecycle](reference/lifecycle.md), [Environments (`env`)](reference/env.md), [Diagnostics](reference/diagnostics.md), and [Tooling](reference/tooling.md) — indexed below.

<script>
/* Deep links from CLI output and installed project-guide artifacts target
   retired usage/#… anchors (the command sections moved to the reference/
   group pages in v3.1). Forward known fragments to their new homes. */
(function () {
  var map = {
    "init": "../reference/lifecycle/#init",
    "purge": "../reference/lifecycle/#purge",
    "update": "../reference/lifecycle/#update",
    "upgrade-env-name-all-check": "../reference/lifecycle/#upgrade-env-name-all-check",
    "env-subcommand": "../reference/env/#env-subcommand",
    "testenv-subcommand": "../reference/env/#env-subcommand",
    "check": "../reference/diagnostics/#check",
    "status": "../reference/diagnostics/#status",
    "run-command-args": "../reference/tooling/#run-command-args",
    "test-pytest-args": "../reference/tooling/#test-pytest-args",
    "lock-check-env-name-all": "../reference/tooling/#lock-check-env-name-all",
    "python-set-ver-python-show": "../reference/tooling/#python-set-ver-python-show",
    "self-install": "../reference/tooling/#self-install",
    "self-uninstall": "../reference/tooling/#self-uninstall",
    "self": "../reference/tooling/#self"
  };
  var frag = window.location.hash.replace(/^#/, "");
  if (Object.prototype.hasOwnProperty.call(map, frag)) {
    window.location.replace(map[frag]);
  }
})();
</script>

!!! note "v3 — the declarative manifest"
    Pyve 3 describes each project with a root-level [`pyve.toml`](pyve-toml.md) manifest and a [plugin model](plugins.md). The main additions over v2 are the `pyve env` namespace (named environments — `pyve testenv` is a deprecated alias, removed in v4.0), `pyve upgrade` (in-place dependency re-resolve), `pyve env sync` (reconcile a planned env spec into the manifest), and `pyve package` (reserved). As of v3.1 the v2 compatibility window is closed: `.pyve/config` is no longer read and the `pyve self migrate` bridge was removed — re-run `pyve init` to bring a v2 project onto the manifest. See the [Migration guide](migration.md).

    Carried over from earlier: `pyve doctor` / `pyve validate` were replaced by `pyve check` (CI-safe `0`/`1`/`2`) and `pyve status` (read-only snapshot); both removed forms now hard-error with a migration hint.

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

Organized into four categories (same as `pyve --help`); each command links to its reference page:

#### Environment

| Command | Description |
|---------|-------------|
| [`init [--yes] [--force [--all]]`](reference/lifecycle.md#init) | Initialize the project's environment(s) — auto-detects each stack, composed across plugins. `--force` rebuilds the root env; `--all` extends the rebuild to every declared env with state restored |
| [`purge [--yes] [--keep-testenv]`](reference/lifecycle.md#purge) | Remove Pyve-managed environment artifacts (composed across plugins) |
| [`update`](reference/lifecycle.md#update) | Non-destructive refresh of the files Pyve manages around your project (never touches an env) |
| [`upgrade [--env <name>] [--all] [--check]`](reference/lifecycle.md#upgrade-env-name-all-check) | Re-resolve env dependencies to newest-within-constraints in place (keeps the env; re-locks) |
| [`python set <ver>`](reference/tooling.md#python-set-ver-python-show) | Pin the project Python version |
| [`python show`](reference/tooling.md#python-set-ver-python-show) | Print the currently pinned Python version + source |
| [`lock [--check] [--env <name>] [--all]`](reference/tooling.md#lock-check-env-name-all) | Generate or verify `conda-lock.yml` (micromamba-backed envs) |
| [`env init\|install\|purge\|run\|list\|prune`](reference/env.md#env-subcommand) | Manage named environments (see [Named Environments](environments.md)) |
| [`env sync`](reference/env.md#env-subcommand) | Reconcile `pyve.toml` with the env spec (`env-dependencies.md` §4): diff → `[Y/n]`-apply |

#### Execution

| Command | Description |
|---------|-------------|
| [`run <command> [args...]`](reference/tooling.md#run-command-args) | Run a command inside the project environment |
| [`test [--env <name>[,…]] [args...]`](reference/tooling.md#test-pytest-args) | Run tests in a `test`-purpose environment (comma-separated `--env` runs a matrix) |
| [`package`](reference/tooling.md#package) | Reserved artifact-materialization verb (prints an advisory until a provider ships) |

#### Diagnostics

| Command | Description |
|---------|-------------|
| [`check`](reference/diagnostics.md#check) | Diagnose problems with CI-safe 0/1/2 exit codes (composed across plugins) |
| [`status`](reference/diagnostics.md#status) | Read-only project-state dashboard, always exit 0 (composed across plugins) |

#### Self management

| Command | Description |
|---------|-------------|
| [`self install`](reference/tooling.md#self-install) | Install pyve (provisions the toolchain venv) |
| [`self uninstall`](reference/tooling.md#self-uninstall) | Remove pyve |
| [`self provision` / `unprovision`](reference/tooling.md#self) | Provision / remove Pyve-managed global tooling (e.g. hosted project-guide) |
| [`self migrate`](reference/tooling.md#self) | Reserved stub for future schema migrations (the v2 → v3 bridge was removed in v3.1) |
| [`self`](reference/tooling.md#self) | Show the self-namespace help |

!!! note "`pyve testenv` → `pyve env`"
    The `pyve testenv <sub>` namespace is a **deprecated alias** for `pyve env <sub>`; it re-dispatches with a one-shot warning and is removed in v4.0. Every example on these pages uses the canonical `pyve env` form.

### Universal Flags

| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show Pyve version |
| `--config`, `-c` | Show current configuration |

## Command Reference

The full per-command reference is organized into four pages:

- **[Project Lifecycle](reference/lifecycle.md)** — `init`, `update`, `upgrade`, `purge`: create, refresh, and remove the project's Pyve-managed surface
- **[Environments (`env`)](reference/env.md)** — the `env` namespace: `init`, `install`, `purge`, `run`, `list`, `prune`, `sync`
- **[Diagnostics](reference/diagnostics.md)** — `check` (CI-safe exit codes) and `status` (read-only dashboard)
- **[Tooling](reference/tooling.md)** — `run`, `test`, `lock`, `package`, `python set`/`show`, and the `self` namespace

The global flags below apply to the CLI as a whole.

### `--version`

Display pyve version information.

**Usage:**

```bash
pyve --version
```

**Output:**

```
pyve version 3.1.0
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
pyve upgrade --help
pyve python --help
pyve lock --help
pyve env --help
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

### `pyve.toml`

The project's declaration — every environment, its purpose, backend, and setup recipe, in one root-level manifest. Written fully explicit by `pyve init`; reconciled from a planned env spec by `pyve env sync`. Everything under `.pyve/` is materialized state, never configuration. See the [`pyve.toml` reference](pyve-toml.md) for the full schema.

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

For the micromamba backend, `PATH_add` points at `.pyve/envs/root/conda/bin` and the sentinel becomes `CONDA_PREFIX`. The file is project-directory independent: `PATH_add` resolves relative paths at runtime, and `$PWD` in the sentinel export expands when direnv sources the file.

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

# Switch to micromamba: rebuild the root env with the new backend
# (updates the manifest; a stray env of the old backend is backed up
# to .pyve/.v2-legacy/, never deleted)
pyve init --force --backend micromamba

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

- [Project Lifecycle](reference/lifecycle.md) — `init`, `update`, `upgrade`, `purge` in full
- [Environments (`env`)](reference/env.md) — the `env` namespace reference
- [Diagnostics](reference/diagnostics.md) — `check` and `status` in full
- [Tooling](reference/tooling.md) — `run`, `test`, `lock`, `python`, `self` in full
- [Backends Guide](backends.md) — Deep dive into venv vs micromamba
- [CI/CD Integration](ci-cd.md) — Using Pyve in automated pipelines
- [Getting Started](getting-started.md) — Installation and quick start
