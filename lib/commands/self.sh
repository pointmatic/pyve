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

    # Provision Pyve's own toolchain Python — best-effort.
    _self_install_toolchain_python

    # Install Pyve's toolchain Python deps (PyYAML) — best-effort.
    _self_install_toolchain_deps

    # Host project-guide as a Pyve-managed global tool —
    # best-effort; installs into the toolchain venv + shims onto PATH.
    _self_install_project_guide

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
# Private helper: provision (and version-track) Pyve's own toolchain
# Python during `self install`.
#
# Best-effort by contract: a build failure WARNS but never aborts the
# install — the resolver (pyve_toolchain_python) falls back to PATH
# `python`, so Pyve still works without the hidden venv. The
# version-keyed layout makes a DEFAULT_PYTHON_VERSION bump a no-op
# presence check on the new dir; ensure builds it, then stale sibling
# versions are pruned.
#------------------------------------------------------------

_self_install_toolchain_python() {
    if ! declare -F pyve_toolchain_python_ensure >/dev/null 2>&1; then
        return 0
    fi
    if pyve_toolchain_python_ensure; then
        log_success "Provisioned Pyve toolchain Python (${DEFAULT_PYTHON_VERSION:-unknown})"
        _self_prune_stale_toolchain_versions
    else
        log_warning "Could not provision Pyve toolchain Python — Pyve will fall back to 'python' on PATH."
        log_warning "  Set PYVE_PYTHON to pin an interpreter, or re-run 'pyve self install' later."
    fi
    return 0
}

#------------------------------------------------------------
# Private helper: remove toolchain version dirs other than the current
# DEFAULT_PYTHON_VERSION. The version-keyed layout means a default bump
# lands a fresh dir; the old one is dead weight.
#------------------------------------------------------------

