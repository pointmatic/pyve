# Phase K — Command Coverage Audit

Story K.a.3 deliverable. Maps every top-level command in `pyve.sh` (v2.3.2, 3,363
lines) to inputs, outputs, side effects, helper calls, and existing test coverage.
Identifies backfill targets and extraction-blockers that subsequent stories
(K.b–K.l) must address before — or as part of — moving each command to
`lib/commands/<name>.sh`.

Source-of-truth referenced throughout: [pyve.sh](../../pyve.sh) (commands),
[lib/](../../lib/) (helpers), [tests/integration/](../../tests/integration/) (pytest
suites), [tests/unit/](../../tests/unit/) (Bats suites).

---

## How to read this document

Each command section contains:

- **Dispatcher entry** — line range in `pyve.sh`'s `main()` `case` block.
- **Implementation** — line range of the handler function (and any private
  helpers that move with it).
- **Inputs** — positional args, flags, env vars consulted.
- **Outputs** — stdout, stderr, exit codes, files created/modified.
- **Side effects** — `.pyve/`, `.gitignore`, `.envrc`, rc files, etc.
- **Cross-command helpers called** — functions in `lib/<topic>.sh` (stay shared)
  and in `pyve.sh` (private vs. shared classification).
- **Existing test coverage** — pytest integration suites and Bats unit suites
  that exercise the command, with test counts.
- **Coverage gaps** — behaviors not yet exercised by tests; backfill targets.
- **Extraction notes** — ordering constraints, helper-placement decisions, and
  cross-command-coupling findings the per-extraction story must honor.

---

## Cross-cutting findings

These apply across multiple extraction stories and should be acted on at the
appropriate K.* story rather than re-derived in each.

### F-1. `install_self` glob does not recurse into `lib/commands/` — fix in K.b

