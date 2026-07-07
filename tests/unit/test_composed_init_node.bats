#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Node-only composed-init path.
#
# A fresh project with Node at root and no Python signal must materialize
# node_modules (via the Node plugin) and get NO Python app env (.venv),
# a [plugins.node]-only pyve.toml, composed .envrc/.gitignore from the
# Node plugin, and node-aware next-steps. Python projects still route to
# the Python materializer. Heavy materializers/composers are stubbed.
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

    # Pyve toolchain python (manifest_load shells out to the helper).
    PYVE_PYTHON="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null)"
    export PYVE_PYTHON

    # Stub the heavy materializers + composers to observable markers.
    node_pyve_plugin_init() { mkdir -p "${1:-.}/node_modules"; printf 'NODE-MATERIALIZE:%s\n' "${1:-.}"; }
    python_pyve_plugin_init() { printf 'PYTHON-MATERIALIZE\n'; PYVE_INIT_TAIL_BACKEND="venv"; PYVE_INIT_TAIL_ENV_PATH="/x/.venv"; PYVE_INIT_TAIL_NO_DIRENV="true"; PYVE_INIT_TAIL_PG_MODE="no"; PYVE_INIT_TAIL_COMP_MODE="no"; }
    compose_project_envrc() { printf 'COMPOSE-ENVRC\n'; }
    compose_project_gitignore() { printf 'COMPOSE-GITIGNORE\n'; }
    run_project_guide_orchestration() { printf 'PROJECT-GUIDE:%s\n' "$1"; }
    _init_print_next_steps() { printf 'PY-NEXT-STEPS\n'; }
    footer_box() { :; }

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export PYVE_INIT_NONINTERACTIVE=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "node-only: dispatches the node materializer, not python" {
    printf '{"name":"demo-node"}\n' > package.json
    run compose_init
    assert_status_equals 0
    assert_output_contains "NODE-MATERIALIZE"
    [[ "$output" != *"PYTHON-MATERIALIZE"* ]] || { echo "python ran on a node-only project: $output" >&2; return 1; }
}

@test "node-only: creates no .venv" {
    printf '{"name":"demo-node"}\n' > package.json
    run compose_init
    [[ ! -d .venv ]]
}

@test "node-only: writes a [plugins.node]-only pyve.toml (no [plugins.python])" {
    printf '{"name":"demo-node"}\n' > package.json
    run compose_init
    assert_status_equals 0
    grep -q '\[plugins.node\]' pyve.toml
    run grep -q '\[plugins.python\]' pyve.toml
    [[ "$status" -ne 0 ]]
}

@test "node-only: composes .envrc and .gitignore" {
    printf '{"name":"demo-node"}\n' > package.json
    run compose_init
    assert_output_contains "COMPOSE-ENVRC"
    assert_output_contains "COMPOSE-GITIGNORE"
}

@test "node-only: honors --no-direnv (skips .envrc)" {
    printf '{"name":"demo-node"}\n' > package.json
    run compose_init --no-direnv
    assert_output_contains "Skipping .envrc creation"
    [[ "$output" != *"COMPOSE-ENVRC"* ]] || { echo "composed .envrc despite --no-direnv" >&2; return 1; }
}

@test "node-only: project-guide orchestration runs (globally hosted), but next-steps stay node-aware" {
    printf '{"name":"demo-node"}\n' > package.json
    run compose_init
    # project-guide is globally hosted, so the orchestration runs
    # on a Node-only stack too (no longer deferred).
    [[ "$output" == *"PROJECT-GUIDE"* ]] || { echo "project-guide did NOT run on node-only (N.aw enables it)" >&2; return 1; }
    # The Python next-steps tail must still NOT run — node gets node-aware steps.
    [[ "$output" != *"PY-NEXT-STEPS"* ]] || { echo "python next-steps ran on node-only" >&2; return 1; }
}

@test "node-only: manifest parse failure errors clearly and does NOT dispatch python" {
    printf '{"name":"demo-node"}\n' > package.json
    # Simulate the toolchain Python being unavailable (manifest_load fails).
    manifest_load() { return 2; }
    run compose_init
    [[ "$status" -ne 0 ]]
    assert_output_contains "Pyve's Python interpreter is unavailable"
    [[ "$output" != *"PYTHON-MATERIALIZE"* ]] || { echo "fell back to python on parse failure" >&2; return 1; }
    [[ ! -d .venv ]]
}

@test "python project still routes to the python materializer (regression)" {
    printf '[project]\nname = "demo-py"\n' > pyproject.toml
    run compose_init --backend venv --no-direnv
    assert_status_equals 0
    assert_output_contains "PYTHON-MATERIALIZE"
    [[ "$output" != *"NODE-MATERIALIZE"* ]] || { echo "node ran on a python project" >&2; return 1; }
}
