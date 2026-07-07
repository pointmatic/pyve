#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# scripts/test-impact.sh — map changed files to the unit-test files
# that exercise them, for fast inner-loop iteration. Three channels,
# unioned: a changed test file selects itself; a changed lib/scripts
# source file selects every test file that references its path suffix
# (tests `source` what they exercise) or any function name it defines;
# and a small fixed smoke set always rides along. Explicitly a
# heuristic — bash has no import graph — so the full suite still runs
# at story gates and CI stays the ultimate arbiter.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    IMPACT="$PYVE_ROOT/scripts/test-impact.sh"
}

@test "impact: a changed lib command file selects its suites plus the smoke set" {
    run "$IMPACT" --list lib/commands/env.sh
    [ "$status" -eq 0 ]
    # Suites that source commands/env.sh ride the path-suffix channel.
    [[ "$output" == *"test_env_dispatcher.bats"* ]]
    [[ "$output" == *"test_env_init_force.bats"* ]]
    # The smoke set always rides along.
    [[ "$output" == *"test_cli_dispatch.bats"* ]]
    [[ "$output" == *"test_tags_guard.bats"* ]]
}

@test "impact: a changed ui module selects its suite" {
    run "$IMPACT" --list lib/ui/select.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_ui_select.bats"* ]]
}

@test "impact: a changed test file selects itself" {
    run "$IMPACT" --list tests/unit/test_manifest.bats
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_manifest.bats"* ]]
}

@test "impact: a docs-only change selects exactly the smoke set" {
    run "$IMPACT" --list docs/site/usage.md
    [ "$status" -eq 0 ]
    local expected="tests/unit/test_cli_dispatch.bats
tests/unit/test_tags_guard.bats"
    [ "$output" = "$expected" ]
}

@test "impact: the function-name channel reaches suites that never source the file" {
    # lib/envs.sh defines resolve_env_path / state_write etc., which
    # test suites call without sourcing envs.sh by that literal path
    # (test_helper sources the world). The function-name grep must
    # reach them anyway.
    run "$IMPACT" --list lib/envs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_state_layout.bats"* ]]
    [[ "$output" == *"test_testenvs_state.bats"* ]]
}

@test "impact: output is sorted and unique" {
    run "$IMPACT" --list lib/commands/env.sh lib/envs.sh
    [ "$status" -eq 0 ]
    local sorted_unique
    sorted_unique="$(printf '%s\n' "$output" | sort -u)"
    [ "$output" = "$sorted_unique" ]
}
