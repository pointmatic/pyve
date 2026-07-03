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
# install semantics from `env_install`.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Pre-create a fake testenv venv at .pyve/envs/<name>/venv/bin/python
# so env_install passes the existence guard without invoking real python.
_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    cat > ".pyve/envs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/$name/venv/bin/python"
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
    # Declared `requirements = [...]` is consumed at install time. Create the
    # declared files on disk so the fixture stays usable across the install tests.
    mkdir -p tests
    printf 'pytest\n' > requirements-dev.txt
    printf 'pytest-asyncio\n' > tests/smoke-requirements.txt
    # heavy's file does not need to exist (lazy = true → never iterated).
}

# ============================================================
# no-arg with NO [tool.pyve.testenvs] block: implicit default `testenv`
# ============================================================

@test "testenv install: no-arg without config installs into default testenv (today's behavior)" {
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install
    [ "$status" -eq 0 ]
    [[ "$output" == *"envs/testenv/venv/bin/python"* ]]
}

# ============================================================
# no-arg with declared named envs: iterate non-lazy, skip lazy
# ============================================================

@test "testenv install: no-arg with declared envs iterates non-lazy (incl. conda after M.k), skips lazy" {
    _fixture_named_envs
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke
    _make_fake_named_venv heavy
    # Story M.k: the conda env now needs its manifest on disk + a fake
    # micromamba binary so iteration successfully passes through it.
    mkdir -p tests
    printf 'name: hardware\ndependencies: [python]\n' > tests/env.yml
    mkdir -p .pyve/envs/hardware/conda/conda-meta   # `install` requires existing env
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'SH'
#!/usr/bin/env bash
printf 'MICROMAMBA:%s\n' "$*"
exit 0
SH
    chmod +x .pyve/bin/micromamba
    _stub_run_cmd_records

    run env_command install
    [ "$status" -eq 0 ]
    # testenv + smoke are non-lazy → both installed via pip.
    [[ "$output" == *"envs/testenv/venv/bin/python"* ]]
    [[ "$output" == *"envs/smoke/venv/bin/python"* ]]
    # heavy is lazy → NOT installed.
    [[ "$output" != *"envs/heavy/venv/bin/python"* ]]
    # hardware is conda-backed → installed via micromamba (M.k landed).
    [[ "$output" == *"MICROMAMBA:install -p .pyve/envs/hardware/conda -f tests/env.yml -y"* ]]
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
    run env_command install
    [ "$status" -eq 0 ]
    [[ "$output" == *"envs/testenv/"* ]]
    [[ "$output" != *"envs/heavy/"* ]]
}

# ============================================================
# with-arg single-env: declared venv-backed
# ============================================================

@test "testenv install <name>: declared venv-backed env installs into that env only" {
    _fixture_named_envs
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run env_command install smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"envs/smoke/venv/bin/python"* ]]
    # Default testenv NOT installed as a side effect.
    [[ "$output" != *"envs/testenv/"* ]]
}

@test "testenv install <lazy-name>: explicit install bypasses lazy-skip (M.n regression)" {
    # M.i.3 made no-arg iteration skip lazy envs. Story M.n verifies
    # the dual behavior: an explicit name installs the lazy env
    # normally — the lazy bit only gates *bulk* / iteration paths.
    _fixture_named_envs
    mkdir -p tests
    printf 'pytest\n' > tests/heavy.txt
    _make_fake_named_venv heavy
    _stub_run_cmd_records
    run env_command install heavy
    [ "$status" -eq 0 ]
    [[ "$output" == *"envs/heavy/venv/bin/python"* ]]
    [[ "$output" == *"-r tests/heavy.txt"* ]]
}

# ============================================================
# Name validation
# ============================================================

@test "testenv install root: reserved 'root' hard-errors" {
    _fixture_named_envs
    run env_command install root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "testenv install <undeclared>: hard-errors with [env.<name>] hint" {
    _fixture_named_envs
    : > pyve.toml  # N.bf.18: initialized project → 'bogus' reaches the not-declared path
    run env_command install bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    # N.bf.19: points at the v3 surface, not the v2 [tool.pyve.testenvs].
    [[ "$output" == *"[env.bogus]"* ]]
    [[ "$output" != *"tool.pyve.testenvs"* ]]
}

@test "testenv install <conda-backed>: uninitialized env hard-errors before lock (N.bf.20)" {
    # Story M.k landed: conda install routes through `_env_install_conda`.
    # Story N.bf.20: the env-initialized gate now runs BEFORE the install
    # lock (and before _env_install_conda's manifest check), so installing
    # into a conda env that was never created reports "not initialized"
    # and materializes no `.pyve` stray — init must precede install.
    _fixture_named_envs
    run env_command install hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"not initialized"* ]]
    [[ "$output" == *"pyve env init hardware"* ]]
    [ ! -e ".pyve/envs/hardware" ]
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
    run env_command install -r requirements-dev.txt
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
    run env_command install smoke -r tests/smoke-requirements.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"envs/smoke/venv/bin/python"* ]]
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
    run env_command install -r tests/smoke-requirements.txt smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"envs/smoke/venv/bin/python"* ]]
    [[ "$output" == *"-r tests/smoke-requirements.txt"* ]]
}
