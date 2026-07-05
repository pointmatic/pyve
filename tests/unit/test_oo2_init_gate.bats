#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve init` materializes a test env only when one is actually declared —
# it must not inject an undeclared `testenv` (which then reads as "broken"
# in `pyve check`). The decision is factored into `_init_testenv_to_materialize`
# (full init_project is too expensive to exercise per-test; cf. test_init_pyve_toml).
# It returns the declared default test env to materialize at init — but only
# when venv-backed: a conda env needs a manifest + solve (deferred to
# `pyve env init`), and an advisory/`none` mirror is declarative-only.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "root-only manifest (no test env declared) → init materializes no test env" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
TOML
    run _init_testenv_to_materialize
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "declared no-backend testenv on a venv root → materialize it" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.testenv]
purpose = "test"
default = true
TOML
    run _init_testenv_to_materialize
    [ "$status" -eq 0 ]
    [ "$output" = "testenv" ]
}

@test "declared micromamba testenv → not materialized at init (conda deferred to env init)" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.testenv]
purpose = "test"
default = true
backend = "micromamba"
manifest = "environment.yml"
TOML
    run _init_testenv_to_materialize
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-backend testenv mirroring a micromamba root → not materialized (conda deferred)" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "micromamba"
[env.testenv]
purpose = "test"
default = true
TOML
    run _init_testenv_to_materialize
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-backend testenv mirroring a none/advisory root → declarative-only (not materialized)" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "none"
[env.testenv]
purpose = "test"
default = true
TOML
    run _init_testenv_to_materialize
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "init_project wires the gate (source-grep) — no bare ensure_env_exists" {
    # init_project must route testenv materialization through the gate, not
    # call a bare no-arg ensure_env_exists (the eager-undeclared defect).
    run grep -n '_init_testenv_to_materialize' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -eq 0 ]
    # The bare no-arg call (eager default-testenv creation) is gone.
    run grep -nE '^\s*ensure_env_exists\s*$' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -ne 0 ]
}
