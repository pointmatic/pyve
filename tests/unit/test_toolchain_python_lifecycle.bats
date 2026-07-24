#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Unit tests for the toolchain-Python lifecycle:
#   - `self install` provisions the hidden venv (best-effort, non-fatal)
#   - a DEFAULT_PYTHON_VERSION bump provisions a new version-keyed dir
#     and prunes the stale one
#   - `self uninstall` removes the whole toolchain tree
#   - the build bootstrap prefers the version-manager's EXACT-version
#     interpreter (version-tracking fidelity), falling back to PATH
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/ui/run.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"

    TEST_DIR="$(mktemp -d)"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

_fake_build_succeeds() {
    _pyve_toolchain_build() {
        local dir="$1"
        mkdir -p "$dir/bin"
        printf '#!/bin/sh\necho built\n' > "$dir/bin/python"
        chmod +x "$dir/bin/python"
        return 0
    }
}

#------------------------------------------------------------
# Install
#------------------------------------------------------------

@test "_self_install_toolchain_python: provisions the venv when build succeeds" {
    _fake_build_succeeds
    run _self_install_toolchain_python
    assert_status_equals 0
    [[ -x "$(pyve_toolchain_venv_dir)/bin/python" ]]
}

@test "_self_install_toolchain_python: non-fatal when the build fails (install must not abort)" {
    _pyve_toolchain_build() { return 1; }
    run _self_install_toolchain_python
    assert_status_equals 0
    assert_output_contains "fall back"
}

@test "_self_install_toolchain_python: a DEFAULT_PYTHON_VERSION bump provisions a new keyed dir" {
    _fake_build_succeeds
    _self_install_toolchain_python                       # builds 3.14.4
    [[ -x "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin/python" ]]

    DEFAULT_PYTHON_VERSION="3.15.0"
    _fake_build_succeeds
    run _self_install_toolchain_python                   # builds 3.15.0
    assert_status_equals 0
    [[ -x "$XDG_DATA_HOME/pyve/toolchain/3.15.0/venv/bin/python" ]]
}

@test "_self_install_toolchain_python: prunes stale version dirs (old GC-able)" {
    # A leftover venv from a previous DEFAULT_PYTHON_VERSION.
    mkdir -p "$XDG_DATA_HOME/pyve/toolchain/3.10.0/venv/bin"
    : > "$XDG_DATA_HOME/pyve/toolchain/3.10.0/venv/bin/python"
    _fake_build_succeeds
    run _self_install_toolchain_python                   # current = 3.14.4
    assert_status_equals 0
    [[ -d "$XDG_DATA_HOME/pyve/toolchain/3.14.4" ]]
    [[ ! -d "$XDG_DATA_HOME/pyve/toolchain/3.10.0" ]]
}

#------------------------------------------------------------
# Uninstall
#------------------------------------------------------------

@test "_self_uninstall_toolchain_python: removes the entire toolchain tree" {
    mkdir -p "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin"
    : > "$XDG_DATA_HOME/pyve/toolchain/3.14.4/venv/bin/python"
    [[ -d "$(pyve_toolchain_root)" ]]
    run _self_uninstall_toolchain_python
    assert_status_equals 0
    [[ ! -d "$(pyve_toolchain_root)" ]]
}

@test "_self_uninstall_toolchain_python: no-op when the tree is absent" {
    [[ ! -d "$(pyve_toolchain_root)" ]]
    run _self_uninstall_toolchain_python
    assert_status_equals 0
}

#------------------------------------------------------------
# Build bootstrap — exact-version fidelity (version tracking)
#------------------------------------------------------------

@test "_pyve_toolchain_bootstrap_python: prefers the version manager's exact-version interpreter" {
    # Fake an asdf install for the pinned version.
    local install="$TEST_DIR/asdf-python-3.14.4"
    mkdir -p "$install/bin"
    printf '#!/bin/sh\necho 3.14.4\n' > "$install/bin/python"
    chmod +x "$install/bin/python"

    detect_version_manager() { VERSION_MANAGER="asdf"; }
    ensure_python_version_installed() { return 0; }
    asdf() { [[ "$1" == "where" && "$2" == "python" ]] && printf '%s' "$install"; }

    run _pyve_toolchain_bootstrap_python "3.14.4"
    assert_status_equals 0
    assert_output_equals "$install/bin/python"
}

@test "_pyve_toolchain_bootstrap_python: STRICT — will NOT fall back to a PATH python" {
    # Was: "falls back to a PATH python when no version-manager match". That
    # fallback was the defect, not a feature — it built `toolchain/<V>/venv` out
    # of whatever interpreter the shell exposed (normally the *project's* python
    # via a version-manager shim), so the slot's name lied about its contents and
    # the toolchain was re-coupled to the version manager it exists to be free of.
    # Absent the exact version, resolution must FAIL and say so; the caller then
    # degrades to bare `python` at use time rather than materializing a
    # mislabeled toolchain.
    local fakebin="$TEST_DIR/fakebin"
    mkdir -p "$fakebin"
    printf '#!/bin/sh\necho 3.12.0\n' > "$fakebin/python3"
    chmod +x "$fakebin/python3"

    detect_version_manager() { VERSION_MANAGER=""; }
    ensure_python_version_installed() { return 1; }

    PATH="$fakebin:$PATH" run _pyve_toolchain_bootstrap_python "3.14.4"
    [ "$status" -ne 0 ]
    [[ "$output" != *"fakebin"* ]]
}

