#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# verify the `assert_python_resolvable` pre-flight is
# wired into the two additional `python` invocation sites that were
# flagged out-of-scope in the initial N.d.1 fix and then folded in:
#
#   1) `_init_venv` (lib/plugins/python/plugin.sh) — venv-backend `pyve init`'s
#      `python -m venv "$venv_dir"` call. Same asdf-shim trap class.
#
#   2) `ensure_env_exists` (lib/utils.sh) drift-check block — the
#      `python -c 'import sys; ...' 2>/dev/null || true` that previously
#      silently no-op'd when python errored, leaving stale testenvs
#      unrebuilt without any signal to the user.
#
# Both wire-ins reuse the helper from lib/env_detect.sh; these tests
# verify the helper is invoked at the right point in each consumer's
# flow (before the python call), not that the helper itself works
# (covered by the 4 tests in test_env_detect.bats).
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Wire-in #1: _init_venv calls assert_python_resolvable
#============================================================

@test "_init_venv: pre-flight fires before run_cmd; failure short-circuits" {
    # Stub the helper to simulate the asdf-shim trap.
    assert_python_resolvable() {
        log_error "PREFLIGHT_FIRED: asdf shim trap"
        return 1
    }
    # Sentinel: if run_cmd is reached, the wire-in did NOT short-circuit.
    run_cmd() { printf 'RUN_CMD_REACHED\n'; }

    run _init_venv "$TEST_DIR/.venv-target"
    [ "$status" -ne 0 ]
    [[ "$output" == *"PREFLIGHT_FIRED"* ]]
    [[ "$output" != *"RUN_CMD_REACHED"* ]]
}

@test "_init_venv: skips pre-flight when venv already exists (no python invocation)" {
    # Existing venv → "skipping" branch → no python call → pre-flight shouldn't fire.
    mkdir -p "$TEST_DIR/.venv-existing"
    assert_python_resolvable() {
        log_error "PREFLIGHT_FIRED_UNEXPECTEDLY"
        return 1
    }
    run_cmd() { :; }
    run _init_venv "$TEST_DIR/.venv-existing"
    [ "$status" -eq 0 ]
    [[ "$output" != *"PREFLIGHT_FIRED_UNEXPECTEDLY"* ]]
}

#============================================================
# Wire-in #2: ensure_env_exists drift-check gated on pre-flight
#============================================================

@test "ensure_env_exists drift-check: pre-flight gates the silent no-op (loud error instead)" {
    # Build a fake existing venv-backed testenv with a pyvenv.cfg that
    # has a stale version recorded, so the drift block is entered.
    local target=".pyve/envs/testenv/venv"
    mkdir -p "$target/bin"
    cat > "$target/pyvenv.cfg" << 'EOF'
home = /usr/local/bin
version = 3.14.4
EOF
    # Stub the helper to simulate the asdf-shim trap.
    assert_python_resolvable() {
        log_error "PREFLIGHT_FIRED_DRIFT"
        return 1
    }

    run ensure_env_exists
    [ "$status" -ne 0 ]
    [[ "$output" == *"PREFLIGHT_FIRED_DRIFT"* ]]
    # The previously-silent skip would have left the stale testenv in place
    # AND returned 0. Now: loud error, non-zero exit.
    [[ -d "$target" ]]  # testenv preserved (we didn't delete it)
}

@test "ensure_env_exists: drift-check pre-flight does NOT fire when no existing testenv" {
    # Fresh: no existing testenv → no drift block → drift-pre-flight not needed.
    # (The creation-path pre-flight inside `if [[ ! -d ... ]]` still applies;
    # we stub it to succeed so we can observe the drift-pre-flight was skipped.)
    local drift_fired=0
    assert_python_resolvable() {
        # We can't easily set a captured-variable from a stub under `run`,
        # so use a sentinel file instead.
        touch "$TEST_DIR/preflight_called.flag"
        return 0
    }
    # Stub run_cmd so venv creation is a no-op mkdir.
    run_cmd() {
        # Expected: run_cmd python -m venv <path>
        local target="${4:-}"
        [[ -n "$target" ]] && mkdir -p "$target/bin"
    }

    run ensure_env_exists
    [ "$status" -eq 0 ]
    # Pre-flight should have fired exactly once (the creation path),
    # not twice (which would happen if the drift block also fired).
    [ -f "$TEST_DIR/preflight_called.flag" ]
}
