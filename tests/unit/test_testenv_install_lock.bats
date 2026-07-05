#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the per-env install lock (Story M.j).
#
# The lock lives at `.pyve/envs/<name>/.lock/` (an atomic mkdir
# directory). A `pid` file inside identifies the holder. Acquire is
# wait-by-default with a 1-second sleep+retry; `--no-wait` exits
# non-zero with a "(pid N)" message on collision. Release is via
# `rm -rf` of the lock dir, and only releases when the caller is the
# recorded holder.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Pre-create a fake testenv venv so env_install passes its
# existence guard without invoking real python.
_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    cat > ".pyve/envs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/$name/venv/bin/python"
}

# Stub run_cmd so install does not actually invoke pip.
_stub_run_cmd_records() {
    run_cmd() {
        printf 'RUN_CMD:%s\n' "$*"
    }
}

# Pre-create a foreign lock for <name> claiming to be held by <pid>.
_seed_foreign_lock() {
    local name="$1" holder_pid="$2"
    mkdir -p ".pyve/envs/$name/.lock"
    printf '%s\n' "$holder_pid" > ".pyve/envs/$name/.lock/pid"
}

# A pid that is overwhelmingly unlikely to exist on the test host.
_dead_pid() {
    printf '%s' 999999
}

# ============================================================
# Helper-level: acquire / release contract
# ============================================================

@test "acquire_install_lock: creates .pyve/envs/<name>/.lock dir with pid file" {
    mkdir -p ".pyve/envs/testenv"
    run _env_acquire_install_lock testenv
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/testenv/.lock" ]
    [ -f ".pyve/envs/testenv/.lock/pid" ]
    # pid file contains a positive integer (run's subshell pid, so we
    # just assert non-empty digits rather than $$ — `run` forks).
    local recorded
    recorded="$(cat ".pyve/envs/testenv/.lock/pid")"
    [[ "$recorded" =~ ^[0-9]+$ ]]
}

@test "release_install_lock: removes the lock dir when the caller is the holder" {
    mkdir -p ".pyve/envs/testenv"
    # Acquire in this shell so the recorded pid is $$, then release.
    _env_acquire_install_lock testenv
    [ -d ".pyve/envs/testenv/.lock" ]
    _env_release_install_lock testenv
    [ ! -d ".pyve/envs/testenv/.lock" ]
}

@test "release_install_lock: leaves a foreign lock alone" {
    _seed_foreign_lock testenv "$(_dead_pid)"
    _env_release_install_lock testenv
    # Foreign lock survives — the release is a no-op when we are not
    # the holder.
    [ -d ".pyve/envs/testenv/.lock" ]
    [ "$(cat .pyve/envs/testenv/.lock/pid)" = "$(_dead_pid)" ]
}

@test "acquire_install_lock: --no-wait collision exits non-zero with '(pid N)' message" {
    # Seed a foreign lock held by a *live* pid (our own shell) so the
    # stale-reclaim path does not kick in.
    _seed_foreign_lock testenv "$$"
    run _env_acquire_install_lock testenv no-wait
    [ "$status" -ne 0 ]
    [[ "$output" == *"(pid $$)"* ]]
    [[ "$output" == *"another pyve process"* ]]
    # Foreign lock untouched.
    [ -d ".pyve/envs/testenv/.lock" ]
    [ "$(cat .pyve/envs/testenv/.lock/pid)" = "$$" ]
}

@test "acquire_install_lock: reclaims a stale lock whose holder pid no longer exists" {
    _seed_foreign_lock testenv "$(_dead_pid)"
    run _env_acquire_install_lock testenv no-wait
    [ "$status" -eq 0 ]
    # Lock dir now exists with the new holder's pid (run's subshell).
    [ -d ".pyve/envs/testenv/.lock" ]
    local recorded
    recorded="$(cat ".pyve/envs/testenv/.lock/pid")"
    [[ "$recorded" =~ ^[0-9]+$ ]]
    [ "$recorded" != "$(_dead_pid)" ]
}

# ============================================================
# Integration: lock surrounds env_install via the dispatcher
# ============================================================

@test "testenv install: lock dir is removed after a successful install" {
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/envs/testenv/.lock" ]
}

@test "testenv install: lock dir is removed after a failed install (bad -r path)" {
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install -r does-not-exist.txt
    [ "$status" -ne 0 ]
    # The trap in the dispatcher must clean the lock dir even on the
    # error exit.
    [ ! -d ".pyve/envs/testenv/.lock" ]
}

@test "testenv install --no-wait: pre-existing live lock fast-fails with (pid N) message" {
    _make_fake_named_venv testenv
    _seed_foreign_lock testenv "$$"
    _stub_run_cmd_records
    run env_command install --no-wait
    [ "$status" -ne 0 ]
    [[ "$output" == *"(pid $$)"* ]]
    # The foreign lock dir survives the failed acquire — release must
    # not blow away a lock we never owned.
    [ -d ".pyve/envs/testenv/.lock" ]
    [ "$(cat .pyve/envs/testenv/.lock/pid)" = "$$" ]
}

@test "testenv install --no-wait: no pre-existing lock succeeds" {
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install --no-wait
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/envs/testenv/.lock" ]
}

# ============================================================
# Help text
# ============================================================

@test "testenv --help: documents --no-wait under install" {
    run env_command --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-wait"* ]]
}
