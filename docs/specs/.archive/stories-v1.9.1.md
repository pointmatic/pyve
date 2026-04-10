# stories.md — Pyve (Bash)

This document contains the implementation plan for remaining Pyve work. Stories are organized by phase and reference modules defined in `tech_spec.md`. Current version is v1.9.1.

Story IDs follow the pattern `<Phase>.<letter>` (e.g., A.a, A.b). Each story that produces code changes includes a version number, bumped per story. Stories with no code changes omit the version. Stories are marked `[Planned]` initially and `[Done]` when completed.

---

## Phase A: Bug Fixes, Validate Command & Coverage

Fix CI failures, activate the `--validate` integration tests, and increase code coverage toward the 80% target.

### Story A.a: v1.1.4 Fix .gitignore Idempotency on CI [Done]

Fix `test_gitignore_idempotent` failure on GitHub Actions. Dynamically inserted Pyve-managed patterns (`.envrc`, `.env`, `.pyve/testenv`, `.pyve/envs`, `.venv`) were not in the deduplication set, causing them to leak into the user-entries section on subsequent inits.

- [x] Add dynamic Pyve-managed patterns to `template_lines` dedup array in `write_gitignore_template()` (`lib/utils.sh`)
- [x] Verify: `bats tests/unit/test_utils.bats` — 56 tests pass
- [x] Verify: `pytest tests/integration/test_venv_workflow.py::TestGitignoreManagement::test_gitignore_idempotent -v` passes
- [x] Bump VERSION to 1.1.4

### Story A.b: v1.2.0 Activate Validate Integration Tests [Done]

Remove stale skip decorators from `test_validate.py` and reconcile test expectations with actual `--validate` output.

- [x] Read `lib/version.sh` `run_full_validation()` output format and exit codes
- [x] Fix exit code severity bug in `run_full_validation()` — warnings (exit 2) were overwriting errors (exit 1); added `_escalate()` helper
- [x] Add `init_venv()` and `init_micromamba()` helper methods to `ProjectBuilder` in `tests/helpers/pyve_test_helpers.py`
- [x] Remove `@pytest.mark.skip` from `TestValidateCommand` class
- [x] Fix all test assertions to match actual `--validate` output (exit codes, output strings, config manipulation via `re.sub`)
- [x] Verify: `pytest tests/integration/test_validate.py::TestValidateCommand -v` — 14 passed, 1 skipped (micromamba)
- [x] Bump VERSION to 1.2.0

### Story A.c: v1.2.1 Descriptions, Marketing Page & README Sync [Done]

Create `docs/specs/descriptions.md` as the canonical source of truth for all project descriptions. Build a marketing landing page and distribute descriptions to all consumer files.

- [x] Fill in `descriptions.md` — One-liner, Friendly Brief, Two-clause Technical, Benefits, Technical Description, Keywords, Feature Cards
- [x] Create `docs/index.html` marketing page using banner image and descriptions from `descriptions.md`
- [x] Distribute descriptions to `README.md` (lines 7, 11, 13–19) and `docs/specs/features.md` (line 1)
- [x] Update Usage Notes table in `descriptions.md` with actual line numbers
- [x] Bump VERSION to 1.2.1

### Story A.d: v1.2.2 Activate Validate Edge Case & Platform Tests [Done]

Activate the remaining validate test classes.

- [x] Remove `@pytest.mark.skip` from `TestValidateEdgeCases` — fix assertions for corrupted/empty config (`not configured`), custom venv dir (exit 2 due to version warning), multiple issues (✗/⚠ count)
- [x] Remove `@pytest.mark.skip` from `TestValidateWithDoctor` — fix version manipulation to use `re.sub`, check `result.stderr` for version warning
- [x] Remove `@pytest.mark.skip` from `TestValidateMacOS` and `TestValidateLinux` — use `pyve.init()` instead of `project_builder.init_venv()`, add `check=False`
- [x] Run tests, fix assertion mismatches
- [x] Verify: `pytest tests/integration/test_validate.py -v` — 21 passed, 2 skipped (micromamba, pyenv on macOS)
- [x] Bump VERSION to 1.2.2

### Story A.e: v1.2.3 Increase Unit Test Coverage for version.sh [Done]

Add Bats unit tests for `lib/version.sh` functions not currently covered.

- [x] Add tests for `compare_versions()` — zero components, single-component versions, single vs triple component equal
- [x] Add tests for `validate_installation_structure()` — valid venv project (happy path), valid venv missing `.env` (warning path)
- [x] Add tests for `update_config_version()` — fails if config has no backend (corrupted config)
- [x] Add tests for `write_config_with_version()` — replaces existing version line, preserves backend
- [x] Verify: `bats tests/unit/test_version.bats` — 36 tests, 0 failures (up from 29)
- [x] Bump VERSION to 1.2.3

### Story A.f: v1.2.4 Coverage Audit and Gap Fill [Done]

Run coverage audit, identify remaining low-coverage functions, and add targeted tests.

- [x] Audit: `pytest-cov` reports "No data collected" because Pyve is Bash (subprocess invocations); switched to function-level audit
- [x] Identify gaps: `read_config_value` edge cases, `pyve_is_distutils_shim_disabled`, `pyve_get_python_major_minor`, `run_full_validation` (unit-level)
- [x] Add `read_config_value` edge case tests in `test_utils.bats` — missing config, missing key, nested key, missing section, quoted value (6 tests)
- [x] Add `pyve_is_distutils_shim_disabled` tests in `test_distutils_shim.bats` — not set, set to 1, set to 0 (3 tests)
- [x] Add `pyve_get_python_major_minor` tests in `test_distutils_shim.bats` — fake python, invalid path (2 tests)
- [x] Add `run_full_validation` unit tests in `test_version.bats` — all-pass, missing venv, warnings-only, escalation, missing backend (5 tests)
- [x] Verify: `bats tests/unit/` — 257 tests, 0 failures
- [x] Bump VERSION to 1.2.4

### Story A.g: v1.2.5 Coverage Target 80% [Done]

Push coverage toward the 80% target with targeted unit and integration tests.

- [x] Add unit tests for `lib/distutils_shim.sh` — `pyve_python_is_312_plus` (6 tests: 3.14, 3.12, 3.11, 4.0, 2.7, invalid), `pyve_write_sitecustomize_shim` update and create paths (2 tests)
- [x] Add integration tests for `pyve doctor` edge cases — missing `.pyve` dir, empty config, output header (3 tests)
- [x] Add integration test for `pyve run` with no command argument (1 test)
- [x] Verify: `bats tests/unit/` — 265 tests, 0 failures (up from 257)
- [x] Verify: `pytest tests/integration/ --collect-only` — 186 tests (up from 182)
- [x] Total: 451 tests across unit + integration suites
- [x] Bump VERSION to 1.2.5

---

## Phase B: Documentation & Cleanup

### Story B.a: v1.3.0 Integrate Bash Coverage via kcov [Done]

Replace the misleading Python-only Codecov badge with real Bash line coverage using `kcov`.

- [x] Install `kcov` in CI (`sudo apt-get install kcov` on Ubuntu in `bash-coverage` job)
- [x] Run Bats unit tests under kcov: `kcov --include-path=lib/,pyve.sh --bash-dont-parse-binary-dir coverage-kcov bats tests/unit/*.bats`
- [x] Run integration tests under kcov: `tests/helpers/kcov-wrapper.sh` wraps `pyve.sh`; `PyveRunner` uses wrapper when `PYVE_KCOV_OUTDIR` is set
- [x] Merge kcov output into single Codecov upload (kcov auto-merges into `kcov-merged/cobertura.xml`)
- [x] Configure `codecov.yml` flags: `bash` flag with `paths: [lib/, pyve.sh]` and `carryforward: true`
- [x] Remove or update `[coverage:run] source = .` in `pytest.ini` — changed to `source = tests/integration`, omit helpers/unit/fixtures
- [x] Document the coverage setup in `testing_spec.md` (new "Bash Coverage (kcov)" section)
- [x] Add `coverage-kcov` Makefile target for local usage
- [x] Bump VERSION to 1.3.0

### Story B.b: v1.3.1 Update testing_spec.md, site structure, and other docs [Done]

Reconcile `testing_spec.md` with the actual test suite after Phase A and the kcov integration.

- [x] Update test structure tree to match actual files (10 unit test files, 11 integration test files, kcov-wrapper.sh, sample_configs detail)
- [x] Update coverage goals section — replaced Phase 1/Phase 2 with "Test Coverage Status" showing 451 tests (265 Bats + 186 pytest) with per-file tables
- [x] Remove or update Phase 1/Phase 2 references — replaced with current achieved status
- [x] Update pytest.ini example to match actual markers (added `requires_direnv`, `venv`, `micromamba`, `--maxfail=5`)
- [x] Update CI/CD section — replaced single-job example with 6-job table matching actual `test.yml`
- [x] Update Bats examples to use actual `test_helper` load pattern (`setup_pyve_env`, `create_test_dir`)
- [x] Update pytest examples to match actual `conftest.py` (imports from `pyve_test_helpers.py`) and class-based test style
- [x] Update Makefile section to match actual targets (including `coverage-kcov`)
- [x] Update `docs/guides/codecov-setup-guide.md` — add kcov references to configuration, troubleshooting, coverage reports, local coverage, and references sections
- [x] Restructure `docs/` to separate user-facing site from developer docs:
  - `docs/codecov-setup.md` → `docs/guides/codecov-setup-guide.md`
  - `docs/ci-cd-examples.md` → `docs/site/ci-cd.md`
  - `docs/images/` → `docs/site/images/`
  - `docs/index.html` → `docs/site/index.html`
