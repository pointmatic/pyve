# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/param_graph.sh — the keystone parameter decision-graph engine
#
# One source the wizard, flag/CLI parser, `--help`, defaults, the explicit
# `pyve.toml` writer, and default-drift detection all consume — replacing the
# four hand-synced sites in lib/plugins/python/plugin.sh (migrated in P.g).
#
# Representation (decided by the P.e architectural spike): the graph is an
# indexed array of pipe-delimited rows, walked at runtime. Associative arrays
# (`declare -A`) are deliberately NOT used — they require bash 4.0+, macOS
# ships bash 3.2, and the suite forbids them (tests/unit/test_bash32_compat.bats).
#
# Row schema (9 fields, pipe-delimited):
#
#   name | owner | applicability | choices | default | flag | env | required | label
#
#   applicability : '*'        -> always applicable
#                   'key=val'  -> applies only when a prior answer matches
#                   '@fn'      -> a predicate function (computed; reads answers)
#   choices       : 'a,b,c'    -> enumerated set (validated)
#                   '@fn'      -> computed from prior answers
#                   '-'        -> free value (no enumerated set; e.g. a version)
#   default       : literal | '@fn' (computed) | '-' (none)
#   env           : env var name | '-'
#   required      : yes | no
#   label         : human text (wizard prompt + `--help` line); must not contain '|'
#
# The walk resolves each applicable node identically for every surface: a
# pluggable value-source returns the *explicit* selection (or empty), then the
# engine applies the default, validates against the choice set, and enforces
# `required`. Default-application lives in ONE place, so the wizard and the
# flag parser can never diverge (the "one graph, two surfaces" guarantee).
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Versioned-defaults anchor. The defaults baked into the framework/plugin node
# rows are the *current* default set; bumping this stamp when a default changes
# is what lets P.k report drift without retroactively rewriting a repo's pins.
PYVE_PARAM_DEFAULTS_VERSION="1"

# Internal state. Indexed arrays + a membership string — all bash-3.2-safe under
# `set -u`; tests reset via pg_reset.
PYVE_PARAM_NODES=()
PYVE_PARAM_CONTRIBUTORS=()
PYVE_PARAM_ANSWERS=" "

# ────────────────────────────────────────────────────────────────────
# Registry
# ────────────────────────────────────────────────────────────────────

# Reset everything (nodes, contributors, answers). Used by tests and by a
# fresh `pyve init` invocation before (re)building the graph.
pg_reset() {
    PYVE_PARAM_NODES=()
    PYVE_PARAM_CONTRIBUTORS=()
    PYVE_PARAM_ANSWERS=" "
}

# Register one node from a pipe-delimited row. Validates the row carries exactly
# 9 fields (8 delimiters): a label that smuggled a '|' would silently shift
# every field, so reject it loudly rather than mis-parse.
pg_add_node() {
    local row="$1"
    local pipes="${row//[^|]/}"
    if [[ ${#pipes} -ne 8 ]]; then
        printf 'pg_add_node: malformed row (need 9 |-delimited fields): %s\n' "$row" >&2
        return 1
    fi
    PYVE_PARAM_NODES+=("$row")
}

# Number of registered nodes.
pg_node_count() {
    printf '%s\n' "${#PYVE_PARAM_NODES[@]}"
}

# Print every node row, one per line, in registration order.
pg_list_nodes() {
    local row
    for row in "${PYVE_PARAM_NODES[@]+"${PYVE_PARAM_NODES[@]}"}"; do
        printf '%s\n' "$row"
    done
}

# Field access — each consumer parses a row ONCE with a single `IFS='|' read`
# into positional locals (not nine `cut` calls). The full nine-name split below
# is the canonical unpack; functions that need a subset still read all nine so
# the column order lives in exactly one place.

# ────────────────────────────────────────────────────────────────────
# Answers accumulator (bash-3.2-safe membership string; mirrors the idiom in
# lib/commands/env.sh's _env_list_all_names — no associative array needed).
# ────────────────────────────────────────────────────────────────────
pg_answer_reset() { PYVE_PARAM_ANSWERS=" "; }

pg_answer_set() {
    # Last write wins: drop any prior value for this key, then append.
    local key="$1" val="$2" tok rebuilt=" "
    for tok in $PYVE_PARAM_ANSWERS; do
        case "$tok" in "$key="*) : ;; *) rebuilt+="$tok " ;; esac
    done
    PYVE_PARAM_ANSWERS="$rebuilt$key=$val "
}

pg_answer_get() {
    local key="$1" tok
    for tok in $PYVE_PARAM_ANSWERS; do
        case "$tok" in "$key="*) printf '%s' "${tok#*=}"; return 0 ;; esac
    done
    return 0
}

