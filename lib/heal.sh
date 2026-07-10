# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/heal.sh — the `pyve check --fix` heal engine
#
# Healing is check's verdicts acted upon: detect faults with the same
# runnability probes `pyve check` reports from, enumerate a plan (what is
# broken → what will be done), then repair only with assent. The engine
# NEVER silently mutates: non-interactive runs without `--yes` are
# report-only, and interactive runs confirm the batch before acting.
# Repairs route through existing machinery (the `self provision` verb,
# the shared shim-link helper) — heal orchestrates, it does not grow a
# parallel rebuild path. Idempotent: a re-run after a successful repair
# finds nothing to heal.
#
# Class → repair map, non-destructive tier (Pyve-owned hosting state,
# deterministically rebuildable — no user data at risk):
#
#   toolchain-dead     — the version-keyed toolchain venv exists but its
#                        interpreter cannot run (dead symlink / deleted
#                        base interpreter). Repair: remove the venv and
#                        rebuild via the provision verb. The provisioning
#                        machinery alone can NOT do this: its fast paths
#                        are presence-gated ([[ -x ]]), so a dead venv is
#                        skipped, not rebuilt — heal closes that gap.
#   project-guide-dead — the hosted console script exists under a
#                        RUNNABLE toolchain but cannot run itself.
#                        Repair: force-reinstall into the toolchain venv
#                        (pip --force-reinstall; a plain --upgrade no-ops
#                        on a satisfied-but-broken install) + re-link.
#   shim-dangling      — ~/.local/bin/project-guide is a symlink whose
#                        target is gone while the hosted script is
#                        runnable. Repair: re-link (ln -sf refresh).
#
# NOT faults (deliberate non-goals):
#   - never-provisioned hosting — optional by contract; a hint in
#     `pyve check`, not breakage;
#   - project-managed project-guide — a deps-source declaration means
#     pyve defers ("not my department"); project-guide faults are
#     suppressed, toolchain faults remain Pyve's own;
#   - healthy-but-stale versions — staleness is never healed; repair is
#     not an upgrade path.
#
# The destructive tier (project-env rebuilds, orphan removal) rides the
# same plan-then-confirm frame with per-repair confirmation.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Enumerate detected faults, one machine-parseable line each:
#   <class>|<human description>|<repair description>
# Read-only (probes execute artifacts but write nothing); empty output
# when there is nothing to heal. Silent in piecemeal test subshells
# where the toolchain module isn't sourced.
heal_plan() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0
    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"

    # Toolchain venv: a fault only when materialized-but-broken. Absent =
    # never provisioned = not a fault. The probe honors PYVE_PYTHON, so an
    # explicit override (the venv deliberately not in play) masks nothing
    # that matters.
    local toolchain_runnable=0
    if pyve_toolchain_runnable >/dev/null 2>&1; then
        toolchain_runnable=1
    fi
    if [[ -d "$venv_dir" && "$toolchain_runnable" -eq 0 ]]; then
        printf 'toolchain-dead|toolchain venv cannot run (%s)|remove it and re-provision (self provision machinery)\n' "$venv_dir"
        # Its repair rebuilds hosting wholesale (project-guide + shim
        # included), so the finer-grained faults below are subsumed.
        return 0
    fi

    # project-guide faults are Pyve's department only when the project
    # does not own the tool via a deps source.
    if declare -F project_guide_deps_source >/dev/null 2>&1; then
        local src
        src="$(project_guide_deps_source 2>/dev/null || true)"
        [[ -n "$src" ]] && return 0
    fi
    # An explicit override is the resolver everywhere else honors first;
    # hosting is not in play under it.
    [[ -n "${PYVE_PROJECT_GUIDE_BIN:-}" ]] && return 0

    local hosted_pg="$venv_dir/bin/project-guide"
    local hosted_pg_runnable=0
    if [[ -e "$hosted_pg" ]]; then
        if pyve_runnable_version "$hosted_pg" >/dev/null 2>&1; then
            hosted_pg_runnable=1
        else
            printf 'project-guide-dead|hosted project-guide cannot run (%s)|force-reinstall into the toolchain venv and re-link the shim\n' "$hosted_pg"
        fi
    fi

    # Shim: a fault only when dangling (a symlink whose target is gone)
    # while the hosted script it should point at is runnable. Absent =
    # never linked = not a fault; broken hosting is the faults above.
    local shim="$HOME/.local/bin/project-guide"
    if [[ -L "$shim" && ! -e "$shim" && "$hosted_pg_runnable" -eq 1 ]]; then
        printf 'shim-dangling|~/.local/bin/project-guide is a dead symlink|re-link it at the hosted console script\n'
    fi
    return 0
}

