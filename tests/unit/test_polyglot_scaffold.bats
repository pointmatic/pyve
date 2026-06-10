#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Polyglot `pyve init` scaffold (closes the N-3 root-collision
# hole). N.t deferred the resolution by making Node detection advisory-only
# (it surfaced "I see a Node project" but never mutated `pyve.toml`). N.ad
# lands the real scaffold: when both Python and Node fire at root, walk the
# Node sub-path conventions, prompt or inform the user, then write explicit
# `[plugins.python]` (root) + `[plugins.node]` (sub-path) blocks into the
# generated `pyve.toml`.
#
# Helpers under test (in lib/plugins/python/plugin.sh, where init_project
# was relocated by N.s):
#   - _init_write_pyve_toml_polyglot <project_name> <node_path>
#   - _init_resolve_node_path <flag> <interactive>
#   - _init_scaffold_manifest <project_name> <node_path_flag>

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # Pin the TOML helper's interpreter so manifest_load doesn't hit an
    # asdf shim with no version set in the bats temp dir (mirrors N.t).
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# _init_write_pyve_toml_polyglot — the polyglot manifest emitter.
#
# Per S3: no `role` field. Per S4: Python alone at root (no `path` line in
# [plugins.python]; it defaults to "."), Node at a distinct sub-path.
# ════════════════════════════════════════════════════════════════════

@test "polyglot writer: creates pyve.toml in cwd" {
    run _init_write_pyve_toml_polyglot "demo" "src/frontend"
    [ "$status" -eq 0 ]
    [ -f pyve.toml ]
}

@test "polyglot writer: emits [plugins.python] with NO path line (defaults to .)" {
    _init_write_pyve_toml_polyglot "demo" "src/frontend"
    grep -qE '^\[plugins\.python\]$' pyve.toml
    # No `path = ...` line inside the [plugins.python] section.
    run awk '/^\[plugins\.python\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml
    [[ "$output" != *"path ="* ]]
}

@test "polyglot writer: emits [plugins.node] with path = chosen sub-path" {
    _init_write_pyve_toml_polyglot "demo" "src/frontend"
    grep -qE '^\[plugins\.node\]$' pyve.toml
    awk '/^\[plugins\.node\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^path = "src/frontend"$'
}

@test "polyglot writer: emits no role field (S3)" {
    _init_write_pyve_toml_polyglot "demo" "web"
    ! grep -qE '^role' pyve.toml
}

@test "polyglot writer: keeps the two Python env blocks (root + testenv)" {
    _init_write_pyve_toml_polyglot "demo" "web"
    grep -qE '^\[env\.root\]$' pyve.toml
    grep -qE '^\[env\.testenv\]$' pyve.toml
}

@test "polyglot writer: output validates clean + loads both plugins" {
    _init_write_pyve_toml_polyglot "demo" "src/frontend"
    manifest_load "$(pwd)/pyve.toml"
    [ "$PYVE_PROJECT_NAME" = "demo" ]
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output")" == $'python\nnode' ]]
}

@test "polyglot writer: node plugin path resolves to the chosen sub-path" {
    _init_write_pyve_toml_polyglot "demo" "frontend"
    manifest_load "$(pwd)/pyve.toml"
    # PYVE_PLUGIN_NAMES / PYVE_PLUGIN_PATHS are positional parallel arrays.
    local i node_path=""
    for i in "${!PYVE_PLUGIN_NAMES[@]}"; do
        if [[ "${PYVE_PLUGIN_NAMES[$i]}" == "node" ]]; then
            node_path="${PYVE_PLUGIN_PATHS[$i]}"
        fi
    done
    [ "$node_path" = "frontend" ]
}

@test "polyglot writer: refuses to overwrite an existing pyve.toml" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "preexisting"
EOF
    _init_write_pyve_toml_polyglot "newname" "web"
    grep -q 'preexisting' pyve.toml
    ! grep -q 'plugins.node' pyve.toml
}

# ════════════════════════════════════════════════════════════════════
# _init_resolve_node_path — convention walk + branch logic.
#
# Contract: resolved path on stdout (and ONLY the path); branch messages
# and prompts on stderr. The flag (arg 1) overrides everything; arg 2 is
# "true"/"false" for whether prompting is allowed.
#
# Convention order: src/frontend, frontend, web, client, ui.
# ════════════════════════════════════════════════════════════════════

@test "resolve: --node-path flag overrides all detection" {
    mkdir -p frontend web   # conventions exist, but the flag wins
    run --separate-stderr _init_resolve_node_path "packages/app" "false"
    [ "$status" -eq 0 ]
    [ "$output" = "packages/app" ]
}