- [x] Bump VERSION to 1.3.1

---

## Phase C: Homebrew Packaging

### Story C.a: v1.4.0 Homebrew Guards & Release Prep [Done]

Prepare pyve for Homebrew distribution: detect Homebrew-managed installs and create the tap repo.

- [x] Detect Homebrew-managed installs in `pyve --install` / `pyve --uninstall` and warn/skip
- [x] Verify `SCRIPT_DIR` resolution works when executed via Homebrew's `bin/pyve` → `libexec/pyve.sh` wrapper
- [x] Create `pointmatic/homebrew-tap` GitHub repo manually
- [x] Bump VERSION to 1.4.0
- [x] Tag `v1.4.0` and push

### Story C.b: Publish Pyve via Homebrew Tap [Done]

Package Pyve for installation via `brew install pointmatic/tap/pyve`.

- [x] Compute SHA256 of the `v1.4.0` release tarball
- [x] Write `Formula/pyve.rb` — install `pyve.sh` + `lib/` under `libexec/`, write exec wrapper under `bin/pyve`
- [x] Add `test` block to formula: `assert_match "pyve version", shell_output("#{bin}/pyve --version")`
- [x] Run `brew install --build-from-source pointmatic/tap/pyve` and verify `pyve --init`, `pyve doctor`, `pyve run` work
- [x] Push formula to `pointmatic/homebrew-tap` and verify `brew install pointmatic/tap/pyve` works from scratch
- [x] Document Homebrew installation in `README.md` — added Homebrew as primary install method, updated Quick Start, Installation, and Uninstallation sections

### Story C.c: v1.4.1 Homebrew Guard Fix & README Update [Done]

Fix Homebrew detection guard to use `SCRIPT_DIR` instead of `command -v`, update README for Homebrew, and push updated formula.

- [x] Fix `install_self()` / `uninstall_self()` guards — use `SCRIPT_DIR` (running script location) instead of `command -v pyve` (which may find a different copy on PATH)
- [x] Update `README.md` — Homebrew as primary install method, updated Quick Start, Installation, Uninstallation sections, fixed image path for `docs/site/` migration
- [x] Bump VERSION to 1.4.1
- [x] Update `Formula/pyve.rb` SHA256 for new tarball

### Story C.d: Automate Homebrew Formula Updates on Tag Push [Done]

Add a GitHub Actions workflow to `pointmatic/pyve` that automatically updates the formula in `pointmatic/homebrew-tap` when a new version tag is pushed.

- [x] Create `HOMEBREW_TAP_TOKEN` — GitHub Personal Access Token with repo access to `pointmatic/homebrew-tap`, stored as a secret in `pointmatic/pyve`
- [x] Add `.github/workflows/update-homebrew.yml` — triggers on `v*` tag push, uses `dawidd6/action-homebrew-bump-formula` to update `Formula/pyve.rb`
- [x] Test by pushing a tag and verifying the formula is auto-updated in `pointmatic/homebrew-tap` — workflow creates a PR that must be manually merged

### Story C.e: v1.5.0 Show Install Source in `pyve doctor` [Done]

Add installation source diagnostic to `pyve doctor` output.

- [x] Detect install source in `doctor_command()`: Homebrew (`SCRIPT_DIR` under `brew --prefix`), installed (`SCRIPT_DIR` == `~/.local/bin`), or source (git clone)
- [x] Display as first line of doctor output: `✓ Pyve: v1.x.x (homebrew|installed|source: <path>)`
- [x] Add tests for the three install source detection paths — 5 Bats tests in `tests/unit/test_doctor.bats`
- [x] Extracted `detect_install_source()` into `lib/utils.sh` for testability
- [x] Bump VERSION to 1.5.0

### Story C.f: v1.5.1 Fix kcov Repository URL in CI [Done]

Fix typo in kcov repository URL that caused bash-coverage CI job to fail.

- [x] Correct kcov repository URL in `.github/workflows/test.yml` — `SimonKagstrom/kcov` not `SimonKagworthy/kcov`
- [x] Bump VERSION to 1.5.1

---

## Phase D: Documentation Site

Publish user-facing documentation at `https://pointmatic.github.io/pyve` via MkDocs on GitHub Pages, served from `docs/site/`.

### Story D.a: Bootstrap MkDocs for docs/site [Done]

Set up MkDocs with Material theme and GitHub Actions deployment to GitHub Pages.

- [x] Add `mkdocs.yml` — Material theme, navigation, markdown extensions, plugins
- [x] Verify existing `index.html` and `ci-cd.md` work with MkDocs
- [x] Add `.github/workflows/deploy-docs.yml` — builds and deploys MkDocs site on push to main
- [x] Add `docs/site/.gitignore` for `/site/` build output
- [x] Add docs links to `index.html` (nav + hero CTA)
- [x] Fix broken link in `ci-cd.md` (changed `../README.md` to GitHub repo link)
- [x] Test local preview: `pip install mkdocs-material mkdocs-git-revision-date-localized-plugin && mkdocs serve`
- [x] Configure GitHub Pages source: Settings → Pages → GitHub Actions
- [x] Verify site builds and serves at `https://pointmatic.github.io/pyve`

### Story D.b: User-Facing Documentation Pages [Done]

Create the core user documentation pages for the published site.

- [x] Create `docs/site/getting-started.md` — installation (Homebrew + git clone), quick start, first project setup
- [x] Create `docs/site/usage.md` — full command reference (`--init`, `--purge`, `doctor`, `run`, `--validate`, `--config`, `test`), flags, examples
- [x] Create `docs/site/backends.md` — venv vs micromamba comparison, auto-detection rules, when to use which
- [x] Review `docs/site/ci-cd.md` for user-facing tone (already exists, content is appropriate)
- [x] Update `mkdocs.yml` nav section with all documentation pages
- [x] Update `index.html` with links to new documentation pages (nav + hero CTA point to getting-started)
- [x] Test local preview: `mkdocs serve` and verify all pages render correctly
- [x] Push and verify all pages render correctly on GitHub Pages

### Story D.c: v1.5.2 CHANGELOG.md and License Header Compliance [Done]

Create CHANGELOG.md and add Apache-2.0 license headers to all Python test files to comply with project guide requirements.

- [x] Create `CHANGELOG.md` in repository root following Keep a Changelog format
  - [x] Document all versions from v1.1.4 through v1.5.1 based on `stories.md`
  - [x] Include v1.0.0 initial release summary
  - [x] Add version comparison links at bottom
- [x] Add Apache-2.0 license headers to all 12 Python test files
  - [x] `tests/helpers/pyve_test_helpers.py`
  - [x] `tests/integration/conftest.py`
  - [x] `tests/integration/test_auto_detection.py`
  - [x] `tests/integration/test_bootstrap.py`
  - [x] `tests/integration/test_cross_platform.py`
  - [x] `tests/integration/test_doctor.py`
  - [x] `tests/integration/test_micromamba_workflow.py`
  - [x] `tests/integration/test_reinit.py`
  - [x] `tests/integration/test_run_command.py`
  - [x] `tests/integration/test_testenv.py`
  - [x] `tests/integration/test_validate.py`
  - [x] `tests/integration/test_venv_workflow.py`
- [x] Verify all headers follow Apache-2.0 format with copyright notice
- [x] Update README.md version references from v0.9.3, v0.8.8, v0.8.7, v0.8.9 to v1.5.2
- [x] Bump VERSION to 1.5.2

Phase E: Bug Fixes and Minor Improvements

### Story E.a: v1.5.3 Fix Pyve micromamba purge ordering [Done]

Fix bug where `pyve --purge` fails to remove micromamba environments due to incorrect purge order. The current implementation uses `rm -rf .pyve` which fails when micromamba environments contain files with special permissions. The fix should properly remove micromamba environments before attempting directory deletion.

- [x] Update `purge_pyve_dir()` function in `pyve.sh`
  - [x] Detect if micromamba backend is in use (check for `.pyve/envs` directory)
  - [x] Read environment name from `.pyve/config` if it exists
  - [x] If micromamba environment exists, run `micromamba env remove -p .pyve/envs/<env_name> -y` first
  - [x] Handle case where micromamba binary is not found (skip env remove, proceed with directory removal)
  - [x] Then remove `.pyve` directory with `rm -rf`
  - [x] Add error handling for failed micromamba env remove (log warning, continue with rm -rf)
- [x] Add integration test for micromamba purge
  - [x] Test `pyve --init --backend micromamba` followed by `pyve --purge`
  - [x] Verify `.pyve` directory is completely removed
  - [x] Verify no "Directory not empty" errors occur
- [x] Test purge with `--keep-testenv` flag
  - [x] Verify micromamba env is removed but testenv is preserved
- [x] Update CHANGELOG.md with v1.5.3 entry
  - [x] Add "Fixed" section describing micromamba purge bug fix
- [x] Bump VERSION to 1.5.3

### Story E.b: v1.5.4 Fix test_purge_with_keep_testenv test failure [Done]

