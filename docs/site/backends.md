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

# Lock dependencies
conda-lock --file environment.yml --platform linux-64

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
Else if requirements.txt exists:
    → Use venv backend
Else:
    → Use venv backend (default)
```

### Override Auto-Detection

Force a specific backend:

```bash
# Force venv
pyve --init --backend venv

# Force micromamba
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
# Install conda-lock
pip install conda-lock

# Generate lock file
conda-lock --file environment.yml --platform linux-64

# Creates conda-lock.yml with exact versions and hashes

# Install from lock file
conda-lock install --name myproject conda-lock.yml
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

# Lock for reproducibility
conda-lock --file environment.yml --platform linux-64 --platform osx-64

# Share conda-lock.yml with team
```

### Mixed Dependencies (micromamba)

```bash
# Initialize
pyve --init --backend micromamba

# Install conda packages
micromamba install numpy pandas -c conda-forge

# Install PyPI-only packages
pip install custom-internal-package

# Both work together in same environment
```

---

## Troubleshooting

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
conda-lock --file environment.yml --platform linux-64
# Commit conda-lock.yml to git
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
