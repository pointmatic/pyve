#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.ae.2 — Activate-contract unification: Python `activate` → snippet
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
    mkdir -p .pyve
    cat > .pyve/config <<EOF
pyve_version: "9.9.9"
backend: venv
venv:
  directory: ${1:-.venv}
python:
  version: 3.13.7
EOF
}

_write_config_micromamba() {
    mkdir -p .pyve
    cat > .pyve/config <<EOF
pyve_version: "9.9.9"
backend: micromamba
micromamba:
  env_name: ${1:-test-env}
EOF
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

@test "emitter (venv): honors a custom venv directory from .pyve/config" {
    _write_config_venv "myenv"
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add "myenv/bin"'* ]]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/myenv"'* ]]
}

@test "emitter (micromamba): CONDA_PREFIX + env path from config env_name" {
    _write_config_micromamba "sci"
    run python_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add ".pyve/envs/sci/bin"'* ]]
    [[ "$output" == *'export CONDA_PREFIX="$PWD/.pyve/envs/sci"'* ]]
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

@test "emitter: unknown backend in config → error, no section, no file" {
    mkdir -p .pyve
    cat > .pyve/config <<'EOF'
backend: quantum-foo
EOF
    rm -f .envrc
    run python_pyve_plugin_activate
    [ "$status" -ne 0 ]
    [ ! -f .envrc ]
}
