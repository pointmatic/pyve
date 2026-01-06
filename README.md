# Pyve: Python Virtual Environment Manager

Pyve is a focused command-line tool that simplifies setting up and managing Python virtual environments on macOS and Linux. It orchestrates Python version management, virtual environments, Micromamba (conda-compatible) environments, and direnv in a single, easy-to-use script.

## Why Pyve?

Pyve provides a single, deterministic entry point for Python environments, without replacing existing tools.

## Key Features
- **Install**: The Pyve script will install itself into `~/.local/bin/` in your home directory, add a path to that, and create a symlink so you can run Pyve like a native command instead of the clunky `./pyve.sh` syntax.
- **Init**: Pyve will automatically initialize your Python coding environment as a virtual environment with your specified (or the default) version of Python and configure `direnv` to autoactivate and deactivate your virtual environment when you change directories. 
- **Purge**: Remove all the Pyve artifacts, except if you've modified the `.env` file, Pyve will leave it and let you know that.

## Conceptual Model

Pyve separates three concerns:

1. **Python runtime selection**
   - Provided by `asdf` or `pyenv`
   - Determines *which Python version* is used

2. **Environment backend**
   - `venv` (pip-based) for application and development workflows
   - `micromamba` (conda-compatible) for scientific / ML workflows

3. **Activation and execution**
   - `direnv` for interactive shell convenience
   - Pyve commands for deterministic environment setup and execution

## Execution Model (Preview)

Pyve is designed around **explicit environment execution**.

While interactive shells typically rely on `direnv` for automatic activation,
Pyve commands may execute tools directly inside the project environment
without requiring manual activation.

This model avoids reliance on shell state and improves reproducibility
for scripts, automation, and CI workflows.

## Requirements

- macOS or Linux with Bash
- Either of these Python version managers:
  - **asdf** (recommended, with Python plugin). Pyve auto-installs requested Python versions.
  - **pyenv**. Pyve auto-installs requested Python versions.
- **direnv** (required for `--init`; not required for standalone `--python-version`)
- **micromamba** (optional):
  - Required only when initializing conda-compatible environments
  - Used for ML / scientific stacks that benefit from binary dependencies

The script checks for prerequisites and provides helpful error messages if anything is missing.

## Quick Start

Copy and paste this into your macOS terminal:

```bash
git clone git@github.com:pointmatic/pyve.git; cd pyve; ./pyve.sh --install; pyve --help
```

### Initialize a Python Virtual Environment

Go to the root of your project directory and run `pyve --init` to initialize your Python virtual environment. 

In a single command, Pyve will:

- **Set Python version**: Uses asdf or pyenv to set the Python version (default: 3.13.7)
- **Create virtual environment**: Creates `.venv` directory with Python venv
- **Configure direnv**: Sets up `.envrc` for automatic activation when entering the directory
- **Create .env file**: Sets up a secure environment variables file (`chmod 600`)
- **Update .gitignore**: Adds appropriate patterns to keep secrets out of version control

### Purge

Run `pyve --purge` to cleanly remove all Pyve-created artifacts:

- Removes `.venv` directory
- Removes `.tool-versions` or `.python-version` file
- Removes `.envrc` file
- **Smart .env handling**: Only removes `.env` if empty; preserves files with your data
- Cleans up `.gitignore` patterns (keeps the file itself)

## Installation

1. Clone this repository:
   ```bash
   git clone git@github.com:pointmatic/pyve.git
   cd pyve
   ```

2. Install to your local bin directory:
   ```bash
   ./pyve.sh --install
   ```

This will:
- Create `~/.local/bin` (if needed)
- Copy `pyve.sh` and `lib/` helpers to `~/.local/bin`
- Create a `pyve` symlink
- Add `~/.local/bin` to your PATH (via `~/.zprofile` or `~/.bash_profile`)
- Create `~/.local/.env` template for shared environment variables

After installation, run `pyve` from any directory.

## Usage

### Initialize a Python Virtual Environment

By default, `pyve --init` creates a Python `venv`-based backend or auto-detects from project files.

#### Backend Selection

```bash
pyve --init                          # Auto-detect or default to venv
pyve --init --backend venv           # Explicit venv backend
pyve --init --backend micromamba     # Explicit micromamba backend
pyve --init --backend auto           # Auto-detect from files
```

#### Standard Options

```bash
pyve --init my_venv                  # Custom venv directory name
pyve --init --python-version 3.12.0  # Specific Python version
pyve --init --local-env              # Copy ~/.local/.env template to .env
pyve -i                              # Short form
```

#### Backend Auto-Detection Priority

When `--backend` is not specified, Pyve automatically detects the appropriate backend using this precedence:

1. **`.pyve/config`** - Explicit project configuration (highest priority)
   ```yaml
   # .pyve/config
   backend: micromamba
   ```

