# Phase L — Pyve Polish

> Diagnostic surface correctness, project-guide integration smoothness, terminal UX cohesion.

**Intended release version:** Single minor bump on phase merge to `main` (`v2.5.x` → `v2.6.0`). L.a was documentation-only and shipped no code; subsequent stories (L.b+) land on the phase branch without per-story version bumps and aggregate into one release. Story titles in `stories.md` therefore omit the `vX.Y.Z` suffix throughout Phase L.

**Theme.** Pyve has reached production-tool maturity, and the rough edges that remain are concentrated in three adjacent areas:

1. **Diagnostic-surface correctness.** `pyve status` and `pyve check` — read-only commands shipped in Phase H and re-homed in Phase K — have accreted small UX/correctness gaps. The canonical example: `pyve status` prints `Python: not pinned` for a micromamba project even though the version *is* pinned in `environment.yml`, and the very next section of the same output correctly shows the resolved interpreter version. One contradiction hints at a class.

2. **`pyve` ↔ `project-guide` integration.** `project-guide` (the sibling project that this codebase uses for its own `docs/project-guide/go.md`) has stabilized, but pyve's integration with it has rough edges across init, update, status, self, and shell-completion files. With `project-guide` no longer in flux, pyve's side of the contract should be tightened. **Cross-repo coordination.** Some Track-2 findings will be cleanest to fix on the project-guide side rather than working around them in pyve (e.g. if project-guide is chatty when invoked from pyve's hook context, the right answer may be a `--quiet` flag in project-guide, not output-suppression in pyve). In those cases L.a produces a small change-request spec for the project-guide repo; the developer ships that change in project-guide separately. The pyve-side L.b+ story that consumes the new behavior may carry a dependency on a specific project-guide minimum version.

3. **Terminal UX — `sv create`-grade scaffolding experience.** Pyve is chatty — most acutely during `pyve init --backend micromamba`, where bootstrap, conda solve, env creation, and dependency install each emit verbose subprocess output without a unifying frame. The phase's delivery target for the scaffold-shaped commands (`pyve init`, `pyve update`) is the `pnpm dlx sv create` bar: an interactive wizard with arrow-key selectors, smart defaults driven by repo signals (e.g. `environment.yml` → default backend = `micromamba`), quiet-by-default subprocess output with a `--verbose` opt-in, step-counter framing, spinners / progress bars during slow operations, and a numbered "Next steps:" summary at the end. `lib/ui.sh` provides primitives (banner / info / success / warn / fail / confirm / ask_yn / boxes / colors); Phase L grows that into a `lib/ui/` library covering the missing pieces (verbosity gate, quiet-replay-on-failure subprocess wrapper, progress / spinner module, arrow-key selector module).

   **Future-extraction shape.** The CLI UX library is intended to be lifted into its own repository so it can be reused by sibling projects (`gitbetter` and others). Phase L treats `lib/ui/` as the destination shape — a subdirectory whose contents become the package boundary for the eventual extraction. The existing `lib/ui.sh` migrates into the directory as `lib/ui/core.sh` in the dedicated foundation story (L.e); new UX modules (`lib/ui/run.sh`, `lib/ui/progress.sh`, `lib/ui/select.sh`) land as siblings in their own stories. Callers (`lib/commands/*.sh`) source from `lib/ui/` instead of `lib/ui.sh`. `lib/ui.sh` is **not** precious; the developer has explicitly cleared it for restructuring.

The phase ran an audit-driven discovery pass (Story L.a, completed) and is now in **execution-driven** mode. The audit cataloged findings across three tracks; the implementation slate (L.b through L.l) was committed after the developer chose to ship a `sv create`-grade UX rather than a foundation-only set of fixes. Implementation stories follow a **foundation-first order**: verbosity policy and core UX primitives land before they're rolled out to commands, and the interactive wizard lands after the selector module exists.

---

## Gap Analysis

### Track 1 — Diagnostic-surface correctness

**What exists today.**

- `lib/commands/status.sh` (~330 lines) — `show_status()` plus `_status_*` helpers organized into three sections: Project / Environment / Integrations. Backend-aware in `_status_section_environment` (separate `_status_env_venv` / `_status_env_micromamba` branches) but **not** in `_status_configured_python`, which only checks `.tool-versions`, `.python-version`, and `.pyve/config`'s `python.version` key.
- `lib/commands/check.sh` — `check_environment()` plus `_check_*` helpers; runs diagnostics that may exit non-zero. (Detailed structure to be catalogued during the audit.)
- Documented behavior: `features.md` "Status" and "Check" sections; `tech-spec.md` Phase H design references.
- Test coverage: bats unit tests for individual helpers; pytest integration tests exercise the commands black-box.

**What's missing.** A systematic catalogue of UX/correctness rough edges. Today the only known finding is the micromamba Python-pinning bug; there are almost certainly others (post-K rename drift in error messages, label/branch inconsistencies between backends, documented-but-unimplemented behaviors). Without an inventory, fixing them ad-hoc risks both missing related issues and double-touching the same files in successive small PRs.

### Track 2 — Project-guide integration

**What exists today.** Pyve touches `project-guide` from at least seven files:

- `lib/commands/init.sh` — installs `project-guide` into the project env when requested; runs `project-guide` hooks during init.
- `lib/commands/update.sh` — refreshes `project-guide` along with other project-level files.
- `lib/commands/status.sh` — reports `project-guide: installed (v…)` / `not installed`.
- `lib/commands/self.sh` — pyve self-install/uninstall plumbing (potential project-guide intersection).
- `lib/utils.sh` — shared helpers used across the above.
- `lib/completion/pyve.bash`, `lib/completion/_pyve` — shell completions referencing project-guide.

**What's missing.** `project-guide` has stabilized (it's running in this very session at v2.5.0), but pyve's side of the contract has not been retuned for that stability. The audit needs to capture the "really rough edges" the developer has been hitting — the specifics aren't currently inventoried, which is what L.a delivers. Findings split into two buckets: **(A)** pyve-side fixes (the default), and **(B)** project-guide-side change requests where the cleanest remedy is upstream (e.g. add a `--quiet` flag to project-guide rather than swallow its output in pyve). For bucket (B), L.a writes a focused change-request spec the developer can apply to the [project-guide repo](https://pointmatic.github.io/project-guide/) directly.

### Track 3 — Terminal UX

**What exists today.**

- `lib/ui.sh` — UI primitives (NO_COLOR-aware colors / symbols, `banner` / `info` / `success` / `warn` / `fail`, `confirm` / `ask_yn` Y/N prompts, `divider`, `run_cmd` echo-and-exec, `_edit_distance` for typo suggestions, `header_box` / `footer_box` rounded-corner frames). The file's header currently notes it is "kept in sync verbatim with the sibling `gitbetter` project" — that constraint is being lifted as part of Phase L's extraction-prep direction (see Theme §3).
- Cross-cutting noise: `pyve init`, especially with the micromamba backend, emits raw subprocess output from micromamba bootstrap, conda solve, env creation, and dependency install with no unifying step frame. Spinner-grade progress, step counters (`[2/5] Installing micromamba…`), and arrow-key selectors are not currently available.

**What's missing.**

- New UX primitives the existing library doesn't provide: step counters, spinners, progress bars, multi-step framing, arrow-key single/multi-select prompts, output-quieting helpers (capture noisy stdout/stderr from a long-running subprocess and replay only on failure).
- A directory-shape that telegraphs "this is the extractable UX library" — currently `lib/ui.sh` is one flat file alongside other `lib/*.sh` helpers. Phase L's target shape is a `lib/ui/` subdirectory housing every UX module, so the eventual extraction is a clean cut along that boundary.
- A "quiet by default" stance: today pyve assumes the user wants to see everything; the audit will likely conclude that the right default is the opposite, with `--verbose` (or `PYVE_VERBOSE=1`) opting into the current firehose.
- A coherent visual contract across all entry points (`init`, `update`, `lock`, `testenv install`, etc.) so that running pyve feels like running one tool, not five different ones.

---

## What This Phase Delivers

- `docs/specs/phase-l-pyve-polish-audit.md` — combined audit document, completed in Story L.a (delivered).
- `docs/specs/project-guide-requests/quiet-non-interactive-embedding.md` — upstream change-request spec from Track 2 (delivered with L.a).
- A `sv create`-grade scaffold experience for `pyve init` and `pyve update`:
  - **Interactive wizard** for `pyve init` with no args — arrow-key backend selector with smart default from repo signals (`environment.yml` → `micromamba`, `.python-version` → `venv`); flags act as "skip this question" overrides so `pyve init --backend venv` proceeds non-interactively for that parameter while still prompting for any unspecified ones.
  - **Quiet-by-default output** with `--verbose` / `PYVE_VERBOSE=1` opt-in restoring the current firehose; subprocess noise (micromamba bootstrap, conda solve, pip install) captured and replayed only on failure.
  - **Step-counter framing** (`[2/5] Installing micromamba…`) wrapped around macro-steps in init (both backends) and update.
  - **Spinner / progress** for slow operations (downloads, conda solve).
  - **End-of-init "Next steps:" summary** as a numbered actionable block.
- A `lib/ui/` library that grows the existing `lib/ui.sh` primitives into a cohesive set:
  - `lib/ui/core.sh` — the migrated `lib/ui.sh` (banner, prompts, colors, boxes, edit-distance).
  - `lib/ui/run.sh` — quiet-replay-on-failure subprocess wrapper.
  - `lib/ui/progress.sh` — step counter, spinner, progress bar primitives.
  - `lib/ui/select.sh` — arrow-key single/multi-select prompt.
  - All modules pyve-agnostic (no pyve paths, no pyve commands) so the eventual lift-out to a separate repo is a clean directory copy.
- Diagnostic-correctness fixes carried forward from the audit (Tracks 1–2): micromamba Python pin in `pyve status` (T1-01), `pyve check` help / `features.md` FR-5 alignment (T1-02), consume upstream `project-guide --quiet` once shipped (T2-01).
- Updated `features.md` / `tech-spec.md` for any documented-vs-actual drift surfaced by the work.

---

## Feature Requirements

**Functional contract** is per-finding and will be specified in each L.b+ story as that story is written. The phase-level contract is shape-only:

- **Backward compatibility.** No command renames, no flag renames, no exit-code changes — except where the audit identifies behavior that is already wrong relative to documented contract. `pyve init` becomes interactive when invoked with no args, but every existing flag-driven invocation continues to work non-interactively (flags suppress the corresponding prompt).
- **Quiet by default, verbose by opt-in.** Subprocess noise from `micromamba`, `conda`, `pip`, and `project-guide` is captured by default and replayed only on failure. `--verbose` flag and `PYVE_VERBOSE=1` env var restore the current firehose for CI logs and debugging workflows.
- **Test coverage per fix.** Every fix is accompanied by a unit test that fails before and passes after, demonstrating the bug and pinning the fix. UX changes get string-match tests (e.g. "step counter `[2/5]` appears in init output") at minimum; full-screen-rendering changes (selectors, spinners) may need a `read`-shim / expect-style harness or pragmatic visual review only.
- **Documentation.** Every fix that changes user-visible output text updates `features.md` if the documented contract is affected. The interactive wizard, verbosity policy, and end-of-init summary each carry a `features.md` update as part of their story.
- **New flags / env vars.** Phase L explicitly adds `--verbose` (top-level flag) and `PYVE_VERBOSE` (env var) — both pre-approved as part of this plan. No further new flags, commands, or env vars without separate developer approval.

The phase is **not** the place to ship `pyve check --fix` (Auto-Remediation). That remains in `## Future` and depends on this phase's output as input.

---

## Technical Changes

### L.a — Audit (no code changes)

- **New file**: `docs/specs/phase-l-pyve-polish-audit.md` — the findings document with three sections, one per track.
- **Inputs (Track 1)**: `lib/commands/status.sh`, `lib/commands/check.sh`, `lib/utils.sh` helpers used by them, `features.md` Status/Check sections, current output on representative venv and micromamba projects.
- **Inputs (Track 2)**: every file under `lib/` that mentions `project-guide` (currently: `lib/commands/init.sh`, `lib/commands/update.sh`, `lib/commands/status.sh`, `lib/commands/self.sh`, `lib/utils.sh`, `lib/completion/pyve.bash`, `lib/completion/_pyve`); `features.md` project-guide section; the [project-guide command reference and docs](https://pointmatic.github.io/project-guide/) for the upstream contract surface (commands: `init`, `mode`, `override`, `update`, `status`; flags; output behavior); and a session of running pyve commands against a project-guide-enabled project to record observed friction. For each Track-2 finding the audit explicitly decides locus (pyve-side vs upstream) and writes the corresponding artifact (Phase L story or `docs/specs/project-guide-requests/<short-name>.md` spec).
- **Inputs (Track 3)**: `lib/ui.sh` (current capabilities), every command that emits multi-step output (`init`, `update`, `lock`, `testenv install`, `purge --force`), the micromamba bootstrap path specifically (because the developer flagged it as the worst offender), and reference UX from `npm create vite@latest` / `npm create svelte@latest` for direction-setting. The audit also proposes the final shape of `lib/ui/` (which modules, which boundaries) — actual reorganization stays in implementation stories.
- **Method**: code-walk all three tracks; capture observed behavior vs. expected; tag each finding with fix size and (Track-1) `--fix`-automation potential.
- **Output**: numbered findings table per track + per-finding short writeups + a "suggested story slate" mapping findings → proposed L.b+ titles, ordered by suggested implementation sequence.

### L.b+ — Implementation stories (foundation-first order)

Stories were committed post-audit. The operational pattern:

- Each story scoped to **one** finding (or one tightly-related cluster). Touched files vary by track:
  - Track-1 fixes touch `lib/commands/status.sh` and/or `lib/commands/check.sh` plus matching bats tests (L.b, L.c).
  - Track-2 fix (L.d) touches the project-guide-aware wrappers in `lib/utils.sh` plus integration tests against a synthetic project-guide-enabled project. **Track-2 upstream finding** is captured in `docs/specs/project-guide-requests/quiet-non-interactive-embedding.md` for a separate project-guide release; L.d carries an explicit dependency note ("requires project-guide ≥ vX.Y.Z") and a check-or-fail guard. **If upstream doesn't ship within the phase window, L.d defers to a follow-up patch release** rather than blocking phase merge.
  - Track-3 work is split into a dedicated foundation pass (L.e: `lib/ui.sh` → `lib/ui/core.sh` migration with no new primitives), three new-module stories (L.g/L.h/L.i), a verbosity-gate story (L.f), then rollout stories (L.j: framing across `init`+`update`; L.k: interactive wizard; L.l: end-of-init summary). Per the explicit-sourcing project-essential, every `source` line in `pyve.sh` is updated when modules move or are added.
- **No per-story version bumps.** All Phase L work lands on the phase branch; a single `v2.5.x` → `v2.6.0` minor bump ships when the branch merges to `main`. Story titles in `stories.md` therefore omit `vX.Y.Z` throughout.
- **Foundation-first ordering.** Stories L.e (lib/ui/ migration) → L.f (verbosity gate) → L.g (quiet-replay wrapper) → L.h (progress primitives) → L.i (selector primitive) build the toolkit before any rollout story uses it. L.j/L.k/L.l consume the foundation. L.b/L.c/L.d are independent correctness/integration fixes that can land at any point; L.b should land early so the audit's seed finding is closed.

### Constraints carried forward

- **Pure Bash, no runtime dependencies** (`concept.md`). External UX libraries (`gum`, `dialog`, `whiptail`, `fzf`) are out of scope. All fancy UX must be built from `tput`, ANSI escapes, `read -sn1`, and the existing edit-distance / box / color primitives.
- **`lib/ui/` is the extractable boundary.** Modules under `lib/ui/` must not import pyve-specific identifiers (paths like `.pyve/`, command names like `pyve init`, config keys, etc.). The pure-UX primitives (colors, prompts, progress, selectors) stay generic so the eventual lift-out is a clean cut. Pyve-specific glue stays outside `lib/ui/` (in `lib/commands/*.sh` or topic-specific `lib/<topic>.sh` files).
- **macOS / Linux only**, including bash 3.2 compatibility on macOS — same constraint that pinned the `_edit_distance` 1-D array implementation in `lib/ui.sh`.

### New architectural invariants

Phase L introduces two new entries to `project-essentials.md`, both appended at the **end** of the phase per plan_phase Step 7 (not per-story). Both are now firm — the foundation-first slate guarantees the preconditions hold:

1. **`lib/ui/` is the boundary of the extractable CLI UX library.** Modules under that directory stay pyve-agnostic (no pyve paths, no pyve commands, no pyve config keys) so the eventual lift-out into a standalone repo is a clean directory copy. Pyve-specific glue lives outside `lib/ui/`.
2. **"Quiet by default, verbose by opt-in"** as a UX policy — pyve commands suppress subprocess noise on the happy path; `--verbose` / `PYVE_VERBOSE=1` opts into the firehose. The single source of truth for the verbosity gate is in `lib/ui/core.sh`; primitives (`info`, `run_cmd`, the new `lib/ui/run.sh` quiet-replay wrapper) honor it without each command re-implementing the check.

---

## Out of Scope

The following Future stories are deliberately **not** in Phase L. They remain in `docs/specs/stories.md` `## Future`:

- **Auto-Remediation for Diagnostics (`pyve check --fix`).** Depends on this phase's audit output as input. Premature to ship before knowing what to remediate. Will be revisited as a candidate for Phase M or later.
- **SHA256 verification of bootstrap download.** Bootstrap hardening — unrelated to the diagnostic surface or UX. Independent track.
- **Micromamba `--micromamba-version` pinning.** Bootstrap concern, not a Phase-L theme. (However: if Track-3 fixes the micromamba init noise problem, the work may **touch** the bootstrap code path; the version-pinning feature itself stays deferred.)
- **Fix pre-existing integration test failures.** Orthogonal CI hygiene — can ship in any phase.
- **Specific `pyve status` Python-pinning fix for micromamba projects.** This is the *seed finding* and L.a's Track 1 will surface it. Leaving it in `## Future` rather than pre-committing it as L.b avoids forcing the audit's hand. Promotion happens during or immediately after L.a.

Out of scope for Phase L itself:

- **Implementing project-guide change requests.** Phase L produces specs under `docs/specs/project-guide-requests/` for any upstream-located findings; the actual implementation happens in the [project-guide repo](https://pointmatic.github.io/project-guide/) on its own release cycle. Phase L only ships the pyve-side consumption (L.d) of those changes, and only after the corresponding project-guide release is available.
- **Major refactors** of `status.sh` or `check.sh` internals beyond what a finding directly requires. If the audit identifies a structural problem requiring a rewrite (e.g. "status output should be data-driven from a config schema"), that becomes its own phase, not an L.* story.
- **UX rollout to non-scaffold commands.** `pyve lock`, `pyve testenv install`, `pyve purge --force` keep their current output behavior — they are explicitly **not** wrapped in step framing or quiet-replay during Phase L. The `lib/ui/` toolkit is built generically so a future phase can apply the same treatment to one-shot ops if/when the developer wants it; Phase L scopes the rollout to `pyve init` (both backends) and `pyve update`.
- **New backends** (uv, poetry support). Out-of-band concern.
- **Output format changes** beyond fixing incorrect labels/values — no JSON output, no `--format` flag, no machine-readable status. If audit findings touch output structure, they're scoped narrowly to fixing the bug, not adding modes.
- **External UX libraries** (`gum`, `dialog`, `whiptail`, `fzf`). Pure-bash invariant holds.
- **Actual extraction of `lib/ui/` to a separate repository.** Phase L *prepares* for that extraction (clean boundary, no pyve-isms inside `lib/ui/`) but does not perform it. The extraction itself is a future cross-repo operation outside this phase's scope.
- **Test infrastructure changes.** Phase L adds tests at the unit-fix and command-rollout level; no new harnesses (e.g. expect/tig) unless a story directly needs one for selector / spinner verification, in which case it's scoped narrowly.

---

## Stories

Implementation order matches the foundation-first rule from §Technical Changes: foundation primitives (L.e–L.i) land before any rollout (L.j–L.l) consumes them; correctness/integration fixes (L.b–L.d) are independent and slot in early.

### L.a — Audit `pyve status` / `pyve check`, project-guide integration, and terminal UX **[Done]**

The phase's spike: produced the three-section findings document at `docs/specs/phase-l-pyve-polish-audit.md` and one upstream change-request spec at `docs/specs/project-guide-requests/quiet-non-interactive-embedding.md`. No code changes, no version bump.

### L.b — Status: micromamba Python pin from `environment.yml`

Backend-aware `_status_configured_python` — fixes the **T1-01** seed contradiction (Project: `not pinned` vs Environment: `3.12.13`). venv path unchanged. Pure correctness; small bats branch additions.

### L.c — Align check help / `features.md` FR-5 with shipped diagnostics

Stale "pyve status coming…" in `show_check_help`; reconcile FR-5's claimed checks (Python version gate, distutils shim) with what `check.sh` actually runs. Defaults to docs-side trim; spike whether to actually implement the deferred checks.

### L.d (+ upstream) — Consume upstream `project-guide --quiet`

Depends on `quiet-non-interactive-embedding.md` shipping in the project-guide repo. Once available, `lib/utils.sh` wrappers (`run_project_guide_init_in_env`, `run_project_guide_update_in_env`) pass the flag and pin a minimum project-guide version. **If upstream doesn't ship within the phase window, this story defers to a follow-up patch release** rather than blocking phase merge.

### L.e — `lib/ui/` directory establishment + `lib/ui.sh` migration

Foundation story for all subsequent UX work. Move `lib/ui.sh` → `lib/ui/core.sh`, update every `source` line in `pyve.sh` per the explicit-sourcing project-essential, lift the "verbatim sync with gitbetter" comment, refresh callers to source the new path. **No new primitives in this story** — it's pure structural prep.

### L.f — Verbosity policy: `--verbose` / `PYVE_VERBOSE=1`

Add the verbosity gate: a single source of truth (`PYVE_VERBOSE`) settable by `--verbose` flag (parsed in `pyve.sh`) or env, threaded through `lib/ui/core.sh` so primitives (`info`, `run_cmd`, future helpers) honor it. Default: quiet. **No command output changes yet** — this story just lands the gate; rollout happens in L.j.

### L.g — `lib/ui/run.sh`: quiet-replay-on-failure subprocess wrapper

New module wrapping noisy long-running subprocesses (micromamba bootstrap, conda solve, pip install). Captures stdout/stderr to a temp buffer; on success, prints nothing (or one summary line); on failure, replays the full captured output with the failing command echoed. Honors the L.f verbosity gate (when verbose, output streams live). Bash 3.2 compatible.

### L.h — `lib/ui/progress.sh`: step counter, spinner, progress bar

New module providing `step_begin "<n/m> <label>"`, `step_end_ok` / `step_end_fail`, `spinner_start` / `spinner_stop`, and an indeterminate ASCII progress bar for slow ops. Pure `tput` + ANSI; no external deps. Honors the L.f verbosity gate (suppressed under `PYVE_VERBOSE=1` so raw output isn't double-decorated).

### L.i — `lib/ui/select.sh`: arrow-key single/multi-select prompt

New module providing `ui_select <label> <option1> <option2>...` returning the chosen index, with arrow-key navigation, enter-to-confirm, escape-to-cancel. Falls back to numbered prompt when stdin is not a TTY (CI safety).

### L.j — Step-framing rollout: `pyve init` (both backends) + `pyve update`

Wrap macro-steps in `init` and `update` with `lib/ui/progress.sh` step counters and `lib/ui/run.sh` quiet-replay. Subprocess output is silent on the happy path; on failure the captured noise is replayed. After this story, scaffold-shaped commands hit the `sv create`-grade output bar.

### L.k — Interactive `pyve init` wizard (red-carpet experience)

`pyve init` with no args opens a welcome banner, then interactive prompts using `lib/ui/select.sh`: backend (default driven by repo signals — `environment.yml` → `micromamba`, `.python-version` → `venv`), confirmation. Flags act as overrides: `pyve init --backend venv` skips the backend question; any flag-provided parameter skips its corresponding question. Strong repo signals make the happy path "press enter through the defaults."

### L.l — End-of-init "Next steps:" summary

After successful `pyve init`, print a numbered "Next steps:" block (e.g., `1. cd <project>`, `2. direnv allow`, `3. pyve test`) tailored to backend and detected scaffolding. Replaces the current ad-hoc trailing banners with a coherent post-install summary.

### L.zz — Phase L wrap-up (project-essentials + closure)

Detailed task list lives in [`stories.md`](stories.md). Runs last, after every other Phase L story is `[Done]` (or L.d explicitly deferred to a follow-up release). This is also when the single `v2.6.0` version bump and consolidated CHANGELOG entry land before merging the phase branch to `main`.

---

## Acceptance for Phase Completion

Phase L is complete when:

1. L.a's audit document exists at `docs/specs/phase-l-pyve-polish-audit.md` with all three sections populated and has been reviewed. **(Done)**
2. Every implementation story (L.b–L.l) is marked `[Done]` on the phase branch, **except L.d** which may defer to a follow-up patch release if the upstream `project-guide --quiet` change has not shipped within the phase window.
3. **`pyve init` (both backends) and `pyve update` deliver the `sv create`-grade experience**: interactive wizard for `pyve init` with no args, smart defaults from repo signals, quiet-by-default subprocess output with `--verbose` opt-in, step-counter framing, spinners/progress for slow ops, end-of-init "Next steps:" summary. Manual walkthrough captured (transcript or screen-recording reference) and shared with the developer for sign-off before phase merge.
4. The full test suite (bats unit + pytest integration) is green on the phase branch.
5. Any documentation drift identified by the audit or surfaced during L.b–L.l (`features.md` / `tech-spec.md` mismatch with actual behavior) has been resolved.
6. **`lib/ui/` is established and pyve-agnostic** — modules under it import no pyve-specific identifiers (paths, command names, config keys); `pyve.sh` sources each module explicitly per the project-essential.
7. **Story L.zz completes** — performs the mandated `docs/specs/project-essentials.md` hygiene pass once L.b–L.l are `[Done]` (or L.d deferred):
   - **Append two firm invariants** (`lib/ui/` extractable boundary; quiet-by-default verbosity policy with `PYVE_VERBOSE` as single source of truth) plus any unanticipated invariants surfaced during implementation.
   - **Prune stale items.** Walk every existing entry in `project-essentials.md` and confirm it's still accurate and still relevant. Phase L's UX work may obsolete or contradict prior invariants (e.g. the `lib/ui.sh` "verbatim sync with gitbetter" narrative that Phase L replaces). Removing or rewriting existing entries is normally `refactor_plan`'s job, but Phase L explicitly opts into a one-shot Phase-end tidy via L.zz — not wholesale file rewrites; substantive structural re-org stays `refactor_plan`.
8. **Single `v2.5.x` → `v2.6.0` minor bump** ships when the phase branch merges to `main`, with one consolidated CHANGELOG entry covering all of L.b–L.l.
