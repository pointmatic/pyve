#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.8 — Relocate `python_command` namespace dispatcher into
# the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation. The
# `pyve python <sub>` namespace dispatcher (`python_command`) and its
# help block (`show_python_help`) move from lib/commands/python.sh
# into lib/plugins/python/plugin.sh; lib/commands/python.sh is
# deleted; the source block in pyve.sh is removed. The leaf functions
# (`python_set` / `python_show`) were already relocated under N.p
# Option (a); N.s.8 completes the namespace.
#
# Transient per-story placeholder slated for N.s.9 consolidation.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/python.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: python_command + show_python_help live in
# lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.8: python_command() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^python_command\(\)' "$PLUGIN_FILE"
}

@test "N.s.8: show_python_help() lives in plugin.sh" {
    grep -qE '^show_python_help\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location: lib/commands/python.sh does not exist; pyve.sh
# no longer references it.
# ════════════════════════════════════════════════════════════════════

@test "N.s.8: lib/commands/python.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.8: pyve.sh contains no reference to lib/commands/python.sh" {
    run grep -F 'lib/commands/python.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
