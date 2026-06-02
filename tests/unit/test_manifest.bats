#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/manifest.sh — the v3.0 canonical manifest reader
# (Story N.a, Subphase N-1). Reads pyve.toml via the Python tomllib
# helper lib/pyve_toml_helper.py and exposes a flat accessor surface.
#
# Surface under test:
#   manifest_load [<pyve.toml path>]
#   manifest_list_envs
#   manifest_get_env <name>
#   manifest_get_purpose <name>
#   manifest_get_backend <name>
#   manifest_get_path <name>
#   manifest_get_app_type <name>
#   manifest_is_default <name>
#   manifest_is_lazy <name>
#   manifest_get_frameworks <name> <out_var>
#   manifest_get_languages <name> <out_var>
#   manifest_get_requirements <name> <out_var>

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/manifest.sh"
    # Capture an absolute path to a working python BEFORE create_test_dir
    # changes cwd (mirrors test_testenvs.bats).
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

# ---------- fixture helpers ----------

_fixture_full_manifest() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
path = "."
languages = ["python"]

[env.testenv]
purpose = "test"
backend = "venv"
default = true
requirements = ["requirements-dev.txt"]

[env.web]
purpose = "run"
backend = "pnpm"
path = "src/web"
app_type = "spa"
frameworks = ["sveltekit"]
languages = ["typescript"]
lazy = true
TOML
}

_fixture_empty_manifest() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "minimal"
TOML
}

_fixture_bad_schema() {
    cat > pyve.toml <<'TOML'
pyve_schema = "2.0"

[project]
name = "stale"
TOML
}

_fixture_bad_purpose() {
    cat > pyve.toml <<'TOML'
[env.x]
purpose = "deploy"
TOML
}

_fixture_two_defaults() {
    cat > pyve.toml <<'TOML'
[env.a]
default = true

[env.b]
default = true
TOML
}

_fixture_source_conflict() {
    cat > pyve.toml <<'TOML'
[env.x]
backend = "micromamba"
manifest = "env.yml"
requirements = ["dev.txt"]
TOML
}

# ============================================================
# 1. Round-trip parse: every documented field is readable
# ============================================================

@test "manifest_load: full manifest populates schema, project, env arrays" {
    _fixture_full_manifest
    manifest_load
    [ "$PYVE_SCHEMA_VERSION" = "3.0" ]
    [ "$PYVE_PROJECT_NAME" = "demo" ]
    [ "${#PYVE_ENV_NAMES[@]}" -eq 3 ]
    [[ " ${PYVE_ENV_NAMES[*]} " == *" root "* ]]
    [[ " ${PYVE_ENV_NAMES[*]} " == *" testenv "* ]]
    [[ " ${PYVE_ENV_NAMES[*]} " == *" web "* ]]
}

@test "manifest_get_purpose: returns declared purpose per env" {
    _fixture_full_manifest
    manifest_load
    [ "$(manifest_get_purpose root)" = "utility" ]
    [ "$(manifest_get_purpose testenv)" = "test" ]
    [ "$(manifest_get_purpose web)" = "run" ]
}

@test "manifest_get_backend: returns declared backend per env" {
    _fixture_full_manifest
    manifest_load
    [ "$(manifest_get_backend root)" = "venv" ]
    [ "$(manifest_get_backend web)" = "pnpm" ]
}

@test "manifest_get_path: returns declared path, defaults to '.'" {
    _fixture_full_manifest
    manifest_load
    [ "$(manifest_get_path root)" = "." ]
    [ "$(manifest_get_path web)" = "src/web" ]
    # testenv did not declare `path` → defaults to "."
    [ "$(manifest_get_path testenv)" = "." ]
}

@test "manifest_get_app_type: returns declared app_type, empty otherwise" {
    _fixture_full_manifest
    manifest_load
    [ "$(manifest_get_app_type web)" = "spa" ]
    [ -z "$(manifest_get_app_type root)" ]
}

