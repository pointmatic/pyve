# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve init — initialize a Python virtual environment
#
# The largest command. Auto-detects backend (venv vs micromamba),
# resolves the version manager (asdf or pyenv), creates the
# environment, configures direnv (unless --no-direnv), writes
# .pyve/config, and runs the project-guide post-init hooks.
#
# Function-name note: this function is named `init_project` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve init` operates on the project (creates venv, writes
# .pyve/config, configures direnv, etc.).
#
# Cross-command callsite: `init_project --force` calls
# `purge_project --keep-testenv --yes` (in lib/commands/purge.sh)
# from its --force pre-flight and from the interactive option-2
# (purge-and-rebuild) path. Bash resolves the call at runtime via
# the global function table.
#
# Init-private helpers (per project-essentials F): `_init_` prefix
# on all single-caller helpers. Includes
# `_init_run_project_guide_hooks` (per audit F-10) and the six
# config-writers (`_init_python_version`, `_init_venv`,
# `_init_direnv_venv`, `_init_direnv_micromamba`, `_init_dotenv`,
# `_init_gitignore`).
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#============================================================
# Init Command
#============================================================

# Run the project-guide post-init hooks: install the package into the
# project env, then optionally add shell completion to the user rc file.
#
# Both steps are failure-non-fatal — pyve init continues even on errors.
# Respects CLI-flag overrides via the "mode" arguments (pre-resolved by
# init() from --project-guide / --no-project-guide and their completion
# siblings). When mode is empty, falls through to the env-var / CI /
# interactive logic inside the prompt helpers.
#
# Usage: _init_run_project_guide_hooks <backend> <env_path> <pg_mode> <comp_mode>
#   backend:   "venv" | "micromamba"
#   env_path:  path to the project environment
#   pg_mode:   "" | "yes" | "no"  (from --project-guide / --no-project-guide)
#   comp_mode: "" | "yes" | "no"  (from --project-guide-completion / etc.)
_init_run_project_guide_hooks() {
    local backend="$1"
    local env_path="$2"
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

    #--- Step 1: pip install --upgrade project-guide ----------------------
    install_project_guide "$backend" "$env_path" || true

    # If install actually failed, don't proceed to step 2 or 3 — running
    # `project-guide init` against a missing binary or adding a completion
    # eval for a missing tool would just leave dead state.
    if ! is_project_guide_installed "$backend" "$env_path"; then
        return 0
    fi

    #--- Step 2: scaffold or refresh managed artifacts --------------------
    # Branch on `.project-guide.yml` presence (Story G.h):
    #   - absent → first-time scaffolding: `project-guide init --no-input`
    #   - present → refresh: `project-guide update --no-input` — preserves
    #     user state (current_mode, overrides, test_first, pyve_version)
    #     and creates `.bak.<ts>` siblings for modified managed files.
    # Pyve never auto-runs `project-guide init --force` because it is
    # destructive (resets config, no backups); that remains user-initiated.
    if [[ -f ".project-guide.yml" ]]; then
        run_project_guide_update_in_env "$backend" "$env_path"
    else
        run_project_guide_init_in_env "$backend" "$env_path"
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

# Repo-signal helper: detect the default backend for this project.
#
# Returns one of:
#   micromamba   if environment.yml exists in cwd
#   venv         if .python-version or .tool-versions exists, OR no signals at all
#
# environment.yml wins over the venv-side signals so a project with
# both env.yml (added recently) and an old .tool-versions still resolves
# to micromamba.
_init_detect_backend_default() {
    if [[ -f environment.yml ]]; then
        printf 'micromamba\n'
    elif [[ -f .python-version ]] || [[ -f .tool-versions ]]; then
        printf 'venv\n'
    else
        printf 'venv\n'
    fi
}

# Detect which Python version managers are available on PATH.
# Returns one of: "" | "asdf" | "pyenv" | "asdf,pyenv".
# Used by the venv branch of the L.k.4 Python prompt.
_init_detect_version_managers_available() {
    local available=()
    command -v asdf  >/dev/null 2>&1 && available+=("asdf")
    command -v pyenv >/dev/null 2>&1 && available+=("pyenv")
    local IFS=,
    printf '%s' "${available[*]}"
}

# List manager-reported installed Python versions, filtered to ^3\..
# Output: one version per line, no leading whitespace, no '*' marker.
# Args: $1 = "asdf" | "pyenv"
_init_list_installed_python_versions() {
    local manager="$1"
    case "$manager" in
        asdf)
            asdf list python 2>/dev/null \
                | sed -e 's/^[[:space:]]*\*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                | grep -E '^3\.' || true
            ;;
        pyenv)
            pyenv versions --bare 2>/dev/null | grep -E '^3\.' || true
            ;;
    esac
}

