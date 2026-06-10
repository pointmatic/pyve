#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# Regression test: internal helper callsites resolve
# Pyve's toolchain interpreter, not the developer's PATH `python`.
#
# The canonical motivator from spike-n-at-composed-init-seam.md Part 2:
# a Node-only project on a machine with no resolvable PATH `python` must
# still parse `pyve.toml` and enumerate `[node]` — NOT silently fall
# back to implicit-Python because the manifest parse died.
#
# Mechanism under test: manifest_load resolves its interpreter via
# pyve_toolchain_python (which finds the Pyve-owned venv) instead of the
# bare `${PYVE_PYTHON:-python}` form. We simulate the failure mode by
# cleaning PATH so bare `python` is unresolvable, while a Pyve-owned
# toolchain venv (a real interpreter, absolute path) is present.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'

    # Resolve a REAL interpreter (absolute path, has tomllib) BEFORE we
    # touch PATH — this stands in for what `pyve self install` would put
    # in the toolchain venv.
    REAL_PY="$(python3 -c 'import sys, tomllib; print(sys.executable)' 2>/dev/null)"
    [[ -n "$REAL_PY" && -x "$REAL_PY" ]] || skip "no real python3 with tomllib available"

    TEST_DIR="$(mktemp -d)"
    export XDG_DATA_HOME="$TEST_DIR/xdg"
    export DEFAULT_PYTHON_VERSION="3.99.0"   # arbitrary key; just must be stable
    unset PYVE_PYTHON

    # Stand up a fake Pyve-owned toolchain venv whose bin/python is the
    # real interpreter (absolute symlink) — exactly what the resolver
    # should pick when PATH `python` is gone.
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    TOOLCHAIN_VENV="$(pyve_toolchain_venv_dir)"
    mkdir -p "$TOOLCHAIN_VENV/bin"
    ln -s "$REAL_PY" "$TOOLCHAIN_VENV/bin/python"

    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "manifest_load enumerates a Node-only project when bare PATH python is gone" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo-node"
[plugins.node]
EOF

    # Run in a fresh, PATH-cleaned shell so bare `python` cannot resolve —
    # only the Pyve-owned toolchain venv (absolute) is reachable. This is
    # the spike's failure machine reproduced deterministically.
    run /bin/bash -c '
        set -uo pipefail
        # Coreutils present (dirname, etc.) but bare `python` unresolvable —
        # the spike failure machine, without removing the shell utilities.
        export PATH="/usr/bin:/bin"
        export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
        export DEFAULT_PYTHON_VERSION="'"$DEFAULT_PYTHON_VERSION"'"
        unset PYVE_PYTHON
        source "'"$PYVE_ROOT"'/lib/ui/core.sh"
        source "'"$PYVE_ROOT"'/lib/utils.sh"
        source "'"$PYVE_ROOT"'/lib/manifest.sh"
        source "'"$PYVE_ROOT"'/lib/env_detect.sh"
        source "'"$PYVE_ROOT"'/lib/toolchain_python.sh"
        source "'"$PYVE_ROOT"'/lib/plugins/contract.sh"
        source "'"$PYVE_ROOT"'/lib/plugins/registry.sh"
        cd "'"$TEST_DIR"'"
        manifest_load
        plugin_registry_reset
        plugin_load_all_from_manifest
        plugin_list_active
    '
    echo "status=$status output=$output" >&2
    assert_status_equals 0
    assert_output_contains "node"
    [[ "$output" != *"python"* ]] || {
        echo "mis-enumerated as python (manifest parse degraded)" >&2
        return 1
    }
}

@test "PYVE_PYTHON override still wins after the rewire" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo-node"
[plugins.node]
EOF
    # PYVE_PYTHON pointed at the real interpreter must be honored by the
    # resolver (the existing test contract — many suites set it in setup).
    export PYVE_PYTHON="$REAL_PY"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    manifest_load
    plugin_registry_reset
    plugin_load_all_from_manifest
    run plugin_list_active
    assert_output_contains "node"
}
