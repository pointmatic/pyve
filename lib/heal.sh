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
# Class → repair map, destructive tier (project-env state; destroys a
# materialized tree before recreating it — so confirm-before-destroy,
# individually):
#
#   env-dead-root — the root env's canary verdict is in the broken family
#                   (dead-shebang / dangling-symlink / missing-interpreter
#                   / broken). Repair: `pyve init --force` — the root-only
#                   rebuild verb (the `pyve env` namespace rejects `root`).
#   env-dead      — a declared named env's canary verdict is broken.
#                   Repair: `pyve env init <name> --force` (one-shot
#                   purge + re-create + re-materialize from the declared
#                   recipe).
#   env-drift     — the root venv runs, but its interpreter version
#                   differs from the declared pin (venv frozen to its
#                   creation-time interpreter; the pin moved). Repair:
#                   `pyve init --force`, rebuilding toward the pin.
#                   Suppressed when a root rebuild is already planned —
#                   one repair, not two.
#   env-orphan    — a materialized tree the manifest does not declare
#                   (an undeclared `.pyve/envs/<name>/`, or a tree under
#                   an advisory root that cannot be materialized — the
#                   state↔declaration contradiction). Repair: remove the
#                   tree; the manifest is canonical.
#
# Destructive-tier ground rules: each repair is INDIVIDUALLY confirmed
# in an interactive run (`--yes` assents to those prompts too, per the
# uniform prompt-skip semantics); a NON-INTERACTIVE run never destroys —
# even with `--yes`, destructive repairs are reported and skipped, so CI
# can run `check --fix --yes` and only ever get the non-destructive tier.
# Declining one repair skips only that repair. Rebuilds route through the
# role-correct verbs and restore toward the declared manifest intent —
# never `pyve env purge root`, never a guess.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Enumerate detected faults, one machine-parseable line each:
#   <class>|<arg>|<human description>|<repair description>
# <arg> is the repair operand (an env name or a tree path; empty for the
# hosting classes). Read-only (probes execute artifacts but write
# nothing); empty output when there is nothing to heal. Silent in
# piecemeal test subshells where the toolchain module isn't sourced.
heal_plan() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0
    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"

    # Toolchain venv: a fault only when materialized-but-broken. Absent =
    # never provisioned = not a fault. The probe honors PYVE_PYTHON, so an
    # explicit override (the venv deliberately not in play) masks nothing
    # that matters.
    local toolchain_dead=0 toolchain_runnable=0
    if pyve_toolchain_runnable >/dev/null 2>&1; then
        toolchain_runnable=1
    fi
    if [[ -d "$venv_dir" && "$toolchain_runnable" -eq 0 ]]; then
        toolchain_dead=1
        printf 'toolchain-dead||toolchain venv cannot run (%s)|remove it and re-provision (self provision machinery)\n' "$venv_dir"
        # Its repair rebuilds hosting wholesale (project-guide + shim
        # included), so the finer-grained hosting faults are subsumed.
    fi

    if [[ "$toolchain_dead" -eq 0 ]]; then
        _heal_plan_project_guide "$venv_dir"
    fi

    _heal_plan_project_envs
    return 0
}

# Hosting faults below the toolchain: the hosted project-guide script and
# its ~/.local/bin shim. Pyve's department only when the project does not
# own the tool via a deps source, and only when no explicit override (the
# resolver everywhere else honors first) puts hosting out of play.
_heal_plan_project_guide() {
    local venv_dir="$1"
    if declare -F project_guide_deps_source >/dev/null 2>&1; then
        local src
        src="$(project_guide_deps_source 2>/dev/null || true)"
        [[ -n "$src" ]] && return 0
    fi
    [[ -n "${PYVE_PROJECT_GUIDE_BIN:-}" ]] && return 0

    local hosted_pg="$venv_dir/bin/project-guide"
    local hosted_pg_runnable=0
    if [[ -e "$hosted_pg" ]]; then
        if pyve_runnable_version "$hosted_pg" >/dev/null 2>&1; then
            hosted_pg_runnable=1
        else
            printf 'project-guide-dead||hosted project-guide cannot run (%s)|force-reinstall into the toolchain venv and re-link the shim\n' "$hosted_pg"
        fi
    fi

    # Shim: a fault only when dangling (a symlink whose target is gone)
    # while the hosted script it should point at is runnable. Absent =
    # never linked = not a fault; broken hosting is the faults above.
    local shim="$HOME/.local/bin/project-guide"
    if [[ -L "$shim" && ! -e "$shim" && "$hosted_pg_runnable" -eq 1 ]]; then
        printf 'shim-dangling||~/.local/bin/project-guide is a dead symlink|re-link it at the hosted console script\n'
    fi
    return 0
}

