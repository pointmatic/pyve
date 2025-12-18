# Features

This document catalogs all features in Pyve v0.5.10 and identifies which will be retained for v0.7.0.

## Core Features (Retained for v0.7.0)

### Python Virtual Environment Management

#### 1. Environment Initialization (`--init`)
- **Description**: Initialize a Python virtual environment in the current directory
- **Capabilities**:
  - Auto-configure Python version using asdf or pyenv
  - Create virtual environment using Python venv
  - Auto-activate/deactivate via direnv when changing directories
  - Configure `.env` file for environment variables (dotenv-ready)
  - Auto-configure `.gitignore` to exclude virtual environment artifacts
  - Optional custom venv directory name (default: `.venv`)
  - Optional Python version selection via `--python-version <ver>`
  - Optional local env template copy via `--local-env` flag
  - Smart conflict detection for existing files
- **Files Created/Modified**:
  - `.venv/` (or custom directory)
  - `.tool-versions` (asdf) or `.python-version` (pyenv)
  - `.envrc` (direnv configuration)
  - `.env` (environment variables, chmod 600)
  - `.gitignore` (patterns added)
  - `.DS_Store` pattern (macOS only)

#### 2. Python Version Management (`--python-version`)
- **Description**: Set local Python version without creating virtual environment
- **Capabilities**:
  - Set Python version via asdf or pyenv
  - Auto-install Python version if not present
  - Refresh shims after version change
  - No venv/direnv changes (version-only operation)
- **Version Format**: `#.#.#` (e.g., `3.13.7`)
- **Default Version**: `3.13.7`

#### 3. Environment Purge (`--purge`)
- **Description**: Delete all Python virtual environment artifacts
- **Capabilities**:
  - Remove venv directory (`.venv` or custom)
  - Remove version manager files (`.tool-versions` or `.python-version`)
  - Remove direnv configuration (`.envrc`)
  - Remove environment file (`.env`) - **only if empty** (v0.7.0 change)
  - Clean up `.gitignore` patterns
  - Optional custom venv directory name parameter
  - Message displayed when any purge action is skipped
- **Safety**: Preserves user code, Git repository, and non-empty `.env` files
- **v0.7.0 Change**: `.env` file now preserved if non-empty (matches `~/.local/.env` behavior during `--uninstall`)

#### 4. Script Installation (`--install`)
- **Description**: Install/update pyve script to `~/.local/bin`
- **Capabilities**:
  - Copy script to `~/.local/bin/pyve.sh`
  - Create `pyve` symlink for convenience
  - Add `~/.local/bin` to PATH via `~/.zprofile` if needed
  - Record source repository path
  - Create `~/.local/.env` template file (chmod 600)
  - Idempotent (safe to run multiple times)
  - Smart handoff to source repo script if available

#### 5. Script Uninstallation (`--uninstall`)
- **Description**: Remove installed pyve script and artifacts
- **Capabilities**:
  - Remove `~/.local/bin/pyve.sh`
  - Remove `~/.local/bin/pyve` symlink
  - Remove `~/.local/.env` if empty
  - Preserve non-empty env template with warning
  - Remove PATH modification from `~/.zprofile` (v0.7.0 change)
- **v0.7.0 Change**: Now cleans up the PATH export line added during `--install` (only removes pyve-added line, preserves other PATH modifications)

#### 6. Help (`--help`, `-h`)
- **Description**: Display comprehensive help message
- **Content**: Usage, parameters, descriptions, examples

#### 7. Version (`--version`, `-v`)
- **Description**: Display current script version
- **Current Version**: `0.5.10`

#### 8. Configuration (`--config`, `-c`)
- **Description**: Display current configuration settings
- **Shows**:
  - Environment vars filename (`.env`)
  - Default Python version (`3.13.7`)
  - Default venv directory (`.venv`)

### Version Manager Support

#### 9. asdf Integration
- **Description**: Primary Python version manager support
- **Capabilities**:
  - Auto-detect asdf installation
  - Verify asdf shims in PATH
  - Check for Python plugin
  - Auto-install Python versions
  - Create/manage `.tool-versions` file
  - Refresh shims after version changes

#### 10. pyenv Integration
- **Description**: Fallback Python version manager support
- **Capabilities**:
  - Auto-detect pyenv installation
  - Auto-install Python versions
  - Create/manage `.python-version` file
  - Refresh shims after version changes

### Environment Management

#### 11. direnv Integration
- **Description**: Automatic virtual environment activation
- **Capabilities**:
  - Create `.envrc` configuration
  - Dynamic path evaluation (supports custom venv dirs)
  - Auto-activation on directory entry
  - Auto-deactivation on directory exit
  - Requires user approval (`direnv allow`)

