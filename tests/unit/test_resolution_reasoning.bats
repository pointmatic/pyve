#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Resolution reasoning: narrate where each managed command resolves from
# and why — the automated version of the manual four-layer PATH trace
# (direnv-activated `.venv/bin` shadowing the version-manager shims; a
# venv frozen to its creation-time interpreter while the pin moved on;
# a shim rejecting a command with "No version is set" under the active
# pin). lib/resolution_reasoning.sh holds the pure helpers (no mutation,
# no network, bounded probes); check_composer.sh renders the classified
# findings as the [resolution] section of `pyve check`.
#
# Managed-command set (plan §8.4): python + pip (Python projects) and
# project-guide (any-stack). Finding classes: ok / venv-pin-drift /
# no-version-set / broken-winner / not-found.

load ../helpers/test_helper

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/resolution_reasoning.sh"
    source "$PYVE_ROOT/lib/check_composer.sh"

    TEST_DIR="$(mktemp -d)"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
    unset ASDF_DATA_DIR PYENV_ROOT PYVE_VERBOSE
    REAL_PATH="$PATH"
    cd "$TEST_DIR"
    export NO_COLOR=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Create an executable stub: _mk_cmd <dir> <name> <echo-line> [<rc>]
_mk_cmd() {
    mkdir -p "$1"
    printf '#!/usr/bin/env bash\necho "%s"\nexit %s\n' "$3" "${4:-0}" > "$1/$2"
    chmod +x "$1/$2"
}

# ============================================================
# PATH-slot tracer
# ============================================================

@test "resolution_path_slots: lists every providing dir in PATH order (winner first)" {
    _mk_cmd "$TEST_DIR/a" mycmd "a"
    _mk_cmd "$TEST_DIR/b" mycmd "b"
    PATH="$TEST_DIR/a:$TEST_DIR/b:$REAL_PATH" run resolution_path_slots mycmd
    [ "$status" -eq 0 ]
    [[ "$output" == *"$TEST_DIR/a"$'\n'"$TEST_DIR/b" ]]
}

@test "resolution_path_slots: empty for a command nowhere on PATH" {
    run resolution_path_slots pyve-no-such-cmd-xyz
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================
# Slot classifier
# ============================================================

@test "classify: version-manager shim dirs (asdf, pyenv, ASDF_DATA_DIR override)" {
    run resolution_classify_slot "$HOME/.asdf/shims"
    [ "$output" = "vm-shim" ]
    run resolution_classify_slot "$HOME/.pyenv/shims"
    [ "$output" = "vm-shim" ]
    export ASDF_DATA_DIR="$TEST_DIR/custom-asdf"
    run resolution_classify_slot "$TEST_DIR/custom-asdf/shims"
    [ "$output" = "vm-shim" ]
}

@test "classify: local-bin, project-env (venv + conda slot), system" {
    run resolution_classify_slot "$HOME/.local/bin"
    [ "$output" = "local-bin" ]
    run resolution_classify_slot "$PWD/.venv/bin"
    [ "$output" = "project-env" ]
    run resolution_classify_slot "$PWD/.pyve/envs/root/conda/bin"
    [ "$output" = "project-env" ]
    run resolution_classify_slot "/usr/bin"
    [ "$output" = "system" ]
}

# ============================================================
# resolution_analyze — classified findings
# ============================================================

@test "analyze: healthy winner → ok with probed version and slot class" {
    _mk_cmd "$TEST_DIR/sys" mycmd "mycmd 1.2.3"
    PATH="$TEST_DIR/sys:$REAL_PATH" run resolution_analyze mycmd
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == "ok|$TEST_DIR/sys/mycmd|system|1.2.3|" ]]
}

@test "analyze: command nowhere on PATH → not-found" {
    run resolution_analyze pyve-no-such-cmd-xyz
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == "not-found||||" ]]
}

@test "analyze: version-manager shim rejecting under the pin → no-version-set" {
    _mk_cmd "$HOME/.asdf/shims" project-guide "No version is set for command project-guide" 1
    PATH="$HOME/.asdf/shims:$REAL_PATH" run resolution_analyze project-guide
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == "no-version-set|$HOME/.asdf/shims/project-guide|vm-shim||" ]]
}

