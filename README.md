# Pyve: Python Virtual Environment Configurator

Pyve is an opinionated command-line tool that simplifies setting up and managing Python virtual environments, and supports developer in planning, building, testing, and maintaining a project from v0.0 to production release v1.0. It combines several best practices made available in a single, easy-to-use script.

## Requirements

- macOS with Z shell (future support for bash/Linux/WSL)
- Either of these Python version managers:
  - asdf (with Python plugin added). Pyve will auto-install the requested Python version via `asdf install python <version>` if available.
  - pyenv. Pyve will auto-install the requested Python version via `pyenv install -s <version>` if available.
- direnv (required for the `--init` flow; not required for standalone `--python-version`)

The script will check for these prerequisites before initialization and provide helpful error messages if anything is missing.

## Quick Start

Copy and paste this into your macOS terminal:

```bash
git clone git@github.com:pointmatic/pyve.git; cd pyve; ./pyve.sh --install; pyve --help
```

### Initialize a Python Virtual Environment

In a single shell command (`pyve --init`), Pyve will:

- **Flexible Python Version Management**: Use either asdf or pyenv to set a specific Python version (default 3.13.7, but customizable)
- **Virtual Environment Creation**: Create a Python virtual environment in your project directory
- **Auto-activation**: Configure direnv to automatically activate/deactivate your environment when you enter/exit the directory
- **Environment Variable Management**: Create a secure .env file for storing environment variables (with chmod 600 permissions)
- **Git Integration**: Automatically add appropriate patterns to .gitignore
- **Foundation Documenation**: Copy foundation documentation (great for any project) from Pyve template library into your project directory

### Purge

And similarly, in a single shell command (`pyve --purge`), Pyve will:
- **Clean Removal**: Easily remove all virtual environment artifacts with a single command

### Comprehensive Documentation

You can list all the documentation packages (`pyve --list`) to see all the topics Pyve can help you with. 

Pyve also supports your project with comprehensive documentation, including:
- Technical design
- Implementation options
- Codebase specs
- Formal version management tracking

### LLM collaboration

With Pyve, you can more easily use LLMs to generate documentation, plan and break downfeatures, implement bite-size chunks, fix bugs, and develop other project artifacts. 

### Other
There are several other commands described below.

## Installation

### Concepts

#### Installation
It is important to understand some basics about how Pyve works. It needs to be "installed" into the user's home directory, and have the PATH variable updated to include it so it can be run from any directory. The script is installed to `~/.local/bin` and a convenience symlink `pyve` is created in the same directory. The script is made executable and the `pyve` symlink is created.

#### Initialization

1. Pyve will help the Python developer initialize a new Python project in seconds in a virtual environment with automatic activation/deactivation.
2. It also copies some foundation documentation from its template library into the project directory.

#### Documentation Packages

Pyve has a comprehensive library of documentation packages that help you explore all the features you might need. These can help you decide on and document which features to use in your project and record them in your project specs (`docs/specs/`).
- Analytics
- Infrastructure
- Persistence
- Web

#### LLM Q&A

Pyve can assist you with step-by-step Q&A across 16 phases of software development:

##### Foundation Phases (All Projects) ✅
- Phase 0: Project Basics (10 questions)
- Phase 1: Core Technical (13 questions)

##### Production Readiness Phases (production/secure) ✅
- Phase 2: Infrastructure (6 questions)
- Phase 3: Authentication & Authorization (6 questions)
- Phase 4: Security Basics (5 questions)
- Phase 5: Operations (8 questions)

##### Feature-Specific Phases (As Needed) ✅
- Phase 6: Data & Persistence (5 questions)
- Phase 7: User Interface (6 questions)
- Phase 8: API Design (5 questions)
- Phase 9: Background Jobs (5 questions)
- Phase 10: Analytics & Observability (5 questions)

##### Secure/Compliance Phases (secure Quality Only) ✅
- Phase 11: Threat Modeling (3 questions)
- Phase 12: Compliance Requirements (5 questions)
- Phase 13: Advanced Security (5 questions)
- Phase 14: Audit Logging (2 questions)
- Phase 15: Incident Response (4 questions)
- Phase 16: Security Governance (4 questions)

### Installation Steps

1. Clone this repository
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

Notes:
- If run outside the source repo, `pyve --install` will delegate to the recorded source path from `~/.pyve/source_path` so the latest repo code is installed.
- If run inside the source repo but invoked via the installed binary, it hands off to local `./pyve.sh --install` to ensure the repo version is used.
- If the target `~/.local/bin/pyve.sh` already matches the current script, copying is skipped without error; the executable bit and `pyve` symlink are still ensured.

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

Template initialization notes (v0.3.2+):
- Copies documentation templates from `~/.pyve/templates/{latest}` into the repo.
- Fails if copying would overwrite non-identical files.
- Records the tool version to `./.pyve/version` and writes a status marker at `./.pyve/status/init`.
- Idempotent: if only benign status files (`init`, `init_copy.log`, `.DS_Store`) are present, it skips copying and prints a clear message.
- Detailed copy logs are written to `./.pyve/status/init_copy.log`.
- The last message printed is a reminder to run `direnv allow`.

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

Template purge notes (v0.3.3):
- Removes only documentation files that are byte-for-byte identical to the recorded template version (`v{major.minor}`).
- Modified files are preserved with a warning; they are not deleted.
- Writes purge status to `./.pyve/status/purge` and fails fast if other status files exist at start.

### Additional Commands

```bash
pyve --help        # or -h: Show help message
pyve --version     # or -v: Show script version
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

### Future Feature Ideas
- Create Python or Homebrew package for installation
- Choice of various standard software licenses to automatically install into your project
- Version management tool installation:
   - Automated installation of asdf
   - Automated installation of pyenv
   - Automated addition of Python plugin using asdf or pyenv
   - Automated installation of a Python version using either asdf or pyenv
- Support for other platforms:
   - Windows Subsystem for Linux (WSL)
   - bash
   - Linux

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the LICENSE file for details.

## Copyright

Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)

