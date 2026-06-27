#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Regression: a secondary-plugin (Node) install that exits non-zero must
# NOT abort `pyve init` before the composition tail (.envrc / .gitignore /
# next-steps).
#
# The bug: `pyve.sh` runs under `set -euo pipefail`; the secondary-plugin
# materializer dispatched the Node install as a bare command, so a non-zero
# return killed the whole process — silently skipping .gitignore/.envrc.
# pnpm's benign "ignored build scripts" notice (ERR_PNPM_IGNORED_BUILDS)
# was the field trigger.
#
# bats does NOT enable `set -e`, so these tests run the code under an
# explicit `set -euo pipefail` subshell to reproduce the real abort
# faithfully (same pattern as the "no 'unbound variable' under set -u"
# regression tests).
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
}

@test "secondary-plugin install failure does not abort under set -e (tail stays reachable)" {
    run bash -c '
        set -euo pipefail
        cd "$PYVE_ROOT"
        source lib/ui/core.sh
        source lib/utils.sh
        source lib/plugins/contract.sh
        source lib/plugins/registry.sh
        source lib/init_composer.sh
        PYVE_INIT_TAIL_BACKEND=venv
        manifest_load() { return 0; }
        plugin_registry_reset() { return 0; }
        plugin_load_all_from_manifest() { return 0; }
        plugin_list_active() { printf "node\n"; }
        manifest_get_plugin_path() { printf "."; }
        # Simulate the Node install exiting non-zero (e.g. pnpm ignored builds).
        plugin_dispatch() { echo "[ERR_PNPM_IGNORED_BUILDS] ..." >&2; return 1; }
        _compose_init_materialize_secondary_plugins
        echo "SURVIVED rc=$?"
    '
    assert_status_equals 0
    assert_output_contains "SURVIVED rc=0"
}

@test "compose_init composes .gitignore/.envrc even when a secondary (node) install fails" {
    run bash -c '
        set -euo pipefail
        cd "$PYVE_ROOT"
        source lib/ui/core.sh
        source lib/utils.sh
        source lib/plugins/contract.sh
        source lib/plugins/registry.sh
        source lib/init_composer.sh
        # Python materializer sets the tail globals (no real env built).
        python_pyve_plugin_init() {
            PYVE_INIT_TAIL_BACKEND=venv
            PYVE_INIT_TAIL_NO_DIRENV=false
            PYVE_INIT_TAIL_PG_MODE=no
            PYVE_INIT_TAIL_COMP_MODE=no
        }
        # Secondary materialization: one active node plugin whose install fails.
        manifest_load() { return 0; }
        plugin_registry_reset() { return 0; }
        plugin_load_all_from_manifest() { return 0; }
        plugin_list_active() { printf "node\n"; }
        manifest_get_plugin_path() { printf "."; }
        node_pyve_plugin_init() { echo "[ERR_PNPM_IGNORED_BUILDS]" >&2; return 1; }
        # Observable tail steps (no real composers / project-guide).
        compose_project_envrc() { echo "TAIL:envrc"; }
        compose_project_gitignore() { echo "TAIL:gitignore"; }
        run_project_guide_orchestration() { :; }
        _init_print_next_steps() { :; }
        footer_box() { :; }
        compose_init --backend venv
    '
    assert_status_equals 0
    assert_output_contains "TAIL:gitignore"
    assert_output_contains "TAIL:envrc"
}

@test "node install: pnpm ignored-build-scripts is non-fatal (warns, returns 0)" {
    run bash -c '
        cd "$PYVE_ROOT"
        source lib/ui/core.sh
        source lib/utils.sh
        source lib/plugins/node/runtime_detect.sh
        source lib/plugins/node/plugin.sh
        node_runtime_resolve() { printf "node\n"; return 0; }
        pnpm() {
            echo "Packages: +200"
            echo "[ERR_PNPM_IGNORED_BUILDS] Ignored build scripts: esbuild@0.25.12" >&2
            return 1
        }
        work="$(mktemp -d)"; cd "$work"; echo "{}" > package.json
        _node_provider_run_install . pnpm install
        echo "RC=$?"
    '
    assert_output_contains "RC=0"
    assert_output_contains "approve-builds"
}

@test "node install: a genuine pnpm failure still propagates non-zero" {
    run bash -c '
        cd "$PYVE_ROOT"
        source lib/ui/core.sh
        source lib/utils.sh
        source lib/plugins/node/runtime_detect.sh
        source lib/plugins/node/plugin.sh
        node_runtime_resolve() { printf "node\n"; return 0; }
        pnpm() { echo "ERR_PNPM_FETCH_404 GET https://registry/x 404" >&2; return 1; }
        work="$(mktemp -d)"; cd "$work"; echo "{}" > package.json
        _node_provider_run_install . pnpm install
        echo "RC=$?"
    '
    assert_output_contains "RC=1"
}
