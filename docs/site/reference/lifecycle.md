# Project Lifecycle

Commands that create, refresh, and remove the project's Pyve-managed surface: [`init`](#init), [`update`](#update), [`upgrade`](#upgrade-env-name-all-check), and [`purge`](#purge).

The three-verb boundary at a glance: `pyve update` refreshes the files Pyve manages *around* your project (never touches an env); `pyve upgrade` re-resolves dependencies *inside* an env (keeps the env); `pyve init --force` rebuilds the env itself.

## `init`

Initialize a Python virtual environment in the current directory.

**Usage:**

```bash
pyve init [options]
```

**Options:**

- `--yes`, `-y`: Easy mode — accept every wizard default with no prompts, then write the fully-explicit `pyve.toml`

- `--python-version <ver>`: Set Python version (e.g., `3.13.7`)
  - If omitted, reads from `.python-version` file
  - If no `.python-version`, uses pyve's default version
- `--backend <type>`: Backend to use: `venv`, `micromamba`, or `auto`
  - Default: auto-detect based on project files
  - If both `environment.yml` and `pyproject.toml` exist, prompts interactively (defaults to micromamba)
- `--auto-bootstrap`: Install micromamba without prompting (if needed)
- `--bootstrap-to <location>`: Where to install micromamba: `project` or `user`
- `--strict`: Error on a stale lock, or a missing lock when `conda-lock` is declared in `environment.yml` (non-strict only nudges); also opts out of scaffolding/inference
- `--no-lock`: Don't use a lock this run — resolve from `environment.yml`, ignore any present lock (never deletes it), skip the requirement (beats `--strict`), and omit `conda-lock` from a fresh scaffold
- `--env-name <name>`: Environment name (micromamba backend)
- `--no-direnv`: Skip `.envrc` creation (for CI/CD or when direnv isn't used)
- `--auto-install-deps`: Automatically install pip dependencies from `pyproject.toml` or `requirements.txt` after environment creation
- `--no-install-deps`: Skip dependency installation prompt (for CI/CD)
- `--local-env`: Copy `~/.local/.env` template into the project
- `--force`: Purge and rebuild the **root** environment from the manifest (destructive; confirms first). Named envs under `.pyve/envs/` are untouched — rebuild one with `pyve env init <name> --force`.
    - For **non-destructive** refresh of managed files, use `pyve update`; to re-resolve dependencies in place, use `pyve upgrade`.
- `--all`: With `--force`: after the root rebuild, rebuild every declared env and restore its recorded operational state
- `--allow-synced-dir`: Bypass the cloud-synced directory safety check (see below)

**`project-guide` integration options** (three-step post-init hook):

- `--project-guide`: Run all three steps (install + init + shell completion), no prompt
- `--no-project-guide`: Skip all three steps, no prompt
- `--project-guide-completion`: Add shell completion only (step 3), no prompt
- `--no-project-guide-completion`: Skip shell completion only (step 3), no prompt

**Examples:**

```bash
# Initialize with defaults (auto-detect backend, default venv)
pyve init

# Easy mode: accept every wizard default, no prompts
pyve init --yes

# Pin a specific Python version
pyve init --python-version 3.13.7

# Force venv backend
pyve init --backend venv

# Force micromamba backend
pyve init --backend micromamba

# Auto-install dependencies after initialization
pyve init --auto-install-deps

# Skip dependency installation prompt (for CI/CD)
pyve init --no-install-deps

# Skip direnv (for CI/CD setups)
pyve init --no-direnv

# Force re-initialization (purges and rebuilds the root env)
pyve init --force

# Rebuild every declared env, restoring recorded state
pyve init --force --all

# Skip the lock for this run (resolve from environment.yml; a present lock is ignored, not deleted)
pyve init --no-lock

# Bypass cloud-sync directory check (only if you have disabled sync)
pyve init --allow-synced-dir

# Install project-guide without prompting
pyve init --project-guide

# Skip project-guide entirely
pyve init --no-project-guide
```

**Cloud-Synced Directory Safety Check:**

Pyve refuses to initialize an environment inside a cloud-synced directory
(`~/Documents`, `~/Dropbox`, `~/Google Drive`, `~/OneDrive`, etc.).

Cloud sync daemons race against micromamba's package extraction, producing
non-deterministic environment corruption that can damage the Python standard
library. The failure is silent and delayed — often not detected until hours
later during a `git commit` or test run.

```
  ✘ Project is inside a cloud-synced directory.

  Path:      /Users/you/Documents/myproject
  Sync root: /Users/you/Documents (iCloud Drive)

  Recommended fix: move your project outside the synced directory.
    mv "/Users/you/Documents/myproject" ~/Developer/myproject

  If you have disabled sync for this directory and understand the risk:
    pyve init --allow-synced-dir
```

**`project-guide` integration (three-step post-init hook):**

On fresh init (or `pyve init --force`), pyve wires
[project-guide](https://pointmatic.github.io/project-guide/) into the project
as an opt-out post-init hook:

1. `pip install --upgrade project-guide` into the project environment
2. `project-guide init --no-input` to create `.project-guide.yml` and `docs/project-guide/`
3. Append a sentinel-bracketed shell completion block to `~/.zshrc` or `~/.bashrc`

**Trigger logic** (priority order, first match wins):

| Input | Behavior |
|---|---|
| `--no-project-guide` flag | Skip all three steps, no prompt |
| `--project-guide` flag | Run all three steps (overrides auto-skip) |
| `PYVE_NO_PROJECT_GUIDE=1` env var | Skip all three steps |
| `PYVE_PROJECT_GUIDE=1` env var | Run all three steps |
| `project-guide` already in project deps | Auto-skip with INFO message |
| Non-interactive (`CI=1` / `PYVE_FORCE_YES=1`) | Run install + init; skip completion |
| Interactive (default) | Prompt: `Install project-guide? [Y/n]` |

**Auto-skip safety:** If `project-guide` is already declared in `pyproject.toml`,
`requirements.txt`, or `environment.yml`, pyve will **not** auto-install or run
`project-guide init` (avoids version conflicts with your pin). Pass
`--project-guide` to override.

**CI default asymmetry:** Non-interactive mode defaults install → **install**
but completion → **skip** (editing user rc files in CI is surprising; opt in
via `PYVE_PROJECT_GUIDE_COMPLETION=1` or `--project-guide-completion`).

**`pyve update` runs step 2 (project-guide refresh) independently** of the full three-step hook. The v2.0 `pyve update` subcommand refreshes `project-guide update --no-input` but does not install/upgrade the project-guide package itself (step 1) and does not touch shell completion (step 3). Users who want a full three-step run should use `pyve init --force`.

**Interactive Prompts:**

When both `environment.yml` and `pyproject.toml` exist, Pyve will prompt:

```
Detected files:
  • environment.yml (conda/micromamba)
  • pyproject.toml (Python project)

Initialize with micromamba backend? [Y/n]:
```

After successful initialization, if `pyproject.toml` or `requirements.txt` exists:

```
Install pip dependencies from pyproject.toml? [Y/n]:
```

These prompts are skipped in CI mode (when `CI` environment variable is set).

**What it does:**

1. Detects or installs the specified Python version
2. Creates the virtual environment (`.venv` for venv, `.pyve/envs/<name>` for micromamba)
3. Generates `.envrc` for direnv (if installed and `--no-direnv` not passed)
4. Updates `.gitignore` with Pyve-managed patterns
5. Creates `.python-version` if it doesn't exist
6. Optionally runs the project-guide three-step hook (see above)

**Notes:**

- Homebrew-managed installations cannot use `init` (managed by Homebrew)
- Re-running `init` with a different `--python-version` only updates `.python-version`; use `--force` to recreate the environment
- Backend is auto-detected from `environment.yml` or `conda-lock.yml` (micromamba) vs `requirements.txt` / `pyproject.toml` (venv)

---

## `update`

Non-destructive refresh path. Refreshes the files Pyve manages around your project and the `project-guide` scaffolding without touching any environment.

**Usage:**

```bash
pyve update [--no-project-guide]
```

**What it does:**

1. Refreshes the Pyve-managed sections of `.gitignore`.
2. Refreshes `.vscode/settings.json` (only if it already exists — never creates one on update).
3. Refreshes `.pyve/` layout (bootstraps scaffolding if missing).
4. Runs `project-guide update --no-input` (unless `--no-project-guide` or an auto-skip condition applies).

**What it does NOT do:**

- Never rebuilds the venv / micromamba environment — use `pyve init --force` for that; to re-resolve dependencies in place, use `pyve upgrade`.
- Never creates a `.env` or `.envrc` that doesn't exist — those are user state.
- Never re-prompts for backend. The backend declared in `pyve.toml` is untouched.
- Never prompts interactively.

**Exit codes:**

- `0` — success (including no-op when already at current version)
- `1` — failure (unwritable config, corrupt YAML, etc.)

**v1.x migration.** `pyve update` replaces the v1.x `pyve init --update` flag (removed in v2.0). The new semantics are broader: the old flag only bumped `pyve_version`; `pyve update` also refreshes managed files + `project-guide` scaffolding. Typing `pyve init --update` in v2.0 produces a migration error pointing at `pyve update`.

**The `update` / `upgrade` boundary:** `pyve update` touches the files Pyve manages *around* your project; `pyve init --force` and `pyve upgrade` touch the *environments themselves*.

---

## `upgrade [--env <name>|--all] [--check]`

Re-resolve an environment's dependencies to newest-within-constraints **in place** — the env directory is kept, the operational-state record is re-stamped, and micromamba-backed envs re-lock when a `conda-lock.yml` participates.

**Usage:**

```bash
pyve upgrade                  # upgrade the root env
pyve upgrade --env smoke      # upgrade one declared env
pyve upgrade --all            # root + every declared env
pyve upgrade --check          # preview the plan; execute nothing
```

**What it does:**

1. venv-backed: `pip install --upgrade` over the declared setup recipe (`editable` → `requirements` → `extra`); the root env falls back to `requirements.txt` (`-r`) or `pyproject.toml` (`-e .`) when its block declares no recipe.
2. micromamba-backed: `micromamba update -f <manifest>` (newest within the manifest's constraints), then the pip layer with `--upgrade`, then a re-lock via the `pyve lock` machinery.
3. Re-stamps the env's `.state` installed dimension (named envs).

**What it does NOT do:**

- Never creates an env — a never-realized target errors with a `pyve env init` hint. Use `pyve env init <name>` first.
- Never rebuilds — that is `pyve init --force` (root) / `pyve env init <name> --force` (named).
- With `--check`: never executes anything; prints `would run:` lines.

---

## `purge`

Remove the virtual environment and clean up Pyve-managed files.

**Usage:**

```bash
pyve purge [options]
```

**Options:**

- `--yes`, `-y`: Skip the confirmation prompt (non-TTY / CI runs skip it automatically; `--force` is a deprecated alias that warns)
- `--keep-testenv`: Preserve every named env under `.pyve/envs/` across purge

**Examples:**

```bash
# Remove .pyve and the venv (lists what will be removed, confirms first)
pyve purge

# Preserve the named envs across purge
pyve purge --keep-testenv

# Skip the confirmation prompt
pyve purge --yes
```

**What it does:**

1. Removes the virtual environment directory
2. Deletes `.envrc` file
3. Removes Pyve-managed entries from `.gitignore`
4. Preserves `.python-version` and dependency files
5. Preserves `.project-guide.yml` and `docs/project-guide/` (committable artifacts)

**Notes:**

- Homebrew-managed installations cannot use `purge` (use `brew uninstall pyve`)
- Does not remove `.python-version`, `requirements.txt`, or `environment.yml`
- Every named env under `.pyve/envs/` is removed by default; pass `--keep-testenv` to preserve them all — or remove a single env with `pyve env purge <name>`
- Safe to run multiple times

## See also

- [Environments (`env`)](env.md) — create, install, and manage named environments
- [Diagnostics](diagnostics.md) — `pyve check` / `pyve status`
- [Usage Guide](../usage.md) — command overview, universal flags, environment variables
