# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/project_guide.sh — stack-agnostic project-guide orchestration
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
    # project-guide is globally hosted, so backend/env_path
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

    #--- Step 1: scaffold or refresh managed artifacts --------------------
    # project-guide is a Pyve-managed GLOBAL tool hosted in the toolchain
    # venv. Story N.bh: provisioning is now LAZY and install-method-agnostic
    # — the init/update callsites below call pyve_project_guide_ensure on
    # first use (so Homebrew and source installs both self-provision), and
    # if hosting genuinely can't be set up they skip with a pyve-actionable
    # "run pyve self provision" message. No bare `command -v project-guide`
    # guard here: under active asdf that resolves the version-gated shim
    # trap, not a real tool.
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

    # Resolve the target rc file up front so the sentinel-presence check can
    # run BEFORE any interactive prompt. The completion block is a
    # one-time-ever configuration; re-asking on every `pyve init` when it is
    # already wired is the bug this guards. The flag/env/prompt handling
    # below only matters when the block is absent.
    local user_shell rc_path=""
    user_shell="$(detect_user_shell)"
    if [[ "$user_shell" != "unknown" ]]; then
        rc_path="$(get_shell_rc_path "$user_shell")"
    fi

    # project-guide >= 2.21.0 owns its own completion. Delegate to it, and
    # migrate anyone still carrying pyve's hand-rolled block.
    if _pg_completion_upstream_available; then
        _pg_completion_delegate "$rc_path" "$user_shell" "$should_add_completion"
        return 0
    fi

    # Pre-prompt idempotency guard: already wired → note and done, no prompt.
    if [[ -n "$rc_path" ]] && is_project_guide_completion_present "$rc_path"; then
        log_info "project-guide completion already present in $rc_path"
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

    if [[ "$user_shell" == "unknown" ]]; then
        log_warning "Unknown shell — skipping project-guide completion wiring."
        log_warning "  For manual setup, add to your shell rc file:"
        log_warning "    eval \"\$(_PROJECT_GUIDE_COMPLETE=<shell>_source project-guide)\""
        return 0
    fi

    if [[ -z "$rc_path" ]]; then
        log_warning "Could not determine rc file for shell '$user_shell' — skipping completion wiring"
        return 0
    fi

    if add_project_guide_completion "$rc_path" "$user_shell"; then
        log_success "Added project-guide completion to $rc_path"
        log_info "  Reload your shell or run: source $rc_path"
    else
        log_warning "Failed to write project-guide completion to $rc_path (continuing)"
    fi
}

#------------------------------------------------------------
# Completion wiring, delegated (project-guide >= 2.21.0)
#
# pyve used to hand-write a Click completion snippet into the user's rc
# file, which meant hardcoding another tool's protocol: the
# `_PROJECT_GUIDE_COMPLETE=<shell>_source` contract, the fact that the
# generated zsh script ends in `compdef`, and that `compdef` presupposes
# `compinit`. Every one of those is a property of project-guide's
# generator, and pyve got two of them wrong in ways that failed silently.
# project-guide now ships `completion install`, which owns all of it —
# and for zsh takes the fpath autoload route, so nothing is evaluated at
# shell startup and the compinit precondition disappears rather than
# being worked around.
#
# pyve's remaining job is the one thing it alone knows: WHICH binary to
# bake in.
#------------------------------------------------------------

# The sentinel project-guide writes for itself. Distinct from pyve's
# legacy `# >>> project-guide completion (added by pyve) >>>` — neither
# string is a substring of the other, so the two never cross-match.
PROJECT_GUIDE_UPSTREAM_COMPLETION_OPEN="# >>> project-guide completion >>>"

_pg_completion_upstream_available() {
    declare -F pyve_project_guide_version_at_least >/dev/null 2>&1 || return 1
    pyve_project_guide_version_at_least "$PROJECT_GUIDE_MIN_VERSION_HANDOFF"
}

# The path to bake into the completion callback. Deliberately the STABLE
# ~/.local/bin shim, never the toolchain venv's console script: the venv
# path is version-keyed (toolchain/<PYTHON_VERSION>/venv/...), so baking
# it in would silently rot on the next DEFAULT_PYTHON_VERSION bump —
# which is precisely the `stale` state `completion status` reports. The
# shim survives bumps because pyve_link_project_guide_shim re-points it.
_pg_completion_bin() {
    local shim="$HOME/.local/bin/project-guide"
    if [[ -e "$shim" ]]; then
        printf '%s' "$shim"
    else
        pyve_project_guide
    fi
}

_pg_completion_delegate() {
    local rc_path="$1" user_shell="$2" should_add_completion="$3"

    if [[ "$user_shell" == "unknown" || -z "$rc_path" ]]; then
        log_warning "Unknown shell — skipping project-guide completion wiring."
        log_warning "  For manual setup, run: project-guide completion install"
        return 0
    fi

    # A legacy pyve block means the user already consented to completion
    # once. Migrating it is a repair, not a new decision, so it does not
    # re-prompt. pyve removes its own block rather than asking upstream to:
    # `completion install` reports a foreign block and never edits it, and
    # the block is pyve's to clean up.
    local migrating=false
    if is_project_guide_completion_present "$rc_path"; then
        migrating=true
        remove_project_guide_completion "$rc_path"
        log_info "Removed pyve's legacy completion block from $rc_path"
    fi

    # Already wired by project-guide → nothing to do, and no prompt.
    # `completion install` is itself idempotent; this guard exists so
    # `pyve init` does not re-ask a question already answered.
    if [[ "$migrating" != true ]] \
        && [[ -f "$rc_path" ]] \
        && grep -qF "$PROJECT_GUIDE_UPSTREAM_COMPLETION_OPEN" "$rc_path"; then
        log_info "project-guide completion already installed in $rc_path"
        return 0
    fi

    if [[ "$migrating" != true ]]; then
        if [[ "$should_add_completion" -ne 1 ]] \
            && ! prompt_install_project_guide_completion; then
            return 0
        fi
    fi

    local pg bin
    pg="$(pyve_project_guide)"
    bin="$(_pg_completion_bin)"
    if run_quiet "$pg" completion install --shell "$user_shell" --bin "$bin"; then
        if [[ "$migrating" == true ]]; then
            log_success "Migrated project-guide completion to project-guide's own installer"
        else
            log_success "Installed project-guide completion ($user_shell)"
        fi
        log_info "  Reload your shell to pick it up."
    else
        log_warning "'project-guide completion install' failed (continuing)"
    fi
    return 0
}

# Discover the env-dependencies spec path (the `plan_envs`-authored doc
# whose §4 `pyve env sync` ingests) via the `.project-guide.yml`
# tool-state pointer (per wizard-env-contract.md §D/§E).
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
