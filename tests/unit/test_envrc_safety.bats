#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# PC-1 plugin input safety validators.
#
# Two pure validators that guard the boundary between plugin-emitted
# text and pyve's composed `.envrc` / `.gitignore` files. A malicious
# or buggy plugin must not be able to smuggle arbitrary shell into
# files that direnv or pyve will later source/parse.
#
# Scope of N.m: validators + tests only. Composer integration (calling
# these from the activation/gitignore composers) is deferred to N.q
# (activation) and N.r (gitignore).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# validate_envrc_snippet — direnv-stdlib allow-list
# ════════════════════════════════════════════════════════════════════
#
# Allow:
#   - blank lines (incl. lines with only whitespace)
#   - comment lines (leading whitespace + `#` + anything)
#   - `PATH_add "<value>"` where value is double-quoted with no $( or `
#   - `export VAR="<value>"` where VAR is a shell-identifier and value
#     is double-quoted with no $( or `
#   - parameter expansions (`$VAR`, `${VAR}`) INSIDE the double-quoted
#     value (safe inside double quotes)
#
# Reject:
#   - backticks anywhere
#   - `$(...)` anywhere
#   - unquoted values (`export FOO=bar`, `PATH_add foo`)
#   - non-allow-listed direnv directives (`dotenv`, `source`, ...)
#   - shell control flow (`if`, `for`, `while`, `function`)
#   - anything else
# ────────────────────────────────────────────────────────────────────

# ── Accept cases ──

@test "envrc: empty snippet is valid" {
    run validate_envrc_snippet ""
    [ "$status" -eq 0 ]
}

@test "envrc: blank line is valid" {
    run validate_envrc_snippet $'\n'
    [ "$status" -eq 0 ]
}

@test "envrc: comment line is valid" {
    run validate_envrc_snippet "# this is a comment"
    [ "$status" -eq 0 ]
}

@test "envrc: indented comment is valid" {
    run validate_envrc_snippet "    # indented comment"
    [ "$status" -eq 0 ]
}

@test "envrc: PATH_add with quoted relative path is valid" {
    run validate_envrc_snippet 'PATH_add ".venv/bin"'
    [ "$status" -eq 0 ]
}

@test "envrc: PATH_add with quoted path containing parameter expansion is valid" {
    run validate_envrc_snippet 'PATH_add "${PWD}/.venv/bin"'
    [ "$status" -eq 0 ]
}

@test "envrc: export with quoted literal value is valid" {
    run validate_envrc_snippet 'export PYVE_BACKEND="venv"'
    [ "$status" -eq 0 ]
}

@test "envrc: export with parameter expansion in quoted value is valid" {
    run validate_envrc_snippet 'export VIRTUAL_ENV="$PWD/.venv"'
    [ "$status" -eq 0 ]
}

@test "envrc: export with braced parameter expansion in quoted value is valid" {
    run validate_envrc_snippet 'export VIRTUAL_ENV="${PWD}/.venv"'
    [ "$status" -eq 0 ]
}

@test "envrc: multi-line mix of allowed shapes is valid" {
    local snippet=$'# header comment\n\nPATH_add ".venv/bin"\nexport VIRTUAL_ENV="$PWD/.venv"\nexport PYVE_BACKEND="venv"\n'
    run validate_envrc_snippet "$snippet"
    [ "$status" -eq 0 ]
}

# ── Reject: command substitution ──

@test "envrc: rejects command substitution in PATH_add" {
    run validate_envrc_snippet 'PATH_add "$(pwd)/bin"'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects backticks in PATH_add" {
    run validate_envrc_snippet 'PATH_add "`pwd`/bin"'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects command substitution in export value" {
    run validate_envrc_snippet 'export FOO="$(whoami)"'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects backticks in export value" {
    run validate_envrc_snippet 'export FOO="`whoami`"'
    [ "$status" -ne 0 ]
}

# ── Reject: unquoted values ──

@test "envrc: rejects unquoted export value" {
    run validate_envrc_snippet 'export FOO=bar'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects unquoted parameter in export" {
    run validate_envrc_snippet 'export FOO=$PWD'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects unquoted PATH_add argument" {
    run validate_envrc_snippet 'PATH_add /usr/local/bin'
    [ "$status" -ne 0 ]
}

# ── Reject: non-allow-listed directives ──

