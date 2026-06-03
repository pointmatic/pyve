#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.1 — Relocate `init_project` into the Python plugin.
#
# Option 1 (per the N.s umbrella decision): whole-function relocation.
# `init_project` + every `_init_*` private helper + `show_init_help`
# move from lib/commands/init.sh into lib/plugins/python/plugin.sh;
# lib/commands/init.sh is deleted; the source block in pyve.sh is
# removed. Behavior preservation is verified by the unchanged full
# unit suite (1393+ ok baseline from N.r) plus the smoke regression
# in the story body — these tests only verify the new structural
# shape.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/init.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: init_project + every helper + show_init_help live
# in lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.1: init_project() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^init_project\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_run_project_guide_hooks() lives in plugin.sh" {
    grep -qE '^_init_run_project_guide_hooks\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_detect_backend_default() lives in plugin.sh" {
    grep -qE '^_init_detect_backend_default\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_detect_version_managers_available() lives in plugin.sh" {
    grep -qE '^_init_detect_version_managers_available\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_list_installed_python_versions() lives in plugin.sh" {
    grep -qE '^_init_list_installed_python_versions\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_detect_project_guide_present() lives in plugin.sh" {
    grep -qE '^_init_detect_project_guide_present\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_write_pyve_toml() lives in plugin.sh" {
    grep -qE '^_init_write_pyve_toml\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_validate_existing_manifest() lives in plugin.sh" {
    grep -qE '^_init_validate_existing_manifest\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_list_available_python_versions() lives in plugin.sh" {
    grep -qE '^_init_list_available_python_versions\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_wizard() lives in plugin.sh" {
    grep -qE '^_init_wizard\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_python_version() lives in plugin.sh" {
    grep -qE '^_init_python_version\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_venv() lives in plugin.sh" {
    grep -qE '^_init_venv\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_direnv_venv() lives in plugin.sh" {
    grep -qE '^_init_direnv_venv\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_direnv_micromamba() lives in plugin.sh" {
    grep -qE '^_init_direnv_micromamba\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_dotenv() lives in plugin.sh" {
    grep -qE '^_init_dotenv\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_gitignore() lives in plugin.sh" {
    grep -qE '^_init_gitignore\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: _init_print_next_steps() lives in plugin.sh" {
    grep -qE '^_init_print_next_steps\(\)' "$PLUGIN_FILE"
}

@test "N.s.1: show_init_help() lives in plugin.sh" {
    grep -qE '^show_init_help\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location: lib/commands/init.sh does not exist; pyve.sh
# no longer references it.
# ════════════════════════════════════════════════════════════════════

@test "N.s.1: lib/commands/init.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.1: pyve.sh contains no reference to lib/commands/init.sh" {
    run grep -F 'lib/commands/init.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
