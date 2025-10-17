# Pyve to DevDocTalk Migration Specification

## Overview

This document outlines the plan to extract documentation features from Pyve and migrate them to a new product called DevDocTalk.

## Products After Split

### **Pyve** (Python Virtual Environment Manager)
- **Purpose:** Simplified Python environment setup and management
- **Scope:** Python version, venv, direnv, dotenv, gitignore
- **Target Size:** ~600-700 lines
- **Repository:** https://github.com/pointmatic/pyve

### **DevDocTalk** (Development Documentation Builder)
- **Purpose:** LLM-optimized documentation framework for software projects
- **Scope:** Template management, Q&A workflow, package system, version upgrades
- **Language:** Python 3.10+ (type-hinted, well-tested)
- **Target Size:** ~1,500-2,000 lines (modular Python package)
- **Repository:** https://github.com/pointmatic/devdoctalk (new)

---

## Migration Timeline

### **Phase 1: Create DevDocTalk Repository (Week 1)**
- [ ] Create new repository at `/Users/pointmatic/Documents/Code/devdoctalk/`
- [ ] Initialize with basic structure
- [ ] Set up modular architecture from the start
- [ ] Create initial README and documentation

### **Phase 2: Translate Shell to Python (Weeks 2-3)**
- [ ] Set up Python package structure with pyproject.toml
- [ ] Translate template management code (shell → Python)
- [ ] Translate package management code (shell → Python)
- [ ] Translate upgrade/update logic (shell → Python)
- [ ] Translate status management (shell → Python)
- [ ] Add type hints and proper error handling
- [ ] Write unit tests for all modules

### **Phase 3: Pyve v0.6.0 Rewrite (Weeks 4-7)**
- [ ] Rewrite pyve_new.sh from scratch
- [ ] Focus on environment management only
- [ ] Fix xtrace issues
- [ ] Implement consistent messaging
- [ ] Test thoroughly

### **Phase 4: Pyve v0.7.0 Deprecation (Week 8)**
- [ ] Add deprecation warnings to old pyve.sh
- [ ] Point users to devdoctalk
- [ ] Update documentation
- [ ] Release v0.7.0

### **Phase 5: DevDocTalk v1.0.0 Release (Week 9)**
- [ ] Finalize devdoctalk features
- [ ] Complete testing
- [ ] Write comprehensive documentation
- [ ] Release v1.0.0

### **Phase 6: Pyve v1.0.0 Release (Week 10)**
- [ ] Replace pyve.sh with pyve_new.sh
- [ ] Remove all documentation features
- [ ] Clean, focused Python environment manager
- [ ] Release v1.0.0

---

## Code Extraction Map (Shell → Python)

### **Shell Functions → Python Modules**

#### **Template Management (Shell → `devdoctalk/templates.py`)**
```python
# Core template operations
def find_latest_template_version(templates_dir: Path) -> Optional[str]: ...
def migrate_template_directories() -> None: ...
def cleanup_old_templates() -> None: ...
def record_source_path(source_path: Path) -> None: ...
def copy_latest_templates_to_home(source_path: Path) -> None: ...

# Template copying and initialization
def init_copy_templates(packages: Optional[list[str]] = None) -> None: ...
def purge_templates() -> None: ...
def list_template_files(src_dir: Path, mode: str = 'foundation') -> list[Path]: ...
def target_path_for_source(src_dir: Path, file_path: Path) -> Path: ...
def is_ddt_owned(file_path: str) -> bool: ...

# Status management
def ensure_project_dirs() -> None: ...
def fail_if_status_present() -> None: ...
def write_init_status(args: list[str]) -> None: ...
def purge_status_fail_if_any_present() -> None: ...
def write_purge_status(args: list[str]) -> None: ...
def read_project_version() -> Optional[str]: ...
```

#### **Package Management (Shell → `devdoctalk/packages.py`)**
```python
# Package operations
def add_packages(packages: list[str]) -> int: ...
def remove_packages(packages: list[str]) -> int: ...
def list_packages() -> int: ...
def copy_package_files(src_dir: Path, package: str) -> int: ...
def remove_package_files(package: str) -> int: ...

# Package metadata
def get_package_metadata(src_dir: Path, package: str, field: str) -> str: ...
def get_available_packages(src_dir: Path) -> list[str]: ...
def read_packages_conf() -> list[str]: ...
def write_packages_conf(packages: list[str]) -> None: ...

# Package metadata structure
@dataclass
class PackageMetadata:
    name: str
    description: str
    category: str
    files: list[Path]
```

