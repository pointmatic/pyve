#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve testenv purge [<name>] [--force]` (Story M.i.4).
#
# Routing:
#   - with-arg <name>     → remove .pyve/testenvs/<name>/  (no confirm)
#   - no-arg, single env  → confirm-or-skip(non-TTY)+remove (scriptable)
#   - no-arg, multi env   → confirm+remove all (interactive only)
#   - no-arg, --force     → skip confirm, remove all
#
# Conda-backed envs are also purged (rm -rf doesn't care about backend).

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

_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/testenvs/$name/venv/bin"
    cat > ".pyve/testenvs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/testenvs/$name/venv/bin/python"
    # Marker so we can verify the dir was removed.
    printf '%s' "$name" > ".pyve/testenvs/$name/.state"
}

_fixture_multi_envs() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]

[tool.pyve.testenvs.hardware]
backend = "micromamba"
TOML
}

# ============================================================
# With-arg single-env: removes .pyve/testenvs/<name>/ root
# ============================================================

@test "testenv purge <name>: removes the named env root (includes .state)" {
    _fixture_multi_envs
    _make_fake_named_venv smoke
    _make_fake_named_venv testenv
    run testenv_command purge smoke
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/smoke" ]
    # Default testenv NOT removed as a side effect.
    [ -d ".pyve/testenvs/testenv" ]
}

@test "testenv purge testenv: explicit default removes only that env" {
    _fixture_multi_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke
    run testenv_command purge testenv
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/testenv" ]
    [ -d ".pyve/testenvs/smoke" ]
}

@test "testenv purge <conda-backed>: also purges (backend-agnostic)" {
    _fixture_multi_envs
    mkdir -p ".pyve/testenvs/hardware/conda"
    printf 'hw' > ".pyve/testenvs/hardware/.state"
    run testenv_command purge hardware
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/hardware" ]
}

@test "testenv purge root: reserved 'root' hard-errors" {
    _fixture_multi_envs
    run testenv_command purge root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "testenv purge <undeclared>: hard-errors with [tool.pyve.testenvs] hint" {
    _fixture_multi_envs
    run testenv_command purge bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
}

@test "testenv purge <name>: missing env prints info, no error" {
    _fixture_multi_envs
    # smoke is declared but not provisioned on disk
    run testenv_command purge smoke
    [ "$status" -eq 0 ]
}

# ============================================================
# No-arg with single declared env (implicit-default): non-TTY skips prompt
# ============================================================

@test "testenv purge: no-arg, single env, non-TTY (bats) — purges without prompt" {
    # No pyproject.toml → implicit-default config (one env: testenv).
    _make_fake_named_venv testenv
    run testenv_command purge
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/testenv" ]
}

# ============================================================
# No-arg with multiple declared envs: non-TTY still skips prompt
# (matches `pyve init`'s prompt pattern — CI must not hang)
# ============================================================

@test "testenv purge: no-arg, multi env, non-TTY (bats) — purges all without prompt" {
    _fixture_multi_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke
    mkdir -p ".pyve/testenvs/hardware/conda"
    printf 'hw' > ".pyve/testenvs/hardware/.state"

    run testenv_command purge
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/testenv" ]
    [ ! -d ".pyve/testenvs/smoke" ]
    [ ! -d ".pyve/testenvs/hardware" ]
}

# ============================================================
# --force flag: skip confirm explicitly (forces interactive paths too)
# ============================================================

@test "testenv purge --force: removes all without prompt" {
    _fixture_multi_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke
    run testenv_command purge --force
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/testenv" ]
    [ ! -d ".pyve/testenvs/smoke" ]
}

@test "testenv purge <name> --force: --force accepted on with-arg path (no-op)" {
    _fixture_multi_envs
    _make_fake_named_venv smoke
    run testenv_command purge smoke --force
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/smoke" ]
}

# ============================================================
# Confirm prompt declined (simulated TTY via stdin redirection)
# ============================================================

@test "testenv purge: simulated TTY with 'n' declines and aborts (no removal)" {
    _fixture_multi_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke

    # Force interactive code path by exporting a sentinel the helper
    # honors (PYVE_FORCE_PROMPT=1), then pipe 'n' on stdin.
    PYVE_FORCE_PROMPT=1 run bash -c "
        source '$PYVE_ROOT/lib/ui/core.sh'
        source '$PYVE_ROOT/lib/ui/run.sh'
        source '$PYVE_ROOT/lib/utils.sh'
        source '$PYVE_ROOT/lib/testenvs.sh'
        source '$PYVE_ROOT/lib/commands/testenv.sh'
        export PYVE_PYTHON='$PYVE_PYTHON'
        export TESTENV_DIR_NAME='testenv'
        export DEFAULT_VENV_DIR='.venv'
        export PYVE_FORCE_PROMPT=1
        cd '$TEST_DIR'
        echo 'n' | testenv_command purge
    "
    [ "$status" -eq 0 ]
    [ -d ".pyve/testenvs/testenv" ]
    [ -d ".pyve/testenvs/smoke" ]
}

@test "testenv purge: simulated TTY with 'y' confirms and removes all" {
    _fixture_multi_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke

    PYVE_FORCE_PROMPT=1 run bash -c "
        source '$PYVE_ROOT/lib/ui/core.sh'
        source '$PYVE_ROOT/lib/ui/run.sh'
        source '$PYVE_ROOT/lib/utils.sh'
        source '$PYVE_ROOT/lib/testenvs.sh'
        source '$PYVE_ROOT/lib/commands/testenv.sh'
        export PYVE_PYTHON='$PYVE_PYTHON'
        export TESTENV_DIR_NAME='testenv'
        export DEFAULT_VENV_DIR='.venv'
        export PYVE_FORCE_PROMPT=1
        cd '$TEST_DIR'
        echo 'y' | testenv_command purge
    "
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenvs/testenv" ]
    [ ! -d ".pyve/testenvs/smoke" ]
}
