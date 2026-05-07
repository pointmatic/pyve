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

### Story L.k.4: Wizard — Python version pin prompt [Planned]

**Goal.** Add the Python pin prompt. Most involved sub-story: version-manager picker, "pick from installed", `more...` secondary prompt with filtered full list, skip path, no-manager hard-fail. Only runs when backend is `venv`.

**Tasks**

- [ ] Skip the entire pin prompt when backend is `micromamba` (env.yml owns the pin).
- [ ] Detect installed version managers: presence checks for `asdf` and `pyenv` on `PATH`. If neither is installed, hard-fail with a clear message naming both as the supported set and pointing the user at the relevant install docs.
- [ ] Version-manager sub-prompt: `ui_select` with options `[asdf, pyenv]` and asdf as default. Skipped if only one is installed.
- [ ] "Pick from installed" prompt:
  - asdf: parse `asdf list python` (strip leading `*` and whitespace).
  - pyenv: parse `pyenv versions --bare`.
  - Filter to `^3\.` numeric prefix.
  - Final option `more...` re-prompts with the full available list (`asdf list all python` / `pyenv install --list`), same `^3\.` filter applied.
  - Skip option (preserve current no-pin behavior).
- [ ] On selection, write the appropriate pin file using existing pyve conventions: `.tool-versions` for asdf, `.python-version` for pyenv.
- [ ] bats unit tests for each branch: asdf installed-list parsing, pyenv installed-list parsing, `more...` flow with mocked manager output, skip path, no-manager hard-fail, single-manager auto-pick (skips the picker sub-prompt), `^3\.` filter correctness.

---

### Story L.k.5: Wizard — project-guide install prompt [Planned]

**Goal.** Last prompt in the wizard. If project-guide is already present in the target dir, run `project-guide update` instead of prompting (the safe refresh path).

**Tasks**

