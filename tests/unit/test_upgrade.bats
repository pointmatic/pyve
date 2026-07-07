#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve upgrade` — re-resolve an env's dependencies to newest-within-
# constraints while KEEPING the env directory (no purge/rebuild), then
# re-stamp the operational-state record and re-lock where a lock file
# participates. The verb boundary: `update` touches the files Pyve
# manages around your project; `init --force`/`upgrade` touch the
# environments themselves. `--check` previews the plan and executes
# nothing. Upgrade never creates: a never-realized target errors with
# the standard `pyve env init` hint.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/commands/upgrade.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

_stub_run_cmd_records() {
    run_cmd() {
        printf 'RUN_CMD:%s\n' "$*"
    }
}

_make_fake_root_venv() {
    mkdir -p ".venv/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > ".venv/bin/python"
    chmod +x ".venv/bin/python"
}

_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > ".pyve/envs/$name/venv/bin/python"
    chmod +x ".pyve/envs/$name/venv/bin/python"
}

_fixture_root_venv() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
TOML
}

# ============================================================
# Root env — bare `pyve upgrade`
# ============================================================

@test "upgrade: bare invocation upgrades the root venv from requirements.txt" {
    _fixture_root_venv
    printf 'requests==2.31.0\n' > requirements.txt
    _make_fake_root_venv
    _stub_run_cmd_records
    run upgrade_environment
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install --upgrade -r requirements.txt"* ]]
}

@test "upgrade: root falls back to 'pip install --upgrade -e .' on a pyproject-only project" {
    _fixture_root_venv
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"
TOML
    _make_fake_root_venv
    _stub_run_cmd_records
    run upgrade_environment
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install --upgrade -e ."* ]]
}

# ============================================================
# Named env — declared recipe, env preserved, state re-stamped
# ============================================================

_fixture_named_recipe() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[env.alpha]
purpose = "test"
backend = "venv"
editable = ".[dev]"
requirements = ["requirements-dev.txt"]
TOML
    printf 'pytest\n' > requirements-dev.txt
}

@test "upgrade --env <name>: recipe re-resolves with --upgrade; env dir is KEPT; installed re-stamped" {
    _fixture_named_recipe
    _make_fake_named_venv alpha
    touch ".pyve/envs/alpha/venv/sentinel"
    state_write alpha venv last_used_at=777 installed_at=1
    _stub_run_cmd_records
    run upgrade_environment --env alpha
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install --upgrade -e .[dev]"* ]]
    [[ "$output" == *"pip install --upgrade -r requirements-dev.txt"* ]]
    # The env was upgraded in place, not rebuilt.
    [ -f ".pyve/envs/alpha/venv/sentinel" ]
    # Installed dimension re-stamped; usage provenance untouched.
    state_read alpha
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" != "1" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "777" ]
}

@test "upgrade: a never-realized target errors with the init hint — upgrade never creates" {
    _fixture_named_recipe
    _stub_run_cmd_records
    run upgrade_environment --env alpha
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve env init"* ]]
    [ ! -d ".pyve/envs/alpha" ]
}

# ============================================================
# Conda env — update → pip layer → re-lock ordering
# ============================================================

@test "upgrade: conda env runs micromamba update, then pip --upgrade, then re-locks" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[env.hardware]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
requirements = ["requirements-hw.txt"]
TOML
    cat > environment.yml <<'YAML'
name: hardware
channels: [conda-forge]
dependencies: [python=3.12]
YAML
    printf 'ruff\n' > requirements-hw.txt
    printf 'lock\n' > conda-lock.yml
    mkdir -p ".pyve/envs/hardware/conda/conda-meta"
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'SH'
#!/usr/bin/env bash
printf 'MM:%s\n' "$*" >> mm.log
exit 0
SH
    chmod +x .pyve/bin/micromamba
    lock_environment() {
        printf 'LOCK:%s\n' "$*" >> mm.log
    }
    _stub_run_cmd_records
    run upgrade_environment --env hardware
    [ "$status" -eq 0 ]
    grep -q "^MM:update -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    [[ "$output" == *"pip install --upgrade -r requirements-hw.txt"* ]]
    grep -q "^LOCK:--env hardware" mm.log
}

# ============================================================
# --check: preview only
# ============================================================

@test "upgrade --check: prints the plan, executes nothing, state untouched" {
    _fixture_named_recipe
    _make_fake_named_venv alpha
    state_write alpha venv installed_at=42
    _stub_run_cmd_records
    run upgrade_environment --env alpha --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run"* ]]
    [[ "$output" != *"RUN_CMD:"* ]]
    state_read alpha
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" = "42" ]
}

# ============================================================
# --all fan-out
# ============================================================

@test "upgrade --all: root + declared envs; one failure continues; worst rc wins" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[env.alpha]
purpose = "test"
backend = "venv"
requirements = ["requirements-dev.txt"]

[env.sleepy]
purpose = "test"
backend = "venv"
lazy = true
TOML
    printf 'pytest\n' > requirements-dev.txt
    printf 'requests\n' > requirements.txt
    _make_fake_root_venv
    _make_fake_named_venv alpha
    state_write alpha venv installed_at=1
    _stub_run_cmd_records
    run upgrade_environment --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"pip install --upgrade -r requirements.txt"* ]]
    [[ "$output" == *"pip install --upgrade -r requirements-dev.txt"* ]]
    [[ "$output" == *"sleepy"* ]]
    [ ! -d ".pyve/envs/sleepy" ]
}

# ============================================================
# Errors + help boundary
# ============================================================

@test "upgrade --env <unknown>: standard actionable hint, nonzero" {
    _fixture_root_venv
    run upgrade_environment --env nope
    [ "$status" -ne 0 ]
}

@test "upgrade --help: documents the update/upgrade boundary" {
    run show_upgrade_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"around your project"* ]]
    [[ "$output" == *"environments themselves"* ]]
}
