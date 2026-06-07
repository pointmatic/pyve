#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `pyve init` writes `pyve.toml` on fresh
# projects, treats an existing `pyve.toml` as a refresh.
#
# Scope per N.e (after the in-story scope decision):
#   - `_init_write_pyve_toml`: the new file emitter (project name +
#     [env.root] + [env.testenv] + pyve_schema header).
#   - `_init_validate_existing_manifest`: the new refresh-path guard
#     that runs `manifest_load` on an existing `pyve.toml` and exits
#     non-zero with a precise error on validation failure.
#   - Source-grep verification that init_project is wired to both
#     helpers — full end-to-end init_project flow is too expensive
#     to exercise per test and already covered by the larger
#     test_init_wizard.bats / integration suite.
#
# Tasks 2 (v2-source detection + soft banner) and 4 (remove
# .pyve/config write) are deferred to later stories; see the
# `pyve init` scope note in stories.md.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    # Capture an absolute path to a working python BEFORE create_test_dir
    # changes cwd — same asdf-shim trap as N.d.1, but here we just need a
    # stable interpreter for manifest_load's helper invocation. Mirrors
    # the pattern in test_manifest.bats:31.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

#============================================================
# _init_write_pyve_toml — happy path
#============================================================

@test "_init_write_pyve_toml: creates pyve.toml in cwd" {
    run _init_write_pyve_toml "myproject"
    [ "$status" -eq 0 ]
    [ -f pyve.toml ]
}

@test "_init_write_pyve_toml: emits pyve_schema = \"3.0\"" {
    _init_write_pyve_toml "myproject"
    grep -qE '^pyve_schema = "3\.0"$' pyve.toml
}

@test "_init_write_pyve_toml: emits [project] with name from arg" {
    _init_write_pyve_toml "myproject"
    grep -qE '^\[project\]$' pyve.toml
    grep -qE '^name = "myproject"$' pyve.toml
}

@test "_init_write_pyve_toml: emits [env.root] with purpose = utility" {
    _init_write_pyve_toml "myproject"
    grep -qE '^\[env\.root\]$' pyve.toml
    # The purpose line for [env.root] must appear inside its section,
    # not under [env.testenv]. Use awk's flag pattern (not the range
    # pattern — `/[env.root]/,/[/` collapses because the header line
    # matches both endpoints) to scope to that section's body.
    awk '/^\[env\.root\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^purpose = "utility"$'
}

@test "_init_write_pyve_toml: emits [env.testenv] with purpose = test, default = true" {
    _init_write_pyve_toml "myproject"
    grep -qE '^\[env\.testenv\]$' pyve.toml
    awk '/^\[env\.testenv\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^purpose = "test"$'
    awk '/^\[env\.testenv\]$/{flag=1;next} /^\[/{flag=0} flag' pyve.toml \
        | grep -qE '^default = true$'
}

@test "_init_write_pyve_toml: output validates clean under manifest_load" {
    _init_write_pyve_toml "demo"
    # manifest_load is sourced via setup_pyve_env (test_helper.bash:23).
    # Call directly, not via `run` — `run` subshells, which would lose
    # the global array state we want to inspect below.
    manifest_load "$(pwd)/pyve.toml"
    [ "$PYVE_PROJECT_NAME" = "demo" ]
    # Both envs declared.
    [ "${#PYVE_ENV_NAMES[@]}" -eq 2 ]
    # Order of envs in pyve.toml: [env.root] first, [env.testenv] second.
    [ "${PYVE_ENV_NAMES[0]}" = "root" ]
    [ "${PYVE_ENV_NAMES[1]}" = "testenv" ]
    [ "${PYVE_ENV_PURPOSE[0]}" = "utility" ]
    [ "${PYVE_ENV_PURPOSE[1]}" = "test" ]
    [ "${PYVE_ENV_DEFAULT[1]}" = "1" ]
}

#============================================================
# _init_write_pyve_toml — refusal to overwrite (story N.e Task 3:
# refresh leaves the manifest content alone)
#============================================================

@test "_init_write_pyve_toml: refuses to overwrite an existing pyve.toml" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "preexisting"

[env.root]
purpose = "utility"
EOF
    local before
    before="$(cat pyve.toml)"
    run _init_write_pyve_toml "newname"
    # Behavior: non-overwrite. Status may be 0 (silent no-op) or
    # explicit non-zero — we only enforce that the file was not
    # modified.
    local after
    after="$(cat pyve.toml)"
    [ "$before" = "$after" ]
}

#============================================================
# _init_validate_existing_manifest — refresh-path guard
#============================================================

@test "_init_validate_existing_manifest: succeeds on a valid pyve.toml" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
EOF
    run _init_validate_existing_manifest
    [ "$status" -eq 0 ]
}

@test "_init_validate_existing_manifest: fails non-zero on invalid pyve_schema" {
    cat > pyve.toml <<'EOF'
pyve_schema = "9.9"

[project]
name = "demo"
EOF
    run _init_validate_existing_manifest
    [ "$status" -ne 0 ]
    # The Python helper's error message must reach the user via stderr;
    # `run` captures combined output by default.
    [[ "$output" == *"pyve_schema"* ]] || [[ "$output" == *"pyve.toml"* ]]
}

@test "_init_validate_existing_manifest: fails non-zero on unknown purpose" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.weird]
purpose = "bogus"
EOF
    run _init_validate_existing_manifest
    [ "$status" -ne 0 ]
    [[ "$output" == *"purpose"* ]] || [[ "$output" == *"pyve.toml"* ]]
}

@test "_init_validate_existing_manifest: silent success when pyve.toml is absent" {
    # Absent manifest is a fresh-init signal, not a refresh-path call,
    # so the validator must be a no-op there (caller decides whether
    # to fall through to the writer).
    [ ! -f pyve.toml ]
    run _init_validate_existing_manifest
    [ "$status" -eq 0 ]
}

#============================================================
# init_project source-grep wiring (matches the M.h.3 pattern at
# tests/unit/test_testenvs_activate.bats:141)
#============================================================

@test "init_project: source-grep verifies _init_write_pyve_toml is wired" {
    # Definition contributes 1 hit (`_init_write_pyve_toml()` on its
    # own line); each call site adds another. Expect ≥3 — the
    # function header plus the venv and micromamba backend branches.
    local count
    count="$(grep -cE '_init_write_pyve_toml' "$PYVE_ROOT/lib/plugins/python/plugin.sh")"
    [ "$count" -ge 3 ]
}

@test "init_project: source-grep verifies _init_validate_existing_manifest is wired" {
    # Definition contributes 1 hit; expect ≥2 — the function header
    # plus a single call site inside init_project before the wizard.
    local count
    count="$(grep -cE '_init_validate_existing_manifest' "$PYVE_ROOT/lib/plugins/python/plugin.sh")"
    [ "$count" -ge 2 ]
}
