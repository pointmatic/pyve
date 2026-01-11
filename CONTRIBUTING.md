# Contributing

Thank you for contributing! This guide explains how to work on this project.

## Documentation

- Building guide: `docs/guides/building_guide.md`
- Decision log: `docs/specs/decisions_spec.md`
- Version history: `docs/specs/versions_spec.md`
- Features spec: `docs/specs/features.md`

## Project Setup

Pyve is a Bash shell script project. To contribute:

1. Clone the repository
2. Make changes to `pyve.sh` or `lib/*.sh`
3. Test locally with `./pyve.sh --help`
4. Test `--init` and `--purge` in a temporary directory

## Versioning Workflow

All work is tracked in `docs/specs/versions_spec.md`:
- Add a new version at the top with a checklist of requirements
- Mark completed items `[x]`; append `[Implemented]` when complete
- Record major decisions in `docs/specs/decisions_spec.md`

## Code Style

- **Shell**: Bash 3.2+ compatible (no associative arrays, no `${var,,}`)
- **Modular**: Keep helper functions in `lib/*.sh`
- **Logging**: Use `log_info()`, `log_warning()`, `log_error()` from `lib/utils.sh`
- **Comments**: Minimal but clear function headers

## Architecture

### Backend System

Pyve supports two environment backends:

**Venv Backend:**
- Uses Python's built-in `venv` module
- Managed by asdf or pyenv for Python versions
- Dependencies via pip/pip-tools
- Environment location: `.venv/`

**Micromamba Backend:**
- Uses micromamba (conda-compatible)
- For data science/ML workflows
- Dependencies via conda/mamba packages
- Environment location: `.pyve/envs/<name>/`

### Module Structure

```
pyve.sh                      # Main entry point and orchestration
lib/
  ├── utils.sh              # Logging, validation, file operations
  ├── env_detect.sh         # Environment file detection helpers
  ├── backend_detect.sh     # Backend detection and priority
  ├── micromamba_core.sh    # Micromamba detection and version
  ├── micromamba_bootstrap.sh  # Micromamba installation
  ├── micromamba_env.sh     # Environment creation and naming
  ├── distutils_shim.sh     # Python 3.12+ distutils compatibility shim helpers
  └── version.sh            # Version tracking and validation
```

**Module Responsibilities:**

**`pyve.sh`:**
- CLI argument parsing
- Command routing (init, purge, run, doctor)
- High-level workflow orchestration
- Sources all lib modules

**`lib/utils.sh`:**
- Logging functions (log_info, log_warning, log_error, log_success)
- File validation (is_file_empty, file_exists)
- User prompts (prompt_yes_no)
- Common utilities

**`lib/config.sh`:**
- YAML configuration parsing
- Config file reading (.pyve/config)
- Config value extraction

**`lib/backend.sh`:**
- Backend detection from files
- Backend priority resolution
- Backend validation

**`lib/venv.sh`:**
- Python version management (asdf/pyenv)
- Venv creation and validation
- Direnv configuration for venv

**`lib/micromamba_core.sh`:**
- Micromamba binary detection
- Version checking
- Location detection (project/user/system)

**`lib/micromamba_bootstrap.sh`:**
- Interactive bootstrap prompts
- Auto-bootstrap for CI/CD
- Download and installation
- Platform detection (macOS/Linux)

**`lib/micromamba_env.sh`:**
- Environment file detection
- Lock file validation
- Environment naming resolution
- Environment creation and verification
- Direnv configuration for micromamba

### Backend Detection Flow

```
1. Check --backend flag (explicit override)
   ↓
2. Check .pyve/config (project configuration)
   ↓
3. Check environment.yml / conda-lock.yml (micromamba)
   ↓
4. Check pyproject.toml / requirements.txt (venv)
   ↓
5. Default to venv
```

### Environment Naming (Micromamba)

```
1. --env-name flag (explicit override)
   ↓
2. .pyve/config (project configuration)
   ↓
3. environment.yml name field
   ↓
4. Directory basename (sanitized)
```

## Testing

Pyve provides `make` targets for running tests (see the `Makefile` in the project root).

### Manual Testing

Test commands manually before submitting:
```bash
# In a temp directory
mkdir /tmp/pyve-test && cd /tmp/pyve-test
/path/to/pyve.sh --init
/path/to/pyve.sh --purge
```

### Test Isolation (IMPORTANT)

Do not let tests mutate developer state.

If a Bats unit test references `"$HOME/.pyve"` (or any user-global path), sandbox `HOME` to a temporary directory inside `setup()` and restore it in `teardown()`.

### Running pytest integration tests (v0.9.3)

Pyve integration tests can exercise destructive flows (e.g. `pyve --init --force`). To avoid clobbering your local dev tooling, follow the pattern Pyve already uses of running pytest from Pyve's dedicated dev/test runner environment. The environment will be automatically created if needed when running `pyve test`. 

You can also initialize the dev/test runner environment manually:

```bash
./pyve.sh testenv --init
./pyve.sh testenv --install -r requirements-dev.txt
./.pyve/testenv/venv/bin/python -m pytest tests/integration/ -v
```

Before Pyve is installed on your system (allowing you to run `pyve` from any directory), you can run tests from the repo script:

```bash
./pyve.sh test -q
./pyve.sh test tests/integration/test_testenv.py
```

