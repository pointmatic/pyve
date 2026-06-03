# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/python/plugin.sh — Python plugin (Story N.n)
#
# First reference implementation of the plugin contract from N.k.
# Re-seats the Python ecosystem behind the contract. This story
# implements three hooks plus the backend-provider activate shims
# absorbed from N.l's transition state:
#
#   python_pyve_plugin_manifest_namespace   — returns "python"
#   python_pyve_plugin_register_backends    — bp_register venv + micromamba
#   python_pyve_plugin_detect               — scaffold-time file-signal scan
#   venv_pyve_bp_activate                   — backend-provider activate shim
#   micromamba_pyve_bp_activate             — backend-provider activate shim
#
# Lifecycle hooks (init / purge / update / check / status / run /
# test) stay as no-op defaults from contract.sh in N.n; they land in
# Stories N.o (init/purge/update) and N.p (check/status/run/test).
# The activation hook proper (`.envrc` snippet composition) and the
# gitignore + smart-purge hooks land in N.q and N.r respectively.
#
# Detection contract (per Story N.n task list + spike):
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
# Backend-provider activate shims (absorbed from lib/commands/init.sh
# per N.n; previously written into init.sh as N.l transition state).
#
# The shims forward `bp_dispatch <backend> activate <env_path> <env_name>`
# to the existing `_init_direnv_*` helpers. The signature is unified
# across backends — venv ignores env_name (uses cwd basename via
# _init_direnv_venv); micromamba uses both.
#------------------------------------------------------------

venv_pyve_bp_activate() {
    _init_direnv_venv "$1"
}

micromamba_pyve_bp_activate() {
    _init_direnv_micromamba "$2" "$1"
}

#------------------------------------------------------------
# Plugin contract — lifecycle hooks (Story N.o, Option 2)
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
        # unregistered backends.
        if [[ -n "$backend" ]]; then
            if ! bp_lookup "$backend" >/dev/null 2>&1; then
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
# Plugin contract — runtime hooks (Story N.p, Option 2)
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

python_pyve_plugin_check() {
    _python_pyve_plugin_render_advisories
    check_environment "$@"
}

python_pyve_plugin_status() {
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
# Plugin contract — activate (Story N.q)
#
# Plugin-level activation: compose the plugin-owned `.envrc` snippet
# (the 5 lines the Python plugin contributes — PATH_add + four
# `export VAR=...` lines), run it through validate_envrc_snippet
# (Story N.m's PC-1 allow-list), then delegate the actual file write
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
# 4 exports). Output is byte-equivalent to the corresponding region
# of write_envrc_template's emission, modulo whitespace at the end.
# Mirrors write_envrc_template's `env_root_expr` rule: absolute paths
# pass through; relative paths get prefixed with `$PWD/`.
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
# Plugin contract — gitignore_entries (Story N.r)
#
# Returns the Python-ecosystem patterns the plugin contributes to
# `.gitignore`. Output flows through validate_gitignore_snippet
# (Story N.m PC-1 gate) before being written. Composer-owned lines
# (macOS `.DS_Store`, Pyve-managed `.pyve/envs`, the dynamic venv
# directory) stay in `write_gitignore_template` — same plugin-vs-
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
# Plugin contract — purge_inventory (Story N.r)
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
    cat <<'EOF'
created .venv
created .pyve/envs
created .envrc
authored pyproject.toml
authored requirements*.txt
authored setup.py
authored environment.yml
EOF
}

# Plugin activate hook. Unified signature across backends:
#   python_pyve_plugin_activate <backend> <env_path> <env_name>
#
# Compose → validate → delegate. On validation failure, aborts with
# non-zero exit and the offending line on stderr; no file write.
python_pyve_plugin_activate() {
    local backend="$1"
    local env_path="$2"
    local env_name="$3"

    case "$backend" in
        venv|micromamba) ;;
        *)
            log_error "python plugin: activate: unknown backend '$backend'"
            return 1
            ;;
    esac

    # PC-1 gate.
    local snippet
    snippet="$(_python_pyve_plugin_envrc_snippet "$backend" "$env_path" "$env_name")" || return $?
    if ! validate_envrc_snippet "$snippet"; then
        log_error "python plugin: activate: snippet failed PC-1 validation"
        return 1
    fi

    # Delegate the actual write to the backend-provider. bp_dispatch
    # routes to <backend>_pyve_bp_activate which calls today's
    # _init_direnv_* helpers in lib/commands/init.sh.
    bp_dispatch "$backend" activate "$env_path" "$env_name"
}

