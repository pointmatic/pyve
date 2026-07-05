#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# `pyve self provision --status` — machine-readable hosting-readiness query,
# plus the dispatcher hardening that closes the silent-re-provision trap.
#
# Two contracts under test:
#   1. Dispatcher: an unrecognized `pyve self provision <flag>` is a HARD
#      ERROR (exit non-zero) and NEVER provisions. The bare `provision`
#      (no args) is the ONLY form that provisions.
#   2. `--status [--json]`: read-only, side-effect-free, runnability-probed
#      (executes `python --version` / `project-guide --version`, not `[[ -x ]]`).
#      Exit-code contract: 0 ready / 1 managed-but-not-ready / 2 not-managed.
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
    export DEFAULT_PYTHON_VERSION="3.14.5"
    mkdir -p "$HOME"
    unset PYVE_PYTHON PYVE_PROJECT_GUIDE_BIN
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# ---- fixtures: hosted toolchain python ----
_host_python_runnable() {
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"; mkdir -p "$bin"
    printf '#!/bin/sh\necho "Python 3.14.5"\n' > "$bin/python"; chmod +x "$bin/python"
}
# provisioned (-x true) but NOT runnable: a dead-shebang interpreter.
_host_python_broken() {
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"; mkdir -p "$bin"
    printf '#!/nonexistent/interp\n' > "$bin/python"; chmod +x "$bin/python"
}

# ---- fixtures: hosted project-guide shim ----
_host_pg_runnable() {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho "project-guide 2.15.0"\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
}
_host_pg_broken() {
    mkdir -p "$HOME/.local/bin"
    printf '#!/nonexistent/interp\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
}

#============================================================
# 1. Dispatcher hardening — unknown flag never provisions
#============================================================

# These exercise the real CLI (unknown_flag_error lives in pyve.sh): an
# unrecognized flag must hard-error and NEVER reach self_provision. The
# isolated HOME/XDG_DATA_HOME mean a regression (fall-through to provision)
# would be observable as a created toolchain tree.
@test "dispatcher: 'self provision --bogus' is a hard error (non-zero)" {
    run bash "$PYVE_ROOT/pyve.sh" self provision --bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not accept '--bogus'"* ]]
}

@test "dispatcher: 'self provision --bogus' creates NO toolchain (provision-free)" {
    run bash "$PYVE_ROOT/pyve.sh" self provision --bogus
    [ "$status" -ne 0 ]
    [ ! -d "$(pyve_toolchain_root)" ]
}

@test "dispatcher: 'self provision --stats' (typo) hard-errors with a hint, no fall-through" {
    run bash "$PYVE_ROOT/pyve.sh" self provision --stats
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not accept"* ]]
    [[ "$output" == *"--status"* ]]
    [ ! -d "$(pyve_toolchain_root)" ]
}

@test "dispatcher: bare 'self provision' still routes to self_provision" {
    export PYVE_DISPATCH_TRACE=1
    run self_command provision
    assert_status_equals 0
    [[ "$output" == *"DISPATCH:self-provision"* ]]
}

@test "dispatcher: 'self provision --help' shows help (no provisioning)" {
    run self_command provision --help
    assert_status_equals 0
    [[ "$output" == *"pyve self provision"* ]]
    [ ! -d "$(pyve_toolchain_root)" ]
}

#============================================================
# 2. --status exit-code contract (runnability, not existence)
#============================================================

@test "status: ready (toolchain + pg both runnable) → exit 0" {
    _host_python_runnable
    _host_pg_runnable
    run self_command provision --status
    assert_status_equals 0
    [[ "$output" == *"ready"* ]]
}

@test "status: never provisioned → exit 1, and stays provision-free" {
    run self_command provision --status
    assert_status_equals 1
    [ ! -d "$(pyve_toolchain_root)" ]
}

@test "status: provisioned-but-broken (dead-shebang) → exit 1 (existence != runnable)" {
    _host_python_broken
    _host_pg_broken
    run self_command provision --status
    assert_status_equals 1
    [[ "$output" == *"not ready"* ]]
}

@test "status: project-managed (pip dep) → exit 2 (not Pyve-managed here)" {
    printf 'project-guide\n' > requirements.txt
    run self_command provision --status
    assert_status_equals 2
    [[ "$output" == *"your project"* ]]
}

@test "status: toolchain runnable but pg hosted-yet-broken → exit 1" {
    _host_python_runnable
    _host_pg_broken
    run self_command provision --status
    assert_status_equals 1
}

#============================================================
# 3. --json payload
#============================================================

@test "status --json: ready emits the documented shape, all-true" {
    _host_python_runnable
    _host_pg_runnable
    run self_command provision --status --json
    assert_status_equals 0
    [[ "$output" == *'"pyve_managed":true'* ]]
    [[ "$output" == *'"toolchain":'* ]]
    [[ "$output" == *'"runnable":true'* ]]
    [[ "$output" == *'"project_guide":'* ]]
    [[ "$output" == *'"version":"3.14.5"'* ]]
    [[ "$output" == *'"version":"2.15.0"'* ]]
}

@test "status --json: provisioned-but-broken reports provisioned:true, runnable:false" {
    _host_python_broken
    run self_command provision --status --json
    assert_status_equals 1
    [[ "$output" == *'"provisioned":true'* ]]
    [[ "$output" == *'"runnable":false'* ]]
}

@test "status --json: project-managed reports pyve_managed:false" {
    printf 'project-guide\n' > requirements.txt
    run self_command provision --status --json
    assert_status_equals 2
    [[ "$output" == *'"pyve_managed":false'* ]]
}

@test "status: probe fires (executes the artifact), not a stat" {
    # A dead-shebang interpreter passes [[ -x ]] but fails to exec. If the
    # status leaf stat-ed instead of probing, this would read "runnable".
    _host_python_broken
    _host_pg_runnable
    run self_command provision --status --json
    [[ "$output" == *'"toolchain":{"provisioned":true,"runnable":false'* ]]
}

#============================================================
# 4. Override seams honored
#============================================================

@test "status: PYVE_PROJECT_GUIDE_BIN override is honored as the pg artifact" {
    _host_python_runnable
    local stub="$TEST_DIR/pg-override"
    printf '#!/bin/sh\necho "project-guide 9.9.9"\n' > "$stub"; chmod +x "$stub"
    export PYVE_PROJECT_GUIDE_BIN="$stub"
    run self_command provision --status --json
    assert_status_equals 0
    [[ "$output" == *'"version":"9.9.9"'* ]]
}

@test "status: a bare-PATH project-guide is NOT counted as hosted/runnable" {
    # The readiness contract is about Pyve's HOSTED project-guide; a bare
    # `project-guide` on PATH (the asdf-shim trap) must not read as ready.
    _host_python_runnable
    local fakebin="$TEST_DIR/pathbin"; mkdir -p "$fakebin"
    printf '#!/bin/sh\necho "project-guide 1.2.3"\n' > "$fakebin/project-guide"
    chmod +x "$fakebin/project-guide"
    PATH="$fakebin:$PATH" run self_command provision --status --json
    assert_status_equals 1
    [[ "$output" == *'"project_guide":{"hosted":false,"runnable":false'* ]]
}

@test "status: side-effect-free — repeated calls never create state" {
    _host_python_runnable
    _host_pg_runnable
    run self_command provision --status
    run self_command provision --status
    assert_status_equals 0
    [ ! -e "$TEST_DIR/pip-args" ]
}
