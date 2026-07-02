#!/usr/bin/env bash
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# lib/env_detect.sh - Environment detection functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

#============================================================
# Shell Profile Sourcing
#============================================================

# Source shell profiles to ensure version managers are available
# This is needed because the script runs in a non-interactive shell
source_shell_profiles() {
    # Instead of sourcing full profiles (which may have interactive elements),
    # directly initialize the version managers we care about
    
    # Initialize asdf if installed
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh" 2>/dev/null || true
    elif [[ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]]; then
        source "/opt/homebrew/opt/asdf/libexec/asdf.sh" 2>/dev/null || true
    elif [[ -f "/usr/local/opt/asdf/libexec/asdf.sh" ]]; then
        source "/usr/local/opt/asdf/libexec/asdf.sh" 2>/dev/null || true
    fi
    
    # Initialize pyenv if installed
    if [[ -d "$HOME/.pyenv" ]]; then
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        if command -v pyenv >/dev/null 2>&1; then
            eval "$(pyenv init -)" 2>/dev/null || true
        fi
    fi
}

#============================================================
# Version Manager Detection
#============================================================

# Global variable to store detected version manager
VERSION_MANAGER=""

# Detect which Python version manager is available
# Sets VERSION_MANAGER to "asdf", "pyenv", or ""
# Returns 0 if found, 1 if not found
detect_version_manager() {
    VERSION_MANAGER=""
    
    # Check for asdf first (preferred)
    if command -v asdf >/dev/null 2>&1; then
        # Verify asdf has Python plugin. Capture-then-grep (not a pipe into
        # `grep -q`): `grep -q` exits on first match, which closes the pipe
        # while `asdf plugin list` may still be writing — the producer then
        # takes SIGPIPE (141), and under `set -o pipefail` that propagates as
        # the pipeline status, false-negating an installed plugin.
        local asdf_plugins=""
        asdf_plugins="$(asdf plugin list 2>/dev/null)" || true
        if grep -qx "python" <<<"$asdf_plugins"; then
            VERSION_MANAGER="asdf"
            return 0
        else
            log_warning "asdf found but Python plugin not installed."
            log_warning "Install with: asdf plugin add python"
        fi
    fi
    
    # Check for pyenv as fallback
    if command -v pyenv >/dev/null 2>&1; then
        VERSION_MANAGER="pyenv"
        return 0
    fi
    
    # Neither found
    log_error "No Python version manager found."
    log_error "Please install asdf (recommended) or pyenv:"
    log_error "  asdf: https://asdf-vm.com/"
    log_error "  pyenv: https://github.com/pyenv/pyenv"
    return 1
}

#============================================================
# Python Version Management
#============================================================

# Check if a Python version is installed
# Usage: is_python_version_installed "3.13.7"
# Returns 0 if installed, 1 if not
is_python_version_installed() {
    local version="$1"
    local installed

    # Capture the manager's version list first, then match with a here-string.
    # Piping straight into `grep -q` lets grep close the pipe on its first
    # match while the manager is still writing later versions — the producer
    # then takes SIGPIPE (141), and under `set -o pipefail` that propagates as
    # a false "not installed" (e.g. 3.12.10 matched, 3.14.5 written after it).
    # Same trap captured-then-greped in detect_version_manager above.
    case "$VERSION_MANAGER" in
        asdf)
            installed="$(asdf list python 2>/dev/null || true)"
            grep -q "$version" <<<"$installed"
            ;;
        pyenv)
            installed="$(pyenv versions --bare 2>/dev/null || true)"
            grep -q "^${version}$" <<<"$installed"
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if a Python version is available to install
# Usage: is_python_version_available "3.13.7"
# Returns 0 if available, 1 if not
is_python_version_available() {
    local version="$1"
    local available_versions
    
    case "$VERSION_MANAGER" in
        asdf)
            available_versions="$(asdf list all python 2>/dev/null)" || return 1
            printf '%s\n' "$available_versions" | grep -q "^${version}$"
            ;;
        pyenv)
            available_versions="$(pyenv install --list 2>/dev/null)" || return 1
            printf '%s\n' "$available_versions" | grep -q "^[[:space:]]*${version}$"
            ;;
        *)
            return 1
            ;;
    esac
}

