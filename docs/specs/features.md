# features.md — Pyve: A single, easy entry point for Python virtual environments

This document defines **what** Pyve does — requirements, inputs, outputs, and behavior — without specifying how it is implemented. It is the source of truth for scope. For architecture and module design, see `tech_spec.md`. For the implementation plan, see `stories.md`.

---

## Project Goal

Pyve is a command-line tool that provides a single, deterministic entry point for setting up and managing Python virtual environments on macOS and Linux. It orchestrates Python version management, virtual environments (venv and micromamba), and direnv integration in one script.

### Core Requirements

1. Initialize a complete Python development environment in one command (`pyve init`), including Python version selection, virtual environment creation, direnv configuration, `.env` file setup, and `.gitignore` management.
2. Support two environment backends:
   - **venv** (pip-based) for application and general development workflows.
   - **micromamba** (conda-compatible) for scientific computing and ML workflows.
3. Auto-detect the appropriate backend from project files (`environment.yml` → micromamba, `pyproject.toml` / `requirements.txt` → venv) or allow explicit selection via `--backend`.
4. Manage Python versions through existing version managers (asdf or pyenv), including auto-installation of requested versions.
5. Cleanly remove all Pyve-created artifacts via `pyve purge`, preserving user data (non-empty `.env` files, user code, Git repository).
6. Execute commands inside the project environment without manual activation via `pyve run <command>`.
7. Provide environment health diagnostics via `pyve doctor`.
8. Install and uninstall the Pyve script itself to/from `~/.local/bin` via `pyve self install` / `pyve self uninstall`.

### Operational Requirements

1. **Error handling** — Check for prerequisites (asdf/pyenv, direnv, micromamba) before operations and provide actionable error messages when dependencies are missing.
2. **Conflict detection** — Detect existing environments, version manager files, and direnv configuration before initialization. Skip with informational messages rather than overwriting.
3. **Idempotency** — Running `pyve init` on an already-initialized project offers update-in-place or force re-initialization, rather than failing or silently overwriting.
4. **Smart re-initialization** — `--update` preserves the existing environment and updates configuration; `--force` purges and re-creates from scratch.
5. **Logging** — Provide clear success (✓), warning (⚠), and error (✗) indicators for all operations.

### Quality Requirements

1. **Self-healing .gitignore** — Maintain a Pyve-managed template section at the top of `.gitignore` with Python build/test artifacts and environment entries. Preserve user entries below the template. Rebuild the template on each init to restore accidentally deleted entries.
2. **Idempotent .gitignore** — Running init multiple times produces identical `.gitignore` content (no duplicate entries, no accumulated blank lines).
3. **Lock file validation** — For micromamba environments, a missing `conda-lock.yml` is a hard error (use `--no-lock` to bypass). A stale `conda-lock.yml` warns interactively (or errors in `--strict` mode).
4. **Secure file permissions** — `.env` files are created with `chmod 600` (owner read/write only).

### Usability Requirements

1. **CLI tool** — Invoked as `pyve` (after install) or `./pyve.sh` (direct execution).
2. **Short flags** — Universal flags have short forms (`-h`, `-v`, `-c`). Top-level subcommand short aliases (`-i`, `-p`) were removed in v1.11.0 (Decision D1 — subcommands are already short; users who want fewer keystrokes can write a shell alias).
3. **Interactive and non-interactive modes** — Interactive prompts for re-initialization choices and micromamba bootstrap; non-interactive flags (`--force`, `--update`, `--auto-bootstrap`, `--no-direnv`) for CI/CD.
4. **direnv integration** — For interactive use, environments auto-activate/deactivate on directory entry/exit. For CI/CD, `pyve run` provides explicit execution without direnv.

### Non-Goals

