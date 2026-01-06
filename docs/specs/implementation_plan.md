# Pyve v0.7.x Implementation Plan: Micromamba Support

This document outlines the complete implementation plan for adding micromamba backend support to Pyve, based on decisions in `design_decisions.md` and requirements in `micromamba.md`.

---

## High-Level Feature Checklist

### Phase 1: Core Micromamba Support (v0.7.0 - v0.7.12)

**Backend Infrastructure:**
- [ ] Backend detection and selection logic
- [ ] File-based backend detection (environment.yml, conda-lock.yml, pyproject.toml, requirements.txt)
- [ ] CLI flag: `--backend` (venv, micromamba, auto)
- [ ] `.pyve/config` YAML configuration file support
- [ ] Backend priority resolution (CLI flag → config → files → default)

**Micromamba Integration:**
- [ ] Micromamba binary detection (sandbox → user → PATH)
- [ ] Micromamba bootstrap installation (interactive prompts)
- [ ] Environment creation from environment.yml
- [ ] Environment creation from conda-lock.yml
- [ ] Lock file staleness detection and warnings
- [ ] Channel configuration (respect environment.yml)
- [ ] Environment naming (project-local, respect name field)

**Execution Model:**
- [ ] `pyve run <cmd>` command implementation
- [ ] Backend-aware command execution (venv vs micromamba)
- [ ] Environment resolution for `pyve run`

**Shell Integration:**
- [ ] Updated `.envrc` generation for micromamba backend
- [ ] Shell prompt format: `(backend:env_name)`
- [ ] `--no-direnv` flag for CI/CD

**Validation & Diagnostics:**
- [ ] `pyve doctor` command for environment health checks
- [ ] Backend-specific validation
- [ ] Lock file validation warnings

**Documentation:**
- [ ] Update README.md with backend selection
- [ ] Update CLI help text
- [ ] Add CI/CD examples
- [ ] Update troubleshooting section

---

## Microversion Breakdown

### v0.7.0: Backend Detection Foundation
**Goal:** Establish backend detection infrastructure without breaking existing venv functionality.

- [ ] Create `lib/backend_detect.sh` library
- [ ] Implement file-based backend detection logic
- [ ] Add backend detection functions:
  - `detect_backend_from_files()` - Check for environment.yml, conda-lock.yml, pyproject.toml, requirements.txt
  - `get_backend_priority()` - Return backend based on priority rules
- [ ] Add `--backend` CLI flag (venv, micromamba, auto)
- [ ] Default to venv backend (maintain backward compatibility)
- [ ] Add unit tests for backend detection logic
- [ ] Update `--config` to show detected backend

**Testing:**
- Existing venv workflows continue to work
- `--backend venv` explicitly selects venv
- `--backend auto` detects from files (defaults to venv if none)

---

### v0.7.1: Configuration File Support
**Goal:** Add `.pyve/config` YAML configuration file.

- [ ] Create YAML parser (use portable bash/awk approach)
- [ ] Implement `.pyve/config` file reading
- [ ] Support configuration schema:
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
- [ ] Add config validation
- [ ] Update backend priority: CLI flag → config → files → default
- [ ] Add `pyve --config` output for config file location

**Testing:**
- Config file overrides file-based detection
- CLI flag overrides config file
- Missing config file doesn't break anything

---

### v0.7.2: Micromamba Binary Detection
**Goal:** Detect and resolve micromamba binary location.

- [ ] Create `lib/micromamba.sh` library
- [ ] Implement micromamba detection order:
  1. `.pyve/bin/micromamba` (project sandbox)
  2. `~/.pyve/bin/micromamba` (user sandbox)
  3. `which micromamba` (system PATH)
- [ ] Add `get_micromamba_path()` function
- [ ] Add `check_micromamba_available()` function
- [ ] Add version detection: `micromamba --version`
- [ ] Error if micromamba required but not found
- [ ] Update `pyve doctor` to check micromamba status

**Testing:**
- Detects micromamba in all three locations
- Errors gracefully when not found
- Reports version correctly

---

### v0.7.3: Micromamba Bootstrap (Interactive)
**Goal:** Allow users to install micromamba when missing.

- [ ] Implement interactive bootstrap prompt:
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
- [ ] Implement bootstrap download and installation
- [ ] Add `--auto-bootstrap` flag for non-interactive mode
- [ ] Add `--bootstrap-to` flag (project, user)
- [ ] Download from official micromamba releases
- [ ] Verify download integrity (checksums)
- [ ] Set executable permissions

