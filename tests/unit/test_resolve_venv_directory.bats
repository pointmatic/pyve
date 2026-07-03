#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml as the sole config source — `resolve_venv_directory` centralizes the
# root venv directory resolution. In v3 the root venv is always the `.venv`
# default (`resolve_env_path root` returns the same); the v2 `.pyve/config`
# venv.directory override is no longer consulted. Never returns empty.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "resolve_venv_directory: a v2 custom venv.directory is ignored (defaults to .venv)" {
    create_pyve_config "backend: venv" "venv:" "  directory: custom_venv"
    run resolve_venv_directory
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
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
