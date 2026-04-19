#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve doctor` and `pyve validate` delegating to
# `pyve check` (Story H.e.8).
#
# v1.x: doctor/validate ran their own diagnostic code paths.
# v2.x (H.e.8): both emit a one-shot stderr notice and reroute
# all normal invocations through `check_command`. The old
# `doctor_command` / `run_full_validation` are unreachable from
# the dispatcher but remain in the source tree as dead code,
# removed in v3.0 per phase-H-cli-refactor-design.md §9.
#
# Spec: phase-H-cli-refactor-design.md §5 D3,
#       phase-H-check-status-design.md §6.

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
# `pyve doctor` — delegation notice on stderr
#============================================================

@test "delegation: 'pyve doctor' emits the rename notice on stderr" {
    run bash -c "'$PYVE_SCRIPT' doctor 2>&1 >/dev/null"
    [[ "$output" == *"pyve doctor: renamed to 'pyve check'. Running 'pyve check' now..."* ]]
}

@test "delegation: 'pyve doctor' rename notice does NOT appear on stdout" {
    run bash -c "'$PYVE_SCRIPT' doctor 2>/dev/null"
    [[ "$output" != *"renamed to"* ]]
}

@test "delegation: 'pyve doctor' rename notice does NOT reference --help" {
    run bash -c "'$PYVE_SCRIPT' doctor 2>&1 >/dev/null"
    [[ "$output" != *"--help"* ]]
}

#============================================================
# `pyve doctor` — stdout is `check`'s output (proof of delegation)
#============================================================

@test "delegation: 'pyve doctor' stdout shows check's banner, not doctor's" {
    run bash -c "'$PYVE_SCRIPT' doctor 2>/dev/null"
    [[ "$output" == *"Pyve Environment Check"* ]]
    [[ "$output" != *"Pyve Environment Diagnostics"* ]]
}

#============================================================
# `pyve doctor --help` — shows check's help, does NOT warn
#============================================================

@test "delegation: 'pyve doctor --help' shows check's help (not doctor's)" {
    run "$PYVE_SCRIPT" doctor --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve check"* ]]
    [[ "$output" == *"Diagnose"* ]]
}

@test "delegation: 'pyve doctor --help' does NOT emit the delegation notice" {
    # --help is informational; no need to announce a delegation.
    run bash -c "'$PYVE_SCRIPT' doctor --help 2>&1 >/dev/null"
    [[ "$output" != *"renamed to"* ]]
}

#============================================================
# `pyve validate` — delegation notice on stderr
#============================================================

@test "delegation: 'pyve validate' emits the rename notice on stderr" {
    run bash -c "'$PYVE_SCRIPT' validate 2>&1 >/dev/null"
    [[ "$output" == *"pyve validate: renamed to 'pyve check'. Running 'pyve check' now..."* ]]
}

@test "delegation: 'pyve validate' rename notice does NOT appear on stdout" {
    run bash -c "'$PYVE_SCRIPT' validate 2>/dev/null"
    [[ "$output" != *"renamed to"* ]]
}

#============================================================
# `pyve validate` — stdout is check's output
#============================================================

@test "delegation: 'pyve validate' stdout shows check's banner" {
    run bash -c "'$PYVE_SCRIPT' validate 2>/dev/null"
    [[ "$output" == *"Pyve Environment Check"* ]]
}

#============================================================
# `pyve validate --help` — shows check's help, does NOT warn
#============================================================

@test "delegation: 'pyve validate --help' shows check's help (not validate's)" {
    run "$PYVE_SCRIPT" validate --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve check"* ]]
    [[ "$output" == *"Diagnose"* ]]
}

@test "delegation: 'pyve validate --help' does NOT emit the delegation notice" {
    run bash -c "'$PYVE_SCRIPT' validate --help 2>&1 >/dev/null"
    [[ "$output" != *"renamed to"* ]]
}

#============================================================
# `PYVE_DISPATCH_TRACE` — traces the delegation arms distinctly
#============================================================

@test "delegation: PYVE_DISPATCH_TRACE traces 'doctor→check' on 'pyve doctor'" {
    PYVE_DISPATCH_TRACE=1 run "$PYVE_SCRIPT" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:doctor"* ]]
    [[ "$output" == *"check"* ]]
}

@test "delegation: PYVE_DISPATCH_TRACE traces 'validate→check' on 'pyve validate'" {
    PYVE_DISPATCH_TRACE=1 run "$PYVE_SCRIPT" validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:validate"* ]]
    [[ "$output" == *"check"* ]]
}

#============================================================
# `pyve check` — direct path stays silent (regression guard)
#============================================================

@test "delegation: 'pyve check' (direct) does NOT emit the rename notice" {
    run bash -c "'$PYVE_SCRIPT' check 2>&1 >/dev/null"
    [[ "$output" != *"renamed to"* ]]
}
