# Usage Guide

Complete reference for all Pyve commands, options, and workflows.

## Command Overview

```bash
pyve [COMMAND] [OPTIONS]
```

### Available Commands

| Command | Description |
|---------|-------------|
| `--init [VERSION]` | Initialize virtual environment |
| `--purge` | Remove virtual environment and cleanup |
| `doctor` | Display environment diagnostics |
| `run COMMAND` | Run command in virtual environment |
| `test [ARGS]` | Run tests with pytest |
| `--validate` | Validate environment configuration |
| `--config` | Show current configuration |
| `--python-version` | Display Python version |
| `--install` | Install Pyve to ~/.local/bin |
| `--uninstall` | Uninstall Pyve from ~/.local/bin |
| `--version` | Show Pyve version |
| `--help` | Display help message |

## Command Reference

### `--init [VERSION]`

Initialize a Python virtual environment in the current directory.

**Usage:**

```bash
pyve --init [VERSION] [--backend BACKEND]
```

**Arguments:**

- `VERSION` (optional): Python version to use (e.g., `3.11`, `3.11.5`)
  - If omitted, reads from `.python-version` file
  - If no `.python-version`, uses default version

**Options:**

- `--backend BACKEND`: Specify backend (`venv` or `micromamba`)
  - Default: auto-detect based on project files

**Examples:**

```bash
# Initialize with default Python version
pyve --init

# Initialize with specific version
pyve --init 3.11

# Initialize with full version
pyve --init 3.11.5

# Initialize with micromamba backend
pyve --init --backend micromamba

# Initialize with specific version and backend
pyve --init 3.12 --backend venv
```

**What it does:**

1. Detects or installs specified Python version
2. Creates virtual environment (`.venv` for venv, `.pyve/envs/<hash>` for micromamba)
3. Generates `.envrc` for direnv (if installed)
4. Updates `.gitignore` with Pyve-managed patterns
5. Creates `.python-version` if it doesn't exist

**Notes:**

- Homebrew-managed installations cannot use `--init` (managed by Homebrew)
- Re-running `--init` with a different version recreates the environment
- Backend is auto-detected from `environment.yml` or `conda-lock.yml` (micromamba) vs `requirements.txt` (venv)

---

### `--purge`

Remove the virtual environment and clean up Pyve-managed files.

**Usage:**

```bash
pyve --purge
```

**What it does:**

1. Removes virtual environment directory
2. Deletes `.envrc` file
3. Removes Pyve-managed entries from `.gitignore`
4. Preserves `.python-version` and dependency files

**Examples:**

```bash
# Remove environment and cleanup
pyve --purge
```

**Notes:**

- Homebrew-managed installations cannot use `--purge` (use `brew uninstall pyve`)
- Does not remove `.python-version`, `requirements.txt`, or `environment.yml`
- Safe to run multiple times

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

**Example output:**

```
Pyve Environment Diagnostics
=============================

✓ Pyve: v1.5.1 (homebrew: /opt/homebrew/Cellar/pyve/1.5.1/libexec)
✓ Python: 3.11.5 (/Users/user/.asdf/installs/python/3.11.5/bin/python)
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

### `run COMMAND`

Execute a command within the virtual environment.

**Usage:**

```bash
pyve run COMMAND [ARGS...]
```

**Arguments:**

- `COMMAND`: Command to execute
- `ARGS`: Arguments to pass to the command

**Examples:**

```bash
# Run Python script
pyve run python script.py

# Run installed CLI tool
pyve run black --check .

# Run with arguments
pyve run pytest tests/ -v

# Chain commands
pyve run python -m pip install requests
```

**Notes:**

- Activates virtual environment before running command
- Useful when direnv is not installed or not working
- Exit code matches the executed command

---

### `test [ARGS]`

Run tests using pytest in the virtual environment.

**Usage:**

```bash
pyve test [PYTEST_ARGS...]
```

**Arguments:**

- `PYTEST_ARGS` (optional): Arguments passed directly to pytest

**Examples:**

```bash
# Run all tests
pyve test

# Run specific test file
pyve test tests/test_module.py

# Run with verbose output
pyve test -v

# Run with coverage
pyve test --cov=mypackage

# Run specific test
pyve test tests/test_module.py::test_function
```

**What it does:**

1. Checks if pytest is installed
2. Auto-installs pytest if `PYVE_TEST_AUTO_INSTALL_PYTEST=1` (CI mode)
3. Prompts to install pytest if not found (interactive mode)
4. Runs pytest with provided arguments

**Notes:**

- Requires pytest to be installed in the virtual environment
- Set `PYVE_TEST_AUTO_INSTALL_PYTEST=1` for CI environments
- Exit code matches pytest exit code

---

### `--validate`

Validate the current environment configuration.

**Usage:**

```bash
pyve --validate
```

**What it checks:**

- Virtual environment exists and is valid
- Python version matches `.python-version`
- Backend configuration is correct
- Direnv setup (if installed)
- Required files are present

**Example output:**

```
✓ Virtual environment exists: .venv
✓ Python version matches: 3.11.5
✓ Backend configured: venv
✓ Direnv configured: .envrc present
✓ Dependencies file exists: requirements.txt
```

**Exit codes:**

- `0`: All checks passed
- `1`: One or more checks failed

**Use cases:**

- Pre-commit hooks
- CI/CD validation
- Debugging environment issues

---

### `--config`

Display current Pyve configuration and environment settings.

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

**Example output:**

```
Pyve Configuration
==================

