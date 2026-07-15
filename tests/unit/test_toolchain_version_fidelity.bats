#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Toolchain version fidelity + bounded runnability probes.
#
# The toolchain slot is version-keyed (`toolchain/<DEFAULT_PYTHON_VERSION>/venv`),
# so the key is a promise about the contents. Three defects broke that promise:
#
#   1. `pyve_runnable_version` executed the artifact with no time bound, so a
#      wedged interpreter hung `pyve check` indefinitely.
#   2. The hosting report printed the DEFAULT_PYTHON_VERSION *constant* rather
#      than the version it actually probed — reporting a value it never verified.
#   3. `pyve_toolchain_python_ensure` accepted the slot on existence alone, so a
#      venv built from a fallback interpreter (right slot, wrong Python) was
#      never rebuilt, silently coupling the toolchain to the developer's
#      version manager.
#
# The invariant under test: a slot named <V> holds Python <V>, or it is rebuilt.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"

    TEST_DIR="$(mktemp -d)"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    unset PYVE_PROBE_TIMEOUT
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# A fake toolchain venv python that reports $1 as its version.
_make_venv_python_reporting() {
    local ver="$1" bin
    bin="$(pyve_toolchain_venv_dir)/bin"
    mkdir -p "$bin"
    printf '#!/bin/sh\necho "Python %s"\n' "$ver" > "$bin/python"
    chmod +x "$bin/python"
}

# A standalone fake interpreter at $1 reporting version $2.
_make_python_at() {
    local path="$1" ver="$2"
    mkdir -p "$(dirname "$path")"
    printf '#!/bin/sh\necho "Python %s"\n' "$ver" > "$path"
    chmod +x "$path"
}

# A binary that never returns — the wedged-interpreter case.
_make_hanging_bin() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    # `exec` so the script IS the sleep — killing the pid kills it outright and
    # cannot orphan a child that keeps bats's output pipe open.
    printf '#!/bin/sh\nexec sleep 300\n' > "$path"
    chmod +x "$path"
}

# Run a command under an OUTER watchdog so a missing-timeout regression FAILS
# the test instead of hanging the whole suite. Exit 137 => the watchdog had to
# kill it (i.e. the probe never bounded itself).
#
# The timer sleep runs in its own background under a TERM trap so dismissing the
# watchdog reaps it too — a bare `sleep && kill` would strand an orphan sleep
# for the full limit, the leak that fed the macOS CI fork-pressure flake.
_bounded() {
    local secs="$1"; shift
    "$@" & local pid=$!
    (
        sleep "$secs" &
        timer=$!
        trap 'kill "$timer" 2>/dev/null || true; exit 0' TERM
        wait "$timer" && kill -9 "$pid" 2>/dev/null
    ) >/dev/null 2>&1 & local watchdog=$!
    local rc=0
    wait "$pid" 2>/dev/null || rc=$?
    kill "$watchdog" >/dev/null 2>&1 || true
    return "$rc"
}

#------------------------------------------------------------
# 1. Bounded probe — a wedged binary must not hang the probe
#------------------------------------------------------------

@test "pyve_runnable_version: a hanging binary times out (124) instead of blocking forever" {
    _make_hanging_bin "$TEST_DIR/hangs"
    export PYVE_PROBE_TIMEOUT=1

    # Outer watchdog at 15s: if the probe self-bounds we get 124 in ~1s; if it
    # regresses to an unbounded wait the watchdog kills it and we see 137.
    # Capture the status with `|| rc=$?` — a bare call returning non-zero would
    # abort the test under bats before the assertions below could run.
    local rc=0
    _bounded 15 pyve_runnable_version "$TEST_DIR/hangs" || rc=$?

    [ "$rc" -ne 137 ]   # 137 => never bounded itself (the bug)
    [ "$rc" -eq 124 ]   # 124 => probe timed out, as designed
}

@test "pyve_runnable_version: timeout is distinct from a plain failure" {
    # A binary that exits non-zero fast is a FAILURE (1), not a timeout (124).
    printf '#!/bin/sh\nexit 3\n' > "$TEST_DIR/broken"
    chmod +x "$TEST_DIR/broken"
    export PYVE_PROBE_TIMEOUT=1

    run pyve_runnable_version "$TEST_DIR/broken"
    assert_status_equals 1
}

@test "pyve_runnable_version: a healthy binary still returns its version fast" {
    _make_python_at "$TEST_DIR/good" "3.14.4"
    export PYVE_PROBE_TIMEOUT=5

    run pyve_runnable_version "$TEST_DIR/good"
    assert_status_equals 0
    assert_output_equals "3.14.4"
}

#------------------------------------------------------------
# 2. Version fidelity — the slot's name is a promise
#------------------------------------------------------------

@test "_pyve_toolchain_venv_is_current: true when the slot holds DEFAULT_PYTHON_VERSION" {
    _make_venv_python_reporting "3.14.4"
    run _pyve_toolchain_venv_is_current "$(pyve_toolchain_venv_dir)"
    assert_status_equals 0
}

