# bootstrap_stories.md — Pyve (Bash)

This document contains the implementation plan for micromamba bootstrap integration testing and related work. These stories are lower priority and separated from the main `stories.md`. Versions start at v2.0.0.

Story IDs follow the pattern `<Phase>.<letter>`. Each story that produces code changes includes a version number. Stories are marked `[Planned]` initially and `[Done]` when completed.

---

## Phase X: Bootstrap Integration Test Activation

Activate the 12 skipped bootstrap integration tests in `test_bootstrap.py`. The bootstrap *code* already exists in `lib/micromamba_bootstrap.sh` — this phase is about wiring up integration tests that exercise it end-to-end.

### Story X.a: v2.0.0 Reconcile Bootstrap Test Fixtures [Planned]

The existing skipped tests reference CLI flags and helper methods that don't match the actual implementation. Fix the test scaffolding before activating tests.

- [ ] Audit `test_bootstrap.py` test methods against actual CLI flags (`--auto-bootstrap`, `--bootstrap-to project|user`)
- [ ] Remove non-existent flag references (`bootstrap_url`, `micromamba_version`, `bootstrap_location` as a path)
- [ ] Add `init_micromamba()` helper method to `ProjectBuilder` in `tests/helpers/pyve_test_helpers.py`
- [ ] Verify `project_builder.create_environment_yml()` works correctly with bootstrap tests
- [ ] No skip removal yet — just fix the test code so it's ready

### Story X.b: v2.0.1 Activate Core Bootstrap Tests [Planned]

Activate the main `TestBootstrapPlaceholder` class tests that can run when micromamba is NOT pre-installed.

- [ ] Remove `@pytest.mark.skip` from `test_auto_bootstrap_when_not_installed`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_to_project_sandbox`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_to_user_sandbox`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_skips_if_already_installed`
- [ ] Fix assertions to match actual bootstrap output messages
- [ ] Verify: `pytest tests/integration/test_bootstrap.py::TestBootstrapPlaceholder -v -m micromamba` passes locally with micromamba available

### Story X.c: v2.0.2 Activate Bootstrap Error Handling Tests [Planned]

Activate failure-path tests.

- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_failure_handling`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_platform_detection`
- [ ] Remove `@pytest.mark.skip` from `TestBootstrapEdgeCases` class (`test_bootstrap_with_insufficient_permissions`, `test_bootstrap_cleanup_on_failure`)
- [ ] Fix assertions to match actual error output
- [ ] Verify: `pytest tests/integration/test_bootstrap.py::TestBootstrapEdgeCases -v` passes

### Story X.d: v2.0.3 Activate Bootstrap Configuration Tests [Planned]

Activate config-driven bootstrap tests.

- [ ] Remove `@pytest.mark.skip` from `TestBootstrapConfiguration` class
- [ ] Fix `test_bootstrap_respects_config_file` — reconcile config keys with actual `.pyve/config` format
- [ ] Fix `test_bootstrap_cli_overrides_config` — use actual CLI flags
- [ ] Verify: `pytest tests/integration/test_bootstrap.py::TestBootstrapConfiguration -v` passes

### Story X.e: v2.0.4 Remove Stale Bootstrap Skip from Micromamba Workflow [Planned]

Activate the single skipped bootstrap test in `test_micromamba_workflow.py`.

- [ ] Remove `@pytest.mark.skip` from `test_auto_bootstrap_micromamba` in `test_micromamba_workflow.py`
- [ ] Fix assertions to match actual behavior
- [ ] Verify: `pytest tests/integration/test_micromamba_workflow.py::TestMicromambaBootstrap -v` passes

---

## Phase Y: Bootstrap CI Pipeline

Add a CI job that exercises bootstrap from scratch — without pre-installed micromamba — so the download and install paths are tested in automation.

### Story Y.a: v2.0.5 Add Bootstrap CI Job [Planned]

Create a new GitHub Actions job that tests bootstrap without pre-installed micromamba.

- [ ] Add `integration-tests-bootstrap` job to `.github/workflows/test.yml`
- [ ] Job runs on `ubuntu-latest` and `macos-latest` (no `mamba-org/setup-micromamba` action)
- [ ] Job runs: `pytest tests/integration/test_bootstrap.py -v -m micromamba`
- [ ] Job requires network access (downloads micromamba binary)
- [ ] Verify: CI pipeline passes with new job

### Story Y.b: v2.0.6 Bootstrap Download Verification [Planned]

Evaluate whether the bootstrap code verifies downloaded binaries and add verification if missing.

- [ ] Audit `bootstrap_install_micromamba()` for checksum or signature verification
- [ ] If missing: add SHA256 verification of downloaded micromamba binary
- [ ] Update `test_bootstrap_download_verification` assertions accordingly
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_download_verification`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_version_selection` (if version pinning is supported)
- [ ] Verify: bootstrap tests pass with verification enabled
