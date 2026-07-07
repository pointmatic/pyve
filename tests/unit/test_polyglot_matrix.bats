#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# End-to-end regression sweep: the polyglot test matrix.
#
# The N-4 composition layer is exercised against the three project shapes
# Phase N targets — pure-Python, Node-only, and polyglot (Python at the root +
# a SvelteKit frontend at src/frontend) — through the REAL composed CLI
# (`bash pyve.sh check|status|purge`) and the composer entry points
# (`compose_project_envrc` / `compose_project_gitignore`). Where N.ab proved
# the per-plugin HOOKS compose at the hook level, this sweep proves the
# CLI-level COMPOSITION holds across the matrix and re-asserts the cross-cutting
# composition invariants (PC-2 write safety, PC-4a no-Python noise gate) at the
# matrix level.
#
# Scope (per the N.am hermetic-bats decision): this file owns the *composed*
# surface — check / status / purge severity-and-section composition, the
# composed .envrc / .gitignore envelopes, PC-2, and PC-4a. Per-plugin
# init / env-install / env-run / test are covered by the existing per-plugin
# suites (N.s*, N.w/N.x, test_venv_workflow.py, test_testenv.py) and are not
# re-driven here. PC-4b (≤ 50ms p95 latency) is owned by
# tests/perf/test_plugin_activation_latency.bats, which already benchmarks all
# three fixtures; it is re-run as part of the sweep rather than duplicated.
#
# Because the sweep is hermetic (no real venv / node toolchain provisioning),
# `pyve check` runs against UN-provisioned fixtures: each plugin's check hook
# reports its missing env as an error, so the composer's worst-severity roll-up
# is `error` → exit 2. That exit is itself the composition contract under test
# (the roll-up), not a regression. `status` and `purge` exit clean (0).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # The composed CLI subprocess (`bash pyve.sh ...`) parses [plugins.*] via
    # manifest_load, which needs a resolvable Python; export it before
    # create_test_dir cds into the sandbox.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    source "$PYVE_ROOT/lib/check_composer.sh"
    source "$PYVE_ROOT/lib/status_composer.sh"
    source "$PYVE_ROOT/lib/envrc_composer.sh"
    source "$PYVE_ROOT/lib/gitignore_composer.sh"
    source "$PYVE_ROOT/lib/purge_composer.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    export NO_COLOR=1
    unset CI PYVE_FORCE_YES
    VERSION_MANAGER=""
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Fixture builders — the three matrix shapes.
# ════════════════════════════════════════════════════════════════════

# Pure-Python: pyproject + a root [plugins.python] + a venv-backed config so
# the composed .envrc gets a `.venv/bin` PATH_add.
_fixture_python() {
    cat > pyproject.toml <<'EOF'
[project]
name = "py-only"
version = "0.1.0"
EOF
    : > main.py
    mkdir -p .pyve
    printf 'backend: venv\nvenv:\n  directory: .venv\n' > .pyve/config
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "py-only"

[plugins.python]
path = "."

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true
EOF
}

# Node-only: a SvelteKit project at the root, [plugins.node] at the root, and
# NO Python signal anywhere (the PC-4a suppression precondition).
_fixture_node() {
    cat > package.json <<'EOF'
{
  "name": "node-only",
  "version": "0.0.1",
  "private": true,
  "scripts": { "test": "vitest run" },
  "devDependencies": { "@sveltejs/kit": "^2.0.0" }
}
EOF
    cat > svelte.config.js <<'EOF'
export default {};
EOF
    mkdir -p src/routes
    : > src/routes/+page.svelte
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "node-only"

[plugins.node]

[env.web]
purpose = "run"
backend = "pnpm"
frameworks = ["sveltekit"]
EOF
}

