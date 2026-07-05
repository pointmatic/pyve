#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Composed `pyve status` aggregation.
#
# `compose_status` is the informational sibling of N.ag's `compose_check`:
# it iterates the active-plugin list, dispatches each plugin's
# `pyve_plugin_status` hook, and emits a per-plugin (path-aware) section.
# Unlike check there is NO severity ladder — status reports reality and
# ALWAYS exits 0 (a broken-environment reading is `pyve check`'s job).
#
# These tests drive `compose_status` in isolation with fake plugins, plus
# two end-to-end tests through `bash pyve.sh status` exercising the real
# Python + Node status hooks.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    export PYVE_TEST_AUTOSCAFFOLD_TOML=1
    setup_pyve_env
    source "$PYVE_ROOT/lib/status_composer.sh"
    # The e2e tests drive `bash pyve.sh status` as a subprocess; its
    # manifest_load needs a resolvable Python to parse `[plugins.*]`.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    create_test_dir
    plugin_registry_reset
    export NO_COLOR=1

    # Neutralize manifest path lookups for the isolated fake-plugin tests;
    # individual tests override this for path-aware coverage.
    manifest_get_plugin_path() { printf '.'; }
}

teardown() {
    cleanup_test_dir
}

# A fake plugin's status hook: prints "<name>-status ran" and returns the
# code wired by the test (to prove status ignores hook return codes).
_define_fake_plugin() {
    local name="$1" rc="${2:-0}"
    eval "${name}_pyve_plugin_status() {
        printf '%s-status ran\n' '$name'
        return $rc
    }"
    plugin_register "$name"
}

# ════════════════════════════════════════════════════════════════════
# Definition + single-plugin aggregation.
# ════════════════════════════════════════════════════════════════════

@test "compose_status is defined" {
    declare -F compose_status >/dev/null
}

@test "single plugin: section emitted, exit 0" {
    _define_fake_plugin alpha 0
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"alpha-status ran"* ]]
}

@test "always exit 0 even when a status hook returns nonzero" {
    _define_fake_plugin alpha 1
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-status ran"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Multi-plugin aggregation + deterministic ordering.
# ════════════════════════════════════════════════════════════════════

@test "two plugins: both sections present, exit 0" {
    _define_fake_plugin alpha 0
    _define_fake_plugin beta 0
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-status ran"* ]]
    [[ "$output" == *"beta-status ran"* ]]
}

@test "ordering: sections appear in registration order" {
    _define_fake_plugin alpha 0
    _define_fake_plugin beta 0
    run compose_status
    [ "$status" -eq 0 ]
    local apos bpos
    apos="$(printf '%s\n' "$output" | grep -n 'alpha-status ran' | head -1 | cut -d: -f1)"
    bpos="$(printf '%s\n' "$output" | grep -n 'beta-status ran' | head -1 | cut -d: -f1)"
    [ "$apos" -lt "$bpos" ]
}

# ════════════════════════════════════════════════════════════════════
# Path-aware labels — visitor plugins (path != ".") are prefixed.
# ════════════════════════════════════════════════════════════════════

@test "path-aware: root plugin (path '.') label is bare" {
    _define_fake_plugin python 0
    manifest_get_plugin_path() { printf '.'; }
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"python"* ]]
    ! [[ "$output" == *"python @"* ]]
}

@test "path-aware: visitor plugin label is prefixed with its path" {
    _define_fake_plugin node 0
    manifest_get_plugin_path() {
        case "$1" in
            node) printf 'src/frontend' ;;
            *)    printf '.' ;;
        esac
    }
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"node @ src/frontend"* ]]
}

@test "active gate: an unregistered plugin contributes nothing" {
    eval 'python_pyve_plugin_status() { printf "python-status ran\n"; return 0; }'
    _define_fake_plugin node 0
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"node-status ran"* ]]
    ! [[ "$output" == *"python-status ran"* ]]
}

# ════════════════════════════════════════════════════════════════════
# End-to-end through the dispatcher (`bash pyve.sh status`).
# ════════════════════════════════════════════════════════════════════

@test "e2e: single title — composer owns it, python section does not reprint" {
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""
    run bash "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    local title_count
    title_count="$(printf '%s\n' "$output" | grep -c 'Pyve project status')"
    [ "$title_count" -eq 1 ]
    [[ "$output" == *"[python]"* ]]
    # Real python status content still present.
    [[ "$output" == *"Project"* ]]
    [[ "$output" == *"Environment"* ]]
}

@test "e2e: polyglot — per-plugin sections, path-aware node label, exit 0" {
    mkdir -p src/frontend
    cat > src/frontend/package.json <<'JSON'
{ "name": "frontend", "private": true }
JSON
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "polyglot"

[plugins.python]
path = "."

[plugins.node]
path = "src/frontend"
EOF
    run bash "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"[python]"* ]]
    [[ "$output" == *"[node @ src/frontend]"* ]]
}
