#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# PC-4a: no-Python noise suppression on Node-only projects.
#
# `python_plugin_is_active_in_project` is the gate. Pyve defaults to Python:
# the gate returns ACTIVE (0) on any Python signal, AND on a bare dir with no
# competing stack (so `pyve check` keeps its "config missing → run pyve init"
# nudge). It returns INACTIVE (1 → suppress) only when there is NO Python
# signal anywhere AND a competing non-Python stack (e.g. package.json) is
# present. The Python plugin's check/status hooks short-circuit to a clean
# no-op when inactive; compose_check/compose_status skip the empty section so
# the output is truly Python-free.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/check_composer.sh"
    source "$PYVE_ROOT/lib/status_composer.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    create_test_dir
    plugin_registry_reset
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Gate predicate — Python signals → ACTIVE.
# ════════════════════════════════════════════════════════════════════

@test "gate is defined" {
    declare -F python_plugin_is_active_in_project >/dev/null
}

@test "active: pyproject.toml at root" {
    : > pyproject.toml
    python_plugin_is_active_in_project
}

@test "active: a root-level *.py file" {
    : > main.py
    python_plugin_is_active_in_project
}

@test "active: requirements*.txt" {
    : > requirements-dev.txt
    python_plugin_is_active_in_project
}

@test "active: .pyve/config (v2 Python project marker)" {
    mkdir -p .pyve
    printf 'backend: venv\n' > .pyve/config
    python_plugin_is_active_in_project
}

@test "active: .project-guide.yml alone falls through to the bare-dir Python default (not a marker signal)" {
    # .project-guide.yml is NO LONGER a Python-active signal
    # (project-guide is globally hosted). With no competing stack present,
    # this dir is still active — but via the bare-dir default, not the marker.
    : > .project-guide.yml
    python_plugin_is_active_in_project
}

@test "active: [plugins.python] declared in pyve.toml" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "x"
[plugins.python]
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
    python_plugin_is_active_in_project
}

@test "active: an env with a venv backend (the project-guide-hosting utility root)" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "x"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    python_plugin_is_active_in_project
}

# ── Pyve-defaults-to-Python: bare dir stays active ──────────────────

@test "active: bare dir with no signals at all (Pyve defaults to Python)" {
    # No pyproject, no .pyve/config, no package.json — nothing.
    python_plugin_is_active_in_project
}

# ════════════════════════════════════════════════════════════════════
# Gate predicate — competing stack + zero Python → SUPPRESS.
# ════════════════════════════════════════════════════════════════════

@test "suppress: package.json present and NO Python signal anywhere" {
    printf '{ "name": "x", "private": true }\n' > package.json
    run python_plugin_is_active_in_project
    [ "$status" -eq 1 ]
}

@test "active: package.json present BUT a Python signal also exists (polyglot)" {
    printf '{ "name": "x" }\n' > package.json
    : > pyproject.toml
    python_plugin_is_active_in_project
}

@test "suppress: package.json + .project-guide.yml (project-guide is global, no project Python env)" {
    # project-guide is globally hosted, so its per-project marker
    # no longer implies a project Python env. A Node-only project that accepts
    # project-guide has NO .venv to report → Python stays suppressed.
    printf '{ "name": "x" }\n' > package.json
    : > .project-guide.yml
    run python_plugin_is_active_in_project
    [ "$status" -eq 1 ]
}

# ════════════════════════════════════════════════════════════════════
# check/status hooks short-circuit to a clean no-op when inactive.
# ════════════════════════════════════════════════════════════════════

@test "hook: python_pyve_plugin_check is silent + rc 0 when suppressed" {
    printf '{ "name": "x" }\n' > package.json
    run python_pyve_plugin_check .
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "hook: python_pyve_plugin_status is silent + rc 0 when suppressed" {
    printf '{ "name": "x" }\n' > package.json
    run python_pyve_plugin_status .
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "hook: python_pyve_plugin_check still runs when a Python signal exists" {
    printf '{ "name": "x" }\n' > package.json
    : > pyproject.toml
    run python_pyve_plugin_check .
    # Active → check_environment runs and emits its body (config missing here).
    [[ -n "$output" ]]
}

# ════════════════════════════════════════════════════════════════════
# End-to-end through the dispatcher — implicit Python on a Node dir.
# ════════════════════════════════════════════════════════════════════

@test "e2e: Node dir, project-guide declined → pyve check has ZERO Python output" {
    # No pyve.toml plugins → implicit Python registers; package.json present,
    # no Python anywhere → the gate suppresses, composer skips the section.
    printf '{ "name": "frontend", "private": true }\n' > package.json
    run "$PYVE_SCRIPT" check
    ! [[ "$output" == *"Pyve Environment Check"* ]]
    ! [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"virtual environment"* ]]
}

@test "e2e: Node dir, project-guide declined → pyve status has ZERO Python output" {
    printf '{ "name": "frontend", "private": true }\n' > package.json
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"Backend:"* ]]
}

@test "e2e: bare dir keeps the 'config missing → pyve init' nudge (Python default)" {
    run "$PYVE_SCRIPT" check
    # No competing stack → Python stays active → the helpful nudge survives.
    [[ "$output" == *".pyve/config"* ]] || [[ "$output" == *"pyve init"* ]]
}

@test "e2e: Node dir + project-guide accepted → Python suppressed (global hosting, no utility root)" {
    # project-guide is global; a Node-only project has no project
    # Python env, so the Python plugin produces ZERO output (as when declined).
    printf '{ "name": "frontend" }\n' > package.json
    : > .project-guide.yml
    run "$PYVE_SCRIPT" check
    ! [[ "$output" == *"[python]"* ]]
    ! [[ "$output" == *"virtual environment"* ]]
}
