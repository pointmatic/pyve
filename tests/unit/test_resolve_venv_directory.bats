#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Subphase P-1 (pyve.toml as the sole config source) — `resolve_venv_directory`
# centralizes the root venv directory resolution: the v2 `.pyve/config`
# venv.directory override (a user's `pyve init <dir>`) is honored during the
# read-compat window, else the v3 default `.venv`. Consumers stop reading
# `.pyve/config` directly, so the transitional read lives in exactly one place
# for Subphase P-1's stop step to remove. Never returns empty.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "resolve_venv_directory: honors a custom venv.directory in .pyve/config" {
    create_pyve_config "backend: venv" "venv:" "  directory: custom_venv"
    run resolve_venv_directory
    [ "$status" -eq 0 ]
    [ "$output" = "custom_venv" ]
}

@test "resolve_venv_directory: v3-native (no .pyve/config) defaults to .venv" {
    [ ! -e .pyve/config ]
    run resolve_venv_directory
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

@test "resolve_venv_directory: config without a venv.directory defaults to .venv" {
    create_pyve_config "backend: venv"
    run resolve_venv_directory
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

@test "no plugin.sh consumer reads venv.directory straight from .pyve/config" {
    # Every consumer routes through resolve_venv_directory (which centralizes the
    # transitional config read + the .venv default). The only direct reads left
    # are the resolver itself (utils.sh), config validation (backend_detect.sh),
    # and the deliberate legacy migrate read (self.sh) — none in plugin.sh.
    run grep -n 'read_config_value ["'"'"']*venv.directory' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -ne 0 ]
}
