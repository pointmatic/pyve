# stories.md — pyve

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

---

## Phase G: UX Improvements
- [x] add `pyve testenv run <command>` subcommand
- [x] draft a `concept.md` file to capture the core ideas and value proposition
- [ ] integrate `project-guide` as a default tool (see `ux-improvements.md`)
- [ ] refactor pyve CLI to use subcommands instead of flags (see `ux-improvements.md`)
- [ ] landing page (usage.md) updates (see `ux-improvements.md`)

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

### Story G.b: v1.11.0 CLI Subcommand Refactor [Planned]

Pyve's top-level CLI is a mix of flag-style commands (`pyve --init`, `pyve --purge`, `pyve --validate`, `pyve --python-version`, `pyve --install`, `pyve --uninstall`) and bare subcommands (`pyve run`, `pyve doctor`, `pyve test`, `pyve testenv`, `pyve lock`). The inconsistency is jarring and the flag-style form is unfamiliar to users coming from `git`, `cargo`, `kubectl`, `gh`, etc.

**Motivation:** A consistent subcommand surface is more discoverable, easier to document, and matches modern developer-tool conventions. This is a one-time breaking change with no compatibility shim — the developer has explicitly opted out of backwards compatibility for the future-now release. A friendly legacy-flag error catch makes the migration cost ~one keystroke per user invocation.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G1 and FR-G4 for full design.

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
- Per-subcommand `--help`: every subcommand supports `pyve <subcommand> --help` printing a focused block. `pyve --help` becomes the index, regrouped into categories: *Environment*, *Execution*, *Diagnostics*, *Self management*.
- `pyve self` with no subcommand prints the `self` namespace help only (mirrors `git remote`, `kubectl config`).

**Examples**

```bash
pyve init                              # was: pyve --init
pyve init --backend micromamba         # was: pyve --init --backend micromamba
pyve init my_venv --no-direnv          # was: pyve --init my_venv --no-direnv
pyve purge --keep-testenv              # was: pyve --purge --keep-testenv
pyve python-version 3.12.0             # was: pyve --python-version 3.12.0
pyve self install                      # was: pyve --install
pyve self uninstall                    # was: pyve --uninstall
pyve init --help                       # NEW: focused per-subcommand help
```

**Implementation checklist**

