#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Story N.av.4 — polyglot composed-init path.
#
# For a polyglot project the Python materializer (init_project) scaffolds
# the [plugins.python] + [plugins.node] manifest and builds the Python
# app env; compose_init then materializes the REMAINING declared plugins
# (node) at their declared sub-paths from the same flow. Python-only is
# unaffected (no secondary plugins to materialize). Materializers stubbed.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/project_guide.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    source "$PYVE_ROOT/lib/init_composer.sh"

    PYVE_PYTHON="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null)"
    export PYVE_PYTHON

    # Stub the node materializer + composition tail to observable markers.
    node_pyve_plugin_init() { printf 'NODE-MATERIALIZE:%s\n' "${1:-.}"; }
    compose_project_envrc() { :; }
    compose_project_gitignore() { :; }
    run_project_guide_orchestration() { :; }
    _init_print_next_steps() { :; }
    footer_box() { :; }

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export PYVE_INIT_NONINTERACTIVE=1
}

teardown() { cd /; rm -rf "$TEST_DIR"; }

# Stub the Python materializer: scaffold a POLYGLOT manifest + report the
# Python env (as the real init_project would), without building a venv.
_stub_python_polyglot() {
    python_pyve_plugin_init() {
        cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo-poly"
[env.root]
purpose = "utility"
[plugins.python]
[plugins.node]
path = "frontend"
EOF
        printf 'PYTHON-MATERIALIZE\n'
        PYVE_INIT_TAIL_BACKEND="venv"
        PYVE_INIT_TAIL_ENV_PATH="$PWD/.venv"
        PYVE_INIT_TAIL_NO_DIRENV="true"
        PYVE_INIT_TAIL_PG_MODE="no"
        PYVE_INIT_TAIL_COMP_MODE="no"
    }
}

@test "polyglot: compose_init materializes BOTH python and node" {
    printf '[project]\nname = "demo-poly"\n' > pyproject.toml
    _stub_python_polyglot
    run compose_init --backend venv --no-direnv
    assert_status_equals 0
    assert_output_contains "PYTHON-MATERIALIZE"
    assert_output_contains "NODE-MATERIALIZE"
}

@test "polyglot: node is materialized at its declared sub-path" {
    printf '[project]\nname = "demo-poly"\n' > pyproject.toml
    _stub_python_polyglot
    run compose_init --backend venv --no-direnv
    assert_output_contains "NODE-MATERIALIZE:frontend"
}

@test "python-only: no secondary node materialization (only python active)" {
    printf '[project]\nname = "demo-py"\n' > pyproject.toml
    python_pyve_plugin_init() {
        cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo-py"
[env.root]
purpose = "utility"
[env.testenv]
purpose = "test"
default = true
EOF
        printf 'PYTHON-MATERIALIZE\n'
        PYVE_INIT_TAIL_BACKEND="venv"
        PYVE_INIT_TAIL_ENV_PATH="$PWD/.venv"
        PYVE_INIT_TAIL_NO_DIRENV="true"
        PYVE_INIT_TAIL_PG_MODE="no"
        PYVE_INIT_TAIL_COMP_MODE="no"
    }
    run compose_init --backend venv --no-direnv
    assert_status_equals 0
    assert_output_contains "PYTHON-MATERIALIZE"
    [[ "$output" != *"NODE-MATERIALIZE"* ]] || { echo "node materialized on a python-only project: $output" >&2; return 1; }
}

@test "polyglot: the secondary loop skips python (no double-materialize)" {
    printf '[project]\nname = "demo-poly"\n' > pyproject.toml
    # Count python materializations: the secondary loop must NOT call it again.
    _stub_python_polyglot
    run compose_init --backend venv --no-direnv
    local count
    count="$(printf '%s\n' "$output" | grep -c 'PYTHON-MATERIALIZE')"
    [[ "$count" -eq 1 ]] || { echo "python materialized $count times (expected 1): $output" >&2; return 1; }
}
