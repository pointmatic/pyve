#!/usr/bin/env bash
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#============================================================
# pyve - Python Virtual Environment Manager
#
# A focused tool for setting up Python virtual environments on macOS and Linux.
# Manages Python versions (via asdf or pyenv), virtual environments, and direnv.
#
# Usage: pyve {--init | --purge | --python-version | --install | --uninstall | --help | --version | --config}
#============================================================

set -euo pipefail

#============================================================
# Configuration
#============================================================

VERSION="2.3.2"
DEFAULT_PYTHON_VERSION="3.14.4"
DEFAULT_VENV_DIR=".venv"
ENV_FILE_NAME=".env"
TESTENV_DIR_NAME="testenv"

# When set to 1, pyve may auto-install pytest into the dev/test runner environment
# without prompting (intended for CI and automated test harnesses).
PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT="${PYVE_TEST_AUTO_INSTALL_PYTEST:-}"

# Installation paths
TARGET_BIN_DIR="$HOME/.local/bin"
TARGET_SCRIPT_PATH="$TARGET_BIN_DIR/pyve.sh"
TARGET_SYMLINK_PATH="$TARGET_BIN_DIR/pyve"
LOCAL_ENV_FILE="$HOME/.local/.env"
SOURCE_DIR_FILE="$HOME/.local/.pyve_source"
PROMPT_HOOK_FILE="$HOME/.local/.pyve_prompt.sh"

#============================================================
# Resolve Script Directory and Source Libraries
#============================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper libraries
if [[ -f "$SCRIPT_DIR/lib/utils.sh" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
else
    printf "ERROR: Cannot find lib/utils.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/env_detect.sh" ]]; then
    source "$SCRIPT_DIR/lib/env_detect.sh"
else
    printf "ERROR: Cannot find lib/env_detect.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/backend_detect.sh" ]]; then
    source "$SCRIPT_DIR/lib/backend_detect.sh"
else
    printf "ERROR: Cannot find lib/backend_detect.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/micromamba_core.sh" ]]; then
    source "$SCRIPT_DIR/lib/micromamba_core.sh"
else
    printf "ERROR: Cannot find lib/micromamba_core.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/micromamba_bootstrap.sh" ]]; then
    source "$SCRIPT_DIR/lib/micromamba_bootstrap.sh"
else
    printf "ERROR: Cannot find lib/micromamba_bootstrap.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/micromamba_env.sh" ]]; then
    source "$SCRIPT_DIR/lib/micromamba_env.sh"
else
    printf "ERROR: Cannot find lib/micromamba_env.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/distutils_shim.sh" ]]; then
    source "$SCRIPT_DIR/lib/distutils_shim.sh"
else
    printf "ERROR: Cannot find lib/distutils_shim.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/version.sh" ]]; then
    source "$SCRIPT_DIR/lib/version.sh"
else
    printf "ERROR: Cannot find lib/version.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    # shellcheck source=lib/ui.sh
    source "$SCRIPT_DIR/lib/ui.sh"
else
    printf "ERROR: Cannot find lib/ui.sh\n" >&2
    exit 1
fi

#============================================================
# Source per-command modules (Phase K — alphabetical)
#============================================================

if [[ -f "$SCRIPT_DIR/lib/commands/lock.sh" ]]; then
    # shellcheck source=lib/commands/lock.sh
    source "$SCRIPT_DIR/lib/commands/lock.sh"
else
    printf "ERROR: Cannot find lib/commands/lock.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/python.sh" ]]; then
    # shellcheck source=lib/commands/python.sh
    source "$SCRIPT_DIR/lib/commands/python.sh"
else
    printf "ERROR: Cannot find lib/commands/python.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/run.sh" ]]; then
    # shellcheck source=lib/commands/run.sh
    source "$SCRIPT_DIR/lib/commands/run.sh"
else
    printf "ERROR: Cannot find lib/commands/run.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/self.sh" ]]; then
    # shellcheck source=lib/commands/self.sh
    source "$SCRIPT_DIR/lib/commands/self.sh"
else
    printf "ERROR: Cannot find lib/commands/self.sh\n" >&2
    exit 1
fi

#============================================================
# Help and Information Commands
#============================================================

show_help() {
    cat << 'EOF'
pyve - Python Virtual Environment Manager

USAGE:
    pyve <command> [options]
    pyve --help | --version | --config

For per-command help:
    pyve <command> --help

COMMANDS:

  Environment:
    init [<dir>]              Initialize a Python virtual environment
                              Auto-detects backend (venv / micromamba)
                              See `pyve init --help` for all options
    update                    Non-destructive upgrade: refresh managed files
                              and config without rebuilding the venv
                              See `pyve update --help` for all options
    purge [<dir>]             Remove all Python environment artifacts
                              See `pyve purge --help` for all options
    python set <ver>          Pin the project's Python version (format: #.#.#)
    python show               Show the currently pinned Python version
                              See `pyve python --help` for details
    lock [--check]            Generate or verify conda-lock.yml (micromamba only)
                              --check: mtime-only verification (no conda-lock needed)

  Execution:
    run <command> [args...]   Run a command inside the project environment
                              For CI/CD, Docker, and --no-direnv setups
    test [pytest args...]     Run pytest via the dev/test runner environment
    testenv <subcommand>      Manage the dev/test runner environment
                              Subcommands: init | install [-r <req>] | purge | run <cmd>
                              (Legacy flag forms --init / --install / --purge still accepted)
                              See `pyve testenv --help` for details

  Diagnostics:
    check                     Diagnose environment problems and suggest fixes
                              Exit codes: 0 (pass), 1 (errors), 2 (warnings)
                              See `pyve check --help` for details
    status                    Read-only snapshot of current project state
                              (backend, python, integrations). Never exits non-zero.
                              See `pyve status --help` for details

  Self management:
    self install              Install pyve to ~/.local/bin
    self uninstall            Remove pyve from ~/.local/bin
    self                      Show the self-namespace help

UNIVERSAL FLAGS:
    --help, -h                Show this help message
    --version, -v             Show version
    --config, -c              Show current configuration

EXAMPLES:
    pyve init                            # Initialize with defaults (auto-detect backend)
    pyve init myenv                      # Use custom venv directory
    pyve init --python-version 3.12.0    # Specify Python version
    pyve init --backend venv             # Explicitly use venv backend
    pyve init --backend micromamba       # Explicitly use micromamba backend
    pyve init --no-direnv                # Skip direnv (for CI/CD)
    pyve run python --version            # Run command in environment
    pyve run pytest                      # Run tests in environment
    pyve testenv init                    # Create dev/test runner environment
    pyve testenv install -r requirements-dev.txt  # Install dev/test deps
    pyve testenv run ruff check .        # Run dev tools from testenv
    pyve test -q                         # Run pytest via dev/test runner
    pyve lock                            # Generate/update conda-lock.yml
    pyve lock --check                    # Verify conda-lock.yml is current (CI gate)
    pyve check                           # Diagnose environment problems
    pyve status                          # Read-only snapshot of project state
    pyve purge                           # Remove environment (prompts for confirmation)
    pyve purge --yes                     # Remove environment without prompting
    pyve python set 3.13.7               # Set the project's Python version
    pyve python show                     # Show the currently pinned Python version
    pyve self install                    # Install pyve to ~/.local/bin

REQUIREMENTS:
    - asdf (recommended) or pyenv for Python version management
    - direnv for automatic environment activation
EOF
}

testenv_paths() {
    local testenv_root=".pyve/$TESTENV_DIR_NAME"
    local testenv_venv="$testenv_root/venv"
    printf "%s\n" "$testenv_root" "$testenv_venv"
}

ensure_testenv_exists() {
    local paths
    local testenv_root
    local testenv_venv
    paths="$(testenv_paths)"
    testenv_root="$(printf "%s" "$paths" | sed -n '1p')"
    testenv_venv="$(printf "%s" "$paths" | sed -n '2p')"

    mkdir -p "$testenv_root"

    # If the testenv exists but was built with a different Python version (e.g.
    # the project Python was changed after the initial pyve init, then pyve init
    # --force preserved the old testenv via --keep-testenv), rebuild it.
    if [[ -d "$testenv_venv" ]] && [[ -f "$testenv_venv/pyvenv.cfg" ]]; then
        local testenv_ver current_ver
        testenv_ver="$(awk -F' *= *' '/^version/{print $2; exit}' "$testenv_venv/pyvenv.cfg" 2>/dev/null || true)"
        current_ver="$(python -c 'import sys; print(".".join(str(x) for x in sys.version_info[:3]))' 2>/dev/null || true)"
        if [[ -n "$testenv_ver" && -n "$current_ver" && "$testenv_ver" != "$current_ver" ]]; then
            warn "Testenv Python ($testenv_ver) differs from project Python ($current_ver) — rebuilding testenv..."
            rm -rf "$testenv_venv"
        fi
    fi

    if [[ ! -d "$testenv_venv" ]]; then
        info "Creating dev/test runner environment in '$testenv_venv'..."
        run_cmd python -m venv "$testenv_venv"
        success "Created dev/test runner environment"
    fi
}

testenv_has_pytest() {
    local testenv_venv="$1"
    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        return 1
    fi
    "$testenv_venv/bin/python" -c "import pytest" >/dev/null 2>&1
}

install_pytest_into_testenv() {
    local testenv_venv="$1"
    local requirements_file=""

    if [[ -f "requirements-dev.txt" ]]; then
        requirements_file="requirements-dev.txt"
    fi

    info "Installing pytest into dev/test runner environment..."
    if [[ -n "$requirements_file" ]]; then
        run_cmd "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
    else
        run_cmd "$testenv_venv/bin/python" -m pip install pytest
    fi
    success "pytest installed"
}

show_version() {
    printf "pyve version %s\n" "$VERSION"
}

