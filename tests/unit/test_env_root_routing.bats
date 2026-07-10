#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Uniform per-env repair routing — no dead-ends on the reserved `root`.
#
# `root` is the main project environment: the `pyve env` namespace
# manages named envs only, and root's lifecycle belongs to the
# top-level verbs. Rejecting `pyve env <verb> root` is correct, but an
# unexplained rejection is a field dead-end — every rejection must
# signpost the verb that DOES do the job: init → `pyve init` (rebuild:
# `pyve init --force`), purge → `pyve purge`, install → `pyve init`,
# run → `pyve run <command>`. `pyve check`'s default-testenv line
# routes by fault kind: a structurally broken env (no runnable python
# — runnability probe, not existence) needs the rebuild verb
# `pyve env init testenv --force`, not `pyve test`.

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

_fixture_project() {
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
    read_env_config
}

# ============================================================
# Per-verb signposts on `pyve env <verb> root`
# ============================================================

@test "env init root: rejection signposts 'pyve init' and the --force rebuild" {
    _fixture_project
    run env_command init root
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" == *"pyve init --force"* ]]
    [[ "$output" != *"pyve env init"* ]]
    [ ! -d ".pyve/envs/root" ]
}

@test "env purge root: rejection signposts 'pyve purge' (a purge, not a rebuild)" {
    _fixture_project
    run env_command purge root
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve purge"* ]]
    [[ "$output" != *"pyve init --force"* ]]
}

@test "env install root: rejection signposts 'pyve init'" {
    _fixture_project
    run env_command install root
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve init"* ]]
}

@test "env run root -- <cmd>: rejection signposts 'pyve run'" {
    _fixture_project
    run env_command run root -- echo hi
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve run"* ]]
}

# ============================================================
# The gate itself — base line pin + no-verb routing map
# ============================================================

@test "assert_env_name_actionable root: base line keeps the selection-only pin" {
    _fixture_project
    run assert_env_name_actionable root
    [ "$status" -ne 0 ]
    [[ "$output" == *"selection-only"* ]]
    [[ "$output" == *"pyve test --env root"* ]]
}

@test "assert_env_name_actionable root (no verb): emits the full routing map" {
    _fixture_project
    run assert_env_name_actionable root
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" == *"pyve purge"* ]]
    [[ "$output" == *"pyve run"* ]]
}

# ============================================================
# `pyve check` default-testenv line routes by fault kind
# ============================================================

# Capture the _check_* closure calls the helper makes.
_stub_check_closures() {
    _check_pass() { printf 'PASS:%s\n' "$*"; }
    _check_warn() { printf 'WARN:%s\n' "$*"; }
    _check_fail() { printf 'FAIL:%s\n' "$*"; }
}

@test "check testenv line: structurally broken env routes to 'pyve env init testenv --force'" {
    _fixture_project
    # Present on disk but gutted: directory exists, no runnable python.
    mkdir -p ".pyve/envs/testenv/venv/bin"
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"pyve env init testenv --force"* ]]
    [[ "$output" != *"pyve test"* ]]
}

@test "check testenv line: runnable python without pytest keeps routing to 'pyve test'" {
    _fixture_project
    mkdir -p ".pyve/envs/testenv/venv/bin"
    # python runs, but any -c import fails (pytest missing).
    cat > ".pyve/envs/testenv/venv/bin/python" <<'SH'
#!/usr/bin/env bash
[[ "$1" == "--version" ]] && { echo "Python 3.12.0"; exit 0; }
exit 1
SH
    chmod +x ".pyve/envs/testenv/venv/bin/python"
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"pyve test"* ]]
    [[ "$output" != *"--force"* ]]
}

@test "check testenv line: healthy env passes" {
    _fixture_project
    mkdir -p ".pyve/envs/testenv/venv/bin"
    cat > ".pyve/envs/testenv/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/testenv/venv/bin/python"
    # pytest presence is now probed via the console-script WRAPPER (the
    # canary model) — a healthy env with pytest carries the wrapper.
    cat > ".pyve/envs/testenv/venv/bin/pytest" <<'SH'
#!/usr/bin/env bash
echo "pytest 8.0.0"
SH
    chmod +x ".pyve/envs/testenv/venv/bin/pytest"
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"PASS:"* ]]
    [[ "$output" != *"WARN:"* ]]
}

@test "check testenv line: absent env stays silent (conditional check)" {
    _fixture_project
    _stub_check_closures
    run _check_default_testenv
    [ -z "$output" ]
}

# ============================================================
# Discoverability — the help carries the routing map
# ============================================================

@test "env --help: reserved-names note carries the root routing map" {
    run env_command --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve purge"* ]]
    [[ "$output" == *"pyve run"* ]]
}
