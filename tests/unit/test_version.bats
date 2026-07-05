#!/usr/bin/env bats
# bats file_tags=cli

#============================================================
# Unit Tests for Version Tracking Functions
#
# Tests for lib/version.sh functions including version
# comparison, validation, and structure checks.
#============================================================

setup() {
    # Set PYVE_ROOT first
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    
    # Load test helpers
    load '../helpers/test_helper'
    
    # Source the version library (compare_versions).
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/version.sh"
    
    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    
    # Set test version
    VERSION="0.8.8"
}

teardown() {
    # Clean up test directory
    cd /
    rm -rf "$TEST_DIR"
}

#------------------------------------------------------------
# Version Comparison Tests
#------------------------------------------------------------

@test "compare_versions: equal versions" {
    result="$(compare_versions "0.8.8" "0.8.8")"
    [ "$result" = "equal" ]
}

@test "compare_versions: first version greater" {
    result="$(compare_versions "0.8.9" "0.8.8")"
    [ "$result" = "greater" ]
}

@test "compare_versions: first version less" {
    result="$(compare_versions "0.8.7" "0.8.8")"
    [ "$result" = "less" ]
}

@test "compare_versions: major version difference" {
    result="$(compare_versions "1.0.0" "0.8.8")"
    [ "$result" = "greater" ]
}

@test "compare_versions: minor version difference" {
    result="$(compare_versions "0.9.0" "0.8.8")"
    [ "$result" = "greater" ]
}

@test "compare_versions: patch version difference" {
    result="$(compare_versions "0.8.10" "0.8.9")"
    [ "$result" = "greater" ]
}

@test "compare_versions: multi-digit versions" {
    result="$(compare_versions "0.10.5" "0.9.20")"
    [ "$result" = "greater" ]
}

@test "compare_versions: different length versions" {
    result="$(compare_versions "0.8" "0.8.0")"
    [ "$result" = "equal" ]
}

@test "compare_versions: zero components" {
    result="$(compare_versions "0.0.0" "0.0.1")"
    [ "$result" = "less" ]
}

@test "compare_versions: single-component versions" {
    result="$(compare_versions "1" "2")"
    [ "$result" = "less" ]
}

@test "compare_versions: single vs triple component equal" {
    result="$(compare_versions "1" "1.0.0")"
    [ "$result" = "equal" ]
}
