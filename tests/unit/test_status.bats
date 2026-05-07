#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `pyve status` subcommand (Story H.e.4).
#
# `pyve status` is the read-only state dashboard. NO exit code
# beyond 0 based on findings (an "environment is broken" reading
# is `pyve check`'s job). Three sections: Project / Environment /
# Integrations. Spec: docs/specs/phase-H-check-status-design.md §4.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    export CURRENT_VERSION
    CURRENT_VERSION="$(grep '^VERSION=' "$PYVE_SCRIPT" | head -1 | cut -d'"' -f2)"
    # Make sure terminal-color codes don't leak into output comparisons.
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Help and dispatcher integration
#============================================================

@test "status: --help prints usage and exits 0" {
    run "$PYVE_SCRIPT" status --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve status"* ]]
    [[ "$output" == *"snapshot"* ]] || [[ "$output" == *"dashboard"* ]] || [[ "$output" == *"state"* ]]
}

@test "status: -h prints usage and exits 0" {
    run "$PYVE_SCRIPT" status -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve status"* ]]
}

@test "status: --help notes read-only / exit-code-0 contract" {
    run "$PYVE_SCRIPT" status --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"read-only"* ]] || [[ "$output" == *"exit code"* ]] || [[ "$output" == *"pyve check"* ]]
}

@test "status: appears in top-level pyve --help" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"status"* ]]
}

@test "status: PYVE_DISPATCH_TRACE shows correct dispatch" {
    PYVE_DISPATCH_TRACE=1 run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:status"* ]]
}

#============================================================
# Exit code discipline — always 0 regardless of findings
#============================================================

@test "status: exit 0 when .pyve/config is missing (not a pyve project)" {
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
}

@test "status: exit 0 when venv is missing (drifting project)" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
}

@test "status: exit 0 when backend is missing from config (malformed)" {
    create_pyve_config 'pyve_version: "1.0.0"'
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
}

#============================================================
# Non-project fallback
#============================================================

@test "status: prints a friendly non-project message when .pyve/config absent" {
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Not a pyve"* ]] || [[ "$output" == *"not initialized"* ]] || [[ "$output" == *"pyve init"* ]]
}

#============================================================
# Section headers
#============================================================

@test "status: prints the top-level 'Pyve project status' title" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pyve project status"* ]]
}

@test "status: prints the three section headers" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project"* ]]
    [[ "$output" == *"Environment"* ]]
    [[ "$output" == *"Integrations"* ]]
}

#============================================================
# Project section content
#============================================================

@test "status: Project section shows backend name" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend"* ]]
    [[ "$output" == *"venv"* ]]
}

@test "status: Project section shows recorded pyve version" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.9.9"* ]]
}

@test "status: Project section notes version drift vs current" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    # Some signal that the recorded version is not the current pyve version.
    [[ "$output" == *"current:"* ]] || [[ "$output" == *"$CURRENT_VERSION"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"stale"* ]]
}

@test "status: Project section marks current version when matching" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"(current)"* ]]
}

#============================================================
# Environment section content — venv backend
#============================================================

@test "status: Environment section shows .venv path when venv backend" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python

    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *".venv"* ]]
}

@test "status: Environment section shows '(missing)' when venv not created" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    # No .venv
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing"* ]] || [[ "$output" == *"not found"* ]] || [[ "$output" == *"absent"* ]]
}

@test "status: Environment section shows Python version when bin/python exists" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    mkdir -p .venv/bin
    cat > .venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .venv/bin/python

    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.14.4"* ]]
}

#============================================================
# Project section: Python pin source — backend-aware (Story L.b)
#============================================================

