# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.0] - 2026-03-20

### Added
- `pyve lock` command: generates or updates `conda-lock.yml` for the current platform (micromamba projects only). Automatically detects the conda platform string via `get_conda_platform()` (`osx-arm64`, `osx-64`, `linux-64`, `linux-aarch64`), runs `conda-lock -f environment.yml -p <platform>`, suppresses the misleading `conda-lock install` post-run message, and prints actionable `pyve --init --force` guidance instead. Exits with an "already up to date" message when the spec hash is unchanged. Fails early with clear messages when the project uses the venv backend, when `conda-lock` is not on PATH, or when `environment.yml` is missing.

### Changed
- All user-facing messages that previously referenced raw `conda-lock -f environment.yml -p <platform>` commands now reference `pyve lock` (stale lock warning, missing lock error, strict-mode error in `warn_stale_lock_file()`, `info_missing_lock_file()`, and `validate_lock_file_status()` in `lib/micromamba_env.sh`).
- Policy update: Pyve no longer describes itself as "hands-off for conda-lock." Pyve does not install `conda-lock`, but wraps its invocation when it is available on PATH.

## [1.8.6] - 2026-03-20

### Fixed
- Fixed `--init --force` ignoring `environment.yml` when `.pyve/config` recorded an old backend: the force pre-flight now passes `skip_config=true` to `get_backend_priority`, bypassing the stale config and re-detecting the backend purely from CLI flag and project files. Projects with both `environment.yml` and `pyproject.toml` now correctly show the ambiguous backend prompt on force re-init regardless of what the old config said.

### Tests
- Fixed `test_force_reinit_prompts_and_respects_venv_choice_in_ambiguous_case`: corrected prompt order from `input="y\nn\n"` to `input="n\ny\n"` (after F.k/F.l fixes the backend prompt precedes the confirmation prompt) and added assertion that `"Initialize with micromamba backend?"` appeared in output
- Added `test_force_reinit_ignores_stale_config_backend`: regression test for F.l — verifies that `--force` pre-flight skips `.pyve/config` and re-runs file detection; asserts the ambiguous backend prompt appears, which proves `skip_config=true` is working (if it were not, Priority 2 would return `venv` silently and the prompt would never show)

## [1.8.5] - 2026-03-20

### Fixed
- Fixed double "Initialize with micromamba backend?" prompt during `--init --force` in projects with both `environment.yml` and `pyproject.toml`: the pre-flight backend result is now stored and reused in the main flow, so `get_backend_priority` is only called once
- Improved `--init --force` interactive UX: the final confirmation prompt now summarises what will be purged and rebuilt (including a `⚠ Backend change` warning when switching backends); cancelling prints "Cancelled — no changes made, existing environment preserved"
- Stale lock file abort message now reads "Aborted — no changes made" (was "Aborted") to confirm no environment was modified
- Ambiguous backend venv-choice message now reads "Using venv backend — initialization will continue with venv" for clarity

## [1.8.4] - 2026-03-20

### Fixed
- Fixed wrong conda platform string in lock file recommendations: `lib/micromamba_env.sh` now uses `get_conda_platform()` to map `uname -s`/`uname -m` to the correct conda platform (e.g. `osx-arm64` instead of `arm64` on Apple Silicon, `linux-aarch64` instead of `aarch64` on Linux ARM)
- Fixed `--init --force` pre-flight check ordering: lock file validation (and cloud sync detection) now runs before the environment is purged, so a failed or aborted check leaves the existing environment intact

## [1.8.3] - 2026-03-20

### Changed
- Updated GitHub Actions to Node.js 24 compatible versions: `actions/checkout@v4` → `@v6`, `actions/setup-python@v5` → `@v6`, `codecov/codecov-action@v4` → `@v5`, `mamba-org/setup-micromamba@v1` → `@v2` (latest; Node 24 migration pending upstream)

## [1.8.2] - 2026-03-20

