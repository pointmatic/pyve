#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the interactive `pyve init` wizard skeleton (Story L.k.2).
#
# Scope: the `_init_wizard` skeleton — banner printing, TTY guard, and the
# PYVE_INIT_NONINTERACTIVE=1 bypass. Per-prompt logic (backend / python
# version / project-guide) lands in L.k.3 / L.k.4 / L.k.5; those stories
# extend this test file.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # Source init.sh so _init_wizard is available for direct invocation.
    # init.sh's external deps (log_error, header_box, etc.) come from
    # ui/core.sh and utils.sh, both sourced by setup_pyve_env.
    source "$PYVE_ROOT/lib/commands/init.sh"
    create_test_dir
    # Tests in this file exercise the TTY guard explicitly. Unset the
    # bypass env var so the guard's natural behavior surfaces; individual
    # tests that need the bypass set it locally.
    unset PYVE_INIT_NONINTERACTIVE
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Happy path: banner prints when all three flags are supplied
#============================================================

@test "_init_wizard: prints header_box when all three flags supplied" {
    run _init_wizard "venv" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" == *"╭"* ]]
    [[ "$output" == *"╰"* ]]
}

#============================================================
# TTY guard fires when at least one prompt-bearing flag is missing
#============================================================

@test "_init_wizard: TTY guard fires when stdin not TTY and all three flags missing" {
    run _init_wizard "" "false" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"--backend"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" == *"--project-guide"* ]]
}

@test "_init_wizard: TTY guard error names only missing flags, not supplied ones" {
    # backend supplied; python and project-guide missing.
    run _init_wizard "venv" "false" ""
    [ "$status" -ne 0 ]
    # Supplied flag must NOT appear in the missing-flag list.
    [[ "$output" != *"--backend"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" == *"--project-guide"* ]]
}

@test "_init_wizard: TTY guard fires with only one missing flag" {
    # backend and project-guide supplied; only python missing.
    run _init_wizard "venv" "false" "yes"
    [ "$status" -ne 0 ]
    [[ "$output" != *"--backend"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" != *"--project-guide"* ]]
}

@test "_init_wizard: TTY guard error mentions PYVE_INIT_NONINTERACTIVE bypass" {
    run _init_wizard "" "false" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"PYVE_INIT_NONINTERACTIVE"* ]]
}

#============================================================
# TTY guard does NOT fire when all three flags are supplied
#============================================================

@test "_init_wizard: TTY guard does not fire when all three supplied (any backend)" {
    run _init_wizard "micromamba" "true" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init"* ]]
}

#============================================================
# PYVE_INIT_NONINTERACTIVE=1 bypasses the TTY guard
#============================================================

@test "_init_wizard: PYVE_INIT_NONINTERACTIVE=1 bypasses TTY guard with all flags missing" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "" "false" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init"* ]]
}

@test "_init_wizard: PYVE_INIT_NONINTERACTIVE=0 does NOT bypass" {
    PYVE_INIT_NONINTERACTIVE=0 run _init_wizard "" "false" ""
    [ "$status" -ne 0 ]
}

#============================================================
# Integration: pyve init dispatches through _init_wizard
#============================================================

@test "pyve init: hard-fails when stdin not TTY, no flags, no bypass" {
    unset PYVE_INIT_NONINTERACTIVE
    run "$PYVE_ROOT/pyve.sh" init
    [ "$status" -ne 0 ]
    [[ "$output" == *"--backend"* ]]
}

@test "pyve init: PYVE_INIT_NONINTERACTIVE=1 lets non-TTY init proceed past wizard" {
    # With the bypass, the wizard returns success and init proceeds. We
    # don't care if init *as a whole* succeeds — only that the wizard
    # didn't hard-fail with the TTY guard error message.
    PYVE_INIT_NONINTERACTIVE=1 run "$PYVE_ROOT/pyve.sh" init --backend foo
    [[ "$output" != *"--python-version"* ]] || [[ "$output" != *"PYVE_INIT_NONINTERACTIVE"* ]]
    # The banner should print (proves wizard ran, did not short-circuit).
    [[ "$output" == *"pyve init"* ]]
}
