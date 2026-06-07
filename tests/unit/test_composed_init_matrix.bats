#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# composed-init integration matrix.
#
# Drives REAL `pyve init` end-to-end across the three project shapes
# (Python-only / Node-only / polyglot), then runs the composed
# `check` / `status` / `purge` against the actual init output (not a
# hand-built fixture). Confirms the N-4 composers enumerate the right
# plugin set on what composed-init produced.
#
# Hermeticity (Fix N.ba.2c). This file drives the real product, so its
# assertions MUST establish their own preconditions rather than read the
# ambient toolchain — otherwise the same fixed assertion is right on one
# machine and wrong on another (the original failure: `init --backend
# venv` correctly refuses with no version manager, so the success
# assertion failed on the VM-less unit-tests CI job while passing
# locally). Three disciplines:
#   - No-VM refusal path → CONTROLLED: run init under `env -i` with an
#     empty HOME and a VM-free PATH (the real interpreter symlinked in,
#     plus coreutils, no asdf/pyenv). "No version manager" becomes a fact
#     the test created, so the refusal is deterministic everywhere.
#   - Real-venv success path → CANNOT be faked (needs a real version
#     manager + network), so it skip-guards on VM presence — mirroring the
#     pre-existing "skip if no real python3 / no node" guards. It runs for
#     real where a VM exists (the bash-coverage CI job's pyenv, local dev).
#   - Node materialization → CONTROLLED via a `file:` local dependency, so
#     `npm install` creates node_modules regardless of npm version and
#     without touching the registry (a zero-dep package.json creates no
#     node_modules on npm 11.x).
# These are slower than the unit tests by design (real venv / node_modules
# materialization).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # Pyve toolchain Python (manifest parsing). Skip the whole file if a
    # real interpreter with tomllib is not resolvable. REAL_PY is the
    # binary behind any version-manager shim (sys.executable), so it works
    # without that version manager on PATH.
    REAL_PY="$(python3 -c 'import sys, tomllib; print(sys.executable)' 2>/dev/null || true)"
    [[ -n "$REAL_PY" && -x "$REAL_PY" ]] || skip "no real python3 with tomllib"
    export PYVE_PYTHON="$REAL_PY"

    export PYVE_INIT_NONINTERACTIVE=1
    export PYVE_NO_PROJECT_GUIDE=1

    HAVE_NODE=0
    command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 && HAVE_NODE=1

    # Does THIS environment have a Python version manager init would find?
    # (unit-tests CI job: no → only the controlled refusal path runs;
    #  bash-coverage CI job / local dev: yes → the real-venv path runs.)
    HAVE_VM=0
    if command -v asdf >/dev/null 2>&1 && asdf plugin list 2>/dev/null | grep -q '^python$'; then
        HAVE_VM=1
    elif command -v pyenv >/dev/null 2>&1; then
        HAVE_VM=1
    fi

    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() { cd /; rm -rf "${TEST_DIR:-/nonexistent}"; }

_pyve() { bash "$PYVE_ROOT/pyve.sh" "$@"; }

# Run `pyve init` in a deliberately VM-free environment: empty HOME (so
# source_shell_profiles finds no ~/.asdf or ~/.pyenv to re-add) and a PATH
# carrying only the real interpreter + coreutils. Deterministic on any host.
_pyve_init_no_vm() {
    local cleanbin="$TEST_DIR/clean-bin" fakehome="$TEST_DIR/fake-home"
    mkdir -p "$cleanbin" "$fakehome"
    ln -sf "$REAL_PY" "$cleanbin/python3"
    ln -sf "$REAL_PY" "$cleanbin/python"
    env -i \
        HOME="$fakehome" \
        PATH="$cleanbin:/usr/bin:/bin" \
        PYVE_PYTHON="$REAL_PY" \
        PYVE_INIT_NONINTERACTIVE=1 \
        PYVE_NO_PROJECT_GUIDE=1 \
        bash "$PYVE_ROOT/pyve.sh" "$@"
}

# Write a node project at <dir> with a `file:` local dependency AND a
# committed package-lock.json. Two ambient variables made the original
# fixture non-deterministic: (1) a zero-dependency package.json creates no
# node_modules on npm 11.x; the `file:` local dep fixes that with no
# network. (2) `node_provider_detect` defaults to **pnpm** when no lockfile
# is present, so init's installer was whatever package manager the host
# happened to have — pnpm install failures aren't propagated, so init
# returned 0 with no node_modules. The package-lock.json pins the provider
# to npm (guaranteed by the HAVE_NODE guard's `command -v npm`), making the
# materialization independent of pnpm/yarn presence. <dir> defaults to ".".
_write_node_project() {
    local dir="${1:-.}" name="${2:-demo-node}"
    mkdir -p "$dir/local-dep"
    printf '{"name":"local-dep","version":"1.0.0"}\n' > "$dir/local-dep/package.json"
    printf '{"name":"%s","version":"1.0.0","dependencies":{"local-dep":"file:./local-dep"}}\n' \
        "$name" > "$dir/package.json"
    # Lockfile only (no node_modules yet) — init's `npm install` does the
    # real materialization the test asserts on.
    ( cd "$dir" && npm install --package-lock-only --no-audit --no-fund >/dev/null 2>&1 )
}

@test "matrix/python-only: init --backend venv refuses deterministically when no version manager" {
    printf '[project]\nname = "demo-py"\nversion = "0.1.0"\n' > pyproject.toml

    # Controlled "no version manager" condition — not an accident of the host.
    run _pyve_init_no_vm init --backend venv --no-direnv --no-project-guide
    [ "$status" -ne 0 ]
    [[ ! -d .venv ]]
    [[ "$output" == *"version manager"* ]]
}

@test "matrix/python-only: with version manager, init builds .venv; composed check covers python" {
    [[ "$HAVE_VM" -eq 1 ]] || skip "no python version manager (asdf/pyenv) — real venv cannot be synthesized"
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
    _write_node_project . demo-node
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
    [[ "$HAVE_VM" -eq 1 ]] || skip "no python version manager (asdf/pyenv) — real venv cannot be synthesized"
    [[ "$HAVE_NODE" -eq 1 ]] || skip "node/npm not installed"
    printf '[project]\nname = "demo-poly"\nversion = "0.1.0"\n' > pyproject.toml
    _write_node_project . poly-root
    _write_node_project src/frontend poly-fe
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
    [[ "$HAVE_VM" -eq 1 ]] || skip "no python version manager (asdf/pyenv) — real venv cannot be synthesized"
    [[ "$HAVE_NODE" -eq 1 ]] || skip "node/npm not installed"
    printf '[project]\nname = "demo-poly"\nversion = "0.1.0"\n' > pyproject.toml
    _write_node_project . poly-root
    _write_node_project src/frontend poly-fe
    run _pyve init --backend venv --no-direnv --no-project-guide
    [ "$status" -eq 0 ]
    [[ -d .venv && -d src/frontend/node_modules ]]

    run _pyve purge --yes
    [ "$status" -eq 0 ]
    [[ ! -d .venv ]]
    [[ ! -d src/frontend/node_modules ]]
}
