#!/usr/bin/env bats
# bats file_tags=plugin
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Node runtime-resolution helpers (nvm / fnm / volta + PATH).
#
# Implements Node's S10 version-manager precedence: per-manager detectors
# (each gated by a PYVE_NO_<MGR>_COMPAT opt-out, mirroring is_asdf_active),
# a precedence walker `node_runtime_manager` (nvm > fnm > volta > asdf >
# PATH), and `node_runtime_resolve` returning the resolved `node` binary
# path (or failing loudly).
#
# Tests are hermetic: setup unsets any manager env leaked from the dev
# shell, then each test opts in to the managers it exercises. The `node`
# binary is a real stub on PATH so `command -v node` yields a path; the
# manager binaries are mocked (detection only checks presence + env).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    create_test_dir

    # Defensively clear any manager env inherited from the dev shell so
    # detection starts from a known-inactive baseline.
    unset NVM_DIR FNM_DIR FNM_MULTISHELL_PATH VOLTA_HOME
    unset PYVE_NO_NVM_COMPAT PYVE_NO_FNM_COMPAT PYVE_NO_VOLTA_COMPAT PYVE_NO_ASDF_COMPAT
    unmock_command fnm 2>/dev/null || true
    unmock_command volta 2>/dev/null || true
    unmock_command asdf 2>/dev/null || true
}

teardown() {
    unmock_command fnm 2>/dev/null || true
    unmock_command volta 2>/dev/null || true
    unmock_command asdf 2>/dev/null || true
    cleanup_test_dir
}

# Create a real `node` executable stub on PATH so command -v node → a path.
_make_node_stub() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/node" <<'EOF'
#!/usr/bin/env bash
echo v20.0.0
EOF
    chmod +x "$TEST_DIR/bin/node"
    export PATH="$TEST_DIR/bin:$PATH"
}

# Make nvm "active": NVM_DIR set to a dir containing a loadable nvm.sh.
_activate_nvm() {
    export NVM_DIR="$TEST_DIR/.nvm"
    mkdir -p "$NVM_DIR"
    printf '# fake nvm\n' > "$NVM_DIR/nvm.sh"
}

# ════════════════════════════════════════════════════════════════════
# is_nvm_active
# ════════════════════════════════════════════════════════════════════

@test "is_nvm_active: active when NVM_DIR set and nvm.sh present" {
    _activate_nvm
    run is_nvm_active
    [ "$status" -eq 0 ]
}

@test "is_nvm_active: inactive when NVM_DIR unset" {
    run is_nvm_active
    [ "$status" -ne 0 ]
}

@test "is_nvm_active: inactive when NVM_DIR set but nvm.sh missing" {
    export NVM_DIR="$TEST_DIR/.nvm"
    mkdir -p "$NVM_DIR"
    run is_nvm_active
    [ "$status" -ne 0 ]
}

@test "is_nvm_active: opt-out PYVE_NO_NVM_COMPAT disables detection" {
    _activate_nvm
    export PYVE_NO_NVM_COMPAT=1
    run is_nvm_active
    [ "$status" -ne 0 ]
}

# ════════════════════════════════════════════════════════════════════
# is_fnm_active
# ════════════════════════════════════════════════════════════════════

@test "is_fnm_active: active when fnm present and FNM_DIR set" {
    mock_command fnm 0 "fnm 1.0.0"
    export FNM_DIR="$TEST_DIR/.fnm"
    run is_fnm_active
    [ "$status" -eq 0 ]
}

@test "is_fnm_active: active when fnm present and FNM_MULTISHELL_PATH set" {
    mock_command fnm 0 "fnm 1.0.0"
    export FNM_MULTISHELL_PATH="$TEST_DIR/.fnm/ms"
    run is_fnm_active
    [ "$status" -eq 0 ]
}

@test "is_fnm_active: inactive when fnm present but no env signal" {
    mock_command fnm 0 "fnm 1.0.0"
    run is_fnm_active
    [ "$status" -ne 0 ]
}

@test "is_fnm_active: opt-out PYVE_NO_FNM_COMPAT disables detection" {
    mock_command fnm 0 "fnm 1.0.0"
    export FNM_DIR="$TEST_DIR/.fnm"
    export PYVE_NO_FNM_COMPAT=1
    run is_fnm_active
    [ "$status" -ne 0 ]
}

