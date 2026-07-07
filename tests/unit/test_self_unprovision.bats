#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Hosted-toolchain lifecycle symmetry: `pyve self unprovision`.
#
# `self provision` had no teardown/upgrade mirror — `self uninstall`
# removed the ENTIRE toolchain (incl. toolchain Python) and no-ops for
# Homebrew, leaving brew users with no supported teardown for the hosted
# tools. `self unprovision` is the brew-safe granular mirror:
#   - removes the project-guide shim + the hosted project-guide PACKAGE
#     from the toolchain venv (keeps the toolchain Python)
#   - `--all` additionally drops the whole toolchain Python tree
#   - brew-safe: never installs a pyve binary or rewrites PATH
#
# Plus: ratify the upgrade semantics — an explicit provision always
# `pip install --upgrade`s the hosted project-guide.
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
    export HOME="$TEST_DIR/home"
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fabricate a provisioned toolchain venv: a `python` + `pip` (no-op success
# unless a recorder is wired) + a `project-guide` console script.
_make_toolchain_venv() {
    local venv_dir bin
    venv_dir="$(pyve_toolchain_venv_dir)"
    bin="$venv_dir/bin"
    mkdir -p "$bin"
    printf '#!/bin/sh\nexit 0\n' > "$bin/python"
    printf '#!/bin/sh\nexit 0\n' > "$bin/pip"
    printf '#!/bin/sh\necho project-guide\n' > "$bin/project-guide"
    chmod +x "$bin/python" "$bin/pip" "$bin/project-guide"
}

# Replace the toolchain venv's pip with a recorder that appends its args to
# $TEST_DIR/pip-args and still exits 0.
_record_pip() {
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"
    cat > "$bin/pip" <<SH
#!/bin/sh
echo "\$*" >> "$TEST_DIR/pip-args"
exit 0
SH
    chmod +x "$bin/pip"
}

#------------------------------------------------------------
# unprovision — granular, brew-safe teardown
#------------------------------------------------------------

@test "self unprovision: removes the project-guide shim" {
    _make_toolchain_venv
    _self_install_project_guide
    [[ -L "$HOME/.local/bin/project-guide" ]]
    run self_unprovision
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "self unprovision: pip-uninstalls the hosted project-guide package" {
    _make_toolchain_venv
    _record_pip
    run self_unprovision
    assert_status_equals 0
    grep -q 'uninstall' "$TEST_DIR/pip-args"
    grep -q 'project-guide' "$TEST_DIR/pip-args"
}

@test "self unprovision: keeps the toolchain Python tree (no --all)" {
    _make_toolchain_venv
    run self_unprovision
    assert_status_equals 0
    # The toolchain venv (and its python) survives a granular unprovision.
    [[ -x "$(pyve_toolchain_venv_dir)/bin/python" ]]
    [[ -d "$(pyve_toolchain_root)" ]]
}

@test "self unprovision --all: drops the whole toolchain Python tree" {
    _make_toolchain_venv
    _self_install_project_guide
    run self_unprovision --all
    assert_status_equals 0
    [[ ! -d "$(pyve_toolchain_root)" ]]
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "self unprovision: brew-safe — no pyve binary, no PATH rewrite" {
    _make_toolchain_venv
    run self_unprovision
    assert_status_equals 0
    [ ! -e "$HOME/.local/bin/pyve" ]
    [ ! -f "$HOME/.zprofile" ]
    [ ! -f "$HOME/.bash_profile" ]
}

@test "self unprovision: non-fatal when nothing is provisioned" {
    # No toolchain venv at all.
    run self_unprovision
    assert_status_equals 0
}

@test "self unprovision: leaves a real (non-symlink) hand-installed project-guide alone" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho real\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
    run self_unprovision
    assert_status_equals 0
    [[ -f "$HOME/.local/bin/project-guide" && ! -L "$HOME/.local/bin/project-guide" ]]
}

@test "self unprovision: unknown flag is a hard error" {
    run self_unprovision --bogus
    [ "$status" -ne 0 ]
}

#------------------------------------------------------------
# Dispatcher + help
#------------------------------------------------------------

@test "dispatcher: 'self unprovision' routes to self_unprovision" {
    export PYVE_DISPATCH_TRACE=1
    run self_command unprovision --all
    assert_status_equals 0
    [[ "$output" == *"DISPATCH:self-unprovision --all"* ]]
}

@test "dispatcher: 'self unprovision --help' shows help (no teardown)" {
    run self_command unprovision --help
    assert_status_equals 0
    [[ "$output" == *"pyve self unprovision"* ]]
}

@test "self help: lists the unprovision subcommand" {
    run show_self_help
    assert_status_equals 0
    [[ "$output" == *"unprovision"* ]]
}

#------------------------------------------------------------
# Upgrade semantics — explicit provision always upgrades
#------------------------------------------------------------

@test "explicit provision upgrades the hosted project-guide (pip install --upgrade)" {
    _make_toolchain_venv
    _record_pip
    run _self_install_project_guide
    assert_status_equals 0
    grep -qE 'install --upgrade .*project-guide' "$TEST_DIR/pip-args"
}