@test "manifest_is_default: 0 for env with default=true, 1 otherwise" {
    _fixture_full_manifest
    manifest_load
    manifest_is_default testenv
    ! manifest_is_default root
    ! manifest_is_default web
}

@test "manifest_is_lazy: 0 for env with lazy=true, 1 otherwise" {
    _fixture_full_manifest
    manifest_load
    manifest_is_lazy web
    ! manifest_is_lazy root
    ! manifest_is_lazy testenv
}

@test "manifest_get_frameworks: populates caller-named array" {
    _fixture_full_manifest
    manifest_load
    declare -a fw=()
    manifest_get_frameworks web fw
    [ "${#fw[@]}" -eq 1 ]
    [ "${fw[0]}" = "sveltekit" ]
}

@test "manifest_get_languages: populates caller-named array" {
    _fixture_full_manifest
    manifest_load
    declare -a langs=()
    manifest_get_languages root langs
    [ "${#langs[@]}" -eq 1 ]
    [ "${langs[0]}" = "python" ]
}

@test "manifest_get_requirements: populates caller-named array" {
    _fixture_full_manifest
    manifest_load
    declare -a reqs=()
    manifest_get_requirements testenv reqs
    [ "${#reqs[@]}" -eq 1 ]
    [ "${reqs[0]}" = "requirements-dev.txt" ]
}

@test "manifest_list_envs: prints declared env names one per line" {
    _fixture_full_manifest
    manifest_load
    run manifest_list_envs
    [ "$status" -eq 0 ]
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"testenv"* ]]
    [[ "$output" == *"web"* ]]
}

@test "manifest_get_env: predicate is 0 for declared, 1 for unknown" {
    _fixture_full_manifest
    manifest_load
    manifest_get_env root
    manifest_get_env web
    ! manifest_get_env nonexistent
}

# ============================================================
# 2. Missing file → empty config (helper degrades gracefully)
# ============================================================

@test "manifest_load: no pyve.toml → empty config with defaulted schema" {
    # No pyve.toml in the test dir.
    manifest_load
    [ "$PYVE_SCHEMA_VERSION" = "3.0" ]
    [ "$PYVE_PROJECT_NAME" = "" ]
    [ "${#PYVE_ENV_NAMES[@]}" -eq 0 ]
}

@test "manifest_load: empty manifest (no [env.*]) yields zero envs" {
    _fixture_empty_manifest
    manifest_load
    [ "$PYVE_PROJECT_NAME" = "minimal" ]
    [ "${#PYVE_ENV_NAMES[@]}" -eq 0 ]
    run manifest_list_envs
    [ -z "$output" ]
}

# ============================================================
# 3. Validation errors (exit 2, stderr-prefixed)
# ============================================================

@test "manifest_load: bad pyve_schema errors with prefix + substring" {
    _fixture_bad_schema
    run manifest_load
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.pyve_schema"* ]]
    [[ "$output" == *"unknown schema version"* ]]
}

@test "manifest_load: invalid purpose errors with prefix + substring" {
    _fixture_bad_purpose
    run manifest_load
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.env.x.purpose"* ]]
    [[ "$output" == *"unknown purpose"* ]]
}

@test "manifest_load: multiple default=true envs errors" {
    _fixture_two_defaults
    run manifest_load
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.env"* ]]
    [[ "$output" == *"default"* ]]
}

@test "manifest_load: requirements + extra + manifest conflict errors" {
    _fixture_source_conflict
    run manifest_load
    [ "$status" -ne 0 ]
    [[ "$output" == *"pyve.env.x"* ]]
    [[ "$output" == *"only one of"* ]]
}

# ============================================================
# 4. manifest_resolve_purpose: explicit value wins over name-default
#    (Story N.d)
# ============================================================
#
# Resolution contract (lib/manifest.sh):
#   1. If env is in PYVE_ENV_NAMES with a non-empty declared `purpose`
#      → return the declared value.
#   2. Otherwise apply the name-based default:
#        env name "testenv" → "test"
#        env name "root"    → "utility"
#        otherwise          → "utility"
# Always returns one of {run, test, utility, temp}; never empty,
# never fail-1 (works even if the env is not declared in the manifest).

