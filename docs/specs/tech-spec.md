# tech_spec.md — Pyve (Bash)

This document defines **how** Pyve is built — architecture, module layout, dependencies, function signatures, and cross-cutting concerns. For requirements and scope, see `features.md`. For the implementation plan, see `stories.md`.

---

## Runtime & Tooling

| Item | Value |
|------|-------|
| **Language** | Bash (4.x+) |
| **Shell mode** | `set -euo pipefail` |
| **Platforms** | macOS (zsh default shell, BSD userland), Linux (Ubuntu, GNU userland) |
| **Package manager** | N/A (single script + sourced libraries, no package registry) |
| **Linter** | ShellCheck |
| **Test runners** | Bats (unit), pytest (integration) |
| **CI** | GitHub Actions |
| **Coverage** | Codecov (via pytest-cov) |

---

## Dependencies

### Runtime Dependencies (must be pre-installed)

| Dependency | Purpose | Required? |
|------------|---------|-----------|
| Bash 4.x+ | Script execution | Yes |
| asdf **or** pyenv | Python version management | One required |
| direnv | Auto-activation of environments | Required for `--init` (skip with `--no-direnv`) |
| micromamba | Conda-compatible environment backend | Only for micromamba backend |
| grep, sed, awk, mktemp, mv | Standard POSIX utilities | Yes |

### Development Dependencies (`requirements-dev.txt`)

| Package | Purpose |
|---------|---------|
| pytest | Integration test runner |
| pytest-cov | Coverage reporting |
| pytest-xdist | Parallel test execution |
| bats-core | Unit test runner (installed via brew/apt) |
| shellcheck | Shell script linter (installed via brew/apt) |
| black | Python code formatter (lint check) |
| flake8 | Python style checker (lint check) |

---

## Package Structure

```
pyve/
├── pyve.sh                          # Main entry point — CLI parsing, orchestration, all top-level commands
├── lib/
│   ├── utils.sh                     # Logging, prompts, .gitignore management, config parsing, validation
│   ├── env_detect.sh                # Shell profile sourcing, version manager detection (asdf/pyenv), direnv check
│   ├── backend_detect.sh            # Backend auto-detection from project files, backend validation
│   ├── micromamba_core.sh           # Micromamba binary detection, version, location
│   ├── micromamba_env.sh            # Environment file parsing, naming, creation, lock file validation
│   ├── micromamba_bootstrap.sh      # Micromamba download and installation (interactive + auto)
│   ├── distutils_shim.sh           # Python 3.12+ distutils compatibility shim (sitecustomize.py)
│   └── version.sh                   # Version comparison, installation validation, config writing
├── tests/
│   ├── unit/                        # Bats unit tests (white-box, one file per lib module)
│   │   ├── test_utils.bats
│   │   ├── test_backend_detect.bats
│   │   ├── test_config_parse.bats
│   │   ├── test_distutils_shim.bats
│   │   ├── test_env_naming.bats
│   │   ├── test_lock_validation.bats
│   │   ├── test_micromamba_bootstrap.bats
│   │   ├── test_micromamba_core.bats
│   │   ├── test_reinit.bats
│   │   └── test_version.bats
│   ├── integration/                 # pytest integration tests (black-box, one file per workflow)
│   │   ├── conftest.py              # Shared fixtures (temp dirs, pyve runner)
│   │   ├── test_venv_workflow.py
│   │   ├── test_micromamba_workflow.py
│   │   ├── test_auto_detection.py
│   │   ├── test_bootstrap.py
│   │   ├── test_cross_platform.py
│   │   ├── test_doctor.py
│   │   ├── test_reinit.py
│   │   ├── test_run_command.py
│   │   ├── test_testenv.py
│   │   └── test_validate.py
│   ├── helpers/
│   │   ├── test_helper.bash         # Bats helper (setup, teardown, assertions, sources all lib modules)
│   │   └── pyve_test_helpers.py     # pytest helper (PyveRunner, temp project scaffolding)
│   └── fixtures/                    # Test data (sample environment.yml, conda-lock.yml, etc.)
├── docs/
│   ├── guides/
│   │   └── project_guide.md         # LLM-assisted project creation workflow
│   └── specs/
│       ├── features.md              # Requirements (what)
│       ├── tech_spec.md             # Architecture (how) — this file
│       ├── stories.md               # Implementation plan (when)
│       ├── testing_spec.md          # Testing strategy details
│       └── pyve-run-examples.md     # Usage examples for pyve run
├── .github/workflows/
│   └── test.yml                     # CI pipeline (unit, integration, micromamba, lint, coverage)
├── Makefile                         # Convenience targets (test, test-unit, test-integration, coverage)
├── pytest.ini                       # pytest configuration (markers, coverage, output)
├── requirements-dev.txt             # Python dev dependencies
├── LICENSE                          # Apache-2.0
├── README.md                        # User documentation
└── CONTRIBUTING.md                  # Contribution guidelines
```

