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

#------------------------------------------------------------
# Plugin contract — lifecycle hooks (Story N.o, Option 2)
#
# Hook-as-shim re-seat: each hook validates the manifest's env
# blocks (per S9), reads the `languages` advisory (per S11; v3.0
# is read-only, N.p surfaces it in `pyve check` / `pyve status`),
# and delegates to the existing `init_project` / `purge_project` /
# `update_project` implementations in lib/commands/*.sh. The
# implementations stay there in N.o; N.s revisits whether to
# relocate them into this plugin file.
#------------------------------------------------------------

# S9 env-block validation. Iterates every declared env; checks
# `purpose` ∈ {run, test, utility, temp} (the helper itself catches
# unknown purposes at parse time, so this is a defense-in-depth
# secondary check), and `backend`, if non-empty, must be a registered
# backend-provider name (bp_lookup returns 0). Empty backend is
# allowed — the manifest doesn't require it; commands resolve a
# default elsewhere.
python_pyve_plugin_validate_env_blocks() {
    local n
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    n=${#PYVE_ENV_NAMES[@]}
    [[ "$n" -eq 0 ]] && return 0

    local i name purpose backend
    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"
        purpose="${PYVE_ENV_PURPOSE[$i]}"
        backend="${PYVE_ENV_BACKEND[$i]}"

        # purpose check — empty is allowed (manifest_resolve_purpose
        # applies a name-based default elsewhere). Non-empty values
        # are validated by the Python helper at parse time; we
        # double-check here so a synthesized v2 read-compat shape
        # can't slip through with an unexpected value.
        if [[ -n "$purpose" ]]; then
            case "$purpose" in
                run|test|utility|temp) ;;
                *)
                    printf "error: python plugin: env '%s' has unknown purpose '%s' (expected one of: run, test, utility, temp)\n" \
                        "$name" "$purpose" >&2
                    return 1
                    ;;
            esac
        fi

        # backend check — bp_lookup returns 1 (no output) for
        # unregistered backends.
        if [[ -n "$backend" ]]; then
            if ! bp_lookup "$backend" >/dev/null 2>&1; then
                printf "error: python plugin: env '%s' declares unregistered backend '%s'\n" \
                    "$name" "$backend" >&2
                return 1
            fi
        fi
    done
    return 0
}

# S11 languages advisory read. Currently a no-op data-flow probe:
# iterates declared envs and reads `languages` via the manifest
# accessor. N.p will surface the read in `pyve check` / `pyve status`.
# Read failures (unknown env, unset languages) are silent — the field
# is advisory, not load-bearing.
_python_pyve_plugin_languages_advisory_read() {
    local n
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    n=${#PYVE_ENV_NAMES[@]}

    local i name
    local -a _langs
    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"
        _langs=()
        manifest_get_languages "$name" _langs 2>/dev/null || true
        # _langs is intentionally unused in N.o — N.p threads it
        # into the diagnostics output. The read confirms the data
        # flow is wired so N.p can rely on it without a schema change.
    done
    return 0
}

python_pyve_plugin_init() {
    python_pyve_plugin_validate_env_blocks || return $?
    _python_pyve_plugin_languages_advisory_read
    init_project "$@"
}

python_pyve_plugin_purge() {
    purge_project "$@"
}

python_pyve_plugin_update() {
    update_project "$@"
}