#### **Lifecycle Management (Shell → `devdoctalk/lifecycle.py`)**
```python
# Upgrade operations
def upgrade_templates() -> int: ...
def upgrade_status_fail_if_any_present() -> None: ...
def write_upgrade_status(args: list[str]) -> None: ...
def write_action_needed(operation: str, files: list[Path]) -> None: ...
def clear_status(operation: str) -> int: ...

# Install/uninstall
def install_self() -> int: ...
def uninstall_self() -> int: ...
```

#### **Version Comparison (Shell → `devdoctalk/version.py`)**
```python
def compare_semver(v1: str, v2: str) -> Literal[-1, 0, 1]: ...
def parse_version(version_str: str) -> tuple[int, int, int]: ...
def format_version(major: int, minor: int, patch: int) -> str: ...
```

### **Functions Staying in Pyve**

#### **Environment Management (~600-700 lines total)**
```bash
# Configuration
VERSION, DEFAULT_PYTHON_VERSION, etc.

# Utilities
show_help()
show_version()
show_config()
log_info()      # New, standardized logging
log_warning()   # New, standardized logging
log_error()     # New, standardized logging
append_to_gitignore()
remove_from_gitignore()

# Environment detection
source_shell_profiles()
check_homebrew_warning()
detect_version_manager()
ensure_python_version_installed()
check_direnv_installed()

# Init operations
init()
init_parse_args()
init_python_versioning()
init_venv()
init_direnv()
init_dotenv()
init_gitignore()
validate_venv_dir_name()
validate_python_version()

# Purge operations
purge()
purge_parse_args()
purge_python_versioning()
purge_venv()
purge_direnv()
purge_dotenv()
purge_gitignore()

# Python version management
set_python_version_only()

# Install/uninstall (simple version)
install_self()
uninstall_self()
```

---

## DevDocTalk Architecture

### **Repository Structure**
```
devdoctalk/
├── devdoctalk/                # Python package
│   ├── __init__.py           # Package initialization
│   ├── __main__.py           # CLI entry point
│   ├── cli.py                # Argument parsing (~150 lines)
│   ├── config.py             # Configuration & constants (~100 lines)
│   ├── templates.py          # Template operations (~400 lines)
│   ├── packages.py           # Package management (~350 lines)
│   ├── lifecycle.py          # Install/upgrade (~300 lines)
│   ├── utils.py              # Utilities (~200 lines)
│   └── version.py            # Version comparison (~50 lines)
├── tests/
│   ├── __init__.py
│   ├── test_templates.py
│   ├── test_packages.py
│   ├── test_lifecycle.py
│   ├── test_utils.py
│   └── test_version.py
├── templates/
│   └── v1.0.0/                # Fresh start at v1.0.0
│       ├── README__t__.md
│       ├── CONTRIBUTING__t__.md
│       └── docs/
│           ├── context/
│           │   └── project_context__t__.md
│           ├── specs/
│           │   ├── codebase_spec__t__.md
│           │   ├── technical_design_spec__t__.md
│           │   ├── implementation_options_spec__t__.md
│           │   └── decisions_spec__t__.md
│           └── guides/
│               ├── llm_qa/
│               │   ├── README__t__.md
│               │   ├── llm_qa_principles__t__.md
│               │   ├── project_context_questions__t__.md
│               │   └── llm_qa_phase[0-16]_questions__t__.md
│               ├── building_guide__t__.md
│               ├── planning_guide__t__.md
│               ├── testing_guide__t__.md
│               └── dependencies_guide__t__.md
├── docs/                      # DevDocTalk's own documentation
│   ├── specs/
│   │   ├── codebase_spec.md
│   │   ├── versions_spec.md
│   │   └── decisions_spec.md
│   └── guides/
│       ├── building_guide.md
│       ├── integration_guide.md
│       └── language_support.md
├── pyproject.toml            # Modern Python packaging (PEP 621)
├── setup.py                  # Backward compatibility
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

### **Python Package Structure**

**Entry Point (`devdoctalk/__main__.py`):**
```python
#!/usr/bin/env python3
"""DevDocTalk CLI entry point."""
import sys
from devdoctalk.cli import main