show_config() {
    local detected_backend
    detected_backend="$(detect_backend_from_files)"
    
    local config_backend=""
    local config_exists="no"
    if config_file_exists; then
        config_exists="yes"
        config_backend="$(read_config_value "backend")"
    fi
    
    # Check micromamba status
    local micromamba_status="not found"
    local micromamba_location=""
    local micromamba_version=""
    if check_micromamba_available; then
        micromamba_location="$(get_micromamba_location)"
        micromamba_version="$(get_micromamba_version)"
        micromamba_status="available ($micromamba_location)"
        if [[ -n "$micromamba_version" ]]; then
            micromamba_status="$micromamba_status v$micromamba_version"
        fi
    fi
    
    # Check environment file
    local env_file_status="none"
    local env_file
    env_file="$(detect_environment_file 2>/dev/null)" || true
    if [[ -n "$env_file" ]]; then
        env_file_status="$env_file"
        # Add environment name if available
        if [[ "$env_file" == "environment.yml" ]]; then
            local env_name
            env_name="$(parse_environment_name "$env_file" 2>/dev/null)" || true
            if [[ -n "$env_name" ]]; then
                env_file_status="$env_file (name: $env_name)"
            fi
        fi
    fi
    
    printf "pyve configuration:\n"
    printf "  Version:                %s\n" "$VERSION"
    printf "  Default Python version: %s\n" "$DEFAULT_PYTHON_VERSION"
    printf "  Default venv directory: %s\n" "$DEFAULT_VENV_DIR"
    printf "  Default backend:        venv\n"
    printf "  Config file (.pyve/config): %s\n" "$config_exists"
    if [[ "$config_exists" == "yes" ]] && [[ -n "$config_backend" ]]; then
        printf "  Config backend:         %s\n" "$config_backend"
    fi
    printf "  Detected backend:       %s\n" "$detected_backend"
    printf "  Micromamba:             %s\n" "$micromamba_status"
    printf "  Conda env file:         %s\n" "$env_file_status"
    printf "  Environment file:       %s\n" "$ENV_FILE_NAME"
    printf "  Install directory:      %s\n" "$TARGET_BIN_DIR"
}

#============================================================
# Init Command
#============================================================

# Run the project-guide post-init hooks: install the package into the
# project env, then optionally add shell completion to the user rc file.
#
# Both steps are failure-non-fatal — pyve init continues even on errors.
# Respects CLI-flag overrides via the "mode" arguments (pre-resolved by
# init() from --project-guide / --no-project-guide and their completion
# siblings). When mode is empty, falls through to the env-var / CI /
# interactive logic inside the prompt helpers.
#
# Usage: run_project_guide_hooks <backend> <env_path> <pg_mode> <comp_mode>
#   backend:   "venv" | "micromamba"
#   env_path:  path to the project environment
#   pg_mode:   "" | "yes" | "no"  (from --project-guide / --no-project-guide)
#   comp_mode: "" | "yes" | "no"  (from --project-guide-completion / etc.)
run_project_guide_hooks() {
    local backend="$1"
    local env_path="$2"
    local pg_mode="$3"
    local comp_mode="$4"

    # Resolve CLI flag overrides into a tri-state.
    local should_install=0  # 0 = unknown (consult env vars / prompt), 1 = yes, 2 = no
    case "$pg_mode" in
        yes) should_install=1 ;;
        no)  should_install=2 ;;
    esac

    local should_add_completion=0
    case "$comp_mode" in
        yes) should_add_completion=1 ;;
        no)  should_add_completion=2 ;;
    esac

    #--- Install decision -------------------------------------------------
    # Priority order:
    #   1. --no-project-guide flag                  → skip silent
    #   2. --project-guide flag                     → install (overrides auto-skip)
    #   3. PYVE_NO_PROJECT_GUIDE=1 / PYVE_PROJECT_GUIDE=1 → handled by prompt_install_project_guide
    #   4. project-guide already in project deps    → AUTO-SKIP with INFO message
    #   5. CI / PYVE_FORCE_YES                      → install (CI default)
    #   6. interactive                              → prompt, default Y
    #---------------------------------------------------------------------
    if [[ $should_install -eq 2 ]]; then
        log_info "Skipping project-guide install (--no-project-guide)"
        return 0
    fi

    local do_install=false
    if [[ $should_install -eq 1 ]]; then
        do_install=true
    else
        # Auto-skip safety: if project-guide is already declared as a project
        # dependency, do not let pyve manage it. The user's pin wins; pyve's
        # install/upgrade would just create a version conflict at the next
        # `pip install -e .`.
        if project_guide_in_project_deps; then
            log_info "Detected 'project-guide' in your project dependencies."
            log_info "Pyve will not auto-install or run 'project-guide init' to avoid a version conflict."
            log_info "Project-guide will be installed when your project dependencies are installed."
            log_info "To override and let pyve manage it anyway, pass --project-guide."
            log_info "To suppress this message, pass --no-project-guide."
            return 0
        fi

        if prompt_install_project_guide; then
            do_install=true
        fi
    fi

    if [[ "$do_install" != true ]]; then
        return 0
    fi

    #--- Step 1: pip install --upgrade project-guide ----------------------
    install_project_guide "$backend" "$env_path" || true

    # If install actually failed, don't proceed to step 2 or 3 — running
    # `project-guide init` against a missing binary or adding a completion
    # eval for a missing tool would just leave dead state.
    if ! is_project_guide_installed "$backend" "$env_path"; then
        return 0
    fi

    #--- Step 2: scaffold or refresh managed artifacts --------------------
    # Branch on `.project-guide.yml` presence (Story G.h):
    #   - absent → first-time scaffolding: `project-guide init --no-input`
    #   - present → refresh: `project-guide update --no-input` — preserves
    #     user state (current_mode, overrides, test_first, pyve_version)
    #     and creates `.bak.<ts>` siblings for modified managed files.
    # Pyve never auto-runs `project-guide init --force` because it is
    # destructive (resets config, no backups); that remains user-initiated.
    if [[ -f ".project-guide.yml" ]]; then
        run_project_guide_update_in_env "$backend" "$env_path"
    else
        run_project_guide_init_in_env "$backend" "$env_path"
    fi

    #--- Step 3: shell completion wiring ----------------------------------
    if [[ $should_add_completion -eq 2 ]]; then
        log_info "Skipping project-guide completion wiring (--no-project-guide-completion)"
        return 0
    fi

    local do_completion=false
    if [[ $should_add_completion -eq 1 ]]; then
        do_completion=true
    elif prompt_install_project_guide_completion; then
        do_completion=true
    fi

    if [[ "$do_completion" != true ]]; then
        return 0
    fi

    local user_shell
    user_shell="$(detect_user_shell)"
    if [[ "$user_shell" == "unknown" ]]; then
        log_warning "Unknown shell — skipping project-guide completion wiring."
        log_warning "  For manual setup, add to your shell rc file:"
        log_warning "    eval \"\$(_PROJECT_GUIDE_COMPLETE=<shell>_source project-guide)\""
        return 0
    fi

    local rc_path
    rc_path="$(get_shell_rc_path "$user_shell")"
    if [[ -z "$rc_path" ]]; then
        log_warning "Could not determine rc file for shell '$user_shell' — skipping completion wiring"
        return 0
    fi

    if is_project_guide_completion_present "$rc_path"; then
        log_info "project-guide completion already present in $rc_path"
        return 0
    fi

    if add_project_guide_completion "$rc_path" "$user_shell"; then
        log_success "Added project-guide completion to $rc_path"
        log_info "  Reload your shell or run: source $rc_path"
    else
        log_warning "Failed to write project-guide completion to $rc_path (continuing)"
    fi
}

init() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local python_version="$DEFAULT_PYTHON_VERSION"
    local use_local_env=false
    local backend_flag=""
    local auto_bootstrap=false
    local bootstrap_to="user"
    local strict_mode=false
    local env_name_flag=""
    local no_direnv=false
    local lock_preflight_done=false
    local preflight_backend=""

    # project-guide integration (Story G.c / FR-G2) — tri-state:
    # "" (unset — use env vars / prompt / CI default), "yes" (force install),
    # "no" (force skip). Set by --project-guide / --no-project-guide flags.
    local project_guide_mode=""
    local project_guide_completion_mode=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --python-version)
                if [[ -z "${2:-}" ]]; then
                    log_error "--python-version requires a version argument"
                    exit 1
                fi
                python_version="$2"
                shift 2
                ;;
            --backend)
                if [[ -z "${2:-}" ]]; then
                    log_error "--backend requires a backend type (venv, micromamba, auto)"
                    exit 1
                fi
                backend_flag="$2"
                shift 2
                ;;
            --local-env)
                use_local_env=true
                shift
                ;;
            --auto-bootstrap)
                auto_bootstrap=true
                shift
                ;;
            --bootstrap-to)
                if [[ -z "${2:-}" ]]; then
                    log_error "--bootstrap-to requires a location (project, user)"
                    exit 1
                fi
                bootstrap_to="$2"
                if [[ "$bootstrap_to" != "project" ]] && [[ "$bootstrap_to" != "user" ]]; then
                    log_error "Invalid --bootstrap-to value: $bootstrap_to"
                    log_error "Must be 'project' or 'user'"
                    exit 1
                fi
                shift 2
                ;;
            --strict)
                strict_mode=true
                shift
                ;;
            --no-lock)
                export PYVE_NO_LOCK=1
                shift
                ;;
            --env-name)
                if [[ -z "${2:-}" ]]; then
                    log_error "--env-name requires an environment name"
                    exit 1
                fi
                env_name_flag="$2"
                shift 2
                ;;
            --no-direnv)
                no_direnv=true
                shift
                ;;
            --auto-install-deps)
                export PYVE_AUTO_INSTALL_DEPS=1
                shift
                ;;
            --no-install-deps)
                export PYVE_NO_INSTALL_DEPS=1
                shift
                ;;
            --allow-synced-dir)
                export PYVE_ALLOW_SYNCED_DIR=1
                shift
                ;;
            --update)
                # Removed in v2.0 (H.e.9). Hard error — semantics of
                # `pyve update` are broader than v1.x's narrow
                # config-bump, so delegation would surprise scripted
                # callers. See phase-H-cli-refactor-design.md §5 D3.
                legacy_flag_error "init --update" "update"
                ;;
            --force)
                PYVE_REINIT_MODE="force"
                shift
                ;;
            --project-guide)
                if [[ "$project_guide_mode" == "no" ]]; then
                    log_error "--project-guide and --no-project-guide are mutually exclusive"
                    exit 1
                fi
                project_guide_mode="yes"
                shift
                ;;
            --no-project-guide)
                if [[ "$project_guide_mode" == "yes" ]]; then
                    log_error "--project-guide and --no-project-guide are mutually exclusive"
                    exit 1
                fi
                project_guide_mode="no"
                shift
                ;;
            --project-guide-completion)
                if [[ "$project_guide_completion_mode" == "no" ]]; then
                    log_error "--project-guide-completion and --no-project-guide-completion are mutually exclusive"
                    exit 1
                fi
                project_guide_completion_mode="yes"
                shift
                ;;
            --no-project-guide-completion)
                if [[ "$project_guide_completion_mode" == "yes" ]]; then
                    log_error "--project-guide-completion and --no-project-guide-completion are mutually exclusive"
                    exit 1
                fi
                project_guide_completion_mode="no"
                shift
                ;;
            -*)
                unknown_flag_error "init" "$1" \
                    --python-version --backend --auto-bootstrap --bootstrap-to \
                    --strict --no-lock --env-name --no-direnv --auto-install-deps \
                    --no-install-deps --local-env --force --allow-synced-dir \
                    --project-guide --no-project-guide \
                    --project-guide-completion --no-project-guide-completion \
                    --help
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done

    header_box "pyve init"

    # Refuse to initialize inside a cloud-synced directory (use --allow-synced-dir to override)
    check_cloud_sync_path

    # Check for existing installation (re-initialization detection)
    if config_file_exists; then
        local existing_backend
        existing_backend="$(read_config_value "backend")"
        local existing_version
        existing_version="$(read_config_value "pyve_version")"
        
        # Handle re-initialization based on mode.
        # (PYVE_REINIT_MODE="update" path removed in v2.0 / H.e.9 —
        # `pyve update` is the new entry point.)
        if [[ "${PYVE_REINIT_MODE:-}" == "force" ]]; then
            # Force re-initialization mode
            warn "Force re-initialization: this will purge the existing environment ($existing_backend)"

            # Run pre-flight checks BEFORE purging so the environment is still intact
            # if the user decides to abort or a check fails.
            # We capture the backend here and reuse it in the main flow to avoid
            # prompting the user twice in the ambiguous case (env.yml + pyproject.toml).
            # skip_config=true: --force is a clean slate — the config records the OLD
            # backend and must not prevent re-detection from project files.
            preflight_backend="$(get_backend_priority "$backend_flag" "true")"
            if [[ "$preflight_backend" == "micromamba" ]]; then
                # Mirror the non-force flow (see the main micromamba branch below):
                # scaffold a starter environment.yml on a fresh dir BEFORE lock
                # validation, otherwise validate_lock_file_status's "neither file"
                # case fires and aborts the switch on projects that the non-force
                # path handles fine.
                if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode"; then
                    info "Scaffolded starter environment.yml (python=$python_version)"
                    info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
                    export PYVE_NO_LOCK=1
                fi
                if ! validate_lock_file_status "$strict_mode"; then
                    fail "Pre-flight check failed — no changes made"
                fi
                lock_preflight_done=true
            fi

            # Prompt for confirmation (skip in CI or if PYVE_FORCE_YES is set).
            # Show a summary of what will happen so the user can make an informed choice.
            if [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
                if [[ "$preflight_backend" != "$existing_backend" ]]; then
                    warn "Backend change: $existing_backend → $preflight_backend"
                fi
                info "Purge:   existing $existing_backend environment"
                info "Rebuild: fresh $preflight_backend environment"
                if ! ask_yn "Proceed"; then
                    info "Cancelled — no changes made, existing environment preserved"
                    exit 0
                fi
            fi

            # Don't preserve backend on --force - let normal detection happen
            # This allows the interactive prompt to appear in ambiguous cases
            # (when both environment.yml and pyproject.toml exist)

            # Purge existing installation
            banner "Purging existing environment"
            purge --keep-testenv --yes
            success "Environment purged"
            banner "Rebuilding fresh environment"

        else
            # Interactive mode (no flag specified)
            warn "Project already initialized with Pyve"
            if [[ -n "$existing_version" ]]; then
                info "Recorded version: $existing_version"
            fi
            info "Current version:  $VERSION"
            info "Backend:          $existing_backend"
            printf "\n  What would you like to do?\n"
            printf "    1. Update in-place (preserves environment, updates config)\n"
            printf "    2. Purge and re-initialize (clean slate)\n"
            printf "    3. Cancel\n\n"
            printf "  %sChoose [1/2/3]:%s " "${Y}" "${RESET}"
            read -r choice

            case "$choice" in
                1)
                    # Check for conflicts before updating
                    if [[ -n "$backend_flag" ]] && [[ "$backend_flag" != "$existing_backend" ]]; then
                        warn "Cannot update in-place: backend change detected ($existing_backend → $backend_flag)"
                        fail "Use option 2 to purge and re-initialize with new backend"
                    fi

                    # Perform safe update
                    if ! update_config_version; then
                        fail "Failed to update configuration (config may be corrupted)"
                    fi
                    success "Configuration updated"
                    if [[ -n "$existing_version" ]]; then
                        info "Version: $existing_version → $VERSION"
                    else
                        info "Version: (not recorded) → $VERSION"
                    fi
                    info "Backend: $existing_backend (unchanged)"
                    info "Project updated to Pyve v$VERSION"

                    # If the environment directory is missing (e.g. freshly cloned repo
                    # where .venv is gitignored), fall through to create it.
                    local _interactive_env_missing=false
                    if [[ "$existing_backend" == "venv" ]]; then
                        local _interactive_venv_dir
                        _interactive_venv_dir="$(read_config_value "venv.directory")"
                        _interactive_venv_dir="${_interactive_venv_dir:-$DEFAULT_VENV_DIR}"
                        if [[ ! -d "$_interactive_venv_dir" ]]; then
                            info "Environment directory '$_interactive_venv_dir' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    elif [[ "$existing_backend" == "micromamba" ]]; then
                        local _interactive_env_name
                        _interactive_env_name="$(read_config_value "micromamba.env_name")"
                        if [[ -n "$_interactive_env_name" ]] && [[ ! -d ".pyve/envs/$_interactive_env_name" ]]; then
                            info "Environment '.pyve/envs/$_interactive_env_name' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    fi
                    if [[ "$_interactive_env_missing" == false ]]; then
                        footer_box
                        return 0
                    fi
                    # Fall through to environment creation below.
                    ;;
                2)
                    # Purge and continue
                    banner "Purging existing environment"
                    purge --keep-testenv --yes
                    success "Environment purged"
                    banner "Rebuilding fresh environment"
                    ;;
                3)
                    info "Initialization cancelled"
                    exit 0
                    ;;
                *)
                    fail "Invalid choice: $choice"
                    ;;
            esac
        fi
    fi
    
    # Validate backend if specified
    if [[ -n "$backend_flag" ]]; then
        if ! validate_backend "$backend_flag"; then
            exit 1
        fi
    fi
    
    # Determine backend to use
    # If the force pre-flight already resolved the backend (to avoid prompting twice
    # in the ambiguous env.yml + pyproject.toml case), reuse that result.
    local backend
    if [[ -n "$preflight_backend" ]]; then
        backend="$preflight_backend"
    else
        backend="$(get_backend_priority "$backend_flag")"
    fi
    
    # Check if micromamba backend is selected and handle bootstrap
    if [[ "$backend" == "micromamba" ]]; then
        # H.f.7: if the directory has neither `environment.yml` nor
        # `conda-lock.yml`, and strict-mode is off, scaffold a starter
        # `environment.yml` before the (expensive) bootstrap step.
        # Doing this early means the user-visible error surface in a
        # clean directory is "scaffolded and proceeded" instead of the
        # H.f.6 "missing environment.yml" hard-error path.
        if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode"; then
            info "Scaffolded starter environment.yml (python=$python_version)"
            info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
            # No conda-lock.yml yet (we just generated the source file).
            # Take validate_lock_file_status's existing bypass so init
            # proceeds without insisting on a lock that can't yet exist.
            export PYVE_NO_LOCK=1
        fi

        # Check if micromamba is available
        if ! check_micromamba_available; then
            # Micromamba not found - offer bootstrap
            if [[ "$auto_bootstrap" == true ]]; then
                # Auto-bootstrap mode (non-interactive)
                if ! bootstrap_micromamba_auto "$bootstrap_to"; then
                    exit 1
                fi
            else
                # Interactive bootstrap prompt
                local context=$'Detected: environment.yml\nRequired: micromamba'
                if ! bootstrap_micromamba_interactive "$context"; then
                    exit 1
                fi
            fi
        fi
        
        # At this point, micromamba should be available
        if ! check_micromamba_available; then
            log_error "Micromamba still not available after bootstrap attempt"
            exit 1
        fi
        
        # Validate lock file status if micromamba backend
        # (skipped when pre-flight already ran it in --force path)
        if [[ "$lock_preflight_done" != "true" ]]; then
            if ! validate_lock_file_status "$strict_mode"; then
                exit 1
            fi
        fi
        
        # Resolve and validate environment name
        local env_name
        env_name="$(resolve_environment_name "$env_name_flag")"
        if ! validate_environment_name "$env_name"; then
            exit 1
        fi
        info "Environment name: $env_name"

        # Validate environment file
        if ! validate_environment_file; then
            exit 1
        fi

        # Create micromamba environment
        banner "Initializing micromamba environment"
        info "Backend:         micromamba"
        info "Environment:     $env_name"

        local env_file
        env_file="$(detect_environment_file)"
        info "Using file:      $env_file"

        if ! create_micromamba_env "$env_name" "$env_file"; then
            exit 1
        fi

        # Verify environment
        if ! verify_micromamba_env "$env_name"; then
            warn "Environment created but verification failed"
        fi

        # Apply Python 3.12+ distutils shim if needed
        local env_prefix
        env_prefix=".pyve/envs/$env_name"
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -n "$micromamba_path" ]]; then
            pyve_install_distutils_shim_for_micromamba_prefix "$micromamba_path" "$env_prefix"
        fi

        # Configure direnv for micromamba (unless --no-direnv)
        local env_path=".pyve/envs/$env_name"
        if [[ "$no_direnv" == false ]]; then
            init_direnv_micromamba "$env_name" "$env_path"
        else
            info "Skipping .envrc creation (--no-direnv)"
        fi

        # Create .env file
        init_dotenv "$use_local_env"

        # Update .gitignore — since H.e.2a the template bakes in every
        # pyve-managed ignore pattern (.pyve/envs, .pyve/testenv, .envrc,
        # .env, .vscode/settings.json), so the micromamba path needs no
        # per-backend dynamic inserts.
        write_gitignore_template

        success "Updated .gitignore"

        # Create .pyve/config with version tracking
        mkdir -p .pyve
        cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: micromamba
micromamba:
  env_name: $env_name
