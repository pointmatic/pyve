#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for M.i.1 internal helpers:
#
#   assert_testenv_name_actionable <name>
#     in lib/testenvs.sh — name-legality gate. 0 if <name> is declared
#     or equals the reserved `testenv`; 1 (stderr error) for `root` and
#     undeclared names.
#
#   assert_testenv_venv_backend <name>
#     in lib/testenvs.sh — venv-only gate (still used by `pyve testenv
#     run` since M.k landed init/install for conda but not run). 0 if
#     the resolved backend is venv; 1 (stderr error) for micromamba
#     and `inherit` resolving to micromamba.
#
#   ensure_testenv_exists [<name>]
#     in lib/utils.sh — name-aware existence-or-create. No arg defaults
#     to the reserved `testenv` (today's behavior). With arg: validates
#     via the two gates above, then creates `.pyve/testenvs/<name>/venv`
#     for venv-backed envs.
#
# Bundle scope: M.i.1 is internal-helpers-only — no leaf CLI changes.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/testenvs.sh"
    # Story M.k: ensure_testenv_exists now dispatches into
    # `_testenv_init_conda` (defined in lib/commands/testenv.sh) for
    # conda-backed envs, so the testenv command file must be sourced
    # alongside the testenvs library to exercise the full call path.
    source "$PYVE_ROOT/lib/commands/testenv.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ---------- fixture helpers ----------

# Stub run_cmd to simulate `python -m venv <path>` by creating a marker
# venv at the requested path. Avoids invoking real python (whose asdf
# shim resolves from cwd and breaks in bats tmp dirs).
_stub_run_cmd_creates_venv() {
    run_cmd() {
        # Expected invocation: run_cmd python -m venv <path>
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
[tool.pyve.testenvs]
default = "testenv"

[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]

[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
lazy = true
TOML
}

# ============================================================
# assert_testenv_name_actionable
# ============================================================

@test "assert_testenv_name_actionable: declared name passes" {
    _fixture_named_envs
    read_testenv_config
    assert_testenv_name_actionable smoke
    assert_testenv_name_actionable testenv
    assert_testenv_name_actionable hardware    # declared; conda-stub is a SEPARATE gate
}

@test "assert_testenv_name_actionable: reserved 'root' is rejected with selection-only hint" {
    _fixture_named_envs
    read_testenv_config
    run assert_testenv_name_actionable root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"selection-only"* || "$output" == *"pyve test --env root"* || "$output" == *"not a testenv"* ]]
}

@test "assert_testenv_name_actionable: undeclared name is rejected with [tool.pyve.testenvs] hint" {
    _fixture_named_envs
    read_testenv_config
    run assert_testenv_name_actionable bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"tool.pyve.testenvs"* ]]
}

@test "assert_testenv_name_actionable: empty config still accepts reserved 'testenv'" {
    # No pyproject.toml — implicit-default config has `testenv` only.
    read_testenv_config
    assert_testenv_name_actionable testenv
    run assert_testenv_name_actionable smoke
    [ "$status" -ne 0 ]
}

# ============================================================
# assert_testenv_venv_backend
# ============================================================

@test "assert_testenv_venv_backend: venv-backed name passes" {
    _fixture_named_envs
    read_testenv_config
    assert_testenv_venv_backend smoke
    assert_testenv_venv_backend testenv
}

@test "assert_testenv_venv_backend: micromamba-backed name is rejected (run is venv-only)" {
    _fixture_named_envs
    read_testenv_config
    run assert_testenv_venv_backend hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"hardware"* ]]
    [[ "$output" == *"conda"* || "$output" == *"micromamba"* ]]
}

@test "assert_testenv_venv_backend: 'inherit' + main=micromamba is rejected" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
manifest = "environment.yml"
TOML
    mkdir -p .pyve
    printf 'backend: micromamba\n' > .pyve/config
    read_testenv_config
    run assert_testenv_venv_backend mirror
    [ "$status" -ne 0 ]
    [[ "$output" == *"mirror"* ]]
}