@test "analyze: winner exists but exec fails for another reason → broken-winner" {
    _mk_cmd "$TEST_DIR/sys" mycmd "boom" 1
    PATH="$TEST_DIR/sys:$REAL_PATH" run resolution_analyze mycmd
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == "broken-winner|$TEST_DIR/sys/mycmd|system||" ]]
}

@test "analyze: project-env winner off the declared pin → venv-pin-drift" {
    _mk_cmd "$PWD/.venv/bin" python "Python 3.14.4"
    PATH="$PWD/.venv/bin:$REAL_PATH" run resolution_analyze python 3.12.13
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == "venv-pin-drift|$PWD/.venv/bin/python|project-env|3.14.4|3.12.13" ]]
}

@test "analyze: project-env winner matching the pin → ok" {
    _mk_cmd "$PWD/.venv/bin" python "Python 3.12.13"
    PATH="$PWD/.venv/bin:$REAL_PATH" run resolution_analyze python 3.12.13
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == ok\|* ]]
}

@test "analyze: finding survives preceding harness stderr noise (fork-pressure shape)" {
    # Under transient process pressure bash itself prints "fork: retry:
    # Resource temporarily unavailable" to stderr and recovers; `run`
    # merges stderr into $output AHEAD of the (correct) finding line.
    # The result_line contract keeps the assertion about the finding.
    _noisy_analyze() {
        echo "bash: fork: retry: Resource temporarily unavailable" >&2
        resolution_analyze "$@"
    }
    _mk_cmd "$PWD/.venv/bin" python "Python 3.12.13"
    PATH="$PWD/.venv/bin:$REAL_PATH" run _noisy_analyze python 3.12.13
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == ok\|* ]]
}

@test "analyze: wedged winner is killed by the bounded runtime → broken-winner, fast" {
    mkdir -p "$TEST_DIR/sys"
    printf '#!/usr/bin/env bash\nsleep 30\n' > "$TEST_DIR/sys/mycmd"
    chmod +x "$TEST_DIR/sys/mycmd"
    export PYVE_PROBE_TIMEOUT=1
    local start end
    start=$SECONDS
    PATH="$TEST_DIR/sys:$REAL_PATH" run resolution_analyze mycmd
    end=$SECONDS
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == broken-winner\|* ]]
    [ $((end - start)) -lt 10 ]
}

# ============================================================
# pyve_run_bounded (shared bounded exec, lib/utils.sh)
# ============================================================

@test "pyve_run_bounded: passes through output and exit status" {
    _mk_cmd "$TEST_DIR/sys" okcmd "hello"
    run pyve_run_bounded "$TEST_DIR/sys/okcmd"
    [ "$status" -eq 0 ]
    [[ "$(result_line)" == "hello" ]]
    _mk_cmd "$TEST_DIR/sys" badcmd "nope" 3
    run pyve_run_bounded "$TEST_DIR/sys/badcmd"
    [ "$status" -eq 3 ]
}

@test "pyve_run_bounded: kills a wedged command at PYVE_PROBE_TIMEOUT" {
    printf '#!/usr/bin/env bash\nsleep 30\n' > "$TEST_DIR/wedged"
    chmod +x "$TEST_DIR/wedged"
    export PYVE_PROBE_TIMEOUT=1
    local start end
    start=$SECONDS
    run pyve_run_bounded "$TEST_DIR/wedged"
    end=$SECONDS
    [ "$status" -ne 0 ]
    [ $((end - start)) -lt 10 ]
}

@test "pyve_run_bounded: watchdog timer does not outlive the call" {
    # A distinctive limit so pgrep can't match anything else on the box.
    # An orphaned `sleep <limit>` per probe is a real process leak: a
    # multi-env `pyve check` strands a herd of them, and under a parallel
    # test suite they feed the fork pressure that flakes small CI runners.
    export PYVE_PROBE_TIMEOUT=947
    _mk_cmd "$TEST_DIR/sys" okcmd "hello"
    run pyve_run_bounded "$TEST_DIR/sys/okcmd"
    [ "$status" -eq 0 ]
    # SIGTERM delivery to the watchdog is asynchronous — poll briefly.
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "sleep 947" >/dev/null 2>&1 || break
        sleep 0.1
    done
    run pgrep -f "sleep 947"
    [ -z "$output" ]
}

