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

## Phase P: UX Overhaul; Harden and heal Pyve

Note: there may be some stories in `## Future` that need to be reviewed and considered whether to include in this Subphase

Complexity, inconsistent patterns/defaults, and some magical behaviors are making Pyve v3 difficult to use, and confusing to determine what v3 is supposed to do. The LLM is confused when it comes time to implement projects with Pyve as the environment manager. 

A primary change that needs to be embraced is that **Pyve v2.x** was a Python virtual environment tool with a built-in test environment and a lumpy integration of Conda (micromamba). The declarative parts of v2 were spread across pyproject.toml, .pyve/config, and environment.yml (micromamba). Now **Pyve v3.x** is an any-project virtual environment tool, with initial support via plugins for Python and Node.js via venv, micromamba, and pnpm/npm backends. And a key improvement, v3 can now be fully declarative (with fallback to very simple defaults, like Python, venv, and a single testenv using PyTest).

**Tenets:**
- Pyve surface starts simple - `pyve init` does everything necessary for simple Python projects, with progressive nuance that adapts to project complexity. `pyve test` auto-initializes the environment and installs dependencies if needed (in the Python default case, it uses `mypy`, `ruff`, and `pytest`).
- Pyve is declarative - configuration is the single source of truth, no configuration falls back to defaults; Pyve supports complex imperative workflows via flags, commands, environment vars, but nothing beyond what is defined in the declarative schema.
- Pyve is DRY — no duplication of configuration or logic (except if convenience aliases are needed).
- Pyve is consistent — similar patterns, behaviors, and defaults across all commands, workflows, and plugins.
- Pyve is robust - it handles errors gracefully, heals when possible, provides clear error messages, and feels light and easy with every project; `check` actually checks environment and integration points beyond the configuration and diagnoses typical issues with hints for fixing them; `status` actually shows a coherent, organized status of the Pyve envs and the configuration.
- Pyve works seamlessly across platforms - While Homebrew is the typical install path for development, cloning the GitHub repo and using `pyve self install` works smoothly for CI/CD, automated environments, or on Linux systems where Homebrew is not ideal.
- Pyve is extensible - every configuration facet has a mechanical purpose in Pyve machinery or is forward-looking toward future capabilities.
- Pyve is clearly documented - all configuration options, commands, and workflows are documented in a way that is easy to understand and follow.

**Two acts, two releases.**

