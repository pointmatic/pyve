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

## Phase P: Harden and heal Pyve

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

**Concerns**

This phase begins after the v3.0.x release. Theme: make Pyve's environment resolution make sense and to be **bulletproof**; when the armor is pierced — give Pyve a **healing mechanism**. This is the "calm the chaos" mission applied to Pyve's own substrate: the developer should never have to hand-trace PATH order, version-manager pins, and venv symlinks to understand why a command misbehaves, and never have to hand-repair Pyve-managed state.

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

**Subphases**

Each subphase has a theme (with adhoc bug fixes as needed). 
- Subphase P-1: Conceptual clarification and documentation
- Subphase P-2: Runnability probes and environment healing
- Subphase P-3: Declarative env setup
- Subphase P-4: Workflow improvements

---

## Subphase P-1: Conceptual clarification and documentation

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

### Story P.b: v3 Plan and Documentation Refactor

Using the Phase P preamble, update Pyve concept, features, tech-spec, and README to be coherent, consistent, and faithful to the Pyve philosophy. 

**Phase P Plan Realignment:**

Using `refactor_plan` mode, review Phase P preamble and provide an analysis of how to realign Pyve docs to be consistent with the intended vision.
- [ ] Update `docs/specs/concept.md`
- [ ] Update `docs/specs/features.md`
- [ ] Update `docs/specs/tech-spec.md`

**Phase P Public Documentation:**

Using `refactor_document` mode and the refactored plan above, update the following documents:
- [ ] Update `README.md`
- [ ] Update `docs/site/index.html`
- [ ] Update `docs/site/` MkDocs files

**Subphase Planning:**

- [ ] Using `plan_phase` mode, review subphases P-2, P-3, etc. and add a description for each sufficient to be broken down into stories. 
- [ ] One by one, plan each subphase (P-2, P-3, etc.)

---

### Story P.?: `project-guide` status is split + v2-leftover — unify into one readout that names *how* it's present (local pip vs toolchain) + show its version (status & self provision) [Planned]

*(v2-wiring removal — same family as the config-source story above. project-guide stopped being a per-project Python dependency in v3, but a v2 status check survived.)*

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

### Story ?.?: CLI output still teaches deprecated `pyve testenv` spellings — sweep fresh user-facing suggestions to `pyve env` [Planned]

*(Field-discovered 2026-06-15, `learningfoundry` `pyve init` under v3.0.7. The code-side companion to the docs-only "Finish the v3 site — drop v2 spellings" story above: that one fixes prose in `usage.md`/`testing.md`; this one fixes the strings the binary actually prints.)*

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

**Out of scope.** The `pyve testenv` *alias itself* (keep until v4.0). The alias/grammar/completion tests that verify the alias still works ([test_testenv_grammar.bats](../../tests/unit/test_testenv_grammar.bats), [test_completion_bash.bats](../../tests/unit/test_completion_bash.bats), [test_testenv_install_name.bats](../../tests/unit/test_testenv_install_name.bats)) — they must keep using `pyve testenv` on purpose. The docs-site prose sweep (the sibling story above). Code *comments* that mention the alias (not user-facing).

**Tasks.**