@test "envrc: rejects 'dotenv' directive (not in allow-list)" {
    run validate_envrc_snippet 'dotenv'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects 'source other.sh'" {
    run validate_envrc_snippet 'source other.sh'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects shell control flow ('if ...; then')" {
    local snippet=$'if [[ -f ".env" ]]; then\n    dotenv\nfi'
    run validate_envrc_snippet "$snippet"
    [ "$status" -ne 0 ]
}

@test "envrc: rejects 'rm -rf /' (canonical smuggling probe)" {
    run validate_envrc_snippet 'rm -rf /'
    [ "$status" -ne 0 ]
}

@test "envrc: rejects export with non-identifier var name" {
    run validate_envrc_snippet 'export 1FOO="bar"'
    [ "$status" -ne 0 ]
}

# ── Reject: smuggling INSIDE a comment is fine; smuggling INSIDE an
# otherwise-valid quoted value is what we're guarding against. Comment
# is a textual no-op.
@test "envrc: backticks inside a comment are valid (no shell interp)" {
    run validate_envrc_snippet '# this `would be a smuggling pattern` outside a comment'
    [ "$status" -eq 0 ]
}

# ── Reject: multi-line with one bad line invalidates the whole snippet ──

@test "envrc: mixed valid + one rejected line rejects the snippet" {
    local snippet=$'# valid\nexport FOO="ok"\nexport BAD="$(whoami)"\n'
    run validate_envrc_snippet "$snippet"
    [ "$status" -ne 0 ]
}

# ════════════════════════════════════════════════════════════════════
# validate_gitignore_snippet — simple-pattern allow-list
# ════════════════════════════════════════════════════════════════════
#
# Allow:
#   - blank lines
#   - comment lines (`# ...`)
#   - plain glob patterns (alphanumerics, `*`, `?`, `[`, `]`, `/`,
#     `.`, `-`, `_`, `!` negation, `\` glob-escape)
#
# Reject (no shell interpolation):
#   - backticks
#   - `$(...)`
#   - `$VAR` / `${VAR}`
# ────────────────────────────────────────────────────────────────────

# ── Accept cases ──

@test "gitignore: empty snippet is valid" {
    run validate_gitignore_snippet ""
    [ "$status" -eq 0 ]
}

@test "gitignore: blank line is valid" {
    run validate_gitignore_snippet $'\n'
    [ "$status" -eq 0 ]
}

@test "gitignore: comment line is valid" {
    run validate_gitignore_snippet "# Python build artifacts"
    [ "$status" -eq 0 ]
}

@test "gitignore: plain glob pattern is valid" {
    run validate_gitignore_snippet "*.pyc"
    [ "$status" -eq 0 ]
}

@test "gitignore: directory pattern is valid" {
    run validate_gitignore_snippet "__pycache__/"
    [ "$status" -eq 0 ]
}

@test "gitignore: nested path pattern is valid" {
    run validate_gitignore_snippet "dist/build/*.tar.gz"
    [ "$status" -eq 0 ]
}

@test "gitignore: bracket-class pattern is valid" {
    run validate_gitignore_snippet "*.[oa]"
    [ "$status" -eq 0 ]
}

@test "gitignore: negation pattern is valid" {
    run validate_gitignore_snippet "!keep_this.txt"
    [ "$status" -eq 0 ]
}

@test "gitignore: multi-line mix is valid" {
    local snippet=$'# Python\n__pycache__/\n*.pyc\n.venv/\n*.egg-info\n'
    run validate_gitignore_snippet "$snippet"
    [ "$status" -eq 0 ]
}

# ── Reject cases ──

@test "gitignore: rejects \$VAR" {
    run validate_gitignore_snippet '$VAR'
    [ "$status" -ne 0 ]
}

@test "gitignore: rejects \${VAR}" {
    run validate_gitignore_snippet '${VAR}'
    [ "$status" -ne 0 ]
}

@test "gitignore: rejects command substitution" {
    run validate_gitignore_snippet '$(rm -rf /)'
    [ "$status" -ne 0 ]
}

@test "gitignore: rejects backticks" {
    run validate_gitignore_snippet '`pwd`'
    [ "$status" -ne 0 ]
}

@test "gitignore: mixed valid + one rejected line rejects the snippet" {
    local snippet=$'*.pyc\n__pycache__/\n$BAD\n'
    run validate_gitignore_snippet "$snippet"
    [ "$status" -ne 0 ]
}
