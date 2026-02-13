# stories.md — Pyve (Bash)

This document contains the implementation plan for remaining Pyve work. Stories are organized by phase and reference modules defined in `tech_spec.md`. Current version is v1.1.4.

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

### Story A.b: v1.2.0 Activate Validate Integration Tests [Planned]

Remove stale skip decorators from `test_validate.py` and reconcile test expectations with actual `--validate` output.

- [ ] Read `lib/version.sh` `run_full_validation()` output format and exit codes
- [ ] Add missing `init_venv()` helper method to `ProjectBuilder` in `tests/helpers/pyve_test_helpers.py` (calls `pyve --init --backend venv --no-direnv` via subprocess)
- [ ] Remove `@pytest.mark.skip` from `TestValidateCommand` class
- [ ] Run tests, fix assertion mismatches (output strings, exit codes) against actual `--validate` output
- [ ] Verify: `pytest tests/integration/test_validate.py::TestValidateCommand -v` passes

### Story A.c: v1.2.1 Activate Validate Edge Case & Platform Tests [Planned]

Activate the remaining validate test classes.

- [ ] Remove `@pytest.mark.skip` from `TestValidateEdgeCases`
- [ ] Remove `@pytest.mark.skip` from `TestValidateWithDoctor`
- [ ] Remove `@pytest.mark.skip` from `TestValidateMacOS` and `TestValidateLinux`
- [ ] Run tests, fix assertion mismatches
- [ ] Verify: `pytest tests/integration/test_validate.py -v` — all non-micromamba tests pass

### Story A.d: v1.2.2 Increase Unit Test Coverage for version.sh [Planned]

Add Bats unit tests for `lib/version.sh` functions not currently covered.

- [ ] Add tests for `compare_versions()` — equal, greater, less, edge cases (missing patch, zero components)
- [ ] Add tests for `validate_pyve_version()` — matching, older, newer, missing config
- [ ] Add tests for `validate_installation_structure()` — valid structure, missing `.pyve/`, missing config
- [ ] Add tests for `write_config_with_version()` and `update_config_version()`
- [ ] Verify: `bats tests/unit/test_version.bats` passes

### Story A.e: v1.2.3 Coverage Audit and Gap Fill [Planned]

Run coverage report, identify remaining low-coverage modules, and add targeted tests.

- [ ] Run `pytest tests/integration/ --cov=. --cov-report=term-missing` and capture per-file coverage
- [ ] Identify functions/branches below 60% coverage
- [ ] Add integration tests for uncovered error-handling paths in `pyve.sh` (missing dependencies, invalid inputs, purge edge cases)
- [ ] Add unit tests for any uncovered `lib/utils.sh` branches (e.g., `remove_pattern_from_gitignore`, `is_file_empty` edge cases)
- [ ] Verify: overall coverage ≥ 65%

### Story A.f: v1.2.4 Coverage Target 80% [Planned]

Push coverage from ~65% to the 80% target.

- [ ] Add integration tests for `pyve run` error paths (no environment, command not found)
- [ ] Add integration tests for `pyve doctor` edge cases (missing config, corrupted state)
- [ ] Add integration tests for `pyve test` and `pyve testenv` workflows
- [ ] Add unit tests for `lib/distutils_shim.sh` branches not covered
- [ ] Verify: overall coverage ≥ 80%
- [ ] Update `testing_spec.md` Phase 2 status to reflect completion

---

## Phase B: Documentation & Cleanup

### Story B.a: Update testing_spec.md [Planned]

Reconcile `testing_spec.md` with the actual test suite after Phase A.

- [ ] Update test structure tree to match actual files (10 unit test files, 11 integration test files)
- [ ] Update coverage goals section to reflect achieved coverage
- [ ] Remove or update Phase 1/Phase 2 references (they're done)
- [ ] Update pytest.ini example to match actual markers (add `requires_direnv`, `venv`, `micromamba`)
- [ ] Update CI/CD section to match actual `test.yml` (separate jobs for unit, integration, micromamba, lint)
