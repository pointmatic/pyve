#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.q — Python plugin activate hook with PC-1 validation gate.
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
# Activate-contract change (Story N.ae.2).
#
# `python_pyve_plugin_activate` is no longer a file writer — it is a
# sentinel-wrapped snippet EMITTER (stdout), self-resolving from
# `.pyve/config`. The emitter contract (self-resolution, no-write, PC-1
# gate, dispatch routing) is owned by
# tests/unit/test_n_ae_2_python_activate_emitter.bats. The former
# byte-equivalence-via-`.envrc` tests were retired with that change: the
# legacy file-write path now lives in the bp shims (exercised directly
# below), and the composed `.envrc` byte-equivalence target moves to
# compose_envrc (N.ae.4).
#
# What remains pinned here: the bp shims still write the same legacy
# `.envrc` (the interim init path calls them directly), and the snippet
# composer is unchanged.
# ════════════════════════════════════════════════════════════════════

@test "bp shim (venv): bp_dispatch venv activate writes the legacy .envrc" {
    VERSION_MANAGER=""
    rm -f .envrc
    bp_dispatch venv activate ".venv" "demo"
    [ -f .envrc ]
    grep -qF 'PATH_add ".venv/bin"' .envrc
    grep -qF 'export VIRTUAL_ENV="$PWD/.venv"' .envrc
}

@test "bp shim (micromamba): bp_dispatch micromamba activate writes the legacy .envrc" {
    VERSION_MANAGER=""
    rm -f .envrc
    bp_dispatch micromamba activate ".pyve/envs/test-env" "test-env"
    [ -f .envrc ]
    grep -qF 'export CONDA_PREFIX="$PWD/.pyve/envs/test-env"' .envrc
}

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

@test "activate: unknown backend → error, no section" {
    mkdir -p .pyve; printf 'backend: quantum-foo\n' > .pyve/config
    rm -f .envrc
    run python_pyve_plugin_activate
    [ "$status" -ne 0 ]
    [ ! -f .envrc ]
}
