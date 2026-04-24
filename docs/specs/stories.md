# stories.md -- pyve (python)

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see `concept.md`. For requirements and behavior (what), see `features.md`. For implementation details (how), see `tech-spec.md`. For project-specific must-know facts, see `project-essentials.md` (`plan_phase` appends new facts per phase).

---

## Phase K: Break the Pyve Monolith

Pure-refactor phase. Extracts all 11 top-level commands from `pyve.sh` (~3,500 lines) into per-command modules under `lib/commands/<name>.sh`, leaving `pyve.sh` as a thin ~200–300 line dispatcher. **Zero behavior change** is the contract — the user-facing CLI surface (every command, flag, env var, exit code, output line) is byte-identical to v2.3.0. Characterization tests precede every move so the safety net is in place before code shifts.

See [phase-k-break-the-pyve-monolith-plan.md](phase-k-break-the-pyve-monolith-plan.md) for full gap analysis, technical changes, and acceptance criteria. Architectural target lives in [tech-spec.md](tech-spec.md); invariants in [project-essentials.md](project-essentials.md).

**Intended release version:** `v2.4.0` — the whole phase ships together. Individual stories land unversioned; the version bump lives in the last story (K.m).

**Per-extraction-story scaffolding (K.b – K.l).** Every per-command extraction story carries the same five-task pattern from the tech-spec invariant: inventory → coverage audit (story-local, references K.a) → backfill characterization tests → extract → verify green. Latent bugs surfaced by step 3 are carved off into their own dedicated fix stories — not folded into the extraction.

---

### Story K.a.1: v2.3.1 Bugfix micromamba init --force without environment.yml [Done]

**Bug**: `pyve init --force --backend micromamba --python-version <ver>` on a project with an existing venv config but no `environment.yml` hard-errored with `"Neither 'environment.yml' nor 'conda-lock.yml' found"` — even though the same invocation without `--force` (on a fresh dir) succeeds by scaffolding a starter `environment.yml`.

