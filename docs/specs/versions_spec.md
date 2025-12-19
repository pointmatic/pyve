# Pyve Version History\
See `docs/guide_versions_spec.md`

## v0.6.6 Fix pipefail issue in version availability check [Implemented]
- [x] Fixed `is_python_version_available` failing due to `set -euo pipefail` causing SIGPIPE errors
- [x] Capture command output to variable before grepping to avoid pipe termination issues

### Notes
The original implementation piped `asdf list all python` directly to `grep -q`, which caused SIGPIPE when grep exited early after finding a match. With `pipefail` enabled, this caused the entire pipeline to fail.

---

## v0.6.5 Python version installation prompt [Implemented]
- [x] Added `prompt_yes_no` utility function in `lib/utils.sh`
- [x] Modified `ensure_python_version_installed` to prompt user before installing unavailable Python versions
- [x] Supports both asdf and pyenv installation flows

### Notes
When a requested Python version is not installed but is available via the version manager, pyve now prompts:
```
INFO: Python 3.14.2 is not installed but is available via asdf.
Install Python 3.14.2 now? [y/n]:
```

---

## v0.6.4 Install fix [Implemented]
- [x] Fixed `--install` bug where running from installed location tried to copy pyve.sh to itself
- [x] Added `~/.local/.pyve_source` to store original source directory for reinstalls
- [x] Updated `uninstall_self()` to clean up source directory file

---

## v0.6.3 Python version bump [Implemented]
- [x] Updated default Python version to 3.14.2 (latest)
- [x] Added note in README.md about future feature ideas

---

## v0.6.2 Cleanup [Implemented]
- [x] Added a `Key Features` section to `README.md`. 
- [x] Deleted all the remaining document generation and explanation files
- [x] Deleted old pyve_deprecated.sh script
- [x] Renamed and updated the guide on how to use this versions_spec.md file
- [x] updated .gitignore to remove deprecated doc update log

### Notes
New Pyve is ready to use with simpler, tighter code and no extra fluff.

--- 

## v0.6.1 Documentation Update [Implemented]
- [x] Update README.md to reflect new focused tool
- [x] Update CONTRIBUTING.md
- [x] Final testing on clean system
- [x] Bump version to 0.6.1 in pyve.sh

### Notes
- **README.md changes:** Simplified to focus on Python environment management only. Removed references to deprecated documentation features, updated requirements (bash instead of zsh), streamlined installation and usage sections.
- **CONTRIBUTING.md changes:** Added Code Style section with bash 3.2 compatibility notes, modular architecture guidance, and logging conventions.
- **Testing:** Verified `--init` and `--purge` work correctly in clean directory.
- **Version bumped:** pyve.sh v0.6.0 → v0.6.1

---

## v0.6.0 Complete Rewrite as Pure Environment Manager [Implemented]
- [x] Rewrite `pyve.sh` from scratch using bash (not zsh) for cross-platform compatibility
- [x] Create modular architecture with `lib/` directory
- [x] Create `lib/utils.sh` with logging, validation, gitignore functions
- [x] Create `lib/env_detect.sh` with version manager detection functions
- [x] Implement smart `.env` purge (only delete if empty)
- [x] Implement PATH cleanup on `--uninstall`
- [x] Support asdf 0.18+ (`asdf set` command instead of deprecated `asdf local`)
- [x] Remove all documentation/template features
- [x] Test all commands: `--init`, `--purge`, `--python-version`, `--install`, `--uninstall`

**Notes:**
- **Major rewrite:** Started fresh rather than incremental refactoring. Combined v0.6.0-v0.6.12 planned microversions into single implementation.
- **Shell change:** Switched from zsh to bash for macOS + Linux compatibility without extra dependencies.
- **Architecture:**
  - `pyve.sh` (~480 lines) - Main script
  - `lib/utils.sh` (~150 lines) - Logging, validation, gitignore
  - `lib/env_detect.sh` (~235 lines) - Version manager, direnv detection
  - Total: ~865 lines (62% reduction from ~2,277 lines in legacy)
