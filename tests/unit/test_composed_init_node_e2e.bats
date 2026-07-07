#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Node-at-root fixture: hook-level lifecycle drive.
#
# Contract-generalization proof (N-3), hook level: stand up a realistic
# pure-Node SvelteKit fixture and drive the WHOLE Node hook lifecycle
# directly — detect → framework-detect → init → check → test → activate
# → purge — asserting each step composes. The Node hooks are not yet
# CLI-routed (that's N-4); here we dispatch them directly.
#
# The full lifecycle uses a deterministic package-manager stub (so it is
# hermetic and covers the SvelteKit-with-deps shape); a separate guarded
# test exercises a real `npm` on a zero-dependency project (offline-safe,
# mirroring N.w's integration test).

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
    unset PYVE_NO_NVM_COMPAT PYVE_NO_FNM_COMPAT PYVE_NO_VOLTA_COMPAT PYVE_NO_ASDF_COMPAT
    mock_command node 0
    export PM_ARGS="$TEST_DIR/pm.args"
    : > "$PM_ARGS"
}

teardown() {
    unmock_command node 2>/dev/null || true
    unmock_command pnpm 2>/dev/null || true
    unmock_command npm 2>/dev/null || true
    cleanup_test_dir
}

# A package-manager stub that records its args AND simulates a real
# install by creating a NON-empty node_modules (so `check` sees it
# provisioned) plus a node_modules/.bin (so activation has a real dir).
_stub_pm() {
    local pm="$1"
    eval "${pm}() {
        printf '%s\n' \"\$*\" >> \"\$PM_ARGS\"
        mkdir -p node_modules/.bin
        : > node_modules/.installed
        return 0
    }"
}

# Build a realistic SvelteKit project in the cwd, with pyve.toml declaring
# [plugins.node] at the root and an [env.web] carrying the S11 attributes.
_build_sveltekit_fixture() {
    cat > package.json <<'EOF'
{
  "name": "my-sveltekit-app",
  "version": "0.0.1",
  "private": true,
  "scripts": { "dev": "vite dev", "build": "vite build", "test": "vitest run" },
  "devDependencies": {
    "@sveltejs/kit": "^2.0.0",
    "svelte": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^5.0.0"
  }
}
EOF
    cat > svelte.config.js <<'EOF'
import adapter from '@sveltejs/adapter-auto';
export default { kit: { adapter: adapter() } };
EOF
    mkdir -p src/routes
    : > src/routes/+page.svelte
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "my-sveltekit-app"

[plugins.node]

[env.web]
purpose = "run"
backend = "pnpm"
frameworks = ["sveltekit"]
languages = ["typescript"]
EOF
}

# ════════════════════════════════════════════════════════════════════
# Registry — a declared [plugins.node] loads node only (no implicit Python).
# ════════════════════════════════════════════════════════════════════

@test "registry: pure-Node manifest loads the node plugin only" {
    _build_sveltekit_fixture
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
}

# ════════════════════════════════════════════════════════════════════
# Detection — node + sveltekit signals fire on the fixture.
# ════════════════════════════════════════════════════════════════════

@test "detect: fixture reports node + sveltekit" {
    _build_sveltekit_fixture
    [ "$(node_pyve_plugin_detect .)" = "node" ]
    [ "$(node_detect_framework .)" = "sveltekit" ]
}

# ════════════════════════════════════════════════════════════════════
# Full lifecycle drive (deterministic stub).
# ════════════════════════════════════════════════════════════════════

@test "lifecycle: init → check → test → activate → purge compose cleanly" {
    _build_sveltekit_fixture
    manifest_load pyve.toml
    _stub_pm pnpm

    # init: provider install creates node_modules
    run node_pyve_plugin_init . pnpm
    [ "$status" -eq 0 ]
    [ -d node_modules ]
    [[ "$(cat "$PM_ARGS")" == "install" ]]

    # check: passes on the provisioned env and surfaces the framework
    run node_pyve_plugin_check .
    [ "$status" -eq 0 ]
    [[ "$output" == *"package.json present"* ]]
    [[ "$output" == *"node_modules present"* ]]
    [[ "$output" == *"sveltekit"* ]]

    # test: delegates to `pnpm test`
    : > "$PM_ARGS"
    run node_pyve_plugin_test . pnpm
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "test" ]]

    # activate: emits a PC-1-valid section
    run node_pyve_plugin_activate .
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add "node_modules/.bin"'* ]]
    local section
    section="$(node_pyve_plugin_activate .)"
    run validate_envrc_snippet "$section"
    [ "$status" -eq 0 ]

    # purge: removes generated artifacts, keeps authored files
    run node_pyve_plugin_purge .
    [ "$status" -eq 0 ]
    [ ! -d node_modules ]
    [ -f package.json ]
    [ -f svelte.config.js ]
    [ -f src/routes/+page.svelte ]
}

# ════════════════════════════════════════════════════════════════════
# Real package manager — init drives a real `npm` end-to-end.
# Zero-dependency project so the install is offline-safe; asserts
# package-lock.json (npm writes it even with no deps). Skipped if npm
# is unavailable.
# ════════════════════════════════════════════════════════════════════

@test "lifecycle: real npm install runs end-to-end (skipped if npm absent)" {
    unmock_command node
    if ! command -v npm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
        skip "npm/node not installed"
    fi
    cat > package.json <<'EOF'
{ "name": "node-root-e2e", "version": "1.0.0", "private": true }
EOF
    run node_pyve_plugin_init . npm
    [ "$status" -eq 0 ]
    [ -f package-lock.json ]
}
