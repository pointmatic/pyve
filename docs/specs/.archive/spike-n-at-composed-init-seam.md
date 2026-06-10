# spike-n-at-composed-init-seam.md — Integration + architectural spike for composed cross-stack `pyve init` (Story N.at)

**Status:** Spike artifact for Subphase N-6 (drafted 2026-06-05). **Not** an implementation spec. The deliverable is two documented contract decisions — (1) the composed-init dispatch seam, and (2) Pyve's toolchain-interpreter resolution — each validated by throwaway bash probes against the four Phase-N project shapes. No production `lib/` code was written; the probe scripts were deleted after capture.

**Type:** integration + architectural (per `developer/best-practices-guide.md` § "Hello World First"), mirroring [spike-n-ae-envrc-composer-contract.md](spike-n-ae-envrc-composer-contract.md).

**Questions this spike answers:**
- **Composed-init.** Can `pyve init` run a composed cross-stack flow — `manifest_load` → `plugin_load_all_from_manifest` → per-plugin materialize dispatch — across Python-only / Node-only / polyglot fixtures, with the project-guide prompt lifted to orchestration level and the `utility` `root` (F2) hanging off the accept decision? Does the N.ao paper design hold against the code?
- **Toolchain interpreter (widened scope, developer-requested 2026-06-05).** The composed-init probe surfaced that Pyve's own manifest parse depends on a developer-environment `python`, which can fail on a clean non-Python stack. How should Pyve resolve its toolchain interpreter so a Node-only project's `pyve.toml` always parses?

**Input:**
- [spike-n-ao-project-guide-provisioning.md](spike-n-ao-project-guide-provisioning.md) (the paper design this spike validates in code), [project-guide-requests/wizard-env-contract.md](project-guide-requests/wizard-env-contract.md).
- Shipped code: [lib/plugins/registry.sh](../../lib/plugins/registry.sh) (`plugin_load_all_from_manifest`, `plugin_list_active`), [lib/manifest.sh](../../lib/manifest.sh) (`manifest_load`, accessors), [lib/envs.sh](../../lib/envs.sh) (`resolve_env_path`, `state_path`), [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh) (`python_pyve_plugin_init` → `init_project`, `_init_run_project_guide_hooks`, `python_plugin_is_active_in_project`, `check_environment`), [lib/plugins/node/plugin.sh](../../lib/plugins/node/plugin.sh) (`node_pyve_plugin_init`), [lib/check_composer.sh](../../lib/check_composer.sh), [lib/envrc_composer.sh](../../lib/envrc_composer.sh) `compose_project_envrc` (the canonical reload seam).

---

## Part 1 — Composed-init dispatch seam

### Open questions

