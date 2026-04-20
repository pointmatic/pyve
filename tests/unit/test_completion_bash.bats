#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/completion/pyve.bash (Story H.e.9c).
#
# Invokes the `_pyve` completion function directly with
# COMP_WORDS / COMP_CWORD set to simulate what bash passes in
# on TAB. Asserts on COMPREPLY contents.

bats_require_minimum_version 1.5.0

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export COMPLETION_PATH="$PYVE_ROOT/lib/completion/pyve.bash"
}

# Run `_pyve` with a simulated command line and return COMPREPLY joined by spaces.
# Usage: _complete "pyve init --"  → sets $output to the completion candidates.
_complete() {
    local cmdline="$1"
    run bash -c "
        source '$COMPLETION_PATH'
        # Split cmdline into COMP_WORDS; empty trailing arg if cmdline ends with space.
        read -ra COMP_WORDS <<< '$cmdline'
        if [[ '$cmdline' == *' ' ]]; then
            COMP_WORDS+=('')
        fi
        COMP_CWORD=\$(( \${#COMP_WORDS[@]} - 1 ))
        _pyve
        echo \"\${COMPREPLY[@]}\"
    "
}

#============================================================
# Top-level subcommand completion
#============================================================

@test "completion: 'pyve <TAB>' lists all v2.0 top-level subcommands" {
    _complete "pyve "
    [ "$status" -eq 0 ]
    for sub in init purge lock run test testenv check status update python self; do
        [[ " $output " == *" $sub "* ]] || {
            echo "Missing subcommand: $sub" >&2
            echo "Got: $output" >&2
            return 1
        }
    done
}

@test "completion: 'pyve <TAB>' does NOT include removed subcommands" {
    _complete "pyve "
    [ "$status" -eq 0 ]
    [[ "$output" != *"doctor"* ]]
    [[ "$output" != *"validate"* ]]
}

@test "completion: 'pyve --<TAB>' lists top-level flags only" {
    _complete "pyve --"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--help"* ]]
    [[ "$output" == *"--version"* ]]
    [[ "$output" == *"--config"* ]]
    [[ "$output" != *" init "* ]]
}

#============================================================
# `pyve init` flag completion
#============================================================

@test "completion: 'pyve init --<TAB>' lists init flags" {
    _complete "pyve init --"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--backend"* ]]
    [[ "$output" == *"--force"* ]]
    [[ "$output" == *"--python-version"* ]]
    [[ "$output" == *"--no-direnv"* ]]
    [[ "$output" == *"--help"* ]]
}

@test "completion: 'pyve init --<TAB>' does NOT include the removed --update flag" {
    _complete "pyve init --"
    [ "$status" -eq 0 ]
    [[ "$output" != *"--update"* ]]
}

@test "completion: 'pyve init --backend <TAB>' lists valid backends" {
    _complete "pyve init --backend "
    [ "$status" -eq 0 ]
    [[ "$output" == *"venv"* ]]
    [[ "$output" == *"micromamba"* ]]
}

#============================================================
# `pyve testenv` nested completion
#============================================================

@test "completion: 'pyve testenv <TAB>' lists the four actions" {
    _complete "pyve testenv "
    [ "$status" -eq 0 ]
    [[ "$output" == *"init"* ]]
    [[ "$output" == *"install"* ]]
    [[ "$output" == *"purge"* ]]
    [[ "$output" == *"run"* ]]
}

@test "completion: 'pyve testenv <TAB>' does NOT offer legacy --init flag form" {
    _complete "pyve testenv "
    [ "$status" -eq 0 ]
    [[ "$output" != *"--init"* ]]
    [[ "$output" != *"--install"* ]]
    [[ "$output" != *"--purge"* ]]
}

@test "completion: 'pyve testenv install -<TAB>' offers -r and --help" {
    _complete "pyve testenv install -"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-r"* ]]
    [[ "$output" == *"--help"* ]]
}

#============================================================
# `pyve python` nested completion
#============================================================

@test "completion: 'pyve python <TAB>' lists set/show" {
    _complete "pyve python "
    [ "$status" -eq 0 ]
    [[ "$output" == *"set"* ]]
    [[ "$output" == *"show"* ]]
}

#============================================================
# `pyve self` nested completion
#============================================================

@test "completion: 'pyve self <TAB>' lists install/uninstall" {
    _complete "pyve self "
    [ "$status" -eq 0 ]
    [[ "$output" == *"install"* ]]
    [[ "$output" == *"uninstall"* ]]
}

#============================================================
# `pyve update` flag completion
#============================================================

@test "completion: 'pyve update --<TAB>' lists update flags" {
    _complete "pyve update --"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-project-guide"* ]]
    [[ "$output" == *"--help"* ]]
}

#============================================================
# `pyve lock` flag completion
#============================================================

@test "completion: 'pyve lock --<TAB>' lists --check and --help" {
    _complete "pyve lock --"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"--help"* ]]
}

#============================================================
# `pyve purge` flag completion
#============================================================

@test "completion: 'pyve purge --<TAB>' lists --keep-testenv and --help" {
    _complete "pyve purge --"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--keep-testenv"* ]]
    [[ "$output" == *"--help"* ]]
}

#============================================================
# ShellCheck clean on the completion file itself
#============================================================

@test "completion: lib/completion/pyve.bash sources cleanly under bash" {
    run bash -c "source '$COMPLETION_PATH'"
    [ "$status" -eq 0 ]
}
