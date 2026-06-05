#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.i — v3.0-only read-compat layer in lib/manifest.sh.
#
# When pyve.toml is absent but legacy sources are present
# (.pyve/config and/or [tool.pyve.testenvs.*]), manifest_load
# synthesizes the v3 array shape so the rest of pyve sees a
# uniform v3-style state regardless of whether the project
# has migrated. The synthesis path emits a one-shot
# deprecation warning per shell.
#
# The read-compat path is marked `# v3.0-only: remove in N-10`
# in lib/manifest.sh so the eventual sweep is mechanical.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # lib/envs.sh needed for read_env_config (used by the synthesis).
    source "$PYVE_ROOT/lib/envs.sh"
    # Capture absolute python before chdir.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    # Confine the deprecation-warn sentinel to the test sandbox.
    export HOME="$TEST_DIR/home"
    export XDG_STATE_HOME="$TEST_DIR/state"
    mkdir -p "$HOME" "$XDG_STATE_HOME"
    # Each @test gets its own session key so memoization is per-test.
    export PYVE_V2_BANNER_SESSION="bats-$BATS_TEST_NUMBER-$$"
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# ----- fixtures ---------------------------------------------------

_write_v2_venv_config() {
    mkdir -p .pyve
    cat > .pyve/config <<'EOF'
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
    cat > .pyve/config <<'EOF'
pyve_version: "2.8.0"
backend: micromamba
micromamba:
  env_name: myproject
EOF
}

_write_v2_pyproject_testenvs() {
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
EOF
}

_write_v3_manifest() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
EOF
}

# ----- happy path: synthesis from legacy ------------------------

@test "manifest_load: v2 venv config alone → synthesizes [env.root] with backend=venv" {
    _write_v2_venv_config
    manifest_load 2>/dev/null
    [ "$PYVE_SCHEMA_VERSION" = "3.0" ]
    # First env is root.
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    [ "${PYVE_ENV_PURPOSE[0]}" = "utility" ]
    [ "${PYVE_ENV_BACKEND[0]}" = "venv" ]
}

@test "manifest_load: v2 micromamba config → root backend = micromamba" {
    _write_v2_micromamba_config
    manifest_load 2>/dev/null
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    [ "${PYVE_ENV_BACKEND[0]}" = "micromamba" ]
}