Fix integration test failure in `test_purge_with_keep_testenv` which was calling non-existent `run_raw()` method on `PyveRunner` class.

- [x] Fix `test_purge_with_keep_testenv` in `test_micromamba_workflow.py`
  - [x] Replace `pyve.run_raw()` calls with `pyve.run()`
  - [x] Verify test uses correct PyveRunner API
- [x] Update CHANGELOG.md with v1.5.4 entry
  - [x] Add "Fixed" section describing test fix
- [x] Bump VERSION to 1.5.4
- [ ] Verify: Run `pyve --init --backend micromamba --force` twice to confirm purge works correctly

### Story E.c: v1.6.0 Auto-upgrade pip during environment initialization [Done]

Automatically upgrade pip to the latest version during `pyve --init` and `pyve --update` to ensure users have the latest security fixes, features, and dependency resolution improvements.

- [x] Update `pyve_ensure_venv_packaging_prereqs()` in `lib/distutils_shim.sh`
  - [x] Change `pip install -U setuptools wheel` to `pip install -U pip setuptools wheel`
  - [x] Ensure pip is upgraded before setuptools and wheel
- [x] Update `pyve_ensure_micromamba_packaging_prereqs()` in `lib/distutils_shim.sh`
  - [x] Verify micromamba environments also get latest pip
  - [x] Add pip to the install command if not already present
- [x] Add integration tests for pip upgrade behavior
  - [x] Test that `pyve --init` results in latest pip version
  - [x] Test that `pyve --init --update` upgrades pip
  - [x] Test both venv and micromamba backends
- [x] Update documentation
  - [x] Add note to README.md about automatic pip upgrades
  - [x] Document in `docs/site/usage.md` or `docs/site/getting-started.md`
- [x] Update CHANGELOG.md with v1.6.0 entry
  - [x] Add "Changed" section describing automatic pip upgrade
  - [x] Note this aligns with Python best practices
- [x] Bump VERSION to 1.6.0

### Story E.d: v1.6.1 Production Mode Migration [Done]

Migrate Pyve from velocity mode to production mode with branch protection, security policies, and PR-based workflow as prescribed in `docs/guides/best-practices-guide.md`.

**Automated Tasks:**
- [x] Create `SECURITY.md` with vulnerability reporting policy
- [x] Create `.github/FUNDING.yml` for GitHub Sponsors (optional)
- [x] Update CHANGELOG.md with v1.6.1 entry
- [x] Bump VERSION to 1.6.1

**Manual Tasks (GitHub Web UI):**
- [ ] Enable branch protection on `main` branch
  - [ ] Require pull request before merging
  - [ ] Require 1 approval
  - [ ] Require status checks: `unit-tests`, `integration-tests`
  - [ ] Require branches to be up to date
  - [ ] Do not allow bypassing settings
- [ ] Enable Dependabot
  - [ ] Dependabot alerts
  - [ ] Dependabot security updates
- [ ] Verify GitHub Actions permissions are correct

**Workflow Transition:**
- [ ] Commit Story E.d changes to main (final direct commit)
- [ ] Enable branch protection immediately after
- [ ] All future work uses PR workflow per `docs/guides/developer/production-mode.md`

### Story E.e: v1.6.2 Interactive Prompts for Ambiguous Backend and Dependency Installation [Done]

Enhance user experience when both `environment.yml` and `pyproject.toml` exist by prompting for backend choice (preferring micromamba) and optionally installing pip dependencies after environment creation.

**Motivation:**
- Current behavior silently defaults to venv when both files exist, which is unintuitive
- `environment.yml` presence is a strong signal that user wants micromamba
- After micromamba init, users often need to install pip dependencies from `pyproject.toml` or `requirements.txt`
- Interactive prompts provide transparency and control while maintaining good defaults

**Implementation:**

**Part 1: Interactive Backend Selection**
- [x] Update `get_backend_priority()` in `lib/backend_detect.sh`
  - [x] When `detected_backend == "ambiguous"`, check if interactive mode
  - [x] In interactive mode: prompt "Initialize with micromamba backend? [Y/n]:"
  - [x] Default to micromamba (Y) if user presses Enter
  - [x] Use venv if user types 'n' or 'N'
  - [x] In CI/non-interactive mode: default to micromamba (no prompt)
  - [x] Respect `PYVE_FORCE_YES` environment variable to skip prompt
- [x] Update warning messages to be more informative about the choice

**Part 2: Interactive Dependency Installation**
- [x] Add `prompt_install_pip_dependencies()` function in `lib/utils.sh`
  - [x] Detect if `pyproject.toml` or `requirements.txt` exists
  - [x] Prompt: "Install pip dependencies from [file]? [Y/n]:"
  - [x] If `pyproject.toml`: run `pip install -e .` (editable install)
  - [x] If `requirements.txt`: run `pip install -r requirements.txt`
  - [x] If both exist: prompt for each separately
  - [x] Skip in CI/non-interactive mode unless `--auto-install-deps` flag set
- [x] Call `prompt_install_pip_dependencies()` after successful environment creation in `init()`
- [x] Add command-line flags:
  - [x] `--auto-install-deps` - Auto-install dependencies without prompting
  - [x] `--no-install-deps` - Skip dependency installation prompt

**Part 3: Enhanced .gitignore Template**
- [x] Update `write_gitignore_template()` in `lib/utils.sh` to include additional Python patterns
  - [x] Add `*.pyc`, `*.pyo`, `*.pyd` - Compiled Python bytecode files
  - [x] Add `dist/`, `build/`, `*.egg` - Python packaging artifacts
  - [x] Add `.ipynb_checkpoints/`, `*.ipynb_checkpoints` - Jupyter notebook checkpoints
- [x] Add micromamba-specific patterns when backend is micromamba
  - [x] Add `conda-lock.yml` to .gitignore for micromamba projects
  - [x] Conditionally insert after environment initialization based on backend

**Testing:**
- [x] Update unit tests in `tests/unit/test_backend_detect.bats`
  - [x] Updated ambiguous detection test to expect micromamba in CI mode
  - [x] Test CI mode defaults to micromamba
  - [x] Test `PYVE_FORCE_YES` skips prompt (covered by CI mode)
- [x] Update test helpers in `tests/helpers/pyve_test_helpers.py`
  - [x] Set `PYVE_NO_INSTALL_DEPS=1` by default in test environment
  - [x] Tests can override to test dependency installation feature
- [x] Verify: All existing tests still pass with no regressions
  - [x] `pytest tests/integration/test_force_backend_detection.py -v` — 2 passed, 3 skipped
  - [x] `pytest tests/integration/test_reinit.py -v` — 20 passed, 1 skipped
  - [x] `bats tests/unit/test_backend_detect.bats` — 23 tests pass
  - [x] `bats tests/unit/test_utils.bats` — 63 tests pass (including .gitignore template tests)

**Documentation:**
- [x] Update `docs/site/usage.md` with new interactive prompt behavior
- [x] Update `docs/site/backends.md` to explain ambiguous case handling
- [x] Add examples showing the interactive flow
- [x] Document new flags: `--auto-install-deps`, `--no-install-deps`

**Verification:**
- [x] Manual test: Create project with both `environment.yml` and `pyproject.toml`
- [x] Run `pyve --init` and verify prompts appear
- [x] Test all prompt responses (y, n, Enter)
- [x] Verify dependencies install correctly when accepted
- [x] Test in CI mode (no prompts, uses defaults)
- [x] Verify: `pytest tests/integration/ -v` — all tests pass
- [x] Verify: `bats tests/unit/ -v` — all tests pass

### Story E.f: v1.6.3 Attempt to Fix --force Backend Preservation (Defective) [Deployed]

**Note:** This implementation was defective and deployed in v1.6.3. See Story E.g for the actual fix in v1.6.4.

Attempted to fix bug where `pyve --init --force` would default to venv in ambiguous cases. Implementation added conditional backend preservation logic, but this prevented the interactive prompt from appearing.

**Defective Implementation:**
- [x] Added logic to check if both conda and Python files exist
- [x] Preserved `existing_backend` only in ambiguous cases
- [x] This still prevented the interactive prompt from working (see Story E.g for why)

### Story E.g: v1.6.4 Fix --force Interactive Prompt in Ambiguous Cases [Done]

Fix critical bug in v1.6.3 where `pyve --init --force` with ambiguous files (both `environment.yml` and `pyproject.toml`) would use venv without prompting, instead of showing the interactive backend selection prompt added in Story E.e.

**Root Cause:**
- Story E.f (v1.6.3) added backend preservation logic to `--force` that set `backend_flag="$existing_backend"` in ambiguous cases
- This preserved backend was passed to `get_backend_priority()` as a CLI flag
- CLI flags have Priority 1 and bypass all detection and prompting logic
- Additionally, `log_info` calls in `get_backend_priority()` were outputting to stdout instead of stderr
- Command substitution `backend="$(get_backend_priority ...)"` captured log messages in the `$backend` variable
- Result: Interactive prompt never appeared, and wrong backend was used

**Implementation:**
- [x] Remove backend preservation logic from `--force` in `pyve.sh` (line 479-482)
  - [x] Let `--force` fall through to normal detection (empty `backend_flag`)
  - [x] This allows the interactive prompt to appear in ambiguous cases
