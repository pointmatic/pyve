# Pyve Version History
See `docs/guide_versions_spec.md`

---

## v0.7.13a: Update README.md - Core Features [Implemented]
- [x] Add "Backend Selection" section to README.md
- [x] Document auto-detection priority (environment.yml → config → venv)
- [x] Add backend selection examples
- [x] Document `--backend` flag usage
- [x] Add backend comparison table (venv vs micromamba)

### Notes
**Goal:** Document backend selection and auto-detection.

**Implementation Summary:**
- Enhanced README.md with comprehensive backend documentation
- Added detailed auto-detection priority section with code examples
- Created backend comparison table with 11 feature comparisons
- Added practical examples for each auto-detection scenario
- Documented when to use each backend

**Changes to README.md:**
- Enhanced "Backend Auto-Detection Priority" section with:
  - Numbered priority list with code examples
  - Practical usage examples for each scenario
  - Override examples
- Added "Backend Comparison" table with:
  - Feature-by-feature comparison (venv vs micromamba)
  - "When to use venv" guidance
  - "When to use micromamba" guidance

**Backend Comparison Table Includes:**
- Package manager (pip vs conda/mamba)
- Best use cases
- Binary dependencies support
- Environment file formats
- Lock file formats
- Activation methods
- Speed comparison
- Disk space requirements
- Cross-platform support
- Channel support
- Python version management

**Auto-Detection Examples Added:**
- Project with environment.yml → micromamba
- Project with requirements.txt → venv
- Empty project → venv (default)
- Override with --backend flag

**Testing Results:**
- ✓ All examples are accurate and runnable
- ✓ Backend selection clearly explained
- ✓ Comparison table comprehensive
- ✓ Auto-detection priority well-documented

---

### v0.7.13b: Update README.md - Micromamba Features
**Goal:** Document micromamba-specific features.

- [ ] Add "Micromamba Bootstrap" section
- [ ] Document auto-bootstrap and manual bootstrap
- [ ] Add `--auto-bootstrap` and `--bootstrap-to` flag documentation
- [ ] Document environment naming resolution
- [ ] Add lock file validation documentation

**Testing:**
- Bootstrap instructions work as documented
- Environment naming examples accurate

---

### v0.7.13c: Update README.md - Commands and CI/CD
**Goal:** Document new commands and CI/CD usage.

- [ ] Add `pyve run` command section with examples
- [ ] Add `pyve doctor` command section with examples
- [ ] Add `--no-direnv` flag documentation
- [ ] Add "CI/CD Integration" section
- [ ] Add GitHub Actions and GitLab CI examples

**Testing:**
- Command examples work correctly
- CI/CD examples are functional

---

### v0.7.13d: Create CI/CD Examples Documentation
**Goal:** Comprehensive CI/CD integration guide.

- [ ] Create `docs/ci-cd-examples.md`
- [ ] Add GitHub Actions workflows (venv and micromamba)
- [ ] Add GitLab CI examples
- [ ] Document caching strategies for both backends
- [ ] Add Docker examples
- [ ] Add troubleshooting section

**Testing:**
- All CI/CD examples tested and working
- Caching strategies verified

---

### v0.7.13e: Update Contributing and Examples
**Goal:** Update developer documentation.

- [ ] Update `CONTRIBUTING.md` with backend architecture
- [ ] Add testing guidelines for both backends
- [ ] Document module structure (lib/micromamba_*.sh)
- [ ] Add examples to `docs/specs/pyve-run-examples.md`
- [ ] Add backend-specific examples
- [ ] Add error handling examples

**Testing:**
- Architecture documentation accurate
- Examples comprehensive and working

---

### v0.7.13f: Final Testing and Polish
**Goal:** Comprehensive testing and final polish.

- [ ] Test all commands with venv backend
- [ ] Test all commands with micromamba backend
- [ ] Test on clean macOS system
- [ ] Test on clean Linux system
- [ ] Test upgrade path from v0.6.6
- [ ] Test CI/CD workflows (GitHub Actions, GitLab CI)
- [ ] Review all help text for completeness
- [ ] Fix any discovered issues

**Testing:**
- All commands work correctly on both backends
- Upgrade path is smooth
- CI/CD workflows functional
- Help text complete and accurate

---

## v0.7.12 `pyve doctor` Command [Implemented]
- [x] Add `pyve doctor` command
- [x] Check and report backend type (venv or micromamba)
- [x] Check and report environment location
- [x] Check and report Python version
- [x] Check and report environment file (environment.yml, conda-lock.yml)
- [x] Check and report lock file status (up to date, stale, missing)
- [x] Check and report micromamba version (if applicable)
- [x] Check and report package count
- [x] Color-coded status indicators (✓ ✗ ⚠)

### Notes
**Goal:** Implement environment health check and diagnostics.

**Implementation Summary:**
- Added `doctor_command()` function to `pyve.sh`
- Comprehensive diagnostics for both venv and micromamba backends
- Automatic backend detection
- Color-coded status indicators for quick visual feedback
- Detailed reporting of environment health

**Changes to `pyve.sh`:**
- Version bumped from 0.7.11 to 0.7.12
- Added `doctor_command()` function (170+ lines)
- Added `doctor` command to main CLI parser
- Updated help text with doctor command documentation
- Added doctor example to EXAMPLES section

**Checks Performed:**

**Common Checks (both backends):**
- ✓ Backend type detection
- ✓ Environment location
- ✓ Python version
- ✓ Direnv configuration (.envrc)
- ✓ Environment file (.env)
- ✓ Package count