- Pyve does not replace asdf, pyenv, direnv, or micromamba — it orchestrates them.
- Pyve does not install `conda-lock` — users add it to `environment.yml` dependencies or install it manually; Pyve wraps the invocation via `pyve lock` when it is available on PATH.
- Pyve does not install asdf or pyenv (they must be pre-installed).
- Pyve does not provide a GUI or web interface.
- Pyve does not manage Docker containers or cloud environments.
- Pyve does not manage project dependencies (pip install, conda install) beyond initial environment creation.

---

## Inputs

### Required

- **Subcommand or universal flag** — One of:
  - Subcommands: `init`, `purge`, `python-version`, `validate`, `lock`, `doctor`, `run`, `test`, `testenv`, `self install`, `self uninstall`.
  - Universal flags (CLI convention): `--help` / `-h`, `--version` / `-v`, `--config` / `-c`.

  As of v1.11.0 (Story G.b.1), the legacy flag-style top-level commands (`--init`, `--purge`, `--validate`, `--python-version`, `--install`, `--uninstall`) have been **removed**. Invoking a removed flag form prints a precise migration error and exits non-zero (Decision D3 — kept forever).

### Optional

| Input | Description | Example |
|-------|-------------|---------|
| `--backend <type>` | Environment backend (`venv`, `micromamba`, `auto`) | `--backend micromamba` |
| `--python-version <ver>` | Python version in `#.#.#` format | `--python-version 3.12.0` |
| `<venv_dir>` | Custom venv directory name | `pyve init my_venv` |
| `--env-name <name>` | Micromamba environment name | `--env-name myproject-dev` |
| `--local-env` | Copy `~/.local/.env` template to project `.env` | `--init --local-env` |
| `--no-direnv` | Skip `.envrc` creation | `--init --no-direnv` |
| `--force` | Force re-initialization (purge + init) | `--init --force` |
| `--update` | Update existing installation in-place | `--init --update` |
| `--auto-bootstrap` | Auto-install micromamba without prompting | `--init --auto-bootstrap` |
| `--bootstrap-to <loc>` | Bootstrap location (`project` or `user`) | `--bootstrap-to project` |
| `--strict` | Enforce lock file validation | `--init --strict` |
| `--no-lock` | Bypass missing `conda-lock.yml` hard error (not recommended) | `--init --no-lock` |
| `--allow-synced-dir` | Bypass cloud-synced directory check | `--init --allow-synced-dir` |
| `--keep-testenv` | Preserve dev/test runner environment during purge | `--purge --keep-testenv` |
| `--project-guide` | Force project-guide install + init + completion (overrides auto-skip) | `--init --project-guide` |
| `--no-project-guide` | Skip the entire project-guide hook | `--init --no-project-guide` |
| `--project-guide-completion` | Force shell completion wiring (no prompt) | `--init --project-guide-completion` |
| `--no-project-guide-completion` | Skip shell completion wiring (no prompt) | `--init --no-project-guide-completion` |

### Project Files (Auto-Detection)

| File | Effect |
|------|--------|
| `.pyve/config` | Explicit backend and environment settings (highest priority) |
| `environment.yml` | Triggers micromamba backend |
| `conda-lock.yml` | Triggers micromamba backend |
| `pyproject.toml` | Triggers venv backend |
| `requirements.txt` | Triggers venv backend |

---

## Outputs

### Files Created by `--init` (venv backend)

| File/Directory | Description |
|----------------|-------------|
| `.venv/` (or custom name) | Python virtual environment |
| `.tool-versions` or `.python-version` | Python version pinning (asdf or pyenv) |
| `.envrc` | direnv configuration (unless `--no-direnv`) |
| `.env` | Environment variables file (chmod 600) |
| `.gitignore` | Updated with Pyve template entries |
| `.pyve/config` | Backend and version tracking |

### Files Created by `--init` (micromamba backend)

| File/Directory | Description |
|----------------|-------------|
| `.pyve/envs/<name>/` | Micromamba environment |
| `.envrc` | direnv configuration (unless `--no-direnv`) |
| `.env` | Environment variables file (chmod 600) |
| `.gitignore` | Updated with Pyve template entries (`.vscode/settings.json` added) |
| `.pyve/config` | Backend, version, and environment name tracking |
| `.vscode/settings.json` | IDE interpreter path and environment isolation settings |

