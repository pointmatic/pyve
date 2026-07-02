#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Subphase P-1 (pyve.toml as the sole config source) — `resolve_python_version`
# centralizes the pinned-Python resolution the `python show` and `status`
# consumers previously duplicated: `.tool-versions` (asdf) → `.python-version`
# (pyenv) → the transitional `.pyve/config` python.version, in that order. It
# prints "<version>|<source>" where source is one of tool-versions /
# python-version / config (empty when nothing pins a version). The config read
# is the read-compat tail, dropped when Subphase P-1 stops writing `.pyve/config`.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "resolve_python_version: reads the python line from .tool-versions" {
    printf 'python 3.12.13\nnodejs 20.0.0\n' > .tool-versions
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "$output" = "3.12.13|tool-versions" ]
}

@test "resolve_python_version: reads .python-version when no .tool-versions" {
    printf '3.11.9\n' > .python-version
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "$output" = "3.11.9|python-version" ]
}

@test "resolve_python_version: .tool-versions takes precedence over .python-version" {
    printf 'python 3.12.13\n' > .tool-versions
    printf '3.11.9\n' > .python-version
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "$output" = "3.12.13|tool-versions" ]
}

@test "resolve_python_version: falls back to .pyve/config when no pin files (read-compat)" {
    create_pyve_config "backend: venv" "python:" "  version: 3.10.4"
    [ ! -e .tool-versions ]
    [ ! -e .python-version ]
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "$output" = "3.10.4|config" ]
}

@test "resolve_python_version: empty version when nothing pins one" {
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "${output%|*}" = "" ]
}
