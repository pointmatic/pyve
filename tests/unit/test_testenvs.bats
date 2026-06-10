#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/envs.sh — the testenv-DX config foundation
# (Story M.g). Reads `[tool.pyve.testenvs]` from `pyproject.toml` via the
# Python tomllib helper, exposes a flat predicate/accessor surface.
#
# Surface under test:
#   read_env_config [<pyproject.toml path>]
#   resolve_env_path <name>
#   validate_env_decl <name>
#   is_env_declared <name>
#   is_env_reserved <name>
#   is_env_lazy <name>
#   list_env_names
#
# Spike decisions live in docs/specs/spike-m-f-testenvs-config.md.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    # Capture an absolute path to a working python BEFORE create_test_dir
    # changes cwd. PATH may carry a relative `.pyve/testenv/venv/bin`
    # (per `pyve testenv run`), so `command -v` returns a relative path
    # that breaks once cwd changes. `sys.executable` is the canonical
    # absolute interpreter path.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ---------- fixture helpers ----------

_fixture_full_config() {
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[tool.pyve.testenvs]
default = "testenv"

[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "src/templates/environment.yml"
lazy = true
TOML
}

_fixture_no_block() {
    cat > pyproject.toml <<'TOML'
[project]
name = "minimal"
version = "0.1.0"
TOML
}

_fixture_bad_backend() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.x]
backend = "uv"
TOML
}

_fixture_conflict() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.x]
backend = "micromamba"
manifest = "env.yml"
requirements = ["dev.txt"]
TOML
}

_fixture_reserved_root() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.root]
requirements = ["dev.txt"]
TOML
}

# ============================================================
# 1. Valid config: arrays populated, predicates respond correctly
# ============================================================

@test "read_env_config: valid config populates default + names + per-env arrays" {
    _fixture_full_config
    # Call directly (no command substitution) so array assignments
    # land in the current shell rather than a discarded subshell.
    read_env_config
    [ -n "${PYVE_TESTENVS_DEFAULT+x}" ]
    [ "$PYVE_TESTENVS_DEFAULT" = "testenv" ]
    # Names array contains both declared envs (order is helper-defined).
    [[ " ${PYVE_TESTENVS_NAMES[*]} " == *" testenv "* ]]
    [[ " ${PYVE_TESTENVS_NAMES[*]} " == *" hardware "* ]]
    # Backend lookup by name.
    [ "$(_env_backend_of hardware)" = "micromamba" ]
    [ "$(_env_backend_of testenv)" = "venv" ]
}

@test "list_env_names: prints declared + reserved 'root' (root not in declared)" {
    _fixture_full_config
    read_env_config
    run list_env_names
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenv"* ]]
    [[ "$output" == *"hardware"* ]]
    [[ "$output" == *"root"* ]]
}

# ============================================================
# 2. Missing config: implicit default (no pyproject.toml AND no [tool.pyve.testenvs])
# ============================================================

@test "read_env_config: no pyproject.toml → implicit testenv default" {
    # No pyproject.toml in test dir.
    read_env_config
    [ "$PYVE_TESTENVS_DEFAULT" = "testenv" ]
    [ "${#PYVE_TESTENVS_NAMES[@]}" -eq 1 ]
    [ "${PYVE_TESTENVS_NAMES[0]}" = "testenv" ]
    is_env_declared testenv
    [ "$(_env_backend_of testenv)" = "venv" ]
}

@test "read_env_config: pyproject.toml without [tool.pyve.testenvs] → implicit testenv default" {
    _fixture_no_block
    read_env_config
    [ "$PYVE_TESTENVS_DEFAULT" = "testenv" ]
    [ "${#PYVE_TESTENVS_NAMES[@]}" -eq 1 ]
    [ "${PYVE_TESTENVS_NAMES[0]}" = "testenv" ]
}

# ============================================================
# 3. Invalid backend → helper exits non-zero, message identifies field
# ============================================================

@test "read_env_config: invalid backend errors with prefix + substring" {
    _fixture_bad_backend
    run read_env_config
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.testenvs.x.backend"* ]]
    [[ "$output" == *"unknown backend"* ]]
}

# ============================================================
# 4. manifest + requirements conflict → helper errors
# ============================================================

@test "read_env_config: manifest + requirements conflict errors" {
    _fixture_conflict
    run read_env_config
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.testenvs.x"* ]]
    [[ "$output" == *"only one of"* ]]
}

# ============================================================
# 5. Reserved-name violation (user declares [tool.pyve.testenvs.root])
# ============================================================

@test "read_env_config: redeclaring reserved 'root' is an error" {
    _fixture_reserved_root
    run read_env_config
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.testenvs.root"* ]]
    [[ "$output" == *"reserved"* ]]
}

# ============================================================
# 6. lazy = true propagation
# ============================================================

@test "is_env_lazy: returns 0 for lazy env, 1 for non-lazy" {
    _fixture_full_config
    read_env_config
    is_env_lazy hardware       # lazy = true → 0 (success)
    ! is_env_lazy testenv      # lazy unset → 1
}

# ============================================================
# 7. Predicates and resolver — happy paths
# ============================================================

@test "is_env_reserved: root and testenv are reserved; other names are not" {
    _fixture_full_config
    read_env_config
    is_env_reserved root
    is_env_reserved testenv
    ! is_env_reserved hardware
    ! is_env_reserved bogus
}

@test "is_env_declared: only declared envs return 0" {
    _fixture_full_config
    read_env_config
    is_env_declared testenv
    is_env_declared hardware
    ! is_env_declared root         # root is reserved, not declared
    ! is_env_declared nonexistent
}

@test "validate_env_decl: passes for reserved or declared; fails for unknown" {
    _fixture_full_config
    read_env_config
    validate_env_decl testenv
    validate_env_decl hardware
    validate_env_decl root         # reserved counts as legal
    run validate_env_decl bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
}

@test "resolve_env_path: per-env layout matches plan doc TC-M.2" {
    _fixture_full_config
    read_env_config
    # testenv: venv-backed → .pyve/envs/testenv/venv
    [ "$(resolve_env_path testenv)" = ".pyve/envs/testenv/venv" ]
    # hardware: micromamba-backed → .pyve/envs/hardware/conda
    [ "$(resolve_env_path hardware)" = ".pyve/envs/hardware/conda" ]
}

@test "resolve_env_path: 'root' resolves to the project main venv path" {
    _fixture_full_config
    read_env_config
    [ "$(resolve_env_path root)" = ".venv" ]
}

# ============================================================
# 8. Empty-array safety under `set -u` (project-essentials rule)
# ============================================================
# Sourcing lib/envs.sh and calling each surface function from a
# fresh shell with `set -euo pipefail` must not raise 'unbound variable'.
# This catches the L.k.7-class regression on an empty config.

@test "no 'unbound variable' under 'set -euo pipefail' (no config; bash 3.2 trap)" {
    # Run lib/envs.sh's full surface from a clean strict shell and
    # capture any stderr 'unbound variable' diagnostics.
    output="$(/bin/bash -c "
        set -euo pipefail
        export PYVE_ROOT='$PYVE_ROOT'
        source '$PYVE_ROOT/lib/envs.sh'
        read_env_config
        list_env_names >/dev/null
        is_env_declared testenv || true
        is_env_reserved root || true
        is_env_lazy testenv || true
        validate_env_decl testenv >/dev/null
        resolve_env_path testenv >/dev/null
    " 2>&1)" || true
    [[ "$output" != *"unbound variable"* ]] || {
        echo "stderr contained 'unbound variable':"
        echo "$output"
        false
    }
}