EOF
        success "Created .pyve/config"

        # Generate .vscode/settings.json so IDEs use the correct interpreter
        write_vscode_settings "$env_name"

        info "Environment location: $env_path"

        # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
        prompt_install_pip_dependencies "micromamba" "$env_path"

        # project-guide hook (Story G.c / FR-G2)
        run_project_guide_hooks "micromamba" "$env_path" \
            "$project_guide_mode" "$project_guide_completion_mode"

        if [[ "$no_direnv" == false ]]; then
            info "Note: ignore micromamba's 'activate' instructions above — Pyve uses direnv (or 'pyve run')"
            info "Next: run 'direnv allow' to activate the environment, or use 'pyve run <command>'"
        else
            info "Use 'pyve run <command>' to execute in environment"
        fi
        footer_box

        return 0
    fi
    
    # Validate inputs
    if ! validate_venv_dir_name "$venv_dir"; then
        exit 1
    fi
    
    if ! validate_python_version "$python_version"; then
        exit 1
    fi
    
    banner "Initializing Python environment"
    info "Backend:        $backend"
    info "Python version: $python_version"
    info "Venv directory: $venv_dir"

    # Source shell profiles to find version managers
    source_shell_profiles

    # Detect and validate version manager
    if ! detect_version_manager; then
        exit 1
    fi
    info "Using $VERSION_MANAGER for Python version management"

    # Check direnv (only if not using --no-direnv)
    if [[ "$no_direnv" == false ]]; then
        if ! check_direnv_installed; then
            exit 1
        fi
    fi

    # Ensure Python version is installed
    if ! ensure_python_version_installed "$python_version"; then
        exit 1
    fi

    # Set local Python version
    init_python_version "$python_version"

    # Create virtual environment
    init_venv "$venv_dir"

    # Apply Python 3.12+ distutils shim if needed
    if [[ -x "$venv_dir/bin/python" ]]; then
        pyve_install_distutils_shim_for_python "$venv_dir/bin/python"
    fi

    # Configure direnv (unless --no-direnv)
    if [[ "$no_direnv" == false ]]; then
        init_direnv_venv "$venv_dir"
    else
        info "Skipping .envrc creation (--no-direnv)"
    fi

    # Create .env file
    init_dotenv "$use_local_env"

    # Update .gitignore
    init_gitignore "$venv_dir"

    # Create .pyve/config with version tracking
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: venv
venv:
  directory: $venv_dir
python:
  version: $python_version
EOF
    success "Created .pyve/config"

    # Ensure dev/test runner environment exists (upgrade-friendly)
    ensure_testenv_exists

    # Absolute venv path — used by both dep install and project-guide hooks
    local _venv_abs
    _venv_abs="$(cd "$venv_dir" && pwd)"

    # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
    prompt_install_pip_dependencies "venv" "$_venv_abs"

    # project-guide hook (Story G.c / FR-G2)
    run_project_guide_hooks "venv" "$_venv_abs" \
        "$project_guide_mode" "$project_guide_completion_mode"

    if [[ "$no_direnv" == false ]]; then
        info "Next step: run 'direnv allow' to activate the environment"
    else
        info "Use 'pyve run <command>' to execute commands in the environment"
    fi
    footer_box
}

init_python_version() {
    local version="$1"
    local version_file
    version_file="$(get_version_file_name)"
    
    if [[ -f "$version_file" ]]; then
        info "$version_file already exists, skipping"
    else
        set_local_python_version "$version"
        success "Created $version_file with Python $version"
    fi
}

init_venv() {
    local venv_dir="$1"

    if [[ -d "$venv_dir" ]]; then
        info "Virtual environment '$venv_dir' already exists, skipping"
    else
        info "Creating virtual environment in '$venv_dir'..."
        run_cmd python -m venv "$venv_dir"
        success "Created virtual environment"
    fi
}

init_direnv_venv() {
    local venv_dir="$1"
    local project_name
    project_name="$(basename "$(pwd)")"

    write_envrc_template "$venv_dir/bin" "VIRTUAL_ENV" "$venv_dir" "venv" "$project_name"
}

init_direnv_micromamba() {
    local env_name="$1"
    local env_path="$2"

    write_envrc_template "$env_path/bin" "CONDA_PREFIX" "$env_path" "micromamba" "$env_name"
}

init_dotenv() {
    local use_local_env="$1"

    if [[ -f "$ENV_FILE_NAME" ]]; then
        info "$ENV_FILE_NAME already exists, skipping"
        return
    fi

    if [[ "$use_local_env" == true ]] && [[ -f "$LOCAL_ENV_FILE" ]]; then
        cp "$LOCAL_ENV_FILE" "$ENV_FILE_NAME"
        success "Copied $LOCAL_ENV_FILE to $ENV_FILE_NAME"
    else
        touch "$ENV_FILE_NAME"
        if [[ "$use_local_env" == true ]]; then
            warn "$LOCAL_ENV_FILE not found, created empty $ENV_FILE_NAME"
        else
            success "Created empty $ENV_FILE_NAME"
        fi
    fi

    # Set secure permissions
    chmod 600 "$ENV_FILE_NAME"
}

init_gitignore() {
    local venv_dir="$1"
    local section="# Pyve virtual environment"

    # Rebuild .gitignore: Pyve-managed template at top, user entries below.
    # Since H.e.2a, the template bakes in .pyve/envs, .pyve/testenv, .envrc,
    # .env, and .vscode/settings.json — the only pattern still inserted
    # dynamically is the user-overridable venv directory name.
    write_gitignore_template
    insert_pattern_in_gitignore_section "$venv_dir" "$section"

    success "Updated .gitignore"
}

#============================================================
# Purge Command
#============================================================

purge() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local keep_testenv=false
    local venv_dir_explicit=false
    local skip_confirm=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-testenv)
                keep_testenv=true
                shift
                ;;
            --yes|-y)
                skip_confirm=true
                shift
                ;;
            -*)
                unknown_flag_error "purge" "$1" --keep-testenv --yes --help
                ;;
            *)
                venv_dir="$1"
                venv_dir_explicit=true
                shift
                ;;
        esac
    done

    header_box "pyve purge"

    # Destructive-confirmation prompt. Skipped when:
    #   --yes / -y passed (e.g., by `init --force`), CI=1, or PYVE_FORCE_YES=1.
    if [[ "$skip_confirm" != true ]] && [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
        warn "This will remove pyve-managed environment artifacts from the current project."
        if ! ask_yn "Proceed"; then
            info "Aborted — no changes made"
            exit 0
        fi
    fi

    # Source shell profiles to detect version manager
    source_shell_profiles
    detect_version_manager 2>/dev/null || true

    # Remove version file
    purge_version_file

    # If a project config exists, prefer its venv directory when the user did not
    # explicitly pass a venv dir to purge.
    if [[ "$venv_dir_explicit" == false ]] && config_file_exists; then
        local configured_venv_dir
        configured_venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
        if [[ -n "$configured_venv_dir" ]]; then
            venv_dir="$configured_venv_dir"
        fi
    fi

    # Remove virtual environment
    purge_venv "$venv_dir"

    # Remove .pyve directory (config and micromamba envs)
    if [[ "$keep_testenv" == true ]]; then
        if [[ -d ".pyve" ]]; then
            if [[ -d ".pyve/$TESTENV_DIR_NAME" ]]; then
                rm -rf ".pyve/config" ".pyve/envs" 2>/dev/null || true
                find ".pyve" -mindepth 1 -maxdepth 1 ! -name "$TESTENV_DIR_NAME" -exec rm -rf {} + 2>/dev/null || true
                success "Removed .pyve directory contents (preserved .pyve/$TESTENV_DIR_NAME)"
            else
                rm -rf ".pyve"
                success "Removed .pyve directory (config and micromamba environments)"
            fi
        fi
    else
        purge_pyve_dir
        purge_testenv_dir
    fi

    # Remove .envrc
    purge_envrc

    # Remove .env (only if empty - v0.6.0 smart purge)
    purge_dotenv

    # Clean .gitignore
    purge_gitignore "$venv_dir"

    footer_box
}

purge_version_file() {
    local version_file

    # Try to remove both possible version files
    for version_file in ".tool-versions" ".python-version"; do
        if [[ -f "$version_file" ]]; then
            rm -f "$version_file"
            success "Removed $version_file"
        fi
    done
}

purge_venv() {
    local venv_dir="$1"

    if [[ -d "$venv_dir" ]]; then
        rm -rf "$venv_dir"
        success "Removed $venv_dir"
    else
        info "No virtual environment found at '$venv_dir'"
    fi
}

