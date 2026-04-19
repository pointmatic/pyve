#!/usr/bin/env bats

#============================================================
# Unit Tests for Version Tracking Functions
#
# Tests for lib/version.sh functions including version
# comparison, validation, and structure checks.
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
    VERSION="0.8.8"
}

teardown() {
    # Clean up test directory
    cd /
    rm -rf "$TEST_DIR"
}

#------------------------------------------------------------
# Version Comparison Tests
#------------------------------------------------------------

@test "compare_versions: equal versions" {
    result="$(compare_versions "0.8.8" "0.8.8")"
    [ "$result" = "equal" ]
}

@test "compare_versions: first version greater" {
    result="$(compare_versions "0.8.9" "0.8.8")"
    [ "$result" = "greater" ]
}

@test "compare_versions: first version less" {
    result="$(compare_versions "0.8.7" "0.8.8")"
    [ "$result" = "less" ]
}

@test "compare_versions: major version difference" {
    result="$(compare_versions "1.0.0" "0.8.8")"
    [ "$result" = "greater" ]
}

@test "compare_versions: minor version difference" {
    result="$(compare_versions "0.9.0" "0.8.8")"
    [ "$result" = "greater" ]
}

@test "compare_versions: patch version difference" {
    result="$(compare_versions "0.8.10" "0.8.9")"
    [ "$result" = "greater" ]
}

@test "compare_versions: multi-digit versions" {
    result="$(compare_versions "0.10.5" "0.9.20")"
    [ "$result" = "greater" ]
}

@test "compare_versions: different length versions" {
    result="$(compare_versions "0.8" "0.8.0")"
    [ "$result" = "equal" ]
}

@test "compare_versions: zero components" {
    result="$(compare_versions "0.0.0" "0.0.1")"
    [ "$result" = "less" ]
}

@test "compare_versions: single-component versions" {
    result="$(compare_versions "1" "2")"
    [ "$result" = "less" ]
}

@test "compare_versions: single vs triple component equal" {
    result="$(compare_versions "1" "1.0.0")"
    [ "$result" = "equal" ]
}

#------------------------------------------------------------
# Version Validation Tests
#------------------------------------------------------------

@test "validate_pyve_version: no config file" {
    run validate_pyve_version
    [ "$status" -eq 0 ]
}

@test "validate_pyve_version: no version field in config" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
EOF
    
    run validate_pyve_version
    [ "$status" -eq 0 ]
}

@test "validate_pyve_version: matching version" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    
    run validate_pyve_version
    [ "$status" -eq 0 ]
}

@test "validate_pyve_version: older version warns" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.6.6"
backend: venv
EOF
    
    run validate_pyve_version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.6.6" ]]
    [[ "$output" =~ "0.8.8" ]]
}

@test "validate_pyve_version: newer version warns" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.9.0"
backend: venv
EOF
    
    run validate_pyve_version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.9.0" ]]
    [[ "$output" =~ "0.8.8" ]]
}

@test "validate_pyve_version: skip check with env var" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.6.6"
backend: venv
EOF
    
    PYVE_SKIP_VERSION_CHECK=1 run validate_pyve_version
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#------------------------------------------------------------
# Structure Validation Tests
#------------------------------------------------------------

@test "validate_installation_structure: missing .pyve directory" {
    run validate_installation_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing .pyve directory" ]]
}

@test "validate_installation_structure: missing config file" {
    mkdir -p .pyve
    
    run validate_installation_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing .pyve/config" ]]
}

@test "validate_installation_structure: missing backend in config" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
EOF
    
    run validate_installation_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No backend specified" ]]
}

@test "validate_installation_structure: unknown backend" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: unknown
EOF
    
    run validate_installation_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown backend" ]]
}

@test "validate_installation_structure: valid venv project" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    mkdir -p .venv/bin
    touch .venv/bin/python
    chmod +x .venv/bin/python
    touch .env
    
    run validate_installation_structure
    [ "$status" -eq 0 ]
}

@test "validate_installation_structure: valid venv missing .env warns but passes" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    mkdir -p .venv/bin
    touch .venv/bin/python
    chmod +x .venv/bin/python
    
    run validate_installation_structure
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Missing .env" ]]
}

#------------------------------------------------------------
# Venv Structure Validation Tests
#------------------------------------------------------------

@test "validate_venv_structure: missing venv directory" {
    run validate_venv_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Virtual environment not found" ]]
}

@test "validate_venv_structure: valid venv directory" {
    mkdir -p .venv/bin
    touch .venv/bin/python
    chmod +x .venv/bin/python
    
    run validate_venv_structure
    [ "$status" -eq 0 ]
}

@test "validate_venv_structure: venv without python" {
    mkdir -p .venv/bin
    
    run validate_venv_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "missing Python executable" ]]
}

@test "validate_venv_structure: custom venv directory" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: custom_venv
EOF
    
    mkdir -p custom_venv/bin
    touch custom_venv/bin/python
    chmod +x custom_venv/bin/python
    
    run validate_venv_structure
    [ "$status" -eq 0 ]
}

#------------------------------------------------------------
# Micromamba Structure Validation Tests
#------------------------------------------------------------

@test "validate_micromamba_structure: missing environment.yml" {
    run validate_micromamba_structure
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing environment.yml" ]]
}

@test "validate_micromamba_structure: valid environment.yml" {
    cat > environment.yml << EOF
name: test-env
channels:
  - conda-forge
dependencies:
  - python=3.11
EOF
    
    run validate_micromamba_structure
    [ "$status" -eq 0 ]
}

#------------------------------------------------------------
# Config Writing Tests
#------------------------------------------------------------

@test "write_config_with_version: creates config with version" {
    write_config_with_version
    
    [ -f ".pyve/config" ]
    
    version=$(grep "^pyve_version:" .pyve/config | awk '{print $2}' | tr -d '"')
    [ "$version" = "0.8.8" ]
}

@test "write_config_with_version: preserves existing config" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: .venv
EOF
    
    write_config_with_version
    
    # Check version was added
    version=$(grep "^pyve_version:" .pyve/config | awk '{print $2}' | tr -d '"')
    [ "$version" = "0.8.8" ]
    
    # Check existing config preserved
    backend=$(grep "^backend:" .pyve/config | awk '{print $2}')
    [ "$backend" = "venv" ]
}

@test "update_config_version: updates existing version" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.6.6"
backend: venv
EOF
    
    update_config_version
    
    version=$(grep "^pyve_version:" .pyve/config | awk '{print $2}' | tr -d '"')
    [ "$version" = "0.8.8" ]
}

@test "update_config_version: no-op if version matches" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.8.8"
backend: venv
EOF
    
    update_config_version
    
    version=$(grep "^pyve_version:" .pyve/config | awk '{print $2}' | tr -d '"')
    [ "$version" = "0.8.8" ]
}

@test "update_config_version: fails if no config file" {
    run update_config_version
    [ "$status" -eq 1 ]
}

@test "update_config_version: fails if config has no backend" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.6.6"
EOF
    
    run update_config_version
    [ "$status" -eq 1 ]
}

@test "write_config_with_version: replaces existing version" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "0.6.6"
backend: venv
EOF
    
    write_config_with_version
    
    # Version should be updated
    version=$(grep "^pyve_version:" .pyve/config | awk '{print $2}' | tr -d '"')
    [ "$version" = "0.8.8" ]
    
    # Old version should not appear
    run grep "0.6.6" .pyve/config
    [ "$status" -eq 1 ]
    
    # Backend should be preserved
    backend=$(grep "^backend:" .pyve/config | awk '{print $2}')
    [ "$backend" = "venv" ]
}