If `pytest` is missing from the dev/test runner environment, Pyve will prompt in interactive shells:

```text
pytest is not installed in the dev/test runner environment. Install now? [y/N]
```

### Purge behavior

`pyve --purge` removes Pyve-managed artifacts, including `.pyve/testenv`, by default.

To preserve the dev/test runner environment:

```bash
pyve --purge --keep-testenv
```

### Testing Both Backends

**Venv Backend:**
```bash
# Test venv initialization
cd /tmp/test-venv
echo 'requests==2.31.0' > requirements.txt
pyve --init --backend venv
pyve run python --version
pyve run pip list
pyve doctor
pyve --purge
```

**Micromamba Backend:**
```bash
# Test micromamba initialization
cd /tmp/test-micromamba
cat > environment.yml << EOF
name: test
dependencies:
  - python=3.11
  - numpy
  - pandas
EOF
pyve --init --backend micromamba --auto-bootstrap
pyve run python --version
pyve run python -c "import numpy; print(numpy.__version__)"
pyve doctor
pyve --purge
```

### Testing Auto-Detection

```bash
# Test auto-detection with environment.yml
cd /tmp/test-auto-micromamba
cat > environment.yml << EOF
name: autotest
dependencies:
  - python=3.11
EOF
pyve --init  # Should auto-detect micromamba

# Test auto-detection with requirements.txt
cd /tmp/test-auto-venv
echo 'requests' > requirements.txt
pyve --init  # Should auto-detect venv
```

### Testing `pyve run`

```bash
# Test command execution
pyve --init
pyve run python --version
pyve run python -c "print('Hello from pyve')"
pyve run pip install requests
pyve run python -c "import requests; print(requests.__version__)"
```

### Testing `pyve doctor`

```bash
# Test diagnostics
pyve --init
pyve doctor  # Should show healthy environment

# Test with issues
rm -rf .venv
pyve doctor  # Should show errors
```

### Testing Lock File Validation

```bash
# Test strict mode
cd /tmp/test-strict
cat > environment.yml << EOF
name: stricttest
dependencies:
  - python=3.11
EOF
pyve --init --backend micromamba --strict  # Should error (no lock file)

# Generate lock file
conda-lock -f environment.yml -p linux-64
pyve --init --backend micromamba --strict  # Should succeed

# Test stale lock file
touch environment.yml
pyve --init --backend micromamba --strict  # Should error (stale)
```

### Testing CI/CD Mode

```bash
# Test --no-direnv flag
pyve --init --no-direnv
test ! -f .envrc  # Should pass (no .envrc created)
pyve run python --version  # Should still work

# Test auto-bootstrap
pyve --init --backend micromamba --auto-bootstrap --no-direnv
```

### Testing Edge Cases

```bash
# Test reserved environment names
pyve --init --backend micromamba --env-name base  # Should error

# Test invalid environment names
pyve --init --backend micromamba --env-name "My Project!"  # Should sanitize

# Test missing micromamba
# (Uninstall micromamba first)
pyve --init --backend micromamba  # Should prompt for bootstrap

# Test command not found
pyve --init
pyve run nonexistent  # Should error with exit code 127
```

### Regression Testing

Before releasing a new version:

1. Test all commands with venv backend
2. Test all commands with micromamba backend
3. Test auto-detection for both backends
4. Test `pyve run` with various commands
5. Test `pyve doctor` diagnostics
6. Test `--no-direnv` flag
7. Test `--strict` mode
8. Test bootstrap (interactive and auto)
9. Test on clean macOS system
10. Test on clean Linux system

## Planning
- For new projects, start with Project Context Q&A (see `docs/guides/llm_qa/project_context_questions.md`) to establish business/organizational context before technical planning.
- For significant features, update or create `docs/specs/technical_design_spec.md` (see `docs/guides/planning_guide.md` for structure).
- Add a `[Next]` version in `docs/specs/versions_spec.md` to outline upcoming work.

## README Checklist
When creating a minimal README for a new project stub, include:
- **Project summary**: one-sentence purpose and audience.
- **Prerequisites**: required runtimes/tools; environment setup expectations.
- **Installation**: how to install/build or a note that the repo is source-only.
- **Quickstart**: one or two commands to verify something runs.
- **Usage**: main CLI commands/flags or link to `docs/specs/technical_design_spec.md`.
- **Configuration**: primary env vars/flags/files.
- **Examples**: pointers to `examples/` and sample flows (if applicable).
- **Docs links**: `docs/guides/building_guide.md`, `docs/guides/planning_guide.md`, `docs/guides/testing_guide.md`, `docs/specs/decisions_spec.md`, `docs/specs/versions_spec.md`.
- **Contributing**: link to `CONTRIBUTING.md`.
- **Security**: don’t commit secrets; where to place local credentials (if any).
- **License**: if applicable.

## Security

- Do not commit secrets
- `.env` files should have `chmod 600` permissions

## Commits and PRs

- Keep changes scoped to the current version requirements
- Reference the version in PR title (e.g., "Implement v0.6.1")
- Summarize what changed and why

## Running the CLI
- Provide examples in the README and/or `docs/specs/technical_design_spec.md` matched to this project’s interfaces.
- Keep examples minimal and self‑verifying where possible.