@test "_pyve_toolchain_venv_is_current: FALSE when the slot holds a different Python" {
    # The field bug: toolchain/3.14.4/venv actually containing 3.12.13.
    _make_venv_python_reporting "3.12.13"
    run _pyve_toolchain_venv_is_current "$(pyve_toolchain_venv_dir)"
    [ "$status" -ne 0 ]
}

@test "_pyve_toolchain_venv_is_current: false when the interpreter cannot run" {
    local bin
    bin="$(pyve_toolchain_venv_dir)/bin"
    mkdir -p "$bin"
    printf '#!/bin/sh\nexit 1\n' > "$bin/python"
    chmod +x "$bin/python"
    run _pyve_toolchain_venv_is_current "$(pyve_toolchain_venv_dir)"
    [ "$status" -ne 0 ]
}

@test "pyve_toolchain_python_ensure: REBUILDS a slot whose Python is the wrong version" {
    _make_venv_python_reporting "3.12.13"   # right slot, wrong Python

    # Record whether the builder was invoked.
    _pyve_toolchain_build() { printf 'BUILD_CALLED\n' >> "$TEST_DIR/build.log"; return 0; }

    run pyve_toolchain_python_ensure
    assert_status_equals 0
    assert_file_contains "$TEST_DIR/build.log" "BUILD_CALLED"
}

@test "pyve_toolchain_python_ensure: does NOT rebuild a slot that already holds the right Python" {
    _make_venv_python_reporting "3.14.4"

    _pyve_toolchain_build() { printf 'BUILD_CALLED\n' >> "$TEST_DIR/build.log"; return 0; }

    run pyve_toolchain_python_ensure
    assert_status_equals 0
    [ ! -f "$TEST_DIR/build.log" ]
}

#------------------------------------------------------------
# 3. Strict bootstrap — never silently borrow a mismatched PATH python
#------------------------------------------------------------

@test "_pyve_toolchain_bootstrap_python: uses the version manager's EXACT interpreter" {
    _make_python_at "$TEST_DIR/vm/3.14.4/bin/python" "3.14.4"
    _pyve_toolchain_versioned_python() { printf '%s' "$TEST_DIR/vm/3.14.4/bin/python"; }

    run _pyve_toolchain_bootstrap_python "3.14.4"
    assert_status_equals 0
    assert_output_equals "$TEST_DIR/vm/3.14.4/bin/python"
}

@test "_pyve_toolchain_bootstrap_python: STRICT — refuses to fall back to a mismatched PATH python" {
    # No exact-version interpreter available...
    _pyve_toolchain_versioned_python() { printf ''; }
    # ...but a (wrong-version) python3 IS on PATH. Strict policy: do NOT use it,
    # because building toolchain/3.14.4/venv from 3.12.13 is the original bug.
    _make_python_at "$TEST_DIR/pathbin/python3" "3.12.13"
    PATH="$TEST_DIR/pathbin:$PATH"

    run _pyve_toolchain_bootstrap_python "3.14.4"
    [ "$status" -ne 0 ]
    # It must not print the mismatched interpreter.
    [[ "$output" != *"pathbin"* ]]
}

#------------------------------------------------------------
# 4. Truthful reporting — never print a version we did not probe
#------------------------------------------------------------

# The hosting report only needs the toolchain probe; stub the project-guide
# side out so these tests isolate the version-reporting behavior.
_stub_pg_absent() {
    pyve_project_guide_is_hosted() { return 1; }
    project_guide_deps_source() { printf ''; }
}

@test "check hosting: reports the PROBED version, not the DEFAULT_PYTHON_VERSION constant" {
    source "$PYVE_ROOT/lib/check_composer.sh"
    # The field state: a slot named 3.14.4 that actually holds 3.12.13.
    pyve_toolchain_runnable() { printf '3.12.13'; return 0; }
    _stub_pg_absent

    run _compose_check_pyve_hosting
    assert_output_contains "3.12.13"
    [[ "$output" != *"provisioned (3.14.4)"* ]]   # must not assert the unprobed constant
}

@test "check hosting: warns on version drift and names the repair" {
    source "$PYVE_ROOT/lib/check_composer.sh"
    pyve_toolchain_runnable() { printf '3.12.13'; return 0; }
    _stub_pg_absent

    run _compose_check_pyve_hosting
    assert_output_contains "drift"
    assert_output_contains "pyve self provision"
}

@test "check hosting: no drift warning when the slot holds the pinned version" {
    source "$PYVE_ROOT/lib/check_composer.sh"
    pyve_toolchain_runnable() { printf '3.14.4'; return 0; }
    _stub_pg_absent

    run _compose_check_pyve_hosting
    assert_output_contains "provisioned (3.14.4)"
    [[ "$output" != *"drift"* ]]
}

@test "check hosting: a timed-out probe reports 'cannot verify', not 'not provisioned'" {
    source "$PYVE_ROOT/lib/check_composer.sh"
    pyve_toolchain_runnable() { return 124; }
    _stub_pg_absent

    run _compose_check_pyve_hosting
    assert_output_contains "timed out"
    [[ "$output" != *"not provisioned (falls back"* ]]
}
