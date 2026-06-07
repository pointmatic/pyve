#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# soft migration banner on `pyve <cmd>` in v2-configured
# projects.
#
# Black-box tests: subprocess `bash pyve.sh ...` (matches the
# test_cli_dispatch.bats pattern) so the pre-dispatch hook is
# exercised end-to-end with the real argv-parsing path in main().
#
# Memoization is per-(parent-shell PID, project-root) so two
# consecutive invocations in the *same* bats test see the banner
# fire only once; the PPID hash differs between bats tests because
# each @test runs in a fresh shell.

bats_require_minimum_version 1.5.0

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_BIN="$PYVE_ROOT/pyve.sh"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    # Confine the banner sentinel to the test sandbox so we get
    # hermetic memoization state per @test.
    export HOME="$TEST_DIR/home"
    export XDG_STATE_HOME="$TEST_DIR/state"
    mkdir -p "$HOME" "$XDG_STATE_HOME"
    # bats's `run` spawns a fresh subshell per invocation, so $PPID
    # in `bash pyve.sh ...` differs between two `run` calls within
    # one @test. Override the session key explicitly so memoization
    # is deterministic across consecutive `run` calls. The override
    # path is documented on `_pyve_v2_banner_sentinel_path` in pyve.sh.
    export PYVE_V2_BANNER_SESSION="bats-$$"
    export NO_COLOR=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# ----- fixtures ---------------------------------------------------

_write_v2_config() {
    mkdir -p .pyve
    cat > .pyve/config <<'EOF'
pyve_version: "2.8.0"
backend: venv
venv:
  directory: .venv
python:
  version: 3.13.7
EOF
}

_write_v3_manifest() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
EOF
}

run_pyve() {
    PYVE_DISPATCH_TRACE=1 run bash "$PYVE_BIN" "$@"
}

# ----- the banner fires on v2 sources -----------------------------

@test "banner: fires on v2-configured project (subcommand)" {
    _write_v2_config
    run_pyve check
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pyve v3 detected v2 configuration"* ]]
    [[ "$output" == *"pyve self migrate"* ]]
    [[ "$output" == *"v3.1"* ]]
}

@test "banner: text matches the documented N.h wording" {
    _write_v2_config
    run_pyve check
    [ "$status" -eq 0 ]
    # Documented banner: "Pyve v3 detected v2 configuration. Run
    # 'pyve self migrate' to upgrade — legacy support ends at v3.1."
    [[ "$output" == *"Pyve v3 detected v2 configuration"* ]]
    [[ "$output" == *"legacy support ends at v3.1"* ]]
}

@test "banner: fires when only [tool.pyve.testenvs.*] in pyproject (no .pyve/config)" {
    cat > pyproject.toml <<'EOF'
[project]
name = "demo"

[tool.pyve.testenvs.testenv]
backend = "venv"
EOF
    run_pyve check
    [[ "$output" == *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: fires when only .pyve/testenvs/ on disk (no config / no pyproject block)" {
    mkdir -p .pyve/testenvs/testenv/venv
    run_pyve check
    [[ "$output" == *"Pyve v3 detected v2 configuration"* ]]
}

# ----- the banner does NOT fire on v3 / bare / informational ------

@test "banner: does NOT fire in a v3-configured project (pyve.toml present)" {
    _write_v3_manifest
    _write_v2_config  # legacy sources also present; pyve.toml short-circuits
    run_pyve check
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire in a bare directory (no config, no pyve.toml)" {
    run_pyve check
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire under PYVE_QUIET=1" {
    _write_v2_config
    PYVE_QUIET=1 PYVE_DISPATCH_TRACE=1 run bash "$PYVE_BIN" check
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire for --help" {
    _write_v2_config
    run bash "$PYVE_BIN" --help
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire for --version" {
    _write_v2_config
    run bash "$PYVE_BIN" --version
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire for --config" {
    _write_v2_config
    run bash "$PYVE_BIN" --config
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire for 'pyve self install'" {
    _write_v2_config
    run_pyve self install
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: does NOT fire for 'pyve self migrate'" {
    _write_v2_config
    run_pyve self migrate --help
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

# ----- memoization ------------------------------------------------

@test "banner: fires once per shell session (second call in same test is silent)" {
    _write_v2_config
    # First call — banner expected.
    PYVE_DISPATCH_TRACE=1 run bash "$PYVE_BIN" check
    [[ "$output" == *"Pyve v3 detected v2 configuration"* ]]
    # Second call from the SAME bats shell — same PPID → sentinel
    # already on disk → no banner.
    PYVE_DISPATCH_TRACE=1 run bash "$PYVE_BIN" check
    [[ "$output" != *"Pyve v3 detected v2 configuration"* ]]
}

@test "banner: sentinel written under XDG_STATE_HOME/pyve/" {
    _write_v2_config
    run_pyve check
    [ -d "$XDG_STATE_HOME/pyve" ]
    # At least one sentinel file with the expected prefix.
    local matches
    matches="$(find "$XDG_STATE_HOME/pyve" -name 'migrate-banner-*' -type f | wc -l | tr -d ' ')"
    [ "$matches" -ge 1 ]
}

@test "banner: sentinel key differs across cwd (different projects in same shell)" {
    _write_v2_config
    run_pyve check
    [[ "$output" == *"Pyve v3 detected v2 configuration"* ]]

    # Second project — different cwd → different hash → banner fires.
    local second_dir; second_dir="$(mktemp -d)"
    (
        cd "$second_dir"
        mkdir -p .pyve
        cp "$TEST_DIR/.pyve/config" .pyve/config
        PYVE_DISPATCH_TRACE=1 bash "$PYVE_BIN" check 2>&1
    ) > /tmp/n_h_second.out
    grep -q "Pyve v3 detected v2 configuration" /tmp/n_h_second.out
    rm -rf "$second_dir" /tmp/n_h_second.out
}
