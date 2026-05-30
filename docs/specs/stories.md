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

## Phase M: Bugfixes, Minor Improvements, and Test Environment DX

Phase M serves two distinct roles.

**The junk drawer.** A rolling home for small, independently-discovered fixes and minor improvements that don't justify their own phase. Each ships its own patch or minor bump as it lands — M.a (v2.6.3), M.b (v2.6.4), M.c (v2.7.0), M.d (no bump, CI config), and M.e (v2.7.1) are the pattern. New junk-drawer stories continue to accrete here on demand; cadence stays **per-story**.

**The testenv-DX sub-section.** A planned, coherent initiative that generalizes pyve's one-main + one-testenv model into named, multi-backend, multi-manifest test environments. See [phase-m-testenv-dx-plan.md](phase-m-testenv-dx-plan.md) for the plan doc and [phase-m-pyve-named-testenvs.md](phase-m-pyve-named-testenvs.md) for the use-case brief. The bundle (M.f onwards) runs **unversioned** during work and ships as **one bundled release at v2.8.0** at the end.

The two cadences coexist inside Phase M. Story IDs are sequential in the order performed; testenv-DX stories are tagged `[Testenv-DX]` in their bodies for clarity.

### Story M.a: v2.6.3 — User-facing testing docs (close LLM testenv-on-micromamba gap) [Done]

