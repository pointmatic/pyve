#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Plugin contract + registry skeleton.
#
# The contract defines 8 conceptual hook groups (manifest_namespace,
# register_backends, detect, lifecycle [init/purge/update/check/status/
# run/test], activate, diagnostics, gitignore_entries, purge_inventory).
# The registry loads `[plugins.*]` declarations from pyve.toml, applies
# the implicit-Python rule (S5), validates `path = "."` cardinality
# (S4), and dispatches hook calls.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    create_test_dir
    # Each test starts with an empty registry.
    plugin_registry_reset
}

teardown() {
    cleanup_test_dir
}

# Plant a fake plugin that overrides one hook to dump observable output.
plant_fake_plugin() {
    local name="$1"
    eval "
        ${name}_pyve_plugin_manifest_namespace() {
            printf '%s' '${name}'
        }
        ${name}_pyve_plugin_detect() {
            printf '%s-detected' '${name}'
            return 0
        }
    "
}

# ────────────────────────────────────────────────────────────────────
# Contract: every default hook exists as a no-op (return 0, no output).
# Plugins implementing a subset must not error on unimplemented hooks.
# ────────────────────────────────────────────────────────────────────

@test "contract: pyve_plugin_default_manifest_namespace exists and is a no-op" {
    declare -f pyve_plugin_default_manifest_namespace >/dev/null
    run pyve_plugin_default_manifest_namespace
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "contract: pyve_plugin_default_detect exists and is a no-op" {
    declare -f pyve_plugin_default_detect >/dev/null
    run pyve_plugin_default_detect
    [ "$status" -eq 0 ]
}

@test "contract: every documented hook has a default no-op" {
    # The 8 hook groups expand to the following hook names. Keeping this
    # list explicit so an accidental rename or deletion of a default
    # fails the build at code-review time.
    local hooks=(
        manifest_namespace
        register_backends
        detect
        init purge update check status run test
        activate
        diagnostics
        gitignore_entries
        purge_inventory
    )
    for hook in "${hooks[@]}"; do
        declare -f "pyve_plugin_default_${hook}" >/dev/null || {
            printf 'missing default: pyve_plugin_default_%s\n' "$hook" >&2
            return 1
        }
    done
}

# ────────────────────────────────────────────────────────────────────
# Registration + dispatch.
# ────────────────────────────────────────────────────────────────────

@test "registry: plugin_register adds a plugin to the active list" {
    plugin_register python
    run plugin_list_active
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

@test "registry: plugin_register is idempotent" {
    plugin_register python
    plugin_register python
    run plugin_list_active
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

@test "registry: plugin_dispatch calls the plugin's hook when defined" {
    plant_fake_plugin python
    plugin_register python
    run plugin_dispatch python detect
    [ "$status" -eq 0 ]
    [ "$output" = "python-detected" ]
}

@test "registry: plugin_dispatch falls back to the default when hook not defined" {
    # Use a hook the Python plugin still doesn't implement at this
    # point in the phase (`diagnostics` lands later). The lifecycle-hook work made
    # `init` / `purge` / `update` concrete on the Python plugin, so
    # they're no longer suitable for the fallback assertion.
    plugin_register python
    run plugin_dispatch python diagnostics
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "registry: plugin_dispatch passes args to the hook" {
    eval '
        python_pyve_plugin_detect() {
            printf "args=%s/%s" "$1" "$2"
        }
    '
    plugin_register python
    run plugin_dispatch python detect alpha beta
    [ "$status" -eq 0 ]
    [ "$output" = "args=alpha/beta" ]
}

# ────────────────────────────────────────────────────────────────────
# plugin_load_all_from_manifest — implicit-Python (S5), cardinality (S4).
# ────────────────────────────────────────────────────────────────────

@test "load_all_from_manifest: empty [plugins.*] → implicit Python plugin (S5)" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

@test "load_all_from_manifest: explicit [plugins.*] overrides implicit-Python default" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.node]
path = "frontend"
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    # `node` is explicit; `python` is NOT implicit because [plugins.*]
    # is non-empty.
    [ "$output" = "node" ]
}

@test "load_all_from_manifest: explicit python plugin at '.' is fine (no implicit duplicate)" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.python]
path = "."
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

@test "load_all_from_manifest: two plugins both at path='.' → cardinality error (S4)" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.python]
path = "."
[plugins.node]
path = "."
EOF
    manifest_load pyve.toml
    run plugin_load_all_from_manifest
    [ "$status" -ne 0 ]
    [[ "$output" == *"path = \".\""* ]] || [[ "$output" == *"path = '.'"* ]] || [[ "$output" == *"both claim the project root"* ]]
}

@test "load_all_from_manifest: two plugins at distinct paths → OK" {
    cat > pyve.toml << 'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[plugins.python]
path = "."
[plugins.node]
path = "frontend"
EOF
    manifest_load pyve.toml
    plugin_load_all_from_manifest
    run plugin_list_active
    [ "$status" -eq 0 ]
    # Both plugins registered, in manifest order.
    [[ "$(printf '%s' "$output")" == $'python\nnode' ]]
}