**Venv-Specific Checks:**
- ✓ Venv directory exists
- ✓ Python executable in venv
- ✓ Version file (.tool-versions or .python-version)
- ✓ Package count from site-packages

**Micromamba-Specific Checks:**
- ✓ Micromamba binary (path, location, version)
- ✓ Environment directory
- ✓ Environment name
- ✓ Python in environment
- ✓ Environment file (environment.yml or conda-lock.yml)
- ✓ Lock file status (up to date, stale, missing)
- ✓ Package count from conda-meta

**Status Indicators:**
- `✓` - Success/OK
- `✗` - Error/Not found
- `⚠` - Warning/Issue detected

**Example Output (Venv):**
```
Pyve Environment Diagnostics
=============================

✓ Backend: venv
✓ Environment: .venv
✓ Python: 3.13.7
✓ Version file: .tool-versions (asdf)
  Python: 3.13.7
  Packages: 42 installed
✓ Direnv: .envrc configured
✓ Environment file: .env (configured)
```

**Example Output (Micromamba):**
```
Pyve Environment Diagnostics
=============================

✓ Backend: micromamba
✓ Micromamba: /Users/user/.pyve/bin/micromamba (user) v1.5.3
✓ Environment: .pyve/envs/myproject
  Name: myproject
✓ Python: 3.11.7
✓ Environment file: environment.yml
⚠ Lock file: conda-lock.yml (stale)
  environment.yml: 2026-01-06 02:15:30
  conda-lock.yml:  2026-01-05 18:42:15
  Packages: 87 installed
✓ Direnv: .envrc configured
✓ Environment file: .env (configured)
```

**Example Output (No Environment):**
```
Pyve Environment Diagnostics
=============================

✗ No environment found
  Run 'pyve --init' to create an environment
```

**Testing Results:**
- ✓ `pyve --version` shows 0.7.12
- ✓ `pyve doctor` works correctly
- ✓ Reports correct status for venv backend
- ✓ Backend detection works
- ✓ Status indicators display correctly
- ✓ Package counting works
- ✓ Help text includes doctor command

**Use Cases:**

**Quick Health Check:**
```bash
pyve doctor
# Shows environment status at a glance
```

**Debugging Issues:**
```bash
pyve doctor
# Identifies missing files, stale lock files, etc.
```

**CI/CD Verification:**
```bash
pyve doctor
# Verify environment is set up correctly in CI
```

**Benefits:**
- **Quick diagnostics** - See environment status at a glance
- **Issue detection** - Identifies common problems automatically
- **Visual feedback** - Color-coded indicators for quick scanning
- **Comprehensive** - Checks all critical components
- **Backend-aware** - Tailored checks for venv vs micromamba

**Deferred Features:**
- `--verbose` flag for detailed output (not needed yet)
- `--backend` flag to check specific backend (not needed yet)
- These can be added when user demand arises

**Next Steps:**
- v0.7.13: Documentation and polish

---

## v0.7.11 `--no-direnv` Flag [Implemented]
- [x] Add `--no-direnv` CLI flag to `pyve --init`
- [x] Skip `.envrc` creation when flag is set
- [x] Update help text to document flag
- [x] Add to CI/CD examples in documentation
- [x] Ensure `pyve run` still works without direnv

### Notes
**Goal:** Add flag to skip direnv configuration for CI/CD.

**Implementation Summary:**
- Added `--no-direnv` flag parsing to `init()` function
- Conditional `.envrc` creation for both venv and micromamba backends
- Updated help text with flag documentation
- Added CI/CD example to help text
- Updated success messages based on direnv usage

**Changes to `pyve.sh`:**
- Version bumped from 0.7.10 to 0.7.11
- Added `no_direnv` variable to `init()` function
- Added `--no-direnv` flag parsing in argument loop
- Wrapped `init_direnv_venv()` call in conditional check
- Wrapped `init_direnv_micromamba()` call in conditional check
- Updated success messages to reflect direnv status
- Added flag to help text USAGE and COMMANDS sections
- Added CI/CD example to EXAMPLES section

**Behavior:**

**With direnv (default):**
```bash
pyve --init
# Creates .envrc
# Success message: "Run 'direnv allow' to activate the environment"
```

**Without direnv (CI/CD mode):**
```bash
pyve --init --no-direnv
# Skips .envrc creation
# Success message: "Use 'pyve run <command>' to execute commands"
```

**Key Features:**
- Works with both venv and micromamba backends
- `pyve run` still works without direnv
- Clear messaging about next steps based on mode
- Useful for CI/CD environments where direnv isn't available

**Testing Results:**
- ✓ `pyve --version` shows 0.7.11
- ✓ `--no-direnv` flag appears in help text
- ✓ Flag parsing works correctly
- ✓ Success messages updated appropriately
- ✓ CI/CD example added to help

**Use Cases:**

**CI/CD Workflows:**
```yaml
# GitHub Actions example
- name: Setup Python environment
  run: |
    pyve --init --no-direnv --backend micromamba
    pyve run pytest
```

**Docker Builds:**
```dockerfile
RUN pyve --init --no-direnv
RUN pyve run pip install -r requirements.txt
```

**Local Development (with direnv):**
```bash
pyve --init
direnv allow
# Environment auto-activates when entering directory
```

**Benefits:**
- **CI/CD friendly** - No direnv dependency required
- **Flexible** - Works with or without direnv
- **Clear messaging** - Users know what to do next
- **Backward compatible** - Default behavior unchanged

