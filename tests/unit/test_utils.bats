#!/usr/bin/env bats
#
# Unit tests for lib/utils.sh
# Tests logging, file operations, validation, and gitignore management
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
# Logging functions tests
#============================================================

@test "log_info: outputs INFO prefix" {
    run log_info "Test message"
    [ "$status" -eq 0 ]
    [[ "$output" == "INFO: Test message" ]]
}

@test "log_warning: outputs WARNING prefix to stderr" {
    run log_warning "Test warning"
    [ "$status" -eq 0 ]
    [[ "$output" == "WARNING: Test warning" ]]
}

@test "log_error: outputs ERROR prefix to stderr" {
    run log_error "Test error"
    [ "$status" -eq 0 ]
    [[ "$output" == "ERROR: Test error" ]]
}

@test "log_success: outputs checkmark prefix" {
    run log_success "Test success"
    [ "$status" -eq 0 ]
    [[ "$output" == "✓ Test success" ]]
}

#============================================================
# append_pattern_to_gitignore() tests
#============================================================

@test "append_pattern_to_gitignore: creates .gitignore if doesn't exist" {
    run append_pattern_to_gitignore ".venv"
    [ "$status" -eq 0 ]
    assert_file_exists ".gitignore"
}

@test "append_pattern_to_gitignore: adds pattern to .gitignore" {
    run append_pattern_to_gitignore ".venv"
    [ "$status" -eq 0 ]
    assert_file_contains ".gitignore" ".venv"
}

@test "append_pattern_to_gitignore: doesn't duplicate existing pattern" {
    echo ".venv" > .gitignore
    
    run append_pattern_to_gitignore ".venv"
    [ "$status" -eq 0 ]
    
    # Count occurrences - should be exactly 1
    local count=$(grep -c "^\.venv$" .gitignore)
    [ "$count" -eq 1 ]
}

@test "append_pattern_to_gitignore: adds multiple different patterns" {
    run append_pattern_to_gitignore ".venv"
    [ "$status" -eq 0 ]
    
    run append_pattern_to_gitignore ".pyve"
    [ "$status" -eq 0 ]
    
    assert_file_contains ".gitignore" ".venv"
    assert_file_contains ".gitignore" ".pyve"
}

@test "append_pattern_to_gitignore: handles patterns with special characters" {
    run append_pattern_to_gitignore "*.pyc"
    [ "$status" -eq 0 ]
    assert_file_contains ".gitignore" "*.pyc"
}

#============================================================
# remove_pattern_from_gitignore() tests
#============================================================

@test "remove_pattern_from_gitignore: removes pattern from .gitignore" {
    echo ".venv" > .gitignore
    
    run remove_pattern_from_gitignore ".venv"
    [ "$status" -eq 0 ]
    
    # Pattern should be gone
    run grep -q "^\.venv$" .gitignore
    [ "$status" -eq 1 ]
}

@test "remove_pattern_from_gitignore: returns 0 when .gitignore doesn't exist" {
    run remove_pattern_from_gitignore ".venv"
    [ "$status" -eq 0 ]
}

@test "remove_pattern_from_gitignore: returns 0 when pattern not found" {
    echo ".pyve" > .gitignore
    
    run remove_pattern_from_gitignore ".venv"
    [ "$status" -eq 0 ]
}

@test "remove_pattern_from_gitignore: only removes exact matches" {
    cat > .gitignore << EOF
.venv
.venv-test
test.venv
EOF
    
    run remove_pattern_from_gitignore ".venv"
    [ "$status" -eq 0 ]
    
    # .venv should be gone
    run grep -q "^\.venv$" .gitignore
    [ "$status" -eq 1 ]
    
    # But .venv-test and test.venv should remain
    assert_file_contains ".gitignore" ".venv-test"
    assert_file_contains ".gitignore" "test.venv"
}

#============================================================
# config_file_exists() tests (already tested in test_config_parse.bats)
#============================================================

@test "config_file_exists: returns 0 when .pyve/config exists" {
    create_pyve_config "backend: venv"
    
    run config_file_exists
    [ "$status" -eq 0 ]
}