#### 12. Dotenv Support
- **Description**: Environment variable file management
- **Capabilities**:
  - Create `.env` file with secure permissions (chmod 600)
  - Copy from `~/.local/.env` template via `--local-env` flag
  - Ready for Python dotenv package
  - Auto-add to `.gitignore`

#### 13. Local Environment Template
- **Description**: Reusable environment variable template
- **Location**: `~/.local/.env`
- **Capabilities**:
  - Created during `--install` (chmod 600)
  - Copied to projects via `--init --local-env`
  - Preserved during `--uninstall` if non-empty

### Platform Support

#### 14. macOS Support
- **Description**: Native macOS compatibility
- **Shell**: zsh (primary)
- **Special Handling**:
  - `.DS_Store` auto-added to `.gitignore`
  - BSD sed compatibility
  - Homebrew detection (warning if missing)

#### 15. Shell Profile Management
- **Description**: Auto-configure shell environment
- **Files Modified**:
  - `~/.zshrc` (sourced for version managers)
  - `~/.zprofile` (PATH modifications)
- **Capabilities**:
  - Add `~/.local/bin` to PATH
  - Source profiles to refresh environment

### Validation & Safety

#### 16. Input Validation
- **Venv Directory Names**:
  - Alphanumeric, dots, underscores, hyphens only
  - No conflicts with reserved names (`.env`, `.git`, `.gitignore`, `.tool-versions`, `.python-version`, `.envrc`)
- **Python Versions**:
  - Semver format validation (`#.#.#`)
  - Availability check before installation

#### 17. Conflict Detection
- **Description**: Prevent overwriting existing configurations
- **Checks**:
  - Existing venv directory
  - Existing version manager files
  - Existing direnv configuration
  - Existing `.env` file
- **Behavior**: Skip with informational message (no error)

#### 18. Error Handling
- **Missing Dependencies**:
  - asdf/pyenv required (one must be present)
  - direnv required for `--init`
  - Python plugin required (asdf)
- **Installation Failures**:
  - Python version installation errors
  - Path configuration errors
  - File permission errors
- **Clear Error Messages**: Actionable instructions for resolution

## Deprecated Features (Removed in v0.7.0)

These features relate to LLM collaboration, markdown document management, and LLM Q&A functionality. They will be removed to simplify Pyve's focus on Python virtual environment management.

### Documentation Template Management

#### D1. Template Installation (`--install` template component)
- **Description**: Copy documentation templates from repo to `~/.pyve/templates/{version}`
- **Capabilities**:
  - Record source repository path to `~/.pyve/source_path`
  - Copy versioned templates to `~/.pyve/templates/v{version}`
  - Support rsync or cp fallback
  - Cleanup old template versions (keep latest 2)
- **Deprecated**: Template system no longer needed

#### D2. Template Updates (`--update`)
- **Description**: Update templates from source repo to `~/.pyve/templates/`
- **Status**: Already deprecated in v0.5.2 (warning shown)
- **Capabilities**:
  - Read source path from `~/.pyve/source_path`
  - Semver comparison for version detection
  - Copy newer template versions
  - Immutable templates (no overwrite)
- **Replacement**: `--install` (which is also being deprecated)

#### D3. Template Upgrades (`--upgrade`)
- **Description**: Upgrade local repository documentation templates
- **Capabilities**:
  - Read current version from `.pyve/version`
  - Compare with available templates in `~/.pyve/templates/`
  - Smart merge (preserve modified files)
  - Create suffixed copies for conflicts (`__t__v{version}.md`)
  - Honor package configuration
  - Status tracking and blocking
- **Deprecated**: Documentation management out of scope

#### D4. Template Initialization (`init_copy_templates`)
- **Description**: Copy foundation documentation during `--init`
- **Capabilities**:
  - Copy foundation docs only (not packages)
  - Conflict detection for existing docs
  - Smart copy with suffixed versions
  - Pyve-owned directory overwriting
  - Status file creation
- **Deprecated**: No documentation templates in v0.7.0

#### D5. Template Purge (`purge_templates`)
- **Description**: Smart documentation cleanup during `--purge`
- **Capabilities**:
  - Compare files against templates
  - Delete matching template files
  - Preserve modified/custom files to `docs-old-pyve/`
  - Preserve root files (README.md, CONTRIBUTING.md) if modified
  - Delete empty directories
- **Deprecated**: No templates to purge

### Documentation Package Management