# List manager-reported AVAILABLE Python versions (full catalog), filtered to ^3\..
# Output: one version per line.
# Args: $1 = "asdf" | "pyenv"
_init_list_available_python_versions() {
    local manager="$1"
    case "$manager" in
        asdf)
            asdf list all python 2>/dev/null | grep -E '^3\.' || true
            ;;
        pyenv)
            pyenv install --list 2>/dev/null \
                | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                | grep -E '^3\.' || true
            ;;
    esac
}

# Interactive `pyve init` wizard (Story L.k.2 skeleton + L.k.3 backend prompt).
#
# Always invoked from init_project(); flags only control whether each
# individual prompt reads stdin or renders the flag-resolved value
# non-interactively. Per-prompt logic for python pin / project-guide
# lands in L.k.4 / L.k.5.
#
# TTY guard: when at least one of the three prompt-bearing parameters
# is not flag-supplied AND stdin is not a TTY, hard-fail with a message
# naming the missing flags. PYVE_INIT_NONINTERACTIVE=1 bypasses the
# guard (used by the bats test harness so existing init-driving tests
# stay green without supplying every prompt-bearing flag).
#
# Side effect: when `--backend` is unsupplied, this function resolves
# the backend (interactive prompt or auto-default) and writes the
# resolved value into the caller's `backend_flag` variable via bash's
# dynamic scoping. The resolved value is therefore visible to
# init_project() after the wizard returns, exactly as if the user had
# passed `--backend <value>` on the command line.
#
# Usage: _init_wizard <backend_flag> <python_value> <python_supplied> <project_guide_mode>
#   arg_backend_flag:          "" if --backend not supplied, else the value
#   arg_python_value:          the resolved python version (the user's flag value
#                              when --python-version was supplied; the
#                              DEFAULT_PYTHON_VERSION fallback otherwise)
#   arg_python_supplied:       "true" if --python-version supplied, else "false"
#   arg_pg_mode:               "" if neither flag supplied, else "yes" or "no"
_init_wizard() {
    local arg_backend_flag="$1"
    local arg_python_value="$2"
    local arg_python_supplied="$3"
    local arg_pg_mode="$4"

    local missing_flags=()
    [[ -z "$arg_backend_flag" ]] && missing_flags+=("--backend <type>")
    [[ "$arg_python_supplied" != "true" ]] && missing_flags+=("--python-version <ver>")
    [[ -z "$arg_pg_mode" ]] && missing_flags+=("--project-guide / --no-project-guide")

    if [[ ${#missing_flags[@]} -gt 0 ]] \
       && [[ ! -t 0 ]] \
       && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
        log_error "pyve init: stdin is not a TTY and the wizard requires interactive input."
        log_error "To run non-interactively, supply the missing flag(s):"
        local f
        for f in "${missing_flags[@]}"; do
            log_error "  $f"
        done
        log_error "Or set PYVE_INIT_NONINTERACTIVE=1 to bypass."
        exit 1
    fi

    header_box "pyve init"

    # Prompt 1 — backend (Story L.k.3).
    if [[ -n "$arg_backend_flag" ]]; then
        info "Backend: $arg_backend_flag (--backend)"
        backend_flag="$arg_backend_flag"
    elif [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
        local default_backend default_idx
        default_backend="$(_init_detect_backend_default)"
        if [[ "$default_backend" == "micromamba" ]]; then
            default_idx=2
        else
            default_idx=1
        fi
        local choice_idx
        if ! choice_idx="$(ui_select --default "$default_idx" "Select backend" "venv" "micromamba")"; then
            log_error "Backend selection cancelled."
            exit 1
        fi
        case "$choice_idx" in
            0) backend_flag="venv" ;;
            1) backend_flag="micromamba" ;;
            *) log_error "Unexpected backend choice index: $choice_idx"; exit 1 ;;
        esac
    else
        local default_backend
        default_backend="$(_init_detect_backend_default)"
        info "Backend: $default_backend (auto-detected)"
        backend_flag="$default_backend"
    fi

    # Prompt 2 — Python version pin (Story L.k.4). Backend-aware: venv pins
    # via asdf/pyenv writing .tool-versions / .python-version; micromamba
    # pins via the `python=X` line in environment.yml (the existing
    # scaffolder writes it later in the init flow).
    if [[ "$backend_flag" == "micromamba" ]]; then
        if [[ -f environment.yml ]]; then
            info "Python: managed via environment.yml"
        elif [[ "$arg_python_supplied" == "true" ]]; then
            info "Python: $arg_python_value (--python-version, will be written to environment.yml)"
        else
            info "Python: $arg_python_value (default, will be written to environment.yml)"
        fi
    else
        # venv branch.
        local available_managers
        available_managers="$(_init_detect_version_managers_available)"

        if [[ "$arg_python_supplied" == "true" ]]; then
            # Flag-driven: detect managers (hard-fail if none); pick asdf when
            # both available; render and write the pin via the existing
            # set_local_python_version helper.
            if [[ -z "$available_managers" ]]; then
                log_error "No supported Python version manager found on PATH."
                log_error "Install one of:"
                log_error "  asdf  — https://asdf-vm.com/"
                log_error "  pyenv — https://github.com/pyenv/pyenv"
                exit 1
            fi
            local picked_manager
            if [[ "$available_managers" == *"asdf"* ]]; then
                picked_manager="asdf"
            else
                picked_manager="pyenv"
            fi
            info "Python: $arg_python_value (--python-version, pinned via $picked_manager)"
            VERSION_MANAGER="$picked_manager"
            if ! set_local_python_version "$arg_python_value" >/dev/null 2>&1; then
                log_error "Failed to pin Python $arg_python_value via $picked_manager."
                exit 1
            fi
            python_version="$arg_python_value"
        elif [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
            # Interactive: full picker flow. Hard-fail when neither manager is
            # installed (the user is being asked to choose; the prompt has no
            # legitimate answer otherwise).
            if [[ -z "$available_managers" ]]; then
                log_error "No supported Python version manager found on PATH."
                log_error "Install one of:"
                log_error "  asdf  — https://asdf-vm.com/"
                log_error "  pyenv — https://github.com/pyenv/pyenv"
                exit 1
            fi
            local picked_manager
            if [[ "$available_managers" == "asdf,pyenv" ]]; then
                local mgr_idx
                if ! mgr_idx="$(ui_select --default 1 "Select Python version manager" "asdf" "pyenv")"; then
                    log_error "Version-manager selection cancelled."
                    exit 1
                fi
                case "$mgr_idx" in
                    0) picked_manager="asdf" ;;
                    1) picked_manager="pyenv" ;;
                    *) log_error "Unexpected manager choice index: $mgr_idx"; exit 1 ;;
                esac
            else
                picked_manager="$available_managers"
            fi
            # Build "Pick from installed" list with `more...` and `skip` as the
            # final two options. Selecting `more...` re-prompts with the full
            # available list.
            local installed_versions
            installed_versions="$(_init_list_installed_python_versions "$picked_manager")"
            local options=()
            local v
            while IFS= read -r v; do
                [[ -n "$v" ]] && options+=("$v")
            done <<<"$installed_versions"
            options+=("more...")
            options+=("skip (no pin)")
            local pick_idx
            if ! pick_idx="$(ui_select --default 1 "Select Python version (via $picked_manager)" "${options[@]}")"; then
                log_error "Python version selection cancelled."
                exit 1
            fi
            local n_installed=$(( ${#options[@]} - 2 ))
            local chosen_version=""
            if (( pick_idx < n_installed )); then
                chosen_version="${options[$pick_idx]}"
            elif (( pick_idx == n_installed )); then
                # `more...` — re-prompt with full available list.
                local available_full
                available_full="$(_init_list_available_python_versions "$picked_manager")"
                local more_options=()
                while IFS= read -r v; do
                    [[ -n "$v" ]] && more_options+=("$v")
                done <<<"$available_full"
                if [[ ${#more_options[@]} -eq 0 ]]; then
                    log_error "No 3.x versions available from $picked_manager."
                    exit 1
                fi
                local more_idx
                if ! more_idx="$(ui_select --default 1 "Select Python version (full list)" "${more_options[@]}")"; then
                    log_error "Python version selection cancelled."
                    exit 1
                fi
                chosen_version="${more_options[$more_idx]}"
            else
                # `skip` — no pin written.
                info "Python: skipped (no pin)"
                chosen_version=""
            fi
            if [[ -n "$chosen_version" ]]; then
                info "Python: $chosen_version (pinned via $picked_manager)"
                VERSION_MANAGER="$picked_manager"
                if ! set_local_python_version "$chosen_version" >/dev/null 2>&1; then
                    log_error "Failed to pin Python $chosen_version via $picked_manager."
                    exit 1
                fi
                python_version="$chosen_version"
            fi
        else
            # Non-TTY or bypass on, no flag → silent skip. No hard-fail on
            # missing managers because no pin was requested.
            info "Python: skipped (no pin)"
        fi
    fi

    return 0
}

init_project() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local python_version="$DEFAULT_PYTHON_VERSION"
    local python_version_supplied=false
    local use_local_env=false
    local backend_flag=""
    local auto_bootstrap=false
    local bootstrap_to="user"
    local strict_mode=false
    local env_name_flag=""
    local no_direnv=false
    local lock_preflight_done=false
    local preflight_backend=""

    # project-guide integration (Story G.c / FR-G2) — tri-state:
    # "" (unset — use env vars / prompt / CI default), "yes" (force install),
    # "no" (force skip). Set by --project-guide / --no-project-guide flags.
    local project_guide_mode=""
    local project_guide_completion_mode=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --python-version)
                if [[ -z "${2:-}" ]]; then
                    log_error "--python-version requires a version argument"
                    exit 1
                fi
                python_version="$2"
                python_version_supplied=true
                shift 2
                ;;
            --backend)
                if [[ -z "${2:-}" ]]; then
                    log_error "--backend requires a backend type (venv, micromamba, auto)"
                    exit 1
                fi
                backend_flag="$2"
                shift 2
                ;;
            --local-env)
                use_local_env=true
                shift
                ;;
            --auto-bootstrap)
                auto_bootstrap=true
                shift
                ;;
            --bootstrap-to)
                if [[ -z "${2:-}" ]]; then
                    log_error "--bootstrap-to requires a location (project, user)"
                    exit 1
                fi
                bootstrap_to="$2"
                if [[ "$bootstrap_to" != "project" ]] && [[ "$bootstrap_to" != "user" ]]; then
                    log_error "Invalid --bootstrap-to value: $bootstrap_to"
                    log_error "Must be 'project' or 'user'"
                    exit 1
                fi
                shift 2
                ;;
            --strict)
                strict_mode=true
                shift
                ;;
            --no-lock)
                export PYVE_NO_LOCK=1
                shift
                ;;
            --env-name)
                if [[ -z "${2:-}" ]]; then
                    log_error "--env-name requires an environment name"
                    exit 1
                fi
                env_name_flag="$2"
                shift 2
                ;;
            --no-direnv)
                no_direnv=true
                shift
                ;;
            --auto-install-deps)
                export PYVE_AUTO_INSTALL_DEPS=1
                shift
                ;;
            --no-install-deps)
                export PYVE_NO_INSTALL_DEPS=1
                shift
                ;;
            --allow-synced-dir)
                export PYVE_ALLOW_SYNCED_DIR=1
                shift
                ;;
            --update)
                # Removed in v2.0 (H.e.9). Hard error — semantics of
                # `pyve update` are broader than v1.x's narrow
                # config-bump, so delegation would surprise scripted
                # callers. See phase-H-cli-refactor-design.md §5 D3.
                legacy_flag_error "init --update" "update"
                ;;
            --force)
                PYVE_REINIT_MODE="force"
                shift
                ;;
            --project-guide)
                if [[ "$project_guide_mode" == "no" ]]; then
                    log_error "--project-guide and --no-project-guide are mutually exclusive"
                    exit 1
                fi
                project_guide_mode="yes"
                shift
                ;;
            --no-project-guide)
                if [[ "$project_guide_mode" == "yes" ]]; then
                    log_error "--project-guide and --no-project-guide are mutually exclusive"
                    exit 1
                fi
                project_guide_mode="no"
                shift
                ;;
            --project-guide-completion)
                if [[ "$project_guide_completion_mode" == "no" ]]; then
                    log_error "--project-guide-completion and --no-project-guide-completion are mutually exclusive"
                    exit 1
                fi
                project_guide_completion_mode="yes"
                shift
                ;;
            --no-project-guide-completion)
                if [[ "$project_guide_completion_mode" == "yes" ]]; then
                    log_error "--project-guide-completion and --no-project-guide-completion are mutually exclusive"
                    exit 1
                fi
                project_guide_completion_mode="no"
                shift
                ;;
            -*)
                unknown_flag_error "init" "$1" \
                    --python-version --backend --auto-bootstrap --bootstrap-to \
                    --strict --no-lock --env-name --no-direnv --auto-install-deps \
                    --no-install-deps --local-env --force --allow-synced-dir \
                    --project-guide --no-project-guide \
                    --project-guide-completion --no-project-guide-completion \
                    --help
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done

    _init_wizard "$backend_flag" "$python_version" "$python_version_supplied" "$project_guide_mode"

    # Refuse to initialize inside a cloud-synced directory (use --allow-synced-dir to override)
    check_cloud_sync_path

    # Check for existing installation (re-initialization detection)
    if config_file_exists; then
        local existing_backend
        existing_backend="$(read_config_value "backend")"
        local existing_version
        existing_version="$(read_config_value "pyve_version")"
        
        # Handle re-initialization based on mode.
        # (PYVE_REINIT_MODE="update" path removed in v2.0 / H.e.9 —
        # `pyve update` is the new entry point.)
        if [[ "${PYVE_REINIT_MODE:-}" == "force" ]]; then
            # Force re-initialization mode
            warn "Force re-initialization: this will purge the existing environment ($existing_backend)"

            # Run pre-flight checks BEFORE purging so the environment is still intact
            # if the user decides to abort or a check fails.
            # We capture the backend here and reuse it in the main flow to avoid
            # prompting the user twice in the ambiguous case (env.yml + pyproject.toml).
            # skip_config=true: --force is a clean slate — the config records the OLD
            # backend and must not prevent re-detection from project files.
            preflight_backend="$(get_backend_priority "$backend_flag" "true")"
            if [[ "$preflight_backend" == "micromamba" ]]; then
                # Mirror the non-force flow (see the main micromamba branch below):
                # scaffold a starter environment.yml on a fresh dir BEFORE lock
                # validation, otherwise validate_lock_file_status's "neither file"
                # case fires and aborts the switch on projects that the non-force
                # path handles fine.
                if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode"; then
                    info "Scaffolded starter environment.yml (python=$python_version)"
                    info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
                    export PYVE_NO_LOCK=1
                fi
                if ! validate_lock_file_status "$strict_mode"; then
                    fail "Pre-flight check failed — no changes made"
                fi
                lock_preflight_done=true
            fi

            # Prompt for confirmation (skip in CI or if PYVE_FORCE_YES is set).
            # Show a summary of what will happen so the user can make an informed choice.
            if [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
                if [[ "$preflight_backend" != "$existing_backend" ]]; then
                    warn "Backend change: $existing_backend → $preflight_backend"
                fi
                info "Purge:   existing $existing_backend environment"
                info "Rebuild: fresh $preflight_backend environment"
                if ! ask_yn "Proceed"; then
                    info "Cancelled — no changes made, existing environment preserved"
                    exit 0
                fi
            fi

            # Don't preserve backend on --force - let normal detection happen
            # This allows the interactive prompt to appear in ambiguous cases
            # (when both environment.yml and pyproject.toml exist)

            # Purge existing installation
            banner "Purging existing environment"
            purge_project --keep-testenv --yes
            success "Environment purged"
            banner "Rebuilding fresh environment"

        else
            # Interactive mode (no flag specified)
            warn "Project already initialized with Pyve"
            if [[ -n "$existing_version" ]]; then
                info "Recorded version: $existing_version"
            fi
            info "Current version:  $VERSION"
            info "Backend:          $existing_backend"
            printf "\n  What would you like to do?\n"
            printf "    1. Update in-place (preserves environment, updates config)\n"
            printf "    2. Purge and re-initialize (clean slate)\n"
            printf "    3. Cancel\n\n"
            printf "  %sChoose [1/2/3]:%s " "${Y}" "${RESET}"
            read -r choice

            case "$choice" in
                1)
                    # Check for conflicts before updating
                    if [[ -n "$backend_flag" ]] && [[ "$backend_flag" != "$existing_backend" ]]; then
                        warn "Cannot update in-place: backend change detected ($existing_backend → $backend_flag)"
                        fail "Use option 2 to purge and re-initialize with new backend"
                    fi

                    # Perform safe update
                    if ! update_config_version; then
                        fail "Failed to update configuration (config may be corrupted)"
                    fi
                    success "Configuration updated"
                    if [[ -n "$existing_version" ]]; then
                        info "Version: $existing_version → $VERSION"
                    else
                        info "Version: (not recorded) → $VERSION"
                    fi
                    info "Backend: $existing_backend (unchanged)"
                    info "Project updated to Pyve v$VERSION"

                    # If the environment directory is missing (e.g. freshly cloned repo
                    # where .venv is gitignored), fall through to create it.
                    local _interactive_env_missing=false
                    if [[ "$existing_backend" == "venv" ]]; then
                        local _interactive_venv_dir
                        _interactive_venv_dir="$(read_config_value "venv.directory")"
                        _interactive_venv_dir="${_interactive_venv_dir:-$DEFAULT_VENV_DIR}"
                        if [[ ! -d "$_interactive_venv_dir" ]]; then
                            info "Environment directory '$_interactive_venv_dir' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    elif [[ "$existing_backend" == "micromamba" ]]; then
                        local _interactive_env_name
                        _interactive_env_name="$(read_config_value "micromamba.env_name")"
                        if [[ -n "$_interactive_env_name" ]] && [[ ! -d ".pyve/envs/$_interactive_env_name" ]]; then
                            info "Environment '.pyve/envs/$_interactive_env_name' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    fi
                    if [[ "$_interactive_env_missing" == false ]]; then
                        footer_box
                        return 0
                    fi
                    # Fall through to environment creation below.
                    ;;
                2)
                    # Purge and continue
                    banner "Purging existing environment"
                    purge_project --keep-testenv --yes
                    success "Environment purged"
                    banner "Rebuilding fresh environment"
                    ;;
                3)
                    info "Initialization cancelled"
                    exit 0
                    ;;
                *)
                    fail "Invalid choice: $choice"
                    ;;
            esac
        fi
    fi
    
    # Validate backend if specified
    if [[ -n "$backend_flag" ]]; then
        if ! validate_backend "$backend_flag"; then
            exit 1
        fi
    fi
    
    # Determine backend to use
    # If the force pre-flight already resolved the backend (to avoid prompting twice
    # in the ambiguous env.yml + pyproject.toml case), reuse that result.
    local backend
    if [[ -n "$preflight_backend" ]]; then
        backend="$preflight_backend"
    else
        backend="$(get_backend_priority "$backend_flag")"
    fi
    
    # Check if micromamba backend is selected and handle bootstrap
    if [[ "$backend" == "micromamba" ]]; then
        # H.f.7: if the directory has neither `environment.yml` nor
        # `conda-lock.yml`, and strict-mode is off, scaffold a starter
        # `environment.yml` before the (expensive) bootstrap step.
        # Doing this early means the user-visible error surface in a
        # clean directory is "scaffolded and proceeded" instead of the
        # H.f.6 "missing environment.yml" hard-error path.
        if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode"; then
            info "Scaffolded starter environment.yml (python=$python_version)"
            info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
            # No conda-lock.yml yet (we just generated the source file).
            # Take validate_lock_file_status's existing bypass so init
            # proceeds without insisting on a lock that can't yet exist.
            export PYVE_NO_LOCK=1
        fi

        # Check if micromamba is available
        if ! check_micromamba_available; then
            # Micromamba not found - offer bootstrap
            if [[ "$auto_bootstrap" == true ]]; then
                # Auto-bootstrap mode (non-interactive)
                if ! bootstrap_micromamba_auto "$bootstrap_to"; then
                    exit 1
                fi
            else
                # Interactive bootstrap prompt
                local context=$'Detected: environment.yml\nRequired: micromamba'
                if ! bootstrap_micromamba_interactive "$context"; then
                    exit 1
                fi
            fi
        fi
        
        # At this point, micromamba should be available
        if ! check_micromamba_available; then
            log_error "Micromamba still not available after bootstrap attempt"
            exit 1
        fi
        
        # Validate lock file status if micromamba backend
        # (skipped when pre-flight already ran it in --force path)
        if [[ "$lock_preflight_done" != "true" ]]; then
            if ! validate_lock_file_status "$strict_mode"; then
                exit 1
            fi
        fi
        
        # Resolve and validate environment name
        local env_name
        env_name="$(resolve_environment_name "$env_name_flag")"
        if ! validate_environment_name "$env_name"; then
            exit 1
        fi
        info "Environment name: $env_name"

        # Validate environment file
        if ! validate_environment_file; then
            exit 1
        fi

        # Create micromamba environment
        banner "Initializing micromamba environment"
        info "Backend:         micromamba"
        info "Environment:     $env_name"

        local env_file
        env_file="$(detect_environment_file)"
        info "Using file:      $env_file"

        if ! create_micromamba_env "$env_name" "$env_file"; then
            exit 1
        fi

        # Verify environment
        if ! verify_micromamba_env "$env_name"; then
            warn "Environment created but verification failed"
        fi

        # Apply Python 3.12+ distutils shim if needed
        local env_prefix
        env_prefix=".pyve/envs/$env_name"
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -n "$micromamba_path" ]]; then
            pyve_install_distutils_shim_for_micromamba_prefix "$micromamba_path" "$env_prefix"
        fi

        # Configure direnv for micromamba (unless --no-direnv)
        local env_path=".pyve/envs/$env_name"
        if [[ "$no_direnv" == false ]]; then
            _init_direnv_micromamba "$env_name" "$env_path"
        else
            info "Skipping .envrc creation (--no-direnv)"
        fi

        # Create .env file
        _init_dotenv "$use_local_env"

        # Update .gitignore — since H.e.2a the template bakes in every
        # pyve-managed ignore pattern (.pyve/envs, .pyve/testenv, .envrc,
        # .env, .vscode/settings.json), so the micromamba path needs no
        # per-backend dynamic inserts.
        write_gitignore_template

        success "Updated .gitignore"

        # Create .pyve/config with version tracking
        mkdir -p .pyve
        cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: micromamba
