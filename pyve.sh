#!/usr/bin/env zsh
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# This source code is licensed under the Mozilla Public License Version 2.0 found in the
# LICENSE file in the root directory of this source tree.
# 
#============================================================================================================================================================================================
#
# This script is designed to set up a Python virtual environment in the current directory.
#
# Name: pyve.sh
# Usage: ~/pyve.sh {--init <directory_name> | --purge <directory_name> | --help | --version | --config | }
# Description:
# There are three functions:
#   1. --init: Initialize the Python virtural environment
#   2. --purge: Delete all the artifacts of the Python virtual environment
#   3. --help: Show this help message
#   4. --version: Show the version of this script
#   5. --config: Show the configuration of this script
#   Neither your own code nor Git is impacted by this script. This is only about setting up your Python environment.
#
#   1. --init: Initialize the Python virtural environment
#   Initializes Python environment with a sane setup
#   - Runs asdf (or if not installed, pyenv) to set Python to version 3.11.11
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
#   - Deletes the asdf .tool-versions file
#   - Deletes the .venv directory (default) or <directory_name> (if provided)
#   - Deletes the .envrc file
#   - Deletes the .env file

# script version
VERSION="0.2.0"

# configuration constants
PYTHONVERSION="3.11.11"
ASDF_FILE_NAME=".tool-versions"
USE_ASDF="true"
PYENV_FILE_NAME=".python-version"
USE_PYENV="false"
DEFAULT_VENV_DIR_NAME=".venv" 
#VENV_DIR_NAME is based on a parameter passed to the script, decided in init_config_dir_name()
ENV_FILE_NAME=".env"
DIRENV_FILE_NAME=".envrc"
GIT_DIR_NAME=".git"
GITIGNORE_FILE_NAME=".gitignore"

function show_help() {
    echo "\nHELP: Pyve.sh - Python Virtual Environment Setup Script\n"
    echo "Pyve will set up a special Python virtual environment in your current directory. "
    echo "- auto-configure a version of Python (asdf or pyenv)"
    echo "- autocreate a virtual environment (python venv)"
    echo "- autoactivate and deactivate the virtual environment when you change directory (direnv)"
    echo "- auto-configure an environment variable file .env (ready for dotenv package in Python)"
    echo "- auto-configure a .gitignore file to ignore the virtual environment directory and other artifacts"
    echo "\nUsage: ~/pyve.sh {--init <directory_name> | --purge <directory_name> | --help | --version | --config}"
    echo "\nDescription:"
    echo "  --init:    Initialize Python virtual environment"
    echo "             Optional directory name (default is .venv)"
    echo "  --purge:   Delete all artifacts of the Python virtual environment"
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
    echo "  Python version: $PYTHONVERSION"
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
}

