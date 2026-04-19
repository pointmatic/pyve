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

# ── Rename announcements (once per invocation per key) ──────
# Two helpers for rename-on-the-way-to-removal situations:
#
#   deprecation_warn  — old form still runs its own code; the
#                       user is advised to switch. Glyph ⚠.
#   delegation_warn   — old form has been re-routed to a new
#                       command; stating the redirect plainly.
#                       No glyph, stated as a transparent note.
#
# Both:
#   - write to stderr (never stdout — scripts parsing stdout
#     stay clean);
#   - guard duplicates with a shared <key> space so the same
#     rename can't fire twice even if one caller picks
#     `deprecation_warn` and another picks `delegation_warn`;
#   - include the exact replacement command, not a `--help`
#     reference.
#
# The guard uses a colon-delimited flat string (not `declare
# -A`) so lib/ui.sh works under macOS's system bash 3.2.
# Keys must not contain ':' — locked by an invariant test in
# tests/unit/test_ui.bats.
__DEPRECATION_WARNED_KEYS=""

_rename_seen() {
    # _rename_seen <key> — returns 0 if <key> was already
    # announced in this invocation, 1 otherwise. On first
    # sight records <key> and returns 1.
    local key="$1"
    case ":${__DEPRECATION_WARNED_KEYS}:" in
        *":${key}:"*) return 0 ;;
    esac
    __DEPRECATION_WARNED_KEYS="${__DEPRECATION_WARNED_KEYS}:${key}"
    return 1
}

deprecation_warn() {
    local key="$1" old_form="$2" new_form="$3"
    _rename_seen "$key" && return 0
    echo -e "  ${WARN} '${old_form}' is deprecated. Use '${new_form}' instead." >&2
}

delegation_warn() {
    local key="$1" old_form="$2" new_form="$3"
    _rename_seen "$key" && return 0
    echo -e "${old_form}: renamed to '${new_form}'. Running '${new_form}' now..." >&2
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
