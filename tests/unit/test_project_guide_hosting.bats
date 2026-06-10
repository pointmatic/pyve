#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# F2 (revised): host project-guide as a Pyve-managed global
# tool. Cycle 1 — the hosting MECHANISM in `pyve self install`/`uninstall`:
#   - install project-guide into the toolchain venv (best-effort, pinned)
#   - shim the console script onto ~/.local/bin (PATH-reachable in every shell)
#   - re-point the shim on a DEFAULT_PYTHON_VERSION bump (idempotent ln -sf)
#   - uninstall removes the shim (only if it's our symlink)
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/ui/run.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/commands/self.sh"

    TEST_DIR="$(mktemp -d)"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export HOME="$TEST_DIR/home"          # redirect ~/.local/bin shim target
    export DEFAULT_PYTHON_VERSION="3.14.4"
    unset PYVE_PYTHON
    unset PYVE_PROJECT_GUIDE_BIN
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Fabricate a provisioned toolchain venv whose `pip` is a no-op success and
# which already exposes a `project-guide` console script (the post-install
# state). $1 = "ok" (pip succeeds) | "fail" (pip exits non-zero).
_make_toolchain_venv() {
    local mode="${1:-ok}"
    local venv_dir bin
    venv_dir="$(pyve_toolchain_venv_dir)"
    bin="$venv_dir/bin"
    mkdir -p "$bin"
    if [[ "$mode" == "fail" ]]; then
        printf '#!/bin/sh\nexit 1\n' > "$bin/pip"
    else
        printf '#!/bin/sh\nexit 0\n' > "$bin/pip"
    fi
    chmod +x "$bin/pip"
    printf '#!/bin/sh\necho project-guide\n' > "$bin/project-guide"
    chmod +x "$bin/project-guide"
}

#------------------------------------------------------------
# Install + shim
#------------------------------------------------------------

@test "_self_install_project_guide: installs into the toolchain venv and shims it" {
    _make_toolchain_venv ok
    run _self_install_project_guide
    assert_status_equals 0
    [[ -L "$HOME/.local/bin/project-guide" ]]
}

