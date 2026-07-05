#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# One meaning each for --yes / --force across the destructive
# commands. `--yes`/`-y` = "skip the confirmation prompt" (uniform). `--force`
# = "override a refusal / escalate to destructive" — NOT a prompt-skip
# synonym. The purge family standardizes on `--yes`; `--force`-as-prompt-skip
# is a deprecated alias that warns (for one release).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export NO_COLOR=1
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
}

teardown() {
    cleanup_test_dir
}

# ---- pyve purge -----------------------------------------------------

@test "pyve purge --yes: prompt-skip, no deprecation warning" {
    run "$PYVE_SCRIPT" purge --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"deprecated"* ]]
}

@test "pyve purge -y: accepted, no deprecation warning" {
    run "$PYVE_SCRIPT" purge -y
    [ "$status" -eq 0 ]
    [[ "$output" != *"deprecated"* ]]
}

@test "pyve purge --force: still works but warns and points at --yes" {
    run "$PYVE_SCRIPT" purge --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"deprecated"* ]]
    [[ "$output" == *"--yes"* ]]
}

# ---- pyve env purge (no-arg sweep) ----------------------------------

@test "pyve env purge --yes: accepted as the prompt-skip flag" {
    run "$PYVE_SCRIPT" env purge --yes
    [[ "$output" != *"Unknown"* ]]
    [[ "$output" != *"nknown flag"* ]]
    [[ "$output" != *"deprecated"* ]]
}

@test "pyve env purge --force: still works but warns (deprecated prompt-skip)" {
    run "$PYVE_SCRIPT" env purge --force
    [[ "$output" == *"deprecated"* ]]
}

# ---- pyve env prune -------------------------------------------------

@test "pyve env prune --yes: accepted as the prompt-skip flag" {
    run "$PYVE_SCRIPT" env prune --yes
    [[ "$output" != *"Unknown prune"* ]]
    [[ "$output" != *"deprecated"* ]]
}

@test "pyve env prune --force: still works but warns (deprecated prompt-skip)" {
    run "$PYVE_SCRIPT" env prune --force
    [[ "$output" == *"deprecated"* ]]
}
