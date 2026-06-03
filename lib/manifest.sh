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
# array state. Validation errors propagate via non-zero exit + stderr.
#
# Fallback paths (when the manifest file is absent):
#   v3.0-only: remove in N-8
#     - If legacy v2 sources are present (`.pyve/config` and/or
#       `[tool.pyve.testenvs.*]`), synthesize the v3 array shape from
#       them so the rest of pyve sees a uniform model and v2-configured
#       projects continue to work through the deprecation window.
#     - The synthesis path emits a one-shot deprecation_warn per shell
#       (memoized via the same sentinel scheme as the N.h banner).
#   - If no legacy sources either → empty config (zero envs).
#
# The synthesis layer is bounded; Subphase N-8 removes everything tagged
# `v3.0-only: remove in N-8` together with the rest of the v2
# deprecation surface.
manifest_load() {
    local manifest="${1:-pyve.toml}"
    if [[ ! -f "$manifest" ]]; then
        # v3.0-only: remove in N-8
        if _manifest_has_legacy_sources; then
            _manifest_synthesize_from_legacy
            return 0
        fi
        _manifest_reset_state
        return 0
    fi
    local py="${PYVE_PYTHON:-python}"
    local kv
    kv="$("$py" "$_PYVE_MANIFEST_HELPER" "$manifest")" || return $?
    eval "$kv"
}

# Reset every PYVE_* array to the empty-config baseline. Pulled out
# so both the "no sources at all" path and the synthesis path start
# from the same clean state.
_manifest_reset_state() {
    # shellcheck disable=SC2034  # PYVE_SCHEMA_VERSION + PYVE_PROJECT_NAME are
    # exposed globals consumed by downstream pyve code and tests; the assignments
    # here are the contract — they look unused inside this single file only.
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
}

# v3.0-only: remove in N-8
#
# Detect whether any v2 *config* source exists. Bare `.pyve/testenvs/`
# on disk is state, not configuration, and does not by itself trigger
# synthesis (the N.h banner still fires on it for the user-visible
# nudge, but the manifest stays empty for that pathological case).
_manifest_has_legacy_sources() {
    [[ -f .pyve/config ]] && return 0
    if [[ -f pyproject.toml ]] \
       && grep -qE '^\[tool\.pyve\.testenvs(\]|\.)' pyproject.toml; then
        return 0
    fi
    return 1
}

