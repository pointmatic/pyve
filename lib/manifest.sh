# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/manifest.sh — v3.0 canonical manifest reader
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
#   PYVE_PROJECT_DEFAULTS_VERSION — [project].pyve_defaults_version (P.k drift
#                                 baseline; "" on pre-P.k manifests)
#   PYVE_ENV_NAMES[]            — declared env names
#   PYVE_ENV_PURPOSE[]          — run | test | utility | temp | ""
#   PYVE_ENV_BACKEND[]          — plugin-registered backend name | ""
#   PYVE_ENV_PATH[]             — working/detection root (default ".")
#   PYVE_ENV_EDITABLE[]         — `editable` setup directive (P.l.2) | ""
#   PYVE_ENV_DEFAULT[]          — "0" / "1"
#   PYVE_ENV_LAZY[]             — "0" / "1"
#   PYVE_ENV_EXTRA[]            — pyproject extra name | ""
#   PYVE_ENV_MANIFEST[]         — conda/pip manifest path | ""
#   PYVE_ENV_APP_TYPE[]         — structured attr | ""
#   PYVE_ENV_PACKAGING[]        — packaging artifact kind (S15) | ""
#   PYVE_ENV_<idx>_ATTRS[]      — per-env provider-private "key=value" list (S9)
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
# array state. Validation errors propagate via non-zero exit + stderr.
# When the manifest file is absent the state resets to the empty-config
# baseline (zero envs) — `pyve.toml` is the sole declaration pyve reads. A
# legacy `.pyve/config`-only project is therefore uninitialized from pyve's
# point of view; the v2 banner nudges `pyve self migrate`.
manifest_load() {
    local manifest="${1:-pyve.toml}"
    if [[ ! -f "$manifest" ]]; then
        _manifest_reset_state
        return 0
    fi
    # Pyve toolchain python: resolve Pyve's own interpreter
    # (PYVE_PYTHON → hidden toolchain venv → bare `python`), not the dev's
    # PATH `python`. Closes the Node-only mis-enumeration the N.at spike
    # found (a shim with no pinned version killed the manifest parse).
    # The `|| ${PYVE_PYTHON:-python}` fallback keeps this self-sufficient
    # when lib/toolchain_python.sh isn't sourced (piecemeal test subshells)
    # — the override path still wins. `local py` is split from the
    # assignment so the command-substitution exit status isn't masked by
    # `local` (the classic bash gotcha).
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    local kv
    kv="$("$py" "$_PYVE_MANIFEST_HELPER" "$manifest")" || return $?
    eval "$kv"
}

# print the project's advisory notes — spec-ahead
# attributes recorded in pyve.toml but not materialized (advisory
# backends/languages/frameworks/packaging/app_type + require_min_version /
# manual_steps). One note per line; empty output when there are none, when
# no pyve.toml exists, or when the toolchain is unavailable (advisory
# surfacing is informational and must never become a failure). Routes
# through the pyve_toml_helper `advisories` mode so the closed vocabulary
# lives in exactly one place. Shared by the check and status composers.
manifest_advisory_notes() {
    [[ -f pyve.toml ]] || return 0
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    "$py" "$_PYVE_MANIFEST_HELPER" advisories pyve.toml 2>/dev/null || return 0
}

# Reset every PYVE_* global to the empty-config baseline — the state
# `manifest_load` yields when no `pyve.toml` exists.
#
# Every assignment below sets an exposed global consumed by downstream pyve
# code and tests (the accessors in this file, plus env.sh / lock.sh / the
# plugins); they look unused inside this single file only, so SC2034 is
# disabled for the whole function.
# shellcheck disable=SC2034
_manifest_reset_state() {
    PYVE_SCHEMA_VERSION="3.0"
    PYVE_PROJECT_NAME=""
    PYVE_PROJECT_DEFAULTS_VERSION=""
    PYVE_ENV_NAMES=()
    PYVE_ENV_PURPOSE=()
    PYVE_ENV_BACKEND=()
    PYVE_ENV_PATH=()
    PYVE_ENV_EDITABLE=()
    PYVE_ENV_DEFAULT=()
    PYVE_ENV_LAZY=()
    PYVE_ENV_EXTRA=()
    PYVE_ENV_MANIFEST=()
    PYVE_ENV_APP_TYPE=()
    PYVE_ENV_PACKAGING=()
    PYVE_ENV_REQUIREMENTS_Q=()
    PYVE_ENV_FRAMEWORKS_Q=()
    PYVE_ENV_LANGUAGES_Q=()
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

# Resolve <env_name> to one of: run | test | utility | temp.
# Always returns a valid purpose; never empty, never fail-1. Resolution:
#   1. If <env_name> is in PYVE_ENV_NAMES with a non-empty declared
#      purpose → return the declared value.
#   2. Else apply the name-based default rule:
#        "testenv" → "test"
#        "root"    → "utility"
#        otherwise → "utility"
#
# Works even if manifest_load has not been called (PYVE_ENV_NAMES unset
# is treated as "no declared envs" — bash-3.2-safe under `set -u`).
# This is the canonical resolver used by purpose-gating selectors
# (e.g. `pyve test --env <name>`); `manifest_get_purpose` remains the
# raw accessor.
manifest_resolve_purpose() {
    local name="$1"
    local raw=""
    if [[ -n "${PYVE_ENV_NAMES+x}" ]]; then
        local i
        for ((i=0; i<${#PYVE_ENV_NAMES[@]}; i++)); do
            if [[ "${PYVE_ENV_NAMES[$i]}" == "$name" ]]; then
                raw="${PYVE_ENV_PURPOSE[$i]}"
                break
            fi
        done
    fi
    if [[ -n "$raw" ]]; then
        printf '%s' "$raw"
        return 0
    fi
    case "$name" in
        testenv) printf '%s' "test" ;;
        root)    printf '%s' "utility" ;;
        *)       printf '%s' "utility" ;;
    esac
}

manifest_get_backend() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_BACKEND[$i]}"
}

