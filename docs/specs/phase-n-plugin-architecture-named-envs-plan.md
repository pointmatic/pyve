# phase-n-plugin-architecture-named-envs-plan.md — Pyve 3.0 plan

**Status:** Plan doc for **Phase N — Pyve 3.0: Plugin Architecture & Named Envs**
(drafted 2026-06-01 via `plan_production_phase`).

**Companion brief / concept input:**
[phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md) —
the strategic direction document (charter expansion, requirements R1–R11,
inviolable constraints, 7 open questions). This plan doc resolves the
"what gets done in v3.0 and in what order"; the brief resolves "why."

**Anticipated version bump targets:** **v3.0.0** (major, after Subphase N-7)
and **v3.1.0** (minor, after Subphase N-8). Phase N ships **two release
tags** — the only post-1.0 phase to do so. Rationale: the visual UX
refinement (N-8) is conceptually within Phase N's architectural arc but
need not block v3.0.0 cutover.

---

## Phase N runs as 8 subphases — read this before drafting any story

Phase N is large enough that the standard "draft every story up front" pattern
breaks down. The phase is split into **8 subphases** of roughly cohesive work.
**Stories are authored one subphase at a time** — each subphase's stories are
drafted in its own `plan_production_phase` session immediately before that
subphase's implementation begins. This planning session breaks down only
**Subphase N-1**; N-2 through N-8 carry descriptions only.

**Two-release exception to the Version Cadence rule.** The standard rule is
"one phase, one bundled release at end-of-phase." Phase N breaks that rule
explicitly: Subphases N-1 through N-7 bundle into **v3.0.0**; Subphase N-8
ships separately as **v3.1.0**. This is documented as an exception, not a
new pattern. Future phases that want to repeat this shape need their own
plan-doc justification.

**Story ID rules under this layout:**

- Story letters (`N.a`, `N.b`, …) **continue monotonically across subphases**.
  Subphase N-1's last story might be `N.f`; N-2's first story is then `N.g`.
- Subphase IDs use arabic numerals with a hyphen (`N-1`, `N-2`, …) and never
  appear in story IDs. They are structural markers in `stories.md`, not part
  of the ID scheme.
- The 3-level story-ID depth limit holds: a complex story `N.b` may bundle
  into `N.b.1`, `N.b.2`, … but never `N.b.1.1`.

**Subphase headings in `stories.md`** use `##` (same level as the phase
heading) — see § *Stories.md layout* below.

---

## Subphase overview

| ID | Title | Stories drafted? | Headline scope |
|---|---|---|---|
| N-1 | Declarative `pyve.toml` manifest with `envs`/`purpose:` vocabulary | **Yes, this session** | Introduce root `pyve.toml`; rename `testenvs → envs` with `purpose ∈ {run,test,utility,temp}`; legacy read-compat for `[tool.pyve.testenvs.*]` and `.pyve/config`; `pyve testenv` CLI as legacy sugar |
| N-2 | Plugin / backend-provider contract — Python as first reference plugin | Deferred | Define the 8-hook contract; re-seat Python ecosystem behind it as the dog-food reference |
| N-3 | Node/SvelteKit second reference plugin | Deferred | Implement Node plugin with `pnpm`/`npm`/`yarn` backend-providers; proves the contract generalizes |
| N-4 | Composed activation, diagnostics, and purge | Deferred | One composed `.envrc` with sentinel-marked plugin sections; aggregated `pyve check`/`status`; composed `pyve purge`; monorepo `path` support |
| N-5 | `pyve deploy` lifecycle hook | Deferred | Architectural scaffold for `pyve deploy`; whether a provider ships in v3.0 is a v3.0-window decision |
| N-6 | Documentation refresh + brand alignment | Deferred | `refactor_document` on [brand-descriptions.md](brand-descriptions.md); cascade to `concept.md`, `features.md`, `tech-spec.md`, `README.md`, mkdocs site |
| N-7 | v3.0 release tag | Deferred | Final cross-plugin verification; CHANGELOG; `project-guide bump-version 3.0.0`; Homebrew formula update — **first Phase N release tag** |
| N-8 | UX visual refinement + hard migration gate (post-v3.0.0) | Deferred | Color, expand/collapse glyphs, structural lines via existing `lib/ui/` primitives; **flip read-compat off and add the hard migration prompt**; **second Phase N release tag (v3.1.0)** |

