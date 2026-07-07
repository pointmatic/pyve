#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Polyglot Python+Node fixture: independent hook firing.
#
# The canonical multi-plugin case (spike Example 4): a Python API at the
# project root and a SvelteKit frontend at src/frontend. Proves both
# plugins load (no S4 cardinality error — distinct paths) and that each
# plugin's hooks fire independently against their own paths: Node init /
# check / purge operate on src/frontend without leaking into the root,
# and the Python side is untouched. Hooks are driven directly (CLI
# routing across plugins is N-4).

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
    python_pyve_plugin_register_backends
    node_pyve_plugin_register_backends
    unset NVM_DIR FNM_DIR FNM_MULTISHELL_PATH VOLTA_HOME
    unset PYVE_NO_NVM_COMPAT PYVE_NO_FNM_COMPAT PYVE_NO_VOLTA_COMPAT PYVE_NO_ASDF_COMPAT
    mock_command node 0
    export PM_ARGS="$TEST_DIR/pm.args"
    : > "$PM_ARGS"
}

teardown() {
    unmock_command node 2>/dev/null || true
    unmock_command pnpm 2>/dev/null || true
    cleanup_test_dir
}

_stub_pm() {
    local pm="$1"
    eval "${pm}() {
        printf '%s\n' \"\$*\" >> \"\$PM_ARGS\"
        mkdir -p node_modules/.bin
        : > node_modules/.installed
        return 0
    }"
}

# Spike Example 4: Python API at root, SvelteKit frontend at src/frontend.
_build_polyglot_fixture() {
    cat > pyproject.toml <<'EOF'
[project]
name = "my-saas"
version = "0.1.0"
EOF
    mkdir -p src/my_saas src/frontend/src/routes
    : > src/my_saas/__main__.py
    cat > src/frontend/package.json <<'EOF'
{
  "name": "frontend",
  "private": true,
  "scripts": { "test": "vitest run" },
  "devDependencies": { "@sveltejs/kit": "^2.0.0" }
}
EOF
    cat > src/frontend/svelte.config.js <<'EOF'
export default {};
EOF
    : > src/frontend/src/routes/+page.svelte
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "my-saas"

[plugins.python]
path = "."

[plugins.node]
path = "src/frontend"

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.web]
purpose = "run"
backend = "pnpm"
path = "src/frontend"
frameworks = ["sveltekit"]
EOF
}

# ════════════════════════════════════════════════════════════════════
# Registry — both plugins load, no S4 cardinality error (distinct paths).
# ════════════════════════════════════════════════════════════════════

@test "registry: polyglot manifest loads python (root) and node (sub-path)" {
    _build_polyglot_fixture
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output")" == $'python\nnode' ]]
}

@test "registry: plugin paths resolve to root and the sub-path" {
    _build_polyglot_fixture
    manifest_load pyve.toml
    [ "$(manifest_get_plugin_path python)" = "." ]
    [ "$(manifest_get_plugin_path node)" = "src/frontend" ]
}

# ════════════════════════════════════════════════════════════════════
# Path-scoped detection — each plugin sees its own tree.
# ════════════════════════════════════════════════════════════════════

@test "detect: node signals fire at the sub-path, not at the root" {
    _build_polyglot_fixture
    [ "$(node_pyve_plugin_detect .)" = "none" ]
    [ "$(node_pyve_plugin_detect src/frontend)" = "node" ]
    [ "$(node_detect_framework src/frontend)" = "sveltekit" ]
}

@test "detect: python detection resolves at the root" {
    _build_polyglot_fixture
    [ "$(plugin_dispatch python detect)" = "venv" ]
}

# ════════════════════════════════════════════════════════════════════
# Independent hook firing — Node lifecycle confined to the sub-path.
# ════════════════════════════════════════════════════════════════════

@test "init: node provisions src/frontend/node_modules, never the root" {
    _build_polyglot_fixture
    manifest_load pyve.toml
    _stub_pm pnpm
    run node_pyve_plugin_init src/frontend pnpm
    [ "$status" -eq 0 ]
    [ -d src/frontend/node_modules ]
    [ ! -d node_modules ]
}

@test "check: node check operates on the sub-path and surfaces the framework" {
    _build_polyglot_fixture
    manifest_load pyve.toml
    _stub_pm pnpm
    node_pyve_plugin_init src/frontend pnpm
    run node_pyve_plugin_check src/frontend
    [ "$status" -eq 0 ]
    [[ "$output" == *"sveltekit"* ]]
}

@test "purge: node purge cleans the sub-path; root + Python side untouched" {
    _build_polyglot_fixture
    manifest_load pyve.toml
    _stub_pm pnpm
    node_pyve_plugin_init src/frontend pnpm
    [ -d src/frontend/node_modules ]
    run node_pyve_plugin_purge src/frontend
    [ "$status" -eq 0 ]
    [ ! -d src/frontend/node_modules ]
    [ -f src/frontend/package.json ]
    [ -f pyproject.toml ]
    [ -f src/my_saas/__main__.py ]
}
