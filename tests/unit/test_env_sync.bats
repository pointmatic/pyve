#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Story N.az.2 — `pyve env sync` leaf (black-box via `bash pyve.sh`).
#
# Discovers the project-guide env-dependencies spec (§4.0), diffs it
# against the current pyve.toml (the baseline), presents the changes, and
# on confirm reconciles pyve.toml via the tomlkit writer. Writes config
# ONLY — never materializes an env.
#
# These exercise the real toolchain-interpreter seam, so they need an
# interpreter carrying PyYAML+tomlkit; point PYVE_PYTHON at one (tomlkit is
# NOT in the dev checkout) and the tests `skip` otherwise. Non-interactive
# (no TTY) so the default verdicts apply directly: non-destructive default
# Y (applied), destructive default N (declined).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_BIN="$PYVE_ROOT/pyve.sh"
    # The seam honors PYVE_PYTHON first; require it to carry both libs.
    # Resolve it BEFORE cd'ing into the sandbox (asdf has no version pinned
    # there, so a bare `python` would fail with status 126).
    PY="${PYVE_PYTHON:-$(python -c 'import sys; print(sys.executable)')}"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_libs_or_skip() {
    "$PY" -c 'import yaml, tomlkit' 2>/dev/null \
        || skip "PyYAML+tomlkit not available (set PYVE_PYTHON)"
}

run_sync() {
    PYVE_PYTHON="$PY" run bash "$PYVE_BIN" env sync "$@"
}

_write_toml() {
    cat > "$TEST_DIR/pyve.toml" <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[plugins.python]

[env.root]
purpose = "utility"

[env.testenv]
purpose = "test"
default = true
EOF
}

# Default spec path is docs/specs/env-dependencies.md. $1 = indented envs body.
_write_spec() {
    mkdir -p "$TEST_DIR/docs/specs"
    cat > "$TEST_DIR/docs/specs/env-dependencies.md" <<EOF
# env-dependencies.md

## 4. Environment Inventory

### 4.0 Environment Surface Enumeration

\`\`\`yaml
spec_version: "3.0"
project: demo
envs:
$1
\`\`\`

## 5. Specs
EOF
}

@test "env sync: clean spec is a no-op (pyve.toml unchanged)" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true'
    local before; before="$(cat "$TEST_DIR/pyve.toml")"
    run_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"sync"* || "$output" == *"nothing"* ]]
    [ "$(cat "$TEST_DIR/pyve.toml")" == "$before" ]
}

@test "env sync: additive change applies by default (non-interactive Y)" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp
    backend: venv'
    run_sync
    [ "$status" -eq 0 ]
    grep -qF '[env.sandbox]' "$TEST_DIR/pyve.toml"
}

@test "env sync: advisory backend (none) is written but NOT materialized" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  docs:
    purpose: utility
    backend: none'
    run_sync
    [ "$status" -eq 0 ]
    grep -qF '[env.docs]' "$TEST_DIR/pyve.toml"
    # Config-only: no env was materialized on disk.
    [ ! -d "$TEST_DIR/.pyve/envs/docs" ]
}

@test "env sync: destructive drop is declined by default (pyve.toml unchanged)" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility'
    local before; before="$(cat "$TEST_DIR/pyve.toml")"
    run_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"destructive"* ]]
    # testenv survives — destructive default is N.
    grep -qF '[env.testenv]' "$TEST_DIR/pyve.toml"
    [ "$(cat "$TEST_DIR/pyve.toml")" == "$before" ]
}

@test "env sync --force: destructive drop is applied" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility'
    run_sync --force
    [ "$status" -eq 0 ]
    run grep -F '[env.testenv]' "$TEST_DIR/pyve.toml"
    [ "$status" -eq 1 ]
}

@test "env sync --dry-run: shows the diff but never writes" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp'
    local before; before="$(cat "$TEST_DIR/pyve.toml")"
    run_sync --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"sandbox"* ]]
    [ "$(cat "$TEST_DIR/pyve.toml")" == "$before" ]
}

@test "env sync: missing spec is a graceful no-op" {
    _libs_or_skip
    _write_toml
    # No docs/specs/env-dependencies.md written.
    run_sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to sync"* || "$output" == *"No env-dependencies"* ]]
}

@test "env sync: toolchain libs absent -> exit 3 with 'pyve self install' hint" {
    "$PY" -m venv --without-pip "$TEST_DIR/nolibs" 2>/dev/null || skip "venv unavailable"
    _write_toml
    _write_spec '  testenv:
    purpose: test'
    PYVE_PYTHON="$TEST_DIR/nolibs/bin/python" run bash "$PYVE_BIN" env sync
    [ "$status" -eq 3 ]
    [[ "$output" == *"pyve self install"* ]]
}
