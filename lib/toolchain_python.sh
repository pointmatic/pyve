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
#   0. PYVE_PROJECT_GUIDE_BIN        — explicit override, highest priority
#                                      (tests + power users), mirroring
#                                      PYVE_PYTHON in pyve_toolchain_python.
#                                      The hosted-absolute-path resolution
#                                      below deliberately ignores PATH, so an
#                                      env override is the only seam by which
#                                      a test can redirect to a stub.
#   1. toolchain venv console script — the canonical hosted binary
#   2. ~/.local/bin/project-guide   — the `self install` shim (a symlink to #1)
#   3. bare `project-guide`         — PATH fallback (non-asdf / hand-installed)
# Always prints SOMETHING so callers can use it directly as
# `local pg="$(pyve_project_guide)"`.
pyve_project_guide() {
    if [[ -n "${PYVE_PROJECT_GUIDE_BIN:-}" ]]; then
        printf '%s' "$PYVE_PROJECT_GUIDE_BIN"
        return 0
    fi
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
    if [[ -n "${PYVE_PROJECT_GUIDE_BIN:-}" ]]; then
        [[ -x "$PYVE_PROJECT_GUIDE_BIN" ]]
        return
    fi
    local pg
    pg="$(pyve_project_guide)"
    if [[ "$pg" == "project-guide" ]]; then
        command -v project-guide >/dev/null 2>&1
    else
        [[ -x "$pg" ]]
    fi
}

# True (0) when project-guide is pyve-HOSTED (the toolchain venv console
# script or the ~/.local/bin shim), as opposed to merely resolvable as a
# bare-PATH command. Story N.bh uses this to decide whether to trust the
# resolution or (re)provision — a bare-PATH `project-guide` under active
# asdf is a trap, not a real hosted tool.
pyve_project_guide_is_hosted() {
    if [[ -n "${PYVE_PROJECT_GUIDE_BIN:-}" ]]; then
        [[ -x "$PYVE_PROJECT_GUIDE_BIN" ]]
        return
    fi
    [[ -x "$(pyve_toolchain_venv_dir)/bin/project-guide" ]] || [[ -x "$HOME/.local/bin/project-guide" ]]
}

# Point ~/.local/bin/project-guide at the toolchain venv's console script.
# Shared helper (Story N.bh): used by both `pyve self install`/`self
# provision` and the lazy `pyve_project_guide_ensure`. `ln -sf` makes this
# a refresh (idempotent + bump-reconcile). No-op if the target is absent.
pyve_link_project_guide_shim() {
    local venv_dir="$1"
    local target="$venv_dir/bin/project-guide"
    [[ -x "$target" ]] || return 0
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    ln -sf "$target" "$bin_dir/project-guide"
}