Version: 1.5.1
Python Version: 3.11.5
Python Manager: asdf
Backend: venv
Virtual Environment: /Users/user/project/.venv
Direnv: enabled
.python-version: present
requirements.txt: present
```

---

### `--python-version`

Display the active Python version.

**Usage:**

```bash
pyve --python-version
```

**Output:**

```
3.11.5
```

**Notes:**

- Shows version from `.python-version` if present
- Otherwise shows system default
- Useful for scripting and automation

---

### `--install`

Install Pyve to `~/.local/bin` for manual installations.

**Usage:**

```bash
./pyve.sh --install
```

**What it does:**

1. Creates `~/.local/bin` if it doesn't exist
2. Copies `pyve.sh` and `lib/` to `~/.local/bin/pyve/`
3. Creates symlink `~/.local/bin/pyve` → `~/.local/bin/pyve/pyve.sh`
4. Makes script executable

**Notes:**

- Only for git clone installations
- Homebrew-managed installations show a warning
- Requires `~/.local/bin` to be in `PATH`

---

### `--uninstall`

Uninstall Pyve from `~/.local/bin`.

**Usage:**

```bash
pyve --uninstall
```

**What it does:**

1. Removes `~/.local/bin/pyve` symlink
2. Removes `~/.local/bin/pyve/` directory

**Notes:**

- Only for manual installations
- Homebrew-managed installations should use `brew uninstall pyve`
- Does not affect project virtual environments

---

### `--version`

Display Pyve version information.

**Usage:**

```bash
pyve --version
```

**Output:**

```
pyve version 1.5.1
```

---

### `--help`

Display help message with command overview.

**Usage:**

```bash
pyve --help
```

## Environment Variables

Pyve recognizes the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PYVE_BACKEND` | Force backend (venv/micromamba) | Auto-detect |
| `PYVE_TEST_AUTO_INSTALL_PYTEST` | Auto-install pytest in test command | `0` (prompt) |
| `PYVE_PYTHON_VERSION` | Override Python version | From `.python-version` |

**Examples:**

```bash
# Force venv backend
export PYVE_BACKEND=venv
pyve --init

# Enable auto-install pytest for CI
export PYVE_TEST_AUTO_INSTALL_PYTEST=1
pyve test

# Override Python version
export PYVE_PYTHON_VERSION=3.12
pyve --init
```

## Configuration Files

### `.python-version`

Specifies the Python version for the project.

```
3.11.5
```

- Created automatically by `pyve --init` if not present
- Read by asdf and pyenv
- Single line with version number

### `.envrc`

Direnv configuration for automatic environment activation.

```bash
# Pyve-managed direnv configuration
source_env_if_exists .env
layout python
```

- Created by `pyve --init` if direnv is installed
- Automatically activates virtual environment on `cd`
- Run `direnv allow` after creation

### `.gitignore`

Pyve adds the following patterns:

```
# Pyve-managed patterns
.envrc
.env
.pyve/
.venv/
```

- Automatically managed by Pyve
- Preserves user entries
- Updated on `--init` and removed on `--purge`

## Workflow Examples

### Daily Development

```bash
# Navigate to project
cd my-project

# Environment auto-activates (with direnv)
# Or manually: source .venv/bin/activate

# Install new package
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
pyve --init 3.11

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
pyve --purge
pyve --init --backend micromamba

# Verify
pyve doctor  # Shows: Backend: micromamba
```

### CI/CD Integration

```bash
# In CI script
export PYVE_TEST_AUTO_INSTALL_PYTEST=1

# Initialize environment
pyve --init

# Validate setup
pyve --validate

# Run tests
pyve test --cov=mypackage --cov-report=xml
```

## Tips and Best Practices

### Use `.python-version`

Always commit `.python-version` to ensure consistent Python versions across environments:

```bash
echo "3.11.5" > .python-version
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

Run `pyve doctor` regularly to catch configuration issues early.

### Backend Selection

- Use **venv** for pure Python projects
- Use **micromamba** for projects with conda dependencies (numpy, pandas, etc.)

## Next Steps

- [Backends Guide](backends.md) - Deep dive into venv vs micromamba
- [CI/CD Integration](ci-cd.md) - Using Pyve in automated pipelines
- [Getting Started](getting-started.md) - Installation and quick start
