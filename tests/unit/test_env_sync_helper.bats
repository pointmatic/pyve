#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/pyve_env_sync_helper.py computes a stateless diff
# between §4.0 of the env-dependencies doc and the current pyve.toml, and
# applies the reconcile via tomlkit (round-trip-preserving). Tested by
# shelling out to the helper (the way the Bash seam invokes it). The
# engine needs a yaml+tomlkit-capable interpreter; tests `skip` when either
# is absent (N.az.1 precedent). Point PYVE_PYTHON at such an interpreter to
# exercise them (tomlkit is NOT in the dev checkout).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    HELPER="$PYVE_ROOT/lib/pyve_env_sync_helper.py"
    # Prefer PYVE_PYTHON if it carries both libs; else the test interpreter.
    PY="${PYVE_PYTHON:-$(python -c 'import sys; print(sys.executable)')}"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_libs_or_skip() {
    "$PY" -c 'import yaml, tomlkit' 2>/dev/null \
        || skip "PyYAML+tomlkit not available in the test interpreter (set PYVE_PYTHON)"
}

# A §4-structured spec doc. <body> is the YAML envs mapping, indented.
_write_spec() {
    cat > "$TEST_DIR/env-dependencies.md" <<EOF
# env-dependencies.md - test

## 4. Environment Inventory

### 4.0 Environment Surface Enumeration

\`\`\`yaml
spec_version: "3.0"
project: demo
envs:
$1
\`\`\`

## 5. Environment Specifications

(prose — never parsed)
EOF
}

# A baseline pyve.toml with root + testenv (the canonical init shape).
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

#------------------------------------------------------------
# diff — JSON surface
#------------------------------------------------------------

@test "diff: clean when spec matches the current pyve.toml" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true'
    run "$PY" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert d["clean"] is True, d
assert d["added"] == {}, d
assert d["changed"] == {}, d
assert d["dropped"] == {}, d
assert d["destructive"] is False, d
' "$output"
}

@test "diff: additive env appears in added, non-destructive" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp
    backend: none'
    run "$PY" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert "sandbox" in d["added"], d
assert d["added"]["sandbox"]["purpose"] == "temp", d
assert d["clean"] is False, d
assert d["destructive"] is False, d
' "$output"
}

@test "diff: dropping a declared env is destructive" {
    _libs_or_skip
    _write_toml
    # Spec omits testenv → it is dropped.
    _write_spec '  root:
    purpose: utility'
    run "$PY" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert "testenv" in d["dropped"], d
assert d["destructive"] is True, d
' "$output"
}

@test "diff: a concrete backend flip is destructive; adding a backend is not" {
    _libs_or_skip
    _write_toml
    # root: None -> venv (additive backend, NOT a flip).
    # testenv: implicit None backend vs spec venv (additive, NOT a flip).
    _write_spec '  root:
    purpose: utility
    backend: venv
  testenv:
    purpose: test
    default: true
    backend: venv'
    run "$PY" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert "root" in d["changed"], d
assert d["destructive"] is False, "adding a backend is not destructive: %r" % d
' "$output"
}

@test "diff: venv->conda is a destructive flip" {
    _libs_or_skip
    cat > "$TEST_DIR/pyve.toml" <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.testenv]
purpose = "test"
backend = "venv"
EOF
    _write_spec '  testenv:
    purpose: test
    backend: conda'
    run "$PY" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert "testenv" in d["changed"], d
assert d["destructive"] is True, d
' "$output"
}

#------------------------------------------------------------
# diff --human — exit-code verdict surface (what the Bash seam branches on)
#------------------------------------------------------------

@test "diff --human: clean -> exit 0" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true'
    run "$PY" "$HELPER" diff --human "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
}

@test "diff --human: non-destructive changes -> exit 10" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp'
    run "$PY" "$HELPER" diff --human "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 10
    assert_output_contains "sandbox"
}

@test "diff --human: destructive changes -> exit 11" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility'
    run "$PY" "$HELPER" diff --human "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 11
    assert_output_contains "testenv"
}

#------------------------------------------------------------
# apply — tomlkit reconcile, round-trip preserving
#------------------------------------------------------------

@test "apply: additive env is written; re-diff is clean" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp
    backend: none'
    run "$PY" "$HELPER" apply "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    # The new table is a nested header, not an inline table.
    assert_file_contains "$TEST_DIR/pyve.toml" "[env.sandbox]"
    run grep -F 'env = {' "$TEST_DIR/pyve.toml"
    assert_status_equals 1
    # Idempotent: applying made the project clean.
    run "$PY" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    "$PY" -c 'import json,sys; assert json.loads(sys.argv[1])["clean"] is True, sys.argv[1]' "$output"
}

@test "apply: preserves [project] and [plugins.*] and drops removed envs" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility'
    run "$PY" "$HELPER" apply "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    assert_file_contains "$TEST_DIR/pyve.toml" '[project]'
    assert_file_contains "$TEST_DIR/pyve.toml" '[plugins.python]'
    assert_file_contains "$TEST_DIR/pyve.toml" '[env.root]'
    run grep -F '[env.testenv]' "$TEST_DIR/pyve.toml"
    assert_status_equals 1
}

@test "apply: into a project with no pyve.toml creates it with nested env headers" {
    _libs_or_skip
    _write_spec '  testenv:
    purpose: test
    default: true'
    run "$PY" "$HELPER" apply "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 0
    assert_file_contains "$TEST_DIR/pyve.toml" '[env.testenv]'
    run grep -F 'env = {' "$TEST_DIR/pyve.toml"
    assert_status_equals 1
}

#------------------------------------------------------------
# error surfaces (aligned with pyve_env_spec_helper exit codes)
#------------------------------------------------------------

@test "diff: spec doc not found -> exit 2" {
    _libs_or_skip
    _write_toml
    run "$PY" "$HELPER" diff "$TEST_DIR/missing.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 2
}

@test "diff: no §4.0 YAML block -> exit 4" {
    _libs_or_skip
    _write_toml
    printf '# doc\n\n## 4. Inventory\n\n(no yaml)\n\n## 5. Specs\n' > "$TEST_DIR/no-block.md"
    run "$PY" "$HELPER" diff "$TEST_DIR/no-block.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 4
}

@test "diff: PyYAML/tomlkit absent -> exit 3" {
    "$PY" -m venv --without-pip "$TEST_DIR/nolibs" 2>/dev/null || skip "venv unavailable"
    _write_toml
    _write_spec '  testenv:
    purpose: test'
    run "$TEST_DIR/nolibs/bin/python" "$HELPER" diff "$TEST_DIR/env-dependencies.md" "$TEST_DIR/pyve.toml"
    assert_status_equals 3
    [[ "$output" == *"pyve self install"* ]]
}
