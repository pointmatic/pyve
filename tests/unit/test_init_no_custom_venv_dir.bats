#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# v3 has no per-project venv-dir override: `pyve init` always uses `.venv`,
# and a positional argument is a hard error (not a silent fallback). The v2
# `pyve init <dir>` custom-venv-dir knob was retired with `.pyve/config`;
# leaving it half-wired produced a broken project (venv created at the custom
# dir but `.envrc`/`.gitignore`/`purge` all target `.venv`).

load ../helpers/test_helper

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

@test "init: rejects a positional argument (no custom venv dir in v3)" {
    run "$PYVE_SCRIPT" init somedir
    [ "$status" -ne 0 ]
    [[ "$output" == *"positional"* ]] || [[ "$output" == *"Unexpected argument"* ]]
    # Must fail fast at arg-parse — never create a custom venv dir.
    [ ! -d somedir ]
    [ ! -d .venv ]
}

@test "purge: rejects a positional argument" {
    run "$PYVE_SCRIPT" purge somedir --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"positional"* ]] || [[ "$output" == *"Unexpected argument"* ]]
}
