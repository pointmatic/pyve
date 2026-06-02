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

    # Detect active backend. Authoritative source is .pyve/config's
    # `backend:` field; the directory heuristic is only a fallback for
    # legacy projects with no config. Story N.j.1: post-N.f, the
    # `.pyve/envs/*` glob also matches testenvs (e.g. .pyve/envs/testenv/),
    # so the pre-N.f "any child under .pyve/envs/ means micromamba" rule
    # would mis-route every venv-backed project that has a testenv to the
    # micromamba branch — and within micromamba projects, mis-route the
    # main env to whichever sibling sorted first alphabetically.
    local backend=""
    local venv_dir="$DEFAULT_VENV_DIR"
    local mm_env_name=""

    if [[ -f ".pyve/config" ]]; then
        backend="$(read_config_value backend 2>/dev/null || printf '')"
        if [[ "$backend" == "micromamba" ]]; then
            mm_env_name="$(read_config_value micromamba.env_name 2>/dev/null || printf '')"
        fi
    fi

    # Fallback for legacy projects with no .pyve/config: prefer the
    # explicit `.venv/` signal; otherwise look for a single-tenant
    # `.pyve/envs/<name>/` (pre-N.f micromamba layout).
    if [[ -z "$backend" ]]; then
        if [[ -d "$venv_dir" ]]; then
            backend="venv"
        elif [[ -d ".pyve/envs" ]]; then
            local env_dirs=(.pyve/envs/*)
            if [[ -d "${env_dirs[0]:-}" ]] && [[ "${env_dirs[0]}" != ".pyve/envs/*" ]]; then
                backend="micromamba"
                mm_env_name="$(basename "${env_dirs[0]}")"
            fi
        fi
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

        # Identify the micromamba main env. mm_env_name was set above
        # from `.pyve/config:micromamba.env_name` (or, for legacy
        # projects with no config, from the sole .pyve/envs/* entry).
        if [[ -z "$mm_env_name" ]]; then
            log_error "Micromamba env_name not recorded in .pyve/config"
            exit 1
        fi
        local env_path=".pyve/envs/$mm_env_name"
        if [[ ! -d "$env_path" ]]; then
            log_error "Micromamba environment not found at $env_path"
            exit 1
        fi

        # Execute command using micromamba run
        exec "$micromamba_path" run -p "$env_path" "$@"
    fi
}