**Bug.** An LLM agent working on a separate micromamba-backend project hit `pyve testenv init` failures and misdiagnosed the cause as a missing `.tool-versions` file. Root cause: `pyve testenv init` invokes `python -m venv` against whatever `python` is on PATH at that moment, and the LLM's Bash-tool subprocess didn't have the micromamba project env activated (direnv doesn't auto-load in subprocesses). `python` fell back to an asdf shim with no pin, surfacing as "No version is set for command python." The right fix is `pyve run pyve testenv init` (which activates the project env first), not `.tool-versions` — but that guidance existed only in the LLM-facing `pyve-essentials.md` template's general "use `pyve run` from Bash tools" rule. Nothing on the user-facing MkDocs site explained the two-environment model, the backend-specific testenv-Python inheritance, or the activation-context requirement.

**Why this is a documentation bug, not a code bug.** Pyve's behavior is contractually correct per `features.md` FR-11 and `tech-spec.md` lib/commands/testenv.sh. The gap is that user-facing documentation never explained how the testenv inherits its base Python from the active project env, why that matters per backend, and what to do when the project env isn't active at invocation time. The information lived in four fragments (README, usage.md, project-essentials.md template, code) and no single page composed them.

**Approach.** New `docs/site/testing.md` as the canonical user-facing concept + how-to page (inserted in MkDocs nav between Backends and CI/CD Integration). Cross-link from `backends.md`, `getting-started.md`, and `ci-cd.md`. Sweep stale legacy-form references in `README.md` and `usage.md` that survived the v2.3.0 (Story J.d) delegation removal. Add the missing LLM-internal rule to the `pyve-essentials.md` template so the rendered `project-essentials.md` carries explicit guidance going forward.

**Tasks**

- [x] Create [docs/site/testing.md](../site/testing.md) with eight sections: Overview, Two-environment model (with table), Backend deltas (Python-inheritance per backend + admonition on activation requirement), Testenv lifecycle (init / install / run / `pyve test` / purge), Editable installs (`pythonpath` vs testenv editable), `requirements-dev.txt` convention, Activation context (developer-direnv / developer-non-activated / LLM-agent), CI/CD patterns, Troubleshooting (3 FAQs including the exact symptom from this bug).
- [x] Add `- Testing: testing.md` to MkDocs `nav` in [mkdocs.yml](../../mkdocs.yml) between Backends and CI/CD Integration.
- [x] Cross-link [docs/site/backends.md](../site/backends.md): new "Testing on the venv Backend" subsection in the venv section, "Testing on the micromamba Backend" subsection in the micromamba section, "Testing" entry in Next Steps.
- [x] Cross-link [docs/site/getting-started.md](../site/getting-started.md): Testing entry in Next Steps.
- [x] Cross-link [docs/site/ci-cd.md](../site/ci-cd.md): Testing entry in Additional Resources.
- [x] [README.md](../../README.md) Testing section: replace stale `pyve testenv --init` / `pyve testenv --install -r requirements-dev.txt` (lines 357–358) with current subcommand forms; drop `(v1.5.2)` annotation from section header; add link to the new Testing guide.
- [x] [docs/site/usage.md](../site/usage.md): fix line 12 (v2.0 upgrade note still framing the v2.3.0-removed delegations as "delegate-with-warning through v2.x") and lines 572–574 (testenv subcommand block making the same stale claim with a phantom "removed in v3.0" timeline).
- [x] [docs/project-guide/templates/artifacts/pyve-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md): under Workflow rules, add explicit "LLM-internal testenv init must wrap with `pyve run`" bullet covering the exact failure mode and explaining why `.tool-versions` is not the fix on a micromamba backend.
- [x] Bump VERSION to 2.6.3 in [pyve.sh](../../pyve.sh).
- [x] Add v2.6.3 entry to [CHANGELOG.md](../../CHANGELOG.md) with Added (docs) and Fixed (docs) sections.

**Prevention scan (housekeeping)**

- [ ] Add a docs-lint that fails CI if user-facing docs (any of `docs/site/*.md` except `migration.md`, plus `README.md`) contain `pyve testenv --init|--install|--purge` or `pyve python-version <ver>` as a non-historical example. Migration.md keeps the legacy→new mapping by design and is the only file exempt.
- [ ] Sweep other user-facing surfaces for the same "delegate-with-warning through v2.x" framing pattern — anywhere else in usage.md or backends.md that still describes a v2.3.0-removed delegation as still working. The two spots fixed here were the only ones grep surfaced today, but a fresh pass with broader patterns ("delegation", "deprecated", "v3.0") would catch any I missed.
- [ ] Consider whether the rendered `docs/project-guide/go.md` should be refreshed in this PR via `project-guide update`, or whether the next routine refresh of the rendered file is sufficient. (Per the project-guide install-output rule, hand-editing go.md is forbidden; the template edit propagates on next sync.)

**Out of scope (flagged at design gate, kept out)**

- Rewriting the broader README "Testing" section structure — only the stale lines were fixed.
- Migrating other CI examples in `ci-cd.md` to the two-env pattern. Those examples represent a valid alternate pattern (pytest installed into the project env) and are linked bidirectionally with testing.md so users can choose.
- Future Story `?.?: Apply Phase L UX framing to non-scaffold commands` mentions `pyve testenv install` UX — orthogonal to this doc fix.

---

### Story M.b: v2.6.4 — project-guide completion block leaks asdf-shim stderr at shell init [Done]

**Bug.** Every interactive shell startup in a pyve project printed:

```
No version is set for command project-guide
Consider adding one of the following versions in your config file at <project>/.tool-versions
python 3.14.3
```

immediately before direnv loaded `.envrc`. project-guide itself worked fine once the env activated, so the error was cosmetic — but alarming, recurring at every shell start, and it meant tab-completion silently failed to wire.

**Root cause (backend-independent).** The shell-completion block that `pyve init --project-guide-completion` appends to `~/.zshrc` / `~/.bashrc` (written by `add_project_guide_completion` in [lib/utils.sh](../../lib/utils.sh)) was:

```bash
command -v project-guide >/dev/null 2>&1 && \
  eval "$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
```

This runs at shell startup, **before** direnv activates the project env, so `project-guide` resolves to the asdf shim (`~/.asdf/shims/project-guide`), not the env's binary. When the asdf-resolved Python has no project-guide installed, the shim errors to stderr (exit 126). The `command -v` guard does **not** catch this — the shim *file* exists, so the guard passes — and the eval's command substitution let the shim's stderr leak. Confirmed on two repos: a micromamba project (no `.tool-versions` → no Python set at all) and the pyve venv repo itself (`.tool-versions` pins `python 3.12.13`, but project-guide is installed only in asdf `python 3.14.3` → the shim resolves to 3.12.13 which lacks it). The venv-vs-micromamba backend was a red herring; the trigger is purely "asdf-resolved Python at shell-init lacks project-guide." Repos that don't show it have their asdf-resolved Python = the version that has project-guide.

**Why tests didn't catch it.** The existing G.c/G.e completion tests assert the block's *structure* (sentinel presence, `command -v` guard, line-continuation, SDKMan ordering, syntactic validity) but never *executed* the block against a project-guide that errors. The failure only manifests at runtime when the resolved command writes to stderr.

**Fix.** Add `2>/dev/null` to the eval's command substitution so the block degrades silently when the shim errors (completion is best-effort per FR-16). Minimal one-token change; preserves the `command -v` guard and the `&& \` line-continuation that the G.e regression tests assert.

```bash
command -v project-guide >/dev/null 2>&1 && \
  eval "$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide 2>/dev/null)"
```

**Tasks**

- [x] Regression test in [tests/unit/test_project_guide.bats](../../tests/unit/test_project_guide.bats) — generate the block, source it under a PATH where `project-guide` is a fake asdf shim (noisy stderr, empty stdout, exit 126), assert the asdf error does not leak. Confirmed RED against the pre-fix block, GREEN after.
- [x] Add `2>/dev/null` to the command substitution in `add_project_guide_completion` ([lib/utils.sh](../../lib/utils.sh)); document why the suppression is load-bearing in the heredoc comment.
- [x] Verify full `test_project_guide.bats` suite (74 tests) passes — including the G.e structural tests and the integration test's `command -v project-guide` / `_PROJECT_GUIDE_COMPLETE` assertions, which my change leaves intact.
- [x] Prevention scan: grep `lib/` + `pyve.sh` for other shell-init `eval "$(...)"` invocations lacking stderr suppression — none found; the prompt-hook block in `lib/commands/self.sh` sources a pyve-owned file, not a shimmed command, so it's unaffected.
- [x] Bump VERSION to 2.6.4 in [pyve.sh](../../pyve.sh); add v2.6.4 CHANGELOG entry.

**Prevention scan / housekeeping (follow-up)**

- [ ] Existing installs are not retroactively fixed by the source change — any `~/.zshrc` / `~/.bashrc` already carrying the old block keeps leaking until the block is re-written. Options to surface to users: (a) re-run completion wiring once shipped, or (b) a one-shot `pyve self repair-completion` that rewrites the sentinel block in place. Decide whether to add (b) or document (a) in the v2.6.4 release notes / Testing guide.
- [ ] Consider whether `pyve check` should warn on the Project-Python (`.tool-versions`) vs Environment-Python (`.venv`) mismatch surfaced during this investigation — it's the deferred "strict version-match gate" from features.md FR-5, and it's the upstream reason this repo's asdf shim resolved to a project-guide-less Python. Distinct concern; own story.

**Out of scope (flagged, kept out)**

- Changing *which* project-guide the completion wires from (asdf shim vs env binary). Completion is shell-global and best-effort; silent degradation is the correct behavior, not re-architecting the resolution source.
- The Project/Environment Python mismatch itself — benign for running code (the venv wins on PATH when active); captured as a follow-up `pyve check` candidate above.

---

### Story M.c: v2.7.0 — `pyve test --env main` + silent-skip advisory (micromamba-testenv trap) [Done]

**Bug.** `pyve test` always routes pytest to the dedicated testenv (`.pyve/testenv/venv`, a plain venv), which is correct for a repo checkout but silently **wrong** for an environment built from a bundled `environment.yml` that puts **both** `pytest` **and** the stack-under-test (`tensorflow`, `torch`, …) in the **main** env. In that case `pyve test` runs in the stack-less testenv, every `pytest.importorskip("…")` **skips**, and the run looks green — a silent false pass. The failure is a SKIP, not an error, so it blends in with normal hardware-gated skips. Full analysis: [docs/specs/pyve-micromamba-testenv-trap.md](pyve-micromamba-testenv-trap.md) (drafted from an nbfoundry debugging session, 2026-05-29).

**Why this is a pyve bug, not just nbfoundry's.** pyve owns two sharp edges: (1) `pyve test` routes to the testenv unconditionally even when the main env has both pytest and the needed deps; (2) the resulting mass-skip is given no signal. The bundling choice (pytest + stack in one `environment.yml`) is nbfoundry's and stays nbfoundry's; pyve's responsibility is the unconditional routing + the silent masking.

**Scope (agreed with developer).** Ship the cheap, test-first pair from the report's options and defer the rest:

- **Option 2 — `pyve test --env main|testenv`** (the escape hatch). `--env main` delegates to `run_command python -m pytest <args>`, reusing run_command's backend detection + asdf reshim guard + exec. First-class form of the documented `pyve run python -m pytest` workaround.
- **Option 1 (proxy variant) — pre-run advisory.** When routing to the testenv (default) and the main env has pytest importable, print a one-line advisory pointing at `--env main` before exec. Chosen over the report's output-parsing variant (which would force `pyve test` from `exec` to a captured subprocess — a behavior change to the exec contract) because the proxy is cheaper, needs no exec change, is trivially test-first, and is well-targeted (never fires for a repo checkout, whose main env has no pytest).

**Tasks**

- [x] Failing test first: [tests/unit/test_test_command.bats](../../tests/unit/test_test_command.bats) — `--env main` delegates to `run_command python -m pytest <args>` (incl. `--env=` form and no-extra-args), invalid `--env` errors, advisory fires iff main env has pytest, no advisory under `--env main`. Confirmed RED (6/7) against pre-fix `test_tests`, GREEN (7/7) after.
- [x] `test_tests` ([lib/commands/test.sh](../../lib/commands/test.sh)): parse `--env main|testenv` (and `--env=…`) out of the arg list into a bash-3.2-safe `args[]` (`"${args[@]+"${args[@]}"}"`); `--env main` → `run_command python -m pytest`; invalid value → hard error.
- [x] New helper `_test_main_env_has_pytest` ([lib/commands/test.sh](../../lib/commands/test.sh)): resolve main env python (`.pyve/envs/*/bin/python` else `$DEFAULT_VENV_DIR/bin/python`) and probe `import pytest`; drives the advisory.
- [x] Pre-exec advisory in the testenv branch, non-fatal, one line + the `--env main` hint.
- [x] **Advisory opt-out** (folded in from the follow-up, since v2.7.0 was still uncommitted): `PYVE_NO_TESTENV_ADVISORY=1` suppresses the advisory for users who keep pytest in the main env deliberately. Test-first (RED→GREEN) in [test_test_command.bats](../../tests/unit/test_test_command.bats); gate is `[[ "${PYVE_NO_TESTENV_ADVISORY:-0}" != "1" ]] && _test_main_env_has_pytest`. Documented in `features.md` env-var table + FR-11, `docs/site/testing.md`, CHANGELOG.
- [x] Verified bash-3.2 empty-array safety under `set -euo pipefail` (`--env main`, no extra args). Full unit suite: 880+ ok, 0 not ok.
- [x] Docs (ride-along): `features.md` FR-11, `tech-spec.md` test.sh table + reuse note, `docs/site/usage.md` `pyve test` reference + trap admonition, `docs/site/testing.md` new "Choosing which environment runs your tests" section (the anchor usage.md links to).
- [x] Bump VERSION to 2.7.0 ([pyve.sh](../../pyve.sh)) — **minor**, new user-facing flag; add v2.7.0 CHANGELOG entry.

**Out of scope (flagged at design gate, kept out)**

- **Option 1b (accurate skip-detection)** — parsing pytest output for `ModuleNotFoundError` / failed `importorskip` to count import-skips. Requires changing `pyve test` from `exec` to a captured/teed subprocess (exec-contract change: TTY, color, signals). Deferred; the proxy advisory covers the trap at lower risk. Revisit only if the proxy proves too blunt.
- **Option 3 (change the default to auto-detect main-env pytest)** — changes long-standing default routing; needs its own opt-in design.
- **Option 4 (testenv dependency seeding / inherit from main env)** — risks duplicating multi-GB native packages (torch/TF) and re-creating the cross-framework co-residence SIGBUS (nbfoundry story F.f.1). Heaviest option; not pursued.
- **nbfoundry's bundled `environment.yml`** — nbfoundry's call; its main-env-runner workaround is already in effect.

**Follow-up (housekeeping)**

- [x] ~~If the proxy advisory generates false-positive noise…consider a `PYVE_NO_TESTENV_ADVISORY=1` opt-out.~~ Done in this story (folded into v2.7.0 while uncommitted). The micromamba-only-gating alternative was *not* taken — a venv project that installs pytest into `.venv` can hit the same trap, so the advisory stays backend-agnostic with the env-var as the universal escape hatch.

---

### Story M.d: Add `.github/dependabot.yml` [Done]

**Why.** Production-readiness checklist gap surfaced during `plan_production_phase` Step 2 walk: `.github/dependabot.yml` was missing. Adding it closes the "automated dependency updates" item before the testenv-DX bundle begins.

**Approach.** Standard Dependabot configuration covering the ecosystems pyve consumes:

- `pip` — for `requirements-dev.txt` (and future runtime requirements added by the testenv-DX bundle).
- `github-actions` — for `.github/workflows/*.yml` ([test.yml](../../.github/workflows/test.yml), [deploy-docs.yml](../../.github/workflows/deploy-docs.yml), [update-homebrew.yml](../../.github/workflows/update-homebrew.yml)).
- Weekly schedule, grouped minor/patch updates per ecosystem to reduce PR noise.

**Tasks**

- [x] Create `.github/dependabot.yml` with the two ecosystems above, weekly schedule, grouped minor/patch updates.
- [ ] Verify the file passes GitHub's Dependabot config validation (no scheduler error reported on the repo's Insights tab within 24h of merge). *(Deferred: only checkable post-merge on GitHub.)*

