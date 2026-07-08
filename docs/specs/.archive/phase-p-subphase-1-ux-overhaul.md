# phase-p-subphase-1-ux-overhaul.md — Pyve v3.1.0 UX Foundation

> The north-star principles, concrete design, and scope for **Subphase P-1** of Phase P — the v3.1.0 UX overhaul. This is the foundation that the rest of Phase P (harden & heal, v3.2.0+) builds on.

This is the design artifact produced by **Story P.b (UX Vision)**. It is the source that the spec realignment (Story P.c) folds into [`concept.md`](concept.md) / [`features.md`](features.md) / [`tech-spec.md`](tech-spec.md), and the framework that Story P.d uses to plan the later subphases. For the authoritative, evolving story roster, see [`stories.md`](stories.md) § *Subphase P-1*.

---

## 1. The problem this subphase solves

Pyve v3 became an *any-project, fully declarative* environment manager — but the **authoring and lifecycle UX did not catch up with the architecture**. The "named environments" promise is under-delivered in three concrete, field-surfaced ways:

1. **Authoring `pyve.toml` is opaque.** A new user can't tell from the manifest "what do I really need, and why" — which fields are required, what a missing field means, what default fills it. Worse, the generated file is *incomplete*: `pyve init --backend micromamba` writes a backend-less `[env.root]`, and the real backend lives in the v2 `.pyve/config`. The canonical file is missing the one fact that matters.
2. **Defaults are hidden and version-fragile.** Defaults are applied silently at read time, so a Pyve upgrade that changes a default can change an existing project's behavior with no record and no warning.
3. **Multi-env lifecycle is a chore.** Upgrading or rebuilding N environments is a long, partly-imperative dance — `pyve init --force` (re-typing every setting), then N× `pyve env purge` / `env init` / `env install` — and lazy environments reset to factory on rebuild, losing the operational reality the developer had built.

