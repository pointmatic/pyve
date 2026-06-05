#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Story N.av.5 — composed-init integration matrix.
#
# Drives REAL `pyve init` end-to-end across the three project shapes
# (Python-only / Node-only / polyglot), then runs the composed
# `check` / `status` / `purge` against the actual init output (not a
# hand-built fixture). Confirms the N-4 composers enumerate the right
# plugin set on what composed-init produced.
#
# Guarded: skips when the required toolchain (a real Python with tomllib,
# and Node/npm for the Node shapes) is unavailable — mirrors the N.ab
# e2e "skipped if npm absent" precedent. These are slower than the unit
# tests by design (real venv / node_modules materialization).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # Pyve toolchain Python (manifest parsing). Skip the whole file if a
    # real interpreter with tomllib is not resolvable.
    REAL_PY="$(python3 -c 'import sys, tomllib; print(sys.executable)' 2>/dev/null || true)"
    [[ -n "$REAL_PY" && -x "$REAL_PY" ]] || skip "no real python3 with tomllib"
    export PYVE_PYTHON="$REAL_PY"

    export PYVE_INIT_NONINTERACTIVE=1
    export PYVE_NO_PROJECT_GUIDE=1
    HAVE_NODE=0
    command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 && HAVE_NODE=1

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() { cd /; rm -rf "${TEST_DIR:-/nonexistent}"; }

_pyve() { bash "$PYVE_ROOT/pyve.sh" "$@"; }

@test "matrix/python-only: init builds .venv; composed check covers python" {
    printf '[project]\nname = "demo-py"\nversion = "0.1.0"\n' > pyproject.toml
    run _pyve init --backend venv --no-direnv --no-project-guide
    [ "$status" -eq 0 ]
    [[ -d .venv ]]
    grep -q '\[plugins.python\]' pyve.toml || grep -q 'pyve_schema' pyve.toml  # plain manifest is implicit-python
    run grep -q '\[plugins.node\]' pyve.toml
    [[ "$status" -ne 0 ]]

    # Composed check enumerates python; no node section.
    run _pyve check
    [[ "$output" == *"python"* || "$output" == *"Python"* ]]
    [[ "$output" != *"[node"* ]]
}

@test "matrix/node-only: init builds node_modules + no .venv; composed check covers node not python" {
    [[ "$HAVE_NODE" -eq 1 ]] || skip "node/npm not installed"
    printf '{"name":"demo-node","version":"1.0.0"}\n' > package.json
    run _pyve init --no-direnv
    [ "$status" -eq 0 ]
    [[ -d node_modules ]]
    [[ ! -d .venv ]]
    grep -q '\[plugins.node\]' pyve.toml
    run grep -q '\[plugins.python\]' pyve.toml
    [[ "$status" -ne 0 ]]

    # Composed check: node section present, python suppressed (PC-4a).
    run _pyve check
    [[ "$output" == *"[node"* ]]
    [[ "$output" != *"[python]"* ]]

    # Composed status runs cleanly (informational, exit 0).
    run _pyve status
    [ "$status" -eq 0 ]
    [[ "$output" == *"node"* ]]
}

@test "matrix/polyglot: init builds .venv + sub-path node_modules; composed check covers both" {
    [[ "$HAVE_NODE" -eq 1 ]] || skip "node/npm not installed"
    printf '[project]\nname = "demo-poly"\nversion = "0.1.0"\n' > pyproject.toml
    printf '{"name":"poly-root"}\n' > package.json
    mkdir -p src/frontend && printf '{"name":"poly-fe","version":"1.0.0"}\n' > src/frontend/package.json
    run _pyve init --backend venv --no-direnv --no-project-guide
    [ "$status" -eq 0 ]
    [[ -d .venv ]]
    [[ -d src/frontend/node_modules ]]
    grep -q '\[plugins.python\]' pyve.toml
    grep -q '\[plugins.node\]' pyve.toml

    # Composed check covers BOTH plugins.
    run _pyve check
    [[ "$output" == *"python"* || "$output" == *"Python"* ]]
    [[ "$output" == *"[node @ src/frontend]"* || "$output" == *"[node"* ]]
}

@test "matrix/polyglot: composed purge --yes removes both the venv and the node_modules" {
    [[ "$HAVE_NODE" -eq 1 ]] || skip "node/npm not installed"
    printf '[project]\nname = "demo-poly"\nversion = "0.1.0"\n' > pyproject.toml
    printf '{"name":"poly-root"}\n' > package.json
    mkdir -p src/frontend && printf '{"name":"poly-fe","version":"1.0.0"}\n' > src/frontend/package.json
    run _pyve init --backend venv --no-direnv --no-project-guide
    [ "$status" -eq 0 ]
    [[ -d .venv && -d src/frontend/node_modules ]]

    run _pyve purge --yes
    [ "$status" -eq 0 ]
    [[ ! -d .venv ]]
    [[ ! -d src/frontend/node_modules ]]
}
