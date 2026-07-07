#!/usr/bin/env bats
# bats file_tags=env
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `pyve env` CLI dispatcher + `pyve testenv`
# legacy-sugar Category A delegation wrapper.
#
# Surface under test (in pyve.sh):
#   - `pyve env <sub>` routes to env_command "$@"
#   - `pyve testenv <sub>` routes via deprecation_warn → env_command
#   - deprecation_warn helper (Category A primitive, per project-essentials
#     deprecation policy + the documented `pyve testenv` exception)
#   - --help parity between the two forms
#
# Black-box: invokes `bash pyve.sh ...` and asserts on output / exit code.

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_BIN="$PYVE_ROOT/pyve.sh"

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

run_pyve() {
    run bash "$PYVE_BIN" "$@"
}

# ============================================================
# 1. New `pyve env` dispatcher arm
# ============================================================

@test "dispatch: 'pyve env' (no sub) prints canonical 'No env action' error" {
    run_pyve env
    [ "$status" -ne 0 ]
    [[ "$output" == *"No env action"* ]]
    [[ "$output" == *"pyve env"* ]]
}

@test "dispatch: 'pyve env --help' renders canonical env help (mentions 'pyve env')" {
    run_pyve env --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve env"* ]]
    [[ "$output" == *"Usage:"* ]]
}

@test "dispatch: 'pyve env --help' shows no deprecation warning" {
    run_pyve env --help
    [ "$status" -eq 0 ]
    # The canonical `env` spelling must not emit the `pyve testenv` rename nag.
    # Anchor on the nag's signature phrases — not the bare word "deprecated",
    # which `env --help` now legitimately uses to document the deprecated
    # `--force` prompt-skip alias (deprecated, warns).
    [[ "$output" != *"has been renamed to"* ]]
    [[ "$output" != *"legacy form will be removed"* ]]
}

@test "dispatch: 'pyve env' routes through dispatch trace as DISPATCH:env" {
    PYVE_DISPATCH_TRACE=1 run_pyve env init smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:env"* ]]
}

# ============================================================
# 2. Legacy `pyve testenv` arm — Category A delegation
# ============================================================

@test "delegation: 'pyve testenv --help' still exits 0 and prints help" {
    run_pyve testenv --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "delegation: 'pyve testenv --help' fires deprecation warning" {
    run_pyve testenv --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"deprecated"* ]] || [[ "$output" == *"renamed"* ]]
    [[ "$output" == *"pyve env"* ]]
}

@test "delegation: deprecation warning specifically names 'pyve testenv' as legacy" {
    run_pyve testenv --help
    [[ "$output" == *"pyve testenv"* ]]
}

@test "delegation: 'pyve testenv' (no sub) still produces the env-dispatcher error" {
    run_pyve testenv
    [ "$status" -ne 0 ]
    # The deprecation warning fires; then env_command's "No env action" error
    [[ "$output" == *"No env action"* ]] || [[ "$output" == *"No testenv action"* ]]
}

@test "delegation: 'pyve testenv' routes through dispatch trace as DISPATCH:testenv (deprecated path)" {
    PYVE_DISPATCH_TRACE=1 run_pyve testenv init smoke
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:testenv"* ]]
}

# ============================================================
# 3. Help parity — both forms render the same canonical body
# ============================================================

@test "help parity: 'pyve env --help' and 'pyve testenv --help' share canonical Usage lines" {
    run_pyve env --help
    [ "$status" -eq 0 ]
    local env_output="$output"

    run_pyve testenv --help
    [ "$status" -eq 0 ]
    # Strip the deprecation banner from the legacy form; compare the
    # canonical help body.
    local testenv_body
    testenv_body="$(printf '%s\n' "$output" | grep -v -iE 'deprecat|renamed')"
    # Both must contain the same Usage block
    [[ "$env_output" == *"pyve env init"* ]]
    [[ "$testenv_body" == *"pyve env init"* ]]
}

# ============================================================
# 4. deprecation_warn primitive — direct probe via testenv invocation
# ============================================================

@test "deprecation_warn: message is precise (contains 'pyve testenv' and 'pyve env' and a deprecation verb)" {
    run_pyve testenv --help
    [[ "$output" == *"pyve testenv"* ]]
    [[ "$output" == *"pyve env"* ]]
    # The message must use a recognized deprecation verb so users / LLMs
    # parsing stderr have a stable signal.
    [[ "$output" == *"deprecated"* ]] || [[ "$output" == *"renamed"* ]]
}

@test "deprecation_warn: written to stderr (separable from command output)" {
    run bash -c "bash '$PYVE_BIN' testenv --help 2>/tmp/n_c_stderr.txt"
    [ "$status" -eq 0 ]
    local stderr_content
    stderr_content="$(cat /tmp/n_c_stderr.txt)"
    rm -f /tmp/n_c_stderr.txt
    # Deprecation message must be in stderr
    [[ "$stderr_content" == *"deprecated"* ]] || [[ "$stderr_content" == *"renamed"* ]]
    # And it must mention both names
    [[ "$stderr_content" == *"pyve testenv"* ]]
    [[ "$stderr_content" == *"pyve env"* ]]
}

#============================================================
# Story O.j — the box footer must reflect the real outcome. A failed
# leaf used to render the green '✔ All done.' under its ✘ errors because
# footer_box was status-blind; env_command now threads leaf_rc into it.
#============================================================

@test "env: a failed 'env init' shows the failure footer, never '✔ All done.'" {
    # Force a deterministic leaf failure, independent of the runner's
    # installed Python: point the project interpreter at a nonexistent path
    # so `env init` fails at python resolution and RETURNS to the footer.
    # (A bare `env init` on a clean dir SUCCEEDS whenever `python` resolves —
    # it just creates the venv — so the failure must be forced.) The footer
    # must render red '✘ Failed.', not green '✔ All done.'.
    export PYVE_PYTHON=/nonexistent/python
    run bash "$PYVE_BIN" env init testenv
    [ "$status" -ne 0 ]
    # The bug: a green success box printed beneath the ✘ errors.
    ! printf '%s' "$output" | grep -qF "All done."
    # The failure footer renders instead.
    printf '%s' "$output" | grep -qF "Failed."
}
