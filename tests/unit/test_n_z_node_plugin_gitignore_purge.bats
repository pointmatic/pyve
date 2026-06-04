#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.z — Node plugin: .gitignore + smart-purge hooks.
#
# Mirrors the Python plugin's N.r:
#   node_pyve_plugin_gitignore_entries [path]  — Node ecosystem patterns,
#                                                designed to pass the N.m
#                                                gitignore validator.
#   node_pyve_plugin_purge_inventory [path]    — created-vs-authored split
#                                                (declarative data interface).
# Both are path-aware: a sub-path plugin prefixes its entries; N-4's
# composer handles root-vs-subpath placement. N.z also aligns the actual
# remover (_node_purge_at, from N.w) with the inventory's created set by
# adding .turbo/ and *.tsbuildinfo.

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
# gitignore_entries
# ════════════════════════════════════════════════════════════════════

@test "gitignore_entries: root emits the Node ecosystem patterns" {
    run node_pyve_plugin_gitignore_entries .
    [ "$status" -eq 0 ]
    [[ "$output" == *"node_modules/"* ]]
    [[ "$output" == *".svelte-kit/"* ]]
    [[ "$output" == *".next/"* ]]
    [[ "$output" == *"*.tsbuildinfo"* ]]
    [[ "$output" == *".turbo/"* ]]
    [[ "$output" == *"pnpm-debug.log*"* ]]
}

@test "gitignore_entries: root output passes the N.m gitignore validator" {
    local out
    out="$(node_pyve_plugin_gitignore_entries .)"
    run validate_gitignore_snippet "$out"
    [ "$status" -eq 0 ]
}

@test "gitignore_entries: defaults to root when no path given" {
    run node_pyve_plugin_gitignore_entries
    [ "$status" -eq 0 ]
    [[ "$output" == *"node_modules/"* ]]
}

@test "gitignore_entries: sub-path prefixes pattern lines" {
    run node_pyve_plugin_gitignore_entries src/frontend
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/frontend/node_modules/"* ]]
    [[ "$output" == *"src/frontend/*.tsbuildinfo"* ]]
}

@test "gitignore_entries: sub-path does NOT prefix comment lines" {
    run node_pyve_plugin_gitignore_entries src/frontend
    # A comment header stays a bare comment (no path prefix in front of #).
    [[ "$output" == *"# Node"* ]]
    [[ "$output" != *"src/frontend/# Node"* ]]
}

@test "gitignore_entries: sub-path output still passes the validator" {
    local out
    out="$(node_pyve_plugin_gitignore_entries src/frontend)"
    run validate_gitignore_snippet "$out"
    [ "$status" -eq 0 ]
}

@test "gitignore_entries: trailing slash in path is normalized" {
    run node_pyve_plugin_gitignore_entries src/frontend/
    [[ "$output" == *"src/frontend/node_modules/"* ]]
    [[ "$output" != *"src/frontend//node_modules/"* ]]
}

# ════════════════════════════════════════════════════════════════════
# purge_inventory — created vs authored declaration.
# ════════════════════════════════════════════════════════════════════

@test "purge_inventory: declares the created (generated) artifacts" {
    run node_pyve_plugin_purge_inventory .
    [ "$status" -eq 0 ]
    [[ "$output" == *"created node_modules"* ]]
    [[ "$output" == *"created .svelte-kit"* ]]
    [[ "$output" == *"created dist"* ]]
    [[ "$output" == *"created build"* ]]
    [[ "$output" == *"created .next"* ]]
    [[ "$output" == *"created .turbo"* ]]
    [[ "$output" == *"created *.tsbuildinfo"* ]]
}

@test "purge_inventory: declares the authored (never-touch) files" {
    run node_pyve_plugin_purge_inventory .
    [[ "$output" == *"authored package.json"* ]]
    [[ "$output" == *"authored pnpm-lock.yaml"* ]]
    [[ "$output" == *"authored package-lock.json"* ]]
    [[ "$output" == *"authored yarn.lock"* ]]
    [[ "$output" == *"authored tsconfig.json"* ]]
    [[ "$output" == *"authored svelte.config.js"* ]]
}

@test "purge_inventory: sub-path prefixes the path token of each entry" {
    run node_pyve_plugin_purge_inventory src/frontend
    [ "$status" -eq 0 ]
    [[ "$output" == *"created src/frontend/node_modules"* ]]
    [[ "$output" == *"authored src/frontend/package.json"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Remover alignment — _node_purge_at now covers .turbo + *.tsbuildinfo.
# ════════════════════════════════════════════════════════════════════

@test "purge: removes .turbo/ and *.tsbuildinfo, keeps authored files" {
    local p="$TEST_DIR/proj"
    mkdir -p "$p/.turbo" "$p/node_modules"
    : > "$p/tsconfig.tsbuildinfo"
    : > "$p/package.json"
    : > "$p/pnpm-lock.yaml"
    run node_pyve_plugin_purge "$p"
    [ "$status" -eq 0 ]
    [ ! -d "$p/.turbo" ]
    [ ! -f "$p/tsconfig.tsbuildinfo" ]
    [ ! -d "$p/node_modules" ]
    [ -f "$p/package.json" ]
    [ -f "$p/pnpm-lock.yaml" ]
}
