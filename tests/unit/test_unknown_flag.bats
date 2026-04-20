#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Integration tests for the closest-match "did you mean?" error on
# unknown flags (Story H.e.9d).
#
# Ratifies phase-H-cli-refactor-design.md §4.5 D2. When the edit
# distance between the typo'd flag and the closest valid flag is
# <=3, the error includes a "Did you mean: '...'?" hint; beyond
# that threshold, the hint is suppressed to avoid suggesting an
# unrelated flag.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Close typo: hint fires
#============================================================

@test "unknown_flag: 'pyve init --forse' (single typo) suggests '--force'" {
    # Distance --forse → --force is 1 (single substitution).
    run "$PYVE_SCRIPT" init --forse
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not accept '--forse'"* ]]
    [[ "$output" == *"Did you mean: '--force'?"* ]]
}

@test "unknown_flag: 'pyve init --force-' suggests '--force'" {
    run "$PYVE_SCRIPT" init --force-
    [ "$status" -eq 1 ]
    [[ "$output" == *"Did you mean: '--force'?"* ]]
}

@test "unknown_flag: error lists valid flags" {
    run "$PYVE_SCRIPT" init --totally-bogus-flag-that-is-very-long
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve init'"* ]]
    [[ "$output" == *"--backend"* ]]
    [[ "$output" == *"--force"* ]]
}

@test "unknown_flag: far typo omits 'Did you mean?' line" {
    # Distance to every valid flag > 3; hint suppressed.
    run "$PYVE_SCRIPT" init --totally-bogus-flag-that-is-very-long
    [ "$status" -eq 1 ]
    [[ "$output" != *"Did you mean"* ]]
}

@test "unknown_flag: error points at per-subcommand help" {
    run "$PYVE_SCRIPT" init --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"See: pyve init --help"* ]]
}

#============================================================
# Other commands wired to unknown_flag_error
#============================================================

@test "unknown_flag: 'pyve update --bogus' surfaces valid flags" {
    run "$PYVE_SCRIPT" update --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve update'"* ]]
    [[ "$output" == *"--no-project-guide"* ]]
}

@test "unknown_flag: 'pyve check --bogus' surfaces valid flags" {
    run "$PYVE_SCRIPT" check --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve check'"* ]]
}

@test "unknown_flag: 'pyve status --bogus' surfaces valid flags" {
    run "$PYVE_SCRIPT" status --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve status'"* ]]
}

@test "unknown_flag: 'pyve purge --bogus' surfaces valid flags" {
    run "$PYVE_SCRIPT" purge --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve purge'"* ]]
    [[ "$output" == *"--keep-testenv"* ]]
}

@test "unknown_flag: 'pyve lock --bogus' surfaces valid flags" {
    run "$PYVE_SCRIPT" lock --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve lock'"* ]]
    [[ "$output" == *"--check"* ]]
}

@test "unknown_flag: 'pyve testenv --bogus' surfaces valid flags" {
    run "$PYVE_SCRIPT" testenv --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Valid flags for 'pyve testenv'"* ]]
}
