#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.l — Backend dispatch via bp_dispatch for `.envrc` emission.
#
# Half 2 of N.l: the registry skeleton (test_n_l_backend_registry.bats)
# wires up bp_register / bp_lookup / bp_dispatch; this file verifies
# that today's `_init_direnv_venv` / `_init_direnv_micromamba` are
# reachable through `bp_dispatch <backend> activate <env_path> <env_name>`
# with byte-identical output.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    create_test_dir
    bp_registry_reset
    # The pyve.sh library-load block calls these on real invocations.
    # For tests, source-then-register is the equivalent.
    bp_register python venv virtualized
    bp_register python micromamba virtualized
}

teardown() {
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# Forwarders (shims) — minimal contract these functions must satisfy
# until N.n absorbs them into `lib/plugins/python/plugin.sh`.
# ────────────────────────────────────────────────────────────────────

@test "shim: venv_pyve_bp_activate is defined" {
    declare -F venv_pyve_bp_activate >/dev/null
}

@test "shim: micromamba_pyve_bp_activate is defined" {
    declare -F micromamba_pyve_bp_activate >/dev/null
}

# ────────────────────────────────────────────────────────────────────
# Dispatch produces the same `.envrc` as the direct legacy call.
# ────────────────────────────────────────────────────────────────────

@test "bp_dispatch venv activate produces same .envrc as _init_direnv_venv" {
    VERSION_MANAGER=""
    PROJECT_NAME="$(basename "$(pwd)")"

    # Direct (legacy) path
    rm -f .envrc
    _init_direnv_venv ".venv"
    local direct
    direct="$(<.envrc)"

    # Dispatched path
    rm -f .envrc
    bp_dispatch venv activate ".venv" "$PROJECT_NAME"
    local dispatched
    dispatched="$(<.envrc)"

    [ "$direct" = "$dispatched" ]
}

@test "bp_dispatch micromamba activate produces same .envrc as _init_direnv_micromamba" {
    VERSION_MANAGER=""

    rm -f .envrc
    _init_direnv_micromamba "test-env" ".pyve/envs/test-env"
    local direct
    direct="$(<.envrc)"

    rm -f .envrc
    bp_dispatch micromamba activate ".pyve/envs/test-env" "test-env"
    local dispatched
    dispatched="$(<.envrc)"

    [ "$direct" = "$dispatched" ]
}
