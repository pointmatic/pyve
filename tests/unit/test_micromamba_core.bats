#!/usr/bin/env bats
#
# Unit tests for lib/micromamba_core.sh
# Tests micromamba binary detection, version checking, and location detection
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
# get_micromamba_path() tests
#============================================================

@test "get_micromamba_path: returns project sandbox path when exists" {
    mkdir -p .pyve/bin
    touch .pyve/bin/micromamba
    chmod +x .pyve/bin/micromamba
    
    run get_micromamba_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.pyve/bin/micromamba" ]]
}

@test "get_micromamba_path: returns user sandbox path when project doesn't exist" {
    mkdir -p "$HOME/.pyve/bin"
    touch "$HOME/.pyve/bin/micromamba"
    chmod +x "$HOME/.pyve/bin/micromamba"
    
    run get_micromamba_path
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.pyve/bin/micromamba" ]
    
    # Cleanup
    rm -f "$HOME/.pyve/bin/micromamba"
}

@test "get_micromamba_path: returns system path when sandboxes don't exist" {
    # Mock which command to return a fake path
    mock_command "which" 0 "/usr/local/bin/micromamba"
    
    # Create fake system micromamba
    mkdir -p /tmp/fake_bin
    touch /tmp/fake_bin/micromamba
    chmod +x /tmp/fake_bin/micromamba
    
    # Override which to return our fake path
    which() {
        if [[ "$1" == "micromamba" ]]; then
            echo "/tmp/fake_bin/micromamba"
            return 0
        fi
        command which "$@"
    }
    
    run get_micromamba_path
    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/fake_bin/micromamba" ]
    
    # Cleanup
    unset -f which
    rm -rf /tmp/fake_bin
}

@test "get_micromamba_path: returns empty when not found" {
    # Mock which to return nothing
    which() {
        if [[ "$1" == "micromamba" ]]; then
            return 1
        fi
        command which "$@"
    }
    
    run get_micromamba_path
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
    
    unset -f which
}

@test "get_micromamba_path: project sandbox takes priority over user sandbox" {
    mkdir -p .pyve/bin
    touch .pyve/bin/micromamba
    chmod +x .pyve/bin/micromamba
    
    mkdir -p "$HOME/.pyve/bin"
    touch "$HOME/.pyve/bin/micromamba"
    chmod +x "$HOME/.pyve/bin/micromamba"
    
    run get_micromamba_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.pyve/bin/micromamba" ]]
    [[ "$output" != "$HOME/.pyve/bin/micromamba" ]]
    
    # Cleanup
    rm -f "$HOME/.pyve/bin/micromamba"
}

#============================================================
# check_micromamba_available() tests
#============================================================

@test "check_micromamba_available: returns 0 when micromamba exists" {
    mkdir -p .pyve/bin
    touch .pyve/bin/micromamba
    chmod +x .pyve/bin/micromamba
    
    run check_micromamba_available
    [ "$status" -eq 0 ]
}

@test "check_micromamba_available: returns 1 when micromamba doesn't exist" {
    which() {
        if [[ "$1" == "micromamba" ]]; then
            return 1
        fi
        command which "$@"
    }
    
    run check_micromamba_available
    [ "$status" -eq 1 ]
    
    unset -f which
}

#============================================================
# get_micromamba_version() tests
#============================================================

@test "get_micromamba_version: extracts version from 'micromamba X.Y.Z' format" {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "micromamba 1.5.3"
fi
EOF
    chmod +x .pyve/bin/micromamba
    
    run get_micromamba_version
    [ "$status" -eq 0 ]
    [ "$output" = "1.5.3" ]
}

@test "get_micromamba_version: extracts version from 'X.Y.Z' format" {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "1.5.3"
fi
EOF
    chmod +x .pyve/bin/micromamba
    
    run get_micromamba_version
    [ "$status" -eq 0 ]
    [ "$output" = "1.5.3" ]
}

@test "get_micromamba_version: returns empty when micromamba not found" {
    which() {
        if [[ "$1" == "micromamba" ]]; then
            return 1
        fi
        command which "$@"
    }
    
    run get_micromamba_version
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
    
    unset -f which
}

@test "get_micromamba_version: returns empty when version command fails" {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x .pyve/bin/micromamba
    
    run get_micromamba_version
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
}

#============================================================
# get_micromamba_location() tests
#============================================================

@test "get_micromamba_location: returns 'project' for project sandbox" {
    mkdir -p .pyve/bin
    touch .pyve/bin/micromamba
    chmod +x .pyve/bin/micromamba
    
    run get_micromamba_location
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}

@test "get_micromamba_location: returns 'user' for user sandbox" {
    mkdir -p "$HOME/.pyve/bin"
    touch "$HOME/.pyve/bin/micromamba"
    chmod +x "$HOME/.pyve/bin/micromamba"
    
    run get_micromamba_location
    [ "$status" -eq 0 ]
    [ "$output" = "user" ]
    
    # Cleanup
    rm -f "$HOME/.pyve/bin/micromamba"
}

@test "get_micromamba_location: returns 'system' for system PATH" {
    mkdir -p /tmp/fake_bin
    touch /tmp/fake_bin/micromamba
    chmod +x /tmp/fake_bin/micromamba
    
    which() {
        if [[ "$1" == "micromamba" ]]; then
            echo "/tmp/fake_bin/micromamba"
            return 0
        fi
        command which "$@"
    }
    
    run get_micromamba_location
    [ "$status" -eq 0 ]
    [ "$output" = "system" ]
    
    unset -f which
    rm -rf /tmp/fake_bin
}

@test "get_micromamba_location: returns 'not_found' when not available" {
    which() {
        if [[ "$1" == "micromamba" ]]; then
            return 1
        fi
        command which "$@"
    }
    
    run get_micromamba_location
    [ "$status" -eq 1 ]
    [ "$output" = "not_found" ]
    
    unset -f which
}

@test "get_micromamba_location: project takes priority over user and system" {
    mkdir -p .pyve/bin
    touch .pyve/bin/micromamba
    chmod +x .pyve/bin/micromamba
    
    mkdir -p "$HOME/.pyve/bin"
    touch "$HOME/.pyve/bin/micromamba"
    chmod +x "$HOME/.pyve/bin/micromamba"
    
    run get_micromamba_location
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
    
    # Cleanup
    rm -f "$HOME/.pyve/bin/micromamba"
}

#============================================================
# error_micromamba_not_found() tests
#============================================================

@test "error_micromamba_not_found: returns 1" {
    run error_micromamba_not_found
    [ "$status" -eq 1 ]
}

@test "error_micromamba_not_found: outputs error message" {
    run error_micromamba_not_found
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"not installed"* ]]
}

@test "error_micromamba_not_found: accepts custom context message" {
    run error_micromamba_not_found "Custom error context"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Custom error context"* ]]
}
