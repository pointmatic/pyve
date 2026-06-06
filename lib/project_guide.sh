# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/project_guide.sh — stack-agnostic project-guide orchestration
# (Story N.au — F1)
#
# Lifted out of the Python plugin's `init_project` tail (where it was
# `_init_run_project_guide_hooks`) so the project-guide install decision
# + scaffold + completion is reachable from the *composed-init*
# orchestration level — answered identically for Python-only, Node-only,
# and polyglot stacks, before per-plugin env materialization.
#
# Per the project-essential "lib/commands/<name>.sh is for command
# implementations only", project-guide orchestration is cross-stack
# shared infrastructure → it lives in lib/, not in any one plugin.
#
# The install/scaffold/completion LEAF helpers (install_project_guide,
# prompt_install_project_guide, run_project_guide_{init,update}_in_env,
# detect_user_shell, get_shell_rc_path, the completion-rc primitives,
# etc.) remain in lib/utils.sh: they are already shared infrastructure,
# and several (is_project_guide_completion_present,
# remove_project_guide_completion) are also consumed by `pyve self
# uninstall`. This module owns the ORCHESTRATION; utils.sh owns the leaves.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Orchestrate the project-guide post-init flow: decide whether to install,
# resolve the host env, install the package into it, scaffold/refresh the
# managed artifacts, then optionally wire shell completion.
#
# Every step is failure-non-fatal — init continues even on errors.
# Respects CLI-flag overrides via the "mode" arguments (pre-resolved by
# the caller from --project-guide / --no-project-guide and their
# completion siblings). When a mode is empty, falls through to the
# env-var / CI / interactive logic inside the prompt helpers.
#
# Usage: run_project_guide_orchestration <backend> <env_path> <pg_mode> <comp_mode>
#   backend:   "venv" | "micromamba"
#   env_path:  the host-candidate env path (the Python app env today)
#   pg_mode:   "" | "yes" | "no"  (from --project-guide / --no-project-guide)
#   comp_mode: "" | "yes" | "no"  (from --project-guide-completion / etc.)
run_project_guide_orchestration() {
    # Story N.aw: project-guide is globally hosted, so backend/env_path
    # ($1, $2) are no longer used here (kept in the signature for the two
    # callers — init_project + compose_init); pg_mode/comp_mode drive the
    # install + completion decisions.
    local pg_mode="$3"
    local comp_mode="$4"

    # Resolve CLI flag overrides into a tri-state.
    local should_install=0  # 0 = unknown (consult env vars / prompt), 1 = yes, 2 = no
    case "$pg_mode" in
        yes) should_install=1 ;;
        no)  should_install=2 ;;
    esac

    local should_add_completion=0
    case "$comp_mode" in
        yes) should_add_completion=1 ;;
        no)  should_add_completion=2 ;;
    esac

    #--- Install decision -------------------------------------------------
    # Priority order:
    #   1. --no-project-guide flag                  → skip silent
    #   2. --project-guide flag                     → install (overrides auto-skip)
    #   3. PYVE_NO_PROJECT_GUIDE=1 / PYVE_PROJECT_GUIDE=1 → handled by prompt_install_project_guide
    #   4. project-guide already in project deps    → AUTO-SKIP with INFO message
    #   5. CI / PYVE_FORCE_YES                      → install (CI default)
    #   6. interactive                              → prompt, default Y
    #---------------------------------------------------------------------
    if [[ $should_install -eq 2 ]]; then
        log_info "Skipping project-guide install (--no-project-guide)"
        return 0
    fi

    local do_install=false
    if [[ $should_install -eq 1 ]]; then
        do_install=true
    else
        # Auto-skip safety: if project-guide is already declared as a project
        # dependency, do not let pyve manage it. The user's pin wins; pyve's
        # install/upgrade would just create a version conflict at the next
        # `pip install -e .`.
        if project_guide_in_project_deps; then
            log_info "Detected 'project-guide' in your project dependencies."
            log_info "Pyve will not auto-install or run 'project-guide init' to avoid a version conflict."
            log_info "Project-guide will be installed when your project dependencies are installed."
            log_info "To override and let pyve manage it anyway, pass --project-guide."
            log_info "To suppress this message, pass --no-project-guide."
            return 0
        fi

        if prompt_install_project_guide; then
            do_install=true
        fi
    fi

    if [[ "$do_install" != true ]]; then
        return 0
    fi

    #--- Step 1: ensure project-guide is globally available --------------
    # Story N.aw: project-guide is a Pyve-managed GLOBAL tool (pyve self
    # install → toolchain venv + ~/.local/bin shim), not a per-project pip
    # install. Nothing to install here — we only need it resolvable on PATH
    # to scaffold. If it isn't, point the user at `pyve self install` and
    # skip (non-fatal): scaffolding or wiring completion for a missing tool
    # would just leave dead state.
    if ! command -v project-guide >/dev/null 2>&1; then
        log_warning "project-guide is not installed — run 'pyve self install' to host it, then re-run."
        return 0
    fi

    #--- Step 2: scaffold or refresh managed artifacts --------------------
    # Branch on `.project-guide.yml` presence (Story G.h):
    #   - absent → first-time scaffolding: `project-guide init --no-input`
    #   - present → refresh: `project-guide update --no-input` — preserves
    #     user state (current_mode, overrides, test_first, pyve_version)
    #     and creates `.bak.<ts>` siblings for modified managed files.
    # Both run the GLOBAL `project-guide` in the project cwd. Pyve never
    # auto-runs `project-guide init --force` (destructive); user-initiated.
    if [[ -f ".project-guide.yml" ]]; then
        run_project_guide_update_in_env
    else
        run_project_guide_init_in_env
    fi

    #--- Step 3: shell completion wiring ----------------------------------
    if [[ $should_add_completion -eq 2 ]]; then
        log_info "Skipping project-guide completion wiring (--no-project-guide-completion)"
        return 0
    fi

    local do_completion=false
    if [[ $should_add_completion -eq 1 ]]; then
        do_completion=true
    elif prompt_install_project_guide_completion; then
        do_completion=true
    fi

    if [[ "$do_completion" != true ]]; then
        return 0
    fi

    local user_shell
    user_shell="$(detect_user_shell)"
    if [[ "$user_shell" == "unknown" ]]; then
        log_warning "Unknown shell — skipping project-guide completion wiring."
        log_warning "  For manual setup, add to your shell rc file:"
        log_warning "    eval \"\$(_PROJECT_GUIDE_COMPLETE=<shell>_source project-guide)\""
        return 0
    fi

    local rc_path
    rc_path="$(get_shell_rc_path "$user_shell")"
    if [[ -z "$rc_path" ]]; then
        log_warning "Could not determine rc file for shell '$user_shell' — skipping completion wiring"
        return 0
    fi

    if is_project_guide_completion_present "$rc_path"; then
        log_info "project-guide completion already present in $rc_path"
        return 0
    fi

    if add_project_guide_completion "$rc_path" "$user_shell"; then
        log_success "Added project-guide completion to $rc_path"
        log_info "  Reload your shell or run: source $rc_path"
    else
        log_warning "Failed to write project-guide completion to $rc_path (continuing)"
    fi
}

