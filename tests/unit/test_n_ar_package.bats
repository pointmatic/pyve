#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.ar — `pyve package [--env <name>]` verb (reserved-verb behavior).
#
# `pyve package` materializes an env's declared `packaging` artifact by
# dispatching to a registered packaging provider (N.aq registry). In v3.0
# ZERO providers register, so the live behavior is the "reserved" advisory:
# accept the declared packaging value and exit 0 with a clean message,
# rather than "unknown command". A post-v3.0 provider drops in with no
# breaking change. The registered-provider dispatch path is exercised here
# only via a test-only stub provider.
#
# Surface under test (lib/commands/package.sh):
#   package_environment [--env <name>] [-h|--help]
#   show_package_help
#
# Behavior branches (per the story):
#   - provider registered      → dispatch its `package` hook
#   - packaging set, no provider→ advisory, exit 0, "reserved for a future release"
#   - packaging absent / "none" → informational, exit 0, "no packaging artifact"
#   - unknown env              → hard error, non-zero
#   - --help                   → usage text

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/packaging_registry.sh"
    source "$PYVE_ROOT/lib/commands/package.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
    pp_registry_reset
}

teardown() {
    cleanup_test_dir
}

# ---------- fixtures ----------

# Single default env carrying a packaging declaration + a provider-private
# key (which core stores but never interprets).
_fixture_docker_default() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.app]
purpose = "run"
backend = "venv"
default = true
packaging = "docker"
dockerfile = "ops/Dockerfile"
TOML
}

# Two envs: a non-default one declaring packaging, and a default one with
# no packaging artifact. Lets us test explicit --env + the "none" path.
_fixture_mixed() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
default = true

[env.web]
purpose = "run"
backend = "pnpm"
packaging = "docker"
TOML
}

# ====================================================================
# Default-env resolution (no --env) → the env marked default = true.
# ====================================================================

@test "package: no --env resolves the default env's packaging (advisory)" {
    _fixture_docker_default
    run package_environment
    [ "$status" -eq 0 ]
    [[ "$output" == *"app"* ]]
    [[ "$output" == *"docker"* ]]
    [[ "$output" == *"reserved for a future release"* ]]
}

# ====================================================================
# Explicit --env resolution (both --env <name> and --env=<name>).
# ====================================================================

@test "package: --env <name> targets the named env" {
    _fixture_mixed
    run package_environment --env web
    [ "$status" -eq 0 ]
    [[ "$output" == *"web"* ]]
    [[ "$output" == *"docker"* ]]
    [[ "$output" == *"reserved for a future release"* ]]
}

@test "package: --env=<name> form is accepted" {
    _fixture_mixed
    run package_environment --env=web
    [ "$status" -eq 0 ]
    [[ "$output" == *"reserved for a future release"* ]]
}

# ====================================================================
# Reserved advisory: packaging declared but no provider registered.
# Exit 0 — the v3.0 reserve-the-verb contract.
# ====================================================================

@test "package: packaging declared, no provider → advisory exit 0" {
    _fixture_docker_default
    run package_environment --env app
    [ "$status" -eq 0 ]
    [[ "$output" == *"reserved for a future release"* ]]
}

# ====================================================================
# Informational: env declares no packaging artifact.
# ====================================================================

@test "package: env with no packaging → informational exit 0" {
    _fixture_mixed
    run package_environment --env root
    [ "$status" -eq 0 ]
    [[ "$output" == *"no packaging artifact"* ]]
    [[ "$output" != *"reserved for a future release"* ]]
}

@test "package: packaging = \"none\" is treated as no artifact" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"
[project]
name = "demo"
[env.app]
default = true
packaging = "none"
TOML
    run package_environment
    [ "$status" -eq 0 ]
    [[ "$output" == *"no packaging artifact"* ]]
}

# ====================================================================
# Hard error: unknown / undeclared env.
# ====================================================================

@test "package: unknown --env hard-errors (non-zero)" {
    _fixture_mixed
    run package_environment --env ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"ghost"* ]]
    [[ "$output" == *"not declared"* ]]
}

# ====================================================================
# Registered-provider dispatch — exercised only by a test stub in v3.0.
# ====================================================================

@test "package: registered provider's package hook is dispatched" {
    _fixture_docker_default
    eval '
        docker_pyve_pp_package() {
            printf "STUB-PACKAGED env=%s" "$1"
        }
    '
    pp_register docker_provider docker
    run package_environment --env app
    [ "$status" -eq 0 ]
    [[ "$output" == *"STUB-PACKAGED env=app"* ]]
    # The reserved advisory must NOT fire when a provider handled it.
    [[ "$output" != *"reserved for a future release"* ]]
}

# ====================================================================
# Help.
# ====================================================================

@test "package: --help prints usage" {
    run package_environment --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve package"* ]]
    [[ "$output" == *"--env"* ]]
}

@test "package: -h prints usage" {
    run package_environment -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve package"* ]]
}

# ====================================================================
# Integration — the real binary: dispatcher wiring + sourcing.
# ====================================================================

@test "package (integration): pyve.sh dispatches 'package' to the verb" {
    _fixture_docker_default
    run env PYVE_PYTHON="$PYVE_PYTHON" PYVE_QUIET=1 bash "$PYVE_ROOT/pyve.sh" package
    [ "$status" -eq 0 ]
    [[ "$output" == *"reserved for a future release"* ]]
}

@test "package (integration): pyve.sh 'package --help' shows usage" {
    run env PYVE_PYTHON="$PYVE_PYTHON" PYVE_QUIET=1 bash "$PYVE_ROOT/pyve.sh" package --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve package"* ]]
}

@test "package (integration): unknown --env exits non-zero" {
    _fixture_mixed
    run env PYVE_PYTHON="$PYVE_PYTHON" PYVE_QUIET=1 bash "$PYVE_ROOT/pyve.sh" package --env ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"not declared"* ]]
}