# Install a Python version
# Usage: install_python_version "3.13.7"
# Returns 0 on success, 1 on failure
install_python_version() {
    local version="$1"
    
    log_info "Installing Python $version (this may take a few minutes)..."
    
    case "$VERSION_MANAGER" in
        asdf)
            if asdf install python "$version"; then
                log_success "Python $version installed successfully."
                return 0
            else
                log_error "Failed to install Python $version with asdf."
                return 1
            fi
            ;;
        pyenv)
            if pyenv install -s "$version"; then
                log_success "Python $version installed successfully."
                return 0
            else
                log_error "Failed to install Python $version with pyenv."
                return 1
            fi
            ;;
        *)
            log_error "No version manager available to install Python."
            return 1
            ;;
    esac
}

# Ensure a Python version is installed, installing if necessary
# Usage: ensure_python_version_installed "3.13.7"
# Returns 0 on success, 1 on failure
ensure_python_version_installed() {
    local version="$1"

    # Check if already installed
    if is_python_version_installed "$version"; then
        return 0
    fi
    
    # Check if available to install
    if ! is_python_version_available "$version"; then
        log_error "Python $version is not available for installation."
        log_error "Check available versions with:"
        case "$VERSION_MANAGER" in
            asdf)
                log_error "  asdf list all python | grep $version"
                ;;
            pyenv)
                log_error "  pyenv install --list | grep $version"
                ;;
        esac
        return 1
    fi
    
    # Prompt user before installing (auto-accept in CI)
    log_info "Python $version is not installed but is available via $VERSION_MANAGER."
    if [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
        if ! prompt_yes_no "Install Python $version now?"; then
            log_info "Installation cancelled."
            return 1
        fi
    else
        log_info "Auto-installing in CI environment..."
    fi
    
    # Install it
    install_python_version "$version"
}

# Set the local Python version for the current directory
# Usage: set_local_python_version "3.13.7"
# Returns 0 on success, 1 on failure
set_local_python_version() {
    local version="$1"
    
    case "$VERSION_MANAGER" in
        asdf)
            # asdf 0.18+ removed 'local' command, use 'set' instead
            # Try 'set' first, fall back to 'local' for older versions
            if asdf set python "$version" 2>/dev/null; then
                : # Success with 'set'
            elif asdf local python "$version" 2>/dev/null; then
                : # Success with 'local' (older asdf)
            else
                log_error "Failed to set Python version with asdf"
                return 1
            fi
            asdf reshim python 2>/dev/null || true
            ;;
        pyenv)
            pyenv local "$version"
            pyenv rehash 2>/dev/null || true
            ;;
        *)
            log_error "No version manager available."
            return 1
            ;;
    esac
    
    return 0
}

# Get the version file name for the current version manager
# Returns ".tool-versions" for asdf, ".python-version" for pyenv
get_version_file_name() {
    case "$VERSION_MANAGER" in
        asdf)
            printf ".tool-versions"
            ;;
        pyenv)
            printf ".python-version"
            ;;
        *)
            printf ""
            ;;
    esac
}

# The pinned project Python version and where it came from, as "<version>|<source>".
# Order: `.tool-versions` (asdf) → `.python-version` (pyenv) → the transitional
# `.pyve/config` python.version (read-compat tail, dropped when Subphase P-1 stops
# writing `.pyve/config`). <source> is one of tool-versions / python-version /
# config, or empty when nothing pins a version (then <version> is empty too).
# Callers map <source> to their own display label.
resolve_python_version() {
    local version="" source=""
    if [[ -f ".tool-versions" ]]; then
        version="$(grep "^python " .tool-versions 2>/dev/null | awk '{print $2}')"
        source="tool-versions"
    elif [[ -f ".python-version" ]]; then
        version="$(head -1 .python-version 2>/dev/null)"
        source="python-version"
    elif config_file_exists; then
        version="$(read_config_value "python.version" 2>/dev/null || true)"
        source="config"
    fi
    [[ -z "$version" ]] && source=""
    printf '%s|%s' "$version" "$source"
}

#============================================================
# asdf/direnv Coexistence (Phase J)
#============================================================

# Returns 0 when pyve should apply asdf-reshim-avoidance measures.
# True when `detect_version_manager` resolved to "asdf" AND the user has
# not opted out via PYVE_NO_ASDF_COMPAT. Downstream callers:
#   - Story J.b: .envrc generator injects ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
#   - Story J.c: `pyve run` dispatcher exports the same var to subprocesses
#
# The opt-out exists because some users run pyve under asdf but install
# CLIs globally via `pip install --user`, and those CLIs legitimately
# need asdf's reshim. PYVE_NO_ASDF_COMPAT=1 keeps the default asdf
# behavior intact for that case.
is_asdf_active() {
    if [[ "$VERSION_MANAGER" != "asdf" ]]; then
        return 1
    fi
    if [[ -n "${PYVE_NO_ASDF_COMPAT:-}" ]]; then
        return 1
    fi
    return 0
}

