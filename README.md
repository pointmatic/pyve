# Pyve: Python Virtual Environment Configurator

Pyve is a command-line tool that simplifies setting up and managing Python virtual environments. It combines several best practices into a single, easy-to-use script.

## Features

- **Automated Python Version Management**: Uses asdf to set a specific Python version (3.11.11)
- **Virtual Environment Creation**: Creates a Python virtual environment in your project directory
- **Auto-activation**: Configures direnv to automatically activate/deactivate your environment when you enter/exit the directory
- **Environment Variable Management**: Creates a secure .env file for storing environment variables
- **Git Integration**: Automatically adds appropriate patterns to .gitignore
- **Clean Removal**: Easily remove all virtual environment artifacts with a single command

## Requirements

- macOS/Linux with zsh
- Homebrew
- asdf (with Python plugin installed and Python 3.11.11 available)
- direnv

## Installation

1. Clone this repository or download the script
2. Make the script executable:
   ```bash
   chmod +x pyve.sh
   ```
3. It works best if you move the script to a directory in your PATH or to your home directory. 

All of the examples assume that you have installed the script in your home directory. 

## Usage

### Initialize a Python Virtual Environment

```bash
~/pyve.sh --init [directory_name]
```

This will:
- Configure asdf to use Python 3.11.11 in the current directory
- Create a Python virtual environment (default is .venv or specify a custom name)
- Set up direnv for auto-activation when entering the directory
- Create a secure .env file for environment variables
- Add appropriate patterns to .gitignore

The script checks for existing files and won't overwrite them if they already exist. If a file already exists, the script will notify you and continue with the next steps.

After setup, run `direnv allow` to activate the environment.

### Remove a Python Virtual Environment

```bash
~/pyve.sh --purge [directory_name]
```

This removes all artifacts created by the initialization:
- .venv directory (or custom named directory)
- .tool-versions file (asdf configuration)
- .envrc file (direnv configuration)
- .env file
- Removes the related patterns from .gitignore (but keeps the file itself)

### Additional Commands

```bash
~/pyve.sh --help     # Show help message
~/pyve.sh --version  # Show script version
~/pyve.sh --config   # Show configuration details
```

## Troubleshooting

The script performs prerequisite checks before initialization to ensure all required tools are available. If any tool is missing, it will provide an error message indicating what needs to be installed.

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the LICENSE file for details.

## Copyright

Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)

