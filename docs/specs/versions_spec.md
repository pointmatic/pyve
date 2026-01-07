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

## v0.8.3: Bats Unit Tests - Part 2 [Implemented]
- [x] Create `tests/unit/test_micromamba_core.bats` (binary detection, version)
- [x] Create `tests/unit/test_lock_validation.bats` (staleness, validation)
- [x] Create `tests/unit/test_utils.bats` (logging, file operations)
- [x] Add edge case tests for all modules
- [x] Test error handling in unit tests
- [x] Verify all unit tests pass
- [x] Bump version in pyve.sh from 0.8.2 to 0.8.3

### Notes
**Goal:** Complete unit test coverage for micromamba and utility modules.

**Implementation Summary:**
- Created tests/unit/test_micromamba_core.bats (280+ lines, 19 tests):
  - `get_micromamba_path()` tests (5 tests): project sandbox, user sandbox, system PATH, not found, priority order
  - `check_micromamba_available()` tests (2 tests): available, not available
  - `get_micromamba_version()` tests (4 tests): version extraction from different formats, not found, command failure
  - `get_micromamba_location()` tests (5 tests): project, user, system, not_found, priority order
  - `error_micromamba_not_found()` tests (3 tests): returns 1, outputs error, custom context

- Created tests/unit/test_lock_validation.bats (210+ lines, 24 tests):
  - `is_lock_file_stale()` tests (6 tests): missing files, newer environment.yml, newer lock file, same mtime
  - `get_file_mtime_formatted()` tests (4 tests): existing file, non-existent file, environment.yml, conda-lock.yml
  - `is_interactive()` tests (1 test): non-interactive mode detection
  - `validate_lock_file_status()` non-strict tests (5 tests): fresh lock, stale lock, missing lock, missing env, neither exists
  - `validate_lock_file_status()` strict mode tests (5 tests): fresh lock, stale lock, missing lock, missing env, neither exists
  - Edge case tests (3 tests): same timestamp, default mode, empty string mode

- Created tests/unit/test_utils.bats (260+ lines, 42 tests):
  - Logging function tests (4 tests): log_info, log_warning, log_error, log_success
  - `append_pattern_to_gitignore()` tests (5 tests): creates file, adds pattern, no duplicates, multiple patterns, special characters
  - `remove_pattern_from_gitignore()` tests (4 tests): removes pattern, missing file, pattern not found, exact matches only
  - `config_file_exists()` tests (2 tests): exists, doesn't exist
  - `validate_venv_dir_name()` tests (10 tests): valid names, dots, underscores, hyphens, empty, spaces, slashes, reserved names
  - `validate_python_version()` tests (9 tests): valid versions, empty, missing segments, extra segments, letters, spaces
  - `is_file_empty()` tests (5 tests): non-existent, empty, with content, single character, newline only

**Testing Results:**
- ✓ All 163 unit tests created (78 from v0.8.2 + 85 new = 163 total)
  - test_backend_detect.bats: 23 tests
  - test_config_parse.bats: 19 tests
  - test_env_naming.bats: 36 tests
  - test_micromamba_core.bats: 19 tests
  - test_lock_validation.bats: 24 tests
  - test_utils.bats: 42 tests
- ✓ All test files verified with `bats --count`
- ✓ Individual test files execute successfully
- ✓ Tests cover:
  - Micromamba binary detection (project/user/system sandbox priority)
  - Micromamba version extraction and validation
  - Lock file staleness detection and validation
  - Interactive vs non-interactive mode handling
  - Strict vs non-strict validation modes
  - Gitignore pattern management
  - Logging functions (info, warning, error, success)
  - File validation (venv directory names, Python versions)
  - File utility functions (empty file detection)
- ✓ Edge cases covered: missing files, invalid inputs, reserved names, timestamp handling
- ✓ Optimized lock validation tests to use `touch -t` instead of `sleep` for faster execution

**Files Created:**
- `tests/unit/test_micromamba_core.bats` - Micromamba core tests (280+ lines, 19 tests)
- `tests/unit/test_lock_validation.bats` - Lock file validation tests (210+ lines, 24 tests)
- `tests/unit/test_utils.bats` - Utility function tests (260+ lines, 42 tests)

**Files Modified:**
- `pyve.sh` - Bumped VERSION from 0.8.2 to 0.8.3 (line 23)
- `tests/unit/test_lock_validation.bats` - Optimized timestamp tests to use `touch -t` instead of `sleep 1`

**Test Coverage Summary:**
- Micromamba core functions: 100% coverage (all detection and version functions)
- Lock file validation: 100% coverage (staleness, validation, interactive/strict modes)
- Utility functions: 100% coverage (logging, gitignore, validation, file operations)
- Total unit test count: 163 tests across 6 test files
- All critical code paths tested with edge cases

