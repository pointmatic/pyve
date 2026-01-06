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

#============================================================
# Environment File Detection Functions
#============================================================

# Detect environment file (conda-lock.yml or environment.yml)
# Detection order:
#   1. conda-lock.yml (highest priority)
#   2. environment.yml (fallback)
# Returns: path to detected file or empty string if neither exists
detect_environment_file() {
    # Priority 1: conda-lock.yml
    if [[ -f "conda-lock.yml" ]]; then
        echo "conda-lock.yml"
        return 0
    fi
    
    # Priority 2: environment.yml
    if [[ -f "environment.yml" ]]; then
        echo "environment.yml"
        return 0
    fi
    
    # Not found
    echo ""
    return 1
}

# Parse environment.yml for environment name
# Returns: environment name or empty string if not found
parse_environment_name() {
    local env_file="${1:-environment.yml}"
    
    if [[ ! -f "$env_file" ]]; then
        echo ""
        return 1
    fi
    
    # Extract name field from YAML
    local name
    name="$(awk '/^name:/ {print $2; exit}' "$env_file" | tr -d '"' | tr -d "'")"
    
    echo "$name"
    return 0
}

# Parse environment.yml for channels
# Returns: space-separated list of channels or empty string
parse_environment_channels() {
    local env_file="${1:-environment.yml}"
    
    if [[ ! -f "$env_file" ]]; then
        echo ""
        return 1
    fi
    
    # Extract channels from YAML (simple parsing)
    # This handles: channels:\n  - channel1\n  - channel2
    local channels
    channels="$(awk '/^channels:$/,/^[a-z]/ {if ($1 == "-") print $2}' "$env_file" | tr '\n' ' ')"
    
    echo "$channels"
    return 0
}

# Validate environment.yml exists and is readable
# Returns: 0 if valid, 1 if invalid
validate_environment_file() {
    local env_file
    env_file="$(detect_environment_file)"
    
    if [[ -z "$env_file" ]]; then
        log_error "No environment file found"
        log_error "Micromamba backend requires either:"
        log_error "  - conda-lock.yml (for reproducible builds)"
        log_error "  - environment.yml (for flexible dependencies)"
        log_error ""
        log_error "Create environment.yml with:"
        log_error "  name: myproject"
        log_error "  channels:"
        log_error "    - conda-forge"
        log_error "  dependencies:"
        log_error "    - python=3.11"
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$env_file" ]]; then
        log_error "Environment file '$env_file' is not readable"
        return 1
    fi
    
    # Basic YAML validation for environment.yml (not for conda-lock.yml)
    if [[ "$env_file" == "environment.yml" ]]; then
        # Check for required fields
        if ! grep -q "^name:" "$env_file"; then
            log_warning "environment.yml missing 'name:' field"
            log_warning "Environment name will be derived from project directory"
        fi
        
        if ! grep -q "^channels:" "$env_file"; then
            log_warning "environment.yml missing 'channels:' field"
            log_warning "Using default channels"
        fi
        
        if ! grep -q "^dependencies:" "$env_file"; then
            log_error "environment.yml missing required 'dependencies:' field"
            return 1
        fi
    fi
    
    return 0
}

# Error if no environment file found
# Returns: 1 (always errors)
error_no_environment_file() {
    log_error "No environment file found for micromamba backend"
    log_error ""
    log_error "Micromamba requires either:"
    log_error "  - conda-lock.yml (for reproducible builds)"
    log_error "  - environment.yml (for flexible dependencies)"
    log_error ""
    log_error "Create environment.yml with:"
    log_error ""
    printf "  name: myproject\n"
    printf "  channels:\n"
    printf "    - conda-forge\n"
    printf "  dependencies:\n"
    printf "    - python=3.11\n"
    printf "    - numpy\n"
    log_error ""
    log_error "Or generate a lock file:"
    log_error "  conda-lock -f environment.yml -p $(uname -m)"
    
    return 1
}

#============================================================
# Lock File Validation Functions
#============================================================

