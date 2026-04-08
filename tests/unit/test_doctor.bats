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

#============================================================
# doctor_check_venv_path() tests
#============================================================

_make_fake_venv() {
    # Helper: scaffold a minimal venv with pyvenv.cfg (Python 3.11+ style with command line)
    local env_path="$1"
    local creation_path="$2"
    mkdir -p "$env_path/bin"
    touch "$env_path/bin/python"
    cat > "$env_path/pyvenv.cfg" <<EOF
home = /usr/bin
include-system-site-packages = false
version = 3.12.0
executable = /usr/bin/python3.12
command = /usr/bin/python -m venv $creation_path
EOF
    # Also write an activate script with VIRTUAL_ENV
    cat > "$env_path/bin/activate" <<EOF
export VIRTUAL_ENV="$creation_path"
EOF
}

_make_fake_venv_no_command() {
    # Helper: scaffold a venv without command line (Python 3.10 style)
    local env_path="$1"
    local virtual_env_path="$2"
    mkdir -p "$env_path/bin"
    touch "$env_path/bin/python"
    cat > "$env_path/pyvenv.cfg" <<EOF
home = /usr/bin
include-system-site-packages = false
version = 3.10.11
EOF
    cat > "$env_path/bin/activate" <<EOF
export VIRTUAL_ENV="$virtual_env_path"
EOF
}

@test "doctor_check_venv_path: no warning when path matches" {
    local venv_path="$TEST_DIR/.venv"
    _make_fake_venv "$venv_path" "$venv_path"

    run doctor_check_venv_path "$venv_path"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "doctor_check_venv_path: warns when path mismatches (relocated project)" {
    local venv_path="$TEST_DIR/.venv"
    _make_fake_venv "$venv_path" "/Users/someone/old-location/project/.venv"

    run doctor_check_venv_path "$venv_path"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠ Environment: venv path mismatch"* ]]
    [[ "$output" == *"relocated"* ]]
    [[ "$output" == *"/Users/someone/old-location/project/.venv"* ]]
    [[ "$output" == *"pyve --init --force"* ]]
}

@test "doctor_check_venv_path: no warning when pyvenv.cfg missing" {
    mkdir -p "$TEST_DIR/.venv/bin"

    run doctor_check_venv_path "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "doctor_check_venv_path: no warning when no command line and no activate script" {
    mkdir -p "$TEST_DIR/.venv/bin"
    cat > "$TEST_DIR/.venv/pyvenv.cfg" <<EOF
home = /usr/bin
version = 3.10.11
EOF

    run doctor_check_venv_path "$TEST_DIR/.venv"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "doctor_check_venv_path: falls back to activate script when no command line (Python 3.10)" {
    local venv_path="$TEST_DIR/.venv"
    _make_fake_venv_no_command "$venv_path" "/Users/someone/old-location/.venv"

    run doctor_check_venv_path "$venv_path"
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠ Environment: venv path mismatch"* ]]
    [[ "$output" == *"/Users/someone/old-location/.venv"* ]]
}

@test "doctor_check_venv_path: no warning via activate script when path matches" {
    local venv_path="$TEST_DIR/.venv"
    _make_fake_venv_no_command "$venv_path" "$venv_path"

    run doctor_check_venv_path "$venv_path"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#============================================================
# detect_install_source: edge case tests
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