#------------------------------------------------------------
# `pyve python set` / `pyve python show` (Story N.p, Option (a))
#
# These are not standard plugin-contract hooks — they're
# Python-version-management commands that logically belong to the
# Python plugin. Moved here from lib/commands/python.sh; the
# `python_command` dispatcher there still calls them by name (bash
# function lookup is global). Behavior unchanged.
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
    local version="" source=""
    if [[ -f ".tool-versions" ]]; then
        version="$(grep "^python " .tool-versions 2>/dev/null | awk '{print $2}')"
        source=".tool-versions"
    elif [[ -f ".python-version" ]]; then
        version="$(cat .python-version 2>/dev/null | head -1)"
        source=".python-version"
    else
        version="$(read_config_value "python.version" 2>/dev/null || true)"
        source=".pyve/config"
    fi

    if [[ -z "$version" ]]; then
        printf "No Python version pinned in this project.\n"
        printf "  (not pinned — use 'pyve python set <version>' to pin one)\n"
        return 0
    fi
    printf "Python %s (from %s)\n" "$version" "$source"
}

#============================================================
# pyve init — initialize a Python virtual environment
# (Story N.s.1, Option 1 relocation from lib/commands/init.sh)
#
# Auto-detects backend (venv vs micromamba), resolves the version
# manager (asdf or pyenv), creates the environment, configures
# direnv (unless --no-direnv), writes .pyve/config, and runs the
# project-guide post-init hooks.
#
# Function-name note: this function is named `init_project` per the
# project-essentials "Function naming convention: verb_<operand>"
# rule — `pyve init` operates on the project (creates venv, writes
# .pyve/config, configures direnv, etc.).
#
# Cross-command callsite: `init_project --force` calls
# `purge_project --keep-testenv --yes` — both functions now live in
# this file (init_project relocated in N.s.1, purge_project in N.s.2).
# Bash resolves the call at runtime via the global function table.
#
# Init-private helpers (per project-essentials F): `_init_` prefix
# on all single-caller helpers. Includes
# `_init_run_project_guide_hooks` (per audit F-10) and the six
# config-writers (`_init_python_version`, `_init_venv`,
# `_init_direnv_venv`, `_init_direnv_micromamba`, `_init_dotenv`,
# `_init_gitignore`).
#============================================================

