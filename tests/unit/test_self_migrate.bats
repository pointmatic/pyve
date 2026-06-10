#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve self migrate` — v2 → v3 migration command.
#
# Scope: unit-test each helper in isolation, plus a few end-to-end
# self_migrate() flows that exercise the orchestrator without
# actually invoking init_project (the rebuild step is exercised by
# the dispatcher in integration; here we use --no-rebuild to keep
# tests fast and hermetic).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"
    # Capture absolute python BEFORE create_test_dir cd's away
    # (same asdf-shim guard as N.e/N.f tests).
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# ----- helpers ----------------------------------------------------

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

_write_v2_micromamba_config() {
    mkdir -p .pyve
    cat > .pyve/config <<EOF
pyve_version: "2.8.0"
backend: micromamba
micromamba:
  env_name: myproject
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

[tool.pyve.testenvs.smoke]
backend = "micromamba"
manifest = "smoke-env.yml"
lazy = true

[tool.pyve.testenvs.integration]
backend = "venv"
requirements = ["pytest", "httpx"]
EOF
}

# ============================================================
# _self_migrate_detect_v2_sources
# ============================================================

@test "_self_migrate_detect_v2_sources: 0 when .pyve/config exists alone" {
    _write_v2_venv_config
    run _self_migrate_detect_v2_sources
    [ "$status" -eq 0 ]
}

@test "_self_migrate_detect_v2_sources: 0 when [tool.pyve.testenvs.*] in pyproject alone" {
    _write_v2_pyproject_with_testenvs
    run _self_migrate_detect_v2_sources
    [ "$status" -eq 0 ]
}

@test "_self_migrate_detect_v2_sources: 0 when .pyve/testenvs/ exists alone" {
    mkdir -p .pyve/testenvs/testenv/venv
    run _self_migrate_detect_v2_sources
    [ "$status" -eq 0 ]
}

@test "_self_migrate_detect_v2_sources: 1 when no v2 sources" {
    run _self_migrate_detect_v2_sources
    [ "$status" -eq 1 ]
}

@test "_self_migrate_detect_v2_sources: 1 when pyve.toml present (already migrated)" {
    _write_v2_venv_config
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
EOF
    run _self_migrate_detect_v2_sources
    [ "$status" -eq 1 ]
}

@test "_self_migrate_detect_v2_sources: 1 when only [tool.pyve] (no testenvs subkey) in pyproject" {
    cat > pyproject.toml <<'EOF'
[tool.pyve]
some_other_key = true
EOF
    run _self_migrate_detect_v2_sources
    [ "$status" -eq 1 ]
}

# ============================================================
# _self_migrate_read_legacy + _self_migrate_render_pyve_toml
# ============================================================

@test "_self_migrate_render_pyve_toml: minimal venv project (no testenvs declared)" {
    _write_v2_venv_config
    _self_migrate_read_legacy
    local out; out="$(_self_migrate_render_pyve_toml demo)"
    [[ "$out" == *'pyve_schema = "3.0"'* ]]
    [[ "$out" == *'[project]'* ]]
    [[ "$out" == *'name = "demo"'* ]]
    [[ "$out" == *'[env.root]'* ]]
    [[ "$out" == *'purpose = "utility"'* ]]
    [[ "$out" == *'backend = "venv"'* ]]
    # Implicit default testenv (matches N.e fresh-init behavior).
    [[ "$out" == *'[env.testenv]'* ]]
    [[ "$out" == *'default = true'* ]]
}

@test "_self_migrate_render_pyve_toml: micromamba backend in [env.root]" {
    _write_v2_micromamba_config
    _self_migrate_read_legacy
    local out; out="$(_self_migrate_render_pyve_toml demo)"
    [[ "$out" == *'[env.root]'* ]]
    awk '/^\[env\.root\]$/{flag=1;next} /^\[/{flag=0} flag' <(printf '%s\n' "$out") \
        | grep -qE '^backend = "micromamba"$'
}

