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

    # Copy the entire lib/ tree recursively. pyve.sh sources from several
    # subtrees (lib/ui/, lib/plugins/{python,node}/, lib/commands/,
    # lib/completion/, …); a recursive copy ships whatever it sources
    # rather than a hand-maintained per-subdir allowlist that silently
    # drifts from the sourcing graph (the v3.0.6 break: lib/ui/ and
    # lib/plugins/ were never added, so the installed binary died at
    # `source .../lib/ui/core.sh`). Wipe-then-copy so a renamed/removed
    # module doesn't linger from a previous install; lib/ is pure code
    # (install output), never state, so removing it is safe. Exclude
    # __pycache__ — compiled bytecode is regenerated on demand and copying
    # it ships a stale .pyc.
    if [[ -d "$source_dir/lib" ]]; then
        rm -rf "${TARGET_BIN_DIR:?}/lib"
        mkdir -p "$TARGET_BIN_DIR/lib"
        cp -R "$source_dir/lib/." "$TARGET_BIN_DIR/lib/"
        find "$TARGET_BIN_DIR/lib" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
        log_success "Installed lib/ (all modules)"
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
# Requires project-guide >= 2.15.0 (ships the readiness-gated local-install
# warning that consumes `pyve self provision --status`).
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
    if run_quiet "$pip_cmd" install --upgrade 'project-guide>=2.15.0'; then
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
        rm -rf "${TARGET_BIN_DIR:?}/lib"
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
# `pyve self migrate` — reserved migration verb
# ============================================================
#
# The v2 (.pyve/config / [tool.pyve.testenvs.*]) migration bridge was
# removed once v2 support ended, so there is no migration for the
# current pyve schema. The verb is kept as a stable home for a future
# schema migration (e.g. v3 -> v4); when one exists this function is
# re-fleshed to perform it. Until then it is an inert, non-destructive
# no-op: it recognizes no legacy sources and writes nothing.
self_migrate() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_self_migrate_help
        return 0
    fi
    info "No migration applies for the current pyve schema — nothing to do."
    return 0
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

#------------------------------------------------------------
# Leaf: pyve self provision --status [--json]
#
# Read-only, side-effect-free hosting-readiness query for other tools
# (project-guide first) to consult WITHOUT a project context and WITHOUT
# reaching into Pyve's version-keyed, XDG-relative internal paths. It is a
# pure reader: it NEVER provisions (kept separate from self_provision, which
# always calls the _self_install_* helpers). Classification probes
# RUNNABILITY — it executes `python --version` / `project-guide --version`
# rather than stat-ing the artifacts, so a dangling symlink or dead-shebang
# install is reported broken, not "ready".
#
# Exit-code contract (the surface consumers key off):
#   0 — hosting ready (toolchain venv runnable AND hosted project-guide runnable)
#   1 — Pyve-managed but not ready (never provisioned, or provisioned-but-broken)
#   2 — not Pyve-managed here (the project owns project-guide via a deps source)
#------------------------------------------------------------

self_provision_status() {
    local json=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json=true; shift ;;
            --help|-h) show_self_provision_help; return 0 ;;
            *) unknown_flag_error "self provision --status" "$1" --json ;;
        esac
    done

    # A project that declares project-guide as its own dependency owns the
    # tool deliberately — "not my department". Report not-managed (exit 2)
    # before probing Pyve hosting at all.
    local src
    src="$(project_guide_deps_source 2>/dev/null || true)"
    if [[ -n "$src" ]]; then
        if [[ "$json" == true ]]; then
            printf '{"pyve_managed":false,"toolchain":{"provisioned":false,"runnable":false,"version":null},"project_guide":{"hosted":false,"runnable":false,"version":null,"shim":null}}\n'
        else
            printf 'Pyve hosting: managed by your project (%s) — not Pyve-managed here\n' "$src"
        fi
        return 2
    fi

    # Toolchain Python: existence (provisioned) vs runnability (executes).
    local tc_provisioned=false tc_runnable=false tc_version="" venv_py
    if [[ -n "${PYVE_PYTHON:-}" ]]; then
        venv_py="$PYVE_PYTHON"
    else
        venv_py="$(pyve_toolchain_venv_dir)/bin/python"
    fi
    [[ -x "$venv_py" ]] && tc_provisioned=true
    if tc_version="$(pyve_toolchain_runnable 2>/dev/null)"; then
        tc_runnable=true
    else
        tc_version=""
    fi

    # project-guide: hosted (existence) vs runnability (executes).
    local pg_hosted=false pg_runnable=false pg_version="" pg_shim=""
    if pyve_project_guide_is_hosted 2>/dev/null; then
        pg_hosted=true
        pg_shim="$(pyve_project_guide)"
    fi
    if pg_version="$(pyve_project_guide_runnable 2>/dev/null)"; then
        pg_runnable=true
    else
        pg_version=""
    fi

    local rc=1
    if [[ "$tc_runnable" == true && "$pg_hosted" == true && "$pg_runnable" == true ]]; then
        rc=0
    fi

    if [[ "$json" == true ]]; then
        _self_provision_status_json \
            "$tc_provisioned" "$tc_runnable" "$tc_version" \
            "$pg_hosted" "$pg_runnable" "$pg_version" "$pg_shim"
    else
        _self_provision_status_human \
            "$rc" "$tc_provisioned" "$tc_runnable" "$tc_version" \
            "$pg_hosted" "$pg_runnable" "$pg_version" "$pg_shim"
    fi
    return "$rc"
}

