# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/init_composer.sh — composed `pyve init` orchestrator
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
# This step is a PURE SEAM: `compose_init` delegates to
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
# The Python hook (init_project) now MATERIALIZES the env + scaffolds
# pyve.toml + runs the Python-specific setup (vscode / testenv /
# pip-deps), then hands the stack-agnostic
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
    if _compose_init_is_node_only; then
        # a fresh Node-only project materializes node_modules
        # and gets NO Python app env.
        _compose_init_node_only "$@" || return $?
    else
        # Python / polyglot: the monolithic Python materializer builds the
        # Python app env AND scaffolds the manifest (plain or polyglot).
        plugin_dispatch python init "$@" || return $?
        # now materialize any OTHER declared plugins (e.g.
        # node at its sub-path) from the freshly-scaffolded manifest.
        _compose_init_materialize_secondary_plugins
    fi
    _compose_init_run_tail
}

# After the Python materializer has run + scaffolded the manifest,
# materialize every OTHER active plugin against its declared path (Python
# is already done). For a Python-only project this is a no-op; for a
# polyglot project it dispatches `node init <sub-path>`.
_compose_init_materialize_secondary_plugins() {
    # Skip when nothing materialized (update-in-place / early-return path):
    # there is no fresh manifest to read and no env was built.
    [[ -z "${PYVE_INIT_TAIL_BACKEND:-}" ]] && return 0

    # The Python materializer succeeded, so pyve.toml parsed once already
    # (init validates it) — manifest_load here will too. A failure leaves
    # the project Python-functional; just skip secondary materialization.
    manifest_load >/dev/null 2>&1 || return 0
    plugin_registry_reset
    plugin_load_all_from_manifest

    local name path
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        [[ "$name" == "python" ]] && continue   # already materialized above
        path="$(manifest_get_plugin_path "$name" 2>/dev/null || printf '.')"
        [[ -z "$path" ]] && path="."
        # A secondary-plugin (e.g. Node) install must not abort the
        # composition tail (.envrc / .gitignore / next-steps). Under
        # `set -e` a bare failing dispatch would kill the whole init; guard
        # it so a non-zero return warns and the tail still runs.
        if ! plugin_dispatch "$name" init "$path"; then
            warn "init: '$name' setup did not finish — continuing; complete it later with 'pyve env install'"
        fi
    done < <(plugin_list_active)
    # Never propagate a secondary-plugin failure: the tail must always run.
    return 0
}

# True for a FRESH Node-only project: no pyve.toml yet, Node detected at
# root, and the Python plugin is NOT active (no Python app signal — the
# package.json is the competing stack per the N.aj gate). Refresh
# (pyve.toml already present) and polyglot are left to the normal path
# here; polyglot Node materialization is N.av.4.
_compose_init_is_node_only() {
    [[ -f pyve.toml ]] && return 1
    local node_signal
    node_signal="$(plugin_dispatch node detect 2>/dev/null || true)"
    [[ "$node_signal" == "node" ]] || return 1
    ! python_plugin_is_active_in_project
}

# Composed Node-only init: scaffold a [plugins.node]-only manifest, load
# it, then dispatch each active plugin's materializer (just Node here).
# Hands the node-variant tail off via the result globals.
_compose_init_node_only() {
    local no_direnv=false arg
    for arg in "$@"; do
        [[ "$arg" == "--no-direnv" ]] && no_direnv=true
    done

    banner "Node project detected"
    _init_write_pyve_toml_node_only "$(basename "$(pwd)")"

    # Reload the manifest so the materializer + composers see node. This
    # needs Pyve's toolchain Python (lib/toolchain_python.sh) to parse
    # pyve.toml. If it fails we must NOT proceed: an empty plugin set falls
    # back to implicit-Python (registry S5), which would materialize a
    # Python venv on a Node-only project. Surface the real cause instead.
    if ! manifest_load >/dev/null 2>&1; then
        log_error "Could not parse pyve.toml — Pyve's Python interpreter is unavailable."
        log_error "Run 'pyve self install' to provision Pyve's toolchain Python, or set PYVE_PYTHON."
        return 1
    fi
    plugin_registry_reset
    plugin_load_all_from_manifest

    # Materialize each active plugin's env against its declared path. For a
    # Node-only manifest this dispatches `node init "."` (node_modules); the
    # same loop generalizes to polyglot in N.av.4.
    local name path
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        path="$(manifest_get_plugin_path "$name" 2>/dev/null || printf '.')"
        [[ -z "$path" ]] && path="."
        # A failed Node install must not abort the composition tail (it would
        # under `set -e` from a bare dispatch); warn and continue so .envrc /
        # .gitignore / next-steps still land.
        if ! plugin_dispatch "$name" init "$path"; then
            warn "init: '$name' setup did not finish — continuing; complete it later with 'pyve env install'"
        fi
    done < <(plugin_list_active)

    # Node-variant tail: no Python backend, no project-guide (a non-Python
    # stack needs a utility root to host it — F2/N.aw); node-aware next-steps.
    PYVE_INIT_TAIL_BACKEND="node"
    PYVE_INIT_TAIL_ENV_PATH="."
    PYVE_INIT_TAIL_NO_DIRENV="$no_direnv"
    PYVE_INIT_TAIL_PG_MODE="no"
    PYVE_INIT_TAIL_COMP_MODE="no"
}

# Write a Node-only v3 manifest ([plugins.node], no [plugins.python]).
# Idempotent: no-op when pyve.toml already exists.
_init_write_pyve_toml_node_only() {
    local project_name="$1"
    [[ -f pyve.toml ]] && return 0
    cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "${project_name}"
pyve_defaults_version = "${PYVE_PARAM_DEFAULTS_VERSION:-1}"

[plugins.node]
EOF
    success "Created pyve.toml (node)"
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

    # project-guide orchestration (lifted to lib/project_guide.sh). project-guide
    # is globally hosted (pyve self install → toolchain venv + shim), so it
    # works on a non-Python stack too — run it on every backend, then emit
    # stack-aware next-steps.
    run_project_guide_orchestration "$backend" "$env_path" "$pg_mode" "$comp_mode"
    if [[ "$backend" == "node" ]]; then
        _compose_init_node_next_steps "$no_direnv"
    else
        _init_print_next_steps "$backend" "$no_direnv" "$env_path"
    fi
    footer_box
}

# Node-aware next-steps (no Python activation hints).
_compose_init_node_next_steps() {
    local no_direnv="$1"
    banner "Next steps"
    info "node_modules installed. Run package scripts with: pyve run <script>"
    if [[ "$no_direnv" == false ]]; then
        info "Activate node_modules/.bin via direnv: direnv allow"
    fi
}
