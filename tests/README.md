# Pyve Testing

This directory contains the test suite for Pyve using a hybrid Bats + pytest approach.

## Overview

Pyve uses a hybrid testing strategy:
- **Bats** for white-box unit testing of shell functions
- **pytest** for black-box integration and end-to-end testing

This approach provides comprehensive coverage at multiple testing levels.

## Directory Structure

```
tests/
├── unit/                    # Bats unit tests (white-box)
│   ├── test_backend_detect.bats
│   ├── test_config_parse.bats
│   ├── test_env_naming.bats
│   ├── test_micromamba_core.bats
│   ├── test_lock_validation.bats
│   └── test_utils.bats
├── integration/             # pytest integration tests (black-box)
│   ├── conftest.py         # pytest fixtures
│   ├── test_venv_workflow.py
│   ├── test_micromamba_workflow.py
│   ├── test_auto_detection.py
│   ├── test_doctor.py
│   ├── test_run_command.py
│   ├── test_bootstrap.py
│   └── test_cross_platform.py
├── helpers/                 # Shared test utilities
│   ├── test_helper.bash    # Bats helper functions
│   └── pyve_test_helpers.py # pytest helper classes
├── fixtures/                # Test data
│   ├── environment.yml
│   ├── requirements.txt
│   └── sample_configs/
└── README.md               # This file
```

## CI/CD Integration

Pyve uses GitHub Actions for continuous integration and testing across multiple platforms and Python versions.

### Workflow Overview

The CI/CD pipeline (`.github/workflows/test.yml`) runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

### Test Jobs

**1. Unit Tests** (`unit-tests`)
- Runs on: Ubuntu and macOS
- Tests: Bats unit tests for shell functions
- Coverage: All unit test files in `tests/unit/`

**2. Integration Tests** (`integration-tests`)
- Matrix: Ubuntu/macOS × Python 3.10/3.11/3.12
- Tests: pytest integration tests (venv backend only)
- Coverage: Uploaded to Codecov with flags per OS/Python version

**3. Micromamba Tests** (`integration-tests-micromamba`)
- Matrix: Ubuntu/macOS × Python 3.11
- Tests: pytest integration tests requiring micromamba
- Coverage: Uploaded to Codecov separately

**4. Coverage Report** (`coverage-report`)
- Combines coverage from all test jobs
- Generates HTML coverage report
- Uploads combined coverage artifact

**5. Lint** (`lint`)
- Runs shellcheck on shell scripts
- Runs black and flake8 on Python code

**6. Test Summary** (`test-summary`)
- Aggregates results from all jobs
- Fails if any required tests fail

### Coverage Reporting

Coverage is tracked using:
- **pytest-cov**: Generates coverage during test runs
- **Codecov**: Aggregates and visualizes coverage across jobs
- **Badges**: Displayed in README.md

Configuration:
- `.codecov.yml`: Codecov settings and component management
- `pytest.ini`: pytest coverage configuration

### Running Tests Locally

To run the same tests as CI/CD:

```bash
# Unit tests (Bats)
make test-unit

# Integration tests (pytest)
pytest tests/integration/ -v

# Integration tests with coverage
pytest tests/integration/ -v --cov=. --cov-report=xml --cov-report=term

# Specific markers
pytest tests/integration/ -v -m "venv"
pytest tests/integration/ -v -m "micromamba"
pytest tests/integration/ -v -m "macos"
pytest tests/integration/ -v -m "linux"
```

### Test Markers

pytest markers for selective test execution:
- `venv`: Tests for venv backend
- `micromamba`: Tests for micromamba backend
- `requires_micromamba`: Tests that require micromamba installed
- `macos`: macOS-specific tests
- `linux`: Linux-specific tests
- `slow`: Long-running tests

### Platform-Specific Testing

The CI/CD pipeline tests on:
- **Ubuntu Latest**: Linux compatibility
- **macOS Latest**: macOS compatibility (both Intel and Apple Silicon)

Python versions tested:
- Python 3.10
- Python 3.11
- Python 3.12

### Viewing Results

- **GitHub Actions**: Check the Actions tab in the repository
- **Codecov**: Visit https://codecov.io/gh/pointmatic/pyve
- **Badges**: Status shown in README.md

## Installation

### Bats (for unit tests)

**macOS:**
```bash
brew install bats-core
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### pytest (for integration tests)

```bash
pip install pytest pytest-cov pytest-xdist
```

## Running Tests

### Quick Start

```bash
# Run all tests
make test

# Run only unit tests
make test-unit

# Run only integration tests
make test-integration

# Run with coverage
make coverage

