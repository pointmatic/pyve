# Pyve Testing Specification

This document defines the testing strategy, framework, and implementation plan for Pyve.

---

## Testing Philosophy

**Goal:** Comprehensive testing at multiple levels to ensure reliability, maintainability, and confidence in both venv and micromamba backends.

**Approach:** Hybrid testing strategy combining:
- **Bats** for white-box unit testing of shell functions
- **pytest** for black-box integration and end-to-end testing

---

## Testing Framework: Hybrid Bats + pytest

### Rationale

Pyve is a Python virtual environment orchestrator written in Bash, making a Python testing dependency perfectly reasonable. A hybrid approach provides:

1. **White-box testing (Bats):**
   - Direct testing of internal shell functions
   - Fast, focused unit tests
   - Native Bash testing environment
   - Easy to test edge cases in logic

2. **Black-box testing (pytest):**
   - Realistic user workflows
   - Excellent fixtures and parametrization
   - Rich assertion library and error messages
   - Coverage reporting
   - Parallel execution
   - Cross-platform testing

### Division of Responsibilities

**Bats Tests (Unit/White-box):**
- Shell function unit tests
- Internal logic verification
- Module-level testing (`lib/*.sh`)
- Config parsing
- Backend detection logic
- Environment naming resolution
- Lock file validation
- Fast, focused tests with direct function access

**pytest Tests (Integration/Black-box):**
- End-to-end workflows
- CLI integration tests
- Complete user scenarios
- Cross-platform testing
- Backend comparison tests
- CI/CD workflow validation
- Realistic environment creation/management

---

## Test Structure

```
tests/
├── unit/                           # Bats tests (white-box) — 10 files, 265 tests
│   ├── test_backend_detect.bats
│   ├── test_config_parse.bats
│   ├── test_distutils_shim.bats
│   ├── test_env_naming.bats
│   ├── test_lock_validation.bats
│   ├── test_micromamba_bootstrap.bats
│   ├── test_micromamba_core.bats
│   ├── test_reinit.bats
│   ├── test_utils.bats
│   └── test_version.bats
├── integration/                    # pytest tests (black-box) — 11 files, 186 tests
│   ├── conftest.py                # pytest fixtures (imports PyveRunner, ProjectBuilder)
│   ├── test_auto_detection.py
│   ├── test_bootstrap.py
│   ├── test_cross_platform.py
│   ├── test_doctor.py
│   ├── test_micromamba_workflow.py
│   ├── test_reinit.py
│   ├── test_run_command.py
│   ├── test_testenv.py
│   ├── test_validate.py
│   └── test_venv_workflow.py
├── helpers/
│   ├── test_helper.bash           # Bats helpers (setup_pyve_env, create_test_dir, assertions)
│   ├── pyve_test_helpers.py       # pytest helpers (PyveRunner, ProjectBuilder, assertions)
│   └── kcov-wrapper.sh            # kcov wrapper for Bash coverage during integration tests
├── fixtures/                       # Test data
│   ├── environment.yml
│   ├── requirements.txt
│   └── sample_configs/
│       ├── basic_micromamba.yml
│       └── basic_venv.yml
```

---

## Bats Test Examples

### Unit Test: Backend Detection

```bash
# tests/unit/test_backend_detect.bats
#!/usr/bin/env bats

# Load test helpers
load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "detect_backend_from_files: returns 'micromamba' for environment.yml" {
    create_environment_yml "test-env" "python=3.11"

    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "detect_backend_from_files: returns 'venv' for requirements.txt" {
    create_requirements_txt "requests==2.31.0"

    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}
```

### Unit Test: Config Parsing

```bash
# tests/unit/test_config_parse.bats
#!/usr/bin/env bats

# Load test helpers
load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "read_config_value: reads backend from config" {
    create_pyve_config "backend: micromamba"

    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "read_config_value: reads nested micromamba.env_name" {
    create_pyve_config "micromamba:" "  env_name: myproject"

    run read_config_value "micromamba.env_name"
    [ "$status" -eq 0 ]
    [ "$output" = "myproject" ]
}
```

