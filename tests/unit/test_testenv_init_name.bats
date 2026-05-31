#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve testenv init [<name>]` (Story M.i.2).
#
# Dispatcher accepts an optional positional <name> after `init`.
# Routing rules:
#   - no arg                  → default `testenv`
#   - declared venv-backed    → create at .pyve/testenvs/<name>/venv
#   - reserved `root`         → hard-error (selection-only)
#   - undeclared              → hard-error (with [tool.pyve.testenvs] hint)
#   - conda-backed declared   → M.k stub hard-error

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/testenvs.sh"
    source "$PYVE_ROOT/lib/commands/testenv.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    # Globals normally defined in pyve.sh.
    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Stub run_cmd to simulate `python -m venv <path>` without invoking real
# python (bats tmp dirs have no .tool-versions; asdf shim breaks).
_stub_run_cmd_creates_venv() {
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
# no-arg behavior preserved
# ============================================================

@test "testenv init: no arg creates the default testenv at the new path" {
    _stub_run_cmd_creates_venv
    run testenv_command init
    [ "$status" -eq 0 ]
    [ -d ".pyve/testenvs/testenv/venv" ]
}

# ============================================================
# with-arg routing
# ============================================================

@test "testenv init <name>: declared venv-backed name creates at .pyve/testenvs/<name>/venv" {
    _fixture_named_envs
    _stub_run_cmd_creates_venv
    run testenv_command init smoke
    [ "$status" -eq 0 ]
    [ -d ".pyve/testenvs/smoke/venv" ]
    # Default testenv NOT created as a side effect.
    [ ! -d ".pyve/testenvs/testenv/venv" ]
}

@test "testenv init <name>: reserved 'root' hard-errors" {
    _fixture_named_envs
    run testenv_command init root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [ ! -d ".pyve/testenvs/root" ]
}

@test "testenv init <name>: undeclared name hard-errors with [tool.pyve.testenvs] hint" {
    _fixture_named_envs
    run testenv_command init bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"tool.pyve.testenvs"* ]]
    [ ! -d ".pyve/testenvs/bogus" ]
}

@test "testenv init <name>: conda-backed name errors with M.k stub message" {
    _fixture_named_envs
    run testenv_command init hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"M.k"* ]]
    [ ! -d ".pyve/testenvs/hardware" ]
}
