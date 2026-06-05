#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Story N.av.2 — the stack-agnostic composition tail is owned by
# compose_init, handed off from the Python materializer via the
# PYVE_INIT_TAIL_* result globals. These tests pin the hand-off
# protocol (run-tail / skip-tail / reset), using stubs so no real env
# materialization or manifest is required.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/init_composer.sh"

    # Stub the stack-agnostic tail steps to observable markers so the test
    # does not need a real manifest / env / project-guide install.
    compose_project_gitignore() { printf 'TAIL:gitignore\n'; }
    run_project_guide_orchestration() { printf 'TAIL:project-guide:%s\n' "$1"; }
    _init_print_next_steps() { printf 'TAIL:next-steps:%s\n' "$1"; }
    footer_box() { printf 'TAIL:footer\n'; }
    unset PYVE_INIT_TAIL_BACKEND
}

@test "compose_init runs the composition tail when the materializer set the result globals" {
    python_pyve_plugin_init() {
        PYVE_INIT_TAIL_BACKEND="venv"
        PYVE_INIT_TAIL_ENV_PATH="/proj/.venv"
        PYVE_INIT_TAIL_NO_DIRENV="true"   # skip real compose_project_envrc
        PYVE_INIT_TAIL_PG_MODE="no"
        PYVE_INIT_TAIL_COMP_MODE="no"
    }
    run compose_init --backend venv --no-direnv
    assert_status_equals 0
    assert_output_contains "Skipping .envrc creation"
    assert_output_contains "TAIL:gitignore"
    assert_output_contains "TAIL:project-guide:venv"
    assert_output_contains "TAIL:next-steps:venv"
    assert_output_contains "TAIL:footer"
}

@test "compose_init skips the tail when no env was materialized (early return / update-in-place)" {
    # Materializer returns without setting PYVE_INIT_TAIL_BACKEND.
    python_pyve_plugin_init() { printf 'CONFIG-ONLY\n'; return 0; }
    run compose_init --some-update-path
    assert_status_equals 0
    assert_output_contains "CONFIG-ONLY"
    [[ "$output" != *"TAIL:"* ]] || { echo "tail ran despite no materialization: $output" >&2; return 1; }
}

@test "compose_init resets the hand-off so a stale backend cannot trigger a spurious tail" {
    # A leftover global from a prior in-process call must not leak.
    PYVE_INIT_TAIL_BACKEND="micromamba"
    python_pyve_plugin_init() { printf 'NO-MATERIALIZE\n'; return 0; }
    run compose_init
    assert_status_equals 0
    [[ "$output" != *"TAIL:"* ]] || { echo "stale backend leaked into tail: $output" >&2; return 1; }
}

@test "compose_init honors --no-direnv (envrc skipped) but still composes .gitignore" {
    python_pyve_plugin_init() {
        PYVE_INIT_TAIL_BACKEND="venv"
        PYVE_INIT_TAIL_ENV_PATH="/proj/.venv"
        PYVE_INIT_TAIL_NO_DIRENV="true"
        PYVE_INIT_TAIL_PG_MODE="no"
        PYVE_INIT_TAIL_COMP_MODE="no"
    }
    run compose_init --no-direnv
    assert_output_contains "Skipping .envrc creation"
    assert_output_contains "TAIL:gitignore"
}
