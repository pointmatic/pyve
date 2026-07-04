#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story P.j — explicit-by-construction manifest.
#
# `pyve init` writes a fully-explicit `pyve.toml`: every `[env.<name>]`
# block records `purpose`, `backend`, and `default` — nothing is left to
# TOML "absent = default" inference. Scope: manifest-native fields only
# (python / env-name / direnv / project-guide are NOT recorded here).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/init_composer.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# Emit the value of a single key inside a named [env.<name>] block.
_env_field() {
    local name="$1" key="$2"
    awk -v blk="[env.${name}]" -v k="$key" '
        $0 == blk { inb=1; next }
        /^\[/     { inb=0 }
        inb && $1 == k { print; exit }
    ' pyve.toml
}

# ---- plain (pure-Python) writer -------------------------------------

@test "explicit manifest: [env.root] carries purpose + backend + default" {
    _init_write_pyve_toml "demo" "venv"
    [[ "$(_env_field root purpose)" == 'purpose = "utility"' ]]
    [[ "$(_env_field root backend)" == 'backend = "venv"' ]]
    [[ "$(_env_field root default)" == 'default = false' ]]
}

@test "explicit manifest: [env.testenv] carries purpose + backend + default" {
    _init_write_pyve_toml "demo" "venv"
    [[ "$(_env_field testenv purpose)" == 'purpose = "test"' ]]
    [[ "$(_env_field testenv backend)" == 'backend = "venv"' ]]
    [[ "$(_env_field testenv default)" == 'default = true' ]]
}

@test "explicit manifest: micromamba root records backend=micromamba, testenv stays venv" {
    _init_write_pyve_toml "demo" "micromamba"
    [[ "$(_env_field root backend)" == 'backend = "micromamba"' ]]
    [[ "$(_env_field testenv backend)" == 'backend = "venv"' ]]
}

@test "explicit manifest: no-backend-arg form still emits an explicit backend (venv default)" {
    _init_write_pyve_toml "demo"
    [[ "$(_env_field root backend)" == 'backend = "venv"' ]]
    [[ "$(_env_field root default)" == 'default = false' ]]
    [[ "$(_env_field testenv backend)" == 'backend = "venv"' ]]
}

@test "explicit manifest: validates clean under manifest_load" {
    _init_write_pyve_toml "demo" "micromamba"
    manifest_load pyve.toml
    [ "$PYVE_PROJECT_NAME" = "demo" ]
}

# ---- polyglot writer ------------------------------------------------

@test "explicit manifest (polyglot): both envs carry backend + default explicitly" {
    _init_write_pyve_toml_polyglot "demo" "src/frontend" "venv"
    [[ "$(_env_field root backend)" == 'backend = "venv"' ]]
    [[ "$(_env_field root default)" == 'default = false' ]]
    [[ "$(_env_field testenv backend)" == 'backend = "venv"' ]]
    [[ "$(_env_field testenv default)" == 'default = true' ]]
    # Node sub-path still recorded.
    grep -qE '^\[plugins\.node\]$' pyve.toml
    grep -qE '^path = "src/frontend"$' pyve.toml
}

# ---- deterministic replay: re-writing is a no-op ---------------------

@test "explicit manifest: writer is idempotent — a second call leaves the file byte-identical" {
    _init_write_pyve_toml "demo" "venv"
    local first; first="$(cat pyve.toml)"
    _init_write_pyve_toml "demo" "venv"
    local second; second="$(cat pyve.toml)"
    [ "$first" = "$second" ]
}

# ---- easy-mode flag registration ------------------------------------

@test "easy-mode: --yes and -y are accepted init flags (not unknown)" {
    run _init_valid_flags
    [ "$status" -eq 0 ]
    grep -qx -- '--yes' <<<"$output"
    grep -qx -- '-y' <<<"$output"
}
