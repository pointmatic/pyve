# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/init_composer.sh — composed `pyve init` orchestrator (Story N.av)
#
# The stack-agnostic entry point `pyve init` dispatches to, sibling of
# the composer family (lib/check_composer.sh / lib/purge_composer.sh /
# lib/status_composer.sh / lib/envrc_composer.sh). Composed `init` is
# cross-stack infrastructure → it lives in lib/, not in any one plugin
# (per the "lib/commands/<name>.sh is for command implementations only"
# essential).
#
# Target shape (N.av umbrella): parse args once → write/scaffold
# pyve.toml → manifest_load + plugin_load_all_from_manifest → the
# project-guide accept decision → dispatch EACH active plugin's
# init/materialize hook against its declared path → compose .envrc /
# .gitignore → next-steps. So a Node-only project materializes
# node_modules (no unwanted .venv) and polyglot materializes both.
#
# Story N.av.1 (this step) is a PURE SEAM: `compose_init` delegates to
# today's monolithic Python init hook with zero behavior change. The
# untangling (materializer extraction + tail lift) lands in N.av.2; the
# Node-only / polyglot paths in N.av.3 / N.av.4.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Composed `pyve init` entry point.
#
# N.av.2: the Python hook (init_project) now MATERIALIZES the env +
# writes .pyve/config + scaffolds pyve.toml + runs the Python-specific
# setup (vscode / testenv / pip-deps), then hands the stack-agnostic
# COMPOSITION TAIL up to compose_init via the PYVE_INIT_TAIL_* result
# globals. compose_init runs that tail (compose .envrc / .gitignore →
# project-guide → next-steps), so it is owned at orchestration level
# rather than welded inside the plugin. N.av.3 / N.av.4 dispatch the
# per-plugin materializers for Node-only / polyglot stacks.
#
# Plain globals (not a helper) carry the hand-off so init_project has no
# cross-file function dependency — it sets the globals directly; an
# early-return path (e.g. update-in-place with no env change) leaves
# PYVE_INIT_TAIL_BACKEND empty and the tail is skipped.
compose_init() {
    # Reset the hand-off so a stale value from a prior in-process call can
    # never trigger a spurious tail (matters for tests / library callers).
    PYVE_INIT_TAIL_BACKEND=""
    plugin_dispatch python init "$@" || return $?
    _compose_init_run_tail
}

# Run the stack-agnostic composition tail using the PYVE_INIT_TAIL_*
# result globals the Python materializer set. No-op when no env was
# materialized (PYVE_INIT_TAIL_BACKEND empty).
_compose_init_run_tail() {
    local backend="${PYVE_INIT_TAIL_BACKEND:-}"
    [[ -z "$backend" ]] && return 0

    local env_path="${PYVE_INIT_TAIL_ENV_PATH:-}"
    local no_direnv="${PYVE_INIT_TAIL_NO_DIRENV:-false}"
    local pg_mode="${PYVE_INIT_TAIL_PG_MODE:-}"
    local comp_mode="${PYVE_INIT_TAIL_COMP_MODE:-}"

    # Compose .envrc (unless --no-direnv) + .gitignore from every active
    # plugin (the composers reload the manifest/registry first).
    if [[ "$no_direnv" == false ]]; then
        compose_project_envrc ".envrc" && success "Created .envrc"
    else
        info "Skipping .envrc creation (--no-direnv)"
    fi
    compose_project_gitignore ".gitignore" && success "Updated .gitignore"

    # project-guide orchestration (lifted in N.au), then next-steps.
    run_project_guide_orchestration "$backend" "$env_path" "$pg_mode" "$comp_mode"
    _init_print_next_steps "$backend" "$no_direnv" "$env_path"
    footer_box
}
