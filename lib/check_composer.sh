# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/check_composer.sh — composed `pyve check` builder
#
# The `pyve check` sibling of lib/envrc_composer.sh / lib/gitignore_composer.sh.
# Iterates every active plugin, dispatches its `pyve_plugin_check` hook,
# emits a per-plugin (path-aware) section, and computes the worst severity
# across all plugins on the pass / warn / error ladder.
#
#   compose_check [args]  — orchestrate per-plugin checks + severity roll-up
#
# Severity ladder. Each plugin's check hook returns a code; the composer
# maps it to a severity ordinal and takes the worst across plugins:
#
#   rc 0            → pass  (clean)
#   rc 2            → warn  (advisory; e.g. version drift, missing .env)
#   rc 1 / other    → error (genuine failure; env broken for run / test)
#
# This matches the long-standing internal exit codes of `check_environment`
# (0 pass / 1 error / 2 warn) and the Node plugin's 0/1 (pass / error)
# convention — the composer interprets them without rewriting either hook.
#
# Process exit semantics (the composed roll-up):
#   error present → exit 2 (nonzero; CI fails the build)
#   warn-only     → exit 0 (advisory text, non-failing)
#   all pass      → exit 0 (clean)
#
# Note the deliberate divergence from the pre-composition single-plugin
# contract (error → 1, warn → 2): warnings no longer fail CI, and the
# error exit code is 2. The composed surface is the authoritative one
# from v3.0 onward.
#
# No-Python noise suppression seam (full impl in N.aj): the composer only
# runs checks for plugins in `plugin_list_active`. A Node-only project that
# declares `[plugins.node]` (and no Python) never registers the Python
# plugin, so its check hook contributes nothing — the active-plugin gate
# is the seam N.aj refines with file-level detection.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Severity ordinals — ordered so `worst = max()` is correct.
PYVE_CHECK_SEV_PASS=0
PYVE_CHECK_SEV_WARN=1
PYVE_CHECK_SEV_ERROR=2

# Map a plugin check hook's return code to a severity ordinal.
_compose_check_rc_to_severity() {
    case "$1" in
        0) printf '%s' "$PYVE_CHECK_SEV_PASS" ;;
        2) printf '%s' "$PYVE_CHECK_SEV_WARN" ;;
        *) printf '%s' "$PYVE_CHECK_SEV_ERROR" ;;  # rc 1 and any other nonzero
    esac
}

# Human label for a severity ordinal (roll-up footer).
_compose_check_sev_label() {
    case "$1" in
        "$PYVE_CHECK_SEV_PASS")  printf 'pass' ;;
        "$PYVE_CHECK_SEV_WARN")  printf 'warnings' ;;
        *)                       printf 'errors' ;;
    esac
}

# project-level env-spec drift check.
#
# Drift = pyve.toml lags the project-guide env-dependencies §4.0 surface.
# A spec-ahead project is a LEGITIMATE steady state, so drift is surfaced at
# WARN (rc 2 → warn → process exit 0), never error. This is a project-level
# concern (not owned by any single plugin), hence it lives in the composer
# rather than a plugin check hook.
#
# Prints a human drift summary + remediation hint on stdout and returns 2
# when pyve.toml is behind the spec; returns 0 with no output when in sync,
# when no spec exists, or when the diff cannot be computed (missing
# toolchain libs / unreadable spec — drift is then undetermined, never a
# failure). The `declare -F` guards keep it silent in piecemeal test
# subshells where env.sh / project_guide.sh aren't sourced.
_compose_check_env_spec_drift() {
    declare -F project_guide_env_spec_path >/dev/null 2>&1 || return 0
    declare -F _env_sync_run_helper >/dev/null 2>&1 || return 0
    [[ -f pyve.toml ]] || return 0

    local spec_path out rc=0
    spec_path="$(project_guide_env_spec_path)"
    out="$(_env_sync_run_helper diff --human "$spec_path" pyve.toml 2>/dev/null)" || rc=$?

    # rc 10 (non-destructive) / 11 (destructive) → changes present → warn.
    # Everything else (0 clean, 2 no-spec, 3 libs-missing, 4/5 unreadable)
    # contributes no section.
    case "$rc" in
        10|11)
            printf '%s\n' "$out"
            printf "Run 'pyve env sync' to reconcile pyve.toml with the env spec.\n"
            return 2
            ;;
    esac
    return 0
}

# Story N.bi: environment-level [pyve] addendum — reports the hosted
# toolchain Python + project-guide hosting state. INFO-ONLY by contract:
# hosting is optional (pyve falls back to bare `python` and lazily
# provisions project-guide on first use), so this NEVER contributes to the
# severity verdict — the composer prints it without reading a return code
# into `worst`, and the helper always returns 0. The "not provisioned"
# project-guide line carries a remediation hint ONLY when project-guide is
# not project-managed (a project dep means pyve intentionally defers). The
# `declare -F` guards keep it silent in piecemeal test subshells.
_compose_check_pyve_hosting() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0
    declare -F pyve_project_guide_is_hosted >/dev/null 2>&1 || return 0

    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"
    if [[ -x "$venv_dir/bin/python" ]]; then
        printf 'Toolchain Python: provisioned (%s)\n' "${DEFAULT_PYTHON_VERSION:-unknown}"
    else
        printf 'Toolchain Python: not provisioned (falls back to python on PATH)\n'
    fi

    local src
    src="$(project_guide_deps_source 2>/dev/null || true)"
    if [[ -n "$src" ]]; then
        printf 'project-guide: managed by your project (%s)\n' "$src"
    elif pyve_project_guide_is_hosted 2>/dev/null; then
        printf 'project-guide hosting: provisioned\n'
        printf "  Upgrade: 'pyve self provision'  ·  Remove: 'pyve self unprovision --all'\n"
    else
        printf 'project-guide hosting: not provisioned\n'
        printf "  Run 'pyve self provision' to install the Pyve toolchain + Project-Guide.\n"
    fi
    return 0
}

