#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story P.k — versioned defaults + drift surfacing.
#
# `PYVE_PARAM_DEFAULTS_VERSION` stamps the current baked-in default set.
# `pg_defaults_changelog` records each default change (empty at v1); a repo
# records the set version it was built under, and `pyve check` surfaces the
# defaults that changed since — as neutral info, never rewriting the pin.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/param_graph.sh"
}

@test "PYVE_PARAM_DEFAULTS_VERSION: is a positive integer" {
    [[ "$PYVE_PARAM_DEFAULTS_VERSION" =~ ^[0-9]+$ ]]
    [ "$PYVE_PARAM_DEFAULTS_VERSION" -ge 1 ]
}

@test "pg_defaults_changelog: empty at defaults version 1 (no default has changed yet)" {
    local out; out="$(pg_defaults_changelog)"
    [ -z "$out" ]
}

@test "pg_defaults_changed_since: nothing changed → empty (real v1 changelog)" {
    local out; out="$(pg_defaults_changed_since 1)"
    [ -z "$out" ]
}

@test "pg_defaults_changed_since: reports rows newer than the given version (simulated bump)" {
    # Simulate a future default change at set v2.
    pg_defaults_changelog() {
        printf '2|python-version|3.14.6|3.15.0\n'
    }
    local out; out="$(pg_defaults_changed_since 1)"
    [ "$out" = '2|python-version|3.14.6|3.15.0' ]
}

@test "pg_defaults_changed_since: silent when the repo is already at the current set" {
    pg_defaults_changelog() {
        printf '2|python-version|3.14.6|3.15.0\n'
    }
    local out; out="$(pg_defaults_changed_since 2)"
    [ -z "$out" ]
}

@test "pg_defaults_changed_since: only rows strictly newer than <since> (multi-version)" {
    pg_defaults_changelog() {
        printf '2|python-version|3.14.6|3.15.0\n'
        printf '3|direnv|yes|no\n'
    }
    local out; out="$(pg_defaults_changed_since 2)"
    [ "$out" = '3|direnv|yes|no' ]
}
