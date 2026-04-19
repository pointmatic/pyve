# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# Variables below are part of this library's public API — they
# are consumed by scripts that source this file, so shellcheck
# cannot see their usage when linting ui.sh on its own.
# shellcheck disable=SC2034
# ──────────────────────────────────────────────────────────────
#  lib/ui.sh — shared UI helpers, colors, and constants.
#
#  Sourced, not executed. Do not add `set -euo pipefail` here —
#  the sourcing script sets its own shell options.
#
#  Respects NO_COLOR=1 (https://no-color.org) by emitting plain
#  text and leaving the symbol variables as unadorned glyphs.
#
#  Backport discipline: this module MUST NOT contain any
#  pyve-specific identifiers, paths, or references. It is
#  intended to be kept in sync verbatim with the sibling
#  `gitbetter` project's copy at lib/ui.sh.
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

# ── Deprecation warning (once per invocation per key) ───────
# Emits a single warning to stderr, formatted like warn() for
# visual continuity. Subsequent calls with the same <key> in
# the same process are suppressed — scripts that invoke a
# deprecated form in a loop stay readable.
#
# Usage: deprecation_warn <key> <old_form> <new_form>
#
# The <key> exists so callers can suppress duplicates even
# when <old_form> / <new_form> vary (e.g. parameterized
# commands). Typical callers pass <old_form> as the key.
declare -A __DEPRECATION_WARNED_KEYS
deprecation_warn() {
    local key="$1"
    local old_form="$2"
    local new_form="$3"
    if [[ -n "${__DEPRECATION_WARNED_KEYS[$key]:-}" ]]; then
        return 0
    fi
    __DEPRECATION_WARNED_KEYS["$key"]=1
    echo -e "  ${WARN} '${old_form}' is deprecated. Use '${new_form}' instead." >&2
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
