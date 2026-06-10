# Migration guide — pyve v2.x → v3.0

Pyve 3.0 introduces the declarative [`pyve.toml`](pyve-toml.md) manifest and the plugin model. Your v2 project keeps working against a v3.0 binary **without** an immediate migration — but the clean, permanent move is one command: `pyve self migrate`.

This guide covers what changes, the one-step migrator, and the three coordinated surfaces that manage the transition window.

## What changes

| v2 | v3 |
|---|---|
| `.pyve/config` (YAML) + `[tool.pyve.testenvs.*]` in `pyproject.toml` | A single root-level [`pyve.toml`](pyve-toml.md) |
| "main env" + "testenvs" | Named `[env.<name>]` blocks with a `purpose` ([Named Environments](environments.md)) |
| State under `.pyve/envs/` and `.pyve/testenvs/` | One root: `.pyve/envs/<name>/<backend>/` |
| `pyve testenv <sub>` | `pyve env <sub>` (the old spelling still works, with a warning) |
| Python-only | Plugin model — Python and Node, more through the contract |

Your code, `pyproject.toml`, `package.json`, lockfiles, and non-empty `.env` files are never touched by migration.

## `pyve self migrate` — the one-step move

`pyve self migrate` is the deterministic migrator. It:

1. **Writes `pyve.toml`** from your v2 sources (`.pyve/config` + `[tool.pyve.testenvs.*]`).
2. **Backs the legacy files up** into `.pyve/.v2-legacy/` — the single, deterministic backup location.
3. **Rebuilds your environments** at the v3 layout (`pyve init --force` under the hood).

It is **idempotent** — running it twice is safe — and offers flags to preview or stage the work:

```bash
pyve self migrate --dry-run      # show what would happen, change nothing
pyve self migrate --no-rebuild   # write pyve.toml + back up, skip the env rebuild
pyve self migrate                # full migration
```

If something looks wrong after a migration, `.pyve/.v2-legacy/` holds your original files.

## The three coordinated surfaces

The v2 → v3 transition is managed by three surfaces, each for a different user state. Don't expect a fourth nudge — these are the only ones.

### 1. The deterministic migrator

`pyve self migrate` (above) — for when you're ready to migrate.

### 2. The v3.0 soft banner

While you're on v3.0 with v2 sources and no `pyve.toml`, Pyve shows a **one-shot banner** nudging you to migrate. It fires at most once per shell session and skips `--help` / `--version` / `--config` and the `self` namespace. Suppress it entirely with:

```bash
export PYVE_QUIET=1
```

### 3. The v3.0 read-compat window

This is what lets you defer. During the v3.0 window, when a project has v2 sources but no `pyve.toml`, Pyve **synthesizes** the v3 model in memory from your legacy files, so every command keeps working as before — you can migrate on your own schedule. The read-compat layer is removed in v3.1.

### 4. The v3.1 hard gate

In **v3.1**, the soft banner is replaced by a hard interactive gate — *"Pyve v2.x configuration is no longer supported. Ready to migrate? [Y/n]"* — that runs `pyve self migrate` on accept. The read-compat layer is removed at the same time, so v3.1 expects a `pyve.toml`. Migrate before v3.1 and you'll never see it.

## CLI renames

The v2 → v3 command renames, all backward-compatible during the v3.x window:

| v2 form | v3 form | Status |
|---|---|---|
| `pyve testenv init` | `pyve env init` | `testenv` aliased with a one-shot warning; removed in v4.0 |
| `pyve testenv install` | `pyve env install` | aliased |
| `pyve testenv purge` | `pyve env purge` | aliased |
| `pyve testenv run` | `pyve env run` | aliased |

The diagnostics split from the v1.x → v2.0 era still holds: `pyve doctor` / `pyve validate` were replaced by `pyve check` (CI-safe `0`/`1`/`2`) and `pyve status` (read-only dashboard).

## Quick recipe

For a repo moving from v2 to v3:

1. Upgrade Pyve (`brew upgrade pointmatic/tap/pyve`, or `git pull && ./pyve.sh self install` from source).
2. In each project, preview first: `pyve self migrate --dry-run`.
3. Run `pyve self migrate`.
4. Confirm: `pyve status` (read the new manifest), `pyve check` (verify health).
5. Once you're happy, the legacy backup in `.pyve/.v2-legacy/` can be removed at your leisure.
6. Update scripts: `pyve testenv …` → `pyve env …` (the old form keeps working until v4.0).