# Polyglot: Python API at the root + SvelteKit frontend at src/frontend.
_fixture_polyglot() {
    cat > pyproject.toml <<'EOF'
[project]
name = "my-saas"
version = "0.1.0"
EOF
    mkdir -p src/my_saas src/frontend/src/routes
    : > src/my_saas/__main__.py
    mkdir -p .pyve
    printf 'backend: venv\nvenv:\n  directory: .venv\n' > .pyve/config
    cat > src/frontend/package.json <<'EOF'
{
  "name": "frontend",
  "private": true,
  "scripts": { "test": "vitest run" },
  "devDependencies": { "@sveltejs/kit": "^2.0.0" }
}
EOF
    cat > src/frontend/svelte.config.js <<'EOF'
export default {};
EOF
    : > src/frontend/src/routes/+page.svelte
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "my-saas"

[plugins.python]
path = "."

[plugins.node]
path = "src/frontend"

[env.root]
purpose = "utility"
backend = "venv"

[env.web]
purpose = "run"
backend = "pnpm"
path = "src/frontend"
frameworks = ["sveltekit"]
EOF
}

# ════════════════════════════════════════════════════════════════════
# Pure-Python fixture — composition is Python-only, no Node leakage.
# ════════════════════════════════════════════════════════════════════

@test "python: check renders exactly one banner and a [python] section, no node" {
    _fixture_python
    run "$PYVE_SCRIPT" check
    local banner_count
    banner_count="$(printf '%s\n' "$output" | grep -c 'Pyve Environment Check')"
    [ "$banner_count" -eq 1 ]
    [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"[node"* ]]
    [[ "$output" == *"Overall:"* ]]
}

@test "python: status exits clean with a [python] section and no node" {
    _fixture_python
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"[node"* ]]
}

@test "python: composed .envrc has the python managed envelope + .venv PATH_add" {
    _fixture_python
    rm -f .envrc
    run compose_project_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF '# >>> pyve:managed:start >>>' .envrc
    grep -qF '# <<< pyve:managed:end <<<' .envrc
    grep -qF 'PATH_add ".venv/bin"' .envrc
    ! grep -qF 'node_modules/.bin' .envrc
}

@test "python: composed .gitignore carries python entries, no node entries" {
    _fixture_python
    rm -f .gitignore
    run compose_project_gitignore .gitignore
    [ "$status" -eq 0 ]
    grep -qF '__pycache__' .gitignore
    ! grep -qF 'node_modules/' .gitignore
}

@test "python: purge --yes exits clean and preserves authored files" {
    _fixture_python
    run "$PYVE_SCRIPT" purge --yes
    [ "$status" -eq 0 ]
    [ -f pyproject.toml ]
    [ -f main.py ]
}

# ════════════════════════════════════════════════════════════════════
# Node-only fixture — PC-4a: ZERO Python output anywhere.
# ════════════════════════════════════════════════════════════════════

@test "node: check has a node section and ZERO python output (PC-4a)" {
    _fixture_node
    run "$PYVE_SCRIPT" check
    [[ "$output" == *"[node"* ]]
    # PC-4a: no Python plugin noise on a Node-only project.
    ! [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"Pyve Environment Check"* ]]
    ! [[ "$output" == *"virtual environment"* ]]
}

@test "node: status exits clean with ZERO python output (PC-4a)" {
    _fixture_node
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"[node]"* ]]
    # PC-4a: no Python section. (The node section legitimately prints its own
    # "Backend: pnpm" line, so "Backend:" is NOT a Python-leakage signal — the
    # [python] header is.)
    ! [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"virtual environment"* ]]
}

@test "node: composed .envrc has the node managed envelope, no python venv line" {
    _fixture_node
    rm -f .envrc
    run compose_project_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF '# >>> pyve:managed:start >>>' .envrc
    grep -qF 'PATH_add "node_modules/.bin"' .envrc
    ! grep -qF '.venv/bin' .envrc
}

@test "node: composed .gitignore carries node entries, no python __pycache__" {
    _fixture_node
    rm -f .gitignore
    run compose_project_gitignore .gitignore
    [ "$status" -eq 0 ]
    grep -qF 'node_modules/' .gitignore
    ! grep -qF '__pycache__' .gitignore
}

@test "node: purge --yes exits clean, removes node_modules, keeps authored files" {
    _fixture_node
    mkdir -p node_modules/.bin
    : > node_modules/.installed
    run "$PYVE_SCRIPT" purge --yes
    [ "$status" -eq 0 ]
    [ ! -d node_modules ]
    [ -f package.json ]
    [ -f svelte.config.js ]
}

# ════════════════════════════════════════════════════════════════════
# Polyglot fixture — both plugins compose, paths stay scoped.
# ════════════════════════════════════════════════════════════════════

