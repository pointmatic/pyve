#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.q — `pyve lock --env <name>` / `--all`.
#
# Today's `pyve lock` (Story G/L era) locks the project's main env's
# `environment.yml` → `conda-lock.yml`. M.q extends `lock_environment`:
#
#   pyve lock                  → main env (existing behavior preserved)
#   pyve lock --env <name>     → lock the named conda-backed testenv
#                                 (uses [tool.pyve.testenvs.<name>].manifest;
#                                  output: <manifest-basename>-lock.yml
#                                  sibling to the manifest)
#   pyve lock --all            → main env + every conda-backed testenv,
#                                 in PYVE_TESTENVS_NAMES order
#
# Hard errors:
#   - --env <venv-backed-name>: precise message naming the backend.
#   - --env <undeclared-name>: name not in [tool.pyve.testenvs].
#   - --env <conda-name> with no `manifest` declared: hint at the
#     pyproject.toml schema.
#   - --env root: reject; tell the user to run `pyve lock` (no args).

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/lock.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"

    # `unknown_flag_error` lives in pyve.sh (not in any lib/), so when
    # tests source lib/commands/lock.sh in isolation and hit the `-*`
    # arm, the call would fall through to "command not found" and the
    # parser would loop forever. Stub it to a clean log_error + exit 1.
    unknown_flag_error() {
        printf "Error: 'pyve %s' does not accept '%s'\n" "$1" "$2" >&2
        exit 1
    }
}

teardown() {
    cleanup_test_dir
}

# Drop a fake `conda-lock` binary on PATH. Records argv to a file
# and writes a marker output file at the `--lockfile <path>` arg
# (when present) or at `./conda-lock.yml` (default).
_stub_conda_lock() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/conda-lock" <<'SH'
#!/usr/bin/env bash
printf 'CONDA_LOCK:%s\n' "$*" >> conda-lock.log

# Find --lockfile <path>; default to ./conda-lock.yml.
lockfile="conda-lock.yml"
take_next=0
for a in "$@"; do
    if [[ "$take_next" == "1" ]]; then
        lockfile="$a"
        take_next=0
        continue
    fi
    [[ "$a" == "--lockfile" ]] && take_next=1 || true
done

mkdir -p "$(dirname "$lockfile")"
printf 'locked: yes\n' > "$lockfile"
SH
    chmod +x "$TEST_DIR/bin/conda-lock"
    export PATH="$TEST_DIR/bin:$PATH"
}

# Project shape: main env (micromamba), one venv testenv, one conda testenv.
_fixture_mixed_lock() {
    cat > environment.yml <<'YAML'
name: main
channels: [conda-forge]
dependencies: [python=3.11]
YAML

    mkdir -p .pyve
    printf 'backend: micromamba\n' > .pyve/config

    mkdir -p tests
    cat > tests/env.yml <<'YAML'
name: hardware
channels: [conda-forge]
dependencies: [python=3.11, numpy]
YAML

    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.smoke]
requirements = ["tests/smoke-requirements.txt"]

[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
TOML
}

# ============================================================
# --env <conda-name>: happy path
# ============================================================

@test "pyve lock --env <conda-name>: invokes conda-lock with the env's manifest and a sibling --lockfile" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --env hardware
    [ "$status" -eq 0 ]
    [ -f "tests/env-lock.yml" ]
    grep -q "^CONDA_LOCK:" conda-lock.log
    grep -q -- "-f tests/env.yml" conda-lock.log
    grep -q -- "--lockfile tests/env-lock.yml" conda-lock.log
    # Main env's conda-lock.yml NOT created as a side effect.
    [ ! -f "conda-lock.yml" ]
}

@test "pyve lock --env=<conda-name>: '=' form also works" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --env=hardware
    [ "$status" -eq 0 ]
    [ -f "tests/env-lock.yml" ]
}

# ============================================================
# Validation
# ============================================================

