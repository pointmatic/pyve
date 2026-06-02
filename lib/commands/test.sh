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

# Story M.o: probe whether `<name>` has pytest importable. Drives the
# generalized silent-skip advisory — if any env *other* than the one
# the user targeted has pytest, that env is a candidate for `--env <X>`
# (its dependency stack may be what the tests actually need). M.c's
# trap is the canonical instance: target = `testenv`, `root` has pytest
# → warn. M.o expands to root + every declared name.
#
# `<name> == "root"` resolves the main project env (micromamba env
# preferred at `.pyve/envs/<first>`, else `$DEFAULT_VENV_DIR/bin/python`).
# Other names resolve via `resolve_env_path <name>` and probe its
# `bin/python`. Returns 0 (env has pytest importable) / 1 (no env /
# no pytest / probe failure).
#
# Renamed from `_test_main_env_has_pytest` in M.o.
_test_env_has_pytest() {
    local env_name="$1"
    local py=""

    if [[ "$env_name" == "root" ]]; then
        if [[ -d ".pyve/envs" ]]; then
            local env_dirs=(.pyve/envs/*)
            if [[ -d "${env_dirs[0]:-}" ]] && [[ "${env_dirs[0]:-}" != ".pyve/envs/*" ]]; then
                py="${env_dirs[0]}/bin/python"
            fi
        fi
        if [[ -z "$py" ]] && [[ -x "$DEFAULT_VENV_DIR/bin/python" ]]; then
            py="$DEFAULT_VENV_DIR/bin/python"
        fi
    else
        local env_path
        env_path="$(resolve_env_path "$env_name" 2>/dev/null)" || return 1
        py="$env_path/bin/python"
    fi

    [[ -x "$py" ]] || return 1
    "$py" -c "import pytest" >/dev/null 2>&1
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
# Cross-file call: `ensure_env_exists` lives in `pyve.sh` until
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
    #
    # Story M.r: `<name>` may also be a comma-separated list of names
    # (`--env a,b,c`). With a single name (no comma), the M.m exec path
    # is preserved verbatim. With multiple names, each is run in a
    # subshell sequentially; exit code is the worst-case aggregate;
    # each env's output is preceded by `=== Env: <name> ===`.
    local env_csv=""
    local env_target_explicit=0
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                env_csv="${2:-}"
                env_target_explicit=1
                shift 2 || { log_error "--env requires a value (a declared env name, or 'root')"; exit 1; }
                ;;
            --env=*)
                env_csv="${1#--env=}"
                env_target_explicit=1
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # Story M.r: split CSV into a list. A single name (no comma)
    # produces a 1-element list; downstream single-vs-matrix dispatch
    # branches on `${#env_targets[@]}`.
    local -a env_targets=()
    if [[ -n "$env_csv" ]]; then
        IFS=',' read -r -a env_targets <<< "$env_csv"
    fi

    # Matrix path: ≥2 declared envs. Each runs in a subshell so an
    # `exit` (or `exec`) inside a per-env run terminates only that
    # subshell; iteration continues. Exit code aggregates worst-case
    # (highest failing rc).
    if [[ "${#env_targets[@]}" -ge 2 ]]; then
        local rc=0
        local one
        for one in "${env_targets[@]}"; do
            printf '\n=== Env: %s ===\n' "$one"
            # Suppress the M.o silent-skip advisory in matrix mode:
            # the user is explicitly running multiple envs, so the
            # cross-env "you might have meant X" hint is noise. The
            # subshell scoping is intentional (the export does NOT
            # leak to test_tests' caller).
            # shellcheck disable=SC2030
            (
                export PYVE_NO_TESTENV_ADVISORY=1
                _test_run_one_env "$one" 1 "${args[@]+"${args[@]}"}"
            )
            local sub_rc=$?
            [[ $sub_rc -gt $rc ]] && rc=$sub_rc
        done
        exit $rc
    fi

    # Single-env path (no comma): preserve the M.m exec contract.
    local env_target="${env_targets[0]:-}"
    _test_run_one_env "$env_target" "$env_target_explicit" "${args[@]+"${args[@]}"}"
}

# Story M.r: extracted from `test_tests` so the matrix loop can call
# the per-env logic inside a subshell without losing the M.m exec
# behavior on the single-env path. Signature:
#
#   _test_run_one_env <name> <explicit> [pytest args...]
#
# `<name>` may be empty (use the declared default); `<explicit>` is
# "1" when the caller passed `--env` (single-env or matrix; matrix
# always passes 1) and "0" only when single-env had no `--env` at all.
#
# Behavior is identical to pre-M.r `test_tests`: legacy-value catch,
# `root` short-circuit to `run_command`, name validation, conda gate,
# lazy auto-provision (M.n), pytest install prompt, silent-skip
# advisory (M.o), `last_used_at` touch (M.m), then `exec pytest`.
# Returns only on error paths (the success tail execs).
_test_run_one_env() {
    local env_target="$1"
    local env_target_explicit="$2"
    shift 2 || true
    local -a args=("$@")

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
        read_env_config
    fi

    if [[ "$env_target_explicit" == "0" ]]; then
        env_target="${PYVE_TESTENVS_DEFAULT:-testenv}"
    fi

    # Validate the target name. Accept the reserved `testenv` and any
    # declared name; reject everything else with the list of valid
    # choices.
    if [[ "$env_target" != "testenv" ]] && ! is_env_declared "$env_target"; then
        log_error "Invalid --env value: '$env_target' is not a declared testenv"
        log_error "Valid choices:"
        local choice
        for choice in root testenv $( { list_env_names | grep -vE '^(root|testenv)$'; } 2>/dev/null ); do
            log_error "  $choice"
        done
        exit 1
    fi

    # Conda-backed envs are not yet supported by `pyve test`'s exec
    # path (PATH-only activation doesn't set CONDA_PREFIX/CONDA_PYTHON_EXE).
    # Same M.k gate that `pyve testenv run` uses; use `--env root`
    # against a conda main env, or `micromamba run -p <path> pytest`.
    assert_env_venv_backend "$env_target" || exit 1

    local testenv_venv
    testenv_venv="$(resolve_env_path "$env_target")"

    # Story M.n: lazy envs that have not been provisioned yet are
    # auto-provisioned on first targeted use — ensure_env_exists
    # creates the venv, then `_env_install_with_lock` installs
    # per the env's declared sources (M.l). The whole thing is gated
    # by PYVE_NO_AUTO_PROVISION=1 for strict CI that wants the M.m
    # "is this env already built?" semantics.
    local was_lazy_unprovisioned=0
    if is_env_lazy "$env_target" && [[ ! -x "$testenv_venv/bin/python" ]]; then
        if [[ "${PYVE_NO_AUTO_PROVISION:-0}" == "1" ]]; then
            log_error "Testenv '$env_target' is declared lazy and has not been provisioned yet."
            log_error "PYVE_NO_AUTO_PROVISION=1 is set — refusing to auto-provision."
            log_error "Run: pyve testenv install $env_target"
            exit 1
        fi
        info "Lazy testenv '$env_target' not yet provisioned — auto-provisioning..."
        was_lazy_unprovisioned=1
    fi

    ensure_env_exists "$env_target"

    if [[ "$was_lazy_unprovisioned" == "1" ]]; then
        if ! _env_install_with_lock "$env_target" "$testenv_venv" "" "wait"; then
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

    # Silent-skip trap guard (Story M.c, generalized in M.o):
    # if any env OTHER than the one we're targeting has pytest
    # importable, that env is a candidate the user may have meant —
    # tests that `importorskip` the alternative env's stack will
    # silently SKIP in the targeted env and look green. Warn, list
    # the alternatives, point at the supported escape hatch. One
    # line, non-fatal. Suppressible via PYVE_NO_TESTENV_ADVISORY=1
    # for users who keep pytest in multiple envs deliberately —
    # matrix mode (M.r) sets the env-var inside its per-env subshell.
    # shellcheck disable=SC2031
    if [[ "${PYVE_NO_TESTENV_ADVISORY:-0}" != "1" ]]; then
        local -a advisory_envs=()
        local probe
        # Candidates: root + every declared name (M.o). Skip the
        # target env itself — we're already routing there.
        for probe in root $({ list_env_names; } 2>/dev/null); do
            [[ "$probe" == "$env_target" ]] && continue
            if _test_env_has_pytest "$probe"; then
                advisory_envs+=("$probe")
            fi
        done
        if [[ "${#advisory_envs[@]}" -gt 0 ]]; then
            local rendered=""
            local e
            for e in "${advisory_envs[@]}"; do
                rendered+="--env $e, "
            done
            rendered="${rendered%, }"
            warn "Targeted env '$env_target' may be missing dependencies from other env(s) that also have pytest installed: ${advisory_envs[*]}"
            info "If your tests need a different env's stack, try one of: $rendered"
        fi
    fi

    # Story M.m: touch `.state`'s `last_used_at` before exec so M.p's
    # `pyve testenv list` / `prune` can report which envs are active.
    # Best-effort: silent no-op when `.state` is missing (e.g. an env
    # provisioned before M.m landed `.state` writes in
    # `ensure_env_exists`). Suppress stdout/stderr — the touch
    # is bookkeeping, not user-facing.
    state_touch_last_used "$env_target" >/dev/null 2>&1 || true

    exec "$testenv_venv/bin/python" -m pytest "${args[@]+"${args[@]}"}"
}
