#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve testenv run [<name>] -- <cmd> [args...]` (Story M.i.2).
#
# Three valid shapes:
#   - `pyve testenv run <cmd> [args]`           → default testenv (today's)
#   - `pyve testenv run -- <cmd> [args]`        → default testenv, explicit
#   - `pyve testenv run <name> -- <cmd> [args]` → named env via separator
#
# Rule: name routing requires explicit `--` separator. No magic detection
# of "the first arg is a name." Today's `pyve testenv run ruff check .`
# behavior must be preserved.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/testenvs.sh"
    source "$PYVE_ROOT/lib/commands/testenv.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Stub testenv_run to record args without exec'ing. The dispatcher calls
# `testenv_run "$testenv_venv" "$@"` with the resolved venv path then
# the command + args.
_stub_testenv_run() {
    testenv_run() {
        printf 'TESTENV_RUN_ARGS:%s\n' "$*"
    }
}

# Pre-create a fake testenv at a named path so the dispatcher's call
# chain into ensure_testenv_exists (if any) short-circuits on existence.
_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/testenvs/$name/venv/bin"
    cat > ".pyve/testenvs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/testenvs/$name/venv/bin/python"
}

_fixture_named_envs() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]

[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
TOML
}

# ============================================================
# Shape 1: today's behavior — `pyve testenv run <cmd> [args]`
# ============================================================

@test "testenv run <cmd> [args]: routes to default testenv, command is first positional" {
    _make_fake_named_venv testenv
    _stub_testenv_run
    run testenv_command run ruff check .
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/testenvs/testenv/venv ruff check ."* ]]
}

# ============================================================
# Shape 2: explicit `--` with no name → default testenv
# ============================================================

@test "testenv run -- <cmd> [args]: explicit '--' with no name routes to default testenv" {
    _make_fake_named_venv testenv
    _stub_testenv_run
    run testenv_command run -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/testenvs/testenv/venv pytest -v"* ]]
}

# ============================================================
# Shape 3: `<name> -- <cmd> [args]` → named env via separator
# ============================================================

@test "testenv run <name> -- <cmd> [args]: name routes to that env's venv" {
    _fixture_named_envs
    _make_fake_named_venv smoke
    _stub_testenv_run
    run testenv_command run smoke -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/testenvs/smoke/venv pytest -v"* ]]
}

@test "testenv run testenv -- <cmd>: explicit default name + '--' separator works" {
    _make_fake_named_venv testenv
    _stub_testenv_run
    run testenv_command run testenv -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/testenvs/testenv/venv pytest -v"* ]]
}

# ============================================================
# Name validation through the M.i.1 gates
# ============================================================

@test "testenv run root -- <cmd>: reserved 'root' rejected (selection-only)" {
    _fixture_named_envs
    run testenv_command run root -- pytest
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "testenv run <undeclared> -- <cmd>: undeclared name rejected" {
    _fixture_named_envs
    run testenv_command run bogus -- pytest
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
}

@test "testenv run <conda-backed> -- <cmd>: micromamba backend hits M.k stub" {
    _fixture_named_envs
    run testenv_command run hardware -- pytest
    [ "$status" -ne 0 ]
    [[ "$output" == *"M.k"* ]]
}

# ============================================================
# No command provided after '--'
# ============================================================

@test "testenv run --: '--' with no command errors with usage hint" {
    _make_fake_named_venv testenv
    run testenv_command run --
    [ "$status" -ne 0 ]
    [[ "$output" == *"command"* || "$output" == *"Usage"* ]]
}

@test "testenv run <name> --: name with '--' but no command errors" {
    _fixture_named_envs
    _make_fake_named_venv smoke
    run testenv_command run smoke --
    [ "$status" -ne 0 ]
}

# ============================================================
# No-args run (today's existing error path)
# ============================================================

@test "testenv run: no args at all errors with usage hint (preserved behavior)" {
    _make_fake_named_venv testenv
    run testenv_command run
    [ "$status" -ne 0 ]
    [[ "$output" == *"command"* || "$output" == *"Usage"* ]]
}