# Run the project-guide post-init hooks: install the package into the
# project env, then optionally add shell completion to the user rc file.
#
# Both steps are failure-non-fatal — pyve init continues even on errors.
# Respects CLI-flag overrides via the "mode" arguments (pre-resolved by
# init() from --project-guide / --no-project-guide and their completion
# siblings). When mode is empty, falls through to the env-var / CI /
# interactive logic inside the prompt helpers.
#
# Usage: _init_run_project_guide_hooks <backend> <env_path> <pg_mode> <comp_mode>
#   backend:   "venv" | "micromamba"
#   env_path:  path to the project environment
#   pg_mode:   "" | "yes" | "no"  (from --project-guide / --no-project-guide)
#   comp_mode: "" | "yes" | "no"  (from --project-guide-completion / etc.)
_init_run_project_guide_hooks() {
    local backend="$1"
    local env_path="$2"
    local pg_mode="$3"
    local comp_mode="$4"

    # Resolve CLI flag overrides into a tri-state.
    local should_install=0  # 0 = unknown (consult env vars / prompt), 1 = yes, 2 = no
    case "$pg_mode" in
        yes) should_install=1 ;;
        no)  should_install=2 ;;
    esac

    local should_add_completion=0
    case "$comp_mode" in
        yes) should_add_completion=1 ;;
        no)  should_add_completion=2 ;;
    esac

    #--- Install decision -------------------------------------------------
    # Priority order:
    #   1. --no-project-guide flag                  → skip silent
    #   2. --project-guide flag                     → install (overrides auto-skip)
    #   3. PYVE_NO_PROJECT_GUIDE=1 / PYVE_PROJECT_GUIDE=1 → handled by prompt_install_project_guide
    #   4. project-guide already in project deps    → AUTO-SKIP with INFO message
    #   5. CI / PYVE_FORCE_YES                      → install (CI default)
    #   6. interactive                              → prompt, default Y
    #---------------------------------------------------------------------
    if [[ $should_install -eq 2 ]]; then
        log_info "Skipping project-guide install (--no-project-guide)"
        return 0
    fi

    local do_install=false
    if [[ $should_install -eq 1 ]]; then
        do_install=true
    else
        # Auto-skip safety: if project-guide is already declared as a project
        # dependency, do not let pyve manage it. The user's pin wins; pyve's
        # install/upgrade would just create a version conflict at the next
        # `pip install -e .`.
        if project_guide_in_project_deps; then
            log_info "Detected 'project-guide' in your project dependencies."
            log_info "Pyve will not auto-install or run 'project-guide init' to avoid a version conflict."
            log_info "Project-guide will be installed when your project dependencies are installed."
            log_info "To override and let pyve manage it anyway, pass --project-guide."
            log_info "To suppress this message, pass --no-project-guide."
            return 0
        fi

        if prompt_install_project_guide; then
            do_install=true
        fi
    fi

    if [[ "$do_install" != true ]]; then
        return 0
    fi

    #--- Step 1: pip install --upgrade project-guide ----------------------
    install_project_guide "$backend" "$env_path" || true

    # If install actually failed, don't proceed to step 2 or 3 — running
    # `project-guide init` against a missing binary or adding a completion
    # eval for a missing tool would just leave dead state.
    if ! is_project_guide_installed "$backend" "$env_path"; then
        return 0
    fi

    #--- Step 2: scaffold or refresh managed artifacts --------------------
    # Branch on `.project-guide.yml` presence (Story G.h):
    #   - absent → first-time scaffolding: `project-guide init --no-input`
    #   - present → refresh: `project-guide update --no-input` — preserves
    #     user state (current_mode, overrides, test_first, pyve_version)
    #     and creates `.bak.<ts>` siblings for modified managed files.
    # Pyve never auto-runs `project-guide init --force` because it is
    # destructive (resets config, no backups); that remains user-initiated.
    if [[ -f ".project-guide.yml" ]]; then
        run_project_guide_update_in_env "$backend" "$env_path"
    else
        run_project_guide_init_in_env "$backend" "$env_path"
    fi

    #--- Step 3: shell completion wiring ----------------------------------
    if [[ $should_add_completion -eq 2 ]]; then
        log_info "Skipping project-guide completion wiring (--no-project-guide-completion)"
        return 0
    fi

    local do_completion=false
    if [[ $should_add_completion -eq 1 ]]; then
        do_completion=true
    elif prompt_install_project_guide_completion; then
        do_completion=true
    fi

    if [[ "$do_completion" != true ]]; then
        return 0
    fi

    local user_shell
    user_shell="$(detect_user_shell)"
    if [[ "$user_shell" == "unknown" ]]; then
        log_warning "Unknown shell — skipping project-guide completion wiring."
        log_warning "  For manual setup, add to your shell rc file:"
        log_warning "    eval \"\$(_PROJECT_GUIDE_COMPLETE=<shell>_source project-guide)\""
        return 0
    fi

    local rc_path
    rc_path="$(get_shell_rc_path "$user_shell")"
    if [[ -z "$rc_path" ]]; then
        log_warning "Could not determine rc file for shell '$user_shell' — skipping completion wiring"
        return 0
    fi

    if is_project_guide_completion_present "$rc_path"; then
        log_info "project-guide completion already present in $rc_path"
        return 0
    fi

    if add_project_guide_completion "$rc_path" "$user_shell"; then
        log_success "Added project-guide completion to $rc_path"
        log_info "  Reload your shell or run: source $rc_path"
    else
        log_warning "Failed to write project-guide completion to $rc_path (continuing)"
    fi
}

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

# Story N.e — emit the v3.0 canonical `pyve.toml` manifest at cwd.
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
# The `[env.testenv]` declaration matches today's two-env init shape:
# `pyve init` materializes the run env (`.venv/`) and `pyve testenv
# init` later materializes the test env. Declaring testenv here means
# `pyve test --env testenv` and other purpose-keyed selectors resolve
# correctly even before the testenv venv exists on disk.
_init_write_pyve_toml() {
    local project_name="$1"
    if [[ -f pyve.toml ]]; then
        return 0
    fi
    cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "${project_name}"

[env.root]
purpose = "utility"

[env.testenv]
purpose = "test"
default = true
EOF
}

# Story N.e — refresh-path guard. When `pyve.toml` exists, validate
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
    if ! manifest_load pyve.toml; then
        log_error "pyve.toml: invalid manifest (see error(s) above)"
        log_error "Fix the manifest and re-run, or remove pyve.toml to re-scaffold."
        return 1
    fi
    return 0
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

    # Prompt 1 — backend (Story L.k.3 + L.k.7 auto handling).
    # `--backend auto` is the explicit "let pyve detect" form; treat it
    # like the no-flag auto-detect path so the wizard resolves to a real
    # backend before downstream prompts (Python/project-guide) branch on
    # backend_flag. Without this, backend_flag stays "auto" through the
    # Python prompt, which would then fall to the venv branch and
    # hard-fail on no managers — even when env.yml says micromamba.
    if [[ -n "$arg_backend_flag" ]] && [[ "$arg_backend_flag" != "auto" ]]; then
        info "Backend: $arg_backend_flag (--backend)"
        backend_flag="$arg_backend_flag"
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

    # Prompt 2 — Python version pin (Story L.k.4). Backend-aware: venv pins
    # via asdf/pyenv writing .tool-versions / .python-version; micromamba
    # pins via the `python=X` line in environment.yml (the existing
    # scaffolder writes it later in the init flow).
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

    # Prompt 3 — project-guide install (Story L.k.5). Detection is keyed on
    # `.project-guide.yml` (the canonical install marker, matching what
    # `pyve update` already uses). Deps-managed signal (project-guide
    # declared in pyproject.toml / requirements.txt / environment.yml)
    # wins over the install-marker check — when the user manages
    # project-guide via project deps, pyve refuses to touch it to avoid
    # version-pin conflicts at the next `pip install -e .`.
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

