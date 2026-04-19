#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for deprecation warnings on renamed `pyve` subcommands
# and flag forms (Story H.e.7).
#
# Renames covered here:
#   pyve testenv --init         → pyve testenv init         (H.e.5)
#   pyve testenv --install      → pyve testenv install      (H.e.5)
#   pyve testenv --purge        → pyve testenv purge        (H.e.5)
#   pyve python-version <ver>   → pyve python set <ver>     (H.e.6)
#
# Spec: docs/specs/phase-H-cli-refactor-design.md §5 D3, D5
# (delegate-with-warning; stderr-only; exact replacement command;
# no --help reference).

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
# `pyve testenv --init` — deprecation warning
#============================================================

@test "deprecation: 'pyve testenv --init' emits warning on stderr" {
    # Swap fds: stdout → /dev/null, capture stderr as bats output.
    run bash -c "'$PYVE_SCRIPT' testenv --init 2>&1 >/dev/null"
    [[ "$output" == *"pyve testenv --init"* ]]
    [[ "$output" == *"pyve testenv init"* ]]
    [[ "$output" == *"deprecated"* ]]
}

@test "deprecation: 'pyve testenv --init' warning does NOT appear on stdout" {
    # Discard stderr — stdout should not contain the warning.
    run bash -c "'$PYVE_SCRIPT' testenv --init 2>/dev/null"
    [[ "$output" != *"is deprecated"* ]]
}

@test "deprecation: 'pyve testenv --init' warning does NOT reference --help" {
    run bash -c "'$PYVE_SCRIPT' testenv --init 2>&1 >/dev/null"
    [[ "$output" != *"--help"* ]]
}

#============================================================
# `pyve testenv --install` — deprecation warning
#============================================================

@test "deprecation: 'pyve testenv --install' emits warning on stderr" {
    run bash -c "'$PYVE_SCRIPT' testenv --install 2>&1 >/dev/null"
    [[ "$output" == *"pyve testenv --install"* ]]
    [[ "$output" == *"pyve testenv install"* ]]
    [[ "$output" == *"deprecated"* ]]
}

#============================================================
# `pyve testenv --purge` — deprecation warning
#============================================================

@test "deprecation: 'pyve testenv --purge' emits warning on stderr" {
    run bash -c "'$PYVE_SCRIPT' testenv --purge 2>&1 >/dev/null"
    [[ "$output" == *"pyve testenv --purge"* ]]
    [[ "$output" == *"pyve testenv purge"* ]]
    [[ "$output" == *"deprecated"* ]]
}

#============================================================
# `pyve python-version <ver>` — deprecation warning
#============================================================

@test "deprecation: 'pyve python-version <ver>' emits warning on stderr" {
    # Use an invalid-format version — the command exits 1 from
    # validate_python_version, but the deprecation_warn should fire
    # BEFORE validation.
    run bash -c "'$PYVE_SCRIPT' python-version abc 2>&1 >/dev/null"
    [[ "$output" == *"pyve python-version"* ]]
    [[ "$output" == *"pyve python set"* ]]
    [[ "$output" == *"deprecated"* ]]
}

@test "deprecation: 'pyve python-version <ver>' warning does NOT appear on stdout" {
    run bash -c "'$PYVE_SCRIPT' python-version abc 2>/dev/null"
    [[ "$output" != *"is deprecated"* ]]
}

#============================================================
# New forms — stay silent (no deprecation warning)
#============================================================

@test "deprecation: 'pyve testenv init' (new form) does NOT emit deprecation warning" {
    run bash -c "'$PYVE_SCRIPT' testenv init 2>&1 >/dev/null"
    [[ "$output" != *"is deprecated"* ]]
}

@test "deprecation: 'pyve testenv install' (new form) does NOT emit deprecation warning" {
    run bash -c "'$PYVE_SCRIPT' testenv install 2>&1 >/dev/null"
    [[ "$output" != *"is deprecated"* ]]
}

@test "deprecation: 'pyve testenv purge' (new form) does NOT emit deprecation warning" {
    run bash -c "'$PYVE_SCRIPT' testenv purge 2>&1 >/dev/null"
    [[ "$output" != *"is deprecated"* ]]
}

@test "deprecation: 'pyve python set <ver>' (new form) does NOT emit deprecation warning" {
    run bash -c "'$PYVE_SCRIPT' python set abc 2>&1 >/dev/null"
    [[ "$output" != *"is deprecated"* ]]
}

#============================================================
# Delegation — legacy forms still reach the same action
#
# The equivalence tests in test_testenv_grammar.bats and
# test_python_command.bats already cover this at the routing
# level. The test below is a smoke check that adding the
# warning didn't accidentally break the dispatch path.
#============================================================

@test "deprecation: 'pyve testenv --purge' still reaches purge action (exit 0, no-op path)" {
    # No testenv exists — purge should print its "not found" info
    # message on stdout and exit 0. Warning on stderr is separate.
    run bash -c "'$PYVE_SCRIPT' testenv --purge 2>/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No dev/test runner environment found"* ]]
}
