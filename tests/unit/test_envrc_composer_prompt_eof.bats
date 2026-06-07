#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `prompt_yes_no` EOF-safety.
#
# `prompt_yes_no` (lib/utils.sh) previously looped forever on EOF stdin
# (`read` returns non-zero with empty input → falls to the "invalid" arm →
# prints "Please answer yes or no." → repeat). On a non-interactive caller
# with closed stdin this burns CPU until the caller's timeout. The fix:
# EOF → decline (return 1), matching ask_yn's default-negative semantics.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

@test "prompt_yes_no: EOF stdin returns 1 (decline) without looping" {
    # </dev/null gives an immediate EOF. With the bug this never returns;
    # the bats run-level guard (a fast assertion) only completes if the
    # function terminates. A stray infinite loop would hang the suite.
    run prompt_yes_no "Proceed?" </dev/null
    [ "$status" -eq 1 ]
}

@test "prompt_yes_no: EOF does not spam 'Please answer yes or no.'" {
    run prompt_yes_no "Proceed?" </dev/null
    # At most one prompt render; no repeated nagging. (grep -c exits non-zero
    # on zero matches, so guard with || true — zero is the expected count.)
    local nag
    nag="$(printf '%s\n' "$output" | grep -c 'Please answer yes or no' || true)"
    [ "$nag" -le 1 ]
}

@test "prompt_yes_no: 'y' returns 0" {
    run prompt_yes_no "Proceed?" <<< "y"
    [ "$status" -eq 0 ]
}

@test "prompt_yes_no: 'yes' returns 0" {
    run prompt_yes_no "Proceed?" <<< "yes"
    [ "$status" -eq 0 ]
}

@test "prompt_yes_no: 'n' returns 1" {
    run prompt_yes_no "Proceed?" <<< "n"
    [ "$status" -eq 1 ]
}

@test "prompt_yes_no: 'no' returns 1" {
    run prompt_yes_no "Proceed?" <<< "no"
    [ "$status" -eq 1 ]
}

@test "prompt_yes_no: re-prompts on a genuinely invalid answer, then accepts a valid one" {
    run prompt_yes_no "Proceed?" <<< $'maybe\ny'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Please answer yes or no"* ]]
}

@test "prompt_yes_no: invalid answer followed by EOF terminates (declines), no spin" {
    run prompt_yes_no "Proceed?" <<< "maybe"
    [ "$status" -eq 1 ]
}
