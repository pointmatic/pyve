#!/usr/bin/env bats

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "pyve_install_distutils_shim_for_python: writes pyve-managed sitecustomize.py (idempotent)" {
    # Make version check deterministic without requiring real Python 3.12
    pyve_python_is_312_plus() { return 0; }

    # Avoid real pip calls
    pyve_ensure_venv_packaging_prereqs() { return 0; }

    local sp_dir="$TEST_DIR/site-packages"
    mkdir -p "$sp_dir"

    pyve_get_site_packages_dir() { echo "$sp_dir"; }

    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'EOF'
#!/usr/bin/env bash
# Minimal fake python for shim logic
if [[ "${1:-}" == "-c" ]]; then
  # Return something plausible for any -c call
  echo "3.12"
  exit 0
fi
exit 0
EOF
    chmod +x "$fake_python"

    run pyve_install_distutils_shim_for_python "$fake_python"
    assert_status_equals 0

    assert_file_exists "$sp_dir/sitecustomize.py"
    assert_file_contains "$sp_dir/sitecustomize.py" "pyve-managed: distutils shim"
    assert_file_contains "$sp_dir/sitecustomize.py" "SETUPTOOLS_USE_DISTUTILS"

    local first
    first="$(cat "$sp_dir/sitecustomize.py")"

    run pyve_install_distutils_shim_for_python "$fake_python"
    assert_status_equals 0

    local second
    second="$(cat "$sp_dir/sitecustomize.py")"

    [ "$first" = "$second" ]
}

@test "pyve_install_distutils_shim_for_python: respects PYVE_DISABLE_DISTUTILS_SHIM=1" {
    pyve_python_is_312_plus() { return 0; }
    pyve_ensure_venv_packaging_prereqs() { return 0; }

    local sp_dir="$TEST_DIR/site-packages"
    mkdir -p "$sp_dir"
    pyve_get_site_packages_dir() { echo "$sp_dir"; }

    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$fake_python"

    PYVE_DISABLE_DISTUTILS_SHIM=1 run pyve_install_distutils_shim_for_python "$fake_python"
    assert_status_equals 0

    # Should not create sitecustomize.py when disabled
    [ ! -f "$sp_dir/sitecustomize.py" ]
}

@test "pyve_is_distutils_shim_disabled: returns 1 when not set" {
    unset PYVE_DISABLE_DISTUTILS_SHIM
    run pyve_is_distutils_shim_disabled
    [ "$status" -eq 1 ]
}

@test "pyve_is_distutils_shim_disabled: returns 0 when set to 1" {
    PYVE_DISABLE_DISTUTILS_SHIM=1 run pyve_is_distutils_shim_disabled
    [ "$status" -eq 0 ]
}

@test "pyve_is_distutils_shim_disabled: returns 1 when set to 0" {
    PYVE_DISABLE_DISTUTILS_SHIM=0 run pyve_is_distutils_shim_disabled
    [ "$status" -eq 1 ]
}

@test "pyve_get_python_major_minor: extracts major.minor from fake python" {
    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'PYEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-c" ]]; then
    eval "$2"
    exit $?
fi
exit 0
PYEOF
    chmod +x "$fake_python"

    # Create a minimal sys module stub
    result="$("$fake_python" -c 'echo "3.14"')"
    [ "$result" = "3.14" ]
}

@test "pyve_get_python_major_minor: returns empty for invalid python path" {
    run pyve_get_python_major_minor "/nonexistent/python"
    [ -z "$output" ]
}

@test "pyve_python_is_312_plus: returns 0 for Python 3.14" {
    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'PYEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-c" ]]; then echo "3.14"; exit 0; fi
exit 0
PYEOF
    chmod +x "$fake_python"

    run pyve_python_is_312_plus "$fake_python"
    [ "$status" -eq 0 ]
}

@test "pyve_python_is_312_plus: returns 0 for Python 3.12" {
    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'PYEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-c" ]]; then echo "3.12"; exit 0; fi
exit 0
PYEOF
    chmod +x "$fake_python"

    run pyve_python_is_312_plus "$fake_python"
    [ "$status" -eq 0 ]
}

@test "pyve_python_is_312_plus: returns 1 for Python 3.11" {
    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'PYEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-c" ]]; then echo "3.11"; exit 0; fi
exit 0
PYEOF
    chmod +x "$fake_python"

    run pyve_python_is_312_plus "$fake_python"
    [ "$status" -eq 1 ]
}

@test "pyve_python_is_312_plus: returns 0 for Python 4.0" {
    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'PYEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-c" ]]; then echo "4.0"; exit 0; fi
exit 0
PYEOF
    chmod +x "$fake_python"

    run pyve_python_is_312_plus "$fake_python"
    [ "$status" -eq 0 ]
}

@test "pyve_python_is_312_plus: returns 1 for Python 2.7" {
    local fake_python="$TEST_DIR/python"
    cat > "$fake_python" << 'PYEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-c" ]]; then echo "2.7"; exit 0; fi
exit 0
PYEOF
    chmod +x "$fake_python"

    run pyve_python_is_312_plus "$fake_python"
    [ "$status" -eq 1 ]
}

@test "pyve_python_is_312_plus: returns 1 for invalid python" {
    run pyve_python_is_312_plus "/nonexistent/python"
    [ "$status" -eq 1 ]
}

@test "pyve_write_sitecustomize_shim: updates outdated pyve-managed shim" {
    local sp_dir="$TEST_DIR/site-packages"
    mkdir -p "$sp_dir"

    # Write an old version of the pyve-managed shim
    cat > "$sp_dir/sitecustomize.py" << 'EOF'
# pyve-managed: distutils shim
import os
os.environ.setdefault("SETUPTOOLS_USE_DISTUTILS", "stdlib")
EOF

    run pyve_write_sitecustomize_shim "$sp_dir"
    assert_status_equals 0

    # Should have been updated to the current version
    assert_file_contains "$sp_dir/sitecustomize.py" "\"local\""
}

@test "pyve_write_sitecustomize_shim: creates shim in new directory" {
    local sp_dir="$TEST_DIR/new-site-packages"

    run pyve_write_sitecustomize_shim "$sp_dir"
    assert_status_equals 0

    assert_file_exists "$sp_dir/sitecustomize.py"
    assert_file_contains "$sp_dir/sitecustomize.py" "pyve-managed: distutils shim"
}

@test "pyve_write_sitecustomize_shim: does not clobber non-pyve-managed sitecustomize.py" {
    local sp_dir="$TEST_DIR/site-packages"
    mkdir -p "$sp_dir"

    cat > "$sp_dir/sitecustomize.py" << 'EOF'
# user-managed sitecustomize
print("hello")
EOF

    run pyve_write_sitecustomize_shim "$sp_dir"
    assert_status_equals 0

    assert_file_contains "$sp_dir/sitecustomize.py" "user-managed sitecustomize"
    # Ensure our marker was not injected
    if grep -qF "pyve-managed: distutils shim" "$sp_dir/sitecustomize.py"; then
        echo "Expected pyve shim not to overwrite/inject into user-managed sitecustomize.py" >&2
        return 1
    fi
}
