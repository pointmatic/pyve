#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Retire the pre-composer template writers.
#
# Regression sentinel (mirrors the stale-path sentinels, e.g.
# test_state_layout.bats): the `.envrc` / `.gitignore` writer chains
# that the composition layer (N.ae/N.af) superseded must have NO production
# definition or caller in `lib/` or `pyve.sh`. The composer functions
# (`compose_envrc` / `compose_gitignore` and the per-plugin `activate` /
# `gitignore_entries` hooks) are the only emission path now.
#
# Full-line comments that mention a retired name in passing (the
# "retired in N.al" notes) are allowed; a non-comment reference is a
# regression — it means a writer was resurrected or a caller re-added.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
}

# Retired functions: no production definition or call may remain.
RETIRED_WRITERS=(
    write_envrc_template
    write_gitignore_template
    insert_pattern_in_gitignore_section
    _init_direnv_venv
    _init_direnv_micromamba
    _init_gitignore
    venv_pyve_bp_activate
    micromamba_pyve_bp_activate
)

@test "sentinel: no retired writer has a non-comment reference in lib/ or pyve.sh" {
    local fn offenders=""
    for fn in "${RETIRED_WRITERS[@]}"; do
        # Match the name anywhere in lib/ + pyve.sh, then drop full-line
        # comments (first non-space char is '#'). Anything left is a real
        # definition or call → a regression.
        local hits
        hits="$(grep -rnE "\\b${fn}\\b" "$PYVE_ROOT"/lib "$PYVE_ROOT"/pyve.sh 2>/dev/null \
            | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
        if [[ -n "$hits" ]]; then
            offenders+="[$fn]"$'\n'"$hits"$'\n'
        fi
    done
    if [[ -n "$offenders" ]]; then
        echo "Retired writer(s) still referenced in production:" >&2
        echo "$offenders" >&2
        return 1
    fi
}

@test "sentinel: the composer emission path is intact (compose_envrc / compose_gitignore defined)" {
    source "$PYVE_ROOT/lib/envrc_composer.sh"
    source "$PYVE_ROOT/lib/gitignore_composer.sh"
    declare -F compose_envrc >/dev/null
    declare -F compose_gitignore >/dev/null
}
