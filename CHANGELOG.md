# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
