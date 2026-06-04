#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.aa — SvelteKit detection + frameworks attribute support.
#
# Layers SvelteKit detection onto the Node plugin (sibling helper
# node_detect_framework — keeps node_pyve_plugin_detect's node/none
# contract intact), surfaces the S11 `frameworks` attribute advisory-only
# in check/status (via manifest_get_frameworks, which already exists), and
# extends the scaffold-time Node advisory with a SvelteKit hint. No
# behavior change beyond detection in v3.0.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    node_pyve_plugin_register_backends
    unset NVM_DIR FNM_DIR FNM_MULTISHELL_PATH VOLTA_HOME
    mock_command node 0
}

teardown() {
    unmock_command node 2>/dev/null || true
    cleanup_test_dir
}

_provision() {
    local dir="$1"
    mkdir -p "$dir/node_modules/somepkg"
    : > "$dir/package.json"
}

_write_manifest() {
    cat > pyve.toml <<EOF
pyve_schema = "3.0"
[project]
name = "demo"
$1
EOF
}

# ════════════════════════════════════════════════════════════════════
# node_detect_framework — sveltekit signal.
# ════════════════════════════════════════════════════════════════════

@test "detect_framework: svelte.config.js → sveltekit" {
    : > package.json
    : > svelte.config.js
    run node_detect_framework
    [ "$status" -eq 0 ]
    [ "$output" = "sveltekit" ]
}

@test "detect_framework: svelte.config.mjs variant → sveltekit" {
    : > package.json
    : > svelte.config.mjs
    run node_detect_framework
    [ "$output" = "sveltekit" ]
}

@test "detect_framework: @sveltejs/kit in package.json → sveltekit" {
    cat > package.json <<'EOF'
{ "name": "app", "devDependencies": { "@sveltejs/kit": "^2.0.0" } }
EOF
    run node_detect_framework
    [ "$output" = "sveltekit" ]
}

@test "detect_framework: pure Node project (no svelte signal) → none" {
    : > package.json
    : > index.js
    run node_detect_framework
    [ "$output" = "none" ]
}

@test "detect_framework: no package.json → none" {
    : > svelte.config.js
    run node_detect_framework
    [ "$output" = "none" ]
}

@test "detect_framework: path-aware (sub-path fixture)" {
    mkdir -p src/frontend
    : > src/frontend/package.json
    : > src/frontend/svelte.config.js
    run node_detect_framework src/frontend
    [ "$output" = "sveltekit" ]
}

# ════════════════════════════════════════════════════════════════════
# check / status surface the manifest `frameworks` attribute (advisory).
# ════════════════════════════════════════════════════════════════════

@test "check: surfaces a declared frameworks attribute" {
    _provision "$TEST_DIR/proj"
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
frameworks = ["sveltekit"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sveltekit"* ]]
}

@test "status: surfaces a declared frameworks attribute" {
    _provision "$TEST_DIR/proj"
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
frameworks = ["sveltekit"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_status "$TEST_DIR/proj" pnpm
    [[ "$output" == *"sveltekit"* ]]
}

@test "check: no framework line when none declared" {
    _provision "$TEST_DIR/proj"
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
'
    manifest_load pyve.toml
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [[ "$output" != *"frameworks"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Scaffold-time advisory extension (the Node consult from N.t).
# ════════════════════════════════════════════════════════════════════

@test "advise: SvelteKit project adds a frameworks hint to the Node advisory" {
    : > package.json
    : > svelte.config.js
    run _init_maybe_advise_node_plugin
    [ "$status" -eq 0 ]
    [[ "$output" == *"Node project detected"* ]]
    [[ "$output" == *"SvelteKit"* ]]
    [[ "$output" == *"sveltekit"* ]]
}

@test "advise: pure-Node project gets no SvelteKit hint" {
    : > package.json
    run _init_maybe_advise_node_plugin
    [ "$status" -eq 0 ]
    [[ "$output" == *"Node project detected"* ]]
    [[ "$output" != *"SvelteKit"* ]]
}