@test "_self_migrate_render_pyve_toml: declared testenvs land as [env.<name>] blocks" {
    _write_v2_pyproject_with_testenvs
    _self_migrate_read_legacy
    local out; out="$(_self_migrate_render_pyve_toml demo)"
    [[ "$out" == *'[env.testenv]'* ]]
    [[ "$out" == *'[env.smoke]'* ]]
    [[ "$out" == *'[env.integration]'* ]]
    # Each testenv has purpose = "test".
    local count
    count="$(grep -c '^purpose = "test"$' <<<"$out")"
    [ "$count" -ge 3 ]
}

@test "_self_migrate_render_pyve_toml: lazy = true preserved" {
    _write_v2_pyproject_with_testenvs
    _self_migrate_read_legacy
    local out; out="$(_self_migrate_render_pyve_toml demo)"
    # Smoke env was declared lazy = true.
    awk '/^\[env\.smoke\]$/{flag=1;next} /^\[/{flag=0} flag' <(printf '%s\n' "$out") \
        | grep -qE '^lazy = true$'
}

@test "_self_migrate_render_pyve_toml: extra/manifest/requirements preserved per env" {
    _write_v2_pyproject_with_testenvs
    _self_migrate_read_legacy
    local out; out="$(_self_migrate_render_pyve_toml demo)"
    # testenv had extra = "dev"
    awk '/^\[env\.testenv\]$/{flag=1;next} /^\[/{flag=0} flag' <(printf '%s\n' "$out") \
        | grep -qE '^extra = "dev"$'
    # smoke had manifest = "smoke-env.yml"
    awk '/^\[env\.smoke\]$/{flag=1;next} /^\[/{flag=0} flag' <(printf '%s\n' "$out") \
        | grep -qE '^manifest = "smoke-env\.yml"$'
    # integration had requirements = ["pytest", "httpx"]
    awk '/^\[env\.integration\]$/{flag=1;next} /^\[/{flag=0} flag' <(printf '%s\n' "$out") \
        | grep -qE '^requirements = \[.*"pytest".*"httpx".*\]$'
}

@test "_self_migrate_render_pyve_toml: output parses + validates clean under manifest_load" {
    _write_v2_pyproject_with_testenvs
    _write_v2_venv_config
    _self_migrate_read_legacy
    _self_migrate_render_pyve_toml demo > pyve.toml
    # Validation goes through the Python tomllib helper which exit-2s on errors.
    manifest_load pyve.toml
    [ "$PYVE_PROJECT_NAME" = "demo" ]
    [ "${#PYVE_ENV_NAMES[@]}" -ge 4 ]   # root + testenv + smoke + integration
}

