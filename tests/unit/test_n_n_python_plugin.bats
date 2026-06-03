#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.n — Python plugin module + scaffold-time detection hook.
#
# The Python plugin is the first reference implementation of the
# plugin contract from N.k. N.n ships THREE hooks (manifest_namespace,
# register_backends, detect) plus the bp activate-hook shims absorbed
# from N.l's transition state. The lifecycle hooks (init/purge/update/
# check/status/run/test) stay as no-op defaults; they land in N.o-N.r.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Plugin contract — manifest namespace
# ════════════════════════════════════════════════════════════════════

@test "python plugin: manifest_namespace returns 'python'" {
    run python_pyve_plugin_manifest_namespace
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
}

# ════════════════════════════════════════════════════════════════════
# Plugin contract — register_backends registers venv + micromamba.
# ════════════════════════════════════════════════════════════════════

@test "python plugin: register_backends registers venv as virtualized" {
    python_pyve_plugin_register_backends
    run bp_lookup venv
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
    run bp_category venv
    [ "$output" = "virtualized" ]
}

@test "python plugin: register_backends registers micromamba as virtualized" {
    python_pyve_plugin_register_backends
    run bp_lookup micromamba
    [ "$status" -eq 0 ]
    [ "$output" = "python" ]
    run bp_category micromamba
    [ "$output" = "virtualized" ]
}

@test "python plugin: register_backends is idempotent (safe to re-fire)" {
    python_pyve_plugin_register_backends
    python_pyve_plugin_register_backends
    run bp_list
    # Each backend appears exactly once.
    [[ "$(printf '%s' "$output")" == $'venv\nmicromamba' ]]
}

# ════════════════════════════════════════════════════════════════════
# Backend-provider activate shims (absorbed from N.l).
# ════════════════════════════════════════════════════════════════════

@test "python plugin: venv_pyve_bp_activate is defined" {
    declare -F venv_pyve_bp_activate >/dev/null
}

@test "python plugin: micromamba_pyve_bp_activate is defined" {
    declare -F micromamba_pyve_bp_activate >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# Plugin contract — detect hook.
# ════════════════════════════════════════════════════════════════════
#
# Signal classes:
#   Python: pyproject.toml | requirements*.txt | setup.py | *.py
#   Conda:  environment*.yml | conda-lock.yml
#
# Output:
#   - both classes present → "ambiguous"
#   - only conda           → "micromamba"
#   - only python          → "venv"
#   - neither              → "none"
# ────────────────────────────────────────────────────────────────────

# ── Python-only signals → "venv" ──

@test "detect: pyproject.toml → venv" {
    : > pyproject.toml
    run python_pyve_plugin_detect
    [ "$output" = "venv" ]
}

@test "detect: requirements.txt → venv" {
    : > requirements.txt
    run python_pyve_plugin_detect
    [ "$output" = "venv" ]
}

@test "detect: requirements-dev.txt (glob) → venv" {
    : > requirements-dev.txt
    run python_pyve_plugin_detect
    [ "$output" = "venv" ]
}

@test "detect: setup.py → venv" {
    : > setup.py
    run python_pyve_plugin_detect
    [ "$output" = "venv" ]
}

@test "detect: bare *.py file → venv" {
    : > foo.py
    run python_pyve_plugin_detect
    [ "$output" = "venv" ]
}

# ── Conda-only signals → "micromamba" ──

@test "detect: environment.yml → micromamba" {
    : > environment.yml
    run python_pyve_plugin_detect
    [ "$output" = "micromamba" ]
}

@test "detect: environment-mac.yml (glob) → micromamba" {
    : > environment-mac.yml
    run python_pyve_plugin_detect
    [ "$output" = "micromamba" ]
}

@test "detect: conda-lock.yml → micromamba" {
    : > conda-lock.yml
    run python_pyve_plugin_detect
    [ "$output" = "micromamba" ]
}

# ── Both classes present → "ambiguous" ──

@test "detect: pyproject.toml + environment.yml → ambiguous" {
    : > pyproject.toml
    : > environment.yml
    run python_pyve_plugin_detect
    [ "$output" = "ambiguous" ]
}

@test "detect: requirements.txt + conda-lock.yml → ambiguous" {
    : > requirements.txt
    : > conda-lock.yml
    run python_pyve_plugin_detect
    [ "$output" = "ambiguous" ]
}

# ── No Python signals → "none" ──

@test "detect: empty directory → none" {
    run python_pyve_plugin_detect
    [ "$output" = "none" ]
}

@test "detect: only non-Python files (README.md) → none" {
    : > README.md
    : > LICENSE
    run python_pyve_plugin_detect
    [ "$output" = "none" ]
}

# ════════════════════════════════════════════════════════════════════
# Drop-in refactor: detect_backend_from_files (the existing public API
# in lib/backend_detect.sh) still returns the same values as before.
# ════════════════════════════════════════════════════════════════════

@test "detect_backend_from_files: pyproject.toml → venv (unchanged)" {
    : > pyproject.toml
    run detect_backend_from_files
    [ "$output" = "venv" ]
}

@test "detect_backend_from_files: environment.yml → micromamba (unchanged)" {
    : > environment.yml
    run detect_backend_from_files
    [ "$output" = "micromamba" ]
}

@test "detect_backend_from_files: both → ambiguous (unchanged)" {
    : > pyproject.toml
    : > environment.yml
    run detect_backend_from_files
    [ "$output" = "ambiguous" ]
}

@test "detect_backend_from_files: empty → none (unchanged)" {
    run detect_backend_from_files
    [ "$output" = "none" ]
}

# ════════════════════════════════════════════════════════════════════
# End-to-end: plugin_dispatch python detect routes correctly.
# ════════════════════════════════════════════════════════════════════

@test "plugin_dispatch python detect: routes to python_pyve_plugin_detect" {
    plugin_register python
    : > pyproject.toml
    run plugin_dispatch python detect
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}