### Fixed
- Fixed integration tests broken by the v1.8.0 missing `conda-lock.yml` hard-fail: `PyveRunner.run()` now sets `PYVE_NO_LOCK=1` automatically when running under pytest (same pattern as `PYVE_NO_INSTALL_DEPS`), covering all 40+ `pyve.init(backend='micromamba')` call sites in the integration test suite without modifying individual tests

## [1.8.1] - 2026-03-20

### Added
- `pyve doctor` now detects potential conda/pip native library conflicts: when pip packages that bundle their own OpenMP runtime (torch, tensorflow, jax) coexist with conda packages that link against the shared OpenMP in the environment's `lib/` directory (numpy, scipy, scikit-learn), and the required shared library (`libomp.dylib` on macOS, `libgomp.so` on Linux) is absent, a `⚠` warning is printed with the conflicting packages and a fix instruction (add `llvm-openmp` or `libgomp` to `environment.yml`)

## [1.8.0] - 2026-03-20

### Changed
- **Breaking:** `pyve --init` (micromamba backend) now hard fails when `conda-lock.yml` is missing, instead of prompting interactively or auto-continuing in CI. A missing lock file produces a non-reproducible environment — this should be an error, not a suggestion.
- New `--no-lock` flag (and `PYVE_NO_LOCK=1` env var) explicitly bypasses the check for first-time setup before a lock file has been generated
- Stale lock file behavior is unchanged: warns and prompts interactively, errors in `--strict` mode

## [1.7.3] - 2026-03-20

### Added
- `pyve doctor` now scans `site-packages` for duplicate `.dist-info` directories and reports conflicting versions with their mtimes
- `pyve doctor` now scans the environment tree for files/directories with ` 2` suffix — the iCloud Drive collision artifact naming used when two processes create the same path simultaneously
- Both checks run automatically for micromamba backends; report `✓` when clean or `✗` with actionable remediation steps

## [1.7.2] - 2026-03-20

### Added
- `pyve --init` with micromamba backend now generates `.vscode/settings.json` with the correct interpreter path and IDE isolation settings
- `.vscode/settings.json` is automatically added to `.gitignore` (machine-specific); `.vscode/extensions.json` is not affected
- File is skipped if it already exists (use `--force` to regenerate); re-generated on `pyve --init --force`

## [1.7.1] - 2026-03-20

### Added
- `pyve --init` now hard fails when the project directory is inside a cloud-synced directory (`~/Documents`, `~/Desktop`, `~/Dropbox`, `~/Google Drive`, `~/OneDrive`)
- Detection uses path heuristics (primary) and extended attributes via `xattr` (secondary, macOS only)
- Error message includes the sync root, provider name, recommended `mv` command, and `--allow-synced-dir` override
- New `--allow-synced-dir` flag (and `PYVE_ALLOW_SYNCED_DIR=1` env var) to bypass the check for users who have disabled sync on that path

### Why a hard fail, not a warning
Cloud sync daemons race against micromamba's package extraction, causing non-deterministic environment corruption that can damage the Python standard library itself. The failure is silent and delayed — a warning is insufficient because users will not connect the symptom (`ImportError`, `__pycache__ 2` directories) to the root cause without significant debugging effort.

## [1.7.0] - 2026-03-19

### Fixed
- `conda-lock.yml` was incorrectly added to `.gitignore` by `pyve --init` for micromamba projects
- `conda-lock.yml` is an explicitly committed artifact (like `package-lock.json` or `Cargo.lock`) and must never be ignored
- Removed `insert_pattern_in_gitignore_section "conda-lock.yml"` call from micromamba init path in `pyve.sh`

## [1.6.4] - 2026-03-14

### Fixed
- **Critical:** Fixed `pyve --init --force` to show interactive backend prompt in ambiguous cases
- Removed backend preservation logic from `--force` that was preventing the interactive prompt
- Fixed `log_info` output in `get_backend_priority()` to go to stderr instead of stdout
- Fixed micromamba initialization missing pip dependency installation prompt
- This ensures the interactive prompts added in v1.6.2 actually work during `--force` re-initialization

