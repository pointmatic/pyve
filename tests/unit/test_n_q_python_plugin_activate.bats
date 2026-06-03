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
    source "$PYVE_ROOT/lib/commands/init.sh"
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
    rm -f .envrc
    run plugin_dispatch python activate venv ".venv" "demo"
    [ "$status" -eq 0 ]
    [ -f .envrc ]
}

# ════════════════════════════════════════════════════════════════════
# Byte-equivalence: every existing fixture still emits the same .envrc.
# ════════════════════════════════════════════════════════════════════

@test "byte-equiv (venv): plugin_dispatch activate matches legacy bp_dispatch output" {
    VERSION_MANAGER=""

    rm -f .envrc
    bp_dispatch venv activate ".venv" "demo"
    local direct
    direct="$(<.envrc)"

    rm -f .envrc
    plugin_dispatch python activate venv ".venv" "demo"
    local dispatched
    dispatched="$(<.envrc)"

    [ "$direct" = "$dispatched" ]
}

@test "byte-equiv (micromamba): plugin_dispatch activate matches legacy bp_dispatch output" {
    VERSION_MANAGER=""

    rm -f .envrc
    bp_dispatch micromamba activate ".pyve/envs/test-env" "test-env"
    local direct
    direct="$(<.envrc)"

    rm -f .envrc
    plugin_dispatch python activate micromamba ".pyve/envs/test-env" "test-env"
    local dispatched
    dispatched="$(<.envrc)"

    [ "$direct" = "$dispatched" ]
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

@test "PC-1: malicious snippet composer is rejected; no .envrc written" {
    # Override the snippet composer with one that injects $(...).
    # The plugin's activate hook must catch this via
    # validate_envrc_snippet and abort BEFORE the write happens.
    _python_pyve_plugin_envrc_snippet() {
        printf 'export EVIL="$(whoami)"\n'
    }

    rm -f .envrc
    run python_pyve_plugin_activate venv ".venv" "demo"
    [ "$status" -ne 0 ]
    [ ! -f .envrc ]
}

@test "PC-1: validation failure surfaces the offending line on stderr" {
    _python_pyve_plugin_envrc_snippet() {
        printf 'PATH_add `pwd`\n'
    }

    rm -f .envrc
    run python_pyve_plugin_activate venv ".venv" "demo"
    [ "$status" -ne 0 ]
    [[ "$output" == *'`pwd`'* ]] || [[ "$output" == *"rejected"* ]]
}

@test "PC-1: validation failure does NOT touch a pre-existing .envrc" {
    # If .envrc already exists, write_envrc_template preserves it.
    # The validation guard should never even reach the write call,
    # but verify the file is byte-identical pre/post failure.
    cat > .envrc << 'EOF'
# pre-existing pyve .envrc
PATH_add ".venv/bin"
EOF
    local before
    before="$(<.envrc)"

    _python_pyve_plugin_envrc_snippet() {
        printf 'export EVIL="$(whoami)"\n'
    }

    run python_pyve_plugin_activate venv ".venv" "demo"
    [ "$status" -ne 0 ]

    local after
    after="$(<.envrc)"
    [ "$before" = "$after" ]
}

# ════════════════════════════════════════════════════════════════════
# Unknown backend rejection.
# ════════════════════════════════════════════════════════════════════

@test "activate: unknown backend → error, no write" {
    rm -f .envrc
    run python_pyve_plugin_activate quantum-foo ".venv" "demo"
    [ "$status" -ne 0 ]
    [ ! -f .envrc ]
}