if __name__ == '__main__':
    sys.exit(main())
```

**CLI Module (`devdoctalk/cli.py`):**
```python
"""Command-line interface for DevDocTalk."""
import argparse
from pathlib import Path
from typing import Optional

from devdoctalk import commands
from devdoctalk.config import VERSION

def main() -> int:
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='DevDocTalk - LLM-optimized documentation framework'
    )
    parser.add_argument('--version', '-v', action='version', version=f'DevDocTalk {VERSION}')
    
    subparsers = parser.add_subparsers(dest='command', required=True)
    
    # Init command
    init_parser = subparsers.add_parser('init', help='Initialize documentation')
    init_parser.add_argument('--packages', nargs='+', help='Packages to install')
    
    # Upgrade command
    upgrade_parser = subparsers.add_parser('upgrade', help='Upgrade templates')
    
    # List command
    list_parser = subparsers.add_parser('list', help='List available packages')
    
    # Add command
    add_parser = subparsers.add_parser('add', help='Add packages')
    add_parser.add_argument('packages', nargs='+', help='Packages to add')
    
    # Remove command
    remove_parser = subparsers.add_parser('remove', help='Remove packages')
    remove_parser.add_argument('packages', nargs='+', help='Packages to remove')
    
    # Clear-status command
    clear_parser = subparsers.add_parser('clear-status', help='Clear status')
    clear_parser.add_argument('operation', choices=['init', 'upgrade'])
    
    # Install command
    install_parser = subparsers.add_parser('install', help='Install DevDocTalk')
    
    # Uninstall command
    uninstall_parser = subparsers.add_parser('uninstall', help='Uninstall DevDocTalk')
    
    args = parser.parse_args()
    
    # Dispatch to appropriate command
    try:
        if args.command == 'init':
            return commands.init(packages=args.packages)
        elif args.command == 'upgrade':
            return commands.upgrade()
        elif args.command == 'list':
            return commands.list_packages()
        elif args.command == 'add':
            return commands.add_packages(args.packages)
        elif args.command == 'remove':
            return commands.remove_packages(args.packages)
        elif args.command == 'clear-status':
            return commands.clear_status(args.operation)
        elif args.command == 'install':
            return commands.install_self()
        elif args.command == 'uninstall':
            return commands.uninstall_self()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    
    return 0
```

**Configuration (`devdoctalk/config.py`):**
```python
"""Configuration and constants for DevDocTalk."""
from pathlib import Path
from typing import Final

# Version
VERSION: Final[str] = "1.0.0"

# Home directory paths
DDT_HOME: Final[Path] = Path.home() / '.devdoctalk'
DDT_TEMPLATES_DIR: Final[Path] = DDT_HOME / 'templates'
DDT_SOURCE_PATH_FILE: Final[Path] = DDT_HOME / 'source_path'

# Project directory paths
DDT_PROJECT_DIR: Final[Path] = Path('.devdoctalk')
DDT_PACKAGES_CONF: Final[Path] = DDT_PROJECT_DIR / 'packages.conf'
DDT_VERSION_FILE: Final[Path] = DDT_PROJECT_DIR / 'version'
DDT_STATUS_DIR: Final[Path] = DDT_PROJECT_DIR / 'status'
DDT_ACTION_NEEDED_FILE: Final[Path] = DDT_PROJECT_DIR / 'action_needed'

# DevDocTalk-owned directories (always overwrite)
DDT_OWNED_DIRS: Final[tuple[str, ...]] = (
    'docs/guides',
    'docs/runbooks',
)

# Template suffix pattern
TEMPLATE_SUFFIX: Final[str] = '__t__'
```

**Version Comparison (`devdoctalk/version.py`):**
```python
"""Semantic version comparison utilities."""
from typing import Literal

