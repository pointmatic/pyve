#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the interactive `pyve init` wizard skeleton (Story L.k.2).
#
# Scope: the `_init_wizard` skeleton — banner printing, TTY guard, and the
# PYVE_INIT_NONINTERACTIVE=1 bypass. Per-prompt logic (backend / python
# version / project-guide) lands in L.k.3 / L.k.4 / L.k.5; those stories
# extend this test file.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    # ui/select.sh is consumed by the L.k.3 backend prompt; source it
    # alongside init.sh so _init_wizard's prompt path can resolve.
    source "$PYVE_ROOT/lib/ui/select.sh"
    # Source init.sh so _init_wizard / _init_detect_backend_default
    # are available for direct invocation. init.sh's external deps
    # (log_error, header_box, etc.) come from ui/core.sh and utils.sh,
    # both sourced by setup_pyve_env.
    source "$PYVE_ROOT/lib/commands/init.sh"
    create_test_dir
    # Tests in this file exercise the TTY guard explicitly. Unset the
    # bypass env var so the guard's natural behavior surfaces; individual
    # tests that need the bypass set it locally.
    unset PYVE_INIT_NONINTERACTIVE
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Happy path: banner prints when all three flags are supplied
#============================================================

@test "_init_wizard: prints header_box when all three flags supplied" {
    run _init_wizard "venv" "3.13.7" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init"* ]]
    [[ "$output" == *"╭"* ]]
    [[ "$output" == *"╰"* ]]
}

#============================================================
# TTY guard fires when at least one prompt-bearing flag is missing
#============================================================

@test "_init_wizard: TTY guard fires when stdin not TTY and all three flags missing" {
    run _init_wizard "" "" "false" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"--backend"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" == *"--project-guide"* ]]
}

@test "_init_wizard: TTY guard error names only missing flags, not supplied ones" {
    # backend supplied; python and project-guide missing.
    run _init_wizard "venv" "" "false" ""
    [ "$status" -ne 0 ]
    # Supplied flag must NOT appear in the missing-flag list.
    [[ "$output" != *"--backend"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" == *"--project-guide"* ]]
}

@test "_init_wizard: TTY guard fires with only one missing flag" {
    # backend and project-guide supplied; only python missing.
    run _init_wizard "venv" "" "false" "yes"
    [ "$status" -ne 0 ]
    [[ "$output" != *"--backend"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" != *"--project-guide"* ]]
}

@test "_init_wizard: TTY guard error mentions PYVE_INIT_NONINTERACTIVE bypass" {
    run _init_wizard "" "" "false" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"PYVE_INIT_NONINTERACTIVE"* ]]
}

#============================================================
# TTY guard does NOT fire when all three flags are supplied
#============================================================

@test "_init_wizard: TTY guard does not fire when all three supplied (any backend)" {
    run _init_wizard "micromamba" "3.13.7" "true" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init"* ]]
}

#============================================================
# PYVE_INIT_NONINTERACTIVE=1 bypasses the TTY guard
#============================================================

@test "_init_wizard: PYVE_INIT_NONINTERACTIVE=1 bypasses TTY guard with all flags missing" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "" "" "false" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve init"* ]]
}

@test "_init_wizard: PYVE_INIT_NONINTERACTIVE=0 does NOT bypass" {
    PYVE_INIT_NONINTERACTIVE=0 run _init_wizard "" "" "false" ""
    [ "$status" -ne 0 ]
}

#============================================================
# Integration: pyve init dispatches through _init_wizard
#============================================================

@test "pyve init: hard-fails when stdin not TTY, no flags, no bypass" {
    unset PYVE_INIT_NONINTERACTIVE
    run "$PYVE_ROOT/pyve.sh" init
    [ "$status" -ne 0 ]
    [[ "$output" == *"--backend"* ]]
}

@test "pyve init: PYVE_INIT_NONINTERACTIVE=1 lets non-TTY init proceed past wizard" {
    # With the bypass, the wizard returns success and init proceeds. We
    # don't care if init *as a whole* succeeds — only that the wizard
    # didn't hard-fail with the TTY guard error message.
    PYVE_INIT_NONINTERACTIVE=1 run "$PYVE_ROOT/pyve.sh" init --backend foo
    [[ "$output" != *"--python-version"* ]] || [[ "$output" != *"PYVE_INIT_NONINTERACTIVE"* ]]
    # The banner should print (proves wizard ran, did not short-circuit).
    [[ "$output" == *"pyve init"* ]]
}

#============================================================
# L.k.3: _init_detect_backend_default (repo-signal helper)
#============================================================

@test "_init_detect_backend_default: returns micromamba when environment.yml exists" {
    touch environment.yml
    run _init_detect_backend_default
    [ "$status" -eq 0 ]
    [[ "$output" == "micromamba" ]]
}

@test "_init_detect_backend_default: returns venv when .python-version exists" {
    touch .python-version
    run _init_detect_backend_default
    [ "$status" -eq 0 ]
    [[ "$output" == "venv" ]]
}

@test "_init_detect_backend_default: returns venv when .tool-versions exists" {
    touch .tool-versions
    run _init_detect_backend_default
    [ "$status" -eq 0 ]
    [[ "$output" == "venv" ]]
}

@test "_init_detect_backend_default: returns venv when no signal files exist" {
    run _init_detect_backend_default
    [ "$status" -eq 0 ]
    [[ "$output" == "venv" ]]
}

@test "_init_detect_backend_default: environment.yml wins over .python-version" {
    touch environment.yml .python-version
    run _init_detect_backend_default
    [ "$status" -eq 0 ]
    [[ "$output" == "micromamba" ]]
}

#============================================================
# L.k.3: _init_wizard backend resolution — flag-render path
#============================================================

@test "_init_wizard: --backend venv renders 'Backend: venv (--backend)'" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend: venv (--backend)"* ]]
}

