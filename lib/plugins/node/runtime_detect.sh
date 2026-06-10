# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/node/runtime_detect.sh — Node runtime resolution
#
# Node's version-manager precedence per spike S10 (revised):
#
#   nvm > fnm > volta > asdf > Homebrew/system PATH
#
# Per S10, runtime resolution is plugin-internal — each plugin owns its
# own precedence chain. These helpers live with the Node plugin (not in
# the shared lib/env_detect.sh, which is Python/asdf-oriented).
#
# Each manager detector mirrors the is_asdf_active() contract from
# lib/env_detect.sh: it returns 0 only when the manager is genuinely
# active AND the user has not opted out via a PYVE_NO_<MGR>_COMPAT env
# var. The opt-out exists so a user who has, say, volta installed but
# wants pyve to ignore it can set PYVE_NO_VOLTA_COMPAT=1.
#
# NOTE on the asdf tier: this does NOT reuse is_asdf_active() from
# lib/env_detect.sh. That helper gates on VERSION_MANAGER == "asdf",
# which detect_version_manager only sets in the Python flow (after
# confirming an asdf *python* plugin) — it would never fire for a
# Node-only project. _is_asdf_node_active() instead checks asdf for a
# *nodejs* plugin, while still honoring the shared PYVE_NO_ASDF_COMPAT
# opt-out so "disable asdf compat" stays a single switch.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Returns 0 when nvm is the active Node version manager. nvm is a shell
# function sourced from $NVM_DIR/nvm.sh, so "loadable" means NVM_DIR is
# set and that script exists and is non-empty.
is_nvm_active() {
    [[ -n "${PYVE_NO_NVM_COMPAT:-}" ]] && return 1
    [[ -n "${NVM_DIR:-}" ]] || return 1
    [[ -s "${NVM_DIR}/nvm.sh" ]] || return 1
    return 0
}

# Returns 0 when fnm is active: the `fnm` binary resolves AND an fnm
# shell-integration env signal is present (FNM_DIR, or the per-shell
# FNM_MULTISHELL_PATH that `fnm env` exports).
is_fnm_active() {
    [[ -n "${PYVE_NO_FNM_COMPAT:-}" ]] && return 1
    command -v fnm >/dev/null 2>&1 || return 1
    [[ -n "${FNM_DIR:-}" || -n "${FNM_MULTISHELL_PATH:-}" ]] || return 1
    return 0
}

# Returns 0 when volta is active: VOLTA_HOME is set AND the volta binary
# resolves (on PATH or at $VOLTA_HOME/bin/volta).
is_volta_active() {
    [[ -n "${PYVE_NO_VOLTA_COMPAT:-}" ]] && return 1
    [[ -n "${VOLTA_HOME:-}" ]] || return 1
    if command -v volta >/dev/null 2>&1 || [[ -x "${VOLTA_HOME}/bin/volta" ]]; then
        return 0
    fi
    return 1
}

# Private: asdf-as-Node-source (the S10 asdf tier). Distinct from the
# Python-context is_asdf_active(); honors the shared PYVE_NO_ASDF_COMPAT
# opt-out. Active when asdf resolves and lists a `nodejs` plugin.
_is_asdf_node_active() {
    [[ -n "${PYVE_NO_ASDF_COMPAT:-}" ]] && return 1
    command -v asdf >/dev/null 2>&1 || return 1
    # Capture-then-grep: piping into `grep -qx` lets grep close the pipe on
    # the match while `asdf plugin list` is still writing → SIGPIPE (141),
    # which `set -o pipefail` turns into a false "not active."
    local plugins
    plugins="$(asdf plugin list 2>/dev/null || true)"
    grep -qx 'nodejs' <<<"$plugins" || return 1
    return 0
}

# Print the governing Node version manager per S10 precedence, or "path"
# when no manager is active (Homebrew/system PATH fallback). Pure: no
# side effects, safe to call standalone. This is the precedence walk;
# node_runtime_resolve() consumes it for the binary path.
node_runtime_manager() {
    if is_nvm_active; then
        printf 'nvm'
    elif is_fnm_active; then
        printf 'fnm'
    elif is_volta_active; then
        printf 'volta'
    elif _is_asdf_node_active; then
        printf 'asdf'
    else
        printf 'path'
    fi
}

# Resolve and print the `node` binary path. Every supported manager
# shims `node` onto PATH when active in the user's shell (the shell pyve
# runs inside), so `command -v node` is the resolution; node_runtime_manager
# reports *which* manager governs it. Fails loudly with a precise,
# actionable message when no node runtime is reachable.
node_runtime_resolve() {
    local node_path
    node_path="$(command -v node 2>/dev/null || true)"
    if [[ -z "$node_path" ]]; then
        printf "error: no Node runtime detected; install Node via Homebrew or your preferred version manager (nvm / fnm / volta).\n" >&2
        return 1
    fi
    printf '%s' "$node_path"
    return 0
}