manifest_get_path() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_PATH[$i]}"
}

# The `editable` setup directive (P.l.2): an editable self-install target with
# optional extras (e.g. ".[corruptions]"), or empty when not declared.
manifest_get_editable() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_EDITABLE[$i]}"
}

manifest_get_app_type() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_ENV_APP_TYPE[$i]}"
}

# the env's `packaging` value (artifact kind read by
# `pyve package`), or empty string when undeclared. Returns 1 (no output)
# for unknown env names. The v2 read-compat synthesis path doesn't populate
# PYVE_ENV_PACKAGING with declared values (v2 had no packaging concept), so
# guard the read for bash-3.2 `set -u` safety when the array is shorter.
manifest_get_packaging() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    if [[ -n "${PYVE_ENV_PACKAGING+x}" ]] \
       && [[ "$i" -lt "${#PYVE_ENV_PACKAGING[@]}" ]]; then
        printf '%s' "${PYVE_ENV_PACKAGING[$i]}"
    fi
}

# read a packaging-/backend-provider-private attribute
# declared on `[env.<name>]` (e.g. `dockerfile`). Core stores these but
# never interprets them; this accessor exists so a provider's `package`
# hook can read its own config. Prints empty string for an unset attr on a
# known env; returns 1 (no output) for unknown envs. Mirrors
# manifest_get_plugin_attr. The v2 read-compat synthesis path doesn't emit
# PYVE_ENV_<idx>_ATTRS, so the read is guarded.
manifest_get_env_attr() {
    local i; i="$(_manifest_name_to_index "$1")" || return 1
    local key="$2"
    local arr_name="PYVE_ENV_${i}_ATTRS"
    local item
    eval "
        if [[ -n \"\${${arr_name}+x}\" ]]; then
            for item in \"\${${arr_name}[@]+\"\${${arr_name}[@]}\"}\"; do
                if [[ \"\$item\" == \"\$key=\"* ]]; then
                    printf '%s' \"\${item#*=}\"
                    return 0
                fi
            done
        fi
    "
    return 0
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

# manual_steps advisory accessor. Mirrors
# manifest_get_languages's contract — populate the caller's named
# array. Returns 1 (no assignment) for unknown env names. Reads
# PYVE_ENV_MANUAL_STEPS_Q only when it's been populated (the v2
# read-compat synthesis path doesn't emit this array).
manifest_get_manual_steps() {
    local i out_var
    i="$(_manifest_name_to_index "$1")" || return 1
    out_var="$2"
    if [[ -n "${PYVE_ENV_MANUAL_STEPS_Q+x}" ]] \
       && [[ "$i" -lt "${#PYVE_ENV_MANUAL_STEPS_Q[@]}" ]]; then
        eval "$out_var=( ${PYVE_ENV_MANUAL_STEPS_Q[$i]} )"
    else
        eval "$out_var=()"
    fi
}

# ────────────────────────────────────────────────────────────────────
# Plugin accessors.
#
# `[plugins.<name>]` blocks expose one core key (`path`, default ".")
# plus any provider-private attributes per spike S9. The Python helper
# emits parallel arrays:
#
#   PYVE_PLUGIN_NAMES[]                   — declared plugin names
#   PYVE_PLUGIN_PATHS[]                   — corresponding paths
#   PYVE_PLUGIN_<idx>_ATTRS[]             — per-plugin "key=value" list
#                                           (idx = position in NAMES)
#
# No `role` field (spike S3). The cardinality check on `path = "."`
# (spike S4) is a registry concern, not a parser concern; see
# lib/plugins/registry.sh.
# ────────────────────────────────────────────────────────────────────

# Private: index lookup for plugin names. Mirrors _manifest_name_to_index.
_manifest_plugin_name_to_index() {
    local target="$1" i
    [[ -n "${PYVE_PLUGIN_NAMES+x}" ]] || return 1
    for ((i=0; i<${#PYVE_PLUGIN_NAMES[@]}; i++)); do
        if [[ "${PYVE_PLUGIN_NAMES[$i]}" == "$target" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

# Print declared plugin names, one per line. Empty when no plugins declared.
manifest_list_plugins() {
    [[ -n "${PYVE_PLUGIN_NAMES+x}" ]] || return 0
    local n
    for n in "${PYVE_PLUGIN_NAMES[@]+"${PYVE_PLUGIN_NAMES[@]}"}"; do
        printf '%s\n' "$n"
    done
}

# Print the plugin's `path`. Returns 1 (no output) for unknown plugins.
manifest_get_plugin_path() {
    local i; i="$(_manifest_plugin_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_PLUGIN_PATHS[$i]}"
}

# Print the value of a provider-private attribute, or empty string if
# unset on a known plugin. Returns 1 (no output) for unknown plugins.
manifest_get_plugin_attr() {
    local i; i="$(_manifest_plugin_name_to_index "$1")" || return 1
    # shellcheck disable=SC2034 # key + item are referenced inside the eval block below (shellcheck can't see into eval)
    local key="$2"
    local arr_name="PYVE_PLUGIN_${i}_ATTRS"
    # shellcheck disable=SC2034 # referenced inside the eval block below (shellcheck can't see into eval)
    local item
    eval "
        if [[ -n \"\${${arr_name}+x}\" ]]; then
            for item in \"\${${arr_name}[@]+\"\${${arr_name}[@]}\"}\"; do
                if [[ \"\$item\" == \"\$key=\"* ]]; then
                    printf '%s' \"\${item#*=}\"
                    return 0
                fi
            done
        fi
    "
    return 0
}
