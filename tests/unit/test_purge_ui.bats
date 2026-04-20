#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the unified UX retrofit of `pyve purge` (Story H.f.2).
#
# Asserts on the output structure produced by lib/ui.sh helpers —
# header_box, ask_yn, info, success, warn, footer_box — and the new
# `--yes` flag that lets internal callers (e.g., `init --force`) skip
# the destructive-confirmation prompt without double-prompting.
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    # The abort-on-no test relies on the confirmation prompt firing.
    # When CI or PYVE_FORCE_YES is set in the parent shell, purge skips
    # the prompt and proceeds, defeating the test.
    unset CI PYVE_FORCE_YES
}

teardown() {
    cleanup_test_dir
}

#============================================================
# header_box at entry
#============================================================

@test "purge: emits rounded-box header at entry" {
    # Pipe "n" so the destructive prompt aborts without doing real work.
    run bash -c "echo n | NO_COLOR=1 '$PYVE_SCRIPT' purge"
    [ "$status" -eq 0 ]
    [[ "$output" == *"╭─────────────────────────────────────────╮"* ]]
    [[ "$output" == *"pyve purge"* ]]
    [[ "$output" == *"╰─────────────────────────────────────────╯"* ]]
}

#============================================================
# NO_COLOR=1 → no ANSI escape codes anywhere in output
#============================================================

@test "purge: NO_COLOR=1 produces no ANSI escape codes" {
    run bash -c "echo n | NO_COLOR=1 '$PYVE_SCRIPT' purge"
    [ "$status" -eq 0 ]
    if printf '%s' "$output" | grep -q $'\033'; then
        echo "Output contained ANSI escape codes under NO_COLOR=1:" >&2
        printf '%s\n' "$output" | cat -v >&2
        return 1
    fi
}

#============================================================
# Confirmation: aborting preserves artifacts
#============================================================

@test "purge: 'n' answer aborts without removing artifacts" {
    # Pre-stage artifacts that purge would normally remove.
    touch .envrc
    touch .tool-versions
    mkdir -p .pyve

    run bash -c "echo n | NO_COLOR=1 '$PYVE_SCRIPT' purge"
    [ "$status" -eq 0 ]
    # Artifacts must still exist after abort.
    [ -f .envrc ]
    [ -f .tool-versions ]
    [ -d .pyve ]
    # Cancel branch should fire through info() (▸ prefix).
    [[ "$output" == *"▸"*"ancel"* ]] || [[ "$output" == *"▸ Aborted"* ]]
}

#============================================================
# --yes flag bypasses the confirmation prompt
#============================================================

@test "purge: --yes flag skips confirmation and removes artifacts" {
    touch .envrc
    touch .tool-versions

    # No stdin piped — if confirmation fires, the test would block.
    # bats `run` will time out / fail if it blocks.
    run "$PYVE_SCRIPT" purge --yes
    [ "$status" -eq 0 ]
    [ ! -f .envrc ]
    [ ! -f .tool-versions ]
}

#============================================================
# footer_box renders on successful completion
#============================================================

@test "purge: footer_box renders on successful run" {
    run bash -c "NO_COLOR=1 '$PYVE_SCRIPT' purge --yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"All done"* ]]
}

#============================================================
# Per-artifact success lines use ✔ glyph (success() helper)
#============================================================

@test "purge: per-artifact removal lines use ✔ glyph" {
    touch .envrc
    touch .tool-versions

    run bash -c "NO_COLOR=1 '$PYVE_SCRIPT' purge --yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✔ Removed .envrc"* ]]
    [[ "$output" == *"✔ Removed .tool-versions"* ]]
}
