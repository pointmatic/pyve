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



## Phase N: Pyve 3.0 — Plugin Architecture & Named Envs

**Theme.** Generalize Pyve from a Python-only virtual-environment manager into a declarative, polyglot project-environment orchestrator. Introduce the canonical root-level `pyve.toml` manifest with `[env.<name>]` blocks carrying `purpose ∈ {run, test, utility, temp}`; re-seat the Python ecosystem as the first reference plugin behind a backend-provider contract; ship Node/SvelteKit as the second reference plugin; compose `.envrc`, `pyve check`, `pyve status`, and `pyve purge` across plugins and envs; introduce `pyve deploy` as an artifact-materialization hook. Driving artifact: [phase-n-plugin-architecture-named-envs-plan.md](phase-n-plugin-architecture-named-envs-plan.md). Concept input: [phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md).

**Structure — read before drafting any Phase N story.** Phase N is split into **8 subphases** because of its size. Stories are authored **one subphase at a time** — each subphase's stories get drafted in its own `plan_production_phase` session immediately before that subphase's implementation begins. This planning session drafted only **Subphase N-1**; N-2 through N-8 carry descriptions only. Subphase IDs are arabic-numeral-hyphenated (`N-1`, `N-2`, …) and are **structural markers in this file, not part of the story-ID scheme**. Story letters (`N.a`, `N.b`, …) continue monotonically **across subphases** — if N-1 ends at `N.j`, N-2 starts at `N.k`. Subphase headings in this file use `##` (same level as the phase heading) per the project convention.

**Two release tags (exception to Version Cadence).** Phase N ships **two** releases — the only post-1.0 phase to do so:

- **v3.0.0** at the end of Subphase N-7 (after the architectural cutover).
- **v3.1.0** at the end of Subphase N-8 (UX visual refinement + hard migration gate).

Within each subphase, stories run unversioned during work; the subphase contributes to its assigned release bundle. **No intermediate release tags between subphases within a bundle.**

---

## Subphase N-1: Declarative `pyve.toml` manifest with `envs`/`purpose:` vocabulary

Introduce root-level `pyve.toml` as the canonical, stack-neutral manifest with `[env.<name>]` blocks; rename `testenvs → envs` with `purpose` attribute; ship the deterministic `pyve self migrate` command; add the v3.0 soft migration banner; preserve v3.0-only read-compat for legacy `[tool.pyve.testenvs.*]` and `.pyve/config`. This subphase is the foundation everything else builds on. Full detail per story below; bundles into **v3.0.0** with N-2 through N-7.

### Story N.a: `pyve.toml` schema + Python TOML helper [Planned]

**Motivation.** v3.0 introduces a single canonical declarative manifest at the repo root: `pyve.toml`. This story lays the schema and parse foundation so every subsequent N-1 story can read/write the v3 shape. No CLI surface change in this story.

**Tasks**

- [ ] Define `pyve.toml` schema in [tech-spec.md](tech-spec.md): `[project]`, `[env.<name>]` with `purpose` / `backend` / `path` / structured attributes (`app_type`, `frameworks`, `languages`); schema-version key `pyve_schema = "3.0"`.
- [ ] New `lib/pyve_toml_helper.py` — TOML read/parse mirroring [lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py); exposes the same Bash-callable surface.
- [ ] New `lib/manifest.sh` — Bash shim over the Python helper: `manifest_load`, `manifest_get_env`, `manifest_list_envs`, `manifest_get_purpose`, etc.
- [ ] Bats unit tests for round-trip parse + every documented schema field.
- [ ] No CLI dispatcher changes — covered in later stories.

### Story N.b: `lib/envs.sh` + `lib/commands/env.sh` rename (`testenvs` → `envs`) [Planned]

**Motivation.** The `testenvs` vocabulary is an accidental holdover from when Pyve only knew about one extra env. v3.0 generalizes to `envs`. This story is the source-tree rename + helper-name sweep; the user-facing CLI rename lands in Story N.c.

**Tasks**

- [ ] Rename [lib/testenvs.sh](../../lib/testenvs.sh) → `lib/envs.sh`; update the explicit `source` line in [pyve.sh](../../pyve.sh) (no glob sourcing per [project-essentials.md](project-essentials.md)).
- [ ] Rename [lib/commands/testenv.sh](../../lib/commands/testenv.sh) → `lib/commands/env.sh`; update the explicit `source` line in [pyve.sh](../../pyve.sh).
- [ ] Rename helper functions: `_testenv_*` → `_env_*`, `testenv_*` → `env_*`, `*_testenv_*` → `*_env_*`; namespace dispatcher `testenv_command` → `env_command` (Story N.c registers the new dispatcher arm).
- [ ] Function-name collision check (per [project-essentials.md](project-essentials.md) F-11 rule): grep for `env`, `env_init`, `env_install`, `env_run`, `env_purge` as bare commands invoked by Pyve; confirm zero shadow risks. (`env` itself is a POSIX utility but is not invoked by Pyve internally — verify with `grep -nE '(\$\(|\`|^|\s|;|\|\|?)env\s' pyve.sh lib/*.sh lib/commands/*.sh`.)
- [ ] Sweep Bats tests: ~1000 assertions touching old function names; update to new names. Test scripts that source `lib/testenvs.sh` directly need their path updated.
- [ ] Sweep `_testenv_paths`, `ensure_testenv_exists`, `purge_testenv_dir` and related shared helpers in [lib/utils.sh](../../lib/utils.sh) to `_env_paths`, etc.

