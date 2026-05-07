# stories.md -- pyve (python)

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Put **`vX.Y.Z` in the story title only when that story ships the package version bump** for that release. Doc-only or polish stories **omit the version from the title** (they share the release with the preceding code story, or use your project’s doc-release policy). **One semver bump per owning story** — extra tasks on the *same* story share that bump; see `project-essentials.md`. Semantic versioning applies to the package. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see [`concept.md`](concept.md). For requirements and behavior (what), see [`features.md`](features.md). For implementation details (how), see [`tech-spec.md`](tech-spec.md). For project-specific must-know facts, see [`project-essentials.md`](project-essentials.md) (`plan_phase` appends new facts per phase). For the workflow steps tailored to the current mode (cycle steps, approval gates, conventions), see [`docs/project-guide/go.md`](../project-guide/go.md) — re-read it whenever the mode changes or after context compaction.

---

## Phase L: Pyve Polish

UX polish phase. Delivers a `sv create`-grade scaffolding experience for `pyve init` (both backends) and `pyve update` — interactive wizard with smart defaults, quiet-by-default subprocess output with `--verbose` opt-in, step-counter framing, spinners/progress, end-of-init "Next steps:" summary — plus diagnostic-correctness fixes from the audit (Tracks 1–2). The phase grows `lib/ui.sh` into a `lib/ui/` library that is the boundary of the eventually-extractable CLI UX library; modules under it stay pyve-agnostic.

See [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md) for full theme, gap analysis, technical changes, and acceptance criteria. Constraints: pure-Bash, no runtime deps, macOS / Linux only including bash 3.2 on macOS.

**Intended release version:** Single `v2.5.x` → `v2.6.0` minor bump on phase merge to `main`. L.a was documentation-only and delivered no code; subsequent stories (L.b–L.l) land on the phase branch without per-story bumps and aggregate into one release. Story titles in this section therefore omit the `vX.Y.Z` suffix; the bump ships in L.zz.

**Implementation order.** Foundation-first per the plan doc: correctness fixes (L.b, L.c) are independent and can land early; the upstream-dependent integration fix (L.d) lands when the upstream change is available or defers to a follow-up patch; the `lib/ui/` migration (L.e) and primitives (L.f–L.i) land before the rollout stories (L.j–L.l) consume them.

**Phase closure.** Run Story L.zz once every other Phase L story is `[Done]` (or L.d explicitly deferred) — it performs the mandated `project-essentials.md` hygiene pass and lands the single `v2.6.0` bump before the phase branch merges to `main`. L.zz's hygiene pass is deliberately **not** "add new facts only" append-only housekeeping; pruning or rewriting stale entries during L.zz is an explicit Phase L carve-out (`refactor_plan` still owns large-scale reorganizations).

---

### Story L.a: Audit `pyve status` / `pyve check`, project-guide integration, and terminal UX [Done]

**Goal.** Produce a single combined audit document with three sections (Diagnostic Surface / Project-Guide Integration / Terminal UX) that catalogues UX/correctness rough edges across pyve's read-only diagnostic surface, its project-guide integration touchpoints, and its terminal output behavior. Each non-trivial finding becomes a follow-up implementation story (L.b, L.c, …) appended to Phase L. Upstream-located Track-2 findings produce a project-guide change-request spec instead. **No code changes**, no version bump — this story is documentation only.

**Output.**

- `docs/specs/phase-l-pyve-polish-audit.md` — three-section findings document. Each finding records: (a) symptom, (b) root cause, (c) proposed fix size (one-liner / small / refactor / new-helper), (d) **fix locus** (pyve-side / upstream), (e) suggested follow-up story title (or change-request spec title), (f) — Track 1 only — whether `pyve check --fix` (deferred Auto-Remediation Future story) could automate the remediation.
- Zero or more `docs/specs/project-guide-requests/<short-name>.md` — one focused, self-contained change-request spec per upstream Track-2 finding (problem, proposed change, motivation, suggested CLI/API shape, compatibility notes).
- A final "suggested story slate" inside the audit document mapping findings → proposed L.b+ titles, ordered by suggested implementation sequence.

**Tasks — Track 1 (Diagnostic-surface correctness)**

- [x] Walk every code path in [lib/commands/status.sh](../../lib/commands/status.sh) for both `venv` and `micromamba` backends. For each output row, confirm the label, the source of truth, and the value match documented behavior in [features.md](features.md) "Status" section; capture mismatches as findings.
- [x] Walk every code path in [lib/commands/check.sh](../../lib/commands/check.sh) for both backends. For each diagnostic, confirm OK / warn / fail message text is precise, actionable, and not stale post-K renames; capture findings.
- [x] Confirm the seed finding (micromamba projects falsely report `Python: not pinned`) and record root cause + proposed fix in the audit; the existing Future-section story for this fix gets either promoted to an L.b+ story or merged into a related cluster.
- [x] Cross-check the `pyve status` Project / Environment / Integrations sections against each other for **same-fact contradictions** (e.g. Python-version disagreement). Capture each contradiction as a finding.
- [x] For each Track-1 finding, tag whether `pyve check --fix` could automate the remediation later (input to the deferred Auto-Remediation Future story).

**Tasks — Track 2 (Project-guide integration)**

