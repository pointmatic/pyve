#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.m — `pyve test --env <name>` resolver
# extension.
#
# Pre-M.m: `--env` accepted only `root` and `testenv`; anything else
# hard-errored.
#
# M.m extends the parser to:
#   1. Accept `--env <declared-name>` (and `--env=<name>`).
#   2. Default to `[tool.pyve.testenvs].default` (falls back to
#      `testenv`) when `--env` is omitted.
#   3. Hard-error on undeclared names with a list of valid choices.
#   4. Hard-error on lazy envs that have not been provisioned yet,
#      pointing at `pyve testenv install <name>` (auto-provision is
#      M.n's job — M.m stays self-contained).
#   5. Operate conda-backed envs by routing the exec through
#      `micromamba run -p <env_path>` (sets CONDA_PREFIX / activate.d /
#      lib paths), the same backend dispatch `pyve env run` uses.
#   6. Touch `.state`'s `last_used_at` on the success path (consumed
#      by M.p's `pyve testenv list / prune`).
#   7. Have `ensure_env_exists` and `_env_init_conda` write
#      an initial `.state` on env creation so the touch in (6) has
#      something to update.

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

# Drop a fake venv python at .pyve/envs/<name>/venv/bin/python so
# `exec` succeeds without a real venv. Also seeds the .state file (the
# resolver's last-used touch needs it present).
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

_fixture_default_smoke() {
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

[env.smoke]
purpose = "test"
backend = "venv"
requirements = ["tests/smoke-requirements.txt"]
default = true

[env.heavy]
purpose = "test"
backend = "venv"
requirements = ["tests/heavy.txt"]
lazy = true

[env.hardware]
purpose = "test"
backend = "micromamba"
manifest = "tests/env.yml"
TOML
}

# ============================================================
# --env <declared-name>: venv-backed
# ============================================================

@test "pyve test --env <declared-name>: routes pytest to that env's venv" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<smoke>] selector requires read-compat shim"
    _fixture_default_smoke
    _make_fake_named_venv_with_state smoke
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke -q
    [ "$status" -eq 0 ]
    # exec'd the fake python at smoke's path → no error output about
    # the testenv path.
    [[ "$output" != *"Invalid --env"* ]]
}

@test "pyve test --env=<declared-name>: '=' form also works" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<smoke>] selector requires read-compat shim"
    _fixture_default_smoke
    _make_fake_named_venv_with_state smoke
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env=smoke
    [ "$status" -eq 0 ]
}

# ============================================================
# Undeclared name: hard-error lists valid choices
# ============================================================

@test "pyve test --env <undeclared>: hard-errors and lists valid choices" {
    _fixture_default_smoke
    run test_tests --env bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    # Valid choices include reserved + declared names.
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"testenv"* ]]
    [[ "$output" == *"smoke"* ]]
}

# ============================================================
# Lazy envs: hard-error pointing at `pyve testenv install <name>`
# (M.n will replace this with auto-provisioning)
# ============================================================

@test "pyve test --env <lazy-name> unprovisioned + PYVE_NO_AUTO_PROVISION=1: hard-errors with install hint" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy>] selector requires read-compat shim"
    # Pre-M.n this test asserted the bare hard-error. M.n landed
    # auto-provisioning; the strict-CI opt-out preserves the M.m
    # contract for users who want it.
    _fixture_default_smoke
    export PYVE_NO_AUTO_PROVISION=1
    run test_tests --env heavy
    [ "$status" -ne 0 ]
    [[ "$output" == *"heavy"* ]]
    [[ "$output" == *"pyve testenv install heavy"* ]]
    [[ "$output" == *"PYVE_NO_AUTO_PROVISION"* ]]
}

@test "pyve test --env <lazy-name> already provisioned: routes normally" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<lazy>] selector requires read-compat shim"
    _fixture_default_smoke
    # heavy is lazy but the user already provisioned it.
    _make_fake_named_venv_with_state heavy
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env heavy -q
    [ "$status" -eq 0 ]
}

# Conda-backed envs are now operated via `micromamba run -p` rather than
# hard-errored off; that dispatch is covered with a v3 `pyve.toml` fixture in
# tests/unit/test_conda_env_exec.bats (no N.i-pending v2-selector dependency).

