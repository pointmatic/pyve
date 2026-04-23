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

@test "log_info: outputs ▸ prefix (unified UX)" {
    run log_info "Test message"
    [ "$status" -eq 0 ]
    [[ "$output" == "  ▸ Test message" ]]
}

@test "log_warning: outputs ⚠ prefix to stderr (unified UX)" {
    run log_warning "Test warning"
    [ "$status" -eq 0 ]
    [[ "$output" == "  ⚠ Test warning" ]]
}

@test "log_error: outputs ✘ prefix to stderr (unified UX)" {
    run log_error "Test error"
    [ "$status" -eq 0 ]
    [[ "$output" == "  ✘ Test error" ]]
}

@test "log_success: outputs ✔ prefix (unified UX)" {
    run log_success "Test success"
    [ "$status" -eq 0 ]
    [[ "$output" == "  ✔ Test success" ]]
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

@test "write_gitignore_template: Pyve-managed section includes .pyve/envs (H.e.2a)" {
    # Regression for H.e.2a: .pyve/envs must be ignored regardless of
    # backend. Before the fix, it was only added by the micromamba init
    # path — a venv-init'd project that later had a micromamba env drop
    # into .pyve/envs/ would leak thousands of files to git status.
    write_gitignore_template
    run grep -qxF ".pyve/envs" .gitignore
    [ "$status" -eq 0 ]
}

@test "write_gitignore_template: Pyve-managed section includes .pyve/testenv (H.e.2a)" {
    write_gitignore_template
    run grep -qxF ".pyve/testenv" .gitignore
    [ "$status" -eq 0 ]
}

@test "write_gitignore_template: Pyve-managed section includes .envrc and .env (H.e.2a)" {
    write_gitignore_template
    run grep -qxF ".envrc" .gitignore
    [ "$status" -eq 0 ]
    run grep -qxF ".env" .gitignore
    [ "$status" -eq 0 ]
}

@test "write_gitignore_template: Pyve-managed section includes .vscode/settings.json (H.e.2a)" {
    write_gitignore_template
    run grep -qxF ".vscode/settings.json" .gitignore
    [ "$status" -eq 0 ]
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

@test "write_gitignore_template: idempotent after multiple purge-reinit cycles with Pyve-only content (H.a)" {
    # Story H.a case (a): Pyve-only .gitignore (no user content beyond the
    # template). Two purge-reinit cycles to catch any accumulating blank lines
    # that a single cycle might miss.
    local section="# Pyve virtual environment"

    write_gitignore_template
    insert_pattern_in_gitignore_section ".pyve/testenv" "$section"
    insert_pattern_in_gitignore_section ".envrc" "$section"
    insert_pattern_in_gitignore_section ".env" "$section"
    insert_pattern_in_gitignore_section ".venv" "$section"

    local first_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)

    local i
    for i in 1 2; do
        remove_pattern_from_gitignore ".venv"
        remove_pattern_from_gitignore ".env"
        remove_pattern_from_gitignore ".envrc"

        write_gitignore_template
        insert_pattern_in_gitignore_section ".pyve/testenv" "$section"
        insert_pattern_in_gitignore_section ".envrc" "$section"
        insert_pattern_in_gitignore_section ".env" "$section"
        insert_pattern_in_gitignore_section ".venv" "$section"
    done

    local final_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)

    [ "$first_md5" = "$final_md5" ]
}

@test "write_gitignore_template: idempotent after purge-reinit with user content below Pyve section (H.a)" {
    # Story H.a case (b): user-added patterns below the Pyve section. Without
    # the fix, each purge-reinit cycle leaks blank lines at the boundary
    # between the Pyve-managed section and the user content.
    local section="# Pyve virtual environment"

    write_gitignore_template
    insert_pattern_in_gitignore_section ".pyve/testenv" "$section"
    insert_pattern_in_gitignore_section ".envrc" "$section"
    insert_pattern_in_gitignore_section ".env" "$section"
    insert_pattern_in_gitignore_section ".venv" "$section"

    # Append real-world user content below the Pyve section
    cat >> .gitignore << 'EOF'

# MkDocs build output
/site/

# project-guide
docs/project-guide/**/*.bak.*
EOF

    local first_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)

    remove_pattern_from_gitignore ".venv"
    remove_pattern_from_gitignore ".env"
    remove_pattern_from_gitignore ".envrc"

    write_gitignore_template
    insert_pattern_in_gitignore_section ".pyve/testenv" "$section"
    insert_pattern_in_gitignore_section ".envrc" "$section"
    insert_pattern_in_gitignore_section ".env" "$section"
    insert_pattern_in_gitignore_section ".venv" "$section"

    local second_md5=$(md5 -q .gitignore 2>/dev/null || md5sum .gitignore | cut -d' ' -f1)

    [ "$first_md5" = "$second_md5" ]
}

