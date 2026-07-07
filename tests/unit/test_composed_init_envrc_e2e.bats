#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Composed `.envrc` non-interference + visitor-path activation.
#
# N-3's closest look at N-4's composition concern. The Python plugin's
# activation section (root env) and the Node plugin's activation section
# (src/frontend visitor) are concatenated into one `.envrc` body; this
# file proves they coexist cleanly:
#   - both sections present in the composed body;
#   - each section, and the composed body, passes the N.m PC-1 validator
#     (validate_envrc_snippet);
#   - the Node section is sentinel-delimited (# >>> pyve:plugin:node:activate
#     >>> … <<<);
#   - the two PATH_adds are distinct and do not interfere;
#   - the visitor-path Node section emits a project-root-relative
#     `PATH_add "src/frontend/node_modules/.bin"` so direnv resolves the
#     absolute dir from the project root, not from src/frontend.
#
# Full composition (ordering, dedup, single-file emission) is N-4. Here the
# concatenation is performed directly to prove non-interference of the two
# plugin-emitted sections; CLI-level composition lands with N-4's routing.

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

# Compose the Python (root venv) + Node (src/frontend visitor) sections
# into one `.envrc` body and echo it to stdout. The Python section is the
# 5-line plugin snippet (N-4 wraps it in composer sentinels); the Node
# section is already sentinel-wrapped by node_pyve_plugin_activate.
_compose_envrc() {
    local py node
    py="$(_python_pyve_plugin_envrc_snippet venv ".venv" "root")" || return 1
    node="$(node_pyve_plugin_activate src/frontend)" || return 1
    printf '%s\n%s\n' "$py" "$node"
}

# ════════════════════════════════════════════════════════════════════
# Both sections present in the composed body.
# ════════════════════════════════════════════════════════════════════

@test "compose: python root section is present" {
    run _compose_envrc
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add ".venv/bin"'* ]]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/.venv"'* ]]
}

@test "compose: node visitor section is present" {
    run _compose_envrc
    [ "$status" -eq 0 ]
    [[ "$output" == *'PATH_add "src/frontend/node_modules/.bin"'* ]]
}

# ════════════════════════════════════════════════════════════════════
# Each section — and the composed body — passes PC-1 validation.
# ════════════════════════════════════════════════════════════════════

@test "validate: python root section passes validate_envrc_snippet" {
    local py
    py="$(_python_pyve_plugin_envrc_snippet venv ".venv" "root")"
    run validate_envrc_snippet "$py"
    [ "$status" -eq 0 ]
}

@test "validate: node visitor section passes validate_envrc_snippet" {
    local node
    node="$(node_pyve_plugin_activate src/frontend)"
    run validate_envrc_snippet "$node"
    [ "$status" -eq 0 ]
}

@test "validate: composed body passes validate_envrc_snippet" {
    local composed
    composed="$(_compose_envrc)"
    run validate_envrc_snippet "$composed"
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# Node section is sentinel-delimited.
# ════════════════════════════════════════════════════════════════════

@test "sentinels: node section is wrapped in node:activate markers" {
    run _compose_envrc
    [[ "$output" == *"# >>> pyve:plugin:node:activate >>>"* ]]
    [[ "$output" == *"# <<< pyve:plugin:node:activate <<<"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Non-interference — the two PATH_adds are distinct.
# ════════════════════════════════════════════════════════════════════

@test "non-interference: the two PATH_add values are distinct" {
    local composed
    composed="$(_compose_envrc)"
    [[ "$composed" == *'PATH_add ".venv/bin"'* ]]
    [[ "$composed" == *'PATH_add "src/frontend/node_modules/.bin"'* ]]
    # The node PATH_add must not collapse onto the python one.
    [ "$(printf '%s\n' "$composed" | grep -c 'PATH_add')" -eq 2 ]
}

@test "non-interference: no hand-rolled 'export PATH=' from either section" {
    run _compose_envrc
    [[ "$output" != *"export PATH="* ]]
}

# ════════════════════════════════════════════════════════════════════
# Visitor-path activation — exact, project-root-relative path string.
# ════════════════════════════════════════════════════════════════════

@test "visitor-path: node-at-subpath emits the exact root-relative PATH_add" {
    run node_pyve_plugin_activate src/frontend
    [ "$status" -eq 0 ]
    # Project-root-relative (no leading ./, no $PWD-from-subdir): direnv
    # resolves the absolute dir from the project root where `.envrc` lives.
    [[ "$output" == *'PATH_add "src/frontend/node_modules/.bin"'* ]]
    [[ "$output" != *'PATH_add "node_modules/.bin"'* ]]
}
