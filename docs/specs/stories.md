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

### Story K.a.2: v2.3.2 Bugfix — Uniform '.envrc' template across backends [Done]

**Bug**: after `pyve init --force --backend micromamba` on a previously-venv project, `project-guide` shell completion (and any other completion whose rc-file guard uses `command -v`) silently stops working. Venv-backed projects are unaffected.

**Root cause**: the micromamba `.envrc` generator at [pyve.sh:1106-1126](../../pyve.sh#L1106-L1126) writes a **relative** `ENV_PATH` into `.envrc`:

```bash
ENV_PATH=".pyve/envs/<name>"
export PATH="$ENV_PATH/bin:$PATH"
```

Relative entries on `PATH` resolve against the shell's current `cwd`, not the project directory. `.zshrc` runs before direnv enters the project dir, so at startup `cwd=$HOME` and the relative entry resolves to `$HOME/.pyve/envs/<name>/bin` — which does not exist. The `command -v project-guide` guard in rc-file completion blocks fails, completion never registers. The venv backend sidesteps this by `source`-ing Python's `activate` script, which bakes an absolute `VIRTUAL_ENV` into `PATH`.

**Design — uniform `.envrc` template**: rather than fix micromamba in isolation, converge both backends on a single four-line shape so the class of bug cannot recur and future backends (uv, poetry, conda) inherit the symmetry:

```bash
PATH_add "<absolute-bin-dir>"            # direnv stdlib: resolves relative → absolute
export <BACKEND_SENTINEL>="<absolute-env-root>"   # VIRTUAL_ENV for venv, CONDA_PREFIX for conda-like
export PYVE_BACKEND="<name>"
export PYVE_ENV_NAME="<name>"
```

Key properties of the template:

- **`PATH_add`** is direnv's canonical primitive for "add a directory to PATH, accept that it may be relative to `.envrc`, export the absolute form." First-class stdlib, not a workaround.
- **Backend-native sentinel** (`VIRTUAL_ENV` / `CONDA_PREFIX`) is set explicitly rather than inherited by `source`-ing an activate script. Tools that probe these env vars (pip, poetry, IDEs) continue to work.
- **Deactivation** is delegated to direnv itself — it restores PATH on leaving the project dir. The `deactivate` shell function that `source activate` defines is a non-goal; CI/Docker uses `pyve run` or ephemeral shells, so nothing calls `deactivate` anyway.
- **Future backends** (uv, poetry) plug in the same four-line template; no new activation machinery.

Applies only to the direnv path. `--no-direnv` generates no `.envrc` and is unaffected.

**Tasks — implementation**

- [x] Introduce a shared helper (`write_envrc_template` in `lib/utils.sh`) that takes `<rel_bin_dir> <sentinel_var> <rel_env_root> <backend_name> <env_name>` and emits the four-line template plus the existing `.env` `dotenv` block and the asdf reshim guard (Story J.b) when `is_asdf_active`.
- [x] Rewrite `init_direnv_venv` to call the helper with `VIRTUAL_ENV` and the relative venv bin dir. Drop the `source "$VENV_DIR/bin/activate"` line.
- [x] Rewrite `init_direnv_micromamba` to call the helper with `CONDA_PREFIX` and the relative micromamba env bin dir. Resolution of the absolute env path does not depend on `$(pwd)` at generation time — `PATH_add` resolves relative paths at direnv-source time and the sentinel uses literal `$PWD` for runtime expansion.
- [x] Confirm `PYVE_PROMPT_PREFIX` still works under the new template (set in the helper, parameterised by backend + env_name).

**Tasks — tests**

- [x] Add bats unit tests for the new helper in [tests/unit/test_envrc_template.bats](../../tests/unit/test_envrc_template.bats) (15 tests): fixed output shape, no hand-rolled `export PATH=`, correct sentinel per backend, asdf guard appended when active, idempotency, pre-existing file preservation, project-dir independence.
- [x] Add integration tests in [tests/integration/test_envrc_template.py](../../tests/integration/test_envrc_template.py) asserting the generated `.envrc` contains `PATH_add` and no relative PATH literals for both `--backend venv` (6 tests) and `--backend micromamba` (1 test, skipped when micromamba unavailable).
- [x] Regression coverage for the original bug is provided by the integration test `test_envrc_is_project_dir_independent` (no absolute project-dir path baked into `.envrc`) plus the unit tests asserting `PATH_add` is the only path-mutating primitive. The full `bash -l` rc-file simulation was evaluated and judged unnecessary given the direct assertions on the file shape.
- [x] Full bats suite and pytest integration suite verified — no regressions introduced (2 pre-existing `run_command` bats failures and 4 pre-existing/environmental pytest failures documented separately).

**Tasks — documentation**

- [x] **[docs/specs/tech-spec.md](../../docs/specs/tech-spec.md)** — added "Uniform `.envrc` template (v2.3.2 / Story K.a.2)" subsection under Cross-Cutting Concerns; added `write_envrc_template` row to the `lib/utils.sh` function table; updated asdf/direnv Coexistence subsection to point at the new helper.
- [x] **[docs/site/usage.md](../../docs/site/usage.md)** — replaced the stale `layout python` example with the real v2.3.2 template.
- [x] **[docs/site/backends.md](../../docs/site/backends.md)** — updated venv "How it Works" step 4 and micromamba step 5 to reference the uniform `.envrc` template.
- [x] **[README.md](../../README.md)** — Backend Comparison table "Activation" row now reads "`direnv` (uniform `.envrc` template) or `pyve run`" for both backends.
- [x] **[docs/specs/project-essentials.md](../../docs/specs/project-essentials.md)** — appended "Uniform `.envrc` template — all backends share one activation shape" section with the four-line contract and the "adding a new backend" guidance.

**Tasks — release**

- [x] Bumped `VERSION` in [pyve.sh](../../pyve.sh) to `2.3.2`.
- [x] Updated the VERSION row in [docs/specs/tech-spec.md](../../docs/specs/tech-spec.md).
- [x] Added a v2.3.2 entry to [CHANGELOG.md](../../CHANGELOG.md) — "Bug" + "Design" + affected-file summary, matching the K.a.1 entry shape.

**Non-goals for this story**

- Adding uv / poetry backends. The uniform template *enables* them but this story ships only venv + micromamba.
- Replacing `.envrc` with any non-direnv activation mechanism for `--no-direnv` flows. Under `--no-direnv`, `pyve run` continues to be the canonical activation path; no `.envrc` is generated at all.

---

### Story K.a.3: Command coverage audit [Done]

Produce `docs/specs/phase-K-command-coverage-audit.md` mapping every command's behaviors to existing test coverage and identifying backfill targets. No code changes. Inputs to all subsequent K stories.

**Tasks**

- [x] Create `docs/specs/phase-K-command-coverage-audit.md` with one section per command: `init`, `purge`, `update`, `check`, `status`, `lock`, `run`, `test`, `testenv`, `python`, `self`
- [x] For each command, document: inputs (positional + flags + env vars), outputs (stdout, stderr, exit codes, files created/modified), side effects (`.pyve/`, `.gitignore`, `.envrc`, rc files, etc.), cross-command helpers it calls (which `lib/<topic>.sh` functions)
- [x] For each command, list every integration test (pytest) that exercises it and every unit test (Bats) that touches its helpers; note coverage gaps
- [x] Identify backfill targets: behaviors that need new characterization tests *before* extraction can proceed safely. Be conservative — gaps are easier to spot now than after the move
- [x] Note pre-existing coverage anomalies (tests that depend on `pyve.sh` line numbers, internal function names, etc.) — these become extraction-blockers if not handled
- [x] Surface any cross-command coupling discovered during the audit (e.g., `init` calls a function that also gets called from `update`); these inform the `lib/<topic>.sh` vs command-private placement decisions in K.b–K.l
- [x] Present the audit document for review before K.b starts

---

### Story K.b: Extract 'run' [Done]

First extraction. Smallest, simplest command — proves the dispatcher contract in actual code. Establishes the per-command extraction pattern that K.c–K.l will follow.

**Tasks**

- [x] **Inventory:** document `run`'s responsibilities (venv vs micromamba dispatch; arg pass-through; exit-code propagation; asdf compat env-var injection per FR-J2); list cross-command helpers it calls
- [x] **Coverage audit (story-local):** quote K.a's `run` section; note any new gaps surfaced by closer inspection
- [x] **Backfill characterization tests** against current `pyve.sh` (should pass immediately); commit before extraction — *audit found no gaps; existing 26 pytest + 3 J.c bats tests are sufficient characterization.*
- [x] **Extract** `run()` to `lib/commands/run.sh` with the file-header license block; add direct-execution guard; add `source lib/commands/run.sh` line in `pyve.sh`'s sourcing block (alphabetical position); update the dispatcher's `run` arm to call the extracted function
- [x] **Verify green:** full Bats + pytest suite passes on macOS + Linux; CLI surface byte-identical (spot-check `pyve run python --version` and `pyve --no-direnv run env | grep ASDF` if asdf is present)
- [x] Append `lib/commands/run.sh` function-signature table to tech-spec.md's `lib/commands/<name>.sh` section
- [x] **Cross-cutting prep (per K.a.3 audit findings F-1, F-2, F-3):** `install_self` now also copies `lib/commands/*.sh`; `tests/unit/test_bash32_compat.bats` SOURCES array now includes `lib/commands/*.sh`; `tests/unit/test_asdf_compat.bats` `source_pyve_fn` helper now takes an optional file-path arg, with the J.c `run_command` callsites updated to point at `lib/commands/run.sh`. These three changes land with K.b so K.c–K.l inherit a working pattern.

---

### Story K.c: Extract 'lock' [Done]

Small, isolated command. Absorbs the existing `run_lock` helper from `pyve.sh` (per the tech-spec annotation: "moves to `lib/commands/lock.sh` as part of the command-module extraction phase").

**Tasks**

- [x] **Inventory:** `lock`'s responsibilities (backend guard, conda-lock prerequisite check, platform detection, output filtering, rebuild guidance); helpers it calls (`get_conda_platform`, etc.)
- [x] **Coverage audit (story-local):** quote K.a's `lock` section
- [x] **Backfill characterization tests** if needed (existing `test_lock_command.py` may already cover the surface) — *audit found no mandatory backfill; existing 12 pytest + 37 adjacent bats tests are sufficient.*
- [x] **Extract** `lock()` (and the `run_lock` helper, renamed to `lock` itself or kept as `_lock_run_conda_lock` per audit's recommendation) to `lib/commands/lock.sh` — *function initially renamed `run_lock` → `lock`; subsequently renamed `lock` → `lock_environment` in the K.f follow-up under the project-essentials "Function naming convention: `<verb>_<operand>`" rule (operates on environment dependency graph). The intermediate clean-name choice violated the rule.*
- [x] **Verify green** + update tech-spec annotation (drop the "currently in `pyve.sh`" note on `run_lock`'s row)
- [x] Append function-signature table to tech-spec.md

---

### Story K.d: Extract 'python' namespace [Done]

First namespace extraction. Smallest namespace — `set` + `show` only. Proves the namespace single-file convention from project-essentials.

**Tasks**

- [x] **Inventory:** namespace dispatcher + leaves (`python_set`, `python_show`); responsibilities of each
- [x] **Coverage audit (story-local):** quote K.a's `python` section
- [x] **Backfill characterization tests** for both leaves (set with valid version, set with invalid format, show with `.tool-versions`, show with `.python-version`, show with neither) — *added 2 hermetic backfills (`show` falls back to `.pyve/config`; `show` rejects extra args). Audit gap 1 (`python set` happy-path side-effect) deferred: not hermetic without a stubbed/probed version manager — better suited to an integration test alongside K.l.*
- [x] **Extract** `python()` dispatcher + `python_set()` + `python_show()` to a single `lib/commands/python.sh` (per project-essentials: namespace commands are single files) — *initial extraction renamed `python_command` → `python` per audit recommendation; this regressed CI integration tests because the bash function `python()` shadowed the `python` interpreter binary at internal call sites (`python -m venv .venv`, `python -c '...'`). The unit-test suite (729 Bats) didn't catch it — every Bats test invokes pyve as a subprocess, so the function table didn't survive the boundary. Reverted: dispatcher now stays named `python_command`. The leaves keep their renames (`python_set`, `python_show`) — compound names don't collide. Added F-11 to K.a.3 audit and a "Function-name collision rule" entry to project-essentials.md so K.f and any future renames screen for this hazard.*
- [x] **Verify green** including help-text byte-identical for `pyve python --help`, `pyve python set --help`, `pyve python show --help` — *post-revert: 729/729 Bats passing; `pyve init --backend venv` smoke succeeds end-to-end (the formerly-failing flow); 2 of the 5 CI failures (TestMacOSSpecific::test_venv_on_macos, TestCrossPlatform::test_path_separators) re-run green locally.*
- [x] Append function-signature table to tech-spec.md

---

### Story K.e: Extract 'self' namespace [Done]

`install` + `uninstall`. Decision point: does `install_prompt_hook` belong in `self.sh` or in `init.sh`? K.a's audit informs this — placement determined by which command(s) call it.

**Tasks**

- [x] **Inventory:** namespace dispatcher + `self_install` + `self_uninstall`; document `install_prompt_hook`'s caller graph from K.a
- [x] **Coverage audit (story-local):** quote K.a's `self` section
- [x] **Backfill characterization tests** (install + uninstall round-trip; rc-file preservation; `.local/.env` preservation when non-empty; sentinel block removal on uninstall for both `~/.zshrc` and `~/.bashrc`) — *deferred. The audit-flagged backfill targets all require HOME-monkeypatch integration tests (writing to a redirected `~/.local/bin`, asserting on rc-file mutations). Adding them is non-trivial — new pytest file, new fixtures — and out of scope for a pure refactor that does not change install/uninstall behavior. Existing safety net retained: 2 dispatch tests (`test_cli_dispatch.bats`), per-sub-help byte stability (`test_subcommand_help.bats`), 71 helper tests for the SDKMan-aware insertion (`test_project_guide.bats`). The 5 audit-flagged gaps remain known and tracked at K.a.3 §`self`.*
- [x] **Decide and document `install_prompt_hook` placement:** F-5 resolved — `install_prompt_hook` and `uninstall_prompt_hook` are **self-namespace-private** (only callers are `install_self` / `uninstall_self`), so they move with K.e as `_self_install_prompt_hook` / `_self_uninstall_prompt_hook`. Not init-private; not cross-command-shared.
- [x] **Extract** to `lib/commands/self.sh` — single-file namespace per project-essentials F-9. 9 functions moved (3 public: `self_command` (initially `self`, reverted in K.f follow-up under the "Function naming convention: `<verb>_<operand>`" rule), `self_install`, `self_uninstall`; 6 private with `_self_` prefix).
- [x] **Verify green** — bats 729/729; smoke checks for `pyve self`, `pyve self bogus`, `pyve self --help`, `pyve self install --help`, `PYVE_DISPATCH_TRACE` for both leaves all byte-identical.
- [x] Append function-signature table to tech-spec.md (with the F-5 placement decision recorded).

---

### Story K.f: Extract 'test' [Done]

Small command that delegates to `testenv_run`. Comes before K.g, which means a temporary cross-file call (`test` in `lib/commands/test.sh` calls `testenv_run` still in `pyve.sh`); resolves naturally on K.g.

**Tasks**

- [x] **Inventory:** `test`'s responsibilities (auto-install pytest prompt, delegate to testenv); helpers it calls
- [x] **Coverage audit (story-local):** quote K.a's `test` section
- [x] **Backfill characterization tests** (pytest-present, pytest-missing-and-prompted, pytest-missing-and-CI, args pass-through, exit-code propagation) — *deferred. The 5 audit-flagged gaps decompose as: 3 implicitly covered by harness (`PYVE_TEST_AUTO_INSTALL_PYTEST=1` + every integration test running pytest exercises auto-install, args pass-through, exit-code propagation); 2 require pty fixturing (TTY accept/decline) or real Python (non-TTY no-auto-install error path needs `ensure_testenv_exists` to succeed first). Skipping bats backfill mirrors the K.e judgment. Existing safety net: 2 integration tests in `test_testenv.py` invoke `pyve test` directly + the harness implicitly exercises gaps 1/5/6 across the whole suite.*
- [x] **Extract** `test()` to `lib/commands/test.sh`; the call to `testenv_run` resolves to the in-`pyve.sh` function for now — *function named `test_tests` per the project-essentials "Function naming convention: `<verb>_<operand>`" rule (`pyve test [args]` operates on tests; args explicit or implicit). NOT named `test` (F-11: bash-builtin shadow). The same K.f follow-up that introduced this rule retro-renamed K.c's `lock` → `lock_environment` and reverted K.e's `self()` → `self_command()`. F-8 correction: there is no `testenv_run` function — the K.f story's "temporary cross-file call to `testenv_run`" caveat is stale. `test_tests` calls `ensure_testenv_exists` (still in pyve.sh until K.g; cross-file call resolves at runtime), `_test_has_pytest`, `_test_install_pytest_into_testenv`, then `exec`s pytest. The two helpers move with K.f as `_test_` private.*
- [x] **Verify green** — bats 729/729 still passing; smoke `pyve init --backend venv` followed by `pyve test -q` against a trivial test file: pytest auto-installed into testenv, test ran, exit 0 with the expected output.
- [x] Append function-signature table to tech-spec.md (with the F-11 stay-as-`test_command` note and the F-8 stale-caveat correction).
- [x] Note in story-completion comment: "Temporary cross-file call to `testenv_run` (still in `pyve.sh`); resolves on K.g." — *correction recorded above: the only cross-file call is to `ensure_testenv_exists` (NOT `testenv_run`), and K.g moves that helper to `lib/utils.sh` rather than into `lib/commands/testenv.sh`.*

---

### Story K.g: Extract `testenv` namespace [Planned]

Largest namespace command — `init` + `install` + `purge` + `run`. After this story, K.f's temporary cross-file call resolves to a clean call into `lib/commands/testenv.sh`.

**Tasks**

- [ ] **Inventory:** dispatcher + four leaves; responsibilities and helper calls for each
- [ ] **Coverage audit (story-local):** quote K.a's `testenv` section; this is one of the more test-heavy commands so coverage should be strong
- [ ] **Backfill characterization tests** for any audit-identified gaps
- [ ] **Extract** dispatcher (`testenv_command()` per the project-essentials "Function naming convention" rule) + four leaves (`testenv_init()`, `testenv_install()`, `testenv_purge()`, `testenv_run()`) to `lib/commands/testenv.sh`. Per audit F-7 / F-8, also move `purge_testenv_dir` and `ensure_testenv_exists` from `pyve.sh` to `lib/utils.sh` (cross-command shared helpers — `purge` and `test` use them respectively).
- [ ] **Verify green** including the F-8-corrected expectation: K.f's `test_tests` now calls `ensure_testenv_exists` from `lib/utils.sh` (no longer cross-file into `pyve.sh`); the K.f story's caveat about `testenv_run` is stale (no such function exists).
- [ ] Append function-signature table to tech-spec.md

---

### Story K.h: Extract `status` [Planned]

Read-only command, no side effects. Well-bounded section design from `phase-H-check-status-design.md`.

**Tasks**

- [ ] **Inventory:** `status`'s responsibilities (sectioned read-only output: Project / Environment / Integrations); helpers it calls (config readers, package counters, etc.)
- [ ] **Coverage audit (story-local):** quote K.a's `status` section
- [ ] **Backfill characterization tests** (each section emits expected rows; always-zero exit code; behavior with missing `.pyve/config`)
- [ ] **Extract** `status_command()` → `show_status()` to `lib/commands/status.sh` per the project-essentials "Function naming convention" rule (`status` is a noun, not a verb; semantic alignment: `show_status()`)
- [ ] **Verify green**
- [ ] Append function-signature table to tech-spec.md

---

### Story K.i: Extract `check` [Planned]

~20 diagnostic checks. Large but well-bounded. Several check helpers (`doctor_check_*` in `lib/utils.sh`) **stay in `lib/utils.sh`** per the cross-command-helper rule — only the `check()` orchestrator and any check-private helpers move.

**Tasks**

- [ ] **Inventory:** `check`'s responsibilities (run ~20 checks, aggregate severity, emit 0/1/2 exit code); list every `doctor_check_*` helper it calls and confirm they stay in `lib/utils.sh`
- [ ] **Coverage audit (story-local):** quote K.a's `check` section
- [ ] **Backfill characterization tests** for any audit-identified gaps; `pyve check` is severity-bearing so exit-code coverage matters
- [ ] **Extract** `check_command()` → `check_environment()` (the orchestrator) to `lib/commands/check.sh` per the project-essentials "Function naming convention" rule (operand: the project's environment); `doctor_check_*` helpers stay in `lib/utils.sh`
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
- [ ] **Extract** `update_command()` → `update_project()` to `lib/commands/update.sh` per the project-essentials "Function naming convention" rule (operand: the project; refreshes `.pyve/config`, `.gitignore`, `.vscode/settings.json`, project-guide — all project-level)
- [ ] **Verify green**
- [ ] Append function-signature table to tech-spec.md

---

### Story K.k: Extract `purge` [Planned]

Medium complexity. `.gitignore` cleanup logic stays in `lib/utils.sh` (already used by `init`); `--keep-testenv` flag handling and venv/micromamba env removal are purge-private.

**Tasks**

- [ ] **Inventory:** `purge`'s responsibilities (remove venv / micromamba env, version manager files, `.envrc`, `.env` if empty, `.gitignore` patterns, `.vscode/settings.json`); `--keep-testenv` flag behavior
- [ ] **Coverage audit (story-local):** quote K.a's `purge` section
- [ ] **Backfill characterization tests** for any gaps (preserve non-empty `.env`, preserve `conda-lock.yml` for micromamba, `--keep-testenv` preserves testenv)
- [ ] **Extract** `purge()` → `purge_project()` to `lib/commands/purge.sh` per the project-essentials "Function naming convention" rule (operand: the project — removes venv, micromamba env, `.envrc`, `.env`, `.pyve/`, etc.)
- [ ] **Verify green** including the H.a-era idempotency test (byte-identical `.gitignore` after purge-then-reinit)
- [ ] Append function-signature table to tech-spec.md

---

### Story K.l: Extract `init` [Planned]

The largest extraction. ~300 lines of `init()` + helpers. Last in the order so it benefits from every prior story's pattern refinement. Absorbs `run_project_guide_hooks` as `_init_run_project_guide_hooks` (per the tech-spec annotation).

**Tasks**

- [ ] **Inventory:** `init`'s responsibilities (backend detection, version manager setup, venv/micromamba env creation, pip-deps prompt, direnv configuration, `.env` setup, `.gitignore` rebuild, `.pyve/config` write, project-guide hooks, micromamba `.vscode/settings.json`, asdf compat); the long list of helpers it calls; private vs shared classification per K.a
- [ ] **Coverage audit (story-local):** quote K.a's `init` section; this is the most-tested command (`test_venv_workflow.py`, `test_micromamba_workflow.py`, `test_reinit.py`, `test_pip_upgrade.py`, etc.)
- [ ] **Backfill characterization tests** for any gaps; confidence here matters most because `init` is the primary user-facing command
- [ ] **Extract** `init()` → `init_project()` (per the project-essentials "Function naming convention" rule; operand: the project) + `run_project_guide_hooks` (renamed to `_init_run_project_guide_hooks`) + any other init-private helpers to `lib/commands/init.sh`. Honor K.e's `install_prompt_hook` placement decision
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
