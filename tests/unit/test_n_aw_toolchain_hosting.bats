#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Story N.aw — F2 (revised): host project-guide as a Pyve-managed global
# tool. Cycle 1 — the hosting MECHANISM in `pyve self install`/`uninstall`:
#   - install project-guide into the toolchain venv (best-effort, pinned)
#   - shim the console script onto ~/.local/bin (PATH-reachable in every shell)
#   - re-point the shim on a DEFAULT_PYTHON_VERSION bump (idempotent ln -sf)
#   - uninstall removes the shim (only if it's our symlink)
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
    export HOME="$TEST_DIR/home"          # redirect ~/.local/bin shim target
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fabricate a provisioned toolchain venv whose `pip` is a no-op success and
# which already exposes a `project-guide` console script (the post-install
# state). $1 = "ok" (pip succeeds) | "fail" (pip exits non-zero).
_make_toolchain_venv() {
    local mode="${1:-ok}"
    local venv_dir bin
    venv_dir="$(pyve_toolchain_venv_dir)"
    bin="$venv_dir/bin"
    mkdir -p "$bin"
    if [[ "$mode" == "fail" ]]; then
        printf '#!/bin/sh\nexit 1\n' > "$bin/pip"
    else
        printf '#!/bin/sh\nexit 0\n' > "$bin/pip"
    fi
    chmod +x "$bin/pip"
    printf '#!/bin/sh\necho project-guide\n' > "$bin/project-guide"
    chmod +x "$bin/project-guide"
}

#------------------------------------------------------------
# Install + shim
#------------------------------------------------------------

@test "_self_install_project_guide: installs into the toolchain venv and shims it" {
    _make_toolchain_venv ok
    run _self_install_project_guide
    assert_status_equals 0
    [[ -L "$HOME/.local/bin/project-guide" ]]
}

@test "_self_install_project_guide: shim points at the toolchain venv's console script" {
    _make_toolchain_venv ok
    _self_install_project_guide
    local target
    target="$(readlink "$HOME/.local/bin/project-guide")"
    [[ "$target" == "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
}

@test "_self_install_project_guide: non-fatal + no shim when toolchain venv absent" {
    # No _make_toolchain_venv → no pip in the (unprovisioned) venv.
    run _self_install_project_guide
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "_self_install_project_guide: non-fatal when pip install fails (no shim)" {
    _make_toolchain_venv fail
    run _self_install_project_guide
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "_self_install_project_guide: re-points the shim after a version bump (idempotent)" {
    _make_toolchain_venv ok
    _self_install_project_guide
    # Simulate a DEFAULT_PYTHON_VERSION bump → a new version-keyed venv.
    export DEFAULT_PYTHON_VERSION="3.15.0"
    _make_toolchain_venv ok
    _self_install_project_guide
    local target
    target="$(readlink "$HOME/.local/bin/project-guide")"
    [[ "$target" == "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
    [[ "$target" == *"/3.15.0/"* ]]
}

#------------------------------------------------------------
# Uninstall
#------------------------------------------------------------

@test "_self_uninstall_project_guide: removes our shim symlink" {
    _make_toolchain_venv ok
    _self_install_project_guide
    [[ -L "$HOME/.local/bin/project-guide" ]]
    run _self_uninstall_project_guide
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "_self_uninstall_project_guide: leaves a real (non-symlink) project-guide binary alone" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho real\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
    run _self_uninstall_project_guide
    assert_status_equals 0
    [[ -f "$HOME/.local/bin/project-guide" && ! -L "$HOME/.local/bin/project-guide" ]]
}