# ============================================================
# No --env: defaults to [tool.pyve.testenvs].default
# ============================================================

@test "pyve test (no --env): routes to declared 'default' env" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<smoke>] default-env selector requires read-compat shim"
    _fixture_default_smoke
    _make_fake_named_venv_with_state smoke
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests -q
    [ "$status" -eq 0 ]
    # Did NOT route to `testenv` (the pre-M.m default) — smoke is
    # the declared default. We can't see the exec target directly,
    # but the lack of any "Invalid --env" / "not declared" error
    # plus the venv-only routing is the signal.
    [[ "$output" != *"Invalid --env"* ]]
}

@test "pyve test (no --env, no [tool.pyve.testenvs] block): falls back to 'testenv'" {
    # No pyproject.toml at all — implicit-default config has 'testenv' only.
    _make_fake_named_venv_with_state testenv
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests -q
    [ "$status" -eq 0 ]
}

# ============================================================
# Regression: --env root / --env testenv still work
# ============================================================

@test "pyve test --env root: still delegates to run_command (M.c regression)" {
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }
    run test_tests --env root
    [ "$status" -eq 0 ]
    [[ "$output" == *"RUN_COMMAND_ARGS:python -m pytest"* ]]
}

@test "pyve test --env testenv: explicit default still routes to testenv venv" {
    _make_fake_named_venv_with_state testenv
    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env testenv -q
    [ "$status" -eq 0 ]
}

# ============================================================
# .state touch on success
# ============================================================

@test "pyve test: 'last_used_at' is touched on the success path" {
    skip "N.i-pending: v2 [tool.pyve.testenvs.<smoke>] success-path .state touch requires read-compat shim"
    _fixture_default_smoke
    _make_fake_named_venv_with_state smoke
    # state_write seeded last_used_at=0; the touch should set it to a
    # positive epoch.
    state_read smoke
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "0" ]

    ensure_env_exists() { :; }
    _test_has_pytest() { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env smoke -q
    [ "$status" -eq 0 ]

    # Re-read .state in the parent shell.
    state_read smoke
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" != "0" ]
    [[ "$PYVE_TESTENV_STATE_LAST_USED_AT" =~ ^[0-9]+$ ]]
}

@test "pyve test --env root: does NOT touch testenv's last_used_at (different env)" {
    _fixture_default_smoke
    _make_fake_named_venv_with_state smoke
    run_command() { printf 'RUN_COMMAND_ARGS:%s\n' "$*"; }

    # smoke's .state should be untouched (we're routing to root).
    state_read smoke
    local before="$PYVE_TESTENV_STATE_LAST_USED_AT"

    run test_tests --env root
    [ "$status" -eq 0 ]

    state_read smoke
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "$before" ]
}

# ============================================================
# ensure_env_exists writes initial .state on creation (M.m)
# ============================================================

@test "ensure_env_exists: writes initial .state for a fresh venv testenv" {
    _fixture_default_smoke
    # Stub run_cmd's `python -m venv` to create the marker venv dir
    # instead of invoking python (avoids the asdf-in-tmpdir issue).
    run_cmd() {
        local venv_path="${4:-}"
        if [[ -n "$venv_path" ]]; then
            mkdir -p "$venv_path/bin"
            cat > "$venv_path/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
            chmod +x "$venv_path/bin/python"
        fi
    }
    ensure_env_exists smoke
    [ -d ".pyve/envs/smoke/venv" ]
    [ -f ".pyve/envs/smoke/.state" ]
    state_read smoke
    [ "$PYVE_TESTENV_STATE_BACKEND" = "venv" ]
    [[ "$PYVE_TESTENV_STATE_PROVISIONED_AT" =~ ^[0-9]+$ ]]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "0" ]
}

@test "ensure_env_exists: idempotent .state — does not overwrite an existing file" {
    _fixture_default_smoke
    # Pre-seed a .state with a known provisioned_at.
    _make_fake_named_venv_with_state smoke  # uses provisioned_at=1700000000
    run_cmd() { :; }  # no-op (env already exists)

    ensure_env_exists smoke

    state_read smoke
    [ "$PYVE_TESTENV_STATE_PROVISIONED_AT" = "1700000000" ]
}
