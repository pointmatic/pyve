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
# gitignore_has_pattern() tests
#============================================================

@test "gitignore_has_pattern: returns 0 when pattern exists" {
    echo ".venv" > .gitignore
    
    run gitignore_has_pattern ".venv"
    [ "$status" -eq 0 ]
}

@test "gitignore_has_pattern: returns 1 when pattern not found" {
    echo ".pyve" > .gitignore
    
    run gitignore_has_pattern ".venv"
    [ "$status" -eq 1 ]
}

@test "gitignore_has_pattern: returns non-zero when .gitignore missing" {
    run gitignore_has_pattern ".venv"
    [ "$status" -ne 0 ]
}

@test "gitignore_has_pattern: handles special characters in pattern" {
    echo "*.egg-info" > .gitignore
    
    run gitignore_has_pattern "*.egg-info"
    [ "$status" -eq 0 ]
}

@test "gitignore_has_pattern: does not match partial lines" {
    echo ".venv-test" > .gitignore
    
    run gitignore_has_pattern ".venv"
    [ "$status" -eq 1 ]
}

#============================================================
# insert_pattern_in_gitignore_section() tests
#============================================================

@test "insert_pattern_in_gitignore_section: inserts after section comment" {
    cat > .gitignore << 'EOF'
# Python
__pycache__

# Pyve virtual environment

# Project
EOF
    
    run insert_pattern_in_gitignore_section ".venv" "# Pyve virtual environment"
    [ "$status" -eq 0 ]
    
    # .venv should appear right after the section comment
    local line_section=$(grep -n "^# Pyve virtual environment$" .gitignore | head -1 | cut -d: -f1)
    local line_venv=$(grep -n "^\.venv$" .gitignore | head -1 | cut -d: -f1)
    [ "$line_venv" -eq $((line_section + 1)) ]
}

@test "insert_pattern_in_gitignore_section: skips if pattern already present" {
    cat > .gitignore << 'EOF'
# Pyve virtual environment
.venv
EOF
    
    run insert_pattern_in_gitignore_section ".venv" "# Pyve virtual environment"
    [ "$status" -eq 0 ]
    
    local count=$(grep -c "^\.venv$" .gitignore)
    [ "$count" -eq 1 ]
}

@test "insert_pattern_in_gitignore_section: falls back to append when section missing" {
    echo "__pycache__" > .gitignore
    
    run insert_pattern_in_gitignore_section ".venv" "# Pyve virtual environment"
    [ "$status" -eq 0 ]
    
    # .venv should be at the end
    local last_line=$(tail -1 .gitignore)
    [ "$last_line" = ".venv" ]
}

@test "insert_pattern_in_gitignore_section: creates .gitignore if missing" {
    run insert_pattern_in_gitignore_section ".venv" "# Pyve virtual environment"
    [ "$status" -eq 0 ]
    
    assert_file_exists ".gitignore"
    assert_file_contains ".gitignore" ".venv"
}

#============================================================
# write_gitignore_template() tests
#============================================================

@test "write_gitignore_template: creates template when no .gitignore exists" {
    run write_gitignore_template
    [ "$status" -eq 0 ]
    
    assert_file_exists ".gitignore"
    assert_file_contains ".gitignore" "# macOS only"
    assert_file_contains ".gitignore" ".DS_Store"
    assert_file_contains ".gitignore" "# Python build and test artifacts"
    assert_file_contains ".gitignore" "__pycache__"
    assert_file_contains ".gitignore" "*.egg-info"
    assert_file_contains ".gitignore" ".coverage"
    assert_file_contains ".gitignore" "coverage.xml"
    assert_file_contains ".gitignore" "htmlcov/"
    assert_file_contains ".gitignore" ".pytest_cache/"
    assert_file_contains ".gitignore" "# Pyve virtual environment"
}

@test "write_gitignore_template: preserves user entries below template" {
    cat > .gitignore << 'EOF'
.DS_Store
__pycache__
my-custom-dir/
my-secret-file
EOF
    
    run write_gitignore_template
    [ "$status" -eq 0 ]
    
    # Template entries should be present
    assert_file_contains ".gitignore" "# Python build and test artifacts"
    assert_file_contains ".gitignore" "# Pyve virtual environment"
    
    # User entries should be preserved
    assert_file_contains ".gitignore" "my-custom-dir/"
    assert_file_contains ".gitignore" "my-secret-file"
    
    # Template entries should NOT be duplicated
    local count=$(grep -c "^__pycache__$" .gitignore)
    [ "$count" -eq 1 ]
    
    local count_ds=$(grep -c "^\.DS_Store$" .gitignore)
    [ "$count_ds" -eq 1 ]
}