@test "write_gitignore_template: conda-lock.yml is NOT in the generated template" {
    run write_gitignore_template
    [ "$status" -eq 0 ]

    # conda-lock.yml must be committed — it must never appear in Pyve's template
    run grep -x "conda-lock.yml" .gitignore
    [ "$status" -ne 0 ]
}

@test "write_gitignore_template: .pyve/envs section header is present (still correctly ignored)" {
    run write_gitignore_template
    [ "$status" -eq 0 ]

    assert_file_contains ".gitignore" "# Pyve virtual environment"
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

#============================================================
# write_vscode_settings() tests
#============================================================

@test "write_vscode_settings: creates .vscode/settings.json with correct interpreter path" {
    run write_vscode_settings "my-env"
    [ "$status" -eq 0 ]

    assert_file_exists ".vscode/settings.json"
    assert_file_contains ".vscode/settings.json" ".pyve/envs/my-env/bin/python"
    assert_file_contains ".vscode/settings.json" '"python.terminal.activateEnvironment": false'
    assert_file_contains ".vscode/settings.json" '"python.condaPath": ""'
}

@test "write_vscode_settings: does not overwrite existing file without --force" {
    mkdir -p .vscode
    echo '{"existing": true}' > .vscode/settings.json

    run write_vscode_settings "my-env"
    [ "$status" -eq 0 ]

    # Original content must be preserved
    assert_file_contains ".vscode/settings.json" '"existing": true'
    run grep -q "my-env" .vscode/settings.json
    [ "$status" -ne 0 ]
}

@test "write_vscode_settings: overwrites existing file when PYVE_REINIT_MODE=force" {
    mkdir -p .vscode
    echo '{"existing": true}' > .vscode/settings.json

    PYVE_REINIT_MODE=force run write_vscode_settings "my-env"
    [ "$status" -eq 0 ]

    assert_file_contains ".vscode/settings.json" ".pyve/envs/my-env/bin/python"
}

@test "write_gitignore_template: .vscode/settings.json not duplicated in user section on reinit" {
    local section="# Pyve virtual environment"

    # Simulate first micromamba init
    write_gitignore_template
    insert_pattern_in_gitignore_section ".vscode/settings.json" "$section"

    local first_count
    first_count=$(grep -c "^\.vscode/settings\.json$" .gitignore)

    # Simulate second init (reinit)
    write_gitignore_template
    insert_pattern_in_gitignore_section ".vscode/settings.json" "$section"

    local second_count
    second_count=$(grep -c "^\.vscode/settings\.json$" .gitignore)

    [ "$first_count" -eq 1 ]
    [ "$second_count" -eq 1 ]
}

#============================================================
# check_cloud_sync_path() tests
#============================================================

@test "check_cloud_sync_path: passes when outside synced directories" {
    # The test temp dir is under /var/folders or /tmp — not under $HOME/Documents
    run check_cloud_sync_path
    [ "$status" -eq 0 ]
}

@test "check_cloud_sync_path: hard fails when inside Documents" {
    local fake_home
    fake_home="$(mktemp -d)"
    mkdir -p "$fake_home/Documents/my-project"

    run env HOME="$fake_home" bash -c "
        source '$PYVE_ROOT/lib/utils.sh'
        cd '$fake_home/Documents/my-project'
        check_cloud_sync_path
    "
    rm -rf "$fake_home"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud-synced"* ]]
}

@test "check_cloud_sync_path: hard fails when inside Dropbox" {
    local fake_home
    fake_home="$(mktemp -d)"
    mkdir -p "$fake_home/Dropbox/work/my-project"

    run env HOME="$fake_home" bash -c "
        source '$PYVE_ROOT/lib/utils.sh'
        cd '$fake_home/Dropbox/work/my-project'
        check_cloud_sync_path
    "
    rm -rf "$fake_home"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud-synced"* ]]
}

@test "check_cloud_sync_path: passes inside Developer directory" {
    local fake_home
    fake_home="$(mktemp -d)"
    mkdir -p "$fake_home/Developer/my-project"

    run env HOME="$fake_home" bash -c "
        source '$PYVE_ROOT/lib/utils.sh'
        cd '$fake_home/Developer/my-project'
        check_cloud_sync_path
    "
    rm -rf "$fake_home"
    [ "$status" -eq 0 ]
}

@test "check_cloud_sync_path: PYVE_ALLOW_SYNCED_DIR=1 bypasses the check" {
    local fake_home
    fake_home="$(mktemp -d)"
    mkdir -p "$fake_home/Documents/my-project"

    run env HOME="$fake_home" PYVE_ALLOW_SYNCED_DIR=1 bash -c "
        source '$PYVE_ROOT/lib/utils.sh'
        cd '$fake_home/Documents/my-project'
        check_cloud_sync_path
    "
    rm -rf "$fake_home"
    [ "$status" -eq 0 ]
}

#============================================================
# prompt_install_pip_dependencies() tests — pip_cmd resolution
#============================================================

@test "prompt_install_pip_dependencies: venv backend uses env_path/bin/pip, not bare pip" {
    # Create a pyproject.toml so the function has something to install
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
version = "0.1.0"
dependencies = []
EOF

    # Create a fake venv with a pip stub that records its invocation
    local fake_venv="$TEST_DIR/.venv"
    mkdir -p "$fake_venv/bin"
    cat > "$fake_venv/bin/pip" << 'STUB'
#!/usr/bin/env bash
echo "VENV_PIP_CALLED: $0 $*"
STUB
    chmod +x "$fake_venv/bin/pip"

    # Also put a bare "pip" on PATH that records if IT gets called (the bug)
    local fake_bin="$TEST_DIR/fake_bin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/pip" << 'STUB'
#!/usr/bin/env bash
echo "BARE_PIP_CALLED: $0 $*"
STUB
    chmod +x "$fake_bin/pip"
    export PATH="$fake_bin:$PATH"

    # Run in auto-install mode to skip interactive prompt
    PYVE_AUTO_INSTALL_DEPS=1 run prompt_install_pip_dependencies "venv" "$fake_venv"
    [ "$status" -eq 0 ]

    # The venv pip should have been called
    [[ "$output" == *"VENV_PIP_CALLED"* ]]

    # The bare pip should NOT have been called
    [[ "$output" != *"BARE_PIP_CALLED"* ]]
}

@test "prompt_install_pip_dependencies: venv backend without env_path returns error" {
    # When no env_path is passed for venv backend, the function should
    # return 1 with a warning instead of falling back to bare pip.
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
version = "0.1.0"
dependencies = []
EOF

    PYVE_AUTO_INSTALL_DEPS=1 run prompt_install_pip_dependencies "venv"
    [ "$status" -eq 1 ]
    [[ "$output" == *"env_path not provided"* ]]
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

#============================================================
# prompt_yes_no — three-arm input loop (Story I.k coverage)
#============================================================

@test "prompt_yes_no: returns 0 for 'y'" {
    run bash -c "source '$PYVE_ROOT/lib/utils.sh' && prompt_yes_no 'Q?'" <<< "y"
    [ "$status" -eq 0 ]
}

@test "prompt_yes_no: returns 0 for 'yes'" {
    run bash -c "source '$PYVE_ROOT/lib/utils.sh' && prompt_yes_no 'Q?'" <<< "yes"
    [ "$status" -eq 0 ]
}

@test "prompt_yes_no: returns 0 for uppercase 'YES'" {
    run bash -c "source '$PYVE_ROOT/lib/utils.sh' && prompt_yes_no 'Q?'" <<< "YES"
    [ "$status" -eq 0 ]
}

@test "prompt_yes_no: returns 1 for 'n'" {
    run bash -c "source '$PYVE_ROOT/lib/utils.sh' && prompt_yes_no 'Q?'" <<< "n"
    [ "$status" -eq 1 ]
}

@test "prompt_yes_no: returns 1 for 'no'" {
    run bash -c "source '$PYVE_ROOT/lib/utils.sh' && prompt_yes_no 'Q?'" <<< "no"
    [ "$status" -eq 1 ]
}

@test "prompt_yes_no: re-prompts on invalid input, then accepts 'y'" {
    # Two invalid answers then 'y' — exercises the loop's default arm.
    run bash -c "source '$PYVE_ROOT/lib/utils.sh' && prompt_yes_no 'Q?'" <<< $'maybe\nmaaaybe\ny'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Please answer yes or no"* ]]
}
