#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
# lib/backend_detect.sh - Backend detection functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

#============================================================
# Backend Detection Functions
#============================================================

# Detect backend from project files
# Returns: "venv", "micromamba", or "none"
detect_backend_from_files() {
    local has_conda_files=false
    local has_python_files=false
    
    # Check for conda/micromamba files
    if [[ -f "environment.yml" ]] || [[ -f "conda-lock.yml" ]]; then
        has_conda_files=true
    fi
    
    # Check for Python/pip files
    if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
        has_python_files=true
    fi
    
    # Determine backend based on files present
    if [[ "$has_conda_files" == true ]] && [[ "$has_python_files" == true ]]; then
        # Both present - ambiguous
        echo "ambiguous"
    elif [[ "$has_conda_files" == true ]]; then
        echo "micromamba"
    elif [[ "$has_python_files" == true ]]; then
        echo "venv"
    else
        echo "none"
    fi
}

# Get backend priority based on CLI flag, config file, and file detection
# Arguments:
#   $1 - CLI backend flag value (venv, micromamba, auto, or empty)
# Returns: "venv" or "micromamba"
get_backend_priority() {
    local cli_backend="${1:-}"
    
    # Priority 1: CLI flag (if not "auto")
    if [[ -n "$cli_backend" ]] && [[ "$cli_backend" != "auto" ]]; then
        echo "$cli_backend"
        return 0
    fi
    
    # Priority 2: .pyve/config file
    if config_file_exists; then
        local config_backend
        config_backend="$(read_config_value "backend")"
        if [[ -n "$config_backend" ]]; then
            echo "$config_backend"
            return 0
        fi
    fi
    
    # Priority 3: File-based detection
    local detected_backend
    detected_backend="$(detect_backend_from_files)"
    
    if [[ "$detected_backend" == "ambiguous" ]]; then
        log_warning "Both conda and Python package files detected"
        log_warning "Please specify backend explicitly with --backend flag or .pyve/config"
        log_warning "  --backend venv        Use Python venv"
        log_warning "  --backend micromamba  Use micromamba"
        echo "venv"  # Default to venv for now
        return 0
    elif [[ "$detected_backend" == "micromamba" ]]; then
        echo "micromamba"
        return 0
    fi
    
    # Priority 4: Default to venv
    echo "venv"
    return 0
}

# Validate backend value
# Arguments:
#   $1 - Backend value to validate
# Returns: 0 if valid, 1 if invalid
validate_backend() {
    local backend="$1"
    
    case "$backend" in
        venv|micromamba|auto)
            return 0
            ;;
        *)
            log_error "Invalid backend: $backend"
            log_error "Valid backends: venv, micromamba, auto"
            return 1
            ;;
    esac
}

# Validate .pyve/config file
# Returns: 0 if valid or doesn't exist, 1 if invalid
validate_config_file() {
    if ! config_file_exists; then
        return 0  # No config file is valid
    fi
    
    local config_file=".pyve/config"
    local has_errors=false
    
    # Check if backend value is valid (if present)
    local backend
    backend="$(read_config_value "backend")"
    if [[ -n "$backend" ]]; then
        if ! validate_backend "$backend"; then
            log_error "Invalid backend in $config_file: $backend"
            has_errors=true
        fi
    fi
    
    # Check if venv.directory is valid (if present)
    local venv_dir
    venv_dir="$(read_config_value "venv.directory")"
    if [[ -n "$venv_dir" ]]; then
        if ! validate_venv_dir_name "$venv_dir"; then
            log_error "Invalid venv.directory in $config_file: $venv_dir"
            has_errors=true
        fi
    fi
    
    # Check if python.version is valid (if present)
    local python_version
    python_version="$(read_config_value "python.version")"
    if [[ -n "$python_version" ]]; then
        if ! validate_python_version "$python_version"; then
            log_error "Invalid python.version in $config_file: $python_version"
            has_errors=true
        fi
    fi
    
    if [[ "$has_errors" == true ]]; then
        return 1
    fi
    
    return 0
}
