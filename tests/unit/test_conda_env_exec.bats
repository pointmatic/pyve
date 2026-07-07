#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve env run` and `pyve test` must operate a micromamba-backed env, not
# hard-error off it. A conda env needs CONDA_PREFIX + its activate.d scripts
# + conda's lib paths (compiled wheels depend on them) — PATH-prepend alone
# (correct for venv) does not set those up, so conda execs go through
# `micromamba run -p <env_path> <cmd>`, the canonical conda exec primitive.
# This replaces the earlier venv-only gate (`assert_env_venv_backend`) with a
# backend dispatch at both callsites: venv → PATH activation; micromamba →
# `micromamba run -p`.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/commands/env.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
    unset CI
    export PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT="0"
}

teardown() {
    cleanup_test_dir
}

# Stub micromamba in the project sandbox (get_micromamba_path priority 1):
# echoes its argv so the `run -p <path> <cmd>` invocation is observable, then
# exits 0. exec replaces the bats subprocess with this, so `run` captures it.
_stub_micromamba() {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'SH'
#!/usr/bin/env bash
printf 'MM:%s\n' "$*"
exit 0
SH
    chmod +x .pyve/bin/micromamba
}

# A materialized conda env is signalled by a conda-meta/ directory.
_fake_conda_env() {
    mkdir -p "$1/conda-meta" "$1/bin"
}

_v3_manifest() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"

[env.smoke]
purpose = "test"
requirements = ["requirements-dev.txt"]

[env.hardware]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
TOML
}

# ============================================================
# env_exec_conda primitive
# ============================================================

@test "env_exec_conda: execs 'micromamba run -p <path> <cmd> args'" {
    _stub_micromamba
    _fake_conda_env ".pyve/envs/hardware/conda"
    run env_exec_conda ".pyve/envs/hardware/conda" python -c "print(1)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MM:run -p .pyve/envs/hardware/conda python -c print(1)"* ]]
}

@test "env_exec_conda: no command → error, no micromamba invocation" {
    _stub_micromamba
    _fake_conda_env ".pyve/envs/hardware/conda"
    run env_exec_conda ".pyve/envs/hardware/conda"
    [ "$status" -ne 0 ]
    [[ "$output" != *"MM:"* ]]
}

@test "env_exec_conda: env not materialized (no conda-meta) → init hint" {
    _stub_micromamba
    mkdir -p .pyve/envs/hardware/conda
    run env_exec_conda ".pyve/envs/hardware/conda" python
    [ "$status" -ne 0 ]
    [[ "$output" == *"init"* ]]
}

@test "env_exec_conda: micromamba absent → actionable error" {
    _fake_conda_env ".pyve/envs/hardware/conda"
    get_micromamba_path() { echo ""; return 1; }
    run env_exec_conda ".pyve/envs/hardware/conda" python
    [ "$status" -ne 0 ]
    [[ "$output" == *"micromamba"* ]]
}

# ============================================================
# `pyve env run` dispatch
# ============================================================

@test "env run <conda-name> -- <cmd>: dispatches to conda exec, not venv env_run" {
    _v3_manifest
    _fake_conda_env ".pyve/envs/hardware/conda"
    env_run()        { printf 'VENV_RUN:%s\n' "$*"; }
    env_exec_conda() { printf 'CONDA_EXEC:%s\n' "$*"; }
    run env_command run hardware -- python -c "print(1)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONDA_EXEC:.pyve/envs/hardware/conda python -c print(1)"* ]]
    [[ "$output" != *"VENV_RUN:"* ]]
}

@test "env run <venv-name> -- <cmd>: still uses venv env_run (regression)" {
    _v3_manifest
    mkdir -p ".pyve/envs/smoke/venv/bin"
    printf '#!/bin/sh\n' > ".pyve/envs/smoke/venv/bin/python"
    chmod +x ".pyve/envs/smoke/venv/bin/python"
    env_run()        { printf 'VENV_RUN:%s\n' "$*"; }
    env_exec_conda() { printf 'CONDA_EXEC:%s\n' "$*"; }
    run env_command run smoke -- pytest -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"VENV_RUN:.pyve/envs/smoke/venv pytest -v"* ]]
    [[ "$output" != *"CONDA_EXEC:"* ]]
}

# ============================================================
# `pyve test --env <conda>` dispatch
# ============================================================

@test "pyve test --env <conda-name>: execs pytest via 'micromamba run -p'" {
    _v3_manifest
    _stub_micromamba
    _fake_conda_env ".pyve/envs/hardware/conda"
    # Skip the venv-centric provisioning/pytest-detection — the conda env is
    # declared with pytest; we only assert the exec dispatch.
    ensure_env_exists()    { :; }
    _test_has_pytest()     { return 0; }
    _test_env_has_pytest() { return 1; }

    run test_tests --env hardware -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"MM:run -p .pyve/envs/hardware/conda python -m pytest -q"* ]]
}
