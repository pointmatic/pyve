# Examples of `pyve run <cmd>`

This document provides concrete, practical examples of using `pyve run <cmd>` and explains what it guarantees compared to running commands directly in your shell.

---

## What `pyve run` Means

`pyve run <cmd>` executes `<cmd>` **inside the project’s declared environment**, regardless of:

- Current shell state
- PATH ordering
- Whether `direnv` is active
- Whether a virtualenv or conda env is already activated

Think of it as an **explicit execution boundary**, similar to:

- `docker run`
- `poetry run`
- `micromamba run`

---

## 1. Basic sanity checks

### Check the project’s Python version

```bash
pyve run python -V
```

Guarantees:
- Uses the project’s environment
- Ignores global or shell Python
- Works even if nothing is activated

Contrast with:

```bash
python -V
```

Which depends entirely on shell state.

### Force a specific backend

```bash
pyve run --backend venv python -V
pyve run --backend micromamba python -V
```

Useful when:
- Testing different backends
- Debugging backend-specific issues
- Overriding auto-detection

---

## 2. Running project scripts

### Run a Python script

```bash
pyve run python scripts/train.py
```

Equivalent to:
- venv backend: `./.venv/bin/python scripts/train.py`
- conda backend: `micromamba run -p .pyve/envs/<env> python scripts/train.py`

But without shell activation or PATH mutation.

### Run with arguments

```bash
pyve run python main.py --epochs 50 --lr 0.001
```

---

## 3. Tooling commands

### Run tests

```bash
pyve run pytest
```

### Linting and formatting

```bash
pyve run ruff check .
pyve run black .
pyve run mypy src/
```

Ensures tools are run from the project environment.

---

## 4. Jupyter and notebooks (micromamba sweet spot)

### Start Jupyter Lab

```bash
pyve run jupyter lab
```

Benefits:
- Correct kernel every time
- No accidental global Jupyter
- No `conda activate`
- Correct binary dependencies

### Execute a notebook headlessly

```bash
pyve run jupyter nbconvert \
  --to notebook \
  --execute notebooks/eda.ipynb
```

Ideal for CI, reproducible analysis, and coursework.

---

## 5. One-off Python expressions

```bash
pyve run python -c "import numpy as np; print(np.__version__)"
```

Useful for diagnostics and quick checks.

### With environment variables

```bash
# Pass environment variables to the command
DEBUG=1 pyve run python script.py

# Multiple variables
DEBUG=1 LOG_LEVEL=info pyve run python script.py

# Using export (persists in shell)
export DEBUG=1
pyve run python script.py
```

Environment variables are passed through to the executed command.

---

## 6. Shell commands inside the environment

### Run a command pipeline

```bash
pyve run bash -c "python preprocess.py && python train.py"
```

All commands execute inside the same resolved environment.

---

## 7. Makefiles and task runners

### Makefile example

```makefile
test:
	pyve run pytest

train:
	pyve run python scripts/train.py
```

Now:
- No activation steps required
- Works locally and in CI

### Task runners

```bash
pyve run invoke build
pyve run poe test
pyve run tox
```

---

## 8. Running from outside the project directory

```bash
cd ~
pyve run python ~/projects/myapp/main.py
```

Why this matters:
- `direnv` does nothing here
- `pyve run` still resolves the correct project environment

---

## 9. CI usage example

```yaml
- name: Run tests
  run: pyve run pytest
```

No:
- `source .venv/bin/activate`
- `conda activate`
- PATH assumptions

---

## 10. micromamba-specific example

Given a project with `environment.yml`:

```bash
pyve run python -c "import torch; print(torch.cuda.is_available())"
```

Guarantees:
- Correct CPU/GPU build
- Correct binary stack
- No accidental pip fallback

---

## 11. Backend-Specific Examples

### Venv Backend Examples

**Running with pip packages:**
```bash
# Install and use packages
pyve run pip install requests flask
pyve run python -c "import requests; print(requests.__version__)"
pyve run flask run
```

**Development workflow:**
```bash
# Install dev dependencies
pyve run pip install -e ".[dev]"

# Run formatters and linters
pyve run black src/
pyve run isort src/
pyve run flake8 src/

# Run tests with coverage
pyve run pytest tests/ --cov=src --cov-report=html
```

**Package management:**
```bash
# List installed packages
pyve run pip list

# Show package info
pyve run pip show numpy

# Freeze dependencies
pyve run pip freeze > requirements.txt

# Install from requirements
pyve run pip install -r requirements.txt
```

### Micromamba Backend Examples

**Running with conda packages:**
```bash
# Import scientific libraries
pyve run python -c "import numpy; print(numpy.__version__)"
pyve run python -c "import pandas; print(pandas.__version__)"
pyve run python -c "import torch; print(torch.__version__)"
```

**Data science workflow:**
```bash
# Run Jupyter notebook
pyve run jupyter notebook

# Run Jupyter lab
pyve run jupyter lab

# Execute notebook from command line
pyve run jupyter nbconvert --execute analysis.ipynb
```

**ML/AI examples:**
```bash
# Check GPU availability
pyve run python -c "import torch; print(torch.cuda.is_available())"

# Run training script
pyve run python train.py --epochs 100 --batch-size 32

# Run inference
pyve run python predict.py --model-path models/best.pth
```

**Environment inspection:**
```bash
# List conda packages
pyve run conda list

# Show environment info
pyve run conda info

# Export environment
pyve run conda env export > environment-export.yml
```

### Cross-Backend Examples

**Testing both backends:**
```bash
# Test with venv
cd project-venv
pyve --init --backend venv
pyve run pytest tests/

# Test with micromamba
cd project-micromamba
pyve --init --backend micromamba
pyve run pytest tests/
```

**Backend comparison:**
```bash
# Venv: Direct execution
pyve run python script.py
# Internally: .venv/bin/python script.py

# Micromamba: Via micromamba run
pyve run python script.py
# Internally: micromamba run -p .pyve/envs/<name> python script.py
```

**Performance testing:**
```bash
# Time command execution (venv)
time pyve run python benchmark.py

# Time command execution (micromamba)
time pyve run python benchmark.py
```

---

## 12. Error Handling Examples

### Backend not found

```bash
$ pyve run python script.py
```

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

### Environment not initialized

```bash
$ pyve run pytest
```

```
ERROR: No Pyve environment found in current directory.

Run one of:
  pyve --init                    # Auto-detect backend
  pyve --init --backend venv     # Explicit venv
  pyve --init --backend micromamba  # Explicit micromamba
```

### Command not found in environment

```bash
$ pyve run pytest
```

```
ERROR: Command 'pytest' not found in environment.

Backend: venv
Environment: .venv

Install it with:
  pyve run pip install pytest
```

### Backend mismatch

```bash
$ pyve run --backend micromamba python script.py
```

```
WARNING: Forcing backend 'micromamba' but project uses 'venv'.

Project configuration: .pyve/config (backend: venv)
Forced backend: micromamba

Continue? [y/N]: _
```

---

## Rule of Thumb

- **Interactive development** → `direnv` + normal commands
- **Scripts, CI, automation, correctness** → `pyve run`

`pyve run` is the authoritative way to execute code in a Pyve-managed project.
