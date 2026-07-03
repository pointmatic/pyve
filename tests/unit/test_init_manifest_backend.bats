#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story P.i.1 — `pyve init` writes the resolved backend into `pyve.toml
# [env.root]` (fresh AND existing manifest), and the re-init/`--force` gate
# fires on manifest presence (not just `.pyve/config`) so `--force` rebuilds on
# a `.pyve/config`-less v3 project.
#
# The fresh-write path is pure heredoc (no Python dep). The existing-manifest
# update is a structure-preserving tomlkit edit (the sanctioned in-place editor,
# per lib/pyve_env_sync_helper.py); tests that exercise it `skip` when tomlkit is
# absent, mirroring tests/unit/test_env_sync.bats.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    # Honor an externally-provided tomlkit-carrying interpreter (the in-place
    # setter tests need one); otherwise pin the dev python for manifest_load.
    : "${PYVE_PYTHON:=$(python -c 'import sys; print(sys.executable)')}"
    export PYVE_PYTHON
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# tomlkit availability gate for the existing-manifest (in-place edit) tests.
_tomlkit_or_skip() {
    "$PYVE_PYTHON" -c 'import tomlkit' 2>/dev/null \
        || skip "tomlkit not available (set PYVE_PYTHON to a tomlkit-carrying interpreter)"
}

# Body of [env.root] only (awk flag-scope, matching test_init_pyve_toml.bats).
_root_block() {
    awk '/^\[env\.root\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml
}

# ────────────────────────────────────────────────────────────────────
# Fresh write — the resolved backend lands in [env.root]
# ────────────────────────────────────────────────────────────────────

@test "_init_write_pyve_toml: with a backend arg emits backend in [env.root]" {
    _init_write_pyve_toml "demo" "micromamba"
    run _root_block
    [[ "$output" == *'backend = "micromamba"'* ]]
}

@test "_init_write_pyve_toml: with a backend arg keeps purpose = utility" {
    _init_write_pyve_toml "demo" "venv"
    run _root_block
    [[ "$output" == *'purpose = "utility"'* ]]
    [[ "$output" == *'backend = "venv"'* ]]
}

@test "_init_write_pyve_toml: no backend arg → legacy backend-less template (back-compat)" {
    _init_write_pyve_toml "demo"
    run _root_block
    [[ "$output" != *'backend ='* ]]
}

@test "_init_write_pyve_toml: backend-bearing manifest validates clean under manifest_load" {
    _init_write_pyve_toml "demo" "micromamba"
    manifest_load "$(pwd)/pyve.toml"
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    [ "${PYVE_ENV_BACKEND[0]}" = "micromamba" ]
}

@test "_init_write_pyve_toml_polyglot: records the root backend" {
    _init_write_pyve_toml_polyglot "demo" "frontend" "venv"
    run _root_block
    [[ "$output" == *'backend = "venv"'* ]]
}

# ────────────────────────────────────────────────────────────────────
# Existing manifest — set/update [env.root].backend in place (tomlkit)
# ────────────────────────────────────────────────────────────────────

@test "_init_manifest_ensure_root_backend: backfills a missing backend on an existing manifest" {
    _tomlkit_or_skip
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"

[env.testenv]
purpose = "test"
default = true
EOF
    _init_manifest_ensure_root_backend "micromamba"
    manifest_load "$(pwd)/pyve.toml"
    [ "${PYVE_ENV_BACKEND[0]}" = "micromamba" ]
    # The other envs survive the in-place edit.
    [ "${#PYVE_ENV_NAMES[@]}" -eq 2 ]
    [ "${PYVE_ENV_NAMES[1]}" = "testenv" ]
}

@test "_init_manifest_ensure_root_backend: idempotent when already correct" {
    _tomlkit_or_skip
    _init_write_pyve_toml "demo" "venv"
    local before; before="$(cat pyve.toml)"
    _init_manifest_ensure_root_backend "venv"
    local after; after="$(cat pyve.toml)"
    [ "$before" = "$after" ]
}

@test "_init_manifest_ensure_root_backend: missing pyve.toml is a silent no-op" {
    run _init_manifest_ensure_root_backend "venv"
    [ "$status" -eq 0 ]
    [ ! -f pyve.toml ]
}

# ────────────────────────────────────────────────────────────────────
# Re-init gate fires on manifest presence (the --force-on-v3 fix)
# ────────────────────────────────────────────────────────────────────

@test "_init_is_reinit: false when only .pyve/config is present (v2, unmigrated)" {
    # pyve.toml is the sole declaration; a legacy .pyve/config-only project is
    # not recognized as an initialized (re-init) project.
    mkdir -p .pyve
    printf 'pyve_version: "1.0.0"\nbackend: venv\n' > .pyve/config
    run _init_is_reinit
    [ "$status" -ne 0 ]
}

@test "_init_is_reinit: true when only pyve.toml is present (v3-native project)" {
    _init_write_pyve_toml "demo" "venv"
    [ ! -e .pyve/config ]
    run _init_is_reinit
    [ "$status" -eq 0 ]
}

@test "_init_is_reinit: false on a pristine directory (neither marker)" {
    run _init_is_reinit
    [ "$status" -ne 0 ]
}