**Out of scope**

- Renovate as an alternative. Dependabot is sufficient.
- Auto-merging Dependabot PRs. Review workflow is a separate concern.

**Version impact.** No bump. Pure CI config; no pyve runtime change.

---

### Story M.e: v2.7.1 — `pyve test --env main` → `--env root` rename (Category-B catch) [Done]

**Why.** M.c v2.7.0 shipped `pyve test --env main` weeks ago. The name `main` overloads the git-branch term and is conceptually fuzzy for "the root project environment, not a sub-environment." The canonical name is **`root`** — the root of the project folder, the development surface. Renaming now (while the M.c form is barely in the field) avoids permanent overload and aligns with the testenv-DX bundle's design, which treats `root` and `testenv` as the two permanently-reserved env names.

**Approach.** Category-B hard-error catch per [project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md) *Deprecation removal policy*: match `--env main`, print the precise replacement, exit non-zero. No Category-A silent delegation.

**Correction (during M.e execution).** The plan body originally said "Three lines in the `pyve.sh` dispatcher arm," modeled on the canonical `legacy_flag_error()` catches for top-level flags like `--init` / `--purge`. That's the wrong locus for `--env main`: `--env` is a *value* parsed inside `_test_parse_args` in [lib/commands/test.sh](../../lib/commands/test.sh), not a top-level flag dispatched by `pyve.sh`. The catch belongs alongside the existing "invalid `--env` value" error in `_test_parse_args` — same Category-B semantics, correct file. The dispatcher arm in `pyve.sh` never sees the `--env` value.

