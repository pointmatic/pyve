# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve run — execute a command inside the active project environment
#
# Auto-detects the active backend (venv vs micromamba) by probing
# .pyve/envs/* (preferred) then $DEFAULT_VENV_DIR, exec()s the target
# command with environment activation done in-process (no shell layer).
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard at the bottom.
#============================================================

# Refuse direct execution. The file is a library; running it as a
# script would fall through to nothing useful and confuse the user.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

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

    # Story J.c: defense-in-depth asdf reshim guard. The .envrc block
    # added in J.b covers the direnv-allow path; this covers `pyve run`
    # used with --no-direnv, or in CI where .envrc is never sourced.
    # Probe the version manager silently — real setup errors would have
    # surfaced during `pyve init`, and noise on every `pyve run` would
    # be unpleasant. Export (vs `env VAR=...` prefix) because exec
    # replaces the shell anyway, so parent-env pollution is moot.
    source_shell_profiles >/dev/null 2>&1 || true
    detect_version_manager >/dev/null 2>&1 || true
    if is_asdf_active; then
        export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
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
