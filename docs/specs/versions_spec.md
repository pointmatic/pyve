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

### Notes
**Goal:** Implement core unit tests for backend detection and configuration.

---

## v0.8.1: pytest Setup and Configuration [Planned]
- [ ] Install pytest, pytest-cov, pytest-xdist
- [ ] Create `pytest.ini` configuration file
- [ ] Configure test paths, markers, and options
- [ ] Create `tests/integration/` directory structure
- [ ] Create `tests/fixtures/` directory with sample data
- [ ] Create `tests/helpers/pyve_test_helpers.py`
- [ ] Verify pytest runs successfully (even with no tests)

### Notes
**Goal:** Set up pytest framework and configuration.

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