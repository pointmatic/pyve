# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# shellcheck disable=SC2207
# SC2207: word-split + glob in `COMPREPLY=( $(compgen ...) )` is the
# portable bash-3.2 shape for completion. `mapfile` would be cleaner
# but requires bash 4+, which macOS /bin/bash (3.2.57) doesn't have.
# All $words values passed to compgen are local flag-name strings we
# control — no user input, no globbing risk.
#
# Bash completion for pyve (v2.0 surface, Story H.e.9c; bash 3.2
# compatibility lock-in via H.e.9h).
#
# To enable: source this file from your ~/.bashrc or equivalent:
#   source ~/.local/bin/lib/completion/pyve.bash
#
# The `pyve self install` command emits these instructions on install.
#
# Completes:
#   - Top-level subcommands and flags.
#   - Per-subcommand flag lists (drawn from pyve.sh's actual parsers).
#   - Nested subcommands: testenv init|install|purge|run,
#     python set|show, self install|uninstall.
#
# Does NOT complete:
#   - Legacy flag forms (e.g., `testenv --init`) — nudging users
#     toward the v2.0-canonical shapes.
#   - Values (e.g., available python versions for --python-version).
#     Flag-name completion only in this release.

_pyve() {
    local cur cword
    cur="${COMP_WORDS[COMP_CWORD]}"
    cword=$COMP_CWORD

    local top_subcommands="init purge lock run test testenv check status update python self"
    local top_flags="--help --version --config -h -v -c"

    local init_flags="--allow-synced-dir --auto-bootstrap --auto-install-deps --backend --bootstrap-to --env-name --force --local-env --no-direnv --no-install-deps --no-lock --no-project-guide --no-project-guide-completion --project-guide --project-guide-completion --python-version --strict --help"
    local purge_flags="--keep-testenv --help"
    local lock_flags="--check --help"
    local update_flags="--no-project-guide --help"
    local check_flags="--help"
    local status_flags="--help"

    local backends="venv micromamba"

    # Position 1: top-level subcommand or top-level flag.
    if [[ $cword -eq 1 ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "$top_flags" -- "$cur") )
        else
            COMPREPLY=( $(compgen -W "$top_subcommands $top_flags" -- "$cur") )
        fi
        return 0
    fi

    local subcmd="${COMP_WORDS[1]}"
    local prev="${COMP_WORDS[cword-1]}"

    case "$subcmd" in
        init)
            # Value completion for a couple of high-value flags.
            case "$prev" in
                --backend) COMPREPLY=( $(compgen -W "$backends" -- "$cur") ); return 0 ;;
            esac
            COMPREPLY=( $(compgen -W "$init_flags" -- "$cur") )
            ;;
        purge)
            COMPREPLY=( $(compgen -W "$purge_flags" -- "$cur") )
            ;;
        lock)
            COMPREPLY=( $(compgen -W "$lock_flags" -- "$cur") )
            ;;
        update)
            COMPREPLY=( $(compgen -W "$update_flags" -- "$cur") )
            ;;
        check)
            COMPREPLY=( $(compgen -W "$check_flags" -- "$cur") )
            ;;
        status)
            COMPREPLY=( $(compgen -W "$status_flags" -- "$cur") )
            ;;
        testenv)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "init install purge run --help" -- "$cur") )
                return 0
            fi
            local action="${COMP_WORDS[2]}"
            case "$action" in
                install)
                    case "$prev" in
                        -r|--requirements)
                            COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
                    esac
                    COMPREPLY=( $(compgen -W "-r --requirements --help" -- "$cur") )
                    ;;
                init|purge)
                    COMPREPLY=( $(compgen -W "--help" -- "$cur") )
                    ;;
                run)
                    # Pass-through to the user's command.
                    COMPREPLY=( $(compgen -c -- "$cur") )
                    ;;
            esac
            ;;
        python)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "set show --help" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            fi
            ;;
        self)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "install uninstall --help" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            fi
            ;;
        run|test)
            # Pass-through: user is providing the command/pytest args.
            COMPREPLY=( $(compgen -c -- "$cur") )
            ;;
    esac

    return 0
}

complete -F _pyve pyve