@test "manifest_resolve_purpose: explicit declared purpose wins" {
    _fixture_full_manifest
    manifest_load
    [ "$(manifest_resolve_purpose root)" = "utility" ]
    [ "$(manifest_resolve_purpose testenv)" = "test" ]
    [ "$(manifest_resolve_purpose web)" = "run" ]
}

@test "manifest_resolve_purpose: declared env with empty purpose falls back to name-default" {
    cat > pyve.toml <<'TOML'
[env.testenv]
backend = "venv"

[env.root]
backend = "venv"

[env.smoke]
backend = "venv"
TOML
    manifest_load
    # None of the three has an explicit `purpose`; name-based defaults
    # apply.
    [ "$(manifest_resolve_purpose testenv)" = "test" ]
    [ "$(manifest_resolve_purpose root)" = "utility" ]
    [ "$(manifest_resolve_purpose smoke)" = "utility" ]
}

@test "manifest_resolve_purpose: undeclared env applies name-default by name" {
    # No pyve.toml; manifest_load synthesizes an empty config.
    manifest_load
    [ "$(manifest_resolve_purpose testenv)" = "test" ]
    [ "$(manifest_resolve_purpose root)" = "utility" ]
    [ "$(manifest_resolve_purpose anything-else)" = "utility" ]
}

@test "manifest_resolve_purpose: works without prior manifest_load (PYVE_ENV_NAMES unset)" {
    # Fresh shell — manifest_load not called. The resolver must still
    # return a valid purpose for any name.
    output="$(/bin/bash -c "
        set -euo pipefail
        export PYVE_ROOT='$PYVE_ROOT'
        source '$PYVE_ROOT/lib/manifest.sh'
        manifest_resolve_purpose testenv
        printf ' '
        manifest_resolve_purpose root
        printf ' '
        manifest_resolve_purpose other
    " 2>&1)"
    [ "$output" = "test utility utility" ]
}

@test "manifest_resolve_purpose: explicit non-test purpose wins over name-default" {
    cat > pyve.toml <<'TOML'
[env.testenv]
purpose = "utility"
TOML
    manifest_load
    # Even though the name is "testenv", the explicit purpose wins.
    [ "$(manifest_resolve_purpose testenv)" = "utility" ]
}

@test "manifest_resolve_purpose: all four purpose values round-trip" {
    cat > pyve.toml <<'TOML'
[env.r]
purpose = "run"

[env.t]
purpose = "test"

[env.u]
purpose = "utility"

[env.x]
purpose = "temp"
TOML
    manifest_load
    [ "$(manifest_resolve_purpose r)" = "run" ]
    [ "$(manifest_resolve_purpose t)" = "test" ]
    [ "$(manifest_resolve_purpose u)" = "utility" ]
    [ "$(manifest_resolve_purpose x)" = "temp" ]
}

# ============================================================
# 5. Empty-array safety under `set -u` (project-essentials rule)
# ============================================================
#
# Sourcing lib/manifest.sh and calling each surface function from a
# fresh shell with `set -euo pipefail` must not raise 'unbound variable'.
# Catches the L.k.7-class regression on an empty config.

@test "no 'unbound variable' under 'set -euo pipefail' (no manifest; bash 3.2 trap)" {
    output="$(/bin/bash -c "
        set -euo pipefail
        export PYVE_ROOT='$PYVE_ROOT'
        source '$PYVE_ROOT/lib/manifest.sh'
        manifest_load
        manifest_list_envs >/dev/null
        manifest_get_env nonexistent || true
        manifest_get_purpose nonexistent || true
        manifest_get_backend nonexistent || true
        manifest_is_default nonexistent || true
        manifest_is_lazy nonexistent || true
    " 2>&1)" || true
    [[ "$output" != *"unbound variable"* ]] || {
        echo "stderr contained 'unbound variable':"
        echo "$output"
        false
    }
}
