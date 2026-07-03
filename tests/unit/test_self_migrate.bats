#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve self migrate` — reserved migration verb.
#
# The v2 (.pyve/config / [tool.pyve.testenvs.*]) migration bridge was
# removed once v2 support ended. `self migrate` is kept as a stable
# home for a future schema migration (e.g. v3 → v4), but for the
# current schema it is an inert no-op: it recognizes no legacy sources,
# writes nothing, and never creates a .pyve/.v2-legacy backup.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# ----- helpers ----------------------------------------------------

# A v2 project shape the OLD migrator would have converted. The stub
# must ignore it entirely.
_write_v2_venv_config() {
    mkdir -p .pyve
    cat > .pyve/config <<EOF
pyve_version: "2.8.0"
backend: venv
venv:
  directory: .venv
python:
  version: 3.13.7
EOF
}

_write_v2_pyproject_with_testenvs() {
    cat > pyproject.toml <<'EOF'
[project]
name = "demo"
version = "0.1.0"

[tool.pyve.testenvs.testenv]
backend = "venv"
extra = "dev"
EOF
}

# ============================================================
# Stub behavior — no migration for the current schema
# ============================================================

@test "self_migrate: fresh dir → clean no-op, exits 0" {
    run self_migrate
    [ "$status" -eq 0 ]
    [[ "$output" == *"No migration applies"* ]]
}

@test "self_migrate: v2 .pyve/config present → writes NOTHING (reserved stub)" {
    _write_v2_venv_config
    run self_migrate
    [ "$status" -eq 0 ]
    # The v2 bridge is gone: no pyve.toml is synthesized and no backup
    # tree is created. The legacy file is left exactly as-is.
    [ ! -f pyve.toml ]
    [ ! -d .pyve/.v2-legacy ]
    [ -f .pyve/config ]
    [[ "$output" == *"No migration applies"* ]]
}

@test "self_migrate: v2 [tool.pyve.testenvs.*] present → no migration performed" {
    _write_v2_pyproject_with_testenvs
    run self_migrate
    [ "$status" -eq 0 ]
    [ ! -f pyve.toml ]
    [ ! -d .pyve/.v2-legacy ]
    # pyproject.toml is untouched — the testenv blocks are not extracted.
    grep -qE '^\[tool\.pyve\.testenvs\.testenv\]$' pyproject.toml
}

@test "self_migrate: never invokes init_project" {
    _write_v2_venv_config
    init_project() { printf 'called\n' > .init_was_called; }
    run self_migrate
    [ "$status" -eq 0 ]
    [ ! -f .init_was_called ]
}

# ============================================================
# Absence guards — the v2 bridge helpers are gone
# ============================================================

@test "the v2 migrator helper functions no longer exist" {
    for fn in _self_migrate_detect_v2_sources _self_migrate_read_legacy \
              _self_migrate_render_pyve_toml _self_migrate_extract_pyproject_testenvs \
              _self_migrate_backup _self_migrate_summary; do
        run declare -F "$fn"
        [ "$status" -ne 0 ] || {
            echo "still defined: $fn"
            return 1
        }
    done
}

@test "the dead .pyve/config helpers no longer exist" {
    run declare -F read_config_value
    [ "$status" -ne 0 ]
    run declare -F config_file_exists
    [ "$status" -ne 0 ]
}

@test "no lib/ or pyve.sh code references the removed .pyve/config helpers" {
    run grep -rnE 'read_config_value|config_file_exists' \
        "$PYVE_ROOT/lib" "$PYVE_ROOT/pyve.sh"
    [ "$status" -ne 0 ]
}

@test "the v2 soft banner is gone from pyve.sh" {
    run grep -nE '_pyve_maybe_show_v2_banner|_pyve_v2_banner_sentinel_path' \
        "$PYVE_ROOT/pyve.sh"
    [ "$status" -ne 0 ]
}

# ============================================================
# Verb + help are preserved (reserved for future migrations)
# ============================================================

@test "self_migrate --help: shows help" {
    run self_migrate --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self migrate"* ]]
}

@test "show_self_migrate_help: function exists and prints something" {
    run show_self_migrate_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self migrate"* ]]
}

@test "self_command migrate --help routes to show_self_migrate_help" {
    run self_command migrate --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self migrate"* ]]
}

@test "show_self_help lists migrate" {
    run show_self_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"migrate"* ]]
}
