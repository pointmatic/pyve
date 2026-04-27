# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve status — read-only state dashboard (Story H.e.4)
#
# Three sections: Project / Environment / Integrations. Never has
# a non-zero exit code based on findings — that's `pyve check`'s
# job. `pyve status` reports reality (including "not a pyve
# project" as a valid reality).
#
# Spec: docs/specs/phase-H-check-status-design.md §4.
#
# Function-name note: this function is named `show_status` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule. `status` is a noun, so semantic alignment trumps spelling
# — "show the status" is the operation being performed.
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

show_status() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "status" "$1" --help
                ;;
            *)
                log_error "pyve status takes no positional arguments (got: $1)"
                log_error "See: pyve status --help"
                exit 1
                ;;
        esac
    done

    # Title + divider. BOLD for the title, DIM for the rule — per H.c §4.4.
    printf "\n%sPyve project status%s\n" "${BOLD}" "${RESET}"
    printf "%s───────────────────%s\n\n" "${DIM}" "${RESET}"

    if ! config_file_exists; then
        # Non-project fallback. Don't treat it as an error; status reports
        # reality, and "not a pyve project" is a valid reality.
        _status_row "Not a pyve-managed project" ""
        printf "  %sRun 'pyve init' to initialize.%s\n\n" "${DIM}" "${RESET}"
        return 0
    fi

    _status_section_project
    _status_section_environment
    _status_section_integrations

    return 0
}

# Print one key/value row with a 17-char label column (matches the widest
# label used — "environment.yml:") so every section aligns.
_status_row() {
    local label="$1"
    local value="$2"
    printf "  %-17s %s\n" "${label}" "${value}"
}

_status_header() {
    printf "%s%s%s\n" "${BOLD}" "$1" "${RESET}"
}

_status_section_project() {
    _status_header "Project"
    _status_row "Path:" "$(pwd -P)"

    local backend
    backend="$(read_config_value "backend" 2>/dev/null || true)"
    if [[ -n "$backend" ]]; then
        _status_row "Backend:" "$backend"
    else
        _status_row "Backend:" "${DIM}not configured${RESET}"
    fi

    local recorded_version
    recorded_version="$(read_config_value "pyve_version" 2>/dev/null || true)"
    if [[ -z "$recorded_version" ]]; then
        _status_row "Pyve config:" "${DIM}version not recorded${RESET}"
    else
        case "$(compare_versions "$recorded_version" "$VERSION")" in
            equal)
                _status_row "Pyve config:" "v${recorded_version} (current)"
                ;;
            less)
                _status_row "Pyve config:" "v${recorded_version} (current: v${VERSION})"
                ;;
            greater)
                _status_row "Pyve config:" "v${recorded_version} (newer than pyve v${VERSION})"
                ;;
        esac
    fi

    _status_row "Python:" "$(_status_configured_python)"
    printf "\n"
}

# Detect the configured Python version source. Returns a human-readable
# string like "3.14.4 (.tool-versions via asdf)" or "(not pinned)".
_status_configured_python() {
    local version="" source=""
    if [[ -f ".tool-versions" ]]; then
        version="$(grep "^python " .tool-versions 2>/dev/null | awk '{print $2}')"
        source=".tool-versions via asdf"
    elif [[ -f ".python-version" ]]; then
        version="$(cat .python-version 2>/dev/null)"
        source=".python-version via pyenv"
    else
        version="$(read_config_value "python.version" 2>/dev/null || true)"
        source=".pyve/config"
    fi
    if [[ -z "$version" ]]; then
        printf "%snot pinned%s" "${DIM}" "${RESET}"
    else
        printf "%s (%s)" "${version}" "${source}"
    fi
}

_status_section_environment() {
    _status_header "Environment"

    local backend
    backend="$(read_config_value "backend" 2>/dev/null || true)"

    if [[ "$backend" == "micromamba" ]]; then
        _status_env_micromamba
    elif [[ "$backend" == "venv" ]]; then
        _status_env_venv
    else
        _status_row "Path:" "${DIM}backend not configured${RESET}"
    fi

    printf "\n"
}

_status_env_venv() {
    local venv_dir
    venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
    venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"

    if [[ ! -d "$venv_dir" ]]; then
        _status_row "Path:" "${venv_dir} (${DIM}missing${RESET})"
        return 0
    fi
    _status_row "Path:" "$venv_dir"

    if [[ -x "$venv_dir/bin/python" ]]; then
        local py_version
        py_version="$("$venv_dir/bin/python" --version 2>&1 | awk '{print $2}')"
        _status_row "Python:" "${py_version:-unknown}"
    else
        _status_row "Python:" "${DIM}not found${RESET}"
    fi

    _status_row "Packages:" "$(_status_venv_package_count "$venv_dir")"

    # distutils shim: check for the sitecustomize.py marker under
    # $venv_dir/lib/python*/site-packages/ (Python 3.12+ install).
    # Guard: `find` on a nonexistent .venv/lib exits non-zero, which
    # would kill the script under `set -euo pipefail` — trailing
    # `|| true` absorbs it.
    if [[ -d "$venv_dir/lib" ]]; then
        local sitecustomize
        sitecustomize="$(find "$venv_dir/lib" -maxdepth 3 -name "sitecustomize.py" 2>/dev/null | head -1 || true)"
        if [[ -n "$sitecustomize" ]] && grep -qF "$PYVE_DISTUTILS_SHIM_MARKER" "$sitecustomize" 2>/dev/null; then
            _status_row "distutils shim:" "installed"
        else
            _status_row "distutils shim:" "${DIM}not installed${RESET}"
        fi
    fi
}

