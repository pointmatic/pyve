#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `migrate_legacy_env_layout` in lib/envs.sh
# (Story M.h.2). One helper, four outcome cases:
#
#   1. Legacy `.pyve/testenv/venv/` only          → migrate + write .state
#   2. New `.pyve/envs/testenv/venv/` already → no-op (idempotent)
#   3. Both legacy + new exist                    → no-op (do not overwrite)
#   4. Neither exists (greenfield project)        → no-op (no trigger)
#
# Not yet wired into pyve update or the resolver — that's M.h.3.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envs.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ---------- fixture helpers ----------

_make_legacy_venv() {
    mkdir -p ".pyve/testenv/venv/bin"
    cat > ".pyve/testenv/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/testenv/venv/bin/python"
    # Marker file so we can verify the dir contents moved intact.
    printf 'legacy-marker' > ".pyve/testenv/venv/MARKER"
}

_make_new_venv() {
    mkdir -p ".pyve/envs/testenv/venv/bin"
    cat > ".pyve/envs/testenv/venv/bin/python" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    chmod +x ".pyve/envs/testenv/venv/bin/python"
    printf 'new-marker' > ".pyve/envs/testenv/venv/MARKER"
}

# ============================================================
# Case 1 — legacy only → migrate
# ============================================================

@test "migrate: legacy-only → moves venv, writes initial .state, removes legacy parent" {
    _make_legacy_venv
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    # New path exists with original contents intact.
    [ -d ".pyve/envs/testenv/venv" ]
    [ -x ".pyve/envs/testenv/venv/bin/python" ]
    [ "$(cat .pyve/envs/testenv/venv/MARKER)" = "legacy-marker" ]
    # Legacy path is gone (parent .pyve/testenv removed when empty).
    [ ! -d ".pyve/testenv" ]
    # .state was written with backend=venv and the defaults.
    [ -f ".pyve/envs/testenv/.state" ]
    grep -q "^backend=venv$"        ".pyve/envs/testenv/.state"
    grep -q "^manifest=$"           ".pyve/envs/testenv/.state"
    grep -q "^manifest_sha256=$"    ".pyve/envs/testenv/.state"
    grep -q "^last_used_at=0$"      ".pyve/envs/testenv/.state"
    # provisioned_at present and numeric.
    grep -qE "^provisioned_at=[0-9]+$" ".pyve/envs/testenv/.state"
}

@test "migrate: legacy-only → user sees a one-line info on stdout" {
    _make_legacy_venv
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    # info() in lib/ui/core.sh prints to stdout; assert the migration
    # event is surfaced. Substring kept loose so message wording can evolve.
    [[ "$output" == *"testenv"* ]]
    [[ "$output" == *".pyve/envs/testenv"* ]]
}

@test "migrate: provisioned_at reflects the legacy venv's mtime when available" {
    _make_legacy_venv
    # Backdate the venv dir to a known historical mtime (10 days ago).
    local target=$(( $(date +%s) - 10 * 86400 ))
    # touch -t accepts YYYYMMDDHHMM.SS; convert epoch.
    if [[ "$(uname)" == "Darwin" ]]; then
        touch -mt "$(date -r "$target" +%Y%m%d%H%M.%S)" ".pyve/testenv/venv"
    else
        touch -d "@$target" ".pyve/testenv/venv"
    fi
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    local pa; pa=$(grep '^provisioned_at=' ".pyve/envs/testenv/.state" | cut -d= -f2)
    # Allow ±2s slack for filesystem-precision noise.
    [ "$pa" -ge $(( target - 2 )) ]
    [ "$pa" -le $(( target + 2 )) ]
}

# ============================================================
# Case 2 — new path already present → no-op (idempotent)
# ============================================================

@test "migrate: already-migrated (new only) → no-op, no .state churn" {
    _make_new_venv
    state_write testenv venv manifest=req.txt last_used_at=12345
    local before_state; before_state="$(cat .pyve/envs/testenv/.state)"
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    # New path untouched.
    [ "$(cat .pyve/envs/testenv/venv/MARKER)" = "new-marker" ]
    # .state untouched (no overwrite of an existing migrated env).
    [ "$(cat .pyve/envs/testenv/.state)" = "$before_state" ]
}

@test "migrate: idempotent (running twice on a legacy project produces the same result)" {
    _make_legacy_venv
    migrate_legacy_env_layout
    local after_first; after_first="$(cat .pyve/envs/testenv/.state)"
    # Second invocation hits the already-migrated branch.
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    [ "$(cat .pyve/envs/testenv/.state)" = "$after_first" ]
    [ "$(cat .pyve/envs/testenv/venv/MARKER)" = "legacy-marker" ]
}

# ============================================================
# Case 3 — both exist → no-op, do not overwrite
# ============================================================

@test "migrate: both legacy and new exist → no-op, new content preserved, legacy left alone" {
    _make_legacy_venv
    _make_new_venv
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    # New path's marker intact (was not overwritten by legacy contents).
    [ "$(cat .pyve/envs/testenv/venv/MARKER)" = "new-marker" ]
    # Legacy path still present (the helper does not touch it when the
    # new layout is already present — leaves it to the user / a later
    # cleanup story rather than silently deleting state).
    [ -d ".pyve/testenv/venv" ]
    [ "$(cat .pyve/testenv/venv/MARKER)" = "legacy-marker" ]
}

# ============================================================
# Case 4 — greenfield project (neither exists)
# ============================================================

@test "migrate: greenfield (no .pyve at all) → no-op, no directories created" {
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    [ ! -d ".pyve" ]
}

@test "migrate: greenfield (empty .pyve) → no-op, no testenv directories created" {
    mkdir -p ".pyve"
    run migrate_legacy_env_layout
    [ "$status" -eq 0 ]
    [ ! -d ".pyve/testenv" ]
    [ ! -d ".pyve/envs" ]
}

# ============================================================
# bash-3.2 set -u safety
# ============================================================

@test "no 'unbound variable' under 'set -euo pipefail' across all four branches" {
    # Run each branch in a fresh strict shell, accumulating stderr.
    local stderr=""
    for case in legacy already_migrated both greenfield; do
        local out
        out="$(/bin/bash -c "
            set -euo pipefail
            export PYVE_ROOT='$PYVE_ROOT'
            export PYVE_PYTHON='$PYVE_PYTHON'
            source '$PYVE_ROOT/lib/envs.sh'
            workdir=\$(mktemp -d)
            cd \"\$workdir\"
            case '$case' in
                legacy)           mkdir -p .pyve/testenv/venv ;;
                already_migrated) mkdir -p .pyve/envs/testenv/venv
                                  printf 'backend=venv\nmanifest=\nmanifest_sha256=\nprovisioned_at=0\nlast_used_at=0\n' > .pyve/envs/testenv/.state ;;
                both)             mkdir -p .pyve/testenv/venv .pyve/envs/testenv/venv ;;
                greenfield)       : ;;
            esac
            migrate_legacy_env_layout >/dev/null
            rm -rf \"\$workdir\"
        " 2>&1)" || true
        stderr+="$out"$'\n'
    done
    [[ "$stderr" != *"unbound variable"* ]] || {
        echo "stderr contained 'unbound variable':"
        echo "$stderr"
        false
    }
}