- [ ] Reproduce (red): flip the next-steps test assertions to expect `pyve env install -r requirements-dev.txt` and to reject `pyve testenv` ([test_init_next_steps.bats](../../tests/unit/test_init_next_steps.bats), [test_init_next_steps.py](../../tests/integration/test_init_next_steps.py)); confirm they fail against current output.
- [ ] Sweep the six suggestion sites `testenv` → `env`: next-steps ([plugin.sh:2256](../../lib/plugins/python/plugin.sh#L2256) + the doc-comment at [:2227](../../lib/plugins/python/plugin.sh#L2227)), the three `pyve test` hints ([:4087](../../lib/plugins/python/plugin.sh#L4087)/[:4118](../../lib/plugins/python/plugin.sh#L4118)/[:4123](../../lib/plugins/python/plugin.sh#L4123)), the two prune usages ([env.sh:362](../../lib/commands/env.sh#L362)/[:1160](../../lib/commands/env.sh#L1160)).
- [ ] Update the two lazy-hint test assertions ([test_test_env_lazy_autoprovision.bats:102](../../tests/unit/test_test_env_lazy_autoprovision.bats#L102), [test_test_env_resolver.bats:147](../../tests/unit/test_test_env_resolver.bats#L147)) to `pyve env install …`; leave the alias/grammar/completion tests untouched.
- [ ] Re-grep `lib/` + `pyve.sh` for any user-facing `pyve testenv` suggestion missed; confirm only the alias-compat tests still reference the old form.
- [ ] Full suite; zero regressions.

**Version:** Phase P — patch-grade; the unshipped v3.0.7 (with P.a) is a natural home if it lands before release, else its own patch. Developer owns number/placement.

---

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

## Subphase P-2: Runnability probes and environment healing

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
- [ ] Full suite; zero regressions.

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

## Subphase P-3: Declarative env setup
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

### Story ?.?: `pyve.toml` is not yet the sole config source — `init` writes a backend-less manifest + the v2 `.pyve/config`; ~64 read-sites still read `.pyve/config` (v3.1.0 v2-wiring removal) [Planned]

*(The "N-10 read-compat sweep" that ~8 O-series stories deferred — N-10 became Phase O, so the v2-wiring removal lands here in Phase P / v3.1.0. This is the **write**-side prerequisite + the **read**-migration + the **stop**-writing, as one coherent change.)*

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

**Out of scope.** The runnability-probe / `pyve heal` pillars (separate Phase P stories). The `pyproject [tool.pyve.testenvs]` → `pyve.toml` lifecycle migration (O.k bundle). Changing the `purpose`/backend vocabularies.

**Tasks (refine at `plan_production_phase`).**

- [ ] Reproduce (red): `pyve init --backend micromamba` (fresh **and** pre-existing `pyve.toml`) → assert `pyve.toml [env.root].backend == "micromamba"` (empty today) and `pyve status` reports the backend (says "not configured" today).
- [ ] **Write:** make `init` persist the resolved backend (+ python / env_name) into `pyve.toml [env.root]`, fresh and existing; drop the backend-less hardcoded template.
- [ ] **Read:** migrate the ~64 `.pyve/config` read-sites (`read_config_value` / `config_file_exists` / `[[ -f ".pyve/config" ]]`) onto `manifest_load` + accessors; remove the read-compat synthesis.
- [ ] **`--force` must force on a v3 project:** route the reinit/destructive-rebuild gate off `config_file_exists` ([plugin.sh:1729](../../lib/plugins/python/plugin.sh#L1729)) onto manifest presence (`pyve.toml` / `manifest_load`), so `pyve init --force` purges + recreates the env on a `.pyve/config`-less project. Regression: a v3 project (valid `pyve.toml`, no `.pyve/config`) with an existing `.venv` → `pyve init --force` **recreates** the venv (assert rebuilt, not `already exists, skipping`); pair with an interpreter-drift fixture (venv built on a different python than the current pin) → `--force` yields a venv on the pinned interpreter.
- [ ] **Stop:** `init` no longer writes `.pyve/config`; remove the writers; confirm a `pyve.toml`-only project (no `.pyve/config`) is fully functional across `status` / `check` / `run` / `lock` / `env`.
- [ ] Tests: fresh + existing-manifest init both populate the manifest backend; every command reads the manifest; no command returns "not configured" on a configured project; a `.pyve/config`-less v3 project is green end-to-end.
- [ ] project-essentials: state that `init` writes the manifest backend and `.pyve/config` is gone; remove the read-compat entry and the `v3.0-only: remove in N-10` markers.

**Version:** Phase P / **v3.1.0** — the v2-wiring removal (former "N-10" sweep). Developer owns number/placement.

---

## Subphase P-4: Workflow improvements

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

## Future

---

## Subphase ?-?: Security & Bootstrap Hardening

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
