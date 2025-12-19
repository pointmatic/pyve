# Pyve: Python Virtual Environment Manager

Pyve is a focused command-line tool that simplifies setting up and managing Python virtual environments on macOS and Linux. It combines Python version management, virtual environments, and direnv in a single, easy-to-use script.

## Key Features
- **Install**: The Pyve script will install itself into `~/.local/bin/` in your home directory, add a path to that, and create a symlink so you can run Pyve like a native command instead of the clunky `./pyve.sh` syntax.
- **Init**: Pyve will automatically initialize your Python coding environment as a virtual environment with your specified (or the default) version of Python and configure `direnv` to autoactivate and deactivate your virtual environment when you change directories. 
- **Purge**: Remove all the Pyve artifacts, except if you've modified the `.env` file, Pyve will leave it and let you know that.

## Requirements

- macOS or Linux with Bash
- Either of these Python version managers:
  - **asdf** (recommended, with Python plugin). Pyve auto-installs requested Python versions.
  - **pyenv**. Pyve auto-installs requested Python versions.
- **direnv** (required for `--init`; not required for standalone `--python-version`)

The script checks for prerequisites and provides helpful error messages if anything is missing.

## Quick Start

Copy and paste this into your macOS terminal:

```bash
git clone git@github.com:pointmatic/pyve.git; cd pyve; ./pyve.sh --install; pyve --help
```

### Initialize a Python Virtual Environment

Go to the root of your project directory and run `pyve --init` to initialize your Python virtual environment. 

In a single command, Pyve will:

- **Set Python version**: Uses asdf or pyenv to set the Python version (default: 3.13.7)
- **Create virtual environment**: Creates `.venv` directory with Python venv
- **Configure direnv**: Sets up `.envrc` for automatic activation when entering the directory
- **Create .env file**: Sets up a secure environment variables file (`chmod 600`)
- **Update .gitignore**: Adds appropriate patterns to keep secrets out of version control

### Purge

Run `pyve --purge` to cleanly remove all Pyve-created artifacts:

- Removes `.venv` directory
- Removes `.tool-versions` or `.python-version` file
- Removes `.envrc` file
- **Smart .env handling**: Only removes `.env` if empty; preserves files with your data
- Cleans up `.gitignore` patterns (keeps the file itself)

## Installation

1. Clone this repository:
   ```bash
   git clone git@github.com:pointmatic/pyve.git
   cd pyve
   ```

2. Install to your local bin directory:
   ```bash
   ./pyve.sh --install
   ```

This will:
- Create `~/.local/bin` (if needed)
- Copy `pyve.sh` and `lib/` helpers to `~/.local/bin`
- Create a `pyve` symlink
- Add `~/.local/bin` to your PATH (via `~/.zprofile` or `~/.bash_profile`)
- Create `~/.local/.env` template for shared environment variables

After installation, run `pyve` from any directory.

## Usage

### Initialize a Python Virtual Environment

```bash
pyve --init                          # Default: Python 3.13.7, .venv directory
pyve --init my_venv                  # Custom venv directory name
pyve --init --python-version 3.12.0  # Specific Python version
pyve --init --local-env              # Copy ~/.local/.env template to .env
pyve -i                              # Short form
```

After setup, run `direnv allow` to activate the environment.

### Set Python Version Only

```bash
pyve --python-version 3.13.7
```

Sets the Python version in the current directory (via asdf or pyenv) without creating a virtual environment.

### Remove Environment

```bash
pyve --purge                         # Remove all artifacts
pyve --purge my_venv                 # Remove custom-named venv
pyve -p                              # Short form
```

### All Commands

```bash
pyve --init, -i       # Initialize Python virtual environment
pyve --purge, -p      # Remove environment artifacts
pyve --python-version # Set Python version only
pyve --install        # Install pyve to ~/.local/bin
pyve --uninstall      # Remove pyve from ~/.local/bin
pyve --help, -h       # Show help
pyve --version, -v    # Show version
pyve --config, -c     # Show configuration
```

## Configuration

### Environment Variables
- **Project-specific**: `.env` file in your project root for secrets and environment variables
- **User template**: `~/.local/.env` serves as a template copied to new projects with `--init --local-env`

### CLI Flags
Run `pyve --help` for all available commands and options.

## Uninstallation

```bash
pyve --uninstall
```

This removes:
- `~/.local/bin/pyve` symlink
- `~/.local/bin/pyve.sh` script
- `~/.local/bin/lib/` helper scripts
- `~/.local/.env` (only if empty)
- PATH entry from shell profile (if added by pyve)

## Contributing

See `CONTRIBUTING.md` for contribution guidelines.

## Troubleshooting

The script checks for prerequisites (asdf/pyenv, direnv) before initialization and provides helpful error messages if anything is missing.

**Direct execution**: You can run the script directly without installing: `./pyve.sh --init`

## Security

- **Never commit secrets**: Pyve automatically adds `.env` to `.gitignore`
- **Restricted permissions**: `.env` files are created with `chmod 600` (owner read/write only)
- **Smart purge**: Non-empty `.env` files are preserved during purge to prevent data loss

## Future Feature Ideas
- Create a Python or Homebrew package for installation
- Version management tool installation:
   - Automated installation of asdf
   - Automated installation of pyenv
   - Automated addition of Python plugin using asdf or pyenv
   - Automated installation of a Python version using either asdf or pyenv

## License

Mozilla Public License Version 2.0 - see LICENSE file.

## Copyright

Copyright (c) 2025 Pointmatic (https://www.pointmatic.com)

## Acknowledgments

Thanks to the asdf, pyenv, and direnv communities for their excellent tools.
