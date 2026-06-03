#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Structural invariant: every Python plugin command implementation
# lives in lib/plugins/python/plugin.sh. Legacy single-purpose
# lib/commands/<command>.sh files (init, purge, update, check,
# status, run, test, python) do not exist. pyve.sh's library-loading
# block contains no references to those paths.
#
# Guards against accidental "restoration" of a per-command file by a
# future contributor unaware of the plugin-as-owner architecture.
#
# Replaces the per-relocation transient placeholder tests
# (test_n_s_{1..8}_*_relocation.bats) that served the RED→GREEN cycle
# during each function relocation.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"

    # Each row: "<function_name> <legacy_lib_commands_basename>"
    relocated_commands=(
        "init_project       init"
        "purge_project      purge"
        "update_project     update"
        "check_environment  check"
        "show_status        status"
        "run_command        run"
        "test_tests         test"
        "python_command     python"
    )
}

@test "every relocated command function is defined in lib/plugins/python/plugin.sh" {
    local row fn
    for row in "${relocated_commands[@]}"; do
        # shellcheck disable=SC2206
        local parts=($row)
        fn="${parts[0]}"
        if ! grep -qE "^${fn}\(\)" "$PLUGIN_FILE"; then
            printf "MISSING: %s() should be defined in %s\n" \
                "$fn" "$PLUGIN_FILE" >&2
            return 1
        fi
    done
}

@test "no legacy lib/commands/<command>.sh file exists for any relocated command" {
    local row legacy path
    for row in "${relocated_commands[@]}"; do
        # shellcheck disable=SC2206
        local parts=($row)
        legacy="${parts[1]}"
        path="$PYVE_ROOT/lib/commands/${legacy}.sh"
        if [[ -e "$path" ]]; then
            printf "PRESENT: %s should be deleted (command moved to %s)\n" \
                "lib/commands/${legacy}.sh" "lib/plugins/python/plugin.sh" >&2
            return 1
        fi
    done
}

@test "pyve.sh references no legacy lib/commands/<command>.sh path" {
    local row legacy
    for row in "${relocated_commands[@]}"; do
        # shellcheck disable=SC2206
        local parts=($row)
        legacy="${parts[1]}"
        if grep -F "lib/commands/${legacy}.sh" "$PYVE_SH" >/dev/null 2>&1; then
            printf "REFERENCE: pyve.sh contains 'lib/commands/%s.sh' (should be removed)\n" \
                "$legacy" >&2
            return 1
        fi
    done
}
