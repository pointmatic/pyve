#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for hash-based environment.yml-drift detection (Story N.bf.15).
#
# At every micromamba env-build path, sha256(environment.yml) is recorded
# in the main env's `.state` `manifest_sha256` field. On the re-init
# "Update in-place" path, the current hash is compared to the stored one;
# a mismatch is surfaced as a nudge toward option 2 (purge + rebuild) —
# the in-place update intentionally does NOT rebuild.
#
# Covers:
#   1. pyve_file_sha256 — deterministic, content-sensitive, portable.
#   2. create_micromamba_env stores sha256(environment.yml) in .state.
#   3. _init_environment_yml_drifted — drift trichotomy + graceful no-state.

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
# pyve_file_sha256 — portable content hash
# ============================================================

@test "pyve_file_sha256: same content yields the same hash" {
    printf 'name: demo\ndependencies:\n  - python=3.12\n' > a.yml
    printf 'name: demo\ndependencies:\n  - python=3.12\n' > b.yml
    run pyve_file_sha256 a.yml
    [ "$status" -eq 0 ]
    local ha="$output"
    run pyve_file_sha256 b.yml
    [ "$ha" = "$output" ]
}

@test "pyve_file_sha256: different content yields different hashes" {
    printf 'name: demo\n' > a.yml
    printf 'name: other\n' > b.yml
    run pyve_file_sha256 a.yml
    local ha="$output"
    run pyve_file_sha256 b.yml
    [ "$ha" != "$output" ]
}

@test "pyve_file_sha256: unreadable file returns non-zero" {
    run pyve_file_sha256 nope.yml
    [ "$status" -ne 0 ]
}

# ============================================================
# create_micromamba_env records environment.yml's hash
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

@test "create_micromamba_env: stores sha256(environment.yml) in manifest_sha256" {
    _stub_micromamba
    cat > environment.yml <<'YML'
name: demo
dependencies:
  - python=3.12
YML
    local expected
    expected="$(pyve_file_sha256 environment.yml)"

    create_micromamba_env demo environment.yml
    state_read root
    [ "$PYVE_TESTENV_STATE_MANIFEST" = "environment.yml" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST_SHA256" = "$expected" ]
}

@test "create_micromamba_env: records environment.yml hash even when built from conda-lock.yml" {
    _stub_micromamba
    cat > environment.yml <<'YML'
name: demo
dependencies:
  - python=3.12
  - conda-lock
YML
    cat > conda-lock.yml <<'YML'
# locked
YML
    local expected
    expected="$(pyve_file_sha256 environment.yml)"

    # Build from the lock file (env_file = conda-lock.yml); drift still
    # tracks the human-edited environment.yml.
    create_micromamba_env demo conda-lock.yml
    state_read root
    [ "$PYVE_TESTENV_STATE_MANIFEST" = "environment.yml" ]
    [ "$PYVE_TESTENV_STATE_MANIFEST_SHA256" = "$expected" ]
}

# ============================================================
# _init_environment_yml_drifted — the comparison
# ============================================================

_seed_root_state_from_envyml() {
    # Mimic an env built from the current environment.yml.
    local sha
    sha="$(pyve_file_sha256 environment.yml)"
    state_write root micromamba manifest=environment.yml manifest_sha256="$sha"
}

@test "_init_environment_yml_drifted: unchanged environment.yml -> no drift" {
    printf 'name: demo\ndependencies:\n  - python=3.12\n' > environment.yml
    _seed_root_state_from_envyml
    run _init_environment_yml_drifted
    [ "$status" -ne 0 ]
}

@test "_init_environment_yml_drifted: edited environment.yml -> drift" {
    printf 'name: demo\ndependencies:\n  - python=3.12\n' > environment.yml
    _seed_root_state_from_envyml
    # User edits the file after the env was built.
    printf 'name: demo\ndependencies:\n  - python=3.12\n  - numpy\n' > environment.yml
    run _init_environment_yml_drifted
    [ "$status" -eq 0 ]
}

@test "_init_environment_yml_drifted: no environment.yml -> no drift" {
    state_write root micromamba manifest=environment.yml manifest_sha256=deadbeef
    run _init_environment_yml_drifted
    [ "$status" -ne 0 ]
}

@test "_init_environment_yml_drifted: no .state -> no drift" {
    printf 'name: demo\n' > environment.yml
    run _init_environment_yml_drifted
    [ "$status" -ne 0 ]
}

@test "_init_environment_yml_drifted: .state without a stored hash -> no false drift" {
    # Pre-N.bf.15 env (or migrated): manifest_sha256 empty.
    printf 'name: demo\n' > environment.yml
    state_write root micromamba manifest=environment.yml
    run _init_environment_yml_drifted
    [ "$status" -ne 0 ]
}
