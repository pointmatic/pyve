#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve testenv init [<name>]` (Story M.i.2).
#
# Dispatcher accepts an optional positional <name> after `init`.
# Routing rules:
#   - no arg                  → default `testenv`
#   - declared venv-backed    → create at .pyve/envs/<name>/venv
#   - reserved `root`         → hard-error (selection-only)
#   - undeclared              → hard-error (with [tool.pyve.testenvs] hint)
#   - conda-backed declared   → M.k stub hard-error

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
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
    # `env init` now materializes the declared recipe, so the
    # declared requirements files must exist for init to succeed.
    mkdir -p tests
    printf 'pytest\n' > requirements-dev.txt
    printf 'ruff\n' > tests/smoke-requirements.txt
}

# ============================================================
# no-arg behavior preserved
# ============================================================

@test "testenv init: no arg creates the default testenv at the new path" {
    _stub_run_cmd_creates_venv
    run env_command init
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/testenv/venv" ]
}

# ============================================================
# with-arg routing
# ============================================================

@test "testenv init <name>: declared venv-backed name creates at .pyve/envs/<name>/venv" {
    _fixture_named_envs
    _stub_run_cmd_creates_venv
    run env_command init smoke
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/smoke/venv" ]
    # Default testenv NOT created as a side effect.
    [ ! -d ".pyve/envs/testenv/venv" ]
}

@test "testenv init <name>: reserved 'root' hard-errors" {
    _fixture_named_envs
    run env_command init root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [ ! -d ".pyve/envs/root" ]
}

@test "testenv init <name>: undeclared name hard-errors with [env.<name>] hint" {
    _fixture_named_envs
    : > pyve.toml  # N.bf.18: initialized project → 'bogus' reaches the not-declared path
    run env_command init bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    # N.bf.19: points at the v3 surface, not the v2 [tool.pyve.testenvs].
    [[ "$output" == *"[env.bogus]"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
    [ ! -d ".pyve/envs/bogus" ]
}

@test "testenv init <name>: conda-backed name with missing manifest file hard-errors (M.k)" {
    # Story M.k landed: conda-backed init/install now route through
    # `micromamba`. With a declared manifest that does not exist on disk,
    # the dispatch should hard-error before invoking the binary so no
    # half-created env is left behind.
    _fixture_named_envs
    # hardware's manifest = "tests/env.yml" — intentionally NOT created.
    run env_command init hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/env.yml"* ]]
    [ ! -d ".pyve/envs/hardware/conda/conda-meta" ]
}
