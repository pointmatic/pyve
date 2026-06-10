#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story N.bf.20 — `pyve env install` must not leave a `.pyve`
# stray on a never-initialized project, and the canonical `env` surface must
# not be branded with the deprecated `testenv`.
#
# Bug A (same class as N.bf.17, different path): `_env_install_with_lock`
# acquired the install lock first, and `_env_acquire_install_lock` runs
# `mkdir -p .pyve/envs/<name>` BEFORE the env-initialized check inside the
# backend install helpers — so a doomed install materialized `.pyve/` before
# discovering there was no env to install into.
#
# Bug B: the named-action dispatcher hardcoded `header_box "pyve testenv"`,
# the install loop printed `Installing '<name>' testenv...`, and the
# not-initialized advice said `Run: pyve testenv init <name>` — pointing at
# the deprecated command even when `env` was invoked.

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

# ============================================================
# Bug A — no `.pyve` stray on a doomed install
# ============================================================

@test "env install: failed install on uninitialized project leaves NO .pyve stray" {
    # No pyproject.toml / pyve.toml: the reserved default `testenv` is
    # iterated, but no env exists on disk — the install must fail and
    # materialize nothing.
    run env_command install
    [ "$status" -ne 0 ]
    [ ! -e ".pyve" ]
}

@test "env install <name>: failed named install on uninitialized project leaves NO .pyve stray" {
    : > pyve.toml  # initialized-enough that `testenv` is actionable
    run env_command install testenv
    [ "$status" -ne 0 ]
    [ ! -e ".pyve/envs/testenv" ]
}

@test "env install: doomed install leaves nothing for purge to find" {
    # The whole point of the gate: a failed install materializes no state,
    # so a follow-up purge has nothing to remove (cf. N.bf.17).
    run env_command install
    [ "$status" -ne 0 ]
    [ ! -e ".pyve" ]
    run "$PYVE_ROOT/pyve.sh" purge --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to remove"* ]]
}

# ============================================================
# Bug B — canonical `pyve env` branding (no `pyve testenv`)
# ============================================================

@test "env install: header box reads 'pyve env', not 'pyve testenv'" {
    run env_command install
    [[ "$output" == *"pyve env"* ]]
    [[ "$output" != *"pyve testenv"* ]]
}

@test "env install: not-initialized advice points at 'pyve env init', not 'pyve testenv init'" {
    run env_command install
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve env init"* ]]
    [[ "$output" != *"pyve testenv init"* ]]
}

@test "env install: install loop message drops the doubled 'testenv' branding" {
    run env_command install
    [[ "$output" == *"Installing 'testenv'"* ]]
    [[ "$output" != *"'testenv' testenv"* ]]
}

# ============================================================
# Sibling leaf — `env run` not-initialized hint is also canonical
# ============================================================

@test "env run: not-initialized advice points at 'pyve env', not 'pyve testenv'" {
    : > pyve.toml
    run env_command run -- echo hi
    [ "$status" -ne 0 ]
    [[ "$output" != *"pyve testenv"* ]]
}
