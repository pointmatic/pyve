# Pyve Version History
See `docs/guide_versions_spec.md`

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
