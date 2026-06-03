#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.2 — Relocate `purge_project` into the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation.
# `purge_project` + every `_purge_*` private helper + `show_purge_help`
# move from lib/commands/purge.sh into lib/plugins/python/plugin.sh;
# lib/commands/purge.sh is deleted; the source block in pyve.sh is
# removed. Behavior preservation is verified by the unchanged full
# unit suite (1413 ok baseline from N.s.1) plus the smoke regression
# in the story body.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/purge.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: purge_project + every helper + show_purge_help live
# in lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.2: purge_project() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^purge_project\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: _purge_version_file() lives in plugin.sh" {
    grep -qE '^_purge_version_file\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: _purge_venv() lives in plugin.sh" {
    grep -qE '^_purge_venv\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: _purge_pyve_dir() lives in plugin.sh" {
    grep -qE '^_purge_pyve_dir\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: _purge_envrc() lives in plugin.sh" {
    grep -qE '^_purge_envrc\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: _purge_dotenv() lives in plugin.sh" {
    grep -qE '^_purge_dotenv\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: _purge_gitignore() lives in plugin.sh" {
    grep -qE '^_purge_gitignore\(\)' "$PLUGIN_FILE"
}

@test "N.s.2: show_purge_help() lives in plugin.sh" {
    grep -qE '^show_purge_help\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location: lib/commands/purge.sh does not exist; pyve.sh
# no longer references it.
# ════════════════════════════════════════════════════════════════════

@test "N.s.2: lib/commands/purge.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.2: pyve.sh contains no reference to lib/commands/purge.sh" {
    run grep -F 'lib/commands/purge.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
