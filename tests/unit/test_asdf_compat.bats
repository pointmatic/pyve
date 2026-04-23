#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the asdf/direnv coexistence helpers (Phase J).
#
# This file is the single home for the `is_asdf_active` helper contract
# (Story J.a) plus placeholder tests for the downstream behaviors that
# J.b (`.envrc` asdf compat guard) and J.c (`pyve run` asdf compat guard)
# will green. The J.b/J.c placeholders use `skip` with a reason pointing
# at the story that will unskip them — same pattern as the Phase I
# bootstrap-test activation flow.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # setup_pyve_env does not source lib/ui.sh (which provides info() /
    # success() used by init_direnv_venv / init_direnv_micromamba). Source
    # it locally so the generator functions can run under bats.
    source "$PYVE_ROOT/lib/ui.sh"
    create_test_dir

    # Each test starts with a neutral environment. Individual tests opt
    # into asdf-active state by setting VERSION_MANAGER and/or
    # PYVE_NO_ASDF_COMPAT explicitly.
    VERSION_MANAGER=""
    unset PYVE_NO_ASDF_COMPAT
}

teardown() {
    unset PYVE_NO_ASDF_COMPAT
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# is_asdf_active — the J.a helper contract
# ────────────────────────────────────────────────────────────────────

@test "is_asdf_active: VERSION_MANAGER=asdf and no gate → 0 (active)" {
    VERSION_MANAGER="asdf"
    run is_asdf_active
    [ "$status" -eq 0 ]
}

@test "is_asdf_active: VERSION_MANAGER=pyenv → 1 (not active)" {
    VERSION_MANAGER="pyenv"
    run is_asdf_active
    [ "$status" -eq 1 ]
}

@test "is_asdf_active: VERSION_MANAGER empty → 1 (not active)" {
    VERSION_MANAGER=""
    run is_asdf_active
    [ "$status" -eq 1 ]
}

@test "is_asdf_active: PYVE_NO_ASDF_COMPAT=1 suppresses active state" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT=1 run is_asdf_active
    [ "$status" -eq 1 ]
}

@test "is_asdf_active: PYVE_NO_ASDF_COMPAT empty is treated as unset (still active)" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT="" run is_asdf_active
    [ "$status" -eq 0 ]
}

@test "is_asdf_active: PYVE_NO_ASDF_COMPAT=anything truthy suppresses (e.g., 'yes')" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT="yes" run is_asdf_active
    [ "$status" -eq 1 ]
}

# ────────────────────────────────────────────────────────────────────
# Story J.b — .envrc asdf compat guard
# ────────────────────────────────────────────────────────────────────

# Extract a function definition from pyve.sh and eval it into the current
# shell. Pyve.sh can't be directly sourced in tests because its final line
# is `main "$@"` which would run the CLI dispatcher. The generators
# init_direnv_venv / init_direnv_micromamba are cleanly formatted (single-
# line header, closing brace at column 0), so an awk range extract works.
source_pyve_fn() {
    local fn="$1"
    local body
    body="$(awk -v fn="$fn" '
        $0 ~ "^" fn "\\(\\)[[:space:]]*\\{" { inside = 1 }
        inside { print }
        inside && /^\}$/ { exit }
    ' "$PYVE_ROOT/pyve.sh")"
    eval "$body"
}

@test "J.b: venv .envrc includes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 when asdf is active" {
    source_pyve_fn init_direnv_venv
    VERSION_MANAGER="asdf"

    run init_direnv_venv ".venv"
    [ "$status" -eq 0 ]

    assert_file_exists ".envrc"
    assert_file_contains ".envrc" "Prevent asdf Python plugin from reshimming"
    assert_file_contains ".envrc" "export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1"
}

@test "J.b: micromamba .envrc includes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 when asdf is active" {
    source_pyve_fn init_direnv_micromamba
    VERSION_MANAGER="asdf"

    run init_direnv_micromamba "test-env" "$TEST_DIR/envs/test-env"
    [ "$status" -eq 0 ]

    assert_file_exists ".envrc"
    assert_file_contains ".envrc" "Prevent asdf Python plugin from reshimming"
    assert_file_contains ".envrc" "export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1"
}

