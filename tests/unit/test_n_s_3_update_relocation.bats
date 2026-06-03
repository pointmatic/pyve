#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.3 — Relocate `update_project` into the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation.
# `update_project` + `_update_migrate_legacy_layout` + `show_update_help`
# move from lib/commands/update.sh into lib/plugins/python/plugin.sh;
# lib/commands/update.sh is deleted; the source block in pyve.sh is
# removed. Behavior preservation is verified by the unchanged full
# unit suite (1423 ok baseline from N.s.2) plus the smoke regression
# in the story body.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/update.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: update_project + helper + show_update_help live in
# lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.3: update_project() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^update_project\(\)' "$PLUGIN_FILE"
}

@test "N.s.3: _update_migrate_legacy_layout() lives in plugin.sh" {
    grep -qE '^_update_migrate_legacy_layout\(\)' "$PLUGIN_FILE"
}

@test "N.s.3: show_update_help() lives in plugin.sh" {
    grep -qE '^show_update_help\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location: lib/commands/update.sh does not exist; pyve.sh
# no longer references it.
# ════════════════════════════════════════════════════════════════════

@test "N.s.3: lib/commands/update.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.3: pyve.sh contains no reference to lib/commands/update.sh" {
    run grep -F 'lib/commands/update.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
