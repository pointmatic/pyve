#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# advisory recognition + surfacing + skip-materialization.
#
# The "known-advisory → record + surface, skip materialization" arm of the
# trichotomy:
#   - the two advisory-only fields (require_min_version, manual_steps) are
#     parsed/stored/emitted, never materialized;
#   - `pyve_toml_helper.py advisories <pyve.toml>` emits per-attribute advisory
#     notes (using FRAMEWORK_KIND / BACKEND_CATEGORY), `none` and implemented
#     values silent;
#   - `pyve_toml_helper.py classify <axis> <value>` exposes the classifier;
#   - the env materializer skips an advisory backend with the §B no-op advisory;
#   - check/status surface the advisory notes as a project-level addendum.
#============================================================

load ../helpers/test_helper

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    HELPER="$PYVE_ROOT/lib/pyve_toml_helper.py"
    PY="$PYVE_PYTHON"
    create_test_dir
    export NO_COLOR=1
}

teardown() { cleanup_test_dir; }

# Write a pyve.toml with [project] + an [env.<name>] whose body is $2.
_toml_env() {
    local name="$1" body="$2"
    cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "demo"

[env.$name]
$body
EOF
}

# ════════════════════════════════════════════════════════════════════
# Task 1 — recognize advisory fields (require_min_version, manual_steps).
# ════════════════════════════════════════════════════════════════════

@test "require_min_version: parsed + emitted as a per-index tool=ver array" {
    _toml_env tools 'purpose = "utility"
backend = "xcode"
require_min_version = { xcode = "15.0", swift = "5.9" }'
    run "$PY" "$HELPER" pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"PYVE_ENV_0_REQUIRE_MIN_VERSION="* ]]
    [[ "$output" == *"xcode=15.0"* ]]
    [[ "$output" == *"swift=5.9"* ]]
}

@test "require_min_version: not leaked into the provider-private attrs array" {
    _toml_env tools 'purpose = "utility"
backend = "xcode"
require_min_version = { xcode = "15.0" }'
    run "$PY" "$HELPER" pyve.toml
    [ "$status" -eq 0 ]
    # The ATTRS array must not carry the recognized advisory field.
    [[ "$output" != *"PYVE_ENV_0_ATTRS=(xcode="* ]]
    [[ "$output" != *"require_min_version="* ]]
}