# The root env's on-disk location (venv dir for a venv root, the conda
# root slot for micromamba) — for plan messages and the drift probe.
_heal_root_env_path() {
    local backend=""
    declare -F _env_resolve_root_backend >/dev/null 2>&1 \
        && backend="$(_env_resolve_root_backend 2>/dev/null)" || true
    if [[ "$backend" == "micromamba" ]] \
        && declare -F micromamba_root_prefix >/dev/null 2>&1; then
        micromamba_root_prefix
        return 0
    fi
    local vd
    vd="$(resolve_venv_directory 2>/dev/null || true)"
    printf '%s' "${vd:-${DEFAULT_VENV_DIR:-.venv}}"
}

# venv↔pin creation-time drift, as a state fact: probe the root venv's
# OWN interpreter against the declared pin — activation-independent (the
# [resolution] finding is the PATH-winner narrative sibling). Prints
# "<ver>|<pin>|<path>" and returns 0 when drifted; non-zero otherwise.
# venv roots only: a conda root's interpreter is pinned by environment.yml,
# not the version-manager pin.
_heal_root_drift() {
    declare -F resolve_python_version >/dev/null 2>&1 || return 1
    local pin ver path backend=""
    pin="$(resolve_python_version 2>/dev/null | cut -d'|' -f1)"
    [[ -n "$pin" ]] || return 1
    declare -F _env_resolve_root_backend >/dev/null 2>&1 \
        && backend="$(_env_resolve_root_backend 2>/dev/null)" || true
    [[ "$backend" == "venv" ]] || return 1
    path="$(_heal_root_env_path)"
    [[ -x "$path/bin/python" ]] || return 1
    ver="$(pyve_runnable_version "$path/bin/python" 2>/dev/null)" || return 1
    [[ -n "$ver" && "$ver" != "$pin" ]] || return 1
    printf '%s|%s|%s' "$ver" "$pin" "$path"
    return 0
}

