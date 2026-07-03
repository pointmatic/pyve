#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml is the sole config source: `pyve_version` was a v2 `.pyve/config`
# concept (pyve.toml carries no version), so its reads and the machinery around
# them are gone — the obsolete `validate_pyve_version` / `validate_config_file`
# validators, the `update_config_version` writer, and the update-flow version
# step. These guards assert nothing reads `.pyve/config` for `pyve_version` and
# that the removed functions are no longer defined.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/version.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

assert_no_pyve_version_read() {
    local fn="$1" body
    body="$(declare -f "$fn")" || {
        echo "function '$fn' is not defined (source chain incomplete)"
        return 1
    }
    if grep -qE 'read_config_value[[:space:]]+"?pyve_version"?' <<<"$body"; then
        echo "function '$fn' still reads .pyve/config pyve_version:"
        grep -nE 'read_config_value[[:space:]]+"?pyve_version"?' <<<"$body"
        return 1
    fi
}

@test "no .pyve/config pyve_version read remains in lib/ or pyve.sh" {
    run grep -rnE 'read_config_value[[:space:]]+"?pyve_version"?' "$PYVE_ROOT/pyve.sh" "$PYVE_ROOT/lib"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "validate_pyve_version is removed" {
    ! declare -F validate_pyve_version
}

@test "validate_config_file is removed" {
    ! declare -F validate_config_file
}

@test "update_config_version is removed" {
    ! declare -F update_config_version
}

@test "init_project no longer reads pyve_version" {
    assert_no_pyve_version_read init_project
}

@test "update_project no longer reads pyve_version" {
    assert_no_pyve_version_read update_project
}

@test "check_environment no longer reads pyve_version" {
    assert_no_pyve_version_read check_environment
}

@test "_status_section_project no longer reads pyve_version" {
    assert_no_pyve_version_read _status_section_project
}

@test "update_project no longer calls update_config_version" {
    local body
    body="$(declare -f update_project)"
    [[ "$body" != *update_config_version* ]]
}
