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
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/project_guide.sh"
    TEST_DIR="$(mktemp -d)"
    # Story N.bf.22: the scaffolding callsites now resolve project-guide via
    # pyve_project_guide (toolchain venv → ~/.local/bin shim → bare PATH).
    # Isolate HOME + XDG_DATA_HOME so neither hosted tier leaks the real
    # developer shim/venv; the fake-on-PATH then resolves via the bare tier.
    export HOME="$TEST_DIR/home"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    mkdir -p "$HOME"
    # Story N.bh: the callsites now lazily provision via
    # pyve_project_guide_ensure. Stub it to a no-op so orchestration tests
    # don't trigger a real toolchain-venv build; the fake is "hosted"
    # directly via the ~/.local/bin shim instead (see _make_hosted_pg).
    pyve_project_guide_ensure() { return 0; }
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fake HOSTED `project-guide` that logs its args. Story N.bh: the callsites
# only invoke project-guide when it's pyve-hosted, so install the fake at the
# ~/.local/bin shim tier (HOME is isolated) — pyve_project_guide resolves it
# and pyve_project_guide_is_hosted returns true.
_make_hosted_pg() {
    local shim_dir="$HOME/.local/bin"
    mkdir -p "$shim_dir"
    cat > "$shim_dir/project-guide" << EOF
#!/bin/bash
echo "\$@" >> "$TEST_DIR/pg-args.log"
exit 0
EOF
    chmod +x "$shim_dir/project-guide"
}

# pg_mode="yes" forces the install decision (skips prompt + deps auto-skip);
# comp_mode="no" skips completion wiring (no rc-file touch).

@test "orchestration: warns + non-fatal when project-guide hosting isn't set up" {
    PATH="/usr/bin:/bin" run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pyve self provision"* ]]
}

@test "orchestration: scaffolds via the hosted project-guide init when no .project-guide.yml" {
    _make_hosted_pg
    run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    grep -qF "init --no-input" "$TEST_DIR/pg-args.log"
}

@test "orchestration: refreshes via the hosted project-guide update when .project-guide.yml present" {
    _make_hosted_pg
    : > .project-guide.yml
    run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    grep -qF "update --no-input" "$TEST_DIR/pg-args.log"
}

@test "orchestration: does NOT pip-install project-guide per-project (no install_project_guide call)" {
    _make_hosted_pg
    # Sentinel: if the retired per-project install path were still wired,
    # this override would fire and drop the marker file.
    install_project_guide() { echo called > "$TEST_DIR/per-project-install.log"; }
    run run_project_guide_orchestration "venv" "/x" "yes" "no"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_DIR/per-project-install.log" ]
}

@test "orchestration: --no-project-guide skips entirely (no scaffold)" {
    _make_hosted_pg
    run run_project_guide_orchestration "venv" "/x" "no" "no"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_DIR/pg-args.log" ]
}
