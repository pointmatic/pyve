#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
#
#============================================================
# pyve - Python Virtual Environment Manager
#
# A focused tool for setting up Python virtual environments on macOS and Linux.
# Manages Python versions (via asdf or pyenv), virtual environments, and direnv.
#
# Usage: pyve {--init | --purge | --python-version | --install | --uninstall | --help | --version | --config}
#============================================================

set -euo pipefail

#============================================================
# Configuration
#============================================================

VERSION="0.7.1"
DEFAULT_PYTHON_VERSION="3.14.2"
DEFAULT_VENV_DIR=".venv"
ENV_FILE_NAME=".env"

# Installation paths
TARGET_BIN_DIR="$HOME/.local/bin"
TARGET_SCRIPT_PATH="$TARGET_BIN_DIR/pyve.sh"
TARGET_SYMLINK_PATH="$TARGET_BIN_DIR/pyve"
LOCAL_ENV_FILE="$HOME/.local/.env"
SOURCE_DIR_FILE="$HOME/.local/.pyve_source"

#============================================================
# Resolve Script Directory and Source Libraries
#============================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper libraries
if [[ -f "$SCRIPT_DIR/lib/utils.sh" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
else
    printf "ERROR: Cannot find lib/utils.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/env_detect.sh" ]]; then
    source "$SCRIPT_DIR/lib/env_detect.sh"
else
    printf "ERROR: Cannot find lib/env_detect.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/backend_detect.sh" ]]; then
    source "$SCRIPT_DIR/lib/backend_detect.sh"
else
    printf "ERROR: Cannot find lib/backend_detect.sh\n" >&2
    exit 1
fi

#============================================================
# Help and Information Commands
#============================================================

show_help() {
    cat << 'EOF'
pyve - Python Virtual Environment Manager

USAGE:
    pyve --init [<dir>] [--python-version <ver>] [--backend <type>] [--local-env]
    pyve --purge [<dir>]
    pyve --python-version <ver>
    pyve --install
    pyve --uninstall
    pyve --help | --version | --config

COMMANDS:
    --init, -i          Initialize Python virtual environment in current directory
                        Optional: specify custom venv directory name (default: .venv)
                        Optional: --python-version <ver> to set Python version
                        Optional: --backend <type> to specify backend (venv, micromamba, auto)
                        Optional: --local-env to copy ~/.local/.env template

    --purge, -p         Remove all Python environment artifacts
                        Optional: specify custom venv directory name (default: .venv)

    --python-version    Set Python version without creating virtual environment
                        Format: #.#.# (e.g., 3.13.7)

    --install           Install pyve to ~/.local/bin

    --uninstall         Remove pyve from ~/.local/bin

    --help, -h          Show this help message

    --version, -v       Show version

    --config, -c        Show current configuration

EXAMPLES:
    pyve --init                          # Initialize with defaults (auto-detect backend)
    pyve --init myenv                    # Use custom venv directory
    pyve --init --python-version 3.12.0  # Specify Python version
    pyve --init --backend venv           # Explicitly use venv backend
    pyve --init --backend micromamba     # Explicitly use micromamba backend
    pyve --init --local-env              # Copy ~/.local/.env template
    pyve --purge                         # Remove environment
    pyve --python-version 3.13.7         # Set Python version only

REQUIREMENTS:
    - asdf (recommended) or pyenv for Python version management
    - direnv for automatic environment activation
EOF
}

show_version() {
    printf "pyve version %s\n" "$VERSION"
}

show_config() {
    local detected_backend
    detected_backend="$(detect_backend_from_files)"
    
    local config_backend=""
    local config_exists="no"
    if config_file_exists; then
        config_exists="yes"
        config_backend="$(read_config_value "backend")"
    fi
    
    printf "pyve configuration:\n"
    printf "  Version:                %s\n" "$VERSION"
    printf "  Default Python version: %s\n" "$DEFAULT_PYTHON_VERSION"
    printf "  Default venv directory: %s\n" "$DEFAULT_VENV_DIR"
    printf "  Default backend:        venv\n"
    printf "  Config file (.pyve/config): %s\n" "$config_exists"
    if [[ "$config_exists" == "yes" ]] && [[ -n "$config_backend" ]]; then
        printf "  Config backend:         %s\n" "$config_backend"
    fi
    printf "  Detected backend:       %s\n" "$detected_backend"
    printf "  Environment file:       %s\n" "$ENV_FILE_NAME"
    printf "  Install directory:      %s\n" "$TARGET_BIN_DIR"
}

#============================================================
# Init Command
#============================================================

init() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local python_version="$DEFAULT_PYTHON_VERSION"
    local use_local_env=false
    local backend_flag=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --python-version)
                if [[ -z "${2:-}" ]]; then
                    log_error "--python-version requires a version argument"
                    exit 1
                fi
                python_version="$2"
                shift 2
                ;;
            --backend)
                if [[ -z "${2:-}" ]]; then
                    log_error "--backend requires a backend type (venv, micromamba, auto)"
                    exit 1
                fi
                backend_flag="$2"
                shift 2
                ;;
            --local-env)
                use_local_env=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done
    
    # Validate backend if specified
    if [[ -n "$backend_flag" ]]; then
        if ! validate_backend "$backend_flag"; then
            exit 1
        fi
    fi
    
    # Determine backend to use
    local backend
    backend="$(get_backend_priority "$backend_flag")"
    
    # For now, only venv backend is fully implemented
    if [[ "$backend" != "venv" ]]; then
        log_error "Backend '$backend' is not yet fully implemented"
        log_error "Currently only 'venv' backend is supported"
        log_error "Micromamba support coming in v0.7.1-v0.7.12"
        exit 1
    fi
    
    # Validate inputs
    if ! validate_venv_dir_name "$venv_dir"; then
        exit 1
    fi
    
    if ! validate_python_version "$python_version"; then
        exit 1
    fi
    
    printf "\nInitializing Python environment...\n"
    printf "  Backend:        %s\n" "$backend"
    printf "  Python version: %s\n" "$python_version"
    printf "  Venv directory: %s\n" "$venv_dir"
    
    # Source shell profiles to find version managers
    source_shell_profiles
    
    # Detect and validate version manager
    if ! detect_version_manager; then
        exit 1
    fi
    log_info "Using $VERSION_MANAGER for Python version management"
    
    # Check direnv
    if ! check_direnv_installed; then
        exit 1
    fi
    
    # Ensure Python version is installed
    if ! ensure_python_version_installed "$python_version"; then
        exit 1
    fi
    
    # Set local Python version
    init_python_version "$python_version"
    
    # Create virtual environment
    init_venv "$venv_dir"
    
    # Configure direnv
    init_direnv "$venv_dir"
    
    # Create .env file
    init_dotenv "$use_local_env"
    
    # Update .gitignore
    init_gitignore "$venv_dir"
    
    printf "\n✓ Python environment initialized successfully!\n"
    printf "\nNext step: Run 'direnv allow' to activate the environment.\n"
}

init_python_version() {
    local version="$1"
    local version_file
    version_file="$(get_version_file_name)"
    
    if [[ -f "$version_file" ]]; then
        log_info "$version_file already exists, skipping"
    else
        set_local_python_version "$version"
        log_success "Created $version_file with Python $version"
    fi
}

init_venv() {
    local venv_dir="$1"
    
    if [[ -d "$venv_dir" ]]; then
        log_info "Virtual environment '$venv_dir' already exists, skipping"
    else
        log_info "Creating virtual environment in '$venv_dir'..."
        python -m venv "$venv_dir"
        log_success "Created virtual environment"
    fi
}

init_direnv() {
    local venv_dir="$1"
    local envrc_file=".envrc"
    
    if [[ -f "$envrc_file" ]]; then
        log_info ".envrc already exists, skipping"
    else
        # Create .envrc with dynamic path resolution
        cat > "$envrc_file" << EOF
# pyve-managed direnv configuration
# Activates Python virtual environment and loads .env

VENV_DIR="$venv_dir"

if [[ -d "\$VENV_DIR" ]]; then
    source "\$VENV_DIR/bin/activate"
fi

if [[ -f ".env" ]]; then
    dotenv
fi
EOF
        log_success "Created .envrc"
    fi
}

init_dotenv() {
    local use_local_env="$1"
    
    if [[ -f "$ENV_FILE_NAME" ]]; then
        log_info "$ENV_FILE_NAME already exists, skipping"
        return
    fi
    
    if [[ "$use_local_env" == true ]] && [[ -f "$LOCAL_ENV_FILE" ]]; then
        cp "$LOCAL_ENV_FILE" "$ENV_FILE_NAME"
        log_success "Copied $LOCAL_ENV_FILE to $ENV_FILE_NAME"
    else
        touch "$ENV_FILE_NAME"
        if [[ "$use_local_env" == true ]]; then
            log_warning "$LOCAL_ENV_FILE not found, created empty $ENV_FILE_NAME"
        else
            log_success "Created empty $ENV_FILE_NAME"
        fi
    fi
    
    # Set secure permissions
    chmod 600 "$ENV_FILE_NAME"
}

init_gitignore() {
    local venv_dir="$1"
    
    # Add patterns to .gitignore
    append_pattern_to_gitignore "$venv_dir"
    append_pattern_to_gitignore "$ENV_FILE_NAME"
    append_pattern_to_gitignore ".envrc"
    
    # Add .DS_Store on macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        append_pattern_to_gitignore ".DS_Store"
    fi
    
    log_success "Updated .gitignore"
}