- [x] Fix `get_backend_priority()` in `lib/backend_detect.sh` (lines 89-117)
  - [x] Redirect all `log_info` calls to stderr with `>&2`
  - [x] Redirect `printf` prompt to stderr with `>&2`
  - [x] Ensures only the backend choice goes to stdout for command substitution
- [x] Fix micromamba initialization in `pyve.sh` (line 677)
  - [x] Add missing `prompt_install_pip_dependencies()` call
  - [x] Micromamba path was missing the pip dependency installation prompt that venv had
- [x] Fix `prompt_install_pip_dependencies()` in `lib/utils.sh` to support micromamba
  - [x] Add backend and env_path parameters
  - [x] Use `micromamba run -p <env_path> pip` for micromamba environments
  - [x] Use regular `pip` for venv environments
  - [x] Prevents using host system's pip instead of environment's pip
- [x] Add regression test `test_force_ambiguous_prompt.py`
  - [x] `test_force_prompts_for_backend_in_ambiguous_case` — verifies prompt appears and choice is respected
  - [x] `test_force_respects_no_response_in_ambiguous_case` — verifies 'n' response uses venv
- [x] Update existing test `test_force_backend_detection.py`
  - [x] Renamed `test_force_reinit_preserves_venv_in_ambiguous_case` to match new behavior
  - [x] Now tests that prompt appears and user can choose venv with 'n' response
- [x] Verify: `pytest tests/integration/test_force_ambiguous_prompt.py -v` — 2 passed
- [x] Verify: `pytest tests/integration/test_force_backend_detection.py -v` — 2 passed, 3 skipped
- [x] Verify: `pytest tests/integration/test_reinit.py -v` — 20 passed, 1 skipped
- [x] Verify: `bats tests/unit/test_backend_detect.bats` — 23 tests pass
- [x] Bump VERSION to 1.6.4

### Story E.h: v1.6.4 Documentation - Interactive Prompts [Done]

Document the interactive prompt features added in v1.6.2 and fixed in v1.6.4 across all user-facing documentation. The MkDocs site (`docs/site/backends.md`) already has excellent coverage, but other docs need updates.

**Scope:**
Two interactive prompts need documentation:
1. **Backend selection prompt** - When both `environment.yml` and `pyproject.toml` exist (ambiguous case)
2. **Pip dependency installation prompt** - After environment creation, prompts to install from `pyproject.toml` or `requirements.txt`

**Documentation Assessment:**
- ✓ **Excellent:** `docs/site/backends.md` - Comprehensive coverage of both prompts with examples and troubleshooting
- ✓ **Good:** `docs/site/usage.md` - Documents both prompts in command reference
- ⚠ **Partial:** `README.md` - Covers `--force` but missing interactive prompt details
- ❌ **Missing:** `docs/site/getting-started.md` - No mention of interactive prompts (entry point for new users)
- ❌ **Missing:** `docs/specs/features.md` - FR-1 and FR-8 don't mention interactive prompts
- ❌ **Missing:** `docs/specs/tech-spec.md` - Prompt functions not fully documented

**Implementation:**
- [x] Update `README.md` (lines 176-222: Backend Auto-Detection Priority section)
  - [x] Add "Ambiguous Cases (Interactive Prompt)" subsection after line 204
  - [x] Show backend selection prompt example
  - [x] Explain default behavior (interactive vs CI mode)
  - [x] Add "Pip Dependency Installation" section after line 255
  - [x] Show pip dependency prompt example
  - [x] Document `--auto-install-deps` and `--no-install-deps` flags
- [x] Update `docs/site/getting-started.md` (lines 106-124: Quick Start section)
  - [x] Add note about interactive prompts in step 1 "Initialize a New Project"
  - [x] Mention backend selection prompt for ambiguous cases
  - [x] Mention pip dependency installation prompt
  - [x] Add link to `backends.md` for details
- [x] Update `docs/specs/features.md`
  - [x] FR-8 "Backend Auto-Detection" (line 199-203)
    - [x] Add bullet: "Ambiguous cases: When both conda files and Python files exist, prompt user interactively"
    - [x] Note non-interactive behavior with `PYVE_FORCE_YES=1`
  - [x] FR-1 "Environment Initialization" (line 128-139)
    - [x] Add bullet: "Prompt to install pip dependencies from `pyproject.toml` or `requirements.txt`"
    - [x] Note flags: `--auto-install-deps`, `--no-install-deps`
  - [x] Environment Variables section (line 256-260)
    - [x] Add `PYVE_AUTO_INSTALL_DEPS` - Set to `1` to auto-install pip dependencies
    - [x] Add `PYVE_NO_INSTALL_DEPS` - Set to `1` to skip pip dependency installation
    - [x] Add `PYVE_FORCE_YES` - Set to `1` to default to micromamba in ambiguous cases
- [x] Update `docs/specs/tech-spec.md`
  - [x] `lib/utils.sh` function table (line 137-146)
    - [x] Update `prompt_install_pip_dependencies` signature: `(backend?, env_path?)` → 0/1
    - [x] Add description: "Prompt to install pip dependencies; supports both venv and micromamba backends"
  - [x] `lib/backend_detect.sh` function table (line 198-203)
    - [x] Update `get_backend_priority` description to mention interactive prompt in ambiguous cases

**Rationale:**
- `backends.md` already serves as the comprehensive reference - no changes needed
- `getting-started.md` is the entry point for new users - needs at least a mention with link to details
- `README.md` is often the first doc users read - should have clear examples
- `features.md` and `tech-spec.md` are specification docs - need to be accurate and complete

**Verification:**
- [x] Review all updated docs for consistency
- [x] Ensure examples match actual behavior
- [x] Verify cross-references between docs work correctly

---

## Phase F: Micromamba Backend Improvements

Improvements derived from production use of Pyve v1.6.4 with a micromamba backend on Apple Silicon (M3). See `docs/specs/pyve-improvements.md` for full context and root cause analysis.

### Story F.a: v1.7.0 Fix `conda-lock.yml` Incorrectly Added to `.gitignore` [Done]

`conda-lock.yml` is an explicitly committed artifact — ignoring it defeats its purpose. Remove it from the Pyve-managed `.gitignore` template and any conditional insertion logic.

- [x] Remove `conda-lock.yml` from `write_gitignore_template()` in `lib/utils.sh`
  - [x] Audit the full template heredoc and any conditional micromamba-specific insertions
  - [x] Confirm `environment.yml` is also not ignored (it should never have been)
- [x] Remove any call-site logic in `pyve.sh` that appends `conda-lock.yml` after init
- [x] Update unit tests in `tests/unit/test_utils.bats`
  - [x] Add test: `conda-lock.yml` is NOT present in the generated `.gitignore` template
  - [x] Add test: `.pyve/envs/` section header IS present (still correctly ignored)
  - [x] Verify: `bats tests/unit/test_utils.bats` — 65 tests, 0 failures
- [x] Update `docs/specs/features.md` — correct the `.gitignore` policy table in FR-2 to explicitly note `conda-lock.yml` must NOT be ignored
- [x] Update CHANGELOG.md with v1.7.0 entry
- [x] Bump VERSION to 1.7.0

### Story F.b: v1.7.1 Hard Fail When Project Is Inside a Cloud-Synced Directory [Done]

Cloud sync daemons race against micromamba package extraction, causing non-deterministic environment corruption that can damage the Python standard library. `pyve --init` must refuse to proceed in synced directories.

- [x] Add `check_cloud_sync_path()` function to `lib/utils.sh`
  - [x] Primary check: hard fail if `$PWD` is a prefix match of any known synced path:
    - `$HOME/Documents`, `$HOME/Desktop`, `$HOME/Library/Mobile Documents`
    - `$HOME/Dropbox`, `$HOME/Google Drive`, `$HOME/OneDrive`
  - [x] Secondary check: run `xattr -l "$PWD" | grep -i "com.apple.cloud\|com.dropbox\|com.google.drive\|com.microsoft.onedrive"` and fail if matched
  - [x] Both checks apply on macOS; skip `xattr` check on Linux (command unavailable)
  - [x] Print actionable error with detected sync root, explanation, `mv` command suggestion, and `--allow-synced-dir` override
- [x] Add `--allow-synced-dir` flag to CLI in `pyve.sh`
  - [x] Parse flag and export `PYVE_ALLOW_SYNCED_DIR=1`
  - [x] Document flag in `--help` output
- [x] Call `check_cloud_sync_path()` at the start of `init()` before any environment creation
- [x] Add unit tests in `tests/unit/test_utils.bats`
  - [x] Test: path inside `$HOME/Documents` fails
  - [x] Test: path inside `$HOME/Dropbox` fails
  - [x] Test: path inside `$HOME/Developer` passes
  - [x] Test: `PYVE_ALLOW_SYNCED_DIR=1` bypasses the check
  - [x] Verify: `bats tests/unit/test_utils.bats` — 70 tests, 0 failures
- [x] Update `docs/specs/features.md` — add FR-14: Cloud-Synced Directory Detection
- [x] Update `docs/site/usage.md` — document `--allow-synced-dir` flag and explain the risk
- [x] Update CHANGELOG.md with v1.7.1 entry
- [x] Bump VERSION to 1.7.1

### Story F.c: v1.7.2 Auto-Generate `.vscode/settings.json` for Micromamba Backend [Done]

When Pyve initializes a micromamba environment, generate `.vscode/settings.json` so VS Code-compatible IDEs (Windsurf, Cursor) use the correct interpreter and don't interfere with Pyve's environment management.

