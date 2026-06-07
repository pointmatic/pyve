#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.l — Backend-provider registry (three-category abstraction).
#
# Per spike S6, every backend declares one of three categories:
#   - virtualized   (per-project env dir; PATH activation required)
#   - cache-backed  (shared user-level cache + project lockfile)
#   - check-only    (Pyve verifies presence; no install action)
#
# v3.0 ships only virtualized backends (venv, micromamba); the other
# categories are designed-in but unexercised. Schema accommodates them.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    create_test_dir
    bp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# Registration + lookup
# ────────────────────────────────────────────────────────────────────

@test "bp_register: records (plugin, backend_name, category)" {
    bp_register python venv virtualized
    run bp_lookup venv
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

@test "bp_category: returns the registered category" {
    bp_register python venv virtualized
    run bp_category venv
    [ "$status" -eq 0 ]
    [ "$output" = "virtualized" ]
}

@test "bp_register: idempotent for same (plugin, category)" {
    bp_register python venv virtualized
    bp_register python venv virtualized
    run bp_lookup venv
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

@test "bp_register: errors on conflicting re-registration" {
    bp_register python venv virtualized
    run bp_register node venv virtualized
    [ "$status" -ne 0 ]
    [[ "$output" == *"venv"* ]]
    [[ "$output" == *"already registered"* ]]
}

@test "bp_register: rejects unknown category" {
    run bp_register python venv quantum
    [ "$status" -ne 0 ]
    [[ "$output" == *"quantum"* ]]
    [[ "$output" == *"virtualized"* ]]
}

@test "bp_register: accepts every documented category" {
    bp_register python venv virtualized
    bp_register rust cargo cache-backed
    bp_register apple xcode check-only
    run bp_lookup venv
    [ "$output" = "python" ]
    run bp_lookup cargo
    [ "$output" = "rust" ]
    run bp_lookup xcode
    [ "$output" = "apple" ]
}

@test "bp_lookup: errors on unknown backend" {
    run bp_lookup nonexistent
    [ "$status" -ne 0 ]
}

@test "bp_category: errors on unknown backend" {
    run bp_category nonexistent
    [ "$status" -ne 0 ]
}

# ────────────────────────────────────────────────────────────────────
# Dispatch — backend-specific impl wins; category default is fallback.
# ────────────────────────────────────────────────────────────────────

@test "bp_dispatch: calls <backend>_pyve_bp_<hook> when defined" {
    eval '
        venv_pyve_bp_activate() {
            printf "venv-activate %s/%s" "$1" "$2"
        }
    '
    bp_register python venv virtualized
    run bp_dispatch venv activate alpha beta
    [ "$status" -eq 0 ]
    [ "$output" = "venv-activate alpha/beta" ]
}

@test "bp_dispatch: falls back to pyve_bp_default_<category>_<hook>" {
    eval '
        pyve_bp_default_virtualized_purge() {
            printf "default-virtualized-purge %s" "$1"
        }
    '
    bp_register python venv virtualized
    run bp_dispatch venv purge .venv
    [ "$status" -eq 0 ]
    [ "$output" = "default-virtualized-purge .venv" ]
}

@test "bp_dispatch: errors on unknown backend" {
    run bp_dispatch unknown_backend activate
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown_backend"* ]]
}

@test "bp_dispatch: silent no-op when no impl and no category default" {
    bp_register apple xcode check-only
    # No xcode_pyve_bp_activate, no pyve_bp_default_check_only_activate.
    # Backend categories' "no contribution" semantics (S6) → silent 0.
    run bp_dispatch xcode activate
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ────────────────────────────────────────────────────────────────────
# bp_list — print all registered backends, one per line.
# ────────────────────────────────────────────────────────────────────

@test "bp_list: empty when no registrations" {
    run bp_list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "bp_list: prints registered backend names in registration order" {
    bp_register python venv virtualized
    bp_register python micromamba virtualized
    run bp_list
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output")" == $'venv\nmicromamba' ]]
}
