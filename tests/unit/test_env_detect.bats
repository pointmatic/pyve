#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for lib/env_detect.sh. Each test installs PATH-shims for
# asdf / pyenv / direnv so coverage reaches the interesting branches
# without requiring those tools on the CI runner. See Story I.j.

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    create_test_dir

    export ORIGINAL_HOME="$HOME"
    export ORIGINAL_PATH="$PATH"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    export SHIM_DIR="$TEST_DIR/bin"
    mkdir -p "$SHIM_DIR"
    # Tests opt into a shim by calling make_asdf_shim / make_pyenv_shim /
    # make_direnv_shim; default PATH is scrubbed of the real host binaries.
    export PATH="$SHIM_DIR:/usr/bin:/bin"

    VERSION_MANAGER=""
}

teardown() {
    export HOME="$ORIGINAL_HOME"
    export PATH="$ORIGINAL_PATH"
    unset CI PYVE_FORCE_YES
    unset ASDF_HAS_PYTHON_PLUGIN ASDF_INSTALLED_VERSIONS ASDF_AVAILABLE_VERSIONS
    unset ASDF_INSTALL_EXIT ASDF_SET_EXIT ASDF_LOCAL_EXIT
    unset PYENV_INSTALLED_VERSIONS PYENV_AVAILABLE_VERSIONS PYENV_INSTALL_EXIT
    cleanup_test_dir
}

# ────────────────────────────────────────────────────────────────────
# Shim builders
# ────────────────────────────────────────────────────────────────────

make_asdf_shim() {
    cat > "$SHIM_DIR/asdf" << 'EOF'
#!/usr/bin/env bash
case "$1:$2" in
    plugin:list)
        [[ "${ASDF_HAS_PYTHON_PLUGIN:-1}" == "1" ]] && echo "python"
        exit 0
        ;;
    list:python)
        for v in ${ASDF_INSTALLED_VERSIONS:-}; do echo "  $v"; done
        exit 0
        ;;
    list:all)
        # "asdf list all python" — args: list all python
        for v in ${ASDF_AVAILABLE_VERSIONS:-3.13.7 3.12.0}; do echo "$v"; done
        exit 0
        ;;
    install:python)
        exit "${ASDF_INSTALL_EXIT:-0}"
        ;;
    set:python)
        echo "python $3" > .tool-versions
        exit "${ASDF_SET_EXIT:-0}"
        ;;
    local:python)
        echo "python $3" > .tool-versions
        exit "${ASDF_LOCAL_EXIT:-0}"
        ;;
    reshim:python)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$SHIM_DIR/asdf"
}

make_pyenv_shim() {
    cat > "$SHIM_DIR/pyenv" << 'EOF'
#!/usr/bin/env bash
case "$1" in
    versions)
        # "pyenv versions --bare"
        for v in ${PYENV_INSTALLED_VERSIONS:-}; do echo "$v"; done
        exit 0
        ;;
    install)
        if [[ "$2" == "--list" ]]; then
            echo "Available versions:"
            for v in ${PYENV_AVAILABLE_VERSIONS:-3.13.7 3.12.0}; do echo "  $v"; done
            exit 0
        else
            # "pyenv install -s X.Y.Z"
            exit "${PYENV_INSTALL_EXIT:-0}"
        fi
        ;;
    local)
        echo "$2" > .python-version
        exit 0
        ;;
    rehash)
        exit 0
        ;;
    init)
        # "pyenv init -" emits shell code; tests don't exercise it.
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$SHIM_DIR/pyenv"
}

make_direnv_shim() {
    cat > "$SHIM_DIR/direnv" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$SHIM_DIR/direnv"
}

# ────────────────────────────────────────────────────────────────────
# source_shell_profiles
# ────────────────────────────────────────────────────────────────────

@test "source_shell_profiles: no profile files present — does not fail" {
    run source_shell_profiles
    assert_status_equals 0
}

@test "source_shell_profiles: sources \$HOME/.asdf/asdf.sh when present" {
    mkdir -p "$HOME/.asdf"
    cat > "$HOME/.asdf/asdf.sh" << 'EOF'
export ASDF_SHELL_PROFILE_MARKER=1
EOF

    source_shell_profiles
    [[ "${ASDF_SHELL_PROFILE_MARKER:-}" == "1" ]]
    unset ASDF_SHELL_PROFILE_MARKER
}

@test "source_shell_profiles: initializes pyenv when \$HOME/.pyenv exists" {
    mkdir -p "$HOME/.pyenv/bin"
    make_pyenv_shim
    cp "$SHIM_DIR/pyenv" "$HOME/.pyenv/bin/pyenv"

    source_shell_profiles
    [[ "$PYENV_ROOT" == "$HOME/.pyenv" ]]
    [[ ":$PATH:" == *":$HOME/.pyenv/bin:"* ]]
}

