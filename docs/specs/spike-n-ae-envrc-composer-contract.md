# spike-n-ae-envrc-composer-contract.md — Integration spike for `lib/envrc_composer.sh` (Story N.ae.1)

**Status:** Integration spike artifact for Subphase N-4 (drafted 2026-06-03 while working Story N.ae). **Not** an implementation spec. The deliverable is the documented composer ↔ plugin-activate **contract decision** in § *Decision*, validated by throwaway probes against the three Phase-N project shapes (Python-only, Node-only, polyglot Python+Node).

**Why a spike here (developer-chosen):** N.ae's tasks say `compose_envrc` should "dispatch each plugin's `pyve_plugin_activate` hook" and "retire the direct `.envrc` callsites." But the two reference plugins ship **divergent activate contracts**, and the main runtime venv sits outside the manifest's env model — so the composer ↔ activate boundary was unproven. Rather than commit a sweeping refactor of the heavily-tested `pyve init` path on an unproven contract, the developer chose an integration spike first.

**Trigger:** mid-N.ae discovery that (a) Node's `node_pyve_plugin_activate` *emits a sentinel-wrapped snippet to stdout* while Python's `python_pyve_plugin_activate` *writes the whole `.envrc`* via `bp_dispatch → write_envrc_template` (and N.q's byte-equivalence tests pin that file-write contract); (b) the main `.venv` / `VIRTUAL_ENV` is not named by any `[env.<name>]` block; (c) at fresh-`init` time the just-written `pyve.toml` is not yet loaded, so `plugin_list_active` would be stale.

**Input:**
- [phase-n-plugin-architecture-named-envs-plan.md](phase-n-plugin-architecture-named-envs-plan.md) § PC-1, PC-2, § N-4.
- Shipped code: [lib/plugins/registry.sh](../../lib/plugins/registry.sh), [lib/manifest.sh](../../lib/manifest.sh), [lib/envrc_safety.sh](../../lib/envrc_safety.sh), [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh) (`python_pyve_plugin_activate`, `_python_pyve_plugin_envrc_snippet`), [lib/plugins/node/plugin.sh](../../lib/plugins/node/plugin.sh) (`node_pyve_plugin_activate`, `_node_pyve_plugin_envrc_snippet`), [lib/utils.sh](../../lib/utils.sh) (`write_envrc_template`), [pyve.sh](../../pyve.sh) `main()`.

---

## Open questions this spike must answer

- **Q1 — Enumeration.** Does `plugin_list_active` (after `manifest_load` + `plugin_load_all_from_manifest`) return the correct active set for each project shape?
- **Q2 — Dispatch args.** With what argument(s) does the composer invoke each plugin's `pyve_plugin_activate`, given Node takes `<path>` and Python takes `<backend> <env_path> <env_name>`?
- **Q3 — Python reconstruction.** Can the composer reconstruct Python's activate args (backend / env_path / env_name) from the loaded manifest, given `.venv` is not named by any env block?
- **Q4 — Validation boundary.** Task 2 says "validate the entire body via `validate_envrc_snippet`." Does the composer-owned infrastructure (the `dotenv` `if`-block, the asdf reshim guard) pass PC-1? If not, what exactly is validated?
- **Q5 — PC-2 mechanics.** Do user-content preservation (below the managed end-marker) + atomic write (`.tmp` → `.prev` → `mv`) work as the plan describes?
- **Q6 — Init/update ordering.** Is the manifest loaded at the point in `init` where `.envrc` is emitted today?

## Probe findings (empirical)

Two throwaway bash probes sourced the real libraries and exercised the three fixtures. Results:

**Q1 — Enumeration: YES.** `plugin_list_active` returns exactly:
- pure-Python (empty manifest): `python` (implicit-Python, S5).
- Node-only (`[plugins.node] path="."`): `node`.
- polyglot (`[plugins.python]` + `[plugins.node] path="src/frontend"`): `python`, `node` (declaration order).

**Q2/Q3 — Dispatch args & Python reconstruction: RECONSTRUCTABLE (with one limitation).**
- `manifest_get_plugin_path <name>` returns the plugin's path (`.`, `src/frontend`, or empty/`.` for implicit-Python).
- Node needs only `<path>` — already conforms.
- Python's section needs `backend` / `env_path` / `env_name`. The probe confirmed `backend` is available from the default (or root) env via `PYVE_ENV_BACKEND` (e.g. `[venv venv]` with default index from `PYVE_ENV_DEFAULT`). `env_name` is the project name (`PYVE_PROJECT_NAME`). `env_path` is derivable by convention: `.venv` for the `venv` backend, `resolve_env_path root` (`.pyve/envs/root/conda`) for `micromamba`.
- **Limitation L1:** the **custom** venv directory from `pyve init <dir>` is *not* recorded anywhere in `pyve.toml`. A manifest-driven composer therefore assumes `.venv`. See § *Decision* → *Known limitations*.

**Q4 — Validation boundary: plugin sections only.** Confirmed empirically:
- A Node section (sentinel comments + `PATH_add "…"`) → **PASS**.
- A Python-style section (sentinel comments + `PATH_add` + four `export VAR="…"`) → **PASS**.
- The `dotenv` `if`-block → **FAIL** (`validate_envrc_snippet` rejects the multi-line `if [[ -f ".env" ]]; then`).
- The asdf guard `export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` → **FAIL** (PC-1 requires the value to be double-quoted; `=1` is unquoted).
- Therefore "validate the entire body" can only mean **validate the concatenated plugin sections**. The composer-owned infrastructure is static pyve text and is added *after* validation — exactly the plugin-vs-infrastructure boundary [lib/plugins/python/plugin.sh:307](../../lib/plugins/python/plugin.sh#L307) already documents from N.q.

**Q5 — PC-2 mechanics: YES.** User content below `# <<< pyve:managed:end <<<` round-trips verbatim via `awk -v m=<end-marker> 'f{print} $0==m{f=1}'`. Atomic rewrite (`cp -p .envrc .envrc.prev`; write `.envrc.tmp`; `mv -f .envrc.tmp .envrc`) preserves the user tail and leaves a `.envrc.prev` rollback copy.

**Q6 — Init/update ordering: RELOAD REQUIRED.** `pyve.sh`'s `main()` runs `manifest_load` + `plugin_load_all_from_manifest` **before** dispatch — but at fresh `init` the `pyve.toml` does not exist yet, so the registry holds only implicit-Python. After `init` writes the manifest (including a polyglot `[plugins.node]` from N.ad), the registry is stale. The composer callsite in `init`/`update` must therefore `manifest_load` → `plugin_registry_reset` → `plugin_load_all_from_manifest` **after** the manifest write, then call `compose_envrc`.

---

## Decision (the contract)

**1. Uniform activate = sentinel-wrapped snippet emitter, single optional `<path>` arg.**
`<name>_pyve_plugin_activate [<path>]` writes a sentinel-wrapped section to **stdout** and performs **no file write**:

```
# >>> pyve:plugin:<name>:activate >>>
PATH_add "…"
export VAR="…"
# <<< pyve:plugin:<name>:activate <<<
```

- **Node** already conforms.
- **Python** is refactored to conform: it self-resolves `backend`, `env_path`, and `env_name`, then emits its existing five-line snippet wrapped in `# >>> pyve:plugin:python:activate >>>` markers. The `bp_dispatch <backend> activate` file-write path is removed from the *activate hook* (the `*_pyve_bp_activate` shims and `_init_direnv_*` helpers remain for any non-composer caller, but the hook no longer writes).

  > **Refinement applied during N.ae.2 implementation.** The resolution source is **`.pyve/config`** (via `read_config_value`), *not* the manifest: `_init_write_pyve_toml` emits no `backend` line, and `resolve_env_path root` returns `.venv` regardless of backend, so the manifest is not the authoritative backend record. Resolution chain: `backend` = `.pyve/config` `backend` → manifest default-env backend → `venv`; venv `env_path` = `.pyve/config` `venv.directory` (honors a custom `pyve init <dir>` — partially retires **L1** below) → `.venv`; micromamba `env_path` = `.pyve/envs/<config micromamba.env_name>`; `env_name` = basename for venv, the micromamba env name for micromamba. `.pyve/config` is reliably present at compose time given the N.ae.5 ordering (write config → reload manifest → `compose_envrc`).

**2. Composer = assembler + PC-2 writer.** `compose_envrc <output_path>`:
1. enumerate `plugin_list_active`;
2. for each, `section="$(plugin_dispatch <name> activate "$(manifest_get_plugin_path <name>)")"` and concatenate → `plugin_body`;
3. `validate_envrc_snippet "$plugin_body"` — **plugin sections only**; on failure, halt with the offending plugin/line and leave the existing `.envrc` **untouched**;
4. assemble the full body: `# pyve-managed direnv configuration` header → `# >>> pyve:managed:start >>>` → `plugin_body` → composer infra (`if [[ -f ".env" ]]; then dotenv; fi`; asdf guard when `is_asdf_active`) → `# <<< pyve:managed:end <<<` → preserved user tail;
5. atomic write: emit to `<output_path>.tmp`; copy the current `<output_path>` to `<output_path>.prev`; `mv -f <output_path>.tmp <output_path>`. Fresh scaffold (no existing file) emits the managed section plus a trailing invitation comment below the end-marker.

**3. Validation boundary.** Only plugin-contributed sections pass through `validate_envrc_snippet`. Composer-owned infrastructure (dotenv block, asdf guard) is static pyve text added after validation — it cannot and should not pass the PC-1 allow-list.

**4. Markers.** Per-plugin: `# >>> pyve:plugin:<name>:activate >>>` … `# <<< pyve:plugin:<name>:activate <<<` (already shipped by Node). Managed envelope: `# >>> pyve:managed:start >>>` … `# <<< pyve:managed:end <<<` (the end-marker is the user-content boundary named in N.ae Task 4).

**5. Init/update rewiring.** Replace the direct per-plugin `.envrc` emission in `init_project` ([lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh), both backend branches) and `update_project` ([lib/commands/update.sh](../../lib/commands/update.sh)) with: `manifest_load` → `plugin_registry_reset` → `plugin_load_all_from_manifest` → `compose_envrc .envrc`, run *after* the manifest is written.

### Known limitations (documented, deferred)

- **L1 — custom venv dir.** *(Largely retired in N.ae.2.)* `pyve init <custom-dir>` is not recorded in `pyve.toml`, but it **is** recorded in `.pyve/config` (`venv.directory`), which the emitter reads — so a custom venv dir is honored whenever `.pyve/config` is present. The residual gap is only a project with a custom venv dir and no `.pyve/config` (not a state init produces). Recording the main env in the `pyve.toml` schema would make activation fully manifest-driven and is still a reasonable **follow-up**, but is no longer load-bearing for N.ae.
- **L2 — `--no-direnv`.** Unchanged: when `--no-direnv` is set, `init` skips `.envrc` emission entirely; `compose_envrc` is simply not called on that path.

### Test-contract impact (for the N.ae implementation that follows)

- **N.q byte-equivalence tests** assert `python_pyve_plugin_activate` *writes* `.envrc`. Under this contract the hook *emits a snippet*; those tests are updated to assert the emitted section (and the byte-equivalence of the composed `.envrc` against today's `write_envrc_template` output for the single-plugin case is the new equivalence target).
- **N.y Node activate tests** already assert the snippet-emitter shape — unchanged.

### Throwaway artifacts

The two probe scripts (`/tmp/spike_nae_probe*.sh`) were deleted after capturing the findings above, per the throwaway-spike rule. This document is the durable deliverable.
