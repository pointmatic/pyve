#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.r — `pyve test --env a,b,c` matrix execution.
#
# Pre-M.r: `--env` accepted only a single name; comma-separated values
# would be passed through to the resolver and hard-error as
# "undeclared name".
#
# M.r extends the parser to:
#   1. Accept a comma-separated list of env names: `--env a,b,c`
#      (and `--env=a,b,c`).
#   2. Single-element (no comma) preserves the M.m exec path verbatim.
#   3. Multi-element runs each env sequentially; failures do not halt
#      iteration.
#   4. Exit code is the worst-case aggregate (highest failing rc).
#   5. Each env run is preceded by `=== Env: <name> ===` so the human
#      reader can delineate per-env output.
#
# Out of scope (per story body): `--parallel`. Plan doc OS-4.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
    unset CI
    unset PYVE_NO_TESTENV_ADVISORY
    export PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT="0"
}

teardown() {
    cleanup_test_dir
}

# Drop a fake venv python at .pyve/envs/<name>/venv/bin/python that
# exits with a configurable code so we can drive matrix exit aggregation
# from a test's POV. `_rc` of 0 → success; otherwise the python stub
# `exit $_rc`s.
_make_fake_named_venv_with_state() {
    local name="$1"
    local rc="${2:-0}"
    mkdir -p ".pyve/envs/$name/venv/bin"
    cat > ".pyve/envs/$name/venv/bin/python" <<SH
#!/usr/bin/env bash
exit $rc
SH
    chmod +x ".pyve/envs/$name/venv/bin/python"
    state_write "$name" "venv" provisioned_at=1700000000
}

_fixture_two_envs() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs]
default = "testenv"

[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]

[tool.pyve.testenvs.heavy]
requirements = ["tests/heavy.txt"]
TOML
}

# ============================================================
# Single-env (no comma): existing exec behavior preserved
# ============================================================

@test "pyve test --env <single-name>: preserves single-env exec path (M.m regression)" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<smoke>] selector requires read-compat shim"
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke -q
    [ "$status" -eq 0 ]
    # No matrix header for the single-env path — verbatim M.m behavior.
    [[ "$output" != *"=== Env:"* ]]
}

# ============================================================
# Matrix: two envs run sequentially
# ============================================================

@test "pyve test --env a,b: runs against both envs sequentially" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<a,b>] matrix selector requires read-compat shim"
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    _make_fake_named_venv_with_state heavy 0
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke,heavy -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Env: smoke ==="* ]]
    [[ "$output" == *"=== Env: heavy ==="* ]]
}

@test "pyve test --env=a,b: '=' form also accepts CSV" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<a,b>] matrix selector requires read-compat shim"
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    _make_fake_named_venv_with_state heavy 0
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env=smoke,heavy
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Env: smoke ==="* ]]
    [[ "$output" == *"=== Env: heavy ==="* ]]
}

@test "pyve test --env a,b: per-env section headers appear in declared order" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<a,b>] matrix selector requires read-compat shim"
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    _make_fake_named_venv_with_state heavy 0
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke,heavy
    [ "$status" -eq 0 ]
    # Header order matches CSV order, not declaration order.
    local smoke_pos="${output%%=== Env: smoke ===*}"
    local heavy_pos="${output%%=== Env: heavy ===*}"
    [ "${#smoke_pos}" -lt "${#heavy_pos}" ]
}

# ============================================================
# Matrix: exit-code aggregation (worst-case)
# ============================================================

@test "pyve test --env a,b: one env fails → aggregate non-zero" {
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    _make_fake_named_venv_with_state heavy 2  # pytest "collection error"
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke,heavy
    [ "$status" -ne 0 ]
    # Even the failing env's header appears — iteration completes.
    [[ "$output" == *"=== Env: smoke ==="* ]]
    [[ "$output" == *"=== Env: heavy ==="* ]]
}

@test "pyve test --env a,b: both fail → returns highest fail code" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<a,b>] matrix selector requires read-compat shim"
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 3
    _make_fake_named_venv_with_state heavy 5
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke,heavy
    [ "$status" -eq 5 ]
}

@test "pyve test --env a,b: failure in first env does not halt second" {
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 1  # fails
    _make_fake_named_venv_with_state heavy 0  # would-succeed
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke,heavy
    [ "$status" -eq 1 ]
    # Second env's header must appear even though first env failed.
    [[ "$output" == *"=== Env: heavy ==="* ]]
}

# ============================================================
# Matrix: name validation runs per element
# ============================================================

@test "pyve test --env a,bogus: undeclared name in list hard-errors" {
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke,bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
}

@test "pyve test --env main,smoke: legacy 'main' caught (M.e regression)" {
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0

    run test_tests --env main,smoke
    [ "$status" -ne 0 ]
    [[ "$output" == *"--env root"* ]]
}

# ============================================================
# Matrix: `.state` last_used_at touched for each env
# ============================================================

@test "pyve test --env a,b: last_used_at touched on every env in matrix" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<a,b>] matrix selector requires read-compat shim"
    _fixture_two_envs
    _make_fake_named_venv_with_state smoke 0
    _make_fake_named_venv_with_state heavy 0
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    # Both .states start with last_used_at=0.
    state_read smoke
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "0" ]
    state_read heavy
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "0" ]

    run test_tests --env smoke,heavy -q
    [ "$status" -eq 0 ]

    state_read smoke
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" != "0" ]
    state_read heavy
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" != "0" ]
}
