#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml as the sole config source — the Python plugin's `.envrc` activate
# hook resolves the backend from the manifest. `compose_project_envrc` calls
# `manifest_load` before dispatching activate, so on a v3-native project
# (pyve.toml with the backend recorded, no `.pyve/config`) the emitted
# activation section reflects the manifest's backend. A v2 project resolves the
# same way: `manifest_load` synthesizes its root backend from `.pyve/config`.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
    bp_registry_reset
    plugin_registry_reset
    python_pyve_plugin_register_backends
}

teardown() {
    cleanup_test_dir
}

@test "activate: venv manifest (no .pyve/config) drives a VIRTUAL_ENV section" {
    _init_write_pyve_toml "demo" "venv"
    [ ! -e .pyve/config ]
    manifest_load "$(pwd)/pyve.toml"
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'VIRTUAL_ENV'* ]]
    [[ "$output" != *'CONDA_PREFIX'* ]]
}

@test "activate: micromamba manifest (no .pyve/config) drives a CONDA_PREFIX section" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
EOF
    [ ! -e .pyve/config ]
    manifest_load "$(pwd)/pyve.toml"
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'CONDA_PREFIX'* ]]
    [[ "$output" != *'VIRTUAL_ENV'* ]]
}

@test "activate: the manifest outranks a contradictory .pyve/config" {
    # v3 manifest says micromamba; a stale .pyve/config says venv. The manifest
    # is authoritative, so the section must be micromamba-shaped.
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
EOF
    mkdir -p .pyve; printf 'backend: venv\n' > .pyve/config
    manifest_load "$(pwd)/pyve.toml"
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'CONDA_PREFIX'* ]]
}
