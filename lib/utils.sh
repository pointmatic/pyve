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

# Prompt to install pip dependencies after environment creation
# Detects pyproject.toml or requirements.txt and prompts user to install
# Respects --auto-install-deps and --no-install-deps flags
# Usage: prompt_install_pip_dependencies [backend] [env_path]
#   backend: "venv" or "micromamba" (optional, defaults to venv)
#   env_path: path to micromamba environment (required if backend is micromamba)
prompt_install_pip_dependencies() {
    local backend="${1:-venv}"
    local env_path="${2:-}"
    
    # Check for --no-install-deps flag
    if [[ "${PYVE_NO_INSTALL_DEPS:-}" == "1" ]]; then
        return 0
    fi
    
    local has_pyproject=false
    local has_requirements=false
    
    if [[ -f "pyproject.toml" ]]; then
        has_pyproject=true
    fi
    
    if [[ -f "requirements.txt" ]]; then
        has_requirements=true
    fi
    
    # Nothing to install
    if [[ "$has_pyproject" == false ]] && [[ "$has_requirements" == false ]]; then
        return 0
    fi
    
    echo ""
    
    # Determine pip command based on backend
    local pip_cmd
    if [[ "$backend" == "micromamba" ]]; then
        if [[ -z "$env_path" ]]; then
            log_warning "Cannot install pip dependencies: micromamba env_path not provided"
            return 1
        fi
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -z "$micromamba_path" ]]; then
            log_warning "Cannot install pip dependencies: micromamba not found"
            return 1
        fi
        pip_cmd="$micromamba_path run -p $env_path pip"
    else
        pip_cmd="pip"
    fi
    
    # Auto-install mode (CI or --auto-install-deps flag)
    if [[ -n "${CI:-}" ]] || [[ "${PYVE_AUTO_INSTALL_DEPS:-}" == "1" ]]; then
        if [[ "$has_pyproject" == true ]]; then
            log_info "Auto-installing dependencies from pyproject.toml..."
            $pip_cmd install -e . || log_warning "Failed to install from pyproject.toml"
        fi
        if [[ "$has_requirements" == true ]]; then
            log_info "Auto-installing dependencies from requirements.txt..."
            $pip_cmd install -r requirements.txt || log_warning "Failed to install from requirements.txt"
        fi
        return 0
    fi
    
    # Interactive mode: prompt for each file
    if [[ "$has_pyproject" == true ]]; then
        printf "Install pip dependencies from pyproject.toml? [Y/n]: "
        read -r response
        
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            log_info "Installing dependencies from pyproject.toml..."
            if $pip_cmd install -e .; then
                log_success "Installed dependencies from pyproject.toml"
            else
                log_warning "Failed to install from pyproject.toml"
            fi
        fi
    fi
    
    if [[ "$has_requirements" == true ]]; then
        printf "Install pip dependencies from requirements.txt? [Y/n]: "
        read -r response
        
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            log_info "Installing dependencies from requirements.txt..."
            if $pip_cmd install -r requirements.txt; then
                log_success "Installed dependencies from requirements.txt"
            else
                log_warning "Failed to install from requirements.txt"
            fi
        fi
    fi
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
*.pyc
*.pyo
*.pyd
*.egg-info
*.egg
.coverage
coverage.xml
htmlcov/
.pytest_cache/
dist/
build/

# Jupyter notebooks
.ipynb_checkpoints/
*.ipynb_checkpoints

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
            "${DEFAULT_VENV_DIR:-.venv}" ".vscode/settings.json"
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
# Doctor: Environment Integrity Checks
#============================================================

