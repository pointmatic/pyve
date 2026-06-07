#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Python plugin gitignore + purge_inventory hooks.
#
# Two hooks ship as data interfaces:
#   - python_pyve_plugin_gitignore_entries   — language-ecosystem
#     patterns the Python plugin contributes to .gitignore. Output
#     passes through validate_gitignore_snippet (N.m PC-1 gate).
#   - python_pyve_plugin_purge_inventory     — declares paths the
#     Python plugin created (safe to remove) and paths the user
#     authored (never touch). v3.0 ships the data interface; purge
#     behavior is unchanged.
#
# Re-seat in N.r:
#   - the Python plugin's gitignore_entries hook supplies the
#     Python-ecosystem patterns (validated via PC-1); macOS / pyve-managed
#     lines stay composer-owned (same Option-(a) boundary as N.q used for
#     .envrc). The composed write itself lives in lib/gitignore_composer.sh
#     (the legacy write_gitignore_template was retired in N.al; its
#     emission is covered by test_gitignore_composer.bats).
#   - purge_project pulls the inventory as a data interface (no
#     removal-decision change in v3.0; the seam is in place for
#     future plugins).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    create_test_dir
    bp_registry_reset
    plugin_registry_reset
    python_pyve_plugin_register_backends
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# python_pyve_plugin_gitignore_entries — language-ecosystem patterns.
# ════════════════════════════════════════════════════════════════════

@test "gitignore_entries: hook is defined" {
    declare -F python_pyve_plugin_gitignore_entries >/dev/null
}

@test "gitignore_entries: emits Python build/test artifact patterns" {
    run python_pyve_plugin_gitignore_entries
    [ "$status" -eq 0 ]
    [[ "$output" == *"__pycache__"* ]]
    [[ "$output" == *"*.pyc"* ]]
    [[ "$output" == *"*.egg-info"* ]]
    [[ "$output" == *".pytest_cache/"* ]]
    [[ "$output" == *"dist/"* ]]
}

@test "gitignore_entries: emits Jupyter notebook patterns" {
    run python_pyve_plugin_gitignore_entries
    [ "$status" -eq 0 ]
    [[ "$output" == *".ipynb_checkpoints/"* ]]
}

@test "gitignore_entries: includes section headers (UX clarity in .gitignore)" {
    run python_pyve_plugin_gitignore_entries
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Python build and test artifacts"* ]]
    [[ "$output" == *"# Jupyter notebooks"* ]]
}

@test "gitignore_entries: output passes validate_gitignore_snippet (PC-1)" {
    local snippet
    snippet="$(python_pyve_plugin_gitignore_entries)"
    run validate_gitignore_snippet "$snippet"
    [ "$status" -eq 0 ]
}

@test "gitignore_entries: plugin_dispatch python gitignore_entries routes to the hook" {
    plugin_register python
    run plugin_dispatch python gitignore_entries
    [ "$status" -eq 0 ]
    [[ "$output" == *"__pycache__"* ]]
}

# ════════════════════════════════════════════════════════════════════
# python_pyve_plugin_purge_inventory — data interface for purge.
#
# Output format: one path per line, prefixed with `created` (safe
# to remove) or `authored` (never touch). Consumer (purge_project)
# filters by prefix.
# ════════════════════════════════════════════════════════════════════

@test "purge_inventory: hook is defined" {
    declare -F python_pyve_plugin_purge_inventory >/dev/null
}

@test "purge_inventory: declares .venv as Pyve-created" {
    run python_pyve_plugin_purge_inventory
    [ "$status" -eq 0 ]
    [[ "$output" == *"created .venv"* ]]
}

@test "purge_inventory: declares .envrc as Pyve-created" {
    run python_pyve_plugin_purge_inventory
    [[ "$output" == *"created .envrc"* ]]
}

@test "purge_inventory: declares .pyve/envs as Pyve-created" {
    run python_pyve_plugin_purge_inventory
    [[ "$output" == *"created .pyve/envs"* ]]
}

@test "purge_inventory: declares pyproject.toml as user-authored (never touch)" {
    run python_pyve_plugin_purge_inventory
    [[ "$output" == *"authored pyproject.toml"* ]]
}

@test "purge_inventory: declares requirements*.txt as user-authored" {
    run python_pyve_plugin_purge_inventory
    [[ "$output" == *"authored requirements"* ]]
}

@test "purge_inventory: plugin_dispatch python purge_inventory routes to the hook" {
    plugin_register python
    run plugin_dispatch python purge_inventory
    [ "$status" -eq 0 ]
    [[ "$output" == *"created"* ]]
    [[ "$output" == *"authored"* ]]
}

