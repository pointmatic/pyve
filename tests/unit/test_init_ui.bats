#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the unified UX retrofit of `pyve init` (Story H.f.1).
#
# These tests assert on the output structure produced by lib/ui.sh
# helpers — header_box, banner, info, success, ask_yn, footer_box —
# rather than the exact text. The point is: every pyve command
# should look and feel like the gitbetter commands once H.f lands.
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
# header_box at entry
#============================================================

@test "init: emits rounded-box header at entry (fails fast on invalid backend)" {
    # `--backend foo` is a clean trigger: arg parsing succeeds, the
    # header should fire, then validate_backend exits 1. We do not
    # need Python tools installed — the header must precede the
    # validation failure.
    run "$PYVE_SCRIPT" init --backend foo
    [ "$status" -ne 0 ]
    [[ "$output" == *"╭─────────────────────────────────────────╮"* ]]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" == *"╰─────────────────────────────────────────╯"* ]]
}

#============================================================
# NO_COLOR=1 → no ANSI escape codes anywhere in output
#============================================================

@test "init: NO_COLOR=1 produces no ANSI escape codes in the entry path" {
    NO_COLOR=1 run "$PYVE_SCRIPT" init --backend foo
    [ "$status" -ne 0 ]
    # The header still renders, just without ANSI wrappers.
    [[ "$output" == *"pyve init"* ]]
    # Any ESC byte (\033 or \x1b) means a helper leaked an escape.
    if printf '%s' "$output" | grep -q $'\033'; then
        echo "Output contained ANSI escape codes under NO_COLOR=1:" >&2
        printf '%s\n' "$output" | cat -v >&2
        return 1
    fi
}

#============================================================
# ask_yn replaces the raw "Proceed? [y/N]: " prompt for --force
#============================================================

@test "init: --force confirmation no longer uses raw 'Proceed? [y/N]:' printf" {
    # Pre-populate a venv-init'd config so --force triggers the
    # destructive-confirmation prompt path. Answer "n" so the prompt
    # aborts cleanly without doing real work.
    #
    # Note: ask_yn's prompt is suppressed by `read -rp` when stdin is
    # piped (not a TTY), so we assert on what *is* visible: (1) the old
    # raw-printf format is gone; (2) the cancel branch fires through
    # the new info() helper (▸ prefix), proving ask_yn returned 1.
    create_pyve_config 'backend: venv' 'pyve_version: "0.1.0"'

    run bash -c "echo n | NO_COLOR=1 '$PYVE_SCRIPT' init --force"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Proceed? [y/N]: "* ]]
    [[ "$output" == *"▸ Cancelled"* ]]
}
