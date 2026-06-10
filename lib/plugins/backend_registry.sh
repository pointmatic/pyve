# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/backend_registry.sh — backend-provider registry
#
# Backends are owned by plugins; each backend declares one of three
# categories (spike S6) with documented init/purge/activation semantics:
#
#   virtualized   — per-project env dir (`.venv/`, `.pyve/envs/<name>/`,
#                   `node_modules/`). Init creates the dir; purge removes
#                   it; activation adds `bin/` to PATH.
#   cache-backed  — shared user-level dep cache + project lockfile
#                   (`~/.cargo/registry/` + `Cargo.lock`). Init runs the
#                   tool's fetch; purge removes only project-local build
#                   dirs (never the shared cache); activation contributes
#                   nothing to PATH (lockfile drives resolution).
#   check-only    — pyve verifies presence and version; no install action.
#                   init verifies; purge is a no-op; activation contributes
#                   nothing.
#
# v3.0 ships only `virtualized` (venv, micromamba). The other categories
# are designed-in but unexercised — schema accommodates them.
#
# Dispatch convention: `bp_dispatch <backend> <hook> [args...]` calls
# `<backend>_pyve_bp_<hook>` if defined; else `pyve_bp_default_<category>_<hook>`
# (category-aware default) if defined; else returns 0 silently.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Parallel indexed arrays — registration record (name, plugin, category)
# stored at the same index. Bash 3.2-safe (no associative arrays).
PYVE_BP_NAMES=()
PYVE_BP_PLUGINS=()
PYVE_BP_CATEGORIES=()

# Valid category enum (spike S6).
_PYVE_BP_VALID_CATEGORIES=("virtualized" "cache-backed" "check-only")

bp_registry_reset() {
    PYVE_BP_NAMES=()
    PYVE_BP_PLUGINS=()
    PYVE_BP_CATEGORIES=()
}

# Private: index lookup. Print 0-based index of <backend_name> in
# PYVE_BP_NAMES, or return 1 (no output) if absent.
_bp_name_to_index() {
    local target="$1" i
    [[ -n "${PYVE_BP_NAMES+x}" ]] || return 1
    for ((i=0; i<${#PYVE_BP_NAMES[@]}; i++)); do
        if [[ "${PYVE_BP_NAMES[$i]}" == "$target" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

# Private: predicate — 0 if <category> is in the valid enum.
_bp_category_is_valid() {
    local cat="$1" valid
    for valid in "${_PYVE_BP_VALID_CATEGORIES[@]}"; do
        [[ "$valid" == "$cat" ]] && return 0
    done
    return 1
}

# Register a backend provider. Idempotent on identical re-registration;
# errors on conflicting re-registration (different plugin or category)
# or unknown category.
#
# Usage: bp_register <plugin> <backend_name> <category>
bp_register() {
    local plugin="$1"
    local name="$2"
    local category="$3"

    if ! _bp_category_is_valid "$category"; then
        printf "error: bp_register: unknown category '%s' (expected one of: %s)\n" \
            "$category" "${_PYVE_BP_VALID_CATEGORIES[*]}" >&2
        return 1
    fi

    local idx
    if idx="$(_bp_name_to_index "$name")"; then
        # Idempotent: same plugin + same category → no-op.
        if [[ "${PYVE_BP_PLUGINS[$idx]}" == "$plugin" ]] \
            && [[ "${PYVE_BP_CATEGORIES[$idx]}" == "$category" ]]; then
            return 0
        fi
        printf "error: bp_register: backend '%s' already registered to plugin '%s' (category '%s'); cannot re-register as plugin '%s' (category '%s')\n" \
            "$name" "${PYVE_BP_PLUGINS[$idx]}" "${PYVE_BP_CATEGORIES[$idx]}" "$plugin" "$category" >&2
        return 1
    fi

    PYVE_BP_NAMES+=("$name")
    PYVE_BP_PLUGINS+=("$plugin")
    PYVE_BP_CATEGORIES+=("$category")
    return 0
}

# Print the plugin owning <backend_name>. Returns 1 (no output) if unknown.
bp_lookup() {
    local idx
    idx="$(_bp_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_BP_PLUGINS[$idx]}"
}

# Print the category of <backend_name>. Returns 1 (no output) if unknown.
bp_category() {
    local idx
    idx="$(_bp_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_BP_CATEGORIES[$idx]}"
}

# Print all registered backend names, one per line, in registration order.
bp_list() {
    local n
    for n in "${PYVE_BP_NAMES[@]+"${PYVE_BP_NAMES[@]}"}"; do
        printf '%s\n' "$n"
    done
}

# Dispatch a hook for <backend_name>. Lookup order:
#   1. <backend_name>_pyve_bp_<hook>    — backend-specific impl
#   2. pyve_bp_default_<cat_san>_<hook> — category-default impl
#      where <cat_san> replaces hyphens with underscores so function
#      names stay shell-identifier-safe (cache-backed → cache_backed).
#   3. silent return 0                   — no contribution from this backend
#
# Args after the hook name are forwarded.
bp_dispatch() {
    local name="$1"
    local hook="$2"
    shift 2

    local idx
    if ! idx="$(_bp_name_to_index "$name")"; then
        printf "error: bp_dispatch: backend '%s' is not registered\n" "$name" >&2
        return 1
    fi

    local specific="${name}_pyve_bp_${hook}"
    if declare -F "$specific" >/dev/null 2>&1; then
        "$specific" "$@"
        return $?
    fi

    local cat="${PYVE_BP_CATEGORIES[$idx]}"
    # Sanitize category for function names: cache-backed → cache_backed.
    local cat_san="${cat//-/_}"
    local default_fn="pyve_bp_default_${cat_san}_${hook}"
    if declare -F "$default_fn" >/dev/null 2>&1; then
        "$default_fn" "$@"
        return $?
    fi

    return 0
}
