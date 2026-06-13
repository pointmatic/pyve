#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve test` (no --env) default-env resolution (`_test_default_env`):
#   - an explicit `default = true` always wins;
#   - else autowire only when the root is a Python backend (venv/micromamba),
#     the declared env collection is homogeneous in backend, AND exactly one
#     test env is declared → promote that sole test env;
#   - a mixed-backend collection, multiple test envs without a default, or a
#     non-Python/`none` root → no default (caller requires explicit --env).

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

@test "explicit default = true wins" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.smoke]
purpose = "test"
[env.testenv]
purpose = "test"
default = true
TOML
    run _test_default_env
    [ "$status" -eq 0 ]
    [ "$output" = "testenv" ]
}

@test "sole test env, no default, venv root (homogeneous, Python) → promote" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.testenv]
purpose = "test"
TOML
    run _test_default_env
    [ "$status" -eq 0 ]
    [ "$output" = "testenv" ]
}

@test "sole test env mirroring a micromamba root (homogeneous, Python) → promote" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "micromamba"
[env.testenv]
purpose = "test"
TOML
    run _test_default_env
    [ "$status" -eq 0 ]
    [ "$output" = "testenv" ]
}

@test "two test envs, no default → no autowire" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.unit]
purpose = "test"
[env.integration]
purpose = "test"
TOML
    run _test_default_env
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "mixed backend (venv root + explicit micromamba testenv), no default → no autowire" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.testenv]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
TOML
    run _test_default_env
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "none/advisory root → no autowire (non-Python root)" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "none"
[env.testenv]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
TOML
    run _test_default_env
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "_test_run_one_env routes its default selection through _test_default_env (source-grep)" {
    run grep -n '_test_default_env' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -eq 0 ]
    # The permissive ${PYVE_TESTENVS_DEFAULT:-testenv} fallback is gone.
    run grep -n 'PYVE_TESTENVS_DEFAULT:-testenv' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -ne 0 ]
}
