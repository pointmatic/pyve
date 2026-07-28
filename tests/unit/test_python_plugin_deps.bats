#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Python plugin — dependency installation
#
# `_python_plugin_pyproject_declares_installable` and
# `_python_plugin_prompt_install_deps` are Python-specific (pyproject /
# pip / editable install), so they live with the Python plugin, not the
# general core — mirroring the Node plugin owning its pnpm/npm install.
# (Relocated from lib/utils.sh; behavior unchanged.)
#============================================================

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

#============================================================
# _python_plugin_prompt_install_deps — pip_cmd resolution
#============================================================

@test "_python_plugin_prompt_install_deps: venv backend uses env_path/bin/pip, not bare pip" {
    # Create a pyproject.toml so the function has something to install
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
version = "0.1.0"
dependencies = []
EOF

    # Create a fake venv with a pip stub that records its invocation
    local fake_venv="$TEST_DIR/.venv"
    mkdir -p "$fake_venv/bin"
    cat > "$fake_venv/bin/pip" << 'STUB'
#!/usr/bin/env bash
echo "VENV_PIP_CALLED: $0 $*"
STUB
    chmod +x "$fake_venv/bin/pip"

    # Also put a bare "pip" on PATH that records if IT gets called (the bug)
    local fake_bin="$TEST_DIR/fake_bin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/pip" << 'STUB'
#!/usr/bin/env bash
echo "BARE_PIP_CALLED: $0 $*"
STUB
    chmod +x "$fake_bin/pip"
    export PATH="$fake_bin:$PATH"

    # Run in auto-install mode to skip interactive prompt
    PYVE_AUTO_INSTALL_DEPS=1 run _python_plugin_prompt_install_deps "venv" "$fake_venv"
    [ "$status" -eq 0 ]

    # The venv pip should have been called
    [[ "$output" == *"VENV_PIP_CALLED"* ]]

    # The bare pip should NOT have been called
    [[ "$output" != *"BARE_PIP_CALLED"* ]]
}

@test "_python_plugin_prompt_install_deps: venv backend without env_path returns error" {
    # When no env_path is passed for venv backend, the function should
    # return 1 with a warning instead of falling back to bare pip.
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
version = "0.1.0"
dependencies = []
EOF

    PYVE_AUTO_INSTALL_DEPS=1 run _python_plugin_prompt_install_deps "venv"
    [ "$status" -eq 1 ]
    [[ "$output" == *"env_path not provided"* ]]
}

#============================================================
# _python_plugin_pyproject_declares_installable — gate the offer
#============================================================
# A pyproject.toml that only carries tool config (e.g. [tool.ruff]) has
# nothing `pip install -e .` can build; offering the install buries init
# in a setuptools auto-discovery failure (flat-layout app projects).

@test "_python_plugin_pyproject_declares_installable: tool-config-only pyproject → non-installable" {
    printf '[tool.ruff]\nline-length = 100\n' > pyproject.toml
    run _python_plugin_pyproject_declares_installable
    [ "$status" -ne 0 ]
}

@test "_python_plugin_pyproject_declares_installable: [project] table → installable" {
    printf '[project]\nname = "demo"\nversion = "0.1.0"\n' > pyproject.toml
    run _python_plugin_pyproject_declares_installable
    [ "$status" -eq 0 ]
}

@test "_python_plugin_pyproject_declares_installable: [build-system] only → installable" {
    printf '[build-system]\nrequires = ["setuptools"]\n' > pyproject.toml
    run _python_plugin_pyproject_declares_installable
    [ "$status" -eq 0 ]
}

@test "_python_plugin_pyproject_declares_installable: tool-config pyproject + setup.py → installable (legacy layout)" {
    printf '[tool.ruff]\nline-length = 100\n' > pyproject.toml
    touch setup.py
    run _python_plugin_pyproject_declares_installable
    [ "$status" -eq 0 ]
}

@test "_python_plugin_pyproject_declares_installable: no pyproject.toml → non-installable" {
    run _python_plugin_pyproject_declares_installable
    [ "$status" -ne 0 ]
}

@test "_python_plugin_prompt_install_deps: tool-config-only pyproject is never offered" {
    printf '[tool.ruff]\nline-length = 100\n' > pyproject.toml
    mkdir -p .venv/bin && printf '#!/bin/sh\nexit 0\n' > .venv/bin/pip && chmod +x .venv/bin/pip
    # No requirements.txt → with the pyproject gated out, there is nothing
    # to install and no prompt may reach stdin.
    run _python_plugin_prompt_install_deps "venv" "$PWD/.venv" </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" != *"pyproject.toml"* ]]
}
