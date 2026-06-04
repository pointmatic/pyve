# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/node/plugin.sh — Node plugin (Story N.t)
#
# Second reference implementation of the plugin contract from N.k,
# and the first non-Python ecosystem. N-3 proves the contract
# generalizes beyond Python: every design hole surfaces when a
# non-Python plugin is implemented against the same hook signatures.
#
# Deliberately mirrors the shape of lib/plugins/python/plugin.sh (N.n)
# so reviewers can diff the two side-by-side and see contract symmetry.
#
# Hooks shipped so far:
#   node_pyve_plugin_manifest_namespace   — returns "node"            (N.t)
#   node_pyve_plugin_detect               — scaffold-time file scan    (N.t)
#   node_pyve_plugin_register_backends    — pnpm / npm / yarn providers (N.u)
#   node_provider_install / _lockfile / _test / _detect — per-provider
#                                            string maps + resolution   (N.u)
#
# Everything else falls back to the no-op defaults in contract.sh:
#   - runtime-resolution (nvm / fnm / volta + PATH) → N.v
#   - lifecycle (init / purge / update)             → N.w
#   - check / status / run / test                   → N.x
#   - activation (.envrc node_modules/.bin PATH_add)→ N.y
#   - .gitignore + smart-purge                      → N.z
#   - SvelteKit detection + frameworks attribute    → N.aa
#
# Detection contract (per Story N.t task list):
#   Signal: package.json present at the plugin's path (default ".").
#   Output:
#     - present → "node"
#     - absent  → "none"
#
# Detection only answers "is this a Node project?" — provider selection
# (pnpm/npm/yarn from lockfile) is N.u's job. Per the spike, detection
# is scaffold-time only: once `pyve.toml` declares [plugins.node], the
# manifest is the runtime source of truth.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Plugin contract — manifest_namespace
#------------------------------------------------------------

node_pyve_plugin_manifest_namespace() {
    printf 'node'
}

#------------------------------------------------------------
# Plugin contract — register_backends (Story N.u)
#
# The three Node package managers register as project-virtualized
# backend-providers (spike S6): each materializes per-project state
# (node_modules/) and contributes node_modules/.bin to PATH on
# activation (the activation hook itself lands in N.y). bp_register is
# idempotent for identical re-registration, so this hook is safe to
# call multiple times (the eager source-time call in pyve.sh and any
# later contract-driven re-fire both land on a consistent registry).
#------------------------------------------------------------

node_pyve_plugin_register_backends() {
    bp_register node pnpm virtualized
    bp_register node npm  virtualized
    bp_register node yarn virtualized
}

#------------------------------------------------------------
# Per-provider string-mapping helpers.
#
# Pure mappings from a provider name to that package manager's
# install command, lockfile name, and test invocation. The lifecycle
# hooks (N.w init/update, N.x test) consume these so the per-tool
# differences live in exactly one place. Unknown providers error.
#------------------------------------------------------------

# Print the install command for <provider>.
node_provider_install() {
    case "$1" in
        pnpm) printf 'pnpm install' ;;
        npm)  printf 'npm install' ;;
        yarn) printf 'yarn install' ;;
        *)
            printf "error: node_provider_install: unknown provider '%s' (expected: pnpm, npm, yarn)\n" "$1" >&2
            return 1
            ;;
    esac
}

# Print the lockfile name for <provider>.
node_provider_lockfile() {
    case "$1" in
        pnpm) printf 'pnpm-lock.yaml' ;;
        npm)  printf 'package-lock.json' ;;
        yarn) printf 'yarn.lock' ;;
        *)
            printf "error: node_provider_lockfile: unknown provider '%s' (expected: pnpm, npm, yarn)\n" "$1" >&2
            return 1
            ;;
    esac
}

# Print the test invocation for <provider>. N.x revisits this per the
# package.json-script-delegation decision; N.u returns the conventional
# `<pm> test` form (each package manager forwards to the package.json
# "test" script).
node_provider_test() {
    case "$1" in
        pnpm) printf 'pnpm test' ;;
        npm)  printf 'npm test' ;;
        yarn) printf 'yarn test' ;;
        *)
            printf "error: node_provider_test: unknown provider '%s' (expected: pnpm, npm, yarn)\n" "$1" >&2
            return 1
            ;;
    esac
}

# Resolve the Node provider for an env. Explicit backend wins; else
# infer from lockfile presence at <path>; else default to pnpm.
#
# Usage: node_provider_detect [declared_backend] [path]
#   declared_backend: the env's `backend = "..."` value, or "" if unset
#   path:             the plugin's path (default ".")
node_provider_detect() {
    local declared="${1:-}"
    local path="${2:-.}"

    # Explicit declaration is the source of truth.
    case "$declared" in
        pnpm|npm|yarn)
            printf '%s' "$declared"
            return 0
            ;;
    esac

    # Infer from lockfile presence (pnpm > npm > yarn probe order is
    # arbitrary — at most one lockfile is normally present).
    if [[ -f "${path}/pnpm-lock.yaml" ]]; then
        printf 'pnpm'
    elif [[ -f "${path}/package-lock.json" ]]; then
        printf 'npm'
    elif [[ -f "${path}/yarn.lock" ]]; then
        printf 'yarn'
    else
        # No lockfile → default to pnpm.
        printf 'pnpm'
    fi
}