---

## Key Component Design

### `pyve.sh` — Main Entry Point

The main script handles CLI argument parsing, sources all library modules, and dispatches to the appropriate command handler. All top-level command logic (init, purge, install, uninstall, run, doctor, test, etc.) lives here.

**Key globals:**

| Variable | Default | Purpose |
|----------|---------|---------|
| `VERSION` | `"1.1.3"` | Current Pyve version |
| `DEFAULT_PYTHON_VERSION` | `"3.14.3"` | Default Python version for new environments |
| `DEFAULT_VENV_DIR` | `".venv"` | Default venv directory name |
| `ENV_FILE_NAME` | `".env"` | Environment variables filename |
| `TESTENV_DIR_NAME` | `"testenv"` | Dev/test runner environment directory |

**Library sourcing order:** `utils.sh` → `env_detect.sh` → `backend_detect.sh` → `micromamba_core.sh` → `micromamba_env.sh` → `micromamba_bootstrap.sh` → `distutils_shim.sh` → `version.sh`

Each library guards against direct execution and is designed to be sourced only.

---

### `lib/utils.sh` — Core Utilities

Logging, user prompts, `.gitignore` management, config file parsing, and input validation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `log_info` | `(message)` | Print `INFO: <message>` to stdout |
| `log_warning` | `(message)` | Print `WARNING: <message>` to stderr |
| `log_error` | `(message)` | Print `ERROR: <message>` to stderr |
| `log_success` | `(message)` | Print `✓ <message>` to stdout |
| `prompt_yes_no` | `(prompt)` → 0/1 | Prompt user for y/n confirmation |
| `prompt_install_pip_dependencies` | `(backend?, env_path?)` → 0/1 | Prompt to install pip dependencies from `pyproject.toml` or `requirements.txt`; supports both venv and micromamba backends |
| `gitignore_has_pattern` | `(pattern)` → 0/1 | Check if exact line exists in `.gitignore` |
| `append_pattern_to_gitignore` | `(pattern)` | Append pattern if not already present |
| `insert_pattern_in_gitignore_section` | `(pattern, section_comment)` | Insert pattern after section comment; falls back to append |
| `remove_pattern_from_gitignore` | `(pattern)` | Remove exact line match from `.gitignore` |
| `write_gitignore_template` | `()` | Rebuild Pyve-managed template section, preserving user entries |
| `read_config_value` | `(key)` → string | Read value from `.pyve/config` (supports dotted keys) |
| `config_file_exists` | `()` → 0/1 | Check if `.pyve/config` exists |
| `validate_venv_dir_name` | `(dirname)` → 0/1 | Reject empty, reserved names, invalid characters |
| `validate_python_version` | `(version)` → 0/1 | Validate `#.#.#` semver format |
| `is_file_empty` | `(filename)` → 0/1 | Returns 0 if file is empty or missing |
| `check_cloud_sync_path` | `()` | Hard fail if `$PWD` is inside a known cloud-synced directory; bypassed by `PYVE_ALLOW_SYNCED_DIR=1` |
| `write_vscode_settings` | `(env_name)` | Write `.vscode/settings.json` with interpreter path and IDE isolation settings; skips if exists unless `PYVE_REINIT_MODE=force` |
| `doctor_check_duplicate_dist_info` | `(env_path)` | Scan `site-packages` for duplicate `.dist-info` dirs; reports conflicting versions with mtimes |
| `doctor_check_collision_artifacts` | `(env_path)` | Scan environment tree for files/dirs with ` 2` suffix (iCloud Drive collision artifacts) |
| `doctor_check_native_lib_conflicts` | `(env_path)` | Detect conda/pip OpenMP conflicts: pip-bundled libs (torch/tf/jax) + conda-linked libs (numpy/scipy) + missing `libomp.dylib`/`libgomp.so` |
| `doctor_check_venv_path` | `(env_path)` | Detect relocated venv: compare `pyvenv.cfg` creation path against actual venv location; warn with remediation if mismatched |

