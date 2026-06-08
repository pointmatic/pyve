#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the v3 main-micromamba-env layout (Story N.bf.14).
#
# Invariant under test: the main micromamba env is the reserved `root`
# env and materializes at the uniform `.pyve/envs/root/conda/` slot with
# a sibling `.pyve/envs/root/.state` — NOT flat at the configured-name
# path `.pyve/envs/<configured>/` (the pre-N.bf.14 shape).
#
# Covers:
#   1. micromamba_root_prefix() returns the canonical slot.
#   2. resolve_env_path root: micromamba -> root/conda; venv -> .venv.
#   3. Opportunistic move of a legacy flat main env -> root/conda + .state.
#   4. Idempotence + non-interference with named micromamba testenvs.
#   5. create_micromamba_env materializes at root/conda + writes .state.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    create_test_dir
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# ============================================================
# micromamba_root_prefix — single source of the slot literal
# ============================================================

@test "micromamba_root_prefix: returns .pyve/envs/root/conda" {
    run micromamba_root_prefix
    [ "$status" -eq 0 ]
    [ "$output" = ".pyve/envs/root/conda" ]
}

# ============================================================
# resolve_env_path root — backend-aware
# ============================================================

@test "resolve_env_path root: micromamba backend -> .pyve/envs/root/conda" {
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: myproj"
    run resolve_env_path root
    [ "$status" -eq 0 ]
    [ "$output" = ".pyve/envs/root/conda" ]
}

@test "resolve_env_path root: venv backend -> .venv" {
    create_pyve_config "backend: venv"
    run resolve_env_path root
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

@test "resolve_env_path root: no config -> .venv (default)" {
    run resolve_env_path root
    [ "$status" -eq 0 ]
    [ "$output" = ".venv" ]
}

# ============================================================
# Opportunistic migration: flat main env -> root/conda
# ============================================================

# Simulate a pre-N.bf.14 flat main micromamba env: conda-meta sits
# DIRECTLY inside .pyve/envs/<configured>/ (named micromamba testenvs
# nest it one level deeper, under .../conda/conda-meta).
_make_flat_main_env() {
    local name="$1"
    mkdir -p ".pyve/envs/$name/conda-meta"
    : > ".pyve/envs/$name/conda-meta/history"
    mkdir -p ".pyve/envs/$name/bin"
    : > ".pyve/envs/$name/bin/python"
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: $name"
}

@test "migrate_legacy_env_layout: moves a flat main micromamba env to root/conda" {
    _make_flat_main_env myproj
    migrate_legacy_env_layout
    [ -d ".pyve/envs/root/conda/conda-meta" ]
    [ -f ".pyve/envs/root/conda/conda-meta/history" ]
    [ ! -d ".pyve/envs/myproj" ]
}

@test "migrate_legacy_env_layout: writes a root .state with backend=micromamba" {
    _make_flat_main_env myproj
    migrate_legacy_env_layout
    [ -f ".pyve/envs/root/.state" ]
    state_read root
    [ "$PYVE_TESTENV_STATE_BACKEND" = "micromamba" ]
    [[ "$PYVE_TESTENV_STATE_PROVISIONED_AT" =~ ^[0-9]+$ ]]
}

@test "resolve_env_path root: triggers the opportunistic move and returns root/conda" {
    _make_flat_main_env myproj
    # Command-substitution (how real callers consume it): stdout must be
    # the path only — migrator progress goes to stderr.
    local out
    out="$(resolve_env_path root)"
    [ "$out" = ".pyve/envs/root/conda" ]
    [ -d ".pyve/envs/root/conda/conda-meta" ]
    [ ! -d ".pyve/envs/myproj" ]
}

@test "migrate_legacy_env_layout: idempotent when root/conda already exists" {
    mkdir -p ".pyve/envs/root/conda/conda-meta"
    : > ".pyve/envs/root/conda/conda-meta/keep"
    # A stray flat dir must NOT clobber the existing v3 env.
    _make_flat_main_env myproj
    migrate_legacy_env_layout
    [ -f ".pyve/envs/root/conda/conda-meta/keep" ]
}

@test "migrate_legacy_env_layout: does NOT move a named micromamba testenv" {
    # Named micromamba testenv: conda-meta nested under conda/.
    mkdir -p ".pyve/envs/hardware/conda/conda-meta"
    : > ".pyve/envs/hardware/conda/conda-meta/history"
    # No flat main env, no micromamba root config.
    migrate_legacy_env_layout
    [ -d ".pyve/envs/hardware/conda/conda-meta" ]
    [ ! -d ".pyve/envs/root" ]
}

# ============================================================
# create_micromamba_env — materializes at root/conda + .state
# ============================================================

_stub_micromamba() {
    local bin="$TEST_DIR/fakebin"
    mkdir -p "$bin"
    cat > "$bin/micromamba" <<'SH'
#!/usr/bin/env bash
prefix=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) prefix="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$prefix" ]] && mkdir -p "$prefix/conda-meta" && mkdir -p "$prefix/bin"
exit 0
SH
    chmod +x "$bin/micromamba"
    get_micromamba_path() { printf '%s' "$TEST_DIR/fakebin/micromamba"; }
}

@test "create_micromamba_env: materializes the main env at root/conda" {
    _stub_micromamba
    cat > environment.yml <<'YML'
name: myproj
dependencies:
  - python=3.12
YML
    run create_micromamba_env myproj environment.yml
    [ "$status" -eq 0 ]
    [ -d ".pyve/envs/root/conda/conda-meta" ]
    [ ! -d ".pyve/envs/myproj" ]
}

@test "create_micromamba_env: writes a sibling .state at root" {
    _stub_micromamba
    cat > environment.yml <<'YML'
name: myproj
dependencies:
  - python=3.12
YML
    create_micromamba_env myproj environment.yml
    [ -f ".pyve/envs/root/.state" ]
    state_read root
    [ "$PYVE_TESTENV_STATE_BACKEND" = "micromamba" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST" = "environment.yml" ]
}
