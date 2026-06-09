#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Retire the Python 3.12+ distutils compatibility shim.
#
# distutils was removed from CPython in 3.12 (PEP 632, 2023). The shim —
# a sitecustomize.py that force-`import setuptools` + set
# SETUPTOOLS_USE_DISTUTILS=local on every interpreter startup, plus a forced
# `pip install setuptools wheel` into every fresh env — is obsolete by the
# 3.14 era and was retired. Fresh envs keep pip (venv built-in /
# environment.yml `- pip`) but no longer carry the shim or setuptools/wheel.
#
# Regression sentinel (mirrors test_retired_writers.bats): the retired
# functions, the marker var, and the `sitecustomize` machinery must have NO
# non-comment reference in lib/ or pyve.sh, and the module file itself must
# be gone. Full-line comments mentioning a retired name in passing are
# allowed; a non-comment reference means the shim was resurrected.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    setup_pyve_env
}

# Retired names: no production definition or call may remain.
RETIRED_SHIM_NAMES=(
    pyve_install_distutils_shim_for_python
    pyve_install_distutils_shim_for_micromamba_prefix
    pyve_write_sitecustomize_shim
    pyve_distutils_shim_probe
    pyve_ensure_venv_packaging_prereqs
    pyve_ensure_micromamba_packaging_prereqs
    pyve_python_is_312_plus
    pyve_is_distutils_shim_disabled
    pyve_get_site_packages_dir
    pyve_get_python_major_minor
    PYVE_DISTUTILS_SHIM_MARKER
    PYVE_DISABLE_DISTUTILS_SHIM
    sitecustomize
)

@test "sentinel: no retired distutils-shim name has a non-comment reference in lib/ or pyve.sh" {
    local fn offenders=""
    for fn in "${RETIRED_SHIM_NAMES[@]}"; do
        local hits
        hits="$(grep -rnE "\\b${fn}\\b" "$PYVE_ROOT"/lib "$PYVE_ROOT"/pyve.sh 2>/dev/null \
            | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
        if [[ -n "$hits" ]]; then
            offenders+="[$fn]"$'\n'"$hits"$'\n'
        fi
    done
    if [[ -n "$offenders" ]]; then
        echo "Retired distutils-shim name(s) still referenced in production:" >&2
        echo "$offenders" >&2
        return 1
    fi
}

@test "sentinel: lib/distutils_shim.sh module file is gone" {
    [[ ! -e "$PYVE_ROOT/lib/distutils_shim.sh" ]]
}

@test "sentinel: pyve.sh no longer sources distutils_shim.sh" {
    run grep -nF 'distutils_shim.sh' "$PYVE_ROOT/pyve.sh"
    [ "$status" -ne 0 ]
}