@test "manual_steps: parsed + emitted (regression — already normalized)" {
    _toml_env tools 'purpose = "utility"
backend = "none"
manual_steps = ["configure signing in Xcode", "enable provisioning"]'
    run "$PY" "$HELPER" pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"PYVE_ENV_MANUAL_STEPS_Q="* ]]
    [[ "$output" == *"configure signing in Xcode"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Task 3 helper — classify <axis> <value>.
# ════════════════════════════════════════════════════════════════════

@test "classify: advisory / implemented / unknown" {
    run "$PY" "$HELPER" classify backend homebrew
    [ "$status" -eq 0 ]; [[ "$output" == "advisory" ]]

    run "$PY" "$HELPER" classify backend venv
    [ "$status" -eq 0 ]; [[ "$output" == "implemented" ]]

    run "$PY" "$HELPER" classify backend not_a_backend
    [ "$status" -eq 0 ]; [[ "$output" == "unknown" ]]
}

# ════════════════════════════════════════════════════════════════════
# Task 2 — `advisories` mode: per-attribute notes.
# ════════════════════════════════════════════════════════════════════

@test "advisories: advisory backend surfaced with category + no-op wording" {
    _toml_env tools 'purpose = "utility"
backend = "homebrew"'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"tools"* ]]
    [[ "$output" == *"homebrew"* ]]
    [[ "$output" == *"check-only"* ]]            # BACKEND_CATEGORY
    [[ "$output" == *"does not materialize"* ]]  # §B no-op wording
}

@test "advisories: implemented backend (venv) is NOT surfaced" {
    _toml_env worker 'purpose = "test"
backend = "venv"'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" != *"venv"* ]]
}

@test "advisories: backend 'none' is NOT surfaced (no noise)" {
    _toml_env meta 'purpose = "utility"
backend = "none"'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" != *"none"* ]]
}

@test "advisories: advisory framework surfaced with intrinsic kind" {
    _toml_env api 'purpose = "test"
backend = "venv"
frameworks = ["pytest"]'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"pytest"* ]]
    [[ "$output" == *"test"* ]]   # FRAMEWORK_KIND[pytest] == test
}

@test "advisories: implemented framework (sveltekit) is NOT surfaced" {
    _toml_env web 'purpose = "run"
backend = "npm"
frameworks = ["sveltekit"]'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" != *"sveltekit"* ]]
}

@test "advisories: advisory language surfaced, implemented language not" {
    _toml_env svc 'purpose = "utility"
backend = "venv"
languages = ["python", "rust"]'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"rust"* ]]
    [[ "$output" != *"python"* ]]
}

@test "advisories: advisory packaging + app_type surfaced; none silent" {
    _toml_env app 'purpose = "run"
backend = "venv"
packaging = "container"
app_type = "cli"'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"container"* ]]
    [[ "$output" == *"cli"* ]]
}

@test "advisories: require_min_version + manual_steps surfaced" {
    _toml_env ios 'purpose = "utility"
backend = "xcode"
require_min_version = { xcode = "15.0" }
manual_steps = ["sign the build"]'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ "$output" == *"xcode"* ]]
    [[ "$output" == *"15.0"* ]]
    [[ "$output" == *"sign the build"* ]]
}

@test "advisories: a fully-implemented project emits no notes" {
    _toml_env worker 'purpose = "test"
backend = "venv"
languages = ["python"]
app_type = "none"'
    run "$PY" "$HELPER" advisories pyve.toml
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

# ════════════════════════════════════════════════════════════════════
# Task 3 — skip materialization of advisory backends.
# ════════════════════════════════════════════════════════════════════

@test "_env_backend_is_advisory: advisory vs implemented" {
    source "$PYVE_ROOT/lib/envs.sh"
    run _env_backend_is_advisory homebrew
    [ "$status" -eq 0 ]
    run _env_backend_is_advisory venv
    [ "$status" -ne 0 ]
}

@test "_env_install_with_lock: advisory backend skips with §B advisory, rc 0, no env" {
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    PYVE_TESTENVS_NAMES=("tools")
    PYVE_TESTENV_BACKEND=("homebrew")
    PYVE_TESTENV_LAZY=("0")
    PYVE_TESTENV_EXTRA=("")
    PYVE_TESTENV_MANIFEST=("")
    PYVE_TESTENV_REQUIREMENTS_Q=("")
    run _env_install_with_lock tools "$PWD/.pyve/envs/tools/venv" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not yet materialize"* ]]
    [[ ! -d "$PWD/.pyve/envs/tools/venv" ]]
}

# ════════════════════════════════════════════════════════════════════
# Task 2 wiring — check / status surface the advisory addendum.
# ════════════════════════════════════════════════════════════════════

@test "compose_check: advisory env surfaces an advisory addendum section" {
    source "$PYVE_ROOT/lib/check_composer.sh"
    _toml_env tools 'purpose = "utility"
backend = "homebrew"'
    run compose_check
    [ "$status" -eq 0 ]   # advisory is informational, never fails
    [[ "$output" == *"homebrew"* ]]
    [[ "$output" == *"advisor"* ]]
}

@test "compose_status: advisory env surfaces an advisory addendum section" {
    source "$PYVE_ROOT/lib/status_composer.sh"
    _toml_env tools 'purpose = "utility"
backend = "homebrew"'
    run compose_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"homebrew"* ]]
}

@test "compose_check: clean project emits no advisory addendum" {
    source "$PYVE_ROOT/lib/check_composer.sh"
    _toml_env worker 'purpose = "test"
backend = "venv"'
    run compose_check
    [[ "$output" != *"advisor"* ]]
}