**`.gitignore` template structure:**
```
# macOS only
.DS_Store

# Python build and test artifacts
__pycache__
*.egg-info
.coverage
coverage.xml
htmlcov/
.pytest_cache/

# Pyve virtual environment
<dynamically inserted entries: .venv, .env, .envrc, .pyve/testenv, .pyve/envs, .vscode/settings.json>
```

The template is written via heredoc. User entries below the template are preserved. Deduplication prevents template lines from appearing in the user section.

---

### `lib/env_detect.sh` — Environment Detection

Version manager detection, Python version management, and direnv checks.

| Function | Signature | Description |
|----------|-----------|-------------|
| `source_shell_profiles` | `()` | Initialize asdf/pyenv in non-interactive shells |
| `detect_version_manager` | `()` → sets `VERSION_MANAGER` | Detect asdf (preferred) or pyenv; sets global |
| `is_python_version_installed` | `(version)` → 0/1 | Check if version is installed via current manager |
| `is_python_version_available` | `(version)` → 0/1 | Check if version is available to install |
| `install_python_version` | `(version)` → 0/1 | Install Python version via asdf or pyenv |
| `ensure_python_version_installed` | `(version)` → 0/1 | Install if not present, verify after |
| `set_local_python_version` | `(version)` → 0/1 | Write `.tool-versions` (asdf) or `.python-version` (pyenv) |
| `get_version_file_name` | `()` → string | Returns `.tool-versions` or `.python-version` |
| `check_direnv_installed` | `()` → 0/1 | Check if direnv is in PATH |

---

### `lib/backend_detect.sh` — Backend Detection

Determine which environment backend to use based on CLI flags, config, and project files.

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_backend_from_files` | `()` → string | Returns `"venv"`, `"micromamba"`, or `"none"` from project files |
| `get_backend_priority` | `(cli_backend, skip_config?)` → string | Resolve backend using priority chain: CLI > config (skipped when `skip_config=true`) > files > default; prompts interactively in ambiguous cases (both conda and Python files present) |
| `validate_backend` | `(backend)` → 0/1 | Validate backend value is `venv`, `micromamba`, or `auto` |
| `validate_config_file` | `()` → 0/1 | Validate `.pyve/config` structure |

---

### `lib/micromamba_core.sh` — Micromamba Binary Management

Locate and query the micromamba binary.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get_micromamba_path` | `()` → string | Search: `.pyve/bin/` > `~/.pyve/bin/` > system PATH |
| `check_micromamba_available` | `()` → 0/1 | Check if micromamba is found anywhere |
| `get_micromamba_version` | `()` → string | Return version string (e.g., `"1.5.3"`) |
| `get_micromamba_location` | `()` → string | Return `"project"`, `"user"`, `"system"`, or `"not_found"` |
| `error_micromamba_not_found` | `(context)` | Print error with installation instructions |

---

### `lib/micromamba_env.sh` — Micromamba Environment Management

Environment file parsing, naming resolution, environment creation, and lock file validation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_environment_file` | `()` → string | Return `conda-lock.yml` or `environment.yml` path |
| `parse_environment_name` | `(env_file?)` → string | Extract `name:` field from environment.yml |
| `parse_environment_channels` | `(env_file?)` → string | Extract channels list |
| `validate_environment_file` | `()` → 0/1 | Check environment file exists and is readable |
| `is_lock_file_stale` | `()` → 0/1 | Compare mtimes of environment.yml vs conda-lock.yml |
| `validate_lock_file_status` | `(strict_mode)` → 0/1 | Full lock file validation with user prompts |
| `sanitize_environment_name` | `(raw_name)` → string | Lowercase, replace special chars, trim hyphens |
| `is_reserved_environment_name` | `(name)` → 0/1 | Check against reserved names list |
| `validate_environment_name` | `(name)` → 0/1 | Full name validation |
| `resolve_environment_name` | `(cli_name?)` → string | Priority: CLI > config > env file > directory basename |
| `check_micromamba_env_exists` | `(env_name)` → 0/1 | Check if `.pyve/envs/<name>` exists |
| `create_micromamba_env` | `(env_name, env_file?)` → 0/1 | Create environment from file |
| `verify_micromamba_env` | `(env_name)` → 0/1 | Verify environment is functional |
| `is_interactive` | `()` → 0/1 | Detect interactive vs CI/batch mode |
| `run_lock` | `()` | Wrapper for `conda-lock`: backend guard, prerequisite check, platform detection, output filtering, rebuild guidance. Lives in `pyve.sh`. |

---

### `lib/micromamba_bootstrap.sh` — Micromamba Installation

Download and install micromamba binary.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get_micromamba_download_url` | `()` → string | Platform-specific download URL |
| `bootstrap_install_micromamba` | `(location)` → 0/1 | Download and install to `"project"` or `"user"` sandbox |
| `bootstrap_micromamba_interactive` | `(context?)` → 0/1 | Interactive prompt with 4 installation options |
| `bootstrap_micromamba_auto` | `(location?)` → 0/1 | Non-interactive install (default: user) |