- **Smart `.env` purge:** `purge_dotenv()` uses `is_file_empty()` to preserve non-empty files with warning message.
- **PATH cleanup:** `uninstall_clean_path()` removes lines containing `# Added by pyve installer` from shell profiles.
- **asdf 0.18+ fix:** `set_local_python_version()` tries `asdf set` first, falls back to `asdf local` for older versions.
- **Legacy script:** Preserved as `pyve_deprecated.sh` for reference.
- **Version:** v0.5.10 → v0.6.0

---

## v0.6.x Architecture Overview

### Shell Compatibility

**Target Shell:** Bash 3.2+ (POSIX-compatible where possible)

**Rationale:**
- Bash is pre-installed on macOS (3.2) and all Linux distros
- No extra dependencies for Linux users (unlike zsh)
- User's login shell doesn't matter - shebang determines interpreter
- Bash 3.2 has sufficient features (arrays, functions, string manipulation)

**Constraints (bash 3.2 compatibility):**
- No associative arrays (`declare -A`)
- No `${var,,}` lowercase syntax
- No `|&` pipe syntax
- No `&>` redirection (use `>file 2>&1`)
- Use `printf` instead of `echo -e` for portability

### File Structure
```
pyve/
├── pyve.sh              # Main script (~400-500 lines)
├── lib/
│   ├── utils.sh         # Logging, validation, gitignore (~150 lines)
│   └── env_detect.sh    # Version manager, direnv detection (~150 lines)
├── pyve_deprecated.sh   # Legacy script (archived)
├── README.md
├── LICENSE
└── CONTRIBUTING.md
```

### Main Script Structure (`pyve.sh`)
```bash
#!/usr/bin/env bash

# Configuration
VERSION="0.7.0"
DEFAULT_PYTHON_VERSION="3.13.7"
DEFAULT_VENV_DIR=".venv"
ENV_FILE_NAME=".env"

# Resolve script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/env_detect.sh"

# Command Functions
show_help() { ... }
show_version() { ... }
show_config() { ... }
init() { ... }
purge() { ... }
set_python_version_only() { ... }
install_self() { ... }
uninstall_self() { ... }

# Main Entry Point
main() {
    case "$1" in
        --help|-h) show_help ;;
        --version|-v) show_version ;;
        --config|-c) show_config ;;
        --init|-i) shift; init "$@" ;;
        --purge|-p) shift; purge "$@" ;;
        --python-version) shift; set_python_version_only "$@" ;;
        --install) install_self ;;
        --uninstall) uninstall_self ;;
        *) log_error "Unknown command: $1"; show_help; exit 1 ;;
    esac
}

main "$@"
```

### Library: `lib/utils.sh`
```bash
#!/usr/bin/env bash
# Utility functions for pyve

# Logging
log_info() { printf "INFO: %s\n" "$1" }
log_warning() { printf "WARNING: %s\n" "$1" >&2 }
log_error() { printf "ERROR: %s\n" "$1" >&2 }

# Gitignore management
append_pattern_to_gitignore() { ... }
remove_pattern_from_gitignore() { ... }

# Validation
validate_venv_dir_name() { ... }
validate_python_version() { ... }
```

### Library: `lib/env_detect.sh`
```bash
#!/usr/bin/env bash
# Environment detection functions for pyve

source_shell_profiles() { ... }
detect_version_manager() { ... }
ensure_python_version_installed() { ... }
check_direnv_installed() { ... }
```

---

## Archived: Original v0.6.0 Rewrite Plan

The following was the original monolithic rewrite plan, now superseded by the microversion approach above.

### v0.6.0 Rewrite as Pure Environment Manager [Superseded]
- [ ] Create `pyve_new.sh` from scratch (~600-700 lines)
- [ ] Implement only environment management features
- [ ] Fix xtrace issues with proper output handling
- [ ] Consistent, professional messaging throughout
- [ ] Simplified error handling
- [ ] Remove all documentation/template functionality
- [ ] Keep only: `--init`, `--purge`, `--python-version`, `--install`, `--uninstall`, `--help`, `--version`, `--config`
- [ ] Test thoroughly before replacing `pyve.sh`

### Notes
- **Problem:** Current `pyve.sh` has accumulated technical debt:
  - Mixed concerns (environment + documentation)
  - Xtrace workarounds that don't fully work
  - Inconsistent messaging and error handling
  - 2,266 lines of complexity
