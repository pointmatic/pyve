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
    source "$PYVE_ROOT/lib/param_graph.sh"
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

# ---- versioned-defaults stamp (Story P.k) ---------------------------

@test "explicit manifest: [project] records pyve_defaults_version stamp" {
    _init_write_pyve_toml "demo" "venv"
    grep -qE "^pyve_defaults_version = \"${PYVE_PARAM_DEFAULTS_VERSION}\"\$" pyve.toml
}

@test "explicit manifest (polyglot): [project] records the stamp too" {
    _init_write_pyve_toml_polyglot "demo" "src/frontend" "venv"
    grep -qE "^pyve_defaults_version = \"${PYVE_PARAM_DEFAULTS_VERSION}\"\$" pyve.toml
}

@test "explicit manifest: manifest_load exposes PYVE_PROJECT_DEFAULTS_VERSION" {
    _init_write_pyve_toml "demo" "venv"
    manifest_load pyve.toml
    [ "$PYVE_PROJECT_DEFAULTS_VERSION" = "$PYVE_PARAM_DEFAULTS_VERSION" ]
}

@test "never retroactive: a defaults-set bump does not rewrite an existing manifest" {
    _init_write_pyve_toml "demo" "venv"
    local before; before="$(cat pyve.toml)"
    # Simulate a framework upgrade that advances the baked-in default set.
    PYVE_PARAM_DEFAULTS_VERSION=999
    _init_write_pyve_toml "demo" "venv"
    local after; after="$(cat pyve.toml)"
    [ "$before" = "$after" ]
    # The repo keeps its original stamp; the bump is surfaced by `pyve check`,
    # never applied to the file.
    grep -qE '^pyve_defaults_version = "1"$' pyve.toml
}

@test "manifest_load: missing stamp → empty PYVE_PROJECT_DEFAULTS_VERSION (back-compat)" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "legacy"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    [ -z "$PYVE_PROJECT_DEFAULTS_VERSION" ]
}

# ---- easy-mode flag registration ------------------------------------

@test "easy-mode: --yes and -y are accepted init flags (not unknown)" {
    run _init_valid_flags
    [ "$status" -eq 0 ]
    grep -qx -- '--yes' <<<"$output"
    grep -qx -- '-y' <<<"$output"
}
