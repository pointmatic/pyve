#!/usr/bin/env bash
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# ============================================================================
# THROWAWAY SPIKE — Story P.e (architectural spike).
#
# Proves the keystone parameter decision-graph can drive the wizard, the
# flag/CLI parser, `--help`, and defaults from ONE node definition, plus a
# plugin-contributed subtree — in Bash that runs on macOS system bash 3.2.
#
# This file is EVIDENCE, not production code. It is never sourced by pyve.sh
# and must be deleted (or left quarantined in scripts/) once P.f/P.g/P.h land.
# The decision it proves is written up in docs/specs/spike-p-e-decision-graph.md.
#
# Run:
#   bash scripts/spike_decision_graph.sh demo       # all proofs, non-interactive
#   bash scripts/spike_decision_graph.sh help       # generated --help
#   bash scripts/spike_decision_graph.sh flags --backend micromamba --no-project-guide
#   bash scripts/spike_decision_graph.sh wizard     # scripted "interactive" walk
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# Representation decision (proven below): the node table is an INDEXED array of
# pipe-delimited rows. Indexed arrays are bash-3.2-safe; associative arrays
# (`declare -A`) are NOT, and pyve's own test suite forbids them
# (tests/unit/test_bash32_compat.bats). So "associative-array tables" — one of
# the two candidates the spike was told to weigh — is ruled out by construction.
#
# Row schema (9 fields). The story's schema is 8 fields
# {name,applicability,choices,default,flag,env,owner,required}; the spike finds
# a 9th — `label` — is REQUIRED, because you cannot generate a wizard prompt or
# a --help line without human text. That is a spike conclusion, not an aside.
#
#   name | owner | applicability | choices | default | flag | env | required | label
#
#   applicability : '*'            -> always
#                   'key=val'      -> only when a prior answer matches
#                   '@fn'          -> predicate function (computed)
#   choices       : 'a,b,c'        -> literal set
#                   '@fn'          -> computed from prior answers
#                   '-'            -> free value (no enumerated set; e.g. a version)
#   default       : literal | '@fn' | '-'
#   env           : env var name | '-'
# ----------------------------------------------------------------------------

NODES=()

graph_add_node() { NODES+=("$1"); }   # one pipe-delimited row per node

# ---- the accumulated answers, as a bash-3.2-safe membership string ----------
# Mirrors lib/commands/env.sh's dedup idiom: a space-bracketed string, scanned
# with glob membership, no associative array needed.
ANSWERS=" "

answer_set() { ANSWERS+="$1=$2 "; }
answer_get() {
    # answer_get <key> -> echoes value or empty
    local key="$1" tok
    for tok in $ANSWERS; do
        case "$tok" in
            "$key="*) printf '%s' "${tok#*=}"; return 0 ;;
        esac
    done
    return 0
}

# ============================================================================
# Field accessors (split a row without arrays-of-arrays).
# ============================================================================
_f() { # _f <row> <1-based index>
    local row="$1" idx="$2"
    printf '%s' "$row" | cut -d'|' -f"$idx"
}
node_name()  { _f "$1" 1; }
node_owner() { _f "$1" 2; }
node_appl()  { _f "$1" 3; }
node_choices(){ _f "$1" 4; }
node_default(){ _f "$1" 5; }
node_flag()  { _f "$1" 6; }
node_env()   { _f "$1" 7; }
node_req()   { _f "$1" 8; }
node_label() { _f "$1" 9; }

# ============================================================================
# Resolvers — applicability / choices / default may be '@fn' (computed).
# This is how "Backend's options are a function of Language" works without
# baking the dependency into the table: the table names a function; the
# function reads prior ANSWERS.
# ============================================================================
resolve_appl() { # resolve_appl <row> -> 0 if applicable
    local appl; appl="$(node_appl "$1")"
    case "$appl" in
        '*') return 0 ;;
        '@'*) "${appl#@}" ;;                       # predicate fn
        *=*) [[ "$(answer_get "${appl%%=*}")" == "${appl#*=}" ]] ;;
        *) return 0 ;;
    esac
}
resolve_choices() { # echoes comma-list or '-'
    local c; c="$(node_choices "$1")"
    case "$c" in '@'*) "${c#@}" ;; *) printf '%s' "$c" ;; esac
}
resolve_default() {
    local d; d="$(node_default "$1")"
    case "$d" in '@'*) "${d#@}" ;; *) printf '%s' "$d" ;; esac
}