### Files Created by `--install`

| File/Directory | Description |
|----------------|-------------|
| `~/.local/bin/pyve.sh` | Main script |
| `~/.local/bin/lib/` | Helper scripts |
| `~/.local/bin/pyve` | Symlink to `pyve.sh` |
| `~/.local/.env` | User-level environment template (chmod 600) |

---

## Functional Requirements

### FR-1: Environment Initialization (`pyve init`)

Initialize a complete Python development environment in the current directory.

- Auto-detect backend from project files or use explicit `--backend` flag.
- Set Python version via asdf or pyenv (auto-install if not present).
- Create virtual environment (venv directory or micromamba environment).
- **Prompt to install pip dependencies** from `pyproject.toml` or `requirements.txt` after environment creation (unless `--auto-install-deps` or `--no-install-deps`).
- Configure direnv for auto-activation (unless `--no-direnv`).
- Create `.env` file with secure permissions.
- Rebuild `.gitignore` from template, preserving user entries.
- Create `.pyve/config` for version and backend tracking.
- **Micromamba only**: Generate `.vscode/settings.json` pointing at `.pyve/envs/<name>/bin/python` with `python.terminal.activateEnvironment: false` and `python.condaPath: ""` to prevent IDE interference. Skips if file already exists (use `--force` to overwrite). Adds `.vscode/settings.json` to `.gitignore`.
- **Edge cases**: Existing environment detected → offer update/force/cancel. Reserved venv directory names rejected (`.env`, `.git`, `.gitignore`, `.tool-versions`, `.python-version`, `.envrc`). Invalid Python version format rejected.
- **Post-init project-guide hook (FR-16)**: After environment creation and pip-deps install, runs the three-step project-guide hook (install, `project-guide init --no-input`, shell completion). Skipped in `--update` mode. Auto-skipped if `project-guide` is already declared as a project dep.

### FR-2: Environment Purge (`pyve purge`)

Remove all Pyve-created artifacts from the current directory.

- Remove venv directory or micromamba environment.
- Remove version manager files (`.tool-versions` or `.python-version`).
- Remove `.envrc`.
- Remove `.env` only if empty; preserve with warning if non-empty.
- Clean `.gitignore` patterns (remove `.venv`, `.env`, `.envrc`; preserve permanent entries).
- **`.gitignore` policy for micromamba backend:**

| File | Ignored by Pyve? |
|------|-----------------|
| `.pyve/envs/` | ✅ Yes — local environment, not portable |
| `.envrc` | ✅ Yes — machine-specific activation |
| `.env` | ✅ Yes — secrets |
| `conda-lock.yml` | ❌ **No — must be committed** (like `package-lock.json` or `Cargo.lock`) |
| `environment.yml` | ❌ No — committed by design |

- **Edge cases**: No environment found → informational message, no error. `--keep-testenv` preserves the dev/test runner environment.

### FR-3: Python Version Management (`pyve python-version`)

Set the local Python version without creating a virtual environment.

- Set version via asdf or pyenv.
- Auto-install if version not present.
- Refresh shims after change.
- No venv or direnv changes.
- **Edge cases**: Invalid version format (`#.#.#` required). Version not available for installation.

### FR-4: Command Execution (`pyve run`)

Execute a command inside the project environment without manual activation.

- Venv: execute directly from `.venv/bin/`.
- Micromamba: execute via `micromamba run -p <prefix>`.
- Pass all arguments through to the command.
- Propagate the command's exit code.
- **Edge cases**: No environment found → error with suggestion to run `pyve init`. Command not found → exit code 127.

### FR-5: Environment Diagnostics (`pyve doctor`)

Display environment health and configuration status.