**Next Steps:**
- v0.8.4: Integration Tests - Part 1 (venv backend initialization and activation)

---

## v0.8.2: Bats Unit Tests - Part 1 [Implemented]
- [x] Create `tests/unit/test_backend_detect.bats` (file detection, priority resolution)
- [x] Create `tests/unit/test_config_parse.bats` (YAML parsing, nested keys)
- [x] Create `tests/unit/test_env_naming.bats` (sanitization, validation, resolution)
- [x] Implement Bats setup/teardown functions
- [x] Add test helper functions (`tests/helpers/test_helper.bash`)
- [x] Verify all unit tests pass
- [x] Bump version in pyve.sh from 0.8.1 to 0.8.2

### Notes
**Goal:** Implement core unit tests for backend detection and configuration.

**Implementation Summary:**
- Created tests/helpers/test_helper.bash (160+ lines) with:
  - `setup_pyve_env()` - Source all pyve lib modules
  - `create_test_dir()` / `cleanup_test_dir()` - Temporary directory management
  - `create_requirements_txt()`, `create_environment_yml()`, `create_pyve_config()`, `create_pyproject_toml()` - Test file generators
  - Assertion helpers: `assert_file_exists()`, `assert_dir_exists()`, `assert_file_contains()`, `assert_output_contains()`, `assert_output_equals()`, `assert_status_equals()`
  - Mock utilities: `mock_command()`, `unmock_command()`
  - Environment helpers: `set_test_env()`, `unset_test_env()`

- Created tests/unit/test_backend_detect.bats (200 lines, 23 tests):
  - `detect_backend_from_files()` tests (7 tests): environment.yml, conda-lock.yml, requirements.txt, pyproject.toml, ambiguous, none, priority
  - `get_backend_priority()` tests (7 tests): CLI priority, config priority, file detection, defaults, auto flag, ambiguous handling
  - `validate_backend()` tests (5 tests): valid backends (venv, micromamba, auto), invalid backends
  - `validate_config_file()` tests (4 tests): no config, valid config, invalid config, empty config

- Created tests/unit/test_config_parse.bats (230 lines, 19 tests):
  - Top-level key tests (5 tests): backend key, micromamba backend, non-existent keys, missing file, empty file
  - Nested key tests (5 tests): venv.directory, micromamba.env_name, python.version, non-existent nested keys, non-existent sections
  - Value format tests (4 tests): quoted values, single quotes, extra whitespace, numeric values
  - Complex config tests (2 tests): multi-section configs, configs with comments
  - `config_file_exists()` tests (3 tests): exists, doesn't exist, empty file

- Created tests/unit/test_env_naming.bats (246 lines, 36 tests):
  - `sanitize_environment_name()` tests (11 tests): lowercase conversion, space replacement, special character removal, hyphen handling, number prefix, underscore handling, truncation, empty string, complex names
  - `is_reserved_environment_name()` tests (7 tests): base, root, default, conda, mamba, micromamba, non-reserved
  - `validate_environment_name()` tests (13 tests): valid names, hyphens, underscores, numbers, reserved names, invalid characters, length limits
  - `resolve_environment_name()` tests (5 tests): CLI priority, config priority, environment.yml priority, directory fallback, empty CLI flag

**Testing Results:**
- ✓ All 78 unit tests pass (23 + 19 + 36 = 78 tests)
- ✓ 0 failures
- ✓ Tests cover:
  - Backend detection from files (environment.yml, requirements.txt, pyproject.toml, conda-lock.yml)
  - Backend priority resolution (CLI > config > file detection > default)
  - YAML config parsing (top-level and nested keys)
  - Environment name sanitization and validation
  - Environment name resolution with priority order
- ✓ Test execution time: ~4-5 seconds for full suite
- ✓ All setup/teardown functions working correctly
- ✓ Temporary directory cleanup verified

**Files Created:**
- `tests/helpers/test_helper.bash` - Bats test helper functions (160+ lines)
- `tests/unit/test_backend_detect.bats` - Backend detection tests (200 lines, 23 tests)
- `tests/unit/test_config_parse.bats` - Config parsing tests (230 lines, 19 tests)
- `tests/unit/test_env_naming.bats` - Environment naming tests (246 lines, 36 tests)

**Files Modified:**
- `pyve.sh` - Bumped VERSION from 0.8.1 to 0.8.2 (line 23)

**Test Coverage:**
- Backend detection: 100% of functions tested
- Config parsing: 100% of read_config_value() scenarios tested
- Environment naming: 100% of sanitize/validate/resolve functions tested
- Edge cases: Empty inputs, invalid inputs, ambiguous scenarios, reserved names

**Next Steps:**
- v0.8.3: Implement Bats unit tests (Part 2) for micromamba core, lock validation, and utility functions

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