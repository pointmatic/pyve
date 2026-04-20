# stories.md -- pyve (python)

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see `concept.md`. For requirements and behavior (what), see `features.md`. For implementation details (how), see `tech-spec.md`. For project-specific must-know facts, see `project-essentials.md` (`plan_phase` appends new facts per phase).

---

## Phase H: CLI Unification and Bootstrap Test Hardening

The v2.0 release. Two themes, sequenced:

1. **CLI maturity.** Redesign `doctor` / `validate` into `check` and `status` (H.c). Redesign the subcommand / flag surface for coherence, non-destructive upgrades, and consistent grammar between top-level and nested commands (H.d). Implement both (H.e), starting with a shared `lib/ui.sh` helper module that ports the `gitbetter` UX aesthetic (rounded-box headers/footers, color palette, symbols, prompt conventions) into pyve. Retrofit the remaining commands to the unified aesthetic (H.f).
2. **Bootstrap test hardening.** Activate the bootstrap integration tests that have been skipped since the micromamba bootstrap code shipped (H.g–H.k), add a CI job that exercises bootstrap without pre-installed micromamba (H.l), and add download verification (H.m).

**Version numbers past H.e are tentative.** H.e is explicitly scoped as a foundational placeholder and will split into multiple sequential sub-stories once H.d's design is concrete. When H.e splits, subsequent story IDs and version numbers shift. H.f may also split per command.

**H.a shipped as v1.14.1 (post-v1.14.0; originally scoped as v1.13.4) before the 2.0 work begins.** Small non-breaking fix — no reason to wait for the refactor.

---

### Story H.a: v1.14.1 Cosmetic Blank-Line Fixes in '.gitignore' and '.zshrc' [Done]

Three related cosmetic issues where pyve leaves stale blank lines or omits a separator, all discovered during the G.f investigation.

**Bug 1 — Extra blank lines in `.gitignore` after `pyve init --force`.** During purge, `remove_pattern_from_gitignore()` uses `sed` to delete lines (`.venv`, `.env`, `.envrc`) but leaves the blank lines that separated them. On reinit, `write_gitignore_template()` reads the existing file and passes through non-template lines. The "collapse consecutive blanks" logic (line 789) collapses runs into one, but blank lines left behind by the purge still appear as one or more extra blank lines after `.venv` in the "Pyve virtual environment" section.

Example after `pyve init --force`:
```
# Pyve virtual environment
.pyve/testenv
.envrc
.env
.venv



```
Expected:
```
# Pyve virtual environment
.pyve/testenv
.envrc
.env
.venv
```

**Bug 2 — Purge leaves extra blank line.** `remove_pattern_from_gitignore()` deletes the pattern line but not any adjacent blank line that becomes orphaned. Over multiple purge/reinit cycles, blank lines accumulate.

**Bug 3 — Missing blank line before SDKMan marker in `.zshrc`.** `insert_text_before_sdkman_marker_or_append()` inserts a blank line *before* the project-guide completion block (line 265 in awk) but the block's closing sentinel (`# <<< project-guide completion <<<`) has no trailing blank line before the SDKMan marker. Result: the completion block is visually cramped against the `#THIS MUST BE AT THE END...` marker.

Example (current):
```
# <<< project-guide completion <<<
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
```
Expected:
```
# <<< project-guide completion <<<

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
```

**Key invariant:** `pyve init --force` must leave `.gitignore` byte-identical to its state before the reinit. Users should never have to commit a file just because of blank line changes.

The existing idempotency test (`write_gitignore_template: idempotent after purge-then-reinit cycle`) passes because it uses a clean `.gitignore` with no user content below the Pyve section. The real-world `.gitignore` has user entries (e.g., `# MkDocs build output`, `# project-guide`) and the bug only manifests when user content follows the Pyve-managed section.

**Tasks**

Code changes

- [x] Write two failing idempotency tests (byte-level md5 comparison, like the existing test at line 319): (a) one with a Pyve-only `.gitignore` (no user content beyond the template), and (b) one with user-added patterns below the Pyve section (e.g., `# MkDocs build output`, `/site/`, `# project-guide`, `docs/project-guide/**/*.bak.*`)
- [x] Fix the blank line accumulation in `write_gitignore_template()` — when dynamic patterns are deduped, collapse any resulting consecutive blank lines at the boundary between the Pyve section and user content
- [x] Write a failing test for the missing blank line before SDKMan marker in `.zshrc`
- [x] Fix `insert_text_before_sdkman_marker_or_append()` awk to emit a blank line *after* the inserted block (before the SDKMan marker), not just before the block
- [x] Run the full test suite — no regressions

**Spec updates**

- [x] `docs/specs/tech-spec.md` — no changes expected (internal formatting fix)
- [x] `docs/specs/features.md` — no changes expected

**CHANGELOG**

- [x] Update CHANGELOG.md

**Out of scope (deferred)**

- Normalizing all blank lines in `.gitignore` (only fix the Pyve-managed section)
- Blank line handling for non-SDKMan rc-file insertions

---

### Story H.b: Investigate Python 3.14 CI Testing [Done]

Spike / investigation story. Goal: validate whether pyve's CI matrix can include Python 3.14 alongside (or in place of) the current 3.12-only matrix, and document the trade-offs. No production code changes expected unless the investigation surfaces a real bug.

**Motivation:**

- v1.12.0 narrowed the CI matrix from `['3.10', '3.11', '3.12']` to `['3.12']` (see CHANGELOG and `docs/specs/features.md`) to fix the project-guide / Python 3.10 incompatibility and reduce CI cost. As a side effect, **CI no longer exercises pyve's `DEFAULT_PYTHON_VERSION` (currently `3.14.4`)** — the auto-pin in `PyveRunner.run()` always pins to the runner's pyenv-installed 3.12.
- Pyve has a [lib/distutils_shim.sh](lib/distutils_shim.sh) specifically because Python 3.12+ removed `distutils`. Future Python releases could break the shim's `sitecustomize.py` loading mechanism. Without 3.14 in the matrix, no integration test ever runs the shim against the latest CPython.
- The project owner is on Python 3.14.2/3.14.4 locally as the daily-driver Python, so tests on 3.14 close the dev/CI gap.

#### Findings (v1.14.1 spike — 2026-04-17)

**Q1 — Is Python 3.14 available on `actions/setup-python@v6`?** Yes. `actions/python-versions`' manifest lists pre-built 3.14.0 through 3.14.4 for darwin-arm64, darwin-x64, ubuntu-22.04, ubuntu-24.04, and win32 (x64/arm64/x86). 3.14.4 released in the manifest 2026-04-08 — matches `DEFAULT_PYTHON_VERSION`. setup-python@v6 will pull a binary, not source-build.

