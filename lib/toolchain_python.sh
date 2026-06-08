# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#============================================================
# lib/toolchain_python.sh — Pyve-owned toolchain interpreter
#
# Pyve is implemented partly in Python: lib/pyve_toml_helper.py (and
# siblings) parse pyve.toml via `tomllib`. Historically every callsite
# resolved that interpreter as `${PYVE_PYTHON:-python}` — i.e. it
# borrowed whatever `python` sat on the developer's PATH. On a clean
# non-Python stack (a version-manager shim with no pinned version, or
# no python ≥ 3.11 at all) that resolution fails, manifest parsing
# silently degrades, and a Node-only project mis-enumerates as Python
# (spike-n-at-composed-init-seam.md Part 2).
#
# This module gives Pyve its OWN interpreter: a hidden venv that exists
# independently of the developer's environment, built on Pyve's
# DEFAULT_PYTHON_VERSION and keyed by that version on disk so a default
# bump lands a fresh tree (old one GC-able) rather than mutating in
# place.
#
# Scope: this is the PYVE-INTERNAL toolchain interpreter only — the one
# that runs Pyve's own Python helpers. It is NOT project-facing Python
# (`pyve run python`, version-manager activation, the project venv);
# that stays the developer's environment, guarded by
# assert_python_resolvable() in lib/env_detect.sh.
#
# Resolution precedence (pyve_toolchain_python):
#   1. PYVE_PYTHON   — explicit override, highest priority (tests + power users)
#   2. hidden venv   — the Pyve-owned interpreter, when provisioned
#   3. bare `python` — legacy fallback (the historical behavior)
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Root of Pyve's version-keyed toolchain tree. XDG_DATA_HOME for durable
# data (the venv is data, not transient state — contrast the v2-banner
# sentinel under XDG_STATE_HOME).
pyve_toolchain_root() {
    printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/pyve/toolchain"
}

# Absolute path to the toolchain venv for the current DEFAULT_PYTHON_VERSION.
# Version-keyed: a DEFAULT_PYTHON_VERSION bump resolves to a new directory.
pyve_toolchain_venv_dir() {
    printf '%s' "$(pyve_toolchain_root)/${DEFAULT_PYTHON_VERSION:-}/venv"
}

# Resolve Pyve's toolchain interpreter (see precedence in the header).
# Always prints SOMETHING (never empty) so callers can use it directly
# as `local py="$(pyve_toolchain_python)"`.
pyve_toolchain_python() {
    if [[ -n "${PYVE_PYTHON:-}" ]]; then
        printf '%s' "$PYVE_PYTHON"
        return 0
    fi
    local venv_py
    venv_py="$(pyve_toolchain_venv_dir)/bin/python"
    if [[ -x "$venv_py" ]]; then
        printf '%s' "$venv_py"
        return 0
    fi
    printf '%s' "python"
}

# Resolve the pyve-hosted `project-guide` console script. project-guide is
# globally hosted by `pyve self install` (pip-installed into the toolchain
# venv, then symlinked onto ~/.local/bin). Pyve-internal callsites MUST
# resolve the hosted absolute path rather than invoking a bare
# `project-guide` on PATH: when asdf is active, ~/.asdf/shims precedes
# ~/.local/bin, so the bare name resolves to asdf's shim — which rejects it
# against the *project's* python pin (no project-guide installed there) and
# fails with "No version is set for command project-guide". This is the same
# failure class pyve_toolchain_python fixes for Pyve's own Python helpers
# (Story N.at); Story N.bf.22 extends it to the hosted project-guide.
#
# Precedence:
#   1. toolchain venv console script — the canonical hosted binary
#   2. ~/.local/bin/project-guide   — the `self install` shim (a symlink to #1)
#   3. bare `project-guide`         — PATH fallback (non-asdf / hand-installed)
# Always prints SOMETHING so callers can use it directly as
# `local pg="$(pyve_project_guide)"`.
pyve_project_guide() {
    local venv_pg
    venv_pg="$(pyve_toolchain_venv_dir)/bin/project-guide"
    if [[ -x "$venv_pg" ]]; then
        printf '%s' "$venv_pg"
        return 0
    fi
    local shim="$HOME/.local/bin/project-guide"
    if [[ -x "$shim" ]]; then
        printf '%s' "$shim"
        return 0
    fi
    printf '%s' "project-guide"
}

# True (0) when a runnable project-guide resolves. Replaces the
# `command -v project-guide` guard at the run_project_guide_* callsites:
# for a hosted absolute path, test it is executable; for the bare-PATH
# fallback, fall back to `command -v`.
pyve_project_guide_available() {
    local pg
    pg="$(pyve_project_guide)"
    if [[ "$pg" == "project-guide" ]]; then
        command -v project-guide >/dev/null 2>&1
    else
        [[ -x "$pg" ]]
    fi
}

