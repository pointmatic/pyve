# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/registry.sh — plugin registry + dispatcher
#
# Maintains the list of active plugins for the current pyve invocation
# and dispatches hook calls. Activation source is `[plugins.*]` blocks
# in pyve.toml, surfaced by lib/manifest.sh's `manifest_list_plugins` /
# `manifest_get_plugin_path` accessors.
#
# Two activation paths:
#
#   1. Explicit — `pyve.toml` declares `[plugins.<name>]`. Each declared
#      plugin is registered in declaration order.
#   2. Implicit-Python (spike S5) — `pyve.toml` declares no plugins, so
#      the registry treats Python as the implicit project plugin at
#      `path = "."`. This is the migration shape for every v2-vintage
#      project (pure Python; no need to write `[plugins.python]`).
#
# Cardinality validation (spike S4): at most one plugin may resolve to
# `path = "."`. Two plugins both claiming the project root is a manifest
# error. The check is enforced at load time, after explicit declarations
# are registered and the implicit-Python rule is applied.
#
# Dispatch convention: `plugin_dispatch <name> <hook> [args...]` calls
# the function `<name>_pyve_plugin_<hook>` if defined; otherwise falls
# back to `pyve_plugin_default_<hook>` (lib/plugins/contract.sh).
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Internal state — declared, but `bash 3.2` -safe under `set -u`: tests
# reset before each case via plugin_registry_reset.
PYVE_PLUGIN_REGISTERED=()

# Reset the registry. Used by tests; not called from production code.
plugin_registry_reset() {
    PYVE_PLUGIN_REGISTERED=()
}

# Register <name> as an active plugin. Idempotent: a name already in
# the active list is not appended a second time.
plugin_register() {
    local name="$1"
    local existing
    for existing in "${PYVE_PLUGIN_REGISTERED[@]+"${PYVE_PLUGIN_REGISTERED[@]}"}"; do
        [[ "$existing" == "$name" ]] && return 0
    done
    PYVE_PLUGIN_REGISTERED+=("$name")
}

# Print active plugin names, one per line, in registration order.
plugin_list_active() {
    local n
    for n in "${PYVE_PLUGIN_REGISTERED[@]+"${PYVE_PLUGIN_REGISTERED[@]}"}"; do
        printf '%s\n' "$n"
    done
}

# Read the manifest's [plugins.*] declarations and register each. When
# none are declared, register Python implicitly (S5). Then enforce the
# path = "." cardinality check (S4).
#
# Assumes `manifest_load` has already populated PYVE_PLUGIN_NAMES /
# PYVE_PLUGIN_PATHS — pyve.sh sources lib/manifest.sh before this file
# and the main() dispatcher calls manifest_load early.
plugin_load_all_from_manifest() {
    local declared=()
    if [[ -n "${PYVE_PLUGIN_NAMES+x}" ]] && [[ ${#PYVE_PLUGIN_NAMES[@]} -gt 0 ]]; then
        declared=("${PYVE_PLUGIN_NAMES[@]}")
    fi

    if [[ ${#declared[@]} -eq 0 ]]; then
        # Implicit-Python rule (S5).
        plugin_register python
    else
        local n
        for n in "${declared[@]}"; do
            plugin_register "$n"
        done
    fi

    # Cardinality check (S4): at most one plugin owns `path = "."`.
    # Implicit-Python is treated as path = "."; explicit plugins use
    # their declared path (default "." per the schema).
    local root_owners=()
    local p path
    for p in "${PYVE_PLUGIN_REGISTERED[@]}"; do
        if [[ ${#declared[@]} -eq 0 ]]; then
            # Implicit-Python — by definition at path = "."
            path="."
        else
            path="$(manifest_get_plugin_path "$p" 2>/dev/null || printf '.')"
            [[ -z "$path" ]] && path="."
        fi
        if [[ "$path" == "." ]]; then
            root_owners+=("$p")
        fi
    done

    if [[ ${#root_owners[@]} -gt 1 ]]; then
        printf "error: multiple plugins both claim the project root (path = \".\"): %s\n" "${root_owners[*]}" >&2
        printf "       at most one plugin may own the project root (spike decision S4).\n" >&2
        return 1
    fi

    return 0
}

# Build the parameter decision-graph from the framework-owned top nodes plus
# every active plugin's contributed subtree. The framework owns the cross-cutting
# differentiators (language / project-guide / direnv — pg_register_framework_nodes
# in lib/param_graph.sh); each active plugin contributes its own language subtree
# through the `register_params` hook (Python: backend → version-manager →
# python-version → test-env; Node: provider → runtime-manager). The graph is thus
# no longer Python-hardcoded — language-based applicability prunes a subtree when
# its language is not selected, and a polyglot `multiple` selection keeps every
# active subtree.
#
# Mirrors pg_build_graph but sources contributors from the active-plugin list
# (the contract) rather than the manual pg_register_contributor list. Resets the
# node table + answers; assumes plugin_load_all_from_manifest already populated
# the active set.
plugin_build_param_graph() {
    # shellcheck disable=SC2034  # both are read by the param_graph.sh walk (cross-file; defined there)
    PYVE_PARAM_NODES=()
    # shellcheck disable=SC2034  # see above — the answers accumulator lives in param_graph.sh
    PYVE_PARAM_ANSWERS=" "
    pg_register_framework_nodes
    local p
    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        plugin_dispatch "$p" register_params
    done <<<"$(plugin_list_active)"
}

# Dispatch a hook to the plugin. Prefers <name>_pyve_plugin_<hook>;
# falls back to pyve_plugin_default_<hook>. Args after the hook name
# are forwarded.
plugin_dispatch() {
    local name="$1"
    local hook="$2"
    shift 2
    local fn="${name}_pyve_plugin_${hook}"
    if declare -F "$fn" >/dev/null 2>&1; then
        "$fn" "$@"
        return $?
    fi
    "pyve_plugin_default_${hook}" "$@"
}
