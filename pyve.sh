#!/usr/bin/env zsh

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
#   - Runs asdf to set Python to version 3.11.11
#   - Runs venv to configure local environment for pip packages
#     - Checks if .venv already exists in the current directory
#   - Configures direnv 
#     - Checks if .envrc already exists in the current directory. 
#     - If it exists, exit with a warning. 
#     - Otherwise, accept one parameter <directory_name> (or nothing for default).
#       - No directory name defaults to '.venv' for the 
#         Python virtual environment config.
#     - assign <directory_name> param to DIRNAME.
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
VERSION="0.1.1"

# asdf configuration
PYTHONVERSION="3.11.11"

function show_help() {
    echo "\nHELP: Pyve.sh - Python Virtual Environment Setup Script\n"
    echo "Pyve will set up a special Python virtual environment in your current directory. "
    echo "- auto-configure a version of Python (asdf)"
    echo "- autocreate a virtual environment (python venv)"
    echo "- autoactivate and deactivate the virtual environment when you change directory (direnv)"
    echo "- auto-configure an environment variable file .env (ready for dotenv package in Python)"
    echo "\nUsage: ~/pyve.sh {--init <directory_name> | --purge <directory_name> | --help | --version | --config}"
    echo "Description:"
    echo "  --init:    Initialize Python virtual environment"
    echo "             Optional directory name (default is .venv)"
    echo "  --purge:   Delete all artifacts of the Python virtual environment"
    echo "  --help:    Show this help message"
    echo "  --version: Show the version of this script"
    echo "  --config:  Show the configuration of this script"
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

function purge() {
    echo "\nDeleting Python virtual environment..."
    rm -rf .venv
    echo "\nDeleting asdf .tool-versions file..."
    rm -f .tool-versions
    echo "\nDeleting .envrc file..."
    rm -f .envrc
    echo "\nDeleting .env file..."
    rm -f .env

    echo "\nAll artifacts of the Python virtual environment have been deleted."
}

function has_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo "\nThis script must be run as root. Please run it with sudo."
        exit 1
    fi
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
    if ! command -v brew &> /dev/null; then
        echo "\nError: Homebrew is not installed. Please install Homebrew first."
        exit 1
    fi

    # Check if asdf is installed
    if ! command -v asdf &> /dev/null; then
        echo "\nError: asdf is not installed. Please install asdf first."
        exit 1
    fi

    # Check if Python plugin is added in asdf
    if ! asdf plugin list | grep -q "python"; then
        echo "\nError: Python plugin is not added in asdf. Please add it first."
        exit 1
    fi

    # Check if Python version is installed
    if ! asdf list python | grep -q "$PYTHONVERSION"; then
        echo "\nError: Python version $PYTHONVERSION is not installed in asdf. Please install it first."
        exit 1
    fi

    # Check if direnv is installed
    if ! command -v direnv &> /dev/null; then
        echo "\nError: direnv is not installed. Please install direnv first."
        exit 1
    fi
}

function init_dotenv() {
    # Check if .env file already exists
    if [[ -f ".env" ]]; then
        echo "\nOops! .env file already exists! (found .env) \nNo change.\n"
        #exit 1
    else
        # Create .env file and set permissions
        touch .env
        chmod 600 .env
        echo "\n.env file created successfully!\n"
    fi
}

function init_config_dir_name() {
    # Check if a second parameter is provided
    if [[ $# -eq 2 ]]; then
        DIRNAME="$2"
    else
        echo "\nYou didn't provide a virtual environment directory (that's fine)."
        echo "Default is '.venv', so we'll use that."
        echo "\nFYI, usage: ~/pyve.sh --init <directory_name>\n"
        
        DIRNAME=".venv"
    fi
    # Check if the directory name has a valid spelling
    if [[ ! $DIRNAME =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "\nInvalid directory name. Please provide a valid directory name."
        exit 1
    fi
}

function init_asdf() {
        # Check if asdf .tool-versions file exists
        if [[ -f ".tool-versions" ]]; then
            echo "\nOops! asdf has already been configured for this directory! (found .tool-versions) \nNo change.\n"
            #exit 1
        else
            echo "\nChecking for current Python version..."
            which python
            python --version
            echo "\nConfiguring Python version..."
            asdf set python "$PYTHONVERSION"
            echo "\nVersion set now to Python $PYTHONVERSION.\nNOTE: this version won't be active until you run 'direnv allow' to activate the environment.\n"
        fi
}

function init_venv() {
    # Configure Python virtual environment, but check first if .venv already exists
    if [[ -d ".venv" || -d "$DIRNAME" ]]; then
        echo "\nOops! Python virtual environment is already set up! (found ${DIRNAME}) \nNo change.\n"
        #exit 1
    else
        python -m venv "$DIRNAME"
    fi
}

function init_direnv() {
    # Configure for direnv, but check first if .envrc already exists
    if [[ -f ".envrc" ]]; then
        echo "\nOops! Direnv has already been configured for this directory! (found .envrc) \nNo change.\n"
        #exit 1
    else
        echo "\nConfiguring direnv for automated virtual environment activation..."
        if [[ -d "$DIRNAME" ]]; then
            echo "Great! $DIRNAME exists."
        else
            echo "\nERROR: Python virtual environment config directory, \"$DIRNAME\" does not exist!\n"
            exit 1
        fi

        # Write the Python venv environment configuration to .envrc
        echo "export VIRTUAL_ENV=\"\$PWD/$DIRNAME\"
    export PATH=\"\$PWD/$DIRNAME/bin:\$PATH\"" > .envrc

        echo ".envrc created successfully!\ndirenv is ready to go!\n"
        echo "Run 'direnv allow' to activate the environment."
    fi
}

function init() {
    if init_ready; then
        init_config_dir_name "$@"
        init_dotenv
        init_asdf
        init_venv
        init_direnv
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
    purge
    exit 0
elif [[ $1 == "--init" ]]; then
    init "$@"
    exit 0
else
    echo "\nInvalid parameter. Please provide a valid parameter."
    show_help
    exit 1
fi

