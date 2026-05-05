# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# Variables below are part of this library's public API — they
# are consumed by scripts that source this file, so shellcheck
# cannot see their usage when linting this module on its own.
# shellcheck disable=SC2034
# ──────────────────────────────────────────────────────────────
#  lib/ui/core.sh — core module of the extractable lib/ui/
#  library: shared UI helpers, colors, and constants.
#
#  Sourced, not executed. Do not add `set -euo pipefail` here —
#  the sourcing script sets its own shell options.
#
#  Respects NO_COLOR=1 (https://no-color.org) by emitting plain
#  text and leaving the symbol variables as unadorned glyphs.
#
#  Library boundary: every module under lib/ui/ stays
#  pyve-agnostic — no pyve paths, command names, or config keys.
#  The directory is the seam along which this UX library can
#  eventually be extracted for reuse in sibling tools.
# ──────────────────────────────────────────────────────────────

# ── Colors & Symbols ─────────────────────────────────────────
if [[ -n "${NO_COLOR:-}" ]]; then
    R=""              G=""              Y=""
    B=""              C=""              M=""
    DIM=""            BOLD=""           RESET=""
    CHECK="✔"         CROSS="✘"         ARROW="▸"
    WARN="⚠"
else
    R=$'\033[0;31m'   G=$'\033[0;32m'   Y=$'\033[0;33m'
    B=$'\033[0;34m'   C=$'\033[0;36m'   M=$'\033[0;35m'
    DIM=$'\033[2m'    BOLD=$'\033[1m'   RESET=$'\033[0m'
    CHECK="${G}✔${RESET}"   CROSS="${R}✘${RESET}"   ARROW="${C}▸${RESET}"
    WARN="${Y}⚠${RESET}"
fi

# ── Helpers ──────────────────────────────────────────────────
banner()  { echo -e "\n${B}${BOLD}── $1 ──${RESET}"; }
info()    { echo -e "  ${ARROW} $1"; }
success() { echo -e "  ${CHECK} $1"; }
warn()    { echo -e "  ${WARN} $1"; }
fail()    { echo -e "\n  ${CROSS} ${R}$1${RESET}\n"; exit 1; }

# Prompt with default Y. Returns 0 for yes; exits 0 (not an
# error) for anything else so the caller's `set -e` does not
# treat an intentional abort as a failure.
confirm() {
    local prompt="${1:-Continue}"
    local answer
    echo ""
    read -rp "  ${Y}${prompt} [Y/n]${RESET} " answer
    answer="${answer:-y}"
    if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
        echo -e "\n  ${DIM}Aborted.${RESET}\n"
        exit 0
    fi
}

# Prompt with default N. Returns 0 for yes, 1 for no. Never
# exits — the caller decides what "no" means in context.
ask_yn() {
    local prompt="${1:-Proceed}"
    local answer
    echo ""
    read -rp "  ${Y}${prompt} [y/N]${RESET} " answer
    answer="${answer:-n}"
    [[ "${answer}" =~ ^[Yy]$ ]]
}

divider() { echo -e "  ${DIM}─────────────────────────────────────────${RESET}"; }

# Echo the command in dimmed style, then execute it. The
# executed command's exit status is the caller's exit status.
run_cmd() {
    echo -e "  ${DIM}\$ $*${RESET}"
    "$@"
}

# ── Edit distance (Levenshtein, bash-3.2 safe) ──────────────
# Returns the Levenshtein distance between two strings on
# stdout. Used by callers to pick a "did you mean?" suggestion
# for typo'd flags or subcommands.
#
# Implementation uses a flat 1-D array to simulate a 2-D DP
# table so it stays compatible with macOS's system bash 3.2
# (no associative arrays required).
_edit_distance() {
    local s1="$1" s2="$2"
    local m=${#s1} n=${#s2}
    local i j cost del ins sub min
    local -a d

    local stride=$((n + 1))
    for ((i = 0; i <= m; i++)); do d[i * stride]=$i; done
    for ((j = 0; j <= n; j++)); do d[j]=$j; done

    for ((i = 1; i <= m; i++)); do
        for ((j = 1; j <= n; j++)); do
            if [[ "${s1:i-1:1}" == "${s2:j-1:1}" ]]; then
                cost=0
            else
                cost=1
            fi
            del=$(( d[(i - 1) * stride + j] + 1 ))
            ins=$(( d[i * stride + (j - 1)] + 1 ))
            sub=$(( d[(i - 1) * stride + (j - 1)] + cost ))
            min=$del
            (( ins < min )) && min=$ins
            (( sub < min )) && min=$sub
            d[i * stride + j]=$min
        done
    done

    echo "${d[m * stride + n]}"
}

# ── Rounded-corner boxes ─────────────────────────────────────
# Internal box width is 41 visible chars (between │…│); content
# area after leading "  " is 39 chars, so pad with (39 - title_len) spaces.

header_box() {
    local title="$1"
    local pad_len=$(( 39 - ${#title} ))
    local pad
    printf -v pad '%*s' "${pad_len}" ""
    echo -e "  ${BOLD}${C}╭─────────────────────────────────────────╮${RESET}"
    echo -e "  ${BOLD}${C}│${RESET}  ${BOLD}${title}${RESET}${pad}${BOLD}${C}│${RESET}"
    echo -e "  ${BOLD}${C}╰─────────────────────────────────────────╯${RESET}"
}

footer_box() {
    echo -e "  ${BOLD}${G}╭─────────────────────────────────────────╮${RESET}"
    echo -e "  ${BOLD}${G}│${RESET}  ${CHECK} ${BOLD}All done.${RESET}                            ${BOLD}${G}│${RESET}"
    echo -e "  ${BOLD}${G}╰─────────────────────────────────────────╯${RESET}"
}
