#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Node plugin: init / purge / update hooks.
#
# Scaffolding lifecycle for Node envs. Mirrors N.o's shape; the new
# shape is Node's dep-install flow — there is no `python -m venv`
# analog, the package manager creates `node_modules/` directly at the
# env's path. Hooks:
#   node_pyve_plugin_init <path> <backend>    — resolve runtime (N.v),
#                                               detect provider (N.u),
#                                               run the install.
#   node_pyve_plugin_purge <path>             — smart-remove generated
#                                               dirs only.
#   node_pyve_plugin_update <path> <backend>  — refresh install (CI-aware
#                                               frozen-lockfile).
#   node_pyve_plugin_validate_env_blocks      — S9 purpose/backend check.
#
# The Node hooks are not yet routed from any `pyve` CLI command — CLI
# routing (pyve init materializing all declared envs) is N-4's job; here
# we exercise the hooks directly. Package managers are mocked (recording
# args + simulating install by creating node_modules); one test exercises
# a real `npm` when present.

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
    node_pyve_plugin_register_backends   # so bp_lookup pnpm/npm/yarn pass

    # Keep runtime resolution on the PATH tier with a stub `node` present,
    # and clear any manager env leaked from the dev shell.
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
    unmock_command yarn 2>/dev/null || true
    cleanup_test_dir
}

# Stub a package manager: record args to $PM_ARGS, simulate install by
# creating node_modules in the cwd.
_stub_pm() {
    local pm="$1"
    eval "${pm}() { printf '%s\n' \"\$*\" >> \"\$PM_ARGS\"; mkdir -p node_modules; return 0; }"
}

_make_project() {
    local dir="$1"
    mkdir -p "$dir/src"
    : > "$dir/package.json"
    : > "$dir/src/index.js"
}

# ════════════════════════════════════════════════════════════════════
# S9 env-block validation (mirrors the Python plugin's N.o validation).
# ════════════════════════════════════════════════════════════════════

_write_manifest() {
    cat > pyve.toml <<EOF
pyve_schema = "3.0"
[project]
name = "demo"
$1
EOF
}

@test "S9: valid purpose + node backend → validation passes" {
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
'
    manifest_load pyve.toml
    run node_pyve_plugin_validate_env_blocks
    [ "$status" -eq 0 ]
}

@test "S9: unregistered backend → validation fails with named diagnostic" {
    _write_manifest '
[env.web]
purpose = "run"
backend = "bun"
'
    manifest_load pyve.toml
    run node_pyve_plugin_validate_env_blocks
    [ "$status" -ne 0 ]
    [[ "$output" == *"bun"* ]]
    [[ "$output" == *"backend"* ]]
}

@test "S9: empty backend is allowed" {
    _write_manifest '
[env.web]
purpose = "run"
'
    manifest_load pyve.toml
    run node_pyve_plugin_validate_env_blocks
    [ "$status" -eq 0 ]
}