---

### `lib/distutils_shim.sh` — Python 3.12+ Compatibility

Install a `sitecustomize.py` shim to prevent `distutils` import failures.

| Function | Signature | Description |
|----------|-----------|-------------|
| `pyve_is_distutils_shim_disabled` | `()` → 0/1 | Check `PYVE_DISABLE_DISTUTILS_SHIM` env var |
| `pyve_get_python_major_minor` | `(python_path)` → string | Return `"3.12"` etc. |
| `pyve_get_site_packages_dir` | `(python_path)` → string | Return site-packages path |
| `pyve_write_sitecustomize_shim` | `(site_packages_dir)` | Write the shim file |
| `pyve_distutils_shim_probe` | `(python_path)` | Lightweight check if shim is needed |
| `pyve_ensure_venv_packaging_prereqs` | `(python_path)` | Ensure pip, setuptools, wheel in venv |
| `pyve_ensure_micromamba_packaging_prereqs` | `(micromamba_path, env_prefix)` | Ensure pip, setuptools, wheel in micromamba env |
| `pyve_install_distutils_shim_for_python` | `(python_path)` | Full shim installation for venv |
| `pyve_install_distutils_shim_for_micromamba_prefix` | `(micromamba_path, env_prefix)` | Full shim installation for micromamba |

---

### `lib/version.sh` — Version Tracking & Validation

Version comparison, installation validation, and config file management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `compare_versions` | `(v1, v2)` → string | Return `"equal"`, `"greater"`, or `"less"` |
| `validate_pyve_version` | `()` → 0/1 | Compare recorded version with current |
| `validate_installation_structure` | `()` → 0/1 | Check `.pyve/` directory and config |
| `validate_venv_structure` | `()` → 0/1 | Check venv directory exists |
| `validate_micromamba_structure` | `()` → 0/1 | Check environment.yml and env directory |
| `run_full_validation` | `()` → exit code | Full validation report (0=pass, 1=errors, 2=warnings) |
| `write_config_with_version` | `()` | Create `.pyve/config` with current version |
| `update_config_version` | `()` | Update version in existing config |

---

## Configuration

### `.pyve/config` Format

```yaml
pyve_version: "1.1.3"
backend: venv | micromamba

micromamba:
  env_name: <name>
  env_file: environment.yml
  channels:
    - conda-forge
    - defaults
  prefix: .pyve/envs/<name>

python:
  version: "3.11"

venv:
  directory: .venv
```

Parsed by `read_config_value()` using simple `grep`/`sed` — not a full YAML parser. Supports top-level keys and one level of nesting via dotted notation (e.g., `micromamba.env_name`).

### Precedence

1. CLI flags
2. `.pyve/config`
3. Project files (`environment.yml`, `pyproject.toml`, etc.)
4. Hardcoded defaults in `pyve.sh`

---

## CLI Design

As of v1.11.0 (Story G.b.1 / FR-G1), Pyve uses a subcommand-style CLI consistent with modern developer tooling (`git`, `cargo`, `kubectl`, `gh`). The legacy flag-style top-level commands (`--init`, `--purge`, `--validate`, `--python-version`, `--install`, `--uninstall`) have been **removed**, and the `-i` / `-p` short aliases are **dropped** (Decision D1). Universal flags (`--help`, `--version`, `--config`) remain as flags per CLI convention.

