# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve testenv — manage a dedicated dev/test runner environment
#
# Single-file namespace command (project-essentials F-9): one file
# contains the namespace dispatcher (`testenv_command`) and every
# leaf (`testenv_init`, `testenv_install`, `testenv_purge`,
# `testenv_run`).
#
# Sub-commands:
#   pyve testenv init                    Create .pyve/testenv/venv
#   pyve testenv install [-r <file>]     Install pytest (or -r reqs)
#   pyve testenv purge                   Remove .pyve/testenv
#   pyve testenv run <cmd> [args...]     exec a command inside testenv
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Leaf: pyve testenv init
#------------------------------------------------------------

testenv_init() {
    ensure_testenv_exists
}

#------------------------------------------------------------
# Leaf: pyve testenv install [-r <requirements_file>]
#
# Pre-condition: testenv must already exist. Without -r, installs
# bare `pytest`. With -r, installs from the named requirements file.
#------------------------------------------------------------

testenv_install() {
    local testenv_venv="$1"
    local requirements_file="$2"

    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        log_error "Dev/test runner environment not initialized"
        log_error "Run: pyve testenv init"
        exit 1
    fi
    info "Installing dev/test dependencies into '$testenv_venv'..."
    if [[ -n "$requirements_file" ]]; then
        if [[ ! -f "$requirements_file" ]]; then
            log_error "Requirements file not found: $requirements_file"
            exit 1
        fi
        run_cmd "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
    else
        run_cmd "$testenv_venv/bin/python" -m pip install pytest
    fi
    success "Dev/test dependencies installed"
}

#------------------------------------------------------------
# Leaf: pyve testenv purge
#------------------------------------------------------------

testenv_purge() {
    purge_testenv_dir
}

#------------------------------------------------------------
# Leaf: pyve testenv run <command> [args...]
#
# `exec`s into the target command. The dispatcher emits no header/
# footer because exec replaces the shell — the called command owns
# the rest of the terminal.
#------------------------------------------------------------

testenv_run() {
    local testenv_venv="$1"
    shift

    if [[ $# -lt 1 ]]; then
        log_error "No command provided"
        log_error "Usage: pyve testenv run <command> [args...]"
        log_error "Example: pyve testenv run ruff check ."
        exit 1
    fi
    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        log_error "Dev/test runner environment not initialized"
        log_error "Run: pyve testenv init"
        exit 1
    fi
    local cmd="$1"
    shift
    local testenv_bin="$testenv_venv/bin"
    local cmd_path="$testenv_bin/$cmd"
    if [[ -x "$cmd_path" ]]; then
        exec "$cmd_path" "$@"
    fi
    export VIRTUAL_ENV="$PWD/$testenv_venv"
    export PATH="$testenv_bin:$PATH"
    exec "$cmd" "$@"
}

#------------------------------------------------------------
# Namespace dispatcher: pyve testenv <subcommand>
#
# Function-name note: this function is named `testenv_command` per
# the project-essentials "Function naming convention: verb_<operand>"
# rule — for namespace dispatchers the operand is the sub-command
# name that follows.
#------------------------------------------------------------

testenv_command() {
    local action=""
    local requirements_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            # New subcommand grammar (H.d §4.4 D5) — silent.
            init)
                action="init"
                shift
                ;;
            install)
                action="install"
                shift
                ;;
            purge)
                action="purge"
                shift
                ;;
            # Story J.d (v2.3.0): Category A legacy flag forms
            # (`testenv --init|--install|--purge`) removed. Falls through
            # to the `-*)` arm below, which produces the standard
            # unknown-flag error.
            -r|--requirements)
                if [[ -z "${2:-}" ]]; then
                    log_error "$1 requires a file path"
                    exit 1
                fi
                requirements_file="$2"
                shift 2
                ;;
            run)
                action="run"
                shift
                break  # Remaining args are the command to execute
                ;;
            --help|-h)
                cat << 'EOF'
pyve testenv - Manage a dedicated dev/test runner environment

Usage:
  pyve testenv init
  pyve testenv install [-r requirements-dev.txt]
  pyve testenv purge
  pyve testenv run <command> [args...]

Notes:
  - Uses: .pyve/testenv/venv
  - This environment is preserved across `pyve init --force` and `pyve purge`.
  - `run` executes a command inside the dev/test runner environment.
EOF
                exit 0
                ;;
            -*)
                unknown_flag_error "testenv" "$1" \
                    --requirements -r --help
                ;;
            *)
                log_error "Unknown testenv argument: $1"
                log_error "Usage: pyve testenv <init|install|purge|run> [options]"
                exit 1
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        log_error "No testenv action provided"
        log_error "Use: pyve testenv <init|install|purge|run <command>>"
        exit 1
    fi

    local testenv_root=".pyve/$TESTENV_DIR_NAME"
    local testenv_venv="$testenv_root/venv"

    # `run` exec's into the target command, so the header/footer wrapper
    # would never close. Skip the box and dispatch directly — the called
    # command owns the rest of the terminal.
    if [[ "$action" == "run" ]]; then
        testenv_run "$testenv_venv" "$@"
        return  # not reached on success (exec) but kept for clarity
    fi

    header_box "pyve testenv"

    case "$action" in
        init)
            testenv_init
            ;;
        install)
            testenv_install "$testenv_venv" "$requirements_file"
            ;;
        purge)
            testenv_purge
            ;;
    esac

    footer_box
}
