#!/usr/bin/env bats
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the `pyve update` subcommand (Story H.e.2).
#
# `pyve update` is the non-destructive upgrade path: it refreshes
# managed files + .pyve/config but NEVER rebuilds the venv. See
# docs/specs/phase-H-cli-refactor-design.md §4.3 for the spec.
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    export CURRENT_VERSION
    CURRENT_VERSION="$(grep '^VERSION=' "$PYVE_SCRIPT" | head -1 | cut -d'"' -f2)"
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Dispatcher: the command exists and has help
#============================================================

@test "update: --help prints usage and exits 0" {
    run "$PYVE_SCRIPT" update --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve update"* ]]
    [[ "$output" == *"Non-destructive upgrade"* ]]
}

@test "update: -h prints usage and exits 0" {
    run "$PYVE_SCRIPT" update -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve update"* ]]
}

#============================================================
# Preconditions
#============================================================

@test "update: fails with exit 1 when neither pyve.toml nor .pyve/config exists" {
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 1 ]
    [[ "$output" == *"No pyve.toml or .pyve/config found"* ]]
    [[ "$output" == *"pyve init"* ]]
}

@test "update: a pyve.toml-only project (no .pyve/config) passes the presence gate" {
    # v3-native shape: the presence gate must recognize the manifest, so a
    # project with pyve.toml and no .pyve/config is not turned away as
    # "uninitialized". (The run still trips later on the config-write step,
    # dropped when Subphase P-1 stops writing `.pyve/config` — so this asserts
    # only that the presence gate passes.)
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
EOF
    [ ! -e .pyve/config ]
    run "$PYVE_SCRIPT" update
    [[ "$output" != *"requires an initialized project"* ]]
    [[ "$output" != *"No pyve.toml or .pyve/config found"* ]]
}

@test "update: fails with exit 1 when the backend is undeterminable (manifest and config both empty)" {
    create_pyve_config 'pyve_version: "0.1.0"'
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not determine the project backend"* ]]
}

@test "update: resolves the backend from pyve.toml when .pyve/config omits it" {
    # v3-native shape: the presence gate is satisfied by a .pyve/config that
    # only carries pyve_version, while the backend lives in the manifest.
    # The init-guard backend read must resolve from the manifest, so update
    # gets *past* the guard into the update body rather than aborting with
    # "Could not determine the project backend".
    #
    # Scope note: the run does not complete — a later `.pyve/config`-rewrite
    # step still expects a `backend:` line in the config (config-write
    # machinery dropped when Subphase P-1 stops writing `.pyve/config`). This
    # asserts only the manifest-first backend read; it does not assert exit 0.
    create_pyve_config 'pyve_version: "0.9.9"'
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
EOF
    run "$PYVE_SCRIPT" update
    [[ "$output" != *"Could not determine the project backend"* ]]
    [[ "$output" == *"[1/5] pyve_version"* ]]
}

#============================================================
# Happy path — venv backend
#============================================================

@test "update: venv backend — bumps pyve_version in .pyve/config" {
    create_pyve_config 'backend: venv' 'pyve_version: "0.9.9"'

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]

    local recorded
    recorded="$(grep '^pyve_version:' .pyve/config | cut -d'"' -f2)"
    [ "$recorded" = "$CURRENT_VERSION" ]
}

@test "update: venv backend — no-op bump when already at current version" {
    create_pyve_config "backend: venv" "pyve_version: \"$CURRENT_VERSION\""

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"already current"* ]] || [[ "$output" == *"$CURRENT_VERSION"* ]]
}

@test "update: venv backend — adds pyve_version when not recorded" {
    create_pyve_config "backend: venv"

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    grep -q "^pyve_version:" .pyve/config
}

@test "update: venv backend — refreshes .gitignore Pyve section" {
    create_pyve_config "backend: venv"
    # Start with a .gitignore missing the Pyve template
    cat > .gitignore << 'EOF'
# User section
my-secret-file
EOF

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]

    # Pyve-managed section now present.
    grep -q "# >>> pyve:managed:gitignore >>>" .gitignore
    grep -q "__pycache__" .gitignore
    # User section preserved (carried below the managed section).
    grep -q "my-secret-file" .gitignore
}

