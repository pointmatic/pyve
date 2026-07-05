#!/usr/bin/env bats
# bats file_tags=core
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
        if [[ "${ASDF_HAS_PYTHON_PLUGIN:-1}" == "1" ]]; then
            echo "python"
            # Opt-in noise: emit a large volume after the match so that a
            # consumer using `grep -q` (which exits on first match) closes
            # the pipe while this producer is still writing → SIGPIPE (141).
            # Under `set -o pipefail` that propagates as the pipeline status,
            # producing the false-negative this test guards (Story N.bf.6).
            if [[ "${ASDF_PLUGIN_LIST_NOISE:-0}" == "1" ]]; then
                for ((__i=0; __i<100000; __i++)); do echo "noise-plugin-$__i"; done
            fi
        fi
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
        # Opt-in noise emitted AFTER the listed versions so that a consumer
        # using `grep -q` (exits on first match) closes the pipe while this
        # producer is still writing → SIGPIPE (141). Under `set -o pipefail`
        # that propagates as the pipeline status — the false-negative this
        # guards (same class as ASDF_PLUGIN_LIST_NOISE).
        if [[ "${PYENV_VERSIONS_NOISE:-0}" == "1" ]]; then
            for ((__i=0; __i<100000; __i++)); do echo "noise-$__i"; done
        fi
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

@test "detect_version_manager: noisy asdf plugin list under pipefail still detects asdf (Story N.bf.6)" {
    # Bug 1: `asdf plugin list | grep -q "^python$"` under `set -o pipefail`
    # false-negatives when asdf is still writing as grep exits (SIGPIPE 141),
    # flipping the result to the pyenv fallback. The fix captures-then-greps
    # so no pipe (and no SIGPIPE) is involved.
    make_asdf_shim
    make_pyenv_shim
    export ASDF_HAS_PYTHON_PLUGIN=1
    export ASDF_PLUGIN_LIST_NOISE=1

    set -o pipefail
    detect_version_manager
    set +o pipefail
    [[ "$VERSION_MANAGER" == "asdf" ]]
}

