# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/testenvs.sh — testenv-DX config foundation (Story M.g)
#
# Reads [tool.pyve.testenvs] from a project's pyproject.toml via the
# Python tomllib helper (`lib/pyve_testenvs_helper.py`) and exposes a
# flat accessor surface for consumers (`pyve testenv`, `pyve test`,
# `pyve lock`). All state lives in parallel indexed arrays populated by
# `read_testenv_config`.
#
# Spike doc (decisions): docs/specs/spike-m-f-testenvs-config.md
#
# Reserved names:
#   - `root`    — the project's main `.venv/` (or conda env). NOT a
#                 testenv; selection-only. Cannot be redeclared.
#   - `testenv` — the well-known default at .pyve/testenvs/testenv/...
#                 MAY be redeclared.
#
# State populated by `read_testenv_config` (V3 wire format):
#   PYVE_TESTENVS_DEFAULT       — name of the default env
#   PYVE_TESTENVS_NAMES[]       — declared env names (indexed)
#   PYVE_TESTENV_BACKEND[]      — parallel: backend per env
#   PYVE_TESTENV_LAZY[]         — parallel: "0" / "1"
#   PYVE_TESTENV_EXTRA[]        — parallel: pyproject extra name or ""
#   PYVE_TESTENV_MANIFEST[]     — parallel: conda manifest path or ""
#   PYVE_TESTENV_REQUIREMENTS_Q[] — parallel: shell-quoted requirements list
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard immediately below.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Path to the Python helper. Resolves relative to this file so the
# library is testable independent of pyve.sh's SCRIPT_DIR.
_PYVE_TESTENVS_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pyve_testenvs_helper.py"

# Read [tool.pyve.testenvs] from <pyproject.toml> (default ./pyproject.toml)
# and populate the V3 array state. Missing file or missing block yields
# the implicit default (single venv `testenv`). Validation errors from
# the helper propagate via non-zero exit and stderr.
read_testenv_config() {
    local pyproject="${1:-pyproject.toml}"
    local py="${PYVE_PYTHON:-python}"
    local kv
    kv="$("$py" "$_PYVE_TESTENVS_HELPER" "$pyproject")" || return $?
    eval "$kv"
}

# Index lookup: print the 0-based position of <name> in PYVE_TESTENVS_NAMES,
# or return 1 (no output) if absent. Private helper.
_testenvs_name_to_index() {
    local target="$1" i
    for ((i=0; i<${#PYVE_TESTENVS_NAMES[@]}; i++)); do
        if [[ "${PYVE_TESTENVS_NAMES[$i]}" == "$target" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

# Field accessors (used by tests and consumers; one per parallel array).
# Print empty string if name is unknown; bash-3.2-safe under set -u.
_testenv_backend_of() {
    local i; i="$(_testenvs_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_TESTENV_BACKEND[$i]}"
}
_testenv_extra_of() {
    local i; i="$(_testenvs_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_TESTENV_EXTRA[$i]}"
}
_testenv_manifest_of() {
    local i; i="$(_testenvs_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_TESTENV_MANIFEST[$i]}"
}
# Populate a caller-named array with the env's requirements list.
# Usage: declare -a reqs; _testenv_requirements_of <name> reqs
_testenv_requirements_of() {
    local i out_var
    i="$(_testenvs_name_to_index "$1")" || return 1
    out_var="$2"
    eval "$out_var=( ${PYVE_TESTENV_REQUIREMENTS_Q[$i]} )"
}

# Predicate: 0 if <name> is one of the reserved names (`root`, `testenv`),
# 1 otherwise.
is_testenv_reserved() {
    case "$1" in
        root|testenv) return 0 ;;
        *) return 1 ;;
    esac
}

# Predicate: 0 if <name> appears in PYVE_TESTENVS_NAMES, 1 otherwise.
# Note: `root` is reserved-but-not-declared (never in PYVE_TESTENVS_NAMES).
is_testenv_declared() {
    _testenvs_name_to_index "$1" >/dev/null
}

# Predicate: 0 if <name> is declared with `lazy = true`, 1 otherwise
# (including: not declared at all).
is_testenv_lazy() {
    local i; i="$(_testenvs_name_to_index "$1")" || return 1
    [[ "${PYVE_TESTENV_LAZY[$i]}" == "1" ]]
}

# Print declared env names + reserved names, one per line. Reserved
# names that overlap with declared ones (i.e. `testenv`) print once.
list_testenv_names() {
    local n
    for n in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        printf '%s\n' "$n"
    done
    # `root` is the one reserved name that is never in NAMES.
    if ! _testenvs_name_to_index root >/dev/null; then
        printf '%s\n' "root"
    fi
}

# Verify a name is usable: declared OR reserved. Print a helpful error
# to stderr and return 1 if not. Caller's job to log_error if it wants
# its own formatting; this prints the canonical message.
validate_testenv_decl() {
    local name="$1"
    if is_testenv_reserved "$name" || is_testenv_declared "$name"; then
        return 0
    fi
    printf "error: testenv '%s' is not declared and is not a reserved name (root, testenv)\n" "$name" >&2
    return 1
}

# =====================================================================
# .state file helpers (Story M.h.1)
# =====================================================================
#
# Each named testenv has a sibling `.state` file at
# .pyve/testenvs/<name>/.state that records provisioning + usage data.
# Schema is plain key=value lines, sourceable:
#
#   backend=venv|micromamba|inherit
#   manifest=<relative path or empty>
#   manifest_sha256=<64-hex or empty>
#   provisioned_at=<unix epoch seconds>
#   last_used_at=<unix epoch seconds or 0>
#
# Consumers (none yet in M.h.1; first is M.h.2's migration helper).

# Print the .state file path for <name>.
state_path() {
    printf '%s' ".pyve/testenvs/$1/.state"
}

# Write/overwrite the .state file for <name>. Required: <name> <backend>.
# Optional keyword args (in any order):
#   manifest=<path>
#   manifest_sha256=<hex>
#   provisioned_at=<epoch>   (default: current epoch)
#   last_used_at=<epoch>     (default: 0)
# Unknown keys are a hard error.
state_write() {
    local name="${1:-}" backend="${2:-}"
    if [[ -z "$name" || -z "$backend" ]]; then
        printf "error: state_write: requires <name> <backend>\n" >&2
        return 1
    fi
    shift 2
    local manifest="" sha="" prov="" last="0"
    local arg key val
    for arg in "$@"; do
        key="${arg%%=*}"
        val="${arg#*=}"
        case "$key" in
            manifest)        manifest="$val" ;;
            manifest_sha256) sha="$val" ;;
            provisioned_at)  prov="$val" ;;
            last_used_at)    last="$val" ;;
            *)
                printf "error: state_write: unknown keyword arg '%s'\n" "$key" >&2
                return 1
                ;;
        esac
    done
    [[ -z "$prov" ]] && prov="$(date +%s)"
    local file; file="$(state_path "$name")"
    mkdir -p "$(dirname "$file")"
    {
        printf 'backend=%s\n'         "$backend"
        printf 'manifest=%s\n'        "$manifest"
        printf 'manifest_sha256=%s\n' "$sha"
        printf 'provisioned_at=%s\n'  "$prov"
        printf 'last_used_at=%s\n'    "$last"
    } > "$file"
}