- **Act 1 — UX Foundation (v3.1.0, Subphase P-1).** Make v3's declarative model *real*: a complete, explicit, single-sourced `pyve.toml`; a parameter decision-graph that ends the scattered wizard/flag/default drift; desired-vs-actual env state with restore-on-rebuild and a batch lifecycle; one consistent verb model. This is what makes the named-environments promise deliver. North-star design: [phase-p-subphase-1-ux-overhaul.md](phase-p-subphase-1-ux-overhaul.md).
- **Act 2 — Harden & heal (v3.2.0+, Subphase P-2 and beyond).** Make environment *resolution* explainable and Pyve's managed state self-healing. **Act 1 is the substrate Act 2 stands on:** `pyve heal` can only restore toward an intent the manifest fully captures (Act 1's explicit declaration) and an operational reality it recorded (Act 1's state record) — so the UX foundation comes first.

**Multi-release exception.** Phase P ships **a release per subphase** — v3.1.0 (P-1) → v3.2.0 (P-2) → v3.3.0 (P-3) → v3.4.0 (P-4) → v3.5.0 (P-5) — an explicit, documented exception to the Version Cadence "one phase = one bundled release" rule. The sequence is deliberate: each release builds on the last (the UX foundation is the substrate the hardening heals toward; the polish, plugin, and security passes follow). A subphase's stories run unversioned during its work; its final code story owns that subphase's minor bump.

---

**Act 2 context — the hardening mandate** *(breakdown deferred to its own `plan_production_phase` session when Subphase P-2 activates; see Story P.d)*.

Make Pyve's environment resolution make sense and be **bulletproof**; when the armor is pierced, give Pyve a **healing mechanism**. The developer should never have to hand-trace PATH order, version-manager pins, and venv symlinks to understand why a command misbehaves, nor hand-repair Pyve-managed state.

**Triggering incident (field-discovered 2026-06-09).** A developer's `project-guide` invocation in the pyve repo broke with a cryptic `No version is set for command project-guide` naming a Python `3.14.3` they could not place. Untangling it took a long manual trace across **four independent layers**, none of which any Pyve command could see or explain:

1. **PATH shadowing.** `python` reported 3.14.4 while `.tool-versions` pinned 3.12.13 — because direnv had prepended an activated `.venv/bin` ahead of `~/.asdf/shims`, so the asdf pin never governed `python` at all. `project-guide`, present in neither `.venv` nor `~/.local/bin`, fell through to the asdf shim where the 3.12.13 pin *did* apply — and 3.12.13 had no project-guide.
2. **Interpreter drift.** The `.venv` python was a frozen symlink to asdf 3.14.4 (its creation-time interpreter), drifted from the now-3.12.13 pin — a venv never tracks later `.tool-versions` edits.
3. **Dead Pyve-managed artifacts.** `~/.local/bin/project-guide` was a dangling symlink, and the hosted toolchain venv's `project-guide` had a `bad interpreter` shebang — both pointing at a deleted path. Yet both passed Pyve's existence checks.
4. **The 3.14.3 mystery.** project-guide 2.12.0 happened to be pip-installed into one asdf interpreter (3.14.3); asdf surfaced that version number in its rejection message, with no context a human could decode.

**Core anti-pattern to eliminate: existence ≠ runnability.** Pyve's health/hosting code asserts that artifacts *exist* (`-x` / `-f` / `-d`) rather than that they *run*. The canonical trap: [`_compose_check_pyve_hosting`](../../lib/check_composer.sh#L121) reports `project-guide hosting: provisioned` on `[[ -x "$venv_dir/bin/python" ]]`, which passes for a venv whose python symlink targets a deleted interpreter. Story N.bo began the correction at the project-guide resolver (a runnability-honoring `PYVE_PROJECT_GUIDE_BIN` override seam); this subphase generalizes it across the codebase.

**Design pillars (Act 2 — decompose when Subphase P-2 activates, Story P.d).**

1. **Runnability probes.** Replace existence checks throughout hosting/health code with probes that actually execute the artifact (`python --version`, `project-guide --version`, version-manager resolution) and classify the failure: dead interpreter, asdf "no version set", dangling symlink, missing command, version-manager-not-installed. A health check that can be fooled by a broken symlink is not a health check.
2. **Resolution reasoning in `pyve check`.** Turn the manual trace into automated narrative: for each managed command, report *where* it resolves and *why* — PATH-slot ordering, venv-shadows-pin, reachability under the active pin, venv↔pin interpreter drift — in the plain language a human had to reconstruct by hand. `check` should have said, unprompted: "`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13); `project-guide` falls through to the asdf shim under that pin, which has no project-guide → install it into 3.12.13 or repoint the pin."
3. **Healing mechanism (`pyve heal`, or `pyve check --fix`).** Safe, idempotent, **confirm-before-destroy** repairs for every failure class the probes detect: rebuild a toolchain venv with a dead interpreter; re-link a dangling `~/.local/bin` shim; rebuild a `.venv` whose interpreter drifted from the pin (destructive → explicit confirmation); install a missing managed command into the *selected* interpreter. Reversible and re-runnable; never silently mutates without surfacing what it will do.
4. **Close the upstream cause — the test-isolation leak.** The triggering incident was *manufactured by Pyve's own test suite*: [`_isolate_home`](../../tests/integration/test_project_guide_integration.py#L211-L217) (integration harness) symlinks the developer's **real** `~/.asdf` and `~/.local` into the test's fake `$HOME`, so any project-guide/toolchain-provisioning test writes hosting artifacts into real developer state — which dangles when the test's tmpdir is cleaned up. Re-scope `_isolate_home` so the suite can never again mutate a real home (provision into a fully self-contained fake `$HOME`, or stub provisioning entirely). N.bo's `PYVE_PROJECT_GUIDE_BIN` seam closes one path; the version-manager (`.asdf`) and self-install paths remain open.

**Scope notes.** `lib/ui/` primitives stay pyve-agnostic (the lib/ui boundary invariant). Healing never destroys without explicit confirmation. Builds on Story N.bi (check hosting/toolchain surfacing), Phase O (check/status expand-collapse long-form output), and Story N.bo (runnability override seam + the existence-vs-runnability framing). Ships in the Phase N v3.x line; the exact release tag and the full story breakdown are deferred to this subphase's `plan_production_phase` session.

**Conceptual work first (Phase P, not started).** The `purpose` lifecycle (`run`/`test`/`utility`/`temp`) and environment durability need a *conceptual* pass before any lifecycle code: **what precious resource each purpose protects**, and why preservation is a *cost-cache + artifact* concern, not a "survives-purge" ranking (the principle: *irreproducibility is the bug; we never preserve because an env is irreplaceable*). The framing seed is [env-lifecycle-concept.md](env-lifecycle-concept.md). The intended mode sequence is **`refactor_document`** (fold the framing into `concept.md` / `project-essentials.md`'s `purpose:` entry / `tech-spec.md`) → **`plan_phase`** (derive targeted stories). This corrects, among other things, the current essentials hint that "utility envs survive `pyve purge`" (the new framing makes `utility` the disposable one). Pairs with the declarative-env-setup megastory (now Story P.l).

**Subphases**

Each subphase has a theme (with adhoc bug fixes as needed).

- **Subphase P-1 (v3.1.0): Conceptual clarification & UX Foundation** — the keystone parameter decision-graph, an explicit single-sourced manifest, desired-vs-actual env state, batch lifecycle, and one consistent verb model. *(Declarative env setup — formerly its own subphase — is folded into P-1's Pillar II.)*
- **Subphase P-2 (v3.2.0): Runnability probes & environment healing** — Act 2 (the four pillars above).
- **Subphase P-3 (v3.3.0): Workflow & DX polish** — CI hygiene + developer-experience.
- **Subphase P-4 (v3.4.0): Deeper plugin work** — plugin enrichment (TypeScript, …).
- **Subphase P-5 (v3.5.0): Security & bootstrap hardening** — download integrity + version pinning.

Story breakdown for each subphase beyond P-1 is deferred to its own `plan_production_phase` session, kicked off when that subphase activates (Story P.d); candidates are parked in `## Future`.

---

### Story P.a: v3.0.7 — `pyve self install` ships every `lib/` subtree (recursive copy), not a drifting allowlist [Done]

*(Field-discovered 2026-06-13. **Critical** — a key part of Pyve functionality (install from source) is broken: every from-source `pyve self install` of v3.0.6 produces a binary that dies on startup. Standalone patch ahead of the rest of Phase P.)*

**Discovered.** A report that `pyve self install` copies `lib/`, `lib/commands/`, and `lib/completion/` but **not** `lib/ui/`, so the installed `pyve` dies at `source "$SCRIPT_DIR/lib/ui/core.sh"`.

**Symptom.** The installed binary aborts at startup the moment `pyve.sh` sources its first missing module. `lib/ui/core.sh` ([pyve.sh:134](../../pyve.sh#L134)) is the first, so that's where it dies; `lib/plugins/` ([pyve.sh:169-259](../../pyve.sh#L169-L259)) is also absent and would be the next failure. Homebrew installs are unaffected (the formula copies the tree itself); `pyve self provision` does not copy `lib/`.

**Root cause — the copy is a hand-maintained subdirectory allowlist that drifted from `pyve.sh`'s sourcing graph.** `self_install` ([lib/commands/self.sh](../../lib/commands/self.sh)) copied exactly three things: top-level `lib/*.sh` (non-recursive glob), `lib/commands/`, and `lib/completion/` — each its own explicit `cp` step. When `lib/ui/` (Phase L) and `lib/plugins/{python,node}/` (Phase N) were added to the tree and wired into `pyve.sh`, no matching copy steps were added. Nothing caught it: the test suite runs `pyve.sh` from the **source tree** (every subdir present), and no test ran the **installed** binary from the target dir — so the existence-vs-startup gap was invisible (the same existence-≠-operable theme as Phase P's runnability pillar, here applied to the installer's own output).

**Fix.** Replaced the three enumerated steps with a single **recursive** copy of `lib/` (wipe-then-`cp -R`, excluding `__pycache__`), so the installer ships whatever `pyve.sh` sources without an allowlist that re-breaks the next time a subtree is added. Bumped `VERSION` → `3.0.7`.

**Tasks.**

- [x] Reproduce (red): [tests/unit/test_self_install.bats](../../tests/unit/test_self_install.bats) — `self_install` into a sandboxed target, then run the **installed** binary (`pyve.sh --version`) and assert it starts; assert `lib/ui/core.sh` + `lib/plugins/{python,node}/plugin.sh` present. Both failed against v3.0.6 (test 2 reproduces the exact field abort).
- [x] Fix: `self_install` does a recursive `lib/` copy (wipe-then-`cp -R "$source_dir/lib/."`, prune `__pycache__`), replacing the `lib/*.sh` + `lib/commands/` + `lib/completion/` allowlist ([lib/commands/self.sh](../../lib/commands/self.sh)).
- [x] Bump `VERSION` `3.0.6` → `3.0.7` ([pyve.sh:32](../../pyve.sh#L32)).
- [x] Test green; the installed-binary startup check is the regression guard against future allowlist drift.
- [x] Full unit suite; zero regressions (`make test-unit` exit 0, 2033 tests, 0 failures).
- [x] Update Python default version to the latest stable (3.14.6)

**Prevention scan.**

- [x] The new test runs the **installed** binary, not the source tree — closing the gap that let this ship.
- [x] Audited other copy/enumeration sites for the same drift: `pyve self provision` does not copy `lib/` ([lib/commands/self.sh](../../lib/commands/self.sh)); `pyve update` refreshes project files, not the pyve binary; the Homebrew formula lives upstream. `self_install` is the only file-copy installer, and the recursive copy fully covers it.
- [ ] Optional follow-up: add a `project-essentials` entry — "the installer must ship every `lib/` subtree `pyve.sh` sources; verify by running the installed binary, never the source tree."

**Version:** **v3.0.7** (patch). Standalone critical fix; ships ahead of the rest of Phase P.

---

### Story P.a.1: v3.0.8 — `pyve init` completes its composition tail (`.gitignore` / `.envrc` / next-steps) even when a secondary-plugin install exits non-zero [Done]

*(Field-discovered 2026-06-26 on a Replit-generated polyglot (Python + SvelteKit) repo. **Important** — a benign `pnpm` warning silently aborts `pyve init` after the env materializes, leaving the project half-configured: no `.gitignore` (so `.venv` / `.env` secrets risk being committed), no `.envrc` (direnv won't activate), no next-steps. Standalone patch ahead of the Subphase P-1 work, paralleling P.a.)*

**Discovered.** On a polyglot init the run "mostly succeeded" — `.venv`, `pyve.toml`, and `node_modules` were all created — but `.gitignore` was never updated and the log ended abruptly at pnpm's output. pnpm had printed `[ERR_PNPM_IGNORED_BUILDS] Ignored build scripts: esbuild@0.25.12` (its default-deny of dependency build scripts) and exited non-zero.

**Symptom.** `pyve init` on a Python + Node project where the Node install emits *any* non-zero exit (here pnpm's ignored-build-scripts notice) terminates immediately after the package-manager output. The composition tail never runs: no `.envrc`, no `# >>> pyve:managed:gitignore >>>` section (so `.pyve/`, the venv dir, and `.env` are left un-ignored), and no next-steps box. There is **no error message** — the failure is invisible and the project looks "mostly done."

**Root cause — a secondary-plugin install runs as a bare command under `set -e`, and the `.gitignore` / `.envrc` tail runs *after* it.** `pyve.sh` sets `set -euo pipefail` ([pyve.sh:26](../../pyve.sh#L26)). In `_compose_init_materialize_secondary_plugins` the Node materializer is dispatched as an unchecked command in the loop body — `plugin_dispatch "$name" init "$path"` ([lib/init_composer.sh:88](../../lib/init_composer.sh#L88)) — so a non-zero return aborts the whole process under `set -e`. `compose_init` calls that materializer ([init_composer.sh:61](../../lib/init_composer.sh#L61)) *before* the composition tail `_compose_init_run_tail` ([init_composer.sh:63](../../lib/init_composer.sh#L63)), which is where `.envrc`, `.gitignore` ([init_composer.sh:185](../../lib/init_composer.sh#L185)), and next-steps are written. The node hook (`_node_provider_run_install`, [lib/plugins/node/plugin.sh](../../lib/plugins/node/plugin.sh)) surfaces pnpm's exit code verbatim, and pnpm v10+ treats ignored build scripts as a non-zero condition — a *warning* pyve mistakes for a fatal failure. Nothing caught it: the unit suite runs `pyve.sh` from the source tree with package managers that don't trip the ignored-builds gate, and no test drives a polyglot init whose Node install returns non-zero (the same test-the-real-path gap as P.a).

**Fix (planned).** Two coordinated changes: (1) isolate secondary-plugin materialization so a failure cannot abort the composition tail — capture the result, emit a clear warning, and always proceed to `_compose_init_run_tail` so `.gitignore` / `.envrc` / next-steps land regardless of Node outcome; (2) treat pnpm's ignored-build-scripts condition as non-fatal in `_node_provider_run_install` (a real install failure still errors). Bump `VERSION` → `3.0.8`.

**Tasks.**

- [x] Reproduce (red): [tests/unit/test_composed_init_secondary_failure.bats](../../tests/unit/test_composed_init_secondary_failure.bats) — under an explicit `set -euo pipefail` subshell (bats does not enable `set -e`, so the abort only reproduces there), a secondary (Node) dispatch returning non-zero aborts `_compose_init_materialize_secondary_plugins` / `compose_init` before the tail, and `_node_provider_run_install` returns non-zero on `ERR_PNPM_IGNORED_BUILDS`. All three reproduced the field abort against v3.0.7; a genuine-failure guard passed throughout.
- [x] Fix 1: both init loops ([lib/init_composer.sh:88](../../lib/init_composer.sh#L88) secondary materializer + the node-only loop) wrap the dispatch in `if ! …; then warn; fi`, and the secondary materializer `return 0`s — so a Node failure can't `set -e`-abort the `.envrc` / `.gitignore` / next-steps tail.
- [x] Fix 2: `_node_provider_run_install` ([lib/plugins/node/plugin.sh](../../lib/plugins/node/plugin.sh)) captures output via `tee`, reads `PIPESTATUS[0]` (robust to `pipefail` on/off), and downgrades `ERR_PNPM_IGNORED_BUILDS` to a warning (returns 0); a genuine install error still propagates.
- [x] Bump `VERSION` `3.0.7` → `3.0.8` ([pyve.sh:32](../../pyve.sh#L32)).
- [x] New test green (4/4) — the regression guard for both the `set -e` abort and the ignored-builds classification.
- [x] Full unit suite: **zero regressions from this change**. 2034 pass; the only 3 failures (`test_composed_init_matrix.bats` real-`.venv`-build cases) fail **identically on the clean v3.0.7 tree** — pre-existing/environmental (this sandbox can't synthesize a real `.venv`), not introduced here. To be confirmed green in CI.

**Prevention scan.**

- [x] Audited the init flow for the same shape: the two bare-dispatch loops (secondary materializer + node-only) are both fixed; the primary Python dispatch ([init_composer.sh:58](../../lib/init_composer.sh#L58)) is already guarded (`|| return $?`), and the composition tail is not under a bare-dispatch loop.
- [x] `shellcheck` clean on the changed bash (the two findings — `SC2148` no-shebang on sourced libs, `SC2034` unused `TESTENV_DIR_NAME` at `pyve.sh:36` — are pre-existing and unrelated). `ruff`/`mypy` N/A (no Python changed); CI runs neither.
- [ ] Candidate `project-essentials` entry — "the `.gitignore` / `.envrc` composition tail must run regardless of secondary-plugin (Node) materialization outcome; a package-manager *warning* (e.g. pnpm ignored-build-scripts) is not an init failure. Verify by driving a polyglot init whose Node install returns non-zero."

**Version:** **v3.0.8** (patch). Standalone field-discovered fix; ships ahead of the Subphase P-1 work, paralleling P.a.

---

## Subphase P-1: v3.1.0 Conceptual clarification and UX Foundation

**Theme (v3.1.0).** Make v3's declarative model *real* and deliver on the named-environments promise. Three moves: (1) a **keystone parameter decision-graph** — one source that generates the wizard, flags, `--help`, defaults, the explicit `pyve.toml`, and default-drift detection (today these are ≥4 hand-synced sites); (2) **Pillar I — an explicit, single-sourced, version-stable declaration** (`pyve.toml` records every resolved value; `.pyve/config` is retired); (3) **Pillar II — desired-vs-actual env state** with restore-on-rebuild, a batch lifecycle, and one consistent verb model (`update` / `upgrade` / `force`). Full design: [phase-p-subphase-1-ux-overhaul.md](phase-p-subphase-1-ux-overhaul.md).

**Roster shape.** A *planning spine* (P.b vision → P.c spec realignment → P.d plan-the-rest → end-of-phase docs) plus implementation stories grouped **keystone → Pillar I → Pillar II → consistency**. Stories run unversioned during work; the subphase ships one bundled **v3.1.0** tag, the bump landing on its final code story (the breaking-change pass for the `pyve env purge` no-arg flip + the new `pyve upgrade` verb keeps it a **minor**). This is an ambitious foundation subphase — stories may merge or split as each is activated.

---

### Story P.b: UX Vision [Done]

Based on the Phase P preamble and the principles in [`concept.md`](concept.md) / [`features.md`](features.md), produce a UX design overhaul plan that is coherent, consistent, and faithful to the Pyve philosophy — the north-star for Subphase P-1.

- [x] Author [phase-p-subphase-1-ux-overhaul.md](phase-p-subphase-1-ux-overhaul.md): north-star principles (P1–P4), the keystone decision-graph, Pillars I & II, the command/verb model, scope, the Act-2 roadmap framing (the P.d framework), and the breaking-change / version target.
- [x] Developer review of the doc + this P-1 roster at the approval gate.

---

### Story P.c: Phase P Plan Realignment [Done]

Using `refactor_plan` mode, fold the UX design overhaul plan ([phase-p-subphase-1-ux-overhaul.md](phase-p-subphase-1-ux-overhaul.md)) into the core spec docs so they are coherent, consistent, and faithful to the intended vision. Produced a realignment analysis per document, then applied. Framing decision (developer): **concept.md states the timeless end-state vision** (no version markers); **features.md / tech-spec.md version-tag** each new/changed item `v3.1.0 (Subphase P-1)`.

- [x] Update [`concept.md`](concept.md) — 3 new pain points (opaque authoring, hidden/version-fragile defaults, multi-env lifecycle chore); explicit-by-construction + pinned-defaults + `pyve upgrade` + restore-on-rebuild folded into Solution/Goals/Scope/Value-Mapping.
- [x] Update [`features.md`](features.md) — 5 new FRs (FR-23 keystone graph, FR-24 explicit manifest + versioned defaults, FR-25 operational-state record, FR-26 declarative env setup, FR-27 `pyve upgrade` + verb matrix); FR-1/2/3/4/10/11 amended; Inputs/Config/Acceptance updated.
- [x] Update [`tech-spec.md`](tech-spec.md) — new Parameter-decision-graph section; contract contribution-hook, explicit/sole-source manifest, `.state` installed dimension + restore-on-rebuild, CLI/upgrade/verb-boundary. **De-staled** (per developer) the `lib/envs.sh`/`.state` subsection *and* the broader Phase-M/N rot: Package Structure tree, the `env`/`lock`/`test` command tables (`testenv_*`→`env_*`, `.pyve/testenvs/`→`.pyve/envs/`, `read_config_value`/`[tool.pyve.testenvs]`→manifest), N-1 consumer roadmap — all verified against current code.
- [x] Project-essentials revisit (Final Step) — assessed; **skipped** (developer-agreed): doc-only fold-in of unbuilt v3.1.0 design + a doc-rot correction of facts project-essentials already records; P-1 essentials get captured as their stories land.

**Version:** none (pure planning-doc restructure folding in not-yet-built design + doc-rot cleanup; no behavioral change — rides the next code-story release per Version Cadence). Backups `concept_old.md` / `features_old.md` / `tech-spec_old.md` left for the developer to delete at their discretion (Step 8).

---

### Story P.d: All Phase P Planning [In Progress]

The framework for completing the UX overhaul and, in the end, delivering a more hardened and self-healing Pyve. Defines Phase P's later-subphase roadmap (P-2…P-5, below) and triages the `## Future` parking lot into it. The Act-2 roadmap in [phase-p-subphase-1-ux-overhaul.md](phase-p-subphase-1-ux-overhaul.md) §8 is the scaffolding. **Per-subphase story breakdown stays deferred** to each subphase's own `plan_production_phase` session, kicked off when it activates.

- [x] Plan the later subphases — **P-2** (Runnability & healing, v3.2.0), **P-3** (Workflow & DX, v3.3.0), **P-4** (Deeper plugins, v3.4.0), **P-5** (Security & bootstrap hardening, v3.5.0): a scope description for each (see the subphase roadmap below).
- [x] Triage the `## Future` candidates into their destination subphase (P-2…P-5) or an existing P-1 story (tech-spec reconcile → P.c; v3-site sweep → P.s).

---

### Story P.e: [Spike] Parameter decision-graph → wizard/flags/help generation in Bash [Done]

*Architectural spike. The keystone is net-new (verified 2026-06-25): no registry exists; adding one `init` parameter touches ≥4 hand-synced sites, and the plugin contract has no wizard/flag hook. Prove the engine before the extraction.*

Time-boxed spike to de-risk the decision-graph: pick the Bash representation (associative-array tables vs. a generated dispatch) and prove one parameter can drive the wizard prompt, flag parsing, `--help`, and default — from a single node definition — plus the plugin-contributed-subtree seam. Deliverable is the documented decision + a throwaway proof, not production code.

- [x] Prototype a node schema `{name, applicability, choices, default, flag, env, owner, required}` and a walk that prunes on prior answers.
- [x] Prove the same node generates an interactive prompt **and** a non-interactive flag resolution.
- [x] Prove a plugin can contribute a subtree (Python's `backend → version-mgr → version`).
- [x] Write up the chosen representation + risks; feed P.f/P.g/P.h.

**Outcome.** Full write-up: [spike-p-e-decision-graph.md](spike-p-e-decision-graph.md). Throwaway proof: [`scripts/spike_decision_graph.sh`](../../scripts/spike_decision_graph.sh) (runs clean under `/bin/bash 3.2.57`, `set -euo pipefail`; never sourced by `pyve.sh`; delete when P.g retires the four scattered sites). Headlines:

1. **Representation decided — indexed array of pipe-delimited rows, not associative-array tables.** The latter is *ruled out by construction*: `declare -A` needs bash 4.0+, macOS is bash 3.2, and pyve's own suite ([test_bash32_compat.bats](../../tests/unit/test_bash32_compat.bats)) fails the build on `declare -A`/`local -A`. The table is walked at runtime so every sink reads one live artifact (beats codegen'd dispatch, which duplicates data and can't be introspected for `--help`/drift).
2. **Schema needs a 9th field — `label`.** You can't generate a wizard prompt or a `--help` line without human text. Computed fields use an `@fn` indirection (the row names a function that reads prior answers) — that's how "Backend choices/default are a function of Language + an `environment.yml` heuristic" becomes *data*, not a branch.
3. **`--help` is a distinct traversal from wizard/flags** (mid-spike finding): help is static with no prior answers, so it must enumerate *all* nodes annotated with their condition — not run the answer-pruning walk. P.g must build help as its own enumeration pass.
4. **Risks 1–6 carried forward** to P.f/P.g/P.h (multi-condition applicability, boolean/negation flags as a node kind, delimiter-collision guard, per-field `cut` cost, the plugin contribution hook on `contract.sh`, shared validation/required-resolution). Verdict: viable, low-risk — the bash 3.2 constraint forces the cleaner design.

**Version:** v3.1.0 bundle (Subphase P-1). Spike — throwaway (no version bump, no CHANGELOG entry: no shipped behavior; the proof is quarantined in `scripts/` and excluded from the package).

---

### Story P.f: Parameter decision-graph — core model & walk engine [Done]

Build the conditional decision-graph engine (per the P.e spike): nodes with applicability predicates, computed choice sets, *versioned* defaults, and flag/env/owner/required metadata; a top-down walk that prunes irrelevant nodes and narrows choices from prior answers. This is the single source the wizard, flag parser, `--help`, defaults, explicit-manifest writer, and drift detector all consume.

- [x] Implement the node registry + walk engine (interactive prune + non-interactive flag resolve from the *same* graph).
- [x] Framework-owned top nodes (Language, project-guide, `.env`/direnv) + the contribution seam for plugin subtrees (P.h).
- [x] Unit tests for pruning, computed choices, and flag-vs-prompt equivalence.

**Implementation.** New framework module [`lib/param_graph.sh`](../../lib/param_graph.sh) (sourced explicitly in [pyve.sh](../../pyve.sh) after `version.sh`), driven by [tests/unit/test_param_graph.bats](../../tests/unit/test_param_graph.bats) (28 cases). Per the P.e spike, the graph is an **indexed array of pipe-delimited 9-field rows** (`name|owner|applicability|choices|default|flag|env|required|label`) walked at runtime — no `declare -A` (bash 3.2 / [test_bash32_compat.bats](../../tests/unit/test_bash32_compat.bats)).

- **Engine:** `pg_add_node` (9-field validation incl. the `|`-in-label guard), a membership-string answers accumulator (`pg_answer_set/get/reset`), applicability resolution (`*` / `key=val` / `@fn`), computed choices/defaults (`@fn`), and `pg_walk <source_fn>` — one traversal that prunes, then resolves each node via a pluggable value-source. **Default-application, choice-set validation, and `required`-enforcement live in the engine (one place)**, so the wizard and flag parser cannot diverge.
- **Two value-sources prove "one graph, two surfaces":** `pg_source_flags` (precedence flag → env → default) and `pg_source_prompt` (queued/TTY); a test asserts both produce identical answers when accepting defaults. Boolean/`--no-x` negation flags are deferred to P.g (spike risk #2).
- **Framework nodes + seam:** `pg_register_framework_nodes` (Language, project-guide, direnv) + `pg_register_contributor` / `pg_build_graph` — framework top nodes precede contributed plugin subtrees so Language prunes everything below. P.h wires this onto the plugin contract; P.g migrates the four scattered `pyve init` sites onto the engine.
- **Versioned-defaults anchor:** `pg_defaults_version` (`PYVE_PARAM_DEFAULTS_VERSION`) — the stamp P.k's drift detection keys off.

**Verification.** Red→green→refactor (the `eval`-based field unpack was refactored to inline `IFS='|' read` for shellcheck-cleanliness). `shellcheck -s bash lib/param_graph.sh`: clean. Full unit suite: **2065 tests, 0 failures** (exit 0). Loads under `/bin/bash 3.2.57` with `set -euo pipefail`; `pyve --version` unaffected.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; the subphase's final code story owns the bundled minor bump. No CHANGELOG entry yet (rides the bundle).

---

### Story P.f.1: Establish a clean `shellcheck` baseline across `pyve.sh` + `lib/` [Done]

*(Developer-requested housekeeping, 2026-06-27. Parked at the P.f.1 slot as a standalone, order-independent hygiene story — not a semantic child of P.f. Pre-existing shellcheck findings surface on **every** feature story's lint step (the mode's "run linting" beat), creating recurring noise that isn't owned by any story. Clear them once so future stories' lint steps only show findings the story itself introduced.)*

**Current baseline** (`shellcheck -s bash` over `pyve.sh` + every `lib/**/*.sh`, 2026-06-27): warnings/errors by code — **16× SC2034** (unused var), **6× SC2155** (declare+assign masks the command's exit status), **4× SC2206** (unquoted `$(...)`/array word-split), **2× SC2115** (`rm -rf "$x/"` with no empty-var guard — the highest-risk), **1× SC2064** (trap expands now, not on signal); plus info-level **6× SC1091** (source-not-followed), **4× SC2016**, **2× SC2086**, **1× SC2153**, **1× SC1003**. Per-file warning/error hotspots: `pyve.sh` (7), `lib/plugins/python/plugin.sh` (5), `lib/commands/self.sh` (3), `lib/version.sh` / `lib/micromamba_bootstrap.sh` / `lib/manifest.sh` / `lib/commands/env.sh` (2 each), `lib/utils.sh` / `lib/micromamba_env.sh` / `lib/envs.sh` (1 each). *(Counts are a snapshot — re-run at implementation time; P.f/P.g code is already shellcheck-clean and excluded.)*

**Approach — triage each finding into one of three buckets, never blanket-suppress:**
1. **Fix** — real defects or easy correctness wins. SC2115 first (guard `rm -rf "${x:?}/"` so an empty var can't target `/`), then SC2155 (split `local x; x="$(cmd)"` so the substitution's exit status isn't masked — the same pattern project-essentials already mandates for `pyve_toolchain_python`), SC2206 (read into arrays safely), SC2064 (single-quote the trap action).
2. **Suppress with a one-line justification** — intentional patterns. SC2034 for deliberately-exposed globals (matching the existing `# shellcheck disable=SC2034 # <reason>` idiom in `lib/manifest.sh` / `lib/ui/core.sh`), SC2016 single-quotes-on-purpose, SC2086 where word-splitting is wanted. Every disable carries a reason comment.
3. **Leave as documented info-noise** — SC1091 (source-not-followed) is unfixable without `-x`/`source=` directives the CI invocation doesn't pass; note it rather than chase it.

**Tasks.**

- [x] Re-run the tree-wide `shellcheck -s bash` and snapshot the current findings — 26 warning/error (18× SC2034, 3× SC2155, 2× SC2115, 2× SC2206, 1× SC2064).
- [x] Resolve all **warning/error**-level findings by the triage rule. **Fixed (correctness):** SC2115 → `rm -rf "${TARGET_BIN_DIR:?}/lib"` in [lib/commands/self.sh](../../lib/commands/self.sh) (×2); SC2155 → split declare/assign in [lib/micromamba_bootstrap.sh](../../lib/micromamba_bootstrap.sh) + [lib/micromamba_env.sh](../../lib/micromamba_env.sh); dead local `testenv_root` removed from [lib/commands/env.sh](../../lib/commands/env.sh); dead var `no_rebuild` removed from `self_migrate` (the `--no-rebuild` arm is now an explicit accepted-no-op). **Suppressed-with-reason (re-triaged from "fix" — shellcheck's suggestion would be a *bug* here):** SC2206 in [lib/version.sh](../../lib/version.sh) (intentional `IFS=.` split; `read -ra` would change empty-field handling in the comparison); SC2064 in [lib/commands/env.sh](../../lib/commands/env.sh) (the trap *must* expand `$name` now — it's a local not in scope when the trap fires). **Suppressed-with-reason (cross-file / eval / compat):** the 7 `pyve.sh` config globals (consumed by sourced `lib/commands/self.sh` etc.), `PYVE_INIT_TAIL_*` (read by `lib/init_composer.sh`), `PYVE_TESTENV_STATE_LAST_USED_AT` (read by `lib/commands/env.sh`), `key`/`item` in `manifest_get_plugin_attr` (referenced inside an `eval`), `env_name` in `write_vscode_settings` (`$1` for caller compat). Every disable carries a one-line reason.
- [x] Info-level handling: not gated by the guard (warning/error only) and documented as accepted noise in the guard's scope comment — SC1091 (source-not-followed) is unfixable without the `-x`/`source=` directives the CI invocation doesn't pass; the rest (SC2016/SC2086/SC2153/SC1003) are intentional or trivial. No blanket ignores.
- [x] Added the regression guard [tests/unit/test_shellcheck_clean.bats](../../tests/unit/test_shellcheck_clean.bats): runs `shellcheck -s bash` over `pyve.sh` + every `lib/**/*.sh`, asserts zero warning/error findings, prints the offenders on failure, and `skip`s when shellcheck isn't installed.
- [x] Full unit suite: **2073 passing** (incl. the new guard); the only 3 failures are the pre-existing environmental matrix tests (asdf lacks the default Python 3.14.6) — unchanged by this story. `pyve --version` unaffected; no behavioral change to any command.

**Follow-up (2026-06-27, shellcheck version skew).** The baseline was first validated against shellcheck **0.11.0** (local macOS), which is more lenient than the **0.10.0** preinstalled on the `ubuntu-latest` CI runner — so the guard passed locally but CI's 0.10.0 surfaced one extra finding: `SC2120` on `is_conda_lock_declared` ([lib/micromamba_env.sh](../../lib/micromamba_env.sh)) (an intentional optional `env_file` arg no caller passes). Suppressed with reason. Re-verified **0 warning/error under both 0.10.0 and 0.11.0**. Lesson: validate the guard against the CI shellcheck version (or pin it) — pinning the CI shellcheck version for determinism is a candidate hardening (still out of this story's CI-config scope).

**Out of scope.** The CI workflow's `... -exec shellcheck {} + || true` line ([.github/workflows/test.yml](../../.github/workflows/test.yml)) — flipping it to blocking is a separate call (the new bats guard already enforces cleanliness in the test suite). `tests/**` shellcheck findings (bats files trip SC1091/SC2329 by design — out of the `pyve.sh`+`lib/` scope). Any finding whose fix would change runtime behavior (raise it as its own story, don't smuggle a behavior change into a lint pass).

**Version:** v3.1.0 bundle (Subphase P-1) — hygiene, no version bump.

---

### Story P.g (split): Migrate `pyve init` wizard / flags / help onto the graph

*Split at implementation time (developer-directed) into the **P.g.1 → P.g.2 → ... → P.g.5** bundle below. Two scoping decisions taken at the split: **(1) flag coverage = parameter subset.** Only the ~5 true decision-graph parameters — `--backend`, `--python-version`, `--project-guide`/`--no-project-guide`, `--no-direnv` (direnv), `--env-name` — are generated from the graph. The ~14 operational toggles (`--force`, `--strict`, `--no-lock`, `--bootstrap-to`, `--node-path`, `--auto-install-deps`, `--no-install-deps`, `--local-env`, `--allow-synced-dir`, `--auto-bootstrap`, `--project-guide-completion`/`--no-`, the legacy `--update` hard-error) stay hand-parsed; `--help` and the valid-flag allow-list **merge** graph-generated + hand-maintained entries. **(2) Three-way split** by surface: non-interactive → interactive → cleanup. The original four sites being retired: `_init_wizard` ([plugin.sh:1181](../../lib/plugins/python/plugin.sh#L1181)), the flag `case` loop ([plugin.sh:1558](../../lib/plugins/python/plugin.sh#L1558)), the `unknown_flag_error` allow-list ([plugin.sh:1690](../../lib/plugins/python/plugin.sh#L1690)), `show_init_help` ([plugin.sh:2271](../../lib/plugins/python/plugin.sh#L2271)). The init parameter nodes are defined by a Python-plugin graph builder in this bundle; **P.h** later refactors that registration onto the plugin contract hook (this bundle does not pre-empt it).*

---

### Story P.g.1: `pyve init` non-interactive surface — flag parsing, valid-flag list, `--help` from the graph [Done]

Define the `pyve init` parameter-subset decision-graph (Python-plugin builder calling `pg_add_node`) and generate the **non-interactive** surfaces from it: flag resolution for the 5 parameters (via the engine's flag source), the merged `unknown_flag_error` valid-flag allow-list, and the merged `show_init_help` text. Operational toggles remain hand-parsed; the wizard is untouched in this story. Lands the boolean/`--no-x` negation handling deferred from P.f (for `--no-project-guide`, `--no-direnv`).

*Refined at implementation time: the parity surface is **substring-based** (the unknown-flag list and `--help` assertions check for flag tokens, not byte-exact text), so P.g.1 single-sources init's **static flag metadata** from the graph — the valid-flag allow-list and the simple `--help` Options lines. Flag *resolution routing* through the engine (replacing the hand `case` arms) and the boolean flag-**resolution** source move to **P.g.5**, where the hand parser is actually removed — keeping P.g.1 additive and low-risk (it changes generated metadata, not parsing behavior).*

- [x] Python-plugin graph builder (`_init_build_param_graph`) defines the 5 parameter nodes (backend, python-version, project-guide, direnv, env-name) with versioned defaults, the `environment.yml`→micromamba computed backend default (`@_init_detect_backend_default`), each node's full CLI flag-set, and a `--help` blurb.
- [x] Engine carries the generation inputs: an optional `help` field (`pg_node_help`) and a comma-list `flag` field (`pg_node_flags`). (Boolean `--x`/`--no-x` *resolution* — P.f risk #2 — lands in P.g.5 with the parsing routing.)
- [x] Generate the valid-flag allow-list (graph flag-sets ⊕ retained operational toggles ⊕ `--help`) via `_init_valid_flags` and route `unknown_flag_error` through it — the real DRY win (flag names single-sourced). `show_init_help` stays hand-authored (its text is the canonical doc, not duplicated metadata); byte-faithful help *generation* with per-flag metavars is deferred (revisited in P.g.5 if still wanted).
- [x] Parity + drift-guard tests: generated valid-flag set equals the current hardcoded set; a guard test asserts `show_init_help` mentions every graph param flag (help can't silently drift from the graph); unknown-flag tests green; full suite green.

**Implementation.** Engine ([lib/param_graph.sh](../../lib/param_graph.sh)): optional 10th `help` field + `pg_node_help` (falls back to `label`); comma-list `flag` field + `pg_node_flags`; `pg_add_node` now accepts 9- or 10-field rows. Python plugin ([lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh)): `_init_build_param_graph` (5 nodes) + `_init_valid_flags`; the `init` flag loop's `-*)` arm now builds its allow-list from `_init_valid_flags` instead of a hand-listed set. Tests: [tests/unit/test_param_graph.bats](../../tests/unit/test_param_graph.bats) (+8 engine cases, 33 total) and new [tests/unit/test_init_param_graph.bats](../../tests/unit/test_init_param_graph.bats) (5 cases incl. the set-equality parity test + drift guard).

**Verification.** Red→green per task. `shellcheck -s bash lib/param_graph.sh`: clean; no new findings in `plugin.sh` (the 6 pre-existing are at lines 1833/2185-2189, untouched — owned by [[P.f.1]]). Loads under `/bin/bash 3.2.57`. Full unit suite: **2072 passing**; the only 3 failures (`test_composed_init_matrix.bats` 157/159/160) are **pre-existing & environmental** — they run a real end-to-end `pyve init` that needs asdf Python 3.14.6 installed on the host (absent here), confirmed identical on the pre-change baseline via `git stash`. Not introduced by this story.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.g (.2–.4 plan): full wizard rewrite onto a `ui_select` value-source

*Approach chosen by the developer: the **full faithful rewrite** (the graph value-source drives the prompts; each parameter's bespoke rendering + side effects become per-node render/apply callbacks). The old P.g.3 was renumbered to **P.g.5** to free the P.g.3–P.g.4 range for an incremental migration. The parity surface is large (**80 tests** in [test_init_wizard.bats](../../tests/unit/test_init_wizard.bats), many asserting verbatim output strings + caller-variable side effects via dynamic scope), so the rewrite is split into small, each-step-green stories:*

- ***P.g.2*** — structural extraction: lift the 3 prompt bodies into `_init_prompt_*` functions, still called sequentially (zero behavior change).
- ***P.g.3*** — convert `_init_wizard` to a `pg_walk` over the param graph + a `ui_select`-bound prompt value-source that dispatches to the extracted renderers (order + applicability become graph data).
- ***P.g.4*** — refine/finalize: ensure the python-version picker and project-guide deps-skip read cleanly through the walk; confirm `_init_wizard` is fully graph-driven; parity sweep.

*Only the 3 parameters prompted today (backend, python-version, project-guide) are interactive; `direnv`/`env-name` stay flag-only (adding prompts would be a behavior change, not a faithful rewrite). Defaults single-sourcing + scattered-initializer removal remain **P.g.5**.*

---

### Story P.g.2: Wizard rewrite (1/3) — extract the three prompt bodies into `_init_prompt_*` functions [Done]

Pure structural refactor enabling the walk: lift the backend, python-version, and project-guide prompt blocks out of `_init_wizard` into `_init_prompt_backend`, `_init_prompt_python_version`, and `_init_prompt_project_guide`, called sequentially in the same order. Each function reads the wizard's `arg_*` locals and writes `backend_flag` / `python_version` / `VERSION_MANAGER` / `project_guide_mode` via the existing dynamic-scope contract — verbatim moves, **zero behavior change**. The TTY guard + `header_box` stay in `_init_wizard`.

- [x] Extract `_init_prompt_backend` (incl. `--backend`/manifest/auto/interactive precedence + caller `backend_flag` side effect).
- [x] Extract `_init_prompt_python_version` (backend-aware micromamba vs venv branches + version-manager picker + `set_local_python_version` side effect).
- [x] Extract `_init_prompt_project_guide` (flags + `.project-guide.yml` refresh + deps auto-skip + `project_guide_mode` side effect).
- [x] `_init_wizard` calls the three in order; all 80 `test_init_wizard.bats` cases + full suite green (no string or side-effect changes).

**Implementation.** [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh): `_init_wizard` is now `<TTY guard>` + `header_box` + three calls (`_init_prompt_backend` → `_init_prompt_python_version` → `_init_prompt_project_guide`) + `return 0`. The three prompt blocks moved verbatim into the new functions (each reading the wizard's `arg_*` locals and writing `backend_flag`/`python_version`/`VERSION_MANAGER`/`project_guide_mode` via dynamic scope, exactly as inline). No new tests (this is a behavior-preserving refactor; the existing 80 `test_init_wizard.bats` cases are the safety net).

**Verification.** `bash -n` clean; `shellcheck -s bash lib/plugins/python/plugin.sh` still 0 warning/error (guard green). `test_init_wizard.bats` **80/80**, `test_init_ui.bats` 3/3, `test_init_param_graph.bats` 5/5. Full unit suite: **2073 passing**; the only 3 failures are the unchanged pre-existing environmental matrix tests (asdf lacks default Python 3.14.6).

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.g.3: Wizard rewrite (2/3) — drive the prompts from the graph (node-order render-dispatch walk) [Done]

Replace `_init_wizard`'s three sequential `_init_prompt_*` calls with a graph-order walk that dispatches each interactive, applicable node to its `_init_prompt_<name>` render callback. Prompt order + applicability now come from the graph, not source position. `direnv`/`env-name` are flag-only (not prompted).

- [x] `_init_wizard` builds the graph (`_init_build_param_graph`) and walks `pg_list_nodes` in node order; for each **interactive** + **applicable** node it dispatches to `_init_prompt_${name//-/_}`. The here-string walk keeps the loop body in-shell so the renderers' dynamic-scope writes (`backend_flag` / `python_version` / …) propagate.
- [x] Interactivity is an explicit, legible predicate `_init_node_is_interactive` (backend / python-version / project-guide → prompted; everything else flag-only). Kept in the **wizard layer**, not the shared node-row schema, because interactivity is wizard-specific (direnv/env-name *are* applicable to flag resolution). One-line to extend for a future direnv prompt (add the name + define `_init_prompt_direnv`).
- [x] Behavior-parity: `test_init_wizard.bats` **80/80**, `test_init_ui.bats` 3/3; new seam tests in `test_init_param_graph.bats` (interactivity predicate + "every interactive node has a renderer"). Full suite green.

**Implementation note (deviation from the title's "pg_walk + value-source").** The bespoke renderers don't fit `pg_walk`'s value-resolution contract (they do their own ui_select + side effects + caller-var writes, not "return a value to validate/record") — `pg_walk` is the *flag* surface's tool. So the wizard uses a thin graph-order render-dispatch loop instead, which still makes the graph the single source of node identity + order + the interactive attribute (the actual goal). Required a test-harness fix: `setup_pyve_env` now sources `lib/param_graph.sh` before the plugin (mirroring `pyve.sh`), since the wizard now builds the graph at runtime.

**Verification.** `bash -n` clean; `shellcheck` guard green (0 warning/error). Full unit suite: **2079 passing, 0 failures.**

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.g.4: Wizard rewrite (3/3) — finalize the graph-driven wizard [Done]

Tidy the rewrite: confirm `_init_wizard` is fully graph-driven (no residual source-ordered prompt logic), the python-version picker and project-guide deps-skip read cleanly through the walk, and the per-node renderers are the single home for each parameter's prompt. Closing parity sweep + any project-essentials note on the wizard/graph contract.

- [x] Audited `_init_wizard`: it is fully graph-driven (arg-parse → TTY guard → `header_box` → build-graph → node-order render-dispatch walk → return). No residual source-ordered prompt logic or dead scaffolding. Tidied the three `_init_prompt_*` doc-comments to describe the graph-walk dispatch contract instead of the now-historical "extracted from _init_wizard" lineage.
- [x] Confirmed clean composition: the renderers are the **single** resolution home for each parameter (writing `backend_flag` / `python_version` / `VERSION_MANAGER` / `project_guide_mode` via dynamic scope). `init_project` feeds the wizard-resolved `backend_flag` into `get_backend_priority` as **Priority 1** — layered honoring, not duplicate resolution.
- [x] Project-essentials entry added — "`pyve init`'s parameters are single-sourced from the decision-graph — never re-create the 4-site pattern" ([docs/specs/project-essentials.md](../../docs/specs/project-essentials.md)): the keystone, parameters-vs-toggles, wizard-only interactivity, the bash-3.2 constraint, and how to add a parameter.
- [x] Full behavior-parity sweep: `test_init_wizard.bats` 80/80 + `test_init_param_graph.bats` 8/8; **full suite 2079 passing, 0 failures**; shellcheck guard green.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.g.5: Make the graph the live single-source of parameter defaults + drift-guard the parser [Done]

*Scope chosen at implementation time (developer-directed, **pragmatic** of three options). Reading the parser surfaced that (a) defaults already trace to single constants (`DEFAULT_PYTHON_VERSION`) / computed functions (`_init_detect_backend_default`) the graph references — there is no *harmful* default duplication, only graph defaults not yet **consumed**; and (b) genuinely **routing flag resolution through the engine** (removing the `case` arms) would require rewriting the load-bearing arg parser into a graph-driven tokenizer — high blast radius, modest DRY gain (flag names are already cross-checked graph↔parser by behavior). So P.g.5 makes the graph defaults **live** (consumed), keeps the hand case-loop as the parser, and adds a drift guard. Full flag-resolution routing is **dropped** (not deferred) — the cross-checking + drift guard make the residual name-presence-in-both benign.*

- [x] `init_project` derives the python-version default from the graph (`_init_param_default python-version` → `pg_resolve_default`) instead of re-referencing `DEFAULT_PYTHON_VERSION` directly — the graph is now the **consumed** default channel (the live consumer P.j/P.k build on). Functionally identical (the node default interpolates the same constant). Backend's default is already single-sourced via the graph's `@_init_detect_backend_default` reference; env-name/project-guide defaults are empty; nothing contrived to wire.
- [x] Drift guard: a bats test asserts **every graph param flag has an `init` arg-parser case arm** ([tests/unit/test_init_param_graph.bats](../../tests/unit/test_init_param_graph.bats)) — so graph↔parser stay in sync without merging them. Plus `_init_param_default` unit tests (resolves a node default; non-zero for an unknown node).
- [x] `unknown_flag_error` (valid-list) + the wizard (prompts/order) are graph-driven (P.g.1/P.g.3); `show_init_help` stays hand-authored (drift-guarded, P.g.1); the case-loop parser is retained by design. Project-essentials entry updated with the defaults-consumed/parsing-not-routed contract.
- [x] Full behavior-parity sweep: full suite **2082 passing, 0 failures**; shellcheck clean under **both 0.10.0 (CI) and 0.11.0 (local)**.

**Implementation.** New `_init_param_default <name>` helper ([lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh)) resolves a node's default from the graph; `init_project`'s python-version default now flows through it. Drift-guard + `_init_param_default` tests added. No version bump.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.g.6: Bugfixes surfaced during the P.g wizard/keystone work [Done]

*Catch-all bugfix story for issues found while landing P.g.1–5 (and the P.f.1 lint guard). Each item below is independently verifiable; the developer may add, drop, or re-prioritize at the announce gate.*

**Candidate fixes (confirm/triage at the gate):**

- [x] **kcov coverage job: bats failures under instrumentation (189/190 + others).** *Root cause (reproduced locally with kcov 43):* not a code bug — kcov instruments **every** nested bash subprocess by enabling xtrace (`BASH_XTRACEFD`/`PS4=kcov@…`), so the `run bash -c 'set -euo pipefail; …'` subshells several regression tests use exit non-zero **regardless of body**. Tests asserting that subshell's `status == 0` then false-fail (the 2 secondary-failure tests + the two `set -u` "unbound variable" tests). A local run also surfaced a *non*-set-e test failing under kcov (`_init_detect_backend_default`), confirming the false-failure class is broad and per-test guarding would be whack-a-mole. *Fix (developer-chosen):* the CI "Run Bats unit tests under kcov" step is now **non-gating** (`|| true`) — coverage is informational; correctness is gated by the regular "Bats" job (green, 2082). kcov still writes its coverage report. ([.github/workflows/test.yml](../../.github/workflows/test.yml)). A reusable `skip_if_kcov` helper was added to [tests/helpers/test_helper.bash](../../tests/helpers/test_helper.bash) as a standby opt-in (not wired — the non-gating step makes per-test guarding unnecessary). *(Relates to the parked "Fix pre-existing integration test failures" + kcov-coverage stories in `## Future`.)*
- [ ] ~~**shellcheck CI version pinning (hardening for the P.f.1 guard).**~~ **Deferred/dropped (developer-decided).** Purely preventive — the tree is verified clean under both shellcheck **0.10.0** (CI) and **0.11.0** (local), so no active failure remains (the one skew finding, `SC2120` on `is_conda_lock_declared`, was suppressed in P.f.1's follow-up). Pinning is CI surgery (install a fixed shellcheck on two runner OSes) for a non-active risk; re-open if version skew bites again.

**Outcome.** Item #1 (kcov coverage job) fixed; item #2 (shellcheck pinning) deferred. Regular full suite **2082 passing, 0 failures**. No behavioral change to shipped commands.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.h: Plugin contract — parameter/wizard contribution hook [Done]

Extend the plugin contract ([contract.sh](../../lib/plugins/contract.sh) — today 14 hooks, none for wizard/flags) with a hook that lets a plugin register its own subtree of the decision-graph, so Language→subtree pruning works and the wizard is no longer Python-hardcoded. Python contributes `backend → version-manager → version → test-env`; Node contributes `provider → runtime-manager`.

- [x] Add the contribution hook (default no-op, matching the subset-of-hooks design). — `register_params` (hook group 9) in [contract.sh](../../lib/plugins/contract.sh); silent no-op default, dispatched via the existing `plugin_dispatch` fallback.
- [x] Move the Python-specific nodes out of the framework wizard into the Python plugin's contribution. — `python_pyve_plugin_register_params` ([python/plugin.sh](../../lib/plugins/python/plugin.sh)) owns `backend → version-manager → python-version → test-env`; the framework rows (`language`/`project-guide`/`direnv` in `pg_register_framework_nodes`) carry no Python vocabulary. The composed graph is assembled by `plugin_build_param_graph` ([registry.sh](../../lib/plugins/registry.sh)) from framework nodes + every *active* plugin's subtree.
- [x] Node plugin contributes its subtree; a polyglot `Multiple` selection fans into both. — `node_pyve_plugin_register_params` ([node/plugin.sh](../../lib/plugins/node/plugin.sh)) owns `provider → runtime-manager`; subtree applicability gates on `@_python_param_active` / `@_node_param_active` (language ∈ {self, multiple}), so `--language multiple` keeps both subtrees.
- [x] Tests: a single-stack project prunes to the right subtree; polyglot composes both. — [tests/unit/test_plugin_param_contribution.bats](../../tests/unit/test_plugin_param_contribution.bats) (12 cases).

**Scope note (live-wizard wiring rides P.i/P.j).** This story delivers the *seam*: the contract hook, the per-plugin contributions, and the plugin-agnostic `plugin_build_param_graph` assembly with language pruning + polyglot fan-out (proven by tests). The live `pyve init` surface (`_init_build_param_graph` → flag parsing / `--help` / interactive `_init_wizard`) is **not** yet swapped onto this assembly — it stays on the existing Python-only builder so the CLI flag surface and prompt flow are unchanged here. Wiring the live wizard onto `plugin_build_param_graph` (introducing a `language` prompt, the Node flags, and polyglot init flow) lands with the manifest-authority + easy-mode-wizard work in P.i / P.j, which is where that behavior change belongs.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle. No CHANGELOG entry yet.

---

### Story P.i (split): `pyve.toml` is the sole config source — write the backend, migrate the read-sites, stop writing `.pyve/config` (v2-wiring removal)

*(Pillar I foundation. The "N-10 read-compat sweep" that ~8 O-series stories deferred — N-10 became Phase O, so the v2-wiring removal lands here in Phase P / v3.1.0. This is the **write**-side prerequisite + the **read**-migration + the **stop**-writing.)*

**Split rationale (recorded at implementation time, 2026-06-29).** The bare `P.i` was too large for one coherent commit: the real blast radius is **~172 `.pyve/config` touch-points across 13 files** (95 in [`python/plugin.sh`](../../lib/plugins/python/plugin.sh) alone), not the ~64 first estimated. Split into **P.i.1 → P.i.2 → P.i.8** in a deliberately safe order — **write** the manifest first (so it is authoritatively populated, while `.pyve/config` is *still* written, so every existing reader keeps working), then **migrate readers** onto the now-populated manifest, then **stop** writing `.pyve/config` once nothing reads it. Every intermediate state is fully functional; the story's "do together — each alone breaks the others" caveat is satisfied across the bundle rather than in one commit. The three-sided fix is one logical change delivered as three reviewable units.

---

### Story P.i.1: Write the resolved backend into `pyve.toml [env.root]` + fix the `--force` reinit gate on v3 projects [Done]

*The **write** side of the P.i bundle, plus the coupled high-severity `--force`-no-op fix (both are about `init`'s manifest authority on a `.pyve/config`-less v3 project). Keeps writing `.pyve/config` for now — the read migration (P.i.2) and the stop (P.i.8) follow.*

**Scope refinement (at implementation).** Per the authoritative project-essentials design ("A forced/refresh rebuild honors the manifest backend"), `[env.root]` carries **only `backend`** — python comes from `.tool-versions`/`environment.yml`, env_name from `environment.yml`'s conda metadata. So the Write side persists `backend` (not python/env_name) into `[env.root]`; that is the one fact `pyve status` keys off and the symptom's missing key.

**Discovered:** 2026-06-12, `nbfoundry-torch-smoke`. `pyve init --backend micromamba` (with `environment.yml` present) materialized the conda root env correctly (`.pyve/envs/root/conda`, 303 pkgs), yet `pyve status` reported **"Backend: not configured."**

**Symptom.** After `pyve init --backend micromamba`, `pyve.toml [env.root]` has **no `backend` key** (just `purpose = "utility"`), while the v2 `.pyve/config` holds `backend: micromamba` + `env_name: nbfoundry`. `pyve status` reads the manifest → "not configured"; `pyve check` / `pyve run` "work" only because they still read `.pyve/config`. The canonical file is empty of the one fact that matters.

**Second symptom (high-severity) — `pyve init --force` silently doesn't rebuild on a v3 project.** `init`'s destructive-rebuild branch is gated on `config_file_exists` ([plugin.sh:1729](../../lib/plugins/python/plugin.sh#L1729) — `if config_file_exists; then … PYVE_REINIT_MODE=force → purge`). On a v3-native project with no `.pyve/config` at start, the **entire reinit/purge block is skipped**, so `--force` falls through to "create if missing," finds the existing `.venv`, and prints `already exists, skipping` — the venv is **not** recreated (no "Force re-initialization: this will purge…" warning ever prints). Field-observed 2026-06-13 in the pyve repo: a `.venv` frozen at Python **3.14.4** survived `pyve init --force` while `.tool-versions` pinned **3.12.13**, leaving the project pin and the venv interpreter drifted with **no** command rebuilding it. So `--force` becomes a no-op for the env precisely when the project is v3-clean — `.pyve/config`-gating inverting `--force`'s documented "purges and recreates the main venv" contract. (The drift then goes *unflagged* by `pyve status` — the separate Phase P resolution-reasoning/heal pillar.)

**Root cause — config is split-brained; the canonical manifest is never written.**
- **Write:** `_init_write_pyve_toml` ([plugin.sh:881](../../lib/plugins/python/plugin.sh#L881)) **no-ops when `pyve.toml` exists**, and even on a fresh write hardcodes a backend-less `[env.root] purpose = "utility"` — it ignores `--backend` entirely. The resolved backend is routed only to `.pyve/config` ([plugin.sh:2014](../../lib/plugins/python/plugin.sh#L2014)).
- **Read:** ~64 sites (per O.g's blast-radius count: **57 `read_config_value` + 13 `config_file_exists`**, across 11 files) still read `.pyve/config`, not `manifest_load`. O.g migrated only `check` + `status`'s presence/backend reads.

So `pyve.toml` is *declared* canonical but is neither fully written by `init` nor fully read by the toolchain — `.pyve/config` remains the de-facto source of truth for the backend.

**Three-sided fix (do together — each alone breaks the others).**
1. **Write (prerequisite).** `init` persists the resolved backend (+ python / env_name) into `pyve.toml [env.root]`, on **both fresh and existing** manifests; replace the backend-less hardcoded template. Without this, stopping the `.pyve/config` write leaves the manifest empty and *every* reader reports "not configured."
2. **Read.** Migrate the ~64 `.pyve/config` read-sites onto `manifest_load` + accessors; remove the `v3.0-only: remove in N-10`-tagged read-compat synthesis in [lib/manifest.sh](../../lib/manifest.sh).
3. **Stop.** `init` no longer writes `.pyve/config`; delete its writers. `pyve.toml` becomes the **sole** declaration.

**Coordinates with:** O.g (partial read fix — `check`/`status` only — `[Done]`); O.d (made the `.pyve/config` write *consistent* with the resolved backend, but did **not** populate the manifest); O.o.* (the `inherit`/mirror-root path reads `.pyve/config` — moves to the manifest in this sweep); O.k (the parallel `pyproject [tool.pyve.testenvs]` lifecycle duality — separate reader, same "make the manifest authoritative" spirit).

**Out of scope (whole bundle).** The runnability-probe / `pyve heal` pillars (Act 2). The `pyproject [tool.pyve.testenvs]` → `pyve.toml` lifecycle migration (O.k bundle). Changing the `purpose`/backend vocabularies.

**P.i.1 tasks (write + `--force`).**

- [x] Reproduce (red): tests assert `pyve.toml [env.root].backend` is recorded on a fresh init and backfilled on an existing manifest, and that the `--force` gate fires on manifest presence. ([tests/unit/test_init_manifest_backend.bats](../../tests/unit/test_init_manifest_backend.bats), 11 cases; [tests/integration/test_reinit.py](../../tests/integration/test_reinit.py) `test_force_rebuilds_on_v3_only_project`.)
- [x] **Write:** `init` persists the resolved root `backend` into `pyve.toml [env.root]` — fresh via the heredoc template (`_init_write_pyve_toml` / `_init_write_pyve_toml_polyglot` gained an optional `backend` arg; the three scaffold call sites pass `venv` / `micromamba` / the advisory value), existing via a structure-preserving tomlkit in-place edit (`_init_manifest_ensure_root_backend` → new helper [lib/pyve_manifest_write.py](../../lib/pyve_manifest_write.py) `set-env-attr`, degrading to a silent no-op when tomlkit is absent). The backend-less hardcoded template is dropped for init (kept only for the no-arg unit form). (`.pyve/config` is *still* written in this story — the stop is P.i.8.) python/env_name deliberately not written (see scope refinement above).
- [x] **`--force` must force on a v3 project:** the reinit/destructive-rebuild gate now fires on `_init_is_reinit` (`config_file_exists` **OR** `pyve.toml` present), with `existing_backend` falling back to `_init_manifest_root_backend` when `.pyve/config` is absent. The interactive re-init menu stays gated on `config_file_exists` (it drives `update_config_version`); a v3-native non-force re-init falls through to the idempotent create path. Regression green: a `.pyve/config`-less v3 project with an existing `.venv` → `pyve init --force` **recreates** the venv (asserts rebuilt + "Force re-initialization", not `already exists, skipping`).
- [x] Tests: fresh + existing-manifest writes populate the manifest backend and validate clean under `manifest_load`; the `--force`-on-v3 integration regression is green. Full unit suite 2105/0; the two reinit integration tests pass.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

**Carried to P.i.2/P.i.8.** The interpreter-drift fixture (venv built on a different python than the pin → `--force` yields a venv on the pinned interpreter) is a deeper assertion folded into the read-migration/end-to-end work; the project-essentials note (`init` writes the manifest backend; gate fires on manifest presence) lands with P.i.8's docs sweep to avoid documenting an area P.i.2/P.i.8 then reshape.

---

### Story P.i.2: Migrate `pyve status`'s backend reads onto the manifest [Done]

*The first **read**-migration slice of the P.i bundle. Builds on P.i.1 (the manifest authoritatively records the backend), so consumers can switch to it safely.*

**Context:** see Story P.i.1 (Discovered / Symptom / Root cause) and the split rationale above.

**Staging — the read migration is keyed by *value*, not by file (recorded at implementation, 2026-06-29).** The ~78 `.pyve/config` reads are not a uniform swap: only `backend` maps to a manifest accessor (`manifest_get_backend root`, authoritative post-P.i.1); the other keys (`micromamba.env_name`, `venv.directory`, `python.version`, `pyve_version`) are **not** stored in the manifest and must each be re-sourced from their v3 home (`environment.yml` conda metadata, `resolve_env_path`, `.tool-versions`/`.python-version`, or dropped). Several `backend` reads are also *intentional* config priority-tiers (`get_backend_priority`) or config-write machinery (`version.sh`), which belong to the **stop** story, not here. So the migration is staged as **per-key sibling stories** (the developer opened P.i.3–P.i.99 by moving "stop" to P.i.8):

- [x] **P.i.2 (this story)** — `pyve status`'s backend reads (the literal symptom: `status` read `.pyve/config`). The three `_status_*` sites in [plugin.sh](../../lib/plugins/python/plugin.sh) (`_status_configured_python`, `_status_section_environment`, the integrations project-guide row). `show_status` already calls `manifest_load` first, and the read-compat synthesis makes `manifest_get_backend root` correct for **both** v3 and v2 projects.
- [x] Migrate the three `pyve status` backend reads onto `manifest_get_backend root`. Extracted a single `_status_backend` helper (DRY — the three reads were identical) called by `_status_configured_python`, `_status_section_environment`, and the integrations project-guide row in [plugin.sh](../../lib/plugins/python/plugin.sh). The non-status `backend` reads (activate hook, `update` guard, reinit gate) are untouched — they belong to later sibling stories.
- [x] Tests: [tests/unit/test_status_backend_manifest.bats](../../tests/unit/test_status_backend_manifest.bats) (4 cases) — `_status_backend` resolves micromamba/venv from a v3 manifest (no `.pyve/config`) and resolves a v2 (`.pyve/config`-only) project via the read-compat synthesis; plus a wiring guard that the three sites route through the helper, not `read_config_value`.

### Story P.i.3: Remaining pure `backend` runtime reads (`activate` hook, `pyve update`'s init-guard backend read) [Done]

*The pure-`backend` read slice of the P.i bundle (after P.i.2's `status` reads). Reorders the two remaining `.pyve/config`-first backend reads to manifest-first, with `.pyve/config` retained as a transitional fallback (removed wholesale in P.i.8). Safe because `manifest_get_backend root` is authoritative on v3 (P.i.1) and correct on v2 via the read-compat synthesis.*

- [x] **`.envrc` activate hook** — `python_pyve_plugin_activate` ([plugin.sh](../../lib/plugins/python/plugin.sh)) reads `manifest_get_backend root` first, falling back to `read_config_value "backend"`. Safe by ordering because `compose_project_envrc` calls `manifest_load` ([envrc_composer.sh](../../lib/envrc_composer.sh)) before dispatching activate.
- [x] **`pyve update` init-guard** — `update_project`'s backend read reorders to manifest-first; the "corrupt config" error becomes "Could not determine the project backend (manifest and .pyve/config both empty)." The *presence* gate above stays on `config_file_exists` — flipping it to manifest-aware presence is P.i.4. The `.pyve/config`-rewrite step downstream (`update_config_version` in [version.sh](../../lib/version.sh)) still reads `backend` from the config; that config-write machinery is P.i.8's, not this story's.
- [x] Tests: [tests/unit/test_activate_backend_manifest.bats](../../tests/unit/test_activate_backend_manifest.bats) (3 cases — venv/micromamba manifest with no `.pyve/config` drive the right section; the manifest outranks a contradictory config); [tests/unit/test_update.bats](../../tests/unit/test_update.bats) (updated the both-empty error assertion to the new message + a positive case proving the guard resolves from `pyve.toml` when `.pyve/config` omits the backend). Full unit suite 2113/0; shellcheck baseline unchanged (no new findings on the two edited reads).

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

### Story P.i.4: `config_file_exists` / `[[ -f ".pyve/config" ]]` presence gates → manifest-aware presence (control-flow-sensitive) [Done]

*Make the "is this an initialized Pyve project?" gates recognize a v3-native `pyve.toml`, so commands stop turning away (or mis-routing) a project that has no `.pyve/config`.*

**Scope finding (at implementation).** This was briefly split into a second `init`/`backend-detect` story; a survey found no standalone work there, so it stayed a single story. The `config_file_exists` / `[[ -f ".pyve/config" ]]` sites that are *not* touched here are already spoken for: config priority-tiers and the re-init menu are retained until the stop story (P.i.8); `micromamba.env_name` reads are P.i.5; `venv.directory` reads are P.i.6; and the plugin-active and status gates already read the manifest first (`.pyve/config` is only their v2 fallback). `pyve env` likewise already reads exclusively from the manifest. So the genuine v3-presence bugs reduced to **two** callsites: `lock` and `update`.

- [x] **`update` presence gate** — `update_project` ([plugin.sh](../../lib/plugins/python/plugin.sh)) gated "initialized?" on `config_file_exists` alone, so a v3-native project (only `pyve.toml`) was rejected with "No .pyve/config found." Flipped to `! config_file_exists && [[ ! -f "pyve.toml" ]]` (mirroring the shipped `_init_is_reinit` pattern); the error now reads "No pyve.toml or .pyve/config found." A v3-native project passes the gate (it still trips the later config-write step until the P.i.8 stop, but that is out of this story's scope).
- [x] **`lock` Guard 1 (venv rejection)** — `_lock_main_env` ([lock.sh](../../lib/commands/lock.sh)) wrapped its "venv projects don't use conda-lock" rejection in `if config_file_exists`, so on a v3-native venv project (no `.pyve/config`) the guard was skipped and the user fell through to a less-precise "environment.yml not found." Resolves the backend manifest-first (`manifest_get_backend root` → `.pyve/config` fallback; `manifest_load` runs pre-dispatch in [pyve.sh](../../pyve.sh)), so the venv rejection fires on v3 too. Micromamba and bare (no-manifest, no-config) projects are unaffected.
- [x] Tests: [tests/unit/test_lock_backend_manifest.bats](../../tests/unit/test_lock_backend_manifest.bats) (3 cases — v3 venv rejected, v2 venv still rejected via fallback, micromamba not mis-rejected); [tests/unit/test_update.bats](../../tests/unit/test_update.bats) (reworded the both-missing precondition to the new message + a positive case: a `pyve.toml`-only project passes the presence gate). Full unit suite **2117** tests; the 4 P.i.4 assertions green. shellcheck baseline unchanged (only the pre-existing SC2148 no-shebang note on the sourced files).

**Note (pre-existing, not P.i.4):** two `test_asdf_compat.bats` J.c cases (`PYVE_NO_ASDF_COMPAT=1 suppresses the guard`; `pyve run … VERSION_MANAGER=pyenv`) fail on a **clean tree** as well — an environmental asdf-state leak (the non-hermetic-test hazard in project-essentials), unrelated to this change. Candidate for a separate `debug`/P-2 test-isolation fix.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

### Story P.i.5: `micromamba.env_name` reads → v3 source (`environment.yml` metadata / resolve helpers) [Done]

*Route the consumers that read the micromamba env name straight from `.pyve/config` onto the v3 source — `environment.yml`'s `name:` metadata (per N.bf.14, the name survives only as conda env metadata, no longer keying the directory).*

**Design (at implementation).** The existing `resolve_environment_name` can't be reused: its Priority-4 basename fallback never returns empty, but several consumers treat **empty = "not configured"** (status prints it; purge/removal skip on empty). Added a purpose-built helper `resolve_micromamba_env_name` ([micromamba_env.sh](../../lib/micromamba_env.sh)): `.pyve/config` micromamba.env_name (config-first for read-compat) → else `environment.yml` `name:` → else empty (no basename fallback).

**Callsites — 9 consumers migrated, 4 read-sites intentionally left:**

- [x] Add `resolve_micromamba_env_name` + unit tests ([tests/unit/test_resolve_micromamba_env_name.bats](../../tests/unit/test_resolve_micromamba_env_name.bats), 4 cases: config, environment.yml fallback, config-wins priority, empty).
- [x] Migrate the 9 plugin.sh consumers (`activate`, `init` re-init, `purge`, `_purge_pyve_dir`, `update` vscode-refresh, `check`, `_status_env_micromamba`, `_status_section_integrations`, `run`) to call the helper. `_purge_pyve_dir` shed its now-redundant `config_file_exists` guard (the helper internalizes it).
- [x] **Coupled backend reads (necessary side-migration).** `purge`'s legacy-flat cleanup and `run`'s backend routing read the env name *nested under a config-based `backend` check*, so the env_name migration was inert on a v3-native project. Made those two local `backend` reads manifest-first (`manifest_get_backend root` → `.pyve/config` fallback) — the reads P.i.3 left behind when it migrated only `activate`/`update`.
- [x] **Left for the P.i.8 stop:** the Priority-2 config tier *inside* `resolve_environment_name` ([micromamba_env.sh](../../lib/micromamba_env.sh)); the tolerant read/migration helpers in [envs.sh](../../lib/envs.sh); and `self migrate`'s deliberate legacy read ([self.sh](../../lib/commands/self.sh)). ([utils.sh:774](../../lib/utils.sh#L774) was a false positive — the `read_config_value` doc comment.)
- [x] Behavioral + wiring tests: [tests/unit/test_status_micromamba_env_name.bats](../../tests/unit/test_status_micromamba_env_name.bats) — `pyve status` shows the `environment.yml` name on a v3-native micromamba project (was "not configured"); "not configured" preserved when neither source names it; grep-guard that no plugin.sh consumer reads `micromamba.env_name` from `.pyve/config`. Full unit suite **2124**; all P.i.5 assertions green; `test_run_backend_detection` intact (the `run` backend-coupling change did not regress detection). shellcheck baseline unchanged.

**Note (pre-existing, not P.i.5):** the same two `test_asdf_compat.bats` J.c cases still fail on a clean tree (environmental asdf-state leak) — unrelated; confirmed `run`-detection is unaffected.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

### Story P.i.6: `venv.directory` reads → v3 source (`resolve_env_path` / default) [Done]

*Route the consumers that read the root venv directory straight from `.pyve/config` through a single resolver, so they stop depending on `.pyve/config` (the read then lives in one place for the P.i.8 stop).*

**Design (at implementation).** Nothing in the v3 tree *writes* `venv.directory` (grep: only a `show_config` display line), and `resolve_env_path root` hardcodes `.venv` for venv — but a **custom** venv dir (`pyve init <dir>`) remains a tested v2 read-compat feature ([test_version.bats](../../tests/unit/test_version.bats) "custom venv directory"). So I preserved behavior (rather than hardcode `.venv` and break read-compat) with a config-first helper, mirroring P.i.5: `resolve_venv_directory` ([utils.sh](../../lib/utils.sh)) = `.pyve/config` venv.directory (transitional) → else `${DEFAULT_VENV_DIR:-.venv}`. Never empty.

- [x] Add `resolve_venv_directory` (in [utils.sh](../../lib/utils.sh), sourced first so every consumer can reach it) + unit tests ([tests/unit/test_resolve_venv_directory.bats](../../tests/unit/test_resolve_venv_directory.bats), 4 cases: custom config dir, v3 default, config-without-key default, plugin.sh wiring guard).
- [x] Migrate the 9 consumers: 7 in [plugin.sh](../../lib/plugins/python/plugin.sh) (`activate`, `init` re-init, `purge`, `update`, `check`, `_status_env_venv`, `_status_section_integrations`), plus [gitignore_composer.sh](../../lib/gitignore_composer.sh) `_gitignore_infra_block` and [version.sh](../../lib/version.sh) `validate_venv_structure`. Each drops its inline `read_config_value "venv.directory"` + `.venv` default for one `resolve_venv_directory` call. `purge` also shed its `config_file_exists`/`[[ -n ]]` custom-dir dance (the helper subsumes it — the `.pyve/config`-presence gate P.i.4 deferred here).
- [x] **Left for the P.i.8 stop:** the `venv.directory` read inside `validate_config_file` ([backend_detect.sh](../../lib/backend_detect.sh), config validation) and `self migrate`'s deliberate legacy read ([self.sh](../../lib/commands/self.sh)).
- [x] Full unit suite **2127**; all P.i.6 assertions green; the custom-venv-dir read-compat tests still pass (behavior preserved). shellcheck baseline unchanged. Same two pre-existing `test_asdf_compat.bats` J.c failures (clean-tree, unrelated).

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

### Story P.i.7: `python.version` reads → `.tool-versions` / `.python-version` [Done]

*Route the two consumers that read the pinned Python version onto a shared resolver so the `.pyve/config` read lives in one place for the P.i.8 stop.*

**Finding (at implementation).** Only 2 consumers read `python.version`, and both **already** tried `.tool-versions` → `.python-version` first, with `.pyve/config` only as the last fallback — so they already preferred the v3 source; they just duplicated the fragile pin-file parsing and each kept its own transitional config read. Like `venv.directory`, nothing *writes* `python.version` to config, but the config fallback is a tested read-compat feature ([test_python_command.bats](../../tests/unit/test_python_command.bats) "falls back to .pyve/config"), so I preserved it (dropped at P.i.8, not now).

- [x] Add `resolve_python_version` ([env_detect.sh](../../lib/env_detect.sh)) — returns `"<version>|<source>"` (source: `tool-versions` / `python-version` / `config` / empty), centralizing the `.tool-versions` → `.python-version` → transitional `.pyve/config` chain. Unit tests: [tests/unit/test_resolve_python_version.bats](../../tests/unit/test_resolve_python_version.bats) (5 cases: each source, precedence, config fallback, none).
- [x] Migrate both consumers ([plugin.sh](../../lib/plugins/python/plugin.sh) `python_show`, `_status_configured_python_venv`) to call the helper and map the `<source>` key to their own display label (`python show` uses `.tool-versions`; `status` uses `.tool-versions via asdf`). Existing `python show` / `status` behavior — including the config-fallback and precedence tests — preserved.
- [x] **Left for the P.i.8 stop:** the `python.version` read in `validate_config_file` ([backend_detect.sh](../../lib/backend_detect.sh)) and `self migrate`'s deliberate legacy read ([self.sh](../../lib/commands/self.sh)).
- [x] Full unit suite **2133**; all P.i.7 assertions green; no regressions. shellcheck baseline unchanged. Same two pre-existing `test_asdf_compat.bats` J.c failures (clean-tree, unrelated).

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

---

### Storybundle P.i.8-11: Stop writing `.pyve/config` + project-essentials [Planned]

*The **stop** side of the P.i bundle. Lands only after P.i.2 (nothing reads `.pyve/config` anymore), making `pyve.toml` the **sole** declaration.*

stop writing `.pyve/config`; remove the priority-tier + config-write-machinery `backend` reads, the `pyve_version` reads, and the `v3.0-only: remove in N-10` read-compat synthesis; project-essentials [Planned]

**Context:** see Story P.i.1 and the split rationale above.

### Story P.i.8: Stop writing `.pyve/config` [Done]

- [x] **Stop:** `init` no longer writes `.pyve/config` — removed both `cat > .pyve/config` heredocs (micromamba + venv branches) in [plugin.sh](../../lib/plugins/python/plugin.sh); `_init_scaffold_manifest` (pyve.toml) is now the sole declaration `init` creates.
- [x] Removed the **dead** `write_config_with_version` (zero callers) from [version.sh](../../lib/version.sh) + its 6 unit tests. `update_config_version` is *kept* (still used by the v2 re-init menu + `update`; its full removal rides P.i.9 with the pyve_version-read rework — the P.i.8↔P.i.9 boundary).
- [x] Guarded the `update` flow: the version-bump step only runs when `config_file_exists`, so `pyve update` on a v3-native project no longer aborts at step [1/5] (`update_config_version` returns 1 on missing config).
- [x] Tests: [tests/unit/test_stop_writing_config.bats](../../tests/unit/test_stop_writing_config.bats) (heredoc-absence guard + update-on-v3). Integration reconciled (**CI-verified only** — the harness mutates real `$HOME`): converted `init`-creates-`.pyve/config` assertions → `pyve.toml` in [test_subcommand_cli.py](../../tests/integration/test_subcommand_cli.py), [test_force_backend_detection.py](../../tests/integration/test_force_backend_detection.py), [test_reinit.py](../../tests/integration/test_reinit.py); seeded a legacy `.pyve/config` fixture in the re-init-menu tests (menu is config-gated read-compat); **deleted** the obsolete v2 `--force`-shows-detection-prompt tests (2 in `test_force_backend_detection.py` + all of `test_force_ambiguous_prompt.py`) — v3 `--force` honors the manifest (P.i.1), so those semantics are gone and already covered by `test_reinit.py`.
- [x] Full unit suite **2129/0** (only the 2 pre-existing `test_asdf_compat.bats` J.c clean-tree failures). shellcheck baseline unchanged.

**Note:** low risk to v2 projects — they still work via the read-compat fallbacks + synthesis (removed later in P.i.9-P.i.13).

### Storybundle P.i.9-12: Remove deprecated cruft

Remove the writers ([version.sh](../../lib/version.sh) `write_config_with_version` / `update_config_version` and the `init` writer at [plugin.sh:2014](../../lib/plugins/python/plugin.sh#L2014)).

- [x] Remove transitional fallbacks (P.i.9)
- [x] Remove resolver config-branches (P.i.10)
- [ ] Remove presence gates 
- [x] Remove get_backend_priority tier (P.i.9)
- [x] Remove validate_config_file (P.i.11)
- [x] Remove pyve_version reads (P.i.11)
- [x] Remove presence gates (P.i.12)

**Note: Consumers become manifest/v3-only; v2 still works via synthesis.**

*Order note: every slice below leaves `.pyve/config` readable **only** by the read-compat synthesis (`_manifest_synthesize_from_legacy`) + `self migrate` + the legacy-layout mover — so v2 projects keep working via synthesis until P.i.13 removes it. The synthesis populates only `backend` into the manifest; the non-backend resolvers fall back to v3 source files (`environment.yml` `name:`, `.tool-versions`/`.python-version`, `.venv`), which real v2 projects also have.*

### Story P.i.9: Remove the transitional `backend` fallbacks + the Priority-2 config tier [Done]

Backend now resolves from the synthesized manifest (`manifest_get_backend root`), so the `.pyve/config` backend reads added as transitional fallbacks (P.i.3–P.i.5) are dead.

- [x] Dropped the `[[ -z ]] && read_config_value "backend"` fallbacks in `python_pyve_plugin_activate`, `update_project`, `_lock_main_env` (Guard 1), `purge_project`, `run_command` ([plugin.sh](../../lib/plugins/python/plugin.sh), [lock.sh](../../lib/commands/lock.sh)) — manifest-first is now manifest-only. `update_project`'s "manifest and .pyve/config both empty" error message dropped the `.pyve/config` mention.
- [x] Removed `get_backend_priority`'s Priority-2 `.pyve/config` tier ([backend_detect.sh](../../lib/backend_detect.sh)) — with it gone the now-vestigial `skip_config` param was removed and its one `--force` preflight caller updated (the manifest reaches the resolver as the CLI-flag Priority-1, so `--force` still honors it). Dropped the `_env_resolve_backend` config fallback and flipped `_env_resolve_root_backend` to manifest-only ([envs.sh](../../lib/envs.sh)); routed `init`'s `existing_backend` and `validate_installation_structure` ([version.sh](../../lib/version.sh)) through `manifest_get_backend root`. `_status_section_project`'s backend read was already manifest-only (P.i.2) — no change needed.
- [x] Left the three exempt `.pyve/config` backend readers untouched (the read-compat synthesis `_manifest_synthesize_from_legacy`, `self migrate`, the legacy-layout mover), so v2 projects keep resolving via synthesis until P.i.13.
- [x] Tests: new [test_backend_fallback_removal.bats](../../tests/unit/test_backend_fallback_removal.bats) (per-function `declare -f` source-guards + a tree-wide fallback-idiom guard + `get_backend_priority` Priority-2-gone behavior + v2-via-synthesis behavior). Updated the P.i.1–P.i.4 wiring-guard comments (fallback → synthesis); rewrote the two `get_backend_priority` "config wins" cases in [test_backend_detect.bats](../../tests/unit/test_backend_detect.bats) to "config ignored"; and had the direct-call unit tests that seed only `.pyve/config` (`test_python_activate_emitter`, `test_python_plugin_activate`, `test_run_backend_detection`, `test_main_micromamba_env_layout`, `test_testenv_conda`, `test_version`) load the manifest, mirroring production (`main`/`compose_project_envrc` call `manifest_load` before these paths run).
- [x] Full unit suite **2142/2** (only the 2 pre-existing `test_asdf_compat.bats` J.c clean-tree baseline failures). shellcheck baseline unchanged (no new findings).

### Story P.i.10: Remove the resolver `.pyve/config` config-branches [Done]

The P.i.5–P.i.7 resolvers became v3-source-only. Unlike the P.i.9 backend removal (covered by the read-compat *synthesis*), these values are read straight from the v3 source files a real v2 project already has on disk — the synthesis only populates `backend`.

- [x] Dropped the `.pyve/config` branch from `resolve_micromamba_env_name` + `resolve_environment_name` (Priority-2, [micromamba_env.sh](../../lib/micromamba_env.sh)) → `environment.yml` `name:` only; `resolve_venv_directory` ([utils.sh](../../lib/utils.sh)) → the `.venv` default only (v3 has no per-project venv-dir override); `resolve_python_version` ([env_detect.sh](../../lib/env_detect.sh)) → `.tool-versions` / `.python-version` only. Routed `resolve_main_micromamba_path`'s env-name read ([envs.sh](../../lib/envs.sh)) through `resolve_micromamba_env_name` (the v3-source resolver) rather than a direct config read. (`remove_pattern_from_gitignore` had no direct config read — its pattern flows from `resolve_venv_directory`, so it became v3-only transitively.)
- [x] Removed the now-dead `config)` source arm from `python_show` and `_status_configured_python_venv` ([plugin.sh](../../lib/plugins/python/plugin.sh)) — `resolve_python_version` never returns the `config` source anymore.
- [x] Left the three exempt `.pyve/config` readers untouched (the read-compat synthesis, `self migrate`, the legacy-layout mover); `validate_config_file`'s venv.directory/python.version reads stay (removed with the whole function in P.i.11/P.i.12).
- [x] Tests: new [test_resolver_config_branch_removal.bats](../../tests/unit/test_resolver_config_branch_removal.bats) (per-resolver `declare -f` source-guards + v2-shaped projects resolving from their v3 source files). Rewrote the "reads `.pyve/config`" / "config wins" cases in [test_resolve_micromamba_env_name.bats](../../tests/unit/test_resolve_micromamba_env_name.bats), [test_resolve_venv_directory.bats](../../tests/unit/test_resolve_venv_directory.bats), [test_resolve_python_version.bats](../../tests/unit/test_resolve_python_version.bats), [test_env_naming.bats](../../tests/unit/test_env_naming.bats) to assert the v3 source is authoritative and a v2 config value is ignored. Fixed the five collateral direct-call tests that seeded a config-only value (`test_python_activate_emitter` custom-venv-dir + micromamba env-name-from-`environment.yml`, `test_python_command` `python show`, `test_run_backend_detection` N.j.1 main-env-from-`environment.yml`, `test_version` `validate_venv_structure`).
- [x] Full unit suite **2152/2154** (only the 2 pre-existing `test_asdf_compat.bats` J.c clean-tree baseline failures). shellcheck baseline unchanged (no new findings).

### Story P.i.11: Remove `pyve_version` reads, `validate_config_file`, and `update_config_version` [Done]

`pyve_version` was a v2 `.pyve/config` concept (`pyve.toml` carries no version), so all six reads and the machinery around them are gone.

- [x] Removed the 6 `pyve_version` `.pyve/config` reads: two rode their whole functions out (`validate_pyve_version` + `update_config_version`, [version.sh](../../lib/version.sh)); `check_environment`'s "Pyve version drift" check block and `_status_section_project`'s recorded-version rows were removed (status now shows a `Declaration:` row — `pyve.toml`, or `.pyve/config (legacy — run 'pyve self migrate')` for a v2 project — with no version); `init_project`'s `existing_version` and `update_project`'s `previous_version` reads were dropped ([plugin.sh](../../lib/plugins/python/plugin.sh)).
- [x] Removed `validate_pyve_version` ([version.sh](../../lib/version.sh), dead — test-only) and `validate_config_file` ([backend_detect.sh](../../lib/backend_detect.sh), dead — test-only) + their unit tests.
- [x] Removed `update_config_version` ([version.sh](../../lib/version.sh)) and the update-flow version step: `pyve update` dropped its `[1/5] pyve_version` step, renumbering the remaining steps `[1/4]`–`[4/4]`. **Re-init menu decision (flagged in the story):** reworked "option 1" *here* rather than deferring to P.i.13 — it drops the `update_config_version` call + the version display and becomes a clean in-place "keep the environment; create it if missing" path. The menu's *full* removal (the whole `config_file_exists` branch) stays for P.i.12/P.i.13; the rework was self-contained (no synthesis entanglement), so deferring bought nothing.
- [x] Tests: new [test_pyve_version_read_removal.bats](../../tests/unit/test_pyve_version_read_removal.bats) (tree-wide no-`pyve_version`-read guard, removed-function guards, per-function `declare -f` guards). Removed the obsolete direct-call tests (`validate_pyve_version`/`update_config_version` in [test_version.bats](../../tests/unit/test_version.bats) + [test_reinit.bats](../../tests/unit/test_reinit.bats), `validate_config_file` in [test_backend_detect.bats](../../tests/unit/test_backend_detect.bats)); converted the behavioral fallout — `pyve update`'s step-count/labels → `[N/4]` ([test_update.bats](../../tests/unit/test_update.bats), [test_stop_writing_config.bats](../../tests/unit/test_stop_writing_config.bats)), `pyve check`'s drift test → "ignores a v2 pyve_version" ([test_check.bats](../../tests/unit/test_check.bats)), `pyve status`'s version rows → `Declaration:` rows ([test_status.bats](../../tests/unit/test_status.bats)).
- [x] Full unit suite **2137/2139** (only the 2 pre-existing `test_asdf_compat.bats` J.c clean-tree baseline failures). shellcheck baseline unchanged (no new findings).

### Story P.i.12: Remove the dead presence gates + `pyve config`'s config read [Done]

Command code no longer probes `.pyve/config` presence directly. The v2-project detection those gates performed now routes through `_manifest_has_legacy_sources` (the surviving synthesis-detection helper), so a v2 project is still recognized during the read-compat window without a scattered `config_file_exists` gate — and removing the gates does **not** break v2 (the helper still keys off `.pyve/config`).

- [x] Rerouted the direct `.pyve/config` presence gates in command code through `_manifest_has_legacy_sources`: `_init_is_reinit`, the `init` re-init-menu branch, `update_project`'s init sanity check, `check_environment`'s "pyve project present" gate, `show_status`'s non-project fallback, and `python_plugin_is_active_in_project`'s v2 marker ([plugin.sh](../../lib/plugins/python/plugin.sh)); plus the env-command "not an initialized project" gate in [envs.sh](../../lib/envs.sh).
- [x] Reworked `show_config` (`pyve config`, [pyve.sh](../../pyve.sh)) — dropped the `config_file_exists` + `read_config_value "backend"` pair; it now `manifest_load`s and shows a single `Configured backend:` row from `manifest_get_backend root` (replacing the v2 `Config file (.pyve/config): yes/no` + `Config backend:` rows).
- [x] **Extension (dead-code cleanup, parallel to P.i.11's dead-validator removals):** removed the now-dead `validate_installation_structure` + `validate_venv_structure` + `validate_micromamba_structure` cluster ([version.sh](../../lib/version.sh)) — all three were test-only (no production callers) and existed to validate the obsolete `.pyve/config` structure, so their root `.pyve/config` presence gate had no live purpose. Removed their unit tests ([test_version.bats](../../tests/unit/test_version.bats) structure sections + the two `validate_installation_structure` cases in [test_backend_fallback_removal.bats](../../tests/unit/test_backend_fallback_removal.bats)). After this, the **only** surviving direct `.pyve/config` presence checks are the exempt trio: `_manifest_has_legacy_sources` + `_manifest_synthesize_from_legacy` ([manifest.sh](../../lib/manifest.sh)), `self migrate` ([self.sh](../../lib/commands/self.sh)), the legacy-layout mover ([envs.sh](../../lib/envs.sh)), and the `config_file_exists` definition itself.
- [x] Tests: new [test_presence_gate_removal.bats](../../tests/unit/test_presence_gate_removal.bats) (per-function `declare -f` guards that the 7 command-code functions carry no direct `.pyve/config` presence gate + `show_config` reads no config value + the exempt `_manifest_has_legacy_sources` still keys off `.pyve/config`). Behavior preserved for v2 (`.pyve/config`) and bare-dir cases — the existing `update`/`check`/`status`/plugin-active project-gate tests stayed green with no changes.
- [x] Full unit suite **2132/2134** (only the 2 pre-existing `test_asdf_compat.bats` J.c clean-tree baseline failures). shellcheck baseline unchanged (no new findings).

*Doc note: [tech-spec.md](../../docs/specs/tech-spec.md)'s module table still lists the removed `validate_*_structure` functions; that table's v3 reconciliation is a separately-planned story (see "Reconcile tech-spec.md command/module tables to the v3 plugin file-layout") and is intentionally out of scope here.*

### Story P.i.13: Remove the read-compat synthesis [Done]

**⚠️ The breaking step.** `pyve.toml` is now the **sole** declaration pyve reads. A legacy `.pyve/config`-only (unmigrated v2) project is treated as uninitialized — `manifest_load` yields the empty-config baseline. The v2 soft banner still nudges `pyve self migrate` (it uses `_self_migrate_detect_v2_sources`, independent of synthesis), and `pyve self migrate` still reads `.pyve/config` directly.

- [x] Removed the synthesis machinery from [manifest.sh](../../lib/manifest.sh): `_manifest_synthesize_from_legacy`, `_manifest_has_legacy_sources`, `_manifest_deprecation_warn_legacy`, the `manifest_load` synthesis dispatch, and all six `v3.0-only: remove in N-10` markers. `manifest_load` on a missing `pyve.toml` now resets to the empty baseline unconditionally. (Extended `_manifest_reset_state`'s SC2034 disable to the whole function — synthesis was the in-file consumer of some reset globals.)
- [x] Updated the 7 gates that P.i.12 routed through `_manifest_has_legacy_sources` to `pyve.toml`-only (dropping the v2 arm): `_init_is_reinit`, `update_project`, `check_environment`, `show_status`, `python_plugin_is_active_in_project` ([plugin.sh](../../lib/plugins/python/plugin.sh)), and the env-command init gate ([envs.sh](../../lib/envs.sh)). **Removed the entire v2 interactive re-init menu branch** (the `elif` in `init_project`) — the deferred "full menu removal" — plus the now-dead `_init_print_reinit_menu` / `_init_environment_yml_drifted` helpers, and simplified `check_environment`/`_status_section_project` (their v2 display branches became unreachable).
- [x] Removed the `v3.0-only`-tagged `|| is_env_declared` arm in `is_env_declared_or_reserved` ([envs.sh](../../lib/envs.sh)) — env recognition is now manifest-only. (`is_env_declared` the function stays; it's the separate pyproject `[tool.pyve.testenvs]` reader still used by `read_env_config`-based paths — that surface's full migration is its own work, per the O.k duality, not this story.)
- [x] Removed the exempt `.pyve/config` readers' last non-migrator use; the only surviving `.pyve/config` readers are now `self migrate` ([self.sh](../../lib/commands/self.sh)) and the legacy-layout mover ([envs.sh](../../lib/envs.sh)).
- [x] Tests: deleted `test_read_compat.bats` wholesale; new [test_synthesis_removal.bats](../../tests/unit/test_synthesis_removal.bats) (machinery-gone guards + `.pyve/config`-only ⇒ uninitialized behavior). Removed the "v2-works-via-synthesis" / removed-function assertions across the suite; converted the ~55 tests that merely *scaffolded* via `.pyve/config` or pyproject `[tool.pyve.testenvs.*]` to declare in `pyve.toml [env.*]` (testenv fixtures + a shared opt-in `create_pyve_toml` autoscaffold in [test_helper.bash](../../tests/helpers/test_helper.bash) for the check/status/update/emitter/run clusters). Where a command reads pyproject in an isolated subshell (the no-arg bulk-purge sweep), the fixture stays pyproject-only.
- [x] Full unit suite **2108/2110** (only the 2 pre-existing `test_asdf_compat.bats` J.c clean-tree baseline failures). shellcheck baseline unchanged (no new findings). *(Integration suite not run locally — it mutates the real `$HOME`; CI covers it. End-to-end `pyve.toml`-only verification across `status`/`check`/`run`/`lock`/`env` is P.i.14's task.)*

### Story P.i.14: project-essentials docs & wrap-up [Done]

The project-essentials file states that `init` writes the manifest backend and `.pyve/config` is gone; remove the read-compat entry and the `v3.0-only: remove in N-10` markers. *(Wrap-up of the P.i bundle — docs + end-to-end verification, no code change.)*

- [x] Updated [project-essentials.md](project-essentials.md) so every entry reflects that `.pyve/config` is neither written nor read in v3.1: the `update_project` command-table row (dropped the `.pyve/config` refresh claim); the canonical-declaration entry (added an explicit "`.pyve/config` fully retired; only `self migrate` + the legacy-layout mover still read it" paragraph); rewrote the deprecation-surface entry from "three layers" → "migrator + soft banner (read-compat retired)"; **removed** the now-discharged "`v3.0-only: remove in N-10` marker is the contract" entry (markers + synthesis were deleted in P.i.13); fixed the "No story/phase IDs" load-bearing-exceptions list (the N-10 markers no longer exist to except); and corrected the forced-rebuild entry's two stale clauses (`skip_config`/Priority-2 config tier removed in P.i.9; the rebuild no longer emits `.pyve/config`).
- [x] Confirmed a `pyve.toml`-only project (no `.pyve/config`) is fully functional end-to-end. Hand-built `pyve.toml`-only fixtures (venv + micromamba roots) and ran the dev binary (`./pyve.sh`): `status` shows `Declaration: pyve.toml`; `check` shows `✓ Configuration: pyve.toml`; `env list` reads the declared `testenv`; `run` executes in `.venv`; `lock` reads the manifest backend (venv → "for micromamba only"; micromamba → past the backend gate to the `environment.yml`-missing error). Every command reads `pyve.toml`, none demands or creates `.pyve/config`, none falsely reports "uninitialized". Grounding greps confirmed the only surviving `.pyve/config` code paths are `self migrate` ([self.sh](../../lib/commands/self.sh)) + the legacy-layout mover ([envs.sh](../../lib/envs.sh)); no write path exists.
- [x] Full unit suite **2110/2110** green (no failures — the two intermittent `test_asdf_compat.bats` J.c env-leak cases did not surface this run). Docs-only change: no `lib/`/`pyve.sh`/`tests/` edits, so the shellcheck baseline is unchanged and the "no `.pyve/config` write" / "`.pyve/config`-only ⇒ uninitialized" invariants stay guarded by the existing `test_stop_writing_config.bats` / `test_synthesis_removal.bats`.

**Note:** stale `.pyve/config` references also linger in `lib/` *code comments* (e.g. [init_composer.sh:35](../../lib/init_composer.sh#L35), several in [plugin.sh](../../lib/plugins/python/plugin.sh)); sweeping those is a code-comment cleanup outside this docs+verify story's scope and was not in the P.i.9–P.i.13 removal scope either — scheduled as **Story P.i.15** below.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

---

### Story P.i.15: Remove the v2 `.pyve/config` migration bridge — stub `self migrate`, drop the v2 banner + dead helpers [Done]

*Developer decision (2026-07-03): v2 is done. P.i.13 already removed read-compat, so the `self migrate` v2 bridge is now the **only** path a legacy `.pyve/config` project has forward — and the developer has judged that carrying that bridge (plus its soft banner and `.pyve/config` parsing helpers) is no longer worth the maintenance. Remove the **v2 bridge logic** but **keep the `pyve self migrate` verb** as a reserved, stubbed command so a future v3→v4 schema migration has a stable home. This makes `.pyve/config` unreferenced by any live logic — the comment sweep (P.i.16) then finishes the job cosmetically.*

**Behavioral note (release-worthy).** This sharpens the v3.1 break: after this story an unmigrated v2 project has **no automated migration path** and reads as uninitialized with no banner nudging it. The developer accepted this trade in place of maintaining v2 compat. Flag it for the v3.1.0 CHANGELOG at end-of-subphase.

**Grounding (verified at planning).** The [legacy-layout mover](../../lib/envs.sh) already carries a directory-scan fallback ([envs.sh:700-707](../../lib/envs.sh#L700-L707)), so dropping its `.pyve/config` read is behavior-preserving. The banner ([pyve.sh:664-681](../../pyve.sh#L664-L681) + sentinel helper + the dispatch `case` at [pyve.sh:729-732](../../pyve.sh#L729-L732)) is self-contained. After removal, `read_config_value` / `config_file_exists` ([utils.sh:773-820](../../lib/utils.sh#L773-L820)) have **zero** callers.

**Tasks.**

- [x] **Stub `self migrate` ([self.sh](../../lib/commands/self.sh)).** Remove the v2 `.pyve/config` + `[tool.pyve.testenvs.*]` parsing, the `.pyve/.v2-legacy/` backup/move, the `_MIGRATE_V2_*` reads, and `_self_migrate_detect_v2_sources`. Keep the `migrate` dispatcher arm + `show_self_migrate_help`; the command now reports "no migration applies for this version" and exits cleanly (a reserved verb, re-fleshed when a v3→v4 migration exists). Decide `--dry-run`/`--no-rebuild`'s fate (drop or accept-as-no-op) at implementation.
- [x] **Remove the v2 soft banner ([pyve.sh](../../pyve.sh)).** Delete `_pyve_maybe_show_v2_banner`, the sentinel-path helper, and the pre-dispatch `case` that calls it. Confirm `PYVE_QUIET` has no other consumer before removing its banner handling (grep first).
- [x] **Drop the mover's `.pyve/config` read ([envs.sh](../../lib/envs.sh)).** The scan fallback (700-707) already covers the flat-env location, so this is behavior-preserving; verify with the existing layout-mover tests.
- [x] **Remove the now-dead helpers ([utils.sh](../../lib/utils.sh)):** `read_config_value` + `config_file_exists` + their doc comments, once the three tasks above leave them callerless. Add a guard assertion (grep) that neither is referenced anywhere in `lib/`/`pyve.sh`.
- [x] **Docs.** Rewrite the [project-essentials.md](project-essentials.md) deprecation-surface entry (no banner, `self migrate` is a reserved stub, v2 config no longer recognized) and trim the canonical-declaration paragraph's "only `self migrate` + the mover still read `.pyve/config`" clause (now: nothing in logic reads it).
- [x] **Tests — removal is in scope.** *Dedicated files:* delete [test_v2_banner.bats](../../tests/unit/test_v2_banner.bats) wholesale; gut the v2-conversion cases in [test_self_migrate.bats](../../tests/unit/test_self_migrate.bats) and replace with **stub-behavior** cases (`pyve self migrate` on a v2 project no longer writes `pyve.toml` / creates `.v2-legacy`; exits cleanly with the reserved-verb message); remove the `read_config_value` / `config_file_exists` cases from [test_utils.bats](../../tests/unit/test_utils.bats) and (likely all of) [test_config_parse.bats](../../tests/unit/test_config_parse.bats). *Case-by-case review (~12 files that reference these surfaces incidentally):* the absence-guards that assert "X no longer reads `.pyve/config`" ([test_presence_gate_removal.bats](../../tests/unit/test_presence_gate_removal.bats), [test_backend_fallback_removal.bats](../../tests/unit/test_backend_fallback_removal.bats), [test_pyve_version_read_removal.bats](../../tests/unit/test_pyve_version_read_removal.bats), [test_resolver_config_branch_removal.bats](../../tests/unit/test_resolver_config_branch_removal.bats)) — some assertions go **moot** once the helper/function no longer exists to reference (a `declare -f` guard on a deleted function fails), so convert those to "function is absent" or drop them; plus any test that seeds a `.pyve/config` fixture purely as v2 scaffolding. *Integration (CI-verified, mutates real `$HOME`):* update the banner/migrate/helper references in [test_bootstrap.py](../../tests/integration/test_bootstrap.py), [test_venv_workflow.py](../../tests/integration/test_venv_workflow.py), [test_micromamba_workflow.py](../../tests/integration/test_micromamba_workflow.py), [test_reinit.py](../../tests/integration/test_reinit.py), [test_node_detection.py](../../tests/integration/test_node_detection.py). Keep the layout-mover tests green via the scan path. Full unit suite green; shellcheck baseline unchanged.

**Out of scope:** the stale-comment sweep (P.i.16); any v3→v4 migration *content* (the stub is intentionally empty); the `docs/specs/tech-spec.md` module-table reconciliation (separately planned).

**Done (2026-07-03).** `self_migrate` and its six v2 helpers (`_self_migrate_detect_v2_sources` / `_read_legacy` / `_render_pyve_toml` / `_extract_pyproject_testenvs` / `_backup` / `_summary`) collapsed to a reserved stub that prints "No migration applies for the current pyve schema" and writes nothing; `show_self_migrate_help` rewritten to describe the reserved verb. The v2 soft banner (`_pyve_maybe_show_v2_banner` + `_pyve_v2_banner_sentinel_path` + the pre-dispatch `case`, with its `PYVE_QUIET` gate) removed from [pyve.sh](../../pyve.sh). The legacy-layout mover now uses its directory-scan only ([envs.sh](../../lib/envs.sh)). `read_config_value` + `config_file_exists` deleted from [utils.sh](../../lib/utils.sh); **no code reads `.pyve/config` anymore** (only `purge`'s `rm -f` cleanup mentions it). Fixed two [plugin.sh](../../lib/plugins/python/plugin.sh) comments that named the deleted helpers (the broader stale-comment sweep stays P.i.16). Docs: rewrote the project-essentials deprecation-surface entry → "v2 is fully retired", trimmed the canonical-declaration + forced-rebuild entries, fixed a dangling wikilink + two stale `self migrate` mentions.
- **Tests:** new [test_self_migrate.bats](../../tests/unit/test_self_migrate.bats) (stub behavior + absence guards for the removed funcs/banner/helpers + a tree-wide grep guard that no code references them); **deleted** [test_v2_banner.bats](../../tests/unit/test_v2_banner.bats), [test_config_parse.bats](../../tests/unit/test_config_parse.bats) (only tested `read_config_value`), and [test_reinit.bats](../../tests/unit/test_reinit.bats) (a v2-era relic — every case either called a removed helper or was a hardcoded-string tautology; `_init_is_reinit` coverage lives in `test_init_manifest_backend.bats` + `test_presence_gate_removal.bats`); excised the config-helper cases from [test_utils.bats](../../tests/unit/test_utils.bats). Integration `.py` reconciliation deferred to CI (harness mutates real `$HOME`).
- **Gotcha (recorded):** reconstructing `pyve.sh` via `head/tail > tmp; mv` dropped its executable bit (mktemp is 644), so every `run "$PYVE_SCRIPT"` test hit `Permission denied` → a spurious 135-failure wave. `chmod 755` restored it; `git diff --summary` confirms no mode changes remain. Lesson: preserve `+x` when rewriting an executed script by reconstruction.
- Full unit suite **2035/2035** green (−75 from P.i.14's 2110 = the deleted/rewritten test files). shellcheck baseline unchanged (the three info notes at [utils.sh](../../lib/utils.sh) 576/761 + [plugin.sh:2774](../../lib/plugins/python/plugin.sh#L2774) are pre-existing, outside the edited regions). End-to-end verified on the binary: `self migrate` on a v2 dir writes nothing/exits 0; `status` shows no banner and reads the project as uninitialized.

**Behavioral note for the v3.1.0 CHANGELOG:** v2 (`.pyve/config`) projects have **no automated migration path** as of v3.1 — `pyve self migrate` no longer converts them and the v2 banner is gone; migrate by re-running `pyve init`.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

---

### Story P.i.16: Sweep stale `.pyve/config` code comments (the final tidy) [Done]

*Cosmetic close-out of the P.i bundle, after P.i.15 removes the last `.pyve/config` **logic**. P.i.8–P.i.15 removed the write, the reads, the read-compat synthesis, and the v2 bridge — but stale **code comments** (and one user-facing error string) still narrate the retired behavior. Comment-only sweep: no behavior change.*

**Note:** P.i.15 already deletes the migrator's v2 comments, the banner comments, and the `read_config_value`/`config_file_exists` helper doc blocks — so the keep-set collapses to just the mover's scan comment ([envs.sh](../../lib/envs.sh)) and the accurate v3.1 statement at [manifest.sh:50](../../lib/manifest.sh#L50), and the remaining fix-set is concentrated in [plugin.sh](../../lib/plugins/python/plugin.sh) + the composers. Re-survey `.pyve/config` mentions at implementation time (line numbers shift after P.i.15).

**Tasks.**

- [x] **Write the guard test first (red).** New `tests/unit/test_config_comment_sweep.bats`: grep `lib/` + `pyve.sh` for `.pyve/config`, **excluding** the sanctioned survivors (the [envs.sh](../../lib/envs.sh) layout-mover comment, [manifest.sh](../../lib/manifest.sh)'s "uninitialized" statement, and `purge`'s `rm -rf ".pyve/config"` cleanup line), and assert **zero** remaining references. Confirm it fails against the post-P.i.15 tree.
- [x] **Sweep [plugin.sh](../../lib/plugins/python/plugin.sh)** stale narration: the `init` header/flow comments claiming it "writes .pyve/config"; the `_status_*` / self-resolution doc block now sourcing from the manifest / v3 files; the synthesis-referencing comments — including the **story-ID-in-comment** "removed in P.i.3" (also a [[No story / phase IDs in code or comments — relocate the *why*]] violation); the foreign-backend-backup comments now keyed off the manifest; the `pyve_version`/return-doc mentions; and the bare-project fallback notes.
- [x] **Fix the user-facing stale string:** `log_error "Micromamba env_name not recorded in .pyve/config"` → point at the v3 source (`environment.yml` `name:`), matching the resolver's actual read path. *(Move earlier into P.i.15 if it's simpler to fix alongside the logic — it's user-facing, not just a comment.)*
- [x] **Sweep the single-site files:** [init_composer.sh:35](../../lib/init_composer.sh#L35), [envrc_composer.sh:210](../../lib/envrc_composer.sh#L210), [pyve_manifest_write.py:25](../../lib/pyve_manifest_write.py#L25), the `read_env_config` doc in [envs.sh](../../lib/envs.sh) claiming synthesis, and the `resolve_venv_directory` "v2 `.pyve/config`" doc tail in [utils.sh](../../lib/utils.sh).
- [x] Rewrites carry **no story/phase IDs** (state the *why* in self-contained prose); comment-only — full unit suite green (no count delta beyond the new guard test) + shellcheck baseline unchanged.

**Out of scope:** any *logic* change; the sanctioned survivors above; the `docs/specs/tech-spec.md` module-table reconciliation.

**Done (2026-07-03).** Swept **32 stale `.pyve/config` mentions** across 6 files → zero remaining except the 3 sanctioned survivors ([manifest.sh:50](../../lib/manifest.sh#L50) "uninitialized" statement, [self.sh:577](../../lib/commands/self.sh#L577) reserved-stub explanation, and `purge`'s `rm -rf ".pyve/config"` cleanup). Fixed 26 sites in [plugin.sh](../../lib/plugins/python/plugin.sh) (init "writes .pyve/config" comments → "scaffolds pyve.toml"; self-resolution + `run`/`status` backend-detection doc blocks → manifest/v3-source; foreign-backend-backup comments → manifest-keyed; the `pyve update --help` heredoc dropped the removed `pyve_version` refresh line + reworded the exit-1 failure text; the user-facing `log_error` now points at `environment.yml` `name:`) plus 5 single-site files ([init_composer.sh](../../lib/init_composer.sh), [envrc_composer.sh](../../lib/envrc_composer.sh), [pyve_manifest_write.py](../../lib/pyve_manifest_write.py), the `_env_*` docs in [envs.sh](../../lib/envs.sh), the `resolve_venv_directory` tail in [utils.sh](../../lib/utils.sh)). Also dropped the co-located story IDs on lines I rewrote (`N.av.2`, `Story N.bf.19`, `removed in P.i.3`, `Phase L audit T1-01`), per the no-story-IDs rule. New [test_config_comment_sweep.bats](../../tests/unit/test_config_comment_sweep.bats) grep-guard (excludes the 3 survivors) drove it red→green. Full unit suite **2036/2036** green (+1 = the guard test); shellcheck baseline unchanged (comment/string-only). No mode changes (Edit-only, no `mv`).

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle. **This story closes the P.i bundle** (`pyve.toml` is the sole config source; v2 `.pyve/config` fully retired in code and docs); next `[Planned]` is **Story P.j**.

---

### Story P.i.17: Retire the vestigial custom-venv-dir positional (bugfix) [Done]

*Bugfix surfaced by the CI integration suite (`test_venv_workflow.py::test_purge_with_custom_venv_dir`) after the P.i bundle. **Root cause:** the `pyve init <dir>` / `pyve purge <dir>` positional was a v2 knob — the custom dir was recorded in `.pyve/config` `venv.directory` and read back everywhere. P.i.6/P.i.10 retired that override (`resolve_venv_directory` returns `.venv` only) and P.i.13 removed read-compat, but **nobody removed init's positional handling**. So today `pyve init my_venv` produces a **broken** project: the venv is created at `my_venv/` ([plugin.sh](../../lib/plugins/python/plugin.sh) init `*)` arm) but the `.envrc`/`.gitignore` composers ignore the custom dir (they resolve `.venv`), and `pyve purge` (no arg) removes `.venv` and leaves `my_venv` behind — the CI failure. The feature is half-retired and yields an unactivated, un-gitignored, un-purgeable venv.*

**Decision (developer, 2026-07-03):** retire it — v3 has no per-project venv-dir override (it isn't even a node in the param decision-graph), so `pyve init` always uses `.venv`. A positional is a **hard error** (fail fast, matching v3's no-magic tenet), not a silent `.venv` fallback.

**Tasks.**

- [x] **Regression test first (red).** New [test_init_no_custom_venv_dir.bats](../../tests/unit/test_init_no_custom_venv_dir.bats): `pyve init <dir>` and `pyve purge <dir>` reject the positional (non-zero exit + "takes no positional arguments"; init also creates no `<dir>`/`.venv`). Confirmed red (purge accepted the positional pre-fix; the init pre-fix path was *not* run in bats because a full `pyve init` reaches project-guide provisioning and mutates real `$HOME` — same fix, verified green post-fix).
- [x] **init ([plugin.sh](../../lib/plugins/python/plugin.sh)):** the `*)` arm (`venv_dir="$1"`) now hard-errors; `venv_dir` stays `$DEFAULT_VENV_DIR` (`.venv`).
- [x] **purge:** the CLI positional is parsed in **`compose_purge`** ([purge_composer.sh](../../lib/purge_composer.sh)), not `purge_project` — `pyve purge` dispatches through the composer, which was forwarding the positional as a "venv directory (a Python-plugin concept)". Rejected it there; also hard-errored `purge_project`'s `*)` arm and dropped its now-dead `venv_dir_explicit` machinery (purge always resolves `.venv`). Internal `init --force` → `purge_project --keep-testenv --yes` is flag-only, unaffected.
- [x] **Help ([pyve.sh](../../pyve.sh)):** removed the `pyve init myenv  # Use custom venv directory` example.
- [x] **Tests:** removed `test_init_with_custom_venv_dir` + `test_purge_with_custom_venv_dir` ([test_venv_workflow.py](../../tests/integration/test_venv_workflow.py)) and `test_config_with_venv_directory` ([test_auto_detection.py](../../tests/integration/test_auto_detection.py)). `validate_venv_dir_name` + its unit tests kept (init still validates `.venv`). Full unit suite **2038/2038** green (+2 = the regression cases); shellcheck baseline unchanged. (Integration CI-verified — the harness mutates real `$HOME`.)

**Out of scope:** any positive `pyve init <dir>` meaning (e.g. "init the project in `<dir>`") — a separate design question; removing `validate_venv_dir_name` (still guards `.venv`).

**Noted (not fixed here):** the sibling `test_config_with_python_version` in [test_auto_detection.py](../../tests/integration/test_auto_detection.py) still seeds `.pyve/config` (a different retired v2 read, python.version). It passes vacuously via its own soft guard and is out of this bugfix's scope — a candidate for a broader integration-test `.pyve/config` cleanup.

**Version:** v3.1.0 bundle (Subphase P-1) — unversioned during work; rides the bundle.

---

### Story P.j: Explicit-by-construction manifest + easy-mode wizard [Done]

`pyve init` writes a **fully-explicit** `pyve.toml` — every manifest-native value recorded rather than left implicit, so the file is self-documenting and reproducible. Builds on P.i (the manifest is the sole source) + the graph (P.f knows all params + defaults). "Easy mode" is a wizard fast-accept path — permissiveness lives in the wizard, not the manifest.

**Scope decision (developer, 2026-07-03): manifest-native fields only.** `init` records every env's `purpose` / `backend` / `default` **explicitly** (no implicit/omitted values), with the graph supplying the default for `backend`. `python` stays in `.tool-versions` / `environment.yml`, `env-name` in `environment.yml` `name:`, and `direnv` / `project-guide` remain init-time actions — none are added to the manifest schema here. This keeps P.j a coherent slice with **no schema change and no reader migration**, and does not contradict the "`[env.root]` carries no python field" principle. Recording `python` / `env-name` as first-class manifest fields (north-star §4) is deferred to a follow-on once its reader-migration story lands.

- [x] `init` writes each `[env.<name>]` block fully explicit — `purpose` + `backend` + `default` on **every** env, in both `_init_write_pyve_toml` and `_init_write_pyve_toml_polyglot` ([plugin.sh](../../lib/plugins/python/plugin.sh)). The no-arg (unit-scaffold) form defaults `backend` to `venv` so the block is never backend-less. `[env.testenv]` records `backend = "venv"` explicitly even under a micromamba root (preserving — not changing — the resolved default). The Node-only writer ([init_composer.sh](../../lib/init_composer.sh)) has no `[env.*]` blocks, so it was already explicit and is unchanged.
- [x] Easy-mode: `pyve init --yes` / `-y` ([plugin.sh](../../lib/plugins/python/plugin.sh)) fast-accepts every wizard default — wired by setting `PYVE_INIT_NONINTERACTIVE=1`, which the wizard's existing per-prompt checks already treat as "resolve the default, no prompt" (even on a TTY). Registered in `_init_valid_flags`, documented in `show_init_help` (+ example). Explicit `--backend` / `--python-version` still win alongside `--yes`.
- [x] Tests: new [test_init_explicit_manifest.bats](../../tests/unit/test_init_explicit_manifest.bats) (every env carries purpose+backend+default, plain + polyglot, validates under `manifest_load`, writer idempotent, `--yes`/`-y` accepted). Integration (CI-verified): explicit-manifest, easy-mode, and byte-identical deterministic-replay cases in [test_venv_workflow.py](../../tests/integration/test_venv_workflow.py). Reconciled the one intentional shape-change (`test_init_manifest_backend.bats` no-arg case) and the `_init_valid_flags` frozen-set guard (`test_init_param_graph.bats`). Full unit suite **2046/2046** green; shellcheck baseline unchanged.

**Also (P.i.17 straggler fixed here):** `show_init_help` still carried a `pyve init myenv  # Custom venv directory name` example — a second copy of the custom-venv-dir help P.i.17 only removed from [pyve.sh](../../pyve.sh). Since `pyve init <dir>` now hard-errors, that example was removed (replaced with the `--yes` example) while editing this help block.

**Out of scope (this story):** any new schema key (`python`, `env_name`, `direnv`, `project_guide`); migrating readers off `.tool-versions` / `environment.yml`; the operational-state / `upgrade` verb / declarative env-recipe work (§5–6, separate stories).

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.k: Versioned defaults + drift surfacing (never retroactive) [Done]

A default is resolved once and frozen into `pyve.toml`; a Pyve-version default change never mutates an existing repo. The graph carries **versioned** defaults so a check surface can *report* a divergence with the new value, leaving the pinned value untouched.

**Design decision (developer, 2026-07-03): stamp-based drift.** Grounding surfaced that the *value*-comparison framing is undercut by P.j's scope: the only graph param the manifest pins is `backend`, whose default is **computed** (`@_init_detect_backend_default`) not a static versioned literal, while the params with static version-bumpable defaults (`python-version`, `direnv`) were *not* pinned into the manifest (P.j deferred them). So P.k uses the **set-level** stamp that already exists — [`PYVE_PARAM_DEFAULTS_VERSION`](../../lib/param_graph.sh) — recorded per-repo in the manifest and compared against the current stamp. This works regardless of which individual params are pinned.

**This is a mechanism story.** We are at defaults version **1** — no default has changed yet — so in production there is nothing to report. P.k builds and *tests* (via a simulated bump) the versioned-defaults + stamp + drift-surfacing machinery, ready for the first real default change.

- [x] **Version the defaults.** `pg_defaults_changelog` (data) + `pg_defaults_changed_since <ver>` (rows strictly newer than a given set) in [param_graph.sh](../../lib/param_graph.sh); changelog **empty at v1**. `PYVE_PARAM_DEFAULTS_VERSION` is the current set stamp (pre-existing anchor).
- [x] **Stamp the manifest.** All three writers (plain + polyglot [plugin.sh](../../lib/plugins/python/plugin.sh), node-only [init_composer.sh](../../lib/init_composer.sh)) record `pyve_defaults_version = "${PYVE_PARAM_DEFAULTS_VERSION:-1}"` in `[project]`. The Python helper ([pyve_toml_helper.py](../../lib/pyve_toml_helper.py)) reads it (empty on pre-P.k manifests) and emits `PYVE_PROJECT_DEFAULTS_VERSION`, reset + documented in [manifest.sh](../../lib/manifest.sh).
- [x] **Drift check (info, never applied).** `_compose_check_defaults_drift` ([check_composer.sh](../../lib/check_composer.sh)) — an **info-only** `[defaults]` section (never touches the severity verdict, mirroring `[pyve]` hosting): when the repo's stamp trails the current set it lists the changed defaults and points at `pyve init --force`; silent at the current set and on pre-P.k (unstamped) manifests.
- [x] **Tests.** New [test_defaults_drift.bats](../../tests/unit/test_defaults_drift.bats) (changelog + changed-since, incl. simulated bump) and [test_check_defaults_drift.bats](../../tests/unit/test_check_defaults_drift.bats) (info-only reporting, silent cases, returns 0); stamp writer/reader + **never-retroactive** (a `PYVE_PARAM_DEFAULTS_VERSION=999` bump leaves an existing manifest byte-identical) in [test_init_explicit_manifest.bats](../../tests/unit/test_init_explicit_manifest.bats). Integration (CI-verified): init stamps the version + a fresh project shows no `[defaults]` drift ([test_venv_workflow.py](../../tests/integration/test_venv_workflow.py)). Full unit suite **2062/2062** green; shellcheck baseline unchanged. No manifest-shape test needed reconciling — the new `[project]` line rides through cleanly.

**Out of scope:** pinning `python` / `env-name` into the manifest (still deferred); any *automatic* adoption of a new default (report-only).

**First real use:** when a baked-in default next changes, bump `PYVE_PARAM_DEFAULTS_VERSION` and append one row to `pg_defaults_changelog` — the drift surface then activates for every repo pinned at the older set.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l: Declarative env setup (megastory) — an `[env.<name>]` block describes *how the env is set up*, materialized in one shot [Done]

*(Pillar II core; folded in from the former Subphase P-3. **Megastory** — captured at altitude; decompose granularly at `plan_production_phase`. Pairs with the per-env runnability probe (now in `## Future`, Act 2): that story tells you an env is broken; this one makes rebuilding it a single declarative act.)*

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

**Decomposition (developer, 2026-07-04): seven ordered sub-stories, P.l.1–P.l.7 below.** Two decisions taken during the breakdown: (1) the cross-cutting **`--yes`/`--force` semantics sweep** goes **first** (P.l.1) so the later rebuild/purge verbs inherit the clean rule (`--yes` = skip the confirm prompt, uniform; `--force` = override a refusal / escalate to destructive, *not* a prompt-skip synonym); (2) the uniform-rebuild principle is **routing/signposting**, not namespace unification — and `pyve env purge root` routes to **`pyve purge`** (a purge, not a rebuild), while rebuild dead-ends route to `pyve init --force`. Flat composable directive keys (per the sketch); the ordered `[[env.<name>.setup]]` array-of-tables stays a documented escape hatch, not built. Migration is verified inside each relevant sub-story (single-key blocks are single-directive recipes) and swept in P.l.7.

**Out of scope (this megastory's framing).** The per-env runnability *probe* (the detection story, Act 2 — this consumes "is it set up right?" but doesn't define detection). Non-Python plugin directive vocabularies beyond stubs (each plugin's own follow-up). The `.pyve/config` read sweep (now Story P.i).

**Coordination.** Pairs with P.n (rebuild = restore): P.l makes the *declaration* fully describe an env; P.n makes `--force` restore the *operational state* on top of it. The "uniform per-env rebuild verb" principle here and P.q's `env purge` no-arg fix are the same consistency goal.

**Version:** v3.1.0 bundle (Subphase P-1). Decomposed into P.l.1–P.l.7 below.

---

### Story P.l.1: `--yes`/`--force` semantics sweep — one meaning each, across the destructive commands [Done]

*Cross-cutting UX foundation for the rest of P.l. Grounding (verified): `--force` carries **two unrelated meanings** today — (A) "skip the confirm prompt" in [`compose_purge`](../../lib/purge_composer.sh) (`--yes|-y|--force` are synonyms), `pyve env purge`, and `testenv prune`; and (B) "override a refusal / escalate to destructive" in `pyve env sync` (`--force` = also apply drops/flips, distinct from `--yes`) and `pyve init --force` (purge-and-rebuild). `pyve purge` accepts **both** `--yes` and `--force` redundantly; `pyve env purge` accepts `--force` but not `--yes`. `--force` is never **required** on a purge — interactively you get a y/N prompt, CI/non-TTY auto-skips.*

**The rule (teachable, pinned in project-essentials):**
- **`--yes` / `-y`** = "assent to the confirmation prompt" — do what you'd do anyway, no questions. Uniform across every prompt-bearing command.
- **`--force`** = "override a safety refusal / escalate to a more destructive action" (`init --force`'s rebuild, `sync`'s destructive changes). **Never** a prompt-skip synonym.

**Decision (implementation):** `--force`-as-prompt-skip is kept as a **deprecated alias that warns** for one release (not dropped) — the gentler break.

**Tasks.**
- [x] `pyve purge` ([purge_composer.sh](../../lib/purge_composer.sh)): `--yes`/`-y` = prompt-skip; `--force` split off as the deprecated alias (warns via `warn_force_prompt_skip_deprecated`, still honored).
- [x] `pyve env purge` (no-arg sweep, [env.sh](../../lib/commands/env.sh)): **gained `--yes`/`-y`**; `--force` now warns. (`pyve env purge <name>` deletes without a prompt, so flags are moot there — a separate consistency point for P.l.6.)
- [x] `pyve env prune`: gained `--yes`/`-y` (dispatcher forward + leaf parser); `--force` warns.
- [x] `pyve env sync` and `pyve init --force` left as-is — they already use `--force` in the override/escalate sense (verified conformant).
- [x] Shared `warn_force_prompt_skip_deprecated` ([ui/core.sh](../../lib/ui/core.sh)); help/usage strings updated; project-essentials records the one-meaning-each rule + command table. Tests: new [test_force_yes_semantics.bats](../../tests/unit/test_force_yes_semantics.bats) (prompt-skip via `--yes`, `--force` deprecation-warning path, across purge / env purge / env prune). Reconciled one over-broad proxy in `test_env_dispatcher.bats` (anchored the rename-nag check on its signature, not the bare word "deprecated"). Full unit suite green; shellcheck baseline unchanged.

**Also (P.i.17 straggler fixed here):** `show_purge_help` still advertised `pyve purge [<dir>]` / `custom_venv` (a second copy of the retired custom-venv-dir positional, like the `show_init_help` one caught in P.j) — `pyve purge <dir>` now hard-errors, so that was removed while adding the `--force` deprecation line.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.2: Schema + readers — add the `editable` directive, lift the source mutex, define directive order [Done]

Add `editable` to `KNOWN_ENV_KEYS` + the `manifest.sh` accessor + `emit` ([pyve_toml_helper.py](../../lib/pyve_toml_helper.py), [manifest.sh](../../lib/manifest.sh)). **Remove the `requirements ⊕ extra ⊕ manifest` mutex** (validator [pyve_toml_helper.py:353](../../lib/pyve_toml_helper.py#L353)). Define + validate the fixed directive order (conda `manifest` → `editable` → `requirements` → `extra` → packages) and keep closed-vocabulary validation. Flat composable keys. Single-key blocks stay valid (single-directive recipes).

- [x] `editable` added to `KNOWN_ENV_KEYS` + `_normalize_env` + `emit` (`PYVE_ENV_EDITABLE`); reader `manifest_get_editable` + reset + header doc in [manifest.sh](../../lib/manifest.sh).
- [x] **Mutex lifted** in `validate()` — the block is a composable recipe; the fixed materialization order (conda `manifest` → `editable` → `requirements` → `extra`) is documented at the removal site for P.l.3/P.l.4 to apply. Closed-vocabulary validation on the other axes unchanged.
- [x] Tests: new [test_env_directives.bats](../../tests/unit/test_env_directives.bats) (editable read; all-directives compose clean; single-directive back-compat). Converted the now-obsolete mutex-conflict case in [test_manifest.bats](../../tests/unit/test_manifest.bats) into a composition case. Full unit suite green; shellcheck baseline unchanged.

**Note:** `editable` is now recorded + read, but not yet *materialized* — P.l.3 (venv materializer) is its first consumer. Until then a declared `editable` validates and round-trips but installs nothing.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.3: venv materializer — compose the full directive recipe in one shot [Done]

`_env_install_venv` ([env.sh](../../lib/commands/env.sh#L99)) composes **all** declared directives in order instead of the current mutex-precedence pick-one; adds the missing `editable` step (`pip install -e ".[extras]"`). `pyve env init <name>` materializes the whole recipe. Existing single-directive blocks unchanged.

- [x] `_env_install_venv` rewritten as the composing materializer: the whole recipe is **validated up front** (requirements files exist, extra resolves) so a bad directive fails before any layer installs, then every declared directive materializes in P.l.2's fixed order (`editable` → `requirements` → `extra`). CLI `-r <file>` stays a full override; the no-declaration fallback chain (auto `requirements-dev.txt` → bare `pytest`) unchanged.
- [x] **One-shot init:** `env_init` now runs `_env_init_materialize_recipe` after `ensure_env_exists` — installs ONLY when the block declares at least one directive ("init installs what you declared, nothing you didn't"; the install fallback chain never fires from init). Venv-backed only; conda init already materializes its `manifest`, and the conda pip layer is P.l.4's mirror.
- [x] Plumbing: `editable` mapped from the manifest arrays into the lifecycle arrays (`PYVE_TESTENV_EDITABLE[]` in [envs.sh](../../lib/envs.sh)) + guarded `_env_editable_of` accessor (the v2 pyproject helper predates the directive and never emits the array).
- [x] Tests: new [test_venv_materializer.bats](../../tests/unit/test_venv_materializer.bats) (editable materializes; full-recipe ordering; the ml-datarefinery field scenario; validate-before-install on missing file / unresolvable extra; single-directive back-compat; CLI `-r` override; one-shot init materializes the recipe / installs nothing when nothing declared). Reconciled `test_testenv_init_name.bats`'s fixture to create the requirements files it declares (init now materializes them). Full unit suite green; shellcheck baseline unchanged.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.4: conda/micromamba materializer — compose directives (manifest first, then pip layer) [Done]

`_env_install_conda` composes the recipe: the conda `manifest` (`environment.yml`) layered first, then the pip layer (O.n) realizes `editable` / `requirements` / `extra`. Mirrors P.l.3's ordering for the micromamba backend.

- [x] `_env_install_conda` ([env.sh](../../lib/commands/env.sh)) composes the full pip recipe after the manifest sync — `editable` → `requirements` → `extra` in P.l.2's fixed order (conda `manifest` first), each layer installed into the env via `micromamba run -p` — replacing the pip layer's pick-one precedence (`_env_conda_pip_layer` retired; its logic folded into the materializer). CLI `-r <file>` stays a full override of the *pip layer* only; the manifest remains the conda base and always syncs.
- [x] Up-front recipe validation mirror: the pip directives (requirements files exist, extra resolves, CLI `-r` file exists) validate BEFORE the manifest sync, so a bad directive fails before any layer installs — including the conda solve (previously the sync ran first and pip-layer validation happened only after it).
- [x] One-shot init mirror: `_env_init_materialize_recipe` no longer early-returns on micromamba — a conda env with declared pip directives materializes them at `pyve env init <name>` (the `manifest` already lands via create; the install path re-syncs it first, idempotently, so the layers land in order; no declared pip directives → no pip layer and no redundant conda solve).
- [x] Tests: new [test_conda_materializer.bats](../../tests/unit/test_conda_materializer.bats) (full-recipe compose + ordering after the sync; editable-alone; validate-before-sync on missing requirements file / unresolvable extra; CLI `-r` pip-layer override with manifest still syncing; requirements-only back-compat; one-shot conda init materializes pip directives / stays quiet with none declared). Full unit suite green (2091 tests, 0 failures); shellcheck baseline unchanged.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.5: One-shot `--force` rebuild + `pyve init --force` root-only scope [Done]

`pyve env init <name> --force` = purge-and-rebuild in one shot (per P.l.1's `--force` = escalate/override meaning). `pyve init --force` **explicitly touches only the root env** — retire the silent "rebuild root, keep testenv" magic (the `purge_project --keep-testenv` coupling). Rebuild of a named env is its own `pyve env init <name> --force`.

- [x] `pyve env init [<name>] --force` = one-shot purge-and-rebuild ([env.sh](../../lib/commands/env.sh)): the dispatcher's `init` arm gains a sub-parser (`--force`, `--yes`/`-y`, optional `<name>`, any order); `env_init` escalates on `--force` — destructive-confirm gate (prompt on interactive stdin unless `--yes`; CI/non-TTY skips; `PYVE_FORCE_PROMPT=1` forces — the P.l.1 rule: `--force` escalates, `--yes` assents), then `purge_env_dir` + create + recipe materialization. `--force` on an absent env degrades to plain init (nothing to purge → no prompt).
- [x] `pyve init --force` states its root-only scope explicitly ([plugin.sh](../../lib/plugins/python/plugin.sh)): the force pre-flight warn/summary lines name the **root** environment and point named-env rebuilds at `pyve env init <name> --force`. Behavior unchanged — named envs under `.pyve/envs/` were already preserved; `purge_project --keep-testenv` stays as the internal mechanism, but the user-facing contract is now "init --force is root-only by definition", not an unstated favor.
- [x] Help surfaces: `pyve env --help` documents `init [<name>] [--force] [--yes]` + the rebuild semantics and re-frames the "preserved across init --force" note as the explicit root-only contract; `show_init_help`'s `--force` line states root-only scope + the per-env rebuild pointer.
- [x] Tests: new [test_env_init_force.bats](../../tests/unit/test_env_init_force.bats) (purge-and-rebuild happens; recipe re-materializes one-shot; prompt aborts on 'n' preserving the env; `--yes` skips the prompt; non-TTY proceeds promptless; absent env degrades to plain init without prompting; plain `init` never purges; help-surface assertions). Full unit suite green (2100 tests, 0 failures); shellcheck baselines unchanged on both edited files.

**Also (show_init_help stragglers fixed here, per the P.l.1 precedent):** the help still advertised the retired `pyve init [<dir>]` positional (the parser hard-errors on positionals) and the removed `--update` flag (hard-errors via `legacy_flag_error` pointing at `pyve update`); both removed, and the `--update` project-guide note now names `pyve update`.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.6: Uniform per-env repair — route each role to the right verb (no dead-ends) [Done]

Resolve the field dead-end without namespace unification (routing, per the developer's decision): `pyve env purge root` → signpost to **`pyve purge`** (a purge, not a rebuild); `pyve env init root [--force]` → signpost to `pyve init [--force]`; `pyve check` / heal route each role to its correct verb. A human never hits an unexplained rejection or has to know which namespace owns which env.

*Grounding (verified): the `root` rejection lived in `assert_env_name_actionable` ([envs.sh](../../lib/envs.sh)) — one generic, stale message ("It is not a testenv and cannot be created/installed/purged") for every verb, no routing. `pyve check`'s root-fault hints already routed correctly to `pyve init --force`; its default-testenv check conflated "present but structurally broken" with "pytest not installed" and sent both to `pyve test`, which cannot heal a gutted env.*

- [x] Verb-aware routing in `assert_env_name_actionable`: optional `<verb>` second arg; the `root` rejection keeps its selection-only base line (pinned by existing tests) and adds the per-verb signpost — `init` → `pyve init` (rebuild: `pyve init --force`), `purge` → `pyve purge`, `install` → `pyve init`, `run` → `pyve run <command>`, no-verb → the full routing map. The dispatcher's four gate sites ([env.sh](../../lib/commands/env.sh)) pass their verb.
- [x] `pyve check` routes the default-testenv fault by kind: Check 16 factored into `_check_default_testenv` ([plugin.sh](../../lib/plugins/python/plugin.sh)) — present-but-broken (no runnable python — runnability probe, not existence) → `pyve env init testenv --force`; present-but-pytest-missing keeps `pyve test`; healthy passes; absent stays silent.
- [x] `pyve env --help`'s reserved-names note carries the root routing map so the namespace boundary is discoverable before the rejection.
- [x] Tests: new [test_env_root_routing.bats](../../tests/unit/test_env_root_routing.bats) (per-verb signposts for init/install/purge/run root; no-verb routing map; "selection-only" pin preserved; check-helper fault classification: broken vs pytest-missing vs healthy vs absent; help routing map). Full unit suite green (2111 tests, 0 failures, run under `bats --jobs 8`); shellcheck baselines unchanged on all three edited files.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.7: Migration verification + docs + project-essentials wrap-up [Done]

Prove existing `requirements`/`extra`/`manifest`-only blocks still materialize (as single-directive recipes) end-to-end. Document the directive vocabulary + ordering, the one-shot rebuild model, and the routing map; add the project-essentials entries (declarative-recipe model; the `--yes`/`--force` rule table from P.l.1). Closes the declarative-recipe arc of the P.l bundle (P.l.1–P.l.6); the test-infrastructure riders P.l.8–P.l.11 follow as their own arc.

**Also: sweep the story/phase-ID comments the P.l bundle itself introduced** — the "No story / phase IDs in code or comments" essentials rule was violated during P.l.1–P.l.3 (caught at the P.l.4 gate). ~22 sites: `# Story P.l.x:` leaders and bare `P.l.x` refs across [env.sh](../../lib/commands/env.sh), [envs.sh](../../lib/envs.sh), [manifest.sh](../../lib/manifest.sh), [pyve_toml_helper.py](../../lib/pyve_toml_helper.py), [ui/core.sh](../../lib/ui/core.sh), [purge_composer.sh](../../lib/purge_composer.sh), and six bats files (test_force_yes_semantics, test_env_directives, test_venv_materializer, test_manifest, test_testenv_init_name, test_env_dispatcher). Rewrite each as self-contained prose (state the *why*, no ID); keep any ref that is genuinely load-bearing per the rule's exception list. Enforcement grep: `grep -rn 'P\.l\.[0-9]\|Story P\.l' lib/ pyve.sh tests/`.

- [x] Verification: every single-directive block shape still materializes — venv `requirements`-only / `extra`-only and conda `manifest`-only / `requirements`-only were already pinned by existing suites; close the one gap (conda `extra`-only, the old precedence-3 path) with a test in test_conda_materializer.bats. Confirm the surviving mutex test (test_testenv_venv_manifest.bats "only one of") targets the v2 `[tool.pyve.testenvs]` reader — v2 keeps its mutex; only `pyve.toml` composes.
- [x] Docs (docs/site): [pyve-toml.md](../site/pyve-toml.md) gains the setup-directive vocabulary (composable recipe, the fixed order conda `manifest` → `editable` → `requirements` → `extra`, the `editable` directive, a worked example); [environments.md](../site/environments.md) gains the one-shot rebuild model (`pyve env init <name> --force`) + the root/named verb routing map, and fixes the now-stale "created empty (no dependencies)" line (init materializes declared directives since P.l.3).
- [x] project-essentials: new "declarative-recipe" entry (an `[env.<name>]` block is a composable setup recipe; one command reproduces the env); extend the P.l.1 `--yes`/`--force` table with the `pyve env init [<name>]` row (`--force` = escalate to purge-and-rebuild).
- [x] Story-ID sweep executed: all 23 grep hits rewritten as self-contained prose (none proved load-bearing); enforcement grep returns zero hits.
- [x] Full unit suite green (2112 tests, 0 failures, `bats --jobs 8`); shellcheck baselines unchanged on all five touched shell files; python helper compiles clean.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.8: Parallel unit suite — `bats --jobs` in the Makefile (measured: ~4–6 min → 1:37) [Done]

*(P.l.8–P.l.11 are the test-infrastructure arc: iterate on targeted suites, run the full suite at story gates, let CI be the ultimate arbiter. Motivated at the P.l.5 gate: 2100 unit tests today, a polyglot future of plugins (Rust, Go, C++, C#, React) heading toward 5–10×, and a mode cadence that runs the whole suite on every task iteration.)*

The suite is serial today (`bats tests/unit/*.bats`, one core, ~4–6 min). GNU parallel is installed; a grounding run of `bats --jobs 8 tests/unit/*.bats` completed all 2100 tests in **1:46.85** (335% CPU — bats parallelizes across files, so the largest files bound the win). Story: wire `make test-unit` to use `--jobs` when GNU parallel is present (serial fallback otherwise; job count from `PYVE_TEST_JOBS`, defaulting to a core-based value; tune the default — file-level granularity may reward more than 8 jobs), verify the suite is parallel-clean (fix or explicitly serialize any file that proves order- or state-dependent), record before/after wall times in the Makefile help, and adopt the same invocation in the CI workflow where the runner benefits.

- [x] `scripts/run-unit-tests.sh` — the one unit-suite entry point: `bats --jobs $PYVE_TEST_JOBS` (default: CPU count via `sysctl`/`nproc`) when GNU parallel is on PATH; serial fallback with a one-line install hint otherwise; actionable bats-missing error. `make test-unit` delegates to it; the kcov coverage job's direct serial bats call is intentionally untouched (coverage collection under parallel kcov is not supported).
- [x] CI: the unit-tests matrix job installs GNU parallel on both runners (`brew install … parallel` / `apt-get install -y … parallel`); it already runs `make test-unit`, so it inherits the parallel path — and degrades to serial by construction wherever parallel is absent.
- [x] Job-count default tuned on the 14-core dev machine: `-j 8` = 1:46.85 (335% CPU), `-j 14` = 1:37.31 (386% CPU) — CPU-count default confirmed (file-level granularity bounds further gains); recorded in the Makefile comments/help.
- [x] Tests: new [test_run_unit_tests.bats](../../tests/unit/test_run_unit_tests.bats) (parallel present → bats invoked with `--jobs <n>`; `PYVE_TEST_JOBS` override honored; parallel absent → serial invocation, no `--jobs`; bats absent → actionable install error). Full suite green (2116 tests, 0 failures, 1:37 wall); the new script shellchecks clean (zero findings).

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.9: Subsystem tags — `bats file_tags` vocabulary + targeted Make targets [Done]

Tag all ~166 unit-test files with a small closed subsystem vocabulary (`# bats file_tags=` — e.g. `env`, `init-wizard`, `purge`, `manifest`, `ui`, `micromamba`, `self-toolchain`, `plugin-python`, `plugin-node`, `completion`, `check-status`, `lock`), and add targeted Make entry points (`make test-tag TAG=<t>` via `bats --filter-tags`, plus shorthand targets for the highest-traffic groups). Add a drift guard that fails when any `.bats` file carries no `file_tags` line, so new files can't land untagged. Document the vocabulary in [testing-spec.md](testing-spec.md). Tags, not directory moves — zero `load`-path churn, and the same vocabulary can drive CI path-filtered jobs later (per-plugin suites when the Rust/Go/etc. plugins arrive; contract/registry/core changes still run everything).

- [x] Closed 11-tag vocabulary (settled at implementation): `env`, `init`, `purge`, `manifest`, `micromamba`, `plugin`, `check`, `self`, `ui`, `cli`, `core` — one tag per file (comma lists stay legal for future splits). All 169 unit files tagged via `# bats file_tags=<tag>` on line 2 (group sizes: env 389, init 322, plugin 318, core 278, check 145, cli 134, micromamba 109, manifest 88 tests, + self/ui/purge).
- [x] Drift guard: new [test_tags_guard.bats](../../tests/unit/test_tags_guard.bats) — every `tests/unit/*.bats` must carry a `file_tags` line AND every used tag must be in the closed vocabulary (typo'd tags fail the build). The guard file is the vocabulary's single source of truth in code.
- [x] Targeted entry points: `scripts/run-unit-tests.sh` honors `PYVE_TEST_TAGS` (adds `--filter-tags`); `make test-tag TAG=<t>` + shorthand targets for the highest-traffic groups (`test-env`, `test-init`, `test-plugin`, `test-check`).
- [x] Vocabulary + usage documented in [testing-spec.md](testing-spec.md) (which tag for a new file; targeted runs for iteration, full suite at gates, CI as arbiter).
- [x] Tests: guard red-first against the untagged tree (166 files reported), green after tagging; runner `--filter-tags` pass-through red→green in test_run_unit_tests.bats (parallel + serial paths); per-tag `--count` smoke recorded; `make test-tag TAG=purge` end-to-end (25 tests in seconds). Full suite green (2120 tests, 0 failures via `make test-unit`); the runner script shellchecks clean.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.10: Impact-map script — changed files → the test files that exercise them [Done]

`scripts/test-impact.sh`: from `git diff --name-only` (or explicit file args), extract the function names defined in the changed `lib/` files (`^name() {` is reliably greppable), and emit the union of (a) test files that reference any of those names, (b) name-convention matches (`lib/commands/env.sh` → `test_env_*.bats`, …), (c) a small always-run smoke set; `make test-impact` runs the selection. **Explicitly a heuristic for the inner loop** — bash has no import graph and pyve's function table is global, and the field record proves cross-module tails are real (the `python` function-shadow passed 725 unit tests and broke only in CI; the SIGPIPE `grep -q` bug surfaced only on the macOS runner in the full suite; the Bash-3.2 empty-array bug was invisible to bats entirely). The contract — impact selection per iteration, full suite at the story gate, CI as the final arbiter — is documented in [testing-spec.md](testing-spec.md) alongside the tag vocabulary.

- [x] `scripts/test-impact.sh`: changed files from explicit args (hermetic/testable) or `git diff --name-only HEAD` + untracked (default). Three selection channels, unioned: changed test files select themselves; changed `lib/`/`scripts/` shell+python files select test files that reference their path suffix (tests `source` what they exercise) OR any function name defined in them (one alternation grep per changed file); plus a fixed 2-file smoke set (test_cli_dispatch, test_tags_guard). `--list` prints the selection; default mode runs it.
- [x] `scripts/run-unit-tests.sh` accepts explicit test-file args (default: whole suite) so test-impact composes with the parallel/serial/tags logic instead of duplicating it; `make test-impact` wires it up.
- [x] The heuristic contract documented in testing-spec.md next to the tag vocabulary (impact per iteration, full suite at gates, CI as arbiter).
- [x] Tests: new [test_test_impact.bats](../../tests/unit/test_test_impact.bats) (lib change selects its suites + smoke; ui module selects its suite; changed test file selects itself; docs-only change → smoke set exactly; function-name channel reaches suites that never source the file; sorted-unique output) + runner file-args coverage in test_run_unit_tests.bats. Live-tree smoke verified (current diff → 4-file selection, correct). Full suite green (2126 tests, 0 failures via `make test-unit`); both scripts shellcheck clean.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.11: Test-cadence change request to project-guide — targeted per task, full at the gate [Done]

The code_test_first mode template's cycle runs the **full** test suite after every task (Step 3f) — the per-iteration cost that motivates P.l.8–P.l.10, and it compounds with suite growth. Per the "Cross-repo coordination — request, don't work around" protocol, write the change-request spec at `docs/specs/project-guide-requests/test-cadence-targeted-then-full.md`: propose the template cadence become *targeted/impacted suites per task; full unit suite once at the story gate; CI runs the whole matrix as the ultimate arbiter*, with rationale (measured costs, suite-growth projection) and compatibility notes (projects without an impact tool simply keep running the full suite). `go.md` is install output and is never hand-edited here; the new cadence lands when the corresponding project-guide release ships.

- [x] Spec written at [project-guide-requests/test-cadence-targeted-then-full.md](project-guide-requests/test-cadence-targeted-then-full.md), matching the established change-request format (problem statement / proposed change / motivation / suggested shape / compatibility): per-task beat becomes "run the tests impacted by the change" with the full suite required once at the story-gate beat; measured pyve numbers as the worked rationale; degrade-safe for projects without targeted tooling (full suite remains the valid default everywhere).
- [x] Spec-only story: no pyve code, no runtime surface, no go.md edits (install output; the cadence lands via a future project-guide release + `project-guide update`). Suite state unchanged from the P.l.10 gate (2126 tests green).

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.12: CI hang fix — the runner suite recursed into the real suite on Linux; refuse re-entrancy, isolate the test PATH [Done]

*(Debug story — root cause unknown until explored. Field report: the last 4 CI runs never completed; the developer cancelled them and captured the logs. Diagnosis from the logs: the ubuntu unit job printed test output up to the file alphabetically before test_run_unit_tests.bats, then went silent for ~3.5 hours until cancellation terminated an orphaned `make → bash → parallel → bash×N` process tree. The macOS unit job was actually green in ~8 minutes — the hang was Linux-only.)*

**Root cause.** test_run_unit_tests.bats (P.l.8) isolated the runner script's PATH as "system dirs only" (`/usr/bin:/bin:/usr/sbin:/sbin`) — an assumption that holds on macOS (homebrew installs bats/parallel outside those dirs) but not on Linux, where **apt installs the real `bats` and `parallel` into `/usr/bin`**. The "bats missing" scenario therefore found the real bats, took the real parallel branch, and `exec`'d the **entire real unit suite inside itself** — which re-runs test_run_unit_tests.bats, which re-launches the suite again: unbounded suite-inside-suite recursion. Under `bats --jobs` + `--keep-order`, the stuck job slot also silently buffered all downstream output. Reproduced locally by pointing the scenario's PATH at dirs containing the real tools.

- [x] **Re-entrancy guard (the class fix)**: `scripts/run-unit-tests.sh` exports `PYVE_RUNNER_REENTRY` and hard-errors ("refusing re-entrant invocation — a test suite must not run itself") if it is already set, so ANY future leak of this shape fails loudly in seconds instead of hanging CI for hours with orphaned parallel workers.
- [x] **Airtight test isolation (the instance fix)**: the suite's baseline PATH is now a per-test toolbox containing only the utilities the runner needs (`bash`, `dirname`) — real bats/parallel cannot leak in on any OS. The stubbed invocations explicitly clear `PYVE_RUNNER_REENTRY=` (the outer CI run sets it, by design).
- [x] Tests (red→green): the guard refuses when the sentinel is set (nothing invoked); an isolation pin asserts bats reads as missing on the toolbox PATH even on machines that have it installed. CI-shape scenario verified locally: real tools on PATH + sentinel set → instant refusal, rc 1.
- [x] Full unit suite green under the guard (the gate run itself executes with the sentinel exported, proving no false-fire); runner script shellchecks clean.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.l.13: CI flake fix — the idempotency test's stat idiom never measured mtime on Linux; assert with a sentinel instead [Done]

*(Debug story. After the P.l.12 hang fix, the ubuntu unit job ran to completion but failed one test: `ensure_env_exists: no arg is idempotent` (test_testenv_name_aware.bats) — a marker-mtime comparison. macOS passed.)*

**Root cause.** The test measured "was the env recreated?" via `stat -f %m <file> 2>/dev/null || stat -c %Y <file>`. That idiom is macOS-shaped: on BSD stat, `-f %m` is the file's mtime. On GNU/Linux, `stat -f` selects **filesystem-status mode** — the expression succeeds (so the `stat -c %Y` fallback never runs) but reports a filesystem attribute, not the file's mtime. It passed serially for years because the two reads, microseconds apart on a quiet machine, returned identical filesystem values; under `bats --jobs` the other workers churn the filesystem between the reads and the values diverge → flaky failure. Code behavior was correct throughout — `ensure_env_exists` provably takes no write path on the second call; only the measuring instrument was broken.

- [x] The test now asserts idempotency directly: plant a sentinel file inside the venv after the first call — a rebuild (`rm -rf` + re-create) would destroy it — then assert it survives the second call (plus the interpreter marker). Portable, deterministic, load-independent, and it tests the actual contract instead of a stat portability accident. Sole occurrence of the idiom in the tree (grep-verified).
- [x] Full unit suite green locally under `bats --jobs`; the definitive verification is the next CI run on ubuntu.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.m: Operational-state record — extend `.state` with an installed dimension [Done]

Record actual (vs. declared) env state so rebuild can restore it. The per-env `.state` store exists ([lib/envs.sh:387](../../lib/envs.sh#L387)) but is written only at **realize** (env dir built), never at **install** — so there's no "deps installed" bit (only a conda `manifest_sha256`; venv has nothing). Add an installed-spec hash for **both** backends and write `.state` from the install path, so realized-vs-installed is recorded, not re-derived from the filesystem. Stays `.pyve/`-resident — no `pyve.yaml`.

- [x] Extend the closed `.state` key set with `installed_at` (0 = realized only; >0 = install completed then) + `installed_sha256` (digest of the effective install spec via new `env_recipe_sha256` in [envs.sh](../../lib/envs.sh): editable target, requirements file contents, extra + pyproject, conda manifest; CLI `-r` replaces the declared pip recipe, mirroring the materializers). New `pyve_string_sha256` in [utils.sh](../../lib/utils.sh) (same no-weaker-hash contract as `pyve_file_sha256`). Pre-existing five-field `.state` files read as installed_at=0; `state_touch_last_used` preserves the new fields.
- [x] `state_mark_installed` ([envs.sh](../../lib/envs.sh)) written from every `_env_install_venv` success path (CLI `-r`, declared recipe, both fallbacks) and from `_env_install_conda` after all layers ([env.sh](../../lib/commands/env.sh)); preserves provisioning fields, creates a fresh record for pre-dimension envs, degrades to an empty hash when no SHA tool exists (the stamp still lands).
- [x] `pyve env list` STATE renders the recorded dimension: declared + on-disk shows **ready** only when installed_at>0, else **realized** (on-disk but recipe never installed). Pre-P.m installed envs show "realized" until their next install/test run re-stamps them — recorded truth, never a filesystem guess.
- [x] Tests: new [test_state_installed.bats](../../tests/unit/test_state_installed.bats) (8: schema round-trip; five-field back-compat; touch preserves; venv install stamps 64-hex digest; digest tracks requirements content; realize-only stays 0; conda install stamps with manifest in digest; list renders ready vs realized). One fixture reconciled in test_testenv_list_prune.bats (records installed_at, matching the new STATE contract). Full suite green (2134 tests, 0 failures); shellcheck baselines unchanged on all three edited lib files.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.n: Rebuild restores state; purge resets it [Done]

`pyve init --force` and `pyve env init <name> --force` **snapshot-then-replay** the operational-state record (P.m): re-realize and re-install whatever was realized-and-installed; leave a never-realized lazy env unrealized. Only `pyve purge` / `pyve env purge` truly destroys. Symmetry (P4): `pyve env init <name> --force` is to a named env what `pyve init --force` is to root.

- [x] `pyve env init <name> --force` snapshot-then-replays: `env_init` reads `.state` before `purge_env_dir`, and after the rebuild (a) restores the **installed dimension** — when the snapshot recorded installed but the declared-recipe materialization didn't re-install (no-directive envs whose install came from the fallback chain), the install path re-runs so the env comes back installed, freshly re-stamped; and (b) restores **usage provenance** — `last_used_at` carries over from the snapshot (`state_touch_last_used` gains an optional epoch arg). A realized-only snapshot (installed_at=0) replays as realized-only: no install fires.
- [x] Root-side: `pyve init` / `pyve init --force` leave a never-realized **lazy** default testenv unrealized — `_init_testenv_to_materialize` now skips a `lazy = true` default (previously eagerly realized it empty). Non-default declared envs were already untouched by init; named envs already survive root `--force` via the keep-envs purge.
- [x] Purge is the only true destroy: `pyve env purge <name>` removes `.state` with the env root — pinned explicitly.
- [x] Tests: replay restores installed+last_used_at on a declared-recipe env; fallback-installed (no-directive) env re-installs on `--force`; realized-only env stays realized-only (no install replay); lazy default skipped by the init materializer; purge wipes `.state` — 3 red → 5 green in [test_env_init_force.bats](../../tests/unit/test_env_init_force.bats) + [test_oo2_init_gate.bats](../../tests/unit/test_oo2_init_gate.bats). Full suite green (2142 tests, 0 failures); zero shellcheck warning/error findings on all three edited lib files (unchanged from before).

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.o: Batch lifecycle — `--all` fans across every declared env [Done]

`pyve init --force --all` rebuilds (and restores, per P.n) every declared env in one command — killing the N×`env purge`/`env init`/`env install` chore. `--all` is the explicit fan-out on the root-scoped lifecycle verbs.

- [x] `pyve init --force --all`: `--all` joins the operational toggles (parse arm, `_init_valid_flags`, help); `--all` without `--force` hard-errors before any dispatch; the force pre-flight messaging widens from "root only" to "root + every declared env" when `--all` is present.
- [x] Fan-out `_compose_init_force_all_envs` ([init_composer.sh](../../lib/init_composer.sh)) runs after the composition tail: per declared non-root env — banner header, then `env_init <name>` force+yes in a subshell (each env gets P.n's snapshot-then-replay; one env's failure never aborts the fan-out); lazy never-realized envs skip with a note (provision-on-first-use contract); advisory backends ride the standing skip-note; worst-case exit code propagates.
- [x] `pyve env purge --all`: explicit spelling of the config-driven whole-declaration sweep (same confirm gate as no-arg today); `<name>` + `--all` together rejected; help surfaces updated. (P.q later re-points the bare no-arg default; unchanged here.)
- [x] Tests: new [test_init_all.bats](../../tests/unit/test_init_all.bats) (guard: `--all` without `--force` errors; fan-out rebuilds+restores realized envs with per-env banners and preserved `last_used_at`; lazy never-realized skipped; advisory skip-note; worst-case rc with continue-past-failure — 5 red → green) + purge `--all` coverage in [test_testenv_purge_name.bats](../../tests/unit/test_testenv_purge_name.bats) + the valid-flags pin gains `--all`. Full suite green (2149 tests, 0 failures); zero shellcheck warning/error findings across the four touched lib files.

**Also (pre-existing gap surfaced by the fan-out, fixed here):** `ensure_env_exists` had no advisory branch — `pyve env init <name>` on a `backend = "none"` env fell through to the venv builder and **materialized a real venv** for an env explicitly declared not-materializable, violating the standing advisory carve-out ("any code path that branches on a backend value must ask `_env_backend_is_advisory` before rejecting/materializing"). The guard now skips with the standing §B note ([utils.sh](../../lib/utils.sh)); the fan-out and plain `pyve env init` both inherit it.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.p: `pyve upgrade` verb — re-resolve deps, keep the env, restore state [Done]

A new top-level verb (apt mental model): `pyve upgrade` re-resolves/upgrades an env's dependencies to newest-within-constraints, keeps the env directory, restores operational state, and re-locks. Pin the boundary everywhere: **`update` touches the files Pyve manages *around* your project; `init`/`force`/`upgrade` touch the *environments themselves*.** `--env <name>` / `--all`.

- [x] New top-level verb `pyve upgrade [--env <name>|--all] [--check]` (new [lib/commands/upgrade.sh](../../lib/commands/upgrade.sh), `upgrade_environment` per the naming convention; explicit source line + dispatcher arm in [pyve.sh](../../pyve.sh)). Bare = root env; `--all` = root + every declared env (lazy never-realized and advisory envs skip with notes; one env's failure continues the fan-out, worst rc wins). Upgrade **keeps** the env directory — a never-realized target is an error pointing at `pyve env init`, never an implicit create.
- [x] Per-backend re-resolve: venv → `pip install --upgrade` over the declared recipe (editable → requirements → extra, the P.l order), root falling back to conventional sources (`requirements.txt` → `-r`, else `pyproject.toml` → `-e .`); conda → `micromamba update -p -f <manifest>` then the pip layer with `--upgrade`, then re-lock via the existing `pyve lock` machinery when the lock file participates. Named envs re-stamp the P.m installed dimension (root has no state slot yet — future story).
- [x] Granularity decision (UX doc §10.2) settled as the leaning: newest-within-constraints + re-lock; `--check` is a dry-run that prints the plan and executes nothing.
- [x] The `update` vs `upgrade` boundary pinned where it's taught: both `--help` texts + [usage.md](../site/usage.md) ("`update` touches the files Pyve manages around your project; `init --force`/`upgrade` touch the environments themselves"). Unknown `--env` gets the standard actionable hint.
- [x] Tests: new [test_upgrade.bats](../../tests/unit/test_upgrade.bats) (9: root venv fallback sources ×2; declared-recipe upgrade preserves the env dir + re-stamps installed while `last_used_at` holds; never-realized target errors with the init hint; conda update→pip→re-lock ordering; `--check` executes nothing and leaves state untouched; `--all` fan-out with lazy skip; unknown env; boundary help) + the dispatch pin in test_cli_dispatch.bats — 10 red → green. Full suite green (2159 tests, 0 failures); zero shellcheck warning/error findings on upgrade.sh, pyve.sh, and plugin.sh.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.q: `pyve env purge` no-arg consistency fix (default env, not sweep-all) [Done]

Bare `pyve env <sub>` should uniformly operate on the **default** env. Today `pyve env purge` (no name) sweeps **all** envs while its siblings (`init`/`install`/`run`) assume the default — an inconsistency a developer hit in the field. Make bare `pyve env purge` hit the default env; `pyve env purge --all` is the explicit sweep.

- [x] Bare `pyve env purge` → the default env, promptless — exactly `env purge testenv` semantics, matching its siblings (`init`/`install`/`run` assume the default when unnamed); `--all` (shipped in P.o) is the sweep with its confirm gate intact.
- [x] **Breaking-change note:** behavior-breaking for scripts relying on the old no-arg sweep, but a trivially-breaking ergonomics fix on a young surface (`--all` preserves the old behavior verbatim) → stays **minor** (v3.1.0).
- [x] Teaching surfaces re-pointed: `pyve env --help` purge bullet; usage.md's worst-case-aggregate note names `--all`.
- [x] Tests re-anchored red-first in [test_testenv_purge_name.bats](../../tests/unit/test_testenv_purge_name.bats): bare multi-env purge removes ONLY the default (siblings survive); bare `--force` = default-only + deprecation warn; the TTY confirm y/n pair re-anchored to `--all`; single-env bare case retitled (same observable). 2 red → 45/45 green across the four affected suites. Full suite green (2159/2159 on the clean run; one unrelated transient in test_env_spec_helper's setup — python resolution 127 under parallel load — not reproducible); zero shellcheck findings on env.sh.

**Version:** v3.1.0 bundle (Subphase P-1).

---

### Story P.r: CLI output still teaches deprecated `pyve testenv` spellings — sweep fresh user-facing suggestions to `pyve env` [Done]

*(Field-discovered 2026-06-15, `learningfoundry` `pyve init` under v3.0.7. The consistency tail of the UX foundation. The code-side companion to the docs-only "Finish the v3 site — drop v2 spellings" story now in `## Future`: that one fixes prose in `usage.md`/`testing.md`; this one fixes the strings the binary actually prints.)*

**Discovered.** A fresh `pyve init` ended with a "Next steps" block instructing the user to run `pyve testenv install -r requirements-dev.txt` — the **deprecated v2 spelling**. The `pyve testenv` alias still re-dispatches (with a one-shot warning, removal slated v4.0), so nothing is broken — but Pyve's own freshly-generated output is teaching users a command form it's actively deprecating.

**Root cause — user-facing command *suggestions* were never swept from `testenv` to `env`, and a test locks the old spelling in.** The canonical v3 form is `pyve env install -r requirements-dev.txt` (already used at [pyve.sh:443](../../pyve.sh#L443)), but six user-facing print sites still emit `pyve testenv`:

| Site | Output |
|---|---|
| [plugin.sh:2256](../../lib/plugins/python/plugin.sh#L2256) | `pyve init` "Next steps" (the reported one) |
| [plugin.sh:4087](../../lib/plugins/python/plugin.sh#L4087) | `pyve test` lazy + `PYVE_NO_AUTO_PROVISION=1` hard error: `Run: pyve testenv install <name>` |
| [plugin.sh:4118](../../lib/plugins/python/plugin.sh#L4118) | `pyve test` pytest-missing interactive skip hint |
| [plugin.sh:4123](../../lib/plugins/python/plugin.sh#L4123) | `pyve test` pytest-missing non-interactive error |
| [env.sh:362](../../lib/commands/env.sh#L362), [:1160](../../lib/commands/env.sh#L1160) | `Usage: pyve testenv prune …` |

This shipped green because the next-steps tests **assert the deprecated string** ([test_init_next_steps.bats:64,139](../../tests/unit/test_init_next_steps.bats#L64), [test_init_next_steps.py:50](../../tests/integration/test_init_next_steps.py#L50)) — they encode the bug. Two more tests assert it for the lazy hint ([test_test_env_lazy_autoprovision.bats:102](../../tests/unit/test_test_env_lazy_autoprovision.bats#L102), [test_test_env_resolver.bats:147](../../tests/unit/test_test_env_resolver.bats#L147)).

**Out of scope.** The `pyve testenv` *alias itself* (keep until v4.0). The alias/grammar/completion tests that verify the alias still works ([test_testenv_grammar.bats](../../tests/unit/test_testenv_grammar.bats), [test_completion_bash.bats](../../tests/unit/test_completion_bash.bats), [test_testenv_install_name.bats](../../tests/unit/test_testenv_install_name.bats)) — they must keep using `pyve testenv` on purpose. The docs-site prose sweep (the sibling story in `## Future`). Code *comments* that mention the alias (not user-facing).

**Tasks.**

- [x] Reproduce (red): flip the next-steps test assertions to expect `pyve env install -r requirements-dev.txt` and to reject `pyve testenv` ([test_init_next_steps.bats](../../tests/unit/test_init_next_steps.bats), [test_init_next_steps.py](../../tests/integration/test_init_next_steps.py)); confirm they fail against current output.
- [x] Sweep the six suggestion sites `testenv` → `env`: next-steps ([plugin.sh:2256](../../lib/plugins/python/plugin.sh#L2256) + the doc-comment at [:2227](../../lib/plugins/python/plugin.sh#L2227)), the three `pyve test` hints ([:4087](../../lib/plugins/python/plugin.sh#L4087)/[:4118](../../lib/plugins/python/plugin.sh#L4118)/[:4123](../../lib/plugins/python/plugin.sh#L4123)), the two prune usages ([env.sh:362](../../lib/commands/env.sh#L362)/[:1160](../../lib/commands/env.sh#L1160)).
- [x] Update the two lazy-hint test assertions ([test_test_env_lazy_autoprovision.bats:102](../../tests/unit/test_test_env_lazy_autoprovision.bats#L102), [test_test_env_resolver.bats:147](../../tests/unit/test_test_env_resolver.bats#L147)) to `pyve env install …`; leave the alias/grammar/completion tests untouched.
- [x] Re-grep `lib/` + `pyve.sh` for any user-facing `pyve testenv` suggestion missed; confirm only the alias-compat tests still reference the old form.
- [x] Full suite; zero regressions (2159/2159, shellcheck 0 findings on both touched files).

**As-built notes.** The story's two `prune` usage-string sites had already been swept by intervening stories (they read `pyve env prune` on re-location), so the live sweep was five `plugin.sh` sites (next-steps printf + its doc comment, the lazy hard-error hint, the two pytest-missing hints). The re-grep surfaced two additional user-facing label prefixes in [env.sh](../../lib/commands/env.sh) (`"testenv install: unexpected positional …"` / `"testenv purge: …"`) — swept to `env install:` / `env purge:`. The two lazy-hint tests are `N.i-pending` skips, so their flipped assertions bind when the read-compat shim lands; the executable red came from the two next-steps tests (red → green). The one surviving non-comment `pyve testenv` string is the `env --help` note documenting the deprecation itself. Integration assertion flip (test_init_next_steps.py) rides to CI — integration is not run locally per the real-HOME mutation essential.

**Version:** v3.1.0 bundle (Subphase P-1) — patch-grade within the bundle. Developer owns number/placement.

---

### Story P.s: End-of-Phase P Public Documentation [Done]

At the end of each release in Phase P, refresh the public docs via `refactor_document` mode against the realigned plan (P.c). For **v3.1.0 (end of Subphase P-1)** this reflects the UX overhaul — the explicit manifest, the keystone-driven wizard/flags, the `update` / `upgrade` / `force` verb model, restore-on-rebuild. (A second pass follows at v3.2.0 for the hardening surface.)

**Session scope (2026-07-06, developer).** The deferred `## Future` story "Finish the v3 site — drop v2 spellings in usage/testing + document the env planning/sync workflow" is **pulled forward and folded in whole** (Groups A + B; its task detail now lives under the MkDocs task below, and the `## Future` placeholder is removed). `docs/specs/brand-descriptions.md` is **included** (the mode's standard target list; v3.1 capabilities may shift feature cards / descriptions).

- [x] Refactor `README.md` (v3.1.0 delta: `pyve upgrade`, declarative env recipes + one-shot `env init --force` rebuild, `--yes`/`--force` semantics, `--all` batch lifecycle; add `pyve env sync` to the command list)
- [x] Refactor `docs/specs/brand-descriptions.md` (v3.1 capabilities in feature cards / descriptions)
- [x] Refactor `docs/site/index.html` (v3.1.0 delta pass)
- [x] Refresh MkDocs config and pages — v3.1.0 delta across affected pages, plus the folded-in site-finish work:
  - [x] Restructure the `mkdocs.yml` nav from 12 flat top-level entries (overflowing tab bar) into a 5-tab hierarchy (developer-selected 2026-07-06): **Home | Start Here** (getting-started, migration) **| Concepts** (pyve-toml, environments, backends, plugins) **| Workflows** (testing, polyglot, packaging, ci-cd) **| Reference** (usage). Pages keep their filenames/URLs — nav-tree regrouping only; `usage.md` stays a single page this session (inbound deep links to `usage/#…` anchors from CLI output and project docs). Re-tune sidebar features (`navigation.sections` / `navigation.expand`) to fit the nested tree.
  - [x] `usage.md` — convert the lower-body Command Reference examples: `pyve testenv …` → `pyve env …`, `.pyve/testenvs/<name>/` → `.pyve/envs/<name>/`, `[tool.pyve.testenvs]` → `pyve.toml` `[env.<name>]`; fix the `#testenv-subcommand` anchor/link references; keep one explicit "`pyve testenv` is a deprecated alias (removed v4.0)" note.
  - [x] `testing.md` — same sweep across the lifecycle / named-test-env / activation-context / backend-deltas sections; rewrite the `[tool.pyve.testenvs]` worked examples as `pyve.toml` `[env.<name>]` blocks; fix the `.pyve/testenvs/testenv/venv` and `.pyve/envs/<name>/` path references in "Backend deltas".
  - [x] Re-run the link/anchor check; confirm no dead `#…` fragments after the rename.
  - [x] Add `pyve env sync` to every command reference where it's missing (`environments.md`, `usage.md`, `README.md`): discover the spec → diff vs the current `pyve.toml` → `[Y/n]` apply (default `Y`; **destructive** drops/backend-flips default `N`); writes `pyve.toml` only, never materializes; note exit `6` (spec invalid under the closed vocabulary).
  - [x] Add a "Planning environments with project-guide" section to `environments.md` (with pointers from `getting-started.md` / `usage.md`): `project-guide mode plan_envs` authors the env spec §4 → `pyve env sync` reconciles it into `pyve.toml` → lifecycle commands materialize. Explain the *why*: one declarative source of intent; the spec may legitimately run ahead of what's materialized.
  - [x] Document the `pyve check` env-spec drift surface — non-empty §4-vs-`pyve.toml` diff → **warn (exit 0)**, with the "run `pyve env sync` to reconcile" hint; note Pyve reads `env_spec_path` from `.project-guide.yml` (default `docs/specs/env-dependencies.md`).
  - [x] Document the projectable subset that syncs/diffs (`name`, `purpose`, `backend`, `default`, `path`, `languages`, `frameworks`, `packaging`) vs. advisory/prose that never triggers drift (`app_type`, `require_min_version`, `manual_steps`, §5–§9 narrative).
  - [x] Link, don't duplicate — reference the env-spec contract ([project-guide-requests/wizard-env-contract.md](project-guide-requests/wizard-env-contract.md)) rather than re-deriving the vocabulary; keep roadmap surfaces honest.

**As-built notes (2026-07-07).** Backups per the mode: `README_old.md`, `docs/specs/brand-descriptions_old.md` (refreshed over the June 10 copy), `docs/site/index_old.html` — deletion at developer discretion. No Legacy Content sections were needed and no files were renamed. Beyond the plan: (1) **`migration.md` was fully rewritten** — it still taught the v3.0 transition machinery (soft banner, read-compat, `self migrate`) as current, and its "v3.1 hard interactive gate" section described a design that never shipped; it now teaches the real v3.1 path (re-run `pyve init`) with the transition history kept for v3.0.x readers. (2) The **link/anchor check caught five dead anchors, two pre-existing** — GitHub-style double-dash slugs that MkDocs collapses (`#setup-directives-a-composable-recipe`, plus the new `#upgrade-env-name-all-check`); mkdocs is not installed locally, so validation ran via a slugify-accurate script (scratchpad) — the site deploy remains the final arbiter. (3) README staleness beyond the v3.1 delta was corrected after verifying each claim against the code/CLI: retired `init <dir>` / `purge <dir>` positionals, `pyve python-version` → `python set`/`show`, `.pyve/config` detection/naming tiers → manifest tiers, the v1.5-era "Smart Re-initialization" section → the three-verb model, `--version` example `1.13.0` → `3.1.0`. (4) `backends.md` fixes outside the sweep: `.pyve/envs/<hash>/` → `.pyve/envs/root/conda/`, and an invalid `pyve init 3.11` positional example. (5) `pyve-toml.md` now documents the `pyve_defaults_version` stamp (P.k). (6) `mkdocs.yml` theme features left unchanged after evaluation — the tab grouping alone resolves the overflow; `navigation.sections`/`expand` are harmless at one nesting level. (7) Three internal story IDs removed from public pages; each page keeps exactly one deprecation-alias note (the P.r pattern). `pyve status` / `pyve check` output examples were re-captured from the live `./pyve.sh`.

**Version:** rides the v3.1.0 bundle (Subphase P-1) — pure documentation refresh, no independent bump (P.u ships the release).

---

### Story P.t: Finalize the Reference documentation — split `usage.md` into per-command reference pages [Done]

*(Follows P.s, which restructures the site nav into the 5-tab hierarchy but deliberately keeps `usage.md` whole — the Reference tab therefore launches with a single 1,182-line page. This story fills the tab out properly. Deferred out of P.s because the split breaks inbound deep links unless redirects land with it.)*

**Motivation.** `usage.md` is the site's heavyweight (1,182 lines) — one page carrying the entire command reference. With the Reference tab established, the finalized shape is per-command-group pages the left sidebar can navigate. The constraint that deferred this: external deep links target `usage/#…` anchors — pyve's own CLI output and the project-guide artifacts link to `https://pointmatic.github.io/pyve/usage/#env-subcommand` — so the split must ship with redirects, not before them.

**Tasks.**

- [x] Settle the page grouping (refined at implementation): Project Lifecycle (`init`, `update`, `upgrade`, `purge`), Environments (`env` namespace incl. `sync`), Diagnostics (`check`, `status`), Tooling (`run`, `test`, `lock`, `package`, `python`, `self`) — plus a slim `usage.md` overview that indexes the group pages. Refinements: the global `--version` / `--config` / `--help` sections stay on the overview (global CLI surface, beside Universal Flags); `package` — which the old page never documented — gets a short reserved-verb entry on Tooling pointing at the Packaging workflow page.
- [x] Split the content into the per-group pages under the Reference tab (`docs/site/reference/{lifecycle,env,diagnostics,tooling}.md`); every moved section keeps its exact heading text, so each slug is stable on its new page. Content moved verbatim except heading level (`###`→`##`) and `../`-prefixing the relative links that crossed into the subdirectory.
- [x] Ship old→new coverage for the retired `usage/#…` anchors — **as-built: a client-side fragment forwarder on `usage.md`**, not `mkdocs-redirects`. The plugin only maps retired *pages*, and `usage.md` still exists (as the overview), so a fragment like `usage/#env-subcommand` would land on the live page and never reach a redirect — fragments are client-side only. The forwarder maps all 14 moved command anchors plus the legacy v2 `#testenv-subcommand` (still baked into old CLI output) to their new homes; it fires only on exact map hits.
- [x] Audit inbound deep links and repoint or confirm redirect coverage: `pyve.sh` + `lib/` and `README.md` link site *pages* only, no `usage/#…` anchors (verified by grep); in-site anchor links repointed (`getting-started.md` → `reference/lifecycle.md`, `testing.md` ×2 → `reference/env.md`); the project-guide artifact template's `usage/#env-subcommand` (install output — not hand-editable) is covered by the forwarder, as are the copies already installed in user projects.
- [x] Site-wide link/anchor check; zero dead fragments (15 pages; slugify-accurate scratchpad script, MkDocs dash-collapsing rules; also verified every forwarder target slug exists on its destination page). Sidebar render check rides P.u's deploy confirmation — mkdocs isn't installed locally and the deploy (`mkdocs build --strict`) is the final arbiter, per the P.s precedent.

**As-built notes (2026-07-07).** New nav: Reference = Usage Guide + Project Lifecycle + Environments (env) + Diagnostics + Tooling ([mkdocs.yml](../../mkdocs.yml)). `usage.md` drops 1,196 → ~460 lines: keeps Command Overview (rows now link into the group pages), Universal Flags, the global-flag sections, Environment Variables, Configuration Files, Workflow Examples, Tips, Next Steps. No `mkdocs.yml` plugin additions and no CI change (the redirect task's as-built mechanism needs neither). The deprecation-alias note appears once per page that mentions the alias (P.r pattern): overview + env page.

**Version:** v3.1.0 bundle (Subphase P-1) — ships with the release so the redirects go live alongside the new nav. Developer owns number/placement.

---

### Story P.u: v3.1.0 Tag release and validate in production [Done]

*(The Subphase P-1 release story — the bundle ships as one versioned release per the Version Cadence rule. Git operations are developer-owned throughout.)*

**Tasks.**

- [x] Local pre-flight: full unit suite green (2,159 tests, 0 failures, parallel runner), including the shellcheck regression guard (0 warning/error findings over `pyve.sh` + `lib/`; info-level SC1091-class noise only, per the P.f.1 contract).
- [x] CI (unit + integration, both runners) green on the release commit — verified after the developer pushes the release commit (`gh` is not installed locally; check on GitHub).
- [x] Consolidate `CHANGELOG.md` for 3.1.0 — the P-1 bundle: keystone parameter decision-graph (P.e–P.g), explicit-by-construction manifest + `--yes` wizard (P.j), versioned defaults + drift surfacing (P.k), full `.pyve/config` retirement (P.i.*), declarative env recipes + one-shot `env init --force` rebuild + `--yes`/`--force` semantics (P.l.*), operational-state record + restore-on-rebuild (P.m/P.n), `--all` batch lifecycle (P.o), `pyve upgrade` (P.p), `env purge` no-arg fix (P.q), `testenv`→`env` output sweep (P.r), docs refresh + site restructure (P.s/P.t). The subphase branch squash-merges to a single commit on `main`, so this is **one consolidated 3.1.0 entry summarizing everything since 3.0.5** — the unreleased 3.0.6–3.0.8 changes fold into the same summary (3.0.6's O.g–O.o.4 fixes, 3.0.7's recursive `self install` copy + Python 3.14.6 default, 3.0.8's init composition-tail fix); no per-patch backfill.
- [x] Bump `VERSION` in [pyve.sh](../../pyve.sh) to `3.1.0` (`./pyve.sh --version` → `pyve version 3.1.0`).
- [x] Developer: squash-merge `subphase/p-1` → `main` (the subphase lands as a single commit)
- [x] Confirm CI from merge lands green
- [x] `git-tag v3.1.0` (`gitbetter` feature) tag and push, which auto-updates the Homebrew formula (upstream tap) to v3.1.0; 
- [x] Merge the homebrew formula update PR, and confirm `brew upgrade` picks it up.
- [x] Confirm the docs site deploy renders the new 5-tab nav and the `usage/#…` redirects resolve.
- [x] Production validation on a real machine with the released binary (not `./pyve.sh`): fresh `pyve init` on a new project; on an existing real project (e.g. ml-datarefinery), exercise `pyve check`, `pyve upgrade`, a state-restoring `pyve env init <name> --force` rebuild, and the `plan_envs` → `pyve env sync` loop.
- [x] Record any escapees as new field-discovered stories rather than patching silently.

**Version:** v3.1.0 — this story *is* the release. Developer owns the final number and tag.

---

## Future

A parking lot of detailed candidate bodies. Each is assigned to a later subphase (P-2…P-5) — see the subphase roadmap above for the mapping — or folds into an existing P-1 story (the tech-spec-table reconcile → P.c; the v3-site sweep → P.s). When a subphase activates, its `plan_production_phase` session pulls its candidates from here and decomposes them into the working roster.

---

## Phase P: UX Overhaul; Harden and heal Pyve

Note: there may be some stories in `## Future` that need to be reviewed and considered whether to include in this Subphase

Complexity, inconsistent patterns/defaults, and some magical behaviors are making Pyve v3 difficult to use, and confusing to determine what v3 is supposed to do. The LLM is confused when it comes time to implement projects with Pyve as the environment manager. 

A primary change that needs to be embraced is that **Pyve v2.x** was a Python virtual environment tool with a built-in test environment and a lumpy integration of Conda (micromamba). The declarative parts of v2 were spread across pyproject.toml, .pyve/config, and environment.yml (micromamba). Now **Pyve v3.x** is an any-project virtual environment tool, with initial support via plugins for Python and Node.js via venv, micromamba, and pnpm/npm backends. And a key improvement, v3 can now be fully declarative (with fallback to very simple defaults, like Python, venv, and a single testenv using PyTest).

**Tenets:**
- Pyve surface starts simple - `pyve init` does everything necessary for simple Python projects, with progressive nuance that adapts to project complexity. `pyve test` auto-initializes the environment and installs dependencies if needed (in the Python default case, it uses `mypy`, `ruff`, and `pytest`).
- Pyve is declarative - configuration is the single source of truth, no configuration falls back to defaults; Pyve supports complex imperative workflows via flags, commands, environment vars, but nothing beyond what is defined in the declarative schema.
- Pyve is DRY — no duplication of configuration or logic (except if convenience aliases are needed).
- Pyve is consistent — similar patterns, behaviors, and defaults across all commands, workflows, and plugins.
- Pyve is robust - it handles errors gracefully, heals when possible, provides clear error messages, and feels light and easy with every project; `check` actually checks environment and integration points beyond the configuration and diagnoses typical issues with hints for fixing them; `status` actually shows a coherent, organized status of the Pyve envs and the configuration.
- Pyve works seamlessly across platforms - While Homebrew is the typical install path for development, cloning the GitHub repo and using `pyve self install` works smoothly for CI/CD, automated environments, or on Linux systems where Homebrew is not ideal.
- Pyve is extensible - every configuration facet has a mechanical purpose in Pyve machinery or is forward-looking toward future capabilities.
- Pyve is clearly documented - all configuration options, commands, and workflows are documented in a way that is easy to understand and follow.

**Two acts, two releases.**

- **Act 1 — UX Foundation (v3.1.0, Subphase P-1).** Make v3's declarative model *real*: a complete, explicit, single-sourced `pyve.toml`; a parameter decision-graph that ends the scattered wizard/flag/default drift; desired-vs-actual env state with restore-on-rebuild and a batch lifecycle; one consistent verb model. This is what makes the named-environments promise deliver. North-star design: [phase-p-subphase-1-ux-overhaul.md](phase-p-subphase-1-ux-overhaul.md).
- **Act 2 — Harden & heal (v3.2.0+, Subphase P-2 and beyond).** Make environment *resolution* explainable and Pyve's managed state self-healing. **Act 1 is the substrate Act 2 stands on:** `pyve heal` can only restore toward an intent the manifest fully captures (Act 1's explicit declaration) and an operational reality it recorded (Act 1's state record) — so the UX foundation comes first.

**Multi-release exception.** Phase P ships **a release per subphase** — v3.1.0 (P-1) → v3.2.0 (P-2) → v3.3.0 (P-3) → v3.4.0 (P-4) → v3.5.0 (P-5) — an explicit, documented exception to the Version Cadence "one phase = one bundled release" rule. The sequence is deliberate: each release builds on the last (the UX foundation is the substrate the hardening heals toward; the polish, plugin, and security passes follow). A subphase's stories run unversioned during its work; its final code story owns that subphase's minor bump.

---

**Act 2 context — the hardening mandate** *(breakdown deferred to its own `plan_production_phase` session when Subphase P-2 activates; see Story P.d)*.

Make Pyve's environment resolution make sense and be **bulletproof**; when the armor is pierced, give Pyve a **healing mechanism**. The developer should never have to hand-trace PATH order, version-manager pins, and venv symlinks to understand why a command misbehaves, nor hand-repair Pyve-managed state.

**Triggering incident (field-discovered 2026-06-09).** A developer's `project-guide` invocation in the pyve repo broke with a cryptic `No version is set for command project-guide` naming a Python `3.14.3` they could not place. Untangling it took a long manual trace across **four independent layers**, none of which any Pyve command could see or explain:

1. **PATH shadowing.** `python` reported 3.14.4 while `.tool-versions` pinned 3.12.13 — because direnv had prepended an activated `.venv/bin` ahead of `~/.asdf/shims`, so the asdf pin never governed `python` at all. `project-guide`, present in neither `.venv` nor `~/.local/bin`, fell through to the asdf shim where the 3.12.13 pin *did* apply — and 3.12.13 had no project-guide.
2. **Interpreter drift.** The `.venv` python was a frozen symlink to asdf 3.14.4 (its creation-time interpreter), drifted from the now-3.12.13 pin — a venv never tracks later `.tool-versions` edits.
3. **Dead Pyve-managed artifacts.** `~/.local/bin/project-guide` was a dangling symlink, and the hosted toolchain venv's `project-guide` had a `bad interpreter` shebang — both pointing at a deleted path. Yet both passed Pyve's existence checks.
4. **The 3.14.3 mystery.** project-guide 2.12.0 happened to be pip-installed into one asdf interpreter (3.14.3); asdf surfaced that version number in its rejection message, with no context a human could decode.

**Core anti-pattern to eliminate: existence ≠ runnability.** Pyve's health/hosting code asserts that artifacts *exist* (`-x` / `-f` / `-d`) rather than that they *run*. The canonical trap: [`_compose_check_pyve_hosting`](../../lib/check_composer.sh#L121) reports `project-guide hosting: provisioned` on `[[ -x "$venv_dir/bin/python" ]]`, which passes for a venv whose python symlink targets a deleted interpreter. Story N.bo began the correction at the project-guide resolver (a runnability-honoring `PYVE_PROJECT_GUIDE_BIN` override seam); this subphase generalizes it across the codebase.

**Design pillars (Act 2 — decompose when Subphase P-2 activates, Story P.d).**

1. **Runnability probes.** Replace existence checks throughout hosting/health code with probes that actually execute the artifact (`python --version`, `project-guide --version`, version-manager resolution) and classify the failure: dead interpreter, asdf "no version set", dangling symlink, missing command, version-manager-not-installed. A health check that can be fooled by a broken symlink is not a health check.
2. **Resolution reasoning in `pyve check`.** Turn the manual trace into automated narrative: for each managed command, report *where* it resolves and *why* — PATH-slot ordering, venv-shadows-pin, reachability under the active pin, venv↔pin interpreter drift — in the plain language a human had to reconstruct by hand. `check` should have said, unprompted: "`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13); `project-guide` falls through to the asdf shim under that pin, which has no project-guide → install it into 3.12.13 or repoint the pin."
3. **Healing mechanism (`pyve heal`, or `pyve check --fix`).** Safe, idempotent, **confirm-before-destroy** repairs for every failure class the probes detect: rebuild a toolchain venv with a dead interpreter; re-link a dangling `~/.local/bin` shim; rebuild a `.venv` whose interpreter drifted from the pin (destructive → explicit confirmation); install a missing managed command into the *selected* interpreter. Reversible and re-runnable; never silently mutates without surfacing what it will do.
4. **Close the upstream cause — the test-isolation leak.** The triggering incident was *manufactured by Pyve's own test suite*: [`_isolate_home`](../../tests/integration/test_project_guide_integration.py#L211-L217) (integration harness) symlinks the developer's **real** `~/.asdf` and `~/.local` into the test's fake `$HOME`, so any project-guide/toolchain-provisioning test writes hosting artifacts into real developer state — which dangles when the test's tmpdir is cleaned up. Re-scope `_isolate_home` so the suite can never again mutate a real home (provision into a fully self-contained fake `$HOME`, or stub provisioning entirely). N.bo's `PYVE_PROJECT_GUIDE_BIN` seam closes one path; the version-manager (`.asdf`) and self-install paths remain open.

**Scope notes.** `lib/ui/` primitives stay pyve-agnostic (the lib/ui boundary invariant). Healing never destroys without explicit confirmation. Builds on Story N.bi (check hosting/toolchain surfacing), Phase O (check/status expand-collapse long-form output), and Story N.bo (runnability override seam + the existence-vs-runnability framing). Ships in the Phase N v3.x line; the exact release tag and the full story breakdown are deferred to this subphase's `plan_production_phase` session.

**Conceptual work first (Phase P, not started).** The `purpose` lifecycle (`run`/`test`/`utility`/`temp`) and environment durability need a *conceptual* pass before any lifecycle code: **what precious resource each purpose protects**, and why preservation is a *cost-cache + artifact* concern, not a "survives-purge" ranking (the principle: *irreproducibility is the bug; we never preserve because an env is irreplaceable*). The framing seed is [env-lifecycle-concept.md](env-lifecycle-concept.md). The intended mode sequence is **`refactor_document`** (fold the framing into `concept.md` / `project-essentials.md`'s `purpose:` entry / `tech-spec.md`) → **`plan_phase`** (derive targeted stories). This corrects, among other things, the current essentials hint that "utility envs survive `pyve purge`" (the new framing makes `utility` the disposable one). Pairs with the declarative-env-setup megastory (now Story P.l).

**Subphases**

Each subphase has a theme (with adhoc bug fixes as needed).

- **Subphase P-1 (v3.1.0): Conceptual clarification & UX Foundation** — the keystone parameter decision-graph, an explicit single-sourced manifest, desired-vs-actual env state, batch lifecycle, and one consistent verb model. *(Declarative env setup — formerly its own subphase — is folded into P-1's Pillar II.)*
- **Subphase P-2 (v3.2.0): Runnability probes & environment healing** — Act 2 (the four pillars above).
- **Subphase P-3 (v3.3.0): Workflow & DX polish** — CI hygiene + developer-experience.
- **Subphase P-4 (v3.4.0): Deeper plugin work** — plugin enrichment (TypeScript, …).
- **Subphase P-5 (v3.5.0): Security & bootstrap hardening** — download integrity + version pinning.

Story breakdown for each subphase beyond P-1 is deferred to its own `plan_production_phase` session, kicked off when that subphase activates (Story P.d); candidates are parked in `## Future`.

---

## Subphase P-2: Runnability probes & environment healing (v3.2.0)

**Scope (Act 2).** Make environment *resolution* explainable and Pyve's managed state self-healing — the four design pillars in the preamble: (1) **runnability probes** that execute artifacts and classify the failure; (2) **resolution reasoning** in `pyve check` (where/why each managed command resolves — PATH-slot order, venv-shadows-pin, interpreter drift); (3) a **healing mechanism** (`pyve heal` / `pyve check --fix`) — safe, idempotent, confirm-before-destroy; (4) **close the test-isolation leak** so the suite never mutates a real `$HOME`. Builds directly on P-1: `heal` restores toward the intent the explicit manifest captures and the operational state it recorded.

**Candidate stories** (parked in `## Future`; pulled on activation): per-env runnability probe (canary); silent-skip `root` pytest probe fix; declarative `pyve.toml` opt-out for the silent-skip advisory; `project-guide` status unify + version; auto-remediation (`pyve check --fix`); `pyve check` surfaces available updates.

**Story breakdown deferred** to its own `plan_production_phase` session (Story P.d), kicked off when this subphase activates.

---

## Subphase P-3: Workflow & DX polish (v3.3.0)

**Scope.** CI hygiene and developer-experience refinements that don't fit the UX-foundation or hardening themes but raise the day-to-day quality bar: coverage reporting, flaky-test triage, per-command help ergonomics, and extending Phase L's calm-UX framing beyond the scaffold commands.

**Candidate stories** (in `## Future`): kcov bash-coverage upload fix (integration `kcov-merged`); fix pre-existing integration-test failures; per-leaf help functions for namespace commands; apply Phase L UX framing to non-scaffold commands (`lock`, `env install`, `purge --force`).

**Story breakdown deferred** to its own `plan_production_phase` session.

---

## Subphase P-4: Deeper plugin work (v3.4.0)

**Scope.** Enrich the plugin layer beyond the contract-proving baseline — deeper, language-aware behavior in the reference plugins, and any generalizable "language-flavor advisory" pattern future plugins inherit. Thin today; grows as plugin needs surface.

**Candidate stories** (in `## Future`): deeper TypeScript integration for the Node plugin (`tsconfig.json` detection, `tsc --noEmit` advisories, opt-in pre-test type-check).

**Story breakdown deferred** to its own `plan_production_phase` session.

---

## Subphase P-5: Security & bootstrap hardening (v3.5.0)

**Scope.** The dedicated security pass deferred from the I.h audit: cryptographic integrity of the micromamba bootstrap download and deterministic version pinning. Picks up the disposition recorded with these stories (revive when a security review asks for download integrity, or a regressing `latest` makes pinning worth its upkeep). Version pinning is the higher-value of the two and the prerequisite for a hardcoded-hash table.

**Candidate stories** (in `## Future`): SHA256 verification of the bootstrap download; micromamba version pinning via `--micromamba-version`.

**Story breakdown deferred** to its own `plan_production_phase` session.

---

### Story ?.?: `project-guide` status is split + v2-leftover — unify into one readout that names *how* it's present (local pip vs toolchain) + show its version (status & self provision) [Planned]

*(v2-wiring removal — same family as the config-source story (now P.i). project-guide stopped being a per-project Python dependency in v3, but a v2 status check survived. Candidate for Subphase P-2, or to ride with P.i.)*

**Discovered:** 2026-06-13, pyve repo. `pyve status` shows a self-contradiction: `[python]` → Integrations → `project-guide: not installed`, while the `[project-guide]` section directly below → `pyve-hosted (toolchain)`. And `pyve self provision` (which provisioned + linked project-guide) didn't move the "not installed" line.

**Root cause — two readouts checking different locations; the `[python]` one is v2 wiring.** The Integrations row ([plugin.sh:3567-3577](../../lib/plugins/python/plugin.sh#L3567-L3577)) checks `[[ -x "$env_path/bin/project-guide" ]]` — project-guide pip-installed in the **project venv** (the v2 location). In v3 project-guide is a Pyve-managed **global** tool (toolchain venv + `~/.local/bin` shim), never in `.venv`, so that row reports "not installed" regardless of hosting — and `self provision` can't change it because the row looks at the wrong place. The authoritative `[project-guide]` section (`_compose_status_project_guide`, [status_composer.sh:42](../../lib/status_composer.sh#L42)) reports the real state. The Integrations row is what N.aw's "Python plugin project-guide status stays suppressed" missed.

**Design (developer-specified, 2026-06-13).**
- **One section / one line.** Keeping a check for a pip-installed project-guide is fine — but it belongs in **one** readout, not split across two contradictory ones. Drop the `[python]` Integrations project-guide row; the `[project-guide]` section is the single home.
- **Name *how* it's present.** Fold the local-pip check into that one readout: installed locally (pip in the project env) but not in the toolchain → report it as present, labeled **"local pip"** (or similar); in the toolchain → **"pyve-hosted (toolchain)"**; neither → "not installed". (`_compose_status_project_guide` already distinguishes "managed by your project (pip)" vs "pyve-hosted" — make it the sole source and relabel for clarity.)
- **Show the version, in both places.** Display the resolved project-guide **version** in `pyve status` (e.g. `pyve-hosted (toolchain) v2.15.1` / `local pip v2.15.1`) **and** in `pyve self provision` output (e.g. `Installed project-guide v2.15.1 into the Pyve toolchain`), so it's clear what was installed.

**Tasks (refine at `plan_production_phase`).**

- [ ] Reproduce (red): a pyve-hosted, no-project-venv-copy project → `pyve status` emits BOTH `project-guide: not installed` ([python]) and `pyve-hosted (toolchain)` ([project-guide]). Assert a single, non-contradictory readout after the fix.
- [ ] Remove the project-guide row from the `[python]` Integrations block ([plugin.sh:3567-3577](../../lib/plugins/python/plugin.sh#L3567-L3577)); the `[project-guide]` section is the sole readout.
- [ ] Make `_compose_status_project_guide` name the presence mode — toolchain-hosted / project-local pip / neither — and **probe runnability** (`project-guide --version`), not just `-x` (existence ≠ runnability, Phase P pillar).
- [ ] Surface the resolved version in the status readout and in `self_provision`'s "Installed project-guide …" line ([self.sh](../../lib/commands/self.sh)).
- [ ] Tests: hosted-only / local-pip-only / both / neither → one correct labeled readout each, with version; `self provision` prints the installed version.

**Version:** Phase P — v2-wiring removal + existence→runnability. Developer owns number/placement.

---

### Story ?.?: Reconcile tech-spec.md command/module tables to the v3 plugin file-layout [Planned]

**Raised:** 2026-06-09 (developer, during the N.bq tech-spec cascade). *(Candidate to fold into P.c Plan Realignment.)*

**Motivation.** The N.bq pass (Subphase N-8) consolidated the plugin region of [tech-spec.md](tech-spec.md) into one `## Plugin layer` section, stripped header archeology, refreshed the enumerated v2 remnants (`pyve.toml`, `.pyve/envs/`, `env` namespace, version globals), and repointed cross-refs — but **deliberately left the deeper file-layout drift** in the `## Key Component Design` command/module tables. Those tables' *behavior/signature* descriptions are still accurate; their *file locations* and inline story refs are stale relative to the v3 relocation: `init`/`purge`/`update`/`check`/`status`/`run`/`test` and the `python` namespace now live in [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh); `lib/testenvs.sh` → `lib/envs.sh`; `lib/commands/testenv.sh` → `lib/commands/env.sh`; `lib/commands/` retains only `env.sh` / `lock.sh` / `package.sh` / `self.sh`. A stopgap v3.0 file-layout orientation note was added at the section head; this story removes the need for it.

**Why deferred.** N.bq was scoped as a *targeted in-place refactor*, not a regenerate — a full rewrite of the ~240-line command-table block risked dropping correct technical detail for no release benefit, and release functionality (N-9) outranks doc-table reconciliation. The orientation note keeps the doc honest in the interim. This pairs with the **"Complete phase/story-ref comment sanitization"** Future story (same story-ref archeology, different surface — code comments there, spec-doc tables here) and could be bundled into one doc/ref-cleanup pass.

**Tasks (sketched; refine when picked up).**

- [ ] Reconcile the `### lib/commands/<name>.sh — Command Implementations` block to the v3 layout: relocate/cross-link the Python command function tables under the Plugin layer's `### Python plugin`, and keep only `env` / `lock` / `package` / `self` as `lib/commands/` residents. Remove the stopgap orientation note once done.
- [ ] Strip inline `Story X.y` / `Phase`/`Subphase` refs from the function-table bodies (`lib/envs.sh`, `lib/manifest.sh`, the command tables, the `lib/utils.sh` / `lib/version.sh` notes), preserving load-bearing markers (`v3.0-only: remove in N-10`, `BOUNDARY`, `N.i-pending`, `F<n>`).
- [ ] Fix the `## Package Structure` tree (`tech-spec.md` ~L50): drop the deleted `lib/commands/{init,purge,update,check,status,run,test,testenv,python}.sh` and `lib/testenvs.sh` / `pyve_testenvs_helper.py`; add `lib/plugins/**`, `lib/*_composer.sh`, `lib/envs.sh`, `lib/manifest.sh`, `lib/toolchain_python.sh`, `lib/project_guide.sh`, `pyve.toml`.
- [ ] Fix the `### pyve.sh — Thin Entry Point` sourcing-order paragraph: it still enumerates deleted command files and a "~500–650 lines post-K.l" framing; replace with the actual v3 source order (helpers → `manifest.sh` → registries → plugins → composers → `env`/`lock`/`package`/`self`).
- [ ] Diff-review against the live codebase; confirm no surviving reference to a deleted file or non-existent function.

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
- [x] Full suite; zero regressions (2159/2159, shellcheck 0 findings on both touched files).

**Version:** Phase P. Pairs with the `pyve check --fix` / `pyve heal` story (heal consumes this detection). Developer owns the number/placement.

---

### Story ?.?: silent-skip advisory's `root` pytest probe is broken for a venv root + named envs (the standard v3 topology) [Planned]

*(Field-discovered 2026-06-17, `modelfoundry`, while explaining why `pyve test --env smoke-pytorch` listed `testenv typecheck` in the silent-skip advisory. The advisory itself fired correctly; tracing it surfaced a latent false-negative in the `root` probe.)*

**The advisory.** `pyve test --env <X>` runs a guard ([plugin.sh:4129-4160](../../lib/plugins/python/plugin.sh#L4129-L4160)): if any env *other* than the target has pytest importable, it warns, because tests that `pytest.importorskip(...)` a stack absent from the target **silently SKIP and look green**. It probes each candidate via `_test_env_has_pytest <name>` ([plugin.sh:3793-3815](../../lib/plugins/python/plugin.sh#L3793-L3815)), which resolves the env's `bin/python` and runs `import pytest`.

**Bug — the `root` branch resolves the wrong path.** For `root` ([plugin.sh:3797-3806](../../lib/plugins/python/plugin.sh#L3797-L3806)) it does **not** use the canonical resolver: it globs `.pyve/envs/*`, takes the first dir, and builds `<dir>/bin/python`. But venv-backed envs nest under `<dir>/venv/bin/python` (conda under `<dir>/conda/bin/python`), so that path **never exists**. It then assigns `py` to the bogus (non-empty) string, which makes the `[[ -z "$py" ]]` guard **skip the `.venv` fallback**, and the function returns `1` ("no pytest") unconditionally whenever `.pyve/envs/` holds any named env.

**Effect — a false negative in exactly the guard's reason for being.** On the standard v3 topology — a **venv `root` plus named envs under `.pyve/envs/`** — `root` is never correctly probed. If `.venv` actually has pytest, the silent-skip guard **fails to warn** about it. (Harmless in `modelfoundry` only by accident: its `.venv` root genuinely lacks pytest, so the broken probe returns the right answer for the wrong reason.)

**Root cause.** The `root` branch predates the N.bf.14 root-slot model and assumes the pre-N.bf.14 *flat* micromamba layout (`.pyve/envs/<first>` with `conda-meta` directly inside). The non-root branch already does the right thing — `resolve_env_path "$env_name"` — so the fix is to make `root` use the same canonical, backend-aware resolution.

**Out of scope.** The advisory's *heuristic* (multiple deliberately-isolated test envs → a benign false **positive**, silenced by `PYVE_NO_TESTENV_ADVISORY=1`; whether declared `purpose="test"` envs should be exempted from the positive is a separate question). The non-root branch (correct). The mutation-on-read concern lives elsewhere — `pyve test` is a sanctioned write path, so firing the opportunistic migrator via `resolve_env_path root` here is acceptable.

**Tasks.**

- [ ] Reproduce (red): a fixture with a venv `root` carrying pytest in `.venv` **plus** a named `purpose="test"` env; `pyve test --env <named>` → assert `root` appears in the advisory list (it does not today).
- [ ] Fix `_test_env_has_pytest`'s `root` branch to resolve the interpreter via the canonical backend-aware path (mirror the non-root branch's `resolve_env_path root`: `.venv` for venv, `.pyve/envs/root/conda` for micromamba — or `resolve_main_micromamba_path` for a non-mutating read), and **delete the `.pyve/envs/*` first-dir glob**.
- [ ] Regression: a venv root **without** pytest + named envs → `root` still excluded (no false positive reintroduced); a micromamba root **with** pytest → `root` correctly detected.
- [x] Full suite; zero regressions (2159/2159, shellcheck 0 findings on both touched files).

**Version:** Phase P — patch-grade. Developer owns number/placement.

---

### Story ?.?: A declarative `pyve.toml` opt-out for the silent-skip advisory — project-scoped and visible, not a per-shell env var [Planned]

*(Design direction, 2026-06-17, from the `modelfoundry` advisory discussion. Pairs with the `root` pytest-probe story above — same advisory — and resolves its out-of-scope note "whether declared `purpose=test` envs should be exempted… is a separate question.")*

**The gap.** The silent-skip advisory ([plugin.sh:4129-4160](../../lib/plugins/python/plugin.sh#L4129-L4160)) fires on every `pyve test --env <X>` when any other env also has pytest. A project that **deliberately** runs several isolated `purpose = "test"` envs (the `modelfoundry` shape: a default suite + per-framework smoke envs + a `typecheck` env, each with its own pytest) trips it on every run — a benign false positive. The only suppression today is `PYVE_NO_TESTENV_ADVISORY=1` ([plugin.sh:4139](../../lib/plugins/python/plugin.sh#L4139)): per-shell (must re-prefix every invocation), or exported and **leaky** (silences it for *every* project), and **invisible** — nothing in the repo records that the project opted out.

**Why now.** The env var shipped (M.c/M.o) under the assumption that "multiple envs with pytest" was rare — the era of *one main env + one testenv*. v3's named-env model makes a multi-test-env project **mainstream**, so a project-scoped, version-controlled, reviewable suppression belongs in the manifest, consistent with [[`pyve.toml` is the canonical declaration; `.pyve/` holds state only]].

**Design — recommended: an explicit declarative opt-out.** A `pyve.toml` field that says "I run multiple test envs on purpose; don't nag." It preserves the signal as **opt-out** (you consciously declare it), is reviewable in the diff, and doesn't leak across projects. **Open sub-question deferred to `plan_production_phase`: project-wide vs. per-env.**
- *Project-wide* — one toggle (a new `[pyve]`/`[test]` settings key); one line, but all-or-nothing.
- *Per-env* — an `[env.<name>]` flag (e.g. `isolated = true`) that suppresses the warning when **targeting** a marked env; surgical (keep the warning for the catch-all `testenv`, silence the deliberate smokes).

**Recorded and rejected-for-now: declaration-as-signal (auto-silence, no field).** Suppress whenever every other pytest-carrying env is itself a declared `purpose = "test"` env. Zero-config and `modelfoundry` goes quiet for free — but it **silently removes a real check**: the silent-skip trap still exists *between* declared test envs (a `smoke-pytorch` test that `importorskip("tensorflow")` vanishes with no trace), and it conflates "declared" with "accepts the tradeoff." That is the kind of magic v3 has been walking back ("empty until demand," "no magic"). Keep an explicit knob.

**Schema-placement question (flag for the planner).** This is a *behavior toggle*, not an env declaration — it doesn't fit `[env.<name>]` cleanly unless per-env, and would be `pyve.toml`'s **first "project preference" key**, possibly seeding a `[pyve]`/`[test]` settings section. Per project-essentials, per-*project* prefs do belong in `pyve.toml` (only per-*user* prefs go to `~/.config/pyve/`), so it is the right home; the section shape is the design call. Must route through the single TOML reader ([`pyve_toml_helper.py`](../../lib/pyve_toml_helper.py) + [`manifest.sh`](../../lib/manifest.sh)) and validate (line-attributed error on a bad value).

**Out of scope.** The `root` pytest-probe bug (separate story above). Changing *when* the advisory fires beyond the opt-out (the heuristic itself). Removing the env var — it stays as a one-off/CI override (matrix mode sets it internally per-subshell); the manifest field is an *additional*, visible surface, and precedence (env var vs. manifest) is a `plan_production_phase` detail.

**Tasks (refine at `plan_production_phase`).**

- [ ] Decide the shape: project-wide toggle vs. per-env `isolated` flag (or both), and the schema home (new `[pyve]`/`[test]` section vs. per-env field).
- [ ] Schema + reader: add the field to the closed vocabulary in [`pyve_toml_helper.py`](../../lib/pyve_toml_helper.py); expose a [`manifest.sh`](../../lib/manifest.sh) accessor; validate with a line-attributed error.
- [ ] Gate: route the advisory's suppression check ([plugin.sh:4139](../../lib/plugins/python/plugin.sh#L4139)) through the manifest field as well — env var **or** manifest opt-out suppresses; document precedence.
- [ ] Tests: a project declaring the opt-out → no advisory on `pyve test --env <X>`; without it → advisory still fires; the env var still works; (per-env shape) targeting an unmarked env still warns.
- [ ] Docs: [environments.md](../site/environments.md) + [pyve-toml.md](../site/pyve-toml.md) document the field; note the env var remains for one-off/CI use.

**Version:** Phase P. Shape/decompose at `plan_production_phase`. Developer owns number/placement.

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

### Subphase P-5 candidates — Security & Bootstrap Hardening

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