**Next Steps:**
- v0.7.12: `pyve doctor` command for diagnostics
- v0.7.13: Documentation and polish

---

## v0.7.10 `pyve run` Command Foundation [Implemented]
- [x] Add `pyve run` command to CLI
- [x] Implement `run_command()` function
- [x] Detect active backend (venv or micromamba) from filesystem
- [x] For venv backend: execute `.venv/bin/<cmd>` directly
- [x] For micromamba backend: use `micromamba run -p .pyve/envs/<name> <cmd>`
- [x] Pass through all arguments to command
- [x] Preserve exit codes using `exec`
- [x] Handle command not found errors (exit code 127)
- [x] Handle no environment found errors
- [x] Update help text with run command and examples

### Notes
**Goal:** Implement basic `pyve run <cmd>` execution.

**Implementation Summary:**
- Added `run_command()` function to `pyve.sh`:
  - Detects active backend by checking filesystem
  - Venv: checks for `.venv` directory
  - Micromamba: checks for `.pyve/envs` directory
  - Executes commands appropriately for each backend

- Updated `pyve.sh`:
  - Version bumped from 0.7.9 to 0.7.10
  - Added `run` command to main CLI parser
  - Updated help text with run command documentation
  - Added usage examples for run command

**Backend Detection Logic:**
1. Check for `.pyve/envs` directory (micromamba)
2. If found, use micromamba backend
3. Otherwise, check for `.venv` directory (venv)
4. If found, use venv backend
5. If neither found, error with helpful message

**Execution Methods:**

**Venv Backend:**
```bash
# Direct execution from venv bin
.venv/bin/<command> [args...]
```
- Checks if command exists in venv bin
- Returns exit code 127 if command not found
- Uses `exec` to preserve exit codes

**Micromamba Backend:**
```bash
# Use micromamba run with prefix
micromamba run -p .pyve/envs/<name> <command> [args...]
```
- Finds first environment in `.pyve/envs`
- Uses `micromamba run -p` for execution
- Uses `exec` to preserve exit codes

**Error Handling:**
- No environment found: Clear error message with suggestion to run `pyve --init`
- Command not found in venv: Exit code 127 with error message
- Micromamba not found: Error message
- No command provided: Usage help

**Testing Results:**
- ✓ `pyve --version` shows 0.7.10
- ✓ `pyve run` with no args shows usage error
- ✓ Error handling for no environment works
- ✓ Help text includes run command
- ✓ Examples added to help text

**Usage Examples:**
```bash
# Run Python
pyve run python --version

# Run tests
pyve run pytest

# Run script
pyve run python script.py

# Run any command with arguments
pyve run pip install requests
pyve run black .
pyve run mypy src/
```

**Key Features:**
- **Automatic backend detection** - No need to specify backend
- **Exit code preservation** - Uses `exec` to preserve command exit codes
- **Argument pass-through** - All arguments passed to command unchanged
- **Error handling** - Clear error messages for common issues
- **No activation needed** - Run commands without manual activation

**Limitations:**
- Only supports single environment per project
- Micromamba backend uses first environment found in `.pyve/envs`
- No support for running in specific named environments (future feature)

**Next Steps:**
- v0.7.11: `--no-direnv` flag for CI/CD environments
- v0.7.12: `pyve doctor` command for diagnostics
- v0.7.13: Documentation and polish

---

## v0.7.9 Shell Prompt Integration [Implemented]
- [x] Update `.envrc` generation for micromamba backend
- [x] Implement prompt format: `(backend:env_name)`
- [x] For venv backend: `export PS1="(venv:project_name) $PS1"`
- [x] For micromamba backend: `export PS1="(micromamba:$ENV_NAME) $PS1"`
- [x] Split `init_direnv()` into `init_direnv_venv()` and `init_direnv_micromamba()`
- [x] Update venv `.envrc` to include backend name in prompt

### Notes
**Goal:** Update shell prompt to show backend and environment name.

**Implementation Summary:**
- Split `init_direnv()` into two backend-specific functions:
  - `init_direnv_venv()` - Creates .envrc for venv backend with prompt
  - `init_direnv_micromamba()` - Creates .envrc for micromamba backend with prompt

- Updated `pyve.sh`:
  - Version bumped from 0.7.8 to 0.7.9
  - Renamed `init_direnv()` to `init_direnv_venv()`
  - Added `init_direnv_micromamba()` function
  - Integrated micromamba .envrc creation into init flow

**Prompt Format:**
- **Venv backend:** `(venv:project_name) $PS1`
  - Uses project directory basename for environment name
  - Example: `(venv:myproject) $`

- **Micromamba backend:** `(micromamba:env_name) $PS1`
  - Uses resolved environment name
  - Example: `(micromamba:myproject) $`

**Venv .envrc Template:**
```bash
# pyve-managed direnv configuration
# Activates Python virtual environment and loads .env

VENV_DIR=".venv"

if [[ -d "$VENV_DIR" ]]; then
    source "$VENV_DIR/bin/activate"
    # Update prompt to show backend and environment
    export PS1="(venv:project_name) $PS1"
fi

if [[ -f ".env" ]]; then
    dotenv
fi
```

