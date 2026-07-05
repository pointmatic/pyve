#!/usr/bin/env bats
# bats file_tags=manifest
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story N.bf.19 — `pyve env` name-validation must consult
# the v3 manifest (`pyve.toml [env.<name>]`), not only the v2
# `pyproject.toml [tool.pyve.testenvs.*]` surface; and the "not declared"
# message must point at the v3 surface.
#
# Read-compat: during the v3.0 window a v2 `[tool.pyve.testenvs.<name>]`
# project still resolves (via the legacy `is_env_declared` arm, which N-10
# removes). The v3 `[env.<name>]` arm is the canonical recognition.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    # manifest_load parses pyve.toml via the Python helper (tomllib).
    # Resolve PYVE_PYTHON while still in PYVE_ROOT (which has a pinned
    # Python) — BEFORE create_test_dir cd's into an unpinned tmp dir.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

_v3_manifest_with_foo() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"

[env.foo]
purpose = "test"
TOML
}

# ============================================================
# v3 manifest [env.<name>] is recognized
# ============================================================

@test "assert_env_name_actionable: recognizes a v3-manifest-declared [env.foo]" {
    _v3_manifest_with_foo
    run assert_env_name_actionable foo
    [ "$status" -eq 0 ]
}

@test "ensure_env_exists-style gate: v3 [env.foo] is actionable" {
    _v3_manifest_with_foo
    # The reserved testenv path is unaffected.
    run assert_env_name_actionable testenv
    [ "$status" -eq 0 ]
}

# ============================================================
# Undeclared name → v3-surface message (not the v2-ism)
# ============================================================

@test "assert_env_name_actionable: undeclared on a v3 project points at [env.<name>] in pyve.toml" {
    _v3_manifest_with_foo
    run assert_env_name_actionable bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"[env.bogus]"* ]]
    [[ "$output" == *"pyve.toml"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
}

# ============================================================
# v2 read-compat: [tool.pyve.testenvs.<name>] still resolves
# ============================================================

# ============================================================
# Story O.k.1 — the env-lifecycle ATTRIBUTE accessors (backend / manifest /
# requirements / extra / lazy) must source from the pyve.toml manifest
# ([env.*]), not the v2 pyproject [tool.pyve.testenvs] table. Before this,
# `read_env_config` read pyproject, so a pyve.toml-only env resolved empty.
# ============================================================

@test "O.k.1: attribute accessors resolve from pyve.toml [env.*] (no pyproject)" {
    # Two valid envs: conda (backend+manifest) and venv (requirements).
    # `manifest`/`requirements`/`extra` are mutually exclusive per env.
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
default = true

[env.lint]
purpose = "test"
backend = "venv"
requirements = ["requirements-dev.txt"]
TOML
    read_env_config
    [ "$(_env_backend_of testenv)" = "micromamba" ]
    [ "$(_env_manifest_of testenv)" = "environment.yml" ]
    [ "$(_env_backend_of lint)" = "venv" ]
    local -a reqs=(); _env_requirements_of lint reqs
    [ "${reqs[0]}" = "requirements-dev.txt" ]
    is_env_declared testenv
    is_env_declared lint
}

@test "O.k.1: pyve.toml [env.*] takes precedence over a stale pyproject testenvs table" {
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
default = true
TOML
    # A stale v2 table that disagrees — the manifest must win.
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
backend = "venv"
TOML
    read_env_config
    [ "$(_env_backend_of testenv)" = "micromamba" ]
}

@test "O.k.1: read-compat — pyproject testenvs still drive when no pyve.toml" {
    # No pyve.toml → v2 pyproject [tool.pyve.testenvs] remains the source.
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.lint]
backend = "venv"
requirements = ["requirements-dev.txt"]
TOML
    read_env_config
    is_env_declared lint
    [ "$(_env_backend_of lint)" = "venv" ]
}
