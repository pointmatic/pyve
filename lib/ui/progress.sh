# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────
#  lib/ui/progress.sh — step counter, spinner, progress bar.
#
#  Sourced, not executed. Sourced after lib/ui/core.sh so the
#  is_verbose() helper and CHECK / CROSS / success() are available.
#
#  Provides three families of visual progress primitives:
#    • step_begin / step_end_ok / step_end_fail — labeled steps,
#      e.g. "[2/5] Installing micromamba ✔".
#    • spinner_start / spinner_stop — backgrounded spinner for
#      indeterminate ops (no-op when not on a TTY or when verbose).
#    • progress_bar — ASCII fill bar for known-total ops.
#
#  All primitives respect the L.f verbosity gate: under
#  PYVE_VERBOSE=1 the spinner becomes a no-op and step output
#  switches to a line-per-step shape so subprocess output isn't
#  doubly decorated.
#
#  Library boundary: this module stays pyve-agnostic — no pyve
#  paths, command names, or config keys.
# ──────────────────────────────────────────────────────────────

# Internal state: the in-flight step's label (used by step_end_*
# in verbose mode to print a labeled outcome line) and the spinner's
# background PID.
_STEP_LABEL=""
_SPINNER_PID=""

# step_begin "<label>" — open a labeled step.
#   Quiet:   prints the label without a trailing newline so that
#            spinner / step_end_* can append a marker on the same
#            line.
#   Verbose: prints the label with a trailing newline so that
#            subprocess output that follows starts on a fresh line.
step_begin() {
    _STEP_LABEL="$1"
    if is_verbose; then
        printf '%s\n' "$1"
    else
        printf '%s' "$1"
    fi
}

# step_end_ok — close the in-flight step with a success marker.
#   Quiet:   appends ' ✔\n' to the current line.
#   Verbose: prints '  ✔ <label>\n' on its own line so the outcome
#            stays tied to the step label even after a wall of
#            subprocess output.
step_end_ok() {
    if is_verbose; then
        success "$_STEP_LABEL"
    else
        printf ' %s\n' "${CHECK}"
    fi
    _STEP_LABEL=""
}

# step_end_fail — close the in-flight step with a failure marker.
#   Quiet:   appends ' ✘\n' to the current line, on stderr so
#            the marker survives stdout redirection.
#   Verbose: prints '  ✘ <label>\n' on stderr.
step_end_fail() {
    if is_verbose; then
        printf '  %s %s\n' "${CROSS}" "$_STEP_LABEL" >&2
    else
        printf ' %s\n' "${CROSS}" >&2
    fi
    _STEP_LABEL=""
}

# spinner_start — start a backgrounded spinner.
#   No-op when verbose (subprocess output is already streaming) or
#   when stdout is not a TTY (CI logs would fill with control
#   characters). ASCII spinner frames keep this bash-3.2 safe —
#   multibyte braille frames would break ${var:offset:1} which
#   counts bytes, not characters, on macOS bash.
spinner_start() {
    is_verbose && return 0
    [[ -t 1 ]] || return 0

    (
        # `trap '' INT TERM` so the parent's signal forwarding can
        # kill us cleanly via the spinner_stop path.
        local frames='|/-\'
        local i=0
        while :; do
            local frame="${frames:$((i % 4)):1}"
            printf ' %s\b\b' "$frame"
            sleep 0.1
            i=$((i + 1))
        done
    ) &
    _SPINNER_PID=$!
    # Hide cursor when tput is available; ignore errors so terminals
    # without civis (rare) don't break the run.
    command -v tput >/dev/null 2>&1 && tput civis 2>/dev/null
    return 0
}

# spinner_stop — stop the spinner if one is running. Idempotent
# (safe to call without spinner_start). Cleans up the cursor and
# the trailing spinner glyph so the line is ready for step_end_*.
spinner_stop() {
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
        # Erase the last spinner frame: backspace, space, backspace.
        printf '\b \b'
    fi
    command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
    return 0
}

# progress_bar <current> <total> [width=40] [force]
#   Print '[####------] 42% (42/100)' with a carriage-return
#   prefix so successive calls overwrite the previous bar. No-op
#   when verbose, when stdout is not a TTY, or when total is <= 0.
#   Pass 'force' as the fourth arg to bypass the TTY check (used
#   by tests).
progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local force="${4:-}"

    (( total > 0 )) || return 0
    is_verbose && return 0
    if [[ "$force" != "force" ]]; then
        [[ -t 1 ]] || return 0
    fi

    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    (( filled > width )) && filled=$width
    (( filled < 0 )) && filled=0
    local empty=$((width - filled))

    printf '\r['
    local i
    for ((i = 0; i < filled; i++)); do printf '#'; done
    for ((i = 0; i < empty; i++)); do printf '-'; done
    printf '] %d%% (%d/%d)' "$pct" "$current" "$total"
}
