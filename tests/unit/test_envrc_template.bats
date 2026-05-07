#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the uniform `.envrc` template helper (Story K.a.2 / v2.3.2).
#
# Contract: `write_envrc_template <rel_bin_dir> <sentinel_var> <rel_env_root>
#                                  <backend_name> <env_name>` writes an .envrc
# whose shape is identical across backends — only the bin dir, sentinel var,
# env root, backend label, and env name differ. The file must remain
# project-directory-independent: no `$(pwd)` baked in at generation time.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/ui/core.sh"
    create_test_dir

    VERSION_MANAGER=""
    unset PYVE_NO_ASDF_COMPAT
}

teardown() {
    unset PYVE_NO_ASDF_COMPAT
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# Shape: uniform four-line template, same across backends
# ────────────────────────────────────────────────────────────────────

@test "write_envrc_template: emits PATH_add (not hand-rolled export PATH=)" {
    run write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"
    [ "$status" -eq 0 ]

    assert_file_exists ".envrc"
    assert_file_contains ".envrc" 'PATH_add ".venv/bin"'

    if grep -qE '^export PATH=' ".envrc"; then
        echo "Expected .envrc to use PATH_add, not hand-rolled 'export PATH='" >&2
        cat .envrc >&2
        return 1
    fi
}

@test "write_envrc_template: emits backend-native sentinel export with \$PWD prefix for relative paths" {
    run write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"
    [ "$status" -eq 0 ]

    # Literal "$PWD/" must appear in the file (not an expanded absolute path).
    grep -qF 'export VIRTUAL_ENV="$PWD/.venv"' .envrc || {
        echo "Expected literal 'export VIRTUAL_ENV=\"\$PWD/.venv\"' in .envrc" >&2
        cat .envrc >&2
        return 1
    }
}

@test "write_envrc_template: micromamba uses CONDA_PREFIX sentinel" {
    run write_envrc_template ".pyve/envs/myproj/bin" "CONDA_PREFIX" ".pyve/envs/myproj" "micromamba" "myproj"
    [ "$status" -eq 0 ]

    grep -qF 'PATH_add ".pyve/envs/myproj/bin"' .envrc
    grep -qF 'export CONDA_PREFIX="$PWD/.pyve/envs/myproj"' .envrc
}

@test "write_envrc_template: exports PYVE_BACKEND and PYVE_ENV_NAME" {
    run write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"
    [ "$status" -eq 0 ]

    assert_file_contains ".envrc" 'export PYVE_BACKEND="venv"'
    assert_file_contains ".envrc" 'export PYVE_ENV_NAME="myproj"'
}

@test "write_envrc_template: exports PYVE_PROMPT_PREFIX parameterised by backend + env_name" {
    run write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"
    [ "$status" -eq 0 ]

    grep -qF 'export PYVE_PROMPT_PREFIX="(venv:myproj) "' .envrc
}

@test "write_envrc_template: does NOT source any activate script" {
    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    if grep -qE 'source.*activate|\.\ .*activate' ".envrc"; then
        echo "Expected .envrc to omit 'source .venv/bin/activate' — activation is now via PATH_add + sentinel." >&2
        cat .envrc >&2
        return 1
    fi
}

@test "write_envrc_template: includes the dotenv block" {
    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    assert_file_contains ".envrc" 'if \[\[ -f ".env" \]\]'
    assert_file_contains ".envrc" "dotenv"
}

# ────────────────────────────────────────────────────────────────────
# Absolute-only invariant: no relative PATH literal in the effective PATH
# ────────────────────────────────────────────────────────────────────

@test "write_envrc_template: contains no relative 'export PATH=' literal" {
    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    # The whole point: PATH must never be set via a hand-rolled export with
    # a relative entry. PATH_add is the only path-mutating primitive allowed.
    if grep -qE '^export PATH=' ".envrc"; then
        echo "Found forbidden 'export PATH=' in .envrc" >&2
        cat .envrc >&2
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# Idempotency and pre-existing .envrc handling
# ────────────────────────────────────────────────────────────────────

@test "write_envrc_template: skips write when .envrc already exists" {
    cat > .envrc << 'EOF'
# user-customized
export CUSTOM_VAR=1
EOF
    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    # Existing content preserved; template not re-written.
    assert_file_contains ".envrc" "user-customized"
    assert_file_contains ".envrc" "export CUSTOM_VAR=1"
    if grep -qF 'PATH_add' ".envrc"; then
        echo "Expected helper NOT to overwrite a pre-existing .envrc" >&2
        cat .envrc >&2
        return 1
    fi
}

@test "write_envrc_template: two calls with same args produce a byte-identical file (asdf active)" {
    VERSION_MANAGER="asdf"

    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"
    local md5_first
    md5_first="$(md5 -q .envrc 2>/dev/null || md5sum .envrc | awk '{print $1}')"

    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"
    local md5_second
    md5_second="$(md5 -q .envrc 2>/dev/null || md5sum .envrc | awk '{print $1}')"

    [ "$md5_first" = "$md5_second" ]
}

# ────────────────────────────────────────────────────────────────────
# asdf compat guard composes with the uniform template
# ────────────────────────────────────────────────────────────────────

@test "write_envrc_template: appends asdf guard when is_asdf_active" {
    VERSION_MANAGER="asdf"

    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    assert_file_contains ".envrc" "Prevent asdf Python plugin from reshimming"
    assert_file_contains ".envrc" "export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1"
}

@test "write_envrc_template: omits asdf guard when VERSION_MANAGER=pyenv" {
    VERSION_MANAGER="pyenv"

    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    if grep -qF "ASDF_PYTHON_PLUGIN_DISABLE_RESHIM" ".envrc"; then
        echo "Expected no asdf guard when VERSION_MANAGER=pyenv" >&2
        cat .envrc >&2
        return 1
    fi
}

@test "write_envrc_template: omits asdf guard when PYVE_NO_ASDF_COMPAT=1" {
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT=1

    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    if grep -qF "ASDF_PYTHON_PLUGIN_DISABLE_RESHIM" ".envrc"; then
        echo "Expected no asdf guard when PYVE_NO_ASDF_COMPAT=1" >&2
        cat .envrc >&2
        return 1
    fi
}

@test "write_envrc_template: asdf guard migrates onto a pre-existing .envrc lacking it" {
    VERSION_MANAGER="asdf"

    cat > .envrc << 'EOF'
# legacy pyve .envrc, no asdf guard
PATH_add ".venv/bin"
EOF

    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    assert_file_contains ".envrc" "legacy pyve .envrc"
    assert_file_contains ".envrc" "Prevent asdf Python plugin from reshimming"
    assert_file_contains ".envrc" "export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1"
}

# ────────────────────────────────────────────────────────────────────
# Project-dir independence: literal file must not bake in an absolute
# path under the test temp dir.
# ────────────────────────────────────────────────────────────────────

@test "write_envrc_template: does not bake \$(pwd) into the generated file" {
    write_envrc_template ".venv/bin" "VIRTUAL_ENV" ".venv" "venv" "myproj"

    # The project dir absolute path (TEST_DIR) must NOT appear literally.
    if grep -qF "$TEST_DIR" ".envrc"; then
        echo "Expected .envrc to not contain the absolute project dir '$TEST_DIR'" >&2
        cat .envrc >&2
        return 1
    fi
}
