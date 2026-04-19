#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/ui.sh — shared UI helpers ported from the
# sibling `gitbetter` project. The module must have zero
# pyve-specific dependencies and must be testable in isolation.
#

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export UI_PATH="$PYVE_ROOT/lib/ui.sh"
}

#============================================================
# Color constants and symbols
#============================================================

@test "ui.sh: sources cleanly with no stderr output" {
    run bash -c "source '$UI_PATH' 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ui.sh: defines the full color palette (R/G/Y/B/C/M/DIM/BOLD/RESET)" {
    run bash -c "source '$UI_PATH'; printf '%s\n' \"\${R+set}\" \"\${G+set}\" \"\${Y+set}\" \"\${B+set}\" \"\${C+set}\" \"\${M+set}\" \"\${DIM+set}\" \"\${BOLD+set}\" \"\${RESET+set}\""
    [ "$status" -eq 0 ]
    # Each line should be "set" (variable is defined, possibly empty)
    [ "$(echo "$output" | grep -c '^set$')" -eq 9 ]
}

@test "ui.sh: defines symbols CHECK, CROSS, ARROW, WARN" {
    run bash -c "source '$UI_PATH'; printf '%s\n' \"\${CHECK+set}\" \"\${CROSS+set}\" \"\${ARROW+set}\" \"\${WARN+set}\""
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c '^set$')" -eq 4 ]
}

@test "ui.sh: color variables contain ANSI escapes when NO_COLOR unset" {
    run bash -c "unset NO_COLOR; source '$UI_PATH'; printf '%s' \"\$R\" | od -c | head -1"
    [ "$status" -eq 0 ]
    # Expect ESC (033) in the R variable
    [[ "$output" == *"033"* ]]
}

#============================================================
# NO_COLOR=1 → ANSI degradation
#============================================================

@test "ui.sh: NO_COLOR=1 empties the color variables" {
    run bash -c "export NO_COLOR=1; source '$UI_PATH'; printf 'R=%s|G=%s|BOLD=%s|RESET=%s' \"\$R\" \"\$G\" \"\$BOLD\" \"\$RESET\""
    [ "$status" -eq 0 ]
    [ "$output" = "R=|G=|BOLD=|RESET=" ]
}

@test "ui.sh: NO_COLOR=1 leaves symbols as plain glyphs (no ANSI wrappers)" {
    run bash -c "export NO_COLOR=1; source '$UI_PATH'; printf '%s %s %s %s' \"\$CHECK\" \"\$CROSS\" \"\$ARROW\" \"\$WARN\""
    [ "$status" -eq 0 ]
    [ "$output" = "✔ ✘ ▸ ⚠" ]
}

@test "ui.sh: NO_COLOR=1 banner output contains no escape sequences" {
    run bash -c "export NO_COLOR=1; source '$UI_PATH'; banner 'Hello'"
    [ "$status" -eq 0 ]
    # No ESC byte in output
    ! printf '%s' "$output" | grep -q $'\033'
    [[ "$output" == *"── Hello ──"* ]]
}

@test "ui.sh: NO_COLOR=1 success/info/warn produce plain glyph-prefixed output" {
    run bash -c "export NO_COLOR=1; source '$UI_PATH'; success 'ok'; info 'note'; warn 'heads up'"
    [ "$status" -eq 0 ]
    ! printf '%s' "$output" | grep -q $'\033'
    [[ "$output" == *"✔ ok"* ]]
    [[ "$output" == *"▸ note"* ]]
    [[ "$output" == *"⚠ heads up"* ]]
}

#============================================================
# banner / info / success / warn — basic output
#============================================================

@test "ui.sh: banner includes the title bracketed by em-dashes" {
    run bash -c "source '$UI_PATH'; banner 'Section Title'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"── Section Title ──"* ]]
}

@test "ui.sh: success prepends the CHECK glyph" {
    run bash -c "source '$UI_PATH'; success 'Done'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✔"* ]]
    [[ "$output" == *"Done"* ]]
}

@test "ui.sh: info prepends the ARROW glyph" {
    run bash -c "source '$UI_PATH'; info 'Doing thing'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"▸"* ]]
    [[ "$output" == *"Doing thing"* ]]
}

@test "ui.sh: warn prepends the WARN glyph" {
    run bash -c "source '$UI_PATH'; warn 'Heads up'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠"* ]]
    [[ "$output" == *"Heads up"* ]]
}

#============================================================
# fail — exits with non-zero status
#============================================================

@test "ui.sh: fail exits with status 1 and prints the CROSS glyph" {
    run bash -c "source '$UI_PATH'; fail 'Broken'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"✘"* ]]
    [[ "$output" == *"Broken"* ]]
}

#============================================================
# confirm — default Y; non-Y aborts with exit 0
#============================================================

