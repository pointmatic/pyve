#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Subphase P-1 (pyve.toml as the sole config source) — the micromamba env name
# is resolved from the v3 source (environment.yml `name:`) when there is no
# `.pyve/config`. Before this, `pyve status` on a v3-native micromamba project
# reported "not configured" for the env name because the status section read
# `.pyve/config` directly.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

@test "_status_env_micromamba: shows the environment.yml name on a v3-native project" {
    printf 'name: myproj\ndependencies:\n  - python\n' > environment.yml
    [ ! -e .pyve/config ]
    run _status_env_micromamba
    [ "$status" -eq 0 ]
    [[ "$output" == *"myproj"* ]]
    [[ "$output" != *"not configured"* ]]
}

@test "_status_env_micromamba: still 'not configured' when neither source names the env" {
    [ ! -e .pyve/config ]
    [ ! -e environment.yml ]
    run _status_env_micromamba
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
}

@test "no plugin.sh consumer reads micromamba.env_name straight from .pyve/config" {
    # Every consumer routes through resolve_micromamba_env_name (which adds the
    # environment.yml fallback); the only direct read left is inside the resolver
    # itself, which lives in lib/micromamba_env.sh, not plugin.sh.
    run grep -n 'read_config_value ["'"'"']*micromamba.env_name' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -ne 0 ]
}
