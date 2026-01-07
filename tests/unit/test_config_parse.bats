#!/usr/bin/env bats
#
# Unit tests for lib/utils.sh - YAML config parsing
# Tests read_config_value() function for parsing .pyve/config
#

# Load test helpers
load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

#============================================================
# read_config_value() - Top-level keys
#============================================================

@test "read_config_value: reads top-level backend key" {
    create_pyve_config "backend: venv"
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "read_config_value: reads top-level backend key with micromamba" {
    create_pyve_config "backend: micromamba"
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "read_config_value: returns empty for non-existent key" {
    create_pyve_config "backend: venv"
    
    run read_config_value "nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "read_config_value: returns empty when config file doesn't exist" {
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "read_config_value: handles empty config file" {
    mkdir -p .pyve
    touch .pyve/config
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

#============================================================
# read_config_value() - Nested keys
#============================================================

@test "read_config_value: reads nested venv.directory key" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: venv
venv:
  directory: .venv
EOF
    
    run read_config_value "venv.directory"
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

@test "read_config_value: reads nested micromamba.env_name key" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: micromamba
micromamba:
  env_name: myproject
EOF
    
    run read_config_value "micromamba.env_name"
    [ "$status" -eq 0 ]
    [ "$output" = "myproject" ]
}

@test "read_config_value: reads nested python.version key" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
python:
  version: 3.11.5
EOF
    
    run read_config_value "python.version"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11.5" ]
}

@test "read_config_value: returns empty for non-existent nested key" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
venv:
  directory: .venv
EOF
    
    run read_config_value "venv.nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "read_config_value: returns empty for non-existent section" {
    create_pyve_config "backend: venv"
    
    run read_config_value "nonexistent.key"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

#============================================================
# read_config_value() - Value formats
#============================================================

@test "read_config_value: handles values with quotes" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: "venv"
EOF
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "read_config_value: handles values with single quotes" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: 'micromamba'
EOF
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "read_config_value: handles values with extra whitespace" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend:   venv   
EOF
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "read_config_value: handles numeric values" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
python:
  version: 3.11
EOF
    
    run read_config_value "python.version"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11" ]
}

#============================================================
# read_config_value() - Complex configs
#============================================================

@test "read_config_value: reads from complex multi-section config" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
backend: micromamba
venv:
  directory: .venv
micromamba:
  env_name: myproject
  env_file: environment.yml
python:
  version: 3.11.5
EOF
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
    
    run read_config_value "venv.directory"
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
    
    run read_config_value "micromamba.env_name"
    [ "$status" -eq 0 ]
    [ "$output" = "myproject" ]
    
    run read_config_value "python.version"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11.5" ]
}

@test "read_config_value: handles config with comments" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
# This is a comment
backend: venv
# Another comment
venv:
  # Nested comment
  directory: .venv
EOF
    
    run read_config_value "backend"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
    
    run read_config_value "venv.directory"
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

#============================================================
# config_file_exists() tests
#============================================================

@test "config_file_exists: returns 0 when config exists" {
    create_pyve_config "backend: venv"
    
    run config_file_exists
    [ "$status" -eq 0 ]
}

@test "config_file_exists: returns 1 when config doesn't exist" {
    run config_file_exists
    [ "$status" -eq 1 ]
}

@test "config_file_exists: returns 0 for empty config file" {
    mkdir -p .pyve
    touch .pyve/config
    
    run config_file_exists
    [ "$status" -eq 0 ]
}