purge_pyve_dir() {
    if [[ -d ".pyve" ]]; then
        # Check if micromamba environments exist
        if [[ -d ".pyve/envs" ]]; then
            # Try to remove micromamba environment(s) properly first
            local micromamba_path
            micromamba_path="$(get_micromamba_path 2>/dev/null || true)"

            if [[ -n "$micromamba_path" ]] && [[ -x "$micromamba_path" ]]; then
                # Get environment name from config if it exists
                local env_name
                if config_file_exists; then
                    env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
                fi

                # If we have an env name, try to remove it
                if [[ -n "$env_name" ]]; then
                    info "Removing micromamba environment '$env_name'..."
                    if "$micromamba_path" env remove -n "$env_name" -y 2>/dev/null; then
                        success "Removed micromamba environment '$env_name'"
                    else
                        # If named removal fails, try prefix-based removal
                        info "Named removal failed, trying prefix-based removal..."
                        "$micromamba_path" env remove -p ".pyve/envs/$env_name" -y 2>/dev/null || true
                    fi
                else
                    # No env name in config, try to find and remove any environments in .pyve/envs
                    for env_dir in .pyve/envs/*; do
                        if [[ -d "$env_dir" ]]; then
                            info "Removing micromamba environment at '$env_dir'..."
                            "$micromamba_path" env remove -p "$env_dir" -y 2>/dev/null || true
                        fi
                    done
                fi
            else
                info "Micromamba not found, will force-remove .pyve directory"
            fi
        fi

        # Now remove the .pyve directory
        rm -rf ".pyve"
        success "Removed .pyve directory (config and micromamba environments)"
    fi
}

purge_testenv_dir() {
    if [[ -d ".pyve/$TESTENV_DIR_NAME" ]]; then
        rm -rf ".pyve/$TESTENV_DIR_NAME"
        success "Removed .pyve/$TESTENV_DIR_NAME"
    else
        info "No dev/test runner environment found at '.pyve/$TESTENV_DIR_NAME'"
    fi
}

#============================================================
# Test Environment Commands
#============================================================

testenv_command() {
    local action=""
    local requirements_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            # New subcommand grammar (H.d §4.4 D5) — silent.
            init)
                action="init"
                shift
                ;;
            install)
                action="install"
                shift
                ;;
            purge)
                action="purge"
                shift
                ;;
            # Story J.d (v2.3.0): Category A legacy flag forms
            # (`testenv --init|--install|--purge`) removed. Falls through
            # to the `-*)` arm below, which produces the standard
            # unknown-flag error.
            -r|--requirements)
                if [[ -z "${2:-}" ]]; then
                    log_error "$1 requires a file path"
                    exit 1
                fi
                requirements_file="$2"
                shift 2
                ;;
            run)
                action="run"
                shift
                break  # Remaining args are the command to execute
                ;;
            --help|-h)
                cat << 'EOF'
pyve testenv - Manage a dedicated dev/test runner environment

Usage:
  pyve testenv init
  pyve testenv install [-r requirements-dev.txt]
  pyve testenv purge
  pyve testenv run <command> [args...]

Notes:
  - Uses: .pyve/testenv/venv
  - This environment is preserved across `pyve init --force` and `pyve purge`.
  - `run` executes a command inside the dev/test runner environment.
EOF
                exit 0
                ;;
            -*)
                unknown_flag_error "testenv" "$1" \
                    --requirements -r --help
                ;;
            *)
                log_error "Unknown testenv argument: $1"
                log_error "Usage: pyve testenv <init|install|purge|run> [options]"
                exit 1
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        log_error "No testenv action provided"
        log_error "Use: pyve testenv <init|install|purge|run <command>>"
        exit 1
    fi

    local testenv_root=".pyve/$TESTENV_DIR_NAME"
    local testenv_venv="$testenv_root/venv"

    # `run` exec's into the target command, so the header/footer wrapper
    # would never close. Emit a minimal header before exec and let the
    # called command own the rest of the terminal.
    if [[ "$action" == "run" ]]; then
        if [[ $# -lt 1 ]]; then
            log_error "No command provided"
            log_error "Usage: pyve testenv run <command> [args...]"
            log_error "Example: pyve testenv run ruff check ."
            exit 1
        fi
        if [[ ! -x "$testenv_venv/bin/python" ]]; then
            log_error "Dev/test runner environment not initialized"
            log_error "Run: pyve testenv init"
            exit 1
        fi
        local cmd="$1"
        shift
        local testenv_bin="$testenv_venv/bin"
        local cmd_path="$testenv_bin/$cmd"
        if [[ -x "$cmd_path" ]]; then
            exec "$cmd_path" "$@"
        fi
        export VIRTUAL_ENV="$PWD/$testenv_venv"
        export PATH="$testenv_bin:$PATH"
        exec "$cmd" "$@"
    fi

    header_box "pyve testenv"

    case "$action" in
        init)
            ensure_testenv_exists
            ;;
        install)
            if [[ ! -x "$testenv_venv/bin/python" ]]; then
                log_error "Dev/test runner environment not initialized"
                log_error "Run: pyve testenv init"
                exit 1
            fi
            info "Installing dev/test dependencies into '$testenv_venv'..."
            if [[ -n "$requirements_file" ]]; then
                if [[ ! -f "$requirements_file" ]]; then
                    log_error "Requirements file not found: $requirements_file"
                    exit 1
                fi
                run_cmd "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
            else
                run_cmd "$testenv_venv/bin/python" -m pip install pytest
            fi
            success "Dev/test dependencies installed"
            ;;
        purge)
            purge_testenv_dir
            ;;
    esac

    footer_box
}

test_command() {
    local testenv_venv=".pyve/$TESTENV_DIR_NAME/venv"
    ensure_testenv_exists

    if ! testenv_has_pytest "$testenv_venv"; then
        local auto_install=false
        if [[ -n "${CI:-}" ]] || [[ "$PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT" == "1" ]]; then
            auto_install=true
        fi

        if [[ "$auto_install" == true ]]; then
            install_pytest_into_testenv "$testenv_venv"
        else
            if [[ -t 0 ]]; then
                printf "pytest is not installed in the dev/test runner environment. Install now? [y/N]: "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    install_pytest_into_testenv "$testenv_venv"
                else
                    log_info "Install skipped. You can install with: pyve testenv install -r requirements-dev.txt"
                    exit 1
                fi
            else
                log_error "pytest is not installed in the dev/test runner environment."
                log_error "Run: pyve testenv install -r requirements-dev.txt"
                exit 1
            fi
        fi
    fi

    exec "$testenv_venv/bin/python" -m pytest "$@"
}

purge_envrc() {
    if [[ -f ".envrc" ]]; then
        rm -f ".envrc"
        success "Removed .envrc"
    fi
}

purge_dotenv() {
    if [[ -f "$ENV_FILE_NAME" ]]; then
        if is_file_empty "$ENV_FILE_NAME"; then
            rm -f "$ENV_FILE_NAME"
            success "Removed $ENV_FILE_NAME (was empty)"
        else
            warn "$ENV_FILE_NAME preserved (contains data). Delete manually if desired."
        fi
    fi
}

purge_gitignore() {
    local venv_dir="$1"

    if [[ -f ".gitignore" ]]; then
        remove_pattern_from_gitignore "$venv_dir"
        remove_pattern_from_gitignore "$ENV_FILE_NAME"
        remove_pattern_from_gitignore ".envrc"
        success "Cleaned .gitignore"
    fi
}

#============================================================
# Status Command (Story H.e.4)
#============================================================

# `pyve status` — read-only state dashboard. Never has a non-zero
# exit code based on findings (that's `pyve check`'s job). Three
# sections: Project / Environment / Integrations.
#
# Spec: docs/specs/phase-H-check-status-design.md §4.
status_command() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "status" "$1" --help
                ;;
            *)
                log_error "pyve status takes no positional arguments (got: $1)"
                log_error "See: pyve status --help"
                exit 1
                ;;
        esac
    done

    # Title + divider. BOLD for the title, DIM for the rule — per H.c §4.4.
    printf "\n%sPyve project status%s\n" "${BOLD}" "${RESET}"
    printf "%s───────────────────%s\n\n" "${DIM}" "${RESET}"

    if ! config_file_exists; then
        # Non-project fallback. Don't treat it as an error; status reports
        # reality, and "not a pyve project" is a valid reality.
        _status_row "Not a pyve-managed project" ""
        printf "  %sRun 'pyve init' to initialize.%s\n\n" "${DIM}" "${RESET}"
        return 0
    fi

    _status_section_project
    _status_section_environment
    _status_section_integrations

    return 0
}

# Print one key/value row with a 17-char label column (matches the widest
# label used — "environment.yml:") so every section aligns.
_status_row() {
    local label="$1"
    local value="$2"
    printf "  %-17s %s\n" "${label}" "${value}"
}

_status_header() {
    printf "%s%s%s\n" "${BOLD}" "$1" "${RESET}"
}

_status_section_project() {
    _status_header "Project"
    _status_row "Path:" "$(pwd -P)"

    local backend
    backend="$(read_config_value "backend" 2>/dev/null || true)"
    if [[ -n "$backend" ]]; then
        _status_row "Backend:" "$backend"
    else
        _status_row "Backend:" "${DIM}not configured${RESET}"
    fi

    local recorded_version
    recorded_version="$(read_config_value "pyve_version" 2>/dev/null || true)"
    if [[ -z "$recorded_version" ]]; then
        _status_row "Pyve config:" "${DIM}version not recorded${RESET}"
    else
        case "$(compare_versions "$recorded_version" "$VERSION")" in
            equal)
                _status_row "Pyve config:" "v${recorded_version} (current)"
                ;;
            less)
                _status_row "Pyve config:" "v${recorded_version} (current: v${VERSION})"
                ;;
            greater)
                _status_row "Pyve config:" "v${recorded_version} (newer than pyve v${VERSION})"
                ;;
        esac
    fi

    _status_row "Python:" "$(_status_configured_python)"
    printf "\n"
}

# Detect the configured Python version source. Returns a human-readable
# string like "3.14.4 (.tool-versions via asdf)" or "(not pinned)".
_status_configured_python() {
    local version="" source=""
    if [[ -f ".tool-versions" ]]; then
        version="$(grep "^python " .tool-versions 2>/dev/null | awk '{print $2}')"
        source=".tool-versions via asdf"
    elif [[ -f ".python-version" ]]; then
        version="$(cat .python-version 2>/dev/null)"
        source=".python-version via pyenv"
    else
        version="$(read_config_value "python.version" 2>/dev/null || true)"
        source=".pyve/config"
    fi
    if [[ -z "$version" ]]; then
        printf "%snot pinned%s" "${DIM}" "${RESET}"
    else
        printf "%s (%s)" "${version}" "${source}"
    fi
}

_status_section_environment() {
    _status_header "Environment"

    local backend
    backend="$(read_config_value "backend" 2>/dev/null || true)"

    if [[ "$backend" == "micromamba" ]]; then
        _status_env_micromamba
    elif [[ "$backend" == "venv" ]]; then
        _status_env_venv
    else
        _status_row "Path:" "${DIM}backend not configured${RESET}"
    fi

    printf "\n"
}

_status_env_venv() {
    local venv_dir
    venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
    venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"

    if [[ ! -d "$venv_dir" ]]; then
        _status_row "Path:" "${venv_dir} (${DIM}missing${RESET})"
        return 0
    fi
    _status_row "Path:" "$venv_dir"

    if [[ -x "$venv_dir/bin/python" ]]; then
        local py_version
        py_version="$("$venv_dir/bin/python" --version 2>&1 | awk '{print $2}')"
        _status_row "Python:" "${py_version:-unknown}"
    else
        _status_row "Python:" "${DIM}not found${RESET}"
    fi

    _status_row "Packages:" "$(_status_venv_package_count "$venv_dir")"

    # distutils shim: check for the sitecustomize.py marker under
    # $venv_dir/lib/python*/site-packages/ (Python 3.12+ install).
    # Guard: `find` on a nonexistent .venv/lib exits non-zero, which
    # would kill the script under `set -euo pipefail` — trailing
    # `|| true` absorbs it.
    if [[ -d "$venv_dir/lib" ]]; then
        local sitecustomize
        sitecustomize="$(find "$venv_dir/lib" -maxdepth 3 -name "sitecustomize.py" 2>/dev/null | head -1 || true)"
        if [[ -n "$sitecustomize" ]] && grep -qF "$PYVE_DISTUTILS_SHIM_MARKER" "$sitecustomize" 2>/dev/null; then
            _status_row "distutils shim:" "installed"
        else
            _status_row "distutils shim:" "${DIM}not installed${RESET}"
        fi
    fi
}

