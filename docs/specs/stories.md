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

### Remaining H.e sub-stories (placeholder — each becomes an 'H.e.N' story as it begins):
- [ ] Add deprecation warnings for every renamed flag/subcommand (match the `legacy_flag_error` pattern at [pyve.sh:2620-2631](pyve.sh#L2620-L2631) but as warnings, not exits).
- [ ] Update shell completion (`lib/completion/*`) for the new surface.
- [ ] Improve "unknown flag for this subcommand" errors — surface valid flags and closest match (`pyve init --purge` → "did you mean `--force`?").
- [ ] Write/update tests for every changed command.

**Spec updates**

- [ ] `docs/specs/features.md` — rewrite the command reference.
- [ ] `docs/specs/tech-spec.md` — document the new dispatcher layout, the finalized `lib/ui.sh` signatures, and the **semantic distinction between `check` (diagnostics; actionable; exit-code-bearing) and `status` (read-only state dashboard; no exit codes beyond 0)** per command. Ensure each command's `--help` text mirrors the same distinction — the help output is the user-facing contract.
- [ ] `docs/site/usage.md` — rewrite user-facing command reference.
- [ ] `docs/site/migration.md` — migration guide from the old surface (new file or section).

**CHANGELOG**

- [ ] v2.0.0 entry — breaking changes summary, renamed flags/commands, deprecation list.

---

### Story H.f: v2.0.1 Retrofit Remaining Commands to Unified UX (may split per command) [Planned]

Apply the `lib/ui.sh` pattern (introduced in H.e's first sub-story) to every pyve command that H.e did not rewrite. Goal: every pyve command looks and feels like the `gitbetter` commands — rounded-box header, consistent banners, confirmation prompts, dimmed command echo, outcome proof, rounded-box footer.

**Watch for complexity — split per command if this grows beyond a single focused change.** Likely split candidates: `pyve init`, `pyve purge`, `pyve testenv run` (if not rewritten in H.e), `pyve python-version` (or its successor). If split, subsequent phase letters shift.

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

---
