#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Packaging-provider contract + registry skeleton.
#
# The packaging-provider registry maps a `packaging` value (e.g. "docker")
# to a registered provider, parallel to the N-2 backend-provider registry.
# v3.0 registers ZERO providers (concept Q6 / v3.0-window decision: reserve
# the verb + scaffold the contract, materialize nothing). The first provider
# lands post-v3.0 with no breaking change.
#
# Surface under test (lib/plugins/packaging_registry.sh):
#   pp_registry_reset
#   pp_register <plugin> <packaging_value>
#   packaging_provider_for <value>     — owning plugin, or empty (return 1)
#   pp_list
#   pp_dispatch <value> <hook> [args...]

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/packaging_registry.sh"
    create_test_dir
    pp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# v3.0 ships zero providers — the empty-registry baseline.
# ────────────────────────────────────────────────────────────────────

@test "packaging_provider_for: empty registry returns no provider" {
    run packaging_provider_for docker
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "pp_list: empty when no registrations (v3.0 baseline)" {
    run pp_list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ────────────────────────────────────────────────────────────────────
# Registration + lookup (exercised by post-v3.0 providers / test stubs).
# ────────────────────────────────────────────────────────────────────

@test "pp_register: records (plugin, packaging_value)" {
    pp_register docker_plugin docker
    run packaging_provider_for docker
    [ "$status" -eq 0 ]
    [ "$output" = "docker_plugin" ]
}

@test "pp_register: idempotent for same (plugin, value)" {
    pp_register docker_plugin docker
    pp_register docker_plugin docker
    run packaging_provider_for docker
    [ "$status" -eq 0 ]
    [ "$output" = "docker_plugin" ]
}

@test "pp_register: errors on conflicting re-registration" {
    pp_register docker_plugin docker
    run pp_register other_plugin docker
    [ "$status" -ne 0 ]
    [[ "$output" == *"docker"* ]]
    [[ "$output" == *"already registered"* ]]
}

@test "pp_list: prints registered values in registration order" {
    pp_register docker_plugin docker
    pp_register bundle_plugin lock_bundle
    run pp_list
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output")" == $'docker\nlock_bundle' ]]
}

# ────────────────────────────────────────────────────────────────────
# Dispatch — provider-specific package hook is invoked when present.
# ────────────────────────────────────────────────────────────────────

@test "pp_dispatch: calls <value>_pyve_pp_<hook> when defined" {
    eval '
        docker_pyve_pp_package() {
            printf "docker-package %s/%s" "$1" "$2"
        }
    '
    pp_register docker_plugin docker
    run pp_dispatch docker package alpha beta
    [ "$status" -eq 0 ]
    [ "$output" = "docker-package alpha/beta" ]
}

@test "pp_dispatch: silent no-op when registered but hook undefined" {
    pp_register docker_plugin docker
    run pp_dispatch docker package
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "pp_dispatch: errors on unregistered value" {
    run pp_dispatch ghost package
    [ "$status" -ne 0 ]
    [[ "$output" == *"ghost"* ]]
}

# ────────────────────────────────────────────────────────────────────
# Library guard — cannot be executed directly.
# ────────────────────────────────────────────────────────────────────

@test "packaging_registry.sh: refuses direct execution" {
    run bash "$PYVE_ROOT/lib/plugins/packaging_registry.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot be executed directly"* ]]
}
