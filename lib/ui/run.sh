# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────
#  lib/ui/run.sh — quiet-replay-on-failure subprocess wrapper.
#
#  Sourced, not executed. Sourced after lib/ui/core.sh so the
#  is_verbose() helper and CHECK / CROSS / success() are available.
#
#  Pattern: long-running noisy subprocesses (micromamba bootstrap,
#  conda solve, pip install) flood the user's terminal with
#  per-file progress chatter that's only useful when something
#  fails. run_quiet captures both streams to a temp buffer; on
#  success the buffer is discarded silently, on failure it is
#  replayed to stderr so the user can diagnose. PYVE_VERBOSE=1
#  (or `--verbose`) bypasses capture and streams output live.
#
#  Library boundary: this module stays pyve-agnostic — no pyve
#  paths, command names, or config keys. Callers in lib/commands/
#  build the labeled steps; this file only knows how to run a
#  child process and decide whether to replay its output.
# ──────────────────────────────────────────────────────────────

# Run a command quietly; replay captured output on failure.
#
# Behavior:
#   - PYVE_VERBOSE=1 → exec the command directly; output streams live.
#   - default        → capture stdout+stderr to a temp file. Discard
#                      silently on success; dump to stderr on failure.
#
# Returns the command's exit code unchanged.
#
# Usage: run_quiet <cmd> [args...]
run_quiet() {
    if is_verbose; then
        "$@"
        return $?
    fi

    local tmp rc
    # Fall back to live execution if the temp file cannot be created.
    tmp="$(mktemp 2>/dev/null)" || { "$@"; return $?; }

    "$@" >"$tmp" 2>&1
    rc=$?

    if (( rc != 0 )); then
        cat "$tmp" >&2
    fi
    rm -f "$tmp"
    return "$rc"
}

# Run a command quietly with a one-line outcome indicator.
#
# Success → prints '  ✔ <label>' (via success()).
# Failure → replays the captured buffer to stderr, then prints
#           '  ✘ <label>' to stderr.
# Verbose → streams live; still prints the outcome line so callers
#           keep a consistent labeled rhythm.
#
# Usage: run_quiet_with_label "<label>" <cmd> [args...]
run_quiet_with_label() {
    local label="$1"
    shift

    if is_verbose; then
        local rc
        "$@"
        rc=$?
        if (( rc == 0 )); then
            success "$label"
        else
            printf "  %s %s\n" "${CROSS}" "$label" >&2
        fi
        return "$rc"
    fi

    local tmp rc
    tmp="$(mktemp 2>/dev/null)" || { "$@"; rc=$?; if (( rc == 0 )); then success "$label"; else printf "  %s %s\n" "${CROSS}" "$label" >&2; fi; return "$rc"; }

    "$@" >"$tmp" 2>&1
    rc=$?

    if (( rc == 0 )); then
        success "$label"
    else
        cat "$tmp" >&2
        printf "  %s %s\n" "${CROSS}" "$label" >&2
    fi
    rm -f "$tmp"
    return "$rc"
}
