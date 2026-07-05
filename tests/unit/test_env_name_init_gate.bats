#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story N.bf.18 — `pyve env <leaf> <name>` on an
# uninitialized project should point at `pyve init`, not "not declared".
#
# `assert_env_name_actionable` previously jumped straight to the
# declared-name check, so on a never-initialized directory it told the
# user to "declare it under [tool.pyve.testenvs.<name>] in pyproject.toml"
# — misleading when there is no Pyve project at all. The init-state check
# only fires for a non-reserved, non-declared name (the reserved `testenv`
# default path is intentionally untouched).

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "assert_env_name_actionable: uninitialized project → points at 'pyve init'" {
    # No pyve.toml, no .pyve/config.
    run assert_env_name_actionable foo
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" != *"not declared"* ]]
}

@test "assert_env_name_actionable: v3-initialized (pyve.toml) → normal not-declared path" {
    : > pyve.toml
    run assert_env_name_actionable foo
    [ "$status" -ne 0 ]
    # Reaches the normal declared-name validation, NOT the init hint.
    [[ "$output" == *"not declared"* ]]
    [[ "$output" != *"pyve init"* ]]
}

@test "assert_env_name_actionable: reserved 'testenv' stays actionable even uninitialized" {
    # Out-of-scope path (N.bf.18) — must remain unchanged.
    run assert_env_name_actionable testenv
    [ "$status" -eq 0 ]
}

@test "assert_env_name_actionable: 'root' is still selection-only (unchanged)" {
    run assert_env_name_actionable root
    [ "$status" -ne 0 ]
    [[ "$output" == *"selection-only"* ]]
}
