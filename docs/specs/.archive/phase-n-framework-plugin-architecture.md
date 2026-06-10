# framework-plugin-architecture.md — Pyve 3.0: declarative, polyglot project-environment orchestration

**Status:** Phase N **concept / requirements / gap-analysis** for **Pyve v3.0.0** — the accepted strategic direction, written to feed a `plan_phase` session. **Not** an implementation spec. Phase N is the next phase to implement after Phase M ships, and it is the work that earns the **major version bump to v3.0.0**.

**How this doc is used:** it is the input to a `plan_phase` session that drafts the formal Phase N plan, which in turn drives updates to Pyve's [`concept.md`](concept.md), [`features.md`](features.md), [`tech-spec.md`](tech-spec.md), and [`README.md`](README.md). Stories are written last, after those four are revised.

**Baseline = Post-M.** Phase M shipped the named-testenv DX bundle: `[tool.pyve.testenvs.<name>]` in `pyproject.toml`, per-env `backend`/`manifest`/`requirements`/`lazy`/`extra`, per-env lock + `.state`, the `pyve test --env <name>` selector, and `.pyve/testenvs/<name>/` materialization. Phase N **generalizes and absorbs** the `testenvs → envs` + `purpose:` rename that `stories.md` sketched as a Future story, plus the polyglot plugin reframing below — into one v3.0 architecture.

**Decision posture:** the charter expansion is **accepted** (per the carrier-audience and convergence arguments below). This doc records the *what* and *why* and a recommended DX; `plan_phase` owns the *how*.

---

## 1. The reframing in one paragraph

Pyve grows from "Python virtual environment manager" into a **declarative, polyglot project-environment orchestrator** with two coupled faces: a **declarative manifest** (`pyve.toml` at the repo root) and a **CLI** (`pyve …`) that are two renderings of one model. The Python ecosystem is itself implemented as the **first, default, always-shipped plugin**; other ecosystems (Node/SvelteKit first, then Go, Rust, Docker, …) plug in via the same contract. The metaphor holds: *green-card residents are indistinguishable from citizens in integration capability* — origin marks history, not status. Full participation in `init`, `purge`, `check`, `status`, `run`, `test`, the activation model, the `.env` lifecycle, and the self-healing `.gitignore` is the contract every plugin satisfies, Python included. Branding already reflects this — see [`brand-descriptions.md`](brand-descriptions.md) ("just about any stack combination … many languages … broad choice of backends").

## 2. Carrier audience & positioning

Pyve's home audience is the Python community, and that is its distribution vector. A Rust developer will not discover Pyve cold; a **Python developer reaching into Rust/Node/Svelte/Docker** carries Pyve in. Design for the actual user, not a hypothetical neutral one — which is also why **Python ships as the first reference plugin**: the people most likely to file the first bugs against the SvelteKit plugin are Python developers whose Python plugin works fine.

**Name:** keep **"Pyve."** The Python-rooted connotation is a feature, signalling that the discipline is grounded in Python-community conventions carried outward. No rename, no sub-brand; the tagline broadens (see `brand-descriptions.md`). *Note: several entries in `brand-descriptions.md` still read Python-only and are flagged there for a future planning/refactor pass.*

## 3. The unifying model — two planes, one seam

The Phase M named-env work and the polyglot plugin idea are **not** competing concepts; they are two layers of one architecture that meet at the **backend**:

- **Declarative plane — `pyve.toml`.** Enumerates the project's environment *surfaces* (the "what"): which environments exist, each with one `purpose`, one `backend`, an optional sub-path, and structured attributes. A **noun** layer.
- **Behavioral plane — the plugin / backend-provider contract.** Supplies the verbs (the "who implements `init`/`check`/`run`/`test`/`purge`/activation/detection" for a given backend). A **verb** layer.
- **Seam — `backend`.** A `pyve.toml` env *names* a backend; a plugin *provides* that backend's behavior.

> **plugin : backend :: ecosystem : mechanism**, and a **named environment** is a per-repo instance that selects a backend.

Every declarative construct has a CLI counterpart and vice-versa: declaring an env in `pyve.toml` then `pyve init` materializes it; `pyve env add` mutates the manifest. One model, two interfaces, both first-class.

## 4. The declarative manifest — `pyve.toml`

**`pyve.toml` at the repo root is the single canonical, stack-neutral source of truth.** It **replaces both** today's `.pyve/config` (YAML) **and** the `[tool.pyve.testenvs.*]` table in `pyproject.toml`. After v3.0, `.pyve/` holds **materialized state only** (envs, locks, `.state`), never the declaration. `[tool.pyve.*]` in `pyproject.toml` is supported as **read-compat** for Python-only users, but `pyve.toml` is what `pyve init` writes and what tooling treats as canonical. Putting it at the root (not under `.pyve/`) makes the Pyve presence visible.

