#!/usr/bin/env zsh
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
# 
#============================================================================================================================================================================================
#
# This script is designed to set up a Python virtual environment in the current directory for MacOS using Z shell.
# In the future, it may support Bash, Linux, and other shells, depending on interest.
#
# Name: pyve.sh
# Usage: ~/pyve.sh {--init [<directory_name>] [--python-version <python_version>] [--local-env] | --python-version <python_version> | --purge [<directory_name>] | --install | --uninstall | --update | --upgrade | --clear-status <operation> | --list | --add <package> | --remove <package> | --help | --version | --config }
# Description:
# There are fourteen functions:
#   1. --init / -i: Initialize the Python virtual environment 
#      NOTE: --python-version is optional
#      FORMAT: #.#.#, example 3.13.7
#   2. --python-version <ver>: Set the Python version in the current directory without creating a virtual environment
#   3. --purge / -p: Delete all the artifacts of the Python virtual environment
#   4. --install: Install this script to $HOME/.local/bin and create a 'pyve' symlink; also record repo path and install latest documentation templates to ~/.pyve/templates/{latest}
#   5. --uninstall: Remove the installed script and 'pyve' symlink from $HOME/.local/bin
#   6. --update: Update documentation templates from the Pyve source repo to ~/.pyve/templates/{newer_version}
#   7. --upgrade: Upgrade the local git repository documentation templates to a newer version from ~/.pyve/templates/
#   8. --clear-status <operation>: Clear status after manual merge (operation: init | upgrade)
#   9. --list: List available and installed documentation packages
#   10. --add <package>: Add a documentation package (e.g., web, persistence, infrastructure)
#   11. --remove <package>: Remove a documentation package
#   12. --help / -h: Show this help message
#   13. --version / -v: Show the version of this script
#   14. --config / -c: Show the configuration of this script
#   Neither your own code nor Git is impacted by this script. This is only about setting up your Python environment.
#
#   1. --init: Initialize the Python virtural environment
#   Initializes Python environment with a sane setup
#   - Runs asdf (or if not installed, pyenv) to set Python to the default version (or the version you provide)
#   - Runs venv to configure local environment for pip packages
#     - Checks if .venv (or an provided dir name) already exists in the current directory
#   - Configures direnv 
#     - Checks if .envrc already exists in the current directory. 
#     - If it exists, exit with a warning. 
#     - Otherwise, accept one parameter <directory_name> (or nothing for default).
#       - No directory name defaults to '.venv' for the 
#         Python virtual environment config.
#     - assign <directory_name> param to VENV_DIR_NAME.
#     - write environment variables to .envrc.
#     - Supports Dotenv
#       - Creates .env file in the current directory
#       - Sets limited permissions (chmod 600) for security
#
#   2. --purge: Delete all the artifacts of the Python virtual environment
#   Deletes the Python virtual environment and all its artifacts
#   - Deletes the asdf .tool-versions or pyenv .python-version file
#   - Deletes the .venv directory (default) or <directory_name> (if provided)
#   - Deletes the .envrc file
#   - Deletes the .env file
#   - Removes the .gitignore artifacts
#
#   The other functions are self-explanatory.

# script version
VERSION="0.5.1"

# configuration constants
DEFAULT_PYTHON_VERSION="3.13.7"
#PYTHON_VERSION is based on a parameter passed to the script, decided in init_parse_args()
ASDF_FILE_NAME=".tool-versions"
USE_ASDF="true"
PYENV_FILE_NAME=".python-version"
USE_PYENV="false"
DEFAULT_VENV_DIR_NAME=".venv" 
#VENV_DIR_NAME is based on a parameter passed to the script, decided in init_parse_args()
ENV_FILE_NAME=".env"
LOCAL_ENV_FILE="$HOME/.local/.env"
DIRENV_FILE_NAME=".envrc"
GIT_DIR_NAME=".git"
GITIGNORE_FILE_NAME=".gitignore"
MAC_OS_GITIGNORE_CONTENT=".DS_Store"
# Pyve home and template locations
PYVE_HOME="$HOME/.pyve"
PYVE_SOURCE_PATH_FILE="$PYVE_HOME/source_path"
PYVE_TEMPLATES_DIR="$PYVE_HOME/templates"
PYVE_PACKAGES_CONF=".pyve/packages.conf"

# v0.5.1: Directories that Pyve owns (always overwrite, no conflict detection)
PYVE_OWNED_DIRS=(
    "docs/guides"
    "docs/context"
    "docs/guides/llm_qa"
)

# Ensure Pyve home directories exist
function ensure_pyve_home() {
    mkdir -p "$PYVE_TEMPLATES_DIR" 2>/dev/null || true
}

