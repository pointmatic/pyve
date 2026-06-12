# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve testenv — manage a dedicated dev/test runner environment
#
# Single-file namespace command (project-essentials F-9): one file
# contains the namespace dispatcher (`env_command`) and every
# leaf (`env_init`, `env_purge`, `env_run`) plus the
# backend-keyed install helpers (`_env_install_venv`,
# `_env_install_conda`).
#
# Sub-commands:
#   pyve testenv init                    Create .pyve/envs/testenv/venv
#   pyve testenv install [-r <file>]     Install pytest (or -r reqs)
#   pyve testenv purge                   Remove .pyve/testenv
#   pyve testenv run <cmd> [args...]     exec a command inside testenv
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Path to the env-spec projection helper. Resolves relative to this file
# (lib/commands/env.sh → lib/pyve_env_spec_helper.py), mirroring
# _PYVE_MANIFEST_HELPER in lib/manifest.sh.
_PYVE_ENV_SPEC_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pyve_env_spec_helper.py"

# the `pyve env sync` engine (diff + tomlkit apply). Same
# directory-relative resolution as the spec helper above.
_PYVE_ENV_SYNC_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pyve_env_sync_helper.py"

#------------------------------------------------------------
# read §4.0 of the env-dependencies doc via the Pyve
# toolchain interpreter and print the projected JSON on stdout. The seam
# `pyve env sync` (N.az.2) builds on.
#
# Resolves the interpreter via pyve_toolchain_python (per the toolchain-
# python essential), with the self-sufficient `|| ${PYVE_PYTHON:-python}`
# fallback for piecemeal test subshells. PyYAML is a hard dependency of the
# helper; we pre-check it so the failure is a precise "run pyve self
# install" (exit 3) rather than a raw ImportError — distinct from the
# helper's doc-not-found (2) / no-block (4) / parse-error (5) codes.
#
# Usage: _env_read_spec_json <doc_path>   (prints JSON; returns helper rc)
#------------------------------------------------------------
_env_read_spec_json() {
    local doc_path="$1"
    if declare -F pyve_toolchain_has_pyyaml >/dev/null 2>&1 \
        && ! pyve_toolchain_has_pyyaml; then
        printf "error: PyYAML is not available in Pyve's toolchain — run 'pyve self install'.\n" >&2
        return 3
    fi
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    "$py" "$_PYVE_ENV_SPEC_HELPER" "$doc_path"
}

#------------------------------------------------------------
# Leaf: pyve testenv init [<name>]
#
# Story M.i.2: accepts an optional <name>. No arg defaults to the
# reserved `testenv`. Validation gates (M.i.1) live in the dispatcher
# so all leaves share one check; `env_init` just creates.
#------------------------------------------------------------

env_init() {
    local name="${1:-testenv}"
    ensure_env_exists "$name"
}

#------------------------------------------------------------
# Story M.l: venv-backed install with source dispatch.
#
# Renamed from `env_install` for symmetry with M.k's
# `_env_install_conda`. Pre-condition: the venv must already
# exist at `<env_path>`. Dispatches on the highest-precedence
# install source available (1 = top precedence):
#
#   1. CLI `-r <file>` (today's explicit-override behavior).
#   2. Declared `[env.<name>].requirements = ["a","b",...]` in pyve.toml
#      → `pip install -r a -r b ...`.
#   3. Declared `[env.<name>].extra = "<extra>"` in pyve.toml
#      → resolve `[project.optional-dependencies].<extra>` via the
#      Python helper, `pip install <pkg1> <pkg2> ...`.
#   4. Auto-detected `requirements-dev.txt` in CWD → `pip install -r requirements-dev.txt`.
#   5. Bare `pytest` fallback (pre-M.l default).
#
# Mutex enforcement (`requirements ⊕ extra ⊕ manifest`) lives in the
# M.g Python helper at config-read time, so by the time we get here
# at most one of (2) and (3) is non-empty.
#------------------------------------------------------------

_env_install_venv() {
    local name="$1"
    local env_path="$2"
    local cli_req_file="$3"

    if [[ ! -x "$env_path/bin/python" ]]; then
        log_error "Dev/test runner environment not initialized"
        log_error "Run: pyve env init $name"
        exit 1
    fi
    info "Installing dev/test dependencies into '$env_path'..."

    # Precedence 1: CLI `-r <file>` always wins.
    if [[ -n "$cli_req_file" ]]; then
        if [[ ! -f "$cli_req_file" ]]; then
            log_error "Requirements file not found: $cli_req_file"
            exit 1
        fi
        run_cmd "$env_path/bin/python" -m pip install -r "$cli_req_file"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 2: declared `requirements = [...]`.
    local -a declared_reqs=()
    _env_requirements_of "$name" declared_reqs 2>/dev/null || true
    if [[ "${#declared_reqs[@]}" -gt 0 ]]; then
        local r
        local -a r_args=()
        for r in "${declared_reqs[@]}"; do
            if [[ ! -f "$r" ]]; then
                log_error "Declared requirements file not found: $r"
                log_error "(declared as [env.$name].requirements in pyve.toml)"
                exit 1
            fi
            r_args+=("-r" "$r")
        done
        run_cmd "$env_path/bin/python" -m pip install "${r_args[@]}"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 3: declared `extra = "<name>"`.
    local declared_extra
    declared_extra="$(_env_extra_of "$name" 2>/dev/null || printf '')"
    if [[ -n "$declared_extra" ]]; then
        local -a pkgs=()
        if ! _env_resolve_extra_packages "$declared_extra" pkgs; then
            exit 1
        fi
        if [[ "${#pkgs[@]}" -eq 0 ]]; then
            info "Extra '$declared_extra' has no packages — skipping install"
            return 0
        fi
        run_cmd "$env_path/bin/python" -m pip install "${pkgs[@]}"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 4: auto-detect requirements-dev.txt.
    if [[ -f "requirements-dev.txt" ]]; then
        run_cmd "$env_path/bin/python" -m pip install -r "requirements-dev.txt"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 5: bare pytest fallback.
    run_cmd "$env_path/bin/python" -m pip install pytest
    success "Dev/test dependencies installed"
}