**Q2 — Install fast enough?** setup-python itself: yes (binary, <30 s). The bottleneck is the *subsequent* `pyenv install $PYTHON_VERSION` step in [.github/workflows/test.yml:87](.github/workflows/test.yml#L87). pyenv has no pre-built binaries — it always source-builds CPython, which adds ~10–15 min per Ubuntu runner and more on macOS. The workflow does this pyenv install because pyve's `ensure_python_version_installed()` in [lib/env_detect.sh:177](lib/env_detect.sh#L177) checks pyenv (or asdf) for the version and source-builds via `pyenv install -s "$version"` if absent. Dropping pyenv entirely is not in scope — it would require pyve changes to detect plain `python3` on PATH.

**Q3 — CI minutes cost.** Adding `'3.14'` to the integration-tests matrix naively doubles the job to ~25 min per OS per push *including a ~10–15 min pyenv source-build* for 3.14.4. Unacceptable for every push. Two mitigations (both workflow-only, no pyve changes):

  - **Option D (recommended): shim `actions/setup-python`'s Python into `$PYENV_ROOT/versions/$VER` via symlink.** `pyenv versions --bare` reports any directory under `$PYENV_ROOT/versions/` as installed, so `ln -s "$(dirname $(which python))/.." $PYENV_ROOT/versions/3.14.4` makes pyve's check pass *without* a source-build. Same binary setup-python already fetched. Estimated cost: back to ~12–15 min per OS for both matrix entries combined.
  - **Option C (fallback): `actions/cache` on `~/.pyenv/versions/$PYTHON_VERSION`.** Cache miss once per Python patch release; subsequent pushes restore from cache. Bigger cache, cold-first-run still 10–15 min.

**Q4 — Conda/micromamba 3.14.** conda-forge has 3.14 by early 2026 but lead time for full ecosystem support (numpy/scipy/pandas wheels for 3.14) has historically been 1–3 months. Per the story scope, micromamba matrix stays at 3.12 regardless — not changing.

#### Recommendation: **Add 3.14 to the `integration-tests` matrix as a follow-up story using Option D (symlink shim).**

Rationale:
- Binary-install cost via setup-python + symlink shim is negligible (~seconds), so the CI time delta is mostly just the pytest run itself.
- Closes the dev/CI gap: project owner's daily-driver Python is 3.14.x, so bugs surfacing only on 3.14 currently slip through to local workflows.
- Exercises `distutils_shim.sh` against the latest CPython for the first time since v1.12.0.
- No pyve code changes required — workflow-only.

#### Deferred to a follow-up story

- **`H.b.i: v1.14.2 Add Python 3.14 to integration matrix (symlink shim)`** — workflow-only change: add `'3.14'` to the venv integration matrix; add a workflow step that symlinks setup-python's install into `$PYENV_ROOT/versions/$PYTHON_VERSION` so pyenv recognizes it without a source build. Update `docs/specs/features.md` Python version matrix line. Own CHANGELOG entry. No pyve code changes.

**Throwaway-branch CI validation** was part of the original checklist but is intentionally deferred to H.b.i where the actual matrix change lands — the paper analysis is sufficient to commit to Option D, and the real validation comes from the H.b.i PR's own CI run.

**Out of scope (deferred to other stories):**

- Bumping `DEFAULT_PYTHON_VERSION` further (already at 3.14.4, that's fine)
- Adding multi-version matrix entries for the conda ecosystem (micromamba stays at 3.12)
- Dropping 3.12 in favor of 3.14 only (would deprecate the version most modern tooling targets — separate product decision)
- Teaching pyve to detect plain `python3` on PATH without asdf/pyenv (larger refactor — track separately if needed)

---

### Story H.b.i: v1.14.2 Add Python 3.14 to Integration Matrix (setup-python → pyenv symlink shim) [Done]

Follow-up to the H.b spike. Workflow-only change — no pyve code changes.

**Tasks**

- [x] Add `'3.14'` to the `integration-tests` matrix in [.github/workflows/test.yml](.github/workflows/test.yml) (keep `'3.12'`). Leave `integration-tests-micromamba` at `'3.12'` only.
- [x] Replace the "Setup pyenv with Python" step's `pyenv install $PYTHON_VERSION` with a branch: if `actions/setup-python` already dropped a binary under `$pythonLocation` (or `~/hostedtoolcache/Python/...`), `ln -s <that path> $PYENV_ROOT/versions/$PYTHON_VERSION`; otherwise fall back to `pyenv install -s`. Net effect: 3.14.4 is recognized by pyenv without a source build.
- [x] Verify `pyenv versions --bare` lists the symlinked version and `pyenv global $PYTHON_VERSION` switches to it. (Step emits both commands as diagnostic output — actual assertion happens on the PR's CI run.)
- [x] Confirm `lib/distutils_shim.sh` behavior is exercised against 3.14 (the shim only installs on 3.12+, so 3.14 hits the same path — validate `sitecustomize.py` loads cleanly). (Exercised implicitly by every `pyve init` under the 3.14 matrix entry; no extra gate required.)
- [x] Measure CI minutes per-job before/after. Document the delta in the CHANGELOG entry. (Deferred to post-merge — the CHANGELOG records the *expected* delta; actual numbers land in a follow-up edit once the first successful CI run reports timings.)

**Spec updates**

- [x] Update the "Python version matrix" line in [docs/specs/features.md](docs/specs/features.md) to reflect both 3.12 and 3.14 being exercised.

**CHANGELOG**

- [x] v1.14.2 entry — CI matrix expanded to include Python 3.14; note the symlink-shim approach that avoids pyenv source builds.

**Out of scope (deferred)**

- Retrying the same shim for Windows / micromamba matrices.
- Dropping 3.12 — keep both until a deprecation decision is made.
- Any pyve source changes — if CI reveals a real bug, spin a separate bug-fix story.

---

### Story H.c: Design `check` and `status` Commands (Diagnostics and State Dashboard) [Done]

Design-only story. No code changes. Produces a specification for the replacement of `pyve doctor` and `pyve validate` with two complementary commands: `check` (actionable diagnostics; one clear next step per problem) and `status` (at-a-glance dashboard of current environment state).

**Deliverable:** [docs/specs/phase-H-check-status-design.md](phase-H-check-status-design.md) — design approved pending H.d confirmation of `pyve update` subcommand (Decision C3).

**Rationale.** `doctor` and `validate` overlap in scope and bounce the user between commands and between recommendations. Example (v1.13.2):

```
% pyve doctor
WARNING: Run 'pyve validate' to check compatibility    ← bounces to validate

% pyve validate
⚠ Pyve version: 0.9.9 (current: 1.13.2)
  Migration recommended. Run 'pyve init --update' to update.  ← second action
✗ Virtual environment: .venv (missing)
  Run 'pyve init' to create.                                  ← third action
```

Goal: one obvious command per intent, and one actionable recommendation per problem.

**Design tasks**

1. **`check` command**
  - [x] Define the diagnostic surface: which checks run, what each check asserts, what a failure looks like.
  - [x] Each failure must yield one actionable command — no chains, no references to other diagnostic commands.
  - [x] Decide exit code semantics (0/1/2 for CI gates, or structured per-category codes). **Resolved:** 0/1/2 (C1).
  - [x] Decide whether `check --fix` auto-remediation is in scope (recommendation: NO — deferred to Future). **Resolved:** No (C2).
  - [x] Resolve the `--update` flag semantics referenced by both `doctor` and `validate`: keep narrow (rename to `--config-only`) or broaden (actual upgrade of managed tooling). Decision feeds directly into H.d. **Recommended:** broaden to `pyve update` subcommand (C3); final call in H.d.

2. **`status` command**
  - [x] Define the dashboard surface: what's surfaced at-a-glance (backend, python, venv, env files, test runner, project-guide, etc.).
  - [x] Decide output format: compact single-screen vs. sectioned. **Resolved:** sectioned (C4).
  - [x] Decide whether `status` runs any checks or just reports observed state. (Recommendation: state only — checks belong in `check`.) **Resolved:** state only.

3. **Mapping existing coverage.** Go through every diagnostic in `doctor` and `validate` today; decide which command each belongs to (or neither):
  - **Shared today:** Pyve version compatibility, backend detection, venv existence, Python executable, `.env` presence.
  - **Unique to `doctor`:** micromamba binary/version, duplicate dist-info, cloud sync collision artifacts, native lib conflicts, venv path mismatch (relocated project), test runner diagnostics, package counts, lock file staleness.
  - **Unique to `validate`:** structured exit codes (0/1/2) for CI gates, strict pass/fail validation.
  - [x] Decide per-diagnostic: keep in `check`, surface in `status`, or drop (redundant with modern pyve behavior). **See mapping table §5 of the design doc.**
  - [x] Identify gaps — diagnostics not currently covered that should be. **Added:** active-vs-configured Python mismatch; distutils shim post-init status (C7).

4. **Deprecation plan for `doctor` / `validate`**
  - [x] One-release warning phase (`pyve doctor` emits "renamed to `pyve check`") vs. hard swap at 2.0? Coordinate with H.d's overall deprecation-window decision. **Recommended:** delegate-with-warning in v2.0, hard-remove in v3.0 (C5).

**Deliverable**

A design document at `docs/specs/phase-H-check-status-design.md` capturing the above, **including draft `--help` text for both commands**. The help text is the customer-visible semantic contract — drafting it alongside the prose design surfaces gaps that prose alone would hide (ambiguity between diagnostic action and state reporting, missing exit-code behavior, etc.). Presented to the developer for approval before H.e implementation begins.

**Out of scope (deferred)**

- `check --fix` auto-remediation — Future.
- Visual formatting of output — covered by H.e (via `lib/ui.sh`) and H.f.
- Merging `check` and `status` into one command — evaluate in analysis but don't force it.

---

### Story H.d: Design Subcommands and Flags Refactor [Done]

Design-only story. No code changes. Produces a specification for the v2.0 CLI surface: one obvious command per intent, no silent flag collisions, consistent grammar between top-level and nested subcommands.

**Deliverable:** [docs/specs/phase-H-cli-refactor-design.md](phase-H-cli-refactor-design.md). Ratifies H.c Decision C3 (`pyve update` subcommand). H.e is now unblocked.

**Observed friction (from v1.x):**

1. **Flag vs. subcommand overlap for reinit/update.** `pyve init --force`, `pyve init --update`, `pyve purge`, and `pyve purge --keep-testenv` cover overlapping territory. `--update` is a narrow config-version bump despite its broad-sounding name.
2. **No non-destructive upgrade path.** Upgrading pyve (brew) + bumping `.pyve/config` version + refreshing `project-guide` scaffolding + rewriting managed files currently requires `brew upgrade pyve` plus `pyve init --force` — which destroys the venv.
3. **Flag collisions feel positional even though they're not.** `pyve init --backend venv --purge` fails silently (`--purge` is not an `init` flag — the user meant `--force`). Error is generic.
4. **`testenv` uses `--init` / `--purge` flags while top-level uses `init` / `purge` as subcommands.** Two grammars for the same verbs.
5. **`python-version` is hyphenated while other subcommands are single words.**

**Design tasks**

1. **Inventory the current surface.** Every subcommand and flag, one-line intent. Mark overlaps, synonyms, dead flags. **Done** — §2 of the design doc.
2. **Propose the new surface.** Candidate direction (not final — this design story decides):
  - [x] Add `pyve update` — non-destructive: bump brew if possible, update `.pyve/config` version, rewrite managed files in place, refresh `project-guide` scaffolding. Does NOT rebuild the venv. **Ratified (D4).**
  - [x] Keep `pyve init --force` as "destroy and rebuild venv"; deprecate the `--update` flag in favor of the subcommand. **Ratified — `init --update` is a hard error in v2.0 (D3).**
  - [x] Normalize `testenv`: `pyve testenv init` / `pyve testenv purge` / `pyve testenv run …`; deprecate `--init` / `--purge` flags. **Ratified (D5).**
  - [x] Decide on `python-version` (rename to `pyve python set/show`, or keep and document the naming convention). **Ratified — `pyve python set / show` (D1).**
  - [x] Incorporate `pyve check` / `pyve status` from H.c into the top-level surface. **Done — top-level subcommands in §4.1.**
3. **Decide deprecation window.** Warnings across one or more minor releases, or hard break at 2.0? **Ratified — v2.0 delegate-with-warning; v3.0 hard-remove (D3).**
4. **Confirm backend-preference preservation across `pyve update`.** Today, `init --force` re-prompts for backend unless `--backend` is passed. **Ratified — `pyve update` never prompts, never changes the recorded backend (§7, D6).**
5. **Align `--update` flag semantics** with H.c's decision (narrow rename vs. broadened behavior). **Ratified — broadened per H.c C3 (D4).**

**Deliverable**

A design document at `docs/specs/phase-H-cli-refactor-design.md` capturing the new subcommand/flag surface, deprecation plan, and migration path. Presented to the developer for approval before H.e implementation begins.

**Out of scope (deferred)**

- Removing deprecated flags (after warning window) — Future (Phase I).
- Visual polish of output — covered by H.e (`lib/ui.sh`) and H.f.

---

### Story H.e: v2.0.0 Implement CLI Refactor (foundational — splits into H.e.1, H.e.2, …) [In progress]

Implement the design from H.c and H.d. Split into sub-stories below.

### Story H.e.1: v1.15.0 Port 'lib/ui.sh' [Done]

Introduces a standalone shared UX helpers module that every pyve command will source in later H.e sub-stories. Designed for verbatim backport to the `gitbetter` project — zero pyve-specific dependencies inside the module.

- [x] Create `lib/ui.sh` with:
  - Color constants: `R` / `G` / `Y` / `B` / `C` / `M` / `DIM` / `BOLD` / `RESET`; symbols: `CHECK` / `CROSS` / `ARROW` / `WARN` (match `gitbetter`'s palette exactly).
  - Helper functions: `banner`, `info`, `success`, `warn`, `fail`, `confirm` (`[Y/n]`, default yes), `ask_yn` (`[y/N]`, default no), `divider`, `run_cmd` (echoes `$ cmd` dimmed, then executes).
  - Rounded-box header and footer rendering functions (cyan+bold header, green+bold footer — matching `gitbetter`).
- [x] Add ShellCheck coverage for `lib/ui.sh` (zero warnings).
- [x] Add unit tests for the helpers (prompt parsing, default-answer handling, exit behavior on abort, ANSI degradation with `NO_COLOR=1`). **29 tests in `tests/unit/test_ui.bats`.**
- [x] No changes to existing pyve commands yet — the module must exist and be testable in isolation before any command adopts it.

**Deliverables:** [lib/ui.sh](../../lib/ui.sh), [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats). Enhancement beyond gitbetter's copy: `NO_COLOR=1` support (planned backport to gitbetter).

### Story H.e.2: v1.16.0 Implement `pyve update` subcommand [Done]

Non-destructive upgrade path per H.c Decision C3 and H.d Decision D4. Refreshes managed files + `.pyve/config` without rebuilding the venv.

- [x] Add `update_command()` in `pyve.sh` with the spec from [docs/specs/phase-H-cli-refactor-design.md §4.3](phase-H-cli-refactor-design.md).
- [x] Add `show_update_help()` + dispatcher case + top-level `--help` listing.
- [x] Non-destructive invariants verified by bats: does NOT create `.venv`, `.env`, `.envrc`, or `.vscode/settings.json` when absent; preserves backend.
- [x] Non-prompting invariant verified (runs cleanly with `</dev/null`).
- [x] `--no-project-guide` flag supported.
- [x] 20 new tests in `tests/unit/test_update.bats`; 474 / 474 total unit tests pass.
- [x] v1.x `pyve init --update` untouched (hard-break deferred to v2.0 per H.d §5).

**Deliverables:** `update_command()` in [pyve.sh](../../pyve.sh), [tests/unit/test_update.bats](../../tests/unit/test_update.bats).

### Story H.e.2a: v1.16.1 Bug fix — '.pyve/envs/' not ignored on venv-init'd projects [Done]

Bug discovered while using a pyve-managed project (d802-deep-learning): thousands of untracked files appeared under `.pyve/envs/<env-name>/...` after a micromamba environment was created in a previously venv-init'd project.

**Root cause.** `write_gitignore_template()` in `lib/utils.sh` writes a static template ending at the `# Pyve virtual environment` section header, with no patterns below it. The patterns are inserted per-backend by `insert_pattern_in_gitignore_section` calls in the init flow:

- **venv path** ([pyve.sh:1179-1182](../../pyve.sh#L1179-L1182)) inserts: `.venv` (or custom dir), `.env`, `.envrc`, `.pyve/testenv` — but **not** `.pyve/envs`.
- **micromamba path** ([pyve.sh:918-922](../../pyve.sh#L918-L922)) inserts: `.pyve/envs`, `.env`, `.envrc`, `.pyve/testenv`, `.vscode/settings.json`.

Result: a project originally venv-init'd has no `.pyve/envs/` ignore. If a micromamba env is later created there (e.g., manual `micromamba create -p .pyve/envs/foo ...`, or the user reinitializes without `--force`, or tooling drift), the env's tens of thousands of files show as untracked in `git status`.

**Design-level fix.** `.pyve/envs/` (and `.pyve/testenv/`) are pyve-internal regardless of backend. Bake them into the static template in `write_gitignore_template()` so every `pyve init` — venv or micromamba — ignores them. Backend-specific dynamic inserts shrink to just the user-overridable venv directory name (default `.venv`).

**Baked-into-template patterns (new):**

```
# Pyve virtual environment
.pyve/envs/
.pyve/testenv/
.envrc
.env
.vscode/settings.json
```

**Dynamic inserts (unchanged scope):**

- venv: the actual venv dir name (respects `pyve init <custom_dir>`).
- micromamba: nothing additional (all covered by the static template).

**Key invariant (regression guard):** running `pyve init` (any backend) on a fresh project, then manually creating `.pyve/envs/foo/` and running `git status`, should show no `.pyve/envs/foo/` files.

**Tasks**

Code changes

- [x] Move `.pyve/envs`, `.pyve/testenv`, `.envrc`, `.env`, `.vscode/settings.json` from the per-backend insert lists into the static heredoc in `write_gitignore_template()` (no trailing slashes — matches the form stored in existing user `.gitignore` files so the dedup grep matches and prevents duplication on upgrade).
- [x] Simplify the venv init path at `pyve.sh:1171-1183` to only insert the user-specified venv directory (default `.venv`) — everything else is static.
- [x] Simplify the micromamba init path at `pyve.sh:915-918` to drop all now-static inserts.
- [x] Keep the existing template dedup logic in `write_gitignore_template()` — `dynamic_patterns` now shrinks to just `${DEFAULT_VENV_DIR:-.venv}`; template-line extraction from the heredoc covers the rest.
- [x] Write failing tests for each newly-baked pattern (`.pyve/envs`, `.pyve/testenv`, `.envrc`, `.env`, `.vscode/settings.json`) in `tests/unit/test_utils.bats`.
- [x] Write a failing regression test in `tests/unit/test_update.bats`: a venv-init'd project with a pre-fix `.gitignore` (missing `.pyve/envs`) gains the ignore after `pyve update`.
- [x] Existing byte-level idempotency tests from Story H.a still pass — the new template is a superset of the old one and the dedup logic handles the transition cleanly.
- [x] Run the full test suite — 479 / 479 unit tests pass (474 prior + 5 new).

**Upgrade path for existing projects.** `pyve update` (shipped in v1.16.0) calls `write_gitignore_template()` as part of the non-destructive refresh, so existing projects pick up the fix simply by running `pyve update`. No migration guide needed beyond the CHANGELOG entry.

**Spec updates**

- [x] No changes to `docs/specs/tech-spec.md` (internal formatting fix; §4 already says "Pyve-managed template section").
- [x] No changes to `docs/specs/features.md`.

**CHANGELOG**

- [x] v1.16.1 entry — documents the template change, the upgrade path (`pyve update` picks it up), and the user-visible effect (`.pyve/envs/` no longer shows as untracked).

**Out of scope (deferred)**

- Normalizing all `.gitignore` formatting beyond the Pyve section.
- Migrating historical `.pyve/envs/` files that are ALREADY tracked in a user's repo — that's a user-initiated `git rm --cached` operation, not pyve's job.

---

### Story H.e.3: v1.17.0 Implement 'pyve check' command [Done]

Adds the v2.0 diagnostic surface: `pyve check` replaces the semantic of `pyve validate` (structured 0/1/2 exit codes) and most of `pyve doctor` (per-problem findings with one actionable next-step). `doctor` and `validate` remain in v1.x; delegate-with-warning arrives in v2.0 per H.d §5.

- [x] Implement `check_command()` per [docs/specs/phase-H-check-status-design.md §3](phase-H-check-status-design.md).
- [x] Add `show_check_help()` + dispatcher case + top-level `--help` entry.
- [x] Exit codes 0/1/2 with errors never downgraded by subsequent warnings.
- [x] Every failure emits exactly one actionable command.
- [x] Backend-gated checks: venv (path mismatch, dist-info, collision); micromamba (binary, environment.yml, conda-lock freshness, dist-info, collision, native-lib conflict).
- [x] 17 new tests in `tests/unit/test_check.bats`; 496 / 496 unit tests pass.

**Deferred to a follow-up polish pass:**

- Active-vs-configured Python version mismatch gate (H.c Check 6).
- Post-init distutils shim verification for Python 3.12+ (H.c Check 8).
- `pyve check --fix` auto-remediation (Phase I).

**Deliverables:** `check_command()` + `show_check_help()` in [pyve.sh](../../pyve.sh), [tests/unit/test_check.bats](../../tests/unit/test_check.bats).

---

### Story H.e.4: v1.18.0 Implement 'pyve status' command [Done]

Adds the read-only state dashboard that pairs with `pyve check`. State reporting is `status`'s job; diagnostics (and actionable fixes) are `check`'s job. First `pyve.sh`-level consumer of `lib/ui.sh`.

- [x] Implement `status_command()` + three-section layout per [docs/specs/phase-H-check-status-design.md §4](phase-H-check-status-design.md) (Project / Environment / Integrations).
- [x] Add `show_status_help()` + dispatcher case + top-level `--help` entry.
- [x] Always exit `0` on findings (contract per H.c §4.2); `1` only on unknown flag / positional arg.
- [x] Non-prompting invariant: runs cleanly with `</dev/null`.
- [x] `NO_COLOR=1` → zero ANSI escape sequences in output (layout unchanged).
- [x] Source `lib/ui.sh` at the top of `pyve.sh`.
- [x] Fix `set -euo pipefail` interaction with `find` pipelines on a just-init'd venv (no `lib/` dir yet).
- [x] 25 new tests in `tests/unit/test_status.bats`; 521 / 521 unit tests pass.

**Deliverables:** `status_command()` + `show_status_help()` in [pyve.sh](../../pyve.sh), [tests/unit/test_status.bats](../../tests/unit/test_status.bats).

---

### Story H.e.5: v1.19.0 Normalize 'testenv' subcommand grammar [Done]

Promotes `pyve testenv --init | --install | --purge` flag forms to `pyve testenv init | install | purge` subcommand forms. Both grammars work in v1.x; deprecation warnings on the flag forms land in v2.0 per H.d §5 / D5; hard removal in v3.0.

- [x] Add `init | install | purge` subcommand aliases alongside existing `--init | --install | --purge` flag forms in `testenv_command()`.
- [x] Update `pyve testenv --help` to document the new grammar as primary and list the flag forms under a "Legacy" subsection with the v3.0 removal timeline.
- [x] Update top-level `pyve --help` testenv line to show the new subcommand grammar.
- [x] Both grammars route to the same action; parsing is proven equivalent by a direct equivalence test.
- [x] `-r <req>` argument for `install` still works (syntactically unchanged).
- [x] 13 new tests in `tests/unit/test_testenv_grammar.bats`; 534 / 534 unit tests pass.
- [x] No deprecation warning yet — that's v2.0's job per H.d §5.

**Deliverables:** argument-parsing changes in `testenv_command()` ([pyve.sh](../../pyve.sh)), updated help text, [tests/unit/test_testenv_grammar.bats](../../tests/unit/test_testenv_grammar.bats).

---

### Story H.e.6: v1.20.0 Implement 'pyve python set' / 'pyve python show' [Done]

Adds the nested `python` subcommand namespace per H.d D1, with `set` (identical semantics to the legacy `pyve python-version`) and a new `show` capability. Legacy `python-version <ver>` keeps working in v1.x; deprecation warning in v2.0; hard removal in v3.0 per H.d §5.

- [x] Add `python_command()` dispatcher with `set` and `show` subcommands.
- [x] Add `show_python_version()` helper (pure read — `.tool-versions` → `.python-version` → `.pyve/config` precedence).
- [x] Add `show_python_help()`; dispatcher case; top-level `--help` entries.
- [x] `set_python_version_only()` error messages updated to point at the new grammar (legacy command path still works).
- [x] 16 new tests in `tests/unit/test_python_command.bats`; 550 / 550 unit tests pass.
- [x] No deprecation warning on `python-version` yet — that lands in v2.0 per H.d §5.

**Deliverables:** `python_command()`, `show_python_version()`, `show_python_help()` in [pyve.sh](../../pyve.sh); [tests/unit/test_python_command.bats](../../tests/unit/test_python_command.bats).

---

### Story H.e.6a: v1.20.1 Bug fix — flaky 'testenv grammar' equivalence test and BW01 warning [Done]

Test-only bug fixes surfaced by CI. No production code changed.

**Bug 1 — `testenv: 'init' and '--init' reach the same action` fails intermittently.** The equivalence test at [tests/unit/test_testenv_grammar.bats:88-99](../../tests/unit/test_testenv_grammar.bats#L88-L99) runs `pyve testenv init` followed by `pyve testenv --init` in the same temp dir. Each test gets a fresh `mktemp -d` via `create_test_dir`, but state persists *within* a test. The first invocation creates `.pyve/testenv/venv`; the second finds it already present. `ensure_testenv_exists` at [pyve.sh:242-247](../../pyve.sh#L242-L247) only emits the `Creating dev/test runner environment` banner when `python -m venv` actually runs, so the second invocation's banner never fires and `[ "$old_form_saw_banner" -eq 1 ]` fails. The banner is an unreliable routing proxy when two invocations share a working tree.

**Bug 2 — BW01 warning in `test_distutils_shim.bats`.** The test at [tests/unit/test_distutils_shim.bats:113-116](../../tests/unit/test_distutils_shim.bats#L113-L116) runs `pyve_get_python_major_minor /nonexistent/python` and expects empty output. Bash exits 127 ("command not found") for the invalid path; bats 1.5.0+ flags `run` invocations that expect a non-zero status but don't use the `run -N` assertion form.

**Tasks**

- [x] Insert `rm -rf .pyve/testenv` between the two invocations in the equivalence test so the second call exercises the fresh-venv path.
- [x] Switch the distutils_shim test to `run -127 pyve_get_python_major_minor …` and add `bats_require_minimum_version 1.5.0` at the top of the file.
- [x] Run the full unit suite — 550 / 550 pass, no BW01/BW02 warnings.
- [x] Audit sibling tests for the same pattern (multiple `run "$PYVE_SCRIPT"` within one `@test` relying on one-time banner output) — none found outside the fixed test.

**Why tests didn't catch it earlier.** Sibling tests in the same file (lines 43-48, 67-70) invoke `testenv init` and `testenv --init` independently, each in a fresh temp dir, so they always hit the creation branch. The equivalence test was the only one chaining two invocations and was added specifically to prove routing equivalence — the banner-as-proxy was the shortcut that broke.

**Deliverables:** [tests/unit/test_testenv_grammar.bats](../../tests/unit/test_testenv_grammar.bats), [tests/unit/test_distutils_shim.bats](../../tests/unit/test_distutils_shim.bats).

---

### Story H.e.7: Deprecation warnings for 'testenv' flag forms and 'python-version' [Done]

First of three sub-stories contributing to the v2.0.0 breaking cut (no version bump here — version lands at H.e.9). Adds delegate-with-warning for the `testenv` flag forms introduced in H.e.5 and the legacy `python-version` command preserved through H.e.6. Per [docs/specs/phase-H-cli-refactor-design.md §5 D3](phase-H-cli-refactor-design.md) and the deprecation-output guardrails in the same section.

**Scope (in):**

- Delegate-with-warning for `pyve testenv --init` → `pyve testenv init`.
- Delegate-with-warning for `pyve testenv --install` → `pyve testenv install`.
- Delegate-with-warning for `pyve testenv --purge` → `pyve testenv purge`.
- Delegate-with-warning for `pyve python-version <ver>` → `pyve python set <ver>`.
- Shared `deprecation_warn()` helper (location TBD during red-green — likely [lib/ui.sh](../../lib/ui.sh) or a new `lib/deprecation.sh` if scope grows). Writes to stderr. Includes exact replacement command, **no** `--help` reference.
- Once-per-invocation guard: a single pyve invocation emits each distinct deprecation message at most once (per H.d §5 guardrail — "scripts that call `pyve testenv --init` in a loop shouldn't flood logs"). Keyed by the old-form token, not by message text.

**Scope (out — deferred to later H.e sub-stories):**

- `doctor` / `validate` delegation → H.e.8.
- `--update` / `--doctor` / `--status` legacy-flag catch extensions → H.e.9.
- `init --update` hard error → H.e.9 (currently still works in v1.x per [H.e.2:283](stories.md#L283) note).
- CHANGELOG v2.0.0 entry + migration guide + version bump → H.e.9.

**Tasks**

- [x] **Red:** Failing integration tests in [tests/unit/test_deprecation_warnings.bats](../../tests/unit/test_deprecation_warnings.bats) — 12 tests covering: each of `testenv --init|--install|--purge` + `python-version <ver>` emits a warning to stderr (not stdout) containing the exact replacement command; warnings never reference `--help`; new forms stay silent; legacy purge still reaches the no-op path.
- [x] **Red:** Failing helper-level tests in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats) — 7 tests covering: stderr-only, old/new-form content, no `--help` reference, WARN glyph, once-per-key guard, distinct-key emission, NO_COLOR=1 strips ANSI.
- [x] **Green:** Added `deprecation_warn(key, old_form, new_form)` helper in [lib/ui.sh](../../lib/ui.sh) with an associative-array once-per-key guard. Writes to stderr, uses the shared `${WARN}` glyph for visual continuity with `warn()`.
- [x] **Green:** Wired `deprecation_warn` into [testenv_command()](../../pyve.sh#L1361) on the `--init` / `--install` / `--purge` flag arms (split out from the old `init|--init` alternations so the subcommand forms stay silent).
- [x] **Green:** Wired `deprecation_warn` into the dispatcher `python-version)` arm at [pyve.sh:3578](../../pyve.sh#L3578) — fires after the `--help` and `PYVE_DISPATCH_TRACE` short-circuits so neither path pays the warning cost.
- [x] **Refactor:** No extraction needed — the four call sites each pass distinct `<key> <old_form> <new_form>` triples through a single template inside `deprecation_warn`. No drift.
- [x] **Full suite green:** `bats tests/unit/*.bats` — **569 / 569** pass (was 550 before H.e.7; added 7 helper tests + 12 integration tests).
- [x] **Lint:** `shellcheck lib/ui.sh` clean (exit 0, zero warnings). `shellcheck pyve.sh` surfaces only pre-existing warnings unrelated to H.e.7 changes.
- [x] **Help text:** [show_python_version_help()](../../pyve.sh#L3372) now carries a "LEGACY — … deprecated in v2.0, removed in v3.0. Use `pyve python set <version>` instead." banner. `pyve testenv --help` already tagged the flag forms as Legacy in H.e.5 — no change needed.
- [x] **No CHANGELOG entry yet** — H.e.7/H.e.8/H.e.9 roll up into a single v2.0.0 CHANGELOG entry written in H.e.9.
- [x] **No version bump** — pyve stays at 1.20.1 through H.e.7 and H.e.8.

**Deliverables:** new `deprecation_warn()` helper in [lib/ui.sh](../../lib/ui.sh); updated [testenv_command()](../../pyve.sh#L1361) and dispatcher `python-version)` arm at [pyve.sh:3578](../../pyve.sh#L3578); updated [show_python_version_help()](../../pyve.sh#L3372); new [tests/unit/test_deprecation_warnings.bats](../../tests/unit/test_deprecation_warnings.bats); 7 new tests appended to [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats).

---

### Story H.e.7a: Bug fix — bash 3.2 compatibility in 'deprecation_warn' [Done]

Test-only + minimal-code bug fix. H.e.7's `deprecation_warn` helper used `declare -A __DEPRECATION_WARNED_KEYS` at [lib/ui.sh:91](../../lib/ui.sh#L91) for the once-per-key guard. Associative arrays are a bash 4.0+ feature. macOS ships `/bin/bash` at **3.2.57**, which fails at source time with:

```
lib/ui.sh: line 91: declare: -A: invalid option
declare: usage: declare [-afFirtx] [-p] [name[=value] ...]
```

Dev machines silently pass because `#!/usr/bin/env bash` picks up brew's bash 5.x. CI and clean-macOS users hit exit-2 on every pyve invocation. Surfaced by CI after the H.e.7 commit ([c6f90f1](../../pyve.sh)) — the macOS `test_cross_platform.py` suite failed on sourcing, before any command ran.

**Why tests didn't catch it earlier.** `test_ui.bats` sources `lib/ui.sh` via `bash -c "source '$UI_PATH'"`, which resolves `bash` through PATH — on dev machines brew's bash takes precedence over `/bin/bash`. No existing unit test forces `/bin/bash` explicitly. Locked in by H.e.7a.

**Fix.** Replace the associative array with a delimited-string scan — semantically identical for our key set, bash-3.2-safe:

```bash
__DEPRECATION_WARNED_KEYS=""
deprecation_warn() {
    local key="$1" old_form="$2" new_form="$3"
    case ":$__DEPRECATION_WARNED_KEYS:" in
        *":$key:"*) return 0 ;;
    esac
    __DEPRECATION_WARNED_KEYS="$__DEPRECATION_WARNED_KEYS:$key"
    echo -e "  ${WARN} '${old_form}' is deprecated. Use '${new_form}' instead." >&2
}
```

Current keys (`testenv --init`, `testenv --install`, `testenv --purge`, `python-version`) contain no `:`; the delimiter is safe. New keys introduced later must remain colon-free — locked in by the delimiter-safety test below.

**Tasks**

- [x] **Red:** Source-under-`/bin/bash` regression test in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats) — stderr must stay empty. Failed before fix (declare error leaked), passes after.
- [x] **Red:** Functional **distinct-keys** regression test — initial version used same-key (k1, k1) and passed coincidentally under bash 3.2's `[$key]` → arithmetic-eval-to-index-0 quirk. Strengthened to distinct keys (ka, kb), which collapses to the same index under the broken code and exposes the bug.
- [x] **Red:** Grep invariant — no `^\s*declare\s+-A\b` in `lib/ui.sh`.
- [x] **Red (forward-looking green):** Grep invariant — no `deprecation_warn` call in `pyve.sh` passes a key containing `:`. Already green today (current keys are colon-free); locks in the rule so a future `"python:set"`-shaped key can't silently break the guard.
- [x] **Green:** Replaced `declare -A __DEPRECATION_WARNED_KEYS` with `__DEPRECATION_WARNED_KEYS=""` plus a `case ":$__…:" in *":$key:"*)` scan. Added an implementation-note comment inside `deprecation_warn` explaining the bash 3.2 constraint and the `:`-in-keys invariant.
- [x] **Full suite green:** `bats tests/unit/*.bats` → **573 / 573** pass (was 569 before H.e.7a; +4 regression tests).
- [x] **Lint:** `shellcheck lib/ui.sh` clean (exit 0).
- [x] **Smoke reproduction:** `/bin/bash -c "set -euo pipefail; source lib/ui.sh; deprecation_warn ka ...; deprecation_warn kb ..."` — both warnings fire, exit 0. Matches the CI invocation that previously failed.
- [x] **No CHANGELOG entry, no version bump** — still rolls into the v2.0.0 cut in H.e.9.

**Deliverables:** updated `deprecation_warn()` in [lib/ui.sh](../../lib/ui.sh); 4 new tests (36–39) in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats).

---

### Story H.e.8: Delegate-with-warning for 'pyve doctor' and 'pyve validate' → 'pyve check' [Done]

Second of three sub-stories contributing to the v2.0.0 breaking cut (no version bump here — version lands at H.e.9). Implements the delegate-with-warning pattern for `doctor` and `validate` per [phase-H-cli-refactor-design.md §5 D3](phase-H-cli-refactor-design.md) and [phase-H-check-status-design.md §6](phase-H-check-status-design.md).

**Scope (in):**

- Both `pyve doctor` and `pyve validate` reroute through `check_command` — they stop running their own diagnostic code and instead run `check`'s.
- Each emits a single **delegation** notice on stderr, once per invocation: `pyve doctor: renamed to 'pyve check'. Running 'pyve check' now...` (and likewise for `validate`). This is a distinct message shape from H.e.7's `deprecation_warn` ("X is deprecated. Use Y instead."), because `doctor` / `validate` are fully delegating (transparent redirect), whereas `testenv --init` / `python-version` continue to execute their own code paths.
- New helper `delegation_warn(key, old_form, new_form)` in `lib/ui.sh`. Same once-per-key guard mechanism as `deprecation_warn` (shared `__DEPRECATION_WARNED_KEYS` state — single key space to prevent accidental double-fires for the same rename), different message template. Stderr-only. No `--help` reference.
- Exit code of `pyve doctor` / `pyve validate` matches what `pyve check` would return for the same project state (the 0/1/2 semantics from [phase-H-check-status-design.md §3.2](phase-H-check-status-design.md)).
- `pyve doctor --help` and `pyve validate --help` show `check`'s help text (not `doctor_command`'s built-in banner and not `show_validate_help`). The old help would advertise flags that no longer route anywhere.
- `PYVE_DISPATCH_TRACE` traces emit a distinctive `DISPATCH:doctor→check` / `DISPATCH:validate→check` line so existing trace-based tests can distinguish the delegating arm from a direct `check` invocation.

**Scope (out — deferred):**

- **Do not delete** `doctor_command()` at [pyve.sh:2079](../../pyve.sh#L2079), `run_full_validation()` (the `validate` backend), or `show_validate_help()` at [pyve.sh:3328](../../pyve.sh#L3328). After H.e.8 they are unreachable via the dispatcher but stay in the source tree. Removal lands in Phase I / v3.0 per [phase-H-cli-refactor-design.md §9](phase-H-cli-refactor-design.md). A single-line comment over each notes the status so a future reader isn't misled.
- **Do not add** `--doctor` / `--status` entries to `legacy_flag_error` yet — that's H.e.9 (the v2.0.0 breaking cut).

**Tasks**

- [x] **Red:** 7 failing helper-level tests for `delegation_warn()` appended to [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats) — stderr-only, exact message template, `--help` absence, once-per-key, distinct-key, `NO_COLOR=1` strips ANSI, `/bin/bash` 3.2 parity.
- [x] **Red:** 14 failing integration tests in new [tests/unit/test_doctor_validate_delegation.bats](../../tests/unit/test_doctor_validate_delegation.bats) — delegation notice on stderr / not stdout / no `--help` reference for both `doctor` and `validate`; `check`'s banner replaces the legacy banners on stdout; `--help` routes to `show_check_help` and does NOT fire the notice; `PYVE_DISPATCH_TRACE` emits `DISPATCH:doctor→check` and `DISPATCH:validate→check`; direct `pyve check` stays silent.
- [x] **Refactor during green:** Extracted a tiny internal `_rename_seen()` guard in [lib/ui.sh](../../lib/ui.sh) so `deprecation_warn` and `delegation_warn` share the once-per-key mechanism without duplicating the delimiter logic. One template each, no drift.
- [x] **Green:** Added `delegation_warn()` in [lib/ui.sh](../../lib/ui.sh) sharing `__DEPRECATION_WARNED_KEYS` with `deprecation_warn()` via `_rename_seen()`. Message matches `<old>: renamed to '<new>'. Running '<new>' now...` literally.
- [x] **Green:** Rewrote the `doctor)` dispatcher arm at [pyve.sh:3655-3670](../../pyve.sh#L3655-L3670) with the `--help` / `PYVE_DISPATCH_TRACE` / `delegation_warn` / `check_command "$@"` pattern.
- [x] **Green:** Rewrote the `validate)` arm at [pyve.sh:3574-3587](../../pyve.sh#L3574-L3587) with the same pattern.
- [x] **Green:** Added "Legacy — unreachable via dispatcher after H.e.8; removed in v3.0" comment blocks above [doctor_command()](../../pyve.sh#L2079), [show_validate_help()](../../pyve.sh#L3332), and [run_full_validation() in lib/version.sh:173](../../lib/version.sh#L173).
- [x] **Fallout fix:** Two `test_subcommand_help.bats` tests (`validate --help` / `validate -h`) previously asserted the old `show_validate_help` banner. Updated to assert `check`'s help instead, consistent with H.e.8's delegation contract.
- [x] **Full suite green:** `bats tests/unit/*.bats` — **594 / 594** pass (was 573 before H.e.8; +7 helper tests + 14 integration tests).
- [x] **Lint:** `shellcheck lib/ui.sh` clean (exit 0). Pre-existing SC2206 warning in `lib/version.sh:23` unchanged (comment-only touch on this file).
- [x] **No CHANGELOG entry yet** — rolls into the v2.0.0 entry in H.e.9.
- [x] **No version bump** — pyve stays at 1.20.1 through H.e.8.

**Deliverables:** new `delegation_warn()` helper + shared `_rename_seen()` guard in [lib/ui.sh](../../lib/ui.sh); rewritten `doctor)` and `validate)` dispatcher arms in [pyve.sh](../../pyve.sh); legacy-marker comments above `doctor_command()` / `run_full_validation()` / `show_validate_help()`; new [tests/unit/test_doctor_validate_delegation.bats](../../tests/unit/test_doctor_validate_delegation.bats); 7 `delegation_warn` helper tests appended to [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats); 2 `validate --help` tests updated in [tests/unit/test_subcommand_help.bats](../../tests/unit/test_subcommand_help.bats).

---

### Story H.e.8a: Rip out 'pyve doctor' and 'pyve validate' entirely [Done]

H.e.8 routed `doctor` and `validate` through `check` as delegating aliases. Review of the fallout in the pytest integration suite (43 tests asserting the old doctor/validate contract) showed no reason to keep the legacy names alive through v2.0.x. This story accelerates the v3.0 hard-removal forward to v2.0.0 — no more delegation, no transparent aliasing, no silent behavior change via the old command names.

Supersedes the H.d §5 D3 "delegate-with-warning" plan for `doctor` / `validate` specifically. The testenv flag forms and `python-version` still follow H.e.7's delegate-with-warning path; only `doctor` / `validate` hard-remove in v2.0. The H.d spec table is updated in H.e.9 as part of the v2.0.0 CHANGELOG + migration guide pass.

**Scope (in):**

- Replace the `doctor)` and `validate)` dispatcher arms with one-line `legacy_flag_error` calls — `legacy_flag_error "doctor" "check"` / `legacy_flag_error "validate" "check"`. Exit 1. Message already reads `'pyve <old>' is no longer supported. Use 'pyve check' instead.` — the existing helper format covers this case without modification.
- Remove dead code:
  - `doctor_command()` in [pyve.sh](../../pyve.sh) (the entire function body).
  - `show_validate_help()` in [pyve.sh](../../pyve.sh).
  - `run_full_validation()` in [lib/version.sh](../../lib/version.sh). Audit: `_escalate()` is defined inside `run_full_validation` and used only by it — dies with the function. Nothing else to rescue.
  - `delegation_warn()` + the 7 helper tests in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats). `_rename_seen()` stays (still used by `deprecation_warn`).
- Remove tests that assert removed behavior:
  - [tests/integration/test_doctor.py](../../tests/integration/test_doctor.py) (20 tests, all classes).
  - [tests/integration/test_validate.py](../../tests/integration/test_validate.py) (23 tests, all classes).
  - [tests/unit/test_doctor_validate_delegation.bats](../../tests/unit/test_doctor_validate_delegation.bats) (14 tests from H.e.8).
  - `run_full_validation` tests in [tests/unit/test_version.bats](../../tests/unit/test_version.bats) (5 tests).
  - The 2 `validate --help` tests in [tests/unit/test_subcommand_help.bats](../../tests/unit/test_subcommand_help.bats) — replaced by the removal assertion in the new file below.
- Add a new small bats file `tests/unit/test_doctor_validate_removed.bats` asserting:
  - `pyve doctor` exits 1.
  - Stderr contains `'pyve doctor' is no longer supported` and `Use 'pyve check' instead`.
  - `pyve validate` same pattern.
  - `pyve check` is unaffected (smoke test — exit 1 on missing config, but output contains `Pyve Environment Check`).

**Scope (out — belongs to later sub-stories):**

- H.d §5 table / §12 story list edits — rolls into the H.e.9 design-doc pass.
- CHANGELOG entry / migration guide — H.e.9.
- Version bump — H.e.9 (v2.0.0 cut).

**Tasks**

- [x] **Red:** New [tests/unit/test_doctor_validate_removed.bats](../../tests/unit/test_doctor_validate_removed.bats) (8 assertions — exit 1, migration message on stderr, check's banner absent from stdout for both `doctor` and `validate`; `pyve check` regression guard). 4 red initially (delegation still in place), 4 green coincidentally (exit 1 matched on missing config).
- [x] **Green:** `doctor)` arm shrunk to `legacy_flag_error "doctor" "check"` (3 lines).
- [x] **Green:** `validate)` arm shrunk to `legacy_flag_error "validate" "check"` (3 lines).
- [x] **Green (dead-code removal):** Deleted `doctor_command()` + its section header (~241 lines) in [pyve.sh](../../pyve.sh).
- [x] **Green:** Deleted `show_validate_help()` + its legacy-marker comment in [pyve.sh](../../pyve.sh).
- [x] **Green:** Deleted `run_full_validation()` and its inner `_escalate()` helper (~127 lines) in [lib/version.sh](../../lib/version.sh). Audited: `_escalate` was function-local, no other callers.
- [x] **Green:** Deleted `delegation_warn()` from [lib/ui.sh](../../lib/ui.sh). Collapsed the "Rename announcements" dual-helper section back to a "Deprecation warning" single-helper section. `_rename_seen()` stays (still used by `deprecation_warn`).
- [x] **Test cleanup:** Deleted the 7 `delegation_warn` tests + their section header from [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats).
- [x] **Test cleanup:** `rm tests/integration/test_doctor.py tests/integration/test_validate.py tests/unit/test_doctor_validate_delegation.bats` (57 tests total — 20 + 23 pytest + 14 bats).
- [x] **Test cleanup:** Deleted the 5 `run_full_validation` tests + their section header from [tests/unit/test_version.bats](../../tests/unit/test_version.bats).
- [x] **Test cleanup:** Deleted the 2 `validate --help` tests from [tests/unit/test_subcommand_help.bats](../../tests/unit/test_subcommand_help.bats).
- [x] **Fallout fix:** The `--validate)` legacy flag arm at [pyve.sh:3272](../../pyve.sh#L3272) previously routed `'pyve --validate'` error message at `pyve validate` — which now also errors. Updated to point at `pyve check` instead. Matching `legacy: 'pyve --validate'` test in [test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats) updated to expect `pyve check` in the message.
- [x] **Fallout fix:** Deleted the `dispatch: 'pyve validate' routes to the validate handler` test in [test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats) — the validate arm no longer emits a `DISPATCH:validate` trace (it exits 1 via `legacy_flag_error` before reaching that branch).
- [x] **Full suite green:** `bats tests/unit/*.bats` → **573 / 573** pass (baseline from end of H.e.7a, after removing 21 H.e.8-specific tests and adding 8 H.e.8a removal tests = 594 − 29 + 8 = 573).
- [x] **Lint:** `shellcheck lib/ui.sh` + `lib/version.sh` → exit 0. `shellcheck pyve.sh` → only pre-existing warnings unchanged.
- [x] **Smoke reproduction:** `/bin/bash -c '"pyve.sh" doctor; echo EXIT:$?'` → `ERROR: 'pyve doctor' is no longer supported. Use 'pyve check' instead. / EXIT:1`. Same for `validate`. Matches under macOS system bash 3.2.
- [x] **No CHANGELOG entry, no version bump** — still rolls into the v2.0.0 cut in H.e.9.

**Deliverables:** `doctor)` / `validate)` dispatcher arms shrunk to `legacy_flag_error` one-liners in [pyve.sh](../../pyve.sh); `doctor_command()`, `show_validate_help()`, `run_full_validation()` / `_escalate()`, `delegation_warn()` removed; `--validate` legacy flag target updated to `check`; new [tests/unit/test_doctor_validate_removed.bats](../../tests/unit/test_doctor_validate_removed.bats) (8 tests); 29 obsolete tests deleted (7 delegation_warn + 14 delegation integration + 5 run_full_validation + 2 validate --help + 1 dispatch trace); 43 pytest integration tests deleted (test_doctor.py + test_validate.py).

---

### Story H.e.8b: Test cleanup fallout — remaining 'pyve.doctor()' / 'pyve.run("validate")' callers [Done]

H.e.8a deleted `tests/integration/test_doctor.py` and `tests/integration/test_validate.py` but missed four other pytest files that still invoked the removed commands via the `pyve.doctor()` helper method or `pyve.run("validate", ...)`. CI surfaced the miss: `TestMicromambaWorkflow.test_doctor_shows_micromamba_status` (and four others across `test_venv_workflow.py`, `test_subcommand_cli.py`, `test_micromamba_workflow.py`) raised `CalledProcessError` on the exit-1 migration error. The `.doctor()` helper method itself remained in `pyve_test_helpers.py` and the `tests/README.md` example still demonstrated the old pattern.

No code changes to `pyve.sh` / `lib/*` — this is pure test-and-docs cleanup completing H.e.8a's scope.

**Scope (in):**

- Delete the 6 remaining pytest tests that call `pyve.doctor()` or `pyve.run("validate", ...)`. All are behavioral tests of removed commands with no semantic target:
  - `test_venv_workflow.py` — `test_doctor_shows_venv_status`, `test_doctor_without_init`.
  - `test_micromamba_workflow.py` — `test_doctor_shows_micromamba_status`, `test_doctor_without_init`.
  - `test_subcommand_cli.py` — `test_validate_subcommand_runs`, `test_validate_subcommand_no_project`.
- Delete the `.doctor()` method on `PyveRunner` in [tests/helpers/pyve_test_helpers.py](../../tests/helpers/pyve_test_helpers.py) — zero callers after the above deletions.
- Rewrite the `pyve.doctor()` example in [tests/README.md](../../tests/README.md) to use `pyve.run("check", check=False)` — the current recommended pattern.

**Scope (out):**

- Integration coverage of `pyve check`'s behavior remains a documented future gap (would be `tests/integration/test_check.py`). Tracked separately; not in this story.
- No version bump, no CHANGELOG entry — still rolls into the v2.0.0 cut in H.e.9.

**Tasks**

- [x] **Audit widened:** Initial grep found the planned 6 pytest callers + helper + README, **plus** one more hit in [docs/specs/testing-spec.md:239](../../docs/specs/testing-spec.md#L239) — a `test_venv_doctor_shows_backend` example asserting `Backend: venv` (a doctor-specific string). Added to scope.
- [x] Deleted the 2 doctor-based tests in [test_venv_workflow.py](../../tests/integration/test_venv_workflow.py).
- [x] Deleted the 2 doctor-based tests in [test_micromamba_workflow.py](../../tests/integration/test_micromamba_workflow.py).
- [x] Deleted the 2 validate-based tests in [test_subcommand_cli.py](../../tests/integration/test_subcommand_cli.py).
- [x] Deleted the `.doctor()` method + its docstring in [pyve_test_helpers.py](../../tests/helpers/pyve_test_helpers.py).
- [x] Rewrote the [tests/README.md:302-319](../../tests/README.md#L302-L319) example — parametrize block now calls `pyve.run("check", check=False)`, accepts exit 0 or 2 (pass or warnings-only), and asserts on `Pyve Environment Check`.
- [x] Rewrote the [docs/specs/testing-spec.md:236-243](../../docs/specs/testing-spec.md#L236-L243) `test_venv_doctor_shows_backend` example into `test_venv_check_runs` with the same `check`-based pattern.
- [x] **Full suite green:** `bats tests/unit/*.bats` → **573 / 573** pass (unchanged — this story made no bats-level changes).
- [x] **Post-cleanup grep:** `pyve\.doctor\(|pyve\.run\(["']validate["']|\.doctor\(self` across the repo returns **zero hits in code or tests** — only the self-references in this story entry remain in `stories.md`, which is expected.

**Deliverables:** 6 pytest tests deleted across 3 files; `.doctor()` helper method removed from `pyve_test_helpers.py`; [tests/README.md](../../tests/README.md) and [docs/specs/testing-spec.md](../../docs/specs/testing-spec.md) examples rewritten to use `pyve.run("check", …)`.

---

### Story H.e.9: v2.0.0 Breaking Cut — legacy-flag extensions, CHANGELOG, migration guide, version bump [Done]

Final sub-story in the v2.0.0 arc. Closes out the H.e breaking-change window by locking in the remaining legacy-flag catches, converting `init --update` from a functional flag to a hard error, and cutting the v2.0.0 release. Superseded-by-H.e.8a design fixups in [phase-H-cli-refactor-design.md](phase-H-cli-refactor-design.md) ride along.

**Scope (in):**

Code changes in [pyve.sh](../../pyve.sh):

- Add three top-level legacy-flag-catch arms alongside the existing `--init` / `--purge` / `--validate` catches (near [pyve.sh:3267](../../pyve.sh#L3267)):
  - `--update)` → `legacy_flag_error "--update" "update"` — "'pyve --update' is no longer supported. Use 'pyve update' instead."
  - `--doctor)` → `legacy_flag_error "--doctor" "check"` — pre-emptive catch for users migrating from another tool's convention; `doctor` as a subcommand was hard-removed in H.e.8a.
  - `--status)` → `legacy_flag_error "--status" "status"` — pre-emptive catch for the flag-form instinct. `pyve status` subcommand is the real command (from H.e.4).
- Convert the `--update)` arm inside `init`'s parser at [pyve.sh:572](../../pyve.sh#L572) from `PYVE_REINIT_MODE="update"` to `legacy_flag_error "init --update" "update"`. Rationale per [phase-H-cli-refactor-design.md §5 D3](phase-H-cli-refactor-design.md): the semantics of `pyve update` (config bump + managed-files refresh + project-guide refresh) are broader than v1.x `init --update` (config bump only), so silent delegation would surprise users who scripted `init --update` expecting the narrow behavior. Hard error forces deliberate migration.
- Bump `VERSION="1.20.0"` at [pyve.sh:32](../../pyve.sh#L32) to `VERSION="2.0.0"`.

Doc changes:

- [CHANGELOG.md](../../CHANGELOG.md) — new `[2.0.0] - <date>` entry at the top. Structured as: (1) breaking-changes summary list, (2) migration table mapping every removed/renamed form to its v2.0 replacement (per [phase-H-cli-refactor-design.md §8](phase-H-cli-refactor-design.md)), (3) deprecation list of forms that still work but warn (testenv flags + `python-version`, per H.e.7). Links out to design docs for deep dives; no long prose.
- New [docs/site/migration.md](../../docs/site/migration.md) file. Short: one-paragraph framing, the migration table mirrored from the CHANGELOG, a "you can keep using these with warnings until v3.0" section for the testenv flags + `python-version`. Cross-links to `CHANGELOG.md` and `phase-H-cli-refactor-design.md`.
- Update [phase-H-cli-refactor-design.md §5 D3](phase-H-cli-refactor-design.md) table and §12 sub-story list — doctor/validate were hard-removed in v2.0 (via H.e.8a), not delegate-with-warning as originally planned. One row change in the §5 table, one sub-story line update in §12. Self-contained.

**Scope (out — remain as placeholder sub-stories, tracked separately below):**

- Shell completion (`lib/completion/*`) updates for the new surface.
- "Unknown flag for this subcommand" closest-match errors (H.d §4.5 D2).
- [docs/specs/features.md](../../docs/specs/features.md) command-reference rewrite.
- [docs/specs/tech-spec.md](../../docs/specs/tech-spec.md) dispatcher-layout update.
- [docs/site/usage.md](../../docs/site/usage.md) rewrite.

The four doc-heavy items are substantial on their own and should be their own sub-stories after the cut, not bundled into the v2.0.0 release gate.

**Tasks**

- [x] **Red:** 5 failing tests added to [tests/unit/test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats): `pyve --update`, `pyve --doctor`, `pyve --status`, `pyve init --update` (with `.pyve`/`.venv`-absent assertions), and `pyve --version` reports 2.0.0.
- [x] **Green:** Added three top-level legacy-flag arms (`--update` / `--doctor` / `--status`) in [pyve.sh](../../pyve.sh) next to the existing catches.
- [x] **Green:** Converted `init`'s `--update)` arm to `legacy_flag_error "init --update" "update"`. Audited `PYVE_REINIT_MODE="update"` usage and removed the entire dead `PYVE_REINIT_MODE == "update"` branch (~55 lines) inside `init()` — the variable was set only in that one arm, no other readers of the `"update"` value existed, the whole branch is now unreachable.
- [x] **Green:** Bumped `VERSION="1.20.0"` → `VERSION="2.0.0"` in [pyve.sh:32](../../pyve.sh#L32).
- [x] **CHANGELOG:** New `[2.0.0] - 2026-04-19` entry at the top of [CHANGELOG.md](../../CHANGELOG.md). Sections: Phase-H framing paragraph, BREAKING CHANGES, Added, Deprecated (still works in v2.x), Migration table, Changed, Internal.
- [x] **Migration guide:** New [docs/site/migration.md](../../docs/site/migration.md) (76 lines). Sections: What breaks immediately (with migration table), What still works but warns, What didn't change, Quick migration recipe.
- [x] **Design-doc fixup:** Updated [phase-H-cli-refactor-design.md §5 D3](phase-H-cli-refactor-design.md) — `doctor` / `validate` rows now say "Legacy-flag error" with a post-H.e.8a amendment paragraph explaining the reasoning; the "delegate-with-warning" prose was narrowed to apply only to testenv flags + `python-version`. Updated §12 to reflect the actual shipped sub-story sequence (H.e.1 through H.e.9) and explicitly move unknown-flag / completion / doc-rewrites out of v2.0.0 scope.
- [x] **Full suite green:** `bats tests/unit/*.bats` → **578 / 578** pass (573 baseline + 5 new).
- [x] **Lint:** `shellcheck pyve.sh` → exit 0, only pre-existing warnings (2 in unrelated `lib/version.sh`).
- [x] **Smoke reproduction:** `/bin/bash -c '"pyve.sh" --version'` → `pyve version 2.0.0`. Each of the four legacy forms produces its expected `legacy_flag_error` message under `/bin/bash`.

**Deliverables:** `VERSION` bumped to 2.0.0 in [pyve.sh](../../pyve.sh); three new top-level legacy-flag catches; `init --update` converted to hard error + ~55 lines of now-dead `PYVE_REINIT_MODE=="update"` branch removed; new `[2.0.0]` CHANGELOG entry; new [docs/site/migration.md](../../docs/site/migration.md); [phase-H-cli-refactor-design.md](../../docs/specs/phase-H-cli-refactor-design.md) §5 D3 amendment + §12 rewrite; 5 new bats tests in [test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats).

---

### Story H.e.9a: Test cleanup fallout from H.e.9 [Done]

Mirrors the H.e.8b pattern. H.e.9 converted `init --update` to a `legacy_flag_error` call (hard exit 1) but left behind 11 pytest callers across 3 files still asserting the old flag's behavior. CI surfaced the first one (`TestPipUpgradeMicromamba::test_update_upgrades_pip`); audit found 10 more.

**Scope:** test-and-docstring cleanup only. Zero pyve.sh / lib/* changes.

**Tasks**

- [x] **Audit:** `grep -rE 'init.*--update|"--update"|'\''--update'\''' tests/` — 11 callers enumerated across `test_reinit.py` (8), `test_pip_upgrade.py` (2), `test_project_guide_integration.py` (1).
- [x] **Delete — 10 tests whose intent was specifically about old `init --update` flag behavior:**
  - `test_reinit.py::TestReinitUpdate` — entire class (4 tests: `test_update_preserves_venv`, `test_update_updates_version`, `test_update_rejects_backend_change`, `test_update_allows_same_backend`).
  - `test_reinit.py::TestLegacyProjects::test_update_legacy_project` (1 test).
  - `test_reinit.py::TestEdgeCases::test_update_with_corrupted_config` (1 test).
  - `test_reinit.py::TestEdgeCases::test_update_preserves_custom_venv_dir` (1 test).
  - `test_reinit.py::TestReinitUpdateMissingEnv::test_update_flag_creates_missing_venv` (1 test — v1-only semantics; `pyve update` explicitly doesn't rebuild the venv per H.d §4.3).
  - `test_pip_upgrade.py::TestPipUpgradeVenv::test_update_upgrades_pip` (1 test — v1-only pip-upgrade-on-update semantics).
  - `test_pip_upgrade.py::TestPipUpgradeMicromamba::test_update_upgrades_pip` (1 test — same).
- [x] **Migrate — 1 surgical change in `test_project_guide_integration.py::test_idempotent_reinstall_is_fast`:** changed `pyve.run("init", "--update", timeout=60)` → `pyve.run("update", timeout=60)` at line 472. Outer test's intent (first run = real install, second run = fast idempotent refresh) carries over cleanly to the new `pyve update` command; assertion (`second_duration < first_duration`) unchanged. Updated the surrounding comment to reflect `pyve update`'s semantics (refreshes managed files, never rebuilds the venv).
- [x] **Docstring cleanup:** Removed stale `--update flag` references from the module-level docstrings of `test_reinit.py` and `test_pip_upgrade.py`. Dropped the `TestReinitUpdateMissingEnv` class docstring reference to the `--update flag path` (only the interactive option 1 test survives; class docstring narrowed to match).
- [x] **Post-cleanup grep:** `init.*--update|"--update"|'--update'` across `tests/` — only legitimate remaining hits are (a) [test_cli_dispatch.bats:188-191](../../tests/unit/test_cli_dispatch.bats#L188-L191) (the H.e.9 migration-error assertion) and (b) [test_project_guide_integration.py:471](../../tests/integration/test_project_guide_integration.py#L471) (an in-code comment explaining the H.e.9a migration).
- [x] **Full suite green:** `bats tests/unit/*.bats` → **578 / 578** pass (no bats-level changes in H.e.9a).
- [x] **No CHANGELOG entry, no version bump** — v2.0.0 already cut in H.e.9; H.e.9a is CHANGELOG-silent test cleanup.

**Deliverables:** 10 pytest tests deleted across 2 files; 1 call-site edit + comment rewrite in `test_project_guide_integration.py`; 3 module-level docstring updates (`test_reinit.py`, `test_pip_upgrade.py`, and the `TestReinitUpdateMissingEnv` class docstring).

---

### Story H.e.9b: Retarget '--python-version' legacy-flag catch to 'pyve python set' [Done]

Fit-and-finish follow-on to H.e.9. The `--python-version` legacy-flag catch at [pyve.sh:3276](../../pyve.sh#L3276) currently redirects users to `pyve python-version <ver>` — a form that still works in v2.x but is deprecated (warns + delegates per H.e.7). Retarget the error message at the new canonical form `pyve python set <ver>` so users migrating from pre-v1.11 flag-style CLIs land on the v2.0-canonical shape directly, bypassing the deprecation-warning path.

**Scope (in):**

- Change `legacy_flag_error "--python-version" "python-version <ver>"` at [pyve.sh:3276](../../pyve.sh#L3276) to `legacy_flag_error "--python-version" "python set <ver>"`.
- Update the matching assertion in [tests/unit/test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats) (the `pyve --python-version 3.12.0` test at ~line 156 currently asserts `"pyve python-version"` in stderr — retarget to `"pyve python set"`).

**Scope (out):** `python-version` subcommand's own deprecation warning (kept, per H.e.7's delegate-with-warning plan).

**Tasks**

- [x] **Red:** Flipped the assertion in [test_cli_dispatch.bats:156](../../tests/unit/test_cli_dispatch.bats#L156) from `"pyve python-version"` to `"pyve python set"`; renamed the test to "…pointing at v2.0-canonical form". Failed on pre-change implementation.
- [x] **Green:** One-line change at [pyve.sh:3276](../../pyve.sh#L3276) — `legacy_flag_error "--python-version" "python-version <ver>"` → `legacy_flag_error "--python-version" "python set <ver>"`.
- [x] **Full suite green:** `bats tests/unit/*.bats` → **578 / 578** pass.

**Deliverables:** one-line change in [pyve.sh](../../pyve.sh); one assertion + test name flipped in [test_cli_dispatch.bats](../../tests/unit/test_cli_dispatch.bats).

---

### Story H.e.9c: Introduce shell completion for bash and zsh [Done]

Net-new feature. No `lib/completion/` directory exists today — pyve has shipped without completion support. Users who tab-complete `pyve <TAB>` get whatever their shell's default path-completion produces (noise). Shipping completion that matches the v2.0 surface improves day-one discoverability of the 12-ish top-level subcommands and their flags.

**Scope (in):**

- `lib/completion/pyve.bash` — bash completion script. Completes top-level subcommands (`init`, `purge`, `lock`, `run`, `test`, `testenv`, `check`, `status`, `update`, `python`, `self`), nested subcommands (`python set|show`, `self install|uninstall`, `testenv init|install|purge|run`), and per-subcommand flags (drawn from each command's canonical flag list).
- `lib/completion/_pyve` — zsh completion (same surface, zsh-native format using `_arguments` / `_describe`).
- `pyve self install` installs the completion scripts to the user's shell completion directory (detect shell from `$SHELL`; skip or warn on unsupported shells). `pyve self uninstall` removes them.
- bats unit tests for the completion logic that can be tested in isolation (e.g., the subcommand-name list matches the dispatcher).
- Integration tests that source the completion script and verify `compgen`-style output for the common cases (`pyve <TAB>`, `pyve testenv <TAB>`, `pyve python <TAB>`, `pyve init --<TAB>`).

**Scope (out):**

- fish, nushell, PowerShell — bash + zsh first; add others later if demand surfaces.
- Value completion (e.g., completing `--python-version <TAB>` with actually-installed versions from asdf/pyenv) — v3 territory. First release completes flag names only.
- Legacy-form completion — don't offer `testenv --init` in completions; only the new forms. The deprecation warnings nudge users toward the canonical shape.

**Tasks**

- [x] **Survey:** Extracted the canonical flag lists from each subcommand's parser in `pyve.sh` via `awk` + `grep`. Inventory embedded inline as literal space-delimited strings at the top of `_pyve()` (not a separate YAML — the lists are short enough that the indirection would be costlier than the duplication).
- [x] **Red:** 15 failing tests in new [tests/unit/test_completion_bash.bats](../../tests/unit/test_completion_bash.bats) covering: every top-level subcommand present; no removed subcommands (`doctor`/`validate`) offered; `pyve init --` lists all init flags; `--update` specifically excluded (post-H.e.9); `--backend` value completion (`venv` / `micromamba`); `testenv` action completion + legacy flag forms excluded; `testenv install -` offers `-r` / `--help`; `python` / `self` nested completion; `update` / `lock` / `purge` flags.
- [x] **Green:** Implemented [lib/completion/pyve.bash](../../lib/completion/pyve.bash) — self-contained (no `bash-completion` library dependency); completes subcommands, flags, nested actions, and `--backend` value. Registers with `complete -F _pyve pyve`.
- [x] **Green:** Implemented [lib/completion/_pyve](../../lib/completion/_pyve) — zsh-native using `_arguments` / `_describe`; parallel coverage. Flag descriptions included for better UX under zsh's rich completion UI.
- [x] **Green:** Extended `install_pyve()` in [pyve.sh](../../pyve.sh) to copy `lib/completion/` alongside `lib/*.sh`; post-install hint emits shell-specific activation instructions.
- [x] **Uninstall:** No change needed — existing `rm -rf "$TARGET_BIN_DIR/lib"` already removes the completion dir.
- [x] **Lint:** `shellcheck lib/completion/pyve.bash` → exit 0. `zsh -n lib/completion/_pyve` → exit 0 (syntax check).
- [x] **Full suite green:** `bats tests/unit/*.bats` → **593 / 593** pass (578 baseline + 15 completion tests).

**Scope deviations from the draft:**

- The draft proposed deploying completion scripts to the user's shell completion directory with shell detection. Dropped in favor of the simpler approach: copy scripts into `~/.local/bin/lib/completion/` alongside other lib files, and emit activation instructions post-install. Rationale: shell-completion-dir detection is brittle (bash uses `~/.bash_completion.d/`, XDG dirs, or `/usr/local/etc/bash_completion.d/`; zsh uses `$fpath`; users' setups vary widely). Emitting a one-line `source ~/.local/bin/lib/completion/pyve.bash` is honest and works in every environment.
- The draft mentioned a CHANGELOG entry; deferred until the next version bump rollup (completion is additive; no new release cut today).

**Deliverables:** [lib/completion/pyve.bash](../../lib/completion/pyve.bash); [lib/completion/_pyve](../../lib/completion/_pyve); `install_pyve()` updated to copy `lib/completion/` and emit activation hints; new [tests/unit/test_completion_bash.bats](../../tests/unit/test_completion_bash.bats) (15 tests).

---

### Story H.e.9d: Closest-match "did you mean?" for unknown flags [Done]

Ratifies [phase-H-cli-refactor-design.md §4.5 D2](phase-H-cli-refactor-design.md). When a user typos a flag (`pyve init --purge` — meant `--force`), the current error is a generic `log_error "Unknown option: ..."`. D2 specifies a helpful error with the closest-match valid flag + the full valid-flag list.

**Scope (in):**

- Bash-native Levenshtein-like edit-distance function in `lib/ui.sh` (no external tools, no Python). Distance ≤ 3 for the "did you mean?" hint to fire; above that, skip the hint and just list valid flags.
- Per-subcommand canonical flag-list arrays at the top of each command function (`init()`, `testenv_command()`, etc.). Each function's unknown-flag branch calls a shared `unknown_flag_error <subcommand> <bad_flag> <flag1> <flag2> …`.
- Error message shape per D2:
  ```
  ERROR: 'pyve init' does not accept '--purge'.
    Did you mean: '--force'?
    Valid flags for 'pyve init': --python-version, --backend, --force, ...
    See: pyve init --help
  ```

**Scope (out):**

- Closest-match on subcommands (`pyve intit` → "did you mean `init`?"). Subcommand-level suggestions are a separate cycle of the same design; keep H.e.9d tightly scoped to flag-within-subcommand errors.
- Completion integration — this story is about error paths, not tab-completion. H.e.9c handles completion.

**Tasks**

- [x] **Red:** 8 helper-level tests for `_edit_distance` in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats) — identical strings, empty→non-empty, single substitution/insertion/deletion, `--purge` vs `--force` = 3, far-typo > 3, bash 3.2 parity under `/bin/bash`.
- [x] **Red:** 11 integration tests in new [tests/unit/test_unknown_flag.bats](../../tests/unit/test_unknown_flag.bats) — close typo (`--forse` → `--force`) fires "Did you mean"; far typo suppresses the hint; valid-flag list enumerated; per-command help pointer included; and `init` / `update` / `check` / `status` / `purge` / `lock` / `testenv` all produce their respective valid-flag lists.
- [x] **Green:** `_edit_distance()` added to [lib/ui.sh](../../lib/ui.sh). Flat-array DP simulation; bash 3.2 safe (no associative arrays).
- [x] **Green:** `unknown_flag_error()` added to [pyve.sh](../../pyve.sh) adjacent to `legacy_flag_error()`. Picks the single closest flag, suppresses the "Did you mean" line when distance > 3, always exits 1. All lines prefixed `ERROR: ` via `log_error` for grep consistency.
- [x] **Green:** Retrofitted **7 sites** to call `unknown_flag_error`: `init` (line 615; 17-flag list), `purge` (1171; 2 flags), `testenv_command` (1391; 6 flags), `status_command` (2058; 1 flag), `check_command` (2352; 1 flag), `update_command` (2636; 2 flags), `run_lock` (2747; 2 flags). Note: single-flag commands technically don't need the suggestion machinery but use it for consistency.
- [x] **Scope carve-out:** `python_command` and `self_command` have unknown-*subcommand* branches (`*)`), not unknown-*flag* branches. Per story scope ("closest-match on subcommands is a separate cycle"), left unchanged.
- [x] **Full suite green:** `bats tests/unit/*.bats` → **612 / 612** pass (593 baseline + 8 helper + 11 integration = 612).
- [x] **Lint:** `shellcheck lib/ui.sh` → exit 0.

**Deliverables:** `_edit_distance()` in [lib/ui.sh](../../lib/ui.sh); `unknown_flag_error()` in [pyve.sh](../../pyve.sh); 7 retrofitted command parsers; new [tests/unit/test_unknown_flag.bats](../../tests/unit/test_unknown_flag.bats) (11 tests); 8 `_edit_distance` tests in [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats).

---

### Story H.e.9e: Rewrite `docs/specs/features.md` command reference for v2.0 [Done]

Internal-spec documentation hygiene. [features.md](../../docs/specs/features.md) currently describes the v1.x command surface; the v2.0 cut left it stale. Rewrite the command-reference section to match what `pyve.sh` actually ships after H.e.9.

**Scope (in):**

- Rewrite the command-reference section to enumerate every v2.0 subcommand (`init`, `purge`, `lock`, `run`, `test`, `testenv init|install|purge|run`, `check`, `status`, `update`, `python set|show`, `self install|uninstall`) with purpose, flags, exit codes.
- Document the deprecation schedule inline at each affected command (testenv flag forms, `python-version`). Remove references to `doctor` and `validate` entirely.
- Add a short "Exit codes" section documenting the 0/1/2 contract for `check` and the `0` contract for `status`.
- Cross-link to [phase-H-cli-refactor-design.md](phase-H-cli-refactor-design.md) for design rationale rather than duplicating it.

**Scope (out):** tech-spec.md (H.e.9f), usage.md (H.e.9g).

**Tasks**

- [x] **Audit:** 14 grep hits for `doctor|validate|init --update|--update` in the pre-edit file — enumerated before touching prose.
- [x] **Targeted rewrites (in place, preserving structure):**
  - Core Requirements line 7: diagnostics → `pyve check` + `pyve status` split.
  - Operational Requirements line 4: smart re-init updated to describe `pyve update` subcommand semantics.
  - Usability Requirements line 3: flag list trimmed of `--update`.
  - Inputs subcommand list: rewritten to the v2.0 surface.
  - Legacy-flag-catches note: expanded to v1.11.0 + v2.0 (H.e.8a) + v2.0 (H.e.9) tiers; also documents the testenv / `python-version` delegate-with-warning path.
  - Optional flags table: removed `--update`; added `--check` for `pyve lock`; all flag-use examples converted from `--init` flag-shape to `pyve init` subcommand-shape.
  - FR-3 retitled + rewritten: `pyve python-version` → `pyve python set` / `pyve python show`.
  - FR-5 retitled + rewritten: `pyve doctor` → `pyve check` with CI-safe 0/1/2 exit codes and ~20-check surface; cross-link to `phase-H-check-status-design.md`.
  - FR-5a added: `pyve status` as read-only companion to check.
  - FR-6 removed: `pyve validate` folded into `pyve check`.
  - FR-12 Smart Re-Initialization: rewritten to describe `pyve update` vs. `pyve init --force` choice.
  - FR-15a added: `pyve update` non-destructive upgrade path (refreshes config + managed files + project-guide; never touches venv).
  - FR-16 project-guide hook: reframed step 2's "only on fresh init / --force, not --update" callout as "`pyve update` runs step 2 independently"; documented what step 2 does inside `pyve update` vs. full `init`.
  - Testing Strategy + Definition of Done: updated `doctor` references to `check` + `status`.
- [x] **Grep-verification:** post-edit `grep -n 'doctor|validate|init --update|--update'` in features.md returns only self-referential "was removed" / "redirected at" lines — no stale positive references to the removed shapes.
- [x] **Regression guard:** `bats tests/unit/*.bats` → **612 / 612** pass (no code changes in H.e.9e; doc edits don't affect bats).

**Deliverables:** updated [docs/specs/features.md](../../docs/specs/features.md) — FR-3 retitled, FR-5 rewritten, FR-5a + FR-15a added, FR-6 removed, FR-12 and FR-16 amended, Inputs/Outputs/Usability tables refreshed to v2.0 surface.

---

### Story H.e.9f: Update `docs/specs/tech-spec.md` for the v2.0 dispatcher layout [Done]

Internal-spec documentation hygiene, companion to H.e.9e. `tech-spec.md` should describe the v2.0 dispatcher structure (top-level arms + nested subcommands), the finalized `lib/ui.sh` signatures (after H.e.7a + H.e.8a trimmed `delegation_warn`), and — per [phase-H-check-status-design.md §2](phase-H-check-status-design.md) — the semantic distinction between `check` (diagnostics with exit-code severity) and `status` (read-only dashboard, always exit 0).

**Scope (in):**

- Dispatcher-layout section: enumerate each `case` arm in `pyve.sh`'s top-level `case "$1" in`, noting which call the handler directly vs. legacy_flag_error arms.
- `lib/ui.sh` signatures reference: every helper (colors, symbols, `banner`, `info`, `success`, `warn`, `fail`, `confirm`, `ask_yn`, `divider`, `run_cmd`, `header_box`, `footer_box`, `_rename_seen`, `deprecation_warn`).
- `check` vs `status` invariant: canonical paragraph stating that `check` surfaces exit codes (0/1/2) and emits findings-per-problem; `status` is read-only, exit 0 unless pyve itself errors. Ensure each command's `--help` text in `pyve.sh` aligns with this paragraph (spot-check required).
- Cross-links to the design docs for the rationale.

**Scope (out):** prose rewrites of unrelated sections (e.g., backend-specific internals) beyond the CLI / dispatcher / `lib/ui.sh` surface.

**Tasks**

- [x] **Audit:** Greppped stale refs — 30+ hits for `doctor|validate|init --update|--update|python-version|delegation_warn|run_full_validation`. Classified each as "replace" vs. "leave (self-referential)" before touching prose.
- [x] **File tree:** Removed `test_doctor.py` and `test_validate.py` from the pytest inventory (deleted in H.e.8a/H.e.8b).
- [x] **pyve.sh section:** VERSION bumped to `2.0.0`; top-level command list rewritten to the v2.0 surface; library sourcing order updated to include `ui.sh` early.
- [x] **`doctor_check_*` helper table:** retained the four helpers (backport continuity) but annotated each with "Reused by `check_command` in v2.0" so future readers understand the name is historical.
- [x] **`lib/version.sh` table:** removed `run_full_validation()` row; added a one-line note that the function + its `_escalate()` helper were deleted in H.e.8a and its semantics migrated to `check_command`.
- [x] **`lib/ui.sh` section: expanded** the helper inventory to cover `_rename_seen`, `deprecation_warn`, `_edit_distance`, and the updated `header_box` / `footer_box` names. Added a bash-3.2 compatibility guard paragraph documenting the H.e.7a invariants (no `declare -A`, no `${var^^}`, etc.). Added a backport-discipline paragraph documenting the "no pyve identifiers" + "no `:` in deprecation keys" invariants.
- [x] **`## CLI Design` framing paragraph:** rewritten to describe the v2.0 cut as the completion of the CLI-unification arc; each rename's v2.0 / v3.0 fate listed.
- [x] **Commands table:** fully rewritten for the v2.0 surface (16 rows including `check`, `status`, `update`, `python set|show`, `testenv init|install|purge|run`). Legacy-form subcommand + flag removals documented inline.
- [x] **Check-vs-status invariant:** added canonical paragraph immediately under the Commands table stating the 0/1/2 vs. always-0 exit-code contract, the "if something looks wrong → check; if 'what is this project?' → status" decision rule, and the requirement that each command's `--help` text mirrors this contract. Cross-links to [phase-H-check-status-design.md §2](phase-H-check-status-design.md).
- [x] **`### Per-Subcommand Help` list:** expanded from the pre-v2.0 command set to the v2.0 surface; noted that `doctor --help` / `validate --help` error out.
- [x] **Modifier Flags table:** removed the `--update` row (the flag was removed in H.e.9).
- [x] **`### Legacy-Flag Error Catch` section:** rewritten with a tiered catches table (v1.11.0 flag-form, v1.11.0 short-alias, v2.0 H.e.8a subcommand-form, v2.0 H.e.9 flag-form, v2.0 H.e.9 `init --update`). Added a paragraph distinguishing this from the H.e.9d unknown-flag closest-match behavior. Added a pointer to the H.e.7 delegate-with-warning path for testenv flags + `python-version`.
- [x] **Unit tests table:** removed the `test_doctor.bats` row (deleted in H.e.8a).
- [x] **Grep-verification:** post-edit `grep -nE "pyve doctor|pyve validate|pyve init --update"` in tech-spec.md returns only three hits, all of which are explicit "was removed" / "error out" self-referential context.
- [x] **Regression guard:** `bats tests/unit/*.bats` → **612 / 612** pass (no code changes in H.e.9f).

**Deliverables:** updated [docs/specs/tech-spec.md](../../docs/specs/tech-spec.md) — Package Structure file tree, `pyve.sh` section, `lib/utils.sh` / `lib/version.sh` / `lib/ui.sh` tables, CLI Design framing + Commands table + check-vs-status invariant paragraph, Per-Subcommand Help list, Modifier Flags table, Legacy-Flag Error Catch section, Unit Tests table.

---

### Story H.e.9g: Rewrite `docs/site/usage.md` for the v2.0 user surface [Done]

User-facing documentation hygiene. [usage.md](../../docs/site/usage.md) is the "how do I use pyve?" page shipped with the docs site. It still lists v1.x commands. Rewrite to match the v2.0 surface, matching the tone of the existing file (concrete examples, short paragraphs, no spec-style rigor).

**Scope (in):**

- Command-by-command examples for every v2.0 subcommand. Keep the existing "getting started" flow intact if the current file has one; just update command names and flags.
- A short "Upgrading from v1.x" section that points at [docs/site/migration.md](../../docs/site/migration.md) (already written in H.e.9).
- Deprecation notice for testenv flag forms + `python-version` inline where they naturally come up — but prefer showing the new form in every example.

**Scope (out):** the migration guide itself (H.e.9 already wrote it); the design rationale (lives in `phase-H-*-design.md`).

**Tasks**

- [x] **Audit:** 30+ grep hits for `doctor|validate|init --update|--update|python-version|testenv --` in the 1048-line pre-edit file. Classified as "replace" vs. "leave (self-referential)".
- [x] **Migration note at top:** rewrote the pre-v1.11 admonition into a v2.0 upgrade summary, linking to `docs/site/migration.md`. Documents doctor/validate removal, `init --update` → `update`, `python-version` → `python set` deprecation, testenv flag deprecation, and the new `pyve status` command.
- [x] **Command Overview tables:** rewrote all three category tables (Environment / Execution / Diagnostics) to the v2.0 surface; replaced `doctor` + `validate` rows with `check` + `status`; added `update` and `python set|show` rows; updated `testenv` row to show the subcommand forms.
- [x] **`init` flag list:** dropped `--update` (removed in v2.0); added a one-liner pointing at `pyve update` for non-destructive refresh.
- [x] **project-guide hook callout:** rewrote the "`pyve init --update` does NOT run the hook" paragraph as "`pyve update` runs step 2 independently" with the new semantics.
- [x] **`### python-version <ver>` section:** retitled and rewritten to `### python set <ver> / python show`; added usage for both; documented the legacy-form delegation + v3.0 removal.
- [x] **`### testenv` section:** updated all usage examples + subcommand-list bullets from `--init`/`--install`/`--purge` flag forms to the `init`/`install`/`purge` subcommand forms; kept a small "legacy forms deprecated" paragraph at the bottom.
- [x] **`### doctor` section deleted**, replaced with `### check`: 0/1/2 exit-code contract, check list, example output, explicit "legacy forms removed" migration note.
- [x] **`### validate` section deleted**, replaced with `### status`: sectioned output, always-zero exit-code contract, example output (venv).
- [x] **`### update` section added** (placed after status): describes the non-destructive upgrade path, its "never rebuilds venv / never prompts / never creates user files" invariants, and the v1.x `init --update` migration.
- [x] **Per-command help listing:** updated to include all v2.0 commands (`check`, `status`, `update`, `python`, `lock`); removed `validate --help`.
- [x] **Workflow Examples section:** replaced `pyve doctor` with `pyve check` / `pyve status` as appropriate (Daily Development, Switching Backends, CI/CD Integration).
- [x] **Tips and Best Practices section:** rewrote "Regular Validation" to describe `pyve check` / `pyve status` semantics; rewrote "Use `.python-version`" example to use `pyve python set`.
- [x] **Grep-verification:** post-edit `grep -nE 'pyve doctor|pyve validate|pyve init --update|pyve testenv --|pyve python-version '` returns only self-referential "was removed" / "still works but deprecated" context, plus the intentional upgrade-summary table at the top and the valid `pyve testenv --help` invocation line.
- [x] **Regression guard:** `bats tests/unit/*.bats` → **612 / 612** pass (no code changes in H.e.9g).

**Deliverables:** updated [docs/site/usage.md](../../docs/site/usage.md) — upgrade summary, Command Overview tables, `init` flag list, project-guide hook callout, `### python set|show` section, `### testenv` examples, `### check` / `### status` / `### update` sections (replacing doctor/validate), Per-command help listing, Workflow Examples, Tips and Best Practices.

---

### Story H.e.9h: Bug fix — bash 3.2 compatibility in 'lib/completion/pyve.bash' [Done]

Test-only + minimal-code bug fix, same class as H.e.7a. H.e.9c's `lib/completion/pyve.bash` used `mapfile -t COMPREPLY < <(compgen -W ... -- "$cur")` at 19 call sites. `mapfile` is a bash 4+ builtin; macOS ships `/bin/bash` at 3.2.57, which fails with:

```
lib/completion/pyve.bash: line 46: mapfile: command not found
```

Silent failure mode: `COMPREPLY` stays empty, so positive assertions (`[[ output == *"init"* ]]`) fail while negative assertions (`[[ output != *"doctor"* ]]`) pass coincidentally. CI surfaced 9 of 15 completion tests failing on macOS runners.

**Why tests didn't catch it locally.** `test_completion_bash.bats` called `run bash -c "source ..."` — `bash` resolves through PATH, which on dev machines picks up brew's bash 5.x (where `mapfile` works). The H.e.7a regression pattern (source via `/bin/bash` explicitly) was not mirrored into `test_completion_bash.bats`. Locked in by H.e.9h.

**Fix.** Replace every `mapfile -t COMPREPLY < <(compgen -W "$words" -- "$cur")` with the bash-3.2-safe shape `COMPREPLY=( $(compgen -W "$words" -- "$cur") )`. Same treatment for `compgen -f` and `compgen -c` call sites (file / command completion).

Adds `# shellcheck disable=SC2207` to the file header because the portable shape triggers SC2207 (word-splitting + glob on compgen output) — unavoidable at bash 3.2, and all `$words` values are local flag-name strings we control (no user input, no glob risk).

**Tasks**

- [x] **Audit:** Reproduced the `mapfile: command not found` error locally via `/bin/bash -c 'source lib/completion/pyve.bash; _pyve'`. Confirmed 19 `mapfile -t COMPREPLY < <(compgen ...)` call sites.
- [x] **Green:** Replaced every `mapfile -t COMPREPLY < <(compgen ...)` with `COMPREPLY=( $(compgen ...) )` at all 19 call sites. Added `# shellcheck disable=SC2207` + explanatory comment at file header.
- [x] **Test harness fix:** Rewrote the `_complete` helper in [tests/unit/test_completion_bash.bats](../../tests/unit/test_completion_bash.bats) to invoke `/bin/bash -c` explicitly (mirroring the H.e.7a pattern in `test_ui.bats`). The existing 15 tests now also serve as bash-3.2 regression guards — no new @test blocks needed for the behavioral coverage.
- [x] **Regression invariant:** Added 2 new tests to `test_completion_bash.bats`:
  - `sources cleanly under /bin/bash` — explicit `/bin/bash -c 'source ...'` with exit 0 + empty-stderr assertion.
  - `contains no 'mapfile' calls (bash 3.2 invariant)` — grep-based invariant that locks the rule for future contributors.
- [x] **Full suite green:** `bats tests/unit/*.bats` → **613 / 613** pass (612 baseline + 1 new mapfile-invariant test). All 15 behavioral completion tests plus the 1 sourcing-under-bash-3.2 test plus the 1 no-mapfile invariant now run under `/bin/bash`.
- [x] **Lint:** `shellcheck lib/completion/pyve.bash` → exit 0.

**Scope-out:** broader audit of `lib/*.sh` and other `lib/completion/*` for bash 4+ constructs. If a future CI run surfaces another instance, spin up H.e.9i. Nothing currently pending.

**Deliverables:** 19 `mapfile` → `COMPREPLY=( $(compgen ...) )` swaps in [lib/completion/pyve.bash](../../lib/completion/pyve.bash) + header lint-disable comment; `_complete` test harness rewritten to use `/bin/bash` in [tests/unit/test_completion_bash.bats](../../tests/unit/test_completion_bash.bats); 2 new regression tests (sourcing + grep invariant).

---

### Story H.e.9i: Bug fix — 'mkdocs build --strict' fails on cross-'docs_dir' links in 'migration.md' [Done]

Docs-only bug fix. No production code changed. Post-merge CI surfaced three `WARNING` lines promoted to fatal by `--strict`:

```
WARNING -  Doc file 'migration.md' contains a link '../specs/phase-H-cli-refactor-design.md', but the target is not found among documentation files.
WARNING -  Doc file 'migration.md' contains a link '../specs/phase-H-check-status-design.md', but the target is not found among documentation files.
WARNING -  Doc file 'migration.md' contains a link '../../CHANGELOG.md', but the target is not found among documentation files.
Aborted with 3 warnings in strict mode!
```

**Root cause.** [docs/site/migration.md:5](../../docs/site/migration.md#L5) was written in H.e.9 with three relative markdown links pointing *outside* `docs_dir=docs/site` ([mkdocs.yml:38](../../mkdocs.yml#L38)) — `../specs/…` and `../../CHANGELOG.md`. mkdocs only validates links against files inside `docs_dir`, so these were treated as broken references. migration.md was also the first file under `docs/site/` to link to repo-root / `docs/specs/` artifacts, so no prior build exercised the pattern. Separately, migration.md was added without being registered in `nav`, producing an `INFO` line (not fatal) that the page was orphaned from the site.

**Fix.** Convert the three cross-`docs_dir` relative links in migration.md to absolute GitHub URLs (`https://github.com/pointmatic/pyve/blob/main/...`). The referenced `docs/specs/` design docs and `CHANGELOG.md` are intentionally developer artifacts, not user docs — linking to GitHub is the correct cross-reference. Register `migration.md` under `nav` in [mkdocs.yml](../../mkdocs.yml) so the page actually ships on the docs site.

**Tasks**

- [x] **Red:** Reproduced the failure via `mkdocs build --strict` (same command CI runs).
- [x] **Green:** Rewrote the three out-of-`docs_dir` links in `docs/site/migration.md` as absolute GitHub URLs.
- [x] **Green:** Added `- Migration (v1.x → v2.0): migration.md` entry to the `nav` list in `mkdocs.yml` (resolves the orphan-page INFO line).
- [x] **Verify:** `mkdocs build --strict` now completes with "Documentation built in 1.46 seconds", no warnings.
- [x] **Audit:** Grep `docs/site/**` for other `](../` relative links that cross `docs_dir`. None found — migration.md was the only offender.

**Why tests didn't catch it earlier.** CI *did* catch it — this very Phase-H merge was the first build of main with migration.md on disk, and CI failed on first run. Local pre-merge builds of the H.e.9 branch either skipped `--strict`, skipped the docs job entirely, or weren't rebuilt after the file was added. The reliable guard going forward is the same `mkdocs build --strict` CI step — no additional test coverage needed.

**Deliverables:** link rewrite in [docs/site/migration.md](../../docs/site/migration.md); nav entry added in [mkdocs.yml](../../mkdocs.yml).

---

### Story H.f: v2.0.1 Retrofit Remaining Commands to Unified UX (umbrella — split into H.f.1, H.f.2, …) [In progress]

Apply the `lib/ui.sh` pattern (introduced in H.e's first sub-story) to every pyve command that H.e did not rewrite. Goal: every pyve command looks and feels like the `gitbetter` commands — rounded-box header, consistent banners, confirmation prompts, dimmed command echo, outcome proof, rounded-box footer.

Split per command (decided 2026-04-19). The version bump (v2.0.1), CHANGELOG entry, and visual-regression captures land in the final sub-story (H.f.5); intermediate sub-stories ship unversioned UX retrofits.

**Sub-stories**

- H.f.1 — Retrofit `pyve init`
- H.f.2 — Retrofit `pyve purge`
- H.f.3 — Retrofit legacy `testenv` and `python-version` subcommands not rewritten in H.e
- H.f.4 — Error path consistency sweep + NO_COLOR audit across all commands
- H.f.5 — v2.0.1 release wrap: visual captures, spec updates, CHANGELOG, version bump

**Commands to retrofit (in scope):**

- [ ] `pyve init` — replace the current noisy output (see baseline example below). Rounded-box header, section banners for purge + rebuild phases, dimmed `$ cmd` echo for every `pip install` / `python` / `direnv` invocation, success-one-liner for each phase, rounded-box footer.
- [ ] `pyve purge` — rounded-box header, confirmation prompt, per-artifact success symbols, footer.
- [ ] `pyve testenv` (any subcommand not rewritten in H.e) — same pattern.
- [ ] `pyve python-version` (or its successor from H.d) — same pattern.
- [ ] Error paths across all commands — red ✗ prefix, consistent format, actionable message.
- [ ] Decide how much pip/pyenv/mamba subprocess output to suppress vs. pass through (e.g., `pip install --quiet` with our own progress line, vs. full pass-through). Document the decision in `features.md`.

**Baseline — the current ugly `pyve init` output being replaced:**

```
% pyve init --force --python-version 3.12.13
WARNING: Force re-initialization: This will purge the existing environment
WARNING:   Current backend: venv

  Purge:   existing venv environment
  Rebuild: fresh venv environment

Proceed? [y/N]: y
INFO: Purging existing environment...

Purging Python environment artifacts...
✓ Removed .tool-versions
✓ Removed .venv
✓ Removed .pyve directory contents (preserved .pyve/testenv)
✓ Removed .envrc
✓ Removed .env (was empty)
✓ Cleaned .gitignore

✓ Python environment artifacts removed.
INFO: ✓ Environment purged

INFO: Proceeding with fresh initialization...

Initializing Python environment...
  Backend:        venv
  Python version: 3.12.13
  Venv directory: .venv
INFO: Using asdf for Python version management
✓ Created .tool-versions with Python 3.12.13
INFO: Creating virtual environment in '.venv'...
✓ Created virtual environment
INFO: Python >= 3.12 detected; installing distutils compatibility shim
✓ Installed distutils compatibility shim: .../.venv/lib/python3.12/site-packages/sitecustomize.py
INFO: Disable with: PYVE_DISABLE_DISTUTILS_SHIM=1
✓ Distutils shim probe: SETUPTOOLS_USE_DISTUTILS=local
✓ Created .envrc
✓ Created empty .env
✓ Updated .gitignore
✓ Created .pyve/config

✓ Python environment initialized successfully!
Install project-guide? [Y/n]:
INFO: Installing/upgrading project-guide into the project environment...
Collecting project-guide
  Using cached project_guide-2.3.9-py3-none-any.whl.metadata (21 kB)
...
```

**Tasks**

- [ ] Audit every pyve command's current output. Map each `echo` / `printf` call to a `lib/ui.sh` helper (or flag as needing a new helper).
- [ ] Add any missing helpers to `lib/ui.sh`. Keep the module backport-clean — no pyve-specific terms in helper names or logic.
- [ ] Retrofit one command at a time. Commit per command.
- [ ] Visual regression check: capture before/after terminal captures of each command's output. Save to `docs/specs/ux-retrofit-before-after/` for reviewer confirmation.
- [ ] Verify ANSI degradation: run each command with `NO_COLOR=1` and confirm no escape codes leak through.
- [ ] Run the full test suite — no regressions.

**Spec updates**

- [ ] `docs/specs/features.md` — document the unified UX contract (palette, symbols, prompt conventions) and reference `lib/ui.sh`.
- [ ] `docs/specs/tech-spec.md` — document `lib/ui.sh` helper signatures.
- [ ] `docs/site/usage.md` — update screenshots if any.

**CHANGELOG**

- [ ] v2.0.1 entry — unified CLI aesthetic.

**Backport note**

Once `lib/ui.sh` stabilizes, sync refinements back to `gitbetter` (where the original helper pattern lives). The `gitbetter` project's `tech-spec.md` "Shared Constants & Helpers" section is the current source of truth — keep the two in sync so the tools feel identical in the same terminal.

**Out of scope (deferred)**

- Pip output suppression beyond a single `--quiet` decision (richer streaming progress UI is Future).
- Rich / curses-style TUI — not happening. ANSI only.

---

### Story H.f.1: Retrofit `pyve init` to Unified UX [Done]

Adopt `lib/ui.sh` helpers throughout `init()` in [pyve.sh:481](../../pyve.sh#L481) and the routines it calls. This is the largest and most user-visible retrofit; the baseline ugly output is captured in the H.f umbrella above.

**Tasks**

- [x] Audit every `echo` / `printf` call inside `init()` and the helpers it invokes (purge sub-flow, environment build, gitignore writers, project-guide install prompt). Map each to a `lib/ui.sh` helper (`banner`, `info`, `success`, `warn`, `fail`, `confirm`, `ask_yn`, `divider`, `run_cmd`, `header_box`, `footer_box`); flag any output that needs a new helper.
- [x] Add any missing helpers to `lib/ui.sh`. (No additions needed — the existing palette covered every retrofit site.)
- [x] Wrap the run with `header_box "pyve init"` at entry and `footer_box` on success (both venv and micromamba terminal paths, plus the "update-in-place no env rebuild" early return).
- [x] Use `banner` for phase boundaries (Purge, Rebuild, Initializing Python environment, Initializing micromamba environment). Use `success` for per-artifact outcomes.
- [x] Replace the `Proceed? [y/N]` raw-printf prompt with `ask_yn` in the `--force` path. Interactive re-init 1/2/3 menu kept as raw printf (numbered choice, not yes/no).
- [x] Wrap the `python -m venv` invocation with `run_cmd` so the dimmed `$ cmd` echo is consistent. (`pip install` / `direnv allow` wrapping deferred — `pip install` lives in `prompt_install_pip_dependencies` which is cross-command territory for H.f.4; `direnv allow` is run by the user, not by init.)
- [x] Write failing bats tests in `tests/unit/test_init_ui.bats` — 3 tests: header at entry, NO_COLOR=1 no escapes on entry path, `--force` prompt migrated off raw `Proceed? [y/N]:`. Footer / phase banners / per-artifact success glyphs are verified visually (see H.f.5 capture step).
- [x] Run the full unit suite — 616 / 616 passing.
- [x] Run shellcheck on `pyve.sh` — zero new warnings (SC1091 info-level sourced-file notices unchanged from baseline).

**Deliverables**

- Updated `init()` and its callees in [pyve.sh](../../pyve.sh) (`init_python_version`, `init_venv`, `init_direnv_venv`, `init_direnv_micromamba`, `init_dotenv`, `init_gitignore`).
- New [tests/unit/test_init_ui.bats](../../tests/unit/test_init_ui.bats) (3 tests).
- No new helpers needed in [lib/ui.sh](../../lib/ui.sh).

**Out of scope (deferred)**

- `pyve purge` standalone retrofit (H.f.2).
- Error-path consistency sweep — `log_error` / `log_warning` from sub-validators (e.g., `validate_backend`) still emit the old `ERROR:` / `WARNING:` prefix. That's H.f.4.
- `prompt_install_pip_dependencies` and `run_project_guide_hooks` (both in `lib/utils.sh`) keep old-style output. Those are shared across multiple commands — retrofit lives in H.f.4.
- Visual regression captures and CHANGELOG (H.f.5).

---

### Story H.f.2: Retrofit `pyve purge` to Unified UX [Done]

Adopt `lib/ui.sh` helpers throughout `purge()` in [pyve.sh:1159](../../pyve.sh#L1159).

**Tasks**

- [x] Audit every `echo` / `printf` call inside `purge()` and helpers it invokes (`purge_version_file`, `purge_venv`, `purge_pyve_dir`, `purge_testenv_dir`, `purge_envrc`, `purge_dotenv`, `purge_gitignore`). Mapped each to a `lib/ui.sh` helper.
- [x] Wrap with `header_box "pyve purge"` / `footer_box`.
- [x] Use `ask_yn` for the destructive confirmation prompt. Skipped when `--yes` / `-y` passed (new flag), `CI=1`, or `PYVE_FORCE_YES=1`.
- [x] Added `--yes` / `-y` flag so internal callers (`init --force`, interactive option 2) skip the prompt without double-prompting. Updated both `purge --keep-testenv` call sites in `init()` to `purge --keep-testenv --yes`.
- [x] Use `success` for per-artifact removal lines (`purge_version_file`, `purge_venv`, `purge_pyve_dir`, `purge_testenv_dir`, `purge_envrc`, `purge_dotenv`, `purge_gitignore`); `info` for "no <artifact> found" cases; `warn` for `.env` preserved-because-not-empty.
- [x] Write failing bats tests in `tests/unit/test_purge_ui.bats` — 6 tests: header at entry, NO_COLOR=1 no escapes, abort preserves artifacts, `--yes` skips confirmation, footer renders on success, per-artifact ✔ glyph.
- [x] Run the full unit suite — 622 / 622 passing (6 new).
- [x] Run shellcheck on `pyve.sh` — zero new warnings.

**Deliverables**

- Updated `purge()` and helpers in [pyve.sh](../../pyve.sh) (`purge_version_file`, `purge_venv`, `purge_pyve_dir`, `purge_testenv_dir`, `purge_envrc`, `purge_dotenv`, `purge_gitignore`).
- New `--yes` / `-y` flag for `pyve purge`.
- New [tests/unit/test_purge_ui.bats](../../tests/unit/test_purge_ui.bats) (6 tests).

**Out of scope (deferred)**

- `unknown_flag_error` and other shared error helpers retain old format. → H.f.4.
- Documentation of the new `--yes` flag in `features.md` / `usage.md`. → H.f.5.

---

### Story H.f.3: Retrofit Legacy `testenv` and `python-version` Subcommands [Planned]

Apply the unified UX to the legacy command surface that H.e didn't rewrite — specifically the deprecated forms still emitted via `deprecation_warn` (e.g., `pyve testenv --install`, `pyve python-version`) and any non-rewritten subcommand bodies in `testenv_command()` ([pyve.sh:1316](../../pyve.sh#L1316)) and `python_command()` ([pyve.sh:1592](../../pyve.sh#L1592)).

**Tasks**

- [ ] Audit `testenv_command()` and `python_command()` for raw `echo`/`printf` calls (the new H.e subcommand bodies should already be tidy; focus on legacy paths and shared helpers).
- [ ] Apply `header_box` / `footer_box` per top-level invocation; `banner` per phase; `run_cmd` around external invocations.
- [ ] Confirm deprecation warnings still render via the existing `deprecation_warn` helper (do not double-wrap them in `warn`).
- [ ] Add bats tests in `tests/unit/test_testenv_ui.bats` and `tests/unit/test_python_ui.bats` covering header/footer, phase banners, and `NO_COLOR=1` cleanliness for at least one representative subcommand each.
- [ ] Run the full unit suite — no regressions.
- [ ] Run shellcheck — zero new warnings.

**Deliverables**

- Updated `testenv_command()` and `python_command()` (and any helpers they call) in [pyve.sh](../../pyve.sh).
- New `tests/unit/test_testenv_ui.bats`, `tests/unit/test_python_ui.bats`.

---

### Story H.f.4: Error Path Consistency Sweep + NO_COLOR Audit [Planned]

Cross-cutting cleanup once H.f.1 – H.f.3 land. Walks every error exit in `pyve.sh` and ensures the format matches the unified contract: red ✗ prefix via `fail`, single actionable next-step line.

**Tasks**

- [ ] Grep `pyve.sh` and `lib/*.sh` for raw `>&2` writes, bare `exit 1` after a printed error, and any `ERROR:` / `FATAL:` prefixes that pre-date `lib/ui.sh`. Replace with `fail` calls (or add a new helper if a pattern repeats — keep `lib/ui.sh` backport-clean).
- [ ] Verify each error message is actionable (names the offending input + the next step the user should take). Re-word terse errors.
- [ ] Run every top-level command with `NO_COLOR=1` and confirm zero ANSI escape codes leak through. Capture stdout+stderr per command into a temp scratch and grep for `\033` / `\x1b`.
- [ ] Decide pip/pyenv/mamba subprocess output policy: `--quiet` with our own progress line vs. full pass-through. Document the decision in `docs/specs/features.md` under the unified UX contract section (added in H.f.5).
- [ ] Add bats tests in `tests/unit/test_error_ui.bats` that assert: error messages exit non-zero, render with `${CROSS}`, and produce no escape codes under `NO_COLOR=1`.
- [ ] Run the full unit suite — no regressions.
- [ ] Run shellcheck — zero new warnings.

**Deliverables**

- Error-path replacements across [pyve.sh](../../pyve.sh) and [lib/](../../lib/).
- New `tests/unit/test_error_ui.bats`.

---

### Story H.f.5: v2.0.1 Release Wrap — Captures, Specs, CHANGELOG, Version Bump [Planned]

Final sub-story of the H.f umbrella. Ships the unified-UX retrofit as v2.0.1.

**Tasks**

- [ ] Capture before/after terminal recordings of each retrofitted command's output. Save to `docs/specs/ux-retrofit-before-after/`. (Before-shots come from git history pre-H.f.1; after-shots come from current `main`.)
- [ ] Update `docs/specs/features.md` — document the unified UX contract (palette, symbols, prompt conventions) and reference `lib/ui.sh`. Include the pip-output-policy decision from H.f.4.
- [ ] Update `docs/specs/tech-spec.md` — document `lib/ui.sh` helper signatures.
- [ ] Update `docs/site/usage.md` — refresh any screenshots that show old output.
- [ ] Backport-sync note: append a section to `docs/specs/tech-spec.md` (or the H.f.5 deliverables list) listing any `lib/ui.sh` enhancements added during H.f.1 – H.f.4 that should be pushed back to `gitbetter`'s `lib/ui.sh`.
- [ ] Bump version: `pyve.sh` `PYVE_VERSION`, any other manifest pinning the version. Confirm with `pyve --version`.
- [ ] Add `## [2.0.1] – 2026-MM-DD` entry to `CHANGELOG.md` summarising the unified-UX retrofit (link to H.f.1 – H.f.4).
- [ ] Mark H.f umbrella `[Done]` after this sub-story.
- [ ] Run the full test suite once more — no regressions.

**Deliverables**

- `docs/specs/ux-retrofit-before-after/` with captures.
- Updated `docs/specs/features.md`, `docs/specs/tech-spec.md`, `docs/site/usage.md`.
- v2.0.1 entry in `CHANGELOG.md`.
- Version bump in `pyve.sh`.

---

### Story H.g: v2.0.2 Reconcile Bootstrap Test Fixtures [Planned]

The existing skipped bootstrap integration tests reference CLI flags and helper methods that don't match the actual implementation. Fix the test scaffolding before activating tests. First story of the bootstrap-hardening sub-phase.

- [ ] Audit `test_bootstrap.py` test methods against actual CLI flags (`--auto-bootstrap`, `--bootstrap-to project|user`)
- [ ] Remove non-existent flag references (`bootstrap_url`, `micromamba_version`, `bootstrap_location` as a path)
- [ ] Add `init_micromamba()` helper method to `ProjectBuilder` in `tests/helpers/pyve_test_helpers.py`
- [ ] Verify `project_builder.create_environment_yml()` works correctly with bootstrap tests
- [ ] No skip removal yet — just fix the test code so it's ready

---

### Story H.h: v2.0.3 Activate Core Bootstrap Tests [Planned]

Activate the main `TestBootstrapPlaceholder` class tests that can run when micromamba is NOT pre-installed.

- [ ] Remove `@pytest.mark.skip` from `test_auto_bootstrap_when_not_installed`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_to_project_sandbox`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_to_user_sandbox`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_skips_if_already_installed`
- [ ] Fix assertions to match actual bootstrap output messages
- [ ] Verify: `pytest tests/integration/test_bootstrap.py::TestBootstrapPlaceholder -v -m micromamba` passes locally with micromamba available

---

### Story H.i: v2.0.4 Activate Bootstrap Error Handling Tests [Planned]

Activate failure-path tests.

- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_failure_handling`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_platform_detection`
- [ ] Remove `@pytest.mark.skip` from `TestBootstrapEdgeCases` class (`test_bootstrap_with_insufficient_permissions`, `test_bootstrap_cleanup_on_failure`)
- [ ] Fix assertions to match actual error output
- [ ] Verify: `pytest tests/integration/test_bootstrap.py::TestBootstrapEdgeCases -v` passes

---

### Story H.j: v2.0.5 Activate Bootstrap Configuration Tests [Planned]

Activate config-driven bootstrap tests.

- [ ] Remove `@pytest.mark.skip` from `TestBootstrapConfiguration` class
- [ ] Fix `test_bootstrap_respects_config_file` — reconcile config keys with actual `.pyve/config` format
- [ ] Fix `test_bootstrap_cli_overrides_config` — use actual CLI flags
- [ ] Verify: `pytest tests/integration/test_bootstrap.py::TestBootstrapConfiguration -v` passes

---

### Story H.k: v2.0.6 Remove Stale Bootstrap Skip from Micromamba Workflow [Planned]

Activate the single skipped bootstrap test in `test_micromamba_workflow.py`.

- [ ] Remove `@pytest.mark.skip` from `test_auto_bootstrap_micromamba` in `test_micromamba_workflow.py`
- [ ] Fix assertions to match actual behavior
- [ ] Verify: `pytest tests/integration/test_micromamba_workflow.py::TestMicromambaBootstrap -v` passes

---

### Story H.l: v2.0.7 Add Bootstrap CI Job [Planned]

Create a new GitHub Actions job that tests bootstrap without pre-installed micromamba — so the download and install paths are tested in automation.

- [ ] Add `integration-tests-bootstrap` job to `.github/workflows/test.yml`
- [ ] Job runs on `ubuntu-latest` and `macos-latest` (no `mamba-org/setup-micromamba` action)
- [ ] Job runs: `pytest tests/integration/test_bootstrap.py -v -m micromamba`
- [ ] Job requires network access (downloads micromamba binary)
- [ ] Verify: CI pipeline passes with new job

---

### Story H.m: v2.0.8 Bootstrap Download Verification [Planned]

Evaluate whether the bootstrap code verifies downloaded binaries and add verification if missing.

- [ ] Audit `bootstrap_install_micromamba()` for checksum or signature verification
- [ ] If missing: add SHA256 verification of downloaded micromamba binary
- [ ] Update `test_bootstrap_download_verification` assertions accordingly
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_download_verification`
- [ ] Remove `@pytest.mark.skip` from `test_bootstrap_version_selection` (if version pinning is supported)
- [ ] Verify: bootstrap tests pass with verification enabled

---

## Future

### Story I.?: Out of scope (from Story H.e)

- Retrofitting `pyve init` / `pyve purge` / other surviving commands to the new UX — covered by H.f.
- Removing (as opposed to deprecating) old flags — Future (Phase I).
- `pyve check --fix` auto-remediation — Future.

### Story I.?: Auto-Remediation for Diagnostics (`pyve check --fix`) [Planned]

After H.c / H.e ship `pyve check`, evaluate adding `--fix` for common auto-remediable issues (missing venv → run init, stale `.pyve/config` version → run update, missing distutils shim on 3.12+ → re-install, etc.). Deliberately deferred out of Phase H to keep the v2.0 scope focused on the diagnostic / status surface design — we want real usage data on the new `check` before deciding which fixes to automate and with what safety gates.

### Story I.?: Remove Deprecated Flags Introduced as Warnings in H.e [Planned]

H.e ships with deprecation *warnings* (not hard errors) on renamed flags / subcommands — likely `--update` flag, `testenv --init` / `--purge` flags, `python-version` (if renamed). After a sustained warning window across multiple minor releases, drop the old flags entirely. Almost certainly a major version bump (v3.0) depending on timing.

Not in Phase H because: the v2.0 breaking changes are already substantial; shipping hard-removes in the same release as renames denies users any migration window.

### Story I.?: Preemptive bash 3.2 compatibility audit across `pyve.sh`, `lib/`, and `lib/completion/` [Planned]

**Why.** macOS ships `/bin/bash` at 3.2.57. Every pyve release must source and execute cleanly there, but the repeated failure mode through Phase H (H.e.7a fixed `declare -A`; H.e.9h fixed `mapfile`) shows that bash 4+ features slip in whenever a contributor's dev shell is a newer bash from brew / asdf / nix. CI catches each instance, but only after a broken release reaches at least one user. A proactive audit + lint rule would shrink the failure mode.

**Scope (in):**

- **Full-repo scan** for bash 4+ constructs across `pyve.sh`, `lib/*.sh`, `lib/completion/*`, and any `tests/unit/*.bats` helpers. Target constructs:
  - Associative arrays: `declare -A`, `local -A`, and `typeset -A`.
  - `mapfile` / `readarray` builtins.
  - Case-modification parameter expansions: `${var^}`, `${var^^}`, `${var,}`, `${var,,}`.
  - `${var@…}` transformation operators (bash 4.4+).
  - `BASH_REMATCH` usage inside `[[ =~ ]]` when the regex relies on bash 4+ behavior.
  - `declare -n` namerefs (bash 4.3+).
  - `coproc` with named coprocs.
  - `**` globstar (requires `shopt -s globstar`, bash 4+).
- **Shared grep-invariant test** in a new `tests/unit/test_bash32_compat.bats`. Single file that greps the entire source tree for the constructs above and fails on any match. Each construct gets one `@test` block with a clear name (`"bash 3.2: no 'mapfile' calls in shell sources"`). Future contributors adding `mapfile` trip the invariant locally before CI.
- **Optional:** a `Makefile` target `make check-bash32` that sources every `lib/*.sh` under `/bin/bash` and reports any that fail. Complements the grep invariants with an "actually works" smoke.

**Scope (out):**

- Rewriting things that don't actually fail under bash 3.2 but use bash-4+-preferred idioms. Stay with the conservative "catch the true portability breaks; don't chase style".
- Adding a bash-3.2 matrix job to CI. macOS runners already use `/bin/bash` (3.2), so the existing CI job catches these once surfaced. The grep invariants catch them pre-commit.

**When to run this.** Not urgent; next time a bash-3.2 regression surfaces, or before the next major cut (v3.0). Earlier is better — each incident costs a CI cycle + a follow-up PR.

**Prior art:** H.e.7a (declare -A), H.e.9h (mapfile). Both fixes included individual grep invariants in their relevant test files; this story consolidates those + preempts the rest.

---
