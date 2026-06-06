#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Story N.az.1 — toolchain PyYAML provisioning + the env-spec Bash seam:
#   - `pyve self install` pip-installs pyyaml into the toolchain venv
#     (best-effort), via _self_install_toolchain_deps
#   - pyve_toolchain_has_pyyaml reports interpreter capability
#   - _env_read_spec_json (lib/commands/env.sh) runs the helper via the
#     toolchain interpreter, with a precise PyYAML-absent error (exit 3)
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/ui/run.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"

    TEST_DIR="$(mktemp -d)"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    PY_WITH_YAML="$(python -c 'import sys; print(sys.executable)')"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fake toolchain venv whose pip logs its args. $1 = "ok" | "fail".
_make_venv_pip() {
    local mode="${1:-ok}" bin
    bin="$(pyve_toolchain_venv_dir)/bin"
    mkdir -p "$bin"
    if [[ "$mode" == "fail" ]]; then
        printf '#!/bin/sh\necho "$@" >> "%s/pip.log"\nexit 1\n' "$TEST_DIR" > "$bin/pip"
    else
        printf '#!/bin/sh\necho "$@" >> "%s/pip.log"\nexit 0\n' "$TEST_DIR" > "$bin/pip"
    fi
    chmod +x "$bin/pip"
}

#------------------------------------------------------------
# Provisioning
#------------------------------------------------------------

@test "_self_install_toolchain_deps: pip-installs pyyaml into the toolchain venv" {
    _make_venv_pip ok
    run _self_install_toolchain_deps
    assert_status_equals 0
    grep -qF "install --upgrade pyyaml" "$TEST_DIR/pip.log"
}

@test "_self_install_toolchain_deps: non-fatal when toolchain venv absent" {
    run _self_install_toolchain_deps
    assert_status_equals 0
    [ ! -f "$TEST_DIR/pip.log" ]
}

@test "_self_install_toolchain_deps: non-fatal when pip fails" {
    _make_venv_pip fail
    run _self_install_toolchain_deps
    assert_status_equals 0
}

#------------------------------------------------------------
# Capability check
#------------------------------------------------------------

@test "pyve_toolchain_has_pyyaml: 0 when the interpreter has PyYAML" {
    "$PY_WITH_YAML" -c 'import yaml' 2>/dev/null || skip "test interpreter lacks PyYAML"
    PYVE_PYTHON="$PY_WITH_YAML" run pyve_toolchain_has_pyyaml
    assert_status_equals 0
}

@test "pyve_toolchain_has_pyyaml: non-zero when the interpreter lacks PyYAML" {
    "$PY_WITH_YAML" -m venv --without-pip "$TEST_DIR/noyaml" 2>/dev/null || skip "venv unavailable"
    PYVE_PYTHON="$TEST_DIR/noyaml/bin/python" run pyve_toolchain_has_pyyaml
    [ "$status" -ne 0 ]
}

#------------------------------------------------------------
# Bash seam
#------------------------------------------------------------

_write_spec() {
    cat > "$TEST_DIR/env-dependencies.md" <<'EOF'
## 4. Environment Inventory

### 4.0 Environment Surface Enumeration

```yaml
project: demo
envs:
  root:
    purpose: utility
    backend: venv
```

## 5. Specs
EOF
}

@test "_env_read_spec_json: prints projected JSON via the toolchain interpreter" {
    "$PY_WITH_YAML" -c 'import yaml' 2>/dev/null || skip "test interpreter lacks PyYAML"
    _write_spec
    PYVE_PYTHON="$PY_WITH_YAML" run _env_read_spec_json "$TEST_DIR/env-dependencies.md"
    assert_status_equals 0
    [[ "$output" == *'"envs"'* ]]
    [[ "$output" == *'"backend": "venv"'* ]]
}

@test "_env_read_spec_json: PyYAML absent → exit 3 + 'pyve self install' hint" {
    "$PY_WITH_YAML" -m venv --without-pip "$TEST_DIR/noyaml" 2>/dev/null || skip "venv unavailable"
    _write_spec
    PYVE_PYTHON="$TEST_DIR/noyaml/bin/python" run _env_read_spec_json "$TEST_DIR/env-dependencies.md"
    assert_status_equals 3
    [[ "$output" == *"pyve self install"* ]]
}