- [x] Add `write_vscode_settings()` function to `lib/utils.sh`
  - [x] Receive `env_name` as parameter; construct interpreter path `.pyve/envs/<env_name>/bin/python`
  - [x] Create `.vscode/` directory if it does not exist
  - [x] Write `.vscode/settings.json` with `python.defaultInterpreterPath`, `python.terminal.activateEnvironment: false`, `python.condaPath: ""`
  - [x] Do not overwrite if already exists (log info and skip); allow override when `PYVE_REINIT_MODE=force`
- [x] Call `write_vscode_settings()` in micromamba init path in `pyve.sh`, after `.pyve/config` is created
- [x] Add `.vscode/settings.json` as dynamic pattern in `write_gitignore_template()` for deduplication
- [x] Add `insert_pattern_in_gitignore_section ".vscode/settings.json"` in micromamba init path
- [x] Add unit tests in `tests/unit/test_utils.bats`
  - [x] Test: `write_vscode_settings()` creates correct JSON with env name substituted
  - [x] Test: existing `.vscode/settings.json` is not overwritten without `--force`
  - [x] Test: `PYVE_REINIT_MODE=force` triggers overwrite
  - [x] Test: `.vscode/settings.json` not duplicated in `.gitignore` on reinit
  - [x] Verify: `bats tests/unit/test_utils.bats` — 74 tests, 0 failures
- [x] Update `docs/specs/features.md` — FR-1 and micromamba outputs table
- [x] Update `docs/site/backends.md` — add "IDE Integration" section
- [x] Update CHANGELOG.md with v1.7.2 entry
- [x] Bump VERSION to 1.7.2

### Story F.d: v1.7.3 `pyve doctor` Detects Duplicate dist-info and iCloud Collision Artifacts [Done]

iCloud Drive and other sync daemons racing against micromamba extraction produce duplicate `dist-info` directories and files/directories with ` 2` suffix — symptoms that are hard to diagnose without tooling.

- [x] Add `doctor_check_duplicate_dist_info()` function to `lib/utils.sh`
  - [x] Locate `site-packages` via `find "$env_path/lib" -name "site-packages"`
  - [x] Extract package names by stripping `-<version>.dist-info`; use `sort | uniq -d` to find duplicates
  - [x] For each duplicate: print `✗ Duplicate dist-info detected: <package>` with both dirs and mtimes
  - [x] Append: `Run 'pyve --init --force' to rebuild the environment cleanly.`
  - [x] If no duplicates: print `✓ No duplicate dist-info directories`
- [x] Add `doctor_check_collision_artifacts()` function to `lib/utils.sh`
  - [x] Scan environment tree for files/directories whose names end with ` 2` (space-two)
  - [x] Report count and up to 5 paths; show `... and N more` if truncated
  - [x] If none: print `✓ No cloud sync collision artifacts`
- [x] Integrate both checks into `doctor_command()` in `pyve.sh`
  - [x] Called inside the micromamba section after the package count check
- [x] Add unit tests in `tests/unit/test_doctor.bats`
  - [x] Test: duplicate dist-info dirs detected with correct package name and versions
  - [x] Test: clean environment passes (✓) for duplicate check
  - [x] Test: missing site-packages passes (✓)
  - [x] Test: ` 2`-suffixed dirs detected and reported
  - [x] Test: nested collision artifacts counted correctly
  - [x] Test: missing env path returns cleanly
  - [x] Verify: `bats tests/unit/test_doctor.bats` — 12 tests, 0 failures
- [x] Update CHANGELOG.md with v1.7.3 entry
- [x] Bump VERSION to 1.7.3

### Story F.e: v1.8.0 Enforce `conda-lock.yml` Presence Before `pyve --init` [Done]

Promote the missing `conda-lock.yml` condition from a dismissible warning to a blocking error. A bypass flag (`--no-lock`) makes intentional overrides explicit.

- [x] Update `validate_lock_file_status()` in `lib/micromamba_env.sh` — Case 2 (only `environment.yml`, no lock file)
  - [x] Remove interactive prompt and CI auto-continue; replace with hard error unconditionally
  - [x] Print structured error: `ERROR: No conda-lock.yml found.` + `conda-lock` command + `--no-lock` override
  - [x] When `PYVE_NO_LOCK=1`: log warning and return 0 (bypass)
  - [x] Stale lock file behavior (Case 1) is unchanged: warns, prompts, errors only in `--strict`
- [x] Add `--no-lock` flag to `pyve.sh`
  - [x] Parse flag and export `PYVE_NO_LOCK=1`
  - [x] Document in `--help` output and USAGE line
- [x] Update unit tests in `tests/unit/test_lock_validation.bats`
  - [x] Updated 3 tests whose expected status changed from 0 → 1 (missing lock is now an error)
  - [x] Added test: `PYVE_NO_LOCK=1` bypasses missing lock file error
  - [x] Added test: `PYVE_NO_LOCK=1` does not bypass missing `environment.yml`
  - [x] Added test: stale lock still warns and continues in non-strict non-interactive mode
  - [x] Verify: `bats tests/unit/test_lock_validation.bats` — 27 tests, 0 failures
- [x] Update `docs/specs/features.md` — Quality Requirements lock file entry updated
- [x] Update CHANGELOG.md with v1.8.0 entry
- [x] Bump VERSION to 1.8.0

### Story F.f: v1.8.1 `pyve doctor` Detects conda/pip Native Library Conflicts [Done]

Mixed conda-forge and pip installs can produce silent runtime failures when pip-bundled native libraries (torch, tensorflow) conflict with conda-linked ones (numpy, scipy). Surface these conflicts proactively.

- [x] Add `doctor_check_native_lib_conflicts()` function
  - [x] Detect pip-installed packages that bundle native libraries — check for known packages: `torch`, `tensorflow`, `tensorflow-macos`, `jax`, `jaxlib`
    - [x] Parse dist-info directories directly (no network): glob `<env>/lib/python*/site-packages/<pkg>-*.dist-info`
  - [x] Detect conda-installed packages that link against shared native libraries — check for known packages: `numpy`, `scipy`, `scikit-learn`, `pandas` via `conda-meta/<pkg>-*.json`
  - [x] For each known conflict pair (e.g., torch + numpy), check whether the required shared library (`libomp.dylib` on macOS, `libgomp.so` on Linux) is present in `<env>/lib/`
  - [x] If library is absent: print `⚠ Potential native library conflict detected` with package names and fix instruction (add `llvm-openmp` or `libgomp` to `environment.yml`)
  - [x] If no conflicts: print `✓ No conda/pip native library conflicts detected`
- [x] Integrate into `doctor_command()` in `pyve.sh`
  - [x] Only run when backend is `micromamba` and environment exists
  - [x] macOS checks `libomp.dylib`, Linux checks `libgomp.so`
- [x] Add unit tests in `tests/unit/test_doctor.bats`
  - [x] Test: no conflict when no pip bundlers present
  - [x] Test: no conflict when no conda linkers present
  - [x] Test: conflict detected when pip+conda present and OpenMP lib absent
  - [x] Test: no conflict when OpenMP lib is present
  - [x] Test: missing env path returns cleanly
  - [x] Verify: `bats tests/unit/test_doctor.bats` — 17 tests, 0 failures
- [x] Update CHANGELOG.md with v1.8.1 entry
- [x] Bump VERSION to 1.8.1

### Story F.g: v1.8.2 Fix Integration Tests Broken by v1.8.0 Hard-Fail Lock Check [Done]

Story F.e promoted a missing `conda-lock.yml` from a dismissible warning to a blocking error. Integration tests create ephemeral micromamba environments without a lock file (they test other features — doctor, auto-detection, cross-platform, run, pip upgrade), so all such tests began failing with `ERROR: No conda-lock.yml found.`

Root cause: the test helper's `run()` method sets sensible defaults for the test environment (`PYVE_NO_INSTALL_DEPS=1`, etc.) but was not setting `PYVE_NO_LOCK=1`. The lock-file hard-fail is already covered by `tests/unit/test_lock_validation.bats`; integration tests should not re-test it implicitly.

- [x] Add `env.setdefault("PYVE_NO_LOCK", "1")` to `PyveRunner.run()` in `tests/helpers/pyve_test_helpers.py`, inside the `PYTEST_CURRENT_TEST` guard, alongside `PYVE_NO_INSTALL_DEPS`
  - [x] Applies automatically to all `pyve.init(backend='micromamba')` calls across all integration test files (40+ call sites) without modifying each test
  - [x] `init_micromamba()` in `ProjectBuilder` is covered by the same path (creates its own `PyveRunner`, calls `runner.run()` which checks `PYTEST_CURRENT_TEST`)
  - [x] Unit tests in `test_lock_validation.bats` are unaffected — they invoke `pyve.sh` directly without `PyveRunner`
- [x] Update CHANGELOG.md with v1.8.2 entry
- [x] Bump VERSION to 1.8.2

### Story F.h: v1.8.3 Update GitHub Actions to Node.js 24 Compatible Versions [Done]

GitHub Actions deprecated Node.js 20 runners; actions still on Node 20 will be forced to Node 24 by default from June 2, 2026. Four actions in the CI workflows were affected.

