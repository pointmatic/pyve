#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Python plugin activate hook with PC-1 validation gate.
#
# Plugin-level activate: compose plugin-side .envrc snippet, run it
# through validate_envrc_snippet (N.m), delegate the actual file
# write to bp_dispatch <backend> activate (unchanged path). The
# validator catches plugin-emitted smuggling before any file is
# touched. Behavior on every existing fixture is byte-equivalent —
# the validator passes the well-formed snippet through silently.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    export PYVE_TEST_AUTOSCAFFOLD_TOML=1
    setup_pyve_env
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    bp_registry_reset
    plugin_registry_reset
    python_pyve_plugin_register_backends
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Hook existence + dispatch routing.
# ════════════════════════════════════════════════════════════════════

@test "activate: python_pyve_plugin_activate is defined" {
    declare -F python_pyve_plugin_activate >/dev/null
}

@test "activate: plugin_dispatch python activate routes to the hook" {
    plugin_register python
    # N.ae.2: the hook emits a sentinel-wrapped section to stdout (no
    # write) and self-resolves from .pyve/config.
    mkdir -p .pyve
    printf 'backend: venv\nvenv:\n  directory: .venv\n' > .pyve/config
    run plugin_dispatch python activate "."
    [ "$status" -eq 0 ]
    [[ "$output" == *"# >>> pyve:plugin:python:activate >>>"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Activate-contract change.
#
# `python_pyve_plugin_activate` is no longer a file writer — it is a
# sentinel-wrapped snippet EMITTER (stdout), self-resolving from
# `.pyve/config`. The emitter contract (self-resolution, no-write, PC-1
# gate, dispatch routing) is owned by
# tests/unit/test_python_activate_emitter.bats. The composed
# `.envrc` byte-equivalence target lives in compose_envrc (N.ae.4).
#
# The legacy file-write path was retired entirely — the
# `bp_dispatch <backend> activate` shims (`{venv,micromamba}_pyve_bp_activate`)
# and `write_envrc_template` are gone; the composer is the only `.envrc`
# emitter now. The bp-shim `.envrc`-write tests that lived here were
# removed with them. What remains: the snippet composer below.
# ════════════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════════════
# Snippet composer — the lines that go through validate_envrc_snippet.
# ════════════════════════════════════════════════════════════════════

@test "snippet: _python_pyve_plugin_envrc_snippet emits 5 plugin-owned lines" {
    run _python_pyve_plugin_envrc_snippet venv ".venv" "demo"
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add ".venv/bin"'* ]]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/.venv"'* ]]
    [[ "$output" == *'export PYVE_BACKEND="venv"'* ]]
    [[ "$output" == *'export PYVE_ENV_NAME="demo"'* ]]
    [[ "$output" == *'export PYVE_PROMPT_PREFIX="(venv:demo) "'* ]]
}

@test "snippet: composed snippet passes validate_envrc_snippet" {
    local snippet
    snippet="$(_python_pyve_plugin_envrc_snippet venv ".venv" "demo")"
    run validate_envrc_snippet "$snippet"
    [ "$status" -eq 0 ]
}

@test "snippet: micromamba shape passes validation too" {
    local snippet
    snippet="$(_python_pyve_plugin_envrc_snippet micromamba ".pyve/envs/test-env" "test-env")"
    # CONDA_PREFIX shape (migrated from the retired bp-shim .envrc test, N.al).
    [[ "$snippet" == *'export CONDA_PREFIX="$PWD/.pyve/envs/test-env"'* ]]
    run validate_envrc_snippet "$snippet"
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# PC-1 validation gate: plugin-side smuggling is caught before write.
# ════════════════════════════════════════════════════════════════════

@test "PC-1: malicious snippet composer is rejected; no section emitted" {
    # Override the snippet composer with one that injects $(...).
    # The emitter must catch this via validate_envrc_snippet and abort
    # before emitting any section.
    mkdir -p .pyve; printf 'backend: venv\n' > .pyve/config
    _python_pyve_plugin_envrc_snippet() {
        printf 'export EVIL="$(whoami)"\n'
    }

    rm -f .envrc
    run python_pyve_plugin_activate
    [ "$status" -ne 0 ]
    [ ! -f .envrc ]
    [[ "$output" != *"# >>> pyve:plugin:python:activate >>>"* ]] || [[ "$output" == *"rejected"* ]] || [[ "$output" == *"PC-1"* ]]
}

@test "PC-1: validation failure surfaces the offending line on stderr" {
    mkdir -p .pyve; printf 'backend: venv\n' > .pyve/config
    _python_pyve_plugin_envrc_snippet() {
        printf 'PATH_add `pwd`\n'
    }

    run python_pyve_plugin_activate
    [ "$status" -ne 0 ]
    [[ "$output" == *'`pwd`'* ]] || [[ "$output" == *"rejected"* ]] || [[ "$output" == *"PC-1"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Unknown backend rejection (resolved from .pyve/config).
# ════════════════════════════════════════════════════════════════════
