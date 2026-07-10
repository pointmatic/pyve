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

**Act 2 context — the hardening mandate** *(broken down 2026-07-08 in Subphase P-2's `plan_production_phase` session — see [phase-p-subphase-2-runnability-heal-plan.md](phase-p-subphase-2-runnability-heal-plan.md) and the Subphase P-2 roster below)*.

Make Pyve's environment resolution make sense and be **bulletproof**; when the armor is pierced, give Pyve a **healing mechanism**. The developer should never have to hand-trace PATH order, version-manager pins, and venv symlinks to understand why a command misbehaves, nor hand-repair Pyve-managed state.

**Triggering incident (field-discovered 2026-06-09).** A developer's `project-guide` invocation in the pyve repo broke with a cryptic `No version is set for command project-guide` naming a Python `3.14.3` they could not place. Untangling it took a long manual trace across **four independent layers**, none of which any Pyve command could see or explain:

1. **PATH shadowing.** `python` reported 3.14.4 while `.tool-versions` pinned 3.12.13 — because direnv had prepended an activated `.venv/bin` ahead of `~/.asdf/shims`, so the asdf pin never governed `python` at all. `project-guide`, present in neither `.venv` nor `~/.local/bin`, fell through to the asdf shim where the 3.12.13 pin *did* apply — and 3.12.13 had no project-guide.
2. **Interpreter drift.** The `.venv` python was a frozen symlink to asdf 3.14.4 (its creation-time interpreter), drifted from the now-3.12.13 pin — a venv never tracks later `.tool-versions` edits.
3. **Dead Pyve-managed artifacts.** `~/.local/bin/project-guide` was a dangling symlink, and the hosted toolchain venv's `project-guide` had a `bad interpreter` shebang — both pointing at a deleted path. Yet both passed Pyve's existence checks.
4. **The 3.14.3 mystery.** project-guide 2.12.0 happened to be pip-installed into one asdf interpreter (3.14.3); asdf surfaced that version number in its rejection message, with no context a human could decode.

**Core anti-pattern to eliminate: existence ≠ runnability.** Pyve's health/hosting code asserts that artifacts *exist* (`-x` / `-f` / `-d`) rather than that they *run*. The canonical trap: [`_compose_check_pyve_hosting`](../../lib/check_composer.sh#L121) reports `project-guide hosting: provisioned` on `[[ -x "$venv_dir/bin/python" ]]`, which passes for a venv whose python symlink targets a deleted interpreter. Story N.bo began the correction at the project-guide resolver (a runnability-honoring `PYVE_PROJECT_GUIDE_BIN` override seam); this subphase generalizes it across the codebase.

**Design pillars (Act 2 — decomposed into the Subphase P-2 roster, 2026-07-08).**

1. **Runnability probes.** Replace existence checks throughout hosting/health code with probes that actually execute the artifact (`python --version`, `project-guide --version`, version-manager resolution) and classify the failure: dead interpreter, asdf "no version set", dangling symlink, missing command, version-manager-not-installed. A health check that can be fooled by a broken symlink is not a health check.
2. **Resolution reasoning in `pyve check`.** Turn the manual trace into automated narrative: for each managed command, report *where* it resolves and *why* — PATH-slot ordering, venv-shadows-pin, reachability under the active pin, venv↔pin interpreter drift — in the plain language a human had to reconstruct by hand. `check` should have said, unprompted: "`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13); `project-guide` falls through to the asdf shim under that pin, which has no project-guide → install it into 3.12.13 or repoint the pin."
3. **Healing mechanism (`pyve heal`, or `pyve check --fix`).** Safe, idempotent, **confirm-before-destroy** repairs for every failure class the probes detect: rebuild a toolchain venv with a dead interpreter; re-link a dangling `~/.local/bin` shim; rebuild a `.venv` whose interpreter drifted from the pin (destructive → explicit confirmation); install a missing managed command into the *selected* interpreter. Reversible and re-runnable; never silently mutates without surfacing what it will do.
4. **Close the upstream cause — the test-isolation leak.** The triggering incident was *manufactured by Pyve's own test suite*: [`_isolate_home`](../../tests/integration/test_project_guide_integration.py#L211-L217) (integration harness) symlinks the developer's **real** `~/.asdf` and `~/.local` into the test's fake `$HOME`, so any project-guide/toolchain-provisioning test writes hosting artifacts into real developer state — which dangles when the test's tmpdir is cleaned up. Re-scope `_isolate_home` so the suite can never again mutate a real home (provision into a fully self-contained fake `$HOME`, or stub provisioning entirely). N.bo's `PYVE_PROJECT_GUIDE_BIN` seam closes one path; the version-manager (`.asdf`) and self-install paths remain open.

**Scope notes.** `lib/ui/` primitives stay pyve-agnostic (the lib/ui boundary invariant). Healing never destroys without explicit confirmation. Builds on Story N.bi (check hosting/toolchain surfacing), Phase O (check/status expand-collapse long-form output), and Story N.bo (runnability override seam + the existence-vs-runnability framing). Ships as v3.2.0; the story breakdown landed 2026-07-08 (Subphase P-2 roster below).

**Conceptual work first (Phase P, not started).** The `purpose` lifecycle (`run`/`test`/`utility`/`temp`) and environment durability need a *conceptual* pass before any lifecycle code: **what precious resource each purpose protects**, and why preservation is a *cost-cache + artifact* concern, not a "survives-purge" ranking (the principle: *irreproducibility is the bug; we never preserve because an env is irreplaceable*). The framing seed is [env-lifecycle-concept.md](env-lifecycle-concept.md). The intended mode sequence is **`refactor_document`** (fold the framing into `concept.md` / `project-essentials.md`'s `purpose:` entry / `tech-spec.md`) → **`plan_phase`** (derive targeted stories). This corrects, among other things, the current essentials hint that "utility envs survive `pyve purge`" (the new framing makes `utility` the disposable one). Pairs with the declarative-env-setup megastory (now Story P.l).

**Subphases**

Each subphase has a theme (with adhoc bug fixes as needed).

- **Subphase P-1 (v3.1.0): Conceptual clarification & UX Foundation** — the keystone parameter decision-graph, an explicit single-sourced manifest, desired-vs-actual env state, batch lifecycle, and one consistent verb model. *(Declarative env setup — formerly its own subphase — is folded into P-1's Pillar II.)*
- **Subphase P-2 (v3.2.0): Runnability probes & environment healing** — Act 2 (the four pillars above).
- **Subphase P-3 (v3.3.0): Workflow & DX polish** — CI hygiene + developer-experience.
- **Subphase P-4 (v3.4.0): Deeper plugin work** — plugin enrichment (TypeScript, …).
- **Subphase P-5 (v3.5.0): Security & bootstrap hardening** — download integrity + version pinning.

Story breakdown for each subphase is drafted in its own `plan_production_phase` session when it activates (Story P.d); Subphase P-2's roster was drafted 2026-07-08. Later subphases' candidates remain parked in `## Future`.

---

## Subphase P-2: Runnability probes & environment healing (v3.2.0)

**Scope (Act 2).** Make environment *resolution* explainable and Pyve's managed state self-healing — the four design pillars in the preamble: (1) **runnability probes** that execute artifacts and classify the failure; (2) **resolution reasoning** in `pyve check` (where/why each managed command resolves — PATH-slot order, venv-shadows-pin, interpreter drift); (3) a **healing mechanism** (`pyve heal` / `pyve check --fix`) — safe, idempotent, confirm-before-destroy; (4) **close the test-isolation leak** so the suite never mutates a real `$HOME`. Builds directly on P-1: `heal` restores toward the intent the explicit manifest captures and the operational state it recorded.

**North-star design:** [phase-p-subphase-2-runnability-heal-plan.md](phase-p-subphase-2-runnability-heal-plan.md) — gap analysis, production concerns, negotiated breaking changes, and the open questions each story resolves. **Version target: v3.2.0 (minor)** per the phase's multi-release exception; the two breaking-adjacent changes ("`pyve check` gets honest", human-output reshape) were negotiated **technically-but-trivially breaking** (plan §6). Roster drafted 2026-07-08; story letters continue from the archived P-1 roster (P.u → P.v). The test-isolation fix leads deliberately: later stories' integration tests exercise provisioning — exactly the surface the leaky harness writes into a real `$HOME`.

---

### Story P.v: Close the test-isolation leak — the integration suite can never mutate a real `$HOME` [Done]

*(Pillar 4 — plan §3. Ordered first deliberately: later P-2 stories' integration tests exercise provisioning and heal, exactly the paths the leaky harness writes into the real `$HOME`.)*

**The leak.** `_isolate_home` ([tests/integration/test_project_guide_integration.py](../../tests/integration/test_project_guide_integration.py)) fakes `$HOME` but symlinks the developer's real `~/.asdf`, `~/.pyenv`, `~/.local`, `.tool-versions`, and `.python-version` into the fake home so version managers still resolve. Any test that provisions Pyve hosting (`self install` / `self provision` / `pyve_project_guide_ensure`) or pip-installs through an asdf interpreter writes into the **real** `~/.local/share/pyve/toolchain`, `~/.local/bin`, and `~/.asdf` — artifacts that dangle when the test tmpdir is reaped. This is what manufactured the 2026-06-09 triggering incident. A second symptom: PATH-stub tests are not hermetic — internal callsites resolve project-guide by hosted **absolute path** (deliberately ignoring PATH), so a PATH-only stub is silently bypassed and the test goes green against whatever real project-guide the machine hosts.

**Tasks.**

- [x] Inventory the tests that reach provisioning / self-install / version-manager writes (the `self install`, `self provision`, `pyve_project_guide_ensure`, and pip-through-asdf paths); classify each: needs real provisioning against a sandbox vs. can stub. *(One live leak found: the `--project-guide`-override auto-skip test drove real `pyve_project_guide_ensure`; now stubbed via `PYVE_PROJECT_GUIDE_BIN`. All other hook tests were already stubbed; `test_bootstrap.py`'s own fixture was already self-contained; no other file opts into the hook or executes `self install`/`self provision`.)*
- [x] Re-scope `_isolate_home` to a fully self-contained fake `$HOME`: no symlinks into the real `~/.local` / `~/.asdf` / `~/.pyenv`; interpreter supplied via `PYVE_PYTHON`, project-guide via `PYVE_PROJECT_GUIDE_BIN` (the top-precedence seams), version-manager fixtures faked in-sandbox. *(Fake in-sandbox `asdf` + `pyenv` on a sanitized PATH — every inherited entry resolving into the real home is dropped; `PYENV_ROOT` / `ASDF_DATA_DIR` / `XDG_*` pinned inside the sandbox; contract enforced by `TestIsolatedHomeIsSelfContained`.)*
- [x] Provisioning-path tests provision into the fake home and assert artifacts land there (positive) and never in the real home (negative). *(`TestProvisioningIsSandboxed` runs a real `pyve self provision` in the sandbox.)*
- [x] Suite-level regression guard: record the real `~/.local/bin/project-guide` + toolchain-dir state before the run; fail teardown if the suite touched them. *(`real_home_mutation_guard` in conftest.py on the `tests/helpers/home_guard.py` snapshot/diff functions; teardown-failure behavior verified against a scratch guarded home.)*
- [x] Full integration suite green locally + CI; document the harness contract at the top of the test file (what is faked, what is stubbed, what a new test must never do). *(Locally green except 12 failures verified pre-existing on clean `main` — stale v2-surface expectations in `test_auto_detection` / `test_reinit` / `test_subcommand_cli` / `test_venv_workflow`, candidates for the Future "Fix pre-existing integration test failures" story. CI validation lands with the developer's push.)*

---

### Story P.w: silent-skip advisory's `root` pytest probe is broken for a venv root + named envs (the standard v3 topology) [Done]

*(Field-discovered 2026-06-17, `modelfoundry`, while explaining why `pyve test --env smoke-pytorch` listed `testenv typecheck` in the silent-skip advisory. The advisory itself fired correctly; tracing it surfaced a latent false-negative in the `root` probe.)*

**The advisory.** `pyve test --env <X>` runs a guard ([plugin.sh:4129-4160](../../lib/plugins/python/plugin.sh#L4129-L4160)): if any env *other* than the target has pytest importable, it warns, because tests that `pytest.importorskip(...)` a stack absent from the target **silently SKIP and look green**. It probes each candidate via `_test_env_has_pytest <name>` ([plugin.sh:3793-3815](../../lib/plugins/python/plugin.sh#L3793-L3815)), which resolves the env's `bin/python` and runs `import pytest`.

**Bug — the `root` branch resolves the wrong path.** For `root` ([plugin.sh:3797-3806](../../lib/plugins/python/plugin.sh#L3797-L3806)) it does **not** use the canonical resolver: it globs `.pyve/envs/*`, takes the first dir, and builds `<dir>/bin/python`. But venv-backed envs nest under `<dir>/venv/bin/python` (conda under `<dir>/conda/bin/python`), so that path **never exists**. It then assigns `py` to the bogus (non-empty) string, which makes the `[[ -z "$py" ]]` guard **skip the `.venv` fallback**, and the function returns `1` ("no pytest") unconditionally whenever `.pyve/envs/` holds any named env.

**Effect — a false negative in exactly the guard's reason for being.** On the standard v3 topology — a **venv `root` plus named envs under `.pyve/envs/`** — `root` is never correctly probed. If `.venv` actually has pytest, the silent-skip guard **fails to warn** about it. (Harmless in `modelfoundry` only by accident: its `.venv` root genuinely lacks pytest, so the broken probe returns the right answer for the wrong reason.)

**Root cause.** The `root` branch predates the N.bf.14 root-slot model and assumes the pre-N.bf.14 *flat* micromamba layout (`.pyve/envs/<first>` with `conda-meta` directly inside). The non-root branch already does the right thing — `resolve_env_path "$env_name"` — so the fix is to make `root` use the same canonical, backend-aware resolution.

**Out of scope.** The advisory's *heuristic* (multiple deliberately-isolated test envs → a benign false **positive**, silenced by `PYVE_NO_TESTENV_ADVISORY=1`; the declarative exemption question is Story P.x). The non-root branch (correct). The mutation-on-read concern lives elsewhere — `pyve test` is a sanctioned write path, so firing the opportunistic migrator via `resolve_env_path root` here is acceptable.

**Tasks.**

- [x] Reproduce (red): a fixture with a venv `root` carrying pytest in `.venv` **plus** a named `purpose="test"` env; `pyve test --env <named>` → assert `root` appears in the advisory list (it does not today). *(Probe-level red plus a real-probe advisory-level red in `test_test_env_advisory.bats`.)*
- [x] Fix `_test_env_has_pytest`'s `root` branch to resolve the interpreter via the canonical backend-aware path (mirror the non-root branch's `resolve_env_path root`: `.venv` for venv, `.pyve/envs/root/conda` for micromamba — or `resolve_main_micromamba_path` for a non-mutating read), and **delete the `.pyve/envs/*` first-dir glob**. *(Root and non-root branches collapsed into one `resolve_env_path`-based body.)*
- [x] Regression: a venv root **without** pytest + named envs → `root` still excluded (no false positive reintroduced); a micromamba root **with** pytest → `root` correctly detected. *(Also: no root env at all + named envs → excluded, the modelfoundry accident shape.)*
- [x] Full suite; zero regressions. *(Bats unit: 2164 green; integration: 217 passed — 3 additional `test_reinit.py` failures surfaced past the old `--maxfail` horizon, all verified pre-existing on clean HEAD, same family as the known interactive-reinit failures.)*

---

### Story P.x: A declarative `pyve.toml` opt-out for the silent-skip advisory — project-scoped and visible, not a per-shell env var [Done]

*(Design direction, 2026-06-17, from the `modelfoundry` advisory discussion. Pairs with Story P.w — same advisory — and resolves its out-of-scope note "whether declared `purpose=test` envs should be exempted… is a separate question.")*

**The gap.** The silent-skip advisory ([plugin.sh:4129-4160](../../lib/plugins/python/plugin.sh#L4129-L4160)) fires on every `pyve test --env <X>` when any other env also has pytest. A project that **deliberately** runs several isolated `purpose = "test"` envs (the `modelfoundry` shape: a default suite + per-framework smoke envs + a `typecheck` env, each with its own pytest) trips it on every run — a benign false positive. The only suppression today is `PYVE_NO_TESTENV_ADVISORY=1` ([plugin.sh:4139](../../lib/plugins/python/plugin.sh#L4139)): per-shell (must re-prefix every invocation), or exported and **leaky** (silences it for *every* project), and **invisible** — nothing in the repo records that the project opted out.

**Why now.** The env var shipped (M.c/M.o) under the assumption that "multiple envs with pytest" was rare — the era of *one main env + one testenv*. v3's named-env model makes a multi-test-env project **mainstream**, so a project-scoped, version-controlled, reviewable suppression belongs in the manifest, consistent with the "`pyve.toml` is the canonical declaration" essentials rule.

**Design — an explicit declarative opt-out.** A `pyve.toml` field that says "I run multiple test envs on purpose; don't nag." It preserves the signal as **opt-out** (you consciously declare it), is reviewable in the diff, and doesn't leak across projects. **Open sub-question (plan §8.2), resolved by this story's first task: project-wide vs. per-env.**
- *Project-wide* — one toggle (a new `[pyve]`/`[test]` settings key); one line, but all-or-nothing.
- *Per-env* — an `[env.<name>]` flag (e.g. `isolated = true`) that suppresses the warning when **targeting** a marked env; surgical (keep the warning for the catch-all `testenv`, silence the deliberate smokes).

**Recorded and rejected-for-now: declaration-as-signal (auto-silence, no field).** Suppress whenever every other pytest-carrying env is itself a declared `purpose = "test"` env. Zero-config and `modelfoundry` goes quiet for free — but it **silently removes a real check**: the silent-skip trap still exists *between* declared test envs (a `smoke-pytorch` test that `importorskip("tensorflow")` vanishes with no trace), and it conflates "declared" with "accepts the tradeoff." That is the kind of magic v3 has been walking back ("empty until demand," "no magic"). Keep an explicit knob.

**Schema-placement note.** This is a *behavior toggle*, not an env declaration — it would be `pyve.toml`'s **first "project preference" key**, possibly seeding a `[pyve]`/`[test]` settings section. Per project-essentials, per-*project* prefs do belong in `pyve.toml` (only per-*user* prefs go to `~/.config/pyve/`), so it is the right home; the section shape is the design call. Must route through the single TOML reader ([`pyve_toml_helper.py`](../../lib/pyve_toml_helper.py) + [`manifest.sh`](../../lib/manifest.sh)) and validate (line-attributed error on a bad value).

**Out of scope.** The `root` pytest-probe bug (Story P.w). Changing *when* the advisory fires beyond the opt-out (the heuristic itself). Removing the env var — it stays as a one-off/CI override (matrix mode sets it internally per-subshell); the manifest field is an *additional*, visible surface.

**Tasks.**

- [x] Decide the shape: project-wide toggle vs. per-env `isolated` flag (or both), and the schema home (new `[pyve]`/`[test]` section vs. per-env field); document the decision in the P-2 plan (§8.2). *(Per-env `isolated = true` on `[env.<name>]` — surgical, fits the existing closed vocabulary, defers the settings-section shape until a second preference key exists; target-side-only semantics.)*
- [x] Schema + reader: add the field to the closed vocabulary in [`pyve_toml_helper.py`](../../lib/pyve_toml_helper.py); expose a [`manifest.sh`](../../lib/manifest.sh) accessor; validate with a line-attributed error. *(`KNOWN_ENV_KEYS` + strict-boolean normalization + `_decl_line` scan → `pyve.toml:<n>:`-prefixed error — the manifest's first line-attributed validation; `manifest_is_isolated` mirrors `manifest_is_lazy`.)*
- [x] Gate: route the advisory's suppression check ([plugin.sh:4139](../../lib/plugins/python/plugin.sh#L4139)) through the manifest field as well — env var **or** manifest opt-out suppresses; document precedence. *(Either alone suffices; precedence documented at the gate.)*
- [x] Tests: a project declaring the opt-out → no advisory on `pyve test --env <X>`; without it → advisory still fires; the env var still works; (per-env shape) targeting an unmarked env still warns. *(Plus: isolated envs stay listed as candidates when an unmarked env is targeted; core-key/attr non-leak; bash-3.2 `set -u` sweep.)*
- [x] Docs: [environments.md](../site/environments.md) + [pyve-toml.md](../site/pyve-toml.md) document the field; note the env var remains for one-off/CI use. *(Also [testing.md](../site/testing.md), where the advisory + env var were already documented.)*
- [x] Full suite; zero regressions.

---

### Story P.y: `project-guide` status is split + v2-leftover — unify into one readout that names *how* it's present (local pip vs toolchain) + show its version (status & self provision) [Done]

*(v2-wiring removal — same family as P-1's config-source retirement (P.i, archived). project-guide stopped being a per-project Python dependency in v3, but a v2 status check survived.)*

**Discovered:** 2026-06-13, pyve repo. `pyve status` shows a self-contradiction: `[python]` → Integrations → `project-guide: not installed`, while the `[project-guide]` section directly below → `pyve-hosted (toolchain)`. And `pyve self provision` (which provisioned + linked project-guide) didn't move the "not installed" line.

**Root cause — two readouts checking different locations; the `[python]` one is v2 wiring.** The Integrations row ([plugin.sh:3567-3577](../../lib/plugins/python/plugin.sh#L3567-L3577)) checks `[[ -x "$env_path/bin/project-guide" ]]` — project-guide pip-installed in the **project venv** (the v2 location). In v3 project-guide is a Pyve-managed **global** tool (toolchain venv + `~/.local/bin` shim), never in `.venv`, so that row reports "not installed" regardless of hosting — and `self provision` can't change it because the row looks at the wrong place. The authoritative `[project-guide]` section (`_compose_status_project_guide`, [status_composer.sh:42](../../lib/status_composer.sh#L42)) reports the real state. The Integrations row is what N.aw's "Python plugin project-guide status stays suppressed" missed.

**Design (developer-specified, 2026-06-13).**
- **One section / one line.** Keeping a check for a pip-installed project-guide is fine — but it belongs in **one** readout, not split across two contradictory ones. Drop the `[python]` Integrations project-guide row; the `[project-guide]` section is the single home.
- **Name *how* it's present.** Fold the local-pip check into that one readout: installed locally (pip in the project env) but not in the toolchain → report it as present, labeled **"local pip"** (or similar); in the toolchain → **"pyve-hosted (toolchain)"**; neither → "not installed". (`_compose_status_project_guide` already distinguishes "managed by your project (pip)" vs "pyve-hosted" — make it the sole source and relabel for clarity.)
- **Show the version, in both places.** Display the resolved project-guide **version** in `pyve status` (e.g. `pyve-hosted (toolchain) v2.15.1` / `local pip v2.15.1`) **and** in `pyve self provision` output (e.g. `Installed project-guide v2.15.1 into the Pyve toolchain`), so it's clear what was installed.

**Tasks.**

- [x] Reproduce (red): a pyve-hosted, no-project-venv-copy project → `pyve status` emits BOTH `project-guide: not installed` ([python]) and `pyve-hosted (toolchain)` ([project-guide]). Assert a single, non-contradictory readout after the fix. *(Full-binary test: `[project-guide]` present, no `project-guide:` row anywhere — deterministic on any host's hosting state.)*
- [x] Remove the project-guide row from the `[python]` Integrations block ([plugin.sh:3567-3577](../../lib/plugins/python/plugin.sh#L3567-L3577)); the `[project-guide]` section is the sole readout. *(Help text's integration list updated too.)*
- [x] Make `_compose_status_project_guide` name the presence mode — toolchain-hosted / project-local pip / neither — and **probe runnability** (`project-guide --version`), not just `-x` (existence ≠ runnability, the Phase P pillar). *(Modes: `local pip|conda [vX]` — wins the label, hosted copy named inline; `pyve-hosted (toolchain) [vX]`; hosted-but-broken → `broken` + repair hint; `not installed`. Local binary located backend-aware via the non-mutating resolvers.)*
- [x] Surface the resolved version in the status readout and in `self_provision`'s "Installed project-guide …" line ([self.sh](../../lib/commands/self.sh)). *(Probe failure degrades to the unversioned message.)*
- [x] Tests: hosted-only / local-pip-only / both / neither → one correct labeled readout each, with version; `self provision` prints the installed version. *(Plus hosted-but-broken and declared-not-installed; 8-test matrix in `test_pyve_hosting_diagnostic.bats`, 2 provision-message tests in `test_project_guide_hosting.bats`.)*
- [x] Full suite; zero regressions.

---

### Story P.z: Per-env runnability probe — plugins own a "canary" command `pyve check` executes (existence ≠ runnability) [Planned]

*(Field-discovered 2026-06-12, ml-datarefinery migration. Concrete embodiment of Phase P Pillar 1 (runnability probes) and the detection half of Pillar 3 — Story P.ab consumes this story's verdicts.)*

**Discovered.** A v2→v3 migration relocated a testenv (`.pyve/testenv/venv/` → `.pyve/envs/testenv/venv/`) under a **pre-v3.0.5** binary whose mover did a bare `mv` without rewriting the baked console-script shebangs. Every wrapper (`pip`, `pytest`, `ruff`, `mypy`, the editable package's entry point) kept `#!.../.pyve/testenv/venv/bin/python` baked in — pointing at a deleted path → `bad interpreter: No such file or directory`. The env's `python` symlink stayed valid, so `python -m pytest` worked while every wrapper failed. (v3.0.5+ repairs shebangs at move time, but the repair is **move-time-only** and cannot heal an env already relocated by an older binary — see project-essentials "conda/venv environments are not relocatable — repair the baked prefix on move, and probe runnability (not existence) before trusting one".)

**Symptom — `pyve check` reports a false green.** `check_environment`'s testenv probe ([plugin.sh:3031-3042](../../lib/plugins/python/plugin.sh#L3031-L3042)) runs `<env>/bin/python -c 'import pytest'`, which **bypasses the broken wrappers** (the `python` symlink is fine), so check prints `✓ testenv: pytest installed` for an env whose every console script is dead. The root-env probe is the same shape (`-d` + `-x bin/python`). No `pyve check` line tells the developer the env is unusable; the only signal today is `bad interpreter` at runtime.

**Root cause — existence ≠ runnability, *and the probe targets the wrong artifact*.** Health code stats `bin/python` or runs `python -m …` — but a **console-script wrapper** (a file carrying a baked-in shebang) is exactly what breaks on relocation / dangling symlink / dead interpreter, and `python -m X` can never catch a dead-shebang wrapper. The probe must execute a wrapper, not the interpreter-module path.

**Design — a plugin-owned canary hook.** Add an optional plugin-contract hook (working name `env_probe` / `canary`) so each plugin defines, per backend, a **minimal runnable command + expected response** that `pyve check` executes against every declared *and materialized* env:

- Executes a **console-script wrapper** (baked shebang), never `python -m …` — e.g. the Python plugin runs `<env>/bin/pip --version` (pip is always present in a venv/conda env) and expects a `pip X.Y …` line. A dead shebang surfaces as `bad interpreter` → non-zero → probe fails.
- Returns a **classified verdict**: `runnable` / `dead-shebang (env relocated or interpreter deleted)` / `dangling symlink` / `missing interpreter` / `not materialized` / **`orphaned` (materialized on disk but **not declared**, OR a declared **non-materializable** env — e.g. a `none`/advisory root — that is **nonetheless materialized**: a state↔declaration contradiction)**. `pyve check` renders `✓ <env>: runnable`, or `✗ <env>: console scripts broken (env relocated; shebangs stale) → <role-correct rebuild>`, or `✗ <env>: materialized but not declared (orphan) → remove it` (heal = delete the undeclared/contradictory tree — the modelfoundry case: a broken micromamba env at `.pyve/envs/root/conda/` while the manifest declares `[env.root] backend = "none"`).
- Backend-aware *within* the plugin: venv → execute `bin/pip --version` directly; micromamba → `micromamba run -p <env> pip --version` (reuses O.m's conda exec). `none`/advisory + not-materialized envs → no probe (declarative-only; reuse `_env_backend_is_advisory`).
- Default contract impl is a no-op (plugins opt in), matching the contract's "implement a subset of hooks" design ([lib/plugins/contract.sh](../../lib/plugins/contract.sh)).

This is the **detection** half; the heal action it feeds (Pillar 3 / Story P.ab) for a dead-shebang env is the per-env destructive rebuild (`pyve env purge <name> --force` → `pyve env init <name>` → reinstall), offered with confirmation.

**Out of scope.** The heal/auto-remediation *action* (Story P.ab consumes this story's verdicts). The move-time shebang repair (already shipped v3.0.5). The test-isolation leak (Story P.v). Pyve-hosting runnability (already done — `pyve_toolchain_runnable` / `pyve_project_guide_runnable`); this generalizes the same discipline to *project* envs.

**Tasks.**

- [ ] Add the `env_probe` (canary) hook to the plugin contract with a no-op default; document the verdict vocabulary.
- [ ] Python plugin: implement the canary — execute a console-script wrapper (`bin/pip --version`; venv direct / micromamba via `micromamba run -p`), validate the expected response, classify the failure (dead-shebang / dangling / missing / not-materialized / orphaned). The **orphaned/contradiction** class is a manifest↔disk reconciliation, not a per-env probe: detect a materialized env with no matching declaration, or a declared non-materializable backend (`none`/advisory via `_env_backend_is_advisory`) that has an on-disk env anyway.
- [ ] Wire `pyve check` to invoke the canary per declared+materialized env; replace the existence-only / `python -m`-style testenv + root probes with the runnability verdict + actionable heal hint, so the `python -c 'import pytest'` false-green can no longer mask a dead-wrapper env. Probes carry a bounded runtime (no hangs on a wedged interpreter); the 0/1/2 exit-code contract is preserved.
- [ ] The heal hint is **role-correct**: a broken **root** env points at `pyve init --force` (the `pyve env` namespace rejects `root` — it is selection-only); a broken **named testenv** at `pyve env purge <name> --force && pyve env init <name>`. `pyve check` must **never** suggest the rejected `pyve env purge root` (the dead-end a developer hit in the field). Both root and named-env breakage must be detected — the root micromamba env (relocated `.pyve/envs/<configured>/` → `.pyve/envs/root/conda/` by a pre-repair binary) is a real instance, not just the testenv case.
- [ ] Tests: a relocated-unrepaired fixture (valid `bin/python` symlink + dead-shebang `bin/pip`) → check reports `✗ … console scripts broken`, not a false green; a healthy env → `✓ runnable`; venv + micromamba backends; **root and named** envs; `none`/advisory + not-materialized → no probe; **an orphan/contradiction fixture** (a materialized `.pyve/envs/root/conda/` under a `[env.root] backend = "none"` manifest) → `✗ … materialized but not declared (orphan)`, not silence.
- [ ] Full suite; zero regressions.

---

### Story P.aa: Resolution reasoning in `pyve check` — narrate where each managed command resolves and why [Planned]

*(Pillar 2 — plan §3. The automated version of the manual four-layer trace from the 2026-06-09 triggering incident.)*

**The gap.** When a managed command misbehaves, nothing in Pyve explains resolution: which PATH slot wins (a direnv-activated `.venv/bin` shadowing `~/.asdf/shims`; a `~/.local/bin` shim preceding the pin), whether the winning interpreter drifted from the declared pin (a `.venv` python frozen to its creation-time interpreter while `.tool-versions` moved on), or why a version manager rejects a command ("no version set" under the active pin). The developer hand-traces the layers; `check` should narrate them unprompted: *"`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13); `project-guide` falls through to the asdf shim under that pin, which has no project-guide → install it into 3.12.13 or repoint the pin."*

**Design.**
- **A PATH-slot tracer:** for a command name, enumerate every PATH entry that provides it, mark the winner, and classify each slot (project env bin / `~/.local/bin` shim / version-manager shim / system). The classification vocabulary feeds Story P.ab's heal hints.
- **Drift detection:** winning interpreter vs. the declared pin (manifest python / `.tool-versions`); venv creation-time interpreter vs. the current pin; version-manager "no version set" recognized and named as such.
- **Rendering:** composes into `check` per the Phase O expand/collapse long-form patterns — concise by default, full trace under verbose. Findings are classified (machine class + plain-language line), not prose-only, so P.ab can map each to a repair.
- **Coverage:** the managed-command set and narrative depth are this story's first design decision (plan §8.4) — python + pip + project-guide at minimum; whether plugins extend the set (Node's node/npm) is decided here.

**Constraints.** Offline; bounded runtime; the 0/1/2 exit-code contract is preserved — reasoning lines are diagnostic narrative, and only finding classes that are already-broken states affect the verdict.

**Tasks.**

- [ ] Decide the managed-command set + default-vs-verbose depth (plan §8.4); document the finding-class vocabulary.
- [ ] Implement the PATH-slot tracer + slot classifier (a pure, testable helper; no mutation, no network).
- [ ] Implement drift detection: pin vs. winner, venv↔pin creation-time drift, version-manager "no version set" classification.
- [ ] Compose into `pyve check` per the Phase O long-form patterns; each finding carries its class + a role-correct hint.
- [ ] Tests: fixture PATH layouts reproducing the incident's four layers → the narrative names the shadow, the drift, and the fall-through; a healthy layout → quiet; bounded + offline (CI-safe).
- [ ] Full suite; zero regressions.

---

### Story P.ab: Healing mechanism — classified failure → safe, idempotent, confirm-before-destroy repair (`pyve heal` / `pyve check --fix`) [Planned]

*(Pillar 3 — plan §3. Consumes Story P.z's canary verdicts and Story P.aa's resolution findings. Supersedes the long-parked "Auto-Remediation for Diagnostics (`pyve check --fix`)" stub, retired from `## Future` with this roster.)*

**The promise.** Every failure class the P-2 detection stories classify gets a safe, idempotent, confirm-before-destroy repair — the developer never hand-repairs Pyve-managed state:

| Detected class (source) | Repair (existing machinery) |
|---|---|
| dead-interpreter toolchain venv (hosting probes) | rebuild via `pyve self provision` |
| dangling `~/.local/bin` shim (hosting probes) | re-link / re-provision |
| dead-shebang / dead-wrapper **root** env (P.z) | `pyve init --force` (destructive → confirm) |
| dead-shebang / dead-wrapper **named** env (P.z) | `pyve env init <name> --force` (destructive → confirm) |
| venv↔pin interpreter drift (P.aa) | rebuild toward the declared pin (destructive → confirm) |
| orphaned tree — materialized but undeclared (P.z) | remove (destructive → confirm) |
| missing managed command under the active pin (P.aa) | install into the *selected* interpreter |

**Design constraints.**
- **Plan-then-confirm:** enumerate detected faults + intended repairs before acting; `--yes` assents to the batch; destructive repairs are individually confirmed; `--force` stays reserved for escalation (never a prompt-skip synonym, per the P.l.1 flag semantics); never silently mutates.
- **Idempotent + re-runnable:** a post-success re-run reports "nothing to heal"; a partial-failure re-run resumes safely.
- **Repairs route through existing verbs** (`self provision`, `pyve init --force`, `pyve env init <name> --force`, shim re-link) — heal orchestrates; it does not grow a parallel rebuild path. Destructive rebuilds ride P-1's state record + `[env.<name>]` recipes: restore toward declared intent, never guess.
- **Role-correct routing:** never suggests or executes the rejected `pyve env purge root`.
- **No upgrades:** heal repairs broken state; healthy-but-stale tools are Story P.ad's hints (plan §8.5 — the boundary is confirmed in this story's first task).

**Tasks.**

- [ ] Decide the command surface — `pyve heal` vs. `pyve check --fix` vs. both-with-delegation (plan §8.1) — and confirm the heal-vs-upgrade boundary (plan §8.5); record both in the P-2 plan.
- [ ] Define the class→repair map + destructiveness tiers; document the vocabulary alongside P.z's verdicts.
- [ ] Implement plan-then-confirm execution over the map, routed through the existing verbs; `--yes`/`--force` per the established semantics; non-TTY behavior defined (report, never destroy).
- [ ] Idempotency + partial-failure resume; exit codes documented.
- [ ] Tests: one fixture per failure class → the correct repair is proposed and applied; refusal + non-TTY paths; a healthy project → "nothing to heal"; no silent mutation anywhere.
- [ ] Help text + site docs for the new surface.
- [ ] Full suite; zero regressions.

*(Scope note: likely splits into P.ab.# at implementation — the class→repair map is the natural seam.)*

---

### Story P.ac: Integration spike — Pyve's first network touchpoint: bounded latest-version lookup (PyPI + Homebrew tap), cache, offline degrade [Planned]

*(Integration spike per the new-integration-boundary rule: `pyve check` has been offline by design, and Story P.ad adds a network dimension. Time-boxed; the deliverable is the documented outcome, not production code.)*

**Uncertainty to reduce.** Can a latest-version probe (project-guide via `https://pypi.org/pypi/project-guide/json`; pyve via the Homebrew tap / GitHub releases API) be made *unconditionally CI-safe*: bounded wall-time on dead/slow/filtered networks, silent offline degrade, rate-limit tolerance (GitHub: 60/hr anonymous), and a TTL cache in an XDG-appropriate location — using only tools pyve already depends on (`curl`)?

**Deliverables (documented outcome).**

- [ ] Prove the fetch pattern: `curl` with connect/total timeouts against both endpoints; measure worst-case wall-time on unreachable/blackholed hosts.
- [ ] Prove the degrade: no network / DNS failure / 403 rate-limit → empty result, zero stderr noise, exit code unchanged.
- [ ] Decide + record: opt-in vs. opt-out network model, flag/env-var names (`--offline` / `PYVE_NO_NETWORK`), cache TTL + location.
- [ ] Write the outcome into the P-2 plan (§8.3, resolving that open question) and hand the pattern to Story P.ad.

---

### Story P.ad: `pyve check` surfaces available updates for the hosted tools and pyve itself [Planned]

**Raised:** 2026-06-08 (developer, during Story N.bj). Post-v3.0.0.

**Motivation.** `pyve check` is **local-only** today: the `[pyve]` diagnostic reports whether the toolchain is provisioned, the toolchain Python version, and whether project-guide is pyve-hosted vs project-managed — but it never asks *"is a newer version available?"* for either the globally-hosted `project-guide` (on PyPI) or `pyve` itself (on the Homebrew tap / GitHub releases). N.bj established the remediation *mechanics* (`pyve self provision` is the hosted-tool upgrade path; `brew upgrade …/pyve` or a source `git pull && pyve self install` upgrades pyve) but nothing tells a user *when* to run them. This story closes that loop: detect staleness, then print the exact remediation command for the user's install source.

**Why a separate story (not folded into N.bj).** N.bj is purely local teardown/upgrade plumbing. Staleness *detection* adds a **network dimension** to a command that is currently offline and CI-safe — a different design surface with its own risk profile. Pairs with Story P.ab (detection here; heal stays repair-only per plan §8.5 — it never auto-applies upgrades).

**Design considerations.**

- **CI-safety is the hard constraint.** `pyve check` returns structured 0/1/2 exit codes consumed by CI. A network probe must NOT flip the verdict (a stale hosted tool is *info*, never `warn`/`error`), must NOT hang CI (short connect timeout + offline-graceful: a failed/absent network degrades silently to "couldn't check"), and wants an explicit opt-out (`--offline` / `PYVE_NO_NETWORK=1`) plus short-TTL caching so every `check` isn't a fresh round-trip. The network model, timeouts, and cache shape are **adopted from Story P.ac's spike outcome**, not re-decided here.
- **Two sources, two mechanics.**
  - *project-guide latest* → PyPI JSON API (`https://pypi.org/pypi/project-guide/json`), compared against the version installed in the toolchain venv (`pyve_toolchain_venv_dir`/bin/pip show, or import metadata).
  - *pyve latest* → the Homebrew tap (or GitHub releases), compared against `$VERSION`.
- **Remediation routing keys off `detect_install_source`** (already known to `check`):
  - stale project-guide → `pyve self provision`
  - stale pyve (Homebrew) → `brew upgrade pointmatic/tap/pyve`
  - stale pyve (source clone) → `git pull && pyve self install`

**Out of scope.** Auto-*applying* upgrades (heal is repair-only; plan §8.5). Version *pinning* of the hosted tools. Any change to the 0/1/2 exit-code contract.

**Tasks.**

- [ ] Adopt the network model from P.ac's recorded outcome (opt-in vs opt-out, timeout, cache TTL + location, `--offline` / `PYVE_NO_NETWORK` surface). Confirm a network failure can never change the exit code.
- [ ] Implement a best-effort latest-version probe for project-guide (PyPI JSON) and pyve (tap / GitHub releases), each degrading silently offline.
- [ ] Wire an `info`-level staleness line into the `[pyve]` check section with the install-source-correct remediation command.
- [ ] Tests: stubbed-network "newer available → correct hint", "up-to-date → no hint", and "offline/timeout → silent, exit code unchanged".
- [ ] Document the new env var / flag in the Environment Variables table and `pyve check --help`.
- [ ] Full suite; zero regressions.

---

### Story P.ae: Subphase P-2 documentation sweep [Planned]

**Scope.** The end-of-subphase coherence pass across the public docs for every P-2 surface (mirroring P.s's shape for P-1): `check`'s canary verdicts + resolution narrative (what the new lines mean, how to read a classified finding), the heal command's reference page (repair classes, confirmation model, flag semantics), the `pyve.toml` opt-out field, the staleness hints + network model, and the Environment Variables table. Per-story docs land with their stories; this pass makes them read as one system.

**Tasks.**

- [ ] Sweep the site docs for the new `check` output (canary verdicts, resolution reasoning) with a worked example from the triggering-incident scenario.
- [ ] Heal reference page + cross-links from the check docs ("check detects → heal repairs").
- [ ] `pyve-toml.md` (opt-out field) + `environments.md` cross-refs verified; Environment Variables table updated (`PYVE_NO_NETWORK` and any new vars).
- [ ] Coherence pass: one vocabulary across check/heal/status docs (verdict names, presence modes, remediation verbs).
- [ ] CHANGELOG entries staged for every P-2 story, ready for the release story.

---

### Story P.af: v3.2.0 Tag release and validate in production [Planned]

**Scope.** Owns Subphase P-2's minor bump per the phase's multi-release exception (mirrors P.u's shape for v3.1.0).

**Tasks.**

- [ ] Pre-flight: full unit + integration suites green on main; CHANGELOG complete for every P-2 story; docs site builds clean.
- [ ] Developer invokes `project-guide bump-version 3.2.0` (version bump + CHANGELOG seed); tag ships through the normal release flow (Homebrew formula update follows).
- [ ] Validate in production on a real project: an incident-shaped fixture (dead shim / drifted venv / dead-wrapper env) → `pyve check` names it, heal repairs it with confirmation, re-check goes green.
- [ ] Post-release: verify the `brew upgrade` path and a clean-clone `pyve self install`; confirm the docs site deployed.

---

## Future

A parking lot of detailed candidate bodies. Each is assigned to a later subphase (P-3…P-5) — see the subphase roadmap above for the mapping. (Subphase P-2's candidates were pulled into its roster 2026-07-08; the tech-spec-table reconcile candidate remains parked as a doc-cleanup item.) When a subphase activates, its `plan_production_phase` session pulls its candidates from here and decomposes them into the working roster.

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