#### D6. Package Listing (`--list`)
- **Description**: List available and installed documentation packages
- **Capabilities**:
  - Scan `~/.pyve/templates/{version}/docs/guides/` for packages
  - Read package metadata from `.packages.json`
  - Show descriptions for each package
  - Mark installed packages with checkmark
  - Display usage instructions
- **Packages**: web, persistence, infrastructure, analytics, mobile, llm_qa
- **Deprecated**: Package system removed

#### D7. Package Addition (`--add`)
- **Description**: Add documentation packages to project
- **Capabilities**:
  - Support multiple packages in one command
  - Validate package availability
  - Skip already-installed packages
  - Copy package files from templates
  - Update `.pyve/packages.conf`
  - Smart file copying (skip identical)
- **Deprecated**: No package system in v0.7.0

#### D8. Package Removal (`--remove`)
- **Description**: Remove documentation packages from project
- **Capabilities**:
  - Support multiple packages in one command
  - Validate package is installed
  - Remove matching template files
  - Preserve modified files
  - Update `.pyve/packages.conf`
- **Deprecated**: No package system in v0.7.0

#### D9. Package Configuration (`packages.conf`)
- **Description**: Track installed documentation packages
- **Location**: `.pyve/packages.conf`
- **Format**: One package name per line
- **Used By**: `--upgrade`, `--add`, `--remove`, `--list`
- **Deprecated**: No packages to track

#### D10. Package Metadata (`.packages.json`)
- **Description**: Package descriptions and metadata
- **Location**: `{templates}/docs/.packages.json`
- **Format**: JSON with package descriptions
- **Used By**: `--list` command
- **Deprecated**: No metadata needed

### Template File Management

#### D11. Template File Listing (`list_template_files`)
- **Description**: Find template files by mode (all/foundation/package)
- **Scopes**:
  - Root docs
  - Foundation guides (top-level)
  - Context docs
  - LLM Q&A docs
  - Specs (general and language-specific)
  - Package-specific docs
- **Deprecated**: No template files to list

#### D12. Template Suffix Stripping (`strip_template_suffix`)
- **Description**: Remove `__t__*` suffix from filenames
- **Pattern**: `filename__t__[version].md` → `filename.md`
- **Used By**: Template copying and target path resolution
- **Deprecated**: No template files to process

#### D13. Target Path Resolution (`target_path_for_source`)
- **Description**: Calculate destination path for template file
- **Capabilities**:
  - Strip template directory prefix
  - Remove `__t__` suffix from filename
  - Preserve directory structure
- **Deprecated**: No template paths to resolve

### Version & Status Management

#### D14. Semver Comparison (`compare_semver`)
- **Description**: Compare semantic version strings
- **Format**: `major.minor.patch`
- **Returns**: 0 (equal), 1 (v1 > v2), 2 (v1 < v2)
- **Used By**: Template version detection and upgrades
- **Deprecated**: Only needed for template versioning

#### D15. Latest Version Detection (`find_latest_template_version`)
- **Description**: Find newest template version in directory
- **Capabilities**:
  - Scan for `v*` directories
  - Validate semver format
  - Compare using semver logic
- **Used By**: All template operations
- **Deprecated**: No template versions to detect

#### D16. Template Directory Migration (`migrate_template_directories`)
- **Description**: Migrate old minor-version dirs to patch-level
- **Example**: `v0.4/` → `v0.4.21/`
- **Purpose**: Support semver transition
- **Deprecated**: No template directories to migrate

#### D17. Template Cleanup (`cleanup_old_templates`)
- **Description**: Remove old template versions (keep latest 2)
- **Location**: `~/.pyve/templates/`
- **Triggered By**: `--install`
- **Deprecated**: No templates to clean up

#### D18. Project Version Tracking (`.pyve/version`)
- **Description**: Record Pyve version used for project templates
- **Format**: `Version: #.#.#`
- **Used By**: `--upgrade` to detect version changes
- **Deprecated**: No templates to version

#### D19. Major.Minor Parsing (`read_project_major_minor`)
- **Description**: Extract major.minor from `.pyve/version`
- **Used By**: Template purge and package removal
- **Deprecated**: No version tracking needed

### Status & Conflict Management

#### D20. Status File Management
- **Description**: Track operation status in `.pyve/status/`
- **Files**:
  - `.pyve/status/init` - Initialization timestamp
  - `.pyve/status/upgrade` - Upgrade timestamp
  - `.pyve/status/purge` - Purge timestamp
  - `.pyve/status/init_copy.log` - Init copy log
- **Deprecated**: No template operations to track