@test "J.b: venv .envrc omits the compat block when asdf is not active (VERSION_MANAGER=pyenv)" {
    source_pyve_fn init_direnv_venv
    VERSION_MANAGER="pyenv"

    run init_direnv_venv ".venv"
    [ "$status" -eq 0 ]

    assert_file_exists ".envrc"
    if grep -qF "ASDF_PYTHON_PLUGIN_DISABLE_RESHIM" ".envrc"; then
        echo "Expected .envrc to omit asdf guard when VERSION_MANAGER=pyenv" >&2
        cat .envrc >&2
        return 1
    fi
}

@test "J.b: venv .envrc omits the compat block when PYVE_NO_ASDF_COMPAT=1" {
    source_pyve_fn init_direnv_venv
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT=1

    run init_direnv_venv ".venv"
    [ "$status" -eq 0 ]

    assert_file_exists ".envrc"
    if grep -qF "ASDF_PYTHON_PLUGIN_DISABLE_RESHIM" ".envrc"; then
        echo "Expected .envrc to omit asdf guard when PYVE_NO_ASDF_COMPAT=1" >&2
        cat .envrc >&2
        return 1
    fi
}

@test "J.b: reinit is idempotent — asdf guard appears exactly once (byte-identical file)" {
    # H.a pattern: run the generator twice with the same inputs and asdf
    # active; the file must be byte-identical between runs (md5 match) and
    # the sentinel comment must appear exactly once.
    source_pyve_fn init_direnv_venv
    VERSION_MANAGER="asdf"

    init_direnv_venv ".venv"
    local md5_first
    md5_first="$(md5 -q .envrc 2>/dev/null || md5sum .envrc | awk '{print $1}')"

    init_direnv_venv ".venv"
    local md5_second
    md5_second="$(md5 -q .envrc 2>/dev/null || md5sum .envrc | awk '{print $1}')"

    [ "$md5_first" = "$md5_second" ]

    # Sentinel appears exactly once.
    local sentinel_count
    sentinel_count="$(grep -cF "Prevent asdf Python plugin from reshimming" .envrc)"
    [ "$sentinel_count" -eq 1 ]
}

@test "J.b: guard migrates onto a pre-existing .envrc that lacks the sentinel" {
    # Upgrade-path coverage: user has an .envrc from pyve < v2.3.0 (no
    # asdf guard). On the next `pyve init`, the generator should append
    # the guard to the existing file without touching its other content.
    source_pyve_fn init_direnv_venv
    VERSION_MANAGER="asdf"

    cat > .envrc << 'EOF'
# pyve-managed direnv configuration (legacy, no asdf guard)
VENV_DIR=".venv"
if [[ -d "$VENV_DIR" ]]; then source "$VENV_DIR/bin/activate"; fi
EOF

    init_direnv_venv ".venv"

    assert_file_contains ".envrc" "Prevent asdf Python plugin from reshimming"
    assert_file_contains ".envrc" "export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1"
    # Original content preserved.
    assert_file_contains ".envrc" "legacy, no asdf guard"
}

# ────────────────────────────────────────────────────────────────────
# Placeholder tests for Story J.c — pyve run asdf compat guard
# ────────────────────────────────────────────────────────────────────
# These assert that `pyve run <cmd>` exposes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
# to the subprocess when is_asdf_active returns 0. Story J.c wraps the
# dispatcher with `env ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 …`.

@test "J.c placeholder: pyve run subprocess environment includes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 when asdf active" {
    skip "Pending Story J.c: pyve run asdf compatibility guard"
    # When J.c unskips this, the expected shape is:
    #   - Arrange: is_asdf_active returns 0 (mock VERSION_MANAGER=asdf)
    #   - Run: pyve run env | grep ASDF_PYTHON_PLUGIN_DISABLE_RESHIM
    #   - Assert: subprocess sees ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
}

@test "J.c placeholder: PYVE_NO_ASDF_COMPAT=1 suppresses the pyve run env injection" {
    skip "Pending Story J.c: pyve run asdf compatibility guard"
    # Negative case: gate env var set → dispatcher must not inject the compat var.
}
