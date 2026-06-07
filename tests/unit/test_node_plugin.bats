#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.t — Node plugin module + scaffold-time detection hook.
#
# First story of Subphase N-3 (Node/SvelteKit second reference plugin).
# Stands up lib/plugins/node/plugin.sh against the N.k contract, mirroring
# the Python plugin's shape (N.n) so the two diff side-by-side. N.t ships
# only the manifest_namespace + detect hooks plus a register_backends
# no-op stub; the backend-providers (pnpm/npm/yarn) land in N.u and the
# lifecycle hooks land in N.w-N.z. Detection is scaffold-time only: once
# `pyve.toml` declares [plugins.node], the manifest is the runtime source
# of truth.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # Pin the TOML helper's interpreter so manifest_load doesn't hit an
    # asdf shim with no version set in the bats temp dir (mirrors N.k).
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Plugin contract — manifest namespace
# ════════════════════════════════════════════════════════════════════

@test "node plugin: manifest_namespace returns 'node'" {
    run node_pyve_plugin_manifest_namespace
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
}

# ════════════════════════════════════════════════════════════════════
# Plugin contract — register_backends hook is present.
#
# N.t introduced this as a no-op stub; N.u filled it with the pnpm /
# npm / yarn providers. The provider-registration behavior is owned by
# tests/unit/test_node_backend_providers.bats; here we only assert
# the hook exists so the plugin's contract shape is complete.
# ════════════════════════════════════════════════════════════════════

@test "node plugin: register_backends is defined" {
    declare -F node_pyve_plugin_register_backends >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# Plugin contract — detect hook (scaffold-time only).
#
# Output:
#   - package.json present at the plugin's path → "node" (positive)
#   - absent                                    → "none" (negative)
#
# Provider selection (pnpm/npm/yarn from lockfile) is N.u's job — detect
# only answers "is this a Node project?".
# ════════════════════════════════════════════════════════════════════

@test "detect: package.json → node" {
    : > package.json
    run node_pyve_plugin_detect
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
}

@test "detect: empty directory → none" {
    run node_pyve_plugin_detect
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

@test "detect: only non-Node files (pyproject.toml) → none" {
    : > pyproject.toml
    : > README.md
    run node_pyve_plugin_detect
    [ "$output" = "none" ]
}

# ── Path-awareness (N-3 insight #5: path-aware from the start) ──

@test "detect: package.json under an explicit sub-path → node" {
    mkdir -p src/frontend
    : > src/frontend/package.json
    run node_pyve_plugin_detect src/frontend
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
}

@test "detect: no package.json at the given sub-path → none" {
    mkdir -p src/frontend
    run node_pyve_plugin_detect src/frontend
    [ "$output" = "none" ]
}

@test "detect: package.json at root is not found when probing a sub-path" {
    : > package.json
    mkdir -p src/frontend
    run node_pyve_plugin_detect src/frontend
    [ "$output" = "none" ]
}

# ════════════════════════════════════════════════════════════════════
# End-to-end: plugin_dispatch node detect routes correctly.
# ════════════════════════════════════════════════════════════════════

@test "plugin_dispatch node detect: routes to node_pyve_plugin_detect" {
    plugin_register node
    : > package.json
    run plugin_dispatch node detect
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
}

# ════════════════════════════════════════════════════════════════════
# Registry: Node loads when explicitly declared; never loads implicitly
# in a pure-Python project (the implicit-plugin rule from N.k covers
# Python only — never Node).
# ════════════════════════════════════════════════════════════════════

@test "registry: node loads when explicitly declared in [plugins.node]" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.node]
path = "frontend"
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
}

@test "registry: pure-Python project (no [plugins.*]) does NOT load node implicitly" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    # Implicit-Python only (S5); node is absent.
    [ "$output" = "python" ]
}

@test "registry: polyglot manifest loads both python (root) and node (sub-path)" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.python]
path = "."
[plugins.node]
path = "src/frontend"
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output")" == $'python\nnode' ]]
}

# ════════════════════════════════════════════════════════════════════
# Task 4 — scaffold-time Node consult.
#
# N.t shipped this as advisory-only (`_init_maybe_advise_node_plugin`
# surfaced a note but never mutated `pyve.toml`), deferring the real
# polyglot scaffold to Subphase N-4. **Story N.ad superseded that helper**
# with `_init_scaffold_manifest`, which now writes a polyglot manifest
# (`[plugins.python]` + `[plugins.node]`) when Node is detected at root.
# The behavior is owned by tests/unit/test_polyglot_scaffold.bats; the
# advisory-only tests that lived here were removed when N.ad landed.
# ════════════════════════════════════════════════════════════════════
