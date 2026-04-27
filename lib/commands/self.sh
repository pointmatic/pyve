# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve self — manage pyve's own installation
#
# Single-file namespace command (project-essentials F-9): one file
# contains the namespace dispatcher (`self`), the leaves
# (`self_install`, `self_uninstall`), and every command-private
# helper (with `_self_` prefix per project-essentials F).
#
# Sub-commands:
#   pyve self install     Copy pyve to ~/.local/bin and wire PATH/prompt
#   pyve self uninstall   Reverse of `self install` (preserves non-empty
#                         ~/.local/.env)
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution. The file is a library; running it as a
# script would fall through to nothing useful and confuse the user.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Leaf: pyve self install
#------------------------------------------------------------

self_install() {
    # Detect Homebrew-managed installs and warn/skip.
    if [[ "$(detect_install_source)" == "homebrew" ]]; then
        log_warning "Pyve is managed by Homebrew ($SCRIPT_DIR)."
        printf "  To update:    brew upgrade pointmatic/tap/pyve\n"
        printf "  To uninstall: brew uninstall pyve\n"
        printf "\n  --install is for non-Homebrew (git clone) installations only.\n"
        exit 0
    fi

    local source_dir="$SCRIPT_DIR"

    # If running from installed location, read source dir from config
    if [[ "$SCRIPT_DIR" == "$TARGET_BIN_DIR" ]]; then
        if [[ -f "$SOURCE_DIR_FILE" ]]; then
            source_dir="$(cat "$SOURCE_DIR_FILE")"
            if [[ ! -d "$source_dir" ]] || [[ ! -f "$source_dir/pyve.sh" ]]; then
                log_error "Source directory no longer exists: $source_dir"
                log_error "Please run --install from the original pyve source directory."
                exit 1
            fi

            # Avoid rewriting the currently-running script. Delegate the reinstall to the
            # repo copy so the installer runs from a different file.
            exec "$source_dir/pyve.sh" --install
        else
            log_error "Cannot reinstall: source directory not recorded."
            log_error "Please run --install from the original pyve source directory."
            exit 1
        fi
    fi

    printf "\nInstalling pyve to %s...\n" "$TARGET_BIN_DIR"
    printf "Source: %s\n" "$source_dir"

    # Create target directory if needed
    if [[ ! -d "$TARGET_BIN_DIR" ]]; then
        mkdir -p "$TARGET_BIN_DIR"
        log_success "Created $TARGET_BIN_DIR"
    fi

    # Copy script (atomic write to avoid partially-written script execution)
    local tmp_script
    tmp_script="$(mktemp "$TARGET_BIN_DIR/pyve.sh.XXXXXX")"
    cp "$source_dir/pyve.sh" "$tmp_script"
    chmod +x "$tmp_script"
    mv -f "$tmp_script" "$TARGET_SCRIPT_PATH"
    log_success "Installed pyve.sh"

    # Copy lib directory
    if [[ -d "$source_dir/lib" ]]; then
        mkdir -p "$TARGET_BIN_DIR/lib"
        cp "$source_dir/lib/"*.sh "$TARGET_BIN_DIR/lib/"
        log_success "Installed lib/ helpers"
    fi

    # Copy per-command modules (Phase K extraction phase). The lib/*.sh
    # glob above is non-recursive, so this directory needs its own copy
    # step. Guard so older installs without lib/commands/ remain a no-op.
    if [[ -d "$source_dir/lib/commands" ]]; then
        mkdir -p "$TARGET_BIN_DIR/lib/commands"
        cp "$source_dir/lib/commands/"*.sh "$TARGET_BIN_DIR/lib/commands/"
        log_success "Installed lib/commands/ (per-command modules)"
    fi

    # Copy shell-completion scripts (H.e.9c)
    if [[ -d "$source_dir/lib/completion" ]]; then
        mkdir -p "$TARGET_BIN_DIR/lib/completion"
        cp "$source_dir/lib/completion/"* "$TARGET_BIN_DIR/lib/completion/" 2>/dev/null || true
        log_success "Installed lib/completion/ (shell completion)"
    fi

    # Save source directory for future reinstalls
    mkdir -p "$(dirname "$SOURCE_DIR_FILE")"
    printf "%s\n" "$source_dir" > "$SOURCE_DIR_FILE"
    log_success "Recorded source directory"

    # Create symlink
    if [[ -L "$TARGET_SYMLINK_PATH" ]] || [[ -f "$TARGET_SYMLINK_PATH" ]]; then
        rm -f "$TARGET_SYMLINK_PATH"
    fi
    ln -s "$TARGET_SCRIPT_PATH" "$TARGET_SYMLINK_PATH"
    log_success "Created symlink: pyve -> pyve.sh"

    # Add to PATH if needed
    _self_install_update_path

    # Install prompt hook for interactive shells
    _self_install_prompt_hook

    # Create local .env template
    _self_install_local_env_template

    printf "\n✓ pyve v%s installed successfully!\n" "$VERSION"
    printf "\nYou may need to restart your shell or run:\n"
    printf "  source ~/.zprofile  # or ~/.bash_profile\n"
    printf "  source ~/.zshrc     # or ~/.bashrc\n"

    # Shell-completion activation hint (H.e.9c)
    if [[ -d "$TARGET_BIN_DIR/lib/completion" ]]; then
        printf "\nTo enable tab completion, add one of these to your shell rc:\n"
        printf "  # bash:\n"
        printf "  source %s/lib/completion/pyve.bash\n" "$TARGET_BIN_DIR"
        printf "  # zsh (place _pyve on \$fpath, then compinit):\n"
        printf "  fpath=(%s/lib/completion \$fpath) && autoload -U compinit && compinit\n" "$TARGET_BIN_DIR"
    fi
}

