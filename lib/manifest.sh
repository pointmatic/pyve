# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/manifest.sh — v3.0 canonical manifest reader (Story N.a)
#
# Reads pyve.toml (root-level v3 declarative manifest) via the Python
# tomllib helper lib/pyve_toml_helper.py and exposes a flat accessor
# surface. Foundation for everything in Subphase N-1; no CLI dispatcher
# wiring is added in this story.
#
# State populated by `manifest_load` (V3 wire format, parallel indexed
# arrays keyed by position in PYVE_ENV_NAMES):
#
#   PYVE_SCHEMA_VERSION         — "3.0"
#   PYVE_PROJECT_NAME           — [project].name (string)
#   PYVE_ENV_NAMES[]            — declared env names
#   PYVE_ENV_PURPOSE[]          — run | test | utility | temp | ""
#   PYVE_ENV_BACKEND[]          — plugin-registered backend name | ""
#   PYVE_ENV_PATH[]             — working/detection root (default ".")
#   PYVE_ENV_DEFAULT[]          — "0" / "1"
#   PYVE_ENV_LAZY[]             — "0" / "1"
#   PYVE_ENV_EXTRA[]            — pyproject extra name | ""
#   PYVE_ENV_MANIFEST[]         — conda/pip manifest path | ""
#   PYVE_ENV_APP_TYPE[]         — structured attr | ""
#   PYVE_ENV_REQUIREMENTS_Q[]   — shell-quoted requirements list per env
#   PYVE_ENV_FRAMEWORKS_Q[]     — shell-quoted frameworks list per env
#   PYVE_ENV_LANGUAGES_Q[]      — shell-quoted languages list per env
#
# This file is sourced explicitly by consumers (test files in N.a; later
# stories wire it into pyve.sh's library-loading block). It must not be
# executed directly — see the guard immediately below.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Path to the Python helper. Resolves relative to this file so the
# library is testable independent of pyve.sh's SCRIPT_DIR.
_PYVE_MANIFEST_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pyve_toml_helper.py"

# Read pyve.toml from <path> (default ./pyve.toml) and populate the V3
# array state. Missing file → empty config (zero envs, schema "3.0").
# Validation errors propagate via non-zero exit + stderr.
manifest_load() {
    local manifest="${1:-pyve.toml}"
    if [[ ! -f "$manifest" ]]; then
        PYVE_SCHEMA_VERSION="3.0"
        PYVE_PROJECT_NAME=""
        PYVE_ENV_NAMES=()
        PYVE_ENV_PURPOSE=()
        PYVE_ENV_BACKEND=()
        PYVE_ENV_PATH=()
        PYVE_ENV_DEFAULT=()
        PYVE_ENV_LAZY=()
        PYVE_ENV_EXTRA=()
        PYVE_ENV_MANIFEST=()
        PYVE_ENV_APP_TYPE=()
        PYVE_ENV_REQUIREMENTS_Q=()
        PYVE_ENV_FRAMEWORKS_Q=()
        PYVE_ENV_LANGUAGES_Q=()
        return 0
    fi
    local py="${PYVE_PYTHON:-python}"
    local kv
    kv="$("$py" "$_PYVE_MANIFEST_HELPER" "$manifest")" || return $?
    eval "$kv"
}

# Index lookup: print the 0-based position of <name> in PYVE_ENV_NAMES,
# or return 1 (no output) if absent. Bash-3.2-safe under `set -u`:
# returns 1 cleanly when PYVE_ENV_NAMES is unset (manifest_load not yet
# called). Private helper.
_manifest_name_to_index() {
    local target="$1" i
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 1
    for ((i=0; i<${#PYVE_ENV_NAMES[@]}; i++)); do
        if [[ "${PYVE_ENV_NAMES[$i]}" == "$target" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

# Print declared env names, one per line. Empty when no envs declared.
manifest_list_envs() {
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    local n
    for n in "${PYVE_ENV_NAMES[@]+"${PYVE_ENV_NAMES[@]}"}"; do
        printf '%s\n' "$n"
    done
}

# Predicate: 0 if <name> appears in PYVE_ENV_NAMES, 1 otherwise.
manifest_get_env() {
    _manifest_name_to_index "$1" >/dev/null
}

# Scalar field accessors. Print empty string if the field is unset;
# return 1 (no output) if the env name is unknown.
manifest_get_purpose() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_PURPOSE[$i]}"
}

manifest_get_backend() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_BACKEND[$i]}"
}

manifest_get_path() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_PATH[$i]}"
}

manifest_get_app_type() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_APP_TYPE[$i]}"
}

# Boolean predicates: 0 / 1.
manifest_is_default() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    [[ "${PYVE_ENV_DEFAULT[$i]}" == "1" ]]
}

manifest_is_lazy() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    [[ "${PYVE_ENV_LAZY[$i]}" == "1" ]]
}

# List-valued accessors: populate a caller-named array with the env's
# list contents.
# Usage: declare -a out; manifest_get_frameworks <name> out
manifest_get_frameworks() {
    local i out_var
    i="$(_manifest_name_to_index "$1")" || return 1
    out_var="$2"
    eval "$out_var=( ${PYVE_ENV_FRAMEWORKS_Q[$i]} )"
}

manifest_get_languages() {
    local i out_var
    i="$(_manifest_name_to_index "$1")" || return 1
    out_var="$2"
    eval "$out_var=( ${PYVE_ENV_LANGUAGES_Q[$i]} )"
}

manifest_get_requirements() {
    local i out_var
    i="$(_manifest_name_to_index "$1")" || return 1
    out_var="$2"
    eval "$out_var=( ${PYVE_ENV_REQUIREMENTS_Q[$i]} )"
}
