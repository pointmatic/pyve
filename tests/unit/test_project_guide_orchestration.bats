#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# retire per-project provisioning. `run_project_guide_
# orchestration` no longer pip-installs project-guide into a project env;
# it scaffolds via the GLOBAL `project-guide` (the N.aw.1 ~/.local/bin
# shim) and warns when that global tool is absent.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/ui/run.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/project_guide.sh"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fake global `project-guide` that logs its args. Prepend $pgbin to PATH.
_fake_global_pg() {
    local pgbin="$TEST_DIR/pgbin"
    mkdir -p "$pgbin"
    cat > "$pgbin/project-guide" << EOF
#!/bin/bash
echo "\$@" >> "$TEST_DIR/pg-args.log"
exit 0
EOF
    chmod +x "$pgbin/project-guide"
    printf '%s' "$pgbin"
}

# pg_mode="yes" forces the install decision (skips prompt + deps auto-skip);
# comp_mode="no" skips completion wiring (no rc-file touch).

@test "orchestration: warns + non-fatal when project-guide is not on PATH" {
    PATH="/usr/bin:/bin" run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self install"* ]]
}

@test "orchestration: scaffolds via the GLOBAL project-guide init when no .project-guide.yml" {
    local pgbin; pgbin="$(_fake_global_pg)"
    PATH="$pgbin:$PATH" run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    grep -qF "init --no-input" "$TEST_DIR/pg-args.log"
}

@test "orchestration: refreshes via the GLOBAL project-guide update when .project-guide.yml present" {
    local pgbin; pgbin="$(_fake_global_pg)"
    : > .project-guide.yml
    PATH="$pgbin:$PATH" run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    grep -qF "update --no-input" "$TEST_DIR/pg-args.log"
}

@test "orchestration: does NOT pip-install project-guide per-project (no install_project_guide call)" {
    local pgbin; pgbin="$(_fake_global_pg)"
    # Sentinel: if the retired per-project install path were still wired,
    # this override would fire and drop the marker file.
    install_project_guide() { echo called > "$TEST_DIR/per-project-install.log"; }
    PATH="$pgbin:$PATH" run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_DIR/per-project-install.log" ]
}

@test "orchestration: --no-project-guide skips entirely (no scaffold)" {
    local pgbin; pgbin="$(_fake_global_pg)"
    PATH="$pgbin:$PATH" run run_project_guide_orchestration "venv" "/x" "no" "no"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_DIR/pg-args.log" ]
}