# Apply the repair for one fault class. Returns 0 when the repair landed
# AND the re-probe confirms runnable state; non-zero otherwise.
heal_apply() {
    local class="$1"
    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"
    case "$class" in
        toolchain-dead)
            rm -rf "$venv_dir"
            if declare -F self_provision >/dev/null 2>&1; then
                self_provision >/dev/null 2>&1 || true
            else
                declare -F pyve_toolchain_python_ensure >/dev/null 2>&1 \
                    && { pyve_toolchain_python_ensure >/dev/null 2>&1 || true; }
                declare -F pyve_project_guide_ensure >/dev/null 2>&1 \
                    && { pyve_project_guide_ensure >/dev/null 2>&1 || true; }
            fi
            pyve_toolchain_runnable >/dev/null 2>&1
            ;;
        project-guide-dead)
            local pip="$venv_dir/bin/pip"
            [[ -x "$pip" ]] || return 1
            "$pip" install --upgrade --force-reinstall 'project-guide>=2.15.0' >/dev/null 2>&1 || return 1
            pyve_link_project_guide_shim "$venv_dir"
            pyve_runnable_version "$venv_dir/bin/project-guide" >/dev/null 2>&1
            ;;
        shim-dangling)
            pyve_link_project_guide_shim "$venv_dir"
            [[ -e "$HOME/.local/bin/project-guide" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Plan-then-confirm driver. <assent>=1 means `--yes` was passed (batch
# assent). Interactive runs without assent get one batch prompt for the
# non-destructive tier; non-interactive runs without assent are
# REPORT-ONLY — never mutate unattended. Returns non-zero only when an
# assented repair failed (re-run to retry — the plan is recomputed from
# live probes, so completed repairs drop out).
heal_run() {
    local assent="${1:-0}"
    local plan
    plan="$(heal_plan)"
    if [[ -z "$plan" ]]; then
        printf 'Nothing to heal.\n'
        return 0
    fi

    printf 'Detected fault(s) and intended repair(s):\n'
    local class desc repair
    while IFS='|' read -r class desc repair; do
        [[ -n "$class" ]] || continue
        printf '  ✗ [%s] %s\n' "$class" "$desc"
        printf '    → %s\n' "$repair"
    done <<<"$plan"

    if [[ "$assent" != "1" ]]; then
        if [[ -t 0 && -t 1 ]] && declare -F prompt_yes_no >/dev/null 2>&1; then
            if ! prompt_yes_no "Apply these repair(s)?"; then
                printf 'No repairs applied.\n'
                return 0
            fi
        else
            printf 'Report-only (no assent): re-run with --yes to apply these repairs.\n'
            return 0
        fi
    fi

    local healed=0 failed=0
    while IFS='|' read -r class desc repair; do
        [[ -n "$class" ]] || continue
        if heal_apply "$class"; then
            printf '  ✓ healed [%s]\n' "$class"
            healed=$((healed + 1))
        else
            printf '  ✗ repair failed [%s] — re-run '\''pyve check --fix'\'' to retry\n' "$class"
            failed=$((failed + 1))
        fi
    done <<<"$plan"

    if [[ "$failed" -gt 0 ]]; then
        printf '%d repair(s) applied, %d failed.\n' "$healed" "$failed"
        return 1
    fi
    printf '%d repair(s) applied.\n' "$healed"
    return 0
}
