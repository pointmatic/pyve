#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the asdf/direnv coexistence helpers (Phase J).
#
# This file is the single home for the `is_asdf_active` helper contract
# (Story J.a) plus placeholder tests for the downstream behaviors that
# J.b (`.envrc` asdf compat guard) and J.c (`pyve run` asdf compat guard)
# will green. The J.b/J.c placeholders use `skip` with a reason pointing
# at the story that will unskip them — same pattern as the Phase I
# bootstrap-test activation flow.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    create_test_dir

    # Each test starts with a neutral environment. Individual tests opt
    # into asdf-active state by setting VERSION_MANAGER and/or
    # PYVE_NO_ASDF_COMPAT explicitly.
    VERSION_MANAGER=""
    unset PYVE_NO_ASDF_COMPAT
}

teardown() {
    unset PYVE_NO_ASDF_COMPAT
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# is_asdf_active — the J.a helper contract
# ────────────────────────────────────────────────────────────────────

@test "is_asdf_active: VERSION_MANAGER=asdf and no gate → 0 (active)" {
    VERSION_MANAGER="asdf"
    run is_asdf_active
    [ "$status" -eq 0 ]
}

@test "is_asdf_active: VERSION_MANAGER=pyenv → 1 (not active)" {
    VERSION_MANAGER="pyenv"
    run is_asdf_active
    [ "$status" -eq 1 ]
}

@test "is_asdf_active: VERSION_MANAGER empty → 1 (not active)" {
    VERSION_MANAGER=""
    run is_asdf_active
    [ "$status" -eq 1 ]
}

@test "is_asdf_active: PYVE_NO_ASDF_COMPAT=1 suppresses active state" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT=1 run is_asdf_active
    [ "$status" -eq 1 ]
}

@test "is_asdf_active: PYVE_NO_ASDF_COMPAT empty is treated as unset (still active)" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT="" run is_asdf_active
    [ "$status" -eq 0 ]
}

@test "is_asdf_active: PYVE_NO_ASDF_COMPAT=anything truthy suppresses (e.g., 'yes')" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT="yes" run is_asdf_active
    [ "$status" -eq 1 ]
}

# ────────────────────────────────────────────────────────────────────
# Placeholder tests for Story J.b — .envrc asdf compat guard
# ────────────────────────────────────────────────────────────────────
# These assert the .envrc generator injects ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
# (with the sentinel comment for idempotency) when is_asdf_active returns 0.
# Story J.b implements the generator change and removes the skip markers.

@test "J.b placeholder: venv-backend .envrc includes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 when asdf active" {
    skip "Pending Story J.b: .envrc asdf compatibility guard"
    # When J.b unskips this, the expected shape is:
    #   - Invoke the venv-backend .envrc generator (pyve.sh ~L1042)
    #   - grep for the sentinel comment: "# Prevent asdf Python plugin from reshimming venv-installed CLIs."
    #   - grep for: export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
    #   - Both must appear exactly once (idempotency check: run generator twice, block stays once)
}

@test "J.b placeholder: micromamba-backend .envrc includes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 when asdf active" {
    skip "Pending Story J.b: .envrc asdf compatibility guard"
    # Parallel to the venv test but drives the micromamba-backend .envrc
    # generator at pyve.sh ~L1076.
}

@test "J.b placeholder: .envrc omits the compat block when is_asdf_active returns 1" {
    skip "Pending Story J.b: .envrc asdf compatibility guard"
    # Negative case: VERSION_MANAGER != "asdf" OR PYVE_NO_ASDF_COMPAT=1
    # → no sentinel, no export line.
}

# ────────────────────────────────────────────────────────────────────
# Placeholder tests for Story J.c — pyve run asdf compat guard
# ────────────────────────────────────────────────────────────────────
# These assert that `pyve run <cmd>` exposes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
# to the subprocess when is_asdf_active returns 0. Story J.c wraps the
# dispatcher with `env ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 …`.

@test "J.c placeholder: pyve run subprocess environment includes ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1 when asdf active" {
    skip "Pending Story J.c: pyve run asdf compatibility guard"
    # When J.c unskips this, the expected shape is:
    #   - Arrange: is_asdf_active returns 0 (mock VERSION_MANAGER=asdf)
    #   - Run: pyve run env | grep ASDF_PYTHON_PLUGIN_DISABLE_RESHIM
    #   - Assert: subprocess sees ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
}

@test "J.c placeholder: PYVE_NO_ASDF_COMPAT=1 suppresses the pyve run env injection" {
    skip "Pending Story J.c: pyve run asdf compatibility guard"
    # Negative case: gate env var set → dispatcher must not inject the compat var.
}
