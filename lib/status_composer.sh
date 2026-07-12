# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/status_composer.sh — composed `pyve status` builder
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
# Project-level [project-guide] addendum — the SOLE project-guide readout
# in `pyve status` (the v2-era `[python]` Integrations row, which probed
# the project venv where v3 never installs project-guide, was removed as
# contradictory). Any-stack (composer-level, not bound to the python
# plugin), informational like the rest of status.
#
# One line, version-bearing; versions come from RUNNABILITY probes
# (executing `<bin> --version`), never a bare `-x`. Modes:
#   local pip|conda [vX]    — the project owns its copy: declared in its
#       dep files and/or installed into the project env (the v2-era
#       location). Wins the label over pyve-hosted — it is how THIS
#       project uses the tool; a hosted copy is still named inline.
#   pyve-hosted (toolchain) [vX] — pyve manages a global copy. A hosted
#       copy that cannot exec (dangling shim / dead shebang) is reported
#       broken with a repair hint, never as healthy.
#   not installed           — neither.
# Silent in piecemeal test subshells where the helpers aren't sourced.
_compose_status_project_guide() {
    declare -F pyve_project_guide_is_hosted >/dev/null 2>&1 || return 0
    local src local_bin local_ver="" mode hint=""
    src="$(project_guide_deps_source 2>/dev/null || true)"
    local_bin="$(_status_project_guide_local_bin)"
    if [[ -n "$local_bin" ]] && declare -F pyve_runnable_version >/dev/null 2>&1; then
        local_ver="$(pyve_runnable_version "$local_bin" 2>/dev/null || true)"
    fi

    local hosted=0 hosted_runnable=0 hosted_ver=""
    if pyve_project_guide_is_hosted 2>/dev/null; then
        hosted=1
        if hosted_ver="$(pyve_project_guide_runnable 2>/dev/null)"; then
            hosted_runnable=1
        else
            hosted_ver=""
        fi
    fi

    if [[ -n "$src" || -n "$local_bin" ]]; then
        mode="local ${src:-pip}"
        [[ -n "$local_ver" ]] && mode+=" v${local_ver}"
        if [[ -n "$src" && -z "$local_bin" ]]; then
            mode+=" (declared in project deps, not installed yet)"
        elif [[ -n "$src" ]]; then
            mode+=" (declared in project deps)"
        fi
        if [[ "$hosted" -eq 1 ]]; then
            mode+=" · also pyve-hosted (toolchain)"
            [[ -n "$hosted_ver" ]] && mode+=" v${hosted_ver}"
        fi
    elif [[ "$hosted" -eq 1 && "$hosted_runnable" -eq 1 ]]; then
        mode="pyve-hosted (toolchain)"
        [[ -n "$hosted_ver" ]] && mode+=" v${hosted_ver}"
        hint="  Upgrade: 'pyve self provision'  ·  Remove: 'pyve self unprovision --all'"
    elif [[ "$hosted" -eq 1 ]]; then
        mode="pyve-hosted (toolchain) — broken (installed but not runnable)"
        hint="  Repair: 'pyve self provision'"
    else
        mode="not installed"
        hint="  Run 'pyve self provision' to install Project-Guide (Pyve-hosted)."
    fi
    printf '[project-guide]\n'
    printf '  %s\n' "$mode"
    [[ -n "$hint" ]] && printf '%s\n' "$hint"
    printf '\n'
    return 0
}

# Locate a project-local project-guide binary (the v2-era "local pip"
# install location), backend-aware: a micromamba root → the root conda
# slot via the NON-MUTATING resolver (status is a read path; it must not
# fire the opportunistic layout migrator), anything else → the venv
# directory. Prints the binary path when an executable exists there;
# empty otherwise. Always returns 0.
_status_project_guide_local_bin() {
    local backend="" env_path=""
    declare -F manifest_get_backend >/dev/null 2>&1 \
        && backend="$(manifest_get_backend root 2>/dev/null || true)"
    if [[ "$backend" == "micromamba" ]]; then
        declare -F resolve_main_micromamba_path >/dev/null 2>&1 \
            && env_path="$(resolve_main_micromamba_path 2>/dev/null || true)"
    else
        declare -F resolve_venv_directory >/dev/null 2>&1 \
            && env_path="$(resolve_venv_directory 2>/dev/null || true)"
        [[ -z "$env_path" ]] && env_path=".venv"
    fi
    if [[ -n "$env_path" && -x "$env_path/bin/project-guide" ]]; then
        printf '%s' "$env_path/bin/project-guide"
    fi
    return 0
}

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

        # a plugin that contributes nothing (e.g. the Python
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

    # project-guide integration mode (Story N.bi) — project-level, any-stack.
    _compose_status_project_guide

    # project-level advisory addendum (spec-ahead attributes
    # recorded in pyve.toml, not materialized). Informational, like the rest
    # of status; absent when there are no advisory attributes.
    local adv_out
    adv_out="$(manifest_advisory_notes)"
    if [[ -n "$adv_out" ]]; then
        printf '[advisories]\n'
        printf '%s\n' "$adv_out"
        printf '\n'
    fi

    return 0
}