- [ ] Refactor top-level dispatcher in `pyve.sh`
  - [ ] Replace top-level `case` block (around [pyve.sh:2179](pyve.sh#L2179)) with subcommand routing
  - [ ] Replace pre-pass `case` block (around [pyve.sh:1189](pyve.sh#L1189)) with subcommand routing
  - [ ] Add `self` namespace dispatcher (`self install`, `self uninstall`)
  - [ ] Add legacy-flag error catch for `--init`, `--purge`, `--validate`, `--install`, `--uninstall`, `--python-version`
  - [ ] Drop `-i` / `-p` short aliases from top-level
  - [ ] `pyve self` (no subcommand) → print namespace help only
- [ ] Reorganize `print_help()` into the four categories
- [ ] Add per-subcommand `--help` plumbing where missing (`init`, `purge`, `validate`, `python-version`, `self`, `self install`, `self uninstall`)
- [ ] Repo-wide sweep for legacy flag invocations
  - [ ] All `tests/integration/*.py` test invocations
  - [ ] All `tests/unit/*.bats` references
  - [ ] `README.md` examples
  - [ ] Any remaining doc examples (excluding `docs/site/usage.md`, which is rewritten in G.d)

**Spec updates**

- [ ] `docs/specs/features.md`
  - [ ] Replace flag list in **Inputs > Required** with the subcommand list
  - [ ] Update FR-1 (`init`), FR-2 (`purge`), FR-3 (`python-version`), FR-7 (`self install` / `self uninstall`) invocation syntax
- [ ] `docs/specs/tech-spec.md`
  - [ ] Update **CLI Design > Commands** table to the subcommand surface
  - [ ] Document the `self` namespace
  - [ ] Note the legacy-flag error catch in **Cross-Cutting Concerns**

**Tests**

- [ ] Bats: new `tests/unit/test_cli_dispatch.bats`
  - [ ] Each new subcommand routes to the correct handler
  - [ ] `pyve self install` and `pyve self uninstall` route correctly
  - [ ] `pyve self` with no arg prints namespace help only
  - [ ] Each removed legacy flag prints the migration error and exits non-zero
- [ ] pytest: new `tests/integration/test_subcommand_cli.py`
  - [ ] `pyve init`, `pyve purge`, `pyve validate`, `pyve python-version`, `pyve self install`, `pyve self uninstall` execute their handlers black-box
  - [ ] Modifier flags still work attached to subcommands (e.g., `pyve init --backend venv --no-direnv`, `pyve purge --keep-testenv`)
  - [ ] Per-subcommand `--help` returns 0 and prints a non-empty block
- [ ] Mechanical sweep: update existing integration tests from flag form to subcommand form (CI catches misses via the legacy-flag error)

- [ ] Update CHANGELOG.md with v1.11.0 entry — note the breaking CLI change prominently
- [ ] Bump VERSION to 1.11.0

---

### Story G.c: v1.12.0 `project-guide` Integration in `pyve init` [Planned]

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

**Examples**

```bash
pyve init                                # prompts: Install project-guide? (Y/n) [Y]
pyve init --project-guide                # install without prompting
pyve init --no-project-guide             # skip without prompting
PYVE_NO_PROJECT_GUIDE=1 pyve init        # skip via env var (CI override)
pyve init --backend micromamba           # also installs project-guide via micromamba pip
```

**Implementation checklist**

- [ ] Add helper functions to `lib/utils.sh`
  - [ ] `is_project_guide_installed(backend, env_path)` — probe by running `<env_python> -c "import project_guide"` (or whichever module the package exposes)
  - [ ] `install_project_guide(backend, env_path)` — pip-install into the project env; idempotent (no-op if already installed); warn-don't-fail on error
  - [ ] `prompt_install_project_guide()` — Y/n prompt with default Y; respects env vars; respects `CI` / `PYVE_FORCE_YES`
- [ ] Wire the hook into `init_command()` in `pyve.sh`
  - [ ] Run after pip-deps install, before final success summary
  - [ ] Parse `--project-guide` / `--no-project-guide` flags; error if both
  - [ ] Read `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` env vars
  - [ ] Honor non-interactive mode (`CI` / `PYVE_FORCE_YES`) — default install
  - [ ] On failure, log warning with pip stderr and `--no-project-guide` hint, continue
- [ ] Update `pyve init --help` to document the new flags and the post-init hook

**Spec updates**

- [ ] `docs/specs/features.md`
  - [ ] Add new **FR-16: project-guide integration** with full behavior spec
  - [ ] Add `--project-guide` and `--no-project-guide` to the **Optional Inputs** table
  - [ ] Add `PYVE_PROJECT_GUIDE` and `PYVE_NO_PROJECT_GUIDE` to the **Environment Variables** table
  - [ ] Update **FR-1: Environment Initialization** to mention the new post-init hook
- [ ] `docs/specs/tech-spec.md`
  - [ ] Document the three new helpers in the `lib/utils.sh` function table
  - [ ] Add `--project-guide` / `--no-project-guide` to the **Modifier Flags** table

**Tests**

- [ ] Bats: extend `tests/unit/test_utils.bats` (or new file)
  - [ ] `prompt_install_project_guide` returns 0 (install) with `PYVE_PROJECT_GUIDE=1`
  - [ ] Returns 1 (skip) with `PYVE_NO_PROJECT_GUIDE=1`
  - [ ] Returns 0 (install) with `CI=1` and no other env vars
  - [ ] `is_project_guide_installed` returns 1 against an env without it
- [ ] pytest: new `tests/integration/test_project_guide_integration.py`
  - [ ] `pyve init --no-project-guide` → no project-guide files, package not installed
  - [ ] `PYVE_PROJECT_GUIDE=1 pyve init` → package importable from project env, `.project-guide.yml` and `docs/project-guide/` exist after `project-guide init`
  - [ ] `pyve init --project-guide --no-project-guide` → mutex error
  - [ ] Idempotency: second `pyve init --project-guide` doesn't re-pip-install
  - [ ] Failure path: simulate pip failure → `pyve init` still exits 0 with warning
  - [ ] Both backends: venv and micromamba (markers `venv`, `micromamba`)

- [ ] Update CHANGELOG.md with v1.12.0 entry
- [ ] Bump VERSION to 1.12.0

---

### Story G.d: v1.13.0 `usage.md` Overhaul + Spec Sync [Planned]

The MkDocs landing page at [docs/site/usage.md](docs/site/usage.md) has drifted significantly behind `pyve --help` and is now compounded by the G.b subcommand refactor and G.c project-guide flags. Bring it fully into sync and ship it under a version bump so the doc-site rollout is legible.

**Motivation:** New users land on the docs site and trust it. Today they get incorrect descriptions (e.g., `--python-version` says "Display Python version" when it sets it), missing subcommands (`testenv` is entirely absent), missing options on `init` and `purge`, and — after G.b — flag-form examples that no longer work. Fix everything in one coherent pass.

See [docs/specs/phase-g-ux-improvements-plan.md](docs/specs/phase-g-ux-improvements-plan.md) FR-G3 for full gap list.

**Command behavior**

(No CLI changes — pure docs and spec sync.)

**Implementation checklist**

- [ ] Rewrite `docs/site/usage.md` command reference against the v1.12.0 surface
  - [ ] Fix `python-version` description (sets the local Python version, not displays)
  - [ ] Add `testenv` subcommand reference: `--init`, `--install [-r]`, `--purge`, `run <command>`
  - [ ] Add missing `init` options: `--local-env`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--env-name`, `--no-direnv`, `--allow-synced-dir`, `--no-lock`, `--project-guide`, `--no-project-guide`, optional `<dir>` positional
  - [ ] Add missing `purge` options: optional `<dir>` positional, `--keep-testenv`
  - [ ] Replace all flag-form examples (`pyve --init`, etc.) with subcommand form
  - [ ] Add `self install` and `self uninstall` to the command overview table
  - [ ] Add a "Migration from flag-style CLI" callout near the top of the page for users coming from <1.11
  - [ ] Document `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` in the env vars section
- [ ] Sweep `docs/site/` for any remaining `pyve --init` / `pyve --purge` / `pyve --validate` / `pyve --install` / `pyve --uninstall` / `pyve --python-version` strings and fix them
- [ ] Verify the docs site builds locally (`mkdocs serve`)

**Spec updates**

- [ ] Final cross-check pass on `docs/specs/features.md` and `docs/specs/tech-spec.md` — anything missed by G.b/G.c
- [ ] Mark Phase G complete in this stories.md (all five top-level checklist items checked)

**Tests**

- [ ] No automated tests (docs-only)
- [ ] Manual: render `usage.md` locally, click through the rendered tables and links, verify each new flag/option matches `pyve --help` exactly

- [ ] Update CHANGELOG.md with v1.13.0 entry
- [ ] Bump VERSION to 1.13.0


