#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# conda/micromamba materializer — compose the declared directive recipe.
#
# A conda-backed `[env.<name>]` block is a composable recipe: the conda
# `manifest` (environment.yml) layers first as the base, then the pip
# layer realizes every declared pip directive in the fixed order
# `editable` → `requirements` → `extra` (was the pick-one precedence
# dispatch: CLI -r > requirements > extra, with no `editable` at all).
# The whole recipe is validated up front so a bad directive fails
# before ANY layer installs — including the conda solve. CLI `-r`
# stays a full override of the pip layer only; the manifest remains
# the conda base and always syncs. `pyve env init <name>` materializes
# the declared pip directives after create ("init installs what you
# declared, nothing you didn't") — no declared pip directives means no
# pip layer and no redundant conda solve.

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

# Stub micromamba in the project sandbox (get_micromamba_path priority 1).
# Logs every invocation's argv to mm.log so the manifest sync
# (`install -f`) and each pip layer (`run -p ... pip install`) are
# observable, including their relative order.
_stub_micromamba_log() {
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'SH'
#!/usr/bin/env bash
printf 'MM:%s\n' "$*" >> mm.log
exit 0
SH
    chmod +x .pyve/bin/micromamba
}

# A conda-backed `hardware` env with the given extra directive lines
# appended to its `[env.hardware]` block, plus the manifest file and a
# materialized env (conda-meta) on disk.
_fixture_conda_env() {
    cat > pyve.toml <<TOML
pyve_schema = "3.0"

[project]
name = "demo"

[env.hardware]
purpose = "test"
backend = "micromamba"
manifest = "environment.yml"
$*
TOML
    cat > environment.yml <<'YAML'
name: hardware
channels: [conda-forge]
dependencies: [python=3.12]
YAML
    mkdir -p ".pyve/envs/hardware/conda/conda-meta"
    read_env_config
}

# Print the 1-based mm.log line number of the first line matching the
# given substring pattern.
_mm_line_of() {
    grep -n -- "$1" mm.log | head -1 | cut -d: -f1
}

# ============================================================
# Composition — pip layers materialize after the manifest sync,
# in the fixed order editable → requirements → extra
# ============================================================

@test "conda materializer: full recipe composes — manifest sync, then editable → requirements → extra" {
    _fixture_conda_env 'editable = ".[corruptions]"
requirements = ["requirements-dev.txt"]
extra = "lint"'
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
lint = ["ruff==0.6.0"]
TOML
    printf 'pytest\n' > requirements-dev.txt
    _stub_micromamba_log

    run env_command install hardware
    [ "$status" -eq 0 ]
    # All four layers ran...
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    grep -q "pip install -e .\[corruptions\]" mm.log
    grep -q "pip install -r requirements-dev.txt" mm.log
    grep -q "pip install ruff==0.6.0" mm.log
    # ...in the fixed order: sync < editable < requirements < extra.
    local sync_line ed_line req_line extra_line
    sync_line="$(_mm_line_of 'MM:install ')"
    ed_line="$(_mm_line_of 'pip install -e')"
    req_line="$(_mm_line_of 'pip install -r')"
    extra_line="$(_mm_line_of 'ruff==0.6.0')"
    [ "$sync_line" -lt "$ed_line" ]
    [ "$ed_line" -lt "$req_line" ]
    [ "$req_line" -lt "$extra_line" ]
}

@test "conda materializer: 'editable' alone layers onto the manifest sync" {
    _fixture_conda_env 'editable = ".[dev]"'
    _stub_micromamba_log

    run env_command install hardware
    [ "$status" -eq 0 ]
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    grep -q "run -p .pyve/envs/hardware/conda python -m pip install -e .\[dev\]" mm.log
}

# ============================================================
# Up-front validation — a bad pip directive fails BEFORE the
# conda solve runs
# ============================================================

@test "conda materializer: missing declared requirements file fails BEFORE the manifest sync" {
    _fixture_conda_env 'editable = "."
requirements = ["tests/missing.txt"]'
    _stub_micromamba_log

    run env_command install hardware
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests/missing.txt"* ]]
    # Nothing ran — not the conda solve, not a pip layer.
    [ ! -f mm.log ]
}

@test "conda materializer: unresolvable extra fails BEFORE the manifest sync" {
    _fixture_conda_env 'extra = "nope"'
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest"]
TOML
    _stub_micromamba_log

    run env_command install hardware
    [ "$status" -ne 0 ]
    [ ! -f mm.log ]
}

# ============================================================
# CLI -r override and single-directive back-compat
# ============================================================

@test "conda materializer: CLI '-r' overrides the pip recipe; the manifest still syncs" {
    _fixture_conda_env 'editable = ".[corruptions]"
requirements = ["should-not-be-used.txt"]'
    printf 'pytest\n' > requirements-cli.txt
    printf 'ignored\n' > should-not-be-used.txt
    _stub_micromamba_log

    run env_command install hardware -r requirements-cli.txt
    [ "$status" -eq 0 ]
    # The conda base still syncs; the pip layer installs ONLY the CLI file.
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    grep -q "pip install -r requirements-cli.txt" mm.log
    ! grep -q "pip install -e" mm.log
    ! grep -q "should-not-be-used.txt" mm.log
}

@test "conda materializer: extra-only block materializes exactly as before (sync, then the extra's packages)" {
    _fixture_conda_env 'extra = "lint"'
    cat > pyproject.toml <<'TOML'
[project]
name = "demo"
version = "0.1.0"

[project.optional-dependencies]
lint = ["ruff==0.6.0"]
TOML
    _stub_micromamba_log

    run env_command install hardware
    [ "$status" -eq 0 ]
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    grep -q "pip install ruff==0.6.0" mm.log
    ! grep -q "pip install -e" mm.log
    ! grep -q "pip install -r" mm.log
}

@test "conda materializer: requirements-only block materializes exactly as before (no -e)" {
    _fixture_conda_env 'requirements = ["tests/smoke-requirements.txt"]'
    mkdir -p tests
    printf 'ruff\n' > tests/smoke-requirements.txt
    _stub_micromamba_log

    run env_command install hardware
    [ "$status" -eq 0 ]
    grep -q "^MM:install -p .pyve/envs/hardware/conda -f environment.yml -y" mm.log
    grep -q "pip install -r tests/smoke-requirements.txt" mm.log
    ! grep -q "pip install -e" mm.log
}

# ============================================================
# One-shot init — `pyve env init <name>` materializes the declared
# pip directives on a conda env
# ============================================================

@test "one-shot conda init: declared pip directives materialize at 'env init <name>'" {
    _fixture_conda_env 'editable = ".[corruptions]"
requirements = ["requirements-dev.txt"]'
    printf 'pytest\n' > requirements-dev.txt
    # conda-meta pre-created by the fixture, so _env_init_conda skips
    # create and init proceeds straight to the recipe materialization.
    _stub_micromamba_log

    run env_command init hardware
    [ "$status" -eq 0 ]
    grep -q "pip install -e .\[corruptions\]" mm.log
    grep -q "pip install -r requirements-dev.txt" mm.log
}

@test "one-shot conda init: no declared pip directives → no pip layer, no redundant solve" {
    _fixture_conda_env ''
    _stub_micromamba_log

    run env_command init hardware
    [ "$status" -eq 0 ]
    # The env already exists (create skipped) and nothing is declared
    # beyond the manifest — init must not invoke micromamba at all.
    [ ! -f mm.log ]
}
