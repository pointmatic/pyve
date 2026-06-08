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
# is_conda_lock_declared() tests (Story N.bf.8)
#============================================================
# The declarative signal for "a lock is required": conda-lock present as a
# dependency in environment.yml. Must match bare / version-pinned / pip-nested
# forms, must NOT match longer names (conda-lock-foo), and must be false when
# there is no environment.yml.

@test "is_conda_lock_declared: bare 'conda-lock' dependency → true" {
    cat > environment.yml <<'YAML'
name: demo
channels: [conda-forge]
dependencies:
  - python=3.11
  - conda-lock
YAML
    run is_conda_lock_declared
    [ "$status" -eq 0 ]
}

@test "is_conda_lock_declared: version-pinned 'conda-lock=2.5.0' → true" {
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - conda-lock=2.5.0
YAML
    run is_conda_lock_declared
    [ "$status" -eq 0 ]
}

@test "is_conda_lock_declared: space-separated 'conda-lock >=2' → true" {
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - conda-lock >=2
YAML
    run is_conda_lock_declared
    [ "$status" -eq 0 ]
}

@test "is_conda_lock_declared: nested under 'pip:' subsection → true" {
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - python=3.11
  - pip
  - pip:
      - conda-lock
      - requests
YAML
    run is_conda_lock_declared
    [ "$status" -eq 0 ]
}

@test "is_conda_lock_declared: absent → false" {
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - python=3.11
  - numpy
YAML
    run is_conda_lock_declared
    [ "$status" -eq 1 ]
}

@test "is_conda_lock_declared: longer name 'conda-lock-foo' is NOT a match → false" {
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - conda-lock-foo
YAML
    run is_conda_lock_declared
    [ "$status" -eq 1 ]
}

