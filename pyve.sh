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
# Usage: ~/pyve.sh {--init [<directory_name>] [--python-version <python_version>] | --python-version <python_version> | --purge [<directory_name>] | --install | --uninstall | --update | --upgrade | --help | --version | --config }
# Description:
# There are ten functions:
#   1. --init / -i: Initialize the Python virtual environment 
#      NOTE: --python-version is optional
#      FORMAT: #.#.#, example 3.13.7
#   2. --python-version <ver>: Set the Python version in the current directory without creating a virtual environment
#   3. --purge / -p: Delete all the artifacts of the Python virtual environment
#   4. --install: Install this script to $HOME/.local/bin and create a 'pyve' symlink; also record repo path and install latest documentation templates to ~/.pyve/templates/{latest}
#   5. --uninstall: Remove the installed script and 'pyve' symlink from $HOME/.local/bin
#   6. --update: Update documentation templates from the Pyve source repo to ~/.pyve/templates/{newer_version}
#   7. --upgrade: Upgrade the local git repository documentation templates to a newer version from ~/.pyve/templates/
#   8. --help / -h: Show this help message
#   9. --version / -v: Show the version of this script
#   10. --config / -c: Show the configuration of this script
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
VERSION="0.3.6"

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
DIRENV_FILE_NAME=".envrc"
GIT_DIR_NAME=".git"
GITIGNORE_FILE_NAME=".gitignore"
MAC_OS_GITIGNORE_CONTENT=".DS_Store"
# Pyve home and template locations
PYVE_HOME="$HOME/.pyve"
PYVE_SOURCE_PATH_FILE="$PYVE_HOME/source_path"
PYVE_TEMPLATES_DIR="$PYVE_HOME/templates"

# Ensure Pyve home directories exist
function ensure_pyve_home() {
    mkdir -p "$PYVE_TEMPLATES_DIR" 2>/dev/null || true
}

# Find latest templates version directory name (e.g., v0.3) under given source path
function find_latest_template_version() {
    local SOURCE_PATH="$1"
    if [[ -z "$SOURCE_PATH" || ! -d "$SOURCE_PATH/templates" ]]; then
        echo ""
        return 0
    fi
    # List v* directories, sort, take last, and print basename
    local LATEST_DIR
    LATEST_DIR=$(ls -1d "$SOURCE_PATH"/templates/v* 2>/dev/null | sort | tail -n 1)
    if [[ -z "$LATEST_DIR" ]]; then
        echo ""
    else
        basename "$LATEST_DIR"
    fi
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
    echo "\nUsage: ~/pyve.sh {--init [<directory_name>] [--python-version <python_version>] | --python-version <python_version> | --purge [<directory_name>] | --install | --uninstall | --update | --upgrade | --help | --version | --config}"
    echo "\nDescription:"
    echo "  --init:    Initialize Python virtual environment"
    echo "             Optional directory name (default is .venv)"
    echo "             Optional --python-version <ver> to select a specific Python version"
    echo "  --python-version <ver>: Set only the local Python version in the current directory (no venv/direnv changes)"
    echo "  --purge:   Delete all artifacts of the Python virtual environment"
    echo "  --install: Install this script to \"$HOME/.local/bin\", ensure it's on your PATH, create a 'pyve' symlink, record the repo path, and copy the latest documentation templates to \"$HOME/.pyve/templates/{latest}\""
    echo "  --uninstall: Remove the installed script (pyve.sh) and the 'pyve' symlink from \"$HOME/.local/bin\""
    echo "  --update:  Update documentation templates from the Pyve source repo to \"$HOME/.pyve/templates/{newer_version}\""
    echo "  --upgrade: Upgrade the local git repository documentation templates to a newer version from \"$HOME/.pyve/templates/\""
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
        # Create .env file and set permissions
        touch $ENV_FILE_NAME
        chmod 600 $ENV_FILE_NAME
        echo "\nCreated '$ENV_FILE_NAME' file with limited permissions (chmod 600)."
        append_pattern_to_gitignore "$ENV_FILE_NAME"
    fi
}

