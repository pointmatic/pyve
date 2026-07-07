#!/usr/bin/env bash
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve upgrade — re-resolve an env's dependencies to newest-within-
# constraints, KEEP the env directory (no purge/rebuild), re-stamp the
# operational-state record, and re-lock where a lock file participates.
#
# The verb boundary, pinned across the help surfaces: `pyve update`
# touches the files Pyve manages *around* your project (config,
# .gitignore, project-guide scaffolding); `pyve init --force` and
# `pyve upgrade` touch the *environments themselves* — force rebuilds
# from the declaration, upgrade re-resolves in place.
#
# Upgrade never creates: a never-realized target errors with the
# standard `pyve env init` hint. `--check` prints the plan ("would
# run: ...") and executes nothing.

show_upgrade_help() {
    cat << 'EOF'
pyve upgrade - Re-resolve environment dependencies to newest-within-constraints

Usage:
  pyve upgrade [--env <name> | --all] [--check]

Options:
  --env <name>   Upgrade one declared env (default: the root env)
  --all          Upgrade the root env and every declared env
  --check        Preview the plan without executing anything
  --help         Show this help

Behavior:
  - The env directory is KEPT — upgrade re-resolves dependencies in
    place (venv: pip install --upgrade over the declared recipe;
    conda: micromamba update from the manifest, then the pip layer
    with --upgrade, then a re-lock when a lock file participates).
  - A never-realized env is an error pointing at `pyve env init` —
    upgrade never creates.
  - Boundary: `pyve update` touches the files Pyve manages
    around your project; `pyve init --force` / `pyve upgrade`
    touch the environments themselves.
EOF
}

upgrade_environment() {
    local target="" all=0 check=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                if [[ -z "${2:-}" ]]; then
                    log_error "--env requires an environment name"
                    exit 1
                fi
                target="$2"
                shift 2
                ;;
            --all)
                all=1
                shift
                ;;
            --check)
                check=1
                shift
                ;;
            --help|-h)
                show_upgrade_help
                exit 0
                ;;
            -*)
                unknown_flag_error "upgrade" "$1" --env --all --check --help
                ;;
            *)
                log_error "Unexpected argument: $1"
                log_error "Usage: pyve upgrade [--env <name> | --all] [--check]"
                exit 1
                ;;
        esac
    done

    if [[ "$all" == "1" && -n "$target" ]]; then
        log_error "upgrade: pass --env <name> OR --all, not both"
        exit 1
    fi

    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi

    header_box "pyve upgrade"
    local rc=0 erc name

    if [[ "$all" == "1" ]]; then
        _upgrade_one_env "root" "$check" || rc=$?
        for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
            [[ -z "$name" || "$name" == "root" ]] && continue
            if is_env_lazy "$name" && [[ ! -d ".pyve/envs/$name" ]]; then
                info "--all: skipping lazy env '$name' (never realized; it provisions on first use)"
                continue
            fi
            banner "Upgrading env '$name'"
            erc=0
            ( _upgrade_one_env "$name" "$check" ) || erc=$?
            if [[ "$erc" -ne 0 ]]; then
                warn "--all: upgrade of '$name' failed (exit $erc) — continuing with the remaining envs"
                if [[ "$erc" -gt "$rc" ]]; then rc="$erc"; fi
            fi
        done
    else
        _upgrade_one_env "${target:-root}" "$check" || rc=$?
    fi

    footer_box "$rc"
    return "$rc"
}

# Upgrade a single env in place. <name> may be `root`; `check`=1 turns
# every execution step into a "would run:" preview line.
_upgrade_one_env() {
    local name="$1" check="${2:-0}"

    if [[ "$name" != "root" ]]; then
        assert_env_name_actionable "$name" || return 1
    fi

    local backend
    backend="$(_env_resolve_backend "$name")" || backend="venv"
    if _env_backend_is_advisory "$backend"; then
        info "env '$name' declares backend '$backend', which pyve does not yet materialize; nothing to upgrade"
        return 0
    fi

    local env_path
    env_path="$(resolve_env_path "$name")"

    if [[ "$backend" == "micromamba" ]]; then
        _upgrade_conda "$name" "$env_path" "$check"
    else
        _upgrade_venv "$name" "$env_path" "$check"
    fi
}

# Run or preview a command depending on check mode.
_upgrade_exec() {
    local check="$1"
    shift
    if [[ "$check" == "1" ]]; then
        info "would run: $*"
        return 0
    fi
    run_cmd "$@"
}

