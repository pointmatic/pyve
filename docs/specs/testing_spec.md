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
├── unit/                           # Bats tests (white-box)
│   ├── test_backend_detect.bats
│   ├── test_config_parse.bats
│   ├── test_env_naming.bats
│   ├── test_micromamba_core.bats
│   ├── test_lock_validation.bats
│   └── test_utils.bats
├── integration/                    # pytest tests (black-box)
│   ├── conftest.py                # pytest fixtures
│   ├── test_venv_workflow.py
│   ├── test_micromamba_workflow.py
│   ├── test_auto_detection.py
│   ├── test_doctor.py
│   ├── test_run_command.py
│   ├── test_bootstrap.py
│   └── test_cross_platform.py
├── helpers/
│   ├── test_helper.bash           # Bats helpers
│   └── pyve_test_helpers.py       # pytest helpers
├── fixtures/                       # Test data
│   ├── environment.yml
│   ├── requirements.txt
│   └── sample_configs/
├── pytest.ini                      # pytest configuration
├── Makefile                        # Test runner convenience
└── README.md                       # Testing documentation
```

---

## Bats Test Examples

### Unit Test: Backend Detection

```bash
# tests/unit/test_backend_detect.bats
#!/usr/bin/env bats

setup() {
  export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  source "$PYVE_ROOT/lib/backend_detect.sh"
  source "$PYVE_ROOT/lib/utils.sh"
  
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

@test "detect_backend_from_files: detects venv from requirements.txt" {
  echo "requests==2.31.0" > requirements.txt
  
  run detect_backend_from_files
  [ "$status" -eq 0 ]
  [ "$output" = "venv" ]
}

@test "sanitize_env_name: converts to lowercase and replaces spaces" {
  run sanitize_env_name "My ML Project"
  [ "$status" -eq 0 ]
  [ "$output" = "my-ml-project" ]
}
```

### Unit Test: Config Parsing

```bash
# tests/unit/test_config_parse.bats
#!/usr/bin/env bats

setup() {
  export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  source "$PYVE_ROOT/lib/config.sh"
  
  export TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  mkdir -p .pyve
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "read_config_value: reads backend from config" {
  cat > .pyve/config << EOF
backend: micromamba
EOF
  
  run read_config_value "backend"
  [ "$status" -eq 0 ]
  [ "$output" = "micromamba" ]
}

@test "read_config_value: reads nested micromamba.env_name" {
  cat > .pyve/config << EOF
micromamba:
  env_name: myproject
EOF
  
  run read_config_value "micromamba.env_name"
  [ "$status" -eq 0 ]
  [ "$output" = "myproject" ]
}
```

---

## pytest Test Examples

### Shared Fixtures

```python
# tests/integration/conftest.py
import pytest
import subprocess
from pathlib import Path

@pytest.fixture
def pyve_script():
    """Path to pyve.sh script"""
    return Path(__file__).parent.parent.parent / "pyve.sh"

@pytest.fixture
def test_project(tmp_path):
    """Create a temporary test project directory"""
    project_dir = tmp_path / "test_project"
    project_dir.mkdir()
    return project_dir

class PyveRunner:
    """Helper class to run pyve commands"""
    
    def __init__(self, script_path, cwd):
        self.script_path = script_path
        self.cwd = cwd
    
    def run(self, *args, check=True, capture=True):
        """Run pyve command"""
        cmd = [str(self.script_path)] + list(args)
        kwargs = {'cwd': self.cwd, 'check': check}
        if capture:
            kwargs['capture_output'] = True
            kwargs['text'] = True
        return subprocess.run(cmd, **kwargs)
    
    def init(self, backend=None, **kwargs):
        """Run pyve --init"""
        args = ['--init', '--no-direnv']
        if backend:
            args.extend(['--backend', backend])
        for key, value in kwargs.items():
            flag = f"--{key.replace('_', '-')}"
            if value is True:
                args.append(flag)
            elif value is not False:
                args.extend([flag, str(value)])
        return self.run(*args)
    
    def doctor(self):
        """Run pyve doctor"""
        return self.run('doctor')
    
    def run_cmd(self, *cmd_args):
        """Run pyve run <cmd>"""
        return self.run('run', *cmd_args)

@pytest.fixture
def pyve(pyve_script, test_project):
    """Pyve runner fixture"""
    return PyveRunner(pyve_script, test_project)
```

### Integration Test: Venv Workflow

```python
# tests/integration/test_venv_workflow.py
import pytest
from pathlib import Path

def test_venv_init_creates_directory(pyve, test_project):
    """Test that pyve --init creates .venv directory"""
    result = pyve.init(backend='venv')
    
    assert result.returncode == 0
    assert (test_project / '.venv').is_dir()
    assert (test_project / '.venv' / 'bin' / 'python').exists()

def test_venv_doctor_shows_backend(pyve, test_project):
    """Test that pyve doctor shows venv backend"""
    pyve.init(backend='venv')
    result = pyve.doctor()
    
    assert result.returncode == 0
    assert 'Backend: venv' in result.stdout
    assert '✓' in result.stdout

def test_venv_run_executes_python(pyve, test_project):
    """Test that pyve run executes Python commands"""
    pyve.init(backend='venv')
    result = pyve.run_cmd('python', '--version')
    
    assert result.returncode == 0
    assert 'Python' in result.stdout

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
    macos: tests that only run on macOS
    linux: tests that only run on Linux

addopts = 
    -v
    --tb=short
    --strict-markers
    --color=yes
    -ra
```

---

## Test Execution

### Running Tests

```bash
# Run all tests
make test

# Run only Bats unit tests
bats tests/unit/*.bats

# Run only pytest integration tests
pytest tests/integration/

# Run with coverage
pytest tests/integration/ --cov=. --cov-report=html

# Run specific test file
pytest tests/integration/test_venv_workflow.py -v

# Run tests matching pattern
pytest tests/integration/ -k "venv"

# Run in parallel
pytest tests/integration/ -n auto
```

### Makefile

```makefile
.PHONY: test test-unit test-integration test-all coverage clean

test: test-unit test-integration

test-unit:
	@echo "Running Bats unit tests..."
	@bats tests/unit/*.bats

test-integration:
	@echo "Running pytest integration tests..."
	@pytest tests/integration/ -v

test-all:
	@echo "Running all tests..."
	@bats tests/unit/*.bats
	@pytest tests/integration/ -v

coverage:
	@echo "Running tests with coverage..."
	@pytest tests/integration/ --cov=. --cov-report=html --cov-report=term
	@echo "Coverage report: htmlcov/index.html"

clean:
	@rm -rf .pytest_cache htmlcov .coverage
	@find . -type d -name __pycache__ -exec rm -rf {} +
```

---

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        python-version: ['3.10', '3.11', '3.12']
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}
      
      - name: Install Bats
        run: |
          if [ "$RUNNER_OS" == "Linux" ]; then
            sudo apt-get update
            sudo apt-get install -y bats
          else
            brew install bats-core
          fi
      
      - name: Install pytest and dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pytest pytest-cov pytest-xdist
      
      - name: Run Bats unit tests
        run: bats tests/unit/*.bats
      
      - name: Run pytest integration tests
        run: |
          pytest tests/integration/ \
            --cov=. \
            --cov-report=xml \
            --cov-report=term \
            -n auto
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
          flags: ${{ matrix.os }}-py${{ matrix.python-version }}
```

---

## Test Coverage Goals

### Phase 1 (v0.8.x): Foundation
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

### Phase 2 (Future): Comprehensive
- Edge cases and error conditions
- Cross-platform compatibility
- Performance benchmarks
- Regression test suite
- CI/CD workflow validation

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

## Dependencies

### Required
- **Bats:** Bash testing framework
  - macOS: `brew install bats-core`
  - Linux: `sudo apt-get install bats` or install from source

- **pytest:** Python testing framework
  - `pip install pytest pytest-cov pytest-xdist`

### Optional
- **pytest-xdist:** Parallel test execution
- **pytest-cov:** Coverage reporting
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