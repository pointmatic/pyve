#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story N.d — `pyve test --env <name>` purpose gate.
#
# The selector now rejects any env whose resolved purpose is NOT
# "test", pointing the user at `pyve env run <name> -- <cmd>` for the
# correct invocation form. Default-purpose rules (lib/manifest.sh::
# manifest_resolve_purpose):
#   env name "testenv" → "test"
#   env name "root"    → "utility"
#   otherwise          → "utility"
# Explicit `purpose = ...` in pyve.toml's [env.<name>] block wins.
#
# These tests use v3-style pyve.toml fixtures (the canonical N.d
# surface). v2-source paths via `[tool.pyve.testenvs.*]` continue to
# work in this story's window but their selector tests are temporarily
# skipped with `N.i-pending` markers until the read-compat shim lands.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/commands/test.sh"
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

# Drop a fake venv python so the selector's exec path can succeed
# without a real venv. Used by happy-path tests.
_make_fake_named_venv_with_state() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    cat > ".pyve/envs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/$name/venv/bin/python"
    state_write "$name" "venv" provisioned_at=1700000000
}

# ============================================================
# 1. Gate rejects non-test envs declared in pyve.toml
# ============================================================

@test "purpose gate: --env <utility-env> hard-errors with hint" {
    cat > pyve.toml <<'TOML'
[env.tools]
purpose = "utility"
backend = "venv"
TOML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.tools]
backend = "venv"
TOML
    run test_tests --env tools
    [ "$status" -ne 0 ]
    [[ "$output" == *"tools"* ]]
    [[ "$output" == *"utility"* ]]
    # Precise hint at the right command.
    [[ "$output" == *"pyve env run"* ]]
}

@test "purpose gate: --env <run-env> hard-errors with hint naming 'run' purpose" {
    cat > pyve.toml <<'TOML'
[env.web]
purpose = "run"
backend = "venv"
TOML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.web]
backend = "venv"
TOML
    run test_tests --env web
    [ "$status" -ne 0 ]
    [[ "$output" == *"run"* ]]
    [[ "$output" == *"pyve env run"* ]]
}

@test "purpose gate: --env <temp-env> hard-errors with hint naming 'temp' purpose" {
    cat > pyve.toml <<'TOML'
[env.scratch]
purpose = "temp"
backend = "venv"
TOML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.scratch]
backend = "venv"
TOML
    run test_tests --env scratch
    [ "$status" -ne 0 ]
    [[ "$output" == *"temp"* ]]
}

# ============================================================
# 2. Gate accepts test envs (declared + reserved-name default)
# ============================================================

@test "purpose gate: --env <test-env declared> passes" {
    cat > pyve.toml <<'TOML'
[env.smoke]
purpose = "test"
backend = "venv"
TOML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.smoke]
backend = "venv"
TOML
    _make_fake_named_venv_with_state smoke
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }
    run test_tests --env smoke
    [ "$status" -eq 0 ]
}

@test "purpose gate: --env testenv passes via name-based default (no explicit purpose)" {
    cat > pyve.toml <<'TOML'
[env.testenv]
backend = "venv"
TOML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
backend = "venv"
TOML
    _make_fake_named_venv_with_state testenv
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }
    run test_tests --env testenv
    [ "$status" -eq 0 ]
}

# ============================================================
# 3. --env root: pre-gate short-circuit (delegates to run_command)
# ============================================================

@test "purpose gate: --env root short-circuits before purpose check" {
    # `--env root` is handled in _test_run_one_env BEFORE the gate runs
    # (delegates straight to run_command). Even if pyve.toml declared
    # root with purpose != test, --env root still routes.
    cat > pyve.toml <<'TOML'
[env.root]
purpose = "utility"
backend = "venv"
TOML
    # Stub run_command so we observe the route without an actual exec.
    run_command() { echo "ROUTED-TO-ROOT $*"; return 0; }
    run test_tests --env root
    [ "$status" -eq 0 ]
    [[ "$output" == *"ROUTED-TO-ROOT"* ]]
}

# ============================================================
# 4. Explicit purpose declaration wins over name
# ============================================================

@test "purpose gate: env named 'testenv' but declared as 'utility' is rejected" {
    cat > pyve.toml <<'TOML'
[env.testenv]
purpose = "utility"
backend = "venv"
TOML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
backend = "venv"
TOML
    run test_tests --env testenv
    [ "$status" -ne 0 ]
    [[ "$output" == *"utility"* ]]
    [[ "$output" == *"pyve env run"* ]]
}