_status_venv_package_count() {
    local venv_dir="$1"
    local site_packages count
    # Same `find`-pipefail guard as above.
    if [[ ! -d "$venv_dir/lib" ]]; then
        printf "%sunknown%s" "${DIM}" "${RESET}"
        return 0
    fi
    site_packages="$(find "$venv_dir/lib" -type d -name "site-packages" 2>/dev/null | head -1 || true)"
    if [[ -z "$site_packages" ]]; then
        printf "%sunknown%s" "${DIM}" "${RESET}"
        return 0
    fi
    count="$(find "$site_packages" -maxdepth 1 -name "*.dist-info" 2>/dev/null | wc -l | tr -d ' ' || true)"
    printf "%s installed" "${count:-0}"
}

_status_env_micromamba() {
    local env_name env_path
    env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
    if [[ -z "$env_name" ]]; then
        _status_row "Name:" "${DIM}not configured${RESET}"
        return 0
    fi
    env_path=".pyve/envs/$env_name"

    _status_row "Name:" "$env_name"

    if [[ ! -d "$env_path" ]]; then
        _status_row "Path:" "${env_path} (${DIM}missing${RESET})"
        return 0
    fi
    _status_row "Path:" "$env_path"

    if [[ -x "$env_path/bin/python" ]]; then
        local py_version
        py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
        _status_row "Python:" "${py_version:-unknown}"
    fi

    if [[ -d "$env_path/conda-meta" ]]; then
        local count
        count="$(find "$env_path/conda-meta" -name "*.json" 2>/dev/null | wc -l | tr -d ' ' || true)"
        _status_row "Packages:" "${count:-0} installed"
    fi

    if [[ -f "environment.yml" ]]; then
        _status_row "environment.yml:" "present"
    else
        _status_row "environment.yml:" "${DIM}missing${RESET}"
    fi

    if [[ -f "conda-lock.yml" ]]; then
        if is_lock_file_stale 2>/dev/null; then
            _status_row "conda-lock.yml:" "${DIM}stale${RESET}"
        else
            _status_row "conda-lock.yml:" "up to date"
        fi
    else
        _status_row "conda-lock.yml:" "${DIM}missing${RESET}"
    fi
}

_status_section_integrations() {
    _status_header "Integrations"

    if [[ -f ".envrc" ]]; then
        _status_row "direnv:" ".envrc present"
    else
        _status_row "direnv:" "${DIM}.envrc missing${RESET}"
    fi

    if [[ -f ".env" ]]; then
        if is_file_empty ".env"; then
            _status_row ".env:" "present (empty)"
        else
            _status_row ".env:" "present"
        fi
    else
        _status_row ".env:" "${DIM}missing${RESET}"
    fi

    # project-guide: look for the binary in the project environment.
    local backend env_path pg_info
    backend="$(read_config_value "backend" 2>/dev/null || true)"
    env_path=""
    if [[ "$backend" == "venv" ]]; then
        local venv_dir
        venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
        env_path="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
    elif [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
        [[ -n "$env_name" ]] && env_path=".pyve/envs/$env_name"
    fi
    if [[ -n "$env_path" ]] && [[ -x "$env_path/bin/project-guide" ]]; then
        pg_info="$("$env_path/bin/project-guide" --version 2>/dev/null | head -1 | awk '{print $NF}')"
        if [[ -n "$pg_info" ]]; then
            _status_row "project-guide:" "installed (v${pg_info})"
        else
            _status_row "project-guide:" "installed"
        fi
    else
        _status_row "project-guide:" "${DIM}not installed${RESET}"
    fi

    local testenv_venv=".pyve/$TESTENV_DIR_NAME/venv"
    if [[ -d "$testenv_venv" ]]; then
        if [[ -x "$testenv_venv/bin/python" ]] && \
           "$testenv_venv/bin/python" -c 'import pytest' >/dev/null 2>&1; then
            _status_row "testenv:" "present, pytest installed"
        elif [[ -x "$testenv_venv/bin/python" ]]; then
            _status_row "testenv:" "present, pytest ${DIM}not installed${RESET}"
        else
            _status_row "testenv:" "present (${DIM}broken${RESET})"
        fi
    else
        _status_row "testenv:" "${DIM}not present${RESET}"
    fi

    printf "\n"
}

#============================================================
# Check Command (Story H.e.3)
#============================================================

# `pyve check` — read-only diagnostics. Replaces the semantic of
# `pyve validate` (structured 0/1/2 exit codes for CI) and most
# of `pyve doctor` (per-problem findings with one actionable
# next-step). State reporting is H.e.4 (`pyve status`), not here.
#
# Spec: docs/specs/phase-H-check-status-design.md §3.
#
# Severity ladder: info (no effect) → pass (✓) → warn (⚠, exit 2)
# → error (✗, exit 1). Escalation is one-way: an error later in
# the run cannot be downgraded; a warning cannot downgrade an
# error.
check_command() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "check" "$1" --help
                ;;
            *)
                log_error "pyve check takes no positional arguments (got: $1)"
                log_error "See: pyve check --help"
                exit 1
                ;;
        esac
    done

    local errors=0
    local warnings=0
    local passed=0
    local exit_code=0

    _check_pass() {
        printf "✓ %s\n" "$1"
        passed=$((passed + 1))
    }
    _check_warn() {
        printf "⚠ %s\n" "$1"
        [[ -n "${2:-}" ]] && printf "  %s\n" "$2"
        warnings=$((warnings + 1))
        if (( exit_code != 1 )); then
            exit_code=2
        fi
    }
    _check_fail() {
        printf "✗ %s\n" "$1"
        [[ -n "${2:-}" ]] && printf "  %s\n" "$2"
        errors=$((errors + 1))
        exit_code=1
    }

    printf "Pyve Environment Check\n"
    printf "======================\n\n"

    # --- Check 1: .pyve/config present ------------------------------------
    if ! config_file_exists; then
        _check_fail "Configuration: .pyve/config missing" "→ Run: pyve init"
        _check_summary_and_exit
    fi
    _check_pass "Configuration: .pyve/config"

    # --- Check 3: backend configured --------------------------------------
    # (Check 2 slots below — runs after we know the backend so we can
    # point the user at either `pyve update` or `pyve init --force` as
    # appropriate.)
    local backend
    backend="$(read_config_value "backend")"
    if [[ -z "$backend" ]]; then
        _check_fail "Backend: not configured in .pyve/config" \
            "→ Run: pyve init --backend venv|micromamba"
        _check_summary_and_exit
    fi
    _check_pass "Backend: $backend"

    # --- Check 2: pyve_version drift --------------------------------------
    local recorded_version
    recorded_version="$(read_config_value "pyve_version")"
    if [[ -z "$recorded_version" ]]; then
        _check_warn "Pyve version: not recorded (legacy project)" \
            "→ Run: pyve update"
    else
        case "$(compare_versions "$recorded_version" "$VERSION")" in
            equal)
                _check_pass "Pyve version: $recorded_version (current)"
                ;;
            less)
                _check_warn "Pyve version: $recorded_version (current: $VERSION)" \
                    "→ Run: pyve update"
                ;;
            greater)
                _check_warn "Pyve version: $recorded_version (newer than running pyve v$VERSION)" \
                    "→ Upgrade pyve or re-initialize the project"
                ;;
        esac
    fi

    # --- Backend-specific checks ------------------------------------------
    local env_path=""
    if [[ "$backend" == "venv" ]]; then
        local venv_dir
        venv_dir="$(read_config_value "venv.directory")"
        venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
        env_path="$venv_dir"
        _check_venv_backend "$env_path"
    elif [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name")"
        if [[ -n "$env_name" ]]; then
            env_path=".pyve/envs/$env_name"
        fi
        _check_micromamba_backend "$env_path" "$env_name"
    else
        _check_fail "Backend: unknown value '$backend'" \
            "→ Run: pyve init --backend venv|micromamba"
    fi

    # --- Common integration checks ----------------------------------------
    # Check 9: .envrc
    if [[ -f ".envrc" ]]; then
        _check_pass "direnv: .envrc present"
    else
        _check_warn ".envrc: missing" "→ Run: pyve init --force"
    fi

    # Check 10: .env
    if [[ -f ".env" ]]; then
        _check_pass ".env: present"
    else
        _check_warn ".env: missing" "→ Run: touch .env"
    fi

    # Check 16: testenv (conditional — only warn if exists but broken)
    local testenv_venv=".pyve/$TESTENV_DIR_NAME/venv"
    if [[ -d "$testenv_venv" ]]; then
        if [[ -x "$testenv_venv/bin/python" ]] && \
           "$testenv_venv/bin/python" -c 'import pytest' >/dev/null 2>&1; then
            _check_pass "testenv: pytest installed"
        else
            _check_warn "testenv: present but pytest not installed" \
                "→ Run: pyve test"
        fi
    fi

    _check_summary_and_exit
}

# Per-backend helpers. These escalate via the outer _check_* closures and
# consult the outer-scoped env_path.

_check_venv_backend() {
    local venv_dir="$1"

    # Check 5: venv directory + python executable.
    if [[ ! -d "$venv_dir" ]]; then
        _check_fail "Environment: $venv_dir (missing)" "→ Run: pyve init --force"
        return 0
    fi
    if [[ ! -x "$venv_dir/bin/python" ]]; then
        _check_fail "Environment: $venv_dir/bin/python (missing or not executable)" \
            "→ Run: pyve init --force"
        return 0
    fi
    _check_pass "Environment: $venv_dir"

    # Python version (informational for now; full version-match gate
    # against .tool-versions / .python-version is deferred to a
    # follow-up H.e.3 polish).
    local py_version
    py_version="$("$venv_dir/bin/python" --version 2>&1 | awk '{print $2}')"
    if [[ -n "$py_version" ]]; then
        _check_pass "Python: $py_version"
    fi

    # Check 7: venv path mismatch (relocated project).
    local path_output
    path_output="$(doctor_check_venv_path "$venv_dir")"
    if [[ -n "$path_output" ]]; then
        _check_fail "Environment: venv path mismatch (project may have been relocated)" \
            "→ Run: pyve init --force"
    fi

    # Check 13: duplicate dist-info.
    local dup_output
    dup_output="$(doctor_check_duplicate_dist_info "$venv_dir")"
    if [[ "$dup_output" == *"Duplicate dist-info detected"* ]]; then
        _check_fail "Environment: duplicate dist-info directories detected" \
            "→ Run: pyve init --force"
    fi

    # Check 14: cloud sync collision artifacts.
    local collision_output
    collision_output="$(doctor_check_collision_artifacts "$venv_dir")"
    if [[ "$collision_output" == *"Cloud sync collision artifacts detected"* ]]; then
        _check_fail "Environment: cloud sync collision artifacts detected" \
            "→ Move the project outside a cloud-synced directory, then: pyve init --force"
    fi
}