**Micromamba .envrc Template:**
```bash
# pyve-managed direnv configuration
# Activates micromamba environment and loads .env

ENV_NAME="myproject"
ENV_PATH=".pyve/envs/myproject"

# Activate micromamba environment
if [[ -d "$ENV_PATH" ]]; then
    # Add environment bin to PATH
    export PATH="$ENV_PATH/bin:$PATH"
    # Update prompt to show backend and environment
    export PS1="(micromamba:$ENV_NAME) $PS1"
fi

if [[ -f ".env" ]]; then
    dotenv
fi
```

**Key Differences:**
- Venv uses `source activate` (traditional activation)
- Micromamba uses PATH manipulation (no activation script needed)
- Both show backend name in prompt for clarity

**Testing Results:**
- ✓ `pyve --version` shows 0.7.9
- ✓ `pyve --config` works correctly
- ✓ All functions load without errors
- ✓ Venv .envrc includes prompt with backend name
- ✓ Micromamba .envrc includes prompt with backend name
- ✓ Backward compatible (existing .envrc files not overwritten)

**Deferred Features:**
- Configurable prompt format via `.pyve/config` (deferred to future version)
- `prompt.show` and `prompt.format` config options (not needed yet)
- These can be added when user demand arises

**Usage Example:**
```bash
# Venv backend
pyve --init
# Creates .envrc with: export PS1="(venv:myproject) $PS1"

# Micromamba backend
pyve --init --backend micromamba
# Creates .envrc with: export PS1="(micromamba:myproject) $PS1"

# After direnv allow, prompt shows:
# (venv:myproject) $ python --version
# (micromamba:myproject) $ python --version
```

**Next Steps:**
- v0.7.10: `pyve run` command for executing commands in environment
- v0.7.11: `--no-direnv` flag for CI/CD environments
- v0.7.12: `pyve doctor` command for diagnostics

---

## v0.7.8 Micromamba Environment Creation [Implemented]
- [x] Implement `create_micromamba_env()` function
- [x] Implement `check_micromamba_env_exists()` function
- [x] Implement `verify_micromamba_env()` function
- [x] Use detected environment file (conda-lock.yml or environment.yml)
- [x] Create environment at `.pyve/envs/<env_name>`
- [x] Execute: `micromamba create -p .pyve/envs/<name> -f <file> -y`
- [x] Handle creation errors gracefully
- [x] Verify environment created successfully
- [x] Update `pyve --init` to support micromamba backend
- [x] Skip if environment already exists

### Notes
**Goal:** Create micromamba environments from environment files.

**Implementation Summary:**
- Added environment creation functions to `lib/micromamba_env.sh`:
  - `check_micromamba_env_exists()` - Check if environment directory exists
  - `create_micromamba_env()` - Create environment from file with error handling
  - `verify_micromamba_env()` - Verify environment is functional (conda-meta, python)

- Updated `pyve.sh`:
  - Version bumped from 0.7.7 to 0.7.8
  - Replaced placeholder micromamba code with actual environment creation
  - Integrated environment validation, creation, and verification
  - Added .gitignore patterns for `.pyve/envs`
  - Removed exit after micromamba backend selection

**Environment Creation Flow:**
1. Resolve and validate environment name
2. Validate lock file status (if applicable)
3. Validate environment file exists and is readable
4. Check if environment already exists (skip if yes)
5. Create environment: `micromamba create -p .pyve/envs/<name> -f <file> -y`
6. Verify environment (check conda-meta, python executable)
7. Create .env file
8. Update .gitignore

**Environment Location:**
- All micromamba environments created at: `.pyve/envs/<env_name>`
- Uses prefix-based environments (not named environments)
- Isolated per-project environments

**Error Handling:**
- Graceful failure if micromamba not found
- Clear error messages for missing/invalid environment files
- Validation of environment file before creation
- Verification after creation with helpful warnings
- Skip creation if environment already exists

**Testing Results:**
- ✓ `pyve --version` shows 0.7.8
- ✓ `pyve --config` works correctly
- ✓ All functions load without errors
- ✓ Environment creation logic integrated
- ✓ Skip logic for existing environments works
- ✓ Error handling for missing files works

**File Size:**
- `lib/micromamba_env.sh`: 475 → 593 lines (+118 lines, +3 functions)

**Usage Example:**
```bash
# Create environment.yml
cat > environment.yml << EOF
name: myproject
channels:
  - conda-forge
dependencies:
  - python=3.11
  - numpy
  - pandas
EOF

# Initialize with micromamba backend
pyve --init --backend micromamba

# Environment created at: .pyve/envs/myproject
```

**Next Steps:**
- v0.7.9: Shell prompt integration and .envrc generation for micromamba
- v0.7.10: `pyve run` command for executing commands in environment
- v0.7.11: `--no-direnv` flag for CI/CD environments

---

## v0.7.7 Code Refactoring - Modularize Micromamba [Implemented]
- [x] Split `lib/micromamba.sh` (876 lines, 24 functions) into 3 focused modules
- [x] Create `lib/micromamba_core.sh` with 5 detection functions
- [x] Create `lib/micromamba_bootstrap.sh` with 4 installation functions
- [x] Create `lib/micromamba_env.sh` with 15 environment management functions
- [x] Update `pyve.sh` to source all 3 new modules
- [x] Remove old `lib/micromamba.sh` using `git rm`
- [x] Test all functions still work correctly

### Notes
**Goal:** Improve code organization by splitting large monolithic file into focused modules.

**Rationale:**
- `lib/micromamba.sh` had grown to 876 lines with 24 functions
- Contains 5 distinct functional areas that should be separated
- Better separation of concerns improves maintainability
- Follows existing pattern (backend_detect.sh, env_detect.sh are separate)
- Makes remaining v0.7.8-v0.7.13 implementations cleaner

