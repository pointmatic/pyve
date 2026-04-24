#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story J.d (v2.3.0) ripped the Category A delegation-with-warning paths
# shipped in Phase H. The four legacy forms that used to delegate to the
# new form with a stderr warning now error out via the standard
# unknown-flag / unknown-command paths:
#
#   pyve testenv --init         → unknown_flag_error ("does not accept '--init'")
#   pyve testenv --install      → unknown_flag_error
#   pyve testenv --purge        → unknown_flag_error
#   pyve python-version <ver>   → dispatcher's "Unknown command" *) arm
#
# These tests document the new behavior: non-zero exit, no "deprecated"
# substring, no re-dispatch to the new-form handler. File kept under its
# original name for git history; original contents rewritten for J.d.

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
# Legacy testenv flag forms — now rejected
#============================================================

@test "J.d: 'pyve testenv --init' exits non-zero and does not delegate" {
    run bash -c "'$PYVE_SCRIPT' testenv --init 2>&1"
    [ "$status" -ne 0 ]
    # The old delegate-with-warning path fired the warning AND executed
    # the new-form action. Neither happens now.
    [[ "$output" != *"deprecated"* ]]
    [[ "$output" != *"Creating dev/test runner environment"* ]]
    # Standard unknown-flag error fires instead.
    [[ "$output" == *"--init"* ]]
}

@test "J.d: 'pyve testenv --install' exits non-zero and does not delegate" {
    run bash -c "'$PYVE_SCRIPT' testenv --install 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" != *"deprecated"* ]]
    [[ "$output" == *"--install"* ]]
}

@test "J.d: 'pyve testenv --purge' exits non-zero and does not delegate" {
    run bash -c "'$PYVE_SCRIPT' testenv --purge 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" != *"deprecated"* ]]
    # Does NOT reach the "No dev/test runner environment found" message
    # that the old delegate path produced.
    [[ "$output" != *"No dev/test runner environment found"* ]]
    [[ "$output" == *"--purge"* ]]
}

#============================================================
# Legacy python-version subcommand — now rejected
#============================================================

@test "J.d: 'pyve python-version <ver>' exits non-zero and does not delegate" {
    run bash -c "'$PYVE_SCRIPT' python-version 3.13.7 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" != *"deprecated"* ]]
    # Dispatcher's *) arm says "Unknown command: python-version"
    [[ "$output" == *"python-version"* ]]
    [[ "$output" == *"Unknown command"* ]] || [[ "$output" == *"unknown"* ]]
}

#============================================================
# New forms — regression guard for the dispatcher routing
#============================================================

@test "J.d: new-form 'pyve python set <ver>' is routed (not unknown-command)" {
    # python set is the replacement for python-version. Use an invalid
    # version format so validate_python_version exits fast — but the
    # dispatcher's "Unknown command" / "does not accept" paths must not
    # fire. Integration suites cover the happy-path routing.
    run bash -c "'$PYVE_SCRIPT' python set abc 2>&1"
    [[ "$output" != *"Unknown command"* ]]
    [[ "$output" != *"does not accept"* ]]
}
