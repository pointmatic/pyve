#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story J.e: bash 3.2 compatibility invariant tests.
#
# macOS ships /bin/bash at version 3.2.57. Every pyve release must source
# and execute cleanly there. Phase H's H.e.7a (declare -A) and H.e.9h
# (mapfile) regressions each landed to be caught by CI — a preemptive
# grep-invariant catches the next slip before commit.
#
# Each test below uses `grep -rnE` across the in-scope shell sources
# (pyve.sh, lib/*.sh, lib/completion/pyve.bash) and fails on any match
# that isn't in a pure-comment line. Failure messages name the bash 3.2-
# safe alternative so the fix is obvious.
#
# Scope note: lib/completion/_pyve is a zsh completion script (opens with
# `#compdef pyve`) where `typeset -A` is idiomatic zsh. Excluded from
# every test here.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    SOURCES=("$PYVE_ROOT/pyve.sh"
             "$PYVE_ROOT/lib"/*.sh
             "$PYVE_ROOT/lib/completion/pyve.bash")
}

# Run grep across in-scope sources, then drop pure-comment lines
# (content after `FILE:LINE:` begins with optional whitespace + `#`).
# Empty stdout means no policy-violating hit. Non-empty means failure;
# the caller asserts on emptiness and surfaces the matches.
_grep_non_comment() {
    local pattern="$1"
    grep -rnE "$pattern" "${SOURCES[@]}" 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true
}

_fail_with_matches() {
    local alternative="$1"; shift
    local matches="$1"
    echo "Forbidden bash-4+ construct found. Use ${alternative} (bash 3.2-safe)." >&2
    echo "Matches:" >&2
    printf '%s\n' "$matches" >&2
}

# ────────────────────────────────────────────────────────────────────
# Associative arrays (bash 4.0+)
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no 'declare -A' (use flat colon-delimited string)" {
    local m; m=$(_grep_non_comment '\bdeclare[[:space:]]+-A\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "a flat colon-delimited string (see pre-J.d deprecation_warn pattern for an example)" "$m"
        return 1
    fi
}

@test "bash 3.2: no 'typeset -A' (use flat colon-delimited string)" {
    local m; m=$(_grep_non_comment '\btypeset[[:space:]]+-A\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "a flat colon-delimited string" "$m"
        return 1
    fi
}

@test "bash 3.2: no 'local -A' (use flat colon-delimited string)" {
    local m; m=$(_grep_non_comment '\blocal[[:space:]]+-A\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "a flat colon-delimited string" "$m"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# mapfile / readarray (bash 4.0+)
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no 'mapfile' (use 'while IFS= read -r line; do … done < file')" {
    local m; m=$(_grep_non_comment '\bmapfile\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "'while IFS= read -r line; do … done < file'" "$m"
        return 1
    fi
}

@test "bash 3.2: no 'readarray' (same alternative as mapfile)" {
    local m; m=$(_grep_non_comment '\breadarray\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "'while IFS= read -r line; do … done < file'" "$m"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# Case-modification parameter expansions (bash 4.0+)
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no case-mod expansions \${var^^} / \${var,,} / \${var^} / \${var,}" {
    # Matches \${name[^,]+?} with at least one ^ or , after the name.
    # The regex captures both single-char (first-letter) and double-char
    # (all-chars) forms in one shot.
    local m; m=$(_grep_non_comment '\$\{[A-Za-z_][A-Za-z_0-9]*[\^,]')
    if [[ -n "$m" ]]; then
        _fail_with_matches "'tr [:lower:] [:upper:]' (or the reverse) via a subshell" "$m"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# @-transform parameter expansions \${var@Q} etc. (bash 4.4+)
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no '\${var@[UuLlQqEePpAaKk]}' transform operators" {
    local m; m=$(_grep_non_comment '\$\{[A-Za-z_][A-Za-z_0-9]*@[UuLlQqEePpAaKk]\}')
    if [[ -n "$m" ]]; then
        _fail_with_matches "an explicit transform (e.g., printf %q for \${var@Q}; awk/sed for case)" "$m"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# Namerefs (bash 4.3+)
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no 'declare -n' namerefs" {
    local m; m=$(_grep_non_comment '\bdeclare[[:space:]]+-n\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "passing/returning via explicit global vars or by eval of a caller-supplied name" "$m"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# Named coprocs (bash 4.0+) — anonymous 'coproc { … }' IS bash 3.2-safe
# (the bare 'coproc' builtin exists in 3.2); only the named form
# 'coproc NAME { … }' requires bash 4+. Regex matches 'coproc' followed
# by an identifier (not a '{' or newline).
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no named 'coproc NAME' (anonymous 'coproc' is fine)" {
    local m; m=$(_grep_non_comment '\bcoproc[[:space:]]+[A-Za-z_]')
    if [[ -n "$m" ]]; then
        _fail_with_matches "explicit FIFO / named-pipe plumbing, or the anonymous 'coproc { … }' form" "$m"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────
# globstar (bash 4.0+)
# ────────────────────────────────────────────────────────────────────

@test "bash 3.2: no 'shopt -s globstar' (use 'find' instead of '**/' glob)" {
    local m; m=$(_grep_non_comment '\bshopt[[:space:]]+-s[[:space:]]+globstar\b')
    if [[ -n "$m" ]]; then
        _fail_with_matches "'find … -type f -name …' instead of '**/' recursion" "$m"
        return 1
    fi
}
