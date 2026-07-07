#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Subphase P-1 (pyve.toml as the sole config source) — `pyve init` no longer
# writes `.pyve/config`; `pyve.toml` is the sole declaration it creates. The
# read-compat fallbacks + synthesis that keep existing v2 projects working are
# removed later in the bundle; this story only stops the *write*.

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

@test "init writes no 'cat > .pyve/config' heredoc in the Python plugin" {
    run grep -n 'cat > .pyve/config' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [ "$status" -ne 0 ]
}

@test "update on a pyve.toml-only project does not fail on the missing .pyve/config" {
    # A v3-native project has no `.pyve/config`. The update flow no longer has a
    # version-bump step (that machinery is removed), so it must run cleanly
    # rather than aborting with "Failed to update .pyve/config".
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
EOF
    [ ! -e .pyve/config ]
    run "$PYVE_SCRIPT" update
    [[ "$output" != *"Failed to update .pyve/config"* ]]
    [[ "$output" == *"[1/4]"* ]]
}
