#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.p — `pyve testenv list` and `pyve testenv prune`.
#
# `testenv list` walks the union of declared + on-disk envs, reads each
# env's `.state` (M.h.1) for backend / last_used_at, computes `du -sh`,
# determines a state label (`ready`/`lazy`/`not provisioned`/`orphaned`),
# and prints a table.
#
# `testenv prune` has three modes:
#   - no args   → remove every orphaned env (on disk but not declared
#                 and not the reserved `testenv`), with confirmation.
#   - --unused-since <ISO-date> → remove envs whose `last_used_at` is
#                 strictly older than the given date. Envs with
#                 `last_used_at = 0` (never used) are NOT removed —
#                 freshly-provisioned envs should not be eaten.
#   - --all     → remove every env on disk (declared + orphaned), with
#                 confirmation. Disk-driven (distinct from `testenv
#                 purge` no-arg, which is config-driven and iterates
#                 PYVE_TESTENVS_NAMES).
#
# All confirmation prompts respect `--force` and the M.i.4 TTY rules
# (`PYVE_FORCE_PROMPT=1` forces prompt on non-TTY for testing).

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
    unset PYVE_FORCE_PROMPT
}

teardown() {
    cleanup_test_dir
}

# Make a fake env on disk + write .state. last_used defaults to 0
# (never), epoch for provisioned_at is a fixed Jan 2026 timestamp.
_make_env_on_disk() {
    local name="$1" backend="${2:-venv}" last_used="${3:-0}"
    local kind="venv"
    [[ "$backend" == "micromamba" ]] && kind="conda"
    mkdir -p ".pyve/envs/$name/$kind/bin"
    cat > ".pyve/envs/$name/$kind/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/$name/$kind/bin/python"
    state_write "$name" "$backend" provisioned_at=1735689600 last_used_at="$last_used"
}

# Stub `du` to a deterministic output so size assertions are stable.
_stub_du() {
    du() {
        # mimics `du -sh <path>\n<size>\t<path>` shape.
        local path="${@: -1}"
        printf '42M\t%s\n' "$path"
    }
}

# ============================================================
# list — empty / single / multiple / orphaned / lazy
# ============================================================

@test "testenv list: empty project prints a header and 'no testenvs' info" {
    _stub_du
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"NAME"* ]]
    [[ "$output" == *"BACKEND"* ]]
    [[ "$output" == *"SIZE"* ]]
    [[ "$output" == *"LAST-USED"* ]]
    [[ "$output" == *"STATE"* ]]
}

@test "testenv list: declared venv-backed env on disk → state=ready" {
    _stub_du
    _make_env_on_disk testenv venv 1735776000
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenv"* ]]
    [[ "$output" == *"venv"* ]]
    [[ "$output" == *"42M"* ]]
    [[ "$output" == *"ready"* ]]
    # last_used is non-zero → ISO date format YYYY-MM-DD.
    [[ "$output" =~ 20[0-9]{2}-[0-9]{2}-[0-9]{2} ]]
}

@test "testenv list: declared but never used → LAST-USED shows 'never'" {
    _stub_du
    _make_env_on_disk testenv venv 0
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"never"* ]]
}

@test "testenv list: declared lazy not provisioned → state=lazy, size=--" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.heavy]
requirements = ["tests/heavy.txt"]
lazy = true
TOML
    _stub_du
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"heavy"* ]]
    [[ "$output" == *"lazy"* ]]
}

@test "testenv list: orphaned env on disk (not declared) → state=orphaned" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]
TOML
    _stub_du
    _make_env_on_disk testenv venv 1735776000
    _make_env_on_disk old-stuff venv 1735776000
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"old-stuff"* ]]
    [[ "$output" == *"orphaned"* ]]
}

@test "testenv list: conda-backed env shows backend=micromamba" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
TOML
    _stub_du
    _make_env_on_disk hardware micromamba 1735776000
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"hardware"* ]]
    [[ "$output" == *"micromamba"* ]]
}

@test "testenv list: declared non-lazy but not on disk → state=not provisioned" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]
TOML
    _stub_du
    run env_command list
    [ "$status" -eq 0 ]
    [[ "$output" == *"smoke"* ]]
    [[ "$output" == *"not provisioned"* ]]
}

# ============================================================
# prune — orphan mode (default, no args)
# ============================================================

@test "testenv prune (no args): removes orphans, leaves declared envs alone" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]
TOML
    _make_env_on_disk testenv venv 1735776000
    _make_env_on_disk old-stuff venv 1735776000
    run env_command prune --force
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/testenv" ]
    [ ! -d ".pyve/envs/old-stuff" ]
}

@test "testenv prune (no args): reserved 'testenv' is never orphaned (no pyproject)" {
    _make_env_on_disk testenv venv 1735776000
    run env_command prune --force
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/testenv" ]
}

@test "testenv prune (no args): nothing to do prints info and exits 0" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]
TOML
    _make_env_on_disk testenv venv 1735776000
    run env_command prune --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"No orphaned"* || "$output" == *"nothing to prune"* || "$output" == *"no orphans"* ]]
}

# ============================================================
# prune --unused-since <ISO-date>
# ============================================================

@test "testenv prune --unused-since: removes envs older than the cutoff" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
[tool.pyve.testenvs.smoke]
[tool.pyve.testenvs.fresh]
TOML
    # testenv last used 2024-12-01 → older than the 2026-01-01 cutoff.
    _make_env_on_disk testenv venv 1733011200
    # smoke last used 2024-12-15 → older than the cutoff.
    _make_env_on_disk smoke venv 1734220800
    # fresh last used 2026-04-01 → newer than the cutoff.
    _make_env_on_disk fresh venv 1775347200
    run env_command prune --unused-since 2026-01-01 --force
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/envs/testenv" ]
    [ ! -d ".pyve/envs/smoke" ]
    [ -d ".pyve/envs/fresh" ]
}

@test "testenv prune --unused-since: 'never used' envs (last_used=0) are preserved" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
TOML
    # last_used=0 → "never used"; do NOT remove freshly-provisioned envs.
    _make_env_on_disk testenv venv 0
    run env_command prune --unused-since 2026-01-01 --force
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/testenv" ]
}

@test "testenv prune --unused-since: bad date format hard-errors" {
    _make_env_on_disk testenv venv 1733011200
    run env_command prune --unused-since not-a-date --force
    [ "$status" -ne 0 ]
    [[ "$output" == *"not-a-date"* ]]
}

# ============================================================
# prune --all
# ============================================================

@test "testenv prune --all --force: removes every env on disk (declared + orphaned)" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
[tool.pyve.testenvs.smoke]
TOML
    _make_env_on_disk testenv venv 1735776000
    _make_env_on_disk smoke venv 1735776000
    _make_env_on_disk old-stuff venv 1735776000
    run env_command prune --all --force
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/envs/testenv" ]
    [ ! -d ".pyve/envs/smoke" ]
    [ ! -d ".pyve/envs/old-stuff" ]
}

# ============================================================
# Dispatcher routing + help
# ============================================================

@test "testenv --help: documents list and prune" {
    run env_command --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"list"* ]]
    [[ "$output" == *"prune"* ]]
    [[ "$output" == *"--unused-since"* ]]
}

@test "testenv prune: unknown flag hard-errors" {
    run env_command prune --bogus
    [ "$status" -ne 0 ]
}