micromamba:
  env_name: $env_name
EOF
        success "Created .pyve/config"

        # Generate .vscode/settings.json so IDEs use the correct interpreter
        write_vscode_settings "$env_name"

        info "Environment location: $env_path"

        # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
        prompt_install_pip_dependencies "micromamba" "$env_path"

        # project-guide hook (Story G.c / FR-G2)
        _init_run_project_guide_hooks "micromamba" "$env_path" \
            "$project_guide_mode" "$project_guide_completion_mode"

        if [[ "$no_direnv" == false ]]; then
            info "Note: ignore micromamba's 'activate' instructions above — Pyve uses direnv (or 'pyve run')"
            info "Next: run 'direnv allow' to activate the environment, or use 'pyve run <command>'"
        else
            info "Use 'pyve run <command>' to execute in environment"
        fi
        footer_box

        return 0
    fi
    
    # Validate inputs
    if ! validate_venv_dir_name "$venv_dir"; then
        exit 1
    fi
    
    if ! validate_python_version "$python_version"; then
        exit 1
    fi
    
    banner "Initializing Python environment"
    info "Backend:        $backend"
    info "Python version: $python_version"
    info "Venv directory: $venv_dir"

    # Source shell profiles to find version managers
    source_shell_profiles

    # Detect and validate version manager
    if ! detect_version_manager; then
        exit 1
    fi
    info "Using $VERSION_MANAGER for Python version management"

    # Check direnv (only if not using --no-direnv)
    if [[ "$no_direnv" == false ]]; then
        if ! check_direnv_installed; then
            exit 1
        fi
    fi

    # Ensure Python version is installed
    if ! ensure_python_version_installed "$python_version"; then
        exit 1
    fi

    # Set local Python version
    _init_python_version "$python_version"

    # Create virtual environment
    _init_venv "$venv_dir"

    # Apply Python 3.12+ distutils shim if needed
    if [[ -x "$venv_dir/bin/python" ]]; then
        pyve_install_distutils_shim_for_python "$venv_dir/bin/python"
    fi

    # Configure direnv (unless --no-direnv)
    if [[ "$no_direnv" == false ]]; then
        _init_direnv_venv "$venv_dir"
    else
        info "Skipping .envrc creation (--no-direnv)"
    fi

    # Create .env file
    _init_dotenv "$use_local_env"

    # Update .gitignore
    _init_gitignore "$venv_dir"

    # Create .pyve/config with version tracking
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: venv
venv:
  directory: $venv_dir
