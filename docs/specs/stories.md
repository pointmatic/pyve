# stories.md — Pyve (Bash)

This document contains the implementation plan for remaining Pyve work. Stories are organized by phase and reference modules defined in `tech_spec.md`. Current version is v1.2.5.

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

### Story B.a: Update testing_spec.md [Planned]

Reconcile `testing_spec.md` with the actual test suite after Phase A.

- [ ] Update test structure tree to match actual files (10 unit test files, 11 integration test files)
- [ ] Update coverage goals section to reflect achieved coverage
- [ ] Remove or update Phase 1/Phase 2 references (they're done)
- [ ] Update pytest.ini example to match actual markers (add `requires_direnv`, `venv`, `micromamba`)
- [ ] Update CI/CD section to match actual `test.yml` (separate jobs for unit, integration, micromamba, lint)

---

## Phase C: Homebrew Packaging

### Story C.a: Publish Pyve via Homebrew Tap [Planned]

Package Pyve for installation via `brew install pointmatic/pyve/pyve`.

- [ ] Create `pointmatic/homebrew-pyve` GitHub repo via `brew tap-new pointmatic/homebrew-pyve`
- [ ] Create a tagged release in `pointmatic/pyve` (e.g., `v1.2.0` or current stable)
- [ ] Compute SHA256 of the release tarball
- [ ] Write `Formula/pyve.rb` — install `pyve.sh` + `lib/` under `libexec/`, write exec wrapper under `bin/pyve`
- [ ] Verify `SCRIPT_DIR` resolution works when executed via Homebrew's `bin/pyve` → `libexec/pyve.sh` wrapper
- [ ] Add `test` block to formula: `assert_match "pyve version", shell_output("#{bin}/pyve --version")`
- [ ] Run `brew install --build-from-source pointmatic/pyve/pyve` and verify `pyve --init`, `pyve doctor`, `pyve run` work
- [ ] Detect Homebrew-managed installs in `pyve --install` / `pyve --uninstall` and warn/skip
- [ ] Push formula to `pointmatic/homebrew-pyve` and verify `brew install pointmatic/pyve/pyve` works from scratch
- [ ] Document Homebrew installation in `README.md`
