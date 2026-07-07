#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# composed-init orchestrator seam.
#
# `compose_init` is the stack-agnostic entry point `pyve init` dispatches
# to. At N.av.1 it is a pure delegation to today's monolithic Python init
# hook (zero behavior change); N.av.2+ lift the orchestration tail into it.
# These tests pin the SEAM (existence + delegation + wiring), not init
# behavior (that stays covered by the existing init suite).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/init_composer.sh"
}

@test "compose_init is defined" {
    run declare -F compose_init
    assert_status_equals 0
}

@test "compose_init lives in lib/init_composer.sh" {
    grep -q 'compose_init()' "$PYVE_ROOT/lib/init_composer.sh"
}

@test "compose_init delegates to the python init hook, forwarding args" {
    # Stub the Python init hook; plugin_dispatch resolves it by name.
    python_pyve_plugin_init() { printf 'INIT-HOOK:%s\n' "$*"; }
    run compose_init --backend venv --python-version 3.13.7
    assert_status_equals 0
    assert_output_equals "INIT-HOOK:--backend venv --python-version 3.13.7"
}

@test "pyve.sh dispatches init through compose_init (not directly to the python hook)" {
    # The init arm calls compose_init; the direct plugin_dispatch is gone.
    grep -qE 'compose_init "\$@"' "$PYVE_ROOT/pyve.sh"
}

@test "pyve.sh sources lib/init_composer.sh explicitly" {
    grep -q 'source .*lib/init_composer.sh' "$PYVE_ROOT/pyve.sh"
}