#------------------------------------------------------------
# Non-interactive safety — the brew `self provision` hang
#
# Regression guard: `self provision` runs as a Homebrew post-install hook
# (non-interactive, output-suppressed). When the pinned DEFAULT_PYTHON_VERSION
# is absent from the active version manager, the toolchain build must NOT
# reach an interactive prompt — a swallowed `prompt_yes_no` whose `read`
# blocks on the terminal is the silent, infinite hang we are fixing.
#------------------------------------------------------------

@test "_pyve_toolchain_bootstrap_python: pure resolver — never reaches the interactive installer" {
    # The captured-stdout resolver must not call ensure_python_version_installed
    # (which can block on prompt_yes_no) nor prompt directly. The install
    # decision belongs in _pyve_toolchain_ensure_interpreter, outside capture.
    local body
    body="$(declare -f _pyve_toolchain_bootstrap_python)"
    [[ "$body" != *"ensure_python_version_installed"* ]]
    [[ "$body" != *"prompt_yes_no"* ]]
}

@test "_pyve_toolchain_confirm_install: declines in a non-interactive context (no TTY) — never blocks" {
    unset CI PYVE_FORCE_YES
    run _pyve_toolchain_confirm_install "3.14.5"
    assert_status_equals 1
}

@test "_pyve_toolchain_confirm_install: PYVE_FORCE_YES=1 forces yes without a TTY" {
    PYVE_FORCE_YES=1 run _pyve_toolchain_confirm_install "3.14.5"
    assert_status_equals 0
}

@test "_pyve_toolchain_confirm_install: CI declines (no unattended source build)" {
    CI=1 run _pyve_toolchain_confirm_install "3.14.5"
    assert_status_equals 1
}

@test "_pyve_toolchain_ensure_interpreter: no-op when the exact version is already installed" {
    detect_version_manager() { VERSION_MANAGER="asdf"; }
    local install="$TEST_DIR/py"
    mkdir -p "$install/bin"
    printf '#!/bin/sh\necho 3.14.5\n' > "$install/bin/python"
    chmod +x "$install/bin/python"
    export FAKE_EXACT="$install/bin/python"
    _pyve_toolchain_versioned_python() { printf '%s' "$FAKE_EXACT"; }
    ensure_python_version_installed() { printf 'INSTALLER-RAN\n'; return 0; }

    run _pyve_toolchain_ensure_interpreter "3.14.5"
    assert_status_equals 0
    [[ "$output" != *"INSTALLER-RAN"* ]]
}

@test "_pyve_toolchain_ensure_interpreter: absent exact + non-interactive → does not invoke the installer (no hang)" {
    detect_version_manager() { VERSION_MANAGER="asdf"; }
    _pyve_toolchain_versioned_python() { :; }              # exact version absent
    ensure_python_version_installed() { printf 'INSTALLER-RAN\n'; return 0; }
    unset CI PYVE_FORCE_YES

    run _pyve_toolchain_ensure_interpreter "3.14.5"
    assert_status_equals 0
    [[ "$output" != *"INSTALLER-RAN"* ]]
}

@test "_pyve_toolchain_ensure_interpreter: absent exact + PYVE_FORCE_YES → invokes the installer" {
    detect_version_manager() { VERSION_MANAGER="asdf"; }
    _pyve_toolchain_versioned_python() { :; }              # exact version absent
    ensure_python_version_installed() { printf 'INSTALLER-RAN\n'; return 0; }

    PYVE_FORCE_YES=1 run _pyve_toolchain_ensure_interpreter "3.14.5"
    assert_status_equals 0
    assert_output_contains "INSTALLER-RAN"
}

@test "_pyve_toolchain_confirm_install: interactive branch with no PATH python — no 'unbound variable' under set -u (brew 3.0.1 regression)" {
    # The brew post-install shape: an interactive TTY (so the prompt path
    # runs) but NO python3/python on PATH (so the fallback-version block is
    # skipped). A bare `local fallback_ver` leaves it unset → `set -u` aborts
    # on the `[[ -n "$fallback_ver" ]]` read. bats doesn't re-enable `set -u`,
    # so the regression only surfaces in an explicit `set -euo pipefail` shell.
    run bash -c '
        set -euo pipefail
        source "'"$PYVE_ROOT"'/lib/toolchain_python.sh"
        _pyve_is_interactive() { return 0; }          # force the interactive branch
        _pyve_toolchain_path_python() { return 1; }   # no python3/python on PATH
        unset CI PYVE_FORCE_YES || true
        printf "n\n" | _pyve_toolchain_confirm_install "3.14.5"
    '
    [[ "$output" != *"unbound variable"* ]]
    assert_output_contains "Pyve prefers Python 3.14.5"
}

@test "_pyve_is_interactive: gates on output visibility, not just stdin (brew 3.0.2 hang)" {
    # Homebrew `post_install` keeps stdin attached to the tty but redirects
    # stdout/stderr to a logfile. A stdin-only gate (`[[ -t 0 ]]`) therefore
    # prompts to the invisible log and blocks on `read`. The gate must also
    # require an OUTPUT stream to be a terminal so the prompt is answerable.
    local body
    body="$(declare -f _pyve_is_interactive)"
    [[ "$body" == *"-t 1"* || "$body" == *"-t 2"* ]]
}

@test "_pyve_is_interactive: false when an output stream is redirected (no prompt → no hang)" {
    # stderr (the prompt's destination) redirected to a file → not interactive,
    # so _pyve_toolchain_confirm_install must decline rather than prompt+block.
    run bash -c '
        set -euo pipefail
        source "'"$PYVE_ROOT"'/lib/toolchain_python.sh"
        _pyve_is_interactive 2>/dev/null && echo INTERACTIVE || echo NONINTERACTIVE
    '
    assert_output_contains "NONINTERACTIVE"
}