**Testing:**
- Interactive prompt works correctly
- Download and installation succeed
- Auto-bootstrap works in CI mode

---

### v0.7.4: Environment File Detection
**Goal:** Detect and validate environment.yml and conda-lock.yml files.

- [ ] Implement `detect_environment_file()` function
- [ ] Detection order:
  1. `conda-lock.yml` (highest priority)
  2. `environment.yml` (fallback)
  3. Error if neither exists
- [ ] Add YAML validation for environment.yml
- [ ] Parse environment.yml for:
  - `name:` field (environment name)
  - `channels:` list
  - `dependencies:` list
- [ ] Error message if no environment file found
- [ ] Update `pyve doctor` to show detected files

**Testing:**
- Detects conda-lock.yml preferentially
- Falls back to environment.yml
- Errors when neither exists
- Parses environment.yml correctly

---

### v0.7.5: Lock File Validation
**Goal:** Warn users about stale or missing lock files.

- [ ] Implement lock file staleness detection
- [ ] Compare modification times: `mtime(environment.yml) > mtime(conda-lock.yml)`
- [ ] Add interactive warning for stale lock files:
  ```
  WARNING: Lock file may be stale
    environment.yml:  modified 2026-01-05 10:30:00
    conda-lock.yml:   modified 2025-12-15 14:20:00
  
  Using conda-lock.yml for reproducibility.
  To update lock file:
    conda-lock -f environment.yml -p osx-arm64
  
  Continue anyway? [Y/n]: _
  ```
- [ ] Add info message for missing lock file
- [ ] Only show warnings in interactive mode (not CI)
- [ ] Add `--strict` flag to error on stale/missing lock files
- [ ] Update `pyve doctor` to check lock file status

**Testing:**
- Detects stale lock files correctly
- Prompts only in interactive mode
- Silent in non-interactive/CI mode
- `--strict` flag errors appropriately

---

### v0.7.6: Environment Naming
**Goal:** Implement environment naming resolution.

- [ ] Implement environment name resolution order:
  1. CLI flag: `--env-name`
  2. `.pyve/config` → `micromamba.env_name`
  3. `environment.yml` → `name:` field
  4. Project directory basename (sanitized)
- [ ] Add name sanitization function:
  - Lowercase conversion
  - Replace spaces/special chars with hyphens
  - Validate starts with letter or underscore
  - Max 255 characters
  - Check reserved names (base, root, default)
- [ ] Add `--env-name` CLI flag
- [ ] Store resolved name for later use
- [ ] Update `pyve doctor` to show environment name

**Testing:**
- Name resolution follows priority order
- Sanitization works correctly
- Reserved names are rejected
- CLI flag overrides all other sources

---

### v0.7.7: Micromamba Environment Creation
**Goal:** Create micromamba environments from environment files.

- [ ] Implement `create_micromamba_env()` function
- [ ] Use detected environment file (conda-lock.yml or environment.yml)
- [ ] Create environment at `.pyve/envs/<env_name>`
- [ ] Execute: `micromamba create -p .pyve/envs/<name> -f <file>`
- [ ] Handle creation errors gracefully
- [ ] Verify environment created successfully
- [ ] Update `pyve --init` to support micromamba backend
- [ ] Skip if environment already exists

**Testing:**
- Creates environment from environment.yml
- Creates environment from conda-lock.yml
- Handles errors (missing channels, invalid packages)
- Skips creation if exists

---

### v0.7.8: Shell Prompt Integration
**Goal:** Update shell prompt to show backend and environment name.

- [ ] Update `.envrc` generation for micromamba backend
- [ ] Implement prompt format: `(backend:env_name)`
- [ ] For venv backend:
  ```bash
  export PS1="(venv:${PWD##*/}) $PS1"
  ```
- [ ] For micromamba backend:
  ```bash
  export PS1="(micromamba:$ENV_NAME) $PS1"
  ```
- [ ] Make prompt format configurable via `.pyve/config`
- [ ] Support `prompt.show` and `prompt.format` config options
- [ ] Update existing venv `.envrc` to include backend name

**Testing:**
- Prompt shows correct backend
- Prompt shows correct environment name
- Configuration options work
- Backward compatible with existing venvs

---

### v0.7.9: `pyve run` Command Foundation
**Goal:** Implement basic `pyve run <cmd>` execution.

