# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve lock — generate or verify conda-lock.yml (micromamba only)
#
# Wraps `conda-lock` with backend guards, prerequisite checks, platform
# detection, output filtering (drops the misleading "conda-lock install"
# post-run hint), and "already up to date" detection. The --check flag
# performs an mtime-only comparison and never invokes conda-lock.
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution. The file is a library; running it as a
# script would fall through to nothing useful and confuse the user.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Run conda-lock for the current platform, handling output filtering and
# actionable next-step messaging.
#
# Function-name note: this function is named `lock_environment` per the
# project-essentials "Function naming convention: verb_<operand>" rule —
# `pyve lock` operates on the environment's dependency graph (locks
# `environment.yml` → `conda-lock.yml`).
#
# Story M.q surface (extends to per-testenv locking):
#   pyve lock                  → main env (existing behavior)
#   pyve lock --env <name>     → lock the named conda-backed testenv
#                                (uses [env.<name>].manifest from pyve.toml;
#                                output: <manifest-basename>-lock.yml
#                                sibling to the manifest)
#   pyve lock --all            → main env + every conda-backed testenv
lock_environment() {
    local check_mode=false
    local mode="main"            # main | env | all
    local target_name=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                check_mode=true
                shift
                ;;
            --env)
                mode="env"
                if [[ -z "${2:-}" ]]; then
                    log_error "--env requires a testenv name"
                    exit 1
                fi
                target_name="$2"
                shift 2
                ;;
            --env=*)
                mode="env"
                target_name="${1#--env=}"
                shift
                ;;
            --all)
                mode="all"
                shift
                ;;
            -*)
                unknown_flag_error "lock" "$1" --check --env --all --help
                ;;
            *)
                log_error "pyve lock takes no positional arguments (got: $1)"
                log_error "Usage: pyve lock [--check] [--env <name>] [--all]"
                exit 1
                ;;
        esac
    done

    # Per-env routing — M.q. `--check` for per-env modes is not in
    # scope for M.q (today's `--check` is main-env-only). The dispatch
    # below routes `--env`/`--all`/`main` to the right helper.
    case "$mode" in
        env)
            _lock_one_env "$target_name"
            return $?
            ;;
        all)
            # Main env first (existing behavior), then per-testenv.
            # Use a subshell for the main-env call so its `exit` paths
            # don't kill the whole `--all` iteration.
            ( _lock_main_env ) || true
            _lock_all_conda_testenvs
            return $?
            ;;
    esac

    # Default mode: main env. Delegate to the helper so the body can
    # be shared with the `--all` path (above) via a subshell.
    _lock_main_env
    return $?
}

# Main-env locking — the pre-M.q body of `lock_environment`, factored
# so `--all` can call it without re-implementing.
_lock_main_env() {
    # --check: mtime comparison only, no conda-lock invocation
    if [[ "$check_mode" == "true" ]]; then
        if [[ ! -f "environment.yml" ]]; then
            log_error "environment.yml not found."
            exit 1
        fi
        if [[ ! -f "conda-lock.yml" ]]; then
            printf "✗ conda-lock.yml not found. Run: pyve lock\n" >&2
            exit 1
        fi
        if is_lock_file_stale; then
            printf "✗ conda-lock.yml is stale — environment.yml has been modified since the lock was generated. Run: pyve lock\n" >&2
            exit 1
        fi
        printf "✓ conda-lock.yml is up to date.\n"
        return 0
    fi

    local platform

    # Guard 1: venv backend projects do not use conda-lock. Resolve the
    # backend manifest-first (authoritative on v3; `.pyve/config` is a
    # transitional fallback for the v3.0 read-compat window, removed in P.i.23)
    # so a v3-native venv project is rejected here too, not just a v2 one.
    local resolved_backend
    resolved_backend="$(manifest_get_backend root 2>/dev/null || true)"
    [[ -z "$resolved_backend" ]] && resolved_backend="$(read_config_value "backend" 2>/dev/null || true)"
    if [[ "$resolved_backend" == "venv" ]]; then
        log_error "pyve lock is for micromamba projects only."
        log_error "This project uses the venv backend. conda-lock.yml is not used by venv."
        exit 1
    fi

    # Guard 2: environment.yml must exist
    if [[ ! -f "environment.yml" ]]; then
        log_error "environment.yml not found. pyve lock requires a conda environment file."
        log_error "Initialize with: pyve init --backend micromamba"
        exit 1
    fi

    # Guard 3: conda-lock must be on PATH
    if ! command -v conda-lock >/dev/null 2>&1; then
        log_error "conda-lock is not available in the current environment."
        log_error "Add 'conda-lock' to environment.yml dependencies and run 'pyve init --force --no-lock'."
        exit 1
    fi

    platform="$(get_conda_platform)"

    log_info "Generating conda-lock.yml for ${platform}..."
    printf "\n"

    # Run conda-lock, capturing combined output
    local output
    local exit_code
    output="$(conda-lock -f environment.yml -p "$platform" 2>&1)"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        # Pass through conda-lock's error output unmodified
        printf "%s\n" "$output" >&2
        exit $exit_code
    fi

    # Filter out the misleading "conda-lock install" post-run message that suggests
    # a non-Pyve workflow. All other output (solver progress, packages) is kept.
    local filtered_output
    filtered_output="$(printf "%s\n" "$output" | grep -v "conda-lock install\|Install lock using")"
    if [[ -n "$filtered_output" ]]; then
        printf "%s\n" "$filtered_output"
        printf "\n"
    fi

    # Detect "already up to date" case: conda-lock emits "spec hash already locked"
    # when the environment spec hasn't changed since the last run.
    # Checked after printing so any warnings in the output are still visible.
    if printf "%s" "$output" | grep -qi "already locked\|spec hash already locked"; then
        printf "✓ conda-lock.yml is already up to date for %s. No changes made.\n" "$platform"
        exit 0
    fi

    printf "✓ conda-lock.yml updated for %s.\n" "$platform"
    printf "\n"
    printf "To rebuild the environment from the new lock file:\n"
    printf "  pyve init --force\n"
    printf "\n"
    printf "If the environment is already initialized and you only need to commit the\n"
    printf "updated lock file, rebuilding is optional.\n"
}