- [x] Inventory every reference to `project-guide` under `lib/` ([lib/commands/init.sh](../../lib/commands/init.sh), [lib/commands/update.sh](../../lib/commands/update.sh), [lib/commands/status.sh](../../lib/commands/status.sh), [lib/commands/self.sh](../../lib/commands/self.sh), [lib/utils.sh](../../lib/utils.sh), [lib/completion/pyve.bash](../../lib/completion/pyve.bash), [lib/completion/_pyve](../../lib/completion/_pyve)). Re-grep at audit time in case new touchpoints have been added.
- [x] Run pyve commands against a synthetic project-guide-enabled project: `init` (both backends) with project-guide enabled, `update`, `status`, `self install/uninstall`. Record observed friction verbatim. **Waived for L.a:** no session transcript appended; friction for **T2-01** is inferred from wrappers + embedding context (see audit §Track 2). Recommended dogfood pass before **`pyve`** consumes **`project-guide --quiet`**.
- [x] Cross-reference the [project-guide command surface](https://pointmatic.github.io/project-guide/) (commands `init`, `mode`, `override`, `update`, `status`; flags; output behavior) against pyve's invocation patterns. Identify mismatched assumptions and stale contracts.
- [x] For each Track-2 finding, decide **fix locus** (pyve-side vs upstream). Pyve-side findings become candidate L.b+ stories; upstream findings become `docs/specs/project-guide-requests/<short-name>.md` specs.
- [x] For any pyve-side L.b+ story that consumes a shipped upstream change, record the minimum project-guide version dependency.

**Tasks — Track 3 (Terminal UX)**

- [x] Catalogue current capabilities of [lib/ui.sh](../../lib/ui.sh) — what's available, what's missing. Note the gitbetter-sync header constraint is being lifted in this phase per the plan doc.
- [x] Walk every command that emits multi-step output: `init` (both backends, with the micromamba bootstrap path treated as the worst-offender), `update`, `lock`, `testenv install`, `purge --force`. Record current output behavior verbatim, including subprocess noise.
- [x] Identify missing primitives (step counters, spinners, progress bars, multi-step framing, arrow-key single/multi-select prompts, output-quieting helpers) and propose where each lives in `lib/ui/` (e.g. `lib/ui/progress.sh`, `lib/ui/select.sh`).
- [x] Propose the final shape of `lib/ui/` — which modules, which boundaries, where `lib/ui.sh` migrates to (likely `lib/ui/core.sh`). Actual reorganization stays in the first Track-3 implementation story; L.a only proposes the shape.
- [x] Compare current pyve output against reference UX from `npm create vite@latest` / `npm create svelte@latest`. Identify the achievable subset within pure-bash + bash-3.2-on-macOS.
- [x] Recommend a verbosity policy ("quiet by default, verbose by opt-in" with `--verbose` / `PYVE_VERBOSE=1`) or, if findings push verbosity work to Future, defer it explicitly with rationale.

**Tasks — synthesis**

- [x] Write `docs/specs/phase-l-pyve-polish-audit.md` with three sections, a numbered findings table per track, per-finding short writeups, and the final "suggested story slate" in implementation order.
- [x] For each upstream Track-2 finding, write the corresponding `docs/specs/project-guide-requests/<short-name>.md` spec (self-contained — droppable into the project-guide repo's planning workflow without further translation).
- [x] Present the audit document and any project-guide change-request specs to the developer for review.

### Story L.b: 'pyve status' — micromamba Python pin from 'environment.yml' [Done]

**Goal.** Eliminate Project vs Environment **Python** contradiction (**[T1-01](phase-l-pyve-polish-audit.md)**). Backend-aware **`_status_configured_python`**; **`venv`** unchanged.

**Tasks**

- [x] Refactor `_status_configured_python` to dispatch by backend (split into `_status_configured_python_venv` / `_status_configured_python_micromamba`).
- [x] Implement `_status_parse_env_yml_python_pin` — regex-grep for `- python=<spec>` (tolerant of whitespace and a trailing `.*` glob).
- [x] Bats tests for each branch: micromamba w/ pinned `environment.yml`, micromamba w/o `environment.yml`, micromamba w/ env.yml lacking `python` dep, whitespace/glob variant, venv unchanged (ignores stray `environment.yml`, still reads `.tool-versions`).
- [x] No `features.md` update — FR-5a is high-level and doesn't claim specifics about pin-source detection.

---

### Story L.c: Align 'pyve check' — help, docs, shipped diagnostics [Done]

**Goal.** Fix stale **`show_check_help`** (**`pyve status`** "coming …") and reconcile **[features.md](features.md)** FR-5 claims with **[`check.sh`](../../lib/commands/check.sh)** (Python version gate, distutils shim) — **docs-only**, **implement deferred checks**, or **narrow docs** (**[T1-02](phase-l-pyve-polish-audit.md)**).

**Resolution.** Docs/help-only narrow path per the audit's recommended starting bundle. Deferred-check implementation (Python version-match gate, `distutils_shim` 3.12+ probe) stays a future story — the H.e design called for them, but they were never shipped, and adding them is a bigger surface than this Phase L correctness pass warrants.

**Tasks**

- [x] `show_check_help`: drop the "(coming in a later release)" parenthetical from the `pyve status` reference (status shipped in v2.0). Replace the misleading `pyve doctor` / `pyve validate` See-also lines (those forms hard-error post-v2.0; advertising them in `pyve check --help` is stale) with a single `pyve status` See-also entry.
- [x] `show_check_help`: tighten the `--fix` note to point at the existing Future story instead of the now-stale "Phase I" reference.
- [x] [features.md](features.md) FR-5: narrow the check inventory to match the shipped surface. Drop "Python version agreement" (only informational today), drop "`distutils_shim` status on 3.12+" (never shipped), drop the unsubstantiated "parseability" qualifier, and add an explicit note that the Python version is reported informationally with the version-match gate / distutils shim probe deferred to a follow-up.
- [x] bats tests: assert `pyve check --help` references `pyve status` without "coming", and does not advertise the removed `pyve doctor` / `pyve validate` forms.

---

### Story L.d ('+' upstream): Consumer '--quiet' for embedded 'project-guide' [Done]

**Goal.** Depends on **[`project-guide-requests/quiet-non-interactive-embedding.md`](project-guide-requests/quiet-non-interactive-embedding.md)** shipping upstream; then **`lib/utils.sh`** wrappers pass **`--quiet`** (or equivalent) once minimum version pinned.

**Resolution.** Upstream `--quiet` shipped in `project-guide` 2.5.0 (currently installed 2.5.8). Both embedded wrappers now pass `--no-input --quiet`; the docstring on `run_project_guide_init_in_env` records the minimum version (`project-guide >= 2.5.0`).

**Tasks**

- [x] [lib/utils.sh](../../lib/utils.sh) — `run_project_guide_init_in_env` passes `--quiet` alongside `--no-input` to suppress per-file progress chatter on success. Docstring updated to record `project-guide >= 2.5.0` minimum (was `>= 2.2.3` for `--no-input` alone).
- [x] [lib/utils.sh](../../lib/utils.sh) — `run_project_guide_update_in_env` passes `--quiet` alongside `--no-input` for the same reason; the `pyve update` and `pyve init --force` paths benefit from the cleaner output stream.
- [x] [lib/utils.sh](../../lib/utils.sh) — `log_info` lines no longer hard-code the literal flag string (which would drift the next time we tune the wrapper).
- [x] bats tests: each wrapper's command line includes `--quiet` (paired with the existing `--no-input` assertions).

---

### Story L.e: 'lib/ui/' directory establishment + 'lib/ui.sh' migration [Done]

**Goal.** Foundation for all subsequent UX work. Move `lib/ui.sh` → `lib/ui/core.sh` and update every `source` line in `pyve.sh` per the explicit-sourcing project-essential. **No new primitives in this story** — pure structural prep so L.f–L.l can land siblings.

**Tasks**

- [x] Create `lib/ui/` directory.
- [x] Move `lib/ui.sh` → `lib/ui/core.sh` via `git mv` (preserves history). Dropped the "verbatim sync with gitbetter" header comment per audit **[T3-03](phase-l-pyve-polish-audit.md)**; replaced with the `lib/ui/`-library boundary note (modules under it stay pyve-agnostic).
- [x] Updated `pyve.sh`'s explicit `source` block: `source "$SCRIPT_DIR/lib/ui/core.sh"`.
- [x] Updated in-tree callers: [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats) (`UI_PATH`), [tests/unit/test_envrc_template.bats](../../tests/unit/test_envrc_template.bats), [tests/unit/test_asdf_compat.bats](../../tests/unit/test_asdf_compat.bats); refreshed code/docstring comment references in [lib/utils.sh](../../lib/utils.sh), [pyve.sh](../../pyve.sh), and the `*_ui.bats` test headers.
- [x] Full bats unit suite green (739 / 739).
- [x] Updated [tech-spec.md](tech-spec.md): file-tree entry, sourcing-order list, cross-command-helpers paragraph, `### lib/ui/core.sh — Unified UI Helpers` section header, sourcing/bash-3.2 paragraphs.

---

### Story L.f: Verbosity policy — '--verbose' / 'PYVE_VERBOSE=1' [Done]

**Goal.** Add the verbosity gate as a single source of truth in `lib/ui/core.sh`. Default: quiet. **No command output changes yet** — this story just lands the gate so L.g–L.l can honor it.

**Tasks**

- [x] `PYVE_VERBOSE` is the single source-of-truth env var. `is_verbose()` in [lib/ui/core.sh](../../lib/ui/core.sh) checks `[[ "${PYVE_VERBOSE:-0}" == "1" ]]`; default behavior (unset / `0` / empty) is quiet.
- [x] [pyve.sh `main()`](../../pyve.sh) consumes `--verbose` as a global flag in a pre-dispatch loop and exports `PYVE_VERBOSE=1` so subcommands inherit it. Pre-subcommand position only (`pyve --verbose init`); subcommand-trailing form is out of scope.
- [x] `is_verbose()` is the only allowed call site for the verbosity check. The library-boundary bats invariant now whitelists `PYVE_VERBOSE` as the single Phase-L-sanctioned PYVE_-prefixed identifier in `lib/ui/core.sh` — every other PYVE_-prefixed name is still forbidden.
- [x] `--verbose` documented in the top-level `--help` UNIVERSAL FLAGS block.
- [x] `PYVE_VERBOSE` added to the Environment Variables table in [features.md](features.md) with the explicit "single source of truth" / `is_verbose()` guidance.
- [x] bats unit tests in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats): `is_verbose` returns 0 for `PYVE_VERBOSE=1`, non-zero for `0` / unset / empty.
- [x] bats integration tests in [tests/unit/test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats): `pyve --verbose <cmd>` sets `PYVE_VERBOSE=1` for the subcommand (verified via a new `VERBOSE:0|1` line emitted under `PYVE_DISPATCH_TRACE`); `PYVE_VERBOSE=1` in the env (no flag) does the same; `--help` documents `--verbose`.

---

### Story L.g: 'lib/ui/run.sh' — quiet-replay-on-failure subprocess wrapper [Done]

**Goal.** New module providing `run_quiet <cmd> [args...]` that captures stdout+stderr from long-running noisy subprocesses (micromamba bootstrap, conda solve, pip install) and replays the captured output only on failure. Honors L.f's verbosity gate. **No callers wired up yet** — that happens in L.j.

**Tasks**

- [x] [lib/ui/run.sh](../../lib/ui/run.sh) ships `run_quiet` (capture stdout+stderr to a temp buffer; discard on success, replay on non-zero) and `run_quiet_with_label "<label>" <cmd>...` (success → `success "<label>"`; failure → replay buffer then `✘ <label>` to stderr). `mktemp` failures fall back to live execution rather than dropping the command.
- [x] Honors `is_verbose()` from L.f — verbose mode streams output live; `run_quiet_with_label` still prints the labeled indicator under verbose so callers keep a consistent rhythm.
- [x] Bash 3.2 compatible — `mktemp 2>/dev/null`, plain `>file 2>&1` (no `&>`); no `mapfile` / `readarray` / process substitution. Locked in by a regression test that greps for those constructs.
- [x] Wired into `pyve.sh` via an explicit `source "$SCRIPT_DIR/lib/ui/run.sh"` block (per the explicit-sourcing project-essential — no glob).
- [x] Pyve-agnostic — boundary invariant tests assert no pyve paths / command names and that `PYVE_VERBOSE` (referenced via the `is_verbose()` helper) is the only PYVE_-prefixed identifier permitted.
- [x] 16 bats unit tests in [tests/unit/test_ui_run.bats](../../tests/unit/test_ui_run.bats) covering: existence, quiet-success silence, quiet-failure replay, exit-code propagation, verbose-mode live streaming, labeled success/failure markers, library-boundary invariants, bash 3.2 sourcing.
- [x] [tech-spec.md](tech-spec.md) updated: file-tree adds `ui/run.sh`; sourcing-order list inserts `ui/run.sh` immediately after `ui/core.sh`.

---

### Story L.h: 'lib/ui/progress.sh' — step counter, spinner, progress bar [Done]

**Goal.** New module providing the visual progress primitives needed for `sv create`-grade output: step counter framing, spinners for indeterminate ops, progress bars for slow operations with known total. Pure `tput` + ANSI; no external deps. **No callers wired up yet** — that happens in L.j.

**Tasks**

- [x] [lib/ui/progress.sh](../../lib/ui/progress.sh) ships:
  - `step_begin "<label>"` — opens a labeled step (quiet: no trailing newline so a marker can append; verbose: line-per-step shape so subprocess output isn't doubly decorated).
  - `step_end_ok` / `step_end_fail` — close the step with `✔` / `✘` markers; verbose mode prints `<marker> <label>` on its own line so the outcome stays tied to the label.
  - `spinner_start` / `spinner_stop` — backgrounded ASCII spinner (`|/-\` frames; multibyte braille frames would break bash 3.2's byte-counting `${var:offset:1}`). No-op when verbose or when stdout is not a TTY. `spinner_stop` is idempotent.
  - `progress_bar <current> <total> [width=40] [force]` — ASCII fill bar with carriage-return prefix so successive calls overwrite. No-op when verbose, when stdout is not a TTY, or when total ≤ 0; `force` argument bypasses the TTY check for tests.
- [x] Honors `is_verbose()` from L.f — spinner becomes a no-op; step output switches to a line-per-step shape under `PYVE_VERBOSE=1`.
- [x] Bash 3.2 compatible — backgrounded subshell with signal cleanup for the spinner; ASCII spinner frames; C-style `for` arithmetic loop in `progress_bar`. Locked in by a regression test that greps for `mapfile`/`readarray`/`&>`/`declare -A`/case-conversion expansions.
- [x] Wired into `pyve.sh` via an explicit `source "$SCRIPT_DIR/lib/ui/progress.sh"` block.
- [x] Pyve-agnostic — boundary invariant tests assert no pyve paths/command names and that `PYVE_VERBOSE` (referenced via `is_verbose()`) is the only PYVE_-prefixed identifier.
- [x] 20 bats unit tests in [tests/unit/test_ui_progress.bats](../../tests/unit/test_ui_progress.bats).
- [x] [tech-spec.md](tech-spec.md) updated: file-tree adds `ui/progress.sh`; sourcing-order list extended.

---

### Story L.i: 'lib/ui/select.sh' — arrow-key single/multi-select prompt [Done]

**Goal.** New module providing arrow-key selectors for the L.k interactive wizard. Falls back to a numbered prompt when stdin is not a TTY (CI safety). **No callers wired up yet** — that happens in L.k.

**Tasks**

- [x] [lib/ui/select.sh](../../lib/ui/select.sh) ships:
  - `ui_select [--default N] <label> <opt1> [opt2 ...]` — single-select. TTY path: arrow-key navigation (`\x1b[A` / `\x1b[B`), enter to confirm, escape or `q`/`Q` to cancel. Fallback path: numbered prompt with `[default]:` empty-input fallthrough. Returns the chosen 0-based index on stdout, exit 0 on confirm, non-zero on cancel / invalid.
  - `ui_multi_select [--default N[,N...]] <label> <opt1> [opt2 ...]` — multi-select. TTY path: arrow-key + space to toggle + enter to confirm. Fallback path: comma- or space-separated indices. Returns space-separated 0-based indices on stdout (empty selection allowed; caller decides if it's meaningful).
- [x] TTY fallback: when stdin is not a TTY, both surfaces drop to a numbered prompt that reads indices from stdin — `bats`-driven unit tests cover this path.
- [x] Bash 3.2 compatible — `IFS= read -rsn1` raw-byte reads, manual ESC-sequence parsing with a 0.01s timeout for the bracket pair, no `mapfile` / `readarray`. Locked in by a regression test.
- [x] Wired into `pyve.sh` via an explicit `source "$SCRIPT_DIR/lib/ui/select.sh"` block.
- [x] Pyve-agnostic — boundary invariant tests assert no pyve paths/command names and that no `PYVE_*` identifiers appear (the verbosity gate is irrelevant to user prompts; prompt shape doesn't change with `--verbose`).
- [x] 15 bats unit tests in [tests/unit/test_ui_select.bats](../../tests/unit/test_ui_select.bats) covering: numeric choice → 0-based index, empty input → default fallthrough, `--default` override, out-of-range / non-numeric → non-zero, prompt-text emission, multi-select space- and comma-separated parsing, library-boundary invariants, bash-3.2 sourcing. (TTY arrow-key path is smoke-tested manually; driving raw reads from a sub-shell without a real PTY is impractical — L.k's `expect`-style integration tests will cover the end-to-end flow.)
- [x] [tech-spec.md](tech-spec.md) updated: file-tree adds `ui/select.sh`; sourcing-order list extended.

---

### Story L.j: Step-framing rollout — 'pyve init' (both backends) + 'pyve update' [Done]

**Goal.** Wire L.g (`run_quiet`) and L.h (`step_begin` / `step_end_ok`) into `pyve init` and `pyve update` macro-steps. Subprocess output is silent on the happy path; on failure the captured noise is replayed. After this story, the scaffold-shaped commands hit the `sv create`-grade output bar.

**Resolution.** Tightly-scoped rollout — full step framing for `pyve update` (clean and contained), `run_quiet` wrap around the project-guide pip-install subprocess in `install_project_guide` (used by both `init` and the project-guide hook), and **explicit deferral of `pyve init`'s full step-counter restructure to L.k**. Reason: L.k restructures init's flow to add the wizard prompts. Adding step-counter framing now would create a known-throwaway intermediate shape and conflict with L.k's branching changes; the audit's worst-offender concern (micromamba init noise) is exactly what L.k will re-shape. Quiet-by-default for the noisiest existing init subprocess (project-guide pip install) lands here so the win is partial-immediate rather than fully-deferred.

**Tasks**

- [x] [lib/commands/update.sh `update_project()`](../../lib/commands/update.sh) refactored: replaced `log_info`/`log_success` chatter with `step_begin "[N/4] ..."` / `step_end_ok` / `step_end_fail` framing across all four steps (pyve_version bump, `.gitignore` refresh, `.vscode/settings.json` refresh, project-guide refresh). Each conditional skip path emits its own labeled step rather than disappearing. Wrapped with `header_box "pyve update v$VERSION"` / `footer_box`.
- [x] [lib/utils.sh `install_project_guide`](../../lib/utils.sh) — `$pip_cmd install --upgrade project-guide` now goes through `run_quiet`: pip's per-package progress is captured and discarded on success, replayed on failure. `--verbose` / `PYVE_VERBOSE=1` streams live.
- [x] [tests/helpers/test_helper.bash](../../tests/helpers/test_helper.bash) — `setup_pyve_env` now sources `lib/ui/core.sh` and `lib/ui/run.sh` before `lib/utils.sh` (utils now calls `run_quiet`).
- [x] [tests/unit/test_utils.bats](../../tests/unit/test_utils.bats) `setup` exports `NO_COLOR=1` so the `log_*` glyph-equality assertions stay stable now that `lib/ui/core.sh` is in scope.
- [x] [tests/unit/test_update.bats](../../tests/unit/test_update.bats) — added 3 new bats tests for the step-counter framing; updated the existing `--no-project-guide` skip-message test to match the new shape.
- [x] [features.md FR-15a](features.md) — output-shape paragraph appended documenting the four labeled steps + footer.
- [x] **Deferred to L.k**: `init.sh` venv-path full step framing, `init.sh` micromamba-path full step framing (the audit's worst offender), and `run_quiet` wraps around `python -m venv` / `bootstrap_install_micromamba` / `micromamba create`. The wizard restructure in L.k is the natural place to land them; doing it here would be re-done immediately. The remaining "non-scaffold" commands (`pyve lock`, `pyve testenv install`, `pyve purge --force`) stay tracked under the existing Future story "Apply Phase L UX framing to non-scaffold commands."

---

### Story L.k: Interactive `pyve init` wizard (red-carpet experience) — split into L.k.1–L.k.6

The original single-story scope grew large enough during pre-implementation Q&A (asdf-vs-pyenv precedence; `more...` secondary prompt for the full Python version list; project-guide already-present detection vs. flag-override interaction) that landing it as one cycle would mix design decisions into the implementation. The story is split into six self-contained sub-stories below. All six aggregate into the single `v2.6.0` bump in L.zz; no per-sub-story version bumps.

---

### Story L.k.1: Interactive init wizard — design + tech-spec [Done]

**Goal.** No-code design pass that locks the wizard's shape, prompt order, default-resolution rules, version-manager precedence, `more...` flow, and TTY policy. Output is a new "Interactive init wizard" subsection in [tech-spec.md](tech-spec.md). L.k.2–L.k.6 implement against this approved spec.

**Tasks**

- [x] Inventory every flag that `pyve init` accepts today. **15 flags catalogued** (`--backend`, `--python-version`, `--env-name`, `--local-env`, `--no-direnv`, `--force`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--no-lock`, `--allow-synced-dir`, `--project-guide`, `--no-project-guide`, `--project-guide-completion`, `--no-project-guide-completion`) plus the `<dir>` positional. Three become interactive prompts; twelve stay flag-only. Full mapping table in the new tech-spec subsection.
- [x] Decide the prompt set and order: **backend → python version pin → project-guide install**. Default-resolution rules per prompt documented in [tech-spec.md](tech-spec.md) "Interactive init wizard" subsection (Prompts 1, 2, 3).
- [x] Document `--force` semantics: applies only to init's destructive safeguard on the existing virtual environment; does **not** skip prompts. Captured in the flag-mapping table.
- [x] Document flag-override precedence: any explicit flag (`--backend`, `--python-version`, `--project-guide`, `--no-project-guide`) skips its corresponding prompt and wins over detection-based defaults. Captured per-prompt in the new subsection.
- [x] Document TTY policy: wizard hard-fails when stdin is not a TTY, error message names `--backend` and the other prompt-bearing flags as the non-interactive path. Captured in the new subsection's "TTY policy" subsection.
- [x] Document out-of-scope items: testenv creation, `--bootstrap-to`, `--auto-bootstrap`, `--force`, plus the rest of the flag-only set — all stay flag-only. Captured in the "Out of scope for the Phase L wizard" subsection.
- [x] Append the new "Interactive init wizard" subsection to [tech-spec.md](tech-spec.md), inserted between the Modifier Flags table and the Exit Codes section.

---

### Story L.k.2: Wizard skeleton — dispatch + welcome banner + TTY guard [Done]

**Goal.** Land the wizard frame so L.k.3–L.k.5 can each add a single prompt without restructuring. No prompts in this story; user-visible behavior on the happy path is "banner appears, then current init flow runs unchanged."

**Tasks**

- [x] Route every `pyve init` invocation through `_init_wizard()`. The existing `header_box "pyve init"` call in [init_project()](../../lib/commands/init.sh) is replaced by `_init_wizard "$backend_flag" "$python_version_supplied" "$project_guide_mode"`. Wizard always runs; per-prompt interactive vs. flag-render logic lands in L.k.3–L.k.5. `python_version_supplied` is tracked as a separate boolean (set `true` in the `--python-version` flag arm) since `python_version` itself is initialized to `DEFAULT_PYTHON_VERSION` and can't distinguish user-supplied from default.
- [x] Implement `_init_wizard()` skeleton in [lib/commands/init.sh](../../lib/commands/init.sh) (command-private per the project-essential prefix rule). Body: TTY guard → header_box → return 0. Per-prompt logic lands in L.k.3–L.k.5.
- [x] Welcome banner — `header_box "pyve init"` from `lib/ui/core.sh`. Always printed when the wizard runs (i.e. always — the wizard always runs).
- [x] TTY hard-fail: if `[[ ! -t 0 ]]` AND at least one of the three prompt-bearing parameters is not flag-supplied AND `PYVE_INIT_NONINTERACTIVE != 1`, the wizard exits non-zero before printing the banner. Error names only the missing flags (supplied flags are excluded from the list) and surfaces the bypass env var. Bypass env var `PYVE_INIT_NONINTERACTIVE=1` is set by default in [tests/helpers/test_helper.bash](../../tests/helpers/test_helper.bash) `setup_pyve_env` so existing 804-test bats fixtures keep passing without supplying every prompt-bearing flag.
- [x] bats unit tests in [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) (10 tests): banner prints with all three supplied; TTY guard fires when any flag missing; error names only missing flags; bypass `=1` works; bypass `=0` does not bypass; `pyve init` integration fails without flags / proceeds with bypass.
- [x] [tech-spec.md](tech-spec.md) "TTY policy" subsection extended with a "Bypass env var" paragraph documenting `PYVE_INIT_NONINTERACTIVE=1`.

---

### Story L.k.3: Wizard — backend prompt + repo-signal helpers [Done]

**Goal.** Add the first prompt to the wizard skeleton from L.k.2. Defaults driven by repo signals.

**Tasks**

- [x] Repo-signal detection helper `_init_detect_backend_default` in [lib/commands/init.sh](../../lib/commands/init.sh) (command-private): returns `micromamba` if `environment.yml` exists; returns `venv` if `.python-version` or `.tool-versions` exists; else returns `venv`. environment.yml wins over the venv-side signals.
- [x] Backend prompt wired into `_init_wizard()` with three resolution paths: (a) `--backend` supplied → render `Backend: <value> (--backend)` non-interactively; (b) flag unset + real TTY + bypass off → `ui_select` with default index from `_init_detect_backend_default`; (c) flag unset + (non-TTY OR `PYVE_INIT_NONINTERACTIVE=1`) → auto-default render `Backend: <detected> (auto-detected)`. The wizard's internal locals were renamed `arg_*` so bash dynamic scoping can write the resolved value back into the caller's `backend_flag` variable in [init_project()](../../lib/commands/init.sh) — post-wizard, `backend_flag` is always set, just like a flag-driven invocation.
- [x] Flag-override path: when `--backend` is supplied, the prompt renders non-interactively via path (a); the flag value is used unchanged.
- [x] bats unit tests for `_init_detect_backend_default` (5 tests covering each branch + signal-precedence).
- [x] bats unit tests for `_init_wizard` backend resolution (7 tests covering flag-render, auto-detect rendering for each signal case, dynamic-scope side effect, no-modification when flag was already set).

---

### Story L.k.4: Wizard — Python version pin prompt [Done]

**Goal.** Add the Python pin prompt. Most involved sub-story: backend-aware split (venv flow vs. micromamba flow), version-manager picker, "pick from installed", `more...` secondary prompt with filtered full list, skip path, no-manager hard-fail. The venv branch is the heavy half; the micromamba branch is small but real (the existing `--python-version` flag bakes into the scaffolded `environment.yml` via [lib/micromamba_env.sh:458](../../lib/micromamba_env.sh#L458) — the wizard surfaces this rather than skipping silently).

**Tasks — venv branch**

- [x] Detect installed version managers: `_init_detect_version_managers_available()` does presence checks for `asdf` and `pyenv` on PATH. Hard-fail applies only when the user is requesting a pin (flag supplied OR interactive selection); no-flag + non-interactive falls through to the no-pin skip path silently — absence of a manager is fine when no pin was requested.
- [x] Version-manager sub-prompt (interactive path): `ui_select` with options `[asdf, pyenv]` and asdf as default. Auto-picks the single one when only one manager is installed.
- [x] "Pick from installed" prompt — `_init_list_installed_python_versions(manager)` parses `asdf list python` (strip `*`/whitespace) or `pyenv versions --bare`, filtered to `^3\.`. Final two options are `more...` and `skip (no pin)`.
- [x] `more...` secondary prompt — `_init_list_available_python_versions(manager)` parses `asdf list all python` or `pyenv install --list` filtered to `^3\.` (drops 2.x, stackless-*, activepython-*, pypy*).
- [x] On selection (flag-driven or interactive), the wizard sets `VERSION_MANAGER` to the explicit pick and calls the existing `set_local_python_version` ([lib/env_detect.sh](../../lib/env_detect.sh)). asdf is preferred when both are available; the wizard's pick overrides the implicit precedence in `detect_version_manager()`.

**Tasks — micromamba branch**

- [x] `environment.yml` exists → `Python: managed via environment.yml`. The existing pin owns it; the wizard does not modify env.yml.
- [x] `environment.yml` absent + `--python-version <ver>` → `Python: <ver> (--python-version, will be written to environment.yml)`. No write in the wizard; the existing `scaffold_starter_environment_yml` writes it later in the init flow.
- [x] `environment.yml` absent + no flag → `Python: <DEFAULT_PYTHON_VERSION> (default, will be written to environment.yml)`. The default is the `python_version` value `init_project()` already passes (initialised to `DEFAULT_PYTHON_VERSION`).
- [x] No manager detection on the micromamba branch — micromamba pins via env.yml, not asdf/pyenv.

**Tasks — tests**

- [x] 4 bats tests for `_init_detect_version_managers_available` (none / asdf-only / pyenv-only / both); requires PATH-cleaning in the test stub helper to keep the dev machine's real asdf/pyenv from leaking in.
- [x] 4 bats tests for `_init_list_*_python_versions` (asdf and pyenv, installed and available), covering `*`-stripping for asdf, bare format for pyenv, and the `^3\.` filter dropping 2.7.18 / stackless / pypy.
- [x] 6 bats tests for the venv-branch wizard paths: flag + asdf, flag + pyenv-only, flag + both → asdf preferred, flag + no managers → hard-fail, bypass + no flag → silent skip, bypass + no flag + no managers → silent skip.
- [x] 4 bats tests for the micromamba-branch wizard paths: env.yml present → "managed via environment.yml", env.yml absent + flag → "(--python-version, will be written to environment.yml)", env.yml absent + no flag → "(default, will be written to environment.yml)", no managers + micromamba → still succeeds (no manager dependency).
- [x] Bug surfaced + fixed during TDD: the L.k.3 backend prompt's flag-set path needs to write `backend_flag="$arg_backend_flag"` so the dynamic-scope variable is populated even when the wizard is invoked from a context that didn't pre-set `backend_flag` (e.g. bats `run _init_wizard ...`). Without this, the L.k.4 micromamba branch check (`if [[ "$backend_flag" == "micromamba" ]]`) would fall through to the venv branch in tests.

---

### Story L.k.5: Wizard — project-guide install prompt [Done]

**Goal.** Last prompt in the wizard. If project-guide is already present in the target dir, run `project-guide update` instead of prompting (the safe refresh path).

**Tasks**

- [x] Detection helper `_init_detect_project_guide_present` in [lib/commands/init.sh](../../lib/commands/init.sh): returns 0 iff `.project-guide.yml` exists in cwd, matching the canonical install marker used by `pyve update` ([lib/commands/update.sh:123](../../lib/commands/update.sh#L123)).
- [x] When already present and no flag is supplied: render `project-guide: refresh (already installed)` and set `project_guide_mode="yes"` so the existing post-env `_init_run_project_guide_hooks` runs the update path (it already branches on `.project-guide.yml` at lines 135-139, calling `run_project_guide_update_in_env` when present). No new wiring needed in the hook.
- [x] When project-guide is declared in project deps (`project_guide_in_project_deps()` in [lib/utils.sh](../../lib/utils.sh)): render `project-guide: managed by your project dependencies` and set `project_guide_mode="no"`. The deps signal wins over the install-marker signal — pyve refuses to touch a user-managed install to avoid version-pin conflicts at the next `pip install -e .`.
- [x] When neither signal is present and no flag is supplied: in interactive mode (real TTY + bypass off), prompt with default no via `ui_select`; in non-TTY/bypass mode, render `project-guide: skipped (no flag)` and set `project_guide_mode="no"`.
- [x] Flag-override path: `--project-guide` renders `install (--project-guide)`; `--no-project-guide` renders `skipped (--no-project-guide)`. The wizard does not modify `project_guide_mode` in these cases — `init_project()` already set it from the flag arm.
- [x] 11 bats unit tests for each branch: detection helper (present / absent), flag-driven render (--project-guide / --no-project-guide), `.project-guide.yml`-present render and `project_guide_mode="yes"` side effect, deps-declared render and `project_guide_mode="no"` side effect, bypass + no-signal render and side effect, deps-vs-install-marker precedence (deps wins).

---

### Story L.k.6: Wizard — end-to-end integration + features.md [Done]

**Goal.** Close out the wizard work: features.md documentation update and the integration tests from the original L.k slate.

**Tasks**

- [x] Updated [features.md](features.md) FR-1 with a new FR-1a "Interactive `pyve init` wizard (Phase L / v2.6.0)" subsection: prompt set + order, default-resolution rules per prompt (including the venv/micromamba split for the Python pin and the deps-vs-install-marker precedence for project-guide), flag-override behavior, TTY policy, and the `PYVE_INIT_NONINTERACTIVE=1` bypass env var. Out-of-scope flags listed explicitly.
- [x] pytest integration test in [tests/integration/test_init_wizard.py](../../tests/integration/test_init_wizard.py): `pyve init --backend venv ...` proceeds non-interactively and the wizard renders `Backend: venv (--backend)`.
- [x] pytest integration test: `pyve init` in a directory containing `environment.yml` resolves the backend to `micromamba` via the wizard's auto-detect path. Driven via the non-TTY+bypass branch (closest faithful proxy for the interactive "press enter on the default" case — same detection signal, same resolved value; real-PTY arrow-key scripting stays out of unit-testable scope per L.i / L.k.4).
- [x] pytest integration test: `pyve init` with `PYVE_INIT_NONINTERACTIVE=0` (overriding the harness default) and no flags exits non-zero with the wizard's TTY guard error message including "stdin is not a TTY" and "--backend".
- [x] Test-harness alignment: [tests/helpers/pyve_test_helpers.py](../../tests/helpers/pyve_test_helpers.py) `PyveRunner.run` now sets `PYVE_INIT_NONINTERACTIVE=1` by default under pytest (mirroring the bats `setup_pyve_env` change in L.k.2). Without this, every existing pytest invocation of `pyve init` with anything less than all three prompt-bearing flags would now hard-fail on the wizard's TTY guard. The new TTY-guard test explicitly overrides this default via `monkeypatch.setenv`.
- [x] Cross-checked the shipped wizard against [tech-spec.md "Interactive `pyve init` wizard"](tech-spec.md) — all three prompts (with the venv/micromamba split for Prompt 2 and the deps-vs-install-marker precedence for Prompt 3), the TTY policy, the bypass env var, and the always-render-banner contract are implemented as specified. No gaps.

---

### Story L.k.7: CI cleanup — bash 3.2 empty-array fix + wizard-test environment isolation [Done]

**Goal.** Close out the L.k arc with a clean CI/CD baseline before L.l begins. Two unrelated regressions surfaced in the macOS GitHub Actions runner once the wizard work landed: (1) a bash-3.2 empty-array bug in [`_init_detect_version_managers_available`](../../lib/commands/init.sh) that crashed `pyve init` mid-flow whenever neither asdf nor pyenv was on PATH; (2) wizard bats tests that implicitly depended on the dev machine's installed asdf and started failing on stripped-down CI runners. Both root causes were latent throughout L.k.4 / L.k.5 but didn't surface locally because the dev environment had asdf installed and a modern bash on PATH. Fixing them here so every subsequent story starts from green CI.

**Tasks — `${available[*]}` empty-array fix (CI-only crash)**

- [x] [lib/commands/init.sh](../../lib/commands/init.sh) `_init_detect_version_managers_available()` — change `printf '%s' "${available[*]}"` to `printf '%s' "${available[*]:-}"`. **Why:** [pyve.sh:26](../../pyve.sh#L26) sets `set -euo pipefail`, which is inherited by sourced libraries. On bash 3.2 (macOS system bash), `"${empty_array[*]}"` triggers `unbound variable` even when `set -u` was not explicitly enabled in the helper itself — modern bash (4.4+) treats it as the empty string. The bug crashes `pyve init` mid-wizard on any runner without asdf/pyenv installed, killing the flow before `validate_backend` runs (which is why subprocess tests like `test_error_ui.bats::error: 'init --backend foo'` lost their "Invalid backend: foo" output: the wizard never reached that step). Symptom in CI: `lib/commands/init.sh: line 214: available[*]: unbound variable`.
- [x] [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) — new regression test "no 'unbound variable' under 'set -u' (bash 3.2 / pyve.sh contract)" that re-sources `lib/ui/core.sh` + `lib/commands/init.sh` from a fresh `/bin/bash -c "set -euo pipefail; ..."` shell with PATH cleaned to a manager-less directory. Locks in the contract: the helper must work under pyve.sh's runtime shell options.

**Tasks — Wizard tests independent of dev-machine asdf**

- [x] [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) `_stub_managers` — `rm -rf "$TEST_DIR/.fakebin"` at the start so each call resets prior stubs. Otherwise calling `_stub_managers pyenv` after a setup-time `_stub_managers asdf` would leave both stubs in place, breaking "only X" tests.
- [x] [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) `setup()` — call `_stub_managers asdf` so the default test environment has a usable manager. **Why:** L.k.2/L.k.3/L.k.5 tests pass `python_supplied="true"` to bypass the TTY guard (a leftover convention from when those args were 3-positional). With `python_supplied="true"` and `backend="venv"`, the wizard's flag-driven Python pin path runs, which calls `_init_detect_version_managers_available()` and **hard-fails by design** when no managers are on PATH. On dev macOS this never tripped because asdf is installed; on Linux CI without asdf/pyenv it tripped 11 wizard tests at once. Stubbing in setup gives those tests the manager they implicitly assumed; tests that explicitly test no-manager / single-manager / both-managers scenarios already override PATH or call `_stub_managers` themselves and remain unaffected.

**Tasks — `--backend auto` resolution**

- [x] [lib/commands/init.sh](../../lib/commands/init.sh) `_init_wizard` backend prompt — split the flag-set arm into two: `--backend auto` resolves through `_init_detect_backend_default` and renders `Backend: <resolved> (--backend auto, detected)`; non-auto values render verbatim as before. **Why:** previously, `pyve init --backend auto` left `backend_flag="auto"` through the Python prompt, where `if [[ "$backend_flag" == "micromamba" ]]` was false and the prompt fell to the venv branch — hard-failing on no managers even when `environment.yml` was clearly the right signal. The downstream `get_backend_priority` later resolved `auto` to a concrete backend, but the wizard never reached that step. Symptom in CI: `tests/integration/test_auto_detection.py::test_detects_micromamba_from_environment_yml` failed with the no-managers hard-fail message. Note: the wizard uses `_init_detect_backend_default` (file-only) rather than the full `get_backend_priority` (file + config), to avoid pulling in `get_backend_priority`'s ambiguous-detection prompt mid-wizard. The config-vs-file precedence mismatch is theoretical (an already-init'd project re-running with `--backend auto` while having a config that conflicts with files) and not currently observed.
- [x] [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) — 3 new tests for the `--backend auto` path: env.yml present → resolves to micromamba and routes the Python prompt through the micromamba branch; no signals → resolves to venv default; caller's `backend_flag` is mutated from `"auto"` to the resolved value.
- [x] [tests/unit/test_init_wizard.bats:214](../../tests/unit/test_init_wizard.bats#L214) — fixed a stale 3-arg `_init_wizard` call (leftover from the L.k.4 signature bump that wasn't caught by the bulk replace). Now passes 4 args matching the current contract.

**Tasks — wizard's project-guide block must not pre-resolve cases the post-env hook owns**

- [x] [lib/commands/init.sh](../../lib/commands/init.sh) `_init_wizard` project-guide prompt — **deps-managed branch** no longer assigns `project_guide_mode="no"`. The wizard renders `project-guide: managed by your project dependencies` as a summary; pg_mode stays empty so the existing `_init_run_project_guide_hooks` runs its detailed auto-skip-from-deps message ("Detected 'project-guide' in your project dependencies. Pyve will not auto-install or run 'project-guide init'…"). **Why:** pre-setting `"no"` made the hook hit the `--no-project-guide`-flag path, emitting a misleading `Skipping project-guide install (--no-project-guide)` (the user never passed that flag) and silencing the accurate deps-managed message. Symptom in CI: `tests/integration/test_project_guide_integration.py::TestAutoSkipWhenInProjectDeps::test_auto_skip_when_in_pyproject_toml` and `test_auto_skip_when_in_requirements_txt` both asserted the deps-managed message and failed.
- [x] [lib/commands/init.sh](../../lib/commands/init.sh) `_init_wizard` project-guide prompt — **non-TTY/bypass + no-flag + no-signal branch** no longer assigns `project_guide_mode="no"`. Renders `project-guide: (env / CI default)` and leaves pg_mode empty so the hook's existing priority-3/4/5/6 logic (PYVE_NO_PROJECT_GUIDE / PYVE_PROJECT_GUIDE / `project_guide_in_project_deps` / CI / PYVE_FORCE_YES / interactive) still applies. **Why:** pre-setting `"no"` broke the documented CI-default-install behavior (priority 5: "CI / PYVE_FORCE_YES → install"). With `CI=1` + `PYVE_TEST_ALLOW_PROJECT_GUIDE=1`, the hook *should* install project-guide, but the wizard short-circuited that. Symptom in CI: `TestRealInstall::test_install_with_completion_wires_everything`, `test_ci_asymmetry_install_yes_completion_no`, and `test_idempotent_reinstall_is_fast` all asserted `_project_guide_importable(test_project)` and failed because pg_mode="no" forced a skip.
- [x] [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) — updated 2 L.k.5 unit tests to assert the new contract: `project_guide_mode` stays empty in the deps-managed and non-TTY-no-signal branches (was previously asserted as `"no"`). The new assertions are aligned with the actual UX: the wizard's job is to render the user-visible summary; the hook owns the install/skip decision and emits the detailed reasoning.

**Tasks — Verification**

- [x] Reproduced the empty-array crash locally: `set -euo pipefail; a=(); printf "%s\n" "${a[*]}"` → `bash: a[*]: unbound variable` on `/bin/bash` (3.2.57). With the `:-` default → empty output, exit 0.
- [x] Simulated Linux CI by clearing PATH inheritance: `env -i HOME="$HOME" PATH=/usr/bin:/bin bats tests/unit/` — full suite **859/859 green** (zero `not ok`). This proves the unit-suite fix without needing to push and wait for CI.
- [x] Re-ran the previously failing pytest integration suites locally: `TestAutoSkipWhenInProjectDeps` (3 tests, was 2 failing) and `TestRealInstall` (3 tests, was 3 failing) — all 6 now pass.
- [x] Local full unit suite: 859/859 green. Pytest integration baseline matches L.k.6 (the pre-existing failures called out in the "Future: Fix pre-existing integration test failures" story are unchanged).

**Notes**

- L.k.7 is bundled into the L.k arc rather than treated as a standalone hotfix because both fixes are direct consequences of the wizard work and the natural inflection point is "CI is clean, ready for L.l." It still aggregates into the single `v2.6.0` bump in L.m.
- Future-pinned: the empty-array pattern is easy to reintroduce. A general-purpose bats test that greps for `"\${[a-z_]+\[[*@]\]}"` (without `:-` or `:?` defaults) across `lib/` could lock the contract more broadly. Deliberately not adding it here — the pattern is uncommon enough that one-off review at PR time is fine, and a noisy regex would catch lots of safe call sites.

---

### Story L.l: End-of-init 'Next steps:' summary [Done]

**Goal.** After successful `pyve init`, print a numbered "Next steps:" block tailored to the chosen backend and detected scaffolding. Replaces the current ad-hoc trailing banners with one coherent post-install summary.

**Tasks**

- [x] Inventory of pre-L.l trailing output: 4 ad-hoc info-line variants (per backend × direnv state) immediately before `footer_box`. None covered by existing tests (grep for the literal strings returned no results), so removal is safe.
- [x] Design locked: numbered list with conditional items:
  - **`cd <project>` deliberately omitted** — pyve init's `<dir>` arg is the venv-directory NAME (within cwd), not a project path. There's no current pyve flow where init runs in a different project dir than the user's cwd, so this step would never trigger; including it would be misleading.
  - `direnv allow` — when `--no-direnv` was **not** passed; always advise even when `.envrc` already exists (the user may not have run `direnv allow` yet).
  - `pyve run <command>` — substitutes for `direnv allow` under `--no-direnv` (alternative-activation pattern for CI/CD).
  - `pyve testenv install -r requirements-dev.txt` — when `requirements-dev.txt` exists. Init creates the testenv directory but doesn't install dev deps — the user still needs this command.
  - `Read docs/project-guide/go.md` — when `.project-guide.yml` exists (canonical install marker, matching `pyve update`'s detection signal). Covers both fresh-install and refresh cases.
  - Trailing micromamba+direnv caveat — preserved from the pre-L.l output ("ignore micromamba's 'activate' instructions above — Pyve uses direnv").
- [x] `_init_print_next_steps()` implemented in [lib/commands/init.sh](../../lib/commands/init.sh) (command-private per project-essential prefix rule). Signature: `_init_print_next_steps <backend> <no_direnv> <env_path>`; the `env_path` arg is reserved for a future verbose-mode log reference. Uses `banner` for the section header and `info` for the caveat; numbered items use `printf '  N. ...\n'`. Wired in to replace the ad-hoc trailing lines in both the venv and micromamba branches of `init_project()`.
- [x] **Verbose-mode log reference deferred.** L.g shipped with discard-on-success semantics for `run_quiet` — there is no persistent tmpfile to reference after a successful init. The signature reserves `env_path` for a future change if `run_quiet` ever grows a "keep on success" mode, but no verbose-only line is added today. (Verbose mode still streams subprocess output live, which is the user-visible difference.)
- [x] [features.md](features.md) FR-1 extended with FR-1b: precondition table + the micromamba+direnv caveat.
- [x] 12 bats unit tests in [tests/unit/test_init_next_steps.bats](../../tests/unit/test_init_next_steps.bats) covering: section header always present; direnv-allow vs pyve-run alternation; testenv install precondition (present/absent); project-guide go.md precondition (present/absent); micromamba caveat conditions (micromamba+direnv only); item numbering; combined all-conditions case.
- [x] 4 pytest integration tests in [tests/integration/test_init_next_steps.py](../../tests/integration/test_init_next_steps.py): block renders at end of init; `--no-direnv` substitutes pyve-run; testenv install hint when `requirements-dev.txt` exists; testenv install hint absent when no `requirements-dev.txt`. The "skips direnv" test uses `pyve.run("init", ...)` directly (rather than `pyve.init()`) so its `timeout=300` kwarg is treated as a subprocess timeout — a quirk of the test helper that was easier to work around than to fix in this story.

### Story L.m: Phase L wrap-up — project-essentials, version bump, phase closure [Done]

**When.** After every Phase L implementation story (L.b–L.l) is `[Done]` (or L.d explicitly deferred to a follow-up patch). This story is intentionally last in Phase L ordering so the `project-essentials.md` pass sees the codebase and docs **as they actually landed**, and so the single `v2.6.0` bump captures the entire phase's work in one release.

**Purpose.** Satisfy Acceptance criterion 7 in [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md): a focused hygiene pass over `docs/specs/project-essentials.md` plus the phase's single version bump.

**Tasks — capture new invariants**

- [x] Re-read Phase L artifacts (`phase-l-pyve-polish-audit.md`, phase-branch commits across L.b–L.l, the L.d project-guide-request spec).
- [x] Appended the two firm invariants from the plan as a single combined entry "**`lib/ui/` is the extractable UX boundary — pyve-agnostic with one exception**" — covers both the boundary contract and the verbosity gate (`PYVE_VERBOSE` as single source of truth, `is_verbose()` as the only check site, the `PYVE_VERBOSE` whitelist exception inside `lib/ui/core.sh`).
- [x] Appended unanticipated invariants surfaced during L.b–L.l:
  - **"Bash 3.2 empty-array reads must use the `:-` default"** — surfaced in L.k.7 as a CI-only crash (`pyve.sh`'s `set -euo pipefail` + bash 3.2's empty-array-as-unbound semantics killed `pyve init` mid-wizard on runners without asdf/pyenv installed). Captures the rule + the canonical regression-test shape so the next contributor can lock in the contract from new helpers.
  - **"`.project-guide.yml` is the canonical project-guide install marker"** — surfaced in L.k.5/L.k.6 once `pyve init` and `pyve update` both needed an "is project-guide installed?" signal. Pins the file (not the directory) as the source of truth, matching upstream's own state record. Prevents future divergence between consumers.

**Tasks — prune and correct stale essentials**

- [x] Walked `docs/specs/project-essentials.md` entry-by-entry. All 11 existing entries (File header conventions; Deprecation removal Cat A vs B; `is_asdf_active`; `lib/commands/<name>.sh`; explicit library sourcing; per-command help blocks; namespace single-files; uniform `.envrc`; function naming convention; function-name collision rule; cross-repo coordination with `project-guide`) verified accurate post-Phase-L. None reference the renamed `lib/ui.sh` or the dropped gitbetter-sync narrative — those references existed in the lib/ui.sh file's own header comment (replaced in L.e), not in project-essentials.md. Prune step is a no-op.

**Tasks — version bump and CHANGELOG**

- [x] [pyve.sh:32](../../pyve.sh#L32) `VERSION="2.4.0"` → `VERSION="2.6.0"`. Only source-of-truth pin (no `pyproject.toml` exists in this repo). Skipped v2.5.x per the phase plan — Phase L stories accumulated on the phase branch without per-story bumps and ship as one minor release.
- [x] [CHANGELOG.md](../../CHANGELOG.md) — new `## [2.6.0] - 2026-05-07` entry, grouped by user-visible theme (Added / Changed / Fixed / Documentation) rather than per-story. Lead paragraph names "Phase L — Pyve Polish" and the high-level theme; subsections cover the wizard (with full prompt/flag details), the verbosity policy, the `lib/ui/` library, the end-of-init summary, the L.j step framing, the L.b/L.c diagnostic correctness fixes, the L.k.7 CI-cleanup fixes (bash 3.2 empty-array, `--backend auto`, project-guide block deferral), and the documentation drift resolved.

**Tasks — close out Phase L**

- [x] Phase L acceptance criteria **1–6 and 8** confirmed:
  - **1.** L.a audit at `docs/specs/phase-l-pyve-polish-audit.md` exists and was reviewed.
  - **2.** L.b–L.l all `[Done]` (L.b, L.c, L.d, L.e, L.f, L.g, L.h, L.i, L.j, L.k.1–L.k.7, L.l).
  - **3.** Wizard / `--verbose` / step framing / end-of-init summary all shipped. Manual walkthrough is the developer's pre-merge gate (not a programmatic check).
  - **4.** Full bats suite green: 871/871 (verified under CI-like env via `env -i HOME="$HOME" PATH=/usr/bin:/bin bats tests/unit/`). Phase-L-introduced pytest tests green; pre-existing flaky/legacy failures tracked under "Future: Fix pre-existing integration test failures."
  - **5.** Doc drift resolved: features.md FR-1a/FR-1b, tech-spec.md "Interactive `pyve init` wizard" subsection, project-essentials.md (this story).
  - **6.** `lib/ui/` established + pyve-agnostic; boundary-invariant bats tests assert no pyve identifiers (with `PYVE_VERBOSE` whitelisted in `lib/ui/core.sh`).
  - **8.** Single v2.4.0 → v2.6.0 minor bump shipped with one consolidated CHANGELOG entry.
- [x] Marked `[Done]`. Phase branch is ready to merge to `main`.

---

### Story L.n: v2.6.1 hotfix — `ui_select` TTY escape leakage [Done]

**When.** Surfaced post-v2.6.0 ship via real-terminal use of the interactive `pyve init` backend prompt. Bug-report symptom from production:

```
$ pyve init
  ╭─────────────────────────────────────────╮
  │  pyve init                              │
  ╰─────────────────────────────────────────╯
Select backend
  > venv
    micromamba
  ✘ Unexpected backend choice index: 0
```

**Root cause.** [lib/ui/select.sh](../../lib/ui/select.sh) `_ui_select_tty` and `_ui_multi_select_tty` ran `tput civis` / `tput cnorm` with stdout undirected. `tput` writes capability strings to stdout by default — that's how terminals interpret them when invoked directly at a shell prompt. But when `ui_select` is called via `idx="$(ui_select ...)"` (the wizard's normal call shape), the captured stdout swallows those escape sequences too. `$idx` ends up being literally `<ESC>[?25l<ESC>[?25h0` (or similar), not the bare `"0"` the case statement expects. The wizard's `case "$choice_idx" in 0) ... 1) ... esac` falls to the catch-all and emits `Unexpected backend choice index: <visible-as-just-the-digit>`. Bats unit tests didn't catch it because they exercise the fallback path (non-TTY); only a real TTY drove the bug.

**Tasks**

- [x] [lib/ui/select.sh](../../lib/ui/select.sh) — every `tput civis` / `tput cnorm` call (8 sites total: `_ui_select_tty` lines 155/178/184/189; `_ui_multi_select_tty` lines 227/254/263/272) now redirects to `>&2`. The terminal still receives the escape sequences (stderr is the same TTY in interactive use, so cursor visibility behavior is preserved); stdout stays clean for `$(...)` capture.
- [x] [tests/unit/test_ui_select.bats](../../tests/unit/test_ui_select.bats) — new regression test "tput calls do not leak escape sequences to stdout (capture-safe)" greps the source file for any `tput civis|cnorm` line that lacks `>&2`. A future contributor adding an unredirected `tput` call breaks the build immediately.
- [x] [pyve.sh:32](../../pyve.sh#L32) `VERSION="2.6.0"` → `VERSION="2.6.1"`. Patch bump per semver: bug fix, no behavior change, no API change.
- [x] [CHANGELOG.md](../../CHANGELOG.md) — new `## [2.6.1] - 2026-05-07` entry above `[2.6.0]`, single Fixed bullet describing the escape-leak root cause and fix locations.
- [x] Full bats unit suite green: 872/872 (871 baseline post-L.m + 1 new regression test). Verified under CI-like env (`env -i HOME="$HOME" PATH=/usr/bin:/bin bats tests/unit/`).

**Notes**

- The bats test for the bug greps the source file for the contract violation rather than driving a real TTY — bats can't drive a TTY (per L.i / L.k.6's note). The grep-based check is the same pattern used by `lib/ui/run.sh` and `lib/ui/progress.sh`'s "no bash-4+ constructs" lock.
- `tput`-output-on-stdout is a well-known footgun for any UX library that gets composed via command substitution; the new regression test plus the project-essential added in L.m ("`lib/ui/` is the extractable UX boundary") together make this less likely to regress when the eventually-extracted standalone library lands.
- L.m's "Phase L closed" claim stands — the v2.6.0 bump shipped successfully, and L.n is a normal post-release patch on the same branch line. No phase reopening; if this were a larger fix it would be its own phase.

---

## Future

### Story ?.?: Apply Phase L UX framing to non-scaffold commands [Planned]

**Motivation**: Phase L scoped the `sv create`-grade rollout (step counters, quiet-replay, spinners) to `pyve init` and `pyve update` — the scaffold-shaped commands. The same treatment plausibly improves `pyve lock` (long conda solves), `pyve testenv install` (pip output), and `pyve purge --force` (multi-step confirmation + delete). The `lib/ui/` toolkit shipped in Phase L (`run.sh`, `progress.sh`) is generic enough to apply directly.

**Why deferred**: Phase L was already large after the option-1 expansion; rolling out to four more commands would have stretched it further. The scaffold commands are the canonical "first impression" surface so they were prioritized.

**Tasks** (sketched; refine when picked up):

- [ ] Walk each command, identify macro-steps, wrap with `step_begin`/`step_end_ok` + `run_quiet`.
- [ ] Decide whether `purge --force` warrants step framing or if the existing confirm flow is sufficient.
- [ ] Update `features.md` for any output-contract changes.
- [ ] Tests per the L.j pattern.

---

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