- [x] Update `.github/workflows/test.yml`
  - [x] `actions/checkout@v4` → `@v6` (Node 24, 5 occurrences)
  - [x] `actions/setup-python@v5` → `@v6` (Node 24, 3 occurrences)
  - [x] `codecov/codecov-action@v4` → `@v5` (composite/shell action — no Node runtime, 3 occurrences)
  - [x] `mamba-org/setup-micromamba@v1` → `@v2` (latest release; still Node 20 upstream — warning will persist until mamba-org ships a Node 24 version)
- [x] Update `.github/workflows/deploy-docs.yml`
  - [x] `actions/checkout@v4` → `@v6`
  - [x] `actions/setup-python@v5` → `@v6`
- [x] Update CHANGELOG.md with v1.8.3 entry
- [x] Bump VERSION to 1.8.3

### Story F.i: Documentation Audit — Sync Site Docs with Phase F Implementation [Done]

Gap analysis of `docs/specs/features.md`, `docs/specs/tech-spec.md`, and `docs/site/` against the Phase F implementation (F.a–F.h). Several user-facing pages contained stale content, an outright error in `.gitignore` documentation, and missing Phase F features.

**`docs/specs/features.md`** (F.a–F.f gaps):
- [x] Optional inputs table: added `--no-lock` and `--allow-synced-dir` rows
- [x] Environment Variables table: added `PYVE_NO_LOCK` and `PYVE_ALLOW_SYNCED_DIR` rows
- [x] FR-5 (`pyve doctor`): added three new micromamba diagnostic checks (duplicate dist-info, cloud sync collision artifacts ` 2`, conda/pip native library conflicts)

**`docs/specs/tech-spec.md`** (F.a–F.f gaps):
- [x] `lib/utils.sh` function table: added 5 new functions (`check_cloud_sync_path`, `write_vscode_settings`, `doctor_check_duplicate_dist_info`, `doctor_check_collision_artifacts`, `doctor_check_native_lib_conflicts`)
- [x] `.gitignore` template structure: added `.vscode/settings.json` to dynamic entries list
- [x] CLI Modifier Flags table: added `--no-lock` and `--allow-synced-dir` rows
- [x] Unit test table: added `test_doctor.bats`; removed stale hardcoded count from `test_utils.bats`
- [x] Integration test table: added `test_force_ambiguous_prompt.py`, `test_force_backend_detection.py`, `test_pip_upgrade.py`
- [x] CI Pipeline table: "Coverage Report" → "Bash Coverage (kcov)" with accurate description

**`docs/site/usage.md`** (critical error + gaps):
- [x] **Bug fix:** Removed `conda-lock.yml` from the `.gitignore` template listing — it was incorrectly shown as a Pyve-managed ignored pattern; it must be committed (per F.a)
- [x] Added `--no-lock` to `--init` options section and examples
- [x] Added `PYVE_NO_LOCK` and `PYVE_ALLOW_SYNCED_DIR` to Environment Variables table
- [x] Updated `pyve doctor` output description with three new micromamba checks

**`docs/site/backends.md`** (gaps):
- [x] "Mixed Dependencies" workflow: added `environment.yml` + `conda-lock.yml` generation steps before `pyve --init` (the workflow would hard-fail without them per F.e)
- [x] Best Practices "Lock Your Dependencies": added note that missing lock is a hard error and `--no-lock` is the escape hatch
- [x] Added Troubleshooting entries: cloud-synced directory and missing `conda-lock.yml`

**`docs/site/getting-started.md`** (gaps):
- [x] Micromamba backend workflow: added `environment.yml` creation + `conda-lock.yml` generation before `pyve --init`
- [x] Added cloud-synced directory Troubleshooting entry

**`docs/site/index.html`**: No changes — omissions are acceptable at the marketing landing page level.

### Story F.j: v1.8.4 Fix conda Platform String and --force Pre-Flight Check Ordering [Done]

Two bugs observed in production use on macOS Apple Silicon:

**Bug 1 — Wrong conda platform string in lock file recommendations**

`lib/micromamba_env.sh` uses `$(uname -m)` to suggest the `-p` argument for `conda-lock`, which returns `arm64` on Apple Silicon. The correct conda platform string is `osx-arm64`. All five call sites produce the wrong string on macOS and the wrong string on Linux aarch64 (`aarch64` instead of `linux-aarch64`).

Platform mapping:
| `uname -s` | `uname -m` | conda platform |
|---|---|---|
| Darwin | arm64 | osx-arm64 |
| Darwin | x86_64 | osx-64 |
| Linux | aarch64 | linux-aarch64 |
| Linux | x86_64 | linux-64 |

**Bug 2 — Lock file staleness check runs after purge in `--init --force`**

In `pyve.sh`, `--force` re-initialization purges the environment (~line 498) before the lock file validation is reached (~line 611). If the user answers `n` to the stale-lock prompt, the environment has already been destroyed with no recovery path. All blocking pre-flight checks must run before the purge begins.

Correct `--init --force` flow:
1. Detect backend
2. Run all pre-flight checks (cloud sync location, lock file existence, lock file staleness)
3. Present single consolidated warning/confirmation prompt
4. Only then purge and rebuild

**Implementation tasks:**

- [x] Add `get_conda_platform()` helper to `lib/micromamba_env.sh`
  - [x] Maps `uname -s` + `uname -m` → conda platform string per the table above
  - [x] Falls back to `$(uname -m)` with a warning for unrecognized combinations
- [x] Replace all five `$(uname -m)` occurrences in `lib/micromamba_env.sh` (lines ~159, 251, 275, 316, 340) with `$(get_conda_platform)`
- [x] Fix `--init --force` pre-flight ordering in `pyve.sh`
  - [x] Move `validate_lock_file_status` call (and `check_cloud_sync_path`) to execute before `purge --keep-testenv`
  - [x] On pre-flight failure, abort with a clear error — no purge has occurred
  - [x] Preserve the existing single user confirmation prompt (currently at ~line 484) as the gate for purge
- [x] Add unit tests in `tests/unit/test_lock_validation.bats`
  - [x] Test: `get_conda_platform` returns `osx-arm64` on Darwin/arm64
  - [x] Test: `get_conda_platform` returns `osx-64` on Darwin/x86_64
  - [x] Test: `get_conda_platform` returns `linux-64` on Linux/x86_64
  - [x] Test: `get_conda_platform` returns `linux-aarch64` on Linux/aarch64
- [x] Update CHANGELOG.md with v1.8.4 entry
- [x] Bump VERSION to 1.8.4

### Story F.k: v1.8.5 Fix Double Backend Prompt and Improve --force UX [Done]

A follow-up to F.j. Discovered that `--init --force` could show the ambiguous backend prompt twice, and that all three interactive gates in the force path gave the user insufficient context to make an informed choice.

**Bug — Double backend prompt in ambiguous projects**

After the F.j pre-flight fix, `get_backend_priority` is called once in the pre-flight block and again in the main flow at line ~596. In projects with both `environment.yml` and `pyproject.toml` (and no config file), the "Initialize with micromamba backend? [Y/n]:" prompt appeared twice. The config file avoids this for existing projects (Priority 2 returns the recorded backend), but after purge the config is gone, so the second call fell through to file detection and re-prompted.

**Fix:** Introduce `preflight_backend` as a function-level variable in `init()`. The force pre-flight stores its result there; the main backend-detection block reuses it when non-empty, skipping the second `get_backend_priority` call entirely.

**UX improvements**

All three interactive prompts in the force path now tell the user what will happen for each choice:

| Prompt | Before | After |
|--------|--------|-------|
| Ambiguous backend `[Y/n]` — chose `n` | `"Using venv backend"` | `"Using venv backend — initialization will continue with venv"` |
| Stale lock file `"Continue anyway?"` — chose `n` | `"Aborted. Please update lock file and try again."` | `"Aborted — no changes made. Update lock file and try again."` |
| Final confirmation `[y/N]` | `"Continue? [y/N]:"` | Prints `Purge: existing <backend>` / `Rebuild: fresh <backend>` summary (+ `⚠ Backend change` line if switching); `"Cancelled — no changes made, existing environment preserved"` on `n` |

- [x] Introduce `preflight_backend` as a function-level variable in `init()` and reuse it in the main backend-detection block to prevent the double prompt
- [x] Replace bare `"Continue? [y/N]:"` with a Purge/Rebuild summary and backend-change warning
- [x] Change cancel message to `"Cancelled — no changes made, existing environment preserved"`
- [x] Update stale-lock abort message to `"Aborted — no changes made. Update lock file and try again."`
- [x] Update ambiguous-backend venv-chosen message to `"Using venv backend — initialization will continue with venv"`
- [x] Update CHANGELOG.md with v1.8.5 entry
- [x] Bump VERSION to 1.8.5

### Story F.l: v1.8.6 Fix --force Pre-Flight Ignoring Project Files When Config Records Old Backend [Done]

The `--force` pre-flight backend detection called `get_backend_priority` without skipping the config file. If the config recorded an old backend (e.g., `venv` after the user declined micromamba during a previous init), Priority 2 in `get_backend_priority` returned that old backend immediately — never reaching the file-based detection that would have found `environment.yml`. The result: `--init --force` on a project with `environment.yml` + `pyproject.toml` silently re-initialized as venv, ignoring the conda files.