@test "pyve lock --env <venv-name>: hard-errors with backend hint" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --env smoke
    [ "$status" -ne 0 ]
    [[ "$output" == *"smoke"* ]]
    [[ "$output" == *"venv"* || "$output" == *"conda-backed"* ]]
    # No conda-lock invocation.
    [ ! -f "conda-lock.log" ]
}

@test "pyve lock --env <undeclared>: hard-errors pointing at [tool.pyve.testenvs]" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --env bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus"* ]]
    [[ "$output" == *"declared"* || "$output" == *"tool.pyve.testenvs"* ]]
}

@test "pyve lock --env root: hard-errors with 'pyve lock' guidance" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --env root
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"pyve lock"* ]]
}

@test "pyve lock --env <conda-name with no manifest>: hard-errors pointing at the schema" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.hardware]
backend = "micromamba"
TOML
    mkdir -p .pyve
    printf 'backend: micromamba\n' > .pyve/config
    _stub_conda_lock
    run lock_environment --env hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
}

@test "pyve lock --env <conda-name with missing manifest file>: hard-errors" {
    _fixture_mixed_lock
    rm tests/env.yml
    _stub_conda_lock
    run lock_environment --env hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/env.yml"* ]]
}

# ============================================================
# --all
# ============================================================

@test "pyve lock --all: locks the main env AND every conda-backed testenv" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --all
    [ "$status" -eq 0 ]
    # Main env's conda-lock.yml exists.
    [ -f "conda-lock.yml" ]
    # Conda testenv's sibling lock exists.
    [ -f "tests/env-lock.yml" ]
    # Two conda-lock invocations.
    [ "$(grep -c '^CONDA_LOCK:' conda-lock.log)" -eq 2 ]
}

@test "pyve lock --all: skips venv-backed testenvs without erroring" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment --all
    [ "$status" -eq 0 ]
    # Only conda backends are locked. No file for smoke.
    [ ! -f "tests/smoke-lock.yml" ]
}

# ============================================================
# Today's behavior preserved
# ============================================================

@test "pyve lock (no args): still locks the main env (existing behavior)" {
    _fixture_mixed_lock
    _stub_conda_lock
    run lock_environment
    [ "$status" -eq 0 ]
    [ -f "conda-lock.yml" ]
    # Conda testenv's sibling was NOT touched.
    [ ! -f "tests/env-lock.yml" ]
}

@test "pyve lock --check: still works (today's behavior)" {
    _fixture_mixed_lock
    touch -t 202401010000 environment.yml
    touch -t 202401010001 conda-lock.yml
    run lock_environment --check
    [ "$status" -eq 0 ]
}

# ============================================================
# Help text
# ============================================================

@test "pyve lock: unknown flag still hard-errors" {
    _fixture_mixed_lock
    run lock_environment --bogus
    [ "$status" -ne 0 ]
}

# ============================================================
# N.bf.7: conda-lock-missing advice points at a command that works
# ============================================================
#
# Bare `pyve init --force` then hard-errors "No conda-lock.yml found"
# (the N.bf.8 wall). Bootstrapping the locker means no lock can exist yet,
# so the advice must name `pyve init --force --no-lock`. conda-lock is
# absent from the base PATH (it lives inside micromamba envs), so the
# guard fires naturally without stubbing.

@test "pyve lock (main env): conda-lock-missing advice names 'pyve init --force --no-lock'" {
    _fixture_mixed_lock
    run lock_environment
    [ "$status" -ne 0 ]
    [[ "$output" == *"conda-lock is not available"* ]]
    [[ "$output" == *"pyve init --force --no-lock"* ]]
}

@test "pyve lock --env <conda-name>: conda-lock-missing advice names 'pyve init --force --no-lock'" {
    _fixture_mixed_lock
    run lock_environment --env hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"conda-lock is not available"* ]]
    [[ "$output" == *"pyve init --force --no-lock"* ]]
}
