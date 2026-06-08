#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the v2.0.1 release wrap (Story H.f.5).
#
# Asserts on:
#   - `pyve --help` no longer advertises the removed `doctor` /
#     `validate` commands (removed in H.e.8a).
#   - `pyve --help` EXAMPLES use the v2.0 canonical grammar
#     (`pyve testenv init`, `pyve python set`) rather than the
#     deprecated flag forms.
#   - `pyve purge --help` documents the `--yes` / `-y` flag
#     (added in H.f.2).
#   - `pyve --version` reflects the v2.0.1 bump.
#

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
# Top-level --help — doctor / validate rows removed
#============================================================

@test "release: 'pyve --help' does not list doctor as a command" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    # The Diagnostics section must not advertise `doctor` as a working command.
    # Grep for the command-list row format: 4-space indent + "doctor" + whitespace.
    if echo "$output" | grep -qE "^    doctor[[:space:]]"; then
        echo "Top-level --help still advertises 'doctor' as a command:" >&2
        echo "$output" | grep -E "doctor" >&2
        return 1
    fi
}

@test "release: 'pyve --help' does not list validate as a command" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    if echo "$output" | grep -qE "^    validate[[:space:]]"; then
        echo "Top-level --help still advertises 'validate' as a command:" >&2
        echo "$output" | grep -E "validate" >&2
        return 1
    fi
}

@test "release: 'pyve --help' EXAMPLES do not reference 'pyve doctor' or 'pyve validate'" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" != *"pyve doctor"* ]]
    [[ "$output" != *"pyve validate"* ]]
}

@test "release: 'pyve --help' EXAMPLES use canonical grammar for env and python" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    # Canonical grammar advertised. Story N.bf.16 retired the deprecated
    # `pyve testenv …` examples in favor of the canonical `pyve env …`
    # namespace (the runtime alias still works + warns, but --help shows
    # only the canonical surface).
    [[ "$output" == *"pyve env init"* ]]
    [[ "$output" == *"pyve python set"* ]]
    # The deprecated namespace no longer appears anywhere in --help.
    [[ "$output" != *"testenv"* ]]
    local examples_block
    examples_block="$(echo "$output" | awk '/^EXAMPLES:/,/^REQUIREMENTS:/')"
    [[ "$examples_block" != *"pyve python-version "* ]]
}

#============================================================
# `pyve purge --help` — --yes flag documented
#============================================================

@test "release: 'pyve purge --help' documents the --yes flag" {
    run "$PYVE_SCRIPT" purge --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--yes"* ]]
    # Must also name the -y short form so users discover it.
    [[ "$output" == *"-y"* ]]
}

#============================================================
# Version bump to 2.0.1 — canonical assertion lives in
# tests/unit/test_cli_dispatch.bats.
#============================================================
