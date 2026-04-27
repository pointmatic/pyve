# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve update — non-destructive upgrade (Story H.e.2)
#
# Refreshes managed files (config, .gitignore, .vscode/settings.json,
# project-guide scaffolding) without rebuilding the venv or touching
# user state (.env, .envrc, user sections of .gitignore). Never
# prompts. Never changes the recorded backend. Never creates files
# that don't already exist (`.vscode/settings.json`). Use
# `pyve init --force` to rebuild the environment.
#
# Spec: docs/specs/phase-H-cli-refactor-design.md §4.3.
#
# Function-name note: this function is named `update_project` per
# the project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve update` operates on the project (`.pyve/config`,
# `.gitignore`, `.vscode/settings.json`, project-guide scaffolding).
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

update_project() {
    local pg_mode=""  # "" | "no"  (only --no-project-guide is supported per H.d §4.3)

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-project-guide)
                pg_mode="no"
                shift
                ;;
            -*)
                unknown_flag_error "update" "$1" --no-project-guide --help
                ;;
            *)
                log_error "pyve update takes no positional arguments (got: $1)"
                log_error "See: pyve update --help"
                exit 1
                ;;
        esac
    done

    # Sanity check: .pyve/config must exist. Without it we don't know the
    # backend or how to refresh anything.
    if ! config_file_exists; then
        log_error "pyve update requires an initialized project."
        log_error "No .pyve/config found. Run 'pyve init' first."
        exit 1
    fi

    local backend
    backend="$(read_config_value "backend")"
    if [[ -z "$backend" ]]; then
        log_error "Corrupt .pyve/config: missing 'backend' key."
        log_error "Run: pyve init --force"
        exit 1
    fi

    local previous_version
    previous_version="$(read_config_value "pyve_version")"

    log_info "Updating project configuration to Pyve v$VERSION..."

    # Step 1: bump pyve_version in .pyve/config (idempotent; writes even
    # when already at current version — simplifies the happy path).
    if ! update_config_version; then
        log_error "Failed to update .pyve/config."
        exit 1
    fi
    if [[ -z "$previous_version" ]]; then
        log_success "pyve_version: (not recorded) → $VERSION"
    elif [[ "$previous_version" == "$VERSION" ]]; then
        log_success "pyve_version: $VERSION (already current)"
    else
        log_success "pyve_version: $previous_version → $VERSION"
    fi

    # Step 2: refresh Pyve-managed sections of .gitignore.
    write_gitignore_template
    log_success "Refreshed .gitignore (Pyve-managed sections)"

    # Step 3: refresh .vscode/settings.json IF it already exists. Never
    # create — that's user opt-in at init time.
    if [[ -f ".vscode/settings.json" ]] && [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name")"
        if [[ -n "$env_name" ]]; then
            PYVE_REINIT_MODE=force write_vscode_settings "$env_name"
        fi
    fi

    # Step 4: ensure .pyve/ exists (should already, by precondition).
    mkdir -p .pyve

    # Step 5: refresh project-guide scaffolding if present and allowed.
    if [[ "$pg_mode" == "no" ]]; then
        log_info "Skipping project-guide refresh (--no-project-guide)"
    elif [[ -f ".project-guide.yml" ]]; then
        local env_path=""
        if [[ "$backend" == "venv" ]]; then
            local venv_dir
            venv_dir="$(read_config_value "venv.directory")"
            venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
            env_path="$venv_dir"
        elif [[ "$backend" == "micromamba" ]]; then
            local env_name
            env_name="$(read_config_value "micromamba.env_name")"
            if [[ -n "$env_name" ]]; then
                env_path=".pyve/envs/$env_name"
            fi
        fi
        if [[ -n "$env_path" ]] && [[ -d "$env_path" ]]; then
            run_project_guide_update_in_env "$backend" "$env_path"
        else
            log_warning "Environment not found; skipping project-guide update."
            log_warning "  (Run 'pyve init --force' to rebuild the environment.)"
        fi
    fi

    echo ""
    log_info "Project updated to Pyve v$VERSION."
    return 0
}
show_update_help() {
    cat << 'EOF'
pyve update - Non-destructive upgrade: refresh managed files and config

Usage:
  pyve update [--no-project-guide]

Description:
  Updates a pyve-managed project to the current pyve version WITHOUT
  rebuilding the virtual environment. Safe to run on any pyve-managed
  project; idempotent.

  Refreshes:
    - pyve_version in .pyve/config
    - Pyve-managed sections of .gitignore
    - .vscode/settings.json (only if it already exists)
    - project-guide scaffolding (via 'project-guide update --no-input')

  Does NOT:
    - rebuild the virtual environment (use 'pyve init --force' for that)
    - create .env or .envrc (those are user state)
    - re-prompt for backend (the recorded backend is preserved)

Options:
  --no-project-guide          Skip the project-guide refresh step

Exit codes:
  0    Success (including no-op when already at current version).
  1    Failure (missing .pyve/config, corrupt config, unwritable files).

See also:
  pyve init --force          Destroy + rebuild the environment
  pyve --help                Full command list
EOF
}
