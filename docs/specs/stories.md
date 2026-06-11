# stories.md -- pyve (python)

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Put **`vX.Y.Z` in the story title only when that story ships the package version bump** for that release. Doc-only or polish stories **omit the version from the title** (they share the release with the preceding code story, or use your project’s doc-release policy). **One semver bump per owning story** — extra tasks on the *same* story share that bump; see `project-essentials.md`. Semantic versioning applies to the package. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see [`concept.md`](concept.md). For requirements and behavior (what), see [`features.md`](features.md). For implementation details (how), see [`tech-spec.md`](tech-spec.md). For project-specific must-know facts, see [`project-essentials.md`](project-essentials.md) (`plan_phase` appends new facts per phase). For the workflow steps tailored to the current mode (cycle steps, approval gates, conventions), see [`docs/project-guide/go.md`](../project-guide/go.md) — re-read it whenever the mode changes or after context compaction.

---

## Version Cadence

Standard semantic versioning, with these conventions:

- **Every story belongs to a phase.** Bugfix stories included. No orphan stories.
- **Per-story bumping** (when a story owns its own release):
  - Bugfix or trivial change → **patch** (`vX.Y.Z+1`)
  - Feature or improvement → **minor** (`vX.Y+1.0`)
  - Breaking change → **major** (`vX+1.0.0`). Post-1.0 only, and only via the `plan_production_phase` mode, which negotiates with the developer about whether the breakage is substantively user-facing or technically-but-trivially breaking (example: a log-format change is technically breaking, but if logs aren't a core consumer capability, the developer may judge it minor or even patch).
- **Phase-bundling option:** a phase can run unversioned during work and ship a single release/tag at end-of-phase. Stories within the phase carry no version in their title; the phase's last story owns the bump (magnitude determined by the highest-impact change in the bundle).
- **No out-of-order implementation.** Story order in this file is the order of execution. If work order needs to change, **reorganize/renumber here first** — don't skip ahead and create version-number gaps.
- **Pre-1.0:** standard semver applies; version starts at `v0.1.0` (Story A.a).
- **Post-1.0:** every phase must go through `plan_production_phase` (the lighter `plan_phase` is pre-1.0 only). Major bumps only happen through that mode's negotiation step.

This is the authoritative cadence rule. **Do not extrapolate the bump magnitude from `pyproject.toml`'s current version** — re-read this section whenever you're about to assign a version to a story.

---

## Phase O: UX visual refinement + hard migration gate + bugfixes and minor improvements (post-v3.0.0)

Begins **after v3.0.0 ships**, with the goal of shipping **v3.1.0**. Extends [lib/ui/](../../lib/ui/) with color and glyph primitives (TTY-detected, `NO_COLOR` respected); adds expand/collapse sections in `pyve check` / `pyve status` long-form output; structural lines between plugin sections in aggregated commands. **Migration hardening:** removes the v3.0 read-compat layer (from Story N.i); replaces the soft banner (from Story N.h) with the hard interactive gate — *"Pyve v2.x configuration is no longer supported. Ready to migrate to v3.x.x? [Y/n]"* — invoking `self_migrate()` on accept. Resolves **PC-5** (UX visual structure). Story breakdown deferred.

There may be random bugfixes and minor improvements interspersed within the stories below. 

---

### Story O.a: v3.0.4 `pyve migrate` clunkiness — `pyve self migrate` commits the entire `.v2-legacy` backup (`.gitignore` never covers `.pyve/` state) [Done]

**Discovered:** 2026-06-10, developer report — a migration commit dragged in 1000+ files (`.pyve/.v2-legacy/testenvs/testenv/venv/lib/python3.12/site-packages/_pytest/*.py`, the whole legacy testenv venv).

**Symptom.** After `pyve self migrate`, `git` wanted to track the entire moved legacy venv tree under `.pyve/.v2-legacy/`. `git check-ignore .pyve/.v2-legacy/testenvs/testenv/venv/bin/pytest` returned nothing → committable.

**Root cause — two facets of one gap (materialized `.pyve/` state not ignored):**

1. **Anchored gitignore patterns.** [`_gitignore_infra_block`](../../lib/gitignore_composer.sh) emitted `.pyve/envs` + `.pyve/testenvs`. A gitignore pattern carrying a non-trailing slash is **anchored to the path root**, so `.pyve/testenvs` matches `.pyve/testenvs` but **not** the nested `.pyve/.v2-legacy/testenvs/…` the migrator creates (nor `.pyve/bin/…`, the micromamba bootstrap's download dir — a latent twin of the same bug).
2. **Migrate never refreshes `.gitignore`.** [`self_migrate`](../../lib/commands/self.sh) moves legacy sources into `.pyve/.v2-legacy/`, then rebuilds by calling `init_project` **directly** — bypassing `compose_init`'s tail (`_compose_init_run_tail` → `compose_project_gitignore`) where the `.gitignore` recompose lives. `--no-rebuild` skips init entirely. So in **both** paths migrate created a fresh committable backup tree and left `.gitignore` byte-identical. Even after fixing the composer, a migrating project's stale v2 `.gitignore` would only gain coverage on a *later* `pyve init`/`update`, not during the migrate that creates the exposure.

**Why tests didn't catch it.** The composer suite asserted *which lines* get emitted, never that the emitted file actually *ignores* the materialized-state paths the migrator creates (a literal-line grep passes on the buggy enumerated form yet still misses the nested paths). No test exercised migrate's effect on `.gitignore` at all.

**Fix.** (1) Composer emits a single `.pyve/` (whole-tree ignore) — matches the documented invariant *"everything under `.pyve/` is materialized state, never config"*, and closes the `.pyve/bin/` gap in the same stroke. (2) `self_migrate` calls `compose_project_gitignore` right after the backup, **unconditionally** (covers `--no-rebuild` and rebuild), with a non-fatal warn on failure and a matching `--dry-run` plan line.

**Version:** v3.0.4 (patch) per Version Cadence.

**Tasks**

- [x] Reproduce (red): behavioral `git check-ignore` test in [test_gitignore_composer.bats](../../tests/unit/test_gitignore_composer.bats) — composed `.gitignore` must ignore `.pyve/.v2-legacy/…`, `.pyve/bin/…`, `.pyve/envs/…`; fails on the enumerated form.
- [x] Reproduce (red): end-to-end test in [test_self_migrate.bats](../../tests/unit/test_self_migrate.bats) — `pyve self migrate --no-rebuild` must leave the moved legacy venv git-ignored.
- [x] Fix composer: collapse `.pyve/envs` + `.pyve/testenvs` → `.pyve/` in `_gitignore_infra_block`.
- [x] Fix migrate: `compose_project_gitignore` after backup (unconditional) + `--dry-run` plan line.
- [x] Update the H.e.2a regression in [test_update.bats](../../tests/unit/test_update.bats): widen the exact-line `.pyve/envs` assertion to `.pyve/` (the contract changed; intent preserved and strengthened).
- [x] Prevention scan: closed the `.pyve/bin/micromamba` latent gap (now covered by `.pyve/`); swept tests/lib for other anchored `.pyve/{envs,testenvs}` gitignore-emit assertions (none beyond the two updated); no story-ID comments introduced (per project-essentials).
- [x] Full unit suite green (1944 tests, 0 failures); live `pyve self migrate` repro now prints `✔ Refreshed .gitignore (.pyve/ state ignored)` and the backup is ignored.
- [x] Update version in [pyve.sh](../../pyve.sh) to v3.0.4

---

### Story O.b: Extend the `.pyve/` gitignore-contract update across the integration suite + keep the emitted file clean (CI follow-up to O.a) [Done]

**Discovered:** 2026-06-10, CI on the O.a branch — `test_micromamba_workflow.py::test_gitignore_updated_for_micromamba` failed: `assert '.pyve/envs' in lines` no longer holds now that the composer emits a single `.pyve/`.

**Root cause.** O.a's prevention scan for old-contract gitignore-line assertions was scoped to `*.bats` / `*.sh` and never searched the pytest integration suite (which isn't run locally — it mutates real `$HOME`). Four integration assertions still encoded the pre-O.a enumerated-subdir contract (`.pyve/envs` / `.pyve/testenvs` as exact gitignore lines). Separately, O.a wrote its whole-tree rationale comment *inside* the composer heredoc, so those 5 rationale lines were being emitted into every user's generated `.gitignore` — and the embedded `.pyve/testenvs` text could false-pass a substring assertion.

**Fix.**
1. Update the four integration assertions to the `.pyve/` contract; convert the one substring check (`'.pyve/testenvs' in content_before`) to an exact line-membership check so the managed comment block can't false-pass it.
2. Move the rationale out of the heredoc into a source comment in `_gitignore_infra_block`, so the emitted `.gitignore` carries only `.pyve/` under `# Pyve-managed`.

**Version:** rides v3.0.4 (O.a owns the bump; no separate version).

**Tasks**

- [x] Fix the failing assertion + 3 siblings: [test_micromamba_workflow.py](../../tests/integration/test_micromamba_workflow.py) (1), [test_venv_workflow.py](../../tests/integration/test_venv_workflow.py) (3, incl. the substring→exact-line conversion).
- [x] Slim the emitted `.gitignore`: whole-tree rationale moved to a source comment outside the heredoc in [gitignore_composer.sh](../../lib/gitignore_composer.sh); verified the emitted block is `.pyve/` only (no `.pyve/{envs,testenvs}` leak into user output).
- [x] All-language prevention re-scan: swept `tests/` + `lib/` for any remaining exact `.pyve/{envs,testenvs}` gitignore-line assertions (none).
- [x] Unit suites green (composer / update / self_migrate, 68 tests); both edited Python test files compile; integration suite validated by CI (not run locally — real-`$HOME` hazard).

---

### Story O.c: `pyve self provision --status` — machine-readable hosting-readiness query (project-guide coordination seam) [Done]

**Motivation.** Other tools — project-guide first — need to know whether Pyve's global hosting is *ready* (toolchain venv runnable **and** the hosted `project-guide` shim runnable), without a project context and without reaching into Pyve's version-keyed, `XDG_DATA_HOME`-relative internal paths. Today the only hosting surface is the human-formatted, project-scoped `pyve check` ([`_compose_check_pyve_hosting`](../../lib/check_composer.sh#L115)); there is no scriptable query. The driving consumer is project-guide's **local-install warning**, which currently advises `pip uninstall project-guide` *unconditionally* — destructive when global hosting isn't provisioned (it reproduced on a machine whose `self provision` had hung per Story N.bv, leaving the `.venv` copy as the only working project-guide). The cross-repo design lives in [project-guide-requests/local-install-warning-readiness-gate.md](project-guide-requests/local-install-warning-readiness-gate.md); this story is the Pyve half — the stable query project-guide keys off. Naturally pairs with this subphase's **runnability-probe** pillar (existence ≠ runnability).

**Tasks**

- [x] Add `pyve self provision --status [--json]` ([lib/commands/self.sh](../../lib/commands/self.sh)) — read-only, side-effect-free, no network, no provisioning. (`self_provision_status`, a pure-reader leaf separate from `self_provision`.)
- [x] **Harden the `provision` dispatcher against unknown flags** ([self.sh:1094-1105](../../lib/commands/self.sh#L1094-L1105)): the `provision)` arm only special-cases `--help`, then falls through to `self_provision` for *anything else* — so `pyve self provision --status --json` against a Pyve that predates `--status` silently **re-provisions the whole toolchain** and returns `0`. That is the live root cause of project-guide's misbehavior (field-confirmed 2026-06-10): project-guide 2.15.0's read-only readiness probe re-creates hosting on *every* invocation and always reads exit 0 → false "global is active" + destructive `pip uninstall` advice, even immediately after `pyve self unprovision --all` (proof: the toolchain + shim reappeared, timestamped, right after the next `project-guide --version`). Make the arm **reject any unrecognized flag with a hard error (exit non-zero)** instead of falling through to a provision. Implementing `--status`/`--json` fixes the one flag we know about; this closes the class so a typo (`--stats`) or a future project-guide flag can't reopen the same trap. (Rewrote the arm as an explicit `case`: `--status` → status leaf; `--help` → help; bare `provision` → `self_provision`; anything else → `unknown_flag_error` — fall-through impossible by construction.)
- [x] Regression test: `pyve self provision <unknown-flag>` exits non-zero, prints an actionable error, and does **not** create `${XDG_DATA_HOME:-$HOME/.local/share}/pyve/toolchain` (assert the provision-free behavior, not just the exit code).
- [x] Exit-code contract: `0` = hosting ready (toolchain + hosted shim both **runnable**); `1` = Pyve-managed but not ready (never provisioned, or provisioned-but-broken); `2` = not Pyve-managed here (project owns project-guide via `.project-guide.yml` deps source, or hosting disabled).
- [x] **Runnability, not existence:** classify by *executing* the artifacts (`python --version`, `project-guide --version`) — never `[[ -x ]]` alone (a dangling shim / dead shebang passes existence and would falsely report "ready"). Reuse the `_compose_check_pyve_hosting` predicates (`pyve_toolchain_venv_dir`, `pyve_project_guide_is_hosted`), upgraded to the probe; honor the `PYVE_PROJECT_GUIDE_BIN` / `PYVE_PYTHON` overrides. (New shared probes `pyve_runnable_version` / `pyve_toolchain_runnable` / `pyve_project_guide_runnable` in [lib/toolchain_python.sh](../../lib/toolchain_python.sh); `_compose_check_pyve_hosting` now routes through them so `pyve check` and `--status` can't disagree.)
- [x] `--json` payload: `{ pyve_managed, toolchain:{provisioned,runnable,version}, project_guide:{hosted,runnable,version,shim} }`.
- [x] Bats coverage for all four states: ready / not-provisioned / provisioned-but-broken (dangling shim + dead-shebang interpreter) / not-managed; assert the probe fires (not a stat). ([tests/unit/test_self_provision_status.bats](../../tests/unit/test_self_provision_status.bats), 16 tests; + 2 runnability tests in [test_pyve_hosting_diagnostic.bats](../../tests/unit/test_pyve_hosting_diagnostic.bats).)
- [x] Document the `--status` exit-code + JSON contract in [project-essentials.md](project-essentials.md) alongside the `.project-guide.yml` and hosting entries; note it as a cross-repo contract project-guide pins a minimum Pyve version against.
- [x] After project-guide ships the readiness-gated warning, pin `project-guide ≥ <release>` and close the loop (consumer-side handled in project-guide; Pyve only provides the query). Already shipped in `project-guide` v2.15.0. (Bumped the pyve-hosted install floor `project-guide>=2.13.0` → `>=2.15.0` in [self.sh](../../lib/commands/self.sh) + [toolchain_python.sh](../../lib/toolchain_python.sh).)
- [x] Wire the detector into CI to enforce the guard on new refs. (The behavioral regression tests in `test_self_provision_status.bats` — unknown-flag-never-provisions + the four-state exit-code contract — run in CI's existing unit-suite job; a regression that reopens the fall-through fails CI. No separate static-grep guard added — the behavioral test is strictly stronger.)

**Implementation notes.**

- **Dispatcher shape that makes the fall-through impossible by construction.** Rewrite the `provision)` arm ([self.sh:1094-1105](../../lib/commands/self.sh#L1094-L1105)) so the order is: `--status` (with optional `--json`) → the read-only status path; `--help`/`-h` → `show_self_provision_help`; **any other flag (leading `-`) → hard error, exit non-zero** (mirror the `legacy_flag_error` shape already used elsewhere in `pyve.sh`); bare `provision` (no args) → `self_provision`. With the explicit unknown-flag arm in place, no flag can reach `self_provision` by accident — the only way to provision is the no-arg form. Keep the `PYVE_DISPATCH_TRACE` early-return where it is.
- **`--status` must be a leaf that never provisions.** Implement it as its own function (e.g. `self_provision_status`), not a branch inside `self_provision` — `self_provision` is "best-effort, always returns 0" and unconditionally calls the three `_self_install_*` helpers, which is exactly the side effect to avoid. The status leaf only *reads*.
- **Share the runnability predicate with `pyve check`, don't fork it.** [`_compose_check_pyve_hosting`](../../lib/check_composer.sh#L115) today decides "provisioned" on `[[ -x "$venv_dir/bin/python" ]]` ([check_composer.sh:121](../../lib/check_composer.sh#L121)) — pure existence, which passes for a dangling shim / dead-shebang interpreter (the existence≠runnability trap this subphase targets). Factor a single runnable-probe helper (e.g. `pyve_hosting_runnable` that executes `python --version` + `project-guide --version` and classifies the failure) and have **both** `--status` and `_compose_check_pyve_hosting` call it, so the JSON query and the human `pyve check` can never disagree about what "ready" means. Honor `PYVE_PROJECT_GUIDE_BIN` / `PYVE_PYTHON` in the probe.
- **Exit-1 vs exit-2 for a project with a local pip copy** (a client example repro): decide deliberately. If pyve considers project-guide "managed by your project" there (the `.project-guide.yml` deps-source branch `_compose_check_pyve_hosting` already distinguishes), `--status` should return `2` (silent — project owns it); otherwise `1` (managed-but-not-ready). Either way the destructive exit-0 path is closed; the choice only affects whether project-guide stays silent or offers readiness guidance.

---

### Story O.?: General housekeeping + Homebrew update formula validation + CLI install/upgrade improvements [Planned]

- [ ] *(housekeeping)* Consider a general "non-interactive guard" so any future prompt auto-declines without a TTY rather than relying on per-callsite `[[ -t 0 ]]` — fits **Phase P: Harden and heal Pyve** alongside the runnability-probe / `pyve heal` work, not needed for v3.0.0.
- [ ] *(housekeeping)* Add an integration smoke that drives the brew `post_install` shape (`PYVE_FORCE_YES` unset, stdin a non-TTY, pinned version absent) and asserts `self provision` exits without hanging — deferred to Phase P (local integration runs mutate the real `~/.local`/`~/.asdf`, a documented hazard).
- [ ] **Revisit before Homebrew 6.0 / 5.2** removes `HOMEBREW_NO_REQUIRE_TAP_TRUST`. By then the path is one of: the `dawidd6` action grows native trust handling; Homebrew ships a non-interactive `brew trust`; or we write `trust.json` directly. Forward-compat is deferred, not solved.
- [ ] Audit `update-homebrew.yml` against the v3 surface: any renamed commands, new files, or `caveats` text the formula references that changed across Phase N.
- [ ] Confirm the formula's test/install block exercises a v3 smoke path (`pyve init` / `pyve --version`) rather than a retired v2 command.
- [ ] *(housekeeping)* Stale comments referencing "lib/utils.sh's gitignore template" ([test_testenvs_activate.bats:15](../../tests/unit/test_testenvs_activate.bats#L15), [test_state_layout.bats:165](../../tests/unit/test_state_layout.bats#L165)) point at the pre-composer emitter; refresh to name `lib/gitignore_composer.sh` when next touching those files.

---

### Story O.?: box commands print `✔ All done.` even when the command failed (`footer_box` is status-blind) [Planned]

**Discovered:** 2026-06-08 smoke test (`pyve env install` and `pyve env init testenv` on a `.git`-only `pyve-v3-smoke`).

**Symptom.** A failed box command renders its `✘` error and then a green success footer directly beneath it:

```
$ ../pyve/pyve.sh env init testenv
  ╭─────────────────────────────────────────╮
  │  pyve env                               │
  ╰─────────────────────────────────────────╯
  ▸ Creating dev/test runner environment in '.pyve/envs/testenv/venv'...
  ✘ Cannot resolve 'python' — version-manager shim has no version pinned for this directory.
  ✘ This directory isn't an initialized Pyve project.
  ✘ Run 'pyve init' to set one up.
  ╭─────────────────────────────────────────╮
  │  ✔ All done.                            │   ← contradicts the ✘ errors above
  ╰─────────────────────────────────────────╯
```

The process exit code is correct (non-zero); only the visual footer lies.

**Root cause — `footer_box` is hardcoded to success.** [`footer_box`](../../lib/ui/core.sh#L141-L145) unconditionally prints `✔ All done.` with no status parameter, and every namespace/composer dispatcher calls it before returning the real result — e.g. [env.sh:1314](../../lib/commands/env.sh#L1314) does `footer_box` then `return "$leaf_rc"`. So whenever a leaf fails, the user sees the error *and* a green "done" box. Affected callsites (~11): [env.sh:1223](../../lib/commands/env.sh#L1223) (sync) + [env.sh:1314](../../lib/commands/env.sh#L1314), [self.sh:912](../../lib/commands/self.sh#L912) + [self.sh:939](../../lib/commands/self.sh#L939), [init_composer.sh:197](../../lib/init_composer.sh#L197), [purge_composer.sh:153](../../lib/purge_composer.sh#L153) + [purge_composer.sh:240](../../lib/purge_composer.sh#L240), and the python plugin ([plugin.sh:643](../../lib/plugins/python/plugin.sh#L643), [1763](../../lib/plugins/python/plugin.sh#L1763), [2393](../../lib/plugins/python/plugin.sh#L2393), [2724](../../lib/plugins/python/plugin.sh#L2724)).

**Proposed fix (decide during debug).** Make `footer_box` status-aware: `footer_box [exit_code]` — `0`/absent renders today's `✔ All done.` (backward-compatible default); non-zero renders a failure variant using the existing `CROSS` glyph + red (`R`) box (e.g. `✘ Failed.`). Thread the real result through each dispatcher that already computes one (`env_command`'s `leaf_rc`, `self_command`, the composers, the plugin paths) — `footer_box "$leaf_rc"`. Callsites with no meaningful failure path at that point keep the no-arg success default. The UI primitive stays pyve-agnostic per the `lib/ui/` boundary invariant.

**Out of scope.** Broader N-10 UX visual refinement beyond the success/failure footer (spacing, color theming, box width); changing any command's exit code or error text; suppressing the footer entirely on failure (the decision here is a *failure* footer, not *no* footer — revisit only if a cleaner shape emerges during debug).

**Tasks**

- [ ] Reproduce (red): a failed box command (e.g. `env init` on an uninitialized project, or any dispatcher with a non-zero leaf) emits `✔ All done.`. Assert the success footer is present on failure (red), then absent after the fix.
- [ ] Make `footer_box` accept an optional exit code; non-zero → failure variant (`CROSS` + red box); zero/absent → unchanged success footer. Keep it pyve-agnostic (extend the `lib/ui/` boundary test if needed).
- [ ] Thread the computed result code into `footer_box` at every dispatcher/composer callsite that has one; verify no-arg callsites still render success.
- [ ] Test: success path still shows `✔ All done.`; failure path shows the failure footer and never `✔ All done.`; exit codes unchanged.
- [ ] Full suite; zero regressions. Re-run the `pyve env init testenv` smoke on an uninitialized dir to confirm the footer matches the outcome.

---

## Future

## Phase P: Harden and heal Pyve

Note: there are several stories in `## Future` that need to be reviewed and considered whether to include in this Subphase

Begins after the v3.0.0 / v3.1.0 release line (exact tag TBD during planning). Theme: make Pyve's environment resolution **bulletproof**, and — when the armor is pierced — give Pyve a **healing mechanism**. This is the "calm the chaos" mission applied to Pyve's own substrate: the developer should never have to hand-trace PATH order, version-manager pins, and venv symlinks to understand why a command misbehaves, and never have to hand-repair Pyve-managed state.

**Triggering incident (field-discovered 2026-06-09).** A developer's `project-guide` invocation in the pyve repo broke with a cryptic `No version is set for command project-guide` naming a Python `3.14.3` they could not place. Untangling it took a long manual trace across **four independent layers**, none of which any Pyve command could see or explain:

1. **PATH shadowing.** `python` reported 3.14.4 while `.tool-versions` pinned 3.12.13 — because direnv had prepended an activated `.venv/bin` ahead of `~/.asdf/shims`, so the asdf pin never governed `python` at all. `project-guide`, present in neither `.venv` nor `~/.local/bin`, fell through to the asdf shim where the 3.12.13 pin *did* apply — and 3.12.13 had no project-guide.
2. **Interpreter drift.** The `.venv` python was a frozen symlink to asdf 3.14.4 (its creation-time interpreter), drifted from the now-3.12.13 pin — a venv never tracks later `.tool-versions` edits.
3. **Dead Pyve-managed artifacts.** `~/.local/bin/project-guide` was a dangling symlink, and the hosted toolchain venv's `project-guide` had a `bad interpreter` shebang — both pointing at a deleted path. Yet both passed Pyve's existence checks.
4. **The 3.14.3 mystery.** project-guide 2.12.0 happened to be pip-installed into one asdf interpreter (3.14.3); asdf surfaced that version number in its rejection message, with no context a human could decode.

**Core anti-pattern to eliminate: existence ≠ runnability.** Pyve's health/hosting code asserts that artifacts *exist* (`-x` / `-f` / `-d`) rather than that they *run*. The canonical trap: [`_compose_check_pyve_hosting`](../../lib/check_composer.sh#L121) reports `project-guide hosting: provisioned` on `[[ -x "$venv_dir/bin/python" ]]`, which passes for a venv whose python symlink targets a deleted interpreter. Story N.bo began the correction at the project-guide resolver (a runnability-honoring `PYVE_PROJECT_GUIDE_BIN` override seam); this subphase generalizes it across the codebase.

**Design pillars (planner to decompose into stories).**

1. **Runnability probes.** Replace existence checks throughout hosting/health code with probes that actually execute the artifact (`python --version`, `project-guide --version`, version-manager resolution) and classify the failure: dead interpreter, asdf "no version set", dangling symlink, missing command, version-manager-not-installed. A health check that can be fooled by a broken symlink is not a health check.
2. **Resolution reasoning in `pyve check`.** Turn the manual trace into automated narrative: for each managed command, report *where* it resolves and *why* — PATH-slot ordering, venv-shadows-pin, reachability under the active pin, venv↔pin interpreter drift — in the plain language a human had to reconstruct by hand. `check` should have said, unprompted: "`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13); `project-guide` falls through to the asdf shim under that pin, which has no project-guide → install it into 3.12.13 or repoint the pin."
3. **Healing mechanism (`pyve heal`, or `pyve check --fix`).** Safe, idempotent, **confirm-before-destroy** repairs for every failure class the probes detect: rebuild a toolchain venv with a dead interpreter; re-link a dangling `~/.local/bin` shim; rebuild a `.venv` whose interpreter drifted from the pin (destructive → explicit confirmation); install a missing managed command into the *selected* interpreter. Reversible and re-runnable; never silently mutates without surfacing what it will do.
4. **Close the upstream cause — the test-isolation leak.** The triggering incident was *manufactured by Pyve's own test suite*: [`_isolate_home`](../../tests/integration/test_project_guide_integration.py#L211-L217) (integration harness) symlinks the developer's **real** `~/.asdf` and `~/.local` into the test's fake `$HOME`, so any project-guide/toolchain-provisioning test writes hosting artifacts into real developer state — which dangles when the test's tmpdir is cleaned up. Re-scope `_isolate_home` so the suite can never again mutate a real home (provision into a fully self-contained fake `$HOME`, or stub provisioning entirely). N.bo's `PYVE_PROJECT_GUIDE_BIN` seam closes one path; the version-manager (`.asdf`) and self-install paths remain open.

**Scope notes.** `lib/ui/` primitives stay pyve-agnostic (the lib/ui boundary invariant). Healing never destroys without explicit confirmation. Builds on Story N.bi (check hosting/toolchain surfacing), Phase O (check/status expand-collapse long-form output), and Story N.bo (runnability override seam + the existence-vs-runnability framing). Ships in the Phase N v3.x line; the exact release tag and the full story breakdown are deferred to this subphase's `plan_production_phase` session.

---

### Story ?.?: Bash Coverage (kcov) job uploads only unit-test coverage — integration `kcov-merged` never produced [Planned]

**Discovered:** 2026-06-10, reviewing CI logs (`Bash Coverage (kcov)` job, run 73345921989). The job is **green**, so this is latent, not a failure.

**Symptom.** The Codecov upload step in the `bash-coverage` job ([.github/workflows/test.yml](../../.github/workflows/test.yml)) is configured to send two files but only one exists:

```
--file ./coverage-kcov/bats/cobertura.xml        ← exists, uploaded
--file ./coverage-kcov/kcov-merged/cobertura.xml  ← never created
warning -- No coverage data found to transform
warning -- Some files were not found --- {"not_found_files": ["coverage-kcov/kcov-merged/cobertura.xml"]}
```

The job stays green only because the Codecov step sets `fail_ci_if_error: false`. Net effect: **only the bats unit-test bash coverage reaches Codecov; the integration + micromamba kcov passes contribute nothing**, silently under-reporting bash coverage. (The same job's large log volume is benign — echoed test stdout, the pyve box UI, and apt install chatter — not part of this ticket. The `xcrun is not installed` / `No gcov data found` lines are harmless Codecov-uploader platform probes.)

**Suspected root cause (confirm during debug).** The two integration steps set `PYVE_KCOV_OUTDIR="$(pwd)/coverage-kcov"` ([test.yml:290](../../.github/workflows/test.yml#L290), [:317](../../.github/workflows/test.yml#L317)) and route pyve.sh through [tests/helpers/kcov-wrapper.sh](../../tests/helpers/kcov-wrapper.sh) via [tests/helpers/pyve_test_helpers.py:137-140](../../tests/helpers/pyve_test_helpers.py#L137-L140). Yet at upload time only `coverage-kcov/bats.<hash>/` was present — no per-invocation pyve.sh dataset and no `kcov-merged/`. Likely the wrapper's writes don't land in the repo-root `coverage-kcov/` (relative-path / cwd resolution inside each test's tmpdir), or kcov isn't producing a merged dataset from those runs.

**Tasks**

- [ ] Reproduce: run the `bash-coverage` job's three kcov steps locally (or in CI) and inspect what lands under `coverage-kcov/` — confirm whether the integration/micromamba passes write any pyve.sh kcov dataset at all.
- [ ] Root-cause why `coverage-kcov/kcov-merged/` is absent: wrapper writing to the wrong dir (per-test cwd), `PYVE_KCOV_OUTDIR` not propagating to the pyve.sh subprocess, or kcov not auto-merging single datasets.
- [ ] Fix so the integration-path bash coverage is produced and uploaded (correct outdir, or generate `kcov-merged` explicitly), and the Codecov `not_found_files` warning clears.
- [ ] Optional polish: quiet the apt provisioning chatter (`-qq` / `DEBIAN_FRONTEND=noninteractive`) and decide whether to suppress verbose test stdout in the coverage job — cosmetic, do only if it aids log triage.

---

### Story ?.?: Fix pre-existing integration test failures [Planned]

**Motivation**: surfaced during story K.a.1 regression sweep. One test in [tests/integration/](../../tests/integration/) fails against `main` unrelated to any in-flight change; it is a flaky timeout. Pinning this now so it doesn't mask real regressions in future `make test-integration` runs. Confirmed still problematic in story N.s.9 and again in N.bg.

**Tasks**

- [ ] `test_cross_platform.py::TestPlatformDetection::test_python_platform_info` — `subprocess.TimeoutExpired` on a short `python -c` invocation. Likely environmental (cold asdf shim, Python install triggered by test harness). Add a pre-warm step or bump the timeout if the root cause is benign.
- [ ] Re-run `make test-integration` after fixes; expect zero failures on a clean checkout.

### Story ?.?: Complete phase/story-ref comment sanitization (deferred from N-7) [Planned]

**Motivation.** N.bd / N.bd.1 swept the conspicuous `# Story N.x` refs (Phase N). The broader all-phase sweep — bare `X.y` refs, `Story M.x`/`J.x`/etc. forms, `Phase`/`Subphase` pointers — was scoped, tooled, and partially auto-cleaned, then **deferred: release functionality (N-8/N-9) outranks comment cosmetics, and the project-essentials guard "No story / phase IDs in code or comments" already stops *new* refs.** This story finishes it when convenient. Full findings, scale (688 candidate lines, all phases), the behavioral-attractor rationale, and the **safe-pattern taxonomy** live in [phase-n-7-audit.md](phase-n-7-audit.md) § 5.

**State at deferral.** First-pass `clean.txt` had 198/688 auto-cleaned (whole-storynum parens deleted; `Story X.y:` prefixes stripped; ` landed` handled; storynum pairs in mixed text marked `XXXX`); 490 left `clean==dirty` (mostly bare single refs in running prose — judgement cases — plus the 20 load-bearing KEEPs). **Nothing applied to source.** Tooling: [`audit_phasestory_refs.py`](../../audit_phasestory_refs.py) (detector / CI-guard candidate) + [`clean_phasestory_refs.py`](../../clean_phasestory_refs.py) (cleaner); the `*_dirty.txt` / `*_clean.txt` are regenerable output.

**Tasks (when resumed)**

- [ ] Per-line judgement on the ~490 `clean==dirty` bare-single refs: strip / rephrase-to-name-the-thing / `[implementation story]` / `<<<DELETE>>>` / keep — preserving load-bearing exceptions (`v3.0-only: remove in N-10`, `BOUNDARY`, `N.i-pending`, `F<n>` labels).
- [ ] Resolve the `XXXX` pair markers into final content.
- [ ] Decide scope: Phase-N-only vs all-phase (the 416 older-phase refs are pre-Phase-N historical context).
- [ ] Write the dumb line-by-line applier (parse `clean.txt`; replace source `path:lineno` with content; `<<<DELETE>>>` removes the line; bottom-up per file) and apply.
- [ ] Diff-review the full source change (comments-don't-execute — the only prose-quality net) + run the full suite; zero regressions.

### Story ?.?: Reconcile tech-spec.md command/module tables to the v3 plugin file-layout [Planned]

**Raised:** 2026-06-09 (developer, during the N.bq tech-spec cascade).

**Motivation.** The N.bq pass (Subphase N-8) consolidated the plugin region of [tech-spec.md](tech-spec.md) into one `## Plugin layer` section, stripped header archeology, refreshed the enumerated v2 remnants (`pyve.toml`, `.pyve/envs/`, `env` namespace, version globals), and repointed cross-refs — but **deliberately left the deeper file-layout drift** in the `## Key Component Design` command/module tables. Those tables' *behavior/signature* descriptions are still accurate; their *file locations* and inline story refs are stale relative to the v3 relocation: `init`/`purge`/`update`/`check`/`status`/`run`/`test` and the `python` namespace now live in [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh); `lib/testenvs.sh` → `lib/envs.sh`; `lib/commands/testenv.sh` → `lib/commands/env.sh`; `lib/commands/` retains only `env.sh` / `lock.sh` / `package.sh` / `self.sh`. A stopgap v3.0 file-layout orientation note was added at the section head; this story removes the need for it.

**Why deferred.** N.bq was scoped as a *targeted in-place refactor*, not a regenerate — a full rewrite of the ~240-line command-table block risked dropping correct technical detail for no release benefit, and release functionality (N-9) outranks doc-table reconciliation. The orientation note keeps the doc honest in the interim. This pairs with the **"Complete phase/story-ref comment sanitization"** Future story above (same story-ref archeology, different surface — code comments there, spec-doc tables here) and could be bundled into one doc/ref-cleanup pass.

**Tasks (sketched; refine when picked up).**

- [ ] Reconcile the `### lib/commands/<name>.sh — Command Implementations` block to the v3 layout: relocate/cross-link the Python command function tables under the Plugin layer's `### Python plugin`, and keep only `env` / `lock` / `package` / `self` as `lib/commands/` residents. Remove the stopgap orientation note once done.
- [ ] Strip inline `Story X.y` / `Phase`/`Subphase` refs from the function-table bodies (`lib/envs.sh`, `lib/manifest.sh`, the command tables, the `lib/utils.sh` / `lib/version.sh` notes), preserving load-bearing markers (`v3.0-only: remove in N-10`, `BOUNDARY`, `N.i-pending`, `F<n>`).
- [ ] Fix the `## Package Structure` tree (`tech-spec.md` ~L50): drop the deleted `lib/commands/{init,purge,update,check,status,run,test,testenv,python}.sh` and `lib/testenvs.sh` / `pyve_testenvs_helper.py`; add `lib/plugins/**`, `lib/*_composer.sh`, `lib/envs.sh`, `lib/manifest.sh`, `lib/toolchain_python.sh`, `lib/project_guide.sh`, `pyve.toml`.
- [ ] Fix the `### pyve.sh — Thin Entry Point` sourcing-order paragraph: it still enumerates deleted command files and a "~500–650 lines post-K.l" framing; replace with the actual v3 source order (helpers → `manifest.sh` → registries → plugins → composers → `env`/`lock`/`package`/`self`).
- [ ] Diff-review against the live codebase; confirm no surviving reference to a deleted file or non-existent function.

---

### Story ?.?: Finish the v3 site — drop v2 spellings in usage/testing + document the env planning/sync workflow [Planned]

**Raised:** 2026-06-09 (developer, after the N.br site refresh).

**Motivation.** N.br (Subphase N-8) refreshed the public site and README for v3 — new pages (`pyve-toml`, `environments`, `plugins`, `polyglot`, `packaging`), a v2→v3 `migration.md`, and full v3 passes on `index` / `getting-started` / `ci-cd` / `backends` / `README`. Two follow-ups were scoped out of N.br to avoid a rushed mechanical edit and surfaced a real content gap:

1. **`usage.md` and `testing.md` got v3 *orientation* passes, not full rewrites.** Their intros, command overviews, and the two-env-model table are v3, and each carries a prominent note mapping `pyve testenv`→`pyve env`, `.pyve/testenvs/`→`.pyve/envs/`, and `[tool.pyve.testenvs]`→`[env.<name>]`. But their **lower-body examples still use the v2 spellings** (~37 in usage, ~60 in testing). The old forms resolve (the `testenv` alias works; legacy paths migrate opportunistically), so nothing is *broken* — but the running examples should be canonical v3.
2. **The environment planning/sync workflow is undocumented, and `pyve env sync` was omitted from the command references.** The site documents declaring `[env.<name>]` by hand / via `init` / via `migrate`, but **not** the `project-guide mode plan_envs` → `pyve env sync` → `pyve.toml` loop that is the intended "configure your environments" path. `pyve env sync` (shipped: N.az.2 / N.ba) is missing from `environments.md` / `usage.md` / `README` command lists, and the `pyve check` env-spec **drift** surface is undocumented.

**Tasks**

*Group A — drop the v2 spellings (mechanical sweep).*

- [ ] **`usage.md`** — convert the lower-body Command Reference examples: `pyve testenv …` → `pyve env …`, `.pyve/testenvs/<name>/` → `.pyve/envs/<name>/`, `[tool.pyve.testenvs]` → `pyve.toml`'s `[env.<name>]`. Fix the `#testenv-subcommand` anchor/link references. Keep one explicit "`pyve testenv` is a deprecated alias (removed v4.0)" note; make every running example canonical.
- [ ] **`testing.md`** — same sweep across the lifecycle / named-test-env / activation-context / backend-deltas sections; rewrite the `[tool.pyve.testenvs]` worked examples as `pyve.toml` `[env.<name>]` blocks; fix the `.pyve/testenvs/testenv/venv` and `.pyve/envs/<name>/` path references in "Backend deltas".
- [ ] Re-run the link/anchor check; confirm no dead `#…` fragments after the rename.

*Group B — document the planning/sync workflow (new content; the gap).*

- [ ] **Add `pyve env sync` to every command reference** where it's missing (`environments.md`, `usage.md`, `README.md`): discover the spec → diff vs the current `pyve.toml` → `[Y/n]` apply (default `Y`; **destructive** drops/backend-flips default `N`); writes `pyve.toml` only, never materializes; note exit `6` (spec invalid under the closed vocabulary).
- [ ] **Add a "Planning environments with project-guide" section** to `environments.md` (with pointers from `getting-started.md` / `usage.md`): `project-guide mode plan_envs` authors `docs/specs/env-dependencies.md` §4 (the analyzed-*ideal* env config at the current `spec_version`) → `pyve env sync` reconciles it into `pyve.toml` → lifecycle commands materialize. Explain the *why*: one declarative source of intent; the spec may legitimately run ahead of what's materialized.
- [ ] **Document the `pyve check` env-spec drift surface** — non-empty §4-vs-`pyve.toml` diff → **warn (exit 0)**, with the "run `pyve env sync` to reconcile" hint; note Pyve reads `env_spec_path` from `.project-guide.yml` (default `docs/specs/env-dependencies.md`).
- [ ] **Document the projectable subset** that syncs/diffs (`name`, `purpose`, `backend`, `default`, `path`, `languages`, `frameworks`, `packaging`) vs. advisory/prose that never triggers drift (`app_type`, `require_min_version`, `manual_steps`, §5–§9 narrative).
- [ ] **Link, don't duplicate** — reference the env-spec contract (`project-guide-requests/wizard-env-contract.md`) rather than re-deriving the vocabulary; keep roadmap surfaces honest.

---

### Story ?.?: Deeper TypeScript integration for the Node plugin [Planned]

**Motivation**: Phase N's Subphase N-3 shipped the Node plugin with **advisory-only** TypeScript support — `languages = ["typescript"]` is read and surfaced in `pyve check` (warn if the attribute is set but `typescript` is not in `package.json` deps), but Pyve does no deeper TS-aware behavior. The deferral was deliberate (avoid bogging N-3 in scope) but the richer integration is the natural next step once N-3 ships.

**Why deferred**: in N-3, the contract-generalization proof was the priority — implementing the Node plugin against the contract Python uses, with one new ecosystem and one framework (SvelteKit) as the scope. TypeScript-specific behavior (tsconfig.json detection, suggested `tsc --noEmit` invocations, type-check hooks, etc.) would have stretched N-3 substantially. Picking it up as a standalone story after N-3 ships keeps each subphase tight.

**Tasks** (sketched; refine when picked up):

- [ ] Detect `tsconfig.json` in the Node plugin's `pyve_plugin_detect` hook; surface presence as a structured signal (e.g., a `typescript` framework attribute, or extend the `languages` semantics).
- [ ] Suggested type-check invocations in `pyve check`: if `tsconfig.json` present, advise `pyve env run <provider> tsc --noEmit` for type-checking; advisory only, no enforcement.
- [ ] Optional `pyve test` enrichment: when TS is configured, optionally pre-flight `tsc --noEmit` before delegating to the user's test script. Gate behind an opt-in flag or env field (e.g., `[env.web] typescript_check_before_test = true`) so the existing honest-passthrough behavior from N.x stays the default.
- [ ] Update [features.md](features.md) and [tech-spec.md](tech-spec.md) for the deeper TS handling.
- [ ] Decide whether this is a Node-plugin-internal change (TS lives inside the Node plugin's hooks) or a generalized "language flavor advisory" pattern that future plugins (Kotlin on JVM, mypy on Python, etc.) inherit. The latter generalizes; the former is tighter scope.

---

### Story ?.?: Per-leaf help functions for namespace commands (`testenv`, `python`, `self`) [Planned]

**Motivation**: today the three namespace commands (`testenv`, `python`, `self`) keep all their help text in a single `--help` heredoc inside the namespace dispatcher (e.g. `testenv_command`'s `--help|-h` arm). As leaves accumulate flags and shape variants — M.i.2 added `--` separators for `run`, M.i.3/M.i.4 added `[<name>]` and `--force` — the single-block help grows unwieldy and per-leaf detail gets cramped.

Per the *Per-command help blocks live with their commands* rule in [project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md), each leaf would get its own `show_<namespace>_<leaf>_help` function inside the same `lib/commands/<namespace>.sh` file (single-file namespace rule preserved). Invocation: `pyve testenv init --help` would call `show_testenv_init_help`, leaving the namespace `--help` as a top-level overview that points at the per-leaf forms.

**Why deferred**: this is a refactor that touches every namespace command's dispatcher. The right time to do it is when one of the namespaces grows enough leaves that the single heredoc becomes painful — `testenv` is approaching that point with M.i, but no leaf has so much detail that the current shape is broken. Doing it as a standalone story keeps the testenv-DX bundle scoped to feature work.

**Tasks** (sketched; refine when picked up):

- [ ] Per-leaf `show_<namespace>_<leaf>_help` functions in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) (`init`, `install`, `purge`, `run`, plus M.p's future `list`/`prune`), [lib/commands/python.sh](../../lib/commands/python.sh), [lib/commands/self.sh](../../lib/commands/self.sh).
- [ ] Dispatcher routes `pyve <namespace> <leaf> --help` to the per-leaf help function.
- [ ] Namespace `--help` retained as an overview that lists leaves + one-liner per leaf + a pointer to `pyve <namespace> <leaf> --help` for detail.
- [ ] Existing direct-command per-leaf helps (`show_init_help`, etc.) are unchanged — this story scopes to namespace-command leaves.
- [ ] Update tests to assert each leaf's `--help` invocation.

---

### Story ?.?: Apply Phase L UX framing to non-scaffold commands [Planned]

**Motivation**: Phase L scoped the `sv create`-grade rollout (step counters, quiet-replay, spinners) to `pyve init` and `pyve update` — the scaffold-shaped commands. The same treatment plausibly improves `pyve lock` (long conda solves), `pyve testenv install` (pip output), and `pyve purge --force` (multi-step confirmation + delete). The `lib/ui/` toolkit shipped in Phase L (`run.sh`, `progress.sh`) is generic enough to apply directly.

**Phase M update (M.i.3 v2.8 testenv-DX bundle).** `pyve testenv install` no-arg now **iterates over every non-lazy declared testenv** — for a project with `[tool.pyve.testenvs.{testenv,smoke,integration}]`, that's three pip installs in sequence, each producing its own stream of output. This is *exactly* the multi-step surface step counters were designed for: without them, the user gets a wall of pip output with no visible structure. With them, `[1/3] Installing testenv...` → `[2/3] Installing smoke...` → `[3/3] Installing integration...` makes the macro-shape legible. M.i.3 shipped with plain `info()` per env (no step counter) to stay scoped, but the bundle's iteration surface elevates the priority of this Future story — pick this up shortly after M.t (v2.8.0) ships and bundle it as an early v2.9-era polish release.

**Why deferred**: Phase L was already large after the option-1 expansion; rolling out to four more commands would have stretched it further. The scaffold commands are the canonical "first impression" surface so they were prioritized.

**Tasks** (sketched; refine when picked up):

- [ ] Walk each command, identify macro-steps, wrap with `step_begin`/`step_end_ok` + `run_quiet`.
- [ ] Decide whether `purge --force` warrants step framing or if the existing confirm flow is sufficient.
- [ ] Update `features.md` for any output-contract changes.
- [ ] Tests per the L.j pattern.

---

### Story ?.?: Auto-Remediation for Diagnostics (`pyve check --fix`) [Planned]

After Phase H shipped `pyve check` in v2.0, evaluate adding `--fix` for common auto-remediable issues (missing venv → run init, stale `.pyve/config` version → run update, missing distutils shim on 3.12+ → re-install, etc.). Deliberately deferred to collect real usage data on `pyve check` before deciding which fixes to automate and with what safety gates.

### Story ?.?: `pyve check` surfaces available updates for the hosted tools and pyve itself [Planned]

**Raised:** 2026-06-08 (developer, during Story N.bj). Post-v3.0.0.

**Motivation.** `pyve check` is **local-only** today: the `[pyve]` diagnostic reports whether the toolchain is provisioned, the toolchain Python version, and whether project-guide is pyve-hosted vs project-managed — but it never asks *"is a newer version available?"* for either the globally-hosted `project-guide` (on PyPI) or `pyve` itself (on the Homebrew tap / GitHub releases). N.bj established the remediation *mechanics* (`pyve self provision` is the hosted-tool upgrade path; `brew upgrade …/pyve` or a source `git pull && pyve self install` upgrades pyve) but nothing tells a user *when* to run them. This story closes that loop: detect staleness, then print the exact remediation command for the user's install source.

**Why a separate story (not folded into N.bj).** N.bj is purely local teardown/upgrade plumbing. Staleness *detection* adds a **network dimension** to a command that is currently offline and CI-safe — a different design surface with its own risk profile. Pairs naturally with the `pyve check --fix` auto-remediation story above (detection here; auto-apply there).

**Design considerations (decide when picked up).**

- **CI-safety is the hard constraint.** `pyve check` returns structured 0/1/2 exit codes consumed by CI. A network probe must NOT flip the verdict (a stale hosted tool is *info*, never `warn`/`error`), must NOT hang CI (short connect timeout + offline-graceful: a failed/absent network degrades silently to "couldn't check"), and wants an explicit opt-out (`--offline` / `PYVE_NO_NETWORK=1`) plus short-TTL caching so every `check` isn't a fresh round-trip.
- **Two sources, two mechanics.**
  - *project-guide latest* → PyPI JSON API (`https://pypi.org/pypi/project-guide/json`), compared against the version installed in the toolchain venv (`pyve_toolchain_venv_dir`/bin/pip show, or import metadata).
  - *pyve latest* → the Homebrew tap (or GitHub releases), compared against `$VERSION`.
- **Remediation routing keys off `detect_install_source`** (already known to `check`):
  - stale project-guide → `pyve self provision`
  - stale pyve (Homebrew) → `brew upgrade pointmatic/tap/pyve`
  - stale pyve (source clone) → `git pull && pyve self install`

**Out of scope.** Auto-*applying* upgrades (that is the `pyve check --fix` story). Version *pinning* of the hosted tools. Any change to the 0/1/2 exit-code contract.

**Tasks (sketch).**

- [ ] Decide the network model: opt-in vs opt-out, timeout, cache TTL + location, and the `--offline` / `PYVE_NO_NETWORK` surface. Confirm a network failure can never change the exit code.
- [ ] Implement a best-effort latest-version probe for project-guide (PyPI JSON) and pyve (tap / GitHub releases), each degrading silently offline.
- [ ] Wire an `info`-level staleness line into the `[pyve]` check section with the install-source-correct remediation command.
- [ ] Tests: stubbed-network "newer available → correct hint", "up-to-date → no hint", and "offline/timeout → silent, exit code unchanged".
- [ ] Document the new env var / flag in the Environment Variables table and `pyve check --help`.

---

### Story-Group: Security & Bootstrap Hardening

**What these are.** Two I.h-audit-driven hardening items on the micromamba *bootstrap download* (the binary pyve fetches when a user has no micromamba): cryptographic integrity verification of the downloaded tarball, and pinning its version instead of always fetching `latest`. Neither is user-requested — they close known gaps a security reviewer would flag, not workflows anyone is blocked on.

**Relevance / reach.** The bootstrap path only fires for users *without* micromamba already installed (many have it via brew/system), so this is a subset of the micromamba-backend subset. The current bar — TLS to `micro.mamba.pm` plus operational sanity (extracts, runs, reports a version) — matches most dev tooling.

**Benefits.**

- *Verification (SHA256):* a real integrity gate. Catches a tampered artifact (compromised CDN/mirror, or a TLS-intercepting proxy / bad CA) and silent corruption (a truncated download that still extracts). Honest limits: it's trust-on-first-use pinning of whatever `micro.mamba.pm` served us at table-build time — **not** upstream signature verification — and the binary still runs with full user privileges immediately after. Incremental defense-in-depth, not a category change.
- *Version pinning:* deterministic, stable bootstraps. The strongest concrete win is **insulation from a regressing `latest`** (mamba/conda have shipped behavior-changing releases — e.g. the libmamba solver default flip — that break unpinned users with no pyve change); plus CI reproducibility across time.

**Tradeoffs (why deferred).**

- Both push pyve into **actively tracking micromamba releases** — bump the pinned version + refresh the hash table each release, or users sit on stale tooling. `latest` + TLS-only is zero-maintenance; these swap that for a recurring release chore.
- **`pyve lock` already covers the reproducibility that matters most.** A `conda-lock.yml` records the *already-solved* package set, and install-from-lock does **not** re-solve — so two machines with different micromamba versions still get identical packages. The binary-version pin only bites when there's *no* lock (solve-from-`environment.yml`) or to dodge a broken `latest`; the integrity gate is orthogonal to it.
- Linking the binary-version pin to `pyve lock` was considered and rejected for now: micromamba is machine-level pyve *infrastructure* (shared `~/.pyve/bin`, like the toolchain Python), not per-project data — letting a per-project lock dictate a shared binary invites churn/conflict between projects, for a reproducibility benefit the lock already delivers.

**Disposition.** Deferred to a future dedicated security pass. The dependency-reproducibility benefit `pyve lock` provides is sufficient for now; the marginal integrity/pin gains don't yet justify the per-release maintenance discipline. Pick these up if a security review specifically asks for download integrity, or if a regressing micromamba `latest` makes the pin worth its upkeep. If revived, version pinning is the higher-value of the two and is the natural prerequisite for the hardcoded-hash table.

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
