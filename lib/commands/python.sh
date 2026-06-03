# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve python — manage the project's Python version pin
#
# Single-file namespace command (project-essentials F-9): one file
# contains the namespace dispatcher (`python`) and every leaf
# (`python_set`, `python_show`).
#
# Sub-commands:
#   pyve python set <version>     Pin the Python version
#   pyve python show              Read the currently pinned version
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution. The file is a library; running it as a
# script would fall through to nothing useful and confuse the user.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# `python_set` and `python_show` moved to lib/plugins/python/plugin.sh
# in Story N.p (Option (a) — plugin-private extensions). The
# python_command dispatcher below still resolves them by name; bash
# function lookup is global. See [lib/plugins/python/plugin.sh] for
# the implementations.

# Nested-subcommand dispatcher for `pyve python <action> [args]`.
# Story H.e.6 introduced this grammar; the legacy `pyve python-version`
# command that preceded it was removed in Story J.d (v2.3.0).
#
# K.d note: this function is named `python_command`, NOT `python`,
# because `python` is the bare binary name invoked by `init` (and
# elsewhere) for venv creation: `python -m venv .venv`, `python -c
# 'import sys; ...'`. A bash function named `python` would shadow
# the interpreter and break every internal call to it. Same risk
# applies to `test_command` (would shadow the bash builtin) — see
# K.a.3 audit "Function-name collision rule" in `project-essentials.md`.
python_command() {
    if [[ $# -lt 1 ]]; then
        log_error "pyve python requires a subcommand"
        log_error "Usage: pyve python set <version>"
        log_error "       pyve python show"
        log_error "See: pyve python --help"
        exit 1
    fi

    local sub="$1"
    shift

    case "$sub" in
        set)
            python_set "$@"
            ;;
        show)
            if [[ $# -gt 0 ]]; then
                log_error "pyve python show takes no arguments (got: $1)"
                exit 1
            fi
            python_show
            ;;
        *)
            log_error "Unknown python subcommand: $sub"
            log_error "Usage: pyve python set <version>"
            log_error "       pyve python show"
            exit 1
            ;;
    esac
}
show_python_help() {
    cat << 'EOF'
pyve python - Manage the project's Python version pin

Usage:
  pyve python set <version>
  pyve python show

Subcommands:
  set <version>     Pin the project's Python version (format: #.#.#)
                    Writes to .tool-versions (asdf) or .python-version (pyenv)
  show              Print the currently pinned Python version

Examples:
  pyve python set 3.13.7
  pyve python show

See `pyve --help` for the full command list.
EOF
}
