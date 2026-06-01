# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve test — run pytest via the dev/test runner environment
#
# Auto-creates the testenv (`.pyve/testenvs/testenv/venv`) if missing, then
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

# Test-private helper: probe whether the ROOT project env (micromamba
# env preferred, then venv) has pytest importable. Used to warn that
# `pyve test` is routing to the (possibly stack-less) testenv when the
# root env already carries pytest — the micromamba-testenv trap.
# Returns 0 (root env has pytest) or 1 (no root env / no pytest).
#
# NOTE: function name retains `main` for M.e v2.7.1. The user-visible
# `--env` value renamed `main → root`; the internal helper generalizes
# (and is renamed) in M.n when the silent-skip advisory expands to all
# named envs.
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
    # Parse the pyve-owned `--env <name>` selector out of the arg list;
    # everything else passes through to pytest verbatim.
    #
    # Story M.m: `<name>` is no longer limited to `root` / `testenv`.
    # Any name declared in `[tool.pyve.testenvs]` is accepted; absent
    # `--env` defaults to `[tool.pyve.testenvs].default` (fallback:
    # `testenv`). Resolver rules below.
    local env_target=""
    local env_target_explicit=0
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                env_target="${2:-}"
                env_target_explicit=1
                shift 2 || { log_error "--env requires a value (a declared env name, or 'root')"; exit 1; }
                ;;
            --env=*)
                env_target="${1#--env=}"
                env_target_explicit=1
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # Category-B hard-error: `--env main` was renamed to `--env root` in
    # v2.7.1 (M.e). Catch the legacy value with a precise migration hint
    # rather than silently delegating (no Category-A).
    if [[ "$env_target" == "main" ]]; then
        log_error "pyve test --env main: renamed to --env root. Run 'pyve test --env root' instead."
        exit 1
    fi

    # `--env root`: route pytest to the ROOT project env. Delegates to
    # run_command, which owns backend detection (venv vs micromamba),
    # the asdf reshim guard, and the exec. This is the first-class form
    # of the `pyve run python -m pytest` workaround for bundled envs
    # that carry both pytest and the stack-under-test in the root env.
    if [[ "$env_target" == "root" ]]; then
        run_command python -m pytest "${args[@]+"${args[@]}"}"
        return  # not reached: run_command execs
    fi

    # Story M.m: load named-env config so we can validate the target
    # name and pick the declared default when `--env` is absent.
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_testenv_config
    fi

    if [[ "$env_target_explicit" == "0" ]]; then
        env_target="${PYVE_TESTENVS_DEFAULT:-testenv}"
    fi

    # Validate the target name. Accept the reserved `testenv` and any
    # declared name; reject everything else with the list of valid
    # choices.
    if [[ "$env_target" != "testenv" ]] && ! is_testenv_declared "$env_target"; then
        log_error "Invalid --env value: '$env_target' is not a declared testenv"
        log_error "Valid choices:"
        local choice
        for choice in root testenv $( { list_testenv_names | grep -vE '^(root|testenv)$'; } 2>/dev/null ); do
            log_error "  $choice"
        done
        exit 1
    fi

    # Conda-backed envs are not yet supported by `pyve test`'s exec
    # path (PATH-only activation doesn't set CONDA_PREFIX/CONDA_PYTHON_EXE).
    # Same M.k gate that `pyve testenv run` uses; use `--env root`
    # against a conda main env, or `micromamba run -p <path> pytest`.
    assert_testenv_venv_backend "$env_target" || exit 1

    local testenv_venv
    testenv_venv="$(resolve_testenv_path "$env_target")"

    # Story M.n: lazy envs that have not been provisioned yet are
    # auto-provisioned on first targeted use — ensure_testenv_exists
    # creates the venv, then `_testenv_install_with_lock` installs
    # per the env's declared sources (M.l). The whole thing is gated
    # by PYVE_NO_AUTO_PROVISION=1 for strict CI that wants the M.m
    # "is this env already built?" semantics.
    local was_lazy_unprovisioned=0
    if is_testenv_lazy "$env_target" && [[ ! -x "$testenv_venv/bin/python" ]]; then
        if [[ "${PYVE_NO_AUTO_PROVISION:-0}" == "1" ]]; then
            log_error "Testenv '$env_target' is declared lazy and has not been provisioned yet."
            log_error "PYVE_NO_AUTO_PROVISION=1 is set — refusing to auto-provision."
            log_error "Run: pyve testenv install $env_target"
            exit 1
        fi
        info "Lazy testenv '$env_target' not yet provisioned — auto-provisioning..."
        was_lazy_unprovisioned=1
    fi

    ensure_testenv_exists "$env_target"

    if [[ "$was_lazy_unprovisioned" == "1" ]]; then
        if ! _testenv_install_with_lock "$env_target" "$testenv_venv" "" "wait"; then
            log_error "Auto-provisioning failed for '$env_target'"
            exit 1
        fi
    fi

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
    # if the ROOT env also carries pytest, the user may be expecting
    # tests to run against the root env's stack. `pyve test` uses the
    # separate testenv, which will not have those deps — tests that
    # importorskip the stack will silently SKIP and look green. Warn,
    # and point at the supported escape hatch. One line, non-fatal.
    # Suppressible via PYVE_NO_TESTENV_ADVISORY=1 for users who keep
    # pytest in the root env deliberately and don't want the nudge.
    if [[ "${PYVE_NO_TESTENV_ADVISORY:-0}" != "1" ]] && _test_main_env_has_pytest; then
        warn "Root env has pytest installed; 'pyve test' is using the separate testenv ($testenv_venv), which won't have your root-env dependencies."
        info "If your tests need the root env's stack, run: pyve test --env root"
    fi

    # Story M.m: touch `.state`'s `last_used_at` before exec so M.p's
    # `pyve testenv list` / `prune` can report which envs are active.
    # Best-effort: silent no-op when `.state` is missing (e.g. an env
    # provisioned before M.m landed `.state` writes in
    # `ensure_testenv_exists`). Suppress stdout/stderr — the touch
    # is bookkeeping, not user-facing.
    state_touch_last_used "$env_target" >/dev/null 2>&1 || true

    exec "$testenv_venv/bin/python" -m pytest "${args[@]+"${args[@]}"}"
}