# Emit a JSON bool/null field value: `true`/`false` pass through; a non-empty
# string becomes a quoted JSON string; empty becomes `null`.
_json_str_or_null() {
    if [[ -z "$1" ]]; then printf 'null'; else printf '"%s"' "$1"; fi
}

_self_provision_status_json() {
    local tc_prov="$1" tc_run="$2" tc_ver="$3" pg_host="$4" pg_run="$5" pg_ver="$6" pg_shim="$7"
    printf '{"pyve_managed":true,"toolchain":{"provisioned":%s,"runnable":%s,"version":%s},"project_guide":{"hosted":%s,"runnable":%s,"version":%s,"shim":%s}}\n' \
        "$tc_prov" "$tc_run" "$(_json_str_or_null "$tc_ver")" \
        "$pg_host" "$pg_run" "$(_json_str_or_null "$pg_ver")" "$(_json_str_or_null "$pg_shim")"
}

_self_provision_status_human() {
    local rc="$1" tc_prov="$2" tc_run="$3" tc_ver="$4" pg_host="$5" pg_run="$6" pg_ver="$7" pg_shim="$8"
    if [[ "$rc" == "0" ]]; then
        printf 'Pyve hosting: ready\n'
    else
        printf 'Pyve hosting: not ready\n'
    fi

    if [[ "$tc_run" == true ]]; then
        printf '  Toolchain Python: runnable (%s)\n' "${tc_ver:-${DEFAULT_PYTHON_VERSION:-unknown}}"
    elif [[ "$tc_prov" == true ]]; then
        printf '  Toolchain Python: provisioned but not runnable\n'
    else
        printf '  Toolchain Python: not provisioned\n'
    fi

    if [[ "$pg_run" == true ]]; then
        printf '  project-guide:    runnable (%s) → %s\n' "${pg_ver:-unknown}" "$pg_shim"
    elif [[ "$pg_host" == true ]]; then
        printf '  project-guide:    hosted but not runnable → %s\n' "$pg_shim"
    else
        printf '  project-guide:    not hosted\n'
    fi

    if [[ "$rc" != "0" ]]; then
        printf "  Run 'pyve self provision' to provision Pyve hosting.\n"
    fi
}

#------------------------------------------------------------
# Leaf: pyve self unprovision
#
# Brew-safe granular teardown — the mirror of `self provision`. Removes
# the project-guide shim + the hosted project-guide PACKAGE while keeping
# the toolchain Python (and its other deps) in place. `--all` additionally
# drops the entire toolchain Python tree (the teardown `self uninstall`
# does today, but which no-ops for Homebrew). Like `self provision` it makes
# NO PATH or binary changes, so a Homebrew-managed pyve can run it for full
# teardown of the hosted tools. Best-effort: always returns 0.
#------------------------------------------------------------

self_unprovision() {
    local all=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                all=true
                shift
                ;;
            --help|-h)
                show_self_unprovision_help
                return 0
                ;;
            *)
                log_error "Unknown 'pyve self unprovision' flag: $1"
                log_error "See: pyve self unprovision --help"
                exit 1
                ;;
        esac
    done

    printf "\nUnprovisioning Pyve hosted tools...\n"

    # Always remove the project-guide shim (only our own symlink).
    _self_uninstall_project_guide

    if [[ "$all" == "true" ]]; then
        # Drop the whole toolchain tree: Python + every hosted package.
        _self_uninstall_toolchain_python
    else
        # Keep the toolchain Python; remove only the hosted project-guide.
        _self_unprovision_project_guide_package
    fi

    printf "\n✓ Unprovisioning complete.\n"
    return 0
}

#------------------------------------------------------------
# Private helper: pip-uninstall the hosted project-guide package from the
# toolchain venv, leaving the toolchain Python (and its other deps) intact.
# Best-effort: a missing venv/pip is a clean no-op; a failed uninstall warns
# but never aborts. Used by `self unprovision` (without --all) for granular
# teardown that doesn't drop the whole toolchain tree.
#------------------------------------------------------------

