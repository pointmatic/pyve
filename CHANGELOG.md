# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.1] - 2026-02-18

### Fixed
- Corrected kcov repository URL in CI workflow (was `SimonKagworthy/kcov`, now `SimonKagstrom/kcov`)

## [1.5.0] - 2026-02-17

### Added
- Installation source detection in `pyve doctor` output
- Shows whether Pyve is installed via Homebrew, from source, or manually installed
- 5 new unit tests for install source detection in `test_doctor.bats`

### Changed
- `pyve doctor` now displays installation source as first line of output
- Extracted `detect_install_source()` into `lib/utils.sh` for testability

## [1.4.1] - 2026-02-16

### Fixed
- Homebrew detection guard now uses `SCRIPT_DIR` instead of `command -v` for more reliable detection
- Fixed image path in README.md after `docs/site/` migration

### Changed
- Updated README.md to position Homebrew as primary installation method
- Improved Quick Start, Installation, and Uninstallation sections

## [1.4.0] - 2026-02-15

### Added
- Homebrew tap support for installation via `brew install pointmatic/tap/pyve`
- Homebrew install detection in `pyve --install` and `pyve --uninstall` commands
- Automated Homebrew formula updates via GitHub Actions on version tag push
- `.github/workflows/update-homebrew.yml` workflow for automatic formula updates

### Changed
- `pyve --install` and `pyve --uninstall` now warn and skip when Homebrew-managed install is detected
- `SCRIPT_DIR` resolution improved to work with Homebrew's `libexec/` structure

## [1.3.1] - 2026-02-14

### Added
- Comprehensive documentation updates in `testing_spec.md`
- kcov references added to `docs/guides/codecov-setup-guide.md`

### Changed
- Restructured `docs/` directory to separate user-facing site from developer docs
  - `docs/codecov-setup.md` → `docs/guides/codecov-setup-guide.md`
  - `docs/ci-cd-examples.md` → `docs/site/ci-cd.md`
  - `docs/images/` → `docs/site/images/`
  - `docs/index.html` → `docs/site/index.html`
- Updated test structure documentation to match actual 451 tests (265 Bats + 186 pytest)
- Updated CI/CD section to reflect 6-job test workflow
- Updated pytest.ini example with current markers

## [1.3.0] - 2026-02-13

### Added
- Bash code coverage via kcov integration
- Real line coverage for Bash scripts in Codecov reports
- `coverage-kcov` Makefile target for local coverage testing
- `tests/helpers/kcov-wrapper.sh` for integration test coverage
- Codecov flags configuration for Bash coverage with carryforward

### Changed
- Replaced Python-only coverage with combined Bash + Python coverage
- Updated `codecov.yml` with `bash` flag for `lib/` and `pyve.sh` paths
- Modified `pytest.ini` coverage configuration to focus on integration tests
- Documented Bash coverage setup in `testing_spec.md`

## [1.2.5] - 2026-02-12

### Added
- 8 new unit tests for `lib/distutils_shim.sh` functions
- 3 new integration tests for `pyve doctor` edge cases
- 1 new integration test for `pyve run` with no command argument
- Total test count: 451 tests (265 Bats + 186 pytest)

### Changed
- Increased test coverage toward 80% target

## [1.2.4] - 2026-02-11

### Added
- 6 new edge case tests for `read_config_value` in `test_utils.bats`
- 3 new tests for `pyve_is_distutils_shim_disabled` in `test_distutils_shim.bats`
- 2 new tests for `pyve_get_python_major_minor` in `test_distutils_shim.bats`
- 5 new unit tests for `run_full_validation` in `test_version.bats`
- Total unit tests: 257 (up from 241)

### Changed
- Improved test coverage for low-coverage functions

## [1.2.3] - 2026-02-10

### Added
- 7 new unit tests for `lib/version.sh` functions
- Tests for `compare_versions()` edge cases
- Tests for `validate_installation_structure()` happy and warning paths
- Tests for `update_config_version()` and `write_config_with_version()`
- Total unit tests: 36 in `test_version.bats` (up from 29)

## [1.2.2] - 2026-02-09

### Added
- Activated all remaining validate test classes
- 21 passing tests in `test_validate.py` (up from 14)

### Fixed
- Test assertions in `TestValidateEdgeCases` for corrupted/empty config
- Test assertions in `TestValidateWithDoctor` for version warnings
- Platform-specific tests in `TestValidateMacOS` and `TestValidateLinux`

## [1.2.1] - 2026-02-08

### Added
- `docs/specs/descriptions.md` as canonical source for all project descriptions
- `docs/index.html` marketing landing page with banner image
- Comprehensive project descriptions including one-liner, technical descriptions, benefits, and feature cards

### Changed
- Distributed descriptions to `README.md` and `docs/specs/features.md`
- Updated Usage Notes table in `descriptions.md` with actual line numbers

## [1.2.0] - 2026-02-07

### Added
- `init_venv()` and `init_micromamba()` helper methods to `ProjectBuilder` in test helpers
- `_escalate()` helper function for proper exit code handling

### Fixed
- Exit code severity bug in `run_full_validation()` where warnings (exit 2) were overwriting errors (exit 1)
- All test assertions in `test_validate.py` to match actual `--validate` output

### Changed
- Activated validate integration tests by removing skip decorators
- 14 tests now passing in `TestValidateCommand` class

## [1.1.4] - 2026-02-06

### Fixed
- `.gitignore` idempotency issue on CI where Pyve-managed patterns leaked into user-entries section
- Added dynamic Pyve-managed patterns (`.envrc`, `.env`, `.pyve/testenv`, `.pyve/envs`, `.venv`) to deduplication array in `write_gitignore_template()`

### Changed
- Improved `test_gitignore_idempotent` reliability on GitHub Actions

## [1.0.0] - 2026-01-15

### Added
- Initial stable release
- Python virtual environment management via venv and micromamba backends
- Automatic Python version management via asdf or pyenv
- direnv integration for seamless shell activation
- CI/CD support with `--no-direnv`, `--auto-bootstrap`, and `--strict` flags
- `pyve run` command for explicit environment execution
- `pyve doctor` command for environment diagnostics
- `pyve --validate` command for installation validation
- `pyve test` command with isolated dev/test runner environment
- Comprehensive test suite with 186 pytest integration tests and 265 Bats unit tests
- GitHub Actions CI/CD with 6-job test matrix
- Codecov integration for coverage tracking
- Complete documentation in README.md

### Changed
- Project reached production-ready status
- All core features implemented and tested

[1.5.1]: https://github.com/pointmatic/pyve/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/pointmatic/pyve/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/pointmatic/pyve/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/pointmatic/pyve/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/pointmatic/pyve/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/pointmatic/pyve/compare/v1.2.5...v1.3.0
[1.2.5]: https://github.com/pointmatic/pyve/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/pointmatic/pyve/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/pointmatic/pyve/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/pointmatic/pyve/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/pointmatic/pyve/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/pointmatic/pyve/compare/v1.1.4...v1.2.0
[1.1.4]: https://github.com/pointmatic/pyve/compare/v1.0.0...v1.1.4
[1.0.0]: https://github.com/pointmatic/pyve/releases/tag/v1.0.0