**Implementation Summary:**
- Created `lib/micromamba_core.sh` (148 lines, 5 functions):
  - `get_micromamba_path()` - Binary path detection
  - `check_micromamba_available()` - Availability check
  - `get_micromamba_version()` - Version extraction
  - `get_micromamba_location()` - Location type (project/user/system)
  - `error_micromamba_not_found()` - Error message helper

- Created `lib/micromamba_bootstrap.sh` (285 lines, 4 functions):
  - `get_micromamba_download_url()` - Platform-specific URL generation
  - `bootstrap_install_micromamba()` - Download, extract, install
  - `bootstrap_micromamba_interactive()` - Interactive installation menu
  - `bootstrap_micromamba_auto()` - Non-interactive installation

- Created `lib/micromamba_env.sh` (475 lines, 15 functions):
  - Environment file detection (5 functions)
  - Lock file validation (6 functions)
  - Environment naming (4 functions)

- Updated `pyve.sh`:
  - Version bumped from 0.7.6 to 0.7.7
  - Replaced single `source lib/micromamba.sh` with 3 module sources
  - Added error handling for each module

- Removed old file:
  - Used `git rm lib/micromamba.sh` to remove from repository

**File Size Comparison:**
- Before: 1 file × 876 lines = 876 lines
- After: 3 files (148 + 285 + 475 = 908 lines)
- Overhead: 32 lines (3.6%) for module headers and guards

**Testing Results:**
- ✓ `pyve --version` shows 0.7.7
- ✓ `pyve --config` works correctly
- ✓ All functions load without errors
- ✓ No functional changes, pure refactoring
- ✓ Module sourcing works correctly

**Benefits Achieved:**
- **Clearer organization** - Each file has single responsibility
- **Easier navigation** - Find functions faster by category
- **Better maintainability** - Smaller, focused files
- **Improved testability** - Can test modules independently
- **Scalability** - Room to grow each module without bloat

---

## v0.7.6 Environment Naming [Implemented]
- [x] Implement environment name resolution order (4 priorities)
- [x] Add `sanitize_environment_name()` function
- [x] Add `is_reserved_environment_name()` function
- [x] Add `validate_environment_name()` function
- [x] Add `resolve_environment_name()` function
- [x] Add `--env-name` CLI flag
- [x] Integrate name resolution into micromamba backend flow
- [x] Update help text with --env-name flag

### Notes
**Goal:** Implement environment naming resolution.

**Implementation Summary:**
- Added environment naming functions to `lib/micromamba.sh`:
  - `sanitize_environment_name()` - Sanitizes raw names (lowercase, replace special chars, ensure valid start)
  - `is_reserved_environment_name()` - Checks against reserved names (base, root, default, conda, mamba, micromamba)
  - `validate_environment_name()` - Validates name meets all requirements
  - `resolve_environment_name()` - Resolves name using priority order
- Updated `pyve.sh`:
  - Version bumped from 0.7.5 to 0.7.6
  - Added `--env-name` flag to `pyve --init`
  - Integrated name resolution and validation into micromamba backend initialization
  - Updated help text with --env-name flag

**Name Resolution Priority:**
1. CLI flag: `--env-name` (highest priority)
2. `.pyve/config` → `micromamba.env_name`
3. `environment.yml` → `name:` field
4. Project directory basename (sanitized) (lowest priority)

**Sanitization Rules:**
- Convert to lowercase
- Replace spaces and special characters with hyphens
- Keep only alphanumeric, hyphens, and underscores
- Remove leading/trailing hyphens
- Ensure starts with letter or underscore (prefix with "env-" if not)
- Truncate to max 255 characters

**Validation Rules:**
- Cannot be empty
- Cannot be reserved (base, root, default, conda, mamba, micromamba)
- Max 255 characters
- Only alphanumeric, hyphens, and underscores
- Must start with letter or underscore

**Testing Results:**
- ✓ `pyve --version` shows 0.7.6
- ✓ Sanitization works correctly (lowercase, special char replacement)
- ✓ Reserved name validation implemented
- ✓ Name resolution follows priority order
- ✓ `--env-name` flag added and parsed correctly
- ✓ Integration into micromamba backend flow complete

**Usage Examples:**
```bash
# Explicit name via CLI flag (highest priority)
pyve --init --backend micromamba --env-name my-project

# Name from .pyve/config
# config file: micromamba.env_name: myproject
pyve --init --backend micromamba

# Name from environment.yml
# environment.yml: name: MyProject
pyve --init --backend micromamba

# Name from directory (sanitized)
# Directory: "My Cool Project!" → sanitized to: "my-cool-project"
pyve --init --backend micromamba
```

**Sanitization Examples:**
- `"My Project"` → `"my-project"`
- `"123test"` → `"env-123test"` (must start with letter/underscore)
- `"Project_Name"` → `"project_name"`
- `"my@special#project!"` → `"my-special-project"`

**Note:** `pyve doctor` command will be implemented in v0.7.11 to show resolved environment name.

---

## v0.7.5 Lock File Validation [Implemented]
- [x] Implement lock file staleness detection
- [x] Compare modification times: `mtime(environment.yml) > mtime(conda-lock.yml)`
- [x] Add interactive warning for stale lock files with "Continue anyway?" prompt
- [x] Add info message for missing lock file
- [x] Only show warnings in interactive mode (not CI)
- [x] Add `--strict` flag to error on stale/missing lock files
- [x] Add `is_interactive()` function to detect terminal
- [x] Add `is_lock_file_stale()` function
- [x] Add `get_file_mtime_formatted()` function
- [x] Add `warn_stale_lock_file()` function
- [x] Add `info_missing_lock_file()` function
- [x] Add `validate_lock_file_status()` function