# Check if lock file is stale (environment.yml newer than conda-lock.yml)
# Returns: 0 if stale, 1 if not stale or files don't exist
is_lock_file_stale() {
    # Both files must exist
    if [[ ! -f "environment.yml" ]] || [[ ! -f "conda-lock.yml" ]]; then
        return 1
    fi
    
    # Get modification times (seconds since epoch)
    local env_mtime
    local lock_mtime
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        env_mtime=$(stat -f %m "environment.yml" 2>/dev/null)
        lock_mtime=$(stat -f %m "conda-lock.yml" 2>/dev/null)
    else
        # Linux
        env_mtime=$(stat -c %Y "environment.yml" 2>/dev/null)
        lock_mtime=$(stat -c %Y "conda-lock.yml" 2>/dev/null)
    fi
    
    # Check if environment.yml is newer
    if [[ -n "$env_mtime" ]] && [[ -n "$lock_mtime" ]] && [[ "$env_mtime" -gt "$lock_mtime" ]]; then
        return 0  # Stale
    else
        return 1  # Not stale
    fi
}

# Get human-readable modification time
# Arguments:
#   $1 - File path
# Returns: formatted date string
get_file_mtime_formatted() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "unknown"
        return 1
    fi
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null
    else
        # Linux
        stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1
    fi
}

