# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/python/plugin.sh — Python plugin (Story N.n)
#
# First reference implementation of the plugin contract from N.k.
# Re-seats the Python ecosystem behind the contract. This story
# implements three hooks plus the backend-provider activate shims
# absorbed from N.l's transition state:
#
#   python_pyve_plugin_manifest_namespace   — returns "python"
#   python_pyve_plugin_register_backends    — bp_register venv + micromamba
#   python_pyve_plugin_detect               — scaffold-time file-signal scan
#   venv_pyve_bp_activate                   — backend-provider activate shim
#   micromamba_pyve_bp_activate             — backend-provider activate shim
#
# Lifecycle hooks (init / purge / update / check / status / run /
# test) stay as no-op defaults from contract.sh in N.n; they land in
# Stories N.o (init/purge/update) and N.p (check/status/run/test).
# The activation hook proper (`.envrc` snippet composition) and the
# gitignore + smart-purge hooks land in N.q and N.r respectively.
#
# Detection contract (per Story N.n task list + spike):
#   Signal classes (probed at the project root):
#     Python: pyproject.toml | requirements*.txt | setup.py | *.py
#     Conda:  environment*.yml | conda-lock.yml
#   Output:
#     - both classes present → "ambiguous"
#     - only conda           → "micromamba"
#     - only python          → "venv"
#     - neither              → "none"
#
# Per the spike, detection is scaffold-time only: once `pyve.toml`
# exists, the manifest is the runtime source of truth.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Plugin contract — manifest_namespace
#------------------------------------------------------------

python_pyve_plugin_manifest_namespace() {
    printf 'python'
}

#------------------------------------------------------------
# Plugin contract — register_backends
#
# bp_register is idempotent for identical re-registration, so this
# hook is safe to call multiple times (the eager source-time call
# and any later contract-driven re-fire both land on a consistent
# registry state).
#------------------------------------------------------------

python_pyve_plugin_register_backends() {
    bp_register python venv virtualized
    bp_register python micromamba virtualized
}

#------------------------------------------------------------
# Plugin contract — detect (scaffold-time only)
#------------------------------------------------------------

python_pyve_plugin_detect() {
    local has_python=false
    local has_conda=false

    # Python signal probes. compgen -G is a bash builtin (no subshell,
    # bash 3.2-safe); returns 0 with the match list when at least one
    # path expands, 1 otherwise. We discard the output.
    if [[ -f "pyproject.toml" ]] \
        || [[ -f "setup.py" ]] \
        || compgen -G "requirements*.txt" >/dev/null 2>&1 \
        || compgen -G "*.py" >/dev/null 2>&1; then
        has_python=true
    fi

    # Conda signal probes.
    if [[ -f "conda-lock.yml" ]] \
        || compgen -G "environment*.yml" >/dev/null 2>&1; then
        has_conda=true
    fi

    if [[ "$has_python" == true ]] && [[ "$has_conda" == true ]]; then
        printf 'ambiguous'
    elif [[ "$has_conda" == true ]]; then
        printf 'micromamba'
    elif [[ "$has_python" == true ]]; then
        printf 'venv'
    else
        printf 'none'
    fi
}

#------------------------------------------------------------
# Backend-provider activate shims (absorbed from lib/commands/init.sh
# per N.n; previously written into init.sh as N.l transition state).
#
# The shims forward `bp_dispatch <backend> activate <env_path> <env_name>`
# to the existing `_init_direnv_*` helpers. The signature is unified
# across backends — venv ignores env_name (uses cwd basename via
# _init_direnv_venv); micromamba uses both.
#------------------------------------------------------------

venv_pyve_bp_activate() {
    _init_direnv_venv "$1"
}

micromamba_pyve_bp_activate() {
    _init_direnv_micromamba "$2" "$1"
}