# ────────────────────────────────────────────────────────────────────
# detect_version_manager
# ────────────────────────────────────────────────────────────────────

@test "detect_version_manager: asdf with python plugin → VERSION_MANAGER=asdf, status 0" {
    make_asdf_shim
    export ASDF_HAS_PYTHON_PLUGIN=1

    run detect_version_manager
    assert_status_equals 0
    # VERSION_MANAGER is set in the caller's scope; run it unwrapped too.
    detect_version_manager
    [[ "$VERSION_MANAGER" == "asdf" ]]
}

@test "detect_version_manager: asdf without python plugin, no pyenv → status 1" {
    make_asdf_shim
    export ASDF_HAS_PYTHON_PLUGIN=0

    run detect_version_manager
    assert_status_equals 1
    assert_output_contains "Python plugin not installed"
}

@test "detect_version_manager: pyenv only → VERSION_MANAGER=pyenv, status 0" {
    make_pyenv_shim

    run detect_version_manager
    assert_status_equals 0
    detect_version_manager
    [[ "$VERSION_MANAGER" == "pyenv" ]]
}

@test "detect_version_manager: neither manager on PATH → status 1 with install hint" {
    run detect_version_manager
    assert_status_equals 1
    assert_output_contains "No Python version manager found"
    assert_output_contains "asdf-vm.com"
}

@test "detect_version_manager: both present, asdf wins" {
    make_asdf_shim
    make_pyenv_shim

    detect_version_manager
    [[ "$VERSION_MANAGER" == "asdf" ]]
}

# ────────────────────────────────────────────────────────────────────
# is_python_version_installed
# ────────────────────────────────────────────────────────────────────

@test "is_python_version_installed: asdf, version listed → status 0" {
    make_asdf_shim
    export ASDF_INSTALLED_VERSIONS="3.13.7 3.12.0"
    VERSION_MANAGER="asdf"

    run is_python_version_installed "3.13.7"
    assert_status_equals 0
}

@test "is_python_version_installed: asdf, version not listed → status 1" {
    make_asdf_shim
    export ASDF_INSTALLED_VERSIONS="3.12.0"
    VERSION_MANAGER="asdf"

    run is_python_version_installed "3.13.7"
    assert_status_equals 1
}

@test "is_python_version_installed: pyenv, version listed → status 0" {
    make_pyenv_shim
    export PYENV_INSTALLED_VERSIONS="3.13.7 3.12.0"
    VERSION_MANAGER="pyenv"

    run is_python_version_installed "3.13.7"
    assert_status_equals 0
}

@test "is_python_version_installed: pyenv, version not listed → status 1" {
    make_pyenv_shim
    VERSION_MANAGER="pyenv"

    run is_python_version_installed "3.13.7"
    assert_status_equals 1
}

@test "is_python_version_installed: empty VERSION_MANAGER → status 1" {
    VERSION_MANAGER=""
    run is_python_version_installed "3.13.7"
    assert_status_equals 1
}

# ────────────────────────────────────────────────────────────────────
# is_python_version_available
# ────────────────────────────────────────────────────────────────────

@test "is_python_version_available: asdf advertises version → status 0" {
    make_asdf_shim
    export ASDF_AVAILABLE_VERSIONS="3.13.7 3.12.0"
    VERSION_MANAGER="asdf"

    run is_python_version_available "3.13.7"
    assert_status_equals 0
}

@test "is_python_version_available: asdf does not advertise version → status 1" {
    make_asdf_shim
    export ASDF_AVAILABLE_VERSIONS="3.12.0"
    VERSION_MANAGER="asdf"

    run is_python_version_available "3.13.7"
    assert_status_equals 1
}

@test "is_python_version_available: pyenv advertises version → status 0" {
    make_pyenv_shim
    export PYENV_AVAILABLE_VERSIONS="3.13.7 3.12.0"
    VERSION_MANAGER="pyenv"

    run is_python_version_available "3.13.7"
    assert_status_equals 0
}

# ────────────────────────────────────────────────────────────────────
# install_python_version
# ────────────────────────────────────────────────────────────────────

@test "install_python_version: asdf success → status 0" {
    make_asdf_shim
    export ASDF_INSTALL_EXIT=0
    VERSION_MANAGER="asdf"

    run install_python_version "3.13.7"
    assert_status_equals 0
    assert_output_contains "installed successfully"
}

@test "install_python_version: asdf failure → status 1 with error" {
    make_asdf_shim
    export ASDF_INSTALL_EXIT=1
    VERSION_MANAGER="asdf"

    run install_python_version "3.13.7"
    assert_status_equals 1
    assert_output_contains "Failed to install Python"
}