def compare_semver(v1: str, v2: str) -> Literal[-1, 0, 1]:
    """
    Compare two semantic version strings.
    
    Args:
        v1: First version (e.g., "1.2.3")
        v2: Second version (e.g., "1.2.4")
    
    Returns:
        -1 if v1 < v2
         0 if v1 == v2
         1 if v1 > v2
    """
    # Strip 'v' prefix if present
    v1 = v1.lstrip('v')
    v2 = v2.lstrip('v')
    
    # Parse versions
    parts1 = [int(x) for x in v1.split('.')]
    parts2 = [int(x) for x in v2.split('.')]
    
    # Pad to same length
    max_len = max(len(parts1), len(parts2))
    parts1.extend([0] * (max_len - len(parts1)))
    parts2.extend([0] * (max_len - len(parts2)))
    
    # Compare
    if parts1 < parts2:
        return -1
    elif parts1 > parts2:
        return 1
    else:
        return 0
```

**Utilities (`devdoctalk/utils.py`):**
```python
"""Utility functions for DevDocTalk."""
import sys
from pathlib import Path
from typing import Optional

def log_info(message: str) -> None:
    """Print info message to stdout."""
    print(f"INFO: {message}")

def log_warning(message: str) -> None:
    """Print warning message to stderr."""
    print(f"WARNING: {message}", file=sys.stderr)

def log_error(message: str) -> None:
    """Print error message to stderr."""
    print(f"ERROR: {message}", file=sys.stderr)

def ensure_dir(path: Path) -> None:
    """Ensure directory exists, create if needed."""
    path.mkdir(parents=True, exist_ok=True)

def strip_template_suffix(filename: str) -> str:
    """
    Remove __t__* suffix from template filename.
    
    Example:
        'README__t__.md' -> 'README.md'
        'guide__t__v1.0.0.md' -> 'guide.md'
    """
    import re
    return re.sub(r'__t__[^.]*\.', '.', filename)
```

### **Commands**
```bash
# Using Python module directly
python -m devdoctalk init [--packages <pkg1> <pkg2> ...]
python -m devdoctalk upgrade
python -m devdoctalk list
python -m devdoctalk add <package> [pkg2 ...]
python -m devdoctalk remove <package> [pkg2 ...]
python -m devdoctalk clear-status <operation>
python -m devdoctalk install
python -m devdoctalk uninstall
python -m devdoctalk --help
python -m devdoctalk --version

# Or via installed command (after pip install)
devdoctalk init [--packages <pkg1> <pkg2> ...]
devdoctalk upgrade
devdoctalk list
# ... etc
```

### **Installation & Distribution**

**Development Installation:**
```bash
cd devdoctalk
pip install -e .
```

**User Installation:**
```bash
# From PyPI (future)
pip install devdoctalk

# From source
pip install git+https://github.com/pointmatic/devdoctalk.git
```

**Package Configuration (`pyproject.toml`):**
```toml
[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "devdoctalk"
version = "1.0.0"
description = "LLM-optimized documentation framework for software projects"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "MPL-2.0"}
authors = [
    {name = "Pointmatic", email = "contact@pointmatic.com"}
]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: Mozilla Public License 2.0 (MPL-2.0)",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]

[project.scripts]
devdoctalk = "devdoctalk.cli:main"

[project.urls]
Homepage = "https://github.com/pointmatic/devdoctalk"
Documentation = "https://github.com/pointmatic/devdoctalk/blob/main/README.md"
Repository = "https://github.com/pointmatic/devdoctalk"
Issues = "https://github.com/pointmatic/devdoctalk/issues"

[tool.setuptools.packages.find]
where = ["."]
include = ["devdoctalk*"]

[tool.setuptools.package-data]
devdoctalk = ["py.typed"]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]