#------------------------------------------------------------
# Private helper: append PATH entry to the active profile rc file.
#------------------------------------------------------------

_self_install_update_path() {
    local profile_file
    local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\"  # Added by pyve installer"

    # Determine profile file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        profile_file="$HOME/.zprofile"
    else
        profile_file="$HOME/.bash_profile"
    fi

    # Check if already in PATH
    if [[ ":$PATH:" == *":$TARGET_BIN_DIR:"* ]]; then
        log_info "$TARGET_BIN_DIR already in PATH"
        return
    fi

    # Check if line already in profile
    if [[ -f "$profile_file" ]] && grep -qF "# Added by pyve installer" "$profile_file"; then
        log_info "PATH already configured in $profile_file"
        return
    fi

    # Add to profile
    printf "\n%s\n" "$path_line" >> "$profile_file"
    log_success "Added $TARGET_BIN_DIR to PATH in $profile_file"
}

#------------------------------------------------------------
# Private helper: write the prompt-hook script and source it from the
# active rc file via the SDKMan-aware insertion helper. Idempotent —
# strips any prior `source $PROMPT_HOOK_FILE` line before re-inserting.
#------------------------------------------------------------

_self_install_prompt_hook() {
    local rc_file=""

    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        rc_file="$HOME/.zshrc"
    else
        rc_file="$HOME/.bashrc"
    fi

    mkdir -p "$(dirname "$PROMPT_HOOK_FILE")"
    cat > "$PROMPT_HOOK_FILE" << 'EOF'
if [[ -n "${ZSH_VERSION:-}" ]]; then
  if [[ -z "${_PYVE_ORIG_PROMPT+set}" ]]; then
    _PYVE_ORIG_PROMPT="$PROMPT"
  fi

  _pyve_prompt_update() {
    if [[ -n "${PYVE_PROMPT_PREFIX:-}" ]]; then
      PROMPT="${PYVE_PROMPT_PREFIX}${_PYVE_ORIG_PROMPT}"
    else
      PROMPT="${_PYVE_ORIG_PROMPT}"
    fi
  }

  if (( ${precmd_functions[(Ie)_pyve_prompt_update]} == 0 )); then
    precmd_functions+=(_pyve_prompt_update)
  fi
  _pyve_prompt_update
elif [[ -n "${BASH_VERSION:-}" ]]; then
  if [[ -z "${_PYVE_ORIG_PS1+set}" ]]; then
    _PYVE_ORIG_PS1="$PS1"
  fi

  _pyve_prompt_update() {
    if [[ -n "${PYVE_PROMPT_PREFIX:-}" ]]; then
      PS1="${PYVE_PROMPT_PREFIX}${_PYVE_ORIG_PS1}"
    else
      PS1="${_PYVE_ORIG_PS1}"
    fi
  }

  if [[ -z "${_PYVE_ORIG_PROMPT_COMMAND+set}" ]]; then
    _PYVE_ORIG_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
  fi

  PROMPT_COMMAND='_pyve_prompt_update;'
  if [[ -n "${_PYVE_ORIG_PROMPT_COMMAND}" ]]; then
    PROMPT_COMMAND+="${_PYVE_ORIG_PROMPT_COMMAND}"
  fi
  _pyve_prompt_update
fi
EOF

    local source_line="source \"$PROMPT_HOOK_FILE\"  # Added by pyve installer"

    # Ensure rc file exists
    if [[ ! -f "$rc_file" ]]; then
        touch "$rc_file"
    fi

    # Remove any existing pyve prompt hook line (idempotency: allows
    # relocating the line safely on re-install).
    local tmp_rc
    tmp_rc="$(mktemp)"
    grep -vF "$PROMPT_HOOK_FILE" "$rc_file" > "$tmp_rc"
    mv -f "$tmp_rc" "$rc_file"

    # Insert via the shared SDKMan-aware helper. This respects
    # SDKMan's "must be last" load-order guidance and matches the
    # insertion behavior of the project-guide completion block.
    insert_text_before_sdkman_marker_or_append "$rc_file" "$source_line"

    log_success "Added prompt hook to $rc_file"
}

