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
# N.av.1: delegate to the Python plugin's init hook (the existing
# monolithic `init_project`) so behavior is byte-for-byte unchanged while
# the dispatch seam is established. Later sub-stories replace this body
# with the composed per-plugin flow.
compose_init() {
    plugin_dispatch python init "$@"
}
