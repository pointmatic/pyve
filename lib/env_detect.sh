#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
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
        # Verify asdf has Python plugin
        if asdf plugin list 2>/dev/null | grep -q "^python$"; then
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
    
    case "$VERSION_MANAGER" in
        asdf)
            asdf list python 2>/dev/null | grep -q "$version"
            ;;
        pyenv)
            pyenv versions --bare 2>/dev/null | grep -q "^${version}$"
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
    
    case "$VERSION_MANAGER" in
        asdf)
            asdf list all python 2>/dev/null | grep -q "^${version}$"
            ;;
        pyenv)
            pyenv install --list 2>/dev/null | grep -q "^[[:space:]]*${version}$"
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
    
    # Prompt user before installing
    log_info "Python $version is not installed but is available via $VERSION_MANAGER."
    if ! prompt_yes_no "Install Python $version now?"; then
        log_info "Installation cancelled."
        return 1
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
