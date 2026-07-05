#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for M.i.1 internal helpers:
#
#   assert_env_name_actionable <name>
#     in lib/envs.sh — name-legality gate. 0 if <name> is declared
#     or equals the reserved `testenv`; 1 (stderr error) for `root` and
#     undeclared names.
#
#   _env_resolve_backend <name>
#     in lib/envs.sh — resolves <name> to a concrete backend (venv /
#     micromamba), following `inherit` to the main env's backend. The
#     `pyve env run` / `pyve test` callsites dispatch on its result
#     (venv → PATH activation; micromamba → `micromamba run -p`).
#
#   ensure_env_exists [<name>]
#     in lib/utils.sh — name-aware existence-or-create. No arg defaults
#     to the reserved `testenv` (today's behavior). With arg: validates
#     via the name gate above, then creates `.pyve/envs/<name>/venv`
#     for venv-backed envs.
#
# Bundle scope: M.i.1 is internal-helpers-only — no leaf CLI changes.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    # Story M.k: ensure_env_exists now dispatches into
    # `_env_init_conda` (defined in lib/commands/env.sh) for
    # conda-backed envs, so the testenv command file must be sourced
    # alongside the testenvs library to exercise the full call path.
    source "$PYVE_ROOT/lib/commands/env.sh"
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
lazy = true
TOML
}

# ============================================================
# assert_env_name_actionable
# ============================================================

@test "assert_env_name_actionable: declared name passes" {
    _fixture_named_envs
    read_env_config
    assert_env_name_actionable smoke
    assert_env_name_actionable testenv
    assert_env_name_actionable hardware    # declared; conda-stub is a SEPARATE gate
}

@test "assert_env_name_actionable: reserved 'root' is rejected with selection-only hint" {
    _fixture_named_envs
    read_env_config
    run assert_env_name_actionable root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"selection-only"* || "$output" == *"pyve test --env root"* || "$output" == *"not a testenv"* ]]
}

@test "assert_env_name_actionable: undeclared name is rejected with [env.<name>] hint" {
    _fixture_named_envs
    : > pyve.toml  # N.bf.18: initialized project → 'bogus' reaches the not-declared path
    read_env_config
    run assert_env_name_actionable bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    # N.bf.19: points at the v3 surface, not the v2 [tool.pyve.testenvs].
    [[ "$output" == *"[env.bogus]"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
}

@test "assert_env_name_actionable: empty config still accepts reserved 'testenv'" {
    # No pyproject.toml — implicit-default config has `testenv` only.
    read_env_config
    assert_env_name_actionable testenv
    run assert_env_name_actionable smoke
    [ "$status" -ne 0 ]
}

# ============================================================
# ensure_env_exists (no arg) — back-compat
# ============================================================

@test "ensure_env_exists: no arg creates the default testenv venv at new path" {
    _stub_run_cmd_creates_venv
    ensure_env_exists
    [ -d ".pyve/envs/testenv/venv" ]
    [ -x ".pyve/envs/testenv/venv/bin/python" ]
}

@test "ensure_env_exists: no arg is idempotent" {
    _stub_run_cmd_creates_venv
    ensure_env_exists
    local marker_mtime_a
    marker_mtime_a=$(stat -f %m ".pyve/envs/testenv/venv/bin/python" 2>/dev/null || stat -c %Y ".pyve/envs/testenv/venv/bin/python")
    ensure_env_exists
    local marker_mtime_b
    marker_mtime_b=$(stat -f %m ".pyve/envs/testenv/venv/bin/python" 2>/dev/null || stat -c %Y ".pyve/envs/testenv/venv/bin/python")
    [ "$marker_mtime_a" = "$marker_mtime_b" ]
}

# ============================================================
# ensure_env_exists (with arg) — name-aware
# ============================================================

@test "ensure_env_exists: with declared venv-backed name creates at .pyve/envs/<name>/venv" {
    _fixture_named_envs
    _stub_run_cmd_creates_venv
    ensure_env_exists smoke
    [ -d ".pyve/envs/smoke/venv" ]
    [ -x ".pyve/envs/smoke/venv/bin/python" ]
    # The default testenv is NOT created as a side effect.
    [ ! -d ".pyve/envs/testenv/venv" ]
}

@test "ensure_env_exists: reserved 'root' is rejected (not a testenv)" {
    _fixture_named_envs
    run ensure_env_exists root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [ ! -d ".pyve/envs/root" ]
}

@test "ensure_env_exists: undeclared name is rejected with [env.<name>] hint" {
    _fixture_named_envs
    : > pyve.toml  # N.bf.18: initialized project → 'bogus' reaches the not-declared path
    run ensure_env_exists bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    # N.bf.19: points at the v3 surface, not the v2 [tool.pyve.testenvs].
    [[ "$output" == *"[env.bogus]"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
    [ ! -d ".pyve/envs/bogus" ]
}

@test "ensure_env_exists: conda-backed name with missing manifest file hard-errors (M.k)" {
    # M.k landed conda init for declared envs whose manifest exists.
    # When the manifest is declared but the file is missing, surface
    # a clear error (no half-created env).
    _fixture_named_envs
    # hardware's manifest = "tests/env.yml" — intentionally NOT created.
    run ensure_env_exists hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/env.yml"* ]]
    # Conda env was not created.
    [ ! -d ".pyve/envs/hardware/conda/conda-meta" ]
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
        source '$PYVE_ROOT/lib/envs.sh'
        workdir=\$(mktemp -d)
        cd \"\$workdir\"
        read_env_config
        assert_env_name_actionable testenv
        _env_resolve_backend testenv
        assert_env_name_actionable root 2>/dev/null || true
        assert_env_name_actionable bogus 2>/dev/null || true
        rm -rf \"\$workdir\"
    " 2>&1)" || true
    [[ "$output" != *"unbound variable"* ]] || {
        echo "stderr contained 'unbound variable':"
        echo "$output"
        false
    }
}
