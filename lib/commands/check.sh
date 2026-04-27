# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve check — read-only diagnostics (Story H.e.3)
#
# Replaces the semantic of `pyve validate` (structured 0/1/2 exit
# codes for CI) and most of `pyve doctor` (per-problem findings
# with one actionable next-step). State reporting is `pyve status`
# (H.e.4), not here.
#
# Spec: docs/specs/phase-H-check-status-design.md §3.
#
# Severity ladder: info (no effect) → pass (✓) → warn (⚠, exit 2)
# → error (✗, exit 1). Escalation is one-way: an error later in
# the run cannot be downgraded; a warning cannot downgrade an
# error.
#
# Function-name note: this function is named `check_environment`
# per the project-essentials "Function naming convention:
# verb_<operand>" rule — `pyve check` operates on the project's
# environment (venv / micromamba env, .envrc, .env, testenv).
#
# Closure pattern: `check_environment` defines three nested
# functions (`_check_pass`, `_check_warn`, `_check_fail`) that
# capture the locals `errors`, `warnings`, `passed`, `exit_code`
# via bash dynamic scoping. The per-backend helpers
# (`_check_venv_backend`, `_check_micromamba_backend`) and
# `_check_summary_and_exit` defined at file scope below see those
# locals at call time because bash resolves variable references
# up the call stack, not by lexical scope. **Do not refactor to
# file-scope counters** — the closure shape is intentional and
# tested by `test_check.bats`.
#
# `doctor_check_*` helpers stay in `lib/utils.sh` (cross-command
# rule — `pyve check --fix` and other future callers may need
# them).
#
# This file is sourced by pyve.sh's library-loading block. It
# must not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

check_environment() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "check" "$1" --help
                ;;
            *)
                log_error "pyve check takes no positional arguments (got: $1)"
                log_error "See: pyve check --help"
                exit 1
                ;;
        esac
    done

    local errors=0
    local warnings=0
    local passed=0
    local exit_code=0

    _check_pass() {
        printf "✓ %s\n" "$1"
        passed=$((passed + 1))
    }
    _check_warn() {
        printf "⚠ %s\n" "$1"
        [[ -n "${2:-}" ]] && printf "  %s\n" "$2"
        warnings=$((warnings + 1))
        if (( exit_code != 1 )); then
            exit_code=2
        fi
    }
    _check_fail() {
        printf "✗ %s\n" "$1"
        [[ -n "${2:-}" ]] && printf "  %s\n" "$2"
        errors=$((errors + 1))
        exit_code=1
    }

    printf "Pyve Environment Check\n"
    printf "======================\n\n"

    # --- Check 1: .pyve/config present ------------------------------------
    if ! config_file_exists; then
        _check_fail "Configuration: .pyve/config missing" "→ Run: pyve init"
        _check_summary_and_exit
    fi
    _check_pass "Configuration: .pyve/config"

    # --- Check 3: backend configured --------------------------------------
    # (Check 2 slots below — runs after we know the backend so we can
    # point the user at either `pyve update` or `pyve init --force` as
    # appropriate.)
    local backend
    backend="$(read_config_value "backend")"
    if [[ -z "$backend" ]]; then
        _check_fail "Backend: not configured in .pyve/config" \
            "→ Run: pyve init --backend venv|micromamba"
        _check_summary_and_exit
    fi
    _check_pass "Backend: $backend"

    # --- Check 2: pyve_version drift --------------------------------------
    local recorded_version
    recorded_version="$(read_config_value "pyve_version")"
    if [[ -z "$recorded_version" ]]; then
        _check_warn "Pyve version: not recorded (legacy project)" \
            "→ Run: pyve update"
    else
        case "$(compare_versions "$recorded_version" "$VERSION")" in
            equal)
                _check_pass "Pyve version: $recorded_version (current)"
                ;;
            less)
                _check_warn "Pyve version: $recorded_version (current: $VERSION)" \
                    "→ Run: pyve update"
                ;;
            greater)
                _check_warn "Pyve version: $recorded_version (newer than running pyve v$VERSION)" \
                    "→ Upgrade pyve or re-initialize the project"
                ;;
        esac
    fi

    # --- Backend-specific checks ------------------------------------------
    local env_path=""
    if [[ "$backend" == "venv" ]]; then
        local venv_dir
        venv_dir="$(read_config_value "venv.directory")"
        venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
        env_path="$venv_dir"
        _check_venv_backend "$env_path"
    elif [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name")"
        if [[ -n "$env_name" ]]; then
            env_path=".pyve/envs/$env_name"
        fi
        _check_micromamba_backend "$env_path" "$env_name"
    else
        _check_fail "Backend: unknown value '$backend'" \
            "→ Run: pyve init --backend venv|micromamba"
    fi

    # --- Common integration checks ----------------------------------------
    # Check 9: .envrc
    if [[ -f ".envrc" ]]; then
        _check_pass "direnv: .envrc present"
    else
        _check_warn ".envrc: missing" "→ Run: pyve init --force"
    fi

    # Check 10: .env
    if [[ -f ".env" ]]; then
        _check_pass ".env: present"
    else
        _check_warn ".env: missing" "→ Run: touch .env"
    fi

    # Check 16: testenv (conditional — only warn if exists but broken)
    local testenv_venv=".pyve/$TESTENV_DIR_NAME/venv"
    if [[ -d "$testenv_venv" ]]; then
        if [[ -x "$testenv_venv/bin/python" ]] && \
           "$testenv_venv/bin/python" -c 'import pytest' >/dev/null 2>&1; then
            _check_pass "testenv: pytest installed"
        else
            _check_warn "testenv: present but pytest not installed" \
                "→ Run: pyve test"
        fi
    fi

    _check_summary_and_exit
}

