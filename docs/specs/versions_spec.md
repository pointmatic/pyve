# Pyve Version History
See `docs/guide_versions_spec.md`

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