# ============================================================
# [resolution] composer section — the incident, narrated
# ============================================================

# The 2026-06-09 shape: direnv-activated .venv (created on 3.14.4)
# shadows the asdf shims; .tool-versions has moved to 3.12.13;
# project-guide falls through to the shim, which rejects it under the
# pin. check must name the shadow, the drift, and the fall-through.
_fixture_incident() {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n' > pyve.toml
    printf 'python 3.12.13\n' > .tool-versions
    _mk_cmd "$PWD/.venv/bin" python "Python 3.14.4"
    _mk_cmd "$PWD/.venv/bin" pip "pip 25.1 from /x (python 3.14)"
    _mk_cmd "$HOME/.asdf/shims" python "No version is set for command python" 1
    _mk_cmd "$HOME/.asdf/shims" project-guide "No version is set for command project-guide" 1
}

@test "[resolution]: the incident layout → drift + fall-through named, rc 2 (warn)" {
    _fixture_incident
    PATH="$PWD/.venv/bin:$HOME/.asdf/shims:$REAL_PATH" run _compose_check_resolution
    [ "$status" -eq 2 ]
    # python: winner + the venv↔pin drift, naming both versions.
    [[ "$output" == *"python → $PWD/.venv/bin/python"* ]]
    [[ "$output" == *"3.14.4"* ]]
    [[ "$output" == *"3.12.13"* ]]
    [[ "$output" == *"venv-pin-drift"* ]]
    # project-guide: the shim fall-through, named as such.
    [[ "$output" == *"project-guide → $HOME/.asdf/shims/project-guide"* ]]
    [[ "$output" == *"no-version-set"* ]]
    # pip resolves fine from the venv — no finding against it.
    [[ "$output" == *"pip → $PWD/.venv/bin/pip"* ]]
}

@test "[resolution]: findings carry role-correct hints" {
    _fixture_incident
    PATH="$PWD/.venv/bin:$HOME/.asdf/shims:$REAL_PATH" run _compose_check_resolution
    [[ "$output" == *"pyve init --force"* ]]
    [[ "$output" == *"pyve self provision"* ]]
    [[ "$output" != *"pyve env purge root"* ]]
}

@test "[resolution]: healthy layout → winner lines only, no findings, rc 0" {
    printf 'pyve_schema = "3.0"\n\n[project]\nname = "demo"\n' > pyve.toml
    printf 'python 3.12.13\n' > .tool-versions
    _mk_cmd "$PWD/.venv/bin" python "Python 3.12.13"
    _mk_cmd "$PWD/.venv/bin" pip "pip 25.1 from /x (python 3.12)"
    _mk_cmd "$HOME/.local/bin" project-guide "project-guide 2.15.1"
    PATH="$PWD/.venv/bin:$HOME/.local/bin:$REAL_PATH" run _compose_check_resolution
    [ "$status" -eq 0 ]
    [[ "$output" == *"python → "* ]]
    [[ "$output" != *"⚠"* ]]
    [[ "$output" != *"venv-pin-drift"* ]]
}

@test "[resolution]: non-Python project → only project-guide is traced" {
    _mk_cmd "$HOME/.local/bin" project-guide "project-guide 2.15.1"
    PATH="$HOME/.local/bin:$REAL_PATH" run _compose_check_resolution
    [ "$status" -eq 0 ]
    [[ "$output" == *"project-guide → "* ]]
    [[ "$output" != *"python → "* ]]
}

@test "[resolution]: verbose adds the full slot-by-slot PATH trace" {
    _fixture_incident
    export PYVE_VERBOSE=1
    PATH="$PWD/.venv/bin:$HOME/.asdf/shims:$REAL_PATH" run _compose_check_resolution
    [[ "$output" == *"winner"* ]]
    # The shadowed asdf shim slot for python is enumerated in the trace.
    [[ "$output" == *"$HOME/.asdf/shims/python"* ]]
}

@test "[resolution]: concise (non-verbose) omits the slot-by-slot trace" {
    _fixture_incident
    PATH="$PWD/.venv/bin:$HOME/.asdf/shims:$REAL_PATH" run _compose_check_resolution
    [[ "$output" != *"$HOME/.asdf/shims/python"* ]]
}
