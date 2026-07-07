#!/usr/bin/env bash
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Map changed files to the unit-test files that exercise them, for
# fast inner-loop iteration (`make test-impact`).
#
# Changed files come from explicit args, or (no args) from
# `git diff --name-only HEAD` plus untracked files. Selection is the
# union of three channels:
#   1. a changed tests/unit/*.bats file selects itself;
#   2. a changed lib/ or scripts/ source file selects every test file
#      that references its lib-relative path suffix (tests `source`
#      what they exercise) or any function name it defines;
#   3. a small fixed smoke set always rides along.
#
# This is a HEURISTIC for the inner loop — bash has no import graph
# and pyve's function table is global, so selection is never proof of
# safety. The full suite runs at story gates; CI is the ultimate
# arbiter (see docs/specs/testing-spec.md).
#
# `--list` prints the selection (one file per line); the default mode
# runs it via scripts/run-unit-tests.sh (parallel-aware).
set -euo pipefail

cd "$(dirname "$0")/.."

SMOKE=(tests/unit/test_cli_dispatch.bats tests/unit/test_tags_guard.bats)

list_only=0
declare -a changed=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --list) list_only=1; shift ;;
        *) changed+=("$1"); shift ;;
    esac
done

# No explicit files → ask git: tracked changes vs HEAD, plus untracked.
if [[ "${#changed[@]}" -eq 0 ]]; then
    while IFS= read -r f; do
        [[ -n "$f" ]] && changed+=("$f")
    done < <(git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
fi

declare -a selected=("${SMOKE[@]}")

for f in "${changed[@]+"${changed[@]}"}"; do
    case "$f" in
        tests/unit/*.bats)
            [[ -f "$f" ]] && selected+=("$f")
            ;;
        lib/*.sh|lib/*.py|scripts/*.sh|pyve.sh)
            # Channel: path-suffix reference (source lines in tests).
            suffix="${f#lib/}"
            suffix="${suffix#scripts/}"
            while IFS= read -r hit; do
                [[ -n "$hit" ]] && selected+=("$hit")
            done < <(grep -l -F "$suffix" tests/unit/*.bats 2>/dev/null || true)
            # Channel: function names defined in the changed file.
            if [[ -f "$f" ]]; then
                if [[ "$f" == *.py ]]; then
                    names="$(grep -oE '^def [a-zA-Z_][a-zA-Z0-9_]*' "$f" 2>/dev/null | sed 's/^def //' || true)"
                else
                    names="$(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$f" 2>/dev/null | sed 's/()$//' || true)"
                fi
                if [[ -n "$names" ]]; then
                    alternation="$(printf '%s\n' "$names" | paste -sd'|' -)"
                    while IFS= read -r hit; do
                        [[ -n "$hit" ]] && selected+=("$hit")
                    done < <(grep -l -E "$alternation" tests/unit/*.bats 2>/dev/null || true)
                fi
            fi
            ;;
        *)
            # Docs, Makefile, specs, … — nothing beyond the smoke set.
            ;;
    esac
done

selection="$(printf '%s\n' "${selected[@]}" | sort -u)"

if [[ "$list_only" == "1" ]]; then
    printf '%s\n' "$selection"
    exit 0
fi

count="$(printf '%s\n' "$selection" | grep -c . || true)"
echo "test-impact: running $count selected test file(s) — heuristic only; run 'make test-unit' at the gate." >&2
# shellcheck disable=SC2086 # selection is a newline list of repo-relative paths without spaces
exec ./scripts/run-unit-tests.sh $selection