_self_prune_stale_toolchain_versions() {
    declare -F pyve_toolchain_root >/dev/null 2>&1 || return 0
    local root current d ver
    root="$(pyve_toolchain_root)"
    current="${DEFAULT_PYTHON_VERSION:-}"
    [[ -d "$root" ]] || return 0
    [[ -n "$current" ]] || return 0
    for d in "$root"/*/; do
        [[ -d "$d" ]] || continue
        ver="$(basename "$d")"
        if [[ "$ver" != "$current" ]]; then
            rm -rf "$d"
            log_info "Pruned stale toolchain Python: $ver"
        fi
    done
}

#------------------------------------------------------------
# Private helper: host project-guide as a Pyve-managed global tool
#. project-guide is a version-agnostic any-stack
# utility, so Pyve installs ONE copy into its toolchain venv (next to the
# toolchain Python) and shims the console script onto ~/.local/bin — which
# `self install` already creates and puts on PATH — so `project-guide`
# resolves in every shell, no machinery installed per project.
#
# Best-effort by contract (mirrors _self_install_toolchain_python): a
# missing toolchain venv or a failed pip install WARNS but never aborts.
# Idempotent: `ln -sf` re-points the shim to the current version-keyed
# venv, so a DEFAULT_PYTHON_VERSION bump self-heals on the next install.
# Requires project-guide >= 2.13.0 (the pyve-toolchain-hosting contract).
#------------------------------------------------------------

# Install Pyve's toolchain Python dependencies into the toolchain venv
#. PyYAML (lib/pyve_env_spec_helper.py — reads §4.0
# of the env-dependencies doc) and tomlkit (lib/pyve_env_sync_helper.py —
# the round-trip-preserving `pyve.toml` writer for `pyve env sync`).
# Best-effort (mirrors _self_install_toolchain_python): a missing venv or
# failed pip WARNS but never aborts — the env-sync seam then degrades to a
# precise "run pyve self install" error. Removal rides the toolchain-tree
# rm -rf in `pyve self uninstall` (no extra step).
_self_install_toolchain_deps() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0
    local venv_dir pip_cmd
    venv_dir="$(pyve_toolchain_venv_dir)"
    pip_cmd="$venv_dir/bin/pip"
    if [[ ! -x "$pip_cmd" ]]; then
        return 0
    fi
    if run_quiet "$pip_cmd" install --upgrade pyyaml tomlkit; then
        log_success "Installed Pyve toolchain dependencies (PyYAML, tomlkit)"
    else
        log_warning "Could not install Pyve toolchain dependencies (PyYAML, tomlkit) — 'pyve env sync' may be unavailable until 'pyve self install' is re-run"
    fi
    return 0
}

_self_install_project_guide() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0
    local venv_dir pip_cmd
    venv_dir="$(pyve_toolchain_venv_dir)"
    pip_cmd="$venv_dir/bin/pip"
    # Toolchain venv not provisioned (build skipped/failed) — nothing to
    # install into or shim. Non-fatal; the next `self install` retries.
    if [[ ! -x "$pip_cmd" ]]; then
        return 0
    fi
    if run_quiet "$pip_cmd" install --upgrade 'project-guide>=2.13.0'; then
        log_success "Installed project-guide into the Pyve toolchain"
        # Shared shim-link helper (Story N.bh, lib/toolchain_python.sh).
        pyve_link_project_guide_shim "$venv_dir"
        log_info "Linked project-guide → $HOME/.local/bin/project-guide"
    else
        log_warning "Could not install project-guide into the toolchain (skip; re-run 'pyve self install' later)"
    fi
    return 0
}

# Remove the project-guide shim on `self uninstall`. Only our own symlink
# is removed — a real project-guide binary a user installed by hand (a
# regular file, not a symlink) is left untouched. The toolchain-tree
# rm -rf in _self_uninstall_toolchain_python drops the hosted package.
_self_uninstall_project_guide() {
    local shim="$HOME/.local/bin/project-guide"
    if [[ -L "$shim" ]]; then
        rm -f "$shim"
        log_success "Removed project-guide shim ($shim)"
    fi
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

    # Remove the project-guide global shim. The hosted
    # package itself goes with the toolchain-tree removal below.
    _self_uninstall_project_guide

    # Remove Pyve's own toolchain Python tree.
    _self_uninstall_toolchain_python

    printf "\n✓ pyve uninstalled.\n"
}

#------------------------------------------------------------
# Private helper: remove the entire Pyve-owned toolchain Python tree on
# `self uninstall`. Safe no-op when absent.
#------------------------------------------------------------

_self_uninstall_toolchain_python() {
    declare -F pyve_toolchain_root >/dev/null 2>&1 || return 0
    local root
    root="$(pyve_toolchain_root)"
    if [[ -d "$root" ]]; then
        rm -rf "$root"
        log_success "Removed Pyve toolchain Python tree ($root)"
    fi
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

# ============================================================
# `pyve self migrate` (v2 → v3 migration command)
# ============================================================
#
# Deterministic, idempotent path that brings a v2.7/v2.8 project to
# v3 in one invocation: writes `pyve.toml` from legacy artifacts,
# backs them up under `.pyve/.v2-legacy/`, optionally invokes
# `pyve init --force` to rebuild envs at the v3 state layout
#.
#
# Flags:
#   --dry-run     Print the migration plan; perform no writes.
#   --no-rebuild  Write pyve.toml + back up legacy sources; skip
#                 the `pyve init --force` rebuild step.
#
# Idempotency: re-running on a fully-migrated project (pyve.toml
# present, no v2 sources) is a clean no-op with an informational
# message — never destructive.

# Detect v2 configuration. Returns:
#   0 — v2 sources present AND `pyve.toml` absent (migration needed)
#   1 — already migrated, never v2, or pyve.toml present (no-op)
#
# Sources that mark a project as v2:
#   .pyve/config                              (the canonical v2 YAML)
#   .pyve/testenvs/                           (v2.8 layout on disk)
#   [tool.pyve.testenvs.*] in pyproject.toml  (v2.8 declared testenvs)
#
# Presence of `pyve.toml` short-circuits to "no-op" — even if legacy
# sources also exist, the v3 manifest wins and self_migrate stays a
# no-op. The user can manually delete `pyve.toml` to force a fresh
# migration pass.
_self_migrate_detect_v2_sources() {
    [[ -f pyve.toml ]] && return 1
    [[ -f .pyve/config ]] && return 0
    [[ -d .pyve/testenvs ]] && return 0
    if [[ -f pyproject.toml ]] \
       && grep -qE '^\[tool\.pyve\.testenvs(\]|\.)' pyproject.toml; then
        return 0
    fi
    return 1
}

# Read v2 .pyve/config + [tool.pyve.testenvs.*] into private shell
# state variables. Resets state on entry so repeated calls are
# self-contained.
#
# Populates:
#   _MIGRATE_V2_BACKEND                  — "venv" | "micromamba" | ""
#   _MIGRATE_V2_VENV_DIR                 — venv.directory or ""
#   _MIGRATE_V2_PYTHON_VERSION           — python.version or ""
#   _MIGRATE_V2_MICROMAMBA_ENV_NAME      — micromamba.env_name or ""
#   _MIGRATE_V2_TESTENV_NAMES[]          — declared env names
#   _MIGRATE_V2_TESTENV_BACKEND[]        — backend per env
#   _MIGRATE_V2_TESTENV_LAZY[]           — "0" / "1"
#   _MIGRATE_V2_TESTENV_EXTRA[]          — pyproject extra or ""
#   _MIGRATE_V2_TESTENV_MANIFEST[]       — manifest path or ""
#   _MIGRATE_V2_TESTENV_REQUIREMENTS_Q[] — shell-quoted requirements list
_self_migrate_read_legacy() {
    _MIGRATE_V2_BACKEND=""
    _MIGRATE_V2_VENV_DIR=""
    _MIGRATE_V2_PYTHON_VERSION=""
    _MIGRATE_V2_MICROMAMBA_ENV_NAME=""
    _MIGRATE_V2_TESTENV_NAMES=()
    _MIGRATE_V2_TESTENV_BACKEND=()
    _MIGRATE_V2_TESTENV_LAZY=()
    _MIGRATE_V2_TESTENV_EXTRA=()
    _MIGRATE_V2_TESTENV_MANIFEST=()
    _MIGRATE_V2_TESTENV_REQUIREMENTS_Q=()

    if [[ -f .pyve/config ]]; then
        _MIGRATE_V2_BACKEND="$(read_config_value backend 2>/dev/null || true)"
        _MIGRATE_V2_VENV_DIR="$(read_config_value venv.directory 2>/dev/null || true)"
        _MIGRATE_V2_PYTHON_VERSION="$(read_config_value python.version 2>/dev/null || true)"
        _MIGRATE_V2_MICROMAMBA_ENV_NAME="$(read_config_value micromamba.env_name 2>/dev/null || true)"
    fi

    if [[ -f pyproject.toml ]] \
       && grep -qE '^\[tool\.pyve\.testenvs(\]|\.)' pyproject.toml; then
        # read_env_config (lib/envs.sh) populates PYVE_TESTENVS_* arrays
        # via the Python helper. Copy into our private state.
        read_env_config
        local i n
        n=${#PYVE_TESTENVS_NAMES[@]}
        for ((i=0; i<n; i++)); do
            _MIGRATE_V2_TESTENV_NAMES+=("${PYVE_TESTENVS_NAMES[$i]}")
            _MIGRATE_V2_TESTENV_BACKEND+=("${PYVE_TESTENV_BACKEND[$i]}")
            _MIGRATE_V2_TESTENV_LAZY+=("${PYVE_TESTENV_LAZY[$i]}")
            _MIGRATE_V2_TESTENV_EXTRA+=("${PYVE_TESTENV_EXTRA[$i]}")
            _MIGRATE_V2_TESTENV_MANIFEST+=("${PYVE_TESTENV_MANIFEST[$i]}")
            _MIGRATE_V2_TESTENV_REQUIREMENTS_Q+=("${PYVE_TESTENV_REQUIREMENTS_Q[$i]}")
        done
    fi
}

# Render the v3 `pyve.toml` to stdout based on the private state
# populated by `_self_migrate_read_legacy`. Caller decides whether
# to capture, write, or compare.
#
# Layout produced:
#   pyve_schema = "3.0"
#   [project]   name = "<project_name>"
#   [env.root]  purpose = "utility", backend = <v2 backend>
#   [env.<n>]   purpose = "test", per-env attrs from legacy
#
# Defaulting rules:
#   - The env named "testenv" (or, if no testenvs declared, an
#     implicit `[env.testenv]`) gets `default = true`.
#   - Omitted scalar fields (extra, manifest, lazy, requirements)
#     are not emitted at all (TOML's "absent = default" semantics).
_self_migrate_render_pyve_toml() {
    local project_name="${1:-$(basename "$(pwd)")}"

    printf 'pyve_schema = "3.0"\n\n'
    printf '[project]\n'
    printf 'name = "%s"\n' "$project_name"
    printf '\n'

    printf '[env.root]\n'
    printf 'purpose = "utility"\n'
    if [[ -n "$_MIGRATE_V2_BACKEND" ]]; then
        printf 'backend = "%s"\n' "$_MIGRATE_V2_BACKEND"
    fi
    printf '\n'

    local n=${#_MIGRATE_V2_TESTENV_NAMES[@]}

    # If no testenvs are declared in the v2 pyproject, emit the
    # implicit default `[env.testenv]` to match N.e's fresh-init
    # behavior — the project gets one default test env.
    if [[ "$n" -eq 0 ]]; then
        printf '[env.testenv]\n'
        printf 'purpose = "test"\n'
        printf 'default = true\n'
        return 0
    fi

    # Determine which env should carry `default = true`: prefer the
    # explicit `testenv` name; otherwise the first declared.
    local default_idx=-1
    local i
    for ((i=0; i<n; i++)); do
        if [[ "${_MIGRATE_V2_TESTENV_NAMES[$i]}" == "testenv" ]]; then
            default_idx=$i
            break
        fi
    done
    if [[ "$default_idx" -lt 0 ]]; then
        default_idx=0
    fi

    for ((i=0; i<n; i++)); do
        local name="${_MIGRATE_V2_TESTENV_NAMES[$i]}"
        printf '[env.%s]\n' "$name"
        printf 'purpose = "test"\n'

        local backend="${_MIGRATE_V2_TESTENV_BACKEND[$i]}"
        # Omit `backend = "venv"` — it's the implicit default per
        # lib/envs.sh's empty-array fallback. Emit any other value.
        if [[ -n "$backend" ]] && [[ "$backend" != "venv" ]]; then
            printf 'backend = "%s"\n' "$backend"
        fi

        if [[ "${_MIGRATE_V2_TESTENV_LAZY[$i]}" == "1" ]]; then
            printf 'lazy = true\n'
        fi

        if [[ -n "${_MIGRATE_V2_TESTENV_EXTRA[$i]}" ]]; then
            printf 'extra = "%s"\n' "${_MIGRATE_V2_TESTENV_EXTRA[$i]}"
        fi
        if [[ -n "${_MIGRATE_V2_TESTENV_MANIFEST[$i]}" ]]; then
            printf 'manifest = "%s"\n' "${_MIGRATE_V2_TESTENV_MANIFEST[$i]}"
        fi
        # Requirements come in already shell-quoted from the Python
        # helper. Split on whitespace honoring the quotes, then
        # re-emit as a TOML array of strings.
        if [[ -n "${_MIGRATE_V2_TESTENV_REQUIREMENTS_Q[$i]}" ]]; then
            printf 'requirements = ['
            local first=1 req
            local -a _reqs=()
            eval "_reqs=( ${_MIGRATE_V2_TESTENV_REQUIREMENTS_Q[$i]} )"
            for req in "${_reqs[@]+"${_reqs[@]}"}"; do
                if [[ "$first" -eq 1 ]]; then
                    first=0
                else
                    printf ', '
                fi
                printf '"%s"' "$req"
            done
            printf ']\n'
        fi

        if [[ "$i" -eq "$default_idx" ]]; then
            printf 'default = true\n'
        fi
        printf '\n'
    done
}

# Extract every `[tool.pyve.testenvs(.<name>)]` block from
# pyproject.toml into the backup file, then rewrite pyproject.toml
# without those lines. Idempotent — if there's nothing to extract,
# the function is a clean no-op.
#
# Block boundaries: a top-level header line `^\[...\]` starts a new
# block; the previous block ends. The implementation runs in one
# awk pass over pyproject.toml.
_self_migrate_extract_pyproject_testenvs() {
    local backup="$1"
    if ! grep -qE '^\[tool\.pyve\.testenvs(\]|\.)' pyproject.toml; then
        return 0
    fi
    local tmp_remainder
    tmp_remainder="$(mktemp)"
    awk -v backup="$backup" -v remainder="$tmp_remainder" '
        BEGIN { in_block = 0 }
        /^\[/ {
            if ($0 ~ /^\[tool\.pyve\.testenvs(\]|\.)/) {
                in_block = 1
            } else {
                in_block = 0
            }
        }
        {
            if (in_block) {
                print >> backup
            } else {
                print >> remainder
            }
        }
    ' pyproject.toml
    mv "$tmp_remainder" pyproject.toml
}

# Move/copy legacy sources into `.pyve/.v2-legacy/`. Layout:
#   .pyve/.v2-legacy/pyve-config              (was .pyve/config)
#   .pyve/.v2-legacy/testenvs/<name>/...      (was .pyve/testenvs/<name>/...)
#   .pyve/.v2-legacy/pyproject-testenvs.toml  (extracted from pyproject.toml)
#
# Arg: $1 = "true" → dry-run (print plan, no writes)
#          "false" → execute
_self_migrate_backup() {
    local dry_run="$1"

    if [[ "$dry_run" == "true" ]]; then
        [[ -f .pyve/config ]] && \
            info "  Would move .pyve/config → .pyve/.v2-legacy/pyve-config"
        [[ -d .pyve/testenvs ]] && \
            info "  Would move .pyve/testenvs → .pyve/.v2-legacy/testenvs"
        if [[ -f pyproject.toml ]] \
           && grep -qE '^\[tool\.pyve\.testenvs(\]|\.)' pyproject.toml; then
            info "  Would extract [tool.pyve.testenvs.*] from pyproject.toml → .pyve/.v2-legacy/pyproject-testenvs.toml"
        fi
        return 0
    fi

    mkdir -p .pyve/.v2-legacy

    if [[ -f .pyve/config ]]; then
        mv .pyve/config .pyve/.v2-legacy/pyve-config
    fi
    if [[ -d .pyve/testenvs ]]; then
        mv .pyve/testenvs .pyve/.v2-legacy/testenvs
    fi
    if [[ -f pyproject.toml ]]; then
        _self_migrate_extract_pyproject_testenvs ".pyve/.v2-legacy/pyproject-testenvs.toml"
    fi
}

# Orchestrator. See banner at top of section for flag semantics.
self_migrate() {
    local dry_run=false
    local no_rebuild=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --no-rebuild)
                no_rebuild=true
                shift
                ;;
            --help|-h)
                show_self_migrate_help
                return 0
                ;;
            *)
                log_error "Unknown 'pyve self migrate' flag: $1"
                log_error "See: pyve self migrate --help"
                exit 1
                ;;
        esac
    done

    # Detection. Two cases yield a no-op:
    #   - pyve.toml present (already migrated, or v3 from the start)
    #   - no legacy sources at all (greenfield)
    if ! _self_migrate_detect_v2_sources; then
        if [[ -f pyve.toml ]]; then
            info "pyve.toml is already in place — nothing to migrate."
        else
            info "No v2 configuration detected — nothing to migrate."
        fi
        return 0
    fi

    header_box "pyve self migrate"
    info "Detected v2 configuration. Planning migration to v3."

    _self_migrate_read_legacy

    local project_name
    project_name="$(basename "$(pwd)")"

    if [[ "$dry_run" == "true" ]]; then
        info ""
        info "Migration plan (--dry-run; no writes):"
        info "  Would write pyve.toml ($project_name, backend=${_MIGRATE_V2_BACKEND:-?})"
        _self_migrate_backup true
        if [[ "$no_rebuild" != "true" ]]; then
            info "  Would invoke 'pyve init --force' to rebuild envs at the v3 layout"
        fi
        footer_box
        return 0
    fi

    # Step 1: write pyve.toml.
    _self_migrate_render_pyve_toml "$project_name" > pyve.toml
    success "Wrote pyve.toml"

    # Step 2: back up legacy sources.
    _self_migrate_backup false
    success "Backed up legacy sources to .pyve/.v2-legacy/"

    # Step 3: rebuild via `pyve init --force` unless suppressed.
    if [[ "$no_rebuild" == "true" ]]; then
        info "Skipped rebuild (--no-rebuild). Run 'pyve init --force' when ready."
    else
        info "Rebuilding environments at the v3 state layout..."
        PYVE_REINIT_MODE="force" PYVE_FORCE_YES=1 init_project || {
            log_error "pyve init --force failed during migration."
            log_error "Your legacy sources are preserved at .pyve/.v2-legacy/."
            log_error "Resolve the init error, then re-run 'pyve self migrate'."
            return 1
        }
    fi

    # Step 4: summary.
    _self_migrate_summary "$no_rebuild"
    footer_box
}

_self_migrate_summary() {
    local no_rebuild="$1"
    info ""
    info "Migration complete."
    info "  Manifest:      pyve.toml"
    info "  Legacy backup: .pyve/.v2-legacy/"
    if [[ "$no_rebuild" == "true" ]]; then
        info "  Rebuild:       skipped (--no-rebuild)"
        info "  Next step:     'pyve init --force' to rebuild envs at the v3 layout"
    else
        info "  Verify with:   'pyve check'"
    fi
}

#------------------------------------------------------------
# Leaf: pyve self provision (Story N.bh)
#
# Provisions Pyve's toolchain venv + hosted tools (toolchain Python,
# PyYAML/tomlkit, project-guide + shim) WITHOUT the file-copy / PATH /
# prompt-hook parts of `self install`. Brew-safe: it never writes a second
# pyve binary into ~/.local/bin or rewrites PATH, so a Homebrew formula's
# post_install can call it to provision hosting that `self install` itself
# refuses to do for Homebrew-managed installs. Best-effort (each step warns
# but never aborts), so it always returns 0 — safe for a non-fatal hook.
#------------------------------------------------------------

self_provision() {
    printf "\nProvisioning Pyve toolchain + hosted tools...\n"
    _self_install_toolchain_python
    _self_install_toolchain_deps
    _self_install_project_guide
    printf "\n✓ Provisioning complete.\n"
    return 0
}

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
        migrate)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_migrate_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-migrate %s\n' "$*"
                return 0
            fi
            self_migrate "$@"
            ;;
        provision)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_provision_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-provision %s\n' "$*"
                return 0
            fi
            self_provision
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
show_self_install_help() {
    cat << 'EOF'
pyve self install - Install pyve to ~/.local/bin

Usage:
  pyve self install

Description:
  Copies the pyve script and lib/ modules to ~/.local/bin and adds
  ~/.local/bin to PATH (via ~/.zshrc or ~/.bashrc) if not already
  present. Idempotent — safe to run multiple times.

See also:
  pyve self uninstall    Remove pyve from ~/.local/bin
  pyve --help            Full command list
EOF
}
show_self_uninstall_help() {
    cat << 'EOF'
pyve self uninstall - Remove pyve from ~/.local/bin

Usage:
  pyve self uninstall

Description:
  Removes the pyve script and lib/ modules from ~/.local/bin, plus:
    - the PATH entry added by the installer (from ~/.zprofile / ~/.bash_profile)
    - the pyve prompt hook (from ~/.zshrc / ~/.bashrc)
    - the project-guide shell completion block (from ~/.zshrc / ~/.bashrc),
      if one was added by `pyve init --project-guide-completion`

  Non-empty ~/.local/.env is preserved (warn, don't delete).

See also:
  pyve self install      Install pyve to ~/.local/bin
  pyve --help            Full command list
EOF
}
show_self_migrate_help() {
    cat << 'EOF'
pyve self migrate - Migrate a v2.7/v2.8 project to v3

Usage:
  pyve self migrate [--dry-run] [--no-rebuild]

Description:
  Deterministic, idempotent path from v2 to v3:
    1. Detects v2 configuration (.pyve/config, [tool.pyve.testenvs.*]
       in pyproject.toml, .pyve/testenvs/ on disk).
    2. Writes a new root-level pyve.toml derived from those sources.
       The main env becomes [env.root] with purpose = "utility"; each
       testenv becomes [env.<name>] with purpose = "test".
    3. Moves legacy sources to .pyve/.v2-legacy/ (preserved for one
       release cycle so you can roll back manually if needed).
    4. Invokes 'pyve init --force' to rebuild envs at the v3 state
       layout (.pyve/envs/<name>/<backend>/).
    5. Prints a summary.

  Re-running on a fully-migrated project (pyve.toml present, no v2
  sources) is a clean no-op.

Options:
  --dry-run        Print the migration plan; perform no writes.
  --no-rebuild     Write pyve.toml + back up legacy sources, but
                   skip the 'pyve init --force' rebuild step. Useful
                   when you want to inspect the manifest or stage the
                   rebuild for a specific moment.

Examples:
  pyve self migrate              # Full migration + rebuild
  pyve self migrate --dry-run    # Inspect the plan without touching disk
  pyve self migrate --no-rebuild # Manifest + backup only; you run init later

See also:
  pyve init --force              Rebuild envs after a --no-rebuild migration
  pyve check                     Verify the v3 layout after migration
EOF
}
show_self_provision_help() {
    cat << 'EOF'
pyve self provision - Provision Pyve's toolchain venv + hosted tools

Usage:
  pyve self provision

Description:
  Provisions Pyve's hidden toolchain Python venv and the tools hosted in
  it (PyYAML/tomlkit for `pyve env sync`, and project-guide), then links
  the project-guide shim onto ~/.local/bin.

  Unlike `pyve self install`, this does NOT copy the pyve binary into
  ~/.local/bin or modify your PATH — so it is safe to run on a
  Homebrew-managed pyve. A Homebrew formula's post_install step calls it
  to set up hosting that `pyve self install` itself refuses to do for
  Homebrew installs. Provisioning also happens lazily on first use, so you
  rarely need to run this by hand.

  Best-effort: each step warns but never aborts; the command always exits 0.

See also:
  pyve self install      Full source install (copies pyve + wires PATH, then provisions)
EOF
}
show_self_help() {
    cat << 'EOF'
pyve self - Manage pyve's own installation

Usage: pyve self <subcommand>

Subcommands:
  pyve self install      Install pyve to ~/.local/bin (and add to PATH if needed)
  pyve self uninstall    Remove pyve from ~/.local/bin
  pyve self migrate      Migrate a v2.7/v2.8 project to v3 (pyve.toml + state-layout cutover)
  pyve self provision    Provision the toolchain venv + hosted tools (brew-safe; no PATH changes)

See `pyve --help` for the full command list.
EOF
}