# Destructive tier: project-env faults — canary verdicts (broken root /
# named envs), venv↔pin drift, and manifest↔disk orphans. Gated on a
# manifest being present and the canary providers being loaded (full
# binary context); silent otherwise.
_heal_plan_project_envs() {
    [[ -f pyve.toml ]] || return 0
    declare -F python_pyve_plugin_env_probe >/dev/null 2>&1 || return 0
    declare -F manifest_list_envs >/dev/null 2>&1 || return 0
    manifest_load >/dev/null 2>&1 || true

    local planned_root=0 nm verdict class rp
    while IFS= read -r nm; do
        [[ -z "$nm" ]] && continue
        verdict="$(python_pyve_plugin_env_probe "$nm" 2>/dev/null)" || true
        class="${verdict%% *}"
        case "$class" in
            dead-shebang|dangling-symlink|missing-interpreter|broken) ;;
            *) continue ;;
        esac
        if [[ "$nm" == "root" ]]; then
            planned_root=1
            rp="$(_heal_root_env_path)"
            printf 'env-dead-root|%s|root env broken (%s) at %s|rebuild: pyve init --force — destroys and recreates %s\n' \
                "$rp" "$class" "$rp" "$rp"
        else
            printf 'env-dead|%s|env %s broken (%s)|rebuild: pyve env init %s --force — destroys and recreates .pyve/envs/%s\n' \
                "$nm" "$nm" "$class" "$nm" "$nm"
        fi
    done < <(printf 'root\n'; manifest_list_envs 2>/dev/null | grep -v '^root$' || true)

    # Drift only when no root rebuild is already planned — one repair.
    local drift dver dpin dpath
    if [[ "$planned_root" -eq 0 ]] && drift="$(_heal_root_drift)"; then
        IFS='|' read -r dver dpin dpath <<<"$drift"
        printf 'env-drift|%s|root env python is %s but the declared pin is %s (venv frozen to its creation-time interpreter)|rebuild toward the pin: pyve init --force — destroys and recreates %s\n' \
            "$dpath" "$dver" "$dpin" "$dpath"
    fi

    # Orphans: materialized trees the manifest does not declare.
    if declare -F list_materialized_env_names >/dev/null 2>&1 \
        && declare -F manifest_get_env >/dev/null 2>&1; then
        while IFS= read -r nm; do
            [[ -z "$nm" || "$nm" == "root" ]] && continue
            if ! manifest_get_env "$nm" >/dev/null 2>&1; then
                printf 'env-orphan|.pyve/envs/%s|env %s is materialized but not declared|remove the undeclared tree — rm -rf .pyve/envs/%s\n' \
                    "$nm" "$nm" "$nm"
            fi
        done < <(list_materialized_env_names 2>/dev/null || true)
    fi

    # Advisory-root contradiction: declared non-materializable, yet a
    # tree is materialized (the manifest is canonical).
    local root_backend=""
    declare -F _env_resolve_root_backend >/dev/null 2>&1 \
        && root_backend="$(_env_resolve_root_backend 2>/dev/null)" || true
    case "$root_backend" in
        venv|micromamba|"") return 0 ;;
    esac
    if declare -F _env_backend_is_advisory >/dev/null 2>&1 \
        && _env_backend_is_advisory "$root_backend"; then
        local slot vd
        if declare -F micromamba_root_prefix >/dev/null 2>&1; then
            slot="$(micromamba_root_prefix)"
            if [[ -d "$slot" ]]; then
                printf 'env-orphan|%s|root declares backend %s (not materializable) but a conda env is materialized at %s|remove the contradictory tree — rm -rf %s\n' \
                    "$slot" "$root_backend" "$slot" "$slot"
            fi
        fi
        vd="$(resolve_venv_directory 2>/dev/null || true)"
        [[ -z "$vd" ]] && vd="${DEFAULT_VENV_DIR:-.venv}"
        if [[ -d "$vd" ]]; then
            printf 'env-orphan|%s|root declares backend %s (not materializable) but a venv is materialized at %s|remove the contradictory tree — rm -rf %s\n' \
                "$vd" "$root_backend" "$vd" "$vd"
        fi
    fi
    return 0
}

# Interactivity seam (tests stub this to drive the confirm flow).
_heal_is_interactive() { [[ -t 0 && -t 1 ]]; }

# Destructiveness tier for a fault class.
_heal_is_destructive() {
    case "$1" in
        env-dead-root|env-dead|env-drift|env-orphan) return 0 ;;
    esac
    return 1
}

# Self-invocation seam for the role-correct rebuild verbs (tests stub
# this). PYVE_FORCE_YES pre-assents nested prompts — heal has already
# collected consent for exactly this repair.
_heal_pyve() {
    PYVE_FORCE_YES=1 "${SCRIPT_DIR:-.}/pyve.sh" "$@"
}

# Post-repair verification for an env: the canary verdict must leave the
# broken family (runnable, or legitimately absent).
_heal_probe_ok() {
    local v
    v="$(python_pyve_plugin_env_probe "$1" 2>/dev/null)" || true
    case "${v%% *}" in
        runnable|not-materialized|advisory) return 0 ;;
    esac
    return 1
}

