# stories.md — Pyve (Bash)

This document contains the implementation plan for remaining Pyve work. Stories are organized by phase and reference modules defined in `tech_spec.md`. Current version is v1.5.1.

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

Phase E: Bug Fixes

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
- [ ] Verify: Run `pyve --init --backend micromamba --force` twice to confirm purge works correctly
