# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────
#  lib/ui/select.sh — arrow-key single/multi-select prompts
#  with a numbered TTY-fallback for non-interactive callers.
#
#  Sourced, not executed. Sourced after lib/ui/core.sh so the
#  ARROW / CHECK / RESET symbols are available.
#
#  Two surfaces:
#    • ui_select [--default N] <label> <opt1> [opt2 ...]
#         Single-select. Returns the chosen option's 0-based index
#         on stdout (exit 0). Returns non-zero on cancel / invalid.
#    • ui_multi_select [--default N[,N...]] <label> <opt1> [opt2 ...]
#         Multi-select. Returns space-separated 0-based indices
#         on stdout (exit 0; empty selection is allowed).
#
#  When stdin is not a TTY (CI), each surface drops to a numbered
#  prompt that accepts indices on stdin. The wizard-side caller
#  (Story L.k) hard-fails the multi-prompt flow when stdin isn't
#  a TTY; this module only guarantees that the per-prompt fallback
#  works so individual prompts remain scriptable from tests.
#
#  Library boundary: pyve-agnostic. No PYVE_-prefixed identifiers
#  here (the verbosity gate is irrelevant to user prompts —
#  prompt shape doesn't change with --verbose).
# ──────────────────────────────────────────────────────────────

# ui_select [--default N] <label> <opt1> [opt2 ...]
ui_select() {
    local default=1
    if [[ "$1" == "--default" ]]; then
        default="$2"
        shift 2
    fi
    local label="$1"
    shift
    local options=("$@")

    if [[ ! -t 0 ]]; then
        _ui_select_fallback "$label" "$default" "${options[@]}"
        return $?
    fi
    _ui_select_tty "$label" "$default" "${options[@]}"
}

# ui_multi_select [--default N[,N...]] <label> <opt1> [opt2 ...]
ui_multi_select() {
    local default=""
    if [[ "$1" == "--default" ]]; then
        default="$2"
        shift 2
    fi
    local label="$1"
    shift
    local options=("$@")

    if [[ ! -t 0 ]]; then
        _ui_multi_select_fallback "$label" "$default" "${options[@]}"
        return $?
    fi
    _ui_multi_select_tty "$label" "$default" "${options[@]}"
}

# ── Fallback implementations (numbered prompt on closed stdin) ──

_ui_select_fallback() {
    local label="$1" default="$2"
    shift 2
    local options=("$@")
    local n=${#options[@]}

    printf '%s\n' "$label" >&2
    local i=1
    for opt in "${options[@]}"; do
        printf '  %d) %s\n' "$i" "$opt" >&2
        i=$((i + 1))
    done
    printf '  [%d]: ' "$default" >&2

    local input
    IFS= read -r input || input=""
    [[ -z "$input" ]] && input="$default"

    if [[ ! "$input" =~ ^[0-9]+$ ]]; then
        printf 'Invalid selection: %s\n' "$input" >&2
        return 1
    fi
    if (( input < 1 || input > n )); then
        printf 'Selection out of range: %s\n' "$input" >&2
        return 1
    fi
    printf '%d' $((input - 1))
    return 0
}

_ui_multi_select_fallback() {
    local label="$1" default="$2"
    shift 2
    local options=("$@")
    local n=${#options[@]}

    printf '%s (space- or comma-separated indices)\n' "$label" >&2
    local i=1
    for opt in "${options[@]}"; do
        printf '  %d) %s\n' "$i" "$opt" >&2
        i=$((i + 1))
    done
    printf '  [%s]: ' "$default" >&2

    local input
    IFS= read -r input || input=""
    [[ -z "$input" ]] && input="$default"

    # Empty input with no default → empty selection. Caller decides
    # whether that's meaningful or an error.
    if [[ -z "$input" ]]; then
        return 0
    fi

    local out=""
    local num
    for num in $(printf '%s' "$input" | tr ',' ' '); do
        if [[ ! "$num" =~ ^[0-9]+$ ]]; then
            printf 'Invalid selection: %s\n' "$num" >&2
            return 1
        fi
        if (( num < 1 || num > n )); then
            printf 'Selection out of range: %s\n' "$num" >&2
            return 1
        fi
        out="$out $((num - 1))"
    done
    printf '%s' "${out# }"
    return 0
}

# ── TTY (raw-mode) implementations ──
#
# Smoke-tested manually; not unit-tested in bats because driving
# `read -rsn1` from a sub-shell without a real PTY is impractical.
# The L.k wizard's `expect`-style integration tests cover the
# arrow-key flow end-to-end.

_ui_select_tty() {
    local label="$1" default="$2"
    shift 2
    local options=("$@")
    local n=${#options[@]}
    local cur=$((default - 1))
    (( cur < 0 )) && cur=0
    (( cur >= n )) && cur=$((n - 1))

    command -v tput >/dev/null 2>&1 && tput civis 2>/dev/null
    printf '%s\n' "$label" >&2

    local i
    for ((i = 0; i < n; i++)); do
        if (( i == cur )); then
            printf '  > %s\n' "${options[$i]}" >&2
        else
            printf '    %s\n' "${options[$i]}" >&2
        fi
    done

    while :; do
        local key=""
        IFS= read -rsn1 key || key=""
        case "$key" in
            $'\x1b')
                local rest=""
                IFS= read -rsn2 -t 0.01 rest || rest=""
                case "$rest" in
                    '[A') (( cur > 0 )) && cur=$((cur - 1)) ;;
                    '[B') (( cur < n - 1 )) && cur=$((cur + 1)) ;;
                    *)
                        command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
                        return 1
                        ;;
                esac
                ;;
            '')
                command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
                printf '%d' "$cur"
                return 0
                ;;
            q|Q)
                command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
                return 1
                ;;
        esac

        # Redraw: cursor up n lines, then re-emit each option.
        printf '\033[%dA' "$n" >&2
        for ((i = 0; i < n; i++)); do
            printf '\r\033[K' >&2
            if (( i == cur )); then
                printf '  > %s\n' "${options[$i]}" >&2
            else
                printf '    %s\n' "${options[$i]}" >&2
            fi
        done
    done
}

