#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.k (folding N.k.1) — `[plugins.<name>]` schema in pyve.toml
# plus the manifest.sh accessors that consume it.
#
# Per the spike (decisions S3, S9):
#   - The only core schema key on `[plugins.<name>]` is `path`
#     (default ".").
#   - Provider-private keys are free-form: the helper preserves them
#     and exposes them via `manifest_get_plugin_attr <name> <key>`.
#   - No `role` field (S3).
#
# Note: cardinality validation (S4 — at most one plugin with
# `path = "."`) belongs to the registry, not the schema parser; covered
# in test_plugin_registry.bats. The parser just preserves what the
# manifest declared.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # Resolve python BEFORE create_test_dir cd's away from PYVE_ROOT's
    # .envrc-activated venv (same pattern as test_read_compat.bats).
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

write_plugin_manifest() {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[plugins.python]
path = "."

[plugins.svelte]
path = "frontend"
app_type = "spa"
EOF
}

# ────────────────────────────────────────────────────────────────────
# manifest_list_plugins
# ────────────────────────────────────────────────────────────────────

@test "manifest_list_plugins: empty when [plugins.*] absent" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    run manifest_list_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "manifest_list_plugins: prints declared plugin names in declaration order" {
    write_plugin_manifest
    manifest_load pyve.toml
    run manifest_list_plugins
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output")" == $'python\nsvelte' ]]
}

# ────────────────────────────────────────────────────────────────────
# manifest_get_plugin_path
# ────────────────────────────────────────────────────────────────────

@test "manifest_get_plugin_path: returns declared path" {
    write_plugin_manifest
    manifest_load pyve.toml
    run manifest_get_plugin_path svelte
    [ "$status" -eq 0 ]
    [ "$output" = "frontend" ]
}

@test "manifest_get_plugin_path: defaults to '.' when path not declared" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.python]
EOF
    manifest_load pyve.toml
    run manifest_get_plugin_path python
    [ "$status" -eq 0 ]
    [ "$output" = "." ]
}

@test "manifest_get_plugin_path: returns 1 (no output) for unknown plugin" {
    write_plugin_manifest
    manifest_load pyve.toml
    run manifest_get_plugin_path nonexistent
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# ────────────────────────────────────────────────────────────────────
# manifest_get_plugin_attr — provider-private keys are free-form.
# ────────────────────────────────────────────────────────────────────

@test "manifest_get_plugin_attr: returns provider-private attribute value" {
    write_plugin_manifest
    manifest_load pyve.toml
    run manifest_get_plugin_attr svelte app_type
    [ "$status" -eq 0 ]
    [ "$output" = "spa" ]
}

@test "manifest_get_plugin_attr: empty string for unset attr (status 0)" {
    write_plugin_manifest
    manifest_load pyve.toml
    run manifest_get_plugin_attr python app_type
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "manifest_get_plugin_attr: returns 1 for unknown plugin" {
    write_plugin_manifest
    manifest_load pyve.toml
    run manifest_get_plugin_attr nonexistent app_type
    [ "$status" -eq 1 ]
}

# ────────────────────────────────────────────────────────────────────
# Schema invariants: no `role` field (S3 — see the spike doc).
# ────────────────────────────────────────────────────────────────────

@test "schema: pyve_toml_helper does NOT expose a 'role' core field" {
    # Read the helper source: PYVE_PLUGIN_ROLES (or equivalent) MUST NOT
    # be emitted. The pre-implementation split rejected the `role`
    # field; future contributors who try to re-add it should fail this
    # test before shipping.
    ! grep -qE 'PYVE_PLUGIN_(ROLE|ROLES)' "$PYVE_ROOT/lib/pyve_toml_helper.py"
    ! grep -qE 'PYVE_PLUGIN_(ROLE|ROLES)' "$PYVE_ROOT/lib/manifest.sh"
}
