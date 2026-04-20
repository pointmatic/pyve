# Getting Started

Pyve is a command-line tool that simplifies Python virtual environment management on macOS and Linux. It orchestrates Python version managers (asdf/pyenv), virtual environment backends (venv/micromamba), and direnv for automatic activation.

## Installation

### Homebrew (Recommended)

The easiest way to install Pyve is via Homebrew:

```bash
brew install pointmatic/tap/pyve
```

To update Pyve:

```bash
brew upgrade pointmatic/tap/pyve
```

To uninstall:

```bash
brew uninstall pyve
```

### Git Clone (Manual Installation)

If you prefer to install from source:

```bash
# Clone the repository
git clone https://github.com/pointmatic/pyve.git
cd pyve

# Install to ~/.local/bin
./pyve.sh self install

# Verify installation
pyve --version
```

To update a manual installation:

```bash
cd /path/to/pyve
git pull origin main
./pyve.sh self install
```

To uninstall:

```bash
pyve self uninstall
```

## Prerequisites

Pyve requires one of the following Python version managers:

- **asdf** with python plugin
- **pyenv**

And optionally:

- **direnv** (for automatic environment activation)
- **micromamba** (for conda-based environments)

### Installing Prerequisites

=== "macOS"

    ```bash
    # Install asdf (recommended)
    brew install asdf
    asdf plugin add python
    
    # Or install pyenv
    brew install pyenv
    
    # Optional: Install direnv for auto-activation
    brew install direnv
    
    # Optional: Install micromamba for conda environments
    brew install micromamba
    ```

=== "Linux"

    ```bash
    # Install asdf (recommended)
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
    asdf plugin add python
    
    # Or install pyenv
    curl https://pyenv.run | bash
    
    # Optional: Install direnv
    # See https://direnv.net/docs/installation.html
    
    # Optional: Install micromamba
    # See https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html
    ```

## Quick Start

### 1. Initialize a New Project

Navigate to your project directory and initialize Pyve:

```bash
cd my-project
pyve init
```

This will:

- Detect or prompt for Python version
- Auto-detect backend (venv or micromamba) from project files
- **Prompt for backend choice** if both `environment.yml` and `pyproject.toml` exist
- Create a virtual environment (`.venv` by default for venv, `.pyve/envs/<name>` for micromamba)
- Upgrade pip to the latest version
- **Prompt to install pip dependencies** from `pyproject.toml` or `requirements.txt`
- Generate `.envrc` for direnv (if installed)
- Add entries to `.gitignore`

**Note:** Pyve uses interactive prompts to help you choose the right backend and install dependencies. For automated workflows, use `--backend`, `--auto-install-deps`, or `--no-install-deps` flags. See the [Backends Guide](backends.md) for details.

### 2. Activate the Environment

If you have direnv installed, the environment activates automatically when you `cd` into the directory.

Without direnv, activate manually:

```bash
source .venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Verify Setup

Check your environment status:

```bash
pyve doctor
```

This displays:

- Pyve version and installation source
- Active Python version
- Virtual environment backend and path
- Direnv status

## Common Workflows

### Creating a New Python Project

```bash
# Create project directory
mkdir my-new-project
cd my-new-project

# Initialize with specific Python version
pyve init 3.11

# Install packages
pip install requests pytest

# Save dependencies
pip freeze > requirements.txt
```

### Working with Existing Projects

```bash
# Clone repository
git clone https://github.com/user/project.git
cd project

# Initialize Pyve (reads .python-version if present)
pyve init

# Install dependencies
pip install -r requirements.txt
```

### Switching Python Versions

```bash
# Change Python version
pyve init 3.12

# Verify new version
python --version
```

### Using Micromamba Backend

For projects with conda dependencies, the fastest path is to let `pyve init` scaffold a starter `environment.yml` for you:

```bash
# 1. In a fresh directory, just run init with the micromamba backend.
#    Pyve scaffolds a minimal environment.yml (python + pip, conda-forge)
#    and creates the micromamba environment in one step.
mkdir myproject && cd myproject
pyve init --backend micromamba --python-version 3.12.13

# 2. Edit the scaffolded environment.yml to add your real dependencies.
#    The default scaffold pins only python=<version> and pip.
$EDITOR environment.yml

# 3. Generate conda-lock.yml once you're happy with environment.yml.
pyve lock

# 4. Install any additional conda packages (or run `pyve lock` again).
micromamba install -c conda-forge scipy
```

**Scaffolding contract.** Pyve only scaffolds when **both** `environment.yml` and `conda-lock.yml` are absent — a clear signal that this is a fresh project. It never overwrites an existing `environment.yml`. Under `--strict`, scaffolding is disabled (hand-authored files only).

**Already have an `environment.yml`?** Skip the scaffold — `pyve init` will use your file as-is:

```bash
# Existing project with environment.yml (but no conda-lock.yml yet):
pyve init --backend micromamba --no-lock   # proceed without a lock for now
pyve lock                                   # generate the lock file when ready

# Existing project with both files:
pyve init --backend micromamba             # uses the lock file for reproducibility
```

> **Note:** By default, `pyve init --backend micromamba` requires `conda-lock.yml` to exist alongside `environment.yml` for reproducibility. When the scaffolding path runs (fresh project, both files absent), `--no-lock` is auto-applied for the remainder of that init so the command can complete. For an existing project with `environment.yml` but no lock, pass `--no-lock` explicitly.

### Cleaning Up

Remove the virtual environment:

```bash
pyve purge
```

This removes:

- Virtual environment directory
- `.envrc` file
- Pyve-managed `.gitignore` entries

## Next Steps

- [Usage Guide](usage.md) - Full command reference
- [Backends](backends.md) - Understanding venv vs micromamba
- [CI/CD Integration](ci-cd.md) - Using Pyve in automated pipelines

## Troubleshooting

### Project Inside a Cloud-Synced Directory

If `pyve init` fails with `ERROR: Project is inside a cloud-synced directory`, move the project out of `~/Documents`, `~/Desktop`, `~/Dropbox`, `~/Google Drive`, or `~/OneDrive`:

```bash
mv ~/Documents/myproject ~/Developer/myproject
cd ~/Developer/myproject
pyve init
```

### Environment Not Activating

If direnv isn't activating automatically:

```bash
# Check direnv is installed and hooked
direnv version

# Allow the .envrc file
direnv allow
```

### Python Version Not Found

If Pyve can't find the requested Python version:

```bash
# Install with asdf
asdf install python 3.11.0
asdf global python 3.11.0

# Or with pyenv
pyenv install 3.11.0
pyenv global 3.11.0
```

### Command Not Found

If `pyve` command isn't found after installation:

```bash
# For Homebrew installation, verify it's in PATH
which pyve

# For manual installation, ensure ~/.local/bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

For more help, run:

```bash
pyve --help
```

Or check the [full documentation](usage.md).
