# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.6.2] - 2026-05-07

**Hotfix (test-infra).** `ubuntu-latest` GitHub Actions CI failed `pyve_write_sitecustomize_shim: no-op when shim already matches desired content` after v2.6.1 shipped. Pre-existing fragility (the test was added in v2.2.1) that didn't surface until Phase L's CI matrix exercised the Ubuntu side reliably.

### Fixed (test-infra)

- **`test_distutils_shim_coverage.bats` mtime check broke on Linux CI** (Story L.o) — the "no-op when shim already matches desired content" test read the file's mtime via `stat -f %m FILE 2>/dev/null || stat -c %Y FILE`, intending BSD-first with a GNU fallback. macOS works (BSD stat's `-c` exits 1 and the fallback fires), but Linux silently broke once GNU coreutils 9.0+ added `%m` as "Mountpoint" in filesystem-status mode (`-f`) — `stat -f %m FILE` exits 0 with a mountpoint string instead of an mtime, and the GNU fallback never fires. Fix: GNU-first ordering — `stat -c %Y` returns the real mtime on Linux, and macOS BSD stat's `-c` cleanly exits 1 so the BSD fallback still fires there.

## [2.6.1] - 2026-05-07

**Hotfix.** Interactive `pyve init` backend prompt rejected the user's selection with `✘ Unexpected backend choice index: 0|1` and exited.

### Fixed

