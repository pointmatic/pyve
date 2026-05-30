# phase-m-testenv-dx-plan.md — Test Environment DX sub-section (Phase M)

**Status:** Plan doc for the **testenv-DX sub-section** of Phase M (drafted
2026-05-28 via `plan_production_phase`).
**Companion brief:** [phase-m-pyve-named-testenvs.md](phase-m-pyve-named-testenvs.md) — use cases, requirements, open
questions (source material that this doc resolves into a plan).
**Phase context:** Phase M is **dual-character**:

1. A rolling **junk drawer** for small, independently-discovered fixes — each
   ships its own patch/minor bump as it lands (M.a v2.6.3, M.b v2.6.4, M.c
   v2.7.0).
2. This **testenv-DX sub-section**, a planned coherent initiative that runs
   **unversioned** during work and ships as **one bundled release** at the end
   (anticipated target: **v2.8.0** — see § Anticipated version bump target).

Junk-drawer stories continue to accrete in Phase M alongside the testenv-DX
sub-section. Story IDs are sequential in the order performed; testenv-DX
stories are marked as such in their bodies.

**Pre-bundle junk-drawer items** (ship before the testenv-DX bundle starts):

- **M.d — Dependabot config.** Adds `.github/dependabot.yml` closing the
  production-readiness gap surfaced during Step 2. Pure CI config; no
  user-facing change; no version bump.
- **M.e — `main` → `root` rename, ships as v2.7.1.** The "oops, we
  got the name wrong in M.c v2.7.0" patch (FR-M.5 / BC-1). Pulling this
  *out* of the testenv-DX bundle and shipping it early leaves the bundle
  itself zero-breaking-change — a clean minor bump.

---

## Gap analysis

| Capability | Today | After testenv-DX |
|---|---|---|
| Number of test envs per project | One (`testenv`) | Many, user-declared |
| Test env backend | venv-only | venv (default) or micromamba; optional `inherit-from-main` shorthand |
| Manifest sources | `requirements*.txt` only | `requirements*.txt`, `pyproject` extra, or `environment*.yml` (per env) |
| Env selection | `pyve test --env {testenv,main}` (M.c) | `pyve test --env <name>` over arbitrary names; `root` + `testenv` reserved |
| Provisioning | Eager (`pyve testenv install` builds the one env) | Per-env, optionally **lazy** (heavy envs built on first targeted run) |
| Drift between shipped manifest and test env | No way to point a test env at the shipped artifact | Same-file: `manifest = "<path>"` eliminates drift by construction |
| Silent-skip safety (M.c advisory) | One env, one advisory | Every named env: select-an-unprovisioned-env fails loudly |
| Concurrency | Undefined; user manages | Per-env install lock owned by pyve dispatcher |
| Disk discoverability | `pyve testenv purge` only | `pyve testenv list` (size, last-used) + `pyve testenv prune` |
| Config location | Hard-coded defaults | `[tool.pyve.testenvs]` in `pyproject.toml` (pytest analog) |
| Matrix testing | Not supported | Supported via env-set selection (UC6 in scope) |

---

## Feature requirements

These are the *properties* of the testenv-DX surface, refining the eight
requirements in the companion brief.

### FR-M.1: Multiple, named test environments per project