#============================================================
# Direnv Detection
#============================================================

# Check if direnv is installed
# Returns 0 if installed, 1 if not
check_direnv_installed() {
    if command -v direnv >/dev/null 2>&1; then
        return 0
    fi
    
    log_error "direnv is not installed."
    log_error "Please install direnv:"
    if [[ "$(uname)" == "Darwin" ]]; then
        log_error "  brew install direnv"
    else
        log_error "  https://direnv.net/docs/installation.html"
    fi
    return 1
}

#============================================================
# Python pre-flight check
#============================================================

# Detect the recurring "asdf/pyenv shim with no resolvable version"
# trap before pyve invokes `python` (e.g. `python -m venv` for testenv
# creation). At shell-init / non-direnv-active shells, `python`
# resolves to the version-manager's shim; with no `.tool-versions` /
# `.python-version` and no global pin, the shim errors noisily.
# Without this guard the user sees asdf's "No version is set for
# command python" and reads it as a pyve bug — they don't realize the
# real cause is "the project env isn't active in this shell."
#
# Returns:
#   0 — `python` is resolvable; safe to invoke.
#   1 — trap detected (or generic unresolvable python); pyve-owned
#       error printed to stderr, naming the actual fix.
#
# This guard does NOT depend on detect_version_manager being run
# first; it probes `python` directly. Callers can invoke it pre-flight
# without ordering concerns.
assert_python_resolvable() {
    # BOUNDARY: this guards the *project* python — the
    # developer's interpreter for `pyve run python`, version-manager
    # activation, the project venv. It is deliberately NOT routed through
    # pyve_toolchain_python (that resolves Pyve's *own* toolchain
    # interpreter, a different concern). Keep this on `${PYVE_PYTHON:-python}`.
    #
    # Respect PYVE_PYTHON for callers that have already resolved a
    # specific interpreter (the tests' setup pre-resolves this before
    # cd'ing to a tmp dir). Fall back to bare `python` otherwise —
    # which is exactly where the asdf-shim trap bites.
    local py="${PYVE_PYTHON:-python}"

    # Fast path: python runs cleanly → resolved regardless of how.
    # `--version` is the cheapest universally-supported probe.
    if "$py" --version >/dev/null 2>&1; then
        return 0
    fi

    # python failed. Inspect what it resolved to and emit the most
    # actionable error possible.
    local python_path
    python_path="$(command -v "$py" 2>/dev/null || true)"

    # Cause line — shim-specific where we can name the shim, generic
    # otherwise (python missing entirely, or some other unresolvable case).
    if [[ "$python_path" == *"/.asdf/shims/python"* ]] \
       || [[ "$python_path" == *"/.pyenv/shims/python"* ]]; then
        log_error "Cannot resolve 'python' — version-manager shim has no version pinned for this directory."
        log_error "  Shim path: $python_path"
    else
        log_error "Cannot resolve 'python' on PATH."
    fi
    log_error ""

    # Fix advice — gated on whether this is an activatable / initialized
    # Pyve project. The shim trap only fires when there is NO version pin in
    # this directory, which a properly-initialized project always has; so by
    # the time we reach here, `direnv allow` / `pyve run` only make sense if
    # there is actually an `.envrc` to allow and an env to activate. With no
    # `.envrc` the project is purged or uninitialized — the real fix is to
    # (re)initialize, not to "activate" an env that doesn't exist.
    if [[ -f .envrc ]]; then
        log_error "Most likely cause: the project environment isn't active in this shell."
        log_error "Fix one of these:"
        log_error "  • Run 'direnv allow' in the project root (one-time per shell session)"
        log_error "  • Re-run wrapped: 'pyve run <cmd>' (one-shot, works without direnv)"
    elif [[ -f pyve.toml ]]; then
        log_error "This Pyve project has no active environment (its '.envrc' is gone)."
        log_error "Run 'pyve init' to (re)create the environment."
    else
        log_error "This directory isn't an initialized Pyve project."
        log_error "Run 'pyve init' to set one up."
    fi
    return 1
}
