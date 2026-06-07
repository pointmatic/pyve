#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Unit tests for the toolchain-Python lifecycle (Story N.at.3):
#   - `self install` provisions the hidden venv (best-effort, non-fatal)
#   - a DEFAULT_PYTHON_VERSION bump provisions a new version-keyed dir
#     and prunes the stale one
#   - `self uninstall` removes the whole toolchain tree
#   - the build bootstrap prefers the version-manager's EXACT-version
#     interpreter (version-tracking fidelity), falling back to PATH
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/ui/run.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"

    TEST_DIR="$(mktemp -d)"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_fake_build_succeeds() {
    _pyve_toolchain_build() {
        local dir="$1"
        mkdir -p "$dir/bin"
        printf '#!/bin/sh\necho built\n' > "$dir/bin/python"
        chmod +x "$dir/bin/python"
        return 0
    }
}

#------------------------------------------------------------
# Install
#------------------------------------------------------------

@test "_self_install_toolchain_python: provisions the venv when build succeeds" {
    _fake_build_succeeds
    run _self_install_toolchain_python
    assert_status_equals 0
    [[ -x "$(pyve_toolchain_venv_dir)/bin/python" ]]
}

@test "_self_install_toolchain_python: non-fatal when the build fails (install must not abort)" {
    _pyve_toolchain_build() { return 1; }
    run _self_install_toolchain_python
    assert_status_equals 0
    assert_output_contains "fall back"
}

@test "_self_install_toolchain_python: a DEFAULT_PYTHON_VERSION bump provisions a new keyed dir" {
    _fake_build_succeeds
    _self_install_toolchain_python                       # builds 3.14.4
    [[ -x "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin/python" ]]

    DEFAULT_PYTHON_VERSION="3.15.0"
    _fake_build_succeeds
    run _self_install_toolchain_python                   # builds 3.15.0
    assert_status_equals 0
    [[ -x "$XDG_DATA_HOME/pyve/toolchain/3.15.0/venv/bin/python" ]]
}

@test "_self_install_toolchain_python: prunes stale version dirs (old GC-able)" {
    # A leftover venv from a previous DEFAULT_PYTHON_VERSION.
    mkdir -p "$XDG_DATA_HOME/pyve/toolchain/3.10.0/venv/bin"
    : > "$XDG_DATA_HOME/pyve/toolchain/3.10.0/venv/bin/python"
    _fake_build_succeeds
    run _self_install_toolchain_python                   # current = 3.14.4
    assert_status_equals 0
    [[ -d "$XDG_DATA_HOME/pyve/toolchain/3.14.4" ]]
    [[ ! -d "$XDG_DATA_HOME/pyve/toolchain/3.10.0" ]]
}

#------------------------------------------------------------
# Uninstall
#------------------------------------------------------------

@test "_self_uninstall_toolchain_python: removes the entire toolchain tree" {
    mkdir -p "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin"
    : > "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin/python"
    [[ -d "$(pyve_toolchain_root)" ]]
    run _self_uninstall_toolchain_python
    assert_status_equals 0
    [[ ! -d "$(pyve_toolchain_root)" ]]
}

@test "_self_uninstall_toolchain_python: no-op when the tree is absent" {
    [[ ! -d "$(pyve_toolchain_root)" ]]
    run _self_uninstall_toolchain_python
    assert_status_equals 0
}

#------------------------------------------------------------
# Build bootstrap — exact-version fidelity (version tracking)
#------------------------------------------------------------

@test "_pyve_toolchain_bootstrap_python: prefers the version manager's exact-version interpreter" {
    # Fake an asdf install for the pinned version.
    local install="$TEST_DIR/asdf-python-3.14.4"
    mkdir -p "$install/bin"
    printf '#!/bin/sh\necho 3.14.4\n' > "$install/bin/python"
    chmod +x "$install/bin/python"

    detect_version_manager() { VERSION_MANAGER="asdf"; }
    ensure_python_version_installed() { return 0; }
    asdf() { [[ "$1" == "where" && "$2" == "python" ]] && printf '%s' "$install"; }

    run _pyve_toolchain_bootstrap_python "3.14.4"
    assert_status_equals 0
    assert_output_equals "$install/bin/python"
}

@test "_pyve_toolchain_bootstrap_python: falls back to a PATH python when no version-manager match" {
    # A fake `python3` on PATH (the legacy bootstrap source) and no
    # version manager resolution.
    local fakebin="$TEST_DIR/fakebin"
    mkdir -p "$fakebin"
    printf '#!/bin/sh\necho 3.12.0\n' > "$fakebin/python3"
    chmod +x "$fakebin/python3"

    detect_version_manager() { VERSION_MANAGER=""; }
    ensure_python_version_installed() { return 1; }

    PATH="$fakebin:$PATH" run _pyve_toolchain_bootstrap_python "3.14.4"
    assert_status_equals 0
    assert_output_contains "python3"
}
