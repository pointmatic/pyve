#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Node plugin: check / status / run / test hooks.
#
# Diagnostic + execution lifecycle. check verifies runtime + provisioning
# and renders the S7 (manual_steps) and S11 (typescript) advisories;
# status summarizes the env; run is a passthrough that puts
# node_modules/.bin on PATH; test honestly delegates to `<provider> test`
# (the user's package.json `test` script). Hooks take explicit
# <path> [<backend>] (not yet CLI-routed — N-4 threads them from the
# manifest).

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
    unmock_command yarn 2>/dev/null || true
    cleanup_test_dir
}

_stub_pm() {
    local pm="$1"
    eval "${pm}() { printf '%s\n' \"\$*\" >> \"\$PM_ARGS\"; return 0; }"
}

# A fully provisioned Node env: package.json + a non-empty node_modules.
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
# check — runtime + provisioning, exit code reflects hard checks only.
# ════════════════════════════════════════════════════════════════════

@test "check: passes (exit 0) on a fully provisioned env" {
    _provision "$TEST_DIR/proj"
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"package.json present"* ]]
    [[ "$output" == *"node_modules present"* ]]
}

@test "check: fails when node_modules is missing" {
    mkdir -p "$TEST_DIR/proj"
    : > "$TEST_DIR/proj/package.json"
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"node_modules"* ]]
}

@test "check: fails when package.json is missing" {
    mkdir -p "$TEST_DIR/proj/node_modules/somepkg"
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"package.json"* ]]
}

@test "check: fails when no Node runtime is present" {
    unmock_command node
    _provision "$TEST_DIR/proj"
    PATH="$TEST_DIR/empty" run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Node runtime"* ]]
}

# ── S11 TypeScript advisory ──

@test "check: warns when languages declares typescript but package.json lacks the dep" {
    _provision "$TEST_DIR/proj"
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
languages = ["typescript"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -eq 0 ]   # advisory only, no failure
    [[ "$output" == *"typescript"* ]]
}

@test "check: no typescript warning when typescript IS a package.json dependency" {
    mkdir -p "$TEST_DIR/proj/node_modules/somepkg"
    cat > "$TEST_DIR/proj/package.json" <<'EOF'
{ "name": "demo", "devDependencies": { "typescript": "^5.0.0" } }
EOF
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
languages = ["typescript"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [ "$status" -eq 0 ]
    [[ "$output" != *"not in package.json"* ]]
}

# ════════════════════════════════════════════════════════════════════
# S7 manual_steps advisory — surfaced in check and status.
# ════════════════════════════════════════════════════════════════════

@test "check: surfaces manual_steps from the manifest" {
    _provision "$TEST_DIR/proj"
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
manual_steps = ["Open iosApp in Xcode", "Press Cmd+R"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_check "$TEST_DIR/proj"
    [[ "$output" == *"Open iosApp in Xcode"* ]]
}

# ════════════════════════════════════════════════════════════════════
# status — env summary.
# ════════════════════════════════════════════════════════════════════

@test "status: reports backend, lockfile state, and node_modules state" {
    local p="$TEST_DIR/proj"
    _provision "$p"
    : > "$p/pnpm-lock.yaml"
    run node_pyve_plugin_status "$p" pnpm
    [ "$status" -eq 0 ]
    [[ "$output" == *"pnpm"* ]]
    [[ "$output" == *"pnpm-lock.yaml"* ]]
    [[ "$output" == *"node_modules"* ]]
}

@test "status: surfaces manual_steps from the manifest" {
    local p="$TEST_DIR/proj"
    _provision "$p"
    _write_manifest '
[env.web]
purpose = "run"
backend = "pnpm"
manual_steps = ["Connect a device"]
'
    manifest_load pyve.toml
    run node_pyve_plugin_status "$p" pnpm
    [[ "$output" == *"Connect a device"* ]]
}

# ════════════════════════════════════════════════════════════════════
# run — passthrough with node_modules/.bin on PATH.
# ════════════════════════════════════════════════════════════════════

@test "run: executes a binary from node_modules/.bin and forwards args" {
    local p="$TEST_DIR/proj"
    mkdir -p "$p/node_modules/.bin"
    cat > "$p/node_modules/.bin/mytool" <<'EOF'
#!/usr/bin/env bash
echo "mytool ran: $*"
EOF
    chmod +x "$p/node_modules/.bin/mytool"
    run node_pyve_plugin_run "$p" mytool arg1 arg2
    [ "$status" -eq 0 ]
    [[ "$output" == *"mytool ran: arg1 arg2"* ]]
}

# ════════════════════════════════════════════════════════════════════
# test — honest delegation to `<provider> test`.
# ════════════════════════════════════════════════════════════════════

@test "test: pnpm provider runs 'pnpm test'" {
    _stub_pm pnpm
    local p="$TEST_DIR/proj"; mkdir -p "$p"; : > "$p/package.json"
    run node_pyve_plugin_test "$p" pnpm
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "test" ]]
}

@test "test: npm provider runs 'npm test'" {
    _stub_pm npm
    local p="$TEST_DIR/proj"; mkdir -p "$p"; : > "$p/package.json"
    run node_pyve_plugin_test "$p" npm
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "test" ]]
}

@test "test: yarn provider runs 'yarn test'" {
    _stub_pm yarn
    local p="$TEST_DIR/proj"; mkdir -p "$p"; : > "$p/package.json"
    run node_pyve_plugin_test "$p" yarn
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "test" ]]
}

@test "test: omitted backend infers provider from lockfile" {
    _stub_pm yarn
    local p="$TEST_DIR/proj"; mkdir -p "$p"; : > "$p/package.json"; : > "$p/yarn.lock"
    run node_pyve_plugin_test "$p" ""
    [ "$status" -eq 0 ]
    [[ "$(cat "$PM_ARGS")" == "test" ]]
}
