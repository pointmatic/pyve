# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/status_composer.sh — composed `pyve status` builder (Story N.ah)
#
# The informational sibling of lib/check_composer.sh. Iterates every active
# plugin, dispatches its `pyve_plugin_status` hook, and emits a per-plugin
# (path-aware) section. Unlike `pyve check`, status has NO severity ladder:
# it reports reality and ALWAYS exits 0 — a broken-environment reading is
# `pyve check`'s job (status is the read-only snapshot, per phase-H design).
#
#   compose_status [args]  — orchestrate per-plugin status sections
#
# Section labels mirror the check composer: visitor plugins (path != ".")
# are prefixed with their path (`[node @ src/frontend]`) for monorepo
# disambiguation; root plugins get a bare label (`[python]`).
#
# No-Python noise suppression seam (shared with N.ag, refined in N.aj): the
# composer only dispatches plugins in `plugin_list_active`, so a Node-only
# project never surfaces a Python section.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Orchestrate per-plugin status sections. Always returns 0; usage errors
# (unknown flag / positional argument) exit 1 via the shared helpers,
# mirroring the pre-composition `show_status`.
compose_status() {
    # Argument validation moved here from show_status when the composer
    # took over dispatch. `--help` / `-h` are handled by the dispatcher in
    # pyve.sh before compose_status is reached.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "status" "$1" --help
                ;;
            *)
                log_error "pyve status takes no positional arguments (got: $1)"
                log_error "See: pyve status --help"
                exit 1
                ;;
        esac
    done

    # Top-level title — owned by the composer so per-plugin sections don't
    # each reprint it. BOLD title + DIM rule, matching the phase-H design.
    printf "\n%sPyve project status%s\n" "${BOLD:-}" "${RESET:-}"
    printf "%s───────────────────%s\n\n" "${DIM:-}" "${RESET:-}"

    # Signal dispatched hooks that the composer owns the top-level title, so
    # a plugin's own status (the Python plugin's show_status) does not
    # reprint it. Exported so it crosses the command-substitution subshell.
    export PYVE_STATUS_COMPOSED=1

    local name path label out
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        path="$(manifest_get_plugin_path "$name" 2>/dev/null || true)"
        [[ -z "$path" ]] && path="."

        # Capture in a subshell so a hook that calls `exit` (defensive: some
        # plugin status paths may) cannot tear down the composer, and so the
        # composer owns the per-section framing. Status is informational, so
        # the hook's return code is intentionally ignored.
        out="$(plugin_dispatch "$name" status "$path" 2>&1)" || true

        # Story N.aj: a plugin that contributes nothing (e.g. the Python
        # plugin suppressed by the PC-4a gate) gets no section — no empty
        # `[plugin]` header in the composed status output.
        [[ -z "$out" ]] && continue

        if [[ "$path" == "." ]]; then
            label="$name"
        else
            label="$name @ $path"
        fi
        printf '[%s]\n' "$label"
        printf '%s\n' "$out"

        printf '\n'
    done < <(plugin_list_active)

    return 0
}
