# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/packaging_registry.sh — packaging-provider registry
#
# Parallel to lib/plugins/backend_registry.sh, but for the artifact-
# materialization side: `pyve package` dispatches to a
# packaging provider keyed by an env's `packaging` value (e.g. "docker",
# "lock_bundle", "binary"). A provider materializes the env's declared
# packaging artifact via its `package` hook.
#
# v3.0 registers ZERO providers (concept Q6 / v3.0-window decision:
# reserve the verb + scaffold the contract, materialize nothing). The
# first provider lands post-v3.0 with no breaking change; `pyve package`
# emits a clean advisory when no provider is registered for the declared
# value.
#
# This registry is simpler than the backend registry: packaging providers
# carry no category abstraction (the three-category split — virtualized /
# cache-backed / check-only — is an env-materialization concern, not an
# artifact-materialization one). A packaging value maps directly to an
# owning provider.
#
# Closed-set *validation* of the `packaging` vocabulary (hard-error on
# unknown) is F6 in Subphase N-6, not here — N-5 reads leniently.
#
# Dispatch convention: `pp_dispatch <value> <hook> [args...]` calls
# `<value>_pyve_pp_<hook>` if defined; else returns 0 silently (the
# provider contributes nothing for that hook).
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Parallel indexed arrays — registration record (packaging value, owning
# plugin) stored at the same index. Bash 3.2-safe (no associative arrays).
PYVE_PP_NAMES=()
PYVE_PP_PLUGINS=()

pp_registry_reset() {
    PYVE_PP_NAMES=()
    PYVE_PP_PLUGINS=()
}

# Private: index lookup. Print 0-based index of <value> in PYVE_PP_NAMES,
# or return 1 (no output) if absent.
_pp_name_to_index() {
    local target="$1" i
    [[ -n "${PYVE_PP_NAMES+x}" ]] || return 1
    for ((i=0; i<${#PYVE_PP_NAMES[@]}; i++)); do
        if [[ "${PYVE_PP_NAMES[$i]}" == "$target" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

# Register a packaging provider. Idempotent on identical re-registration;
# errors on conflicting re-registration (a different plugin claiming the
# same packaging value).
#
# Usage: pp_register <plugin> <packaging_value>
pp_register() {
    local plugin="$1"
    local name="$2"

    local idx
    if idx="$(_pp_name_to_index "$name")"; then
        # Idempotent: same plugin → no-op.
        if [[ "${PYVE_PP_PLUGINS[$idx]}" == "$plugin" ]]; then
            return 0
        fi
        printf "error: pp_register: packaging value '%s' already registered to plugin '%s'; cannot re-register as plugin '%s'\n" \
            "$name" "${PYVE_PP_PLUGINS[$idx]}" "$plugin" >&2
        return 1
    fi

    PYVE_PP_NAMES+=("$name")
    PYVE_PP_PLUGINS+=("$plugin")
    return 0
}

# Print the plugin owning <packaging_value>. Returns 1 (no output) when
# no provider is registered for the value — the v3.0 baseline for every
# value, since no providers ship. `pyve package` keys its advisory off
# this: empty/non-zero → "reserved for a future release".
packaging_provider_for() {
    local idx
    idx="$(_pp_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_PP_PLUGINS[$idx]}"
}

# Print all registered packaging values, one per line, in registration
# order. Empty in v3.0 (zero providers).
pp_list() {
    local n
    for n in "${PYVE_PP_NAMES[@]+"${PYVE_PP_NAMES[@]}"}"; do
        printf '%s\n' "$n"
    done
}

# Dispatch a hook for <packaging_value>. Lookup order:
#   1. <value>_pyve_pp_<hook>  — provider-specific impl
#   2. silent return 0          — provider contributes nothing for this hook
#
# Args after the hook name are forwarded. Errors on an unregistered value.
pp_dispatch() {
    local name="$1"
    local hook="$2"
    shift 2

    if ! _pp_name_to_index "$name" >/dev/null; then
        printf "error: pp_dispatch: packaging provider '%s' is not registered\n" "$name" >&2
        return 1
    fi

    local specific="${name}_pyve_pp_${hook}"
    if declare -F "$specific" >/dev/null 2>&1; then
        "$specific" "$@"
        return $?
    fi

    return 0
}