### Commands

| Command | Description |
|---------|-------------|
| `pyve init [dir]` | Initialize Python virtual environment |
| `pyve purge [dir]` | Remove all Python environment artifacts |
| `pyve python-version <ver>` | Set Python version without creating an environment |
| `pyve validate` | Validate Pyve installation structure and version compatibility |
| `pyve lock [--check]` | Generate/update `conda-lock.yml` for current platform (micromamba only) |
| `pyve run <cmd> [args]` | Execute command in project environment |
| `pyve doctor` | Environment diagnostics |
| `pyve test [args]` | Run pytest in dev/test environment |
| `pyve testenv --init` | Initialize dev/test environment |
| `pyve testenv --install [-r]` | Install dev/test dependencies |
| `pyve testenv --purge` | Remove dev/test environment |
| `pyve testenv run <cmd>` | Execute command in dev/test environment |
| `pyve self install` | Install pyve to `~/.local/bin` |
| `pyve self uninstall` | Remove pyve from `~/.local/bin` |
| `pyve self` | Show `self` namespace help (no subcommand → namespace help only) |

### Universal Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--version` | `-v` | Show version |
| `--config` | `-c` | Show configuration |

### Per-Subcommand Help (Story G.b.2 / FR-G4)

Every renamed subcommand responds to `--help` / `-h` with a focused, man-page-style help block:

```
pyve init --help
pyve purge --help
pyve validate --help
pyve python-version --help
pyve self --help
pyve self install --help
pyve self uninstall --help
```

The `--help` intercept fires **before** the real handler runs, so help is always fast and side-effect-free. `pyve --help` is reorganized into four categories: *Environment*, *Execution*, *Diagnostics*, *Self management*.

### `self` Namespace

The `self` subcommand namespace (Decision D4) groups commands that manage Pyve's own installation, mirroring `git remote` / `kubectl config`:

- `pyve self install` — copy script + lib to `~/.local/bin`, create symlink, add to PATH, create `~/.local/.env` template. Idempotent.
- `pyve self uninstall` — remove script, symlink, lib/, PATH entry. Preserve `~/.local/.env` if non-empty.
- `pyve self` (no subcommand) — print the namespace help only. Does **not** fall through to top-level help.

### Modifier Flags

All modifier flags keep their names from pre-v1.11.0 and attach to their renamed subcommands.

| Flag | Applies to | Description |
|------|-----------|-------------|
| `--backend <type>` | `pyve init` | Force backend selection |
| `--env-name <name>` | `pyve init` | Micromamba environment name |
| `--local-env` | `pyve init` | Copy `~/.local/.env` template |
| `--no-direnv` | `pyve init` | Skip `.envrc` creation |
| `--force` | `pyve init` | Purge and re-initialize |
| `--update` | `pyve init` | Update in-place |
| `--auto-bootstrap` | `pyve init` | Auto-install micromamba |
| `--bootstrap-to <loc>` | `pyve init` | Bootstrap location (project/user) |
| `--strict` | `pyve init` | Enforce lock file validation |
| `--no-lock` | `pyve init` | Bypass missing `conda-lock.yml` hard error |
| `--allow-synced-dir` | `pyve init` | Bypass cloud-synced directory check |
| `--keep-testenv` | `pyve purge` | Preserve dev/test environment |
| `--project-guide` | `pyve init` | Force project-guide hook (overrides auto-skip) |
| `--no-project-guide` | `pyve init` | Skip the project-guide hook |
| `--project-guide-completion` | `pyve init` | Force shell completion wiring |
| `--no-project-guide-completion` | `pyve init` | Skip shell completion wiring |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (missing dependency, invalid input, operation failure) |
| 2 | Warnings only (validation) |
| 127 | Command not found (`pyve run`) |

---

## Cross-Cutting Concerns

### project-guide rc-file Sentinel (v1.12.0+, Story G.c / FR-G2)

The `pyve init --project-guide-completion` hook appends a sentinel-bracketed eval block to the user's `~/.zshrc` or `~/.bashrc`:

```bash
# >>> project-guide completion (added by pyve) >>>
command -v project-guide >/dev/null 2>&1 && \
  eval "$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
# <<< project-guide completion <<<
```

The opening sentinel comment (`# >>> project-guide completion (added by pyve) >>>`) is the source of truth for idempotent insertion and removal:

- **Insertion** (`add_project_guide_completion` in `lib/utils.sh`): no-op if the sentinel is already present. Preserves the rest of the rc file. Creates the rc file if missing.
- **Removal** (`remove_project_guide_completion` in `lib/utils.sh`): removes only the sentinel-bracketed block plus one immediately-preceding blank line (so add → remove round-trips cleanly). Awk-based, BSD/GNU compatible.
- **Detection** (`is_project_guide_completion_present` in `lib/utils.sh`): a single `grep -qF` against the opening sentinel.

The sentinels must not change without a migration plan. Users who installed the block with an older sentinel would end up with orphaned blocks on uninstall.

`pyve self uninstall` calls `remove_project_guide_completion()` for both `~/.zshrc` and `~/.bashrc` to cover users who switched shells after installing the block.

### project-guide Helper Functions (v1.12.0+, Story G.c / FR-G2)

The following helpers in `lib/utils.sh` implement the three-step project-guide hook (FR-16):

| Function | Purpose |
|---|---|
| `prompt_install_project_guide` | Y/n prompt with default Y; honors `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` / `CI` / `PYVE_FORCE_YES`. CI default = install. |
| `prompt_install_project_guide_completion` | Y/n prompt with default Y; honors `PYVE_PROJECT_GUIDE_COMPLETION` / `PYVE_NO_PROJECT_GUIDE_COMPLETION`. **CI default = SKIP** (deliberate asymmetry — editing rc files in CI is surprising). |
| `is_project_guide_installed(backend, env_path)` | Probes `<env_python> -c 'import project_guide'`. ~50ms. Returns 0 if importable. |
| `install_project_guide(backend, env_path)` | Step 1: runs `pip install --upgrade project-guide` against the project env. Always uses `--upgrade`. Failure-non-fatal. |
| `run_project_guide_init_in_env(backend, env_path)` | Step 2: runs `<env>/bin/project-guide init --no-input`. Requires project-guide >= 2.2.3. Failure-non-fatal. |
| `project_guide_in_project_deps()` | Auto-skip safety: returns 0 if `project-guide` is declared in `pyproject.toml`, `requirements.txt`, or `environment.yml`. Word-boundary regex to avoid false matches with similar names like `project-guide-extras`. |
| `detect_user_shell()` | Reads `$SHELL`, prints `zsh` / `bash` / `unknown`. |
| `get_shell_rc_path(shell)` | Maps `zsh` → `$HOME/.zshrc`, `bash` → `$HOME/.bashrc`, anything else → empty string. |
| `is_project_guide_completion_present(rc_path)` | Detects the sentinel block. |
| `add_project_guide_completion(rc_path, shell)` | Step 3: appends the sentinel-bracketed block. Idempotent. Creates rc file if missing. |
| `remove_project_guide_completion(rc_path)` | Removes the sentinel block. Safe no-op if absent. |

The orchestrator `run_project_guide_hooks(backend, env_path, pg_mode, comp_mode)` in `pyve.sh` calls these in priority order. Tri-state mode arguments (`""` / `"yes"` / `"no"`) come from CLI flag parsing in `init()`. The auto-skip safety mechanism fires between explicit flag overrides and the prompt/CI default path.

### Legacy-Flag Error Catch (v1.11.0+, Decision D3 — kept forever)

When a user invokes a removed legacy flag form (`pyve --init`, `pyve --purge`, `pyve --validate`, `pyve --python-version`, `pyve --install`, `pyve --uninstall`, or the `-i` / `-p` short aliases), the dispatcher in `main()` catches it and prints a precise migration error, then exits non-zero:

```
ERROR: 'pyve --init' is no longer supported. Use 'pyve init' instead.
ERROR: See: pyve --help
```

**Why kept forever:** Three lines of code, great error message, zero cost. Users coming from old README snippets, blog posts, third-party tutorials, and LLM training data will hit it for years and get a precise hint instead of an opaque "unknown command" error. Implemented via `legacy_flag_error()` helper in `pyve.sh`, called from the top-level dispatcher `case` block before any subcommand dispatch runs.

**No compat shim, no silent translation.** Silent translation hides the rename from users and builds long-term tech debt.

### Platform Portability

