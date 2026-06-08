#!/usr/bin/env bats
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

@test "assert_env_name_actionable: v2 [tool.pyve.testenvs.foo] still resolves (read-compat)" {
    # No pyve.toml; v2 declaration + init marker.
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.foo]
requirements = ["requirements-dev.txt"]
TOML
    mkdir -p .pyve
    printf 'backend: venv\n' > .pyve/config
    read_env_config
    run assert_env_name_actionable foo
    [ "$status" -eq 0 ]
}
