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

# The full valid-flag set `pyve init` accepts: the pre-P.g.1 hand-maintained
# list (which graph generation must reproduce) plus later operational-toggle
# additions. `--yes` / `-y` are the P.j easy-mode fast-accept flags.
EXPECTED_VALID_FLAGS=(
    --python-version --backend --auto-bootstrap --bootstrap-to
    --strict --no-lock --env-name --no-direnv --node-path
    --auto-install-deps --no-install-deps --local-env --force --allow-synced-dir
    --project-guide --no-project-guide
    --project-guide-completion --no-project-guide-completion
    --yes -y
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

# ── wizard interactivity seam (P.g.3) ───────────────────────────────
# The wizard prompts only the 3 interactive nodes (in graph order); direnv /
# env-name are flag-only. Adding a prompt later = add the node name here +
# define _init_prompt_<name>.

@test "_init_node_is_interactive: true for the three prompted parameters" {
    local n
    for n in backend python-version project-guide; do
        _init_node_is_interactive "$n" || { echo "expected interactive: $n"; false; }
    done
}

@test "_init_node_is_interactive: false for flag-only parameters" {
    local n
    for n in direnv env-name nope; do
        ! _init_node_is_interactive "$n" || { echo "expected non-interactive: $n"; false; }
    done
}

@test "every interactive node has a matching _init_prompt_<name> renderer" {
    _init_build_param_graph
    local row name fn
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        name="${row%%|*}"
        _init_node_is_interactive "$name" || continue
        fn="_init_prompt_${name//-/_}"
        declare -F "$fn" >/dev/null || { echo "missing renderer: $fn"; false; }
    done <<<"$(pg_list_nodes)"
}

# ── defaults consumed from the graph + parser drift guard (P.g.5) ────

@test "_init_param_default: resolves a node's default from the graph" {
    DEFAULT_PYTHON_VERSION="9.9.9"
    run _init_param_default python-version
    [ "$status" -eq 0 ]
    [ "$output" = "9.9.9" ]
}

@test "_init_param_default: non-zero for an unknown node" {
    run _init_param_default no-such-node
    [ "$status" -ne 0 ]
}

@test "drift guard: every graph param flag has an init arg-parser case arm" {
    _init_build_param_graph
    local row f
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        while IFS= read -r f; do
            [[ -n "$f" ]] || continue
            grep -qE "^[[:space:]]*${f}[)=]" "$PYVE_ROOT/lib/plugins/python/plugin.sh" \
                || { echo "graph param flag has no init parser case arm: $f"; false; }
        done <<<"$(pg_node_flags "$row")"
    done <<<"$(pg_list_nodes)"
}
