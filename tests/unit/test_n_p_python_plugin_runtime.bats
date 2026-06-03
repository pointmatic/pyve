#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.p — Python plugin runtime hooks (check / status / run / test)
# plus the manual_steps (S7) schema extension and advisory rendering,
# plus the languages (S11) advisory in check, plus python set/show
# relocation into the plugin file (Option (a) — ordinary functions).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/commands/run.sh"
    source "$PYVE_ROOT/lib/commands/test.sh"
    source "$PYVE_ROOT/lib/commands/python.sh"
    create_test_dir
    bp_registry_reset
    plugin_registry_reset
    python_pyve_plugin_register_backends
}

teardown() {
    cleanup_test_dir
}

# ════════════════════════════════════════════════════════════════════
# S7 schema: manual_steps as a list field on [env.<name>].
# ════════════════════════════════════════════════════════════════════

@test "S7 schema: manifest_get_manual_steps returns declared list" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
manual_steps = ["Open Xcode and accept license", "Install device certificate"]
EOF
    manifest_load pyve.toml
    local -a steps
    manifest_get_manual_steps root steps
    [ "${#steps[@]}" -eq 2 ]
    [ "${steps[0]}" = "Open Xcode and accept license" ]
    [ "${steps[1]}" = "Install device certificate" ]
}

@test "S7 schema: manifest_get_manual_steps returns empty when not declared" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    local -a steps
    manifest_get_manual_steps root steps
    [ "${#steps[@]}" -eq 0 ]
}

@test "S7 schema: manifest_get_manual_steps returns 1 for unknown env" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
EOF
    manifest_load pyve.toml
    local -a steps
    run manifest_get_manual_steps nonexistent steps
    [ "$status" -eq 1 ]
}

# ════════════════════════════════════════════════════════════════════
# Shim existence — the four runtime hooks are defined.
# ════════════════════════════════════════════════════════════════════

@test "lifecycle: python_pyve_plugin_check is defined" {
    declare -F python_pyve_plugin_check >/dev/null
}

@test "lifecycle: python_pyve_plugin_status is defined" {
    declare -F python_pyve_plugin_status >/dev/null
}

@test "lifecycle: python_pyve_plugin_run is defined" {
    declare -F python_pyve_plugin_run >/dev/null
}

@test "lifecycle: python_pyve_plugin_test is defined" {
    declare -F python_pyve_plugin_test >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# plugin_dispatch routes runtime hooks to their delegates.
# ════════════════════════════════════════════════════════════════════

stub_runtime_targets() {
    eval '
        check_environment() { printf "check_environment ARGS=%s\n" "$*"; return 0; }
        show_status()       { printf "show_status ARGS=%s\n"       "$*"; return 0; }
        run_command()       { printf "run_command ARGS=%s\n"       "$*"; return 0; }
        test_tests()        { printf "test_tests ARGS=%s\n"        "$*"; return 0; }
    '
}

@test "dispatch: plugin_dispatch python run forwards args to run_command" {
    stub_runtime_targets
    plugin_register python
    run plugin_dispatch python run python --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"run_command ARGS=python --version"* ]]
}

@test "dispatch: plugin_dispatch python test forwards args to test_tests" {
    stub_runtime_targets
    plugin_register python
    run plugin_dispatch python test -v -k foo
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_tests ARGS=-v -k foo"* ]]
}

@test "dispatch: plugin_dispatch python check forwards args to check_environment" {
    stub_runtime_targets
    plugin_register python
    run plugin_dispatch python check
    [ "$status" -eq 0 ]
    [[ "$output" == *"check_environment ARGS="* ]]
}

@test "dispatch: plugin_dispatch python status forwards args to show_status" {
    stub_runtime_targets
    plugin_register python
    run plugin_dispatch python status
    [ "$status" -eq 0 ]
    [[ "$output" == *"show_status ARGS="* ]]
}

# ════════════════════════════════════════════════════════════════════
# S7 advisory rendering — `manual_steps` surfaces in check + status.
# ════════════════════════════════════════════════════════════════════

@test "S7: render_advisories prints manual_steps for each env that has them" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
manual_steps = ["Install Xcode 16", "Accept Apple Developer agreement"]
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
    [[ "$output" == *"Manual steps"* ]] || [[ "$output" == *"manual_steps"* ]]
    [[ "$output" == *"Install Xcode 16"* ]]
    [[ "$output" == *"Accept Apple Developer agreement"* ]]
}

@test "S7: render_advisories names the env owning the manual_steps" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.testenv]
purpose = "test"
backend = "venv"
manual_steps = ["Configure device certificate"]
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
    [[ "$output" == *"testenv"* ]]
    [[ "$output" == *"Configure device certificate"* ]]
}

@test "S7: render_advisories silent when no env has manual_steps" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "S7: render_advisories exit code is always 0 (advisories are informational)" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
manual_steps = ["Step 1"]
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
}

# ════════════════════════════════════════════════════════════════════
# S11 languages advisory in check — warn on simple gaps.
# ════════════════════════════════════════════════════════════════════
#
# Rule: when an env declares `languages` AND the declared list does
# NOT include "python", emit a warning (the Python plugin owns the
# env but the user has marked it as a different language).

@test "S11: env without languages → no warning" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
    [[ "$output" != *"languages"* ]]
}

@test "S11: env with languages = ['python'] → no warning" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
languages = ["python"]
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
    [[ "$output" != *"warning"* ]] || [[ "$output" != *"languages"* ]]
}

@test "S11: env with languages = ['rust'] (no python) → warning" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
languages = ["rust"]
EOF
    manifest_load pyve.toml
    run _python_pyve_plugin_render_advisories
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning"* ]] || [[ "$output" == *"Warning"* ]]
    [[ "$output" == *"languages"* ]]
}

# ════════════════════════════════════════════════════════════════════
# python_set / python_show relocation (Option (a)).
# ════════════════════════════════════════════════════════════════════
#
# Functions move into lib/plugins/python/plugin.sh; the python_command
# dispatcher in lib/commands/python.sh still calls them by name (bash
# resolves globally).

@test "relocation: python_set is defined in lib/plugins/python/plugin.sh" {
    grep -q '^python_set()' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
}

@test "relocation: python_show is defined in lib/plugins/python/plugin.sh" {
    grep -q '^python_show()' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
}

@test "relocation: python_set is NOT in lib/commands/python.sh (single owner)" {
    ! grep -q '^python_set()' "$PYVE_ROOT/lib/commands/python.sh"
}

@test "relocation: python_show is NOT in lib/commands/python.sh (single owner)" {
    ! grep -q '^python_show()' "$PYVE_ROOT/lib/commands/python.sh"
}

@test "relocation: python_command dispatcher still resolves python_show by name" {
    # Sanity: python_show is callable from the dispatcher (which is
    # in lib/commands/python.sh) after the relocation.
    declare -F python_show >/dev/null
    declare -F python_set >/dev/null
}