- **macOS vs Linux `sed`**: All `sed` operations use portable shell loops with temp files instead of `sed -i` (which has incompatible syntax between BSD and GNU). See v1.1.2/v1.1.3 for history.
- **Shell profiles**: `source_shell_profiles()` initializes asdf/pyenv directly rather than sourcing full shell profiles (which may contain interactive elements).
- **`.DS_Store`**: Auto-added to `.gitignore` template for macOS.

### Atomic File Operations

- `.gitignore` writes use `mktemp` + `mv` to avoid partial writes.
- Config file updates use temp files with atomic `mv`.

### Idempotency

- `write_gitignore_template()` rebuilds the template section from scratch on every call, deduplicating against existing content.
- `insert_pattern_in_gitignore_section()` checks `gitignore_has_pattern()` before inserting.
- `--init` detects existing installations and offers update/force paths.

### Security

- `.env` files: `chmod 600` on creation.
- `.env` always added to `.gitignore`.
- Non-empty `.env` preserved during purge/uninstall.

### Logging

All user-facing output uses the `log_*` functions from `utils.sh`:
- `log_success` → `✓` prefix
- `log_warning` → `WARNING:` to stderr
- `log_error` → `ERROR:` to stderr
- `log_info` → `INFO:` to stdout

---

## Testing Strategy

### Unit Tests (Bats)

White-box tests that source individual `lib/*.sh` modules and test functions directly.

| Test File | Module Under Test | Test Count |
|-----------|-------------------|------------|
| `test_utils.bats` | `lib/utils.sh` | — |
| `test_backend_detect.bats` | `lib/backend_detect.sh` | — |
| `test_config_parse.bats` | `lib/utils.sh` (config) | — |
| `test_distutils_shim.bats` | `lib/distutils_shim.sh` | — |
| `test_doctor.bats` | `lib/utils.sh` (doctor checks) | — |
| `test_env_naming.bats` | `lib/micromamba_env.sh` | — |
| `test_lock_validation.bats` | `lib/micromamba_env.sh` | — |
| `test_micromamba_bootstrap.bats` | `lib/micromamba_bootstrap.sh` | — |
| `test_micromamba_core.bats` | `lib/micromamba_core.sh` | — |
| `test_reinit.bats` | `lib/version.sh` | — |
| `test_version.bats` | `lib/version.sh` | — |

### Integration Tests (pytest)

Black-box tests that invoke `pyve.sh` as a subprocess and verify outcomes.

| Test File | Workflow Tested |
|-----------|-----------------|
| `test_venv_workflow.py` | Full venv lifecycle (init, run, purge, .gitignore) |
| `test_micromamba_workflow.py` | Full micromamba lifecycle |
| `test_auto_detection.py` | Backend auto-detection from project files |
| `test_bootstrap.py` | Micromamba bootstrap (placeholder, not yet implemented) |
| `test_cross_platform.py` | macOS/Linux-specific behavior |
| `test_doctor.py` | Doctor diagnostics for both backends |
| `test_force_ambiguous_prompt.py` | Interactive backend prompt in `--force` + ambiguous cases |
| `test_force_backend_detection.py` | Backend detection during `--force` re-initialization |
| `test_lock_command.py` | `pyve lock` command (backend guard, prerequisite, platform detection, output filtering) |
| `test_pip_upgrade.py` | pip upgrade during `--init` |
| `test_reinit.py` | Re-initialization (update, force) |
| `test_run_command.py` | `pyve run` for both backends |
| `test_testenv.py` | Dev/test runner environment |
| `test_validate.py` | Installation validation |

**Markers**: `venv`, `micromamba`, `requires_micromamba`, `requires_asdf`, `requires_direnv`, `macos`, `linux`, `slow`

### CI Pipeline (`.github/workflows/test.yml`)

| Job | Runner | Matrix | What it runs |
|-----|--------|--------|-------------|
| Unit Tests | ubuntu + macos | — | `make test-unit` (Bats) |
| Integration Tests | ubuntu + macos | Python 3.10, 3.11, 3.12 | pytest venv tests |
| Micromamba Tests | ubuntu + macos | Python 3.11 | pytest micromamba tests |
| Lint | ubuntu | — | ShellCheck, black, flake8 |
| Bash Coverage (kcov) | ubuntu | — | Line coverage of `lib/*.sh` and `pyve.sh` via kcov; uploads to Codecov |
| Test Summary | ubuntu | — | Gate: fail if unit or integration fail |