### Technical Details
- Removed backend preservation logic from `--force` in `pyve.sh` (lines 479-482)
- Redirected all `log_info` and `printf` calls to stderr in `get_backend_priority()` (lib/backend_detect.sh)
- Added missing `prompt_install_pip_dependencies()` call to micromamba initialization path
- Updated `prompt_install_pip_dependencies()` to use `micromamba run -p <env_path> pip` for micromamba environments
- Added regression test `test_force_ambiguous_prompt.py` to verify prompt behavior
- Updated `test_force_backend_detection.py` to test new interactive behavior

## [1.6.3] - 2026-03-14 [DEFECTIVE - Fixed in 1.6.4]

### Attempted Fix (Defective)
- Attempted to fix `pyve --init --force` backend detection in ambiguous cases
- Implementation preserved backend in ambiguous cases, which prevented the interactive prompt from working
- See v1.6.4 for the actual fix

### Fixed
- Fixed critical bug in v1.6.2 where `pyve --init --force` unconditionally preserved the existing backend instead of only preserving it in ambiguous cases
- `--force` now correctly re-detects backend from project files when unambiguous (e.g., only `environment.yml` present)
- Backend preservation now only applies when both conda files AND Python files exist (ambiguous detection scenario)
- This ensures `--force` respects `environment.yml` and switches to micromamba when appropriate

## [1.6.2] - 2026-03-14

### Added
- Interactive prompt when both `environment.yml` and `pyproject.toml` exist, asking user to choose backend (defaults to micromamba)
- Interactive prompt to install pip dependencies from `pyproject.toml` or `requirements.txt` after environment creation
- New flags: `--auto-install-deps` (auto-install dependencies without prompting) and `--no-install-deps` (skip dependency installation)
- Enhanced `.gitignore` template with additional Python patterns: `*.pyc`, `*.pyo`, `*.pyd`, `dist/`, `build/`, `*.egg`
- Added Jupyter notebook patterns to `.gitignore`: `.ipynb_checkpoints/`, `*.ipynb_checkpoints`
- Micromamba-specific `.gitignore` pattern: `conda-lock.yml` (added only for micromamba projects)

### Changed
- Ambiguous backend detection now prompts interactively in non-CI mode instead of silently defaulting to venv
- In CI mode or with `CI` environment variable set, ambiguous cases default to micromamba without prompting
- Environment variables: Added `PYVE_AUTO_INSTALL_DEPS`, `PYVE_NO_INSTALL_DEPS`, `PYVE_FORCE_YES`

## [1.6.1] - 2026-03-09

### Added
- `SECURITY.md` with vulnerability reporting policy and security best practices
- `.github/FUNDING.yml` template for GitHub Sponsors (commented out by default)

### Changed
- **Production Mode Migration**: Pyve now uses branch protection and PR-based workflow
- All future changes require pull requests and CI checks before merging to main
- Adopted production-grade development practices per `docs/guides/best-practices-guide.md`

## [1.6.0] - 2026-03-09

### Changed
- Pyve now automatically upgrades pip to the latest version during `pyve --init` and `pyve --init --update`
- Applies to both venv and micromamba backends
- Ensures users have the latest pip security fixes, features, and dependency resolution improvements
- Aligns with Python best practices for virtual environment setup

## [1.5.4] - 2026-02-25

### Fixed
- Fixed `test_purge_with_keep_testenv` integration test calling non-existent `run_raw()` method
- Test now correctly uses `pyve.run()` method from PyveRunner API

## [1.5.3] - 2026-02-25

### Fixed
- Fixed `pyve --purge` failing to remove micromamba environments with "Directory not empty" errors
- `purge_pyve_dir()` now properly removes micromamba environments using `micromamba env remove` before attempting directory deletion
- Handles both named environments and prefix-based removal for robustness

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
