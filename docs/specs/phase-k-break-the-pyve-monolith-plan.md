# Phase K — Break the Pyve Monolith

**Intended release version:** `v2.4.0` — the whole phase ships together.

**Theme.** Decompose `pyve.sh`'s ~3,500 lines into per-command modules under `lib/commands/`, leaving `pyve.sh` as a thin ~200–300 line dispatcher. **Zero behavior change** is the contract — every story must leave the full test suite green with no observable user-facing diff. Characterization tests precede every move so the safety net is in place before code shifts.

The architectural target is fully specced in [tech-spec.md](tech-spec.md) (sections: Package Structure, `pyve.sh — Thin Entry Point`, `lib/commands/<name>.sh — Command Implementations`, Cross-Cutting Concerns → Command Module Extraction Pattern). The invariants live in [project-essentials.md](project-essentials.md) (three subsections covering command-vs-helper placement, explicit sourcing, namespace single-file rule).

---

## Gap Analysis

**What exists today.**

- `pyve.sh` (~3,500 lines): shebang, copyright header, `set -euo pipefail`, globals, library sourcing block, `legacy_flag_error()`, `unknown_flag_error()`, top-level `case`-block dispatcher, `main()`, **plus all 11 command implementations** (`init`, `purge`, `update`, `check`, `status`, `lock`, `run`, `test`, `testenv`, `python`, `self`) and various command-private helpers (`run_lock`, `install_prompt_hook`, `run_project_guide_hooks`, `.envrc` generators, etc.).
- `lib/*.sh` (9 helper modules): logging, UI, env detection, backend detection, micromamba helpers, distutils shim, version tracking. Cross-command helpers, all sourced before any command runs.
- Test coverage: integration tests (pytest) exercise commands black-box; unit tests (Bats) source individual `lib/*.sh` modules. **No unit tests target command-level logic** because command logic lives inside `pyve.sh` (which is hard to source standalone).

**What's missing.**

- Per-command source files. Adding any new command means editing `pyve.sh`; the file is past comfortable LLM-context size; bisecting a regression to a single command is harder than it should be.
- A pre-refactor coverage map. We don't currently know which command behaviors are exercised only by integration tests, which have unit coverage, and which are covered indirectly through helper-function tests. The first story (K.a) produces this map.
- A characterization-test backfill. Behaviors with thin coverage need new tests (against the current, pre-refactor `pyve.sh`) before extraction can proceed safely.

**What this phase delivers.**

- All 11 top-level commands extracted to `lib/commands/<name>.sh`, each defining a top-level function with the same name as the file (namespace commands keep the dispatcher + leaves in one file per the project-essentials invariant).
- `pyve.sh` shrunk to ~200–300 lines: globals, sourcing block (now including `commands/*`), universal flag handling, `legacy_flag_error()`, `unknown_flag_error()`, `main()`, top-level `case` dispatcher.
- A coverage audit artifact at `docs/specs/phase-K-command-coverage-audit.md` that maps each command's behaviors to existing tests + identifies backfill targets. Used as input to per-command extraction stories.
- Test suite remains green at every story boundary; no story is "complete" until the full suite passes with zero observable behavior change.

---

## Feature Requirements

**None.** This is a pure refactor. The user-facing surface is unchanged: every CLI command, flag, env var, exit code, and output line behaves identically to v2.3.0. The project-essentials and tech-spec invariants are the contract.

If a backfill characterization test (step 3 of the extraction pattern) reveals a latent bug, it is **not** fixed in the extraction story — it is carved off into its own dedicated fix story (with its own version bump and CHANGELOG entry) so the refactor stays clean and bisectable.

---

## Technical Changes

The architectural changes are already specced in tech-spec.md. Operational summary:

### New files

- `lib/commands/init.sh` — `init()` and `_init_*` private helpers (including `_init_run_project_guide_hooks` migrated from `pyve.sh`).
- `lib/commands/purge.sh` — `purge()` and `_purge_*` private helpers.
- `lib/commands/update.sh` — `update()` and `_update_*` private helpers.
- `lib/commands/check.sh` — `check()` and `_check_*` private helpers.
- `lib/commands/status.sh` — `status()` and `_status_*` private helpers.
- `lib/commands/lock.sh` — `lock()` (which absorbs `run_lock` from `pyve.sh`).
- `lib/commands/run.sh` — `run()` and `_run_*` private helpers.
- `lib/commands/test.sh` — `test()` (delegates to `testenv_run`).
- `lib/commands/testenv.sh` — `testenv()` dispatcher + `testenv_init`, `testenv_install`, `testenv_purge`, `testenv_run`.
- `lib/commands/python.sh` — `python()` dispatcher + `python_set`, `python_show`.
- `lib/commands/self.sh` — `self()` dispatcher + `self_install`, `self_uninstall` (and `install_prompt_hook` if it ends up self-private rather than init-private — to be settled in K.l).
- `docs/specs/phase-K-command-coverage-audit.md` — produced by K.a; used by K.b–K.l.
- New `tests/unit/test_<command>.bats` files **only** when a command has command-private logic worth white-box testing in isolation. Most commands are exercised end-to-end by existing integration tests; per the tech-spec policy, separate unit files are permitted but not required.

