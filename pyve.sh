#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
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

VERSION="1.16.1"
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
    python-version <ver>      Set Python version without creating an environment
                              Format: #.#.# (e.g., 3.13.7)
    lock [--check]            Generate or verify conda-lock.yml (micromamba only)
                              --check: mtime-only verification (no conda-lock needed)

  Execution:
    run <command> [args...]   Run a command inside the project environment
                              For CI/CD, Docker, and --no-direnv setups
    test [pytest args...]     Run pytest via the dev/test runner environment
    testenv <subcommand>      Manage the dev/test runner environment
                              Subcommands: --init | --install [-r <req>] | --purge | run <cmd>
                              See `pyve testenv --help` for details

  Diagnostics:
    doctor                    Check environment health and show diagnostics
                              Reports backend, Python version, packages, and status
    validate                  Validate Pyve installation and configuration
                              Exit codes: 0 (pass), 1 (errors), 2 (warnings)

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
    pyve testenv --init                  # Create dev/test runner environment
    pyve testenv --install -r requirements-dev.txt  # Install dev/test deps
    pyve testenv run ruff check .        # Run dev tools from testenv
    pyve test -q                         # Run pytest via dev/test runner
    pyve lock                            # Generate/update conda-lock.yml
    pyve lock --check                    # Verify conda-lock.yml is current (CI gate)
    pyve doctor                          # Check environment health
    pyve validate                        # Validate installation and config
    pyve purge                           # Remove environment
    pyve python-version 3.13.7           # Set Python version only
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
            log_warning "Testenv Python ($testenv_ver) differs from project Python ($current_ver) — rebuilding testenv..."
            rm -rf "$testenv_venv"
        fi
    fi

    if [[ ! -d "$testenv_venv" ]]; then
        log_info "Creating dev/test runner environment in '$testenv_venv'..."
        python -m venv "$testenv_venv"
        log_success "Created dev/test runner environment"
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

    log_info "Installing pytest into dev/test runner environment..."
    if [[ -n "$requirements_file" ]]; then
        "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
    else
        "$testenv_venv/bin/python" -m pip install pytest
    fi
    log_success "pytest installed"
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
                PYVE_REINIT_MODE="update"
                shift
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
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done
    
    # Refuse to initialize inside a cloud-synced directory (use --allow-synced-dir to override)
    check_cloud_sync_path

    # Check for existing installation (re-initialization detection)
    if config_file_exists; then
        local existing_backend
        existing_backend="$(read_config_value "backend")"
        local existing_version
        existing_version="$(read_config_value "pyve_version")"
        
        # Handle re-initialization based on mode
        if [[ "${PYVE_REINIT_MODE:-}" == "update" ]]; then
            # Safe update mode
            log_info "Updating existing Pyve installation..."
            
            # Check for conflicts
            if [[ -n "$backend_flag" ]] && [[ "$backend_flag" != "$existing_backend" ]]; then
                log_error "Cannot update in-place: Backend change detected"
                log_error "  Current: $existing_backend"
                log_error "  Requested: $backend_flag"
                echo ""
                log_error "Backend changes require a clean re-initialization."
                log_error "Run: pyve init --force"
                exit 1
            fi
            
            # Perform safe update
            if ! update_config_version; then
                log_error "Failed to update configuration (config may be corrupted)"
                exit 1
            fi
            log_info "✓ Configuration updated"
            if [[ -n "$existing_version" ]]; then
                log_info "  Version: $existing_version → $VERSION"
            else
                log_info "  Version: (not recorded) → $VERSION"
            fi
            log_info "  Backend: $existing_backend (unchanged)"
            echo ""
            log_info "Project updated to Pyve v$VERSION"

            # If the environment directory is missing (e.g. freshly cloned repo where
            # .venv is gitignored), fall through to create it rather than returning.
            local _update_env_missing=false
            if [[ "$existing_backend" == "venv" ]]; then
                local _update_venv_dir
                _update_venv_dir="$(read_config_value "venv.directory")"
                _update_venv_dir="${_update_venv_dir:-$DEFAULT_VENV_DIR}"
                if [[ ! -d "$_update_venv_dir" ]]; then
                    log_info "Environment directory '$_update_venv_dir' not found — creating it now..."
                    _update_env_missing=true
                fi
            elif [[ "$existing_backend" == "micromamba" ]]; then
                local _update_env_name
                _update_env_name="$(read_config_value "micromamba.env_name")"
                if [[ -n "$_update_env_name" ]] && [[ ! -d ".pyve/envs/$_update_env_name" ]]; then
                    log_info "Environment '.pyve/envs/$_update_env_name' not found — creating it now..."
                    _update_env_missing=true
                fi
            fi
            if [[ "$_update_env_missing" == false ]]; then
                return 0
            fi
            # Fall through to environment creation below.

        elif [[ "${PYVE_REINIT_MODE:-}" == "force" ]]; then
            # Force re-initialization mode
            log_warning "Force re-initialization: This will purge the existing environment"
            log_warning "  Current backend: $existing_backend"

            # Run pre-flight checks BEFORE purging so the environment is still intact
            # if the user decides to abort or a check fails.
            # We capture the backend here and reuse it in the main flow to avoid
            # prompting the user twice in the ambiguous case (env.yml + pyproject.toml).
            # skip_config=true: --force is a clean slate — the config records the OLD
            # backend and must not prevent re-detection from project files.
            preflight_backend="$(get_backend_priority "$backend_flag" "true")"
            if [[ "$preflight_backend" == "micromamba" ]]; then
                if ! validate_lock_file_status "$strict_mode"; then
                    log_error "Pre-flight check failed — no changes made"
                    exit 1
                fi
                lock_preflight_done=true
            fi

            # Prompt for confirmation (skip in CI or if PYVE_FORCE_YES is set).
            # Show a summary of what will happen so the user can make an informed choice.
            if [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
                echo ""
                if [[ "$preflight_backend" != "$existing_backend" ]]; then
                    printf "  ⚠ Backend change: %s → %s\n" "$existing_backend" "$preflight_backend"
                fi
                printf "  Purge:   existing %s environment\n" "$existing_backend"
                printf "  Rebuild: fresh %s environment\n" "$preflight_backend"
                echo ""
                printf "Proceed? [y/N]: "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    log_info "Cancelled — no changes made, existing environment preserved"
                    exit 0
                fi
            fi

            # Don't preserve backend on --force - let normal detection happen
            # This allows the interactive prompt to appear in ambiguous cases
            # (when both environment.yml and pyproject.toml exist)

            # Purge existing installation
            log_info "Purging existing environment..."
            purge --keep-testenv
            log_info "✓ Environment purged"
            echo ""
            log_info "Proceeding with fresh initialization..."
            
        else
            # Interactive mode (no flag specified)
            log_warning "Project already initialized with Pyve"
            if [[ -n "$existing_version" ]]; then
                log_warning "  Recorded version: $existing_version"
            fi
            log_warning "  Current version: $VERSION"
            log_warning "  Backend: $existing_backend"
            echo ""
            # Also print version info to stdout so it appears alongside the interactive prompt.
            # (Warnings are emitted to stderr, but the prompt UX should be visible in stdout.)
            if [[ -n "$existing_version" ]]; then
                printf "Recorded version: %s\n" "$existing_version"
            fi
            printf "Current version: %s\n" "$VERSION"
            printf "What would you like to do?\n"
            printf "  1. Update in-place (preserves environment, updates config)\n"
            printf "  2. Purge and re-initialize (clean slate)\n"
            printf "  3. Cancel\n"
            echo ""
            printf "Choose [1/2/3]: "
            read -r choice
            
            case "$choice" in
                1)
                    # Check for conflicts before updating
                    if [[ -n "$backend_flag" ]] && [[ "$backend_flag" != "$existing_backend" ]]; then
                        log_error "Cannot update in-place: Backend change detected"
                        log_error "  Current: $existing_backend"
                        log_error "  Requested: $backend_flag"
                        echo ""
                        log_error "Use option 2 to purge and re-initialize with new backend"
                        exit 1
                    fi
                    
                    # Perform safe update
                    if ! update_config_version; then
                        log_error "Failed to update configuration (config may be corrupted)"
                        exit 1
                    fi
                    log_info "✓ Configuration updated"
                    if [[ -n "$existing_version" ]]; then
                        log_info "  Version: $existing_version → $VERSION"
                    else
                        log_info "  Version: (not recorded) → $VERSION"
                    fi
                    log_info "  Backend: $existing_backend (unchanged)"
                    echo ""
                    log_info "Project updated to Pyve v$VERSION"

                    # If the environment directory is missing (e.g. freshly cloned repo
                    # where .venv is gitignored), fall through to create it.
                    local _interactive_env_missing=false
                    if [[ "$existing_backend" == "venv" ]]; then
                        local _interactive_venv_dir
                        _interactive_venv_dir="$(read_config_value "venv.directory")"
                        _interactive_venv_dir="${_interactive_venv_dir:-$DEFAULT_VENV_DIR}"
                        if [[ ! -d "$_interactive_venv_dir" ]]; then
                            log_info "Environment directory '$_interactive_venv_dir' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    elif [[ "$existing_backend" == "micromamba" ]]; then
                        local _interactive_env_name
                        _interactive_env_name="$(read_config_value "micromamba.env_name")"
                        if [[ -n "$_interactive_env_name" ]] && [[ ! -d ".pyve/envs/$_interactive_env_name" ]]; then
                            log_info "Environment '.pyve/envs/$_interactive_env_name' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    fi
                    if [[ "$_interactive_env_missing" == false ]]; then
                        return 0
                    fi
                    # Fall through to environment creation below.
                    ;;
                2)
                    # Purge and continue
                    log_info "Purging existing environment..."
                    purge --keep-testenv
                    log_info "✓ Environment purged"
                    echo ""
                    log_info "Proceeding with fresh initialization..."
                    ;;
                3)
                    log_info "Initialization cancelled"
                    exit 0
                    ;;
                *)
                    log_error "Invalid choice: $choice"
                    exit 1
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
        log_info "Environment name: $env_name"
        
        # Validate environment file
        if ! validate_environment_file; then
            exit 1
        fi
        
        # Create micromamba environment
        printf "\nInitializing micromamba environment...\n"
        printf "  Backend:         micromamba\n"
        printf "  Environment:     %s\n" "$env_name"
        
        local env_file
        env_file="$(detect_environment_file)"
        printf "  Using file:      %s\n" "$env_file"
        
        if ! create_micromamba_env "$env_name" "$env_file"; then
            exit 1
        fi
        
        # Verify environment
        if ! verify_micromamba_env "$env_name"; then
            log_warning "Environment created but verification failed"
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
            log_info "Skipping .envrc creation (--no-direnv)"
        fi
        
        # Create .env file
        init_dotenv "$use_local_env"
        
        # Update .gitignore — since H.e.2a the template bakes in every
        # pyve-managed ignore pattern (.pyve/envs, .pyve/testenv, .envrc,
        # .env, .vscode/settings.json), so the micromamba path needs no
        # per-backend dynamic inserts.
        write_gitignore_template

        log_success "Updated .gitignore"

        # Create .pyve/config with version tracking
        mkdir -p .pyve
        cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: micromamba
