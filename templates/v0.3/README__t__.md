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
- Version management:
   - Automated installation of asdf
   - Automated installation of pyenv
   - Automated addition of Python plugin using asdf or pyenv
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
3. Install it to your local bin and create a convenience symlink `pyve`:
   ```bash
   ./pyve.sh --install
   ```
   This will:
   - Create `$HOME/.local/bin` (if it doesn't exist)
   - Add `$HOME/.local/bin` to your PATH via `~/.zprofile` (if not already present)
   - Copy `pyve.sh` to `$HOME/.local/bin/pyve.sh` and make it executable
   - Create a symlink `$HOME/.local/bin/pyve` -> `$HOME/.local/bin/pyve.sh`

After installation, you can run `pyve` from any directory.

## Usage

### Initialize a Python Virtual Environment

Basic usage with default settings (Python 3.13.7 and .venv directory):
```bash
pyve --init
```

With custom virtual environment directory:
```bash
pyve --init my_venv
```

With custom Python version:
```bash
pyve --init --python-version 3.10.9
```

With both custom directory and Python version:
```bash
pyve --init my_venv --python-version 3.10.9
```

You can also use shortened parameter forms:
```bash
pyve -i my_venv
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
pyve --python-version 3.13.7
```

This will set the requested Python version locally in the current directory using either asdf or pyenv (auto-installing the version if available), without creating a virtual environment or configuring direnv.

### Remove a Python Virtual Environment

```bash
pyve --purge [directory_name]
# or 
pyve -p [directory_name]
```

This removes all artifacts created by the initialization:
- .venv directory (or custom named directory)
- .tool-versions file (asdf configuration) or .python-version file (pyenv configuration)
- .envrc file (direnv configuration)
- .env file
- Removes the related patterns from .gitignore (but keeps the file itself)

### Additional Commands

```bash
pyve --help        # or -h: Show help message
pyve --version     # or -v: Show script version (current: 0.2.5)
pyve --config      # or -c: Show configuration details
pyve --install     # Install to ~/.local/bin and create 'pyve' symlink
pyve --uninstall   # Remove installed script and 'pyve' symlink from ~/.local/bin
```

## Troubleshooting

The script performs prerequisite checks before initialization to ensure all required tools are available. If any tool is missing, it will provide an error message indicating what needs to be installed.

The script is compatible with current macOS command-line (Z shell). Future support for other shells and platforms is planned.

Backward compatibility: If you prefer not to install, you can still run the script directly via its path (e.g., `~/pyve.sh --init`).

### Uninstallation

To remove the installed files:

```bash
pyve --uninstall
```

This removes `$HOME/.local/bin/pyve` and `$HOME/.local/bin/pyve.sh`. If `$HOME/.local/bin` was added to your PATH via `~/.zprofile`, you may remove that line manually if desired.

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the LICENSE file for details.

## Copyright

Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)

