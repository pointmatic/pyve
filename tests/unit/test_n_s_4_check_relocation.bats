#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.4 — Relocate `check_environment` into the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation. First
# story of the N.p runtime quartet (check / status / run / test).
# `check_environment` + 3 `_check_*` private helpers + `show_check_help`
# move from lib/commands/check.sh into lib/plugins/python/plugin.sh;
# lib/commands/check.sh is deleted; the source block in pyve.sh is
# removed.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/check.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: check_environment + helpers + show_check_help live
# in lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.4: check_environment() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^check_environment\(\)' "$PLUGIN_FILE"
}

@test "N.s.4: _check_venv_backend() lives in plugin.sh" {
    grep -qE '^_check_venv_backend\(\)' "$PLUGIN_FILE"
}

@test "N.s.4: _check_micromamba_backend() lives in plugin.sh" {
    grep -qE '^_check_micromamba_backend\(\)' "$PLUGIN_FILE"
}

@test "N.s.4: _check_summary_and_exit() lives in plugin.sh" {
    grep -qE '^_check_summary_and_exit\(\)' "$PLUGIN_FILE"
}

@test "N.s.4: show_check_help() lives in plugin.sh" {
    grep -qE '^show_check_help\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location.
# ════════════════════════════════════════════════════════════════════

@test "N.s.4: lib/commands/check.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.4: pyve.sh contains no reference to lib/commands/check.sh" {
    run grep -F 'lib/commands/check.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