---

## pytest Test Examples

### Shared Fixtures

Fixtures are defined in `conftest.py` and import helpers from `tests/helpers/pyve_test_helpers.py`:

```python
# tests/integration/conftest.py
import pytest
from pathlib import Path
import sys

# Add helpers to path
helpers_path = Path(__file__).parent.parent / 'helpers'
sys.path.insert(0, str(helpers_path))

from pyve_test_helpers import PyveRunner, ProjectBuilder

@pytest.fixture
def pyve_script():
    """Path to pyve.sh script."""
    return Path(__file__).parent.parent.parent / "pyve.sh"

@pytest.fixture
def test_project(tmp_path):
    """Create a temporary test project directory."""
    project_dir = tmp_path / "test_project"
    project_dir.mkdir()
    return project_dir

@pytest.fixture
def pyve(pyve_script, test_project):
    """Pyve runner fixture."""
    return PyveRunner(pyve_script, test_project)

@pytest.fixture
def project_builder(test_project):
    """Project builder fixture."""
    return ProjectBuilder(test_project)
```

`PyveRunner` provides `run()`, `init()`, `doctor()`, `run_cmd()`, `purge()`, `config()`, and `version()` methods. When `PYVE_KCOV_OUTDIR` is set, it automatically uses the kcov wrapper for Bash coverage collection.

`ProjectBuilder` provides `create_requirements_txt()`, `create_environment_yml()`, `create_pyve_config()`, `create_pyproject_toml()`, `init_venv()`, and `init_micromamba()` methods.

### Integration Test: Venv Workflow

```python
# tests/integration/test_venv_workflow.py
import pytest

@pytest.mark.venv
class TestVenvInit:
    def test_venv_init_creates_directory(self, pyve, test_project):
        """Test that pyve --init creates .venv directory"""
        result = pyve.init(backend='venv')

        assert result.returncode == 0
        assert (test_project / '.venv').is_dir()
        assert (test_project / '.venv' / 'bin' / 'python').exists()

    def test_venv_doctor_shows_backend(self, pyve, test_project):
        """Test that pyve doctor shows venv backend"""
        pyve.init(backend='venv')
        result = pyve.doctor()

        assert result.returncode == 0
        assert 'Backend: venv' in result.stdout

    def test_venv_run_executes_python(self, pyve, test_project):
        """Test that pyve run executes Python commands"""
        pyve.init(backend='venv')
        result = pyve.run_cmd('python', '--version')

        assert result.returncode == 0
        assert 'Python' in result.stdout
```

---

## pytest Configuration

```ini
# pytest.ini
[pytest]
testpaths = tests/integration
python_files = test_*.py
python_classes = Test*
python_functions = test_*

markers =
    slow: marks tests as slow (deselect with '-m "not slow"')
    requires_micromamba: tests that require micromamba installed
    requires_asdf: tests that require asdf installed
    requires_direnv: tests that require direnv installed
    macos: tests that only run on macOS
    linux: tests that only run on Linux
    venv: tests specific to venv backend
    micromamba: tests specific to micromamba backend

addopts = 
    -v
    --tb=short
    --strict-markers
    --color=yes
    -ra
    --maxfail=5
```

---

## Test Execution

### Running Tests

```bash
# Run all tests
make test

# Run only Bats unit tests
make test-unit

# Run only pytest integration tests
make test-integration

# Run venv tests in CI mode
make test-integration-ci

# Run Bash coverage via kcov
make coverage-kcov

# Run specific test file
pytest tests/integration/test_venv_workflow.py -v

# Run tests matching pattern
pytest tests/integration/ -k "venv"

# Run tests by marker
pytest tests/integration/ -m "venv and not requires_micromamba"
```

### Makefile

Key targets (see `make help` for the full list):

