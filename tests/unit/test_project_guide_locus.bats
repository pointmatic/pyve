#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# project-guide orchestration is lifted to a stack-agnostic
# locus (lib/project_guide.sh), no longer welded inside the Python
# plugin's tail. These tests pin the SEAM (reachability + locus), not
# the install/scaffold behavior (that stays covered by test_project_guide.bats).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    # Source ONLY the stack-agnostic chain — deliberately NOT the Python
    # plugin — to prove the orchestration is reachable without it.
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/project_guide.sh"
}

@test "run_project_guide_orchestration is defined from lib/project_guide.sh (not Python-plugin-private)" {
    run declare -F run_project_guide_orchestration
    assert_status_equals 0
}

@test "the lifted orchestration lives in lib/project_guide.sh" {
    grep -q 'run_project_guide_orchestration()' "$PYVE_ROOT/lib/project_guide.sh"
}

@test "the welded _init_run_project_guide_hooks definition is gone from the Python plugin" {
    run grep -nE '^_init_run_project_guide_hooks\(\)' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [[ "$status" -ne 0 ]]
}

@test "the Python plugin calls the lifted orchestration, not the welded name" {
    grep -q 'run_project_guide_orchestration' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    # No non-comment occurrence of the welded name (a historical mention in
    # a `# ...` comment is allowed; a callsite is not).
    run grep -nE '^[^#]*_init_run_project_guide_hooks' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    [[ "$status" -ne 0 ]]
}

# Note: the N.au `_project_guide_resolve_host_env` identity seam was retired
# in N.aw — project-guide is globally hosted, so there is no per-project host
# env to resolve. (Its test was removed with the function.)

@test "pyve.sh sources lib/project_guide.sh explicitly" {
    grep -q 'source .*lib/project_guide.sh' "$PYVE_ROOT/pyve.sh"
}
