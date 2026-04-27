# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve purge — remove pyve-managed environment artifacts
#
# Removes the venv / micromamba env, version manager files, .envrc,
# .env (only if empty — v0.6.0 smart purge), pyve-managed sections of
# .gitignore, and the .pyve/ directory. Optionally preserves
# .pyve/testenv via --keep-testenv (used by `init --force` to avoid
# rebuilding the dev/test runner across re-inits).
#
# Function-name note: this function is named `purge_project` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve purge` operates on the project (removes every Pyve-
# managed artifact across venv/conda env, rc files, .gitignore
# sections, .pyve/ directory).
#
# Cross-command callsite: `init` (still in pyve.sh until K.l) calls
# `purge_project --keep-testenv --yes` from its --force pre-flight
# and from the interactive option-2 (purge-and-rebuild) path. Bash
# resolves the call at runtime via the global function table.
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

purge_project() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local keep_testenv=false
    local venv_dir_explicit=false
    local skip_confirm=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-testenv)
                keep_testenv=true
                shift
                ;;
            --yes|-y)
                skip_confirm=true
                shift
                ;;
            -*)
                unknown_flag_error "purge" "$1" --keep-testenv --yes --help
                ;;
            *)
                venv_dir="$1"
                venv_dir_explicit=true
                shift
                ;;
        esac
    done

    header_box "pyve purge"

    # Destructive-confirmation prompt. Skipped when:
    #   --yes / -y passed (e.g., by `init --force`), CI=1, or PYVE_FORCE_YES=1.
    if [[ "$skip_confirm" != true ]] && [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
        warn "This will remove pyve-managed environment artifacts from the current project."
        if ! ask_yn "Proceed"; then
            info "Aborted — no changes made"
            exit 0
        fi
    fi

    # Source shell profiles to detect version manager
    source_shell_profiles
    detect_version_manager 2>/dev/null || true

    # Remove version file
    _purge_version_file

    # If a project config exists, prefer its venv directory when the user did not
    # explicitly pass a venv dir to purge.
    if [[ "$venv_dir_explicit" == false ]] && config_file_exists; then
        local configured_venv_dir
        configured_venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
        if [[ -n "$configured_venv_dir" ]]; then
            venv_dir="$configured_venv_dir"
        fi
    fi

    # Remove virtual environment
    _purge_venv "$venv_dir"

    # Remove .pyve directory (config and micromamba envs)
    if [[ "$keep_testenv" == true ]]; then
        if [[ -d ".pyve" ]]; then
            if [[ -d ".pyve/$TESTENV_DIR_NAME" ]]; then
                rm -rf ".pyve/config" ".pyve/envs" 2>/dev/null || true
                find ".pyve" -mindepth 1 -maxdepth 1 ! -name "$TESTENV_DIR_NAME" -exec rm -rf {} + 2>/dev/null || true
                success "Removed .pyve directory contents (preserved .pyve/$TESTENV_DIR_NAME)"
            else
                rm -rf ".pyve"
                success "Removed .pyve directory (config and micromamba environments)"
            fi
        fi
    else
        _purge_pyve_dir
        purge_testenv_dir
    fi

    # Remove .envrc
    _purge_envrc

    # Remove .env (only if empty - v0.6.0 smart purge)
    _purge_dotenv

    # Clean .gitignore
    _purge_gitignore "$venv_dir"

    footer_box
}

_purge_version_file() {
    local version_file

    # Try to remove both possible version files
    for version_file in ".tool-versions" ".python-version"; do
        if [[ -f "$version_file" ]]; then
            rm -f "$version_file"
            success "Removed $version_file"
        fi
    done
}

_purge_venv() {
    local venv_dir="$1"

    if [[ -d "$venv_dir" ]]; then
        rm -rf "$venv_dir"
        success "Removed $venv_dir"
    else
        info "No virtual environment found at '$venv_dir'"
    fi
}

_purge_pyve_dir() {
    if [[ -d ".pyve" ]]; then
        # Check if micromamba environments exist
        if [[ -d ".pyve/envs" ]]; then
            # Try to remove micromamba environment(s) properly first
            local micromamba_path
            micromamba_path="$(get_micromamba_path 2>/dev/null || true)"

            if [[ -n "$micromamba_path" ]] && [[ -x "$micromamba_path" ]]; then
                # Get environment name from config if it exists
                local env_name
                if config_file_exists; then
                    env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
                fi

                # If we have an env name, try to remove it
                if [[ -n "$env_name" ]]; then
                    info "Removing micromamba environment '$env_name'..."
                    if "$micromamba_path" env remove -n "$env_name" -y 2>/dev/null; then
                        success "Removed micromamba environment '$env_name'"
                    else
                        # If named removal fails, try prefix-based removal
                        info "Named removal failed, trying prefix-based removal..."
                        "$micromamba_path" env remove -p ".pyve/envs/$env_name" -y 2>/dev/null || true
                    fi
                else
                    # No env name in config, try to find and remove any environments in .pyve/envs
                    for env_dir in .pyve/envs/*; do
                        if [[ -d "$env_dir" ]]; then
                            info "Removing micromamba environment at '$env_dir'..."
                            "$micromamba_path" env remove -p "$env_dir" -y 2>/dev/null || true
                        fi
                    done
                fi
            else
                info "Micromamba not found, will force-remove .pyve directory"
            fi
        fi

        # Now remove the .pyve directory
        rm -rf ".pyve"
        success "Removed .pyve directory (config and micromamba environments)"
    fi
}

_purge_envrc() {
    if [[ -f ".envrc" ]]; then
        rm -f ".envrc"
        success "Removed .envrc"
    fi
}

_purge_dotenv() {
    if [[ -f "$ENV_FILE_NAME" ]]; then
        if is_file_empty "$ENV_FILE_NAME"; then
            rm -f "$ENV_FILE_NAME"
            success "Removed $ENV_FILE_NAME (was empty)"
        else
            warn "$ENV_FILE_NAME preserved (contains data). Delete manually if desired."
        fi
    fi
}

_purge_gitignore() {
    local venv_dir="$1"

    if [[ -f ".gitignore" ]]; then
        remove_pattern_from_gitignore "$venv_dir"
        remove_pattern_from_gitignore "$ENV_FILE_NAME"
        remove_pattern_from_gitignore ".envrc"
        success "Cleaned .gitignore"
    fi
}
