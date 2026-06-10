# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve package — materialize an environment's packaging artifact
#
# `pyve package [--env <name>]` builds the packaging artifact declared for
# an environment via its `packaging` attribute in pyve.toml (S15), by
# dispatching to a registered packaging provider (the N.aq registry).
#
# RESERVED IN v3.0 (concept Q6 / v3.0-window decision): no packaging
# provider materializes yet. The registry registers zero providers, so the
# live path is the "reserved" advisory — accept the declared `packaging`
# value and exit 0 with a clean message, rather than "unknown command".
# A post-v3.0 provider drops in transparently with no breaking change.
# `deploy` (shipping the artifact) is reserved for a future ship step (O1).
#
# Closed-set validation of the `packaging` vocabulary (hard-error on
# unknown) is F6 in Subphase N-6, not here — this verb reads leniently.
#
# This file is sourced by pyve.sh's library-loading block. It must not be
# executed directly — see the guard immediately below.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Resolve the default target env when no --env is given. Precedence:
#   1. the env declared `default = true`
#   2. `root` when declared (the canonical primary env in v3)
#   3. the sole declared env when exactly one exists
#   4. fail (status 1, no output) — caller surfaces a "specify --env" error
#
# Assumes manifest_load has already populated PYVE_ENV_NAMES. Private helper.
_package_default_env() {
    local name
    local -a all=()
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        all+=("$name")
        if manifest_is_default "$name"; then
            printf '%s' "$name"
            return 0
        fi
    done < <(manifest_list_envs 2>/dev/null)

    if manifest_get_env root; then
        printf '%s' "root"
        return 0
    fi

    if [[ "${#all[@]}" -eq 1 ]]; then
        printf '%s' "${all[0]}"
        return 0
    fi

    return 1
}

# pyve package [--env <name>] [-h|--help]
#
# Function-name note: named `package_environment` per the project-essentials
# "Function naming convention: verb_<operand>" rule — `pyve package`
# operates on an environment (materializes its packaging artifact). `package`
# is neither a bash builtin nor a binary pyve invokes, so no F-11 collision.
package_environment() {
    local env_target=""
    local env_explicit=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_package_help
                return 0
                ;;
            --env)
                env_target="${2:-}"
                env_explicit=1
                shift 2 || { log_error "pyve package: --env requires a value (a declared env name)"; exit 1; }
                ;;
            --env=*)
                env_target="${1#--env=}"
                env_explicit=1
                shift
                ;;
            *)
                log_error "pyve package: unexpected argument '$1'"
                show_package_help
                exit 1
                ;;
        esac
    done

    # Load the v3 manifest. Absent pyve.toml falls through to the empty /
    # v2 read-compat baseline (manifest_load handles both); resolution then
    # finds no envs and errors with a "specify --env" message.
    if [[ -f pyve.toml ]]; then
        manifest_load || exit 1
    fi

    # Resolve the target env. Reuses the same manifest default-env concept
    # `pyve test --env` keys off (the env marked `default = true`), but is
    # NOT purpose-gated — `pyve package` operates on any declared env.
    if [[ "$env_explicit" == "0" ]]; then
        if ! env_target="$(_package_default_env)"; then
            log_error "pyve package: no default env to package; specify one with --env <name>"
            exit 1
        fi
    fi

    if ! manifest_get_env "$env_target"; then
        log_error "pyve package: env '$env_target' is not declared in pyve.toml"
        local declared=""
        local choice
        while IFS= read -r choice; do
            [[ -n "$choice" ]] || continue
            declared="${declared:+$declared }$choice"
        done < <(manifest_list_envs 2>/dev/null)
        [[ -n "$declared" ]] && log_error "Declared envs: $declared"
        exit 1
    fi

    local pkg
    pkg="$(manifest_get_packaging "$env_target")"

    # No artifact declared (absent, or the explicit no-op value "none").
    if [[ -z "$pkg" || "$pkg" == "none" ]]; then
        info "env '$env_target' declares no packaging artifact."
        return 0
    fi

    # Provider registered? In v3.0 this is never true outside a test stub
    # (the registry ships empty). When a provider IS registered, dispatch
    # its `package` hook with the resolved env name — the provider reads
    # the env's packaging config (the `packaging` value + provider-private
    # keys like `dockerfile`) from the manifest itself.
    if packaging_provider_for "$pkg" >/dev/null; then
        pp_dispatch "$pkg" package "$env_target"
        return $?
    fi

    # Reserved-verb advisory (the v3.0 live path). Exit 0: the verb is
    # reserved + scaffolded, so a future provider drops in transparently.
    info "env '$env_target' declares packaging '$pkg'; no packaging provider is registered yet — reserved for a future release."
    return 0
}

show_package_help() {
    cat << 'EOF'
pyve package - Materialize an environment's packaging artifact

USAGE:
    pyve package [--env <name>]

DESCRIPTION:
    Builds the packaging artifact declared for an environment via its
    `packaging` attribute in pyve.toml (e.g. a container image). The target
    env is selected with --env <name>, or the default env when omitted.

    RESERVED IN v3.0: no packaging provider materializes yet. When an env
    declares a `packaging` value, `pyve package` prints a clean advisory
    and exits 0 — a packaging provider drops in transparently in a future
    release. `deploy` (shipping the artifact) is reserved separately.

OPTIONS:
    --env <name>    Target environment (default: the env marked
                    `default = true`, else `root`).
    -h, --help      Show this help.

CONFIG (pyve.toml):
    [env.<name>]
    packaging  = "container"     # artifact kind (read by pyve package)
    dockerfile = "Dockerfile"    # provider-private; stored, not interpreted

EXAMPLES:
    pyve package                 # package the default env
    pyve package --env web       # package the 'web' env
EOF
}
