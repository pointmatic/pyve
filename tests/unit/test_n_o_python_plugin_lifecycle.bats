#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.o — Python plugin lifecycle hooks (init / purge / update).
#
# Option 2 (announce-gate decision): hook-as-shim re-seat. The public
# entry points in pyve.sh's case dispatcher route through
# plugin_dispatch python <hook>; the implementations in
# lib/commands/{init,purge,update}.sh stay where they are. Same call
# revisited in N.s.
#
# Cross-cutting:
#   - S9: env-block validation — purpose ∈ {run, test, utility, temp},
#     backend ∈ registered names.
#   - S11: languages advisory read — informational only in v3.0;
#     surfacing in pyve check / pyve status lands in N.p.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    bp_registry_reset
    plugin_registry_reset
    # The plugin's register_backends hook is normally called from
    # pyve.sh at source time; tests start from a clean registry.
    python_pyve_plugin_register_backends
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# Shim existence — the three lifecycle hooks are defined.
# ════════════════════════════════════════════════════════════════════

@test "lifecycle: python_pyve_plugin_init is defined" {
    declare -F python_pyve_plugin_init >/dev/null
}

@test "lifecycle: python_pyve_plugin_purge is defined" {
    declare -F python_pyve_plugin_purge >/dev/null
}

@test "lifecycle: python_pyve_plugin_update is defined" {
    declare -F python_pyve_plugin_update >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# plugin_dispatch routes to the plugin's hook.
# ════════════════════════════════════════════════════════════════════
#
# We stub out the underlying init_project / purge_project /
# update_project so the test doesn't actually spawn `python -m venv`
# etc. — the assertion is "did plugin_dispatch reach the shim, which
# called the right downstream function with the right args?"

stub_lifecycle_targets() {
    eval '
        init_project()   { printf "init_project ARGS=%s\n" "$*"; return 0; }
        purge_project()  { printf "purge_project ARGS=%s\n" "$*"; return 0; }
        update_project() { printf "update_project ARGS=%s\n" "$*"; return 0; }
    '
}

@test "dispatch: plugin_dispatch python init forwards args to init_project" {
    stub_lifecycle_targets
    plugin_register python
    run plugin_dispatch python init --backend venv --no-direnv
    [ "$status" -eq 0 ]
    [[ "$output" == *"init_project ARGS=--backend venv --no-direnv"* ]]
}

@test "dispatch: plugin_dispatch python purge forwards args to purge_project" {
    stub_lifecycle_targets
    plugin_register python
    run plugin_dispatch python purge --keep-testenv --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"purge_project ARGS=--keep-testenv --yes"* ]]
}

@test "dispatch: plugin_dispatch python update forwards args to update_project" {
    stub_lifecycle_targets
    plugin_register python
    run plugin_dispatch python update --foo bar
    [ "$status" -eq 0 ]
    [[ "$output" == *"update_project ARGS=--foo bar"* ]]
}

# ════════════════════════════════════════════════════════════════════
# S9 env-block validation — purpose + backend.
# ════════════════════════════════════════════════════════════════════
#
# The init hook validates every declared env's purpose and backend
# BEFORE delegating to init_project. Failure exits non-zero with a
# precise diagnostic.

write_manifest() {
    cat > pyve.toml <<EOF
pyve_schema = "3.0"
[project]
name = "demo"
$1
EOF
}

@test "S9: valid purpose + backend → validation passes" {
    write_manifest '
[env.root]
purpose = "utility"
backend = "venv"
'
    manifest_load pyve.toml
    run python_pyve_plugin_validate_env_blocks
    [ "$status" -eq 0 ]
}

@test "S9: unknown purpose → validation fails with named diagnostic" {
    write_manifest '
[env.root]
purpose = "deploy"
backend = "venv"
'
    # The Python helper itself rejects unknown purposes (Story N.a
    # added VALID_PURPOSES validation). Loading errors at the helper
    # layer; plugin validation never reaches this env. Sanity-check
    # the error surfaces correctly.
    run manifest_load pyve.toml
    [ "$status" -ne 0 ]
    [[ "$output" == *"purpose"* ]] || [[ "$output" == *"deploy"* ]]
}

@test "S9: unregistered backend → plugin validation fails with named diagnostic" {
    # F6 (N.ba.2) now rejects an unknown backend at manifest_load. To exercise
    # the plugin validator's own bp_lookup guard — which still defends the v2
    # read-compat synthesis path that bypasses the Python validator — load a
    # valid manifest, then inject an unregistered backend into the parsed
    # arrays (simulating a synthesized shape).
    write_manifest '
[env.root]
purpose = "utility"
backend = "venv"
'
    manifest_load pyve.toml
    PYVE_ENV_BACKEND[0]="quantum-foo"
    run python_pyve_plugin_validate_env_blocks
    [ "$status" -ne 0 ]
    [[ "$output" == *"quantum-foo"* ]]
    [[ "$output" == *"backend"* ]]
}

@test "S9: empty backend is allowed (manifest doesn't require it)" {
    write_manifest '
[env.root]
purpose = "utility"
'
    manifest_load pyve.toml
    run python_pyve_plugin_validate_env_blocks
    [ "$status" -eq 0 ]
}

@test "S9: validation iterates every declared env" {
    # Inject the bad backend into the LAST env post-load (F6 would otherwise
    # reject it at parse), so the plugin validator's per-env iteration is what
    # is exercised — it must reach 'broken' at the end of the list.
    write_manifest '
[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"

[env.broken]
purpose = "utility"
backend = "venv"
'
    manifest_load pyve.toml
    PYVE_ENV_BACKEND[2]="quantum-foo"
    run python_pyve_plugin_validate_env_blocks
    [ "$status" -ne 0 ]
    [[ "$output" == *"broken"* ]] || [[ "$output" == *"quantum-foo"* ]]
}

# ════════════════════════════════════════════════════════════════════
# S11 languages advisory — readable from the plugin's init path.
# ════════════════════════════════════════════════════════════════════
#
# v3.0: read-only — no behavior change. Storing the read sets up
# N.p's surfacing in `pyve check` / `pyve status`. Tests confirm the
# read mechanism works end-to-end so N.p has something to consume.

@test "S11: manifest_get_languages returns the declared list for the env" {
    write_manifest '
[env.root]
purpose = "utility"
backend = "venv"
languages = ["python", "rust"]
'
    manifest_load pyve.toml
    local -a langs
    manifest_get_languages root langs
    [ "${#langs[@]}" -eq 2 ]
    [ "${langs[0]}" = "python" ]
    [ "${langs[1]}" = "rust" ]
}

@test "S11: manifest_get_languages returns empty when languages not declared" {
    write_manifest '
[env.root]
purpose = "utility"
backend = "venv"
'
    manifest_load pyve.toml
    local -a langs
    manifest_get_languages root langs
    [ "${#langs[@]}" -eq 0 ]
}