**Root cause**: the `--force` pre-flight at [pyve.sh:654](../../pyve.sh#L654) duplicated `validate_lock_file_status` from the main micromamba branch ([pyve.sh:829](../../pyve.sh#L829)) but omitted the `scaffold_starter_environment_yml` call that precedes it at [pyve.sh:799-806](../../pyve.sh#L799-L806). On a directory with neither file, validation's Case 4 fires before scaffolding gets a chance, aborting the switch.

**Fix**: invoke `scaffold_starter_environment_yml` before `validate_lock_file_status` in the `--force` pre-flight, mirroring the main-flow ordering. When scaffolding succeeds, set `PYVE_NO_LOCK=1` so the follow-up validation recognises the newly scaffolded file as a legitimate lock-less state.

**Tasks**

- [x] Add `scaffold_starter_environment_yml` call before `validate_lock_file_status` in the `--force` pre-flight ([pyve.sh:654-664](../../pyve.sh#L654-L664))
- [x] Add regression test `test_force_switch_venv_to_micromamba_without_environment_yml` in [tests/integration/test_force_backend_detection.py](../../tests/integration/test_force_backend_detection.py)
- [x] Verify new test fails before fix and passes after
- [x] Verify full bats suite (712 tests) and pytest integration suite still pass (5 pre-existing failures confirmed unrelated — tracked separately)
- [x] Bump version to 2.3.1

### Story K.a.2: Command coverage audit [Planned]

Produce `docs/specs/phase-K-command-coverage-audit.md` mapping every command's behaviors to existing test coverage and identifying backfill targets. No code changes. Inputs to all subsequent K stories.

**Tasks**

- [ ] Create `docs/specs/phase-K-command-coverage-audit.md` with one section per command: `init`, `purge`, `update`, `check`, `status`, `lock`, `run`, `test`, `testenv`, `python`, `self`
- [ ] For each command, document: inputs (positional + flags + env vars), outputs (stdout, stderr, exit codes, files created/modified), side effects (`.pyve/`, `.gitignore`, `.envrc`, rc files, etc.), cross-command helpers it calls (which `lib/<topic>.sh` functions)
- [ ] For each command, list every integration test (pytest) that exercises it and every unit test (Bats) that touches its helpers; note coverage gaps
- [ ] Identify backfill targets: behaviors that need new characterization tests *before* extraction can proceed safely. Be conservative — gaps are easier to spot now than after the move
- [ ] Note pre-existing coverage anomalies (tests that depend on `pyve.sh` line numbers, internal function names, etc.) — these become extraction-blockers if not handled
- [ ] Surface any cross-command coupling discovered during the audit (e.g., `init` calls a function that also gets called from `update`); these inform the `lib/<topic>.sh` vs command-private placement decisions in K.b–K.l
- [ ] Present the audit document for review before K.b starts

---

### Story K.b: Extract `run` [Planned]

First extraction. Smallest, simplest command — proves the dispatcher contract in actual code. Establishes the per-command extraction pattern that K.c–K.l will follow.

**Tasks**

- [ ] **Inventory:** document `run`'s responsibilities (venv vs micromamba dispatch; arg pass-through; exit-code propagation; asdf compat env-var injection per FR-J2); list cross-command helpers it calls
- [ ] **Coverage audit (story-local):** quote K.a's `run` section; note any new gaps surfaced by closer inspection
- [ ] **Backfill characterization tests** against current `pyve.sh` (should pass immediately); commit before extraction
- [ ] **Extract** `run()` to `lib/commands/run.sh` with the file-header license block; add direct-execution guard; add `source lib/commands/run.sh` line in `pyve.sh`'s sourcing block (alphabetical position); update the dispatcher's `run` arm to call the extracted function
- [ ] **Verify green:** full Bats + pytest suite passes on macOS + Linux; CLI surface byte-identical (spot-check `pyve run python --version` and `pyve --no-direnv run env | grep ASDF` if asdf is present)
- [ ] Append `lib/commands/run.sh` function-signature table to tech-spec.md's `lib/commands/<name>.sh` section

---

### Story K.c: Extract `lock` [Planned]

Small, isolated command. Absorbs the existing `run_lock` helper from `pyve.sh` (per the tech-spec annotation: "moves to `lib/commands/lock.sh` as part of the command-module extraction phase").

**Tasks**

- [ ] **Inventory:** `lock`'s responsibilities (backend guard, conda-lock prerequisite check, platform detection, output filtering, rebuild guidance); helpers it calls (`get_conda_platform`, etc.)
- [ ] **Coverage audit (story-local):** quote K.a's `lock` section
- [ ] **Backfill characterization tests** if needed (existing `test_lock_command.py` may already cover the surface)
- [ ] **Extract** `lock()` (and the `run_lock` helper, renamed to `lock` itself or kept as `_lock_run_conda_lock` per audit's recommendation) to `lib/commands/lock.sh`
- [ ] **Verify green** + update tech-spec annotation (drop the "currently in `pyve.sh`" note on `run_lock`'s row)
- [ ] Append function-signature table to tech-spec.md

---

### Story K.d: Extract `python` namespace [Planned]

First namespace extraction. Smallest namespace — `set` + `show` only. Proves the namespace single-file convention from project-essentials.

**Tasks**

- [ ] **Inventory:** namespace dispatcher + leaves (`python_set`, `python_show`); responsibilities of each
- [ ] **Coverage audit (story-local):** quote K.a's `python` section
- [ ] **Backfill characterization tests** for both leaves (set with valid version, set with invalid format, show with `.tool-versions`, show with `.python-version`, show with neither)
- [ ] **Extract** `python()` dispatcher + `python_set()` + `python_show()` to a single `lib/commands/python.sh` (per project-essentials: namespace commands are single files)
- [ ] **Verify green** including help-text byte-identical for `pyve python --help`, `pyve python set --help`, `pyve python show --help`
- [ ] Append function-signature table to tech-spec.md

---

### Story K.e: Extract `self` namespace [Planned]

`install` + `uninstall`. Decision point: does `install_prompt_hook` belong in `self.sh` or in `init.sh`? K.a's audit informs this — placement determined by which command(s) call it.

**Tasks**

- [ ] **Inventory:** namespace dispatcher + `self_install` + `self_uninstall`; document `install_prompt_hook`'s caller graph from K.a
- [ ] **Coverage audit (story-local):** quote K.a's `self` section
- [ ] **Backfill characterization tests** (install + uninstall round-trip; rc-file preservation; `.local/.env` preservation when non-empty; sentinel block removal on uninstall for both `~/.zshrc` and `~/.bashrc`)
- [ ] **Decide and document `install_prompt_hook` placement:** if called only by `init`, becomes `_init_install_prompt_hook` (moves with K.l); if called by `self_install` too, stays in `lib/utils.sh` as a cross-command helper
- [ ] **Extract** to `lib/commands/self.sh`
- [ ] **Verify green**
- [ ] Append function-signature table to tech-spec.md

---

### Story K.f: Extract `test` [Planned]

Small command that delegates to `testenv_run`. Comes before K.g, which means a temporary cross-file call (`test` in `lib/commands/test.sh` calls `testenv_run` still in `pyve.sh`); resolves naturally on K.g.

**Tasks**

- [ ] **Inventory:** `test`'s responsibilities (auto-install pytest prompt, delegate to testenv); helpers it calls
- [ ] **Coverage audit (story-local):** quote K.a's `test` section
- [ ] **Backfill characterization tests** (pytest-present, pytest-missing-and-prompted, pytest-missing-and-CI, args pass-through, exit-code propagation)
- [ ] **Extract** `test()` to `lib/commands/test.sh`; the call to `testenv_run` resolves to the in-`pyve.sh` function for now
- [ ] **Verify green**
- [ ] Append function-signature table to tech-spec.md
- [ ] Note in story-completion comment: "Temporary cross-file call to `testenv_run` (still in `pyve.sh`); resolves on K.g."

---

### Story K.g: Extract `testenv` namespace [Planned]

Largest namespace command — `init` + `install` + `purge` + `run`. After this story, K.f's temporary cross-file call resolves to a clean call into `lib/commands/testenv.sh`.

**Tasks**

- [ ] **Inventory:** dispatcher + four leaves; responsibilities and helper calls for each
- [ ] **Coverage audit (story-local):** quote K.a's `testenv` section; this is one of the more test-heavy commands so coverage should be strong
- [ ] **Backfill characterization tests** for any audit-identified gaps
- [ ] **Extract** all four leaves + dispatcher to `lib/commands/testenv.sh`
- [ ] **Verify green** including K.f's `test` command now calling into `lib/commands/testenv.sh`
- [ ] Append function-signature table to tech-spec.md

---

### Story K.h: Extract `status` [Planned]

Read-only command, no side effects. Well-bounded section design from `phase-H-check-status-design.md`.

**Tasks**

- [ ] **Inventory:** `status`'s responsibilities (sectioned read-only output: Project / Environment / Integrations); helpers it calls (config readers, package counters, etc.)
- [ ] **Coverage audit (story-local):** quote K.a's `status` section
- [ ] **Backfill characterization tests** (each section emits expected rows; always-zero exit code; behavior with missing `.pyve/config`)
- [ ] **Extract** `status()` to `lib/commands/status.sh`
- [ ] **Verify green**
- [ ] Append function-signature table to tech-spec.md

---

### Story K.i: Extract `check` [Planned]

~20 diagnostic checks. Large but well-bounded. Several check helpers (`doctor_check_*` in `lib/utils.sh`) **stay in `lib/utils.sh`** per the cross-command-helper rule — only the `check()` orchestrator and any check-private helpers move.

**Tasks**

- [ ] **Inventory:** `check`'s responsibilities (run ~20 checks, aggregate severity, emit 0/1/2 exit code); list every `doctor_check_*` helper it calls and confirm they stay in `lib/utils.sh`
- [ ] **Coverage audit (story-local):** quote K.a's `check` section
- [ ] **Backfill characterization tests** for any audit-identified gaps; `pyve check` is severity-bearing so exit-code coverage matters
- [ ] **Extract** `check()` (the orchestrator) to `lib/commands/check.sh`; `doctor_check_*` helpers stay in `lib/utils.sh`
- [ ] **Verify green** including all three exit-code paths (0 / 1 / 2)
- [ ] Append function-signature table to tech-spec.md

---

### Story K.j: Extract `update` [Planned]

Non-destructive upgrade. Shares helpers with `init` — careful audit needed to decide which helpers move with `init` (K.l), which stay shared in `lib/utils.sh`, which become `update`-private.

**Tasks**

- [ ] **Inventory:** `update`'s responsibilities (rewrite `.pyve/config` `pyve_version`, refresh `.gitignore` template, refresh `.vscode/settings.json` if present, refresh `.pyve/` layout, run project-guide step 2); cross-helper map vs `init`
- [ ] **Coverage audit (story-local):** quote K.a's `update` section
- [ ] **Backfill characterization tests** (no-op-when-already-current, re-running idempotency, `--no-project-guide` skips step 2, never rebuilds venv, never prompts)
- [ ] **Decide helper placement.** Helpers called *only* by `init` and `update` (not other commands) stay in `lib/utils.sh` per the cross-command-helper rule (two callers = shared). Document each decision in the story
- [ ] **Extract** `update()` to `lib/commands/update.sh`
- [ ] **Verify green**
- [ ] Append function-signature table to tech-spec.md

---

### Story K.k: Extract `purge` [Planned]

Medium complexity. `.gitignore` cleanup logic stays in `lib/utils.sh` (already used by `init`); `--keep-testenv` flag handling and venv/micromamba env removal are purge-private.

**Tasks**

- [ ] **Inventory:** `purge`'s responsibilities (remove venv / micromamba env, version manager files, `.envrc`, `.env` if empty, `.gitignore` patterns, `.vscode/settings.json`); `--keep-testenv` flag behavior
- [ ] **Coverage audit (story-local):** quote K.a's `purge` section
- [ ] **Backfill characterization tests** for any gaps (preserve non-empty `.env`, preserve `conda-lock.yml` for micromamba, `--keep-testenv` preserves testenv)
- [ ] **Extract** `purge()` to `lib/commands/purge.sh`
- [ ] **Verify green** including the H.a-era idempotency test (byte-identical `.gitignore` after purge-then-reinit)
- [ ] Append function-signature table to tech-spec.md

---

### Story K.l: Extract `init` [Planned]

The largest extraction. ~300 lines of `init()` + helpers. Last in the order so it benefits from every prior story's pattern refinement. Absorbs `run_project_guide_hooks` as `_init_run_project_guide_hooks` (per the tech-spec annotation).

**Tasks**

- [ ] **Inventory:** `init`'s responsibilities (backend detection, version manager setup, venv/micromamba env creation, pip-deps prompt, direnv configuration, `.env` setup, `.gitignore` rebuild, `.pyve/config` write, project-guide hooks, micromamba `.vscode/settings.json`, asdf compat); the long list of helpers it calls; private vs shared classification per K.a
- [ ] **Coverage audit (story-local):** quote K.a's `init` section; this is the most-tested command (`test_venv_workflow.py`, `test_micromamba_workflow.py`, `test_reinit.py`, `test_pip_upgrade.py`, etc.)
- [ ] **Backfill characterization tests** for any gaps; confidence here matters most because `init` is the primary user-facing command
- [ ] **Extract** `init()` + `run_project_guide_hooks` (renamed to `_init_run_project_guide_hooks`) + any other init-private helpers to `lib/commands/init.sh`. Honor K.e's `install_prompt_hook` placement decision
- [ ] **Verify green** — full suite, both backends, both platforms, both Python matrix versions; spot-check `pyve init --help` byte-identical
- [ ] Append function-signature table to tech-spec.md
- [ ] Verify `pyve.sh` line count is in the 200–350 range (acceptance criterion 1)

---

### Story K.m: v2.4.0 Release Wrap [Planned]

Final story. Spec finalization, version bump, CHANGELOG, startup-time sanity check.

**Tasks**

- [ ] Verify `pyve.sh` is in the 200–350 line range; if not, investigate (likely a helper that should have moved to `lib/commands/`)
- [ ] Spot-check `pyve.sh`'s remaining content matches the "What lives" list in tech-spec's `pyve.sh — Thin Entry Point` section: globals, sourcing, universal flags, dispatcher, `legacy_flag_error`, `unknown_flag_error`, `main`
- [ ] Run startup-time sanity check: `time pyve --version` before vs. after the refactor; sourcing 11 extra files should add <50ms. If significantly more, investigate (probably a helper doing real work at source-time); resolve before release
- [ ] Update tech-spec.md per-command function-signature tables: confirm all 11 sections appended over K.b–K.l, no orphaned "currently in `pyve.sh`" annotations remain
- [ ] Bump `VERSION` in `pyve.sh` from `2.3.0` to `2.4.0`
- [ ] Finalize `CHANGELOG.md` v2.4.0 entry: high-level summary ("All 11 top-level commands extracted to `lib/commands/<name>.sh`; `pyve.sh` is now a thin ~200–300 line dispatcher; zero behavior change") + pointer to phase-K plan doc + any latent-bug fix stories that landed as side effects
- [ ] Verify: full CI green; `pyve --version` prints `2.4.0`

---

## Future

### Story ?.?: Auto-Remediation for Diagnostics (`pyve check --fix`) [Planned]

After Phase H shipped `pyve check` in v2.0, evaluate adding `--fix` for common auto-remediable issues (missing venv → run init, stale `.pyve/config` version → run update, missing distutils shim on 3.12+ → re-install, etc.). Deliberately deferred to collect real usage data on `pyve check` before deciding which fixes to automate and with what safety gates.

---

### Story ?.?: SHA256 Verification of Bootstrap Download [Planned]

**Motivation**: I.h audit finding — `bootstrap_install_micromamba` ([lib/micromamba_bootstrap.sh:87-200](../../lib/micromamba_bootstrap.sh#L87-L200)) currently verifies the downloaded micromamba tarball only via transport (TLS to `micro.mamba.pm`) + operational sanity (non-empty, extracts, binary runs and reports a version). No cryptographic content integrity. Same trust bar as most `curl | bash` installers, but a step below `apt` / `brew` signed-package verification.

**Design sketch** (to be refined when the story is picked up):

- **Hash source**: two realistic options.
  1. Hardcode `(os, arch, version) → sha256` map in a new `lib/micromamba_manifest.sh`. Explicit, audit-friendly, zero runtime network overhead. Cost: every micromamba release that pyve wants to track requires a pyve release to update the table.
  2. Fetch hashes dynamically from GitHub Releases API (`https://api.github.com/repos/mamba-org/micromamba-releases/releases/latest`). No hardcoded table; picks up new releases automatically. Cost: extra network round-trip, GitHub rate limits (60/hr anonymous), more error paths. Pin specific versions to soften the moving-target problem.
- **Verification step** slots between the download and the extraction in `bootstrap_install_micromamba`. On mismatch: `log_error`, `rm -f "$temp_file"`, `return 1`. On match: `log_info "Verified micromamba tarball SHA256"`.
- **Escape hatch**: `PYVE_NO_BOOTSTRAP_VERIFY=1` env var for developers on networks that strip TLS cert chains or fetch from a mirror.

**Tasks**

- [ ] Decide between hardcoded table vs GitHub API (weigh update cadence vs runtime cost).
- [ ] Implement verification in `bootstrap_install_micromamba`.
- [ ] Activate `test_bootstrap_download_verification` in [tests/integration/test_bootstrap.py:182-195](../../tests/integration/test_bootstrap.py#L182-L195); replace the "verified/checksum" substring assertion with something specific to the chosen implementation (e.g. `Verified micromamba tarball SHA256` log line + a negative test that mismatches fail the bootstrap).
- [ ] Add a bats unit test that exercises the mismatch path via `curl`-shim returning known bogus content.
- [ ] Document the escape hatch in `features.md` and the new env var in the Environment Variables table.

---

### Story ?.?: Micromamba Version Pinning via `--micromamba-version` [Planned]

**Motivation**: I.h audit finding — [lib/micromamba_bootstrap.sh:36](../../lib/micromamba_bootstrap.sh#L36) hardcodes `version="latest"` in the download URL. Reproducible bootstraps across machines or CI runs require a pinned version. The skipped `test_bootstrap_version_selection` in [test_bootstrap.py:170-180](../../tests/integration/test_bootstrap.py#L170-L180) was written for this feature before it was implemented.

**Design sketch**

- **New CLI flag** `--micromamba-version <ver>` on `pyve init`, parallel to the existing `--bootstrap-to`. Propagates into `bootstrap_micromamba_auto`.
- **URL construction**: `get_micromamba_download_url` takes an optional `version` arg; URL becomes `https://micro.mamba.pm/api/micromamba/<platform>/<version>` when version is set, `/latest` otherwise.
- **Config-file key**: optional — `micromamba.micromamba_version` in `.pyve/config` could pin per-project. Weigh against the "bootstrap is CLI-only" invariant pinned by the I.d negative tests; adding this one key would require inverting those tests.
- **Compose cleanly with K's SHA256 story**: with version pinning, the hardcoded-table approach becomes much more tractable because pinned versions have known-stable hashes.

**Tasks**

- [ ] Add `--micromamba-version <ver>` flag parsing alongside `--auto-bootstrap` / `--bootstrap-to` in `pyve.sh`.
- [ ] Plumb version through `bootstrap_micromamba_auto` → `bootstrap_install_micromamba` → `get_micromamba_download_url`.
- [ ] Activate `test_bootstrap_version_selection` with a real version string (e.g. `2.0.5`) and assert the download URL in stdout contains that version.
- [ ] Decide on config-key support; if yes, revisit and invert I.d's negative tests.
- [ ] Document the flag in `--help`, `features.md`, `tech-spec.md`.

---

### Story ?.?: Fix pre-existing integration test failures [Planned]

**Motivation**: surfaced during story K.a.1 regression sweep. Four tests in [tests/integration/](../../tests/integration/) fail against `main` unrelated to any in-flight change; three are UI-drift (assertions checking `stderr` for output now on `stdout`, or looking for prompt text that changed), one is a genuine behavior check worth reinvestigating, and one is a flaky timeout. Pinning these now so they don't mask real regressions in future `make test-integration` runs.

**Tasks**

- [ ] `test_reinit.py::TestReinitForce::test_force_purges_existing_venv` — assertion `"Force re-initialization" in result.stderr` fails because the `warn()` banner prints to `stdout`. Update the assertion to check combined output (or `stdout`).
- [ ] `test_reinit.py::TestReinitForce::test_force_prompts_for_confirmation` — asserts `"Proceed?" in result.stdout` but `ask_yn` prompt text / stream appears to have changed (stdout now shows only the `Cancelled` message). Verify where the prompt is emitted and update assertion or re-emit the prompt to the captured stream.
- [ ] `test_auto_detection.py::TestEdgeCases::test_invalid_backend_in_config` — asserts `'invalid' in result.stderr.lower() or 'backend' in result.stderr.lower()` but the error banner is on `stdout`. Same UI-drift fix as above.
- [ ] `test_auto_detection.py::TestPriorityOrder::test_priority_cli_over_all` — asserts `(project_dir / ".venv").exists()` but the directory is not created in the scenario. Investigate whether this is a test-setup gap (missing fixture state) or a genuine regression in CLI-priority backend dispatch.
- [ ] `test_cross_platform.py::TestPlatformDetection::test_python_platform_info` — `subprocess.TimeoutExpired` on a short `python -c` invocation. Likely environmental (cold asdf shim, Python install triggered by test harness). Add a pre-warm step or bump the timeout if the root cause is benign.
- [ ] Re-run `make test-integration` after fixes; expect zero failures on a clean checkout.

---