# ════════════════════════════════════════════════════════════════════
# is_volta_active
# ════════════════════════════════════════════════════════════════════

@test "is_volta_active: active when VOLTA_HOME set and volta present" {
    mock_command volta 0 "1.1.1"
    export VOLTA_HOME="$TEST_DIR/.volta"
    run is_volta_active
    [ "$status" -eq 0 ]
}

@test "is_volta_active: active via \$VOLTA_HOME/bin/volta when not on PATH" {
    export VOLTA_HOME="$TEST_DIR/.volta"
    mkdir -p "$VOLTA_HOME/bin"
    printf '#!/usr/bin/env bash\n' > "$VOLTA_HOME/bin/volta"
    chmod +x "$VOLTA_HOME/bin/volta"
    run is_volta_active
    [ "$status" -eq 0 ]
}

@test "is_volta_active: inactive when VOLTA_HOME unset" {
    mock_command volta 0 "1.1.1"
    run is_volta_active
    [ "$status" -ne 0 ]
}

@test "is_volta_active: opt-out PYVE_NO_VOLTA_COMPAT disables detection" {
    mock_command volta 0 "1.1.1"
    export VOLTA_HOME="$TEST_DIR/.volta"
    export PYVE_NO_VOLTA_COMPAT=1
    run is_volta_active
    [ "$status" -ne 0 ]
}

# ════════════════════════════════════════════════════════════════════
# node_runtime_manager — S10 precedence (nvm > fnm > volta > asdf > PATH)
# ════════════════════════════════════════════════════════════════════

@test "node_runtime_manager: nvm wins over all lower-priority managers" {
    _activate_nvm
    mock_command fnm 0 "fnm"; export FNM_DIR="$TEST_DIR/.fnm"
    mock_command volta 0 "volta"; export VOLTA_HOME="$TEST_DIR/.volta"
    run node_runtime_manager
    [ "$output" = "nvm" ]
}

@test "node_runtime_manager: fnm wins over volta when nvm inactive" {
    mock_command fnm 0 "fnm"; export FNM_DIR="$TEST_DIR/.fnm"
    mock_command volta 0 "volta"; export VOLTA_HOME="$TEST_DIR/.volta"
    run node_runtime_manager
    [ "$output" = "fnm" ]
}

@test "node_runtime_manager: volta selected when only volta active" {
    mock_command volta 0 "volta"; export VOLTA_HOME="$TEST_DIR/.volta"
    run node_runtime_manager
    [ "$output" = "volta" ]
}

@test "node_runtime_manager: asdf tier selected when asdf has a nodejs plugin" {
    mock_command asdf 0 "nodejs"
    run node_runtime_manager
    [ "$output" = "asdf" ]
}

@test "node_runtime_manager: asdf tier honors PYVE_NO_ASDF_COMPAT opt-out" {
    mock_command asdf 0 "nodejs"
    export PYVE_NO_ASDF_COMPAT=1
    run node_runtime_manager
    [ "$output" = "path" ]
}

@test "node_runtime_manager: PATH fallback when no manager active" {
    export PYVE_NO_ASDF_COMPAT=1   # ignore any real asdf+nodejs on the dev box
    run node_runtime_manager
    [ "$output" = "path" ]
}

# ════════════════════════════════════════════════════════════════════
# node_runtime_resolve — returns the node binary path, or fails loudly.
# ════════════════════════════════════════════════════════════════════

@test "node_runtime_resolve: returns the resolved node binary path" {
    _make_node_stub
    run node_runtime_resolve
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_DIR/bin/node" ]
}

@test "node_runtime_resolve: succeeds via PATH fallback when no manager active" {
    export PYVE_NO_ASDF_COMPAT=1
    _make_node_stub
    run node_runtime_resolve
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_DIR/bin/node" ]
}

@test "node_runtime_resolve: fails loudly when no node runtime is present" {
    mkdir -p "$TEST_DIR/empty"
    PATH="$TEST_DIR/empty" run node_runtime_resolve
    [ "$status" -ne 0 ]
    [[ "$output" == *"no Node runtime detected"* ]]
}