@test "_self_install_project_guide: shim points at the toolchain venv's console script" {
    _make_toolchain_venv ok
    _self_install_project_guide
    local target
    target="$(readlink "$HOME/.local/bin/project-guide")"
    [[ "$target" == "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
}

@test "_self_install_project_guide: non-fatal + no shim when toolchain venv absent" {
    # No _make_toolchain_venv → no pip in the (unprovisioned) venv.
    run _self_install_project_guide
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "_self_install_project_guide: non-fatal when pip install fails (no shim)" {
    _make_toolchain_venv fail
    run _self_install_project_guide
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "_self_install_project_guide: re-points the shim after a version bump (idempotent)" {
    _make_toolchain_venv ok
    _self_install_project_guide
    # Simulate a DEFAULT_PYTHON_VERSION bump → a new version-keyed venv.
    export DEFAULT_PYTHON_VERSION="3.15.0"
    _make_toolchain_venv ok
    _self_install_project_guide
    local target
    target="$(readlink "$HOME/.local/bin/project-guide")"
    [[ "$target" == "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
    [[ "$target" == *"/3.15.0/"* ]]
}

#------------------------------------------------------------
# Uninstall
#------------------------------------------------------------

@test "_self_uninstall_project_guide: removes our shim symlink" {
    _make_toolchain_venv ok
    _self_install_project_guide
    [[ -L "$HOME/.local/bin/project-guide" ]]
    run _self_uninstall_project_guide
    assert_status_equals 0
    [[ ! -e "$HOME/.local/bin/project-guide" ]]
}

@test "_self_uninstall_project_guide: leaves a real (non-symlink) project-guide binary alone" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho real\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
    run _self_uninstall_project_guide
    assert_status_equals 0
    [[ -f "$HOME/.local/bin/project-guide" && ! -L "$HOME/.local/bin/project-guide" ]]
}

#------------------------------------------------------------
# Story N.bf.22: internal callsites must resolve the HOSTED project-guide
# absolute path, not bare `project-guide` on PATH — otherwise an active
# asdf shim dir (which precedes ~/.local/bin) hijacks the name and rejects
# it against the project's python pin. Same failure class as
# pyve_toolchain_python (N.at).
#------------------------------------------------------------

# Prepend a fake asdf shim that mimics asdf's "no version set" rejection:
# prints a marker on stderr and exits non-zero, like the real failure.
_prepend_asdf_shim() {
    local shimdir="$TEST_DIR/asdf-shims"
    mkdir -p "$shimdir"
    cat > "$shimdir/project-guide" <<'SH'
#!/bin/sh
echo "ASDF_SHIM_PG" >&2
echo "No version is set for command project-guide" >&2
exit 126
SH
    chmod +x "$shimdir/project-guide"
    export PATH="$shimdir:$PATH"
}

@test "pyve_project_guide: returns the toolchain venv console script when present" {
    _make_toolchain_venv ok
    run pyve_project_guide
    [[ "$output" == "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
}

@test "pyve_project_guide: falls back to the ~/.local/bin shim when no toolchain venv" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
    run pyve_project_guide
    [[ "$output" == "$HOME/.local/bin/project-guide" ]]
}

@test "pyve_project_guide: falls back to bare 'project-guide' when nothing is hosted" {
    run pyve_project_guide
    [[ "$output" == "project-guide" ]]
}

@test "pyve_project_guide_available: true when the hosted path is executable" {
    _make_toolchain_venv ok
    run pyve_project_guide_available
    assert_status_equals 0
}

#------------------------------------------------------------
# PYVE_PROJECT_GUIDE_BIN override — the explicit test/power-user seam,
# mirroring PYVE_PYTHON in pyve_toolchain_python. Internal callsites resolve
# project-guide by absolute path (toolchain venv → shim), which deliberately
# ignores PATH; an env override is the only way for a test to redirect the
# resolution to a stub. Honored at top precedence by every project-guide
# predicate so a set override is treated as a fully hosted, runnable binary.
#------------------------------------------------------------

# A standalone executable that is NOT under the toolchain venv or ~/.local/bin,
# proving the override outranks (and works without) real hosting.
_make_pg_override() {
    local script="$TEST_DIR/override-pg"
    cat > "$script" <<SH
#!/bin/sh
echo "OVERRIDE_PG ran: \$*"
exit ${1:-0}
SH
    chmod +x "$script"
    printf '%s' "$script"
}

@test "pyve_project_guide: PYVE_PROJECT_GUIDE_BIN overrides the toolchain venv console script" {
    _make_toolchain_venv ok            # real hosting present...
    local ov; ov="$(_make_pg_override)"
    export PYVE_PROJECT_GUIDE_BIN="$ov" # ...but the override wins
    run pyve_project_guide
    [[ "$output" == "$ov" ]]
}

@test "pyve_project_guide_is_hosted: true when PYVE_PROJECT_GUIDE_BIN points at an executable (no real hosting)" {
    local ov; ov="$(_make_pg_override)"
    export PYVE_PROJECT_GUIDE_BIN="$ov"
    run pyve_project_guide_is_hosted   # no toolchain venv, no shim
    assert_status_equals 0
}

@test "pyve_project_guide_ensure: no-op (no provisioning) when PYVE_PROJECT_GUIDE_BIN is set" {
    local ov; ov="$(_make_pg_override)"
    export PYVE_PROJECT_GUIDE_BIN="$ov"
    # No toolchain venv → ensure would normally try to build + pip-install.
    # With the override it must short-circuit to success without either.
    run pyve_project_guide_ensure
    assert_status_equals 0
    [[ ! -d "$(pyve_toolchain_venv_dir)" ]]
}

@test "run_project_guide_update_in_env: PYVE_PROJECT_GUIDE_BIN failure surfaces as a non-fatal warning" {
    local ov; ov="$(_make_pg_override 1)"   # override exits non-zero on update
    export PYVE_PROJECT_GUIDE_BIN="$ov"
    run run_project_guide_update_in_env
    assert_status_equals 0                   # non-fatal by design
    [[ "$output" == *"OVERRIDE_PG ran: update"* ]]
    [[ "$output" == *"failed"* ]]
}

@test "run_project_guide_init_in_env: invokes the hosted project-guide, not an asdf shim on PATH" {
    _prepend_asdf_shim
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"; mkdir -p "$bin"
    cat > "$bin/project-guide" <<'SH'
#!/bin/sh
echo "HOSTED_PG ran: $*"
exit 0
SH
    chmod +x "$bin/project-guide"
    run run_project_guide_init_in_env
    assert_status_equals 0
    [[ "$output" == *"HOSTED_PG ran: init"* ]]
    [[ "$output" != *"ASDF_SHIM_PG"* ]]
    [[ "$output" == *"project-guide artifacts generated"* ]]
}

@test "run_project_guide_update_in_env: invokes the hosted project-guide, not an asdf shim on PATH" {
    _prepend_asdf_shim
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"; mkdir -p "$bin"
    cat > "$bin/project-guide" <<'SH'
#!/bin/sh
echo "HOSTED_PG ran: $*"
exit 0
SH
    chmod +x "$bin/project-guide"
    run run_project_guide_update_in_env
    assert_status_equals 0
    [[ "$output" == *"HOSTED_PG ran: update"* ]]
    [[ "$output" != *"ASDF_SHIM_PG"* ]]
    [[ "$output" == *"project-guide artifacts refreshed"* ]]
}

#------------------------------------------------------------
# Story N.bh: lazy, install-method-agnostic provisioning. project-guide
# hosting is provisioned on first opt-in use (not only by `self install`,
# which no-ops for Homebrew). The ensure is idempotent + presence-gated —
# a no-op stat when already hosted, a provision when missing. On a genuine
# provisioning failure the callsites skip generically and NEVER invoke the
# bare asdf shim (no asdf-internal error leak).
#------------------------------------------------------------

# A toolchain-build stub: fabricates the venv + a `pip` that, on
# `install … project-guide…`, writes a project-guide console script next
# to itself. Wire it in as the `pyve_toolchain_python_ensure` stub.
_stub_toolchain_build_ok() {
    pyve_toolchain_python_ensure() {
        local bin; bin="$(pyve_toolchain_venv_dir)/bin"; mkdir -p "$bin"
        cat > "$bin/pip" <<'SH'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
case "$*" in
  *project-guide*) printf '#!/bin/sh\necho "HOSTED_PG ran: $*"\n' > "$dir/project-guide"; chmod +x "$dir/project-guide" ;;
esac
exit 0
SH
        chmod +x "$bin/pip"
        return 0
    }
}

@test "pyve_project_guide_ensure: no-op (no pip call) when already hosted" {
    _make_toolchain_venv ok
    # Replace pip with a recorder; the fast path must not invoke it.
    local bin; bin="$(pyve_toolchain_venv_dir)/bin"
    cat > "$bin/pip" <<SH
#!/bin/sh
echo CALLED > "$TEST_DIR/pip-called"
exit 0
SH
    chmod +x "$bin/pip"
    run pyve_project_guide_ensure
    assert_status_equals 0
    [ ! -f "$TEST_DIR/pip-called" ]
}

@test "pyve_project_guide_ensure: provisions (venv + project-guide + shim) when missing" {
    _stub_toolchain_build_ok
    run pyve_project_guide_ensure
    assert_status_equals 0
    [[ -x "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
    [[ -L "$HOME/.local/bin/project-guide" ]]
}

@test "pyve_project_guide_ensure: returns non-zero when the toolchain build fails" {
    pyve_toolchain_python_ensure() { return 1; }
    run pyve_project_guide_ensure
    [ "$status" -ne 0 ]
}

@test "pyve_project_guide_is_hosted: true when hosted, false when only a bare/asdf shim resolves" {
    run pyve_project_guide_is_hosted
    [ "$status" -ne 0 ]          # nothing hosted yet
    _make_toolchain_venv ok
    run pyve_project_guide_is_hosted
    assert_status_equals 0       # toolchain console script present
}

@test "run_project_guide_init_in_env: unhosted + asdf shim → auto-provisions, no asdf leak" {
    _prepend_asdf_shim
    _stub_toolchain_build_ok
    run run_project_guide_init_in_env
    assert_status_equals 0
    [[ "$output" == *"HOSTED_PG ran: init"* ]]
    [[ "$output" != *"No version is set"* ]]
    [[ "$output" != *"ASDF_SHIM_PG"* ]]
}

@test "run_project_guide_init_in_env: unhosted + provision fails → generic skip, no asdf leak, non-fatal" {
    _prepend_asdf_shim
    pyve_toolchain_python_ensure() { return 1; }
    run run_project_guide_init_in_env
    assert_status_equals 0
    [[ "$output" != *"No version is set"* ]]
    [[ "$output" != *"ASDF_SHIM_PG"* ]]
}

@test "self provision: provisions hosting without installing the pyve binary or touching PATH" {
    _stub_toolchain_build_ok
    run self_provision
    assert_status_equals 0
    # project-guide hosting is provisioned...
    [[ -x "$(pyve_toolchain_venv_dir)/bin/project-guide" ]]
    [[ -L "$HOME/.local/bin/project-guide" ]]
    # ...but the pyve binary is NOT installed and PATH is not rewritten
    # (that's `self install`'s job; provision is brew-safe).
    [ ! -e "$HOME/.local/bin/pyve" ]
}
