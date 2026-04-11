# stories.md — pyve

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

---

## Phase G: UX Improvements
- [x] add `pyve testenv run <command>` subcommand
- [x] draft a `concept.md` file to capture the core ideas and value proposition
- [x] integrate `project-guide` as a default tool (see G.c)
- [x] refactor pyve CLI to use subcommands instead of flags (see G.b / G.b.1 / G.b.2 / G.b.3)
- [x] landing page (usage.md) updates (see G.d)

### Story G.a: v1.10.0 `pyve testenv run <command>` — Run Dev Tools in the Test Environment [Done]

Today `pyve testenv` can `--init`, `--install`, and `--purge` the dev/test runner environment (`.pyve/testenv/venv`), and `pyve test` executes `pytest` inside it. But there is no general-purpose way to run other dev tools (ruff, mypy, black, pre-commit, etc.) that are installed in the testenv.

Users must either invoke the hidden path directly (`.pyve/testenv/venv/bin/ruff check .`) or pollute the project venv with dev-only dependencies (`pyve run pip install ruff`). Neither is discoverable or consistent with Pyve's design.

**Motivation:** Dev/lint/type-check tools belong in the testenv, not the project venv. The testenv already survives `pyve --init --force` and `pyve --purge`, making it the right home for tools whose versions shouldn't drift with environment rebuilds. A `pyve testenv run` subcommand completes the lifecycle: install once, run anywhere, survive rebuilds.

**Command behavior**

```
pyve testenv run <command> [args...]
```

