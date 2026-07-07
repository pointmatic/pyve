#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# One-shot `--force` rebuild: `pyve env init <name> --force` purges the
# env and rebuilds it from its declaration in one command (`--force` =
# escalate to destructive, per the one-meaning-each flag rule; `--yes`
# assents to the confirmation prompt). The destructive step is gated
# like the other destructive verbs: prompt on interactive stdin unless
# --yes; CI/non-TTY skips; PYVE_FORCE_PROMPT=1 forces the prompt.
# `--force` on an absent env degrades to plain init (nothing to purge,
# so nothing to confirm). `pyve init --force` is the ROOT env's rebuild
# and says so — named envs are untouched, and both help surfaces point
# a named-env rebuild at `pyve env init <name> --force`.

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

# Stub run_cmd to record every invocation AND simulate
# `python -m venv <path>` (create a fake interpreter) so the rebuild's
# create + install layers are observable without real python.
_stub_run_cmd_records_and_creates() {
    run_cmd() {
        printf 'RUN_CMD:%s\n' "$*"
        if [[ "$1" == "python" && "$2" == "-m" && "$3" == "venv" ]]; then
            mkdir -p "$4/bin"
            cat > "$4/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
            chmod +x "$4/bin/python"
        fi
    }
}

# A declared venv env (`smoke`, no setup directives) plus a declared
# recipe-bearing env (`testenv`).
_fixture_declared_envs() {
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

[env.smoke]
purpose = "test"
backend = "venv"
TOML
    printf 'pytest\n' > requirements-dev.txt
    read_env_config
}

# Materialize a fake on-disk env with a marker file so "was it purged?"
# is directly observable.
_make_marked_venv() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/venv/bin"
    cat > ".pyve/envs/$name/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/$name/venv/bin/python"
    touch ".pyve/envs/$name/venv/marker"
}

# ============================================================
# The one-shot rebuild
# ============================================================

@test "env init <name> --force: purges the existing env and rebuilds it" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates

    run env_command init smoke --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed .pyve/envs/smoke"* ]]
    # Old contents gone, fresh env in place.
    [ ! -f ".pyve/envs/smoke/venv/marker" ]
    [ -x ".pyve/envs/smoke/venv/bin/python" ]
}

@test "env init <name> --force: re-materializes the declared recipe in the same shot" {
    _fixture_declared_envs
    _make_marked_venv testenv
    _stub_run_cmd_records_and_creates

    run env_command init testenv --force
    [ "$status" -eq 0 ]
    [ ! -f ".pyve/envs/testenv/venv/marker" ]
    # The rebuild is declaration-driven: create, then the recipe layer.
    [[ "$output" == *"RUN_CMD:python -m venv"* ]]
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
}

# ============================================================
# Confirmation gate — --force escalates, --yes assents
# ============================================================

@test "env init <name> --force: prompt declined ('n') aborts and preserves the env" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates
    export PYVE_FORCE_PROMPT=1

    run env_command init smoke --force <<< "n"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]
    [ -f ".pyve/envs/smoke/venv/marker" ]
}

@test "env init <name> --force --yes: skips the prompt and rebuilds" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates
    export PYVE_FORCE_PROMPT=1

    run env_command init smoke --force --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"[y/N]"* ]]
    [ ! -f ".pyve/envs/smoke/venv/marker" ]
    [ -x ".pyve/envs/smoke/venv/bin/python" ]
}

@test "env init <name> --force: non-TTY (CI) proceeds without a prompt" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates

    run env_command init smoke --force
    [ "$status" -eq 0 ]
    [[ "$output" != *"[y/N]"* ]]
    [ ! -f ".pyve/envs/smoke/venv/marker" ]
}

# ============================================================
# Degenerate and regression cases
# ============================================================

@test "env init <name> --force on an absent env: plain init, no purge, no prompt" {
    _fixture_declared_envs
    _stub_run_cmd_records_and_creates
    export PYVE_FORCE_PROMPT=1

    run env_command init smoke --force
    [ "$status" -eq 0 ]
    [[ "$output" != *"Removed"* ]]
    [[ "$output" != *"[y/N]"* ]]
    [ -x ".pyve/envs/smoke/venv/bin/python" ]
}

@test "env init <name> without --force: existing env is never purged" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates

    run env_command init smoke
    [ "$status" -eq 0 ]
    [ -f ".pyve/envs/smoke/venv/marker" ]
}

# ============================================================
# Help surfaces — the explicit root-only contract
# ============================================================

@test "env --help: documents init [--force] [--yes] and the root-only routing" {
    run env_command --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"env init [<name>] [--force] [--yes]"* ]]
    [[ "$output" == *"pyve env init <name> --force"* ]]
}

@test "show_init_help: --force states root-only scope and points at the per-env rebuild" {
    run show_init_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"root environment"* ]]
    [[ "$output" == *"pyve env init <name> --force"* ]]
}

# ============================================================
# Rebuild restores state (snapshot-then-replay); purge resets it
# ============================================================

@test "force replay: declared-recipe env comes back installed, last_used_at preserved" {
    _fixture_declared_envs
    _make_marked_venv testenv
    _stub_run_cmd_records_and_creates
    state_write testenv venv installed_at=11111 installed_sha256=oldhash last_used_at=22222
    run env_command init testenv --force --yes
    [ "$status" -eq 0 ]
    # The declared recipe re-installed (fresh stamp), usage provenance restored.
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
    state_read testenv
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" != "0" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "22222" ]
}

@test "force replay: fallback-installed env (no directives) re-installs to restore the installed dimension" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates
    state_write smoke venv installed_at=11111 last_used_at=333
    run env_command init smoke --force --yes
    [ "$status" -eq 0 ]
    # smoke declares no directives — the recipe step is a no-op, so the
    # replay must re-run the install path (fallback chain) itself.
    [[ "$output" == *"pip install -r requirements-dev.txt"* ]]
    state_read smoke
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" != "0" ]
    [ "$PYVE_TESTENV_STATE_LAST_USED_AT" = "333" ]
}

@test "force replay: realized-only env stays realized-only (no install replay)" {
    _fixture_declared_envs
    _make_marked_venv smoke
    _stub_run_cmd_records_and_creates
    state_write smoke venv
    run env_command init smoke --force --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"pip install"* ]]
    state_read smoke
    [ "$PYVE_TESTENV_STATE_INSTALLED_AT" = "0" ]
}

@test "purge is the only true destroy: env purge removes .state with the env" {
    _fixture_declared_envs
    _make_marked_venv smoke
    state_write smoke venv installed_at=1
    [ -f ".pyve/envs/smoke/.state" ]
    run env_command purge smoke
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/envs/smoke" ]
}