# Scan site-packages for packages that have more than one .dist-info directory.
# This indicates cloud sync corruption or overlapping installs.
# Usage: doctor_check_duplicate_dist_info <env_path>
doctor_check_duplicate_dist_info() {
    local env_path="$1"

    local site_packages
    site_packages=$(find "$env_path/lib" -maxdepth 2 -type d -name "site-packages" 2>/dev/null | head -1)

    if [[ -z "$site_packages" ]]; then
        printf "✓ No duplicate dist-info directories\n"
        return 0
    fi

    # Collect all .dist-info dir basenames
    local -a all_dirs=()
    while IFS= read -r d; do
        all_dirs+=("$(basename "$d")")
    done < <(find "$site_packages" -maxdepth 1 -type d -name "*.dist-info" 2>/dev/null | sort)

    if [[ ${#all_dirs[@]} -eq 0 ]]; then
        printf "✓ No duplicate dist-info directories\n"
        return 0
    fi

    # Extract normalized package names (strip -<version>.dist-info)
    local -a pkg_names=()
    for d in "${all_dirs[@]}"; do
        local pkg_name
        pkg_name=$(printf '%s' "${d%.dist-info}" | sed 's/-[0-9].*//')
        pkg_names+=("$pkg_name")
    done

    # Find which package names appear more than once
    local dup_pkgs
    dup_pkgs=$(printf '%s\n' "${pkg_names[@]}" | sort | uniq -d)

    if [[ -z "$dup_pkgs" ]]; then
        printf "✓ No duplicate dist-info directories\n"
        return 0
    fi

    # Report each duplicated package with its conflicting dirs and mtimes
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        printf "✗ Duplicate dist-info detected: %s\n" "$pkg"
        for d in "${all_dirs[@]}"; do
            local dpkg
            dpkg=$(printf '%s' "${d%.dist-info}" | sed 's/-[0-9].*//')
            if [[ "$dpkg" == "$pkg" ]]; then
                local full_path="$site_packages/$d"
                local mtime
                if [[ "$(uname)" == "Darwin" ]]; then
                    mtime=$(stat -f "%Sm" -t "%b %d %H:%M" "$full_path" 2>/dev/null || echo "?")
                else
                    mtime=$(stat -c "%y" "$full_path" 2>/dev/null | cut -d'.' -f1 || echo "?")
                fi
                printf "    %s (%s)\n" "$d" "$mtime"
            fi
        done
    done <<< "$dup_pkgs"
    printf "  Run 'pyve --init --force' to rebuild the environment cleanly.\n"
}

# Scan the environment tree for files/directories with a " 2" suffix — the
# collision naming used by iCloud Drive when two processes create the same
# path simultaneously.
# Usage: doctor_check_collision_artifacts <env_path>
doctor_check_collision_artifacts() {
    local env_path="$1"

    if [[ ! -d "$env_path" ]]; then
        return 0
    fi

    local -a artifacts=()
    while IFS= read -r artifact; do
        artifacts+=("$artifact")
    done < <(find "$env_path" -name "* 2" 2>/dev/null | sort | head -20)

    if [[ ${#artifacts[@]} -eq 0 ]]; then
        printf "✓ No cloud sync collision artifacts\n"
        return 0
    fi

    printf "✗ Cloud sync collision artifacts detected (%d found):\n" "${#artifacts[@]}"
    local shown=0
    for artifact in "${artifacts[@]}"; do
        if [[ $shown -lt 5 ]]; then
            printf "    %s\n" "$artifact"
        fi
        (( shown++ )) || true
    done
    if [[ ${#artifacts[@]} -gt 5 ]]; then
        printf "    ... and %d more\n" "$(( ${#artifacts[@]} - 5 ))"
    fi
    printf "  Caused by cloud sync running concurrently with environment extraction.\n"
    printf "  Rebuild outside a cloud-synced directory: pyve --init --force\n"
}

# Check for known conflicts between pip-bundled native libraries and
# conda-linked ones. When pip packages (torch, tensorflow) bundle their own
# OpenMP and conda packages (numpy, scipy) link against the system OpenMP in
# the environment's lib/ directory, a missing libomp/libgomp produces
# intermittent dlopen failures at import time.
#
# Only runs when both a pip bundler AND a conda linker are detected.
# Usage: doctor_check_native_lib_conflicts <env_path>
doctor_check_native_lib_conflicts() {
    local env_path="$1"

    if [[ ! -d "$env_path" ]]; then
        return 0
    fi

    local site_packages
    site_packages=$(find "$env_path/lib" -maxdepth 2 -type d -name "site-packages" 2>/dev/null | head -1)

    # Known pip packages that bundle their own OpenMP runtime
    local -a pip_bundlers=("torch" "tensorflow" "tensorflow_macos" "tensorflow-macos"
                           "tensorflow_metal" "jax" "jaxlib")

    # Known conda packages that link against the shared OpenMP in env/lib/
    local -a conda_linkers=("numpy" "scipy" "scikit-learn" "pandas" "openblas" "blas" "mkl")

    # Detect pip bundlers present in site-packages
    local -a found_pip=()
    if [[ -n "$site_packages" ]]; then
        for pkg in "${pip_bundlers[@]}"; do
            local matches=("$site_packages/${pkg}-"*.dist-info)
            [[ -e "${matches[0]}" ]] && found_pip+=("$pkg")
        done
    fi

    # Detect conda linkers present in conda-meta
    local -a found_conda=()
    if [[ -d "$env_path/conda-meta" ]]; then
        for pkg in "${conda_linkers[@]}"; do
            local matches=("$env_path/conda-meta/${pkg}-"*.json)
            [[ -e "${matches[0]}" ]] && found_conda+=("$pkg")
        done
    fi

    # Only check for a missing shared lib when both sides are present
    if [[ ${#found_pip[@]} -eq 0 ]] || [[ ${#found_conda[@]} -eq 0 ]]; then
        printf "✓ No conda/pip native library conflicts detected\n"
        return 0
    fi

    # Platform-specific shared library name and conda fix package
    local missing_lib="" fix_pkg=""
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ ! -f "$env_path/lib/libomp.dylib" ]]; then
            missing_lib="libomp.dylib"
            fix_pkg="llvm-openmp"
        fi
    else
        local gomp_matches=("$env_path/lib/libgomp.so"*)
        if [[ ! -e "${gomp_matches[0]}" ]]; then
            missing_lib="libgomp.so"
            fix_pkg="libgomp"
        fi
    fi

    if [[ -z "$missing_lib" ]]; then
        printf "✓ No conda/pip native library conflicts detected\n"
        return 0
    fi

    local pip_list conda_list
    pip_list=$(IFS=', '; echo "${found_pip[*]}")
    conda_list=$(IFS=', '; echo "${found_conda[*]}")

    printf "⚠ Potential native library conflict detected:\n"
    printf "    pip-installed:   %s (bundles its own OpenMP)\n" "$pip_list"
    printf "    conda-installed: %s (requires %s)\n" "$conda_list" "$missing_lib"
    printf "    %s not found in %s/lib/\n\n" "$missing_lib" "$env_path"
    printf "  Fix: add '%s' to environment.yml conda dependencies:\n" "$fix_pkg"
    printf "    dependencies:\n"
    printf "      - %s\n" "$fix_pkg"
    printf "  Then regenerate: conda-lock -f environment.yml -p %s\n" "$(uname -m)"
}

# Detect venv path mismatch (relocated project).
#
# When a project directory is moved after venv creation, pyvenv.cfg retains
# the original creation path. The activate script and direnv will prepend the
# wrong bin/ to PATH, so `which python` resolves to a system shim instead of
# the venv's Python.
#
# Compares the path embedded in pyvenv.cfg's `command` line against the
# actual venv location. Prints a warning if they differ.
# Usage: doctor_check_venv_path <env_path>
doctor_check_venv_path() {
    local env_path="$1"

    local pyvenv_cfg="$env_path/pyvenv.cfg"
    if [[ ! -f "$pyvenv_cfg" ]]; then
        return 0
    fi

    local cfg_venv_path
    cfg_venv_path="$(grep "^command" "$pyvenv_cfg" 2>/dev/null | sed 's/.*-m venv //')"
    if [[ -z "$cfg_venv_path" ]]; then
        return 0
    fi

    local expected_venv_path
    expected_venv_path="$(cd "$env_path" && pwd -P)"
    local canonical_cfg_path
    # Resolve the config path if it exists, otherwise use as-is
    if [[ -d "$cfg_venv_path" ]]; then
        canonical_cfg_path="$(cd "$cfg_venv_path" && pwd -P)"
    else
        canonical_cfg_path="$cfg_venv_path"
    fi

    if [[ "$canonical_cfg_path" != "$expected_venv_path" ]]; then
        printf "⚠ Environment: venv path mismatch (project may have been relocated)\n"
        printf "  Created at: %s\n" "$cfg_venv_path"
        printf "  Expected:   %s\n" "$expected_venv_path"
        printf "  Run 'pyve --init --force' to recreate the environment.\n"
        return 0
    fi

    return 0
}

#============================================================
# VS Code Settings
#============================================================

# Generate .vscode/settings.json for micromamba environments.
#
# Points the IDE at the correct interpreter and prevents it from attempting
# to manage the environment independently (which conflicts with direnv/Pyve).
#
# Skips if the file already exists, unless PYVE_REINIT_MODE=force.
# Usage: write_vscode_settings <env_name>
write_vscode_settings() {
    local env_name="$1"
    local vscode_dir=".vscode"
    local settings_file="$vscode_dir/settings.json"
    local interpreter_path=".pyve/envs/${env_name}/bin/python"

    if [[ -f "$settings_file" ]] && [[ "${PYVE_REINIT_MODE:-}" != "force" ]]; then
        log_info "Skipping .vscode/settings.json (already exists; use --force to overwrite)"
        return 0
    fi

    mkdir -p "$vscode_dir"
    cat > "$settings_file" << EOF
{
  "python.defaultInterpreterPath": "${interpreter_path}",
  "python.terminal.activateEnvironment": false,
  "python.condaPath": ""
}
EOF
    log_success "Created .vscode/settings.json (interpreter: ${interpreter_path})"
}

#============================================================
# Cloud Sync Detection
#============================================================

# Hard fail if the current directory is inside a known cloud-synced path.
#
# Cloud sync daemons (iCloud Drive, Dropbox, Google Drive, OneDrive) write
# concurrently to synced directories, which corrupts micromamba environments
# during extraction. This causes non-deterministic import failures and can
# damage the Python standard library itself.
#
# Set PYVE_ALLOW_SYNCED_DIR=1 (or pass --allow-synced-dir) to bypass.
# Usage: check_cloud_sync_path
check_cloud_sync_path() {
    if [[ "${PYVE_ALLOW_SYNCED_DIR:-}" == "1" ]]; then
        return 0
    fi

    local current_dir="$PWD"
    local sync_root=""
    local sync_provider=""

    # Primary check: known synced path prefixes
    local -a known_synced=(
        "$HOME/Documents"
        "$HOME/Desktop"
        "$HOME/Library/Mobile Documents"
        "$HOME/Dropbox"
        "$HOME/Google Drive"
        "$HOME/OneDrive"
    )

    local path
    for path in "${known_synced[@]}"; do
        if [[ "$current_dir" == "$path" ]] || [[ "$current_dir" == "$path/"* ]]; then
            sync_root="$path"
            case "$path" in
                */Documents)                  sync_provider="iCloud Drive" ;;
                */Desktop)                    sync_provider="iCloud Drive (Desktop)" ;;
                */"Library/Mobile Documents") sync_provider="iCloud Drive" ;;
                */Dropbox)                    sync_provider="Dropbox" ;;
                */"Google Drive")             sync_provider="Google Drive" ;;
                */OneDrive)                   sync_provider="OneDrive" ;;
            esac
            break
        fi
    done

    # Secondary check: extended attributes (macOS only)
    if [[ -z "$sync_root" ]] && [[ "$(uname)" == "Darwin" ]] && command -v xattr >/dev/null 2>&1; then
        if xattr -l "$current_dir" 2>/dev/null | grep -qi "com.apple.cloud\|com.dropbox\|com.google.drive\|com.microsoft.onedrive"; then
            sync_root="$current_dir"
            sync_provider="cloud sync (detected via extended attributes)"
        fi
    fi

    if [[ -z "$sync_root" ]]; then
        return 0
    fi

    printf "ERROR: Project is inside a cloud-synced directory.\n\n" >&2
    printf "  Path:      %s\n" "$current_dir" >&2
    printf "  Sync root: %s (%s)\n\n" "$sync_root" "$sync_provider" >&2
    printf "  Cloud sync daemons write concurrently to synced directories, which\n" >&2
    printf "  corrupts micromamba environments during extraction. This causes\n" >&2
    printf "  non-deterministic import failures and can damage the Python standard\n" >&2
    printf "  library itself.\n\n" >&2
    printf "  Recommended fix: move your project outside the synced directory.\n" >&2
    printf "    mv \"%s\" ~/Developer/%s\n\n" "$current_dir" "$(basename "$current_dir")" >&2
    printf "  If you have disabled sync for this directory and understand the risk:\n" >&2
    printf "    pyve --init --allow-synced-dir\n" >&2
    exit 1
}

#============================================================
# Install Source Detection
#============================================================

# Detect how pyve was installed.
# Prints one of: homebrew, installed, source
# Requires SCRIPT_DIR and TARGET_BIN_DIR to be set.
detect_install_source() {
    if command -v brew >/dev/null 2>&1; then
        local brew_prefix
        brew_prefix="$(brew --prefix 2>/dev/null)"
        if [[ "$SCRIPT_DIR" == "$brew_prefix"/* ]]; then
            echo "homebrew"
            return 0
        fi
    fi
    if [[ "$SCRIPT_DIR" == "$TARGET_BIN_DIR" ]]; then
        echo "installed"
    else
        echo "source"
    fi
}

#============================================================
# File Utilities
#============================================================

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
