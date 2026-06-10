# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0
#============================================================
# lib/purge_composer.sh — composed `pyve purge` builder
#
# Gathers every active plugin's `pyve_plugin_purge_inventory` (created /
# authored declarations from N.r / N.z), composes them keyed by
# (plugin, path), enforces the user-authored guard, presents a grouped
# confirmation, and DELEGATES the actual removal to each plugin's
# `pyve_plugin_purge` hook.
#
# Design (Option B, developer decision on N.ai): the composer owns the
# inventory / guard / confirmation; the per-plugin purge hooks remain the
# authoritative removers so their smart-purge nuance (.env-if-empty,
# .gitignore-section-only, --keep-testenv surgical deletion) is preserved.
# The flat `created <path>` inventory could not express those rules.
#
#   compose_purge_inventory          — aggregate, tagged `<plugin> <class> <path>`
#   compose_purge_removals           — created set minus authored-guard matches
#   compose_purge [args]             — orchestrate confirmation + delegated removal
#
# Failure recovery. Removal is delete-only (`rm -rf`), hence convergent and
# idempotent: an interrupted purge leaves a strict subset removed, never a
# corrupt half-state. The composer therefore dispatches ALL active plugins
# even if one fails (no early abort), collects the failures, reports which
# (plugin) failed, notes that re-running `pyve purge` is safe and resumes
# (already-removed artifacts are no-ops; the failed one is retried), and
# exits nonzero. The authored guard runs before any deletion, so a re-run
# can never escalate to touching user files.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Emit the composed purge inventory across all active plugins, one entry per
# line as `<plugin> <class> <path>` (class ∈ created|authored). Paths are
# whatever the plugin's inventory hook emits — visitor plugins (path != ".")
# already prefix their paths, so monorepo entries are disambiguated.
compose_purge_inventory() {
    local name path line cls p
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        path="$(manifest_get_plugin_path "$name" 2>/dev/null || true)"
        [[ -z "$path" ]] && path="."
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Each hook line is "<class> <path>"; re-tag with the plugin.
            cls="${line%% *}"
            p="${line#* }"
            [[ -z "$cls" || -z "$p" || "$cls" == "$p" ]] && continue
            printf '%s %s %s\n' "$name" "$cls" "$p"
        done < <(plugin_dispatch "$name" purge_inventory "$path" 2>/dev/null || true)
    done < <(plugin_list_active)
}

# Print the removal set (`<plugin> <path>` per line) — every `created` entry
# whose path is NOT protected by an `authored` declaration anywhere in the
# composed inventory. Authorship is a cross-plugin safety net: a path
# declared authored by ANY plugin is never removed, even if another plugin
# (or the same one, by mistake) declared it created. Authored entries may be
# globs (`requirements*.txt`); a created path matching the glob is protected.
compose_purge_removals() {
    local inv
    inv="$(compose_purge_inventory)"

    # Collect authored patterns first (the guard set).
    local -a authored=()
    local plugin cls path
    while read -r plugin cls path; do
        [[ "$cls" == "authored" ]] && authored+=("$path")
    done <<< "$inv"

    # Emit created entries not matched by any authored pattern.
    while read -r plugin cls path; do
        [[ "$cls" == "created" ]] || continue
        local pat protected=0
        for pat in "${authored[@]+"${authored[@]}"}"; do
            # shellcheck disable=SC2053  # intentional glob match (pat may contain *)
            if [[ "$path" == $pat ]]; then
                protected=1
                break
            fi
        done
        (( protected )) && continue
        printf '%s %s\n' "$plugin" "$path"
    done <<< "$inv"
}

# Print the tidied set (`<plugin> <path>` per line) — every `tidied` entry in
# the composed inventory. A `tidied` artifact is one the plugin cleans in
# place (strips only its OWN section from a shared file, e.g. .gitignore) or
# removes only when empty (e.g. .env) — never a wholesale delete of user
# data. Display-only: the actual tidy is delegated to the plugin's purge hook
# (Option B). NOT subject to the authored guard — a tidied path may itself be
# user-authored (.gitignore is); surfacing it keeps the confirmation honest,
# but the plugin hook is responsible for touching only its own part.
compose_purge_tidied() {
    local inv plugin cls path
    inv="$(compose_purge_inventory)"
    while read -r plugin cls path; do
        [[ "$cls" == "tidied" ]] || continue
        printf '%s %s\n' "$plugin" "$path"
    done <<< "$inv"
}

