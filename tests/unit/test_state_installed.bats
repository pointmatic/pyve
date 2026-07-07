#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# The .state installed dimension — record actual (vs declared) env
# state so a rebuild can restore it. `.state` gains `installed_at`
# (0 = realized only; >0 = install completed then) and
# `installed_sha256` (digest of the effective install spec: editable
# target, requirements file contents, extra + pyproject, conda
# manifest). The install paths write it; realize-only envs read as
# "realized, not installed"; `pyve env list` renders the recorded
# state (ready vs realized) instead of re-deriving it. Pre-existing
# five-field .state files read with installed_at=0 — recorded truth,
# never a guess.

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

_fixture_declared() {
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

[env.bare]
purpose = "test"
backend = "venv"
TOML
    printf 'pytest\n' > requirements-dev.txt
    read_env_config
}

_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > ".pyve/envs/$name/venv/bin/python"
    chmod +x ".pyve/envs/$name/venv/bin/python"
}

_stub_run_cmd_records() {
    run_cmd() { printf 'RUN_CMD:%s\n' "$*"; }
}

# ============================================================
# Schema round-trip + back-compat
# ============================================================

@test "state: installed_at + installed_sha256 round-trip through write/read" {
    state_write demo venv installed_at=1735689600 installed_sha256=abc123
    state_read demo
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" = "1735689600" ]
    [ "$PYVE_TESTENV_STATE_INSTALLED_SHA256" = "abc123" ]
}

@test "state: a pre-installed-dimension five-field .state reads as installed_at=0" {
    mkdir -p .pyve/envs/old
    cat > .pyve/envs/old/.state <<'EOF'
backend=venv
manifest=
manifest_sha256=
provisioned_at=1735689600
last_used_at=0
EOF
    state_read old
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" = "0" ]
    [ -z "$PYVE_TESTENV_STATE_INSTALLED_SHA256" ]
}

@test "state: state_touch_last_used preserves the installed fields" {
    state_write demo venv installed_at=1735689600 installed_sha256=abc123
    state_touch_last_used demo
    state_read demo
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" = "1735689600" ]
    [ "$PYVE_TESTENV_STATE_INSTALLED_SHA256" = "abc123" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" != "0" ]
}

# ============================================================
# The install paths record; realize-only does not
# ============================================================

@test "installed: venv install stamps installed_at and a 64-hex spec digest" {
    _fixture_declared
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    [ "$status" -eq 0 ]
    state_read testenv
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" != "0" ]
    [[ "$PYVE_TESTENV_STATE_INSTALLED_SHA256" =~ ^[0-9a-f]{64}$ ]]
}

@test "installed: the spec digest tracks the requirements file's content" {
    _fixture_declared
    _make_fake_named_venv testenv
    _stub_run_cmd_records
    run env_command install testenv
    state_read testenv
    local first="$PYVE_TESTENV_STATE_INSTALLED_SHA256"
    printf 'pytest\nruff\n' > requirements-dev.txt
    run env_command install testenv
    state_read testenv
    [ "$PYVE_TESTENV_STATE_INSTALLED_SHA256" != "$first" ]
}

@test "realized-only: env init with no directives records installed_at=0" {
    _fixture_declared
    _stub_run_cmd_records
    # `bare` declares no setup directives → init realizes but installs
    # nothing; run_cmd stub means no real venv, so pre-create it.
    _make_fake_named_venv bare
    run env_command init bare
    [ "$status" -eq 0 ]
    if state_read bare; then
        [ "$PYVE_TESTENV_STATE_INSTALLED_AT" = "0" ]
    fi
}

@test "installed: conda install stamps installed_at with the manifest in the digest" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.hardware]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
TOML
    cat > environment.yml <<'YAML'
name: hardware
channels: [conda-forge]
dependencies: [python=3.12]
YAML
    mkdir -p ".pyve/envs/hardware/conda/conda-meta"
    read_env_config
    mkdir -p .pyve/bin
    printf '#!/usr/bin/env bash\nexit 0\n' > .pyve/bin/micromamba
    chmod +x .pyve/bin/micromamba

    run _env_install_with_lock hardware ".pyve/envs/hardware/conda" "" "wait"
    [ "$status" -eq 0 ]
    state_read hardware
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" != "0" ]
    [[ "$PYVE_TESTENV_STATE_INSTALLED_SHA256" =~ ^[0-9a-f]{64}$ ]]
}

# ============================================================
# `pyve env list` renders the recorded state
# ============================================================

@test "list: recorded-installed env shows ready; realized-only shows realized" {
    _fixture_declared
    _make_fake_named_venv testenv
    _make_fake_named_venv bare
    state_write testenv venv installed_at=1735689600 installed_sha256=abc
    state_write bare venv
    run env_command list
    [ "$status" -eq 0 ]
    local testenv_row bare_row
    testenv_row="$(printf '%s\n' "$output" | grep '^testenv ')"
    bare_row="$(printf '%s\n' "$output" | grep '^bare ')"
    [[ "$testenv_row" == *"ready"* ]]
    [[ "$bare_row" == *"realized"* ]]
}
