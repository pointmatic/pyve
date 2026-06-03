#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.s.7 — Relocate `test_tests` into the Python plugin.
#
# Option 1 (per the N.s umbrella): whole-function relocation.
# `test_tests` + 4 `_test_*` private helpers move from
# lib/commands/test.sh into lib/plugins/python/plugin.sh;
# lib/commands/test.sh is deleted; the source block in pyve.sh is
# removed. This transient per-story placeholder will be consolidated
# into a single structural-invariant test in N.s.9.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PLUGIN_FILE="$PYVE_ROOT/lib/plugins/python/plugin.sh"
    OLD_FILE="$PYVE_ROOT/lib/commands/test.sh"
    PYVE_SH="$PYVE_ROOT/pyve.sh"
}

# ════════════════════════════════════════════════════════════════════
# In-new-location: test_tests + 4 _test_* helpers live in
# lib/plugins/python/plugin.sh.
# ════════════════════════════════════════════════════════════════════

@test "N.s.7: test_tests() lives in lib/plugins/python/plugin.sh" {
    grep -qE '^test_tests\(\)' "$PLUGIN_FILE"
}

@test "N.s.7: _test_has_pytest() lives in plugin.sh" {
    grep -qE '^_test_has_pytest\(\)' "$PLUGIN_FILE"
}

@test "N.s.7: _test_env_has_pytest() lives in plugin.sh" {
    grep -qE '^_test_env_has_pytest\(\)' "$PLUGIN_FILE"
}

@test "N.s.7: _test_install_pytest_into_testenv() lives in plugin.sh" {
    grep -qE '^_test_install_pytest_into_testenv\(\)' "$PLUGIN_FILE"
}

@test "N.s.7: _test_run_one_env() lives in plugin.sh" {
    grep -qE '^_test_run_one_env\(\)' "$PLUGIN_FILE"
}

# ════════════════════════════════════════════════════════════════════
# Not-in-old-location: lib/commands/test.sh does not exist; pyve.sh
# no longer references it.
# ════════════════════════════════════════════════════════════════════

@test "N.s.7: lib/commands/test.sh does not exist" {
    [ ! -e "$OLD_FILE" ]
}

@test "N.s.7: pyve.sh contains no reference to lib/commands/test.sh" {
    run grep -F 'lib/commands/test.sh' "$PYVE_SH"
    [ "$status" -ne 0 ]
}
