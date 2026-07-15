#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Unit tests for lib/toolchain_python.sh
#
# The Pyve-owned toolchain interpreter: a resolver that returns a
# reliable, Pyve-owned Python (independent of the developer's PATH)
# and an idempotent provisioner that builds the hidden venv, keyed by
# DEFAULT_PYTHON_VERSION under an XDG data path.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"

    TEST_DIR="$(mktemp -d)"
    # Isolate the toolchain tree inside the test dir.
    export XDG_DATA_HOME="$TEST_DIR/xdg-data"
    export DEFAULT_PYTHON_VERSION="3.14.4"
    # The override must not leak in from the surrounding shell.
    unset PYVE_PYTHON
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Helper: create a fake executable interpreter at the toolchain venv path.
# It reports DEFAULT_PYTHON_VERSION, because the slot is only accepted when the
# interpreter it holds IS the version the slot is keyed to — a fake that printed
# no version would (correctly) read as a stale slot and be rebuilt.
_make_fake_venv_python() {
    local dir
    dir="$(pyve_toolchain_venv_dir)"
    mkdir -p "$dir/bin"
    printf '#!/bin/sh\necho "Python %s"\n' "${DEFAULT_PYTHON_VERSION}" > "$dir/bin/python"
    chmod +x "$dir/bin/python"
}

#------------------------------------------------------------
# Path / version-keying
#------------------------------------------------------------

@test "pyve_toolchain_venv_dir is version-keyed under XDG_DATA_HOME" {
    run pyve_toolchain_venv_dir
    assert_status_equals 0
    assert_output_equals "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv"
}

@test "pyve_toolchain_venv_dir tracks DEFAULT_PYTHON_VERSION changes" {
    DEFAULT_PYTHON_VERSION="3.13.1"
    run pyve_toolchain_venv_dir
    assert_output_equals "$XDG_DATA_HOME/pyve/toolchain/3.13.1/venv"
}

@test "pyve_toolchain_venv_dir defaults to ~/.local/share when XDG_DATA_HOME unset" {
    unset XDG_DATA_HOME
    HOME="$TEST_DIR/home"
    run pyve_toolchain_venv_dir
    assert_output_equals "$TEST_DIR/home/.local/share/pyve/toolchain/3.14.4/venv"
}

#------------------------------------------------------------
# Resolution precedence: PYVE_PYTHON > toolchain venv > bare python
#------------------------------------------------------------

@test "pyve_toolchain_python: PYVE_PYTHON override wins (highest priority)" {
    export PYVE_PYTHON="/custom/interp/python"
    run pyve_toolchain_python
    assert_output_equals "/custom/interp/python"
}

@test "pyve_toolchain_python: PYVE_PYTHON wins even when a venv exists" {
    _make_fake_venv_python
    export PYVE_PYTHON="/custom/interp/python"
    run pyve_toolchain_python
    assert_output_equals "/custom/interp/python"
}

@test "pyve_toolchain_python: returns the toolchain venv interpreter when present" {
    _make_fake_venv_python
    run pyve_toolchain_python
    assert_output_equals "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin/python"
}

@test "pyve_toolchain_python: falls back to bare 'python' when no venv and no override" {
    run pyve_toolchain_python
    assert_output_equals "python"
}

#------------------------------------------------------------
# Provisioning (idempotent build)
#------------------------------------------------------------

@test "pyve_toolchain_python_ensure: idempotent no-op when the venv already holds the pinned version" {
    # Idempotency is conditioned on version fidelity, not mere existence: the
    # slot is reused only when its interpreter IS DEFAULT_PYTHON_VERSION. (A slot
    # holding some other Python is stale and gets rebuilt — see
    # test_toolchain_version_fidelity.bats.)
    _make_fake_venv_python
    # Sentinel: if the builder is invoked, the test fails.
    _pyve_toolchain_build() { printf 'BUILD-INVOKED\n' >&2; return 1; }
    run pyve_toolchain_python_ensure
    assert_status_equals 0
    [[ "$output" != *"BUILD-INVOKED"* ]] || {
        echo "builder was invoked despite an existing, correctly-versioned venv" >&2
        return 1
    }
}

@test "pyve_toolchain_python_ensure: invokes the builder when venv is missing" {
    # Stub the real build seam so the unit test does not shell out to asdf.
    _pyve_toolchain_build() {
        local dir="$1"
        mkdir -p "$dir/bin"
        printf '#!/bin/sh\necho built\n' > "$dir/bin/python"
        chmod +x "$dir/bin/python"
        return 0
    }
    run pyve_toolchain_python_ensure
    assert_status_equals 0
    assert_dir_exists "$(pyve_toolchain_venv_dir)/bin"
    [[ -x "$(pyve_toolchain_venv_dir)/bin/python" ]]
}

@test "pyve_toolchain_python_ensure: returns non-zero with a precise error when the build fails" {
    _pyve_toolchain_build() { return 1; }
    run pyve_toolchain_python_ensure
    [[ "$status" -ne 0 ]]
    assert_output_contains "toolchain"
}

@test "pyve_toolchain_python_ensure: builds at the version-keyed path" {
    _pyve_toolchain_build() {
        local dir="$1"
        mkdir -p "$dir/bin"
        : > "$dir/bin/python"
        chmod +x "$dir/bin/python"
        return 0
    }
    run pyve_toolchain_python_ensure
    assert_status_equals 0
    assert_dir_exists "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin"
}
