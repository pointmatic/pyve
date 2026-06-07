# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/node/plugin.sh — Node plugin
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
# Detection contract (per task list):
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
# Plugin contract — register_backends
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
# Framework detection
#
# Sibling to node_pyve_plugin_detect — kept separate so detect's
# node/none contract (N.t) stays intact. Returns the framework signal
# for <path> (default "."): "sveltekit" when package.json is present AND
# (a svelte.config.{js,mjs,ts} is present OR @sveltejs/kit appears in
# package.json's deps/devDeps); "none" otherwise. The package.json probe
# is advisory-grade (grep, not a JSON parse), matching the typescript
# advisory's posture. `frameworks` is S11 structured metadata — advisory
# only in v3.0 (no behavior change beyond detection).
#------------------------------------------------------------

node_detect_framework() {
    local path="${1:-.}"
    [[ -f "${path}/package.json" ]] || { printf 'none'; return 0; }

    local cfg
    for cfg in svelte.config.js svelte.config.mjs svelte.config.ts; do
        if [[ -f "${path}/${cfg}" ]]; then
            printf 'sveltekit'
            return 0
        fi
    done

    if grep -q '"@sveltejs/kit"' "${path}/package.json" 2>/dev/null; then
        printf 'sveltekit'
        return 0
    fi

    printf 'none'
}

#------------------------------------------------------------
# Plugin contract — env-block validation (S9)
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
# Lifecycle workers
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

