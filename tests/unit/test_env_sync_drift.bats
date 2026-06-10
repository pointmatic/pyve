#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# `pyve check` env-spec drift surface.
#
# A spec-ahead project (pyve.toml lags the project-guide env-dependencies
# §4.0 surface) is a LEGITIMATE steady state, so the composer surfaces drift
# at WARN severity (process exit 0), never error. Drift is a project-level
# check — not owned by any plugin — so it lives in lib/check_composer.sh.
#
# Needs a PyYAML+tomlkit interpreter to compute the diff; point PYVE_PYTHON
# at one and the tests `skip` otherwise.
#============================================================

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/check_composer.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/project_guide.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="${PYVE_PYTHON:-$(python -c 'import sys; print(sys.executable)')}"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

_libs_or_skip() {
    "$PYVE_PYTHON" -c 'import yaml, tomlkit' 2>/dev/null \
        || skip "PyYAML+tomlkit not available (set PYVE_PYTHON)"
}

_write_toml() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"

[env.testenv]
purpose = "test"
default = true
EOF
}

_write_spec() {
    mkdir -p docs/specs
    cat > docs/specs/env-dependencies.md <<EOF
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

@test "drift check: warn (rc 2) + remediation hint when spec is ahead" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp'
    run _compose_check_env_spec_drift
    [ "$status" -eq 2 ]
    [[ "$output" == *"sandbox"* ]]
    [[ "$output" == *"pyve env sync"* ]]
}

@test "drift check: no section (rc 0, empty) when in sync" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true'
    run _compose_check_env_spec_drift
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "drift check: no section when no spec exists" {
    _libs_or_skip
    _write_toml
    run _compose_check_env_spec_drift
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "drift check: no section when pyve.toml is absent" {
    run _compose_check_env_spec_drift
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── e2e: the composed `pyve check` exit semantics ───────────────────

@test "compose_check: env-spec drift is warn-only (process exit 0)" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true
  sandbox:
    purpose: temp'
    # No plugins active → the only contribution is the env-spec drift warn.
    plugin_list_active() { return 0; }
    manifest_get_plugin_path() { printf '.'; }
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"[env-spec]"* ]]
    [[ "$output" == *"warnings"* ]]
}

@test "compose_check: no env-spec section when in sync" {
    _libs_or_skip
    _write_toml
    _write_spec '  root:
    purpose: utility
  testenv:
    purpose: test
    default: true'
    plugin_list_active() { return 0; }
    manifest_get_plugin_path() { printf '.'; }
    run compose_check
    [ "$status" -eq 0 ]
    [[ "$output" != *"[env-spec]"* ]]
}
