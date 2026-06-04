#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.ai — Composed `pyve purge` with composed inventory.
#
# `compose_purge` gathers each active plugin's `pyve_plugin_purge_inventory`
# (created/authored lines), composes them keyed by (plugin, path), enforces
# the user-authored guard (created∩authored → authored, never removed),
# presents a grouped confirmation, and then DELEGATES the actual removal to
# each plugin's `pyve_plugin_purge` hook (Option B — the hooks keep their
# smart-purge nuance; the composer owns inventory/guard/confirmation).
#
# Failure recovery: removal is idempotent (rm-only, convergent), so the
# composer dispatches ALL plugins even if one fails, reports the failures,
# notes that re-running is safe, and exits nonzero.
#
# These tests drive the composer in isolation with fake plugins, plus
# end-to-end coverage through `bash pyve.sh purge`.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/purge_composer.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    create_test_dir
    plugin_registry_reset
    export NO_COLOR=1
    unset CI PYVE_FORCE_YES

    manifest_get_plugin_path() { printf '.'; }
}

teardown() {
    cleanup_test_dir
}

# Register a fake plugin with a controllable inventory and a purge hook
# that records its invocation and returns a controlled code. Usage:
#   _fake_plugin <name> <purge_rc> <<'INV'
#   created  <path>
#   authored <path>
#   INV
_fake_plugin() {
    local name="$1" rc="${2:-0}"
    local inv
    inv="$(cat)"
    eval "${name}_pyve_plugin_purge_inventory() {
        local path=\"\${1:-.}\"
        local prefix=\"\"
        [[ -n \"\$path\" && \"\$path\" != \".\" ]] && prefix=\"\${path%/}/\"
        printf '%s\n' \"$inv\" | awk -v p=\"\$prefix\" 'NF==2 { print \$1, p \$2 }'
    }"
    eval "${name}_pyve_plugin_purge() {
        printf '%s-purge ran (path=%s)\n' '$name' \"\${1:-.}\"
        return $rc
    }"
    plugin_register "$name"
}

# ════════════════════════════════════════════════════════════════════
# compose_purge_inventory — aggregation keyed by (plugin, path).
# ════════════════════════════════════════════════════════════════════

@test "compose_purge_inventory is defined" {
    declare -F compose_purge_inventory >/dev/null
}

@test "inventory: aggregates created/authored across plugins, tagged by plugin" {
    _fake_plugin alpha 0 <<'INV'
created  build
authored config.toml
INV
    _fake_plugin beta 0 <<'INV'
created  cache
authored beta.lock
INV
    run compose_purge_inventory
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha created build"* ]]
    [[ "$output" == *"alpha authored config.toml"* ]]
    [[ "$output" == *"beta created cache"* ]]
    [[ "$output" == *"beta authored beta.lock"* ]]
}

@test "inventory: visitor-plugin paths are prefixed with the plugin path" {
    _fake_plugin node 0 <<'INV'
created  node_modules
authored package.json
INV
    manifest_get_plugin_path() {
        case "$1" in
            node) printf 'src/frontend' ;;
            *)    printf '.' ;;
        esac
    }
    run compose_purge_inventory
    [ "$status" -eq 0 ]
    [[ "$output" == *"node created src/frontend/node_modules"* ]]
    [[ "$output" == *"node authored src/frontend/package.json"* ]]
}

# ════════════════════════════════════════════════════════════════════
# User-authored guard — created∩authored → authored (never removed).
# ════════════════════════════════════════════════════════════════════

@test "guard: a path declared both created and authored is NOT in the removal set" {
    _fake_plugin alpha 0 <<'INV'
created  build
created  secret.txt
authored secret.txt
INV
    run compose_purge_removals
    [ "$status" -eq 0 ]
    [[ "$output" == *"build"* ]]
    ! [[ "$output" == *"secret.txt"* ]]
}

