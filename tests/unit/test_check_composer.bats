#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Composed `pyve check` with severity roll-up.
#
# `compose_check` iterates the active-plugin list, dispatches each plugin's
# `pyve_plugin_check` hook, emits a per-plugin (path-aware) section, and
# computes the worst severity across plugins. Severity ladder:
#
#   pass  — hook returns 0 → clean
#   error — hook returns 1 (or any other nonzero) → genuine failure
#   warn  — hook returns 2 → advisory
#
# Process exit semantics (the composer's roll-up):
#   error present → exit 2
#   warn-only     → exit 0 (advisory text, but non-failing)
#   all pass      → exit 0
#
# These tests drive `compose_check` in isolation by registering fake
# plugins whose check hooks print a marker and return a controlled code.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/check_composer.sh"
    # The e2e tests drive `bash pyve.sh check` as a subprocess; its
    # manifest_load needs a resolvable Python to parse `[plugins.*]`.
    # Export it (computed before create_test_dir cds into a sandbox).
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    plugin_registry_reset
    export NO_COLOR=1

    # Neutralize manifest path lookups for the isolated fake-plugin
    # tests; individual tests override this for path-aware coverage.
    manifest_get_plugin_path() { printf '.'; }
}

teardown() {
    cleanup_test_dir
}

# A fake plugin's check hook: prints "<name>-check" and returns the code
# captured from a per-plugin env var so each test wires its own outcome.
_define_fake_plugin() {
    local name="$1" rc="$2"
    eval "${name}_pyve_plugin_check() {
        printf '%s-check ran\n' '$name'
        return $rc
    }"
    plugin_register "$name"
}

# ════════════════════════════════════════════════════════════════════
# Definition + single-plugin outcomes.
# ════════════════════════════════════════════════════════════════════

@test "compose_check is defined" {
    declare -F compose_check >/dev/null
}

@test "single plugin pass: exit 0, section emitted" {
    _define_fake_plugin alpha 0
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"alpha-check ran"* ]]
}

@test "single plugin warn (rc 2): exit 0 with advisory section" {
    _define_fake_plugin alpha 2
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-check ran"* ]]
}

@test "single plugin error (rc 1): exit 2" {
    _define_fake_plugin alpha 1
    run compose_check
    [ "$status" -eq 2 ]
    [[ "$output" == *"alpha-check ran"* ]]
}

@test "single plugin error (rc 3, arbitrary nonzero): exit 2" {
    _define_fake_plugin alpha 3
    run compose_check
    [ "$status" -eq 2 ]
}

# ════════════════════════════════════════════════════════════════════
# Two-plugin severity roll-up (worst-across-plugins).
# ════════════════════════════════════════════════════════════════════

@test "two plugins both pass: exit 0, both sections present" {
    _define_fake_plugin alpha 0
    _define_fake_plugin beta 0
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-check ran"* ]]
    [[ "$output" == *"beta-check ran"* ]]
}

@test "two plugins one-pass-one-warn: exit 0, warning advisory present" {
    _define_fake_plugin alpha 0
    _define_fake_plugin beta 2
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-check ran"* ]]
    [[ "$output" == *"beta-check ran"* ]]
}

@test "two plugins one-pass-one-error: nonzero exit (2)" {
    _define_fake_plugin alpha 0
    _define_fake_plugin beta 1
    run compose_check
    [ "$status" -eq 2 ]
}

@test "two plugins one-warn-one-error: error wins (exit 2)" {
    _define_fake_plugin alpha 2
    _define_fake_plugin beta 1
    run compose_check
    [ "$status" -eq 2 ]
}

@test "roll-up: error in first plugin is not downgraded by a later pass" {
    _define_fake_plugin alpha 1
    _define_fake_plugin beta 0
    run compose_check
    [ "$status" -eq 2 ]
}

# ════════════════════════════════════════════════════════════════════
# Roll-up summary footer reflects the worst severity.
# ════════════════════════════════════════════════════════════════════

@test "summary footer: reports PASS when all plugins pass" {
    _define_fake_plugin alpha 0
    _define_fake_plugin beta 0
    run compose_check
    [[ "$output" == *"pass"* ]] || [[ "$output" == *"PASS"* ]]
}

@test "summary footer: reports error when a plugin errors" {
    _define_fake_plugin alpha 1
    run compose_check
    [[ "$output" == *"error"* ]] || [[ "$output" == *"ERROR"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Path-aware labels — visitor plugins (path != ".") are prefixed.
# ════════════════════════════════════════════════════════════════════

@test "path-aware: root plugin (path '.') label is bare" {
    _define_fake_plugin python 0
    manifest_get_plugin_path() { printf '.'; }
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"python"* ]]
    # No "@" path-prefix for a root plugin.
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
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"node @ src/frontend"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Active-plugin gate (no-Python suppression seam, N.aj completes it).
# ════════════════════════════════════════════════════════════════════

@test "active gate: a plugin that is NOT registered contributes nothing" {
    # Define a python check hook but DON'T register it; only node is active.
    eval 'python_pyve_plugin_check() { printf "python-check ran\n"; return 1; }'
    _define_fake_plugin node 0
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"node-check ran"* ]]
    ! [[ "$output" == *"python-check ran"* ]]
}

# ════════════════════════════════════════════════════════════════════
# End-to-end through the dispatcher (`bash pyve.sh check`) — real hooks,
# real manifest/registry loading, the actual Python + Node plugins.
# ════════════════════════════════════════════════════════════════════

@test "e2e: single banner — composer owns it, python section does not reprint" {
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""
    run bash "$PYVE_ROOT/pyve.sh" check
    # Exactly one "Pyve Environment Check" banner in the composed output.
    local banner_count
    banner_count="$(printf '%s\n' "$output" | grep -c 'Pyve Environment Check')"
    [ "$banner_count" -eq 1 ]
    [[ "$output" == *"[python]"* ]]
    [[ "$output" == *"Overall:"* ]]
}

@test "e2e: polyglot — per-plugin sections, path-aware node label, error roll-up" {
    # Python at root (no .pyve/config → error) + Node at src/frontend
    # (no node_modules → error). Both sections must appear; the Node
    # section label is path-prefixed; worst severity is error → exit 2.
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
    run bash "$PYVE_ROOT/pyve.sh" check
    [ "$status" -eq 2 ]
    [[ "$output" == *"[python]"* ]]
    [[ "$output" == *"[node @ src/frontend]"* ]]
    [[ "$output" == *"Overall: errors"* ]]
}
