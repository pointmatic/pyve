#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Venv materializer: compose the full directive recipe in one shot.
#
# `_env_install_venv` materializes EVERY declared directive in the
# fixed order `editable` → `requirements` → `extra` (was M.l's
# pick-one precedence dispatch; the source mutex is lifted). The
# recipe is validated up front so a bad directive fails before any
# layer installs. `pyve env init <name>` now materializes the whole
# recipe after creating the env — but ONLY what is declared: an
# undeclared env comes up empty (no fallback chain from init).
#
# CLI `-r <file>` stays a full override; the no-declaration fallback
# chain of `pyve env install` (requirements-dev.txt / bare pytest) is
# unchanged — both covered in test_testenv_venv_manifest.bats.

bats_require_minimum_version 1.5.0

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

# Print the 1-based output line number of the first line matching the
# given substring pattern (grep -n over $output).
_line_of() {
    printf '%s\n' "$output" | grep -n -- "$1" | head -1 | cut -d: -f1
}

# ============================================================
# The `editable` directive materializes (declared in the schema; this
# is its first consumer)
# ============================================================

@test "materializer: 'editable' alone → 'pip install -e .[extras]'" {
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
editable = ".[corruptions]"
TOML
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"-m pip install -e .[corruptions]"* ]]
}

# ============================================================
# Composition — the mutex is gone; directives layer in order
# ============================================================

@test "materializer: full recipe composes in order editable → requirements → extra" {
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
editable = ".[corruptions]"
requirements = ["requirements-dev.txt"]
extra = "lint"
TOML
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
lint = ["ruff==0.6.0"]
TOML
    printf 'pytest\n' > requirements-dev.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -eq 0 ]
    # All three layers ran...
    [[ "$output" == *"pip install -e .[corruptions]"* ]]
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
    [[ "$output" == *"ruff==0.6.0"* ]]
    # ...in the fixed order.
    local ed_line req_line extra_line
    ed_line="$(_line_of 'pip install -e')"
    req_line="$(_line_of 'pip install -r')"
    extra_line="$(_line_of 'ruff==0.6.0')"
    [ "$ed_line" -lt "$req_line" ]
    [ "$req_line" -lt "$extra_line" ]
}

@test "materializer: the field scenario — editable + requirements, one command" {
    # ml-datarefinery's four-command rebuild collapses: the recipe
    # declares the editable self-install AND the dev requirements.
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
editable = ".[corruptions]"
requirements = ["requirements-dev.txt"]
TOML
    printf 'pytest\n' > requirements-dev.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install -e .[corruptions]"* ]]
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
}

# ============================================================
# Up-front validation — a bad directive fails before any layer runs
# ============================================================

@test "materializer: missing requirements file fails BEFORE the editable layer installs" {
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
editable = "."
requirements = ["tests/missing.txt"]
TOML
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/missing.txt"* ]]
    # The whole recipe is validated up front — nothing installed.
    [[ "$output" != *"RUN_CMD:"* ]]
}

@test "materializer: unresolvable extra fails BEFORE the editable layer installs" {
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
editable = "."
extra = "nope"
TOML
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest"]
TOML
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -ne 0 ]
    [[ "$output" != *"RUN_CMD:"* ]]
}

# ============================================================
# Back-compat: single-directive recipes and the CLI override
# ============================================================

@test "materializer: requirements-only block materializes exactly as before (no -e)" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[env.smoke]
purpose = "test"
backend = "venv"
requirements = ["tests/smoke-requirements.txt"]
TOML
    mkdir -p tests
    printf 'ruff\n' > tests/smoke-requirements.txt
    _make_fake_named_venv smoke
    _stub_run_cmd_records
    run env_command install smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"-m pip install -r tests/smoke-requirements.txt"* ]]
    [[ "$output" != *"pip install -e"* ]]
}

@test "materializer: CLI '-r <file>' overrides the whole recipe" {
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
editable = ".[corruptions]"
requirements = ["should-not-be-used.txt"]
TOML
    printf 'pytest\n' > requirements-cli.txt
    printf 'ignored\n' > should-not-be-used.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv -r requirements-cli.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"-r requirements-cli.txt"* ]]
    [[ "$output" != *"pip install -e"* ]]
    [[ "$output" != *"should-not-be-used.txt"* ]]
}

# ============================================================
# One-shot init — `pyve env init <name>` materializes the recipe
# ============================================================

@test "one-shot init: 'env init <name>' materializes the declared recipe" {
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
editable = ".[corruptions]"
requirements = ["requirements-dev.txt"]
TOML
    printf 'pytest\n' > requirements-dev.txt
    # Pre-create the venv so ensure_env_exists skips creation and the
    # stubbed run_cmd only records the install layers.
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command init testenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install -e .[corruptions]"* ]]
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
}

@test "one-shot init: no declared directives → init installs nothing (no fallback)" {
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
TOML
    # requirements-dev.txt present — env *install*'s fallback would use
    # it, but init must not ("init installs what you declared, nothing
    # you didn't").
    printf 'pytest\n' > requirements-dev.txt
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command init testenv
    [ "$status" -eq 0 ]
    [[ "$output" != *"pip install"* ]]
}
