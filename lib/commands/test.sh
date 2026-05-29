# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve test — run pytest via the dev/test runner environment
#
# Auto-creates the testenv (`.pyve/testenv/venv`) if missing, then
# auto-installs pytest in CI / under PYVE_TEST_AUTO_INSTALL_PYTEST=1
# (or prompts the user when stdin is a TTY), and finally exec()s
# pytest with the user's args. Pytest's exit code propagates via
# exec.
#
# Function-name note: this function is named `test_tests` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve test [args]` runs the project's tests, whether the
# args explicitly select a subset or are absent (implicitly all).
# This naming also avoids the F-11 `test` shadowing trap (`test`
# is a bash builtin / `/usr/bin/test`).
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Test-private helper: probe whether the testenv has pytest installed.
# Returns 0 (yes) or 1 (no/missing-python).
_test_has_pytest() {
    local testenv_venv="$1"
    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        return 1
    fi
    "$testenv_venv/bin/python" -c "import pytest" >/dev/null 2>&1
}

# Test-private helper: probe whether the MAIN project env (micromamba
# env preferred, then venv) has pytest importable. Used to warn that
# `pyve test` is routing to the (possibly stack-less) testenv when the
# main env already carries pytest — the micromamba-testenv trap.
# Returns 0 (main env has pytest) or 1 (no main env / no pytest).
_test_main_env_has_pytest() {
    local main_py=""

    if [[ -d ".pyve/envs" ]]; then
        local env_dirs=(.pyve/envs/*)
        if [[ -d "${env_dirs[0]:-}" ]] && [[ "${env_dirs[0]:-}" != ".pyve/envs/*" ]]; then
            main_py="${env_dirs[0]}/bin/python"
        fi
    fi

    if [[ -z "$main_py" ]] && [[ -x "$DEFAULT_VENV_DIR/bin/python" ]]; then
        main_py="$DEFAULT_VENV_DIR/bin/python"
    fi

    [[ -x "$main_py" ]] || return 1
    "$main_py" -c "import pytest" >/dev/null 2>&1
}

# Test-private helper: install pytest into the testenv. If
# `requirements-dev.txt` is present, prefer installing from it.
_test_install_pytest_into_testenv() {
    local testenv_venv="$1"
    local requirements_file=""

    if [[ -f "requirements-dev.txt" ]]; then
        requirements_file="requirements-dev.txt"
    fi

    info "Installing pytest into dev/test runner environment..."
    if [[ -n "$requirements_file" ]]; then
        run_cmd "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
    else
        run_cmd "$testenv_venv/bin/python" -m pip install pytest
    fi
    success "pytest installed"
}

# Public: pyve test [pytest args...]
#
# Cross-file call: `ensure_testenv_exists` lives in `pyve.sh` until
# K.g moves it to `lib/utils.sh`. Bash resolves the call at runtime
# from the global function table — no special handling needed.
test_tests() {
    # Parse the pyve-owned `--env main|testenv` selector out of the
    # arg list; everything else passes through to pytest verbatim.
    local env_target="testenv"
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                env_target="${2:-}"
                shift 2 || { log_error "--env requires a value (main|testenv)"; exit 1; }
                ;;
            --env=*)
                env_target="${1#--env=}"
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$env_target" != "main" && "$env_target" != "testenv" ]]; then
        log_error "Invalid --env value: '$env_target' (expected 'main' or 'testenv')"
        exit 1
    fi

    # `--env main`: route pytest to the MAIN project env. Delegates to
    # run_command, which owns backend detection (venv vs micromamba),
    # the asdf reshim guard, and the exec. This is the first-class form
    # of the `pyve run python -m pytest` workaround for bundled envs
    # that carry both pytest and the stack-under-test in the main env.
    if [[ "$env_target" == "main" ]]; then
        run_command python -m pytest "${args[@]+"${args[@]}"}"
        return  # not reached: run_command execs
    fi

    local testenv_venv=".pyve/$TESTENV_DIR_NAME/venv"
    ensure_testenv_exists

    if ! _test_has_pytest "$testenv_venv"; then
        local auto_install=false
        if [[ -n "${CI:-}" ]] || [[ "$PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT" == "1" ]]; then
            auto_install=true
        fi

        if [[ "$auto_install" == true ]]; then
            _test_install_pytest_into_testenv "$testenv_venv"
        else
            if [[ -t 0 ]]; then
                printf "pytest is not installed in the dev/test runner environment. Install now? [y/N]: "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    _test_install_pytest_into_testenv "$testenv_venv"
                else
                    log_info "Install skipped. You can install with: pyve testenv install -r requirements-dev.txt"
                    exit 1
                fi
            else
                log_error "pytest is not installed in the dev/test runner environment."
                log_error "Run: pyve testenv install -r requirements-dev.txt"
                exit 1
            fi
        fi
    fi

    # Silent-skip trap guard (proxy for the micromamba-testenv trap):
    # if the MAIN env also carries pytest, the user may be expecting
    # tests to run against the main env's stack. `pyve test` uses the
    # separate testenv, which will not have those deps — tests that
    # importorskip the stack will silently SKIP and look green. Warn,
    # and point at the supported escape hatch. One line, non-fatal.
    # Suppressible via PYVE_NO_TESTENV_ADVISORY=1 for users who keep
    # pytest in the main env deliberately and don't want the nudge.
    if [[ "${PYVE_NO_TESTENV_ADVISORY:-0}" != "1" ]] && _test_main_env_has_pytest; then
        warn "Main env has pytest installed; 'pyve test' is using the separate testenv ($testenv_venv), which won't have your main-env dependencies."
        info "If your tests need the main env's stack, run: pyve test --env main"
    fi

    exec "$testenv_venv/bin/python" -m pytest "${args[@]+"${args[@]}"}"
}