micromamba:
  env_name: $env_name
EOF
        log_success "Created .pyve/config"

        # Generate .vscode/settings.json so IDEs use the correct interpreter
        write_vscode_settings "$env_name"
        
        printf "\n✓ Micromamba environment initialized successfully!\n"
        printf "\nEnvironment location: %s\n" "$env_path"

        # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
        prompt_install_pip_dependencies "micromamba" "$env_path"

        # project-guide hook (Story G.c / FR-G2)
        run_project_guide_hooks "micromamba" "$env_path" \
            "$project_guide_mode" "$project_guide_completion_mode"

        printf "\nNext steps:\n"
        if [[ "$no_direnv" == false ]]; then
            printf "  Note: Ignore micromamba's 'activate' instructions above — Pyve uses direnv activation (or 'pyve run').\n"
            printf "  1. Run 'direnv allow' to activate the environment\n"
            printf "  2. Or use: pyve run <command>\n"
        else
            printf "  Use: pyve run <command> to execute in environment\n"
        fi
        
        return 0
    fi
    
    # Validate inputs
    if ! validate_venv_dir_name "$venv_dir"; then
        exit 1
    fi
    
    if ! validate_python_version "$python_version"; then
        exit 1
    fi
    
    printf "\nInitializing Python environment...\n"
    printf "  Backend:        %s\n" "$backend"
    printf "  Python version: %s\n" "$python_version"
    printf "  Venv directory: %s\n" "$venv_dir"
    
    # Source shell profiles to find version managers
    source_shell_profiles
    
    # Detect and validate version manager
    if ! detect_version_manager; then
        exit 1
    fi
    log_info "Using $VERSION_MANAGER for Python version management"
    
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
        log_info "Skipping .envrc creation (--no-direnv)"
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
    log_success "Created .pyve/config"

    # Ensure dev/test runner environment exists (upgrade-friendly)
    ensure_testenv_exists
    
    printf "\n✓ Python environment initialized successfully!\n"

    # Absolute venv path — used by both dep install and project-guide hooks
    local _venv_abs
    _venv_abs="$(cd "$venv_dir" && pwd)"

    # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
    prompt_install_pip_dependencies "venv" "$_venv_abs"

    # project-guide hook (Story G.c / FR-G2)
    run_project_guide_hooks "venv" "$_venv_abs" \
        "$project_guide_mode" "$project_guide_completion_mode"

    if [[ "$no_direnv" == false ]]; then
        printf "\nNext step: Run 'direnv allow' to activate the environment.\n"
    else
        printf "\nUse 'pyve run <command>' to execute commands in the environment.\n"
    fi
}

