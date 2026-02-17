# Pyve CI/CD Integration Examples

This guide provides comprehensive examples for integrating Pyve into CI/CD pipelines across different platforms.

## Table of Contents

- [GitHub Actions](#github-actions)
- [GitLab CI](#gitlab-ci)
- [Docker](#docker)
- [Caching Strategies](#caching-strategies)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## GitHub Actions

### Basic Venv Workflow

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
          /tmp/pyve/pyve.sh --install
      
      - name: Initialize environment
        run: pyve --init --no-direnv
      
      - name: Install dependencies
        run: pyve run pip install -r requirements.txt
      
      - name: Run tests
        run: pyve run pytest tests/ -v
      
      - name: Check environment
        run: pyve doctor
```

### Basic Micromamba Workflow

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
          /tmp/pyve/pyve.sh --install
      
      - name: Initialize environment
        run: |
          pyve --init --backend micromamba \
               --auto-bootstrap \
               --no-direnv \
               --strict
      
      - name: Run tests
        run: pyve run pytest tests/ -v
      
      - name: Check environment
        run: pyve doctor
```

### Advanced Workflow with Caching

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.10', '3.11', '3.12']
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Cache Pyve installation
        uses: actions/cache@v3
        with:
          path: ~/.local/bin
          key: pyve-${{ runner.os }}-v1
      
      - name: Cache micromamba binary
        uses: actions/cache@v3
        with:
          path: ~/.pyve/bin/micromamba
          key: micromamba-${{ runner.os }}-v1
      
      - name: Cache environment
        uses: actions/cache@v3
        with:
          path: .pyve/envs
          key: env-${{ runner.os }}-py${{ matrix.python-version }}-${{ hashFiles('conda-lock.yml') }}
          restore-keys: |
            env-${{ runner.os }}-py${{ matrix.python-version }}-
      
      - name: Install Pyve
        run: |
          if [ ! -f ~/.local/bin/pyve ]; then
            git clone https://github.com/pointmatic/pyve.git /tmp/pyve
            /tmp/pyve/pyve.sh --install
          fi
      
      - name: Setup environment
        run: |
          pyve --init --backend micromamba \
               --auto-bootstrap \
               --no-direnv \
               --strict
      
      - name: Verify setup
        run: pyve doctor
      
      - name: Run tests
        run: pyve run pytest tests/ --cov --cov-report=xml
      
      - name: Run linters
        run: |
          pyve run black --check .
          pyve run mypy src/
          pyve run ruff check
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```

### Multi-Backend Testing

```yaml
name: Multi-Backend Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        backend: [venv, micromamba]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install asdf (for venv)
        if: matrix.backend == 'venv'
        uses: asdf-vm/actions/setup@v3
      
      - name: Install Python (for venv)
        if: matrix.backend == 'venv'
        run: |
          asdf plugin add python
          asdf install python 3.11.7
      
      - name: Install Pyve
        run: |
          git clone https://github.com/pointmatic/pyve.git /tmp/pyve
          /tmp/pyve/pyve.sh --install
      
      - name: Initialize environment
        run: |
          if [ "${{ matrix.backend }}" = "micromamba" ]; then
            pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict
          else
            pyve --init --backend venv --no-direnv
          fi
      
      - name: Run tests
        run: pyve run pytest tests/
      
      - name: Check environment
        run: pyve doctor
```

### Release Workflow

```yaml
name: Release
on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Pyve
        run: |
          git clone https://github.com/pointmatic/pyve.git /tmp/pyve
          /tmp/pyve/pyve.sh --install
      
      - name: Setup environment
        run: pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict
      
      - name: Run tests
        run: pyve run pytest tests/
      
      - name: Build package
        run: pyve run python -m build
      
      - name: Publish to PyPI
        env:
          TWINE_USERNAME: __token__
          TWINE_PASSWORD: ${{ secrets.PYPI_TOKEN }}
        run: pyve run twine upload dist/*
```

## GitLab CI

### Basic Venv Pipeline

```yaml
image: ubuntu:latest

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"

cache:
  paths:
    - .cache/pip
    - .venv/

before_script:
  - apt-get update && apt-get install -y git curl
  - git clone https://github.com/pointmatic/pyve.git /tmp/pyve
  - /tmp/pyve/pyve.sh --install
  - export PATH="$HOME/.local/bin:$PATH"

stages:
  - test
  - lint
  - deploy

test:
  stage: test
  script:
    - pyve --init --no-direnv
    - pyve run pytest tests/ -v --cov
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

lint:
  stage: lint
  script:
    - pyve --init --no-direnv
    - pyve run black --check .
    - pyve run mypy src/
    - pyve run ruff check
```

### Basic Micromamba Pipeline

```yaml
image: ubuntu:latest

variables:
  PYVE_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pyve"

cache:
  paths:
    - .cache/pyve
    - .pyve/envs/

before_script:
  - apt-get update && apt-get install -y git curl
  - git clone https://github.com/pointmatic/pyve.git /tmp/pyve
  - /tmp/pyve/pyve.sh --install
  - export PATH="$HOME/.local/bin:$PATH"

stages:
  - test
  - deploy

test:
  stage: test
  script:
    - pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict
    - pyve doctor
    - pyve run pytest tests/ -v
```

### Advanced Pipeline with Multiple Jobs

```yaml
image: ubuntu:latest

variables:
  PYVE_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pyve"

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .cache/pyve
    - .pyve/envs/
    - ~/.pyve/bin/

stages:
  - setup
  - test
  - lint
  - build
  - deploy

setup:
  stage: setup
  script:
    - apt-get update && apt-get install -y git curl
    - git clone https://github.com/pointmatic/pyve.git /tmp/pyve
    - /tmp/pyve/pyve.sh --install
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict
    - pyve doctor
  artifacts:
    paths:
      - .pyve/envs/
    expire_in: 1 hour

test:unit:
  stage: test
  dependencies:
    - setup
  script:
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve run pytest tests/unit/ -v

test:integration:
  stage: test
  dependencies:
    - setup
  script:
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve run pytest tests/integration/ -v

lint:black:
  stage: lint
  dependencies:
    - setup
  script:
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve run black --check .

lint:mypy:
  stage: lint
  dependencies:
    - setup
  script:
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve run mypy src/

build:
  stage: build
  dependencies:
    - setup
  script:
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve run python -m build
  artifacts:
    paths:
      - dist/
    expire_in: 1 week

deploy:
  stage: deploy
  dependencies:
    - build
  script:
    - export PATH="$HOME/.local/bin:$PATH"
    - pyve run twine upload dist/*
  only:
    - tags
```

## Docker

### Venv Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y git curl && \
    rm -rf /var/lib/apt/lists/*

# Install Pyve
RUN git clone https://github.com/pointmatic/pyve.git /tmp/pyve && \
    /tmp/pyve/pyve.sh --install && \
    rm -rf /tmp/pyve

# Add Pyve to PATH
ENV PATH="/root/.local/bin:$PATH"

# Copy project files
COPY requirements.txt .
COPY . .

# Initialize environment and install dependencies
RUN pyve --init --no-direnv && \
    pyve run pip install -r requirements.txt

# Run application
CMD ["pyve", "run", "python", "app.py"]
```

### Micromamba Dockerfile

```dockerfile
FROM ubuntu:22.04

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y git curl && \
    rm -rf /var/lib/apt/lists/*

# Install Pyve
RUN git clone https://github.com/pointmatic/pyve.git /tmp/pyve && \
    /tmp/pyve/pyve.sh --install && \
    rm -rf /tmp/pyve

# Add Pyve to PATH
ENV PATH="/root/.local/bin:$PATH"

# Copy environment files
COPY environment.yml conda-lock.yml ./

# Initialize environment
RUN pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict

# Copy application code
COPY . .

# Verify setup
RUN pyve doctor

# Run application
CMD ["pyve", "run", "python", "app.py"]
```

### Multi-Stage Dockerfile (Optimized)

```dockerfile
# Stage 1: Build environment
FROM ubuntu:22.04 AS builder

WORKDIR /app

RUN apt-get update && \
    apt-get install -y git curl && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/pointmatic/pyve.git /tmp/pyve && \
    /tmp/pyve/pyve.sh --install

ENV PATH="/root/.local/bin:$PATH"

COPY environment.yml conda-lock.yml ./

RUN pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict

# Stage 2: Runtime
FROM ubuntu:22.04

WORKDIR /app

# Copy Pyve and environment from builder
COPY --from=builder /root/.local/bin /root/.local/bin
COPY --from=builder /root/.pyve /root/.pyve
COPY --from=builder /app/.pyve /app/.pyve

ENV PATH="/root/.local/bin:$PATH"

# Copy application code
COPY . .

# Run application
CMD ["pyve", "run", "python", "app.py"]
```

### Docker Compose Example

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - .:/app
      - pyve-cache:/root/.pyve
    environment:
      - PYTHONUNBUFFERED=1
    command: pyve run python app.py
  
  test:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - .:/app
      - pyve-cache:/root/.pyve
    command: pyve run pytest tests/

volumes:
  pyve-cache:
```

## Caching Strategies

### GitHub Actions Caching

**Cache Micromamba Binary:**
```yaml
- name: Cache micromamba
  uses: actions/cache@v3
  with:
    path: ~/.pyve/bin/micromamba
    key: micromamba-${{ runner.os }}-v1
```

**Cache Environment:**
```yaml
- name: Cache environment
  uses: actions/cache@v3
  with:
    path: .pyve/envs
    key: env-${{ runner.os }}-${{ hashFiles('conda-lock.yml') }}
    restore-keys: |
      env-${{ runner.os }}-
```

**Cache Venv:**
```yaml
- name: Cache venv
  uses: actions/cache@v3
  with:
    path: .venv
    key: venv-${{ runner.os }}-${{ hashFiles('requirements.txt') }}
    restore-keys: |
      venv-${{ runner.os }}-
```

### GitLab CI Caching

```yaml
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .pyve/envs/
    - ~/.pyve/bin/
    - .venv/
  policy: pull-push
```

### Docker Layer Caching

```dockerfile
# Cache Pyve installation
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/pointmatic/pyve.git /tmp/pyve && \
    /tmp/pyve/pyve.sh --install

# Cache environment creation
RUN --mount=type=cache,target=/root/.pyve \
    pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict
```

## Best Practices

### 1. Always Use `--no-direnv` in CI

Direnv is not needed in CI environments:

```bash
pyve --init --no-direnv
```

### 2. Use `--auto-bootstrap` for Micromamba

Skip interactive prompts in CI:

```bash
pyve --init --backend micromamba --auto-bootstrap
```

### 3. Use `--strict` for Lock File Validation

Ensure reproducibility:

```bash
pyve --init --backend micromamba --strict
```

### 4. Cache Aggressively

Cache everything that doesn't change often:
- Micromamba binary
- Python environments
- Package caches

### 5. Run `pyve doctor` for Verification

Verify environment setup:

```bash
pyve doctor
```

### 6. Use `pyve run` for All Commands

Consistent execution:

```bash
pyve run pytest tests/
pyve run black .
pyve run mypy src/
```

### 7. Pin Lock Files

Always use lock files for reproducibility:
- `conda-lock.yml` for micromamba
- `requirements.txt` (with hashes) for venv

### 8. Test Both Backends

If your project supports both:

```yaml
strategy:
  matrix:
    backend: [venv, micromamba]
```

### 9. Use Matrix Builds

Test multiple Python versions:

```yaml
strategy:
  matrix:
    python-version: ['3.10', '3.11', '3.12']
```

### 10. Fail Fast

Use `--strict` to catch issues early:

```bash
pyve --init --strict
```

## Troubleshooting

### Micromamba Not Found

**Problem:** Micromamba binary not found in CI.

**Solution:** Ensure `--auto-bootstrap` is used:

```bash
pyve --init --backend micromamba --auto-bootstrap
```

### Cache Not Working

**Problem:** Environment not restored from cache.

**Solution:** Check cache key includes lock file hash:

```yaml
key: env-${{ runner.os }}-${{ hashFiles('conda-lock.yml') }}
```

### Lock File Stale

**Problem:** Lock file is older than environment.yml.

**Solution:** Regenerate lock file:

```bash
conda-lock -f environment.yml -p linux-64 -p osx-64
```

### Permission Denied

**Problem:** Permission errors when installing Pyve.

**Solution:** Ensure proper permissions:

```bash
chmod +x /tmp/pyve/pyve.sh
/tmp/pyve/pyve.sh --install
```

### Environment Not Found

**Problem:** `pyve run` fails with "No environment found".

**Solution:** Ensure `pyve --init` ran successfully:

```bash
pyve --init --no-direnv
pyve doctor  # Verify setup
pyve run python --version
```

### Slow Builds

**Problem:** CI builds are slow.

**Solution:** Implement caching:

```yaml
- name: Cache environment
  uses: actions/cache@v3
  with:
    path: .pyve/envs
    key: env-${{ hashFiles('conda-lock.yml') }}
```

### Command Not Found in Environment

**Problem:** Command not found when using `pyve run`.

**Solution:** Ensure package is in dependencies:

```yaml
# environment.yml
dependencies:
  - pytest
  - black
  - mypy
```

### Docker Build Fails

**Problem:** Docker build fails during environment creation.

**Solution:** Use `--no-direnv` and check logs:

```dockerfile
RUN pyve --init --backend micromamba --auto-bootstrap --no-direnv --strict && \
    pyve doctor
```

### GitLab CI PATH Issues

**Problem:** `pyve` command not found in GitLab CI.

**Solution:** Export PATH in before_script:

```yaml
before_script:
  - export PATH="$HOME/.local/bin:$PATH"
```

### Matrix Build Failures

**Problem:** Some matrix combinations fail.

**Solution:** Use conditional steps:

```yaml
- name: Setup for venv
  if: matrix.backend == 'venv'
  run: asdf install python ${{ matrix.python-version }}
```

## Additional Resources

- [Pyve Repository](https://github.com/pointmatic/pyve)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [Docker Documentation](https://docs.docker.com/)
- [conda-lock Documentation](https://conda.github.io/conda-lock/)

## Contributing

Found an issue or have a suggestion? Please open an issue or submit a pull request on GitHub.
