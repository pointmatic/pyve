#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# `pyve self install` — the lib/ file copy.
#
# Regression: the installer must ship EVERY lib/ subtree that pyve.sh
# sources, not a hand-maintained allowlist. v3.0.6 copied only
# lib/*.sh + lib/commands/ + lib/completion/, omitting lib/ui/ and
# lib/plugins/, so the installed binary died at startup sourcing
# lib/ui/core.sh. The faithful check runs the INSTALLED binary (whose
# SCRIPT_DIR points at the install target), not the source tree — the
# source tree always has every subdir, which is why no prior test
# caught the drift.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"

    TEST_DIR="$(mktemp -d)"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Drive the install into a sandboxed target — full control, never
    # the developer's real ~/.local.
    SCRIPT_DIR="$PYVE_ROOT"
    TARGET_BIN_DIR="$TEST_DIR/bin"
    TARGET_SCRIPT_PATH="$TARGET_BIN_DIR/pyve.sh"
    TARGET_SYMLINK_PATH="$TARGET_BIN_DIR/pyve"
    SOURCE_DIR_FILE="$HOME/.local/.pyve_source"
    VERSION="3.0.7"

    # Neutralize the heavy, best-effort, network/system-touching phases —
    # this test is only about the lib/ copy.
    detect_install_source() { printf 'source'; }
    _self_install_update_path() { :; }
    _self_install_prompt_hook() { :; }
    _self_install_local_env_template() { :; }
    _self_install_toolchain_python() { :; }
    _self_install_toolchain_deps() { :; }
    _self_install_project_guide() { :; }

    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "self install ships every lib/ subtree pyve.sh sources" {
    run self_install
    [ "$status" -eq 0 ]

    # The two subtrees v3.0.6 dropped.
    [ -f "$TARGET_BIN_DIR/lib/ui/core.sh" ]
    [ -f "$TARGET_BIN_DIR/lib/plugins/contract.sh" ]
    [ -f "$TARGET_BIN_DIR/lib/plugins/python/plugin.sh" ]
    [ -f "$TARGET_BIN_DIR/lib/plugins/node/plugin.sh" ]

    # The subtrees it already copied stay present.
    [ -f "$TARGET_BIN_DIR/lib/utils.sh" ]
    [ -f "$TARGET_BIN_DIR/lib/commands/self.sh" ]
}

@test "the installed binary starts (sources cleanly), not just exists" {
    run self_install
    [ "$status" -eq 0 ]

    # Reproduce the field symptom: run the INSTALLED pyve.sh. With the
    # bug it dies sourcing lib/ui/core.sh; fixed, it prints its version.
    run bash "$TARGET_SCRIPT_PATH" --version
    [ "$status" -eq 0 ]
    [[ "$output" != *"No such file or directory"* ]]
    [[ "$output" != *"unbound variable"* ]]
}

@test "self install does not copy stale __pycache__ bytecode" {
    run self_install
    [ "$status" -eq 0 ]
    run find "$TARGET_BIN_DIR/lib" -type d -name __pycache__
    [ -z "$output" ]
}
