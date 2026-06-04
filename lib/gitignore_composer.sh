# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/gitignore_composer.sh — composed `.gitignore` builder (Story N.af)
#
# The `.gitignore` sibling of lib/envrc_composer.sh. Gathers every active
# plugin's `pyve_plugin_gitignore_entries` contribution, validates each
# through PC-1 (validate_gitignore_snippet, N.m), dedupes entries across
# plugins + composer-owned infrastructure, and wraps them in a
# sentinel-marked managed section. Writes atomically with a `.gitignore.prev`
# backup, preserving user-authored content ABOVE and BELOW the managed
# section.
#
#   _compose_gitignore_body          — pure assembly + PC-1 (stdout, no write)
#   compose_gitignore <path>         — atomic writer + user-content preserve
#   compose_project_gitignore <path> — reload manifest/registry, then compose
#                                      (init/update entry point; see N.ae.5)
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

GITIGNORE_MANAGED_START="# >>> pyve:managed:gitignore >>>"
GITIGNORE_MANAGED_END="# <<< pyve:managed:gitignore <<<"

# Composer-owned infrastructure lines (macOS + Pyve-managed state). These
# are not plugin-specific; they mirror what write_gitignore_template emitted
# before the composer. The venv directory is dynamic (a custom `pyve init
# <dir>` overrides it), so it is appended from DEFAULT_VENV_DIR.
_gitignore_infra_block() {
    cat <<'EOF'
# macOS
.DS_Store

# Pyve-managed
.pyve/envs
.pyve/testenvs
.envrc
.env
.vscode/settings.json
EOF
    # The venv directory is user-overridable (`pyve init <dir>`); honor the
    # recorded value from .pyve/config so a custom dir is ignored correctly
    # (mirrors the python activate emitter, N.ae.2). Falls back to the
    # default when no config is present.
    local venv_dir
    venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
    printf '%s\n' "${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
}

# Assemble the managed `.gitignore` body and emit it to stdout.
#
# Composer infra first, then each active plugin's validated entries. The
# combined stream is deduped: a pattern line emitted by more than one source
# (e.g. `.env`) appears once; comment lines pass through (they act as section
# headers) and consecutive blank lines collapse to one. A plugin hook that
# fails, or whose entries fail PC-1, halts the whole compose (non-zero).
_compose_gitignore_body() {
    local name path plugin_block
    local all
    all="$(_gitignore_infra_block)"$'\n'

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        path="$(manifest_get_plugin_path "$name" 2>/dev/null || true)"
        if ! plugin_block="$(plugin_dispatch "$name" gitignore_entries "$path")"; then
            log_error "gitignore_composer: plugin '$name' gitignore_entries hook failed"
            return 1
        fi
        if ! validate_gitignore_snippet "$plugin_block"; then
            log_error "gitignore_composer: plugin '$name' entries failed PC-1 validation"
            return 1
        fi
        all+=$'\n'"$plugin_block"$'\n'
    done < <(plugin_list_active)

    # The start marker is the FIRST line emitted so nothing composer-owned
    # sits above it — otherwise the header would be captured as "user content
    # above" on re-compose and duplicate (breaking idempotence). The header
    # comment lives inside the managed section, just after the start marker.
    printf '%s\n' "$GITIGNORE_MANAGED_START"
    printf '# pyve-managed .gitignore — do not edit between the markers;\n'
    printf '# add your own ignores above or below the managed section.\n'
    printf '%s\n' "$all" | awk '
        /^[[:space:]]*$/ { if (!blank) print ""; blank=1; next }
        /^[[:space:]]*#/ { print; blank=0; next }
        { if (!seen[$0]++) print; blank=0 }
    '
    printf '%s\n' "$GITIGNORE_MANAGED_END"
}

# Print lines from <file> EXCEPT pattern lines that already appear in <body>
# (so a legacy `.gitignore`'s pyve-managed lines aren't duplicated when its
# content is carried below the new managed section). User comments and blank
# lines are kept.
_gitignore_filter_managed_dups() {
    local file="$1" body="$2"
    # Two-file awk: first the managed body (collect its pattern lines into
    # `seen`), then the legacy file (print lines not already covered). Passing
    # the multi-line body as a file via process substitution avoids BSD awk's
    # "newline in string" error from a multi-line `-v` assignment.
    awk '
        FNR==NR {
            if ($0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/) seen[$0]=1
            next
        }
        /^[[:space:]]*$/ { print; next }
        /^[[:space:]]*#/ { print; next }
        seen[$0] { next }
        { print }
    ' <(printf '%s\n' "$body") "$file"
}

# Compose the managed `.gitignore` body and write it to <output_path> with
# PC-2 crash-safe semantics (atomic `.tmp` → `.prev` → `mv`), preserving
# user-authored content above and below the managed section.
#
#   - File with managed markers: content above the start marker and below the
#     end marker is preserved verbatim.
#   - Legacy file (no markers): existing content is carried below the new
#     managed section, minus any lines the managed body already covers (so a
#     `pyve update` migrates the file without losing user ignores or
#     duplicating pyve-managed ones). The prior file is backed up to .prev.
#   - On compose failure, the existing file is left untouched.
#
# Usage: compose_gitignore [<output_path>]   (default: .gitignore)
compose_gitignore() {
    local output_path="${1:-.gitignore}"
    local tmp="${output_path}.tmp"

    local body
    if ! body="$(_compose_gitignore_body)"; then
        log_error "gitignore_composer: compose failed — '$output_path' left unchanged"
        return 1
    fi

    local user_above="" user_below=""
    if [[ -f "$output_path" ]]; then
        if grep -qF "$GITIGNORE_MANAGED_START" "$output_path"; then
            user_above="$(awk -v m="$GITIGNORE_MANAGED_START" '$0==m{exit} {print}' "$output_path")"
            user_below="$(awk -v m="$GITIGNORE_MANAGED_END" 'f{print} $0==m{f=1}' "$output_path")"
        else
            # Legacy file: carry its content below, minus managed duplicates.
            user_below="$(_gitignore_filter_managed_dups "$output_path" "$body")"
        fi
    fi

    if ! {
        [[ -n "$user_above" ]] && printf '%s\n' "$user_above"
        printf '%s\n' "$body"
        [[ -n "$user_below" ]] && printf '%s\n' "$user_below"
        true
    } > "$tmp"; then
        log_error "gitignore_composer: failed to write '$tmp' — '$output_path' left unchanged"
        rm -f "$tmp"
        return 1
    fi

    if [[ -f "$output_path" ]]; then
        cp -p "$output_path" "${output_path}.prev"
    fi
    mv -f "$tmp" "$output_path"
}

# Init/update entry point (mirrors compose_project_envrc, N.ae.5): reload the
# manifest + plugin registry from the on-disk pyve.toml, THEN compose
# `.gitignore`. Required because main() loaded the manifest before the
# subcommand wrote/updated it.
compose_project_gitignore() {
    local output_path="${1:-.gitignore}"
    manifest_load >/dev/null 2>&1 || true
    plugin_registry_reset
    if ! plugin_load_all_from_manifest; then
        log_error "gitignore_composer: could not load plugins from pyve.toml"
        return 1
    fi
    compose_gitignore "$output_path"
}
