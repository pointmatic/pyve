![Pyve](docs/site/images/pyve_header_readme.png)

# Pyve: A single, easy entry point for managing all your virtual environments.

[![Tests](https://github.com/pointmatic/pyve/actions/workflows/test.yml/badge.svg)](https://github.com/pointmatic/pyve/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/pointmatic/pyve/branch/main/graph/badge.svg)](https://codecov.io/gh/pointmatic/pyve)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A command-line tool that gives every project a single, declarative entry point for setting up and managing its environments across language ecosystems on macOS and Linux. A root-level `pyve.toml` names each environment and its purpose; language plugins — Python (venv/micromamba) and Node (pnpm/npm/yarn) today, more through a stable contract — materialize them through their own backends and compose into one direnv activation, one `.gitignore`, and one health report.

See https://pointmatic.github.io/pyve/ for full documentation.

> **Coming from v2?** Pyve 3 is manifest-first: a root-level `pyve.toml` describes every environment. As of v3.1 the v2 compatibility window is closed — `.pyve/config` is no longer read, so a v2-only project reads as uninitialized. Re-run `pyve init` to bring it onto the manifest. See the [Migration guide](https://pointmatic.github.io/pyve/migration/).

## Why Pyve?

Getting from an empty directory to a clean, ready-to-code environment requires the same fiddly setup every time — and every ecosystem reinvents it. Python has asdf/pyenv + venv/conda + direnv; Node has nvm/fnm/volta + npm/pnpm/yarn; polyglot projects multiply the pain. Pyve orchestrates the tools you already use behind one consistent CLI and one declarative manifest.

- One declarative manifest (`pyve.toml`) for every environment
- Polyglot — Python and Node in one repo, composed cleanly (one `.envrc`, one `.gitignore`, one `check`/`status`/`purge`)
- The right backend per stack — venv / micromamba / pnpm / npm / yarn, auto-detected
- Automatic version management via asdf / pyenv (Python) and nvm / fnm / volta (Node)
- Named environments by purpose — `run` / `test` / `utility` / `temp`
- Declarative env recipes — an `[env.<name>]` block composes `editable` / `requirements` / `extra` / `manifest` setup directives, and one command reproduces the env
- Lifecycle verbs with one meaning each — `update` refreshes managed files, `upgrade` re-resolves dependencies, `init --force` rebuilds and restores an env's recorded state
- direnv integration for seamless shell activation
- CI/CD-ready with `--no-direnv`, `--auto-bootstrap`, and `--strict` flags
- Clean teardown with `pyve purge` — preserves your secrets
- Zero runtime dependencies — pure Bash, no daemons

### Philosophy
Make things easy and natural, but avoid being invasive.
- Pyve **orchestrates** existing tools rather than replacing them.
- Pyve manages the environments it creates, and never destroys user data (non-empty `.env`, your code, lockfiles, git history).
- Pyve asks before installing non-critical, networked dependencies like `micromamba` or `pytest`.
- Pyve does not install version managers or `conda-lock`, but wraps their invocation (e.g. `pyve lock`) when they're available — handling platform detection and suppressing the misleading post-run message.

## Key Features
- **Install**: via Homebrew (`brew install pointmatic/tap/pyve`) or from source (`./pyve.sh self install`, which copies the script to `~/.local/bin/` and creates a symlink).
- **Init**: `pyve init` auto-detects each stack, pins language versions, creates environments, configures `direnv` for auto-activation, secures `.env` (`chmod 600`), and self-heals `.gitignore`. `pyve init --yes` accepts every wizard default and writes a fully-explicit `pyve.toml`.
  - **Rebuild**: `pyve init --force` purges and rebuilds the root environment — named envs survive; add `--all` to also rebuild every declared env with its recorded state restored. A named env rebuilds with `pyve env init <name> --force`.
- **Declare**: `pyve.toml` names each `[env.<name>]` (purpose / backend / setup recipe) and each `[plugins.<lang>]`; `pyve env init <name>` materializes the full declared recipe in one shot.
- **Upgrade**: `pyve upgrade` re-resolves an env's dependencies to newest-within-constraints, keeps the env, and re-locks — `--env <name>` targets one env, `--all` fans out, `--check` previews the plan.
- **Purge**: Remove all the Pyve setup and artifacts — except a non-empty `.env`, which Pyve preserves and tells you about.

## Conceptual Model

Pyve separates concerns per stack and composes them:

1. **Language runtime selection**
   - Python via `asdf` / `pyenv`; Node via `nvm` / `fnm` / `volta` / `asdf`
   - Determines *which version* of each language is used

2. **Environment backend** (registered by the language plugin)
   - Python: `venv` (pip) for app/dev work, `micromamba` (conda-compatible) for scientific/ML
   - Node: `pnpm` / `npm` / `yarn`

3. **Declaration**
   - `pyve.toml` — `[env.<name>]` (purpose, backend) and `[plugins.<lang>]` (which sub-tree each plugin owns)
   - `.pyve/` holds materialized state only — never configuration

4. **Activation and execution**
   - `direnv` for interactive shell convenience (composed across every plugin)
   - `pyve run` / `pyve test` for deterministic execution without relying on shell state

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
- For **Node** projects: any of **nvm**, **fnm**, **volta**, **asdf**, or a Homebrew/system Node
- **direnv** (required for `pyve init`; not required for standalone `pyve python set`)
- **micromamba** (optional):
  - Required only when initializing conda-compatible environments
  - Used for ML / scientific stacks that benefit from binary dependencies

The script checks for prerequisites and provides helpful error messages if anything is missing.

## Quick Start

Install via Homebrew (recommended):

```bash
brew install pointmatic/tap/pyve
pyve --help
```

Or install from source:

```bash
git clone git@github.com:pointmatic/pyve.git; cd pyve; ./pyve.sh self install; pyve --help
```

### Initialize a Python Virtual Environment

Go to the root of your project directory and run `pyve init` to initialize your Python virtual environment (add `--yes` to accept every wizard default without prompting).

In a single command, Pyve will:

- **Write the manifest**: Records every environment in a fully-explicit root-level `pyve.toml`
- **Set Python version**: Uses asdf or pyenv to set the Python version (default: 3.14.6)
- **Create virtual environment**: Creates `.venv` directory with Python venv
- **Upgrade pip**: Automatically upgrades pip to the latest version for security and features
- **Configure direnv**: Sets up `.envrc` for automatic activation when entering the directory
- **Create .env file**: Sets up a secure environment variables file (`chmod 600`)
- **Update .gitignore**: Adds appropriate patterns to keep secrets out of version control

### Purge

Run `pyve purge` to cleanly remove all Pyve-created artifacts:

- Removes `.venv` directory
- Removes `.tool-versions` or `.python-version` file
- Removes `.envrc` file
- **Smart .env handling**: Only removes `.env` if empty; preserves files with your data
- Cleans up `.gitignore` patterns (keeps the file itself)

## Installation

### Homebrew (recommended)

```bash
brew install pointmatic/tap/pyve
```

To update:

```bash
brew upgrade pointmatic/tap/pyve
```

### From Source

1. Clone this repository:
   ```bash
   git clone git@github.com:pointmatic/pyve.git
   cd pyve
   ```

2. Install to your local bin directory:
   ```bash
   ./pyve.sh self install
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

By default, `pyve init` creates a Python `venv`-based backend or auto-detects from project files.

#### Backend Selection

```bash
pyve init                          # Auto-detect or default to venv
pyve init --backend venv           # Explicit venv backend
pyve init --backend micromamba     # Explicit micromamba backend
pyve init --backend auto           # Auto-detect from files
```

#### Standard Options

```bash
pyve init --yes                      # Easy mode: accept every wizard default
pyve init --python-version 3.12.0    # Specific Python version
pyve init --local-env                # Copy ~/.local/.env template to .env
```

#### Backend Auto-Detection Priority

When `--backend` is not specified, Pyve automatically detects the appropriate backend using this precedence:

1. **`pyve.toml`** - The manifest's declared root backend (highest priority)
   ```toml
   # pyve.toml
   [env.root]
   backend = "micromamba"
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

**Ambiguous Cases (Interactive Prompt):**

When both conda and Python files exist (e.g., `environment.yml` + `pyproject.toml`), Pyve prompts you to choose:

```
Detected files:
  • environment.yml (conda/micromamba)
  • pyproject.toml (Python project)

Initialize with micromamba backend? [Y/n]:
```

- **Interactive mode:** Prompts user, defaults to micromamba (press Enter or type `Y`)
- **CI mode:** Automatically uses micromamba without prompting (when `CI` environment variable is set)
- **Override:** Use `--backend` flag to skip the prompt

**Examples:**
```bash
# Project with environment.yml → automatically uses micromamba
cd my-ml-project
pyve init  # Detects environment.yml, uses micromamba

# Project with requirements.txt → automatically uses venv
cd my-web-app
pyve init  # Detects requirements.txt, uses venv

# Empty project → defaults to venv
cd new-project
pyve init  # No files detected, uses venv

# Ambiguous project → prompts for choice
cd ml-project-with-both-files
pyve init  # Prompts: "Initialize with micromamba backend? [Y/n]:"

# Override auto-detection
pyve init --backend micromamba  # Force micromamba (skip prompt)
pyve init --backend venv         # Force venv (skip prompt)
```

#### Backend Comparison

| Feature | venv | micromamba |
|---------|------|------------|
| **Package Manager** | pip | conda/mamba |
| **Best For** | Pure Python, web apps, APIs | Data science, ML, scientific computing |
| **Binary Dependencies** | Limited (via wheels) | Excellent (conda packages) |
| **Environment File** | `requirements.txt`, `pyproject.toml` | `environment.yml`, `conda-lock.yml` |
| **Lock Files** | `requirements.txt` (pip-tools) | `conda-lock.yml` |
| **Activation** | `direnv` (uniform `.envrc` template) or `pyve run` | `direnv` (uniform `.envrc` template) or `pyve run` |
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

#### Pip Dependency Installation

After creating the environment, Pyve prompts to install pip dependencies if `pyproject.toml` or `requirements.txt` exists:

```
Install pip dependencies from pyproject.toml? [Y/n]:
```

This runs `pip install -e .` to install your project in editable mode, making your code importable as a package.

**Behavior:**
- **Interactive mode:** Prompts user (default: Yes, press Enter or type `Y`)
- **Auto-install:** Use `--auto-install-deps` flag to install without prompting
- **Skip prompt:** Use `--no-install-deps` flag to skip installation
- **CI mode:** Skipped by default (set `PYVE_AUTO_INSTALL_DEPS=1` to enable in CI)

**Examples:**
```bash
# Standard initialization (prompts for pip dependencies)
pyve init

# Auto-install dependencies without prompting
pyve init --auto-install-deps

# Skip dependency installation prompt (useful for CI)
pyve init --no-install-deps

# CI/CD with auto-install
PYVE_AUTO_INSTALL_DEPS=1 pyve init --no-direnv
```

After setup, run `direnv allow` to activate the environment.

### Set Python Version Only

```bash
pyve python set 3.13.7    # Pin the version (via asdf or pyenv)
pyve python show          # Show the pinned version and its source
```

Sets the Python version in the current directory (via asdf or pyenv) without creating a virtual environment.

### Remove Environment

```bash
pyve purge                           # Remove all artifacts (confirms first; --yes skips)
pyve purge --keep-testenv            # Preserve the dev/test runner environment
pyve env purge [<name>]              # Remove one named env (default env when unnamed)
pyve env purge --all                 # Remove every declared env
```

## Testing

Pyve supports the developer with an isolated test environment, separate from the project's runtime environment. The full guide is at [Testing](https://pointmatic.github.io/pyve/testing/).

### The dev/test runner environment

Pyve supports integration testing via a dedicated dev/test runner environment separate from the project runtime virtual environment. When you run `pyve test`, Pyve will initialize the dev/test runner environment. If `pytest` is missing, Pyve prompts to install `pytest` (interactive shell).

- Project environment: `.venv/` (created by `pyve init`)
- Dev/test runner environment: `.pyve/envs/testenv/venv/` (used by `pyve test`)

This separation prevents destructive actions like `pyve init --force` from wiping your test tooling.

**Two envs is the minimum, not the maximum.** Declare additional named environments in `pyve.toml` — each `[env.<name>]` block picks its purpose (`run` / `test` / `utility` / `temp`), its backend (`venv`, `micromamba`, or the root's by default), a composable setup recipe (`editable` / `requirements` / `extra` / `manifest`), and a lifecycle policy (`lazy = true` for on-demand provisioning). State for each env lives under `.pyve/envs/<name>/`. Then `pyve test --env <name>` (single) or `pyve test --env a,b,c` (matrix) routes the suite to the right env. See [Testing → Named test environments](https://pointmatic.github.io/pyve/testing/#named-test-environments) for the full schema and the canonical detail.

### Running tests

Run pytest via Pyve:

```bash
pyve test
pyve test -q
pyve test tests/integration/test_testenv.py
```

If `pytest` is not installed in the dev/test runner environment:

- In an interactive terminal, Pyve will prompt:
  - `pytest is not installed in the dev/test runner environment. Install now? [y/N]`
- In non-interactive contexts, Pyve will exit with instructions.

You can also install dev/test dependencies explicitly:

```bash
pyve env init
pyve env install -r requirements-dev.txt
```

Or declare the setup recipe once in `pyve.toml` and materialize it in one shot:

```toml
[env.testenv]
purpose = "test"
backend = "venv"
default = true
editable     = ".[dev]"                  # editable self-install + extras
requirements = ["requirements-dev.txt"]  # composes with the line above
```

```bash
pyve env init testenv            # materializes the full declared recipe
pyve env init testenv --force    # one-shot rebuild from the declaration
```

### All Commands

```bash
# Environment
pyve init                 # Initialize the project's environment(s) (--yes: accept defaults)
pyve init --force [--all] # Rebuild the root env (--all: every declared env, state restored)
pyve purge                # Remove environment artifacts (composed across plugins)
pyve update               # Non-destructive refresh of config + managed files
pyve upgrade              # Re-resolve deps within constraints (--env <name> | --all | --check)
pyve python set <ver>     # Pin the project Python version
pyve python show          # Show the pinned Python version + its source
pyve lock                 # Generate/update conda-lock.yml (micromamba envs)
pyve env <subcommand>     # Manage named environments (init/install/purge/run/list/prune/sync)

# Execution
pyve run <cmd>            # Execute a command in the project environment
pyve test [--env <name>]  # Run tests in a test-purpose environment

# Diagnostics
pyve check                # Diagnose problems (CI-safe 0/1/2 exit codes)
pyve status               # Read-only project-state dashboard (always exit 0)

# Packaging (reserved)
pyve package              # Reserved artifact-materialization verb

# Self management
pyve self install         # Install pyve (provisions the toolchain venv)
pyve self uninstall       # Remove pyve
pyve self provision       # (Re)provision the hosted toolchain (--status: readiness query)

# Universal flags
pyve --help, -h           # Show help
pyve --version, -v        # Show version
pyve --config, -c         # Show configuration

# Per-command help
pyve <command> --help     # Show focused help for a specific command
```

> `pyve testenv <subcommand>` still works as a deprecated alias for `pyve env <subcommand>` (removed in v4.0).

## Configuration

### Project Configuration File

From v3.0, a project is described by a root-level `pyve.toml` manifest. Everything under `.pyve/` is materialized state — never configuration.

```toml
# pyve.toml
pyve_schema = "3.0"

[project]
name = "myproject"
pyve_defaults_version = "1"   # which Pyve defaults-set the project was created with

[env.root]
purpose = "utility"
backend = "venv"        # or "micromamba"
default = false

[env.testenv]
purpose = "test"
backend = "venv"
default = true
editable     = ".[dev]"                  # setup recipe: directives compose
requirements = ["requirements-dev.txt"]

# Optional: declare language plugins and the sub-tree each owns
[plugins.python]
path = "."
```

`pyve init` writes the manifest fully explicit — every env records its `purpose`, `backend`, and `default`, so the file is self-documenting and reproducible. You rarely write it by hand: `pyve init` generates it, and `pyve env sync` reconciles a planned environment spec into it. See the [`pyve.toml` reference](https://pointmatic.github.io/pyve/pyve-toml/) for the full schema.

### Environment Variables
- **Project-specific**: `.env` file in your project root for secrets and environment variables
- **User template**: `~/.local/.env` serves as a template copied to new projects with `pyve init --local-env`

### CLI Flags
Run `pyve --help` for all available commands and options.

## Uninstallation

### Homebrew

```bash
brew uninstall pyve
```

### From Source

```bash
pyve self uninstall
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

**Direct execution**: You can run the script directly without installing: `./pyve.sh init`

### Diagnostic Commands

Diagnose problems, or snapshot project state:

```bash
pyve check                  # Diagnose problems; CI-safe exit codes (0 pass / 2 warn / 1 error)
pyve --verbose check        # Detailed diagnostics
pyve status                 # Read-only "what is this project?" dashboard (always exit 0)
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
pyve init --backend micromamba --auto-bootstrap

# Explicitly specify installation location
pyve init --backend micromamba --auto-bootstrap --bootstrap-to user
pyve init --backend micromamba --auto-bootstrap --bootstrap-to project

# CI/CD example
pyve init --backend micromamba --auto-bootstrap --no-direnv
```

**Bootstrap Flags:**
- `--auto-bootstrap` - Install micromamba automatically without prompting
- `--bootstrap-to project` - Install to `.pyve/bin/micromamba` (project-local)
- `--bootstrap-to user` - Install to `~/.pyve/bin/micromamba` (user-wide)

### Environment Naming

Pyve automatically resolves environment names for micromamba using this priority:

1. **`--env-name` flag** - Explicit CLI override (highest priority)
   ```bash
   pyve init --backend micromamba --env-name myproject-dev
   ```

2. **`environment.yml` name field** - From environment file
   ```yaml
   name: myproject
   dependencies:
     - python=3.11
   ```

3. **Project directory basename** - Sanitized directory name (default)
   ```bash
   # In /path/to/my-ml-project
   pyve init --backend micromamba
   # Environment name: my-ml-project
   ```

The resolved name is recorded as metadata (`environment.yml`'s `name:` field); the environment itself always materializes at `.pyve/envs/root/conda/`, regardless of name.

**Name Sanitization:**
- Converts to lowercase
- Replaces spaces and special characters with hyphens
- Removes leading/trailing hyphens
- Reserved names rejected: `base`, `root`, `default`, `conda`, `mamba`, `micromamba`

**Examples:**
```bash
# Explicit name
pyve init --backend micromamba --env-name my-env

# From environment.yml
cat > environment.yml << EOF
name: data-science-project
dependencies:
  - python=3.11
  - pandas
EOF
pyve init  # Uses name: data-science-project

# Auto-generated from directory
cd "My ML Project"
pyve init --backend micromamba  # Environment: my-ml-project
```

### Lock Files (`conda-lock.yml`)

For micromamba projects, a `conda-lock.yml` pins every dependency (and its transitive deps) to exact versions per platform, so the environment builds byte-for-byte reproducibly. When a `conda-lock.yml` is present, Pyve builds the env *from the lock* rather than re-solving `environment.yml`.

#### Whether a lock is required is declarative

Pyve keys "is a lock required?" on **your own declaration** — whether `conda-lock` is a dependency in `environment.yml`:

- **`conda-lock` declared, no lock yet** → `pyve init` proceeds and gently **nudges** you to run `pyve lock` when your dependencies are finalized. `pyve init --strict` instead **errors** (the production gate).
- **`conda-lock` not declared** → no lock is expected; init proceeds silently (the pre-production default).

A fresh micromamba scaffold declares `conda-lock` by default (interactive init asks; `--no-lock` omits it), so `pyve lock` works immediately — no edit-then-rebuild dance.

#### `--strict` and `--no-lock`

- **`--strict`** — turn the missing/stale-lock nudge into a hard error (for CI/CD reproducibility). Also opts out of scaffolding/inference.
- **`--no-lock`** — for this run, don't use a lock: resolve from `environment.yml`, ignore any present `conda-lock.yml` (it is **never deleted**, even with `--force`), skip the requirement (beats `--strict`), and omit `conda-lock` from a fresh scaffold. To opt out permanently, remove `conda-lock` from `environment.yml`.

```bash
pyve init --backend micromamba --strict --auto-bootstrap --no-direnv   # CI: require a fresh lock
pyve init --backend micromamba --no-lock                                # skip locking this run
```

#### Generate / check a lock

```bash
pyve lock          # generate/update conda-lock.yml for the current platform
pyve check         # report lock status (up to date / stale / missing-but-required)
```

`pyve check` reports a missing lock as a finding only when `conda-lock` is declared; otherwise it reports it as "not required." A stale lock (`environment.yml` newer than `conda-lock.yml`) warns; re-run `pyve lock` to refresh, then `pyve init --force` to rebuild the env from the new lock.

## Commands

### `pyve run` - For CI/CD and Automation

> **Note for interactive use:** If you're using direnv (the default), you **don't need** `pyve run`. Just `cd` into your project and run commands normally. The environment auto-activates.

**When you need `pyve run`:**
- ✅ **CI/CD pipelines** (GitHub Actions, GitLab CI, etc.)
- ✅ **Docker containers** without direnv
- ✅ **Automation scripts** that need explicit environment execution
- ✅ **Projects initialized with `--no-direnv`**

**When you DON'T need it:**
- ❌ **Interactive terminal use** with direnv (just use `cd` + normal commands)
- ❌ **Local development** with direnv active

```bash
pyve run <command> [args...]
```

**Arguments:**
- `<command>`: The executable to run (python, pytest, pip, black, etc.)
- `[args...]`: Optional arguments passed to the command

**Interactive Use (with direnv - most users):**
```bash
cd /path/to/project    # direnv auto-activates environment
python --version       # Just run commands normally
pytest                 # No pyve run needed
pip install requests   # Works directly
```

**CI/CD / Automation Use (without direnv):**
```bash
# GitHub Actions, Docker, scripts
pyve init --no-direnv
pyve run python --version
pyve run pytest
pyve run pip install requests

# Automation from any directory
cd /path/to/project && pyve run pytest
(cd /path/to/project && pyve run python script.py)
```

**Full Examples:**
```bash
# CI/CD: No direnv, explicit execution
pyve run python script.py
pyve run pytest tests/ -v
pyve run black .
pyve run mypy src/

# Automation: Run from outside project
PROJECT_DIR="/path/to/project"
cd "$PROJECT_DIR" && pyve run pytest tests/
```

**Backend-Specific Behavior:**

**Venv backend:**
```bash
# Executes directly from .venv/bin/
pyve run python script.py
# Equivalent to: .venv/bin/python script.py
```

**Micromamba backend:**
```bash
# Uses micromamba run with prefix
pyve run python script.py
# Equivalent to: micromamba run -p .pyve/envs/root/conda python script.py
```

**Error Handling:**
```bash
# Command not found
pyve run nonexistent
# ERROR: Command not found in venv: nonexistent
# Exit code: 127

# No environment
pyve run python
# ERROR: No Python environment found
# ERROR: Run 'pyve init' to create an environment first
```

**Use Cases:**
- **CI/CD pipelines** - Run tests without activation
- **Scripts** - Execute Python scripts deterministically
- **One-off commands** - Run tools without entering environment
- **Automation** - Consistent execution across systems

### `pyve check` — Diagnostics

> `pyve check` replaces the v1.x/v2 `pyve doctor` and `pyve validate` commands, which now hard-error with a migration hint.

Diagnose problems and suggest one remediation per failure, composed across every active plugin:

```bash
pyve check
```

**What it checks** (per active plugin): backend health, environment existence and location, language version, environment files (e.g. `environment.yml` / `conda-lock.yml`, `package.json` / `node_modules`), lock-file freshness, `.envrc` / `.env` status, and project-guide hosting. An info-only `[defaults]` section reports when Pyve's built-in defaults have changed since the project was created — reported, never applied retroactively.

**Exit codes (CI-safe):**
- `0` — pass (clean)
- `2` — warnings only (advisory, non-failing)
- `1` — errors (environment broken for run/test)

In a polyglot repo, each plugin contributes its own section and the worst severity across all of them becomes the process exit code.

### `pyve status` — Project State

Read-only "what is this project?" dashboard. Always exits `0` unless pyve itself errors — a broken reading is `check`'s job, not `status`'s.

```bash
pyve status
```

It reports the project's backend(s), declared environments, language versions, and integrations across every active plugin.

### Smart Re-initialization

Pyve handles re-initialization of existing projects without manual cleanup, honoring `pyve.toml` as the source of truth. Running `pyve init` on an already-initialized project re-runs setup non-destructively: the wizard seeds its answers from the manifest, healthy environments are kept, and managed files are refreshed. Nothing is purged without `--force`.

**Three lifecycle verbs, one meaning each:**

| Command | Touches | Destructive? |
|---|---|---|
| `pyve update` | The files Pyve manages *around* your project (`.gitignore`, editor settings, project-guide scaffolding) | No |
| `pyve upgrade` | An env's *dependencies* — re-resolves to newest-within-constraints, keeps the env, re-locks | No (env preserved) |
| `pyve init --force` | The root *environment itself* — purge and rebuild from the manifest | Yes (confirms first) |

```bash
pyve update                      # refresh managed files (never touches envs)
pyve upgrade                     # upgrade the root env's dependencies
pyve upgrade --env testenv       # upgrade one named env
pyve upgrade --all --check       # preview the upgrade plan for every env
pyve init --force                # rebuild the root env (named envs untouched)
pyve init --force --all          # rebuild every declared env, restoring recorded state
pyve env init <name> --force     # rebuild one named env from its declaration
```

**Rebuilds restore state.** A forced rebuild snapshots the env's operational state first (installed dependencies, usage provenance) and replays it after the rebuild — a rebuilt env comes back installed, not empty. Only `pyve purge` / `pyve env purge` truly destroys.

**Backend changes are safe.** `pyve init --force` honors the backend declared in `pyve.toml` (an explicit `--backend` flag wins). If a stray environment of a different backend is found, it is backed up to `.pyve/.v2-legacy/` — recoverable, never deleted.

**Use Cases:**
- **Dependency refresh** - `pyve upgrade` after loosening constraints or to pick up new releases
- **Managed-file refresh** - `pyve update` after upgrading Pyve itself
- **Backend switching** - Change from venv to micromamba (or vice versa) via `pyve init --force`
- **Project recovery** - Rebuild a corrupted environment from its declaration

### `--no-direnv` Flag - Skip Direnv Configuration

Skip `.envrc` creation for environments where direnv isn't available:

```bash
pyve init --no-direnv
```

**When to use:**
- **CI/CD environments** - Where direnv isn't installed
- **Docker containers** - Where direnv isn't needed
- **Automation scripts** - Where manual activation isn't desired
- **Minimal setups** - Where you prefer `pyve run` only

**Behavior:**
- Skips `.envrc` file creation
- Environment still fully functional
- Use `pyve run` to execute commands
- No direnv dependency required

**Examples:**
```bash
# Venv without direnv
pyve init --no-direnv
pyve run python --version

# Micromamba without direnv
pyve init --backend micromamba --no-direnv
pyve run pytest

# CI/CD setup
pyve init --backend micromamba --auto-bootstrap --no-direnv --strict
pyve run pytest tests/
```

## CI/CD Integration

Pyve is designed for deterministic, reproducible environments in CI/CD pipelines.

### GitHub Actions

**Venv Backend:**
```yaml
name: Test with Venv
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install asdf
        uses: asdf-vm/actions/setup@v3
      
      - name: Install Python
        run: |
          asdf plugin add python
          asdf install python 3.11.7
      
      - name: Install Pyve
        run: |
          git clone https://github.com/pointmatic/pyve.git /tmp/pyve
          /tmp/pyve/pyve.sh self install
      
      - name: Initialize environment
        run: pyve init --no-direnv
      
      - name: Run tests
        run: pyve run pytest tests/
      
      - name: Check environment
        run: pyve check
```

**Micromamba Backend:**
```yaml
name: Test with Micromamba
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Pyve
        run: |
          git clone https://github.com/pointmatic/pyve.git /tmp/pyve
          /tmp/pyve/pyve.sh self install
      
      - name: Initialize environment
        run: |
          pyve init --backend micromamba \
               --auto-bootstrap \
               --no-direnv \
               --strict
      
      - name: Run tests
        run: pyve run pytest tests/
      
      - name: Check environment
        run: pyve check
```

**With Caching:**
```yaml
- name: Cache micromamba
  uses: actions/cache@v3
  with:
    path: ~/.pyve/bin/micromamba
    key: micromamba-${{ runner.os }}

- name: Cache environment
  uses: actions/cache@v3
  with:
    path: .pyve/envs
    key: env-${{ runner.os }}-${{ hashFiles('conda-lock.yml') }}
```

### GitLab CI

**Venv Backend:**
```yaml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y git curl
    - git clone https://github.com/pointmatic/pyve.git /tmp/pyve
    - /tmp/pyve/pyve.sh self install
    - export PATH="$HOME/.local/bin:$PATH"
  script:
    - pyve init --no-direnv
    - pyve run pytest tests/
    - pyve check
```

**Micromamba Backend:**
```yaml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y git curl
    - git clone https://github.com/pointmatic/pyve.git /tmp/pyve
    - /tmp/pyve/pyve.sh self install
    - export PATH="$HOME/.local/bin:$PATH"
  script:
    - pyve init --backend micromamba --auto-bootstrap --no-direnv --strict
    - pyve run pytest tests/
    - pyve check
  cache:
    paths:
      - .pyve/envs/
      - ~/.pyve/bin/
```

### Docker

**Dockerfile with Venv:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install Pyve
RUN git clone https://github.com/pointmatic/pyve.git /tmp/pyve && \
    /tmp/pyve/pyve.sh self install

# Copy project files
COPY . .

# Initialize environment
RUN pyve init --no-direnv

# Run application
CMD ["pyve", "run", "python", "app.py"]
```

**Dockerfile with Micromamba:**
```dockerfile
FROM ubuntu:22.04

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y git curl

# Install Pyve
RUN git clone https://github.com/pointmatic/pyve.git /tmp/pyve && \
    /tmp/pyve/pyve.sh self install

# Copy project files
COPY environment.yml conda-lock.yml ./

# Initialize environment
RUN pyve init --backend micromamba --auto-bootstrap --no-direnv --strict

# Copy application
COPY . .

# Run application
CMD ["pyve", "run", "python", "app.py"]
```

### Best Practices

**For CI/CD:**
1. Always use `--no-direnv` (direnv not needed in CI)
2. Use `--auto-bootstrap` for micromamba (no interactive prompts)
3. Use `--strict` to enforce lock file validation
4. Cache environments and binaries for faster builds
5. Run `pyve check` to verify setup
6. Use `pyve run` for all command execution

**Caching Strategy:**
- Cache micromamba binary (`~/.pyve/bin/micromamba`)
- Cache environments (`.pyve/envs/` or `.venv/`)
- Use lock file hash as cache key
- Invalidate cache when dependencies change

**Example Complete Workflow:**
```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Cache Pyve
        uses: actions/cache@v3
        with:
          path: |
            ~/.pyve/bin
            .pyve/envs
          key: pyve-${{ runner.os }}-${{ hashFiles('conda-lock.yml') }}
      
      - name: Install Pyve
        run: |
          git clone https://github.com/pointmatic/pyve.git /tmp/pyve
          /tmp/pyve/pyve.sh self install
      
      - name: Setup environment
        run: |
          pyve init --backend micromamba \
               --auto-bootstrap \
               --no-direnv \
               --strict
      
      - name: Verify setup
        run: pyve check
      
      - name: Run tests
        run: pyve run pytest tests/ --cov
      
      - name: Run linters
        run: |
          pyve run black --check .
          pyve run mypy src/
```

## Security

- **Never commit secrets**: Pyve automatically adds `.env` to `.gitignore`
- **Restricted permissions**: `.env` files are created with `chmod 600` (owner read/write only)
- **Smart purge**: Non-empty `.env` files are preserved during purge to prevent data loss

## Future Feature Ideas
- Version management tool installation:
   - Automated installation of asdf
   - Automated installation of pyenv
   - Automated addition of Python plugin using asdf or pyenv
   - Automated installation of a Python version using either asdf or pyenv

## License

Apache License 2.0 - see LICENSE file.

## Copyright

Copyright (c) 2025-2026 Pointmatic (https://www.pointmatic.com)

## Acknowledgments

Thanks to the asdf, pyenv, micromamba, and direnv communities for their excellent tools.