@test "polyglot: check renders one banner + BOTH sections, node path-prefixed" {
    _fixture_polyglot
    run "$PYVE_SCRIPT" check
    local banner_count
    banner_count="$(printf '%s\n' "$output" | grep -c 'Pyve Environment Check')"
    [ "$banner_count" -eq 1 ]
    [[ "$output" == *"[python]"* ]]
    [[ "$output" == *"[node @ src/frontend]"* ]]
    # Un-provisioned fixture → worst severity is error → exit 2 (the roll-up).
    [ "$status" -eq 2 ]
    [[ "$output" == *"Overall: errors"* ]]
}

@test "polyglot: status exits clean with BOTH sections, node path-prefixed" {
    _fixture_polyglot
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"[python]"* ]]
    [[ "$output" == *"[node @ src/frontend]"* ]]
}

@test "polyglot: composed .envrc carries BOTH managed plugin sections" {
    _fixture_polyglot
    rm -f .envrc
    run compose_project_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF 'PATH_add ".venv/bin"' .envrc
    grep -qF 'src/frontend/node_modules/.bin' .envrc
}

@test "polyglot: composed .gitignore carries BOTH plugins' entries (node path-prefixed)" {
    _fixture_polyglot
    rm -f .gitignore
    run compose_project_gitignore .gitignore
    [ "$status" -eq 0 ]
    grep -qF '__pycache__' .gitignore
    grep -qF 'src/frontend/node_modules/' .gitignore
}

@test "polyglot: purge --yes removes node_modules at the sub-path, keeps authored files" {
    _fixture_polyglot
    mkdir -p src/frontend/node_modules/.bin
    : > src/frontend/node_modules/.installed
    run "$PYVE_SCRIPT" purge --yes
    [ "$status" -eq 0 ]
    [ ! -d src/frontend/node_modules ]
    [ -f src/frontend/package.json ]
    [ -f pyproject.toml ]
    [ -f src/my_saas/__main__.py ]
}

# ════════════════════════════════════════════════════════════════════
# PC-2 — induced-failure write safety, at the matrix (polyglot) level.
# A plugin emitting an unsafe (.envrc) snippet must leave the existing
# file untouched and produce no half-written tmp / spurious backup.
# ════════════════════════════════════════════════════════════════════

@test "PC-2: a smuggling plugin snippet leaves the existing .envrc intact" {
    _fixture_polyglot
    # Establish a valid composed .envrc first.
    compose_project_envrc .envrc
    local before
    before="$(cat .envrc)"
    rm -f .envrc.prev .envrc.tmp

    # Node now tries to smuggle command substitution into its section.
    _node_pyve_plugin_envrc_snippet() {
        printf '# >>> pyve:plugin:node:activate >>>\nPATH_add "$(whoami)"\n# <<< pyve:plugin:node:activate <<<\n'
    }
    run compose_envrc .envrc
    [ "$status" -ne 0 ]
    # Existing file unchanged; no debris.
    [ "$(cat .envrc)" = "$before" ]
    [ ! -f .envrc.tmp ]
    [ ! -f .envrc.prev ]
}

@test "PC-2: .envrc.prev rollback restores the prior composed state" {
    _fixture_polyglot
    compose_project_envrc .envrc
    printf 'export ROLLBACK_ME="yes"\n' >> .envrc
    local before
    before="$(cat .envrc)"
    compose_project_envrc .envrc      # writes .envrc.prev = before
    [ -f .envrc.prev ]
    mv -f .envrc.prev .envrc          # documented one-step rollback
    [ "$(cat .envrc)" = "$before" ]
}

# ════════════════════════════════════════════════════════════════════
# PC-4b — latency budget. Owned by the perf suite (all three fixtures);
# this is a presence assertion so the sweep documents the dependency
# rather than duplicating the benchmark.
# ════════════════════════════════════════════════════════════════════

@test "PC-4b: the per-fixture latency benchmark suite exists" {
    [ -f "$PYVE_ROOT/tests/perf/test_plugin_activation_latency.bats" ]
    grep -qF 'PERF_BUDGET_MS=50' "$PYVE_ROOT/tests/perf/test_plugin_activation_latency.bats"
}