- Report backend type, environment location, Python version.
- Report micromamba binary location and version (if applicable).
- Report lock file status (up to date, stale, missing).
- Report direnv and `.env` status.
- **Micromamba only:** Scan `site-packages` for duplicate `.dist-info` directories and report conflicting versions with their mtimes.
- **Micromamba only:** Scan environment tree for files/directories with ` 2` suffix (iCloud Drive collision artifacts).
- **Micromamba only:** Detect potential conda/pip native library conflicts — when pip-bundled packages (torch, tensorflow, jax) coexist with conda-linked packages (numpy, scipy, scikit-learn) and the required shared OpenMP library (`libomp.dylib` on macOS, `libgomp.so` on Linux) is absent.
- **Venv only:** Detect relocated projects by comparing `pyvenv.cfg` creation path against the current project directory; warn with remediation if mismatched.
- Use status indicators: ✓ (success), ⚠ (warning), ✗ (error).

### FR-6: Installation Validation (`pyve validate`)

Validate Pyve installation structure and version compatibility.

- Check Pyve version compatibility with project.
- Verify installation structure (`.pyve/` directory, config file).
- Verify environment existence and backend configuration.
- Check Python version availability.
- Exit codes: 0 (pass), 1 (errors), 2 (warnings only).

### FR-7: Script Installation (`pyve self install`) and Uninstallation (`pyve self uninstall`)

Install or remove the Pyve script from the user's system. Lives under the `self` namespace (mirrors `git remote`, `kubectl config`); `pyve self` with no subcommand prints the namespace help only.

- **Install** (`pyve self install`): Copy script and lib/ to `~/.local/bin`, create symlink, add to PATH, create `~/.local/.env` template. Idempotent.
- **Uninstall** (`pyve self uninstall`): Remove script, symlink, lib/, PATH entry. Preserve `~/.local/.env` if non-empty. Also removes the project-guide shell completion sentinel block from both `~/.zshrc` and `~/.bashrc` (if previously added by `pyve init --project-guide-completion`).

### FR-8: Backend Auto-Detection

Determine the environment backend from project files when `--backend` is not specified.

- Priority: `.pyve/config` > `environment.yml` / `conda-lock.yml` > `pyproject.toml` / `requirements.txt` > default (venv).
- **Ambiguous cases:** When both conda files (`environment.yml`, `conda-lock.yml`) and Python files (`pyproject.toml`, `requirements.txt`) exist, prompt user interactively to choose backend (default: micromamba).
- **Non-interactive mode:** Set `PYVE_FORCE_YES=1` or `CI=1` to auto-default to micromamba in ambiguous cases without prompting.

### FR-9: Micromamba Environment Naming

Resolve micromamba environment names using a priority chain.

- Priority: `--env-name` flag > `.pyve/config` > `environment.yml` name field > sanitized directory basename.
- Sanitization: lowercase, replace special characters with hyphens, remove leading/trailing hyphens.
- Reject reserved names: `base`, `root`, `default`, `conda`, `mamba`, `micromamba`.

### FR-10: Micromamba Bootstrap

Install micromamba when the backend is required but not found.

- Interactive: prompt with installation location options (project sandbox, user sandbox, system package manager, manual).
- Non-interactive: `--auto-bootstrap` with `--bootstrap-to` for location selection.
- Installation locations: `.pyve/bin/micromamba` (project) or `~/.pyve/bin/micromamba` (user).

### FR-11: Dev/Test Runner Environment (`pyve test`, `pyve testenv`)

Provide an isolated test environment separate from the project environment.

- Test environment located at `.pyve/testenv/venv/`.
- `pyve test` runs pytest in the test environment; prompts to install pytest if missing (interactive) or exits with instructions (non-interactive).
- `pyve testenv --init` and `pyve testenv --install` for explicit management.
- `pyve testenv run <command>` executes any command inside the test environment (ruff, mypy, black, etc.).
- Survives `pyve init --force` (separate from project environment).

### FR-12: Smart Re-Initialization

Handle `pyve init` on already-initialized projects.

- Detect existing installation and offer: update in-place, purge and re-initialize, or cancel.
- `--update`: preserve environment, update config, reject backend changes.
- `--force`: purge and re-create, allow backend changes, prompt for confirmation.

