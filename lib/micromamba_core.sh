#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
# lib/micromamba_core.sh - Micromamba binary detection and version functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

#============================================================
# Micromamba Detection Functions
#============================================================

# Get micromamba binary path
# Detection order:
#   1. .pyve/bin/micromamba (project sandbox)
#   2. ~/.pyve/bin/micromamba (user sandbox)
#   3. which micromamba (system PATH)
# Returns: path to micromamba binary or empty string if not found
get_micromamba_path() {
    # Priority 1: Project sandbox
    if [[ -x ".pyve/bin/micromamba" ]]; then
        echo "$(pwd)/.pyve/bin/micromamba"
        return 0
    fi
    
    # Priority 2: User sandbox
    if [[ -x "$HOME/.pyve/bin/micromamba" ]]; then
        echo "$HOME/.pyve/bin/micromamba"
        return 0
    fi
    
    # Priority 3: System PATH
    local system_path
    system_path="$(which micromamba 2>/dev/null)"
    if [[ -n "$system_path" ]] && [[ -x "$system_path" ]]; then
        echo "$system_path"
        return 0
    fi
    
    # Not found
    echo ""
    return 1
}

# Check if micromamba is available
# Returns: 0 if available, 1 if not
check_micromamba_available() {
    local micromamba_path
    micromamba_path="$(get_micromamba_path)"
    
    if [[ -n "$micromamba_path" ]]; then
        return 0
    else
        return 1
    fi
}

# Get micromamba version
# Returns: version string (e.g., "1.5.3") or empty string if not available
get_micromamba_version() {
    local micromamba_path
    micromamba_path="$(get_micromamba_path)"
    
    if [[ -z "$micromamba_path" ]]; then
        echo ""
        return 1
    fi
    
    # Execute micromamba --version and extract version number
    # Output format: "micromamba 1.5.3" or "1.5.3"
    local version_output
    version_output="$("$micromamba_path" --version 2>/dev/null)"
    
    if [[ -z "$version_output" ]]; then
        echo ""
        return 1
    fi
    
    # Extract version number (handles both "micromamba X.Y.Z" and "X.Y.Z" formats)
    local version
    version="$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
    
    echo "$version"
    return 0
}

# Get micromamba location type
# Returns: "project", "user", "system", or "not_found"
get_micromamba_location() {
    # Check project sandbox
    if [[ -x ".pyve/bin/micromamba" ]]; then
        echo "project"
        return 0
    fi
    
    # Check user sandbox
    if [[ -x "$HOME/.pyve/bin/micromamba" ]]; then
        echo "user"
        return 0
    fi
    
    # Check system PATH
    local system_path
    system_path="$(which micromamba 2>/dev/null)"
    if [[ -n "$system_path" ]] && [[ -x "$system_path" ]]; then
        echo "system"
        return 0
    fi
    
    echo "not_found"
    return 1
}

# Error if micromamba required but not found
# Arguments:
#   $1 - Context message (optional)
# Returns: 1 (always errors and exits)
error_micromamba_not_found() {
    local context="${1:-Backend 'micromamba' required but not found}"
    
    log_error "$context"
    log_error ""
    log_error "Micromamba is not installed or not in PATH."
    log_error ""
    log_error "Installation options:"
    log_error "  1. Install via package manager:"
    log_error "     macOS:  brew install micromamba"
    log_error "     Linux:  See https://mamba.readthedocs.io/en/latest/installation.html"
    log_error ""
    log_error "  2. Bootstrap installation (future feature in v0.7.3):"
    log_error "     pyve --init --backend micromamba --auto-bootstrap"
    log_error ""
    log_error "After installation, micromamba will be detected in:"
    log_error "  - Project sandbox: .pyve/bin/micromamba"
    log_error "  - User sandbox:    ~/.pyve/bin/micromamba"
    log_error "  - System PATH:     $(which micromamba)"
    
    return 1
}