```makefile
.PHONY: test test-unit test-integration test-integration-ci test-all coverage coverage-kcov clean

test: test-unit test-integration          # Run all tests

test-unit:                                # Bats unit tests
test-integration:                         # pytest integration tests
test-integration-ci:                      # Venv tests with CI=true
test-integration-micromamba-ci:           # Micromamba tests with CI=true

coverage:                                 # pytest with --cov (Python helpers only)
coverage-kcov:                            # Bash line coverage via kcov (unit + integration)

clean:                                    # Remove .pytest_cache, htmlcov, .coverage, coverage-kcov
```

---

## CI/CD Integration

The CI pipeline (`.github/workflows/test.yml`) runs six parallel jobs:

| Job | Runner | Matrix | What it runs |
|-----|--------|--------|-------------|
| **Unit Tests** | ubuntu + macos | — | `make test-unit` (Bats) |
| **Integration Tests** | ubuntu + macos | Python 3.10, 3.11, 3.12 | pytest venv tests via pyenv |
| **Micromamba Tests** | ubuntu + macos | Python 3.11 | pytest micromamba tests |
| **Bash Coverage** | ubuntu | Python 3.11 | Bats + pytest under kcov → Codecov upload |
| **Lint** | ubuntu | — | ShellCheck, black, flake8 |
| **Test Summary** | ubuntu | — | Gate: fail if unit or integration fail |

Key details:

- **Triggers**: push/PR to `main`/`develop`, plus `workflow_dispatch`
- **Integration tests** install pyenv on the runner and pin to the `actions/setup-python` version to avoid slow builds
- **Bash Coverage** runs on Linux only (kcov is most reliable there) and uploads merged Cobertura XML to Codecov with the `bash` flag
- **Test Summary** is the required status check; it fails if unit or integration tests fail, but does not gate on micromamba, bash-coverage, or lint

---

## Test Coverage Status

### Current (v1.3.x): 451 tests

**Unit Tests (Bats) — 265 tests across 10 files:**

| Test File | Module Under Test | Coverage |
|-----------|-------------------|----------|
| `test_utils.bats` | `lib/utils.sh` | Logging, gitignore, config parsing, validation |
| `test_backend_detect.bats` | `lib/backend_detect.sh` | File detection, priority chain, validation |
| `test_config_parse.bats` | `lib/utils.sh` (config) | read_config_value edge cases |
| `test_distutils_shim.bats` | `lib/distutils_shim.sh` | Shim disabled check, version parsing, write paths |
| `test_env_naming.bats` | `lib/micromamba_env.sh` | Sanitization, reserved names, resolution |
| `test_lock_validation.bats` | `lib/micromamba_env.sh` | Stale/missing lock files, strict mode |
| `test_micromamba_bootstrap.bats` | `lib/micromamba_bootstrap.sh` | Download URL, install locations |
| `test_micromamba_core.bats` | `lib/micromamba_core.sh` | Binary detection, version, location |
| `test_reinit.bats` | `lib/version.sh` | Re-initialization logic |
| `test_version.bats` | `lib/version.sh` | Version comparison, validation, config writing |

**Integration Tests (pytest) — 186 tests across 11 files:**

| Test File | Workflow Tested |
|-----------|-----------------|
| `test_venv_workflow.py` | Full venv lifecycle (init, run, purge, .gitignore) |
| `test_micromamba_workflow.py` | Full micromamba lifecycle |
| `test_auto_detection.py` | Backend auto-detection from project files |
| `test_bootstrap.py` | Micromamba bootstrap (placeholder) |
| `test_cross_platform.py` | macOS/Linux-specific behavior |
| `test_doctor.py` | Doctor diagnostics for both backends |
| `test_reinit.py` | Re-initialization (update, force) |
| `test_run_command.py` | `pyve run` for both backends |
| `test_testenv.py` | Dev/test runner environment |
| `test_validate.py` | Installation validation (21 tests) |

### Coverage Target

