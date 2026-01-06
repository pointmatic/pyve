#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
# lib/micromamba_bootstrap.sh - Micromamba installation and bootstrap functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

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