function init_ready() {
    # source the Z shell configuration
    if [[ -f ~/.zshrc ]]; then
        source ~/.zshrc
    fi
    if [[ -f ~/.zprofile ]]; then
        source ~/.zprofile
    fi

    # Check if homebrew is installed
    if [[ "$(uname)" == "Darwin" ]] && ! command -v brew &> /dev/null; then
        echo "\nError: Homebrew is not installed. Please install Homebrew first."
        exit 1
    fi

    # Check if asdf is installed
    if command -v asdf &> /dev/null; then
        echo "\nFound asdf, so we'll use that for Python versioning."
        USE_ASDF="true"
    elif command -v pyenv &> /dev/null; then
        echo "\nFound pyenv, so we'll use that for Python versioning."
        USE_PYENV="true"
    else
        echo "\nError: Neither asdf nor pyenv is installed. Please install one of them first."
        echo "We need a Python version manager to set up the environment."
        exit 1
    fi

    if [[ $USE_ASDF == "true" ]]; then
        # Check if Python plugin is added in asdf
        if ! asdf plugin list | grep -q "python"; then
            echo "\nError: Python plugin is not added in asdf."
            echo "Run: asdf add python"
            exit 1
        fi
        # Check if Python version is installed
        if ! asdf list python | grep -q "$PYTHONVERSION"; then
            echo "\nError: Python version $PYTHONVERSION is not installed in asdf."
            echo "Run: asdf install python $PYTHONVERSION"
            exit 1
        fi
    elif [[ $USE_PYENV == "true" ]]; then
        # Check if Python version is installed
        if ! pyenv versions | grep -q "$PYTHONVERSION"; then
            echo "\nError: Python version $PYTHONVERSION is not installed in pyenv."
            echo "Run: pyenv install $PYTHONVERSION"
            exit 1
        fi
    fi

    # Check if direnv is installed
    if ! command -v direnv &> /dev/null; then
        echo "\nError: direnv is not installed. Please install direnv first."
        exit 1
    fi

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

function init_config_dir_name() {
    # Check if a second parameter is provided
    if [[ $# -eq 2 ]]; then
        VENV_DIR_NAME="$2"
        echo "\nUsing the Venv directory you provided: $VENV_DIR_NAME"
    else
        VENV_DIR_NAME="$DEFAULT_VENV_DIR_NAME"
        echo "\nUsing the default Venv directory: $VENV_DIR_NAME"
    fi
    # Check if the directory name has a valid spelling
    if [[ ! $VENV_DIR_NAME =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "\nInvalid directory name. Please provide a valid directory name."
        exit 1
    fi
    # Final sanity control...
    # Check if the directory name conflicts with $ENV_FILE_NAME, $GIT_DIR_NAME, $GITIGNORE_FILE_NAME, $ASDF_FILE_NAME, or $DIRENV_FILE_NAME
    if [[ $VENV_DIR_NAME == $ENV_FILE_NAME ]]; then
        echo "\nError: The Venv directory name ($VENV_DIR_NAME) conflicts with the Python environment variable file name.\nPlease provide another name." 
    elif [[ $VENV_DIR_NAME == $GIT_DIR_NAME ]]; then
        echo "\nError: The Venv directory name ($VENV_DIR_NAME) conflicts with the Git configuration directory name.\nPlease provide another name." 
    elif [[ $VENV_DIR_NAME == $GITIGNORE_FILE_NAME ]]; then
        echo "\nError: The Venv directory name ($VENV_DIR_NAME) conflicts with the Git configuration file to ignore certain patterns.\nPlease provide another name." 
    elif [[ $VENV_DIR_NAME == $ASDF_FILE_NAME ]]; then
        echo "\nError: The Venv directory name ($VENV_DIR_NAME) conflicts with the asdf configuration file name.\nPlease provide another name." 
    elif [[ $VENV_DIR_NAME == $PYENV_FILE_NAME ]]; then
        echo "\nError: The Venv directory name ($VENV_DIR_NAME) conflicts with the pyenv configuration file name.\nPlease provide another name." 
    elif [[ $VENV_DIR_NAME == $DIRENV_FILE_NAME ]]; then
        echo "\nError: The Venv directory name ($VENV_DIR_NAME) conflicts with the Direnv configuration file name. Please provide another name."
    else
        return 0 # no conflict, continue
    fi

    # If we reach this point, the directory name conflicts with one of the reserved names
    exit 1 # error
}

function init_python_versioning() {
    # Configure for asdf or pyenv
    if [[ $USE_ASDF == "true" ]]; then
        VERSION_FILE_NAME="$ASDF_FILE_NAME"
        VERSION_APP="asdf"
        LOCAL_VERSION_COMMAND="asdf set python $PYTHONVERSION"
    elif [[ $USE_PYENV == "true" ]]; then
        VERSION_FILE_NAME="$PYENV_FILE_NAME"
        VERSION_APP="pyenv"
        LOCAL_VERSION_COMMAND="pyenv local $PYTHONVERSION"
    fi

    # Check if the version file already exists
    if [[ -f "$VERSION_FILE_NAME" ]]; then
        echo "\n$VERSION_APP has already been configured for this directory! (found $VERSION_FILE_NAME) \nNo change.\n"
    else
        echo "\nChecking for current Python version..."
        which python
        python --version
        echo "\nConfiguring Python version using asdf..."
        eval "$LOCAL_VERSION_COMMAND"
        if [[ $? -ne 0 ]]; then
            echo "\nError: Failed to set Python version using $VERSION_APP."
            exit 1
        fi
        echo "Python $PYTHONVERSION is now set locally for this directory."
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
        echo "export VIRTUAL_ENV=\"\$PWD/$VENV_DIR_NAME\"
    export PATH=\"\$PWD/$VENV_DIR_NAME/bin:\$PATH\"" > $DIRENV_FILE_NAME

        echo "Confirmed: '$DIRENV_FILE_NAME' created successfully!"
        echo "Run 'direnv allow' to activate the environment (if you see a warning below)."
    fi
}

function init() {
    if init_ready; then
        init_config_dir_name "$@"
        init_dotenv
        init_python_versioning
        init_venv
        init_direnv
        # no success message, since we need the user to pay attention to 'direnv allow'
    else
        echo "\nError: Failed to configure Python virtual environment."
        exit 1
    fi
}

# Check if the script is run with a parameter
if [[ $# -eq 0 ]]; then
    echo "\nNo parameters provided. Please provide a parameter."
    show_help
    exit 1
fi
# Check for the first parameter
if [[ $1 == "--help" ]]; then
    show_help
    exit 0
elif [[ $1 == "--version" ]]; then
    show_version
    exit 0
elif [[ $1 == "--config" ]]; then
    show_config
    exit 0
elif [[ $1 == "--purge" ]]; then
    purge "$@"
    exit 0
elif [[ $1 == "--init" ]]; then
    init "$@"
    exit 0
else
    echo "\nInvalid parameter. Please provide a valid parameter."
    show_help
    exit 1
fi
