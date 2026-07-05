#!/usr/bin/env bats
# bats file_tags=core
#
# Unit tests for lib/backend_detect.sh
# Tests backend detection logic and priority resolution
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
# detect_backend_from_files() tests
#============================================================

@test "detect_backend_from_files: returns 'micromamba' for environment.yml" {
    create_environment_yml "test-env" "python=3.11"
    
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "detect_backend_from_files: returns 'micromamba' for conda-lock.yml" {
    touch conda-lock.yml
    
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "detect_backend_from_files: returns 'venv' for requirements.txt" {
    create_requirements_txt "requests==2.31.0"
    
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "detect_backend_from_files: returns 'venv' for pyproject.toml" {
    create_pyproject_toml
    
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "detect_backend_from_files: returns 'ambiguous' for both conda and python files" {
    create_environment_yml "test-env" "python=3.11"
    create_requirements_txt "requests==2.31.0"
    
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "ambiguous" ]
}

@test "detect_backend_from_files: returns 'none' for no files" {
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

@test "detect_backend_from_files: prefers micromamba when both environment.yml and pyproject.toml exist" {
    create_environment_yml "test-env" "python=3.11"
    create_pyproject_toml
    
    run detect_backend_from_files
    [ "$status" -eq 0 ]
    [ "$output" = "ambiguous" ]
}

#============================================================
# get_backend_priority() tests
#============================================================

@test "get_backend_priority: CLI flag 'venv' takes priority" {
    create_pyve_config "backend: micromamba"
    create_environment_yml "test-env" "python=3.11"
    
    run get_backend_priority "venv"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "get_backend_priority: CLI flag 'micromamba' takes priority" {
    create_pyve_config "backend: venv"
    create_requirements_txt "requests==2.31.0"
    
    run get_backend_priority "micromamba"
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "get_backend_priority: a stale .pyve/config no longer overrides file detection" {
    # Priority-2 (.pyve/config) was removed: the manifest reaches this resolver
    # as the CLI flag, so with no flag it arbitrates file detection only.
    create_pyve_config "backend: micromamba"
    create_requirements_txt "requests==2.31.0"

    run get_backend_priority ""
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "get_backend_priority: file detection works when no CLI or config" {
    create_environment_yml "test-env" "python=3.11"
    
    run get_backend_priority ""
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "get_backend_priority: defaults to 'venv' when no files" {
    run get_backend_priority ""
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "get_backend_priority: 'auto' flag defers to file detection" {
    # 'auto' is not a concrete flag, so it falls through to file detection; a
    # stale .pyve/config is no longer consulted. No files → venv default.
    create_pyve_config "backend: micromamba"

    run get_backend_priority "auto"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "get_backend_priority: defaults to 'micromamba' for ambiguous file detection in CI mode" {
    create_environment_yml "test-env" "python=3.11"
    create_requirements_txt "requests==2.31.0"
    
    # Set CI mode to trigger non-interactive behavior
    export CI=1
    
    run get_backend_priority ""
    [ "$status" -eq 0 ]
    # Check last line of output
    local last_line=$(echo "$output" | tail -n 1)
    [ "$last_line" = "micromamba" ]
    
    unset CI
}

#============================================================
# validate_backend() tests
#============================================================

@test "validate_backend: accepts 'venv'" {
    run validate_backend "venv"
    [ "$status" -eq 0 ]
}

@test "validate_backend: accepts 'micromamba'" {
    run validate_backend "micromamba"
    [ "$status" -eq 0 ]
}

@test "validate_backend: accepts 'auto'" {
    run validate_backend "auto"
    [ "$status" -eq 0 ]
}

@test "validate_backend: rejects invalid backend" {
    run validate_backend "invalid"
    [ "$status" -eq 1 ]
}

@test "validate_backend: rejects empty string" {
    run validate_backend ""
    [ "$status" -eq 1 ]
}