@test "_self_migrate_render_pyve_toml: 'testenv' is the default = true env" {
    _write_v2_pyproject_with_testenvs
    _self_migrate_read_legacy
    _self_migrate_render_pyve_toml demo > pyve.toml
    manifest_load pyve.toml
    # find index of "testenv"
    local idx
    for ((idx=0; idx<${#PYVE_ENV_NAMES[@]}; idx++)); do
        if [[ "${PYVE_ENV_NAMES[$idx]}" == "testenv" ]]; then
            break
        fi
    done
    [ "${PYVE_ENV_DEFAULT[$idx]}" = "1" ]
}

# ============================================================
# _self_migrate_backup
# ============================================================

@test "_self_migrate_backup: .pyve/config → .pyve/.v2-legacy/pyve-config" {
    _write_v2_venv_config
    _self_migrate_backup false
    [ -f .pyve/.v2-legacy/pyve-config ]
    [ ! -f .pyve/config ]
    grep -q "backend: venv" .pyve/.v2-legacy/pyve-config
}

@test "_self_migrate_backup: .pyve/testenvs/ → .pyve/.v2-legacy/testenvs/" {
    mkdir -p .pyve/testenvs/testenv/venv
    touch .pyve/testenvs/testenv/venv/pyvenv.cfg
    _self_migrate_backup false
    [ -d .pyve/.v2-legacy/testenvs/testenv/venv ]
    [ -f .pyve/.v2-legacy/testenvs/testenv/venv/pyvenv.cfg ]
    [ ! -d .pyve/testenvs ]
}

@test "_self_migrate_backup: extracts [tool.pyve.testenvs.*] from pyproject.toml" {
    _write_v2_pyproject_with_testenvs
    _self_migrate_backup false
    # Backup file holds the testenv blocks.
    grep -qE '^\[tool\.pyve\.testenvs\.testenv\]$' .pyve/.v2-legacy/pyproject-testenvs.toml
    grep -qE '^\[tool\.pyve\.testenvs\.smoke\]$' .pyve/.v2-legacy/pyproject-testenvs.toml
    grep -qE '^\[tool\.pyve\.testenvs\.integration\]$' .pyve/.v2-legacy/pyproject-testenvs.toml
    # Remainder pyproject.toml lost the testenv blocks but kept [project].
    grep -qE '^\[project\]$' pyproject.toml
    ! grep -qE '^\[tool\.pyve\.testenvs' pyproject.toml
}

@test "_self_migrate_backup: dry_run=true performs no writes" {
    _write_v2_venv_config
    _write_v2_pyproject_with_testenvs
    mkdir -p .pyve/testenvs/testenv/venv
    _self_migrate_backup true
    # Originals all still present.
    [ -f .pyve/config ]
    [ -d .pyve/testenvs ]
    grep -qE '^\[tool\.pyve\.testenvs\.testenv\]$' pyproject.toml
    # No backup directory written.
    [ ! -d .pyve/.v2-legacy ]
}

# ============================================================
# self_migrate orchestrator
# ============================================================

@test "self_migrate: no v2 sources → clean no-op (idempotent on fresh dir)" {
    run self_migrate
    [ "$status" -eq 0 ]
    [[ "$output" == *"No v2 configuration"* ]] || [[ "$output" == *"nothing to migrate"* ]]
}

@test "self_migrate: pyve.toml present + v2 sources → no-op (already migrated)" {
    _write_v2_venv_config
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
EOF
    run self_migrate
    [ "$status" -eq 0 ]
    # Original .pyve/config untouched.
    [ -f .pyve/config ]
    [ ! -d .pyve/.v2-legacy ]
}

@test "self_migrate --no-rebuild: writes pyve.toml + backup, skips init --force" {
    _write_v2_venv_config
    _write_v2_pyproject_with_testenvs
    mkdir -p .pyve/testenvs/testenv/venv
    run self_migrate --no-rebuild
    [ "$status" -eq 0 ]
    [ -f pyve.toml ]
    [ -f .pyve/.v2-legacy/pyve-config ]
    [ -d .pyve/.v2-legacy/testenvs ]
    [ -f .pyve/.v2-legacy/pyproject-testenvs.toml ]
}

@test "self_migrate --dry-run: no disk writes" {
    _write_v2_venv_config
    _write_v2_pyproject_with_testenvs
    run self_migrate --dry-run
    [ "$status" -eq 0 ]
    [ ! -f pyve.toml ]
    [ -f .pyve/config ]
    [ ! -d .pyve/.v2-legacy ]
    grep -qE '^\[tool\.pyve\.testenvs\.' pyproject.toml
}

@test "self_migrate --dry-run: prints what it would do" {
    _write_v2_venv_config
    run self_migrate --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would"* ]] || [[ "$output" == *"would"* ]]
    [[ "$output" == *"pyve.toml"* ]]
}

@test "self_migrate: rejects unknown flag" {
    run self_migrate --bogus
    [ "$status" -ne 0 ]
}

@test "self_migrate: idempotency — second --no-rebuild run is clean no-op" {
    _write_v2_venv_config
    self_migrate --no-rebuild >/dev/null 2>&1
    [ -f pyve.toml ]
    run self_migrate --no-rebuild
    [ "$status" -eq 0 ]
    [[ "$output" == *"already"* ]] || [[ "$output" == *"No v2"* ]] || [[ "$output" == *"nothing"* ]]
}

# ============================================================
# Dispatcher + help
# ============================================================

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
