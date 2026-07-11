#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Staleness detection for the hosted tools (lib/staleness.sh): best-effort
# latest-version lookups — project-guide via PyPI JSON, pyve via the raw
# Homebrew-tap formula — rendered as INFO-ONLY lines in `pyve check`'s
# [pyve] section with the install-source-correct upgrade command.
#
# The network model is the P.ac spike's recorded outcome (plan §8.3):
# bounded silent curl; probe suppressed by --offline / PYVE_NO_NETWORK=1,
# the CI env var, a non-interactive stdout (hints are for humans — this
# also keeps every scripted/test `check` run offline by construction),
# or an unexpired cache; 24h mtime TTL under XDG_CACHE_HOME; a failed
# fetch never overwrites a cached value; a network failure can never
# change the exit code.

load ../helpers/test_helper

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/staleness.sh"

    TEST_DIR="$(mktemp -d)"
    export HOME="$TEST_DIR/home"
    export XDG_CACHE_HOME="$TEST_DIR/home/.cache"
    export XDG_DATA_HOME="$TEST_DIR/home/.local/share"
    mkdir -p "$HOME"
    unset PYVE_NO_NETWORK PYVE_PYTHON PYVE_PROJECT_GUIDE_BIN
    unset CI
    export DEFAULT_PYTHON_VERSION="3.12.13"
    cd "$TEST_DIR"
    export NO_COLOR=1
    # Unit tests drive the module as an interactive human run; the
    # non-TTY suppression is asserted explicitly where it is the subject.
    _staleness_interactive() { return 0; }
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fetch stub: record the call, serve canned bodies per URL.
_stub_fetch_ok() {
    _staleness_fetch() {
        echo "fetched $1" >> "$TEST_DIR/fetch.log"
        case "$1" in
            *pypi.org*)  printf '{"info":{"name":"project-guide","version":"9.9.9"}}' ;;
            *pyve.rb*)   printf 'url "https://github.com/pointmatic/pyve/archive/refs/tags/v9.8.7.tar.gz"' ;;
        esac
    }
}

_stub_fetch_fail() {
    _staleness_fetch() {
        echo "fetched $1" >> "$TEST_DIR/fetch.log"
        printf ''
    }
}

# ============================================================
# version compare
# ============================================================

@test "ver_gt: numeric, not lexicographic" {
    _staleness_ver_gt "3.10.0" "3.9.1"
    ! _staleness_ver_gt "3.9.1" "3.10.0"
    ! _staleness_ver_gt "3.1.0" "3.1.0"
    _staleness_ver_gt "2.15.0" "2.9"
    ! _staleness_ver_gt "2.9" "2.15.0"
}

# ============================================================
# staleness_latest — cache, TTL, suppression
# ============================================================

@test "latest: fresh cache short-circuits the fetch" {
    mkdir -p "$XDG_CACHE_HOME/pyve/latest"
    printf '5.5.5' > "$XDG_CACHE_HOME/pyve/latest/project-guide"
    _stub_fetch_ok
    run staleness_latest project-guide
    [ "$output" = "5.5.5" ]
    [ ! -f "$TEST_DIR/fetch.log" ]
}

@test "latest: expired cache + successful fetch → new value, cache updated" {
    mkdir -p "$XDG_CACHE_HOME/pyve/latest"
    printf '5.5.5' > "$XDG_CACHE_HOME/pyve/latest/project-guide"
    export PYVE_STALENESS_TTL_MINUTES=0
    _stub_fetch_ok
    run staleness_latest project-guide
    [ "$output" = "9.9.9" ]
    [ "$(cat "$XDG_CACHE_HOME/pyve/latest/project-guide")" = "9.9.9" ]
}

@test "latest: expired cache + failed fetch → empty, cached value preserved" {
    mkdir -p "$XDG_CACHE_HOME/pyve/latest"
    printf '5.5.5' > "$XDG_CACHE_HOME/pyve/latest/project-guide"
    export PYVE_STALENESS_TTL_MINUTES=0
    _stub_fetch_fail
    run staleness_latest project-guide
    [ -z "$output" ]
    [ "$(cat "$XDG_CACHE_HOME/pyve/latest/project-guide")" = "5.5.5" ]
}

@test "latest: PYVE_NO_NETWORK=1 with no cache → empty, no fetch attempted" {
    export PYVE_NO_NETWORK=1
    _stub_fetch_ok
    run staleness_latest project-guide
    [ -z "$output" ]
    [ ! -f "$TEST_DIR/fetch.log" ]
}