@test "_init_wizard: --backend micromamba renders 'Backend: micromamba (--backend)'" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "micromamba" "3.13.7" "true" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend: micromamba (--backend)"* ]]
}

#============================================================
# L.k.3: _init_wizard backend resolution — auto-default path (bypass on)
#============================================================

@test "_init_wizard: bypass + no flag + no signals → auto-detected venv" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend: venv (auto-detected)"* ]]
}

@test "_init_wizard: bypass + no flag + environment.yml → auto-detected micromamba" {
    touch environment.yml
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend: micromamba (auto-detected)"* ]]
}

@test "_init_wizard: bypass + no flag + .tool-versions → auto-detected venv" {
    touch .tool-versions
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend: venv (auto-detected)"* ]]
}

#============================================================
# L.k.3: side-effect — caller's backend_flag set to resolved value
#============================================================

@test "_init_wizard: side-effect sets caller's backend_flag from auto-detection" {
    touch environment.yml
    local backend_flag=""
    PYVE_INIT_NONINTERACTIVE=1 _init_wizard "$backend_flag" "" "false" "yes" >/dev/null 2>&1
    [[ "$backend_flag" == "micromamba" ]]
}

@test "_init_wizard: --backend leaves caller's backend_flag untouched (already set)" {
    local backend_flag="venv"
    PYVE_INIT_NONINTERACTIVE=1 _init_wizard "$backend_flag" "" "false" "yes" >/dev/null 2>&1
    [[ "$backend_flag" == "venv" ]]
}

#============================================================
# L.k.4: version-manager detection helper
#============================================================

# Helper for L.k.4 tests: drop fake `asdf` and/or `pyenv` shims into a
# test-local bin dir and prepend to PATH. The shims are minimal — just
# enough for the wizard's parsers and the pin-write paths in
# set_local_python_version. Tests opt into a particular combination
# (asdf, pyenv, or both) by listing them as args.
_stub_managers() {
    mkdir -p "$TEST_DIR/.fakebin"
    local m
    for m in "$@"; do
        case "$m" in
            asdf)
                cat > "$TEST_DIR/.fakebin/asdf" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    list)
        if [[ "$2" == "all" && "$3" == "python" ]]; then
            printf '2.7.18\n3.10.0\n3.13.7\nstackless-3.7.5\n'
        elif [[ "$2" == "python" ]]; then
            printf '  3.12.0\n  *3.13.7\n  3.14.0\n'
        fi
        ;;
    plugin)
        if [[ "$2" == "list" ]]; then
            printf 'python\n'
        fi
        ;;
    set|local|reshim)
        :
        ;;
esac
EOF
                chmod +x "$TEST_DIR/.fakebin/asdf"
                ;;
            pyenv)
                cat > "$TEST_DIR/.fakebin/pyenv" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    versions)
        printf '3.12.0\n3.13.7\n'
        ;;
    install)
        if [[ "$2" == "--list" ]]; then
            printf '  2.7.18\n  3.10.0\n  3.13.7\n  pypy3.10-7.3.12\n'
        fi
        ;;
    local|rehash|init)
        :
        ;;
esac
EOF
                chmod +x "$TEST_DIR/.fakebin/pyenv"
                ;;
        esac
    done
    # Clean PATH: only the stub bin dir + the minimum needed for shell
    # builtins (`tput`, `sed`, `grep`, etc.). Otherwise the dev's real
    # asdf/pyenv on the inherited PATH leaks into "only X" tests.
    export PATH="$TEST_DIR/.fakebin:/usr/bin:/bin"
}

@test "_init_detect_version_managers_available: empty when neither asdf nor pyenv on PATH" {
    mkdir -p "$TEST_DIR/.emptybin"
    PATH="$TEST_DIR/.emptybin" run _init_detect_version_managers_available
    [ "$status" -eq 0 ]
    [[ "$output" == "" ]]
}

@test "_init_detect_version_managers_available: 'asdf' when only asdf on PATH" {
    _stub_managers asdf
    run _init_detect_version_managers_available
    [ "$status" -eq 0 ]
    [[ "$output" == "asdf" ]]
}