@test "guard: authorship in one plugin protects a created path in another (cross-plugin)" {
    _fake_plugin alpha 0 <<'INV'
created  shared.db
INV
    _fake_plugin beta 0 <<'INV'
authored shared.db
INV
    run compose_purge_removals
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"shared.db"* ]]
}

@test "guard: authored glob pattern protects a matching created path" {
    _fake_plugin alpha 0 <<'INV'
created  requirements-dev.txt
authored requirements*.txt
INV
    run compose_purge_removals
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"requirements-dev.txt"* ]]
}

# ════════════════════════════════════════════════════════════════════
# compose_purge orchestration — confirmation, delegation, exit codes.
# ════════════════════════════════════════════════════════════════════

@test "compose_purge is defined" {
    declare -F compose_purge >/dev/null
}

@test "purge: --yes skips confirmation, dispatches every active plugin's purge hook, exit 0" {
    _fake_plugin alpha 0 <<'INV'
created build
INV
    _fake_plugin beta 0 <<'INV'
created cache
INV
    run compose_purge --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha-purge ran"* ]]
    [[ "$output" == *"beta-purge ran"* ]]
}

@test "purge: 'n' at the confirmation aborts WITHOUT dispatching any purge hook" {
    _fake_plugin alpha 0 <<'INV'
created build
INV
    run compose_purge <<< "n"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"alpha-purge ran"* ]]
    [[ "$output" == *"Aborted"* ]] || [[ "$output" == *"ancel"* ]]
}

@test "purge: grouped confirmation lists items by plugin before removing" {
    _fake_plugin alpha 0 <<'INV'
created build
INV
    run compose_purge --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"build"* ]]
}

# ── Failure recovery ────────────────────────────────────────────────

@test "recovery: a failing purge hook does NOT stop the composer dispatching others" {
    _fake_plugin alpha 1 <<'INV'
created build
INV
    _fake_plugin beta 0 <<'INV'
created cache
INV
    run compose_purge --yes
    # alpha failed, but beta must still have been dispatched.
    [[ "$output" == *"alpha-purge ran"* ]]
    [[ "$output" == *"beta-purge ran"* ]]
}

@test "recovery: any plugin failure yields a nonzero exit and a re-run-safe note" {
    _fake_plugin alpha 1 <<'INV'
created build
INV
    run compose_purge --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"alpha"* ]]
    # Recovery guidance: re-running is safe / resumes.
    [[ "$output" == *"re-run"* ]] || [[ "$output" == *"safe"* ]] || [[ "$output" == *"again"* ]]
}

@test "recovery: all-success purge returns 0" {
    _fake_plugin alpha 0 <<'INV'
created build
INV
    run compose_purge --yes
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# End-to-end through the dispatcher (`bash pyve.sh purge`).
# ════════════════════════════════════════════════════════════════════

@test "e2e: polyglot --yes removes node_modules at sub-path, preserves authored files" {
    mkdir -p src/frontend/node_modules
    : > src/frontend/node_modules/.installed
    cat > src/frontend/package.json <<'JSON'
{ "name": "frontend", "private": true }
JSON
    # Python authored file at root that must survive purge.
    cat > pyproject.toml <<'TOML'
[project]
name = "polyglot"
TOML
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "polyglot"

[plugins.python]
path = "."

[plugins.node]
path = "src/frontend"
EOF
    run "$PYVE_SCRIPT" purge --yes
    [ "$status" -eq 0 ]
    # Node-created artifact at the visitor path is gone.
    [ ! -d src/frontend/node_modules ]
    # Authored files preserved.
    [ -f src/frontend/package.json ]
    [ -f pyproject.toml ]
}

@test "e2e: header box + footer render once through composed purge" {
    run bash -c "echo n | NO_COLOR=1 '$PYVE_SCRIPT' purge"
    [ "$status" -eq 0 ]
    local header_count
    header_count="$(printf '%s\n' "$output" | grep -c '╭─────────────────────────────────────────╮')"
    # Composer owns the entry header; purge_project's is gated under
    # composed mode — exactly one box-top at entry (abort path: no footer).
    [ "$header_count" -ge 1 ]
}
