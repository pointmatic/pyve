#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# A conda-backed env supports a pip layer on top of its conda manifest:
# `pyve env install <name> -r <file>` must conda-sync the manifest AND then
# pip-install the requested requirements *into* the conda env (via
# `micromamba run -p <env> python -m pip install ...`). Before this, the
# micromamba install branch consumed only the manifest and silently dropped
# the `-r` file — making the standard "conda for heavy deps, pip for dev
# tooling" split unexpressible. A supplied source that can't be applied
# (missing file) errors loudly; it is never silently dropped.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# Stub micromamba in the project sandbox (get_micromamba_path priority 1).
# Logs every invocation's argv to mm.log so both the `install -f` (conda
# manifest sync) and the `run -p ... pip install` (pip layer) are observable.
_stub_micromamba_log() {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'SH'
#!/usr/bin/env bash
printf 'MM:%s\n' "$*" >> mm.log
exit 0
SH
    chmod +x .pyve/bin/micromamba
}

# A conda-backed `hardware` env declared in the v3 manifest + a materialized
# conda env (conda-meta) + the manifest file on disk.
_fixture_conda_env() {
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
}

# ============================================================
# CLI -r is applied as a pip layer on top of the conda sync
# ============================================================

@test "env install <conda> -r <file>: conda-syncs the manifest AND pip-installs -r into the env" {
    _fixture_conda_env
    _stub_micromamba_log
    printf 'ruff\n' > requirements-dev.txt

    run _env_install_with_lock hardware ".pyve/envs/hardware/conda" "requirements-dev.txt" "wait"
    [ "$status" -eq 0 ]
    # Conda manifest sync ran.
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    # pip layer ran inside the conda env via `micromamba run -p`.
    grep -q "^MM:run -p .pyve/envs/hardware/conda python -m pip install -r requirements-dev.txt" mm.log
}

@test "env install <conda> with no -r: conda-syncs only, no pip layer" {
    _fixture_conda_env
    _stub_micromamba_log

    run _env_install_with_lock hardware ".pyve/envs/hardware/conda" "" "wait"
    [ "$status" -eq 0 ]
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    ! grep -q "pip install" mm.log
}

@test "env install <conda> -r <missing-file>: errors loudly, never silent (no pip attempt)" {
    _fixture_conda_env
    _stub_micromamba_log

    run _env_install_with_lock hardware ".pyve/envs/hardware/conda" "does-not-exist.txt" "wait"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does-not-exist.txt"* ]]
    ! grep -q "pip install" mm.log
}

# ============================================================
# Direct _env_install_conda unit
# ============================================================

@test "_env_install_conda: pip layer runs AFTER the manifest sync" {
    _fixture_conda_env
    _stub_micromamba_log
    printf 'pytest\n' > reqs.txt

    run _env_install_conda hardware ".pyve/envs/hardware/conda" "environment.yml" "reqs.txt"
    [ "$status" -eq 0 ]
    # Order: install (sync) line precedes the pip run line.
    install_line=$(grep -n "^MM:install " mm.log | head -1 | cut -d: -f1)
    pip_line=$(grep -n "pip install" mm.log | head -1 | cut -d: -f1)
    [ -n "$install_line" ] && [ -n "$pip_line" ] && [ "$install_line" -lt "$pip_line" ]
}