# ============================================================================
# FRAMEWORK-OWNED top nodes (Language, project-guide). These prune everything
# below them; they are pyve's, not a plugin's.
# ============================================================================
register_framework_nodes() {
    graph_add_node "language|framework|*|@language_choices|python|--language|PYVE_LANGUAGE|yes|Project language"
    graph_add_node "project-guide|framework|*|yes,no|yes|--project-guide|PYVE_PROJECT_GUIDE|no|Install project-guide?"
}
language_choices() { printf 'python,node,shell,multiple'; }

# ============================================================================
# PLUGIN-CONTRIBUTED SUBTREE (proof of bullet 3). The Python plugin contributes
# `backend -> version-manager -> version`, each gated on language=python, with
# computed choices/defaults. The framework code below NEVER mentions venv,
# asdf, or 3.14 — that knowledge lives entirely in the plugin's contribution.
# ============================================================================
register_python_subtree() {
    graph_add_node "backend|python|language=python|@py_backend_choices|@py_backend_default|--backend|PYVE_BACKEND|yes|Backend"
    graph_add_node "version-manager|python|@py_needs_vmgr|asdf,pyenv|asdf|--version-manager|PYVE_VMGR|no|Python version manager"
    graph_add_node "python-version|python|language=python|-|@py_version_default|--python-version|PYVE_PYTHON_VERSION|no|Python version"
}
py_backend_choices() { printf 'venv,micromamba'; }
py_backend_default() {
    # computed: an environment.yml in cwd flips the default to micromamba —
    # the real filesystem heuristic, now expressed as graph data.
    if [[ -f environment.yml ]]; then printf 'micromamba'; else printf 'venv'; fi
}
py_needs_vmgr() {
    # version-manager node only applies to a venv backend (micromamba pins
    # python via environment.yml instead). Pruning in action.
    [[ "$(answer_get language)" == "python" && "$(answer_get backend)" == "venv" ]]
}
py_version_default() { printf '3.14.6'; }

# ============================================================================
# A SECOND plugin subtree, to prove pruning across stacks (Node). With
# language=python this whole subtree is pruned; with language=node it activates.
# ============================================================================
register_node_subtree() {
    graph_add_node "provider|node|language=node|pnpm,npm,yarn|pnpm|--provider|PYVE_NODE_PROVIDER|yes|Node package manager"
}

build_graph() {
    NODES=()
    register_framework_nodes
    register_python_subtree     # plugin seam: framework calls a registration hook
    register_node_subtree
}

# ============================================================================
# THE WALK ENGINE — one traversal, four different sinks. Bullet 1 + 2.
#   mode=flags    : resolve from argv flags / env / default (non-interactive/CI)
#   mode=wizard   : prompt the user, defaulting; prune the same way
#   mode=help     : emit a --help line per applicable-or-flagged node
#   mode=manifest : emit the explicit pyve.toml lines (bonus: 5th sink)
# Prefix every public surface so the SAME table feeds all of them.
# ============================================================================