# Clean test artifacts
make clean
```

### Detailed Commands

**Bats unit tests:**
```bash
# Run all unit tests
bats tests/unit/*.bats

# Run specific test file
bats tests/unit/test_backend_detect.bats

# Run with verbose output
bats -t tests/unit/*.bats
```

**pytest integration tests:**
```bash
# Run all integration tests
pytest tests/integration/

# Run specific test file
pytest tests/integration/test_venv_workflow.py

# Run with verbose output
pytest tests/integration/ -v

# Run tests matching pattern
pytest tests/integration/ -k "venv"

# Run in parallel
pytest tests/integration/ -n auto

# Run with coverage
pytest tests/integration/ --cov=. --cov-report=html
```

## Writing Tests

### Bats Unit Tests

Bats tests are for testing internal shell functions directly (white-box testing).

**Example:**
```bash
#!/usr/bin/env bats

setup() {
  export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  source "$PYVE_ROOT/lib/backend_detect.sh"
  
  export TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "detect_backend_from_files: detects micromamba from environment.yml" {
  cat > environment.yml << EOF
name: test
dependencies:
  - python=3.11
EOF
  
  run detect_backend_from_files
  [ "$status" -eq 0 ]
  [ "$output" = "micromamba" ]
}
```

**Key points:**
- Use `setup()` and `teardown()` for test isolation
- Source the modules you want to test
- Use temporary directories for file operations
- Test internal functions directly
- Use `run` to capture command output and exit code

### pytest Integration Tests

pytest tests are for testing user workflows and CLI behavior (black-box testing).

**Example:**
```python
import pytest
from pathlib import Path

def test_venv_init_creates_directory(pyve, test_project):
    """Test that pyve --init creates .venv directory"""
    result = pyve.init(backend='venv')
    
    assert result.returncode == 0
    assert (test_project / '.venv').is_dir()
    assert (test_project / '.venv' / 'bin' / 'python').exists()

@pytest.mark.parametrize('backend', ['venv', 'micromamba'])
def test_doctor_works_for_both_backends(pyve, test_project, backend):
    """Test doctor works for both backends"""
    if backend == 'micromamba':
        (test_project / 'environment.yml').write_text("""
name: test
dependencies:
  - python=3.11
""")
        pyve.init(backend=backend, auto_bootstrap=True)
    else:
        pyve.init(backend=backend)
    
    result = pyve.doctor()
    assert result.returncode == 0
    assert f'Backend: {backend}' in result.stdout
```

**Key points:**
- Use fixtures for common setup (see `conftest.py`)
- Test complete user workflows
- Use `PyveRunner` helper class for running pyve commands
- Use parametrize for testing multiple scenarios
- Test realistic user scenarios

## Test Coverage Goals

### Phase 1 (v0.8.x)
- **Unit Tests (Bats):**
  - Backend detection (all functions)
  - Config parsing (all functions)
  - Environment naming (all functions)
  - Lock file validation (all functions)
  - Utility functions (critical paths)

- **Integration Tests (pytest):**
  - Venv workflow (init, run, doctor, purge)
  - Micromamba workflow (init, run, doctor, purge)
  - Auto-detection scenarios
  - Error handling

**Target:** >80% code coverage

## Best Practices

1. **Isolation:** Each test should be independent
2. **Cleanup:** Always clean up temporary files in teardown
3. **Determinism:** Tests should produce consistent results
4. **Fast feedback:** Unit tests should run quickly (< 1 second each)
5. **Clear assertions:** Use descriptive assertion messages
6. **Parametrization:** Use pytest parametrize for multiple scenarios
7. **Fixtures:** Leverage pytest fixtures for common setup
8. **Documentation:** Document complex test scenarios

## CI/CD Integration

Tests run automatically in CI/CD via GitHub Actions:
- Matrix builds: macOS and Linux
- Python versions: 3.10, 3.11, 3.12
- Coverage reporting via Codecov

See `.github/workflows/test.yml` for configuration.

## Troubleshooting

**Bats not found:**
```bash
# macOS
brew install bats-core

# Linux
sudo apt-get install bats
```

**pytest not found:**
```bash
pip install pytest pytest-cov pytest-xdist
```

**Tests failing:**
1. Check that you're in the project root directory
2. Verify all dependencies are installed
3. Run tests with verbose output: `pytest -v` or `bats -t`
4. Check test logs for specific error messages

## Resources

- **Bats Documentation:** https://bats-core.readthedocs.io/
- **pytest Documentation:** https://docs.pytest.org/
- **Pyve Testing Spec:** `docs/specs/testing_spec.md`
- **Design Decision:** `docs/specs/design_decisions.md#9-testing-framework-strategy`

## Contributing

When adding new features to Pyve:
1. Write unit tests for internal functions (Bats)
2. Write integration tests for user workflows (pytest)
3. Ensure all tests pass before submitting PR
4. Aim for >80% code coverage

See `CONTRIBUTING.md` for more details.
