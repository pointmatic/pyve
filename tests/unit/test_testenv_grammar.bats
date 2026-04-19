#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `pyve testenv` subcommand-grammar normalization
# (Story H.e.5).
#
# v1.x: both flag forms and new subcommand forms accepted.
# v2.0:  flag forms emit a deprecation warning (delegate-with-warning).
# v3.0:  flag forms removed.
#
# Spec: docs/specs/phase-H-cli-refactor-design.md §4.4, D5.
#
# These tests verify argument *parsing* (i.e. which action the
# command routes to) rather than full execution, so they don't
# depend on a working `python` on PATH.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
}

teardown() {
    cleanup_test_dir
}

# Each action prints a distinctive banner line before it does any
# work that would need a working python. We use those banners as
# proof that argument parsing routed to the right action.

_init_banner='Creating dev/test runner environment'
_purge_banner_absent='No dev/test runner environment found'
_install_banner_absent='Dev/test runner environment not initialized'

#============================================================
# New subcommand grammar — routes to the right action
#============================================================

@test "testenv: 'pyve testenv init' routes to the init action" {
    run "$PYVE_SCRIPT" testenv init
    # Exit status depends on whether `python -m venv` works in the test
    # env; what matters is that parsing reached the init code path.
    [[ "$output" == *"$_init_banner"* ]]
}

@test "testenv: 'pyve testenv purge' routes to the purge action" {
    # No testenv exists; purge prints the "not found" info message.
    run "$PYVE_SCRIPT" testenv purge
    [ "$status" -eq 0 ]
    [[ "$output" == *"$_purge_banner_absent"* ]]
}

@test "testenv: 'pyve testenv install' routes to the install action" {
    run "$PYVE_SCRIPT" testenv install
    [ "$status" -eq 1 ]
    [[ "$output" == *"$_install_banner_absent"* ]]
}

#============================================================
# Legacy flag grammar — routes to the same action (v1.x: no warning)
#============================================================

@test "testenv: 'pyve testenv --init' routes to the init action" {
    run "$PYVE_SCRIPT" testenv --init
    [[ "$output" == *"$_init_banner"* ]]
}

@test "testenv: 'pyve testenv --purge' routes to the purge action" {
    run "$PYVE_SCRIPT" testenv --purge
    [ "$status" -eq 0 ]
    [[ "$output" == *"$_purge_banner_absent"* ]]
}

@test "testenv: 'pyve testenv --install' routes to the install action" {
    run "$PYVE_SCRIPT" testenv --install
    [ "$status" -eq 1 ]
    [[ "$output" == *"$_install_banner_absent"* ]]
}

#============================================================
# Equivalence — old and new grammar produce the same signal
#============================================================

@test "testenv: 'init' and '--init' reach the same action" {
    run "$PYVE_SCRIPT" testenv init
    local new_form_saw_banner=0
    [[ "$output" == *"$_init_banner"* ]] && new_form_saw_banner=1

    run "$PYVE_SCRIPT" testenv --init
    local old_form_saw_banner=0
    [[ "$output" == *"$_init_banner"* ]] && old_form_saw_banner=1

    [ "$new_form_saw_banner" -eq 1 ]
    [ "$old_form_saw_banner" -eq 1 ]
}

#============================================================
# install -r <req> — flag form for dependency file still works
#============================================================

@test "testenv: 'install -r requirements-dev.txt' is accepted syntactically" {
    # No testenv; install should error out but AFTER parsing -r.
    run "$PYVE_SCRIPT" testenv install -r requirements-dev.txt
    [ "$status" -eq 1 ]
    [[ "$output" == *"$_install_banner_absent"* ]]
}

#============================================================
# Help text documents both forms
#============================================================

@test "testenv: --help documents the new subcommand grammar" {
    run "$PYVE_SCRIPT" testenv --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenv init"* ]]
    [[ "$output" == *"testenv install"* ]]
    [[ "$output" == *"testenv purge"* ]]
}

@test "testenv: --help notes legacy flag forms are still accepted" {
    run "$PYVE_SCRIPT" testenv --help
    [ "$status" -eq 0 ]
    # Look for either the "Legacy" header or the flag names.
    [[ "$output" == *"Legacy"* ]] || [[ "$output" == *"--init"* ]]
}

#============================================================
# Unknown subcommand — actionable error
#============================================================

@test "testenv: unknown subcommand exits 1 with actionable error" {
    run "$PYVE_SCRIPT" testenv bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"bogus"* ]]
}

@test "testenv: unknown flag exits 1 with actionable error" {
    run "$PYVE_SCRIPT" testenv --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"--bogus"* ]]
}

#============================================================
# Top-level --help lists the new grammar
#============================================================

@test "testenv: top-level 'pyve --help' lists the new subcommand grammar" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    # Expect the new subcommand list somewhere in top-level help.
    [[ "$output" == *"init"* ]]
    [[ "$output" == *"install"* ]]
    [[ "$output" == *"purge"* ]]
}
