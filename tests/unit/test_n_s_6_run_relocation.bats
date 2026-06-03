#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.6 — Relocate `run_command` into the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation.
# `run_command` (the entire surface of lib/commands/run.sh — no
# private helpers, no help-block function) moves into
# lib/plugins/python/plugin.sh; lib/commands/run.sh is deleted; the
# source block in pyve.sh is removed.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/run.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

@test "N.s.6: run_command() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^run_command\(\)' "$PLUGIN_FILE"
}

@test "N.s.6: lib/commands/run.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.6: pyve.sh contains no reference to lib/commands/run.sh" {
    run grep -F 'lib/commands/run.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
