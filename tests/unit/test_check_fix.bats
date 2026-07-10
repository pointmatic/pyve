#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve check --fix` — the heal engine (lib/heal.sh), non-destructive tier.
#
# Healing is check's verdicts acted upon: detect faults with the same
# runnability probes check reports from, enumerate the plan, then repair
# only with assent (`--yes`, or an interactive confirmation). Non-TTY
# without --yes is report-only — the engine never silently mutates.
#
# Fault classes covered here (the non-destructive tier — Pyve-owned
# hosting state, deterministically rebuildable):
#   toolchain-dead     — toolchain venv exists but cannot run
#   project-guide-dead — hosted console script exists but cannot run
#   shim-dangling      — ~/.local/bin/project-guide is a dead symlink
#
# NOT faults: never-provisioned hosting (optional by contract),
# project-managed project-guide (deps-source declaration → pyve defers),
# healthy-but-stale versions (staleness hints, never heal).

load ../helpers/test_helper

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/heal.sh"

    TEST_DIR="$(mktemp -d)"
    export HOME="$TEST_DIR/home"
    export XDG_DATA_HOME="$TEST_DIR/home/.local/share"
    mkdir -p "$HOME"
    unset PYVE_PYTHON PYVE_PROJECT_GUIDE_BIN
    export DEFAULT_PYTHON_VERSION="3.12.13"
    # Full-binary tests must build hosting fixtures under the version the
    # BINARY resolves (pyve.sh hardcodes its own DEFAULT_PYTHON_VERSION;
    # the exported unit-level value does not reach it).
    PYVE_BIN_PYVER="$(sed -n 's/^DEFAULT_PYTHON_VERSION="\(.*\)"/\1/p' "$PYVE_SCRIPT")"
    cd "$TEST_DIR"
    export NO_COLOR=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# --- fixtures -------------------------------------------------------------

_venv_dir() { pyve_toolchain_venv_dir; }

# A runnable stub at <path> that prints "<name> <version>".
_mk_runnable() {
    mkdir -p "$(dirname "$1")"
    printf '#!/usr/bin/env bash\necho "%s"\n' "$2" > "$1"
    chmod +x "$1"
}

# A dead-shebang executable at <path>: interpreter path that no longer
# exists — passes [[ -x ]], cannot exec (the corruption class).
_mk_dead() {
    mkdir -p "$(dirname "$1")"
    printf '#!%s/gone/python\nprint("never runs")\n' "$TEST_DIR" > "$1"
    chmod +x "$1"
}

_fixture_healthy_hosting() {
    _mk_runnable "$(_venv_dir)/bin/python" "Python 3.12.13"
    _mk_runnable "$(_venv_dir)/bin/project-guide" "project-guide 2.15.1"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(_venv_dir)/bin/project-guide" "$HOME/.local/bin/project-guide"
}

_fixture_dead_toolchain() {
    _mk_dead "$(_venv_dir)/bin/python"
    _mk_dead "$(_venv_dir)/bin/project-guide"
}

_fixture_dead_pg_only() {
    _mk_runnable "$(_venv_dir)/bin/python" "Python 3.12.13"
    _mk_dead "$(_venv_dir)/bin/project-guide"
}

_fixture_dangling_shim() {
    _fixture_healthy_hosting
    ln -sf "$TEST_DIR/gone/project-guide" "$HOME/.local/bin/project-guide"
}

# --- heal_plan: fault detection -------------------------------------------

