#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `pyve python` nested subcommand (Story H.e.6).
#
# v1.x: `pyve python set <ver>` and `pyve python show` are
# available alongside the legacy `pyve python-version <ver>`
# command.
# v2.0:  `pyve python-version` emits a deprecation warning and
# delegates to `pyve python set`.
# v3.0:  `pyve python-version` removed.
#
# Spec: docs/specs/phase-H-cli-refactor-design.md §4.2, D1.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Top-level dispatch + help
#============================================================

@test "python: 'pyve python --help' prints usage and exits 0" {
    run "$PYVE_SCRIPT" python --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve python"* ]]
    [[ "$output" == *"set"* ]]
    [[ "$output" == *"show"* ]]
}

@test "python: 'pyve python -h' prints usage and exits 0" {
    run "$PYVE_SCRIPT" python -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve python"* ]]
}

@test "python: appears in top-level pyve --help" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"python"* ]]
}

@test "python: PYVE_DISPATCH_TRACE shows correct dispatch" {
    PYVE_DISPATCH_TRACE=1 run "$PYVE_SCRIPT" python set 3.13.7
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:python"* ]]
}

#============================================================
# `pyve python` with no subcommand — actionable error
#============================================================

@test "python: no subcommand exits 1 with actionable error" {
    run "$PYVE_SCRIPT" python
    [ "$status" -eq 1 ]
    [[ "$output" == *"set"* ]] || [[ "$output" == *"show"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "python: unknown subcommand exits 1 with actionable error" {
    run "$PYVE_SCRIPT" python bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"bogus"* ]]
}

#============================================================
# `pyve python set <ver>` — validates argument like python-version
#============================================================

@test "python: 'python set' without version exits 1 with actionable error" {
    run "$PYVE_SCRIPT" python set
    [ "$status" -eq 1 ]
    [[ "$output" == *"version"* ]]
}

@test "python: 'python set 3.13.7.1' (invalid format) exits 1" {
    run "$PYVE_SCRIPT" python set 3.13.7.1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"format"* ]]
}

@test "python: 'python set abc' (non-numeric) exits 1" {
    run "$PYVE_SCRIPT" python set abc
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"format"* ]]
}

#============================================================
# `pyve python show` — reads the current configured version
#============================================================

@test "python: 'python show' on a fresh directory reports 'not pinned'" {
    run "$PYVE_SCRIPT" python show
    [ "$status" -eq 0 ]
    [[ "$output" == *"not pinned"* ]] || [[ "$output" == *"No Python"* ]]
}

@test "python: 'python show' reads .tool-versions when present" {
    echo "python 3.13.7" > .tool-versions
    run "$PYVE_SCRIPT" python show
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.13.7"* ]]
    [[ "$output" == *".tool-versions"* ]]
}

@test "python: 'python show' reads .python-version when present" {
    echo "3.12.10" > .python-version
    run "$PYVE_SCRIPT" python show
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.12.10"* ]]
    [[ "$output" == *".python-version"* ]]
}

@test "python: 'python show' prefers .tool-versions over .python-version" {
    echo "python 3.13.7" > .tool-versions
    echo "3.12.10" > .python-version
    run "$PYVE_SCRIPT" python show
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.13.7"* ]]
    [[ "$output" != *"3.12.10"* ]]
}

@test "python: 'python show' falls back to .pyve/config when no version files" {
    # Story K.d backfill (K.a.3 audit gap 2). show_python_version's third
    # branch reads python.version from .pyve/config when neither
    # .tool-versions nor .python-version exists.
    create_pyve_config "backend: venv" "python:" "  version: 3.11.9"
    run "$PYVE_SCRIPT" python show
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.11.9"* ]]
    [[ "$output" == *".pyve/config"* ]]
}

@test "python: 'python show' rejects extra positional arguments" {
    # Story K.d backfill (K.a.3 audit gap 3). The `python show <extra>`
    # path emits an actionable error and exits 1.
    run "$PYVE_SCRIPT" python show oops
    [ "$status" -eq 1 ]
    [[ "$output" == *"takes no arguments"* ]] || [[ "$output" == *"oops"* ]]
}

#============================================================
# Backward compatibility — old `pyve python-version <ver>` still works
#============================================================

@test "python-version: legacy command still exits 1 on invalid version" {
    run "$PYVE_SCRIPT" python-version 3.13.7.1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"format"* ]]
}

@test "python-version: legacy command no longer routable (Story J.d)" {
    # Pre-v2.3.0 the `python-version)` case arm delegated to `python set`.
    # Story J.d ripped the alias; --help (and any other invocation) now
    # hit the dispatcher's unknown-command arm.
    run "$PYVE_SCRIPT" python-version --help
    [ "$status" -ne 0 ]
}

#============================================================
# Top-level --help lists both forms
#============================================================

@test "python: top-level --help mentions 'python set' / 'python show'" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"python set"* ]] || [[ "$output" == *"python show"* ]]
}