#============================================================
# Purge Command
#============================================================

purge() {
    local venv_dir="$DEFAULT_VENV_DIR"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done
    
    printf "\nPurging Python environment artifacts...\n"
    
    # Source shell profiles to detect version manager
    source_shell_profiles
    detect_version_manager 2>/dev/null || true
    
    # Remove version file
    purge_version_file
    
    # Remove virtual environment
    purge_venv "$venv_dir"
    
    # Remove .envrc
    purge_envrc
    
    # Remove .env (only if empty - v0.6.0 smart purge)
    purge_dotenv
    
    # Clean .gitignore
    purge_gitignore "$venv_dir"
    
    printf "\n✓ Python environment artifacts removed.\n"
}

purge_version_file() {
    local version_file
    
    # Try to remove both possible version files
    for version_file in ".tool-versions" ".python-version"; do
        if [[ -f "$version_file" ]]; then
            rm -f "$version_file"
            log_success "Removed $version_file"
        fi
    done
}

purge_venv() {
    local venv_dir="$1"
    
    if [[ -d "$venv_dir" ]]; then
        rm -rf "$venv_dir"
        log_success "Removed $venv_dir"
    else
        log_info "No virtual environment found at '$venv_dir'"
    fi
}

purge_envrc() {
    if [[ -f ".envrc" ]]; then
        rm -f ".envrc"
        log_success "Removed .envrc"
    fi
}

purge_dotenv() {
    if [[ -f "$ENV_FILE_NAME" ]]; then
        if is_file_empty "$ENV_FILE_NAME"; then
            rm -f "$ENV_FILE_NAME"
            log_success "Removed $ENV_FILE_NAME (was empty)"
        else
            log_warning "$ENV_FILE_NAME preserved (contains data). Delete manually if desired."
        fi
    fi
}

purge_gitignore() {
    local venv_dir="$1"
    
    if [[ -f ".gitignore" ]]; then
        remove_pattern_from_gitignore "$venv_dir"
        remove_pattern_from_gitignore "$ENV_FILE_NAME"
        remove_pattern_from_gitignore ".envrc"
        log_success "Cleaned .gitignore"
    fi
}

#============================================================
# Python Version Command
#============================================================

