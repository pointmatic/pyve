# Phase L — Pyve Polish

> Diagnostic surface correctness, project-guide integration smoothness, terminal UX cohesion.

**Intended release version:** TBD per story. L.a is documentation-only (no version bump). Subsequent stories (L.b+) will each carry their own minor / patch bump as they ship; the phase is **not** a single atomic release.

**Theme.** Pyve has reached production-tool maturity, and the rough edges that remain are concentrated in three adjacent areas:

1. **Diagnostic-surface correctness.** `pyve status` and `pyve check` — read-only commands shipped in Phase H and re-homed in Phase K — have accreted small UX/correctness gaps. The canonical example: `pyve status` prints `Python: not pinned` for a micromamba project even though the version *is* pinned in `environment.yml`, and the very next section of the same output correctly shows the resolved interpreter version. One contradiction hints at a class.

2. **`pyve` ↔ `project-guide` integration.** `project-guide` (the sibling project that this codebase uses for its own `docs/project-guide/go.md`) has stabilized, but pyve's integration with it has rough edges across init, update, status, self, and shell-completion files. With `project-guide` no longer in flux, pyve's side of the contract should be tightened. **Cross-repo coordination.** Some Track-2 findings will be cleanest to fix on the project-guide side rather than working around them in pyve (e.g. if project-guide is chatty when invoked from pyve's hook context, the right answer may be a `--quiet` flag in project-guide, not output-suppression in pyve). In those cases L.a produces a small change-request spec for the project-guide repo; the developer ships that change in project-guide separately. The pyve-side L.b+ story that consumes the new behavior may carry a dependency on a specific project-guide minimum version.

3. **Terminal UX.** Pyve is chatty — most acutely during `pyve init --backend micromamba`, where bootstrap, conda solve, env creation, and dependency install each emit verbose subprocess output without a unifying frame. Modern best-of-breed scaffolding tools (`npm create vite@latest`, `npm create svelte@latest`) demonstrate what's achievable: clear multi-step framing, minimal noise on the happy path, interactive selectors for choices, visual progress that doesn't scroll past you. `lib/ui.sh` provides primitives (banner / info / success / warn / fail / confirm / ask_yn / boxes / colors) — but those primitives are the floor, not the ceiling.

   **Future-extraction shape.** The CLI UX library is intended to be lifted into its own repository so it can be reused by sibling projects (`gitbetter` and others). Phase L treats `lib/ui/` as the destination shape — a subdirectory whose contents become the package boundary for the eventual extraction. New UX modules (progress, spinners, selectors) land there as siblings; the existing `lib/ui.sh` migrates into the directory at the natural point in the work (likely as `lib/ui/core.sh`). The directory move is **not** pre-emptive churn — it happens inside whichever L.b+ story first needs to add a new UX module. Callers (`lib/commands/*.sh`) then source from `lib/ui/` instead of `lib/ui.sh`. `lib/ui.sh` is **not** precious; the developer has explicitly cleared it for restructuring.

The phase is intentionally **audit-driven**: only one story (L.a) is defined upfront. L.a runs three audit tracks in parallel, producing a single findings document with three sections. Each non-trivial finding is then carved into its own implementation story (L.b, L.c, …) and appended to Phase L in `stories.md`. The phase ends when L.a's findings have all been either resolved by a Phase L story or explicitly deferred back to `## Future`.

There is no pre-committed story count.

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

- `docs/specs/phase-l-pyve-polish-audit.md` — one combined audit document with three sections (Diagnostic Surface / Project-Guide Integration / Terminal UX). Each finding records: (a) symptom, (b) root cause, (c) proposed fix size (one-liner / small / refactor / new-helper), (d) **fix locus** — pyve-side or upstream (project-guide-side); Tracks 1 and 3 are always pyve-side, Track 2 may be either, (e) suggested follow-up story title (or change-request spec title for upstream findings), (f) — for Track 1 only — whether `pyve check --fix` could automate the remediation later.
- Zero or more **project-guide change-request specs** at `docs/specs/project-guide-requests/<short-name>.md` — one file per upstream finding from Track 2. Each spec is self-contained (problem, proposed change, motivation, suggested CLI/API shape, compatibility notes) so the developer can drop it into the project-guide repo's planning workflow without further translation.
- A series of small, independently-shippable implementation stories (L.b, L.c, …) — each fixes one finding (or one tightly-related cluster), with passing tests, a version bump, and a CHANGELOG entry. Stories are added to `stories.md` Phase L after L.a is complete; the audit doc's findings are the source.
- A new `lib/ui/` directory (likely created during the first L.b+ story that needs a new UX module) that becomes the package boundary for the eventual extracted repo. The migration of `lib/ui.sh` into the directory (e.g. as `lib/ui/core.sh`) and the addition of new modules (`lib/ui/progress.sh`, `lib/ui/select.sh`, etc.) happen inside concrete implementation stories — no pre-emptive reorganization.
- Updated `features.md` / `tech-spec.md` where audit findings reveal documented-vs-actual drift.

---

## Feature Requirements

**Functional contract** is per-finding and will be specified in each L.b+ story as that story is written. The phase-level contract is shape-only:

- **Backward compatibility.** No command renames, no flag renames, no exit-code changes — except where the audit identifies behavior that is already wrong relative to documented contract.
- **Quiet by default, verbose by opt-in.** If the audit recommends a noise reduction, the loud output must remain reachable behind a flag (`--verbose`) or env var (`PYVE_VERBOSE=1`) so CI logs and debugging workflows aren't degraded.
- **Test coverage per fix.** Every fix is accompanied by a unit test that fails before and passes after, demonstrating the bug and pinning the fix. UX changes get string-match tests (e.g. "step counter `[2/5]` appears in init output") at minimum; full-screen-rendering changes may need a Tig/expect-style harness or pragmatic visual review only.
- **Documentation.** Every fix that changes user-visible output text updates `features.md` if the documented contract is affected.
- **No new top-level commands**, no new flags, no new env vars unless the audit explicitly identifies a gap that requires one — in which case it becomes a flagged scope expansion, presented to the developer for approval before implementation.

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

### L.b+ — Implementation stories (defined post-audit)

The shape of these stories cannot be pinned before the audit, but the operational pattern is:

- Each story scoped to **one** finding (or one tightly-related cluster — e.g. "all label-text typos" may be one polish story).
- Touched files vary by track:
  - Track-1 fixes typically touch `lib/commands/status.sh` and/or `lib/commands/check.sh` plus matching bats tests.
  - Track-2 pyve-side fixes typically touch the project-guide-aware files listed above plus integration tests against a synthetic project-guide-enabled project. **Track-2 upstream findings** do not produce a Phase L implementation story — they produce a change-request spec under `docs/specs/project-guide-requests/`. The pyve-side L.b+ story that *consumes* a shipped upstream change carries an explicit dependency note ("requires project-guide ≥ vX.Y.Z") and a check-or-fail guard if necessary.
  - Track-3 fixes typically add new modules under `lib/ui/` and ripple into multiple commands. The first Track-3 story to add a module also performs the `lib/ui.sh` → `lib/ui/` migration (and updates every `source` line in `pyve.sh` accordingly per the explicit-sourcing project-essential). Larger Track-3 stories (e.g. "introduce step-counter framing across all init paths") are scoped intentionally narrow at first and may grow to span 2–3 commands.
- Each story carries an explicit version bump. Most are patch (`v2.5.0` → `v2.5.1`); UX overhauls are minor (`v2.5.x` → `v2.6.0`). Audit will recommend.
- Stories are independently shippable; the phase has no "ship together" contract.

### Constraints carried forward

- **Pure Bash, no runtime dependencies** (`concept.md`). External UX libraries (`gum`, `dialog`, `whiptail`, `fzf`) are out of scope. All fancy UX must be built from `tput`, ANSI escapes, `read -sn1`, and the existing edit-distance / box / color primitives.
- **`lib/ui/` is the extractable boundary.** Modules under `lib/ui/` must not import pyve-specific identifiers (paths like `.pyve/`, command names like `pyve init`, config keys, etc.). The pure-UX primitives (colors, prompts, progress, selectors) stay generic so the eventual lift-out is a clean cut. Pyve-specific glue stays outside `lib/ui/` (in `lib/commands/*.sh` or topic-specific `lib/<topic>.sh` files).
- **macOS / Linux only**, including bash 3.2 compatibility on macOS — same constraint that pinned the `_edit_distance` 1-D array implementation in `lib/ui.sh`.

### New architectural invariants expected

Phase L is likely to introduce two new entries to `project-essentials.md`, both appended at the **end** of the phase per plan_phase Step 7 (not per-story):

1. **`lib/ui/` is the boundary of the extractable CLI UX library.** Modules under that directory stay pyve-agnostic (no pyve paths, no pyve commands, no pyve config keys) so the eventual lift-out into a standalone repo is a clean directory copy. Pyve-specific glue lives outside `lib/ui/`.
2. **"Quiet by default, verbose by opt-in"** as a UX policy — pyve commands suppress subprocess noise on the happy path; `--verbose` / `PYVE_VERBOSE=1` opts into the firehose. (Only added if Track 3 actually delivers noise reduction; if findings push verbosity work to Future, this entry is skipped.)

---

## Out of Scope

The following Future stories are deliberately **not** in Phase L. They remain in `docs/specs/stories.md` `## Future`:

- **Auto-Remediation for Diagnostics (`pyve check --fix`).** Depends on this phase's audit output as input. Premature to ship before knowing what to remediate. Will be revisited as a candidate for Phase M or later.
- **SHA256 verification of bootstrap download.** Bootstrap hardening — unrelated to the diagnostic surface or UX. Independent track.
- **Micromamba `--micromamba-version` pinning.** Bootstrap concern, not a Phase-L theme. (However: if Track-3 fixes the micromamba init noise problem, the work may **touch** the bootstrap code path; the version-pinning feature itself stays deferred.)
- **Fix pre-existing integration test failures.** Orthogonal CI hygiene — can ship in any phase.
- **Specific `pyve status` Python-pinning fix for micromamba projects.** This is the *seed finding* and L.a's Track 1 will surface it. Leaving it in `## Future` rather than pre-committing it as L.b avoids forcing the audit's hand. Promotion happens during or immediately after L.a.

Out of scope for Phase L itself (regardless of what the audit finds):

- **Implementing project-guide change requests.** Phase L produces specs under `docs/specs/project-guide-requests/` for any upstream-located findings; the actual implementation happens in the [project-guide repo](https://pointmatic.github.io/project-guide/) on its own release cycle. Phase L only ships the pyve-side consumption of those changes (and only after the corresponding project-guide release is available).
- **Major refactors** of `status.sh` or `check.sh` internals beyond what a finding directly requires. If the audit identifies a structural problem requiring a rewrite (e.g. "status output should be data-driven from a config schema"), that becomes its own phase, not an L.* story.
- **New backends** (uv, poetry support). Out-of-band concern.
- **Output format changes** beyond fixing incorrect labels/values — no JSON output, no `--format` flag, no machine-readable status. If audit findings touch output structure, they're scoped narrowly to fixing the bug, not adding modes.
- **External UX libraries** (`gum`, `dialog`, `whiptail`, `fzf`). Pure-bash invariant holds.
- **Actual extraction of `lib/ui/` to a separate repository.** Phase L *prepares* for that extraction (clean boundary, no pyve-isms inside `lib/ui/`) but does not perform it. The extraction itself is a future cross-repo operation outside this phase's scope.
- **Test infrastructure changes.** Phase L adds tests at the unit-fix level only.
- **Vite/Svelte-level polish as a contract.** Aspirational direction, not a delivery target. The audit will identify achievable subsets within the pure-bash + bash-3.2-on-macOS envelope.

---

## Stories

### L.a — Audit `pyve status`/`pyve check`, project-guide integration, and terminal UX

The single initially-defined story for Phase L. Acts as the phase's spike: produces the three-section findings document, no code changes, no version bump. Detailed task list will be written into `stories.md` when the phase is committed.

### L.b, L.c, … — TBD post-audit

Defined as audit findings are catalogued. Appended to Phase L in `stories.md` after L.a completes.

### L.zz — Phase L wrap-up (project-essentials + closure)

Detailed task list lives in [`stories.md`](stories.md). Runs last after every other Phase L obligation is discharged.

---

## Acceptance for Phase Completion

Phase L is complete when:

1. L.a's audit document exists at `docs/specs/phase-l-pyve-polish-audit.md` with all three sections populated and has been reviewed.
2. Every non-trivial finding across all three tracks has been resolved in one of:
   - Implemented as an L.b+ story marked `[Done]` (pyve-side fix), or
   - Captured as a `docs/specs/project-guide-requests/<short-name>.md` spec for the upstream repo (the implementation lands in project-guide; the pyve-side consumption may be a Phase L story or deferred to Future depending on timing), or
   - Explicitly deferred back to `## Future` with the developer's confirmation.
3. The full test suite (bats unit + pytest integration) is green on `main`.
4. Any documentation drift identified by the audit (`features.md` / `tech-spec.md` mismatch with actual behavior) has been resolved.
5. If `lib/ui/` was introduced (Track 3 implementation stories), the corresponding `project-essentials.md` entries have been appended.
6. **Story L.zz completes** — Phase L wraps with `Story L.zz: Phase L wrap-up — project-essentials and phase closure` in [`stories.md`](stories.md). That story performs the mandated `docs/specs/project-essentials.md` hygiene pass once all other Phase L work is `[Done]` or explicitly deferred:
   - **Capture invariants that emerged during L.b+** that weren't anticipated at planning time. The two anticipated entries (`lib/ui/` boundary, "quiet by default" verbosity policy) are conditional on what shipped — append them iff their preconditions held. Capture any *unanticipated* invariants surfaced by audit findings or implementation work.
   - **Prune stale items.** Walk every existing entry in `project-essentials.md` and confirm it's still accurate and still relevant. Phase L is polish + UX work that may obsolete or contradict prior invariants (e.g. UX / `lib/ui.sh` narratives that Phase L replaced). Removing or rewriting existing entries is normally `refactor_plan`'s job, but Phase L explicitly opts into a one-shot Phase-end tidy via L.zz — not wholesale file rewrites; substantive structural re-org stays `refactor_plan`.