- **Solution:** Complete rewrite focused solely on Python environment management
- **Scope:** ONLY environment management, NO documentation features
- **Target:** ~600-700 lines of clean, maintainable code
- **Module breakdown:**

#### **Core Features (Environment Management Only)**

**Commands:**
- `--init [<dir>] [--python-version <ver>] [--local-env]` - Initialize Python environment
- `--purge [<dir>]` - Remove all Python environment artifacts
- `--python-version <ver>` - Set Python version without full init
- `--install` - Install pyve to ~/.local/bin
- `--uninstall` - Remove pyve from ~/.local/bin
- `--help` / `-h` - Show help
- `--version` / `-v` - Show version
- `--config` / `-c` - Show configuration

**What Gets Managed:**
- Python version (asdf or pyenv)
- Virtual environment (.venv or custom directory)
- Environment activation (direnv with .envrc)
- Environment variables (.env file)
- `.gitignore` patterns

**What Gets Removed:**
- All template/documentation functionality
- Package management (--list, --add, --remove)
- Template upgrades (--upgrade, --update)
- Status management (--clear-status)
- ~/.pyve/templates/ directory
- .pyve/ project directory

#### **Implementation Approach**

**1. Start Fresh:**
- Create `pyve_new.sh` from scratch
- Don't port old code, rewrite with lessons learned
- Single file, ~600-700 lines total
- Clean, modern shell scripting practices

**2. Fix Xtrace Issues:**
- No command substitution in output paths
- Use explicit `printf` and `echo` for all user-facing output
- Redirect stderr properly in all functions
- Test with `set -x` enabled to verify clean output

**3. Consistent Messaging:**
- Standardized prefixes: `INFO:`, `WARNING:`, `ERROR:`
- Clear, actionable error messages
- Consistent formatting throughout
- Professional tone

**4. Simplified Architecture:**
```bash
# Configuration (lines 1-50)
VERSION="0.6.0"
DEFAULT_PYTHON_VERSION="3.13.7"
# ... other constants

# Utility Functions (lines 51-200)
show_help()
show_version()
show_config()
log_info()
log_warning()
log_error()
append_to_gitignore()
remove_from_gitignore()

# Environment Detection (lines 201-350)
source_shell_profiles()
detect_version_manager()
ensure_python_version_installed()
check_direnv_installed()

# Init Functions (lines 351-500)
init()
init_parse_args()
init_python_versioning()
init_venv()
init_direnv()
init_dotenv()
init_gitignore()
validate_venv_dir_name()
validate_python_version()

# Purge Functions (lines 501-600)
purge()
purge_parse_args()
purge_python_versioning()
purge_venv()
purge_direnv()
purge_dotenv()
purge_gitignore()

# Install/Uninstall (lines 601-700)
install_self()
uninstall_self()

# Main Entry Point (lines 701-750)
# Argument parsing and dispatch
```

**5. Testing Strategy:**
- Test with `set -x` enabled (verify no xtrace pollution)
- Test all flags and combinations
- Test error conditions
- Test on fresh system (no existing .venv, etc.)
- Test upgrade path from v0.5.9

### Original Implementation Plan (Superseded)

**Phase 1: Core Structure (Week 1)**
- Create `pyve_new.sh` skeleton
- Implement configuration and constants
- Implement utility functions (logging, gitignore)
- Implement help/version/config

**Phase 2: Environment Detection (Week 1)**
- Implement shell profile sourcing
- Implement version manager detection (asdf/pyenv)
- Implement Python version installation
- Implement direnv detection

**Phase 3: Init Functionality (Week 2)**
- Implement argument parsing
- Implement Python versioning setup
- Implement venv creation
- Implement direnv configuration
- Implement dotenv setup
- Implement gitignore management

**Phase 4: Purge Functionality (Week 2)**
- Implement argument parsing
- Implement removal of all artifacts
- Implement gitignore cleanup

**Phase 5: Install/Uninstall (Week 3)**
- Implement self-installation
- Implement symlink creation
- Implement PATH management
- Implement uninstallation

**Phase 6: Testing & Polish (Week 3)**
- Test all commands with xtrace enabled
- Test error conditions
- Test on clean system
- Polish messaging
- Update documentation

**Phase 7: Migration (Week 4)**
- Backup current pyve.sh → pyve_legacy.sh
- Rename pyve_new.sh → pyve.sh
- Test upgrade path