init_project() {
    local venv_dir="$DEFAULT_VENV_DIR"
    local python_version="$DEFAULT_PYTHON_VERSION"
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
            --force)
                PYVE_REINIT_MODE="force"
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
                unknown_flag_error "init" "$1" \
                    --python-version --backend --auto-bootstrap --bootstrap-to \
                    --strict --no-lock --env-name --no-direnv --auto-install-deps \
                    --no-install-deps --local-env --force --allow-synced-dir \
                    --project-guide --no-project-guide \
                    --project-guide-completion --no-project-guide-completion \
                    --help
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done

    # Story N.e — refresh-path guard. If `pyve.toml` exists, validate
    # it before doing any work; surface helper errors and abort on
    # malformed schema / unknown purpose / etc. Absent manifest is a
    # silent no-op (the fresh-init path falls through to the writer
    # at the end). Runs before the wizard so an invalid manifest
    # short-circuits without prompting the user.
    if ! _init_validate_existing_manifest; then
        exit 1
    fi

    _init_wizard "$backend_flag" "$python_version" "$python_version_supplied" "$project_guide_mode"

    # Refuse to initialize inside a cloud-synced directory (use --allow-synced-dir to override)
    check_cloud_sync_path

    # Check for existing installation (re-initialization detection)
    if config_file_exists; then
        local existing_backend
        existing_backend="$(read_config_value "backend")"
        local existing_version
        existing_version="$(read_config_value "pyve_version")"

        # Handle re-initialization based on mode.
        # (PYVE_REINIT_MODE="update" path removed in v2.0 / H.e.9 —
        # `pyve update` is the new entry point.)
        if [[ "${PYVE_REINIT_MODE:-}" == "force" ]]; then
            # Force re-initialization mode
            warn "Force re-initialization: this will purge the existing environment ($existing_backend)"

            # Run pre-flight checks BEFORE purging so the environment is still intact
            # if the user decides to abort or a check fails.
            # We capture the backend here and reuse it in the main flow to avoid
            # prompting the user twice in the ambiguous case (env.yml + pyproject.toml).
            # skip_config=true: --force is a clean slate — the config records the OLD
            # backend and must not prevent re-detection from project files.
            preflight_backend="$(get_backend_priority "$backend_flag" "true")"
            if [[ "$preflight_backend" == "micromamba" ]]; then
                # Mirror the non-force flow (see the main micromamba branch below):
                # scaffold a starter environment.yml on a fresh dir BEFORE lock
                # validation, otherwise validate_lock_file_status's "neither file"
                # case fires and aborts the switch on projects that the non-force
                # path handles fine.
                if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode"; then
                    info "Scaffolded starter environment.yml (python=$python_version)"
                    info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
                    export PYVE_NO_LOCK=1
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
                info "Purge:   existing $existing_backend environment"
                info "Rebuild: fresh $preflight_backend environment"
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

        else
            # Interactive mode (no flag specified)
            warn "Project already initialized with Pyve"
            if [[ -n "$existing_version" ]]; then
                info "Recorded version: $existing_version"
            fi
            info "Current version:  $VERSION"
            info "Backend:          $existing_backend"
            printf "\n  What would you like to do?\n"
            printf "    1. Update in-place (preserves environment, updates config)\n"
            printf "    2. Purge and re-initialize (clean slate)\n"
            printf "    3. Cancel\n\n"
            printf "  %sChoose [1/2/3]:%s " "${Y}" "${RESET}"
            read -r choice

            case "$choice" in
                1)
                    # Check for conflicts before updating
                    if [[ -n "$backend_flag" ]] && [[ "$backend_flag" != "$existing_backend" ]]; then
                        warn "Cannot update in-place: backend change detected ($existing_backend → $backend_flag)"
                        fail "Use option 2 to purge and re-initialize with new backend"
                    fi

                    # Perform safe update
                    if ! update_config_version; then
                        fail "Failed to update configuration (config may be corrupted)"
                    fi
                    success "Configuration updated"
                    if [[ -n "$existing_version" ]]; then
                        info "Version: $existing_version → $VERSION"
                    else
                        info "Version: (not recorded) → $VERSION"
                    fi
                    info "Backend: $existing_backend (unchanged)"
                    info "Project updated to Pyve v$VERSION"

                    # If the environment directory is missing (e.g. freshly cloned repo
                    # where .venv is gitignored), fall through to create it.
                    local _interactive_env_missing=false
                    if [[ "$existing_backend" == "venv" ]]; then
                        local _interactive_venv_dir
                        _interactive_venv_dir="$(read_config_value "venv.directory")"
                        _interactive_venv_dir="${_interactive_venv_dir:-$DEFAULT_VENV_DIR}"
                        if [[ ! -d "$_interactive_venv_dir" ]]; then
                            info "Environment directory '$_interactive_venv_dir' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    elif [[ "$existing_backend" == "micromamba" ]]; then
                        local _interactive_env_name
                        _interactive_env_name="$(read_config_value "micromamba.env_name")"
                        if [[ -n "$_interactive_env_name" ]] && [[ ! -d ".pyve/envs/$_interactive_env_name" ]]; then
                            info "Environment '.pyve/envs/$_interactive_env_name' not found — creating it now..."
                            _interactive_env_missing=true
                        fi
                    fi
                    if [[ "$_interactive_env_missing" == false ]]; then
                        footer_box
                        return 0
                    fi
                    # Fall through to environment creation below.
                    ;;
                2)
                    # Purge and continue
                    banner "Purging existing environment"
                    purge_project --keep-testenv --yes
                    success "Environment purged"
                    banner "Rebuilding fresh environment"
                    ;;
                3)
                    info "Initialization cancelled"
                    exit 0
                    ;;
                *)
                    fail "Invalid choice: $choice"
                    ;;
            esac
        fi
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
        if scaffold_starter_environment_yml "$python_version" "$env_name_flag" "$strict_mode"; then
            info "Scaffolded starter environment.yml (python=$python_version)"
            info "Edit environment.yml to add dependencies, then run 'pyve lock' when ready."
            # No conda-lock.yml yet (we just generated the source file).
            # Take validate_lock_file_status's existing bypass so init
            # proceeds without insisting on a lock that can't yet exist.
            export PYVE_NO_LOCK=1
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
        env_file="$(detect_environment_file)"
        info "Using file:      $env_file"

        if ! create_micromamba_env "$env_name" "$env_file"; then
            exit 1
        fi

        # Verify environment
        if ! verify_micromamba_env "$env_name"; then
            warn "Environment created but verification failed"
        fi

        # Apply Python 3.12+ distutils shim if needed
        local env_prefix
        env_prefix=".pyve/envs/$env_name"
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -n "$micromamba_path" ]]; then
            pyve_install_distutils_shim_for_micromamba_prefix "$micromamba_path" "$env_prefix"
        fi

        # Configure direnv for micromamba (unless --no-direnv).
        # Story N.l: dispatch through bp_dispatch so the activation
        # path is uniform across backends.
        local env_path=".pyve/envs/$env_name"
        if [[ "$no_direnv" == false ]]; then
            # Story N.q: route through plugin_dispatch so PC-1 validation
            # runs on the plugin-owned snippet before write.
            plugin_dispatch python activate micromamba "$env_path" "$env_name"
        else
            info "Skipping .envrc creation (--no-direnv)"
        fi

        # Create .env file
        _init_dotenv "$use_local_env"

        # Update .gitignore — since H.e.2a the template bakes in every
        # pyve-managed ignore pattern (.pyve/envs, .pyve/testenvs, .envrc,
        # .env, .vscode/settings.json), so the micromamba path needs no
        # per-backend dynamic inserts.
        write_gitignore_template

        success "Updated .gitignore"

        # Create .pyve/config with version tracking
        mkdir -p .pyve
        cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: micromamba
