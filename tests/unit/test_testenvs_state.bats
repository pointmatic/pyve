#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `.state` helpers in lib/envs.sh (Story M.h.1).
#
# Schema (plain key=value, sourceable):
#   backend=venv|micromamba|inherit
#   manifest=<relative path or empty>
#   manifest_sha256=<64-hex or empty>
#   provisioned_at=<unix epoch seconds>
#   last_used_at=<unix epoch seconds or 0>
#
# `.state` lives at .pyve/testenvs/<name>/.state
#
# Surface under test:
#   state_path <name>
#   state_write <name> <backend> [manifest=...] [manifest_sha256=...] [provisioned_at=...] [last_used_at=...]
#   state_read  <name>      → populates PYVE_TESTENV_STATE_{BACKEND,MANIFEST,MANIFEST_SHA256,PROVISIONED_AT,LAST_USED_AT}
#   state_touch_last_used <name>

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    # See test_testenvs.bats: capture an absolute python path before cwd
    # changes — the asdf shim can't resolve a relative .pyve/testenv/...
    # entry once we leave PYVE_ROOT.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# Clear state variables between assertions in a single test so a stale
# read doesn't masquerade as success.
_clear_state_vars() {
    unset PYVE_TESTENV_STATE_BACKEND
    unset PYVE_TESTENV_STATE_MANIFEST
    unset PYVE_TESTENV_STATE_MANIFEST_SHA256
    unset PYVE_TESTENV_STATE_PROVISIONED_AT
    unset PYVE_TESTENV_STATE_LAST_USED_AT
}

# ============================================================
# state_path
# ============================================================

@test "state_path: prints .pyve/testenvs/<name>/.state" {
    [ "$(state_path testenv)" = ".pyve/testenvs/testenv/.state" ]
    [ "$(state_path hardware)" = ".pyve/testenvs/hardware/.state" ]
}

# ============================================================
# state_write — round-trip with full and minimal arg sets
# ============================================================

@test "state_write: full keyword arg set writes all five fields" {
    state_write hardware micromamba \
        manifest=tests/env.yml \
        manifest_sha256=abc123 \
        provisioned_at=1700000000 \
        last_used_at=1700000500
    [ -f ".pyve/testenvs/hardware/.state" ]
    grep -q "^backend=micromamba$"          ".pyve/testenvs/hardware/.state"
    grep -q "^manifest=tests/env.yml$"      ".pyve/testenvs/hardware/.state"
    grep -q "^manifest_sha256=abc123$"      ".pyve/testenvs/hardware/.state"
    grep -q "^provisioned_at=1700000000$"   ".pyve/testenvs/hardware/.state"
    grep -q "^last_used_at=1700000500$"     ".pyve/testenvs/hardware/.state"
}

@test "state_write: minimal arg set defaults manifest='', sha='', last_used_at=0, provisioned_at=now" {
    local before; before=$(date +%s)
    state_write testenv venv
    local after; after=$(date +%s)
    [ -f ".pyve/testenvs/testenv/.state" ]
    grep -q "^backend=venv$"             ".pyve/testenvs/testenv/.state"
    grep -q "^manifest=$"                ".pyve/testenvs/testenv/.state"
    grep -q "^manifest_sha256=$"         ".pyve/testenvs/testenv/.state"
    grep -q "^last_used_at=0$"           ".pyve/testenvs/testenv/.state"
    # provisioned_at lies in [before, after].
    local pa
    pa=$(grep '^provisioned_at=' ".pyve/testenvs/testenv/.state" | cut -d= -f2)
    [ "$pa" -ge "$before" ]
    [ "$pa" -le "$after" ]
}

@test "state_write: overwrites an existing .state (no merge)" {
    state_write testenv venv manifest=old.txt last_used_at=42
    state_write testenv venv manifest=new.txt
    grep -q "^manifest=new.txt$" ".pyve/testenvs/testenv/.state"
    # last_used_at reverts to default 0 because state_write overwrites.
    grep -q "^last_used_at=0$"   ".pyve/testenvs/testenv/.state"
}

@test "state_write: unknown keyword arg hard-errors" {
    run state_write testenv venv bogus=bad
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
}

@test "state_write: missing required <backend> hard-errors" {
    run state_write testenv
    [ "$status" -ne 0 ]
}

# ============================================================
# state_read — populates the documented PYVE_TESTENV_STATE_* vars
# ============================================================

@test "state_read: populates all five PYVE_TESTENV_STATE_* vars" {
    state_write hardware micromamba \
        manifest=env.yml manifest_sha256=deadbeef \
        provisioned_at=1700000000 last_used_at=1700000500
    _clear_state_vars
    state_read hardware
    [ "$PYVE_TESTENV_STATE_BACKEND"         = "micromamba" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST"        = "env.yml" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST_SHA256" = "deadbeef" ]
    [ "$PYVE_TESTENV_STATE_PROVISIONED_AT"  = "1700000000" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT"    = "1700000500" ]
}

@test "state_read: missing .state returns non-zero (clean failure, no shell crash)" {
    _clear_state_vars
    run state_read nonexistent_env
    [ "$status" -ne 0 ]
}

# ============================================================
# state_touch_last_used — updates only last_used_at; preserves others
# ============================================================

@test "state_touch_last_used: updates last_used_at to current epoch; preserves other fields" {
    state_write testenv venv \
        manifest=req.txt manifest_sha256=cafe \
        provisioned_at=1700000000 last_used_at=0
    local before; before=$(date +%s)
    state_touch_last_used testenv
    local after; after=$(date +%s)

    _clear_state_vars
    state_read testenv
    [ "$PYVE_TESTENV_STATE_BACKEND"         = "venv" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST"        = "req.txt" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST_SHA256" = "cafe" ]
    [ "$PYVE_TESTENV_STATE_PROVISIONED_AT"  = "1700000000" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT"    -ge "$before" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT"    -le "$after" ]
}

@test "state_touch_last_used: missing .state returns non-zero" {
    run state_touch_last_used nonexistent_env
    [ "$status" -ne 0 ]
}

# ============================================================
# bash-3.2 set -u safety (project-essentials empty-array rule applies)
# ============================================================

@test "no 'unbound variable' under 'set -euo pipefail' for the .state surface" {
    output="$(/bin/bash -c "
        set -euo pipefail
        export PYVE_ROOT='$PYVE_ROOT'
        export PYVE_PYTHON='$PYVE_PYTHON'
        source '$PYVE_ROOT/lib/envs.sh'
        cd '$TEST_DIR'
        state_path testenv >/dev/null
        state_write testenv venv >/dev/null
        state_read testenv >/dev/null
        state_touch_last_used testenv >/dev/null
    " 2>&1)" || true
    [[ "$output" != *"unbound variable"* ]] || {
        echo "stderr contained 'unbound variable':"
        echo "$output"
        false
    }
}