[pyve.sh:1630](../../pyve.sh#L1630) does:

```bash
cp "$source_dir/lib/"*.sh "$TARGET_BIN_DIR/lib/"
```

This non-recursive glob will silently skip `lib/commands/*.sh` once K.b creates
that directory. **K.b must update `install_self` to also create
`$TARGET_BIN_DIR/lib/commands/` and copy `lib/commands/*.sh`** — otherwise
`pyve self install` will produce a broken installation (sourcing fails because
`lib/commands/run.sh` is absent).

Acceptance criterion for K.b: `pyve self install` followed by
`~/.local/bin/pyve run --help` succeeds.

### F-2. `tests/unit/test_bash32_compat.bats` SOURCES glob does not recurse — fix in K.b

[tests/unit/test_bash32_compat.bats:28-30](../../tests/unit/test_bash32_compat.bats#L28-L30) sets:

```bash
SOURCES=("$PYVE_ROOT/pyve.sh"
         "$PYVE_ROOT/lib"/*.sh
         "$PYVE_ROOT/lib/completion/pyve.bash")
```

The `lib/*.sh` glob does not include `lib/commands/*.sh`. After K.b, the
extracted command files will not be scanned for forbidden bash 4+ constructs
(`declare -A`, `mapfile`, etc.). **K.b must extend the SOURCES array to
`"$PYVE_ROOT/lib/commands"/*.sh`** so the bash 3.2 invariant tests cover the
new directory from day one.

### F-3. `source_pyve_fn` extraction helper is path-pinned to `pyve.sh` — fix in K.b and K.l

[tests/unit/test_asdf_compat.bats:88-97](../../tests/unit/test_asdf_compat.bats#L88-L97)
defines `source_pyve_fn` which awk-extracts function bodies from `$PYVE_ROOT/pyve.sh`.
The helper is regex-driven (function name → `^fn\(\)`), **not** line-number-driven, so
the extraction itself is robust. But the path is hard-coded.

Functions currently extracted by this helper:

- `init_direnv_venv` ([pyve.sh:1049](../../pyve.sh#L1049)) — moves with init in K.l
- `init_direnv_micromamba` ([pyve.sh:1057](../../pyve.sh#L1057)) — moves with init in K.l
- `run_command` ([pyve.sh:1925](../../pyve.sh#L1925)) — moves with run in K.b

**K.b must update `source_pyve_fn` to take an optional path parameter (or scan
both `pyve.sh` and `lib/commands/*.sh`)** so the J.c `pyve run` asdf-guard tests
still load `run_command` after extraction. K.l must do the same for the two
`init_direnv_*` helpers when they move.

Cleanest fix: make `source_pyve_fn` accept a second arg `<file>` defaulting to
`$PYVE_ROOT/pyve.sh`, and update each callsite. Alternative: scan a hardcoded
list of files. The first is preferred — explicit beats clever.

### F-4. Two integration-test comments cite stale `pyve.sh` line numbers

These are documentation comments only (no test assertion depends on the line
number), but they will become misleading once the extraction shuffles line
numbers. Update opportunistically as the relevant code moves:

- [tests/integration/test_bootstrap.py:264](../../tests/integration/test_bootstrap.py#L264) cites `pyve.sh:682`
- [tests/integration/test_force_backend_detection.py:262](../../tests/integration/test_force_backend_detection.py#L262) cites `pyve.sh:789`

Not extraction-blockers; just stale-comment hygiene during K.l's `init` move.

### F-5. Two callers of `install_prompt_hook` — placement decision for K.e

[pyve.sh:1657](../../pyve.sh#L1657) (`install_self`) and [pyve.sh:1845](../../pyve.sh#L1845)
(`uninstall_self`) both call `uninstall_prompt_hook` / `install_prompt_hook`.
**Both callers live in the same namespace** (`self`), so `install_prompt_hook`
(and its sibling `uninstall_prompt_hook`) are **`self`-private** and move into
`lib/commands/self.sh` as `_self_install_prompt_hook` /
`_self_uninstall_prompt_hook` per the per-command-helper convention. They are
not called from `init` despite the K.e story note posing that hypothetical.

Confirmed by grep — no caller outside `install_self` / `uninstall_self`.

### F-6. `purge` is called from `init` (twice) — confirms purge-as-shared-API

[pyve.sh:691](../../pyve.sh#L691) and [pyve.sh:759](../../pyve.sh#L759) (both inside
`init()`) call `purge --keep-testenv --yes` for the `--force` and interactive
"option 2" rebuild paths. After K.k extracts `purge()` to `lib/commands/purge.sh`
and K.l extracts `init()`, `init`'s call into `purge` becomes a cross-file
function call.

This is fine and intentional — K.k lands before K.l, so by the time `init`
moves, `purge()` is already a stable function in `lib/commands/purge.sh` that
gets sourced by `pyve.sh` and is callable from any other command file. No
helper extraction needed; the function name *is* the public API.

### F-7. `purge_testenv_dir` is shared between `purge` and `testenv` — moves to a shared location

[pyve.sh:1180](../../pyve.sh#L1180) (`purge`) and [pyve.sh:1402](../../pyve.sh#L1402)
(`testenv_command`'s `purge` action) both call `purge_testenv_dir`. The function is
~9 lines, single responsibility (`rm -rf .pyve/testenv` with logging).

**Decision (informs K.g and K.k):** since `testenv` is extracted before `purge`
(K.g lands at K.g, `purge` at K.k), move `purge_testenv_dir` to `lib/utils.sh`
during K.g (the first extraction that needs it cross-file). When K.k follows,
the call from `purge()` already resolves to the shared helper. Justification:
the function is small enough that its move to `lib/utils.sh` adds <10 lines to
that file and avoids a temporary "still in pyve.sh" annotation.

### F-8. `testenv_paths`, `testenv_has_pytest`, `install_pytest_into_testenv`, `ensure_testenv_exists` — all testenv-private but called from `test_command` and `init`

Call graph at HEAD:

- `testenv_paths` ([pyve.sh:210](../../pyve.sh#L210)) — only called by `ensure_testenv_exists`. testenv-private.
- `ensure_testenv_exists` ([pyve.sh:216](../../pyve.sh#L216)) — called by:
  - `init()` end-of-flow ([pyve.sh:1003](../../pyve.sh#L1003), venv-only)
  - `testenv_command init` action ([pyve.sh:1381](../../pyve.sh#L1381))
  - `test_command` ([pyve.sh:1411](../../pyve.sh#L1411))
- `testenv_has_pytest` ([pyve.sh:246](../../pyve.sh#L246)) — only called by `test_command` ([pyve.sh:1413](../../pyve.sh#L1413)).
- `install_pytest_into_testenv` ([pyve.sh:254](../../pyve.sh#L254)) — only called by `test_command` (twice: lines [1420](../../pyve.sh#L1420), [1426](../../pyve.sh#L1426)).

**Decision (informs K.f, K.g, K.l):**

- `testenv_has_pytest`, `install_pytest_into_testenv` are `test`-private —
  they move with `test_command` to `lib/commands/test.sh` in K.f as
  `_test_has_pytest` / `_test_install_pytest_into_testenv`.
- `ensure_testenv_exists` and `testenv_paths` are called from THREE places
  (init, testenv, test). They are **shared infrastructure** and move to
  `lib/utils.sh` (or a new `lib/testenv.sh` if it grows; for now, `utils.sh`
  is fine — both functions are small).
- The K.f temporary-cross-file note in stories.md (`test` calls `testenv_run`
  which still lives in `pyve.sh` until K.g) becomes a non-issue under this
  scheme: K.f's `test_command` does **not** call `testenv_run` directly; it
  calls `ensure_testenv_exists` (now in `lib/utils.sh`) and then `exec`s
  pytest. Re-reading [pyve.sh:1409-1440](../../pyve.sh#L1409-L1440) confirms:
  there is no `testenv_run` function — `testenv_command run` is dispatched
  inside the `testenv_command` case block ([pyve.sh:1353-1374](../../pyve.sh#L1353-L1374)), and
  `test_command` reaches into the testenv directly via `exec
  "$testenv_venv/bin/python" -m pytest "$@"`. **Story K.f's "temporary
  cross-file call to `testenv_run`" caveat is therefore stale and can be
  dropped from that story.**

### F-9. Help-block functions stay in `pyve.sh` for now

The 8 `show_*_help()` functions ([pyve.sh:2879-3143](../../pyve.sh#L2879-L3143)) are
called only from the dispatcher's `--help` intercepts in `main()` and from
`self_command()`. They are dispatcher-tier code and live in `pyve.sh` —
not in the per-command files. This matches the project-essentials rule that
`pyve.sh` retains "globals, sourcing, universal flags, dispatcher,
`legacy_flag_error`, `unknown_flag_error`, `main`."

Each per-command file gets its own help block move *only if* the help becomes
substantial enough to merit colocation; for v2.4.0, all 8 stay put. Re-evaluate
during K.m.

### F-10. `run_project_guide_hooks` — init-private

[pyve.sh:349-476](../../pyve.sh#L349-L476). Called twice ([pyve.sh:917](../../pyve.sh#L917),
[pyve.sh:1013](../../pyve.sh#L1013)), both inside `init()`. **`run_project_guide_hooks`
is init-private** and moves with K.l as `_init_run_project_guide_hooks`. The
matching `run_project_guide_update_in_env` (called from both `init` *and*
`update_command`) already lives in `lib/utils.sh` and stays there.

---

## Per-command audit

### `init`

- **Dispatcher entry:** [pyve.sh:3252-3263](../../pyve.sh#L3252-L3263).
- **Implementation:** [pyve.sh:478-1022](../../pyve.sh#L478-L1022) (~545 lines for `init()`),
  plus init-private helpers:
  - `init_python_version` ([pyve.sh:1024](../../pyve.sh#L1024))
  - `init_venv` ([pyve.sh:1037](../../pyve.sh#L1037))
  - `init_direnv_venv` ([pyve.sh:1049](../../pyve.sh#L1049))
  - `init_direnv_micromamba` ([pyve.sh:1057](../../pyve.sh#L1057))
  - `init_dotenv` ([pyve.sh:1064](../../pyve.sh#L1064))
  - `init_gitignore` ([pyve.sh:1088](../../pyve.sh#L1088))
  - `run_project_guide_hooks` ([pyve.sh:349](../../pyve.sh#L349)) — init-private (F-10).

  Total `init`-extraction footprint: ~870 lines. Largest extraction — last in
  the order (K.l).

- **Inputs:**
  - **Positional:** `<dir>` (custom venv directory, default `.venv`).
  - **Flags:** `--python-version <ver>`, `--backend <type>`, `--local-env`,
    `--auto-bootstrap`, `--bootstrap-to <project|user>`, `--strict`,
    `--no-lock`, `--env-name <name>`, `--no-direnv`, `--auto-install-deps`,
    `--no-install-deps`, `--allow-synced-dir`, `--force`, `--project-guide`,
    `--no-project-guide`, `--project-guide-completion`,
    `--no-project-guide-completion`. Legacy: `--update` (hard-errors via
    `legacy_flag_error`).
  - **Env vars (read):** `CI`, `PYVE_FORCE_YES`, `PYVE_REINIT_MODE`,
    `PYVE_NO_LOCK` (via micromamba branch), `PYVE_NO_PROJECT_GUIDE`,
    `PYVE_PROJECT_GUIDE`, `PYVE_PROJECT_GUIDE_COMPLETION`,
    `PYVE_NO_PROJECT_GUIDE_COMPLETION`, `PYVE_TEST_PIN_PYTHON` (test harness
    only), `PYVE_AUTO_INSTALL_DEPS`, `PYVE_NO_INSTALL_DEPS`,
    `PYVE_ALLOW_SYNCED_DIR`, `PYVE_NO_ASDF_COMPAT`.
  - **Env vars (set/exported):** `PYVE_NO_LOCK=1` (when scaffolding starter
    `environment.yml`), `PYVE_AUTO_INSTALL_DEPS=1` /
    `PYVE_NO_INSTALL_DEPS=1` (from flags), `PYVE_ALLOW_SYNCED_DIR=1`,
    `PYVE_REINIT_MODE=force`.

- **Outputs:**
  - **stdout:** banner box, info lines, success ticks, version-detection
    messages, project-guide install/completion progress.
  - **stderr:** `log_error` lines on validation failures.
  - **Exit codes:** 0 (success), 1 (any validation/precondition failure).

- **Side effects (files created/modified):**
  - `.tool-versions` or `.python-version` (via `init_python_version` / version
    manager).
  - `.venv/` (venv backend) or `.pyve/envs/<name>/` (micromamba backend).
  - `.envrc` (unless `--no-direnv`).
  - `.env` (created empty if not present; chmod 600).
  - `.gitignore` (Pyve-managed template + venv-dir line).
  - `.pyve/config` (always written).
  - `.vscode/settings.json` (micromamba backend only, via `write_vscode_settings`).
  - `.pyve/testenv/venv/` (created by `ensure_testenv_exists` after the main env).
  - `environment.yml` (scaffolded if absent + micromamba backend + non-strict).
  - Project-guide artifacts (`.project-guide.yml`, `docs/project-guide/`)
    when the hook runs and chooses install path.
  - User rc files (`~/.zshrc` / `~/.bashrc`) — completion block, when the
    project-guide-completion path is taken.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `config_file_exists`, `read_config_value`,
    `update_config_version`, `validate_venv_dir_name`, `validate_python_version`,
    `write_gitignore_template`, `write_envrc_template`, `write_vscode_settings`,
    `check_cloud_sync_path`, `prompt_install_pip_dependencies`,
    `prompt_install_project_guide`, `prompt_install_project_guide_completion`,
    `is_project_guide_installed`, `install_project_guide`,
    `is_project_guide_completion_present`, `add_project_guide_completion`,
    `run_project_guide_init_in_env`, `run_project_guide_update_in_env`,
    `project_guide_in_project_deps`, `detect_user_shell`, `get_shell_rc_path`,
    `insert_pattern_in_gitignore_section`.
  - `lib/env_detect.sh`: `source_shell_profiles`, `detect_version_manager`,
    `ensure_python_version_installed`, `set_local_python_version`,
    `get_version_file_name`, `is_asdf_active`, `check_direnv_installed`.
  - `lib/backend_detect.sh`: `get_backend_priority`, `validate_backend`,
    `detect_backend_from_files`.
  - `lib/micromamba_core.sh`: `check_micromamba_available`, `get_micromamba_path`.
  - `lib/micromamba_bootstrap.sh`: `bootstrap_micromamba_auto`,
    `bootstrap_micromamba_interactive`.
  - `lib/micromamba_env.sh`: `validate_lock_file_status`,
    `scaffold_starter_environment_yml`, `resolve_environment_name`,
    `validate_environment_name`, `validate_environment_file`,
    `detect_environment_file`, `create_micromamba_env`, `verify_micromamba_env`.
  - `lib/distutils_shim.sh`: `pyve_install_distutils_shim_for_python`,
    `pyve_install_distutils_shim_for_micromamba_prefix`.
  - `lib/ui.sh`: `header_box`, `footer_box`, `banner`, `info`, `success`,
    `warn`, `fail`, `ask_yn`, `run_cmd`.

- **Cross-command helpers called from pyve.sh:**
  - `purge` (twice: `--force` path + interactive option-2 path) — F-6.
  - `ensure_testenv_exists` (F-8) — moves to `lib/utils.sh` in K.g (before
    K.l). By the time `init` extracts, this is already a shared helper.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/integration/test_venv_workflow.py | 19 | venv happy path, idempotency, reinit |
  | tests/integration/test_micromamba_workflow.py | 19 | micromamba happy path, env naming, lock interactions |
  | tests/integration/test_reinit.py | 15 | `--force` and interactive reinit; some pre-existing failures (see Story for "Fix pre-existing integration test failures") |
  | tests/integration/test_auto_detection.py | 17 | backend-priority resolution (CLI > config > files > default) |
  | tests/integration/test_force_backend_detection.py | 7 | `--force` cross-backend switching; K.a.1 added regression `test_force_switch_venv_to_micromamba_without_environment_yml` |
  | tests/integration/test_force_ambiguous_prompt.py | 2 | venv+micromamba ambiguous-detection prompt under `--force` |
  | tests/integration/test_envrc_template.py | 7 | uniform-`.envrc` template (K.a.2) |
  | tests/integration/test_pip_upgrade.py | 2 | `pip install --upgrade pip` post-init for venv |
  | tests/integration/test_project_guide_integration.py | 15 | post-init project-guide hook (install + scaffolding + completion) |
  | tests/integration/test_bootstrap.py | 14 | micromamba bootstrap (`--auto-bootstrap`, `--bootstrap-to`) |
  | tests/integration/test_helpers.py | 4 | `init_micromamba` helper / starter `environment.yml` scaffold |
  | tests/integration/test_cross_platform.py | 22 | platform detection (macOS / Linux); some pre-existing flake (Story for "Fix pre-existing integration test failures") |
  | tests/unit/test_init_ui.bats | 3 | header/footer box wrapping for `pyve init` |
  | tests/unit/test_reinit.bats | 23 | `--force` flag handling, prompts |
  | tests/unit/test_subcommand_help.bats | partial | `pyve init --help` byte stability |
  | tests/unit/test_envrc_template.bats | 15 | uniform-`.envrc` template helper |
  | tests/unit/test_lock_validation.bats | 37 | `validate_lock_file_status` (called by init's micromamba branch) |
  | tests/unit/test_scaffold_environment_yml.bats | 8 | starter-yml scaffolding |
  | tests/unit/test_asdf_compat.bats | 15 (J.b/J.c subset) | `init_direnv_venv` / `init_direnv_micromamba` asdf-guard injection |

  Total: ~150+ tests directly exercise some `init` behavior. This is the most-tested
  command in the suite — confidence is highest here, which matches K.l being the
  last (and largest) extraction.

- **Coverage gaps (backfill targets for K.l):**
  - **Interactive option-1 "update in-place" path** ([pyve.sh:711-755](../../pyve.sh#L711-L755))
    is exercised indirectly through the `--force` path in test_reinit.py, but
    no test sends literal `1\n` to the prompt and asserts the
    `update_config_version` happy path on an existing project. Add one.
  - **Interactive option-3 "cancel" path** ([pyve.sh:763-766](../../pyve.sh#L763-L766))
    has no test. Cheap to backfill: send `3\n`, assert exit 0 and no
    filesystem mutations.
  - **`--allow-synced-dir`** (sets `PYVE_ALLOW_SYNCED_DIR=1`) — the negative
    path (synced dir without flag → fail) is well-covered by
    `check_cloud_sync_path` tests, but the positive override is not. Add one
    integration test.
  - **`--no-install-deps`** — exercised by the test harness `clean_env`
    fixture but no explicit assertion that the deps prompt is suppressed.
  - **Mutually-exclusive flag pairs** (`--project-guide` + `--no-project-guide`,
    `--project-guide-completion` + `--no-project-guide-completion`) — error
    paths at [pyve.sh:582-610](../../pyve.sh#L582-L610) are not tested. Trivial unit-test
    additions.
  - **`--force` + interactive option `2` (purge-and-rebuild)** rebuilds
    using the same backend; `test_reinit.py` covers this, but the
    backend-change variant (option-2 with `--backend` differing from
    `existing_backend`) [pyve.sh:711-716](../../pyve.sh#L711-L716) — actually rejects in
    update mode but allows in option-2 — has no test of the "rejected"
    branch.

- **Pre-existing coverage anomalies:**
  - `test_reinit.py::TestReinitForce::test_force_purges_existing_venv` and
    `test_force_prompts_for_confirmation` — UI-drift failures already tracked
    under "Fix pre-existing integration test failures" in [stories.md:357-369](stories.md#L357-L369).
    Resolve before K.l so the `init`-extraction green-bar is unambiguous.
  - `test_auto_detection.py::TestPriorityOrder::test_priority_cli_over_all`
    — fixture/regression already tracked in same story.
  - `test_cross_platform.py::TestPlatformDetection::test_python_platform_info`
    — flaky timeout already tracked in same story.
  - F-3 (`source_pyve_fn` extraction helper) is path-pinned to `pyve.sh` and
    must be updated when `init_direnv_venv` / `init_direnv_micromamba` move.

- **Extraction notes (for K.l):**
  - Honor F-1 (install_self), F-2 (bash32_compat), F-3 (source_pyve_fn) —
    most should already be done by K.b, but verify.
  - `run_project_guide_hooks` becomes `_init_run_project_guide_hooks` (F-10).
  - The interactive-option-2 path (line 759) calls `purge --keep-testenv --yes`;
    after K.k, this is a cross-file call to `lib/commands/purge.sh::purge`.
    Standard cross-file call, no special handling needed.
  - F-4 stale comment in `test_bootstrap.py:264` cites `pyve.sh:682` —
    update opportunistically when `init` moves.

---

### `purge`

- **Dispatcher entry:** [pyve.sh:3264-3275](../../pyve.sh#L3264-L3275).
- **Implementation:** [pyve.sh:1106-1193](../../pyve.sh#L1106-L1193) (~88 lines for `purge()`),
  plus purge-private helpers:
  - `purge_version_file` ([pyve.sh:1195](../../pyve.sh#L1195))
  - `purge_venv` ([pyve.sh:1207](../../pyve.sh#L1207))
  - `purge_pyve_dir` ([pyve.sh:1218](../../pyve.sh#L1218))
  - `purge_envrc` ([pyve.sh:1442](../../pyve.sh#L1442))
  - `purge_dotenv` ([pyve.sh:1449](../../pyve.sh#L1449))
  - `purge_gitignore` ([pyve.sh:1460](../../pyve.sh#L1460))
  - `purge_testenv_dir` ([pyve.sh:1263](../../pyve.sh#L1263)) — **shared** with `testenv` (F-7).

- **Inputs:**
  - **Positional:** `<dir>` (custom venv directory, default `.venv`; only used
    when no `.pyve/config` exists; otherwise the configured venv dir wins).
  - **Flags:** `--keep-testenv`, `--yes` / `-y`.
  - **Env vars (read):** `CI`, `PYVE_FORCE_YES`.

- **Outputs:**
  - **stdout:** banner box, removal-progress info lines.
  - **stderr:** none in normal operation.
  - **Exit codes:** 0 (success or user-aborted), 1 (unknown-flag error).

- **Side effects (files removed):**
  - Version file (`.tool-versions` or `.python-version`).
  - Venv directory.
  - `.pyve/` (or just `.pyve/config` + `.pyve/envs` when `--keep-testenv`).
  - `.envrc`.
  - `.env` (only if empty; warn-and-preserve otherwise).
  - Pyve-managed lines in `.gitignore`.
  - Micromamba env (via `micromamba env remove -n <name>` before `rm -rf
    .pyve/`).

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `config_file_exists`, `read_config_value`,
    `remove_pattern_from_gitignore`, `is_file_empty`.
  - `lib/env_detect.sh`: `source_shell_profiles`, `detect_version_manager`.
  - `lib/micromamba_core.sh`: `get_micromamba_path`.
  - `lib/ui.sh`: `header_box`, `footer_box`, `warn`, `info`, `success`,
    `ask_yn`.

- **Cross-command helpers called from pyve.sh:** none (after F-7 moves
  `purge_testenv_dir` to `lib/utils.sh` during K.g).

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/unit/test_purge_ui.bats | 6 | header/footer box, `--yes` non-interactive |
  | tests/unit/test_reinit.bats | 23 (subset) | `--keep-testenv` preservation |
  | tests/integration/test_venv_workflow.py | partial | venv purge |
  | tests/integration/test_micromamba_workflow.py | partial | micromamba env removal via `micromamba env remove` |
  | tests/integration/test_testenv.py | 1 (`test_testenv_survives_force_reinit`) | `--keep-testenv` invariant under `init --force` |
  | tests/unit/test_cli_dispatch.bats | partial | dispatcher routing + `--keep-testenv` flag preservation |

- **Coverage gaps (backfill targets for K.k):**
  - **Empty `.env` removal vs. non-empty preservation** ([pyve.sh:1449-1458](../../pyve.sh#L1449-L1458))
    — partial coverage in `test_purge_ui.bats`; add explicit "non-empty
    `.env` is preserved with warn message" assertion if not present.
  - **`.gitignore` byte-identical idempotency after purge-then-reinit**
    (referenced in K.k's task list as the H.a-era invariant). Verify the
    test exists; if not, backfill in K.k.
  - **Micromamba named-removal-fails fallback to prefix-based removal**
    ([pyve.sh:1240-1242](../../pyve.sh#L1240-L1242)) — no test exercises the failure
    path. Hard to test without stubbing `micromamba`; consider if the
    benefit outweighs the stubbing complexity.
  - **`<dir>` positional arg vs. config-derived venv dir precedence**
    ([pyve.sh:1153-1161](../../pyve.sh#L1153-L1161)): explicit positional should win, and
    the test `test_priority_cli_over_all` exercises something similar but
    for `init`. A `purge`-specific test would close this gap.

- **Extraction notes (for K.k):**
  - F-7 is the only cross-command-coupling decision: `purge_testenv_dir`
    moves to `lib/utils.sh` in K.g (before K.k), so K.k just removes the
    function definition from pyve.sh and the call resolves to the shared
    helper.
  - All other purge_* helpers are purge-private (single caller, all from
    inside `purge`). They move into `lib/commands/purge.sh` with the
    `_purge_` prefix per project-essentials.

---

### `update`

- **Dispatcher entry:** [pyve.sh:3280-3291](../../pyve.sh#L3280-L3291).
- **Implementation:** [pyve.sh:2589-2689](../../pyve.sh#L2589-L2689) (~101 lines, single
  function `update_command`).

- **Inputs:**
  - **Positional:** none (errors out on any positional).
  - **Flags:** `--no-project-guide`.
  - **Env vars:** none direct (calls into `run_project_guide_update_in_env`
    which has its own env-var conventions).

- **Outputs:**
  - **stdout:** info lines (`Updating project configuration to Pyve v...`),
    success ticks per refresh step.
  - **stderr:** `log_error` on missing/corrupt config.
  - **Exit codes:** 0 (success / no-op), 1 (no `.pyve/config`, missing backend,
    config-write failure, unknown flag, positional arg).

- **Side effects (files modified):**
  - `.pyve/config` (`pyve_version` rewritten — idempotent).
  - `.gitignore` (Pyve-managed sections refreshed via
    `write_gitignore_template`).
  - `.vscode/settings.json` — refreshed *only if it already exists* and
    backend is micromamba.
  - `.project-guide.yml` and `docs/project-guide/` — refreshed via
    `project-guide update --no-input` if `.project-guide.yml` exists and
    `--no-project-guide` not passed. Creates `.bak.<ts>` siblings for
    modified managed files.

  Explicitly does **not** create `.venv/`, `.envrc`, `.env`, or
  `.vscode/settings.json` if absent.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `config_file_exists`, `read_config_value`,
    `update_config_version`, `write_gitignore_template`,
    `write_vscode_settings`, `run_project_guide_update_in_env`.
  - `lib/version.sh`: (indirect via `update_config_version`).

- **Cross-command helpers called from pyve.sh:** none. `update_command` is
  self-contained — no calls into other command handlers or pyve.sh-internal
  helpers outside its own body.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/unit/test_update.bats | 21 | comprehensive: `--help`, no-`.pyve/config` failure, missing-backend failure, version bump idempotency, `.gitignore` refresh, H.e.2a ignore patterns, `.vscode` create-vs-refresh, `.env`/`.envrc` non-creation, `--no-project-guide`, `--no-project-guide` no-op when `.project-guide.yml` absent, unknown-flag error, top-level help mention, dispatch trace |
  | tests/integration/test_project_guide_integration.py | partial | project-guide refresh path |

- **Coverage gaps (backfill targets for K.j):**
  - **Backend-change rejection** — `update` preserves the recorded backend
    and never prompts; this is asserted in `test_update.bats:133` ("preserves
    recorded backend"). Coverage looks complete.
  - **`update` after `init --force` was interrupted mid-flow** — leaves
    `.pyve/config` corrupt or partially written. Edge case; not a typical
    user path; defer unless K.j surfaces a concrete bug.
  - **micromamba `.vscode/settings.json` regen path** ([pyve.sh:2650-2656](../../pyve.sh#L2650-L2656))
    — `test_update.bats:165` covers the *no-op* path; no test covers the
    actually-refreshes path with a pre-existing `.vscode/settings.json`.
    Backfill target.

- **Extraction notes (for K.j):**
  - `update_command` is self-contained — clean single-file move to
    `lib/commands/update.sh`. No helper-placement decisions.
  - The K.j story task to "decide helper placement" between `init` and
    `update` is therefore narrower than its phrasing suggests: there are no
    pyve.sh-internal helpers shared between init and update at HEAD.
    Library helpers (`write_gitignore_template`, `update_config_version`,
    `run_project_guide_update_in_env`) are already in `lib/`.
  - Help block (`show_update_help`) stays in pyve.sh per F-9.

---

### `check`

- **Dispatcher entry:** [pyve.sh:3330-3341](../../pyve.sh#L3330-L3341).
- **Implementation:** [pyve.sh:2314-2575](../../pyve.sh#L2314-L2575) (~262 lines), split
  into:
  - `check_command` ([pyve.sh:2314](../../pyve.sh#L2314)) — orchestrator with three nested
    closures (`_check_pass`, `_check_warn`, `_check_fail`).
  - `_check_venv_backend` ([pyve.sh:2450](../../pyve.sh#L2450)) — venv-specific check helper.
  - `_check_micromamba_backend` ([pyve.sh:2499](../../pyve.sh#L2499)) — micromamba-specific
    check helper.
  - `_check_summary_and_exit` ([pyve.sh:2571](../../pyve.sh#L2571)) — pretty-printer.

  All four are check-private (single caller, all from inside `check`).

- **Inputs:** no positional, no flags except `--help`. (Unknown flags
  hard-error.)
- **Env vars:** none direct.

- **Outputs:**
  - **stdout:** `Pyve Environment Check\n======================\n\n`, then
    `✓` / `⚠` / `✗` per check, then `N passed, N warnings, N errors`.
  - **stderr:** none in normal operation (unknown-flag is via `log_error`
    → stderr).
  - **Exit codes:** 0 (all pass), 1 (any error), 2 (warnings only). Severity
    escalation is one-way (an error cannot be downgraded by a later
    warning).

- **Side effects:** none (read-only by contract).

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `config_file_exists`, `read_config_value`,
    `doctor_check_duplicate_dist_info`, `doctor_check_collision_artifacts`,
    `doctor_check_native_lib_conflicts`, `doctor_check_venv_path`.
  - `lib/version.sh`: `compare_versions`.
  - `lib/micromamba_core.sh`: `check_micromamba_available`.
  - `lib/micromamba_env.sh`: `is_lock_file_stale`.

  **Important**: the `doctor_check_*` helpers stay in `lib/utils.sh`. They
  are tested directly by `test_doctor.bats` and may grow more callers in
  future (potentially `pyve check --fix` from the deferred story). The
  `check`-extraction does not move them.

- **Cross-command helpers called from pyve.sh:** none. `check_command` and
  its three private helpers are isolated.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/unit/test_check.bats | 17 | exit codes 0/1/2, missing config, missing backend, missing venv, missing python, version drift, missing .env / .envrc, escalation invariant, summary footer, actionable-command-in-failure, micromamba branch, unknown-flag |
  | tests/unit/test_doctor.bats | 23 | `doctor_check_*` helpers (stay in `lib/utils.sh`) |
  | tests/unit/test_doctor_validate_removed.bats | 8 | legacy `doctor`/`validate` hard-errors |

- **Coverage gaps (backfill targets for K.i):**
  - **Pyve version "newer than running pyve" path** ([pyve.sh:2390-2393](../../pyve.sh#L2390-L2393))
    — explicitly tested? `test_check.bats:104` covers the drift case but
    not specifically the `>` direction. Verify; backfill if missing.
  - **Native-lib conflict warning path on micromamba** ([pyve.sh:2566-2568](../../pyve.sh#L2566-L2568))
    — `test_doctor.bats` covers the helper directly but no integration-style
    `check`-orchestrator test exercises the warning escalation. Cheap
    backfill.
  - **All-pass exit-code-0 happy path** — implicit in many tests but a
    direct "fully healthy project, exit 0, no warnings" assertion is
    valuable as an extraction safety net.

- **Extraction notes (for K.i):**
  - All check_* helpers are check-private; they move with K.i and adopt the
    `_check_` prefix (already prefixed today).
  - The three nested closures (`_check_pass`, `_check_warn`, `_check_fail`)
    capture local variables (`errors`, `warnings`, `passed`, `exit_code`)
    via dynamic scoping — bash's quirky-but-stable semantics. Preserve this
    structure during extraction; do not refactor to file-scope state.

---

### `status`

- **Dispatcher entry:** [pyve.sh:3342-3353](../../pyve.sh#L3342-L3353).
- **Implementation:** [pyve.sh:2022-2297](../../pyve.sh#L2022-L2297) (~276 lines), split
  into:
  - `status_command` ([pyve.sh:2022](../../pyve.sh#L2022)) — top-level orchestrator.
  - `_status_row` ([pyve.sh:2057](../../pyve.sh#L2057))
  - `_status_header` ([pyve.sh:2063](../../pyve.sh#L2063))
  - `_status_section_project` ([pyve.sh:2067](../../pyve.sh#L2067))
  - `_status_configured_python` ([pyve.sh:2103](../../pyve.sh#L2103))
  - `_status_section_environment` ([pyve.sh:2122](../../pyve.sh#L2122))
  - `_status_env_venv` ([pyve.sh:2139](../../pyve.sh#L2139))
  - `_status_venv_package_count` ([pyve.sh:2176](../../pyve.sh#L2176))
  - `_status_env_micromamba` ([pyve.sh:2193](../../pyve.sh#L2193))
  - `_status_section_integrations` ([pyve.sh:2239](../../pyve.sh#L2239))

  All ten are status-private (single caller, all from inside `status_command`
  or sibling status_* helpers). `_status_row` is heavily reused (41 callsites
  inside the status block).

- **Inputs:** no positional, no flags except `--help`.
- **Env vars:** `NO_COLOR` (honored — tested at `test_status.bats:257`).

- **Outputs:**
  - **stdout:** "Pyve project status" title + 3 sections (Project, Environment,
    Integrations) + per-section key/value rows.
  - **stderr:** `log_error` only on unknown-flag.
  - **Exit codes:** always 0 (read-only contract — diagnostics are `pyve
    check`'s job).

- **Side effects:** none.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `config_file_exists`, `read_config_value`, `is_file_empty`.
  - `lib/version.sh`: `compare_versions`.
  - `lib/micromamba_env.sh`: `is_lock_file_stale`.
  - `lib/distutils_shim.sh`: (uses `PYVE_DISTUTILS_SHIM_MARKER` constant).

- **Cross-command helpers called from pyve.sh:** none.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/unit/test_status.bats | 25 | help, exit-0 contract, non-project fallback, three-section structure, version drift, env path, missing env, python version, integrations, NO_COLOR, unknown-flag |

- **Coverage gaps (backfill targets for K.h):**
  - **Project section under config-without-`pyve_version`** (legacy project)
    ([pyve.sh:2081-2082](../../pyve.sh#L2081-L2082)) — covered by `test_status.bats:127`?
    Yes, "shows recorded pyve version" + the no-record path is in the
    "version drift" test. Looks adequate.
  - **Micromamba branch full coverage** — `test_status.bats` is heavy on
    the venv branch; the micromamba `_status_env_micromamba` path
    ([pyve.sh:2193](../../pyve.sh#L2193)) has limited coverage. Backfill: synthetic
    fixture project with `.pyve/config` set to micromamba + asserted output
    rows.
  - **Stale `conda-lock.yml` row** ([pyve.sh:2229-2233](../../pyve.sh#L2229-L2233)) — verified
    via `is_lock_file_stale`; integration test in `test_lock_command.py`
    covers the helper but not the `pyve status` rendering of it.

- **Extraction notes (for K.h):**
  - All status_* helpers are status-private; clean move to
    `lib/commands/status.sh`. Adopt `_status_` prefix (already prefixed).
  - Pure read-only command — extraction risk is the lowest among the
    medium-sized commands.

---

### `lock`

- **Dispatcher entry:** [pyve.sh:3322-3325](../../pyve.sh#L3322-L3325).
- **Implementation:** [pyve.sh:2697-2804](../../pyve.sh#L2697-L2804) (~108 lines, single
  function `run_lock`).

  Note: the function is named `run_lock` (not `lock_command`) — minor naming
  inconsistency relative to peers. **K.c decision point:** rename to `lock` or
  keep `run_lock` as `_lock_main` private helper? Recommend renaming to `lock`
  in K.c (matches the dispatch arm name and the per-command file name); the
  rename is a one-line dispatcher edit + function-definition edit.

- **Inputs:**
  - **Positional:** none (errors out).
  - **Flags:** `--check` (mtime-only verification).
- **Env vars:** none direct.

- **Outputs:**
  - **stdout:** progress, conda-lock output (filtered to drop "conda-lock
    install" misleading post-run message), `✓` ticks.
  - **stderr:** `log_error` on guard failures, conda-lock's own stderr in
    `--check` failure paths.
  - **Exit codes:** 0 (success / `--check` passes), 1 (guards fail or
    `--check` finds stale/missing lock).

- **Side effects:** writes/updates `conda-lock.yml`. Otherwise read-only.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `config_file_exists`, `read_config_value`.
  - `lib/micromamba_env.sh`: `get_conda_platform`, `is_lock_file_stale`.
  - `lib/ui.sh`: (none — uses raw `printf` and `log_*`).

- **Cross-command helpers called from pyve.sh:** none.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/integration/test_lock_command.py | 12 | guards (venv-backend, missing env.yml, missing conda-lock binary), end-to-end happy path, "already up to date" detection, output filtering, success message, `--check` flag (3 tests) |
  | tests/unit/test_lock_validation.bats | 37 | `validate_lock_file_status` (called by `init`, not `lock`) — adjacent coverage |

- **Coverage gaps (backfill targets for K.c):**
  - **Platform detection failure** (e.g., on an unrecognized OS/arch combo)
    — `get_conda_platform` is tested in `test_micromamba_core.bats` directly.
    No `pyve lock` integration test exercises a synthetic platform-detection
    failure. Low priority (the helper rarely fails in practice).
  - **Output filtering specifically** — `test_lock_command.py:138` asserts
    the misleading-install-message is filtered. Looks adequate.

- **Extraction notes (for K.c):**
  - Rename `run_lock` → `lock` during extraction (see above).
  - Update tech-spec.md annotation: drop "moves to `lib/commands/lock.sh` as
    part of the command-module extraction phase" since K.c is that phase.

---

### `run`

- **Dispatcher entry:** [pyve.sh:3310-3313](../../pyve.sh#L3310-L3313).
- **Implementation:** [pyve.sh:1925-2011](../../pyve.sh#L1925-L2011) (~87 lines, single
  function `run_command`).

  Smallest top-level command. K.b's first-mover position validates the
  per-command extraction pattern.

- **Inputs:**
  - **Positional:** `<command> [args...]` (everything after `run` is the
    target command).
  - **Flags:** none (passed through to the target command).
- **Env vars:**
  - **Read:** `PYVE_NO_ASDF_COMPAT` (via `is_asdf_active`).
  - **Set/exported:** `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` when asdf is
    active (Story J.c — defense-in-depth for `--no-direnv` / CI flows).
    Also exports `VIRTUAL_ENV` and modifies `PATH` for the venv backend's
    "fallback to $PATH lookup" branch.

- **Outputs:**
  - **stdout/stderr:** target command's output, unmodified (since this
    `exec`s into the target).
  - **Exit code:** target command's exit code (propagated via `exec`).

- **Side effects:** none beyond the target command's own.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/env_detect.sh`: `source_shell_profiles`, `detect_version_manager`,
    `is_asdf_active`.
  - `lib/micromamba_core.sh`: `get_micromamba_path`.
  - `lib/utils.sh`: `log_error`.

- **Cross-command helpers called from pyve.sh:** none.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/integration/test_run_command.py | 23 | venv (8 tests) + micromamba (5 tests) + parametrized (3 tests) + edge cases (6 tests) |
  | tests/unit/test_asdf_compat.bats | 3 (J.c subset) | `run_command` exports `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM` |

- **Coverage gaps (backfill targets for K.b):**
  - Coverage is strong (FR-J2 was the most-recently-tightened invariant on
    `run`). Spot-check: assertion that `pyve run` with no args prints usage
    and exits 1 — `test_run_command.py:356` covers this. ✓
  - **Backend-not-found exit message** — `test_run_command.py:124` and
    `test_run_command.py:194` cover both backends. ✓
  - No identifiable gaps.

- **Extraction notes (for K.b — pattern-establishing extraction):**
  - F-1: update `install_self`'s lib copy to also handle `lib/commands/`.
  - F-2: update `test_bash32_compat.bats` SOURCES to include
    `lib/commands/*.sh`.
  - F-3: update `source_pyve_fn` to take an optional file path arg, then
    update the J.c test callsites to pass `"$PYVE_ROOT/lib/commands/run.sh"`.
  - K.b is also the right time to **add the file-header license block**
    convention to `lib/commands/run.sh` and **add the direct-execution
    guard** (per K.b task list). The guard pattern that the rest of K.c–K.l
    will copy-paste:
    ```bash
    # If sourced, do nothing. If executed directly, error out.
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
        exit 1
    fi
    ```

---

### `test`

- **Dispatcher entry:** [pyve.sh:3318-3321](../../pyve.sh#L3318-L3321).
- **Implementation:** [pyve.sh:1409-1440](../../pyve.sh#L1409-L1440) (~32 lines, single
  function `test_command`).

  Calls `ensure_testenv_exists` and (after F-8) extracts pytest-management
  helpers as test-private.

- **Inputs:**
  - **Positional:** any args, passed through to pytest.
  - **Flags:** none own; pytest flags pass through.
- **Env vars:**
  - **Read:** `CI`, `PYVE_TEST_AUTO_INSTALL_PYTEST` (via
    `PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT` cached at top of `pyve.sh`).
  - **Set/exported:** none direct (pytest may set its own).

- **Outputs:**
  - **stdout/stderr:** pytest's output, unmodified (`exec`s into pytest).
  - **stdin:** if not in CI / not auto-install mode and stdin is a TTY,
    prompts y/N for pytest install.
  - **Exit code:** pytest's exit code (or 1 if user declines pytest install
    in interactive mode).

- **Side effects:**
  - Creates `.pyve/testenv/venv/` if missing (via `ensure_testenv_exists`).
  - Installs pytest into the testenv on first run (or on requirements-dev.txt
    presence).

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `log_info`, `log_error`.
  - `lib/ui.sh`: `run_cmd` (via `install_pytest_into_testenv`).

- **Cross-command helpers called from pyve.sh:**
  - `ensure_testenv_exists` (F-8) — moves to `lib/utils.sh` in K.g, so
    K.f's `test_command` calls it via the shared helper.
  - `testenv_has_pytest`, `install_pytest_into_testenv` (F-8) — both
    test-private; move with `test_command` to `lib/commands/test.sh` in K.f
    and adopt the `_test_` prefix.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/integration/test_testenv.py | 6 | testenv creation + survival under `init --force`; `pyve test` is invoked indirectly via `pyve_run` |

  Direct coverage of `pyve test` is thin — most exercise of `test_command` is
  through the test harness's `PYVE_TEST_AUTO_INSTALL_PYTEST=1` default
  invoking it as a side-effect of running the test suite under itself.

- **Coverage gaps (backfill targets for K.f):**
  - **CI auto-install path** ([pyve.sh:1414-1419](../../pyve.sh#L1414-L1419)) — exercised
    implicitly by the test harness but no direct integration test.
  - **TTY-interactive prompt — accept** ([pyve.sh:1424-1426](../../pyve.sh#L1424-L1426)) — no
    test sends `y\n` and asserts the install runs.
  - **TTY-interactive prompt — decline** ([pyve.sh:1427-1429](../../pyve.sh#L1427-L1429)) —
    no test sends `n\n` and asserts exit 1 with the right message.
  - **Non-TTY without auto-install** ([pyve.sh:1430-1435](../../pyve.sh#L1430-L1435)) — no
    test exercises this branch.
  - **Pytest args pass-through** — covered indirectly by the harness; cheap
    to add a direct test (`pyve test --co tests/unit/test_version.bats` →
    expect collection-only output).
  - **Exit-code propagation** — same; cheap to add.

  K.f's task list ("backfill characterization tests: pytest-present,
  pytest-missing-and-prompted, pytest-missing-and-CI, args pass-through,
  exit-code propagation") covers all five gaps. They are real gaps, not
  redundant work.

- **Extraction notes (for K.f):**
  - F-8 supersedes the K.f story's "Temporary cross-file call to
    `testenv_run`" caveat — there is no `testenv_run` function in pyve.sh;
    `test_command` reaches into the testenv via direct `exec` of
    `$testenv_venv/bin/python -m pytest`. K.f and K.g are decoupled at the
    function-call level.
  - `testenv_has_pytest` and `install_pytest_into_testenv` move with K.f as
    `_test_has_pytest` and `_test_install_pytest_into_testenv`.

---

### `testenv`

- **Dispatcher entry:** [pyve.sh:3314-3317](../../pyve.sh#L3314-L3317).
- **Implementation:** [pyve.sh:1276-1407](../../pyve.sh#L1276-L1407) (~132 lines, single
  function `testenv_command` containing dispatcher + four leaves inline).

  Per project-essentials F-9 ("Namespace commands are single files"), the
  current shape (one function with a `case "$action" in` block) maps cleanly
  to `lib/commands/testenv.sh` as one file containing the dispatcher and the
  four leaf actions (`init`, `install`, `purge`, `run`) as inline blocks.

  Optional refactor during K.g: split the inline blocks into `testenv_init`,
  `testenv_install`, `testenv_purge`, `testenv_run` functions in the same
  file (matches stories.md K.g task wording). This makes each leaf
  individually addressable and tested without requiring case-block
  juggling.

- **Inputs:**
  - **Positional:** `<action>` ∈ {`init`, `install`, `purge`, `run`}, with
    optional positional args after `run`.
  - **Flags:** `-r` / `--requirements <file>` (install action), `--help`.
- **Env vars:** none direct.

- **Outputs:**
  - **stdout:** for `init`/`install`/`purge` — header/footer box + progress.
    For `run` — exec's into the target, so output is the target's.
  - **stderr:** `log_error` on usage / missing testenv / missing requirements.
  - **Exit codes:** 0 (success), 1 (usage error, missing testenv, missing
    requirements file, or `unknown_flag_error`). For `run`, target's exit
    code via `exec`.

- **Side effects (per action):**
  - **init:** creates `.pyve/testenv/venv/` if missing.
  - **install:** installs pytest (no `-r`) or the requirements file's
    contents into the testenv.
  - **purge:** removes `.pyve/testenv/`.
  - **run:** `exec`s into the testenv's bin (or `$PATH` fallback) with
    `VIRTUAL_ENV` and `PATH` set.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `log_error`.
  - `lib/ui.sh`: `header_box`, `footer_box`, `info`, `success`, `run_cmd`.

- **Cross-command helpers called from pyve.sh:**
  - `ensure_testenv_exists` (F-8) — moves to `lib/utils.sh` in K.g.
  - `purge_testenv_dir` (F-7) — moves to `lib/utils.sh` in K.g.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/integration/test_testenv.py | 6 | `testenv run` (4 tests) + `--force` survival (1) + Python-version-stale rebuild (1) |
  | tests/unit/test_testenv_grammar.bats | 10 | new subcommand grammar (init/install/purge), `--init` legacy form rejected, `-r` accepted, --help, unknown-subcommand, unknown-flag, top-level help mention |
  | tests/unit/test_testenv_ui.bats | 3 | header/footer box wrapping |

- **Coverage gaps (backfill targets for K.g):**
  - **`testenv install` without `-r` and without `requirements-dev.txt`**
    — installs pytest. The path `if [[ -n "$requirements_file" ]]` else
    `pytest` ([pyve.sh:1395-1398](../../pyve.sh#L1395-L1398)) — covered? Verify in
    `test_testenv_grammar.bats:57`. The "routes to install action" test
    asserts dispatch but not the actual install side-effect.
  - **`testenv install -r` with non-existent file** ([pyve.sh:1391-1394](../../pyve.sh#L1391-L1394))
    — error path. Likely covered; verify.
  - **`testenv run` with command missing from PATH** ([pyve.sh:1372-1374](../../pyve.sh#L1372-L1374))
    — falls back to `exec "$cmd"` after `PATH` mutation. Edge case,
    interesting to verify.
  - **`testenv purge` when `.pyve/testenv/` doesn't exist** — coverage
    likely via the indirect path; explicit assertion would close the gap.

- **Extraction notes (for K.g):**
  - Decide on the optional refactor (inline `case` arms vs. four
    `testenv_<action>` functions). Recommendation: refactor to four
    functions for better testability. Cost: ~40 lines of structural
    changes, no behavior change.
  - F-7 and F-8 helper moves happen as part of K.g (first extraction
    needing those helpers cross-file).
  - The K.g story note about "K.f's `test` command now calling into
    `lib/commands/testenv.sh`" is incorrect (F-8) — `test_command` does not
    call any `testenv_*` function. The note should be updated when K.f is
    written (or removed from K.g's verification step).

---

### `python`

- **Dispatcher entry:** [pyve.sh:3292-3303](../../pyve.sh#L3292-L3303).
- **Implementation:** [pyve.sh:1542-1572](../../pyve.sh#L1542-L1572) (`python_command`,
  ~31 lines), plus two leaf functions:
  - `set_python_version_only` ([pyve.sh:1475](../../pyve.sh#L1475))
  - `show_python_version` ([pyve.sh:1518](../../pyve.sh#L1518))

  All three are python-namespace-private (single caller chain). Smallest
  namespace command — K.d validates the namespace single-file convention.

- **Inputs:**
  - **Positional:** `<sub>` ∈ {`set`, `show`}; `<version>` for `set`.
  - **Flags:** `--help`.
- **Env vars:** none direct.

- **Outputs:**
  - **stdout (`set`):** header/footer box + progress + success.
  - **stdout (`show`):** `Python <ver> (from <source>)` or "not pinned" message.
  - **stderr:** `log_error` on validation / missing-version-arg / unknown-sub.
  - **Exit codes:** 0 (success or "not pinned"), 1 (validation/usage error).

- **Side effects (`set` only):** writes `.tool-versions` (asdf) or
  `.python-version` (pyenv).

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `validate_python_version`, `read_config_value`.
  - `lib/env_detect.sh`: `source_shell_profiles`, `detect_version_manager`,
    `ensure_python_version_installed`, `set_local_python_version`,
    `get_version_file_name`.
  - `lib/ui.sh`: `header_box`, `footer_box`, `banner`, `success`.

- **Cross-command helpers called from pyve.sh:** none.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/unit/test_python_command.bats | 16 | help, dispatch, missing-sub, unknown-sub, set-no-version, set-invalid-format, set-non-numeric, show-not-pinned, show-from-tool-versions, show-from-python-version, show-prefers-tool-versions, legacy `python-version` removed |
  | tests/unit/test_python_ui.bats | 2 | header/footer box wrapping |

- **Coverage gaps (backfill targets for K.d):**
  - **`pyve python set <ver>` happy path** — installs the Python version
    via the version manager. `test_python_command.bats` covers validation
    failures but no test asserts a successful set with side effect (`.tool-
    versions` write). Add one (cheap, given the fixture infrastructure).
  - **`pyve python show` from `.pyve/config`** ([pyve.sh:1527-1528](../../pyve.sh#L1527-L1528))
    — fallback when neither version file exists but `.pyve/config` has
    `python.version`. Currently no test.
  - **`pyve python show` with extra args** ([pyve.sh:1559-1562](../../pyve.sh#L1559-L1562)) —
    error path. No direct test.

- **Extraction notes (for K.d):**
  - Single-file move per project-essentials. `python_command` becomes the
    dispatcher; `set_python_version_only` and `show_python_version` become
    leaves in the same file.
  - Optional rename: `set_python_version_only` → `python_set` and
    `show_python_version` → `python_show` (matches the leaf-function
    convention from project-essentials F-9, line 123). Cost: trivial; the
    only callers are inside `python_command`. Recommendation: rename.

---

### `self`

- **Dispatcher entry:** [pyve.sh:3304-3307](../../pyve.sh#L3304-L3307).
- **Implementation:** [pyve.sh:3148-3189](../../pyve.sh#L3148-L3189) (`self_command`,
  ~42 lines for the dispatcher), plus two leaf functions and four helpers:
  - `install_self` ([pyve.sh:1578](../../pyve.sh#L1578))
  - `install_update_path` ([pyve.sh:1677](../../pyve.sh#L1677)) — install-private.
  - `install_prompt_hook` ([pyve.sh:1705](../../pyve.sh#L1705)) — self-private (F-5).
  - `install_local_env_template` ([pyve.sh:1780](../../pyve.sh#L1780)) — install-private.
  - `uninstall_self` ([pyve.sh:1799](../../pyve.sh#L1799))
  - `uninstall_project_guide_completion` ([pyve.sh:1859](../../pyve.sh#L1859)) — uninstall-private.
  - `uninstall_clean_path` ([pyve.sh:1873](../../pyve.sh#L1873)) — uninstall-private.
  - `uninstall_prompt_hook` ([pyve.sh:1895](../../pyve.sh#L1895)) — self-private (F-5).

  All eight are self-namespace-private — they move into
  `lib/commands/self.sh` as a single file per project-essentials.

- **Inputs:**
  - **Positional:** `<sub>` ∈ {`install`, `uninstall`}.
  - **Flags:** `--help`.
- **Env vars (read):** `ZSH_VERSION`, `BASH_VERSION`, `SHELL` (for shell
  detection).

- **Outputs:**
  - **stdout:** progress + success ticks; final activation hint block.
  - **stderr:** none in normal operation.
  - **Exit codes:** 0 (success or Homebrew skip), 1 (re-install with missing
    source dir).

- **Side effects:**
  - **install:** writes `~/.local/bin/pyve.sh`, `~/.local/bin/pyve` symlink,
    `~/.local/bin/lib/*.sh`, `~/.local/bin/lib/completion/*`,
    `~/.local/.pyve_source`, `~/.local/.pyve_prompt.sh`, `~/.local/.env`.
    Adds PATH line to `~/.zprofile` or `~/.bash_profile`. Adds prompt-hook
    source line to `~/.zshrc` or `~/.bashrc` (via SDKMan-aware insertion).
  - **uninstall:** removes all of the above (preserving non-empty
    `~/.local/.env`). Removes project-guide completion block from
    `~/.zshrc` and `~/.bashrc`.

- **Cross-command helpers called (stay in `lib/<topic>.sh`):**
  - `lib/utils.sh`: `is_file_empty`, `detect_install_source`,
    `is_project_guide_completion_present`, `remove_project_guide_completion`,
    `insert_text_before_sdkman_marker_or_append`.

- **Cross-command helpers called from pyve.sh:** none.

- **Existing test coverage:**

  | Test file | Tests | Notes |
  |---|---:|---|
  | tests/unit/test_cli_dispatch.bats | 4 (subset) | dispatcher routing for `self install` / `self uninstall` / `self` (no-arg) / `self --help` |
  | tests/unit/test_subcommand_help.bats | partial | `self install --help` / `self uninstall --help` byte stability |
  | tests/unit/test_project_guide.bats | 71 (subset) | `install_prompt_hook` / `uninstall_prompt_hook` rc-file handling, project-guide completion add/remove (heavily tested via sentinel-block helpers) |
  | tests/integration/test_project_guide_integration.py | 15 (mention) | end-to-end install/uninstall with project-guide completion |

  Coverage of the actual `install_self` / `uninstall_self` happy path is
  **modest** — most tests target the helpers
  (`install_prompt_hook`, sentinel-block helpers) rather than asserting the
  full `pyve self install` end-to-end behavior. This makes K.e a higher-risk
  extraction than its size suggests.

- **Coverage gaps (backfill targets for K.e):**
  - **End-to-end `pyve self install` round-trip** — install, assert files
    exist + PATH line added, then uninstall, assert files removed + PATH
    line removed. Needs an integration test using `tmp_path` and
    `monkeypatch.setenv("HOME", ...)`. Currently absent.
  - **Idempotency** — re-install over an existing install should not
    duplicate PATH lines or prompt-hook source lines. The
    "remove-existing-line-then-insert" pattern at
    [pyve.sh:1769-1775](../../pyve.sh#L1769-L1775) implements this; not directly tested.
  - **Homebrew detection short-circuit** — `detect_install_source` returns
    `homebrew` and both functions exit 0 with a brew-specific message.
    `test_doctor.bats:103` covers the helper directly; a `pyve self install`
    integration test under a synthetic Homebrew prefix would close the gap.
  - **`uninstall_self` preserving non-empty `~/.local/.env`** ([pyve.sh:1829-1836](../../pyve.sh#L1829-L1836))
    — partial coverage; backfill explicit.

  K.e's "backfill characterization tests" task should target these five
  gaps specifically.

- **Extraction notes (for K.e):**
  - F-5: `install_prompt_hook` and `uninstall_prompt_hook` are **self-private**,
    not init-private. They move with K.e to `lib/commands/self.sh` as
    `_self_install_prompt_hook` and `_self_uninstall_prompt_hook`. The K.e
    story task "Decide and document `install_prompt_hook` placement: if
    called only by init, becomes `_init_install_prompt_hook` (moves with
    K.l); if called by `self_install` too, stays in `lib/utils.sh` as a
    cross-command helper" is now resolved: **called only by self_install
    and uninstall_self → self-private**. Update the K.e story to reflect
    F-5.
  - All 8 self_* and *_self functions move together. None stay in pyve.sh,
    and none move to `lib/utils.sh`.
  - Rename suggestions for clarity (optional, K.e-discretionary):
    `install_self` → `self_install`, `uninstall_self` → `self_uninstall`,
    matching the dispatcher arm names. The current `*_self` form is
    historical (pre-namespace) and inverted relative to peers
    (`testenv_init`, etc.).

---

## Summary table — extraction order and key risks

| K story | Command | Lines moved | Coverage strength | Key risks |
|---|---|---:|---|---|
| K.b | `run` | ~90 | Strong (J.c hardened) | F-1, F-2, F-3 — pattern-establishing fixes |
| K.c | `lock` | ~110 | Strong | Decide `run_lock` → `lock` rename |
| K.d | `python` | ~150 | Moderate | Single-file namespace pattern; optional `set`/`show` rename |
| K.e | `self` | ~370 | **Modest** | F-5 placement + e2e backfill |
| K.f | `test` | ~35 | Modest | F-8: drops "temporary cross-file call" caveat |
| K.g | `testenv` | ~135 | Moderate | F-7, F-8 helper moves; optional 4-leaf refactor |
| K.h | `status` | ~280 | Strong | None — read-only, lowest risk |
| K.i | `check` | ~265 | Strong | Preserve closure-via-dynamic-scoping pattern |
| K.j | `update` | ~100 | Strong | Self-contained — no helper-placement decisions |
| K.k | `purge` | ~155 | Moderate | F-7 already done by K.g; .gitignore idempotency invariant |
| K.l | `init` | ~870 | Strongest | F-3, F-4 cleanup; F-10 init-private rename |

**Total lines moved out of `pyve.sh`:** ~2,560 of 3,363. Remaining: ~800 for
globals, sourcing, universal flags, dispatcher, `legacy_flag_error`,
`unknown_flag_error`, `main`, plus the 8 `show_*_help()` blocks (kept per
F-9). Adding `source lib/commands/<name>.sh` lines (~11) and headers brings
the dispatcher file close to the 200–350 target with the help blocks
remaining in place; if K.m wants to push closer to 200, the help blocks are
the next candidate to move (each into its respective command file).

---

## Stories.md correction list

The audit surfaces three places where the K stories' story text is
inconsistent with HEAD reality. These are documentation hygiene fixes the
relevant K story should make as it lands, not separate stories:

1. **K.e story** ([stories.md:166-178](stories.md#L166-L178)): the
   "Decide and document `install_prompt_hook` placement" task is resolved by
   F-5 — placement is **self-private**. Update task wording.
2. **K.f story** ([stories.md:182-194](stories.md#L182-L194)): the "Temporary
   cross-file call to `testenv_run` (still in `pyve.sh`); resolves on K.g"
   note is incorrect (F-8) — `test_command` does not call `testenv_run`;
   `testenv_run` is not a top-level function. Drop the caveat.
3. **K.g story** ([stories.md:198-209](stories.md#L198-L209)): the "K.f's
   `test` command now calling into `lib/commands/testenv.sh`" verification
   step is also incorrect (F-8). Replace with verification that
   `_test_has_pytest` and `_test_install_pytest_into_testenv` resolve from
   `lib/commands/test.sh`.