**Tasks**

- [x] Failing test first: extend [tests/unit/test_test_command.bats](../../tests/unit/test_test_command.bats) with a `--env main` Category-B test asserting the hard-error message + non-zero exit code. Confirm RED. *(Done: also renamed the existing `--env main` happy-path tests to `--env root`. RED = 6/10 fail; GREEN = 10/10. Full unit suite 883/883.)*
- [x] Rename `--env main` → `--env root` in [lib/commands/test.sh](../../lib/commands/test.sh) (`_test_parse_args` value handling; the `root` value targets `.venv/` — current `main` behavior).
- [x] Add `legacy_flag_error()`-style catch for `--env main` printing: `pyve test --env main: renamed to --env root. Run 'pyve test --env root' instead.` *(Implemented inline in `test_tests`'s arg-validation section, not via `legacy_flag_error()` in `pyve.sh` — see the **Correction** note in the Approach section above.)*
- [x] Update `features.md` FR-11 (rename `main` → `root` in the documented value list).
- [x] Update `tech-spec.md` test.sh table.
- [x] Update `docs/site/usage.md` and `docs/site/testing.md` to use `--env root`; add a one-line note that `--env main` was renamed in v2.7.1.
- [x] Bump VERSION to 2.7.1 in [pyve.sh](../../pyve.sh).
- [x] Add v2.7.1 CHANGELOG entry under **Changed** (rename) and **Removed** (`--env main` value).

**Out of scope**

- Category-A delegation. Per project-essentials, the precise error message *is* the migration window.
- Renaming private helper `_test_main_env_has_pytest`. Rename folds into M.n when the helper is generalized.

**Version impact.** Patch (v2.7.1). Junk-drawer cadence. Pre-bundle.

---

### Story M.f: [Testenv-DX] Architectural spike — `[tool.pyve.testenvs]` config schema & reader pattern [Done]

**Goal.** Lock in the TOML-config integration design before the bundle's foundation stories (M.g+) begin. This is the first time pyve reads TOML; the choice of approach affects every downstream story.

**Questions to answer.**

1. **Schema shape.** Confirm `[tool.pyve.testenvs]` (top-level: `default`) + `[tool.pyve.testenvs.<name>]` (per-env: `backend`, `requirements`, `extra`, `manifest`, `lazy`). Validate against the use cases in [phase-m-testenv-dx-plan.md](phase-m-testenv-dx-plan.md).
2. **TOML reader.** Python helper via `python -c "import tomllib; ..."` (Python 3.11+). One-shot subprocess per `pyve` invocation, or cached output in `.pyve/.testenvs-cache`?
3. **Output format from helper.** JSON to stdout (parsed in bash via `jq`)? Shell `key=value` lines (sourced)? Bash-array-literal output? Decide a Bash-3.2-safe pattern.
4. **Validation & error UX.** What does pyve print for invalid `backend`, missing-file `requirements`, conflicting `manifest` + `requirements`? Pinned-message contract or free-form? Validation in Python helper or in bash post-parse?
5. **Missing-config behavior.** When `pyproject.toml` exists but has no `[tool.pyve.testenvs]` block (or `pyproject.toml` is absent), the resolver returns the implicit default: `testenv` = venv at `.pyve/testenvs/testenv/venv/`. Confirm.

**Time-box.** ~1 working session. Throwaway code in `tmp/spike-testenvs/`. Deliverable is decisions documented in **`docs/specs/spike-m-f-testenvs-config.md`**.

**Tasks**

- [x] Sketch helper in throwaway form; try JSON-to-bash, shell-`key=value`, and bash-array-literal output; pick one with a one-paragraph rationale. *(Picked V3 bash-array-literal — see Decision 3 in the spike doc.)*
- [x] Sketch validation: invalid `backend`, missing-file `requirements`, `manifest`+`requirements` conflict. Decide error-message shape. *(Schema validation in Python helper; filesystem checks deferred to consumers. Prefix `error: pyve.testenvs.<env>[.<key>]: <message>`. Exit 2. Batched.)*
- [x] Sketch caching: measure cold-start cost of Python helper per `pyve` invocation; if < ~30ms, skip caching. *(Measured ~60 ms — above the threshold, but Python's startup floor alone is ~44 ms, so the threshold was below pyve's existing baseline. **Skipping caching anyway** — the marginal ~16 ms is invisible against ambient command cost, and caching brings real invalidation/concurrency complexity. See Decision 2.)*
- [x] Write `docs/specs/spike-m-f-testenvs-config.md`: decided schema, helper invocation, output format, validation pattern, caching policy, rationale.
- [x] **No production code** in this story.

**Out of scope.** Implementing `lib/testenvs.sh` — that's M.g, informed by this spike.

**Version impact.** None (no shipped change; bundle-unversioned).

---

### Story M.g: [Testenv-DX] `lib/testenvs.sh` foundation [Done]

**Why.** All testenv-DX stories beyond this point need a shared config reader, env-name resolver, and backend/manifest validator. Per [`lib/commands/<name>.sh` is for command implementations only](../project-guide/templates/artifacts/pyve-essentials.md), shared helpers live in `lib/<topic>.sh`, not in a command file.

**Approach.** New [lib/testenvs.sh](../../lib/testenvs.sh) implementing the M.f spike's decisions:

- `read_testenv_config` — invoke Python TOML helper, populate state.
- `resolve_testenv_path <name>` — on-disk env path for a given name.
- `validate_testenv_decl <name>` — sanity-check a declaration.
- `is_testenv_declared <name>`, `is_testenv_reserved <name>`, `is_testenv_lazy <name>` — predicates.
- `list_testenv_names` — all declared names + reserved (`testenv`, `root`).

**Tasks**

- [x] Failing tests first: [tests/unit/test_testenvs.bats](../../tests/unit/test_testenvs.bats) covering valid config, missing config (implicit default), invalid backend, conflicting `requirements` + `manifest`, reserved-name violation in user config, `lazy = true` propagation, empty-array safety per [Bash 3.2 empty-array reads](../project-guide/templates/artifacts/pyve-essentials.md). *(14 tests; RED → GREEN 14/14; full unit suite 897/897.)*
- [x] Implement `lib/testenvs.sh` per M.f decisions. *(Python helper at `lib/pyve_testenvs_helper.py` emits plain bash-assignment syntax — not `declare` — so `eval` inside a function lands in global scope under bash 3.2's missing-`declare -g` constraint. Honors `${PYVE_PYTHON:-python}` for interpreter override.)*
- [x] Add explicit `source lib/testenvs.sh` in [pyve.sh](../../pyve.sh) sourcing block (after `lib/utils.sh`, before `lib/commands/*.sh`).
- [x] Update [docs/specs/tech-spec.md](tech-spec.md) with the `lib/testenvs.sh` design: TOML reader pattern (Python helper invocation form), output-format contract, validation policy, caching policy — all per the M.f spike's decisions. *(New §`lib/testenvs.sh` between `version.sh` and `ui/core.sh`; Package Structure tree updated; tests inventory updated.)*

**Out of scope.** Consumers (`testenv` namespace, `pyve test`, `pyve lock`) pull from `lib/testenvs.sh` in later stories.

---

### Story M.h: [Testenv-DX] Per-env directory layout + migration hook [Planned]

**Why.** Today's single testenv lives at `.pyve/testenvs/venv/` (hard-coded). Named envs need `.pyve/testenvs/<name>/{venv,conda}/`. Existing projects must transparently migrate.

**Approach.** New per-env layout: `<name>/venv/` or `<name>/conda/`, plus `<name>/.lock` and `<name>/.state`. Reserved `testenv` resolves to `.pyve/testenvs/testenv/venv/`. A `pyve update` hook detects the legacy layout and moves it.

**Tasks**

- [ ] Failing tests first: bats covering migration on `pyve update` (legacy → new), idempotency, new-project layout (no migration triggered).
- [ ] Migration helper in [lib/commands/update.sh](../../lib/commands/update.sh): detect legacy, `mv` to new path, write initial `.state`.
- [ ] `.state` format: backend, manifest path + hash, provisioned timestamp, last-used timestamp. Plain `key=value` (sourceable).
- [ ] Update `tech-spec.md` testenv-layout section.

**Out of scope.** Namespace command expansion (M.i); `.state` consumption (folds into stories that produce/consume those signals).

---

### Story M.i: [Testenv-DX] `testenv` namespace expansion — name-aware ops [Planned]

**Why.** With named envs declared (M.g) and the layout in place (M.h), the `testenv` namespace commands need an optional `<name>` argument. The reserved `testenv` name keeps existing workflows working.

**Approach.** Extend leaves in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) per TC-M.6 in the plan doc:

| CLI | No-arg behavior | With-arg behavior |
|---|---|---|
| `pyve testenv init [<name>]` | Default `testenv` | Named env |
| `pyve testenv install [<name>] [-r …]` | All non-lazy envs | Named env only |
| `pyve testenv purge [<name>]` | All envs (confirm) | Named env only |
| `pyve testenv run [<name>] -- <cmd>` | Default `testenv` | Named env |

**Tasks**

- [ ] Failing tests first: bats covering each leaf's no-arg and with-arg branches, reserved-name behavior, undeclared-name error.
- [ ] Extend `testenv_init`, `testenv_install`, `testenv_purge`, `testenv_run`.
- [ ] Update per-leaf help blocks (`show_testenv_<sub>_help`) per [Per-command help blocks live with their commands](../project-guide/templates/artifacts/pyve-essentials.md).

**Out of scope.** `pyve testenv list` / `pyve testenv prune` (M.p — new leaves); lock machinery in `install` (M.j).

---

### Story M.j: [Testenv-DX] Per-env install lock (`.pyve/testenvs/<name>/.lock`) [Planned]

**Why.** Pyve owns the testenv lifecycle. Concurrent `pyve testenv install <same-env>` from two shells must serialize on the env, not collide on the package cache.

**Approach.** `flock`-based lock at `.pyve/testenvs/<name>/.lock`. Acquired around `pyve testenv install <name>` and any auto-provision path (M.m). Second invocation waits by default; `--no-wait` exits with a clear "another pyve process is installing `<name>` (pid N)" message.

**Tasks**

- [ ] Failing tests first: bats covering serial install (no collision), `--no-wait` exit message + non-zero code, lock cleanup on success and failure.
- [ ] `_testenv_acquire_install_lock` / `_testenv_release_install_lock` helpers in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) (command-private, per the `_<command>_` prefix).
- [ ] Wire into `testenv_install`.
- [ ] Document `--no-wait` in `show_testenv_install_help`.