# Story M.l: invoke the Python helper's `--resolve-extra` mode to
# expand a declared `extra = "<name>"` into a concrete package list.
# Populates the caller-named array `<out_var>`. Returns non-zero
# (with helper's stderr already on the terminal) when the extra is
# not declared in `[project.optional-dependencies]` or pyproject.toml
# is missing.
_env_resolve_extra_packages() {
    local extra_name="$1"
    local out_var="$2"
    # Pyve toolchain python — see lib/manifest.sh's note
    # (incl. the self-sufficient fallback + the `local` split rationale).
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    local pyproject="${PYVE_PYPROJECT:-pyproject.toml}"
    local pkg_lines rc=0
    pkg_lines="$("$py" "$_PYVE_TESTENVS_HELPER" --resolve-extra "$pyproject" "$extra_name")" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        return "$rc"
    fi
    eval "$out_var=()"
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        eval "$out_var+=(\"\$line\")"
    done <<< "$pkg_lines"
    return 0
}

#------------------------------------------------------------
# Story M.p — date helpers (epoch ↔ ISO date, cross-platform).
#
# macOS ships BSD date (`date -r <epoch>`, `date -j -f`); Linux ships
# GNU date (`date -d @<epoch>`, `date -d <iso>`). Probe via `uname` per
# the existing micromamba_env.sh pattern.
#------------------------------------------------------------

_env_format_epoch() {
    local epoch="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -r "$epoch" '+%Y-%m-%d' 2>/dev/null || printf '?'
    else
        date -d "@$epoch" '+%Y-%m-%d' 2>/dev/null || printf '?'
    fi
}

