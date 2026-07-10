# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/python/plugin.sh — Python plugin
#
# First reference implementation of the plugin contract from N.k.
# Re-seats the Python ecosystem behind the contract. This story
# implements the plugin-contract hooks:
#
#   python_pyve_plugin_manifest_namespace   — returns "python"
#   python_pyve_plugin_register_backends    — bp_register venv + micromamba
#   python_pyve_plugin_detect               — scaffold-time file-signal scan
#
# (The N.l-era backend-provider activate shims `venv_pyve_bp_activate` /
# `micromamba_pyve_bp_activate` and the legacy `write_envrc_template` /
# `write_gitignore_template` writer chains were retired once
# the composition layer (N.ae/N.af) fully superseded them; activation now
# flows through `python_pyve_plugin_activate` → `_python_pyve_plugin_envrc_snippet`.)
#
# Lifecycle hooks (init / purge / update / check / status / run /
# test) start as no-op defaults from contract.sh; the Python plugin
# implements init/purge/update (lifecycle) and check/status/run/test
# (runtime). The activation hook (`.envrc` snippet composition) and the
# gitignore + smart-purge hooks are implemented below.
#
# Detection contract (per task list + spike):
#   Signal classes (probed at the project root):
#     Python: pyproject.toml | requirements*.txt | setup.py | *.py
#     Conda:  environment*.yml | conda-lock.yml
#   Output:
#     - both classes present → "ambiguous"
#     - only conda           → "micromamba"
#     - only python          → "venv"
#     - neither              → "none"
#
# Per the spike, detection is scaffold-time only: once `pyve.toml`
# exists, the manifest is the runtime source of truth.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Plugin contract — manifest_namespace
#------------------------------------------------------------

python_pyve_plugin_manifest_namespace() {
    printf 'python'
}

#------------------------------------------------------------
# Plugin contract — register_backends
#
# bp_register is idempotent for identical re-registration, so this
# hook is safe to call multiple times (the eager source-time call
# and any later contract-driven re-fire both land on a consistent
# registry state).
#------------------------------------------------------------

python_pyve_plugin_register_backends() {
    bp_register python venv virtualized
    bp_register python micromamba virtualized
}

#------------------------------------------------------------
# Plugin contract — detect (scaffold-time only)
#------------------------------------------------------------

python_pyve_plugin_detect() {
    local has_python=false
    local has_conda=false

    # Python signal probes. compgen -G is a bash builtin (no subshell,
    # bash 3.2-safe); returns 0 with the match list when at least one
    # path expands, 1 otherwise. We discard the output.
    if [[ -f "pyproject.toml" ]] \
        || [[ -f "setup.py" ]] \
        || compgen -G "requirements*.txt" >/dev/null 2>&1 \
        || compgen -G "*.py" >/dev/null 2>&1; then
        has_python=true
    fi

    # Conda signal probes.
    if [[ -f "conda-lock.yml" ]] \
        || compgen -G "environment*.yml" >/dev/null 2>&1; then
        has_conda=true
    fi

    if [[ "$has_python" == true ]] && [[ "$has_conda" == true ]]; then
        printf 'ambiguous'
    elif [[ "$has_conda" == true ]]; then
        printf 'micromamba'
    elif [[ "$has_python" == true ]]; then
        printf 'venv'
    else
        printf 'none'
    fi
}

#------------------------------------------------------------
# Plugin contract — lifecycle hooks (Option 2)
#
# Hook-as-shim re-seat: each hook validates the manifest's env
# blocks (per S9), reads the `languages` advisory (per S11; v3.0
# is read-only, N.p surfaces it in `pyve check` / `pyve status`),
# and delegates to the existing `init_project` / `purge_project` /
# `update_project` implementations in lib/commands/*.sh. The
# implementations stay there in N.o; N.s revisits whether to
# relocate them into this plugin file.
#------------------------------------------------------------

# S9 env-block validation. Iterates every declared env; checks
# `purpose` ∈ {run, test, utility, temp} (the helper itself catches
# unknown purposes at parse time, so this is a defense-in-depth
# secondary check), and `backend`, if non-empty, must be a registered
# backend-provider name (bp_lookup returns 0). Empty backend is
# allowed — the manifest doesn't require it; commands resolve a
# default elsewhere.
python_pyve_plugin_validate_env_blocks() {
    local n
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    n=${#PYVE_ENV_NAMES[@]}
    [[ "$n" -eq 0 ]] && return 0

    local i name purpose backend
    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"
        purpose="${PYVE_ENV_PURPOSE[$i]}"
        backend="${PYVE_ENV_BACKEND[$i]}"

        # purpose check — empty is allowed (manifest_resolve_purpose
        # applies a name-based default elsewhere). Non-empty values
        # are validated by the Python helper at parse time; we
        # double-check here so a synthesized v2 read-compat shape
        # can't slip through with an unexpected value.
        if [[ -n "$purpose" ]]; then
            case "$purpose" in
                run|test|utility|temp) ;;
                *)
                    printf "error: python plugin: env '%s' has unknown purpose '%s' (expected one of: run, test, utility, temp)\n" \
                        "$name" "$purpose" >&2
                    return 1
                    ;;
            esac
        fi

        # backend check — bp_lookup returns 1 (no output) for
        # unregistered backends. An *advisory* backend (e.g. `none`) is
        # intentionally unregistered: it is declarable but not materialized
        # by pyve (a runtime-less / non-Python root), so the materializer
        # skips it with a note rather than building an env. Let it through
        # here; only a genuinely-unknown backend hard-errors.
        if [[ -n "$backend" ]] && ! bp_lookup "$backend" >/dev/null 2>&1; then
            if ! _env_backend_is_advisory "$backend"; then
                printf "error: python plugin: env '%s' declares unregistered backend '%s'\n" \
                    "$name" "$backend" >&2
                return 1
            fi
        fi
    done
    return 0
}