#------------------------------------------------------------
# Private helper: ensure ~/.local/.env exists with secure permissions.
#------------------------------------------------------------

_self_install_local_env_template() {
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        log_info "$LOCAL_ENV_FILE already exists"
        return
    fi

    # Create directory if needed
    mkdir -p "$(dirname "$LOCAL_ENV_FILE")"

    # Create empty template with secure permissions
    touch "$LOCAL_ENV_FILE"
    chmod 600 "$LOCAL_ENV_FILE"
    log_success "Created $LOCAL_ENV_FILE template"
}

#------------------------------------------------------------
# Leaf: pyve self uninstall
#------------------------------------------------------------

self_uninstall() {
    # Detect Homebrew-managed installs and warn/skip.
    if [[ "$(detect_install_source)" == "homebrew" ]]; then
        log_warning "Pyve is managed by Homebrew ($SCRIPT_DIR)."
        printf "  To uninstall: brew uninstall pyve\n"
        printf "\n  --uninstall is for non-Homebrew (git clone) installations only.\n"
        exit 0
    fi

    printf "\nUninstalling pyve...\n"

    # Remove symlink
    if [[ -L "$TARGET_SYMLINK_PATH" ]]; then
        rm -f "$TARGET_SYMLINK_PATH"
        log_success "Removed symlink: $TARGET_SYMLINK_PATH"
    fi

    # Remove script
    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        rm -f "$TARGET_SCRIPT_PATH"
        log_success "Removed $TARGET_SCRIPT_PATH"
    fi

    # Remove lib directory
    if [[ -d "$TARGET_BIN_DIR/lib" ]]; then
        rm -rf "$TARGET_BIN_DIR/lib"
        log_success "Removed $TARGET_BIN_DIR/lib"
    fi

    # Remove local .env template (only if empty)
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        if is_file_empty "$LOCAL_ENV_FILE"; then
            rm -f "$LOCAL_ENV_FILE"
            log_success "Removed $LOCAL_ENV_FILE (was empty)"
        else
            log_warning "$LOCAL_ENV_FILE preserved (contains data). Delete manually if desired."
        fi
    fi

    # Remove source directory file
    if [[ -f "$SOURCE_DIR_FILE" ]]; then
        rm -f "$SOURCE_DIR_FILE"
        log_success "Removed $SOURCE_DIR_FILE"
    fi

    # Remove prompt hook
    _self_uninstall_prompt_hook

    # Remove PATH from profile (v0.6.1 feature)
    _self_uninstall_clean_path

    # Remove project-guide completion blocks from both common rc files.
    # Covers users who switched shells after installing the block. Each
    # call is a safe no-op if the block is absent or the file is missing.
    # (Story G.c / FR-G2)
    _self_uninstall_project_guide_completion

    printf "\n✓ pyve uninstalled.\n"
}

