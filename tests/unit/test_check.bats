#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `pyve check` subcommand (Story H.e.3).
#
# `pyve check` replaces the semantic of `pyve validate` (structured
# 0/1/2 exit codes for CI) and most of `pyve doctor` (diagnostics
# with one actionable next-step per failure). State reporting is
# H.e.4 (`pyve status`), not this command.
#
# Spec: docs/specs/phase-H-check-status-design.md §3.

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
# Help and dispatcher integration
#============================================================

@test "check: --help prints usage and exits 0" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve check"* ]]
    [[ "$output" == *"Diagnose"* ]]
}

@test "check: -h prints usage and exits 0" {
    run "$PYVE_SCRIPT" check -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve check"* ]]
}

@test "check: --help documents 0/1/2 exit codes" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"0"* ]]
    [[ "$output" == *"1"* ]]
    [[ "$output" == *"2"* ]]
}

# Story L.c — stale "coming in a later release" parenthetical post-shipping
# of `pyve status`. Help now points at status as a current command.
@test "check: --help points at 'pyve status' without 'coming' parenthetical" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve status"* ]]
    ! printf '%s' "$output" | grep -qi "coming in a later release"
}

# Story L.c — `pyve doctor` and `pyve validate` were hard-removed in v2.0;
# mentioning them in the See-also block is stale and misleading.
@test "check: --help does not advertise removed pyve doctor / pyve validate" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    ! printf '%s' "$output" | grep -qE "pyve doctor|pyve validate"
}

@test "check: appears in top-level pyve --help" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"check"* ]]
}

@test "check: PYVE_DISPATCH_TRACE shows correct dispatch" {
    PYVE_DISPATCH_TRACE=1 run "$PYVE_SCRIPT" check
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:check"* ]]
}

#============================================================
# Exit code 1 — errors (environment broken for pyve run / pyve test)
#============================================================

@test "check: exit 1 when .pyve/config is missing" {
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗"* ]] || [[ "$output" == *".pyve/config"* ]]
    [[ "$output" == *"pyve init"* ]]
}

@test "check: exit 1 when .pyve/config lacks backend" {
    create_pyve_config 'pyve_version: "1.0.0"'
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
    [[ "$output" == *"backend"* ]] || [[ "$output" == *"Backend"* ]]
}

@test "check: exit 1 when venv directory missing" {
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
    [[ "$output" == *".venv"* ]]
    [[ "$output" == *"pyve init"* ]]
}

@test "check: exit 1 when venv has no bin/python" {
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""
    mkdir -p .venv
    # No bin/python

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
}

#============================================================
# Exit code 2 — warnings (environment usable but drifting)
#============================================================

@test "check: exit 2 when pyve_version differs from current (drift)" {
    # Set up a functional-looking venv + config, with stale version
    create_pyve_config "backend: venv" "pyve_version: \"0.1.0\""
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python
    cat > .venv/pyvenv.cfg << EOF
home = $PWD/.venv/bin
version = 3.14.4
command = $PWD/.venv/bin/python3 -m venv $PWD/.venv
EOF
    touch .envrc .env

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *"0.1.0"* ]] || [[ "$output" == *"pyve update"* ]]
}

@test "check: exit 2 when .env is missing but otherwise OK" {
    create_pyve_config "backend: venv" "pyve_version: \"$(grep '^VERSION=' "$PYVE_SCRIPT" | cut -d'"' -f2)\""
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python
    cat > .venv/pyvenv.cfg << EOF
home = $PWD/.venv/bin
version = 3.14.4
command = $PWD/.venv/bin/python3 -m venv $PWD/.venv
EOF
    touch .envrc
    # No .env

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *".env"* ]]
    [[ "$output" == *"touch .env"* ]] || [[ "$output" == *"warn"* ]] || [[ "$output" == *"⚠"* ]]
}

@test "check: exit 2 when .envrc is missing" {
    create_pyve_config "backend: venv" "pyve_version: \"$(grep '^VERSION=' "$PYVE_SCRIPT" | cut -d'"' -f2)\""
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python
    cat > .venv/pyvenv.cfg << EOF
home = $PWD/.venv/bin
version = 3.14.4
command = $PWD/.venv/bin/python3 -m venv $PWD/.venv
EOF
    touch .env
    # No .envrc

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *".envrc"* ]]
}

#============================================================
# Escalation — errors never downgraded by subsequent warnings
#============================================================

@test "check: error status is not downgraded by subsequent warnings" {
    # Missing venv (error) + missing .env (warning) → status 1, not 2.
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""
    # No .venv, no .env
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
}

#============================================================
# Summary footer
#============================================================

@test "check: prints a summary footer with pass/warn/error counts" {
    run "$PYVE_SCRIPT" check
    # Regardless of outcome, look for the summary line.
    [[ "$output" == *"passed"* ]] || [[ "$output" == *"errors"* ]] || [[ "$output" == *"warnings"* ]]
}

#============================================================
# Actionable message discipline — at least one "pyve <cmd>" or "Run:"
# hint appears when there are failures
#============================================================

@test "check: failure output contains at least one actionable command" {
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
    # Actionable command signature: "pyve init", "pyve update", "touch ...", etc.
    [[ "$output" == *"pyve "* ]] || [[ "$output" == *"touch"* ]] || [[ "$output" == *"Run:"* ]]
}

#============================================================
# micromamba-specific checks (gated on backend == micromamba)
#============================================================

@test "check: micromamba backend — flags missing environment.yml" {
    create_pyve_config "backend: micromamba" "pyve_version: \"1.0.0\""
    # No environment.yml

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 1 ]
    [[ "$output" == *"environment.yml"* ]] || [[ "$output" == *"micromamba"* ]]
}

#============================================================
# Unknown flag
#============================================================

@test "check: unknown flag exits 1 with actionable error" {
    run "$PYVE_SCRIPT" check --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"--bogus"* ]]
}