micromamba:
  env_name: $env_name
EOF
        success "Created .pyve/config"

        # Story N.e — write the v3.0 canonical manifest. No-op if it
        # already exists (refresh path). `.pyve/config` continues to
        # be written above; the YAML removal lands in Story N.i with
        # the read-compat sweep.
        if [[ ! -f pyve.toml ]]; then
            _init_write_pyve_toml "$(basename "$(pwd)")"
            success "Created pyve.toml"
        fi

        # Generate .vscode/settings.json so IDEs use the correct interpreter
        write_vscode_settings "$env_name"

        info "Environment location: $env_path"

        # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
        prompt_install_pip_dependencies "micromamba" "$env_path"

        # project-guide hook (Story G.c / FR-G2)
        _init_run_project_guide_hooks "micromamba" "$env_path" \
            "$project_guide_mode" "$project_guide_completion_mode"

        _init_print_next_steps "micromamba" "$no_direnv" "$env_path"
        footer_box

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

    # Detect and validate version manager
    if ! detect_version_manager; then
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

    # Apply Python 3.12+ distutils shim if needed
    if [[ -x "$venv_dir/bin/python" ]]; then
        pyve_install_distutils_shim_for_python "$venv_dir/bin/python"
    fi

    # Configure direnv (unless --no-direnv).
    # Story N.l: dispatch through bp_dispatch so the activation path
    # is uniform across backends.
    if [[ "$no_direnv" == false ]]; then
        local _venv_project_name
        _venv_project_name="$(basename "$(pwd)")"
        # Story N.q: route through plugin_dispatch so PC-1 validation
        # runs on the plugin-owned snippet before write.
        plugin_dispatch python activate venv "$venv_dir" "$_venv_project_name"
    else
        info "Skipping .envrc creation (--no-direnv)"
    fi

    # Create .env file
    _init_dotenv "$use_local_env"

    # Update .gitignore
    _init_gitignore "$venv_dir"

    # Create .pyve/config with version tracking
    mkdir -p .pyve
    cat > .pyve/config << EOF
