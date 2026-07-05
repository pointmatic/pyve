#!/usr/bin/env bats
# bats file_tags=manifest
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Declarative env setup — schema + readers.
#
# An `[env.<name>]` block declares a COMPOSABLE recipe of directives. This
# story adds the `editable` directive (editable self-install + extras) and
# LIFTS the `requirements ⊕ extra ⊕ manifest` mutex so directives layer.
# Materialization (applying them in the fixed order) is the
# per-backend materializers' job, covered in their own suites.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/manifest.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

@test "editable directive: read into manifest_get_editable" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
[env.testenv]
purpose = "test"
editable = ".[corruptions]"
EOF
    manifest_load pyve.toml
    [ "$(manifest_get_editable testenv)" = ".[corruptions]" ]
}

@test "editable directive: empty when not declared" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml
    [ -z "$(manifest_get_editable root)" ]
}

@test "mutex lifted: editable + requirements + extra + manifest compose (validates clean)" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.testenv]
purpose = "test"
editable = "."
requirements = ["requirements-dev.txt"]
extra = "dev"
manifest = "environment.yml"
default = true
EOF
    run manifest_load pyve.toml
    [ "$status" -eq 0 ]
}

@test "back-compat: a requirements-only block still validates" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.testenv]
purpose = "test"
requirements = ["requirements-dev.txt"]
default = true
EOF
    run manifest_load pyve.toml
    [ "$status" -eq 0 ]
}

@test "back-compat: an extra-only block still validates" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.testenv]
purpose = "test"
extra = "dev"
default = true
EOF
    run manifest_load pyve.toml
    [ "$status" -eq 0 ]
}
