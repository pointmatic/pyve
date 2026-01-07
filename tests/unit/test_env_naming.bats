#!/usr/bin/env bats
#
# Unit tests for lib/micromamba_env.sh - Environment naming functions
# Tests sanitize_environment_name(), validate_environment_name(), and resolve_environment_name()
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
# sanitize_environment_name() tests
#============================================================

@test "sanitize_environment_name: converts to lowercase" {
    run sanitize_environment_name "MyProject"
    [ "$status" -eq 0 ]
    [ "$output" = "myproject" ]
}

@test "sanitize_environment_name: replaces spaces with hyphens" {
    run sanitize_environment_name "my project"
    [ "$status" -eq 0 ]
    [ "$output" = "my-project" ]
}

@test "sanitize_environment_name: removes special characters" {
    run sanitize_environment_name "my@project#123"
    [ "$status" -eq 0 ]
    [ "$output" = "my-project-123" ]
}

@test "sanitize_environment_name: keeps alphanumeric, hyphens, underscores" {
    run sanitize_environment_name "my_project-123"
    [ "$status" -eq 0 ]
    [ "$output" = "my_project-123" ]
}

@test "sanitize_environment_name: removes leading hyphens" {
    run sanitize_environment_name "-myproject"
    [ "$status" -eq 0 ]
    [ "$output" = "myproject" ]
}

@test "sanitize_environment_name: removes trailing hyphens" {
    run sanitize_environment_name "myproject-"
    [ "$status" -eq 0 ]
    [ "$output" = "myproject" ]
}

@test "sanitize_environment_name: adds 'env-' prefix if starts with number" {
    run sanitize_environment_name "123project"
    [ "$status" -eq 0 ]
    [ "$output" = "env-123project" ]
}

@test "sanitize_environment_name: allows starting with underscore" {
    run sanitize_environment_name "_myproject"
    [ "$status" -eq 0 ]
    [ "$output" = "_myproject" ]
}

@test "sanitize_environment_name: truncates to 255 characters" {
    local long_name=$(printf 'a%.0s' {1..300})
    run sanitize_environment_name "$long_name"
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 255 ]
}

@test "sanitize_environment_name: returns error for empty string" {
    run sanitize_environment_name ""
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
}

@test "sanitize_environment_name: handles complex name" {
    run sanitize_environment_name "My Cool Project 2024!"
    [ "$status" -eq 0 ]
    [ "$output" = "my-cool-project-2024" ]
}

#============================================================
# is_reserved_environment_name() tests
#============================================================

@test "is_reserved_environment_name: returns 0 for 'base'" {
    run is_reserved_environment_name "base"
    [ "$status" -eq 0 ]
}

@test "is_reserved_environment_name: returns 0 for 'root'" {
    run is_reserved_environment_name "root"
    [ "$status" -eq 0 ]
}

@test "is_reserved_environment_name: returns 0 for 'default'" {
    run is_reserved_environment_name "default"
    [ "$status" -eq 0 ]
}

@test "is_reserved_environment_name: returns 0 for 'conda'" {
    run is_reserved_environment_name "conda"
    [ "$status" -eq 0 ]
}

@test "is_reserved_environment_name: returns 0 for 'mamba'" {
    run is_reserved_environment_name "mamba"
    [ "$status" -eq 0 ]
}

@test "is_reserved_environment_name: returns 0 for 'micromamba'" {
    run is_reserved_environment_name "micromamba"
    [ "$status" -eq 0 ]
}

@test "is_reserved_environment_name: returns 1 for non-reserved name" {
    run is_reserved_environment_name "myproject"
    [ "$status" -eq 1 ]
}

#============================================================
# validate_environment_name() tests
#============================================================

@test "validate_environment_name: accepts valid name" {
    run validate_environment_name "myproject"
    [ "$status" -eq 0 ]
}

@test "validate_environment_name: accepts name with hyphens" {
    run validate_environment_name "my-project"
    [ "$status" -eq 0 ]
}

@test "validate_environment_name: accepts name with underscores" {
    run validate_environment_name "my_project"
    [ "$status" -eq 0 ]
}

@test "validate_environment_name: accepts name with numbers" {
    run validate_environment_name "project123"
    [ "$status" -eq 0 ]
}

@test "validate_environment_name: accepts name starting with underscore" {
    run validate_environment_name "_myproject"
    [ "$status" -eq 0 ]
}

@test "validate_environment_name: rejects empty name" {
    run validate_environment_name ""
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects reserved name 'base'" {
    run validate_environment_name "base"
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects reserved name 'root'" {
    run validate_environment_name "root"
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects name with spaces" {
    run validate_environment_name "my project"
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects name with special characters" {
    run validate_environment_name "my@project"
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects name starting with number" {
    run validate_environment_name "123project"
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects name starting with hyphen" {
    run validate_environment_name "-myproject"
    [ "$status" -eq 1 ]
}

@test "validate_environment_name: rejects name longer than 255 characters" {
    local long_name=$(printf 'a%.0s' {1..300})
    run validate_environment_name "$long_name"
    [ "$status" -eq 1 ]
}

#============================================================
# resolve_environment_name() tests
#============================================================

@test "resolve_environment_name: CLI flag takes priority" {
    create_pyve_config "micromamba:\n  env_name: config-name"
    create_environment_yml "file-name" "python=3.11"
    
    run resolve_environment_name "cli-name"
    [ "$status" -eq 0 ]
    [ "$output" = "cli-name" ]
}

@test "resolve_environment_name: config file takes priority over environment.yml" {
    mkdir -p .pyve
    cat > .pyve/config << EOF
micromamba:
  env_name: config-name
EOF
    create_environment_yml "file-name" "python=3.11"
    
    run resolve_environment_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "config-name" ]
}

@test "resolve_environment_name: environment.yml takes priority over directory name" {
    create_environment_yml "file-name" "python=3.11"
    
    run resolve_environment_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "file-name" ]
}

@test "resolve_environment_name: uses sanitized directory name as fallback" {
    # Current directory is TEST_DIR which is a temp directory
    local dir_name=$(basename "$TEST_DIR")
    local expected=$(sanitize_environment_name "$dir_name")
    
    run resolve_environment_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "$expected" ]
}

@test "resolve_environment_name: returns empty CLI flag as no priority" {
    create_environment_yml "file-name" "python=3.11"
    
    run resolve_environment_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "file-name" ]
}