**Out of scope.** Read-only execution locking (`pyve test --env <name>` fast path is lock-free); cross-host locks (local file lock only; document the limit).

---

### Story M.k: [Testenv-DX] Conda-backed testenv plumbing (`backend = "micromamba"`) [Planned]

**Why.** UC2 (test/runtime parity for conda mains) and UC3 (conda-only native deps — GDAL, CUDA, HDF5) both reduce to "per-env conda backend." The main-env micromamba paths exist; testenvs need the same plumbing minus the `.envrc`.

**Approach.** Reuse [lib/backend_detect.sh](../../lib/backend_detect.sh) and main-env micromamba init logic. Add `_testenv_init_conda` and `_testenv_install_conda` to [lib/commands/testenv.sh](../../lib/commands/testenv.sh). Conda-backed envs accept `manifest = "<environment.yml>"` (FR-M.3); mutually exclusive with `requirements`/`extra` (validation in M.g).

**Tasks**

- [ ] Failing tests first: bats covering `pyve testenv init <name>` for a conda-backed declared env, `pyve testenv install <name>` from a `manifest = "…"` source, validation error on `manifest` + `requirements` collision.
- [ ] `_testenv_init_conda` + `_testenv_install_conda` helpers.
- [ ] `backend = "inherit"` resolution via [lib/env_detect.sh](../../lib/env_detect.sh) (main env backend).
- [ ] No `.envrc` emission for testenvs.
- [ ] Update `tech-spec.md` testenv backend section.