init_python_version() {
    local version="$1"
    local version_file
    version_file="$(get_version_file_name)"
    
    if [[ -f "$version_file" ]]; then
        log_info "$version_file already exists, skipping"
    else
        set_local_python_version "$version"
        log_success "Created $version_file with Python $version"
    fi
}

init_venv() {
    local venv_dir="$1"
    
    if [[ -d "$venv_dir" ]]; then
        log_info "Virtual environment '$venv_dir' already exists, skipping"
    else
        log_info "Creating virtual environment in '$venv_dir'..."
        python -m venv "$venv_dir"
        log_success "Created virtual environment"
    fi
}

init_direnv_venv() {
    local venv_dir="$1"
    local envrc_file=".envrc"
    
    if [[ -f "$envrc_file" ]]; then
        log_info ".envrc already exists, skipping"
    else
        # Get project name for prompt
        local project_name
        project_name="$(basename "$(pwd)")"
        
        # Create .envrc with dynamic path resolution and prompt
        cat > "$envrc_file" << EOF
# pyve-managed direnv configuration
# Activates Python virtual environment and loads .env

VENV_DIR="$venv_dir"

if [[ -d "\$VENV_DIR" ]]; then
    source "\$VENV_DIR/bin/activate"
    export PYVE_BACKEND="venv"
    export PYVE_ENV_NAME="$project_name"
    export PYVE_PROMPT_PREFIX="(venv:$project_name) "
fi

if [[ -f ".env" ]]; then
    dotenv
fi
EOF
        log_success "Created .envrc"
    fi
}

init_direnv_micromamba() {
    local env_name="$1"
    local env_path="$2"
    local envrc_file=".envrc"
    
    if [[ -f "$envrc_file" ]]; then
        log_info ".envrc already exists, skipping"
    else
        # Create .envrc for micromamba with prompt
        cat > "$envrc_file" << EOF
# pyve-managed direnv configuration
# Activates micromamba environment and loads .env

ENV_NAME="$env_name"
ENV_PATH="$env_path"

# Activate micromamba environment
if [[ -d "\$ENV_PATH" ]]; then
    # Add environment bin to PATH
    export PATH="\$ENV_PATH/bin:\$PATH"
    export PYVE_BACKEND="micromamba"
    export PYVE_ENV_NAME="\$ENV_NAME"
    export PYVE_ENV_PATH="\$ENV_PATH"
    export PYVE_PROMPT_PREFIX="(micromamba:\$ENV_NAME) "
fi

if [[ -f ".env" ]]; then
    dotenv
fi
EOF
        log_success "Created .envrc"
    fi
}

init_dotenv() {
    local use_local_env="$1"
    
    if [[ -f "$ENV_FILE_NAME" ]]; then
        log_info "$ENV_FILE_NAME already exists, skipping"
        return
    fi
    
    if [[ "$use_local_env" == true ]] && [[ -f "$LOCAL_ENV_FILE" ]]; then
        cp "$LOCAL_ENV_FILE" "$ENV_FILE_NAME"
        log_success "Copied $LOCAL_ENV_FILE to $ENV_FILE_NAME"
    else
        touch "$ENV_FILE_NAME"
        if [[ "$use_local_env" == true ]]; then
            log_warning "$LOCAL_ENV_FILE not found, created empty $ENV_FILE_NAME"
        else
            log_success "Created empty $ENV_FILE_NAME"
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

    log_success "Updated .gitignore"
}

#============================================================
# Purge Command
#============================================================

purge() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local keep_testenv=false
    local venv_dir_explicit=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-testenv)
                keep_testenv=true
                shift
                ;;
            -* )
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                venv_dir="$1"
                venv_dir_explicit=true
                shift
                ;;
        esac
    done
    
    printf "\nPurging Python environment artifacts...\n"
    
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
                log_success "Removed .pyve directory contents (preserved .pyve/$TESTENV_DIR_NAME)"
            else
                rm -rf ".pyve"
                log_success "Removed .pyve directory (config and micromamba environments)"
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
    
    printf "\n✓ Python environment artifacts removed.\n"
}

purge_version_file() {
    local version_file
    
    # Try to remove both possible version files
    for version_file in ".tool-versions" ".python-version"; do
        if [[ -f "$version_file" ]]; then
            rm -f "$version_file"
            log_success "Removed $version_file"
        fi
    done
}

