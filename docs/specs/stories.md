# stories.md -- pyve (python)

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see `concept.md`. For requirements and behavior (what), see `features.md`. For implementation details (how), see `tech-spec.md`. For project-specific must-know facts, see `project-essentials.md` (`plan_phase` appends new facts per phase).

---

## Phase L: Pyve Polish

Audit-driven phase. Catalogues UX/correctness rough edges across three adjacent areas — `pyve status` / `pyve check` (diagnostic-surface correctness), `pyve` ↔ `project-guide` integration touchpoints, and terminal UX (chattiness, multi-step framing, progress, selectors) — then turns each non-trivial finding into its own small implementation story (L.b, L.c, …) appended to this phase. Findings whose cleanest remedy is upstream of pyve (in [project-guide](https://pointmatic.github.io/project-guide/)) become change-request specs under `docs/specs/project-guide-requests/` rather than Phase L stories.

See [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md) for full theme, gap analysis, technical changes, and acceptance criteria. Constraints: pure-Bash, no runtime deps, macOS / Linux only including bash 3.2 on macOS. `lib/ui/` (introduced during the first Track-3 implementation story) is the boundary of the eventually-extractable CLI UX library — modules under it stay pyve-agnostic.

**Intended release version:** TBD per story. L.a is documentation-only (no version bump). Subsequent stories (L.b+) carry their own minor / patch bump as they ship — the phase is **not** a single atomic release.

**Story-spawning pattern.** L.a is the phase's spike — a three-track audit that produces a single findings document plus zero or more project-guide change-request specs. After L.a's review, every non-trivial finding is added as a new L.b+ story to this section in implementation order; trivial label/typo fixes may be batched into a single polish story. Findings the developer chooses not to address in Phase L are explicitly deferred back to `## Future`.

**Phase closure.** Run Story L.zz (`Phase L wrap-up — project-essentials and phase closure`) once every other Phase L story is `[Done]` or intentionally deferred — it performs the mandated `project-essentials.md` hygiene pass described in Story L.zz below and in [`phase-l-pyve-polish-plan.md`](phase-l-pyve-polish-plan.md) Acceptance criterion 6. This story is deliberately **not** "add new facts only" append-only housekeeping; pruning or rewriting stale entries during L.zz is an explicit Phase L carve-out (`refactor_plan` still owns large-scale reorganizations).

---

### Story L.a: Audit `pyve status` / `pyve check`, project-guide integration, and terminal UX [Planned]

**Goal.** Produce a single combined audit document with three sections (Diagnostic Surface / Project-Guide Integration / Terminal UX) that catalogues UX/correctness rough edges across pyve's read-only diagnostic surface, its project-guide integration touchpoints, and its terminal output behavior. Each non-trivial finding becomes a follow-up implementation story (L.b, L.c, …) appended to Phase L. Upstream-located Track-2 findings produce a project-guide change-request spec instead. **No code changes**, no version bump — this story is documentation only.

**Output.**

- `docs/specs/phase-l-pyve-polish-audit.md` — three-section findings document. Each finding records: (a) symptom, (b) root cause, (c) proposed fix size (one-liner / small / refactor / new-helper), (d) **fix locus** (pyve-side / upstream), (e) suggested follow-up story title (or change-request spec title), (f) — Track 1 only — whether `pyve check --fix` (deferred Auto-Remediation Future story) could automate the remediation.
- Zero or more `docs/specs/project-guide-requests/<short-name>.md` — one focused, self-contained change-request spec per upstream Track-2 finding (problem, proposed change, motivation, suggested CLI/API shape, compatibility notes).
- A final "suggested story slate" inside the audit document mapping findings → proposed L.b+ titles, ordered by suggested implementation sequence.

**Tasks — Track 1 (Diagnostic-surface correctness)**

- [ ] Walk every code path in [lib/commands/status.sh](../../lib/commands/status.sh) for both `venv` and `micromamba` backends. For each output row, confirm the label, the source of truth, and the value match documented behavior in [features.md](features.md) "Status" section; capture mismatches as findings.
- [ ] Walk every code path in [lib/commands/check.sh](../../lib/commands/check.sh) for both backends. For each diagnostic, confirm OK / warn / fail message text is precise, actionable, and not stale post-K renames; capture findings.
- [ ] Confirm the seed finding (micromamba projects falsely report `Python: not pinned`) and record root cause + proposed fix in the audit; the existing Future-section story for this fix gets either promoted to an L.b+ story or merged into a related cluster.
- [ ] Cross-check the `pyve status` Project / Environment / Integrations sections against each other for **same-fact contradictions** (e.g. Python-version disagreement). Capture each contradiction as a finding.
- [ ] For each Track-1 finding, tag whether `pyve check --fix` could automate the remediation later (input to the deferred Auto-Remediation Future story).

**Tasks — Track 2 (Project-guide integration)**

- [ ] Inventory every reference to `project-guide` under `lib/` ([lib/commands/init.sh](../../lib/commands/init.sh), [lib/commands/update.sh](../../lib/commands/update.sh), [lib/commands/status.sh](../../lib/commands/status.sh), [lib/commands/self.sh](../../lib/commands/self.sh), [lib/utils.sh](../../lib/utils.sh), [lib/completion/pyve.bash](../../lib/completion/pyve.bash), [lib/completion/_pyve](../../lib/completion/_pyve)). Re-grep at audit time in case new touchpoints have been added.
- [ ] Run pyve commands against a synthetic project-guide-enabled project: `init` (both backends) with project-guide enabled, `update`, `status`, `self install/uninstall`. Record observed friction verbatim.
- [ ] Cross-reference the [project-guide command surface](https://pointmatic.github.io/project-guide/) (commands `init`, `mode`, `override`, `update`, `status`; flags; output behavior) against pyve's invocation patterns. Identify mismatched assumptions and stale contracts.
- [ ] For each Track-2 finding, decide **fix locus** (pyve-side vs upstream). Pyve-side findings become candidate L.b+ stories; upstream findings become `docs/specs/project-guide-requests/<short-name>.md` specs.
- [ ] For any pyve-side L.b+ story that consumes a shipped upstream change, record the minimum project-guide version dependency.

**Tasks — Track 3 (Terminal UX)**

- [ ] Catalogue current capabilities of [lib/ui.sh](../../lib/ui.sh) — what's available, what's missing. Note the gitbetter-sync header constraint is being lifted in this phase per the plan doc.
- [ ] Walk every command that emits multi-step output: `init` (both backends, with the micromamba bootstrap path treated as the worst-offender), `update`, `lock`, `testenv install`, `purge --force`. Record current output behavior verbatim, including subprocess noise.
- [ ] Identify missing primitives (step counters, spinners, progress bars, multi-step framing, arrow-key single/multi-select prompts, output-quieting helpers) and propose where each lives in `lib/ui/` (e.g. `lib/ui/progress.sh`, `lib/ui/select.sh`).
- [ ] Propose the final shape of `lib/ui/` — which modules, which boundaries, where `lib/ui.sh` migrates to (likely `lib/ui/core.sh`). Actual reorganization stays in the first Track-3 implementation story; L.a only proposes the shape.
- [ ] Compare current pyve output against reference UX from `npm create vite@latest` / `npm create svelte@latest`. Identify the achievable subset within pure-bash + bash-3.2-on-macOS.
- [ ] Recommend a verbosity policy ("quiet by default, verbose by opt-in" with `--verbose` / `PYVE_VERBOSE=1`) or, if findings push verbosity work to Future, defer it explicitly with rationale.

**Tasks — synthesis**

- [ ] Write `docs/specs/phase-l-pyve-polish-audit.md` with three sections, a numbered findings table per track, per-finding short writeups, and the final "suggested story slate" in implementation order.
- [ ] For each upstream Track-2 finding, write the corresponding `docs/specs/project-guide-requests/<short-name>.md` spec (self-contained — droppable into the project-guide repo's planning workflow without further translation).
- [ ] Present the audit document and any project-guide change-request specs to the developer for review.

### Stories L.b, L.c, … — TBD post-audit

Defined as L.a's findings are catalogued. Appended here in implementation order after L.a is reviewed.

### Story L.zz: Phase L wrap-up — project-essentials and phase closure [Planned]

**When.** After L.a completes and **every non-trivial finding** has either been absorbed by an `[Done]` L.b+ story, captured as `docs/specs/project-guide-requests/<short-name>.md` for upstream, or explicitly deferred to `## Future` with confirmation — and **after** every Phase L implementation story you chose not to defer is also `[Done]`. This story is intentionally last in Phase L ordering so the `project-essentials.md` pass sees the codebase and docs **as they actually landed**.

**Purpose.** Satisfy Acceptance criterion 6 in [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md): a focused hygiene pass over `docs/specs/project-essentials.md` at phase close.

**Tasks — capture new invariants**

- [ ] Re-read Phase L artifacts (`phase-l-pyve-polish-audit.md`, CHANGELOG entries across L.b+, any new `docs/specs/project-guide-requests/*.md`).
- [ ] Append new `###` subsections for any invariant that surfaced during implementation but was **not** anticipated at planning time (normal `plan_phase` append-only semantics apply to new additions).
- [ ] If `lib/ui/` shipped, append or confirm the **`lib/ui/` extractable-boundary** invariant (`project-guide`/`go.md`-rendered essentials may already reference it via Step 7 of the plan — don't duplicate blindly).
- [ ] If Phase L landed a verbosity policy (“quiet by default, verbose by opt-in”), append that invariant iff it remained true after merge.

**Tasks — prune and correct stale essentials**

- [ ] Walk `docs/specs/project-essentials.md` entry-by-entry. For each subsection, verify it matches current code, filenames, conventions, and post–Phase-L reality.
- [ ] Rewrite or delete subsections that are **clearly superseded**, **incorrect**, or **no longer actionable** — this is Phase L–sanctioned one-shot tightening, not carte blanche to reorganize the file wholesale (large-scope restructuring stays `refactor_plan`).
- [ ] Specifically re-check entries that cite `lib/ui.sh` / UX constraints that Phase L superseded (e.g. verbatim sync with sibling projects vs. eventual `lib/ui/` extraction). Update wording to match shipped state.
- [ ] If substantive edits accumulate, note them in CHANGELOG even if there's no semver bump beyond the last Phase L ship (documentation-only housekeeping may omit a version bump if no code changed in L.zz alone — omit version number on this story if L.zz touches only markdown).

**Tasks — close out Phase L**

- [ ] Confirm [phase-l-pyve-polish-plan.md](phase-l-pyve-polish-plan.md) Acceptance criteria **1–5** are satisfied (criterion **6 is this story** — the `project-essentials.md` pass above completes it).
- [ ] Mark this story `[Done]`.

---

## Future

### Story ?.?: `pyve status` should report Python version pinning for micromamba projects [Planned]

**Motivation**: surfaced during Phase L planning. `pyve status` calls `_status_configured_python` ([lib/commands/status.sh:110-127](../../lib/commands/status.sh#L110-L127)), which checks three sources in order: `.tool-versions`, `.python-version`, then `.pyve/config`'s `python.version` key. For a `venv` project those three are the canonical pinning surfaces. For a **micromamba** project the Python version is pinned in `environment.yml` (`- python=3.12`) and resolved in `conda-lock.yml`; none of the three checked sources are populated. Result: `Python: not pinned` is printed in the `Project` section even though the version *is* pinned, and the `Environment` section's `Python: 3.12.13` line directly contradicts the `Project` section.

**Design sketch**:

- Make `_status_configured_python` backend-aware (read `backend` once at the top, dispatch). For `backend=micromamba`:
  1. Parse `environment.yml` for a `python=<spec>` (or `- python=<spec>`) dependency line. Report e.g. `3.12 (environment.yml)`.
  2. Optionally enrich with the resolved version from `conda-lock.yml` if present and fresh — though the running env's actual version is already shown in the `Environment` section, so this is decoration, not necessity.
  3. If neither file pins Python, fall through to the existing "not pinned" message.
- For `backend=venv` keep current behavior.
- Use the same backend-dispatch shape that `_status_section_environment` already uses, so the function isn't a tangle of file-existence checks.

**Tasks**:

- [ ] Refactor `_status_configured_python` to take backend as input (or read it once at the top) and dispatch by backend.
- [ ] Implement the `environment.yml` Python-pin parser (regex-grep should suffice; full YAML is overkill).
- [ ] Add a bats unit test for each branch: micromamba w/ pinned `environment.yml`, micromamba w/ unpinned `environment.yml`, micromamba w/o `environment.yml`, venv unchanged.
- [ ] Update `features.md` "Status" section if behavior changes the documented contract.

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
