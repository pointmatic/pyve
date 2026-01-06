#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
# lib/micromamba_env.sh - Micromamba environment management functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

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

#============================================================
# Environment Creation Functions
#============================================================

# Check if micromamba environment exists
# Arguments:
#   $1 - Environment name
# Returns: 0 if exists, 1 if not exists
check_micromamba_env_exists() {
    local env_name="$1"
    local env_path=".pyve/envs/$env_name"
    
    if [[ -d "$env_path" ]]; then
        return 0
    else
        return 1
    fi
}

# Create micromamba environment from environment file
# Arguments:
#   $1 - Environment name
#   $2 - Environment file path (optional, auto-detected if not provided)
# Returns: 0 on success, 1 on failure
create_micromamba_env() {
    local env_name="$1"
    local env_file="${2:-}"
    
    # Validate environment name
    if [[ -z "$env_name" ]]; then
        log_error "Environment name is required"
        return 1
    fi
    
    # Auto-detect environment file if not provided
    if [[ -z "$env_file" ]]; then
        env_file="$(detect_environment_file)"
        if [[ -z "$env_file" ]]; then
            log_error "No environment file found"
            return 1
        fi
    fi
    
    # Verify environment file exists
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    # Check if environment already exists
    if check_micromamba_env_exists "$env_name"; then
        log_info "Micromamba environment '$env_name' already exists, skipping creation"
        return 0
    fi
    
    # Get micromamba path
    local micromamba_path
    micromamba_path="$(get_micromamba_path)"
    if [[ -z "$micromamba_path" ]]; then
        log_error "Micromamba not found"
        return 1
    fi
    
    # Create environment directory
    local env_path=".pyve/envs/$env_name"
    mkdir -p ".pyve/envs" || {
        log_error "Failed to create .pyve/envs directory"
        return 1
    }
    
    log_info "Creating micromamba environment '$env_name' from $env_file..."
    
    # Execute micromamba create command
    # Use -p for prefix (path-based environment)
    # Use -f for file (environment.yml or conda-lock.yml)
    # Use -y for yes (non-interactive)
    if "$micromamba_path" create -p "$env_path" -f "$env_file" -y; then
        log_success "Micromamba environment '$env_name' created successfully"
        return 0
    else
        log_error "Failed to create micromamba environment"
        log_error "Check that:"
        log_error "  - All channels are accessible"
        log_error "  - All packages are available"
        log_error "  - Environment file is valid"
        return 1
    fi
}

# Verify micromamba environment is functional
# Arguments:
#   $1 - Environment name
# Returns: 0 if functional, 1 if not
verify_micromamba_env() {
    local env_name="$1"
    local env_path=".pyve/envs/$env_name"
    
    # Check if environment directory exists
    if [[ ! -d "$env_path" ]]; then
        log_error "Environment directory not found: $env_path"
        return 1
    fi
    
    # Check if conda-meta directory exists (indicates valid conda environment)
    if [[ ! -d "$env_path/conda-meta" ]]; then
        log_error "Environment appears invalid (missing conda-meta)"
        return 1
    fi
    
    # Check if Python executable exists
    if [[ ! -f "$env_path/bin/python" ]]; then
        log_warning "Python executable not found in environment"
        log_warning "This may be expected if Python is not in dependencies"
    fi
    
    return 0
}