2. **`environment.yml` / `conda-lock.yml`** - Conda environment files → micromamba backend
   ```yaml
   # environment.yml present → uses micromamba
   name: myproject
   dependencies:
     - python=3.11
     - numpy
   ```

3. **`pyproject.toml` / `requirements.txt`** - Python package files → venv backend
   ```toml
   # pyproject.toml present → uses venv
   [project]
   name = "myproject"
   dependencies = ["requests", "flask"]
   ```

4. **Default to venv** - When no environment files exist

**Examples:**
```bash
# Project with environment.yml → automatically uses micromamba
cd my-ml-project
pyve --init  # Detects environment.yml, uses micromamba

# Project with requirements.txt → automatically uses venv
cd my-web-app
pyve --init  # Detects requirements.txt, uses venv

# Empty project → defaults to venv
cd new-project
pyve --init  # No files detected, uses venv

# Override auto-detection
pyve --init --backend micromamba  # Force micromamba
pyve --init --backend venv         # Force venv
```

#### Backend Comparison

| Feature | venv | micromamba |
|---------|------|------------|
| **Package Manager** | pip | conda/mamba |
| **Best For** | Pure Python, web apps, APIs | Data science, ML, scientific computing |
| **Binary Dependencies** | Limited (via wheels) | Excellent (conda packages) |
| **Environment File** | `requirements.txt`, `pyproject.toml` | `environment.yml`, `conda-lock.yml` |
| **Lock Files** | `requirements.txt` (pip-tools) | `conda-lock.yml` |
| **Activation** | `source .venv/bin/activate` | `micromamba activate` or `pyve run` |
| **Speed** | Fast (pip) | Fast (micromamba is faster than conda) |
| **Disk Space** | Smaller | Larger (includes compiled binaries) |
| **Cross-Platform** | Python-only packages | Full cross-platform support |
| **Channel Support** | PyPI only | conda-forge, defaults, custom channels |
| **Python Version** | Managed by asdf/pyenv | Can be in environment.yml |

**When to use venv:**
- Pure Python projects
- Web applications and APIs
- Projects with only PyPI dependencies
- Smaller disk footprint needed

**When to use micromamba:**
- Data science and ML projects
- Projects requiring NumPy, Pandas, TensorFlow, PyTorch
- Projects with C/C++ dependencies
- Cross-platform reproducibility needed
- Projects already using conda/mamba

After setup, run `direnv allow` to activate the environment.

### Set Python Version Only

```bash
pyve --python-version 3.13.7
```

Sets the Python version in the current directory (via asdf or pyenv) without creating a virtual environment.

### Remove Environment

```bash
pyve --purge                         # Remove all artifacts
pyve --purge my_venv                 # Remove custom-named venv
pyve -p                              # Short form
```

### All Commands

```bash
pyve --init, -i       # Initialize your Python coding environment
pyve --purge, -p      # Remove environment artifacts
pyve --python-version # Set Python version only
pyve run <cmd>        # Execute command in project environment
pyve doctor           # Check environment health and configuration
pyve --install        # Install pyve to ~/.local/bin
pyve --uninstall      # Remove pyve from ~/.local/bin
pyve --help, -h       # Show help
pyve --version, -v    # Show version
pyve --config, -c     # Show configuration
```

## Configuration

### Project Configuration File

Create `.pyve/config` for explicit backend and environment settings:

```yaml
# .pyve/config
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

### Environment Variables
- **Project-specific**: `.env` file in your project root for secrets and environment variables
- **User template**: `~/.local/.env` serves as a template copied to new projects with `--init --local-env`

### CLI Flags
Run `pyve --help` for all available commands and options.

## Uninstallation

```bash
pyve --uninstall
```

This removes:
- `~/.local/bin/pyve` symlink
- `~/.local/bin/pyve.sh` script
- `~/.local/bin/lib/` helper scripts
- `~/.local/.env` (only if empty)
- PATH entry from shell profile (if added by pyve)

## Contributing

See `CONTRIBUTING.md` for contribution guidelines.

## Troubleshooting

The script checks for prerequisites (asdf/pyenv, direnv) before initialization and provides helpful error messages if anything is missing.

**Direct execution**: You can run the script directly without installing: `./pyve.sh --init`

### Diagnostic Command

Check environment health and configuration:

```bash
pyve doctor                          # Check environment health
pyve doctor --backend micromamba     # Check micromamba setup
pyve doctor --verbose                # Detailed diagnostics
```

### Micromamba Bootstrap

Pyve can automatically install micromamba when needed, with both interactive and non-interactive modes.

#### Interactive Bootstrap

When micromamba backend is required but not found, Pyve prompts for installation:

```
ERROR: Backend 'micromamba' required but not found.

Detected: environment.yml
Required: micromamba

Installation options:
  1. Install to project sandbox: .pyve/bin/micromamba
  2. Install to user sandbox: ~/.pyve/bin/micromamba
  3. Install via system package manager (brew/apt)
  4. Abort and install manually