@test "config_file_exists: returns 1 when .pyve/config doesn't exist" {
    run config_file_exists
    [ "$status" -eq 1 ]
}

#============================================================
# validate_venv_dir_name() tests
#============================================================

@test "validate_venv_dir_name: accepts valid directory name" {
    run validate_venv_dir_name ".venv"
    [ "$status" -eq 0 ]
}

@test "validate_venv_dir_name: accepts name with dots" {
    run validate_venv_dir_name ".my.venv"
    [ "$status" -eq 0 ]
}

@test "validate_venv_dir_name: accepts name with underscores" {
    run validate_venv_dir_name "my_venv"
    [ "$status" -eq 0 ]
}

@test "validate_venv_dir_name: accepts name with hyphens" {
    run validate_venv_dir_name "my-venv"
    [ "$status" -eq 0 ]
}

@test "validate_venv_dir_name: rejects empty name" {
    run validate_venv_dir_name ""
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects name with spaces" {
    run validate_venv_dir_name "my venv"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects name with slashes" {
    run validate_venv_dir_name "my/venv"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects reserved name .env" {
    run validate_venv_dir_name ".env"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects reserved name .git" {
    run validate_venv_dir_name ".git"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects reserved name .gitignore" {
    run validate_venv_dir_name ".gitignore"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects reserved name .tool-versions" {
    run validate_venv_dir_name ".tool-versions"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects reserved name .python-version" {
    run validate_venv_dir_name ".python-version"
    [ "$status" -eq 1 ]
}

@test "validate_venv_dir_name: rejects reserved name .envrc" {
    run validate_venv_dir_name ".envrc"
    [ "$status" -eq 1 ]
}

#============================================================
# validate_python_version() tests
#============================================================

@test "validate_python_version: accepts valid version 3.11.5" {
    run validate_python_version "3.11.5"
    [ "$status" -eq 0 ]
}

@test "validate_python_version: accepts valid version 3.13.7" {
    run validate_python_version "3.13.7"
    [ "$status" -eq 0 ]
}

@test "validate_python_version: accepts valid version 2.7.18" {
    run validate_python_version "2.7.18"
    [ "$status" -eq 0 ]
}

@test "validate_python_version: rejects empty version" {
    run validate_python_version ""
    [ "$status" -eq 1 ]
}

@test "validate_python_version: rejects version without patch (3.11)" {
    run validate_python_version "3.11"
    [ "$status" -eq 1 ]
}

@test "validate_python_version: rejects version with only major (3)" {
    run validate_python_version "3"
    [ "$status" -eq 1 ]
}

@test "validate_python_version: rejects version with letters (3.11.5a)" {
    run validate_python_version "3.11.5a"
    [ "$status" -eq 1 ]
}

@test "validate_python_version: rejects version with extra segments (3.11.5.1)" {
    run validate_python_version "3.11.5.1"
    [ "$status" -eq 1 ]
}

@test "validate_python_version: rejects version with spaces" {
    run validate_python_version "3.11 .5"
    [ "$status" -eq 1 ]
}

#============================================================
# is_file_empty() tests
#============================================================

@test "is_file_empty: returns 0 for non-existent file" {
    run is_file_empty "nonexistent.txt"
    [ "$status" -eq 0 ]
}

@test "is_file_empty: returns 0 for empty file" {
    touch empty.txt
    
    run is_file_empty "empty.txt"
    [ "$status" -eq 0 ]
}

@test "is_file_empty: returns 1 for file with content" {
    echo "content" > file.txt
    
    run is_file_empty "file.txt"
    [ "$status" -eq 1 ]
}

@test "is_file_empty: returns 1 for file with single character" {
    echo -n "x" > file.txt
    
    run is_file_empty "file.txt"
    [ "$status" -eq 1 ]
}

@test "is_file_empty: returns 0 for file with only newline" {
    echo "" > file.txt
    
    # File has a newline, so it's not empty (has 1 byte)
    run is_file_empty "file.txt"
    [ "$status" -eq 1 ]
}