set_python_version_only() {
    if [[ $# -lt 1 ]]; then
        log_error "--python-version requires a version argument"
        log_error "Usage: pyve --python-version <version>"
        log_error "Example: pyve --python-version 3.13.7"
        exit 1
    fi
    
    local version="$1"
    
    if ! validate_python_version "$version"; then
        exit 1
    fi
    
    printf "\nSetting Python version to %s...\n" "$version"
    
    # Source shell profiles to find version managers
    source_shell_profiles
    
    # Detect version manager
    if ! detect_version_manager; then
        exit 1
    fi
    
    # Ensure version is installed
    if ! ensure_python_version_installed "$version"; then
        exit 1
    fi
    
    # Set local version
    set_local_python_version "$version"
    
    local version_file
    version_file="$(get_version_file_name)"
    log_success "Set Python $version in $version_file"
}

#============================================================
# Install Command
#============================================================

install_self() {
    local source_dir="$SCRIPT_DIR"
    
    # If running from installed location, read source dir from config
    if [[ "$SCRIPT_DIR" == "$TARGET_BIN_DIR" ]]; then
        if [[ -f "$SOURCE_DIR_FILE" ]]; then
            source_dir="$(cat "$SOURCE_DIR_FILE")"
            if [[ ! -d "$source_dir" ]] || [[ ! -f "$source_dir/pyve.sh" ]]; then
                log_error "Source directory no longer exists: $source_dir"
                log_error "Please run --install from the original pyve source directory."
                exit 1
            fi
        else
            log_error "Cannot reinstall: source directory not recorded."
            log_error "Please run --install from the original pyve source directory."
            exit 1
        fi
    fi
    
    printf "\nInstalling pyve to %s...\n" "$TARGET_BIN_DIR"
    printf "Source: %s\n" "$source_dir"
    
    # Create target directory if needed
    if [[ ! -d "$TARGET_BIN_DIR" ]]; then
        mkdir -p "$TARGET_BIN_DIR"
        log_success "Created $TARGET_BIN_DIR"
    fi
    
    # Copy script
    cp "$source_dir/pyve.sh" "$TARGET_SCRIPT_PATH"
    chmod +x "$TARGET_SCRIPT_PATH"
    log_success "Installed pyve.sh"
    
    # Copy lib directory
    if [[ -d "$source_dir/lib" ]]; then
        mkdir -p "$TARGET_BIN_DIR/lib"
        cp "$source_dir/lib/"*.sh "$TARGET_BIN_DIR/lib/"
        log_success "Installed lib/ helpers"
    fi
    
    # Save source directory for future reinstalls
    mkdir -p "$(dirname "$SOURCE_DIR_FILE")"
    printf "%s\n" "$source_dir" > "$SOURCE_DIR_FILE"
    log_success "Recorded source directory"
    
    # Create symlink
    if [[ -L "$TARGET_SYMLINK_PATH" ]] || [[ -f "$TARGET_SYMLINK_PATH" ]]; then
        rm -f "$TARGET_SYMLINK_PATH"
    fi
    ln -s "$TARGET_SCRIPT_PATH" "$TARGET_SYMLINK_PATH"
    log_success "Created symlink: pyve -> pyve.sh"
    
    # Add to PATH if needed
    install_update_path
    
    # Create local .env template
    install_local_env_template
    
    printf "\n✓ pyve installed successfully!\n"
    printf "\nYou may need to restart your shell or run:\n"
    printf "  source ~/.zprofile  # or ~/.bash_profile\n"
}

install_update_path() {
    local profile_file
    local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\"  # Added by pyve installer"
    
    # Determine profile file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        profile_file="$HOME/.zprofile"
    else
        profile_file="$HOME/.bash_profile"
    fi
    
    # Check if already in PATH
    if [[ ":$PATH:" == *":$TARGET_BIN_DIR:"* ]]; then
        log_info "$TARGET_BIN_DIR already in PATH"
        return
    fi
    
    # Check if line already in profile
    if [[ -f "$profile_file" ]] && grep -qF "# Added by pyve installer" "$profile_file"; then
        log_info "PATH already configured in $profile_file"
        return
    fi
    
    # Add to profile
    printf "\n%s\n" "$path_line" >> "$profile_file"
    log_success "Added $TARGET_BIN_DIR to PATH in $profile_file"
}

install_local_env_template() {
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        log_info "$LOCAL_ENV_FILE already exists"
        return
    fi
    
    # Create directory if needed
    mkdir -p "$(dirname "$LOCAL_ENV_FILE")"
    
    # Create empty template with secure permissions
    touch "$LOCAL_ENV_FILE"
    chmod 600 "$LOCAL_ENV_FILE"
    log_success "Created $LOCAL_ENV_FILE template"
}

#============================================================
# Uninstall Command
#============================================================

uninstall_self() {
    printf "\nUninstalling pyve...\n"
    
    # Remove symlink
    if [[ -L "$TARGET_SYMLINK_PATH" ]]; then
        rm -f "$TARGET_SYMLINK_PATH"
        log_success "Removed symlink: $TARGET_SYMLINK_PATH"
    fi
    
    # Remove script
    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        rm -f "$TARGET_SCRIPT_PATH"
        log_success "Removed $TARGET_SCRIPT_PATH"
    fi
    
    # Remove lib directory
    if [[ -d "$TARGET_BIN_DIR/lib" ]]; then
        rm -rf "$TARGET_BIN_DIR/lib"
        log_success "Removed $TARGET_BIN_DIR/lib"
    fi
    
    # Remove local .env template (only if empty)
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        if is_file_empty "$LOCAL_ENV_FILE"; then
            rm -f "$LOCAL_ENV_FILE"
            log_success "Removed $LOCAL_ENV_FILE (was empty)"
        else
            log_warning "$LOCAL_ENV_FILE preserved (contains data). Delete manually if desired."
        fi
    fi
    
    # Remove source directory file
    if [[ -f "$SOURCE_DIR_FILE" ]]; then
        rm -f "$SOURCE_DIR_FILE"
        log_success "Removed $SOURCE_DIR_FILE"
    fi
    
    # Remove PATH from profile (v0.6.1 feature)
    uninstall_clean_path
    
    printf "\n✓ pyve uninstalled.\n"
}

uninstall_clean_path() {
    local profile_files=(
        "$HOME/.zprofile"
        "$HOME/.bash_profile"
    )
    
    local profile_file
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]]; then
            # Remove the line added by pyve installer
            if grep -qF "# Added by pyve installer" "$profile_file"; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' '/# Added by pyve installer/d' "$profile_file"
                else
                    sed -i '/# Added by pyve installer/d' "$profile_file"
                fi
                log_success "Removed PATH entry from $profile_file"
            fi
        fi
    done
}

#============================================================
# Main Entry Point
#============================================================

main() {
    # No arguments - show help
    if [[ $# -eq 0 ]]; then
        log_error "No command provided."
        show_help
        exit 1
    fi
    
    # Parse command
    case "$1" in
        --help|-h)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        --config|-c)
            show_config
            ;;
        --init|-i)
            shift
            init "$@"
            ;;
        --purge|-p)
            shift
            purge "$@"
            ;;
        --python-version)
            shift
            set_python_version_only "$@"
            ;;
        --install)
            install_self
            ;;
        --uninstall)
            uninstall_self
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
