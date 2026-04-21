#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the unified UX retrofit of `pyve python set` (Story H.f.3).
#
# `pyve python set <version>` is the mutating path and gets the
# header_box / banner / footer_box treatment. `pyve python show`
# remains a quiet read-only output (no header), matching the
# `git status`-style convention in gitbetter.
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
# header_box fires on `python set` before validate_python_version
#============================================================

@test "python set: emits rounded-box header before validating version format" {
    # `set notaversion` passes arg-count check, then fails at
    # validate_python_version with exit 1. The header must fire
    # before validation so the user sees the command context even
    # when validation rejects the input.
    run "$PYVE_SCRIPT" python set notaversion
    [ "$status" -ne 0 ]
    [[ "$output" == *"╭─────────────────────────────────────────╮"* ]]
    [[ "$output" == *"pyve python set"* ]]
    [[ "$output" == *"╰─────────────────────────────────────────╯"* ]]
}

#============================================================
# NO_COLOR=1 → no ANSI escape codes on the validation-fail path
#============================================================

@test "python set: NO_COLOR=1 produces no ANSI escape codes on invalid version" {
    NO_COLOR=1 run "$PYVE_SCRIPT" python set notaversion
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve python set"* ]]
    if printf '%s' "$output" | grep -q $'\033'; then
        echo "Output contained ANSI escape codes under NO_COLOR=1:" >&2
        printf '%s\n' "$output" | cat -v >&2
        return 1
    fi
}
