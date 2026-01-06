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

VERSION="0.7.12"
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

if [[ -f "$SCRIPT_DIR/lib/micromamba_core.sh" ]]; then
    source "$SCRIPT_DIR/lib/micromamba_core.sh"
else
    printf "ERROR: Cannot find lib/micromamba_core.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/micromamba_bootstrap.sh" ]]; then
    source "$SCRIPT_DIR/lib/micromamba_bootstrap.sh"
else
    printf "ERROR: Cannot find lib/micromamba_bootstrap.sh\n" >&2
    exit 1
fi

if [[ -f "$SCRIPT_DIR/lib/micromamba_env.sh" ]]; then
    source "$SCRIPT_DIR/lib/micromamba_env.sh"
else
    printf "ERROR: Cannot find lib/micromamba_env.sh\n" >&2
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
                [--auto-bootstrap] [--bootstrap-to <location>] [--strict]
                [--env-name <name>] [--no-direnv]
    pyve run <command> [args...]
    pyve doctor
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
                        Optional: --auto-bootstrap to install micromamba without prompting
                        Optional: --bootstrap-to <location> where to install (project, user)
                        Optional: --strict to error on stale/missing lock files
                        Optional: --env-name <name> to specify environment name (micromamba)
                        Optional: --no-direnv to skip .envrc creation (for CI/CD)
                        Optional: --local-env to copy ~/.local/.env template

    run                 Run a command in the active environment
                        Automatically detects backend (venv or micromamba)
                        Passes all arguments to the command
                        Preserves exit codes

    doctor              Check environment health and show diagnostics
                        Reports backend, Python version, packages, and status
                        Detects issues with lock files and configuration

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
    pyve --init --no-direnv              # Skip direnv (for CI/CD)
    pyve run python --version            # Run command in environment
    pyve run pytest                      # Run tests in environment
    pyve run python script.py            # Run script in environment
    pyve doctor                          # Check environment health
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
    
    # Check micromamba status
    local micromamba_status="not found"
    local micromamba_location=""
    local micromamba_version=""
    if check_micromamba_available; then
        micromamba_location="$(get_micromamba_location)"
        micromamba_version="$(get_micromamba_version)"
        micromamba_status="available ($micromamba_location)"
        if [[ -n "$micromamba_version" ]]; then
            micromamba_status="$micromamba_status v$micromamba_version"
        fi
    fi
    
    # Check environment file
    local env_file_status="none"
    local env_file
    env_file="$(detect_environment_file 2>/dev/null)" || true
    if [[ -n "$env_file" ]]; then
        env_file_status="$env_file"
        # Add environment name if available
        if [[ "$env_file" == "environment.yml" ]]; then
            local env_name
            env_name="$(parse_environment_name "$env_file" 2>/dev/null)" || true
            if [[ -n "$env_name" ]]; then
                env_file_status="$env_file (name: $env_name)"
            fi
        fi
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
    printf "  Micromamba:             %s\n" "$micromamba_status"
    printf "  Conda env file:         %s\n" "$env_file_status"
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
    local auto_bootstrap=false
    local bootstrap_to="user"
    local strict_mode=false
    local env_name_flag=""
    local no_direnv=false
    
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
            --auto-bootstrap)
                auto_bootstrap=true
                shift
                ;;
            --bootstrap-to)
                if [[ -z "${2:-}" ]]; then
                    log_error "--bootstrap-to requires a location (project, user)"
                    exit 1
                fi
                bootstrap_to="$2"
                if [[ "$bootstrap_to" != "project" ]] && [[ "$bootstrap_to" != "user" ]]; then
                    log_error "Invalid --bootstrap-to value: $bootstrap_to"
                    log_error "Must be 'project' or 'user'"
                    exit 1
                fi
                shift 2
                ;;
            --strict)
                strict_mode=true
                shift
                ;;
            --env-name)
                if [[ -z "${2:-}" ]]; then
                    log_error "--env-name requires an environment name"
                    exit 1
                fi
                env_name_flag="$2"
                shift 2
                ;;
            --no-direnv)
                no_direnv=true
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
    
    # Check if micromamba backend is selected and handle bootstrap
    if [[ "$backend" == "micromamba" ]]; then
        # Check if micromamba is available
        if ! check_micromamba_available; then
            # Micromamba not found - offer bootstrap
            if [[ "$auto_bootstrap" == true ]]; then
                # Auto-bootstrap mode (non-interactive)
                if ! bootstrap_micromamba_auto "$bootstrap_to"; then
                    exit 1
                fi
            else
                # Interactive bootstrap prompt
                local context="Detected: environment.yml\nRequired: micromamba"
                if ! bootstrap_micromamba_interactive "$context"; then
                    exit 1
                fi
            fi
        fi
        
        # At this point, micromamba should be available
        if ! check_micromamba_available; then
            log_error "Micromamba still not available after bootstrap attempt"
            exit 1
        fi
        
        # Validate lock file status if micromamba backend
        if ! validate_lock_file_status "$strict_mode"; then
            exit 1
        fi
        
        # Resolve and validate environment name
        local env_name
        env_name="$(resolve_environment_name "$env_name_flag")"
        if ! validate_environment_name "$env_name"; then
            exit 1
        fi
        log_info "Environment name: $env_name"
        
        # Validate environment file
        if ! validate_environment_file; then
            exit 1
        fi
        
        # Create micromamba environment
        printf "\nInitializing micromamba environment...\n"
        printf "  Backend:         micromamba\n"
        printf "  Environment:     %s\n" "$env_name"
        
        local env_file
        env_file="$(detect_environment_file)"
        printf "  Using file:      %s\n" "$env_file"
        
        if ! create_micromamba_env "$env_name" "$env_file"; then
            exit 1
        fi
        
        # Verify environment
        if ! verify_micromamba_env "$env_name"; then
            log_warning "Environment created but verification failed"
        fi
        
        # Configure direnv for micromamba (unless --no-direnv)
        local env_path=".pyve/envs/$env_name"
        if [[ "$no_direnv" == false ]]; then
            init_direnv_micromamba "$env_name" "$env_path"
        else
            log_info "Skipping .envrc creation (--no-direnv)"
        fi
        
        # Create .env file
        init_dotenv "$use_local_env"
        
        # Update .gitignore
        append_pattern_to_gitignore ".pyve/envs"
        append_pattern_to_gitignore "$ENV_FILE_NAME"
        append_pattern_to_gitignore ".envrc"
        if [[ "$(uname)" == "Darwin" ]]; then
            append_pattern_to_gitignore ".DS_Store"
        fi
        log_success "Updated .gitignore"
        
        printf "\n✓ Micromamba environment initialized successfully!\n"
        printf "\nEnvironment location: %s\n" "$env_path"
        printf "\nNext steps:\n"
        if [[ "$no_direnv" == false ]]; then
            printf "  1. Run 'direnv allow' to activate the environment\n"
            printf "  2. Or use: pyve run <command>\n"
        else
            printf "  Use: pyve run <command> to execute in environment\n"
        fi
        
        return 0
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
    
    # Configure direnv (unless --no-direnv)
    if [[ "$no_direnv" == false ]]; then
        init_direnv_venv "$venv_dir"
    else
        log_info "Skipping .envrc creation (--no-direnv)"
    fi
    
    # Create .env file
    init_dotenv "$use_local_env"
    
    # Update .gitignore
    init_gitignore "$venv_dir"
    
    printf "\n✓ Python environment initialized successfully!\n"
    if [[ "$no_direnv" == false ]]; then
        printf "\nNext step: Run 'direnv allow' to activate the environment.\n"
    else
        printf "\nUse 'pyve run <command>' to execute commands in the environment.\n"
    fi
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

