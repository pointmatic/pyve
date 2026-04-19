#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the hard-removal of `pyve doctor` and `pyve validate`
# (Story H.e.8a).
#
# Both subcommands were briefly delegated to `pyve check` in H.e.8.
# H.e.8a accelerates the v3.0 hard-removal forward: typing the old
# name now produces a `legacy_flag_error` migration message and
# exits 1. `pyve check` is unaffected.

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
# `pyve doctor` — hard-removal migration error
#============================================================

@test "removed: 'pyve doctor' exits 1" {
    run "$PYVE_SCRIPT" doctor
    [ "$status" -eq 1 ]
}

@test "removed: 'pyve doctor' prints migration message to stderr" {
    run bash -c "'$PYVE_SCRIPT' doctor 2>&1 >/dev/null"
    [[ "$output" == *"'pyve doctor' is no longer supported"* ]]
    [[ "$output" == *"Use 'pyve check' instead"* ]]
}

@test "removed: 'pyve doctor' does NOT produce check's banner on stdout" {
    # Proof that the legacy name no longer routes anywhere — stdout
    # is empty or contains only the stub error, NOT check's output.
    run bash -c "'$PYVE_SCRIPT' doctor 2>/dev/null"
    [[ "$output" != *"Pyve Environment Check"* ]]
}

#============================================================
# `pyve validate` — hard-removal migration error
#============================================================

@test "removed: 'pyve validate' exits 1" {
    run "$PYVE_SCRIPT" validate
    [ "$status" -eq 1 ]
}

@test "removed: 'pyve validate' prints migration message to stderr" {
    run bash -c "'$PYVE_SCRIPT' validate 2>&1 >/dev/null"
    [[ "$output" == *"'pyve validate' is no longer supported"* ]]
    [[ "$output" == *"Use 'pyve check' instead"* ]]
}

@test "removed: 'pyve validate' does NOT produce check's banner on stdout" {
    run bash -c "'$PYVE_SCRIPT' validate 2>/dev/null"
    [[ "$output" != *"Pyve Environment Check"* ]]
}

#============================================================
# `pyve check` — unaffected (regression guard)
#============================================================

@test "removed: 'pyve check' still runs and prints its banner on stdout" {
    run bash -c "'$PYVE_SCRIPT' check 2>/dev/null"
    [[ "$output" == *"Pyve Environment Check"* ]]
}

@test "removed: 'pyve check' does NOT emit a migration-error line" {
    run bash -c "'$PYVE_SCRIPT' check 2>&1 >/dev/null"
    [[ "$output" != *"no longer supported"* ]]
}
