#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Parameter decision-graph — core model & walk engine (Story P.f).
#
# The single source the wizard, flag parser, --help, defaults, explicit
# manifest writer, and drift detector all consume. Representation (per the
# P.e spike): an indexed array of pipe-delimited rows, 9-field schema, walked
# at runtime — no associative arrays (bash 3.2 / test_bash32_compat.bats).
#
# Row schema:
#   name | owner | applicability | choices | default | flag | env | required | label

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/param_graph.sh"
    pg_reset
}

# ────────────────────────────────────────────────────────────────────
# Registry: add / list / count / reset / malformed-row guard
# ────────────────────────────────────────────────────────────────────

@test "pg_add_node + pg_node_count: records a node" {
    pg_add_node "backend|python|language=python|venv,micromamba|venv|--backend|PYVE_BACKEND|yes|Backend"
    run pg_node_count
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}

@test "pg_reset: clears the registry" {
    pg_add_node "a|framework|*|x,y|x|--a|-|no|A"
    pg_reset
    run pg_node_count
    [ "$output" -eq 0 ]
}

@test "pg_list_nodes: preserves registration order" {
    pg_add_node "first|framework|*|x,y|x|--first|-|no|First"
    pg_add_node "second|framework|*|x,y|x|--second|-|no|Second"
    run pg_list_nodes
    [ "${lines[0]%%|*}" = "first" ]
    [ "${lines[1]%%|*}" = "second" ]
}

@test "pg_add_node: rejects a row without exactly 9 fields" {
    run pg_add_node "too|few|fields"
    [ "$status" -ne 0 ]
}

@test "pg_add_node: rejects a label containing the | delimiter" {
    run pg_add_node "a|framework|*|x,y|x|--a|-|no|bad|label"
    [ "$status" -ne 0 ]
}

# ────────────────────────────────────────────────────────────────────
# Answers accumulator (bash-3.2-safe membership string)
# ────────────────────────────────────────────────────────────────────

@test "pg_answer_set / pg_answer_get: round-trips a value" {
    pg_answer_set language python
    run pg_answer_get language
    [ "$output" = "python" ]
}

@test "pg_answer_get: empty for an unset key" {
    run pg_answer_get nope
    [ "$output" = "" ]
}

@test "pg_answer_reset: clears accumulated answers" {
    pg_answer_set language python
    pg_answer_reset
    run pg_answer_get language
    [ "$output" = "" ]
}

# ────────────────────────────────────────────────────────────────────
# Applicability: '*', key=val, and @fn predicates
# ────────────────────────────────────────────────────────────────────

@test "pg_applicable: '*' is always applicable" {
    run pg_applicable "a|framework|*|x,y|x|--a|-|no|A"
    [ "$status" -eq 0 ]
}

@test "pg_applicable: key=val matches a prior answer" {
    pg_answer_set language python
    run pg_applicable "backend|python|language=python|venv|venv|--backend|-|no|Backend"
    [ "$status" -eq 0 ]
}

@test "pg_applicable: key=val prunes when the answer differs" {
    pg_answer_set language node
    run pg_applicable "backend|python|language=python|venv|venv|--backend|-|no|Backend"
    [ "$status" -ne 0 ]
}