_self_unprovision_project_guide_package() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0
    local venv_dir pip_cmd
    venv_dir="$(pyve_toolchain_venv_dir)"
    pip_cmd="$venv_dir/bin/pip"
    if [[ ! -x "$pip_cmd" ]]; then
        return 0
    fi
    if run_quiet "$pip_cmd" uninstall -y project-guide; then
        log_success "Removed hosted project-guide from the Pyve toolchain"
    else
        log_warning "Could not remove hosted project-guide from the toolchain (skip)"
    fi
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
            # The ONLY form that provisions is bare `provision` (no args).
            # `--status` is the read-only query; `--help` prints help; any
            # other flag/argument is a HARD ERROR. This makes the old
            # silent-fall-through-to-provision (a typo or a future flag
            # re-provisioning the whole toolchain and returning 0) impossible
            # by construction — no input can reach self_provision by accident.
            case "${1:-}" in
                --status)
                    shift
                    self_provision_status "$@"
                    return $?
                    ;;
                --help|-h)
                    show_self_provision_help
                    return 0
                    ;;
                "")
                    if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                        printf 'DISPATCH:self-provision %s\n' "$*"
                        return 0
                    fi
                    self_provision
                    ;;
                *)
                    unknown_flag_error "self provision" "$1" --status --help
                    ;;
            esac
            ;;
        unprovision)
            shift
            if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
                show_self_unprovision_help
                return 0
            fi
            if [[ -n "${PYVE_DISPATCH_TRACE:-}" ]]; then
                printf 'DISPATCH:self-unprovision %s\n' "$*"
                return 0
            fi
            self_unprovision "$@"
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
pyve self migrate - Reserved migration verb (no migration for the current schema)

Usage:
  pyve self migrate

Description:
  A stable home for schema migrations. The legacy v2 -> v3 bridge was
  removed once v2 support ended, so there is no migration to perform for
  the current pyve schema: this command recognizes no legacy sources,
  writes nothing, and exits cleanly.

  The verb is retained so a future schema migration (e.g. v3 -> v4) has a
  predictable command to attach to. When such a migration exists, this
  command will perform it.

See also:
  pyve init --force              Rebuild envs at the current layout
  pyve check                     Verify the environment layout
EOF
}
show_self_provision_help() {
    cat << 'EOF'
pyve self provision - Provision Pyve's toolchain venv + hosted tools

Usage:
  pyve self provision
  pyve self provision --status [--json]

Description:
  Provisions Pyve's hidden toolchain Python venv and the tools hosted in
  it (PyYAML/tomlkit for `pyve env sync`, and project-guide), then links
  the project-guide shim onto ~/.local/bin.

  --status [--json]
    Read-only, side-effect-free hosting-readiness query — NEVER provisions.
    Probes runnability (executes `python --version` / `project-guide
    --version`, not a stat). Exit codes: 0 = hosting ready (toolchain +
    hosted project-guide both runnable); 1 = Pyve-managed but not ready
    (never provisioned, or provisioned-but-broken); 2 = not Pyve-managed
    here (your project owns project-guide via a dependency). --json prints
    the machine-readable detail. Any other flag is rejected (it never
    provisions by accident).

  Unlike `pyve self install`, this does NOT copy the pyve binary into
  ~/.local/bin or modify your PATH — so it is safe to run on a
  Homebrew-managed pyve. A Homebrew formula's post_install step calls it
  to set up hosting that `pyve self install` itself refuses to do for
  Homebrew installs. Provisioning also happens lazily on first use, so you
  rarely need to run this by hand.

  Best-effort: each step warns but never aborts; the command always exits 0.

  Upgrade path: re-running `pyve self provision` always pip-installs the
  hosted tools with --upgrade, so it doubles as the way to bump the hosted
  project-guide to its latest release. (`pyve update` refreshes a project's
  scaffolding; it does NOT bump the hosted project-guide version.)

See also:
  pyve self install      Full source install (copies pyve + wires PATH, then provisions)
  pyve self unprovision   Brew-safe teardown of the hosted tools (--all drops the toolchain)
EOF
}
show_self_unprovision_help() {
    cat << 'EOF'
pyve self unprovision - Remove the hosted project-guide (brew-safe teardown)

Usage:
  pyve self unprovision [--all]

Description:
  Granular, brew-safe teardown — the mirror of `pyve self provision`.
  Removes the project-guide shim (~/.local/bin/project-guide) and the
  hosted project-guide package from Pyve's toolchain venv, while leaving
  the toolchain Python (and its other deps) in place.

  Like `pyve self provision`, this makes NO PATH or binary changes (no
  second pyve in ~/.local/bin), so it is safe to run on a Homebrew-managed
  pyve — it gives Homebrew users a supported teardown for the hosted tools
  that `pyve self uninstall` no-ops on.

Options:
  --all   Also remove the entire toolchain Python tree
          (~/.local/share/pyve/toolchain/), not just project-guide.

Note:
  `brew uninstall pyve` does not remove these (they live outside the
  Homebrew prefix). Run `pyve self unprovision --all` for full teardown.

See also:
  pyve self provision    Provision the toolchain venv + hosted tools
  pyve self uninstall     Full source-install teardown (non-Homebrew)
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
  pyve self unprovision  Remove the hosted project-guide (--all also drops the toolchain; brew-safe)

See `pyve --help` for the full command list.
EOF
}
