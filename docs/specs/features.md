# features.md — Pyve (Bash)

This document defines **what** Pyve does — requirements, inputs, outputs, and behavior — without specifying how it is implemented. It is the source of truth for scope. For architecture and module design, see `tech_spec.md`. For the implementation plan, see `stories.md`.

---

## Project Goal

Pyve is a command-line tool that provides a single, deterministic entry point for setting up and managing Python virtual environments on macOS and Linux. It orchestrates Python version management, virtual environments (venv and micromamba), and direnv integration in one script.

### Core Requirements

1. Initialize a complete Python development environment in one command (`pyve --init`), including Python version selection, virtual environment creation, direnv configuration, `.env` file setup, and `.gitignore` management.
2. Support two environment backends:
   - **venv** (pip-based) for application and general development workflows.
   - **micromamba** (conda-compatible) for scientific computing and ML workflows.
3. Auto-detect the appropriate backend from project files (`environment.yml` → micromamba, `pyproject.toml` / `requirements.txt` → venv) or allow explicit selection via `--backend`.
4. Manage Python versions through existing version managers (asdf or pyenv), including auto-installation of requested versions.
5. Cleanly remove all Pyve-created artifacts via `pyve --purge`, preserving user data (non-empty `.env` files, user code, Git repository).
6. Execute commands inside the project environment without manual activation via `pyve run <command>`.
7. Provide environment health diagnostics via `pyve doctor`.
8. Install and uninstall the Pyve script itself to/from `~/.local/bin` via `--install` / `--uninstall`.

### Operational Requirements

1. **Error handling** — Check for prerequisites (asdf/pyenv, direnv, micromamba) before operations and provide actionable error messages when dependencies are missing.
2. **Conflict detection** — Detect existing environments, version manager files, and direnv configuration before initialization. Skip with informational messages rather than overwriting.
3. **Idempotency** — Running `pyve --init` on an already-initialized project offers update-in-place or force re-initialization, rather than failing or silently overwriting.
4. **Smart re-initialization** — `--update` preserves the existing environment and updates configuration; `--force` purges and re-creates from scratch.
5. **Logging** — Provide clear success (✓), warning (⚠), and error (✗) indicators for all operations.

### Quality Requirements

1. **Self-healing .gitignore** — Maintain a Pyve-managed template section at the top of `.gitignore` with Python build/test artifacts and environment entries. Preserve user entries below the template. Rebuild the template on each init to restore accidentally deleted entries.
2. **Idempotent .gitignore** — Running init multiple times produces identical `.gitignore` content (no duplicate entries, no accumulated blank lines).
3. **Lock file validation** — For micromamba environments, detect stale or missing `conda-lock.yml` files and warn (or error in `--strict` mode).
4. **Secure file permissions** — `.env` files are created with `chmod 600` (owner read/write only).

### Usability Requirements

1. **CLI tool** — Invoked as `pyve` (after install) or `./pyve.sh` (direct execution).
2. **Short flags** — Common operations have short forms (`-i`, `-p`, `-h`, `-v`, `-c`).
3. **Interactive and non-interactive modes** — Interactive prompts for re-initialization choices and micromamba bootstrap; non-interactive flags (`--force`, `--update`, `--auto-bootstrap`, `--no-direnv`) for CI/CD.
4. **direnv integration** — For interactive use, environments auto-activate/deactivate on directory entry/exit. For CI/CD, `pyve run` provides explicit execution without direnv.

### Non-Goals

- Pyve does not replace asdf, pyenv, direnv, or micromamba — it orchestrates them.
- Pyve does not manage conda-lock (users install and run it themselves).
- Pyve does not install asdf or pyenv (they must be pre-installed).
- Pyve does not provide a GUI or web interface.
- Pyve does not manage Docker containers or cloud environments.
- Pyve does not manage project dependencies (pip install, conda install) beyond initial environment creation.

---

## Inputs

### Required

- **Command flag** — One of `--init`, `--purge`, `--python-version`, `--install`, `--uninstall`, `--help`, `--version`, `--config`, `--validate`, `doctor`, `run`, `test`, `testenv`.

### Optional

| Input | Description | Example |
|-------|-------------|---------|
| `--backend <type>` | Environment backend (`venv`, `micromamba`, `auto`) | `--backend micromamba` |
| `--python-version <ver>` | Python version in `#.#.#` format | `--python-version 3.12.0` |
| `<venv_dir>` | Custom venv directory name | `pyve --init my_venv` |
| `--env-name <name>` | Micromamba environment name | `--env-name myproject-dev` |
| `--local-env` | Copy `~/.local/.env` template to project `.env` | `--init --local-env` |
| `--no-direnv` | Skip `.envrc` creation | `--init --no-direnv` |
| `--force` | Force re-initialization (purge + init) | `--init --force` |
| `--update` | Update existing installation in-place | `--init --update` |
| `--auto-bootstrap` | Auto-install micromamba without prompting | `--init --auto-bootstrap` |
| `--bootstrap-to <loc>` | Bootstrap location (`project` or `user`) | `--bootstrap-to project` |
| `--strict` | Enforce lock file validation | `--init --strict` |
| `--keep-testenv` | Preserve dev/test runner environment during purge | `--purge --keep-testenv` |