python:
  version: $python_version
EOF
    success "Created .pyve/config"

    # Ensure dev/test runner environment exists (upgrade-friendly)
    ensure_testenv_exists

    # Absolute venv path — used by both dep install and project-guide hooks
    local _venv_abs
    _venv_abs="$(cd "$venv_dir" && pwd)"

    # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
    prompt_install_pip_dependencies "venv" "$_venv_abs"

    # project-guide hook (Story G.c / FR-G2)
    _init_run_project_guide_hooks "venv" "$_venv_abs" \
        "$project_guide_mode" "$project_guide_completion_mode"

    if [[ "$no_direnv" == false ]]; then
        info "Next step: run 'direnv allow' to activate the environment"
    else
        info "Use 'pyve run <command>' to execute commands in the environment"
    fi
    footer_box
}

_init_python_version() {
    local version="$1"
    local version_file
    version_file="$(get_version_file_name)"
    
    if [[ -f "$version_file" ]]; then
        info "$version_file already exists, skipping"
    else
        set_local_python_version "$version"
        success "Created $version_file with Python $version"
    fi
}

_init_venv() {
    local venv_dir="$1"

    if [[ -d "$venv_dir" ]]; then
        info "Virtual environment '$venv_dir' already exists, skipping"
    else
        info "Creating virtual environment in '$venv_dir'..."
        run_cmd python -m venv "$venv_dir"
        success "Created virtual environment"
    fi
}

