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
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Stub env_run to record args without exec'ing. The dispatcher calls
# `env_run "$testenv_venv" "$@"` with the resolved venv path then
# the command + args.
_stub_testenv_run() {
    env_run() {
        printf 'TESTENV_RUN_ARGS:%s\n' "$*"
    }
}

# Pre-create a fake testenv at a named path so the dispatcher's call
# chain into ensure_env_exists (if any) short-circuits on existence.
_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    cat > ".pyve/envs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/$name/venv/bin/python"
}

_fixture_named_envs() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
requirements = ["requirements-dev.txt"]
default = true

[env.smoke]
purpose = "test"
backend = "venv"
requirements = ["tests/smoke-requirements.txt"]

[env.hardware]
purpose = "test"
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
    run env_command run ruff check .
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/envs/testenv/venv ruff check ."* ]]
}

# ============================================================
# Shape 2: explicit `--` with no name → default testenv
# ============================================================

@test "testenv run -- <cmd> [args]: explicit '--' with no name routes to default testenv" {
    _make_fake_named_venv testenv
    _stub_testenv_run
    run env_command run -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/envs/testenv/venv pytest -v"* ]]
}

# ============================================================
# Shape 3: `<name> -- <cmd> [args]` → named env via separator
# ============================================================

@test "testenv run <name> -- <cmd> [args]: name routes to that env's venv" {
    _fixture_named_envs
    _make_fake_named_venv smoke
    _stub_testenv_run
    run env_command run smoke -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/envs/smoke/venv pytest -v"* ]]
}

@test "testenv run testenv -- <cmd>: explicit default name + '--' separator works" {
    _make_fake_named_venv testenv
    _stub_testenv_run
    run env_command run testenv -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTENV_RUN_ARGS:.pyve/envs/testenv/venv pytest -v"* ]]
}

# ============================================================
# Name validation through the M.i.1 gates
# ============================================================

@test "testenv run root -- <cmd>: reserved 'root' rejected (selection-only)" {
    _fixture_named_envs
    run env_command run root -- pytest
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "testenv run <undeclared> -- <cmd>: undeclared name rejected" {
    _fixture_named_envs
    : > pyve.toml  # N.bf.18: initialized project → 'bogus' reaches the not-declared path
    run env_command run bogus -- pytest
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
}

@test "testenv run <conda-backed> -- <cmd>: dispatches to micromamba run -p" {
    # A micromamba-backed env now execs via `micromamba run -p` (sets
    # CONDA_PREFIX / activate.d / lib paths) instead of hard-erroring. The
    # dispatcher routes the conda branch through env_exec_conda; stub it to a
    # marker so the routing (not a real conda exec) is what's asserted.
    _fixture_named_envs
    env_run()        { printf 'VENV_RUN:%s\n' "$*"; }
    env_exec_conda() { printf 'CONDA_EXEC:%s\n' "$*"; }
    run env_command run hardware -- pytest
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONDA_EXEC:.pyve/envs/hardware/conda pytest"* ]]
    [[ "$output" != *"VENV_RUN:"* ]]
}

# ============================================================
# No command provided after '--'
# ============================================================

@test "testenv run --: '--' with no command errors with usage hint" {
    _make_fake_named_venv testenv
    run env_command run --
    [ "$status" -ne 0 ]
    [[ "$output" == *"command"* || "$output" == *"Usage"* ]]
}

@test "testenv run <name> --: name with '--' but no command errors" {
    _fixture_named_envs
    _make_fake_named_venv smoke
    run env_command run smoke --
    [ "$status" -ne 0 ]
}

# ============================================================
# No-args run (today's existing error path)
# ============================================================

@test "testenv run: no args at all errors with usage hint (preserved behavior)" {
    _make_fake_named_venv testenv
    run env_command run
    [ "$status" -ne 0 ]
    [[ "$output" == *"command"* || "$output" == *"Usage"* ]]
}
