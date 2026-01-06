# Pyve Version History
See `docs/guide_versions_spec.md`

---

## High-Level Feature Checklist

### Phase 2: Testing Framework (v0.8.0 - v0.8.6)

**Test Infrastructure:**
- [ ] Test directory structure (`tests/unit/`, `tests/integration/`, `tests/helpers/`, `tests/fixtures/`)
- [ ] Bats installation and setup
- [ ] pytest installation and configuration
- [ ] pytest.ini configuration file
- [ ] Makefile for test execution
- [ ] Test helper utilities (Bash and Python)

**Bats Unit Tests (White-box):**
- [ ] Backend detection tests (`test_backend_detect.bats`)
- [ ] Config parsing tests (`test_config_parse.bats`)
- [ ] Environment naming tests (`test_env_naming.bats`)
- [ ] Micromamba core tests (`test_micromamba_core.bats`)
- [ ] Lock file validation tests (`test_lock_validation.bats`)
- [ ] Utility function tests (`test_utils.bats`)

**pytest Integration Tests (Black-box):**
- [ ] Venv workflow tests (`test_venv_workflow.py`)
- [ ] Micromamba workflow tests (`test_micromamba_workflow.py`)
- [ ] Auto-detection tests (`test_auto_detection.py`)
- [ ] Doctor command tests (`test_doctor.py`)
- [ ] Run command tests (`test_run_command.py`)
- [ ] Bootstrap tests (`test_bootstrap.py`)
- [ ] Cross-platform tests (`test_cross_platform.py`)

**Test Fixtures and Helpers:**
- [ ] pytest fixtures (`conftest.py`)
- [ ] PyveRunner helper class
- [ ] Bats test helpers (`test_helper.bash`)
- [ ] Sample test data (environment.yml, requirements.txt, configs)

**CI/CD Integration:**
- [ ] GitHub Actions workflow for testing
- [ ] Matrix builds (macOS, Linux)
- [ ] Python version matrix (3.10, 3.11, 3.12)
- [ ] Coverage reporting
- [ ] Codecov integration

**Documentation:**
- [ ] Test README.md
- [ ] Testing best practices documentation
- [ ] CI/CD testing examples
- [ ] Coverage reporting documentation

---

## v0.8.6: CI/CD Integration and Coverage [Planned]
- [ ] Create GitHub Actions workflow (`.github/workflows/test.yml`)
- [ ] Configure matrix builds (macOS, Linux × Python 3.10, 3.11, 3.12)
- [ ] Add coverage reporting with pytest-cov
- [ ] Integrate Codecov for coverage tracking
- [ ] Add coverage badges to README
- [ ] Test CI/CD workflow on both platforms
- [ ] Document CI/CD testing setup
- [ ] Bump version in pyve.sh from 0.8.5 to 0.8.6

### Notes
**Goal:** Integrate testing into CI/CD pipeline with coverage reporting.

---

## v0.8.5: pytest Integration Tests - Part 2 [Planned]
- [ ] Create `tests/integration/test_doctor.py` (doctor command tests)
- [ ] Create `tests/integration/test_run_command.py` (pyve run tests)
- [ ] Create `tests/integration/test_bootstrap.py` (micromamba bootstrap tests)
- [ ] Create `tests/integration/test_cross_platform.py` (platform-specific tests)
- [ ] Add parametrized tests for both backends
- [ ] Test error handling and edge cases
- [ ] Verify all integration tests pass
- [ ] Bump version in pyve.sh from 0.8.4 to 0.8.5

### Notes
**Goal:** Complete integration test coverage for all commands.

---

## v0.8.4: pytest Integration Tests - Part 1 [Planned]
- [ ] Create `tests/integration/conftest.py` with fixtures
- [ ] Implement `PyveRunner` helper class
- [ ] Create `tests/integration/test_venv_workflow.py` (init, run, doctor, purge)
- [ ] Create `tests/integration/test_micromamba_workflow.py` (init, run, doctor, purge)
- [ ] Create `tests/integration/test_auto_detection.py` (backend detection scenarios)
- [ ] Add test fixtures for sample projects
- [ ] Verify all workflow tests pass
- [ ] Bump version in pyve.sh from 0.8.3 to 0.8.4

### Notes
**Goal:** Implement core integration tests for both backends.

---

## v0.8.3: Bats Unit Tests - Part 2 [Planned]
- [ ] Create `tests/unit/test_micromamba_core.bats` (binary detection, version)
- [ ] Create `tests/unit/test_lock_validation.bats` (staleness, validation)
- [ ] Create `tests/unit/test_utils.bats` (logging, file operations)
- [ ] Add edge case tests for all modules
- [ ] Test error handling in unit tests
- [ ] Verify all unit tests pass
- [ ] Bump version in pyve.sh from 0.8.2 to 0.8.3

### Notes
**Goal:** Complete unit test coverage for micromamba and utility modules.

---

## v0.8.2: Bats Unit Tests - Part 1 [Planned]
- [ ] Create `tests/unit/test_backend_detect.bats` (file detection, priority resolution)
- [ ] Create `tests/unit/test_config_parse.bats` (YAML parsing, nested keys)
- [ ] Create `tests/unit/test_env_naming.bats` (sanitization, validation, resolution)
- [ ] Implement Bats setup/teardown functions
- [ ] Add test helper functions (`tests/helpers/test_helper.bash`)
- [ ] Verify all unit tests pass
- [ ] Bump version in pyve.sh from 0.8.1 to 0.8.2

### Notes
**Goal:** Implement core unit tests for backend detection and configuration.

---

