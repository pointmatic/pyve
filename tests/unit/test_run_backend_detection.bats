#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.j.1 — pyve run backend detection regression after N.f
# state-dir relocation.
#
# After Story N.f moved testenv state and venv-backed testenvs under
# .pyve/envs/<name>/, the heuristic in lib/plugins/python/plugin.sh ("if
# .pyve/envs/* has any children, it's micromamba") falsely fires on
# pure-venv projects that happen to have a testenv. The fix consults
# `.pyve/config:backend` first (authoritative for v3.0), only falling
# back to the directory heuristic when no config is present.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/ui/core.sh"
    create_test_dir
    VERSION_MANAGER=""
    unset PYVE_NO_ASDF_COMPAT
}

teardown() {
    cleanup_test_dir
}

# Reuse the source_pyve_fn extractor from the J.c tests.
source_pyve_fn() {
    local fn="$1"
    local file="${2:-$PYVE_ROOT/pyve.sh}"
    local body
    body="$(awk -v fn="$fn" '
        $0 ~ "^" fn "\\(\\)[[:space:]]*\\{" { inside = 1 }
        inside { print }
        inside && /^\}$/ { exit }
    ' "$file")"
    eval "$body"
}

# Build a venv-backed project skeleton that matches the post-N.f shape:
# .venv/ for the main env, .pyve/envs/testenv/{.state,venv/} for the
# default testenv. Plants a fake `python` under .venv/bin so the venv
# exec path is observable via stdout.
setup_post_nf_venv_project() {
    DEFAULT_VENV_DIR=".venv"

    mkdir -p .venv/bin
    cat > .venv/bin/python << 'EOF'
#!/usr/bin/env bash
printf 'VENV-PYTHON %s\n' "$*"
EOF
    chmod +x .venv/bin/python

    mkdir -p .pyve .pyve/envs/testenv/venv/bin
    printf 'backend=venv\n' > .pyve/envs/testenv/.state
    cat > .pyve/config << 'EOF'
pyve_version: "3.0.0"
backend: venv
venv:
  directory: .venv
python:
  version: 3.14.4
EOF

    # Silence the asdf reshim probe so detect_version_manager and
    # source_shell_profiles do not poke at the host.
    source_shell_profiles() { :; }
    detect_version_manager() { :; }
}

# Build a micromamba-backed project skeleton. Plants a fake micromamba
# at .pyve/bin/micromamba so get_micromamba_path's priority-1 branch
# resolves it. The fake echoes its args, letting tests assert the
# correct -p path was selected (the v3.0 micromamba main env path is
# still .pyve/envs/<env_name>/ pre-N.g; the .pyve/envs/testenv/ sibling
# must not shadow it).
setup_post_nf_micromamba_project() {
    DEFAULT_VENV_DIR=".venv"

    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba << 'EOF'
#!/usr/bin/env bash
printf 'MM-RAN args=%s\n' "$*"
EOF
    chmod +x .pyve/bin/micromamba

    # zzz-env sorts AFTER testenv so the v2-era `env_dirs[0]` glob
    # picks testenv first — the assertion below verifies the fix
    # consults config.micromamba.env_name instead of relying on the
    # alphabetical accident.
    mkdir -p .pyve/envs/zzz-env/bin .pyve/envs/testenv/venv/bin
    printf 'backend=micromamba\n' > .pyve/envs/testenv/.state
    cat > .pyve/config << 'EOF'
pyve_version: "3.0.0"
backend: micromamba
micromamba:
  env_name: zzz-env
EOF

    source_shell_profiles() { :; }
    detect_version_manager() { :; }
}

# ────────────────────────────────────────────────────────────────────
# The regression — the failing CI test that motivated this story
# ────────────────────────────────────────────────────────────────────

@test "N.j.1: venv project with .pyve/envs/testenv/ uses venv (not micromamba)" {
    source_pyve_fn run_command "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    setup_post_nf_venv_project

    run run_command python --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"VENV-PYTHON --version"* ]]
}

@test "N.j.1: micromamba project picks main env from config, not the testenv sibling" {
    source_pyve_fn run_command "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    setup_post_nf_micromamba_project

    run run_command python --version
    [ "$status" -eq 0 ]
    # Must be .pyve/envs/zzz-env (from config.micromamba.env_name), NOT
    # .pyve/envs/testenv (the alphabetically-first glob entry).
    [[ "$output" == *"run -p .pyve/envs/zzz-env python --version"* ]]
}

@test "N.j.1: no env present → error, exit 1" {
    source_pyve_fn run_command "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    DEFAULT_VENV_DIR=".venv"
    source_shell_profiles() { :; }
    detect_version_manager() { :; }

    run run_command python --version
    [ "$status" -eq 1 ]
    [[ "$output" == *"No Python environment found"* ]]
}

@test "N.j.1: legacy project (no .pyve/config) with .venv/ falls back to venv" {
    source_pyve_fn run_command "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    DEFAULT_VENV_DIR=".venv"

    mkdir -p .venv/bin
    cat > .venv/bin/python << 'EOF'
#!/usr/bin/env bash
printf 'LEGACY-VENV-PYTHON\n'
EOF
    chmod +x .venv/bin/python

    source_shell_profiles() { :; }
    detect_version_manager() { :; }

    run run_command python --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"LEGACY-VENV-PYTHON"* ]]
}