#------------------------------------------------------------
# Private helper: strip the project-guide completion block from both
# common rc files (covers users who switched shells post-install).
#------------------------------------------------------------

_self_uninstall_project_guide_completion() {
    local rc_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
    )
    local rc_file
    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]] && is_project_guide_completion_present "$rc_file"; then
            remove_project_guide_completion "$rc_file"
            log_success "Removed project-guide completion block from $rc_file"
        fi
    done
}

#------------------------------------------------------------
# Private helper: strip the PATH line added by `self install` from
# both common profile rc files. macOS/Linux sed in-place compatible.
#------------------------------------------------------------

_self_uninstall_clean_path() {
    local profile_files=(
        "$HOME/.zprofile"
        "$HOME/.bash_profile"
    )

    local profile_file
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]]; then
            # Remove the line added by pyve installer
            if grep -qF "# Added by pyve installer" "$profile_file"; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' '/# Added by pyve installer/d' "$profile_file"
                else
                    sed -i '/# Added by pyve installer/d' "$profile_file"
                fi
                log_success "Removed PATH entry from $profile_file"
            fi
        fi
    done
}

#------------------------------------------------------------
# Private helper: strip the `source $PROMPT_HOOK_FILE` line from both
# common rc files and remove the prompt-hook file itself.
#------------------------------------------------------------

_self_uninstall_prompt_hook() {
    local rc_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
    )

    local rc_file
    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]]; then
            if grep -qF "$PROMPT_HOOK_FILE" "$rc_file" && grep -qF "# Added by pyve installer" "$rc_file"; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' "\\|$PROMPT_HOOK_FILE|d" "$rc_file"
                else
                    sed -i "\\|$PROMPT_HOOK_FILE|d" "$rc_file"
                fi
                log_success "Removed prompt hook from $rc_file"
            fi
        fi
    done

    if [[ -f "$PROMPT_HOOK_FILE" ]]; then
        rm -f "$PROMPT_HOOK_FILE"
        log_success "Removed $PROMPT_HOOK_FILE"
    fi
}

#------------------------------------------------------------
# Namespace dispatcher: pyve self <subcommand>
#
# Function-name note: this function is named `self_command` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — for namespace dispatchers the operand is the sub-command
# name that follows. The K.e initial clean-name rename to `self()`
# violated the rule (no operand suffix); reverted in K.f follow-up.
#------------------------------------------------------------

self_command() {
    if [[ $# -eq 0 ]]; then
        show_self_help
        return 0
    fi

    case "$1" in
        install)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_install_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-install %s\n' "$*"
                return 0
            fi
            self_install
            ;;
        uninstall)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_uninstall_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-uninstall %s\n' "$*"
                return 0
            fi
            self_uninstall
            ;;
        --help|-h)
            show_self_help
            return 0
            ;;
        *)
            log_error "Unknown 'pyve self' subcommand: $1"
            show_self_help
            exit 1
            ;;
    esac
}
