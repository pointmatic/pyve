#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Shim reachability — the third rung of existence → runnable → reachable.
#
# Pyve hosts project-guide in a private toolchain venv and shims it onto
# ~/.local/bin. That only helps if the user's shell can see that
# directory, and for a long time only `pyve self install` wrote the PATH
# entry — so a Homebrew-installed pyve hosted the tool perfectly and left
# it uninvocable, while every health surface correctly said "provisioned".
#
# The single-global-install construct is Pyve's invention, so its
# reachability is Pyve's to own: provisioning wires the entry, `check`
# reports it, and `check --fix` repairs it through the SAME helper.
#
# Covered here:
#   - the profile-file choice (login shell, by design)
#   - live-PATH vs profile-marker idempotency (both must no-op)
#   - the PYVE_NO_PATH_WIRING opt-out
#   - the tri-state reachability probe (reachable/unreachable/shadowed)
#   - the field shape: an ALREADY-hosted machine self-repairs, which the
#     presence fast path in pyve_project_guide_ensure would otherwise skip
#   - the heal fault class + its repair
#============================================================

load ../helpers/test_helper

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    source "$PYVE_ROOT/lib/heal.sh"

    TEST_DIR="$(mktemp -d)"
    # $HOME isolation is mandatory here — these helpers WRITE to a profile
    # file. A test that leaks would append to the developer's real shell
    # config (the P.v lesson, in miniature).
    export HOME="$TEST_DIR/home"
    export XDG_DATA_HOME="$HOME/.local/share"
    mkdir -p "$HOME"
    unset PYVE_PYTHON PYVE_PROJECT_GUIDE_BIN PYVE_NO_PATH_WIRING
    export SHELL=/bin/zsh
    export DEFAULT_PYTHON_VERSION="3.14.4"
    # A PATH with no ~/.local/bin — the field condition on a Homebrew install.
    export PATH="/usr/bin:/bin"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# A hosted, runnable project-guide: the toolchain console script plus the
# ~/.local/bin shim pointing at it.
_host_project_guide() {
    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"
    mkdir -p "$venv_dir/bin" "$HOME/.local/bin"
    cat > "$venv_dir/bin/project-guide" << 'SH'
#!/usr/bin/env bash
echo "project-guide, version 2.18.1"
SH
    chmod +x "$venv_dir/bin/project-guide"
    ln -sf "$venv_dir/bin/project-guide" "$HOME/.local/bin/project-guide"
}

#============================================================
# pyve_path_profile_file — a LOGIN-shell file, deliberately
#============================================================

@test "profile file: zsh gets ~/.zprofile (login), not ~/.zshrc" {
    SHELL=/bin/zsh
    run pyve_path_profile_file
    [ "$output" = "$HOME/.zprofile" ]
}

@test "profile file: bash gets ~/.bash_profile" {
    SHELL=/bin/bash
    unset ZSH_VERSION
    run pyve_path_profile_file
    [ "$output" = "$HOME/.bash_profile" ]
}

#============================================================
# pyve_local_bin_on_path — live truth
#============================================================

@test "on_path: false when ~/.local/bin is absent from PATH" {
    run pyve_local_bin_on_path
    [ "$status" -ne 0 ]
}

@test "on_path: true when ~/.local/bin is on PATH" {
    PATH="$HOME/.local/bin:$PATH"
    run pyve_local_bin_on_path
    [ "$status" -eq 0 ]
}

@test "on_path: substring near-miss does not count as present" {
    # ~/.local/binaries must not satisfy the ~/.local/bin check.
    PATH="$HOME/.local/binaries:/usr/bin:/bin"
    run pyve_local_bin_on_path
    [ "$status" -ne 0 ]
}

#============================================================
# pyve_ensure_local_bin_on_path — idempotent on BOTH conditions
#============================================================

@test "ensure: writes the PATH entry when neither PATH nor profile has it" {
    run pyve_ensure_local_bin_on_path
    [ "$status" -eq 0 ]
    [ -f "$HOME/.zprofile" ]
    grep -qF '# Added by pyve installer' "$HOME/.zprofile"
    grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zprofile"
}

@test "ensure: no-op when ~/.local/bin is already on the live PATH" {
    PATH="$HOME/.local/bin:$PATH"
    run pyve_ensure_local_bin_on_path
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.zprofile" ]
}

@test "ensure: idempotent — a second call does not duplicate the entry" {
    pyve_ensure_local_bin_on_path
    pyve_ensure_local_bin_on_path
    pyve_ensure_local_bin_on_path
    local count
    count="$(grep -cF '# Added by pyve installer' "$HOME/.zprofile")"
    [ "$count" -eq 1 ]
}