# Smart-purge: remove only the artifacts a Node env generates. Never
# touches package.json, lockfiles, or source (S9 / N.r smart-purge rule).
# The removed set is kept consistent with node_pyve_plugin_purge_inventory's
# "created" declaration (N.z).
_node_purge_at() {
    local path="$1"
    local d
    for d in node_modules .svelte-kit dist build .next .turbo; do
        if [[ -e "$path/$d" ]]; then
            rm -rf "${path:?}/$d"
        fi
    done

    # *.tsbuildinfo (TypeScript incremental build info) — file glob. Use a
    # local nullglob so a no-match expands to nothing instead of a literal.
    local f had_nullglob=0
    shopt -q nullglob && had_nullglob=1
    shopt -s nullglob
    for f in "$path"/*.tsbuildinfo; do
        rm -f "$f"
    done
    [[ "$had_nullglob" -eq 0 ]] && shopt -u nullglob
    return 0
}

#------------------------------------------------------------
# Plugin contract — lifecycle hooks
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
    # A declared Node path with no package.json is a scaffold-time
    # declaration (e.g. `pyve init --node-path apps/web` before the app
    # exists): the manifest records the intended path, but there is nothing
    # to install yet. Skip with an advisory rather than failing init — the
    # install runs later via `pyve env install` once package.json is added.
    if [[ ! -f "${path}/package.json" ]]; then
        info "node: no package.json at '${path}' — skipping install (add dependencies, then run 'pyve env install')"
        return 0
    fi
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

#------------------------------------------------------------
# Plugin contract — runtime hooks
#
# check / status / run / test for Node envs. Signatures take an explicit
# <path> [<backend>] (not yet CLI-routed; N-4 threads them from the
# manifest). check and status render the S7 (manual_steps) and S11
# (typescript) advisories before/after their body; test honestly
# delegates to the user's package.json `test` script via the provider.
#------------------------------------------------------------

# Portable file mtime: BSD/macOS `stat -f`, then GNU `stat -c`.
_node_mtime() {
    stat -f '%Sm' "$1" 2>/dev/null || stat -c '%y' "$1" 2>/dev/null || printf 'unknown'
}

# S7 + S11 advisory renderer (parallels the Python plugin's). Iterates
# declared envs and prints:
#   - a "Manual steps" section for each env's non-empty manual_steps (S7)
#   - a typescript warning when an env declares languages including
#     "typescript" but package.json at <path> has no typescript dep (S11)
# Always returns 0 — advisories never fail.
_node_pyve_plugin_render_advisories() {
    local path="${1:-.}"
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    local n=${#PYVE_ENV_NAMES[@]}
    [[ "$n" -eq 0 ]] && return 0

    local i name step
    local -a steps langs
    local manual_header_printed=0

    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"

        # S7: manual_steps
        steps=()
        manifest_get_manual_steps "$name" steps 2>/dev/null || true
        if [[ "${#steps[@]}" -gt 0 ]]; then
            if [[ "$manual_header_printed" -eq 0 ]]; then
                printf "Manual steps (advisory — pyve does not run these):\n"
                manual_header_printed=1
            fi
            printf "  env '%s':\n" "$name"
            for step in "${steps[@]}"; do
                printf "    - %s\n" "$step"
            done
        fi

        # S11: typescript declared but not a package.json dependency.
        langs=()
        manifest_get_languages "$name" langs 2>/dev/null || true
        if [[ "${#langs[@]}" -gt 0 ]]; then
            local lang has_ts=0
            for lang in "${langs[@]}"; do
                [[ "$lang" == "typescript" ]] && { has_ts=1; break; }
            done
            if [[ "$has_ts" -eq 1 ]] \
               && ! grep -q '"typescript"' "$path/package.json" 2>/dev/null; then
                warn "env '$name' declares typescript but 'typescript' is not in package.json dependencies"
            fi
        fi

        # S11: frameworks attribute — advisory surfacing only.
        local -a fws
        fws=()
        manifest_get_frameworks "$name" fws 2>/dev/null || true
        if [[ "${#fws[@]}" -gt 0 ]]; then
            info "env '$name' frameworks: ${fws[*]}"
        fi
    done
    return 0
}

# Verify the env is healthy. Hard checks (runtime, package.json,
# node_modules) drive the exit code; the S7/S11 advisories are
# informational and never change it.
node_pyve_plugin_check() {
    local path="${1:-.}"
    local failed=0

    _node_pyve_plugin_render_advisories "$path"

    if node_runtime_resolve >/dev/null 2>&1; then
        success "Node runtime: $(node_runtime_resolve 2>/dev/null) (manager: $(node_runtime_manager))"
    else
        log_error "No Node runtime detected — install via Homebrew or your preferred version manager (nvm / fnm / volta)"
        failed=1
    fi

    if [[ -f "$path/package.json" ]]; then
        success "package.json present"
    else
        log_error "package.json not found at '$path'"
        failed=1
    fi

    if [[ -d "$path/node_modules" ]] && [[ -n "$(ls -A "$path/node_modules" 2>/dev/null)" ]]; then
        success "node_modules present"
    else
        log_error "node_modules missing or empty — run init to install dependencies"
        failed=1
    fi

    return "$failed"
}

# Summarize the Node env: backend/provider, lockfile state, node_modules
# state, package.json mtime, plus the S7/S11 advisories.
node_pyve_plugin_status() {
    local path="${1:-.}"
    local backend="${2:-}"
    local provider
    provider="$(node_provider_detect "$backend" "$path")"

    info "Backend: $provider"

    local lockfile
    lockfile="$(node_provider_lockfile "$provider" 2>/dev/null)"
    if [[ -n "$lockfile" && -f "$path/$lockfile" ]]; then
        info "Lockfile: $lockfile (present)"
    else
        info "Lockfile: none"
    fi

    if [[ -d "$path/node_modules" ]] && [[ -n "$(ls -A "$path/node_modules" 2>/dev/null)" ]]; then
        info "node_modules: present"
    else
        info "node_modules: missing"
    fi

    if [[ -f "$path/package.json" ]]; then
        info "package.json last modified: $(_node_mtime "$path/package.json")"
    fi

    _node_pyve_plugin_render_advisories "$path"
    return 0
}

# Passthrough execution. Puts the env's node_modules/.bin on PATH so
# locally-installed tools (vitest, tsc, eslint, …) resolve, then runs the
# command. N.y moves this PATH activation into the env's `.envrc`; this
# hook is the direct-invocation path.
node_pyve_plugin_run() {
    local path="$1"
    shift
    (
        cd "$path" || exit 1
        PATH="$PWD/node_modules/.bin:$PATH" "$@"
    )
}

# Honest delegation: run `<provider> test`, which forwards to the user's
# package.json `test` script (vitest / jest / playwright / mocha / …).
node_pyve_plugin_test() {
    local path="${1:-.}"
    local backend="${2:-}"
    local provider
    provider="$(node_provider_detect "$backend" "$path")"
    (
        cd "$path" || exit 1
        case "$provider" in
            pnpm|npm|yarn) "$provider" test ;;
            *)
                printf "error: node plugin: unknown provider '%s'\n" "$provider" >&2
                exit 1
                ;;
        esac
    )
}

#------------------------------------------------------------
# Plugin contract — activate
#
# Compose → validate → emit. The Node plugin's `.envrc` contribution is
# a single `PATH_add` for the env's node_modules/.bin so locally-installed
# tools (vitest, tsc, eslint, …) resolve. Unlike the Python plugin
# (venv→VIRTUAL_ENV vs micromamba→CONDA_PREFIX), Node activation is
# uniform across providers (pnpm/npm/yarn) — no per-provider branch.
#
# Path-aware: a sub-path plugin (path = "src/frontend") emits
# `PATH_add "src/frontend/node_modules/.bin"` so direnv resolves the
# absolute dir correctly at eval time. Uses PATH_add — never a
# hand-rolled `export PATH=` — per the Uniform .envrc template rule.
#
# The section is wrapped in per-plugin sentinel markers and emitted to
# stdout: N-4's composer assembles each plugin's section into one
# `.envrc`. PC-1 (validate_envrc_snippet, N.m) gates the output — a
# path carrying command substitution / backticks halts with no emission.
#------------------------------------------------------------

# Compose the sentinel-wrapped Node `.envrc` section for <path>.
_node_pyve_plugin_envrc_snippet() {
    local path="${1:-.}"
    local bin_dir
    if [[ -z "$path" || "$path" == "." ]]; then
        bin_dir="node_modules/.bin"
    else
        # Strip a trailing slash so we don't emit a double slash.
        bin_dir="${path%/}/node_modules/.bin"
    fi
    cat <<EOF
# >>> pyve:plugin:node:activate >>>
PATH_add "$bin_dir"
# <<< pyve:plugin:node:activate <<<
EOF
}

node_pyve_plugin_activate() {
    local path="${1:-.}"
    local snippet
    snippet="$(_node_pyve_plugin_envrc_snippet "$path")" || return $?
    if ! validate_envrc_snippet "$snippet"; then
        log_error "node plugin: activate: snippet failed PC-1 validation"
        return 1
    fi
    printf '%s\n' "$snippet"
}

#------------------------------------------------------------
# Plugin contract — gitignore_entries
#
# Returns the Node-ecosystem patterns the plugin contributes to
# `.gitignore`. Output flows through validate_gitignore_snippet (N.m
# PC-1 gate) at the composer; it is designed to pass that allow-list
# (plain globs, no `$`/backticks). Path-aware: a sub-path plugin prefixes
# each pattern with its path so the entry anchors to that sub-tree;
# comment / blank lines are never prefixed.
#------------------------------------------------------------

_node_gitignore_patterns() {
    cat <<'EOF'
# Node ecosystem artifacts
node_modules/
.svelte-kit/
dist/
build/
.next/
*.tsbuildinfo
.turbo/
.parcel-cache/
npm-debug.log*
yarn-debug.log*
pnpm-debug.log*
EOF
}

node_pyve_plugin_gitignore_entries() {
    local path="${1:-.}"
    local prefix=""
    [[ -n "$path" && "$path" != "." ]] && prefix="${path%/}/"
    _node_gitignore_patterns | awk -v p="$prefix" '
        /^[[:space:]]*$/ { print; next }
        /^[[:space:]]*#/ { print; next }
        { print p $0 }
    '
}

#------------------------------------------------------------
# Plugin contract — purge_inventory
#
# Declares the Node ecosystem's created-vs-authored split:
#   created <path>   — package-manager / build generated; safe to remove.
#   authored <path>  — user-written; never touch on purge.
# Like the Python plugin's (N.r), this is a declarative data interface;
# the actual remover is _node_purge_at, kept consistent with the
# `created` list here. Path-aware: a sub-path plugin prefixes the path
# token of each entry.
#------------------------------------------------------------

_node_purge_inventory_lines() {
    cat <<'EOF'
created node_modules
created .svelte-kit
created dist
created build
created .next
created .turbo
created *.tsbuildinfo
authored package.json
authored pnpm-lock.yaml
authored package-lock.json
authored yarn.lock
authored tsconfig.json
authored svelte.config.js
EOF
}

node_pyve_plugin_purge_inventory() {
    local path="${1:-.}"
    local prefix=""
    [[ -n "$path" && "$path" != "." ]] && prefix="${path%/}/"
    _node_purge_inventory_lines | awk -v p="$prefix" '{ print $1, p $2 }'
}
