#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml as the sole config source — `resolve_micromamba_env_name` resolves
# the configured micromamba env name from `environment.yml`'s `name:` metadata
# (the v3 source: the name survives only as conda env metadata), else empty.
# Empty is meaningful — callers treat it as "not configured" — so unlike
# `resolve_environment_name` there is no basename fallback. `.pyve/config` is no
# longer consulted.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "resolve_micromamba_env_name: a v2 .pyve/config env_name is ignored (no environment.yml → empty)" {
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: fromconfig"
    [ ! -e environment.yml ]
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "resolve_micromamba_env_name: resolves from environment.yml name:" {
    printf 'name: fromyaml\ndependencies:\n  - python\n' > environment.yml
    [ ! -e .pyve/config ]
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "fromyaml" ]
}

@test "resolve_micromamba_env_name: environment.yml is authoritative; a v2 config env_name is ignored" {
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: fromconfig"
    printf 'name: fromyaml\ndependencies:\n  - python\n' > environment.yml
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "fromyaml" ]
}

@test "resolve_micromamba_env_name: empty when neither source declares a name" {
    [ ! -e .pyve/config ]
    [ ! -e environment.yml ]
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