### Modified files

- `pyve.sh` — shrinks from ~3,500 to ~200–300 lines. Loses every command implementation; gains `source lib/commands/<name>.sh` lines (alphabetical, explicit) in the existing sourcing block.
- `tests/integration/*.py` — no functional change expected; integration tests are black-box and unaware of internal structure. If any test inspects line numbers or other internals, it gets fixed in the relevant extraction story.
- `tests/unit/*.bats` — no change expected; existing Bats files target `lib/*.sh` helpers, which are unaffected.
- `docs/specs/tech-spec.md` — per-command function-signature tables get appended to the `lib/commands/<name>.sh` section as each extraction completes (per the tech-spec policy: "Per-command function tables are documented in this section as the extraction phase progresses").
- `CHANGELOG.md` — single v2.4.0 entry covering the full extraction.

### Cross-cutting

- **Direct-execution guard.** Each new file under `lib/commands/` ends with the same `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`-style guard the existing `lib/*.sh` modules use.
- **Explicit sourcing only.** Per project-essentials, the new sourcing lines in `pyve.sh` are explicit; no globs.
- **No new env vars, flags, or CLI surface.** If a story tries to add one, it has scope-crept and needs to be split.

---

## Out of Scope (deferred)

- **Decomposing the `lib/<topic>.sh` helpers.** Some helpers (`lib/utils.sh` is ~1,500 lines, `lib/micromamba_env.sh` is dense) could also benefit from splitting. Not in K — K is specifically about removing **command logic** from `pyve.sh`. Helper decomposition is a separate refactor judged on its own merits.
- **Renaming functions for stylistic consistency.** Tempting during a move; explicitly rejected because it makes the diff hard to review and breaks downstream `git blame`. Renames go in their own follow-up stories with their own justification.
- **Adding new tests beyond characterization needs.** If the coverage audit (K.a) finds gaps, the backfill is scoped to **what's needed to safely extract the command** — not "while we're here, let's add comprehensive tests." Comprehensive coverage is a separate, post-refactor effort.
- **Performance optimization.** Sourcing 11 more files at startup adds a few ms; if this matters, address it in a separate phase. Current target: zero perceptible startup-time regression. K.m measures and decides.
- **Touching `lib/completion/`.** Shell completion is generated/maintained separately; unaffected by this refactor.
- **Introducing a `lib/shared/` directory** for cross-command helpers. Existing `lib/<topic>.sh` modules are sufficient; adding another tier complicates sourcing-order reasoning without payoff.
- **Migrating to `bash 4+` constructs** that the bash 3.2 invariant (J.e) currently forbids. The refactor stays in bash 3.2-compatible territory.

---

## Proposed Story Breakdown

13 stories total: one up-front audit, eleven extractions in low-risk-first order, one release wrap. Per the tech-spec extraction pattern, every per-command story (K.b–K.l) carries the same five-task scaffolding (inventory, coverage audit, backfill characterization tests, extract, verify green). Story IDs use the `K.a`–`K.m` range.