@test "is_conda_lock_declared: no environment.yml → false (clean, no error)" {
    run is_conda_lock_declared
    [ "$status" -eq 1 ]
    [ -z "$output" ]
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

@test "validate_lock_file_status: non-strict, env.yml only, conda-lock NOT declared → proceeds (no lock expected)" {
    # Declarative model (N.bf.9): a lock is required only when conda-lock is a
    # declared dependency. Pre-production projects proceed silently.
    create_environment_yml "test-env" "python=3.11"

    run validate_lock_file_status "false"
    [ "$status" -eq 0 ]
    [[ "$output" != *"requires a lock file"* ]]
}

@test "validate_lock_file_status: non-strict, env.yml only, conda-lock declared → proceeds (nudge handled post-init)" {
    create_environment_yml "test-env" "python=3.11" "conda-lock"

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

@test "validate_lock_file_status: strict, env.yml only, conda-lock declared → barks (requires a lock)" {
    create_environment_yml "test-env" "python=3.11" "conda-lock"

    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires a lock file"* ]]
    [[ "$output" == *"pyve lock"* ]]
    [[ "$output" == *"remove conda-lock"* ]]
}

@test "validate_lock_file_status: strict, env.yml only, conda-lock NOT declared → proceeds (no lock required)" {
    create_environment_yml "test-env" "python=3.11"

    run validate_lock_file_status "true"
    [ "$status" -eq 0 ]
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
# H.f.6 — actionable error content for Cases 3 and 4
#
# These cases historically returned 1 silently in non-strict mode,
# producing a bare `exit 1` from the caller in pyve.sh with zero
# output — indistinguishable from a shell-integration bug. The fix:
# emit an actionable error unconditionally, name the missing file(s),
# and point at the venv fallback.
#============================================================

@test "validate_lock_file_status: Case 3 (only conda-lock.yml) emits actionable error in non-strict mode" {
    touch conda-lock.yml

    run validate_lock_file_status "false"
    [ "$status" -eq 1 ]
    [[ "$output" == *"environment.yml"* ]]
    [[ "$output" == *"pyve init --backend venv"* ]]
}

@test "validate_lock_file_status: Case 4 (neither file) emits actionable error in non-strict mode" {
    # Clean dir (no environment.yml, no conda-lock.yml) — reproduces
    # the 2026-04-20 user-visible silent-exit bug.
    run validate_lock_file_status "false"
    [ "$status" -eq 1 ]
    [[ "$output" == *"environment.yml"* ]]
    [[ "$output" == *"pyve init --backend venv"* ]]
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

@test "validate_lock_file_status: defaults to non-strict when no argument (undeclared → proceeds)" {
    create_environment_yml "test-env" "python=3.11"

    run validate_lock_file_status
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: handles empty string as non-strict (undeclared → proceeds)" {
    create_environment_yml "test-env" "python=3.11"

    run validate_lock_file_status ""
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: PYVE_NO_LOCK=1 relaxes the requirement even when conda-lock is declared (--no-lock beats --strict)" {
    create_environment_yml "test-env" "python=3.11" "conda-lock"

    PYVE_NO_LOCK=1 run validate_lock_file_status "true"
    [ "$status" -eq 0 ]
}

@test "validate_lock_file_status: PYVE_NO_LOCK=1 does not bypass missing environment.yml" {
    # Only conda-lock.yml present — still an error regardless of --no-lock
    touch conda-lock.yml

    PYVE_NO_LOCK=1 run validate_lock_file_status "false"
    [ "$status" -eq 1 ]
}

@test "validate_lock_file_status: stale lock still warns and continues in non-strict non-interactive mode" {
    touch -t 202401010000 conda-lock.yml
    touch -t 202401010001 environment.yml

    run validate_lock_file_status "false"
    [ "$status" -eq 0 ]
}

#============================================================
# get_conda_platform() tests
#============================================================

@test "get_conda_platform: returns osx-arm64 on Darwin/arm64" {
    local mock_dir
    mock_dir="$(mktemp -d)"
    cat > "$mock_dir/uname" << 'EOF'
#!/bin/bash
if [[ "$1" == "-s" ]]; then echo "Darwin"; elif [[ "$1" == "-m" ]]; then echo "arm64"; fi
EOF
    chmod +x "$mock_dir/uname"
    PATH="$mock_dir:$PATH" run get_conda_platform
    rm -rf "$mock_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "osx-arm64" ]
}

@test "get_conda_platform: returns osx-64 on Darwin/x86_64" {
    local mock_dir
    mock_dir="$(mktemp -d)"
    cat > "$mock_dir/uname" << 'EOF'
#!/bin/bash
if [[ "$1" == "-s" ]]; then echo "Darwin"; elif [[ "$1" == "-m" ]]; then echo "x86_64"; fi
EOF
    chmod +x "$mock_dir/uname"
    PATH="$mock_dir:$PATH" run get_conda_platform
    rm -rf "$mock_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "osx-64" ]
}

@test "get_conda_platform: returns linux-64 on Linux/x86_64" {
    local mock_dir
    mock_dir="$(mktemp -d)"
    cat > "$mock_dir/uname" << 'EOF'
#!/bin/bash
if [[ "$1" == "-s" ]]; then echo "Linux"; elif [[ "$1" == "-m" ]]; then echo "x86_64"; fi
EOF
    chmod +x "$mock_dir/uname"
    PATH="$mock_dir:$PATH" run get_conda_platform
    rm -rf "$mock_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "linux-64" ]
}

@test "get_conda_platform: returns linux-aarch64 on Linux/aarch64" {
    local mock_dir
    mock_dir="$(mktemp -d)"
    cat > "$mock_dir/uname" << 'EOF'
#!/bin/bash
if [[ "$1" == "-s" ]]; then echo "Linux"; elif [[ "$1" == "-m" ]]; then echo "aarch64"; fi
EOF
    chmod +x "$mock_dir/uname"
    PATH="$mock_dir:$PATH" run get_conda_platform
    rm -rf "$mock_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "linux-aarch64" ]
}

#============================================================
# pyve lock — message content tests
# These verify that user-facing messages reference 'pyve lock'
# rather than raw conda-lock commands (FR-15 policy change).
#============================================================

@test "warn_stale_lock_file: references 'pyve lock' not raw conda-lock command" {
    touch -t 202401010000 conda-lock.yml
    touch -t 202401010001 environment.yml

    # Non-interactive, auto-continue
    CI=1 run warn_stale_lock_file
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve lock"* ]]
    [[ "$output" != *"conda-lock -f"* ]]
}

@test "info_missing_lock_file: references 'pyve lock' not raw conda-lock command" {
    create_environment_yml "test-env" "python=3.11"

    CI=1 run info_missing_lock_file
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve lock"* ]]
    [[ "$output" != *"conda-lock -f"* ]]
}

@test "validate_lock_file_status: strict stale error references 'pyve lock'" {
    touch -t 202401010000 conda-lock.yml
    touch -t 202401010001 environment.yml

    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
    [[ "$output" == *"pyve lock"* ]]
    [[ "$output" != *"conda-lock -f"* ]]
}

@test "validate_lock_file_status: strict declared-missing bark references 'pyve lock'" {
    create_environment_yml "test-env" "python=3.11" "conda-lock"

    run validate_lock_file_status "true"
    [ "$status" -eq 1 ]
    [[ "$output" == *"pyve lock"* ]]
    [[ "$output" != *"conda-lock -f"* ]]
}
