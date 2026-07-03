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
    export PYVE_TEST_AUTOSCAFFOLD_TOML=1
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
    # resolve_env_path reads the root backend from the manifest; a v2 project
    # resolves via the read-compat synthesis, loaded here as production does.
    manifest_load >/dev/null 2>&1 || true
    run resolve_env_path root
    [ "$status" -eq 0 ]
    [ "$output" = ".pyve/envs/root/conda" ]
}

@test "resolve_env_path root: venv backend -> .venv" {
    create_pyve_config "backend: venv"
    manifest_load >/dev/null 2>&1 || true
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
    # resolve_env_path reads the root backend from the manifest; a v2 project
    # resolves via the read-compat synthesis, loaded here as production does.
    manifest_load >/dev/null 2>&1 || true
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
# Relocation repairs the baked absolute prefix (conda envs are not
# relocatable: console scripts, conda-meta records and .pth files bake
# the env's absolute prefix at creation; a bare `mv` leaves them dead).
# ============================================================

# Like _make_flat_main_env, but the env carries the artifacts conda bakes
# the absolute prefix into: a console-script shebang, a conda-meta JSON,
# and a site-packages .pth. python stays a plain binary (survives a move).
_make_flat_main_env_with_baked_prefix() {
    local name="$1"
    local old_prefix="$PWD/.pyve/envs/$name"
    mkdir -p ".pyve/envs/$name/conda-meta" \
             ".pyve/envs/$name/bin" \
             ".pyve/envs/$name/lib/python3.12/site-packages"
    : > ".pyve/envs/$name/conda-meta/history"
    : > ".pyve/envs/$name/bin/python"
    chmod +x ".pyve/envs/$name/bin/python"
    printf '#!%s/bin/python\n# pip console script\n' "$old_prefix" \
        > ".pyve/envs/$name/bin/pip"
    chmod +x ".pyve/envs/$name/bin/pip"
    printf '{"extracted_package_dir": "%s/pkgs/pip"}\n' "$old_prefix" \
        > ".pyve/envs/$name/conda-meta/pip-24.0.json"
    printf '%s/lib/python3.12/site-packages\n' "$old_prefix" \
        > ".pyve/envs/$name/lib/python3.12/site-packages/distutils.pth"
    create_pyve_config "backend: micromamba" "micromamba:" "  env_name: $name"
}

@test "migrate_legacy_env_layout: repairs console-script shebangs to the new prefix" {
    _make_flat_main_env_with_baked_prefix myproj
    migrate_legacy_env_layout
    local new_prefix="$PWD/.pyve/envs/root/conda"
    run head -1 ".pyve/envs/root/conda/bin/pip"
    [ "$status" -eq 0 ]
    [ "$output" = "#!$new_prefix/bin/python" ]
}

@test "migrate_legacy_env_layout: leaves no dead reference to the old flat prefix" {
    _make_flat_main_env_with_baked_prefix myproj
    migrate_legacy_env_layout
    # The old prefix string must survive nowhere in the relocated tree
    # (bin shebang, conda-meta records, .pth).
    ! grep -rqF "/.pyve/envs/myproj" ".pyve/envs/root/conda"
}

@test "migrate_legacy_env_layout: repairs the baked prefix in conda-meta records" {
    _make_flat_main_env_with_baked_prefix myproj
    migrate_legacy_env_layout
    run grep -cF "$PWD/.pyve/envs/root/conda" \
        ".pyve/envs/root/conda/conda-meta/pip-24.0.json"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "migrate_legacy_env_layout: does not corrupt the python binary during repair" {
    _make_flat_main_env_with_baked_prefix myproj
    migrate_legacy_env_layout
    # python is relocated as-is (a real Mach-O/ELF must never be sed'd).
    [ -f ".pyve/envs/root/conda/bin/python" ]
    [ -x ".pyve/envs/root/conda/bin/python" ]
}

# ============================================================
# Runnability backstop: an existing env with dead-shebang console
# scripts is rebuilt, not skipped (existence ≠ runnability).
# ============================================================

_make_root_conda_dead() {
    mkdir -p .pyve/envs/root/conda/conda-meta .pyve/envs/root/conda/bin
    : > .pyve/envs/root/conda/conda-meta/history
    # Shebang points at an interpreter that does not exist.
    printf '#!%s/.pyve/envs/GONE/bin/python\n' "$PWD" > .pyve/envs/root/conda/bin/pip
    chmod +x .pyve/envs/root/conda/bin/pip
}

_make_root_conda_healthy() {
    mkdir -p .pyve/envs/root/conda/conda-meta .pyve/envs/root/conda/bin
    : > .pyve/envs/root/conda/conda-meta/history
    printf '#!/bin/sh\necho "pip 24.0"\n' > .pyve/envs/root/conda/bin/pip
    chmod +x .pyve/envs/root/conda/bin/pip
}

@test "_micromamba_env_runnable: dead-shebang console script -> non-runnable" {
    _make_root_conda_dead
    run _micromamba_env_runnable ".pyve/envs/root/conda"
    [ "$status" -ne 0 ]
}

@test "_micromamba_env_runnable: working console script -> runnable" {
    _make_root_conda_healthy
    run _micromamba_env_runnable ".pyve/envs/root/conda"
    [ "$status" -eq 0 ]
}

@test "_micromamba_env_runnable: env with no console scripts -> runnable" {
    mkdir -p .pyve/envs/root/conda/conda-meta
    run _micromamba_env_runnable ".pyve/envs/root/conda"
    [ "$status" -eq 0 ]
}

# A fake micromamba whose `create -p <path>` materializes a healthy env
# and drops a sentinel, so tests can tell "rebuilt" from "skipped".
_install_fake_micromamba() {
    mkdir -p .fakebin
    cat > .fakebin/micromamba <<'EOF'
#!/usr/bin/env bash
path=""
while [[ $# -gt 0 ]]; do
    case "$1" in -p) path="$2"; shift 2;; *) shift;; esac
done
mkdir -p "$path/conda-meta" "$path/bin"
: > "$path/conda-meta/history"
printf '#!/bin/sh\necho ok\n' > "$path/bin/pip"; chmod +x "$path/bin/pip"
touch ".micromamba_create_called"
EOF
    chmod +x .fakebin/micromamba
    get_micromamba_path() { printf '%s/.fakebin/micromamba' "$PWD"; }
}

@test "create_micromamba_env: rebuilds a non-runnable existing env instead of skipping" {
    _make_root_conda_dead
    printf 'name: myproj\n' > environment.yml
    _install_fake_micromamba
    run create_micromamba_env myproj environment.yml
    [ "$status" -eq 0 ]
    [ -f .micromamba_create_called ]
}

@test "create_micromamba_env: skips a runnable existing env (no rebuild)" {
    _make_root_conda_healthy
    printf 'name: myproj\n' > environment.yml
    _install_fake_micromamba
    run create_micromamba_env myproj environment.yml
    [ "$status" -eq 0 ]
    [ ! -f .micromamba_create_called ]
}

# ============================================================
# venv relocation is shebang-bearing too — the v2.8 testenv mover must
# repair the baked prefix the same way (audit follow-on).
# ============================================================

@test "migrate_legacy_env_layout: repairs venv console-script shebangs on a v2.8 testenv move" {
    local old_prefix="$PWD/.pyve/testenvs/lint/venv"
    mkdir -p ".pyve/testenvs/lint/venv/bin"
    : > ".pyve/testenvs/lint/venv/bin/python"
    chmod +x ".pyve/testenvs/lint/venv/bin/python"
    printf '#!%s/bin/python\n# pytest console script\n' "$old_prefix" \
        > ".pyve/testenvs/lint/venv/bin/pytest"
    chmod +x ".pyve/testenvs/lint/venv/bin/pytest"
    migrate_legacy_env_layout
    local new_prefix="$PWD/.pyve/envs/lint/venv"
    run head -1 ".pyve/envs/lint/venv/bin/pytest"
    [ "$status" -eq 0 ]
    [ "$output" = "#!$new_prefix/bin/python" ]
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
