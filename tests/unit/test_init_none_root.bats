#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve init` on a project whose `pyve.toml` declares an advisory root
# backend (`[env.root] backend = "none"`) must not crash. `none` declares
# a runtime-less / non-Python root — pyve does not materialize it yet, so
# init skips the root env (emitting the same "does not yet materialize"
# note the per-env install path uses) and completes, leaving the project's
# declaration + direnv wiring + named concrete-backend envs intact.
#
# Two gates rejected `none` before this: the plugin's env-block validation
# (`bp_lookup` knows no `none` backend) and `init`'s `validate_backend`
# (closed venv|micromamba|auto set). Both now let an *advisory* backend
# through while a genuinely-unknown one (`bogus`) still hard-errors.
#
# Black-box: drives `bash pyve.sh init` non-interactively, offline.

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_BIN="$PYVE_ROOT/pyve.sh"
    # manifest_load shells out to the Python helper — capture a working
    # interpreter before cd'ing into the unpinned tmp dir.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Non-interactive + offline: suppress every prompt and all project-guide
    # network/hosting work so the run is hermetic and fast.
    export PYVE_INIT_NONINTERACTIVE=1
    export PYVE_NO_PROJECT_GUIDE=1
    export PYVE_NO_PROJECT_GUIDE_COMPLETION=1
    export NO_COLOR=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_none_root_manifest() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "noneroot-demo"

[env.root]
purpose = "utility"
backend = "none"

[env.testenv]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
TOML
}

@test "init on a none-root project completes (exit 0) instead of crashing" {
    _none_root_manifest
    run bash "$PYVE_BIN" init
    [ "$status" -eq 0 ]
}

@test "init on a none-root project skips the root env (no .venv materialized)" {
    _none_root_manifest
    run bash "$PYVE_BIN" init
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_DIR/.venv" ]
    [ ! -d "$TEST_DIR/.pyve/envs/root" ]
}

@test "init on a none-root project emits the 'does not yet materialize' advisory note" {
    _none_root_manifest
    run bash "$PYVE_BIN" init
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not yet materialize"* ]]
    [[ "$output" == *"root"* ]]
}

@test "init preserves the declared pyve.toml on a none-root project" {
    _none_root_manifest
    run bash "$PYVE_BIN" init
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/pyve.toml" ]
    grep -q 'backend = "none"' "$TEST_DIR/pyve.toml"
}

@test "init still hard-errors on a genuinely-unknown --backend (bogus)" {
    run bash "$PYVE_BIN" init --backend bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" != *"does not yet materialize"* ]]
}
