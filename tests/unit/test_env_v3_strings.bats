#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# The env-lifecycle help + error strings must point at the v3 canonical
# declaration surface (`pyve.toml [env.<name>]`), not the v2
# `pyproject.toml [tool.pyve.testenvs.<name>]` table. Once the lifecycle
# reader migrated onto the manifest, the old spellings became lies: a
# user declaring only in `pyve.toml` is told to edit a file the lifecycle
# no longer reads.
#
# The `pyve self migrate` references to the v2 source stay — the migrator
# legitimately reads `[tool.pyve.testenvs]` from `pyproject.toml`. A guard
# test below confirms the rewrite did not over-reach into them.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/commands/lock.sh"
    # manifest_load parses pyve.toml via the Python helper (tomllib).
    # Resolve PYVE_PYTHON while still in PYVE_ROOT (pinned) — BEFORE
    # create_test_dir cd's into an unpinned tmp dir.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    # `unknown_flag_error` lives in pyve.sh, not in any lib/; stub it so
    # the lock dispatcher's `-*` arm can't loop or "command not found".
    unknown_flag_error() {
        printf "Error: 'pyve %s' does not accept '%s'\n" "$1" "$2" >&2
        exit 1
    }
}

teardown() {
    cleanup_test_dir
}

# ============================================================
# `pyve env --help`
# ============================================================

@test "env --help points named-env declaration at pyve.toml [env.<name>]" {
    run bash "$PYVE_ROOT/pyve.sh" env --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve.toml"* ]]
    [[ "$output" == *"[env."* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
    [[ "$output" != *"pyproject.toml"* ]]
}

# ============================================================
# `pyve lock --env` errors
# ============================================================

@test "lock --env <undeclared>: 'not declared' error names pyve.toml [env.<name>]" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"
TOML
    run lock_environment --env bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"pyve.toml"* ]]
    [[ "$output" == *"[env.bogus]"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
}

@test "lock --env <conda, no manifest>: schema hint names pyve.toml [env.<name>]" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.hardware]
purpose = "test"
backend = "micromamba"
TOML
    run lock_environment --env hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
    [[ "$output" == *"pyve.toml"* ]]
    [[ "$output" == *"[env.hardware]"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
}

# ============================================================
# `pyve env install` / `pyve env init` errors
# ============================================================

@test "env install: declared-requirements-missing error names [env.<name>].requirements" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.foo]
purpose = "test"
requirements = ["nope.txt"]
TOML
    mkdir -p fakeenv/bin
    printf '#!/bin/sh\n' > fakeenv/bin/python
    chmod +x fakeenv/bin/python

    # The lifecycle reads its config via read_env_config (as the dispatcher
    # does) before the accessors resolve; populate from pyve.toml [env.*].
    read_env_config
    run _env_install_venv foo "$PWD/fakeenv" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"nope.txt"* ]]
    [[ "$output" == *"[env.foo].requirements"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
}

@test "env init (conda, no manifest): error names pyve.toml [env.<name>]" {
    run _env_init_conda mirror "$PWD/fakeenv" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
    [[ "$output" == *"pyve.toml"* ]]
    [[ "$output" == *"[env.mirror]"* ]]
    [[ "$output" != *"pyproject.toml"* ]]
}

@test "env install (conda, no manifest): error names pyve.toml [env.<name>]" {
    run _env_install_conda mirror "$PWD/fakeenv" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
    [[ "$output" == *"pyve.toml"* ]]
    [[ "$output" != *"pyproject.toml"* ]]
}

# ============================================================
# Regression guard — the `pyve self migrate` refs to the v2 source
# legitimately read pyproject `[tool.pyve.testenvs]`; the rewrite must
# not over-reach into them.
# ============================================================

@test "self migrate still references the v2 [tool.pyve.testenvs] source" {
    grep -q 'tool\.pyve\.testenvs' "$PYVE_ROOT/lib/commands/self.sh"
}