# v0.5.1: Check if a file path is in a Pyve-owned directory
function is_pyve_owned() {
    local FILE="$1"
    for DIR in "${PYVE_OWNED_DIRS[@]}"; do
        if [[ "$FILE" == "$DIR"/* ]]; then
            return 0  # Pyve owns this
        fi
    done
    return 1  # User owns this
}

# v0.5.0: Migrate old minor-version directories to patch-level directories
function migrate_template_directories() {
    # Migrate 0.4/ to 0.4.21/ if needed
    if [[ -d "$PYVE_TEMPLATES_DIR/v0.4" ]] && [[ ! -d "$PYVE_TEMPLATES_DIR/v0.4.21" ]]; then
        echo "Migrating templates from v0.4/ to v0.4.21/..."
        mv "$PYVE_TEMPLATES_DIR/v0.4" "$PYVE_TEMPLATES_DIR/v0.4.21"
        echo "Migration complete."
    fi
    
    # Future migrations can be added here
    # if [[ -d "$PYVE_TEMPLATES_DIR/v0.5" ]] && [[ ! -d "$PYVE_TEMPLATES_DIR/v0.5.0" ]]; then
    #     mv "$PYVE_TEMPLATES_DIR/v0.5" "$PYVE_TEMPLATES_DIR/v0.5.0"
    # fi
}

# v0.5.0: Compare two semver strings (e.g., "0.4.20" vs "0.4.21")
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
function compare_semver() {
    local v1="$1"
    local v2="$2"
    
    # Strip 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    # Split into major.minor.patch
    local v1_major=$(echo "$v1" | cut -d. -f1)
    local v1_minor=$(echo "$v1" | cut -d. -f2)
    local v1_patch=$(echo "$v1" | cut -d. -f3)
    
    local v2_major=$(echo "$v2" | cut -d. -f1)
    local v2_minor=$(echo "$v2" | cut -d. -f2)
    local v2_patch=$(echo "$v2" | cut -d. -f3)
    
    # Compare major, then minor, then patch
    if [[ $v1_major -gt $v2_major ]]; then return 1; fi
    if [[ $v1_major -lt $v2_major ]]; then return 2; fi
    if [[ $v1_minor -gt $v2_minor ]]; then return 1; fi
    if [[ $v1_minor -lt $v2_minor ]]; then return 2; fi
    if [[ $v1_patch -gt $v2_patch ]]; then return 1; fi
    if [[ $v1_patch -lt $v2_patch ]]; then return 2; fi
    return 0
}

# v0.5.0: Find latest templates version directory name (e.g., v0.5.0) under given source path
# Now supports full semver comparison instead of simple string sort
function find_latest_template_version() {
    local SOURCE_PATH="$1"
    if [[ -z "$SOURCE_PATH" || ! -d "$SOURCE_PATH/templates" ]]; then
        echo ""
        return 0
    fi
    
    local LATEST=""
    local DIR
    
    for DIR in "$SOURCE_PATH"/templates/v*; do
        [[ ! -d "$DIR" ]] && continue
        local VERSION=$(basename "$DIR")
        
        # Strip 'v' prefix for comparison
        local VERSION_NUM="${VERSION#v}"
        
        # Skip if not valid semver (e.g., .DS_Store)
        if [[ ! "$VERSION_NUM" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi
        
        if [[ -z "$LATEST" ]]; then
            LATEST="$VERSION"
        else
            compare_semver "$VERSION" "$LATEST"
            if [[ $? -eq 1 ]]; then
                LATEST="$VERSION"
            fi
        fi
    done
    
    echo "$LATEST"
}

# Record the Pyve source path (repo root) for future updates
function record_source_path() {
    local SOURCE_PATH="$1"
    ensure_pyve_home
    echo "$SOURCE_PATH" > "$PYVE_SOURCE_PATH_FILE"
    echo "Recorded Pyve source path to $PYVE_SOURCE_PATH_FILE"
}

# Copy the latest templates from the repo to ~/.pyve/templates/{latest}
function copy_latest_templates_to_home() {
    local SOURCE_PATH="$1"
    local LATEST_VERSION
    LATEST_VERSION=$(find_latest_template_version "$SOURCE_PATH")
    if [[ -z "$LATEST_VERSION" ]]; then
        echo "\nWARNING: No versioned templates found under '$SOURCE_PATH/templates'. Skipping template copy."
        return 0
    fi
    ensure_pyve_home
    local SRC_DIR="$SOURCE_PATH/templates/$LATEST_VERSION"
    local DEST_DIR="$PYVE_TEMPLATES_DIR/$LATEST_VERSION"
    echo "Copying templates from '$SRC_DIR' to '$DEST_DIR' ..."
    mkdir -p "$DEST_DIR"
    # Use rsync if available for cleaner sync, else fallback to cp -R
    if command -v rsync &> /dev/null; then
        rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
    else
        cp -R "$SRC_DIR/." "$DEST_DIR/"
    fi
    echo "Templates copied to $DEST_DIR"
}

function show_help() {
    echo "\nHELP: Pyve.sh - Python Virtual Environment Setup Script\n"
    echo "Pyve will set up a special Python virtual environment in your current directory. "
    echo "- auto-configure a version of Python (asdf or pyenv)"
    echo "- autocreate a virtual environment (python venv)"
    echo "- autoactivate and deactivate the virtual environment when you change directory (direnv)"
    echo "- auto-configure an environment variable file .env (ready for dotenv package in Python)"
    echo "- auto-configure a .gitignore file to ignore the virtual environment directory and other artifacts"
    echo "\nUsage: ~/pyve.sh {--init [<directory_name>] [--python-version <python_version>] [--local-env] [--packages <pkg1> <pkg2> ...] | --python-version <python_version> | --purge [<directory_name>] | --install | --uninstall | --update | --upgrade | --clear-status <operation> | --list | --add <package> [pkg2 ...] | --remove <package> [pkg2 ...] | --help | --version | --config}"
    echo "\nDescription:"
    echo "  --init:    Initialize Python virtual environment"
    echo "             Optional directory name (default is .venv)"
    echo "             Optional --python-version <ver> to select a specific Python version"
    echo "             Optional --local-env to copy from ~/.local/.env instead of creating empty .env"
    echo "             Optional --packages <pkg1> <pkg2> ... to install doc packages during init"
    echo "             Note: Only foundation docs are copied on init (v0.3.11+)"
    echo "  --python-version <ver>: Set only the local Python version in the current directory (no venv/direnv changes)"
    echo "  --purge:   Delete all artifacts of the Python virtual environment"
    echo "  --install: Install this script to \"$HOME/.local/bin\", ensure it's on your PATH, create a 'pyve' symlink, record the repo path, and copy the latest documentation templates to \"$HOME/.pyve/templates/{latest}\""
    echo "  --uninstall: Remove the installed script (pyve.sh) and the 'pyve' symlink from \"$HOME/.local/bin\""
    echo "  --update:  Update documentation templates from the Pyve source repo to \"$HOME/.pyve/templates/{newer_version}\""
    echo "  --upgrade: Upgrade the local git repository documentation templates to a newer version from \"$HOME/.pyve/templates/\""
    echo "  --clear-status <operation>: Clear status after manual merge (operation: init | upgrade)"
    echo "  --list:    List available and installed documentation packages with descriptions"
    echo "  --add <package> [pkg2 ...]: Add one or more documentation packages (e.g., web, persistence, infrastructure)"
    echo "  --remove <package> [pkg2 ...]: Remove one or more documentation packages"
    echo "  --help:    Show this help message"
    echo "  --version: Show the version of this script"
    echo "  --config:  Show the configuration of this script"
    echo 
}

function show_version() {
    echo "Version: $VERSION"
}

function show_config() {
    echo "Configuration:"
    echo "  Environment vars filename: .env"
    echo "  Default Python version: $DEFAULT_PYTHON_VERSION"
    echo "  Default directory name: .venv"
}

function append_pattern_to_gitignore() {
    # Check if .gitignore file is missing
    if [[ ! -f "$GITIGNORE_FILE_NAME" ]]; then
        echo "Creating .gitignore file and adding pattern '$1'..."
        echo "$1" > $GITIGNORE_FILE_NAME
    else
        # Check if the pattern is already in .gitignore
        if ! grep -q "$1" $GITIGNORE_FILE_NAME; then
            echo "$1" >> $GITIGNORE_FILE_NAME
            echo "Pattern '$1' added to $GITIGNORE_FILE_NAME."
        else
            echo "Pattern '$1' already exists in $GITIGNORE_FILE_NAME."
        fi
    fi
}

function remove_pattern_from_gitignore() {
    # Check if .gitignore file is missing
    if [[ ! -f "$GITIGNORE_FILE_NAME" ]]; then
        echo "$GITIGNORE_FILE_NAME file not found. No changes made."
        return
    else
        # Check if the pattern is in .gitignore
        if grep -q "$1" $GITIGNORE_FILE_NAME; then
            # OS-specific sed command
            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS (BSD) sed
                sed -i '' "/$1/d" $GITIGNORE_FILE_NAME
            else
                # GNU sed (Linux)
                sed -i "/$1/d" $GITIGNORE_FILE_NAME
            fi
            echo "Pattern '$1' removed from $GITIGNORE_FILE_NAME."
        else
            echo "\nFYI: Pattern '$1' does not exist in $GITIGNORE_FILE_NAME."
        fi
    fi
}

function purge_misc_artifacts() {
    # v0.4.18: Remove .pyve directory from .gitignore
    remove_pattern_from_gitignore ".pyve"
    
    # On macOS, remove special content from .gitignore
    if [[ "$(uname)" == "Darwin" ]]; then
        remove_pattern_from_gitignore "$MAC_OS_GITIGNORE_CONTENT"
    fi
}

function purge_config_dir_name() {
    # Check if a second parameter is provided
    if [[ $# -eq 2 ]]; then
        VENV_DIR_NAME="$2"
        echo "\nUsing the Venv directory you provided: $VENV_DIR_NAME"
    else
        VENV_DIR_NAME="$DEFAULT_VENV_DIR_NAME"
        echo "\nUsing the default Venv directory: $VENV_DIR_NAME"
    fi
}

function purge() {
    purge_misc_artifacts

    purge_config_dir_name "$@"

    echo "\nDeleting Python virtual environment..."
    rm -rf "$VENV_DIR_NAME"
    remove_pattern_from_gitignore "$VENV_DIR_NAME"

    if [[ -f "$ASDF_FILE_NAME" ]]; then
        echo "\nDeleting asdf $ASDF_FILE_NAME file..."
        rm -rf "$ASDF_FILE_NAME"
        remove_pattern_from_gitignore "$ASDF_FILE_NAME"
    elif [[ -f "$PYENV_FILE_NAME" ]]; then
        echo "\nDeleting pyenv $PYENV_FILE_NAME file..."
        rm -rf "$PYENV_FILE_NAME"
        remove_pattern_from_gitignore "$PYENV_FILE_NAME"
    else
        echo "\nHmmm... Neither asdf nor pyenv is configured here. No change."
    fi

    echo "\nDeleting $DIRENV_FILE_NAME file..."
    rm -f "$DIRENV_FILE_NAME"
    remove_pattern_from_gitignore "$DIRENV_FILE_NAME"

    echo "\nDeleting $ENV_FILE_NAME file..."
    rm -f "$ENV_FILE_NAME"
    remove_pattern_from_gitignore "$ENV_FILE_NAME"

    echo "\nAll artifacts of the Python virtual environment have been deleted.\n"

    # v0.3.3: Also purge Pyve documentation templates from this repo if identical to recorded template version
    purge_templates "$@"
}

# Helper: source user shell profiles to ensure version managers are on PATH
function source_shell_profiles() {
    if [[ -f ~/.zshrc ]]; then
        source ~/.zshrc
    fi
    if [[ -f ~/.zprofile ]]; then
        source ~/.zprofile
    fi
}

# Helper: warn if Homebrew missing on macOS (non-fatal)
function check_homebrew_warning() {
    if [[ "$(uname)" == "Darwin" ]] && ! command -v brew &> /dev/null; then
        echo "\nWarning: Homebrew is not found.\nA future version will require Homebrew to automate some installations."
    fi
}

# Helper: detect which Python version manager to use (asdf preferred, then pyenv)
function detect_version_manager() {
    if command -v asdf &> /dev/null; then
        echo "\nFound asdf, so we'll use that for Python versioning."
        if [[ "$PATH" == *"$HOME/.asdf/shims"* ]]; then
            USE_ASDF="true"
        else
            echo "\nERROR: asdf shims path is not in the PATH. Please add it to the PATH."
            cat << 'EOF'
Run: echo -e '\n# Prepend the existing PATH with asdf\nexport PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> ~/.zprofile; source ~/.zprofile;
EOF
            echo "\n"
            exit 1
        fi
    elif command -v pyenv &> /dev/null; then
        echo "\nFound pyenv, so we'll use that for Python versioning."
        USE_PYENV="true"
    else
        echo "\nERROR: Neither asdf nor pyenv is installed. Please install one of them first."
        echo "We need a Python version manager to set up the environment."
        exit 1
    fi
}

# Helper: ensure requested Python version is installed (auto-install if available)
function ensure_python_version_installed() {
    if [[ $USE_ASDF == "true" ]]; then
        if ! asdf plugin list | grep -q "python"; then
            echo "\nERROR: Python plugin is not added in asdf."
            echo "Run: asdf plugin add python"
            exit 1
        fi
        if ! asdf list python | grep -q "$PYTHON_VERSION"; then
            echo "\nPython version $PYTHON_VERSION is not installed in asdf. Checking availability..."
            if asdf list all python | grep -q "^\s*${PYTHON_VERSION}$"; then
                echo "Installing Python $PYTHON_VERSION via asdf..."
                asdf install python "$PYTHON_VERSION"
                if [[ $? -ne 0 ]]; then
                    echo "\nERROR: Failed to install Python $PYTHON_VERSION via asdf."
                    exit 1
                fi
            else
                echo "\nERROR: Python version $PYTHON_VERSION is not available via asdf."
                exit 1
            fi
        fi
    elif [[ $USE_PYENV == "true" ]]; then
        if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
            echo "\nPython version $PYTHON_VERSION is not installed in pyenv. Attempting install..."
            pyenv install -s "$PYTHON_VERSION"
            if [[ $? -ne 0 ]]; then
                echo "\nERROR: Failed to install Python $PYTHON_VERSION via pyenv."
                exit 1
            fi
        fi
    fi
}

# Helper: ensure direnv is installed (required for init flow)
function check_direnv_installed() {
    if ! command -v direnv &> /dev/null; then
        echo "\nERROR: direnv is not installed. Please install direnv first."
        exit 1
    fi
}

function init_ready() {
    source_shell_profiles
    check_homebrew_warning
    detect_version_manager
    ensure_python_version_installed
    check_direnv_installed
    return 0 # success
}

function init_dotenv() {
    # Check if .env file already exists
    if [[ -f "$ENV_FILE_NAME" ]]; then
        echo "\nDotenv file already exists! (found $ENV_FILE_NAME) \nNo change."
    else
        # Create .env file - either copy from ~/.local/.env or create empty
        if [[ "$USE_LOCAL_ENV" == "true" ]] && [[ -f "$LOCAL_ENV_FILE" ]]; then
            cp "$LOCAL_ENV_FILE" "$ENV_FILE_NAME"
            chmod 600 "$ENV_FILE_NAME"
            echo "\nCopied '$LOCAL_ENV_FILE' to '$ENV_FILE_NAME' with limited permissions (chmod 600)."
        else
            if [[ "$USE_LOCAL_ENV" == "true" ]]; then
                echo "\nWARNING: --local-env specified but '$LOCAL_ENV_FILE' not found. Creating empty .env instead."
            fi
            touch $ENV_FILE_NAME
            chmod 600 $ENV_FILE_NAME
            echo "\nCreated '$ENV_FILE_NAME' file with limited permissions (chmod 600)."
        fi
        append_pattern_to_gitignore "$ENV_FILE_NAME"
    fi
}

function init_misc_artifacts() {
    # v0.4.18: Add .pyve directory to .gitignore (local state, never commit)
    append_pattern_to_gitignore ".pyve"
    
    # On macOS, add special content to .gitignore
    if [[ "$(uname)" == "Darwin" ]]; then
        append_pattern_to_gitignore "$MAC_OS_GITIGNORE_CONTENT"
    fi
}

# Set only the local Python version without venv/direnv changes
function set_python_version_only() {
    # Expecting: --python-version <version>
    if [[ $# -ne 2 ]]; then
        echo "\nERROR: parameter formatting problem."
        echo "Usage: pyve --python-version <python_version>"
        exit 1
    fi

    PYTHON_VERSION="$2"
    validate_python_version "$PYTHON_VERSION"

    # Prepare environment and detect manager
    source_shell_profiles
    detect_version_manager
    ensure_python_version_installed

    # Set local version via version manager only
    if [[ $USE_ASDF == "true" ]]; then
        echo "\nConfiguring Python version using asdf..."
        asdf set python "$PYTHON_VERSION"
        if [[ $? -ne 0 ]]; then
            echo "\nERROR: Failed to set Python version using asdf."
            exit 1
        fi
        echo "Python $PYTHON_VERSION is now set locally for this directory."
        echo "Refreshing asdf shims so the shell picks up the new version..."
        asdf reshim python "$PYTHON_VERSION" 2>/dev/null || asdf reshim python || asdf reshim
    elif [[ $USE_PYENV == "true" ]]; then
        echo "\nConfiguring Python version using pyenv..."
        pyenv local "$PYTHON_VERSION"
        if [[ $? -ne 0 ]]; then
            echo "\nERROR: Failed to set Python version using pyenv."
            exit 1
        fi
        echo "Python $PYTHON_VERSION is now set locally for this directory."
        echo "Refreshing pyenv shims so the shell picks up the new version..."
        if command -v pyenv &> /dev/null; then
            pyenv rehash 2>/dev/null || true
        fi
    fi
}

function init_python_versioning() {
    # Configure for asdf or pyenv
    if [[ $USE_ASDF == "true" ]]; then
        VERSION_FILE_NAME="$ASDF_FILE_NAME"
        VERSION_APP="asdf"
        LOCAL_VERSION_COMMAND="asdf set python $PYTHON_VERSION"
    elif [[ $USE_PYENV == "true" ]]; then
        VERSION_FILE_NAME="$PYENV_FILE_NAME"
        VERSION_APP="pyenv"
        LOCAL_VERSION_COMMAND="pyenv local $PYTHON_VERSION"
    fi

    # Check if the version file already exists
    if [[ -f "$VERSION_FILE_NAME" ]]; then
        echo "\n$VERSION_APP has already been configured for this directory! (found $VERSION_FILE_NAME) \nNo change.\n"
    else
        echo "\nChecking for current Python version..."
        which python
        python --version
        echo "\nConfiguring Python version using $VERSION_APP..."
        eval "$LOCAL_VERSION_COMMAND"
        if [[ $? -ne 0 ]]; then
            echo "\nERROR: Failed to set Python version using $VERSION_APP."
            exit 1
        fi
        echo "Python $PYTHON_VERSION is now set locally for this directory."
        echo "NOTE: For new projects, the Python version won't be active"
        echo "until you run 'direnv allow' to activate the environment."
        append_pattern_to_gitignore "$VERSION_FILE_NAME"
    fi
}

function init_venv() {
    # Configure Python virtual environment, but check first if .venv already exists
    if [[ -d "$VENV_DIR_NAME" ]]; then
        echo "\nPython virtual environment is already set up! (found ${VENV_DIR_NAME}) \nNo change.\n"
    else
        python -m venv "$VENV_DIR_NAME"
        echo "\nCreated Python virtual environment in '$VENV_DIR_NAME' directory."
        append_pattern_to_gitignore "$VENV_DIR_NAME"
    fi
}

function init_direnv() {
    # Configure for direnv, but check first if .envrc already exists
    if [[ -f "$DIRENV_FILE_NAME" ]]; then
        echo "\nDirenv has already been configured for this directory! (found $DIRENV_FILE_NAME) \nNo change.\n"
    else
        echo "\nConfiguring direnv for automated virtual environment activation..."
        if [[ -d "$VENV_DIR_NAME" ]]; then
            echo "Confirmed: '$VENV_DIR_NAME' directory exists."
        else
            echo "\nERROR: Python virtual environment config directory, '$VENV_DIR_NAME' does not exist!\n"
            exit 1
        fi

        append_pattern_to_gitignore "$DIRENV_FILE_NAME"

        # Write the Python venv environment configuration to .envrc
        echo "export VIRTUAL_ENV=\"$PWD/$VENV_DIR_NAME\"
    export PATH=\"$PWD/$VENV_DIR_NAME/bin:$PATH\"" > $DIRENV_FILE_NAME

        echo "Confirmed: '$DIRENV_FILE_NAME' created successfully!"
        echo "\nRun 'direnv allow' to activate the environment (if you see a warning below)."
    fi
}

function validate_venv_dir_name() {
    # Check if the directory name has a valid spelling
    if [[ ! $1 =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "\nInvalid directory name. Please provide a valid directory name."
        exit 1
    fi
    # Final sanity control...
    # Check if the directory name conflicts with $ENV_FILE_NAME, $GIT_DIR_NAME, $GITIGNORE_FILE_NAME, $ASDF_FILE_NAME, or $DIRENV_FILE_NAME
    if [[ $1 == $ENV_FILE_NAME ]]; then
        echo "\nERROR: The Venv directory name ($1) conflicts with the Python environment variable file name.\nPlease provide another name." 
    elif [[ $1 == $GIT_DIR_NAME ]]; then
        echo "\nERROR: The Venv directory name ($1) conflicts with the Git configuration directory name.\nPlease provide another name." 
    elif [[ $1 == $GITIGNORE_FILE_NAME ]]; then
        echo "\nERROR: The Venv directory name ($1) conflicts with the Git configuration file to ignore certain patterns.\nPlease provide another name." 
    elif [[ $1 == $ASDF_FILE_NAME ]]; then
        echo "\nERROR: The Venv directory name ($1) conflicts with the asdf configuration file name.\nPlease provide another name." 
    elif [[ $1 == $PYENV_FILE_NAME ]]; then
        echo "\nERROR: The Venv directory name ($1) conflicts with the pyenv configuration file name.\nPlease provide another name." 
    elif [[ $1 == $DIRENV_FILE_NAME ]]; then
        echo "\nERROR: The Venv directory name ($1) conflicts with the Direnv configuration file name. Please provide another name."
    else
        return 0 # no conflict, continue
    fi

    # If we reach this point, the directory name conflicts with one of the reserved names
    exit 1 # error
}

function validate_python_version() {
    # Check if the Python version has a valid spelling
    if [[ ! $1 =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
        echo "\nInvalid Python version ($1). Please provide a valid Python version."
        exit 1
    fi
}

function init_parse_args() {
    # v0.3.11b: Support --packages flag
    # v0.3.14: Support --local-env flag
    VENV_DIR_NAME="$DEFAULT_VENV_DIR_NAME"
    PYTHON_VERSION="$DEFAULT_PYTHON_VERSION"
    USE_LOCAL_ENV="false"
    INIT_PACKAGES=()
    
    local i=2  # Start from second arg (first is --init)
    while [[ $i -le $# ]]; do
        local arg="${!i}"
        
        if [[ "$arg" == "--python-version" ]]; then
            i=$((i+1))
            if [[ $i -gt $# ]]; then
                echo "\nERROR: --python-version requires a version number."
                exit 1
            fi
            PYTHON_VERSION="${!i}"
            validate_python_version "$PYTHON_VERSION"
            echo "\nUsing the Python version you provided: $PYTHON_VERSION"
        elif [[ "$arg" == "--local-env" ]]; then
            USE_LOCAL_ENV="true"
            echo "\nWill use local env template from ~/.local/.env (if available)"
        elif [[ "$arg" == "--packages" ]]; then
            # Collect all remaining args as packages
            i=$((i+1))
            while [[ $i -le $# ]]; do
                local pkg="${!i}"
                if [[ "$pkg" == --* ]]; then
                    i=$((i-1))  # Back up to process this flag
                    break
                fi
                INIT_PACKAGES+=("$pkg")
                i=$((i+1))
            done
        elif [[ "$arg" != --* ]]; then
            # Assume it's the venv directory name
            VENV_DIR_NAME="$arg"
            validate_venv_dir_name "$VENV_DIR_NAME"
            echo "\nUsing the Venv directory you provided: $VENV_DIR_NAME"
        else
            echo "\nERROR: Unknown flag: $arg"
            echo "Usage: pyve --init [<directory_name>] [--python-version <version>] [--local-env] [--packages <pkg1> <pkg2> ...]"
            exit 1
        fi
        
        i=$((i+1))
    done
    
    if [[ "$VENV_DIR_NAME" == "$DEFAULT_VENV_DIR_NAME" ]]; then
        echo "\nUsing the default Venv directory: $VENV_DIR_NAME"
    fi
    if [[ "$PYTHON_VERSION" == "$DEFAULT_PYTHON_VERSION" ]]; then
        echo "\nUsing the default Python version: $PYTHON_VERSION"
    fi
    
    if [[ ${#INIT_PACKAGES[@]} -gt 0 ]]; then
        echo "\nWill install packages after init: ${INIT_PACKAGES[*]}"
    fi
}

function init() {
    init_parse_args "$@"
    if init_ready; then
        init_misc_artifacts
        init_dotenv
        init_python_versioning
        init_venv

        # v0.3.2: Initialize documentation templates from ~/.pyve/templates/{latest}
        init_copy_templates

        # v0.3.11b: Install packages if specified
        if [[ ${#INIT_PACKAGES[@]} -gt 0 ]]; then
            echo "\nInstalling documentation packages..."
            add_package "${INIT_PACKAGES[@]}"
        fi

        # this needs to run last so that the 'direnv allow' instruction is close to the end of the output.
        init_direnv

        # no success message, since we need the user to pay attention to 'direnv allow'
    else
        echo "\nERROR: Failed to configure Python virtual environment."
        exit 1
    fi
}

# v0.3.2 helpers: initialize documentation templates
function ensure_project_pyve_dirs() {
    mkdir -p ./.pyve/status 2>/dev/null || true
}

# v0.4.21: Only block if action_needed exists (indicates incomplete merge)
function fail_if_status_present() {
    # Only block if action_needed file exists (indicates incomplete merge requiring user action)
    if [[ -f ./.pyve/action_needed ]]; then
        echo "\nERROR: Manual merge required."
        echo ""
        cat ./.pyve/action_needed
        exit 1
    fi
    # Status files without action_needed = successful operations, don't block
}

function write_init_status() {
    ensure_project_pyve_dirs
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) pyve --init $@" > ./.pyve/status/init
}

# v0.3.11: Doc package management functions
# v0.3.11b: Enhanced with metadata support

function get_package_metadata() {
    # Read package metadata from .packages.json
    # Usage: get_package_metadata <SRC_DIR> <package_name> <field>
    local SRC_DIR="$1"
    local PACKAGE="$2"
    local FIELD="$3"
    local METADATA_FILE="$SRC_DIR/docs/.packages.json"
    
    if [[ ! -f "$METADATA_FILE" ]]; then
        echo ""
        return 0
    fi
    
    # Use python or jq if available, otherwise return empty
    if command -v python3 &> /dev/null; then
        python3 -c "import json, sys; data=json.load(open('$METADATA_FILE')); print(data.get('packages', {}).get('$PACKAGE', {}).get('$FIELD', ''))" 2>/dev/null || echo ""
    elif command -v jq &> /dev/null; then
        jq -r ".packages.\"$PACKAGE\".\"$FIELD\" // empty" "$METADATA_FILE" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

function get_available_packages() {
    # Returns list of available doc packages based on subdirectories
    local SRC_DIR="$1"
    local -a PACKAGES=()
    
    # Check for subdirectories in guides and runbooks
    if [[ -d "$SRC_DIR/docs/guides" ]]; then
        for dir in "$SRC_DIR/docs/guides"/*; do
            if [[ -d "$dir" && "$(basename "$dir")" != "lang" ]]; then
                PACKAGES+=("$(basename "$dir")")
            fi
        done
    fi
    
    # Deduplicate by converting to associative array
    local -A UNIQUE_PACKAGES
    for pkg in "${PACKAGES[@]}"; do
        UNIQUE_PACKAGES[$pkg]=1
    done
    
    # Return sorted unique packages
    printf '%s\n' "${(@k)UNIQUE_PACKAGES}" | sort
}

function read_packages_conf() {
    # Read selected packages from .pyve/packages.conf
    if [[ -f "$PYVE_PACKAGES_CONF" ]]; then
        grep -v '^#' "$PYVE_PACKAGES_CONF" | grep -v '^[[:space:]]*$' | sort -u
    fi
}

function write_packages_conf() {
    # Write packages to .pyve/packages.conf
    # Usage: write_packages_conf package1 package2 ...
    ensure_project_pyve_dirs
    {
        echo "# Pyve documentation packages"
        echo "# One package name per line"
        echo "# Available packages: web, persistence, infrastructure, analytics, mobile"
        echo ""
        for pkg in "$@"; do
            echo "$pkg"
        done
    } > "$PYVE_PACKAGES_CONF"
}

function add_package() {
    # Add one or more packages to the configuration
    # v0.3.11b: Support space-separated packages
    # Usage: add_package pkg1 [pkg2 pkg3 ...]
    
    if [[ $# -eq 0 ]]; then
        echo "\nERROR: No packages specified."
        echo "Usage: pyve --add <package> [package2 package3 ...]"
        exit 1
    fi
    
    # Get latest version
    local LATEST_VERSION
    LATEST_VERSION=$(find_latest_template_version "$PYVE_HOME")
    if [[ -z "$LATEST_VERSION" ]]; then
        echo "\nERROR: No templates found in $PYVE_TEMPLATES_DIR."
        echo "Run 'pyve --update' first to download templates."
        exit 1
    fi
    
    local SRC_DIR="$PYVE_TEMPLATES_DIR/$LATEST_VERSION"
    
    # Get available packages
    local -a AVAILABLE
    AVAILABLE=(${(@f)"$(get_available_packages "$SRC_DIR")"})
    
    # Validate all packages first
    local -a TO_ADD=()
    for PACKAGE in "$@"; do
        local VALID=0
        for pkg in "${AVAILABLE[@]}"; do
            if [[ "$pkg" == "$PACKAGE" ]]; then
                VALID=1
                break
            fi
        done
        
        if [[ $VALID -eq 0 ]]; then
            echo "\nERROR: Package '$PACKAGE' not found."
            echo "Available packages:"
            for pkg in "${AVAILABLE[@]}"; do
                echo "  - $pkg"
            done
            exit 1
        fi
        TO_ADD+=("$PACKAGE")
    done
    
    # Read current packages
    local -a CURRENT
    CURRENT=(${(@f)"$(read_packages_conf)"})
    
    # Add packages (skip duplicates)
    local -a ADDED=()
    local -a SKIPPED=()
    for PACKAGE in "${TO_ADD[@]}"; do
        local ALREADY_ADDED=0
        for pkg in "${CURRENT[@]}"; do
            if [[ "$pkg" == "$PACKAGE" ]]; then
                ALREADY_ADDED=1
                SKIPPED+=("$PACKAGE")
                break
            fi
        done
        
        if [[ $ALREADY_ADDED -eq 0 ]]; then
            CURRENT+=("$PACKAGE")
            ADDED+=("$PACKAGE")
        fi
    done
    
    # Write updated config
    if [[ ${#ADDED[@]} -gt 0 ]]; then
        write_packages_conf "${CURRENT[@]}"
        
        echo "\nAdding packages..."
        for PACKAGE in "${ADDED[@]}"; do
            echo "  - $PACKAGE"
            copy_package_files "$SRC_DIR" "$PACKAGE"
        done
        
        echo "\nSuccessfully added ${#ADDED[@]} package(s)."
    fi
    
    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo "\nAlready installed (skipped):"
        for pkg in "${SKIPPED[@]}"; do
            echo "  - $pkg"
        done
    fi
}

function remove_package() {
    # Remove one or more packages from the configuration
    # v0.3.11b: Support space-separated packages
    # Usage: remove_package pkg1 [pkg2 pkg3 ...]
    
    if [[ $# -eq 0 ]]; then
        echo "\nERROR: No packages specified."
        echo "Usage: pyve --remove <package> [package2 package3 ...]"
        exit 1
    fi
    
    # Read current packages
    local -a CURRENT
    CURRENT=(${(@f)"$(read_packages_conf)"})
    
    # Check which packages to remove
    local -a TO_REMOVE=()
    local -a NOT_FOUND=()
    for PACKAGE in "$@"; do
        local FOUND=0
        for pkg in "${CURRENT[@]}"; do
            if [[ "$pkg" == "$PACKAGE" ]]; then
                FOUND=1
                TO_REMOVE+=("$PACKAGE")
                break
            fi
        done
        
        if [[ $FOUND -eq 0 ]]; then
            NOT_FOUND+=("$PACKAGE")
        fi
    done
    
    # Remove packages from list
    local -a NEW_PACKAGES
    for pkg in "${CURRENT[@]}"; do
        local SHOULD_REMOVE=0
        for remove_pkg in "${TO_REMOVE[@]}"; do
            if [[ "$pkg" == "$remove_pkg" ]]; then
                SHOULD_REMOVE=1
                break
            fi
        done
        
        if [[ $SHOULD_REMOVE -eq 0 ]]; then
            NEW_PACKAGES+=("$pkg")
        fi
    done
    
    # Write updated config
    if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
        write_packages_conf "${NEW_PACKAGES[@]}"
        
        echo "\nRemoving packages..."
        for PACKAGE in "${TO_REMOVE[@]}"; do
            echo "  - $PACKAGE"
            remove_package_files "$PACKAGE"
        done
        
        echo "\nSuccessfully removed ${#TO_REMOVE[@]} package(s)."
    fi
    
    if [[ ${#NOT_FOUND[@]} -gt 0 ]]; then
        echo "\nNot currently installed (skipped):"
        for pkg in "${NOT_FOUND[@]}"; do
            echo "  - $pkg"
        done
    fi
}

function copy_package_files() {
    # Copy files for a specific package
    local SRC_DIR="$1"
    local PACKAGE="$2"
    
    local -a FILES=()
    
    # Find package files in guides and runbooks
    if [[ -d "$SRC_DIR/docs/guides/$PACKAGE" ]]; then
        FILES+=(${(@f)"$(find "$SRC_DIR/docs/guides/$PACKAGE" -type f -name "*__t__*.md" 2>/dev/null)"})
    fi
    if [[ -d "$SRC_DIR/docs/runbooks/$PACKAGE" ]]; then
        FILES+=(${(@f)"$(find "$SRC_DIR/docs/runbooks/$PACKAGE" -type f -name "*__t__*.md" 2>/dev/null)"})
    fi
    
    local COPIED=0
    for FILE in "${FILES[@]}"; do
        [[ -z "$FILE" ]] && continue
        local DEST_REL
        DEST_REL=$(target_path_for_source "$SRC_DIR" "$FILE")
        local DEST_ABS="./$DEST_REL"
        
        # Skip if file already exists and is identical
        if [[ -f "$DEST_ABS" ]] && cmp -s "$FILE" "$DEST_ABS"; then
            continue
        fi
        
        mkdir -p "$(dirname "$DEST_ABS")"
        cp "$FILE" "$DEST_ABS"
        echo "  Copied: $DEST_REL"
        COPIED=$((COPIED+1))
    done
    
    echo "Copied $COPIED files for package '$PACKAGE'."
}

function remove_package_files() {
    # Remove files for a specific package
    local PACKAGE="$1"
    
    # Get current version
    local MM
    MM=$(read_project_major_minor)
    if [[ -z "$MM" ]]; then
        echo "\nWARNING: Could not determine project version. Skipping file removal."
        return 0
    fi
    
    local TEMPLATE_DIR="$PYVE_TEMPLATES_DIR/v$MM"
    if [[ ! -d "$TEMPLATE_DIR" ]]; then
        echo "\nWARNING: Template directory not found. Skipping file removal."
        return 0
    fi
    
    local -a FILES=()
    
    # Find package files in templates
    if [[ -d "$TEMPLATE_DIR/docs/guides/$PACKAGE" ]]; then
        FILES+=(${(@f)"$(find "$TEMPLATE_DIR/docs/guides/$PACKAGE" -type f -name "*__t__*.md" 2>/dev/null)"})
    fi
    if [[ -d "$TEMPLATE_DIR/docs/runbooks/$PACKAGE" ]]; then
        FILES+=(${(@f)"$(find "$TEMPLATE_DIR/docs/runbooks/$PACKAGE" -type f -name "*__t__*.md" 2>/dev/null)"})
    fi
    
    local REMOVED=0
    local SKIPPED=0
    for FILE in "${FILES[@]}"; do
        [[ -z "$FILE" ]] && continue
        local DEST_REL
        DEST_REL=$(target_path_for_source "$TEMPLATE_DIR" "$FILE")
        local DEST_ABS="./$DEST_REL"
        
        if [[ -f "$DEST_ABS" ]]; then
            if cmp -s "$FILE" "$DEST_ABS"; then
                rm -f "$DEST_ABS"
                echo "  Removed: $DEST_REL"
                REMOVED=$((REMOVED+1))
            else
                echo "  Skipped (modified): $DEST_REL"
                SKIPPED=$((SKIPPED+1))
            fi
        fi
    done
    
    echo "Removed $REMOVED files, skipped $SKIPPED modified files."
}

function list_packages() {
    # List available and installed packages
    # v0.3.11b: Show descriptions from metadata
    local LATEST_VERSION
    LATEST_VERSION=$(find_latest_template_version "$PYVE_HOME")
    if [[ -z "$LATEST_VERSION" ]]; then
        echo "\nNo templates installed. Run 'pyve --update' to download templates."
        return 0
    fi
    
    local SRC_DIR="$PYVE_TEMPLATES_DIR/$LATEST_VERSION"
    local -a AVAILABLE
    AVAILABLE=(${(@f)"$(get_available_packages "$SRC_DIR")"})
    
    local -a INSTALLED
    INSTALLED=(${(@f)"$(read_packages_conf)"})
    
    echo "\nAvailable documentation packages:"
    echo ""
    for pkg in "${AVAILABLE[@]}"; do
        local STATUS="  "
        for installed in "${INSTALLED[@]}"; do
            if [[ "$installed" == "$pkg" ]]; then
                STATUS="✓ "
                break
            fi
        done
        
        # Get description from metadata
        local DESC
        DESC=$(get_package_metadata "$SRC_DIR" "$pkg" "description")
        
        if [[ -n "$DESC" ]]; then
            echo "  $STATUS$pkg"
            echo "      $DESC"
        else
            echo "  $STATUS$pkg"
        fi
    done
    
    if [[ ${#INSTALLED[@]} -eq 0 ]]; then
        echo "\nNo packages currently installed."
        echo "Use 'pyve --add <package> [package2 ...]' to add packages."
    else
        echo "\nInstalled packages:"
        for pkg in "${INSTALLED[@]}"; do
            echo "  - $pkg"
        done
    fi
    
    echo "\nUsage:"
    echo "  pyve --add <package> [package2 ...]     Add one or more packages"
    echo "  pyve --remove <package> [package2 ...]  Remove one or more packages"
}

function strip_template_suffix() {
    # Usage: strip_template_suffix <filename>
    local name="$1"
    # Remove __t__* before extension (handles zero or more chars)
    echo "$name" | sed -E 's/__t__[^.]*\.(md)$/\.\1/; s/__t__\.(md)$/\.\1/' 2>/dev/null || echo "$name"
}

function list_template_files() {
    local SRC_DIR="$1"
    local MODE="${2:-all}"  # all, foundation, or package name
    
    # Root docs
    find "$SRC_DIR" -maxdepth 1 -type f -name "*__t__*.md" 2>/dev/null
    
    # Foundation docs (top-level guides)
    find "$SRC_DIR/docs/guides" -maxdepth 1 -type f -name "*__t__*.md" 2>/dev/null
    
    # v0.4.19: Context docs (always included in foundation)
    find "$SRC_DIR/docs/context" -type f -name "*__t__*.md" 2>/dev/null
    
    # v0.4.19: LLM Q&A docs (always included in foundation)
    find "$SRC_DIR/docs/guides/llm_qa" -type f -name "*__t__*.md" 2>/dev/null
    
    # Specs (always included)
    find "$SRC_DIR/docs/specs" -maxdepth 1 -type f -name "*__t__*.md" 2>/dev/null
    
    # Language specs (always included)
    find "$SRC_DIR/docs/specs/lang" -type f -name "*__t__*.md" -o -type f -name "*_spec__t__*.md" 2>/dev/null
    find "$SRC_DIR/docs/guides/lang" -type f -name "*__t__*.md" 2>/dev/null
    
    # Package-specific docs (only if mode is 'all' or specific package)
    if [[ "$MODE" == "all" ]]; then
        # Include all packages
        find "$SRC_DIR/docs/guides" -mindepth 2 -type f -name "*__t__*.md" ! -path "*/lang/*" ! -path "*/llm_qa/*" 2>/dev/null
        find "$SRC_DIR/docs/runbooks" -type f -name "*__t__*.md" 2>/dev/null
    elif [[ "$MODE" != "foundation" ]]; then
        # Include specific package
        find "$SRC_DIR/docs/guides/$MODE" -type f -name "*__t__*.md" 2>/dev/null
        find "$SRC_DIR/docs/runbooks/$MODE" -type f -name "*__t__*.md" 2>/dev/null
    fi
    # If MODE is "foundation", we only include the files already listed above
}

function target_path_for_source() {
    local SRC_DIR="$1"; shift
    local FILE="$1"
    local REL="${FILE#$SRC_DIR/}"
    local DEST="$REL"
    # Strip template suffix from filename parts
    local BASENAME=$(basename "$DEST")
    local DIRNAME=$(dirname "$DEST")
    local STRIPPED=$(echo "$BASENAME" | sed -E 's/__t__[^.]*\.(md)$/\.md/; s/__t__\.(md)$/\.\1/')
    echo "$DIRNAME/$STRIPPED"
}

function init_copy_templates() {
    # v0.5.0: Migrate old template directories before using them
    migrate_template_directories
    
    # Determine latest templates in ~/.pyve
    local HOME_SRC="$PYVE_HOME"
    local LATEST_VERSION
    LATEST_VERSION=$(find_latest_template_version "$HOME_SRC")
    if [[ -z "$LATEST_VERSION" ]]; then
        echo "\nWARNING: No templates found under $PYVE_HOME/templates. Skipping template initialization."
        return 0
    fi
    local SRC_DIR="$PYVE_TEMPLATES_DIR/$LATEST_VERSION"

    # Temporarily disable tracing to reduce noise, if currently enabled
    local HAD_XTRACE=0
    if [[ -o xtrace ]] || [[ "$-" == *x* ]]; then
        HAD_XTRACE=1
        set +x 2>/dev/null || true
        unsetopt xtrace 2>/dev/null || true
    fi

    echo "\nCopying documentation templates from the installed cache..."

    # Guard status: if only init status exists, skip copying; otherwise fail if other status files exist
    ensure_project_pyve_dirs
    if [[ -f ./.pyve/status/init ]]; then
        # Are there any files other than benign ones? (init, init_copy.log, .DS_Store)
        if ls -A ./.pyve/status 2>/dev/null | grep -Ev '^(init|init_copy\.log|\.DS_Store)$' >/dev/null; then
            echo "\nERROR: One or more status files exist under ./.pyve/status. Aborting to avoid making it worse."
            # Restore tracing if disabled
            if [[ $HAD_XTRACE -eq 1 ]]; then
                set -x 2>/dev/null || true
                setopt xtrace 2>/dev/null || true
            fi
            exit 1
        else
            echo "Templates already initialized previously; skipping template copy."
            # Restore tracing if disabled
            if [[ $HAD_XTRACE -eq 1 ]]; then
                set -x 2>/dev/null || true
                setopt xtrace 2>/dev/null || true
            fi
            return 0
        fi
    fi
    # No init status file present; ensure there aren't any unexpected status files
    fail_if_status_present

    # Build list and preflight check for non-identical overwrites (no subshells)
    # v0.3.11: Only copy foundation docs on init
    # v0.5.1: Skip conflict detection for Pyve-owned directories
    local -a FILES=()
    local CONFLICTS=()
    local FILE
    local LOG_FILE="./.pyve/status/init_copy.log"
    : > "$LOG_FILE" 2>/dev/null || true
    {
        FILES=(${(@f)"$(list_template_files "$SRC_DIR" "foundation")"})
        for FILE in "$FILES[@]"; do
            [[ -z "$FILE" ]] && continue
            local DEST_REL
            DEST_REL=$(target_path_for_source "$SRC_DIR" "$FILE")
            local DEST_ABS="./$DEST_REL"
            
            # v0.5.1: Skip conflict check for Pyve-owned files
            if is_pyve_owned "$DEST_REL"; then
                continue  # Will be overwritten without conflict check
            fi
            
            if [[ -f "$DEST_ABS" ]]; then
                if ! cmp -s "$FILE" "$DEST_ABS"; then
                    CONFLICTS+=("$DEST_REL")
                fi
            fi
        done
    } >> "$LOG_FILE" 2>&1

    # v0.4.17: If conflicts found, prompt user for smart copy
    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        echo "\nFound existing documentation files that differ from templates:"
        for f in "${CONFLICTS[@]}"; do echo " - $f"; done
        echo ""
        echo "These files will be preserved. New templates will be copied with __t__${LATEST_VERSION} suffix."
        echo -n "Continue with initialization? [y/N]: "
        read -r RESPONSE
        if [[ ! "$RESPONSE" =~ ^[Yy]$ ]]; then
            echo "Initialization cancelled."
            if [[ $HAD_XTRACE -eq 1 ]]; then
                set -x 2>/dev/null || true
                setopt xtrace 2>/dev/null || true
            fi
            exit 0
        fi
        
        # Use smart copy logic (like upgrade does)
        local UPGRADED=0
        local SKIPPED_MODIFIED=0
        echo "\nCopying templates..."
        {
            for FILE in "$FILES[@]"; do
                [[ -z "$FILE" ]] && continue
                local DEST_REL
                DEST_REL=$(target_path_for_source "$SRC_DIR" "$FILE")
                local DEST_ABS="./$DEST_REL"
                
                # v0.5.1: Always overwrite Pyve-owned files
                if is_pyve_owned "$DEST_REL"; then
                    mkdir -p "$(dirname "$DEST_ABS")"
                    cp "$FILE" "$DEST_ABS"
                    echo "  Copied: $DEST_REL (Pyve-owned)"
                    UPGRADED=$((UPGRADED+1))
                    continue
                fi
                
                if [[ -f "$DEST_ABS" ]]; then
                    if ! cmp -s "$FILE" "$DEST_ABS"; then
                        # File exists and differs - create suffixed copy
                        local SUFFIXED_NAME="${DEST_ABS%.*}__t__${LATEST_VERSION}.${DEST_ABS##*.}"
                        mkdir -p "$(dirname "$SUFFIXED_NAME")"
                        cp "$FILE" "$SUFFIXED_NAME"
                        echo "  Created: ${SUFFIXED_NAME##*/} (original preserved)"
                        SKIPPED_MODIFIED=$((SKIPPED_MODIFIED+1))
                    else
                        # Identical, safe to overwrite
                        mkdir -p "$(dirname "$DEST_ABS")"
                        cp "$FILE" "$DEST_ABS"
                        echo "  Copied: $DEST_REL"
                        UPGRADED=$((UPGRADED+1))
                    fi
                else
                    # File doesn't exist, copy it
                    mkdir -p "$(dirname "$DEST_ABS")"
                    cp "$FILE" "$DEST_ABS"
                    echo "  Added: $DEST_REL"
                    UPGRADED=$((UPGRADED+1))
                fi
            done
        } >> "$LOG_FILE" 2>&1
        
        echo "\nTemplate copy complete:"
        echo "  Copied/Added: $UPGRADED files"
        echo "  Preserved (created __t__ copies): $SKIPPED_MODIFIED files"
        if [[ $SKIPPED_MODIFIED -gt 0 ]]; then
            echo "\nNote: Review the __t__${LATEST_VERSION} files and merge changes manually."
            
            # v0.4.20: Create action_needed file with list of suffixed files
            local -a SUFFIXED_FILES=()
            if [[ -d ./docs ]]; then
                while IFS= read -r file; do
                    SUFFIXED_FILES+=("$file")
                done < <(find ./docs -type f -name "*__t__${LATEST_VERSION}.md" 2>/dev/null)
            fi
            if [[ ${#SUFFIXED_FILES[@]} -gt 0 ]]; then
                write_action_needed "init" "${SUFFIXED_FILES[@]}"
                echo "\nCreated .pyve/action_needed with merge instructions."
            fi
        fi
    else
        # No conflicts, simple copy
        {
            for FILE in "$FILES[@]"; do
                [[ -z "$FILE" ]] && continue
                local DEST_REL
                DEST_REL=$(target_path_for_source "$SRC_DIR" "$FILE")
                local DEST_ABS="./$DEST_REL"
                mkdir -p "$(dirname "$DEST_ABS")"
                cp "$FILE" "$DEST_ABS"
            done
        } >> "$LOG_FILE" 2>&1
        echo "Template initialization complete from version $LATEST_VERSION."
    fi

    # Record version used in the project
    if command -v pyve &> /dev/null; then
        pyve --version > ./.pyve/version 2>/dev/null || echo "Version: $VERSION" > ./.pyve/version
    else
        echo "Version: $VERSION" > ./.pyve/version
    fi

    # Write status file with args
    write_init_status "$@"

    # Restore tracing if it was previously enabled
    if [[ $HAD_XTRACE -eq 1 ]]; then
        set -x 2>/dev/null || true
        setopt xtrace 2>/dev/null || true
    fi
}

# v0.3.3 helpers: purge documentation templates that match the recorded template version
function read_project_major_minor() {
    # Extract major.minor from ./.pyve/version (expects something like 'Version: 0.3.1')
    if [[ ! -f ./.pyve/version ]]; then
        echo ""
        return 0
    fi
    local MM
    MM=$(grep -Eo '[0-9]+\.[0-9]+' ./.pyve/version 2>/dev/null | head -n1)
    echo "$MM"
}

# v0.4.21: Only block if action_needed exists (indicates incomplete merge)
function purge_status_fail_if_any_present() {
    # Only block if action_needed file exists (indicates incomplete merge requiring user action)
    if [[ -f ./.pyve/action_needed ]]; then
        echo "\nERROR: Manual merge required. Cannot purge until merge is complete."
        echo ""
        cat ./.pyve/action_needed
        exit 1
    fi
    # Status files without action_needed = successful operations, don't block
}

function write_purge_status() {
    mkdir -p ./.pyve/status 2>/dev/null || true
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) pyve --purge $@" > ./.pyve/status/purge
}

function purge_templates() {
    # Enforce status cleanliness at the beginning (spec requirement)
    purge_status_fail_if_any_present

    local MM
    MM=$(read_project_major_minor)
    if [[ -z "$MM" ]]; then
        echo "\nWARNING: Could not determine project template version from ./.pyve/version. Skipping template purge."
        return 0
    fi
    local TEMPLATE_DIR="$PYVE_TEMPLATES_DIR/v$MM"
    if [[ ! -d "$TEMPLATE_DIR" ]]; then
        echo "\nWARNING: Template directory '$TEMPLATE_DIR' not found. Skipping template purge."
        return 0
    fi

    local REMOVED=0
    local SKIPPED_MODIFIED=0
    local FILE
    # Use same mapping as init_copy_templates: iterate template files and compute target paths
    while IFS= read -r FILE; do
        [[ -z "$FILE" ]] && continue
        local DEST_REL
        DEST_REL=$(target_path_for_source "$TEMPLATE_DIR" "$FILE")
        local DEST_ABS="./$DEST_REL"
        if [[ -f "$DEST_ABS" ]]; then
            if cmp -s "$FILE" "$DEST_ABS"; then
                rm -f "$DEST_ABS"
                REMOVED=$((REMOVED+1))
            else
                echo "Warning: Not removing modified file: $DEST_REL"
                SKIPPED_MODIFIED=$((SKIPPED_MODIFIED+1))
            fi
        fi
    done < <(list_template_files "$TEMPLATE_DIR")

    write_purge_status "$@"

    echo "\nTemplate purge complete. Removed: $REMOVED; Skipped (modified): $SKIPPED_MODIFIED."
}

# Install this script into $HOME/.local/bin and create a 'pyve' symlink
function install_self() {
    # v0.3.1: If a newer source path is recorded, hand off install to that script (without looping)
    # Guard to prevent recursion
    if [[ -z "$PYVE_SKIP_HANDOFF" ]] && [[ -f "$PYVE_SOURCE_PATH_FILE" ]]; then
        RECORDED_SOURCE_PATH=$(cat "$PYVE_SOURCE_PATH_FILE" 2>/dev/null)
        # Resolve an indicator of where this script lives
        local CURRENT_SCRIPT_DIR=""
        if [[ -n "${(%):-%x}" ]] && [[ -f "${(%):-%x}" ]]; then
            CURRENT_SCRIPT_DIR=$(cd "$(dirname "${(%):-%x}")" && pwd)
        elif [[ -n "$0" ]] && [[ -f "$0" ]]; then
            CURRENT_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
        fi
        # Only handoff if recorded path exists, differs from PWD, and current script is not already under recorded path
        if [[ -n "$RECORDED_SOURCE_PATH" && -d "$RECORDED_SOURCE_PATH" ]]; then
            local REC_ABS
            REC_ABS=$(cd "$RECORDED_SOURCE_PATH" && pwd)
            local PWD_ABS
            PWD_ABS=$(pwd)
            # Case A: we're outside the source dir -> handoff to recorded source
            if [[ "$REC_ABS" != "$PWD_ABS" ]] && [[ -n "$CURRENT_SCRIPT_DIR" ]] && [[ "$CURRENT_SCRIPT_DIR" != "$REC_ABS"* ]]; then
                if [[ -f "$REC_ABS/pyve.sh" ]]; then
                    echo "\nDetected recorded source at '$REC_ABS'. Handing off install to the sourcecode script..."
                    ( export PYVE_SKIP_HANDOFF=1; cd "$REC_ABS" && ./pyve.sh --install )
                    return $?
                elif [[ -f "$REC_ABS/pyve" ]]; then
                    echo "\nDetected recorded source at '$REC_ABS'. Handing off install to the sourcecode script..."
                    ( export PYVE_SKIP_HANDOFF=1; cd "$REC_ABS" && ./pyve --install )
                    return $?
                else
                    echo "\nWARNING: Recorded source path exists but no pyve script found at '$REC_ABS'. Proceeding with current script."
                fi
            # Case B: we're inside the source dir but executing via installed binary -> handoff locally to ./pyve.sh
            elif [[ "$REC_ABS" == "$PWD_ABS" ]] && [[ -n "$CURRENT_SCRIPT_DIR" ]] && [[ "$CURRENT_SCRIPT_DIR" != "$PWD_ABS"* ]] && [[ -f "$PWD_ABS/pyve.sh" ]]; then
                echo "\nDetected execution from installed binary within the source directory. Handing off install to ./pyve.sh..."
                ( export PYVE_SKIP_HANDOFF=1; ./pyve.sh --install )
                return $?
            fi
        fi
    fi

    TARGET_BIN_DIR="$HOME/.local/bin"
    TARGET_SCRIPT_PATH="$TARGET_BIN_DIR/pyve.sh"
    TARGET_SYMLINK_PATH="$TARGET_BIN_DIR/pyve"

    echo "\nInstalling Pyve $VERSION to $TARGET_BIN_DIR ..."
    # Ensure bin dir exists
    if [[ ! -d "$TARGET_BIN_DIR" ]]; then
        echo "Creating $TARGET_BIN_DIR ..."
        mkdir -p "$TARGET_BIN_DIR"
        if [[ $? -ne 0 ]]; then
            echo "\nERROR: Failed to create $TARGET_BIN_DIR."
            exit 1
        fi
    else
        echo "Found $TARGET_BIN_DIR."
    fi

    # Ensure PATH contains bin dir (persist to ~/.zprofile if missing)
    if [[ ":$PATH:" != *":$TARGET_BIN_DIR:"* ]]; then
        echo "Adding $TARGET_BIN_DIR to PATH via ~/.zprofile ..."
        echo "\n# Added by pyve installer\nexport PATH=\"$TARGET_BIN_DIR:$PATH\"" >> ~/.zprofile
        if [[ -f ~/.zprofile ]]; then
            source ~/.zprofile 2>/dev/null || true
        fi
    else
        echo "$TARGET_BIN_DIR is already on PATH."
    fi

    # Resolve current script path (zsh-friendly with robust fallbacks)
    CURRENT_SCRIPT=""
    # 1) zsh special: current executing file
    if [[ -n "${(%):-%x}" ]] && [[ -f "${(%):-%x}" ]]; then
        CURRENT_SCRIPT="${(%):-%x}"
    fi
    # 2) $0 if it points to a file
    if [[ -z "$CURRENT_SCRIPT" ]] && [[ -n "$0" ]] && [[ -f "$0" ]]; then
        CURRENT_SCRIPT="$0"
    fi
    # 3) command -v $0 (resolved via PATH)
    if [[ -z "$CURRENT_SCRIPT" ]] && command -v -- "$0" &> /dev/null; then
        CANDIDATE=$(command -v -- "$0")
        if [[ -f "$CANDIDATE" ]]; then
            CURRENT_SCRIPT="$CANDIDATE"
        fi
    fi
    # 4) Common local names in the current directory
    if [[ -z "$CURRENT_SCRIPT" ]] && [[ -f "./pyve.sh" ]]; then
        CURRENT_SCRIPT="./pyve.sh"
    fi
    if [[ -z "$CURRENT_SCRIPT" ]] && [[ -f "./pyve" ]]; then
        CURRENT_SCRIPT="./pyve"
    fi
    # 5) Final attempt with readlink/greadlink for absolute path
    if [[ -n "$CURRENT_SCRIPT" ]]; then
        if command -v readlink &> /dev/null; then
            RESOLVED=$(readlink -f "$CURRENT_SCRIPT" 2>/dev/null)
            if [[ -n "$RESOLVED" ]]; then CURRENT_SCRIPT="$RESOLVED"; fi
        elif command -v greadlink &> /dev/null; then
            RESOLVED=$(greadlink -f "$CURRENT_SCRIPT" 2>/dev/null)
            if [[ -n "$RESOLVED" ]]; then CURRENT_SCRIPT="$RESOLVED"; fi
        fi
    fi

    if [[ -z "$CURRENT_SCRIPT" ]] || [[ ! -f "$CURRENT_SCRIPT" ]]; then
        echo "\nERROR: Cannot locate the current script to copy (got: $CURRENT_SCRIPT). Please run via a file path."
        exit 1
    fi

    # Copy script unless target already has identical contents
    if [[ -f "$TARGET_SCRIPT_PATH" ]] && cmp -s "$CURRENT_SCRIPT" "$TARGET_SCRIPT_PATH"; then
        echo "Target already up to date at $TARGET_SCRIPT_PATH (identical contents)."
    else
        cp "$CURRENT_SCRIPT" "$TARGET_SCRIPT_PATH"
        if [[ $? -ne 0 ]]; then
            echo "\nERROR: Failed to copy script to $TARGET_SCRIPT_PATH."
            exit 1
        fi
        echo "Installed script to $TARGET_SCRIPT_PATH."
    fi
    chmod +x "$TARGET_SCRIPT_PATH"
    echo "Ensured $TARGET_SCRIPT_PATH is executable."

    # Create/update symlink 'pyve' -> 'pyve.sh'
    if [[ -L "$TARGET_SYMLINK_PATH" || -e "$TARGET_SYMLINK_PATH" ]]; then
        LINK_TARGET=$(readlink "$TARGET_SYMLINK_PATH" 2>/dev/null)
        if [[ "$LINK_TARGET" != "pyve.sh" && "$LINK_TARGET" != "$TARGET_SCRIPT_PATH" ]]; then
            echo "Updating existing symlink or file at $TARGET_SYMLINK_PATH ..."
            rm -f "$TARGET_SYMLINK_PATH"
            ln -s "$TARGET_SCRIPT_PATH" "$TARGET_SYMLINK_PATH"
        else
            echo "Symlink $TARGET_SYMLINK_PATH already set."
        fi
    else
        ln -s "$TARGET_SCRIPT_PATH" "$TARGET_SYMLINK_PATH"
        echo "Created symlink $TARGET_SYMLINK_PATH -> $TARGET_SCRIPT_PATH"
    fi

    # v0.5.0: Migrate old template directories before copying new ones
    migrate_template_directories
    
    # v0.3.1: Record source path and copy latest templates
    local SOURCE_PATH="$PWD"
    if [[ ! -d "$SOURCE_PATH/templates" ]]; then
        echo "\nWARNING: Expected 'templates' directory under current path ($SOURCE_PATH). Ensure you run --install from the Pyve repo root."
    else
        record_source_path "$SOURCE_PATH"
        copy_latest_templates_to_home "$SOURCE_PATH"
    fi

    # v0.3.14: Create ~/.local/.env template if it doesn't exist
    if [[ ! -f "$LOCAL_ENV_FILE" ]]; then
        mkdir -p "$(dirname "$LOCAL_ENV_FILE")" 2>/dev/null || true
        touch "$LOCAL_ENV_FILE"
        chmod 600 "$LOCAL_ENV_FILE"
        echo "\nCreated empty env template at $LOCAL_ENV_FILE (chmod 600)."
        echo "You can add your default environment variables to this file."
        echo "Use 'pyve --init --local-env' to copy it to new projects."
    else
        echo "\nEnv template already exists at $LOCAL_ENV_FILE."
    fi

    echo "\nInstallation of Pyve $VERSION complete. You can now run 'pyve --help' from any directory."
}

# Uninstall this script from $HOME/.local/bin by removing the script and symlink
function uninstall_self() {
    TARGET_BIN_DIR="$HOME/.local/bin"
    TARGET_SCRIPT_PATH="$TARGET_BIN_DIR/pyve.sh"
    TARGET_SYMLINK_PATH="$TARGET_BIN_DIR/pyve"

    echo "\nUninstalling pyve from $TARGET_BIN_DIR ..."
    if [[ -L "$TARGET_SYMLINK_PATH" ]] || [[ -e "$TARGET_SYMLINK_PATH" ]]; then
        echo "Removing symlink or file: $TARGET_SYMLINK_PATH"
        rm -f "$TARGET_SYMLINK_PATH"
    else
        echo "No symlink found at $TARGET_SYMLINK_PATH."
    fi

    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        echo "Removing installed script: $TARGET_SCRIPT_PATH"
        rm -f "$TARGET_SCRIPT_PATH"
    else
        echo "No installed script found at $TARGET_SCRIPT_PATH."
    fi

    # v0.3.1: Remove ~/.pyve directory
    if [[ -d "$PYVE_HOME" ]]; then
        echo "Removing $PYVE_HOME ..."
        rm -rf "$PYVE_HOME"
    fi

    # v0.3.14: Remove ~/.local/.env if it's empty
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        if [[ ! -s "$LOCAL_ENV_FILE" ]]; then
            echo "Removing empty env template: $LOCAL_ENV_FILE"
            rm -f "$LOCAL_ENV_FILE"
        else
            echo "Keeping non-empty env template: $LOCAL_ENV_FILE (delete manually if desired)"
        fi
    fi

    echo "\nUninstall complete. Note: If $TARGET_BIN_DIR was added to your PATH via ~/.zprofile, that line remains; you can remove it manually if desired."
}

# v0.3.5: Update templates from source repo to ~/.pyve/templates/{newer_version}
# v0.5.0: Now uses semver comparison for patch-level versions
function update_templates() {
    # v0.5.0: Migrate old template directories before updating
    migrate_template_directories
    
    # Read the source path from ~/.pyve/source_path
    if [[ ! -f "$PYVE_SOURCE_PATH_FILE" ]]; then
        echo "\nERROR: Source path file not found at $PYVE_SOURCE_PATH_FILE."
        echo "Please run 'pyve --install' from the Pyve repository first."
        exit 1
    fi

    local SOURCE_PATH
    SOURCE_PATH=$(cat "$PYVE_SOURCE_PATH_FILE" 2>/dev/null)
    if [[ -z "$SOURCE_PATH" || ! -d "$SOURCE_PATH" ]]; then
        echo "\nERROR: Invalid source path recorded in $PYVE_SOURCE_PATH_FILE."
        echo "Please run 'pyve --install' from the Pyve repository to update the source path."
        exit 1
    fi

    echo "\nChecking for template updates from source: $SOURCE_PATH"

    # Find the latest version in the source repo
    local SOURCE_LATEST_VERSION
    SOURCE_LATEST_VERSION=$(find_latest_template_version "$SOURCE_PATH")
    if [[ -z "$SOURCE_LATEST_VERSION" ]]; then
        echo "\nWARNING: No versioned templates found in source at '$SOURCE_PATH/templates'."
        exit 0
    fi

    echo "Latest version in source: $SOURCE_LATEST_VERSION"

    # Find the latest version in the home directory
    local HOME_LATEST_VERSION
    HOME_LATEST_VERSION=$(find_latest_template_version "$PYVE_HOME")
    if [[ -z "$HOME_LATEST_VERSION" ]]; then
        echo "No templates currently installed in $PYVE_TEMPLATES_DIR."
        HOME_LATEST_VERSION="v0.0.0"
    else
        echo "Current version in home: $HOME_LATEST_VERSION"
    fi

    # v0.5.0: Use semver comparison instead of string comparison
    local NEED_UPDATE=0
    compare_semver "$SOURCE_LATEST_VERSION" "$HOME_LATEST_VERSION"
    local CMP_RESULT=$?
    if [[ $CMP_RESULT -eq 1 ]]; then
        # Source is newer
        NEED_UPDATE=1
    elif [[ $CMP_RESULT -eq 0 ]] && [[ ! -d "$PYVE_TEMPLATES_DIR/$SOURCE_LATEST_VERSION" ]]; then
        # Same version but directory missing
        NEED_UPDATE=1
    fi
    
    if [[ $NEED_UPDATE -eq 1 ]]; then
        echo "\nNewer version available: $SOURCE_LATEST_VERSION"
        local SRC_DIR="$SOURCE_PATH/templates/$SOURCE_LATEST_VERSION"
        local DEST_DIR="$PYVE_TEMPLATES_DIR/$SOURCE_LATEST_VERSION"
        
        # Ensure destination doesn't already exist (keep immutable)
        if [[ -d "$DEST_DIR" ]]; then
            echo "Template version $SOURCE_LATEST_VERSION already exists at $DEST_DIR."
            echo "Templates are kept immutable once written. No update needed."
        else
            echo "Copying templates from '$SRC_DIR' to '$DEST_DIR' ..."
            mkdir -p "$DEST_DIR"
            # Use rsync if available for cleaner sync, else fallback to cp -R
            if command -v rsync &> /dev/null; then
                rsync -a "$SRC_DIR/" "$DEST_DIR/"
            else
                cp -R "$SRC_DIR/." "$DEST_DIR/"
            fi
            echo "Templates copied to $DEST_DIR"
            
            # Update the version file in ~/.pyve/version
            echo "Version: $VERSION" > "$PYVE_HOME/version"
            echo "Updated version file to $VERSION"
        fi
    else
        echo "\nTemplates are already up to date (version $HOME_LATEST_VERSION)."
    fi

    echo "\nTemplate update complete."
}

# v0.4.20: Write action_needed file when manual merge is required
function write_action_needed() {
    local OPERATION="$1"
    shift
    local -a SUFFIXED_FILES=("$@")
    
    ensure_project_pyve_dirs
    local ACTION_FILE="./.pyve/action_needed"
    
    {
        echo "Manual merge required for the following files:"
        for file in "${SUFFIXED_FILES[@]}"; do
            echo "  - $file"
        done
        echo ""
        echo "To complete:"
        echo "1. Review and merge changes from suffixed files"
        echo "2. Delete suffixed files when satisfied"
        echo "3. Run: pyve --clear-status $OPERATION"
        echo ""
        echo "Until resolved, 'pyve --upgrade' is blocked."
    } > "$ACTION_FILE"
}

# v0.4.20: Clear status after manual merge
function clear_status() {
    if [[ $# -ne 2 ]]; then
        echo "\nERROR: --clear-status requires an operation argument."
        echo "Usage: pyve --clear-status <operation>"
        echo "  where <operation> is: init | upgrade"
        exit 1
    fi
    
    local OPERATION="$2"
    
    if [[ "$OPERATION" != "init" ]] && [[ "$OPERATION" != "upgrade" ]]; then
        echo "\nERROR: Invalid operation '$OPERATION'."
        echo "Valid operations: init | upgrade"
        exit 1
    fi
    
    local STATUS_FILE="./.pyve/status/$OPERATION"
    local ACTION_FILE="./.pyve/action_needed"
    
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo "\nNo status file found for operation '$OPERATION'."
        echo "Nothing to clear."
        exit 0
    fi
    
    # Check if suffixed files still exist (warning, not blocking)
    local SUFFIXED_COUNT=0
    if [[ -d ./docs ]]; then
        SUFFIXED_COUNT=$(find ./docs -type f -name "*__t__v*.md" 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    if [[ $SUFFIXED_COUNT -gt 0 ]]; then
        echo "\nWARNING: Found $SUFFIXED_COUNT suffixed file(s) still present."
        echo "You may want to review and delete them after merging."
    fi
    
    # Remove status file
    rm -f "$STATUS_FILE"
    echo "\nRemoved status file: $STATUS_FILE"
    
    # Remove action_needed file if it exists
    if [[ -f "$ACTION_FILE" ]]; then
        rm -f "$ACTION_FILE"
        echo "Removed action file: $ACTION_FILE"
    fi
    
    # For upgrade, update the version file
    if [[ "$OPERATION" == "upgrade" ]]; then
        if command -v pyve &> /dev/null; then
            pyve --version > ./.pyve/version 2>/dev/null || echo "Version: $VERSION" > ./.pyve/version
        else
            echo "Version: $VERSION" > ./.pyve/version
        fi
        echo "Updated .pyve/version to current version ($VERSION)"
    fi
    
    echo "\nStatus cleared for '$OPERATION'."
    if [[ "$OPERATION" == "init" ]]; then
        echo "You can now run 'pyve --upgrade' if needed."
    else
        echo "You can now run 'pyve --upgrade' again."
    fi
}

# v0.3.6: Upgrade local repository templates to newer version from ~/.pyve/templates/
# v0.4.21: Only block if action_needed exists (indicates incomplete merge)
function upgrade_status_fail_if_any_present() {
    # Only block if action_needed file exists (indicates incomplete merge requiring user action)
    if [[ -f ./.pyve/action_needed ]]; then
        echo "\nERROR: Manual merge required."
        echo ""
        cat ./.pyve/action_needed
        exit 1
    fi
    # Status files without action_needed = successful operations, don't block
}

function write_upgrade_status() {
    mkdir -p ./.pyve/status 2>/dev/null || true
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) pyve --upgrade $@" > ./.pyve/status/upgrade
}

function upgrade_templates() {
    # v0.5.0: Migrate old template directories before upgrading
    migrate_template_directories
    
    # Enforce status cleanliness at the beginning (spec requirement)
    upgrade_status_fail_if_any_present

    # Read the old version from the local git repo
    if [[ ! -f ./.pyve/version ]]; then
        echo "\nERROR: No version file found at ./.pyve/version."
        echo ""
        echo "This project appears to be from an old pyve version (pre-v0.3.2) or was never initialized."
        echo ""
        echo "To fix:"
        echo "  pyve --init"
        echo ""
        echo "This will safely initialize/upgrade your project:"
        echo "  - Creates .pyve/version and .pyve/status/ infrastructure"
        echo "  - Copies missing templates"
        echo "  - Preserves modified files (creates __t__ suffixed copies for review)"
        exit 1
    fi

    local OLD_VERSION_FULL
    OLD_VERSION_FULL=$(cat ./.pyve/version 2>/dev/null)
    # v0.5.0: Parse full semver (major.minor.patch) instead of just major.minor
    local OLD_VERSION_NUM
    OLD_VERSION_NUM=$(echo "$OLD_VERSION_FULL" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    if [[ -z "$OLD_VERSION_NUM" ]]; then
        # Fallback: try major.minor format for old projects
        local OLD_MM
        OLD_MM=$(echo "$OLD_VERSION_FULL" | grep -Eo '[0-9]+\.[0-9]+' | head -n1)
        if [[ -z "$OLD_MM" ]]; then
            echo "\nERROR: Could not parse version from ./.pyve/version (content: $OLD_VERSION_FULL)."
            exit 1
        fi
        OLD_VERSION_NUM="$OLD_MM.0"
    fi
    local OLD_VERSION="v$OLD_VERSION_NUM"
    echo "\nCurrent project template version: $OLD_VERSION"

    # Find the latest version available in ~/.pyve/templates/
    local HOME_LATEST_VERSION
    HOME_LATEST_VERSION=$(find_latest_template_version "$PYVE_HOME")
    if [[ -z "$HOME_LATEST_VERSION" ]]; then
        echo "\nERROR: No templates found in $PYVE_TEMPLATES_DIR."
        echo "Run 'pyve --update' first to download templates from the source repository."
        exit 1
    fi
    echo "Latest available template version: $HOME_LATEST_VERSION"

    # v0.5.0: Use semver comparison instead of string comparison
    compare_semver "$HOME_LATEST_VERSION" "$OLD_VERSION"
    local CMP_RESULT=$?
    if [[ $CMP_RESULT -eq 1 ]]; then
        echo "\nNewer version available: $HOME_LATEST_VERSION"
        local TEMPLATE_DIR="$PYVE_TEMPLATES_DIR/$HOME_LATEST_VERSION"
        local OLD_TEMPLATE_DIR="$PYVE_TEMPLATES_DIR/$OLD_VERSION"
        
        if [[ ! -d "$TEMPLATE_DIR" ]]; then
            echo "\nERROR: Template directory not found at $TEMPLATE_DIR."
            exit 1
        fi

        # Build list of template files to process
        # v0.3.11: Honor packages.conf if it exists
        local -a FILES=()
        local -a INSTALLED_PACKAGES
        INSTALLED_PACKAGES=(${(@f)"$(read_packages_conf)"})
        
        if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
            # Copy foundation + installed packages
            FILES=(${(@f)"$(list_template_files "$TEMPLATE_DIR" "foundation")"})
            for pkg in "${INSTALLED_PACKAGES[@]}"; do
                FILES+=(${(@f)"$(list_template_files "$TEMPLATE_DIR" "$pkg")"})
            done
        else
            # No packages.conf, copy only foundation (v0.3.11 behavior)
            FILES=(${(@f)"$(list_template_files "$TEMPLATE_DIR" "foundation")"})
        fi
        
        if [[ ${#FILES[@]} -eq 0 ]]; then
            echo "\nWARNING: No template files found in $TEMPLATE_DIR."
            return 0
        fi

        local UPGRADED=0
        local SKIPPED_MODIFIED=0
        local FILE
        
        echo "\nUpgrading templates..."
        for FILE in "${FILES[@]}"; do
            [[ -z "$FILE" ]] && continue
            
            local DEST_REL
            DEST_REL=$(target_path_for_source "$TEMPLATE_DIR" "$FILE")
            local DEST_ABS="./$DEST_REL"
            
            # v0.5.1: Always overwrite Pyve-owned files
            if is_pyve_owned "$DEST_REL"; then
                mkdir -p "$(dirname "$DEST_ABS")"
                cp "$FILE" "$DEST_ABS"
                echo "  Upgraded: $DEST_REL (Pyve-owned)"
                UPGRADED=$((UPGRADED+1))
                continue
            fi
            
            # Check if the destination file exists
            if [[ -f "$DEST_ABS" ]]; then
                # Check if it's identical to the old version
                local OLD_TEMPLATE_FILE
                OLD_TEMPLATE_FILE=$(echo "$FILE" | sed "s|$HOME_LATEST_VERSION|$OLD_VERSION|")
                
                if [[ -f "$OLD_TEMPLATE_FILE" ]] && cmp -s "$OLD_TEMPLATE_FILE" "$DEST_ABS"; then
                    # Identical to old version, safe to overwrite
                    mkdir -p "$(dirname "$DEST_ABS")"
                    cp "$FILE" "$DEST_ABS"
                    echo "  Upgraded: $DEST_REL"
                    UPGRADED=$((UPGRADED+1))
                else
                    # Not identical to old version, create suffixed copy
                    local SUFFIXED_NAME="${DEST_ABS%.*}__t__${HOME_LATEST_VERSION}.${DEST_ABS##*.}"
                    mkdir -p "$(dirname "$SUFFIXED_NAME")"
                    cp "$FILE" "$SUFFIXED_NAME"
                    echo "  Warning: Modified file detected. Created: ${SUFFIXED_NAME##*/}"
                    echo "           Original file not modified: $DEST_REL"
                    SKIPPED_MODIFIED=$((SKIPPED_MODIFIED+1))
                fi
            else
                # File doesn't exist, copy it
                mkdir -p "$(dirname "$DEST_ABS")"
                cp "$FILE" "$DEST_ABS"
                echo "  Added: $DEST_REL"
                UPGRADED=$((UPGRADED+1))
            fi
        done

        # Update the version file
        if command -v pyve &> /dev/null; then
            pyve --version > ./.pyve/version 2>/dev/null || echo "Version: $VERSION" > ./.pyve/version
        else
            echo "Version: $VERSION" > ./.pyve/version
        fi

        # Write status file
        write_upgrade_status "$@"

        echo "\nUpgrade complete."
        echo "  Upgraded/Added: $UPGRADED files"
        echo "  Skipped (modified): $SKIPPED_MODIFIED files"
        if [[ $SKIPPED_MODIFIED -gt 0 ]]; then
            echo "\nNote: Modified files were preserved. Review the __t__${HOME_LATEST_VERSION} files and merge changes manually."
            
            # v0.4.20: Create action_needed file with list of suffixed files
            local -a SUFFIXED_FILES=()
            if [[ -d ./docs ]]; then
                while IFS= read -r file; do
                    SUFFIXED_FILES+=("$file")
                done < <(find ./docs -type f -name "*__t__${HOME_LATEST_VERSION}.md" 2>/dev/null)
            fi
            if [[ ${#SUFFIXED_FILES[@]} -gt 0 ]]; then
                write_action_needed "upgrade" "${SUFFIXED_FILES[@]}"
                echo "\nCreated .pyve/action_needed with merge instructions."
            fi
        fi
    elif [[ $CMP_RESULT -eq 0 ]]; then
        echo "\nTemplates are already at the latest version ($OLD_VERSION)."
    else
        echo "\nCurrent version ($OLD_VERSION) is newer than available templates ($HOME_LATEST_VERSION)."
        echo "Run 'pyve --update' to check for newer templates from the source repository."
    fi
}

# Check if the script is run with a parameter
if [[ $# -eq 0 ]]; then
    echo "\nNo parameters provided. Please provide a parameter."
    show_help
    exit 1
fi
# Check for the first parameter
if [[ $1 == "--help" ]] || [[ $1 == "-h" ]]; then
    show_help
    exit 0
elif [[ $1 == "--version" ]] || [[ $1 == "-v" ]]; then
    show_version
    exit 0
elif [[ $1 == "--config" ]] || [[ $1 == "-c" ]]; then
    show_config
    exit 0
elif [[ $1 == "--purge" ]] || [[ $1 == "-p" ]]; then
    purge "$@"
    exit 0
elif [[ $1 == "--install" ]]; then
    install_self
    exit 0
elif [[ $1 == "--uninstall" ]]; then
    uninstall_self
    exit 0
elif [[ $1 == "--python-version" ]]; then
    set_python_version_only "$@"
    exit 0
elif [[ $1 == "--update" ]]; then
    update_templates
    exit 0
elif [[ $1 == "--upgrade" ]]; then
    upgrade_templates
    exit 0
elif [[ $1 == "--clear-status" ]]; then
    clear_status "$@"
    exit 0
elif [[ $1 == "--list" ]]; then
    list_packages
    exit 0
elif [[ $1 == "--add" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "\nERROR: --add requires at least one package name."
        echo "Usage: pyve --add <package> [package2 package3 ...]"
        exit 1
    fi
    shift  # Remove --add from args
    add_package "$@"
    exit 0
elif [[ $1 == "--remove" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "\nERROR: --remove requires at least one package name."
        echo "Usage: pyve --remove <package> [package2 package3 ...]"
        exit 1
    fi
    shift  # Remove --remove from args
    remove_package "$@"
    exit 0
elif [[ $1 == "--init" ]] || [[ $1 == "-i" ]]; then
    init "$@"
    exit 0
else
    echo "\nInvalid parameter. Please provide a valid parameter."
    show_help
    exit 1
fi