### Notes
**Goal:** Warn users about stale or missing lock files.

**Implementation Summary:**
- Added lock file validation functions to `lib/micromamba.sh`:
  - `is_lock_file_stale()` - Compares modification times (macOS and Linux compatible)
  - `get_file_mtime_formatted()` - Returns human-readable timestamps
  - `is_interactive()` - Detects if stdin is a terminal
  - `warn_stale_lock_file()` - Interactive warning with "Continue anyway?" prompt
  - `info_missing_lock_file()` - Info message about missing lock file
  - `validate_lock_file_status()` - Main validation function with strict mode support
- Updated `pyve.sh`:
  - Version bumped from 0.7.4 to 0.7.5
  - Added `--strict` flag to `pyve --init`
  - Integrated `validate_lock_file_status()` into micromamba backend initialization
  - Updated help text with --strict flag

**Interactive Warning (Stale Lock File):**
```
WARNING: Lock file may be stale
  environment.yml:  modified 2026-01-05 10:30:00
  conda-lock.yml:   modified 2025-12-15 14:20:00

Using conda-lock.yml for reproducibility.
To update lock file:
  conda-lock -f environment.yml -p arm64

Continue anyway? [y/n]: _
```

**Info Message (Missing Lock File):**
```
INFO: Using environment.yml without lock file.

For reproducible builds, consider generating a lock file:
  conda-lock -f environment.yml -p arm64

This is especially important for CI/CD and production.

Continue anyway? [y/n]: _
```

**Behavior Modes:**
1. **Interactive mode** (terminal detected):
   - Stale lock file → warn and prompt
   - Missing lock file → info and prompt
   - User can continue or abort

2. **Non-interactive mode** (CI/batch):
   - Silent, no prompts
   - Continues with detected files
   - Suitable for automated workflows

3. **Strict mode** (`--strict` flag):
   - Stale lock file → error and exit
   - Missing lock file → error and exit
   - Enforces reproducible builds

**Testing Results:**
- ✓ `pyve --version` shows 0.7.5
- ✓ Staleness detection works (compares file mtimes)
- ✓ Interactive mode detection works (`is_interactive()`)
- ✓ `--strict` flag added and parsed correctly
- ✓ Validation integrated into micromamba backend flow
- ✓ Platform-specific mtime handling (macOS `stat -f`, Linux `stat -c`)

**Usage Examples:**
```bash
# Interactive mode (default) - prompts user
pyve --init --backend micromamba

# Strict mode - errors on stale/missing lock files
pyve --init --backend micromamba --strict

# CI mode (non-interactive) - silent, no prompts
echo | pyve --init --backend micromamba --auto-bootstrap
```

**Note:** `pyve doctor` command will be implemented in v0.7.11 to provide comprehensive diagnostics including lock file status checks.

---

## v0.7.4 Environment File Detection [Implemented]
- [x] Implement `detect_environment_file()` function
- [x] Detection order: conda-lock.yml → environment.yml → error
- [x] Add YAML validation for environment.yml
- [x] Parse environment.yml for name, channels, dependencies
- [x] Add `parse_environment_name()` function
- [x] Add `parse_environment_channels()` function
- [x] Add `validate_environment_file()` function
- [x] Add `error_no_environment_file()` function
- [x] Update `pyve --config` to show detected files

### Notes
**Goal:** Detect and validate environment.yml and conda-lock.yml files.

**Implementation Summary:**
- Added environment file detection functions to `lib/micromamba.sh`:
  - `detect_environment_file()` - Detects conda-lock.yml or environment.yml (priority order)
  - `parse_environment_name()` - Extracts `name:` field from environment.yml
  - `parse_environment_channels()` - Extracts `channels:` list from environment.yml
  - `validate_environment_file()` - Validates file exists and has required fields
  - `error_no_environment_file()` - Displays helpful error with example
- Updated `pyve.sh`:
  - Version bumped from 0.7.3 to 0.7.4
  - Enhanced `show_config()` to display detected environment file and name

**Detection Order:**
1. `conda-lock.yml` (highest priority - for reproducible builds)
2. `environment.yml` (fallback - for flexible dependencies)
3. Error if neither exists

**YAML Parsing:**
- Uses awk for portable parsing (no external dependencies)
- Extracts `name:` field for environment naming
- Extracts `channels:` list (space-separated)
- Validates `dependencies:` field exists (required)

**Validation:**
- Checks file exists and is readable
- For environment.yml:
  - Warns if `name:` missing (will derive from project directory)
  - Warns if `channels:` missing (will use defaults)
  - Errors if `dependencies:` missing (required field)
- For conda-lock.yml:
  - No validation (assumes valid lock file)

**Testing Results:**
- ✓ `pyve --version` shows 0.7.4
- ✓ Detects environment.yml and extracts name field
- ✓ Detects conda-lock.yml preferentially over environment.yml
- ✓ Shows "none" when no environment files present
- ✓ `pyve --config` displays: `Conda env file: environment.yml (name: testproject)`
- ✓ `pyve --config` displays: `Conda env file: conda-lock.yml` (when lock file present)
- ✓ Parsing works correctly for environment name extraction