# Idempotent, presence-gated provisioning of the pyve-hosted project-guide
# (Story N.bh). Fast path: a stat — no-op (and no network) when the
# toolchain venv's console script already exists. When missing: build the
# toolchain venv if absent (pyve_toolchain_python_ensure), pip-install
# project-guide into it, then link the shim. Returns 0 once hosted; non-zero
# if the venv could not be built or the install failed (callers treat that
# as "skip project-guide", never as a hard abort). Install-method-agnostic:
# works for Homebrew and source installs alike, independent of `self install`.
pyve_project_guide_ensure() {
    # An explicit override is already a runnable project-guide — never
    # provision (no venv build, no network pip) when it is set.
    if [[ -n "${PYVE_PROJECT_GUIDE_BIN:-}" ]]; then
        [[ -x "$PYVE_PROJECT_GUIDE_BIN" ]]
        return
    fi
    local venv_dir target pip
    venv_dir="$(pyve_toolchain_venv_dir)"
    target="$venv_dir/bin/project-guide"
    [[ -x "$target" ]] && return 0
    if declare -F pyve_toolchain_python_ensure >/dev/null 2>&1; then
        pyve_toolchain_python_ensure >/dev/null 2>&1 || return 1
    fi
    pip="$venv_dir/bin/pip"
    [[ -x "$pip" ]] || return 1
    "$pip" install --upgrade 'project-guide>=2.13.0' >/dev/null 2>&1 || return 1
    pyve_link_project_guide_shim "$venv_dir"
    [[ -x "$target" ]]
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
# Best-effort: ensures an interpreter exists (may prompt to install the
# pinned version on an interactive TTY), then resolves it and runs
# `python -m venv`. The interpreter decision runs OUTSIDE the resolver's
# command substitution so any prompt or install progress streams to the
# developer instead of being swallowed.
_pyve_toolchain_build() {
    local venv_dir="$1"
    local version="${DEFAULT_PYTHON_VERSION:-}"

    # May prompt/install (interactive) or no-op (non-interactive). Its
    # stdout is NOT captured, so prompts and build progress are visible.
    _pyve_toolchain_ensure_interpreter "$version"

    local boot
    boot="$(_pyve_toolchain_bootstrap_python "$version")" || return 1
    if [[ -z "$boot" ]]; then
        return 1
    fi

    mkdir -p "$(dirname "$venv_dir")" || return 1
    "$boot" -m venv "$venv_dir" >/dev/null 2>&1 || return 1
    [[ -x "$venv_dir/bin/python" ]]
}

# Ensure an interpreter for the toolchain venv is available — installing the
# EXACT DEFAULT_PYTHON_VERSION when it is absent, so Pyve's toolchain tracks
# that version. Best-effort and non-blocking: never reaches a prompt unless
# it can actually be answered (see _pyve_toolchain_confirm_install). On a
# decline (or any non-interactive context), the build falls back to a PATH
# python via _pyve_toolchain_bootstrap_python. Returns 0 regardless.
#
# This is the seam that must stay out of command substitution: it may write
# a prompt and stream `asdf install` / `pyenv install` output to the user.
_pyve_toolchain_ensure_interpreter() {
    local version="$1"
    [[ -n "$version" ]] || return 0

    if declare -F detect_version_manager >/dev/null 2>&1; then
        detect_version_manager >/dev/null 2>&1 || true
    fi

    # Already installed at the exact version → nothing to do, no prompt.
    local exact
    exact="$(_pyve_toolchain_versioned_python "$version")"
    if [[ -n "$exact" && -x "$exact" ]]; then
        return 0
    fi

    declare -F ensure_python_version_installed >/dev/null 2>&1 || return 0

    if _pyve_toolchain_confirm_install "$version"; then
        # Force-yes so ensure_python_version_installed does not raise its own
        # (separate) prompt — the consent was already collected above.
        PYVE_FORCE_YES=1 ensure_python_version_installed "$version" || true
    fi
    return 0
}

# Is this a fully interactive session — can the user both SEE a prompt and
# answer it? All three std streams must be terminals:
#   - stdin (fd 0): the user can type an answer (else `read` blocks)
#   - stdout/stderr (fd 1/2): the user can see the prompt
# Checking only stdin is insufficient: Homebrew's `post_install` keeps stdin
# attached to the tty but redirects stdout/stderr to a logfile, so a
# stdin-only gate prompts to the (invisible) log and then blocks on `read` —
# the brew `self provision` hang. Factored out so tests can drive the
# interactive path without a real TTY.
_pyve_is_interactive() { [[ -t 0 && -t 1 && -t 2 ]]; }

# Ask whether to install the pinned toolchain Python. Returns 0 (yes) / 1 (no).
#
# Decision policy — must never block a non-interactive caller (the brew
# `self provision` hang was a prompt the user could not see, blocking on a
# live stdin):
#   - PYVE_FORCE_YES=1        → yes  (explicit opt-in; CI/automation that wants it)
#   - CI set, or not a TTY    → no   (fall back to an existing interpreter; no
#                                     unattended multi-minute source build)
#   - fully interactive TTY   → ask, default YES
#
# The prompt and `read` go to the terminal; this function prints nothing to
# stdout, so it is safe even if a caller is inside command substitution.
_pyve_toolchain_confirm_install() {
    local version="$1"
    [[ "${PYVE_FORCE_YES:-}" == "1" ]] && return 0
    [[ -n "${CI:-}" ]] && return 1
    _pyve_is_interactive || return 1

    # Both initialized to empty: under `set -u` the fallback block may not
    # run (no python3/python on PATH — the brew post-install shape), and a
    # bare `local fallback_ver` would leave it UNSET, so the `[[ -n ... ]]`
    # read below would abort with "unbound variable".
    local fallback="" fallback_ver=""
    fallback="$(_pyve_toolchain_path_python)" || fallback=""
    if [[ -n "$fallback" ]]; then
        fallback_ver="$("$fallback" --version 2>&1 | awk '{print $2}')"
    fi

    printf '\n  Pyve prefers Python %s for its toolchain.\n' "$version" >&2
    if [[ -n "$fallback_ver" ]]; then
        printf "  Install it now (several minutes)? If not, I'll use your Python %s.\n" \
            "$fallback_ver" >&2
    else
        printf '  Install it now (several minutes)?\n' >&2
    fi

    local answer
    read -rp "  Install Python $version? [Y/n] " answer
    answer="${answer:-y}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Resolve a bootstrap interpreter capable of building the toolchain venv.
# Pure resolver — no prompt, no install, so it is safe inside command
# substitution (its only stdout is the interpreter path).
#
# Order (version-tracking fidelity):
#   1. the version manager's install for the EXACT DEFAULT_PYTHON_VERSION,
#      if present (installation is handled earlier by
#      _pyve_toolchain_ensure_interpreter);
#   2. a PATH python3 / python (legacy fallback — the version may differ;
#      best-effort so a venv is still built when no version manager exists).
_pyve_toolchain_bootstrap_python() {
    local version="$1"
    if declare -F detect_version_manager >/dev/null 2>&1; then
        detect_version_manager >/dev/null 2>&1 || true
    fi
    # Exact-version interpreter via the active version manager.
    local exact
    exact="$(_pyve_toolchain_versioned_python "$version")"
    if [[ -n "$exact" && -x "$exact" ]]; then
        printf '%s' "$exact"
        return 0
    fi
    # Fall back to a PATH python3 / python (the legacy bootstrap source).
    _pyve_toolchain_path_python
}

# Print the first runnable `python3` / `python` on PATH; non-zero if none.
_pyve_toolchain_path_python() {
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
