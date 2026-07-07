#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml is the sole config source: the non-backend resolvers no longer
# consult `.pyve/config`. Unlike the backend resolvers (which a v2 project
# reaches via the read-compat synthesis), these values are read straight from
# the v3 source files a real v2 project already has on disk — `environment.yml`
# `name:` (micromamba env name), `.tool-versions` / `.python-version` (Python
# pin), and the `.venv` default (venv directory). These guards assert the
# `.pyve/config` branch is gone from each resolver, plus prove a v2-shaped
# project still resolves from its v3 source file.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# Fail if <fn>'s body reads `.pyve/config` (either read_config_value or the
# config_file_exists presence gate that guards such a read).
assert_no_config_read() {
    local fn="$1" body
    body="$(declare -f "$fn")" || {
        echo "function '$fn' is not defined (source chain incomplete)"
        return 1
    }
    if grep -qE 'read_config_value|config_file_exists' <<<"$body"; then
        echo "function '$fn' still reads .pyve/config:"
        grep -nE 'read_config_value|config_file_exists' <<<"$body"
        return 1
    fi
}

@test "resolve_environment_name reads no .pyve/config" {
    assert_no_config_read resolve_environment_name
}

@test "resolve_micromamba_env_name reads no .pyve/config" {
    assert_no_config_read resolve_micromamba_env_name
}

@test "resolve_venv_directory reads no .pyve/config" {
    assert_no_config_read resolve_venv_directory
}

@test "resolve_python_version reads no .pyve/config" {
    assert_no_config_read resolve_python_version
}

@test "resolve_main_micromamba_path reads no .pyve/config" {
    assert_no_config_read resolve_main_micromamba_path
}

# ── v2-shaped projects still resolve, from the v3 source files ──────────────

@test "resolve_micromamba_env_name: a v2 project resolves from environment.yml name:" {
    # v2 project also carries environment.yml; the config env_name is ignored.
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: fromconfig"
    printf 'name: fromyaml\ndependencies:\n  - python\n' > environment.yml
    run resolve_micromamba_env_name
    [ "$status" -eq 0 ]
    [ "$output" = "fromyaml" ]
}

@test "resolve_environment_name: a v2 project resolves from environment.yml name:" {
    create_pyve_config "micromamba:" "  env_name: fromconfig"
    create_environment_yml "fromyaml" "python=3.11"
    run resolve_environment_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "fromyaml" ]
}

@test "resolve_python_version: a v2 project resolves from .tool-versions" {
    create_pyve_config "backend: venv" "python:" "  version: 3.10.4"
    printf 'python 3.12.13\n' > .tool-versions
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "$output" = "3.12.13|tool-versions" ]
}

@test "resolve_venv_directory: a v2 custom venv.directory is ignored (defaults to .venv)" {
    create_pyve_config "backend: venv" "venv:" "  directory: custom_venv"
    run resolve_venv_directory
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

@test "resolve_python_version: no pin files → empty (config no longer consulted)" {
    create_pyve_config "backend: venv" "python:" "  version: 3.10.4"
    [ ! -e .tool-versions ]
    [ ! -e .python-version ]
    run resolve_python_version
    [ "$status" -eq 0 ]
    [ "${output%|*}" = "" ]
}