_check_micromamba_backend() {
    local env_path="$1"
    local env_name="$2"

    # Check 4: micromamba binary available.
    if ! check_micromamba_available; then
        _check_fail "Backend: micromamba binary not found" \
            "→ Run: pyve init   (triggers bootstrap)"
        return 0
    fi
    _check_pass "Micromamba: available"

    # Check: environment.yml present.
    if [[ ! -f "environment.yml" ]]; then
        _check_fail "environment.yml: missing" \
            "→ Run: pyve init --backend micromamba"
        return 0
    fi
    _check_pass "environment.yml: present"

    # Check 11 / 12: conda-lock.yml present and fresh.
    if [[ ! -f "conda-lock.yml" ]]; then
        _check_warn "conda-lock.yml: missing" "→ Run: pyve lock"
    elif is_lock_file_stale; then
        _check_warn "conda-lock.yml: stale (older than environment.yml)" \
            "→ Run: pyve lock"
    else
        _check_pass "conda-lock.yml: up to date"
    fi

    # Check 5: environment directory exists.
    if [[ -z "$env_path" ]] || [[ ! -d "$env_path" ]]; then
        _check_fail "Environment: $env_path (missing)" "→ Run: pyve init --force"
        return 0
    fi
    if [[ ! -x "$env_path/bin/python" ]]; then
        _check_fail "Environment: $env_path/bin/python (missing or not executable)" \
            "→ Run: pyve init --force"
        return 0
    fi
    _check_pass "Environment: $env_path"

    # Python version (informational).
    local py_version
    py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
    if [[ -n "$py_version" ]]; then
        _check_pass "Python: $py_version"
    fi

    # Check 13 / 14 / 15 reuse the existing helpers.
    local dup_output
    dup_output="$(doctor_check_duplicate_dist_info "$env_path")"
    if [[ "$dup_output" == *"Duplicate dist-info detected"* ]]; then
        _check_fail "Environment: duplicate dist-info directories detected" \
            "→ Run: pyve init --force"
    fi

    local collision_output
    collision_output="$(doctor_check_collision_artifacts "$env_path")"
    if [[ "$collision_output" == *"Cloud sync collision artifacts detected"* ]]; then
        _check_fail "Environment: cloud sync collision artifacts detected" \
            "→ Move the project outside a cloud-synced directory, then: pyve init --force"
    fi

    local native_output
    native_output="$(doctor_check_native_lib_conflicts "$env_path")"
    if [[ "$native_output" == *"Potential native library conflict"* ]]; then
        _check_warn "Environment: potential pip/conda native library conflict" \
            "→ Add the missing OpenMP package to environment.yml, then: pyve lock"
    fi
}

_check_summary_and_exit() {
    printf "\n"
    printf "%d passed, %d warnings, %d errors\n" "$passed" "$warnings" "$errors"
    exit "$exit_code"
}

#============================================================
# Update Command (Story H.e.2)
#============================================================

# Non-destructive upgrade path per docs/specs/phase-H-cli-refactor-design.md
# §4.3. Refreshes managed files (config, .gitignore, .vscode/settings.json,
# project-guide scaffolding) without rebuilding the venv or touching user
# state (.env, .envrc, user sections of .gitignore).
#
# Never prompts. Never changes the recorded backend. Never creates files
# that don't already exist (.vscode/settings.json). Use `pyve init --force`
# to rebuild the environment.
update_command() {
    local pg_mode=""  # "" | "no"  (only --no-project-guide is supported per H.d §4.3)

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-project-guide)
                pg_mode="no"
                shift
                ;;
            -*)
                unknown_flag_error "update" "$1" --no-project-guide --help
                ;;
            *)
                log_error "pyve update takes no positional arguments (got: $1)"
                log_error "See: pyve update --help"
                exit 1
                ;;
        esac
    done

    # Sanity check: .pyve/config must exist. Without it we don't know the
    # backend or how to refresh anything.
    if ! config_file_exists; then
        log_error "pyve update requires an initialized project."
        log_error "No .pyve/config found. Run 'pyve init' first."
        exit 1
    fi

    local backend
    backend="$(read_config_value "backend")"
    if [[ -z "$backend" ]]; then
        log_error "Corrupt .pyve/config: missing 'backend' key."
        log_error "Run: pyve init --force"
        exit 1
    fi

    local previous_version
    previous_version="$(read_config_value "pyve_version")"

    log_info "Updating project configuration to Pyve v$VERSION..."

    # Step 1: bump pyve_version in .pyve/config (idempotent; writes even
    # when already at current version — simplifies the happy path).
    if ! update_config_version; then
        log_error "Failed to update .pyve/config."
        exit 1
    fi
    if [[ -z "$previous_version" ]]; then
        log_success "pyve_version: (not recorded) → $VERSION"
    elif [[ "$previous_version" == "$VERSION" ]]; then
        log_success "pyve_version: $VERSION (already current)"
    else
        log_success "pyve_version: $previous_version → $VERSION"
    fi

    # Step 2: refresh Pyve-managed sections of .gitignore.
    write_gitignore_template
    log_success "Refreshed .gitignore (Pyve-managed sections)"

    # Step 3: refresh .vscode/settings.json IF it already exists. Never
    # create — that's user opt-in at init time.
    if [[ -f ".vscode/settings.json" ]] && [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name")"
        if [[ -n "$env_name" ]]; then
            PYVE_REINIT_MODE=force write_vscode_settings "$env_name"
        fi
    fi

    # Step 4: ensure .pyve/ exists (should already, by precondition).
    mkdir -p .pyve

    # Step 5: refresh project-guide scaffolding if present and allowed.
    if [[ "$pg_mode" == "no" ]]; then
        log_info "Skipping project-guide refresh (--no-project-guide)"
    elif [[ -f ".project-guide.yml" ]]; then
        local env_path=""
        if [[ "$backend" == "venv" ]]; then
            local venv_dir
            venv_dir="$(read_config_value "venv.directory")"
            venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
            env_path="$venv_dir"
        elif [[ "$backend" == "micromamba" ]]; then
            local env_name
            env_name="$(read_config_value "micromamba.env_name")"
            if [[ -n "$env_name" ]]; then
                env_path=".pyve/envs/$env_name"
            fi
        fi
        if [[ -n "$env_path" ]] && [[ -d "$env_path" ]]; then
            run_project_guide_update_in_env "$backend" "$env_path"
        else
            log_warning "Environment not found; skipping project-guide update."
            log_warning "  (Run 'pyve init --force' to rebuild the environment.)"
        fi
    fi

    echo ""
    log_info "Project updated to Pyve v$VERSION."
    return 0
}

#============================================================
# Main Entry Point
#============================================================

#------------------------------------------------------------
# Legacy-flag catch (Decision D3 — kept forever).
#
# v1.11.0 broke the flag-style top-level CLI in favor of
# subcommands. Old invocations like `pyve --init` get a
# precise migration error instead of an opaque "unknown
# command". Three lines of code, great error message, zero
# cost. Users coming from old README snippets, blog posts,
# or LLM training data will hit this for years.
#------------------------------------------------------------
legacy_flag_error() {
    local old_flag="$1"
    local new_form="$2"
    log_error "'pyve $old_flag' is no longer supported. Use 'pyve $new_form' instead."
    log_error "See: pyve --help"
    exit 1
}

#------------------------------------------------------------
# Unknown-flag error with closest-match suggestion (H.e.9d).
#
#   unknown_flag_error <subcommand> <bad_flag> <valid_flag1> [<valid_flag2> ...]
#
# Picks the single closest valid flag by Levenshtein distance
# (via `_edit_distance` in lib/ui.sh). Emits "Did you mean X?"
# only when distance <= 3; for more distant typos it omits the
# hint to avoid suggesting an unrelated flag.
#
# Every line is an ERROR: line so scripts grepping stderr see
# a coherent block. Always exits 1.
#------------------------------------------------------------
unknown_flag_error() {
    local subcommand="$1"; shift
    local bad_flag="$1"; shift

    local best_match=""
    local best_dist=999
    local flag dist
    for flag in "$@"; do
        dist="$(_edit_distance "$bad_flag" "$flag")"
        if (( dist < best_dist )); then
            best_dist=$dist
            best_match=$flag
        fi
    done

    log_error "'pyve $subcommand' does not accept '$bad_flag'."
    if (( best_dist <= 3 )) && [[ -n "$best_match" ]]; then
        log_error "  Did you mean: '$best_match'?"
    fi
    log_error "  Valid flags for 'pyve $subcommand': $*"
    log_error "  See: pyve $subcommand --help"
    exit 1
}

#------------------------------------------------------------
# Per-subcommand help blocks (Story G.b.2 / FR-G4).
#
# Each renamed subcommand gets a focused man-page-style help
# block. The dispatcher intercepts `--help` / `-h` for the
# new subcommands and calls these BEFORE the real handler
# runs, so help is always fast and side-effect-free.
#
# Each block opens with a strict marker line of the form
# `pyve <sub> - <one-line summary>` so tests can assert on
# exactly the right help block (not a fall-through to
# top-level help).
#------------------------------------------------------------