Declared in `[tool.pyve.testenvs]` (see § Technical changes). Selected via
`pyve test --env <name>` (generalizing M.c's two-value `--env`). The names
**`root`** and **`testenv`** are reserved (see FR-M.4 and FR-M.5).

### FR-M.2: Per-env backend selection

Each named env declares `backend = "venv"` or `backend = "micromamba"`. A
shorthand `backend = "inherit"` resolves to the main env's backend at
provisioning time. **Default if unspecified: `venv`.** (Rationale: pyve =
Python virtual environment; conda is heavy and slow; double-conda use cases
are thinner.)

This single mechanism satisfies both UC2 (parity — main is conda → test
mirrors via `inherit`) and UC3 (capability — main is venv, but a test
category needs conda-only native libs like GDAL/CUDA/HDF5 → explicit
`backend = "micromamba"`).

### FR-M.3: Per-env manifest source

Each named env declares one of:

- `requirements = ["<file>", ...]` — one or more pip-style manifests
- `extra = "<name>"` — a `pyproject.toml` optional-dependency extra (e.g. `[project.optional-dependencies] dev = [...]`)
- `manifest = "<path>"` — a single conda `environment*.yml` (UC4: drift-free
  by construction; the shipped artifact is the test source-of-truth)

`manifest` is mutually exclusive with `requirements`/`extra`. Conda-backed
envs accept `manifest`; venv-backed envs accept `requirements` or `extra`.

### FR-M.4: Light default preserved (no ceremony for simple projects)

Projects with **no** `[tool.pyve.testenvs]` block continue to work
unchanged: a single venv testenv at `.pyve/testenvs/testenv/`, populated by
`pyve testenv install -r requirements-dev.txt`. The reserved name
`testenv` always exists and refers to this default. The two-env mental
model from
[project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md)'s
"Pyve Essentials" stays canonical for pure-Python projects.

### FR-M.5: Canonical root-env name — `root` replaces `main`

The reserved name for "the main `.venv/` env, not a testenv" is
**`root`** (formerly `main`, introduced in M.c v2.7.0). Rationale: `main`
overloads the git-branch term; `root` reads as "the root of the project
folder, the development surface." `root` and `testenv` are the two
permanently-reserved names; user-declared envs cannot use either.

The rename ships as a **Category-B** hard-error catch (per
[project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md)
*Deprecation removal policy*) in the `pyve test --env main` arm of
`pyve.sh`:

```
pyve test --env main: renamed to --env root. Run 'pyve test --env root' instead.
```

…and exits non-zero. Three lines, zero ongoing maintenance, precise migration
hint. No Category-A silent delegation.

**Release sequencing.** This rename ships as story **M.e (v2.7.1)** —
a junk-drawer patch *before* the testenv-DX bundle begins. Treating it as
an "oops, M.c got the name wrong" fix rather than folding it into the
bundled release achieves two things: (a) the bundle becomes
zero-breaking-change (clean minor bump per the Version Cadence rule);
(b) anyone running stale M.c-era scripts gets the migration error
weeks earlier than they would otherwise. The testenv-DX bundle
(M.f onwards) takes `root` as the established canonical name from day
one — no further accommodation needed.

### FR-M.6: Lazy provisioning

A testenv with `lazy = true` is **skipped** by the bulk-install path
(`pyve testenv install` with no name installs all non-lazy envs only) and
is built on first targeted use (`pyve test --env <lazy-env>` or
`pyve testenv install <lazy-env>`). The heavy multi-GB ML stack (UC1) is
the motivating case: CI selects the light env and never materializes the
heavy one.

### FR-M.7: Fidelity / anti-drift

The same-file `manifest = "<path>"` mechanism (FR-M.3) is the canonical
answer. No separate two-file divergence checker. If a user maintains two
parallel manifests, that's their choice — they can write a project-local
test for divergence; pyve does not provide one. (See § Out of scope.)

### FR-M.8: Missing-dependency visibility — generalize M.c

The silent-skip advisory shipped in M.c (`PYVE_NO_TESTENV_ADVISORY=1` opt-out)
must extend to **every named env**, not just the default `testenv`. When a
selected env lacks deps the tests import, surface it loudly rather than let
a mass-skip masquerade as a pass. The advisory message names the offending
env explicitly.

### FR-M.9: Coherent selection across CLI/CI

One obvious way to pick the env: `pyve test --env <name>` locally and in CI
config. When `[tool.pyve.testenvs] default = "<name>"` is set, that is the
no-`--env` default; otherwise the reserved `testenv` is the default.

### FR-M.10: Matrix testing (UC6)

`pyve test --env <a>,<b>,<c>` runs the same suite against multiple envs in
**sequence by default**, accumulating results. A future flag (`--parallel`,
out of scope here unless trivially in reach) may switch to concurrent
execution; default matrix execution is serial to align with the dispatcher
concurrency model (see § Production concerns / Concurrency).

### FR-M.11: Polyglot generality boundary (UC5)

The data model (named envs with per-env backend, manifest, runtime tag)
must not bake in Python-specific assumptions. Concretely: the
`[tool.pyve.testenvs]` schema treats `backend` as an open string; current
allowed values are `{venv, micromamba, inherit}` but the parser does not
encode Python-only assumptions about what an env *is*. **No actual
non-Python backend ships in this sub-section** — the requirement is to not
preclude one being added later (e.g. a `node`, `jsdom`, or `wasm` backend
in a future phase).

### FR-M.12: Disk discoverability — `pyve testenv list` / `pyve testenv prune`

- `pyve testenv list` — table of declared envs, with per-env disk size,
  last-used timestamp, and provisioning state (`provisioned` /
  `lazy-unprovisioned` / `stale`).
- `pyve testenv prune` — remove envs whose state is `lazy-unprovisioned` is
  a no-op; remove envs `--unused-since <date>`; remove envs not declared
  in `[tool.pyve.testenvs]` (drift cleanup) with confirmation.

These are small additions that surface disk cost without forcing `du -sh`.

---

## Technical changes

### TC-M.1: TOML config reader for `[tool.pyve.testenvs]`

Pyve does not parse `pyproject.toml` today. Add a Python-helper invocation
(pyve already requires Python; venv-only project can `python -c "import
tomllib; ..."` on 3.11+; older fallback uses `tomli` if needed, but pyve's
supported Python versions can be pinned at ≥3.11 since pyve itself is
shell-with-Python-helpers, not a library). The helper emits shell-friendly
key/value lines consumed by `lib/testenvs.sh` (new).

**File placement** — per
[project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md)
*lib/commands/<name>.sh is for command implementations only*:

- `lib/testenvs.sh` (new) — shared helper: read config, resolve env names,
  validate backend/manifest combos, locate env directory. Called by
  `testenv`, `test`, and `lock` commands.
- `lib/commands/testenv.sh` (existing) — namespace dispatcher + leaves
  extended for name-aware ops (`testenv_list`, `testenv_prune` are new
  leaves).
- `lib/commands/test.sh` (existing) — `pyve test --env <name>` lookup
  delegates to `lib/testenvs.sh`.

Explicit `source` line added in `pyve.sh` (per the
*Library sourcing is explicit, not glob-based* rule).

### TC-M.2: Per-env directory layout

Existing single-testenv layout (`.pyve/testenvs/venv/` is today's
hard-coded location, used by `lib/commands/testenv.sh`). Generalize to:

```
.pyve/testenvs/
  <name>/
    venv/                  # venv-backed env content (mutually exclusive with conda/)
    conda/                 # micromamba-backed env content
    .lock                  # per-env install lock (TC-M.4)
    .state                 # cache: backend, manifest hash, provisioned timestamp, last-used timestamp
```

The reserved `testenv` name resolves to `.pyve/testenvs/testenv/venv/` for
backward compatibility — existing projects' testenvs migrate transparently.
(A one-time `pyve update` hook renames the legacy `.pyve/testenvs/venv/`
to `.pyve/testenvs/testenv/venv/`; see Story-level breakdown.)

### TC-M.3: Conda-backed testenv plumbing

Reuse the main-env micromamba code path
([lib/commands/init.sh](../../lib/commands/init.sh) + [lib/utils.sh](../../lib/utils.sh) `write_envrc_template`) but emit no
`.envrc` for testenvs (testenvs are not direnv-activated; they are invoked
via `pyve testenv run` / `pyve test --env`). The shared conda detection
and micromamba invocation helpers live in `lib/backend_detect.sh` already;
extend them to take a target prefix.

### TC-M.4: Per-env install lock

`.pyve/testenvs/<name>/.lock` — acquired via `flock` for the duration of
`pyve testenv install <name>` (and any auto-provision path from
`pyve test`). Second concurrent invocation either waits (default) or fails
with a clear message naming the holding PID. Lock-free fast path for
read-only execution of an already-provisioned env (per the
dispatcher concurrency model).

### TC-M.5: `pyve lock` extension for conda-backed testenvs

`pyve lock` today locks the main env's `environment.yml` → `conda-lock.yml`
(see [lib/commands/lock.sh](../../lib/commands/lock.sh)). Extend to:

- `pyve lock` (no args) — lock the main env (current behavior preserved)
- `pyve lock --env <name>` — lock the named conda-backed testenv
- `pyve lock --all` — lock the main env and every conda-backed testenv

Lock files are sibling to the manifest: `<manifest-basename>-lock.yml`.

### TC-M.6: CLI surface — `testenv` namespace expansion

Per the
[project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md)
*Namespace commands are single files* and *function naming convention*
rules, all new leaves stay in [lib/commands/testenv.sh](../../lib/commands/testenv.sh):

| CLI | Function | Behavior |
|---|---|---|
| `pyve testenv init [<name>]` | `testenv_init()` | Creates env directory. No args = default `testenv`. |
| `pyve testenv install [<name>] [-r ...]` | `testenv_install()` | Installs deps. No args = all non-lazy envs; with name = that env only. |
| `pyve testenv purge [<name>]` | `testenv_purge()` | Removes env. No args = all envs; with name = that env. |
| `pyve testenv run [<name>] -- <cmd>` | `testenv_run()` | Runs in named env. No args = default `testenv`. |
| `pyve testenv list` | `testenv_list()` | **New.** Table of declared envs (size, state, last-used). |
| `pyve testenv prune` | `testenv_prune()` | **New.** Removes unused / undeclared envs. |

Per-command help blocks (`show_testenv_<sub>_help`) extended for new leaves,
co-located in [lib/commands/testenv.sh](../../lib/commands/testenv.sh) per the existing rule.

### TC-M.7: `pyve test --env <name>` resolution

[lib/commands/test.sh](../../lib/commands/test.sh)'s arg parser already accepts `--env {testenv,main}`
(M.c). Generalize the resolver:

1. If `--env <name>` given, look up `<name>` in `[tool.pyve.testenvs]`.
   - If `<name>` == `main`: hard-error per FR-M.5.
   - If `<name>` == `root`: target `.venv/` directly (M.c's `main` path
     under the new name).
   - If `<name>` == `testenv`: target `.pyve/testenvs/testenv/venv/`.
   - Otherwise: target `.pyve/testenvs/<name>/<venv|conda>/` per the env's
     declared backend.
2. If no `--env` given, use `[tool.pyve.testenvs] default` if set;
   otherwise `testenv`.
3. If the env is not provisioned and not `lazy`, run the M.c silent-skip
   advisory (FR-M.8); if `lazy`, auto-provision (acquiring the lock per
   TC-M.4) and proceed.

### TC-M.8: Matrix execution (UC6)

`pyve test --env a,b,c` parses comma-separated names, runs each in sequence,
accumulates exit codes, exits with the worst-case status. Output is
delineated per env. Parallel execution is **out of scope** for this
sub-section; the serial baseline is a deliberate alignment with the
dispatcher concurrency model.

---

## Production concerns

Per Step 2 of `plan_production_phase`, all eight production-readiness items
are satisfied (one — Dependabot — adopted as junk-drawer story M.d
ahead of the testenv-DX sub-section).

**Phase-specific production concerns** identified in design:

### PC-1: Silent-skip safety extended to all named envs

The micromamba-testenv-trap lesson (M.c) is the lever. Generalizing
`--env` from {testenv, main} to arbitrary names multiplies the surface
area for a CI invocation selecting an env that isn't provisioned. **In
scope.** Implementation reuses M.c's advisory helper, parameterized over
env name.

### PC-2: Conda channel pinning for conda-backed testenvs

UC2/UC3 introduce conda-backed testenvs. Without lock files, conda-forge
resolution is non-deterministic across time, leaking into CI flakiness.
**In scope** via TC-M.5 (`pyve lock --env <name>` extension).

### PC-3: Per-env install lock

Pyve owns the testenv lifecycle; concurrent install of the same env from
two shells is pyve's responsibility to serialize (see TC-M.4). **In scope.**

### PC-4: Disk discoverability

Multiple named envs balloon disk; `pyve testenv list` + `pyve testenv
prune` are the in-scope mitigations (FR-M.12).

---

## Anticipated breaking changes

One, **and it ships outside the testenv-DX bundle** (see § Pre-bundle
junk-drawer items in the header).

### BC-1: `pyve test --env main` → `pyve test --env root` (pre-bundled patch)

- **Surface:** the `--env main` value introduced in M.c v2.7.0.
- **Mechanism:** Category-B hard-error catch in the `pyve.sh` dispatcher
  arm (three lines; precise replacement message; exit non-zero).
- **Substantively breaking?** No — technically-but-trivially. M.c shipped
  weeks before this rename, the value is one CLI argument, the new value
  is a one-token swap, and the error message points to it.
- **Step-5 negotiation result:** treated as an *"oops, last release"*
  patch. Ships as **story M.e, v2.7.1**, before the testenv-DX bundle
  begins. By the time the bundle ships, the rename is already in the
  field for weeks.
- **Consequence for the bundle:** zero breaking changes inside the
  testenv-DX bundle. The bundle is purely additive — clean minor bump.

No other breaking changes anticipated. The default no-config path
(FR-M.4) preserves existing behavior; the reserved `testenv` name keeps
the current bulk-install / single-env workflow intact for every project
that doesn't opt in.

---

## Anticipated version bump target

Two releases bracket the testenv-DX work, both inside Phase M:

| Release | Story | Type | Contents |
|---|---|---|---|
| **v2.7.1** | M.e | patch | `--env main` → `--env root` rename (Category-B catch); junk-drawer cadence |
| **v2.8.0** | last bundle story | **minor** | testenv-DX bundle (M.f onwards); zero breaking changes; purely additive |

Rationale for v2.8.0 per the **Version Cadence** rule in
[stories.md](stories.md):

> Any item judged substantively breaking → major bump.
> All items judged technically-but-trivially breaking, or no breaking changes → minor bump.

With BC-1 pre-shipped as v2.7.1, the bundle has zero breaking changes
and many additive features (named testenvs, conda backend, config
schema, lazy provisioning, `list`/`prune`, matrix execution, advisory
generalization). **Minor bump → v2.8.0.**

If unanticipated breaking changes surface during implementation, the
target is revisited before bumping (per Step 10 of `plan_production_phase`).

---

## Out of scope (deferred)

Each item below was flagged during design and is **explicitly deferred**.
Future phases (or the rolling junk drawer) may pick them up.

### OS-1: `uv` as a testenv backend

`uv`'s single global package store + per-env hardlinks model would
materially reduce disk usage for many-named-env projects. **Deferred** —
backend substitution is a separate architectural decision; the testenv-DX
sub-section keeps the `{venv, micromamba}` backend set.

### OS-2: Two-file drift guard

A separate divergence checker between a dev manifest and a shipped
manifest. **Deferred — and likely never needed:** the same-file
`manifest = "<path>"` mechanism (FR-M.3 / FR-M.7) eliminates drift by
construction. If a project deliberately maintains two manifests, they
write their own divergence test.

### OS-3: In-env pytest parallelism

`pytest -n auto` (pytest-xdist) is pytest's concern, not pyve's. Pyve
hands off to pytest; in-env parallelism is configured in
`pyproject.toml`'s `[tool.pytest.ini_options]`.

### OS-4: Parallel matrix execution

UC6 ships **serial** matrix execution (FR-M.10 / TC-M.8). Parallel matrix
(`pyve test --env a,b,c --parallel`) is deferred — its concurrency model
deserves dedicated design and is non-trivial to get right without
collateral failure modes (TTY collision, log interleaving, exit-code
aggregation policy).

### OS-5: Non-Python runtime backends (UC5)

The data model does not preclude a `node`, `jsdom`, or `wasm` backend
(FR-M.11), but no such backend ships in this sub-section. **Deferred** —
adding one is a future-phase capability extension on a stable substrate.

### OS-6: `pyve testenv install` auto-creating the env

The current contract (`pyve testenv init` is required before
`pyve testenv install`) is preserved. Auto-create on install would change
the lifecycle invariant and is not in scope.

### OS-7: M.c silent-skip advisory becoming a hard-error by default

Today's M.c shipped a *warning*-style advisory. Some projects may prefer
"missing-dep skip = test failure." A `[tool.pyve.testenvs.<name>]
strict = true` flag would surface this cleanly. **Deferred** — the
generalized advisory (FR-M.8) keeps M.c's warning semantics; strict mode
is a future enhancement.

---

## Open question carried forward

The companion brief listed six open questions. Five are resolved above
(unified `--env` namespace with `root`/`testenv` reserved; config in
`pyproject.toml`; venv default with `inherit` shorthand; matrix in scope;
generality preserved without shipping a non-Python backend; drift via
same-file manifest). One remains:

- **What is the deployed-artifact resolution surface for projects whose
  runtime is *not* the repo's main env?** (Docker image, downstream
  `pip install`, conda-forge package.) The testenv-DX sub-section
  *enables* parity (via `backend` + `manifest`) but does not *enforce*
  matching any particular deployment surface — the developer declares
  the matching env. A future phase may add `pyve testenv verify-parity
  --against <docker-image|wheel|conda-pkg>` if demand surfaces. **Not
  blocking** for this sub-section.

---

## What this plan does not contain

The **story breakdown** (M.e onwards, integration spike, etc.) — that's
Step 7 of `plan_production_phase`. After approval of this plan doc, the
stories land in [stories.md](stories.md) under the existing
`## Phase M:` heading, interleaved with the junk-drawer cadence.