# True (0) when the resolved toolchain interpreter can `import yaml`
# (PyYAML), which lib/pyve_env_spec_helper.py requires for `pyve env sync`
#. PyYAML is provisioned into the toolchain venv by
# `pyve self install`. The env-spec seam uses this to emit a precise
# "run pyve self install" error instead of a raw ImportError.
pyve_toolchain_has_pyyaml() {
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    "$py" -c 'import yaml' >/dev/null 2>&1
}

# Build the hidden venv at <venv_dir> on DEFAULT_PYTHON_VERSION. This is
# the real-work seam, factored out so pyve_toolchain_python_ensure's
# orchestration (idempotency, error surfacing) is unit-testable without
# shelling out to a version manager — tests stub this function.
#
# Best-effort: resolves a bootstrap interpreter (the version manager's
# install for DEFAULT_PYTHON_VERSION, else a PATH python3), then
# `python -m venv`. The thorough version-manager integration (install
# the version if absent, exact-path resolution) is hardened in the
# N.at.3 lifecycle story; here it does the minimal viable build.
_pyve_toolchain_build() {
    local venv_dir="$1"
    local version="${DEFAULT_PYTHON_VERSION:-}"

    local boot
    boot="$(_pyve_toolchain_bootstrap_python "$version")" || return 1
    if [[ -z "$boot" ]]; then
        return 1
    fi

    mkdir -p "$(dirname "$venv_dir")" || return 1
    "$boot" -m venv "$venv_dir" >/dev/null 2>&1 || return 1
    [[ -x "$venv_dir/bin/python" ]]
}

# Resolve a bootstrap interpreter capable of building the toolchain venv.
# Prints the interpreter path on success; non-zero / empty on failure.
#
# Order (version-tracking fidelity):
#   1. the version manager's install for the EXACT DEFAULT_PYTHON_VERSION
#      (so Pyve's toolchain tracks that version, per the developer's
#      decision), installing it first if absent;
#   2. a PATH python3 / python (legacy fallback — the version may differ;
#      best-effort so a venv is still built when no version manager exists).
_pyve_toolchain_bootstrap_python() {
    local version="$1"
    if declare -F detect_version_manager >/dev/null 2>&1; then
        detect_version_manager >/dev/null 2>&1 || true
    fi
    if declare -F ensure_python_version_installed >/dev/null 2>&1 \
       && [[ -n "$version" ]]; then
        ensure_python_version_installed "$version" >/dev/null 2>&1 || true
    fi
    # Exact-version interpreter via the active version manager.
    local exact
    exact="$(_pyve_toolchain_versioned_python "$version")"
    if [[ -n "$exact" && -x "$exact" ]]; then
        printf '%s' "$exact"
        return 0
    fi
    # Fall back to a PATH python3 / python (the legacy bootstrap source).
    local cand
    for cand in python3 python; do
        if command -v "$cand" >/dev/null 2>&1 && "$cand" --version >/dev/null 2>&1; then
            command -v "$cand"
            return 0
        fi
    done
    return 1
}

# Resolve the on-disk interpreter path for a specific Python version via
# the active version manager. Prints the path (the caller checks `-x`);
# empty when there is no version manager or no version. Mirrors the
# version-manager dispatch in lib/env_detect.sh.
_pyve_toolchain_versioned_python() {
    local version="$1"
    [[ -n "$version" ]] || return 0
    local d
    case "${VERSION_MANAGER:-}" in
        asdf)
            d="$(asdf where python "$version" 2>/dev/null)" || return 0
            [[ -n "$d" ]] && printf '%s' "$d/bin/python"
            ;;
        pyenv)
            d="$(pyenv prefix "$version" 2>/dev/null)" || return 0
            [[ -n "$d" ]] && printf '%s' "$d/bin/python"
            ;;
    esac
    return 0
}

# Idempotently ensure the toolchain venv exists. No-op when already
# provisioned (the common path — one check, no build). On a missing
# venv, delegate to the build seam and surface a precise error if it
# could not be created.
#
# Returns 0 when the venv exists (already or newly built); non-zero with
# a stderr diagnostic when the build failed. Callers treat a failure as
# "fall back to bare python" rather than a hard abort.
pyve_toolchain_python_ensure() {
    local venv_dir
    venv_dir="$(pyve_toolchain_venv_dir)"
    if [[ -x "$venv_dir/bin/python" ]]; then
        return 0
    fi
    if _pyve_toolchain_build "$venv_dir"; then
        return 0
    fi
    printf "error: could not provision Pyve toolchain Python (%s) at %s\n" \
        "${DEFAULT_PYTHON_VERSION:-unknown}" "$venv_dir" >&2
    printf "       Pyve will fall back to 'python' on PATH; set PYVE_PYTHON to override.\n" >&2
    return 1
}
