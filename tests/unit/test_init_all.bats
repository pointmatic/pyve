#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve init --force --all` — batch lifecycle fan-out. After the root
# rebuild completes, every declared non-root env is rebuilt from its
# declaration with the same snapshot-then-replay semantics as a
# single `pyve env init <name> --force`: realized envs come back
# realized (installed dimension + last_used_at restored), a lazy
# never-realized env stays unrealized, an advisory backend skips with
# a note, and one env's failure never aborts the rest (worst-case
# exit code propagates). `--all` without `--force` is refused before
# any dispatch — fan-out is a rebuild semantic.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/init_composer.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

_stub_run_cmd_creates_venv() {
    run_cmd() {
        local venv_path="${4:-}"
        if [[ "$1" == "python" && "$2" == "-m" && "$3" == "venv" && -n "$venv_path" ]]; then
            mkdir -p "$venv_path/bin"
            printf '#!/usr/bin/env bash\nexit 0\n' > "$venv_path/bin/python"
            chmod +x "$venv_path/bin/python"
        else
            printf 'RUN_CMD:%s\n' "$*"
        fi
    }
}

_make_fake_named_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > ".pyve/envs/$name/venv/bin/python"
    chmod +x ".pyve/envs/$name/venv/bin/python"
}

# ============================================================
# Guard: --all is a rebuild semantic
# ============================================================

@test "compose_init: --all without --force is refused before any dispatch" {
    run compose_init --all
    [ "$status" -ne 0 ]
    [[ "$output" == *"--all requires --force"* ]]
}

# ============================================================
# Fan-out across the declaration
# ============================================================

_fixture_multi_env() {
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

[env.adv]
purpose = "utility"
backend = "none"
TOML
    printf 'pytest\n' > requirements-dev.txt
}

@test "fan-out: realized env rebuilds with a per-env banner; last_used_at restored" {
    _fixture_multi_env
    _make_fake_named_venv alpha
    state_write alpha venv last_used_at=12345 installed_at=99 installed_sha256=deadbeef
    _stub_run_cmd_creates_venv

    run _compose_init_force_all_envs
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    # The declared recipe re-materialized into the rebuilt env.
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
    # P.n replay: usage provenance survives, installed dimension re-stamped.
    state_read alpha
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "12345" ]
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" != "0" ]
}

@test "fan-out: lazy never-realized env is skipped and stays unrealized" {
    _fixture_multi_env
    _make_fake_named_venv alpha
    state_write alpha venv installed_at=99
    _stub_run_cmd_creates_venv

    run _compose_init_force_all_envs
    [ "$status" -eq 0 ]
    [[ "$output" == *"sleepy"* ]]   # named in the skip note
    [ ! -d ".pyve/envs/sleepy" ]
}

@test "fan-out: advisory backend skips with the standing note, rc stays 0" {
    _fixture_multi_env
    _make_fake_named_venv alpha
    state_write alpha venv installed_at=99
    _stub_run_cmd_creates_venv

    run _compose_init_force_all_envs
    [ "$status" -eq 0 ]
    [[ "$output" == *"adv"* ]]
    [[ "$output" == *"does not yet materialize"* ]]
    [ ! -d ".pyve/envs/adv" ]
}

@test "fan-out: one env's failure doesn't abort the rest; worst-case rc propagates" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"

[env.broken]
purpose = "test"
backend = "venv"
requirements = ["no-such-file.txt"]

[env.beta]
purpose = "test"
backend = "venv"
TOML
    _make_fake_named_venv broken
    _make_fake_named_venv beta
    state_write broken venv installed_at=99
    state_write beta venv installed_at=99
    _stub_run_cmd_creates_venv

    run _compose_init_force_all_envs
    [ "$status" -ne 0 ]
    # beta still got its turn after broken failed.
    [[ "$output" == *"beta"* ]]
    [ -d ".pyve/envs/beta/venv" ]
}
