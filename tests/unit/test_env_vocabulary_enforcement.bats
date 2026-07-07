#!/usr/bin/env bats
# bats file_tags=manifest
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# trichotomy enforcement: unknown → hard error + abort.
#
# Part A (pyve.toml validation, pure stdlib): pyve_toml_helper.py rejects an
# unknown value on any closed axis (exit 2); advisory and implemented values
# pass.
# Part B (pyve env sync ingestion, needs PyYAML+tomlkit): an unknown value or
# unrecognized field in §4 aborts the sync with no pyve.toml write. Point
# PYVE_PYTHON at a libs-carrying interpreter; tests `skip` otherwise.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_BIN="$PYVE_ROOT/pyve.sh"
    HELPER="$PYVE_ROOT/lib/pyve_toml_helper.py"
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

# A pyve.toml with one extra [env.x] whose body is $1 (indented TOML lines).
_toml_with_env_x() {
    cat > "$TEST_DIR/pyve.toml" <<EOF
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"

[env.x]
$1
EOF
}

# A §4 spec doc with one [env.x]-shaped entry; \$1 = indented YAML under x.
_spec_with_env_x() {
    mkdir -p "$TEST_DIR/docs/specs"
    cat > "$TEST_DIR/docs/specs/env-dependencies.md" <<EOF
# spec

## 4. Inventory

### 4.0 Environment Surface Enumeration

\`\`\`yaml
project: demo
envs:
  root:
    purpose: utility
  x:
$1
\`\`\`

## 5. Specs
EOF
}

# ── Part A: pyve.toml validation (pure stdlib) ───────────────────────

@test "validate: unknown backend → exit 2" {
    _toml_with_env_x 'purpose = "utility"
backend = "rocket"'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown backend"* ]]
    [[ "$output" == *"rocket"* ]]
}

@test "validate: unknown language → exit 2" {
    _toml_with_env_x 'purpose = "utility"
languages = ["python", "cobol"]'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown languages"* ]]
    [[ "$output" == *"cobol"* ]]
}

@test "validate: unknown framework → exit 2" {
    _toml_with_env_x 'purpose = "test"
frameworks = ["jest", "qunit"]'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown frameworks"* ]]
    [[ "$output" == *"qunit"* ]]
}

@test "validate: unknown packaging → exit 2" {
    _toml_with_env_x 'purpose = "run"
packaging = "docker"'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown packaging"* ]]
}

@test "validate: unknown app_type → exit 2" {
    _toml_with_env_x 'purpose = "run"
app_type = "spa"'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown app_type"* ]]
}

@test "validate: advisory values are accepted → exit 0" {
    _toml_with_env_x 'purpose = "test"
backend = "homebrew"
languages = ["rust", "ruby"]
frameworks = ["pytest", "ruff"]
packaging = "container"
app_type = "cli"'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 0 ]
}

@test "validate: implemented values are accepted → exit 0" {
    _toml_with_env_x 'purpose = "test"
backend = "venv"
languages = ["python", "typescript"]
frameworks = ["sveltekit"]'
    run "$PY" "$HELPER" "$TEST_DIR/pyve.toml"
    [ "$status" -eq 0 ]
}

# ── Part B: pyve env sync ingestion (needs libs) ─────────────────────

@test "env sync: unknown value in §4 aborts; pyve.toml not written" {
    _libs_or_skip
    # No pyve.toml yet — prove the abort prevents any write.
    _spec_with_env_x '    purpose: utility
    backend: rocket'
    PYVE_PYTHON="$PY" run bash "$PYVE_BIN" env sync
    [ "$status" -ne 0 ]
    [[ "$output" == *"backend"* ]]
    [[ "$output" == *"rocket"* ]]
    [ ! -f "$TEST_DIR/pyve.toml" ]
}

@test "env sync: unrecognized §4 field aborts; pyve.toml not written" {
    _libs_or_skip
    _spec_with_env_x '    purpose: utility
    bogus_field: 1'
    PYVE_PYTHON="$PY" run bash "$PYVE_BIN" env sync
    [ "$status" -ne 0 ]
    [[ "$output" == *"bogus_field"* ]]
    [ ! -f "$TEST_DIR/pyve.toml" ]
}

@test "env sync: valid advisory spec is accepted (sync proceeds, writes)" {
    _libs_or_skip
    _spec_with_env_x '    purpose: utility
    backend: homebrew
    app_type: cli'
    PYVE_PYTHON="$PY" run bash "$PYVE_BIN" env sync
    [ "$status" -eq 0 ]
    grep -qF '[env.x]' "$TEST_DIR/pyve.toml"
}
