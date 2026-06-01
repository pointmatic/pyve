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
- Renaming private helper `_test_main_env_has_pytest`. Rename folds into M.o when the helper is generalized.

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

### Story M.h: [Testenv-DX] Layout migration to `testenvs/` — clear v2.7/v2.8 boundary [Bundle, Done]

**Why.** Today's single testenv lives at **`.pyve/testenv/venv/`** (singular `testenv`), driven by the global `TESTENV_DIR_NAME="testenv"` in [pyve.sh:36](../../pyve.sh#L36) and read by `lib/utils.sh`, `lib/commands/{test,testenv,check,status,purge}.sh`. The testenv-DX bundle's named-env layout is **`.pyve/testenvs/<name>/{venv,conda}/`** (plural `testenvs`, with a `<name>` slot). The reserved `testenv` resolves to `.pyve/testenvs/testenv/venv/`.

**The singular→plural rename is an intentional structural boundary** between Pyve <2.8.x and Pyve 2.8+. Every project under v2.8 has the new layout; every project under v2.7 has the old. Existing projects must transparently migrate — `pyve update` runs the migration the first time it sees the legacy layout, and the consumer-side resolver in [lib/testenvs.sh](../../lib/testenvs.sh) runs the same migration opportunistically the first time a `pyve test` / `pyve testenv …` call needs the testenv on a not-yet-`update`d project. After migration, the legacy `.pyve/testenv/` directory is gone and the boundary is unambiguous.

**Bundle structure (M.h.1 → M.h.4).** Each sub-story is independently RED-GREEN testable; the bundle ships unversioned with the rest of the testenv-DX bundle, releasing at M.t (v2.8.0).

| Sub-story | Scope |
|---|---|
| **M.h.1** | `.state` file format + read/write helpers in `lib/testenvs.sh`. Pure schema + helpers; no callers yet. |
| **M.h.2** | `migrate_legacy_testenv_layout` helper (uses M.h.1's `.state` writer). Detects legacy, mv to new path, writes initial `.state`. Idempotent. Not yet wired. |
| **M.h.3** | Activate the new layout — wire M.h.2 into `pyve update`, add opportunistic-migration fallback in `resolve_testenv_path`, sweep every hard-coded `.pyve/$TESTENV_DIR_NAME/venv` consumer to read through the resolver. |
| **M.h.4** | Docs sweep — `tech-spec.md` testenv-layout section, `features.md` testenv DX entries, `project-essentials.md` Pyve Essentials block acknowledging the new path shape. |

**Out of scope (bundle-wide).** Namespace command expansion to take `<name>` arguments (M.i); `.state` field consumption — `last_used_at` touch lands in M.m, `provisioned_at` / `manifest_sha256` consumption lands in M.p's `pyve testenv list` / `prune`.

---

### Story M.h.1: [Testenv-DX] `.state` file format + read/write helpers [Done]

**Why.** Every consumer in the bundle (migration in M.h.2; list/prune in M.p; lazy-provision in M.n; last-used tracking in M.m) needs a single shared format for per-env state. Ship the schema + helpers first so M.h.2+ has stable API.

**Schema (plain `key=value`, sourceable):**

```
backend=venv|micromamba|inherit
manifest=<relative path or empty>
manifest_sha256=<64-hex or empty>
provisioned_at=<unix epoch seconds>
last_used_at=<unix epoch seconds or 0>
```

`.state` lives at `.pyve/testenvs/<name>/.state` (sibling to `venv/` or `conda/`).

**Helpers in [lib/testenvs.sh](../../lib/testenvs.sh):**

- `state_path <name>` — print `.pyve/testenvs/<name>/.state`.
- `state_write <name> <backend> [manifest=<path>] [manifest_sha256=<hex>] [provisioned_at=<epoch>] [last_used_at=<epoch>]` — write/overwrite the file. Missing optional fields default sensibly (`manifest=""`, `provisioned_at=$(date +%s)`, `last_used_at=0`).
- `state_read <name>` — populate caller's shell with `PYVE_TESTENV_STATE_BACKEND`, `_MANIFEST`, `_MANIFEST_SHA256`, `_PROVISIONED_AT`, `_LAST_USED_AT` (function-global per [lib/testenvs.sh](../../lib/testenvs.sh)'s established plain-assignment pattern; bash-3.2-safe per [Bash 3.2 empty-array reads](../project-guide/templates/artifacts/pyve-essentials.md)).
- `state_touch_last_used <name>` — set `last_used_at=$(date +%s)`, leave other fields intact.

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenvs_state.bats](../../tests/unit/test_testenvs_state.bats): write→read round-trip, default-field behavior, `state_touch_last_used` updates only `last_used_at`, missing `.state` returns non-zero from `state_read` cleanly, bash-3.2 `set -u` safety. *(11 tests; RED → GREEN 11/11; full unit suite 908/908.)*
- [x] Implement the four helpers in [lib/testenvs.sh](../../lib/testenvs.sh) using the plain-assignment pattern established in M.g. *(state_read parses via `IFS= read` loop rather than `source` to prevent shell-injection from a malformed `.state`.)*
- [x] No consumers yet — M.h.2 is the first.

**Out of scope.** The migration helper (M.h.2); any consumer that touches `.state` (M.h.3, M.m, M.p).

---

### Story M.h.2: [Testenv-DX] `migrate_legacy_testenv_layout` helper [Done]

**Why.** Move the on-disk testenv layout from `.pyve/testenv/venv/` (singular, hard-coded) to `.pyve/testenvs/testenv/venv/` (plural, name-keyed). Helper is standalone — M.h.3 wires it into the call sites.

**Behavior.**

1. If `.pyve/testenvs/testenv/venv/` already exists → no-op (idempotent; the migration has already run).
2. Else if `.pyve/testenv/venv/` exists → `mkdir -p .pyve/testenvs/testenv`, `mv .pyve/testenv/venv .pyve/testenvs/testenv/venv`, `rmdir .pyve/testenv` if empty (it should be), write initial `.state` via M.h.1 helpers (`backend=venv`, `manifest=""`, `manifest_sha256=""`, `provisioned_at=<mtime of the venv dir>`, `last_used_at=0`). Log a one-line `info` so the user sees what happened.
3. Else → no-op (greenfield project; nothing to migrate).

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenvs_migration.bats](../../tests/unit/test_testenvs_migration.bats): legacy→new migration with `.state` written; idempotency (already-migrated → no-op); greenfield (no-trigger); legacy + new both exist (no-op, do not overwrite). *(9 tests covering all four cases + mtime preservation + bash-3.2 `set -u` safety. RED 8/9 → GREEN 9/9. Full unit suite 917/917.)*
- [x] Implement `migrate_legacy_testenv_layout` in [lib/testenvs.sh](../../lib/testenvs.sh) (single function, calls M.h.1's `state_write`). *(macOS/Linux `stat` inline per `lib/micromamba_env.sh`'s existing pattern; legacy `.pyve/testenv/` parent removed only if empty; the both-exist case preserves both layouts rather than silently deleting user state.)*
- [x] Not yet invoked from `pyve update` or the resolver — that's M.h.3.

**Out of scope.** Wiring into `pyve update` / the consumer path; updating any hard-coded legacy-path references in command files.

---

### Story M.h.3: [Testenv-DX] Activate the new layout — wire migration, sweep consumers [Done]

**Why.** With M.h.2 in place but unwired, the codebase still hard-codes `.pyve/$TESTENV_DIR_NAME/venv` (= `.pyve/testenv/venv/`) in `lib/utils.sh` and the five command files. M.h.3 is the cut-over: wire migration into `pyve update`, add an opportunistic-migration fallback in `resolve_testenv_path` (so `pyve test` etc. work even before `pyve update`), and sweep every consumer to read through the resolver.

**Approach.**

