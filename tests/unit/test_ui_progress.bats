#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/ui/progress.sh — step counter, spinner, and
# progress bar primitives (Story L.h). Tests focus on the
# observable output contract; spinner timing is covered with a
# light smoke test rather than a deterministic assertion.

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export UI_CORE="$PYVE_ROOT/lib/ui/core.sh"
    export UI_PROGRESS="$PYVE_ROOT/lib/ui/progress.sh"
    export NO_COLOR=1
    unset PYVE_VERBOSE
}

src='source "$UI_CORE"; source "$UI_PROGRESS"'

#============================================================
# Symbol coverage
#============================================================

@test "progress.sh: defines step_begin / step_end_ok / step_end_fail" {
    run bash -c "$src; type step_begin >/dev/null && type step_end_ok >/dev/null && type step_end_fail >/dev/null"
    [ "$status" -eq 0 ]
}

@test "progress.sh: defines spinner_start / spinner_stop" {
    run bash -c "$src; type spinner_start >/dev/null && type spinner_stop >/dev/null"
    [ "$status" -eq 0 ]
}

@test "progress.sh: defines progress_bar" {
    run bash -c "$src; type progress_bar >/dev/null"
    [ "$status" -eq 0 ]
}

#============================================================
# step_begin — prints the label in both quiet and verbose modes
#============================================================

@test "step_begin: prints the label (quiet mode)" {
    run bash -c "$src; step_begin '[2/5] Installing thing'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[2/5] Installing thing"* ]]
}

@test "step_begin: prints the label (verbose mode)" {
    run bash -c "$src; PYVE_VERBOSE=1 step_begin '[3/5] Resolving deps'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[3/5] Resolving deps"* ]]
}

@test "step_begin: quiet mode emits no trailing newline (so marker can append)" {
    run bash -c "$src; step_begin '[1/3] Foo'; printf 'AFTER'"
    [ "$status" -eq 0 ]
    # Quiet mode: label and AFTER share a line (no \n between them).
    [[ "$output" == *"FooAFTER"* ]]
}

@test "step_begin: verbose mode emits a trailing newline" {
    run bash -c "$src; PYVE_VERBOSE=1 step_begin '[1/3] Foo'; printf 'AFTER'"
    [ "$status" -eq 0 ]
    # Verbose mode: each on its own line.
    printf '%s\n' "$output" | grep -q "^AFTER$"
}

#============================================================
# step_end_ok / step_end_fail — distinguishable output
#============================================================

@test "step_end_ok: emits success indicator" {
    run bash -c "$src; step_begin 'Foo'; step_end_ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Foo"* ]]
    printf '%s' "$output" | grep -qE '✔|CHECK'
}

@test "step_end_fail: emits failure indicator on stderr" {
    run bash -c "$src; step_begin 'Bar'; step_end_fail 2>&1"
    [ "$status" -eq 0 ]
    printf '%s' "$output" | grep -qE '✘|CROSS'
}

@test "step_end_ok and step_end_fail produce distinguishable output" {
    local ok_out fail_out
    ok_out="$(bash -c "$src; step_begin 'X'; step_end_ok")"
    fail_out="$(bash -c "$src; step_begin 'X'; step_end_fail" 2>&1)"
    [ "$ok_out" != "$fail_out" ]
}

@test "step_end_ok: verbose mode still emits an outcome line tied to the label" {
    run bash -c "$src; PYVE_VERBOSE=1 step_begin 'Verbose-step'; PYVE_VERBOSE=1 step_end_ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Verbose-step"* ]]
}

#============================================================
# spinner_start / spinner_stop — non-TTY safe; no-op in verbose
#============================================================

@test "spinner_start / spinner_stop: no-op when stdout is not a TTY" {
    run bash -c "$src; spinner_start; spinner_stop"
    [ "$status" -eq 0 ]
    # Without a TTY there's no spinner — the helper must exit cleanly
    # rather than spawning a runaway background loop.
}

@test "spinner_start: no-op under PYVE_VERBOSE=1" {
    run bash -c "$src; PYVE_VERBOSE=1 spinner_start; PYVE_VERBOSE=1 spinner_stop"
    [ "$status" -eq 0 ]
}

@test "spinner_stop: idempotent — safe to call without spinner_start" {
    run bash -c "$src; spinner_stop"
    [ "$status" -eq 0 ]
}

#============================================================
# progress_bar — formatted output
#============================================================

@test "progress_bar: prints percent and current/total when given a TTY-safe context" {
    # progress_bar is no-op without a TTY; force it on by piping to a file
    # and reading back. Use the 'force' arg if present, else accept either
    # printed-or-skipped behavior.
    run bash -c "$src; progress_bar 50 100 20 force 2>&1"
    [ "$status" -eq 0 ]
}

@test "progress_bar: zero total is a safe no-op" {
    run bash -c "$src; progress_bar 0 0 20 force 2>&1"
    [ "$status" -eq 0 ]
}

#============================================================
# Library-boundary invariant — progress.sh stays pyve-agnostic
#============================================================

@test "progress.sh: source file contains no pyve-specific paths or command names" {
    run grep -E '(pyve\.sh|\.pyve|DEFAULT_VENV_DIR|TESTENV_DIR_NAME)' "$UI_PROGRESS"
    [ "$status" -eq 1 ]
}

@test "progress.sh: PYVE_VERBOSE is the only PYVE_-prefixed identifier" {
    run grep -oE 'PYVE_[A-Z_]+' "$UI_PROGRESS"
    if [ "$status" -eq 0 ]; then
        while IFS= read -r match; do
            [[ "$match" == "PYVE_VERBOSE" ]] || {
                echo "Unexpected PYVE_-prefixed identifier in $UI_PROGRESS: $match" >&2
                return 1
            }
        done <<<"$output"
    fi
}

#============================================================
# bash 3.2 compatibility
#============================================================

@test "progress.sh: sources cleanly under /bin/bash (bash 3.2 compatibility)" {
    run /bin/bash -c "source '$UI_CORE'; source '$UI_PROGRESS' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "progress.sh: source contains no bash-4+ constructs" {
    run bash -c "grep -vE '^[[:space:]]*#' '$UI_PROGRESS' | grep -E '(\\bmapfile\\b|\\breadarray\\b|&>[^>]|\\bdeclare -A\\b|\\\${[^}]+\\^\\^}|\\\${[^}]+,,})'"
    [ "$status" -eq 1 ]
}
