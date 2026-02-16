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