# Per-backend helpers. These escalate via the outer _check_* closures and
# consult the outer-scoped env_path.

_check_venv_backend() {
    local venv_dir="$1"

    # Check 5: venv directory + python executable.
    if [[ ! -d "$venv_dir" ]]; then
        _check_fail "Environment: $venv_dir (missing)" "→ Run: pyve init --force"
        return 0
    fi
    if [[ ! -x "$venv_dir/bin/python" ]]; then
        _check_fail "Environment: $venv_dir/bin/python (missing or not executable)" \
            "→ Run: pyve init --force"
        return 0
    fi
    _check_pass "Environment: $venv_dir"

    # Python version (informational for now; full version-match gate
    # against .tool-versions / .python-version is deferred to a
    # follow-up H.e.3 polish).
    local py_version
    py_version="$("$venv_dir/bin/python" --version 2>&1 | awk '{print $2}')"
    if [[ -n "$py_version" ]]; then
        _check_pass "Python: $py_version"
    fi

    # Check 7: venv path mismatch (relocated project).
    local path_output
    path_output="$(doctor_check_venv_path "$venv_dir")"
    if [[ -n "$path_output" ]]; then
        _check_fail "Environment: venv path mismatch (project may have been relocated)" \
            "→ Run: pyve init --force"
    fi

    # Check 13: duplicate dist-info.
    local dup_output
    dup_output="$(doctor_check_duplicate_dist_info "$venv_dir")"
    if [[ "$dup_output" == *"Duplicate dist-info detected"* ]]; then
        _check_fail "Environment: duplicate dist-info directories detected" \
            "→ Run: pyve init --force"
    fi

    # Check 14: cloud sync collision artifacts.
    local collision_output
    collision_output="$(doctor_check_collision_artifacts "$venv_dir")"
    if [[ "$collision_output" == *"Cloud sync collision artifacts detected"* ]]; then
        _check_fail "Environment: cloud sync collision artifacts detected" \
            "→ Move the project outside a cloud-synced directory, then: pyve init --force"
    fi
}

_check_micromamba_backend() {
    local env_path="$1"
    local env_name="$2"

    # Check 4: micromamba binary available.
    if ! check_micromamba_available; then
        _check_fail "Backend: micromamba binary not found" \
            "→ Run: pyve init   (triggers bootstrap)"
        return 0
    fi
    _check_pass "Micromamba: available"

    # Check: environment.yml present.
    if [[ ! -f "environment.yml" ]]; then
        _check_fail "environment.yml: missing" \
            "→ Run: pyve init --backend micromamba"
        return 0
    fi
    _check_pass "environment.yml: present"

    # Check 11 / 12: conda-lock.yml present and fresh.
    if [[ ! -f "conda-lock.yml" ]]; then
        _check_warn "conda-lock.yml: missing" "→ Run: pyve lock"
    elif is_lock_file_stale; then
        _check_warn "conda-lock.yml: stale (older than environment.yml)" \
            "→ Run: pyve lock"
    else
        _check_pass "conda-lock.yml: up to date"
    fi

    # Check 5: environment directory exists.
    if [[ -z "$env_path" ]] || [[ ! -d "$env_path" ]]; then
        _check_fail "Environment: $env_path (missing)" "→ Run: pyve init --force"
        return 0
    fi
    if [[ ! -x "$env_path/bin/python" ]]; then
        _check_fail "Environment: $env_path/bin/python (missing or not executable)" \
            "→ Run: pyve init --force"
        return 0
    fi
    _check_pass "Environment: $env_path"

    # Python version (informational).
    local py_version
    py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
    if [[ -n "$py_version" ]]; then
        _check_pass "Python: $py_version"
    fi

    # Check 13 / 14 / 15 reuse the existing helpers.
    local dup_output
    dup_output="$(doctor_check_duplicate_dist_info "$env_path")"
    if [[ "$dup_output" == *"Duplicate dist-info detected"* ]]; then
        _check_fail "Environment: duplicate dist-info directories detected" \
            "→ Run: pyve init --force"
    fi

    local collision_output
    collision_output="$(doctor_check_collision_artifacts "$env_path")"
    if [[ "$collision_output" == *"Cloud sync collision artifacts detected"* ]]; then
        _check_fail "Environment: cloud sync collision artifacts detected" \
            "→ Move the project outside a cloud-synced directory, then: pyve init --force"
    fi

    local native_output
    native_output="$(doctor_check_native_lib_conflicts "$env_path")"
    if [[ "$native_output" == *"Potential native library conflict"* ]]; then
        _check_warn "Environment: potential pip/conda native library conflict" \
            "→ Add the missing OpenMP package to environment.yml, then: pyve lock"
    fi
}

_check_summary_and_exit() {
    printf "\n"
    printf "%d passed, %d warnings, %d errors\n" "$passed" "$warnings" "$errors"
    exit "$exit_code"
}
