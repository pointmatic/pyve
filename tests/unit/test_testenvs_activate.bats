#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the M.h.3 layout cut-over:
#
#   - resolve_testenv_path testenv triggers migration as a side effect
#     when only the legacy layout is present (opportunistic fallback).
#   - resolve_testenv_path on any name is otherwise a pure pretty-printer.
#   - lib/commands/update.sh exposes a private migration wrapper that
#     update_project invokes (verified by sourcing + grep).
#   - testenv_paths in lib/utils.sh emits the new paths (.pyve/testenvs/testenv/...).
#   - purge_testenv_dir in lib/utils.sh removes the new layout.
#   - lib/utils.sh's gitignore template ignores .pyve/testenvs (not .pyve/testenv).
#
# Existing test_test_command.bats / test_status.bats fixtures are updated
# separately to point at the new path; that update is part of M.h.3.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/testenvs.sh"
    source "$PYVE_ROOT/lib/commands/update.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ============================================================
# resolve_testenv_path opportunistic migration
# ============================================================

@test "resolve_testenv_path testenv: legacy-only state triggers migration as a side effect" {
    mkdir -p ".pyve/testenv/venv/bin"
    printf 'legacy-marker' > ".pyve/testenv/venv/MARKER"

    # Discard stdout — we only care about the migration side effect here.
    resolve_testenv_path testenv >/dev/null

    # Migration happened: new path exists with original contents.
    [ -d ".pyve/testenvs/testenv/venv" ]
    [ "$(cat .pyve/testenvs/testenv/venv/MARKER)" = "legacy-marker" ]
    [ ! -d ".pyve/testenv" ]
    [ -f ".pyve/testenvs/testenv/.state" ]
}

@test "resolve_testenv_path testenv: greenfield project does NOT create any directories" {
    [ ! -d ".pyve" ]
    [ "$(resolve_testenv_path testenv)" = ".pyve/testenvs/testenv/venv" ]
    # Pure pretty-printer when neither legacy nor new state exists.
    [ ! -d ".pyve" ]
}

@test "resolve_testenv_path testenv: already-migrated state is a no-op (no churn)" {
    mkdir -p ".pyve/testenvs/testenv/venv"
    printf 'new-marker' > ".pyve/testenvs/testenv/venv/MARKER"

    resolve_testenv_path testenv >/dev/null
    # Marker untouched; no .state appears if it wasn't already present.
    [ "$(cat .pyve/testenvs/testenv/venv/MARKER)" = "new-marker" ]
}

@test "resolve_testenv_path other-name: never triggers migration (only 'testenv' has a legacy form)" {
    mkdir -p ".pyve/testenv/venv"
    # An unrelated name lookup must not move .pyve/testenv/.
    resolve_testenv_path hardware >/dev/null
    [ -d ".pyve/testenv/venv" ]
    [ ! -d ".pyve/testenvs/hardware" ]
}

@test "resolve_testenv_path root: never triggers migration (root is selection-only)" {
    mkdir -p ".pyve/testenv/venv"
    resolve_testenv_path root >/dev/null
    [ -d ".pyve/testenv/venv" ]
}

# ============================================================
# testenv_paths emits the new layout
# ============================================================

@test "testenv_paths: emits new .pyve/testenvs/testenv root + venv paths" {
    local out
    out="$(testenv_paths)"
    local root venv
    root="$(printf "%s" "$out" | sed -n '1p')"
    venv="$(printf "%s" "$out" | sed -n '2p')"
    [ "$root" = ".pyve/testenvs/testenv" ]
    [ "$venv" = ".pyve/testenvs/testenv/venv" ]
}

# ============================================================
# purge_testenv_dir removes the new layout
# ============================================================

@test "purge_testenv_dir: removes .pyve/testenvs/testenv (new layout)" {
    mkdir -p ".pyve/testenvs/testenv/venv/bin"
    purge_testenv_dir >/dev/null 2>&1
    [ ! -d ".pyve/testenvs/testenv" ]
}

@test "purge_testenv_dir: missing testenv prints info, no error" {
    run purge_testenv_dir
    [ "$status" -eq 0 ]
}

# ============================================================
# gitignore template ignores the new layout (.pyve/testenvs)
# ============================================================

@test "gitignore template: pyve-managed section ignores .pyve/testenvs (not .pyve/testenv)" {
    # write_gitignore_template writes to ./.gitignore in cwd.
    write_gitignore_template
    grep -qxF ".pyve/testenvs" .gitignore
    # Legacy entry not written for new projects.
    if grep -qxF ".pyve/testenv" .gitignore; then
        echo "stale legacy entry '.pyve/testenv' present in fresh .gitignore" >&2
        false
    fi
}

# ============================================================
# pyve update wiring — private wrapper exists and is referenced
# ============================================================

@test "_update_migrate_legacy_layout: wrapper exists in lib/commands/update.sh" {
    type -t _update_migrate_legacy_layout | grep -q "function"
}

@test "_update_migrate_legacy_layout: invoking it migrates a legacy project" {
    mkdir -p ".pyve/testenv/venv/bin"
    _update_migrate_legacy_layout >/dev/null
    [ -d ".pyve/testenvs/testenv/venv" ]
    [ ! -d ".pyve/testenv" ]
}

@test "update_project: source-grep verifies the migration wrapper is wired" {
    # We don't invoke update_project end-to-end here (it does many other
    # things that need a fully-initialized project). Source-level grep
    # gives a brittle-but-accurate "the wiring is present" signal.
    grep -qE "_update_migrate_legacy_layout|migrate_legacy_testenv_layout" \
        "$PYVE_ROOT/lib/commands/update.sh"
}

# ============================================================
# No legacy literals survive in production code
# ============================================================

@test "sweep: no '.pyve/testenv/' or '.pyve/\$TESTENV_DIR_NAME' literals in production code outside the migration helper" {
    # Allowed locations: lib/testenvs.sh (the migration helper itself
    # legitimately references the legacy path), pyve.sh (the back-compat
    # TESTENV_DIR_NAME global declaration). Everything else must be gone.
    local hits
    hits="$(grep -rnE '\.pyve/(\$TESTENV_DIR_NAME|testenv[^s])' \
        "$PYVE_ROOT/lib/utils.sh" \
        "$PYVE_ROOT/lib/commands/test.sh" \
        "$PYVE_ROOT/lib/commands/testenv.sh" \
        "$PYVE_ROOT/lib/commands/check.sh" \
        "$PYVE_ROOT/lib/commands/status.sh" \
        "$PYVE_ROOT/lib/commands/purge.sh" \
        2>&1 | grep -v '^[^:]*:[0-9]*:\s*#' || true)"
    if [[ -n "$hits" ]]; then
        echo "legacy-path literals survived in production code:" >&2
        echo "$hits" >&2
        false
    fi
}
