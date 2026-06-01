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
