#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
# lib/utils.sh - Utility functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

#============================================================
# Logging Functions
#============================================================

log_info() {
    printf "INFO: %s\n" "$1"
}

log_warning() {
    printf "WARNING: %s\n" "$1" >&2
}

log_error() {
    printf "ERROR: %s\n" "$1" >&2
}

log_success() {
    printf "✓ %s\n" "$1"
}

#============================================================
# User Prompts
#============================================================

# Prompt user for yes/no confirmation
# Usage: prompt_yes_no "Question?"
# Returns 0 for yes, 1 for no
prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        printf "%s [y/n]: " "$prompt"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                printf "Please answer yes or no.\n"
                ;;
        esac
    done
}

#============================================================
# Gitignore Management
#============================================================

# Add a pattern to .gitignore if not already present
# Usage: append_pattern_to_gitignore "pattern"
append_pattern_to_gitignore() {
    local pattern="$1"
    local gitignore=".gitignore"
    
    # Create .gitignore if it doesn't exist
    if [[ ! -f "$gitignore" ]]; then
        touch "$gitignore"
    fi
    
    # Check if pattern already exists (exact line match)
    if grep -qxF "$pattern" "$gitignore" 2>/dev/null; then
        return 0  # Already present
    fi
    
    # Append pattern
    printf "%s\n" "$pattern" >> "$gitignore"
}

# Remove a pattern from .gitignore
# Usage: remove_pattern_from_gitignore "pattern"
remove_pattern_from_gitignore() {
    local pattern="$1"
    local gitignore=".gitignore"
    
    if [[ ! -f "$gitignore" ]]; then
        return 0  # Nothing to remove
    fi
    
    # Use sed to remove exact line match
    # macOS sed requires '' after -i, Linux doesn't
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "/^$(printf '%s' "$pattern" | sed 's/[.[\*^$()+?{|]/\\&/g')$/d" "$gitignore"
    else
        sed -i "/^$(printf '%s' "$pattern" | sed 's/[.[\*^$()+?{|]/\\&/g')$/d" "$gitignore"
    fi
}

#============================================================
# Validation Functions
#============================================================

# Validate venv directory name
# Returns 0 if valid, 1 if invalid
# Usage: validate_venv_dir_name "dirname"
validate_venv_dir_name() {
    local dir_name="$1"
    
    # Check for empty
    if [[ -z "$dir_name" ]]; then
        log_error "Virtual environment directory name cannot be empty."
        return 1
    fi
    
    # Check for valid characters (alphanumeric, dots, underscores, hyphens)
    if [[ ! "$dir_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid directory name '$dir_name'. Use only alphanumeric characters, dots, underscores, and hyphens."
        return 1
    fi
    
    # Check for reserved names
    local reserved_names=(".env" ".git" ".gitignore" ".tool-versions" ".python-version" ".envrc")
    local reserved
    for reserved in "${reserved_names[@]}"; do
        if [[ "$dir_name" == "$reserved" ]]; then
            log_error "Directory name '$dir_name' is reserved and cannot be used."
            return 1
        fi
    done
    
    return 0
}

# Validate Python version format
# Returns 0 if valid, 1 if invalid
# Usage: validate_python_version "3.13.7"
validate_python_version() {
    local version="$1"
    
    # Check for empty
    if [[ -z "$version" ]]; then
        log_error "Python version cannot be empty."
        return 1
    fi
    
    # Check format: major.minor.patch (e.g., 3.13.7)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid Python version format '$version'. Expected format: #.#.# (e.g., 3.13.7)"
        return 1
    fi
    
    return 0
}

#============================================================
# File Utility Functions
#============================================================

# Check if a file is empty
# Returns 0 if empty or doesn't exist, 1 if has content
# Usage: is_file_empty "filename"
is_file_empty() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 0  # Doesn't exist, treat as empty
    fi
    
    if [[ ! -s "$file" ]]; then
        return 0  # Exists but empty
    fi
    
    return 1  # Has content
}