- **`tput civis` / `tput cnorm` escape leakage in `lib/ui/select.sh`** (Story L.n) — both `_ui_select_tty` and `_ui_multi_select_tty` ran `tput` with stdout undirected. When `ui_select` was captured via `$(ui_select ...)` (the wizard's normal call shape), the cursor-hide / cursor-show escape sequences got captured and prepended to the numeric index. The wizard's `case "$choice_idx" in 0) ... 1) ... esac` then fell to the catch-all because `$choice_idx` was actually `<esc-seq>0` / `<esc-seq>1`, not the bare digit. Both `tput` calls (8 sites total across the two TTY helpers) now redirect to `>&2`; the terminal still sees the escape sequences via stderr (same TTY in interactive use), but stdout stays clean for capture. A regression test in [tests/unit/test_ui_select.bats](tests/unit/test_ui_select.bats) greps the source file for any `tput civis|cnorm` line lacking `>&2` so a future contributor adding an unredirected call breaks the build immediately.

## [2.6.0] - 2026-05-07

**Phase L — Pyve Polish.** UX overhaul: `pyve init` (both backends) and `pyve update` now deliver a `sv create`-grade scaffolding experience. Every `pyve init` invocation runs through an interactive wizard with smart defaults from repo signals; subprocess output is quiet on the happy path with `--verbose` opt-in for live streaming; long-running steps render with a step counter; init ends with a single coherent "Next steps:" summary. Plus diagnostic-correctness fixes (`pyve status` Python pin, `pyve check --help` reconciliation) and the `lib/ui/` library extraction (the boundary of an eventually-extractable bash UX library). Skips v2.5.x — Phase L stories accumulated on the phase branch without per-story bumps and ship as one minor release.

See [docs/specs/phase-l-pyve-polish-plan.md](docs/specs/phase-l-pyve-polish-plan.md) for the phase plan and acceptance criteria, and [docs/specs/phase-l-pyve-polish-audit.md](docs/specs/phase-l-pyve-polish-audit.md) for the L.a audit (Diagnostic Surface / Project-Guide Integration / Terminal UX) that drove each follow-up story.

### Added

- **Interactive `pyve init` wizard** (Stories L.k.1–L.k.7). `pyve init` now opens with a welcome banner and walks the user through three prompts in fixed order: **backend → Python version pin → project-guide install**. The wizard always runs; flags suppress only the *interactive* part of individual prompts and render the flag-resolved value in the flow, so the user sees what's about to happen even on fully flag-driven invocations.
  - **Backend prompt** — defaults driven by repo signals (`environment.yml` → micromamba; `.python-version`/`.tool-versions` → venv; else venv). `--backend auto` is treated as the auto-detect path. `--backend <type>` skips interactive selection and renders the resolved value.
  - **Python version pin prompt** — backend-aware. `venv` branch: version-manager picker (asdf default; auto-pick when only one is installed; hard-fail when neither is installed AND a pin is requested), then "pick from installed" via `asdf list python` / `pyenv versions --bare` filtered to `^3\.`, with a final `more...` option that re-prompts with the full available list (`asdf list all python` / `pyenv install --list`). `micromamba` branch: env.yml-aware — managed-via-env.yml when present; flag/default version baked into the scaffolded env.yml when absent.
  - **project-guide install prompt** — detection-keyed on `.project-guide.yml` (the canonical install marker). Already present → render "refresh (already installed)" and let the post-env hook run `project-guide update` (the safe refresh path). Declared as a project dependency → render "managed by your project dependencies" and defer entirely to the user's deps. Otherwise → prompt with default no, or in non-TTY mode defer to the existing env-var / CI-default / interactive-fallback logic in `_init_run_project_guide_hooks`.
  - **TTY policy** — wizard hard-fails when stdin is not a TTY AND at least one prompt would read stdin AND `PYVE_INIT_NONINTERACTIVE` is not `1`. Error names the missing flags as the non-interactive path.
  - **`PYVE_INIT_NONINTERACTIVE=1`** — new env var that bypasses the wizard's TTY guard. Mirrors the existing `PYVE_FORCE_YES` / `CI=1` pattern but specific to the wizard. Set by default in the bats and pytest test harnesses.
- **Verbosity policy** (Story L.f) — `--verbose` (parsed pre-subcommand) and `PYVE_VERBOSE=1` (env var) are equivalent. Quiet by default. Every UI primitive consults `is_verbose()` in `lib/ui/core.sh` rather than re-implementing the env-var check.
- **`lib/ui/` library** (Story L.e) — `lib/ui.sh` migrated to `lib/ui/core.sh` and grew sibling modules: `lib/ui/run.sh` (`run_quiet` quiet-replay-on-failure subprocess wrapper, Story L.g), `lib/ui/progress.sh` (step counters + spinner + progress bar, Story L.h), `lib/ui/select.sh` (arrow-key single/multi-select prompts with TTY fallback, Story L.i). Modules under `lib/ui/` stay pyve-agnostic — the boundary is the eventual extraction point for a standalone bash UX library.
- **End-of-init "Next steps:" summary** (Story L.l) — `pyve init` now ends with a single numbered block replacing the per-backend ad-hoc trailing lines. Conditional items: `direnv allow` (or `pyve run <command>` under `--no-direnv`), `pyve testenv install -r requirements-dev.txt` (when `requirements-dev.txt` exists), `Read docs/project-guide/go.md` (when `.project-guide.yml` exists). Trailing micromamba+direnv caveat preserved.

### Changed

- **`pyve update` step framing** (Story L.j) — replaced ad-hoc `log_info` chatter with `step_begin "[N/4] ..."` / `step_end_ok` / `step_end_fail` framing across all four steps (`pyve_version` bump, `.gitignore` refresh, `.vscode/settings.json` refresh, project-guide refresh). Wrapped with `header_box` / `footer_box`. Each conditional skip path emits its own labeled step.
- **`pyve update` and `pyve init --force`** — embedded `project-guide` invocations now pass `--quiet` alongside `--no-input` (Story L.d). Requires `project-guide >= 2.5.0`. Pip's per-package progress is captured and discarded on success, replayed on failure.
- **`pyve status`** — micromamba projects now read the Python pin from `environment.yml` (`- python=<spec>` line, regex-grep tolerant of whitespace and a trailing `.*` glob) instead of falsely reporting "Python: not pinned" (Story L.b, audit T1-01).
- **`pyve check --help`** — reconciled with shipped diagnostics (Story L.c, audit T1-02). Dropped the "(coming in a later release)" parenthetical from the `pyve status` reference; replaced misleading `pyve doctor` / `pyve validate` See-also entries (which hard-error post-v2.0) with a single `pyve status` entry.

### Fixed

- **bash 3.2 empty-array under `set -u`** (Story L.k.7) — `_init_detect_version_managers_available` in `lib/commands/init.sh` now uses `"${available[*]:-}"` instead of `"${available[*]}"`. Without the `:-` default, `pyve init` would crash on macOS bash 3.2 with `available[*]: unbound variable` whenever neither `asdf` nor `pyenv` was on PATH (e.g. CI runners with neither installed).
- **`pyve init --backend auto` resolution in the wizard** (Story L.k.7) — the wizard now resolves `auto` to a concrete backend (via `_init_detect_backend_default`) before downstream prompts branch on it. Without this, the Python prompt fell to the venv branch even when `environment.yml` clearly indicated micromamba, hard-failing on no managers.
- **Wizard's project-guide block over-resolved cases the post-env hook owns** (Story L.k.7) — the deps-managed and non-flag-no-signal branches no longer pre-set `project_guide_mode="no"`. The wizard renders a one-line summary; the post-env `_init_run_project_guide_hooks` retains its detailed deps-managed message and its CI-default-install behavior.

### Documentation

- **`docs/specs/project-essentials.md`** — appended four new invariants surfaced during Phase L: `lib/ui/` extractable boundary + verbosity gate (firm), bash 3.2 empty-array contract (unanticipated, from L.k.7), `.project-guide.yml` as canonical project-guide install marker (unanticipated, from L.k.5/L.k.6).
- **`docs/specs/features.md`** — new FR-1a "Interactive `pyve init` wizard" subsection documenting prompt set, default-resolution rules, flag-override behavior, TTY policy, bypass env var, out-of-scope flags. New FR-1b "End-of-init Next steps summary" with the precondition table.
- **`docs/specs/tech-spec.md`** — new "Interactive `pyve init` wizard" subsection between Modifier Flags and Exit Codes. Documents the venv/micromamba split for the Python pin and the deps-vs-install-marker precedence for project-guide.

## [2.4.0] - 2026-04-27

**Phase K — Break the Pyve Monolith.** Pure-refactor release: all 11 top-level commands extracted from `pyve.sh` into per-command modules under `lib/commands/<name>.sh`. `pyve.sh` shrunk from 3,363 lines to **595 lines** (−2,768, ~82% reduction). The user-facing CLI surface is byte-identical to v2.3.2 — every command, flag, env var, exit code, and output line is preserved.

See [docs/specs/phase-k-break-the-pyve-monolith-plan.md](docs/specs/phase-k-break-the-pyve-monolith-plan.md) for the full gap analysis and architectural target, and [docs/specs/phase-K-command-coverage-audit.md](docs/specs/phase-K-command-coverage-audit.md) for the K.a.3 audit findings (F-1 through F-11) that informed each extraction story.

### Added

- **`lib/commands/<name>.sh`** — eleven new per-command modules:
  - [lib/commands/run.sh](lib/commands/run.sh) (K.b — 108 lines)
  - [lib/commands/lock.sh](lib/commands/lock.sh) (K.c — 137 lines)
  - [lib/commands/python.sh](lib/commands/python.sh) (K.d — 153 lines)
  - [lib/commands/self.sh](lib/commands/self.sh) (K.e — 515 lines)
  - [lib/commands/test.sh](lib/commands/test.sh) (K.f — 95 lines)
  - [lib/commands/testenv.sh](lib/commands/testenv.sh) (K.g — 214 lines)
  - [lib/commands/status.sh](lib/commands/status.sh) (K.h — 327 lines)
  - [lib/commands/check.sh](lib/commands/check.sh) (K.i — 342 lines)
  - [lib/commands/update.sh](lib/commands/update.sh) (K.j — 166 lines)
  - [lib/commands/purge.sh](lib/commands/purge.sh) (K.k — 242 lines)
  - [lib/commands/init.sh](lib/commands/init.sh) (K.l — 877 lines)

  Each file carries the Apache-2.0 header, a direct-execution guard, the orchestrator function, all command-private helpers (with `_<command>_` prefix per project-essentials F), and the `show_<cmd>_help` block (moved from `pyve.sh` in K.l).

- **Function naming convention** (project-essentials, post-K.f follow-up). Top-level command functions are named `<verb>_<operand>` where the operand describes what the verb operates on, taken from the position immediately after the verb in the user's CLI invocation: `init_project`, `purge_project`, `update_project`, `check_environment`, `show_status`, `lock_environment`, `run_command`, `test_tests`, `python_command`, `self_command`, `testenv_command`. Naturally avoids the F-11 binary/builtin shadowing trap (`python`, `test`).

- **Function-name collision rule** (F-11, project-essentials). Discovered when K.d's initial rename `python_command` → `python` shipped a CI-breaking regression: bash function names take precedence over external binaries, so a function `python()` shadowed the `python` interpreter at every internal call site (`python -m venv`, `python -c`). Rule: never rename a command function to a name that is (a) an external binary pyve invokes internally, or (b) a bash builtin. `python_command` and `test_command` keep their `_command` suffix accordingly.

- **F-7/F-8 helper moves to `lib/utils.sh`** — three shared helpers moved out of `pyve.sh` because they're called from 2+ commands: `testenv_paths`, `ensure_testenv_exists`, `purge_testenv_dir`.

### Changed

- **`pyve.sh` is now a thin dispatcher** (~595 lines). Owns: shebang/license, process-wide globals, library + per-command sourcing block, universal flags (`--help`/`-v`/`-c`), `case`-block dispatcher, `legacy_flag_error` / `unknown_flag_error`, `main()`. Does NOT own: command implementations or per-command help blocks.

- **Per-command help blocks moved** (K.l) — `show_init_help`, `show_purge_help`, `show_status_help`, `show_check_help`, `show_update_help`, `show_python_help`, `show_self_help`, `show_self_install_help`, `show_self_uninstall_help` now live in their respective `lib/commands/*.sh` files. The dispatcher in `pyve.sh` continues to call them by name; bash resolves them through the global function table at call time, so the location move is transparent to users.

- **`pyve self install` glob fix** (K.b — F-1): `cp "$source_dir/lib/"*.sh` is non-recursive; added an explicit `cp "$source_dir/lib/commands/"*.sh` step so installations from a non-Homebrew source pick up the per-command modules.

- **`tests/unit/test_bash32_compat.bats` SOURCES array** (K.b — F-2): now also scans `lib/commands/*.sh` for forbidden bash 4+ constructs (`declare -A`, `mapfile`, etc.).

- **`source_pyve_fn` test helper** (K.b — F-3): now takes an optional second argument (the source file path), defaulting to `$PYVE_ROOT/pyve.sh`. The J.b/J.c asdf-compat tests use it to extract function bodies from `lib/commands/init.sh` (`_init_direnv_venv`, `_init_direnv_micromamba`) and `lib/commands/run.sh` (`run_command`).

- **Architectural target** (tech-spec): `pyve.sh` line-count target revised from 200–300 to ~500–650 in K.m. The original target predated full accounting of the explicit-sourcing rule's structural floor (~470 lines minimum even with all per-command code moved).

### Tests

- Bats unit suite: 727 → 729 tests (+2 hermetic backfills in K.d for `pyve python show` config-fallback and extra-args rejection). All 729 passing.
- Integration suite: unchanged baseline; same pre-existing failures as v2.3.2 (tracked in stories.md "Fix pre-existing integration test failures").
- Startup time: `pyve --version` ≈ 10–20ms (well under K.m's 50ms acceptance target; sourcing 19 lib + lib/commands files adds no measurable cost).

### Migration

No user-facing changes. CLI is byte-identical to v2.3.2:

- Every command, flag, exit code, env var, and output line preserved.
- Existing `.pyve/config` files compatible without modification.
- Re-running `pyve self install` post-upgrade picks up the new `lib/commands/` directory automatically (F-1 fix in K.b).

## [2.3.2] - 2026-04-24

Bugfix release (Story K.a.2). After `pyve init --force --backend micromamba` on a previously-venv project, `project-guide` shell completion (and any other completion whose rc-file guard uses `command -v`) silently stopped working. Venv-backed projects were unaffected.

**Root cause**: the micromamba `.envrc` generator wrote a **relative** `ENV_PATH=".pyve/envs/<name>"` then did `export PATH="$ENV_PATH/bin:$PATH"`. Relative entries on `PATH` resolve against the caller's cwd, not the project directory. At `.zshrc` time the shell's cwd is `$HOME`, so the relative entry resolved to `$HOME/.pyve/envs/<name>/bin` — which does not exist. The `command -v project-guide` guard in rc-file completion blocks failed and completion never registered. The venv backend sidestepped this by `source`-ing Python's `activate` script, which bakes an absolute `VIRTUAL_ENV` into PATH.

**Design** — uniform `.envrc` template across backends. Rather than fix micromamba in isolation, both backends now converge on a single four-line shape so the class of bug cannot recur and future backends (uv, poetry, conda) inherit the symmetry:

```bash
PATH_add "<rel_bin_dir>"                          # direnv stdlib: resolves relative → absolute
export <BACKEND_SENTINEL>="$PWD/<rel_env_root>"   # VIRTUAL_ENV (venv) or CONDA_PREFIX (conda-like)
export PYVE_BACKEND="<backend_name>"
export PYVE_ENV_NAME="<env_name>"
export PYVE_PROMPT_PREFIX="(<backend_name>:<env_name>) "
```

`PATH_add` is direnv's canonical primitive for "add a directory to PATH, accept it may be relative to `.envrc`, export the absolute form." Backend-native sentinels (`VIRTUAL_ENV` / `CONDA_PREFIX`) are set explicitly instead of inherited from an activate script, so tools that probe these env vars (pip, poetry, IDEs) keep working. The generated file is project-directory independent — `$PWD` expands at direnv-source time.

### Added

- **`write_envrc_template` helper** in [lib/utils.sh](lib/utils.sh). One shared emitter for the uniform template; `init_direnv_venv` and `init_direnv_micromamba` in [pyve.sh](pyve.sh) are now thin wrappers. Adding a new backend means calling the helper with five args — no new activation machinery.
- **Bats unit tests** at [tests/unit/test_envrc_template.bats](tests/unit/test_envrc_template.bats) (15 tests): template shape, `PATH_add` vs hand-rolled `export PATH=`, backend-native sentinel with `$PWD` prefix, no `source activate`, idempotency, pre-existing `.envrc` preservation, asdf guard composition, project-dir independence.
- **Integration tests** at [tests/integration/test_envrc_template.py](tests/integration/test_envrc_template.py) (6 venv tests + 1 micromamba, module-scoped init fixture): asserts the generated `.envrc` for both backends conforms to the uniform template.

### Changed

- **`init_direnv_venv` and `init_direnv_micromamba`** in [pyve.sh](pyve.sh) are now three-line wrappers around `write_envrc_template`. Zero behavior change for the asdf reshim guard (Story J.b) — the guard still appends via the same sentinel-grep idempotency pattern and still migrates onto pre-existing `.envrc` files.
- **`PYVE_ENV_PATH`** is no longer exported by the micromamba `.envrc`. Unreferenced anywhere in the codebase or tests; the uniform template uses `CONDA_PREFIX` as the canonical sentinel instead.

### Upgrade impact

Low. Re-run `pyve init --force` (or delete `.envrc` and re-run `pyve init`) to regenerate `.envrc` under the new template; `direnv allow` picks it up on the next `cd`. Projects still on v2.3.1 `.envrc` files keep working — they just don't benefit from the fix. The asdf reshim guard migrates onto pre-existing files automatically (Story J.b behavior, preserved).

## [2.3.1] - 2026-04-24

Bugfix release (Story K.a.1). `pyve init --force --backend micromamba --python-version <ver>` on a project with an existing venv config but no `environment.yml` hard-errored with `"Neither 'environment.yml' nor 'conda-lock.yml' found"` — even though the same invocation without `--force` (on a fresh directory) succeeds by scaffolding a starter `environment.yml`. Root cause: the `--force` pre-flight at [pyve.sh:654](pyve.sh#L654) duplicated `validate_lock_file_status` from the main micromamba branch but omitted the `scaffold_starter_environment_yml` call that precedes it; on a directory with neither file, validation's Case 4 fires before scaffolding gets a chance. Fix: invoke `scaffold_starter_environment_yml` before `validate_lock_file_status` in the `--force` pre-flight, mirroring the main-flow ordering. Regression test in [tests/integration/test_force_backend_detection.py](tests/integration/test_force_backend_detection.py).

## [2.3.0] - 2026-04-23

Phase J release: environment compatibility & hardening. Three sub-themes: (1) fix the asdf-reshim bug that made venv-installed CLIs resolve via `~/.asdf/shims/` instead of `.venv/bin/` on direnv-allow; (2) rip the remaining Category A delegate-with-warning paths from Phase H; (3) add a grep-invariant test that catches bash-4+ constructs before they reach CI. All three are "pyve interoperates cleanly with the realities around it."

### Added

- **asdf/direnv coexistence guard** (FR-18, Stories J.a–J.c). When pyve detects asdf as the active version manager, it sets `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` at two layers — the generated `.envrc` (venv + micromamba backends, sentinel-grep idempotent, migrates onto pre-v2.3.0 files) and the `pyve run` dispatcher (silent defense-in-depth for `--no-direnv` / CI). Root cause documented in [docs/specs/pyve-asdf-reshim-bug-brief.md](docs/specs/pyve-asdf-reshim-bug-brief.md), now marked resolved.
- **`PYVE_NO_ASDF_COMPAT` environment variable**. Set to `1` to suppress the asdf reshim guard at both layers. Intended for users who install CLIs globally via `pip install --user` and want asdf's default reshim behavior. `PYVE_ASDF_COMPAT` is reserved for symmetry (no distinct behavior — the default state when asdf is detected).
- **`is_asdf_active()` helper** in [lib/env_detect.sh](lib/env_detect.sh). Single source of truth for the asdf-compat check; both the `.envrc` generator and the `pyve run` dispatcher call it so the opt-out is consistent.
- **bash 3.2 grep-invariant test** at [tests/unit/test_bash32_compat.bats](tests/unit/test_bash32_compat.bats) (Story J.e) — 10 `@test` blocks covering `declare/typeset/local -A`, `mapfile`, `readarray`, case-mod parameter expansions (`${var^^}` family), `${var@[UuLlQqEePpAaKk]}` transform ops, `declare -n` namerefs, named `coproc`, and `shopt -s globstar`. Each block names the bash-3.2-safe alternative in its failure message. Scope excludes `lib/completion/_pyve` (zsh). H.e.7a (`declare -A`) and H.e.9h (`mapfile`) would have been caught by this preemptively.

### Removed (breaking)

- **`pyve testenv --init|--install|--purge` legacy flag forms** (Story J.d). Phase H shipped these as delegate-with-warning paths (the handler would emit a stderr deprecation warning then run the new-form action). v2.3.0 rips the alias-handlers entirely; the forms now fall through to the `unknown_flag_error` path. Use `pyve testenv init|install|purge` instead.
- **`pyve python-version <ver>` legacy subcommand** (Story J.d). Was a delegate-with-warning to `pyve python set <ver>`. Now hits the dispatcher's "Unknown command" arm. Use `pyve python set <ver>` instead.
- **`deprecation_warn` helper** in [lib/ui.sh](lib/ui.sh) plus the supporting `_rename_seen` once-per-key guard and `__DEPRECATION_WARNED_KEYS` state. Zero callers remain after J.d. The Category B `legacy_flag_error` pattern (hard error with targeted hint — e.g. `pyve --validate` → "Use 'pyve check' instead") stays; it's three lines per flag and keeps stale-docs / blog-post / LLM-training invocations helpful.

**Upgrade impact**: low. The removed forms stopped being the canonical spelling in v2.0 (a year ago in project time); the deprecation warning nudged users toward the new forms for a full major-version cycle. If a script still invokes the old forms, it now exits non-zero with a generic unknown-flag / unknown-command message instead of a targeted deprecation-warning-then-succeed. Fix is a one-line sed substitution in the invoking script.

### Changed

- **`.envrc` generator** ([pyve.sh:1071-1086](pyve.sh#L1071-L1086), [pyve.sh:1120-1133](pyve.sh#L1120-L1133)). New sentinel-guarded block runs both on fresh-creation and pre-existing-file paths, so the guard migrates onto `.envrc` files produced by pyve < v2.3.0 without requiring `--force`. One info line fires when the block is appended ("Added asdf reshim guard (set PYVE_NO_ASDF_COMPAT=1 if you install CLIs globally via pip)").
- **`pyve run` dispatcher** ([pyve.sh:2050-2062](pyve.sh#L2050-L2062)). Silently probes the version manager before the backend branches so `is_asdf_active` has input, then `export`s the guard var once before all three exec sites. Silent — no output per invocation.
- **`lib/ui.sh` slimmed down** — 30 lines of `deprecation_warn` + `_rename_seen` + `__DEPRECATION_WARNED_KEYS` removed. The module is now focused on the unified palette + banner helpers + edit-distance helper.
- **Testing Strategy section of `tech-spec.md`** updated with the four new bats files from Phases I and J (`test_env_detect.bats`, `test_distutils_shim_coverage.bats`, `test_asdf_compat.bats`, `test_bash32_compat.bats`).

### Fixed

- **`.envrc` asdf reshim bug root-fix**. Pre-v2.3.0, running `pip install <new-cli>` inside a pyve venv on an asdf system could leave the CLI resolvable only through `~/.asdf/shims/<new-cli>` (which dispatched through asdf instead of executing the venv binary). The new `.envrc` guard prevents the asdf Python plugin from reshimming on every direnv-allow, so venv binaries stay reachable directly. Full repro + root-cause in [docs/specs/pyve-asdf-reshim-bug-brief.md](docs/specs/pyve-asdf-reshim-bug-brief.md).

### Developer notes

- **Test suite**: bats **712 / 712 passing** (was 707 at end of v2.2.1; +10 from J.e, +15 from J.a/b/c, -15 from J.d's test cleanup — net +10). Integration tests unchanged in count; `pyve.run('testenv', '--init')` invocations rewritten to `'init'` across three integration files.
- **Design decisions recorded in Story J.c notes**: `export` chosen over `env VAR=... <cmd>` prefix for the `pyve run` guard (simpler — one export before the branch vs. per-exec wrapping; exec replaces the shell so parent-env pollution is moot). Opt-out is env-var-only (no CLI flag) per FR-18 scope discipline — a flag commits to a permanent surface for a narrow defense-in-depth feature.
- **Design decision recorded in Story J.d notes**: removed alias-handlers fall through to the generic `unknown_flag_error` / `Unknown command` paths rather than being converted to Category B `legacy_flag_error` entries. Tradeoff documented — the generic message is less targeted, but "remove the alias-handling" was the task's literal instruction. If users hit it in practice, a one-line `legacy_flag_error` stanza per form can be added back without re-introducing the deprecation-warning machinery.
- **Pre-existing test-data bugs surfaced during J.d verification**: `test_subcommand_cli.py::TestLegacyFlagCatch` parametrize entries for `--validate` and `--python-version` assert `"pyve validate"` / `"pyve python-version"` as the migration-hint text, but `pyve.sh` has always output `"pyve check"` / `"pyve python set <ver>"` via `legacy_flag_error`. Confirmed pre-existing via `git stash` baseline. Filed as a follow-up test-data cleanup story outside J scope.

### Migration notes

Breaking: the four removed legacy forms (`pyve testenv --init`, `--install`, `--purge`, and `pyve python-version <ver>`) now exit non-zero instead of delegate-with-warning. If a script or CI job calls any of them, swap to the new form:

```sh
# Before (v2.2.x)
pyve testenv --init
pyve testenv --install -r requirements-dev.txt
pyve testenv --purge
pyve python-version 3.13.7

# After (v2.3.0+)
pyve testenv init
pyve testenv install -r requirements-dev.txt
pyve testenv purge
pyve python set 3.13.7
```

No config-file format changes. `pyve --version` reports `2.3.0`. `.envrc` files generated by pyve < v2.3.0 gain the asdf guard on the next `pyve init` (sentinel-grep ensures no duplication).

## [2.2.1] - 2026-04-23

Coverage-hardening patch for Phase I. After v2.2.0 shipped, Codecov surfaced a `lib/` bash-subtotal of **62.44%** — the I.b–I.g test activations weren't reaching the coverage measurement because the `bash-coverage` CI job only ran kcov against the venv-backend integration tests. This release wires the micromamba integration path into kcov, adds direct bats coverage for two previously-untested libraries, and surfaces one latent dead-branch bug along the way. No user-facing CLI changes.

### Fixed

- **`pyve_write_sitecustomize_shim` idempotency short-circuit was unreachable.** The check at `lib/distutils_shim.sh:89-91` used `[[ "$(cat file)" == "$desired" ]]`, but bash command substitution strips trailing newlines while `$desired` always ends in one — so the "no-op when already current" branch never fired, and the file was rewritten with identical content on every call. Fixed with a `cmp`-based comparison. Observable only as unnecessary mtime churn on repeated `pyve init` runs in Python ≥ 3.12 environments, but a real dead branch in kcov. (Story I.k.)

### Changed

- **`bash-coverage` CI job now exercises the micromamba integration path under kcov** (Story I.i). Previously ran only `pytest -m "venv and not requires_micromamba"`; now runs a second kcov pass over `-m "micromamba or requires_micromamba"` with `mamba-org/setup-micromamba@v2` installed just-in-time between the two passes. kcov auto-merges into `coverage-kcov/kcov-merged/`; the existing Codecov upload step picks up the combined data with no config change needed. The `mamba-org` install is deliberately placed **after** the venv kcov pass to keep micromamba off PATH during the venv run — defense against the asdf/pyenv shim leakage that bit v1.13.2 / v1.13.3.
- **`bash-coverage` CI job bumped from Python 3.11 → 3.12** to align with `integration-tests-micromamba` (which uses 3.12) and remove the lone 3.11 holdout among the job matrix. Nothing about kcov required 3.11; it was leftover from before the H.b.i modernization of the integration matrix.

### Added

- **[tests/unit/test_env_detect.bats](tests/unit/test_env_detect.bats)** (Story I.j) — new file, 33 tests covering all 9 functions in `lib/env_detect.sh` (baseline: **1.98%** coverage, 99 / 101 tracked lines missed). Uses PATH-shim builders for `asdf`, `pyenv`, and `direnv` so the test doesn't require those tools on the CI runner; shim behavior is parameterized by env vars (`ASDF_INSTALL_EXIT`, `PYENV_AVAILABLE_VERSIONS`, etc.) so a single shim serves multiple tests. Specifically exercises the asdf 0.18+ `set`→`local` fallback, the `CI=true` auto-install gate, and the `asdf plugin list` no-python-plugin warning.
- **[tests/unit/test_distutils_shim_coverage.bats](tests/unit/test_distutils_shim_coverage.bats)** (Story I.k) — new file, 17 tests covering the functions and branches the existing `test_distutils_shim.bats` leaves uncovered. Includes the first coverage for `pyve_install_distutils_shim_for_micromamba_prefix` (44-line function, wholly untested before), `pyve_distutils_shim_probe` (4 log-output branches), `pyve_get_site_packages_dir`, and `pyve_ensure_venv_packaging_prereqs`.
- **`prompt_yes_no` tests in [test_utils.bats](tests/unit/test_utils.bats)** (Story I.k) — 6 tests covering all three arms of the input loop (y / n / re-prompt-on-invalid). `prompt_yes_no` was previously wholly untested despite being called from `lib/env_detect.sh` and `lib/utils.sh` itself.

### Developer notes

- **Coverage baseline vs. target** (per Codecov, `bash` flag, `lib/` subtotal):
  - v2.2.0 (post-Phase-I-primary): **62.44%** (996 / 1595 tracked)
  - v2.2.1 target: **≥ 80%**
  - v2.2.1 realistic estimate: **~78%** — the `utils.sh` per-function targeting is necessarily less surgical than for `env_detect.sh` / `distutils_shim.sh` without Codecov's per-line view. If the actual CI number comes in under 80%, a follow-up targeting `utils.sh`'s big multi-branch functions (`prompt_install_pip_dependencies` at 155 lines; the `prompt_install_project_guide*` family) will be filed as a K-class story.
- **`utils.sh` dead-code audit finding** (Story I.k): zero unused functions. All 36 functions in `utils.sh` are called from at least one of `pyve.sh`, `lib/*.sh`, or `tests/` — the three that show 0 `pyve.sh` references (`prompt_yes_no`, `gitignore_has_pattern`, `append_pattern_to_gitignore`) are used from other `lib/` files. The 32% gap in `utils.sh` comes from uncovered branches within called functions, not dead helpers.
- **Test suite state**: bats **707 / 707 passing** (was 651 at start of v2.2.1 work; +56 = 33 env_detect + 17 distutils_shim_coverage + 6 prompt_yes_no). Integration bootstrap + helpers: 16 passed, 2 skipped (unchanged).

### Migration notes

No breaking changes. `pyve --version` reports `2.2.1`. No CLI surface changes, no config-file-format changes, no behavior changes visible to users (the `distutils_shim.sh` idempotency fix only affects mtime on repeat `pyve init` runs — content is unchanged).

## [2.2.0] - 2026-04-22

Phase I release: bootstrap test activation and hardening. Ten previously-skipped pytest tests around `pyve init --backend micromamba --auto-bootstrap` (stale since v0.8.4 — "Bootstrap not yet implemented") are now live and pinning real behavior. One user-facing bug (bzip2 extraction on Linux) was surfaced and fixed during test activation, and a new CI job exercises the bootstrap-and-download path on every PR.

### Fixed

- **Bootstrap tarball extraction now works on Linux.** `bootstrap_install_micromamba` was extracting with `tar -xzf`, which forces gzip decompression. Real micromamba tarballs served from `micro.mamba.pm` are **bzip2**-compressed (`file` output: `bzip2 compressed data, block size = 900k`); GNU tar (Linux CI runners, every Linux user) errored out, and the existing `2>/dev/null` swallowed the error — bootstrap silently returned 1 and the binary never landed. macOS's BSD tar auto-detects the format regardless of the `-z` flag, which is why the bug had remained invisible on dev machines. Changed to plain `tar -xf` (auto-detect via magic bytes, supported by GNU tar since 1.15 in 2010). Any Linux user running `pyve init --backend micromamba --auto-bootstrap` was hitting this. (Story I.e.)

### Added

- **New CI job `integration-tests-bootstrap`** (Story I.g) runs on `ubuntu-latest` + `macos-latest` with no pre-installed micromamba, so the bootstrap-and-download path is exercised for real on every PR. Both OSes are required — the I.e tar-extraction bug only surfaces on GNU tar; dropping macOS would let a `-xzf` regression slip back in silently.
- **`bootstrap_isolation` and `failing_curl` pytest fixtures** in [tests/integration/test_bootstrap.py](tests/integration/test_bootstrap.py). `bootstrap_isolation` points `$HOME` at a fresh tmp dir and iteratively scrubs any directory containing a `micromamba` binary from `$PATH`, so `get_micromamba_path` resolves deterministically regardless of host setup. `failing_curl` layers a PATH-shim that makes `curl` exit 1, short-circuiting the real network download for failure-path tests (kept them ~0.5s combined instead of 15-30s).
- **`ProjectBuilder.init_micromamba()` now accepts `**kwargs`** ([tests/helpers/pyve_test_helpers.py:555-579](tests/helpers/pyve_test_helpers.py#L555-L579)) so tests can invoke `project_builder.init_micromamba(auto_bootstrap=True, bootstrap_to='project')` without bypassing the helper. (Story I.a.)
- **Grep-invariant bats test** in [tests/unit/test_micromamba_bootstrap.bats](tests/unit/test_micromamba_bootstrap.bats) locking the "no `tar -...z...f`" invariant that the Story I.e fix depends on. Catches any future revert to the buggy flag combination on every bats run.

### Changed

- **Integration test coverage**: 10 previously-skipped bootstrap tests activated. 4 tests (Story I.b) exercise the real bootstrap-and-download path using `bootstrap_isolation`. 4 tests (Story I.c) cover failure paths (network failure, platform detection, insufficient permissions, cleanup on failure) using `failing_curl` + targeted chmod. 2 tests (Story I.d) pin the "config-file bootstrap keys are not read" invariant as negative tests — bootstrap is strictly CLI-driven via `--auto-bootstrap` and `--bootstrap-to <project|user>`; no `.pyve/config` keys are parsed, and `pyve init --force` purges the existing config before continuing anyway. 1 test (Story I.f) pins the "bootstrap is a no-op" happy path when micromamba is already available. 2 tests remain skipped, pending Future stories K (SHA256 verification, version pinning).
- **Stale skip reasons refreshed**: the two remaining skips in `test_bootstrap.py` now reference the specific Future stories they depend on, not the long-outdated "Bootstrap not yet implemented" from v0.8.4.

### Developer notes

- **Bootstrap verification is transport-only**, not cryptographic. The Story I.h audit confirmed `bootstrap_install_micromamba` trusts the downloaded binary if it (1) arrives non-empty over HTTPS to `micro.mamba.pm`, (2) extracts cleanly, (3) executes and reports a version. SHA256 verification and version pinning are tracked as Future work — see the two new `Story K.?` entries in [docs/specs/stories.md](docs/specs/stories.md). With version pinning in place, SHA256 via a hardcoded-table approach becomes much more tractable; both stories compose cleanly.
- **Test suite state**: bats now 651 / 651 passing (was 650; +1 for the I.e grep-invariant). Bootstrap + helpers integration: 16 passed, 2 skipped (was 2 passed, 12 skipped at start of Phase I). The new CI bootstrap job is the first automation exercising the real network download path.
- **Scope pivot recorded in Story I.d**: the two `TestBootstrapConfiguration` tests were originally written assuming pyve would parse bootstrap-related keys from `.pyve/config`. pyve never did, and `--force` purges the config anyway. Instead of implementing config-keyed bootstrap (a new feature outside Phase I scope) or deleting the test skeleton, both tests were reshaped as negative-invariant tests that pin the CLI-only contract. If config-keyed bootstrap is ever added, invert those tests back to positive assertions and wire a new `read_config_value` call into the bootstrap decision point at [pyve.sh:799-814](pyve.sh#L799-L814).
- **Scope pivot recorded in Story I.h**: the original I.h task list expected cryptographic verification + version pinning to land with v2.2.0. Neither is a one-line change (hash-table maintenance burden, GitHub API rate limits, new CLI flag + URL plumbing + tests). Both deferred to Future K stories so v2.2.0 can ship focused on "bootstrap tests are real and CI catches regressions."

### Migration notes

No breaking changes. `pyve --version` reports `2.2.0`. No CLI surface changes, no config-file-format changes. The `tar -xzf` → `tar -xf` fix is a silent improvement for Linux users; macOS behavior is unchanged.

## [2.1.0] - 2026-04-20

Feature bump: `pyve init --backend micromamba` in a fresh directory now scaffolds a starter `environment.yml` and proceeds, instead of requiring the user to hand-author one before the first run. Ships alongside the H.f.6 silent-exit fix for the same code path.

### Added

- **Starter `environment.yml` scaffold** on `pyve init --backend micromamba` when the current directory has neither `environment.yml` nor `conda-lock.yml`. The scaffold pins `python=<--python-version>` on `conda-forge` and adds `pip`; the user edits to add real dependencies, then runs `pyve lock`. See `docs/specs/features.md` FR-10a for the full contract. Name resolution: `--env-name` wins; otherwise the sanitized directory basename. Does **not** scaffold under `--strict`, does **not** overwrite an existing `environment.yml`, does **not** scaffold when `conda-lock.yml` exists without `environment.yml` (that's an inconsistent-state error). (H.f.7.)
- **`scaffold_starter_environment_yml()`** helper in [lib/micromamba_env.sh](lib/micromamba_env.sh). Library-level, testable, single responsibility. Called from `init()` before `check_micromamba_available` so scaffolding is cheap and deterministic and happens before the expensive bootstrap dance.
- **Auto `PYVE_NO_LOCK=1`** inside init when scaffolding fires, so `validate_lock_file_status()` takes its existing `--no-lock` bypass and the first successful init doesn't insist on a lock that can't yet exist.

### Fixed

- **`pyve init --backend micromamba` in an empty directory no longer exits silently.** The two silent-return-1 branches in `validate_lock_file_status()` (Cases 3 and 4 — "only conda-lock.yml" and "neither file present") now emit actionable errors unconditionally, naming the missing file(s), pointing at the scaffolding path (or the `pyve init --backend venv` fallback), and elaborating when `--strict` is set. Pre-fix, a fresh-shell repro produced exit 1 with zero stdout/stderr — indistinguishable from a shell-integration bug. (H.f.6, field-caught 2026-04-20.)

### Changed

- **`docs/site/getting-started.md`** — the "Using Micromamba Backend" section now documents the scaffold-then-proceed flow as the primary path. The old "hand-author `environment.yml` first, then `conda-lock`, then `pyve init`" sequence moves to an "already have an `environment.yml`?" sub-section.

### Developer notes

- 8 new bats tests in [tests/unit/test_scaffold_environment_yml.bats](tests/unit/test_scaffold_environment_yml.bats) — 6 library-level (helper contract) + 2 integration-lite (init wiring). Plus 2 new tests in [tests/unit/test_lock_validation.bats](tests/unit/test_lock_validation.bats) for the H.f.6 error-content assertions. Test suite now 650 / 650 passing.
- Side finding during H.f.6 verification: `bootstrap_micromamba_interactive` silently defaults to "install to project sandbox" under piped `</dev/null` (EOF + while-loop + empty-choice-defaults-to-1 → unexpected download). Not fixed in this release. Documented in H.f.6's out-of-scope list.

## [2.0.1] - 2026-04-20

Unified UX retrofit across every top-level pyve command. Output from `pyve init`, `pyve purge`, `pyve testenv`, and `pyve python set` now looks and feels like the sibling `gitbetter` tool — rounded-box header, consistent phase banners, `▸` / `⚠` / `✘` / `✔` glyph palette, `▸`-prefixed info lines for per-artifact outcomes, and a closing "All done" footer on success. No behavior changes — this is a cosmetic retrofit plus one new convenience flag.

### Added

- **`pyve purge --yes` / `-y`** — skip the destructive-confirmation prompt. Same semantics as `CI=1` or `PYVE_FORCE_YES=1`. Used internally by `pyve init --force` (which already prompts at its own layer) to avoid double-prompting. (H.f.2.)
- **`▸ / ⚠ / ✘ / ✔` unified-glyph palette** across `lib/utils.sh` logging helpers. The `log_info` / `log_warning` / `log_error` / `log_success` helpers now emit the shared-UX palette instead of the pre-H.f `INFO:` / `WARNING:` / `ERROR:` / `✓` prefixes. Stderr vs. stdout routing and non-exiting semantics preserved. (H.f.4.)

### Changed

- **`pyve init` output** rewritten end-to-end: `header_box "pyve init"` at entry; `banner` for phase boundaries ("Purging existing environment", "Rebuilding fresh environment", "Initializing Python environment", "Initializing micromamba environment"); `info` / `success` / `warn` for per-artifact outcomes; `ask_yn` for the `--force` confirmation; `footer_box` on success. (H.f.1.)
- **`pyve purge` output** rewritten with the same contract. Destructive-confirmation prompt now fires via `ask_yn` (skippable via `--yes` / `-y`). (H.f.2.)
- **`pyve testenv init | install | purge` output** retrofitted. `pyve testenv run <cmd>` still `exec`s into the target command (no footer — the called command owns the terminal from that point). `pyve testenv install` wraps the pip install with `run_cmd`, showing the dimmed `$ cmd` echo before the subprocess output. (H.f.3.)
- **`pyve python set <ver>` output** wrapped with `header_box` / `banner "Setting Python version to <ver>"` / `footer_box`. `pyve python show` intentionally stays quiet — read-only commands follow the `git status` / `gitbetter` "unwrapped" convention. (H.f.3.)
- **Error hint on `pyve testenv run` before init** now recommends the v2.0-canonical `pyve testenv init` (previously advertised the deprecated `pyve testenv --init` flag form). (H.f.3.)
- **Pip / micromamba subprocess output policy**: full pass-through. `run_cmd`'s dimmed `$ cmd` echo provides the header line; the subprocess's own progress bars and error diagnostics stay visible at both the dev console and in CI logs. (H.f.4 decision, documented in `docs/specs/features.md`.)

### Fixed

- **`show_help()`** no longer advertises `doctor` or `validate` as active commands. Both were hard-removed in v2.0.0 (H.e.8a) but still appeared in the Diagnostics section and EXAMPLES block. (H.f.5.)
- **`show_help()` EXAMPLES** use v2.0-canonical grammar throughout (`pyve testenv init`, `pyve python set 3.13.7`, `pyve check`, `pyve status`, `pyve purge --yes`). The deprecated flag forms (`--init` / `--install` / `python-version <ver>`) continue to work with a deprecation warning — the informational note in the Commands section remains — but they are no longer promoted in examples. (H.f.5.)
- **`pyve purge --help`** documents `--yes` / `-y`. (H.f.5.)
- **Integration test `test_testenv_run_before_init_shows_error`** updated to match the v2.0-canonical error-hint wording. (Caught by CI after H.f.3; fixed alongside H.f.5.)

### Developer notes

- All new `lib/ui.sh` helpers used by H.f (`header_box` / `footer_box` / `banner` / `info` / `success` / `warn` / `fail` / `ask_yn` / `confirm` / `run_cmd`) were already present from H.e.1 — no additions during H.f. The module stays verbatim-backport-clean for the sibling `gitbetter` project.
- 27 new bats tests added across H.f.1 – H.f.5 — 3 init UX, 6 purge UX, 3 testenv UX, 2 python UX, 8 error-path, 5 release-sync — plus 4 refreshed `log_*` format assertions in `test_utils.bats` and an updated version assertion in `test_cli_dispatch.bats`. Test suite now 640 / 640 passing.

## [2.0.0] - 2026-04-19

Phase H's CLI-unification arc lands. This release rewires the top-level command surface for consistency (one grammar, not two), cuts `doctor` and `validate` in favor of `check` + `status`, and locks in a deliberate deprecation path for every rename introduced during H.e.

See [docs/site/migration.md](docs/site/migration.md) for a tactical upgrade guide; see [docs/specs/phase-H-cli-refactor-design.md](docs/specs/phase-H-cli-refactor-design.md) and [docs/specs/phase-H-check-status-design.md](docs/specs/phase-H-check-status-design.md) for the design rationale.

### BREAKING CHANGES

- **`pyve doctor` removed.** Replaced by `pyve check` (diagnostics, 0/1/2 CI-safe exit codes) and `pyve status` (read-only state dashboard). Typing `pyve doctor` now prints a migration error and exits 1. (H.e.8a, superseding H.e.8's delegate-with-warning.)
- **`pyve validate` removed.** Also replaced by `pyve check`. Typing `pyve validate` prints a migration error and exits 1. (H.e.8a.)
- **`pyve init --update` removed.** Replaced by the new top-level `pyve update` subcommand (shipped in v1.16.0). Migration is deliberate — `pyve update` has broader semantics (config bump + managed-files refresh + project-guide refresh) than the old flag's narrow config-version bump; silent delegation would surprise scripted callers. (H.e.9.)
- **New legacy-flag catches added** for flag-form invocations that never existed but that users might instinctively reach for: `pyve --update`, `pyve --doctor`, `pyve --status` each error with a migration message pointing at the correct subcommand. (H.e.9.)

### Added

- **`pyve update`** — non-destructive upgrade path (v1.16.0, H.e.2): refresh `.pyve/config` version, managed files (`.gitignore`, `.vscode/settings.json`), and `project-guide` scaffolding. Never rebuilds the venv — use `pyve init --force` for that.
- **`pyve check`** — diagnostics + remediation (v1.17.0, H.e.3): 20 checks with 0/1/2 CI-safe exit codes.
- **`pyve status`** — state dashboard (v1.18.0, H.e.4): sectioned read-only view of the project environment.
- **`pyve testenv init | install | purge`** — nested subcommand grammar for testenv (v1.19.0, H.e.5). Flag forms (`--init` / `--install` / `--purge`) still work with a deprecation warning (see below).
- **`pyve python set <ver>` / `pyve python show`** — nested subcommand grammar for the Python-version pin (v1.20.0, H.e.6). Legacy `pyve python-version <ver>` still works with a deprecation warning.

### Deprecated (still works in v2.x; removed in v3.0)

The following forms continue to work in v2.x but emit a one-shot deprecation warning to stderr on first use. Scripts that invoke them in a loop stay readable — warnings fire once per invocation, not once per call.

- `pyve testenv --init` → use `pyve testenv init` (H.e.7).
- `pyve testenv --install [-r <file>]` → use `pyve testenv install [-r <file>]` (H.e.7).
- `pyve testenv --purge` → use `pyve testenv purge` (H.e.7).
- `pyve python-version <ver>` → use `pyve python set <ver>` (H.e.7).

### Migration table

| v1.x form | v2.0 form | v2.0 behavior |
|---|---|---|
| `pyve doctor` | `pyve check` | Hard error, exit 1 |
| `pyve validate` | `pyve check` | Hard error, exit 1 |
| `pyve init --update` | `pyve update` | Hard error, exit 1 |
| `pyve --update` | `pyve update` | Hard error, exit 1 |
| `pyve --doctor` | `pyve check` | Hard error, exit 1 |
| `pyve --status` | `pyve status` | Hard error, exit 1 |
| `pyve testenv --init` | `pyve testenv init` | Works + deprecation warning |
| `pyve testenv --install` | `pyve testenv install` | Works + deprecation warning |
| `pyve testenv --purge` | `pyve testenv purge` | Works + deprecation warning |
| `pyve python-version <ver>` | `pyve python set <ver>` | Works + deprecation warning |

### Changed

- `VERSION` bumped to `2.0.0` in [pyve.sh](pyve.sh).
- Dead code removed: `doctor_command()`, `show_validate_help()`, `run_full_validation()` / `_escalate()`, and the `PYVE_REINIT_MODE="update"` branch inside `init()` — all rendered unreachable by the above changes (H.e.8a, H.e.9).

### Internal

- New `lib/ui.sh` module (v1.15.0, H.e.1) with colors, symbols, rounded-corner boxes, and shared prompt helpers. Ported from `gitbetter` verbatim; enhanced with `NO_COLOR=1` support.
- `deprecation_warn()` helper in [lib/ui.sh](lib/ui.sh): once-per-invocation-per-key stderr warning. bash-3.2-safe (H.e.7a).
- `legacy_flag_error()` catch list extended to 9 entries in [pyve.sh](pyve.sh).

## [1.20.0] - 2026-04-18

### Added — `pyve python set <ver>` and `pyve python show` (Story H.e.6)

Adds the `python` nested subcommand namespace, ratifying H.d Decision D1 in [docs/specs/phase-H-cli-refactor-design.md §4.2](docs/specs/phase-H-cli-refactor-design.md). Two subcommands in this release:

- **`pyve python set <version>`** — identical semantics to `pyve python-version <version>`: pins the project's Python via asdf / pyenv (writes `.tool-versions` or `.python-version`).
- **`pyve python show`** — NEW capability: reads the currently pinned Python version and prints it along with its source (`.tool-versions` / `.python-version` / `.pyve/config`). Returns "not pinned" message when no pin is set. Read-only; never installs or modifies anything.

**Why the nested grammar (D1 rationale):**

- `python-version` was the only hyphenated top-level subcommand in pyve — inconsistent with `init`, `purge`, `lock`, etc.
- Renaming directly to `python` would collide with the name of the underlying tool (`pyve python` — is that "pyve's python subcommand" or "run python via pyve"?). Nesting with an action verb (`set` / `show`) disambiguates.
- Leaves room for future `pyve python list` / `pyve python available` without another rename.

**Deprecation schedule (per H.d §5, D1):**

- **v1.x (this release):** Both `pyve python set <ver>` and `pyve python-version <ver>` work. No warnings.
- **v2.0:** `python-version` delegates to `python set` with a deprecation warning.
- **v3.0:** `python-version` removed (hard error via `legacy_flag_error`).

### Added — `show_python_help()` + top-level `--help` entries

- New `show_python_help()` function documents the `set` / `show` subcommands and calls out the legacy `python-version` form with its v3.0 removal timeline.
- `pyve --help` now lists `python set <ver>` and `python show` under the Environment section, with a note that the legacy `python-version` form is still accepted.

### Tests

- **`tests/unit/test_python_command.bats` — 16 new tests** covering:
  - `--help` / `-h` output and top-level help integration.
  - `PYVE_DISPATCH_TRACE` emits `DISPATCH:python <args>`.
  - `pyve python` with no subcommand exits 1 actionably.
  - Unknown subcommand exits 1 actionably.
  - `python set` without a version exits 1 with usage guidance.
  - `python set` with invalid version formats (`3.13.7.1`, `abc`) exits 1.
  - `python show` on a fresh directory reports "not pinned" and exits 0.
  - `python show` reads `.tool-versions` / `.python-version` correctly.
  - `python show` prefers `.tool-versions` over `.python-version` (same precedence as `pyve init`).
  - Legacy `pyve python-version` still validates args and still has `--help`.
  - Top-level `pyve --help` references the new grammar.
- All 550 Bats unit tests pass (534 prior + 16 new).

### Changed — `set_python_version_only()` error messages

The function is still invoked by the legacy `python-version` dispatch path AND the new `python set` path. Error messages now point at `pyve python set <version>` as the usage example. The legacy `pyve python-version <version>` path still works — only the error text guides new users toward the new grammar.

### Unchanged in this release

- `pyve python-version <ver>` — still works end-to-end in v1.x.
- All asdf / pyenv integration logic (`detect_version_manager`, `ensure_python_version_installed`, `set_local_python_version`). This sub-story is a rename + addition, not a rewrite.

---

## [1.19.0] - 2026-04-18

### Added — `pyve testenv init | install | purge` subcommand grammar (Story H.e.5)

Normalizes the `testenv` sub-surface to match top-level pyve grammar (`pyve init`, `pyve purge`, etc.). Implements H.d Decision D5 from [docs/specs/phase-H-cli-refactor-design.md §4.4](docs/specs/phase-H-cli-refactor-design.md).

Before this release, `testenv` used two grammars:

```
pyve testenv --init / --install / --purge    (flag form; inconsistent with top-level)
pyve testenv run <cmd>                        (subcommand form)
```

Now both forms are accepted; the new subcommand form is the preferred grammar going forward:

```
pyve testenv init
pyve testenv install [-r requirements-dev.txt]
pyve testenv purge
pyve testenv run <cmd> [args...]
```

**Deprecation schedule** (per H.d §5):

- **v1.x (this release):** Both forms accepted. No warnings. Scripts that use the flag form keep working unchanged.
- **v2.0 (coming):** Flag forms emit a deprecation warning and delegate to the new form.
- **v3.0:** Flag forms removed (hard error).

### Changed — `pyve testenv --help` and top-level `pyve --help`

- `pyve testenv --help` usage block now shows the new subcommand grammar as primary. The flag forms are listed under a "Legacy flag forms" subsection with the v3.0 removal timeline.
- `pyve --help` testenv line updated from `--init | --install [-r <req>] | --purge | run <cmd>` to `init | install [-r <req>] | purge | run <cmd>` with a note that the old flag forms are still accepted.

### Tests

- **`tests/unit/test_testenv_grammar.bats` — 13 new tests** covering:
  - Each new subcommand form (`init`, `install`, `purge`) routes to the correct action.
  - Each legacy flag form (`--init`, `--install`, `--purge`) still routes to the same action.
  - `init` and `--init` reach the identical code path (equivalence check).
  - `install -r <req>` syntax remains accepted.
  - `--help` documents both grammars.
  - `--help` notes the legacy status of the flag forms.
  - Unknown subcommand / unknown flag both exit 1 with actionable errors.
  - Top-level `pyve --help` lists the new subcommand grammar.
- All 534 Bats unit tests pass (521 prior + 13 new).

The tests verify argument **parsing** by asserting on each action's distinctive banner line, so they do not depend on a working `python` / `python -m venv` at test time. Actual testenv-creation paths are covered by the existing integration tests in `tests/integration/test_testenv.py`.

### Unchanged in this release

- `pyve testenv run <cmd>` — already correct subcommand grammar; no change.
- The `-r` / `--requirements` flag still takes a file argument exactly as before.
- No deprecation warnings on the flag forms yet — that's v2.0's job per H.d §5.

---

## [1.18.0] - 2026-04-18

### Added — `pyve status` subcommand (Story H.e.4)

Read-only state dashboard. Implements the spec in [docs/specs/phase-H-check-status-design.md §4](docs/specs/phase-H-check-status-design.md). Pairs with `pyve check` (diagnostics + suggested fixes) — `status` reports what is, `check` reports what's wrong.

**Usage:**

```
pyve status
```

**Contract (per H.c §4.2):**

- Always exits `0` based on findings. An "environment is broken" reading is `pyve check`'s job, not `status`'s.
- `1` only for pyve-internal errors (unknown flag, positional arg — same conventions as `update` / `check`).
- Never prompts. Safe under `</dev/null`. Safe in CI.

**Output layout (sectioned, per H.c §4.3):**

```
Pyve project status
───────────────────

Project
  Path:             <absolute project path>
  Backend:          venv | micromamba | not configured
  Pyve config:      v<recorded> (current | current: v<running> | newer than pyve v<running>)
  Python:           <version> (.tool-versions via asdf | .python-version via pyenv | .pyve/config | not pinned)

Environment
  # venv backend:
  Path:             <venv dir> [(missing)]
  Python:           <version from bin/python --version>
  Packages:         <N> installed
  distutils shim:   installed | not installed           (Python 3.12+ venv only)

  # micromamba backend:
  Name:             <env_name>
  Path:             .pyve/envs/<env_name> [(missing)]
  Python:           <version>
  Packages:         <N> installed                       (from conda-meta/)
  environment.yml:  present | missing
  conda-lock.yml:   up to date | stale | missing

Integrations
  direnv:           .envrc present | .envrc missing
  .env:             present | present (empty) | missing
  project-guide:    installed (v<ver>) | installed | not installed
  testenv:          present, pytest installed | present, pytest not installed | not present
```

Non-project fallback: when `.pyve/config` is absent, `pyve status` prints the title, a "Not a pyve-managed project" marker, and exits `0`. Users who run `pyve status` in the wrong directory get a friendly answer, not a red error.

**Rendering:** uses the `lib/ui.sh` color/style constants (`BOLD`, `DIM`, `RESET`) — first `pyve.sh`-level adopter of the module shipped in v1.15.0. Respects `NO_COLOR=1` (https://no-color.org): output contains zero ANSI escape sequences, layout unchanged.

### Added — `show_status_help()` + top-level `--help` entry

- `show_status_help()` with the read-only contract, output description, and cross-references to `check` and `--help`.
- `pyve --help` lists `status` under Diagnostics, directly beneath `check`.
- `PYVE_DISPATCH_TRACE=1 pyve status` emits `DISPATCH:status <args>`.

### Changed — `pyve.sh` now sources `lib/ui.sh` at startup

The main script now sources `lib/ui.sh` alongside the other lib modules at the top of the file. `status_command` is the first consumer; `update` and `check` migrate in a later adoption pass (tracked under the H.f retrofit scope).

### Tests

- **`tests/unit/test_status.bats` — 25 new tests** covering:
  - `--help` / `-h` output, read-only-contract wording, and top-level help integration.
  - Exit-code discipline: always `0` for missing config, missing venv, missing backend; `1` only on unknown flag / positional arg.
  - Non-project fallback message.
  - Title + three section headers (Project / Environment / Integrations).
  - Project section: backend name, recorded pyve version, version drift, "(current)" marker.
  - Environment section (venv backend): `.venv` path, "(missing)" marker when absent, Python version extraction from `bin/python`.
  - Integrations section: `.envrc` / `.env` / testenv presence reporting.
  - Non-prompting invariant (runs cleanly with `</dev/null`).
  - `NO_COLOR=1` → no ANSI escape sequences in output.
  - `PYVE_DISPATCH_TRACE` integration.
- All 521 Bats unit tests pass (496 prior + 25 new).

### Fixed — `set -euo pipefail` interaction with `find` pipelines

`find`'s non-zero exit when the search root is missing, combined with `pipefail`, made several `status` helpers kill the script on a just-init'd venv (no `lib/` dir yet). Fixed the helpers (`_status_env_venv`, `_status_venv_package_count`, `_status_env_micromamba`) by guarding with `[[ -d ... ]]` checks and `|| true` on the pipeline output. No regressions in `pyve doctor`; this bug could only surface through `status`.

---

## [1.17.0] - 2026-04-18

### Added — `pyve check` subcommand (Story H.e.3)

New read-only diagnostic command. Implements the spec in [docs/specs/phase-H-check-status-design.md §3](docs/specs/phase-H-check-status-design.md) and unifies the roles of `pyve doctor` (health diagnostics) and `pyve validate` (CI exit-code gate).

**Usage:**

```
pyve check
```

**Exit codes (same contract as `pyve validate`):**

| Code | Meaning |
|---|---|
| `0` | All checks passed. |
| `1` | One or more errors — environment is broken for `pyve run` / `pyve test`. |
| `2` | Warnings only — environment works but is drifting. Errors never downgraded by subsequent warnings. |

**Diagnostic surface (implemented in v1.17.0):**

- Configuration: `.pyve/config` present and parseable.
- Pyve version: drift from running `pyve` version (via `compare_versions` — points at `pyve update`).
- Backend: configured in `.pyve/config`; unknown backend value flagged.
- venv backend: environment directory + `bin/python` exist; venv path mismatch (relocated project) detection via `doctor_check_venv_path`; duplicate `dist-info` detection; cloud-sync collision artifact detection.
- micromamba backend: `micromamba` binary available; `environment.yml` present; `conda-lock.yml` present + freshness via `is_lock_file_stale`; environment directory + `bin/python` exist; duplicate `dist-info`, cloud-sync artifact, native-library conflict detection via the existing `doctor_check_*` helpers.
- Integrations: `.envrc` present; `.env` present.
- testenv: if present, warn when `pytest` not installed (conditional — absent testenv is not a warning; `pyve test` bootstraps on demand).

Every failure emits exactly one actionable command (no chains, no cross-references to other diagnostic commands — per H.c §3.1).

**Deferred to a follow-up polish pass:**

- Full **active-vs-configured Python version mismatch** gate (H.c Check 6). The venv and micromamba paths already surface `bin/python --version`; the explicit comparison against `.tool-versions` / `.python-version` / config lives in a follow-up.
- Post-init **distutils shim** verification for Python 3.12+ (H.c Check 8). Needs a new `is_distutils_shim_installed` helper.
- `pyve check --fix` auto-remediation (H.c C2 — deferred to Phase I; [docs/specs/stories.md](docs/specs/stories.md) "Future" section).

### Added — `show_check_help()` + top-level `--help` entry

- New `show_check_help()` with the usage contract, exit-code semantics, and cross-references to `doctor` / `validate` / `--help`.
- Top-level `pyve --help` now lists `check` under "Diagnostics". `doctor` and `validate` re-labeled as "Legacy (superseded by `pyve check`)" — actual delegation / deprecation warnings on those old commands land in v2.0 per H.d §5.
- `PYVE_DISPATCH_TRACE=1 pyve check` emits `DISPATCH:check <args>` for dispatcher debugging.

### Tests

- **`tests/unit/test_check.bats` — 17 new tests** covering:
  - `--help` / `-h` output and top-level help integration.
  - Exit-code semantics: 0 (happy path), 1 (errors: missing `.pyve/config`, missing backend, missing venv, missing `bin/python`), 2 (warnings: pyve_version drift, missing `.env`, missing `.envrc`).
  - Escalation invariant: an error status is never downgraded by a subsequent warning.
  - Summary footer format.
  - Actionable-message discipline: failure output contains at least one executable command.
  - micromamba-specific path: missing `environment.yml` flagged as error.
  - Unknown-flag handling.
  - Dispatcher integration (`PYVE_DISPATCH_TRACE`).
- All 496 Bats unit tests pass (479 prior + 17 new).

### Unchanged in this release

- `pyve doctor` and `pyve validate` still work exactly as before. Delegation-with-warning is planned for v2.0 per the H.d deprecation plan.
- No code was removed. `check` is additive; the pre-existing `doctor_check_*` helpers in `lib/utils.sh` are reused in place (they serve both `doctor_command` and `check_command`).

---

## [1.16.1] - 2026-04-18

### Fixed — `.pyve/envs/` not ignored on venv-init'd projects (Story H.e.2a)

Before this release, `.pyve/envs/` was added to `.gitignore` only by the **micromamba** init path ([pyve.sh:918-922](pyve.sh#L918-L922) pre-fix); the venv init path ([pyve.sh:1179-1182](pyve.sh#L1179-L1182) pre-fix) omitted it. A project originally venv-init'd that later had a micromamba env drop into `.pyve/envs/` (e.g., manual `micromamba create -p .pyve/envs/foo`, backend switch without `--force`, tooling drift) would leak tens of thousands of env files to `git status`.

**Root cause — asymmetric per-backend `.gitignore` population.** Five pyve-managed ignore patterns (`.pyve/envs`, `.pyve/testenv`, `.envrc`, `.env`, `.vscode/settings.json`) are pyve-internal regardless of backend, but they were being inserted by backend-specific post-template `insert_pattern_in_gitignore_section` calls — so whichever backend you last init'd determined which of these appeared in your `.gitignore`.

**Fix — bake the pyve-internal patterns into the static template in `write_gitignore_template()`.** The `# Pyve virtual environment` section in the template now statically includes all five patterns. Per-backend init paths retain only the dynamic insert for the user-overridable venv directory name (defaults to `.venv`, customizable via `pyve init <dir>`). The existing template-dedup logic prevents any duplication when users migrate from pre-fix `.gitignore` files.

**Upgrade path for existing projects.** Run `pyve update` (shipped in v1.16.0) — it calls `write_gitignore_template()` as part of the non-destructive refresh, so `.pyve/envs` and the other baked-in patterns appear without touching the venv or user state. Alternatively, `pyve init --force` achieves the same on a fresh rebuild.

Byte-level idempotency tests from Story H.a continue to pass — the new template is a superset of the old one and the dedup logic handles the transition cleanly.

### Tests

- **`tests/unit/test_utils.bats` — 4 new tests** asserting each of the newly-baked patterns is present after `write_gitignore_template` (`.pyve/envs`, `.pyve/testenv`, `.envrc` + `.env`, `.vscode/settings.json`).
- **`tests/unit/test_update.bats` — 1 new regression test** that reproduces the user-reported scenario: a venv-init'd project with a pre-fix `.gitignore` (missing `.pyve/envs`) gains the ignore after `pyve update`.
- All 479 Bats unit tests pass (474 prior + 5 new).

### Changed — `init_gitignore()` and micromamba init path simplified

- `init_gitignore()` ([pyve.sh:1171-1183](pyve.sh#L1171-L1183)) now calls `write_gitignore_template` followed by one `insert_pattern_in_gitignore_section` for the venv directory. Drops the four now-redundant `ENV_FILE_NAME` / `.envrc` / `.pyve/testenv` inserts.
- Micromamba init `.gitignore` block ([pyve.sh:915-918](pyve.sh#L915-L918)) drops all five per-backend inserts — the template now covers them.
- `dynamic_patterns` array in `write_gitignore_template()` shrinks from six entries to one (`${DEFAULT_VENV_DIR:-.venv}`). Template lines contributed via the heredoc cover the rest via the existing template-line deduplication path.

### Out of scope (not addressed in this release)

- `.gitignore` formatting normalization beyond the Pyve section.
- Migrating historical `.pyve/envs/` files that are ALREADY tracked in a user's repo — that requires `git rm --cached`, a user-initiated operation.

---

## [1.16.0] - 2026-04-18

### Added — `pyve update` subcommand (Story H.e.2)

Non-destructive upgrade path for pyve-managed projects. Ratifies Decision C3 from Story H.c and D4 from Story H.d (see [docs/specs/phase-H-cli-refactor-design.md §4.3](docs/specs/phase-H-cli-refactor-design.md)).

**Usage:**

```
pyve update [--no-project-guide]
```

**What it refreshes (all idempotent):**

- `pyve_version` in `.pyve/config` → bumped to the running pyve version.
- Pyve-managed sections of `.gitignore` → re-applied via the existing `write_gitignore_template()`.
- `.vscode/settings.json` → refreshed only if it already exists (never created; respects user opt-in at init time).
- `project-guide` scaffolding → via `project-guide update --no-input` when `.project-guide.yml` is present, unless suppressed by `--no-project-guide` / `PYVE_NO_PROJECT_GUIDE=1`.

**Invariants (spec-level — enforced by tests):**

- Does NOT rebuild the virtual environment. Use `pyve init --force` for that.
- Does NOT create `.env` or `.envrc`. Those are user state.
- Does NOT re-prompt for backend. The recorded backend is preserved.
- Does NOT prompt under any circumstances (safe for CI and one-command upgrades).
- Returns `0` on success (including no-op when already at current version) and `1` on failure (missing config, corrupt config, unwritable files).

**Boundary vs. `pyve init --force`:**

- `pyve init --force` destroys + rebuilds the venv + all managed files.
- `pyve update` refreshes managed files only; the venv and user state are preserved.

**v1.x `pyve init --update` is unchanged in this release.** The old flag still performs its narrow config-version bump. It will become a legacy-flag error in v2.0 per H.d §5 (semantics have broadened in the new `pyve update`; silent delegation would surprise users).

### Added — `show_update_help()` + top-level `--help` entry

- New `show_update_help()` function in [pyve.sh](pyve.sh) — standard help block with usage, options, exit codes, and cross-references.
- Top-level `pyve --help` now lists `update` in the "Environment" section.
- `PYVE_DISPATCH_TRACE=1 pyve update` emits `DISPATCH:update <args>` for dispatcher debugging (consistent with the other v1.11.0+ subcommands).

### Tests

- **`tests/unit/test_update.bats` — 20 new tests** covering:
  - `--help` / `-h` output and top-level help integration.
  - Precondition failures: missing `.pyve/config`, missing `backend` key.
  - Happy path for venv backend: pyve_version bump, no-op at current version, adding pyve_version when not previously recorded.
  - `.gitignore` refresh with user-section preservation.
  - Backend preservation.
  - Spec-level invariants: does NOT create `.venv`, `.env`, `.envrc`, `.vscode/settings.json` (when absent); leaves existing `.venv` and `.env` untouched.
  - Non-prompting invariant: runs cleanly with `</dev/null`.
  - `--no-project-guide` skip path.
  - Unknown-flag error handling.
  - `PYVE_DISPATCH_TRACE` dispatch trace.
- All 474 Bats unit tests pass (454 prior + 20 new).

### Out of scope (deferred to later H.e sub-stories)

- `pyve check` (H.e.3) and `pyve status` (H.e.4) implementations.
- `testenv --init|--install|--purge` → `testenv init|install|purge` normalization.
- `python-version` → `python set` rename.
- Adopting `lib/ui.sh` styling inside `update_command` — will be done alongside the `lib/ui.sh` adoption pass (H.f).
- Removing or warning on `pyve init --update` — deferred to v2.0 per H.d §5.

---

## [1.15.0] - 2026-04-18

### Added — `lib/ui.sh` shared UX helpers module (Story H.e, first sub-story)

Introduces a standalone UI helpers module — the foundational building block for the Phase H CLI refactor. No existing pyve commands adopt it yet; this sub-story ships the module in isolation with full test coverage so every later H.e sub-story can source it without the module itself being on the critical path.

Ported verbatim from the sibling [`gitbetter`](https://github.com/pointmatic/gitbetter) project's `lib/ui.sh` with two deliberate enhancements:

- **`NO_COLOR=1` support** (https://no-color.org) — when `NO_COLOR` is non-empty, all color variables (`R`/`G`/`Y`/`B`/`C`/`M`/`DIM`/`BOLD`/`RESET`) become empty strings and the symbols (`CHECK`/`CROSS`/`ARROW`/`WARN`) degrade to unadorned glyphs. Output contains no ANSI escape sequences. Planned backport to `gitbetter`.
- **Pyve-free**: stripped `gitbetter`-specific identifiers (`GITBETTER_VERSION`, `GITBETTER_HOMEPAGE`, `print_version`, `fetch_quiet_or_warn`) so the module is a pure UI-primitives library. The remaining surface is what both projects genuinely share.

**Public API:**

- Color constants: `R`, `G`, `Y`, `B`, `C`, `M`, `DIM`, `BOLD`, `RESET`.
- Symbols: `CHECK` (✔), `CROSS` (✘), `ARROW` (▸), `WARN` (⚠).
- Helpers: `banner`, `info`, `success`, `warn`, `fail` (exits 1), `confirm` (default Y; exits 0 on abort), `ask_yn` (default N; returns 0/1), `divider`, `run_cmd` (dim-echoes `$ cmd` then executes).
- Rounded-corner boxes: `header_box <title>` (cyan+bold), `footer_box` (green+bold, "All done.").

**Backport discipline:** `lib/ui.sh` must not contain pyve-specific identifiers (`PYVE_*`, `.pyve`, `pyve.sh`, etc.). Enforced by a bats test that greps for pyve markers and fails if any are present.

### Tests

- **`tests/unit/test_ui.bats` — 29 new tests** covering color palette presence, `NO_COLOR=1` ANSI degradation, symbol output, each helper's glyph + exit behavior, `confirm`/`ask_yn` default handling and abort-path, `run_cmd` status propagation, rounded-corner rendering, and the backport-discipline invariant.
- All 454 Bats unit tests pass (425 pre-existing + 29 new).
- ShellCheck on `lib/ui.sh` produces zero warnings.

### Out of scope (deferred to later H.e sub-stories)

- Adopting `lib/ui.sh` in any existing pyve command (`init`, `purge`, `doctor`, etc.). No command changes in this release.
- Implementing `pyve update`, `pyve check`, `pyve status` (H.e sub-stories 2–4, per `docs/specs/phase-H-cli-refactor-design.md`).

---

## [1.14.2] - 2026-04-17

### Added — Python 3.14 in the integration-tests CI matrix (Story H.b.i)

Workflow-only change. The `integration-tests` job in [.github/workflows/test.yml](.github/workflows/test.yml) now runs against `['3.12', '3.14']` on both `ubuntu-latest` and `macos-latest`. `integration-tests-micromamba` stays at `'3.12'` only (conda ecosystem lead time for 3.14 wheels).

Why this matters: pyve's `DEFAULT_PYTHON_VERSION` is `3.14.4`, but CI has been pinning every runner to 3.12 since v1.12.0 — so the `distutils_shim.sh` path for Python 3.12+ has had no upper-bound coverage against the latest CPython. Adding 3.14 closes the dev/CI gap (the project owner's daily-driver Python) and exercises the shim on the newest stable release.

### Changed — `actions/setup-python` → pyenv symlink shim (avoids source build)

Previously the workflow ran `pyenv install $PYTHON_VERSION` after `actions/setup-python@v6` so that pyve's `ensure_python_version_installed()` would recognize the version. For 3.14, that pyenv step is a ~10–15 min source build on Ubuntu (worse on macOS) per runner per push — unacceptable for a matrix entry.

The new "Setup pyenv with Python" step reuses setup-python's pre-built binary by symlinking its install directory (`$(dirname $(dirname $(python -c 'import sys; print(sys.executable)')))`) into `$PYENV_ROOT/versions/$PYTHON_VERSION`. `pyenv versions --bare` reports the version as installed, `pyenv global $PYTHON_VERSION` switches to it, and `ensure_python_version_installed()` passes without a source build. If the symlink path isn't populated (e.g., setup-python didn't place a binary), the step falls back to the old `pyenv install` behavior.

No pyve code changes. No Bats or pytest test changes. Validation happens on this PR's CI run — a paper analysis (Story H.b) determined Option D (symlink) as the cleanest path and this change implements it.

### Spec

- `docs/specs/features.md` — Python version matrix line updated to reflect 3.12 + 3.14 and the symlink-shim approach.

---

## [1.14.1] - 2026-04-17

### Fixed — Cosmetic blank-line accumulation in `.gitignore` and `.zshrc` (Story H.a)

Three related formatting fixes discovered during the G.f investigation, all cosmetic (no behavioral change, no breaking change) but each produced spurious diffs on `pyve init --force` that users would otherwise have to commit.

**`.gitignore` — blank-line accumulation after purge-then-reinit.** `write_gitignore_template()` in `lib/utils.sh` eagerly emitted every blank line it read from the existing file, then skipped template/dynamic patterns. When the user had content below the Pyve-managed section, consecutive blank lines accumulated at the section boundary on each reinit cycle. Fixed by buffering blank lines and emitting them only when followed by a non-skipped (user) line, so blanks around skipped patterns no longer leak through.

**`.zshrc` — missing blank line before SDKMan marker.** `insert_text_before_sdkman_marker_or_append()` in `lib/utils.sh` emitted a leading blank line before the inserted project-guide completion block but none after it, so the block's closing sentinel (`# <<< project-guide completion <<<`) sat flush against `#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!`. Fixed by emitting a trailing blank line after the block. `remove_project_guide_completion()` was updated in lockstep to swallow one trailing blank line immediately following the close sentinel, preserving the byte-identical add→remove round-trip invariant (in both the SDKMan-absent and SDKMan-present cases).

### Tests

- **`tests/unit/test_utils.bats` — 2 new byte-level idempotency tests for `write_gitignore_template`:**
  - `idempotent after multiple purge-reinit cycles with Pyve-only content (H.a)` — regression guard for the Pyve-only path; md5 match across two purge-reinit cycles.
  - `idempotent after purge-reinit with user content below Pyve section (H.a)` — reproduces the real-world layout (user-added `# MkDocs build output`, `# project-guide` sections below) that triggered the bug.
- **`tests/unit/test_project_guide.bats` — 1 new test for `insert_text_before_sdkman_marker_or_append`:**
  - `SDKMan present — blank line precedes marker (H.a bug 3)` — asserts the line immediately before the SDKMan marker is blank after insertion.

All 425 Bats unit tests and all 89 venv integration tests pass.

---

## [1.14.0] - 2026-04-16

### Added — `pyve init --force` refreshes `project-guide` scaffolding via `project-guide update` (Story G.h)

First-time `pyve init` already runs `project-guide init` (Story G.c), but `pyve init --force` previously left `project-guide` scaffolding untouched: `project-guide init --no-input` silently no-ops with "already initialized" when `.project-guide.yml` exists, so template changes shipped by newer `project-guide` releases never reached user projects without manual intervention.

`pyve init --force` now branches based on `.project-guide.yml` presence:

- **Present (reinit case):** runs `project-guide update --no-input`. This is content-aware — it hash-compares each managed file, skips ones that already match, creates `.bak.<timestamp>` siblings for files the user has modified before overwriting, and preserves the config state (`current_mode`, overrides, `metadata_overrides`, `test_first`, `pyve_version`).
- **Absent (first time or previously skipped):** runs `project-guide init --no-input` as before.

Why `update` and not `init --force`: `project-guide init --force` is destructive — it resets `.project-guide.yml` to defaults (losing mode and overrides) with no backups. `update` is the correct command for ongoing template refreshes; `init --force` is reserved for the rare manual reset case. Pyve never auto-runs `init --force`, even on schema mismatch — that decision stays with the user.

The existing gate logic in `run_project_guide_hooks` is reused — no new flags:
- `--no-project-guide` / `PYVE_NO_PROJECT_GUIDE=1` still fully skips.
- `--project-guide` / `PYVE_PROJECT_GUIDE=1` still forces install.
- Auto-skip when `project-guide` is in project deps still applies.
- `project-guide update` failure (including a future `SchemaVersionError`) is surfaced as a warning and is non-fatal — `pyve init` continues.

### Added — `run_project_guide_update_in_env(backend, env_path)` helper

New helper in `lib/utils.sh`, mirroring `run_project_guide_init_in_env`. Invokes `project-guide update --no-input` in the project environment. Failure is non-fatal. Requires `project-guide >= 2.4.0` (earlier versions lack the `update` subcommand).

### Tests

- **Python integration — 4 new tests in `tests/integration/test_project_guide_integration.py::TestRefreshOnReinit`:**
  - `test_force_reinit_restores_modified_template_with_backup` — verifies a user-modified managed template (e.g., `developer/debug-guide.md`) is restored and a `.bak.<timestamp>` sibling is created
  - `test_force_reinit_skipped_by_no_project_guide` — verifies `--no-project-guide` still suppresses the refresh
  - `test_force_reinit_falls_back_to_init_when_config_absent` — verifies deleting `.project-guide.yml` forces the first-time `init` path
  - `test_force_reinit_update_failure_is_non_fatal` — verifies a corrupt `.project-guide.yml` (simulating future `SchemaVersionError`) surfaces a warning but does not abort `pyve init`
- **Bats unit — 3 new tests in `tests/unit/test_project_guide.bats`:**
  - `run_project_guide_update_in_env` passes `--no-input`, is a safe no-op when binary is missing, and is failure-non-fatal

---

## [1.13.3] - 2026-04-16

### Fixed — testenv built with system `python3` instead of project Python; not rebuilt on version change (Story G.g)

`ensure_testenv_exists()` in `pyve.sh` created the testenv venv with `python3` (the system/Homebrew Python) instead of `python` (the version-manager shim). In environments where Homebrew Python is on `PATH` before asdf shims (common on macOS), this caused the testenv to be built with the global default Python (e.g., 3.14.4) even when the project was configured for a different version (e.g., 3.12.13).

A second, compounding issue: `pyve init --force` calls `purge --keep-testenv`, which intentionally preserves the testenv across force-reinits so that dev tools don't need to be reinstalled. However, this also meant that a testenv built with the wrong Python version was never rebuilt, even after the user explicitly changed the project Python version and reran `pyve init --force --python-version 3.12.13`.

**Symptoms:** `pyve doctor` reported `Test runner Python: 3.14.4` while `Python: 3.12.13` — the testenv and project were on different Python versions. Neither `pyve python-version 3.12.13` nor `pyve init --force --python-version 3.12.13` resolved it.

**Root cause:** Two bugs:
1. `ensure_testenv_exists()` used `python3` (resolves to system/Homebrew Python) instead of `python` (resolves through asdf/pyenv shim to the project-configured version).
2. No version mismatch check — when an existing testenv's Python version differs from the project's current `python`, the testenv was silently kept rather than rebuilt.

**Fix:**
- Changed `python3 -m venv` to `python -m venv` in `ensure_testenv_exists()`.
- Added a version mismatch check: before skipping creation of an existing testenv, `ensure_testenv_exists()` reads `pyvenv.cfg`'s `version` field and compares it against the current `python` version. If they differ, the stale testenv is deleted and rebuilt automatically.

**User workaround (pre-fix):** `pyve testenv --purge && pyve testenv --init`

### Tests

- **Python integration — 1 new test in `tests/integration/test_testenv.py`:**
  - `test_testenv_rebuilt_when_python_version_stale` — corrupts an existing testenv's `pyvenv.cfg` to report version `9.9.9`, then calls `pyve testenv --init` and asserts the testenv was rebuilt with the real project Python.
- Full suite: **243 passing**, 26 skipped, 0 failures.

### Spec updates

- `docs/specs/features.md` — no changes (observable behavior unchanged for users whose testenv Python already matches).
- `docs/specs/tech-spec.md` — no changes.

---

## [1.13.2] - 2026-04-11

### Fixed — `prompt_install_pip_dependencies` installs into base asdf Python instead of venv (Story G.f)

`prompt_install_pip_dependencies()` in `lib/utils.sh` set `pip_cmd="pip"` for the venv backend. Because the venv is not yet activated during `pyve init` (direnv activation happens *after* init completes), bare `pip` resolved to `~/.asdf/shims/pip` — the asdf-python plugin's pip wrapper. This caused two problems:

1. **Packages installed into the base asdf Python** instead of the project venv. `pip install -e .` wrote to `~/.asdf/installs/python/<version>/lib/pythonX.Y/site-packages/` rather than `.venv/lib/`.
2. **asdf's pip wrapper auto-reshimmed** (`asdf reshim python` after every install), creating global shims (e.g., `~/.asdf/shims/project-guide`) for any console scripts the installed package declared. These shims persisted outside the venv, shadowed the correct venv binary, and reappeared every time `asdf reshim python` ran.

**Root cause:** `install_project_guide()` (same file) correctly used `$env_path/bin/pip` for the venv backend, but `prompt_install_pip_dependencies()` used bare `pip`. The call site in `pyve.sh` also did not pass the venv path.

**Fix:** `prompt_install_pip_dependencies()` now requires `env_path` for the venv backend and uses `$env_path/bin/pip`, matching the pattern in `install_project_guide()`. The call site in `pyve.sh` now passes the absolute venv path.

### Tests

- **Bats — 2 new tests in `tests/unit/test_utils.bats`:**
  - `prompt_install_pip_dependencies: venv backend uses env_path/bin/pip, not bare pip` — verifies the venv's pip is called (not the asdf shim) when `env_path` is provided
  - `prompt_install_pip_dependencies: venv backend without env_path returns error` — verifies the function returns 1 with a warning when `env_path` is missing, instead of falling back to bare `pip`
- Full bats suite: **419 passing**, 0 failures.

### Spec updates

- `docs/specs/tech-spec.md` — updated `prompt_install_pip_dependencies` entry in the helper functions table: `env_path` is now required (not optional) for both backends.
- `docs/specs/features.md` — no changes (observable behavior unchanged; this is a bugfix).

---

## [1.13.1] - 2026-04-11

### Fixed — `project-guide` shell-completion bugs (Story G.e)

Two bugs in the `pyve init` `project-guide` shell-completion step (step 3 of the three-step hook from G.c, v1.12.0). Both surfaced when the project owner ran `pyve init --project-guide-completion` against a daily-driver `~/.zshrc` and discovered the inserted block was non-functional and broke SDKMan's load order.

**Bug 1 — SDKMan-blind append.** `add_project_guide_completion()` in `lib/utils.sh` appended to the rc file via a plain `>> "$rc_path"` redirect. Pyve already had SDKMan-aware insertion logic in `install_prompt_hook()` (`pyve.sh`) that scans for the SDKMan end-of-file marker

```
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
```

and `awk`-inserts new content *above* it. G.c reimplemented its own append rather than reusing this convention. Result: the project-guide completion block landed *after* the SDKMan marker, demoting SDKMan from "last thing in the file" and breaking its load order for users with SDKMan installed.

**Bug 2 — Literal `\n` instead of newline + line continuation.** The eval block was emitted via:

```bash
printf "command -v project-guide >/dev/null 2>&1 && \\\n"
```

In a bash double-quoted string `\n` is *not* an escape — `n` is not in bash's double-quote escape set, so bash preserves both characters literally. The format string handed to `printf` was `\\n` (3 chars), which `printf` rendered as the 2-char sequence `\n` (backslash + literal `n`). The user's `~/.zshrc` ended up with this single broken line:

```
command -v project-guide >/dev/null 2>&1 && \n  eval "$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
```

Zsh parsed `\n` after `&&` as the literal command `n`, which doesn't exist. The `eval` never ran. `project-guide st<TAB>` produced no completion even after restarting the shell.

### Changed — refactored shared SDKMan-aware rc-file insertion

- **New helper** `insert_text_before_sdkman_marker_or_append(rc_path, content)` in `lib/utils.sh`. Handles both branches: SDKMan-marker present (insert above the marker via awk + getline-from-tempfile to work around BSD awk's no-newlines-in-`-v` limitation) and SDKMan absent (append to end). Always emits a leading blank line for round-trip symmetry with `remove_project_guide_completion()`.
- **`add_project_guide_completion()`** in `lib/utils.sh` rewritten to (a) build the eval block via an unquoted heredoc — `\\` + literal newline produces a real backslash + real newline (the `od -c` output is now `... & & \  \n` instead of `... & & \  \\  n`), and (b) delegate the rc-file insertion to the new helper.
- **`install_prompt_hook()`** in `pyve.sh` refactored to call the same helper instead of inlining its own SDKMan-marker awk. Behavior is preserved for users without the SDKMan marker; users with the marker continue to get the prompt-hook source line inserted above the marker. This refactor in the same release prevents the codebase from drifting back into two implementations.

### Tests

- **Bats — 13 new tests in `tests/unit/test_project_guide.bats`:**
  - `add_project_guide_completion: emits a real newline + backslash, not literal '\n'` — regression guard for bug 2 (asserts no literal `\n` in the file, asserts the `&& \` and `  eval` lines are separate)
  - `add_project_guide_completion: emitted block is syntactically valid zsh` — `zsh -n` parse-only check (skipped if zsh not on PATH)
  - `add_project_guide_completion: emitted block is syntactically valid bash` — `bash -n` parse-only check
  - `add_project_guide_completion: SDKMan absent — block appended to end` — happy-path regression guard
  - `add_project_guide_completion: SDKMan present — block inserted BEFORE the marker` — bug 1 fix verification
  - `add_project_guide_completion: SDKMan present — SDKMan section unchanged` — asserts the SDKMan marker line and its `sdkman-init.sh` payload survive insertion and remain the last non-blank lines
  - `add_project_guide_completion: SDKMan present — round-trip add+remove is byte-identical` — round-trip symmetry guarantee
  - Six tests for the new `insert_text_before_sdkman_marker_or_append` helper: SDKMan absent appends, SDKMan present inserts above marker, empty file, missing file, multi-line content preserved, multi-line content lands above marker
- Full bats suite: **417 passing** (404 pre-G.e + 13 new), 0 failures.
- Full pytest integration: **243 passing**, 26 environment-conditional skips, 0 real failures.

### Spec updates

- `docs/specs/tech-spec.md` — **project-guide rc-file Sentinel** section updated to document the new SDKMan-aware insertion path and the heredoc approach. **project-guide Helper Functions** table extended with `insert_text_before_sdkman_marker_or_append`.
- `docs/specs/features.md` — no changes (FR-16 still describes the same observable behavior).
- `docs/site/usage.md` — no changes (the user-facing description of the hook is unchanged; this is a bugfix, not a behavior change).

### Migration

Users who already have a broken `# >>> project-guide completion (added by pyve) >>>` block in `~/.zshrc` or `~/.bashrc` from v1.12.0 / v1.13.0 should remove it manually (or run `pyve self uninstall` to strip the sentinel block) and then re-run `pyve init --force --project-guide-completion` from a project, or hand-edit. There is intentionally no automated migration / legacy-detection path: the broken block is benign at runtime (zsh just runs the literal `n` command which fails silently), and the audience for this hotfix is small.

## [1.13.0] - 2026-04-11

### Changed — `docs/site/usage.md` overhaul + spec sync (Story G.d, FR-G3)

The MkDocs landing page at [`docs/site/usage.md`](docs/site/usage.md) had drifted significantly behind `pyve --help` and was further out of sync after the G.b subcommand refactor and G.c project-guide flags. This release brings it fully into sync with the v1.12.0 CLI surface in one coherent pass.

**What changed in `usage.md`:**

- **Migration callout** added near the top of the page documenting the six removed flag forms (`pyve --init`, `pyve --purge`, `pyve --validate`, `pyve --python-version`, `pyve --install`, `pyve --uninstall`) and their subcommand replacements, for users coming from <1.11 README snippets, blog posts, or LLM training data.
- **Command overview** reorganized into the four `pyve --help` categories: *Environment* (`init`, `purge`, `python-version`, `lock`), *Execution* (`run`, `test`, `testenv`), *Diagnostics* (`doctor`, `validate`), *Self management* (`self install`, `self uninstall`, `self`).
- **`init` reference** rewritten to document the full v1.12.0 surface: optional `<dir>` positional, plus all 17 options (`--python-version`, `--backend`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--no-lock`, `--env-name`, `--no-direnv`, `--auto-install-deps`, `--no-install-deps`, `--local-env`, `--update`, `--force`, `--allow-synced-dir`, `--project-guide`, `--no-project-guide`, `--project-guide-completion`, `--no-project-guide-completion`).
- **`init` project-guide hook section** added: three-step hook description, trigger logic table (priority order), auto-skip safety mechanism, CI default asymmetry (install yes, completion no), and the `--update` mode exemption — mirrors `pyve init --help` and the G.c CHANGELOG entry.
- **`purge` reference** rewritten with the optional `<dir>` positional and `--keep-testenv` option.
- **`python-version` reference** rewritten — old description ("Display Python version") was wrong; the command *sets* the local Python version by writing `.python-version`.
- **`testenv` reference** added as a top-level command section (was missing entirely): all four subcommands (`--init`, `--install [-r <file>]`, `--purge`, `run <command> [args...]`) with examples.
- **`self install` / `self uninstall` / `self`** added as top-level command sections (were missing entirely).
- **Environment variables table** expanded to document `PYVE_PROJECT_GUIDE`, `PYVE_NO_PROJECT_GUIDE`, `PYVE_PROJECT_GUIDE_COMPLETION`, `PYVE_NO_PROJECT_GUIDE_COMPLETION`.
- **`.project-guide.yml` and `docs/project-guide/`** mentioned in the configuration files section as committable artifacts that survive `pyve purge`.
- **CI/CD example** updated to show `PYVE_NO_PROJECT_GUIDE=1` as a recommended env var for CI runs.
- **All flag-form examples** (`pyve --init`, `pyve --purge`, `pyve --validate`, `pyve --python-version`, `pyve --uninstall`) replaced with subcommand form throughout.

**Sweep of `docs/site/`:** Two stale `./pyve.sh --install` references in [`docs/site/getting-started.md`](docs/site/getting-started.md) (manual installation and update sections) updated to `./pyve.sh self install`. The only remaining `pyve --<flag>` strings under `docs/site/` are in the intentional migration callout table in `usage.md`.

**Build verification:** `mkdocs build --strict` against the rewritten site builds clean using the same dependencies as [`.github/workflows/deploy-docs.yml`](.github/workflows/deploy-docs.yml) (`mkdocs-material` + `mkdocs-git-revision-date-localized-plugin`).

### Spec updates

- `docs/specs/stories.md` — Story G.d marked `[Done]`. All five top-level Phase G checklist items now `[x]`, marking Phase G complete.
- `docs/specs/features.md` and `docs/specs/tech-spec.md` — final cross-check pass, no changes needed. G.b and G.c already completed the spec sync work; both files already document the post-init project-guide hook, the four new flags, the four new env vars, and the subcommand surface. The remaining `pyve --init` / `pyve --purge` etc. references in `tech-spec.md` and `stories.md` are intentional historical documentation (the legacy-flag catch and the migration table from G.b.1).

### Tests

No automated tests (docs-only release). The existing `deploy-docs.yml` GitHub Actions workflow runs `mkdocs build --strict` on every push to main and is the authoritative gate for the rendered site.

## [1.12.0] - 2026-04-11

### Added — `project-guide` integration in `pyve init` (Story G.c, FR-G2 / FR-16)

`pyve init` (fresh init or `--force`) now wires [`project-guide`](https://pointmatic.github.io/project-guide/) into the project as an opinionated, opt-out post-init hook. The hook runs after the existing pip-deps prompt and consists of three steps:

1. **`pip install --upgrade project-guide`** — installs (or upgrades) project-guide into the project env. Always uses `--upgrade` so users get the latest. Default upgrade strategy (`only-if-needed`) so transitive deps aren't cascaded.
2. **`<env>/bin/project-guide init --no-input`** — runs the project-guide initializer in unattended mode to create `.project-guide.yml` and `docs/project-guide/` artifacts. Requires `project-guide >= 2.2.3`. Older versions degrade gracefully (failure non-fatal).
3. **Shell completion** — appends a sentinel-bracketed eval block to the user's `~/.zshrc` or `~/.bashrc` so `project-guide` tab-completion works in interactive shells.

**Trigger logic** (priority order, first match wins):

| Input | Behavior |
|---|---|
| `--no-project-guide` flag | Skip all three steps, no prompt |
| `--project-guide` flag | Run all three steps (overrides auto-skip) |
| `PYVE_NO_PROJECT_GUIDE=1` env var | Skip all three steps |
| `PYVE_PROJECT_GUIDE=1` env var | Run all three steps |
| **`project-guide` already in project deps** | **Auto-skip with INFO message** |
| Non-interactive (`CI=1` / `PYVE_FORCE_YES=1`) | Run install + init; skip completion (asymmetry) |
| Interactive (default) | Prompt: `Install project-guide? [Y/n]` |

**Auto-skip safety mechanism.** If `project-guide` is already declared as a dep in `pyproject.toml`, `requirements.txt`, or `environment.yml`, pyve auto-skips the entire hook with an informative message. The user's pin wins; pyve refuses to manage what the user already manages, avoiding a version conflict at the next `pip install -e .`. The explicit `--project-guide` flag overrides this auto-skip. Word-boundary regex prevents false matches with similar-named packages like `project-guide-extras`.

**`pyve init --update` does NOT run the hook** — preserves the minimal-touch promise of update mode. Users who want to refresh project-guide on update run `pyve init --force`.

**CI default asymmetry — install vs. completion.** Non-interactive mode defaults the install flow to **install** (matches the interactive default of Y), but defaults the completion flow to **skip**. Editing user rc files in unattended environments is the kind of surprise pyve avoids; explicit opt-in via `PYVE_PROJECT_GUIDE_COMPLETION=1` or `--project-guide-completion` is required.

**Failure handling.** All three steps are failure-non-fatal — pip failure, project-guide init failure, unwritable rc file, or unknown shell all log a warning and continue. `pyve init` itself still exits 0.

**Removal.** `pyve self uninstall` removes the completion sentinel block from both `~/.zshrc` and `~/.bashrc` (covering users who switched shells). The sentinel comments make this safe and idempotent.

**`pyve purge` does not touch `.project-guide.yml` or `docs/project-guide/`** — they're committable artifacts that survive purge.

### Added — new CLI flags on `pyve init`

- `--project-guide` / `--no-project-guide` — explicit opt-in / opt-out for the entire hook (mutually exclusive)
- `--project-guide-completion` / `--no-project-guide-completion` — explicit control over the rc-file step only (mutually exclusive)

### Added — new env vars

- `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE`
- `PYVE_PROJECT_GUIDE_COMPLETION` / `PYVE_NO_PROJECT_GUIDE_COMPLETION`

### Added — new helpers in `lib/utils.sh`

- `prompt_install_project_guide`, `prompt_install_project_guide_completion` — Y/n prompts respecting env vars and CI defaults
- `is_project_guide_installed(backend, env_path)` — fast import probe (`python -c 'import project_guide'`, ~50ms)
- `install_project_guide(backend, env_path)` — pip install --upgrade with backend dispatch (venv vs. micromamba)
- `run_project_guide_init_in_env(backend, env_path)` — invokes `project-guide init --no-input`
- `project_guide_in_project_deps()` — auto-skip detection across pyproject.toml, requirements.txt, environment.yml
- `detect_user_shell()`, `get_shell_rc_path(shell)` — shell + rc path detection
- `is_project_guide_completion_present(rc_path)` — sentinel detection
- `add_project_guide_completion(rc_path, shell)` — idempotent insertion
- `remove_project_guide_completion(rc_path)` — surgical removal (awk-based, BSD/GNU compatible)

Plus orchestrator `run_project_guide_hooks(backend, env_path, pg_mode, comp_mode)` in `pyve.sh` that resolves CLI flags into the helper protocol and sequences the three-step hook.

### Added — `uninstall_project_guide_completion` helper in `pyve.sh`

Called from `uninstall_self()` after the existing PATH/prompt-hook cleanup. Removes the project-guide completion sentinel block from both `~/.zshrc` and `~/.bashrc`.

### Changed
- `pyve init --help` now documents the three-step hook, the auto-skip safety mechanism, all four new flags, all four new env vars, the CI-default asymmetry, and the `--update` mode exemption.
- `pyve self uninstall --help` now documents the rc-file completion-block removal.

### Tests
- **Bats:** new `tests/unit/test_project_guide.bats` with 54 tests covering all 11 helpers — trigger logic for both prompt helpers (including the CI asymmetry), shell detection, rc-path mapping, sentinel detection, idempotent insertion (creating missing rc files), surgical removal preserving surrounding content, add→remove round-trip, `--upgrade` flag passthrough, `--no-input` flag passthrough, missing-binary safe no-ops, failure-non-fatal exit-code propagation, and the auto-skip detection matrix (pyproject.toml positive/negative/word-boundary/comments, requirements.txt positive/negative/word-boundary/comments, environment.yml positive/negative/comments, pip-nested deps).
- **Pytest integration:** new `tests/integration/test_project_guide_integration.py` with 11 tests across four classes:
  - `TestMutexFlags` — both flag pairs error on simultaneous use
  - `TestSkipPaths` — `--no-project-guide`, `PYVE_NO_PROJECT_GUIDE=1`, and the independent completion-skip flag
  - `TestAutoSkipWhenInProjectDeps` — auto-skip on pyproject.toml dep, auto-skip on requirements.txt dep, explicit `--project-guide` overrides auto-skip
  - `TestRealInstall` — three slow tests with real network: full three-step hook (install + artifacts + sentinel), CI asymmetry (install yes, completion no), idempotency timing
- Full bats suite: 404 tests passing (350 pre-G.c + 54 new). Full pytest integration: 242 passing, 26 environment-conditional skips, 0 real failures.

### Spec updates
- `docs/specs/features.md` — new FR-16 with full hook spec, 4 new modifier flags in **Optional Inputs** table, 4 new env vars in **Environment Variables** table, FR-1 updated to mention the post-init hook, FR-7 updated to mention the rc-file removal.
- `docs/specs/tech-spec.md` — 4 new flags in **Modifier Flags** table, new **project-guide rc-file Sentinel** section in **Cross-Cutting Concerns**, new **project-guide Helper Functions** section documenting all 11 helpers.
- Upstream dependency spec: [docs/specs/project-guide-no-input-spec.md](docs/specs/project-guide-no-input-spec.md) — proposed and implemented in `project-guide >= 2.2.3`.

### Changed — CI matrix narrowed to Python 3.12

The integration test matrix was narrowed from `['3.10', '3.11', '3.12']` to `['3.12']`, and the micromamba matrix was bumped from `['3.11']` to `['3.12']`. Both run on `[ubuntu-latest, macos-latest]`. This is a **6-job → 4-job reduction** (counting venv + micromamba matrices).

**Why now:**
- `project-guide >= 2.2.3` (the upstream dep newly required by FR-16) requires Python `>= 3.11`. The 3.10 matrix entry could not run the new `TestRealInstall` tests because pip refuses to install project-guide on 3.10. Rather than skip those tests on the 3.10 entry indefinitely, drop 3.10 from the matrix.
- The project owner (currently the only user) targets Python 3.12 for both venv and micromamba projects.
- Modern tooling (project-guide, etc.) and the conda ecosystem are converging on 3.12 as the practical baseline.

**What this implies:**
- Pyve no longer claims active support for Python 3.10 or 3.11. Venvs pyve creates likely still work on those versions, but they are not exercised in CI.
- `DEFAULT_PYTHON_VERSION` in `pyve.sh` is `3.14.4` (the latest stable as of v1.12.0). CI does NOT exercise the default — `PyveRunner.run()`'s auto-pin detects the runner's pyenv-installed 3.12 and pins that, so tests use 3.12 even though pyve's user-facing default is 3.14.4. This is a deliberate trade-off to avoid expensive source builds on each CI run; it's tracked as a follow-up story (see "Investigate Python 3.14 CI testing" in `docs/specs/stories.md`).
- The `SKIP_PYTHON_TOO_OLD` mark on `TestRealInstall` is kept as a no-op safety net. It costs nothing and protects future contributors who might run the tests locally on older Python.

### Test infrastructure changes (`tests/helpers/pyve_test_helpers.py`)

Two changes were needed to make the project-guide tests pass on CI runners:

1. **Auto-pin Python for `pyve.run("init", ...)` invocations.** The existing `PyveRunner.init()` method already detected the runner's Python and pinned it via `--python-version`, but `PyveRunner.run("init", ...)` (used by tests that need to pass extra CLI flags) bypassed that logic. Centralized the pin into `_auto_pin_python_for_init()` so any subprocess invocation targeting the `init` subcommand inherits the pin automatically. Skipped when `--help` / `-h` is in args (the dispatcher's help intercept needs `--help` to be the immediate next arg after `init`).

2. **`PYVE_NO_PROJECT_GUIDE=1` is now a test-runner default.** Tests opt out of the project-guide hook by default (same pattern as the existing `PYVE_NO_INSTALL_DEPS` / `PYVE_NO_LOCK` defaults). Tests that actually want to test the project-guide hook opt in via `PYVE_TEST_ALLOW_PROJECT_GUIDE=1`. This isolates every existing test from the new hook's side effects (network calls, `.gitignore` mutations, rc-file edits) and prevents the kind of regression we caught on the Ubuntu CI run where `test_gitignore_idempotent` failed because the project-guide hook ran successfully and modified `.gitignore` non-idempotently.

## [1.11.0] - 2026-04-10

### ⚠️ BREAKING CHANGE — CLI surface migrated from flags to subcommands

The flag-style top-level CLI is replaced with a subcommand-style CLI consistent with modern developer tooling (`git`, `cargo`, `kubectl`, `gh`). This is a clean break — no deprecation cycle, no silent translation.

| Old (removed) | New |
|---|---|
| `pyve --init [dir]` | `pyve init [dir]` |
| `pyve --purge [dir]` | `pyve purge [dir]` |
| `pyve --validate` | `pyve validate` |
| `pyve --python-version <ver>` | `pyve python-version <ver>` |
| `pyve --install` | `pyve self install` |
| `pyve --uninstall` | `pyve self uninstall` |

**Migration:** invoking a removed flag form prints a precise migration error and exits non-zero — e.g. `ERROR: 'pyve --init' is no longer supported. Use 'pyve init' instead.` This catch is kept forever (Decision D3): users coming from old README snippets, blog posts, or LLM training data will hit it for years and get a clear hint instead of an opaque "unknown command" error.

**Unchanged:** `pyve run`, `pyve lock`, `pyve doctor`, `pyve test`, `pyve testenv [...]`, and the universal flags `--help` / `--version` / `--config`. All modifier flags (`--backend`, `--force`, `--update`, `--no-direnv`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--no-lock`, `--allow-synced-dir`, `--env-name`, `--local-env`, `--keep-testenv`) keep their names and continue to attach to their renamed subcommands.

**Short flag aliases dropped (Decision D1):** `-i` and `-p` are removed. Subcommands are already short; users who want fewer keystrokes can write a shell alias.

**`pyve self` namespace (Decision D4):** `pyve self` with no subcommand prints just the namespace help (mirrors `git remote`, `kubectl config`).

### Added
- Subcommand routing in `main()` dispatcher: `init`, `purge`, `validate`, `python-version`, and the `self` namespace (`self install`, `self uninstall`).
- `legacy_flag_error()` helper in `pyve.sh`: emits the precise migration error for any removed flag form.
- `show_self_help()` and `self_command()` helpers in `pyve.sh`: dispatch and print help for the `self` namespace.
- `tests/unit/test_cli_dispatch.bats`: 20 black-box bats tests covering subcommand routing, the legacy-flag catch, the `self` namespace, modifier-flag preservation, and universal-flag regression guards. Uses a test-only `PYVE_DISPATCH_TRACE=1` hook (gated in `main()`) so routing assertions don't trigger the real handlers.
- `tests/integration/test_subcommand_cli.py`: 20 end-to-end pytest cases exercising every renamed subcommand against a temp project, the legacy-flag catch (parameterized over all six removed flags), and the universal-flag regression guards.

### Changed
- All user-visible runtime strings in `pyve.sh` and `lib/*.sh` that previously emitted `pyve --init` / `pyve --purge` / `pyve --validate` / etc. now emit the subcommand form (e.g. `pyve init --force`, `pyve validate`, `pyve init --no-lock`). Affects help/error guidance from `lib/version.sh`, `lib/micromamba_core.sh`, `lib/micromamba_bootstrap.sh`, `lib/micromamba_env.sh`, `lib/utils.sh`, and the `pyve lock` success guidance.
- `show_help()` USAGE/COMMANDS/EXAMPLES sections rewritten to reflect the subcommand surface. *(Note: per-subcommand `--help` plumbing and the full category reorganization — Environment / Execution / Diagnostics / Self management — are deferred to G.b.2.)*
- `tests/helpers/pyve_test_helpers.py` `PyveRunner.init()` and `PyveRunner.purge()` now emit the subcommand form (`init` / `purge` instead of `--init` / `--purge`).

### Tests
- Repo-wide sweep of `tests/integration/*.py` and `tests/unit/*.bats`: every legacy `pyve.run("--init", ...)` / `pyve.run("--purge", ...)` / `pyve.run("--validate", ...)` invocation rewritten to subcommand form. Affected files: `test_validate.py`, `test_reinit.py`, `test_micromamba_workflow.py`, `test_force_ambiguous_prompt.py`, `test_force_backend_detection.py`, `test_lock_command.py`, `test_pip_upgrade.py`, `test_auto_detection.py`, `test_testenv.py`, `test_doctor.bats`. CI's legacy-flag catch surfaces any miss as a clean failure.
- Full suite green after the swap: 330 bats unit tests + 213 pytest integration tests pass (26 environment-conditional skips).

### Added (G.b.2 — Per-subcommand `--help` plumbing, FR-G4)
- **Per-subcommand `--help`** for every renamed subcommand from G.b.1. `pyve init --help`, `pyve purge --help`, `pyve validate --help`, `pyve python-version --help`, `pyve self --help`, `pyve self install --help`, and `pyve self uninstall --help` all print a focused man-page-style block and exit 0 **before** the real handler runs — no side effects, no filesystem mutation, no slow Python install. `-h` is accepted everywhere `--help` is.
- `show_init_help()`, `show_purge_help()`, `show_validate_help()`, `show_python_version_help()`, `show_self_install_help()`, `show_self_uninstall_help()` helper functions in `pyve.sh`. Each opens with a strict marker line of the form `pyve <sub> - <one-line summary>` so tests can assert on exactly the right help block.
- `main()` dispatcher: each new subcommand arm now intercepts `--help` / `-h` immediately after `shift`, before the `PYVE_DISPATCH_TRACE` hook and before the handler call. `self_command()` does the same for `install` and `uninstall`.
- `tests/unit/test_subcommand_help.bats`: 20 black-box bats tests covering every per-subcommand `--help` / `-h`, the four top-level section headers, and two regression guards (`pyve init --help` must not create `.venv`, `pyve purge --help` must not delete files).
- `tests/integration/test_subcommand_cli.py`: 19 new pytest cases (14 parameterized per-subcommand `--help` smoke tests, 4 parameterized top-level section-header tests, 1 regression guard).

### Changed (G.b.2)
- **`pyve --help` reorganized into four categories** (FR-G4): *Environment* (`init`, `purge`, `python-version`, `lock`), *Execution* (`run`, `test`, `testenv`), *Diagnostics* (`doctor`, `validate`), *Self management* (`self install`, `self uninstall`, `self`). Each subcommand entry is a one-line summary with a pointer to its own `--help` for full options. Replaces the single flat `COMMANDS:` dump from v1.10.0.

### Deferred to later Phase G stories
- Sweep of `docs/site/`, `docs/specs/`, `README.md`, and other docs for legacy flag references: G.b.3.
- `project-guide` integration in `pyve init` (FR-G2): G.c (v1.12.0).
- `usage.md` overhaul (FR-G3): G.d (v1.13.0).

## [1.10.0] - 2026-04-09

### Added
- `pyve testenv run <command> [args...]`: execute any command inside the dev/test runner environment (`.pyve/testenv/venv`). Supports dev tools like ruff, mypy, and black that should live in the testenv rather than the project venv. If the command binary exists in the testenv's `bin/`, it is executed directly; otherwise the testenv's `bin/` is prepended to PATH.

## [1.9.1] - 2026-04-08

### Fixed
- `pyve doctor` now detects relocated venv projects: when a project directory is moved after venv creation, `pyvenv.cfg` retains the original path, silently breaking environment activation (`which python` resolves to the system shim instead of `.venv/bin/python`). Doctor now compares the `pyvenv.cfg` creation path against the current project directory and warns with a `pyve --init --force` remediation when they differ.

### Added
- `doctor_check_venv_path()` function in `lib/utils.sh`: extracts the venv creation path from `pyvenv.cfg` and compares it against the actual venv location.

## [1.9.0] - 2026-03-20

### Added
- `pyve lock` command: generates or updates `conda-lock.yml` for the current platform (micromamba projects only). Automatically detects the conda platform string via `get_conda_platform()` (`osx-arm64`, `osx-64`, `linux-64`, `linux-aarch64`), runs `conda-lock -f environment.yml -p <platform>`, suppresses the misleading `conda-lock install` post-run message, and prints actionable `pyve --init --force` guidance instead. Exits with an "already up to date" message when the spec hash is unchanged. Fails early with clear messages when the project uses the venv backend, when `conda-lock` is not on PATH, or when `environment.yml` is missing.
- `pyve lock --check`: mtime-only verification flag for CI/CD pipelines. Compares `environment.yml` and `conda-lock.yml` modification times without invoking `conda-lock` (does not require `conda-lock` to be installed). Exits 0 if up to date, 1 if stale or missing. Suitable as a pre-build gate to catch uncommitted lock file updates.

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