Concept-level sketch (the exact schema is `plan_phase`/`tech-spec` work):

```toml
[project]
name = "learningfoundry"

[env.root]                     # the root development environment
purpose = "utility"            # run | test | utility | temp
backend = "venv"

[env.web]                      # a polyglot sub-surface
purpose = "run"
backend = "pnpm"
path    = "src/learningfoundry/sveltekit_template"   # subdir root (monorepo)

[env.testenv]                  # default test env (Phase M parity)
purpose = "test"
backend = "venv"
default = true
```

### 4.1 Named-environment vocabulary (adopted from the env-dependencies model)

- **Purpose (surface)** — exactly one of `run` (the shipped/executed runtime), `test` (test runners + test-only deps), `utility` (dev/orchestration tooling — LLM/project-guide CLIs, formatters, codegen), `temp` (a *structured*, reproducible ephemeral space; not ad-hoc spikes). One env = one purpose.
- **Root development environment** — the env activated at the repo root; `purpose: utility` by default.
- **`path`** — per-env working/detection root, default `.`. First-class so a monorepo (Python backend + SvelteKit frontend) declares both surfaces in one manifest.
- **Backend** — the materialization mechanism; specific names (`venv`, `micromamba`, `pnpm`, `npm`, `yarn`, `docker`, `podman`, `none`), never generic categories. Closely-related mechanisms with leaky behavioral differences stay as **separate flavored values** (`docker` vs `podman`; `npm` vs `pnpm` vs `yarn`).
- **Structured attributes** — `app_type`, `frameworks`, `languages` per env (fixed vocabularies).
- **Backend tiers** — *language-env* (`venv`, `micromamba`, `pnpm`/`npm`/`yarn`), *host-package* (`homebrew`, `apt`), *isolation* (`docker`, `podman`, which may nest the others).

## 5. The plugin / backend-provider contract

**Granularity decision (Q5): the minimal pluggable seam is a `backend-provider`; an "ecosystem plugin" is a bundle of backend-providers plus shared detection/activation.** Rationale: one plugin (Python) contributes multiple backends (`venv` + `micromamba`); a Node plugin contributes `pnpm`/`npm`/`yarn`. The backend-provider is the unit of *materialization*; the plugin is the unit of *contribution/distribution*. This keeps the contract light enough to preserve the pure-Bash, no-runtime-deps property.

A backend-provider/plugin earns its green card by implementing this contract (a subset is allowed — missing hooks are no-ops, not errors):

1. **Manifest namespace.** Reads its own block(s) in `pyve.toml` (the `backend` value + ecosystem section). Core does not interpret plugin-private keys.
2. **Backend declaration.** Registers one or more backend names. `pyve init --backend pnpm` is valid because the Node plugin declared `pnpm`.
3. **Detection participation.** Contributes a detection rule (e.g. `package.json ∧ (svelte.config.js ∨ vite config imports @sveltejs/kit)`); the existing precedence chain extends to include plugin votes.
4. **Lifecycle hooks.** `init`, `purge`, `update`, `check`, `status`, `run`, `test`, `deploy`. Typed context in (project root, env block, verbosity), typed result out (status rows, exit-code contribution).
5. **Activation contribution.** Emits its `.envrc` snippet (e.g. PATH-munging `node_modules/.bin`); core composes plugin snippets into the single managed `.envrc` with sentinel-marked sections.
6. **Diagnostics contribution.** Adds rows to `pyve check` (pass/warn/error ladder) and `pyve status`.
7. **Self-healing `.gitignore`.** Contributes ecosystem entries *inside* the Pyve-managed template section; user entries below are preserved.
8. **Smart-purge contribution.** Declares created-vs-user-authored inventory; `pyve purge` composes them, mirroring the non-empty-`.env` rule.

Plugins **do not** get to: bypass cloud-sync refusal; weaken `.env` permissions or skip `.gitignore` self-healing; install Pyve or modify `~/.local/.env`; or add new top-level verbs (they extend `--backend`/`--env` and hook existing commands).

**Plugin language (Q7): Bash-only for v3.0** — dog-fooded by the Python plugin, preserving the no-runtime-deps floor. "Any executable satisfying a CLI contract" is post-3.0 roadmap.

**v3.0 plugin set (Q5): exactly two** — **Python** (default, dog-food reference) and **Node/SvelteKit** (second reference, proving the contract generalizes). All others (Go, Rust, Docker/Podman, Ruby, …) are roadmap, not v3.0 deliverables.

