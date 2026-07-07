#!/usr/bin/env bats
# bats file_tags=manifest
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/pyve_env_spec_helper.py reads §4.0 of the
# env-dependencies doc and projects each env to the pyve.toml-projectable
# shape, emitting JSON. Tested by shelling out to the helper (the way the
# Bash seam invokes it). The projection tests need a yaml-capable
# interpreter; they `skip` when PyYAML is absent (repo precedent).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    HELPER="$PYVE_ROOT/lib/pyve_env_spec_helper.py"
    # A working interpreter captured before any cd (mirrors test_manifest).
    PY="$(python -c 'import sys; print(sys.executable)')"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    _write_fixture
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_yaml_or_skip() {
    "$PY" -c 'import yaml' 2>/dev/null || skip "PyYAML not available in the test interpreter"
}

# A §4-structured doc: §4.0 machine YAML block + §4.1 table + §5 prose
# (the latter two must be ignored). Quoted heredoc → literal backticks.
_write_fixture() {
    cat > "$TEST_DIR/env-dependencies.md" <<'EOF'
# env-dependencies.md - test

## 3. Backend Catalog

(prose — no yaml here)

## 4. Environment Inventory

### 4.0 Environment Surface Enumeration

```yaml
spec_version: "3.0"
project: testproj
envs:
  root:
    purpose: utility
    backend: venv
    default: false
    path: "."
    languages: [python]
    frameworks: [none]
    packaging: none
  testenv:
    purpose: test
    backend: venv
    default: true
    frameworks: [pytest]
    languages: [python]
  sandbox:
    purpose: temp
    backend: none
  minimal:
    purpose: utility
    backend: venv
```

### 4.1 Inventory Table

| # | Environment | Purpose |
|---|-------------|---------|
| 0 | root        | utility |

## 5. Environment Specifications

(human prose — never parsed)
EOF
}

@test "helper: projects each env to the projectable subset" {
    _yaml_or_skip
    run "$PY" "$HELPER" "$TEST_DIR/env-dependencies.md"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert d["spec_version"] == "3.0", d["spec_version"]
assert d["project"] == "testproj", d["project"]
e = d["envs"]
assert set(e) == {"root", "testenv", "sandbox", "minimal"}, set(e)
assert e["root"]["purpose"] == "utility"
assert e["root"]["backend"] == "venv"
assert e["root"]["languages"] == ["python"]
assert e["testenv"]["default"] is True
assert e["testenv"]["frameworks"] == ["pytest"]
' "$output"
}

@test "helper: advisory backend (none) passes through unchanged (permissive)" {
    _yaml_or_skip
    run "$PY" "$HELPER" "$TEST_DIR/env-dependencies.md"
    assert_status_equals 0
    "$PY" -c '
import json, sys
d = json.loads(sys.argv[1])
assert d["envs"]["sandbox"]["backend"] == "none", d["envs"]["sandbox"]
' "$output"
}

@test "helper: default-fills missing optional fields" {
    _yaml_or_skip
    run "$PY" "$HELPER" "$TEST_DIR/env-dependencies.md"
    assert_status_equals 0
    "$PY" -c '
import json, sys
m = json.loads(sys.argv[1])["envs"]["minimal"]
assert m["path"] == ".", m
assert m["default"] is False, m
assert m["languages"] == [], m
assert m["frameworks"] == [], m
assert m["packaging"] == "none", m
' "$output"
}

@test "helper: §4.1 table and §5 prose are ignored (only §4.0 block parsed)" {
    _yaml_or_skip
    run "$PY" "$HELPER" "$TEST_DIR/env-dependencies.md"
    assert_status_equals 0
    # 4 envs, not polluted by the table row or §5 prose.
    "$PY" -c 'import json,sys; assert len(json.loads(sys.argv[1])["envs"]) == 4' "$output"
}

@test "helper: absent spec file → exit 2" {
    _yaml_or_skip
    run "$PY" "$HELPER" "$TEST_DIR/does-not-exist.md"
    assert_status_equals 2
}

@test "helper: no §4.0 YAML block → exit 4" {
    _yaml_or_skip
    printf '# doc\n\n## 4. Environment Inventory\n\n(no yaml block)\n\n## 5. Specs\n' \
        > "$TEST_DIR/no-block.md"
    run "$PY" "$HELPER" "$TEST_DIR/no-block.md"
    assert_status_equals 4
}

@test "helper: PyYAML absent → exit 3 (distinct from parse/file errors)" {
    # A fresh venv has no PyYAML → import yaml fails → exit 3.
    "$PY" -m venv --without-pip "$TEST_DIR/noyaml" 2>/dev/null || skip "venv unavailable"
    run "$TEST_DIR/noyaml/bin/python" "$HELPER" "$TEST_DIR/env-dependencies.md"
    assert_status_equals 3
    [[ "$output" == *"pyve self install"* ]]
}