### FR-14: Cloud-Synced Directory Detection

Refuse to initialize an environment inside a known cloud-synced directory.

- On `pyve init`, check whether `$PWD` is inside a known synced path before any environment work begins.
- **Primary check (path heuristic):** hard fail if `$PWD` is a descendant of any of:
  `~/Documents`, `~/Desktop`, `~/Library/Mobile Documents`, `~/Dropbox`, `~/Google Drive`, `~/OneDrive`
- **Secondary check (xattr, macOS only):** hard fail if `xattr -l "$PWD"` output contains `com.apple.cloud`, `com.dropbox`, `com.google.drive`, or `com.microsoft.onedrive`.
- Error message includes: current path, detected sync root and provider, recommended `mv` command, and `--allow-synced-dir` override.
- **`--allow-synced-dir` flag** (or `PYVE_ALLOW_SYNCED_DIR=1`) bypasses the check for users who have disabled sync on that directory.
- **Rationale:** Cloud sync daemons race against micromamba extraction, causing non-deterministic environment corruption. A warning is insufficient — the failure is silent, delayed, and not recoverable without a full rebuild.

### FR-13: Distutils Compatibility Shim

On Python 3.12+, install a lightweight `sitecustomize.py` shim to prevent TensorFlow/Keras import failures from missing `distutils`.

- Disable with `PYVE_DISABLE_DISTUTILS_SHIM=1`.

### FR-16: project-guide Integration (`pyve init`)

