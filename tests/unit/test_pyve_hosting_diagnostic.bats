#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.bi: surface project-guide / toolchain integration.
#   - `pyve check`  → environment-level [pyve] addendum (INFO-only; never
#                     affects the severity verdict).
#   - `pyve status` → project-level [project-guide] addendum (integration
#                     mode: pyve-hosted / project-managed pip|conda / not).
# These tests exercise the composer addendum helpers directly with an
# isolated HOME + XDG_DATA_HOME so the hosted state is fully controlled.

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/check_composer.sh"
    source "$PYVE_ROOT/lib/status_composer.sh"

    TEST_DIR="$(mktemp -d)"
    export HOME="$TEST_DIR/home"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export DEFAULT_PYTHON_VERSION="9.9.9"
    mkdir -p "$HOME"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_host_toolchain_python() {
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"
    mkdir -p "$bin"; : > "$bin/python"; chmod +x "$bin/python"
}
_host_pg_shim() {
    mkdir -p "$HOME/.local/bin"
    : > "$HOME/.local/bin/project-guide"; chmod +x "$HOME/.local/bin/project-guide"
}

#============================================================
# check: [pyve] addendum (_compose_check_pyve_hosting)
#============================================================

@test "check [pyve]: unprovisioned → 'not provisioned' + 'pyve self provision' hint" {
    run _compose_check_pyve_hosting
    [ "$status" -eq 0 ]
    [[ "$output" == *"Toolchain Python: not provisioned"* ]]
    [[ "$output" == *"project-guide hosting: not provisioned"* ]]
    [[ "$output" == *"Run 'pyve self provision' to install"* ]]
}

@test "check [pyve]: provisioned → toolchain version + hosting provisioned + upgrade/remove reminder" {
    _host_toolchain_python
    _host_pg_shim
    run _compose_check_pyve_hosting
    [ "$status" -eq 0 ]
    [[ "$output" == *"Toolchain Python: provisioned (9.9.9)"* ]]
    [[ "$output" == *"project-guide hosting: provisioned"* ]]
    # Healthy path still surfaces the lifecycle commands (upgrade / remove).
    [[ "$output" == *"Upgrade: 'pyve self provision'"* ]]
    [[ "$output" == *"pyve self unprovision --all"* ]]
}

@test "check [pyve]: dead-shebang toolchain python is NOT 'provisioned' (runnability, not existence)" {
    # File exists and is executable (passes [[ -x ]]) but cannot exec — the
    # existence != runnability trap. check must not rubber-stamp it.
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"; mkdir -p "$bin"
    printf '#!/nonexistent/interp\n' > "$bin/python"; chmod +x "$bin/python"
    run _compose_check_pyve_hosting
    [ "$status" -eq 0 ]
    [[ "$output" == *"Toolchain Python: not provisioned"* ]]
}

@test "check [pyve]: hosted-but-broken project-guide shim is NOT 'provisioned'" {
    _host_toolchain_python
    mkdir -p "$HOME/.local/bin"
    printf '#!/nonexistent/interp\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
    run _compose_check_pyve_hosting
    [ "$status" -eq 0 ]
    [[ "$output" == *"project-guide hosting: not provisioned"* ]]
}

@test "check [pyve]: project-managed (pip) → 'managed by your project (pip)', no provision hint" {
    printf 'project-guide\n' > requirements.txt
    run _compose_check_pyve_hosting
    [ "$status" -eq 0 ]
    [[ "$output" == *"managed by your project (pip)"* ]]
    [[ "$output" != *"pyve self provision"* ]]
}

@test "check [pyve]: helper always returns 0 (never contributes to the verdict)" {
    # Unprovisioned, provisioned, and project-managed must all be rc 0 so the
    # composer never bumps `worst` from this info-only section.
    run _compose_check_pyve_hosting; [ "$status" -eq 0 ]
    _host_toolchain_python; _host_pg_shim
    run _compose_check_pyve_hosting; [ "$status" -eq 0 ]
}

#============================================================
# status: [project-guide] addendum (_compose_status_project_guide)
#============================================================

@test "status [project-guide]: not integrated → provision reminder" {
    run _compose_status_project_guide
    [ "$status" -eq 0 ]
    [[ "$output" == *"[project-guide]"* ]]
    [[ "$output" == *"not integrated"* ]]
    [[ "$output" == *"Run 'pyve self provision' to install"* ]]
}

@test "status [project-guide]: pyve-hosted (toolchain) → upgrade/remove reminder" {
    _host_pg_shim
    run _compose_status_project_guide
    [[ "$output" == *"pyve-hosted (toolchain)"* ]]
    [[ "$output" == *"Upgrade: 'pyve self provision'"* ]]
    [[ "$output" == *"pyve self unprovision --all"* ]]
}

@test "status [project-guide]: project-managed (pip) → no provision reminder" {
    printf 'project-guide\n' > requirements.txt
    run _compose_status_project_guide
    [[ "$output" == *"project-managed (pip)"* ]]
    [[ "$output" != *"pyve self provision"* ]]
}

@test "status [project-guide]: project-managed (conda)" {
    cat > environment.yml << 'EOF'
name: e
dependencies:
  - project-guide
EOF
    run _compose_status_project_guide
    [[ "$output" == *"project-managed (conda)"* ]]
}

@test "status [project-guide]: project-managed wins over pyve-hosted" {
    _host_pg_shim
    printf 'project-guide\n' > requirements.txt
    run _compose_status_project_guide
    [[ "$output" == *"project-managed (pip)"* ]]
    [[ "$output" != *"pyve-hosted"* ]]
}

#============================================================
# any-stack: composer-level, not python-plugin-bound (end-to-end)
#============================================================

@test "check: [pyve] section renders on a Node-shaped project (any-stack)" {
    printf '{ "name": "app" }\n' > package.json   # Node marker, no Python markers
    run bash "$PYVE_ROOT/pyve.sh" check
    [[ "$output" == *"[pyve]"* ]]
}

@test "status: [project-guide] section renders on a Node-shaped project (any-stack)" {
    printf '{ "name": "app" }\n' > package.json
    run bash "$PYVE_ROOT/pyve.sh" status
    [[ "$output" == *"[project-guide]"* ]]
}