Underneath all three is one root cause: **the declaration is incomplete and the config surface is scattered.** Grounding (verified 2026-06-25): adding a single `pyve init` parameter today touches **≥4 hand-synced sites** — the flag `case` loop ([`plugin.sh:1558`](../../lib/plugins/python/plugin.sh#L1558)), the `unknown_flag_error` allow-list ([`plugin.sh:1690`](../../lib/plugins/python/plugin.sh#L1690)), the help text ([`plugin.sh:2271`](../../lib/plugins/python/plugin.sh#L2271)), and the default initializer ([`plugin.sh:1535`](../../lib/plugins/python/plugin.sh#L1535)) — plus a hardcoded wizard block whose prompt order is fixed by source position ([`_init_wizard`, plugin.sh:1181](../../lib/plugins/python/plugin.sh#L1181)). The plugin contract has 14 hooks, **none** for wizard/flags ([`contract.sh:35`](../../lib/plugins/contract.sh#L35)). Nothing keeps the four sites consistent; drift is only caught by tests.

This subphase makes the declaration **complete** and the config surface **single-sourced**, so the named-environments promise actually delivers.

---

## 2. North-star principles

The mission tenets that bear on UX — *calm the chaos*, *starts-simple with progressive nuance*, *declarative as the single source of truth*, *DRY*, *consistent across commands and plugins*, and *delightful* (FR-20: consistency is the floor, not the goal) — plus four UX principles established with the developer:

- **P1 — Explicit-by-construction.** `pyve.toml` records *every* resolved value. The wizard does the authoring (an "easy mode" fast-accepts the defaults), so explicitness is never a hand-editing burden. **Permissiveness lives in the wizard, not the manifest.**
- **P2 — Defaults pinned at authoring; never retroactive.** A default is resolved once and frozen into `pyve.toml`. A Pyve-version default change never mutates an existing repo — it is *surfaced* ("default backend changed `venv`→`X`"), never silently re-applied. This makes Pyve upgrades safe by construction (the lockfile discipline, applied to config).
- **P3 — Rebuild restores state; purge resets it.** A rebuild returns each env to *whatever it was* — a realized-and-installed lazy env comes back realized-and-installed; a never-realized one stays unrealized. Only `purge` blows it away. Powered by a `.pyve/`-resident operational-state record, snapshot-then-replayed across `--force`.
- **P4 — Symmetry + uniform no-arg default.** `pyve env init <name> --force` is to a named env exactly what `pyve init --force` is to root; `--all` fans the root action across every declared env; and **bare `pyve env <sub>` operates on the *default* env** — fixing the `env purge` wart (today it sweeps *all* envs while its siblings assume the default).

These four are the acceptance lens for every story in P-1: a change that violates one is wrong even if it "works."

---

## 3. The keystone — a parameter decision-graph

A flat list of parameters cannot prune questions or narrow choices. The keystone is a **conditional decision-graph** in which each node declares:

- **applicability** — a predicate over prior answers (skip the node entirely when not relevant);
- a **choice set** — possibly *computed* from prior answers (Backend's options are a function of Language);
- a **default** — *versioned* (so P2 can detect drift);
- plus its **flag**, **env var**, **owning plugin**, and **required?**.

The wizard walks the graph top-down and prunes; the **same graph**, resolved by flags instead of prompts, is the non-interactive / CI surface. From this one artifact, six outputs are generated — eliminating the ≥4-site drift entirely:

> **wizard** · **flag/CLI parser** · **`--help`** · **the defaults the manifest reader applies** · **the explicit `pyve.toml`** · **default-drift detection**

**Plugins contribute their own subtrees.** The framework owns the top differentiators and cross-cutting nodes (Language, project-guide, `.env`/direnv, composition); each plugin contributes its language subtree (Python: `backend → version-manager → version → test-env`; Node: `provider → runtime-manager → …`). This extends the FR-4 plugin contract to carry the **wizard/parameter graph**, not just lifecycle hooks.

The gradient this produces:

```
Language?                      ← framework node, prunes everything below
├─ Python      → Backend? {venv, micromamba}   → version-mgr → version → test-env shape
├─ JS/TS       → Provider? {pnpm, npm, yarn}    → runtime-mgr → …
├─ Shell       → (few/no further nodes)
└─ Multiple    → fan out into per-language subtrees + env-set questions
```

- **Python, single stack** → 2–3 nodes and done ("easy mode" is just *the graph being shallow here*).
- **Multiple / polyglot** → fans into per-language subtrees.
- **Gnarly topologies** (PyTorch-vs-Keras isolation, monorepo env count) → the deferred **templates** feature (§7) pre-seeds subtree answers; the core graph never encodes those opinions.

**Grounding / lift sizing.** This is **net-new** — there is no seam to extend today (verified: no registry, no plugin wizard/flag hook). But the parameters are already conceptually 1:1 across the four scattered sites, so the work is a *consolidation*, not a redesign. Because it is net-new with an unproven Bash-generation seam, P-1 opens with an **architectural spike** before the full extraction.

---

## 4. Pillar I — explicit, teachable declaration

The keystone makes the declaration *complete*; Pillar I makes it *honest and stable*.

- **Explicit-by-construction (P1).** `pyve init` writes a fully-explicit `pyve.toml` — every resolved value recorded, sourced from the registry's defaults. The wizard (and its easy-mode fast-accept) does the authoring, so a trivial Python project's explicit file is generated, not hand-typed.
- **`pyve.toml` is the *sole* config source.** Today the manifest is declared canonical but is neither fully *written* by `init` (backend-less `[env.root]`) nor fully *read* by the toolchain (~64 sites still read the v2 `.pyve/config`). P-1 closes this three-sided: **write** the resolved backend/python/env-name into `pyve.toml`, **migrate** the ~64 read-sites onto `manifest_load`, and **stop** writing `.pyve/config`. This is the load-bearing prerequisite for "explicit" — and it also repairs a high-severity bug where `pyve init --force` silently no-ops on a `.pyve/config`-less v3 project (the reinit gate keys off `config_file_exists`).
- **Defaults pinned + drift surfaced (P2).** Registry defaults are versioned. A default change never rewrites an existing repo; a check/update surface *reports* the divergence with the new value, leaving the pinned value untouched.

The net effect: a developer (or an LLM) can read a `pyve.toml` and know exactly what the project is, what every field means, and that it will behave identically on the next machine and the next Pyve version.

---

## 5. Pillar II — desired-vs-actual state & reproducible rebuild

`pyve.toml` is *desired* state (intent); a new **operational-state record** is *actual* state (what's materialized). This is the IaC split (`main.tf` vs `terraform.tfstate`) — not a second source of truth, because one is declared and one is observed.

- **Operational-state record — extend `.state` (P3).** Grounding (verified): a per-env `.state` store already exists with safe read/write/update helpers ([`lib/envs.sh:387`](../../lib/envs.sh#L387)), but it is written at **realize** (env dir built), never at **install** — so there is *no recorded "deps installed" bit* (only a conda `manifest_sha256` drift baseline; venv has nothing), and `ready`/`lazy` is recomputed live from the filesystem. P-1 adds an installed-spec hash for **both** backends and writes `.state` from the install path, so the realized-vs-installed distinction is recorded rather than re-derived. **No new file** — it stays `.pyve/`-resident (honoring "`pyve.toml` declares, `.pyve/` holds state"), so `pyve.yaml` is *not* introduced.
- **Declarative env setup — the manifest fully describes an env.** An `[env.<name>]` block declares *how the env is set up*: a composable set of plugin-interpreted directives (an `editable` self-install with extras, requirements files, an `extra` group, a conda manifest, packages…). The `requirements ⊕ extra ⊕ manifest` mutex is lifted; the missing `editable` directive is added. `pyve env init <name>` materializes the whole recipe in one shot. *(The detailed decomposition lives in the megastory in `stories.md`.)*
- **Rebuild restores; purge resets (P3).** `pyve init --force` / `pyve env init <name> --force` **snapshot-then-replay** the operational-state record: re-realize and re-install what was realized-and-installed; leave never-realized envs unrealized. Only `pyve purge` / `pyve env purge` truly destroys.
- **Batch lifecycle (`--all`).** `pyve init --force --all` fans the rebuild across every declared env — killing the N×`env init`/`env install` chore.
- **`pyve env purge` no-arg consistency fix (P4).** Bare `pyve env purge` operates on the *default* env (like its siblings); `pyve env purge --all` is the explicit sweep.

### The verb model (Option B — apt mental model)

Three distinct operations on a disturbance spectrum, named to stay legible:

| Intent | Touches | Command |
|---|---|---|
| Refresh Pyve's managed files (scaffolding, `.gitignore`, manifest version, project-guide) | files **around** the project, not envs | `pyve update` (exists) |
| Re-resolve / upgrade env deps, keep the env, restore state, re-lock | **env deps** | `pyve upgrade` (new) |
| Purge + rebuild the env, restore state | **env dir** (destructive) | `pyve init --force` / `pyve env init <name> --force` |

The one-sentence boundary that keeps `update` and `upgrade` legible (pinned everywhere in docs and help):

> **`update` touches the files Pyve manages *around* your project; `init` / `force` / `upgrade` touch the *environments themselves*.**

This matches the widely-held apt model (`apt update` refreshes the index; `apt upgrade` installs newer versions) and meets the instinct users already have.

---

## 6. Command & verb matrix

| Intent | Root | Named env | All envs |
|---|---|---|---|
| First materialize (declarative) | `pyve init` | `pyve env init <name>` | (init materializes the declared set) |
| Upgrade deps, keep env, restore state | `pyve upgrade` | `pyve upgrade --env <name>` | `pyve upgrade --all` |
| Purge + rebuild, restore state | `pyve init --force` | `pyve env init <name> --force` | `pyve init --force --all` |
| Reset / destroy (no restore) | `pyve purge` | `pyve env purge <name>` | `pyve purge --all` |
| Refresh Pyve scaffolding (no env) | `pyve update` | — | `pyve update` |

"Restore state" is powered by the operational-state record (§5). Bare `pyve env <sub>` (no name) → the **default** env, uniformly.

---

## 7. Scope — v3.1.0 (in) vs deferred (out)

**In scope (v3.1.0 / Subphase P-1):**

- The keystone parameter decision-graph + the plugin contribution hook.
- `pyve.toml` as the sole, explicit, version-stable declaration (Pillar I).
- The operational-state record + restore-on-rebuild + batch lifecycle + the `update`/`upgrade`/`force` verb model + the `env purge` consistency fix (Pillar II).
- User-facing CLI consistency (the `testenv`→`env` suggestion sweep).

**Deferred (out of scope here):**

- **Opinionated env templates / scenario presets** — the FastAPI+SvelteKit monorepo, PyTorch-vs-Keras isolation, "where does PyTorch go" cases. A follow-on templated feature (checkbox-or-detect → apply an opinionated multi-env config onto the explicit `pyve.toml`). The keystone is designed so templates plug in as pre-seeded subtree answers; the opinions themselves are not P-1.
- **Harden & heal (v3.2.0+, Subphase P-2 and beyond)** — runnability probes, resolution reasoning, `pyve heal` / `pyve check --fix`, and the test-isolation leak. See §8.

---

## 8. Roadmap — how this foundation frames the rest of Phase P (the P.d framework)

Phase P is one arc in two acts, and **Act 1 is the substrate Act 2 stands on** — which is exactly why the UX foundation comes first:

- **Act 1 — UX Foundation (v3.1.0, this subphase).** Make the declaration complete and explicit, the config single-sourced, and the lifecycle reproducible.
- **Act 2 — Harden & heal (v3.2.0+, later subphases).** Make environment *resolution* explainable and Pyve's managed state *self-healing*.

The dependency is real, not rhetorical:

- **`pyve heal` needs a complete, explicit declaration + the operational-state record to know what "correct" looks like** and to restore it. You cannot heal toward an intent the manifest doesn't fully capture (Pillar I) or a prior operational reality you never recorded (Pillar II).
- **Runnability probes and resolution reasoning build on explicit pins.** "`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13)" is only diagnosable when the pin and backend are authoritatively declared, not split across `.pyve/config`.
- **The state record turns "rebuild" into a safe heal action.** Act 2's destructive repairs (rebuild a drifted `.venv`) are the same snapshot-then-replay mechanism Pillar II ships, now triggered by a detected fault instead of a developer command.

**Story P.d** (deferred) uses this framework to break down Act 2: the runnability/healing pillars from the Phase P preamble decompose into Subphase P-2's roster when that subphase is activated. The candidate stories for it are parked in `stories.md` § *Future* until then.

---

## 9. Breaking changes & version target

Target: **v3.1.0 (minor).** The two changes that need the `plan_production_phase` breaking-change pass:

- **`pyve env purge` no-arg flip** — today sweeps all envs; proposed default is the single default env. *Behavior-breaking* for any script relying on the old sweep, but a CLI-ergonomics fix on a young surface that clears as **trivially-breaking** (the explicit `--all` preserves the old behavior); minor is appropriate.
- **`pyve upgrade` (new verb)** — additive; non-breaking.

The deeper `pyve.toml`-sole-source change removes the v2 `.pyve/config` write, but the v3.0 read-compat layer means existing v2-configured projects still function — so it is not user-breaking within the v3.x window.

---

## 10. Open questions (resolve during story breakdown)

1. **Graph schema in Bash** — the architectural spike decides the concrete representation (associative-array tables vs a generated dispatch) and proves the plugin-contribution seam before the full extraction.
2. **`upgrade` granularity** — does `pyve upgrade` re-resolve to newest-within-constraints and re-lock, or honor an existing lock? (Likely: bump + re-lock; `--check` to preview.)
3. **State-record schema** — the exact installed-spec hash inputs per backend (venv: the resolved requirement set; conda: already has `manifest_sha256`), and how `--force` snapshots before purge.
4. **Phase name** — "UX Overhaul; Harden and heal Pyve" is set; preamble reframed to match. (Cosmetic.)