purge_venv() {
    local venv_dir="$1"
    
    if [[ -d "$venv_dir" ]]; then
        rm -rf "$venv_dir"
        log_success "Removed $venv_dir"
    else
        log_info "No virtual environment found at '$venv_dir'"
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
                    log_info "Removing micromamba environment '$env_name'..."
                    if "$micromamba_path" env remove -n "$env_name" -y 2>/dev/null; then
                        log_success "Removed micromamba environment '$env_name'"
                    else
                        # If named removal fails, try prefix-based removal
                        log_info "Named removal failed, trying prefix-based removal..."
                        "$micromamba_path" env remove -p ".pyve/envs/$env_name" -y 2>/dev/null || true
                    fi
                else
                    # No env name in config, try to find and remove any environments in .pyve/envs
                    for env_dir in .pyve/envs/*; do
                        if [[ -d "$env_dir" ]]; then
                            local env_basename
                            env_basename="$(basename "$env_dir")"
                            log_info "Removing micromamba environment at '$env_dir'..."
                            "$micromamba_path" env remove -p "$env_dir" -y 2>/dev/null || true
                        fi
                    done
                fi
            else
                log_info "Micromamba not found, will force-remove .pyve directory"
            fi
        fi
        
        # Now remove the .pyve directory
        rm -rf ".pyve"
        log_success "Removed .pyve directory (config and micromamba environments)"
    fi
}

purge_testenv_dir() {
    if [[ -d ".pyve/$TESTENV_DIR_NAME" ]]; then
        rm -rf ".pyve/$TESTENV_DIR_NAME"
        log_success "Removed .pyve/$TESTENV_DIR_NAME"
    else
        log_info "No dev/test runner environment found at '.pyve/$TESTENV_DIR_NAME'"
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
            --init)
                action="init"
                shift
                ;;
            --install)
                action="install"
                shift
                ;;
            --purge)
                action="purge"
                shift
                ;;
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
  pyve testenv --init
  pyve testenv --install [-r requirements-dev.txt]
  pyve testenv --purge
  pyve testenv run <command> [args...]

Notes:
  - Uses: .pyve/testenv/venv
  - This environment is preserved across `pyve init --force` and `pyve purge`.
  - `run` executes a command inside the dev/test runner environment.
EOF
                exit 0
                ;;
            *)
                log_error "Unknown testenv option: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        log_error "No testenv action provided"
        log_error "Use: pyve testenv --init | --install | --purge | run <command>"
        exit 1
    fi

    local testenv_root=".pyve/$TESTENV_DIR_NAME"
    local testenv_venv="$testenv_root/venv"

    case "$action" in
        init)
            ensure_testenv_exists
            ;;
        install)
            if [[ ! -x "$testenv_venv/bin/python" ]]; then
                log_error "Dev/test runner environment not initialized"
                log_error "Run: pyve testenv --init"
                exit 1
            fi
            log_info "Installing dev/test dependencies into '$testenv_venv'..."
            if [[ -n "$requirements_file" ]]; then
                if [[ ! -f "$requirements_file" ]]; then
                    log_error "Requirements file not found: $requirements_file"
                    exit 1
                fi
                "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
            else
                "$testenv_venv/bin/python" -m pip install pytest
            fi
            log_success "Dev/test dependencies installed"
            ;;
        purge)
            purge_testenv_dir
            ;;
        run)
            if [[ $# -lt 1 ]]; then
                log_error "No command provided"
                log_error "Usage: pyve testenv run <command> [args...]"
                log_error "Example: pyve testenv run ruff check ."
                exit 1
            fi
            if [[ ! -x "$testenv_venv/bin/python" ]]; then
                log_error "Dev/test runner environment not initialized"
                log_error "Run: pyve testenv --init"
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
            ;;
    esac
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
                    log_info "Install skipped. You can install with: pyve testenv --install -r requirements-dev.txt"
                    exit 1
                fi
            else
                log_error "pytest is not installed in the dev/test runner environment."
                log_error "Run: pyve testenv --install -r requirements-dev.txt"
                exit 1
            fi
        fi
    fi

    exec "$testenv_venv/bin/python" -m pytest "$@"
}

purge_envrc() {
    if [[ -f ".envrc" ]]; then
        rm -f ".envrc"
        log_success "Removed .envrc"
    fi
}

purge_dotenv() {
    if [[ -f "$ENV_FILE_NAME" ]]; then
        if is_file_empty "$ENV_FILE_NAME"; then
            rm -f "$ENV_FILE_NAME"
            log_success "Removed $ENV_FILE_NAME (was empty)"
        else
            log_warning "$ENV_FILE_NAME preserved (contains data). Delete manually if desired."
        fi
    fi
}

purge_gitignore() {
    local venv_dir="$1"
    
    if [[ -f ".gitignore" ]]; then
        remove_pattern_from_gitignore "$venv_dir"
        remove_pattern_from_gitignore "$ENV_FILE_NAME"
        remove_pattern_from_gitignore ".envrc"
        log_success "Cleaned .gitignore"
    fi
}

#============================================================
# Python Version Command
#============================================================

set_python_version_only() {
    if [[ $# -lt 1 ]]; then
        log_error "--python-version requires a version argument"
        log_error "Usage: pyve python-version <version>"
        log_error "Example: pyve python-version 3.13.7"
        exit 1
    fi
    
    local version="$1"
    
    if ! validate_python_version "$version"; then
        exit 1
    fi
    
    printf "\nSetting Python version to %s...\n" "$version"
    
    # Source shell profiles to find version managers
    source_shell_profiles
    
    # Detect version manager
    if ! detect_version_manager; then
        exit 1
    fi
    
    # Ensure version is installed
    if ! ensure_python_version_installed "$version"; then
        exit 1
    fi
    
    # Set local version
    set_local_python_version "$version"
    
    local version_file
    version_file="$(get_version_file_name)"
    log_success "Set Python $version in $version_file"
}

#============================================================
# Install Command
#============================================================

install_self() {
    # Detect Homebrew-managed installs and warn/skip.
    if [[ "$(detect_install_source)" == "homebrew" ]]; then
        log_warning "Pyve is managed by Homebrew ($SCRIPT_DIR)."
        printf "  To update:    brew upgrade pointmatic/tap/pyve\n"
        printf "  To uninstall: brew uninstall pyve\n"
        printf "\n  --install is for non-Homebrew (git clone) installations only.\n"
        exit 0
    fi

    local source_dir="$SCRIPT_DIR"
    
    # If running from installed location, read source dir from config
    if [[ "$SCRIPT_DIR" == "$TARGET_BIN_DIR" ]]; then
        if [[ -f "$SOURCE_DIR_FILE" ]]; then
            source_dir="$(cat "$SOURCE_DIR_FILE")"
            if [[ ! -d "$source_dir" ]] || [[ ! -f "$source_dir/pyve.sh" ]]; then
                log_error "Source directory no longer exists: $source_dir"
                log_error "Please run --install from the original pyve source directory."
                exit 1
            fi

            # Avoid rewriting the currently-running script. Delegate the reinstall to the
            # repo copy so the installer runs from a different file.
            exec "$source_dir/pyve.sh" --install
        else
            log_error "Cannot reinstall: source directory not recorded."
            log_error "Please run --install from the original pyve source directory."
            exit 1
        fi
    fi
    
    printf "\nInstalling pyve to %s...\n" "$TARGET_BIN_DIR"
    printf "Source: %s\n" "$source_dir"
    
    # Create target directory if needed
    if [[ ! -d "$TARGET_BIN_DIR" ]]; then
        mkdir -p "$TARGET_BIN_DIR"
        log_success "Created $TARGET_BIN_DIR"
    fi
    
    # Copy script (atomic write to avoid partially-written script execution)
    local tmp_script
    tmp_script="$(mktemp "$TARGET_BIN_DIR/pyve.sh.XXXXXX")"
    cp "$source_dir/pyve.sh" "$tmp_script"
    chmod +x "$tmp_script"
    mv -f "$tmp_script" "$TARGET_SCRIPT_PATH"
    log_success "Installed pyve.sh"
    
    # Copy lib directory
    if [[ -d "$source_dir/lib" ]]; then
        mkdir -p "$TARGET_BIN_DIR/lib"
        cp "$source_dir/lib/"*.sh "$TARGET_BIN_DIR/lib/"
        log_success "Installed lib/ helpers"
    fi
    
    # Save source directory for future reinstalls
    mkdir -p "$(dirname "$SOURCE_DIR_FILE")"
    printf "%s\n" "$source_dir" > "$SOURCE_DIR_FILE"
    log_success "Recorded source directory"
    
    # Create symlink
    if [[ -L "$TARGET_SYMLINK_PATH" ]] || [[ -f "$TARGET_SYMLINK_PATH" ]]; then
        rm -f "$TARGET_SYMLINK_PATH"
    fi
    ln -s "$TARGET_SCRIPT_PATH" "$TARGET_SYMLINK_PATH"
    log_success "Created symlink: pyve -> pyve.sh"
    
    # Add to PATH if needed
    install_update_path

    # Install prompt hook for interactive shells
    install_prompt_hook
    
    # Create local .env template
    install_local_env_template
    
    printf "\n✓ pyve v%s installed successfully!\n" "$VERSION"
    printf "\nYou may need to restart your shell or run:\n"
    printf "  source ~/.zprofile  # or ~/.bash_profile\n"
    printf "  source ~/.zshrc     # or ~/.bashrc\n"
}

install_update_path() {
    local profile_file
    local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\"  # Added by pyve installer"
    
    # Determine profile file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        profile_file="$HOME/.zprofile"
    else
        profile_file="$HOME/.bash_profile"
    fi
    
    # Check if already in PATH
    if [[ ":$PATH:" == *":$TARGET_BIN_DIR:"* ]]; then
        log_info "$TARGET_BIN_DIR already in PATH"
        return
    fi
    
    # Check if line already in profile
    if [[ -f "$profile_file" ]] && grep -qF "# Added by pyve installer" "$profile_file"; then
        log_info "PATH already configured in $profile_file"
        return
    fi
    
    # Add to profile
    printf "\n%s\n" "$path_line" >> "$profile_file"
    log_success "Added $TARGET_BIN_DIR to PATH in $profile_file"
}

install_prompt_hook() {
    local rc_file=""

    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        rc_file="$HOME/.zshrc"
    else
        rc_file="$HOME/.bashrc"
    fi

    mkdir -p "$(dirname "$PROMPT_HOOK_FILE")"
    cat > "$PROMPT_HOOK_FILE" << 'EOF'
if [[ -n "${ZSH_VERSION:-}" ]]; then
  if [[ -z "${_PYVE_ORIG_PROMPT+set}" ]]; then
    _PYVE_ORIG_PROMPT="$PROMPT"
  fi

  _pyve_prompt_update() {
    if [[ -n "${PYVE_PROMPT_PREFIX:-}" ]]; then
      PROMPT="${PYVE_PROMPT_PREFIX}${_PYVE_ORIG_PROMPT}"
    else
      PROMPT="${_PYVE_ORIG_PROMPT}"
    fi
  }

  if (( ${precmd_functions[(Ie)_pyve_prompt_update]} == 0 )); then
    precmd_functions+=(_pyve_prompt_update)
  fi
  _pyve_prompt_update
elif [[ -n "${BASH_VERSION:-}" ]]; then
  if [[ -z "${_PYVE_ORIG_PS1+set}" ]]; then
    _PYVE_ORIG_PS1="$PS1"
  fi

  _pyve_prompt_update() {
    if [[ -n "${PYVE_PROMPT_PREFIX:-}" ]]; then
      PS1="${PYVE_PROMPT_PREFIX}${_PYVE_ORIG_PS1}"
    else
      PS1="${_PYVE_ORIG_PS1}"
    fi
  }

  if [[ -z "${_PYVE_ORIG_PROMPT_COMMAND+set}" ]]; then
    _PYVE_ORIG_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
  fi

  PROMPT_COMMAND='_pyve_prompt_update;'
  if [[ -n "${_PYVE_ORIG_PROMPT_COMMAND}" ]]; then
    PROMPT_COMMAND+="${_PYVE_ORIG_PROMPT_COMMAND}"
  fi
  _pyve_prompt_update
fi
EOF

    local source_line="source \"$PROMPT_HOOK_FILE\"  # Added by pyve installer"

    # Ensure rc file exists
    if [[ ! -f "$rc_file" ]]; then
        touch "$rc_file"
    fi

    # Remove any existing pyve prompt hook line (idempotency: allows
    # relocating the line safely on re-install).
    local tmp_rc
    tmp_rc="$(mktemp)"
    grep -vF "$PROMPT_HOOK_FILE" "$rc_file" > "$tmp_rc"
    mv -f "$tmp_rc" "$rc_file"

    # Insert via the shared SDKMan-aware helper. This respects
    # SDKMan's "must be last" load-order guidance and matches the
    # insertion behavior of the project-guide completion block.
    insert_text_before_sdkman_marker_or_append "$rc_file" "$source_line"

    log_success "Added prompt hook to $rc_file"
}

install_local_env_template() {
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        log_info "$LOCAL_ENV_FILE already exists"
        return
    fi
    
    # Create directory if needed
    mkdir -p "$(dirname "$LOCAL_ENV_FILE")"
    
    # Create empty template with secure permissions
    touch "$LOCAL_ENV_FILE"
    chmod 600 "$LOCAL_ENV_FILE"
    log_success "Created $LOCAL_ENV_FILE template"
}

#============================================================
# Uninstall Command
#============================================================

uninstall_self() {
    # Detect Homebrew-managed installs and warn/skip.
    if [[ "$(detect_install_source)" == "homebrew" ]]; then
        log_warning "Pyve is managed by Homebrew ($SCRIPT_DIR)."
        printf "  To uninstall: brew uninstall pyve\n"
        printf "\n  --uninstall is for non-Homebrew (git clone) installations only.\n"
        exit 0
    fi

    printf "\nUninstalling pyve...\n"
    
    # Remove symlink
    if [[ -L "$TARGET_SYMLINK_PATH" ]]; then
        rm -f "$TARGET_SYMLINK_PATH"
        log_success "Removed symlink: $TARGET_SYMLINK_PATH"
    fi
    
    # Remove script
    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        rm -f "$TARGET_SCRIPT_PATH"
        log_success "Removed $TARGET_SCRIPT_PATH"
    fi
    
    # Remove lib directory
    if [[ -d "$TARGET_BIN_DIR/lib" ]]; then
        rm -rf "$TARGET_BIN_DIR/lib"
        log_success "Removed $TARGET_BIN_DIR/lib"
    fi
    
    # Remove local .env template (only if empty)
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        if is_file_empty "$LOCAL_ENV_FILE"; then
            rm -f "$LOCAL_ENV_FILE"
            log_success "Removed $LOCAL_ENV_FILE (was empty)"
        else
            log_warning "$LOCAL_ENV_FILE preserved (contains data). Delete manually if desired."
        fi
    fi
    
    # Remove source directory file
    if [[ -f "$SOURCE_DIR_FILE" ]]; then
        rm -f "$SOURCE_DIR_FILE"
        log_success "Removed $SOURCE_DIR_FILE"
    fi

    # Remove prompt hook
    uninstall_prompt_hook

    # Remove PATH from profile (v0.6.1 feature)
    uninstall_clean_path

    # Remove project-guide completion blocks from both common rc files.
    # Covers users who switched shells after installing the block. Each
    # call is a safe no-op if the block is absent or the file is missing.
    # (Story G.c / FR-G2)
    uninstall_project_guide_completion

    printf "\n✓ pyve uninstalled.\n"
}

uninstall_project_guide_completion() {
    local rc_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
    )
    local rc_file
    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]] && is_project_guide_completion_present "$rc_file"; then
            remove_project_guide_completion "$rc_file"
            log_success "Removed project-guide completion block from $rc_file"
        fi
    done
}

uninstall_clean_path() {
    local profile_files=(
        "$HOME/.zprofile"
        "$HOME/.bash_profile"
    )
    
    local profile_file
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]]; then
            # Remove the line added by pyve installer
            if grep -qF "# Added by pyve installer" "$profile_file"; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' '/# Added by pyve installer/d' "$profile_file"
                else
                    sed -i '/# Added by pyve installer/d' "$profile_file"
                fi
                log_success "Removed PATH entry from $profile_file"
            fi
        fi
    done
}

uninstall_prompt_hook() {
    local rc_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
    )

    local rc_file
    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]]; then
            if grep -qF "$PROMPT_HOOK_FILE" "$rc_file" && grep -qF "# Added by pyve installer" "$rc_file"; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' "\\|$PROMPT_HOOK_FILE|d" "$rc_file"
                else
                    sed -i "\\|$PROMPT_HOOK_FILE|d" "$rc_file"
                fi
                log_success "Removed prompt hook from $rc_file"
            fi
        fi
    done

    if [[ -f "$PROMPT_HOOK_FILE" ]]; then
        rm -f "$PROMPT_HOOK_FILE"
        log_success "Removed $PROMPT_HOOK_FILE"
    fi
}

#============================================================
# Run Command
#============================================================

run_command() {
    if [[ $# -lt 1 ]]; then
        log_error "No command provided to run"
        log_error "Usage: pyve run <command> [args...]"
        log_error "Example: pyve run python --version"
        exit 1
    fi
    
    # Detect active backend by checking what exists
    local backend=""
    local venv_dir="$DEFAULT_VENV_DIR"
    
    # Check for micromamba environment first
    if [[ -d ".pyve/envs" ]]; then
        # Find the first environment directory
        local env_dirs=(.pyve/envs/*)
        if [[ -d "${env_dirs[0]}" ]] && [[ "${env_dirs[0]}" != ".pyve/envs/*" ]]; then
            backend="micromamba"
        fi
    fi
    
    # Check for venv if micromamba not found
    if [[ -z "$backend" ]] && [[ -d "$venv_dir" ]]; then
        backend="venv"
    fi
    
    # Error if no environment found
    if [[ -z "$backend" ]]; then
        log_error "No Python environment found"
        log_error "Run 'pyve init' to create an environment first"
        exit 1
    fi
    
    # Execute command based on backend
    if [[ "$backend" == "venv" ]]; then
        # Venv backend: prefer venv bin, but allow system commands too
        local cmd="$1"
        shift

        local venv_bin="$venv_dir/bin"
        local cmd_path="$venv_bin/$cmd"

        if [[ -x "$cmd_path" ]]; then
            exec "$cmd_path" "$@"
        fi

        export VIRTUAL_ENV="$PWD/$venv_dir"
        export PATH="$venv_bin:$PATH"
        exec "$cmd" "$@"
        
    elif [[ "$backend" == "micromamba" ]]; then
        # Micromamba backend: use micromamba run
        
        # Get micromamba path
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -z "$micromamba_path" ]]; then
            log_error "Micromamba not found"
            exit 1
        fi
        
        # Find environment directory
        local env_dirs=(.pyve/envs/*)
        local env_path="${env_dirs[0]}"
        
        if [[ ! -d "$env_path" ]]; then
            log_error "Micromamba environment not found"
            exit 1
        fi
        
        # Execute command using micromamba run
        exec "$micromamba_path" run -p "$env_path" "$@"
    fi
}

#============================================================
# Doctor Command
#============================================================

doctor_command() {
    printf "Pyve Environment Diagnostics\n"
    printf "=============================\n\n"
    
    # Detect install source
    local install_source
    install_source="$(detect_install_source)"
    printf "✓ Pyve: v%s (%s: %s)\n" "$VERSION" "$install_source" "$SCRIPT_DIR"
    
    # Check version compatibility
    if config_file_exists; then
        validate_pyve_version
    fi
    
    local backend=""
    local venv_dir="$DEFAULT_VENV_DIR"
    local env_path=""
    local env_name=""

    # If a project config exists, prefer its venv directory for venv detection.
    if config_file_exists; then
        local configured_venv_dir
        configured_venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
        if [[ -n "$configured_venv_dir" ]]; then
            venv_dir="$configured_venv_dir"
        fi
    fi
    
    # Detect active backend
    # Check for micromamba environment first
    if [[ -d ".pyve/envs" ]]; then
        local env_dirs=(.pyve/envs/*)
        if [[ -d "${env_dirs[0]}" ]] && [[ "${env_dirs[0]}" != ".pyve/envs/*" ]]; then
            backend="micromamba"
            env_path="${env_dirs[0]}"
            env_name="$(basename "$env_path")"
        fi
    fi
    
    # Check for venv if micromamba not found
    if [[ -z "$backend" ]] && [[ -d "$venv_dir" ]]; then
        backend="venv"
        env_path="$venv_dir"
    fi
    
    # Check if no environment found
    if [[ -z "$backend" ]]; then
        printf "✗ No environment found\n"
        printf "  Run 'pyve init' to create an environment\n"
        exit 1
    fi
    
    # Report backend
    printf "✓ Backend: %s\n" "$backend"
    
    # Backend-specific checks
    if [[ "$backend" == "micromamba" ]]; then
        # Check micromamba binary
        if check_micromamba_available; then
            local mm_path
            mm_path="$(get_micromamba_path)"
            local mm_version
            mm_version="$(get_micromamba_version)"
            local mm_location
            mm_location="$(get_micromamba_location)"
            printf "✓ Micromamba: %s (%s) v%s\n" "$mm_path" "$mm_location" "$mm_version"
        else
            printf "✗ Micromamba: not found\n"
            if [[ -f ".pyve/bin/micromamba" ]] && [[ ! -x ".pyve/bin/micromamba" ]]; then
                printf "  Found at: %s (not executable)\n" "$(pwd)/.pyve/bin/micromamba"
                printf "  Fix with: chmod +x .pyve/bin/micromamba\n"
            elif [[ -f "$HOME/.pyve/bin/micromamba" ]] && [[ ! -x "$HOME/.pyve/bin/micromamba" ]]; then
                printf "  Found at: %s (not executable)\n" "$HOME/.pyve/bin/micromamba"
                printf "  Fix with: chmod +x $HOME/.pyve/bin/micromamba\n"
            else
                printf "  Checked: .pyve/bin/micromamba\n"
                printf "  Checked: $HOME/.pyve/bin/micromamba\n"
                printf "  Checked: micromamba on PATH\n"
            fi
        fi
        
        # Check environment
        if [[ -d "$env_path" ]]; then
            printf "✓ Environment: %s\n" "$env_path"
            printf "  Name: %s\n" "$env_name"
        else
            printf "✗ Environment: not found\n"
        fi
        
        # Check Python in environment
        if [[ -f "$env_path/bin/python" ]]; then
            local py_version
            py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
            printf "✓ Python: %s\n" "$py_version"
        else
            printf "⚠ Python: not found in environment\n"
        fi
        
        # Check environment file
        local env_file
        env_file="$(detect_environment_file 2>/dev/null)" || true
        if [[ -n "$env_file" ]]; then
            printf "✓ Environment file: %s\n" "$env_file"
            
            # Check lock file status if environment.yml exists
            if [[ "$env_file" == "environment.yml" ]] || [[ -f "environment.yml" ]]; then
                if [[ -f "conda-lock.yml" ]]; then
                    if is_lock_file_stale; then
                        printf "⚠ Lock file: conda-lock.yml (stale)\n"
                        local env_mtime
                        local lock_mtime
                        env_mtime="$(get_file_mtime_formatted "environment.yml")"
                        lock_mtime="$(get_file_mtime_formatted "conda-lock.yml")"
                        printf "  environment.yml: %s\n" "$env_mtime"
                        printf "  conda-lock.yml:  %s\n" "$lock_mtime"
                    else
                        printf "✓ Lock file: conda-lock.yml (up to date)\n"
                    fi
                else
                    printf "⚠ Lock file: missing\n"
                    printf "  Generate with: conda-lock -f environment.yml\n"
                fi
            fi
        else
            printf "⚠ Environment file: not found\n"
        fi
        
        # Count packages
        if [[ -d "$env_path/conda-meta" ]]; then
            local pkg_count
            pkg_count=$(find "$env_path/conda-meta" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
            printf "  Packages: %s installed\n" "$pkg_count"
        fi

        # Check for duplicate dist-info, cloud sync collision artifacts, and native lib conflicts
        doctor_check_duplicate_dist_info "$env_path"
        doctor_check_collision_artifacts "$env_path"
        doctor_check_native_lib_conflicts "$env_path"

    elif [[ "$backend" == "venv" ]]; then
        # Check venv directory
        if [[ -d "$env_path" ]]; then
            printf "✓ Environment: %s\n" "$env_path"
        else
            printf "✗ Environment: not found\n"
        fi
        
        # Check Python in venv
        if [[ -f "$env_path/bin/python" ]]; then
            local py_version
            py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
            printf "✓ Python: %s\n" "$py_version"
        else
            printf "✗ Python: not found in venv\n"
        fi

        # Check venv path consistency (detect relocated projects)
        doctor_check_venv_path "$env_path"

        # Check Python version file
        if [[ -f ".tool-versions" ]]; then
            local version_manager="asdf"
            local py_ver
            py_ver="$(grep "^python " .tool-versions | awk '{print $2}')"
            printf "✓ Version file: .tool-versions (asdf)\n"
            printf "  Python: %s\n" "$py_ver"
        elif [[ -f ".python-version" ]]; then
            local version_manager="pyenv"
            local py_ver
            py_ver="$(cat .python-version)"
            printf "✓ Version file: .python-version (pyenv)\n"
            printf "  Python: %s\n" "$py_ver"
        else
            printf "⚠ Version file: not found\n"
        fi
        
        # Count packages in venv
        if [[ -d "$env_path/lib" ]]; then
            local site_packages
            site_packages=$(find "$env_path/lib" -type d -name "site-packages" 2>/dev/null | head -1)
            if [[ -n "$site_packages" ]]; then
                local pkg_count
                pkg_count=$(find "$site_packages" -maxdepth 1 -name "*.dist-info" 2>/dev/null | wc -l | tr -d ' ')
                printf "  Packages: %s installed\n" "$pkg_count"
            fi
        fi
    fi
    
    # Check direnv
    if [[ -f ".envrc" ]]; then
        printf "✓ Direnv: .envrc configured\n"
    else
        printf "⚠ Direnv: .envrc not found\n"
        printf "  Use 'pyve run' to execute commands\n"
    fi
    
    # Check .env file
    if [[ -f ".env" ]]; then
        if is_file_empty ".env"; then
            printf "✓ Environment file: .env (empty)\n"
        else
            printf "✓ Environment file: .env (configured)\n"
        fi
    else
        printf "⚠ Environment file: .env not found\n"
    fi

    # Dev/test runner environment (non-invasive diagnostics)
    local testenv_root=".pyve/$TESTENV_DIR_NAME"
    local testenv_venv="$testenv_root/venv"
    if [[ -d "$testenv_venv" ]]; then
        printf "✓ Test runner: %s\n" "$testenv_venv"
        if [[ -x "$testenv_venv/bin/python" ]]; then
            local test_py_version
            test_py_version="$("$testenv_venv/bin/python" --version 2>&1 | awk '{print $2}')"
            printf "  Test runner Python: %s\n" "$test_py_version"
            if "$testenv_venv/bin/python" -c "import pytest" >/dev/null 2>&1; then
                printf "  ✓ pytest: installed\n"
            else
                printf "  ⚠ pytest: missing\n"
                printf "    Install with: pyve test (interactive) or pyve testenv --install -r requirements-dev.txt\n"
            fi
        else
            printf "  ⚠ Test runner Python: not found\n"
        fi
    else
        printf "⚠ Test runner: not found\n"
        printf "  Create with: pyve testenv --init (or run: pyve test)\n"
    fi
    
    printf "\n"
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
                log_error "Unknown option: $1"
                log_error "See: pyve update --help"
                exit 1
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
# Lock Command
#============================================================

# Run conda-lock for the current platform, handling output filtering and
# actionable next-step messaging.
run_lock() {
    local check_mode=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                check_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                log_error "Usage: pyve lock [--check]"
                exit 1
                ;;
        esac
    done

    # --check: mtime comparison only, no conda-lock invocation
    if [[ "$check_mode" == "true" ]]; then
        if [[ ! -f "environment.yml" ]]; then
            log_error "environment.yml not found."
            exit 1
        fi
        if [[ ! -f "conda-lock.yml" ]]; then
            printf "✗ conda-lock.yml not found. Run: pyve lock\n" >&2
            exit 1
        fi
        if is_lock_file_stale; then
            printf "✗ conda-lock.yml is stale — environment.yml has been modified since the lock was generated. Run: pyve lock\n" >&2
            exit 1
        fi
        printf "✓ conda-lock.yml is up to date.\n"
        return 0
    fi

    local platform

    # Guard 1: venv backend projects do not use conda-lock
    if config_file_exists; then
        local config_backend
        config_backend="$(read_config_value "backend")"
        if [[ "$config_backend" == "venv" ]]; then
            log_error "pyve lock is for micromamba projects only."
            log_error "This project uses the venv backend. conda-lock.yml is not used by venv."
            exit 1
        fi
    fi

    # Guard 2: environment.yml must exist
    if [[ ! -f "environment.yml" ]]; then
        log_error "environment.yml not found. pyve lock requires a conda environment file."
        log_error "Initialize with: pyve init --backend micromamba"
        exit 1
    fi

    # Guard 3: conda-lock must be on PATH
    if ! command -v conda-lock >/dev/null 2>&1; then
        log_error "conda-lock is not available in the current environment."
        log_error "Add 'conda-lock' to environment.yml dependencies and run 'pyve init --force'."
        exit 1
    fi

    platform="$(get_conda_platform)"

    log_info "Generating conda-lock.yml for ${platform}..."
    printf "\n"

    # Run conda-lock, capturing combined output
    local output
    local exit_code
    output="$(conda-lock -f environment.yml -p "$platform" 2>&1)"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        # Pass through conda-lock's error output unmodified
        printf "%s\n" "$output" >&2
        exit $exit_code
    fi

    # Filter out the misleading "conda-lock install" post-run message that suggests
    # a non-Pyve workflow. All other output (solver progress, packages) is kept.
    local filtered_output
    filtered_output="$(printf "%s\n" "$output" | grep -v "conda-lock install\|Install lock using")"
    if [[ -n "$filtered_output" ]]; then
        printf "%s\n" "$filtered_output"
        printf "\n"
    fi

    # Detect "already up to date" case: conda-lock emits "spec hash already locked"
    # when the environment spec hasn't changed since the last run.
    # Checked after printing so any warnings in the output are still visible.
    if printf "%s" "$output" | grep -qi "already locked\|spec hash already locked"; then
        printf "✓ conda-lock.yml is already up to date for %s. No changes made.\n" "$platform"
        exit 0
    fi

    printf "✓ conda-lock.yml updated for %s.\n" "$platform"
    printf "\n"
    printf "To rebuild the environment from the new lock file:\n"
    printf "  pyve init --force\n"
    printf "\n"
    printf "If the environment is already initialized and you only need to commit the\n"
    printf "updated lock file, rebuilding is optional.\n"
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

Examples:
  pyve purge                               # Remove .pyve and the venv
  pyve purge --keep-testenv                # Preserve the testenv across purge
  pyve purge custom_venv                   # Remove a custom-named venv

See `pyve --help` for the full command list.
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

show_validate_help() {
    cat << 'EOF'
pyve validate - Validate Pyve installation and configuration

Usage:
  pyve validate

Description:
  Checks version compatibility, .pyve/config structure, backend setup,
  and environment health. Useful as a pre-build gate in CI.

Exit codes:
  0    All validations passed
  1    Errors found (e.g., missing venv, invalid backend)
  2    Warnings only (e.g., version mismatch)

See `pyve --help` for the full command list.
EOF
}

show_python_version_help() {
    cat << 'EOF'
pyve python-version - Set Python version without creating an environment

Usage:
  pyve python-version <version>

Arguments:
  <version>                   Python version in #.#.# form (e.g., 3.13.7)

Description:
  Writes the version to .python-version (asdf/pyenv format) so
  subsequent `pyve init` invocations pick it up. Does not create
  or modify any virtual environment.

Examples:
  pyve python-version 3.13.7

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

#------------------------------------------------------------
# self namespace dispatcher.
#------------------------------------------------------------
self_command() {
    if [[ $# -eq 0 ]]; then
        show_self_help
        return 0
    fi

    case "$1" in
        install)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_install_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-install %s\n' "$*"
                return 0
            fi
            install_self
            ;;
        uninstall)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_uninstall_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-uninstall %s\n' "$*"
                return 0
            fi
            uninstall_self
            ;;
        --help|-h)
            show_self_help
            return 0
            ;;
        *)
            log_error "Unknown 'pyve self' subcommand: $1"
            show_self_help
            exit 1
            ;;
    esac
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
            legacy_flag_error "--validate" "validate"
            ;;
        --python-version)
            legacy_flag_error "--python-version" "python-version <ver>"
            ;;
        --install)
            legacy_flag_error "--install" "self install"
            ;;
        --uninstall)
            legacy_flag_error "--uninstall" "self uninstall"
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
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_validate_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:validate %s\n' "$*"
                exit 0
            fi
            run_full_validation
            exit $?
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
        python-version)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_python_version_help
                exit 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:python-version %s\n' "$*"
                exit 0
            fi
            set_python_version_only "$@"
            ;;
        self)
            shift
            self_command "$@"
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
            run_lock "$@"
            ;;
        doctor)
            doctor_command
            ;;

        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