**Out of scope.** `pyve lock --env <name>` (M.q); pip-installed-into-conda mixed mode.

---

### Story M.l: [Testenv-DX] venv manifest sources — `requirements` and `extra` [Planned]

**Why.** Venv-backed testenvs need both `requirements = ["…"]` (one or more pip manifests) and `extra = "<name>"` (named optional-dependency extra from `pyproject.toml`).

**Approach.** Extend `_testenv_install_venv` in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) to dispatch on the declared source:

- `requirements = ["a.txt", "b.txt"]` → `pip install -r a.txt -r b.txt`.
- `extra = "dev"` → resolve via Python helper (extract `[project.optional-dependencies].dev`, install).
- Neither declared → fallback to legacy `-r requirements-dev.txt` (preserves FR-M.4 light default).

**Tasks**

- [ ] Failing tests first: bats covering `requirements` list (multi-file), `extra` extraction from a `pyproject.toml`, fallback when neither declared, validation error when both declared.
- [ ] `_testenv_install_venv` extension.
- [ ] Python helper extension (from M.g `lib/testenvs.sh`) to extract `[project.optional-dependencies].<name>`.
- [ ] Update `docs/site/testing.md` with the three source patterns (folds into M.s sweep).

**Out of scope.** Editable installs (`pip install -e .`) — existing [Editable install and testenv dependency management](../project-guide/templates/artifacts/pyve-essentials.md) policy covers this; no change.

---

### Story M.m: [Testenv-DX] Lazy provisioning (`lazy = true`) [Planned]

