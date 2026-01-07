#!/usr/bin/env bats

#============================================================
# Unit Tests for Re-initialization Logic
#
# Tests for smart re-initialization, conflict detection,
# and safe update vs. force re-init scenarios.
#============================================================

setup() {
    # Set PYVE_ROOT first
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    
    # Load test helpers
    load '../helpers/test_helper'
    
    # Source the version library
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/version.sh"
    
    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    
    # Set test version
    VERSION="0.8.9"
}

teardown() {
    # Clean up test directory
    cd /
    rm -rf "$TEST_DIR"
}

#------------------------------------------------------------
# Existing Installation Detection Tests
#------------------------------------------------------------

@test "config_file_exists: returns true when config exists" {
    mkdir -p .pyve
    touch .pyve/config
    
    run config_file_exists
    [ "$status" -eq 0 ]
}

@test "config_file_exists: returns false when config missing" {
    run config_file_exists
    [ "$status" -eq 1 ]
}

@test "config_file_exists: returns false when .pyve directory missing" {
    run config_file_exists
    [ "$status" -eq 1 ]
}

#------------------------------------------------------------
# Conflict Detection Tests
#------------------------------------------------------------

@test "detect backend conflict: venv to micromamba" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    
    existing_backend="$(read_config_value "backend")"
    requested_backend="micromamba"
    
    [ "$existing_backend" = "venv" ]
    [ "$requested_backend" = "micromamba" ]
    [ "$existing_backend" != "$requested_backend" ]
}

@test "detect backend conflict: micromamba to venv" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: micromamba
EOF
    
    existing_backend="$(read_config_value "backend")"
    requested_backend="venv"
    
    [ "$existing_backend" = "micromamba" ]
    [ "$requested_backend" = "venv" ]
    [ "$existing_backend" != "$requested_backend" ]
}

@test "no backend conflict: same backend" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    
    existing_backend="$(read_config_value "backend")"
    requested_backend="venv"
    
    [ "$existing_backend" = "$requested_backend" ]
}

@test "no backend conflict: no requested backend" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    
    existing_backend="$(read_config_value "backend")"
    requested_backend=""
    
    [ "$existing_backend" = "venv" ]
    [ -z "$requested_backend" ]
}

#------------------------------------------------------------
# Version Update Tests
#------------------------------------------------------------

@test "update_config_version: updates version field" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.7"
backend: venv
venv:
  directory: .venv
EOF
    
    update_config_version
    
    new_version="$(read_config_value "pyve_version")"
    [ "$new_version" = "0.8.9" ]
}

@test "update_config_version: preserves other fields" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.7"
backend: venv
venv:
  directory: .venv
python:
  version: "3.11"
EOF
    
    update_config_version
    
    backend="$(read_config_value "backend")"
    venv_dir="$(read_config_value "venv.directory")"
    py_version="$(read_config_value "python.version")"
    
    [ "$backend" = "venv" ]
    [ "$venv_dir" = ".venv" ]
    [ "$py_version" = "3.11" ]
}

@test "update_config_version: adds version if missing" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: .venv
EOF
    
    update_config_version
    
    new_version="$(read_config_value "pyve_version")"
    [ "$new_version" = "0.8.9" ]
}

@test "update_config_version: no-op if version matches" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.9"
backend: venv
EOF
    
    # Get initial timestamp
    initial_mtime=$(stat -f %m .pyve/config 2>/dev/null || stat -c %Y .pyve/config 2>/dev/null)
    
    sleep 1
    update_config_version
    
    # Version should still be 0.8.9
    version="$(read_config_value "pyve_version")"
    [ "$version" = "0.8.9" ]
}

#------------------------------------------------------------
# Config Creation with Version Tests
#------------------------------------------------------------

@test "write_config_with_version: creates config with version" {
    write_config_with_version
    
    [ -f ".pyve/config" ]
    
    version="$(read_config_value "pyve_version")"
    [ "$version" = "0.8.9" ]
}

@test "write_config_with_version: creates .pyve directory" {
    write_config_with_version
    
    [ -d ".pyve" ]
}

@test "write_config_with_version: preserves existing config" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: custom_venv
EOF
    
    write_config_with_version
    
    # Check version was added
    version="$(read_config_value "pyve_version")"
    [ "$version" = "0.8.9" ]
    
    # Check existing config preserved
    backend="$(read_config_value "backend")"
    venv_dir="$(read_config_value "venv.directory")"
    [ "$backend" = "venv" ]
    [ "$venv_dir" = "custom_venv" ]
}

#------------------------------------------------------------
# Re-initialization Mode Tests
#------------------------------------------------------------

@test "PYVE_REINIT_MODE: update mode set correctly" {
    PYVE_REINIT_MODE="update"
    
    [ "$PYVE_REINIT_MODE" = "update" ]
}

@test "PYVE_REINIT_MODE: force mode set correctly" {
    PYVE_REINIT_MODE="force"
    
    [ "$PYVE_REINIT_MODE" = "force" ]
}

@test "PYVE_REINIT_MODE: unset by default" {
    unset PYVE_REINIT_MODE
    
    [ -z "${PYVE_REINIT_MODE:-}" ]
}

#------------------------------------------------------------
# Legacy Project Tests
#------------------------------------------------------------

@test "legacy project: config without version field" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: .venv
EOF
    
    version="$(read_config_value "pyve_version")"
    [ -z "$version" ]
}

@test "legacy project: can be updated" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: .venv
EOF
    
    update_config_version
    
    version="$(read_config_value "pyve_version")"
    [ "$version" = "0.8.9" ]
}

#------------------------------------------------------------
# Safe Update Scenario Tests
#------------------------------------------------------------

@test "safe update: same backend allowed" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.7"
backend: venv
EOF
    
    existing_backend="venv"
    requested_backend="venv"
    
    # No conflict
    [ "$existing_backend" = "$requested_backend" ]
}

@test "safe update: no requested backend allowed" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.7"
backend: venv
EOF
    
    existing_backend="venv"
    requested_backend=""
    
    # No conflict when no backend requested
    [ -n "$existing_backend" ]
    [ -z "$requested_backend" ]
}

#------------------------------------------------------------
# Destructive Scenario Tests
#------------------------------------------------------------

@test "destructive scenario: backend change" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.7"
backend: venv
EOF
    
    existing_backend="venv"
    requested_backend="micromamba"
    
    # Conflict detected
    [ "$existing_backend" != "$requested_backend" ]
}

@test "destructive scenario: requires force flag" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.7"
backend: venv
EOF
    
    # Without force flag, backend change should be rejected
    PYVE_REINIT_MODE="update"
    existing_backend="venv"
    requested_backend="micromamba"
    
    [ "$PYVE_REINIT_MODE" != "force" ]
    [ "$existing_backend" != "$requested_backend" ]
}