- Executes `<command>` inside `.pyve/testenv/venv` by prepending its `bin/` to PATH — same pattern as `pyve run` uses for the project venv.
- If the testenv doesn't exist, fail with: `ERROR: Dev/test runner environment not initialized. Run: pyve testenv --init`
- If `<command>` is found in `.pyve/testenv/venv/bin/`, exec it directly.
- Otherwise, export `VIRTUAL_ENV` and prepend `bin/` to PATH, then exec `<command>` (allows system commands that need the testenv's Python on PATH).
- Propagate the command's exit code.
- No arguments → error with usage hint.

**Examples**

```bash
pyve testenv --install -r requirements-dev.txt   # install ruff, mypy, etc.
pyve testenv run ruff check .                    # run ruff from testenv
pyve testenv run mypy src/                       # run mypy from testenv
pyve testenv run python -m pytest --co -q        # alternative to pyve test
```

**Implementation checklist**

- [x] Add `run` action to `testenv_command()` in `pyve.sh`
  - [x] Parse `run` as a new action; `break` to collect remaining args as the command
  - [x] Verify testenv exists (`.pyve/testenv/venv/bin/python`); error if missing
  - [x] If command binary exists in testenv `bin/`, exec it directly
  - [x] Otherwise, export `VIRTUAL_ENV` and prepend testenv `bin/` to PATH, then exec
  - [x] No command → error with usage
- [x] Update `pyve --help` output
  - [x] Usage line: `pyve testenv --init | --install [-r <req.txt>] | --purge | run <command> [args...]`
  - [x] Commands section: add `run` to the testenv description
  - [x] Examples: added `pyve testenv run ruff check .` and `pyve testenv run mypy src/`
- [x] Update `pyve testenv --help` output to document `run`
- [x] Update `docs/site/usage.md`: added `testenv` entries to command overview table and full `testenv` reference section

**Spec updates**

- [x] `docs/specs/features.md`: updated FR-11 to include `testenv run`
- [x] `docs/specs/tech-spec.md`: added `testenv --install`, `testenv --purge`, `testenv run` to Commands table

**Tests**

- [x] Integration test: `pyve testenv run` with no command → error with usage
- [x] Integration test: `pyve testenv run` before `--init` → error with init hint
- [x] Integration test: `pyve testenv run python --version` → succeeds, prints version
- [x] Integration test: `pyve testenv run` propagates non-zero exit code (exit 42)

- [x] Update CHANGELOG.md with v1.10.0 entry
- [x] Bump VERSION to 1.10.0

### Story G.b: CLI Subcommand Refactor — Planning [Done]

Pyve's top-level CLI is a mix of flag-style commands (`pyve --init`, `pyve --purge`, `pyve --validate`, `pyve --python-version`, `pyve --install`, `pyve --uninstall`) and bare subcommands (`pyve run`, `pyve doctor`, `pyve test`, `pyve testenv`, `pyve lock`). The original G.b story bundled the dispatcher refactor, the per-subcommand `--help` plumbing, the `print_help()` reorganization, two new test files, a mechanical sweep across ~11 pytest files plus several bats files, README, two spec docs, VERSION, and CHANGELOG into one story. That's too much surface area for a single TDD cycle and a single review gate.

This planning story breaks G.b into three sub-stories so each has a focused review gate and CI stays green between merges.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G1 and FR-G4 for full design.

**Sub-story summary**

| Sub-story | Version | Scope |
|---|---|---|
| G.b.1 | v1.11.0 | Dispatcher refactor + legacy-flag catch + test sweep (atomic — CI red→green window) |
| G.b.2 | folds into v1.11.0 (or v1.11.1 if shipped after) | Per-subcommand `--help` plumbing + `print_help()` reorganization |
| G.b.3 | docs-only, no version bump | README + features.md + tech-spec.md sync (excludes `usage.md`, owned by G.d) |

**Why this split**

- **G.b.1 must be atomic.** The moment the dispatcher changes, every legacy-flag invocation in the test suite fails. The sweep cannot be deferred without leaving CI red between merges. Bundling the dispatcher rewrite with the sweep keeps the diff focused on a single concern: "rename the CLI surface".
- **G.b.2 is pure UX, no behavior change.** Help text bikeshedding shouldn't hold up the dispatcher refactor.
- **G.b.3 is pure prose.** Reviewable in a text editor without running tests.

**Planning checklist**

- [x] Decide breakdown (3 sub-stories vs monolithic)
- [x] Replace this G.b body with sub-story sections in `stories.md`
- [x] Confirm `usage.md` overhaul stays in G.d (out of scope for G.b.*)

### Story G.b.1: v1.11.0 Dispatcher Refactor + Legacy-Flag Catch + Test Sweep [Done]

Replace the flag-style top-level dispatcher with subcommand routing and sweep every test invocation in one story. **Atomic by necessity:** the moment the dispatcher changes, every `pyve --init` / `pyve --purge` / etc. in the test suite fails, so the sweep cannot be deferred.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G1 and Decision D1 (drop short aliases), D3 (legacy-flag catch lifetime), D4 (`pyve self` with no subcommand).

**Command behavior**

```
Old → New
pyve --init [dir]            → pyve init [dir]
pyve --purge [dir]           → pyve purge [dir]
pyve --validate              → pyve validate
pyve --python-version <ver>  → pyve python-version <ver>
pyve --install               → pyve self install
pyve --uninstall             → pyve self uninstall
```

Unchanged: `pyve run`, `pyve lock`, `pyve doctor`, `pyve test`, `pyve testenv`, `pyve --help`, `pyve --version`, `pyve --config`.

- All modifier flags (`--backend`, `--force`, `--update`, `--no-direnv`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--no-lock`, `--allow-synced-dir`, `--env-name`, `--local-env`, `--keep-testenv`) keep their names and attach to their renamed subcommands.
- Short flag aliases (`-i`, `-p`) for top-level commands are **removed**. Users who want fewer keystrokes write a shell alias.
- Legacy flag forms print a precise migration error and exit non-zero — kept forever:
  ```
  ERROR: 'pyve --init' is no longer supported. Use 'pyve init' instead.
  See: pyve --help
  ```
- `pyve self` with no subcommand prints the `self` namespace help only (mirrors `git remote`, `kubectl config`).
- **Per-subcommand `--help` plumbing for the new subcommands is deferred to G.b.2.** G.b.1 only needs to ensure `pyve <new-sub> --help` doesn't crash; it can fall through to top-level help if necessary.

**Examples**

```bash
pyve init                              # was: pyve --init
pyve init --backend micromamba         # was: pyve --init --backend micromamba
pyve init my_venv --no-direnv          # was: pyve --init my_venv --no-direnv
pyve purge --keep-testenv              # was: pyve --purge --keep-testenv
pyve python-version 3.12.0             # was: pyve --python-version 3.12.0
pyve self install                      # was: pyve --install
pyve self uninstall                    # was: pyve --uninstall
```

**Implementation checklist**

- [x] Refactor top-level dispatcher in `pyve.sh`
  - [x] Replace top-level `case` block in `main()` (currently around [pyve.sh:2161](pyve.sh#L2161)) with subcommand routing
  - [x] Locate and refactor the "pre-pass" `case` block referenced by the planning doc at ~pyve.sh:1189 (resolved: no separate pre-pass exists today — line 1189 is inside `testenv_command()`'s inner case block, which is testenv-scoped and unchanged. All top-level dispatch lives in `main()`.)
  - [x] Add `self` namespace dispatcher (`self install`, `self uninstall`)
  - [x] `pyve self` (no subcommand) → print namespace help only
  - [x] Add legacy-flag error catch for `--init`, `--purge`, `--validate`, `--install`, `--uninstall`, `--python-version` with the precise migration message
  - [x] Drop `-i` / `-p` short aliases from top-level
- [x] Update `tests/helpers/pyve_test_helpers.py` `PyveRunner` methods (`init()`, `purge()`, `version()`, etc.) to emit subcommand form
- [x] Repo-wide sweep for legacy flag invocations in test code only (docs sweep is G.b.3)
  - [x] All `tests/integration/*.py` test invocations
  - [x] All `tests/unit/*.bats` references
  - [x] Any test fixtures, conftest.py, or helper scripts that still spell out the flag form

**Bonus (in scope by necessity):** swept legacy `pyve --init` / `pyve --purge` / etc. strings out of `pyve.sh` runtime output and `lib/*.sh` (`lib/version.sh`, `lib/micromamba_core.sh`, `lib/micromamba_bootstrap.sh`, `lib/micromamba_env.sh`, `lib/utils.sh`). Without this, runtime error/info messages would point users at commands the new dispatcher rejects. `show_help()` USAGE/COMMANDS/EXAMPLES were also rewritten to subcommand form (full category reorganization deferred to G.b.2 per the planning doc).

**Tests**

- [x] Bats: new `tests/unit/test_cli_dispatch.bats` (20 tests, all green)
  - [x] Each new subcommand routes to the correct handler (`init`, `purge`, `validate`, `python-version`)
  - [x] `pyve self install` and `pyve self uninstall` route correctly
  - [x] `pyve self` with no arg prints namespace help only and exits 0 (asserts on strict marker line `Usage: pyve self <subcommand>`)
  - [x] Each removed legacy flag (`--init`, `--purge`, `--validate`, `--install`, `--uninstall`, `--python-version`) prints the migration error and exits non-zero
  - [x] `-i` and `-p` short flags are no longer recognized (exit non-zero)
  - Note: routing assertions use a test-only `PYVE_DISPATCH_TRACE=1` hook in `main()` so they don't trigger real handlers (filesystem mutation, slow Python install, etc.)
- [x] pytest: new `tests/integration/test_subcommand_cli.py` (20 tests, all green)
  - [x] `pyve init`, `pyve purge`, `pyve validate`, `pyve python-version`, `pyve self install`, `pyve self uninstall` execute their handlers black-box
  - [x] Modifier flags still work attached to subcommands (e.g., `pyve init --backend venv --no-direnv`, `pyve purge --keep-testenv`)
- [x] Full bats and pytest suites pass after the dispatcher swap: 330 bats unit tests + 213 pytest integration tests pass (26 environment-conditional skips, 0 failures)
- [ ] `make coverage-kcov` not regressed on dispatcher coverage *(not run locally — CI gate)*

- [x] Update CHANGELOG.md with v1.11.0 entry — note the breaking CLI change prominently at the top
- [x] Bump VERSION to 1.11.0

### Story G.b.2: Per-Subcommand `--help` Plumbing + `print_help()` Reorganization [Done]

Pure UX enhancement on top of the new dispatcher from G.b.1. No CLI behavior change. **Folded into v1.11.0** — the whole phase ships as one PR, so G.b.1 and G.b.2 are released together.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G4.

**Implementation checklist**

- [x] Add per-subcommand `--help` text for `init`, `purge`, `validate`, `python-version`, `self`, `self install`, `self uninstall` (those that don't already have it after G.b.1; `testenv` already has it from G.a)
- [x] Reorganize `print_help()` into four categories: *Environment*, *Execution*, *Diagnostics*, *Self management*
  - Placement: `init`/`purge`/`python-version`/`lock` → Environment, `run`/`test`/`testenv` → Execution, `doctor`/`validate` → Diagnostics, `self install`/`self uninstall`/`self` → Self management.
- [x] Verify each subcommand `--help` is reachable through the dispatcher (returns 0, prints non-empty)

**Tests**

- [x] Bats: new `tests/unit/test_subcommand_help.bats` (20 tests, all green)
  - [x] `pyve <sub> --help` returns 0 and prints a non-empty block for each new subcommand (tests both `--help` and `-h`)
  - [x] `pyve --help` output contains all four section headers (*Environment*, *Execution*, *Diagnostics*, *Self management*)
  - [x] Regression guards: `pyve init --help` does not create `.venv`, `pyve purge --help` does not delete files. Proves the `--help` intercept runs BEFORE the real handler.
- [x] pytest: extended `tests/integration/test_subcommand_cli.py` (+19 tests, all green)
  - [x] Per-subcommand `--help` smoke test for the renamed subcommands (14 parameterized cases covering `--help` and `-h` for each subcommand + strict marker line assertion)
  - [x] 4 parameterized top-level section-header tests
  - [x] 1 regression guard: `pyve init --help` doesn't create `.venv`

- [x] Folded into v1.11.0 (no separate version bump). CHANGELOG.md v1.11.0 entry gained a dedicated G.b.2 section.

### Story G.b.3: CLI Refactor Doc + Spec Sync [Done]

Pure documentation. Excludes [docs/site/usage.md](docs/site/usage.md), which is owned by G.d. No code changes, no tests, no version bump (per the docs-only convention in this `stories.md` header).

**Implementation checklist**

- [x] Update [README.md](README.md) examples from flag form to subcommand form
  - Bulk-converted all `pyve --init` / `pyve --purge` / `pyve --validate` / `pyve --python-version` / `pyve --uninstall` / `./pyve.sh --install` / `/tmp/pyve/pyve.sh --install` to subcommand form.
  - Removed the `pyve -i` / `pyve -p` "Short form" example lines (short aliases dropped in G.b.1).
  - Rewrote the "All Commands" block into five groups (Environment / Execution / Diagnostics / Self management / Universal flags) mirroring the new top-level `pyve --help` layout from G.b.2, and added a "Per-command help" pointer line.
  - Fixed the direnv "Requirements" bullet to reference `pyve init` and `pyve python-version`.
- [x] Sweep `docs/` (excluding `docs/site/usage.md` and `docs/specs/.archive/`) for any remaining `pyve --init` / `pyve --purge` / `pyve --validate` / `pyve --install` / `pyve --uninstall` / `pyve --python-version` strings and fix them
  - Cleaned: `docs/site/ci-cd.md`, `docs/site/backends.md`, `docs/site/getting-started.md`, `docs/site/index.html`, `docs/specs/concept.md`, `docs/specs/brand-descriptions.md`, `docs/specs/pyve-run-examples.md`, `docs/specs/testing-spec.md`.
  - Also cleaned top-level docs: `CONTRIBUTING.md`, `SECURITY.md`, `tests/README.md`.
  - Also cleaned stale docstrings in integration test files: `test_force_ambiguous_prompt.py`, `test_force_backend_detection.py`, `test_pip_upgrade.py`, `test_lock_command.py` (docstring references only — test invocations were already converted in G.b.1).
  - **Deliberately left alone** (intentional historical/narrative references): `docs/specs/phase-g-ux-improvements-plan.md` (planning doc for this refactor), `docs/specs/stories.md` (story history and Old→New tables), `CHANGELOG.md` v1.11.0 breaking-change section, `docs/specs/tech-spec.md` Legacy-Flag Error Catch section, `pyve.sh` dispatcher catch, `tests/unit/test_cli_dispatch.bats` (tests the catch itself).

**Spec updates**

- [x] `docs/specs/features.md`
  - [x] Replaced flag list in **Inputs > Required** with the subcommand list plus a note that legacy flag forms were removed in v1.11.0 (Decision D3)
  - [x] Updated FR-1 (`pyve init`), FR-2 (`pyve purge`), FR-3 (`pyve python-version`), FR-6 (`pyve validate`), FR-7 (`pyve self install` / `pyve self uninstall`) headings and invocation syntax
  - [x] Updated Core Requirements bullet 8 and Usability Requirements bullet 2 to reflect the dropped short aliases and new `self` namespace
- [x] `docs/specs/tech-spec.md`
  - [x] Rewrote **CLI Design > Commands** table to the subcommand surface (flat list with `pyve <sub>` syntax instead of the old two-part flag table)
  - [x] Documented the `self` namespace (`self install`, `self uninstall`, and `self` with no subcommand → namespace help only)
  - [x] Added a new **Per-Subcommand Help** subsection describing the G.b.2 `--help` plumbing and the four top-level categories
  - [x] Updated the **Modifier Flags** table to show each flag attached to its renamed subcommand (e.g. `pyve init` instead of `--init`)
  - [x] Added a dedicated **Legacy-Flag Error Catch** subsection to **Cross-Cutting Concerns** documenting the Decision D3 catch (kept forever, precise migration error, no compat shim)

---

### Story G.c: v1.12.0 `project-guide` Integration in `pyve init` [Done]

[`project-guide`](https://pointmatic.github.io/project-guide/) is the developer's standard project bootstrap tool and is now installed in every Pyve project the developer touches. Today users have to remember to `pip install project-guide` and run `project-guide init` manually after `pyve init` finishes. Wire it into `pyve init` so it's a one-command setup.

**Motivation:** Pyve's promise is to collapse repetitive setup tasks. Installing `project-guide` is part of that ritual for every new project. Wiring it into `pyve init` (with opt-out) makes the LLM-assisted workflow available from the first command, while keeping Pyve's "self-contained microcosm" philosophy: the install goes into the project env via `pip`, not pipx or system Python, and the resulting `.project-guide.yml` + `docs/project-guide/` artifacts get committed alongside `.pyve/config` so a fresh clone reproduces the same setup on any machine or container.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G2 and Decision D2 for full design.

**Command behavior**

`pyve init` gains a final post-environment step that installs `project-guide` into the project env via `pip`:

| Backend | Install command |
|---|---|
| `venv` | `<venv>/bin/pip install project-guide` |
| `micromamba` | `micromamba run -p <prefix> pip install project-guide` |

**Trigger logic** (priority order, first match wins):

| Input | Behavior |
|---|---|
| `--no-project-guide` flag | Skip, no prompt |
| `--project-guide` flag | Install, no prompt |
| `PYVE_NO_PROJECT_GUIDE=1` env var | Skip, no prompt |
| `PYVE_PROJECT_GUIDE=1` env var | Install, no prompt |
| Non-interactive (`CI=1` or `PYVE_FORCE_YES=1`) | Install (matches interactive default) |
| Interactive (default) | Prompt: `Install project-guide? (Y/n) [Y]` |

- `--project-guide` and `--no-project-guide` are mutually exclusive — using both is a hard error.
- **Idempotent**: no-op if `project-guide` is already importable from the project env's Python.
- **Failure is non-fatal**: a failed `pip install project-guide` warns with the underlying pip stderr and a `--no-project-guide` hint, then `pyve init` continues. Pyve's job is environment setup; project-guide is a value-add.

**Shell completion wiring (one-time, user-global)**

After `project-guide` is successfully installed (whether prompted, flagged, or env-var-driven), Pyve also offers to add the shell completion eval line to the user's shell rc file. **Why this can't be done via direnv `.envrc`:** direnv only propagates *environment variables* from a bash subprocess into the parent shell — shell completions are internal builtin state (`compdef`/`_comps` in zsh, `complete` in bash), not env vars. They have to live in the user's interactive shell config to take effect. Since this is user-global rather than per-project, Pyve only does this once (idempotent — it checks before inserting).

- **Detection**: Pyve reads `$SHELL` to determine zsh vs bash. Other shells (fish, etc.) are skipped with a warning that points to `_PROJECT_GUIDE_COMPLETE=<shell>_source` for manual setup.
- **Target file**: `~/.zshrc` for zsh, `~/.bashrc` for bash.
- **Inserted block** (zsh example):
  ```bash
  # >>> project-guide completion (added by pyve) >>>
  command -v project-guide >/dev/null 2>&1 && \
    eval "$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
  # <<< project-guide completion <<<
  ```
  The `command -v` guard means it's a no-op in shells where `project-guide` isn't yet on PATH.
- **Trigger logic** (parallels the install flow):

  | Input | Behavior |
  |---|---|
  | `--no-project-guide-completion` flag | Skip, no prompt |
  | `--project-guide-completion` flag | Add, no prompt |
  | `PYVE_NO_PROJECT_GUIDE_COMPLETION=1` env var | Skip, no prompt |
  | `PYVE_PROJECT_GUIDE_COMPLETION=1` env var | Add, no prompt |
  | Non-interactive (`CI=1` or `PYVE_FORCE_YES=1`) | **Skip** (touching shell rc files in CI is surprising) |
  | Interactive, completion block already present | Skip silently (idempotent) |
  | Interactive, completion block missing | Prompt: `Add project-guide shell completion to ~/.zshrc? (Y/n) [Y]` |

  Note the deliberate asymmetry with the install flow: CI defaults to **skip** here, not install. Modifying user rc files in an unattended environment is the kind of surprise Pyve avoids.
- `--project-guide-completion` and `--no-project-guide-completion` are mutually exclusive.
- **Idempotency**: detected via the `# >>> project-guide completion (added by pyve) >>>` sentinel. Already-present blocks are never duplicated.
- **Removal**: `pyve self uninstall` removes the completion block from the rc file (mirrors how it removes the `~/.local/bin` PATH entry today). The block's sentinel comments make this safe.
- **Failure is non-fatal**: rc file unwritable, unknown shell, etc. → warn and continue. project-guide is still installed and functional; the user just won't get tab completion until they manually add the line.

**Examples**

```bash
pyve init                                       # prompts: Install project-guide? Add completion?
pyve init --project-guide                       # install without prompting
pyve init --no-project-guide                    # skip without prompting
PYVE_NO_PROJECT_GUIDE=1 pyve init               # skip via env var (CI override)
pyve init --backend micromamba                  # also installs project-guide via micromamba pip
pyve init --project-guide --no-project-guide-completion  # install pkg, skip rc-file edit
```

**Implementation checklist**

- [x] Add helper functions to `lib/utils.sh`
  - [x] `is_project_guide_installed(backend, env_path)` — probes via `<env_python> -c 'import project_guide'`. Module name confirmed from `project_guide-2.0.20.dist-info/entry_points.txt`. ~50ms latency.
  - [x] `install_project_guide(backend, env_path)` — runs `pip install --upgrade project-guide` (always upgrade per user requirement). Default upgrade strategy (`only-if-needed`) so transitive deps don't cascade. Warn-don't-fail on error.
  - [x] `prompt_install_project_guide()` — Y/n prompt with default Y; respects env vars; respects `CI` / `PYVE_FORCE_YES`
  - [x] `run_project_guide_init_in_env(backend, env_path)` — **new helper added during implementation** (not in original checklist). Runs `<env>/bin/project-guide init --no-input` for step 2 of the three-step hook. Requires project-guide >= 2.2.3. Failure-non-fatal.
  - [x] `project_guide_in_project_deps()` — **new helper added during implementation** (not in original checklist). Auto-skip safety: detects `project-guide` declared in `pyproject.toml` / `requirements.txt` / `environment.yml` with word-boundary regex (no false matches with `project-guide-extras`).
  - [x] `detect_user_shell()` → `zsh` | `bash` | `unknown` — read `$SHELL`, fall back to `unknown`
  - [x] `get_shell_rc_path(shell)` → `~/.zshrc` | `~/.bashrc` | empty
  - [x] `is_project_guide_completion_present(rc_path)` → 0/1 — check for the sentinel comment
  - [x] `add_project_guide_completion(rc_path, shell)` — append the sentinel-bracketed completion block; idempotent (no-op if sentinel already present); creates rc file if missing
  - [x] `remove_project_guide_completion(rc_path)` — remove the sentinel-bracketed block plus one preceding blank line; safe no-op if absent (called by `self uninstall`); awk-based, BSD/GNU compatible
  - [x] `prompt_install_project_guide_completion()` — Y/n prompt with default Y; respects env vars; **CI defaults to SKIP** (not install — see asymmetry note above)
- [x] Wire the install hook into `init()` in `pyve.sh`
  - [x] Run after pip-deps install, before final success summary
  - [x] Parse `--project-guide` / `--no-project-guide` flags; error if both
  - [x] Read `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` env vars
  - [x] Honor non-interactive mode (`CI` / `PYVE_FORCE_YES`) — default install
  - [x] On failure, log warning with pip stderr and `--no-project-guide` hint, continue
  - [x] **Auto-skip safety added during implementation:** if `project_guide_in_project_deps` returns 0, skip the entire hook with an INFO message and the `--project-guide` override hint
  - [x] **`--update` mode does NOT run the hook** — naturally handled because update returns at line 469 before the env-creation flow
- [x] Wire the `project-guide init --no-input` invocation **(new step 2 — added during implementation per user spec)**
  - [x] Runs after successful install, before completion step
  - [x] Failure-non-fatal: warn and continue
- [x] Wire the completion hook into `init()` in `pyve.sh`
  - [x] Only run if `project-guide` was actually installed (or already present from prior init)
  - [x] Parse `--project-guide-completion` / `--no-project-guide-completion` flags; error if both
  - [x] Read `PYVE_PROJECT_GUIDE_COMPLETION` / `PYVE_NO_PROJECT_GUIDE_COMPLETION` env vars
  - [x] Honor non-interactive mode — **default skip**
  - [x] If user shell is unknown (not zsh/bash) → warn with manual-setup hint, continue
  - [x] If sentinel already present in rc file → silent no-op
  - [x] On rc-file write failure → warn and continue
- [x] Wire completion removal into `uninstall_self()` in `pyve.sh`
  - [x] Call `remove_project_guide_completion()` for both `~/.zshrc` and `~/.bashrc` (covers users who switched shells)
  - [x] Implemented via new `uninstall_project_guide_completion()` helper called at the end of `uninstall_self()`
- [x] Update `pyve init --help` to document the four new flags, the three-step hook, the auto-skip safety, and the CI-default asymmetry
- [x] Update `pyve self uninstall --help` to mention completion-block removal

**Spec updates**

- [x] `docs/specs/features.md`
  - [x] Add new **FR-16: project-guide integration** with full behavior spec, including the three-step hook, completion sub-feature, install/completion CI-default asymmetry, auto-skip safety mechanism, and `--update` exemption
  - [x] Add `--project-guide`, `--no-project-guide`, `--project-guide-completion`, `--no-project-guide-completion` to the **Optional Inputs** table
  - [x] Add `PYVE_PROJECT_GUIDE`, `PYVE_NO_PROJECT_GUIDE`, `PYVE_PROJECT_GUIDE_COMPLETION`, `PYVE_NO_PROJECT_GUIDE_COMPLETION` to the **Environment Variables** table
  - [x] Update **FR-1: Environment Initialization** to mention the post-init hook
  - [x] Update **FR-7: Script Installation/Uninstallation** to note that `self uninstall` removes the project-guide completion block
- [x] `docs/specs/tech-spec.md`
  - [x] Document all 11 helpers in a new **project-guide Helper Functions** subsection
  - [x] Add the four new modifier flags to the **Modifier Flags** table
  - [x] New **project-guide rc-file Sentinel** subsection in **Cross-Cutting Concerns** alongside the existing PATH-entry handling
- [x] **Upstream dependency spec (new — drafted during implementation):** [docs/specs/project-guide-no-input-spec.md](project-guide-no-input-spec.md) — proposed and implemented in `project-guide >= 2.2.3`

**Tests**

- [x] Bats: new `tests/unit/test_project_guide.bats` (54 tests, all green)
  - [x] `prompt_install_project_guide` returns 0 (install) with `PYVE_PROJECT_GUIDE=1`
  - [x] Returns 1 (skip) with `PYVE_NO_PROJECT_GUIDE=1`
  - [x] Returns 0 (install) with `CI=1` and no other env vars
  - [x] Returns 0 (install) with `PYVE_FORCE_YES=1`
  - [x] `PYVE_NO_PROJECT_GUIDE` wins over `PYVE_PROJECT_GUIDE` (priority test)
  - [x] `PYVE_NO_PROJECT_GUIDE` wins over `CI` (priority test)
  - [x] `is_project_guide_installed` returns 1 against an env without it (and without python binary)
  - [x] `prompt_install_project_guide_completion` returns 0 with `PYVE_PROJECT_GUIDE_COMPLETION=1`
  - [x] Returns 1 with `PYVE_NO_PROJECT_GUIDE_COMPLETION=1`
  - [x] Returns 1 (skip) with `CI=1` — verifies CI-default asymmetry vs install
  - [x] Returns 1 (skip) with `PYVE_FORCE_YES=1` — same asymmetry
  - [x] `PYVE_NO_PROJECT_GUIDE_COMPLETION` wins over `PYVE_PROJECT_GUIDE_COMPLETION` (priority test)
  - [x] `detect_user_shell` returns `zsh` / `bash` / `unknown` from `$SHELL` (matrix: /bin/zsh, /usr/bin/zsh, /bin/bash, /opt/homebrew/bin/bash, /usr/bin/fish, empty)
  - [x] `get_shell_rc_path` returns expected paths for zsh / bash / unknown / fish
  - [x] `is_project_guide_completion_present` detects the sentinel (matrix: missing file, file without sentinel, file with sentinel)
  - [x] `add_project_guide_completion` creates rc file if missing
  - [x] Inserts the eval block with `command -v` guard for both zsh and bash
  - [x] Preserves existing content above and below the inserted block
  - [x] Idempotent — running twice produces one block
  - [x] `remove_project_guide_completion` safe no-op for missing file and file without sentinel
  - [x] Removes only the sentinel block, preserves other lines
  - [x] add → remove round-trip restores the original content byte-for-byte
  - [x] **`install_project_guide` passes `--upgrade` to pip** (verified via fake-pip stub)
  - [x] **`run_project_guide_init_in_env` passes `--no-input` to project-guide init** (verified via fake-binary stub)
  - [x] **`run_project_guide_init_in_env` safe no-op when binary missing**
  - [x] **`run_project_guide_init_in_env` failure-non-fatal when binary fails (exit 17 → return 0)**
  - [x] **`project_guide_in_project_deps` matrix:** pyproject.toml positive (multiple table styles), pyproject.toml negative, similar-named-package negative, comment-only negative, requirements.txt positive (with/without version pin), requirements.txt negative, requirements.txt comment-only, environment.yml conda dep positive, environment.yml pip-nested dep positive, environment.yml negative, environment.yml comment-only
- [x] pytest: new `tests/integration/test_project_guide_integration.py` (11 tests across 4 classes, all green)
  - [x] `pyve init --no-project-guide` → no project-guide files, package not installed, no rc-file edit
  - [x] `PYVE_PROJECT_GUIDE=1 pyve init` → package importable from project env, `.project-guide.yml` and `docs/project-guide/` exist after `project-guide init` ← **TestRealInstall::test_install_with_completion_wires_everything**
  - [x] `pyve init --project-guide --no-project-guide` → mutex error
  - [x] `pyve init --project-guide-completion --no-project-guide-completion` → mutex error
  - [x] `PYVE_PROJECT_GUIDE=1 PYVE_PROJECT_GUIDE_COMPLETION=1 pyve init` against an isolated `HOME` → sentinel block present in `~/.zshrc`
  - [x] `CI=1 pyve init` → package installed, rc file untouched (CI-default asymmetry) ← **TestRealInstall::test_ci_asymmetry_install_yes_completion_no**
  - [x] Idempotency: second `pyve init --project-guide` re-runs faster (timing-based) ← **TestRealInstall::test_idempotent_reinstall_is_fast**
  - [x] **Auto-skip when project-guide is in pyproject.toml** ← TestAutoSkipWhenInProjectDeps
  - [x] **Auto-skip when project-guide is in requirements.txt** ← TestAutoSkipWhenInProjectDeps
  - [x] **Explicit `--project-guide` flag overrides auto-skip** ← TestAutoSkipWhenInProjectDeps
  - [ ] `pyve self uninstall` after a completion-enabled install → sentinel block removed *(deferred — covered by bats unit tests for `remove_project_guide_completion` + `uninstall_self` wiring is visual-inspection in pyve.sh; full e2e would require running self-uninstall against a fake install target)*
  - [ ] Failure path: simulate pip failure → `pyve init` still exits 0 with warning *(deferred — failure-non-fatal behavior validated in bats with the exit-17 test)*
  - [ ] Failure path: simulate unwritable rc file → warn, `pyve init` still exits 0 *(deferred — same rationale)*
  - [ ] Both backends: venv and micromamba (markers `venv`, `micromamba`) *(deferred — venv backend covered fully; micromamba backend covered by helper unit tests but no integration test runs micromamba pyve init in the project-guide path; can be added once micromamba is reliably available in CI)*
- [x] **Real-install tests confirmed passing** with `project-guide >= 2.2.3` (the upstream `--no-input` change shipped during this story)
- [x] Full bats suite: 404 tests passing (350 pre-G.c + 54 new). Full pytest integration: 242 passing, 26 environment-conditional skips, 0 real failures (1 unrelated pre-existing flake on rerun).

- [x] Update CHANGELOG.md with v1.12.0 entry
- [x] Bump VERSION to 1.12.0

---

### Story G.d: v1.13.0 `usage.md` Overhaul + Spec Sync [Done]

The MkDocs landing page at [docs/site/usage.md](docs/site/usage.md) has drifted significantly behind `pyve --help` and is now compounded by the G.b subcommand refactor and G.c project-guide flags. Bring it fully into sync and ship it under a version bump so the doc-site rollout is legible.

**Motivation:** New users land on the docs site and trust it. Today they get incorrect descriptions (e.g., `--python-version` says "Display Python version" when it sets it), missing subcommands (`testenv` is entirely absent), missing options on `init` and `purge`, and — after G.b — flag-form examples that no longer work. Fix everything in one coherent pass.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G3 for full gap list.

**Command behavior**

(No CLI changes — pure docs and spec sync.)

**Implementation checklist**

- [x] Rewrite `docs/site/usage.md` command reference against the v1.12.0 surface
  - [x] Fix `python-version` description (sets the local Python version, not displays)
  - [x] Add `testenv` subcommand reference: `--init`, `--install [-r]`, `--purge`, `run <command>`
  - [x] Add missing `init` options: `--local-env`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--env-name`, `--no-direnv`, `--allow-synced-dir`, `--no-lock`, `--project-guide`, `--no-project-guide`, optional `<dir>` positional
  - [x] Add missing `purge` options: optional `<dir>` positional, `--keep-testenv`
  - [x] Replace all flag-form examples (`pyve --init`, etc.) with subcommand form
  - [x] Add `self install` and `self uninstall` to the command overview table
  - [x] Add a "Migration from flag-style CLI" callout near the top of the page for users coming from <1.11
  - [x] Document `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` in the env vars section
- [x] Sweep `docs/site/` for any remaining `pyve --init` / `pyve --purge` / `pyve --validate` / `pyve --install` / `pyve --uninstall` / `pyve --python-version` strings and fix them — fixed two stale `./pyve.sh --install` references in `getting-started.md`; only intentional references remain in the migration callout table in `usage.md`
- [x] Verify the docs site builds locally (`mkdocs build --strict`) — built clean in an ephemeral venv with `mkdocs-material` + `mkdocs-git-revision-date-localized-plugin` (same deps as `.github/workflows/deploy-docs.yml`)

**Spec updates**

- [x] Final cross-check pass on `docs/specs/features.md` and `docs/specs/tech-spec.md` — clean. G.b/G.c already completed the spec sync; `features.md` has no stale legacy-flag references and both files document the project-guide hook from G.c. Remaining `pyve --init` references in `tech-spec.md` and `stories.md` are intentional historical documentation (the legacy-flag catch and the migration table).
- [x] Mark Phase G complete in this stories.md (all five top-level checklist items checked)

**Tests**

- [x] No automated tests (docs-only)
- [x] Manual: rendered `usage.md` against `pyve --help` / `pyve init --help` / `pyve purge --help` / `pyve testenv --help` / `pyve self install --help` / `pyve self uninstall --help` — every new flag/option matches the v1.12.0 CLI surface exactly.

- [x] Update CHANGELOG.md with v1.13.0 entry
- [x] Bump VERSION to 1.13.0

---

### Story G.e: Investigate Python 3.14 CI Testing [Planned]

Spike / investigation story. Goal: validate whether pyve's CI matrix can include Python 3.14 alongside (or in place of) the current 3.12-only matrix, and document the trade-offs. No production code changes expected unless the investigation surfaces a real bug.

**Motivation:**

- v1.12.0 narrowed the CI matrix from `['3.10', '3.11', '3.12']` to `['3.12']` (see CHANGELOG and `docs/specs/features.md`) to fix the project-guide / Python 3.10 incompatibility and reduce CI cost. As a side effect, **CI no longer exercises pyve's `DEFAULT_PYTHON_VERSION` (currently `3.14.4`)** — the auto-pin in `PyveRunner.run()` always pins to the runner's pyenv-installed 3.12.
- Pyve has a [lib/distutils_shim.sh](lib/distutils_shim.sh) specifically because Python 3.12+ removed `distutils`. Future Python releases could break the shim's `sitecustomize.py` loading mechanism. Without 3.14 in the matrix, no integration test ever runs the shim against the latest CPython.
- The project owner is on Python 3.14.2/3.14.4 locally as the daily-driver Python, so tests on 3.14 close the dev/CI gap.

**Open questions to answer:**

1. **Is Python 3.14 available on `actions/setup-python@v6`?** As of v1.12.0 we didn't verify this. Quick check: does `actions/setup-python` install a pre-built 3.14 binary, or does it fall back to source build? (Source build is what timed out the Ubuntu runner during the v1.12.0 G.c CI failures.)
2. **If pre-built binaries exist, is the install fast enough?** The pyve workflow currently runs `pyenv install $PYTHON_VERSION` after `actions/setup-python` to register the version with pyenv (so pyve's auto-pin works). For 3.14, would we need to skip pyenv entirely and have pyve detect Python directly from the runner's PATH?
3. **What CI minutes does adding 3.14 to the matrix actually cost?** The current 3.12-only integration matrix runs in ~10–13 min per OS. Adding 3.14 doubles integration test runtime per push.
4. **Does the conda ecosystem support 3.14?** Probably not yet. Micromamba matrix should stay at 3.12 even if venv matrix gains 3.14.

**Implementation checklist:**

- [ ] Read [.github/workflows/test.yml](.github/workflows/test.yml) and identify exactly what would need to change to add `'3.14'` to the integration matrix
- [ ] Check `actions/setup-python@v6` documentation / changelog for 3.14 support
- [ ] Push a throwaway branch with the matrix change and observe CI behavior (build vs. binary install, duration, any errors)
- [ ] If pyenv source-build is required and slow, evaluate alternatives:
  - Use `actions/setup-python` directly without registering with pyenv (requires changing pyve's auto-pin to detect plain `python3` on PATH)
  - Cache the pyenv source build between runs
  - Skip pyenv entirely on the 3.14 matrix entry
- [ ] Validate that pyve's `distutils_shim.sh` works against 3.14 — this is the main thing we'd be buying with the matrix expansion
- [ ] Document findings in this story's body (replace this checklist with the actual recommendation)
- [ ] If the recommendation is to add 3.14: implement the matrix change in a separate PR with its own CHANGELOG entry
- [ ] If the recommendation is to defer: document why (e.g., "3.14 source-build cost not justified by current shim coverage") and close the story

**Tests:**

- [ ] No code-side tests for this story — it's an investigation. Any tests added would be part of the follow-up PR (if any).

**Spec updates:**

- [ ] If we add 3.14 to the matrix, update `docs/specs/features.md` line about the Python version matrix to match
- [ ] If we defer, add a note to the same line linking back to this story for future reference

**Out of scope (deferred to other stories):**

- Bumping `DEFAULT_PYTHON_VERSION` further (already at 3.14.4, that's fine)
- Adding multi-version matrix entries for the conda ecosystem (micromamba stays at 3.12)
- Dropping 3.12 in favor of 3.14 only (would deprecate the version most modern tooling targets — separate product decision)