- **Goal:** >80% Bash line coverage (measured via kcov)
- **Measurement:** kcov instruments `lib/*.sh` and `pyve.sh` during both Bats and pytest runs
- **Reporting:** Codecov with `bash` flag; HTML report via `make coverage-kcov`

---

## Testing Best Practices

1. **Isolation:** Each test should be independent and not rely on other tests
2. **Cleanup:** Always clean up temporary files and directories in teardown
3. **Determinism:** Tests should produce consistent results
4. **Fast feedback:** Unit tests should run quickly (< 1 second each)
5. **Clear assertions:** Use descriptive assertion messages
6. **Parametrization:** Use pytest parametrize for testing multiple scenarios
7. **Fixtures:** Leverage pytest fixtures for common setup
8. **Mocking:** Mock external dependencies when appropriate
9. **Coverage:** Aim for >80% code coverage
10. **Documentation:** Document complex test scenarios

---

## Bash Coverage (kcov)

Pyve is a Bash project, so Python-only coverage tools (`pytest-cov`) cannot measure the code under test. We use [kcov](https://github.com/SimonKagstrom/kcov) to collect Bash line coverage from both Bats unit tests and pytest integration tests.

### How It Works

1. **Bats unit tests** — kcov instruments all `source`d scripts automatically:
   ```bash
   kcov --include-path=lib/,pyve.sh --bash-dont-parse-binary-dir coverage-kcov bats tests/unit/*.bats
   ```

2. **pytest integration tests** — a wrapper script (`tests/helpers/kcov-wrapper.sh`) intercepts `pyve.sh` invocations. When `PYVE_KCOV_OUTDIR` is set, `PyveRunner` uses the wrapper instead of `pyve.sh` directly:
   ```bash
   PYVE_KCOV_OUTDIR=$(pwd)/coverage-kcov pytest tests/integration/ -v
   ```

3. **Merging** — kcov auto-merges results when multiple runs write to the same output directory. The merged report appears under `coverage-kcov/kcov-merged/`.

4. **Codecov upload** — the merged Cobertura XML (`coverage-kcov/kcov-merged/cobertura.xml`) is uploaded to Codecov with the `bash` flag.

### Key Flags

| Flag | Purpose |
|------|---------|
| `--include-path=lib/,pyve.sh` | Scope coverage to Pyve source files only |
| `--bash-dont-parse-binary-dir` | Prevent kcov from scanning unrelated scripts in the bats binary directory |

### CI Configuration

The `bash-coverage` job in `.github/workflows/test.yml` runs on `ubuntu-latest` only (kcov bash coverage is most reliable on Linux). It runs both Bats and pytest under kcov, then uploads the merged Cobertura XML to Codecov.

### Local Usage

```bash
# Requires: brew install kcov (macOS) or sudo apt-get install kcov (Linux)
make coverage-kcov
# Report: coverage-kcov/kcov-merged/index.html
```

---

## Dependencies

### Required
- **Bats:** Bash testing framework
  - macOS: `brew install bats-core`
  - Linux: `sudo apt-get install bats` or install from source

- **pytest:** Python testing framework
  - `pip install pytest pytest-cov pytest-xdist`

### Optional
- **pytest-xdist:** Parallel test execution
- **pytest-cov:** Coverage reporting (Python test helpers only)
- **kcov:** Bash line coverage
  - macOS: `brew install kcov`
  - Linux: `sudo apt-get install kcov`
- **codecov:** Coverage reporting service

---

## Summary

The hybrid Bats + pytest testing strategy provides:
- ✅ Comprehensive coverage (white-box + black-box)
- ✅ Fast feedback (Bats unit tests)
- ✅ Thorough validation (pytest integration tests)
- ✅ Multiple testing levels (unit, integration, E2E)
- ✅ Leverages Python's testing maturity for a Python tool
- ✅ Best tool for each job
- ✅ CI/CD ready
- ✅ Cross-platform support

This approach ensures Pyve is reliable, maintainable, and well-tested across both venv and micromamba backends.