Subphases N-1 through N-7 ship one bundled release (**v3.0.0**); Subphase
N-8 ships separately (**v3.1.0**). Within each subphase, the standard
Version Cadence applies: stories run unversioned during work, the subphase
contributes to its assigned bundle. **No intermediate release tags between
subphases within a bundle.**

---

## Gap analysis (Post-M v2.8.0 → v3.0.0 target)

Same content as the concept doc § 9, repeated for plan-doc cohesion.

| Concern | Post-M (today) | v3.0 target | Gap closed in |
|---|---|---|---|
| Declaration home | `.pyve/config` (YAML) + `[tool.pyve.testenvs.*]` (pyproject) | Single root `pyve.toml`; `.pyve/` = state only | **N-1** |
| Named envs | Test-only (`testenvs`), `--env` selector | `[env.*]` with `purpose: run/test/utility/temp` + `path` | **N-1** |
| Backends | `venv`, `micromamba` (Python only) | + Node `pnpm`/`npm`/`yarn`; backend-provider contract | N-2, N-3 |
| Detection | `backend_detect.sh` (Python files only) | Plugin-contributed detection votes | N-2, N-3 |
| Activation | Single `.envrc`, Python-only | Composed `.envrc`, sentinel-marked plugin sections | N-4 |
| `check`/`status` | Python env only | Aggregate across envs + plugins | N-4 |
| `purge` | Python artifacts only | Composed created-vs-authored inventory | N-4 |
| Deploy | None | `pyve deploy` artifact lifecycle hook (provider may defer) | N-5 |
| Architecture | Monolithic core | Python = first reference plugin (dog-food invariant) | N-2 |
| User-facing copy | Python-centric (per [brand-descriptions.md](brand-descriptions.md) **NEEDS REVISION** flags) | Polyglot orchestration framing | N-6 |
| UX visual structure | Monochrome, no visual hierarchy | Color + expand/collapse glyphs + structural lines via `lib/ui/` | **N-8 (post-v3.0.0, ships v3.1.0)** |

---

## Feature requirements

Charter-level (from concept doc § 10):

- **R1.** Plugin/backend-provider contract is a first-class part of Pyve identity.
- **R2.** Python is the first reference plugin (dog-food invariant) — no privileged backdoor.
- **R3.** Node/SvelteKit is the second reference plugin (contract-generalization proof).
- **R4.** Zero-change for pure-Python projects: existing `pyve init` behavior preserved.
- **R5.** `pyve.toml` is the single canonical, stack-neutral manifest.

Capability-level:

- **R6.** In-tree plugins only for v3.0.
- **R7.** Multiple active plugins compose in a declared order from `pyve.toml`.
- **R8.** Per-env / per-plugin schema versioning in `pyve.toml`.
- **R9.** Composed `.envrc`, `check`, and `purge`.
- **R10.** Monorepo `path` support.
- **R11.** Preserve all inviolable constraints (concept doc § 11).

---

## Technical changes (by subphase)

**N-1 — Manifest + migration:** new `lib/pyve_toml_helper.py` (Python
helper for TOML parsing, mirroring
[lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py) shape);
`lib/manifest.sh` for read/write; v3.0-only legacy-source read paths
preserved in [lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py)
behind a deprecation gate; rename `lib/testenvs.sh` → `lib/envs.sh`;
rename `lib/commands/testenv.sh` → `lib/commands/env.sh`; legacy `pyve
testenv` dispatcher arm becomes a sugar wrapper that delegates with a
deprecation warning (Category A, per
[project-essentials.md](project-essentials.md) § *Deprecation removal
policy* — this rename is high-traffic enough to justify the Category A
exception). **`pyve self migrate`** added as `self_migrate()` in
[lib/commands/self.sh](../../lib/commands/self.sh); a soft migration
banner hook fires in [pyve.sh](../../pyve.sh)'s `main()` for every
`pyve <cmd>` invocation in a v2-configured project.

**N-2 — Plugin contract:** new `lib/plugins/` directory with the contract
definition (`lib/plugins/contract.sh`); core no longer hardcodes "venv +
micromamba" — instead loads the Python plugin which registers those
backends; backend-provider registry; lifecycle hook dispatcher.

