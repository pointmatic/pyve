#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Node backend-providers: pnpm / npm / yarn.
#
# Fills the register_backends stub from N.t: registers the three Node
# package managers as project-virtualized backend-providers via N.l's
# bp_register, and ships the per-provider string-mapping helpers
# (install command / lockfile name / test invocation) plus the
# provider-detection helper (explicit backend wins; else infer from
# lockfile presence; else default pnpm).
#
# The actual lifecycle bp hooks (activate / init / purge) land in N.w /
# N.y; N.u only registers the providers and maps their per-tool strings.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# register_backends — pnpm / npm / yarn as project-virtualized, owned
# by the node plugin.
# ════════════════════════════════════════════════════════════════════

@test "register_backends: registers pnpm as virtualized owned by node" {
    node_pyve_plugin_register_backends
    run bp_lookup pnpm
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
    run bp_category pnpm
    [ "$output" = "virtualized" ]
}

@test "register_backends: registers npm as virtualized owned by node" {
    node_pyve_plugin_register_backends
    run bp_lookup npm
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
    run bp_category npm
    [ "$output" = "virtualized" ]
}

@test "register_backends: registers yarn as virtualized owned by node" {
    node_pyve_plugin_register_backends
    run bp_lookup yarn
    [ "$status" -eq 0 ]
    [ "$output" = "node" ]
    run bp_category yarn
    [ "$output" = "virtualized" ]
}

@test "register_backends: registers exactly pnpm, npm, yarn" {
    node_pyve_plugin_register_backends
    run bp_list
    [[ "$(printf '%s' "$output")" == $'pnpm\nnpm\nyarn' ]]
}

@test "register_backends: is idempotent (safe to re-fire)" {
    node_pyve_plugin_register_backends
    node_pyve_plugin_register_backends
    run bp_list
    [[ "$(printf '%s' "$output")" == $'pnpm\nnpm\nyarn' ]]
}

@test "register_backends: coexists with the Python providers (no collision)" {
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    python_pyve_plugin_register_backends
    node_pyve_plugin_register_backends
    run bp_lookup venv
    [ "$output" = "python" ]
    run bp_lookup pnpm
    [ "$output" = "node" ]
}

# ════════════════════════════════════════════════════════════════════
# bp_dispatch resolves a registered Node provider (lifecycle hooks land
# later; here we only prove registration makes the backend dispatchable
# rather than erroring with "not registered").
# ════════════════════════════════════════════════════════════════════

@test "bp_dispatch: a registered Node provider resolves (no 'not registered' error)" {
    node_pyve_plugin_register_backends
    run bp_dispatch pnpm activate
    [ "$status" -eq 0 ]
}

@test "bp_dispatch: an unregistered backend still errors" {
    node_pyve_plugin_register_backends
    run bp_dispatch deno activate
    [ "$status" -ne 0 ]
    [[ "$output" == *"not registered"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Per-provider helpers — install command / lockfile name / test command.
# ════════════════════════════════════════════════════════════════════

@test "node_provider_install: maps each provider to its install command" {
    run node_provider_install pnpm
    [ "$output" = "pnpm install" ]
    run node_provider_install npm
    [ "$output" = "npm install" ]
    run node_provider_install yarn
    [ "$output" = "yarn install" ]
}

@test "node_provider_lockfile: maps each provider to its lockfile name" {
    run node_provider_lockfile pnpm
    [ "$output" = "pnpm-lock.yaml" ]
    run node_provider_lockfile npm
    [ "$output" = "package-lock.json" ]
    run node_provider_lockfile yarn
    [ "$output" = "yarn.lock" ]
}

@test "node_provider_test: maps each provider to its test invocation" {
    # N.x revisits this per the package.json-script-delegation decision;
    # N.u returns the conventional `<pm> test` form.
    run node_provider_test pnpm
    [ "$output" = "pnpm test" ]
    run node_provider_test npm
    [ "$output" = "npm test" ]
    run node_provider_test yarn
    [ "$output" = "yarn test" ]
}

@test "node_provider_install: unknown provider errors" {
    run node_provider_install deno
    [ "$status" -ne 0 ]
}

@test "node_provider_lockfile: unknown provider errors" {
    run node_provider_lockfile deno
    [ "$status" -ne 0 ]
}

@test "node_provider_test: unknown provider errors" {
    run node_provider_test deno
    [ "$status" -ne 0 ]
}

# ════════════════════════════════════════════════════════════════════
# node_provider_detect — explicit backend wins; else infer from lockfile
# presence; else default to pnpm. Path-aware (default ".").
# Usage: node_provider_detect [declared_backend] [path]
# ════════════════════════════════════════════════════════════════════

@test "node_provider_detect: explicit backend is the source of truth" {
    run node_provider_detect pnpm
    [ "$output" = "pnpm" ]
    run node_provider_detect npm
    [ "$output" = "npm" ]
    run node_provider_detect yarn
    [ "$output" = "yarn" ]
}

@test "node_provider_detect: explicit backend wins over a conflicting lockfile" {
    : > pnpm-lock.yaml
    run node_provider_detect npm
    [ "$output" = "npm" ]
}

@test "node_provider_detect: infers pnpm from pnpm-lock.yaml" {
    : > pnpm-lock.yaml
    run node_provider_detect ""
    [ "$output" = "pnpm" ]
}

@test "node_provider_detect: infers npm from package-lock.json" {
    : > package-lock.json
    run node_provider_detect ""
    [ "$output" = "npm" ]
}

@test "node_provider_detect: infers yarn from yarn.lock" {
    : > yarn.lock
    run node_provider_detect ""
    [ "$output" = "yarn" ]
}

@test "node_provider_detect: defaults to pnpm when no lockfile present" {
    run node_provider_detect ""
    [ "$output" = "pnpm" ]
}

@test "node_provider_detect: path-aware — infers from a lockfile under a sub-path" {
    mkdir -p src/frontend
    : > src/frontend/yarn.lock
    run node_provider_detect "" src/frontend
    [ "$output" = "yarn" ]
}