Opinionated, opt-out hook that wires [`project-guide`](https://pointmatic.github.io/project-guide/) into `pyve init` so the LLM-assisted workflow is available from the first command. Runs after the existing pip-deps prompt, as the final step of `pyve init` before the success summary.

**Three-step hook** (fresh init or `--force`; **not** `--update`):

1. `pip install --upgrade project-guide` — installs (or upgrades) project-guide into the project env. Always uses `--upgrade` so users get the latest. Default upgrade strategy (`only-if-needed`) so transitive deps are not cascaded.
2. **Scaffold or refresh managed artifacts**, branching on `.project-guide.yml` presence:
   - **Absent** (first-time, or a previous `--no-project-guide` skipped the initial scaffold): `<env>/bin/project-guide init --no-input` — creates `.project-guide.yml` and `docs/project-guide/` artifacts. Requires `project-guide >= 2.2.3`.
   - **Present** (reinit case — v1.14.0+): `<env>/bin/project-guide update --no-input` — content-aware refresh. Hash-compares each managed file against its shipped template, skips matches, creates `.bak.<timestamp>` siblings for modified files before overwriting, and preserves `.project-guide.yml` state (`current_mode`, overrides, `metadata_overrides`, `test_first`, `pyve_version`). Requires `project-guide >= 2.4.0` (the `update` subcommand). Failure (including a future `SchemaVersionError`) is surfaced as a warning and is non-fatal; pyve never auto-runs `project-guide init --force`, since that would be destructive.
3. Shell completion wiring — appends a sentinel-bracketed eval block to the user's `~/.zshrc` or `~/.bashrc` so `project-guide` tab-completion works in interactive shells.

**Trigger logic** (priority order, first match wins):

| Input | Behavior |
|---|---|
| `--no-project-guide` flag | Skip all three steps, no prompt |
| `--project-guide` flag | Run all three steps (overrides auto-skip below) |
| `PYVE_NO_PROJECT_GUIDE=1` env var | Skip all three steps, no prompt |
| `PYVE_PROJECT_GUIDE=1` env var | Run all three steps, no prompt |
| **`project-guide` already in project deps** | **Auto-skip with INFO message** |
| Non-interactive (`CI=1` or `PYVE_FORCE_YES=1`) | Run install + step 2; **skip step 3** (CI asymmetry) |
| Interactive (default) | Prompt: `Install project-guide? [Y/n]` |

`--project-guide` and `--no-project-guide` are mutually exclusive — using both is a hard error. Same for `--project-guide-completion` / `--no-project-guide-completion`.

**Auto-skip safety mechanism.** If `project-guide` is already declared as a dependency in `pyproject.toml`, `requirements.txt`, or `environment.yml`, pyve auto-skips the entire hook with an informative message. The user's pin wins; pyve refuses to manage what the user already manages, avoiding a version conflict at the next `pip install -e .`. The explicit `--project-guide` flag overrides this auto-skip.

**`--update` does not run the hook.** `pyve init --update` is a config-only metadata bump and must not touch the environment or run network operations. Users who want a fresh project-guide on update run `pyve init --force` instead.

**CI default asymmetry — install vs. completion.** Non-interactive mode (`CI=1` or `PYVE_FORCE_YES=1`) defaults the install flow to **install** (matches the interactive default of Y), but defaults the completion flow to **skip**. Editing user rc files in unattended environments is the kind of surprise pyve avoids; explicit opt-in via `PYVE_PROJECT_GUIDE_COMPLETION=1` or `--project-guide-completion` is required.

**Idempotency.**
- Step 1: `pip install --upgrade` is naturally idempotent — re-running it just confirms the latest is installed.
- Step 2 (first-time, `init`): `project-guide init --no-input` is a no-op success on an already-initialized project unless `--force` is given (which pyve never passes).
- Step 2 (reinit, `update`): `project-guide update --no-input` hash-compares each managed file; files that already match are skipped. Modified files get `.bak.<timestamp>` siblings before being overwritten, so re-running is safe and cumulative.
- Step 3: detected via the sentinel comment `# >>> project-guide completion (added by pyve) >>>`. Already-present blocks are never duplicated.

**Failure handling.** All three steps are failure-non-fatal. A failed pip install, a failed `project-guide init`, an unwritable rc file, or an unknown shell all log a warning with a `--no-project-guide` hint and continue. `pyve init` itself still exits 0. Pyve's job is environment setup; project-guide is a value-add.

**Removal.** `pyve self uninstall` removes the completion sentinel block from both `~/.zshrc` and `~/.bashrc` (covering users who switched shells). The block's sentinel comments make this safe and idempotent.

**Purge.** `pyve purge` does **not** touch the rendered `.project-guide.yml` or `docs/project-guide/` artifacts. They live alongside the project's source and survive purge for the same reason `pyproject.toml` does.

### FR-15: conda-lock Wrapper (`pyve lock`)

Generate or update `conda-lock.yml` for the current platform.

- **Backend guard**: if `.pyve/config` records `backend: venv`, fail immediately with a clear "micromamba projects only" message.
- **Prerequisite check**: if `conda-lock` is not on PATH, fail with instructions to add it to `environment.yml` and run `pyve init --force`.
- **Environment file check**: if `environment.yml` does not exist, fail with a message that includes a `pyve init --backend micromamba` hint.
- **Platform detection**: call `get_conda_platform()` to resolve the correct conda platform string (`osx-arm64`, `osx-64`, `linux-64`, `linux-aarch64`).
- **Invocation**: run `conda-lock -f environment.yml -p <platform>`, capturing combined stdout/stderr.
- **"Already up to date" case**: if output contains `"already locked"` or `"spec hash already locked"`, print `✓ conda-lock.yml is already up to date for <platform>. No changes made.` and exit 0.
- **Success case**: filter lines matching `conda-lock install` or `Install lock using` from conda-lock's post-run output (these suggest a non-Pyve workflow), then print rebuild guidance: `pyve init --force`.
- **Error case**: on non-zero exit from conda-lock, pass through output unmodified and propagate exit code.
- **Scope**: generates for the current platform only. Multi-platform generation and `--check` mode are future enhancements (FR-16).

---

## Configuration

### Precedence (highest to lowest)

1. CLI flags (`--backend`, `--python-version`, `--env-name`, etc.)
2. Project config file (`.pyve/config`)
3. Project files (`environment.yml`, `pyproject.toml`, etc.)
4. Defaults (venv backend, Python 3.14.3, `.venv` directory)

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `PYVE_DISABLE_DISTUTILS_SHIM` | Set to `1` to disable the Python 3.12+ distutils shim |
| `PYVE_TEST_AUTO_INSTALL_PYTEST` | Set to `1` to auto-install pytest without prompting (CI) |
| `PYVE_AUTO_INSTALL_DEPS` | Set to `1` to auto-install pip dependencies without prompting |
| `PYVE_NO_INSTALL_DEPS` | Set to `1` to skip pip dependency installation prompt |
| `PYVE_FORCE_YES` | Set to `1` to auto-default to micromamba in ambiguous backend cases |
| `PYVE_NO_LOCK` | Set to `1` to bypass missing `conda-lock.yml` hard error (same as `--no-lock`) |
| `PYVE_ALLOW_SYNCED_DIR` | Set to `1` to bypass cloud-synced directory check (same as `--allow-synced-dir`) |
| `PYVE_PROJECT_GUIDE` | Set to `1` to force project-guide install (same as `--project-guide`) |
| `PYVE_NO_PROJECT_GUIDE` | Set to `1` to skip the project-guide hook (same as `--no-project-guide`) |
| `PYVE_PROJECT_GUIDE_COMPLETION` | Set to `1` to force shell completion wiring (same as `--project-guide-completion`) |
| `PYVE_NO_PROJECT_GUIDE_COMPLETION` | Set to `1` to skip shell completion wiring (same as `--no-project-guide-completion`) |
| `CI` | When set, enables non-interactive mode (auto-defaults to micromamba, skips prompts) |

### Project Config File (`.pyve/config`)

```yaml
pyve_version: "1.1.3"
backend: micromamba

micromamba:
  env_name: myproject
  env_file: environment.yml
  channels:
    - conda-forge
    - defaults
  prefix: .pyve/envs/myproject

python:
  version: "3.11"

venv:
  directory: .venv
```

---

## Testing Requirements

- **Unit tests** (Bats): White-box testing of shell functions in `lib/*.sh`.
- **Integration tests** (pytest): Black-box testing of full `pyve` workflows (init, purge, run, doctor) across both backends.
- **Platform coverage**: macOS and Linux (Ubuntu) via CI matrix.
- **Python version matrix**: Integration tests run against Python 3.12. Pyve's `DEFAULT_PYTHON_VERSION` is 3.14.4 (set in `pyve.sh`), but CI tests pin the runner's pyenv-installed Python via the auto-pin in `PyveRunner.run()` to avoid expensive source builds on each run. The matrix was narrowed from 3.10/3.11/3.12 to 3.12 only in v1.12.0 — see CHANGELOG and the deferred "Python 3.14 CI investigation" story for the rationale and follow-up.

---

## Security and Compliance Notes

- `.env` files are created with `chmod 600` (owner read/write only).
- `.env` is always added to `.gitignore` to prevent accidental secret commits.
- Non-empty `.env` files are never deleted by purge or uninstall.
- Micromamba bootstrap downloads are verified against official sources.

---

## Performance Notes

- Pyve is a shell script with no background processes or daemons.
- Environment creation time is dominated by Python version installation (asdf/pyenv) and package installation (pip/micromamba), not by Pyve itself.
- `.gitignore` management uses temp files and atomic `mv` to avoid partial writes.

---

## Acceptance Criteria

1. `pyve init` creates a fully functional Python environment (venv or micromamba) in one command on both macOS and Linux.
2. `pyve purge` cleanly removes all Pyve artifacts without data loss.
3. `pyve run <command>` executes commands in the correct environment without manual activation.
4. `pyve doctor` accurately reports environment health.
5. All operations are idempotent — running them multiple times produces the same result.
6. CI/CD workflows work without interactive prompts using `--no-direnv`, `--auto-bootstrap`, and `--strict`.
7. Unit and integration tests pass on macOS and Linux across the Python version matrix.