# Discover the env-dependencies spec path (the `plan_envs`-authored doc
# whose §4 `pyve env sync` ingests, Story N.az) via the `.project-guide.yml`
# tool-state pointer (Story N.ay — F5, per wizard-env-contract.md §D/§E).
#
# Resolution:
#   1. the `env_spec_path:` key in `.project-guide.yml` — a plain
#      `key: value` line (basic YAML, no parser dependency), with
#      surrounding whitespace and quotes stripped.
#   2. the default `docs/specs/env-dependencies.md` when the marker file is
#      absent, the key is missing, or the value is empty.
#
# Minimum project-guide version: the `env_spec_path` pointer and the
# env-dependencies doc are authored by the `plan_envs` mode, which ships in
# project-guide >= 2.12.0 (the wizard-env-contract integration — alongside
# the existing `--no-input` >= 2.2.3 / `--quiet` >= 2.5.0 precedents
# recorded in lib/utils.sh). The default keeps discovery robust against
# older installs that predate the pointer.
#
# Usage: project_guide_env_spec_path   (prints the resolved path)
project_guide_env_spec_path() {
    local marker=".project-guide.yml"
    local default_path="docs/specs/env-dependencies.md"

    [[ -f "$marker" ]] || { printf '%s' "$default_path"; return 0; }

    local line
    line="$(grep -E '^[[:space:]]*env_spec_path:' "$marker" 2>/dev/null | head -1 || true)"
    [[ -n "$line" ]] || { printf '%s' "$default_path"; return 0; }

    # Strip the key, then trim whitespace and one layer of surrounding quotes.
    local value="${line#*:}"
    value="${value#"${value%%[![:space:]]*}"}"   # ltrim
    value="${value%"${value##*[![:space:]]}"}"   # rtrim
    value="${value#\"}"; value="${value%\"}"     # strip double quotes
    value="${value#\'}"; value="${value%\'}"     # strip single quotes
    value="${value#"${value%%[![:space:]]*}"}"   # re-trim (quoted padding)
    value="${value%"${value##*[![:space:]]}"}"

    [[ -n "$value" ]] || { printf '%s' "$default_path"; return 0; }
    printf '%s' "$value"
}
