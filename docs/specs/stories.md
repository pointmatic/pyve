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

### Story O.d: `pyve init --force` (and `self migrate`'s rebuild) is blind to v3 `pyve.toml` content — re-derives backend/python from filesystem heuristics, silently converting backend [Done]

**Discovered:** 2026-06-11, migrating the micromamba `modelfoundry` repo (a "test-only" repo whose target is `root = none` + a micromamba `testenv`). Generalized to `pyve init --force` while writing this story.

**Symptom.** `pyve self migrate` on a micromamba project wrote a *correct* `pyve.toml` (`[env.root] backend = "micromamba"`), then its rebuild dropped into the **interactive `pyve init` wizard**, which re-prompted for backend / version-manager / Python and produced a **`.venv` on Python 3.14.5** — converting the project to venv and orphaning the intact conda env (`environment.yml` + `.pyve/envs/root/conda`). It also wrote a **stray v2-style `.pyve/config`** (`backend: venv`, `python.version: 3.14.5`) alongside `pyve.toml`, reintroducing dual config; `.envrc` still activates the micromamba root, so the on-disk state is now self-contradictory.

**Root cause — `pyve init --force` ignores the *content* of an existing `pyve.toml`.** `init_project` calls `_init_validate_existing_manifest` ([plugin.sh:1628](../../lib/plugins/python/plugin.sh#L1628)), which only **validates the schema** of an existing manifest — it never reads the declared backend/python. `backend_flag` is populated *only* from the `--backend` CLI flag; a bare `pyve init --force` leaves it empty, so `_init_wizard` ([plugin.sh:1110](../../lib/plugins/python/plugin.sh#L1110)) resolves the backend from `_init_detect_backend_default` ([plugin.sh:760](../../lib/plugins/python/plugin.sh#L760)) — a pure **filesystem heuristic** (`environment.yml` → micromamba, else venv) — in every branch (interactive prompt default *and* non-interactive value). The manifest is honored for *existence/validity* but never for *content*.

It survives **by luck** when filesystem agrees with manifest (a micromamba project with `environment.yml` heuristics back to micromamba); it silently **converts** when they disagree — a declared backend with no matching filesystem marker, a future plugin backend (uv/poetry/node), or the user accepting a wrong wizard default.

**Migrate is the most dangerous caller, not the bug's locus.** `self_migrate` step 3 runs `PYVE_REINIT_MODE=force PYVE_FORCE_YES=1 init_project` ([self.sh:917](../../lib/commands/self.sh#L917)) — inheriting the blindness whole. `PYVE_FORCE_YES=1` suppresses only the destroy-confirmation, not the wizard (the gate is `PYVE_INIT_NONINTERACTIVE=1`, which migrate doesn't set — and even if it did, the non-interactive path still uses the filesystem heuristic, not the manifest). So the migrator's "deterministic" docstring claim is false on rebuild.

**Why it matters.** Any forced rebuild of a non-default-backend project (micromamba today; future plugin backends) silently risks converting it to venv — data-loss-class for the abandoned env — and re-asks decisions the v3 manifest already encodes. The fix belongs in `init` (honor the manifest on a forced/refresh rebuild); migrate is fixed for free once init reads the manifest. This is the architectural twin of O.a: the forced-init / migrate-rebuild path is the recurring weak seam.

**Fix (decide during implementation).**
1. **`init` honors the manifest on a forced/refresh rebuild.** When `pyve.toml` exists, `init_project` reads backend/python/version-manager from it (`manifest_get_backend` etc.) as authoritative — prompting only for what the manifest doesn't declare, and running fully non-interactively under `--force`. The fix lives in `init`, not migrate; `self migrate` is corrected for free (its rebuild *is* `init_project`) and should additionally pass `PYVE_INIT_NONINTERACTIVE=1` so it can never prompt.
2. **Consider defaulting migrate to `--no-rebuild`.** The env is frequently already at the v3 `.pyve/envs/<name>/<backend>/` path (modelfoundry's micromamba root was), making the rebuild unnecessary and risky; opt into `--rebuild` only for the layout-move case. (Pairs with the developer's observation that migrate's real value is the `pyve.toml` seed, not the rebuild.)
3. **Stop the rebuild writing a v2-style `.pyve/config`** when `pyve.toml` is canonical — confirm whether that write is read-compat scaffolding or a stray, and kill the dual-source-of-truth (project-essentials: "`pyve.toml` is canonical; `.pyve/` holds state only").

**Decisions taken during implementation.**
- **Backend is the load-bearing field.** `pyve.toml`'s `[env.root]` carries `backend` but no python/version-manager; python follows from the existing `environment.yml` (micromamba) / `.tool-versions` (venv) the wizard already honors. The fix therefore seeds the resolved backend from the manifest; python/version-manager need no separate manifest read.
- **Migrate drops its rebuild entirely (Q1-b)**, rather than defaulting to `--no-rebuild`. Migrate now only seeds `pyve.toml` + backs up legacy sources; `pyve init --force` is the separate, documented next step. `--no-rebuild` is kept as an accepted no-op for back-compat. This removes the migrate-level corruption path by construction.
- **`.pyve/config` is justified, not killed (deferred to N-10).** Investigation showed it is not a stray: it is deliberate v3.0 read-compat scaffolding with **64 read-sites across 11 files** (gitignore composer, `.envrc` activate hook, `backend_detect`, `lock`, `envs`, `micromamba_env`, re-init detection). The O.d symptom (`.pyve/config` recording `backend: venv`) was a *downstream* effect of the backend conversion; the core fix makes the same write record the manifest's backend, eliminating the *contradiction*. Eliminating the *file* means migrating all 64 read-sites + composers onto `pyve.toml` — that is the N-10 read-compat sweep, out of scope here. Developer-confirmed.
- **Q2-a — never orphan a foreign-backend env.** On a forced rebuild, a stray env of a backend differing from the manifest's target is moved to `.pyve/.v2-legacy/` (recoverable), not abandoned.

**Tasks**

- [x] Reproduce (red) at the **backend-resolution level**: a project whose `pyve.toml` declares a backend the filesystem heuristic disagrees with (`[env.root] backend = micromamba` with a `.python-version`, or `backend = venv` with an `environment.yml`) → the rebuild resolves the *heuristic's* backend, not the manifest's. (Unit, at the wizard seam where the bug lived — full materialization is exercised by integration; the resolution decision is the defect.)
- [x] Reproduce (red) at the **migrate level**: a bare `pyve self migrate` invokes `init_project` (the rebuild) → red via a sentinel stub.
- [x] Fix in `init`: when `pyve.toml` declares a root backend and no `--backend` is given, the wizard seeds `backend_flag` from the manifest (`_init_manifest_root_backend`), outranking the filesystem heuristic and suppressing the backend prompt. Flows into `get_backend_priority` as Priority 1, so the manifest wins on both `--force` (config skipped) and non-force (config outranked) paths.
- [x] Decide + implement the rebuild question: **migrate drops its rebuild entirely** (Q1-b). `self_migrate` no longer calls `init_project`; help + summary + dry-run plan + docstring updated; `--no-rebuild` kept as accepted no-op.
- [x] Justify the `.pyve/config` write: load-bearing v3.0 read-compat (64 read-sites), consistency restored by the core fix, removal deferred to N-10 (developer-confirmed). No dual-source *contradiction* remains.
- [x] Q2-a: `_init_backup_foreign_env` moves a stray foreign-backend env to `.pyve/.v2-legacy/` on a forced rebuild; wired into the force path after re-init handling. Bats covers micromamba-target/venv-target/own-env-untouched.
- [x] Bats: migrate no longer rebuilds (no `init_project` invocation, points at `pyve init --force`); dry-run plan no longer promises a rebuild.
- [x] project-essentials: documented that a forced rebuild / `pyve init --force` honors the manifest backend (no heuristic re-derivation when `pyve.toml` declares it), and that migrate no longer rebuilds.

**Version:** **v3.0.5** — part of the combined "sane migration path + manifest-honoring `pyve init --force`" bundle; shares the release with the sibling O-series migration/init stories (no separate per-story bump; the bump + CHANGELOG land at O.f).

---

### Story O.e: v3 root-env relocation `mv`s a micromamba env — breaks every console script (dead shebangs); env looks healthy because python still runs [Done]

**Discovered:** 2026-06-11, modelfoundry — `pyve init --force` → "Install pip dependencies from pyproject.toml?" → `bad interpreter: No such file or directory` for `.pyve/envs/root/conda/bin/pip`.

**Symptom.** Every console script in the relocated micromamba env (`pip`, `pip3`, … — **23 scripts**) carries a dead absolute shebang `#!/…/.pyve/envs/modelfoundry/bin/python3.12`, pointing at the env's *original* prefix, which no longer exists. `pip install` fails; any entry point fails. The env's **python binary still runs** (`python --version` → 3.12.13), so existence checks pass and the breakage is invisible until pip / a console script is invoked.

**Root cause — conda/micromamba envs are not relocatable.** The v3 layout mover `migrate_legacy_env_layout` (a side effect of `resolve_env_path`, [lib/envs.sh](../../lib/envs.sh)) **`mv`s** a flat name-keyed prefix `.pyve/envs/<configured>/` → the reserved root slot `.pyve/envs/root/conda/`. conda bakes the absolute prefix into every script's shebang (and into `conda-meta` records, `.pth` files, and pkg metadata) at creation; a bare `mv` moves the directory but rewrites none of it. The python *binary* survives (Mach-O/ELF, not a shebang script), masking the damage. `pyve init --force` can't heal it — it sees the dir exists and prints "environment already exists, skipping creation."

**Why it matters.** Every v2.x→v3 migration of a micromamba project silently produces a broken env (pip + all entry points dead) the instant the opportunistic mover runs — surfacing only when the user installs deps or runs a console script. The canonical existence-≠-runnability trap, in the migration path. Companion to O.d: O.d converts the backend, O.e corrupts the env it relocates — together they are why `pyve self migrate` on a micromamba project is presently unsafe.

**Fix (decide during implementation).**
1. **Don't `mv` a conda prefix — recreate it at the destination** from `environment.yml` (+ `conda-lock.yml` if present). Relocation becomes create-new-then-remove-old, not move-in-place.
2. **Or repair-on-move:** after relocation, rewrite the baked prefix everywhere conda put it (script shebangs in `bin/`, `conda-meta/*.json`, `*.pth`, pkg records) — the conda prefix-replacement mechanism. Heavier and easy to under-cover; (1) is safer.
3. **Heal, don't skip.** `pyve init --force` and `pyve check` must **probe runnability** (execute `pip --version` / a console script, not `[[ -x ]]`) and, on a dead-shebang env, rebuild rather than report healthy / "skip, already exists." Reuses the runnability-probe pillar (Phase P) and the O.c `--status` probe helper.

**Decision taken during implementation.** **Repair-on-move + recreate backstop** (developer-confirmed), not recreate-in-mover. The mover fires as a side effect of `resolve_env_path` on routine read commands (`check` / `status` / `run`), so a conda solve+download there is unacceptable — fix #1 (recreate) is wrong *at the mover*. Instead: the mover does a cheap local prefix-repair after the `mv`, and the *explicit* `pyve init --force` path gains a runnability probe that recreates a non-runnable env (the backstop for any baked-prefix location the repair misses). Fix #3 is delivered via `create_micromamba_env` (which `init --force` calls), not a separate `init` branch.

**Tasks**

- [x] Reproduce (red): a flat name-keyed micromamba env relocated to `.pyve/envs/root/conda/` leaves dead-shebang console scripts. Hermetic stub `bin/`/`conda-meta`/`.pth` tree with an absolute-prefix shebang; assert the relocated shebang targets the *new* prefix (red: bare `mv` left the old one).
- [x] `migrate_legacy_env_layout` relocates safely — `_env_repair_baked_prefix` rewrites the baked prefix (`bin/*` shebangs, `conda-meta/*.json`, `*.pth`; **binaries skipped**) after every `mv` in the main-micromamba mover. **venv audit done**: the v2.7 + v2.8 movers (which `mv` testenv `venv/` and `conda/`) call the same repair — a moved venv's `bin/` shebangs are repaired too.
- [x] `init --force` runnability-aware: `create_micromamba_env` probes `_micromamba_env_runnable` (executes `bin/pip --version`) and rebuilds a non-runnable existing env instead of "already exists, skipping."
- [x] Bats: relocate a fixture env → console-script shebang targets the new prefix; conda-meta records repaired; python binary untouched; venv testenv shebang repaired; runnability helper + rebuild-vs-skip decision. (12 new tests in [test_main_micromamba_env_layout.bats](../../tests/unit/test_main_micromamba_env_layout.bats).)
- [x] project-essentials: added "conda/venv envs are not relocatable — repair the baked prefix on move, and probe runnability (not existence) before trusting one."

**Version:** v3.0.5 — part of the combined "sane migration path" bundle (shares the release with O.d and siblings; bump + CHANGELOG owned by O.z).

---

### Story O.f: v3.0.5 — bundle version bump + final testing [Done]

*(Placeholder. Owns the single `pyve.sh` → v3.0.5 bump and the end-of-bundle validation for the "sane migration path + manifest-honoring `pyve init --force`" effort. The story number and the bundle's member references will be adjusted when the bundle is resolved and locked for release.)*

**Purpose.** The v3.0.5 bundle (O.d, O.e, + any siblings added before lock) ships as one release; per the Version Cadence phase-bundling rule, exactly one story owns the bump. This is that story — it carries the `pyve.sh` version bump and the final cross-bundle validation, and lands **last** in the bundle.

**Tasks**

- [x] Confirm every v3.0.5 bundle story is `[Done]` and its fix verified — **locked member set: O.d** (manifest-honoring `init --force`) **+ O.e** (safe micromamba relocation), both `[Done]`. No other siblings; the following `O.?` stories are explicitly outside this bundle.
- [x] Bump `VERSION` in [pyve.sh](../../pyve.sh) to `3.0.5` (the single bump for the bundle).
- [x] Full unit suite green (bats) — 0 failures locally. Integration suite runs in CI.
- [x] End-to-end migration smoke — **deferred to CI** (developer-chosen): a real-micromamba local run would bootstrap over the network and mutate the developer's real `~/.local` / `~/.asdf`. Covered by O.d's wizard-resolution unit tests + O.e's relocation/runnability unit tests plus the integration suite in CI.
- [x] Update [project-essentials.md](project-essentials.md) — cross-bundle facts landed with their stories: manifest-honoring rebuild (O.d entry) and "conda/venv envs are not relocatable — repair-on-move + probe runnability" (O.e entry).
- [x] CHANGELOG: added the `[3.0.5]` release entry (O.d + O.e).
- [x] *(at lock — developer)* Renumber this story to its final position and reconcile the member-story references. Left to the developer (story sequencing/renumbering is developer-owned).

**Version:** v3.0.5 — this story owns the bump.

---

### Release v3.0.6: General Housekeeping and Fixes (Stories O.g, O.h, O.i, O.j, O.k group, O.l, O.m, O.n, O.o)

---

### Story O.g: `pyve check` is v3-blind — hard-errors "`.pyve/config` missing" on a valid `pyve.toml` project (and `init` papers over it by re-writing the v2 config) [Done]

*(Post-v3.0.5 escapee. The v3.0.5 bundle (O.d/O.e) made `self migrate` + `init --force` honor `pyve.toml`, but `pyve check` was not in scope — and O.d's facet #3 "stop writing `.pyve/config`" was correctly **deferred** here because it's coupled to this fix. Number/version are placeholders for the developer to finalize.)*

**Discovered:** 2026-06-11, migrating the `project-guide` repo with the v3.0.5 binary. After `pyve self migrate` (writes `pyve.toml`, skips rebuild) and before any `.pyve/config` is recreated, `pyve check` reports `✗ Configuration: .pyve/config missing → Run: pyve init` — on a project whose canonical v3 `pyve.toml` is present and valid.

**Symptom.** `check_environment` Check 1 gates on `config_file_exists` (`[[ -f ".pyve/config" ]]`, [plugin.sh:2897](../../lib/plugins/python/plugin.sh#L2897)) and hard-exits if absent; Check 3 reads the backend via `read_config_value "backend"` ([plugin.sh:2908](../../lib/plugins/python/plugin.sh#L2908)) — both pure v2 `.pyve/config` (YAML), never `manifest_load` / `pyve.toml`. A v3-native project (pyve.toml present, no `.pyve/config`) fails `pyve check` outright.

**Root cause — the check path never adopted the v3 manifest.** `pyve.toml` is canonical, and `manifest_load` already handles both native pyve.toml and the v3.0 read-compat synthesis from `.pyve/config`. But `pyve check` bypasses that layer, pivoting on `config_file_exists` + `read_config_value`, so it only "sees" a project that still carries the legacy `.pyve/config`.

**The squirrely coupling — why `init` re-writes `.pyve/config`.** `pyve init` writes a v2-style `.pyve/config` (the "✔ Created .pyve/config" line) — which is the *only* reason `pyve check` passes afterward. Removing that write (the dual-config anti-pattern project-essentials forbids) **without** fixing check would leave check permanently broken. The two are **one change**: check must read `pyve.toml`, and `init` must stop writing `.pyve/config` — together. This is the home for O.d's deferred facet #3.

**Fix.**
1. Route `pyve check`'s config-presence + backend/python reads through `manifest_load` + the flat accessors (`manifest_get_backend`, `manifest_resolve_purpose`, …) — never `config_file_exists` / `read_config_value`. Works for v3-native (pyve.toml) and v2 (read-compat synthesis) alike.
2. Stop `init` writing the v2 `.pyve/config`; `pyve.toml` is the sole declaration.
3. Audit the remaining `config_file_exists` / `read_config_value` / `[[ -f ".pyve/config" ]]` consumers ([plugin.sh:341](../../lib/plugins/python/plugin.sh#L341), [:2399](../../lib/plugins/python/plugin.sh#L2399), [:3559](../../lib/plugins/python/plugin.sh#L3559)) and route the v3 ones through the manifest; keep only the deliberate read-compat reads (tagged `v3.0-only: remove in N-10`).

**Scope decision (2026-06-11).** Task 2 alone (route `check` reads through the manifest) fixes the user-facing symptom: once `check` reads `pyve.toml`, a migrated project passes regardless of whether `init` still writes `.pyve/config`. Stopping the `.pyve/config` write (Fix #2 / original task 3) has a 57-`read_config_value` + 13-`config_file_exists` blast radius — every *direct* (non-manifest) reader returns empty on a fresh v3 project — which is exactly the N-10 read-compat sweep the O.d project-essentials note scopes *"not to ad-hoc edits here."* So this story lands the **check-read fix** (+ the parallel `status` presence/backend read-fix, same one-line risk profile); the **`init` write-removal + the broader read-site migration move to N-10.**

**Tasks**

- [x] Reproduce (red): a v3-native project (valid `pyve.toml`, no `.pyve/config`) → `pyve check` exits non-zero with "`.pyve/config` missing." Assert check passes on `pyve.toml` alone.
- [x] Route check's config/backend reads through `manifest_load` + accessors; drop the `config_file_exists` hard-gate.
- [x] Fix the parallel `pyve status` v3-blindness: presence gate + backend read through the manifest, so a `pyve.toml`-only project is recognized (no "Not a pyve-managed project" false negative).
- [ ] ~~Stop `init` writing `.pyve/config`~~ → **deferred to N-10** (O.d's facet #3; coupled to the 57-site read migration below).
- [ ] ~~Audit + route other v3 consumers off `.pyve/config`~~ → **deferred to N-10** (the ~64-site read-compat sweep, per the `v3.0-only: remove in N-10` markers).
- [x] Bats: `pyve check` green on a pyve.toml-only fixture (venv + micromamba); still green on a v2 `.pyve/config`-only fixture via read-compat.

**Version:** v3.0.6 (recommended) — the "sane migration path" follow-up: a migrated project must pass `pyve check` without an `init --force` that re-creates the v2 config. Developer owns the final number/version.

---

### Story O.h: `pyve init` re-asks the project-guide completion prompt every run — sentinel check runs *after* the prompt, not before [Done]

*(Innocuous — the wiring is correctly idempotent; only the prompt ordering is wrong. Outside the v3.0.5 migration bundle.)*

**Discovered:** 2026-06-11, modelfoundry `pyve init --force` (project-guide-perspective diagnosis).

**Symptom.** `pyve init`'s FR-16 post-init project-guide hook (Step 3, shell-completion wiring) prints `Add project-guide shell completion to your rc file? [Y/n]:` ([utils.sh:350](../../lib/utils.sh#L350)) **before** checking whether the completion block already exists. Only *after* the user answers does it find the sentinel and print `▸ project-guide completion already present in ~/.zshrc` ([project_guide.sh:163](../../lib/project_guide.sh#L163)). So every `pyve init --force` re-asks a question whose answer is already determinable for a one-time-ever configuration.

**Root cause.** The sentinel-presence check (`PROJECT_GUIDE_COMPLETION_OPEN` = `# >>> project-guide completion (added by pyve) >>>`, [utils.sh:223](../../lib/utils.sh#L223); FR-16 idempotency, Step 3) runs *inside* the post-prompt wiring path instead of as a *pre-prompt* guard.

**Note — pure Pyve bug.** No project-guide code is involved: the prompt strings exist nowhere in `project_guide`; the behavior is specified in the synced `features.md` FR-16 and implemented entirely in Pyve. (project-guide repo: diagnosis only, no story there.)

**Fix.** Hoist the sentinel check above the interactive prompt. If the block is already present in the target rc file (`~/.zshrc` / `~/.bashrc`), skip the prompt entirely — silently, or with the existing one-line `▸ … already present` note. No changes to the flag/env handling (`--project-guide-completion`, `--no-project-guide-completion`, `PYVE_PROJECT_GUIDE_COMPLETION`, the CI auto-skip asymmetry) — those paths only matter when the block is **absent**.

**Tasks**

- [x] Reproduce (red): with a temp rc file already containing the sentinel block, drive the completion-wiring step in interactive mode → assert the prompt is **not consulted** and the rc file is unchanged. (Tested via a prompt spy in [test_project_guide.bats](../../tests/unit/test_project_guide.bats) rather than real stdin — the prompt's `read` is nondeterministic under bats.) Fails today (prompt consulted).
- [x] Hoist the sentinel-presence check above the prompt in the completion-wiring path — the wiring lives in [`run_project_guide_orchestration`](../../lib/project_guide.sh#L129) (Step 3), not `utils.sh`: resolve the rc path up front, and if the block is present → one-line "already present" note + return *before* the prompt; absent → unchanged flag/env/prompt handling.
- [x] Confirm the flag/env paths (`--project-guide-completion` / `--no-project-guide-completion` / `PYVE_PROJECT_GUIDE_COMPLETION` / CI auto-skip) are untouched and still only matter when the block is absent (absent-path test green; full suite green).

---

### Story O.i: General housekeeping + Homebrew update formula validation + CLI install/upgrade improvements [Done]

- [ ] *(housekeeping)* Consider a general "non-interactive guard" so any future prompt auto-declines without a TTY rather than relying on per-callsite `[[ -t 0 ]]` — fits **Phase P: Harden and heal Pyve** alongside the runnability-probe / `pyve heal` work, not needed for v3.0.0.
- [ ] *(housekeeping)* Add an integration smoke that drives the brew `post_install` shape (`PYVE_FORCE_YES` unset, stdin a non-TTY, pinned version absent) and asserts `self provision` exits without hanging — deferred to Phase P (local integration runs mutate the real `~/.local`/`~/.asdf`, a documented hazard).
- [ ] **Revisit before Homebrew 6.0 / 5.2** removes `HOMEBREW_NO_REQUIRE_TAP_TRUST`. By then the path is one of: the `dawidd6` action grows native trust handling; Homebrew ships a non-interactive `brew trust`; or we write `trust.json` directly. Forward-compat is deferred, not solved.
- [x] Audit `update-homebrew.yml` against the v3 surface — **clean**: it's only a `dawidd6/action-homebrew-bump-formula` version bump on `v*` tags; references no pyve commands, file names, or `caveats` text, so nothing v2-specific to fix.
- [x] Confirm the formula's test/install block exercises a v3 smoke path. Audited the reference copy [docs/specs/pyve.rb](../../docs/specs/pyve.rb): `install` / `caveats` (`pyve self provision`, `self unprovision --all`, `pyve update`) / `depends_on python@3.12` already v3-correct. Strengthened `test do` from a `--version`-only check to a real **v3 `init` smoke** (shims the formula Python as bare `python`, runs `pyve init --backend venv` non-interactively + no network, asserts `pyve.toml` + `.venv/bin/python`); validated the sandbox steps locally. Developer deployed the `test do` block to `pointmatic/homebrew/tap`. (`url`/`sha256` left untouched — auto-bumped by the `dawidd6` release action.)
- [x] *(housekeeping)* Refreshed the stale gitignore-template comments — but **not** as a simple rename: the sweep test ([test_state_layout.bats](../../tests/unit/test_state_layout.bats)) only scans `lib/commands/` + `pyve.sh` (not `utils.sh`), and `utils.sh` has no gitignore-template line (gitignore moved to `lib/gitignore_composer.sh`, which ignores the whole `.pyve/` tree). Both comments ([test_testenvs_activate.bats:13-15](../../tests/unit/test_testenvs_activate.bats#L13-L15), [test_state_layout.bats:165-168](../../tests/unit/test_state_layout.bats#L165-L168)) corrected to reflect that reality.

---

### Story O.j: box commands print `✔ All done.` even when the command failed (`footer_box` is status-blind) [Done]

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

- [x] Reproduce (red): `footer_box 1` still printed `✔ All done.` ([test_ui.bats](../../tests/unit/test_ui.bats)); e2e, `pyve env init testenv` on an uninitialized dir emitted the green success box under its `✘` errors.
- [x] Made `footer_box [exit_code]` status-aware ([core.sh:141](../../lib/ui/core.sh#L141)): `0`/absent → `✔ All done.`; non-zero → red `✘ Failed.`. Padding is computed (not hardcoded) so the box stays 41 wide for either message. Pyve-agnostic (no `PYVE_*`/paths introduced).
- [x] Threaded the result code at the only two callsites that compute one at the footer point — `env_command`'s `leaf_rc` ([env.sh:1314](../../lib/commands/env.sh#L1314)) and the sync path's `sync_rc` ([env.sh:1223](../../lib/commands/env.sh#L1223)). The other 9 callsites are success-only (their failure paths `return`/`exit` before the footer, or `set -e` aborts) → kept the no-arg success default.
- [x] Tests: 3 `footer_box` unit tests (success / explicit-0 / non-zero→Failed) + 1 e2e dispatcher test (failed `env init` → `Failed.`, never `All done.`, exit unchanged).
- [x] Full suite green (1992 tests, 0 failures); re-ran the `pyve env init testenv` smoke — footer now renders red `✘ Failed.` and exits 1.
- [x] **CI follow-up:** the e2e dispatcher test was environment-dependent — a bare `env init` *succeeds* whenever `python` resolves (it just creates the venv), so it passed locally but green-passed on CI and tripped `[ status -ne 0 ]`. Made deterministic by forcing the leaf failure via `PYVE_PYTHON=/nonexistent/python` (overrides the project interpreter regardless of the runner's Python); verified the fix holds with a valid `python` on PATH.

---

### Story Group O.k: env-config duality — lifecycle commands read `pyproject.toml [tool.pyve.testenvs]` while the v3 canonical is `pyve.toml [env.*]` (umbrella)

*(Reframed 2026-06-11. The original O.k assumed the `[tool.pyve.testenvs]` / pyproject references in env/lock help + errors were merely **stale strings** to rewrite. The investigation for O.k's own red step disproved that: the env **lifecycle** path (`init`/`install`/`run`/`lock`) still **reads** `pyproject.toml [tool.pyve.testenvs]`, so those strings are **accurate**, not stale. Rewriting them to `pyve.toml` without migrating the reader would make them lie. The real work is resolving the duality — broken into the bundle below.)*

**The duality (verified).** Two env-config readers coexist:
- `lib/manifest.sh` → `PYVE_ENV_*` ← `pyve.toml [env.*]` (v3 canonical; used by `check`/`status`/`test --env` purpose-gating + init backend resolution).
- `lib/envs.sh` `read_env_config` → `PYVE_TESTENV_*` ← `pyproject.toml [tool.pyve.testenvs]` via `pyve_testenvs_helper.py` (used by `pyve env init/install/run/lock` for backend/manifest/requirements/extra/declaration).

So `pyve env sync` **writes** `pyve.toml [env.*]`, but `pyve env init <name>` **reads** `pyproject.toml` — a user who declares only in `pyve.toml` gets an empty lifecycle read. This is the field-reported "mirror vs driver" gap (the duality O.m/O.n deferred to "O.k / N-10").

**Enabling facts (already in place — no schema work).** The `pyve.toml [env.*]` schema already recognizes `backend`/`manifest`/`extra`/`lazy`/`requirements` (`KNOWN_ENV_KEYS`, [pyve_toml_helper.py:230](../../lib/pyve_toml_helper.py#L230)); the manifest arrays already carry them (`PYVE_ENV_MANIFEST`/`_EXTRA`/`_REQUIREMENTS_Q`, [manifest.sh:23-28](../../lib/manifest.sh#L23-L28)); and the manifest's legacy synthesis already maps `PYVE_TESTENV_*` → `PYVE_ENV_*` for read-compat. So the migration is a **re-pointing**, not a schema build.

**Bundle.** **O.k.1** (behavioral reader migration) → **O.k.2** (truthful strings, depends on O.k.1). Removal of the standalone v2 `pyve_testenvs_helper.py` reader stays in the N-10 read-compat sweep.

**Version:** v3.0.6 Phase O bundle (O.k.1 + O.k.2). Developer owns the final number/version.

---

### Story O.k.1: migrate the env-lifecycle config reader onto the `pyve.toml` manifest [Done]

**Goal.** Make `pyve env init/install/run/lock` source env config (`backend`/`manifest`/`requirements`/`extra`/`lazy`/declaration) from `pyve.toml [env.*]` (the manifest, `PYVE_ENV_*`) instead of `pyproject.toml [tool.pyve.testenvs]` (`PYVE_TESTENV_*`). When `pyve.toml` is absent, v2 `[tool.pyve.testenvs]` keeps working via the manifest's existing legacy synthesis (read-compat). After this, `pyve env sync` (writes `pyve.toml`) and the lifecycle (reads `pyve.toml`) are coherent.

**Approach (decide during impl).** Route the lifecycle accessors (`_env_backend_of` / `_env_manifest_of` / `_env_extra_of` / `_env_requirements_of` / `is_env_declared` / `is_env_lazy`) — and/or `read_env_config` — through `manifest_load` + the `PYVE_ENV_*` arrays. **Avoid the recursion trap:** `_manifest_synthesize_from_legacy` calls `read_env_config`, so `read_env_config` must NOT call `manifest_load` unconditionally — when `pyve.toml` is present, map `PYVE_ENV_*` → `PYVE_TESTENV_*`; the synthesis path keeps using the lower-level pyproject helper directly. Filter the manifest envs to the lifecycle-relevant set (declared named/test envs; exclude `root`).

**Out of scope.** Rewriting the user-facing strings (O.k.2 — must follow this). Removing `pyve_testenvs_helper.py` (N-10). Conda exec / pip layer (O.m/O.n).

**Tasks**

- [x] Reproduce (red): a `pyve.toml`-only project with `[env.testenv]` (backend/manifest) + `[env.lint]` (requirements) and NO `[tool.pyve.testenvs]` → the lifecycle accessors returned empty. Now resolve from `pyve.toml` ([test_env_name_manifest_decl.bats](../../tests/unit/test_env_name_manifest_decl.bats), 3 tests: resolves / precedence / read-compat).
- [x] Routed `read_env_config` through the manifest: a **no-arg** call with `pyve.toml` present maps `PYVE_ENV_*` → `PYVE_TESTENV_*` via the new `_env_config_from_manifest` ([envs.sh](../../lib/envs.sh)); an explicit-path call stays on pyproject. Recursion-safe (manifest_load reads pyve.toml directly here; synthesis only fires when pyve.toml is absent). The migrator now reads the v2 source explicitly (`read_env_config pyproject.toml`, [self.sh](../../lib/commands/self.sh)).
- [x] Parity: existing pyproject-`[tool.pyve.testenvs]` fixtures still drive the lifecycle (read-compat); new `pyve.toml [env.*]` fixtures now drive it too.
- [x] Coherent end-to-end: a `lint` env declared **only** in `pyve.toml` materializes via `pyve env init lint` (`.pyve/envs/lint/venv` created, exit 0) — before O.k.1 the lifecycle read pyproject and couldn't see it.
- [x] Full suite green: **1995 tests, 0 failures** (read-compat preserved every pyproject-testenv test). Shellcheck clean on changed lines.

*(Note: the project-essentials wording "`pyve.toml` … the manifest accessors are the only sanctioned read path" is now substantially true for the lifecycle; a formal essentials edit is `plan_phase`'s job, deferred.)*

---

### Story O.k.2: rewrite the now-accurate env/lock help + error strings to `pyve.toml [env.<name>]` [Done]

*(Depends on O.k.1 — the strings can only truthfully say `pyve.toml` once the lifecycle reads it.)*

**Sites (stale only after O.k.1 lands).**
- `pyve env` / `testenv` `--help` ([env.sh:1150](../../lib/commands/env.sh#L1150)): *"Declare them in `[tool.pyve.testenvs.<name>]` inside pyproject.toml."*
- `pyve lock` errors ([lock.sh:239-240](../../lib/commands/lock.sh#L239-L240), [lock.sh:256](../../lib/commands/lock.sh#L256)).
- `pyve env` conda/requirements errors ([env.sh:131](../../lib/commands/env.sh#L131), [env.sh:808-809](../../lib/commands/env.sh#L808-L809), [env.sh:846](../../lib/commands/env.sh#L846)).
- Comments ([env.sh:86](../../lib/commands/env.sh#L86), [env.sh:88](../../lib/commands/env.sh#L88), [env.sh:798](../../lib/commands/env.sh#L798)).

**Fix.** Rewrite `[tool.pyve.testenvs.<name>]` / pyproject → `[env.<name>]` in `pyve.toml`; point at `pyve env sync` as the reconciliation path. **Keep** the `self.sh` migrator refs ([self.sh:606](../../lib/commands/self.sh#L606), [self.sh:831](../../lib/commands/self.sh#L831)) — the migrator legitimately reads the v2 source.

**Tasks**

- [x] Reproduce (red): new [test_env_v3_strings.bats](../../tests/unit/test_env_v3_strings.bats) asserts the env/lock help + error paths emit the **v3** spelling (`pyve.toml` / `[env.<name>]`) and **not** `tool.pyve.testenvs` / `pyproject.toml`; all 6 string assertions failed before the rewrite.
- [x] Rewrite the help ([env.sh:1150](../../lib/commands/env.sh#L1150)) → `[env.<name>]` in `pyve.toml` + a `pyve env sync` pointer; lock errors ([lock.sh:239-240](../../lib/commands/lock.sh#L239-L240), [lock.sh:256](../../lib/commands/lock.sh#L256)); env conda/requirements errors ([env.sh:131](../../lib/commands/env.sh#L131), [env.sh:809](../../lib/commands/env.sh#L809), [env.sh:846](../../lib/commands/env.sh#L846)); comments ([env.sh:86-88](../../lib/commands/env.sh#L86), [env.sh:798](../../lib/commands/env.sh#L798)). Also fixed the now-stale lock surface header comment ([lock.sh:34](../../lib/commands/lock.sh#L34)) — beyond the enumerated sites but the same O.k.1-induced lie.
- [x] Green: the rewritten user-facing strings carry no `tool.pyve.testenvs` / `pyproject.toml`; a regression-guard test confirms the `self.sh` migrator refs ([self.sh:606](../../lib/commands/self.sh#L606), [self.sh:831](../../lib/commands/self.sh#L831)) survive (the migrator legitimately reads the v2 source). The two remaining `pyproject.toml` refs in `env.sh` ([env.sh:174](../../lib/commands/env.sh#L174), [env.sh:183](../../lib/commands/env.sh#L183)) are the `extra` resolver reading `[project.optional-dependencies]` — correct, left untouched.
- [x] Full suite green: **2002 tests, 0 failures** (`bats tests/unit/*.bats`, exit 0). Shellcheck clean on changed lines (only pre-existing baseline findings remain).

**Version:** v3.0.6 Phase O bundle. Depends on O.k.1. Developer owns the final number/version.

---

### Story O.l: `pyve init` crashes on a declared `none` / advisory root backend — can't materialize a no-Python-root topology (e.g. `none`-root + micromamba-testenv) [Done]

*(Field feedback surfaced 2026-06-11 while investigating O.g/O.k. `backend = "none"` is declarable in `pyve.toml` but `pyve init` hard-errors on it, so a no-Python-root project can't be built. Also folds in the documentation gap: what `none` is actually for.)*

**Discovered:** 2026-06-11, field report that v3.0.5 cannot materialize a `none`-root + micromamba-testenv topology.

**Symptom.** A `pyve.toml` declaring `[env.root] backend = "none"` (or any advisory backend) makes `pyve init` abort with `Invalid backend: none / Valid backends: venv, micromamba, auto` (exit 1) **before materializing anything** — so neither the skipped root nor the concrete-backend test env (e.g. a micromamba `testenv`) gets built. Micromamba itself works fine both as a root backend and as a named test-env backend; the **only** blocker is the `none` root.

**Root cause.** `pyve init`'s root-backend resolution seeds `backend_flag` from the manifest ([`_init_manifest_root_backend`](../../lib/plugins/python/plugin.sh#L779) → `"none"`), then runs it through [`validate_backend`](../../lib/backend_detect.sh#L122), which only accepts `venv|micromamba|auto` → `exit 1` ([plugin.sh:1849-1853](../../lib/plugins/python/plugin.sh#L1849-L1853)). The **per-env** install path already handles this gracefully — [`_env_install_with_lock`](../../lib/commands/env.sh#L754) calls [`_env_backend_is_advisory`](../../lib/envs.sh#L254) (the single classifier, backed by `pyve_toml_helper.py classify`) and records-but-does-not-materialize an advisory-backend env with a "provision it manually" note. Init's **root** path predates that and chokes.

**What `none` is for (the documentation gap).** `backend = "none"` declares that the project **root has no Pyve-managed Python/virtualenv runtime** — for non-Python languages / backends / environments Pyve does **not yet materialize**: a Node root (npm/pnpm/yarn), Rust (cargo), Go, advisory cache-backed toolchains, or a polyglot coordination root. It lets a project use Pyve's declaration + `.envrc`/direnv wiring + named **purpose-driven** envs (e.g. a micromamba `test` env, advisory tool envs) **without a vestigial root `.venv` or a forced Python pin**. It is currently *expressible* in `pyve.toml` (advisory backend, validates) but **not materializable** (this story makes `init` skip it rather than crash; actually creating non-Python root envs is future per-plugin work). For a pure-Python project `none` gains nothing over `venv` — it exists specifically for the non-Python / runtime-less root.

**Fix.**
1. **`init` skips an advisory/`none` root instead of crashing.** When the resolved root backend classifies as advisory (reuse `_env_backend_is_advisory` — do **not** inline a `== none` check; per the single-classifier rule), skip root env creation and emit the same advisory note the per-env path uses ("declares backend '<x>', which pyve does not yet materialize; provision it manually"), then continue to materialize the declared concrete-backend envs. Prefer an **init-level skip** so `validate_backend` stays strict for an explicit `--backend` flag (a genuinely-unknown `--backend bogus` must still hard-error).
2. **Document what `none` is for.** Add a project-essentials entry (and refresh any backends help/docs that imply root must be venv/micromamba) explaining the non-Python/unsupported-root use case, that `none` is declarable + (after this fix) init-safe, and that root materialization for those backends is future work. Cross-link the closed `VALID_BACKENDS` vocabulary.

**Out of scope.** Actually **materializing** non-Python root backends (npm/pnpm/yarn/cargo/go root env creation) — per-plugin future work; this story only stops the crash, skips the root, and documents the concept. The `pyve env run` conda-activation limitation (micromamba test envs install/create fine; PATH-only `run` is venv-only — use `micromamba run -p`). The N-10 `.pyve/config` read sweep.

**Tasks**

- [x] Reproduce (red): new black-box [test_init_none_root.bats](../../tests/unit/test_init_none_root.bats) drives `pyve init` (non-interactive, offline) on a `[env.root] backend = "none"` + micromamba-`testenv` fixture. **Root-cause correction:** the live crash is not `Invalid backend: none` from `validate_backend` (the story's stale diagnosis) but the *earlier* `python plugin: env 'root' declares unregistered backend 'none'` — there are in fact **three** gates that each reject an advisory backend (see next task). The 4 "init succeeds" assertions failed red; the `--backend bogus` strictness assertion was already green.
- [x] Skip root env creation when the resolved root backend classifies advisory — routed all **three** gates through the single classifier `_env_backend_is_advisory` (no inline `== none`): (1) the plugin's env-block validation [plugin.sh:152](../../lib/plugins/python/plugin.sh#L152) (`bp_lookup` miss → advisory carve-out), (2) `init`'s `validate_backend` gate [plugin.sh:1855](../../lib/plugins/python/plugin.sh#L1855) — an advisory **manifest** backend emits the per-env "does not yet materialize" note, scaffolds the manifest, sets the composition-tail globals (so `.envrc`/`.gitignore` + project-guide + next-steps still run), and returns before materializing; an explicit `--backend` stays strict via a captured `arg_backend_explicit`, so `--backend bogus` still hard-errors, and (3) the `.envrc` activate hook [plugin.sh:578](../../lib/plugins/python/plugin.sh#L578) (advisory root → contribute no section instead of erroring).
- [x] Confirmed: on the `none`-root fixture the declared micromamba `testenv` reads cleanly from the manifest (`is_env_declared testenv` → yes, `_env_resolve_backend testenv` → micromamba) — the advisory root never gates it off; it materializes via `pyve env init <name>` like any project (env-init path untouched).
- [x] Documented in [project-essentials.md](project-essentials.md): new "`backend = "none"` declares a runtime-less / non-Python root" entry (advisory category + the closed `classify backend` vocabulary, declarable + init-safe, root materialization is future per-plugin work, the single-classifier `how-to-apply`). The `--backend` CLI help stays `venv, micromamba, auto` — `none` is a manifest declaration, never a flag value, so the help is already correct.
- [x] Bats green: 5 `init` tests on the `none`-root fixture (exit 0, no `.venv`/`.pyve/envs/root`, advisory note emitted, `pyve.toml` preserved) + `--backend bogus` still hard-errors with no advisory note.
- [x] Full suite: **2007 tests**, only 2 failures — `test_asdf_compat.bats` `J.c` guard tests — confirmed **pre-existing** (fail identically with my lib changes stashed; environment-dependent on this machine's asdf state; tracked by Phase P "Fix pre-existing integration test failures"). Zero regressions attributable to O.l. Shellcheck clean on changed lines.

**Version:** part of the **v3.0.6** Phase O bundle (ships with O.g–O.n). Developer owns the final number/version.

---

### Story O.m: `pyve test` / `pyve env run` cannot operate a conda-backed testenv — primary dev loop hard-gated off conda [Done]

*(Critical bug, field-reported 2026-06-11. A conda-backed testenv **builds and runs fine** — but only via direct `micromamba run -p …`, bypassing pyve entirely. The `pyve test` ergonomics that are the whole reason to declare a pyve testenv don't work against conda in 3.0.5, so the primary dev loop is broken for every conda project.)*

**Discovered:** 2026-06-11, field report. A `[tool.pyve.testenvs.testenv]` (`backend="micromamba"`, `manifest="environment.yml"`) materialized a real conda env at `.pyve/envs/testenv/conda` (python 3.12.13 + torch etc.), but `pyve test` and `pyve env run` both refuse to operate it.

**Symptom.** `pyve env run testenv …` and `pyve test` (which is built on the same exec path) hard-error: *"'pyve env run' does not yet support conda-backed env 'testenv' (resolved backend: micromamba). Workaround: 'micromamba run -p .pyve/envs/testenv/conda <command>'."* So the user must run the conda env directly, outside pyve.

**Root cause.** `pyve env run` activates via **PATH-prepend** (`<env>/bin` ahead of `PATH`) — correct for a venv, **wrong for conda**. A conda env needs `CONDA_PREFIX` / `CONDA_DEFAULT_ENV`, its `etc/conda/activate.d` scripts, and conda's library paths (which compiled wheels like torch depend on); PATH-prepend alone doesn't set those up. M.i.1 deliberately **gated conda out** ([`assert_env_venv_backend`](../../lib/envs.sh#L271)) rather than ship half-working activation. The gate fires at both callsites: `pyve env run` ([env.sh:1241](../../lib/commands/env.sh#L1241)) and `pyve test` ([plugin.sh:3937](../../lib/plugins/python/plugin.sh#L3937)).

**Fix — exec conda envs the conda way (proper support, not a workaround).** When the resolved env backend is micromamba, exec via `micromamba run -p <env_path> <cmd>` — the canonical conda exec primitive that sets `CONDA_PREFIX`, runs the activate scripts, and fixes lib paths. This is the same command the error currently tells the user to run by hand, moved *inside* pyve. Replace the `assert_env_venv_backend` hard-gate at both callsites with a backend dispatch: venv → today's PATH activation; micromamba → `micromamba run -p`. Preserve exit codes, argument passing, stdin/TTY. Requires micromamba on PATH (`get_micromamba_path`); error actionably if absent.

**Out of scope.** The conda **pip-requirements layer** (O.n — `pyve env install -r` for conda). Which declaration table *drives* a conda env (`[tool.pyve.testenvs.*]` in pyproject vs `pyve.toml [env.*]`) — that duality is O.k / N-10 territory; this story consumes whatever `_env_resolve_backend` / `_env_manifest_of` already resolve. The main (`root`) conda env's `pyve run` path if it needs the same treatment — note it, fix here only if it shares the exec helper cheaply.

**Tasks**

- [x] Reproduce (red): new [test_conda_env_exec.bats](../../tests/unit/test_conda_env_exec.bats) drives both callsites against a conda env — the dispatch assertions failed red (the gate hard-errored before any exec). The two pre-existing reject-tests asserting the old policy ([test_testenv_run_name.bats](../../tests/unit/test_testenv_run_name.bats), [test_test_env_resolver.bats](../../tests/unit/test_test_env_resolver.bats)) were flipped/retired since this story reverses the behavior they pinned.
- [x] Added the shared exec primitive `env_exec_conda <env_path> <cmd…>` ([envs.sh](../../lib/envs.sh)) — execs `micromamba run -p <env_path> <cmd>` (sets CONDA_PREFIX / activate.d / lib paths). Routed both callsites through a backend dispatch on `_env_resolve_backend`: `pyve env run` ([env.sh:1242](../../lib/commands/env.sh#L1242)) and `pyve test`'s exec tail ([plugin.sh](../../lib/plugins/python/plugin.sh)); venv stays on PATH activation (`env_run` / direct `python -m pytest`). Removed the now-dead venv-only gate `assert_env_venv_backend` (+ its 4 unit tests; `inherit`-resolution coverage already lives in [test_testenv_conda.bats:147](../../tests/unit/test_testenv_conda.bats#L147)).
- [x] `exec` preserves exit code / arg passing / stdin / TTY by construction (`micromamba run` runs in the same process tree); micromamba-absent and env-not-materialized (no `conda-meta`) paths hard-error actionably (covered in the new test).
- [x] `pyve test --env <conda>` execs `micromamba run -p <path> python -m pytest <args>` (asserted via a stubbed micromamba in the new test). A *real* conda solve + run is an integration/manual check, not a hermetic bats unit (the suite avoids network) — the exec dispatch and arg threading are what the unit pins.
- [x] Venv path unchanged: a venv-backed `env run` still routes to `env_run` (regression test in the new file) and the venv `pyve test` exec is untouched; existing resolver/run tests green.
- [x] Full suite: **2009 tests**, only the 2 pre-existing `test_asdf_compat.bats` `J.c` failures (environment-dependent, confirmed pre-existing — same as O.l; Phase P backlog). Zero regressions from O.m. Shellcheck clean on changed lines.

*(Out-of-scope note resolved: the `root` conda env's `pyve run` path **already** execs via `micromamba run -p` in `run_command` [plugin.sh:3718](../../lib/plugins/python/plugin.sh#L3718) — no change needed there.)*

**Version:** **v3.0.6** Phase O critical-bugfix bundle. Developer owns the final number/version.

---

### Story O.n: `pyve env install -r` silently drops pip requirements for conda testenvs — no conda+pip layer [Done]

*(Critical bug, field-reported 2026-06-11. The standard conda workflow — conda for heavy deps (torch), pip for dev tooling (pytest/ruff) — is unexpressible: `-r` is silently ignored against a conda env, so dev tools never land and the silent data loss masks it. Pairs with O.m to make conda testenvs fully operable.)*

**Discovered:** 2026-06-11, field report. `pyve env install testenv -r requirements-dev.txt` against a conda-backed testenv synced only `environment.yml`; the pip requirements were silently dropped, forcing a manual `pip install` via the conda env's own python.

**Symptom.** For a micromamba-backed env, `pyve env install <name> -r <file>` runs only `micromamba install -p <env> -f <manifest> -y` and **never pip-installs `<file>`** — with no warning.

**Root cause.** [`_env_install_conda`](../../lib/commands/env.sh#L802) takes only `(name, env_path, manifest)` and syncs the conda manifest. The `-r` file (`cli_req_file`) is threaded into [`_env_install_with_lock`](../../lib/commands/env.sh#L747) but consumed **only by the venv branch** (`_env_install_venv`); the micromamba branch ignores it. The conda backend was designed as "manifest is the single source" with no pip fallback — so a conda+pip split has nowhere to live.

**Fix — a real pip layer for conda envs (proper support).** After the conda manifest sync, pip-install the requested pip sources **into the conda env** via `micromamba run -p <env_path> python -m pip install -r <file>` (reusing O.m's conda exec). Honor the same source precedence the venv path already supports where it makes sense for conda — CLI `-r`, then a declared `requirements`/`extra` — layered on top of the manifest solve (conda solves heavy deps; pip adds the rest). **Never silently drop `-r`**: if a source is given and can't be applied, it must be an error or a loud warning, never silent.

**Out of scope.** The conda exec primitive itself (O.m — this story depends on it). Lockfile/`conda-lock` interaction with the pip layer (note if it surfaces; don't expand). Reconciling which table declares conda sources (`[tool.pyve.testenvs.*]` vs `pyve.toml [env.*]`) — O.k / N-10.

**Tasks**

- [x] Reproduce (red): new [test_conda_pip_layer.bats](../../tests/unit/test_conda_pip_layer.bats) drives `_env_install_with_lock` against a conda env with a stub micromamba logging argv — pre-fix only the `install -f <manifest>` line appeared, never a `run -p … pip install -r` line (the `-r` was silently dropped). The "no -r → sync-only" case was already green.
- [x] Threaded `cli_req_file` into the micromamba branch of `_env_install_with_lock` → `_env_install_conda` (new optional 4th param). Added `_env_conda_pip_layer` ([env.sh](../../lib/commands/env.sh)): after the manifest sync, resolves the pip source by precedence (CLI `-r` > declared `requirements` > declared `extra`) and installs it INTO the conda env via `micromamba run -p <env> python -m pip install …`. The venv-only conveniences (auto `requirements-dev.txt`, bare-pytest fallback) are intentionally not carried over — for conda the manifest is the base and the pip layer is opt-in.
- [x] No silent drop: a CLI `-r` (or declared `requirements`) file that doesn't exist is a hard error before any pip attempt (asserted — error names the missing file, `mm.log` shows no `pip install`).
- [x] Manifest sync runs first, then the pip layer (asserted via log line ordering); the venv install path (`_env_install_venv`) is untouched — zero changes to its precedence chain.
- [x] Full suite: **2013 tests**, only the 2 pre-existing `test_asdf_compat.bats` `J.c` failures (environment-dependent, confirmed pre-existing — same as O.l/O.m; Phase P backlog). Zero regressions from O.n. Shellcheck clean on changed lines.

*(Scope note on declared sources: the schema mutex `requirements ⊕ extra ⊕ manifest` means a conda env — which requires `manifest` — cannot also declare `requirements`/`extra` today, so the **CLI `-r`** flag is the live pip-source path for conda. The declared-`requirements`/`extra` precedence branches are implemented for parity and are future-proof if the mutex is relaxed to allow conda+pip declarations, but are currently unreachable for a conda env. Relaxing the mutex was not in this story's scope.)*

**Version:** **v3.0.6** Phase O critical-bugfix bundle. Depends on O.m. Developer owns the final number/version.

---

### Story O.o: Clarify and correct the promise of `pyve init` — declaration vs. materialization vs. mechanics for test environments (umbrella) [Planned]

*(Design correction surfaced 2026-06-11. What `pyve init` actually *promises* to materialize from a `pyve.toml` is muddy: init eagerly builds a bare-Python `testenv` regardless of declaration, a no-backend testenv hardcodes `venv` instead of mirroring the root, a code comment claims the opposite of what the code does, and no docs state the contract. Correct the ergonomics + comments + docs so "initialize" has one clear, declared-driven meaning.)*

**Discovered:** 2026-06-11, tracing `pyve init` behavior for a `[env.root] venv` + `[env.testenv] purpose="test", default=true` (no backend) config. Empirically, init materialized **both** `.venv/` **and** `.pyve/envs/testenv/venv/` — the latter a bare venv (Python only, no pytest), which `pyve check` then flags as "present but pytest not installed."

**Three defects of one muddy promise.**
1. **Eager undeclared materialization.** `pyve init` calls `ensure_env_exists` ([plugin.sh:2075](../../lib/plugins/python/plugin.sh#L2075)) which builds a default `testenv` venv even when no test env is declared — creating an env the user never asked for, that immediately reads as "broken" in `check`.
2. **No-backend testenv hardcodes `venv`, doesn't mirror root.** `_env_resolve_backend` ([envs.sh](../../lib/envs.sh)) returns `venv` for a testenv with no `backend`; only an *explicit* `inherit` mirrors the main backend. So a micromamba project's no-backend testenv wrongly resolves to venv.
3. **Stale comment contradicts behavior.** [plugin.sh:862-866](../../lib/plugins/python/plugin.sh#L862-L866) claims *"`pyve init` materializes the run env (`.venv/`) and `pyve testenv init` later materializes the test env … even before the testenv venv exists on disk"* — the opposite of what init does (it eagerly creates it).

**Proposed model — a graduated "declared → materialized → operable" ladder (minimal magic).**

- **No test env declared** → **no test env initialized.** Init materializes only what's declared (the root env). No injected bare-Python `testenv`.
- **Test env declared, `purpose="test"`, `default=true`, no backend** → Pyve **mirrors the root backend** (`inherit` semantics) and uses the block name (`testenv`) as the env name. `pyve test` autowires to the `default` test env. Very little magic — a declared default with an inferred backend.
- **Test env declared, `purpose="test"` only (no `default`, no backend)** → a **skeleton** declaration: Pyve initializes it with a backend that **mirrors the root**, and nothing more. No autowiring, no dep mechanics. Purely declarative for non-Python stacks (Rust, C++) or `none`/advisory roots — Pyve provides mechanics only for backends it implements. (Consistent with the `none`-root model in O.l and the "declared ≠ operable" framing in O.m/O.n.)
  - **Python-root special promotion (decided 2026-06-11).** Drawing on Pyve's Python origins and Python-friendly slant: when the **root is a Python backend** (venv / micromamba), the declared env collection is **homogeneous** (all envs share one backend — see the homogeneity guard below), and **exactly one** test env is declared with **nothing else** (no other test envs, no explicit `default`), Pyve **promotes** that sole test env to the default and **autowires `pyve test`** to it (PyTest autowiring) — no explicit `default = true` required. The promotion is Python-only: a non-Python / `none`-root, or multiple test envs with no declared default, stays skeleton (no autowiring; `pyve test` reports no default test env).
  - **Homogeneity guard (decided 2026-06-11) — no magic when backends are mixed.** All of the above gentle assumptions (sole-env promotion, autowiring) apply **only when the declared env collection is homogeneous in backend.** The moment the repo declares a **mix of backends** (e.g. a venv root with a micromamba test env, or several test envs spanning backends), the assumptions break: Pyve requires **specificity**. It will happily **configure every env the developer declares** (materialization is unchanged), but does **no autowiring** — `pyve test` needs an explicit `default = true`. No heuristics, no magic: a non-homogeneous repo has too many edge cases to guess a sane default safely.

**Corrections in scope.**
1. **Ergonomics (code).** Gate init's testenv materialization on an actual test-env declaration; default a no-backend testenv to `inherit` (mirror root) rather than hardcoded `venv`; ensure "mirror root" reads the **manifest** (`manifest_get_backend root`), not `.pyve/config` (the current `inherit` path reads the v2 config — coordinate with O.g / the N-10 read sweep). When the mirrored backend is `none`/advisory, the testenv is declarative-only (no materialization, no mechanics — reuse `_env_backend_is_advisory`).
2. **Comments.** Fix [plugin.sh:862-866](../../lib/plugins/python/plugin.sh#L862-L866) and any sibling comments to state the *actual* promise.
3. **Docs.** State the init contract plainly (project-essentials + the site/usage docs): what "initialize" guarantees per declaration shape; that a declared env is not automatically an operable or dependency-populated env; that `purpose="test"` without `default` is a skeleton.

**Decided (2026-06-11).**
- **Sole Python test env → auto-promote** to default with PyTest autowiring (no explicit `default` needed); non-Python / skeleton roots get no promotion (see the Python-root special-promotion note above).
- **Homogeneity guard.** The gentle assumptions apply only to a **single-backend** repo. A mixed-backend collection → Pyve still configures every declared env but does **no autowiring**; `pyve test` requires an explicit `default`. No heuristics under ambiguity.
- **"Mirror root" reads the manifest** (`manifest_get_backend root`), not `.pyve/config` (coordinate with O.g / the N-10 read sweep); root `none`/advisory → mirror yields `none` → skeleton, no mechanics.

**Open decisions — resolved 2026-06-12 (developer).**
- **Dependency seeding → empty until demand.** An initialized Python testenv stays empty (no pytest/deps) until `pyve test` / `pyve env install` populates it on demand — today's behavior, now intentional + documented (the natural partner of the autowiring promotion + O.n's pip layer). Init does **not** eagerly seed `requirements-dev.txt` / declared `requirements`.
- **Backward-compat → proceed + release note.** Gating eager testenv creation changes init output for existing v3 projects that relied on the auto-created empty testenv. Accepted in the early-v3 line; no compatibility shim — call it out in the release notes.

**Bundle.** Broken into four child stories (this story becomes the tracking umbrella, mirroring O.k). Dependency order: **O.o.1** (backend mirroring — foundational) → { **O.o.2** (gate init materialization + comment fix), **O.o.3** (`pyve test` autowiring + homogeneity guard) } → **O.o.4** (docs). Each child carries its own TDD tests; "full suite green" is a per-child gate.

**Version:** Phase O init-semantics correction, larger than the v3.0.6 bugfix line. Number/placement (own subphase vs. folded into a release) is the developer's at planning time.

---

### Story O.o.1: a no-backend testenv resolves `inherit` against the manifest root (not hardcoded `venv`) [Done]

*(Defect 2 of the O.o umbrella. Foundational — O.o.2 and O.o.3 build on it.)*

**Goal.** A declared test env with no `backend` mirrors the **root** backend instead of defaulting to `venv`. Today `_env_config_from_manifest` defaults an empty backend to `venv` ([envs.sh](../../lib/envs.sh)), so a micromamba-root project's no-backend testenv wrongly resolves to `venv`; only an *explicit* `inherit` mirrors. The fix: default a no-backend testenv to `inherit`, and make `_env_resolve_backend`'s inherit path read the **manifest** root backend (`_env_resolve_root_backend` / `manifest_get_backend root`), not only `.pyve/config`.

**Approach.** Change the empty-backend default in `_env_config_from_manifest` from `venv` to `inherit`; route the inherit branch of `_env_resolve_backend` through the manifest-aware root resolver. When the mirrored backend is `none`/advisory, resolution yields the advisory value (declarative-only downstream — reuse `_env_backend_is_advisory`). Confirm the only resolution-time consumer is `_env_resolve_backend` (venv-root projects unaffected: inherit→venv).

**Out of scope.** Init materialization gating (O.o.2), `pyve test` autowiring (O.o.3). The N-10 `.pyve/config` read-sweep (this coordinates with it but doesn't remove the config read).

**Tasks**

- [x] Reproduce (red): new [test_oo1_inherit_mirror.bats](../../tests/unit/test_oo1_inherit_mirror.bats) — a no-backend `[env.testenv]` on a micromamba root resolved `venv`; now resolves `micromamba`. venv root → `venv` (unchanged); `none` root → `none`; explicit testenv backend still wins.
- [x] Defaulted a no-backend testenv to `inherit` in `_env_config_from_manifest` ([envs.sh](../../lib/envs.sh)); `_env_resolve_backend`'s inherit branch now resolves the root via `manifest_get_backend root` first, falling back to `.pyve/config` (v3.0-only read-compat) then `venv`.
- [x] `none`/advisory mirrored root passes through verbatim (resolves `none`), so a no-backend testenv on a `none` root is declarative-only downstream (`_env_backend_is_advisory`).
- [x] No direct array-consumer breaks: the only resolution consumer of the backend array is `_env_resolve_backend` (handles `inherit`); full suite confirms. Also fixed a latent bug — `_env_config_from_manifest` returned the non-zero status of its trailing `&&` whenever a default was set, making `read_env_config` report failure to a `set -e` caller; added an explicit `return 0`.
- [x] Full suite: **2017 tests**, only the 2 pre-existing `J.c` asdf flakes (Phase P backlog). Zero regressions. Shellcheck clean on changed lines.

**Version:** part of the O.o bundle. Developer owns the number.

---

### Story O.o.2: gate `pyve init` testenv materialization on a declared test env (+ fix the stale promise comment) [Planned]

*(Defect 1 + Defect 3 of the O.o umbrella. Depends on O.o.1.)*

**Goal.** `pyve init` materializes only what's **declared**. No test env declared → no testenv created (today it eagerly builds a bare `.pyve/envs/testenv/venv` that `pyve check` then flags as broken). Declared test env(s) → materialize each (using O.o.1's mirrored backend), **empty until demand** (no pytest/deps seeded); a `none`/advisory mirrored backend → declarative-only (not materialized).

**Approach.** Gate the eager `ensure_env_exists` call in init ([plugin.sh:2112](../../lib/plugins/python/plugin.sh#L2112)) on an actual test-env declaration; iterate the declared test envs and materialize each (skip `none`/advisory). Fold in **Defect 3**: fix the stale comment at [plugin.sh:862-866](../../lib/plugins/python/plugin.sh#L862-L866) (and any siblings) to state the actual promise — it's about init's testenv promise, so it belongs in this diff.

**Out of scope.** Backend resolution itself (O.o.1). `pyve test` default selection / autowiring (O.o.3). Dependency seeding (resolved: empty until demand — init seeds nothing).

**Tasks**

- [ ] Reproduce (red): `pyve init` on a project with **no** declared test env creates `.pyve/envs/testenv/venv`; assert it does **not** (only the root env materializes).
- [ ] Gate init testenv materialization on a declared test env; materialize each declared test env (mirrored backend via O.o.1), no deps; `none`/advisory → declarative-only (skip).
- [ ] Fix the stale comment(s) at [plugin.sh:862-866](../../lib/plugins/python/plugin.sh#L862-L866) to match actual behavior.
- [ ] Back-compat: behavior change noted for the release notes (no shim).
- [ ] Full suite; zero regressions.

**Version:** part of the O.o bundle. Developer owns the number.

---

### Story O.o.3: `pyve test` autowiring + homogeneity guard [Planned]

*(Task 4 of the O.o umbrella. Depends on O.o.1; independent of O.o.2.)*

**Goal.** Resolve the default test env `pyve test` targets, with the decided promotion + guard: an explicit `default = true` always wins; else, when the **root is a Python backend**, the declared env collection is **homogeneous in backend**, and **exactly one** test env is declared with nothing else → **promote** that sole test env to default and autowire `pyve test` to it (no explicit `default` needed). A **mixed-backend** collection, multiple test envs with no declared default, or a non-Python / `none` root → **no autowiring**; `pyve test` requires an explicit `default` (and reports no default test env when absent).

**Approach.** Centralize default-test-env resolution (the `pyve test` no-`--env` path at [plugin.sh](../../lib/plugins/python/plugin.sh) currently uses `PYVE_TESTENVS_DEFAULT:-testenv`); add the homogeneity + sole-Python-env promotion logic. Reuse `_env_resolve_backend` (O.o.1) for the per-env backend reads that the homogeneity check needs.

**Out of scope.** Init materialization (O.o.2). Backend resolution (O.o.1).

**Tasks**

- [ ] Reproduce (red): a single declared Python test env with no explicit `default` is not autowired by `pyve test` today; assert it is promoted + autowired on a homogeneous Python project.
- [ ] Default resolution: explicit `default=true` wins; else Python root + homogeneous backends + sole test env → promote; else no default.
- [ ] Homogeneity guard: a mixed-backend collection → no autowiring; `pyve test` requires an explicit `default`.
- [ ] Non-Python / `none` root, or multi-env-no-default → no promotion (no autowiring).
- [ ] Full suite; zero regressions.

**Version:** part of the O.o bundle. Developer owns the number.

---

### Story O.o.4: document the `pyve init` contract — declaration vs. materialization vs. mechanics [Planned]

*(Task 6 of the O.o umbrella. Last — after O.o.2 / O.o.3 settle the behavior.)*

**Goal.** State the init contract plainly so "initialize" has one clear meaning. Cover the graduated **declared → materialized → operable** ladder; that a declared env is not automatically operable or dependency-populated (empty until demand); that `purpose="test"` without `default` is a skeleton; and the Python-root sole-env promotion + homogeneity guard.

**Approach.** A `project-essentials.md` entry (the canonical source go.md embeds) + the usage/site docs. Cross-link the `none`-root model (O.l) and the conda exec / pip layer (O.m/O.n) — all share the "declared ≠ operable" framing.

**Out of scope.** Any behavior change (O.o.1–O.o.3). The N-10 `.pyve/config` read sweep.

**Tasks**

- [ ] `project-essentials.md` entry: the ladder; declared ≠ operable; empty-until-demand; mirror-root; skeleton (`purpose=test` w/o `default`); the Python-root promotion + homogeneity guard.
- [ ] Usage/site docs state the init contract per declaration shape.
- [ ] Cross-link O.l (`none`-root) and O.m/O.n (conda exec + pip layer).

**Version:** part of the O.o bundle. Developer owns the number.

---

## Future

---

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

**Conceptual work first (Phase P, not started).** The `purpose` lifecycle (`run`/`test`/`utility`/`temp`) and environment durability need a *conceptual* pass before any lifecycle code: **what precious resource each purpose protects**, and why preservation is a *cost-cache + artifact* concern, not a "survives-purge" ranking (the principle: *irreproducibility is the bug; we never preserve because an env is irreplaceable*). The framing seed is [env-lifecycle-concept.md](env-lifecycle-concept.md). The intended mode sequence is **`refactor_document`** (fold the framing into `concept.md` / `project-essentials.md`'s `purpose:` entry / `tech-spec.md`) → **`plan_phase`** (derive targeted stories). This corrects, among other things, the current essentials hint that "utility envs survive `pyve purge`" (the new framing makes `utility` the disposable one). Pairs with the declarative-env-setup megastory above.

---

### Story ?.?: Per-env runnability probe — plugins own a "canary" command `pyve check` executes (existence ≠ runnability) [Planned]

*(Field-discovered 2026-06-12, ml-datarefinery migration. Concrete embodiment of Phase P Pillar 1 (runnability probes) and the detection half of Pillar 3 (`pyve heal` / `pyve check --fix`).)*

**Discovered.** A v2→v3 migration relocated a testenv (`.pyve/testenv/venv/` → `.pyve/envs/testenv/venv/`) under a **pre-v3.0.5** binary whose mover did a bare `mv` without rewriting the baked console-script shebangs. Every wrapper (`pip`, `pytest`, `ruff`, `mypy`, the editable package's entry point) kept `#!.../.pyve/testenv/venv/bin/python` baked in — pointing at a deleted path → `bad interpreter: No such file or directory`. The env's `python` symlink stayed valid, so `python -m pytest` worked while every wrapper failed. (v3.0.5+ repairs shebangs at move time, but the repair is **move-time-only** and cannot heal an env already relocated by an older binary — see project-essentials "conda/venv environments are not relocatable — repair the baked prefix on move, and probe runnability (not existence) before trusting one".)

**Symptom — `pyve check` reports a false green.** `check_environment`'s testenv probe ([plugin.sh:3031-3042](../../lib/plugins/python/plugin.sh#L3031-L3042)) runs `<env>/bin/python -c 'import pytest'`, which **bypasses the broken wrappers** (the `python` symlink is fine), so check prints `✓ testenv: pytest installed` for an env whose every console script is dead. The root-env probe is the same shape (`-d` + `-x bin/python`). No `pyve check` line tells the developer the env is unusable; the only signal today is `bad interpreter` at runtime.

**Root cause — existence ≠ runnability, *and the probe targets the wrong artifact*.** Health code stats `bin/python` or runs `python -m …` — but a **console-script wrapper** (a file carrying a baked-in shebang) is exactly what breaks on relocation / dangling symlink / dead interpreter, and `python -m X` can never catch a dead-shebang wrapper. The probe must execute a wrapper, not the interpreter-module path.

**Design — a plugin-owned canary hook.** Add an optional plugin-contract hook (working name `env_probe` / `canary`) so each plugin defines, per backend, a **minimal runnable command + expected response** that `pyve check` executes against every declared *and materialized* env:

- Executes a **console-script wrapper** (baked shebang), never `python -m …` — e.g. the Python plugin runs `<env>/bin/pip --version` (pip is always present in a venv/conda env) and expects a `pip X.Y …` line. A dead shebang surfaces as `bad interpreter` → non-zero → probe fails.
- Returns a **classified verdict**: `runnable` / `dead-shebang (env relocated or interpreter deleted)` / `dangling symlink` / `missing interpreter` / `not materialized` / **`orphaned` (materialized on disk but **not declared**, OR a declared **non-materializable** env — e.g. a `none`/advisory root — that is **nonetheless materialized**: a state↔declaration contradiction)**. `pyve check` renders `✓ <env>: runnable`, or `✗ <env>: console scripts broken (env relocated; shebangs stale) → <role-correct rebuild>`, or `✗ <env>: materialized but not declared (orphan) → remove it` (heal = delete the undeclared/contradictory tree — the modelfoundry case: a broken micromamba env at `.pyve/envs/root/conda/` while the manifest declares `[env.root] backend = "none"`).
- Backend-aware *within* the plugin: venv → execute `bin/pip --version` directly; micromamba → `micromamba run -p <env> pip --version` (reuses O.m's conda exec). `none`/advisory + not-materialized envs → no probe (declarative-only; reuse `_env_backend_is_advisory`).
- Default contract impl is a no-op (plugins opt in), matching the contract's "implement a subset of hooks" design ([lib/plugins/contract.sh](../../lib/plugins/contract.sh)).

This is the **detection** half; the heal action it feeds (Pillar 3 / the `pyve check --fix` story) for a dead-shebang env is the per-env destructive rebuild (`pyve env purge <name> --force` → `pyve env init <name>` → reinstall), offered with confirmation.

**Out of scope.** The heal/auto-remediation *action* (the `pyve check --fix` / `pyve heal` story consumes this story's verdict). The move-time shebang repair (already shipped v3.0.5). The test-isolation leak (Pillar 4). Pyve-hosting runnability (already done — `pyve_toolchain_runnable` / `pyve_project_guide_runnable`); this generalizes the same discipline to *project* envs.

**Tasks (refine at `plan_production_phase`).**

- [ ] Add the `env_probe` (canary) hook to the plugin contract with a no-op default; document the verdict vocabulary.
- [ ] Python plugin: implement the canary — execute a console-script wrapper (`bin/pip --version`; venv direct / micromamba via `micromamba run -p`), validate the expected response, classify the failure (dead-shebang / dangling / missing / not-materialized / orphaned). The **orphaned/contradiction** class is a manifest↔disk reconciliation, not a per-env probe: detect a materialized env with no matching declaration, or a declared non-materializable backend (`none`/advisory via `_env_backend_is_advisory`) that has an on-disk env anyway.
- [ ] Wire `pyve check` to invoke the canary per declared+materialized env; replace the existence-only / `python -m`-style testenv + root probes with the runnability verdict + actionable heal hint, so the `python -c 'import pytest'` false-green can no longer mask a dead-wrapper env.
- [ ] The heal hint is **role-correct**: a broken **root** env points at `pyve init --force` (the `pyve env` namespace rejects `root` — it is selection-only); a broken **named testenv** at `pyve env purge <name> --force && pyve env init <name>`. `pyve check` must **never** suggest the rejected `pyve env purge root` (the dead-end a developer hit in the field). Both root and named-env breakage must be detected — the root micromamba env (relocated `.pyve/envs/<configured>/` → `.pyve/envs/root/conda/` by a pre-repair binary) is a real instance, not just the testenv case.
- [ ] Tests: a relocated-unrepaired fixture (valid `bin/python` symlink + dead-shebang `bin/pip`) → check reports `✗ … console scripts broken`, not a false green; a healthy env → `✓ runnable`; venv + micromamba backends; **root and named** envs; `none`/advisory + not-materialized → no probe; **an orphan/contradiction fixture** (a materialized `.pyve/envs/root/conda/` under a `[env.root] backend = "none"` manifest) → `✗ … materialized but not declared (orphan)`, not silence.
- [ ] Full suite; zero regressions.

**Version:** Phase P. Pairs with the `pyve check --fix` / `pyve heal` story (heal consumes this detection). Developer owns the number/placement.

---

### Story ?.? (megastory): Declarative env setup — an `[env.<name>]` block describes *how the env is set up*, materialized in one shot [Planned]

*(Design direction, 2026-06-12. **Megastory** — captured at altitude; decompose granularly at `plan_production_phase`. Pairs with the per-env runnability probe above: that story tells you an env is broken; this one makes rebuilding it a single declarative act.)*

**The problem (field-surfaced, ml-datarefinery).** Rebuilding a test env took four commands — `pyve env purge testenv --force`, `pyve env init testenv`, `pyve env run testenv -- pip install -e ".[corruptions]"`, `pyve env install testenv -r requirements-dev.txt`. Two of those are **imperative**, because the declaration cannot express what the env needs:

- an **editable self-install with extras** (`-e ".[corruptions]"`) has no declarative home in `[env.<name>]` (today only `requirements` / `extra` / `manifest` — and `extra` installs the group's *packages*, not the project editable);
- the **source mutex** (`requirements ⊕ extra ⊕ manifest`) forbids layering, so even a declarable editable-install couldn't sit beside `requirements-dev.txt`.

A four-command, partly-imperative rebuild is not a declarative system.

**The reframe — declare the setup, not a taxonomy of sources.** An `[env.<name>]` block declares **how the environment should be set up**: a *composable* set of declarative **directives** (editable-self + extras, requirements files, an extra group, a conda manifest, plain packages, …), each a high-level intent the **owning plugin** knows how to realize. The directives compose — the mutex is removed. The vocabulary is **closed and declarative** (a plugin-interpreted set of intents), never a list of shell steps — that boundary is what keeps it declarative rather than imperative-in-disguise. *If it can be expressed, it can be declared.* This is the altitude correction: stop enumerating "what single source populates the env" and describe "how the env is set up."

Concrete shape (Python plugin):

```toml
[env.testenv]
purpose = "test"
# no backend → mirrors the root (O.o.1)
editable     = ".[corruptions]"            # editable self-install + extras (the missing directive)
requirements = ["requirements-dev.txt"]     # composes — no mutex
# a conda env also carries `manifest = "environment.yml"`, layered first
```

`pyve env init testenv` reads the whole recipe and materializes a fully operable env in one shot; rebuild collapses to `pyve env purge testenv --force && pyve env init testenv`, or a single `pyve env init testenv --force`. The manifest fully describes the env; one command reproduces it.

**Decided principles (2026-06-12, developer).**

- Env blocks declare **how to set up** (a composable recipe of intents), not one mutually-exclusive source. **Lift the `requirements ⊕ extra ⊕ manifest` mutex.**
- Add an **`editable`** directive (editable self-install + extras) — the missing expressiveness that forced the imperative step.
- Directives are a **closed, plugin-interpreted declarative vocabulary**, not shell steps. `editable` is the Python plugin's notion; other plugins interpret their own backend's directives.
- **One-shot materialization:** `pyve env init <name>` (and `--force`) realizes the full declared recipe. Reproducibility — the manifest fully describes the env — is the north star.
- Reframes O.o's "empty until demand" into **"init installs what you declared, nothing you didn't"** (no magic pytest; but a fully-declared env comes up operable).
- Folds in the **`pyve init --force` retention question**: replace the silent "rebuild root, keep testenv" magic with **explicit per-env rebuild** (`pyve env init <name> --force`); `pyve init --force` states it touches only the root.
- **A uniform per-env rebuild verb across roles.** Today rebuild is split and holed: a named testenv rebuilds via `pyve env purge/init`, but the `pyve env` namespace **rejects `root`** (selection-only), so root rebuild is a *different* command (`pyve init --force`) — and `pyve env purge root` is a confusing dead-end a developer hit in the field. The one-shot rebuild should present **one "rebuild this env from its declaration" verb that works for `root` and named envs alike** (or, at minimum, `pyve check`/heal routes each role to the correct command), so a human never has to know which namespace owns which env to repair it.

**Decomposition sketch (granular breakdown deferred to `plan_production_phase`).** Likely sub-stories: (a) **schema** — add `editable`, define directive ordering (conda manifest → editable → requirements → extra → packages), lift the mutex, validate the closed vocabulary; (b) **readers** — `pyve_toml_helper.py` + `manifest.sh` accessors for the directive set; (c) **materializer** — `pyve env init`/`install` executes the recipe (venv directly + micromamba via O.n's pip layer + O.m's conda exec); (d) **`--force` one-shot rebuild** + the `pyve init --force` scope change; (e) **migration** — existing `requirements`/`extra`/`manifest`-only blocks stay valid (they're just single-directive recipes); (f) **docs + project-essentials**. An ordered `[[env.<name>.setup]]` array-of-tables is the escape hatch if the flat composable-keys form ever proves insufficient (ordering/repetition).

**Out of scope (this megastory's framing).** The per-env runnability *probe* (the detection story above — this consumes "is it set up right?" but doesn't define detection). Non-Python plugin directive vocabularies beyond stubs (each plugin's own follow-up). The N-10 `.pyve/config` read sweep.

**Version:** Phase P. Decompose at `plan_production_phase`. Developer owns numbering/placement.

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
