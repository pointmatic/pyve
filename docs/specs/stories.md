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

### Story L.i: `lib/ui/select.sh` — arrow-key single/multi-select prompt [Planned]

**Goal.** New module providing arrow-key selectors for the L.k interactive wizard. Falls back to a numbered prompt when stdin is not a TTY (CI safety). **No callers wired up yet** — that happens in L.k.

**Tasks**

- [ ] Create `lib/ui/select.sh` with:
  - `ui_select <label> <option1> <option2>...` — single-select: arrow-key navigation, enter-to-confirm, escape-to-cancel; returns the chosen option's index on stdout (exit code 0); returns non-zero on cancel.
  - `ui_multi_select <label> <option1> <option2>...` — multi-select with space-bar to toggle, enter to confirm; returns selected indices.
  - Optional `--default <n>` arg to pre-highlight a default option (used by L.k for repo-signal-driven defaults).
- [ ] TTY fallback: when `stdin` is not a TTY (CI), fall back to a numbered prompt (`1) venv, 2) micromamba, [1]:`) so the wizard remains scriptable.
- [ ] Bash 3.2 compatible — `read -sn1` for arrow-key bytes, parse escape sequences manually.
- [ ] Add `source lib/ui/select.sh` to `pyve.sh` per explicit-sourcing project-essential.
- [ ] Keep the module pyve-agnostic.
- [ ] bats unit tests: piping numeric input through the TTY-fallback path returns the expected index; cancel path returns non-zero; default-highlight is honored.

---

### Story L.j: Step-framing rollout — `pyve init` (both backends) + `pyve update` [Planned]

**Goal.** Wire L.g (`run_quiet`) and L.h (`step_begin` / `step_end_ok`) into `pyve init` and `pyve update` macro-steps. Subprocess output is silent on the happy path; on failure the captured noise is replayed. After this story, the scaffold-shaped commands hit the `sv create`-grade output bar.

**Tasks**

- [ ] Walk `lib/commands/init.sh` venv path: identify macro-steps (e.g. *create venv*, *install requirements*, *write `.envrc`*, *project-guide install*) and wrap each with `step_begin`/`step_end_ok` + `run_quiet` for the noisy subprocess.
- [ ] Walk `lib/commands/init.sh` micromamba path (audit's worst offender): identify macro-steps (*bootstrap micromamba*, *create env*, *install deps*, *install distutils shim*, *write `.envrc`*, *project-guide install*); wrap each.
- [ ] Walk `lib/commands/update.sh`: identify macro-steps (*refresh `.gitignore`*, *refresh `.vscode/settings.json`*, *refresh `.pyve/config`*, *project-guide update*); wrap each.
- [ ] Confirm `--verbose` / `PYVE_VERBOSE=1` reverts each command to the current firehose behavior (output streams live, no decoration).
- [ ] Confirm failure paths replay the captured subprocess output.
- [ ] Update `features.md` Init / Update sections to reflect the new output behavior.
- [ ] bats unit tests + pytest integration tests: happy-path output matches the expected step-framed format; failure path includes the captured subprocess output.

---

### Story L.k: Interactive `pyve init` wizard (red-carpet experience) [Planned]

**Goal.** `pyve init` with no args opens a welcome banner, then walks the user through a guided setup using `lib/ui/select.sh` (L.i) prompts. Strong repo signals make the happy path "press enter through the defaults." Flags act as overrides — any flag-provided parameter skips its corresponding prompt — so existing flag-driven invocations remain non-interactive.

**Tasks — design**

- [ ] Inventory every flag that `pyve init` accepts today (`--backend`, `--auto-bootstrap`, `--bootstrap-to`, `--project-guide`, `--no-project-guide`, `--force`, etc.). Each is a candidate interactive prompt with the flag as its "skip this question" override.
- [ ] Decide which inventory items become interactive prompts in the wizard. Minimum viable set:
  - **Backend** (`venv` / `micromamba`) — default driven by repo signals: `environment.yml` present → `micromamba`; `.python-version` or `.tool-versions` present → `venv`; otherwise prompt with `venv` as default.
  - **project-guide install** (yes/no) — default `yes` if running in a repo that already has `docs/project-guide/` or a `.project-guide.yml`; otherwise default `no` and let the user opt in.
  - **Python version pin** (skip / pick from installed asdf versions / type a version) — only prompt for venv backend; micromamba pins via `environment.yml`. Default: skip (current behavior).
- [ ] Out of scope for L.k: testenv creation prompt (testenv is a follow-up command, not an init concern), bootstrap location (`--bootstrap-to`), `--force` — these stay flag-only.
- [ ] Document the prompt set + default-resolution rules in `tech-spec.md` (new "Interactive init wizard" subsection).

**Tasks — implementation**

- [ ] Detect "no relevant flags" entry point in `init_project()` — when true, route to `_init_wizard()` to gather any unspecified parameters. When a flag is present for a given parameter, skip that prompt and use the flag value.
- [ ] Implement `_init_wizard()` in `lib/commands/init.sh` (command-private per the project-essential prefix rule). Uses `ui_select` (L.i) for each prompt; threads the resolved values into the existing `init_project()` codepath so post-wizard the flow is identical to flag-driven init.
- [ ] Welcome banner at the top of the wizard (use existing `header_box` from `lib/ui/core.sh`).
- [ ] Repo-signal detection helpers — small functions that inspect `environment.yml`, `.python-version`, `.tool-versions`, `docs/project-guide/`, `.project-guide.yml` and return the appropriate default. Live in `lib/commands/init.sh` (command-private; no other command needs them).
- [ ] TTY check: if stdin is not a TTY, the wizard refuses to run interactively and prints a clear error pointing the user at `--backend` and friends. (`lib/ui/select.sh` handles the basic fallback for the per-prompt case, but the welcome banner + multi-prompt flow should hard-fail rather than degrade.)
- [ ] Update `features.md` Init section to document the new interactive flow + the flag-override behavior.

**Tasks — tests**

- [ ] bats unit tests for repo-signal detection helpers (each branch of the default-resolution rules).
- [ ] pytest integration test: `pyve init --backend venv` (flag-driven) skips the backend prompt and proceeds non-interactively.
- [ ] pytest integration test: `pyve init` in an `environment.yml`-containing directory defaults the backend prompt to `micromamba` and accepts the default on enter (expect-style stdin scripting if needed).
- [ ] pytest integration test: `pyve init` with stdin not a TTY exits non-zero with an error pointing at `--backend`.

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
