# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/envrc_safety.sh — PC-1 plugin input safety
#
# Pure validators that guard the boundary between plugin-emitted text
# and pyve's composed `.envrc` / `.gitignore` files. A malicious or
# buggy plugin must not be able to smuggle arbitrary shell into files
# that direnv or pyve will later source/parse.
#
# Two validators, two allow-lists:
#
#   validate_envrc_snippet <text>
#       Accept lines: blank, comment, `PATH_add "<value>"`,
#       `export VAR="<value>"`. Value must be double-quoted. Parameter
#       expansions (`$VAR`, `${VAR}`) inside the value are safe.
#       Reject: backticks, `$(...)`, unquoted values, any other shape.
#
#   validate_gitignore_snippet <text>
#       Accept lines: blank, comment, plain glob patterns.
#       Reject: any `$` (parameter expansion or command sub), backticks.
#
# Both validators are LINE-ORIENTED: one bad line invalidates the
# whole snippet, with the offending line printed to stderr.
#
# Scope: validators only. The activation and gitignore composers
# integrate these.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Private: validate one `.envrc` line. Already-stripped trailing
# newline; may have leading whitespace.
_envrc_validate_line() {
    local line="$1"
    local trimmed

    # Strip leading whitespace for shape matching.
    trimmed="${line#"${line%%[![:space:]]*}"}"

    # Blank line (after whitespace strip).
    [[ -z "$trimmed" ]] && return 0

    # Comment line: anything after `#` is opaque. Smuggling patterns
    # in comments are textually inert.
    [[ "$trimmed" == "#"* ]] && return 0

    # Smuggling probes: backticks and `$(...)` are command substitution
    # outside of comments. Reject anywhere on the line.
    if [[ "$trimmed" == *'`'* ]]; then
        return 1
    fi
    if [[ "$trimmed" == *'$('* ]]; then
        return 1
    fi

    # Allow shape 1: PATH_add "<quoted-value>"
    # Value: matches `"..."` (anything between quotes, no embedded `"`).
    if [[ "$trimmed" =~ ^PATH_add[[:space:]]+\"[^\"]*\"[[:space:]]*$ ]]; then
        return 0
    fi

    # Allow shape 2: export VAR="<quoted-value>"
    # VAR: shell identifier — [A-Za-z_][A-Za-z_0-9]*
    if [[ "$trimmed" =~ ^export[[:space:]]+[A-Za-z_][A-Za-z_0-9]*=\"[^\"]*\"[[:space:]]*$ ]]; then
        return 0
    fi

    return 1
}

validate_envrc_snippet() {
    local text="$1"
    local line
    local IFS=$'\n'
    # `while read` over a here-string iterates each newline-separated
    # chunk. An empty input emits zero iterations → silent success.
    while IFS= read -r line || [[ -n "$line" ]]; do
        if ! _envrc_validate_line "$line"; then
            printf "envrc_safety: rejected line: %s\n" "$line" >&2
            return 1
        fi
    done <<< "$text"
    return 0
}

# Private: validate one `.gitignore` line.
_gitignore_validate_line() {
    local line="$1"
    local trimmed

    # Strip leading whitespace.
    trimmed="${line#"${line%%[![:space:]]*}"}"

    [[ -z "$trimmed" ]] && return 0
    [[ "$trimmed" == "#"* ]] && return 0

    # No shell interpolation: reject any `$` (covers both `$VAR` and
    # `$(...)`) plus backticks. `.gitignore` patterns never need a
    # literal `$` — defensive over-rejection is the right tradeoff.
    if [[ "$trimmed" == *'$'* ]]; then
        return 1
    fi
    if [[ "$trimmed" == *'`'* ]]; then
        return 1
    fi

    return 0
}

validate_gitignore_snippet() {
    local text="$1"
    local line
    local IFS=$'\n'
    while IFS= read -r line || [[ -n "$line" ]]; do
        if ! _gitignore_validate_line "$line"; then
            printf "envrc_safety: rejected gitignore line: %s\n" "$line" >&2
            return 1
        fi
    done <<< "$text"
    return 0
}
