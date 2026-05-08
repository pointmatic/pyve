#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Coverage-focused tests for lib/distutils_shim.sh. Complements the existing
# tests/unit/test_distutils_shim.bats (which covers the primary install
# flow) by exercising the functions and branches left uncovered per the
# Codecov baseline after v2.2.0: pyve_get_site_packages_dir,
# pyve_distutils_shim_probe, pyve_ensure_*_packaging_prereqs, the "python
# < 3.12" short-circuit, "empty site_packages" warning, and the entire
# pyve_install_distutils_shim_for_micromamba_prefix function. See Story I.k.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# Helper: make a fake python binary whose behavior varies by args.
# PY_VERSION controls the version reported by the 3.12-plus detection call.
# PY_SITE_PACKAGES controls the path reported by the site-packages call.
# PY_PROBE controls what the probe sees for SETUPTOOLS_USE_DISTUTILS.
make_fake_python() {
    local path="$1"
    cat > "$path" << 'EOF'
#!/usr/bin/env bash
# Minimal fake python script — distinguishes the three -c calls that
# distutils_shim.sh makes by a substring match on the source.
if [[ "${1:-}" == "-c" ]]; then
    case "$2" in
        *version_info*)
            echo "${PY_VERSION:-3.14}"
            exit 0
            ;;
        *getsitepackages*)
            # PY_SITE_PACKAGES can be empty to simulate a python that
            # returns nothing.
            echo "${PY_SITE_PACKAGES:-}"
            exit 0
            ;;
        *SETUPTOOLS_USE_DISTUTILS*)
            # If PY_PROBE_FAIL=1, simulate "setuptools import failed".
            if [[ "${PY_PROBE_FAIL:-0}" == "1" ]]; then
                exit 1
            fi
            # ${PY_PROBE-local} (no colon) so PY_PROBE="" stays empty and
            # only truly-unset PY_PROBE falls back to "local".
            echo "${PY_PROBE-local}"
            exit 0
            ;;
    esac
fi
exit 0
EOF
    chmod +x "$path"
}

# ────────────────────────────────────────────────────────────────────
# pyve_get_site_packages_dir
# ────────────────────────────────────────────────────────────────────

@test "pyve_get_site_packages_dir: returns path reported by python" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    PY_SITE_PACKAGES="$TEST_DIR/site-packages" run pyve_get_site_packages_dir "$fake_python"
    assert_status_equals 0
    assert_output_equals "$TEST_DIR/site-packages"
}

@test "pyve_get_site_packages_dir: returns empty when python prints nothing" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    PY_SITE_PACKAGES="" run pyve_get_site_packages_dir "$fake_python"
    assert_status_equals 0
    assert_output_equals ""
}

@test "pyve_get_site_packages_dir: returns empty for nonexistent python" {
    run -127 pyve_get_site_packages_dir "/nonexistent/python"
    assert_output_equals ""
}

# ────────────────────────────────────────────────────────────────────
# pyve_distutils_shim_probe
# ────────────────────────────────────────────────────────────────────

@test "pyve_distutils_shim_probe: logs success when SETUPTOOLS_USE_DISTUTILS=local" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    PY_PROBE="local" run pyve_distutils_shim_probe "$fake_python"
    assert_status_equals 0
    assert_output_contains "SETUPTOOLS_USE_DISTUTILS=local"
}

@test "pyve_distutils_shim_probe: warns when SETUPTOOLS_USE_DISTUTILS is unset" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    PY_PROBE="" run pyve_distutils_shim_probe "$fake_python"
    assert_status_equals 0
    assert_output_contains "was not set"
}

@test "pyve_distutils_shim_probe: warns when SETUPTOOLS_USE_DISTUTILS has a non-local value" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    PY_PROBE="stdlib" run pyve_distutils_shim_probe "$fake_python"
    assert_status_equals 0
    assert_output_contains "SETUPTOOLS_USE_DISTUTILS=stdlib"
}

@test "pyve_distutils_shim_probe: non-fatal when setuptools import fails" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    PY_PROBE_FAIL=1 run pyve_distutils_shim_probe "$fake_python"
    assert_status_equals 0
    assert_output_contains "could not import setuptools"
}

# ────────────────────────────────────────────────────────────────────
# pyve_ensure_venv_packaging_prereqs
# ────────────────────────────────────────────────────────────────────

@test "pyve_ensure_venv_packaging_prereqs: runs pip install with pip already available" {
    local fake_python="$TEST_DIR/python"
    # Track calls in a side file; pip calls all succeed.
    cat > "$fake_python" << EOF
#!/usr/bin/env bash
echo "python \$@" >> "$TEST_DIR/calls.log"
exit 0
EOF
    chmod +x "$fake_python"

    run pyve_ensure_venv_packaging_prereqs "$fake_python"
    assert_status_equals 0
    # Should have invoked pip install -U pip setuptools wheel
    grep -q "pip install -U pip setuptools wheel" "$TEST_DIR/calls.log"
}

@test "pyve_ensure_venv_packaging_prereqs: falls back to ensurepip when pip is missing" {
    local fake_python="$TEST_DIR/python"
    # First pip --version call fails (non-zero); subsequent calls succeed.
    cat > "$fake_python" << EOF
#!/usr/bin/env bash
echo "python \$@" >> "$TEST_DIR/calls.log"
if [[ "\$1 \$2 \$3" == "-m pip --version" ]]; then exit 1; fi
exit 0
EOF
    chmod +x "$fake_python"

    run pyve_ensure_venv_packaging_prereqs "$fake_python"
    assert_status_equals 0
    grep -q "ensurepip" "$TEST_DIR/calls.log"
}