# Apply the repair for one fault class (<arg> = the plan line's operand:
# an env name or tree path). Returns 0 when the repair landed AND the
# re-probe confirms the fault is gone; non-zero otherwise.
heal_apply() {
    local class="$1" arg="${2:-}"
    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"
    case "$class" in
        env-dead-root)
            _heal_pyve init --force >/dev/null 2>&1 || return 1
            _heal_probe_ok root
            ;;
        env-drift)
            _heal_pyve init --force >/dev/null 2>&1 || return 1
            ! _heal_root_drift >/dev/null 2>&1
            ;;
        env-dead)
            [[ -n "$arg" ]] || return 1
            _heal_pyve env init "$arg" --force >/dev/null 2>&1 || return 1
            _heal_probe_ok "$arg"
            ;;
        env-orphan)
            # The path comes from our own plan; still refuse anything that
            # is not a relative project-local tree.
            [[ -n "$arg" && "$arg" != /* && "$arg" != *..* ]] || return 1
            rm -rf "$arg"
            [[ ! -d "$arg" ]]
            ;;
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
# assent). Interactive runs without assent get one batch prompt, plus an
# INDIVIDUAL confirmation per destructive repair (`--yes` assents to
# those too); non-interactive runs without assent are REPORT-ONLY, and a
# non-interactive run NEVER applies a destructive repair — even with
# `--yes` it reports and skips them, so `check --fix --yes` stays CI-safe.
# Declining one repair skips only that repair. Returns non-zero only when
# an assented repair failed (re-run to retry — the plan is recomputed
# from live probes, so completed repairs drop out; skips and refusals are
# not failures).
heal_run() {
    local assent="${1:-0}"
    local plan
    plan="$(heal_plan)"
    if [[ -z "$plan" ]]; then
        printf 'Nothing to heal.\n'
        return 0
    fi

    local interactive=0
    _heal_is_interactive && interactive=1

    printf 'Detected fault(s) and intended repair(s):\n'
    local class arg desc repair
    while IFS='|' read -r class arg desc repair; do
        [[ -n "$class" ]] || continue
        if _heal_is_destructive "$class"; then
            printf '  ✗ [%s] %s (destructive)\n' "$class" "$desc"
        else
            printf '  ✗ [%s] %s\n' "$class" "$desc"
        fi
        printf '    → %s\n' "$repair"
    done <<<"$plan"

    if [[ "$assent" != "1" ]]; then
        if [[ "$interactive" -eq 1 ]] && declare -F prompt_yes_no >/dev/null 2>&1; then
            if ! prompt_yes_no "Apply these repair(s)?"; then
                printf 'No repairs applied.\n'
                return 0
            fi
        else
            printf 'Report-only (no assent): re-run with --yes to apply these repairs.\n'
            return 0
        fi
    fi

    # Apply loop reads the plan on fd 3: the per-repair confirmation
    # prompts inside the loop read stdin, which must stay the caller's.
    local healed=0 failed=0 skipped=0
    while IFS='|' read -r -u 3 class arg desc repair; do
        [[ -n "$class" ]] || continue
        if _heal_is_destructive "$class"; then
            if [[ "$interactive" -ne 1 ]]; then
                printf '  ▸ skipped [%s] — destructive; needs an interactive terminal (%s)\n' "$class" "$desc"
                skipped=$((skipped + 1))
                continue
            fi
            if [[ "$assent" != "1" ]] && declare -F prompt_yes_no >/dev/null 2>&1; then
                if ! prompt_yes_no "Destructive: $repair — proceed?"; then
                    printf '  ▸ declined [%s]\n' "$class"
                    skipped=$((skipped + 1))
                    continue
                fi
            fi
        fi
        if heal_apply "$class" "$arg"; then
            printf '  ✓ healed [%s]\n' "$class"
            healed=$((healed + 1))
        else
            printf '  ✗ repair failed [%s] — re-run '\''pyve check --fix'\'' to retry\n' "$class"
            failed=$((failed + 1))
        fi
    done 3<<<"$plan"

    printf '%d repair(s) applied' "$healed"
    if [[ "$skipped" -gt 0 ]]; then
        printf ', %d skipped' "$skipped"
    fi
    if [[ "$failed" -gt 0 ]]; then
        printf ', %d failed' "$failed"
        printf '.\n'
        return 1
    fi
    printf '.\n'
    return 0
}
