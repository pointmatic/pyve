#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `compose_envrc` body assembly + PC-1 validation.
#
# The composer's pure half: `_compose_envrc_body` enumerates active plugins
# (plugin_list_active), dispatches each plugin's `pyve_plugin_activate`
# (passing its manifest path), concatenates the sentinel-wrapped sections,
# validates the plugin sections through PC-1 (validate_envrc_snippet), and
# wraps everything in the `# >>> pyve:managed:start >>>` …
# `# <<< pyve:managed:end <<<` envelope with composer-owned infrastructure
# (the dotenv block + asdf guard) appended AFTER validation. Emits the
# managed body to stdout — no filesystem writes (that is N.ae.4).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    source "$PYVE_ROOT/lib/envrc_composer.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    export NO_COLOR=1
    # Keep the asdf reshim guard out of the body unless a test opts in.
    VERSION_MANAGER=""
}

teardown() {
    cleanup_test_dir
}

_config_venv() {
    mkdir -p .pyve
    printf 'backend: venv\nvenv:\n  directory: .venv\n' > .pyve/config
}

_load_pure_python() {
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
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

_load_polyglot() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.python]
[plugins.node]
path = "src/frontend"
[env.root]
purpose = "utility"
[env.testenv]
purpose = "test"
default = true
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

# ════════════════════════════════════════════════════════════════════
# Existence + single-plugin body.
# ════════════════════════════════════════════════════════════════════

@test "composer: _compose_envrc_body is defined" {
    declare -F _compose_envrc_body >/dev/null
}

@test "composer (python-only): body carries the python section + envelope + dotenv" {
    _config_venv
    _load_pure_python
    run _compose_envrc_body
    [ "$status" -eq 0 ]
    [[ "$output" == *"# >>> pyve:managed:start >>>"* ]]
    [[ "$output" == *"# <<< pyve:managed:end <<<"* ]]
    [[ "$output" == *"# >>> pyve:plugin:python:activate >>>"* ]]
    [[ "$output" == *'PATH_add ".venv/bin"'* ]]
    [[ "$output" == *'export VIRTUAL_ENV="$PWD/.venv"'* ]]
    # Composer-owned infra present.
    [[ "$output" == *'if [[ -f ".env" ]]; then'* ]]
    [[ "$output" == *'dotenv'* ]]
}

@test "composer (python-only): writes no file" {
    _config_venv
    _load_pure_python
    rm -f .envrc
    _compose_envrc_body >/dev/null
    [ ! -f .envrc ]
}

# ════════════════════════════════════════════════════════════════════
# Polyglot: both sections present, in registration order (python, node).
# ════════════════════════════════════════════════════════════════════

@test "composer (polyglot): both python and node sections present" {
    _config_venv
    _load_polyglot
    run _compose_envrc_body
    [ "$status" -eq 0 ]
    [[ "$output" == *"# >>> pyve:plugin:python:activate >>>"* ]]
    [[ "$output" == *"# >>> pyve:plugin:node:activate >>>"* ]]
    [[ "$output" == *'PATH_add "src/frontend/node_modules/.bin"'* ]]
}

@test "composer (polyglot): python section precedes node section" {
    _config_venv
    _load_polyglot
    local body py_at node_at
    body="$(_compose_envrc_body)"
    py_at="$(printf '%s\n' "$body" | grep -n 'pyve:plugin:python:activate' | head -1 | cut -d: -f1)"
    node_at="$(printf '%s\n' "$body" | grep -n 'pyve:plugin:node:activate' | head -1 | cut -d: -f1)"
    [ -n "$py_at" ] && [ -n "$node_at" ]
    [ "$py_at" -lt "$node_at" ]
}

@test "composer (polyglot): plugin sections sit inside the managed envelope" {
    _config_venv
    _load_polyglot
    local body start_at end_at first_plugin_at
    body="$(_compose_envrc_body)"
    start_at="$(printf '%s\n' "$body" | grep -n 'pyve:managed:start' | head -1 | cut -d: -f1)"
    end_at="$(printf '%s\n' "$body" | grep -n 'pyve:managed:end' | head -1 | cut -d: -f1)"
    first_plugin_at="$(printf '%s\n' "$body" | grep -n 'pyve:plugin:' | head -1 | cut -d: -f1)"
    [ "$start_at" -lt "$first_plugin_at" ]
    [ "$first_plugin_at" -lt "$end_at" ]
}

# ════════════════════════════════════════════════════════════════════
# PC-1 boundary.
# ════════════════════════════════════════════════════════════════════

@test "composer: a plugin emitting a smuggling section halts with non-zero" {
    _config_venv
    _load_polyglot
    # Make the node snippet composer inject command substitution.
    _node_pyve_plugin_envrc_snippet() {
        printf '# >>> pyve:plugin:node:activate >>>\nPATH_add "$(whoami)"\n# <<< pyve:plugin:node:activate <<<\n'
    }
    run _compose_envrc_body
    [ "$status" -ne 0 ]
}

@test "composer: composer infra (dotenv block) is NOT part of the validated plugin sections" {
    # Proof by construction: the dotenv block fails validate_envrc_snippet
    # on its own, yet a successful compose includes it — so it must be
    # appended outside the validated region.
    run validate_envrc_snippet "$(printf 'if [[ -f ".env" ]]; then\n    dotenv\nfi\n')"
    [ "$status" -ne 0 ]
    _config_venv
    _load_pure_python
    run _compose_envrc_body
    [ "$status" -eq 0 ]
    [[ "$output" == *'dotenv'* ]]
}

# ════════════════════════════════════════════════════════════════════
# asdf reshim guard (composer-owned infra, gated by is_asdf_active).
# ════════════════════════════════════════════════════════════════════

@test "composer: asdf guard absent when asdf is not the active manager" {
    _config_venv
    _load_pure_python
    VERSION_MANAGER=""
    run _compose_envrc_body
    [[ "$output" != *"ASDF_PYTHON_PLUGIN_DISABLE_RESHIM"* ]]
}

@test "composer: asdf guard present when asdf is active" {
    _config_venv
    _load_pure_python
    VERSION_MANAGER="asdf"
    unset PYVE_NO_ASDF_COMPAT
    run _compose_envrc_body
    [[ "$output" == *"export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1"* ]]
}

# Migrated from test_asdf_compat.bats J.b — the opt-out is now
# enforced on the composed `.envrc` path. is_asdf_active honors
# PYVE_NO_ASDF_COMPAT, so the guard is suppressed even when asdf is active.
@test "composer: asdf guard absent when PYVE_NO_ASDF_COMPAT=1 (asdf otherwise active)" {
    _config_venv
    _load_pure_python
    VERSION_MANAGER="asdf"
    PYVE_NO_ASDF_COMPAT=1
    run _compose_envrc_body
    [[ "$output" != *"ASDF_PYTHON_PLUGIN_DISABLE_RESHIM"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Wiring: explicit source in pyve.sh.
# ════════════════════════════════════════════════════════════════════

@test "wiring: pyve.sh sources lib/envrc_composer.sh explicitly" {
    grep -qE 'source .*lib/envrc_composer\.sh' "$PYVE_ROOT/pyve.sh"
}