## 6. Recommended CLI DX (idiomatic, friendly, familiar)

The CLI is the imperative face of `pyve.toml`. Design goals: a Python-only project sees **no change**; polyglot capability is **discoverable, not imposed**; muscle memory is preserved via legacy sugar.

- `pyve init` — detect ecosystems, scaffold/refresh `pyve.toml`, materialize **all** declared envs, compose **one** `.envrc`, self-heal **one** `.gitignore`. Works **standalone** (no project-guide required) and auto-writes a starter `pyve.toml`.
- `pyve env <add|list|init|install|run|purge|prune>` — generalizes `pyve testenv …`. **`pyve testenv …` is kept as legacy sugar** mapping to `pyve env … --purpose test`.
- `pyve run [--env <name>] <cmd>` · `pyve test [--env <name>]` · `pyve lock [--env <name>|--all]`.
- `pyve check` / `pyve status` — **aggregate** across all envs and active plugins (per-plugin sections, worst-severity exit-code roll-up).
- `pyve deploy [--env <name>]` — see §7.
- `pyve update` — refresh config/managed files; **no automated legacy migration** (see §9). `pyve self …`, `--help/-v/-c` unchanged.

**Backwards compatibility:** an existing `pyproject.toml`-only Python project behaves exactly as today; the Python plugin is the invisible default. A no-Python project (only SvelteKit/Rust) gets the Python plugin included-but-unused, with **no spurious "Python not found" warnings**.

## 7. The `deploy` surface

Deployability is **architecturally in-scope** for v3.0 (Q4), but the **deploy plugin/implementation may be deferred** past the initial release. Scope boundary that reconciles with the existing out-of-scope line ("Docker container or cloud environment management"):

- **In scope:** `pyve deploy` *materializes a reproducible, shippable artifact* — e.g. building a pinned `docker`/`podman` image, producing a lock/bundle — modeled as a **lifecycle hook**, not a new purpose (`run` remains the deployable/runtime surface).
- **Out of scope:** pushing to or orchestrating cloud infrastructure (registries, clusters, secrets backends). Pyve produces the artifact; it does not manage where it runs.

**Refinement (post-N-3 env-spec design — see [phase-n-2-spike-env-model-worked-examples.md](phase-n-2-spike-env-model-worked-examples.md) §S15).** The materialized artifact's kind is a first-class **`packaging`** attribute on `[env.<name>]` (`container` / `static` / `server` / `serverless` / `package` / `binary` / `mobile_app` / `lock_bundle` / `none`), distinct from the build-time platform (`build_target`) and the ship destination (`deploy_target`, out of scope). Because the verb *materializes* the packaging rather than shipping it, the command is likely renamed **`pyve package`** (reserving `deploy` for an eventual ship step) — to be ratified when N-5 is planned.

## 8. `project-guide` integration

`project-guide` is **not required** (Q3) — `pyve init` is fully standalone. When used, `project-guide` offers a **Q&A wizard with a new step** that determines the project's stack and which environments to build, then scaffolds a Pyve-managed repo (writing `pyve.toml` and the per-env surfaces). See <https://pointmatic.github.io/project-guide/> and [`docs/specs/project-guide/`](../project-guide/). The **env-dependencies document** (`env-dependencies-repo_<name>.md`, authored by an LLM via [`env-dependencies-prompt.md`](project-guide-requests/env-dependencies-prompt.md)) is the **planning/migration artifact** used to bring an existing repo under Pyve management — front-loaded into `project-guide` so greenfield planning initializes the manifest. It is an input to authoring `pyve.toml`, not a maintained runtime source.

## 9. Gap analysis (Post-M → v3.0 target)

| Concern | Post-M (today) | v3.0 target | Gap |
|---|---|---|---|
| Declaration home | `.pyve/config` (YAML) + `[tool.pyve.testenvs.*]` (pyproject) | single root `pyve.toml`; `.pyve/` = state only | consolidate two sources into one; pyproject read-compat |
| Named envs | test-only (`testenvs`), `--env` selector | `[env.*]` with `purpose` (run/test/utility/temp) + `path` | rename + generalize; add purpose & monorepo paths |
| Backends | `venv`, `micromamba` (Python only) | + Node `pnpm`/`npm`/`yarn`; backend-provider contract | extract core→provider seam; add Node plugin |
| Detection | `backend_detect.sh` (Python files) | plugin-contributed detection votes | generalize precedence chain |
| Activation | single `.envrc`, Python-only | composed `.envrc`, sentinel-marked plugin sections | composition + refresh-safe updates |
| `check`/`status` | Python env only | aggregate across envs + plugins | per-plugin rows, exit roll-up |
| `purge` | Python artifacts | composed created-vs-authored inventory | plugin purge contributions |
| Deploy | none | `pyve deploy` artifact lifecycle (impl. deferrable) | new hook; provider deferred |
| Architecture | monolithic core | Python = first reference plugin (dog-food) | re-seat core behind the contract |

