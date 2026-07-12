# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/resolution_reasoning.sh — PATH-slot tracing + resolution findings
#
# Pure, offline helpers that explain WHERE a managed command resolves
# from and WHY — the automated version of the manual four-layer trace a
# developer otherwise reconstructs by hand (which PATH slot wins, whether
# the winner drifted from the declared pin, why a version-manager shim
# rejects the command). No mutation, no network; the only execution is a
# bounded `<winner> --version` probe (pyve_run_bounded).
#
# Slot classes (resolution_classify_slot):
#   project-env — an env bin under the project (an activated `<venv>/bin`,
#                 a `.pyve/envs/<name>/<backend>/bin`)
#   local-bin   — ~/.local/bin (pyve's hosted-tool shim slot)
#   vm-shim     — a version-manager shim dir (~/.asdf/shims, ~/.pyenv/shims,
#                 honoring ASDF_DATA_DIR / PYENV_ROOT)
#   system      — everything else
#
# Finding classes (resolution_analyze; the vocabulary the heal mechanism's
# class→repair map consumes):
#   ok             — the winner runs; no contradiction with the pin
#   venv-pin-drift — the winning command is the project env's and its
#                    version differs from the declared pin (the venv is
#                    frozen to its creation-time interpreter; the pin moved)
#   no-version-set — the winner is a version-manager shim that rejects the
#                    command under the active pin ("No version is set")
#   broken-winner  — the winner exists but cannot run (probe failed or was
#                    killed by the bounded runtime)
#   not-found      — no PATH slot provides the command
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Print every PATH dir providing an executable <cmd>, one per line, in
# PATH order — the first line is the winner `command -v` would pick.
# Always returns 0 (empty output = not found).
resolution_path_slots() {
    local cmd="$1"
    local dir
    while IFS= read -r dir; do
        [[ -n "$dir" ]] || continue
        if [[ -x "$dir/$cmd" && ! -d "$dir/$cmd" ]]; then
            printf '%s\n' "$dir"
        fi
    done < <(printf '%s\n' "$PATH" | tr ':' '\n')
    return 0
}

# Classify one PATH dir. Pure string/path logic — no probing.
resolution_classify_slot() {
    local dir="${1%/}"
    local asdf_shims="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
    local pyenv_shims="${PYENV_ROOT:-$HOME/.pyenv}/shims"
    case "$dir" in
        "$asdf_shims"|"$pyenv_shims")
            printf 'vm-shim' ;;
        "$HOME/.local/bin")
            printf 'local-bin' ;;
        "$PWD/"*"/bin"|*/.venv/bin)
            printf 'project-env' ;;
        *)
            printf 'system' ;;
    esac
    return 0
}

# Print "<winner_path>|<slot_class>" for <cmd>; returns 1 when no PATH
# slot provides it.
resolution_winner() {
    local cmd="$1" dir
    dir="$(resolution_path_slots "$cmd" | head -n1)"
    [[ -n "$dir" ]] || return 1
    printf '%s|%s' "$dir/$cmd" "$(resolution_classify_slot "$dir")"
}

# Analyze <cmd> against an optional declared <pin> version. Prints one
# machine-parseable line: "<finding>|<winner_path>|<slot_class>|<version>|<pin>"
# (fields empty where not applicable). Always returns 0 — the finding
# class carries the signal; callers decide severity.
resolution_analyze() {
    local cmd="$1" pin="${2:-}"
    local winner path cls
    if ! winner="$(resolution_winner "$cmd")"; then
        printf 'not-found||||%s' "$pin"
        return 0
    fi
    path="${winner%%|*}"
    cls="${winner##*|}"
    local out rc=0 ver=""
    out="$(pyve_run_bounded "$path" --version)" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        if printf '%s' "$out" | grep -qiE 'no version (is )?set'; then
            printf 'no-version-set|%s|%s||%s' "$path" "$cls" "$pin"
        else
            printf 'broken-winner|%s|%s||%s' "$path" "$cls" "$pin"
        fi
        return 0
    fi
    ver="$(printf '%s\n' "$out" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true)"
    if [[ -n "$pin" && "$cls" == "project-env" && -n "$ver" && "$ver" != "$pin" ]]; then
        printf 'venv-pin-drift|%s|%s|%s|%s' "$path" "$cls" "$ver" "$pin"
        return 0
    fi
    printf 'ok|%s|%s|%s|%s' "$path" "$cls" "$ver" "$pin"
    return 0
}