_init_direnv_venv() {
    local venv_dir="$1"
    local project_name
    project_name="$(basename "$(pwd)")"

    write_envrc_template "$venv_dir/bin" "VIRTUAL_ENV" "$venv_dir" "venv" "$project_name"
}

_init_direnv_micromamba() {
    local env_name="$1"
    local env_path="$2"

    write_envrc_template "$env_path/bin" "CONDA_PREFIX" "$env_path" "micromamba" "$env_name"
}

_init_dotenv() {
    local use_local_env="$1"

    if [[ -f "$ENV_FILE_NAME" ]]; then
        info "$ENV_FILE_NAME already exists, skipping"
        return
    fi

    if [[ "$use_local_env" == true ]] && [[ -f "$LOCAL_ENV_FILE" ]]; then
        cp "$LOCAL_ENV_FILE" "$ENV_FILE_NAME"
        success "Copied $LOCAL_ENV_FILE to $ENV_FILE_NAME"
    else
        touch "$ENV_FILE_NAME"
        if [[ "$use_local_env" == true ]]; then
            warn "$LOCAL_ENV_FILE not found, created empty $ENV_FILE_NAME"
        else
            success "Created empty $ENV_FILE_NAME"
        fi
    fi

    # Set secure permissions
    chmod 600 "$ENV_FILE_NAME"
}

