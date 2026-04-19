#!/usr/bin/env bats
#
# Unit tests for per-subcommand --help plumbing in pyve.sh.
#
# Story G.b.2 — every renamed subcommand from G.b.1 must respond to
# `pyve <sub> --help` (and `-h`) by printing a focused, non-empty help
# block and exiting 0 BEFORE the real handler runs.  Top-level
# `pyve --help` must be regrouped into four sections:
#   Environment, Execution, Diagnostics, Self management.
#
# These tests are black-box: they invoke `bash pyve.sh ...` and assert
# on output content + exit code.  Each per-subcommand assertion uses a
# strict marker line that ONLY appears in that subcommand's help block,
# so a fall-through to top-level help would fail the assertion loudly.
#

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

#============================================================
# Per-subcommand --help — exit 0, non-empty, strict marker
#============================================================

@test "help: 'pyve init --help' prints init help and exits 0" {
    run_pyve init --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"pyve init - Initialize"* ]]
}

@test "help: 'pyve init -h' is equivalent to --help" {
    run_pyve init -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init - Initialize"* ]]
}

@test "help: 'pyve purge --help' prints purge help and exits 0" {
    run_pyve purge --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"pyve purge - Remove"* ]]
}

@test "help: 'pyve purge -h' is equivalent to --help" {
    run_pyve purge -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve purge - Remove"* ]]
}

@test "help: 'pyve validate --help' delegates to check's help (H.e.8)" {
    run_pyve validate --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve check"* ]]
}

@test "help: 'pyve validate -h' delegates to check's help (H.e.8)" {
    run_pyve validate -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve check"* ]]
}

@test "help: 'pyve python-version --help' prints python-version help and exits 0" {
    run_pyve python-version --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"pyve python-version - Set Python version"* ]]
}

@test "help: 'pyve python-version -h' is equivalent to --help" {
    run_pyve python-version -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve python-version - Set Python version"* ]]
}

@test "help: 'pyve self --help' prints self namespace help and exits 0" {
    run_pyve self --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Same strict marker the namespace dispatcher already prints.
    [[ "$output" == *"Usage: pyve self <subcommand>"* ]]
}

@test "help: 'pyve self -h' is equivalent to --help" {
    run_pyve self -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: pyve self <subcommand>"* ]]
}

@test "help: 'pyve self install --help' prints self-install help and exits 0" {
    run_pyve self install --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"pyve self install - Install pyve"* ]]
}

@test "help: 'pyve self install -h' is equivalent to --help" {
    run_pyve self install -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self install - Install pyve"* ]]
}

@test "help: 'pyve self uninstall --help' prints self-uninstall help and exits 0" {
    run_pyve self uninstall --help
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"pyve self uninstall - Remove pyve"* ]]
}

@test "help: 'pyve self uninstall -h' is equivalent to --help" {
    run_pyve self uninstall -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self uninstall - Remove pyve"* ]]
}

#============================================================
# Top-level --help — four section headers (FR-G4)
#============================================================

@test "top-level help: 'pyve --help' contains 'Environment:' section header" {
    run_pyve --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Environment:"* ]]
}

@test "top-level help: 'pyve --help' contains 'Execution:' section header" {
    run_pyve --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Execution:"* ]]
}

@test "top-level help: 'pyve --help' contains 'Diagnostics:' section header" {
    run_pyve --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Diagnostics:"* ]]
}

@test "top-level help: 'pyve --help' contains 'Self management:' section header" {
    run_pyve --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Self management:"* ]]
}

#============================================================
# Regression: --help must NOT trigger the real handler
#============================================================

@test "regression: 'pyve init --help' does not create .venv (handler never runs)" {
    # If the dispatcher fell through to the init handler, it would try
    # to create .venv in TEST_DIR (which is empty) — fail this test by
    # asserting no .venv exists after the call.
    run_pyve init --help
    [ "$status" -eq 0 ]
    [ ! -d ".venv" ]
    [ ! -d ".pyve" ]
}

@test "regression: 'pyve purge --help' does not delete anything" {
    # Create a marker file that purge would otherwise leave alone
    # (purge only touches .pyve / venv dirs), then verify --help
    # returns without ever invoking the real handler.
    mkdir -p .pyve
    touch .pyve/marker
    run_pyve purge --help
    [ "$status" -eq 0 ]
    [ -f ".pyve/marker" ]
}