**Example Output:**
```bash
$ pyve --config
pyve configuration:
  ...
  Conda env file:         environment.yml (name: testproject)
  ...
```

**Error Message (when no files found):**
```
ERROR: No environment file found for micromamba backend

Micromamba requires either:
  - conda-lock.yml (for reproducible builds)
  - environment.yml (for flexible dependencies)

Create environment.yml with:
  name: myproject
  channels:
    - conda-forge
  dependencies:
    - python=3.11
    - numpy
```

**Note:** `pyve doctor` command will be implemented in v0.7.11 to provide comprehensive diagnostics including environment file validation.

---

## v0.7.3 Micromamba Bootstrap (Interactive) [Implemented]
- [x] Implement interactive bootstrap prompt with 4 options
- [x] Implement bootstrap download and installation
- [x] Add `--auto-bootstrap` flag for non-interactive mode
- [x] Add `--bootstrap-to` flag (project, user)
- [x] Download from official micromamba releases
- [x] Extract tarball and install binary
- [x] Set executable permissions
- [x] Verify installation works

### Notes
**Goal:** Allow users to install micromamba when missing.

**Implementation Summary:**
- Added bootstrap functions to `lib/micromamba.sh`:
  - `get_micromamba_download_url()` - Determines correct download URL for platform (macOS arm64/x86_64, Linux x86_64/aarch64/ppc64le)
  - `bootstrap_install_micromamba()` - Downloads tarball, extracts binary, installs to specified location
  - `bootstrap_micromamba_interactive()` - Interactive menu with 4 options
  - `bootstrap_micromamba_auto()` - Non-interactive installation for CI/CD
- Updated `pyve.sh`:
  - Version bumped from 0.7.2 to 0.7.3
  - Added `--auto-bootstrap` flag to `pyve --init`
  - Added `--bootstrap-to` flag (project, user) to `pyve --init`
  - Integrated bootstrap into `init()` when micromamba backend selected
  - Updated help text with new flags

**Interactive Bootstrap Menu:**
```
ERROR: Backend 'micromamba' required but not found.

Detected: environment.yml
Required: micromamba

Installation options:
  1. Install to project sandbox: .pyve/bin/micromamba
  2. Install to user sandbox: ~/.pyve/bin/micromamba
  3. Install via system package manager (brew/apt)
  4. Abort and install manually

Choice [1]: _
```

**Download and Installation:**
- Downloads from official micromamba API: `https://micro.mamba.pm/api/micromamba/{platform}/latest`
- Supports platforms: osx-arm64, osx-64, linux-64, linux-aarch64, linux-ppc64le
- Extracts tarball (micromamba is distributed as tar.gz with bin/micromamba inside)
- Verifies binary is executable
- Tests that binary runs (`micromamba --version`)

**Testing Results:**
- ✓ `pyve --version` shows 0.7.3
- ✓ `--auto-bootstrap` flag downloads and installs micromamba successfully
- ✓ `--bootstrap-to project` installs to `.pyve/bin/micromamba`
- ✓ `--bootstrap-to user` installs to `~/.pyve/bin/micromamba`
- ✓ Downloaded micromamba v2.4.0 works correctly
- ✓ Tarball extraction works (fixed from initial raw binary assumption)
- ✓ Installation verified with `micromamba --version`
- ✓ `pyve --config` shows micromamba as available after bootstrap

**CI/CD Usage:**
```bash
# Auto-bootstrap to user sandbox (default)
pyve --init --backend micromamba --auto-bootstrap

# Auto-bootstrap to project sandbox
pyve --init --backend micromamba --auto-bootstrap --bootstrap-to project
```

**Note:** Full micromamba environment creation will be implemented in v0.7.4-v0.7.12. This version only handles micromamba binary installation.

---

## v0.7.2 Micromamba Binary Detection [Implemented]
- [x] Create `lib/micromamba.sh` library
- [x] Implement micromamba detection order (project → user → system)
- [x] Add `get_micromamba_path()` function
- [x] Add `check_micromamba_available()` function
- [x] Add version detection: `micromamba --version`
- [x] Add `get_micromamba_location()` function (returns location type)
- [x] Add `error_micromamba_not_found()` function with helpful error messages
- [x] Update `pyve --config` to show micromamba status

### Notes
**Goal:** Detect and resolve micromamba binary location.

**Implementation Summary:**
- Created `lib/micromamba.sh` with five core functions:
  - `get_micromamba_path()` - Returns path to micromamba binary (detection order: project → user → system)
  - `check_micromamba_available()` - Returns 0 if available, 1 if not
  - `get_micromamba_version()` - Extracts version from `micromamba --version`
  - `get_micromamba_location()` - Returns "project", "user", "system", or "not_found"
  - `error_micromamba_not_found()` - Displays helpful error with installation instructions
- Updated `pyve.sh`:
  - Version bumped from 0.7.1 to 0.7.2
  - Sourced `lib/micromamba.sh`
  - Enhanced `show_config()` to display micromamba status with location and version

**Detection Order:**
1. `.pyve/bin/micromamba` (project sandbox) - highest priority
2. `~/.pyve/bin/micromamba` (user sandbox)
3. `which micromamba` (system PATH) - lowest priority

**Testing Results:**
- ✓ `pyve --version` shows 0.7.2
- ✓ `pyve --config` displays micromamba status
- ✓ Detects micromamba in project sandbox (.pyve/bin/micromamba)
- ✓ Detects micromamba in user sandbox (~/.pyve/bin/micromamba)
- ✓ Project sandbox takes priority over user sandbox
- ✓ Version extraction works correctly (tested with v1.5.3 and v1.4.0)
- ✓ Shows "not found" when micromamba is not available
- ✓ Location type reported correctly (project, user, system, not_found)