@test "ensure: recognizes an entry written by an older pyve (marker unchanged)" {
    # A line from a previous `self install` must be honored, not doubled.
    printf '\nexport PATH="$HOME/.local/bin:$PATH"  # Added by pyve installer\n' \
        > "$HOME/.zprofile"
    run pyve_ensure_local_bin_on_path
    [ "$status" -eq 0 ]
    local count
    count="$(grep -cF '# Added by pyve installer' "$HOME/.zprofile")"
    [ "$count" -eq 1 ]
}

@test "ensure: preserves existing profile content" {
    printf 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"\n' > "$HOME/.zprofile"
    pyve_ensure_local_bin_on_path
    grep -qF 'brew shellenv' "$HOME/.zprofile"
    grep -qF '# Added by pyve installer' "$HOME/.zprofile"
}

@test "ensure: PYVE_NO_PATH_WIRING=1 opts out entirely" {
    export PYVE_NO_PATH_WIRING=1
    run pyve_ensure_local_bin_on_path
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.zprofile" ]
}

#============================================================
# pyve_project_guide_reachable — tri-state
#============================================================

@test "reachable: 1 (unreachable) when the shim exists but is off PATH" {
    _host_project_guide
    run pyve_project_guide_reachable
    [ "$status" -eq 1 ]
}

@test "reachable: 0 when a bare project-guide resolves to the pyve shim" {
    _host_project_guide
    PATH="$HOME/.local/bin:$PATH"
    run pyve_project_guide_reachable
    [ "$status" -eq 0 ]
}

@test "reachable: 2 (shadowed) when another project-guide wins on PATH" {
    _host_project_guide
    local foreign="$TEST_DIR/foreign"
    mkdir -p "$foreign"
    printf '#!/usr/bin/env bash\necho other\n' > "$foreign/project-guide"
    chmod +x "$foreign/project-guide"
    PATH="$foreign:$HOME/.local/bin:$PATH"
    run pyve_project_guide_reachable
    [ "$status" -eq 2 ]
}

@test "reachable: an explicit PYVE_PROJECT_GUIDE_BIN override always reads reachable" {
    export PYVE_PROJECT_GUIDE_BIN="$TEST_DIR/stub"
    run pyve_project_guide_reachable
    [ "$status" -eq 0 ]
}

#============================================================
# The field shape — an ALREADY-provisioned machine must self-repair.
#
# pyve_project_guide_ensure fast-paths on `[[ -x "$target" ]]`, so if the
# PATH wiring sat after that stat, every existing user would be stranded
# forever: provisioning returns immediately and never reaches it. This is
# why option 1 alone could not fix the installed base.
#============================================================

@test "ensure(field): an already-hosted machine still gets the PATH entry" {
    _host_project_guide
    # Precondition: the fast path WILL trigger (the console script exists).
    [ -x "$(pyve_toolchain_venv_dir)/bin/project-guide" ]

    run pyve_project_guide_ensure
    [ "$status" -eq 0 ]
    grep -qF '# Added by pyve installer' "$HOME/.zprofile"
}

@test "ensure(field): no PATH entry is written when pyve hosts nothing" {
    # No shim → the entry would point at a directory pyve never populated.
    run pyve_project_guide_ensure
    [ ! -f "$HOME/.zprofile" ]
}

#============================================================
# heal — the fault class and its repair
#============================================================

@test "heal plan: shim-unreachable is reported when the shim is off PATH" {
    _host_project_guide
    run _heal_plan_project_guide "$(pyve_toolchain_venv_dir)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"shim-unreachable"* ]]
}

@test "heal plan: no shim-unreachable once ~/.local/bin is on PATH" {
    _host_project_guide
    PATH="$HOME/.local/bin:$PATH"
    run _heal_plan_project_guide "$(pyve_toolchain_venv_dir)"
    [[ "$output" != *"shim-unreachable"* ]]
}

@test "heal plan: no shim-unreachable once the profile already carries the entry" {
    # Live PATH still lacks it (this shell), but future shells have it —
    # so there is nothing left to repair.
    _host_project_guide
    pyve_ensure_local_bin_on_path
    run _heal_plan_project_guide "$(pyve_toolchain_venv_dir)"
    [[ "$output" != *"shim-unreachable"* ]]
}

@test "heal plan: no shim-unreachable when pyve hosts nothing" {
    run _heal_plan_project_guide "$(pyve_toolchain_venv_dir)"
    [[ "$output" != *"shim-unreachable"* ]]
}

@test "heal: shim-unreachable is non-destructive (additive, reversible)" {
    run _heal_is_destructive shim-unreachable
    [ "$status" -ne 0 ]
}

@test "heal repair: shim-unreachable writes the entry via the shared helper" {
    _host_project_guide
    run heal_apply shim-unreachable
    [ "$status" -eq 0 ]
    grep -qF '# Added by pyve installer' "$HOME/.zprofile"
}

@test "heal repair: re-running after a successful repair finds nothing (idempotent)" {
    _host_project_guide
    heal_apply shim-unreachable
    run _heal_plan_project_guide "$(pyve_toolchain_venv_dir)"
    [[ "$output" != *"shim-unreachable"* ]]
}