# argv flag lookup for non-interactive mode (set by `flags` entrypoint).
ARGV=()
flag_value() { # flag_value <--flag> -> echoes value (or 'true' for boolean) or empty
    local want="$1" i n; n=${#ARGV[@]}
    i=0
    while [[ $i -lt $n ]]; do
        local a="${ARGV[$i]:-}"
        if [[ "$a" == "$want" ]]; then
            local nx="${ARGV[$((i+1))]:-}"
            if [[ -z "$nx" || "$nx" == --* ]]; then printf 'true'; else printf '%s' "$nx"; fi
            return 0
        fi
        # boolean negation form: --no-project-guide answers project-guide=no
        i=$((i+1))
    done
    return 0
}

# scripted "interactive" input so the wizard demo runs without a TTY.
WIZARD_INPUT=()
_wiz_i=0
prompt_user() { # prompt_user <label> <choices> <default> -> echoes chosen value
    local label="$1" choices="$2" def="$3" reply
    if [[ $_wiz_i -lt ${#WIZARD_INPUT[@]} ]]; then
        reply="${WIZARD_INPUT[$_wiz_i]:-}"; _wiz_i=$((_wiz_i+1))
    else
        reply=""   # accept default
    fi
    if [[ -z "$reply" ]]; then reply="$def"; fi
    if [[ "$choices" == "-" ]]; then
        printf '   ? %-26s [%s] -> %s\n' "$label" "$def" "$reply" >&2
    else
        printf '   ? %-26s {%s} [%s] -> %s\n' "$label" "$choices" "$def" "$reply" >&2
    fi
    printf '%s' "$reply"
}

walk() { # walk <flags|wizard|help|manifest>
    local mode="$1" row
    ANSWERS=" "
    for row in "${NODES[@]:-}"; do
        [[ -n "$row" ]] || continue
        local name; name="$(node_name "$row")"
        # SPIKE FINDING: help is STATIC — it has no prior answers, so it must
        # enumerate every node (annotated with its gating condition), NOT run
        # the answer-pruning walk the wizard/flags sinks use. Help therefore
        # skips the applicability gate; every other sink honors it.
        if [[ "$mode" != "help" ]] && ! resolve_appl "$row"; then
            [[ "$mode" == "manifest" ]] || \
                printf '   - prune %-16s (n/a: %s)\n' "$name" "$(node_appl "$row")" >&2
            continue
        fi
        local choices default flag env req label value cond
        choices="$(resolve_choices "$row")"
        default="$(resolve_default "$row")"
        flag="$(node_flag "$row")"; env="$(node_env "$row")"
        req="$(node_req "$row")"; label="$(node_label "$row")"

        case "$mode" in
            help)
                cond="$(node_appl "$row")"
                local when=""; [[ "$cond" != "*" ]] && when="  [when $cond]"
                if [[ "$choices" == "-" ]]; then
                    printf '  %-24s %s (default: %s)%s\n' "$flag <value>" "$label" "$default" "$when"
                else
                    printf '  %-24s %s {%s} (default: %s)%s\n' "$flag <choice>" "$label" "$choices" "$default" "$when"
                fi
                continue ;;
            flags)
                # precedence: explicit flag -> negation flag -> env var -> default
                value="$(flag_value "$flag")"
                if [[ -z "$value" ]]; then
                    local neg="--no-${name}"
                    [[ -n "$(flag_value "$neg")" ]] && value="no"
                fi
                if [[ -z "$value" && "$env" != "-" ]]; then value="${!env:-}"; fi
                if [[ -z "$value" ]]; then value="$default"; fi
                if [[ "$req" == "yes" && -z "$value" ]]; then
                    printf 'ERROR: required parameter %s (%s) not resolved\n' "$name" "$flag" >&2
                    return 1
                fi
                # validate against the choice set when enumerated
                if [[ "$choices" != "-" && -n "$value" ]]; then
                    case ",$choices," in *",$value,"*) : ;; *)
                        printf 'ERROR: %s=%s not in {%s}\n' "$name" "$value" "$choices" >&2
                        return 1 ;;
                    esac
                fi
                answer_set "$name" "$value"
                printf '   = %-16s %s\n' "$name" "$value" >&2 ;;
            wizard)
                value="$(prompt_user "$label" "$choices" "$default")"
                answer_set "$name" "$value" ;;
            manifest)
                answer_set "$name" "$default" ;;   # explicit-by-construction
        esac
    done
}

# ============================================================================
# DEMOS
# ============================================================================
demo_flags() {
    echo "### SINK 1+2 — non-interactive flag resolution (CI surface)"
    echo "argv: ${ARGV[*]:-(none)}"
    walk flags
    echo "resolved pyve.toml intent: ${ANSWERS# }"
    echo
}
demo_help() {
    echo "### SINK 3 — generated --help (same table)"
    echo "Options:"
    walk help
    echo
}
demo_wizard() {
    echo "### SINK 4 — wizard walk (prompts + pruning, scripted input)"
    walk wizard
    echo "   authored intent: ${ANSWERS# }"
    echo
}
demo_manifest() {
    echo "### SINK 5 (bonus) — explicit pyve.toml from the SAME defaults"
    walk manifest
    echo "[project]"
    echo "  language = \"$(answer_get language)\""
    echo "[env.root]"
    echo "  backend = \"$(answer_get backend)\""
    [[ -n "$(answer_get python-version)" ]] && echo "  python  = \"$(answer_get python-version)\""
    echo
}

main() {
    build_graph
    local cmd="${1:-demo}"; shift || true
    case "$cmd" in
        help)    demo_help ;;
        flags)   ARGV=("$@"); demo_flags ;;
        wizard)  WIZARD_INPUT=("$@"); demo_wizard ;;
        demo)
            echo "============================================================"
            echo " P.e spike — one decision-graph, many sinks (bash $BASH_VERSION)"
            echo "============================================================"
            echo
            demo_help
            echo "--- Python project, defaults (venv heuristic, no env.yml) ---"
            ARGV=(); demo_flags
            echo "--- Python project, --backend micromamba --no-project-guide ---"
            ARGV=(--backend micromamba --no-project-guide); demo_flags
            echo "--- Polyglot pruning: --language node prunes the Python subtree ---"
            ARGV=(--language node); demo_flags
            echo "--- Same graph as a wizard (accept all defaults) ---"
            WIZARD_INPUT=(); demo_wizard
            echo "--- Explicit manifest emission ---"
            demo_manifest
            ;;
        *) echo "usage: $0 {demo|help|flags ...|wizard ...}" >&2; exit 2 ;;
    esac
}
main "$@"