@test "install_python_version: pyenv success → status 0" {
    make_pyenv_shim
    export PYENV_INSTALL_EXIT=0
    VERSION_MANAGER="pyenv"

    run install_python_version "3.13.7"
    assert_status_equals 0
}

@test "install_python_version: no VERSION_MANAGER → status 1" {
    VERSION_MANAGER=""
    run install_python_version "3.13.7"
    assert_status_equals 1
    assert_output_contains "No version manager available"
}

# ────────────────────────────────────────────────────────────────────
# ensure_python_version_installed
# ────────────────────────────────────────────────────────────────────

@test "ensure_python_version_installed: already installed → status 0, skips install" {
    make_asdf_shim
    export ASDF_INSTALLED_VERSIONS="3.13.7"
    VERSION_MANAGER="asdf"

    run ensure_python_version_installed "3.13.7"
    assert_status_equals 0
}

@test "ensure_python_version_installed: unavailable → status 1 with hint" {
    make_asdf_shim
    export ASDF_INSTALLED_VERSIONS=""
    export ASDF_AVAILABLE_VERSIONS="3.12.0"  # 3.13.7 not in list
    VERSION_MANAGER="asdf"

    run ensure_python_version_installed "3.13.7"
    assert_status_equals 1
    assert_output_contains "not available for installation"
}

@test "ensure_python_version_installed: CI=true auto-installs available version" {
    make_asdf_shim
    export ASDF_INSTALLED_VERSIONS=""
    export ASDF_AVAILABLE_VERSIONS="3.13.7"
    export CI=true
    VERSION_MANAGER="asdf"

    run ensure_python_version_installed "3.13.7"
    assert_status_equals 0
    assert_output_contains "Auto-installing in CI"
}

# ────────────────────────────────────────────────────────────────────
# set_local_python_version
# ────────────────────────────────────────────────────────────────────

@test "set_local_python_version: asdf 'set' succeeds → writes .tool-versions" {
    make_asdf_shim
    VERSION_MANAGER="asdf"

    run set_local_python_version "3.13.7"
    assert_status_equals 0
    assert_file_exists ".tool-versions"
    assert_file_contains ".tool-versions" "python 3.13.7"
}

@test "set_local_python_version: asdf falls back to 'local' when 'set' fails" {
    make_asdf_shim
    export ASDF_SET_EXIT=1
    export ASDF_LOCAL_EXIT=0
    VERSION_MANAGER="asdf"

    run set_local_python_version "3.13.7"
    assert_status_equals 0
    assert_file_exists ".tool-versions"
}

@test "set_local_python_version: asdf both 'set' and 'local' fail → status 1" {
    make_asdf_shim
    export ASDF_SET_EXIT=1
    export ASDF_LOCAL_EXIT=1
    VERSION_MANAGER="asdf"

    run set_local_python_version "3.13.7"
    assert_status_equals 1
    assert_output_contains "Failed to set Python version"
}

@test "set_local_python_version: pyenv → writes .python-version" {
    make_pyenv_shim
    VERSION_MANAGER="pyenv"

    run set_local_python_version "3.13.7"
    assert_status_equals 0
    assert_file_exists ".python-version"
    assert_file_contains ".python-version" "3.13.7"
}

@test "set_local_python_version: no VERSION_MANAGER → status 1" {
    VERSION_MANAGER=""

    run set_local_python_version "3.13.7"
    assert_status_equals 1
    assert_output_contains "No version manager available"
}

# ────────────────────────────────────────────────────────────────────
# get_version_file_name
# ────────────────────────────────────────────────────────────────────

@test "get_version_file_name: asdf → .tool-versions" {
    VERSION_MANAGER="asdf"
    run get_version_file_name
    assert_status_equals 0
    assert_output_equals ".tool-versions"
}

@test "get_version_file_name: pyenv → .python-version" {
    VERSION_MANAGER="pyenv"
    run get_version_file_name
    assert_status_equals 0
    assert_output_equals ".python-version"
}

@test "get_version_file_name: none → empty string" {
    VERSION_MANAGER=""
    run get_version_file_name
    assert_status_equals 0
    assert_output_equals ""
}

# ────────────────────────────────────────────────────────────────────
# check_direnv_installed
# ────────────────────────────────────────────────────────────────────

@test "check_direnv_installed: direnv on PATH → status 0" {
    make_direnv_shim

    run check_direnv_installed
    assert_status_equals 0
}

@test "check_direnv_installed: direnv absent → status 1 with install hint" {
    run check_direnv_installed
    assert_status_equals 1
    assert_output_contains "direnv is not installed"
}
