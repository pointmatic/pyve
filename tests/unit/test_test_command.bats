#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve test` env routing (Story M.c).
#
# The micromamba-testenv trap: `pyve test` always routed pytest to the
# dedicated testenv (a plain venv). For a smoke env built from a bundled
# environment.yml that puts BOTH pytest AND the heavy stack in the MAIN
# env, that routing runs pytest in a stack-less testenv → tests
# importorskip → silent SKIP → false confidence.
#
# Fix under test:
#   - `pyve test --env main` routes pytest to the MAIN project env
#     (delegates to `run_command python -m pytest <args>`).
#   - Default routing stays on the testenv (unchanged behavior).
#   - When routing to the testenv AND the main env has pytest, a
#     pre-run advisory is printed pointing at `--env main` (proxy
#     for the silent-skip trap).
#   - An invalid --env value errors.
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/commands/run.sh"
    source "$PYVE_ROOT/lib/commands/test.sh"
    create_test_dir

    # Globals normally defined in pyve.sh.
    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"

    # Determinism: don't let an ambient CI / auto-install flag steer
    # the testenv pytest-install branch.
    unset CI
    unset PYVE_NO_TESTENV_ADVISORY
    export PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT="0"
}

teardown() {
    cleanup_test_dir
}

# Provide a fake testenv python so the final `exec` in the testenv
# branch succeeds without a real venv.
_make_fake_testenv_python() {
    mkdir -p ".pyve/testenv/venv/bin"
    cat > ".pyve/testenv/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/testenv/venv/bin/python"
}

#============================================================
# --env main routing
#============================================================

@test "pyve test --env main: delegates to run_command python -m pytest <args>" {
    ensure_testenv_exists() { :; }   # guard against real venv creation
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }

    run test_tests --env main -q tests/test_x.py
    [ "$status" -eq 0 ]
    [[ "$output" == *"RUN_COMMAND_ARGS:python -m pytest -q tests/test_x.py"* ]]
}

@test "pyve test --env main: works with no extra pytest args" {
    ensure_testenv_exists() { :; }
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }

    run test_tests --env main
    [ "$status" -eq 0 ]
    [[ "$output" == *"RUN_COMMAND_ARGS:python -m pytest"* ]]
}

@test "pyve test --env=main: '=' form is accepted" {
    ensure_testenv_exists() { :; }
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }

    run test_tests --env=main -k smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"RUN_COMMAND_ARGS:python -m pytest -k smoke"* ]]
}

@test "pyve test: invalid --env value errors" {
    ensure_testenv_exists() { :; }
    run test_tests --env bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid --env"* ]]
}

#============================================================
# testenv routing (default) + silent-skip advisory
#============================================================

@test "pyve test (testenv routing): advisory when main env has pytest" {
    ensure_testenv_exists() { :; }
    _test_has_pytest() { return 0; }          # testenv already has pytest
    _test_main_env_has_pytest() { return 0; } # MAIN env ALSO has pytest
    _make_fake_testenv_python

    run test_tests -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"--env main"* ]]
}

@test "pyve test (testenv routing): PYVE_NO_TESTENV_ADVISORY=1 suppresses the advisory" {
    ensure_testenv_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_main_env_has_pytest() { return 0; } # main env HAS pytest — would normally warn
    _make_fake_testenv_python
    export PYVE_NO_TESTENV_ADVISORY=1

    run test_tests -q
    [ "$status" -eq 0 ]
    [[ "$output" != *"--env main"* ]]
}

@test "pyve test (testenv routing): no advisory when main env lacks pytest" {
    ensure_testenv_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_main_env_has_pytest() { return 1; } # MAIN env has NO pytest
    _make_fake_testenv_python

    run test_tests -q
    [ "$status" -eq 0 ]
    [[ "$output" != *"--env main"* ]]
}

@test "pyve test --env main: no testenv advisory (routed away from testenv)" {
    _test_main_env_has_pytest() { return 0; }
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }

    run test_tests --env main
    [ "$status" -eq 0 ]
    [[ "$output" != *"using the separate testenv"* ]]
}
