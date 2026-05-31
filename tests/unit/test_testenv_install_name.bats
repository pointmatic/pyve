#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve testenv install [<name>] [-r <file>]` (Story M.i.3).
#
# Two routing branches:
#   - no-arg: iterate over every non-lazy declared env; install each.
#   - with-arg <name>: install only into that env.
#
# Both branches accept an optional `-r <requirements_file>`. The
# manifest source declared in [tool.pyve.testenvs.<name>]
# (`requirements`/`extra`) is intentionally NOT consumed here — M.l
# flips that switch. M.i.3 preserves today's `-r <file>` or bare-pytest
# install semantics from `testenv_install`.

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

# Pre-create a fake testenv venv at .pyve/testenvs/<name>/venv/bin/python
# so testenv_install passes the existence guard without invoking real python.
_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/testenvs/$name/venv/bin"
    cat > ".pyve/testenvs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/testenvs/$name/venv/bin/python"
}

# Stub run_cmd to record the pip invocation rather than execute it.
# Records emit to stdout so bats `run` can capture them via $output —
# the subshell that `run` uses means a shell-variable-based recorder
# would not propagate back here.
_stub_run_cmd_records() {
    run_cmd() {
        printf 'RUN_CMD:%s\n' "$*"
    }
}

_fixture_named_envs() {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]

[tool.pyve.testenvs.heavy]
requirements = ["tests/heavy.txt"]
lazy = true

[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
TOML
}

# ============================================================
# no-arg with NO [tool.pyve.testenvs] block: implicit default `testenv`
# ============================================================

@test "testenv install: no-arg without config installs into default testenv (today's behavior)" {
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run testenv_command install
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenvs/testenv/venv/bin/python"* ]]
}

# ============================================================
# no-arg with declared named envs: iterate non-lazy, skip lazy
# ============================================================

@test "testenv install: no-arg with declared envs iterates non-lazy, skips lazy" {
    _fixture_named_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke
    _make_fake_named_venv heavy
    _stub_run_cmd_records

    run testenv_command install
    [ "$status" -eq 0 ]
    # testenv + smoke are non-lazy → both installed.
    [[ "$output" == *"testenvs/testenv/venv/bin/python"* ]]
    [[ "$output" == *"testenvs/smoke/venv/bin/python"* ]]
    # heavy is lazy → NOT installed.
    [[ "$output" != *"testenvs/heavy/venv/bin/python"* ]]
    # hardware is conda-backed → not iterated (would M.k stub anyway).
    [[ "$output" != *"testenvs/hardware/"* ]]
}

@test "testenv install: no-arg with only lazy envs prints info, exits 0" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.heavy]
requirements = ["tests/heavy.txt"]
lazy = true
TOML
    # Note: implicit default `testenv` (non-lazy) is always synthesized,
    # so this fixture still has one non-lazy env to install. Make the
    # default testenv venv exist so it can be installed.
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run testenv_command install
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenvs/testenv/"* ]]
    [[ "$output" != *"testenvs/heavy/"* ]]
}

# ============================================================
# with-arg single-env: declared venv-backed
# ============================================================

@test "testenv install <name>: declared venv-backed env installs into that env only" {
    _fixture_named_envs
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run testenv_command install smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenvs/smoke/venv/bin/python"* ]]
    # Default testenv NOT installed as a side effect.
    [[ "$output" != *"testenvs/testenv/"* ]]
}

# ============================================================
# Name validation
# ============================================================

@test "testenv install root: reserved 'root' hard-errors" {
    _fixture_named_envs
    run testenv_command install root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "testenv install <undeclared>: hard-errors with [tool.pyve.testenvs] hint" {
    _fixture_named_envs
    run testenv_command install bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"tool.pyve.testenvs"* ]]
}

@test "testenv install <conda-backed>: M.k stub hard-error" {
    _fixture_named_envs
    run testenv_command install hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"M.k"* ]]
}

# ============================================================
# -r <file> parsing in either argument order
# ============================================================

@test "testenv install -r <file>: no name, with -r requirements" {
    cat > requirements-dev.txt <<'EOF'
ruff
EOF
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run testenv_command install -r requirements-dev.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"-r requirements-dev.txt"* ]]
}

@test "testenv install <name> -r <file>: name then -r" {
    _fixture_named_envs
    mkdir -p tests
    cat > tests/smoke-requirements.txt <<'EOF'
ruff
EOF
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run testenv_command install smoke -r tests/smoke-requirements.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenvs/smoke/venv/bin/python"* ]]
    [[ "$output" == *"-r tests/smoke-requirements.txt"* ]]
}

@test "testenv install -r <file> <name>: -r then name (reverse order)" {
    _fixture_named_envs
    mkdir -p tests
    cat > tests/smoke-requirements.txt <<'EOF'
ruff
EOF
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run testenv_command install -r tests/smoke-requirements.txt smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenvs/smoke/venv/bin/python"* ]]
    [[ "$output" == *"-r tests/smoke-requirements.txt"* ]]
}