@test "heal_plan: healthy hosting → empty plan" {
    _fixture_healthy_hosting
    run heal_plan
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "heal_plan: never-provisioned hosting is not a fault" {
    run heal_plan
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "heal_plan: dead toolchain venv → toolchain-dead" {
    _fixture_dead_toolchain
    run heal_plan
    [ "$status" -eq 0 ]
    [[ "$output" == toolchain-dead\|* ]]
}

@test "heal_plan: dead hosted project-guide under a runnable toolchain → project-guide-dead" {
    _fixture_dead_pg_only
    run heal_plan
    [[ "$output" == *project-guide-dead\|* ]]
    [[ "$output" != *toolchain-dead* ]]
}

@test "heal_plan: dangling shim with runnable hosting → shim-dangling" {
    _fixture_dangling_shim
    run heal_plan
    [[ "$output" == *shim-dangling\|* ]]
    [[ "$output" != *toolchain-dead* ]]
}

@test "heal_plan: absent shim (never linked) is not a fault" {
    _fixture_healthy_hosting
    rm -f "$HOME/.local/bin/project-guide"
    run heal_plan
    [ -z "$output" ]
}

@test "heal_plan: project-managed project-guide suppresses pg faults, not toolchain faults" {
    # A dead hosted pg under a project that declares project-guide in its
    # own deps → pyve defers ("not my department"): no pg fault.
    _fixture_dead_pg_only
    printf '[project]\nname = "x"\ndependencies = ["project-guide==2.0.20"]\n' > pyproject.toml
    run heal_plan
    [ -z "$output" ]
    # A dead TOOLCHAIN stays Pyve's own fault regardless of the deps pin.
    _fixture_dead_toolchain
    run heal_plan
    [[ "$output" == *toolchain-dead\|* ]]
}

# --- heal_run: plan-then-confirm frame -------------------------------------

@test "heal_run: healthy → 'Nothing to heal.'" {
    _fixture_healthy_hosting
    run heal_run 0
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to heal."* ]]
}

@test "heal_run: non-TTY without assent → report-only, no mutation" {
    _fixture_dangling_shim
    run heal_run 0
    [ "$status" -eq 0 ]
    [[ "$output" == *shim-dangling* ]]
    [[ "$output" == *"--yes"* ]]
    # The dangling shim was NOT touched.
    [ "$(readlink "$HOME/.local/bin/project-guide")" = "$TEST_DIR/gone/project-guide" ]
}

@test "heal_run: assent applies the shim re-link repair" {
    _fixture_dangling_shim
    run heal_run 1
    [ "$status" -eq 0 ]
    [ "$(readlink "$HOME/.local/bin/project-guide")" = "$(_venv_dir)/bin/project-guide" ]
}

@test "heal_run: assent on a dead toolchain removes the venv and re-provisions" {
    _fixture_dead_toolchain
    # Stub the provision verb: record the call, build a runnable venv.
    self_provision() {
        echo "self_provision" >> "$TEST_DIR/calls.log"
        _mk_runnable "$(_venv_dir)/bin/python" "Python 3.12.13"
        _mk_runnable "$(_venv_dir)/bin/project-guide" "project-guide 2.15.1"
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(_venv_dir)/bin/project-guide" "$HOME/.local/bin/project-guide"
        return 0
    }
    export -f self_provision _mk_runnable _venv_dir pyve_toolchain_venv_dir pyve_toolchain_root
    heal_run 1
    grep -q "self_provision" "$TEST_DIR/calls.log"
    # Idempotence: the rebuilt hosting probes runnable → nothing to heal.
    run heal_plan
    [ -z "$output" ]
}

@test "heal_run: assent on a dead hosted project-guide force-reinstalls and re-links" {
    _fixture_dead_pg_only
    # Stub the venv pip: log argv, then lay down a runnable console script.
    cat > "$(_venv_dir)/bin/pip" <<EOF
#!/usr/bin/env bash
echo "pip \$*" >> "$TEST_DIR/calls.log"
printf '#!/usr/bin/env bash\necho "project-guide 2.15.1"\n' > "$(_venv_dir)/bin/project-guide"
chmod +x "$(_venv_dir)/bin/project-guide"
EOF
    chmod +x "$(_venv_dir)/bin/pip"
    heal_run 1
    grep -q "force-reinstall" "$TEST_DIR/calls.log"
    run heal_plan
    [ -z "$output" ]
}

# --- pyve check --fix surface ----------------------------------------------

@test "check --fix: healthy hosting → '[heal]' section with 'Nothing to heal.'" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n\n[env.root]\nbackend = "none"\n' > pyve.toml
    export DEFAULT_PYTHON_VERSION="$PYVE_BIN_PYVER"
    _fixture_healthy_hosting
    run "$PYVE_SCRIPT" check --fix
    [[ "$output" == *"[heal]"* ]]
    [[ "$output" == *"Nothing to heal."* ]]
}

@test "check without --fix: no [heal] section (behavior unchanged)" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n\n[env.root]\nbackend = "none"\n' > pyve.toml
    run "$PYVE_SCRIPT" check
    [[ "$output" != *"[heal]"* ]]
}

@test "check --yes without --fix: rejected with a precise error" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n\n[env.root]\nbackend = "none"\n' > pyve.toml
    run "$PYVE_SCRIPT" check --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"--fix"* ]]
}

@test "check --fix in non-TTY without --yes: reports the plan, never mutates" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n\n[env.root]\nbackend = "none"\n' > pyve.toml
    export DEFAULT_PYTHON_VERSION="$PYVE_BIN_PYVER"
    _fixture_dangling_shim
    run "$PYVE_SCRIPT" check --fix
    [[ "$output" == *shim-dangling* ]]
    [ "$(readlink "$HOME/.local/bin/project-guide")" = "$TEST_DIR/gone/project-guide" ]
}

@test "check --fix --yes: applies the repair end-to-end" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n\n[env.root]\nbackend = "none"\n' > pyve.toml
    export DEFAULT_PYTHON_VERSION="$PYVE_BIN_PYVER"
    _fixture_dangling_shim
    run "$PYVE_SCRIPT" check --fix --yes
    [ "$(readlink "$HOME/.local/bin/project-guide")" = "$(_venv_dir)/bin/project-guide" ]
    [[ "$output" == *"healed"* ]]
}

@test "check --help documents --fix and --yes" {
    run "$PYVE_SCRIPT" check --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--fix"* ]]
    [[ "$output" == *"--yes"* ]]
}