**N-3 — Node plugin:** new `lib/plugins/node/` directory; backend-providers
for `pnpm` / `npm` / `yarn`; SvelteKit detection rule; ecosystem activation
contribution.

**N-4 — Composition:** `lib/envrc_composer.sh` (sentinel-marked section
management); aggregated `pyve check` / `pyve status` (per-plugin sections,
worst-severity exit roll-up); `pyve purge` composes created-vs-authored
inventory from each plugin.

**N-5 — Deploy:** `pyve deploy` dispatcher arm; lifecycle hook in the
contract; v3.0-window decision on whether to ship a Docker/Podman artifact
provider.

**N-6 — Docs:** `refactor_document` mode runs over
[brand-descriptions.md](brand-descriptions.md); cascade refresh of
`concept.md`, `features.md`, `tech-spec.md`, `README.md`, mkdocs site.

**N-7 — Release (v3.0.0):** integration verification matrix across
Python-only, Node-only, and polyglot Python+Node project shapes;
CHANGELOG; bump-version; Homebrew formula update via existing workflow.
**First Phase N release tag.**

**N-8 — UX visual refinement + hard migration gate (v3.1.0):** extend
`lib/ui/` with color and glyph primitives (TTY-detected, `NO_COLOR`
respected); expand/collapse sections in `pyve check` / `pyve status`
long-form output; structural lines between plugin sections in aggregated
commands. **Migration hardening:** remove the v3.0 read-compat layer
from [lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py);
replace the soft banner in `main()` with the hard interactive gate
(*"Pyve v2.x configuration is no longer supported. Ready to migrate to
v3.x.x? [Y/n]"*); accepting invokes `self_migrate()`. CHANGELOG entry;
bump-version to v3.1.0; Homebrew formula update. **Second Phase N
release tag.**

---

## Production concerns (driving design)

Five concerns surfaced during planning. Each must be addressed by the named
subphase before that subphase's exit.

### PC-1: Plugin contract input safety (resolved in N-2)

Plugins emit text into the composed `.envrc` and `.gitignore`. The
composition layer must validate plugin-emitted strings don't smuggle
shell-evaluable content (`$(...)`, backticks, unquoted `${VAR}` expansions
in dangerous positions) into `.envrc`. Define an allow-list of
direnv-stdlib functions (`PATH_add`, `export VAR=...`) plus a strict
quoting policy enforced by a `lib/envrc_composer.sh` validator.

### PC-2: Composed `.envrc` refresh safety (resolved in N-4)

Sentinel-marked sections in `.envrc` must survive partial-write/crash
scenarios. Atomic write pattern: compose to `.envrc.tmp`, validate parses
cleanly via `direnv eval`-style check, then `mv` over `.envrc`. Backup the
previous `.envrc` to `.envrc.prev` for one-step rollback. User-authored
content below the managed section is preserved by reading and re-appending.

### PC-3: Read-compat window + migration policy (resolved in N-1 soft, N-8 hard)

The v2→v3 transition uses a **two-step soft/hard migration model** with a
**short read-compat window** (one minor release):

- **v3.0 — soft.** Pyve reads legacy `[tool.pyve.testenvs.*]` and
  `.pyve/config` and continues to operate. Every `pyve <cmd>` invocation
  in a v2-configured project (legacy sources present, no `pyve.toml`)
  prints a one-shot soft migration banner:
  > *"Pyve v3 detected v2 configuration. Run `pyve self migrate` to
  > upgrade — legacy support ends at v3.1."*
  User can choose to migrate now or keep deferring through v3.0.x patches.
- **v3.1 — hard** (lands in Subphase N-8). Read-compat is removed. Any
  `pyve <cmd>` in a v2-configured project prints:
  > *"Pyve v2.x configuration is no longer supported. Ready to migrate to
  > v3.x.x? [Y/n]"*
  Accepting runs the migration. Declining hard-exits with the same prompt
  re-shown on the next invocation. The interactive `[Y/n]` keeps it
  friendlier than a flat hard-error, but the gate is mandatory — no
  further pyve operation against v2 configuration from v3.1 onward.

**Migration command** (introduced in N-1): `pyve self migrate` writes
`pyve.toml` from legacy artifacts (`.pyve/config` + `[tool.pyve.testenvs.*]`),
then performs `pyve init --force` to rebuild envs at the new state
layout. Idempotent; safe to re-run. The migration story (Story N.g) is the
load-bearing piece — read-compat is just the v3.0 grace period until users
choose to invoke it.

### PC-4: No-Python-project noise + plugin latency (resolved in N-4)

Two coupled sub-concerns:

- **No-Python noise:** when no Python surface is declared in `pyve.toml`
  **and** no Python files are detected in the project, the Python plugin
  registers but contributes nothing to `.envrc`, `check`, or `status`.
  No "Python not found" warning anywhere. Verified by a regression test
  asserting clean output on a Node-only project.
- **Plugin latency:** composed `.envrc` evaluation runs on every shell /
  direnv reload. Per-plugin latency budget: **≤ 50 ms p95** for activation
  contribution. Measured by a Bats benchmark in N-4. Plugins exceeding the
  budget block subphase exit.

### PC-5: UX visual structure (resolved in N-8, ships v3.1.0)

Today's CLI output is monochrome and visually flat — `pyve check` reads as
an undifferentiated wall of lines. **Deliberately deferred to N-8 (the
post-v3.0.0 subphase shipping v3.1.0)** so the v3.0.0 architectural cutover
isn't blocked on visual polish. v3.1.0 introduces structured visual
hierarchy via the existing `lib/ui/` primitives:

- **Color**: pass/warn/error/info palette (TTY-detected, `NO_COLOR`
  respected).
- **Expand/collapse glyphs**: `▸` for collapsed sections (default), `▾`
  expanded; user opts in via `--verbose` per existing `lib/ui/core.sh`
  `is_verbose()` gate.
- **Structural lines**: separators between plugin sections in aggregated
  `check`/`status`.

Constraint: all visual primitives stay in `lib/ui/` per the *lib/ui/ is the
extractable UX boundary* rule in [project-essentials.md](project-essentials.md).
No new pyve-specific tokens leak into the primitives.

---

## Anticipated breaking changes (negotiation result)

Walked at the approval gate with the developer; classifications below are
recorded results.

| # | Change | Classification | Mitigation |
|---|---|---|---|
| BC-1 | `.pyve/config` (YAML) retired in favor of root `pyve.toml` | Substantive | `pyve self migrate` (N.g) writes pyve.toml; v3.0 soft banner; v3.1 hard gate (PC-3) |
| BC-2 | `[tool.pyve.testenvs.*]` → `[env.*]` in pyve.toml | Substantive | Same migration path as BC-1 |
| BC-3 | `pyve testenv <sub>` CLI | **Non-breaking** (kept as legacy sugar per concept doc § 6) | Category A delegation wrapper; deprecation warning; removed in v4.0 |
| BC-4 | `.pyve/testenvs/<name>/` → new state layout (`.pyve/envs/<name>/` or similar — picked during N-1) | Substantive | `pyve self migrate` performs `pyve init --force`, which rebuilds envs at the new state layout; old paths cleared after successful rebuild |
| BC-5 | `.envrc` shape (sentinel-marked composed sections) | Substantive | Rewritten as part of the `pyve init --force` step in the migration command; user-authored content below sentinels preserved; `.envrc.prev` backup |
| BC-6 | `pyve deploy` verb introduction | Additive, non-breaking | n/a |
| BC-7 | Plugin/backend-provider contract internals | Internal architectural; user-invisible | n/a |

Any one of BC-1, BC-2, BC-4, BC-5 alone justifies the major bump.
Collectively they make v3.0.0 unambiguous.

**Anticipated version bump targets:**
- **v3.0.0** at end of Subphase N-7 (after all architectural work in
  N-1 through N-6 lands).
- **v3.1.0** at end of Subphase N-8 (UX visual refinement). All N-8
  changes are additive/visual; the minor bump is appropriate.

---

## Out of scope (deferred to later phases or roadmap)

Walk this with the developer at the approval gate — out-of-scope is a
negotiation, not a unilateral declaration.

1. **Out-of-tree plugins / third-party plugin distribution.** v3.0 ships
   in-tree plugins only (Python + Node/SvelteKit). Out-of-tree contract is
   post-3.0 roadmap. (Concept doc Q6 / R6.)
2. **Additional ecosystems** — Go, Rust, Ruby, Docker/Podman as primary
   ecosystems, Crystal, Java, etc. Roadmap, not v3.0. (Concept doc § 5.)
3. **Non-Bash plugin languages.** "Any executable satisfying a CLI
   contract" is post-3.0. (Concept doc § 5, Q7.)
4. **Windows support.** Per inviolable constraint § 11.
5. ~~Automated migration tooling — *now in scope*.~~ Revised during planning:
   `pyve self migrate` (Story N.g) is the deterministic migration command;
   it generates `pyve.toml` from legacy artifacts and rebuilds envs via
   `pyve init --force`. The LLM-assisted env-dependencies prompt remains
   the **planning** artifact (for designing a project's env layout in the
   first place); it is not a runtime migration tool. This supersedes the
   "no automated migration" line in concept doc § 12.
6. **Cloud-sync / registry push for `pyve deploy`.** `pyve deploy` produces
   shippable artifacts; pushing them is out of scope. (Concept doc § 7.)
7. **Per-leaf help functions for namespace commands** — the Future story
   in [stories.md:33](stories.md#L33). The CLI rename (testenv → env) in
   N-1 keeps the existing namespace-help shape; the per-leaf refactor lands
   in a later phase.
8. **`pyve check --fix` auto-remediation** — Future story in
   [stories.md:68](stories.md#L68). Independent of Phase N's scope.
9. **SHA256 verification of micromamba bootstrap** — Future story in
   [stories.md:74](stories.md#L74). Independent of Phase N's scope.
10. **Micromamba version pinning via `--micromamba-version`** — Future story
    in [stories.md:96](stories.md#L96). Independent of Phase N's scope.
11. **Pre-existing integration test failures** — Future story in
    [stories.md:117](stories.md#L117). Independent of Phase N's scope; if
    they masque a regression introduced in N-1, that story may get pulled
    into Phase N as an interrupt insert.
12. **Out-of-scope production-readiness item: Homebrew tap publish PAT
    hardening.** Acknowledged in Step 2; not blocking Phase N. Could be
    folded into N-7 if you want (cheap once the v3.0 cutover is otherwise
    settled).

---

## Stories.md layout (final shape for Phase N)

```
## Phase N: Pyve 3.0 — Plugin Architecture & Named Envs

<phase preamble explaining the 8-subphase structure, the two-release
exception (v3.0.0 after N-7, v3.1.0 after N-8), and that story
breakdowns happen per subphase>

## Subphase N-1: Declarative pyve.toml manifest with envs/purpose: vocabulary

### Story N.a: <name> [Planned]
### Story N.b: <name> [Planned]
…

## Subphase N-2: Plugin / backend-provider contract — Python as first reference plugin

<subphase description; no stories yet — drafted in a future plan_production_phase>

## Subphase N-3: Node/SvelteKit second reference plugin

<subphase description>

… (N-4 through N-8 same pattern)

## Subphase N-8: UX visual refinement (post-v3.0.0 — ships v3.1.0)

<subphase description; this subphase begins after v3.0.0 ships>
```

When Subphase N-2 is ready to begin, the developer runs
`plan_production_phase` again. That session drafts N-2's stories and
appends them under the existing `## Subphase N-2: …` heading, continuing
the story-letter sequence from where N-1 left off (e.g., if N-1's last
story was `N.f`, N-2's first story is `N.g`).

---

## Subphase N-1 — story breakdown (drafted this session)

N-1 introduces the single canonical declarative manifest (`pyve.toml`), the
new `envs`/`purpose:` vocabulary, the **deterministic v2→v3 migration
command**, and the v3.0 soft read-compat layer. Story order is the order
of execution.

### Story N.a: `pyve.toml` schema + Python TOML helper

Define the v3.0 `pyve.toml` schema (`[project]`, `[env.<name>]` with
`purpose`/`backend`/`path`/structured attributes). Implement the read/parse
path via a new `lib/pyve_toml_helper.py` mirroring the
[lib/pyve_testenvs_helper.py](../../lib/pyve_testenvs_helper.py) shape.
**No CLI surface change yet** — this story is the foundation everyone else
builds on. Schema-versioning key (`pyve_schema = "3.0"`) included.

### Story N.b: `lib/envs.sh` + `lib/commands/env.sh` (rename `testenvs` → `envs`)

Rename `lib/testenvs.sh` → `lib/envs.sh` and `lib/commands/testenv.sh` →
`lib/commands/env.sh`. All helper functions (`_testenv_*`, `testenv_*`,
`*_testenv_*`) get the `_env_*` / `env_*` / `*_env_*` rename. The Bats
test sweep updates ~1000 assertions touching the old names. Per
[project-essentials.md](project-essentials.md) function-naming rules, the
namespace dispatcher becomes `env_command()` and leaves are `env_init()`,
`env_install()`, `env_purge()`, `env_run()`. Function-name collision
check passes (no bash builtin or invoked binary named `env_*`).

### Story N.c: `pyve env` CLI dispatcher + `pyve testenv` legacy sugar

Register the new `pyve env <sub>` namespace in [pyve.sh](../../pyve.sh)'s
case dispatcher. Implement `pyve testenv <sub>` as a Category A delegation
wrapper (per [project-essentials.md](project-essentials.md) deprecation
policy, *with the documented exception* — this is high-traffic enough that
silent breakage is the worse outcome). The wrapper prints a `deprecation_warn`
on first invocation per shell, then re-dispatches to `pyve env <sub>`.

### Story N.d: `purpose:` attribute + selector semantics

Add `purpose: run | test | utility | temp` to each `[env.<name>]` block.
Default per-env: if env name is `testenv`, default `purpose = test`; else
default `purpose = utility`. `pyve test --env <name>` (existing surface)
restricts to `purpose: test` envs; selecting a non-test env produces a
precise error pointing at the appropriate command (`pyve env run <name>`
for utility envs). Update [features.md](features.md) and
[tech-spec.md](tech-spec.md) for the new vocabulary.

### Story N.e: `pyve init` writes `pyve.toml` on fresh projects

Wire `pyve init` to emit `pyve.toml` instead of `.pyve/config` for fresh
projects. The default scaffold contains `[project]`, `[env.root]`
(`purpose = utility`), and (if a Python interpreter is selected during
init) `[env.testenv]` (`purpose = test`, `default = true`). **Existing v2
projects are not auto-migrated by `pyve init`** — they hit the soft
migration banner (Story N.h) and are directed to `pyve self migrate`
(Story N.g). This keeps `pyve init`'s semantics clean: fresh-project
scaffolding only.

### Story N.f: State layout — `.pyve/testenvs/<name>/` → final v3 path

Pick the final state-directory path (candidates from concept doc § 2:
consolidate under `.pyve/envs/` — but `.pyve/envs/` is currently
micromamba's main-env namespace, so this needs disambiguation;
alternatives: `.pyve/environments/`, keep `.pyve/testenvs/` for back-compat
and only rename at the CLI/schema layer). Decision goes into the story's
first task. The actual relocation of state happens inside `pyve self
migrate` (Story N.g) via `pyve init --force`; this story is purely the
**path-decision + layout-update** at the code level.

### Story N.g: `pyve self migrate` — v2 → v3 migration command

The load-bearing migration story. New sub-command `pyve self migrate`
that:

1. Detects v2 configuration: `.pyve/config` (YAML),
   `[tool.pyve.testenvs.*]` in `pyproject.toml`, `.pyve/testenvs/<name>/`.
   Exits cleanly if none present.
2. **Generates `pyve.toml`** by translating `.pyve/config` + every
   `[tool.pyve.testenvs.<name>]` block into the v3 `[env.<name>]` shape.
   Adds `purpose = "test"` to former testenv blocks; adds `[env.root]`
   with `purpose = "utility"` for the main env reflected in `.pyve/config`.
3. **Backs up legacy artifacts** to `.pyve/.v2-legacy/` for one release
   cycle so the user can roll back.
4. Runs `pyve init --force` to rebuild envs at the new state layout
   (decided in Story N.f).
5. Prints a summary: what was migrated, where the backup lives, what to
   verify.

Idempotent — running `pyve self migrate` again on an already-migrated
project is a no-op with a clean message. Flags: `--dry-run` (print plan
without writing); `--no-rebuild` (write `pyve.toml` only, skip
`init --force`).

Per the *Namespace commands are single files* rule in
[project-essentials.md](project-essentials.md), the implementation lives
in [lib/commands/self.sh](../../lib/commands/self.sh) as `self_migrate()`.

### Story N.h: Soft migration banner on `pyve <cmd>` in v2-configured projects

Hook every `pyve <cmd>` dispatch (in [pyve.sh](../../pyve.sh)'s `main()`)
with a pre-check: if v2 configuration is detected (per Story N.g's
detection helper) and no `pyve.toml` exists, print a one-shot soft banner
(per shell, per cwd):

> *"Pyve v3 detected v2 configuration. Run `pyve self migrate` to
> upgrade — legacy support ends at v3.1."*

The command then continues to execute via the read-compat layer
(Story N.i). The banner is suppressed under `PYVE_QUIET=1` or `--quiet`
(if available). Bats regression test asserts banner appears once per
shell session and exactly once.

### Story N.i: Read-compat layer — v3.0 reads legacy sources

Read-only compatibility shims for v3.0: when `pyve.toml` is absent but
`[tool.pyve.testenvs.*]` or `.pyve/config` exists, parse them and emit a
synthesized in-memory `pyve.toml` equivalent so commands like
`pyve test --env <name>` keep working. **This is v3.0-only**; Subphase
N-8 removes the layer and replaces it with the hard migration gate
(PC-3). Bats regression tests cover: a v2.8.0 project installs cleanly
under v3.0; selecting a test env via the legacy `pyproject.toml` block
works; the deprecation banner fires exactly once.

### Story N.j: Append project-essentials entries for N-1

Append to [project-essentials.md](project-essentials.md) any new must-know
facts that surfaced during N-1 implementation. Anticipated entries:

- `pyve.toml` as canonical declaration; `.pyve/` = state only.
- `purpose:` vocabulary (run/test/utility/temp) + default-purpose rules.
- Category A delegation for `pyve testenv *` (the documented exception to
  the Category B policy).
- The v2→v3 migration model: `pyve self migrate` (deterministic), v3.0
  soft banner, v3.1 hard gate (PC-3).
- Read-compat window policy (v3.0 only — hard gate in v3.1).
- Final state-directory path decision from N.f.
- `.pyve/.v2-legacy/` backup location.

Skip the story if N-1 introduced no new invariants beyond what's already
captured here.

---

## Approval-gate handoff

**Files changed this session:** this plan doc, and (pending approval)
`stories.md` with the new Phase N + Subphase N-1 + 8 stories appended.

**What's being asked at the gate:**

1. Confirm the 8-subphase breakdown and the per-subphase scope summaries
   (including the two-release exception: v3.0.0 + v3.1.0).
2. Confirm the production concerns and their assigned subphases.
3. Confirm the breaking-change classifications.
4. Confirm the out-of-scope list (or redirect items into Phase N).
5. Confirm Subphase N-1's 10-story breakdown (N.a through N.j),
   including the new `pyve self migrate` (N.g) and soft banner (N.h)
   stories.

After approval, the next steps in this session are:
(a) append Phase N + Subphase N-1 stories to `stories.md`,
(b) append any new must-know facts to `project-essentials.md` (likely
deferred to N.h since N-1 hasn't shipped yet),
(c) end this `plan_production_phase` session.

---

## Related

- [phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md)
  — strategic direction / requirements / gap-analysis (input to this plan).
- [brand-descriptions.md](brand-descriptions.md) — sections flagged
  **NEEDS REVISION for Pyve 3.0**, addressed in N-6.
- [env-dependencies-template.md](project-guide-requests/env-dependencies-template.md) /
  [env-dependencies-prompt.md](project-guide-requests/env-dependencies-prompt.md) — declarative
  env-dependencies model + LLM-assisted migration prompt.
- [stories.md](stories.md) — the "generalize testenv → named environments"
  Future story is absorbed into N-1; other Future stories listed in
  § *Out of scope*.
- [project-essentials.md](project-essentials.md) — invariants the plan
  preserves (deprecation policy, function naming, `lib/ui/` boundary,
  sourcing discipline, `.envrc` template uniformity).
