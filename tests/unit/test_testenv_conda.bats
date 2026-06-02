#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for Story M.k — conda-backed testenv plumbing.
#
# Surface under test:
#   _env_resolve_backend <name>     — venv | micromamba | "inherit"-resolved
#   _env_init_conda <name> <path> <manifest>     — `micromamba create -p ...`
#   _env_install_conda <name> <path> <manifest>  — `micromamba install -p ...`
#   testenv init  <conda-name>     — dispatcher routes to _env_init_conda
#   testenv install <conda-name>   — dispatcher routes to _env_install_conda
#   testenv install (no-arg)       — iteration installs conda envs too (no skip)

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

# Drop a fake micromamba binary at .pyve/bin/micromamba that records its
# argv to .pyve/micromamba.log (one line per invocation, args joined by
# space). Always exits 0 unless PYVE_TEST_MICROMAMBA_FAIL=1 is set.
_stub_micromamba_recorder() {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'SH'
#!/usr/bin/env bash
printf 'MICROMAMBA:%s\n' "$*" >> .pyve/micromamba.log
if [[ "${PYVE_TEST_MICROMAMBA_FAIL:-0}" == "1" ]]; then
    exit 1
fi
# Simulate a successful `create` by mkdir'ing the -p target.
target=""
take_next=0
for a in "$@"; do
    if [[ "$take_next" == "1" ]]; then
        target="$a"
        take_next=0
        continue
    fi
    [[ "$a" == "-p" ]] && take_next=1 || true
done
[[ -n "$target" ]] && mkdir -p "$target/conda-meta"
exit 0
SH
    chmod +x .pyve/bin/micromamba
}

_fixture_conda_env() {
    mkdir -p tests
    cat > tests/env.yml <<'YAML'
name: hardware
channels:
  - conda-forge
dependencies:
  - python=3.11
  - numpy
YAML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
TOML
}

_fixture_mixed_envs() {
    mkdir -p tests
    cat > tests/env.yml <<'YAML'
name: hardware
dependencies: [python]
YAML
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.testenv]
requirements = ["requirements-dev.txt"]

[tool.pyve.testenvs.hardware]
backend = "micromamba"
manifest = "tests/env.yml"
TOML
    # Story M.l: testenv's declared `requirements = [...]` is now consumed
    # at install time, so the file must exist on disk for iteration tests
    # that exercise the testenv install path.
    printf 'pytest\n' > requirements-dev.txt
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

_stub_run_cmd_records() {
    run_cmd() {
        printf 'RUN_CMD:%s\n' "$*"
    }
}

# ============================================================
# _env_resolve_backend
# ============================================================

@test "_env_resolve_backend: returns 'venv' for venv-backed declared env" {
    _fixture_mixed_envs
    read_env_config
    run _env_resolve_backend testenv
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "_env_resolve_backend: returns 'micromamba' for micromamba-backed env" {
    _fixture_mixed_envs
    read_env_config
    run _env_resolve_backend hardware
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "_env_resolve_backend: 'inherit' + main backend=venv resolves to venv" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
TOML
    mkdir -p .pyve
    printf 'backend: venv\n' > .pyve/config
    read_env_config
    run _env_resolve_backend mirror
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

@test "_env_resolve_backend: 'inherit' + main backend=micromamba resolves to micromamba" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
manifest = "environment.yml"
TOML
    mkdir -p .pyve
    printf 'backend: micromamba\n' > .pyve/config
    read_env_config
    run _env_resolve_backend mirror
    [ "$status" -eq 0 ]
    [ "$output" = "micromamba" ]
}

@test "_env_resolve_backend: 'inherit' with no .pyve/config defaults to venv" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
TOML
    read_env_config
    run _env_resolve_backend mirror
    [ "$status" -eq 0 ]
    [ "$output" = "venv" ]
}

# ============================================================
# resolve_env_path follows _env_resolve_backend (M.k)
# ============================================================

@test "resolve_env_path: 'inherit' + main=venv yields venv-shaped path" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
TOML
    mkdir -p .pyve
    printf 'backend: venv\n' > .pyve/config
    read_env_config
    run resolve_env_path mirror
    [ "$status" -eq 0 ]
    [ "$output" = ".pyve/envs/mirror/venv" ]
}

@test "resolve_env_path: 'inherit' + main=micromamba yields conda-shaped path" {
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.mirror]
backend = "inherit"
manifest = "environment.yml"
TOML
    mkdir -p .pyve
    printf 'backend: micromamba\n' > .pyve/config
    read_env_config
    run resolve_env_path mirror
    [ "$status" -eq 0 ]
    [ "$output" = ".pyve/envs/mirror/conda" ]
}

