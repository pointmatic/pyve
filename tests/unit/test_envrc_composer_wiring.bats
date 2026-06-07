#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# init/update rewiring: `compose_project_envrc`.
#
# `compose_project_envrc` is the init/update entry point: it reloads the
# manifest + plugin registry from the on-disk pyve.toml BEFORE composing,
# because main() loaded the manifest before the command wrote/updated
# pyve.toml + .pyve/config (spike decision 3). Without the reload,
# plugin_list_active is stale — e.g. implicit-Python only, missing a
# freshly-scaffolded node plugin. The full init/update flow is covered by
# tests/integration/test_envrc_composition.py; this pins the reload-then-
# compose unit fast.

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
    VERSION_MANAGER=""
}

teardown() {
    cleanup_test_dir
}

_config_venv() {
    mkdir -p .pyve
    printf 'backend: venv\nvenv:\n  directory: .venv\n' > .pyve/config
}

@test "compose_project_envrc: is defined" {
    declare -F compose_project_envrc >/dev/null
}

@test "reload: composes a python-only .envrc from on-disk pyve.toml" {
    _config_venv
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
EOF
    # Simulate a stale registry (as if main() loaded an empty manifest).
    plugin_registry_reset
    run compose_project_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF '# >>> pyve:plugin:python:activate >>>' .envrc
    grep -qF 'export VIRTUAL_ENV="$PWD/.venv"' .envrc
}

@test "reload: picks up a node plugin that the stale registry was missing" {
    _config_venv
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.python]
[plugins.node]
path = "src/frontend"
[env.root]
purpose = "utility"
EOF
    # Stale registry holds ONLY python (as main() would for a pre-write
    # implicit-Python load). The reload must surface node too.
    plugin_registry_reset
    plugin_register python
    run compose_project_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF '# >>> pyve:plugin:python:activate >>>' .envrc
    grep -qF '# >>> pyve:plugin:node:activate >>>' .envrc
    grep -qF 'PATH_add "src/frontend/node_modules/.bin"' .envrc
}

@test "reload: writes the managed envelope + .envrc.prev semantics via compose_envrc" {
    _config_venv
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
EOF
    compose_project_envrc .envrc
    grep -qF '# <<< pyve:managed:end <<<' .envrc
}