# S11 languages advisory read. Currently a no-op data-flow probe:
# iterates declared envs and reads `languages` via the manifest
# accessor. N.p will surface the read in `pyve check` / `pyve status`.
# Read failures (unknown env, unset languages) are silent — the field
# is advisory, not load-bearing.
_python_pyve_plugin_languages_advisory_read() {
    local n
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    n=${#PYVE_ENV_NAMES[@]}

    local i name
    local -a _langs
    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"
        _langs=()
        manifest_get_languages "$name" _langs 2>/dev/null || true
        # _langs is intentionally unused in N.o — N.p threads it
        # into the diagnostics output. The read confirms the data
        # flow is wired so N.p can rely on it without a schema change.
    done
    return 0
}

python_pyve_plugin_init() {
    python_pyve_plugin_validate_env_blocks || return $?
    _python_pyve_plugin_languages_advisory_read
    init_project "$@"
}

python_pyve_plugin_purge() {
    purge_project "$@"
}

python_pyve_plugin_update() {
    update_project "$@"
}

#------------------------------------------------------------
# Plugin contract — runtime hooks (Option 2)
#
# Hook-as-shim: check / status / run / test delegate to today's
# implementations in lib/commands/{check,status,run,test}.sh.
# check and status additionally render the S7 manual_steps advisory
# and the S11 languages advisory before delegating; run and test
# are pure forwarders.
#
# Render-before-delegate placement: advisories print at the top so
# the user sees relevant setup context before the diagnostic body.
# `check_environment` and `show_status` exit the process from their
# summary functions, so render-AFTER-delegate isn't reachable.
#------------------------------------------------------------

# S7 + S11 advisory renderer. Iterates declared envs and prints:
#   - "Manual steps" section listing each env's non-empty manual_steps
#   - "Warning: env '<name>' declares languages without 'python'"
# Silent when no env has manual_steps and no env has a mismatched
# languages list. Exit code always 0 — advisories are informational.
_python_pyve_plugin_render_advisories() {
    [[ -n "${PYVE_ENV_NAMES+x}" ]] || return 0
    local n=${#PYVE_ENV_NAMES[@]}
    [[ "$n" -eq 0 ]] && return 0

    local i name
    local -a steps langs
    local manual_header_printed=0
    local manual_count step

    for ((i=0; i<n; i++)); do
        name="${PYVE_ENV_NAMES[$i]}"

        # S7: manual_steps
        steps=()
        manifest_get_manual_steps "$name" steps 2>/dev/null || true
        manual_count="${#steps[@]}"
        if [[ "$manual_count" -gt 0 ]]; then
            if [[ "$manual_header_printed" -eq 0 ]]; then
                printf "Manual steps (advisory — pyve does not run these):\n"
                manual_header_printed=1
            fi
            printf "  env '%s':\n" "$name"
            for step in "${steps[@]}"; do
                printf "    - %s\n" "$step"
            done
        fi

        # S11: languages declared but no 'python' present.
        langs=()
        manifest_get_languages "$name" langs 2>/dev/null || true
        if [[ "${#langs[@]}" -gt 0 ]]; then
            local found_python=0 lang
            for lang in "${langs[@]}"; do
                [[ "$lang" == "python" ]] && { found_python=1; break; }
            done
            if [[ "$found_python" -eq 0 ]]; then
                printf "warning: env '%s' declares languages = [%s] without 'python' — the Python plugin manages this env\n" \
                    "$name" "${langs[*]}"
            fi
        fi
    done
    return 0
}

#------------------------------------------------------------
# Plugin contract — PC-4a no-Python noise suppression
#
# `python_plugin_is_active_in_project` gates the Python plugin's
# diagnostic hooks (check / status). Pyve defaults to Python, so the
# gate is deliberately generous:
#
#   ACTIVE (return 0) on ANY Python signal:
#     - `[plugins.python]` declared in pyve.toml
#     - any declared env with a Python backend (venv / micromamba) or
#       `languages` containing `python` (an explicit Python env declaration)
#       (`.project-guide.yml` is NOT a signal — project-guide is globally
#        hosted, so its per-project marker no longer implies a project
#        Python env.)
#     - root-scoped Python application files
#       (pyproject.toml / setup.py / requirements*.txt /
#        environment*.yml / *.py). Root-scoped via `compgen -G` so
#       `node_modules/**/*.py` and a hosting `.venv/**/*.py` never
#       false-trigger.
#   ACTIVE on a bare dir with NO competing stack — Pyve treats an
#     otherwise-empty project as Python-by-default, so `pyve check`
#     keeps its "config missing → run pyve init" nudge.
#   SUPPRESS (return 1) ONLY when there is no Python signal at all AND a
#     competing non-Python stack is present (e.g. a `package.json`, or an
#     active non-Python plugin) — the Node-only-declined-project case.
#
# Scope: the gate is applied to check / status — the hooks that emit
# user-facing diagnostic output. The composition hooks (activate /
# gitignore_entries / purge_inventory) are already excluded for declared
# non-Python projects by the active-plugin registry (a project that
# declares `[plugins.node]` never registers Python); the lifecycle/action
# hooks (init / update / run / test / purge) are explicit user intent and
# not gated. So check / status are the precise PC-4a safety net for the
# implicit-Python edge.
#------------------------------------------------------------

# True (0) when a competing non-Python stack is present. Today the marker
# is Node's `package.json`; extend as plugins are added. Also treats any
# active plugin other than `python` as a competing stack.
_python_plugin_competing_stack_present() {
    [[ -f "package.json" ]] && return 0
    local p
    while IFS= read -r p; do
        [[ -n "$p" && "$p" != "python" ]] && return 0
    done < <(plugin_list_active 2>/dev/null)
    return 1
}

python_plugin_is_active_in_project() {
    # 1. Declared Python plugin.
    if manifest_list_plugins 2>/dev/null | grep -qx 'python'; then
        return 0
    fi

    # 2. Any declared env with a Python backend or `languages: python`.
    local env backend
    while IFS= read -r env; do
        [[ -z "$env" ]] && continue
        backend="$(manifest_get_backend "$env" 2>/dev/null || true)"
        if [[ "$backend" == "venv" || "$backend" == "micromamba" ]]; then
            return 0
        fi
        local -a _langs=()
        manifest_get_languages "$env" _langs 2>/dev/null || true
        local l
        for l in "${_langs[@]+"${_langs[@]}"}"; do
            [[ "$l" == "python" ]] && return 0
        done
    done < <(manifest_list_envs 2>/dev/null)

    # 3. Root-scoped Python application files (no recursion — `compgen -G`).
    #    (`.project-guide.yml` is NO longer a Python-active signal —
    #    project-guide is globally hosted, so its per-project marker no longer
    #    implies a project Python env. On a Node-only project that accepts
    #    project-guide there is no `.venv` for the Python plugin to report, so
    #    it must stay suppressed.)
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] \
        || compgen -G "requirements*.txt" >/dev/null 2>&1 \
        || compgen -G "environment*.yml" >/dev/null 2>&1 \
        || compgen -G "*.py" >/dev/null 2>&1; then
        return 0
    fi

    # No Python signal. Suppress ONLY with a competing non-Python stack;
    # otherwise stay active (Pyve defaults to Python on a bare project).
    if _python_plugin_competing_stack_present; then
        return 1
    fi
    return 0
}

python_pyve_plugin_check() {
    # the composer (compose_check) passes the plugin's declared
    # path as $1. Python always operates at the project root, so consume and
    # ignore it; forwarding it to check_environment would trip its
    # "takes no positional arguments" guard. User flags (`pyve check --x`)
    # are validated upstream in compose_check before any hook runs.
    [[ $# -gt 0 ]] && shift
    # PC-4a — suppress all Python diagnostic output when there
    # is no Python surface and a competing stack is present.
    python_plugin_is_active_in_project || return 0
    _python_pyve_plugin_render_advisories
    check_environment "$@"
}

python_pyve_plugin_status() {
    # the composer (compose_status) passes the plugin's declared
    # path as $1. Python operates at the project root, so consume and ignore
    # it (forwarding it would trip show_status's positional-arg guard). User
    # flags are validated upstream in compose_status before any hook runs.
    [[ $# -gt 0 ]] && shift
    # PC-4a — see python_pyve_plugin_check.
    python_plugin_is_active_in_project || return 0
    _python_pyve_plugin_render_advisories
    show_status "$@"
}

python_pyve_plugin_run() {
    run_command "$@"
}

python_pyve_plugin_test() {
    test_tests "$@"
}

#------------------------------------------------------------
# Plugin contract — activate
#
# Plugin-level activation: compose the plugin-owned `.envrc` snippet
# (the 5 lines the Python plugin contributes — PATH_add + four
# `export VAR=...` lines), run it through validate_envrc_snippet
#, then delegate the actual file write
# to bp_dispatch <backend> activate.
#
# The infrastructure lines around the plugin snippet (the
# `# pyve-managed direnv configuration` header, the
# `if [[ -f ".env" ]]; then dotenv; fi` block, the asdf compat block)
# are composer-owned and not validated — they're never plugin-emitted.
# That boundary keeps the strict N.m allow-list usable for plugins
# without retroactively rewriting the existing template.
#------------------------------------------------------------

# Compose the plugin-owned `.envrc` snippet (5 lines: PATH_add +
# 4 exports). `env_root_expr` rule: absolute env-root paths pass through;
# relative paths get prefixed with `$PWD/` so direnv resolves them against
# the `.envrc` directory rather than the caller's cwd. (This snippet
# replaced the retired `write_envrc_template`'s emission)
_python_pyve_plugin_envrc_snippet() {
    local backend="$1"
    local env_path="$2"
    local env_name="$3"

    local sentinel_var rel_bin_dir
    case "$backend" in
        venv)
            sentinel_var="VIRTUAL_ENV"
            rel_bin_dir="$env_path/bin"
            ;;
        micromamba)
            sentinel_var="CONDA_PREFIX"
            rel_bin_dir="$env_path/bin"
            ;;
        *)
            printf "error: python plugin: snippet: unknown backend '%s'\n" "$backend" >&2
            return 1
            ;;
    esac

    local env_root_expr
    if [[ "$env_path" == /* ]]; then
        env_root_expr="$env_path"
    else
        env_root_expr="\$PWD/$env_path"
    fi

    cat <<EOF
PATH_add "$rel_bin_dir"
export $sentinel_var="$env_root_expr"
export PYVE_BACKEND="$backend"
export PYVE_ENV_NAME="$env_name"
export PYVE_PROMPT_PREFIX="($backend:$env_name) "
EOF
}

#------------------------------------------------------------
# Plugin contract — gitignore_entries
#
# Returns the Python-ecosystem patterns the plugin contributes to
# `.gitignore`. Output flows through validate_gitignore_snippet
# before being written. Composer-owned lines
# (macOS `.DS_Store`, Pyve-managed `.pyve/envs`, the dynamic venv
# directory) are emitted by `lib/gitignore_composer.sh` — same plugin-vs-
# infrastructure boundary as N.q used for `.envrc`.
#------------------------------------------------------------

python_pyve_plugin_gitignore_entries() {
    cat <<'EOF'
# Python build and test artifacts
__pycache__
*.pyc
*.pyo
*.pyd
*.egg-info
*.egg
.coverage
coverage.xml
htmlcov/
.pytest_cache/
dist/
build/

# Jupyter notebooks
.ipynb_checkpoints/
*.ipynb_checkpoints
EOF
}

#------------------------------------------------------------
# Plugin contract — purge_inventory
#
# Declares the paths the Python plugin manages, split into two
# classes:
#   - `created <path>`   — Pyve-created; safe to remove on purge.
#   - `authored <path>`  — user-authored; never touch on purge.
#
# v3.0 ships this as a data interface — `purge_project` reads but
# does not consume it for removal decisions. The existing hardcoded
# removal calls inside `purge_project` (relocated into this file in
# N.s.2) stay direct. The seam is in
# place for future plugins (Node, etc.) that need to declare their
# own creation/authorship surfaces.
#------------------------------------------------------------

python_pyve_plugin_purge_inventory() {
    # Existence-gated so the composed `pyve purge` preview reflects THIS
    # project's actual artifacts — listing only what is present keeps the
    # confirmation honest (no phantom entries, and no silent removals like
    # the .tool-versions one N.bf.3 fixed). Two display classes, consumed by
    # the purge composer:
    #   created — pyve-generated; the purge hook removes it wholesale.
    #   tidied  — pyve touches only its OWN part: .gitignore (its section is
    #             stripped, the file stays) or .env (removed only if empty).
    # Scope note: the remover does `rm -rf .pyve` (whole dir), so we declare
    # `.pyve`, not the narrower `.pyve/envs` the preview used to under-report.
    # The `authored` guards are presence-independent — they protect user
    # files from removal whether or not they exist yet.
    local envf="${ENV_FILE_NAME:-.env}"
    if [[ -d .venv ]];           then printf 'created .venv\n'; fi
    if [[ -d .pyve ]];           then printf 'created .pyve\n'; fi
    if [[ -f .envrc ]];          then printf 'created .envrc\n'; fi
    if [[ -f .tool-versions ]];  then printf 'created .tool-versions\n'; fi
    if [[ -f .python-version ]]; then printf 'created .python-version\n'; fi
    if [[ -f "$envf" ]];         then printf 'tidied %s\n' "$envf"; fi
    if [[ -f .gitignore ]];      then printf 'tidied .gitignore\n'; fi
    printf 'authored pyproject.toml\n'
    printf 'authored requirements*.txt\n'
    printf 'authored setup.py\n'
    printf 'authored environment.yml\n'
}

# Plugin activate hook.
#
# Uniform composer-facing contract (spike N.ae.1, decision 1): the hook
# takes a single optional `<path>` (the plugin's manifest path — always
# "." for Python, which owns the project root) and emits a sentinel-wrapped
# `.envrc` section to STDOUT, matching node_pyve_plugin_activate. It performs
# NO file write — the composed `.envrc` is assembled and atomically written
# by compose_envrc.
#
# Self-resolution: backend / env_path / env_name come from the v3 manifest
# and resolvers:
#   - backend:  `manifest_get_backend root` → "venv"
#   - venv:     env_path = ".venv" (`resolve_venv_directory`); env_name = basename "$PWD"
#   - micromamba: env_name from `environment.yml` `name:`
#               (`resolve_micromamba_env_name`) → basename;
#               env_path = ".pyve/envs/<env_name>"
#
# Compose → PC-1 validate → emit. On validation failure (a buggy/malicious
# snippet composer), aborts non-zero with the offending line on stderr and
# emits no section.
python_pyve_plugin_activate() {
    # <path> accepted for uniform composer dispatch; Python owns root, so
    # the value is not consulted (the venv/micromamba env paths are
    # resolved from project state below).
    local _path="${1:-.}"

    # Backend from the manifest (authoritative; `compose_project_envrc` calls
    # `manifest_load` before dispatching activate).
    local backend
    backend="$(manifest_get_backend root 2>/dev/null || true)"
    [[ -z "$backend" ]] && backend="venv"

    local env_path env_name
    case "$backend" in
        venv)
            env_path="$(resolve_venv_directory)"
            env_name="$(basename "$PWD")"
            ;;
        micromamba)
            # PYVE_ENV_NAME stays the configured (human-facing) name; the
            # CONDA_PREFIX/PATH come from the v3 root slot (Story N.bf.14).
            env_name="$(resolve_micromamba_env_name)"
            [[ -z "$env_name" ]] && env_name="$(basename "$PWD")"
            env_path="$(micromamba_root_prefix)"
            ;;
        *)
            # An advisory root backend (e.g. `none`) is a runtime-less /
            # non-Python root: there is no Python env to activate, so the
            # Python plugin contributes no .envrc section (the composer
            # assembles the rest). A genuinely-unknown backend still errors.
            if _env_backend_is_advisory "$backend"; then
                return 0
            fi
            log_error "python plugin: activate: unknown backend '$backend'"
            return 1
            ;;
    esac

    # PC-1 gate over the plugin-owned snippet (the five PATH_add/export lines).
    local snippet
    snippet="$(_python_pyve_plugin_envrc_snippet "$backend" "$env_path" "$env_name")" || return $?
    if ! validate_envrc_snippet "$snippet"; then
        log_error "python plugin: activate: snippet failed PC-1 validation"
        return 1
    fi

    # Emit the sentinel-wrapped section (composer-ready; matches Node).
    printf '# >>> pyve:plugin:python:activate >>>\n%s\n# <<< pyve:plugin:python:activate <<<\n' "$snippet"
}

#------------------------------------------------------------
# `pyve python <sub>` — Python-version-management namespace
#
# The namespace dispatcher (`python_command`) and its leaves
# (`python_set`, `python_show`) form a single-file namespace per the
# project-essentials "Namespace commands are single files" rule.
# These are not plugin-contract hooks — they're Python-specific
# version-pin management surfaces. The dispatcher is invoked by
# pyve.sh's case arm as `python_command "$@"`; bash function lookup
# is global, so the leaves resolve by name regardless of file.
#
# Function-name note: the dispatcher is named `python_command`, NOT
# `python`, because `python` is the bare binary name invoked by
# `init` (and elsewhere) for venv creation. A bash function named
# `python` would shadow the interpreter and break every internal
# call to it. See project-essentials' "Function-name collision rule".
#------------------------------------------------------------

python_set() {
    if [[ $# -lt 1 ]]; then
        log_error "pyve python set requires a version argument"
        log_error "Usage: pyve python set <version>"
        log_error "Example: pyve python set 3.13.7"
        exit 1
    fi

    local version="$1"

    header_box "pyve python set"

    if ! validate_python_version "$version"; then
        exit 1
    fi

    banner "Setting Python version to $version"

    source_shell_profiles

    if ! detect_version_manager; then
        exit 1
    fi

    if ! ensure_python_version_installed "$version"; then
        exit 1
    fi

    set_local_python_version "$version"

    local version_file
    version_file="$(get_version_file_name)"
    success "Set Python $version in $version_file"
    footer_box
}

python_show() {
    local out version source
    out="$(resolve_python_version)"
    version="${out%%|*}"
    source="${out##*|}"
    case "$source" in
        tool-versions)  source=".tool-versions" ;;
        python-version) source=".python-version" ;;
    esac

    if [[ -z "$version" ]]; then
        printf "No Python version pinned in this project.\n"
        printf "  (not pinned — use 'pyve python set <version>' to pin one)\n"
        return 0
    fi
    printf "Python %s (from %s)\n" "$version" "$source"
}

# Nested-subcommand dispatcher for `pyve python <action> [args]`.
python_command() {
    if [[ $# -lt 1 ]]; then
        log_error "pyve python requires a subcommand"
        log_error "Usage: pyve python set <version>"
        log_error "       pyve python show"
        log_error "See: pyve python --help"
        exit 1
    fi

    local sub="$1"
    shift

    case "$sub" in
        set)
            python_set "$@"
            ;;
        show)
            if [[ $# -gt 0 ]]; then
                log_error "pyve python show takes no arguments (got: $1)"
                exit 1
            fi
            python_show
            ;;
        *)
            log_error "Unknown python subcommand: $sub"
            log_error "Usage: pyve python set <version>"
            log_error "       pyve python show"
            exit 1
            ;;
    esac
}

show_python_help() {
    cat << 'EOF'
pyve python - Manage the project's Python version pin

Usage:
  pyve python set <version>
  pyve python show

Subcommands:
  set <version>     Pin the project's Python version (format: #.#.#)
                    Writes to .tool-versions (asdf) or .python-version (pyenv)
  show              Print the currently pinned Python version

Examples:
  pyve python set 3.13.7
  pyve python show

See `pyve --help` for the full command list.
EOF
}

#============================================================
# pyve init — initialize a Python virtual environment
# (Option 1 relocation from lib/commands/init.sh)
#
# Auto-detects backend (venv vs micromamba), resolves the version
# manager (asdf or pyenv), creates the environment, configures
# direnv (unless --no-direnv), scaffolds pyve.toml, and runs the
# project-guide post-init hooks.
#
# Function-name note: this function is named `init_project` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve init` operates on the project (creates venv, scaffolds
# pyve.toml, configures direnv, etc.).
#
# Cross-command callsite: `init_project --force` calls
# `purge_project --keep-testenv --yes` — both functions now live in
# this file (init_project relocated in N.s.1, purge_project in N.s.2).
# Bash resolves the call at runtime via the global function table.
#
# Init-private helpers (per project-essentials F): `_init_` prefix
# on all single-caller helpers — the surviving config-writers
# (`_init_python_version`, `_init_venv`, `_init_dotenv`). The
# project-guide orchestration (formerly `_init_run_project_guide_hooks`)
# was lifted to the stack-agnostic `lib/project_guide.sh`
# (`run_project_guide_orchestration`). The `.envrc` / `.gitignore`
# writers (`_init_direnv_*`, `_init_gitignore`) were retired in Story
# N.al — `init_project` composes those files through
# `compose_project_envrc` / `compose_project_gitignore` instead.
#============================================================

# Repo-signal helper: detect the default backend for this project.
#
# Returns one of:
#   micromamba   if environment.yml exists in cwd
#   venv         if .python-version or .tool-versions exists, OR no signals at all
#
# environment.yml wins over the venv-side signals so a project with
# both env.yml (added recently) and an old .tool-versions still resolves
# to micromamba.
_init_detect_backend_default() {
    if [[ -f environment.yml ]]; then
        printf 'micromamba\n'
    elif [[ -f .python-version ]] || [[ -f .tool-versions ]]; then
        printf 'venv\n'
    else
        printf 'venv\n'
    fi
}

# Print the backend declared for the reserved `root` env in pyve.toml,
# or empty when no manifest exists / root declares no backend. On a
# forced or refresh rebuild this is authoritative: the manifest records
# the project's chosen backend, so a rebuild must honor it rather than
# re-derive from filesystem heuristics (which silently convert the
# backend when the heuristic disagrees — e.g. a declared micromamba env
# whose root has no environment.yml). Empty output keeps the heuristic
# as the fresh-init fallback. Failures to load (no usable interpreter)
# degrade to empty, never abort.
_init_manifest_root_backend() {
    [[ -f pyve.toml ]] || return 0
    manifest_load pyve.toml >/dev/null 2>&1 || return 0
    manifest_get_backend root 2>/dev/null || true
}

# Absolute path to the in-place manifest writer (resolved once at source time;
# lib/plugins/python/plugin.sh → ../../ is lib/).
_PYVE_MANIFEST_WRITE_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pyve_manifest_write.py"

# Ensure pyve.toml's [env.root] records the resolved backend. Used on the refresh
# / --force path where pyve.toml already exists, so _init_scaffold_manifest would
# otherwise no-op and leave the canonical manifest backend-less (the split-brain
# `pyve status` reports "not configured"). A structure-preserving tomlkit edit
# (lib/pyve_manifest_write.py); idempotent. Degrades to a silent no-op when
# pyve.toml is absent or tomlkit is unavailable — in which case the backend
# is simply not recorded in the manifest.
_init_manifest_ensure_root_backend() {
    local backend="$1"
    [[ -n "$backend" ]] || return 0
    [[ -f pyve.toml ]] || return 0
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    local rc=0
    "$py" "$_PYVE_MANIFEST_WRITE_HELPER" set-env-attr pyve.toml root backend "$backend" || rc=$?
    # rc 3 = tomlkit unavailable → not fatal (the backend is simply not recorded).
    [[ $rc -eq 3 ]] && return 0
    return $rc
}

# True (0) when the cwd already holds a Pyve project — declared by `pyve.toml`.
# The re-init / `--force` handling keys off this so a forced rebuild fires on an
# already-initialized project.
_init_is_reinit() {
    [[ -f pyve.toml ]] && return 0
    return 1
}

# On a forced rebuild, never silently orphan a materialized env whose
# backend differs from the target backend. The re-init purge only removes
# the env for the manifest's declared backend; a stray foreign-backend env
# (e.g. a `.venv` materialized alongside a micromamba manifest) would
# otherwise survive the rebuild and leave the project straddling two
# backends. Move any such foreign env into the `.pyve/.v2-legacy/` backup
# tree (recoverable, never deleted) and warn. The target backend's OWN env
# is left untouched.
# Arg: $1 = target backend (venv|micromamba). Always returns 0.
_init_backup_foreign_env() {
    local target="$1"
    local stamp; stamp="$(date +%s)"
    if [[ "$target" == "micromamba" ]] && [[ -d .venv ]]; then
        mkdir -p .pyve/.v2-legacy
        mv .venv ".pyve/.v2-legacy/orphaned-venv-$stamp"
        warn "Backed up a stray venv (.venv) to .pyve/.v2-legacy/ — pyve.toml declares the micromamba backend."
    elif [[ "$target" == "venv" ]] && [[ -d .pyve/envs/root/conda ]]; then
        mkdir -p .pyve/.v2-legacy
        mv .pyve/envs/root/conda ".pyve/.v2-legacy/orphaned-conda-$stamp"
        warn "Backed up a stray micromamba env to .pyve/.v2-legacy/ — pyve.toml declares the venv backend."
    fi
    return 0
}

# Detect which Python version managers are available on PATH.
# Returns one of: "" | "asdf" | "pyenv" | "asdf,pyenv".
# Used by the venv branch of the L.k.4 Python prompt.
_init_detect_version_managers_available() {
    local available=()
    command -v asdf  >/dev/null 2>&1 && available+=("asdf")
    command -v pyenv >/dev/null 2>&1 && available+=("pyenv")
    # bash 3.2 (macOS system bash) raises "unbound variable" on
    # "${array[*]}" when the array is empty — even without `set -u`.
    # The `:-` default keeps the empty case a clean empty string.
    local IFS=,
    printf '%s' "${available[*]:-}"
}

# List manager-reported installed Python versions, filtered to ^3\..
# Output: one version per line, no leading whitespace, no '*' marker.
# Args: $1 = "asdf" | "pyenv"
_init_list_installed_python_versions() {
    local manager="$1"
    case "$manager" in
        asdf)
            asdf list python 2>/dev/null \
                | sed -e 's/^[[:space:]]*\*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                | grep -E '^3\.' || true
            ;;
        pyenv)
            pyenv versions --bare 2>/dev/null | grep -E '^3\.' || true
            ;;
    esac
}

# Detect whether project-guide is already installed in this project.
# Returns 0 if `.project-guide.yml` exists in cwd, else 1. This matches
# the canonical install marker used by `pyve update` —
# `.project-guide.yml` records `installed_version`, `target_dir`,
# `current_mode`, etc.; the `docs/project-guide/` directory alone is
# not authoritative because `target_dir` is configurable.
_init_detect_project_guide_present() {
    [[ -f .project-guide.yml ]]
}

# emit the v3.0 canonical `pyve.toml` manifest at cwd.
#
# Idempotent: if `pyve.toml` already exists, this is a silent no-op
# (the existing manifest is the source of truth — the refresh path
# leaves it alone per N.e Task 3).
#
# Schema shipped:
#   pyve_schema = "3.0"
#   [project] name = <project_name>
#   [env.root]    purpose = "utility"
#   [env.testenv] purpose = "test", default = true
#
# The `[env.testenv]` declaration is the project's default test env.
# `pyve init` materializes the run env (`.venv/`) and, gated on an actual
# declaration, the default test env when it is venv-backed (empty until
# demand — dependencies install on first `pyve test` / `pyve env install`);
# conda-backed or additional named envs materialize via `pyve env init
# <name>`. A root-only manifest (no test env declared) materializes no test
# env. Declaring testenv here also lets purpose-keyed selectors
# (`pyve test --env testenv`) resolve.
_init_write_pyve_toml() {
    local project_name="$1"
    # The resolved root backend (venv / micromamba). `pyve init` always
    # passes it; the no-arg form defaults to venv so the emitted manifest
    # is ALWAYS fully explicit (Story P.j — explicit-by-construction):
    # every [env.<name>] block records purpose + backend + default, never
    # leaning on TOML "absent = default" inference. The test env is venv by
    # default (the fresh scaffold's materialized default test env), recorded
    # explicitly even when the root env is micromamba.
    local backend="${2:-venv}"
    if [[ -f pyve.toml ]]; then
        return 0
    fi
    cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "${project_name}"
pyve_defaults_version = "${PYVE_PARAM_DEFAULTS_VERSION:-1}"

[env.root]
purpose = "utility"
backend = "${backend}"
default = false

[env.testenv]
purpose = "test"
backend = "venv"
default = true
EOF
}

# Which test env, if any, `pyve init` materializes: the declared default test
# env — but only when it resolves to a venv backend. No test env declared (a
# root-only manifest) → nothing, so init never injects an undeclared `testenv`.
# A conda-backed default needs a manifest + solve and is deferred to
# `pyve env init <name>`; an advisory/`none` mirror is declarative-only. Prints
# the env name to materialize, or nothing.
_init_testenv_to_materialize() {
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi
    local name="${PYVE_TESTENVS_DEFAULT:-}"
    [[ -z "$name" ]] && return 0
    # A lazy env provisions on first use — init must leave it
    # unrealized (including a forced re-init).
    if is_env_lazy "$name"; then
        return 0
    fi
    local be
    be="$(_env_resolve_backend "$name")" || be="venv"
    [[ "$be" == "venv" ]] && printf '%s' "$name"
    return 0
}

# refresh-path guard. When `pyve.toml` exists, validate
# it before letting `init_project` proceed. Validation is delegated
# to `manifest_load` (which calls the Python helper and exits 2 with
# stderr diagnostics on malformed schema / unknown purpose / etc.).
#
# Silent success when `pyve.toml` is absent — callers don't need to
# pre-check, the caller path falls through to `_init_write_pyve_toml`
# at the end of init.
#
# On validation failure, surface the Python helper's stderr (already
# captured to the process's stderr by manifest_load's invocation
# shape) and exit non-zero. We don't try to translate the message
# here — the helper's own "error: pyve.<key>: <message>" form is the
# documented contract.
_init_validate_existing_manifest() {
    if [[ ! -f pyve.toml ]]; then
        return 0
    fi
    if manifest_load pyve.toml; then
        return 0
    fi
    # manifest_load failed. Distinguish "the validator couldn't run" from
    # "the manifest is genuinely invalid" — they demand opposite handling.
    # manifest_load parses pyve.toml by shelling out to Pyve's manifest
    # interpreter; if that interpreter can't run (an asdf shim with no
    # pinned version → "No version is set for command python", a missing
    # `python`, or a Python < 3.11 without tomllib), the failure says
    # nothing about the manifest's contents. Probe the SAME interpreter
    # manifest_load resolves; if it can't import tomllib, the manifest may
    # be perfectly valid.
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    if ! "$py" -c 'import tomllib' >/dev/null 2>&1; then
        # Cannot validate — but "cannot validate" is NOT "invalid". This
        # pre-flight gate only exists to abort early on a KNOWN-bad manifest;
        # aborting here would break the purge->init round-trip, since the
        # very next step (the wizard) is what re-establishes Python. So
        # DEFER: warn, return success, and let init proceed. The manifest is
        # consumed downstream once Python is resolvable; a genuinely-bad one
        # still fails there, just without a misleading pre-flight abort.
        warn "pyve.toml: deferring validation — no usable Python interpreter yet (environment setup will establish it). Not deleting or modifying the manifest."
        return 0
    fi
    log_error "pyve.toml: invalid manifest (see error(s) above)"
    log_error "Fix the manifest and re-run, or remove pyve.toml to re-scaffold."
    return 1
}

# polyglot `pyve.toml` writer.
#
# Emits the canonical manifest with explicit `[plugins.python]` (root) and
# `[plugins.node]` (sub-path) blocks. Per spike S3 there is no `role` field;
# per S4 Python alone owns the root, so `[plugins.python]` carries NO `path`
# line (the helper defaults it to "."), and Node lives at the distinct
# `<node_path>`. The two Python env blocks ([env.root] / [env.testenv])
# match the plain `_init_write_pyve_toml` shape so purpose-keyed selectors
# resolve identically on polyglot projects.
#
# Idempotent: silent no-op when `pyve.toml` already exists (refresh path),
# mirroring `_init_write_pyve_toml`.
_init_write_pyve_toml_polyglot() {
    local project_name="$1"
    local node_path="$2"
    # Explicit-by-construction (Story P.j), mirroring `_init_write_pyve_toml`:
    # every [env.<name>] block records purpose + backend + default. No-arg
    # backend defaults to venv so the block is never backend-less.
    local backend="${3:-venv}"
    if [[ -f pyve.toml ]]; then
        return 0
    fi
    cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "${project_name}"
pyve_defaults_version = "${PYVE_PARAM_DEFAULTS_VERSION:-1}"

[env.root]
purpose = "utility"
backend = "${backend}"
default = false

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[plugins.python]

[plugins.node]
path = "${node_path}"
EOF
}

# interactivity gate for the Node sub-path prompt. Mirrors the
# wizard's gate: prompt only when stdin is a TTY and the non-interactive
# bypass is not set. `--node-path` (the scripted override) sidesteps this
# entirely by short-circuiting the resolver before the gate is consulted.
_init_node_path_interactive() {
    [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]
}

# resolve the Node sub-path for a polyglot scaffold.
#
# Usage: _init_resolve_node_path <flag> <interactive>
#   <flag>:        the --node-path value ("" if unset). Non-empty wins
#                  unconditionally (the scripted-override contract).
#   <interactive>: "true" if prompting is allowed, else "false".
#
# Output contract: the resolved path is the ONLY thing written to stdout,
# so callers can capture it via command substitution. Branch rationale and
# prompts go to stderr (still visible on the terminal, but out of the
# captured value).
#
# Convention walk (in this precedence order): src/frontend, frontend, web,
# client, ui — each tested for existence as a directory.
#   0 matches → prompt (default src/frontend); non-interactive → default.
#   1 match   → use it; print an informational "only convention matched" note.
#   2+ matches→ prompt with the list + custom option (default first match);
#               non-interactive → first match.
_init_resolve_node_path() {
    local flag="$1"
    local interactive="$2"
    local default_path="src/frontend"
    local conventions=(src/frontend frontend web client ui)

    # Scripted override wins unconditionally.
    if [[ -n "$flag" ]]; then
        printf '%s' "$flag"
        return 0
    fi

    local matches=() c
    for c in "${conventions[@]}"; do
        [[ -d "$c" ]] && matches+=("$c")
    done
    local n=${#matches[@]}

    if (( n == 0 )); then
        if [[ "$interactive" == "true" ]]; then
            local reply
            printf '  %sNode detected; where should it live? [%s]%s ' \
                "${Y}" "$default_path" "${RESET}" >&2
            read -r reply
            [[ -z "$reply" ]] && reply="$default_path"
            printf '%s' "$reply"
        else
            printf '%s' "$default_path"
        fi
        return 0
    fi

    if (( n == 1 )); then
        info "Node sub-path: ${matches[0]} (using existing directory; only convention matched)" >&2
        printf '%s' "${matches[0]}"
        return 0
    fi

    # 2+ matches.
    local joined
    joined="$(IFS=', '; printf '%s' "${matches[*]}")"
    if [[ "$interactive" == "true" ]]; then
        local reply
        printf '  %sMultiple Node sub-path conventions found: %s. Choose one or type a different path: [%s]%s ' \
            "${Y}" "$joined" "${matches[0]}" "${RESET}" >&2
        read -r reply
        [[ -z "$reply" ]] && reply="${matches[0]}"
        printf '%s' "$reply"
    else
        printf '%s' "${matches[0]}"
    fi
}

# manifest scaffold orchestrator (replaces N.t's advisory-only
# `_init_maybe_advise_node_plugin`). Consults the Node plugin's detection
# hook alongside Python's:
#
#   - `pyve.toml` already present → silent no-op (refresh path).
#   - Node detected at root → resolve the Node sub-path (flag / convention
#     walk / prompt), print the chosen path, and write a polyglot manifest
#     with `[plugins.python]` (root) + `[plugins.node]` (sub-path). Closes
#     the S4+S5 root-collision hole N.t deferred.
#   - Pure-Python project → plain `_init_write_pyve_toml`, unchanged.
#
# `node_path_flag` carries the `--node-path` value ("" if unset).
_init_scaffold_manifest() {
    local project_name="$1"
    local node_path_flag="$2"
    # The resolved root backend, recorded into [env.root] so pyve.toml is the
    # canonical source of the backend. On an existing
    # manifest (refresh / --force), backfill the backend in place rather than
    # no-op'ing, so a re-init never leaves the manifest backend-less.
    local backend="${3:-}"

    if [[ -f pyve.toml ]]; then
        _init_manifest_ensure_root_backend "$backend"
        return 0
    fi

    local node_signal
    node_signal="$(plugin_dispatch node detect 2>/dev/null || true)"

    if [[ "$node_signal" != "node" ]]; then
        _init_write_pyve_toml "$project_name" "$backend"
        success "Created pyve.toml"
        return 0
    fi

    banner "Polyglot project detected (Python + Node)"

    local interactive="false"
    _init_node_path_interactive && interactive="true"

    local node_path
    node_path="$(_init_resolve_node_path "$node_path_flag" "$interactive")"

    # Always announce the chosen path before writing (whether inferred,
    # prompted, or flag-supplied) so the user knows what landed.
    info "Node sub-path: ${node_path}"
    info "Manifest: Python at \".\", Node at \"${node_path}\"."

    _init_write_pyve_toml_polyglot "$project_name" "$node_path" "$backend"
    success "Created pyve.toml (polyglot: python + node)"

    # surface a SvelteKit framework hint when detected.
    local node_framework
    node_framework="$(node_detect_framework 2>/dev/null || true)"
    if [[ "$node_framework" == "sveltekit" ]]; then
        info "SvelteKit detected — consider adding frameworks = [\"sveltekit\"] to the Node env block."
    fi
}

# List manager-reported AVAILABLE Python versions (full catalog), filtered to ^3\..
# Output: one version per line.
# Args: $1 = "asdf" | "pyenv"
_init_list_available_python_versions() {
    local manager="$1"
    case "$manager" in
        asdf)
            asdf list all python 2>/dev/null | grep -E '^3\.' || true
            ;;
        pyenv)
            pyenv install --list 2>/dev/null \
                | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                | grep -E '^3\.' || true
            ;;
    esac
}

# Build the `pyve init` parameter decision-graph: the 5 framework-level
# parameters whose wizard prompt / flag / valid-flag-list / --help / default
# all derive from one node definition (the keystone, lib/param_graph.sh). The
# operational toggles (--force, --strict, --bootstrap-to, …) are NOT graph
# parameters — they stay hand-parsed. Each row carries its full CLI flag-set (a
# boolean parameter lists both spellings; a negation-only one lists just its
# `--no-` form) and a `--help` blurb. Defaults are recorded for the wizard /
# manifest writer; the valid-flag-list generator below consumes only the flags.
_init_build_param_graph() {
    pg_reset
    pg_add_node "backend|python|*|venv,micromamba,auto|@_init_detect_backend_default|--backend|-|no|Backend|Backend to use: venv, micromamba, auto"
    pg_add_node "python-version|python|*|-|${DEFAULT_PYTHON_VERSION}|--python-version|-|no|Python version|Set Python version (e.g., 3.13.7)"
    pg_add_node "project-guide|python|*|yes,no|-|--project-guide,--no-project-guide|-|no|Install project-guide|Install/refresh project-guide (post-init hook)"
    pg_add_node "direnv|python|*|yes,no|yes|--no-direnv|-|no|direnv activation|Skip .envrc creation (for CI/CD)"
    pg_add_node "env-name|python|*|-|-|--env-name|-|no|Environment name|Environment name (micromamba backend)"
}

# ── decision-graph contribution (P.h plugin-contract `register_params` hook) ──
# The Python plugin's subtree of the keystone decision-graph, registered onto the
# framework graph by plugin_build_param_graph (lib/plugins/registry.sh) when the
# python plugin is active. Order is prompt order: backend → version-manager →
# python-version → test-env. Every node gates on `@_python_param_active` so the
# whole subtree is pruned for a non-Python language and kept for a polyglot
# `multiple` selection. Framework rows (language / project-guide / direnv) carry
# no Python vocabulary — that knowledge lives only here.
python_pyve_plugin_register_params() {
    pg_add_node "backend|python|@_python_param_active|venv,micromamba|@_init_detect_backend_default|--backend|PYVE_BACKEND|no|Backend|Backend to use: venv or micromamba"
    pg_add_node "version-manager|python|@_python_param_needs_vmgr|asdf,pyenv|asdf|--version-manager|PYVE_VMGR|no|Python version manager|Version manager for the Python pin"
    pg_add_node "python-version|python|@_python_param_active|-|${DEFAULT_PYTHON_VERSION:-}|--python-version|PYVE_PYTHON_VERSION|no|Python version|Set Python version (e.g., 3.13.7)"
    pg_add_node "test-env|python|@_python_param_active|yes,no|yes|--test-env,--no-test-env|PYVE_TEST_ENV|no|Default test environment|Create a default test environment"
}

# Applicability predicate: the Python subtree applies when the selected language
# is Python or a polyglot `multiple`. Consulted by the graph walk via the `@fn`
# applicability form (lib/param_graph.sh § Resolvers).
_python_param_active() {
    case "$(pg_answer_get language)" in
        python|multiple) return 0 ;;
        *)               return 1 ;;
    esac
}

# Applicability predicate: the version-manager node applies only for a venv
# backend (micromamba pins Python itself, so no separate manager is needed) and
# only while the Python subtree itself applies.
_python_param_needs_vmgr() {
    _python_param_active && [[ "$(pg_answer_get backend)" == "venv" ]]
}

# Resolve a parameter's default from the decision-graph — the single source of
# parameter defaults. Builds the graph, finds the node by name, and echoes its
# resolved default (`pg_resolve_default` honors computed `@fn` defaults).
# Returns non-zero (no output) for an unknown node. init_project consumes this
# so default values are read from the graph, not re-referenced from constants in
# a second place (the live consumer the P.j manifest writer / P.k drift detector
# build on).
_init_param_default() {
    local want="$1" row
    _init_build_param_graph
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        if [[ "${row%%|*}" == "$want" ]]; then
            pg_resolve_default "$row"
            return 0
        fi
    done <<<"$(pg_list_nodes)"
    return 1
}

# Which graph nodes the interactive wizard prompts for. Interactivity is a
# wizard-only concern (direnv / env-name ARE applicable to flag resolution —
# they are simply flag-only, never prompted), so it lives here in the wizard
# layer rather than in the shared node-row schema. The wizard walks the graph
# in node order and dispatches each interactive node to its
# `_init_prompt_<name>` renderer. To add a prompt later (e.g. direnv): add the
# node name here and define `_init_prompt_direnv`.
_init_node_is_interactive() {
    case "$1" in
        backend|python-version|project-guide) return 0 ;;
        *) return 1 ;;
    esac
}

# Print the full set of flags `pyve init` accepts, one per line: the graph
# parameters' CLI flags (single-sourced from _init_build_param_graph) followed
# by the retained operational toggles and --help. This is the single source for
# the unknown_flag_error allow-list — adding a graph parameter no longer means
# editing a separate hand-maintained list.
_init_valid_flags() {
    _init_build_param_graph
    local row
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        pg_node_flags "$row"
    done <<<"$(pg_list_nodes)"
    # Operational toggles (imperative; not decision-graph parameters) + --help.
    printf '%s\n' \
        --auto-bootstrap --bootstrap-to --strict --no-lock --node-path \
        --auto-install-deps --no-install-deps --local-env --force --all --allow-synced-dir \
        --project-guide-completion --no-project-guide-completion \
        --yes -y \
        --help
}

# Interactive `pyve init` wizard (Story L.k.2 skeleton + L.k.3 backend prompt).
#
# Always invoked from init_project(); flags only control whether each
# individual prompt reads stdin or renders the flag-resolved value
# non-interactively. Per-prompt logic for python pin / project-guide
# lands in L.k.4 / L.k.5.
#
# TTY guard: when at least one of the three prompt-bearing parameters
# is not flag-supplied AND stdin is not a TTY, hard-fail with a message
# naming the missing flags. PYVE_INIT_NONINTERACTIVE=1 bypasses the
# guard (used by the bats test harness so existing init-driving tests
# stay green without supplying every prompt-bearing flag).
#
# Side effect: when `--backend` is unsupplied, this function resolves
# the backend (interactive prompt or auto-default) and writes the
# resolved value into the caller's `backend_flag` variable via bash's
# dynamic scoping. The resolved value is therefore visible to
# init_project() after the wizard returns, exactly as if the user had
# passed `--backend <value>` on the command line.
#
# Usage: _init_wizard <backend_flag> <python_value> <python_supplied> <project_guide_mode>
#   arg_backend_flag:          "" if --backend not supplied, else the value
#   arg_python_value:          the resolved python version (the user's flag value
#                              when --python-version was supplied; the
#                              DEFAULT_PYTHON_VERSION fallback otherwise)
#   arg_python_supplied:       "true" if --python-version supplied, else "false"
#   arg_pg_mode:               "" if neither flag supplied, else "yes" or "no"
_init_wizard() {
    local arg_backend_flag="$1"
    local arg_python_value="$2"
    local arg_python_supplied="$3"
    local arg_pg_mode="$4"

    local missing_flags=()
    [[ -z "$arg_backend_flag" ]] && missing_flags+=("--backend <type>")
    [[ "$arg_python_supplied" != "true" ]] && missing_flags+=("--python-version <ver>")
    [[ -z "$arg_pg_mode" ]] && missing_flags+=("--project-guide / --no-project-guide")

    if [[ ${#missing_flags[@]} -gt 0 ]] \
       && [[ ! -t 0 ]] \
       && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
        log_error "pyve init: stdin is not a TTY and the wizard requires interactive input."
        log_error "To run non-interactively, supply the missing flag(s):"
        local f
        for f in "${missing_flags[@]}"; do
            log_error "  $f"
        done
        log_error "Or set PYVE_INIT_NONINTERACTIVE=1 to bypass."
        exit 1
    fi

    header_box "pyve init"

    # Drive the prompts from the parameter decision-graph: build the graph, then
    # walk it in node order and dispatch each interactive, applicable node to its
    # `_init_prompt_<name>` render callback (the bespoke renderers do the
    # ui_select interaction + side effects via dynamic scope). Prompt order is
    # now graph data (the order nodes are registered), not source position.
    # The here-string keeps the loop body in this shell so the renderers'
    # dynamic-scope writes (backend_flag / python_version / …) propagate.
    _init_build_param_graph
    local _wiz_row _wiz_name _wiz_fn
    while IFS= read -r _wiz_row; do
        [[ -n "$_wiz_row" ]] || continue
        _wiz_name="${_wiz_row%%|*}"
        _init_node_is_interactive "$_wiz_name" || continue
        pg_applicable "$_wiz_row" || continue
        _wiz_fn="_init_prompt_${_wiz_name//-/_}"
        "$_wiz_fn"
    done <<<"$(pg_list_nodes)"

    return 0
}

# Wizard prompt — backend selection. Dispatched by _init_wizard's graph walk
# (the `backend` node). Reads the wizard's arg_backend_flag and writes the
# resolved backend into the caller's backend_flag via dynamic scope.
#
# backend (Story L.k.3 + L.k.7 auto handling).
# `--backend auto` is the explicit "let pyve detect" form; treat it
# like the no-flag auto-detect path so the wizard resolves to a real
# backend before downstream prompts (Python/project-guide) branch on
# backend_flag. Without this, backend_flag stays "auto" through the
# Python prompt, which would then fall to the venv branch and
# hard-fail on no managers — even when env.yml says micromamba.
# When no --backend flag is given, an existing pyve.toml's declared
# root backend is authoritative (a refresh / forced rebuild must not
# re-derive the backend and silently convert the project). It outranks
# the filesystem heuristic and suppresses the interactive prompt, but
# an explicit --backend still wins.
_init_prompt_backend() {
    local manifest_backend=""
    if [[ -z "$arg_backend_flag" ]]; then
        manifest_backend="$(_init_manifest_root_backend)"
    fi

    if [[ -n "$arg_backend_flag" ]] && [[ "$arg_backend_flag" != "auto" ]]; then
        info "Backend: $arg_backend_flag (--backend)"
        backend_flag="$arg_backend_flag"
    elif [[ -n "$manifest_backend" ]]; then
        info "Backend: $manifest_backend (from pyve.toml)"
        backend_flag="$manifest_backend"
    elif [[ "$arg_backend_flag" == "auto" ]]; then
        local default_backend
        default_backend="$(_init_detect_backend_default)"
        info "Backend: $default_backend (--backend auto, detected)"
        backend_flag="$default_backend"
    elif [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
        local default_backend default_idx
        default_backend="$(_init_detect_backend_default)"
        if [[ "$default_backend" == "micromamba" ]]; then
            default_idx=2
        else
            default_idx=1
        fi
        local choice_idx
        if ! choice_idx="$(ui_select --default "$default_idx" "Select backend" "venv" "micromamba")"; then
            log_error "Backend selection cancelled."
            exit 1
        fi
        case "$choice_idx" in
            0) backend_flag="venv" ;;
            1) backend_flag="micromamba" ;;
            *) log_error "Unexpected backend choice index: $choice_idx"; exit 1 ;;
        esac
    else
        local default_backend
        default_backend="$(_init_detect_backend_default)"
        info "Backend: $default_backend (auto-detected)"
        backend_flag="$default_backend"
    fi
}

# Wizard prompt — Python version pin. Dispatched by _init_wizard's graph walk
# (the `python-version` node, after `backend`). Reads backend_flag (resolved by
# the earlier backend node), arg_python_supplied / arg_python_value; writes
# python_version and VERSION_MANAGER via dynamic scope.
#
# Backend-aware (Story L.k.4): venv pins
# via asdf/pyenv writing .tool-versions / .python-version; micromamba
# pins via the `python=X` line in environment.yml (the existing
# scaffolder writes it later in the init flow).
_init_prompt_python_version() {
    if [[ "$backend_flag" == "micromamba" ]]; then
        if [[ -f environment.yml ]]; then
            info "Python: managed via environment.yml"
        elif [[ "$arg_python_supplied" == "true" ]]; then
            info "Python: $arg_python_value (--python-version, will be written to environment.yml)"
        else
            info "Python: $arg_python_value (default, will be written to environment.yml)"
        fi
    else
        # venv branch.
        local available_managers
        available_managers="$(_init_detect_version_managers_available)"

        if [[ "$arg_python_supplied" == "true" ]]; then
            # Flag-driven: detect managers (hard-fail if none); pick asdf when
            # both available; render and write the pin via the existing
            # set_local_python_version helper.
            if [[ -z "$available_managers" ]]; then
                log_error "No supported Python version manager found on PATH."
                log_error "Install one of:"
                log_error "  asdf  — https://asdf-vm.com/"
                log_error "  pyenv — https://github.com/pyenv/pyenv"
                exit 1
            fi
            local picked_manager
            if [[ "$available_managers" == *"asdf"* ]]; then
                picked_manager="asdf"
            else
                picked_manager="pyenv"
            fi
            info "Python: $arg_python_value (--python-version, pinned via $picked_manager)"
            VERSION_MANAGER="$picked_manager"
            if ! set_local_python_version "$arg_python_value" >/dev/null 2>&1; then
                log_error "Failed to pin Python $arg_python_value via $picked_manager."
                exit 1
            fi
            python_version="$arg_python_value"
        elif [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
            # Interactive: full picker flow. Hard-fail when neither manager is
            # installed (the user is being asked to choose; the prompt has no
            # legitimate answer otherwise).
            if [[ -z "$available_managers" ]]; then
                log_error "No supported Python version manager found on PATH."
                log_error "Install one of:"
                log_error "  asdf  — https://asdf-vm.com/"
                log_error "  pyenv — https://github.com/pyenv/pyenv"
                exit 1
            fi
            local picked_manager
            if [[ "$available_managers" == "asdf,pyenv" ]]; then
                local mgr_idx
                if ! mgr_idx="$(ui_select --default 1 "Select Python version manager" "asdf" "pyenv")"; then
                    log_error "Version-manager selection cancelled."
                    exit 1
                fi
                case "$mgr_idx" in
                    0) picked_manager="asdf" ;;
                    1) picked_manager="pyenv" ;;
                    *) log_error "Unexpected manager choice index: $mgr_idx"; exit 1 ;;
                esac
            else
                picked_manager="$available_managers"
            fi
            # Build "Pick from installed" list with `more...` and `skip` as the
            # final two options. Selecting `more...` re-prompts with the full
            # available list.
            local installed_versions
            installed_versions="$(_init_list_installed_python_versions "$picked_manager")"
            local options=()
            local v
            while IFS= read -r v; do
                [[ -n "$v" ]] && options+=("$v")
            done <<<"$installed_versions"
            options+=("more...")
            options+=("skip (no pin)")
            local pick_idx
            if ! pick_idx="$(ui_select --default 1 "Select Python version (via $picked_manager)" "${options[@]}")"; then
                log_error "Python version selection cancelled."
                exit 1
            fi
            local n_installed=$(( ${#options[@]} - 2 ))
            local chosen_version=""
            if (( pick_idx < n_installed )); then
                chosen_version="${options[$pick_idx]}"
            elif (( pick_idx == n_installed )); then
                # `more...` — re-prompt with full available list.
                local available_full
                available_full="$(_init_list_available_python_versions "$picked_manager")"
                local more_options=()
                while IFS= read -r v; do
                    [[ -n "$v" ]] && more_options+=("$v")
                done <<<"$available_full"
                if [[ ${#more_options[@]} -eq 0 ]]; then
                    log_error "No 3.x versions available from $picked_manager."
                    exit 1
                fi
                local more_idx
                if ! more_idx="$(ui_select --default 1 "Select Python version (full list)" "${more_options[@]}")"; then
                    log_error "Python version selection cancelled."
                    exit 1
                fi
                chosen_version="${more_options[$more_idx]}"
            else
                # `skip` — no pin written.
                info "Python: skipped (no pin)"
                chosen_version=""
            fi
            if [[ -n "$chosen_version" ]]; then
                info "Python: $chosen_version (pinned via $picked_manager)"
                VERSION_MANAGER="$picked_manager"
                if ! set_local_python_version "$chosen_version" >/dev/null 2>&1; then
                    log_error "Failed to pin Python $chosen_version via $picked_manager."
                    exit 1
                fi
                python_version="$chosen_version"
            fi
        else
            # Non-TTY or bypass on, no flag → silent skip. No hard-fail on
            # missing managers because no pin was requested.
            info "Python: skipped (no pin)"
        fi
    fi
}

# Wizard prompt — project-guide install. Dispatched by _init_wizard's graph walk
# (the `project-guide` node). Reads arg_pg_mode; writes project_guide_mode via
# dynamic scope.
#
# Detection (Story L.k.5) is keyed on
# `.project-guide.yml` (the canonical install marker, matching what
# `pyve update` already uses). Deps-managed signal (project-guide
# declared in pyproject.toml / requirements.txt / environment.yml)
# wins over the install-marker check — when the user manages
# project-guide via project deps, pyve refuses to touch it to avoid
# version-pin conflicts at the next `pip install -e .`.
_init_prompt_project_guide() {
    if [[ "$arg_pg_mode" == "yes" ]]; then
        info "project-guide: install (--project-guide)"
    elif [[ "$arg_pg_mode" == "no" ]]; then
        info "project-guide: skipped (--no-project-guide)"
    elif project_guide_in_project_deps; then
        # Render the wizard summary; defer to the hook's detailed
        # auto-skip-from-deps message ("Detected 'project-guide'...")
        # by leaving project_guide_mode empty. Pre-setting "no" here
        # would short-circuit that message and emit a misleading
        # "Skipping project-guide install (--no-project-guide)" instead.
        info "project-guide: managed by your project dependencies"
    elif _init_detect_project_guide_present; then
        info "project-guide: refresh (already installed)"
        project_guide_mode="yes"
    elif [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
        local pg_idx
        if ! pg_idx="$(ui_select --default 2 "Install project-guide?" "yes" "no")"; then
            log_error "project-guide selection cancelled."
            exit 1
        fi
        case "$pg_idx" in
            0) info "project-guide: install"; project_guide_mode="yes" ;;
            1) info "project-guide: skipped"; project_guide_mode="no" ;;
            *) log_error "Unexpected project-guide choice index: $pg_idx"; exit 1 ;;
        esac
    else
        # Non-TTY / bypass + no flag + no signal: defer to the hook's
        # existing env-var / CI-default / interactive-fallback logic
        # (PYVE_NO_PROJECT_GUIDE, PYVE_PROJECT_GUIDE, CI=1, PYVE_FORCE_YES).
        # Pre-setting "no" here would break the CI-default-install behavior
        # documented in `_init_run_project_guide_hooks` priority 5.
        info "project-guide: (env / CI default)"
    fi

    return 0
}

# Resolve the version manager to use during materialization. Honors an
# explicit pick already recorded in VERSION_MANAGER (the wizard sets it from
# the user's selection, after verifying the manager is available); only when
# none is recorded does it fall back to detect_version_manager. This keeps a
# transient detection false-negative (e.g. the SIGPIPE/pipefail bug in
# Story N.bf.6) from silently overriding what the user asked for. Returns
# non-zero only when nothing can be resolved at all.
_init_resolve_version_manager() {
    if [[ -n "${VERSION_MANAGER:-}" ]]; then
        return 0
    fi
    detect_version_manager
}

# Emit the gentle lock nudge at the end of a successful non-strict micromamba
# init (Story N.bf.9). Fires only when `conda-lock` is a declared dependency
# but no lock file exists yet — the signal that the user opted into locking but
# hasn't generated the lock. No-op when `--no-lock` is set, a lock already
# exists, or `conda-lock` is not declared (pre-production). The `--strict`
# declared-missing case never reaches here — validate_lock_file_status barks
# pre-flight.
_init_lock_nudge() {
    [[ "${PYVE_NO_LOCK:-}" == "1" ]] && return 0
    [[ -f "conda-lock.yml" ]] && return 0
    is_conda_lock_declared || return 0
    info "conda-lock is in your environment.yml, so Pyve expects a conda-lock.yml."
    info "When your dependencies are finalized, run \`pyve lock\` to resolve them into the lock file."
}

# Select the environment file micromamba builds from. The default prefers a
# present conda-lock.yml (reproducible) via detect_environment_file. `--no-lock`
# (PYVE_NO_LOCK=1) overrides that for this run (Story N.bf.10): resolve from
# environment.yml even when a lock exists — the lock is ignored as the install
# source, NOT deleted. Falls back to detect_environment_file when there's no
# environment.yml to resolve from.
_init_select_env_file() {
    if [[ "${PYVE_NO_LOCK:-}" == "1" ]] && [[ -f "environment.yml" ]]; then
        echo "environment.yml"
        return 0
    fi
    detect_environment_file
}

# Decide whether a freshly scaffolded environment.yml should declare conda-lock
# (Story N.bf.11). Return-code based (0 = include, 1 = omit) so it composes in an
# `if`. Short-circuits to omit when no scaffold will actually happen (strict, or
# environment.yml / conda-lock.yml already present) so we never prompt
# pointlessly. `--no-lock` → omit. Interactive TTY → prompt with a Y default
# ("[Y/n]"). Non-interactive → include (the settled "locking desired" default).
_init_resolve_scaffold_conda_lock() {
    local strict_mode="$1"

    [[ "${PYVE_NO_LOCK:-}" == "1" ]] && return 1
    # No scaffold will occur → the value is irrelevant; don't prompt.
    [[ "$strict_mode" == "true" ]] && return 1
    [[ -f "environment.yml" ]] && return 1
    [[ -f "conda-lock.yml" ]] && return 1

    if [[ -t 0 ]] && [[ "${PYVE_INIT_NONINTERACTIVE:-0}" != "1" ]]; then
        # Default-yes prompt (the project's other prompts are default-no; this
        # one recommends locking, so Enter accepts). Prompt to stderr; read the
        # already-confirmed TTY on stdin.
        local answer
        read -r -p "  Version-control dependencies with a lock file? [Y/n] " answer
        answer="${answer:-y}"
        [[ "$answer" =~ ^[Yy] ]]
        return $?
    fi

    # Non-interactive default: include.
    return 0
}

init_project() {
    local venv_dir="$DEFAULT_VENV_DIR"
    # Python-version default is read from the decision-graph (the single source
    # of parameter defaults), not the DEFAULT_PYTHON_VERSION constant directly —
    # the graph's `python-version` node interpolates the same constant, so this
    # is functionally identical while making the graph the consumed default path.
    local python_version
    python_version="$(_init_param_default python-version)"
    local python_version_supplied=false
    local use_local_env=false
    local backend_flag=""
    local auto_bootstrap=false
    local bootstrap_to="user"
    local strict_mode=false
    local env_name_flag=""
    local no_direnv=false
    local lock_preflight_done=false
    local preflight_backend=""
    # explicit Node sub-path for polyglot scaffolds. Empty
    # means "infer / prompt"; a value overrides all detection.
    local node_path_flag=""

    # project-guide integration (Story G.c / FR-G2) — tri-state:
    # "" (unset — use env vars / prompt / CI default), "yes" (force install),
    # "no" (force skip). Set by --project-guide / --no-project-guide flags.
    local project_guide_mode=""
    local project_guide_completion_mode=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --python-version)
                if [[ -z "${2:-}" ]]; then
                    log_error "--python-version requires a version argument"
                    exit 1
                fi
                python_version="$2"
                python_version_supplied=true
                shift 2
                ;;
            --backend)
                if [[ -z "${2:-}" ]]; then
                    log_error "--backend requires a backend type (venv, micromamba, auto)"
                    exit 1
                fi
                backend_flag="$2"
                shift 2
                ;;
            --local-env)
                use_local_env=true
                shift
                ;;
            --auto-bootstrap)
                auto_bootstrap=true
                shift
                ;;
            --bootstrap-to)
                if [[ -z "${2:-}" ]]; then
                    log_error "--bootstrap-to requires a location (project, user)"
                    exit 1
                fi
                bootstrap_to="$2"
                if [[ "$bootstrap_to" != "project" ]] && [[ "$bootstrap_to" != "user" ]]; then
                    log_error "Invalid --bootstrap-to value: $bootstrap_to"
                    log_error "Must be 'project' or 'user'"
                    exit 1
                fi
                shift 2
                ;;
            --strict)
                strict_mode=true
                shift
                ;;
            --no-lock)
                export PYVE_NO_LOCK=1
                shift
                ;;
            --env-name)
                if [[ -z "${2:-}" ]]; then
                    log_error "--env-name requires an environment name"
                    exit 1
                fi
                env_name_flag="$2"
                shift 2
                ;;
            --no-direnv)
                no_direnv=true
                shift
                ;;
            --node-path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--node-path requires a path argument"
                    exit 1
                fi
                node_path_flag="$2"
                shift 2
                ;;
            --node-path=*)
                node_path_flag="${1#*=}"
                if [[ -z "$node_path_flag" ]]; then
                    log_error "--node-path requires a non-empty path argument"
                    exit 1
                fi
                shift
                ;;
            --auto-install-deps)
                export PYVE_AUTO_INSTALL_DEPS=1
                shift
                ;;
            --no-install-deps)
                export PYVE_NO_INSTALL_DEPS=1
                shift
                ;;
            --allow-synced-dir)
                export PYVE_ALLOW_SYNCED_DIR=1
                shift
                ;;
            --update)
                # Removed in v2.0 (H.e.9). Hard error — semantics of
                # `pyve update` are broader than v1.x's narrow
                # config-bump, so delegation would surprise scripted
                # callers. See phase-H-cli-refactor-design.md §5 D3.
                legacy_flag_error "init --update" "update"
                ;;
            --all)
                # Batch fan-out marker. Validated (requires --force) and
                # executed by compose_init AFTER the root flow; parsed here
                # so the allow-list accepts it and messaging can widen.
                PYVE_INIT_ALL="1"
                shift
                ;;
            --force)
                PYVE_REINIT_MODE="force"
                shift
                ;;
            --yes|-y)
                # Easy mode (Story P.j): fast-accept every wizard default.
                # Reuses the non-interactive resolution path so every
                # prompt-bearing parameter (backend / python / project-guide /
                # node path) resolves to its graph default with no prompts —
                # then init writes the same fully-explicit pyve.toml the
                # interactive path would. Explicit `--backend`, `--python-version`,
                # etc. still win when supplied alongside `--yes`.
                export PYVE_INIT_NONINTERACTIVE=1
                shift
                ;;
            --project-guide)
                if [[ "$project_guide_mode" == "no" ]]; then
                    log_error "--project-guide and --no-project-guide are mutually exclusive"
                    exit 1
                fi
                project_guide_mode="yes"
                shift
                ;;
            --no-project-guide)
                if [[ "$project_guide_mode" == "yes" ]]; then
                    log_error "--project-guide and --no-project-guide are mutually exclusive"
                    exit 1
                fi
                project_guide_mode="no"
                shift
                ;;
            --project-guide-completion)
                if [[ "$project_guide_completion_mode" == "no" ]]; then
                    log_error "--project-guide-completion and --no-project-guide-completion are mutually exclusive"
                    exit 1
                fi
                project_guide_completion_mode="yes"
                shift
                ;;
            --no-project-guide-completion)
                if [[ "$project_guide_completion_mode" == "yes" ]]; then
                    log_error "--project-guide-completion and --no-project-guide-completion are mutually exclusive"
                    exit 1
                fi
                project_guide_completion_mode="no"
                shift
                ;;
            -*)
                # Valid-flag allow-list single-sourced from the parameter
                # decision-graph (graph flags) ⊕ the operational toggles.
                local _vf=() _vf_flag
                while IFS= read -r _vf_flag; do
                    [[ -n "$_vf_flag" ]] && _vf+=("$_vf_flag")
                done <<<"$(_init_valid_flags)"
                unknown_flag_error "init" "$1" "${_vf[@]}"
                ;;
            *)
                log_error "Unexpected argument: $1"
                log_error "pyve init takes no positional arguments (the venv is always '${DEFAULT_VENV_DIR}')."
                log_error "See: pyve init --help"
                exit 1
                ;;
        esac
    done

    # refresh-path guard. If `pyve.toml` exists, validate
    # it before doing any work; surface helper errors and abort on
    # malformed schema / unknown purpose / etc. Absent manifest is a
    # silent no-op (the fresh-init path falls through to the writer
    # at the end). Runs before the wizard so an invalid manifest
    # short-circuits without prompting the user.
    if ! _init_validate_existing_manifest; then
        exit 1
    fi

    # Capture whether the backend came from an explicit --backend before the
    # wizard resolves backend_flag (it may seed it from pyve.toml's [env.root]
    # backend via dynamic scope). The advisory-root skip below keys off this:
    # a manifest-declared advisory backend is skipped, but an explicit
    # --backend stays strict (an unknown value still hard-errors).
    local arg_backend_explicit="$backend_flag"

    _init_wizard "$backend_flag" "$python_version" "$python_version_supplied" "$project_guide_mode"

    # Refuse to initialize inside a cloud-synced directory (use --allow-synced-dir to override)
    check_cloud_sync_path

    # Check for existing installation (re-initialization detection).
    # Keys off the presence of `pyve.toml` via `_init_is_reinit`.
    if _init_is_reinit; then
        # Read the existing backend from the manifest for the force/notice
        # messaging (`manifest_load` runs in `main` before dispatch).
        local existing_backend
        existing_backend="$(manifest_get_backend root 2>/dev/null || true)"

        # Handle re-initialization based on mode.
        # (PYVE_REINIT_MODE="update" path removed in v2.0 / H.e.9 —
        # `pyve update` is the new entry point.)
        if [[ "${PYVE_REINIT_MODE:-}" == "force" ]]; then
            # Force re-initialization mode
            warn "Force re-initialization: this will purge and rebuild the root environment ($existing_backend)"
            if [[ "${PYVE_INIT_ALL:-}" == "1" ]]; then
                warn "--all: after the root rebuild, every declared env is rebuilt from its declaration and its recorded state restored"
            fi

            # Run pre-flight checks BEFORE purging so the environment is still intact
            # if the user decides to abort or a check fails.
            # We capture the backend here and reuse it in the main flow to avoid
            # prompting the user twice in the ambiguous case (env.yml + pyproject.toml).
            preflight_backend="$(get_backend_priority "$backend_flag")"
            if [[ "$preflight_backend" == "micromamba" ]]; then
                # Mirror the non-force flow (see the main micromamba branch below):
                # scaffold a starter environment.yml on a fresh dir BEFORE lock
                # validation, otherwise validate_lock_file_status's "neither file"
                # case fires and aborts the switch on projects that the non-force
                # path handles fine.
                local _scaffold_lock="false"
                _init_resolve_scaffold_conda_lock "$strict_mode" && _scaffold_lock="true"
                if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode" "$_scaffold_lock"; then
                    info "Scaffolded starter environment.yml (python=$python_version)"
                    info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
                fi
                if ! validate_lock_file_status "$strict_mode"; then
                    fail "Pre-flight check failed — no changes made"
                fi
                lock_preflight_done=true
            fi

            # Prompt for confirmation (skip in CI or if PYVE_FORCE_YES is set).
            # Show a summary of what will happen so the user can make an informed choice.
            if [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
                if [[ "$preflight_backend" != "$existing_backend" ]]; then
                    warn "Backend change: $existing_backend → $preflight_backend"
                fi
                info "Purge:   existing $existing_backend root environment"
                info "Rebuild: fresh $preflight_backend root environment"
                info "Named envs under .pyve/envs/ are untouched — rebuild one with: pyve env init <name> --force"
                if ! ask_yn "Proceed"; then
                    info "Cancelled — no changes made, existing environment preserved"
                    exit 0
                fi
            fi

            # Don't preserve backend on --force - let normal detection happen
            # This allows the interactive prompt to appear in ambiguous cases
            # (when both environment.yml and pyproject.toml exist)

            # Purge existing installation
            banner "Purging existing environment"
            purge_project --keep-testenv --yes
            success "Environment purged"
            banner "Rebuilding fresh environment"

        fi
    fi

    # On a forced rebuild, back up any materialized env whose backend
    # differs from the target (manifest-declared) backend before creating
    # the new one. The re-init purge above only removes the env for the
    # manifest's declared backend; this catches a stray foreign-backend env
    # the manifest doesn't account for, so the rebuild never leaves the
    # project straddling two backends. No-op when nothing foreign is present.
    if [[ "${PYVE_REINIT_MODE:-}" == "force" ]] && [[ -n "$backend_flag" ]]; then
        _init_backup_foreign_env "$backend_flag"
    fi

    # An advisory root backend (e.g. `none`) declared in pyve.toml is not
    # something pyve materializes — it marks a runtime-less / non-Python root
    # (Node, Rust, Go, advisory tool envs, a polyglot coordination root). Skip
    # root env creation with the same note the per-env install path emits,
    # rather than crashing in validate_backend, then let the composition tail
    # still wire up .envrc/.gitignore + named concrete-backend envs. Gated on
    # the manifest-derived value: an explicit --backend stays strict below, so
    # a genuinely-unknown `--backend bogus` still hard-errors.
    if [[ -z "$arg_backend_explicit" ]] && _env_backend_is_advisory "$backend_flag"; then
        info "env 'root' declares backend '$backend_flag', which pyve does not yet materialize; skipping root env creation (provision it manually per the env spec)"
        _init_scaffold_manifest "$(basename "$(pwd)")" "$node_path_flag" "$backend_flag"
        PYVE_INIT_TAIL_BACKEND="$backend_flag"
        PYVE_INIT_TAIL_ENV_PATH=""
        PYVE_INIT_TAIL_NO_DIRENV="$no_direnv"
        PYVE_INIT_TAIL_PG_MODE="$project_guide_mode"
        PYVE_INIT_TAIL_COMP_MODE="$project_guide_completion_mode"
        return 0
    fi

    # Validate backend if specified
    if [[ -n "$backend_flag" ]]; then
        if ! validate_backend "$backend_flag"; then
            exit 1
        fi
    fi

    # Determine backend to use
    # If the force pre-flight already resolved the backend (to avoid prompting twice
    # in the ambiguous env.yml + pyproject.toml case), reuse that result.
    local backend
    if [[ -n "$preflight_backend" ]]; then
        backend="$preflight_backend"
    else
        backend="$(get_backend_priority "$backend_flag")"
    fi

    # Check if micromamba backend is selected and handle bootstrap
    if [[ "$backend" == "micromamba" ]]; then
        # H.f.7: if the directory has neither `environment.yml` nor
        # `conda-lock.yml`, and strict-mode is off, scaffold a starter
        # `environment.yml` before the (expensive) bootstrap step.
        # Doing this early means the user-visible error surface in a
        # clean directory is "scaffolded and proceeded" instead of the
        # H.f.6 "missing environment.yml" hard-error path.
        local _scaffold_lock="false"
        _init_resolve_scaffold_conda_lock "$strict_mode" && _scaffold_lock="true"
        if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode" "$_scaffold_lock"; then
            info "Scaffolded starter environment.yml (python=$python_version)"
            info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
        fi

        # Check if micromamba is available
        if ! check_micromamba_available; then
            # Micromamba not found - offer bootstrap
            if [[ "$auto_bootstrap" == true ]]; then
                # Auto-bootstrap mode (non-interactive)
                if ! bootstrap_micromamba_auto "$bootstrap_to"; then
                    exit 1
                fi
            else
                # Interactive bootstrap prompt
                local context=$'Detected: environment.yml\nRequired: micromamba'
                if ! bootstrap_micromamba_interactive "$context"; then
                    exit 1
                fi
            fi
        fi

        # At this point, micromamba should be available
        if ! check_micromamba_available; then
            log_error "Micromamba still not available after bootstrap attempt"
            exit 1
        fi

        # Validate lock file status if micromamba backend
        # (skipped when pre-flight already ran it in --force path)
        if [[ "$lock_preflight_done" != "true" ]]; then
            if ! validate_lock_file_status "$strict_mode"; then
                exit 1
            fi
        fi

        # Resolve and validate environment name
        local env_name
        env_name="$(resolve_environment_name "$env_name_flag")"
        if ! validate_environment_name "$env_name"; then
            exit 1
        fi
        info "Environment name: $env_name"

        # Validate environment file
        if ! validate_environment_file; then
            exit 1
        fi

        # Create micromamba environment
        banner "Initializing micromamba environment"
        info "Backend:         micromamba"
        info "Environment:     $env_name"

        local env_file
        env_file="$(_init_select_env_file)"
        info "Using file:      $env_file"

        if ! create_micromamba_env "$env_name" "$env_file"; then
            exit 1
        fi

        # Verify environment
        if ! verify_micromamba_env "$env_name"; then
            warn "Environment created but verification failed"
        fi

        # .envrc is composed below, AFTER pyve.toml exists (see the venv
        # branch for the rationale).
        local env_path
        env_path="$(micromamba_root_prefix)"

        # Create .env file
        _init_dotenv "$use_local_env"

        # .gitignore is composed below, after pyve.toml exists, via
        # compose_project_gitignore (gathers every active plugin's ignore
        # entries through the managed section).

        # write the v3.0 canonical manifest — the sole declaration `init`
        # creates. No-op if it already exists (refresh path). When Node is
        # detected at root alongside Python, this writes a polyglot manifest
        # with explicit [plugins.python] + [plugins.node] blocks; pure-Python
        # projects get the plain manifest.
        _init_scaffold_manifest "$(basename "$(pwd)")" "$node_path_flag" "micromamba"

        # Generate .vscode/settings.json so IDEs use the correct interpreter
        write_vscode_settings "$env_name"

        info "Environment location: $env_path"

        # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
        prompt_install_pip_dependencies "micromamba" "$env_path"

        # Gentle nudge (Story N.bf.9): if conda-lock is declared but no lock
        # exists yet, point the user at `pyve lock` — no auto-lock, no error.
        _init_lock_nudge

        # hand the stack-agnostic composition tail (compose
        # .envrc/.gitignore → project-guide → next-steps) up to compose_init
        # via the result globals. The .envrc/.gitignore composition is no
        # longer welded here — it runs once at orchestration level.
        PYVE_INIT_TAIL_BACKEND="micromamba"
        PYVE_INIT_TAIL_ENV_PATH="$env_path"
        PYVE_INIT_TAIL_NO_DIRENV="$no_direnv"
        PYVE_INIT_TAIL_PG_MODE="$project_guide_mode"
        PYVE_INIT_TAIL_COMP_MODE="$project_guide_completion_mode"

        return 0
    fi

    # Validate inputs
    if ! validate_venv_dir_name "$venv_dir"; then
        exit 1
    fi

    if ! validate_python_version "$python_version"; then
        exit 1
    fi

    banner "Initializing Python environment"
    info "Backend:        $backend"
    info "Python version: $python_version"
    info "Venv directory: $venv_dir"

    # Source shell profiles to find version managers
    source_shell_profiles

    # Resolve the version manager. Honors the wizard's explicit pick
    # (recorded in VERSION_MANAGER) rather than blindly re-detecting, which
    # used to discard the user's selection — and could flip asdf → pyenv on a
    # transient detection false-negative (Story N.bf.6).
    if ! _init_resolve_version_manager; then
        exit 1
    fi
    info "Using $VERSION_MANAGER for Python version management"

    # Check direnv (only if not using --no-direnv)
    if [[ "$no_direnv" == false ]]; then
        if ! check_direnv_installed; then
            exit 1
        fi
    fi

    # Ensure Python version is installed
    if ! ensure_python_version_installed "$python_version"; then
        exit 1
    fi

    # Set local Python version
    _init_python_version "$python_version"

    # Create virtual environment
    _init_venv "$venv_dir"

    # .envrc is composed below, AFTER pyve.toml exists — the composer's
    # Python activate hook resolves the backend / env path from the manifest,
    # and plugin enumeration reads the freshly-written manifest.

    # Create .env file
    _init_dotenv "$use_local_env"

    # .gitignore is composed below, after pyve.toml exists, and enumerates
    # plugins from it (the composer resolves the venv dir via
    # resolve_venv_directory to ignore a custom dir).

    # write the v3.0 canonical manifest — the sole declaration `init` creates.
    # No-op if it already exists (refresh path). Polyglot Python+Node projects
    # get explicit [plugins.python] + [plugins.node] blocks; pure-Python
    # projects get the plain manifest.
    _init_scaffold_manifest "$(basename "$(pwd)")" "$node_path_flag" "venv"

    # Materialize the declared default test env (venv-backed only), gated on an
    # actual declaration — never inject an undeclared `testenv`. Conda/advisory
    # test envs and additional named envs materialize via `pyve env init <name>`.
    local _init_te
    _init_te="$(_init_testenv_to_materialize)"
    [[ -n "$_init_te" ]] && ensure_env_exists "$_init_te"

    # Absolute venv path — used by dep install and the composition tail.
    local _venv_abs
    _venv_abs="$(cd "$venv_dir" && pwd)"

    # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
    prompt_install_pip_dependencies "venv" "$_venv_abs"

    # hand the stack-agnostic composition tail (compose
    # .envrc/.gitignore → project-guide → next-steps) up to compose_init
    # via the result globals (see the micromamba branch + lib/init_composer.sh).
    # shellcheck disable=SC2034 # result globals consumed by lib/init_composer.sh's compose tail (cross-file)
    PYVE_INIT_TAIL_BACKEND="venv"
    # shellcheck disable=SC2034 # result global, see above
    PYVE_INIT_TAIL_ENV_PATH="$_venv_abs"
    # shellcheck disable=SC2034 # result global, see above
    PYVE_INIT_TAIL_NO_DIRENV="$no_direnv"
    # shellcheck disable=SC2034 # result global, see above
    PYVE_INIT_TAIL_PG_MODE="$project_guide_mode"
    # shellcheck disable=SC2034 # result global, see above
    PYVE_INIT_TAIL_COMP_MODE="$project_guide_completion_mode"
}

_init_python_version() {
    local version="$1"
    local version_file
    version_file="$(get_version_file_name)"

    if [[ -f "$version_file" ]]; then
        info "$version_file already exists, skipping"
    else
        set_local_python_version "$version"
        success "Created $version_file with Python $version"
    fi
}

_init_venv() {
    local venv_dir="$1"

    if [[ -d "$venv_dir" ]]; then
        info "Virtual environment '$venv_dir' already exists, skipping"
    else
        info "Creating virtual environment in '$venv_dir'..."
        # pre-flight check for the asdf/pyenv shim trap.
        # Same wire-in pattern as `ensure_env_exists`'s testenv venv
        # creation — placed after the banner so the user sees the
        # intent, then a pyve-owned error if `python` would fail.
        assert_python_resolvable || return 1
        run_cmd python -m venv "$venv_dir"
        success "Created virtual environment"
    fi
}

_init_dotenv() {
    local use_local_env="$1"

    if [[ -f "$ENV_FILE_NAME" ]]; then
        info "$ENV_FILE_NAME already exists, skipping"
        return
    fi

    if [[ "$use_local_env" == true ]] && [[ -f "$LOCAL_ENV_FILE" ]]; then
        cp "$LOCAL_ENV_FILE" "$ENV_FILE_NAME"
        success "Copied $LOCAL_ENV_FILE to $ENV_FILE_NAME"
    else
        touch "$ENV_FILE_NAME"
        if [[ "$use_local_env" == true ]]; then
            warn "$LOCAL_ENV_FILE not found, created empty $ENV_FILE_NAME"
        else
            success "Created empty $ENV_FILE_NAME"
        fi
    fi

    # Set secure permissions
    chmod 600 "$ENV_FILE_NAME"
}

# End-of-init "Next steps:" summary (Story L.l).
#
# Replaces the ad-hoc trailing `info` lines with a single coherent
# numbered block. Conditional items appear only when their precondition
# holds. Called once on the success path of init_project, just before
# `footer_box`.
#
# Usage: _init_print_next_steps <backend> <no_direnv> <env_path>
#   backend:   "venv" | "micromamba"
#   no_direnv: "true" | "false" (the --no-direnv flag state)
#   env_path:  resolved env directory (currently unused; kept in the
#              signature so verbose mode can grow log references later
#              without a callsite churn)
#
# Conditional items:
#   - direnv allow                     (when --no-direnv was NOT passed)
#   - pyve run <command>               (when --no-direnv WAS passed)
#   - pyve env install -r requirements-dev.txt
#                                      (when requirements-dev.txt exists)
#   - Read docs/project-guide/go.md   (when .project-guide.yml exists —
#                                      same canonical signal pyve update
#                                      uses for project-guide presence)
#
# Caveat appended for micromamba+direnv only: micromamba prints "to
# activate, run: micromamba activate ..." earlier in stdout; pyve
# doesn't use that, direnv does. The note keeps the user from
# following stale advice.
_init_print_next_steps() {
    local backend="$1"
    local no_direnv="$2"
    # shellcheck disable=SC2034  # env_path reserved for future verbose-mode log references
    local env_path="$3"

    banner "Next steps"

    local n=0
    if [[ "$no_direnv" == "false" ]]; then
        n=$((n + 1))
        printf '  %d. direnv allow\n' "$n"
    else
        n=$((n + 1))
        printf '  %d. pyve run <command>     # alternative to direnv activation\n' "$n"
    fi

    if [[ -f requirements-dev.txt ]]; then
        n=$((n + 1))
        printf '  %d. pyve env install -r requirements-dev.txt\n' "$n"
    fi

    if [[ -f .project-guide.yml ]]; then
        n=$((n + 1))
        printf '  %d. Read docs/project-guide/go.md\n' "$n"
    fi

    if [[ "$backend" == "micromamba" ]] && [[ "$no_direnv" == "false" ]]; then
        echo
        info "Note: ignore micromamba's 'activate' instructions above —"
        info "      Pyve uses direnv (or 'pyve run')."
    fi
}

show_init_help() {
    cat << 'EOF'
pyve init - Initialize a Python virtual environment in the current directory

Usage:
  pyve init [options]

Options:
  --python-version <ver>             Set Python version (e.g., 3.13.7)
  --backend <type>                   Backend to use: venv, micromamba, auto
  --auto-bootstrap                   Install micromamba without prompting (if needed)
  --bootstrap-to <location>          Where to install micromamba: project, user
  --strict                           Error on stale or missing lock files
  --no-lock                          Bypass missing conda-lock.yml error (not recommended)
  --env-name <name>                  Environment name (micromamba backend)
  --no-direnv                        Skip .envrc creation (for CI/CD)
  --node-path <path>                 Node sub-path for polyglot Python+Node
                                     projects (overrides convention detection;
                                     e.g. src/frontend)
  --auto-install-deps                Auto-install from pyproject.toml / requirements.txt
  --no-install-deps                  Skip dependency installation prompt (for CI/CD)
  --local-env                        Copy ~/.local/.env template
  --force                            Purge and rebuild the root environment only
                                     (destructive). Named envs under .pyve/envs/
                                     are untouched — rebuild one with
                                     'pyve env init <name> --force'
  --all                              With --force: after the root rebuild, rebuild
                                     every declared env and restore its recorded state
  --allow-synced-dir                 Bypass cloud-sync directory check
  --yes, -y                          Easy mode: accept every wizard default with
                                     no prompts, then write the explicit pyve.toml

  project-guide integration (three-step post-init hook):
    1. pip install --upgrade project-guide   (latest version)
    2. project-guide init --no-input          (creates .project-guide.yml + docs/project-guide/)
    3. shell completion in ~/.zshrc / ~/.bashrc (sentinel-bracketed block)

    --project-guide                  Run all three steps (overrides auto-skip below)
    --no-project-guide               Skip all three steps (no prompt)
    --project-guide-completion       Add shell completion (no prompt) — step 3 only
    --no-project-guide-completion    Skip shell completion (no prompt) — step 3 only

  Auto-skip safety:
    If 'project-guide' is already declared as a dependency in your
    pyproject.toml, requirements.txt, or environment.yml, pyve will NOT
    auto-install or run 'project-guide init' (avoids version conflicts
    with your pin). Pass --project-guide to override.

  Environment variables for the project-guide hooks:
    PYVE_PROJECT_GUIDE=1              Same as --project-guide
    PYVE_NO_PROJECT_GUIDE=1           Same as --no-project-guide
    PYVE_PROJECT_GUIDE_COMPLETION=1   Same as --project-guide-completion
    PYVE_NO_PROJECT_GUIDE_COMPLETION=1 Same as --no-project-guide-completion

  CI defaults (non-interactive, i.e. CI=1 or PYVE_FORCE_YES=1):
    project-guide install             → INSTALL (matches interactive default)
    project-guide shell completion    → SKIP (editing rc files in CI is surprising)

  Note: pyve update does NOT run the project-guide hook (minimal-touch).

Examples:
  pyve init                                # Auto-detect backend, default venv
  pyve init --yes                          # Easy mode: accept all defaults, no prompts
  pyve init --backend venv                 # Force venv backend
  pyve init --backend micromamba           # Force micromamba backend
  pyve init --python-version 3.13.7        # Pin Python version
  pyve init --no-direnv                    # Skip direnv (CI/CD)
  pyve init --node-path src/frontend       # Polyglot: place Node at src/frontend
  pyve init --force                        # Rebuild the root env (named envs untouched)
  pyve init --project-guide                # Install project-guide without prompting
  pyve init --no-project-guide             # Skip project-guide entirely

See `pyve --help` for the full command list.
EOF
}

#============================================================
# pyve purge — remove pyve-managed environment artifacts
# (Option 1 relocation from lib/commands/purge.sh)
#
# Removes the venv / micromamba env, version manager files, .envrc,
# .env (only if empty — v0.6.0 smart purge), pyve-managed sections of
# .gitignore, and the .pyve/ directory. Optionally preserves
# .pyve/envs/ via --keep-testenv (used by `init --force` to avoid
# rebuilding the dev/test runner across re-inits).
#
# Function-name note: this function is named `purge_project` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve purge` operates on the project.
#
# Cross-command callsite: `init_project --force` calls
# `purge_project --keep-testenv --yes` from its --force pre-flight
# and from the interactive option-2 (purge-and-rebuild) path. Both
# functions now live in this file (N.s.1 + N.s.2); bash resolves the
# call at runtime via the global function table.
#============================================================

purge_project() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local keep_testenv=false
    local skip_confirm=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-testenv)
                keep_testenv=true
                shift
                ;;
            --yes|-y)
                skip_confirm=true
                shift
                ;;
            -*)
                unknown_flag_error "purge" "$1" --keep-testenv --yes --help
                ;;
            *)
                log_error "Unexpected argument: $1"
                log_error "pyve purge takes no positional arguments."
                log_error "See: pyve purge --help"
                exit 1
                ;;
        esac
    done

    # when invoked as a composed-purge section, the composer
    # (compose_purge) owns the header/footer frame and the confirmation, so
    # suppress the duplicate here. Standalone / init --force callers
    # (PYVE_PURGE_COMPOSED unset) keep the original frame.
    if [[ -z "${PYVE_PURGE_COMPOSED:-}" ]]; then
        header_box "pyve purge"
    fi

    # pull the active plugin's purge_inventory as a data
    # interface. v3.0 reads the inventory for diagnostic / verbose
    # surfacing only — the actual removal calls below stay direct.
    # Future stories can extend the composer to consume the inventory
    # for path-level removal decisions; for now the seam is in place.
    if declare -F plugin_dispatch >/dev/null 2>&1; then
        local _plugin_inventory
        _plugin_inventory="$(plugin_dispatch python purge_inventory 2>/dev/null || true)"
        if [[ -n "${PYVE_VERBOSE:-}" ]] && [[ -n "$_plugin_inventory" ]]; then
            info "Plugin purge inventory:"
            while IFS= read -r _inv_line; do
                [[ -n "$_inv_line" ]] && info "  $_inv_line"
            done <<< "$_plugin_inventory"
        fi
    fi

    # Destructive-confirmation prompt. Skipped when:
    #   --yes / -y passed (e.g., by `init --force`), CI=1, or PYVE_FORCE_YES=1.
    if [[ "$skip_confirm" != true ]] && [[ -z "${CI:-}" ]] && [[ -z "${PYVE_FORCE_YES:-}" ]]; then
        warn "This will remove pyve-managed environment artifacts from the current project."
        if ! ask_yn "Proceed"; then
            info "Aborted — no changes made"
            exit 0
        fi
    fi

    # Source shell profiles to detect version manager
    source_shell_profiles
    detect_version_manager 2>/dev/null || true

    # Remove version file
    _purge_version_file

    # Resolve the venv directory (always `.venv` in v3).
    venv_dir="$(resolve_venv_directory)"

    # Remove virtual environment
    _purge_venv "$venv_dir"

    # Remove .pyve directory (config and micromamba envs).
    # N.f: in v3 the named-env tree lives at `.pyve/envs/<name>/<backend>/`
    # and shares its parent with the micromamba main env (pre-N.g layout
    # at `.pyve/envs/<configured_name>/` — no /conda subdir). `--keep-testenv`
    # therefore preserves `.pyve/envs/` as a whole and surgically deletes
    # only the micromamba main-env subdir (identified via the resolved
    # micromamba env name).
    # The legacy `.pyve/testenvs/` directory is also preserved defensively
    # in case the opportunistic migrator (`migrate_legacy_env_layout`)
    # hasn't run yet on a v2.8 project. Granular per-`purpose` preservation
    # is N.g's deterministic-migrator territory.
    if [[ "$keep_testenv" == true ]]; then
        if [[ -d ".pyve" ]]; then
            if [[ -d ".pyve/envs" ]] || [[ -d ".pyve/testenvs" ]]; then
                # Resolve the backend from the manifest (the env_name migration
                # below is inert on a v3-native project otherwise). A v2 project
                # resolves here too via the synthesized root backend.
                local main_env_subdir=""
                local cfg_backend
                cfg_backend="$(manifest_get_backend root 2>/dev/null || true)"
                if [[ "$cfg_backend" == "micromamba" ]]; then
                    main_env_subdir="$(resolve_micromamba_env_name 2>/dev/null || true)"
                fi
                rm -rf ".pyve/config" 2>/dev/null || true
                # Main micromamba env: the v3 root slot (Story N.bf.14),
                # plus the pre-N.bf.14 flat configured-name dir for projects
                # not yet relocated by the opportunistic mover.
                rm -rf ".pyve/envs/root" 2>/dev/null || true
                if [[ -n "$main_env_subdir" ]] && [[ "$main_env_subdir" != "root" ]] \
                   && [[ -d ".pyve/envs/$main_env_subdir" ]]; then
                    rm -rf ".pyve/envs/$main_env_subdir" 2>/dev/null || true
                fi
                find ".pyve" -mindepth 1 -maxdepth 1 \
                    ! -name "envs" ! -name "testenvs" \
                    -exec rm -rf {} + 2>/dev/null || true
                success "Removed .pyve directory contents (preserved .pyve/envs/ test environments)"
            else
                rm -rf ".pyve"
                success "Removed .pyve directory (config and micromamba environments)"
            fi
        fi
    else
        _purge_pyve_dir
        purge_env_dir
    fi

    # Remove .envrc
    _purge_envrc

    # Remove .env (only if empty - v0.6.0 smart purge)
    _purge_dotenv

    # Clean .gitignore
    _purge_gitignore "$venv_dir"

    if [[ -z "${PYVE_PURGE_COMPOSED:-}" ]]; then
        footer_box
    fi
    # Explicit success: the composed-purge orchestrator (N.ai) keys its
    # failure-recovery roll-up on this function's return code, so it must
    # not leak the status of the gating test above.
    return 0
}

_purge_version_file() {
    local version_file

    # Try to remove both possible version files
    for version_file in ".tool-versions" ".python-version"; do
        if [[ -f "$version_file" ]]; then
            rm -f "$version_file"
            success "Removed $version_file"
        fi
    done
}

_purge_venv() {
    local venv_dir="$1"

    if [[ -d "$venv_dir" ]]; then
        rm -rf "$venv_dir"
        success "Removed $venv_dir"
    else
        info "No virtual environment found at '$venv_dir'"
    fi
}

_purge_pyve_dir() {
    if [[ -d ".pyve" ]]; then
        # Check if micromamba environments exist
        if [[ -d ".pyve/envs" ]]; then
            # Try to remove micromamba environment(s) properly first
            local micromamba_path
            micromamba_path="$(get_micromamba_path 2>/dev/null || true)"

            if [[ -n "$micromamba_path" ]] && [[ -x "$micromamba_path" ]]; then
                # Get environment name from config if it exists.
                # Initialize on declaration: a declared-but-unset `local` is
                # an unbound-variable error under `set -u` on bash 4.4+ when
                # neither source declares a name. (N.bf.5)
                local env_name=""
                env_name="$(resolve_micromamba_env_name 2>/dev/null || true)"

                # If we have an env name, try to remove it
                if [[ -n "$env_name" ]]; then
                    info "Removing micromamba environment '$env_name'..."
                    if "$micromamba_path" env remove -n "$env_name" -y 2>/dev/null; then
                        success "Removed micromamba environment '$env_name'"
                    else
                        # If named removal fails, try prefix-based removal.
                        # v3 main env at the root slot (Story N.bf.14),
                        # tolerant of a not-yet-moved flat env.
                        info "Named removal failed, trying prefix-based removal..."
                        "$micromamba_path" env remove -p "$(resolve_main_micromamba_path "$env_name")" -y 2>/dev/null || true
                    fi
                else
                    # No env name in config: deregister any *actual* conda
                    # envs under .pyve/envs/. Story N.bf.17: only dirs that
                    # are conda prefixes (have a conda-meta/) are micromamba
                    # envs — a venv testenv or an empty stray must NOT be
                    # mislabeled "micromamba environment" (it's removed by the
                    # rm -rf .pyve below, not via micromamba). v3 nests the
                    # prefix under <name>/conda/; the pre-N.bf.14 flat layout
                    # had it directly under <name>/.
                    local env_dir conda_prefix
                    for env_dir in .pyve/envs/*; do
                        [[ -d "$env_dir" ]] || continue
                        conda_prefix=""
                        if [[ -d "$env_dir/conda/conda-meta" ]]; then
                            conda_prefix="$env_dir/conda"
                        elif [[ -d "$env_dir/conda-meta" ]]; then
                            conda_prefix="$env_dir"
                        fi
                        if [[ -n "$conda_prefix" ]]; then
                            info "Removing micromamba environment at '$conda_prefix'..."
                            "$micromamba_path" env remove -p "$conda_prefix" -y 2>/dev/null || true
                        fi
                    done
                fi
            else
                info "Micromamba not found, will force-remove .pyve directory"
            fi
        fi

        # Now remove the .pyve directory
        rm -rf ".pyve"
        success "Removed .pyve directory (config and micromamba environments)"
    fi
}

_purge_envrc() {
    if [[ -f ".envrc" ]]; then
        rm -f ".envrc"
        success "Removed .envrc"
    fi
}

_purge_dotenv() {
    if [[ -f "$ENV_FILE_NAME" ]]; then
        if is_file_empty "$ENV_FILE_NAME"; then
            rm -f "$ENV_FILE_NAME"
            success "Removed $ENV_FILE_NAME (was empty)"
        else
            warn "$ENV_FILE_NAME preserved (contains data). Delete manually if desired."
        fi
    fi
}

_purge_gitignore() {
    local venv_dir="$1"

    if [[ -f ".gitignore" ]]; then
        remove_pattern_from_gitignore "$venv_dir"
        remove_pattern_from_gitignore "$ENV_FILE_NAME"
        remove_pattern_from_gitignore ".envrc"
        success "Cleaned .gitignore"
    fi
}
show_purge_help() {
    cat << 'EOF'
pyve purge - Remove all Python environment artifacts

Usage:
  pyve purge [options]

Options:
  --keep-testenv              Preserve .pyve/envs/ (all dev/test runner envs)
  --yes, -y                   Skip the destructive-confirmation prompt.
                              Equivalent to setting CI=1 or PYVE_FORCE_YES=1.
  --force                     Deprecated alias for --yes (warns). '--force' now
                              means "override a refusal" elsewhere (pyve init --force).

Examples:
  pyve purge                               # Remove .pyve and the venv (prompts)
  pyve purge --yes                         # Remove without the prompt
  pyve purge --keep-testenv                # Preserve the testenv across purge

See `pyve --help` for the full command list.
EOF
}

#============================================================
# pyve update — non-destructive upgrade (Story H.e.2)
# (Option 1 relocation from lib/commands/update.sh)
#
# Refreshes managed files (config, .gitignore, .vscode/settings.json,
# project-guide scaffolding) without rebuilding the venv or touching
# user state (.env, .envrc, user sections of .gitignore). Never
# prompts. Never changes the recorded backend. Never creates files
# that don't already exist (`.vscode/settings.json`). Use
# `pyve init --force` to rebuild the environment.
#
# Spec: docs/specs/phase-H-cli-refactor-design.md §4.3.
#
# Function-name note: this function is named `update_project` per
# the project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve update` operates on the project (`.gitignore`,
# `.vscode/settings.json`, project-guide scaffolding).
#============================================================

# Update-private wrapper around the M.h.2 migration helper. Exists as
# a named function so the M.h.3 wiring is grep-visible from plugin.sh
# (the unit test `update_project: source-grep verifies the migration
# wrapper is wired` keys off the name).
_update_migrate_legacy_layout() {
    migrate_legacy_env_layout
}

update_project() {
    local pg_mode=""  # "" | "no"  (only --no-project-guide is supported per H.d §4.3)

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-project-guide)
                pg_mode="no"
                shift
                ;;
            -*)
                unknown_flag_error "update" "$1" --no-project-guide --help
                ;;
            *)
                log_error "pyve update takes no positional arguments (got: $1)"
                log_error "See: pyve update --help"
                exit 1
                ;;
        esac
    done

    # Sanity check: the project must be initialized. A project declares itself
    # via `pyve.toml`; the backend is resolved from the manifest below.
    if [[ ! -f "pyve.toml" ]]; then
        log_error "pyve update requires an initialized project."
        log_error "No pyve.toml found. Run 'pyve init' first."
        exit 1
    fi

    # Backend from the manifest (authoritative).
    local backend
    backend="$(manifest_get_backend root 2>/dev/null || true)"
    if [[ -z "$backend" ]]; then
        log_error "Could not determine the project backend."
        log_error "Run: pyve init --force"
        exit 1
    fi

    # Pre-step: opportunistically migrate any v2.7 `.pyve/testenv/venv/`
    # or v2.8 `.pyve/testenvs/<name>/{venv,conda}/` layout to the v3
    # `.pyve/envs/<name>/{venv,conda}/` shape. Silent on
    # greenfield and on already-migrated projects; prints a one-line
    # info() per boundary when an actual move happens. M.h.3 wires this;
    # the helper lives in lib/envs.sh.
    _update_migrate_legacy_layout

    header_box "pyve update v$VERSION"

    # Step 1/4 — refresh the composed .gitignore managed section across all
    # active plugins. User content above/below the managed
    # markers is preserved; prior file backed up to .gitignore.prev.
    step_begin "[1/4] Refresh .gitignore (Pyve-managed section)"
    if run_quiet compose_project_gitignore ".gitignore"; then
        step_end_ok
    else
        step_end_fail
        log_warning "  .gitignore refresh failed; existing file left intact."
    fi

    # Step 3/5 — refresh the composed .envrc managed section IF it exists.
    # like the .vscode step, NEVER create one (that respects
    # the --no-direnv opt-out from init). compose_project_envrc reloads the
    # manifest/registry, preserves user content below the managed end
    # marker, and backs the prior file up to .envrc.prev.
    if [[ -f ".envrc" ]]; then
        step_begin "[2/4] Refresh .envrc (Pyve-managed section)"
        if run_quiet compose_project_envrc ".envrc"; then
            step_end_ok
        else
            step_end_fail
            log_warning "  .envrc refresh failed; existing file left intact."
        fi
    else
        step_begin "[2/4] .envrc: absent — skipped (use 'pyve init' to opt into direnv)"
        step_end_ok
    fi

    # Step 4/5 — refresh .vscode/settings.json IF it already exists.
    # Never create — that's user opt-in at init time.
    if [[ -f ".vscode/settings.json" ]] && [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(resolve_micromamba_env_name)"
        if [[ -n "$env_name" ]]; then
            step_begin "[3/4] Refresh .vscode/settings.json"
            PYVE_REINIT_MODE=force write_vscode_settings "$env_name" >/dev/null 2>&1
            step_end_ok
        else
            step_begin "[3/4] .vscode/settings.json: micromamba env_name missing — skipped"
            step_end_ok
        fi
    elif [[ -f ".vscode/settings.json" ]]; then
        step_begin "[3/4] .vscode/settings.json: present but only refreshed for micromamba backends — skipped"
        step_end_ok
    else
        step_begin "[3/4] .vscode/settings.json: absent — skipped (use 'pyve init --force' to opt in)"
        step_end_ok
    fi

    # Ensure .pyve/ exists (should already, by precondition).
    mkdir -p .pyve

    # Step 5/5 — refresh project-guide scaffolding if present and allowed.
    if [[ "$pg_mode" == "no" ]]; then
        step_begin "[4/4] project-guide refresh skipped (--no-project-guide)"
        step_end_ok
    elif [[ -f ".project-guide.yml" ]]; then
        local env_path=""
        if [[ "$backend" == "venv" ]]; then
            local venv_dir
            venv_dir="$(resolve_venv_directory)"
            env_path="$venv_dir"
        elif [[ "$backend" == "micromamba" ]]; then
            # Main micromamba env at the v3 root slot (Story N.bf.14); the
            # flat→root move already fired via _update_migrate_legacy_layout
            # earlier in update_project.
            env_path="$(micromamba_root_prefix)"
        fi
        if [[ -n "$env_path" ]] && [[ -d "$env_path" ]]; then
            step_begin "[4/4] Refresh project-guide artifacts"
            if run_quiet run_project_guide_update_in_env "$backend" "$env_path"; then
                step_end_ok
            else
                step_end_fail
                log_warning "  Run 'project-guide update' manually to retry."
            fi
        else
            step_begin "[4/4] project-guide: environment not found — skipped"
            step_end_ok
            log_warning "  (Run 'pyve init --force' to rebuild the environment.)"
        fi
    else
        step_begin "[4/4] project-guide: .project-guide.yml absent — skipped"
        step_end_ok
    fi

    footer_box
    return 0
}
show_update_help() {
    cat << 'EOF'
pyve update - Non-destructive upgrade: refresh managed files and config

Usage:
  pyve update [--no-project-guide]

Description:
  Updates a pyve-managed project to the current pyve version WITHOUT
  rebuilding the virtual environment. Safe to run on any pyve-managed
  project; idempotent.

  Refreshes:
    - Pyve-managed sections of .gitignore
    - .envrc managed section (only if it already exists; user content
      below the managed end marker is preserved, prior file → .envrc.prev)
    - .vscode/settings.json (only if it already exists)
    - project-guide scaffolding (via 'project-guide update --no-input')

  Does NOT:
    - rebuild the virtual environment (use 'pyve init --force' for that)
    - create .env or .envrc when absent (those are user opt-in at init)
    - re-prompt for backend (the recorded backend is preserved)
    - bump the hosted project-guide package version (run 'pyve self
      provision' to upgrade the globally-hosted project-guide)

Options:
  --no-project-guide          Skip the project-guide refresh step

Exit codes:
  0    Success (including no-op when already at current version).
  1    Failure (not a pyve project, or unwritable files).

See also:
  pyve init --force          Destroy + rebuild the environment
  pyve --help                Full command list
Boundary:
  pyve update touches the files Pyve manages around your project;
  pyve init --force / pyve upgrade touch the environments themselves.
EOF
}

#============================================================
# pyve check — read-only diagnostics (Story H.e.3)
# (Option 1 relocation from lib/commands/check.sh)
#
# Replaces the semantic of `pyve validate` (structured 0/1/2 exit
# codes for CI) and most of `pyve doctor` (per-problem findings
# with one actionable next-step). State reporting is `pyve status`
# (H.e.4), not here.
#
# Spec: docs/specs/phase-H-check-status-design.md §3.
#
# Severity ladder: info (no effect) → pass (✓) → warn (⚠, exit 2)
# → error (✗, exit 1). Escalation is one-way: an error later in
# the run cannot be downgraded; a warning cannot downgrade an
# error.
#
# Function-name note: this function is named `check_environment`
# per the project-essentials "Function naming convention:
# verb_<operand>" rule — `pyve check` operates on the project's
# environment.
#
# Closure pattern: `check_environment` defines three nested
# functions (`_check_pass`, `_check_warn`, `_check_fail`) that
# capture the locals `errors`, `warnings`, `passed`, `exit_code`
# via bash dynamic scoping. The per-backend helpers
# (`_check_venv_backend`, `_check_micromamba_backend`) and
# `_check_summary_and_exit` defined at file scope below see those
# locals at call time because bash resolves variable references
# up the call stack, not by lexical scope. **Do not refactor to
# file-scope counters** — the closure shape is intentional and
# tested by `test_check.bats`.
#
# `doctor_check_*` helpers stay in `lib/utils.sh` (cross-command
# rule — `pyve check --fix` and other future callers may need them).
#============================================================

check_environment() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "check" "$1" --help
                ;;
            *)
                log_error "pyve check takes no positional arguments (got: $1)"
                log_error "See: pyve check --help"
                exit 1
                ;;
        esac
    done

    local errors=0
    local warnings=0
    local passed=0
    local exit_code=0

    _check_pass() {
        printf "✓ %s\n" "$1"
        passed=$((passed + 1))
    }
    _check_warn() {
        printf "⚠ %s\n" "$1"
        [[ -n "${2:-}" ]] && printf "  %s\n" "$2"
        warnings=$((warnings + 1))
        if (( exit_code != 1 )); then
            exit_code=2
        fi
    }
    _check_fail() {
        printf "✗ %s\n" "$1"
        [[ -n "${2:-}" ]] && printf "  %s\n" "$2"
        errors=$((errors + 1))
        exit_code=1
    }

    # the composer (compose_check) owns the top-level banner
    # when it dispatches this hook as a per-plugin section, so suppress the
    # duplicate here. Standalone invocations (PYVE_CHECK_COMPOSED unset)
    # still print it.
    if [[ -z "${PYVE_CHECK_COMPOSED:-}" ]]; then
        printf "Pyve Environment Check\n"
        printf "======================\n\n"
    fi

    # --- Check 1: pyve project present ------------------------------------
    # `pyve.toml` is the sole declaration; a project without it is not a pyve
    # project.
    manifest_load 2>/dev/null || true
    if [[ ! -f "pyve.toml" ]]; then
        _check_fail "Configuration: no pyve.toml (not a pyve project)" "→ Run: pyve init"
        _check_summary_and_exit
    fi
    _check_pass "Configuration: pyve.toml"

    # --- Check 3: backend configured --------------------------------------
    # Read the main (`root`) env's backend from the manifest accessor.
    local backend
    backend="$(manifest_get_backend root 2>/dev/null || true)"
    if [[ -z "$backend" ]]; then
        _check_fail "Backend: not configured in pyve.toml" \
            "→ Run: pyve init --backend venv|micromamba"
        _check_summary_and_exit
    fi
    _check_pass "Backend: $backend"

    # --- Backend-specific checks ------------------------------------------
    local env_path=""
    if [[ "$backend" == "venv" ]]; then
        local venv_dir
        venv_dir="$(resolve_venv_directory)"
        env_path="$venv_dir"
        _check_venv_backend "$env_path"
    elif [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(resolve_micromamba_env_name)"
        # Main micromamba env at the v3 root slot (Story N.bf.14), tolerant
        # of a not-yet-moved flat env (non-mutating — `check` is a diagnostic).
        env_path="$(resolve_main_micromamba_path "$env_name")"
        _check_micromamba_backend "$env_path" "$env_name"
    else
        _check_fail "Backend: unknown value '$backend'" \
            "→ Run: pyve init --backend venv|micromamba"
    fi

    # --- Common integration checks ----------------------------------------
    # Check 9: .envrc
    if [[ -f ".envrc" ]]; then
        _check_pass "direnv: .envrc present"
    else
        _check_warn ".envrc: missing" "→ Run: pyve init --force"
    fi

    # Check 10: .env
    if [[ -f ".env" ]]; then
        _check_pass ".env: present"
    else
        _check_warn ".env: missing" "→ Run: touch .env"
    fi

    # Check 16: testenv (conditional — only speaks when the env exists).
    _check_default_testenv

    # Declared named envs beyond the reserved pair: canary each
    # materialized one (empty-until-demand envs stay silent).
    _check_declared_envs

    # Manifest↔disk reconciliation: orphaned / contradictory trees.
    _check_env_orphans

    _check_summary_and_exit
}

#============================================================
# Per-env runnability canary (the env_probe plugin hook).
#
# Executes a CONSOLE-SCRIPT wrapper (`bin/pip --version`) — the artifact
# that carries a baked shebang and actually breaks on relocation /
# interpreter deletion. `python -m …` / `python -c …` bypass wrappers
# (the env's `python` symlink survives exactly the faults that kill every
# entry point), so they can never catch a dead-shebang env. Verdict
# vocabulary is documented on the contract hook (lib/plugins/contract.sh).
#============================================================

# Probes run through pyve_run_bounded (lib/utils.sh) — bounded to
# PYVE_PROBE_TIMEOUT so a wedged interpreter can never hang `pyve check`.

# The Python plugin's env_probe hook: probe <env_name> and print one
# classified verdict (see lib/plugins/contract.sh for the vocabulary).
# Self-sufficient — loads env/manifest state itself so it is callable as
# a bare hook (check composer today, the heal mechanism later).
python_pyve_plugin_env_probe() {
    local env_name="$1"
    read_env_config >/dev/null 2>&1 || true
    local backend
    if [[ "$env_name" == "root" ]]; then
        backend="$(_env_resolve_root_backend)"
    else
        backend="$(_env_resolve_backend "$env_name")"
    fi
    case "$backend" in
        venv|micromamba) ;;
        *)
            if _env_backend_is_advisory "$backend"; then
                printf 'advisory'
                return 0
            fi
            ;;
    esac
    local env_path=""
    if [[ "$env_name" == "root" ]]; then
        if [[ "$backend" == "micromamba" ]]; then
            # Non-mutating root-slot resolution — a probe must not fire
            # the opportunistic layout migrator.
            local mm_name
            mm_name="$(resolve_micromamba_env_name 2>/dev/null || true)"
            env_path="$(resolve_main_micromamba_path "$mm_name" 2>/dev/null || true)"
        else
            env_path="$(resolve_venv_directory 2>/dev/null || true)"
            [[ -z "$env_path" ]] && env_path="${DEFAULT_VENV_DIR:-.venv}"
        fi
    else
        env_path="$(resolve_env_path "$env_name" 2>/dev/null || true)"
    fi
    _env_probe_classify "$env_path" "$backend"
}

# Classify the env at <env_path> (backend <backend>). Prints the verdict;
# returns 0 for runnable / not-materialized, 1 for the broken family.
_env_probe_classify() {
    local env_path="$1" backend="$2"
    if [[ -z "$env_path" || ! -d "$env_path" ]]; then
        printf 'not-materialized'
        return 0
    fi
    local py="$env_path/bin/python"
    if [[ -L "$py" && ! -e "$py" ]]; then
        printf 'dangling-symlink'
        return 1
    fi
    if [[ ! -e "$py" ]]; then
        printf 'missing-interpreter'
        return 1
    fi
    local wrapper="$env_path/bin/pip"
    if [[ ! -e "$wrapper" ]]; then
        # No console script to probe (minimal fixture envs, --without-pip
        # venvs): a runnable interpreter is not condemned — the canary's
        # target class is a PRESENT-but-dead wrapper.
        if pyve_run_bounded "$py" --version >/dev/null; then
            printf 'runnable'
            return 0
        fi
        printf 'broken'
        return 1
    fi
    # Execute the wrapper: venv directly; micromamba through
    # `micromamba run -p` (CONDA_PREFIX / activate.d / lib paths), falling
    # back to direct wrapper exec when the micromamba binary is absent —
    # the wrapper's baked shebang is what breaks either way.
    local mm="" out="" rc=0
    if [[ "$backend" == "micromamba" ]] \
        && declare -F get_micromamba_path >/dev/null 2>&1; then
        mm="$(get_micromamba_path 2>/dev/null)" || mm=""
    fi
    if [[ -n "$mm" ]]; then
        out="$(pyve_run_bounded "$mm" run -p "$env_path" pip --version)" || rc=$?
    else
        out="$(pyve_run_bounded "$wrapper" --version)" || rc=$?
    fi
    if [[ "$rc" -eq 0 && "$out" == pip* ]]; then
        local ver
        ver="$(printf '%s\n' "$out" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)"
        printf 'runnable%s' "${ver:+ $ver}"
        return 0
    fi
    # Exec failed — classify by the wrapper's baked shebang target.
    local shebang interp
    shebang="$(head -n1 "$wrapper" 2>/dev/null || true)"
    if [[ "$shebang" == '#!'* ]]; then
        interp="${shebang#\#!}"
        interp="${interp#"${interp%%[![:space:]]*}"}"
        interp="${interp%% *}"
        if [[ -n "$interp" && ! -x "$interp" ]]; then
            printf 'dead-shebang'
            return 1
        fi
    fi
    printf 'broken'
    return 1
}

# Render a canary verdict through the caller's _check_* closures.
# Usage: _check_env_canary <env_name> <label> <rebuild_hint> <fail|warn>
# runnable prints a pass line; not-materialized / advisory print nothing
# (empty-until-demand and declarative-only are legitimate states, not
# findings); the broken family reports at the given severity with the
# role-correct rebuild hint. Always returns 0 — severity flows through
# the closures, never the return code.
_check_env_canary() {
    local env_name="$1" label="$2" hint="$3" severity="${4:-warn}"
    local report="_check_warn"
    [[ "$severity" == "fail" ]] && report="_check_fail"
    local verdict class detail=""
    verdict="$(python_pyve_plugin_env_probe "$env_name")" || true
    class="${verdict%% *}"
    [[ "$verdict" == *" "* ]] && detail="${verdict#* }"
    case "$class" in
        runnable)
            if [[ -n "$detail" ]]; then
                _check_pass "$label: console scripts runnable (pip $detail)"
            else
                _check_pass "$label: runnable"
            fi
            ;;
        not-materialized|advisory|"")
            : ;;
        dead-shebang)
            "$report" "$label: console scripts broken (dead shebang — env relocated or interpreter deleted)" "$hint" ;;
        dangling-symlink)
            "$report" "$label: broken (python is a dangling symlink — interpreter deleted)" "$hint" ;;
        missing-interpreter)
            "$report" "$label: broken (no python interpreter in the env)" "$hint" ;;
        *)
            "$report" "$label: console scripts broken (probe failed)" "$hint" ;;
    esac
    return 0
}

# Canary every declared named env beyond the reserved pair — `root` is
# probed inside its backend section and `testenv` by
# _check_default_testenv. Broken named envs route to their own rebuild
# verb (`pyve env init <name> --force`), never a root-level verb.
_check_declared_envs() {
    manifest_load >/dev/null 2>&1 || return 0
    local name
    while IFS= read -r name; do
        [[ -z "$name" || "$name" == "root" || "$name" == "testenv" ]] && continue
        _check_env_canary "$name" "env '$name'" "→ Run: pyve env init $name --force" warn
    done < <(manifest_list_envs 2>/dev/null || true)
    return 0
}

# Manifest↔disk reconciliation: flag state↔declaration contradictions.
#   (a) a materialized `.pyve/envs/<name>/` tree with no `[env.<name>]`
#       declaration — the manifest is canonical; undeclared state is drift;
#   (b) a root declared with a non-materializable (advisory) backend that
#       nonetheless has a materialized env — the field shape:
#       `[env.root] backend = "none"` with a stale `.pyve/envs/root/conda/`.
# Warnings, not errors: a contradiction doesn't break the declared envs'
# operation; it needs cleanup (the heal mechanism consumes these).
_check_env_orphans() {
    manifest_load >/dev/null 2>&1 || return 0
    local name
    while IFS= read -r name; do
        [[ -z "$name" || "$name" == "root" ]] && continue
        if ! manifest_get_env "$name" >/dev/null 2>&1; then
            _check_warn "env '$name': materialized but not declared (orphan)" \
                "→ Declare [env.$name] in pyve.toml, or remove the tree: rm -rf .pyve/envs/$name"
        fi
    done < <(list_materialized_env_names 2>/dev/null || true)

    local root_backend
    root_backend="$(_env_resolve_root_backend)"
    case "$root_backend" in
        venv|micromamba) return 0 ;;
    esac
    if _env_backend_is_advisory "$root_backend"; then
        local slot
        slot="$(micromamba_root_prefix)"
        if [[ -d "$slot" ]]; then
            _check_warn "root: declared backend '$root_backend' is not materializable, but a conda env is materialized at $slot (contradiction)" \
                "→ Remove the tree: rm -rf $slot"
        fi
        local vd
        vd="$(resolve_venv_directory 2>/dev/null || true)"
        [[ -z "$vd" ]] && vd="${DEFAULT_VENV_DIR:-.venv}"
        if [[ -d "$vd" ]]; then
            _check_warn "root: declared backend '$root_backend' is not materializable, but a venv is materialized at $vd (contradiction)" \
                "→ Remove the tree: rm -rf $vd"
        fi
    fi
    return 0
}

# Default-testenv line for `pyve check`. Routes the fault to the verb
# that actually repairs it, keyed off the canary verdict (a console-script
# runnability probe — existence stats and `python -c 'import pytest'` both
# rubber-stamp a relocated env whose wrappers are dead): a broken env
# needs the rebuild verb `pyve env init testenv --force`; a healthy env
# that merely lacks pytest is repopulated by `pyve test`. Absent env →
# silent (the check is conditional). Emits via the caller's _check_*
# closures (dynamic scope from check_environment).
_check_default_testenv() {
    local testenv_venv
    testenv_venv="$(resolve_env_path testenv)"
    [[ -d "$testenv_venv" ]] || return 0
    local verdict class
    verdict="$(python_pyve_plugin_env_probe testenv)" || true
    class="${verdict%% *}"
    case "$class" in
        runnable) ;;
        not-materialized|advisory|"")
            return 0 ;;
        dead-shebang)
            _check_warn "testenv: present but console scripts broken (dead shebang — env relocated or interpreter deleted)" \
                "→ Run: pyve env init testenv --force"
            return 0 ;;
        *)
            _check_warn "testenv: present but broken ($class)" \
                "→ Run: pyve env init testenv --force"
            return 0 ;;
    esac
    # pytest presence — probe the WRAPPER (bin/pytest), never `python -c
    # 'import pytest'`: a dead wrapper must not masquerade as installed.
    if [[ -e "$testenv_venv/bin/pytest" ]]; then
        if pyve_run_bounded "$testenv_venv/bin/pytest" --version >/dev/null; then
            _check_pass "testenv: pytest installed"
        else
            _check_warn "testenv: pytest wrapper present but broken (console scripts cannot run)" \
                "→ Run: pyve env init testenv --force"
        fi
    else
        _check_warn "testenv: present but pytest not installed" \
            "→ Run: pyve test"
    fi
}

# Per-backend helpers. These escalate via the outer _check_* closures and
# consult the outer-scoped env_path.

_check_venv_backend() {
    local venv_dir="$1"

    # Check 5: venv directory + python executable.
    if [[ ! -d "$venv_dir" ]]; then
        _check_fail "Environment: $venv_dir (missing)" "→ Run: pyve init --force"
        return 0
    fi
    if [[ ! -x "$venv_dir/bin/python" ]]; then
        _check_fail "Environment: $venv_dir/bin/python (missing or not executable)" \
            "→ Run: pyve init --force"
        return 0
    fi
    _check_pass "Environment: $venv_dir"

    # Python version (informational for now; full version-match gate
    # against .tool-versions / .python-version is deferred to a
    # follow-up H.e.3 polish).
    local py_version
    py_version="$("$venv_dir/bin/python" --version 2>&1 | awk '{print $2}')"
    if [[ -n "$py_version" ]]; then
        _check_pass "Python: $py_version"
    fi

    # Canary: execute a console-script wrapper. A runnable `python` and a
    # passing `-x` both rubber-stamp a relocated env whose every entry
    # point is dead — only executing a wrapper catches it. Root repairs
    # via the top-level rebuild verb (`pyve env` rejects root).
    _check_env_canary root "Environment" "→ Run: pyve init --force" fail

    # Check 7: venv path mismatch (relocated project).
    local path_output
    path_output="$(doctor_check_venv_path "$venv_dir")"
    if [[ -n "$path_output" ]]; then
        _check_fail "Environment: venv path mismatch (project may have been relocated)" \
            "→ Run: pyve init --force"
    fi

    # Check 13: duplicate dist-info.
    local dup_output
    dup_output="$(doctor_check_duplicate_dist_info "$venv_dir")"
    if [[ "$dup_output" == *"Duplicate dist-info detected"* ]]; then
        _check_fail "Environment: duplicate dist-info directories detected" \
            "→ Run: pyve init --force"
    fi

    # Check 14: cloud sync collision artifacts.
    local collision_output
    collision_output="$(doctor_check_collision_artifacts "$venv_dir")"
    if [[ "$collision_output" == *"Cloud sync collision artifacts detected"* ]]; then
        _check_fail "Environment: cloud sync collision artifacts detected" \
            "→ Move the project outside a cloud-synced directory, then: pyve init --force"
    fi
}

# Report conda-lock.yml status for `pyve check` (Story N.bf.9, declarative
# model). A missing lock is a warning ONLY when conda-lock is a declared
# dependency (the project opted into locking); otherwise no lock is expected
# and it's reported as a non-issue. Uses the `_check_pass` / `_check_warn`
# reporters in scope (mirrors _check_micromamba_backend's closure usage).
_check_conda_lock_status() {
    if [[ ! -f "conda-lock.yml" ]]; then
        if is_conda_lock_declared; then
            _check_warn "conda-lock.yml: missing (conda-lock is in environment.yml)" \
                "→ Run: pyve lock  (or --no-lock for this run, or remove conda-lock from environment.yml)"
        else
            _check_pass "conda-lock.yml: not required (conda-lock not declared in environment.yml)"
        fi
    elif is_lock_file_stale; then
        _check_warn "conda-lock.yml: stale (older than environment.yml)" \
            "→ Run: pyve lock"
    else
        _check_pass "conda-lock.yml: up to date"
    fi
}

_check_micromamba_backend() {
    local env_path="$1"
    local env_name="$2"

    # Check 4: micromamba binary available.
    if ! check_micromamba_available; then
        _check_fail "Backend: micromamba binary not found" \
            "→ Run: pyve init   (triggers bootstrap)"
        return 0
    fi
    _check_pass "Micromamba: available"

    # Check: environment.yml present.
    if [[ ! -f "environment.yml" ]]; then
        _check_fail "environment.yml: missing" \
            "→ Run: pyve init --backend micromamba"
        return 0
    fi
    _check_pass "environment.yml: present"

    # Check 11 / 12: conda-lock.yml present and fresh (declarative — N.bf.9).
    _check_conda_lock_status

    # Check 5: environment directory exists.
    if [[ -z "$env_path" ]] || [[ ! -d "$env_path" ]]; then
        _check_fail "Environment: $env_path (missing)" "→ Run: pyve init --force"
        return 0
    fi
    if [[ ! -x "$env_path/bin/python" ]]; then
        _check_fail "Environment: $env_path/bin/python (missing or not executable)" \
            "→ Run: pyve init --force"
        return 0
    fi
    _check_pass "Environment: $env_path"

    # Python version (informational).
    local py_version
    py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
    if [[ -n "$py_version" ]]; then
        _check_pass "Python: $py_version"
    fi

    # Canary: execute a console-script wrapper (see the venv twin above).
    _check_env_canary root "Environment" "→ Run: pyve init --force" fail

    # Check 13 / 14 / 15 reuse the existing helpers.
    local dup_output
    dup_output="$(doctor_check_duplicate_dist_info "$env_path")"
    if [[ "$dup_output" == *"Duplicate dist-info detected"* ]]; then
        _check_fail "Environment: duplicate dist-info directories detected" \
            "→ Run: pyve init --force"
    fi

    local collision_output
    collision_output="$(doctor_check_collision_artifacts "$env_path")"
    if [[ "$collision_output" == *"Cloud sync collision artifacts detected"* ]]; then
        _check_fail "Environment: cloud sync collision artifacts detected" \
            "→ Move the project outside a cloud-synced directory, then: pyve init --force"
    fi

    local native_output
    native_output="$(doctor_check_native_lib_conflicts "$env_path")"
    if [[ "$native_output" == *"Potential native library conflict"* ]]; then
        _check_warn "Environment: potential pip/conda native library conflict" \
            "→ Add the missing OpenMP package to environment.yml, then: pyve lock"
    fi
}

_check_summary_and_exit() {
    printf "\n"
    printf "%d passed, %d warnings, %d errors\n" "$passed" "$warnings" "$errors"
    exit "$exit_code"
}
show_check_help() {
    cat << 'EOF'
pyve check - Diagnose environment problems and suggest fixes

Usage:
  pyve check [--fix [--yes]]

Options:
  --fix        After the diagnostics, detect broken Pyve-managed hosting
               state (a toolchain venv or hosted tool that exists but
               cannot run, a dangling shim) and repair it. Plan-then-
               confirm: the faults and intended repairs are printed
               first; nothing is repaired without assent.
  --yes, -y    Assent to the repair batch (only with --fix). Without it,
               an interactive run prompts once; a non-interactive run is
               report-only and never mutates.

Description:
  Runs a set of read-only diagnostics against the current project and
  reports findings. Every failure includes exactly one command that
  will move the project toward a working state — no chains, no
  references to other commands.

  For a read-only snapshot of current state (no diagnostics), use
  'pyve status'.

Exit codes:
  0    No errors — all checks passed, or warnings only (environment
       works but is drifting; advisory text is still printed).
  2    One or more errors — environment is broken for 'pyve run' /
       'pyve test'.

Notes:
  - pyve check (without --fix) is safe to run in CI (no side effects,
    stable exit codes). With --fix it stays CI-safe unless --yes is
    also passed: without assent it only reports what it would repair.
  - The exit code always reflects the pre-repair diagnostics; a healed
    system goes green on the next run.

See also:
  pyve status            Read-only state snapshot (no diagnostics)
  pyve --help            Full command list
EOF
}

#============================================================
# pyve status — read-only state dashboard (Story H.e.4)
# (Option 1 relocation from lib/commands/status.sh)
#
# Three sections: Project / Environment / Integrations. Never has
# a non-zero exit code based on findings — that's `pyve check`'s
# job. `pyve status` reports reality (including "not a pyve
# project" as a valid reality).
#
# Spec: docs/specs/phase-H-check-status-design.md §4.
#
# Function-name note: this function is named `show_status` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule. `status` is a noun, so semantic alignment trumps spelling
# — "show the status" is the operation being performed.
#============================================================

show_status() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                unknown_flag_error "status" "$1" --help
                ;;
            *)
                log_error "pyve status takes no positional arguments (got: $1)"
                log_error "See: pyve status --help"
                exit 1
                ;;
        esac
    done

    # Title + divider. BOLD for the title, DIM for the rule — per H.c §4.4.
    # the composer (compose_status) owns the top-level title when
    # it dispatches this hook as a per-plugin section, so suppress the
    # duplicate here. Standalone invocations (PYVE_STATUS_COMPOSED unset)
    # still print it.
    if [[ -z "${PYVE_STATUS_COMPOSED:-}" ]]; then
        printf "\n%sPyve project status%s\n" "${BOLD}" "${RESET}"
        printf "%s───────────────────%s\n\n" "${DIM}" "${RESET}"
    fi

    # `pyve.toml` is the sole declaration; a project without it is not a
    # pyve-managed project.
    manifest_load 2>/dev/null || true
    if [[ ! -f "pyve.toml" ]]; then
        # Non-project fallback. Don't treat it as an error; status reports
        # reality, and "not a pyve project" is a valid reality.
        _status_row "Not a pyve-managed project" ""
        printf "  %sRun 'pyve init' to initialize.%s\n\n" "${DIM}" "${RESET}"
        return 0
    fi

    _status_section_project
    _status_section_environment
    _status_section_integrations

    return 0
}

# Print one key/value row with a 17-char label column (matches the widest
# label used — "environment.yml:") so every section aligns.
_status_row() {
    local label="$1"
    local value="$2"
    printf "  %-17s %s\n" "${label}" "${value}"
}

_status_header() {
    printf "%s%s%s\n" "${BOLD}" "$1" "${RESET}"
}

_status_section_project() {
    _status_header "Project"
    _status_row "Path:" "$(pwd -P)"

    # Read the main (`root`) env's backend from the manifest accessor —
    # works for v3-native (pyve.toml) and v2 (read-compat synthesis) alike.
    local backend
    backend="$(manifest_get_backend root 2>/dev/null || true)"
    if [[ -n "$backend" ]]; then
        _status_row "Backend:" "$backend"
    else
        _status_row "Backend:" "${DIM}not configured${RESET}"
    fi

    # The project is declared by pyve.toml (the caller only reaches this section
    # when pyve.toml exists; a project without it is reported as non-managed).
    _status_row "Declaration:" "pyve.toml"

    _status_row "Python:" "$(_status_configured_python)"
    printf "\n"
}

# Detect the configured Python version source. Returns a human-readable
# string like "3.14.4 (.tool-versions via asdf)" or "(not pinned)".
#
# The project's backend, for status display. Reads the v3 manifest — `pyve.toml`
# is authoritative for the root backend, and `show_status` calls `manifest_load`
# before these sections run.
_status_backend() {
    manifest_get_backend root 2>/dev/null || true
}

# Backend-aware: micromamba projects pin Python in environment.yml
# (`python=<spec>`); venv-style backends use .tool-versions /
# .python-version. Without the dispatch the Project section falsely
# reports "not pinned" for a pinned micromamba project, contradicting
# the Environment section's actual interpreter version.
_status_configured_python() {
    local backend
    backend="$(_status_backend)"
    if [[ "$backend" == "micromamba" ]]; then
        _status_configured_python_micromamba
    else
        _status_configured_python_venv
    fi
}

_status_configured_python_venv() {
    local out version source
    out="$(resolve_python_version)"
    version="${out%%|*}"
    source="${out##*|}"
    case "$source" in
        tool-versions)  source=".tool-versions via asdf" ;;
        python-version) source=".python-version via pyenv" ;;
    esac
    if [[ -z "$version" ]]; then
        printf "%snot pinned%s" "${DIM}" "${RESET}"
    else
        printf "%s (%s)" "${version}" "${source}"
    fi
}

_status_configured_python_micromamba() {
    local version=""
    if [[ -f "environment.yml" ]]; then
        version="$(_status_parse_env_yml_python_pin environment.yml)"
    fi
    if [[ -z "$version" ]]; then
        printf "%snot pinned%s" "${DIM}" "${RESET}"
    else
        printf "%s (environment.yml)" "${version}"
    fi
}

# Extract the python version spec from a conda environment.yml. Matches
# lines like `- python=3.12`, `- python =3.12.*`, `  - python = 3.12`.
# Strips a trailing `.*` glob so the displayed pin reads naturally.
# Returns empty when no python dependency is present.
_status_parse_env_yml_python_pin() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local line spec
    line="$(grep -E '^[[:space:]]*-[[:space:]]*python[[:space:]]*=' "$file" 2>/dev/null | head -1 || true)"
    [[ -z "$line" ]] && return 0
    # Take everything after the first '=' and trim whitespace + comments.
    spec="${line#*=}"
    spec="${spec%%#*}"
    # Trim leading/trailing whitespace (bash 3.2 compatible).
    spec="${spec#"${spec%%[![:space:]]*}"}"
    spec="${spec%"${spec##*[![:space:]]}"}"
    # Drop a trailing ".*" glob — common in conda specs but noisy in display.
    spec="${spec%.\*}"
    printf "%s" "$spec"
}

_status_section_environment() {
    _status_header "Environment"

    local backend
    backend="$(_status_backend)"

    if [[ "$backend" == "micromamba" ]]; then
        _status_env_micromamba
    elif [[ "$backend" == "venv" ]]; then
        _status_env_venv
    else
        _status_row "Path:" "${DIM}backend not configured${RESET}"
    fi

    printf "\n"
}

_status_env_venv() {
    local venv_dir
    venv_dir="$(resolve_venv_directory)"

    if [[ ! -d "$venv_dir" ]]; then
        _status_row "Path:" "${venv_dir} (${DIM}missing${RESET})"
        return 0
    fi
    _status_row "Path:" "$venv_dir"

    if [[ -x "$venv_dir/bin/python" ]]; then
        local py_version
        py_version="$("$venv_dir/bin/python" --version 2>&1 | awk '{print $2}')"
        _status_row "Python:" "${py_version:-unknown}"
    else
        _status_row "Python:" "${DIM}not found${RESET}"
    fi

    _status_row "Packages:" "$(_status_venv_package_count "$venv_dir")"
}

_status_venv_package_count() {
    local venv_dir="$1"
    local site_packages count
    # Same `find`-pipefail guard as above.
    if [[ ! -d "$venv_dir/lib" ]]; then
        printf "%sunknown%s" "${DIM}" "${RESET}"
        return 0
    fi
    site_packages="$(find "$venv_dir/lib" -type d -name "site-packages" 2>/dev/null | head -1 || true)"
    if [[ -z "$site_packages" ]]; then
        printf "%sunknown%s" "${DIM}" "${RESET}"
        return 0
    fi
    count="$(find "$site_packages" -maxdepth 1 -name "*.dist-info" 2>/dev/null | wc -l | tr -d ' ' || true)"
    printf "%s installed" "${count:-0}"
}

_status_env_micromamba() {
    local env_name env_path
    env_name="$(resolve_micromamba_env_name 2>/dev/null || true)"
    if [[ -z "$env_name" ]]; then
        _status_row "Name:" "${DIM}not configured${RESET}"
        return 0
    fi
    # v3 root slot (Story N.bf.14), tolerant of a not-yet-moved flat env.
    env_path="$(resolve_main_micromamba_path "$env_name")"

    _status_row "Name:" "$env_name"

    if [[ ! -d "$env_path" ]]; then
        _status_row "Path:" "${env_path} (${DIM}missing${RESET})"
        return 0
    fi
    _status_row "Path:" "$env_path"

    if [[ -x "$env_path/bin/python" ]]; then
        local py_version
        py_version="$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')"
        _status_row "Python:" "${py_version:-unknown}"
    fi

    if [[ -d "$env_path/conda-meta" ]]; then
        local count
        count="$(find "$env_path/conda-meta" -name "*.json" 2>/dev/null | wc -l | tr -d ' ' || true)"
        _status_row "Packages:" "${count:-0} installed"
    fi

    if [[ -f "environment.yml" ]]; then
        _status_row "environment.yml:" "present"
    else
        _status_row "environment.yml:" "${DIM}missing${RESET}"
    fi

    if [[ -f "conda-lock.yml" ]]; then
        if is_lock_file_stale 2>/dev/null; then
            _status_row "conda-lock.yml:" "${DIM}stale${RESET}"
        else
            _status_row "conda-lock.yml:" "up to date"
        fi
    else
        _status_row "conda-lock.yml:" "${DIM}missing${RESET}"
    fi
}

_status_section_integrations() {
    _status_header "Integrations"

    if [[ -f ".envrc" ]]; then
        _status_row "direnv:" ".envrc present"
    else
        _status_row "direnv:" "${DIM}.envrc missing${RESET}"
    fi

    if [[ -f ".env" ]]; then
        if is_file_empty ".env"; then
            _status_row ".env:" "present (empty)"
        else
            _status_row ".env:" "present"
        fi
    else
        _status_row ".env:" "${DIM}missing${RESET}"
    fi

    # project-guide deliberately has NO row here: in v3 it is a globally
    # hosted tool (toolchain venv + shim), never installed into the project
    # env this section describes, so a row probing the project env
    # contradicted the real hosting state. The composed [project-guide]
    # section (lib/status_composer.sh) is the sole readout.

    local testenv_venv
    testenv_venv="$(resolve_env_path testenv)"
    if [[ -d "$testenv_venv" ]]; then
        if [[ -x "$testenv_venv/bin/python" ]] && \
           "$testenv_venv/bin/python" -c 'import pytest' >/dev/null 2>&1; then
            _status_row "testenv:" "present, pytest installed"
        elif [[ -x "$testenv_venv/bin/python" ]]; then
            _status_row "testenv:" "present, pytest ${DIM}not installed${RESET}"
        else
            _status_row "testenv:" "present (${DIM}broken${RESET})"
        fi
    else
        _status_row "testenv:" "${DIM}not present${RESET}"
    fi

    printf "\n"
}
show_status_help() {
    cat << 'EOF'
pyve status - Show a snapshot of the current project environment

Usage:
  pyve status

Description:
  Prints an at-a-glance summary of how this project is set up:
  backend, Python version, environment location, package count, and
  integration state (direnv, .env, testenv).

  pyve status is read-only and never produces a non-zero exit code
  based on findings — if something looks wrong, use 'pyve check'.

Output respects NO_COLOR=1 (https://no-color.org) — set it to strip
ANSI escapes without changing the layout.

See also:
  pyve check             Diagnose problems and suggest fixes
  pyve --help            Full command list
EOF
}

#============================================================
# pyve run — execute a command inside the active project environment
# (Option 1 relocation from lib/commands/run.sh)
#
# Auto-detects the active backend (venv vs micromamba) by reading the
# manifest first (authoritative), then falling back to the
# directory heuristic for bare projects. exec()s the target command
# with environment activation done in-process (no shell layer).
#
# No private `_run_*` helpers and no `show_run_help` block exist —
# `pyve run` is a single-function command and dispatches `--help`
# through the global `show_help` flow in `pyve.sh`.
#============================================================

run_command() {
    if [[ $# -lt 1 ]]; then
        log_error "No command provided to run"
        log_error "Usage: pyve run <command> [args...]"
        log_error "Example: pyve run python --version"
        exit 1
    fi

    # Detect active backend. Authoritative source is the manifest's root
    # `backend`; the directory heuristic is only a fallback for bare
    # projects with no manifest. With the v3 state layout, the
    # `.pyve/envs/*` glob also matches testenvs (e.g. .pyve/envs/testenv/),
    # so the older "any child under .pyve/envs/ means micromamba" rule
    # would mis-route every venv-backed project that has a testenv to the
    # micromamba branch — and within micromamba projects, mis-route the
    # main env to whichever sibling sorted first alphabetically.
    local backend=""
    local venv_dir="$DEFAULT_VENV_DIR"
    local mm_env_name=""

    # Backend from the manifest (the env_name resolve is inert on a v3-native
    # project otherwise).
    backend="$(manifest_get_backend root 2>/dev/null || printf '')"
    if [[ "$backend" == "micromamba" ]]; then
        mm_env_name="$(resolve_micromamba_env_name 2>/dev/null || printf '')"
    fi

    # Fallback for bare projects (no manifest): prefer the
    # explicit `.venv/` signal; otherwise look for a single-tenant
    # `.pyve/envs/<name>/` (pre-N.f micromamba layout).
    if [[ -z "$backend" ]]; then
        if [[ -d "$venv_dir" ]]; then
            backend="venv"
        elif [[ -d ".pyve/envs" ]]; then
            local env_dirs=(.pyve/envs/*)
            if [[ -d "${env_dirs[0]:-}" ]] && [[ "${env_dirs[0]}" != ".pyve/envs/*" ]]; then
                backend="micromamba"
                mm_env_name="$(basename "${env_dirs[0]}")"
            fi
        fi
    fi

    # Error if no environment found
    if [[ -z "$backend" ]]; then
        log_error "No Python environment found"
        log_error "Run 'pyve init' to create an environment first"
        exit 1
    fi

    # Story J.c: defense-in-depth asdf reshim guard. The .envrc block
    # added in J.b covers the direnv-allow path; this covers `pyve run`
    # used with --no-direnv, or in CI where .envrc is never sourced.
    # Probe the version manager silently — real setup errors would have
    # surfaced during `pyve init`, and noise on every `pyve run` would
    # be unpleasant. Export (vs `env VAR=...` prefix) because exec
    # replaces the shell anyway, so parent-env pollution is moot.
    source_shell_profiles >/dev/null 2>&1 || true
    detect_version_manager >/dev/null 2>&1 || true
    if is_asdf_active; then
        export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
    fi

    # Execute command based on backend
    if [[ "$backend" == "venv" ]]; then
        # Venv backend: prefer venv bin, but allow system commands too
        local cmd="$1"
        shift

        local venv_bin="$venv_dir/bin"
        local cmd_path="$venv_bin/$cmd"

        if [[ -x "$cmd_path" ]]; then
            exec "$cmd_path" "$@"
        fi

        export VIRTUAL_ENV="$PWD/$venv_dir"
        export PATH="$venv_bin:$PATH"
        exec "$cmd" "$@"

    elif [[ "$backend" == "micromamba" ]]; then
        # Micromamba backend: use micromamba run

        # Get micromamba path
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -z "$micromamba_path" ]]; then
            log_error "Micromamba not found"
            exit 1
        fi

        # Identify the micromamba main env. mm_env_name was set above from
        # `resolve_micromamba_env_name` (environment.yml `name:`), or for bare
        # projects with no manifest, from the sole .pyve/envs/* entry.
        if [[ -z "$mm_env_name" ]]; then
            log_error "Micromamba env_name not found (set 'name:' in environment.yml)"
            exit 1
        fi
        # v3 root slot (Story N.bf.14), tolerant of a not-yet-moved flat
        # env (and of the no-config legacy fallback that set mm_env_name
        # from the sole .pyve/envs/* entry).
        local env_path
        env_path="$(resolve_main_micromamba_path "$mm_env_name")"
        if [[ ! -d "$env_path" ]]; then
            log_error "Micromamba environment not found at $env_path"
            exit 1
        fi

        # Execute command using micromamba run
        exec "$micromamba_path" run -p "$env_path" "$@"
    fi
}

#============================================================
# pyve test — run pytest via the dev/test runner environment
#
# Auto-creates the testenv (`.pyve/envs/testenv/venv`) if missing, then
# auto-installs pytest in CI / under PYVE_TEST_AUTO_INSTALL_PYTEST=1
# (or prompts the user when stdin is a TTY), and finally exec()s
# pytest with the user's args. Pytest's exit code propagates via
# exec.
#
# Function-name note: this function is named `test_tests` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve test [args]` runs the project's tests, whether the
# args explicitly select a subset or are absent (implicitly all).
# This naming also avoids the F-11 `test` shadowing trap (`test`
# is a bash builtin / `/usr/bin/test`).
#
# Cross-command callsite: the `--env root` short-circuit below
# routes pytest through `run_command` (relocated above in this
# file). Both functions live in this file; bash resolves the call
# via the global function table.
#============================================================

# Test-private helper: probe whether the testenv has pytest installed.
# Returns 0 (yes) or 1 (no/missing-python).
_test_has_pytest() {
    local testenv_venv="$1"
    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        return 1
    fi
    "$testenv_venv/bin/python" -c "import pytest" >/dev/null 2>&1
}

# Probe whether `<name>` has pytest importable. Drives the silent-skip
# advisory on `pyve test --env <X>`: if any env *other* than the
# targeted one has pytest, that env is a candidate the user may have
# meant — tests that `importorskip` its stack silently SKIP in the
# targeted env and look green.
#
# Every name — `root` included — resolves through the canonical
# backend-aware `resolve_env_path` (venv root → `.venv`; micromamba
# root → the `.pyve/envs/root/conda` slot; named envs →
# `.pyve/envs/<name>/{venv|conda}`) and probes the env's `bin/python`.
# Returns 0 (env has pytest importable) / 1 (no env / no pytest /
# probe failure).
_test_env_has_pytest() {
    local env_name="$1"
    local env_path py
    env_path="$(resolve_env_path "$env_name" 2>/dev/null)" || return 1
    py="$env_path/bin/python"
    [[ -x "$py" ]] || return 1
    "$py" -c "import pytest" >/dev/null 2>&1
}

# Test-private helper: install pytest into the testenv. If
# `requirements-dev.txt` is present, prefer installing from it.
_test_install_pytest_into_testenv() {
    local testenv_venv="$1"
    local requirements_file=""

    if [[ -f "requirements-dev.txt" ]]; then
        requirements_file="requirements-dev.txt"
    fi

    info "Installing pytest into dev/test runner environment..."
    if [[ -n "$requirements_file" ]]; then
        run_cmd "$testenv_venv/bin/python" -m pip install -r "$requirements_file"
    else
        run_cmd "$testenv_venv/bin/python" -m pip install pytest
    fi
    success "pytest installed"
}

# Public: pyve test [pytest args...]
test_tests() {
    # Parse the pyve-owned `--env <name>` selector out of the arg list;
    # everything else passes through to pytest verbatim.
    #
    # Story M.m: `<name>` is no longer limited to `root` / `testenv`.
    # Any name declared in `[tool.pyve.testenvs]` is accepted; absent
    # `--env` defaults to `[tool.pyve.testenvs].default` (fallback:
    # `testenv`). Resolver rules below.
    #
    # Story M.r: `<name>` may also be a comma-separated list of names
    # (`--env a,b,c`). With a single name (no comma), the M.m exec path
    # is preserved verbatim. With multiple names, each is run in a
    # subshell sequentially; exit code is the worst-case aggregate;
    # each env's output is preceded by `=== Env: <name> ===`.
    local env_csv=""
    local env_target_explicit=0
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                env_csv="${2:-}"
                env_target_explicit=1
                shift 2 || { log_error "--env requires a value (a declared env name, or 'root')"; exit 1; }
                ;;
            --env=*)
                env_csv="${1#--env=}"
                env_target_explicit=1
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # Story M.r: split CSV into a list. A single name (no comma)
    # produces a 1-element list; downstream single-vs-matrix dispatch
    # branches on `${#env_targets[@]}`.
    local -a env_targets=()
    if [[ -n "$env_csv" ]]; then
        IFS=',' read -r -a env_targets <<< "$env_csv"
    fi

    # Matrix path: ≥2 declared envs. Each runs in a subshell so an
    # `exit` (or `exec`) inside a per-env run terminates only that
    # subshell; iteration continues. Exit code aggregates worst-case
    # (highest failing rc).
    if [[ "${#env_targets[@]}" -ge 2 ]]; then
        local rc=0
        local one
        for one in "${env_targets[@]}"; do
            printf '\n=== Env: %s ===\n' "$one"
            # Suppress the M.o silent-skip advisory in matrix mode:
            # the user is explicitly running multiple envs, so the
            # cross-env "you might have meant X" hint is noise. The
            # subshell scoping is intentional (the export does NOT
            # leak to test_tests' caller).
            # shellcheck disable=SC2030
            (
                export PYVE_NO_TESTENV_ADVISORY=1
                _test_run_one_env "$one" 1 "${args[@]+"${args[@]}"}"
            )
            local sub_rc=$?
            [[ $sub_rc -gt $rc ]] && rc=$sub_rc
        done
        exit $rc
    fi

    # Single-env path (no comma): preserve the M.m exec contract.
    local env_target="${env_targets[0]:-}"
    _test_run_one_env "$env_target" "$env_target_explicit" "${args[@]+"${args[@]}"}"
}

# Story M.r: extracted from `test_tests` so the matrix loop can call
# the per-env logic inside a subshell without losing the M.m exec
# behavior on the single-env path. Signature:
#
#   _test_run_one_env <name> <explicit> [pytest args...]
#
# `<name>` may be empty (use the declared default); `<explicit>` is
# "1" when the caller passed `--env` (single-env or matrix; matrix
# always passes 1) and "0" only when single-env had no `--env` at all.
#
# Behavior is identical to pre-M.r `test_tests`: legacy-value catch,
# `root` short-circuit to `run_command`, name validation, conda gate,
# lazy auto-provision (M.n), pytest install prompt, silent-skip
# advisory (M.o), `last_used_at` touch (M.m), then `exec pytest`.
# Returns only on error paths (the success tail execs).

# Resolve the test env `pyve test` targets when no `--env` is given. An
# explicit `default = true` always wins. Otherwise autowire only when the
# project is unambiguous: the root is a Python backend (venv/micromamba), the
# declared env collection is homogeneous in backend, AND exactly one test env
# is declared — then promote that sole test env. A mixed-backend collection,
# multiple test envs without a default, or a non-Python/`none` root yields no
# default (the caller then requires an explicit `--env`). Prints the env name,
# or nothing. No heuristics under ambiguity — we never guess a default.
_test_default_env() {
    # read_env_config populates BOTH the manifest arrays (PYVE_ENV_*, for
    # list/default/purpose) and the lifecycle arrays (PYVE_TESTENV_*, which
    # _env_resolve_backend reads) — manifest_load alone leaves the latter empty,
    # so a no-backend testenv would mis-resolve to the venv default.
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi
    local -a envs=() test_envs=()
    local env
    while IFS= read -r env; do
        [[ -n "$env" ]] && envs+=("$env")
    done < <(manifest_list_envs 2>/dev/null)

    if [[ "${#envs[@]}" -gt 0 ]]; then
        # 1. Explicit default wins.
        for env in "${envs[@]}"; do
            if manifest_is_default "$env" 2>/dev/null; then
                printf '%s' "$env"
                return 0
            fi
        done

        # 2. Autowire a sole test env on a homogeneous, Python-rooted project.
        local root_be be homogeneous=1
        root_be="$(_env_resolve_root_backend 2>/dev/null || printf 'venv')"
        for env in "${envs[@]}"; do
            if [[ "$env" == "root" ]]; then
                be="$root_be"
            else
                be="$(_env_resolve_backend "$env" 2>/dev/null)" || be="venv"
            fi
            [[ "$be" != "$root_be" ]] && homogeneous=0
            [[ "$(manifest_resolve_purpose "$env" 2>/dev/null)" == "test" ]] && test_envs+=("$env")
        done

        if [[ "$homogeneous" == "1" ]] \
           && [[ "${#test_envs[@]}" -eq 1 ]] \
           && { [[ "$root_be" == "venv" ]] || [[ "$root_be" == "micromamba" ]]; }; then
            printf '%s' "${test_envs[0]}"
            return 0
        fi
    fi

    # 3. Reserved/implicit `testenv` fallback: a bare project (no manifest)
    # where read_env_config synthesized the conventional single `testenv`.
    # Fires only when the manifest declared NO test env of its own — a
    # manifest that omits testenv on purpose leaves PYVE_TESTENVS_DEFAULT
    # empty and gets no magic default (it must declare one or pass --env).
    if [[ "${#test_envs[@]}" -eq 0 ]] && [[ "${PYVE_TESTENVS_DEFAULT:-}" == "testenv" ]]; then
        printf '%s' "testenv"
    fi
    return 0
}

_test_run_one_env() {
    local env_target="$1"
    local env_target_explicit="$2"
    shift 2 || true
    local -a args=("$@")

    # Category-B hard-error: `--env main` was renamed to `--env root` in
    # v2.7.1 (M.e). Catch the legacy value with a precise migration hint
    # rather than silently delegating (no Category-A).
    if [[ "$env_target" == "main" ]]; then
        log_error "pyve test --env main: renamed to --env root. Run 'pyve test --env root' instead."
        exit 1
    fi

    # `--env root`: route pytest to the ROOT project env. Delegates to
    # run_command, which owns backend detection (venv vs micromamba),
    # the asdf reshim guard, and the exec. This is the first-class form
    # of the `pyve run python -m pytest` workaround for bundled envs
    # that carry both pytest and the stack-under-test in the root env.
    if [[ "$env_target" == "root" ]]; then
        run_command python -m pytest "${args[@]+"${args[@]}"}"
        return  # not reached: run_command execs
    fi

    # Story M.m: load named-env config so we can validate the target
    # name and pick the declared default when `--env` is absent.
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi

    if [[ "$env_target_explicit" == "0" ]]; then
        # No --env: resolve the default test env (explicit `default = true`,
        # or a sole test env auto-promoted on a homogeneous Python-rooted
        # project). No unambiguous default → require an explicit --env rather
        # than guessing.
        env_target="$(_test_default_env)"
        if [[ -z "$env_target" ]]; then
            log_error "pyve test: no default test env to run."
            log_error "Declare 'default = true' on a test env in pyve.toml, or pass --env <name>."
            local _te
            while IFS= read -r _te; do
                [[ -z "$_te" ]] && continue
                [[ "$(manifest_resolve_purpose "$_te" 2>/dev/null)" == "test" ]] && log_error "  --env $_te"
            done < <(manifest_list_envs 2>/dev/null)
            exit 1
        fi
    fi

    # Validate the target name. Accept the reserved `testenv` and any
    # declared name; reject everything else with the list of valid
    # choices.
    if [[ "$env_target" != "testenv" ]] && ! is_env_declared "$env_target"; then
        log_error "Invalid --env value: '$env_target' is not a declared testenv"
        log_error "Valid choices:"
        local choice
        for choice in root testenv $( { list_env_names | grep -vE '^(root|testenv)$'; } 2>/dev/null ); do
            log_error "  $choice"
        done
        exit 1
    fi

    # purpose gate. `pyve test --env <name>` is reserved
    # for envs with `purpose = "test"` (declared in pyve.toml, or
    # implied by the name-based default rule in
    # `lib/manifest.sh::manifest_resolve_purpose`). Non-test envs hard-
    # error with a precise hint at the right invocation form.
    #
    # The shim that propagates `purpose = "test"` from v2-source
    # `[tool.pyve.testenvs.<name>]` blocks is not yet implemented; until
    # then, v2-only selector paths are intentionally broken (test-suite
    # coverage carries `N.i-pending` skip markers — see the audit in
    # `tests/unit/test_test_env_resolver.bats`'s setup).
    if [[ -f pyve.toml ]]; then
        manifest_load
    fi
    local resolved_purpose
    resolved_purpose="$(manifest_resolve_purpose "$env_target")"
    if [[ "$resolved_purpose" != "test" ]]; then
        log_error "Env '$env_target' has purpose '$resolved_purpose'; 'pyve test' is reserved for purpose='test' envs."
        log_error "Use 'pyve env run $env_target -- <command>' to invoke a command in this env."
        exit 1
    fi

    local testenv_venv
    testenv_venv="$(resolve_env_path "$env_target")"

    # Story M.n: lazy envs that have not been provisioned yet are
    # auto-provisioned on first targeted use — ensure_env_exists
    # creates the venv, then `_env_install_with_lock` installs
    # per the env's declared sources (M.l). The whole thing is gated
    # by PYVE_NO_AUTO_PROVISION=1 for strict CI that wants the M.m
    # "is this env already built?" semantics.
    local was_lazy_unprovisioned=0
    if is_env_lazy "$env_target" && [[ ! -x "$testenv_venv/bin/python" ]]; then
        if [[ "${PYVE_NO_AUTO_PROVISION:-0}" == "1" ]]; then
            log_error "Testenv '$env_target' is declared lazy and has not been provisioned yet."
            log_error "PYVE_NO_AUTO_PROVISION=1 is set — refusing to auto-provision."
            log_error "Run: pyve env install $env_target"
            exit 1
        fi
        info "Lazy testenv '$env_target' not yet provisioned — auto-provisioning..."
        was_lazy_unprovisioned=1
    fi

    ensure_env_exists "$env_target"

    if [[ "$was_lazy_unprovisioned" == "1" ]]; then
        if ! _env_install_with_lock "$env_target" "$testenv_venv" "" "wait"; then
            log_error "Auto-provisioning failed for '$env_target'"
            exit 1
        fi
    fi

    if ! _test_has_pytest "$testenv_venv"; then
        local auto_install=false
        if [[ -n "${CI:-}" ]] || [[ "$PYVE_TEST_AUTO_INSTALL_PYTEST_DEFAULT" == "1" ]]; then
            auto_install=true
        fi

        if [[ "$auto_install" == true ]]; then
            _test_install_pytest_into_testenv "$testenv_venv"
        else
            if [[ -t 0 ]]; then
                printf "pytest is not installed in the dev/test runner environment. Install now? [y/N]: "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    _test_install_pytest_into_testenv "$testenv_venv"
                else
                    log_info "Install skipped. You can install with: pyve env install -r requirements-dev.txt"
                    exit 1
                fi
            else
                log_error "pytest is not installed in the dev/test runner environment."
                log_error "Run: pyve env install -r requirements-dev.txt"
                exit 1
            fi
        fi
    fi

    # Silent-skip trap guard: if any env OTHER than the one we're
    # targeting has pytest importable, that env is a candidate the user
    # may have meant — tests that `importorskip` the alternative env's
    # stack will silently SKIP in the targeted env and look green. Warn,
    # list the alternatives, point at the supported escape hatch. One
    # line, non-fatal. Suppressible two ways, either suffices:
    #   1. PYVE_NO_TESTENV_ADVISORY=1 — the per-shell one-off/CI
    #      override (matrix mode sets it inside its per-env subshell);
    #   2. the targeted env declares `isolated = true` in pyve.toml —
    #      the project-scoped, reviewable opt-out for projects that run
    #      multiple deliberately-isolated test envs.
    # The manifest flag is target-side only: a marked env still appears
    # as a candidate when another (unmarked) env is targeted, so the
    # advisory keeps its value for the catch-all testenv.
    # shellcheck disable=SC2031
    if [[ "${PYVE_NO_TESTENV_ADVISORY:-0}" != "1" ]] \
        && ! manifest_is_isolated "$env_target" 2>/dev/null; then
        local -a advisory_envs=()
        local probe
        # Candidates: root + every declared name (M.o). Skip the
        # target env itself — we're already routing there.
        for probe in root $({ list_env_names; } 2>/dev/null); do
            [[ "$probe" == "$env_target" ]] && continue
            if _test_env_has_pytest "$probe"; then
                advisory_envs+=("$probe")
            fi
        done
        if [[ "${#advisory_envs[@]}" -gt 0 ]]; then
            local rendered=""
            local e
            for e in "${advisory_envs[@]}"; do
                rendered+="--env $e, "
            done
            rendered="${rendered%, }"
            warn "Targeted env '$env_target' may be missing dependencies from other env(s) that also have pytest installed: ${advisory_envs[*]}"
            info "If your tests need a different env's stack, try one of: $rendered"
        fi
    fi

    # Story M.m: touch `.state`'s `last_used_at` before exec so M.p's
    # `pyve testenv list` / `prune` can report which envs are active.
    # Best-effort: silent no-op when `.state` is missing (e.g. an env
    # provisioned before M.m landed `.state` writes in
    # `ensure_env_exists`). Suppress stdout/stderr — the touch
    # is bookkeeping, not user-facing.
    state_touch_last_used "$env_target" >/dev/null 2>&1 || true

    # Backend dispatch (mirrors `pyve env run`): venv execs the env's python
    # directly; micromamba routes through `micromamba run -p` so CONDA_PREFIX /
    # activate.d / conda lib paths are set up (compiled deps depend on them).
    local test_backend
    test_backend="$(_env_resolve_backend "$env_target")" || test_backend="venv"
    if [[ "$test_backend" == "micromamba" ]]; then
        env_exec_conda "$testenv_venv" python -m pytest "${args[@]+"${args[@]}"}"
    else
        exec "$testenv_venv/bin/python" -m pytest "${args[@]+"${args[@]}"}"
    fi
}
