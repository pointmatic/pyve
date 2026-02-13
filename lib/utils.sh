#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
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

# Check if a pattern is already present in .gitignore (exact line match)
# Usage: gitignore_has_pattern "pattern"
# Returns 0 if found, 1 if not
gitignore_has_pattern() {
    local pattern="$1"
    local gitignore=".gitignore"
    grep -qxF "$pattern" "$gitignore" 2>/dev/null
}

# Add a pattern to .gitignore if not already present
# Usage: append_pattern_to_gitignore "pattern"
append_pattern_to_gitignore() {
    local pattern="$1"
    local gitignore=".gitignore"
    
    # Create .gitignore if it doesn't exist
    if [[ ! -f "$gitignore" ]]; then
        touch "$gitignore"
    fi
    
    if gitignore_has_pattern "$pattern"; then
        return 0  # Already present
    fi
    
    # Append pattern
    printf "%s\n" "$pattern" >> "$gitignore"
}

# Insert a pattern after a section comment in .gitignore if not already present
# Falls back to append if the section comment is not found.
# Usage: insert_pattern_in_gitignore_section "pattern" "section_comment"
#   pattern:         the gitignore entry (e.g. ".venv")
#   section_comment: the full comment line to insert after (e.g. "# Pyve virtual environment")
insert_pattern_in_gitignore_section() {
    local pattern="$1"
    local section="$2"
    local gitignore=".gitignore"
    
    if [[ ! -f "$gitignore" ]]; then
        touch "$gitignore"
    fi
    
    if gitignore_has_pattern "$pattern"; then
        return 0  # Already present
    fi
    
    # Try to insert after the section comment
    if grep -qxF "$section" "$gitignore" 2>/dev/null; then
        # Insert pattern on the line after the section comment
        local tmpfile
        tmpfile="$(mktemp "${gitignore}.tmp.XXXXXX")"
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf '%s\n' "$line" >> "$tmpfile"
            if [[ "$line" == "$section" ]]; then
                printf '%s\n' "$pattern" >> "$tmpfile"
            fi
        done < "$gitignore"
        mv "$tmpfile" "$gitignore"
    else
        # Section not found — fall back to append
        printf "%s\n" "$pattern" >> "$gitignore"
    fi
}

# Remove a pattern from .gitignore (exact line match)
# Usage: remove_pattern_from_gitignore "pattern"
remove_pattern_from_gitignore() {
    local pattern="$1"
    local gitignore=".gitignore"
    
    if [[ ! -f "$gitignore" ]]; then
        return 0  # Nothing to remove
    fi
    
    # Use sed to remove exact line match
    # macOS sed requires '' after -i, Linux doesn't
    local escaped
    escaped="$(printf '%s' "$pattern" | sed 's/[.[\*^$()+?{|]/\\&/g')"
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "/^${escaped}$/d" "$gitignore"
    else
        sed -i "/^${escaped}$/d" "$gitignore"
    fi
}

# Write (or rebuild) the .gitignore from the Pyve template.
#
# The Pyve-managed section is written to a temporary file first.  If an
# existing .gitignore is present, every line that is NOT already in the
# template is appended verbatim, preserving the user's formatting, blank
# lines, section headers, and comments.
#
# The result is: Pyve-managed entries at the top, user entries below.
# Running `pyve --init` (or --force) is therefore idempotent — the file
# converges to a stable layout without unnecessary git diffs.
#
# Note: .gitignore does not support inline comments.  A `#` is only a
# comment when it is the first non-whitespace character on the line.
#
# Usage: write_gitignore_template
write_gitignore_template() {
    local gitignore=".gitignore"
    local tmpfile
    tmpfile="$(mktemp "${gitignore}.tmp.XXXXXX")"

    # --- 1. Write the Pyve-managed section ---
    cat > "$tmpfile" << 'GITIGNORE_EOF'
# macOS only
.DS_Store

# Python build and test artifacts
__pycache__
*.egg-info
.coverage
coverage.xml
htmlcov/
.pytest_cache/

# Pyve virtual environment
GITIGNORE_EOF

    # --- 2. Append non-template lines from the existing file ---
    if [[ -f "$gitignore" ]]; then
        # Build set of ALL template lines (including comments) for deduplication
        local -a template_lines=()
        while IFS= read -r tline; do
            [[ -n "$tline" ]] && template_lines+=("$tline")
        done < "$tmpfile"

        # Also include dynamically inserted Pyve-managed patterns so they
        # are stripped from the user-entries pass on subsequent inits.
        local -a dynamic_patterns=(
            ".envrc" ".env" ".pyve/testenv" ".pyve/envs"
            "${DEFAULT_VENV_DIR:-.venv}"
        )
        template_lines+=("${dynamic_patterns[@]}")

        # Pass through every line from the existing file
        local prev_was_blank=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Blank lines: pass through but collapse consecutive blanks
            if [[ -z "$line" ]]; then
                if [[ "$prev_was_blank" == false ]]; then
                    printf '\n' >> "$tmpfile"
                fi
                prev_was_blank=true
                continue
            fi
            prev_was_blank=false

            # Skip if this exact line is already in the template
            local found=false
            for tl in "${template_lines[@]}"; do
                if [[ "$line" == "$tl" ]]; then
                    found=true
                    break
                fi
            done

            if [[ "$found" == false ]]; then
                printf '%s\n' "$line" >> "$tmpfile"
            fi
        done < "$gitignore"
    fi

    # --- 3. Strip trailing blank lines and replace atomically ---
    # When dynamic entries are deduped, their surrounding blank lines may
    # leak through as trailing whitespace.
    local content
    content="$(cat "$tmpfile")"
    printf '%s\n' "$content" > "$tmpfile"

    mv -f "$tmpfile" "$gitignore"
}

#============================================================
# YAML Configuration Parser
#============================================================

# Read a simple YAML value from .pyve/config
# Usage: read_config_value "backend" or read_config_value "micromamba.env_name"
# Returns the value or empty string if not found
read_config_value() {
    local key="$1"
    local config_file=".pyve/config"
    
    # Return empty if config file doesn't exist
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 0
    fi
    
    # Handle nested keys (e.g., "micromamba.env_name")
    if [[ "$key" == *.* ]]; then
        local section="${key%%.*}"
        local subkey="${key#*.}"
        
        # Extract value from nested section using awk
        # This handles simple YAML: section:\n  subkey: value
        awk -v section="$section" -v subkey="$subkey" '
            /^[a-z_]+:/ { current_section = $1; gsub(/:/, "", current_section) }
            current_section == section && $1 == subkey ":" {
                # Remove leading/trailing whitespace and quotes
                value = $2
                gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", value)
                print value
                exit
            }
        ' "$config_file"
    else
        # Handle top-level keys
        awk -v key="$key" '
            /^[a-z_]+:/ && $1 == key ":" {
                # Remove leading/trailing whitespace and quotes
                value = $2
                gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", value)
                print value
                exit
            }
        ' "$config_file"
    fi
}

# Check if .pyve/config file exists
# Returns 0 if exists, 1 if not
config_file_exists() {
    [[ -f ".pyve/config" ]]
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
