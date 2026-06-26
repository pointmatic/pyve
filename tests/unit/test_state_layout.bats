#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# v3 state-directory layout pin.
#
# Hard-pins the v3 path shape:
#   .pyve/envs/<name>/<backend>/   (was .pyve/testenvs/<name>/<backend>/ in v2.8)
#   .pyve/envs/<name>/.state       (was .pyve/testenvs/<name>/.state in v2.8)
#
# Also extends the existing v2.7 production-code sweep
# (test_testenvs_activate.bats § "no legacy literals survive") with a
# parallel sweep for `.pyve/testenvs/...` literals — production code
# must route through `state_path()` / `resolve_env_path()`.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # lib/envs.sh isn't in the default helper-load chain — sourced
    # explicitly here for the path-constructor and migration tests.
    source "$PYVE_ROOT/lib/envs.sh"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Path constructors return v3 shapes
#============================================================

@test "state_path: returns .pyve/envs/<name>/.state (v3)" {
    [ "$(state_path testenv)" = ".pyve/envs/testenv/.state" ]
    [ "$(state_path smoke)" = ".pyve/envs/smoke/.state" ]
}

@test "resolve_env_path: venv backend returns .pyve/envs/<name>/venv (v3)" {
    # No pyproject.toml → implicit default for `testenv` is venv-backed
    # (read_env_config synthesizes that shape).
    read_env_config
    [ "$(resolve_env_path testenv)" = ".pyve/envs/testenv/venv" ]
}

@test "resolve_env_path: conda backend returns .pyve/envs/<name>/conda (v3)" {
    cat > pyproject.toml <<'EOF'
[tool.pyve.testenvs.smoke]
backend = "micromamba"
manifest = "environment.yml"
EOF
    export PYVE_PYTHON="$(cd "$PYVE_ROOT" && python -c 'import sys; print(sys.executable)')"
    read_env_config
    [ "$(resolve_env_path smoke)" = ".pyve/envs/smoke/conda" ]
}

@test "resolve_env_path: root short-circuits to .venv (unchanged)" {
    # The micromamba main-env path move (.pyve/envs/<old>/ -> .pyve/envs/root/conda/)
    # is N.g's deterministic-migrator territory; N.f keeps `root` mapping
    # to `.venv` for now (matches today's contract).
    read_env_config
    [ "$(resolve_env_path root)" = ".venv" ]
}

#============================================================
# Opportunistic v2.8 -> v3 migration (extension of M.h.2 helper)
#============================================================

@test "migrate_legacy_env_layout: moves .pyve/testenvs/<name>/venv -> .pyve/envs/<name>/venv" {
    mkdir -p .pyve/testenvs/testenv/venv
    touch .pyve/testenvs/testenv/venv/pyvenv.cfg  # sentinel file
    migrate_legacy_env_layout
    [ -d .pyve/envs/testenv/venv ]
    [ -f .pyve/envs/testenv/venv/pyvenv.cfg ]
    [ ! -d .pyve/testenvs/testenv/venv ]
}

@test "migrate_legacy_env_layout: moves .pyve/testenvs/<name>/conda -> .pyve/envs/<name>/conda" {
    mkdir -p .pyve/testenvs/smoke/conda/conda-meta
    touch .pyve/testenvs/smoke/conda/conda-meta/history
    migrate_legacy_env_layout
    [ -d .pyve/envs/smoke/conda ]
    [ -f .pyve/envs/smoke/conda/conda-meta/history ]
    [ ! -d .pyve/testenvs/smoke ]
}

@test "migrate_legacy_env_layout: also moves the .state sibling file" {
    mkdir -p .pyve/testenvs/testenv/venv
    cat > .pyve/testenvs/testenv/.state <<'EOF'
backend=venv
manifest=
manifest_sha256=
provisioned_at=1700000000
last_used_at=0
EOF
    migrate_legacy_env_layout
    [ -f .pyve/envs/testenv/.state ]
    grep -q "backend=venv" .pyve/envs/testenv/.state
    grep -q "provisioned_at=1700000000" .pyve/envs/testenv/.state
}