**Why.** UC1's heavy hardware-smoke env (multi-GB ML stack) should not materialize on every CI run. `lazy = true` opts the env out of bulk install and provisions on first targeted use.

**Approach.** Three behavior changes:

1. `pyve testenv install` (no name) skips lazy envs.
2. `pyve testenv install <lazy-env>` installs normally.
3. `pyve test --env <lazy-env>` auto-provisions if missing (acquiring the lock per M.j), then runs.

**Tasks**

- [ ] Failing tests first: bats covering lazy env skipped by bulk install, lazy env explicitly installed by name, auto-provision on first `pyve test --env <lazy-env>` use.
- [ ] `is_testenv_lazy` predicate (from M.g) wired into `testenv_install` and `test_tests`.
- [ ] Auto-provision gated by `PYVE_NO_AUTO_PROVISION=1` opt-out (for CI that wants strict "is-this-env-already-built?" semantics).
- [ ] Document in `docs/site/testing.md` (folds into M.s sweep).

**Out of scope.** Pre-flight bandwidth/disk-space check; provision-time error reporting uses the underlying package manager's messages.

---

### Story M.n: [Testenv-DX] Silent-skip advisory generalization (all named envs) [Planned]

**Why.** M.c's advisory fires only when routing to the default `testenv` and detecting pytest in the main env. With many named envs, the trap surface multiplies: select any named env that lacks deps the tests import, and the run looks green via silent skips. The advisory must hold for **every** env.

**Approach.** Generalize `_test_main_env_has_pytest` → `_test_env_has_pytest <name>` (parameterized over env name). Advisory message names the offending env explicitly. `PYVE_NO_TESTENV_ADVISORY=1` opt-out continues to apply to all envs.

**Tasks**

- [ ] Failing tests first: bats covering advisory firing for each backend/env combination — venv testenv, conda testenv, named venv, named conda; opt-out gates the advisory off in all cases.
- [ ] `_test_env_has_pytest <name>` helper replaces `_test_main_env_has_pytest`.
- [ ] Advisory message: `pytest not found in env '<name>' — run 'pyve testenv install <name>' or select a different env with --env <other>`.
- [ ] Update `features.md` FR-11 with the generalized advisory shape.

**Out of scope.** Strict mode (`strict = true` → missing-dep skip = test failure). Plan doc OS-7; deferred.

---

### Story M.o: [Testenv-DX] `pyve test --env <name>` resolver extension [Planned]

**Why.** M.e's parser accepts only `--env {testenv, root}`. With named envs declared (M.g), the resolver needs to accept any declared name.

**Approach.** Extend `_test_parse_args` in [lib/commands/test.sh](../../lib/commands/test.sh):

1. Accept `--env <name>` (and `--env=<name>`).
2. Look up via `is_testenv_declared` / `is_testenv_reserved`.
3. Resolve to on-disk path via `resolve_testenv_path`.
4. Undeclared and not reserved → hard error listing valid choices.
5. No `--env` → read `[tool.pyve.testenvs] default`, fall back to `testenv`.

Also: touch `.state`'s `last-used` on successful run (consumed by `pyve testenv list` in M.p).

**Tasks**

- [ ] Failing tests first: bats covering `--env <declared-name>`, `--env <reserved>`, `--env <undeclared>` error, no-`--env` default lookup, no-config implicit `testenv` fallback, `last-used` touch.
- [ ] `_test_parse_args` extension.
- [ ] Hard-error message lists all declared + reserved names.
- [ ] `last-used` touch in success path.
- [ ] Update `features.md` FR-11.

**Out of scope.** Matrix (comma-separated) handling — M.r.

---

### Story M.p: [Testenv-DX] `pyve testenv list` / `pyve testenv prune` [Planned]

**Why.** Disk discoverability (FR-M.12). Many envs balloon disk; surfacing per-env size + last-used + provisioning state without `du -sh` matches the "feels integral" criterion.

**Approach.** Two new leaves in [lib/commands/testenv.sh](../../lib/commands/testenv.sh):

- `testenv_list` — read `.state` files, compute `du -sh` per env, print a table (name, backend, size, last-used, state).
- `testenv_prune` — three modes: no args (remove envs not declared in config, with confirmation), `--unused-since <date>` (remove envs whose `last-used` is older), `--all` (purge every env, with confirmation).

**Tasks**

- [ ] Failing tests first: bats covering `list` output shape, `prune` modes, confirmation prompt mocking.
- [ ] `testenv_list` + `testenv_prune` leaves.
- [ ] Per-leaf help blocks.
- [ ] Update `tech-spec.md` testenv namespace table.

**Out of scope.** Real-time `last-used` tracking — folds into M.o.

---

### Story M.q: [Testenv-DX] `pyve lock --env <name>` / `--all` extension [Planned]

**Why.** Production concern PC-2: conda-backed testenvs need deterministic resolution (no conda-forge drift across time). `pyve lock` already handles the main env; extend to per-env locking for conda-backed testenvs.

**Approach.** Extend `lock_environment` in [lib/commands/lock.sh](../../lib/commands/lock.sh):

- `pyve lock` (no args) → main env (existing behavior preserved).
- `pyve lock --env <name>` → lock the named conda-backed testenv. Hard error for venv-backed envs.
- `pyve lock --all` → main env + every conda-backed testenv.

Lock files: `<manifest-basename>-lock.yml` sibling to the manifest.

**Tasks**