### Project Files (Auto-Detection)

| File | Effect |
|------|--------|
| `.pyve/config` | Explicit backend and environment settings (highest priority) |
| `environment.yml` | Triggers micromamba backend |
| `conda-lock.yml` | Triggers micromamba backend |
| `pyproject.toml` | Triggers venv backend |
| `requirements.txt` | Triggers venv backend |

---

## Outputs

### Files Created by `--init` (venv backend)

| File/Directory | Description |
|----------------|-------------|
| `.venv/` (or custom name) | Python virtual environment |
| `.tool-versions` or `.python-version` | Python version pinning (asdf or pyenv) |
| `.envrc` | direnv configuration (unless `--no-direnv`) |
| `.env` | Environment variables file (chmod 600) |
| `.gitignore` | Updated with Pyve template entries |
| `.pyve/config` | Backend and version tracking |

### Files Created by `--init` (micromamba backend)

| File/Directory | Description |
|----------------|-------------|
| `.pyve/envs/<name>/` | Micromamba environment |
| `.envrc` | direnv configuration (unless `--no-direnv`) |
| `.env` | Environment variables file (chmod 600) |
| `.gitignore` | Updated with Pyve template entries |
| `.pyve/config` | Backend, version, and environment name tracking |

### Files Created by `--install`

| File/Directory | Description |
|----------------|-------------|
| `~/.local/bin/pyve.sh` | Main script |
| `~/.local/bin/lib/` | Helper scripts |
| `~/.local/bin/pyve` | Symlink to `pyve.sh` |
| `~/.local/.env` | User-level environment template (chmod 600) |

---

## Functional Requirements

### FR-1: Environment Initialization (`--init`)

Initialize a complete Python development environment in the current directory.

- Auto-detect backend from project files or use explicit `--backend` flag.
- Set Python version via asdf or pyenv (auto-install if not present).
- Create virtual environment (venv directory or micromamba environment).
- Configure direnv for auto-activation (unless `--no-direnv`).
- Create `.env` file with secure permissions.
- Rebuild `.gitignore` from template, preserving user entries.
- Create `.pyve/config` for version and backend tracking.
- **Edge cases**: Existing environment detected → offer update/force/cancel. Reserved venv directory names rejected (`.env`, `.git`, `.gitignore`, `.tool-versions`, `.python-version`, `.envrc`). Invalid Python version format rejected.

### FR-2: Environment Purge (`--purge`)

Remove all Pyve-created artifacts from the current directory.

- Remove venv directory or micromamba environment.
- Remove version manager files (`.tool-versions` or `.python-version`).
- Remove `.envrc`.
- Remove `.env` only if empty; preserve with warning if non-empty.
- Clean `.gitignore` patterns (remove `.venv`, `.env`, `.envrc`; preserve permanent entries).
- **Edge cases**: No environment found → informational message, no error. `--keep-testenv` preserves the dev/test runner environment.

### FR-3: Python Version Management (`--python-version`)

Set the local Python version without creating a virtual environment.

- Set version via asdf or pyenv.
- Auto-install if version not present.
- Refresh shims after change.
- No venv or direnv changes.
- **Edge cases**: Invalid version format (`#.#.#` required). Version not available for installation.

### FR-4: Command Execution (`pyve run`)

Execute a command inside the project environment without manual activation.

- Venv: execute directly from `.venv/bin/`.
- Micromamba: execute via `micromamba run -p <prefix>`.
- Pass all arguments through to the command.
- Propagate the command's exit code.
- **Edge cases**: No environment found → error with suggestion to run `pyve --init`. Command not found → exit code 127.

### FR-5: Environment Diagnostics (`pyve doctor`)

Display environment health and configuration status.

- Report backend type, environment location, Python version.
- Report micromamba binary location and version (if applicable).
- Report lock file status (up to date, stale, missing).
- Report direnv and `.env` status.
- Use status indicators: ✓ (success), ⚠ (warning), ✗ (error).

### FR-6: Installation Validation (`pyve --validate`)

Validate Pyve installation structure and version compatibility.

- Check Pyve version compatibility with project.
- Verify installation structure (`.pyve/` directory, config file).
- Verify environment existence and backend configuration.
- Check Python version availability.
- Exit codes: 0 (pass), 1 (errors), 2 (warnings only).

### FR-7: Script Installation (`--install`) and Uninstallation (`--uninstall`)

Install or remove the Pyve script from the user's system.