# Read the .state file for <name> into PYVE_TESTENV_STATE_* shell vars.
# Returns 1 (no shell mutation) if the file is missing or unreadable.
state_read() {
    local name="$1"
    local file; file="$(state_path "$name")"
    [[ -r "$file" ]] || return 1
    # Source into local vars first (subshell isolation), then promote.
    # Use a clean associative read rather than a raw `source` so a
    # malformed .state cannot inject arbitrary shell.
    local backend="" manifest="" sha="" prov="" last="0"
    local line key val
    while IFS= read -r line || [[ -n "$line" ]]; do
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
            backend)         backend="$val" ;;
            manifest)        manifest="$val" ;;
            manifest_sha256) sha="$val" ;;
            provisioned_at)  prov="$val" ;;
            last_used_at)    last="$val" ;;
        esac
    done < "$file"
    PYVE_TESTENV_STATE_BACKEND="$backend"
    PYVE_TESTENV_STATE_MANIFEST="$manifest"
    PYVE_TESTENV_STATE_MANIFEST_SHA256="$sha"
    PYVE_TESTENV_STATE_PROVISIONED_AT="$prov"
    PYVE_TESTENV_STATE_LAST_USED_AT="$last"
}

# Update only `last_used_at` to the current epoch; preserve all other
# fields. Returns 1 if the .state file is missing.
state_touch_last_used() {
    local name="$1"
    state_read "$name" || return 1
    state_write "$name" "$PYVE_TESTENV_STATE_BACKEND" \
        manifest="$PYVE_TESTENV_STATE_MANIFEST" \
        manifest_sha256="$PYVE_TESTENV_STATE_MANIFEST_SHA256" \
        provisioned_at="$PYVE_TESTENV_STATE_PROVISIONED_AT" \
        last_used_at="$(date +%s)"
}

# Resolve the on-disk path for <name>. Does NOT check existence; that is
# the caller's responsibility. Path shape per plan doc TC-M.2:
#   root      → .venv          (the project main venv; conda case TBD M.h)
#   <name>    → .pyve/testenvs/<name>/{venv|conda}/  (per declared backend)
#               Reserved `testenv` follows the same shape (always venv unless
#               redeclared) for back-compat with the existing layout.
resolve_testenv_path() {
    local name="$1"
    if [[ "$name" == "root" ]]; then
        # Main project env. M.h will reconcile this with main-env conda
        # backends; for now this matches today's .venv assumption.
        printf '%s' ".venv"
        return 0
    fi
    local backend
    backend="$(_testenv_backend_of "$name")" || backend="venv"
    if [[ "$backend" == "micromamba" || "$backend" == "inherit" ]]; then
        # Note: `inherit` resolution to a concrete backend happens at
        # provisioning time (M.k). The on-disk layout slot is still
        # conda-shaped for envs that *will* resolve to micromamba.
        printf '%s' ".pyve/testenvs/${name}/conda"
    else
        printf '%s' ".pyve/testenvs/${name}/venv"
    fi
}