pyve_version: "$VERSION"
backend: venv
venv:
  directory: $venv_dir
python:
  version: $python_version
EOF
    success "Created .pyve/config"

    # Story N.e — write the v3.0 canonical manifest. No-op if it
    # already exists (refresh path). `.pyve/config` continues to
    # be written above; the YAML removal lands in Story N.i with
    # the read-compat sweep.
    if [[ ! -f pyve.toml ]]; then
        _init_write_pyve_toml "$(basename "$(pwd)")"
        success "Created pyve.toml"
    fi

    # Ensure dev/test runner environment exists (upgrade-friendly)
    ensure_env_exists

    # Absolute venv path — used by both dep install and project-guide hooks
    local _venv_abs
    _venv_abs="$(cd "$venv_dir" && pwd)"

    # Prompt to install pip dependencies if pyproject.toml or requirements.txt exists
    prompt_install_pip_dependencies "venv" "$_venv_abs"

    # project-guide hook (Story G.c / FR-G2)
    _init_run_project_guide_hooks "venv" "$_venv_abs" \
        "$project_guide_mode" "$project_guide_completion_mode"

    _init_print_next_steps "venv" "$no_direnv" "$_venv_abs"
    footer_box
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
        # Story N.d.1: pre-flight check for the asdf/pyenv shim trap.
        # Same wire-in pattern as `ensure_env_exists`'s testenv venv
        # creation — placed after the banner so the user sees the
        # intent, then a pyve-owned error if `python` would fail.
        assert_python_resolvable || return 1
        run_cmd python -m venv "$venv_dir"
        success "Created virtual environment"
    fi
}

_init_direnv_venv() {
    local venv_dir="$1"
    local project_name
    project_name="$(basename "$(pwd)")"

    write_envrc_template "$venv_dir/bin" "VIRTUAL_ENV" "$venv_dir" "venv" "$project_name"
}

