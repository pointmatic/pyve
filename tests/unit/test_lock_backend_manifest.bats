#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve.toml as the sole config source — `pyve lock`'s venv-rejection guard
# (Guard 1) resolves the backend from the manifest, so a v3-native venv project
# (pyve.toml with `backend = "venv"`, no `.pyve/config`) is rejected as
# "micromamba only" just like a v2-configured venv project. A v2 project
# resolves the same way: `manifest_load` synthesizes its root backend from
# `.pyve/config`.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

@test "lock: rejects a v3-native venv project (pyve.toml, no .pyve/config)" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
EOF
    [ ! -e .pyve/config ]
    run "$PYVE_SCRIPT" lock
    [ "$status" -eq 1 ]
    [[ "$output" == *"micromamba projects only"* ]]
}

@test "lock: still rejects a v2 venv project (.pyve/config, no pyve.toml)" {
    # Regression: the read-compat synthesis keeps the v2 path working.
    create_pyve_config "backend: venv"
    [ ! -e pyve.toml ]
    run "$PYVE_SCRIPT" lock
    [ "$status" -eq 1 ]
    [[ "$output" == *"micromamba projects only"* ]]
}

@test "lock: a micromamba manifest is not rejected by Guard 1" {
    # A v3 micromamba project with no environment.yml passes Guard 1 and trips
    # Guard 2 (environment.yml required) — proving micromamba is not mistaken
    # for venv.
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
EOF
    [ ! -e .pyve/config ]
    run "$PYVE_SCRIPT" lock
    [ "$status" -eq 1 ]
    [[ "$output" != *"micromamba projects only"* ]]
    [[ "$output" == *"environment.yml"* ]]
}