## v0.8.1: pytest Setup and Configuration [Implemented]
- [x] Install pytest, pytest-cov, pytest-xdist
- [x] Create `pytest.ini` configuration file
- [x] Configure test paths, markers, and options
- [x] Create `tests/integration/` directory structure
- [x] Create `tests/fixtures/` directory with sample data
- [x] Create `tests/helpers/pyve_test_helpers.py`
- [x] Verify pytest runs successfully (even with no tests)
- [x] Bump version in pyve.sh from 0.7.12 to 0.8.1

### Notes
**Goal:** Set up pytest framework and configuration.

**Implementation Summary:**
- Installed pytest 9.0.2, pytest-cov 7.0.0, pytest-xdist 3.8.0 successfully
- Created comprehensive pytest.ini configuration with:
  - Test discovery paths (tests/integration)
  - 8 custom markers (slow, requires_micromamba, requires_asdf, requires_direnv, macos, linux, venv, micromamba)
  - Output and reporting options (verbose, short traceback, strict markers, color, maxfail)
  - Coverage configuration (source, omit patterns, reporting options)
- Created tests/helpers/pyve_test_helpers.py (330+ lines) with:
  - `PyveRunner` class - Helper for running pyve commands with methods for init, doctor, run, purge, config, version
  - `ProjectBuilder` class - Helper for building test project structures (requirements.txt, environment.yml, .pyve/config, Python scripts)
  - Utility assertion functions (assert_file_exists, assert_dir_exists, assert_command_success, assert_in_output)
- Created tests/integration/conftest.py with pytest fixtures:
  - `pyve_script` - Path to pyve.sh
  - `test_project` - Temporary test project directory
  - `pyve` - PyveRunner instance
  - `project_builder` - ProjectBuilder instance
  - `clean_env` - Clean environment variables
- Created sample test fixtures:
  - `tests/fixtures/environment.yml` - Sample conda environment file
  - `tests/fixtures/requirements.txt` - Sample pip requirements
  - `tests/fixtures/sample_configs/basic_venv.yml` - Sample venv config
  - `tests/fixtures/sample_configs/basic_micromamba.yml` - Sample micromamba config

**Testing Results:**
- ✓ pytest installed successfully (version 9.0.2)
- ✓ pytest-cov installed successfully (version 7.0.0)
- ✓ pytest-xdist installed successfully (version 3.8.0)
- ✓ pytest runs successfully: `pytest --version` works
- ✓ pytest collects tests: `pytest --collect-only` works (0 tests expected)
- ✓ pytest configuration loaded: rootdir and configfile detected
- ✓ pytest plugins loaded: xdist and cov plugins active

**Files Created:**
- `pytest.ini` - pytest configuration (45 lines)
- `tests/helpers/pyve_test_helpers.py` - Test helper classes and utilities (330+ lines)
- `tests/integration/conftest.py` - pytest fixtures (40+ lines)
- `tests/fixtures/environment.yml` - Sample conda environment
- `tests/fixtures/requirements.txt` - Sample pip requirements
- `tests/fixtures/sample_configs/basic_venv.yml` - Sample venv config
- `tests/fixtures/sample_configs/basic_micromamba.yml` - Sample micromamba config

**Files Modified:**
- `pyve.sh` - Bumped VERSION from 0.7.12 to 0.8.1 (line 23)

**Next Steps:**
- v0.8.2: Implement Bats unit tests (Part 1) for backend detection, config parsing, and environment naming

---

## v0.8.0: Test Infrastructure Setup [Implemented]
- [x] Create `tests/` directory structure
- [x] Create `tests/unit/` directory for Bats tests
- [x] Create `tests/integration/` directory for pytest tests
- [x] Create `tests/helpers/` directory for shared utilities
- [x] Create `tests/fixtures/` directory for test data
- [x] Install Bats (document installation for macOS and Linux)
- [x] Create `Makefile` with test targets (test, test-unit, test-integration, coverage, clean)
- [x] Create `tests/README.md` with testing documentation
- [x] Verify directory structure and Makefile work

### Notes
**Goal:** Establish test infrastructure and directory structure.

**Implementation Summary:**
- Created complete test directory structure with 4 subdirectories (unit, integration, helpers, fixtures)
- Created comprehensive Makefile with 6 test targets:
  - `make test` - Run all tests
  - `make test-unit` - Run Bats unit tests only
  - `make test-integration` - Run pytest integration tests only
  - `make test-all` - Run all tests with verbose output
  - `make coverage` - Run tests with coverage reporting
  - `make clean` - Clean test artifacts
- Makefile includes intelligent error handling for missing dependencies
- Created detailed tests/README.md (280+ lines) with:
  - Overview of hybrid testing approach
  - Directory structure documentation
  - Installation instructions for Bats and pytest
  - Running tests guide
  - Writing tests guide with examples
  - Test coverage goals
  - Best practices
  - CI/CD integration notes
  - Troubleshooting section

**Testing Results:**
- ✓ Directory structure created successfully (verified with `ls -la tests/`)
- ✓ Makefile help target works (`make help`)
- ✓ Makefile correctly handles missing tests (no Bats tests yet)
- ✓ Makefile correctly handles missing dependencies (pytest not installed)
- ✓ All targets functional and ready for test implementation

**Files Created:**
- `tests/unit/` - Directory for Bats unit tests
- `tests/integration/` - Directory for pytest integration tests
- `tests/helpers/` - Directory for shared test utilities
- `tests/fixtures/` - Directory for test data
- `Makefile` - Test execution targets (83 lines)
- `tests/README.md` - Comprehensive testing documentation (280+ lines)

**Next Steps:**
- v0.8.1: Set up pytest framework and configuration
- v0.8.2: Implement Bats unit tests (Part 1)

**Decision Reference:** [2026-01-06: Hybrid Testing Framework](docs/specs/design_decisions.md#9-testing-framework-strategy) — Adopted Bats + pytest hybrid approach for comprehensive testing coverage.

---