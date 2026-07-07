# Environments (`env`)

The `pyve env` namespace manages named environments end to end — creation from the declared recipe, dependency install, execution, inventory, and removal — plus `env sync`, which reconciles a planned env spec into `pyve.toml`.

## `env <subcommand>`

Manage named environments — dev/test runner envs for tools like ruff, mypy, black, and pytest, plus any other declared `[env.<name>]`. The default test env lives at `.pyve/envs/testenv/venv/`. Declare additional named envs in `pyve.toml` (see [Named Environments](../environments.md) and [Testing → Named test environments](../testing.md#named-test-environments)). All named envs are preserved across `pyve init --force` and `pyve purge --keep-testenv`.

**Usage:**

```bash
pyve env init [<name>] [--force]                         # Create an env from its declared recipe (default: testenv)
pyve env install [<name>] [-r <file>] [--no-wait]        # Install dependencies
pyve env purge [<name>|--all] [--yes]                    # Remove the default env, one env, or every env
pyve env run [<name> --] <command> [args...]             # Run a command in an env
pyve env list                                            # Tabulate every known env
pyve env prune [--unused-since <YYYY-MM-DD>|--all] [--yes]   # Remove unused envs
pyve env sync [--yes] [--force]                          # Reconcile the env spec into pyve.toml
```

**Subcommands:**

- `init [<name>] [--force]`: Creates `.pyve/envs/<name>/{venv,conda}/` and materializes the env's full declared setup recipe in one shot — conda `manifest` first, then `editable`, `requirements`, `extra`, in that fixed order. No directives declared → an empty env ("init installs what you declared, nothing you didn't"). `--force` is the one-shot rebuild verb: purge + re-create + re-materialize, with the recorded operational state restored. (`root` is rejected here — rebuild the root env with `pyve init --force`.)
- `install [<name>] [-r <file>] [--no-wait]`: No `<name>` iterates every declared non-lazy env. With `<name>` installs into one env. `-r <file>` overrides the declared pip-layer recipe; without any declared recipe, falls back to auto-detected `requirements-dev.txt` or bare `pytest`. `--no-wait` fast-fails if another pyve process holds the install lock.
- `purge [<name>|--all] [--yes]`: Bare `pyve env purge` removes the **default** env — matching its siblings, which assume the default when unnamed. `<name>` removes one env; `--all` sweeps every declared env (TTY-prompted; `--yes` skips the prompt; non-TTY stdin also skips).
- `run [<name> --] <command> [args...]`: Executes a command inside an env. With `<name>`, the `--` separator disambiguates env name from command. Venv-only — conda-backed envs hard-error with a `micromamba run -p <env> <cmd>` workaround hint.
- `list`: Tabulates the union of declared envs and on-disk envs with `NAME / BACKEND / SIZE / LAST-USED / STATE` columns. STATE is one of `ready` (recipe installed), `realized` (on-disk but never installed), `lazy`, `not provisioned`, `orphaned`.
- `prune`: Disk-walking removal. Default mode removes orphans (on-disk but not declared); `--unused-since <ISO-date>` removes envs whose `.state.last_used_at` is strictly older (envs never used are preserved); `--all` removes every on-disk env. Distinct from `purge` (which is declaration-driven, walking `pyve.toml`).
- `sync [--yes] [--force]`: Reconciles the planned environment spec (`docs/specs/env-dependencies.md` §4, authored by `project-guide mode plan_envs`) into `pyve.toml`: discover → diff → `[Y/n]`-apply. Writes `pyve.toml` only, never materializes. Non-destructive changes default to apply (`--yes` assents); destructive drops and backend flips default to No — `--force` escalates to apply them too. Exit `6` = spec invalid under the closed vocabulary. See [Planning environments with project-guide](../environments.md#planning-environments-with-project-guide).

**Examples:**

```bash
# Set up the default testenv
pyve env init
pyve env install -r requirements-dev.txt

# Set up a named env (requires an [env.smoke] declaration in pyve.toml)
pyve env init smoke                # materializes smoke's full declared recipe

# Rebuild an env from its declaration (purge + create + install, state restored)
pyve env init smoke --force

# Install every declared non-lazy env in one shot
pyve env install

# Run dev tools from the default testenv
pyve env run ruff check .
pyve env run mypy src/
pyve env run black --check .

# Run a tool in a named env (note the `--` separator)
pyve env run smoke -- pytest -v

# See what's on disk
pyve env list

# Remove envs nobody has used since 2026-01-01
pyve env prune --unused-since 2026-01-01

# Tear down the default env / one env / every declared env
pyve env purge
pyve env purge smoke
pyve env purge --all --yes

# Reconcile the planned env spec into pyve.toml
pyve env sync
```

**Notes:**

- Every named env survives `pyve init --force` and `pyve purge --keep-testenv`; plain `pyve purge` removes them.
- `pyve test` is a convenience shortcut that runs pytest inside the resolved env with auto-install support and the silent-skip advisory.
- Exit code matches the executed command's exit code (single env) or the worst-case aggregate (`install` no-arg iteration / `purge --all`).
- Concurrent `pyve env install <same-env>` from two shells serialize via a `mkdir`-based lock in the env's state directory; the holder's PID is in `lock/pid`. `--no-wait` fast-fails with a "(pid N)" message instead of queuing.

**Legacy flag forms (removed in v2.3.0).**

`pyve testenv --init`, `pyve testenv --install`, and `pyve testenv --purge` were delegated-with-warning through v2.2.x and hard-removed in v2.3.0. They now fall through to the dispatcher's unknown-flag path. See the [Migration guide](../migration.md) for the mapping.

!!! note "`pyve testenv` → `pyve env`"
    The `pyve testenv <sub>` namespace is a **deprecated alias** for `pyve env <sub>`; it re-dispatches with a one-shot warning and is removed in v4.0. Every example above uses the canonical `pyve env` form.

## See also

- [Named Environments](../environments.md) — the concept guide: purposes, backends, lifecycle policies
- [Testing](../testing.md) — how `pyve test` selects and provisions envs
- [Project Lifecycle](lifecycle.md) — `init --force --all`, `upgrade`, `purge --keep-testenv`
- [Usage Guide](../usage.md) — command overview and universal flags
