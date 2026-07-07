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
# Returns: "venv", "micromamba", "ambiguous", or "none"
#
# thin delegator over the Python plugin's detect hook.
# The plugin owns the file-signal probes (broader signal set:
# `pyproject.toml | requirements*.txt | setup.py | *.py` for Python;
# `environment*.yml | conda-lock.yml` for conda). This wrapper is
# kept as a public entry point so existing callers in `pyve.sh` and
# `lib/commands/init.sh` don't churn — N.o onward can drop them in
# favor of `plugin_dispatch python detect` directly.
detect_backend_from_files() {
    plugin_dispatch python detect
}

# Get backend priority based on CLI flag and file detection. The manifest's
# declared root backend reaches here as the CLI flag (the wizard seeds it),
# so this resolver only arbitrates flag vs. filesystem detection.
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

    # Priority 2: File-based detection
    local detected_backend
    detected_backend="$(detect_backend_from_files)"
    
    if [[ "$detected_backend" == "ambiguous" ]]; then
        # Both conda and Python files detected - prompt user or use smart default
        log_info "Detected files:" >&2
        if [[ -f "environment.yml" ]]; then
            log_info "  • environment.yml (conda/micromamba)" >&2
        elif [[ -f "conda-lock.yml" ]]; then
            log_info "  • conda-lock.yml (conda/micromamba)" >&2
        fi
        if [[ -f "pyproject.toml" ]]; then
            log_info "  • pyproject.toml (Python project)" >&2
        elif [[ -f "requirements.txt" ]]; then
            log_info "  • requirements.txt (Python dependencies)" >&2
        fi
        echo "" >&2
        
        # In CI or non-interactive mode, default to micromamba
        if [[ -n "${CI:-}" ]] || [[ -n "${PYVE_FORCE_YES:-}" ]]; then
            log_info "Non-interactive mode: defaulting to micromamba backend" >&2
            echo "micromamba"
            return 0
        fi
        
        # Interactive mode: prompt user with micromamba as default
        printf "Initialize with micromamba backend? [Y/n]: " >&2
        read -r response
        
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            echo "micromamba"
        else
            log_info "Using venv backend — initialization will continue with venv" >&2
            echo "venv"
        fi
        return 0
    elif [[ "$detected_backend" == "micromamba" ]]; then
        echo "micromamba"
        return 0
    fi
    
    # Priority 3: Default to venv
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