**Root cause:** `get_backend_priority` Priority 2 reads `.pyve/config`. This is correct for normal `--init` (preserve the recorded backend), but wrong for `--force` (clean slate — the config is about to be wiped).

**Fix:** Add a `skip_config` parameter (default `false`) to `get_backend_priority`. The force pre-flight passes `skip_config=true`, which bypasses Priority 2 and falls through to file detection. All other callers are unaffected. With `skip_config=true` the priority chain becomes: CLI flag → project files → interactive prompt (if ambiguous) → default venv.

**Side effect fixed:** With the old config skipped, the pre-flight now correctly detects the ambiguous case (both `environment.yml` + `pyproject.toml`), prompts once, and stores the answer in `preflight_backend` for reuse in the main flow. The confirmation summary also correctly shows `⚠ Backend change: venv → micromamba` when switching.

- [x] Add `skip_config` parameter to `get_backend_priority` in `lib/backend_detect.sh`
- [x] Pass `skip_config=true` from the `--force` pre-flight call in `pyve.sh`
- [x] Update CHANGELOG.md with v1.8.6 entry
- [x] Bump VERSION to 1.8.6
- [x] Fix broken integration test `test_force_reinit_prompts_and_respects_venv_choice_in_ambiguous_case` in `tests/integration/test_force_backend_detection.py`
  - Before F.k/F.l fixes the prompt order was: confirmation → backend; after fixes it is: backend → confirmation
  - Change `input="y\nn\n"` to `input="n\ny\n"` (backend prompt first: `n` = choose venv; then confirmation: `y` = proceed)
  - Add assertion that `"Initialize with micromamba backend?"` appeared in stdout/stderr
  - Update comment block to reflect correct prompt order
- [x] Add regression test `test_force_reinit_ignores_stale_config_backend` in `tests/integration/test_force_backend_detection.py`
  - Scenario: project has both `environment.yml` + `pyproject.toml`; initial `--init --backend venv` writes `backend: venv` to config; `--init --force` (interactive, `input="y\ny\n"`) must skip the stale config and show the backend detection prompt
  - Assert `"Initialize with micromamba backend?"` appears in output — if `skip_config` were not working, Priority 2 would return `venv` immediately and the prompt would never appear

---

## `pyve lock` and conda-lock Workflow Ownership

Pyve already wraps the full micromamba lifecycle. The one gap remaining in the workflow is `conda-lock.yml` regeneration: users must know the right platform string (`osx-arm64`, not `arm64`), remember the full `conda-lock` invocation, ignore a misleading post-run message, and then know to run `pyve --init --force` to apply the new file. Pyve already resolved the platform-string problem in F.j (`get_conda_platform()`). These stories complete the workflow by adding `pyve lock` as a thin, opinionated wrapper.

### Story F.m: v1.9.0 `pyve lock` — conda-lock Wrapper Command [Done]

**Background**

Currently, every mention of conda-lock in Pyve output sends the user to run raw `conda-lock` commands themselves:

```
Regenerate with: conda-lock -f environment.yml -p osx-arm64
```

This forces users to:
1. Know the correct conda platform string for their machine (`osx-arm64`, not the raw `uname -m` output `arm64`)
2. Remember the full syntax (`conda-lock -f environment.yml -p <platform>`)
3. Ignore the misleading post-run message: `Install lock using: conda-lock install --name YOURENV conda-lock.yml` — which is **not** the correct workflow in a Pyve-managed project (the correct workflow is `pyve --init --force`)
4. Know to run `pyve --init --force` afterward if the environment needs to be rebuilt

Pyve already knows all of this. A `pyve lock` command encapsulates the entire workflow.

**Scope and policy change**

This story changes Pyve's stated policy from "hands-off for conda-lock" to "provides a thin opinionated wrapper." Pyve still does **not** install `conda-lock`; users add it to `environment.yml` dependencies or install it manually. The change is that Pyve now wraps the invocation when `conda-lock` is available on PATH, handling platform detection, output filtering, and actionable next-step messaging.

Non-goals for this story:
- `pyve lock --check` (verify currency without regenerating) — deferred to F.n
- Multi-platform lock generation — `pyve lock` generates for the current platform only
- Installing `conda-lock` — Pyve does not bootstrap `conda-lock`

**Command behavior**

```
pyve lock
```

1. **Check backend** — if `.pyve/config` exists and records `backend: venv`, fail immediately with:
   ```
   ERROR: pyve lock is for micromamba projects only.
   This project uses the venv backend. conda-lock.yml is not used by venv.
   ```
   This prevents the confusing "environment.yml not found" message reaching venv users and avoids accidentally running conda-lock on a venv project that happens to have a stale `environment.yml` around.

2. **Verify `conda-lock` is available** — if `conda-lock` is not on PATH, fail with:
   ```
   ERROR: conda-lock is not available in the current environment.
   Add 'conda-lock' to environment.yml dependencies and run 'pyve --init --force'.
   ```

3. **Verify `environment.yml` exists** — if not found, fail with:
   ```
   ERROR: environment.yml not found. pyve lock requires a conda environment file.
   Initialize with: pyve --init --backend micromamba
   ```

4. **Detect platform** via `get_conda_platform()` (already in `lib/micromamba_env.sh`)

5. **Run `conda-lock -f environment.yml -p <platform>`**, capturing stdout/stderr

6. **Detect the "already up to date" case** — when conda-lock's output contains `"already locked"` or `"spec hash already locked"`, print:
   ```
   ✓ conda-lock.yml is already up to date for osx-arm64. No changes made.
   ```

7. **On successful regeneration**, suppress the misleading `conda-lock install` post-run message and replace it with:
   ```
   ✓ conda-lock.yml updated for osx-arm64.

   To rebuild the environment from the new lock file:
     pyve --init --force

   If the environment is already initialized and you only need to commit the updated
   lock file, rebuilding is optional.
   ```

8. **On any other non-zero exit**, propagate the error and pass through conda-lock's output unmodified.

**Implementation checklist**

- [x] Add `run_lock()` function to `pyve.sh` (or `lib/micromamba_env.sh`)
  - [x] Check `.pyve/config` backend; if `backend: venv`, fail with "pyve lock is for micromamba projects only" message
  - [x] Check `conda-lock` is on PATH; fail with helpful message if not
  - [x] Check `environment.yml` exists; fail with message that includes `pyve --init --backend micromamba` hint
  - [x] Call `get_conda_platform()` for the platform string
  - [x] Run `conda-lock -f environment.yml -p "$platform"` capturing combined output
  - [x] Detect "already locked" / "spec hash already locked" pattern in output; print up-to-date message and exit 0
  - [x] On success, filter out lines matching `conda-lock install` and print the pyve-specific rebuild guidance
  - [x] On non-zero exit, pass through output unmodified and propagate exit code
- [x] Add `lock` to the CLI dispatch in `pyve.sh` (alongside `doctor`, `run`, `test`, `testenv`)
- [x] Update stale lock warning in `warn_stale_lock_file()` (`lib/micromamba_env.sh`): change raw `conda-lock` command to `"pyve lock"`
- [x] Update missing lock warning in `info_missing_lock_file()` (`lib/micromamba_env.sh`): change raw `conda-lock` command to `"pyve lock"`
- [x] Update the strict-mode error messages in `validate_lock_file_status()` that reference raw `conda-lock` commands
- [x] Update `pyve --help` output to include `lock` in the command list

**Policy and spec updates**

- [x] `docs/specs/features.md`:
  - [x] Remove "Pyve does not manage conda-lock (users install and run it themselves)" from the Non-Goals section
  - [x] Add replacement non-goal: "Pyve does not install `conda-lock` — users add it to `environment.yml` or install it manually; Pyve wraps the invocation via `pyve lock` when it is available"
  - [x] Add `lock` to the required Command flag list
  - [x] Add FR-15: `pyve lock` — conda-lock Wrapper
- [x] `docs/specs/tech-spec.md`:
  - [x] Add `lock` to the Commands and Flags table
  - [x] Document `run_lock` in `lib/micromamba_env.sh` function table (lives in `pyve.sh`)
  - [x] Add `test_lock_command.py` to the integration test table

**README updates**

- [x] Remove "Pyve does not install or manage `conda-lock`, but you can install it yourself and Pyve won't interfere." from the Philosophy section
- [x] Add `pyve lock` to the All Commands table
- [x] Update the Lock File Validation section's "Generate Lock Files" example to show `pyve lock` as the primary method with raw `conda-lock` as a fallback

**MkDocs site updates**

- [x] `docs/site/usage.md`:
  - [x] Add `pyve lock` to the Command Overview table
  - [x] Add a `### lock` command reference section documenting behavior, prerequisites, output, and examples
- [x] `docs/site/backends.md`:
  - [x] Update the `micromamba Example` code block: replace raw `conda-lock` command with `pyve lock`
  - [x] Update the "With conda-lock (reproducible)" example in the Dependency Management section
  - [x] Update the "Data Science Project (micromamba)" workflow example
  - [x] Update the "Mixed Dependencies (micromamba)" workflow example
  - [x] Update the Best Practices "Lock Your Dependencies" section
  - [x] Update the Missing conda-lock.yml troubleshooting entry
- [x] `docs/site/ci-cd.md`: Updated "Lock File Stale" troubleshooting entry to use `pyve lock`
- [x] `docs/site/index.html`: No changes required — the marketing page operates at feature-card level

