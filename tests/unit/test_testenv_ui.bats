#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the unified UX retrofit of `pyve testenv` (Story H.f.3).
#
# Asserts on the output structure produced by lib/ui/core.sh helpers —
# header_box, info, success, footer_box — for the `purge` subcommand
# (cheapest path to exercise the wrapper without a real Python venv).
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
# header_box + footer_box on `testenv purge` (clean dir → info path)
#============================================================

@test "testenv purge: emits rounded-box header at entry" {
    run "$PYVE_SCRIPT" testenv purge
    [ "$status" -eq 0 ]
    [[ "$output" == *"╭─────────────────────────────────────────╮"* ]]
    [[ "$output" == *"pyve testenv"* ]]
    [[ "$output" == *"╰─────────────────────────────────────────╯"* ]]
}

@test "testenv purge: footer_box renders on successful run" {
    run bash -c "NO_COLOR=1 '$PYVE_SCRIPT' testenv purge"
    [ "$status" -eq 0 ]
    [[ "$output" == *"All done"* ]]
}

#============================================================
# NO_COLOR=1 → no ANSI escape codes anywhere in output
#============================================================

@test "testenv purge: NO_COLOR=1 produces no ANSI escape codes" {
    run bash -c "NO_COLOR=1 '$PYVE_SCRIPT' testenv purge"
    [ "$status" -eq 0 ]
    if printf '%s' "$output" | grep -q $'\033'; then
        echo "Output contained ANSI escape codes under NO_COLOR=1:" >&2
        printf '%s\n' "$output" | cat -v >&2
        return 1
    fi
}