- [ ] Failing tests first: bats covering `--env <conda-name>` produces a lock file, `--env <venv-name>` errors with a precise message, `--all` iterates correctly.
- [ ] `lock_environment` extension.
- [ ] Update `tech-spec.md` lock command section.

**Out of scope.** Lock-file format change (continue `conda-lock` default); locking pip-installed-into-conda mixed envs.

---

### Story M.r: [Testenv-DX] Matrix execution — `pyve test --env a,b,c` (serial) [Planned]

**Why.** UC6 (matrix testing). The same suite against multiple envs, selectable individually or as a set.

**Approach.** Comma-separated `--env` value parsed into a list; each env resolved via M.o; runs sequentially; exit code aggregates as worst-case (any failure → non-zero).

**Tasks**

- [ ] Failing tests first: bats covering single-env (existing behavior preserved), `a,b` two-env sequential run, exit-code aggregation, output delineation per env.
- [ ] `_test_parse_args` extension for comma-separated value.
- [ ] Per-env section header in output (`=== Env: <name> ===`) for human readability.
- [ ] Document in `docs/site/testing.md` (folds into M.s sweep).

**Out of scope.** `--parallel` execution. Plan doc OS-4; deferred.

---

### Story M.s: [Testenv-DX] Docs sweep — named testenvs across user-facing docs [Planned]

**Why.** The bundle introduces a substantial new surface (config schema, named envs, multi-backend, lazy provisioning, matrix). User-facing docs need a coherent story before release; piecemeal ride-along docs would fragment.

**Approach.** Single consolidated docs pass:

- [docs/specs/features.md](features.md) — new **FR-11a (or successor number): Named test environments** documenting the `[tool.pyve.testenvs]` DX contract as a first-class feature requirement. Schema (default + per-env `backend` / `requirements` / `extra` / `manifest` / `lazy`); reserved names (`root`, `testenv`); precedence; what happens with no config block. This is the source of truth for the DX surface; user-facing docs link here for canonical detail.
- `docs/site/testing.md` — new "Named test environments" section with the full config schema; updated "Choosing which environment runs your tests"; same-file manifest pattern (UC4); lazy provisioning; matrix.
- `docs/site/usage.md` — `pyve testenv {init,install,purge,run,list,prune}` reference updated with name argument; `pyve test --env <name>` reference; `pyve lock --env`/`--all` reference.
- `docs/site/backends.md` — note that named testenvs can use conda backend independent of main env.
- `README.md` — Testing section: mention that `[tool.pyve.testenvs]` in `pyproject.toml` is the canonical declarative config for named test environments (state lives in `.pyve/testenvs/<name>/`); link to the named-testenvs material in testing.md for detail; no full duplication.
- `docs/project-guide/templates/artifacts/pyve-essentials.md` — Pyve Essentials section: acknowledge "two envs" is now the *minimum*; named envs are an opt-in extension; LLM workflow rules updated for `pyve test --env <name>` and `pyve testenv install <name>`.

**Tasks**

- [ ] Audit and update the six files above.
- [ ] Verify all internal links resolve (`mkdocs build --strict`).
- [ ] No code changes in this story.

**Out of scope.** `migration.md` — bundle is purely additive (rename pre-shipped in M.e); no new migration entries needed.

---

### Story M.t: v2.8.0 — Testenv-DX bundle release [Planned]

**Why.** Per the Version Cadence rule, the phase's last bundle story owns the bump. M.f through M.s ran unversioned; this story ships the bundle as **v2.8.0**.

**Approach.** VERSION bump + CHANGELOG entry + final smoke pass.

**Tasks**

- [ ] Bump VERSION to 2.8.0 in [pyve.sh](../../pyve.sh).
- [ ] Add v2.8.0 CHANGELOG entry. **Added**: named testenvs, per-env backend (incl. `inherit`), per-env manifest sources (`requirements`/`extra`/`manifest`), lazy provisioning, install lock, `pyve testenv list`, `pyve testenv prune`, `pyve lock --env`/`--all`, matrix execution, generalized silent-skip advisory. **Changed**: `testenv` namespace commands now accept optional `<name>`. **Internal**: `lib/testenvs.sh` foundation, per-env layout migration.
- [ ] Final smoke: full test suite green; `pyve init` end-to-end on venv and micromamba backends; end-to-end on a project with `[tool.pyve.testenvs]` declaring two named envs (one lazy).
- [ ] Tag and release.

**Out of scope.** Anything not already done in M.f–M.s. Newly-discovered scope at this stage means the bundle is incomplete — return to the appropriate story.

---

## Future

### Story ?.?: Apply Phase L UX framing to non-scaffold commands [Planned]

**Motivation**: Phase L scoped the `sv create`-grade rollout (step counters, quiet-replay, spinners) to `pyve init` and `pyve update` — the scaffold-shaped commands. The same treatment plausibly improves `pyve lock` (long conda solves), `pyve testenv install` (pip output), and `pyve purge --force` (multi-step confirmation + delete). The `lib/ui/` toolkit shipped in Phase L (`run.sh`, `progress.sh`) is generic enough to apply directly.

**Why deferred**: Phase L was already large after the option-1 expansion; rolling out to four more commands would have stretched it further. The scaffold commands are the canonical "first impression" surface so they were prioritized.

**Tasks** (sketched; refine when picked up):

- [ ] Walk each command, identify macro-steps, wrap with `step_begin`/`step_end_ok` + `run_quiet`.
- [ ] Decide whether `purge --force` warrants step framing or if the existing confirm flow is sufficient.
- [ ] Update `features.md` for any output-contract changes.
- [ ] Tests per the L.j pattern.

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