_upgrade_venv() {
    local name="$1" env_path="$2" check="$3"

    if [[ ! -x "$env_path/bin/python" ]]; then
        log_error "env '$name' is not initialized at '$env_path' — upgrade never creates"
        if [[ "$name" == "root" ]]; then
            log_error "Run: pyve init"
        else
            log_error "Run: pyve env init $name"
        fi
        return 1
    fi

    # The declared recipe upgrades in the fixed directive order.
    local editable extra
    editable="$(_env_editable_of "$name" 2>/dev/null || printf '')"
    extra="$(_env_extra_of "$name" 2>/dev/null || printf '')"
    local -a reqs=()
    _env_requirements_of "$name" reqs 2>/dev/null || true

    local ran=0 r
    if [[ -n "$editable" || -n "$extra" || "${#reqs[@]}" -gt 0 ]]; then
        info "Upgrading '$name' from its declared recipe..."
        if [[ -n "$editable" ]]; then
            _upgrade_exec "$check" "$env_path/bin/python" -m pip install --upgrade -e "$editable"
            ran=1
        fi
        local -a r_args=()
        for r in "${reqs[@]+"${reqs[@]}"}"; do
            if [[ ! -f "$r" ]]; then
                log_error "Declared requirements file not found: $r"
                return 1
            fi
            r_args+=("-r" "$r")
        done
        if [[ "${#r_args[@]}" -gt 0 ]]; then
            _upgrade_exec "$check" "$env_path/bin/python" -m pip install --upgrade "${r_args[@]}"
            ran=1
        fi
        if [[ -n "$extra" ]]; then
            local -a extra_pkgs=()
            _env_resolve_extra_packages "$extra" extra_pkgs || return 1
            if [[ "${#extra_pkgs[@]}" -gt 0 ]]; then
                _upgrade_exec "$check" "$env_path/bin/python" -m pip install --upgrade "${extra_pkgs[@]}"
                ran=1
            fi
        fi
    elif [[ "$name" == "root" ]]; then
        # No declared recipe on the root block: fall back to the
        # conventional project sources the init dep-install honors.
        if [[ -f "requirements.txt" ]]; then
            info "Upgrading root env from requirements.txt..."
            _upgrade_exec "$check" "$env_path/bin/python" -m pip install --upgrade -r requirements.txt
            ran=1
        elif [[ -f "pyproject.toml" ]]; then
            info "Upgrading root env from pyproject.toml (editable self-install)..."
            _upgrade_exec "$check" "$env_path/bin/python" -m pip install --upgrade -e .
            ran=1
        fi
    fi

    if [[ "$ran" == "0" ]]; then
        info "env '$name' declares no upgradable dependency source — nothing to upgrade"
        return 0
    fi

    if [[ "$check" != "1" ]]; then
        if [[ "$name" != "root" ]]; then
            state_mark_installed "$name" "venv"
        fi
        success "Upgraded '$name'"
    fi
}

_upgrade_conda() {
    local name="$1" env_path="$2" check="$3"

    if [[ ! -d "$env_path/conda-meta" ]]; then
        log_error "env '$name' is not initialized at '$env_path' — upgrade never creates"
        log_error "Run: pyve env init $name"
        return 1
    fi

    local manifest
    manifest="$(_env_manifest_of "$name")" || manifest=""
    if [[ -z "$manifest" || ! -f "$manifest" ]]; then
        log_error "conda-backed env '$name' has no readable manifest to upgrade from"
        return 1
    fi

    local micromamba_path
    micromamba_path="$(get_micromamba_path)" || micromamba_path=""
    if [[ -z "$micromamba_path" ]]; then
        log_error "micromamba not found"
        return 1
    fi

    # Newest-within-constraints for the conda layer, then the pip layer.
    info "Upgrading conda env '$name' from $manifest..."
    if [[ "$check" == "1" ]]; then
        info "would run: $micromamba_path update -p $env_path -f $manifest -y"
    elif ! "$micromamba_path" update -p "$env_path" -f "$manifest" -y; then
        log_error "Failed to upgrade conda env '$name'"
        return 1
    fi

    local editable extra
    editable="$(_env_editable_of "$name" 2>/dev/null || printf '')"
    extra="$(_env_extra_of "$name" 2>/dev/null || printf '')"
    local -a reqs=()
    _env_requirements_of "$name" reqs 2>/dev/null || true
    local r
    if [[ -n "$editable" ]]; then
        _upgrade_exec "$check" "$micromamba_path" run -p "$env_path" python -m pip install --upgrade -e "$editable"
    fi
    local -a r_args=()
    for r in "${reqs[@]+"${reqs[@]}"}"; do
        if [[ ! -f "$r" ]]; then
            log_error "Declared requirements file not found: $r"
            return 1
        fi
        r_args+=("-r" "$r")
    done
    if [[ "${#r_args[@]}" -gt 0 ]]; then
        _upgrade_exec "$check" "$micromamba_path" run -p "$env_path" python -m pip install --upgrade "${r_args[@]}"
    fi
    if [[ -n "$extra" ]]; then
        local -a extra_pkgs=()
        _env_resolve_extra_packages "$extra" extra_pkgs || return 1
        if [[ "${#extra_pkgs[@]}" -gt 0 ]]; then
            _upgrade_exec "$check" "$micromamba_path" run -p "$env_path" python -m pip install --upgrade "${extra_pkgs[@]}"
        fi
    fi

    # Re-lock when a lock file participates in this project.
    if [[ -f "conda-lock.yml" && "$check" != "1" ]]; then
        info "Re-locking after upgrade..."
        if [[ "$name" == "root" ]]; then
            lock_environment
        else
            lock_environment --env "$name"
        fi
    fi

    if [[ "$check" != "1" ]]; then
        state_mark_installed "$name" "micromamba"
        success "Upgraded '$name'"
    fi
}
