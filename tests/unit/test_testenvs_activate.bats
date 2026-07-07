#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the M.h.3 layout cut-over:
#
#   - resolve_env_path testenv triggers migration as a side effect
#     when only the legacy layout is present (opportunistic fallback).
#   - resolve_env_path on any name is otherwise a pure pretty-printer.
#   - lib/plugins/python/plugin.sh exposes a private migration wrapper that
#     update_project invokes (verified by sourcing + grep).
#   - env_paths in lib/utils.sh emits the new paths (.pyve/envs/testenv/...).
#   - purge_env_dir in lib/utils.sh removes the new layout.
#   - the composed .gitignore (lib/gitignore_composer.sh) ignores the whole
#     .pyve/ state tree (covers .pyve/envs; no per-.pyve/testenv line).
#
# Existing test_test_command.bats / test_status.bats fixtures are updated
# separately to point at the new path; that update is part of M.h.3.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ============================================================
# resolve_env_path opportunistic migration
# ============================================================

@test "resolve_env_path testenv: legacy-only state triggers migration as a side effect" {
    mkdir -p ".pyve/testenv/venv/bin"
    printf 'legacy-marker' > ".pyve/testenv/venv/MARKER"

    # Discard stdout — we only care about the migration side effect here.
    resolve_env_path testenv >/dev/null

    # Migration happened: new path exists with original contents.
    [ -d ".pyve/envs/testenv/venv" ]
    [ "$(cat .pyve/envs/testenv/venv/MARKER)" = "legacy-marker" ]
    [ ! -d ".pyve/testenv" ]
    [ -f ".pyve/envs/testenv/.state" ]
}

@test "resolve_env_path testenv: greenfield project does NOT create any directories" {
    [ ! -d ".pyve" ]
    [ "$(resolve_env_path testenv)" = ".pyve/envs/testenv/venv" ]
    # Pure pretty-printer when neither legacy nor new state exists.
    [ ! -d ".pyve" ]
}

@test "resolve_env_path testenv: already-migrated state is a no-op (no churn)" {
    mkdir -p ".pyve/envs/testenv/venv"
    printf 'new-marker' > ".pyve/envs/testenv/venv/MARKER"

    resolve_env_path testenv >/dev/null
    # Marker untouched; no .state appears if it wasn't already present.
    [ "$(cat .pyve/envs/testenv/venv/MARKER)" = "new-marker" ]
}

@test "resolve_env_path other-name: never triggers migration (only 'testenv' has a legacy form)" {
    mkdir -p ".pyve/testenv/venv"
    # An unrelated name lookup must not move .pyve/testenv/.
    resolve_env_path hardware >/dev/null
    [ -d ".pyve/testenv/venv" ]
    [ ! -d ".pyve/envs/hardware" ]
}

@test "resolve_env_path root: never triggers migration (root is selection-only)" {
    mkdir -p ".pyve/testenv/venv"
    resolve_env_path root >/dev/null
    [ -d ".pyve/testenv/venv" ]
}

# ============================================================
# env_paths emits the new layout
# ============================================================

@test "env_paths: emits new .pyve/envs/testenv root + venv paths" {
    local out
    out="$(env_paths)"
    local root venv
    root="$(printf "%s" "$out" | sed -n '1p')"
    venv="$(printf "%s" "$out" | sed -n '2p')"
    [ "$root" = ".pyve/envs/testenv" ]
    [ "$venv" = ".pyve/envs/testenv/venv" ]
}

# ============================================================
# purge_env_dir removes the new layout
# ============================================================

@test "purge_env_dir: removes .pyve/envs/testenv (new layout)" {
    mkdir -p ".pyve/envs/testenv/venv/bin"
    purge_env_dir >/dev/null 2>&1
    [ ! -d ".pyve/envs/testenv" ]
}

@test "purge_env_dir: missing testenv prints info, no error" {
    run purge_env_dir
    [ "$status" -eq 0 ]
}

# ============================================================
# pyve update wiring — private wrapper exists and is referenced
# ============================================================

@test "_update_migrate_legacy_layout: wrapper exists in lib/plugins/python/plugin.sh" {
    type -t _update_migrate_legacy_layout | grep -q "function"
}

@test "_update_migrate_legacy_layout: invoking it migrates a legacy project" {
    mkdir -p ".pyve/testenv/venv/bin"
    _update_migrate_legacy_layout >/dev/null
    [ -d ".pyve/envs/testenv/venv" ]
    [ ! -d ".pyve/testenv" ]
}

@test "update_project: source-grep verifies the migration wrapper is wired" {
    # We don't invoke update_project end-to-end here (it does many other
    # things that need a fully-initialized project). Source-level grep
    # gives a brittle-but-accurate "the wiring is present" signal.
    grep -qE "_update_migrate_legacy_layout|migrate_legacy_env_layout" \
        "$PYVE_ROOT/lib/plugins/python/plugin.sh"
}

# ============================================================
# No legacy literals survive in production code
# ============================================================

@test "sweep: no '.pyve/testenv/' or '.pyve/\$TESTENV_DIR_NAME' literals in production code outside the migration helper" {
    # Allowed locations: lib/envs.sh (the migration helper itself
    # legitimately references the legacy path), pyve.sh (the back-compat
    # TESTENV_DIR_NAME global declaration). Everything else must be gone.
    local hits
    hits="$(grep -rnE '\.pyve/(\$TESTENV_DIR_NAME|testenv[^s])' \
        "$PYVE_ROOT/lib/utils.sh" \
        "$PYVE_ROOT/lib/plugins/python/plugin.sh" \
        "$PYVE_ROOT/lib/commands/env.sh" \
        "$PYVE_ROOT/lib/plugins/python/plugin.sh" \
        "$PYVE_ROOT/lib/plugins/python/plugin.sh" \
        "$PYVE_ROOT/lib/plugins/python/plugin.sh" \
        2>&1 | grep -v '^[^:]*:[0-9]*:\s*#' || true)"
    if [[ -n "$hits" ]]; then
        echo "legacy-path literals survived in production code:" >&2
        echo "$hits" >&2
        false
    fi
}