### Story N.c: `pyve env` CLI dispatcher + `pyve testenv` legacy sugar [Planned]

**Motivation.** Register the new `pyve env <sub>` namespace and keep the existing `pyve testenv <sub>` working as legacy sugar through the v3.x deprecation window.

**Tasks**

- [ ] Add `env)` arm to [pyve.sh](../../pyve.sh)'s case dispatcher invoking `env_command "$@"`.
- [ ] Implement `pyve testenv` as a **Category A delegation wrapper** (per [project-essentials.md](project-essentials.md) deprecation policy, with the documented exception — `pyve testenv` is high-traffic enough that hard-error breakage is the worse outcome). Wrapper prints a `deprecation_warn` once per shell, then re-dispatches to `env_command "$@"`.
- [ ] `pyve testenv --help` and `pyve env --help` show identical content with a one-line "renamed from `pyve testenv`" note on the legacy form.
- [ ] Bats tests: every `pyve testenv <sub>` invocation works exactly as before; deprecation warning fires once per shell.

### Story N.d: `purpose:` attribute + selector semantics [Planned]

**Motivation.** The `purpose: {run, test, utility, temp}` attribute is the cornerstone of the v3 env model — it lets one mechanism host test envs, utility/dev-tooling envs, run/runtime envs, and ephemeral envs without overloading "test."

**Tasks**

- [ ] Extend [lib/manifest.sh](../../lib/manifest.sh) (from N.a) with `manifest_get_purpose <env>` returning one of `run | test | utility | temp`.
- [ ] Default-purpose rules: env name `testenv` → `purpose = "test"`; env name `root` → `purpose = "utility"`; otherwise → `purpose = "utility"`. Explicit `purpose = ...` always wins.
- [ ] `pyve test --env <name>` (existing surface) restricts to `purpose: test` envs; selecting a non-`test` env hard-errors with a precise hint (`pyve env run <name>` for `purpose: utility`, etc.).
- [ ] Update [features.md](features.md) and [tech-spec.md](tech-spec.md) sections covering the env model.
- [ ] Bats tests for each purpose's default-rule + the `--env` selector behavior.

### Story N.e: `pyve init` writes `pyve.toml` on fresh projects [Planned]

**Motivation.** Wire `pyve init` to scaffold `pyve.toml` for fresh projects. **Existing v2-configured projects are not auto-migrated by `pyve init`** — they hit the soft migration banner (Story N.h) and are directed to `pyve self migrate` (Story N.g). This keeps `pyve init` semantically clean.

**Tasks**

- [ ] `pyve init` (no `pyve.toml` and no v2 sources) writes a fresh `pyve.toml` with `[project]`, `[env.root]` (`purpose = "utility"`), and (when a Python interpreter is selected during init) `[env.testenv]` (`purpose = "test"`, `default = true`).
- [ ] `pyve init` (no `pyve.toml` but v2 sources detected) prints the soft migration banner from Story N.h and exits with a hint pointing at `pyve self migrate`; does **not** auto-migrate.
- [ ] `pyve init` (existing `pyve.toml`) is a refresh: re-validates the manifest, updates managed files, leaves the manifest content alone.
- [ ] Remove the `.pyve/config` write path from `pyve init`; legacy YAML is read-only from v3.0 onward (Story N.i).
- [ ] Bats integration tests for each of the three branches.

### Story N.f: State directory final path — `.pyve/testenvs/<name>/` decision [Planned]