_init_gitignore() {
    local venv_dir="$1"
    local section="# Pyve virtual environment"

    # Rebuild .gitignore: Pyve-managed template at top, user entries below.
    # Since H.e.2a, the template bakes in .pyve/envs, .pyve/testenv, .envrc,
    # .env, and .vscode/settings.json — the only pattern still inserted
    # dynamically is the user-overridable venv directory name.
    write_gitignore_template
    insert_pattern_in_gitignore_section "$venv_dir" "$section"

    success "Updated .gitignore"
}
show_init_help() {
    cat << 'EOF'
pyve init - Initialize a Python virtual environment in the current directory

Usage:
  pyve init [<dir>] [options]

Arguments:
  <dir>                              Custom venv directory name (default: .venv)

Options:
  --python-version <ver>             Set Python version (e.g., 3.13.7)
  --backend <type>                   Backend to use: venv, micromamba, auto
  --auto-bootstrap                   Install micromamba without prompting (if needed)
  --bootstrap-to <location>          Where to install micromamba: project, user
  --strict                           Error on stale or missing lock files
  --no-lock                          Bypass missing conda-lock.yml error (not recommended)
  --env-name <name>                  Environment name (micromamba backend)
  --no-direnv                        Skip .envrc creation (for CI/CD)
  --auto-install-deps                Auto-install from pyproject.toml / requirements.txt
  --no-install-deps                  Skip dependency installation prompt (for CI/CD)
  --local-env                        Copy ~/.local/.env template
  --update                           Safely update an existing installation
  --force                            Purge and re-initialize (destructive)
  --allow-synced-dir                 Bypass cloud-sync directory check

  project-guide integration (three-step post-init hook):
    1. pip install --upgrade project-guide   (latest version)
    2. project-guide init --no-input          (creates .project-guide.yml + docs/project-guide/)
    3. shell completion in ~/.zshrc / ~/.bashrc (sentinel-bracketed block)

    --project-guide                  Run all three steps (overrides auto-skip below)
    --no-project-guide               Skip all three steps (no prompt)
    --project-guide-completion       Add shell completion (no prompt) — step 3 only
    --no-project-guide-completion    Skip shell completion (no prompt) — step 3 only

  Auto-skip safety:
    If 'project-guide' is already declared as a dependency in your
    pyproject.toml, requirements.txt, or environment.yml, pyve will NOT
    auto-install or run 'project-guide init' (avoids version conflicts
    with your pin). Pass --project-guide to override.

  Environment variables for the project-guide hooks:
    PYVE_PROJECT_GUIDE=1              Same as --project-guide
    PYVE_NO_PROJECT_GUIDE=1           Same as --no-project-guide
    PYVE_PROJECT_GUIDE_COMPLETION=1   Same as --project-guide-completion
    PYVE_NO_PROJECT_GUIDE_COMPLETION=1 Same as --no-project-guide-completion

  CI defaults (non-interactive, i.e. CI=1 or PYVE_FORCE_YES=1):
    project-guide install             → INSTALL (matches interactive default)
    project-guide shell completion    → SKIP (editing rc files in CI is surprising)

  Note: pyve init --update does NOT run the project-guide hook (minimal-touch).

Examples:
  pyve init                                # Auto-detect backend, default venv
  pyve init myenv                          # Custom venv directory name
  pyve init --backend venv                 # Force venv backend
  pyve init --backend micromamba           # Force micromamba backend
  pyve init --python-version 3.13.7        # Pin Python version
  pyve init --no-direnv                    # Skip direnv (CI/CD)
  pyve init --force                        # Purge and rebuild
  pyve init --project-guide                # Install project-guide without prompting
  pyve init --no-project-guide             # Skip project-guide entirely

See `pyve --help` for the full command list.
EOF
}