## 10. Requirements distilled (accepted)

Charter-level:

- **R1.** The plugin/backend-provider contract is a **first-class part of Pyve's identity**, documented alongside the core CLI.
- **R2.** **Python is the first reference plugin** (dog-food invariant): built on the same contract third parties use; no privileged "Python backdoor." Regressions break the Python plugin first — loud, not subtle.
- **R3.** **Node/SvelteKit is the second reference plugin**, proving the contract generalizes.
- **R4.** **Zero-change for pure-Python projects**: existing `pyve init` behavior is preserved; the plugin model is invisible unless reached for.
- **R5.** **`pyve.toml`** is the single canonical, stack-neutral manifest; declarative and CLI faces are kept in lockstep.

Capability-level:

- **R6.** **In-tree plugins only** for v3.0; out-of-tree contract is post-3.0.
- **R7.** **Multiple active plugins** compose in a declared order from `pyve.toml`; no privileged slot — Python's "first" status is being the default-included plugin.
- **R8.** **Per-env / per-plugin schema versioning** in `pyve.toml`; the `pyve_version` drift check generalizes.
- **R9.** **Composed `.envrc`, `check`, and `purge`** as in §6/§9.
- **R10.** **Monorepo `path` support** is in-scope (Q2).
- **R11.** Preserve all inviolable constraints (§11).

## 11. Inviolable constraints (unchanged)

macOS + Linux only · pure-Bash core, no runtime deps, no daemons · **Bash-only plugins (v3.0)** · orchestrate-don't-replace (plugins orchestrate `pnpm`/`cargo`/`go mod`, never reimplement them) · idempotent · never destroy user data · secure defaults (`.env` `chmod 600`, self-healing `.gitignore`) · cloud-sync refusal · Apache 2.0.

## 12. Migration

**No automated migration tooling** (Q6). Post-M projects are migrated **ad hoc with LLM-assisted scaffolding** that derives `pyve.toml` from the existing `.pyve/config` + `[tool.pyve.testenvs.*]` and relocates `.pyve/testenvs/<name>/` → the v3.0 state layout. Pyve **may** still *read* legacy declarations for a deprecation window and emit a hard-error/warning pointing at the new form, but it does not auto-rewrite them. The env-dependencies doc (§8) is the recommended driving artifact for the LLM-assisted pass.

## 13. Open questions for `plan_phase`

1. **`pyve.toml` schema specifics** — exact table shape for `[env.*]`, plugin sections, per-plugin version keys, and how `path` interacts with detection roots.
2. **State layout** — `.pyve/testenvs/<name>/` → `.pyve/envs/<name>/`? (`.pyve/envs/` currently names micromamba envs — pick the final path during `plan_phase`.)
3. **Composition order semantics** — declared order vs detection order for `.envrc` PATH precedence and `.gitignore` section ordering.
4. **Activation across sub-paths** — does a monorepo emit one `.envrc` at root, or per-`path` `.envrc` files? Implications for direnv.
5. **Legacy read-compat window** — how long does Pyve read `[tool.pyve.testenvs.*]` / `.pyve/config`, and what exactly does the deprecation message say?
6. **`pyve deploy` minimum** — is any deploy hook shipped in v3.0, or is the verb reserved and the implementation fully deferred?
7. **No-Python-project UX** — concrete behavior to suppress Python-plugin noise when no Python surface is declared/detected.

## 14. Related

- [`concept.md`](concept.md) — the charter Phase N evolves.
- [`features.md`](features.md) / [`tech-spec.md`](tech-spec.md) — current capability + implementation discipline plugins must respect.
- [`stories.md`](stories.md) — Phase M (baseline) and the Future "generalize testenv → named environments" story absorbed here.
- [`env-dependencies-template.md`](project-guide-requests/env-dependencies-template.md) / [`env-dependencies-prompt.md`](project-guide-requests/env-dependencies-prompt.md) — the declarative env-dependencies model and the migration-authoring prompt.
- [`brand-descriptions.md`](brand-descriptions.md) — positioning/taglines (partly Python-only, flagged for a future pass).
- learningfoundry's [SvelteKit template](../../src/learningfoundry/sveltekit_template/) — worked-example codebase for the second reference plugin.