# ────────────────────────────────────────────────────────────────────
# Resolvers — applicability / choices / default may be '@fn' (computed from
# prior answers). This indirection is how dependent fields (Backend's choices
# are a function of Language; the default flips on an environment.yml heuristic)
# stay *data* rather than special-cased branches.
# ────────────────────────────────────────────────────────────────────

# Return 0 if the node applies given the current answers, non-zero to prune it.
pg_applicable() {
    local name owner appl choices default flag env req label
    IFS='|' read -r name owner appl choices default flag env req label <<<"$1"
    case "$appl" in
        '*')   return 0 ;;
        '@'*)  "${appl#@}" ;;
        *=*)   [[ "$(pg_answer_get "${appl%%=*}")" == "${appl#*=}" ]] ;;
        *)     return 0 ;;
    esac
}

# Echo the node's resolved choice set ('a,b,c' or '-').
pg_resolve_choices() {
    local name owner appl choices default flag env req label
    IFS='|' read -r name owner appl choices default flag env req label <<<"$1"
    case "$choices" in '@'*) "${choices#@}" ;; *) printf '%s' "$choices" ;; esac
}

# Echo the node's resolved default ('' when '-').
pg_resolve_default() {
    local name owner appl choices default flag env req label
    IFS='|' read -r name owner appl choices default flag env req label <<<"$1"
    case "$default" in
        '@'*) "${default#@}" ;;
        '-')  printf '' ;;
        *)    printf '%s' "$default" ;;
    esac
}

# ────────────────────────────────────────────────────────────────────
# The walk — one traversal, a pluggable value-source. The source is called as
#   <source_fn> <name> <flag> <env> <choices> <default>
# and must echo the *explicit* selection or empty. The engine then applies the
# default, validates, and enforces `required` — uniformly for every source.
# ────────────────────────────────────────────────────────────────────
pg_walk() {
    local source_fn="$1" row
    for row in "${PYVE_PARAM_NODES[@]+"${PYVE_PARAM_NODES[@]}"}"; do
        [[ -n "$row" ]] || continue
        pg_applicable "$row" || continue          # prune
        local name owner appl choices default flag env req label value
        # shellcheck disable=SC2034  # owner/appl/label split for canonical column order; unused in this sink
        IFS='|' read -r name owner appl choices default flag env req label <<<"$row"
        choices="$(pg_resolve_choices "$row")"
        default="$(pg_resolve_default "$row")"
        value="$("$source_fn" "$name" "$flag" "$env" "$choices" "$default")"
        [[ -z "$value" ]] && value="$default"
        if [[ "$req" == "yes" && -z "$value" ]]; then
            printf 'pyve init: required parameter "%s" (%s) was not provided\n' "$name" "$flag" >&2
            return 1
        fi
        if [[ "$choices" != "-" && -n "$value" ]]; then
            case ",$choices," in
                *",$value,"*) : ;;
                *) printf 'pyve init: %s=%s is not one of {%s}\n' "$name" "$value" "$choices" >&2
                   return 1 ;;
            esac
        fi
        pg_answer_set "$name" "$value"
    done
}

# ── value source: non-interactive flags + env vars ──────────────────
# Resolution precedence: explicit `--flag value` > env var > (engine: default).
# Boolean / `--no-x` negation flags are a node *kind* deferred to P.g (spike
# risk #2); this generic source handles valued flags and env vars.
PYVE_PARAM_ARGV=()
pg_argv_set() { PYVE_PARAM_ARGV=("$@"); }