@test "_init_detect_version_managers_available: 'pyenv' when only pyenv on PATH" {
    _stub_managers pyenv
    run _init_detect_version_managers_available
    [ "$status" -eq 0 ]
    [[ "$output" == "pyenv" ]]
}

@test "_init_detect_version_managers_available: 'asdf,pyenv' when both on PATH" {
    _stub_managers asdf pyenv
    run _init_detect_version_managers_available
    [ "$status" -eq 0 ]
    [[ "$output" == "asdf,pyenv" ]]
}

#============================================================
# L.k.4: installed-version listing helpers
#============================================================

@test "_init_list_installed_python_versions asdf: strips '*' and whitespace, filters ^3\\." {
    _stub_managers asdf
    run _init_list_installed_python_versions asdf
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.12.0"* ]]
    [[ "$output" == *"3.13.7"* ]]
    [[ "$output" == *"3.14.0"* ]]
    [[ "$output" != *"*3.13.7"* ]]
}

@test "_init_list_installed_python_versions pyenv: bare format, filters ^3\\." {
    _stub_managers pyenv
    run _init_list_installed_python_versions pyenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.12.0"* ]]
    [[ "$output" == *"3.13.7"* ]]
}

#============================================================
# L.k.4: available-version listing helpers (full list, ^3\. filter)
#============================================================

@test "_init_list_available_python_versions asdf: filters non-3.x oddities" {
    _stub_managers asdf
    run _init_list_available_python_versions asdf
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.10.0"* ]]
    [[ "$output" == *"3.13.7"* ]]
    [[ "$output" != *"2.7.18"* ]]
    [[ "$output" != *"stackless"* ]]
}

@test "_init_list_available_python_versions pyenv: filters non-3.x oddities" {
    _stub_managers pyenv
    run _init_list_available_python_versions pyenv
    [ "$status" -eq 0 ]
    [[ "$output" == *"3.10.0"* ]]
    [[ "$output" == *"3.13.7"* ]]
    [[ "$output" != *"2.7.18"* ]]
    [[ "$output" != *"pypy"* ]]
}

#============================================================
# L.k.4: wizard Python-prompt — micromamba branch
#============================================================

@test "_init_wizard: micromamba + environment.yml present → 'managed via environment.yml'" {
    touch environment.yml
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "micromamba" "3.13.7" "true" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: managed via environment.yml"* ]]
}

@test "_init_wizard: micromamba + no env.yml + --python-version → 'will be written to environment.yml'" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "micromamba" "3.12.13" "true" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: 3.12.13 (--python-version, will be written to environment.yml)"* ]]
}

@test "_init_wizard: micromamba + no env.yml + no flag → 'default, will be written to environment.yml'" {
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "micromamba" "3.13.7" "false" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: 3.13.7 (default, will be written to environment.yml)"* ]]
}

@test "_init_wizard: micromamba + no managers on PATH still succeeds (no manager detection on micromamba branch)" {
    mkdir -p "$TEST_DIR/.emptybin"
    PATH="$TEST_DIR/.emptybin" PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "micromamba" "3.12.13" "true" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: 3.12.13"* ]]
}

#============================================================
# L.k.4: wizard Python-prompt — venv branch, flag-driven
#============================================================

@test "_init_wizard: venv + --python-version + asdf on PATH → 'pinned via asdf'" {
    _stub_managers asdf
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: 3.13.7 (--python-version, pinned via asdf)"* ]]
}

@test "_init_wizard: venv + --python-version + pyenv only → 'pinned via pyenv'" {
    _stub_managers pyenv
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: 3.13.7 (--python-version, pinned via pyenv)"* ]]
}

@test "_init_wizard: venv + --python-version + both managers → asdf preferred" {
    _stub_managers asdf pyenv
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "true" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pinned via asdf"* ]]
    [[ "$output" != *"pinned via pyenv"* ]]
}

@test "_init_wizard: venv + --python-version + no managers → hard-fail naming both" {
    mkdir -p "$TEST_DIR/.emptybin"
    PATH="$TEST_DIR/.emptybin" PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "true" "yes"
    [ "$status" -ne 0 ]
    [[ "$output" == *"asdf"* ]]
    [[ "$output" == *"pyenv"* ]]
}

#============================================================
# L.k.4: wizard Python-prompt — venv branch, bypass + no flag (silent skip)
#============================================================

@test "_init_wizard: venv + bypass + no --python-version → 'Python: skipped (no pin)'" {
    _stub_managers asdf
    PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "false" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: skipped (no pin)"* ]]
}

@test "_init_wizard: venv + bypass + no flag + no managers → silent skip (no hard-fail)" {
    mkdir -p "$TEST_DIR/.emptybin"
    PATH="$TEST_DIR/.emptybin" PYVE_INIT_NONINTERACTIVE=1 run _init_wizard "venv" "3.13.7" "false" "yes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python: skipped (no pin)"* ]]
}