# ────────────────────────────────────────────────────────────────────
# pyve_install_distutils_shim_for_python: uncovered branches
# ────────────────────────────────────────────────────────────────────

@test "pyve_install_distutils_shim_for_python: skips silently for Python < 3.12" {
    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    local sp_dir="$TEST_DIR/site-packages"
    PY_VERSION="3.11" PY_SITE_PACKAGES="$sp_dir" run pyve_install_distutils_shim_for_python "$fake_python"
    assert_status_equals 0
    [ ! -f "$sp_dir/sitecustomize.py" ]
}

@test "pyve_install_distutils_shim_for_python: warns when site-packages path is empty" {
    pyve_python_is_312_plus() { return 0; }
    pyve_ensure_venv_packaging_prereqs() { return 0; }
    pyve_get_site_packages_dir() { echo ""; }

    local fake_python="$TEST_DIR/python"
    make_fake_python "$fake_python"

    run pyve_install_distutils_shim_for_python "$fake_python"
    assert_status_equals 0
    assert_output_contains "Could not determine site-packages directory"
}

# ────────────────────────────────────────────────────────────────────
# pyve_install_distutils_shim_for_micromamba_prefix
# ────────────────────────────────────────────────────────────────────

@test "pyve_install_distutils_shim_for_micromamba_prefix: skips when env has no python" {
    local env_prefix="$TEST_DIR/env"
    mkdir -p "$env_prefix/bin"
    # No python binary in env
    run pyve_install_distutils_shim_for_micromamba_prefix "/dummy/micromamba" "$env_prefix"
    assert_status_equals 0
    [ ! -f "$env_prefix/lib/python*/site-packages/sitecustomize.py" ] || false
}

@test "pyve_install_distutils_shim_for_micromamba_prefix: respects PYVE_DISABLE_DISTUTILS_SHIM=1" {
    local env_prefix="$TEST_DIR/env"
    mkdir -p "$env_prefix/bin"
    make_fake_python "$env_prefix/bin/python"

    PYVE_DISABLE_DISTUTILS_SHIM=1 run pyve_install_distutils_shim_for_micromamba_prefix "/dummy/micromamba" "$env_prefix"
    assert_status_equals 0
    assert_output_contains "disabled"
}

@test "pyve_install_distutils_shim_for_micromamba_prefix: skips silently for Python < 3.12" {
    local env_prefix="$TEST_DIR/env"
    mkdir -p "$env_prefix/bin"
    make_fake_python "$env_prefix/bin/python"

    PY_VERSION="3.11" run pyve_install_distutils_shim_for_micromamba_prefix "/dummy/micromamba" "$env_prefix"
    assert_status_equals 0
}

@test "pyve_install_distutils_shim_for_micromamba_prefix: warns when site-packages empty" {
    pyve_python_is_312_plus() { return 0; }
    pyve_ensure_micromamba_packaging_prereqs() { return 0; }
    pyve_get_site_packages_dir() { echo ""; }

    local env_prefix="$TEST_DIR/env"
    mkdir -p "$env_prefix/bin"
    make_fake_python "$env_prefix/bin/python"

    run pyve_install_distutils_shim_for_micromamba_prefix "/dummy/micromamba" "$env_prefix"
    assert_status_equals 0
    assert_output_contains "Could not determine site-packages directory"
}

@test "pyve_install_distutils_shim_for_micromamba_prefix: happy path installs shim" {
    pyve_python_is_312_plus() { return 0; }
    pyve_ensure_micromamba_packaging_prereqs() { return 0; }

    local env_prefix="$TEST_DIR/env"
    local sp_dir="$TEST_DIR/site-packages"
    mkdir -p "$env_prefix/bin" "$sp_dir"
    make_fake_python "$env_prefix/bin/python"

    pyve_get_site_packages_dir() { echo "$sp_dir"; }

    run pyve_install_distutils_shim_for_micromamba_prefix "/dummy/micromamba" "$env_prefix"
    assert_status_equals 0
    assert_file_exists "$sp_dir/sitecustomize.py"
    assert_file_contains "$sp_dir/sitecustomize.py" "pyve-managed: distutils shim"
}

# ────────────────────────────────────────────────────────────────────
# pyve_write_sitecustomize_shim: already-current short-circuit
# ────────────────────────────────────────────────────────────────────

@test "pyve_write_sitecustomize_shim: no-op when shim already matches desired content" {
    local sp_dir="$TEST_DIR/site-packages"
    mkdir -p "$sp_dir"

    # Write the desired shim first
    run pyve_write_sitecustomize_shim "$sp_dir"
    assert_status_equals 0

    # Cross-platform mtime: try GNU stat first (`-c %Y`), fall back to BSD
    # stat (`-f %m`). Order matters — BSD stat's `-c` exits 1 ("illegal
    # option") so the fallback fires correctly on macOS, but GNU stat's
    # `-f %m` does NOT fail on Linux (coreutils 9.0+ treats %m as
    # "Mountpoint" in filesystem-status mode), which would make the
    # fallback unreachable and produce a mountpoint string instead of an
    # mtime — silently breaking this test on Linux CI runners.
    local mtime_before
    mtime_before="$(stat -c %Y "$sp_dir/sitecustomize.py" 2>/dev/null || stat -f %m "$sp_dir/sitecustomize.py")"

    # Wait a bit so mtime would change if file were rewritten
    sleep 1

    # Run again — should short-circuit without rewriting
    run pyve_write_sitecustomize_shim "$sp_dir"
    assert_status_equals 0

    local mtime_after
    mtime_after="$(stat -c %Y "$sp_dir/sitecustomize.py" 2>/dev/null || stat -f %m "$sp_dir/sitecustomize.py")"

    [[ "$mtime_before" == "$mtime_after" ]]
}