@test "version-manager pick honored: asdf write lands in .tool-versions, not .python-version (Story N.bf.6)" {
    # Bug 2 consequence: when asdf is the resolved manager, the pin must be
    # written via asdf (.tool-versions) — never silently via pyenv
    # (.python-version), which is what a clobbered VERSION_MANAGER produced.
    make_asdf_shim
    make_pyenv_shim
    export ASDF_HAS_PYTHON_PLUGIN=1
    VERSION_MANAGER="asdf"

    set_local_python_version "3.13.7"
    [ -f .tool-versions ]
    [ ! -f .python-version ]
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

@test "is_python_version_installed: pyenv match followed by more output under pipefail → status 0" {
    # `pyenv versions --bare | grep -q "^X$"` false-negatives under
    # `set -o pipefail` when pyenv keeps writing versions after the match:
    # grep exits on first match → pipe closes → pyenv takes SIGPIPE (141) →
    # pipefail makes the pipeline non-zero → "not installed". This was the
    # macOS-CI failure (3.12.10 matched, 3.14.5 written after it). The fix
    # captures-then-greps so no pipe (and no SIGPIPE) is involved.
    make_pyenv_shim
    export PYENV_INSTALLED_VERSIONS="3.12.10"
    export PYENV_VERSIONS_NOISE=1
    VERSION_MANAGER="pyenv"

    set -o pipefail
    local rc=0
    is_python_version_installed "3.12.10" || rc=$?
    set +o pipefail
    [ "$rc" -eq 0 ]
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

# ────────────────────────────────────────────────────────────────────
# assert_python_resolvable — pre-flight check.
#
# Detects the recurring "asdf-shim with no resolvable version" trap
# (bit `pyve testenv init` in M.a, project-guide completion in M.b,
# `pyve test` drift-rebuild in the N.d.1 report) before pyve invokes
# `python -m venv` (or any python). Emits a pyve-owned actionable
# error pointing at `direnv allow` / `pyve run`, instead of letting
# asdf's "No version is set for command python" leak through.
# ────────────────────────────────────────────────────────────────────

# Shim builder: a `python` that behaves like an asdf shim with no
# resolvable version — noisy stderr, exit 126.
make_asdf_python_shim_no_version() {
    mkdir -p "$SHIM_DIR/.asdf/shims"
    cat > "$SHIM_DIR/.asdf/shims/python" << 'EOF'
#!/usr/bin/env bash
echo "No version is set for command python" >&2
echo "Consider adding one of the following versions in your config file at $PWD/.tool-versions" >&2
echo "python 3.14.4" >&2
exit 126
EOF
    chmod +x "$SHIM_DIR/.asdf/shims/python"
    export PATH="$SHIM_DIR/.asdf/shims:$SHIM_DIR:/usr/bin:/bin"
}

# Shim builder: a `python` that behaves like a pyenv shim with no
# resolvable version.
make_pyenv_python_shim_no_version() {
    mkdir -p "$SHIM_DIR/.pyenv/shims"
    cat > "$SHIM_DIR/.pyenv/shims/python" << 'EOF'
#!/usr/bin/env bash
echo "pyenv: no version configured for this directory" >&2
exit 1
EOF
    chmod +x "$SHIM_DIR/.pyenv/shims/python"
    export PATH="$SHIM_DIR/.pyenv/shims:$SHIM_DIR:/usr/bin:/bin"
}

# Shim builder: a `python` that just works (simulates project env on PATH).
make_working_python() {
    cat > "$SHIM_DIR/python" << 'EOF'
#!/usr/bin/env bash
echo "Python 3.12.13"
EOF
    chmod +x "$SHIM_DIR/python"
}

@test "assert_python_resolvable: python works → returns 0 silently" {
    make_working_python
    run assert_python_resolvable
    assert_status_equals 0
    [ -z "$output" ]
}

@test "assert_python_resolvable: asdf-shim-no-version (activatable) → exit 1 + actionable error" {
    make_asdf_python_shim_no_version
    touch .envrc             # an activatable project: keep the direnv advice
    run assert_python_resolvable
    assert_status_equals 1
    assert_output_contains "direnv allow"
    assert_output_contains "pyve run"
    # Must NOT leak asdf's own message — pyve owns the error now.
    [[ "$output" != *"Consider adding one of the following versions"* ]]
}

@test "assert_python_resolvable: pyenv-shim-no-version (activatable) → exit 1 + actionable error" {
    make_pyenv_python_shim_no_version
    touch .envrc
    run assert_python_resolvable
    assert_status_equals 1
    assert_output_contains "direnv allow"
    assert_output_contains "pyve run"
}

@test "assert_python_resolvable: python missing entirely → generic activation hint" {
    # setup() sets PATH="$SHIM_DIR:/usr/bin:/bin" — fine on macOS where
    # /usr/bin/python is absent, but Ubuntu CI runners ship
    # /usr/bin/python (symlinked to python3), so the system interpreter
    # leaks in and `python --version` would succeed. Point PYVE_PYTHON
    # at a nonexistent path so the assertion exercises the
    # missing-entirely branch deterministically across runners (keeping
    # the rest of PATH intact so bats helpers like grep still work).
    # An activatable project (.envrc present) keeps the direnv advice.
    touch .envrc
    PYVE_PYTHON="/nonexistent/python-deliberately-missing" \
        run assert_python_resolvable
    assert_status_equals 1
    assert_output_contains "direnv allow"
}

# N.bf.4: the fix advice is gated on init state. The shim trap only fires
# when there's no version pin — which in a properly-initialized project
# never happens. So when the message appears with no `.envrc`, the project
# is purged/uninitialized, and `direnv allow` / `pyve run` are wrong advice.

@test "assert_python_resolvable: shim trap + no .envrc + pyve.toml → advises 'pyve init', not 'direnv allow'" {
    make_asdf_python_shim_no_version
    touch pyve.toml          # a Pyve project whose env was purged
    run assert_python_resolvable
    assert_status_equals 1
    assert_output_contains "pyve init"
    if [[ "$output" == *"direnv allow"* ]]; then
        echo "FAIL: advised 'direnv allow' with no .envrc to allow"; return 1
    fi
}

@test "assert_python_resolvable: shim trap + no .envrc + no pyve.toml → advises 'pyve init' to set up" {
    make_asdf_python_shim_no_version
    run assert_python_resolvable     # not a Pyve project at all
    assert_status_equals 1
    assert_output_contains "pyve init"
    if [[ "$output" == *"direnv allow"* ]]; then
        echo "FAIL: advised 'direnv allow' in a non-Pyve dir"; return 1
    fi
}

@test "assert_python_resolvable: generic (missing) + no .envrc + pyve.toml → advises 'pyve init'" {
    touch pyve.toml
    PYVE_PYTHON="/nonexistent/python-deliberately-missing" \
        run assert_python_resolvable
    assert_status_equals 1
    assert_output_contains "pyve init"
    if [[ "$output" == *"direnv allow"* ]]; then
        echo "FAIL: generic branch ignored init state"; return 1
    fi
}