@test "manifest_load: [tool.pyve.testenvs.*] alone → synthesizes [env.root] + [env.<name>] per testenv" {
    _write_v2_pyproject_testenvs
    manifest_load 2>/dev/null
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    # Subsequent envs include the declared testenvs (order may vary).
    local found_testenv=0 found_smoke=0
    local i
    for ((i=0; i<${#PYVE_ENV_NAMES[@]}; i++)); do
        [[ "${PYVE_ENV_NAMES[$i]}" == "testenv" ]] && found_testenv=1
        [[ "${PYVE_ENV_NAMES[$i]}" == "smoke" ]] && found_smoke=1
    done
    [ "$found_testenv" -eq 1 ]
    [ "$found_smoke" -eq 1 ]
}

@test "manifest_load: synthesized testenvs all get purpose = 'test'" {
    _write_v2_pyproject_testenvs
    manifest_load 2>/dev/null
    local i
    for ((i=1; i<${#PYVE_ENV_NAMES[@]}; i++)); do
        [ "${PYVE_ENV_PURPOSE[$i]}" = "test" ]
    done
}

@test "manifest_load: synthesized 'testenv' env carries default = 1" {
    _write_v2_pyproject_testenvs
    manifest_load 2>/dev/null
    local i
    for ((i=0; i<${#PYVE_ENV_NAMES[@]}; i++)); do
        if [[ "${PYVE_ENV_NAMES[$i]}" == "testenv" ]]; then
            [ "${PYVE_ENV_DEFAULT[$i]}" = "1" ]
            return 0
        fi
    done
    return 1
}

@test "manifest_load: synthesized testenvs preserve backend / lazy / extra / manifest" {
    _write_v2_pyproject_testenvs
    manifest_load 2>/dev/null
    local i smoke_idx=-1 testenv_idx=-1
    for ((i=0; i<${#PYVE_ENV_NAMES[@]}; i++)); do
        [[ "${PYVE_ENV_NAMES[$i]}" == "smoke" ]] && smoke_idx=$i
        [[ "${PYVE_ENV_NAMES[$i]}" == "testenv" ]] && testenv_idx=$i
    done
    [ "$smoke_idx" -ge 0 ]
    [ "$testenv_idx" -ge 0 ]
    # Smoke: backend = micromamba, lazy = 1, manifest = smoke-env.yml
    [ "${PYVE_ENV_BACKEND[$smoke_idx]}" = "micromamba" ]
    [ "${PYVE_ENV_LAZY[$smoke_idx]}" = "1" ]
    [ "${PYVE_ENV_MANIFEST[$smoke_idx]}" = "smoke-env.yml" ]
    # testenv: backend = venv, extra = dev
    [ "${PYVE_ENV_BACKEND[$testenv_idx]}" = "venv" ]
    [ "${PYVE_ENV_EXTRA[$testenv_idx]}" = "dev" ]
}

@test "manifest_load: both .pyve/config AND [tool.pyve.testenvs.*] → root from config, testenvs from pyproject" {
    _write_v2_micromamba_config
    _write_v2_pyproject_testenvs
    manifest_load 2>/dev/null
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    [ "${PYVE_ENV_BACKEND[0]}" = "micromamba" ]
    # At least 3 envs total (root + testenv + smoke).
    [ "${#PYVE_ENV_NAMES[@]}" -ge 3 ]
}

# ----- v3 wins when pyve.toml is present --------------------------

@test "manifest_load: pyve.toml present + legacy sources → v3 path wins (no synthesis)" {
    _write_v3_manifest
    _write_v2_venv_config
    _write_v2_pyproject_testenvs
    manifest_load 2>/dev/null
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    # The v3 manifest declares only [env.root]; synthesis would have
    # also added testenvs from pyproject. Asserting that the testenvs
    # are absent proves pyve.toml took priority.
    [ "${#PYVE_ENV_NAMES[@]}" -eq 1 ]
}

# ----- empty config branch --------------------------------------

@test "manifest_load: no manifest + no legacy sources → empty config (no synthesis)" {
    manifest_load 2>/dev/null
    [ "${#PYVE_ENV_NAMES[@]}" -eq 0 ]
}

@test "manifest_load: bare .pyve/testenvs/ on disk (no other v2 source) → empty (state, not config)" {
    mkdir -p .pyve/testenvs/testenv/venv
    manifest_load 2>/dev/null
    [ "${#PYVE_ENV_NAMES[@]}" -eq 0 ]
}

# ----- deprecation warning --------------------------------------

@test "deprecation warn: fires once per shell on first synthesis" {
    _write_v2_venv_config
    local stderr
    stderr="$(manifest_load 2>&1 1>/dev/null)"
    [[ "$stderr" == *"legacy"* ]] || [[ "$stderr" == *"deprecat"* ]] || [[ "$stderr" == *"v3.1"* ]]
}

@test "deprecation warn: silent on second manifest_load in the same session" {
    _write_v2_venv_config
    manifest_load 2>/dev/null  # primes the sentinel
    local stderr
    stderr="$(manifest_load 2>&1 1>/dev/null)"
    # Should be empty (or at least not contain a fresh warning).
    [[ "$stderr" != *"v3.1"* ]] && [[ "$stderr" != *"deprecated"* ]]
}

@test "deprecation warn: NOT fired when pyve.toml is present" {
    _write_v3_manifest
    _write_v2_venv_config
    local stderr
    stderr="$(manifest_load 2>&1 1>/dev/null)"
    [[ "$stderr" != *"legacy"* ]]
    [[ "$stderr" != *"v3.1"* ]]
}

@test "deprecation warn: NOT fired on bare directory" {
    local stderr
    stderr="$(manifest_load 2>&1 1>/dev/null)"
    [[ "$stderr" != *"legacy"* ]]
}

# ----- sentinel + N-10 cleanup marker ----------------------------

@test "read-compat code path: marked with 'v3.0-only: remove in N-10'" {
    # Mechanical sweep marker so the N-10 cleanup removes everything
    # tagged with this comment without hunting through the file.
    grep -qE 'v3\.0-only: remove in N-10' "$PYVE_ROOT/lib/manifest.sh"
}
