#!/usr/bin/env bats
#
# Unit tests for the top-level CLI dispatcher in pyve.sh.
#
# These tests are black-box: they invoke `bash pyve.sh ...` against a
# stubbed environment so the dispatcher is exercised but the actual
# command handlers (init, purge, validate, ...) are replaced with
# trivial stubs that print a marker line. This isolates dispatch
# routing from per-command behavior.
#
# Story G.b.1 — v1.11.0 dispatcher refactor + legacy-flag catch.
#

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_BIN="$PYVE_ROOT/pyve.sh"

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # A stub harness: a wrapper bash script that defines stub functions
    # for every command handler, then sources pyve.sh's main() body.
    # We avoid actually running any real environment manipulation by
    # short-circuiting the handlers to print a marker and exit 0.
    #
    # The dispatcher itself lives in main() at the bottom of pyve.sh,
    # so we cannot easily source-and-call without triggering the
    # bottom-of-file `main "$@"` invocation. Instead we run pyve.sh
    # under a controlled HOME and CWD and rely on early-exit handlers
    # like --help / --version which don't touch the filesystem, plus
    # the legacy-flag catch which exits before any handler runs.
    #
    # For routing assertions on subcommands that *do* touch the
    # filesystem (init, purge, ...), we use a wrapper that intercepts
    # by setting PYVE_DISPATCH_TRACE=1 — a hook the refactored
    # dispatcher will honor by printing the resolved handler name and
    # exiting 0 before invoking it. This hook exists solely for tests.

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
# New subcommand routing
#============================================================

@test "dispatch: 'pyve init' routes to the init handler" {
    PYVE_DISPATCH_TRACE=1 run_pyve init
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:init"* ]]
}

@test "dispatch: 'pyve purge' routes to the purge handler" {
    PYVE_DISPATCH_TRACE=1 run_pyve purge
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:purge"* ]]
}

@test "dispatch: 'pyve python-version 3.12.0' is no longer a routable subcommand (Story J.d)" {
    # Pre-v2.3.0 this case arm delegated-with-warning to `python set`.
    # Story J.d ripped the alias; the dispatcher's *) arm now errors out.
    run_pyve python-version 3.12.0
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown command"* ]] || [[ "$output" == *"unknown"* ]]
}

@test "dispatch: 'pyve self install' routes to the install_self handler" {
    PYVE_DISPATCH_TRACE=1 run_pyve self install
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:self-install"* ]]
}

@test "dispatch: 'pyve self uninstall' routes to the uninstall_self handler" {
    PYVE_DISPATCH_TRACE=1 run_pyve self uninstall
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:self-uninstall"* ]]
}

@test "dispatch: 'pyve self' with no subcommand prints namespace help and exits 0" {
    run_pyve self
    [ "$status" -eq 0 ]
    # Strict marker line — appears ONLY in the self-namespace help block,
    # NEVER in top-level --help. If this assertion fails, the dispatcher
    # fell through to top-level help instead of printing the self help.
    [[ "$output" == *"Usage: pyve self <subcommand>"* ]]
    [[ "$output" == *"self install"* ]]
    [[ "$output" == *"self uninstall"* ]]
}

#============================================================
# Modifier flags still attach to renamed subcommands
#============================================================

@test "dispatch: 'pyve init --backend venv --no-direnv' routes to init with flags preserved" {
    PYVE_DISPATCH_TRACE=1 run_pyve init --backend venv --no-direnv
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:init"* ]]
    [[ "$output" == *"--backend"* ]]
    [[ "$output" == *"--no-direnv"* ]]
}

@test "dispatch: 'pyve purge --keep-testenv' routes to purge with flag preserved" {
    PYVE_DISPATCH_TRACE=1 run_pyve purge --keep-testenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:purge"* ]]
    [[ "$output" == *"--keep-testenv"* ]]
}

#============================================================
# Legacy flag catch — kept forever per Decision D3
#============================================================

@test "legacy: 'pyve --init' prints migration error and exits non-zero" {
    run_pyve --init
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --init' is no longer supported"* ]]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" == *"pyve --help"* ]]
}

@test "legacy: 'pyve --purge' prints migration error and exits non-zero" {
    run_pyve --purge
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --purge' is no longer supported"* ]]
    [[ "$output" == *"pyve purge"* ]]
}

@test "legacy: 'pyve --validate' prints migration error and exits non-zero" {
    run_pyve --validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --validate' is no longer supported"* ]]
    [[ "$output" == *"pyve check"* ]]
}

@test "legacy: 'pyve --install' prints migration error and exits non-zero" {
    run_pyve --install
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --install' is no longer supported"* ]]
    [[ "$output" == *"pyve self install"* ]]
}

@test "legacy: 'pyve --uninstall' prints migration error and exits non-zero" {
    run_pyve --uninstall
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --uninstall' is no longer supported"* ]]
    [[ "$output" == *"pyve self uninstall"* ]]
}

@test "legacy: 'pyve --python-version 3.12.0' prints migration error pointing at v2.0-canonical form" {
    run_pyve --python-version 3.12.0
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --python-version' is no longer supported"* ]]
    [[ "$output" == *"pyve python set"* ]]
}

#============================================================
# Legacy flag catches added in H.e.9 (v2.0.0)
#============================================================

@test "legacy: 'pyve --update' prints migration error and exits non-zero" {
    run_pyve --update
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --update' is no longer supported"* ]]
    [[ "$output" == *"pyve update"* ]]
}

@test "legacy: 'pyve --doctor' prints migration error and exits non-zero" {
    run_pyve --doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --doctor' is no longer supported"* ]]
    [[ "$output" == *"pyve check"* ]]
}

@test "legacy: 'pyve --status' prints migration error and exits non-zero" {
    run_pyve --status
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve --status' is no longer supported"* ]]
    [[ "$output" == *"pyve status"* ]]
}

@test "legacy: 'pyve init --update' prints migration error and does NOT proceed (H.e.9)" {
    run_pyve init --update
    [ "$status" -ne 0 ]
    [[ "$output" == *"'pyve init --update' is no longer supported"* ]]
    [[ "$output" == *"pyve update"* ]]
    # init must not proceed — no .pyve/ or .venv left behind in this fresh temp dir.
    [ ! -d .pyve ]
    [ ! -d .venv ]
}

#============================================================
# Version — v2.1.0 (H.f.7 starter env.yml scaffold feature;
# v2.0.1 was the H.f.5 release wrap)
#============================================================

@test "version: 'pyve --version' reports 2.2.1" {
    run_pyve --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.2.1"* ]]
}

#============================================================
# Short flag aliases dropped (Decision D1)
#============================================================

@test "legacy: '-i' short alias is no longer recognized" {
    run_pyve -i
    [ "$status" -ne 0 ]
    # Either the legacy-flag catch or the unknown-command path; both
    # must exit non-zero. We don't constrain the exact message here
    # so the implementation can pick whichever phrasing fits best.
}

@test "legacy: '-p' short alias is no longer recognized" {
    run_pyve -p
    [ "$status" -ne 0 ]
}

#============================================================
# Universal flags still work (regression guard)
#============================================================

@test "universal: 'pyve --help' still prints help and exits 0" {
    run_pyve --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve"* ]]
}

@test "universal: 'pyve --version' still prints version and exits 0" {
    run_pyve --version
    [ "$status" -eq 0 ]
}

@test "universal: 'pyve' with no args prints help and exits non-zero" {
    run_pyve
    [ "$status" -ne 0 ]
}