@test "assert_testenv_venv_backend: 'inherit' + main=venv passes (M.k inherit resolution)" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
TOML
    mkdir -p .pyve
    printf 'backend: venv\n' > .pyve/config
    read_testenv_config
    assert_testenv_venv_backend mirror
}

# ============================================================
# ensure_testenv_exists (no arg) — back-compat
# ============================================================

@test "ensure_testenv_exists: no arg creates the default testenv venv at new path" {
    _stub_run_cmd_creates_venv
    ensure_testenv_exists
    [ -d ".pyve/testenvs/testenv/venv" ]
    [ -x ".pyve/testenvs/testenv/venv/bin/python" ]
}

@test "ensure_testenv_exists: no arg is idempotent" {
    _stub_run_cmd_creates_venv
    ensure_testenv_exists
    local marker_mtime_a
    marker_mtime_a=$(stat -f %m ".pyve/testenvs/testenv/venv/bin/python" 2>/dev/null || stat -c %Y ".pyve/testenvs/testenv/venv/bin/python")
    ensure_testenv_exists
    local marker_mtime_b
    marker_mtime_b=$(stat -f %m ".pyve/testenvs/testenv/venv/bin/python" 2>/dev/null || stat -c %Y ".pyve/testenvs/testenv/venv/bin/python")
    [ "$marker_mtime_a" = "$marker_mtime_b" ]
}

# ============================================================
# ensure_testenv_exists (with arg) — name-aware
# ============================================================

@test "ensure_testenv_exists: with declared venv-backed name creates at .pyve/testenvs/<name>/venv" {
    _fixture_named_envs
    _stub_run_cmd_creates_venv
    ensure_testenv_exists smoke
    [ -d ".pyve/testenvs/smoke/venv" ]
    [ -x ".pyve/testenvs/smoke/venv/bin/python" ]
    # The default testenv is NOT created as a side effect.
    [ ! -d ".pyve/testenvs/testenv/venv" ]
}

@test "ensure_testenv_exists: reserved 'root' is rejected (not a testenv)" {
    _fixture_named_envs
    run ensure_testenv_exists root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [ ! -d ".pyve/testenvs/root" ]
}

@test "ensure_testenv_exists: undeclared name is rejected with [tool.pyve.testenvs] hint" {
    _fixture_named_envs
    run ensure_testenv_exists bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"tool.pyve.testenvs"* ]]
    [ ! -d ".pyve/testenvs/bogus" ]
}

@test "ensure_testenv_exists: conda-backed name with missing manifest file hard-errors (M.k)" {
    # M.k landed conda init for declared envs whose manifest exists.
    # When the manifest is declared but the file is missing, surface
    # a clear error (no half-created env).
    _fixture_named_envs
    # hardware's manifest = "tests/env.yml" — intentionally NOT created.
    run ensure_testenv_exists hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/env.yml"* ]]
    # Conda env was not created.
    [ ! -d ".pyve/testenvs/hardware/conda/conda-meta" ]
}

# ============================================================
# bash-3.2 set -u safety (project-essentials rule)
# ============================================================

@test "no 'unbound variable' under 'set -euo pipefail' for the M.i.1 surface" {
    output="$(/bin/bash -c "
        set -euo pipefail
        export PYVE_ROOT='$PYVE_ROOT'
        export PYVE_PYTHON='$PYVE_PYTHON'
        export TESTENV_DIR_NAME='testenv'
        source '$PYVE_ROOT/lib/ui/core.sh'
        source '$PYVE_ROOT/lib/ui/run.sh'
        source '$PYVE_ROOT/lib/utils.sh'
        source '$PYVE_ROOT/lib/testenvs.sh'
        workdir=\$(mktemp -d)
        cd \"\$workdir\"
        read_testenv_config
        assert_testenv_name_actionable testenv
        assert_testenv_venv_backend testenv
        assert_testenv_name_actionable root 2>/dev/null || true
        assert_testenv_name_actionable bogus 2>/dev/null || true
        rm -rf \"\$workdir\"
    " 2>&1)" || true
    [[ "$output" != *"unbound variable"* ]] || {
        echo "stderr contained 'unbound variable':"
        echo "$output"
        false
    }
}