#============================================================
# Story M.q: per-testenv locking
#
# `pyve lock --env <name>` locks a single conda-backed testenv by
# running `conda-lock -f <manifest> -p <platform> --lockfile <out>`
# where `<out>` is `<manifest-basename>-lock.yml` sibling to the
# manifest. Venv-backed envs hard-error (conda-lock is conda-only).
# `pyve lock --all` locks the main env plus every conda-backed
# testenv.
#============================================================

# Derive the sibling lock-file path for a manifest.
# tests/env.yml        → tests/env-lock.yml
# environment.yaml     → environment-lock.yml
# Strips `.yml` or `.yaml`, then appends `-lock.yml`.
_lock_env_lock_path() {
    local manifest="$1"
    local dir base
    dir="$(dirname "$manifest")"
    base="$(basename "$manifest")"
    base="${base%.yaml}"
    base="${base%.yml}"
    if [[ "$dir" == "." ]]; then
        printf '%s-lock.yml' "$base"
    else
        printf '%s/%s-lock.yml' "$dir" "$base"
    fi
}

# Lock a single named testenv. Uses `return` (not `exit`) so callers
# can iterate without the first failure killing the whole walk.
_lock_one_env() {
    local name="$1"

    # Load named-env config (idempotent).
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi

    if [[ "$name" == "root" ]]; then
        log_error "pyve lock --env root: 'root' is the main project env."
        log_error "Use: pyve lock (no args) to lock the main env."
        return 1
    fi
    if ! is_env_declared "$name"; then
        log_error "pyve lock --env: testenv '$name' is not declared in pyve.toml."
        log_error "Declare it under [env.$name] in pyve.toml."
        return 1
    fi

    local backend
    backend="$(_env_resolve_backend "$name")" || backend="venv"
    if [[ "$backend" != "micromamba" ]]; then
        log_error "pyve lock --env: testenv '$name' (backend=$backend) is not conda-backed."
        log_error "Only micromamba-backed testenvs can be locked via conda-lock."
        return 1
    fi

    local manifest
    manifest="$(_env_manifest_of "$name")" || manifest=""
    if [[ -z "$manifest" ]]; then
        log_error "pyve lock --env: testenv '$name' has no 'manifest' declared."
        log_error "Add: [env.$name]"
        log_error "     manifest = \"<environment.yml path>\" (in pyve.toml)"
        return 1
    fi
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi

    if ! command -v conda-lock >/dev/null 2>&1; then
        log_error "conda-lock is not available in the current environment."
        log_error "Add 'conda-lock' to environment.yml dependencies and run 'pyve init --force --no-lock'."
        return 1
    fi

    local platform
    platform="$(get_conda_platform)"

    local lock_path
    lock_path="$(_lock_env_lock_path "$manifest")"

    log_info "Generating lock file for testenv '$name' (manifest: $manifest, platform: $platform)..."

    if conda-lock -f "$manifest" -p "$platform" --lockfile "$lock_path"; then
        success "Locked testenv '$name' → $lock_path"
        return 0
    fi
    log_error "Failed to lock testenv '$name'"
    return 1
}

# Iterate every declared conda-backed testenv and lock it. Venv envs
# are silently skipped (handled by main-env lock or out of scope for
# `pyve lock`). Errors per-env are warned but do not halt iteration.
_lock_all_conda_testenvs() {
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi
    local name backend rc=0
    for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        backend="$(_env_resolve_backend "$name")" || backend="venv"
        [[ "$backend" == "micromamba" ]] || continue
        if ! _lock_one_env "$name"; then
            warn "Failed to lock testenv '$name' (continuing)"
            rc=1
        fi
    done
    return "$rc"
}