# Orchestrate per-plugin checks and roll up the worst severity.
#
# Returns 2 when any plugin reports an error; 0 otherwise (warn-only or
# all-pass). Usage errors (unknown flag / positional argument) exit 1 via
# the shared helpers, mirroring the pre-composition `check_environment`.
compose_check() {
    # Argument validation lives here now (it left check_environment when
    # the composer took over dispatch). `--help` / `-h` are handled by the
    # dispatcher in pyve.sh before compose_check is reached.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "check" "$1" --help
                ;;
            *)
                log_error "pyve check takes no positional arguments (got: $1)"
                log_error "See: pyve check --help"
                exit 1
                ;;
        esac
    done

    printf "Pyve Environment Check\n"
    printf "======================\n\n"

    # Signal dispatched hooks that the composer owns the top-level banner,
    # so a plugin's own check (e.g. the Python plugin's check_environment)
    # does not reprint it. Exported so it crosses the command-substitution
    # subshell used to capture each section's output.
    export PYVE_CHECK_COMPOSED=1

    local worst="$PYVE_CHECK_SEV_PASS"
    local count=0
    local name path label out rc sev

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        path="$(manifest_get_plugin_path "$name" 2>/dev/null || true)"
        [[ -z "$path" ]] && path="."

        # Run the hook in a subshell (command substitution) for two
        # reasons: (1) the Python plugin's check hook calls `exit` via
        # check_environment, which would tear down the composer mid-loop;
        # the subshell turns that into a captured return code. (2) Capturing
        # the combined output lets the composer own section framing.
        # `|| rc=$?` keeps `set -e` from aborting the composer when a hook
        # exits nonzero (the Python plugin's check_environment exits 1/2);
        # the failure code is captured rather than propagated.
        rc=0
        out="$(plugin_dispatch "$name" check "$path" 2>&1)" || rc=$?

        # a plugin that contributes nothing (e.g. the Python
        # plugin suppressed by the PC-4a gate) gets no section at all — the
        # composed output stays free of empty `[plugin]` headers.
        if [[ -z "$out" ]]; then
            continue
        fi
        count=$((count + 1))

        # Path-aware section header: visitor plugins (path != ".") are
        # prefixed with their path so monorepo output disambiguates which
        # tree a finding belongs to (e.g. `[node @ src/frontend]`).
        if [[ "$path" == "." ]]; then
            label="$name"
        else
            label="$name @ $path"
        fi
        printf '[%s]\n' "$label"
        printf '%s\n' "$out"

        sev="$(_compose_check_rc_to_severity "$rc")"
        (( sev > worst )) && worst="$sev"

        printf '\n'
    done < <(plugin_list_active)

    # project-level env-spec drift addendum (not a plugin, so
    # it is not counted in the plugin tally). Warn-only by contract.
    local drift_out drift_rc=0
    drift_out="$(_compose_check_env_spec_drift)" || drift_rc=$?
    if [[ -n "$drift_out" ]]; then
        printf '[env-spec]\n'
        printf '%s\n' "$drift_out"
        sev="$(_compose_check_rc_to_severity "$drift_rc")"
        (( sev > worst )) && worst="$sev"
        printf '\n'
    fi

    # project-level advisory addendum (spec-ahead attributes
    # recorded in pyve.toml, not materialized). Purely informational — never
    # affects severity; absent when there are no advisory attributes.
    local adv_out
    adv_out="$(manifest_advisory_notes)"
    if [[ -n "$adv_out" ]]; then
        printf '[advisories]\n'
        printf '%s\n' "$adv_out"
        printf '\n'
    fi

    # environment-level [pyve] addendum (Story N.bi) — hosted toolchain +
    # project-guide hosting. INFO-ONLY: deliberately does NOT touch `worst`,
    # so an unprovisioned (optional) toolchain never affects the verdict.
    local pyve_out
    pyve_out="$(_compose_check_pyve_hosting)"
    if [[ -n "$pyve_out" ]]; then
        printf '[pyve]\n'
        printf '%s\n' "$pyve_out"
        printf '\n'
    fi

    # Roll-up footer — the single worst-severity verdict across all plugins.
    printf '======================\n'
    printf 'Overall: %s (%d plugin(s) checked)\n' "$(_compose_check_sev_label "$worst")" "$count"

    if (( worst >= PYVE_CHECK_SEV_ERROR )); then
        return 2
    fi
    return 0
}
