#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/ui/select.sh — arrow-key selectors with a
# TTY-fallback numbered prompt (Story L.i). The TTY path uses
# raw-mode reads that aren't practical to drive from bats; tests
# focus on the fallback path which is what CI / the wizard's
# `expect`-style integration tests will exercise.

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export UI_CORE="$PYVE_ROOT/lib/ui/core.sh"
    export UI_SELECT="$PYVE_ROOT/lib/ui/select.sh"
    export NO_COLOR=1
    unset PYVE_VERBOSE
}

src='source "$UI_CORE"; source "$UI_SELECT"'

#============================================================
# Symbol coverage
#============================================================

@test "select.sh: defines ui_select and ui_multi_select" {
    run bash -c "$src; type ui_select >/dev/null && type ui_multi_select >/dev/null"
    [ "$status" -eq 0 ]
}

#============================================================
# ui_select — TTY fallback (stdin not a TTY)
#============================================================

@test "ui_select: piping a numeric choice returns the 0-based index" {
    # Pipe '2\n' as stdin → second option chosen → returns '1'.
    run bash -c "$src; ui_select 'pick one' venv micromamba <<<'2'"
    [ "$status" -eq 0 ]
    # The prompt and option list go to stderr; the index goes to stdout.
    [[ "$output" == *"1"* ]]
}

@test "ui_select: empty input falls through to the default" {
    # No --default → default is option 1 (index 0).
    run bash -c "$src; ui_select 'pick' venv micromamba <<<''"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0"* ]]
}

@test "ui_select: --default <n> changes the empty-input fallthrough" {
    # --default 2 + empty input → returns index 1 (zero-based).
    run bash -c "$src; ui_select --default 2 'pick' venv micromamba <<<''"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"* ]]
}

@test "ui_select: out-of-range numeric input returns non-zero" {
    run bash -c "$src; ui_select 'pick' venv micromamba <<<'9'"
    [ "$status" -ne 0 ]
}

@test "ui_select: non-numeric input returns non-zero" {
    run bash -c "$src; ui_select 'pick' venv micromamba <<<'banana'"
    [ "$status" -ne 0 ]
}

@test "ui_select: prompt text is printed (to stderr) for the user" {
    run bash -c "$src; ui_select 'CHOOSE_ME_PLEASE' alpha beta <<<'1' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CHOOSE_ME_PLEASE"* ]]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"beta"* ]]
}

#============================================================
# ui_multi_select — TTY fallback
#============================================================

@test "ui_multi_select: parses space-separated indices into 0-based output" {
    run bash -c "$src; ui_multi_select 'pick many' a b c d <<<'1 3'"
    [ "$status" -eq 0 ]
    # 1-based 1,3 → 0-based 0,2.
    [[ "$output" == *"0"* ]]
    [[ "$output" == *"2"* ]]
}

@test "ui_multi_select: parses comma-separated indices" {
    run bash -c "$src; ui_multi_select 'pick many' a b c d <<<'1,2,4'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0"* ]]
    [[ "$output" == *"1"* ]]
    [[ "$output" == *"3"* ]]
}

@test "ui_multi_select: out-of-range index returns non-zero" {
    run bash -c "$src; ui_multi_select 'pick many' a b c <<<'1 99'"
    [ "$status" -ne 0 ]
}

@test "ui_multi_select: empty input with no default returns empty selection (exit 0)" {
    run bash -c "$src; ui_multi_select 'pick many' a b c <<<''"
    [ "$status" -eq 0 ]
}

#============================================================
# Library-boundary invariant — select.sh stays pyve-agnostic
#============================================================

@test "select.sh: source file contains no pyve-specific paths or command names" {
    run grep -E '(pyve\.sh|\.pyve|DEFAULT_VENV_DIR|TESTENV_DIR_NAME)' "$UI_SELECT"
    [ "$status" -eq 1 ]
}

@test "select.sh: no PYVE_-prefixed identifiers (no L.f gate consumed here)" {
    # ui_select / ui_multi_select are wizard primitives — they don't
    # need to read PYVE_VERBOSE. The user is interacting; verbosity
    # has nothing to do with the prompt shape.
    run grep -oE 'PYVE_[A-Z_]+' "$UI_SELECT"
    [ "$status" -eq 1 ]
}

#============================================================
# bash 3.2 compatibility
#============================================================

@test "select.sh: sources cleanly under /bin/bash (bash 3.2 compatibility)" {
    run /bin/bash -c "source '$UI_CORE'; source '$UI_SELECT' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "select.sh: source contains no bash-4+ constructs" {
    run bash -c "grep -vE '^[[:space:]]*#' '$UI_SELECT' | grep -E '(\\bmapfile\\b|\\breadarray\\b|&>[^>]|\\bdeclare -A\\b|\\\${[^}]+\\^\\^}|\\\${[^}]+,,})'"
    [ "$status" -eq 1 ]
}
