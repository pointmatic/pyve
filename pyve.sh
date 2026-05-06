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

VERSION="2.4.0"
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

if [[ -f "$SCRIPT_DIR/lib/ui/core.sh" ]]; then
    # shellcheck source=lib/ui/core.sh
    source "$SCRIPT_DIR/lib/ui/core.sh"
else
    printf "ERROR: Cannot find lib/ui/core.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/ui/run.sh" ]]; then
    # shellcheck source=lib/ui/run.sh
    source "$SCRIPT_DIR/lib/ui/run.sh"
else
    printf "ERROR: Cannot find lib/ui/run.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/ui/progress.sh" ]]; then
    # shellcheck source=lib/ui/progress.sh
    source "$SCRIPT_DIR/lib/ui/progress.sh"
else
    printf "ERROR: Cannot find lib/ui/progress.sh\n" >&2
    exit 1
fi

#============================================================
# Source per-command modules (Phase K — alphabetical)
#============================================================

if [[ -f "$SCRIPT_DIR/lib/commands/check.sh" ]]; then
    # shellcheck source=lib/commands/check.sh
    source "$SCRIPT_DIR/lib/commands/check.sh"
else
    printf "ERROR: Cannot find lib/commands/check.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/init.sh" ]]; then
    # shellcheck source=lib/commands/init.sh
    source "$SCRIPT_DIR/lib/commands/init.sh"
else
    printf "ERROR: Cannot find lib/commands/init.sh\n" >&2
    exit 1
fi

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

if [[ -f "$SCRIPT_DIR/lib/commands/purge.sh" ]]; then
    # shellcheck source=lib/commands/purge.sh
    source "$SCRIPT_DIR/lib/commands/purge.sh"
else
    printf "ERROR: Cannot find lib/commands/purge.sh\n" >&2
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

if [[ -f "$SCRIPT_DIR/lib/commands/status.sh" ]]; then
    # shellcheck source=lib/commands/status.sh
    source "$SCRIPT_DIR/lib/commands/status.sh"
else
    printf "ERROR: Cannot find lib/commands/status.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/test.sh" ]]; then
    # shellcheck source=lib/commands/test.sh
    source "$SCRIPT_DIR/lib/commands/test.sh"
else
    printf "ERROR: Cannot find lib/commands/test.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/testenv.sh" ]]; then
    # shellcheck source=lib/commands/testenv.sh
    source "$SCRIPT_DIR/lib/commands/testenv.sh"
else
    printf "ERROR: Cannot find lib/commands/testenv.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/commands/update.sh" ]]; then
    # shellcheck source=lib/commands/update.sh
    source "$SCRIPT_DIR/lib/commands/update.sh"
else
    printf "ERROR: Cannot find lib/commands/update.sh\n" >&2
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
    --verbose                 Stream subprocess output live; suppress quiet
                              defaults. Equivalent to `PYVE_VERBOSE=1`.
                              Parsed before the subcommand:
                              `pyve --verbose init` (not `pyve init --verbose`).

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
# (via `_edit_distance` in lib/ui/core.sh). Emits "Did you mean X?"
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


main() {
    # Global flags consumed before subcommand dispatch (Story L.f).
    # `--verbose` is parsed here so every subcommand sees PYVE_VERBOSE=1
    # without each having to re-implement the flag.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                export PYVE_VERBOSE=1
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    # The dispatch trace surfaces verbosity state alongside the
    # resolved handler so tests can assert wiring without adding
    # any user-visible behavior. Honors PYVE_VERBOSE set via either
    # `--verbose` (handled above) or directly in the environment.
    if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
        printf 'VERBOSE:%s\n' "${PYVE_VERBOSE:-0}"
    fi

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
            init_project "$@"
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
            purge_project "$@"
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
            update_project "$@"
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
            test_tests "$@"
            ;;
        lock)
            shift
            lock_environment "$@"
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
            check_environment "$@"
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
            show_status "$@"
            ;;

        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
