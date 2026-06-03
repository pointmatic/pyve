#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.5 — Relocate `show_status` into the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation.
# `show_status` + 12 `_status_*` private helpers + `show_status_help`
# move from lib/commands/status.sh into lib/plugins/python/plugin.sh;
# lib/commands/status.sh is deleted; the source block in pyve.sh is
# removed.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/status.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: show_status + helpers + show_status_help live in
# lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.5: show_status() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^show_status\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_row() lives in plugin.sh" {
    grep -qE '^_status_row\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_header() lives in plugin.sh" {
    grep -qE '^_status_header\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_section_project() lives in plugin.sh" {
    grep -qE '^_status_section_project\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_configured_python() lives in plugin.sh" {
    grep -qE '^_status_configured_python\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_configured_python_venv() lives in plugin.sh" {
    grep -qE '^_status_configured_python_venv\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_configured_python_micromamba() lives in plugin.sh" {
    grep -qE '^_status_configured_python_micromamba\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_parse_env_yml_python_pin() lives in plugin.sh" {
    grep -qE '^_status_parse_env_yml_python_pin\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_section_environment() lives in plugin.sh" {
    grep -qE '^_status_section_environment\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_env_venv() lives in plugin.sh" {
    grep -qE '^_status_env_venv\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_venv_package_count() lives in plugin.sh" {
    grep -qE '^_status_venv_package_count\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_env_micromamba() lives in plugin.sh" {
    grep -qE '^_status_env_micromamba\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: _status_section_integrations() lives in plugin.sh" {
    grep -qE '^_status_section_integrations\(\)' "$PLUGIN_FILE"
}

@test "N.s.5: show_status_help() lives in plugin.sh" {
    grep -qE '^show_status_help\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location.
# ════════════════════════════════════════════════════════════════════

@test "N.s.5: lib/commands/status.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.5: pyve.sh contains no reference to lib/commands/status.sh" {
    run grep -F 'lib/commands/status.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