@test "pg_applicable: @fn predicate is consulted" {
    pg_answer_set backend venv
    _pred_true() { [ "$(pg_answer_get backend)" = "venv" ]; }
    run pg_applicable "vmgr|python|@_pred_true|asdf,pyenv|asdf|--version-manager|-|no|VM"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────────────────────────────
# Computed choices / defaults via @fn
# ────────────────────────────────────────────────────────────────────

@test "pg_resolve_choices: literal set passes through" {
    run pg_resolve_choices "b|python|*|venv,micromamba|venv|--backend|-|no|B"
    [ "$output" = "venv,micromamba" ]
}

@test "pg_resolve_choices: @fn is invoked" {
    _choices_fn() { printf 'pnpm,npm,yarn'; }
    run pg_resolve_choices "p|node|*|@_choices_fn|pnpm|--provider|-|no|P"
    [ "$output" = "pnpm,npm,yarn" ]
}

@test "pg_resolve_default: @fn computes from prior answers" {
    pg_answer_set language python
    _def_fn() { if [ "$(pg_answer_get language)" = "python" ]; then printf '3.14.6'; else printf 'none'; fi; }
    run pg_resolve_default "v|python|*|-|@_def_fn|--python-version|-|no|V"
    [ "$output" = "3.14.6" ]
}

# ────────────────────────────────────────────────────────────────────
# Walk: pruning + flag resolution + required + validation
# ────────────────────────────────────────────────────────────────────

@test "pg_walk (flags): prunes non-applicable nodes and records the rest" {
    pg_add_node "language|framework|*|python,node|python|--language|-|yes|Language"
    pg_add_node "backend|python|language=python|venv,micromamba|venv|--backend|-|no|Backend"
    pg_add_node "provider|node|language=node|pnpm,npm|pnpm|--provider|-|no|Provider"
    pg_resolve_with_flags
    [ "$(pg_answer_get language)" = "python" ]
    [ "$(pg_answer_get backend)" = "venv" ]
    [ "$(pg_answer_get provider)" = "" ]   # pruned: language != node
}

@test "pg_walk (flags): an explicit flag overrides the default" {
    pg_add_node "backend|python|*|venv,micromamba|venv|--backend|-|no|Backend"
    pg_resolve_with_flags --backend micromamba
    [ "$(pg_answer_get backend)" = "micromamba" ]
}

@test "pg_walk (flags): env var resolves when no flag is given" {
    pg_add_node "backend|python|*|venv,micromamba|venv|--backend|PYVE_TEST_BACKEND|no|Backend"
    PYVE_TEST_BACKEND=micromamba pg_resolve_with_flags
    [ "$(pg_answer_get backend)" = "micromamba" ]
}

@test "pg_walk (flags): flag outranks env var" {
    pg_add_node "backend|python|*|venv,micromamba|venv|--backend|PYVE_TEST_BACKEND|no|Backend"
    PYVE_TEST_BACKEND=venv pg_resolve_with_flags --backend micromamba
    [ "$(pg_answer_get backend)" = "micromamba" ]
}

@test "pg_walk (flags): rejects a value outside the choice set" {
    pg_add_node "backend|python|*|venv,micromamba|venv|--backend|-|no|Backend"
    run pg_resolve_with_flags --backend bogus
    [ "$status" -ne 0 ]
}

@test "pg_walk (flags): free-value node (choices '-') accepts any value" {
    pg_add_node "python-version|python|*|-|3.14.6|--python-version|-|no|Version"
    pg_resolve_with_flags --python-version 3.13.1
    [ "$(pg_answer_get python-version)" = "3.13.1" ]
}

@test "pg_walk (flags): required node with no resolution errors" {
    pg_add_node "language|framework|*|python,node|-|--language|-|yes|Language"
    run pg_resolve_with_flags
    [ "$status" -ne 0 ]
}

# ────────────────────────────────────────────────────────────────────
# Flag-vs-prompt equivalence (the core "one graph, two surfaces" claim)
# ────────────────────────────────────────────────────────────────────

@test "flag and prompt sinks agree when both accept defaults" {
    _graph() {
        pg_reset
        pg_add_node "language|framework|*|python,node|python|--language|-|yes|Language"
        pg_add_node "backend|python|language=python|venv,micromamba|venv|--backend|-|no|Backend"
    }
    _graph
    pg_resolve_with_flags
    local from_flags="${PYVE_PARAM_ANSWERS# }"
    _graph
    pg_resolve_with_prompts            # empty queue → every prompt accepts its default
    local from_prompts="${PYVE_PARAM_ANSWERS# }"
    [ "$from_flags" = "$from_prompts" ]
}

@test "pg_walk (prompts): a queued answer overrides the default" {
    pg_add_node "backend|python|*|venv,micromamba|venv|--backend|-|no|Backend"
    pg_resolve_with_prompts micromamba
    [ "$(pg_answer_get backend)" = "micromamba" ]
}

# ────────────────────────────────────────────────────────────────────
# Framework nodes + plugin contribution seam
# ────────────────────────────────────────────────────────────────────

@test "pg_register_framework_nodes: registers the framework-owned top nodes" {
    pg_register_framework_nodes
    run pg_list_nodes
    [[ "$output" == *"language|framework"* ]]
    [[ "$output" == *"project-guide|framework"* ]]
    [[ "$output" == *"direnv|framework"* ]]
}

@test "pg_build_graph: framework nodes precede contributed subtrees" {
    _py_nodes() {
        pg_add_node "backend|python|language=python|venv,micromamba|venv|--backend|-|no|Backend"
    }
    pg_register_contributor _py_nodes
    pg_build_graph
    run pg_list_nodes
    # language (framework) registered before backend (contributed)
    local lang_line backend_line
    lang_line=$(printf '%s\n' "$output" | grep -n '^language|' | cut -d: -f1)
    backend_line=$(printf '%s\n' "$output" | grep -n '^backend|' | cut -d: -f1)
    [ "$lang_line" -lt "$backend_line" ]
}

@test "pg_build_graph + walk: a contributed subtree prunes by language" {
    _py_nodes() {
        pg_add_node "backend|python|language=python|venv,micromamba|venv|--backend|-|no|Backend"
    }
    pg_register_contributor _py_nodes
    pg_build_graph
    # default language is python → backend applies
    pg_resolve_with_flags
    [ "$(pg_answer_get backend)" = "venv" ]
}

# ────────────────────────────────────────────────────────────────────
# Versioned defaults anchor (drift detection in P.k keys off this)
# ────────────────────────────────────────────────────────────────────

@test "pg_defaults_version: exposes a non-empty version stamp" {
    run pg_defaults_version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