@test "ui.sh: confirm with empty input defaults to yes (returns 0, no exit)" {
    run bash -c "source '$UI_PATH'; confirm 'Proceed?' </dev/null; echo POST_RETURN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST_RETURN"* ]]
}

@test "ui.sh: confirm with 'y' input returns 0" {
    # Here-string (not a pipe) keeps confirm in the current shell,
    # so POST can observe its return status.
    run bash -c "source '$UI_PATH'; confirm 'Proceed?' <<< 'y'; echo POST=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST=0"* ]]
}

@test "ui.sh: confirm with 'Y' input returns 0 (case-insensitive)" {
    run bash -c "source '$UI_PATH'; confirm 'Proceed?' <<< 'Y'; echo POST=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST=0"* ]]
}

@test "ui.sh: confirm with 'n' input exits 0 and prints 'Aborted.'" {
    # Here-string keeps confirm in the current shell, so its exit 0
    # propagates and the trailing echo never runs.
    run bash -c "source '$UI_PATH'; confirm 'Proceed?' <<< 'n'; echo POST_SHOULD_NOT_PRINT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted."* ]]
    [[ "$output" != *"POST_SHOULD_NOT_PRINT"* ]]
}

@test "ui.sh: confirm default prompt is 'Continue' when no arg" {
    # bash's `read -rp` only writes the prompt when stdin is a tty,
    # so we can't see it from bats. Verify the default via source
    # inspection — it's a literal string in the function definition.
    run grep -E 'prompt="\$\{1:-Continue\}"' "$UI_PATH"
    [ "$status" -eq 0 ]
}

#============================================================
# ask_yn — default N; returns 0 for yes, 1 for no
#============================================================

@test "ui.sh: ask_yn with empty input defaults to no (returns 1)" {
    run bash -c "source '$UI_PATH'; ask_yn 'Install?' </dev/null; echo POST=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST=1"* ]]
}

@test "ui.sh: ask_yn with 'y' input returns 0" {
    run bash -c "source '$UI_PATH'; echo 'y' | ask_yn 'Install?'; echo POST=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST=0"* ]]
}

@test "ui.sh: ask_yn with 'n' input returns 1 and does NOT exit" {
    run bash -c "source '$UI_PATH'; echo 'n' | ask_yn 'Install?'; echo STILL_ALIVE=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STILL_ALIVE=1"* ]]
}

@test "ui.sh: ask_yn with 'anything_else' returns 1 (non-Y is treated as N)" {
    run bash -c "source '$UI_PATH'; echo 'maybe' | ask_yn 'Install?'; echo POST=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST=1"* ]]
}

#============================================================
# divider — prints a horizontal rule
#============================================================

@test "ui.sh: divider prints a horizontal line of box-drawing chars" {
    run bash -c "source '$UI_PATH'; divider"
    [ "$status" -eq 0 ]
    [[ "$output" == *"─"* ]]
}

#============================================================
# run_cmd — dim-echoes, then executes the command
#============================================================

@test "ui.sh: run_cmd executes the given command and returns its status" {
    run bash -c "source '$UI_PATH'; run_cmd true; echo RC=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RC=0"* ]]
}

@test "ui.sh: run_cmd propagates the executed command's exit status" {
    run bash -c "source '$UI_PATH'; run_cmd false; echo RC=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RC=1"* ]]
}

@test "ui.sh: run_cmd prints a '$' prefix before executing" {
    run bash -c "source '$UI_PATH'; run_cmd echo hello"
    [ "$status" -eq 0 ]
    [[ "$output" == *"\$ echo hello"* ]]
    [[ "$output" == *"hello"* ]]
}

#============================================================
# header_box / footer_box — rounded-corner boxes
#============================================================

@test "ui.sh: header_box renders a rounded-corner box containing the title" {
    run bash -c "source '$UI_PATH'; NO_COLOR=1 header_box 'Pyve'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"╭"* ]]
    [[ "$output" == *"╮"* ]]
    [[ "$output" == *"╰"* ]]
    [[ "$output" == *"╯"* ]]
    [[ "$output" == *"Pyve"* ]]
}

@test "ui.sh: footer_box renders a rounded-corner box with 'All done.'" {
    run bash -c "source '$UI_PATH'; NO_COLOR=1 footer_box"
    [ "$status" -eq 0 ]
    [[ "$output" == *"╭"* ]]
    [[ "$output" == *"╯"* ]]
    [[ "$output" == *"All done."* ]]
}

#============================================================
# deprecation_warn — once-per-invocation stderr warning helper
#   deprecation_warn <key> <old_form> <new_form>
# See: docs/specs/phase-H-cli-refactor-design.md §5 guardrails.
#============================================================

