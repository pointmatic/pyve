#!/usr/bin/env bats
#
# Unit tests for lib/micromamba_env.sh - Lock file validation functions
# Tests is_lock_file_stale(), get_file_mtime_formatted(), and validate_lock_file_status()
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
# is_lock_file_stale() tests
#============================================================

@test "is_lock_file_stale: returns 1 when environment.yml doesn't exist" {
    touch conda-lock.yml
    
    run is_lock_file_stale
    [ "$status" -eq 1 ]
}

@test "is_lock_file_stale: returns 1 when conda-lock.yml doesn't exist" {
    touch environment.yml
    
    run is_lock_file_stale
    [ "$status" -eq 1 ]
}

@test "is_lock_file_stale: returns 1 when neither file exists" {
    run is_lock_file_stale
    [ "$status" -eq 1 ]
}

@test "is_lock_file_stale: returns 0 when environment.yml is newer" {
    # Create lock file with older timestamp
    touch -t 202401010000 conda-lock.yml
    # Create environment.yml with newer timestamp
    touch -t 202401010001 environment.yml
    
    run is_lock_file_stale
    [ "$status" -eq 0 ]
}

@test "is_lock_file_stale: returns 1 when conda-lock.yml is newer" {
    # Create environment.yml with older timestamp
    touch -t 202401010000 environment.yml
    # Create lock file with newer timestamp
    touch -t 202401010001 conda-lock.yml
    
    run is_lock_file_stale
    [ "$status" -eq 1 ]
}

@test "is_lock_file_stale: returns 1 when files have same mtime" {
    # Create both files at same time
    touch environment.yml conda-lock.yml
    
    run is_lock_file_stale
    [ "$status" -eq 1 ]
}

#============================================================
# get_file_mtime_formatted() tests
#============================================================

@test "get_file_mtime_formatted: returns formatted date for existing file" {
    touch test_file.txt
    
    run get_file_mtime_formatted "test_file.txt"
    [ "$status" -eq 0 ]
    # Output should contain date-like format (YYYY-MM-DD or similar)
    [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "get_file_mtime_formatted: returns 'unknown' for non-existent file" {
    run get_file_mtime_formatted "nonexistent.txt"
    [ "$status" -eq 1 ]
    [ "$output" = "unknown" ]
}

@test "get_file_mtime_formatted: handles environment.yml" {
    create_environment_yml "test-env" "python=3.11"
    
    run get_file_mtime_formatted "environment.yml"
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "get_file_mtime_formatted: handles conda-lock.yml" {
    touch conda-lock.yml
    
    run get_file_mtime_formatted "conda-lock.yml"
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

#============================================================
# is_interactive() tests
#============================================================

@test "is_interactive: returns 1 in non-interactive mode (bats)" {
    # Bats runs tests in non-interactive mode
    run is_interactive
    [ "$status" -eq 1 ]
}

#============================================================
# validate_lock_file_status() tests - non-strict mode
#============================================================

@test "validate_lock_file_status: returns 0 when both files exist and lock is fresh" {
    # Create environment.yml with older timestamp
    touch -t 202401010000 environment.yml
    # Create lock file with newer timestamp
    touch -t 202401010001 conda-lock.yml
    
    run validate_lock_file_status "false"
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: returns 0 when both files exist and lock is stale (non-interactive)" {
    # Create lock file with older timestamp
    touch -t 202401010000 conda-lock.yml
    # Create environment.yml with newer timestamp (stale lock)
    touch -t 202401010001 environment.yml
    
    # In non-interactive mode, should continue despite stale lock
    run validate_lock_file_status "false"
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: returns 0 when only environment.yml exists (non-interactive)" {
    create_environment_yml "test-env" "python=3.11"
    
    # In non-interactive mode, should continue without lock file
    run validate_lock_file_status "false"
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: returns 1 when only conda-lock.yml exists" {
    touch conda-lock.yml
    
    # Missing environment.yml is an error
    run validate_lock_file_status "false"
    [ "$status" -eq 1 ]
}

@test "validate_lock_file_status: returns 1 when neither file exists" {
    run validate_lock_file_status "false"
    [ "$status" -eq 1 ]
}

#============================================================
# validate_lock_file_status() tests - strict mode
#============================================================

@test "validate_lock_file_status: strict mode returns 0 when lock is fresh" {
    # Create environment.yml with older timestamp
    touch -t 202401010000 environment.yml
    # Create lock file with newer timestamp
    touch -t 202401010001 conda-lock.yml
    
    run validate_lock_file_status "true"
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: strict mode returns 1 when lock is stale" {
    # Create lock file with older timestamp
    touch -t 202401010000 conda-lock.yml
    # Create environment.yml with newer timestamp (stale lock)
    touch -t 202401010001 environment.yml
    
    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
}

@test "validate_lock_file_status: strict mode returns 1 when lock file missing" {
    create_environment_yml "test-env" "python=3.11"
    
    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
}

@test "validate_lock_file_status: strict mode returns 1 when environment.yml missing" {
    touch conda-lock.yml
    
    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
}

@test "validate_lock_file_status: strict mode returns 1 when both files missing" {
    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
}

#============================================================
# Edge cases
#============================================================

@test "is_lock_file_stale: handles files with same timestamp correctly" {
    # Touch both files simultaneously
    touch -t 202401010000 environment.yml conda-lock.yml
    
    run is_lock_file_stale
    # Should return 1 (not stale) when timestamps are equal
    [ "$status" -eq 1 ]
}

@test "validate_lock_file_status: defaults to non-strict when no argument" {
    create_environment_yml "test-env" "python=3.11"
    
    # No lock file, non-strict mode (default), non-interactive
    run validate_lock_file_status
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: handles empty string as non-strict" {
    create_environment_yml "test-env" "python=3.11"
    
    run validate_lock_file_status ""
    [ "$status" -eq 0 ]
}