# ============================================================
# _env_init_conda
# ============================================================

@test "_env_init_conda: invokes 'micromamba create -p <path> -f <manifest> -y'" {
    _fixture_conda_env
    _stub_micromamba_recorder
    run _env_init_conda hardware ".pyve/envs/hardware/conda" "tests/env.yml"
    [ "$status" -eq 0 ]
    [ -f ".pyve/micromamba.log" ]
    grep -q "create -p .pyve/envs/hardware/conda -f tests/env.yml -y" .pyve/micromamba.log
    # The stub mkdir's the conda-meta dir on success.
    [ -d ".pyve/envs/hardware/conda/conda-meta" ]
}

@test "_env_init_conda: missing manifest file hard-errors" {
    _fixture_conda_env
    _stub_micromamba_recorder
    rm tests/env.yml
    run _env_init_conda hardware ".pyve/envs/hardware/conda" "tests/env.yml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/env.yml"* ]]
    [ ! -f ".pyve/micromamba.log" ]
}

@test "_env_init_conda: empty manifest argument hard-errors" {
    _fixture_conda_env
    _stub_micromamba_recorder
    run _env_init_conda hardware ".pyve/envs/hardware/conda" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
    [ ! -f ".pyve/micromamba.log" ]
}

# ============================================================
# _env_install_conda
# ============================================================

@test "_env_install_conda: invokes 'micromamba install -p <path> -f <manifest> -y' on existing env" {
    _fixture_conda_env
    _stub_micromamba_recorder
    # Pre-create the env so install proceeds past the existence check.
    mkdir -p .pyve/envs/hardware/conda/conda-meta
    run _env_install_conda hardware ".pyve/envs/hardware/conda" "tests/env.yml"
    [ "$status" -eq 0 ]
    grep -q "install -p .pyve/envs/hardware/conda -f tests/env.yml -y" .pyve/micromamba.log
}

@test "_env_install_conda: env not yet initialized hard-errors with 'init' hint" {
    _fixture_conda_env
    _stub_micromamba_recorder
    run _env_install_conda hardware ".pyve/envs/hardware/conda" "tests/env.yml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"init"* ]]
    [ ! -f ".pyve/micromamba.log" ]
}

# ============================================================
# Dispatcher: testenv init <conda-name>
# ============================================================

@test "testenv init <conda-name>: routes to _env_init_conda (no python -m venv)" {
    _fixture_conda_env
    _stub_micromamba_recorder
    _stub_run_cmd_records
    run env_command init hardware
    [ "$status" -eq 0 ]
    grep -q "create -p .pyve/envs/hardware/conda" .pyve/micromamba.log
    # python -m venv must NOT have run (no venv-shaped sibling).
    [ ! -d ".pyve/envs/hardware/venv" ]
}

@test "testenv init <conda-name>: missing manifest declaration in pyproject hard-errors" {
    # Declare the env with no manifest.
    cat > pyproject.toml <<'TOML'
[tool.pyve.testenvs.hardware]
backend = "micromamba"
TOML
    _stub_micromamba_recorder
    run env_command init hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest"* ]]
    [ ! -f ".pyve/micromamba.log" ]
}

# ============================================================
# Dispatcher: testenv install <conda-name>
# ============================================================

@test "testenv install <conda-name>: routes to _env_install_conda" {
    _fixture_conda_env
    _stub_micromamba_recorder
    mkdir -p .pyve/envs/hardware/conda/conda-meta
    run env_command install hardware
    [ "$status" -eq 0 ]
    grep -q "install -p .pyve/envs/hardware/conda -f tests/env.yml -y" .pyve/micromamba.log
    # Lock dir cleaned up.
    [ ! -d ".pyve/envs/hardware/.lock" ]
}

# ============================================================
# Iteration (no-arg install) includes conda envs
# ============================================================

@test "testenv install (no-arg): iteration includes conda envs (no 'see Story M.k' skip)" {
    _fixture_mixed_envs
    _make_fake_named_venv testenv
    mkdir -p .pyve/envs/hardware/conda/conda-meta
    _stub_micromamba_recorder
    _stub_run_cmd_records
    run env_command install
    [ "$status" -eq 0 ]
    # venv env installed via pip.
    [[ "$output" == *"envs/testenv/venv/bin/python"* ]]
    # conda env installed via micromamba.
    grep -q "install -p .pyve/envs/hardware/conda" .pyve/micromamba.log
    # Old M.k skip message must NOT appear anymore.
    [[ "$output" != *"see Story M.k"* ]]
}
