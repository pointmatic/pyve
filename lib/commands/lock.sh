# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve lock — generate or verify conda-lock.yml (micromamba only)
#
# Wraps `conda-lock` with backend guards, prerequisite checks, platform
# detection, output filtering (drops the misleading "conda-lock install"
# post-run hint), and "already up to date" detection. The --check flag
# performs an mtime-only comparison and never invokes conda-lock.
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution. The file is a library; running it as a
# script would fall through to nothing useful and confuse the user.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Run conda-lock for the current platform, handling output filtering and
# actionable next-step messaging.
#
# Function-name note: this function is named `lock_environment` per the
# project-essentials "Function naming convention: verb_<operand>" rule —
# `pyve lock` operates on the environment's dependency graph (locks
# `environment.yml` → `conda-lock.yml`).
lock_environment() {
    local check_mode=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                check_mode=true
                shift
                ;;
            -*)
                unknown_flag_error "lock" "$1" --check --help
                ;;
            *)
                log_error "pyve lock takes no positional arguments (got: $1)"
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
