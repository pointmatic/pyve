# Spike N.ao — project-guide wizard integration + Python-`utility`-`root` provisioning

**Type:** integration + architectural (per `developer/best-practices-guide.md` § "Hello World First — Spike Early, Spike Often").
**Status:** complete — deliverable is this design + the follow-up breakdown below. **No production `lib/` code** was written.
**Question:** Will the pyve `init` wizard and the `project-guide` sibling tool connect cleanly across non-Python stacks, and does the "a Python `utility` `root` env hosts project-guide" design (established by Story N.aj's active-gate) hold on the *provisioning* side?

---

## 1. Findings — where the code is today

Grounded by reading [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh), [lib/utils.sh](../../lib/utils.sh), [pyve.sh](../../pyve.sh).

1. **`pyve init` is monolithic Python-first.** The dispatcher routes `init` → `plugin_dispatch python init` → `init_project` ([lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh)). `init_project` runs for **every** project regardless of stack and **always** materializes a Python env — `.venv/` (venv backend) or `.pyve/envs/<name>/` (micromamba). There is no CLI-routed Node-app init path yet (consistent with the post-N-4 note in [tech-spec.md](tech-spec.md): only the per-env runtime commands remain Python-routed).
2. **The project-guide hook is welded to the Python env and fires late.** `_init_run_project_guide_hooks <backend> <env_path> <pg_mode> <comp_mode>` is called at the *tail* of `init_project` (both the venv and micromamba branches), passing the **Python app env path** (`.venv` or `.pyve/envs/<name>`). It owns the install decision, the `pip install --upgrade project-guide`, the `project-guide init|update --no-input` scaffold, and the shell-completion wiring.
3. **`install_project_guide <backend> <env_path>`** ([lib/utils.sh](../../lib/utils.sh)) assumes a Python env: venv → `$env_path/bin/pip`, micromamba → `micromamba run … pip`. It cannot host project-guide without a Python env on disk.
4. **The `[Y/n]` prompt is Python-plugin-private.** `prompt_install_project_guide` ([lib/utils.sh](../../lib/utils.sh), default **Y**) is reachable only from inside the Python hook at #2. It is *stack-agnostic in content* ("Install project-guide?") but *Python-bound in placement*.
5. **The manifest scaffolder already declares a `root` env, but with no backend.** `_init_write_pyve_toml` writes `[env.root] purpose = "utility"` (no `backend`) + `[env.testenv] purpose = "test" default = true`; `_init_write_pyve_toml_polyglot` adds `[plugins.python]` + `[plugins.node]`.
6. **The N.aj active-gate already reads the contract correctly.** `python_plugin_is_active_in_project` ([lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh)) returns *active* on any of: `[plugins.python]` declared; an `[env.*]` with a `venv`/`micromamba` backend (or `languages` incl. python); **`.project-guide.yml` present**; `.pyve/config` present; root-scoped Python files. So a Node-only project that has installed project-guide is *already* treated as Python-active (the N.aj test `active: package.json present BUT project-guide installed` pins this).

**The gap, precisely.** Today the welded path "works" only because `init_project` *always* builds a Python env first, so project-guide always has a host. The contract breaks the moment `pyve init` becomes **composed/cross-stack** — i.e. when a Node-only (or Node-rooted polyglot) project no longer gets a Python *application* env by default. At that point, accepting the project-guide prompt has **no defined host env to install into**, and the prompt itself is unreachable because it lives inside the Python plugin's tail. N.aj wired the *read* side (the gate recognizes a project-guide-implied utility root); the *write* side (standing that root up) does not exist.

---

## 2. Provisioning design — the Python `utility` `root` env

**Decision: the project-guide host is a dedicated `utility` `root` venv, distinct from any application env.**

- **Declaration.** When project-guide is accepted on a stack that has no Python *application* env, write/ensure an explicit block in `pyve.toml`:
  ```toml
  [env.root]
  purpose = "utility"
  backend = "venv"
  ```
  This upgrades the always-scaffolded `[env.root] purpose = "utility"` (finding #5) with an explicit `backend = "venv"`. **Do not** add `[plugins.python]` — the project is not a Python *app*; declaring the plugin would pull in the full Python app-env semantics (e.g. expecting `.venv`, emitting an app `VIRTUAL_ENV` activation). The `[env.root] backend = "venv"` line is *exactly* the N.aj gate's signal #2, so the read side already agrees with this write side — no gate change needed. (Confirmed against `python_plugin_is_active_in_project`.)

- **Materialization path.** Build the venv at **`.pyve/envs/root/venv/`** via `resolve_env_path "root"` (the v3 state-layout helper in [lib/envs.sh](../../lib/envs.sh); see the project-essential "v3 state directory is `.pyve/envs/<name>/<backend>/`"). Crucially this is **not** `.venv` — `.venv` is the Python *application* env, which a Node-rooted project does not have. The utility root is a tool-hosting sidecar, not the project's runtime.

- **Install target.** Point `install_project_guide "venv" ".pyve/envs/root/venv"` at the utility root. The existing venv branch (`$env_path/bin/pip`) works unchanged once `env_path` is the root venv. The scaffold (`project-guide init|update --no-input`) and completion wiring are env-path-agnostic and follow.

- **Composition with a Node app (S4 root-cardinality).** No collision. The S4 cardinality rule is "two *plugins* cannot both own path `.`"; the utility root is an **env**, not a plugin-at-root. A Node app owns `.` (or a sub-path) as `[plugins.node]`; the Python utility root is `[env.root]` materialized under `.pyve/envs/root/venv/` and is **not** a `[plugins.python]` declaration. Polyglot stays: `[plugins.node]` (app) + `[env.root] backend = "venv"` (utility) coexist with no path contention.

- **Open implementation subtlety (flag for the follow-up).** With `[env.root] backend = "venv"` present but **no** `[plugins.python]`, the N.aj gate makes Python *active*, so `compose_check` / `compose_status` will dispatch the Python plugin's hooks. Those hooks today assume an *application* env (look for `.venv`, report app backend). They must learn a **utility-root-only** mode: report the health of `.pyve/envs/root/venv/` (and the hosted project-guide), **not** complain about a missing `.venv`. This is the one real behavioral change the provisioning implies and is the highest-risk follow-up item.

---

## 3. Wizard prompt placement

**Decision: lift the project-guide question to a stack-agnostic, pre-plugin orchestration step.**

- **Placement.** The prompt ("Use Project-Guide to help you set up and develop?", default `[Y/n]`) must move out of the Python-plugin tail (finding #2/#4) to the composed `pyve init` orchestration — *early*, before per-plugin env materialization, so the answer can (a) drive whether a `utility` `root` block is written to `pyve.toml` and (b) be answered identically for Python-only, Node-only, and polyglot.
- **New locus.** Extract a stack-agnostic `lib/project_guide.sh` (or a composed-init orchestration section in `pyve.sh`) owning: the prompt, the accept→provision decision, the install/scaffold/completion sequence against the *resolved host env path*. The Python-plugin-private helpers (`_init_run_project_guide_hooks`, and the `install_project_guide` / `prompt_install_project_guide` calls) are the lift source. Per the project-essential "`lib/commands/<name>.sh` is for command implementations only" + the cross-stack nature, project-guide orchestration is shared infrastructure → it belongs in `lib/`, not in any one plugin.
- **Host-env resolution at accept-time.**
  - Python app present (`.venv` / micromamba) → host project-guide in the app env (today's behavior; no regression).
  - No Python app env (Node-only / Node-rooted polyglot) → provision the `utility` `root` venv (§2) and host there.
  - This keeps the prompt's *content* unchanged while making its *placement* and *target* cross-stack.
- **Sequencing with composition.** The accept decision must run **before** `compose_project_envrc` / `compose_project_gitignore` and before the manifest is finalized, so the `[env.root] backend = "venv"` block is present when the composers and the gate read the manifest.

---

## 4. Cross-repo contract

Written as a self-contained change-request spec per the project-essential "Cross-repo coordination with `project-guide` — request, don't work around":

➜ **[project-guide-requests/wizard-env-contract.md](project-guide-requests/wizard-env-contract.md)**

It captures: the `.project-guide.yml` filename/shape contract (load-bearing — pyve keys behavior off it, N.aj makes it a Python-active signal); the breaking-change protocol if `project-guide` renames/reshapes it; the `plan_envs` ↔ wizard hand-off (who authors `pyve.toml`, who validates) keyed off the drafted [env-dependencies-template.md](project-guide-requests/env-dependencies-template.md) / [env-dependencies-prompt.md](project-guide-requests/env-dependencies-prompt.md); and the **minimum `project-guide` version** the wizard integration will depend on (to be pinned at the implementing story, alongside the existing `--no-input ≥ 2.2.3` precedent).

---

## 5. Follow-up story breakdown + subphase recommendation

Concrete implementation stories (each lands real `lib/` code + tests; this spike emits the plan only):

| # | Story (proposed) | Scope | Risk |
|---|---|---|---|
| F1 | **Lift project-guide orchestration to a stack-agnostic locus** | Extract `lib/project_guide.sh` (prompt + accept-decision + install/scaffold/completion against a resolved host env path); rewire `init_project` to call it instead of the welded `_init_run_project_guide_hooks`. Pure relocation + seam — no behavior change for Python-only. | Med (touches the heavily-tested init tail + project-guide G.* tests) |
| F2 | **`utility`-`root` provisioning on non-Python stacks** | When accepted with no Python app env: write `[env.root] backend = "venv"`, materialize `.pyve/envs/root/venv/` via `resolve_env_path`, install project-guide there. | Med |
| F3 | **Python plugin utility-root-only check/status mode** | Make the Python check/status hooks report a utility-root (`.pyve/envs/root/venv/` + hosted project-guide) instead of demanding `.venv`, when `[plugins.python]` is absent but `[env.root] backend = "venv"` is present. (The §2 subtlety — highest-risk.) | **High** |
| F4 | **`pyve env sync` — `plan_envs` spec consumption** | `pyve env sync` ingests §4 of `docs/specs/env-dependencies.md`, validates against `pyve_schema`, presents a live diff vs `pyve.toml`, and `[Y/n]`-applies (writes `pyve.toml` only; default `Y`; destructive diffs default `N`). Plus `pyve check`'s stateless live-diff surface (warn severity). Per the drift-reconciliation model in [wizard-env-contract.md](project-guide-requests/wizard-env-contract.md) §C–§D. Gated on the upstream `plan_envs` release + the contract. | Med (cross-repo dependency) |
| F5 | **`.project-guide.yml` contract guard + spec discovery** | A pyve-side test asserting the gate's `.project-guide.yml` dependency is intact + a documented min-version pin (the breaking-change tripwire); plus `env_spec_path` discovery (read from `.project-guide.yml`, default `docs/specs/env-dependencies.md`). | Low |
| F6 | **Closed env vocabulary + no-op trichotomy** | Pyve owns a versioned, forward-looking closed vocabulary for `purpose`/`backend`/`language`/`framework`/`app_type` (implemented + no-op sets in `pyve_toml_helper.py`). Implement the trichotomy: known-implemented → materialize; known-no-op → record + advisory, skip materialization; unknown → hard error + abort. Today only `purpose` (`VALID_PURPOSES`) is closed-set-validated. Per [wizard-env-contract.md](project-guide-requests/wizard-env-contract.md) §A–§B. | Med |

**Subphase recommendation (since acted on).** These follow-ups depend on a **composed/cross-stack `pyve init`** (where a Node-only project does *not* get a Python app env) — a capability that did not exist when this spike was written (init is still monolithic Python-first, finding #1), and that was architecturally distinct from every phase-N subphase theme at the time. The recommendation was a **dedicated new subphase**; it has since been acted on: **Subphase N-6 (`pyve init` composed/cross-stack refactoring)** now owns the composed-init materialization umbrella that F1–F5 sit under. The surrounding tail renumbered accordingly — **N-5** `pyve deploy`, **N-7** test consolidation, **N-8** docs, **N-9** the v3.0.0 release, **N-10** post-release UX + hard migration gate.

**Subphase creation is plan-mode's job.** Per the mode's scope-of-authority rule (`go.md` § Rules), creating a `## Subphase` heading and bundling its stories is `plan_phase` / `plan_production_phase`'s exclusive job — not this mode's. The N-6 heading + theme were authored by the developer; the F1–F5 story breakdown within N-6 still awaits `plan_production_phase`. This spike neither created the subphase nor appended F1–F5 as stories.

---

## 6. Spike verdict

The N.aj design **holds on the provisioning side** with one named behavioral consequence (the §2 utility-root-only check/status mode, F3). The connection between the pyve wizard and `project-guide` is clean **provided** (a) the project-guide orchestration is lifted out of the Python plugin to a stack-agnostic locus, and (b) the `.project-guide.yml` contract is formalized as a versioned cross-repo dependency. No blocker found; the path is viable. Deliverable complete.
