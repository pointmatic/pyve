#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Node plugin: activation hook (.envrc emission).
#
# node_pyve_plugin_activate composes a sentinel-marked `.envrc` section
# that PATH_adds the env's node_modules/.bin (path-aware for sub-path
# plugins), runs it through the N.m PC-1 validator (validate_envrc_snippet),
# and emits the validated section to stdout — the section N-4's composer
# assembles into one `.envrc`. Uses direnv's PATH_add primitive, never a
# hand-rolled `export PATH=` (the Uniform .envrc template rule).
#
# Unlike the Python plugin (venv→VIRTUAL_ENV vs micromamba→CONDA_PREFIX),
# Node activation is uniform across providers (pnpm/npm/yarn) — just the
# node_modules/.bin PATH_add.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Snippet shape — PATH_add + sentinel markers.
# ════════════════════════════════════════════════════════════════════

@test "activate: root plugin emits PATH_add for node_modules/.bin" {
    run node_pyve_plugin_activate .
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add "node_modules/.bin"'* ]]
}

@test "activate: defaults to root when no path is given" {
    run node_pyve_plugin_activate
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add "node_modules/.bin"'* ]]
}

@test "activate: sub-path plugin emits a path-prefixed PATH_add" {
    run node_pyve_plugin_activate src/frontend
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add "src/frontend/node_modules/.bin"'* ]]
}

@test "activate: a trailing slash in the path is normalized" {
    run node_pyve_plugin_activate src/frontend/
    [[ "$output" == *'PATH_add "src/frontend/node_modules/.bin"'* ]]
}

@test "activate: section is wrapped in node:activate sentinel markers" {
    run node_pyve_plugin_activate .
    [[ "$output" == *">>> pyve:plugin:node:activate >>>"* ]]
    [[ "$output" == *"<<< pyve:plugin:node:activate <<<"* ]]
}

@test "activate: does not hand-roll 'export PATH=' (uses PATH_add)" {
    run node_pyve_plugin_activate .
    [[ "$output" != *"export PATH="* ]]
}

# ════════════════════════════════════════════════════════════════════
# PC-1 integration — emitted output validates; malformed input rejected.
# ════════════════════════════════════════════════════════════════════

@test "activate: emitted section passes PC-1 validation (root)" {
    local snippet
    snippet="$(node_pyve_plugin_activate .)"
    run validate_envrc_snippet "$snippet"
    [ "$status" -eq 0 ]
}

@test "activate: emitted section passes PC-1 validation (sub-path)" {
    local snippet
    snippet="$(node_pyve_plugin_activate src/frontend)"
    run validate_envrc_snippet "$snippet"
    [ "$status" -eq 0 ]
}

@test "activate: a path with command substitution is caught by PC-1 (no write, no exec)" {
    run node_pyve_plugin_activate 'evil/$(touch pwned)'
    [ "$status" -ne 0 ]
    [[ "$output" == *"PC-1"* ]] || [[ "$output" == *"rejected"* ]]
    [ ! -f pwned ]
}

@test "PC-1: rejects an unquoted PATH_add value (malformed snippet)" {
    run validate_envrc_snippet 'PATH_add node_modules/.bin'
    [ "$status" -ne 0 ]
}
