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

#------------------------------------------------------------
# Plugin contract — runtime hooks (Story N.p, Option 2)
#
# Hook-as-shim: check / status / run / test delegate to today's
# implementations in lib/commands/{check,status,run,test}.sh.
# check and status additionally render the S7 manual_steps advisory
# and the S11 languages advisory before delegating; run and test
# are pure forwarders.
#
# Render-before-delegate placement: advisories print at the top so
# the user sees relevant setup context before the diagnostic body.
# `check_environment` and `show_status` exit the process from their
# summary functions, so render-AFTER-delegate isn't reachable.
#------------------------------------------------------------

# S7 + S11 advisory renderer. Iterates declared envs and prints:
#   - "Manual steps" section listing each env's non-empty manual_steps
#   - "Warning: env '<name>' declares languages without 'python'"
# Silent when no env has manual_steps and no env has a mismatched
# languages list. Exit code always 0 — advisories are informational.
_python_pyve_plugin_render_advisories() {
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    local n=${#PYVE_ENV_NAMES[@]}
    [[ "$n" -eq 0 ]] && return 0

    local i name
    local -a steps langs
    local manual_header_printed=0
    local manual_count step

    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"

        # S7: manual_steps
        steps=()
        manifest_get_manual_steps "$name" steps 2>/dev/null || true
        manual_count="${#steps[@]}"
        if [[ "$manual_count" -gt 0 ]]; then
            if [[ "$manual_header_printed" -eq 0 ]]; then
                printf "Manual steps (advisory — pyve does not run these):\n"
                manual_header_printed=1
            fi
            printf "  env '%s':\n" "$name"
            for step in "${steps[@]}"; do
                printf "    - %s\n" "$step"
            done
        fi

        # S11: languages declared but no 'python' present.
        langs=()
        manifest_get_languages "$name" langs 2>/dev/null || true
        if [[ "${#langs[@]}" -gt 0 ]]; then
            local found_python=0 lang
            for lang in "${langs[@]}"; do
                [[ "$lang" == "python" ]] && { found_python=1; break; }
            done
            if [[ "$found_python" -eq 0 ]]; then
                printf "warning: env '%s' declares languages = [%s] without 'python' — the Python plugin manages this env\n" \
                    "$name" "${langs[*]}"
            fi
        fi
    done
    return 0
}

python_pyve_plugin_check() {
    _python_pyve_plugin_render_advisories
    check_environment "$@"
}

python_pyve_plugin_status() {
    _python_pyve_plugin_render_advisories
    show_status "$@"
}

python_pyve_plugin_run() {
    run_command "$@"
}

python_pyve_plugin_test() {
    test_tests "$@"
}

#------------------------------------------------------------
# `pyve python set` / `pyve python show` (Story N.p, Option (a))
#
# These are not standard plugin-contract hooks — they're
# Python-version-management commands that logically belong to the
# Python plugin. Moved here from lib/commands/python.sh; the
# `python_command` dispatcher there still calls them by name (bash
# function lookup is global). Behavior unchanged.
#------------------------------------------------------------

python_set() {
    if [[ $# -lt 1 ]]; then
        log_error "pyve python set requires a version argument"
        log_error "Usage: pyve python set <version>"
        log_error "Example: pyve python set 3.13.7"
        exit 1
    fi

    local version="$1"

    header_box "pyve python set"

    if ! validate_python_version "$version"; then
        exit 1
    fi

    banner "Setting Python version to $version"

    source_shell_profiles

    if ! detect_version_manager; then
        exit 1
    fi

    if ! ensure_python_version_installed "$version"; then
        exit 1
    fi

    set_local_python_version "$version"

    local version_file
    version_file="$(get_version_file_name)"
    success "Set Python $version in $version_file"
    footer_box
}

python_show() {
    local version="" source=""
    if [[ -f ".tool-versions" ]]; then
        version="$(grep "^python " .tool-versions 2>/dev/null | awk '{print $2}')"
        source=".tool-versions"
    elif [[ -f ".python-version" ]]; then
        version="$(cat .python-version 2>/dev/null | head -1)"
        source=".python-version"
    else
        version="$(read_config_value "python.version" 2>/dev/null || true)"
        source=".pyve/config"
    fi

    if [[ -z "$version" ]]; then
        printf "No Python version pinned in this project.\n"
        printf "  (not pinned — use 'pyve python set <version>' to pin one)\n"
        return 0
    fi
    printf "Python %s (from %s)\n" "$version" "$source"
}
