# Migration guide — pyve v2.x → v3

Pyve 3 describes each project with the declarative [`pyve.toml`](pyve-toml.md) manifest and the plugin model. **As of v3.1 the v2 compatibility window is closed**: nothing reads `.pyve/config` anymore, the `pyve self migrate` bridge has been removed, and a project with only v2 configuration reads as **uninitialized**. The move to v3 is one command: re-run `pyve init`.

## What changes

| v2 | v3 |
|---|---|
| `.pyve/config` (YAML) + `[tool.pyve.testenvs.*]` in `pyproject.toml` | A single root-level [`pyve.toml`](pyve-toml.md) |
| "main env" + "testenvs" | Named `[env.<name>]` blocks with a `purpose` ([Named Environments](environments.md)) |
| State split across `.pyve/envs/` and `.pyve/testenvs/` | One root: `.pyve/envs/<name>/<backend>/` |
| `pyve testenv <sub>` | `pyve env <sub>` (the old spelling still works, with a warning; removed in v4.0) |
| One dependency source per env (`requirements` ⊕ `extra` ⊕ `manifest`) | Composable [setup directives](pyve-toml.md#setup-directives-a-composable-recipe), including `editable` |
| Python-only | Plugin model — Python and Node, more through the contract |

Your code, `pyproject.toml`, `package.json`, lockfiles, and non-empty `.env` files are never touched by migration.

## Migrating a v2 project (v3.1 and later)

1. **Upgrade Pyve** (`brew upgrade pointmatic/tap/pyve`, or `git pull && ./pyve.sh self install` from source).
2. **Re-run `pyve init`** in the project. The wizard re-detects the stack — the backend from `environment.yml` / `pyproject.toml`, the Python pin from `.tool-versions` / `.python-version` — and writes a fully-explicit `pyve.toml`. Add `--yes` to accept every default without prompting.
3. **On-disk environments migrate opportunistically.** A legacy env under `.pyve/testenvs/<name>/` is relocated to `.pyve/envs/<name>/<backend>/` the first time a command needs it. During a forced rebuild, a stray env whose backend contradicts the manifest is backed up to `.pyve/.v2-legacy/` — recoverable, never deleted.
4. **Re-declare named envs in `pyve.toml`.** Attributes that lived in `[tool.pyve.testenvs.<name>]` become an `[env.<name>]` block: `requirements` / `extra` / `manifest` / `lazy` / `backend` carry over one-to-one, `default = "<name>"` becomes `default = true` on the env itself — and the directives now [compose](pyve-toml.md#setup-directives-a-composable-recipe) (the v2 pick-one rule is gone), including the new `editable` directive.
5. **Verify.** `pyve status` (read the new manifest), `pyve check` (health). A leftover `.pyve/config` is inert — nothing reads it, and `pyve purge` deletes it opportunistically.
6. **Update scripts:** `pyve testenv …` → `pyve env …` (the alias keeps working until v4.0).

## The transition history

The v2 → v3 transition passed through two releases:

- **v3.0** shipped three coordinated surfaces: a read-compat layer (v2 sources synthesized into the v3 model in memory, so unmigrated projects kept working), a one-shot soft banner nudging toward migration, and the `pyve self migrate` bridge (write `pyve.toml` from v2 sources, back them up under `.pyve/.v2-legacy/`, rebuild).
- **v3.1** closed the window: the read-compat layer, the banner, and the `self migrate` bridge were all removed. `pyve self migrate` survives only as a reserved stub for future schema migrations (e.g. v3 → v4) — it recognizes no v2 sources.

**Still on v3.0.x?** You can run `pyve self migrate` there before upgrading to v3.1 — the smoothest path for a heavily-customized v2 project. On v3.1+, `pyve init` is the migration.

## CLI renames

The v2 → v3 command renames, aliased during the v3.x window:

| v2 form | v3 form | Status |
|---|---|---|
| `pyve testenv init` | `pyve env init` | `testenv` aliased with a one-shot warning; removed in v4.0 |
| `pyve testenv install` | `pyve env install` | aliased |
| `pyve testenv purge` | `pyve env purge` | aliased |
| `pyve testenv run` | `pyve env run` | aliased |

The diagnostics split from the v1.x → v2.0 era still holds: `pyve doctor` / `pyve validate` were replaced by `pyve check` (CI-safe `0`/`1`/`2`) and `pyve status` (read-only dashboard).

## Quick recipe

For a repo moving from v2 to v3.1+:

```bash
brew upgrade pointmatic/tap/pyve     # 1. upgrade Pyve
cd ~/my-v2-project
pyve init                            # 2. re-detect the stack, write pyve.toml
pyve status                          # 3. confirm the manifest reads correctly
pyve check                           # 4. verify health
```

Then re-declare any named test envs as `[env.<name>]` blocks, and update scripts from `pyve testenv` to `pyve env`.
