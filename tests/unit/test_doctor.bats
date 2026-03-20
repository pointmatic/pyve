#!/usr/bin/env bats
#
# Unit tests for detect_install_source() in lib/utils.sh
#

# Load test helpers
load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export TARGET_BIN_DIR="$HOME/.local/bin"
}

teardown() {
    cleanup_test_dir
}

#============================================================
# doctor_check_native_lib_conflicts() tests
#============================================================

_make_conflict_env() {
    # Helper: scaffold a fake env with torch (pip) + numpy (conda) but no OpenMP lib
    local env_path="${1:-env}"
    mkdir -p "$env_path/lib/python3.12/site-packages"
    mkdir -p "$env_path/lib/python3.12/site-packages/torch-2.0.0.dist-info"
    mkdir -p "$env_path/conda-meta"
    touch "$env_path/conda-meta/numpy-1.24.0-py312hab.json"
    # Deliberately do NOT create libomp.dylib or libgomp.so
}

@test "doctor_check_native_lib_conflicts: no conflict when no pip bundlers" {
    mkdir -p env/lib/python3.12/site-packages
    mkdir -p env/conda-meta
    touch "env/conda-meta/numpy-1.24.0-py312.json"

    run doctor_check_native_lib_conflicts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ No conda/pip native library conflicts detected"* ]]
}

@test "doctor_check_native_lib_conflicts: no conflict when no conda linkers" {
    mkdir -p env/lib/python3.12/site-packages
    mkdir -p "env/lib/python3.12/site-packages/torch-2.0.0.dist-info"
    mkdir -p env/conda-meta

    run doctor_check_native_lib_conflicts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ No conda/pip native library conflicts detected"* ]]
}

@test "doctor_check_native_lib_conflicts: detects conflict when pip+conda present and OpenMP missing" {
    _make_conflict_env "env"

    run doctor_check_native_lib_conflicts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠ Potential native library conflict detected"* ]]
    [[ "$output" == *"torch"* ]]
    [[ "$output" == *"numpy"* ]]
    [[ "$output" == *"llvm-openmp"* ]] || [[ "$output" == *"libgomp"* ]]
}

@test "doctor_check_native_lib_conflicts: no conflict when OpenMP lib is present" {
    _make_conflict_env "env"
    if [[ "$(uname)" == "Darwin" ]]; then
        touch "env/lib/libomp.dylib"
    else
        touch "env/lib/libgomp.so.1"
    fi

    run doctor_check_native_lib_conflicts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ No conda/pip native library conflicts detected"* ]]
}

@test "doctor_check_native_lib_conflicts: returns early for missing env path" {
    run doctor_check_native_lib_conflicts "nonexistent-env"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#============================================================
# detect_install_source tests
#============================================================

@test "detect_install_source: returns 'source' when running from repo clone" {
    # SCRIPT_DIR is set to PYVE_ROOT by setup_pyve_env, which is the repo root
    # This should not match TARGET_BIN_DIR or a Homebrew prefix
    export SCRIPT_DIR="$PYVE_ROOT"
    run detect_install_source
    [ "$status" -eq 0 ]
    [ "$output" = "source" ]
}

@test "detect_install_source: returns 'installed' when SCRIPT_DIR matches TARGET_BIN_DIR" {
    export SCRIPT_DIR="$TARGET_BIN_DIR"
    run detect_install_source
    [ "$status" -eq 0 ]
    [ "$output" = "installed" ]
}

@test "detect_install_source: returns 'homebrew' when SCRIPT_DIR is under brew prefix" {
    # Mock brew to return a known prefix
    brew() {
        case "$1" in
            --prefix) echo "/opt/homebrew" ;;
        esac
    }
    export -f brew
    export SCRIPT_DIR="/opt/homebrew/Cellar/pyve/1.5.0/libexec"

    run detect_install_source
    [ "$status" -eq 0 ]
    [ "$output" = "homebrew" ]

    unset -f brew
}

@test "detect_install_source: returns 'source' when brew exists but SCRIPT_DIR is not under prefix" {
    # Mock brew to return a known prefix
    brew() {
        case "$1" in
            --prefix) echo "/opt/homebrew" ;;
        esac
    }
    export -f brew
    export SCRIPT_DIR="/Users/someone/projects/pyve"

    run detect_install_source
    [ "$status" -eq 0 ]
    [ "$output" = "source" ]

    unset -f brew
}

#============================================================
# doctor_check_duplicate_dist_info() tests
#============================================================

@test "doctor_check_duplicate_dist_info: passes for clean environment" {
    mkdir -p env/lib/python3.12/site-packages
    mkdir -p "env/lib/python3.12/site-packages/numpy-1.24.0.dist-info"
    mkdir -p "env/lib/python3.12/site-packages/pandas-2.0.0.dist-info"

    run doctor_check_duplicate_dist_info "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ No duplicate dist-info directories"* ]]
}

@test "doctor_check_duplicate_dist_info: detects duplicate dist-info dirs" {
    mkdir -p env/lib/python3.12/site-packages
    mkdir -p "env/lib/python3.12/site-packages/numpy-1.24.0.dist-info"
    mkdir -p "env/lib/python3.12/site-packages/numpy-1.25.0.dist-info"
    mkdir -p "env/lib/python3.12/site-packages/pandas-2.0.0.dist-info"

    run doctor_check_duplicate_dist_info "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✗ Duplicate dist-info detected: numpy"* ]]
    [[ "$output" == *"numpy-1.24.0.dist-info"* ]]
    [[ "$output" == *"numpy-1.25.0.dist-info"* ]]
    [[ "$output" == *"pyve --init --force"* ]]
}

@test "doctor_check_duplicate_dist_info: passes for missing site-packages" {
    mkdir -p env/lib

    run doctor_check_duplicate_dist_info "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ No duplicate dist-info directories"* ]]
}

#============================================================
# doctor_check_collision_artifacts() tests
#============================================================

@test "doctor_check_collision_artifacts: passes for clean environment" {
    mkdir -p env/lib/python3.12

    run doctor_check_collision_artifacts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ No cloud sync collision artifacts"* ]]
}

@test "doctor_check_collision_artifacts: detects files with ' 2' suffix" {
    mkdir -p "env/lib/python3.12/__pycache__ 2"

    run doctor_check_collision_artifacts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✗ Cloud sync collision artifacts detected"* ]]
    [[ "$output" == *"__pycache__ 2"* ]]
}

@test "doctor_check_collision_artifacts: detects nested collision artifacts" {
    mkdir -p env/lib/python3.12/zipfile
    mkdir -p "env/lib/python3.12/zipfile/__pycache__ 2"
    touch "env/lib/python3.12/zipfile/_path 2"

    run doctor_check_collision_artifacts "env"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✗ Cloud sync collision artifacts detected (2 found)"* ]]
}

@test "doctor_check_collision_artifacts: returns early for missing env path" {
    run doctor_check_collision_artifacts "nonexistent-env"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#============================================================
# detect_install_source tests
#============================================================

@test "detect_install_source: homebrew takes priority over installed" {
    # Edge case: SCRIPT_DIR matches both brew prefix and TARGET_BIN_DIR
    brew() {
        case "$1" in
            --prefix) echo "/opt/homebrew" ;;
        esac
    }
    export -f brew
    export SCRIPT_DIR="/opt/homebrew/Cellar/pyve/1.5.0/libexec"
    export TARGET_BIN_DIR="/opt/homebrew/Cellar/pyve/1.5.0/libexec"

    run detect_install_source
    [ "$status" -eq 0 ]
    [ "$output" = "homebrew" ]

    unset -f brew
}