_init_direnv_micromamba() {
    local env_name="$1"
    local env_path="$2"

    write_envrc_template "$env_path/bin" "CONDA_PREFIX" "$env_path" "micromamba" "$env_name"
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

_init_gitignore() {
    local venv_dir="$1"
    local section="# Pyve virtual environment"

    # Rebuild .gitignore: Pyve-managed template at top, user entries below.
    # Since H.e.2a, the template bakes in .pyve/envs, .pyve/testenvs, .envrc,
    # .env, and .vscode/settings.json — the only pattern still inserted
    # dynamically is the user-overridable venv directory name.
    write_gitignore_template
    insert_pattern_in_gitignore_section "$venv_dir" "$section"

    success "Updated .gitignore"
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
#   - pyve testenv install -r requirements-dev.txt
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
        printf '  %d. pyve testenv install -r requirements-dev.txt\n' "$n"
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
  pyve init [<dir>] [options]

Arguments:
  <dir>                              Custom venv directory name (default: .venv)

Options:
  --python-version <ver>             Set Python version (e.g., 3.13.7)
  --backend <type>                   Backend to use: venv, micromamba, auto
  --auto-bootstrap                   Install micromamba without prompting (if needed)
  --bootstrap-to <location>          Where to install micromamba: project, user
  --strict                           Error on stale or missing lock files
  --no-lock                          Bypass missing conda-lock.yml error (not recommended)
  --env-name <name>                  Environment name (micromamba backend)
  --no-direnv                        Skip .envrc creation (for CI/CD)
  --auto-install-deps                Auto-install from pyproject.toml / requirements.txt
  --no-install-deps                  Skip dependency installation prompt (for CI/CD)
  --local-env                        Copy ~/.local/.env template
  --update                           Safely update an existing installation
  --force                            Purge and re-initialize (destructive)
  --allow-synced-dir                 Bypass cloud-sync directory check

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

  Note: pyve init --update does NOT run the project-guide hook (minimal-touch).

Examples:
  pyve init                                # Auto-detect backend, default venv
  pyve init myenv                          # Custom venv directory name
  pyve init --backend venv                 # Force venv backend
  pyve init --backend micromamba           # Force micromamba backend
  pyve init --python-version 3.13.7        # Pin Python version
  pyve init --no-direnv                    # Skip direnv (CI/CD)
  pyve init --force                        # Purge and rebuild
  pyve init --project-guide                # Install project-guide without prompting
  pyve init --no-project-guide             # Skip project-guide entirely

See `pyve --help` for the full command list.
EOF
}

#============================================================
# pyve purge — remove pyve-managed environment artifacts
# (Story N.s.2, Option 1 relocation from lib/commands/purge.sh)
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
    local venv_dir_explicit=false
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
                venv_dir="$1"
                venv_dir_explicit=true
                shift
                ;;
        esac
    done

    header_box "pyve purge"

    # Story N.r: pull the active plugin's purge_inventory as a data
    # interface. v3.0 reads the inventory for diagnostic / verbose
    # surfacing only — the actual removal calls below stay direct.
    # Future stories can extend the composer to consume the inventory
    # for path-level removal decisions; for now the seam is in place.
    if declare -F plugin_dispatch >/dev/null 2>&1; then
        local _plugin_inventory
        _plugin_inventory="$(plugin_dispatch python purge_inventory 2>/dev/null || true)"
        if [[ -n "${PYVE_VERBOSE:-}" ]] && [[ -n "$_plugin_inventory" ]]; then
            info "Plugin purge inventory (Story N.r):"
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

    # If a project config exists, prefer its venv directory when the user did not
    # explicitly pass a venv dir to purge.
    if [[ "$venv_dir_explicit" == false ]] && config_file_exists; then
        local configured_venv_dir
        configured_venv_dir="$(read_config_value "venv.directory" 2>/dev/null || true)"
        if [[ -n "$configured_venv_dir" ]]; then
            venv_dir="$configured_venv_dir"
        fi
    fi

    # Remove virtual environment
    _purge_venv "$venv_dir"

    # Remove .pyve directory (config and micromamba envs).
    # N.f: in v3 the named-env tree lives at `.pyve/envs/<name>/<backend>/`
    # and shares its parent with the micromamba main env (pre-N.g layout
    # at `.pyve/envs/<configured_name>/` — no /conda subdir). `--keep-testenv`
    # therefore preserves `.pyve/envs/` as a whole and surgically deletes
    # only the micromamba main-env subdir (identified from `.pyve/config`).
    # The legacy `.pyve/testenvs/` directory is also preserved defensively
    # in case the opportunistic migrator (`migrate_legacy_env_layout`)
    # hasn't run yet on a v2.8 project. Granular per-`purpose` preservation
    # is N.g's deterministic-migrator territory.
    if [[ "$keep_testenv" == true ]]; then
        if [[ -d ".pyve" ]]; then
            if [[ -d ".pyve/envs" ]] || [[ -d ".pyve/testenvs" ]]; then
                local main_env_subdir=""
                if [[ -f ".pyve/config" ]]; then
                    local cfg_backend
                    cfg_backend="$(read_config_value backend 2>/dev/null || true)"
                    if [[ "$cfg_backend" == "micromamba" ]]; then
                        main_env_subdir="$(read_config_value micromamba.env_name 2>/dev/null || true)"
                    fi
                fi
                rm -rf ".pyve/config" 2>/dev/null || true
                if [[ -n "$main_env_subdir" ]] && [[ -d ".pyve/envs/$main_env_subdir" ]]; then
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

    footer_box
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
                # Get environment name from config if it exists
                local env_name
                if config_file_exists; then
                    env_name="$(read_config_value "micromamba.env_name" 2>/dev/null || true)"
                fi

                # If we have an env name, try to remove it
                if [[ -n "$env_name" ]]; then
                    info "Removing micromamba environment '$env_name'..."
                    if "$micromamba_path" env remove -n "$env_name" -y 2>/dev/null; then
                        success "Removed micromamba environment '$env_name'"
                    else
                        # If named removal fails, try prefix-based removal
                        info "Named removal failed, trying prefix-based removal..."
                        "$micromamba_path" env remove -p ".pyve/envs/$env_name" -y 2>/dev/null || true
                    fi
                else
                    # No env name in config, try to find and remove any environments in .pyve/envs
                    for env_dir in .pyve/envs/*; do
                        if [[ -d "$env_dir" ]]; then
                            info "Removing micromamba environment at '$env_dir'..."
                            "$micromamba_path" env remove -p "$env_dir" -y 2>/dev/null || true
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
  pyve purge [<dir>] [options]

Arguments:
  <dir>                       Custom venv directory name (default: .venv)

Options:
  --keep-testenv              Preserve .pyve/envs/ (all dev/test runner envs)
  --yes, -y                   Skip the destructive-confirmation prompt.
                              Equivalent to setting CI=1 or PYVE_FORCE_YES=1.

Examples:
  pyve purge                               # Remove .pyve and the venv (prompts)
  pyve purge --yes                         # Remove without the prompt
  pyve purge --keep-testenv                # Preserve the testenv across purge
  pyve purge custom_venv                   # Remove a custom-named venv

See `pyve --help` for the full command list.
EOF
}

#============================================================
# pyve update — non-destructive upgrade (Story H.e.2)
# (Story N.s.3, Option 1 relocation from lib/commands/update.sh)
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
# rule — `pyve update` operates on the project (`.pyve/config`,
# `.gitignore`, `.vscode/settings.json`, project-guide scaffolding).
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

    # Sanity check: .pyve/config must exist. Without it we don't know the
    # backend or how to refresh anything.
    if ! config_file_exists; then
        log_error "pyve update requires an initialized project."
        log_error "No .pyve/config found. Run 'pyve init' first."
        exit 1
    fi

    local backend
    backend="$(read_config_value "backend")"
    if [[ -z "$backend" ]]; then
        log_error "Corrupt .pyve/config: missing 'backend' key."
        log_error "Run: pyve init --force"
        exit 1
    fi

    local previous_version
    previous_version="$(read_config_value "pyve_version")"

    # Pre-step: opportunistically migrate any v2.7 `.pyve/testenv/venv/`
    # or v2.8 `.pyve/testenvs/<name>/{venv,conda}/` layout to the v3
    # `.pyve/envs/<name>/{venv,conda}/` shape (Story N.f). Silent on
    # greenfield and on already-migrated projects; prints a one-line
    # info() per boundary when an actual move happens. M.h.3 wires this;
    # the helper lives in lib/envs.sh.
    _update_migrate_legacy_layout

    header_box "pyve update v$VERSION"

    # Step 1/4 — bump pyve_version in .pyve/config (idempotent; writes
    # even when already at current version, simplifying the happy path).
    local step1_label
    if [[ -z "$previous_version" ]]; then
        step1_label="[1/4] pyve_version: (not recorded) → $VERSION"
    elif [[ "$previous_version" == "$VERSION" ]]; then
        step1_label="[1/4] pyve_version: $VERSION (already current)"
    else
        step1_label="[1/4] pyve_version: $previous_version → $VERSION"
    fi
    step_begin "$step1_label"
    if ! update_config_version >/dev/null 2>&1; then
        step_end_fail
        log_error "Failed to update .pyve/config."
        exit 1
    fi
    step_end_ok

    # Step 2/4 — refresh Pyve-managed sections of .gitignore.
    step_begin "[2/4] Refresh .gitignore (Pyve-managed sections)"
    write_gitignore_template >/dev/null 2>&1
    step_end_ok

    # Step 3/4 — refresh .vscode/settings.json IF it already exists.
    # Never create — that's user opt-in at init time.
    if [[ -f ".vscode/settings.json" ]] && [[ "$backend" == "micromamba" ]]; then
        local env_name
        env_name="$(read_config_value "micromamba.env_name")"
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

    # Step 4/4 — refresh project-guide scaffolding if present and allowed.
    if [[ "$pg_mode" == "no" ]]; then
        step_begin "[4/4] project-guide refresh skipped (--no-project-guide)"
        step_end_ok
    elif [[ -f ".project-guide.yml" ]]; then
        local env_path=""
        if [[ "$backend" == "venv" ]]; then
            local venv_dir
            venv_dir="$(read_config_value "venv.directory")"
            venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
            env_path="$venv_dir"
        elif [[ "$backend" == "micromamba" ]]; then
            local env_name
            env_name="$(read_config_value "micromamba.env_name")"
            if [[ -n "$env_name" ]]; then
                env_path=".pyve/envs/$env_name"
            fi
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
    - pyve_version in .pyve/config
    - Pyve-managed sections of .gitignore
    - .vscode/settings.json (only if it already exists)
    - project-guide scaffolding (via 'project-guide update --no-input')

  Does NOT:
    - rebuild the virtual environment (use 'pyve init --force' for that)
    - create .env or .envrc (those are user state)
    - re-prompt for backend (the recorded backend is preserved)

Options:
  --no-project-guide          Skip the project-guide refresh step

Exit codes:
  0    Success (including no-op when already at current version).
  1    Failure (missing .pyve/config, corrupt config, unwritable files).

See also:
  pyve init --force          Destroy + rebuild the environment
  pyve --help                Full command list
EOF
}