# Check if running in interactive mode
# Returns: 0 if interactive, 1 if non-interactive (CI/batch)
is_interactive() {
    # Check if stdin is a terminal
    if [[ -t 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Warn about stale lock file (interactive mode only)
# Returns: 0 if user continues, 1 if user aborts
warn_stale_lock_file() {
    local env_mtime
    local lock_mtime
    
    env_mtime="$(get_file_mtime_formatted "environment.yml")"
    lock_mtime="$(get_file_mtime_formatted "conda-lock.yml")"
    
    printf "\n"
    log_warning "Lock file may be stale"
    printf "  environment.yml:  modified %s\n" "$env_mtime"
    printf "  conda-lock.yml:   modified %s\n" "$lock_mtime"
    printf "\n"
    printf "Using conda-lock.yml for reproducibility.\n"
    printf "To update lock file:\n"
    printf "  conda-lock -f environment.yml -p %s\n" "$(uname -m)"
    printf "\n"
    
    # Prompt user
    if prompt_yes_no "Continue anyway?"; then
        return 0
    else
        log_info "Aborted. Please update lock file and try again."
        return 1
    fi
}

# Info message about missing lock file (interactive mode only)
# Returns: 0 if user continues, 1 if user aborts
info_missing_lock_file() {
    printf "\n"
    log_info "Using environment.yml without lock file."
    printf "\n"
    printf "For reproducible builds, consider generating a lock file:\n"
    printf "  conda-lock -f environment.yml -p %s\n" "$(uname -m)"
    printf "\n"
    printf "This is especially important for CI/CD and production.\n"
    printf "\n"
    
    # Prompt user
    if prompt_yes_no "Continue anyway?"; then
        return 0
    else
        log_info "Aborted. Generate lock file and try again."
        return 1
    fi
}

# Validate lock file status (with interactive warnings)
# Arguments:
#   $1 - strict mode (true/false)
# Returns: 0 if valid or user continues, 1 if invalid or user aborts
validate_lock_file_status() {
    local strict_mode="${1:-false}"
    
    # Check if both files exist
    local has_env_yml=false
    local has_lock_yml=false
    
    [[ -f "environment.yml" ]] && has_env_yml=true
    [[ -f "conda-lock.yml" ]] && has_lock_yml=true
    
    # Case 1: Both files exist - check staleness
    if [[ "$has_env_yml" == true ]] && [[ "$has_lock_yml" == true ]]; then
        if is_lock_file_stale; then
            # Stale lock file detected
            if [[ "$strict_mode" == true ]]; then
                log_error "Lock file is stale (strict mode)"
                log_error "environment.yml was modified after conda-lock.yml"
                log_error "Regenerate lock file:"
                log_error "  conda-lock -f environment.yml -p $(uname -m)"
                return 1
            elif is_interactive; then
                # Interactive mode - warn and prompt
                if ! warn_stale_lock_file; then
                    return 1
                fi
            fi
            # Non-interactive mode - silent, continue
        fi
        return 0
    fi
    
    # Case 2: Only environment.yml exists (no lock file)
    if [[ "$has_env_yml" == true ]] && [[ "$has_lock_yml" == false ]]; then
        if [[ "$strict_mode" == true ]]; then
            log_error "Lock file missing (strict mode)"
            log_error "Generate lock file for reproducible builds:"
            log_error "  conda-lock -f environment.yml -p $(uname -m)"
            return 1
        elif is_interactive; then
            # Interactive mode - info and prompt
            if ! info_missing_lock_file; then
                return 1
            fi
        fi
        # Non-interactive mode - silent, continue
        return 0
    fi
    
    # Case 3: Only conda-lock.yml exists (unusual but valid)
    if [[ "$has_env_yml" == false ]] && [[ "$has_lock_yml" == true ]]; then
        return 0
    fi
    
    # Case 4: Neither file exists (error handled elsewhere)
    return 0
}

#============================================================
# Environment Naming Functions
#============================================================

# Sanitize environment name for conda/micromamba
# Arguments:
#   $1 - Raw environment name
# Returns: sanitized name
sanitize_environment_name() {
    local raw_name="$1"
    
    if [[ -z "$raw_name" ]]; then
        echo ""
        return 1
    fi
    
    # Convert to lowercase
    local sanitized="${raw_name,,}"
    
    # Replace spaces and special characters with hyphens
    # Keep only alphanumeric, hyphens, and underscores
    sanitized="$(echo "$sanitized" | tr -cs '[:alnum:]_-' '-')"
    
    # Remove leading/trailing hyphens
    sanitized="${sanitized#-}"
    sanitized="${sanitized%-}"
    
    # Ensure it starts with letter or underscore
    if [[ ! "$sanitized" =~ ^[a-z_] ]]; then
        sanitized="env-${sanitized}"
    fi
    
    # Truncate to max 255 characters
    if [[ ${#sanitized} -gt 255 ]]; then
        sanitized="${sanitized:0:255}"
    fi
    
    echo "$sanitized"
    return 0
}

# Check if environment name is reserved
# Arguments:
#   $1 - Environment name
# Returns: 0 if reserved, 1 if not reserved
is_reserved_environment_name() {
    local name="$1"
    
    local reserved_names=("base" "root" "default" "conda" "mamba" "micromamba")
    
    for reserved in "${reserved_names[@]}"; do
        if [[ "$name" == "$reserved" ]]; then
            return 0  # Reserved
        fi
    done
    
    return 1  # Not reserved
}

# Validate environment name
# Arguments:
#   $1 - Environment name
# Returns: 0 if valid, 1 if invalid
validate_environment_name() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Environment name cannot be empty"
        return 1
    fi
    
    # Check if reserved
    if is_reserved_environment_name "$name"; then
        log_error "Environment name '$name' is reserved"
        log_error "Reserved names: base, root, default, conda, mamba, micromamba"
        return 1
    fi
    
    # Check length
    if [[ ${#name} -gt 255 ]]; then
        log_error "Environment name too long (max 255 characters): $name"
        return 1
    fi
    
    # Check valid characters (alphanumeric, hyphens, underscores)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid environment name: $name"
        log_error "Use only alphanumeric characters, hyphens, and underscores"
        return 1
    fi
    
    # Check starts with letter or underscore
    if [[ ! "$name" =~ ^[a-zA-Z_] ]]; then
        log_error "Environment name must start with letter or underscore: $name"
        return 1
    fi
    
    return 0
}

# Resolve environment name with priority order
# Arguments:
#   $1 - CLI flag value (optional)
# Returns: resolved environment name
resolve_environment_name() {
    local cli_name="${1:-}"
    local resolved_name=""
    
    # Priority 1: CLI flag --env-name
    if [[ -n "$cli_name" ]]; then
        resolved_name="$cli_name"
        echo "$resolved_name"
        return 0
    fi
    
    # Priority 2: .pyve/config → micromamba.env_name
    if config_file_exists; then
        local config_name
        config_name="$(read_config_value "micromamba.env_name")"
        if [[ -n "$config_name" ]]; then
            resolved_name="$config_name"
            echo "$resolved_name"
            return 0
        fi
    fi
    
    # Priority 3: environment.yml → name: field
    if [[ -f "environment.yml" ]]; then
        local env_file_name
        env_file_name="$(parse_environment_name "environment.yml")"
        if [[ -n "$env_file_name" ]]; then
            resolved_name="$env_file_name"
            echo "$resolved_name"
            return 0
        fi
    fi
    
    # Priority 4: Project directory basename (sanitized)
    local project_dir
    project_dir="$(basename "$(pwd)")"
    resolved_name="$(sanitize_environment_name "$project_dir")"
    
    echo "$resolved_name"
    return 0
}