- **Q1 — Enumeration.** Does the `manifest_load → plugin_registry_reset → plugin_load_all_from_manifest` seam (copied from `compose_project_envrc`, [lib/envrc_composer.sh:216-220](../../lib/envrc_composer.sh#L216)) yield the correct active set per stack, with no false S4 cardinality error on legitimate shapes and a real error on a true collision?
- **Q2 — Materialize dispatch.** Can the composer dispatch each active plugin's init/materialize hook uniformly? Do the two reference plugins' init-hook signatures conform?
- **Q3 — Utility-root provisioning (F2).** With project-guide accepted on a Node-only stack, does writing `[env.root] backend = "venv"` + materializing via `resolve_env_path "root"` land the utility venv where N.ao §2 says (`.pyve/envs/root/venv/`)?
- **Q4 — F3 risk.** With `[env.root] backend = "venv"` present but no `[plugins.python]`, do `compose_check` / `compose_status` dispatch the Python hooks, and what do those hooks assume?

### Probe findings (empirical)

Two throwaway probes sourced the real libraries and exercised four fixtures. **All results below were captured with a working interpreter (`PYVE_PYTHON` pointed at a real Python 3.12 binary).** Without that — see Part 2 — `manifest_load` silently fails and every fixture mis-enumerates as implicit-Python.

**Q1 — Enumeration: YES.** The seam returns exactly:
- Python-only (`[env.root]`/`[env.testenv]`, no `[plugins.*]`) → `python` (implicit-Python, S5).
- Node-only (`[plugins.node]`) → `node`. **No Python plugin, no Python app env.**
- Polyglot (`[plugins.python]` + `[plugins.node] path="src/frontend"`) → `python` (path `.`), `node` (path `src/frontend`).
- S4 collision (`[plugins.python]` + `[plugins.node]` both at root) → hard error `multiple plugins both claim the project root`, rc 1. ✓

**Q2 — Materialize dispatch: PARTIAL — signatures diverge; no uniform hook.**
- Node's `node_pyve_plugin_init [<path>] [<backend>]` ([lib/plugins/node/plugin.sh:333](../../lib/plugins/node/plugin.sh#L333)) is already **composed-ready**: it takes a path, detects the provider, and materializes `node_modules` at that path.
- Python's `python_pyve_plugin_init` ([lib/plugins/python/plugin.sh:186](../../lib/plugins/python/plugin.sh#L186)) wraps the **monolithic** `init_project`, which parses the full CLI flag set (`--backend`/`--python-version`/`--no-direnv`/…), materializes exactly one Python env, **and** runs `.pyve/config` + manifest scaffolding + `.envrc`/`.gitignore` composition + the project-guide hooks at its tail. It is not a per-env materializer; it is the whole legacy init.
- The plugin contract ([lib/plugins/contract.sh](../../lib/plugins/contract.sh)) has **no** `materialize` hook — only `init` (and `purge`/`update`/`check`/`status`/`run`/`test`/`activate`/`gitignore_entries`/`purge_inventory`).

**Q3 — Utility-root provisioning: N.ao §2 IS WRONG ABOUT THE PATH.** `resolve_env_path "root"` is a hard special-case that returns **`.venv`**, ignoring backend ([lib/envs.sh:452-456](../../lib/envs.sh#L452)) — it does **not** return `.pyve/envs/root/venv/`. (The N.ae.2 refinement note already recorded "`resolve_env_path root` returns `.venv` regardless of backend"; N.ao §2 was authored without reconciling that.) Two consequences:
- A utility root materialized via `resolve_env_path "root"` would land at `.venv` — the slot N.ao §2 explicitly said to avoid ("Crucially this is **not** `.venv`").
- The helpers are **internally inconsistent** for the reserved name: `resolve_env_path root` = `.venv`, but `state_path root` = `.pyve/envs/root/.state`. The env and its state file live in different trees.

**Q4 — F3 risk: the predicted failure is INVERTED — worse, not as N.ao described.** For the Node-only + `[env.root] backend="venv"` + `[plugins.node]` fixture (project-guide accepted, no `[plugins.python]`):
- `plugin_list_active` = **`[node]`** — the Python plugin is **NOT registered**. Registration keys off `[plugins.<name>]` declarations (or implicit-Python when zero plugins); an `[env.*] backend="venv"` block does **not** register the Python *plugin*.
- `python_plugin_is_active_in_project` returns **ACTIVE** (the N.aj gate's signal #2, `[env.root] backend="venv"`, fires) — **but that function is never reached**, because it is an *in-hook suppression guard* inside `python_pyve_plugin_check`/`_status` ([lib/plugins/python/plugin.sh:365,377](../../lib/plugins/python/plugin.sh#L365)), and the hook is only dispatched for plugins in `plugin_list_active`.
- **Net:** `compose_check` / `compose_status` iterate `[node]` only and **never dispatch the Python hook at all**. N.ao §2 predicted "compose_check / compose_status **will dispatch** the Python plugin's hooks [which] assume an application env." Reality: they **do not dispatch it**, so the project-guide utility root gets **zero** check/status coverage.
- Independently: even if Python *were* dispatched, `check_environment` reads `.pyve/config` first (`config_file_exists` → `_check_fail "missing"` → exit; then `read_config_value backend` / `venv.directory`) — **not** the manifest. A utility-root-only project has no `.pyve/config`. So the F3 surface to change is two-fold: (a) get Python *into* the active set, and (b) re-source backend + env-path from the manifest `[env.root]`, not `.pyve/config`.

### Decision (the composed-init contract)

1. **Reload seam.** Composed init uses the same three-line seam the other composers use, run **after** the manifest is written: `manifest_load` → `plugin_registry_reset` → `plugin_load_all_from_manifest` → iterate `plugin_list_active`. Proven correct for all four shapes.

2. **Uniform materialize dispatch via the existing `init` hook + path arg — Node's shape is the target.** The composer dispatches `plugin_dispatch <name> init "$(manifest_get_plugin_path <name>)"` per active plugin. Node already conforms. **Python's `init` hook must be refactored (N.av) to separate env materialization from orchestration**: the per-env Python materializer (create venv/micromamba at the resolved path) becomes the hook body; the `.pyve/config`/manifest/`.envrc`/`.gitignore`/project-guide tail moves **up** to the composed-init orchestrator (project-guide specifically → F1/`lib/project_guide.sh`). A new named `materialize` hook is **not** introduced — overloading the existing `init` hook keeps the contract's hook set stable and matches Node.

3. **Utility-root path (corrects N.ao §2).** Do **not** rely on `resolve_env_path "root"` for the project-guide utility venv — it returns `.venv`. F2 (N.aw) must pick one explicitly and the decision is load-bearing:
   - **Recommended:** materialize the utility root at **`.pyve/envs/root/venv/`** via a dedicated path (not the `root` special-case), so a non-Python stack never grows a top-level `.venv` (which reads as "this is a Python app"). This requires either teaching `resolve_env_path` a utility-root branch or having F2 construct the path through a new helper — **not** string concatenation (per the "v3 state directory … route through helpers" essential). Also reconcile the `state_path root` vs `resolve_env_path root` split while here.
   - **Alternative (cheaper, accept the wart):** let the utility root be `.venv` on a Node-only stack, since no Python *app* env competes for it. Rejected as the default because it muddies the app-vs-utility distinction the `purpose` vocabulary exists to draw.

4. **F3 — get Python into the active set, then add a utility-root-only mode.** The real fix (N.ax) is a **registration-gate** change: `plugin_load_all_from_manifest` (or a Python-plugin self-registration hook) must register the Python plugin when an `[env.*]` declares a `venv`/`micromamba` backend (or `languages: python`) — i.e. align the registration gate with the N.aj *activation* gate, which already recognizes that signal. **Without this, the utility root is invisible to `check`/`status`.** Then `check_environment` gains a utility-root-only mode that sources backend + env-path from the manifest `[env.root]` instead of `.pyve/config`, and reports the health of the utility venv + hosted project-guide rather than demanding `.venv`. Do **not** solve F3 by writing `[plugins.python]` for a utility root — that pulls in full app-env semantics (N.ao §2), the opposite of intent.

5. **Sequencing.** The project-guide accept decision runs at orchestration level **before** per-plugin materialization and **before** `compose_project_envrc` / `compose_project_gitignore` / manifest finalization — so the `[env.root] backend="venv"` block (and the consequent Python registration, per #4) is present when the composers, the registration gate, and the activation gate read the manifest. This matches N.ao §3 and the N.ae.5 ordering.

---

## Part 2 — Toolchain-interpreter resolution

### The gap (surfaced by the Part 1 probe)

Every Pyve callsite that needs Python resolves it as `local py="${PYVE_PYTHON:-python}"` — [manifest.sh:73](../../lib/manifest.sh#L73), [envs.sh:66](../../lib/envs.sh#L66), [env_detect.sh:336](../../lib/env_detect.sh#L336), [commands/env.sh:144](../../lib/commands/env.sh#L144) — falling back to **bare `python` on PATH**. `pyve self install` ([lib/commands/self.sh](../../lib/commands/self.sh)) copies the bash scripts to `~/.local/bin` and creates **no** interpreter of its own. `assert_python_resolvable` ([lib/env_detect.sh:330](../../lib/env_detect.sh#L330)) only *diagnoses* the asdf/pyenv-shim trap; it provides no interpreter.

**Empirical failure (not just a probe artifact).** In a bare directory with no `.tool-versions`, the asdf `python`/`python3` shims error (`No version is set for command python`). `manifest_load` then fails, and because production wraps it `2>/dev/null || true`, the registry silently falls back to implicit-Python — so a **Node-only project mis-enumerates as Python**. On a Python-first monolithic init this is invisible (Pyve is setting up a Python anyway); composed cross-stack init is exactly where it bites.

**Proof a self-owned interpreter fixes it.** A throwaway venv built from a real 3.12 binary parsed `[plugins.node]` from the same bare dir where the shim errored — its interpreter is a concrete binary, independent of cwd / asdf state.

### Options evaluated

| Option | Mechanism | Verdict |
|---|---|---|
| **1. Self-owned hidden venv** | `pyve self install` builds a Pyve-owned venv once; all `${PYVE_PYTHON:-…}` callsites resolve to it. | **Chosen** (see Decision). Robust, isolated from dev envs. |
| 2. Repackage as pip/pipx app | Ship Pyve as a wheel so pipx gives it an isolated venv. | Rejected — a distribution overhaul for a bash-first tool; Homebrew remains the primary channel. |
| 3. Vendored pure-bash TOML reader | Drop the Python dependency for manifest parsing. | Rejected for the full helper — `pyve_toml_helper.py` (244 LOC) also normalizes + closed-set-validates + emits a wire format; a bash reimplementation is fragile and risks dual-parser drift (a second helper, `pyve_testenvs_helper.py`, exists too). A *narrow* bash pre-reader remains a last-resort fallback only. |

### Decision (developer-directed, 2026-06-05)

**Pyve owns its toolchain Python in a hidden venv that exists independently of the developer's environment.**

- **Version tracking.** The toolchain venv is built on **Pyve's default Python version** — `DEFAULT_PYTHON_VERSION` ([pyve.sh:33](../../pyve.sh#L33), currently `3.14.4`), owned by the Python plugin. It moves when that default moves. (Any version ≥ 3.11 satisfies the `tomllib` requirement; 3.14.4 does.)
- **Shim convergence.** When the developer's environment already uses the same version, the version-manager shim resolves to the same binaries — zero duplication. When it differs (or no dev Python exists), Pyve still has a **reliable** interpreter. This is the explicit goal: *stop borrowing from the developer's environment.*
- **Resolution.** All `${PYVE_PYTHON:-python}` callsites gain the Pyve-owned venv as the authoritative source ahead of bare `python`. `PYVE_PYTHON` (explicit override) stays the highest-priority escape hatch — the tests already rely on it.
- **Provisioning locus.** The venv is created/refreshed by `pyve self install` (and adopted by the Homebrew formula). Bootstrap chicken-and-egg (a Python is needed once to *build* the venv) is a one-time install concern, resolvable via the same version-manager Pyve already drives for project envs.

This is a **new follow-up story** (proposed below), not part of N.at's deliverable. It is a **prerequisite for the cross-stack robustness of N-6**: composed init on a Node-only stack must parse `pyve.toml` reliably. Whether it gates N-6 or ships alongside is a `plan_production_phase` decision flagged at the approval gate.

---

## Corrections this spike makes to the N.ao paper design

1. **`resolve_env_path "root"` returns `.venv`, not `.pyve/envs/root/venv/`** (N.ao §2 "Materialization path"). F2 must place the utility root explicitly; it cannot lean on the `root` helper.
2. **The F3 risk is inverted.** N.ao §2 said the Python check/status hooks *would be dispatched and wrongly demand `.venv`*. In fact they are **not dispatched at all** for a utility-root-only project, because the **registration** gate (`plugin_list_active`) ≠ the **activation** gate (`python_plugin_is_active_in_project`). The fix is to align them (register Python on a python-backed `[env.*]`), *then* add the manifest-sourced utility-root mode.
3. **A toolchain-interpreter dependency exists** that N.ao never surfaced (paper spike). Composed cross-stack init makes it load-bearing.

## Impact on the N-6 follow-up stories

- **N.au (F1)** — unchanged in intent; confirmed locus `lib/project_guide.sh`, lifted to run *before* materialization.
- **N.av (composed-init core)** — must refactor `python_pyve_plugin_init` to a per-env materializer (Decision §2); the orchestration tail moves up. Node already conforms.
- **N.aw (F2)** — **add an explicit utility-root path decision** (Decision §3); do not use `resolve_env_path "root"`.
- **N.ax (F3, highest risk)** — **scope grows**: it is a registration-gate alignment *plus* the manifest-sourced utility-root check/status mode (Decision §4), not just the latter.
- **New (toolchain Python)** — propose a story for the Pyve-owned hidden venv (Part 2 Decision), sequenced ahead of / alongside the composed-init core as a `plan_production_phase` call.

## Spike verdict

The composed-init seam is **viable** — enumeration, S4 cardinality, and polyglot path-routing all work in code. But the path is **not** the one N.ao drew on paper: three concrete corrections (utility-root path, inverted F3, toolchain interpreter) change the shape of N.aw / N.ax and add a prerequisite story. No blocker; the refactor is safe to commit **provided** F3 is treated as a registration-gate change and the toolchain interpreter is owned by Pyve. Deliverable complete.

### Throwaway artifacts

Two probe scripts (`/tmp/spike_nat_probe*.sh`) sourced the real libraries against four fixtures (Python-only, Node-only, Node-only+utility-root, polyglot, S4-collision) and a toolchain-venv bootstrap proof. Deleted after capturing the findings above, per the throwaway-spike rule. This document is the durable deliverable.