**Error Handling:**
- `error_micromamba_not_found()` provides clear installation instructions:
  - Package manager installation (brew on macOS, apt on Linux)
  - Bootstrap installation (future feature in v0.7.3)
  - Lists all detection locations for troubleshooting

**Note:** `pyve doctor` command will be implemented in v0.7.11 to provide comprehensive health checks including micromamba status.

---

## v0.7.1 Configuration File Support [Implemented]
- [x] Create YAML parser (portable bash/awk approach)
- [x] Implement `.pyve/config` file reading
- [x] Support configuration schema (backend, micromamba, python, venv, prompt sections)
- [x] Add config validation function
- [x] Update backend priority: CLI flag → config → files → default
- [x] Add `pyve --config` output for config file location

### Notes
**Goal:** Add `.pyve/config` YAML configuration file support.

**Implementation Summary:**
- Added YAML parser functions to `lib/utils.sh`:
  - `read_config_value()` - Reads simple YAML values (supports nested keys like "micromamba.env_name")
  - `config_file_exists()` - Checks if .pyve/config exists
- Updated `lib/backend_detect.sh`:
  - Modified `get_backend_priority()` to check config file (Priority 2)
  - Added `validate_config_file()` - Validates backend, venv.directory, and python.version values
- Updated `pyve.sh`:
  - Version bumped from 0.7.0 to 0.7.1
  - Enhanced `show_config()` to display config file status and backend value
- Uses portable bash/awk approach (no external YAML libraries needed)

**Configuration Schema:**
```yaml
backend: micromamba
micromamba:
  env_name: myproject
  env_file: environment.yml
python:
  version: "3.11"
venv:
  directory: .venv
prompt:
  show: true
  format: "({backend}:{env_name})"
```

**Backend Priority Resolution (Updated):**
1. CLI flag: `--backend` (highest priority)
2. `.pyve/config` → `backend:` field
3. File-based detection (environment.yml → micromamba, pyproject.toml → venv)
4. Default to venv (lowest priority)

**Testing Results:**
- ✓ `pyve --version` shows 0.7.1
- ✓ `pyve --config` displays config file status
- ✓ Config file with `backend: micromamba` is read correctly
- ✓ Config file with `backend: venv` is read correctly
- ✓ Config backend overrides file-based detection
- ✓ CLI flag would override config (tested in v0.7.0)
- ✓ Missing config file doesn't break anything
- ✓ Invalid backend values are displayed (validation will be enforced in init command)

**YAML Parser Implementation:**
- Uses awk for parsing (portable, no dependencies)
- Handles top-level keys: `backend: value`
- Handles nested keys: `micromamba:\n  env_name: value`
- Strips quotes and whitespace
- Returns empty string if key not found or file doesn't exist

---

## v0.7.0 Backend Detection Foundation [Implemented]
- [x] Create `lib/backend_detect.sh` library
- [x] Implement file-based backend detection logic (environment.yml, conda-lock.yml, pyproject.toml, requirements.txt)
- [x] Add backend detection functions: `detect_backend_from_files()`, `get_backend_priority()`
- [x] Add `--backend` CLI flag (venv, micromamba, auto)
- [x] Default to venv backend (maintain backward compatibility)
- [x] Update `--config` to show detected backend
- [x] Add unit tests for backend detection logic

### Notes
**Goal:** Establish backend detection infrastructure without breaking existing venv functionality.

**Implementation Summary:**
- Created `lib/backend_detect.sh` with three core functions:
  - `detect_backend_from_files()` - Detects backend from project files
  - `get_backend_priority()` - Resolves backend based on priority rules
  - `validate_backend()` - Validates backend values
- Updated `pyve.sh` to source backend_detect.sh library
- Added `--backend` flag to `pyve --init` command
- Updated help text and configuration output
- Version bumped from 0.6.6 to 0.7.0

**Backend Priority Resolution:**
1. CLI flag: `--backend` (highest priority)
2. `.pyve/config` file (future - v0.7.1)
3. File-based detection (environment.yml → micromamba, pyproject.toml → venv)
4. Default to venv (lowest priority)

**File Detection Rules:**
- `environment.yml` or `conda-lock.yml` present → micromamba backend
- `pyproject.toml` or `requirements.txt` present → venv backend
- Both present → "ambiguous", warns user, defaults to venv
- None present → "none", defaults to venv

**Backward Compatibility:**
- Existing venv workflows continue to work unchanged (tested)
- Default behavior remains venv backend
- No breaking changes to existing commands
- Micromamba backend detection works but full implementation deferred to v0.7.1-v0.7.12

**Testing Results:**
- ✓ `pyve --version` shows 0.7.0
- ✓ `pyve --config` displays detected backend
- ✓ Backend detection works correctly:
  - `requirements.txt` only → detects "venv"
  - `environment.yml` only → detects "micromamba"
  - Both files → detects "ambiguous"
  - No files → detects "none"
- ✓ `--backend` flag validates input (venv, micromamba, auto)
- ✓ Attempting to use micromamba backend shows clear error message about future implementation

**Implementation Reference:**
- See `docs/specs/implementation_plan.md` for complete v0.7.x roadmap
- See `docs/specs/design_decisions.md` for architectural decisions
- See `docs/specs/micromamba.md` for requirements

---