### Original Rationale
- **Clean slate:** Rewriting allows us to apply lessons learned without technical debt
- **Focus:** Pure environment management, no feature creep
- **Quality:** Fix xtrace issues properly from the start
- **Maintainability:** 600-700 lines is manageable, well-documented
- **Professional:** Consistent messaging and error handling throughout

### Breaking Changes (v0.7.0)
- Removes all documentation features (--upgrade, --update, --list, --add, --remove, --clear-status)
- Users must migrate to devdoctalk for documentation management
- `~/.pyve/` directory no longer created or used
- `.pyve/` project directory no longer created or used

### Migration Path
- v0.5.10 → v0.6.0: Smart `.env` purge
- v0.6.0 → v0.6.1: PATH cleanup on uninstall
- v0.6.1 → v0.6.2: Deprecation warnings
- v0.6.2 → v0.6.3: Create lib/ structure
- v0.6.3 → v0.6.4: Extract env detection
- v0.6.4 → v0.6.5: Rewrite init
- v0.6.5 → v0.6.6: Rewrite purge
- v0.6.6 → v0.6.7: Rewrite install/uninstall
- v0.6.7 → v0.6.8: Standardize messaging
- v0.6.8 → v0.6.9: Fix xtrace issues
- v0.6.9 → v0.6.10: Remove deprecated code
- v0.6.10 → v0.6.11: Update documentation
- v0.6.11 → v0.6.12: Final testing
- v0.6.12 → v0.7.0: Release pure environment manager

### Version Bump
- pyve.sh v0.6.12 → v0.7.0 (clean release after incremental rewrite)

---

## v0.5.10 Fix .envrc static init [Implemented]
- [x] Fix .envrc static init so the path direnv loads is dynamic (current)

---

## v0.5.9 Suppress Xtrace Debug Output in Package Commands [Implemented]
- [x] Add xtrace disable/restore logic to `list_packages()` function
- [x] Add xtrace disable/restore logic to `add_package()` function
- [x] Add xtrace disable/restore logic to `remove_package()` function
- [x] Add xtrace disable/restore logic to `copy_package_files()` function
- [x] Filter `DESC=` output from `get_package_metadata()` calls
- [x] Wrap `DEST_REL` assignments to suppress xtrace output

### Notes
- **Problem:** When shell tracing (`set -x` or `setopt xtrace`) is enabled in the user's environment, `pyve --list` and `pyve --add` commands produce messy console output with debug lines like:
  ```
  DESC='Cloud platforms and deployment - AWS, GCP, Kubernetes, Fly.io, Docker, CI/CD'
  DEST_REL=docs/guides/llm_qa/README.md
  ```
- **Root cause:** Zsh's xtrace feature prints variable assignments during command substitution. When `DESC=$(get_package_metadata ...)` or `DEST_REL=$(target_path_for_source ...)` execute with xtrace enabled, the assignments are traced and printed to the console.
- **Solution:** Add xtrace detection and suppression to user-facing functions:
  1. Detect if xtrace is enabled using `[[ -o xtrace ]] || [[ "$-" == *x* ]]`
  2. Temporarily disable xtrace using `exec 3>&2 2>/dev/null; set +x; unsetopt xtrace; exec 2>&3 3>&-`
  3. Execute function body with xtrace disabled
  4. Restore xtrace at function exit if it was previously enabled
  5. Filter `DESC=` lines from `get_package_metadata` output: `DESC=$(get_package_metadata ... 2>&1 | grep -v "^DESC=")`
  6. Wrap `DEST_REL` assignments in command groups with stderr redirected
- **Functions modified:**
  - `list_packages()` - Clean output for `pyve --list`
  - `add_package()` - Suppress debug output during package installation
  - `remove_package()` - Suppress debug output during package removal
  - `copy_package_files()` - Suppress debug output during file copying
- **Result:** `pyve --list` now produces clean output. `pyve --add` still shows some `DEST_REL=` lines due to xtrace propagation through nested function calls, but core functionality works correctly.
- **Recommendation:** Users with persistent xtrace output should run `set +x` and `unsetopt xtrace` before using pyve commands.
- **Version:** pyve.sh v0.5.8 → v0.5.9 (script changes only, no template changes)