show_init_help() {
    cat << 'EOF'
pyve init - Initialize a Python virtual environment in the current directory

Usage:
  pyve init [<dir>] [options]

Arguments:
  <dir>                              Custom venv directory name (default: .venv)

Options:
  --python-version <ver>             Set Python version (e.g., 3.13.7)
  --backend <type>                   Backend to use: venv, micromamba, auto
  --auto-bootstrap                   Install micromamba without prompting (if needed)
  --bootstrap-to <location>          Where to install micromamba: project, user
  --strict                           Error on stale or missing lock files
  --no-lock                          Bypass missing conda-lock.yml error (not recommended)
  --env-name <name>                  Environment name (micromamba backend)
  --no-direnv                        Skip .envrc creation (for CI/CD)
  --auto-install-deps                Auto-install from pyproject.toml / requirements.txt
  --no-install-deps                  Skip dependency installation prompt (for CI/CD)
  --local-env                        Copy ~/.local/.env template
  --update                           Safely update an existing installation
  --force                            Purge and re-initialize (destructive)
  --allow-synced-dir                 Bypass cloud-sync directory check

  project-guide integration (three-step post-init hook):
    1. pip install --upgrade project-guide   (latest version)
    2. project-guide init --no-input          (creates .project-guide.yml + docs/project-guide/)
    3. shell completion in ~/.zshrc / ~/.bashrc (sentinel-bracketed block)

    --project-guide                  Run all three steps (overrides auto-skip below)
    --no-project-guide               Skip all three steps (no prompt)
    --project-guide-completion       Add shell completion (no prompt) — step 3 only
    --no-project-guide-completion    Skip shell completion (no prompt) — step 3 only

  Auto-skip safety:
    If 'project-guide' is already declared as a dependency in your
    pyproject.toml, requirements.txt, or environment.yml, pyve will NOT
    auto-install or run 'project-guide init' (avoids version conflicts
    with your pin). Pass --project-guide to override.

  Environment variables for the project-guide hooks:
    PYVE_PROJECT_GUIDE=1              Same as --project-guide
    PYVE_NO_PROJECT_GUIDE=1           Same as --no-project-guide
    PYVE_PROJECT_GUIDE_COMPLETION=1   Same as --project-guide-completion
    PYVE_NO_PROJECT_GUIDE_COMPLETION=1 Same as --no-project-guide-completion

  CI defaults (non-interactive, i.e. CI=1 or PYVE_FORCE_YES=1):
    project-guide install             → INSTALL (matches interactive default)
    project-guide shell completion    → SKIP (editing rc files in CI is surprising)

  Note: pyve init --update does NOT run the project-guide hook (minimal-touch).

Examples:
  pyve init                                # Auto-detect backend, default venv
  pyve init myenv                          # Custom venv directory name
  pyve init --backend venv                 # Force venv backend
  pyve init --backend micromamba           # Force micromamba backend
  pyve init --python-version 3.13.7        # Pin Python version
  pyve init --no-direnv                    # Skip direnv (CI/CD)
  pyve init --force                        # Purge and rebuild
  pyve init --project-guide                # Install project-guide without prompting
  pyve init --no-project-guide             # Skip project-guide entirely

See `pyve --help` for the full command list.
EOF
}

show_purge_help() {
    cat << 'EOF'
pyve purge - Remove all Python environment artifacts

Usage:
  pyve purge [<dir>] [options]

Arguments:
  <dir>                       Custom venv directory name (default: .venv)

Options:
  --keep-testenv              Preserve .pyve/testenv (the dev/test runner env)
  --yes, -y                   Skip the destructive-confirmation prompt.
                              Equivalent to setting CI=1 or PYVE_FORCE_YES=1.

Examples:
  pyve purge                               # Remove .pyve and the venv (prompts)
  pyve purge --yes                         # Remove without the prompt
  pyve purge --keep-testenv                # Preserve the testenv across purge
  pyve purge custom_venv                   # Remove a custom-named venv

See `pyve --help` for the full command list.
EOF
}

show_status_help() {
    cat << 'EOF'
pyve status - Show a snapshot of the current project environment

Usage:
  pyve status

Description:
  Prints an at-a-glance summary of how this project is set up:
  backend, Python version, environment location, package count, and
  integration state (direnv, .env, project-guide, testenv).

  pyve status is read-only and never produces a non-zero exit code
  based on findings — if something looks wrong, use 'pyve check'.

Output respects NO_COLOR=1 (https://no-color.org) — set it to strip
ANSI escapes without changing the layout.

See also:
  pyve check             Diagnose problems and suggest fixes
  pyve --help            Full command list
EOF
}

show_check_help() {
    cat << 'EOF'
pyve check - Diagnose environment problems and suggest fixes

Usage:
  pyve check

Description:
  Runs a set of read-only diagnostics against the current project and
  reports findings. Every failure includes exactly one command that
  will move the project toward a working state — no chains, no
  references to other commands.

  For a read-only snapshot of current state (no diagnostics), use
  'pyve status' instead (coming in a later release).

Exit codes:
  0    All checks passed.
  1    One or more errors — environment is broken for 'pyve run' / 'pyve test'.
  2    Warnings only — environment works but is drifting.

Notes:
  - pyve check is safe to run in CI (no side effects, stable exit codes).
  - pyve check does not auto-remediate. For the auto-fix story, see
    the future 'pyve check --fix' (tracked in stories.md Phase I).

See also:
  pyve doctor            Legacy diagnostics (superseded by 'pyve check')
  pyve validate          Legacy CI gate (superseded by 'pyve check')
  pyve --help            Full command list
EOF
}

show_update_help() {
    cat << 'EOF'
pyve update - Non-destructive upgrade: refresh managed files and config

Usage:
  pyve update [--no-project-guide]

Description:
  Updates a pyve-managed project to the current pyve version WITHOUT
  rebuilding the virtual environment. Safe to run on any pyve-managed
  project; idempotent.

  Refreshes:
    - pyve_version in .pyve/config
    - Pyve-managed sections of .gitignore
    - .vscode/settings.json (only if it already exists)
    - project-guide scaffolding (via 'project-guide update --no-input')

  Does NOT:
    - rebuild the virtual environment (use 'pyve init --force' for that)
    - create .env or .envrc (those are user state)
    - re-prompt for backend (the recorded backend is preserved)

Options:
  --no-project-guide          Skip the project-guide refresh step

Exit codes:
  0    Success (including no-op when already at current version).
  1    Failure (missing .pyve/config, corrupt config, unwritable files).

See also:
  pyve init --force          Destroy + rebuild the environment
  pyve --help                Full command list
EOF
}

show_python_help() {
    cat << 'EOF'
pyve python - Manage the project's Python version pin

Usage:
  pyve python set <version>
  pyve python show

Subcommands:
  set <version>     Pin the project's Python version (format: #.#.#)
                    Writes to .tool-versions (asdf) or .python-version (pyenv)
  show              Print the currently pinned Python version

Examples:
  pyve python set 3.13.7
  pyve python show

See `pyve --help` for the full command list.
EOF
}

show_self_install_help() {
    cat << 'EOF'
pyve self install - Install pyve to ~/.local/bin

Usage:
  pyve self install

Description:
  Copies the pyve script and lib/ modules to ~/.local/bin and adds
  ~/.local/bin to PATH (via ~/.zshrc or ~/.bashrc) if not already
  present. Idempotent — safe to run multiple times.

See also:
  pyve self uninstall    Remove pyve from ~/.local/bin
  pyve --help            Full command list
EOF
}

show_self_uninstall_help() {
    cat << 'EOF'
pyve self uninstall - Remove pyve from ~/.local/bin

Usage:
  pyve self uninstall

Description:
  Removes the pyve script and lib/ modules from ~/.local/bin, plus:
    - the PATH entry added by the installer (from ~/.zprofile / ~/.bash_profile)
    - the pyve prompt hook (from ~/.zshrc / ~/.bashrc)
    - the project-guide shell completion block (from ~/.zshrc / ~/.bashrc),
      if one was added by `pyve init --project-guide-completion`

  Non-empty ~/.local/.env is preserved (warn, don't delete).

See also:
  pyve self install      Install pyve to ~/.local/bin
  pyve --help            Full command list
EOF
}

#------------------------------------------------------------
# self namespace help — printed when `pyve self` is invoked
# with no subcommand. Mirrors `git remote`, `kubectl config`.
#------------------------------------------------------------
show_self_help() {
    cat << 'EOF'
pyve self - Manage pyve's own installation

Usage: pyve self <subcommand>

Subcommands:
  pyve self install      Install pyve to ~/.local/bin (and add to PATH if needed)
  pyve self uninstall    Remove pyve from ~/.local/bin

See `pyve --help` for the full command list.
EOF
}

main() {
    # No arguments - show help
    if [[ $# -eq 0 ]]; then
        log_error "No command provided."
        show_help
        exit 1
    fi

    # Parse command
    case "$1" in
        # Universal flags (CLI convention — these stay as flags)
        --help|-h)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        --config|-c)
            show_config
            ;;

        # Legacy-flag catch (Decision D3 — kept forever)
        --init)
            legacy_flag_error "--init" "init"
            ;;
        --purge)
            legacy_flag_error "--purge" "purge"
            ;;
        --validate)
            legacy_flag_error "--validate" "check"
            ;;
        --python-version)
            legacy_flag_error "--python-version" "python set <ver>"
            ;;
        --install)
            legacy_flag_error "--install" "self install"
            ;;
        --uninstall)
            legacy_flag_error "--uninstall" "self uninstall"
            ;;
        # Added in v2.0 (H.e.9) — top-level flag forms catch
        # users who instinctively reach for a flag when the
        # corresponding subcommand is the actual shape.
        --update)
            legacy_flag_error "--update" "update"
            ;;
        --doctor)
            legacy_flag_error "--doctor" "check"
            ;;
        --status)
            legacy_flag_error "--status" "status"
            ;;
        # Short aliases removed in v1.11.0 (Decision D1)
        -i)
            legacy_flag_error "-i" "init"
            ;;
        -p)
            legacy_flag_error "-p" "purge"
            ;;

        # New subcommand surface (v1.11.0+)
        init)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_init_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:init %s\n' "$*"
                exit 0
            fi
            init "$@"
            ;;
        purge)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_purge_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:purge %s\n' "$*"
                exit 0
            fi
            purge "$@"
            ;;
        validate)
            # Removed in v2.0 per H.e.8a. Superseded by `pyve check`.
            legacy_flag_error "validate" "check"
            ;;
        update)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_update_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:update %s\n' "$*"
                exit 0
            fi
            update_command "$@"
            ;;
        python)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_python_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:python %s\n' "$*"
                exit 0
            fi
            python_command "$@"
            ;;
        self)
            shift
            self "$@"
            ;;

        # Unchanged subcommands (already subcommand-form pre-v1.11.0)
        run)
            shift
            run_command "$@"
            ;;
        testenv)
            shift
            testenv_command "$@"
            ;;
        test)
            shift
            test_command "$@"
            ;;
        lock)
            shift
            lock "$@"
            ;;
        doctor)
            # Removed in v2.0 per H.e.8a. Superseded by `pyve check`.
            legacy_flag_error "doctor" "check"
            ;;
        check)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_check_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:check %s\n' "$*"
                exit 0
            fi
            check_command "$@"
            ;;
        status)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_status_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:status %s\n' "$*"
                exit 0
            fi
            status_command "$@"
            ;;

        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
