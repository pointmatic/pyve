#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story P.i.2 — `pyve status` reads the backend from the manifest, not
# `.pyve/config`. This closes the original P.i symptom: a v3-native project
# (pyve.toml with the backend recorded, no `.pyve/config`) had `pyve status`
# report the wrong/"not configured" backend because the status sections read
# `.pyve/config` directly. `show_status` calls `manifest_load` first, and the
# v3.0 read-compat synthesis keeps `manifest_get_backend root` correct for v2
# (`.pyve/config`-only) projects too — so one accessor serves both.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

@test "_status_backend: reads micromamba from a v3 manifest (no .pyve/config)" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
EOF
    [ ! -e .pyve/config ]
    manifest_load "$(pwd)/pyve.toml"
    run _status_backend
    [ "$output" = "micromamba" ]
}

@test "_status_backend: reads venv from a v3 manifest" {
    _init_write_pyve_toml "demo" "venv"
    manifest_load "$(pwd)/pyve.toml"
    run _status_backend
    [ "$output" = "venv" ]
}

@test "the migrated status sections route the backend through the manifest helper" {
    # Each backend-consuming section calls _status_backend and no longer reads
    # the backend straight from .pyve/config. Extract each function body (awk
    # flag-scope) and assert: contains _status_backend, not read_config_value
    # "backend". _status_section_integrations is checked for the negative only:
    # its sole backend-dependent row (the v2 project-guide row) moved to the
    # composed [project-guide] section, so it consumes no backend at all now.
    local fn body
    for fn in _status_configured_python _status_section_environment; do
        body="$(awk -v f="$fn" '$0 ~ "^"f"\\(\\)"{flag=1} flag{print} flag && /^}/{exit}' \
            "$PYVE_ROOT/lib/plugins/python/plugin.sh")"
        [[ "$body" == *"_status_backend"* ]] || { echo "$fn: does not call _status_backend"; false; }
        [[ "$body" != *'read_config_value "backend"'* ]] || { echo "$fn: still reads backend from .pyve/config"; false; }
    done
    body="$(awk '$0 ~ "^_status_section_integrations\\(\\)"{flag=1} flag{print} flag && /^}/{exit}' \
        "$PYVE_ROOT/lib/plugins/python/plugin.sh")"
    [[ "$body" != *'read_config_value "backend"'* ]] || { echo "_status_section_integrations: still reads backend from .pyve/config"; false; }
}