pg_source_flags() {
    local flag="$2" env="$3" i n a nx
    n=${#PYVE_PARAM_ARGV[@]}
    i=0
    while [[ $i -lt $n ]]; do
        a="${PYVE_PARAM_ARGV[$i]:-}"
        if [[ "$a" == "$flag" ]]; then
            nx="${PYVE_PARAM_ARGV[$((i+1))]:-}"
            if [[ -z "$nx" || "$nx" == --* ]]; then printf 'true'; else printf '%s' "$nx"; fi
            return 0
        elif [[ "$a" == "$flag="* ]]; then
            printf '%s' "${a#*=}"; return 0
        fi
        i=$((i+1))
    done
    if [[ "$env" != "-" && -n "${!env:-}" ]]; then printf '%s' "${!env}"; return 0; fi
    printf ''   # empty → engine applies the default
}

# Convenience: resolve the whole graph from argv (and env), non-interactively.
pg_resolve_with_flags() {
    pg_answer_reset
    pg_argv_set "$@"
    pg_walk pg_source_flags
}

# ── value source: interactive prompts (TTY) ─────────────────────────
# A queued-input mechanism keeps the wizard testable without a TTY: each
# applicable node pops one entry off PYVE_PARAM_PROMPT_QUEUE (empty/absent →
# accept the default). The real prompt rendering (ui_select etc.) is wired in
# P.g; this engine only needs the value, so it stays UI-agnostic here.
PYVE_PARAM_PROMPT_QUEUE=()
_pg_prompt_idx=0

pg_source_prompt() {
    local reply=""
    if [[ $_pg_prompt_idx -lt ${#PYVE_PARAM_PROMPT_QUEUE[@]} ]]; then
        reply="${PYVE_PARAM_PROMPT_QUEUE[$_pg_prompt_idx]:-}"
        _pg_prompt_idx=$((_pg_prompt_idx+1))
    fi
    printf '%s' "$reply"   # empty → engine applies the default
}

# Convenience: resolve the whole graph by "prompting", consuming the args as the
# queued replies in node order.
pg_resolve_with_prompts() {
    pg_answer_reset
    PYVE_PARAM_PROMPT_QUEUE=("$@")
    _pg_prompt_idx=0
    pg_walk pg_source_prompt
}

# ────────────────────────────────────────────────────────────────────
# Framework-owned top nodes + the plugin contribution seam.
#
# The framework owns the cross-cutting differentiators (Language, project-guide,
# direnv); each language plugin contributes its own subtree (Python:
# backend → version-manager → version; Node: provider → runtime-manager) by
# registering a contributor. P.h wires plugin contributors onto the plugin
# contract; here the seam is the plain `pg_register_contributor` list, called in
# registration order *after* the framework nodes so Language prunes everything
# below it.
# ────────────────────────────────────────────────────────────────────
pg_register_framework_nodes() {
    pg_add_node "language|framework|*|@pg_language_choices|python|--language|PYVE_LANGUAGE|yes|Project language"
    pg_add_node "project-guide|framework|*|yes,no|yes|--project-guide|PYVE_PROJECT_GUIDE|no|Install project-guide"
    pg_add_node "direnv|framework|*|yes,no|yes|--direnv|PYVE_DIRENV|no|direnv (.envrc) activation"
}

# Default language choice set. A real build narrows this to detected stacks; the
# engine only needs the closed vocabulary.
pg_language_choices() { printf 'python,node,shell,multiple'; }

# Register a contributor: a function that calls pg_add_node for its subtree.
pg_register_contributor() {
    PYVE_PARAM_CONTRIBUTORS+=("$1")
}

# Build the full graph: framework top nodes first, then every contributed
# subtree in registration order. Clears nodes + answers but PRESERVES the
# registered contributors, so callers register contributors then build (and may
# rebuild) without re-registering. Use pg_reset to drop contributors too.
pg_build_graph() {
    PYVE_PARAM_NODES=()
    PYVE_PARAM_ANSWERS=" "
    pg_register_framework_nodes
    local c
    for c in "${PYVE_PARAM_CONTRIBUTORS[@]+"${PYVE_PARAM_CONTRIBUTORS[@]}"}"; do
        "$c"
    done
}

# The versioned-defaults stamp (drift detection in P.k keys off this).
pg_defaults_version() { printf '%s\n' "$PYVE_PARAM_DEFAULTS_VERSION"; }
