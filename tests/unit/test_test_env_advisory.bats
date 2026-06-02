#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.o — silent-skip advisory generalization.
#
# M.c shipped a one-line advisory that fires when `pyve test` routes to
# the default testenv AND the root project env has pytest importable:
# the user may have wanted the root env's stack and tests that
# `importorskip` that stack will silently SKIP.
#
# M.o generalizes:
#   1. `_test_main_env_has_pytest` is renamed `_test_env_has_pytest <name>`
#      so it can probe any env, not just root.
#   2. The advisory scans `root` + every declared env that isn't the
#      target; lists any with pytest importable as alternatives. The
#      message names the offending env(s) so the user can pick.
#   3. `PYVE_NO_TESTENV_ADVISORY=1` continues to gate the advisory off
#      for all envs (not just root).

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/run.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/commands/test.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
    unset CI
    unset PYVE_NO_TESTENV_ADVISORY
    unset PYVE_NO_AUTO_PROVISION
    export PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT="0"
}

teardown() {
    cleanup_test_dir
}

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

_fixture_two_venv_envs() {
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
# Generalized helper: `_test_env_has_pytest <name>`
# ============================================================

@test "_test_env_has_pytest root: existing semantics preserved (root env probe)" {
    # The function should accept `root` and behave like the pre-M.o
    # `_test_main_env_has_pytest`. With no main env on disk, returns 1.
    run _test_env_has_pytest root
    [ "$status" -ne 0 ]
}

@test "_test_env_has_pytest <named-name>: probes the named env's python" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state smoke
    # Replace the venv python with a stub that fails 'import pytest'.
    cat > .pyve/envs/smoke/venv/bin/python <<'SH'
#!/usr/bin/env bash
exit 1
SH
    chmod +x .pyve/envs/smoke/venv/bin/python
    run _test_env_has_pytest smoke
    [ "$status" -ne 0 ]
}

@test "_test_env_has_pytest <named-name>: returns 0 when 'import pytest' succeeds" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state smoke
    cat > .pyve/envs/smoke/venv/bin/python <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x .pyve/envs/smoke/venv/bin/python
    run _test_env_has_pytest smoke
    [ "$status" -eq 0 ]
}

@test "_test_env_has_pytest <missing-env>: returns 1 cleanly" {
    run _test_env_has_pytest does-not-exist
    [ "$status" -ne 0 ]
}

# ============================================================
# Generalized advisory: lists alternatives
# ============================================================

@test "advisory: targeting testenv when smoke (declared) has pytest → warn names smoke" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state testenv
    _make_fake_named_venv_with_state smoke
    # Stub _test_env_has_pytest deterministically.
    _test_env_has_pytest() {
        case "$1" in
            root) return 1 ;;
            testenv) return 0 ;;   # target has pytest (otherwise install-prompt fires)
            smoke) return 0 ;;     # the alternative
            *) return 1 ;;
        esac
    }
    _test_has_pytest() { return 0; }
    ensure_env_exists() { :; }

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"smoke"* ]]
    [[ "$output" == *"--env smoke"* ]]
    # Old M.c-only message wording shouldn't be the only signal.
    [[ "$output" == *"may be missing"* || "$output" == *"also has pytest"* || "$output" == *"silent"* ]]
}

@test "advisory: target listed in the alternatives is excluded (don't suggest current env)" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state testenv
    _test_env_has_pytest() {
        case "$1" in
            root) return 0 ;;
            testenv) return 0 ;;
            *) return 1 ;;
        esac
    }
    _test_has_pytest() { return 0; }
    ensure_env_exists() { :; }

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
    # Should mention root as alternative, not testenv.
    [[ "$output" == *"--env root"* ]]
    [[ "$output" != *"--env testenv"* ]]
}

@test "advisory: multiple alternatives are listed (root + named env)" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state testenv
    _make_fake_named_venv_with_state smoke
    _test_env_has_pytest() {
        case "$1" in
            root) return 0 ;;
            testenv) return 0 ;;
            smoke) return 0 ;;
            *) return 1 ;;
        esac
    }
    _test_has_pytest() { return 0; }
    ensure_env_exists() { :; }

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"--env root"* ]]
    [[ "$output" == *"--env smoke"* ]]
}

# ============================================================
# Opt-out (carry-over from M.c)
# ============================================================

@test "advisory: PYVE_NO_TESTENV_ADVISORY=1 suppresses across all envs" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state testenv
    _make_fake_named_venv_with_state smoke
    _test_env_has_pytest() { return 0; }  # every env has pytest
    _test_has_pytest() { return 0; }
    ensure_env_exists() { :; }
    export PYVE_NO_TESTENV_ADVISORY=1

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
    [[ "$output" != *"--env root"* ]]
    [[ "$output" != *"--env smoke"* ]]
}

# ============================================================
# No advisory when no candidate has pytest
# ============================================================

@test "advisory: silent when no other env has pytest" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state testenv
    _test_env_has_pytest() {
        case "$1" in
            testenv) return 0 ;;
            *) return 1 ;;
        esac
    }
    _test_has_pytest() { return 0; }
    ensure_env_exists() { :; }

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
    [[ "$output" != *"--env root"* ]]
    [[ "$output" != *"--env smoke"* ]]
}

# ============================================================
# --env root: no advisory (target is the candidate, no alternatives to warn about)
# ============================================================

@test "advisory: --env root never prints an advisory (it's the root path)" {
    _fixture_two_venv_envs
    _test_env_has_pytest() { return 0; }
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }

    run test_tests --env root
    [ "$status" -eq 0 ]
    [[ "$output" != *"may be missing"* ]]
    [[ "$output" != *"also has pytest"* ]]
}

# ============================================================
# M.c regression: helper rename is backward-compatible for the
# existing root-only case
# ============================================================

@test "advisory: M.c regression — root has pytest, target is testenv, warn fires" {
    _fixture_two_venv_envs
    _make_fake_named_venv_with_state testenv
    _test_env_has_pytest() {
        case "$1" in
            root) return 0 ;;
            *) return 1 ;;
        esac
    }
    _test_has_pytest() { return 0; }
    ensure_env_exists() { :; }

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"--env root"* ]]
}