- [ ] Detection helper `_init_detect_project_guide_present` in [lib/commands/init.sh](../../lib/commands/init.sh): returns true iff `.project-guide.yml` exists in the target dir. This matches the existing detection signal used by `pyve update` ([lib/commands/update.sh:123](../../lib/commands/update.sh#L123)) — `.project-guide.yml` is the canonical install marker (records `installed_version`, `target_dir`, `current_mode`); `docs/project-guide/` alone is not a reliable signal because the directory could exist for unrelated reasons or be relocated via `target_dir`.
- [ ] When already present and no flag is supplied: skip the prompt, run `project-guide update` via the existing `run_project_guide_update_in_env` wrapper in [lib/utils.sh](../../lib/utils.sh).
- [ ] When not present and no flag is supplied: prompt with default `no`. On `yes`, route through the existing project-guide install path (`install_project_guide` + the embedded-init wrapper).
- [ ] Flag-override path: `--project-guide` always installs/updates regardless of detection; `--no-project-guide` always skips. Explicit flag wins over detection.
- [ ] bats unit tests for each branch: detection-true (`.project-guide.yml` present) → update path, detection-false → default-no prompt, `--project-guide` with already-present (update) and absent (install), `--no-project-guide` short-circuit.

---

### Story L.k.6: Wizard — end-to-end integration + features.md [Planned]

**Goal.** Close out the wizard work: features.md documentation update and the integration tests from the original L.k slate.

**Tasks**

- [ ] Update [features.md](features.md) Init section to document the interactive wizard, prompt set, default-resolution rules, flag-override behavior, and TTY policy.
- [ ] pytest integration test: `pyve init --backend venv` (flag-driven) skips the backend prompt and proceeds non-interactively.
- [ ] pytest integration test: `pyve init` in an `environment.yml`-containing directory defaults the backend prompt to `micromamba` and accepts the default on enter (expect-style stdin scripting if needed).
- [ ] pytest integration test: `pyve init` with stdin not a TTY exits non-zero with an error pointing at `--backend`.
- [ ] Cross-check the shipped wizard against L.k.1's design subsection in tech-spec.md; close any gap surfaced by the integration tests.

---

### Story L.l: End-of-init "Next steps:" summary [Planned]

**Goal.** After successful `pyve init`, print a numbered "Next steps:" block tailored to the chosen backend and detected scaffolding. Replaces the current ad-hoc trailing banners with one coherent post-install summary.

**Tasks**

- [ ] Inventory the current ad-hoc trailing output from `pyve init` (both backends, with and without project-guide install) — what gets printed after success today, and which lines are still relevant once the rest of Phase L's framing is in place.
- [ ] Design the unified summary block. Minimum content: numbered list of next actions tailored to context:
  - `cd <project>` (only when init was run for a different directory).
  - `direnv allow` (always — even when `.envrc` already exists, the user may not have allowed it yet).
  - `pyve testenv install -r requirements-dev.txt` (only when `requirements-dev.txt` exists and testenv was not just installed).
  - `Read docs/project-guide/go.md` (when project-guide was just installed and the developer is expected to start a session).
- [ ] Implement `_init_print_next_steps()` (command-private, in `lib/commands/init.sh`). Called at the end of `init_project()` on success. Use `lib/ui/core.sh` primitives for formatting.
- [ ] Honor `is_verbose()` — verbose mode appends a line referencing the captured subprocess logs (e.g., "Full subprocess output: <tmpfile>") when L.g's quiet-replay path produced one.
- [ ] Update `features.md` Init section to document the summary block.
- [ ] bats unit tests + pytest integration tests: each conditional branch of the summary appears when its precondition holds and is omitted otherwise.

### Story L.zz: Phase L wrap-up — project-essentials, version bump, phase closure [Planned]

**When.** After every Phase L implementation story (L.b–L.l) is `[Done]` (or L.d explicitly deferred to a follow-up patch). This story is intentionally last in Phase L ordering so the `project-essentials.md` pass sees the codebase and docs **as they actually landed**, and so the single `v2.6.0` bump captures the entire phase's work in one release.

**Purpose.** Satisfy Acceptance criterion 7 in [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md): a focused hygiene pass over `docs/specs/project-essentials.md` plus the phase's single version bump.

**Tasks — capture new invariants**

- [ ] Re-read Phase L artifacts (`phase-l-pyve-polish-audit.md`, accumulated phase-branch commits across L.b–L.l, any new `docs/specs/project-guide-requests/*.md`).
- [ ] Append the two firm invariants from the plan:
  - **`lib/ui/` extractable boundary** — modules under `lib/ui/` stay pyve-agnostic (no pyve paths, command names, or config keys).
  - **Quiet by default, verbose by opt-in** — `PYVE_VERBOSE` is the single source of truth in `lib/ui/core.sh`; primitives honor it via `is_verbose()` rather than re-implementing the env-var check.
- [ ] Append new `###` subsections for any **unanticipated** invariant that surfaced during L.b–L.l implementation but was not pre-committed in the plan.

**Tasks — prune and correct stale essentials**

- [ ] Walk `docs/specs/project-essentials.md` entry-by-entry. For each subsection, verify it matches current code, filenames, conventions, and post–Phase-L reality.
- [ ] Rewrite or delete subsections that are **clearly superseded**, **incorrect**, or **no longer actionable** — this is Phase L–sanctioned one-shot tightening, not carte blanche to reorganize the file wholesale (large-scope restructuring stays `refactor_plan`).
- [ ] Specifically re-check entries that cite `lib/ui.sh` / UX constraints that Phase L superseded (e.g. verbatim sync with sibling projects vs. extracted `lib/ui/` library). Update wording to match shipped state.

**Tasks — version bump and CHANGELOG**

- [ ] Bump the package version from `v2.5.x` to `v2.6.0` in every source-of-truth (`pyve.sh` `VERSION`, `pyproject.toml` if present, any other version pin).
- [ ] Write a single consolidated CHANGELOG entry covering all of L.b–L.l (interactive wizard, verbosity policy, `lib/ui/` library, step framing, end-of-init summary, diagnostic-correctness fixes). Group by user-visible theme rather than per-story.

**Tasks — close out Phase L**

- [ ] Confirm [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md) Acceptance criteria **1–6** and **8** are satisfied (criterion **7 is this story** — the `project-essentials.md` pass and version bump above complete it).
- [ ] Mark this story `[Done]`. Phase branch is now ready to merge to `main`.

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