# Print the epoch for the given ISO date (YYYY-MM-DD). Return 1 + no
# output if the input is not in that exact shape or `date` rejects it.
_env_parse_iso_date() {
    local iso="$1"
    [[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
    if [[ "$(uname)" == "Darwin" ]]; then
        date -j -f '%Y-%m-%d' "$iso" '+%s' 2>/dev/null || return 1
    else
        date -d "$iso" '+%s' 2>/dev/null || return 1
    fi
}

#------------------------------------------------------------
# Story M.p — `testenv list` / `testenv prune`.
#
# `env_list`: walk the union of declared (PYVE_TESTENVS_NAMES) and
# on-disk (`.pyve/envs/*/`) env names; for each, print one row
# with name/backend/size/last-used/state.
#
# `env_prune`: three modes:
#   default (no args)       — remove on-disk envs not declared in
#                              pyproject (orphans). Reserved `testenv`
#                              is never orphaned.
#   --unused-since <ISO>    — remove on-disk envs whose `.state`'s
#                              last_used_at is strictly older than
#                              the given date. last_used=0 ("never")
#                              is preserved so freshly-provisioned envs
#                              are not eaten.
#   --all                   — remove every on-disk env (declared and
#                              orphaned alike). Disk-driven; distinct
#                              from `testenv purge` no-arg, which is
#                              config-driven (iterates
#                              PYVE_TESTENVS_NAMES).
# Confirmation gating mirrors M.i.4's `purge` semantics: `--force`
# skips; non-TTY (CI) skips; `PYVE_FORCE_PROMPT=1` forces.
#------------------------------------------------------------

# Print the union of declared + on-disk env names, one per line.
# Bash-3.2-safe dedup via string-membership (no `declare -A`).
_env_list_all_names() {
    local name seen=" "
    for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        if [[ "$seen" != *" $name "* ]]; then
            printf '%s\n' "$name"
            seen+="$name "
        fi
    done
    if [[ -d ".pyve/envs" ]]; then
        local d
        for d in .pyve/envs/*/; do
            [[ -d "$d" ]] || continue
            name="$(basename "$d")"
            if [[ "$seen" != *" $name "* ]]; then
                printf '%s\n' "$name"
                seen+="$name "
            fi
        done
    fi
}

# Print a single env's row.
_env_list_one_row() {
    local name="$1"
    local backend size last_used state
    local on_disk=0
    [[ -d ".pyve/envs/$name" ]] && on_disk=1

    if is_env_declared "$name"; then
        backend="$(_env_resolve_backend "$name" 2>/dev/null || printf 'venv')"
    elif [[ -d ".pyve/envs/$name/conda" ]]; then
        backend="micromamba"
    elif [[ -d ".pyve/envs/$name/venv" ]]; then
        backend="venv"
    else
        backend="?"
    fi

    if [[ "$on_disk" == "1" ]]; then
        size="$(du -sh ".pyve/envs/$name" 2>/dev/null | awk '{print $1}')"
        [[ -z "$size" ]] && size="?"
    else
        size="--"
    fi

    if state_read "$name" 2>/dev/null; then
        if [[ "$PYVE_TESTENV_STATE_LAST_USED_AT" == "0" ]]; then
            last_used="never"
        else
            last_used="$(_env_format_epoch "$PYVE_TESTENV_STATE_LAST_USED_AT")"
        fi
    else
        last_used="--"
    fi

    if is_env_declared "$name"; then
        if [[ "$on_disk" == "1" ]]; then
            state="ready"
        elif is_env_lazy "$name"; then
            state="lazy"
        else
            state="not provisioned"
        fi
    else
        state="orphaned"
    fi

    printf '%-12s %-12s %-8s %-12s %s\n' "$name" "$backend" "$size" "$last_used" "$state"
}

env_list() {
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi
    printf '%-12s %-12s %-8s %-12s %s\n' NAME BACKEND SIZE LAST-USED STATE
    local name
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        _env_list_one_row "$name"
    done < <(_env_list_all_names)
}

env_prune() {
    local mode="orphan"
    local cutoff_date=""
    local force=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unused-since)
                mode="unused-since"
                if [[ -z "${2:-}" ]]; then
                    log_error "--unused-since requires a date (YYYY-MM-DD)"
                    exit 1
                fi
                cutoff_date="$2"
                shift 2
                ;;
            --all)
                mode="all"
                shift
                ;;
            --force)
                force=1
                shift
                ;;
            *)
                log_error "Unknown prune flag: $1"
                log_error "Usage: pyve testenv prune [--unused-since <YYYY-MM-DD>] [--all] [--force]"
                exit 1
                ;;
        esac
    done

    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi

    # Pre-loop arg validation.
    local cutoff_epoch=""
    if [[ "$mode" == "unused-since" ]]; then
        if ! cutoff_epoch="$(_env_parse_iso_date "$cutoff_date")"; then
            log_error "Invalid date '$cutoff_date' (expected YYYY-MM-DD)"
            exit 1
        fi
    fi

    if [[ ! -d ".pyve/envs" ]]; then
        case "$mode" in
            orphan)        info "No orphaned testenvs to prune." ;;
            all)           info "No testenvs on disk to prune." ;;
            unused-since)  info "No testenvs unused since $cutoff_date — nothing to prune." ;;
        esac
        return 0
    fi

    # Walk on-disk envs and collect candidates per mode.
    local -a candidates=()
    local d name
    for d in .pyve/envs/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        case "$mode" in
            orphan)
                # Skip declared + the reserved 'testenv' (always implicit).
                if is_env_declared "$name" || [[ "$name" == "testenv" ]]; then
                    continue
                fi
                candidates+=("$name")
                ;;
            all)
                candidates+=("$name")
                ;;
            unused-since)
                if ! state_read "$name" 2>/dev/null; then
                    # No .state → safer to skip than to remove blindly.
                    continue
                fi
                if [[ "$PYVE_TESTENV_STATE_LAST_USED_AT" == "0" ]]; then
                    # Never used → preserve (don't eat freshly-provisioned envs).
                    continue
                fi
                if [[ "$PYVE_TESTENV_STATE_LAST_USED_AT" -lt "$cutoff_epoch" ]]; then
                    candidates+=("$name")
                fi
                ;;
        esac
    done

    if [[ "${#candidates[@]}" -eq 0 ]]; then
        case "$mode" in
            orphan)        info "No orphaned testenvs to prune." ;;
            all)           info "No testenvs on disk to prune." ;;
            unused-since)  info "No testenvs unused since $cutoff_date — nothing to prune." ;;
        esac
        return 0
    fi

    # Confirm — same TTY/--force semantics as M.i.4.
    local should_prompt=0
    if [[ "$force" != "1" ]]; then
        if [[ "${PYVE_FORCE_PROMPT:-0}" == "1" ]] || [[ -t 0 ]]; then
            should_prompt=1
        fi
    fi
    if [[ "$should_prompt" == "1" ]]; then
        printf "Remove %d testenv(s): %s? [y/N]: " "${#candidates[@]}" "${candidates[*]}"
        local response
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Aborted; no testenvs were removed."
            return 0
        fi
    fi

    local rc=0
    for name in "${candidates[@]}"; do
        if ! purge_env_dir "$name"; then
            warn "Failed to remove '$name' (continuing)"
            rc=1
        fi
    done
    return "$rc"
}

#------------------------------------------------------------
# Leaf: pyve testenv purge [<name>]
#
# Story M.i.4: accepts an optional <name>. With-arg removes that env;
# no-arg falls through to the dispatcher's iteration helper.
# Conda-backed envs are also purged (rm -rf is backend-agnostic).
#------------------------------------------------------------

env_purge() {
    local name="${1:-testenv}"
    purge_env_dir "$name"
}

#------------------------------------------------------------
# Leaf: pyve testenv run <command> [args...]
#
# `exec`s into the target command. The dispatcher emits no header/
# footer because exec replaces the shell — the called command owns
# the rest of the terminal.
#------------------------------------------------------------

env_run() {
    local testenv_venv="$1"
    shift

    if [[ $# -lt 1 ]]; then
        log_error "No command provided"
        log_error "Usage: pyve env run <command> [args...]"
        log_error "Example: pyve env run ruff check ."
        exit 1
    fi
    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        log_error "Dev/test runner environment not initialized"
        log_error "Run: pyve env init"
        exit 1
    fi
    local cmd="$1"
    shift
    local testenv_bin="$testenv_venv/bin"
    local cmd_path="$testenv_bin/$cmd"
    if [[ -x "$cmd_path" ]]; then
        exec "$cmd_path" "$@"
    fi
    export VIRTUAL_ENV="$PWD/$testenv_venv"
    export PATH="$testenv_bin:$PATH"
    exec "$cmd" "$@"
}

#------------------------------------------------------------
# pyve env sync
#
# Discover the project-guide env-dependencies spec (§4.0, via N.ay's
# project_guide_env_spec_path), diff it against the current pyve.toml (the
# baseline — there is no separate state), present the changes, and on
# confirm reconcile pyve.toml via the tomlkit writer (N.az.2 helper).
#
# Writes config ONLY — it never materializes an env. Run `pyve env install`
# afterward to provision new/changed environments.
#
# Validation is PERMISSIVE here (the helper accepts any value). Closed-set
# vocabulary enforcement is F6/N.ba — do not add it in this leaf.
#
# Flags:
#   --dry-run / -n   show the diff and exit; never write.
#   --yes / -y       apply non-destructive changes without prompting.
#   --force / -f     also apply destructive changes (drops / backend flips).
#
# Confirm semantics (interactive TTY, or PYVE_FORCE_PROMPT=1):
#   non-destructive → [Y/n] default Y
#   destructive     → [y/N] default N
# Non-interactive (CI): the default verdict applies directly — non-
# destructive proceeds, destructive declines (unless --force).
#------------------------------------------------------------

# Run the sync engine under Pyve's TOOLCHAIN interpreter (per the toolchain-
# python essential), with the self-sufficient fallback for piecemeal test
# subshells. Args are the helper's own (`diff --human <spec> <toml>`, etc.).
_env_sync_run_helper() {
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    "$py" "$_PYVE_ENV_SYNC_HELPER" "$@"
}

# Confirm with an explicit default ($1 = y|n; $2 = prompt). Prompts only on a
# TTY or when PYVE_FORCE_PROMPT=1; otherwise returns the default verdict so
# CI never blocks. Empty input takes the default. Mirrors the TTY-gating in
# _env_purge_all_with_confirm.
_env_sync_confirm() {
    local default="$1" prompt="$2" response
    if [[ "${PYVE_FORCE_PROMPT:-0}" != "1" ]] && [[ ! -t 0 ]]; then
        [[ "$default" == "y" ]]
        return
    fi
    local hint="[y/N]"
    [[ "$default" == "y" ]] && hint="[Y/n]"
    printf "%s %s: " "$prompt" "$hint"
    read -r response || response=""
    [[ -z "$response" ]] && response="$default"
    [[ "$response" =~ ^[Yy]$ ]]
}

env_sync() {
    local dry_run=0 assume_yes=0 force=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n) dry_run=1; shift ;;
            --yes|-y)     assume_yes=1; shift ;;
            --force|-f)   force=1; shift ;;
            *) log_error "env sync: unexpected argument '$1'"; return 1 ;;
        esac
    done

    local spec_path
    spec_path="$(project_guide_env_spec_path)"

    # Compute the diff (human render + verdict exit code), capturing both.
    local out rc=0
    out="$(_env_sync_run_helper diff --human "$spec_path" pyve.toml 2>&1)" || rc=$?

    case "$rc" in
        0)
            printf '%s\n' "$out"
            return 0
            ;;
        2)
            info "No env-dependencies spec found at '$spec_path' — nothing to sync."
            return 0
            ;;
        3)
            log_error "PyYAML/tomlkit unavailable in Pyve's toolchain — run 'pyve self install'."
            return 3
            ;;
        4)
            log_error "Env spec '$spec_path' has no §4.0 machine-readable block — nothing to sync."
            return 1
            ;;
        6)
            # F6/N.ba.2: the spec carries an unknown value or unrecognized
            # field. Surface the helper's precise per-env errors; pyve.toml is
            # left untouched.
            log_error "Env spec '$spec_path' has invalid values — pyve.toml not changed. Fix the spec:"
            printf '%s\n' "$out" >&2
            return 1
            ;;
        10|11) ;;  # changes present — fall through to present + confirm
        *)
            log_error "Could not read env spec '$spec_path'."
            printf '%s\n' "$out" >&2
            return 1
            ;;
    esac

    # Changes present (rc 10 non-destructive / 11 destructive). Show the diff.
    printf '%s\n' "$out"

    if [[ "$dry_run" == "1" ]]; then
        info "Dry run — pyve.toml not modified."
        return 0
    fi

    local do_apply=0
    if [[ "$rc" == "11" ]]; then
        if [[ "$force" == "1" ]]; then
            do_apply=1
        elif _env_sync_confirm n "Apply these changes (includes destructive drops/rebuilds)?"; then
            do_apply=1
        fi
    else
        if [[ "$assume_yes" == "1" || "$force" == "1" ]]; then
            do_apply=1
        elif _env_sync_confirm y "Apply these changes to pyve.toml?"; then
            do_apply=1
        fi
    fi

    if [[ "$do_apply" != "1" ]]; then
        info "No changes applied to pyve.toml."
        return 0
    fi

    if _env_sync_run_helper apply "$spec_path" pyve.toml; then
        success "Updated pyve.toml from the env spec."
        info "Run 'pyve env install' to materialize new or changed environments."
        return 0
    fi
    log_error "Failed to apply env-spec changes to pyve.toml."
    return 1
}

#------------------------------------------------------------
# Story M.j: per-env install lock
#
# `mkdir`-based atomic lock at `.pyve/envs/<name>/.lock/`. The
# holding pid is written to `.lock/pid` so a waiting process can name
# who holds the lock. `flock(1)` is not on macOS by default — `mkdir`
# covers the same surface (atomic acquire, serialized wait, fast-fail
# on collision) with zero external-binary dependencies.
#
# Acquire is wait-by-default (1s sleep+retry, 10-minute cap). The
# `no-wait` mode fast-fails with a "(pid N)" message on collision.
# Stale-lock reclamation: if the holding pid no longer exists
# (`kill -0` fails), the lock dir is removed and re-acquired.
#
# Release only removes the lock dir when the caller is the recorded
# holder ($$ == pid file contents) so a stray release call cannot
# blow away another process's in-progress install.
#------------------------------------------------------------

_env_install_lock_dir() {
    printf '%s' ".pyve/envs/$1/.lock"
}

_env_acquire_install_lock() {
    local name="$1"
    local mode="${2:-wait}"
    local lock_dir
    lock_dir="$(_env_install_lock_dir "$name")"
    mkdir -p "$(dirname "$lock_dir")"

    local waited=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
        local holder_pid="?"
        if [[ -f "$lock_dir/pid" ]]; then
            holder_pid="$(cat "$lock_dir/pid" 2>/dev/null || printf '?')"
        fi

        # Stale-lock reclamation: holder pid no longer exists.
        if [[ "$holder_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
            warn "Stale install lock for '$name' (pid $holder_pid no longer exists); reclaiming."
            rm -rf "$lock_dir"
            continue
        fi

        if [[ "$mode" == "no-wait" ]]; then
            log_error "another pyve process is installing '$name' (pid $holder_pid)"
            return 1
        fi

        if [[ "$waited" -eq 0 ]]; then
            info "Waiting for install lock on '$name' (held by pid $holder_pid)..."
        fi
        sleep 1
        waited=$((waited + 1))
        if [[ "$waited" -gt 600 ]]; then
            log_error "timed out waiting for install lock on '$name' (held by pid $holder_pid)"
            return 1
        fi
    done

    printf '%s\n' "$$" > "$lock_dir/pid"
    return 0
}

_env_release_install_lock() {
    local name="$1"
    local lock_dir
    lock_dir="$(_env_install_lock_dir "$name")"
    if [[ -d "$lock_dir" && -f "$lock_dir/pid" ]]; then
        local holder
        holder="$(cat "$lock_dir/pid" 2>/dev/null || printf '')"
        if [[ "$holder" == "$$" ]]; then
            rm -rf "$lock_dir"
        fi
    fi
}

# Wraps a testenv install with acquire/release. A `trap` covers the
# `exit 1` paths inside the install helpers (existence checks, missing
# requirements file) and SIGINT/SIGTERM so the lock dir never strands
# the env. Story M.k: dispatches on the resolved backend so a
# conda-backed env goes through `_env_install_conda` (manifest-
# driven sync); Story M.l: venv backend goes through
# `_env_install_venv` (renamed from `env_install`), which
# itself dispatches on declared sources (`requirements`/`extra`/
# auto-detect/bare-pytest).
# Story N.bf.20: backend-aware "is this env materialized on disk?" check.
# Used to gate `_env_install_with_lock` BEFORE it acquires the install lock
# (whose `mkdir -p .pyve/envs/<name>` would otherwise leave a stray on a
# doomed install). venv: an executable interpreter; micromamba: conda-meta/.
_env_is_initialized() {
    local env_path="$1" backend="$2"
    if [[ "$backend" == "micromamba" ]]; then
        [[ -d "$env_path/conda-meta" ]]
    else
        [[ -x "$env_path/bin/python" ]]
    fi
}

_env_install_with_lock() {
    local name="$1" env_path="$2" req_file="$3" lock_mode="${4:-wait}"
    local backend
    backend="$(_env_resolve_backend "$name")" || backend="venv"
    # a declared env whose backend is known-advisory is
    # recorded but never materialized — skip with the §B no-op advisory
    # (before acquiring the install lock; there is nothing to serialize).
    if _env_backend_is_advisory "$backend"; then
        info "env '$name' declares backend '$backend', which pyve does not yet materialize; provision it manually per the env spec"
        return 0
    fi
    # Story N.bf.20: gate the env-initialized check BEFORE acquiring the
    # install lock — there is nothing to serialize against a non-existent
    # env, and `_env_acquire_install_lock`'s `mkdir -p` would otherwise
    # leave a `.pyve/` stray on an uninitialized project (cf. N.bf.17).
    if ! _env_is_initialized "$env_path" "$backend"; then
        if [[ "$backend" == "micromamba" ]]; then
            log_error "Conda-backed env '$name' is not initialized at '$env_path'"
        else
            log_error "Dev/test runner environment not initialized"
        fi
        log_error "Run: pyve env init $name"
        return 1
    fi
    _env_acquire_install_lock "$name" "$lock_mode" || return $?
    trap "_env_release_install_lock '$name'" EXIT INT TERM
    local rc=0
    if [[ "$backend" == "micromamba" ]]; then
        local manifest
        manifest="$(_env_manifest_of "$name")" || manifest=""
        _env_install_conda "$name" "$env_path" "$manifest" || rc=$?
    else
        _env_install_venv "$name" "$env_path" "$req_file" || rc=$?
    fi
    _env_release_install_lock "$name"
    trap - EXIT INT TERM
    return "$rc"
}

#------------------------------------------------------------
# Story M.k: conda-backed init/install
#
# `_env_init_conda` creates the env from its declared `manifest`
# via `micromamba create -p <path> -f <manifest> -y`. This is conda's
# natural one-shot (create + install packages) — there is no "empty
# env" intermediate state for the conda backend.
#
# `_env_install_conda` syncs an *existing* env to its manifest via
# `micromamba install -p <path> -f <manifest> -y`. If the env does not
# exist, errors with a hint pointing at `pyve testenv init <name>`.
#
# Both require `manifest` to be declared in `[env.<name>]` in pyve.toml
# — the conda backend has no implicit pip-style fallback.
#------------------------------------------------------------

_env_init_conda() {
    local name="$1"
    local env_path="$2"
    local manifest="$3"

    if [[ -z "$manifest" ]]; then
        log_error "conda-backed testenv '$name' requires 'manifest' to be declared in pyve.toml"
        log_error "Add: [env.$name]"
        log_error "     manifest = \"<environment.yml path>\""
        return 1
    fi
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi

    if [[ -d "$env_path/conda-meta" ]]; then
        info "Conda-backed testenv '$name' already exists at '$env_path' — skipping create"
        return 0
    fi

    local micromamba_path
    micromamba_path="$(get_micromamba_path)" || micromamba_path=""
    if [[ -z "$micromamba_path" ]]; then
        log_error "micromamba not found — install it first (\`pyve init --backend micromamba\` bootstraps it)"
        return 1
    fi

    mkdir -p "$(dirname "$env_path")"
    info "Creating conda-backed testenv '$name' from $manifest..."
    if "$micromamba_path" create -p "$env_path" -f "$manifest" -y; then
        success "Created conda-backed testenv '$name'"
        return 0
    fi
    log_error "Failed to create conda-backed testenv '$name'"
    return 1
}

_env_install_conda() {
    local name="$1"
    local env_path="$2"
    local manifest="$3"

    if [[ -z "$manifest" ]]; then
        log_error "conda-backed testenv '$name' requires 'manifest' to be declared in pyve.toml ([env.$name])"
        return 1
    fi
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi
    if [[ ! -d "$env_path/conda-meta" ]]; then
        log_error "Conda-backed testenv '$name' is not initialized at '$env_path'"
        log_error "Run: pyve env init $name"
        return 1
    fi

    local micromamba_path
    micromamba_path="$(get_micromamba_path)" || micromamba_path=""
    if [[ -z "$micromamba_path" ]]; then
        log_error "micromamba not found"
        return 1
    fi

    info "Syncing conda-backed testenv '$name' from $manifest..."
    if "$micromamba_path" install -p "$env_path" -f "$manifest" -y; then
        success "Synced conda-backed testenv '$name'"
        return 0
    fi
    log_error "Failed to sync conda-backed testenv '$name'"
    return 1
}

#------------------------------------------------------------
# Story M.i.3: iterate `testenv install` over every non-lazy declared
# env. Returns the first install failure's status.
#
# Reads PYVE_TESTENVS_NAMES populated by read_env_config — caller
# must have loaded config (env_command does this in M.i.2).
#
# Story M.j: takes a `lock_mode` second arg (`wait` | `no-wait`) so
# the iteration honors `--no-wait` from the caller.
#
# Story M.k: conda-backed envs are no longer skipped — backend dispatch
# happens inside `_env_install_with_lock`, which calls
# `_env_install_conda` for `micromamba` (and `inherit` resolving
# to micromamba) and `env_install` for venv.
#------------------------------------------------------------

_env_install_all_nonlazy() {
    local requirements_file="$1"
    local lock_mode="${2:-wait}"
    local name installed_count=0 rc=0
    for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        if is_env_lazy "$name"; then
            continue
        fi
        info "Installing '$name'..."
        local install_env_path
        install_env_path="$(resolve_env_path "$name")"
        _env_install_with_lock "$name" "$install_env_path" "$requirements_file" "$lock_mode" || rc=$?
        installed_count=$((installed_count + 1))
    done
    if [[ "$installed_count" -eq 0 ]]; then
        info "No non-lazy testenvs to install."
    fi
    return "$rc"
}

#------------------------------------------------------------
# Story M.i.4: iterate `testenv purge` over every declared env.
# Confirmation gate: prompt `y/N` only on an interactive stdin AND
# when --force is absent. CI / scripted invocations (non-TTY) skip
# the prompt and proceed — matches `pyve init`'s prompt pattern so
# `pyve testenv purge` stays scriptable. PYVE_FORCE_PROMPT=1 forces
# the prompt even on non-TTY stdin (used by the bats test that
# simulates the confirmation flow).
#
# Per-env failures are surfaced via warn() but do not halt the
# iteration — `rc` accumulates the worst exit code seen.
#------------------------------------------------------------

_env_purge_all_with_confirm() {
    local force="$1"
    local count="${#PYVE_TESTENVS_NAMES[@]}"
    if [[ "$count" -eq 0 ]]; then
        info "No declared testenvs to purge."
        return 0
    fi

    # Decide whether to prompt.
    local should_prompt=0
    if [[ "$force" != "1" ]]; then
        if [[ "${PYVE_FORCE_PROMPT:-0}" == "1" ]] || [[ -t 0 ]]; then
            should_prompt=1
        fi
    fi

    if [[ "$should_prompt" == "1" ]]; then
        printf "Remove all %d dev/test runner environment%s? [y/N]: " \
            "$count" "$([ "$count" -ne 1 ] && echo s)"
        local response
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Aborted; no testenvs were removed."
            return 0
        fi
    fi

    local name rc=0
    for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        if ! purge_env_dir "$name"; then
            warn "Failed to purge '$name' (continuing)"
            rc=1
        fi
    done
    return "$rc"
}

#------------------------------------------------------------
# Namespace dispatcher: pyve testenv <subcommand>
#
# Function-name note: this function is named `env_command` per
# the project-essentials "Function naming convention: verb_<operand>"
# rule — for namespace dispatchers the operand is the sub-command
# name that follows.
#------------------------------------------------------------

env_command() {
    local action=""
    local action_name=""           # Story M.i.2: optional positional <name>
    local requirements_file=""
    local purge_force=0            # Story M.i.4: --force skips the confirm prompt
    local install_no_wait=0        # Story M.j: --no-wait fast-fails on lock collision
    local -a prune_args=()         # Story M.p: prune flags forwarded to env_prune
    local -a sync_args=()          # sync flags forwarded to env_sync

    while [[ $# -gt 0 ]]; do
        case "$1" in
            # New subcommand grammar (H.d §4.4 D5) — silent.
            init)
                action="init"
                shift
                # Story M.i.2: optional positional <name> after `init`.
                if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
                    action_name="$1"
                    shift
                fi
                ;;
            install)
                action="install"
                shift
                # Story M.i.3: install accepts an optional positional
                # <name> and an optional -r <file>; both may appear in
                # either order. Sub-parse here so the order is flexible
                # without leaking into the rest of the dispatcher.
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        -r|--requirements)
                            if [[ -z "${2:-}" ]]; then
                                log_error "$1 requires a file path"
                                exit 1
                            fi
                            requirements_file="$2"
                            shift 2
                            ;;
                        --no-wait)
                            install_no_wait=1
                            shift
                            ;;
                        -*)
                            # Leave unknown flags to the outer loop
                            # (e.g. --help) so it can produce the
                            # canonical unknown_flag_error.
                            break
                            ;;
                        *)
                            if [[ -n "$action_name" ]]; then
                                log_error "testenv install: unexpected positional '$1' (already named '$action_name')"
                                exit 1
                            fi
                            action_name="$1"
                            shift
                            ;;
                    esac
                done
                ;;
            purge)
                action="purge"
                shift
                # Story M.i.4: sub-parser for optional <name> and --force.
                # Unrecognized flags break back to the outer loop.
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --force)
                            purge_force=1
                            shift
                            ;;
                        -*)
                            break
                            ;;
                        *)
                            if [[ -n "$action_name" ]]; then
                                log_error "testenv purge: unexpected positional '$1' (already named '$action_name')"
                                exit 1
                            fi
                            action_name="$1"
                            shift
                            ;;
                    esac
                done
                ;;
            list)
                action="list"
                shift
                # Story M.p: `list` takes no positional / sub-flag args
                # today. Any leftover args fall through to the outer
                # unknown-flag/unknown-arg arms.
                ;;
            prune)
                action="prune"
                shift
                # Story M.p: sub-parser absorbs flags here. The action
                # leaf consumes them via shell positional preservation
                # using a captured array.
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --unused-since|--all|--force)
                            prune_args+=("$1")
                            shift
                            ;;
                        --unused-since=*)
                            prune_args+=("--unused-since" "${1#--unused-since=}")
                            shift
                            ;;
                        *)
                            # `--unused-since` consumes the next arg in
                            # the leaf; route any remaining positionals
                            # through too so the leaf sees the date.
                            if [[ "${prune_args[*]: -1}" == "--unused-since" ]]; then
                                prune_args+=("$1")
                                shift
                                continue
                            fi
                            log_error "Unknown prune arg: $1"
                            log_error "Usage: pyve testenv prune [--unused-since <YYYY-MM-DD>] [--all] [--force]"
                            exit 1
                            ;;
                    esac
                done
                ;;
            # Story J.d (v2.3.0): Category A legacy flag forms
            # (`testenv --init|--install|--purge`) removed. Falls through
            # to the `-*)` arm below, which produces the standard
            # unknown-flag error.
            -r|--requirements)
                if [[ -z "${2:-}" ]]; then
                    log_error "$1 requires a file path"
                    exit 1
                fi
                requirements_file="$2"
                shift 2
                ;;
            run)
                action="run"
                shift
                break  # Remaining args are the [<name> --] command [args]
                ;;
            sync)
                action="sync"
                shift
                # collect sync flags. Unknown flags break back
                # to the outer loop for the canonical unknown_flag_error.
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --dry-run|-n|--yes|-y|--force|-f)
                            sync_args+=("$1")
                            shift
                            ;;
                        -*)
                            break
                            ;;
                        *)
                            log_error "env sync: unexpected positional '$1'"
                            exit 1
                            ;;
                    esac
                done
                ;;
            --help|-h)
                cat << 'EOF'
pyve env - Manage one or more declared project environments

Usage:
  pyve env init [<name>]
  pyve env install [<name>] [-r requirements-dev.txt] [--no-wait]
  pyve env purge [<name>] [--force]
  pyve env run [<name> --] <command> [args...]
  pyve env list
  pyve env prune [--unused-since <YYYY-MM-DD>] [--all] [--force]
  pyve env sync [--dry-run] [--yes] [--force]

Notes:
  - The legacy spelling `pyve testenv <sub>` is preserved as a Category A
    delegation alias through the v3.x deprecation window (removal in v4.0).
    Every invocation prints a one-shot deprecation warning to stderr.
  - Default `testenv` lives at .pyve/envs/testenv/venv
  - Named environments live at .pyve/envs/<name>/{venv,conda}/
    Declare them in [env.<name>] inside pyve.toml (run `pyve env sync` to
    reconcile the manifest with what's on disk).
  - `install` no-arg iterates over every non-lazy declared env. Conda-backed
    envs are skipped (M.k will provide provisioning). `install <name>` installs
    only into that env.
  - `list` (M.p) prints a table of every env (declared + on-disk):
      NAME / BACKEND / SIZE / LAST-USED / STATE.
    Last-used is from `.state.last_used_at` (M.m); `never` when 0.
    State is one of: ready / lazy / not provisioned / orphaned.
  - `prune` (M.p) removes envs from disk, with confirmation (TTY) or `--force`:
      no args            — remove orphans (on disk but not declared,
                            excluding the reserved `testenv`).
      --unused-since DATE — remove envs whose last-used is strictly older.
                            ISO date YYYY-MM-DD. Envs with last-used=0
                            (never used) are preserved.
      --all              — remove every env on disk (declared + orphaned).
                            Disk-driven; distinct from `env purge` no-arg,
                            which is config-driven.
  - `install` acquires a per-env lock at .pyve/envs/<name>/.lock to
    serialize concurrent installs into the same env. Default is wait+retry;
    `--no-wait` fast-fails with "another pyve process is installing
    '<name>' (pid N)" instead of waiting.
  - `purge` no-arg iterates over every declared env (including lazy and
    conda-backed) and prompts `y/N` on interactive shells; `--force` skips
    the prompt. Non-TTY (CI) invocations skip the prompt automatically.
    `purge <name>` removes only that env's root, no prompt.
  - `run` requires the `--` separator when routing to a named env:
      pyve env run smoke -- pytest -v
    Without `--`, the first positional is the command (today's behavior preserved).
  - `sync` (N.az.2) reconciles pyve.toml with the project-guide
    env-dependencies spec (§4.0): discover → diff → confirm → write. It
    writes config ONLY (run `pyve env install` afterward to materialize).
    Non-destructive changes default to apply ([Y/n]); destructive changes
    (dropping a declared env, flipping a backend) default to skip ([y/N])
    and need `--force`. `--dry-run` shows the diff without writing.
  - `testenv` and `root` are reserved names. `root` is selection-only
    (use `pyve test --env root`), not creatable as an env.
  - The default-env tree is preserved across `pyve init --force` and
    `pyve purge --keep-testenv` (the `--keep-testenv` flag name is unchanged).
EOF
                exit 0
                ;;
            -*)
                unknown_flag_error "env" "$1" \
                    --requirements -r --help
                ;;
            *)
                log_error "Unknown env argument: $1"
                log_error "Usage: pyve env <init|install|purge|run> [options]"
                exit 1
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        log_error "No env action provided"
        log_error "Use: pyve env <init|install|purge|run|list|prune> [...]"
        exit 1
    fi

    # Story M.i.2: load named-env config so `assert_env_*` gates can
    # validate non-default names. The no-pyproject.toml short-circuit
    # (M.i.1) keeps this cheap on bash-only projects.
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi

    # `sync` operates on pyve.toml + the env spec directly —
    # no per-env name/path resolution. Handle it before the path-resolution
    # block below (mirrors `run`'s early dispatch).
    if [[ "$action" == "sync" ]]; then
        header_box "pyve env"
        local sync_rc=0
        env_sync "${sync_args[@]+"${sync_args[@]}"}" || sync_rc=$?
        footer_box "$sync_rc"
        return "$sync_rc"
    fi

    # Story M.i.2: `run` has its own arg shape — parse `[<name> --]
    # <cmd> [args]` from the leftover positional args. The `--`
    # separator is required when routing to a named env (no magic
    # detection of "the first arg is a name" — preserves today's
    # `pyve testenv run ruff check .` semantics).
    if [[ "$action" == "run" ]]; then
        local run_name="testenv"
        if [[ "${1:-}" == "--" ]]; then
            shift
        elif [[ "${2:-}" == "--" ]]; then
            run_name="$1"
            shift 2
        fi
        assert_env_name_actionable "$run_name" || exit 1
        local run_venv run_backend
        run_venv="$(resolve_env_path "$run_name")"
        run_backend="$(_env_resolve_backend "$run_name")" || run_backend="venv"
        # Backend dispatch: venv → PATH activation (env_run); micromamba →
        # `micromamba run -p` (sets CONDA_PREFIX, runs activate.d, fixes lib
        # paths). Both exec, so neither returns on success.
        if [[ "$run_backend" == "micromamba" ]]; then
            env_exec_conda "$run_venv" "$@"
        else
            env_run "$run_venv" "$@"
        fi
        return  # not reached on success (exec) but kept for clarity
    fi

    # Non-`run` actions: resolve path via the selected name (default
    # `testenv`). For `install`/`purge` the M.i.2 dispatcher still
    # hard-codes the default; M.i.3/M.i.4 will accept `<name>` here.
    local target_name="${action_name:-testenv}"
    if [[ "$action" == "init" ]]; then
        assert_env_name_actionable "$target_name" || exit 1
        # Backend stub is enforced inside env_init -> ensure_env_exists.
    fi
    local testenv_venv testenv_root
    testenv_venv="$(resolve_env_path "$target_name")"
    testenv_root="${testenv_venv%/venv}"

    header_box "pyve env"

    # Propagate leaf return codes (M.i.2). Without explicit handling,
    # bash uses the last command's status — which is footer_box's 0,
    # masking failures from the leaf functions.
    local leaf_rc=0
    case "$action" in
        init)
            env_init "$target_name" || leaf_rc=$?
            ;;
        install)
            # Story M.i.3: with-arg installs into a single named env;
            # no-arg iterates over every non-lazy declared env.
            # Story M.j: each install is wrapped with a per-env lock;
            # `--no-wait` switches the acquire from wait+retry to fast-fail.
            # Story M.k: backend dispatch happens inside
            # `_env_install_with_lock` — no caller-side venv/conda gate.
            local lock_mode="wait"
            [[ "$install_no_wait" == "1" ]] && lock_mode="no-wait"
            if [[ -n "$action_name" ]]; then
                if assert_env_name_actionable "$action_name"; then
                    local install_env_path
                    install_env_path="$(resolve_env_path "$action_name")"
                    _env_install_with_lock "$action_name" "$install_env_path" "$requirements_file" "$lock_mode" || leaf_rc=$?
                else
                    leaf_rc=1
                fi
            else
                _env_install_all_nonlazy "$requirements_file" "$lock_mode" || leaf_rc=$?
            fi
            ;;
        purge)
            # Story M.i.4: with-arg removes one env; no-arg iterates
            # over every declared env with a TTY-aware confirm gate.
            if [[ -n "$action_name" ]]; then
                if assert_env_name_actionable "$action_name"; then
                    env_purge "$action_name" || leaf_rc=$?
                else
                    leaf_rc=1
                fi
            else
                _env_purge_all_with_confirm "$purge_force" || leaf_rc=$?
            fi
            ;;
        list)
            # Story M.p: read-mostly walk of declared + on-disk envs.
            env_list || leaf_rc=$?
            ;;
        prune)
            # Story M.p: forward the captured flags to the leaf.
            env_prune "${prune_args[@]+"${prune_args[@]}"}" || leaf_rc=$?
            ;;
    esac

    footer_box "$leaf_rc"
    return "$leaf_rc"
}