1. **Wire `pyve update`** — `update_project` in [lib/commands/update.sh](../../lib/commands/update.sh) calls `migrate_legacy_testenv_layout` near the start of its project-shape refresh block.
2. **Opportunistic-migration fallback** — `resolve_testenv_path testenv` in [lib/testenvs.sh](../../lib/testenvs.sh) calls `migrate_legacy_testenv_layout` if the new path doesn't exist and the legacy one does, *before* returning the new path. Users on v2.8 who run `pyve test` before `pyve update` get migrated transparently. (Other names short-circuit — only `testenv` has a legacy form to migrate.)
3. **Consumer sweep** — every reference to `.pyve/$TESTENV_DIR_NAME/venv` (or hard-coded `.pyve/testenv/venv`) reads from `resolve_testenv_path testenv` instead. Files touched (per the M.h pre-flight grep): [lib/utils.sh](../../lib/utils.sh) (`testenv_paths`, `purge_testenv_dir`, `ensure_testenv_exists`), [lib/commands/test.sh](../../lib/commands/test.sh), [lib/commands/testenv.sh](../../lib/commands/testenv.sh), [lib/commands/check.sh](../../lib/commands/check.sh), [lib/commands/status.sh](../../lib/commands/status.sh), [lib/commands/purge.sh](../../lib/commands/purge.sh).
4. **`TESTENV_DIR_NAME` global**: retain as a back-compat constant pointing at `testenv` (the reserved name) so any external script referencing it doesn't break, but stop reading it from any internal path construction. Deprecation-removal can be a later cleanup story.

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenvs_activate.bats](../../tests/unit/test_testenvs_activate.bats): 13 tests covering resolver side-effect migration, resolver purity on greenfield/already-migrated, other-name short-circuit, `testenv_paths` shape, `purge_testenv_dir` new layout, gitignore template, `_update_migrate_legacy_layout` wrapper exists + invocation, source-grep wiring check, and a sweep guard that asserts no legacy literal survives in production code. *(RED 7/13 → GREEN 13/13.)*
- [x] Wire migration into `update_project` in [lib/commands/update.sh](../../lib/commands/update.sh) via a thin `_update_migrate_legacy_layout` wrapper (grep-visible name for the source-level wiring check). Runs pre-step, after config sanity check, before `header_box`.
- [x] Add the opportunistic-migration fallback to `resolve_testenv_path testenv` in [lib/testenvs.sh](../../lib/testenvs.sh). Only `testenv` triggers migration; `root` and named envs short-circuit.
- [x] Sweep the six consumer files to use the resolver. Verify no `.pyve/testenv/venv` or `.pyve/$TESTENV_DIR_NAME` literal survives outside of `lib/testenvs.sh`'s migration helper and `pyve.sh`'s back-compat global. *(Implicit-scope adds flagged at announce gate: gitignore template `.pyve/testenv` → `.pyve/testenvs` in [lib/utils.sh:859](../../lib/utils.sh#L859); `--keep-testenv` semantic expansion from "preserve single legacy testenv" to "preserve whole `.pyve/testenvs/` tree" in [lib/commands/purge.sh](../../lib/commands/purge.sh) — both included for v2.8 coherence.)*
- [x] Verify full unit suite passes after the sweep. *(930/930 ok. Three pre-existing test files updated: [tests/unit/test_test_command.bats](../../tests/unit/test_test_command.bats) and [tests/unit/test_status.bats](../../tests/unit/test_status.bats) fixtures now create envs at the new path; [tests/unit/test_utils.bats](../../tests/unit/test_utils.bats) idempotency tests use the new pattern. The `test_test_command` setup now sources `lib/testenvs.sh` since `test.sh` resolves paths through it.)*

**Out of scope.** `.state` field *consumption* — touch `last_used_at` lands in M.m, `provisioned_at` / `manifest_sha256` read lands in M.p. M.h.3 only writes `.state` at migration time (via M.h.2) and at provisioning time (existing `testenv_init` writes it via the M.h.1 helper).

---

### Story M.h.4: [Testenv-DX] Docs sweep — testenv layout, `.state` schema, migration mechanism [Done]

**Why.** With code shipped (M.h.1–M.h.3), the user-facing and internal docs need to describe the new layout, the `.state` schema, and the migration mechanism. Without this, the bundle ships with stale docs pointing at `.pyve/testenv/venv/` everywhere.

**Files touched.**

- [docs/specs/tech-spec.md](tech-spec.md) — extend the `lib/testenvs.sh` section (added in M.g) with `.state` schema + migration mechanism; update Package Structure tree if any new files were added.
- [docs/specs/features.md](features.md) — FR-11 (or appropriate FR-M) describes the new layout as part of the testenv DX surface.
- [docs/project-guide/templates/artifacts/pyve-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md) — Pyve Essentials block: acknowledge the v2.8 layout change (`.pyve/testenv/` → `.pyve/testenvs/testenv/`); update any examples that mention paths.
- (M.s — bundle-wide user-facing docs sweep — will pick up `docs/site/testing.md` etc.; M.h.4 stays scoped to internal/spec docs to avoid duplicating M.s's surface.)

**Tasks**

- [x] Update tech-spec.md `lib/testenvs.sh` section with the M.h.1 schema table + the M.h.2/M.h.3 migration narrative. Update Package Structure tree. *(Two new subsections added — `.state` per-env state file (schema table + helper table) and Legacy-layout migration (four-case outcome table + call sites + consumer-sweep narrative + `--keep-testenv` semantic expansion + gitignore template note + `TESTENV_DIR_NAME` back-compat note). Resolver row in the function table updated to mention the opportunistic-migration side effect. Test inventory extended with three new bats files.)*
- [x] Update features.md FR-11 (or appropriate FR-M) entry for the layout shift. *(Two new bullets at the top of FR-11: v2.8+ layout shift + migration mechanism; per-env `.state` file schema summary. Inline `.pyve/testenv/venv/` reference in the M.c paragraph updated to the new path.)*
- [x] Update project-essentials.md Pyve Essentials section. *(Workflow-rules bullets updated to reference `.pyve/testenvs/testenv/venv/`; new admonition block flags the v2.8 rename for projects upgrading from v2.7. Editable-install example path updated.)*
- [x] No code changes in this story.

**Out of scope.** User-facing `docs/site/` files — those land in M.s alongside the bundle's broader doc sweep.

---

### Story M.i: [Testenv-DX] `testenv` namespace expansion — name-aware ops [Bundle, Done]

**Why.** With named envs declared (M.g) and the layout in place (M.h), the `testenv` namespace commands need an optional `<name>` argument. The reserved `testenv` name keeps existing single-env workflows working. With-arg branches operate on a single named env; no-arg branches preserve today's defaults for unconfigured projects and expand naturally to "all non-lazy envs" (install) and "all envs with confirmation" (purge) for projects that declare named envs.

**Target surface** (per TC-M.6 in the plan doc):

| CLI | No-arg behavior | With-arg behavior |
|---|---|---|
| `pyve testenv init [<name>]` | Default `testenv` | Named env |
| `pyve testenv install [<name>] [-r …]` | All non-lazy envs | Named env only |
| `pyve testenv purge [<name>]` | All envs (confirm; `--force` skips) | Named env only |
| `pyve testenv run [<name>] -- <cmd>` | Default `testenv` | Named env via `--` separator |

**Bundle-wide scope guards** (apply to every sub-story):

- **Conda-backed envs** (`backend = "micromamba"` or `inherit`) are stubbed with a "conda backend not yet implemented; see M.k" hard-error in M.i.1 and stay that way through the bundle. M.k implements the conda mechanics; M.i.1's stub is the placeholder.
- **Manifest source consumption** (declared `requirements = [...]` / `extra = "dev"` from `[tool.pyve.testenvs]`) is NOT in this bundle — `install` continues to accept `-r <file>` or install bare `pytest` exactly like today. M.l flips that switch.
- **Per-env install lock** (`.pyve/testenvs/<name>/.lock` via `flock`) is M.j, not M.i.
- **Lazy auto-provisioning on first targeted use** (`pyve test --env <lazy-env>` triggering an install) is M.n.

**Bundle structure (M.i.1 → M.i.4).** Each sub-story is independently RED-GREEN testable; the bundle ships unversioned, releasing at M.t (v2.8.0).

| Sub-story | Scope |
|---|---|
| **M.i.1** | Prep — generalize `ensure_testenv_exists` to accept `[<name>]`; add a name-validation gate that rejects `root` (selection-only) and undeclared names with helpful errors; add the conda-backend stub. No user-facing leaf changes yet. |
| **M.i.2** | `testenv init [<name>]` + `testenv run [<name>] -- <cmd>` — both single-env leaves, name-aware. `run` uses `--` as the disambiguator when a name is present. |
| **M.i.3** | `testenv install [<name>] [-r …]` — with-arg single-env behavior + no-arg iteration over non-lazy envs. |
| **M.i.4** | `testenv purge [<name>] [--force]` — with-arg single-env behavior + no-arg "all envs (confirm)" iteration; `--force` skips confirmation. |

**Out of scope (bundle-wide).** `pyve testenv list` / `prune` (M.p — new leaves); per-env install lock (M.j); conda backend provisioning (M.k); declared manifest source consumption (M.l); lazy auto-provisioning (M.n).

---

### Story M.i.1: [Testenv-DX] Name-aware `ensure_testenv_exists` + validation gate + conda stub [Done]

**Why.** All four leaves in M.i.2–M.i.4 need a shared way to "ensure the named env exists" (path-aware variant of today's `ensure_testenv_exists`) and a shared "is this name legal" gate that rejects `root` and undeclared names with helpful errors. Ship those + the conda-backend stub first so M.i.2+ can call them.

**Approach.**

1. **Generalize `ensure_testenv_exists` in [lib/utils.sh](../../lib/utils.sh)** to accept an optional `<name>` argument that defaults to `testenv`. Path resolution moves from `testenv_paths` (which is `testenv`-specific) to `resolve_testenv_path "$name"`. Existing callers (e.g. `test.sh`'s `test_tests`) keep working — no arg, same default behavior.
2. **New name-validation gate** in [lib/testenvs.sh](../../lib/testenvs.sh): `assert_testenv_name_actionable <name>` (or similar). 0 if `<name>` is declared or equal to reserved `testenv`; 1 with a precise stderr error otherwise. Rejects `root` (selection-only — `pyve test --env root` works, but `pyve testenv init root` does not) and undeclared names (with a hint pointing at `[tool.pyve.testenvs]`).
3. **Conda-backend stub** in `ensure_testenv_exists`: when the named env declares `backend = "micromamba"` or `backend = "inherit"`, hard-error with `conda-backed testenv '<name>' requires backend support not yet implemented (see Story M.k)`. Exit non-zero. Venv-backed envs proceed as today (just at the per-env path).

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenv_name_aware.bats](../../tests/unit/test_testenv_name_aware.bats): `ensure_testenv_exists` (no arg / with declared name / with reserved `root` rejected / with undeclared name rejected / with conda-backed name rejected with M.k hint); `assert_testenv_name_actionable` (declared/reserved-testenv/root/undeclared/bash-3.2 `set -u` safety). *(14 tests; RED 13/14 → GREEN 14/14. Full unit suite 944/944.)*
- [x] Generalize `ensure_testenv_exists` in [lib/utils.sh](../../lib/utils.sh). *(Accepts optional `<name>` defaulting to `testenv`; calls `read_testenv_config` (idempotent if already loaded), then validates via `assert_testenv_name_actionable` + `assert_testenv_venv_backend`; resolves path via `resolve_testenv_path "$name"`.)*
- [x] Add `assert_testenv_name_actionable` in [lib/testenvs.sh](../../lib/testenvs.sh). *(Stricter than `validate_testenv_decl`: rejects `root` (selection-only) and undeclared names with helpful errors pointing at `[tool.pyve.testenvs]`.)*
- [x] Wire the conda-backend stub. *(Factored as `assert_testenv_venv_backend` per the announce-gate decision — reusable by M.i.3/M.i.4 install/purge leaves. Error message includes `(see Story M.k)` so future readers find the implementation locus.)*
- [x] Verify full unit suite passes — existing callers must keep working unchanged. *(Found and fixed two lurking issues: (a) `read_testenv_config` now short-circuits in pure bash when `pyproject.toml` is absent — no Python subprocess needed for bash-only projects, matching spike Decision 5; (b) hardened `_testenvs_name_to_index` against unset `PYVE_TESTENVS_NAMES` under `set -u`, exposed when `resolve_testenv_path` is called before any caller has loaded config.)*

**Out of scope.** Wiring into the four leaves (M.i.2–M.i.4); any user-facing CLI change. M.i.1 is internal-helpers-only.

---

### Story M.i.2: [Testenv-DX] `testenv init [<name>]` + `testenv run [<name>] -- <cmd>` [Done]

**Why.** Both are single-env leaves with no iteration semantics — combining them in one story keeps the bundle granular without producing two trivially-tiny stories.

**Approach.**

1. **`pyve testenv init [<name>]`** — dispatcher accepts an optional positional `<name>` after `init`. Calls `assert_testenv_name_actionable "$name"` (M.i.1), then `ensure_testenv_exists "$name"` (M.i.1). No-arg path is unchanged (defaults to `testenv`).
2. **`pyve testenv run [<name>] -- <cmd>`** — dispatcher accepts an optional positional `<name>` followed by `--` separator before the command. Without `--`, the first arg is the command (today's behavior). With `<name> -- <cmd>`, the name is validated, the path is resolved, and `testenv_run` exec's the command inside the named env. Ambiguous shapes (e.g. a bare positional that's neither `--` nor a recognizable command) hard-error with usage hints.

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenv_init_name.bats](../../tests/unit/test_testenv_init_name.bats) (5 tests) + [tests/unit/test_testenv_run_name.bats](../../tests/unit/test_testenv_run_name.bats) (10 tests): no-arg behavior preserved; with-arg success for a declared venv-backed env; reserved `root` and undeclared names hard-error; `run` `--` separator parsing (three valid shapes); name validation through M.i.1 gates; `--` with no command errors. *(RED 10/15 → GREEN 15/15. Full unit suite 959/959.)*
- [x] Extend the dispatcher arg parser in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) for `init` and `run`. *(`init`: optional positional `<name>` consumed in the case arm. `run`: post-loop logic detects `[<name>] --` by peeking `${1:-}` and `${2:-}` — name routing requires the explicit `--` separator per the announce-gate decision.)*
- [x] Update `testenv_init` to accept `<name>`; `testenv_run`'s `<testenv_venv>` argument continues to be path-shaped (the dispatcher resolves the path before calling).
- [x] Update per-leaf help blocks — *no per-leaf `show_testenv_<sub>_help` functions exist today; updated the namespace `--help` heredoc to document the new `init [<name>]` and `run [<name> --] <cmd>` shapes. Per-leaf functions are tracked as a Future story (added to the `## Future` section in this commit).*
- [x] Verify full unit suite passes (no regressions to existing `pyve testenv init` / `run` callers). *(Also fixed a lurking issue: dispatcher previously swallowed the return code from leaf functions because `footer_box` was the last command; now captures `leaf_rc` and returns it.)*

**Out of scope.** `install` (M.i.3); `purge` (M.i.4); conda-backend implementation (stubbed in M.i.1).

---

### Story M.i.3: [Testenv-DX] `testenv install [<name>] [-r …]` — with-arg + no-arg iteration [Done]

**Why.** `install` has two distinct behaviors that share most of the same code path: with-arg installs into one env; no-arg iterates over all non-lazy declared envs. Ship them together so the iteration loop and the single-env call share a tested implementation.

**Approach.**

1. **With-arg single-env behavior** — dispatcher accepts an optional `<name>` and an optional `-r <file>`; both may appear in either order. Validates name via M.i.1's gate; resolves path; calls `testenv_install <path> <requirements_file>` (the existing 2-arg function) unchanged. Conda-backed envs error per M.i.1's stub.
2. **No-arg iteration** — when no `<name>` is given, `read_testenv_config` populates `PYVE_TESTENVS_NAMES`; iterate non-lazy envs (`is_testenv_lazy <name>` returns 1); call the single-env install for each in turn. Per-env step header so the user sees per-env progress. If iteration finds no envs to install (all declared envs are lazy), print an info message and return 0.
3. **Default-config single-env path preserved** — projects without `[tool.pyve.testenvs]` declare only the implicit `testenv` (non-lazy), so no-arg install iterates over exactly one env: the default `testenv`. Today's behavior is preserved by definition.

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenv_install_name.bats](../../tests/unit/test_testenv_install_name.bats): 10 tests covering all the listed scenarios. *(RED 9/10 → GREEN 10/10. Full unit suite 969/969.)*
- [x] Extend the dispatcher arg parser in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) for `install`. *(Sub-parser inside the `install)` case arm handles `-r <file>` and the optional positional `<name>` in either order; an unrecognized flag breaks back to the outer loop so `--help` / unknown-flag errors still work.)*
- [x] Implement the iteration loop (small new dispatcher-private helper, e.g. `_testenv_install_all_nonlazy`). *(Iterates `PYVE_TESTENVS_NAMES`, skips lazy and conda-backed envs (conda gets a one-line `Skipping '<name>' (conda backend; see Story M.k).` info — non-fatal), returns the first install failure's status. Per-env progress via `info "Installing '<name>' testenv..."`.)*
- [x] Update help block for `install`. *(Namespace `--help` heredoc adds the `[<name>]` slot and a note that no-arg iterates non-lazy envs and skips conda-backed envs.)*
- [x] Verify full unit suite passes.

**Out of scope.** Declared `requirements = [...]` / `extra = "dev"` consumption (M.l); per-env install lock (M.j); lazy auto-provisioning on `pyve test` (M.n).

---

### Story M.i.4: [Testenv-DX] `testenv purge [<name>] [--force]` — with-arg + no-arg iteration with confirm [Done]

**Why.** `purge` mirrors `install`'s shape but with a confirmation gate on the iteration path. The single-env path has no confirmation (matching today's `testenv_purge` behavior); the iteration path prompts `y/N` before removing all declared envs; `--force` skips the prompt.

**Approach.**

1. **With-arg single-env behavior** — dispatcher accepts an optional `<name>`. Validates via M.i.1's gate; resolves path; removes `.pyve/testenvs/<name>/` (the env root, not just `venv/` — covers `.state` and any future siblings). No confirm. Conda-backed envs are also purged (the on-disk shape isn't backend-specific).
2. **No-arg iteration** — when no `<name>` is given, prompt `Remove all <N> dev/test runner environments? [y/N]`. If `y`: iterate every declared env (including lazy ones — purge isn't gated on laziness) and remove each; if `N` or empty: abort, return 0, no changes. Per-env success message.
3. **`--force` flag** — if present, skip the confirmation; otherwise behavior is identical. The flag is supported on both the with-arg and no-arg paths (no-op on with-arg since there's no confirm there, but accepted for shell-script consistency).

**Tasks**

- [x] Failing bats tests first in [tests/unit/test_testenv_purge_name.bats](../../tests/unit/test_testenv_purge_name.bats): 12 tests covering all the listed scenarios + simulated-TTY tests (via `PYVE_FORCE_PROMPT=1` + `echo y|n` pipe) that exercise the interactive confirm flow. *(RED 7/12 → GREEN 12/12. Full unit suite 981/981.)*
- [x] Extend the dispatcher arg parser in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) for `purge` (handle the `--force` flag here). *(Sub-parser inside the `purge)` case arm handles `--force` and optional positional `<name>` in either order; same shape as M.i.3's `install` sub-parser.)*
- [x] Implement the iteration + confirmation logic (dispatcher-private helper, e.g. `_testenv_purge_all_with_confirm`). *(TTY-aware confirm per the announce-gate pick (c): non-TTY (CI) skips the prompt, interactive TTY prompts `y/N`. `--force` skips the prompt explicitly. `PYVE_FORCE_PROMPT=1` env-var forces the prompt even on non-TTY stdin — used by bats tests. Per-env failures surface via `warn()` but don't halt iteration; `rc` accumulates worst exit.)*
- [x] Update help block for `purge`.
- [x] Verify full unit suite passes — existing single-env `pyve testenv purge` callers must keep working (no-arg behavior is now "purge all," not "purge the default" — but in the implicit-default config that's the same one env). *(`purge_testenv_dir` in `lib/utils.sh` generalized to accept optional `<name>` (default `testenv`); uses `dirname` of the resolver output so it handles both venv and conda layout shapes without hard-coding the suffix.)*

**Out of scope.** `pyve testenv list` / `prune` (M.p); reading `.state` files (M.p consumes them); recovery from partial-purge failures.

---

### Story M.j: [Testenv-DX] Per-env install lock (`.pyve/testenvs/<name>/.lock`) [Done]

**Why.** Pyve owns the testenv lifecycle. Concurrent `pyve testenv install <same-env>` from two shells must serialize on the env, not collide on the package cache.

**Approach.** Pure-bash atomic `mkdir`-as-lock at `.pyve/testenvs/<name>/.lock`. `mkdir` is the standard POSIX primitive for atomic directory creation — a second concurrent `mkdir` of the same path fails with `EEXIST`, serializing installers without an external binary. The holding pid is written into `.lock/pid` so a waiting process can name who holds the lock.

**Correction (at announce gate).** The plan originally said "`flock`-based lock," but `flock(1)` is **not installed on macOS** by default and macOS is a first-class pyve platform. The cheapest portable alternative — `mkdir` — covers the same semantic surface (atomic acquire, serialized wait, fast-fail on collision) without an OS-specific binary. Stale-lock reclamation uses `kill -0` to probe the holding pid: if the holder no longer exists, the lock is freed and re-acquired.

Acquired around `pyve testenv install <name>` and any auto-provision path (M.n). Second invocation waits by default (1-second sleep+retry); `--no-wait` exits non-zero with a "another pyve process is installing `<name>` (pid N)" message. A `trap` guarantees release on any exit signal (success, error, SIGINT) so the lock dir never strands the env.

**Tasks**

- [x] Failing tests first in [tests/unit/test_testenv_install_lock.bats](../../tests/unit/test_testenv_install_lock.bats): 10 tests covering lock-dir/pid file shape, release-when-holder semantics, foreign-lock survival on release, `--no-wait` collision message + non-zero exit, stale-lock reclamation via `kill -0`, integration cleanup on successful + failed (`-r does-not-exist.txt`) install, `--no-wait` happy path, and `--help` documents the flag. *(RED 5/10 → GREEN 10/10. Full unit suite 991/991.)*
- [x] `_testenv_acquire_install_lock` / `_testenv_release_install_lock` helpers in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) (command-private, `_testenv_` prefix). *(Also added `_testenv_install_lock_dir` path helper and `_testenv_install_with_lock` wrapper that pairs acquire+install+release with a `trap … EXIT INT TERM` so the `exit 1` paths inside `testenv_install` and SIGINT both clean the lock dir.)*
- [x] Wire lock acquire/release around every `testenv_install` call in the dispatcher. *(Single-env path calls `_testenv_install_with_lock` directly; `_testenv_install_all_nonlazy` takes a new `lock_mode` arg and wraps each per-env install. Release is gated on `pid file == $$` so a stray release call cannot remove another process's in-progress lock.)*
- [x] Add `--no-wait` flag parsing to the `install` sub-parser; document in the namespace `--help` block. *(`install_no_wait` local in `testenv_command` set by the sub-parser; mapped to `lock_mode="no-wait"` at the install case arm; help heredoc adds Usage and a Notes paragraph naming the lock path and the fast-fail message format.)*

**Out of scope.** Read-only execution locking (`pyve test --env <name>` fast path is lock-free); cross-host locks (local file lock only; document the limit). Lock-aware `pyve testenv purge` (a purge while an install runs would race; current `rm -rf` of the env root is independent of the lock and remains so for this story — the lock prevents install/install collisions, not install/purge ones).

---

### Story M.k: [Testenv-DX] Conda-backed testenv plumbing (`backend = "micromamba"`) [Done]

**Why.** UC2 (test/runtime parity for conda mains) and UC3 (conda-only native deps — GDAL, CUDA, HDF5) both reduce to "per-env conda backend." The main-env micromamba paths exist; testenvs need the same plumbing minus the `.envrc`.

**Approach.** Reuse [lib/micromamba_core.sh::get_micromamba_path](../../lib/micromamba_core.sh) for binary resolution; add `_testenv_init_conda` (`micromamba create -p <path> -f <manifest> -y`) and `_testenv_install_conda` (`micromamba install -p <path> -f <manifest> -y`) to [lib/commands/testenv.sh](../../lib/commands/testenv.sh). Conda-backed envs accept `manifest = "<environment.yml>"` (FR-M.3); mutually exclusive with `requirements`/`extra` (validation already in the M.g Python helper). New shared helper `_testenv_resolve_backend` in [lib/testenvs.sh](../../lib/testenvs.sh) returns the concrete backend (`venv` | `micromamba`) — for `inherit`, defers to `read_config_value backend` from `.pyve/config`. The resolver consumes it so `inherit` produces the right path shape (venv when main is venv, conda when main is micromamba); `ensure_testenv_exists` and `_testenv_install_with_lock` consume it for init/install dispatch; `assert_testenv_venv_backend` consumes it so the run-only gate sees the resolved backend.

**Correction (during M.k execution).** `pyve testenv run` for conda envs was kept out of scope and surfaced at the announce gate: `testenv_run` does PATH-only activation (exports `VIRTUAL_ENV`, prepends `<env>/bin` to `PATH`), which is insufficient for conda envs that need `CONDA_PREFIX` / `CONDA_PYTHON_EXE`. The `assert_testenv_venv_backend` helper is kept (no longer the "M.k stub" — its responsibility shrinks to "venv-only gate for `run`") with a new error message pointing at `micromamba run -p .pyve/testenvs/<name>/conda <command>` as the manual workaround. Conda `run` is a future-story candidate.

**Tasks**

- [x] Failing tests first in [tests/unit/test_testenv_conda.bats](../../tests/unit/test_testenv_conda.bats): 16 tests covering `_testenv_resolve_backend` (venv / micromamba / inherit + main=venv / inherit + main=micromamba / inherit + no config), `resolve_testenv_path` for inherit (both main backends), `_testenv_init_conda` (happy path + missing-file + empty-manifest errors), `_testenv_install_conda` (happy path + env-not-initialized error), `testenv init <conda-name>` + `testenv install <conda-name>` dispatcher routing, and no-arg iteration including conda envs (no "see Story M.k" skip). *(RED 15/16 → GREEN 16/16. Full unit suite 1008/1008.)*
- [x] `_testenv_init_conda` + `_testenv_install_conda` helpers in [lib/commands/testenv.sh](../../lib/commands/testenv.sh). Both require a non-empty `manifest` and verify the file exists before invoking `micromamba`; `_init_conda` is idempotent (info-and-skip when `conda-meta` exists); `_install_conda` requires the env to exist (`pyve testenv init <name>` hint otherwise).
- [x] `backend = "inherit"` resolution via [lib/testenvs.sh](../../lib/testenvs.sh) `_testenv_resolve_backend` (reads main env's backend via `read_config_value backend` from `.pyve/config`). Wired into `resolve_testenv_path` (path shape), `ensure_testenv_exists` (init dispatch), `_testenv_install_with_lock` (install dispatch), and `assert_testenv_venv_backend` (run-only gate).
- [x] No `.envrc` emission for testenvs — confirmed: neither `_testenv_init_conda` nor `ensure_testenv_exists` touches `.envrc`. Testenv activation lives in the wrapper commands (`testenv_run`'s PATH/`VIRTUAL_ENV` exports, `pyve test`'s direct `<testenv>/bin/python -m pytest` invocation), not in direnv.
- [x] Update [tech-spec.md](tech-spec.md) testenv backend section: extended the `lib/testenvs.sh` function table with `_testenv_resolve_backend` and updated `resolve_testenv_path` + `assert_testenv_venv_backend` descriptions; rewrote the `lib/commands/testenv.sh` function table to cover M.i/M.j/M.k surface (`testenv_command` flag inventory, conda + lock helpers, `_testenv_install_all_nonlazy` dispatch); added a new "Conda backend dispatch (Story M.k)" subsection under Legacy-layout migration; updated the M.k bullet in "Consumers" to mark it landed; added the two new test files to the inventory tree.

**Updates to existing tests (M.k semantic shift).**

- [tests/unit/test_testenv_name_aware.bats](../../tests/unit/test_testenv_name_aware.bats): renamed three M.k-stub assertions to reflect post-landing semantics — `assert_testenv_venv_backend` is now the run-only gate; `inherit` resolution now depends on `.pyve/config`'s main backend; `ensure_testenv_exists` for a conda env now hard-errors on missing manifest file instead of returning the stub. Also added a new test for `inherit + main=venv` passing the gate.
- [tests/unit/test_testenv_init_name.bats](../../tests/unit/test_testenv_init_name.bats): rewrote the M.k-stub test to assert missing-manifest-file hard-error.
- [tests/unit/test_testenv_install_name.bats](../../tests/unit/test_testenv_install_name.bats): rewrote the iteration test to include the conda env (now uses a stubbed `micromamba` recorder); rewrote the single-env conda test to assert missing-manifest-file hard-error.
- [tests/unit/test_testenv_run_name.bats](../../tests/unit/test_testenv_run_name.bats): updated the conda-rejection test message check (no more "M.k" hint; now asserts `hardware` + `conda`/`micromamba` in the workaround message).

**Out of scope (carried).** `pyve lock --env <name>` (M.q); pip-installed-into-conda mixed mode; conda `pyve testenv run` (deferred per Correction above).

**Version impact.** None — M.k is part of the testenv-DX bundle, which ships unversioned during work and releases as `v2.8.0` at M.t.

---

### Story M.l: [Testenv-DX] venv manifest sources — `requirements` and `extra` [Done]

**Why.** Venv-backed testenvs need both `requirements = ["…"]` (one or more pip manifests) and `extra = "<name>"` (named optional-dependency extra from `pyproject.toml`).

**Approach.** Renamed `testenv_install` → `_testenv_install_venv` in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) (symmetry with M.k's `_testenv_install_conda`) and grew its signature to take `<name>` so it can read declarations. Five-stage source dispatch (highest precedence first):

1. CLI `-r <file>` (today's explicit-override behavior).
2. Declared `requirements = ["a","b"]` → `pip install -r a -r b`.
3. Declared `extra = "<name>"` → resolve `[project.optional-dependencies].<name>` via the Python helper's new `--resolve-extra` mode, `pip install <pkg1> <pkg2> ...`.
4. Auto-detected `requirements-dev.txt` in CWD → `pip install -r requirements-dev.txt`.
5. Bare `pytest` fallback (pre-M.l default).

Mutex enforcement (`requirements ⊕ extra ⊕ manifest`) lives in the M.g Python helper at config-read time, so by dispatch time at most one of (2) and (3) is non-empty.

**Naming choice (announce-gate decision (a)).** Renaming over extending-in-place: blast radius was ~1 production caller (`_testenv_install_with_lock`) plus two fixtures, in exchange for the readable `_testenv_install_venv` / `_testenv_install_conda` symmetry in the lock wrapper.

**Tasks**

- [x] Failing tests first in [tests/unit/test_testenv_venv_manifest.bats](../../tests/unit/test_testenv_venv_manifest.bats): 11 tests covering `requirements` single/multi-file + missing-file hard-error; `extra` resolution from `[project.optional-dependencies]` + missing-extra hard-error; auto-detect `requirements-dev.txt`; bare-`pytest` fallback; CLI `-r` override of both declared sources; M.g mutex validation; mixed iteration (one env with `extra`, one with `requirements`). *(RED 7/11 → GREEN 11/11. Full unit suite 1019/1019.)*
- [x] Rename `testenv_install` → `_testenv_install_venv` and grow its dispatch in [lib/commands/testenv.sh](../../lib/commands/testenv.sh). Updated caller `_testenv_install_with_lock` to use the new name and pass `<name>`. New private `_testenv_resolve_extra_packages` invokes the helper's `--resolve-extra` mode and populates a caller-named array.
- [x] Python helper extension — added `--resolve-extra <pyproject> <extra_name>` side mode to [lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py). Emits one package spec per line on success; exits 2 with a precise stderr message for missing pyproject, undeclared extra (lists available extras), or non-list extra value.
- [x] Fixture updates: [tests/unit/test_testenv_install_name.bats](../../tests/unit/test_testenv_install_name.bats) `_fixture_named_envs` now creates the declared `requirements-dev.txt` + `tests/smoke-requirements.txt` files on disk; [tests/unit/test_testenv_conda.bats](../../tests/unit/test_testenv_conda.bats) `_fixture_mixed_envs` does the same for `requirements-dev.txt`. Pre-M.l the declarations were inert; post-M.l they must resolve.
- [ ] Update `docs/site/testing.md` with the three source patterns (deferred to the M.s bundle-wide user-facing docs sweep — its scope per the existing story).

**Tech-spec.md updates.** Extended the `lib/commands/testenv.sh` function table with `_testenv_install_venv` (replacing the old `testenv_install` row) and `_testenv_resolve_extra_packages`. Added a "Side mode: `--resolve-extra`" paragraph under the existing Validation-locus paragraph in the `lib/testenvs.sh` section. Updated the consumer-list bullet for M.l to mark it landed. Added [test_testenv_venv_manifest.bats](../../tests/unit/test_testenv_venv_manifest.bats) to the test inventory.

**Out of scope.** Editable installs (`pip install -e .`) — existing [Editable install and testenv dependency management](../project-guide/templates/artifacts/pyve-essentials.md) policy covers this; no change.

**Version impact.** None — M.l is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.m: [Testenv-DX] `pyve test --env <name>` resolver extension [Done]

**Why.** M.e's parser accepts only `--env {testenv, root}`. With named envs declared (M.g), the resolver needs to accept any declared name.

**Approach.** Extended the inline `--env` parser in `test_tests` (no `_test_parse_args` extraction — kept the existing shape for blast-radius hygiene):

1. Accept `--env <name>` (and `--env=<name>`).
2. Load `read_testenv_config` (idempotent) so the parser can validate names + read the declared default.
3. No `--env` → default to `${PYVE_TESTENVS_DEFAULT:-testenv}` (reads `[tool.pyve.testenvs].default`; falls back to the reserved `testenv` when no `default` declared or no `pyproject.toml`).
4. Validate via `is_testenv_declared` / the reserved-name guard (`root` short-circuits to `run_command`; `testenv` is always accepted).
5. Undeclared and not reserved → hard error listing every valid choice (`root`, `testenv`, plus declared names).
6. Conda-backed envs → hard error via `assert_testenv_venv_backend` (the same M.k gate `pyve testenv run` uses; M.n does NOT change this — run + test are venv-only by design until a future story adds conda activation).
7. Lazy envs that have not been provisioned → hard error with a `pyve testenv install <name>` hint. **M.n replaces this with auto-provisioning on the same code path.**
8. Resolve via `resolve_testenv_path "$env_target"`, auto-create via `ensure_testenv_exists "$env_target"` for non-lazy envs.
9. Touch `.state.last_used_at` via `state_touch_last_used "$env_target"` before exec — best-effort, suppressed stderr (silent no-op when `.state` is missing on legacy envs).

**Infrastructure addition.** `ensure_testenv_exists` (in [lib/utils.sh](../../lib/utils.sh)) and `_testenv_init_conda` (in [lib/commands/testenv.sh](../../lib/commands/testenv.sh)) now write an initial `.state` for freshly-created envs. Idempotent — skipped when `.state` already exists (preserves `provisioned_at` from legacy migration or a prior write). This is the infrastructure M.m's last-used touch depends on and the natural home for it (previously only the legacy migration wrote `.state`).

**Tasks**

- [x] Failing tests first in [tests/unit/test_test_env_resolver.bats](../../tests/unit/test_test_env_resolver.bats): 14 tests covering `--env <declared-name>` happy path (both `--env <val>` and `--env=<val>` forms), undeclared-name error with list of valid choices, lazy unprovisioned hard-error + lazy-already-provisioned happy path, conda-backed hard-error, no-`--env` default lookup, no-pyproject.toml fallback to `testenv`, `--env root` / `--env testenv` regressions, `.state` `last_used_at` touched on success, `--env root` does not touch other envs' state, `ensure_testenv_exists` writes initial `.state` + idempotency. *(RED 9/14 → GREEN 14/14. Full unit suite 1033/1033.)*
- [x] Extend `test_tests` inline `--env` parser in [lib/commands/test.sh](../../lib/commands/test.sh) per the nine-step rule list above.
- [x] Hard-error message lists all declared + reserved names — via `list_testenv_names` plus the reserved `root`/`testenv`.
- [x] `last-used` touch in success path — `state_touch_last_used "$env_target"` before `exec`, suppressed stderr.
- [x] Initial `.state` writes in `ensure_testenv_exists` (venv + conda branches) — the M.m-only infrastructure surface flagged at the approval gate.
- [x] Update [features.md](features.md) FR-11 — full `[--env <name>]` paragraph (defaults, undeclared, conda gate, lazy hard-error, M.n forward-pointer) + `.state` per-env file updated to cite M.m's write/touch surface.

**Tech-spec.md updates.** Rewrote the `test_tests` row in the `lib/commands/test.sh` table for the new resolver + `.state` touch. Updated the consumer-list bullet for M.m (landed). Added the new bats file to the test inventory.

**Out of scope.** Matrix (comma-separated `--env a,b,c`) — M.r. Auto-provisioning of lazy envs — M.n. Silent-skip advisory generalization to named envs — M.o.

**Version impact.** None — M.m is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.n: [Testenv-DX] Lazy provisioning (`lazy = true`) [Done]

**Why.** UC1's heavy hardware-smoke env (multi-GB ML stack) should not materialize on every CI run. `lazy = true` opts the env out of bulk install and provisions on first targeted use.

**Approach.** Three behavior changes:

1. `pyve testenv install` (no name) skips lazy envs — already true since M.i.3's iteration loop. M.n adds a regression test.
2. `pyve testenv install <lazy-env>` installs normally — also already true since M.i.3 (the lazy bit only gates *iteration*, not explicit-by-name). M.n adds a regression test.
3. **`pyve test --env <lazy-env>` auto-provisions if missing.** This is the only new behavior. M.m left a hard-error site at the lazy-unprovisioned gate; M.n replaces that with `ensure_testenv_exists "$env_target"` + `_testenv_install_with_lock "$env_target" "$path" "" wait` — the same lock wrapper that bulk install uses, so concurrent `pyve test`s on the same lazy env serialize cleanly via M.j's `mkdir`-based lock. Auto-provisioning is gated by `PYVE_NO_AUTO_PROVISION=1` for strict CI that wants the pre-M.n "is this env already built?" semantics — when set, the M.m hard-error returns (with a `PYVE_NO_AUTO_PROVISION` marker in the message so users can find the opt-out).

**Tasks**

- [x] Failing tests first in [tests/unit/test_test_env_lazy_autoprovision.bats](../../tests/unit/test_test_env_lazy_autoprovision.bats): 5 tests covering auto-provision happy path (env created, declared requirements installed via M.l, exec runs), `PYVE_NO_AUTO_PROVISION=1` hard-error (with `pyve testenv install <name>` hint), already-provisioned no-op (no second install), lock cleanup after auto-provision success, conda lazy still rejected by M.k's venv-only gate. *(RED 3/5 → GREEN 5/5. Plus 1 net new regression test in [tests/unit/test_testenv_install_name.bats](../../tests/unit/test_testenv_install_name.bats) for `install <lazy-name>`. Full unit suite 1039/1039.)*
- [x] M.m's lazy hard-error site in [lib/commands/test.sh](../../lib/commands/test.sh) replaced with the auto-provision dispatch: `was_lazy_unprovisioned` flag captured at the gate; `ensure_testenv_exists` (already in the venv code path) creates the env; immediately afterward, `_testenv_install_with_lock` installs per the env's declarations.
- [x] `is_testenv_lazy` wired into `test_tests` (already wired into `testenv_install`'s iteration via M.i.3 — no additional wiring needed for tasks 1 & 2).
- [x] `PYVE_NO_AUTO_PROVISION=1` gate added at the lazy-unprovisioned site; documented in [features.md](features.md) Environment Variables table.
- [x] Updated [tests/unit/test_test_env_resolver.bats](../../tests/unit/test_test_env_resolver.bats): the M.m "lazy unprovisioned hard-errors with install hint" test now requires `PYVE_NO_AUTO_PROVISION=1` and asserts the new opt-out-marker message text.
- [ ] Document in `docs/site/testing.md` — deferred to the M.s bundle-wide user-facing docs sweep per its existing scope.

**Tech-spec.md updates.** Updated the M.m note in `test_tests`'s row to reflect M.n landed (auto-provision + opt-out); updated the M.n consumer-list bullet (landed); added the new bats file to the test inventory.

**Features.md updates.** FR-11's lazy paragraph rewritten to "auto-provisioned… suppressible via `PYVE_NO_AUTO_PROVISION=1`"; new `PYVE_NO_AUTO_PROVISION` row in the Environment Variables table.

**Out of scope.** Pre-flight bandwidth/disk-space check; provision-time error reporting uses the underlying package manager's messages.

**Version impact.** None — M.n is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.o: [Testenv-DX] Silent-skip advisory generalization (all named envs) [Done]

**Why.** M.c's advisory fires only when routing to the default `testenv` and detecting pytest in the main env. With many named envs, the trap surface multiplies: select any named env that lacks deps the tests import, and the run looks green via silent skips. The advisory must hold for **every** env.

**Approach (announce-gate decision (a)).** Generalized `_test_main_env_has_pytest` → `_test_env_has_pytest <name>` (parameterized). The advisory in `test_tests` now scans `root` plus every declared env, skipping the target itself; any candidate where `import pytest` succeeds is listed as an alternative the user may have meant.

**Story-body advisory message redirected.** The task body's proposed message text (`pytest not found in env '<name>'…`) describes the *target env lacks pytest* case (today's install-pytest prompt), which is orthogonal to the silent-skip trap M.c generalizes. The "Why" paragraph is the load-bearing intent; the message text was a hasty draft. Implemented the silent-skip generalization only — `pytest not found in env` polish to the install-pytest prompt remains a candidate for a future story, not folded into M.o.

**Tasks**

- [x] Failing tests first in [tests/unit/test_test_env_advisory.bats](../../tests/unit/test_test_env_advisory.bats): 11 tests covering the helper's name resolution (root probe, named-env probe via `resolve_testenv_path`, missing-env clean return), advisory firing with one alternative, advisory excluding the target, multi-alternative listing, opt-out, no-fire when no candidate has pytest, `--env root` skipping the advisory, M.c regression (root-only advisory still fires). *(RED 8/11 → GREEN 11/11. Full unit suite 1050/1050.)*
- [x] `_test_env_has_pytest <name>` helper replaces `_test_main_env_has_pytest` in [lib/commands/test.sh](../../lib/commands/test.sh). `<name> == "root"` preserves the M.c root-env resolution (micromamba `.pyve/envs/*` first, else `$DEFAULT_VENV_DIR/bin/python`); any other name resolves via `resolve_testenv_path "$name"` and probes its `bin/python`.
- [x] Advisory generalized: scans `root` + `list_testenv_names` (minus the target), lists every match. Message text: `Targeted env '<T>' may be missing dependencies from other env(s) that also have pytest installed: <list>` + `If your tests need a different env's stack, try one of: --env <X>, --env <Y>`. Per-the-redirect note above, the install-pytest prompt is unchanged.
- [x] Sibling test files swept for the mock rename: [tests/unit/test_test_command.bats](../../tests/unit/test_test_command.bats), [tests/unit/test_test_env_resolver.bats](../../tests/unit/test_test_env_resolver.bats), [tests/unit/test_test_env_lazy_autoprovision.bats](../../tests/unit/test_test_env_lazy_autoprovision.bats) — 14 mock occurrences renamed via `sed`. No assertion text changes were needed; all existing assertions remain valid against the new advisory shape (the M.c-shaped `--env root` text still appears when root is the sole candidate).
- [x] Update [features.md](features.md) FR-11 — silent-skip advisory paragraph rewritten to describe the M.o generalization (`root` + every declared env, naming alternatives).

**Tech-spec.md updates.** Replaced the `_test_main_env_has_pytest` row with the `_test_env_has_pytest <name>` row in the `lib/commands/test.sh` table. Updated the `test_tests` row's advisory-block description for the new scan behavior. Updated the M.o consumer-list bullet (landed). Added the new bats file to the test inventory.

**Out of scope.** Strict mode (`strict = true` → missing-dep skip = test failure). Plan doc OS-7; deferred. Polishing the install-pytest prompt with named-env hints (see story-body redirect above); future candidate.

**Version impact.** None — M.o is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.p: [Testenv-DX] `pyve testenv list` / `pyve testenv prune` [Done]

**Why.** Disk discoverability (FR-M.12). Many envs balloon disk; surfacing per-env size + last-used + provisioning state without `du -sh` matches the "feels integral" criterion.

**Approach.** Two new leaves in [lib/commands/testenv.sh](../../lib/commands/testenv.sh):

- `testenv_list` — walk the union of declared (`PYVE_TESTENVS_NAMES`) and on-disk (`.pyve/testenvs/*/`) env names; for each, print `NAME / BACKEND / SIZE / LAST-USED / STATE`. `LAST-USED` is from `.state.last_used_at` (`never` for `0`, ISO date `YYYY-MM-DD` otherwise via `_testenv_format_epoch`); `SIZE` from `du -sh`; `STATE` is `ready` (declared + on disk) / `lazy` (declared `lazy = true`, not yet provisioned) / `not provisioned` (declared non-lazy, absent from disk) / `orphaned` (on disk, not declared; the reserved `testenv` is never orphaned).
- `testenv_prune` — three modes, all disk-walking with confirmation gating that mirrors M.i.4's `purge`:
  - **no args** — remove orphans.
  - **`--unused-since <YYYY-MM-DD>`** — compare each env's `.state.last_used_at` against the cutoff; remove the strict-older set. `last_used=0` ("never used") preserves so freshly-provisioned envs are not eaten. Bad date format hard-errors before walking.
  - **`--all`** — remove every on-disk env. Distinct from `testenv purge` no-arg's config-driven iteration over `PYVE_TESTENVS_NAMES`.

**Announce-gate decisions.**

- **Last-used display:** absolute ISO date (`YYYY-MM-DD`). Cross-platform relative-time math via `date` is fiddly (BSD vs GNU); ISO is portable.
- **`--unused-since` format:** ISO date only. No relative durations (`30d` / `1w`) — defer to a polish pass if real friction surfaces.
- **State column:** `ready` / `lazy` / `not provisioned` / `orphaned`. **Stale** (manifest-sha mismatch) explicitly deferred — M.p's `.state` consumption stays read-mostly; a `stale`-aware story can land later.
- **`prune --all` vs `testenv purge` no-arg:** kept as separate surfaces with the **disk-driven** vs **config-driven** distinction explicit in the help heredoc.

**Tasks**

- [x] Failing tests first in [tests/unit/test_testenv_list_prune.bats](../../tests/unit/test_testenv_list_prune.bats): 16 tests covering `list` over the empty / ready / lazy / orphaned / conda / never-used / not-provisioned cases plus header columns; `prune` orphan mode (skips declared + reserved `testenv`, info-when-empty); `prune --unused-since` (removes-older, preserves never-used, rejects bad date format); `prune --all --force`; `--help` documents both leaves; unknown-flag hard-error. *(RED 15/16 → GREEN 16/16 after a single fixture epoch correction. Full unit suite 1066/1066.)*
- [x] `testenv_list` + `testenv_prune` leaves in [lib/commands/testenv.sh](../../lib/commands/testenv.sh), plus four private helpers: `_testenv_list_all_names` (bash-3.2-safe dedup via string-membership; no `declare -A`), `_testenv_list_one_row` (per-row formatting + state classification), `_testenv_format_epoch` (epoch → ISO date, cross-platform), `_testenv_parse_iso_date` (ISO date → epoch). Dispatcher wired with new `list` / `prune` arms; the `prune` sub-parser captures `--unused-since <date>` / `--all` / `--force` into a `prune_args[]` array forwarded to the leaf.
- [x] Per-leaf help blocks — **deferred per the announce-gate decision** to the existing Future story for per-leaf help functions in namespace commands. The namespace `--help` heredoc was updated with usage + behavior bullets covering both new leaves.
- [x] Update [tech-spec.md](tech-spec.md) testenv namespace table — added five rows (`testenv_list`, `_testenv_list_all_names` / `_one_row`, `testenv_prune`, `_testenv_format_epoch` / `_parse_iso_date`); updated the consumer-list bullet for M.p (landed); added the new bats file to the test inventory.

**Features.md updates.** FR-11's `.state` per-env-file bullet extended to cite M.p's consumption. Two new bullets describe `pyve testenv list` and `pyve testenv prune` with the full mode catalog + the disk-vs-config distinction from `testenv purge`.

**Out of scope.** Stale-state detection (manifest_sha256 mismatch) — future candidate. Per-leaf `show_<leaf>_help` functions — covered by the existing Future story for the namespace-wide refactor. Relative-time displays / durations — defer to polish pass. `docs/site/testing.md` documentation — folds into M.s.

**Version impact.** None — M.p is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.q: [Testenv-DX] `pyve lock --env <name>` / `--all` extension [Done]

**Why.** Production concern PC-2: conda-backed testenvs need deterministic resolution (no conda-forge drift across time). `pyve lock` already handles the main env; extend to per-env locking for conda-backed testenvs.

**Approach.** Factored `lock_environment` in [lib/commands/lock.sh](../../lib/commands/lock.sh) into a thin dispatcher + four helpers. Pre-M.q the function held the main-env body inline; that body moved into `_lock_main_env` so `--all` can reuse it without duplication. New private helpers `_lock_one_env`, `_lock_env_lock_path`, `_lock_all_conda_testenvs` deliver the per-env surface.

- `pyve lock` (no args) → `_lock_main_env` (existing behavior preserved verbatim).
- `pyve lock --env <name>` → `_lock_one_env "$name"`. Loads `read_testenv_config` (idempotent). Validates: rejects `root` (with a "use `pyve lock` no-args" hint), rejects undeclared names (with a `[tool.pyve.testenvs]` hint), rejects non-`micromamba` backends after resolving `inherit` via `_testenv_resolve_backend`, rejects missing-`manifest` declarations + missing manifest files on disk, requires `conda-lock` on PATH. Invokes `conda-lock -f <manifest> -p <platform> --lockfile <out>` where `<out>` = `_lock_env_lock_path <manifest>` (`tests/env.yml` → `tests/env-lock.yml`, strips `.yml`/`.yaml`, appends `-lock.yml`).
- `pyve lock --all` → subshell-wrapped `_lock_main_env` (so its `exit` paths don't kill iteration) + `_lock_all_conda_testenvs`. The latter iterates `PYVE_TESTENVS_NAMES`, skips non-`micromamba` backends, calls `_lock_one_env` per env. Per-env failures `warn` and accumulate into a non-zero return; iteration always completes. Venv-backed testenvs are skipped silently — they live outside conda-lock's scope.

**Test infrastructure note (debugging tax).** First bats run hung because `unknown_flag_error` lives in `pyve.sh` (not in any `lib/`) — the unknown-flag arm in lock.sh's parser called a "command not found" function, and the parser looped on the unshifted arg. Fix: stubbed `unknown_flag_error` in the test's `setup()` to a clean `log_error + exit 1`. This is a class of bug that will recur for any future lib/commands test exercising the unknown-flag arm; the existing `tests/unit/test_unknown_flag.bats` sidesteps it by shelling out to `$PYVE_SCRIPT` (full sourcing). A class-level fix — moving `unknown_flag_error` into `lib/utils.sh` so the standard test sourcing picks it up — is a candidate Future story.

**Tasks**

- [x] Failing tests first in [tests/unit/test_lock_per_env.bats](../../tests/unit/test_lock_per_env.bats): 12 tests covering `--env <conda-name>` happy path with assertions on `conda-lock` argv (manifest + `--lockfile` sibling), `--env=<name>` `=` form, `--env <venv-name>` rejected with backend hint, `--env <undeclared>` rejected with config hint, `--env root` rejected with `pyve lock` guidance, `--env <conda-name>` with no `manifest` declared / missing manifest file both hard-error, `--all` iterates main + conda-backed envs (skipping venv), today's `pyve lock` (no args) + `--check` behavior preserved, unknown-flag still errors. *(Full unit suite 1078/1078.)*
- [x] `lock_environment` extension — dispatcher + `_lock_main_env` extraction + three M.q helpers (`_lock_one_env`, `_lock_env_lock_path`, `_lock_all_conda_testenvs`). `unknown_flag_error` allowlist updated.
- [x] Update [tech-spec.md](tech-spec.md) lock command section: replaced the single-row `lock_environment` description with five rows (dispatcher + the four helpers); updated the cross-command-helpers paragraph for M.q's `testenvs.sh` calls; added the M.q consumer-list bullet (landed); added the new bats file to the test inventory.
- [x] Update [features.md](features.md) flag inventory: two new rows (`--env <name>` and `--all` under `pyve lock`).

**Out of scope.** Lock-file format change (continue `conda-lock` default); locking pip-installed-into-conda mixed envs; `pyve lock --check --env <name>` (per-env staleness check) — defer to a polish pass; moving `unknown_flag_error` into `lib/utils.sh` (Future story candidate per the debugging-tax note above).

**Version impact.** None — M.q is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.r: [Testenv-DX] Matrix execution — `pyve test --env a,b,c` (serial) [Done]

**Why.** UC6 (matrix testing). The same suite against multiple envs, selectable individually or as a set.

**Approach.** Comma-separated `--env` value parsed into a list; each env resolved via M.m; runs sequentially; exit code aggregates as worst-case (any failure → non-zero).

**Correction (at execution).** The plan said "`_test_parse_args` extension" — but there is no `_test_parse_args` function in [lib/commands/test.sh](../../lib/commands/test.sh); the parser is inline in `test_tests`, per the M.m note ("no `_test_parse_args` extraction — kept the existing shape for blast-radius hygiene"). Extended the inline parser, then factored the per-env body into a new private helper `_test_run_one_env` so the matrix loop can call it inside a subshell without losing the single-env exec contract.

**Tasks**

- [x] Failing tests first in [tests/unit/test_test_env_matrix.bats](../../tests/unit/test_test_env_matrix.bats): 10 tests covering single-env behavior preserved (M.m regression — no matrix header), two-env sequential run, `--env=a,b` `=` form, per-env section header order matches CSV order, one-env-fails aggregate non-zero, both-fail returns the highest fail code, first-env failure does not halt the second, undeclared-name-in-list hard-errors, legacy `--env main,smoke` caught with M.e migration hint, `.state.last_used_at` touched on every env in matrix. *(RED 8/10 → GREEN 10/10. Full unit suite 1088/1088.)*
- [x] Inline `--env` parser in `test_tests` ([lib/commands/test.sh](../../lib/commands/test.sh)) extended to split CSV via `IFS=',' read -r -a env_targets` (per-call IFS, not `local IFS=','` — the latter leaks into the rest of the function and corrupts `"$*"` expansions; caught the hard way when `--env root` started joining run_command's argv with commas).
- [x] Per-env body factored into `_test_run_one_env <name> <explicit> [args...]` — identical behavior to pre-M.r single-env path (legacy `main` catch, `root` short-circuit, name validation, conda gate, lazy auto-provision, pytest install prompt, silent-skip advisory, `.state` touch, exec).
- [x] Matrix dispatch in `test_tests`: when `${#env_targets[@]} -ge 2`, iterate with `printf '\n=== Env: %s ===\n' "$one"` per env, run `_test_run_one_env` in a subshell (so per-env `exit` / `exec` doesn't kill iteration), aggregate worst-case rc, `exit $rc` at the end. Matrix path exports `PYVE_NO_TESTENV_ADVISORY=1` inside each subshell — the M.o cross-env "you might have meant X" hint is noise when the user explicitly listed multiple envs.
- [x] Update [tech-spec.md](tech-spec.md): `test_tests` row rewritten for the matrix dispatcher + the `_test_run_one_env` worker (new row added immediately below); M.r consumer-list bullet (landed); new bats file added to test inventory.
- [x] Update [features.md](features.md) FR-11 — new bullet for the matrix form documenting per-env header, exit-aggregation rule, no-halt iteration, M.o advisory suppression, and the `--parallel` out-of-scope marker.
- [ ] Document in `docs/site/testing.md` (folds into M.s sweep per its existing scope).

**Out of scope.** `--parallel` execution. Plan doc OS-4; deferred.

**Version impact.** None — M.r is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

---

### Story M.s: [Testenv-DX] Docs sweep — named testenvs across user-facing docs [Done]

**Why.** The bundle introduces a substantial new surface (config schema, named envs, multi-backend, lazy provisioning, matrix). User-facing docs need a coherent story before release; piecemeal ride-along docs would fragment.

**Approach.** Single consolidated docs pass:

- [docs/specs/features.md](features.md) — new **FR-11a (or successor number): Named test environments** documenting the `[tool.pyve.testenvs]` DX contract as a first-class feature requirement. Schema (default + per-env `backend` / `requirements` / `extra` / `manifest` / `lazy`); reserved names (`root`, `testenv`); precedence; what happens with no config block. This is the source of truth for the DX surface; user-facing docs link here for canonical detail.
- `docs/site/testing.md` — new "Named test environments" section with the full config schema; updated "Choosing which environment runs your tests"; same-file manifest pattern (UC4); lazy provisioning; matrix.
- `docs/site/usage.md` — `pyve testenv {init,install,purge,run,list,prune}` reference updated with name argument; `pyve test --env <name>` reference; `pyve lock --env`/`--all` reference.
- `docs/site/backends.md` — note that named testenvs can use conda backend independent of main env.
- `README.md` — Testing section: mention that `[tool.pyve.testenvs]` in `pyproject.toml` is the canonical declarative config for named test environments (state lives in `.pyve/testenvs/<name>/`); link to the named-testenvs material in testing.md for detail; no full duplication.
- `docs/project-guide/templates/artifacts/pyve-essentials.md` — Pyve Essentials section: acknowledge "two envs" is now the *minimum*; named envs are an opt-in extension; LLM workflow rules updated for `pyve test --env <name>` and `pyve testenv install <name>`.

**Tasks**

- [x] Audit and update the six files above. *(Six edits per the bullet list. FR-11a "Named Test Environments" added to features.md immediately after FR-11; testing.md gained a "Named test environments" section between Testenv lifecycle and "Choosing which environment runs your tests" plus updates to the two-env model, lifecycle (now 6 leaves: list/prune added), advisory text (M.o generalization), conda backend notes, lock --env / --all, and matrix execution; usage.md `pyve test` and `testenv <subcommand>` sections rewritten for the v2.8 surface, `lock` section gained `--env`/`--all`, `--keep-testenv` description updated; backends.md "Testing on …" subsections (venv and micromamba) call out per-env backend independence + lock --env; README.md "The dev/test runner environment" paragraph updated for the v2.8 layout and named envs; pyve-essentials.md template Workflow-rules block rewritten for "at least two" envs with named-env routing examples, LLM-internal testenv-init guidance, and the v2.8 layout admonition.)*
- [x] Verify all internal links resolve (`mkdocs build --strict`). *(Pass; the only output was a vendor "Material for MkDocs 2.0" banner from `mkdocs-material` and the build-completed line. No warnings on cross-doc links / internal anchors. mkdocs and plugins were installed into the legacy `.pyve/testenv/venv/` for the check — the local repo hasn't been migrated to the v2.8 layout yet.)*
- [x] No code changes in this story.

**Out of scope.** `migration.md` — bundle is purely additive (rename pre-shipped in M.e); no new migration entries needed.

**Note on `pyve-essentials.md` template.** This file lives under `docs/project-guide/templates/artifacts/` which is gitignored (project-guide install output, regenerated by `project-guide update`). The local edit is authoritative for this session's LLM context but will be overwritten on the next `project-guide update` unless first marked overridden via `project-guide override` or filed upstream against the project-guide repo. The phase-M cadence has been editing this template in place across M.a / M.h.4 / M.s; the developer may want to consolidate by filing an upstream PR after the testenv-DX bundle ships at v2.8.0.

**Version impact.** None — M.s is part of the testenv-DX bundle, which ships unversioned during work and releases as a single `v2.8.0` at M.t.

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

### Story ?.?: Generalize testenv → named environments with `purpose:` attribute (Phase N candidate) [Planned]

**Motivation.** The testenv-DX bundle (M.f–M.t) introduced named, multi-backend, multi-manifest **test** environments. Looking at the model that emerged — `[tool.pyve.testenvs.<name>]` with per-env `backend`/`manifest`/`requirements`/`lazy`/`extra`, lock file at `.pyve/testenvs/<name>/.lock`, `.state` file per env, `--env <name>` selector — none of it is actually testing-specific. The same mechanism cleanly hosts utility envs (LLM/project-guide tooling, formatters, generators) and could host alternate run envs (multiple deployment targets). The `test` prefix on every identifier is an accidental holdover from when pyve only knew about one extra env.

The driving artifact for the redesign is [docs/specs/pyve-environment-dependencies-template.md](pyve-environment-dependencies-template.md) — a template for the formal per-repo environment-dependencies document. It encodes the generalized model already: every env has a `purpose: {run, test, utility, temp}` attribute, the root env is `purpose: utility` by default, the first test env (`testenv`) is `purpose: test` with `default: true`, and additional envs declare distinct names. The `test` overloading in pyve's vocabulary collides with that template's clean separation. Embracing the template's vocabulary inside pyve is the natural next move once the testenv-DX bundle ships.

**Approach (sketched).**

1. **Schema rename.** `[tool.pyve.testenvs.*]` → `[tool.pyve.envs.*]`. New `purpose = "test"` (or `"run"`/`"utility"`/`"temp"`) attribute per env; default is `test` for back-compat with the M.* model. Reserved names extend: `root` stays selection-only; `testenv` stays the default-test alias.
2. **CLI rename.** `pyve testenv <sub>` → `pyve env <sub>`. `pyve testenv init` becomes a Category-B sugar form that maps to `pyve env init testenv --purpose test` — keeps muscle memory and existing docs working. Same for `install`/`purge`/`run`.
3. **Path layout.** `.pyve/testenvs/<name>/` → `.pyve/envs/<name>/` (singular `envs` is already taken for micromamba main envs — pick the actual name during plan_phase; candidates: `.pyve/envs/` consolidated, or `.pyve/environments/`, or keep `.pyve/testenvs/` for back-compat and only rename at the schema/CLI layer). Legacy migration mechanism mirrors M.h's v2.7→v2.8 boundary.
4. **Helper renames.** `_testenv_*` / `*_testenv_*` → `_env_*` / `*_env_*` across `lib/testenvs.sh` (→ `lib/envs.sh`?), `lib/commands/testenv.sh` (→ `lib/commands/env.sh`), `lib/utils.sh`'s `ensure_testenv_exists`, `purge_testenv_dir`, `testenv_paths`. Roughly ~12 helpers + ~1000 tests touched.
5. **`pyve test --env <name>` resolver** stays — the surface was named `--env` from the start, so no rename needed there. The mental model just gets cleaner: any `purpose: test` env is selectable; non-`purpose: test` envs hard-error with a hint pointing at the appropriate command (`pyve env run <name>` for `purpose: utility`, etc.).
6. **Documentation lift.** Adopt the §2 vocabulary (purpose / structured attributes / dependency source classes) from the template doc into `features.md` + `tech-spec.md`. The template doc itself becomes a first-class deliverable: ship `pyve-environment-dependencies-template.md` to the `docs/project-guide/templates/artifacts/` tree so `project-guide init` can scaffold a concrete `pyve-environment-dependencies-repo_<name>.md` for each project.

**Backward compatibility.** Category-B-friendly. Every legacy form gets a precise hard-error pointing at the new form:
- `pyve testenv init` → "renamed: use `pyve env init` (default `--purpose test`)" — and/or kept as silent sugar if the Category-A vs B decision in [project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md) judges this rename high-traffic enough to warrant the legacy form continuing to work.
- `[tool.pyve.testenvs.*]` in pyproject.toml → Python helper emits a warning and reads the section as if it were `[tool.pyve.envs.*]` with implicit `purpose = "test"`.

**Why deferred to Phase N (not folded into M.\*).** Pivoting the conceptual frame mid-bundle would leave half the M.\* surface speaking the old vocabulary — features.md / tech-spec.md sections from M.g–M.h reference `testenvs`, the eight M.\* test files all assert against `[tool.pyve.testenvs.*]`, and the partially-written M.l–M.s stories build on the M.f schema. Cleaner timing: finish M.\* on the current naming, ship `v2.8.0` at M.t, then plan_phase a coherent Phase N rebrand that lands the rename + the legacy catches + the template-doc adoption as one diff.

**Phase ordering note.** The pre-existing Phase N plan moves to Phase O when this story is promoted; the new Phase N takes its slot. Recorded here so the displacement is visible before plan_phase is run.

**Tasks** (sketched; full breakdown belongs in plan_phase):

- [ ] Decide path layout (rename `.pyve/testenvs/` vs hold) — substantive backward-compat decision.
- [ ] Decide Category A (silent sugar) vs B (hard-error catch) per legacy form — likely A for `pyve testenv *` (high-traffic, in every doc), B for everything else.
- [ ] Schema rename in [lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py); add `purpose` field with `test` default; emit migration warning for `[tool.pyve.testenvs.*]`.
- [ ] CLI rename: new `lib/commands/env.sh` (or in-place rename of `testenv.sh`); legacy `pyve testenv` becomes a thin sugar wrapper or Category-B catch per the prior decision.
- [ ] Helper renames + sweep tests.
- [ ] Adopt §2 vocabulary in [features.md](features.md) + [tech-spec.md](tech-spec.md).
- [ ] Ship [docs/specs/pyve-environment-dependencies-template.md](pyve-environment-dependencies-template.md) to `docs/project-guide/templates/artifacts/` so `project-guide init` scaffolds it.
- [ ] Migrate this repo's own enumeration: produce `pyve-environment-dependencies-repo_pyve.md` from the template as the dogfood instance.

**Cross-reference.** The driving template is [docs/specs/pyve-environment-dependencies-template.md](pyve-environment-dependencies-template.md) — read §2 (Conventions & Terminology) before plan_phase to align on vocabulary.

---