@test "ui.sh: deprecation_warn writes to stderr (stdout stays empty)" {
    # Discard stderr — stdout should be empty.
    run bash -c "source '$UI_PATH'; deprecation_warn k1 'pyve testenv --init' 'pyve testenv init' 2>/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ui.sh: deprecation_warn message contains both old_form and new_form literal strings" {
    # Swap fds: stdout → /dev/null, capture stderr as bats output.
    run bash -c "source '$UI_PATH'; deprecation_warn k1 'pyve testenv --init' 'pyve testenv init' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve testenv --init"* ]]
    [[ "$output" == *"pyve testenv init"* ]]
}

@test "ui.sh: deprecation_warn message does NOT reference --help" {
    # Per design guardrail: warnings include the exact replacement command,
    # NOT a --help reference.
    run bash -c "source '$UI_PATH'; deprecation_warn k1 'pyve testenv --init' 'pyve testenv init' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" != *"--help"* ]]
}

@test "ui.sh: deprecation_warn prepends the WARN glyph" {
    run bash -c "NO_COLOR=1; source '$UI_PATH'; deprecation_warn k1 'pyve testenv --init' 'pyve testenv init' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠"* ]]
}

@test "ui.sh: deprecation_warn prints once per key within a single invocation" {
    # Two calls with the same key — only ONE warning line should appear.
    run bash -c "source '$UI_PATH'; deprecation_warn k1 'old' 'new'; deprecation_warn k1 'old' 'new' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    # Count occurrences of 'old is deprecated' (or whatever text) — expect 1.
    local count
    count=$(printf '%s\n' "$output" | grep -c "old" || true)
    [ "$count" -eq 1 ]
}

@test "ui.sh: deprecation_warn prints each distinct key once" {
    # Two calls with different keys — both should warn.
    run bash -c "source '$UI_PATH'; { deprecation_warn ka 'oldA' 'newA'; deprecation_warn kb 'oldB' 'newB'; } 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"oldA"* ]]
    [[ "$output" == *"oldB"* ]]
}

@test "ui.sh: deprecation_warn under NO_COLOR=1 emits no ANSI escape sequences" {
    run bash -c "export NO_COLOR=1; source '$UI_PATH'; deprecation_warn k1 'pyve testenv --init' 'pyve testenv init' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    ! printf '%s' "$output" | grep -q $'\033'
    [[ "$output" == *"pyve testenv --init"* ]]
}

#============================================================
# bash 3.2 compatibility (H.e.7a regression guard)
#   macOS /bin/bash is 3.2.57; pyve.sh uses `set -euo pipefail`
#   and sources lib/ui.sh, so any bash 4+ construct at source
#   time aborts every pyve invocation.
#============================================================

@test "ui.sh: sources cleanly under /bin/bash (bash 3.2 compatibility)" {
    # Capture stderr only; swap fds so stdout is dropped.
    run /bin/bash -c "source '$UI_PATH' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ui.sh: deprecation_warn distinct-keys correctness under /bin/bash" {
    # Under bash 3.2 with the broken `declare -A` + `[$key]` lookup,
    # non-integer keys arithmetic-evaluate to index 0 — distinct
    # string keys collapse, so only the FIRST call warns. This test
    # catches that regression explicitly.
    run /bin/bash -c "source '$UI_PATH'; { deprecation_warn ka 'oldA' 'newA'; deprecation_warn kb 'oldB' 'newB'; } 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"oldA"* ]]
    [[ "$output" == *"oldB"* ]]
}

@test "ui.sh: source contains no 'declare -A' (bash 3.2 invariant)" {
    # Associative arrays are bash 4+. macOS /bin/bash is 3.2.
    run grep -E '^\s*declare\s+-A\b' "$UI_PATH"
    [ "$status" -eq 1 ]  # grep returns 1 when no match — that's what we want
}

@test "deprecation_warn: no call site in pyve.sh passes a key containing ':'" {
    # The once-per-invocation guard uses ':' as its delimiter in
    # the flat string; any key containing ':' would break the
    # lookup. Rule: keys stay colon-free forever.
    local pyve_script="$PYVE_ROOT/pyve.sh"
    run grep -nE 'deprecation_warn[[:space:]]+"[^"]*:' "$pyve_script"
    [ "$status" -eq 1 ]  # no match → rule holds
}

#============================================================
# Backport-discipline invariant — zero pyve identifiers in ui.sh
#============================================================

@test "ui.sh: source file contains no pyve-specific identifiers" {
    # Constants, paths, and command names that are specific to pyve.
    # The module must be backportable to gitbetter verbatim.
    run grep -E '(PYVE_|pyve\.sh|\.pyve|DEFAULT_VENV_DIR|TESTENV_DIR_NAME)' "$UI_PATH"
    [ "$status" -eq 1 ]  # grep returns 1 when no match — that's what we want
}