| Story | Title | Notes |
|---|---|---|
| **K.a** | Command coverage audit | Produces `docs/specs/phase-K-command-coverage-audit.md`: one section per command listing inputs/outputs/side-effects, the integration tests that exercise it, the unit tests that touch its helpers, and identified backfill targets. No code changes. Inputs to all subsequent stories. |
| **K.b** | Extract `run` | Smallest, simplest command. Establishes the per-command extraction pattern in code. The "spike" of the phase — proves the dispatcher contract works end-to-end before larger commands move. |
| **K.c** | Extract `lock` | Small, isolated; absorbs the existing `run_lock` helper from `pyve.sh`. |
| **K.d** | Extract `python` namespace | Smallest namespace command (`set` + `show`). First test of the namespace single-file pattern. |
| **K.e** | Extract `self` namespace | `install` + `uninstall`. Decision point: does `install_prompt_hook` belong in `self.sh` or in `init.sh`? K.a's audit informs this. |
| **K.f** | Extract `test` | Delegates to `testenv_run` — straightforward, but K.f comes before K.g so the ordering forces a temporary cross-file call (`test` calls `testenv_run` which is still in `pyve.sh`); resolved naturally by K.g. |
| **K.g** | Extract `testenv` namespace | Largest namespace command (`init` + `install` + `purge` + `run`). After K.g lands, K.f's temporary cross-file call resolves to a same-direction call into `lib/commands/testenv.sh`. |
| **K.h** | Extract `status` | Read-only, no side effects, well-bounded section design (per `phase-H-check-status-design.md`). |
| **K.i** | Extract `check` | ~20 diagnostic checks; large but well-bounded. Some `check` logic lives in `lib/utils.sh` (`doctor_check_*` functions) and stays there per the cross-command-helper rule. |
| **K.j** | Extract `update` | Depends on init helpers it shares (or used to share via `pyve.sh`-internal calls). Carefully audit which helpers move, which stay shared in `lib/utils.sh`, which become command-private. |
| **K.k** | Extract `purge` | Medium complexity; `.gitignore` cleanup logic + testenv preservation. |
| **K.l** | Extract `init` | The largest command (~300 lines + helpers). Last because it's the riskiest and benefits from every prior story's pattern refinement. Absorbs `run_project_guide_hooks` as `_init_run_project_guide_hooks`. |
| **K.m** | v2.4.0 Release Wrap | CHANGELOG finalization, version bump in `pyve.sh` from `2.3.0` to `2.4.0`, startup-time sanity check (sourcing 11 extra files should add <50ms; if more, investigate but don't block release), final verification that `pyve.sh` is in the 200–300 line target range. |

**Why this order.**

- **K.a first** — produces the artifact every other story consumes. Without it, each per-command story would re-do the same audit work.
- **Low-risk-first (K.b → K.l)** — the simplest commands establish the extraction pattern in actual code. By the time we reach `init` (K.l), the pattern is well-worn and the riskiest extraction has the most precedent to draw on.
- **Namespace commands grouped (K.d, K.e, K.g)** — proves the namespace single-file convention before the most complex namespace (`testenv`) lands.
- **K.f before K.g** — `test` is trivially smaller than `testenv` and benefits from extracting first; the resulting temporary cross-file call is cosmetic and resolves on the next story.
- **K.l last** — `init` is the largest function in the codebase and the most-modified. Extracting it last means the dispatcher pattern is mature, the `lib/commands/` directory is well-populated with examples, and the team's confidence in the extraction safety-net is high.

**Per-extraction-story task scaffolding (K.b–K.l).** Each story carries the five-task pattern from the tech-spec invariant:

1. **Inventory** — list this command's responsibilities, the cross-command helpers it calls (referencing `lib/<topic>.sh` functions), and the process-wide state it touches. Reference the relevant section of K.a's audit.
2. **Coverage audit (story-local).** Quote the relevant K.a section. Note any new gaps surfaced by closer inspection.
3. **Backfill characterization tests** against current `pyve.sh`. Should pass immediately. Latent-bug discoveries get carved off as separate fix stories.
4. **Extract** to `lib/commands/<name>.sh`; update `pyve.sh` dispatcher.
5. **Verify** — full test suite green, no observable diff. If the new file warrants a `tests/unit/test_<name>.bats` (rare per the tech-spec policy), add it here.

---

## Acceptance Criteria

1. `pyve.sh` is between 200 and 350 lines (target 200–300, ceiling 350 to allow for comments and the explicit sourcing block).
2. Every command listed in `pyve.sh`'s top-level `case` block resolves to a function defined in `lib/commands/<name>.sh`.
3. Every `lib/commands/<name>.sh` file follows the file-to-function contract (top-level function with the same name as the file; namespace files contain `<namespace>_<leaf>` functions).
4. The bash 3.2 invariant (J.e) stays green — no bash-4+ constructs introduced.
5. The full test suite (Bats unit + pytest integration on macOS + Linux) is green between every story.
6. No CLI surface change: `pyve --help`, every subcommand's help text, every flag, every env var, every exit code, and every output line is byte-identical to v2.3.0.
7. CHANGELOG.md v2.4.0 entry summarizes the refactor without listing every file moved (the granularity is "all 11 commands extracted to `lib/commands/`"; the per-story commit history holds the detail).