#### D21. Action Needed Tracking (`.pyve/action_needed`)
- **Description**: Block operations until manual merge complete
- **Created When**: Suffixed template files created
- **Contains**: List of files requiring merge, instructions
- **Cleared By**: `--clear-status` command
- **Deprecated**: No template merges to track

#### D22. Status Clearing (`--clear-status`)
- **Description**: Clear status after manual merge completion
- **Operations**: `init` | `upgrade`
- **Capabilities**:
  - Remove status file
  - Remove action_needed file
  - Update version file (upgrade only)
  - Warn about remaining suffixed files
- **Deprecated**: No status to clear

#### D23. Status Validation Functions
- **Functions**:
  - `fail_if_status_present()` - Block if action_needed exists
  - `upgrade_status_fail_if_any_present()` - Upgrade-specific check
  - `purge_status_fail_if_any_present()` - Purge-specific check
- **Purpose**: Prevent operations during incomplete merges
- **Deprecated**: No merge conflicts to manage

### Pyve-Owned Directories

#### D24. Pyve-Owned Directory Management
- **Description**: Directories that Pyve owns and overwrites
- **Directories**:
  - `docs/guides/` - Auto-added to `.gitignore`
  - `docs/runbooks/` - Auto-added to `.gitignore`
- **Behavior**: Always overwrite without conflict detection
- **Function**: `is_pyve_owned()`
- **Deprecated**: No owned directories in v0.7.0

### LLM & Documentation Features

#### D25. LLM Q&A Documentation
- **Description**: Documentation for LLM question-answering
- **Location**: `docs/guides/llm_qa/`
- **Included In**: Foundation templates
- **Deprecated**: LLM collaboration features removed

#### D26. Context Documentation
- **Description**: Project context for LLM collaboration
- **Location**: `docs/context/`
- **Included In**: Foundation templates
- **Deprecated**: LLM collaboration features removed

#### D27. Language-Specific Documentation
- **Description**: Programming language guides and specs
- **Locations**:
  - `docs/guides/lang/`
  - `docs/specs/lang/`
- **Included In**: Foundation templates
- **Deprecated**: Language docs out of scope

#### D28. Specification Templates
- **Description**: Project specification documents
- **Location**: `docs/specs/`
- **Types**: Technical design, codebase, implementation options
- **Included In**: Foundation templates
- **Deprecated**: Spec templates removed

#### D29. Foundation Documentation
- **Description**: Core documentation copied during `--init`
- **Includes**:
  - Root docs (README, CONTRIBUTING)
  - Top-level guides
  - Context docs
  - LLM Q&A docs
  - Specs (general and language)
- **Excludes**: Package-specific docs
- **Deprecated**: No foundation docs in v0.7.0

### Internal Infrastructure

#### D30. Pyve Home Directory (`~/.pyve/`)
- **Description**: User-level Pyve configuration and templates
- **Structure**:
  - `~/.pyve/source_path` - Recorded repo path
  - `~/.pyve/templates/v{version}/` - Template versions
  - `~/.pyve/version` - Installed Pyve version
- **Created By**: `--install`
- **Removed By**: `--uninstall`
- **Deprecated**: Only needed for templates

#### D31. Project Pyve Directory (`.pyve/`)
- **Description**: Project-level Pyve state and status
- **Structure**:
  - `.pyve/version` - Template version used
  - `.pyve/status/` - Operation status files
  - `.pyve/action_needed` - Merge instructions
  - `.pyve/packages.conf` - Installed packages
- **Auto-added to**: `.gitignore`
- **Deprecated**: Minimal state needed in v0.7.0

#### D32. Package File Operations
- **Functions**:
  - `copy_package_files()` - Copy package templates
  - `remove_package_files()` - Remove package files
  - `get_available_packages()` - Scan for packages
  - `get_package_metadata()` - Read package info
  - `read_packages_conf()` - Read installed packages
  - `write_packages_conf()` - Write package list
- **Deprecated**: No packages to manage

#### D33. Init Package Support (`--init --packages`)
- **Description**: Install documentation packages during initialization
- **Flag**: `--packages <pkg1> <pkg2> ...`
- **Behavior**: Install packages after init completes
- **Deprecated**: No packages to install

## Summary

**Core Features (18)**: Python virtual environment management, version managers, direnv integration, installation/uninstallation, help/version/config, platform support, validation, and error handling.

**Deprecated Features (33)**: All documentation template management, package management, LLM collaboration features, markdown document management, and related infrastructure.

**Retention Rate**: 35% of features retained (18/51 total features)

**v0.7.0 Focus**: Pure Python virtual environment setup and management tool with no documentation/LLM features.
