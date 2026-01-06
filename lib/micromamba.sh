#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
# lib/micromamba.sh - Micromamba detection and management functions for pyve
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

#============================================================
# Micromamba Bootstrap Functions
#============================================================

# Get the appropriate micromamba download URL for the current platform
# Returns: URL string or empty if platform not supported
get_micromamba_download_url() {
    local os="$(uname -s)"
    local arch="$(uname -m)"
    local version="latest"  # Use latest release
    
    # Determine platform string
    local platform=""
    case "$os" in
        Darwin)
            case "$arch" in
                arm64|aarch64)
                    platform="osx-arm64"
                    ;;
                x86_64)
                    platform="osx-64"
                    ;;
                *)
                    log_error "Unsupported macOS architecture: $arch"
                    return 1
                    ;;
            esac
            ;;
        Linux)
            case "$arch" in
                x86_64)
                    platform="linux-64"
                    ;;
                aarch64|arm64)
                    platform="linux-aarch64"
                    ;;
                ppc64le)
                    platform="linux-ppc64le"
                    ;;
                *)
                    log_error "Unsupported Linux architecture: $arch"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "Unsupported operating system: $os"
            return 1
            ;;
    esac
    
    # Construct download URL
    echo "https://micro.mamba.pm/api/micromamba/$platform/$version"
    return 0
}

# Download and install micromamba to specified location
# Arguments:
#   $1 - Installation location ("project" or "user")
# Returns: 0 on success, 1 on failure
bootstrap_install_micromamba() {
    local install_location="$1"
    
    if [[ "$install_location" != "project" ]] && [[ "$install_location" != "user" ]]; then
        log_error "Invalid installation location: $install_location"
        log_error "Must be 'project' or 'user'"
        return 1
    fi
    
    # Determine installation directory
    local install_dir
    if [[ "$install_location" == "project" ]]; then
        install_dir=".pyve/bin"
    else
        install_dir="$HOME/.pyve/bin"
    fi
    
    # Create directory if it doesn't exist
    if [[ ! -d "$install_dir" ]]; then
        log_info "Creating directory: $install_dir"
        mkdir -p "$install_dir" || {
            log_error "Failed to create directory: $install_dir"
            return 1
        }
    fi
    
    # Get download URL
    local download_url
    download_url="$(get_micromamba_download_url)" || return 1
    
    log_info "Downloading micromamba from: $download_url"
    
    # Download to temporary file
    local temp_file
    temp_file="$(mktemp)" || {
        log_error "Failed to create temporary file"
        return 1
    }
    
    # Download using curl (micromamba is distributed as a tarball)
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        log_error "Failed to download micromamba"
        rm -f "$temp_file"
        return 1
    fi
    
    # Verify download
    if [[ ! -s "$temp_file" ]]; then
        log_error "Downloaded file is empty"
        rm -f "$temp_file"
        return 1
    fi
    
    # Extract micromamba binary from tarball
    # The tarball contains bin/micromamba
    local temp_dir
    temp_dir="$(mktemp -d)" || {
        log_error "Failed to create temporary directory"
        rm -f "$temp_file"
        return 1
    }
    
    log_info "Extracting micromamba binary..."
    if ! tar -xzf "$temp_file" -C "$temp_dir" 2>/dev/null; then
        log_error "Failed to extract micromamba tarball"
        rm -f "$temp_file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Move extracted binary to installation location
    local install_path="$install_dir/micromamba"
    if [[ -f "$temp_dir/bin/micromamba" ]]; then
        mv "$temp_dir/bin/micromamba" "$install_path" || {
            log_error "Failed to move micromamba to $install_path"
            rm -f "$temp_file"
            rm -rf "$temp_dir"
            return 1
        }
    else
        log_error "Micromamba binary not found in tarball"
        rm -f "$temp_file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_file"
    rm -rf "$temp_dir"
    
    # Set executable permissions
    chmod +x "$install_path" || {
        log_error "Failed to set executable permissions on $install_path"
        return 1
    }
    
    # Verify installation
    if [[ ! -x "$install_path" ]]; then
        log_error "Micromamba installation failed: not executable"
        return 1
    fi
    
    # Test that it runs
    local version
    version="$("$install_path" --version 2>/dev/null)" || {
        log_error "Micromamba installation failed: cannot execute"
        return 1
    }
    
    log_success "Micromamba installed successfully to $install_path"
    log_info "Version: $version"
    
    return 0
}

# Interactive bootstrap prompt for micromamba installation
# Arguments:
#   $1 - Context message (optional, e.g., "Detected: environment.yml")
# Returns: 0 if installed, 1 if user aborted
bootstrap_micromamba_interactive() {
    local context="${1:-}"
    
    printf "\n"
    log_error "Backend 'micromamba' required but not found."
    printf "\n"
    
    if [[ -n "$context" ]]; then
        printf "%s\n" "$context"
        printf "\n"
    fi
    
    printf "Installation options:\n"
    printf "  1. Install to project sandbox: .pyve/bin/micromamba\n"
    printf "  2. Install to user sandbox: ~/.pyve/bin/micromamba\n"
    printf "  3. Install via system package manager (brew/apt)\n"
    printf "  4. Abort and install manually\n"
    printf "\n"
    
    local choice
    while true; do
        printf "Choice [1]: "
        read -r choice
        
        # Default to 1 if empty
        if [[ -z "$choice" ]]; then
            choice="1"
        fi
        
        case "$choice" in
            1)
                log_info "Installing micromamba to project sandbox..."
                if bootstrap_install_micromamba "project"; then
                    return 0
                else
                    log_error "Installation failed. Please try another option."
                    return 1
                fi
                ;;
            2)
                log_info "Installing micromamba to user sandbox..."
                if bootstrap_install_micromamba "user"; then
                    return 0
                else
                    log_error "Installation failed. Please try another option."
                    return 1
                fi
                ;;
            3)
                printf "\n"
                log_info "To install via package manager:"
                printf "\n"
                if [[ "$(uname -s)" == "Darwin" ]]; then
                    printf "  brew install micromamba\n"
                else
                    printf "  See: https://mamba.readthedocs.io/en/latest/installation.html\n"
                fi
                printf "\n"
                log_info "After installation, run 'pyve --init' again."
                return 1
                ;;
            4)
                log_info "Installation aborted."
                log_info "Install micromamba manually and run 'pyve --init' again."
                return 1
                ;;
            *)
                printf "Invalid choice. Please enter 1, 2, 3, or 4.\n"
                ;;
        esac
    done
}

# Auto-bootstrap micromamba (non-interactive)
# Arguments:
#   $1 - Installation location ("project" or "user", default: "user")
# Returns: 0 on success, 1 on failure
bootstrap_micromamba_auto() {
    local install_location="${1:-user}"
    
    log_info "Auto-bootstrapping micromamba to $install_location sandbox..."
    
    if bootstrap_install_micromamba "$install_location"; then
        return 0
    else
        log_error "Auto-bootstrap failed"
        return 1
    fi
}
