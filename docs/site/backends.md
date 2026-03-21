# Backends Guide

Pyve supports two virtual environment backends: **venv** (Python's built-in) and **micromamba** (conda-compatible). This guide explains when to use each, how they work, and how to switch between them.

## Overview

| Feature | venv | micromamba |
|---------|------|------------|
| **Type** | Python-only | Multi-language (Python, R, C++) |
| **Package Source** | PyPI (pip) | conda-forge, PyPI |
| **Binary Packages** | Limited | Extensive |
| **Environment Location** | `.venv/` | `.pyve/envs/<hash>/` |
| **Lock Files** | `requirements.txt` | `conda-lock.yml` |
| **Speed** | Fast | Slower (dependency solving) |
| **Disk Usage** | Smaller | Larger |
| **Best For** | Pure Python projects | Scientific computing, data science |

## venv Backend

### What is venv?

`venv` is Python's built-in virtual environment module. It creates isolated Python environments with their own site-packages directories.

### When to Use venv

- **Pure Python projects** with only PyPI dependencies
- **Web applications** (Django, Flask, FastAPI)
- **CLI tools** and scripts
- **Projects with simple dependencies**
- **When disk space is limited**
- **When speed is important**

### How venv Works

1. Creates `.venv/` directory in project root
2. Copies Python interpreter and pip
3. Isolates site-packages from system Python
4. Activates via `source .venv/bin/activate`

### venv Example

```bash
# Initialize with venv
pyve --init 3.11

# Install packages
pip install requests flask pytest

# Save dependencies
pip freeze > requirements.txt

# requirements.txt
requests==2.31.0
flask==3.0.0
pytest==7.4.3
```

### venv Advantages

✅ **Fast installation** - No dependency solving overhead  
✅ **Small footprint** - Minimal disk usage  
✅ **Simple** - Straightforward pip workflow  
✅ **Standard** - Built into Python  
✅ **Portable** - Works everywhere Python works  

### venv Limitations

❌ **No binary packages** - Compiles from source (slow for numpy, pandas)  
❌ **PyPI only** - Can't install conda packages  
❌ **No lock files** - `requirements.txt` doesn't capture full dependency tree  
❌ **Platform-specific** - Requirements may differ across OS  

---

## micromamba Backend

### What is micromamba?

`micromamba` is a fast, standalone conda package manager. It provides conda-compatible environments without the overhead of Anaconda or Miniconda.

### When to Use micromamba

- **Scientific computing** (numpy, scipy, pandas)
- **Data science** (jupyter, matplotlib, scikit-learn)
- **Machine learning** (tensorflow, pytorch)
- **Projects with C/C++ dependencies**
- **Cross-platform reproducibility**
- **When you need pre-built binaries**

### How micromamba Works

1. Creates environment in `.pyve/envs/<hash>/`
2. Uses content-addressable storage (hash-based)
3. Installs packages from conda-forge
4. Solves dependencies across all packages
5. Activates via micromamba shell hooks

### micromamba Example

```bash
# Initialize with micromamba
pyve --init 3.11 --backend micromamba

# Install conda packages
micromamba install numpy pandas matplotlib -c conda-forge

# Install PyPI packages (if needed)
pip install custom-package

# Lock dependencies (pyve detects platform automatically)
pyve lock

# conda-lock.yml (generated)
# Contains exact versions and hashes for reproducibility
```

### micromamba Advantages

✅ **Pre-built binaries** - Fast installation of scientific packages  
✅ **Cross-platform** - Consistent across macOS, Linux, Windows  
✅ **Lock files** - Full dependency tree with hashes  
✅ **Multi-language** - Python, R, C++, Julia  
✅ **Reproducible** - Exact environment recreation  
✅ **conda-forge** - Massive package repository  

### micromamba Limitations

❌ **Slower** - Dependency solving takes time  
❌ **Larger** - More disk space required  
❌ **Complex** - More moving parts  
❌ **Learning curve** - Different from pip workflow  

---

## Auto-Detection

Pyve automatically detects the appropriate backend based on project files:

### Detection Rules

```
If environment.yml or conda-lock.yml exists:
    → Use micromamba backend
Else if requirements.txt or pyproject.toml exists:
    → Use venv backend
Else:
    → Use venv backend (default)
```

### Ambiguous Case Handling

**New in v1.6.2:** When both conda/micromamba files (`environment.yml`, `conda-lock.yml`) and Python/pip files (`pyproject.toml`, `requirements.txt`) exist, Pyve will prompt interactively:

```
Detected files:
  • environment.yml (conda/micromamba)
  • pyproject.toml (Python project)

Initialize with micromamba backend? [Y/n]:
```

**Default behavior:**
- **Interactive mode:** Prompts user, defaults to micromamba (Y)
- **CI mode:** Automatically uses micromamba without prompting
- **Rationale:** `environment.yml` presence is a strong signal that the project needs conda packages

**Why this matters:**

Many data science and ML projects have both:
- `environment.yml` for conda packages (numpy, pandas, tensorflow)
- `pyproject.toml` for project metadata and pip-only packages

The interactive prompt ensures you get the right backend while maintaining good defaults.

### Override Auto-Detection

Force a specific backend:

```bash
# Force venv (skip prompt)
pyve --init --backend venv

# Force micromamba (skip prompt)
pyve --init --backend micromamba

# Or set environment variable
export PYVE_BACKEND=micromamba
pyve --init
```

---

## Switching Backends

### From venv to micromamba

```bash
# 1. Export current dependencies
pip freeze > requirements.txt

# 2. Remove venv environment
pyve --purge

# 3. Create environment.yml
cat > environment.yml << EOF
name: myproject
channels:
  - conda-forge
dependencies:
  - python=3.11
  - numpy
  - pandas
  - pip
  - pip:
    - requests
EOF

# 4. Initialize with micromamba
pyve --init --backend micromamba

# 5. Install dependencies
micromamba install --file environment.yml
```

### From micromamba to venv

```bash
# 1. Export pip dependencies
pip freeze > requirements.txt

# 2. Remove micromamba environment
pyve --purge

# 3. Initialize with venv
pyve --init --backend venv

# 4. Install dependencies
pip install -r requirements.txt
```

---

## Dependency Management

### venv: requirements.txt

**Basic format:**

```txt
requests==2.31.0
flask==3.0.0
pytest==7.4.3
```

**With hashes (more secure):**

```txt
requests==2.31.0 \
    --hash=sha256:942c5a758f98d7479d9cc2dce5fb87bc
flask==3.0.0 \
    --hash=sha256:7eb373984bf1c770023fce9db164ed0c
```

**Generate with pip-tools:**

```bash
# Install pip-tools
pip install pip-tools

# Create requirements.in
echo "requests" > requirements.in
echo "flask" >> requirements.in

# Compile to requirements.txt with hashes
pip-compile --generate-hashes requirements.in
```

### micromamba: environment.yml

**Basic format:**

```yaml
name: myproject
channels:
  - conda-forge
dependencies:
  - python=3.11
  - numpy>=1.24
  - pandas>=2.0
  - pip
  - pip:
    - requests>=2.31
```

**With conda-lock (reproducible):**

```bash
# Add conda-lock to environment.yml, then run pyve --init --force to install it
# Afterwards, generate a lock file:
pyve lock

# Creates conda-lock.yml with exact versions and hashes for the current platform
# Commit conda-lock.yml — pyve --init reads it for reproducible builds
```

---

## Performance Comparison

### Installation Speed

**Test: Install numpy, pandas, matplotlib**

| Backend | Time | Notes |
|---------|------|-------|
| venv (pip) | ~5 min | Compiles from source |
| micromamba | ~30 sec | Pre-built binaries |

**Winner:** micromamba (10x faster for scientific packages)

### Disk Usage

**Test: Same packages installed**

| Backend | Size | Notes |
|---------|------|-------|
| venv | ~200 MB | Minimal overhead |
| micromamba | ~500 MB | Includes conda infrastructure |

**Winner:** venv (2.5x smaller)

### Startup Time

**Test: Activate environment**

| Backend | Time | Notes |
|---------|------|-------|
| venv | ~50 ms | Simple PATH modification |
| micromamba | ~200 ms | Shell hook initialization |

**Winner:** venv (4x faster)

---

## Common Workflows

### Pure Python Web App (venv)

```bash
# Initialize
pyve --init 3.11

# Install dependencies
pip install django psycopg2-binary gunicorn

# Save
pip freeze > requirements.txt

# Deploy
# requirements.txt is standard, works everywhere
```

### Data Science Project (micromamba)

```bash
# Initialize
pyve --init 3.11 --backend micromamba

# Install scientific stack
micromamba install numpy pandas matplotlib jupyter scikit-learn -c conda-forge

# Create environment.yml
micromamba env export > environment.yml

# Lock for reproducibility (platform detected automatically)
pyve lock

# Share conda-lock.yml with team
git add conda-lock.yml && git commit -m "Lock conda environment"
```

### Mixed Dependencies (micromamba)

```bash
# Create environment.yml first
cat > environment.yml << EOF
name: myproject
channels:
  - conda-forge
dependencies:
  - python=3.11
  - numpy
  - pandas
  - pip
EOF

# Generate lock file (platform detected automatically)
pyve lock

# Initialize (reads conda-lock.yml for reproducibility)
pyve --init --backend micromamba

# Install PyPI-only packages
pip install custom-internal-package

# Both work together in same environment
```

> **Note:** `pyve --init` requires `conda-lock.yml` to exist. During initial project setup before the file has been generated, use `pyve --init --no-lock`.

### ML/Data Science Project with Both Files (v1.6.2+)

```bash
# Project structure:
# - environment.yml (conda packages: numpy, pandas, tensorflow)
# - pyproject.toml (project metadata and pip-only packages)

# Initialize (will prompt for backend)
pyve --init

# Output:
# Detected files:
#   • environment.yml (conda/micromamba)
#   • pyproject.toml (Python project)
# 
# Initialize with micromamba backend? [Y/n]: y

# After environment creation:
# Install pip dependencies from pyproject.toml? [Y/n]: y

# Result: micromamba environment with both conda and pip packages installed
```

**CI/CD for mixed projects:**

```bash
# Non-interactive mode
export CI=1
pyve --init --auto-install-deps

# Or explicit flags
pyve --init --backend micromamba --auto-install-deps
```

---

## IDE Integration

### VS Code / Windsurf / Cursor (micromamba)

When Pyve initializes a micromamba environment, it automatically generates
`.vscode/settings.json` to configure VS Code-compatible IDEs:

```json
{
  "python.defaultInterpreterPath": ".pyve/envs/<env_name>/bin/python",
  "python.terminal.activateEnvironment": false,
  "python.condaPath": ""
}
```

**Why each setting:**

- **`python.defaultInterpreterPath`** — tells the IDE exactly where the interpreter is, eliminating startup probing and ensuring language server features use the correct environment immediately
- **`python.terminal.activateEnvironment: false`** — Pyve activates the environment via direnv; IDE activation in new terminals would conflict with direnv's PATH ordering
- **`python.condaPath: ""`** — prevents the IDE from invoking micromamba or conda directly, keeping all environment management through Pyve

**`.gitignore` behavior:** `.vscode/settings.json` is automatically added to `.gitignore` (it is machine-specific). `.vscode/extensions.json` is not ignored — it is conventionally committed.

**Re-initialization:** The file is not overwritten on `pyve --init --update`. It is regenerated on `pyve --init --force`.

## Troubleshooting

### Project Inside a Cloud-Synced Directory

**Problem:** `pyve --init` fails with `ERROR: Project is inside a cloud-synced directory`

**Why it happens:** Pyve refuses to initialize inside `~/Documents`, `~/Desktop`, `~/Dropbox`, `~/Google Drive`, or `~/OneDrive`. Cloud sync daemons race against micromamba's package extraction, causing non-deterministic environment corruption.

**Solution:** Move the project outside the synced directory:

```bash
mv ~/Documents/myproject ~/Developer/myproject
cd ~/Developer/myproject
pyve --init
```

If you have disabled sync for that path and understand the risk:

```bash
pyve --init --allow-synced-dir
# or: export PYVE_ALLOW_SYNCED_DIR=1
```

### Missing conda-lock.yml (micromamba)

**Problem:** `pyve --init` fails with `ERROR: No conda-lock.yml found`

**Solution:** Generate the lock file first:

```bash
pyve lock       # detects platform automatically
pyve --init
```

Or invoke conda-lock directly if needed:

```bash
conda-lock -f environment.yml -p osx-arm64   # macOS Apple Silicon
conda-lock -f environment.yml -p linux-64     # Linux
```

During initial project setup before the lock file exists:

```bash
pyve --init --no-lock   # not recommended for shared projects
```

### venv: Package Won't Install

**Problem:** `pip install numpy` takes forever or fails

**Solution:** Switch to micromamba for pre-built binaries

```bash
pyve --purge
pyve --init --backend micromamba
micromamba install numpy -c conda-forge
```

### micromamba: Dependency Conflicts

**Problem:** `micromamba install` fails with conflict errors

**Solution:** Specify compatible versions or use pip

```bash
# Option 1: Specify versions
micromamba install "numpy>=1.24,<2.0" "pandas>=2.0"

# Option 2: Use pip for problematic package
pip install problematic-package
```

### Wrong Backend Detected

**Problem:** Pyve auto-detects wrong backend

**Solution:** Force the backend explicitly

```bash
pyve --init --backend venv
```

### Ambiguous Backend Prompt Appears

**Problem:** Pyve prompts for backend choice when you have both `environment.yml` and `pyproject.toml`

**Why it happens:** Your project has both conda and Python package files, making backend detection ambiguous

**Solutions:**

```bash
# Option 1: Answer the prompt (recommended)
# Press Enter to use micromamba (default)
# Or type 'n' to use venv

# Option 2: Force backend explicitly
pyve --init --backend micromamba

# Option 3: Set environment variable for CI/CD
export CI=1  # Auto-defaults to micromamba
pyve --init

# Option 4: Remove unused file
# If you don't need conda packages, remove environment.yml
rm environment.yml
pyve --init  # Will use venv
```

### Environment Size Too Large

**Problem:** micromamba environment uses too much disk

**Solution:** Clean cache and unused packages

```bash
# Clean micromamba cache
micromamba clean --all

# Or switch to venv if you don't need conda packages
pyve --purge
pyve --init --backend venv
```

---

## Best Practices

### Choose the Right Backend

**Use venv if:**
- Project has only PyPI dependencies
- Disk space is limited
- You need fast environment creation
- Team is familiar with pip

**Use micromamba if:**
- Project needs scientific packages (numpy, pandas, etc.)
- You need reproducible environments
- You have conda dependencies
- Cross-platform consistency is important

### Lock Your Dependencies

**venv:**
```bash
pip freeze > requirements.txt
# Or use pip-tools for better control
pip-compile --generate-hashes requirements.in
```

**micromamba:**
```bash
pyve lock
# Commit conda-lock.yml to git — it must be committed, not ignored
# (pyve --init hard-fails if conda-lock.yml is missing; use --no-lock only during initial setup)
```

### Document Your Choice

Add to README.md:

```markdown
## Development Setup

This project uses Pyve with the **venv** backend.

\`\`\`bash
pyve --init
pip install -r requirements.txt
\`\`\`
```

Or for micromamba:

```markdown
## Development Setup

This project uses Pyve with the **micromamba** backend for scientific packages.

\`\`\`bash
pyve --init --backend micromamba
micromamba install --file environment.yml
\`\`\`
```

---

## Next Steps

- [Usage Guide](usage.md) - Full command reference
- [CI/CD Integration](ci-cd.md) - Using Pyve in automated pipelines
- [Getting Started](getting-started.md) - Installation and quick start

## Further Reading

- [Python venv documentation](https://docs.python.org/3/library/venv.html)
- [micromamba documentation](https://mamba.readthedocs.io/en/latest/user_guide/micromamba.html)
- [conda-lock documentation](https://conda.github.io/conda-lock/)
- [pip-tools documentation](https://pip-tools.readthedocs.io/)
