# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/staleness.sh — best-effort latest-version lookups for the hosted
# tools (project-guide) and pyve itself, surfaced as INFO-ONLY lines in
# `pyve check`'s [pyve] section.
#
# Pyve's first network touchpoint, built to the integration-spike record
# (P-2 plan §8.3). The hard constraints:
#   - a network failure can NEVER change `check`'s exit code — every
#     failure degrades to an empty string and the hint simply does not
#     render (staleness is information, never a verdict);
#   - bounded wall-time — curl with connect/total timeouts (a blackholed
#     host costs ~2s, a slow-drip server at most the total timeout);
#   - silent — no stderr noise on any failure class (the 2>/dev/null is
#     load-bearing: `-s` alone still emits error text);
#   - the probe runs only for interactive human runs: suppressed by
#     --offline / PYVE_NO_NETWORK=1, by the CI env var, and by a
#     non-interactive stdout — so scripted, piped, CI, and test runs are
#     offline by construction. A fresh cache also suppresses the fetch
#     (reading the cache is offline and allowed everywhere).
#
# Sources (spike-verified):
#   project-guide → https://pypi.org/pypi/project-guide/json ("version"
#     in the leading "info" object; grep/cut, no jq dependency).
#   pyve → the raw Homebrew-tap formula (refs/tags/v<ver> in its url
#     line). The GitHub releases API is deliberately NOT used: Releases
#     stopped being cut after v1.13.3 (the workflow moved to tags on
#     branches merged to main), and the API burns the 60/hr anonymous
#     rate limit; the raw formula is CDN-served and current.
#
# Cache: one single-line version file per tool at
# ${XDG_CACHE_HOME:-~/.cache}/pyve/latest/<tool>; freshness by file
# mtime, TTL 24h (PYVE_STALENESS_TTL_MINUTES overrides — a test seam).
# A failed fetch never overwrites a cached value; an expired cache while
# offline means no hint, silently.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

pyve_latest_cache_dir() {
    printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/pyve/latest"
}

# Interactivity seam: hints are for humans reading a terminal. Tests
# stub this open; every piped/scripted consumer stays offline.
_staleness_interactive() { [[ -t 1 ]]; }

# True (0) when the network probe must not run. The cache may still be
# read — suppression gates the FETCH, not the hint.
_staleness_suppressed() {
    [[ "${PYVE_NO_NETWORK:-0}" == "1" ]] && return 0
    [[ -n "${CI:-}" ]] && return 0
    ! _staleness_interactive
}

# The spike-proven fetch shape: bounded, silent, empty-on-any-failure,
# pipeline rc always 0. Tests stub this seam.
_staleness_fetch() {
    command -v curl >/dev/null 2>&1 || return 0
    curl -fsSL --connect-timeout 2 --max-time 5 "$1" 2>/dev/null || true
}

# Numeric dotted-version compare: returns 0 when <a> is strictly newer
# than <b>. Field-wise numeric (never lexicographic — 3.10 > 3.9);
# non-numeric suffixes are ignored; missing fields read as 0.
_staleness_ver_gt() {
    local IFS=.
    # shellcheck disable=SC2206 # word-splitting on IFS=. is the parse
    local a=($1) b=($2)
    local i x y
    for i in 0 1 2; do
        x="${a[i]:-0}"; y="${b[i]:-0}"
        x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
        x="${x:-0}"; y="${y:-0}"
        if (( x > y )); then return 0; fi
        if (( x < y )); then return 1; fi
    done
    return 1
}

# Latest known version of <tool> (project-guide | pyve): the unexpired
# cache when present, else a live fetch (unless suppressed) that renews
# the cache. Empty output on any failure — callers render nothing.
staleness_latest() {
    local tool="$1"
    local dir file ttl
    dir="$(pyve_latest_cache_dir)"
    file="$dir/$tool"
    ttl="${PYVE_STALENESS_TTL_MINUTES:-1440}"
    # ttl <= 0 = always stale, checked explicitly — `find -mmin -0` is
    # not portable (BSD/GNU disagree on whether the current minute hits).
    if [[ "$ttl" -gt 0 && -f "$file" && -n "$(find "$file" -mmin "-$ttl" 2>/dev/null)" ]]; then
        cat "$file"
        return 0
    fi
    _staleness_suppressed && return 0
    local latest=""
    case "$tool" in
        project-guide)
            latest="$(_staleness_fetch 'https://pypi.org/pypi/project-guide/json' \
                | grep -o '"version":[[:space:]]*"[^"]*"' | head -n1 | cut -d'"' -f4)"
            ;;
        pyve)
            latest="$(_staleness_fetch 'https://raw.githubusercontent.com/pointmatic/homebrew-tap/main/Formula/pyve.rb' \
                | grep -o 'refs/tags/v[0-9][0-9.]*' | head -n1)"
            latest="${latest#refs/tags/v}"
            latest="${latest%.}"
            ;;
        *)
            return 0
            ;;
    esac
    [[ -n "$latest" ]] || return 0
    mkdir -p "$dir" 2>/dev/null || { printf '%s' "$latest"; return 0; }
    printf '%s' "$latest" > "$file" 2>/dev/null || true
    printf '%s' "$latest"
}

# Emit the staleness hint lines for the [pyve] check section. INFO-ONLY
# by contract: always returns 0, prints nothing when everything is
# current, unknown, or someone else's department (a project-managed
# project-guide). Remediation routes on the install source.
staleness_hint_lines() {
    declare -F pyve_toolchain_venv_dir >/dev/null 2>&1 || return 0

    # project-guide: only when pyve hosts it (and the project does not
    # manage it via a deps source).
    local src=""
    if declare -F project_guide_deps_source >/dev/null 2>&1; then
        src="$(project_guide_deps_source 2>/dev/null || true)"
    fi
    if [[ -z "$src" ]]; then
        local pg cur latest
        pg="$(pyve_toolchain_venv_dir)/bin/project-guide"
        if [[ -x "$pg" ]] && cur="$(pyve_runnable_version "$pg" 2>/dev/null)" && [[ -n "$cur" ]]; then
            latest="$(staleness_latest project-guide)"
            if [[ -n "$latest" ]] && _staleness_ver_gt "$latest" "$cur"; then
                printf 'project-guide %s is available (installed: %s)\n' "$latest" "$cur"
                printf "  Upgrade: 'pyve self provision'\n"
            fi
        fi
    fi

    # pyve itself, against the running $VERSION.
    local cur_pyve="${VERSION:-}" latest_pyve
    if [[ -n "$cur_pyve" ]]; then
        latest_pyve="$(staleness_latest pyve)"
        if [[ -n "$latest_pyve" ]] && _staleness_ver_gt "$latest_pyve" "$cur_pyve"; then
            printf 'pyve %s is available (installed: %s)\n' "$latest_pyve" "$cur_pyve"
            case "$(detect_install_source 2>/dev/null || true)" in
                homebrew)
                    printf "  Upgrade: 'brew upgrade pointmatic/tap/pyve'\n" ;;
                *)
                    printf "  Upgrade: 'git pull && pyve self install' (from your clone)\n" ;;
            esac
        fi
    fi
    return 0
}