@test "migrate_legacy_env_layout: handles multiple named envs in one pass" {
    mkdir -p .pyve/testenvs/testenv/venv
    mkdir -p .pyve/testenvs/smoke/venv
    mkdir -p .pyve/testenvs/integration/venv
    migrate_legacy_env_layout
    [ -d .pyve/envs/testenv/venv ]
    [ -d .pyve/envs/smoke/venv ]
    [ -d .pyve/envs/integration/venv ]
}

@test "migrate_legacy_env_layout: idempotent when v3 layout already in place" {
    mkdir -p .pyve/envs/testenv/venv
    touch .pyve/envs/testenv/venv/pyvenv.cfg
    migrate_legacy_env_layout
    [ -d .pyve/envs/testenv/venv ]
    [ -f .pyve/envs/testenv/venv/pyvenv.cfg ]
}

@test "migrate_legacy_env_layout: greenfield is a clean no-op" {
    # No .pyve/testenv/, no .pyve/testenvs/, no .pyve/envs/.
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    [ ! -d .pyve/envs ]
}

@test "migrate_legacy_env_layout: v2.7 singular layout still migrates to v3" {
    # Pre-existing v2.7 behavior is preserved: .pyve/testenv/venv/ ->
    # the v3 destination (was .pyve/testenvs/testenv/venv/ in v2.8).
    mkdir -p .pyve/testenv/venv
    touch .pyve/testenv/venv/pyvenv.cfg
    migrate_legacy_env_layout
    [ -d .pyve/envs/testenv/venv ]
    [ -f .pyve/envs/testenv/venv/pyvenv.cfg ]
    [ ! -d .pyve/testenv ]
}

@test "migrate_legacy_env_layout: both legacy and v3 present -> preserve v3, leave legacy alone" {
    mkdir -p .pyve/envs/testenv/venv
    touch .pyve/envs/testenv/venv/v3-marker
    mkdir -p .pyve/testenvs/testenv/venv
    touch .pyve/testenvs/testenv/venv/v2-marker
    migrate_legacy_env_layout
    [ -f .pyve/envs/testenv/venv/v3-marker ]
    # Legacy left in place — silent deletion of user state is the wrong default.
    [ -f .pyve/testenvs/testenv/venv/v2-marker ]
}

#============================================================
# Production-code path-literal sweep (extends test_testenvs_activate.bats)
#============================================================

@test "sweep: no '.pyve/testenvs/' literals in production code outside the migration helpers" {
    # Allowed locations (migrator surfaces):
    #   - lib/envs.sh: legitimately mentions the legacy v2.8 path inside
    #     migrate_legacy_env_layout (source-of-truth for the opportunistic
    #     mover).
    #   - lib/commands/self.sh: `pyve self migrate` reads
    #     the legacy paths during detection/backup; its surface refers
    #     to .pyve/testenvs/ by name.
    #   - lib/utils.sh: a doc comment in purge_env_dir noting the legacy v2
    #     path (`.pyve/testenvs/<name>/`). The gitignore is now built by
    #     lib/gitignore_composer.sh, which ignores the whole `.pyve/` tree —
    #     there is no per-`.pyve/testenvs` template line to remove in N-10.
    #
    # Everything else (lib/commands/*.sh other than self.sh, pyve.sh)
    # must route through state_path() / resolve_env_path() / other
    # helpers — hard-coded path strings get caught here.
    local hits
    hits="$(grep -rnE '\.pyve/testenvs/' \
        "$PYVE_ROOT/lib/commands/" \
        "$PYVE_ROOT/pyve.sh" 2>/dev/null \
        | grep -vE '^[^:]+/self\.sh:' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
        | grep -vE '\.pyve/testenvs/<name>/\\\{venv,conda\\\}/' \
        || true)"
    if [[ -n "$hits" ]]; then
        printf 'Forbidden .pyve/testenvs/ literal in production code:\n%s\n' "$hits" >&2
        return 1
    fi
}
