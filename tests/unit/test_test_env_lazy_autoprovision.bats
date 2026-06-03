#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.n — lazy auto-provisioning.
#
# M.m left a hard-error site for `pyve test --env <lazy-name>` when the
# env hadn't been provisioned yet (pointing the user at `pyve testenv
# install <name>`). M.n replaces that hard-error with auto-provisioning
# on the same code path: `ensure_env_exists <name>` then
# `_env_install_with_lock <name> <path> "" wait`, gated by a
# `PYVE_NO_AUTO_PROVISION=1` opt-out for strict CI that wants the
# pre-M.n "is this env already built?" semantics.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
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

_fixture_lazy_heavy() {
    mkdir -p tests
    printf 'pytest\n' > tests/heavy.txt
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.heavy]
requirements = ["tests/heavy.txt"]
lazy = true
TOML
}

# Stub `python -m venv <path>` (called from ensure_env_exists)
# to materialize a marker venv at the requested path.
_stub_run_cmd_creates_venv_and_records() {
    run_cmd() {
        local venv_path="${4:-}"
        if [[ "$1" == "python" && "$2" == "-m" && "$3" == "venv" && -n "$venv_path" ]]; then
            mkdir -p "$venv_path/bin"
            cat > "$venv_path/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
            chmod +x "$venv_path/bin/python"
        fi
        # Record every run_cmd invocation so tests can observe what
        # `_env_install_venv` did.
        printf 'RUN_CMD:%s\n' "$*"
    }
}

# ============================================================
# Auto-provision happy path
# ============================================================

@test "pyve test --env <lazy-unprovisioned>: auto-provisions then routes" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy>] selector requires read-compat shim"
    _fixture_lazy_heavy
    _stub_run_cmd_creates_venv_and_records
    _test_has_pytest() { return 0; }       # post-provision: pretend pytest is installed
    _test_env_has_pytest() { return 1; }

    run test_tests --env heavy -q
    [ "$status" -eq 0 ]
    # Auto-provision wrote the venv on disk.
    [ -x ".pyve/envs/heavy/venv/bin/python" ]
    # The install path ran with the declared requirements file.
    [[ "$output" == *"-r tests/heavy.txt"* ]]
    # The lazy hard-error message from M.m is gone.
    [[ "$output" != *"declared lazy and has not been provisioned"* ]]
}

# ============================================================
# Opt-out: PYVE_NO_AUTO_PROVISION=1 restores the M.m hard-error
# ============================================================

@test "pyve test --env <lazy-unprovisioned> with PYVE_NO_AUTO_PROVISION=1: hard-errors" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy>] selector requires read-compat shim"
    _fixture_lazy_heavy
    export PYVE_NO_AUTO_PROVISION=1

    run test_tests --env heavy
    [ "$status" -ne 0 ]
    [[ "$output" == *"heavy"* ]]
    [[ "$output" == *"PYVE_NO_AUTO_PROVISION"* ]]
    [[ "$output" == *"pyve testenv install heavy"* ]]
    # Auto-provision did NOT run.
    [ ! -d ".pyve/envs/heavy/venv" ]
}

# ============================================================
# Already-provisioned lazy env: no auto-provision second time
# ============================================================

@test "pyve test --env <lazy-already-provisioned>: routes normally (no re-provision)" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy>] selector requires read-compat shim"
    _fixture_lazy_heavy
    # Pre-provision heavy by hand.
    mkdir -p .pyve/envs/heavy/venv/bin
    cat > .pyve/envs/heavy/venv/bin/python <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x .pyve/envs/heavy/venv/bin/python
    state_write heavy venv

    # Stub run_cmd so we can prove `_env_install_venv` was NOT called
    # (no `pip install` invocation should appear).
    _stub_run_cmd_creates_venv_and_records
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env heavy -q
    [ "$status" -eq 0 ]
    # No pip install call — already provisioned.
    [[ "$output" != *"pip install"* ]]
}

# ============================================================
# Lock interaction: acquire/release surrounds the auto-provision
# ============================================================

@test "pyve test --env <lazy-unprovisioned>: auto-provision lock is released after success" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy>] selector requires read-compat shim"
    _fixture_lazy_heavy
    _stub_run_cmd_creates_venv_and_records
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env heavy -q
    [ "$status" -eq 0 ]
    # Lock dir cleaned up — the M.j release happens regardless of
    # whether the install was bulk or auto-provisioned.
    [ ! -d ".pyve/envs/heavy/.lock" ]
}

# ============================================================
# Conda lazy: still rejected (M.k venv-only gate fires before lazy gate)
# ============================================================

@test "pyve test --env <lazy-conda>: still rejected (run is venv-only)" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy-conda>] selector requires read-compat shim"
    mkdir -p tests
    printf 'name: hardware\ndependencies: [python]\n' > tests/env.yml
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
lazy = true
TOML
    run test_tests --env hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"hardware"* ]]
    [[ "$output" == *"conda"* || "$output" == *"micromamba"* ]]
}