@test "resolve: 0 conventions, non-interactive → src/frontend default" {
    run --separate-stderr _init_resolve_node_path "" "false"
    [ "$status" -eq 0 ]
    [ "$output" = "src/frontend" ]
}

@test "resolve: 0 conventions, interactive, typed path → uses typed" {
    run --separate-stderr _init_resolve_node_path "" "true" <<< "apps/web"
    [ "$status" -eq 0 ]
    [ "$output" = "apps/web" ]
    [[ "$stderr" == *"where should it live"* ]]
}

@test "resolve: 0 conventions, interactive, empty input → src/frontend default" {
    run --separate-stderr _init_resolve_node_path "" "true" <<< ""
    [ "$status" -eq 0 ]
    [ "$output" = "src/frontend" ]
}

@test "resolve: exactly 1 convention → uses it + 'only convention matched' note" {
    mkdir -p web
    run --separate-stderr _init_resolve_node_path "" "false"
    [ "$status" -eq 0 ]
    [ "$output" = "web" ]
    [[ "$stderr" == *"only convention matched"* ]]
}

@test "resolve: 2+ conventions, non-interactive → first match by precedence" {
    mkdir -p web frontend     # frontend precedes web in the convention list
    run --separate-stderr _init_resolve_node_path "" "false"
    [ "$status" -eq 0 ]
    [ "$output" = "frontend" ]
}

@test "resolve: 2+ conventions, interactive, typed custom → uses typed" {
    mkdir -p frontend web
    run --separate-stderr _init_resolve_node_path "" "true" <<< "custom/place"
    [ "$status" -eq 0 ]
    [ "$output" = "custom/place" ]
    [[ "$stderr" == *"Multiple Node sub-path conventions found"* ]]
}

@test "resolve: 2+ conventions, interactive, empty input → first match" {
    mkdir -p frontend web
    run --separate-stderr _init_resolve_node_path "" "true" <<< ""
    [ "$status" -eq 0 ]
    [ "$output" = "frontend" ]
}

# ════════════════════════════════════════════════════════════════════
# _init_scaffold_manifest — orchestrator wiring detection + writer.
# ════════════════════════════════════════════════════════════════════

@test "scaffold: pure-Python project → plain manifest (no plugins blocks)" {
    : > pyproject.toml
    run _init_scaffold_manifest "demo" ""
    [ "$status" -eq 0 ]
    [ -f pyve.toml ]
    ! grep -q '\[plugins' pyve.toml
}

@test "scaffold: Python + Node at root → polyglot manifest written" {
    : > pyproject.toml
    : > package.json
    run _init_scaffold_manifest "demo" ""
    [ "$status" -eq 0 ]
    grep -qE '^\[plugins\.python\]$' pyve.toml
    grep -qE '^\[plugins\.node\]$' pyve.toml
    # Non-interactive (no TTY in bats) + no conventions → default src/frontend.
    awk '/^\[plugins\.node\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^path = "src/frontend"$'
}

@test "scaffold: Python + Node, --node-path flag honored" {
    : > pyproject.toml
    : > package.json
    run _init_scaffold_manifest "demo" "packages/ui"
    [ "$status" -eq 0 ]
    awk '/^\[plugins\.node\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^path = "packages/ui"$'
}

@test "scaffold: Python + Node, existing convention dir → used + informational message" {
    : > pyproject.toml
    : > package.json
    mkdir -p client
    run _init_scaffold_manifest "demo" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"only convention matched"* ]]
    awk '/^\[plugins\.node\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^path = "client"$'
}

@test "scaffold: always prints the chosen Node sub-path" {
    : > pyproject.toml
    : > package.json
    run _init_scaffold_manifest "demo" "apps/site"
    [ "$status" -eq 0 ]
    [[ "$output" == *"apps/site"* ]]
}

@test "scaffold: idempotent — existing pyve.toml is a no-op" {
    : > pyproject.toml
    : > package.json
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "already-here"
EOF
    local before
    before="$(cat pyve.toml)"
    run _init_scaffold_manifest "demo" ""
    [ "$status" -eq 0 ]
    [ "$(cat pyve.toml)" = "$before" ]
}

@test "scaffold: polyglot manifest validates clean + loads both plugins" {
    : > pyproject.toml
    : > package.json
    _init_scaffold_manifest "demo" "src/frontend"
    manifest_load "$(pwd)/pyve.toml"
    plugin_load_all_from_manifest
    run plugin_list_active
    [[ "$(printf '%s' "$output")" == $'python\nnode' ]]
}

@test "scaffold: SvelteKit project surfaces a frameworks hint" {
    : > pyproject.toml
    : > package.json
    : > svelte.config.js
    run _init_scaffold_manifest "demo" "src/frontend"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SvelteKit"* ]]
    [[ "$output" == *"sveltekit"* ]]
}