_ui_multi_select_tty() {
    local label="$1" default="$2"
    shift 2
    local options=("$@")
    local n=${#options[@]}
    local cur=0

    # Selected[]: 1 if selected, 0 otherwise.
    local selected=()
    local i
    for ((i = 0; i < n; i++)); do selected+=(0); done
    if [[ -n "$default" ]]; then
        local d
        for d in $(printf '%s' "$default" | tr ',' ' '); do
            if [[ "$d" =~ ^[0-9]+$ ]] && (( d >= 1 && d <= n )); then
                selected[$((d - 1))]=1
            fi
        done
    fi

    command -v tput >/dev/null 2>&1 && tput civis 2>/dev/null
    printf '%s (space to toggle, enter to confirm)\n' "$label" >&2

    _draw() {
        for ((i = 0; i < n; i++)); do
            local mark='[ ]'
            (( selected[i] == 1 )) && mark='[x]'
            if (( i == cur )); then
                printf '  > %s %s\n' "$mark" "${options[$i]}" >&2
            else
                printf '    %s %s\n' "$mark" "${options[$i]}" >&2
            fi
        done
    }
    _draw

    while :; do
        local key=""
        IFS= read -rsn1 key || key=""
        case "$key" in
            $'\x1b')
                local rest=""
                IFS= read -rsn2 -t 0.01 rest || rest=""
                case "$rest" in
                    '[A') (( cur > 0 )) && cur=$((cur - 1)) ;;
                    '[B') (( cur < n - 1 )) && cur=$((cur + 1)) ;;
                    *)
                        command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
                        return 1
                        ;;
                esac
                ;;
            ' ')
                if (( selected[cur] == 1 )); then selected[$cur]=0; else selected[$cur]=1; fi
                ;;
            '')
                command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
                local out=""
                for ((i = 0; i < n; i++)); do
                    (( selected[i] == 1 )) && out="$out $i"
                done
                printf '%s' "${out# }"
                return 0
                ;;
            q|Q)
                command -v tput >/dev/null 2>&1 && tput cnorm 2>/dev/null
                return 1
                ;;
        esac

        printf '\033[%dA' "$n" >&2
        for ((i = 0; i < n; i++)); do
            printf '\r\033[K' >&2
            local mark='[ ]'
            (( selected[i] == 1 )) && mark='[x]'
            if (( i == cur )); then
                printf '  > %s %s\n' "$mark" "${options[$i]}" >&2
            else
                printf '    %s %s\n' "$mark" "${options[$i]}" >&2
            fi
        done
    done
}
