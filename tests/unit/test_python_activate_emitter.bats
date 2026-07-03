#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Activate-contract unification: Python `activate` → snippet
# emitter.
#
# Per the N.ae.1 spike contract: `python_pyve_plugin_activate [<path>]` is a
# sentinel-wrapped snippet emitter on stdout (matching Node's
# node_pyve_plugin_activate), performing NO file write. It self-resolves
# backend / env_path / env_name from `.pyve/config` (the authoritative
# backend record written by init) with manifest + convention fallbacks. The
# composer (N.ae.3) dispatches it uniformly with the plugin's manifest path;
# the file write moves to compose_envrc (N.ae.4) and the init/update
# rewiring lands in N.ae.5.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    export PYVE_TEST_AUTOSCAFFOLD_TOML=1
    setup_pyve_env
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

_write_config_venv() {
    create_pyve_toml venv
    # Activate resolves the backend from the manifest. Load it so these unit
    # tests mirror production, where compose_project_envrc calls manifest_load
    # before activate.
    manifest_load >/dev/null 2>&1 || true
}

_write_config_micromamba() {
    create_pyve_toml micromamba
    manifest_load >/dev/null 2>&1 || true
}

# ════════════════════════════════════════════════════════════════════
# Hook shape: emitter, not writer.
# ════════════════════════════════════════════════════════════════════

@test "emitter: python_pyve_plugin_activate is defined" {
    declare -F python_pyve_plugin_activate >/dev/null
}

@test "emitter (venv): emits sentinel-wrapped python section to stdout" {
    _write_config_venv
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *"# >>> pyve:plugin:python:activate >>>"* ]]
    [[ "$output" == *"# <<< pyve:plugin:python:activate <<<"* ]]
    [[ "$output" == *'PATH_add ".venv/bin"'* ]]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/.venv"'* ]]
    [[ "$output" == *'export PYVE_BACKEND="venv"'* ]]
    [[ "$output" == *'export PYVE_ENV_NAME='* ]]
}

@test "emitter (venv): writes NO file" {
    _write_config_venv
    rm -f .envrc
    python_pyve_plugin_activate >/dev/null
    [ ! -f .envrc ]
}

@test "emitter (venv): a v2 custom venv directory is ignored (defaults to .venv)" {
    _write_config_venv "myenv"
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add ".venv/bin"'* ]]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/.venv"'* ]]
}

@test "emitter (micromamba): CONDA_PREFIX + PATH from the v3 root slot" {
    # The main micromamba env lives at the uniform root slot
    # .pyve/envs/root/conda/; PYVE_ENV_NAME comes from environment.yml's name:.
    _write_config_micromamba "sci"
    printf 'name: sci\ndependencies:\n  - python\n' > environment.yml
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add ".pyve/envs/root/conda/bin"'* ]]
    [[ "$output" == *'export CONDA_PREFIX="$PWD/.pyve/envs/root/conda"'* ]]
    [[ "$output" == *'export PYVE_BACKEND="micromamba"'* ]]
    [[ "$output" == *'export PYVE_ENV_NAME="sci"'* ]]
}

@test "emitter: no .pyve/config → falls back to venv / .venv" {
    rm -rf .pyve
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/.venv"'* ]]
    [[ "$output" == *'export PYVE_BACKEND="venv"'* ]]
}

@test "emitter: accepts a <path> arg (uniform composer dispatch)" {
    _write_config_venv
    run python_pyve_plugin_activate "."
    [ "$status" -eq 0 ]
    [[ "$output" == *'export PYVE_BACKEND="venv"'* ]]
}

@test "emitter: emitted section passes validate_envrc_snippet" {
    _write_config_venv
    local section
    section="$(python_pyve_plugin_activate)"
    run validate_envrc_snippet "$section"
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# Dispatch routing + PC-1 gate.
# ════════════════════════════════════════════════════════════════════

@test "emitter: plugin_dispatch python activate routes to the emitter" {
    plugin_registry_reset
    plugin_register python
    _write_config_venv
    run plugin_dispatch python activate "."
    [ "$status" -eq 0 ]
    [[ "$output" == *"# >>> pyve:plugin:python:activate >>>"* ]]
}

@test "PC-1: malicious snippet is rejected; no section emitted, no file" {
    _write_config_venv
    _python_pyve_plugin_envrc_snippet() {
        printf 'export EVIL="$(whoami)"\n'
    }
    rm -f .envrc
    run python_pyve_plugin_activate
    [ "$status" -ne 0 ]
    [ ! -f .envrc ]
    [[ "$output" != *"# >>> pyve:plugin:python:activate >>>"* ]] || [[ "$output" == *"rejected"* ]] || [[ "$output" == *"PC-1"* ]]
}

@test "PC-1: rejection surfaces the offending line / a rejection message" {
    _write_config_venv
    _python_pyve_plugin_envrc_snippet() {
        printf 'PATH_add `pwd`\n'
    }
    run python_pyve_plugin_activate
    [ "$status" -ne 0 ]
    [[ "$output" == *'`pwd`'* ]] || [[ "$output" == *"rejected"* ]] || [[ "$output" == *"PC-1"* ]]
}
