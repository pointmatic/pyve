#!/usr/bin/env bats
# bats file_tags=check
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
    export PYVE_TEST_AUTOSCAFFOLD_TOML=1
    setup_pyve_env
    # Capture an absolute working python BEFORE create_test_dir cd's into a
    # temp dir with no version-manager pin (an asdf shim there errors "No
    # version is set"). manifest_load needs it to parse pyve.toml via the
    # tomllib helper. Harmless for v2 .pyve/config tests (synthesis is pure
    # bash, no python). Mirrors test_manifest.bats.
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
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

# composed `pyve check` collapses the ladder to two outcomes:
# 0 (no errors; pass or warn-only) and 2 (one or more errors).
@test "check: --help documents the 0 / 2 exit codes" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"0"* ]]
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
# Exit code 2 — errors (environment broken for pyve run / pyve test).
# the composed check uses exit 2 for any error (was 1).
#============================================================

@test "check: exit 2 when .pyve/config is missing" {
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *"✗"* ]] || [[ "$output" == *".pyve/config"* ]]
    [[ "$output" == *"pyve init"* ]]
}

@test "check: exit 2 when .pyve/config lacks backend" {
    create_pyve_config 'pyve_version: "1.0.0"'
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *"backend"* ]] || [[ "$output" == *"Backend"* ]]
}

@test "check: exit 2 when venv directory missing" {
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
    [[ "$output" == *".venv"* ]]
    [[ "$output" == *"pyve init"* ]]
}

@test "check: exit 2 when venv has no bin/python" {
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""
    mkdir -p .venv
    # No bin/python

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
}

#============================================================
# Exit code 0 — warnings only (environment usable but drifting).
# the composed check no longer fails CI on warnings.
#============================================================

@test "check: ignores a v2 pyve_version and reports no version row" {
    # A stale v2 `.pyve/config` pyve_version is no longer read — check does not
    # report version drift, and still exits 0 on a functional env.
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
    [ "$status" -eq 0 ]
    [[ "$output" != *"0.1.0"* ]]
    [[ "$output" != *"Pyve version:"* ]]
}

@test "check: exit 0 when .env is missing but otherwise OK" {
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
    [ "$status" -eq 0 ]
    [[ "$output" == *".env"* ]]
    [[ "$output" == *"touch .env"* ]] || [[ "$output" == *"warn"* ]] || [[ "$output" == *"⚠"* ]]
}

@test "check: exit 0 when .envrc is missing" {
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
    [ "$status" -eq 0 ]
    [[ "$output" == *".envrc"* ]]
}

#============================================================
# Escalation — errors never downgraded by subsequent warnings
#============================================================

@test "check: error status is not downgraded by subsequent warnings" {
    # Missing venv (error) + missing .env (warning) → error wins: exit 2.
    create_pyve_config "backend: venv" "pyve_version: \"1.0.0\""
    # No .venv, no .env
    run "$PYVE_SCRIPT" check
    [ "$status" -eq 2 ]
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
    [ "$status" -eq 2 ]
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
    [ "$status" -eq 2 ]
    [[ "$output" == *"environment.yml"* ]] || [[ "$output" == *"micromamba"* ]]
}

#============================================================
# N.bf.9: declarative conda-lock status in check (_check_conda_lock_status)
#============================================================
# Unit-tested directly with stubbed reporters because _check_micromamba_backend
# returns early when the micromamba binary is absent (which it may be on CI),
# so the conda-lock branch isn't reachable via a full subprocess `pyve check`.

@test "_check_conda_lock_status: declared + lock missing → warns (lock required)" {
    _check_warn() { printf 'WARN:%s|%s\n' "$1" "${2:-}"; }
    _check_pass() { printf 'PASS:%s\n' "$1"; }
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - conda-lock
YAML
    run _check_conda_lock_status
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"conda-lock.yml: missing"* ]]
    [[ "$output" == *"pyve lock"* ]]
}

@test "_check_conda_lock_status: NOT declared + lock missing → pass (not required)" {
    _check_warn() { printf 'WARN:%s|%s\n' "$1" "${2:-}"; }
    _check_pass() { printf 'PASS:%s\n' "$1"; }
    cat > environment.yml <<'YAML'
name: demo
dependencies:
  - python=3.11
YAML
    run _check_conda_lock_status
    [[ "$output" == *"PASS:"* ]]
    [[ "$output" == *"not required"* ]]
    [[ "$output" != *"WARN:"* ]]
}

#============================================================
# Story O.g — v3-native (pyve.toml-only) projects pass check.
# `pyve check` must read the v3 manifest, not gate on the v2
# `.pyve/config` file. A migrated project (pyve.toml present, no
# .pyve/config) was hard-failing "Configuration: .pyve/config missing".
#============================================================

@test "check: v3-native venv project (pyve.toml, no .pyve/config) passes" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
TOML
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python
    cat > .venv/pyvenv.cfg << EOF
home = $PWD/.venv/bin
version = 3.14.4
EOF
    touch .envrc .env

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend: venv"* ]]
    # Must not claim the v2 config is missing on a valid v3 project.
    ! printf '%s' "$output" | grep -q ".pyve/config missing"
}

@test "check: v3-native micromamba project gets past the config gate" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
TOML

    run "$PYVE_SCRIPT" check
    # The env isn't built, so check still fails downstream — but it must
    # get *past* Check 1/3 (recognize the project + backend), never
    # hard-error on a missing .pyve/config.
    [[ "$output" == *"Backend: micromamba"* ]]
    ! printf '%s' "$output" | grep -q ".pyve/config missing"
}

@test "check: v3-native project does not emit the misleading 'legacy project' version nudge" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
TOML
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python
    cat > .venv/pyvenv.cfg << EOF
home = $PWD/.venv/bin
version = 3.14.4
EOF
    touch .envrc .env

    run "$PYVE_SCRIPT" check
    [ "$status" -eq 0 ]
    # pyve.toml carries no recorded pyve_version; the "legacy project →
    # pyve update" nudge is a v2 .pyve/config concept and must not fire.
    ! printf '%s' "$output" | grep -q "legacy project"
}

#============================================================
# Unknown flag
#============================================================

@test "check: unknown flag exits 1 with actionable error" {
    run "$PYVE_SCRIPT" check --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"--bogus"* ]]
}