@test "update: venv-init'd project gains whole-.pyve/ ignore after update (H.e.2a)" {
    # Regression for H.e.2a: a project originally venv-init'd with the
    # pre-fix template would have .gitignore missing any .pyve/ state
    # ignore. After `pyve update`, the refreshed template must ignore the
    # whole .pyve/ tree so a later micromamba env dropping into
    # .pyve/envs/ — or the migrator's .pyve/.v2-legacy/ backup — stays out
    # of git. (The earlier enumerated `.pyve/envs` line was widened to
    # `.pyve/` because anchored subdir patterns miss nested state.)
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    cat > .gitignore << 'EOF'
# Pyve virtual environment
.pyve/testenv
.envrc
.env
.venv
EOF

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]

    # The whole .pyve/ tree must now be ignored.
    run grep -qxF ".pyve/" .gitignore
    [ "$status" -eq 0 ]
}

@test "update: preserves recorded backend (does not change it)" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]

    local backend
    backend="$(grep '^backend:' .pyve/config | awk '{print $2}')"
    [ "$backend" = "venv" ]
}

#============================================================
# Non-invariants — update must not touch venv/user state
#============================================================

@test "update: does NOT create .venv" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [ ! -d .venv ]
}

@test "update: does NOT create .env or .envrc" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [ ! -f .env ]
    [ ! -f .envrc ]
}

@test "update: does NOT create .vscode/settings.json when absent" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [ ! -f .vscode/settings.json ]
}

@test "update: leaves existing .venv directory untouched" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    mkdir -p .venv/bin
    echo "pre-existing" > .venv/marker.txt

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [ -f .venv/marker.txt ]
    [ "$(cat .venv/marker.txt)" = "pre-existing" ]
}

@test "update: leaves existing .env untouched" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    echo "SECRET=shh" > .env

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [ "$(cat .env)" = "SECRET=shh" ]
}

#============================================================
# Non-prompting invariant — runs with no stdin
#============================================================

@test "update: runs non-interactively (no prompt even without CI=)" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    # /dev/null as stdin → if update prompts, `read` sees EOF and
    # either hangs (test times out) or accepts empty input.
    run bash -c "'$PYVE_SCRIPT' update </dev/null"
    [ "$status" -eq 0 ]
}

#============================================================
# project-guide flag
#============================================================

@test "update: --no-project-guide prints skip message" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    touch .project-guide.yml

    run "$PYVE_SCRIPT" update --no-project-guide
    [ "$status" -eq 0 ]
    # Step framing (Story L.j) renders the skip as
    # "[5/5] project-guide refresh skipped (--no-project-guide)".
    [[ "$output" == *"--no-project-guide"* ]] && [[ "$output" == *"skip"* ]]
}

@test "update: project-guide refresh is a no-op when .project-guide.yml absent" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    # No project-guide activity message
    [[ "$output" != *"project-guide update"* ]]
}

#============================================================
# Unknown flag
#============================================================

@test "update: unknown flag exits 1 with actionable error" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""

    run "$PYVE_SCRIPT" update --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"--bogus"* ]]
}

#============================================================
# Dispatcher integration
#============================================================

@test "update: appears in top-level pyve --help" {
    run "$PYVE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"update"* ]]
}

#============================================================
# Step counter framing (Story L.j)
#============================================================

@test "update: prints [1/5] step header for pyve_version step" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"[1/5]"* ]]
    [[ "$output" == *"pyve_version"* ]]
}

@test "update: prints all five [N/5] step headers in sequence" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"[1/5]"* ]]
    [[ "$output" == *"[2/5]"* ]]
    [[ "$output" == *"[3/5]"* ]]
    [[ "$output" == *"[4/5]"* ]]
    [[ "$output" == *"[5/5]"* ]]
}

@test "update: [3/5] .envrc step skips cleanly when no .envrc exists" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"[3/5]"* ]]
    [[ "$output" == *".envrc"* ]]
}

@test "update: emits a footer-box close after the last step" {
    create_pyve_config "backend: venv" "pyve_version: \"0.9.9\""
    run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    # footer_box emits a rounded-corner glyph (e.g. ╰) — when NO_COLOR
    # is set the glyph stays but the ANSI styling drops. Either way
    # at least one footer line should be present.
    [[ "$output" == *"╰"* ]] || [[ "$output" == *"All done"* ]] || [[ "$output" == *"footer"* ]]
}

@test "update: PYVE_DISPATCH_TRACE shows correct dispatch" {
    PYVE_DISPATCH_TRACE=1 run "$PYVE_SCRIPT" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH:update"* ]]
}