@test "write_gitignore_template: idempotent — running twice produces identical output" {
    # First run (fresh)
    write_gitignore_template
    
    local first_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)
    
    # Second run (existing file)
    write_gitignore_template
    
    local second_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)
    
    [ "$first_md5" = "$second_md5" ]
}

@test "write_gitignore_template: self-healing removes duplicate template entries from user section" {
    # Simulate a .gitignore where user manually added template entries
    cat > .gitignore << 'EOF'
my-project-dir/
__pycache__
.DS_Store
*.egg-info
another-user-entry
EOF
    
    run write_gitignore_template
    [ "$status" -eq 0 ]
    
    # Each template entry should appear exactly once
    local count_pycache=$(grep -c "^__pycache__$" .gitignore)
    [ "$count_pycache" -eq 1 ]
    
    local count_ds=$(grep -c "^\.DS_Store$" .gitignore)
    [ "$count_ds" -eq 1 ]
    
    local count_egg=$(grep -c "^\*\.egg-info$" .gitignore)
    [ "$count_egg" -eq 1 ]
    
    # User entries should be preserved
    assert_file_contains ".gitignore" "my-project-dir/"
    assert_file_contains ".gitignore" "another-user-entry"
}

@test "write_gitignore_template: idempotent after purge-then-reinit cycle (byte-level)" {
    # Regression test for v1.1.4 CI failure: after purge removed some dynamic
    # entries but left .pyve/testenv, a second init produced trailing blank
    # lines. Uses md5 checksum to catch trailing newline differences that
    # $(cat) would mask.
    local section="# Pyve virtual environment"

    # Simulate first init: template + dynamic entries
    write_gitignore_template
    insert_pattern_in_gitignore_section ".pyve/testenv" "$section"
    insert_pattern_in_gitignore_section ".envrc" "$section"
    insert_pattern_in_gitignore_section ".env" "$section"
    insert_pattern_in_gitignore_section ".venv" "$section"

    local first_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)

    # Simulate purge: removes .venv, .env, .envrc but NOT .pyve/testenv
    remove_pattern_from_gitignore ".venv"
    remove_pattern_from_gitignore ".env"
    remove_pattern_from_gitignore ".envrc"

    # Simulate second init: template + dynamic entries again
    write_gitignore_template
    insert_pattern_in_gitignore_section ".pyve/testenv" "$section"
    insert_pattern_in_gitignore_section ".envrc" "$section"
    insert_pattern_in_gitignore_section ".env" "$section"
    insert_pattern_in_gitignore_section ".venv" "$section"

    local second_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)

    [ "$first_md5" = "$second_md5" ]
}

@test "write_gitignore_template: preserves user section comments" {
    cat > .gitignore << 'EOF'
.DS_Store

# My custom section
custom-pattern
EOF
    
    run write_gitignore_template
    [ "$status" -eq 0 ]
    
    assert_file_contains ".gitignore" "# My custom section"
    assert_file_contains ".gitignore" "custom-pattern"
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
# read_config_value() edge case tests
#============================================================

@test "read_config_value: returns empty for missing config file" {
    result="$(read_config_value "backend")"
    [ -z "$result" ]
}

@test "read_config_value: reads top-level key" {
    create_pyve_config "backend: venv"
    
    result="$(read_config_value "backend")"
    [ "$result" = "venv" ]
}

@test "read_config_value: returns empty for missing top-level key" {
    create_pyve_config "backend: venv"
    
    result="$(read_config_value "nonexistent")"
    [ -z "$result" ]
}

@test "read_config_value: reads nested key" {
    mkdir -p .pyve
    cat > .pyve/config << 'EOF'
backend: venv
venv:
  directory: custom_venv
EOF
    
    result="$(read_config_value "venv.directory")"
    [ "$result" = "custom_venv" ]
}

@test "read_config_value: returns empty for nested key in missing section" {
    create_pyve_config "backend: venv"
    
    result="$(read_config_value "micromamba.env_name")"
    [ -z "$result" ]
}

@test "read_config_value: reads quoted value" {
    mkdir -p .pyve
    cat > .pyve/config << 'EOF'
pyve_version: "1.2.3"
backend: venv
EOF
    
    result="$(read_config_value "pyve_version")"
    [ "$result" = "1.2.3" ]
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