Choice [1]: _
```

**Installation Locations:**
- **Project sandbox** (`.pyve/bin/micromamba`) - Isolated per-project, gitignored
- **User sandbox** (`~/.pyve/bin/micromamba`) - Shared across projects, in home directory
- **System package manager** - Uses `brew` (macOS) or `apt` (Linux)
- **Manual** - Exit and install yourself

#### Auto-Bootstrap (Non-Interactive)

For CI/CD and automation, use `--auto-bootstrap` to skip prompts:

```bash
# Auto-bootstrap to user sandbox (default)
pyve --init --backend micromamba --auto-bootstrap

# Explicitly specify installation location
pyve --init --backend micromamba --auto-bootstrap --bootstrap-to user
pyve --init --backend micromamba --auto-bootstrap --bootstrap-to project

# CI/CD example
pyve --init --backend micromamba --auto-bootstrap --no-direnv
```

**Bootstrap Flags:**
- `--auto-bootstrap` - Install micromamba automatically without prompting
- `--bootstrap-to project` - Install to `.pyve/bin/micromamba` (project-local)
- `--bootstrap-to user` - Install to `~/.pyve/bin/micromamba` (user-wide)

### Environment Naming

Pyve automatically resolves environment names for micromamba using this priority:

1. **`--env-name` flag** - Explicit CLI override (highest priority)
   ```bash
   pyve --init --backend micromamba --env-name myproject-dev
   ```

2. **`.pyve/config` file** - Project configuration
   ```yaml
   micromamba:
     env_name: myproject
   ```

3. **`environment.yml` name field** - From environment file
   ```yaml
   name: myproject
   dependencies:
     - python=3.11
   ```

4. **Project directory basename** - Sanitized directory name (default)
   ```bash
   # In /path/to/my-ml-project
   pyve --init --backend micromamba
   # Environment name: my-ml-project
   ```

**Name Sanitization:**
- Converts to lowercase
- Replaces spaces and special characters with hyphens
- Removes leading/trailing hyphens
- Reserved names rejected: `base`, `root`, `default`, `conda`, `mamba`, `micromamba`

**Examples:**
```bash
# Explicit name
pyve --init --backend micromamba --env-name my-env

# From environment.yml
cat > environment.yml << EOF
name: data-science-project
dependencies:
  - python=3.11
  - pandas
EOF
pyve --init  # Uses name: data-science-project

# Auto-generated from directory
cd "My ML Project"
pyve --init --backend micromamba  # Environment: my-ml-project
```

### Lock File Validation

Pyve validates conda lock files to ensure reproducibility:

#### Lock File Status

```bash
pyve doctor  # Check lock file status
```

**Status Indicators:**
- ✓ **Up to date** - `conda-lock.yml` newer than `environment.yml`
- ⚠ **Stale** - `environment.yml` modified after `conda-lock.yml`
- ⚠ **Missing** - No `conda-lock.yml` found

#### Strict Mode

Use `--strict` to enforce lock file requirements:

```bash
# Error if lock file is stale or missing
pyve --init --backend micromamba --strict

# Useful for CI/CD to ensure reproducibility
pyve --init --backend micromamba --strict --auto-bootstrap --no-direnv
```

**Strict Mode Behavior:**
- **Missing lock file** - Exits with error, suggests generating with `conda-lock`
- **Stale lock file** - Exits with error, shows timestamps, suggests regenerating
- **Up-to-date lock file** - Proceeds normally

**Generate Lock Files:**
```bash
# Install conda-lock
pip install conda-lock

# Generate lock file
conda-lock -f environment.yml -p linux-64 -p osx-64

# Or use micromamba
micromamba env export > conda-lock.yml
```

**Example Output (Stale Lock File):**
```
⚠ Lock file: conda-lock.yml (stale)
  environment.yml: 2026-01-06 02:15:30
  conda-lock.yml:  2026-01-05 18:42:15

ERROR: Lock file is stale (--strict mode)
Regenerate with: conda-lock -f environment.yml
```

## Security

- **Never commit secrets**: Pyve automatically adds `.env` to `.gitignore`
- **Restricted permissions**: `.env` files are created with `chmod 600` (owner read/write only)
- **Smart purge**: Non-empty `.env` files are preserved during purge to prevent data loss

## Future Feature Ideas
- Create a Python or Homebrew package for installation
- Version management tool installation:
   - Automated installation of asdf
   - Automated installation of pyenv
   - Automated addition of Python plugin using asdf or pyenv
   - Automated installation of a Python version using either asdf or pyenv

## License

Mozilla Public License Version 2.0 - see LICENSE file.

## Copyright

Copyright (c) 2025 Pointmatic (https://www.pointmatic.com)

## Acknowledgments

Thanks to the asdf, pyenv, and direnv communities for their excellent tools.