function init_misc_artifacts() {
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
    if [[ $# -eq 1 ]]; then
        # simple case, use defaults
        VENV_DIR_NAME="$DEFAULT_VENV_DIR_NAME"
        echo "\nUsing the default Venv directory: $VENV_DIR_NAME"
        PYTHON_VERSION="$DEFAULT_PYTHON_VERSION"
        echo "\nUsing the default Python version: $PYTHON_VERSION"
    elif [[ $# -eq 4 ]]; then
        # max params --init <directory_name> --python-version <python_version>
        if [[ $3 != "--python-version" ]]; then
            # something is wrong
            echo "\nERROR: parameter formatting problem."
            echo "--init <optional_directory_name> --python-version <python_version>"
            echo "Note: you can also use abbreviation -i for --init" 
            exit 1
        fi
        VENV_DIR_NAME="$2"
        validate_venv_dir_name "$VENV_DIR_NAME"
        echo "\nUsing the Venv directory you provided: $VENV_DIR_NAME"
        PYTHON_VERSION="$4"
        validate_python_version "$PYTHON_VERSION"
        echo "\nUsing the Python version you provided: $PYTHON_VERSION"
    elif [[ $# -eq 2 ]]; then
        if [[ $2 == "--python-version" ]]; then
            echo "\nERROR: you need to specify a python version.\n"
            exit 1
        fi
        # second param is the directory name
        VENV_DIR_NAME="$2"
        validate_venv_dir_name "$VENV_DIR_NAME"
        echo "\nUsing the Venv directory you provided: $VENV_DIR_NAME"
        PYTHON_VERSION="$DEFAULT_PYTHON_VERSION"
        echo "\nUsing the default Python version: $PYTHON_VERSION"
    elif [[ $# -eq 3 ]]; then
        if [[ $2 != "--python-version" ]]; then
            # something is wrong
            echo "\nERROR: parameter formatting problem."
            echo "--init <optional_directory_name> --python-version <python_version>"
            echo "Note: you can also use abbreviation -i for --init" 
            exit 1
        fi
        VENV_DIR_NAME="$DEFAULT_VENV_DIR_NAME"
        echo "\nUsing the default Venv directory: $VENV_DIR_NAME"
        PYTHON_VERSION="$3"
        echo "\nUsing the Python version you provided: $PYTHON_VERSION"
        validate_python_version "$PYTHON_VERSION"
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

function fail_if_status_present() {
    if [[ -d ./.pyve/status ]] && [[ -n $(ls -A ./.pyve/status 2>/dev/null) ]]; then
        echo "\nERROR: One or more status files exist under ./.pyve/status. Aborting to avoid making it worse."
        exit 1
    fi
}

function write_init_status() {
    ensure_project_pyve_dirs
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) pyve --init $@" > ./.pyve/status/init
}

function strip_template_suffix() {
    # Usage: strip_template_suffix <filename>
    local name="$1"
    # Remove __t__* before extension (handles zero or more chars)
    echo "$name" | sed -E 's/__t__[^.]*\.(md)$/\.\1/; s/__t__\.(md)$/\.\1/' 2>/dev/null || echo "$name"
}

function list_template_files() {
    local SRC_DIR="$1"
    # Root docs
    find "$SRC_DIR" -maxdepth 1 -type f -name "*__t__*.md" 2>/dev/null
    # Guides and Specs
    find "$SRC_DIR/docs/guides" -type f -name "*__t__*.md" 2>/dev/null
    find "$SRC_DIR/docs/specs" -maxdepth 1 -type f -name "*__t__*.md" 2>/dev/null
    # Language specs (copy all available for now)
    find "$SRC_DIR/docs/specs/lang" -type f -name "*__t__*.md" -o -type f -name "*_spec__t__*.md" 2>/dev/null
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
    local -a FILES=()
    local CONFLICTS=()
    local FILE
    local LOG_FILE="./.pyve/status/init_copy.log"
    : > "$LOG_FILE" 2>/dev/null || true
    {
        FILES=(${(@f)"$(list_template_files "$SRC_DIR")"})
        for FILE in "$FILES[@]"; do
            [[ -z "$FILE" ]] && continue
            local DEST_REL
            DEST_REL=$(target_path_for_source "$SRC_DIR" "$FILE")
            local DEST_ABS="./$DEST_REL"
            if [[ -f "$DEST_ABS" ]]; then
                if ! cmp -s "$FILE" "$DEST_ABS"; then
                    CONFLICTS+=("$DEST_REL")
                fi
            fi
        done
    } >> "$LOG_FILE" 2>&1

    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        echo "\nERROR: Initialization would overwrite modified files. Aborting. Conflicts:"
        for f in "${CONFLICTS[@]}"; do echo " - $f"; done
        exit 1
    fi

    # Copy files, stripping __t__* suffix
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

    # Record version used in the project
    if command -v pyve &> /dev/null; then
        pyve --version > ./.pyve/version 2>/dev/null || echo "Version: $VERSION" > ./.pyve/version
    else
        echo "Version: $VERSION" > ./.pyve/version
    fi

    # Write status file with args
    write_init_status "$@"

    echo "Template initialization complete from version $LATEST_VERSION."

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

function purge_status_fail_if_any_present() {
    if [[ -d ./.pyve/status ]] && [[ -n $(ls -A ./.pyve/status 2>/dev/null) ]]; then
        echo "\nERROR: One or more status files exist under ./.pyve/status. Aborting purge to avoid making it worse."
        exit 1
    fi
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

    # v0.3.1: Record source path and copy latest templates
    local SOURCE_PATH="$PWD"
    if [[ ! -d "$SOURCE_PATH/templates" ]]; then
        echo "\nWARNING: Expected 'templates' directory under current path ($SOURCE_PATH). Ensure you run --install from the Pyve repo root."
    else
        record_source_path "$SOURCE_PATH"
        copy_latest_templates_to_home "$SOURCE_PATH"
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

    echo "\nUninstall complete. Note: If $TARGET_BIN_DIR was added to your PATH via ~/.zprofile, that line remains; you can remove it manually if desired."
}

# v0.3.5: Update templates from source repo to ~/.pyve/templates/{newer_version}
function update_templates() {
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
        HOME_LATEST_VERSION="v0.0"
    else
        echo "Current version in home: $HOME_LATEST_VERSION"
    fi

    # Compare versions (simple string comparison works for v0.3 format)
    if [[ "$SOURCE_LATEST_VERSION" > "$HOME_LATEST_VERSION" ]] || [[ "$SOURCE_LATEST_VERSION" == "$HOME_LATEST_VERSION" && ! -d "$PYVE_TEMPLATES_DIR/$SOURCE_LATEST_VERSION" ]]; then
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

# v0.3.6: Upgrade local repository templates to newer version from ~/.pyve/templates/
function upgrade_status_fail_if_any_present() {
    if [[ -d ./.pyve/status ]] && [[ -n $(ls -A ./.pyve/status 2>/dev/null) ]]; then
        echo "\nERROR: One or more status files exist under ./.pyve/status. Aborting upgrade to avoid making it worse."
        exit 1
    fi
}

function write_upgrade_status() {
    mkdir -p ./.pyve/status 2>/dev/null || true
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) pyve --upgrade $@" > ./.pyve/status/upgrade
}

function upgrade_templates() {
    # Enforce status cleanliness at the beginning (spec requirement)
    upgrade_status_fail_if_any_present

    # Read the old version from the local git repo
    if [[ ! -f ./.pyve/version ]]; then
        echo "\nERROR: No version file found at ./.pyve/version."
        echo "This directory does not appear to have been initialized with pyve templates."
        echo "Run 'pyve --init' first to initialize this repository."
        exit 1
    fi

    local OLD_VERSION_FULL
    OLD_VERSION_FULL=$(cat ./.pyve/version 2>/dev/null)
    local OLD_MM
    OLD_MM=$(echo "$OLD_VERSION_FULL" | grep -Eo '[0-9]+\.[0-9]+' | head -n1)
    if [[ -z "$OLD_MM" ]]; then
        echo "\nERROR: Could not parse version from ./.pyve/version (content: $OLD_VERSION_FULL)."
        exit 1
    fi
    local OLD_VERSION="v$OLD_MM"
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

    # Check if there's a newer version
    if [[ "$HOME_LATEST_VERSION" > "$OLD_VERSION" ]]; then
        echo "\nNewer version available: $HOME_LATEST_VERSION"
        local TEMPLATE_DIR="$PYVE_TEMPLATES_DIR/$HOME_LATEST_VERSION"
        local OLD_TEMPLATE_DIR="$PYVE_TEMPLATES_DIR/$OLD_VERSION"
        
        if [[ ! -d "$TEMPLATE_DIR" ]]; then
            echo "\nERROR: Template directory not found at $TEMPLATE_DIR."
            exit 1
        fi

        # Build list of template files to process
        local -a FILES=()
        FILES=(${(@f)"$(list_template_files "$TEMPLATE_DIR")"})
        
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
        fi
    elif [[ "$HOME_LATEST_VERSION" == "$OLD_VERSION" ]]; then
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
elif [[ $1 == "--init" ]] || [[ $1 == "-i" ]]; then
    init "$@"
    exit 0
else
    echo "\nInvalid parameter. Please provide a valid parameter."
    show_help
    exit 1
fi
