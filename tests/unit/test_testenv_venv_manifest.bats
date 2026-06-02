#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.l — venv testenv manifest sources.
#
# `_env_install_venv` (renamed from `env_install` in M.l for
# symmetry with M.k's `_env_install_conda`) dispatches on the
# declared install source from [tool.pyve.testenvs.<name>]:
#
#   1. CLI `-r <file>` (always wins; today's explicit-override behavior).
#   2. Declared `requirements = ["a.txt", "b.txt"]` → `pip install -r a.txt -r b.txt`.
#   3. Declared `extra = "<name>"` → resolve via Python helper
#      (`[project.optional-dependencies].<name>`), `pip install <pkg1> <pkg2>`.
#   4. Auto-detected `requirements-dev.txt` present → `pip install -r requirements-dev.txt`.
#   5. Bare `pytest` fallback (today's default).
#
# Validation of mutually-exclusive `requirements` / `extra` / `manifest`
# is already enforced by the M.g Python helper at read time; the bats
# test here just confirms the helper still fires.

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
_stub_run_cmd_records() {
    run_cmd() {
        printf 'RUN_CMD:%s\n' "$*"
    }
}

# ============================================================
# `requirements = [...]` — single and multi-file
# ============================================================

@test "venv install: declared 'requirements' (single file) → 'pip install -r <file>'" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]
TOML
    mkdir -p tests
    printf 'ruff\n' > tests/smoke-requirements.txt
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run env_command install smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"-m pip install -r tests/smoke-requirements.txt"* ]]
}

@test "venv install: declared 'requirements' (multi-file) → 'pip install -r a -r b'" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements.txt", "requirements-dev.txt"]
TOML
    printf 'requests\n' > requirements.txt
    printf 'pytest\n' > requirements-dev.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"-r requirements.txt -r requirements-dev.txt"* ]]
}

@test "venv install: declared 'requirements' with a missing file hard-errors" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.smoke]
requirements = ["tests/missing.txt"]
TOML
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run env_command install smoke
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/missing.txt"* ]]
}

# ============================================================
# `extra = "<name>"` — pyproject [project.optional-dependencies]
# ============================================================

@test "venv install: declared 'extra' resolves to 'pip install <pkg list>'" {
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest>=8", "ruff==0.6.0"]

[tool.pyve.testenvs.testenv]
extra = "dev"
TOML
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install"* ]]
    [[ "$output" == *"pytest>=8"* ]]
    [[ "$output" == *"ruff==0.6.0"* ]]
}

@test "venv install: declared 'extra' that does not exist in pyproject hard-errors" {
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest"]

[tool.pyve.testenvs.testenv]
extra = "missing"
TOML
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing"* ]]
}

# ============================================================
# Fallback chain (no declarations)
# ============================================================

@test "venv install: no declarations, requirements-dev.txt present → auto-uses it" {
    _make_fake_named_venv testenv
    printf 'pytest\n' > requirements-dev.txt
    _stub_run_cmd_records
    run env_command install
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
}

@test "venv install: no declarations, no requirements-dev.txt → bare 'pytest'" {
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install
    [ "$status" -eq 0 ]
    # Today's default: bare pytest install.
    [[ "$output" == *"pip install pytest"* ]]
    [[ "$output" != *"-r"* ]]
}

# ============================================================
# CLI `-r <file>` overrides every declaration
# ============================================================

@test "venv install: CLI '-r <file>' overrides declared 'requirements'" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["should-not-be-used.txt"]
TOML
    printf 'pytest\n' > requirements-cli.txt
    printf 'ignored\n' > should-not-be-used.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install -r requirements-cli.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"-r requirements-cli.txt"* ]]
    [[ "$output" != *"should-not-be-used.txt"* ]]
}

@test "venv install: CLI '-r <file>' overrides declared 'extra'" {
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["should-not-be-installed"]

[tool.pyve.testenvs.testenv]
extra = "dev"
TOML
    printf 'pytest\n' > requirements-cli.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install -r requirements-cli.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"-r requirements-cli.txt"* ]]
    [[ "$output" != *"should-not-be-installed"* ]]
}

# ============================================================
# Validation: M.g helper still rejects mutually-exclusive sources
# ============================================================

@test "venv install: declaring both 'requirements' and 'extra' fails at config read" {
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest"]

[tool.pyve.testenvs.bad]
requirements = ["requirements-dev.txt"]
extra = "dev"
TOML
    _make_fake_named_venv bad
    _stub_run_cmd_records
    run env_command install bad
    [ "$status" -ne 0 ]
    # The M.g Python helper batches this as
    # "pyve.testenvs.bad: only one of 'requirements'/'extra'/'manifest' may be declared".
    [[ "$output" == *"only one of"* ]]
}

# ============================================================
# Iteration through the lock wrapper still honors the new dispatch
# ============================================================

@test "venv install: iteration installs declared 'extra' for one env and 'requirements' for another" {
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["ruff>=0.6"]

[tool.pyve.testenvs.testenv]
extra = "dev"

[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]
TOML
    mkdir -p tests
    printf 'pytest-asyncio\n' > tests/smoke-requirements.txt
    _make_fake_named_venv testenv
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run env_command install
    [ "$status" -eq 0 ]
    # testenv: extra resolution → ruff>=0.6 in args.
    [[ "$output" == *"ruff>=0.6"* ]]
    # smoke: requirements → -r tests/smoke-requirements.txt.
    [[ "$output" == *"-r tests/smoke-requirements.txt"* ]]
}