init_direnv_venv() {
    local venv_dir="$1"
    local envrc_file=".envrc"
    
    if [[ -f "$envrc_file" ]]; then
        log_info ".envrc already exists, skipping"
    else
        # Get project name for prompt
        local project_name
        project_name="$(basename "$(pwd)")"
        
        # Create .envrc with dynamic path resolution and prompt
        cat > "$envrc_file" << EOF
# pyve-managed direnv configuration
# Activates Python virtual environment and loads .env

VENV_DIR="$venv_dir"

if [[ -d "\$VENV_DIR" ]]; then
    source "\$VENV_DIR/bin/activate"
    # Update prompt to show backend and environment
    export PS1="(venv:$project_name) \$PS1"
fi

if [[ -f ".env" ]]; then
    dotenv
fi
EOF
        log_success "Created .envrc"
    fi
}

init_direnv_micromamba() {
    local env_name="$1"
    local env_path="$2"
    local envrc_file=".envrc"
    
    if [[ -f "$envrc_file" ]]; then
        log_info ".envrc already exists, skipping"
    else
        # Create .envrc for micromamba with prompt
        cat > "$envrc_file" << EOF
# pyve-managed direnv configuration
# Activates micromamba environment and loads .env

ENV_NAME="$env_name"
ENV_PATH="$env_path"

# Activate micromamba environment
if [[ -d "\$ENV_PATH" ]]; then
    # Add environment bin to PATH
    export PATH="\$ENV_PATH/bin:\$PATH"
    # Update prompt to show backend and environment
    export PS1="(micromamba:\$ENV_NAME) \$PS1"
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
# Run Command
#============================================================

run_command() {
    if [[ $# -lt 1 ]]; then
        log_error "No command provided to run"
        log_error "Usage: pyve run <command> [args...]"
        log_error "Example: pyve run python --version"
        exit 1
    fi
    
    # Detect active backend by checking what exists
    local backend=""
    local venv_dir="$DEFAULT_VENV_DIR"
    
    # Check for micromamba environment first
    if [[ -d ".pyve/envs" ]]; then
        # Find the first environment directory
        local env_dirs=(.pyve/envs/*)
        if [[ -d "${env_dirs[0]}" ]] && [[ "${env_dirs[0]}" != ".pyve/envs/*" ]]; then
            backend="micromamba"
        fi
    fi
    
    # Check for venv if micromamba not found
    if [[ -z "$backend" ]] && [[ -d "$venv_dir" ]]; then
        backend="venv"
    fi
    
    # Error if no environment found
    if [[ -z "$backend" ]]; then
        log_error "No Python environment found"
        log_error "Run 'pyve --init' to create an environment first"
        exit 1
    fi
    
    # Execute command based on backend
    if [[ "$backend" == "venv" ]]; then
        # Venv backend: execute directly from venv bin
        local cmd_path="$venv_dir/bin/$1"
        
        if [[ ! -x "$cmd_path" ]]; then
            log_error "Command not found in venv: $1"
            log_error "Environment: $venv_dir"
            exit 127
        fi
        
        # Execute command with remaining arguments
        shift
        exec "$cmd_path" "$@"
        
    elif [[ "$backend" == "micromamba" ]]; then
        # Micromamba backend: use micromamba run
        
        # Get micromamba path
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -z "$micromamba_path" ]]; then
            log_error "Micromamba not found"
            exit 1
        fi
        
        # Find environment directory
        local env_dirs=(.pyve/envs/*)
        local env_path="${env_dirs[0]}"
        
        if [[ ! -d "$env_path" ]]; then
            log_error "Micromamba environment not found"
            exit 1
        fi
        
        # Execute command using micromamba run
        exec "$micromamba_path" run -p "$env_path" "$@"
    fi
}

#============================================================
# Doctor Command
#============================================================

doctor_command() {
    printf "\nPyve Environment Diagnostics\n"
    printf "=============================\n\n"
    
    # Detect active backend
    local backend=""
    local venv_dir="$DEFAULT_VENV_DIR"
    local env_path=""
    local env_name=""
    
    # Check for micromamba environment first
    if [[ -d ".pyve/envs" ]]; then
        local env_dirs=(.pyve/envs/*)
        if [[ -d "${env_dirs[0]}" ]] && [[ "${env_dirs[0]}" != ".pyve/envs/*" ]]; then
            backend="micromamba"
            env_path="${env_dirs[0]}"
            env_name="$(basename "$env_path")"
        fi
    fi
    
    # Check for venv if micromamba not found
    if [[ -z "$backend" ]] && [[ -d "$venv_dir" ]]; then
        backend="venv"
        env_path="$venv_dir"
    fi
    
    # Check if no environment found
    if [[ -z "$backend" ]]; then
        printf "✗ No environment found\n"
        printf "  Run 'pyve --init' to create an environment\n"
        exit 1
    fi
    
    # Report backend
    printf "✓ Backend: %s\n" "$backend"
    
    # Backend-specific checks
    if [[ "$backend" == "micromamba" ]]; then
        # Check micromamba binary
        if check_micromamba_available; then
            local mm_path
            mm_path="$(get_micromamba_path)"
            local mm_version
            mm_version="$(get_micromamba_version)"
            local mm_location
            mm_location="$(get_micromamba_location)"
            printf "✓ Micromamba: %s (%s) v%s\n" "$mm_path" "$mm_location" "$mm_version"
        else
            printf "✗ Micromamba: not found\n"
        fi
        
        # Check environment
        if [[ -d "$env_path" ]]; then
            printf "✓ Environment: %s\n" "$env_path"
            printf "  Name: %s\n" "$env_name"
        else
            printf "✗ Environment: not found\n"
        fi
        
        # Check Python in environment
        if [[ -f "$env_path/bin/python" ]]; then
            local py_version
            py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
            printf "✓ Python: %s\n" "$py_version"
        else
            printf "⚠ Python: not found in environment\n"
        fi
        
        # Check environment file
        local env_file
        env_file="$(detect_environment_file 2>/dev/null)" || true
        if [[ -n "$env_file" ]]; then
            printf "✓ Environment file: %s\n" "$env_file"
            
            # Check lock file status if environment.yml exists
            if [[ "$env_file" == "environment.yml" ]] || [[ -f "environment.yml" ]]; then
                if [[ -f "conda-lock.yml" ]]; then
                    if is_lock_file_stale; then
                        printf "⚠ Lock file: conda-lock.yml (stale)\n"
                        local env_mtime
                        local lock_mtime
                        env_mtime="$(get_file_mtime_formatted "environment.yml")"
                        lock_mtime="$(get_file_mtime_formatted "conda-lock.yml")"
                        printf "  environment.yml: %s\n" "$env_mtime"
                        printf "  conda-lock.yml:  %s\n" "$lock_mtime"
                    else
                        printf "✓ Lock file: conda-lock.yml (up to date)\n"
                    fi
                else
                    printf "⚠ Lock file: missing\n"
                    printf "  Generate with: conda-lock -f environment.yml\n"
                fi
            fi
        else
            printf "⚠ Environment file: not found\n"
        fi
        
        # Count packages
        if [[ -d "$env_path/conda-meta" ]]; then
            local pkg_count
            pkg_count=$(find "$env_path/conda-meta" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
            printf "  Packages: %s installed\n" "$pkg_count"
        fi
        
    elif [[ "$backend" == "venv" ]]; then
        # Check venv directory
        if [[ -d "$env_path" ]]; then
            printf "✓ Environment: %s\n" "$env_path"
        else
            printf "✗ Environment: not found\n"
        fi
        
        # Check Python in venv
        if [[ -f "$env_path/bin/python" ]]; then
            local py_version
            py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
            printf "✓ Python: %s\n" "$py_version"
        else
            printf "✗ Python: not found in venv\n"
        fi
        
        # Check Python version file
        if [[ -f ".tool-versions" ]]; then
            local version_manager="asdf"
            local py_ver
            py_ver="$(grep "^python " .tool-versions | awk '{print $2}')"
            printf "✓ Version file: .tool-versions (asdf)\n"
            printf "  Python: %s\n" "$py_ver"
        elif [[ -f ".python-version" ]]; then
            local version_manager="pyenv"
            local py_ver
            py_ver="$(cat .python-version)"
            printf "✓ Version file: .python-version (pyenv)\n"
            printf "  Python: %s\n" "$py_ver"
        else
            printf "⚠ Version file: not found\n"
        fi
        
        # Count packages in venv
        if [[ -d "$env_path/lib" ]]; then
            local site_packages
            site_packages=$(find "$env_path/lib" -type d -name "site-packages" 2>/dev/null | head -1)
            if [[ -n "$site_packages" ]]; then
                local pkg_count
                pkg_count=$(find "$site_packages" -maxdepth 1 -name "*.dist-info" 2>/dev/null | wc -l | tr -d ' ')
                printf "  Packages: %s installed\n" "$pkg_count"
            fi
        fi
    fi
    
    # Check direnv
    if [[ -f ".envrc" ]]; then
        printf "✓ Direnv: .envrc configured\n"
    else
        printf "⚠ Direnv: .envrc not found\n"
        printf "  Use 'pyve run' to execute commands\n"
    fi
    
    # Check .env file
    if [[ -f ".env" ]]; then
        if is_file_empty ".env"; then
            printf "✓ Environment file: .env (empty)\n"
        else
            printf "✓ Environment file: .env (configured)\n"
        fi
    else
        printf "⚠ Environment file: .env not found\n"
    fi
    
    printf "\n"
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
        run)
            shift
            run_command "$@"
            ;;
        doctor)
            doctor_command
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