# v3.0-only: remove in N-8
#
# Build the v3 array state from `.pyve/config` (YAML, for [env.root])
# and `[tool.pyve.testenvs.*]` (TOML, for each declared test env).
# Mirrors what `pyve self migrate` writes into pyve.toml, but populates
# arrays directly rather than going through TOML text.
#
# Mapping rules (mirrors N.g's render):
#   - Always emit [env.root]: purpose="utility", backend from
#     `.pyve/config:backend` (empty when no `.pyve/config`).
#   - Each declared testenv becomes [env.<name>] with purpose="test"
#     and per-env attrs (backend/lazy/extra/manifest/requirements)
#     carried over from the v2 declaration.
#   - The env named "testenv" (or, if none, the first declared) gets
#     `default = "1"`.
#   - When no testenv blocks are declared but `.pyve/config` exists,
#     `read_env_config` synthesizes the implicit-default "testenv"
#     entry — same behavior pre-N.i had via the v2 lib/envs.sh
#     reader, preserved here for compatibility.
_manifest_synthesize_from_legacy() {
    _manifest_reset_state
    # shellcheck disable=SC2034  # exposed global, see note on _manifest_reset_state
    PYVE_PROJECT_NAME="$(basename "$(pwd)")"

    # [env.root]: backend from .pyve/config when available.
    local main_backend=""
    if [[ -f .pyve/config ]]; then
        main_backend="$(read_config_value backend 2>/dev/null || true)"
    fi
    PYVE_ENV_NAMES+=("root")
    PYVE_ENV_PURPOSE+=("utility")
    PYVE_ENV_BACKEND+=("$main_backend")
    PYVE_ENV_PATH+=(".")
    PYVE_ENV_DEFAULT+=("0")
    PYVE_ENV_LAZY+=("0")
    PYVE_ENV_EXTRA+=("")
    PYVE_ENV_MANIFEST+=("")
    PYVE_ENV_APP_TYPE+=("")
    PYVE_ENV_REQUIREMENTS_Q+=("")
    PYVE_ENV_FRAMEWORKS_Q+=("")
    PYVE_ENV_LANGUAGES_Q+=("")

    # Determine whether to walk testenvs.
    local should_read_testenvs=0
    if [[ -f pyproject.toml ]] \
       && grep -qE '^\[tool\.pyve\.testenvs(\]|\.)' pyproject.toml; then
        should_read_testenvs=1
    elif [[ -f .pyve/config ]]; then
        # v2 projects rely on the implicit "testenv" default even
        # without an explicit pyproject block.
        should_read_testenvs=1
    fi

    if [[ "$should_read_testenvs" == "1" ]]; then
        # read_env_config may fail when the python helper can't be
        # resolved (e.g. asdf shim trap with no .tool-versions). Swallow
        # the failure so the synthesis still produces the [env.root]
        # entry from .pyve/config alone — the legacy testenvs are
        # synthesized only when read_env_config succeeds.
        read_env_config 2>/dev/null || true
        # Defensive: PYVE_TESTENVS_NAMES may still be unset if
        # read_env_config short-circuited. Treat the zero-testenv case
        # as "no testenvs to synthesize" rather than crashing under
        # `set -u` on the array-length read.
        local n=0
        if [[ -n "${PYVE_TESTENVS_NAMES+x}" ]]; then
            n=${#PYVE_TESTENVS_NAMES[@]}
        fi
        local i default_idx=-1
        for ((i=0; i<n; i++)); do
            if [[ "${PYVE_TESTENVS_NAMES[$i]}" == "testenv" ]]; then
                default_idx=$i
                break
            fi
        done
        if [[ "$default_idx" -lt 0 ]] && [[ "$n" -gt 0 ]]; then
            default_idx=0
        fi
        for ((i=0; i<n; i++)); do
            PYVE_ENV_NAMES+=("${PYVE_TESTENVS_NAMES[$i]}")
            PYVE_ENV_PURPOSE+=("test")
            PYVE_ENV_BACKEND+=("${PYVE_TESTENV_BACKEND[$i]}")
            PYVE_ENV_PATH+=(".")
            if [[ "$i" -eq "$default_idx" ]]; then
                PYVE_ENV_DEFAULT+=("1")
            else
                PYVE_ENV_DEFAULT+=("0")
            fi
            PYVE_ENV_LAZY+=("${PYVE_TESTENV_LAZY[$i]}")
            PYVE_ENV_EXTRA+=("${PYVE_TESTENV_EXTRA[$i]}")
            PYVE_ENV_MANIFEST+=("${PYVE_TESTENV_MANIFEST[$i]}")
            PYVE_ENV_APP_TYPE+=("")
            PYVE_ENV_REQUIREMENTS_Q+=("${PYVE_TESTENV_REQUIREMENTS_Q[$i]}")
            PYVE_ENV_FRAMEWORKS_Q+=("")
            PYVE_ENV_LANGUAGES_Q+=("")
        done
    fi

    _manifest_deprecation_warn_legacy
}

# v3.0-only: remove in N-8
#
# Emit a one-shot deprecation warning per (session, cwd) when pyve
# reads from legacy v2 sources. Memoization mirrors N.h's banner —
# `PYVE_V2_BANNER_SESSION` (when set) or `$PPID` keys the sentinel,
# with `$XDG_STATE_HOME/pyve/` (or `~/.local/state/pyve/`) as the
# state dir.
_manifest_deprecation_warn_legacy() {
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pyve"
    local session_key="${PYVE_V2_BANNER_SESSION:-${PPID:-0}}"
    local hash
    hash="$(printf '%s' "$PWD" | cksum | awk '{print $1}')"
    local sentinel="$state_dir/legacy-read-warn-$session_key-$hash"
    if [[ -f "$sentinel" ]]; then
        return 0
    fi
    printf "warning: pyve is reading legacy v2 sources (.pyve/config and/or [tool.pyve.testenvs.*]); legacy support ends at v3.1. Run 'pyve self migrate' to upgrade.\n" >&2
    mkdir -p "$state_dir" 2>/dev/null || true
    : >| "$sentinel" 2>/dev/null || true
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

# Story N.d. Resolve <env_name> to one of: run | test | utility | temp.
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

# Story N.p (S7): manual_steps advisory accessor. Mirrors
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
# Plugin accessors (Story N.k, folding N.k.1).
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
    local key="$2"
    local arr_name="PYVE_PLUGIN_${i}_ATTRS"
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
