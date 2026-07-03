#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml is the sole config source: with the read-compat synthesis
# populating the root backend from `.pyve/config`, the transitional
# `.pyve/config` backend reads (added as manifest-first-then-config
# fallbacks while the two sources coexisted) are dead. Backend now resolves
# from the manifest only; a v2 project keeps working because `manifest_load`
# synthesizes its root backend from `.pyve/config`. These guards assert the
# direct config reads are gone from every backend-resolving surface.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # version.sh (validate_installation_structure) and commands/lock.sh
    # (_lock_main_env) are not part of the default helper source chain.
    source "$PYVE_ROOT/lib/version.sh"
    source "$PYVE_ROOT/lib/commands/lock.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
    bp_registry_reset
    plugin_registry_reset
    python_pyve_plugin_register_backends
}

teardown() {
    cleanup_test_dir
}

# Fail if <fn>'s body reads the `.pyve/config` backend directly. Matches both
# `read_config_value backend` and `read_config_value "backend"`; a
# `read_config_value "pyve_version"` (a separate, later-removed concern) does
# not trip it.
assert_no_config_backend_read() {
    local fn="$1" body
    body="$(declare -f "$fn")" || {
        echo "function '$fn' is not defined (source chain incomplete)"
        return 1
    }
    if grep -qE 'read_config_value[[:space:]]+"?backend"?' <<<"$body"; then
        echo "function '$fn' still reads .pyve/config backend directly:"
        grep -nE 'read_config_value[[:space:]]+"?backend"?' <<<"$body"
        return 1
    fi
}

@test "activate hook resolves backend from the manifest only" {
    assert_no_config_backend_read python_pyve_plugin_activate
}

@test "update_project resolves backend from the manifest only" {
    assert_no_config_backend_read update_project
}

@test "purge_project resolves backend from the manifest only" {
    assert_no_config_backend_read purge_project
}

@test "run_command resolves backend from the manifest only" {
    assert_no_config_backend_read run_command
}

@test "_lock_main_env resolves backend from the manifest only" {
    assert_no_config_backend_read _lock_main_env
}

@test "_env_resolve_backend resolves the mirrored root backend from the manifest only" {
    assert_no_config_backend_read _env_resolve_backend
}

@test "_env_resolve_root_backend resolves from the manifest only" {
    assert_no_config_backend_read _env_resolve_root_backend
}

@test "init existing-backend detection reads the manifest, not .pyve/config" {
    assert_no_config_backend_read init_project
}

@test "get_backend_priority no longer reads .pyve/config" {
    assert_no_config_backend_read get_backend_priority
}

@test "validate_installation_structure reads the manifest backend" {
    assert_no_config_backend_read validate_installation_structure
}

@test "no manifest-first-then-config backend fallback idiom remains in lib/ or pyve.sh" {
    run grep -rnE '\[\[ -z "\$[A-Za-z_]+" \]\] &&[[:space:]]*[A-Za-z_]+="\$\(read_config_value[^)]*backend' \
        "$PYVE_ROOT/pyve.sh" "$PYVE_ROOT/lib"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "get_backend_priority: a stale .pyve/config no longer overrides file detection" {
    # A venv-shaped project (pyproject.toml) with a stale micromamba .pyve/config.
    # With Priority-2 gone, file detection wins and the config is ignored.
    touch pyproject.toml
    create_pyve_config "backend: micromamba"
    run get_backend_priority ""
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "get_backend_priority: an explicit --backend still wins (Priority 1 intact)" {
    create_pyve_config "backend: micromamba"
    run get_backend_priority "venv"
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "_env_resolve_root_backend: a v2 project resolves its backend via synthesis" {
    create_pyve_config "backend: micromamba"
    [ ! -e pyve.toml ]
    manifest_load >/dev/null 2>&1 || true
    run _env_resolve_root_backend
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "validate_installation_structure: a v2 venv project validates via the synthesized backend" {
    create_pyve_config "pyve_version: \"0.8.8\"" "backend: venv"
    mkdir -p .venv/bin
    touch .venv/bin/python
    chmod +x .venv/bin/python
    touch .env
    run validate_installation_structure
    [ "$status" -eq 0 ]
}