@test "status: Project ▸ Python reads environment.yml pin for micromamba backend" {
    create_pyve_config "backend: micromamba" "pyve_version: \"$CURRENT_VERSION\"" "micromamba:" "  env_name: test-env"
    cat > environment.yml << 'YML'
name: test-env
channels:
  - conda-forge
dependencies:
  - python=3.12
  - numpy
YML
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.12"* ]]
    [[ "$output" == *"environment.yml"* ]]
    # Must NOT contradict by also reporting "not pinned" in the Project section.
    # ("environment.yml: present" line in Environment section is fine.)
    ! printf '%s' "$output" | awk '/^Project$/,/^Environment$/' | grep -q "not pinned"
}

@test "status: Project ▸ Python reports 'not pinned' for micromamba w/o environment.yml" {
    create_pyve_config "backend: micromamba" "pyve_version: \"$CURRENT_VERSION\"" "micromamba:" "  env_name: test-env"
    # No environment.yml.
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"not pinned"* ]]
}

@test "status: Project ▸ Python reports 'not pinned' for micromamba env.yml without python dep" {
    create_pyve_config "backend: micromamba" "pyve_version: \"$CURRENT_VERSION\"" "micromamba:" "  env_name: test-env"
    cat > environment.yml << 'YML'
name: test-env
channels:
  - conda-forge
dependencies:
  - numpy
  - scipy
YML
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    # Project section's Python row prints "not pinned" because env.yml lists
    # no python dependency.
    printf '%s' "$output" | awk '/^Project$/,/^Environment$/' | grep -q "not pinned"
}

@test "status: Project ▸ Python parses '- python =3.12.*' with whitespace and globs" {
    create_pyve_config "backend: micromamba" "pyve_version: \"$CURRENT_VERSION\"" "micromamba:" "  env_name: test-env"
    cat > environment.yml << 'YML'
name: test-env
dependencies:
  -  python = 3.12.*
YML
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.12"* ]]
    [[ "$output" == *"environment.yml"* ]]
}

@test "status: Project ▸ Python — venv backend ignores environment.yml" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    # Even if a stray environment.yml is present, venv backend MUST NOT use it
    # (venv pins via .tool-versions / .python-version / .pyve/config).
    cat > environment.yml << 'YML'
dependencies:
  - python=3.99
YML
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    # 3.99 from environment.yml must not appear in the Project Python row.
    ! printf '%s' "$output" | awk '/^Project$/,/^Environment$/' | grep -q "3.99"
}

@test "status: Project ▸ Python — venv backend still reads .tool-versions" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    printf 'python 3.14.4\n' > .tool-versions
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.14.4"* ]]
    [[ "$output" == *".tool-versions"* ]]
}

#============================================================
# Integrations section content
#============================================================

@test "status: Integrations section notes .envrc presence" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    touch .envrc
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *".envrc"* ]]
    [[ "$output" == *"present"* ]]
}

@test "status: Integrations section notes .envrc absence" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    # No .envrc
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *".envrc"* ]]
    [[ "$output" == *"missing"* ]] || [[ "$output" == *"absent"* ]] || [[ "$output" == *"not"* ]]
}

@test "status: Integrations section notes .env presence" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    touch .env
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *".env"* ]]
}

@test "status: Integrations section notes testenv presence when present" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    mkdir -p .pyve/testenv/venv/bin
    cat > .pyve/testenv/venv/bin/python << 'PY'
#!/usr/bin/env bash
echo "Python 3.14.4"
PY
    chmod +x .pyve/testenv/venv/bin/python

    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenv"* ]]
}

#============================================================
# Non-prompting invariant
#============================================================

@test "status: runs non-interactively (no prompts)" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run bash -c "'$PYVE_SCRIPT' status </dev/null"
    [ "$status" -eq 0 ]
}

#============================================================
# Unknown flag
#============================================================

@test "status: unknown flag exits 1 with actionable error" {
    run "$PYVE_SCRIPT" status --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"--bogus"* ]]
}

#============================================================
# NO_COLOR=1 — no ANSI escape sequences in output
#============================================================

@test "status: NO_COLOR=1 output contains no ANSI escape sequences" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""
    run "$PYVE_SCRIPT" status
    [ "$status" -eq 0 ]
    ! printf '%s' "$output" | grep -q $'\033'
}
