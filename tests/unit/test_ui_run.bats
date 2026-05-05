#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/ui/run.sh — quiet-replay-on-failure subprocess
# wrapper (Story L.g). The module captures stdout+stderr from noisy
# subprocesses and replays the captured output only on failure.
# Honors L.f's PYVE_VERBOSE gate via is_verbose() — verbose mode
# streams output live, no capture.

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export UI_CORE="$PYVE_ROOT/lib/ui/core.sh"
    export UI_RUN="$PYVE_ROOT/lib/ui/run.sh"
    export NO_COLOR=1
    unset PYVE_VERBOSE
}

# Shared sourcing preamble for sub-shell test bodies.
src='source "$UI_CORE"; source "$UI_RUN"'

#============================================================
# run_quiet — file existence + signature
#============================================================

@test "run.sh: defines run_quiet and run_quiet_with_label" {
    run bash -c "$src; type run_quiet >/dev/null && type run_quiet_with_label >/dev/null"
    [ "$status" -eq 0 ]
}

#============================================================
# run_quiet — quiet-by-default (PYVE_VERBOSE unset)
#============================================================

@test "run_quiet: success — produces no stdout/stderr output" {
    run bash -c "$src; run_quiet bash -c 'echo hello; echo world >&2'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "run_quiet: success — propagates exit code 0" {
    run bash -c "$src; run_quiet true"
    [ "$status" -eq 0 ]
}

@test "run_quiet: failure — replays captured stdout+stderr" {
    run bash -c "$src; run_quiet bash -c 'echo OUT; echo ERR >&2; exit 7'"
    [ "$status" -eq 7 ]
    [[ "$output" == *"OUT"* ]]
    [[ "$output" == *"ERR"* ]]
}

@test "run_quiet: failure — propagates non-zero exit code" {
    run bash -c "$src; run_quiet bash -c 'exit 42'"
    [ "$status" -eq 42 ]
}

#============================================================
# run_quiet — verbose mode (PYVE_VERBOSE=1) streams live
#============================================================

@test "run_quiet: verbose mode streams stdout live (no capture)" {
    run bash -c "$src; PYVE_VERBOSE=1 run_quiet bash -c 'echo streamed-stdout'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"streamed-stdout"* ]]
}

@test "run_quiet: verbose mode streams stderr live (no capture)" {
    run bash -c "$src; PYVE_VERBOSE=1 run_quiet bash -c 'echo streamed-stderr >&2' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"streamed-stderr"* ]]
}

@test "run_quiet: verbose mode propagates exit code" {
    run bash -c "$src; PYVE_VERBOSE=1 run_quiet bash -c 'exit 9' 2>/dev/null"
    [ "$status" -eq 9 ]
}

#============================================================
# run_quiet_with_label — labeled wrapper
#============================================================

@test "run_quiet_with_label: success prints a one-line success indicator" {
    run bash -c "$src; run_quiet_with_label 'doing-the-thing' true"
    [ "$status" -eq 0 ]
    [[ "$output" == *"doing-the-thing"* ]]
    # Use ✔ or success-style marker. Existing success() prints '  ✔ msg'.
    printf '%s' "$output" | grep -qE '✔|CHECK'
}

@test "run_quiet_with_label: success — single line of output (no buffer dump)" {
    run bash -c "$src; run_quiet_with_label 'short' bash -c 'echo OUT; echo ERR >&2'"
    [ "$status" -eq 0 ]
    # Captured 'OUT' / 'ERR' lines must NOT appear on success.
    ! printf '%s' "$output" | grep -q "OUT"
    ! printf '%s' "$output" | grep -q "ERR"
}

@test "run_quiet_with_label: failure replays output and prints a failure marker" {
    run bash -c "$src; run_quiet_with_label 'thing-that-fails' bash -c 'echo OUT; echo ERR >&2; exit 5'"
    [ "$status" -eq 5 ]
    [[ "$output" == *"OUT"* ]]
    [[ "$output" == *"ERR"* ]]
    [[ "$output" == *"thing-that-fails"* ]]
    printf '%s' "$output" | grep -qE '✘|CROSS'
}

@test "run_quiet_with_label: verbose mode streams live, still prints label on success" {
    run bash -c "$src; PYVE_VERBOSE=1 run_quiet_with_label 'live-mode' bash -c 'echo LIVE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"LIVE"* ]]
    [[ "$output" == *"live-mode"* ]]
}

#============================================================
# Library-boundary invariant — run.sh stays pyve-agnostic
#============================================================

@test "run.sh: source file contains no pyve-specific paths or command names" {
    run grep -E '(pyve\.sh|\.pyve|DEFAULT_VENV_DIR|TESTENV_DIR_NAME)' "$UI_RUN"
    [ "$status" -eq 1 ]
}

@test "run.sh: PYVE_VERBOSE is the only PYVE_-prefixed identifier" {
    run grep -oE 'PYVE_[A-Z_]+' "$UI_RUN"
    # Either no matches at all (PYVE_VERBOSE accessed via is_verbose helper)
    # or every match is exactly PYVE_VERBOSE.
    if [ "$status" -eq 0 ]; then
        while IFS= read -r match; do
            [[ "$match" == "PYVE_VERBOSE" ]] || {
                echo "Unexpected PYVE_-prefixed identifier in $UI_RUN: $match" >&2
                return 1
            }
        done <<<"$output"
    fi
}

#============================================================
# bash 3.2 compatibility — sources cleanly under /bin/bash
#============================================================

@test "run.sh: sources cleanly under /bin/bash (bash 3.2 compatibility)" {
    run /bin/bash -c "source '$UI_CORE'; source '$UI_RUN' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "run.sh: source contains no bash-4+ constructs (mapfile/readarray, &>)" {
    # &> is bash 4+. mapfile/readarray are bash 4+.
    # Comments are stripped before grep so doc references don't trigger.
    run bash -c "grep -vE '^[[:space:]]*#' '$UI_RUN' | grep -E '(\\bmapfile\\b|\\breadarray\\b|&>[^>])'"
    [ "$status" -eq 1 ]
}