@test "S9: provider-private fields (frameworks/languages) pass through untouched" {
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
languages = ["typescript"]
frameworks = ["sveltekit"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_validate_env_blocks
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# init — resolves runtime, detects provider, runs the install.
# ════════════════════════════════════════════════════════════════════

@test "init: pnpm backend runs 'pnpm install' and creates node_modules" {
    _stub_pm pnpm
    _make_project "$TEST_DIR/proj"
    run node_pyve_plugin_init "$TEST_DIR/proj" pnpm
    [ "$status" -eq 0 ]
    [ -d "$TEST_DIR/proj/node_modules" ]
    [[ "$(cat "$PM_ARGS")" == "install" ]]
}

@test "init: npm backend runs 'npm install' and creates node_modules" {
    _stub_pm npm
    _make_project "$TEST_DIR/proj"
    run node_pyve_plugin_init "$TEST_DIR/proj" npm
    [ "$status" -eq 0 ]
    [ -d "$TEST_DIR/proj/node_modules" ]
    [[ "$(cat "$PM_ARGS")" == "install" ]]
}

@test "init: yarn backend runs 'yarn install' and creates node_modules" {
    _stub_pm yarn
    _make_project "$TEST_DIR/proj"
    run node_pyve_plugin_init "$TEST_DIR/proj" yarn
    [ "$status" -eq 0 ]
    [ -d "$TEST_DIR/proj/node_modules" ]
    [[ "$(cat "$PM_ARGS")" == "install" ]]
}

@test "init: omitted backend infers provider from lockfile (pnpm-lock.yaml → pnpm)" {
    _stub_pm pnpm
    _make_project "$TEST_DIR/proj"
    : > "$TEST_DIR/proj/pnpm-lock.yaml"
    run node_pyve_plugin_init "$TEST_DIR/proj" ""
    [ "$status" -eq 0 ]
    [ -d "$TEST_DIR/proj/node_modules" ]
}

@test "init: fails loudly when no Node runtime is present" {
    unmock_command node
    _stub_pm pnpm
    _make_project "$TEST_DIR/proj"
    PATH="$TEST_DIR/empty" run node_pyve_plugin_init "$TEST_DIR/proj" pnpm
    [ "$status" -ne 0 ]
    [[ "$output" == *"no Node runtime detected"* ]]
    [ ! -d "$TEST_DIR/proj/node_modules" ]
}

# ════════════════════════════════════════════════════════════════════
# purge — smart removal of generated dirs only.
# ════════════════════════════════════════════════════════════════════

@test "purge: removes node_modules and other generated dirs" {
    local p="$TEST_DIR/proj"
    _make_project "$p"
    mkdir -p "$p/node_modules" "$p/.svelte-kit" "$p/dist" "$p/build" "$p/.next"
    run node_pyve_plugin_purge "$p"
    [ "$status" -eq 0 ]
    [ ! -d "$p/node_modules" ]
    [ ! -d "$p/.svelte-kit" ]
    [ ! -d "$p/dist" ]
    [ ! -d "$p/build" ]
    [ ! -d "$p/.next" ]
}

@test "purge: never touches package.json, lockfiles, or source" {
    local p="$TEST_DIR/proj"
    _make_project "$p"
    : > "$p/pnpm-lock.yaml"
    mkdir -p "$p/node_modules"
    node_pyve_plugin_purge "$p"
    [ -f "$p/package.json" ]
    [ -f "$p/pnpm-lock.yaml" ]
    [ -f "$p/src/index.js" ]
}

@test "purge: is a no-op (exit 0) when nothing to remove" {
    local p="$TEST_DIR/proj"
    _make_project "$p"
    run node_pyve_plugin_purge "$p"
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# update — refresh install, CI-aware frozen-lockfile semantics.
# ════════════════════════════════════════════════════════════════════

@test "update: non-CI re-runs a plain install" {
    _stub_pm pnpm
    _make_project "$TEST_DIR/proj"
    unset CI
    run node_pyve_plugin_update "$TEST_DIR/proj" pnpm
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "install" ]]
}

@test "update: CI uses 'pnpm install --frozen-lockfile'" {
    _stub_pm pnpm
    _make_project "$TEST_DIR/proj"
    CI=1 run node_pyve_plugin_update "$TEST_DIR/proj" pnpm
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "install --frozen-lockfile" ]]
}

@test "update: CI uses 'npm ci' for the npm provider" {
    _stub_pm npm
    _make_project "$TEST_DIR/proj"
    CI=1 run node_pyve_plugin_update "$TEST_DIR/proj" npm
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "ci" ]]
}

@test "update: CI uses 'yarn install --frozen-lockfile' for the yarn provider" {
    _stub_pm yarn
    _make_project "$TEST_DIR/proj"
    CI=1 run node_pyve_plugin_update "$TEST_DIR/proj" yarn
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "install --frozen-lockfile" ]]
}

# ════════════════════════════════════════════════════════════════════
# Integration-style: the init hook drives a *real* `npm` end-to-end.
# Asserts on package-lock.json (npm writes it even for a zero-dependency
# project, network-free — node_modules/ only appears when there are deps
# to install). Skipped when npm/node are not installed so the suite stays
# green on machines without them.
# ════════════════════════════════════════════════════════════════════

@test "integration: real npm install runs end-to-end (skipped if npm absent)" {
    unmock_command node
    if ! command -v npm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
        skip "npm/node not installed"
    fi
    local p="$TEST_DIR/realproj"
    mkdir -p "$p"
    cat > "$p/package.json" <<'EOF'
{ "name": "realproj", "version": "1.0.0", "private": true }
EOF
    run node_pyve_plugin_init "$p" npm
    [ "$status" -eq 0 ]
    [ -f "$p/package-lock.json" ]
}