_status_venv_package_count() {
    local venv_dir="$1"
    local site_packages count
    # Same `find`-pipefail guard as above.
    if [[ ! -d "$venv_dir/lib" ]]; then
        printf "%sunknown%s" "${DIM}" "${RESET}"
        return 0
    fi
    site_packages="$(find "$venv_dir/lib" -type d -name "site-packages" 2>/dev/null | head -1 || true)"
    if [[ -z "$site_packages" ]]; then
        printf "%sunknown%s" "${DIM}" "${RESET}"
        return 0
    fi
    count="$(find "$site_packages" -maxdepth 1 -name "*.dist-info" 2>/dev/null | wc -l | tr -d ' ' || true)"
    printf "%s installed" "${count:-0}"
}

_status_env_micromamba() {
    local env_name env_path
    env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
    if [[ -z "$env_name" ]]; then
        _status_row "Name:" "${DIM}not configured${RESET}"
        return 0
    fi
    env_path=".pyve/envs/$env_name"

    _status_row "Name:" "$env_name"

    if [[ ! -d "$env_path" ]]; then
        _status_row "Path:" "${env_path} (${DIM}missing${RESET})"
        return 0
    fi
    _status_row "Path:" "$env_path"

    if [[ -x "$env_path/bin/python" ]]; then
        local py_version
        py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
        _status_row "Python:" "${py_version:-unknown}"
    fi

    if [[ -d "$env_path/conda-meta" ]]; then
        local count
        count="$(find "$env_path/conda-meta" -name "*.json" 2>/dev/null | wc -l | tr -d ' ' || true)"
        _status_row "Packages:" "${count:-0} installed"
    fi

    if [[ -f "environment.yml" ]]; then
        _status_row "environment.yml:" "present"
    else
        _status_row "environment.yml:" "${DIM}missing${RESET}"
    fi

    if [[ -f "conda-lock.yml" ]]; then
        if is_lock_file_stale 2>/dev/null; then
            _status_row "conda-lock.yml:" "${DIM}stale${RESET}"
        else
            _status_row "conda-lock.yml:" "up to date"
        fi
    else
        _status_row "conda-lock.yml:" "${DIM}missing${RESET}"
    fi
}

_status_section_integrations() {
    _status_header "Integrations"

    if [[ -f ".envrc" ]]; then
        _status_row "direnv:" ".envrc present"
    else
        _status_row "direnv:" "${DIM}.envrc missing${RESET}"
    fi

    if [[ -f ".env" ]]; then
        if is_file_empty ".env"; then
            _status_row ".env:" "present (empty)"
        else
            _status_row ".env:" "present"
        fi
    else
        _status_row ".env:" "${DIM}missing${RESET}"
    fi

    # project-guide: look for the binary in the project environment.
    local backend env_path pg_info
    backend="$(read_config_value "backend" 2>/dev/null || true)"
    env_path=""
    if [[ "$backend" == "venv" ]]; then
        local venv_dir
        venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
        env_path="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
    elif [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
        [[ -n "$env_name" ]] && env_path=".pyve/envs/$env_name"
    fi
    if [[ -n "$env_path" ]] && [[ -x "$env_path/bin/project-guide" ]]; then
        pg_info="$("$env_path/bin/project-guide" --version 2>/dev/null | head -1 | awk '{print $NF}')"
        if [[ -n "$pg_info" ]]; then
            _status_row "project-guide:" "installed (v${pg_info})"
        else
            _status_row "project-guide:" "installed"
        fi
    else
        _status_row "project-guide:" "${DIM}not installed${RESET}"
    fi

    local testenv_venv=".pyve/$TESTENV_DIR_NAME/venv"
    if [[ -d "$testenv_venv" ]]; then
        if [[ -x "$testenv_venv/bin/python" ]] && \
           "$testenv_venv/bin/python" -c 'import pytest' >/dev/null 2>&1; then
            _status_row "testenv:" "present, pytest installed"
        elif [[ -x "$testenv_venv/bin/python" ]]; then
            _status_row "testenv:" "present, pytest ${DIM}not installed${RESET}"
        else
            _status_row "testenv:" "present (${DIM}broken${RESET})"
        fi
    else
        _status_row "testenv:" "${DIM}not present${RESET}"
    fi

    printf "\n"
}
