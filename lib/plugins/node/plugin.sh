# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/node/plugin.sh — Node plugin (Story N.t)
#
# Second reference implementation of the plugin contract from N.k,
# and the first non-Python ecosystem. N-3 proves the contract
# generalizes beyond Python: every design hole surfaces when a
# non-Python plugin is implemented against the same hook signatures.
#
# Deliberately mirrors the shape of lib/plugins/python/plugin.sh (N.n)
# so reviewers can diff the two side-by-side and see contract symmetry.
#
# N.t ships only:
#   node_pyve_plugin_manifest_namespace   — returns "node"
#   node_pyve_plugin_register_backends    — no-op stub (providers in N.u)
#   node_pyve_plugin_detect               — scaffold-time file-signal scan
#
# Everything else falls back to the no-op defaults in contract.sh:
#   - backend-providers (pnpm / npm / yarn)        → N.u
#   - runtime-resolution (nvm / fnm / volta + PATH) → N.v
#   - lifecycle (init / purge / update)             → N.w
#   - check / status / run / test                   → N.x
#   - activation (.envrc node_modules/.bin PATH_add)→ N.y
#   - .gitignore + smart-purge                      → N.z
#   - SvelteKit detection + frameworks attribute    → N.aa
#
# Detection contract (per Story N.t task list):
#   Signal: package.json present at the plugin's path (default ".").
#   Output:
#     - present → "node"
#     - absent  → "none"
#
# Detection only answers "is this a Node project?" — provider selection
# (pnpm/npm/yarn from lockfile) is N.u's job. Per the spike, detection
# is scaffold-time only: once `pyve.toml` declares [plugins.node], the
# manifest is the runtime source of truth.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Plugin contract — manifest_namespace
#------------------------------------------------------------

node_pyve_plugin_manifest_namespace() {
    printf 'node'
}

#------------------------------------------------------------
# Plugin contract — register_backends (no-op stub in N.t)
#
# The three project-virtualized backend-providers (pnpm / npm / yarn)
# register here in Story N.u via bp_register. The stub keeps the hook
# signature present from N.t so N.u has an obvious insertion point and
# the Node plugin's shape matches the Python plugin's from day one.
#------------------------------------------------------------

node_pyve_plugin_register_backends() {
    : # providers land in N.u
}

#------------------------------------------------------------
# Plugin contract — detect (scaffold-time only)
#
# Path-aware from the start (N-3 insight #5): the optional first arg is
# the plugin's path (default "."). The monorepo case (Node at a sub-path
# while Python owns the root) is tested in N.ab; probing the path here
# means that composition work has a working detection primitive.
#------------------------------------------------------------

node_pyve_plugin_detect() {
    local path="${1:-.}"
    if [[ -f "${path}/package.json" ]]; then
        printf 'node'
    else
        printf 'none'
    fi
}
