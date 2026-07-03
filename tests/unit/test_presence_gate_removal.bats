#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml is the sole config source: command code no longer probes
# `.pyve/config` presence directly. The v2-project detection that these gates
# performed now routes through `_manifest_has_legacy_sources` (the surviving
# synthesis-detection helper), so a v2 project is still recognized without a
# scattered `config_file_exists` gate. The only surviving direct `.pyve/config`
# presence checks are the exempt trio — `_manifest_has_legacy_sources`,
# `self migrate`, and the legacy-layout mover — which go in P.i.13.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # show_config lives in pyve.sh (which runs main() on source); extract just
    # that function so `declare -f` can inspect it.
    source_pyve_fn show_config
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

# Extract a single function definition from pyve.sh and eval it into scope.
source_pyve_fn() {
    local fn="$1"
    local body
    body="$(awk -v fn="$fn" '
        $0 ~ "^" fn "\\(\\)[[:space:]]*\\{" { inside = 1 }
        inside { print }
        inside && /^\}$/ { exit }
    ' "$PYVE_ROOT/pyve.sh")"
    eval "$body"
}

teardown() {
    cleanup_test_dir
}

# Fail if <fn>'s body calls config_file_exists or tests `.pyve/config` presence
# with a -f/-e file test. A plain string mention (e.g. inside a log_error) is
# not a presence gate and does not trip this.
assert_no_config_presence_gate() {
    local fn="$1" body
    body="$(declare -f "$fn")" || {
        echo "function '$fn' is not defined (source chain incomplete)"
        return 1
    }
    if grep -qE 'config_file_exists|-[ef][[:space:]]+"?\.pyve/config"?' <<<"$body"; then
        echo "function '$fn' still has a direct .pyve/config presence gate:"
        grep -nE 'config_file_exists|-[ef][[:space:]]+"?\.pyve/config"?' <<<"$body"
        return 1
    fi
}

@test "show_config has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate show_config
}

@test "show_config no longer reads a .pyve/config value" {
    local body
    body="$(declare -f show_config)"
    [[ "$body" != *read_config_value* ]]
}

@test "_init_is_reinit has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate _init_is_reinit
}

@test "init_project has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate init_project
}

@test "update_project has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate update_project
}

@test "check_environment has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate check_environment
}

@test "show_status has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate show_status
}

@test "python_plugin_is_active_in_project has no direct .pyve/config presence gate" {
    assert_no_config_presence_gate python_plugin_is_active_in_project
}
