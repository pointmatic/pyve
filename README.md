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

Go to the root of your git project directory and run `pyve --init` to initialize your Python virtual environment. 

In that single shell command, Pyve will:

- **Run asdf or pyenv**: No need to interact directly with `asdf` or `pyenv` tools anymore to install Python versions set a specific Python version. Pyve defaults to a configured stable Python version (usually the latest), but it is customizable.
- **Create a virtual environment**: Yes, instead of having to set up and manually activate or deactivate your virtual environment, Pyve does it for you.
- **Auto-activate and auto-deactivate**: Using `direnv`, Pyve configures your project to automatically activate/deactivate your environment when you enter/exit the project directory
- **Create/copy .env**: Yet another little detail, but Pyve will set up an empty secrets/environment variable file or copy your default secrets file into your project directory. The secure `.env` file has `chmod 600` permissions (read and write for owner only)
- **Add .gitignore**: Automatically add appropriate patterns to .gitignore, including your `.env` file so your secrets are not committed to your repository. 
- **Foundation Documenation**: Copy foundation documentation (great for any project) from Pyve template library into your project directory

### Purge

And similarly, in a single shell command (`pyve --purge`), Pyve will:
- **Cleanly remove**: Actually, it gently and cleanly removes Pyve. If you have added your own secrets to the `~/.local/.env` file, it will not remove it. If you have modified any of the documentation files, it will leave any that you have modified. Even if Pyve was the creator of the .gitignore file, it will only remove the patterns that Pyve added. 

### Comprehensive Documentation

You can list all the documentation packages (`pyve --list`) to see all the topics Pyve can help you with. 

Topics include:
- Technical design
- Implementation options
- Codebase specs
- Formal version management tracking

### LLM collaboration

With Pyve, you can more easily use LLMs to generate documentation, plan and break downfeatures, implement bite-size chunks, fix bugs, and develop other project artifacts. It includes an LLM onramp doc (`docs/guides/llm_onramp_guide.md`) you can hand to your LLM to get started.

### Other
There are several other commands described below.

## Installation

### Concepts

#### Installation
Pyve is mostly automatic, but it needs to be "installed" into the user's home directory. In the process it will update your PATH variable to include the Pyve script path so it can be run from any directory. The script is installed to `~/.local/bin` and a convenience symlink `pyve` is created in the same directory. After that, you can just type `pyve` to see the help message, and you're ready to go!

#### Initialization

1. Pyve will help the Python developer initialize a new Python project in seconds in a virtual environment with automatic activation/deactivation.
2. It also copies some foundation documentation from its template library into your git project directory.

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
2. Automatically install it to your local bin directory and create a convenience symlink `pyve`:
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
pyve --help                           # or -h: Show help message
pyve --version                        # or -v: Show script version
pyve --config                         # or -c: Show configuration details
pyve --install                        # Install to ~/.local/bin and create 'pyve' symlink
pyve --uninstall                      # Remove installed script and 'pyve' symlink from ~/.local/bin
pyve --update                         # Update documentation templates from source repo to ~/.pyve/templates/
pyve --upgrade                        # Upgrade local project templates to newer version from ~/.pyve/templates/
pyve --list                           # List available and installed documentation packages
pyve --add <package> [pkg2 ...]       # Add one or more documentation packages (e.g., web, persistence, llm_qa)
pyve --remove <package> [pkg2 ...]    # Remove one or more documentation packages
pyve --init --local-env               # Initialize with .env copied from ~/.local/.env template
```

## Configuration

Pyve has minimal configuration requirements:

### Environment Variables
- **Project-specific**: Use `.env` file in your project root for secrets and environment variables
- **User template**: `~/.local/.env` serves as a template that can be copied to new projects with `--init --local-env`

### Configuration Files
- **`~/.pyve/source_path`**: Records pyve source repository location for install handoff
- **`~/.pyve/templates/`**: Template cache directory (organized by version)
- **`.pyve/version`**: Tracks installed template version (per project, never committed)
- **`.pyve/status/`**: Operation logs (init, upgrade, purge timestamps)
- **`.pyve/packages.conf`**: Tracks installed documentation packages (per project)

### CLI Flags
See `pyve --help` for all available commands and options.

## Development

### Contributing
Follow the contribution process in `CONTRIBUTING.md`.

### Key Documentation
- **Project context**: `docs/context/project_context.md` - Business and organizational context for Pyve
- **Dependency policy**: `docs/guides/dependencies_guide.md` - Version management and dependency practices
- **Testing guidelines**: `docs/guides/testing_guide.md` - Testing strategies and commands
- **Planning/design**: `docs/guides/planning_guide.md`, `docs/specs/technical_design_spec.md` - Feature planning and design process
- **Decision log**: `docs/specs/decisions_spec.md` - Architectural and technical decisions with rationale
- **Version history**: `docs/specs/versions_spec.md` - Detailed change tracking and release notes
- **Codebase spec**: `docs/specs/codebase_spec.md` - Components, runtime, build, and quality standards
- **Implementation options**: `docs/specs/implementation_options_spec.md` - Technology choices and trade-offs

### LLM Collaboration
If working with an LLM on Pyve development:
- Start with `docs/guides/llm_onramp_guide.md` for reading order and operating rules
- Use `docs/guides/llm_qa/` for structured Q&A sessions across development phases
- Begin with Project Context Q&A (`docs/guides/llm_qa/project_context_questions.md`) before technical work

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

## Security

### File Safety
Pyve is designed to be gentle with your files:
- **Non-destructive by default**: Won't overwrite files that differ from templates
- **Smart upgrades**: Preserves modified files and creates suffixed copies (e.g., `filename__t__v0.4.md`) for manual review
- **Interactive prompts**: Asks for confirmation before making changes when conflicts are detected
- **Explicit permissions**: Like direnv, requires `direnv allow` before activation

### Secrets Management
- **Never commit secrets**: Pyve automatically adds `.env` and `.pyve/` to `.gitignore`
- **Restricted permissions**: `.env` files are created with `chmod 600` (owner read/write only)
- **Local state protection**: `~/.local/.env` template also has `chmod 600` permissions
- **Least-privilege**: Follow least-privilege principles for credentials and tokens

### Development Safety
Scripts that modify local files carry inherent risk. Pyve mitigates this by:
- Checking for existing files before creating new ones
- Preserving user modifications during upgrades
- Providing clear status messages about what will be changed
- Logging detailed operations to `.pyve/status/` for audit trails

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the LICENSE file for details.

## Copyright

Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)

## Acknowledgments

- Built with inspiration from modern Python development workflows
- Thanks to the asdf, pyenv, and direnv communities for their excellent tools
- Documentation structure influenced by design thinking and LLM collaboration patterns