#------------------------------------------------------------
# Plugin contract — detect (scaffold-time only)
#
# Path-aware from the start (N-3 insight #5): the optional first arg is
# the plugin's path (default "."). The monorepo case (Node at a sub-path
# while Python owns the root) is tested in N.ab; probing the path here
# means that composition work has a working detection primitive.
#------------------------------------------------------------

node_pyve_plugin_detect() {
    local path="${1:-.}"
    if [[ -f "${path}/package.json" ]]; then
        printf 'node'
    else
        printf 'none'
    fi
}

#------------------------------------------------------------
# Plugin contract — env-block validation (Story N.w, S9)
#
# Mirrors the Python plugin's validate_env_blocks: iterates declared
# envs, checks `purpose` ∈ {run, test, utility, temp} (defense-in-depth;
# the manifest helper already rejects unknown purposes at parse time)
# and, when non-empty, that `backend` is a registered backend-provider.
# Provider-private fields (languages, frameworks, future node_version)
# are NOT inspected — they pass through to the provider untouched (S9).
#------------------------------------------------------------

node_pyve_plugin_validate_env_blocks() {
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    local n=${#PYVE_ENV_NAMES[@]}
    [[ "$n" -eq 0 ]] && return 0

    local i name purpose backend
    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"
        purpose="${PYVE_ENV_PURPOSE[$i]}"
        backend="${PYVE_ENV_BACKEND[$i]}"

        if [[ -n "$purpose" ]]; then
            case "$purpose" in
                run|test|utility|temp) ;;
                *)
                    printf "error: node plugin: env '%s' has unknown purpose '%s' (expected one of: run, test, utility, temp)\n" \
                        "$name" "$purpose" >&2
                    return 1
                    ;;
            esac
        fi

        if [[ -n "$backend" ]]; then
            if ! bp_lookup "$backend" >/dev/null 2>&1; then
                printf "error: node plugin: env '%s' declares unregistered backend '%s'\n" \
                    "$name" "$backend" >&2
                return 1
            fi
        fi
    done
    return 0
}

#------------------------------------------------------------
# Lifecycle workers (Story N.w)
#
# Parameterized by <path> + <provider>; the contract hooks below resolve
# the env's path/backend and call these. Kept separate so the install /
# purge logic is testable hermetically (mocked package manager) apart
# from the manifest-driven hook wrappers.
#------------------------------------------------------------

# Run the provider's install in <path>. mode: "install" | "refresh".
# Confirms a Node runtime first (every provider needs node) via N.v's
# node_runtime_resolve, which fails loudly when none is reachable. The
# refresh mode uses each provider's CI frozen-lockfile form when CI is
# set (pnpm/yarn `--frozen-lockfile`, npm `ci`).
_node_provider_run_install() {
    local path="$1"
    local provider="$2"
    local mode="${3:-install}"

    if ! node_runtime_resolve >/dev/null; then
        return 1
    fi

    (
        cd "$path" || exit 1
        if [[ "$mode" == "refresh" && -n "${CI:-}" ]]; then
            case "$provider" in
                pnpm) pnpm install --frozen-lockfile ;;
                npm)  npm ci ;;
                yarn) yarn install --frozen-lockfile ;;
                *)
                    printf "error: node plugin: unknown provider '%s'\n" "$provider" >&2
                    exit 1
                    ;;
            esac
        else
            case "$provider" in
                pnpm|npm|yarn) "$provider" install ;;
                *)
                    printf "error: node plugin: unknown provider '%s'\n" "$provider" >&2
                    exit 1
                    ;;
            esac
        fi
    )
}

# Smart-purge: remove only the dirs a Node env generates. Never touches
# package.json, lockfiles, or source (S9 / N.r smart-purge rule). N.z
# adds the formal created-vs-authored purge_inventory declaration.
_node_purge_at() {
    local path="$1"
    local d
    for d in node_modules .svelte-kit dist build .next; do
        if [[ -e "$path/$d" ]]; then
            rm -rf "${path:?}/$d"
        fi
    done
    return 0
}

#------------------------------------------------------------
# Plugin contract — lifecycle hooks (Story N.w)
#
# Signatures take an explicit <path> [<backend>]. N-4's composed init
# resolves these per declared env from the manifest and dispatches here;
# until then the hooks are driven directly. Default path is "." (the
# single-plugin-at-root case). init/update validate env blocks (S9)
# first, mirroring the Python plugin.
#------------------------------------------------------------

node_pyve_plugin_init() {
    node_pyve_plugin_validate_env_blocks || return $?
    local path="${1:-.}"
    local backend="${2:-}"
    local provider
    provider="$(node_provider_detect "$backend" "$path")"
    _node_provider_run_install "$path" "$provider" install
}

node_pyve_plugin_purge() {
    local path="${1:-.}"
    _node_purge_at "$path"
}

node_pyve_plugin_update() {
    node_pyve_plugin_validate_env_blocks || return $?
    local path="${1:-.}"
    local backend="${2:-}"
    local provider
    provider="$(node_provider_detect "$backend" "$path")"
    _node_provider_run_install "$path" "$provider" refresh
}