@test "latest: PYVE_NO_NETWORK=1 with a fresh cache → cached value, still no fetch" {
    export PYVE_NO_NETWORK=1
    mkdir -p "$XDG_CACHE_HOME/pyve/latest"
    printf '4.4.4' > "$XDG_CACHE_HOME/pyve/latest/pyve"
    _stub_fetch_ok
    run staleness_latest pyve
    [ "$output" = "4.4.4" ]
    [ ! -f "$TEST_DIR/fetch.log" ]
}

@test "latest: the CI env var suppresses the fetch" {
    export CI=true
    _stub_fetch_ok
    run staleness_latest project-guide
    [ -z "$output" ]
    [ ! -f "$TEST_DIR/fetch.log" ]
}

@test "latest: non-interactive stdout suppresses the fetch (hints are for humans)" {
    _staleness_interactive() { return 1; }
    _stub_fetch_ok
    run staleness_latest project-guide
    [ -z "$output" ]
    [ ! -f "$TEST_DIR/fetch.log" ]
}

@test "latest: parses the PyPI JSON and the tap formula tag" {
    _stub_fetch_ok
    run staleness_latest project-guide
    [ "$output" = "9.9.9" ]
    rm -f "$TEST_DIR/fetch.log"
    run staleness_latest pyve
    [ "$output" = "9.8.7" ]
}

# ============================================================
# staleness_hint_lines — comparison + remediation routing
# ============================================================

_fixture_hosted_pg() {
    local pg
    pg="$(pyve_toolchain_venv_dir)/bin/project-guide"
    mkdir -p "$(dirname "$pg")"
    printf '#!/usr/bin/env bash\necho "project-guide 2.15.1"\n' > "$pg"
    chmod +x "$pg"
}

@test "hints: newer project-guide → line + 'pyve self provision'" {
    _fixture_hosted_pg
    _stub_fetch_ok
    VERSION="9.8.7" run staleness_hint_lines
    [ "$status" -eq 0 ]
    [[ "$output" == *"project-guide 9.9.9 is available"* ]]
    [[ "$output" == *"2.15.1"* ]]
    [[ "$output" == *"pyve self provision"* ]]
}

@test "hints: newer pyve on a Homebrew install → brew upgrade hint" {
    _stub_fetch_ok
    detect_install_source() { printf 'homebrew'; }
    VERSION="3.1.0" run staleness_hint_lines
    [[ "$output" == *"pyve 9.8.7 is available"* ]]
    [[ "$output" == *"brew upgrade pointmatic/tap/pyve"* ]]
}

@test "hints: newer pyve on a source install → git pull hint" {
    _stub_fetch_ok
    detect_install_source() { printf 'source'; }
    VERSION="3.1.0" run staleness_hint_lines
    [[ "$output" == *"pyve 9.8.7 is available"* ]]
    [[ "$output" == *"git pull && pyve self install"* ]]
}

@test "hints: up to date → silent" {
    _fixture_hosted_pg
    _staleness_fetch() {
        case "$1" in
            *pypi.org*) printf '{"info":{"version":"2.15.1"}}' ;;
            *pyve.rb*)  printf 'url ".../refs/tags/v3.1.0.tar.gz"' ;;
        esac
    }
    VERSION="3.1.0" run staleness_hint_lines
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "hints: project-managed project-guide → no project-guide hint" {
    _fixture_hosted_pg
    _stub_fetch_ok
    project_guide_deps_source() { printf 'pyproject.toml'; }
    VERSION="9.8.7" run staleness_hint_lines
    [[ "$output" != *"project-guide"* ]]
}

@test "hints: offline → silent, returns 0 (exit code can never change)" {
    _fixture_hosted_pg
    _stub_fetch_fail
    VERSION="0.0.1" run staleness_hint_lines
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================
# pyve check surface
# ============================================================

@test "check --offline is accepted and forces PYVE_NO_NETWORK" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n\n[env.root]\nbackend = "none"\n' > pyve.toml
    run "$PYVE_SCRIPT" check --offline
    [[ "$output" != *"unknown flag"* ]]
    [[ "$output" != *"Unknown flag"* ]]
}

@test "check --help documents --offline and PYVE_NO_NETWORK" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--offline"* ]]
    [[ "$output" == *"PYVE_NO_NETWORK"* ]]
}
