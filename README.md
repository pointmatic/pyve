# Pyve: Python Virtual Environment Configurator

Pyve is a command-line tool that simplifies setting up and managing Python virtual environments. It combines several best practices into a single, easy-to-use script.

## Features

- **Flexible Python Version Management**: Uses either asdf or pyenv to set a specific Python version (default 3.13.7, but customizable)
- **Virtual Environment Creation**: Creates a Python virtual environment in your project directory
- **Auto-activation**: Configures direnv to automatically activate/deactivate your environment when you enter/exit the directory
- **Environment Variable Management**: Creates a secure .env file for storing environment variables (with chmod 600 permissions)
- **Git Integration**: Automatically adds appropriate patterns to .gitignore
- **Clean Removal**: Easily remove all virtual environment artifacts with a single command

### Planned Features
- Support for configurable default Python version (stored in a config in the user's home directory)
- Automated installation of asdf or pyenv
- Automated addition of Python plugin using asdf
- Automated installation of a Python version using either asdf or pyenv
- Support for Windows Subsystem for Linux (WSL)
- Support for bash
- Support for Linux

## Requirements

- macOS with Z shell (future support for bash/Linux/WSL)
- Either of these Python version managers:
  - asdf (with Python plugin added). Pyve will auto-install the requested Python version via `asdf install python <version>` if available.
  - pyenv. Pyve will auto-install the requested Python version via `pyenv install -s <version>` if available.
- direnv (required for the `--init` flow; not required for standalone `--python-version`)

The script will check for these prerequisites before initialization and provide helpful error messages if anything is missing.

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

Basic usage with default settings (Python 3.13.7 and .venv directory):
```bash
~/pyve.sh --init
```

With custom virtual environment directory:
```bash
~/pyve.sh --init my_venv
```

With custom Python version:
```bash
~/pyve.sh --init --python-version 3.10.9
```

With both custom directory and Python version:
```bash
~/pyve.sh --init my_venv --python-version 3.10.9
```

You can also use shortened parameter forms:
```bash
~/pyve.sh -i my_venv
```

This will:
- Configure either asdf or pyenv (whichever is available) to use the specified Python version in the current directory
- Create a Python virtual environment (default is .venv or specify a custom name)
- Set up direnv for auto-activation when entering the directory
- Create a secure .env file for environment variables with restricted permissions (chmod 600)
- Add appropriate patterns to .gitignore

The script checks for existing files and won't overwrite them if they already exist. If a file already exists, the script will notify you and continue with the next steps.

After setup, run `direnv allow` to activate the environment.

### Set Only the Local Python Version (no venv/direnv)

```bash
~/pyve.sh --python-version 3.13.7
```

This will set the requested Python version locally in the current directory using either asdf or pyenv (auto-installing the version if available), without creating a virtual environment or configuring direnv.

### Remove a Python Virtual Environment

```bash
~/pyve.sh --purge [directory_name]
# or 
~/pyve.sh -p [directory_name]
```

This removes all artifacts created by the initialization:
- .venv directory (or custom named directory)
- .tool-versions file (asdf configuration) or .python-version file (pyenv configuration)
- .envrc file (direnv configuration)
- .env file
- Removes the related patterns from .gitignore (but keeps the file itself)

### Additional Commands

```bash
~/pyve.sh --help     # or -h: Show help message
~/pyve.sh --version  # or -v: Show script version (current: 0.2.4)
~/pyve.sh --config   # or -c: Show configuration details
```

## Troubleshooting

The script performs prerequisite checks before initialization to ensure all required tools are available. If any tool is missing, it will provide an error message indicating what needs to be installed.

The script is compatible with current macOS command-line (Z shell). Future support for other shells and platforms is planned.

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the LICENSE file for details.

## Copyright

Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)

