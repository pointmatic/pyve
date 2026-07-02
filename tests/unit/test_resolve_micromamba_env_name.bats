#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Subphase P-1 (pyve.toml as the sole config source) — `resolve_micromamba_env_name`
# resolves the configured micromamba env name from v3 sources: the transitional
# `.pyve/config` micromamba.env_name (config-first for read-compat), else
# `environment.yml`'s `name:` metadata, else empty. Empty is meaningful —
# callers treat it as "not configured" — so unlike `resolve_environment_name`
# there is no basename fallback.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "resolve_micromamba_env_name: reads .pyve/config micromamba.env_name" {
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: fromconfig"
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "fromconfig" ]
}

@test "resolve_micromamba_env_name: v3-native falls back to environment.yml name:" {
    printf 'name: fromyaml\ndependencies:\n  - python\n' > environment.yml
    [ ! -e .pyve/config ]
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "fromyaml" ]
}

@test "resolve_micromamba_env_name: config wins over environment.yml (read-compat priority)" {
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: fromconfig"
    printf 'name: fromyaml\ndependencies:\n  - python\n' > environment.yml
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "fromconfig" ]
}

@test "resolve_micromamba_env_name: empty when neither source declares a name" {
    [ ! -e .pyve/config ]
    [ ! -e environment.yml ]
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