[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[tool.ruff]
line-length = 100
target-version = "py310"
```

---

## Language-Agnostic Design

### **Phase 1: Python Support (v1.0.0)**
- Templates work for Python projects
- No language-specific assumptions in core code
- Foundation for multi-language support

### **Phase 2: Multi-Language Support (v1.1.0+)**
```bash
# Future: Language detection and templates
devdoctalk --init --lang python
devdoctalk --init --lang javascript
devdoctalk --init --lang rust

# Language-specific template directories
templates/
├── v1.1.0/
│   ├── python/
│   │   └── docs/
│   ├── javascript/
│   │   └── docs/
│   └── rust/
│       └── docs/
```

### **Language-Agnostic Features**
- Q&A workflow (Phase 0-16) works for any language
- Project context template is universal
- Technical specs are language-agnostic
- Only language-specific: building guide, dependencies guide

---

## Refactoring Guidelines

### **Python Coding Standards**

**Type Hints:**
```python
from pathlib import Path
from typing import Optional, Literal

def copy_template_file(
    src: Path,
    dest: Path,
    *,
    overwrite: bool = False
) -> bool:
    """
    Copy a template file from source to destination.
    
    Args:
        src: Source file path
        dest: Destination file path
        overwrite: Whether to overwrite existing files
    
    Returns:
        True if file was copied, False if skipped
    
    Raises:
        FileNotFoundError: If source file doesn't exist
        PermissionError: If destination is not writable
    """
    ...
```

**Error Handling:**
```python
from devdoctalk.utils import log_error

def upgrade_templates() -> int:
    """Upgrade project templates to latest version."""
    try:
        template_dir = find_template_directory()
        if not template_dir.exists():
            log_error(f"Template directory not found: {template_dir}")
            log_error("Run 'devdoctalk install' to download templates.")
            return 1
        
        # Perform upgrade...
        return 0
        
    except PermissionError as e:
        log_error(f"Permission denied: {e}")
        return 1
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        return 1
```

**Logging:**
```python
from devdoctalk.utils import log_info, log_warning, log_error

# Usage
log_info("Copying templates from v1.0.0...")
log_warning("Modified files detected. Creating suffixed copies.")
log_error("Template directory not found.")
```

**Path Handling:**
```python
from pathlib import Path

# Use pathlib for all file operations
template_dir = Path.home() / '.devdoctalk' / 'templates'
project_dir = Path.cwd() / '.devdoctalk'

# Iterate over files
for template_file in template_dir.glob('**/*__t__*.md'):
    dest_file = target_path_for_source(template_dir, template_file)
    copy_template_file(template_file, dest_file)
```

**JSON Handling:**
```python
import json
from pathlib import Path
from typing import Any

def read_package_metadata(metadata_file: Path) -> dict[str, Any]:
    """Read package metadata from JSON file."""
    with metadata_file.open('r') as f:
        return json.load(f)

def write_packages_conf(packages: list[str]) -> None:
    """Write package configuration."""
    config_file = Path('.devdoctalk') / 'packages.conf'
    config_file.parent.mkdir(parents=True, exist_ok=True)
    config_file.write_text('\n'.join(packages) + '\n')
```

**Testing:**
```python
import pytest
from pathlib import Path
from devdoctalk.version import compare_semver

def test_compare_semver_equal():
    assert compare_semver('1.0.0', '1.0.0') == 0

def test_compare_semver_greater():
    assert compare_semver('1.1.0', '1.0.0') == 1

def test_compare_semver_less():
    assert compare_semver('1.0.0', '1.1.0') == -1

def test_compare_semver_with_v_prefix():
    assert compare_semver('v1.0.0', 'v1.0.0') == 0
```

---

## Integration Strategy

### **Option A: Independent Tools**
```bash
# Users run separately
pyve --init                              # Python environment
devdoctalk --init --packages web         # Documentation
```

**Pros:**
- Clean separation
- No coupling
- Each tool focused

**Cons:**
- Two commands to remember
- Separate installations

### **Option B: Pyve Recommends DevDocTalk**
```bash
# Pyve suggests devdoctalk after init
pyve --init
# Output:
# Python environment initialized.
# 
# TIP: Add documentation with DevDocTalk:
#   devdoctalk --init --packages web persistence
#   https://github.com/pointmatic/devdoctalk
```

**Pros:**
- Smooth discovery
- No hard dependency
- User choice

**Cons:**
- Requires coordination

### **Option C: DevDocTalk Detects Pyve**
```bash
# DevDocTalk checks for Python environment
devdoctalk --init
# Output:
# Detected Python project (pyve environment found)
# Initializing documentation for Python project...
```

**Pros:**
- Smart integration
- Automatic language detection

**Cons:**
- Creates soft dependency

### **Recommended: Option B + C**
- Pyve recommends devdoctalk (soft suggestion)
- DevDocTalk detects pyve (smart defaults)
- Both work independently

---

## Migration Checklist

### **DevDocTalk Repository Setup**
- [ ] Create repository structure
- [ ] Set up modular architecture (lib/ directory)
- [ ] Create initial README
- [ ] Create CONTRIBUTING guide
- [ ] Add LICENSE (MPL 2.0)
- [ ] Initialize git repository

### **Code Translation (Shell → Python)**
- [ ] Set up Python package structure
- [ ] Create `pyproject.toml` with dependencies
- [ ] Translate template management (shell → Python)
- [ ] Translate package management (shell → Python)
- [ ] Translate upgrade/update logic (shell → Python)
- [ ] Translate status management (shell → Python)
- [ ] Implement proper error handling with exceptions
- [ ] Add type hints to all functions
- [ ] Use pathlib for all file operations
- [ ] Use json module for metadata parsing
- [ ] Update all names (pyve → devdoctalk)
- [ ] Update all paths (.pyve → .devdoctalk)

### **Template Migration**
- [ ] Copy templates/v0.5.8/ → templates/v1.0.0/
- [ ] Review and update all templates
- [ ] Remove Python-specific assumptions where possible
- [ ] Update template metadata
- [ ] Create .packages.json with package descriptions

### **Testing**
- [ ] Write unit tests for all modules (pytest)
- [ ] Test `init` command with foundation docs
- [ ] Test `init` command with packages
- [ ] Test `upgrade` command with conflicts
- [ ] Test `list` command
- [ ] Test `add`/`remove` commands
- [ ] Test `clear-status` command
- [ ] Test `install`/`uninstall` commands
- [ ] Test version comparison logic
- [ ] Test path manipulation utilities
- [ ] Test JSON metadata parsing
- [ ] Integration tests for full workflows
- [ ] Test on Python 3.10, 3.11, 3.12
- [ ] Type checking with mypy
- [ ] Linting with ruff

### **Documentation**
- [ ] Write comprehensive README with installation instructions
- [ ] Document all CLI commands with examples
- [ ] Add docstrings to all functions (Google style)
- [ ] Create integration guide (using with pyve)
- [ ] Create language support guide
- [ ] Document package system
- [ ] Document Q&A workflow
- [ ] Add API documentation (Sphinx or mkdocs)
- [ ] Create CONTRIBUTING guide for Python development
- [ ] Document testing procedures

### **Pyve Updates**
- [ ] Create pyve_new.sh (v0.6.0)
- [ ] Test pyve_new.sh thoroughly
- [ ] Add deprecation warnings to pyve.sh (v0.7.0)
- [ ] Update pyve README
- [ ] Update pyve documentation
- [ ] Plan migration path for users

---

## Success Criteria

### **DevDocTalk v1.0.0**
- ✅ All template features working
- ✅ All package features working
- ✅ Upgrade system working
- ✅ Clean output (no xtrace pollution)
- ✅ Comprehensive documentation
- ✅ Modular architecture
- ✅ Language-agnostic foundation

### **Pyve v0.6.0**
- ✅ Pure environment management
- ✅ ~600-700 lines total
- ✅ Clean output (no xtrace pollution)
- ✅ Consistent messaging
- ✅ All environment features working
- ✅ Comprehensive testing

### **Pyve v1.0.0**
- ✅ Documentation features completely removed
- ✅ Clean, focused tool
- ✅ Professional quality
- ✅ Well documented

---

## Timeline Summary

| Week | Milestone |
|------|-----------|
| 1 | Create DevDocTalk repository structure |
| 2-3 | Extract and refactor code to DevDocTalk |
| 4-7 | Rewrite Pyve v0.6.0 (pyve_new.sh) |
| 8 | Release Pyve v0.7.0 with deprecation warnings |
| 9 | Release DevDocTalk v1.0.0 |
| 10 | Release Pyve v1.0.0 (clean, focused) |

---

## Notes

- **Migration is one-way:** Once users move to devdoctalk, they don't go back
- **Backward compatibility:** Pyve v0.7.0 still works with old .pyve/ directories
- **Clean break:** Pyve v1.0.0 removes all documentation features
- **User impact:** Only one user (you), so migration is straightforward
- **Future vision:** DevDocTalk becomes language-agnostic documentation framework

---

## References

- Pyve Versions Spec: `docs/specs/versions_spec.md`
- Pyve Codebase Spec: `docs/specs/codebase_spec.md`
- Pyve Decision Log: `docs/specs/decisions_spec.md`
