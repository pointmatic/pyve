#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story N.bf.17 — `pyve test` / `env init` must not leave
# `.pyve` strays when env provisioning fails the Python-resolvability gate,
# and `purge`'s fallback removal must not mislabel non-conda dirs.
#
# Bug: ensure_env_exists ran `mkdir -p .pyve/envs/<name>` BEFORE
# assert_python_resolvable, so a failed `pyve test` on an uninitialized /
# non-activated project materialized `.pyve/envs/<name>/` (empty) — which a
# later `pyve purge` then "found" and removed, reporting success as though a
# real project had been torn down.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    create_test_dir
    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# ============================================================
# ensure_env_exists: gate before materialization
# ============================================================

@test "ensure_env_exists: unresolvable python leaves NO .pyve stray (venv)" {
    # Simulate the asdf/pyenv shim trap on an uninitialized project.
    assert_python_resolvable() { return 1; }
    run ensure_env_exists testenv
    [ "$status" -ne 0 ]
    # Nothing must be materialized when the gate fails.
    [ ! -e ".pyve/envs/testenv" ]
    [ ! -e ".pyve" ]
}

@test "ensure_env_exists: resolvable python still materializes the venv testenv" {
    assert_python_resolvable() { return 0; }
    # Stub `python -m venv <path>` (run_cmd python -m venv <path> → $4 = path).
    run_cmd() {
        local target="${4:-}"
        if [[ -n "$target" ]]; then
            mkdir -p "$target/bin"
            : > "$target/bin/python"
            : > "$target/pyvenv.cfg"
        fi
    }
    run ensure_env_exists testenv
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/testenv/venv" ]
    [ -f ".pyve/envs/testenv/.state" ]
}

# ============================================================
# purge fallback: no mislabeling of non-conda envs
# ============================================================

@test "_purge_pyve_dir: does not call a venv testenv a 'micromamba environment'" {
    # A venv testenv (no conda-meta), no .pyve/config → the fallback loop.
    mkdir -p .pyve/envs/testenv/venv/bin
    : > .pyve/envs/testenv/venv/pyvenv.cfg

    # Micromamba "present" but record any invocation.
    local calls="$TEST_DIR/mm_calls"
    get_micromamba_path() { printf '%s' "$TEST_DIR/fakemm"; }
    cat > "$TEST_DIR/fakemm" <<SH
#!/usr/bin/env bash
echo "\$@" >> "$calls"
exit 0
SH
    chmod +x "$TEST_DIR/fakemm"

    run _purge_pyve_dir
    [ "$status" -eq 0 ]
    # The venv testenv must NOT be announced/removed as a micromamba env.
    [[ "$output" != *"micromamba environment at '.pyve/envs/testenv'"* ]]
    if [[ -f "$calls" ]]; then
        ! grep -q "envs/testenv" "$calls"
    fi
}

@test "_purge_pyve_dir: still deregisters a real conda env in the fallback loop" {
    # A conda-shaped env (v3 nested conda-meta), no .pyve/config.
    mkdir -p .pyve/envs/sci/conda/conda-meta
    : > .pyve/envs/sci/conda/conda-meta/history

    local calls="$TEST_DIR/mm_calls"
    get_micromamba_path() { printf '%s' "$TEST_DIR/fakemm"; }
    cat > "$TEST_DIR/fakemm" <<SH
#!/usr/bin/env bash
echo "\$@" >> "$calls"
exit 0
SH
    chmod +x "$TEST_DIR/fakemm"

    run _purge_pyve_dir
    [ "$status" -eq 0 ]
    # The real conda prefix is deregistered via micromamba.
    grep -q "envs/sci/conda" "$calls"
}