# Orchestrate a composed purge: build the inventory, apply the authored
# guard, confirm (unless skipped), then delegate removal to each active
# plugin's purge hook. Returns nonzero if any plugin's purge hook failed
# (see the file header's "Failure recovery").
compose_purge() {
    local skip_confirm=false
    local keep_testenv=false
    local -a py_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y|--force)
                skip_confirm=true
                shift
                ;;
            --keep-testenv)
                keep_testenv=true
                py_args+=("--keep-testenv")
                shift
                ;;
            -*)
                unknown_flag_error "purge" "$1" --yes --force --keep-testenv --help
                ;;
            *)
                # A positional is a venv directory — a Python-plugin concept;
                # forward it to the Python purge hook.
                py_args+=("$1")
                shift
                ;;
        esac
    done

    header_box "pyve purge"

    # Composed inventory + authored guard. `removals` are wholesale deletes;
    # `tidied` are clean-in-place / remove-if-empty (e.g. .gitignore, .env).
    # Both are surfaced so the confirmation matches what the purge actually
    # touches (N.bf.3) — under-reporting either is a consent/trust bug.
    local removals tidied
    removals="$(compose_purge_removals)"
    tidied="$(compose_purge_tidied)"

    if [[ -z "$removals" && -z "$tidied" ]]; then
        info "Nothing to remove — no pyve-created artifacts found."
        footer_box
        return 0
    fi

    # Grouped confirmation: list what will be removed, then what will be
    # cleaned, each by plugin.
    local plugin path last_plugin=""
    if [[ -n "$removals" ]]; then
        info "The following pyve-created artifacts will be removed:"
        while read -r plugin path; do
            [[ -z "$plugin" ]] && continue
            if [[ "$plugin" != "$last_plugin" ]]; then
                printf "  [%s]\n" "$plugin"
                last_plugin="$plugin"
            fi
            printf "    %s\n" "$path"
        done <<< "$removals"
    fi

    if [[ -n "$tidied" ]]; then
        info "The following will be cleaned (pyve's own entries only) or removed if empty:"
        last_plugin=""
        while read -r plugin path; do
            [[ -z "$plugin" ]] && continue
            if [[ "$plugin" != "$last_plugin" ]]; then
                printf "  [%s]\n" "$plugin"
                last_plugin="$plugin"
            fi
            printf "    %s\n" "$path"
        done <<< "$tidied"
    fi

    # --keep-testenv prunes around the test envs rather than wiping the whole
    # tree, so any `.pyve` listed above is pruned, not fully removed. The flat
    # inventory can't express that surgical scope (Option B seam), so surface
    # it as a note to prevent a false "my test envs are about to die" alarm.
    if [[ "$keep_testenv" == true ]]; then
        info "--keep-testenv: your test environments are preserved — '.pyve' is pruned around them, not fully removed."
    fi

    if [[ "$skip_confirm" != true ]] && [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
        warn "This permanently removes or cleans the artifacts listed above."
        if ! ask_yn "Proceed"; then
            info "Aborted — no changes made"
            return 0
        fi
    fi

    # Delegated removal. Suppress each plugin's own confirmation/frame:
    #   PYVE_FORCE_YES=1     — the Python purge hook honors this to skip its
    #                          internal prompt (the composer already confirmed).
    #   PYVE_PURGE_COMPOSED=1 — gates the per-plugin header/footer box so the
    #                          composer owns the frame.
    export PYVE_FORCE_YES=1
    export PYVE_PURGE_COMPOSED=1

    local -a failed=()
    local name p_path rc out
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        p_path="$(manifest_get_plugin_path "$name" 2>/dev/null || true)"
        [[ -z "$p_path" ]] && p_path="."

        printf "[%s]\n" "$name"
        rc=0
        if [[ "$name" == "python" ]]; then
            # Python is the root plugin; forward the user's purge args
            # (venv dir, --keep-testenv) rather than a plugin path.
            out="$(plugin_dispatch python purge "${py_args[@]+"${py_args[@]}"}" 2>&1)" || rc=$?
        elif [[ "$p_path" == "." ]]; then
            out="$(plugin_dispatch "$name" purge 2>&1)" || rc=$?
        else
            out="$(plugin_dispatch "$name" purge "$p_path" 2>&1)" || rc=$?
        fi
        [[ -n "$out" ]] && printf '%s\n' "$out"

        if (( rc != 0 )); then
            failed+=("$name")
        fi
    done < <(plugin_list_active)

    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "Purge incomplete — these plugins reported errors: ${failed[*]}"
        info "Removal is idempotent — re-run 'pyve purge' to retry safely; already-removed artifacts are skipped."
        return 1
    fi

    footer_box
    return 0
}
