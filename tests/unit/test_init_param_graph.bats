#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# `pyve init` non-interactive surface single-sourced from the decision-graph
# (Story P.g.1). The Python-plugin builder defines the 5 parameter nodes; the
# valid-flag allow-list (consumed by unknown_flag_error) is generated from the
# graph ⊕ the retained operational toggles. Parity bar: the generated valid-flag
# set equals the previously hand-maintained set, and `show_init_help` mentions
# every graph param flag (drift guard) — both substring/set checks, matching the
# existing test_unknown_flag.bats / test_subcommand_help.bats bars.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/param_graph.sh"
    : "${DEFAULT_PYTHON_VERSION:=3.14.6}"
    pg_reset
}

# The five decision-graph parameters and their CLI flag-sets.
PARAM_FLAGS=(--backend --python-version --project-guide --no-project-guide --no-direnv --env-name)

# The full valid-flag set `pyve init` accepted before P.g.1 (the list that was
# hand-maintained in the unknown_flag_error call). Generation must reproduce it.
EXPECTED_VALID_FLAGS=(
    --python-version --backend --auto-bootstrap --bootstrap-to
    --strict --no-lock --env-name --no-direnv --node-path
    --auto-install-deps --no-install-deps --local-env --force --allow-synced-dir
    --project-guide --no-project-guide
    --project-guide-completion --no-project-guide-completion
    --help
)

@test "_init_build_param_graph: registers the 5 parameter nodes" {
    _init_build_param_graph
    run pg_node_count
    [ "$output" -eq 5 ]
}

@test "_init_build_param_graph: each param node exposes its CLI flag(s)" {
    _init_build_param_graph
    run pg_list_nodes
    local f
    for f in "${PARAM_FLAGS[@]}"; do
        [[ "$output" == *"$f"* ]] || { echo "missing flag in graph: $f"; false; }
    done
}

@test "_init_valid_flags: generated set equals the pre-P.g.1 hand-maintained set" {
    local got expected
    got="$(_init_valid_flags | sort -u | tr '\n' ' ')"
    expected="$(printf '%s\n' "${EXPECTED_VALID_FLAGS[@]}" | sort -u | tr '\n' ' ')"
    [ "$got" = "$expected" ]
}

@test "_init_valid_flags: includes graph flags, operational toggles, and --help" {
    local flags
    flags="$(_init_valid_flags)"
    local f
    for f in "${PARAM_FLAGS[@]}" --force --strict --node-path --help; do
        [[ "$flags" == *"$f"* ]] || { echo "missing: $f"; false; }
    done
}

@test "drift guard: show_init_help mentions every graph param flag" {
    local help f
    help="$(show_init_help)"
    for f in "${PARAM_FLAGS[@]}"; do
        [[ "$help" == *"$f"* ]] || { echo "show_init_help missing graph flag: $f"; false; }
    done
}