**Motivation.** The v3 state layout needs a decided path. Candidates: consolidate under `.pyve/envs/` (but `.pyve/envs/` is currently micromamba's main-env namespace — needs disambiguation); `.pyve/environments/`; or keep `.pyve/testenvs/` and only rename at the CLI/schema layer. **Decision is made in this story's first task.** Actual relocation happens inside `pyve self migrate` (Story N.g).

**Tasks**

- [ ] **Decision task** — pick the final v3 state directory path. Document the choice + rationale in this story body before continuing. Reference the concept doc § 2 candidates ([phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md)).
- [ ] Update [tech-spec.md](tech-spec.md) with the chosen path + the v2 → v3 path-mapping table.
- [ ] Update all path-construction helpers in [lib/envs.sh](../../lib/envs.sh) (from N.b) to use the chosen path. Tests sweep to match.
- [ ] Confirm `is_asdf_active()` + `.envrc` template generation (per [project-essentials.md](project-essentials.md)) still work with the new path.

### Story N.g: `pyve self migrate` — v2 → v3 migration command [Planned]

**Motivation.** The load-bearing migration story. Deterministic, idempotent command that brings any v2.7/v2.8 project to v3 in one invocation: writes `pyve.toml` from legacy artifacts, backs them up, runs `pyve init --force` to rebuild envs at the new state layout. This is the path the soft banner (N.h) and (eventually) the v3.1 hard gate (N-8) point users to.

**Tasks**

- [ ] Implement `self_migrate()` in [lib/commands/self.sh](../../lib/commands/self.sh) (per the *Namespace commands are single files* rule in [project-essentials.md](project-essentials.md)).
- [ ] Detection step: returns clean if no v2 configuration is present (no `.pyve/config`, no `[tool.pyve.testenvs.*]`, no `.pyve/testenvs/`). Otherwise proceed.
- [ ] Manifest generation: translate `.pyve/config` (YAML) + each `[tool.pyve.testenvs.<name>]` block into the v3 `[env.<name>]` shape in a new `pyve.toml`. Former testenv blocks get `purpose = "test"`; the main-env block becomes `[env.root]` with `purpose = "utility"`.
- [ ] Backup step: move `.pyve/config`, the `[tool.pyve.testenvs.*]` section of `pyproject.toml`, and the old `.pyve/testenvs/` tree into `.pyve/.v2-legacy/` (preserving structure). Keep for one release cycle so the user can roll back.
- [ ] Rebuild step: invoke `pyve init --force` to rebuild envs at the new state layout (decided in N.f).
- [ ] Summary print: list what was migrated, where the backup lives, and a `pyve check` recommendation to verify.
- [ ] Flags: `--dry-run` (print plan without writing); `--no-rebuild` (write `pyve.toml` + backup only, skip `init --force`).
- [ ] Idempotency: re-running `pyve self migrate` on an already-migrated project is a no-op with a clean message.
- [ ] `show_self_migrate_help` function added to [lib/commands/self.sh](../../lib/commands/self.sh) per the per-command help convention.
- [ ] Bats integration tests: v2.7.x → v3 happy path; v2.8.x → v3 happy path; idempotency; `--dry-run`; `--no-rebuild`; rollback from `.pyve/.v2-legacy/`.

### Story N.h: Soft migration banner on `pyve <cmd>` in v2-configured projects [Planned]

**Motivation.** Every `pyve <cmd>` invocation in a v2-configured project should nudge the user toward migration without forcing it. Soft in v3.0; the hard gate replaces this in N-8.

**Tasks**

- [ ] Pre-dispatch hook in [pyve.sh](../../pyve.sh)'s `main()` (before the case dispatcher). Detection helper from Story N.g returns "v2-configured" iff legacy sources present AND no `pyve.toml`.
- [ ] One-shot soft banner (per shell session, per cwd): *"Pyve v3 detected v2 configuration. Run `pyve self migrate` to upgrade — legacy support ends at v3.1."*
- [ ] Suppress under `PYVE_QUIET=1` or `--quiet` (existing primitive in [lib/ui/core.sh](../../lib/ui/core.sh)).
- [ ] Per-session memoization: write a sentinel under `$XDG_STATE_HOME/pyve/migrate-banner-shown` (or fallback `$HOME/.local/state/pyve/`) keyed by project root, so the banner doesn't repeat for the same project in the same shell.
- [ ] After the banner, control passes to the existing dispatcher; the command continues to execute via the read-compat layer (Story N.i).
- [ ] Bats tests: banner appears once per shell session; suppressed under `PYVE_QUIET`; does not fire in a v3-configured project; does not fire in a no-config bare directory.

### Story N.i: Read-compat layer — v3.0 reads legacy sources [Planned]

**Motivation.** v3.0 still reads `[tool.pyve.testenvs.*]` and `.pyve/config` so v2-configured projects continue to work without migration. This is **v3.0-only**; Subphase N-8 removes the layer.

**Tasks**

- [ ] In [lib/manifest.sh](../../lib/manifest.sh): when `pyve.toml` is absent but legacy sources exist, parse them and emit a synthesized in-memory `pyve.toml`-equivalent so the rest of Pyve sees the v3 shape.
- [ ] Each legacy-source read emits a one-shot `deprecation_warn` per shell.
- [ ] Bats tests: a v2.8.0 project layout (sources present, no `pyve.toml`) installs cleanly under v3.0; `pyve test --env <name>` works against legacy `[tool.pyve.testenvs.*]`; deprecation warning fires once.
- [ ] Document the v3.0-only nature in [tech-spec.md](tech-spec.md) and flag the N-8 removal point.
- [ ] The legacy-read code path is clearly marked (e.g., `# v3.0-only: remove in N-8`) so the N-8 sweep is mechanical.

### Story N.j: Append project-essentials entries for N-1 [Planned]

**Motivation.** Capture must-know facts that surfaced during N-1 so future contributors (and future LLM sessions) don't re-derive them.

**Tasks**

- [ ] `pyve.toml` as canonical declaration; `.pyve/` = state only.
- [ ] `purpose:` vocabulary (run/test/utility/temp) + default-purpose rules.
- [ ] Category A delegation for `pyve testenv *` (the documented exception to the Category B policy).
- [ ] The v2→v3 migration model: `pyve self migrate` (deterministic), v3.0 soft banner, v3.1 hard gate.
- [ ] Read-compat window policy (v3.0 only; removed in N-8).
- [ ] Final state-directory path decision from Story N.f.
- [ ] `.pyve/.v2-legacy/` backup location.
- [ ] Skip the story entirely if N-1 surfaced no new invariants beyond what's already captured.

---

## Subphase N-2: Plugin / backend-provider contract — Python as first reference plugin

Extract the 8-hook plugin/backend-provider contract (manifest namespace, backend declaration, detection, lifecycle, activation, diagnostics, `.gitignore`, smart-purge) and re-seat the Python ecosystem behind it as the dog-food reference. No new user-facing surface; existing Python behavior preserved via the contract. Resolves **PC-1** (plugin contract input safety). Story breakdown deferred to its own `plan_production_phase` session, kicked off when N-1 ships. Bundles into **v3.0.0**.

---

## Subphase N-3: Node/SvelteKit second reference plugin

Implement the Node plugin with `pnpm`/`npm`/`yarn` backend-providers and a SvelteKit detection rule. Proves the contract generalizes beyond Python. Story breakdown deferred. Bundles into **v3.0.0**.

---

## Subphase N-4: Composed activation, diagnostics, and purge

`pyve init` materializes **all** declared envs; composes one `.envrc` with sentinel-marked plugin sections; self-heals one `.gitignore`. `pyve check` and `pyve status` aggregate per-plugin/per-env with worst-severity exit-code roll-up. `pyve purge` composes created-vs-authored inventory from each plugin. Monorepo `path` support lands here. Resolves **PC-2** (`.envrc` refresh safety) and **PC-4** (no-Python noise + plugin latency budget). Story breakdown deferred. Bundles into **v3.0.0**.

---

## Subphase N-5: `pyve deploy` lifecycle hook

Architectural scaffold for `pyve deploy [--env <name>]` as an artifact-materialization hook (pinned `docker`/`podman` image, lock bundle). Whether any provider ships in v3.0 is a v3.0-window decision (per concept doc Q6). Story breakdown deferred. Bundles into **v3.0.0**.

---

## Subphase N-6: Documentation refresh + brand alignment

`refactor_document` mode runs over [brand-descriptions.md](brand-descriptions.md) (Benefits, Technical Description, Keywords, Feature Cards — all currently flagged **NEEDS REVISION for Pyve 3.0**). Cascade refresh of [concept.md](concept.md), [features.md](features.md), [tech-spec.md](tech-spec.md), [README.md](../../README.md), mkdocs site copy. User-facing migration guide referencing `pyve self migrate`. Story breakdown deferred. Bundles into **v3.0.0**.

---

## Subphase N-7: v3.0.0 release tag

Final integration verification matrix across Python-only, Node-only, and polyglot Python+Node project shapes. `CHANGELOG.md` entry. `project-guide bump-version 3.0.0`. Homebrew formula update via the existing [.github/workflows/update-homebrew.yml](../../.github/workflows/update-homebrew.yml). **First Phase N release tag.** Story breakdown deferred.

---

## Subphase N-8: UX visual refinement + hard migration gate (post-v3.0.0)

Begins **after v3.0.0 ships**. Extends [lib/ui/](../../lib/ui/) with color and glyph primitives (TTY-detected, `NO_COLOR` respected); adds expand/collapse sections in `pyve check` / `pyve status` long-form output; structural lines between plugin sections in aggregated commands. **Migration hardening:** removes the v3.0 read-compat layer (from Story N.i); replaces the soft banner (from Story N.h) with the hard interactive gate — *"Pyve v2.x configuration is no longer supported. Ready to migrate to v3.x.x? [Y/n]"* — invoking `self_migrate()` on accept. Resolves **PC-5** (UX visual structure). Story breakdown deferred. Ships **v3.1.0** as the second Phase N release tag.

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
