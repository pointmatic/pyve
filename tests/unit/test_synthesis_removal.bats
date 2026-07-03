#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# The v3.0 read-compat synthesis is gone (the breaking step). pyve.toml is now
# the ONLY declaration pyve reads: a legacy `.pyve/config`-only project (never
# migrated) is treated as uninitialized. The v2 soft banner still nudges
# `pyve self migrate`, and `pyve self migrate` itself still reads `.pyve/config`
# directly — but no command synthesizes a working manifest from it anymore.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    create_test_dir
    export NO_COLOR=1
    export PYVE_QUIET=1
}

teardown() {
    cleanup_test_dir
}

@test "the synthesis machinery is removed" {
    ! declare -F _manifest_synthesize_from_legacy
    ! declare -F _manifest_has_legacy_sources
    ! declare -F _manifest_deprecation_warn_legacy
}

@test "no 'v3.0-only: remove in N-10' markers remain in lib/" {
    run grep -rn 'v3.0-only: remove in N-10' "$PYVE_ROOT/lib"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "manifest_load on a .pyve/config-only project yields an empty manifest" {
    create_pyve_config "backend: micromamba"
    [ ! -e pyve.toml ]
    manifest_load >/dev/null 2>&1 || true
    run manifest_get_backend root
    # root env is not synthesized → lookup fails / empty.
    [ -z "$output" ]
    run manifest_list_envs
    [ -z "$output" ]
}

@test "pyve check on a .pyve/config-only project reports 'not a pyve project'" {
    create_pyve_config "backend: venv"
    [ ! -e pyve.toml ]
    run "$PYVE_SCRIPT" check
    [[ "$output" == *"not a pyve project"* ]]
}

@test "pyve status on a .pyve/config-only project reports 'Not a pyve-managed project'" {
    create_pyve_config "backend: venv"
    [ ! -e pyve.toml ]
    run "$PYVE_SCRIPT" status
    [[ "$output" == *"Not a pyve-managed project"* ]]
}

@test "pyve update on a .pyve/config-only project requires an initialized project" {
    create_pyve_config "backend: venv"
    [ ! -e pyve.toml ]
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires an initialized project"* ]]
}