- [ ] Add `pyve run` command to CLI
- [ ] Detect active backend (venv or micromamba)
- [ ] For venv backend:
  ```bash
  .venv/bin/<cmd>
  ```
- [ ] For micromamba backend:
  ```bash
  micromamba run -p .pyve/envs/<name> <cmd>
  ```
- [ ] Pass through all arguments to command
- [ ] Preserve exit codes
- [ ] Handle command not found errors
- [ ] Update help text

**Testing:**
- `pyve run python -V` works for both backends
- Arguments pass through correctly
- Exit codes preserved
- Errors when environment not initialized

---

### v0.7.10: `--no-direnv` Flag
**Goal:** Add flag to skip direnv configuration for CI/CD.

- [ ] Add `--no-direnv` CLI flag to `pyve --init`
- [ ] Skip `.envrc` creation when flag is set
- [ ] Update help text to document flag
- [ ] Add to CI/CD examples in documentation
- [ ] Ensure `pyve run` still works without direnv

**Testing:**
- `--no-direnv` skips .envrc creation
- Environment still works with `pyve run`
- Useful for CI/CD workflows

---

### v0.7.11: `pyve doctor` Command
**Goal:** Implement environment health check and diagnostics.

- [ ] Add `pyve doctor` command
- [ ] Check and report:
  - Backend type (venv or micromamba)
  - Environment location
  - Python version
  - Environment file (environment.yml, conda-lock.yml)
  - Lock file status (up to date, stale, missing)
  - Micromamba version (if applicable)
  - Package count
- [ ] Add `--verbose` flag for detailed output
- [ ] Add `--backend` flag to check specific backend
- [ ] Color-coded status indicators (✓ ✗ ⚠)
- [ ] Example output:
  ```
  ✓ Backend: micromamba
  ✓ Micromamba: /Users/user/.pyve/bin/micromamba (v1.5.3)
  ✓ Environment: .pyve/envs/myproject
  ✓ Python: 3.11.7
  ✓ Environment file: environment.yml
  ⚠ Lock file: conda-lock.yml (stale)
  ```

**Testing:**
- Reports correct status for venv
- Reports correct status for micromamba
- Detects issues correctly
- Verbose mode shows additional details

---

### v0.7.12: Documentation and Polish
**Goal:** Complete documentation and final polish.

- [ ] Update README.md:
  - Backend selection section
  - Auto-detection priority
  - Micromamba bootstrap instructions
  - `pyve run` examples
  - `pyve doctor` usage
  - CI/CD integration examples
- [ ] Update help text for all commands
- [ ] Add troubleshooting section for micromamba
- [ ] Create `docs/ci-cd-examples.md` with:
  - GitHub Actions workflows
  - GitLab CI examples
  - Caching strategies
- [ ] Update `CONTRIBUTING.md` with:
  - Backend architecture
  - Testing guidelines for both backends
- [ ] Add examples to `pyve-run-examples.md`:
  - Backend-specific examples
  - Error handling examples
- [ ] Final testing:
  - Test all commands with both backends
  - Test on clean system
  - Test upgrade path from v0.6.6
  - Test CI/CD workflows

**Testing:**
- All documentation accurate
- Examples work as documented
- Help text complete and clear
- Upgrade path smooth

---

## Phase 2: Future Enhancements (v0.8.0+)

**Not in v0.7.x scope:**
- Multiple environments per project (`pyve --init --env dev`)
- Environment listing (`pyve envs`)
- Environment switching (`pyve activate <env>`)
- Lock file generation (`pyve lock`)
- Migration between backends (`pyve migrate`)
- Native Windows support (PowerShell)
- GitHub Action (`uses: pointmatic/setup-pyve@v1`)

---

## Testing Strategy

**Per Microversion:**
- Unit tests for new functions
- Integration tests for workflows
- Manual testing on clean system
- Backward compatibility verification

**Final Testing (v0.7.12):**
- Complete workflow tests (venv and micromamba)
- CI/CD workflow tests
- Upgrade testing from v0.6.6
- Cross-platform testing (macOS, Linux, WSL)

---

## Success Criteria

v0.7.x is complete when:
1. Users can initialize micromamba environments with `pyve --init --backend micromamba`
2. Backend auto-detection works from environment files
3. Lock file validation warns about staleness
4. `pyve run` executes commands in both venv and micromamba environments
5. `pyve doctor` provides useful diagnostics
6. CI/CD workflows documented and tested
7. All existing venv functionality continues to work
8. Documentation is complete and accurate
