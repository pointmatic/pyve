#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the end-of-init "Next steps:" summary (Story L.l).
#
# Scope: the `_init_print_next_steps` private helper. Each conditional
# next-step item appears when its precondition holds and is omitted
# otherwise; the section header is always rendered.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/commands/init.sh"
    create_test_dir
    export NO_COLOR=1
    unset PYVE_VERBOSE
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Section header always appears
#============================================================

@test "_init_print_next_steps: emits the 'Next steps' section header" {
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next steps"* ]]
}

#============================================================
# direnv-allow vs pyve-run alternative (no-direnv)
#============================================================

@test "_init_print_next_steps: direnv enabled → 'direnv allow' step appears" {
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"direnv allow"* ]]
    [[ "$output" != *"pyve run <command>"* ]]
}

@test "_init_print_next_steps: --no-direnv → 'pyve run <command>' step appears" {
    run _init_print_next_steps "venv" "true" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve run <command>"* ]]
    [[ "$output" != *"direnv allow"* ]]
}

#============================================================
# requirements-dev.txt → testenv install hint
#============================================================

@test "_init_print_next_steps: requirements-dev.txt present → testenv install step appears" {
    touch requirements-dev.txt
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve testenv install -r requirements-dev.txt"* ]]
}

@test "_init_print_next_steps: requirements-dev.txt absent → testenv install step omitted" {
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" != *"requirements-dev.txt"* ]]
}

#============================================================
# .project-guide.yml → 'Read go.md' hint
#============================================================

@test "_init_print_next_steps: .project-guide.yml present → 'Read docs/project-guide/go.md' step appears" {
    touch .project-guide.yml
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"docs/project-guide/go.md"* ]]
}

@test "_init_print_next_steps: .project-guide.yml absent → project-guide go.md step omitted" {
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" != *"docs/project-guide/go.md"* ]]
}

#============================================================
# Micromamba caveat ("ignore micromamba's activate") only on micromamba+direnv
#============================================================

@test "_init_print_next_steps: micromamba + direnv → 'ignore micromamba activate' caveat appears" {
    run _init_print_next_steps "micromamba" "false" "$TEST_DIR/.pyve/envs/test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ignore micromamba"* ]]
}

@test "_init_print_next_steps: venv backend → 'ignore micromamba' caveat omitted" {
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [[ "$output" != *"ignore micromamba"* ]]
}

@test "_init_print_next_steps: micromamba + --no-direnv → 'ignore micromamba' caveat omitted" {
    # The caveat is about direnv-vs-conda-activate confusion. Without
    # direnv there's no activation conflict to warn about.
    run _init_print_next_steps "micromamba" "true" "$TEST_DIR/.pyve/envs/test"
    [ "$status" -eq 0 ]
    [[ "$output" != *"ignore micromamba"* ]]
}

#============================================================
# Numbering: items are numbered (visible to the user as a sequence)
#============================================================

@test "_init_print_next_steps: numbered items use '1.' '2.' etc." {
    touch requirements-dev.txt
    touch .project-guide.yml
    run _init_print_next_steps "venv" "false" "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    # With direnv on + 2 detection signals, 3 numbered items expected.
    [[ "$output" == *"1."* ]]
    [[ "$output" == *"2."* ]]
    [[ "$output" == *"3."* ]]
}

#============================================================
# Combined: every conditional fires together
#============================================================

@test "_init_print_next_steps: all conditions present → all four steps in one block" {
    touch requirements-dev.txt
    touch .project-guide.yml
    run _init_print_next_steps "micromamba" "false" "$TEST_DIR/.pyve/envs/test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"direnv allow"* ]]
    [[ "$output" == *"pyve testenv install -r requirements-dev.txt"* ]]
    [[ "$output" == *"docs/project-guide/go.md"* ]]
    [[ "$output" == *"ignore micromamba"* ]]
}
