#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Plugin contract — parameter/wizard contribution hook (Story P.h).
#
# The framework owns the top differentiators (language / project-guide /
# direnv); each language plugin contributes its own decision-graph subtree via
# the `register_params` contract hook (Python: backend → version-manager →
# python-version → test-env; Node: provider → runtime-manager). The graph is no
# longer Python-hardcoded: `plugin_build_param_graph` composes the framework
# nodes with every active plugin's contributed subtree, and language-based
# applicability prunes a subtree when its language is not selected — a polyglot
# `multiple` selection keeps every active subtree.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/param_graph.sh"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    create_test_dir
    : "${DEFAULT_PYTHON_VERSION:=3.14.6}"
    pg_reset
    plugin_registry_reset
    bp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# The contract hook — default no-op, dispatched like every other hook
# ────────────────────────────────────────────────────────────────────

@test "contract: register_params has a silent no-op default" {
    declare -F pyve_plugin_default_register_params >/dev/null
    run pyve_plugin_default_register_params
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "dispatch: an unknown plugin's register_params falls back to the no-op" {
    pg_reset
    run plugin_dispatch nope register_params
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run pg_node_count
    [ "$output" -eq 0 ]
}

# ────────────────────────────────────────────────────────────────────
# Python plugin contributes its subtree (and only its subtree)
# ────────────────────────────────────────────────────────────────────

@test "python plugin: register_params contributes backend → version-manager → python-version → test-env" {
    declare -F python_pyve_plugin_register_params >/dev/null
    pg_reset
    python_pyve_plugin_register_params
    run pg_list_nodes
    [[ "$output" == *"backend|python"* ]]
    [[ "$output" == *"version-manager|python"* ]]
    [[ "$output" == *"python-version|python"* ]]
    [[ "$output" == *"test-env|python"* ]]
}

@test "python plugin: contributed nodes are owned by 'python', not framework" {
    pg_reset
    python_pyve_plugin_register_params
    run pg_list_nodes
    # no python-contributed row may claim framework ownership
    [[ "$output" != *"backend|framework"* ]]
}

# ────────────────────────────────────────────────────────────────────
# Node plugin contributes its subtree
# ────────────────────────────────────────────────────────────────────

@test "node plugin: register_params contributes provider → runtime-manager" {
    declare -F node_pyve_plugin_register_params >/dev/null
    pg_reset
    node_pyve_plugin_register_params
    run pg_list_nodes
    [[ "$output" == *"provider|node"* ]]
    [[ "$output" == *"runtime-manager|node"* ]]
}

# ────────────────────────────────────────────────────────────────────
# Framework stays plugin-agnostic — no plugin vocabulary leaks up
# ────────────────────────────────────────────────────────────────────

@test "framework nodes name no plugin-specific backend/provider vocabulary" {
    pg_reset
    pg_register_framework_nodes
    run pg_list_nodes
    [[ "$output" != *venv* ]]
    [[ "$output" != *micromamba* ]]
    [[ "$output" != *pnpm* ]]
    [[ "$output" != *asdf* ]]
}

# ────────────────────────────────────────────────────────────────────
# Assembly — framework nodes + every ACTIVE plugin's subtree
# ────────────────────────────────────────────────────────────────────

@test "plugin_build_param_graph: framework nodes precede contributed subtrees" {
    plugin_register python
    plugin_build_param_graph
    run pg_list_nodes
    local lang_line backend_line
    lang_line=$(printf '%s\n' "$output" | grep -n '^language|' | cut -d: -f1)
    backend_line=$(printf '%s\n' "$output" | grep -n '^backend|' | cut -d: -f1)
    [ "$lang_line" -lt "$backend_line" ]
}

@test "plugin_build_param_graph: only active plugins contribute their subtree" {
    plugin_register python
    plugin_build_param_graph
    run pg_list_nodes
    [[ "$output" == *"backend|python"* ]]
    [[ "$output" != *"provider|node"* ]]   # node not active → absent
}

@test "plugin_build_param_graph: a polyglot project registers both subtrees" {
    plugin_register python
    plugin_register node
    plugin_build_param_graph
    run pg_list_nodes
    [[ "$output" == *"backend|python"* ]]
    [[ "$output" == *"provider|node"* ]]
}

# ────────────────────────────────────────────────────────────────────
# Walk-time pruning — the actual story acceptance
# ────────────────────────────────────────────────────────────────────

@test "single-stack: language=python keeps the Python subtree and prunes Node" {
    plugin_register python
    plugin_register node
    plugin_build_param_graph
    pg_resolve_with_flags --language python
    [ "$(pg_answer_get backend)" != "" ]   # python subtree applied
    [ "$(pg_answer_get provider)" = "" ]   # node subtree pruned
}

@test "single-stack: language=node keeps the Node subtree and prunes Python" {
    plugin_register python
    plugin_register node
    plugin_build_param_graph
    pg_resolve_with_flags --language node
    [ "$(pg_answer_get provider)" != "" ]  # node subtree applied
    [ "$(pg_answer_get backend)" = "" ]    # python subtree pruned
}

@test "polyglot: language=multiple resolves BOTH subtrees" {
    plugin_register python
    plugin_register node
    plugin_build_param_graph
    pg_resolve_with_flags --language multiple
    [ "$(pg_answer_get backend)" != "" ]
    [ "$(pg_answer_get provider)" != "" ]
}