- **Install**: Copy script and lib/ to `~/.local/bin`, create symlink, add to PATH, create `~/.local/.env` template. Idempotent.
- **Uninstall**: Remove script, symlink, lib/, PATH entry. Preserve `~/.local/.env` if non-empty.

### FR-8: Backend Auto-Detection

Determine the environment backend from project files when `--backend` is not specified.

- Priority: `.pyve/config` > `environment.yml` / `conda-lock.yml` > `pyproject.toml` / `requirements.txt` > default (venv).

### FR-9: Micromamba Environment Naming

Resolve micromamba environment names using a priority chain.

- Priority: `--env-name` flag > `.pyve/config` > `environment.yml` name field > sanitized directory basename.
- Sanitization: lowercase, replace special characters with hyphens, remove leading/trailing hyphens.
- Reject reserved names: `base`, `root`, `default`, `conda`, `mamba`, `micromamba`.

### FR-10: Micromamba Bootstrap

Install micromamba when the backend is required but not found.

- Interactive: prompt with installation location options (project sandbox, user sandbox, system package manager, manual).
- Non-interactive: `--auto-bootstrap` with `--bootstrap-to` for location selection.
- Installation locations: `.pyve/bin/micromamba` (project) or `~/.pyve/bin/micromamba` (user).

### FR-11: Dev/Test Runner Environment (`pyve test`, `pyve testenv`)

Provide an isolated test environment separate from the project environment.

- Test environment located at `.pyve/testenv/venv/`.
- `pyve test` runs pytest in the test environment; prompts to install pytest if missing (interactive) or exits with instructions (non-interactive).
- `pyve testenv --init` and `pyve testenv --install` for explicit management.
- Survives `pyve --init --force` (separate from project environment).

### FR-12: Smart Re-Initialization

Handle `pyve --init` on already-initialized projects.

- Detect existing installation and offer: update in-place, purge and re-initialize, or cancel.
- `--update`: preserve environment, update config, reject backend changes.
- `--force`: purge and re-create, allow backend changes, prompt for confirmation.

### FR-13: Distutils Compatibility Shim

On Python 3.12+, install a lightweight `sitecustomize.py` shim to prevent TensorFlow/Keras import failures from missing `distutils`.

- Disable with `PYVE_DISABLE_DISTUTILS_SHIM=1`.

---

## Configuration

### Precedence (highest to lowest)

1. CLI flags (`--backend`, `--python-version`, `--env-name`, etc.)
2. Project config file (`.pyve/config`)
3. Project files (`environment.yml`, `pyproject.toml`, etc.)
4. Defaults (venv backend, Python 3.14.3, `.venv` directory)

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `PYVE_DISABLE_DISTUTILS_SHIM` | Set to `1` to disable the Python 3.12+ distutils shim |
| `PYVE_TEST_AUTO_INSTALL_PYTEST` | Set to `1` to auto-install pytest without prompting (CI) |

### Project Config File (`.pyve/config`)

```yaml
pyve_version: "1.1.3"
backend: micromamba

micromamba:
  env_name: myproject
  env_file: environment.yml
  channels:
    - conda-forge
    - defaults
  prefix: .pyve/envs/myproject

python:
  version: "3.11"

venv:
  directory: .venv
```

---

## Testing Requirements

- **Unit tests** (Bats): White-box testing of shell functions in `lib/*.sh`.
- **Integration tests** (pytest): Black-box testing of full `pyve` workflows (init, purge, run, doctor) across both backends.
- **Platform coverage**: macOS and Linux (Ubuntu) via CI matrix.
- **Python version matrix**: Tests run against Python 3.10, 3.11, and 3.12.

---

## Security and Compliance Notes

- `.env` files are created with `chmod 600` (owner read/write only).
- `.env` is always added to `.gitignore` to prevent accidental secret commits.
- Non-empty `.env` files are never deleted by purge or uninstall.
- Micromamba bootstrap downloads are verified against official sources.

---

## Performance Notes

- Pyve is a shell script with no background processes or daemons.
- Environment creation time is dominated by Python version installation (asdf/pyenv) and package installation (pip/micromamba), not by Pyve itself.
- `.gitignore` management uses temp files and atomic `mv` to avoid partial writes.

---

## Acceptance Criteria

1. `pyve --init` creates a fully functional Python environment (venv or micromamba) in one command on both macOS and Linux.
2. `pyve --purge` cleanly removes all Pyve artifacts without data loss.
3. `pyve run <command>` executes commands in the correct environment without manual activation.
4. `pyve doctor` accurately reports environment health.
5. All operations are idempotent — running them multiple times produces the same result.
6. CI/CD workflows work without interactive prompts using `--no-direnv`, `--auto-bootstrap`, and `--strict`.
7. Unit and integration tests pass on macOS and Linux across the Python version matrix.