**Tests**

- [x] Unit tests appended to `tests/unit/test_lock_validation.bats`:
  - [x] Test: `warn_stale_lock_file` output references `pyve lock` not raw `conda-lock -f` command
  - [x] Test: `info_missing_lock_file` output references `pyve lock` not raw `conda-lock -f` command
  - [x] Test: `validate_lock_file_status` strict stale error references `pyve lock`
  - [x] Test: `validate_lock_file_status` missing lock error references `pyve lock`
- [x] Integration tests in `tests/integration/test_lock_command.py`:
  - [x] Test: `pyve lock` on a venv-backend project → non-zero exit + "micromamba projects only" message; must not mention `environment.yml not found`
  - [x] Test: `pyve lock` with no `environment.yml` → non-zero exit + clear error with `--backend micromamba` hint
  - [x] Test: `pyve lock` on venv project that happens to have `environment.yml` → same "micromamba projects only" error
  - [x] Test: `pyve lock` with `environment.yml` but `conda-lock` not on PATH → non-zero exit + install instructions
  - [x] Test (micromamba only): `pyve lock` end-to-end → produces `conda-lock.yml`
  - [x] Test (micromamba only): success output references `pyve --init --force` not raw conda-lock commands
  - [x] Test (micromamba only): success output does not contain `conda-lock install` or `Install lock using`
  - [x] Test (micromamba only): second `pyve lock` run without spec change → up-to-date or mtime unchanged

- [x] Update CHANGELOG.md with v1.9.0 entry
- [x] Bump VERSION to 1.9.0

### Story F.n: v1.9.1 `pyve doctor` Detects Relocated venv [Done]

When a project directory is moved (e.g., `~/Documents/Code/pyve` → `~/Developer/Pointmatic/pyve`), the venv appears healthy to `pyve doctor` — all checks pass with `✓` — but the environment is silently broken. `which python` resolves to the system shim (asdf/pyenv) instead of `.venv/bin/python` because the `activate` script and `pyvenv.cfg` contain hardcoded paths to the original location.

**Symptoms observed:**
- `pyve doctor` reports all green
- Shell prompt shows `(venv:pyve)` (direnv sets `VIRTUAL_ENV` and `PYVE_PROMPT_PREFIX`)
- `which python` returns `/Users/.../.asdf/shims/python`, not `.venv/bin/python`
- `pyvenv.cfg` `command` field points to old path; `activate` script sets `VIRTUAL_ENV` to old path

**Root cause analysis (per debug-guide.md):**

1. **Requirements gap** — FR-5 lists what doctor reports but does not require validating that the venv's internal paths match the current project directory.
2. **Test coverage gap** — `test_doctor_detects_broken_venv` tests a deleted venv, not a relocated one. No test verifies path consistency between `pyvenv.cfg` and `$(pwd)`.
3. **Implementation gap** — `doctor_command()` checks `[[ -f "$env_path/bin/python" ]]` and runs `--version`, but never reads `pyvenv.cfg`. The binary works (it's a symlink to the asdf-installed Python), so the check passes even though PATH activation is broken.

**Fix design — minimal change:**

After the existing venv directory and Python binary checks (line ~1924 in `pyve.sh`), add a `pyvenv.cfg` path consistency check:

1. Read `.venv/pyvenv.cfg`
2. Extract the path from the `command = ... -m venv <path>` line
3. Compare to `$(pwd)/$venv_dir` (canonicalized)
4. If mismatch, emit: `⚠ Environment: venv was created at <old-path> (project appears to have been relocated)`
5. Suggest: `Run 'pyve --init --force' to recreate the environment at the current location.`

**Implementation checklist**

- [x] Add `doctor_check_venv_path()` function to `lib/utils.sh`
  - [x] Read `"$env_path/pyvenv.cfg"` and parse the `command` line to extract venv creation path
  - [x] Canonicalize both paths (resolve symlinks via `cd && pwd -P`) before comparing
  - [x] On mismatch: print `⚠ Environment: venv path mismatch (project may have been relocated)`
  - [x] Print original path and current expected path
  - [x] Suggest `pyve --init --force` to recreate
- [x] Call `doctor_check_venv_path "$env_path"` from `doctor_command()` in `pyve.sh` after Python version check

**Spec updates**

- [x] `docs/specs/features.md`: Added venv path consistency check to FR-5 bullet list
- [x] `docs/specs/tech-spec.md`: Added `doctor_check_venv_path` to `lib/utils.sh` function table

**Tests**

- [x] Integration test in `tests/integration/test_doctor.py`:
  - [x] `test_doctor_detects_relocated_venv` — init venv, rewrite `pyvenv.cfg` command path and `activate` VIRTUAL_ENV to a stale path, assert doctor output contains relocation warning
- [x] Unit tests in `tests/unit/test_doctor.bats`:
  - [x] Test: `pyvenv.cfg` with matching path → no warning
  - [x] Test: `pyvenv.cfg` with mismatched path → warning emitted
  - [x] Test: missing `pyvenv.cfg` → no warning
  - [x] Test: `pyvenv.cfg` without `command` line → no warning

- [x] Update CHANGELOG.md with v1.9.1 entry
- [x] Bump VERSION to 1.9.1

### Story F.o: `pyve lock --check` — Lock Currency Verification [Done]

A follow-up to F.m. Adds a `--check` flag to `pyve lock` for CI/CD pipelines that want to verify `conda-lock.yml` is up to date with `environment.yml` **without** modifying it. Exits 0 if current, non-zero if stale or missing.

**Note:** This was fully implemented as part of Story F.m (v1.9.0) but not marked done. No version bump — no new code changes.

**Motivation:** Teams running CI against a committed `conda-lock.yml` need a fast gate that catches `environment.yml` changes that were not accompanied by a `pyve lock` run. Unlike `--strict` in `pyve --init`, this check is explicit and targeted.

**Command behavior**

```
pyve lock --check
```

- Compares `environment.yml` mtime against `conda-lock.yml` mtime (same logic as `is_lock_file_stale()`)
- Exit 0: `✓ conda-lock.yml is up to date.`
- Exit 1 (stale): `✗ conda-lock.yml is stale — environment.yml has been modified since the lock was generated. Run: pyve lock`
- Exit 1 (missing): `✗ conda-lock.yml not found. Run: pyve lock`
- Does not invoke `conda-lock` — mtime comparison only, so `conda-lock` need not be installed

**Relationship to `validate_lock_file_status()`:** `pyve lock --check` is a thin public-facing alias for the existing mtime-comparison logic, with pyve-aligned exit codes and messaging. The existing function continues to be used internally by `pyve --init` and `pyve --init --force`.

**Implementation checklist**

- [x] Add `--check` flag parsing to `run_lock()` in `pyve.sh` (shipped in v1.9.0)
- [x] When `--check` is set, call `is_lock_file_stale()` / check for missing `conda-lock.yml`; print status and exit without invoking `conda-lock`
- [x] Add `--check` to `pyve lock` docs in `docs/site/usage.md`
- [x] Add CI/CD usage example in `docs/site/ci-cd.md`:
  ```yaml
  - name: Verify lock file is up to date
    run: pyve lock --check
  ```
- [x] Integration test: `pyve lock --check` exits 0 when `conda-lock.yml` is newer than `environment.yml`
- [x] Integration test: `pyve lock --check` exits 1 with stale message when `environment.yml` is newer
- [x] Integration test: `pyve lock --check` exits 1 with missing message when `conda-lock.yml` absent
- [x] Integration test: `pyve lock --check` does not invoke `conda-lock`
- [x] CHANGELOG.md v1.9.0 entry includes `--check` documentation

### Story F.p: Fix "No environment found" After Update-in-Place on Cloned Projects [Done]

**Bug:** Cloning a GitHub repo that was initialized with an older version of pyve leaves `.pyve/config` in the repo but no `.venv` directory (gitignored). Running `pyve --init` → option 1 "Update in-place" (or `--update`) updates the config version but does **not** create the missing environment. `pyve doctor` then reports "No environment found".

**Note:** This was already fixed in an earlier release. Both update-in-place code paths now check for a missing environment directory and fall through to creation. Tests exist and pass. No version bump — no new code changes.

**Root cause:** Both update-in-place code paths (`PYVE_REINIT_MODE=update` and interactive option 1) `return 0` immediately after calling `update_config_version()` without checking whether the environment directory actually exists.

**Fix:** After updating the config, check whether the environment directory exists. If missing, fall through to the normal environment creation flow rather than returning early.

- [x] Write failing test: `TestReinitUpdateMissingEnv::test_update_flag_creates_missing_venv` in `tests/integration/test_reinit.py`
  - [x] Set up a project with `.pyve/config` (backend: venv) but no `.venv` directory
  - [x] Run `pyve --init --update`; assert exit 0 and `.venv` exists
- [x] Write failing test: `TestReinitUpdateMissingEnv::test_interactive_option1_creates_missing_venv` in `tests/integration/test_reinit.py`
  - [x] Same setup; run `pyve --init` with input `"1\n"`; assert exit 0 and `.venv` exists
- [x] Fix `pyve.sh` — `PYVE_REINIT_MODE=update` path: after `update_config_version()`, check env directory; fall through to creation if missing
- [x] Fix `pyve.sh` — interactive option 1 path: same env-existence check before `return 0`
- [x] Tests pass, no regressions
