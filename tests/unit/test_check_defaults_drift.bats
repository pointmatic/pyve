#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story P.k — `pyve check` surfaces versioned-defaults drift as INFO-ONLY.
# `_compose_check_defaults_drift` compares the repo's recorded defaults-set
# stamp against the framework's current set and lists what changed, without
# ever rewriting the manifest or affecting the check severity verdict.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/param_graph.sh"
    source "$PYVE_ROOT/lib/check_composer.sh"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

@test "defaults drift: silent when the repo stamp equals the current set" {
    : > pyve.toml
    PYVE_PROJECT_DEFAULTS_VERSION=1
    PYVE_PARAM_DEFAULTS_VERSION=1
    local out; out="$(_compose_check_defaults_drift)"
    [ -z "$out" ]
}

@test "defaults drift: silent on a pre-P.k manifest (no stamp recorded)" {
    : > pyve.toml
    PYVE_PROJECT_DEFAULTS_VERSION=""
    PYVE_PARAM_DEFAULTS_VERSION=1
    local out; out="$(_compose_check_defaults_drift)"
    [ -z "$out" ]
}

@test "defaults drift: no section when pyve.toml is absent" {
    PYVE_PROJECT_DEFAULTS_VERSION=1
    PYVE_PARAM_DEFAULTS_VERSION=2
    pg_defaults_changelog() { printf '2|python-version|3.14.6|3.15.0\n'; }
    local out; out="$(_compose_check_defaults_drift)"
    [ -z "$out" ]
}

@test "defaults drift: reports changed defaults when the repo trails the current set" {
    : > pyve.toml
    PYVE_PROJECT_DEFAULTS_VERSION=1
    PYVE_PARAM_DEFAULTS_VERSION=2
    pg_defaults_changelog() { printf '2|python-version|3.14.6|3.15.0\n'; }
    local out; out="$(_compose_check_defaults_drift)"
    [[ "$out" == *"python-version"* ]]
    [[ "$out" == *"3.14.6"* ]]
    [[ "$out" == *"3.15.0"* ]]
    # Reassures the user their pins are untouched (info, not an error).
    [[ "$out" == *"unchanged"* ]] || [[ "$out" == *"pins"* ]]
}

@test "defaults drift: returns 0 (info-only, never an error verdict)" {
    : > pyve.toml
    PYVE_PROJECT_DEFAULTS_VERSION=1
    PYVE_PARAM_DEFAULTS_VERSION=2
    pg_defaults_changelog() { printf '2|python-version|3.14.6|3.15.0\n'; }
    _compose_check_defaults_drift >/dev/null
    [ "$?" -eq 0 ]
}
