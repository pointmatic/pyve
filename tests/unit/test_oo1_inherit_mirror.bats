#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# A declared test env with no `backend` mirrors the ROOT backend (`inherit`
# semantics) instead of defaulting to a hardcoded `venv`. Before this, a
# no-backend testenv resolved `venv` even on a micromamba-root project, so
# `pyve env`/`test` mis-resolved its path/backend. The mirror reads the
# canonical manifest (`pyve.toml [env.root]`), not only `.pyve/config`.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Writes a manifest with a no-backend [env.testenv] and the given root
# backend. Only writes the file — read_env_config must run in the test body
# so the PYVE_ENV_* manifest arrays land at body scope (a helper-function
# call drops them before the resolve runs).
_write_manifest() {
    cat > pyve.toml <<TOML
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "$1"

[env.testenv]
purpose = "test"
TOML
}

@test "no-backend testenv on a micromamba root resolves micromamba (mirrors root)" {
    _write_manifest "micromamba"
    read_env_config
    run _env_resolve_backend testenv
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "no-backend testenv on a venv root resolves venv (mirrors root, unchanged)" {
    _write_manifest "venv"
    read_env_config
    run _env_resolve_backend testenv
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "no-backend testenv on a none/advisory root mirrors the advisory value" {
    _write_manifest "none"
    read_env_config
    run _env_resolve_backend testenv
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}

@test "explicit backend on the testenv still wins over the root mirror" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"

[env.testenv]
purpose = "test"
backend = "venv"
TOML
    read_env_config
    run _env_resolve_backend testenv
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}
