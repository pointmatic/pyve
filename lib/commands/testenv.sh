# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# pyve testenv — manage a dedicated dev/test runner environment
#
# Single-file namespace command (project-essentials F-9): one file
# contains the namespace dispatcher (`testenv_command`) and every
# leaf (`testenv_init`, `testenv_purge`, `testenv_run`) plus the
# backend-keyed install helpers (`_testenv_install_venv`,
# `_testenv_install_conda`).
#
# Sub-commands:
#   pyve testenv init                    Create .pyve/testenvs/testenv/venv
#   pyve testenv install [-r <file>]     Install pytest (or -r reqs)
#   pyve testenv purge                   Remove .pyve/testenv
#   pyve testenv run <cmd> [args...]     exec a command inside testenv
#
# This file is sourced by pyve.sh's library-loading block. It must
# not be executed directly — see the guard immediately below.
#============================================================

# Refuse direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

#------------------------------------------------------------
# Leaf: pyve testenv init [<name>]
#
# Story M.i.2: accepts an optional <name>. No arg defaults to the
# reserved `testenv`. Validation gates (M.i.1) live in the dispatcher
# so all leaves share one check; `testenv_init` just creates.
#------------------------------------------------------------

testenv_init() {
    local name="${1:-testenv}"
    ensure_testenv_exists "$name"
}

#------------------------------------------------------------
# Story M.l: venv-backed install with source dispatch.
#
# Renamed from `testenv_install` for symmetry with M.k's
# `_testenv_install_conda`. Pre-condition: the venv must already
# exist at `<env_path>`. Dispatches on the highest-precedence
# install source available (1 = top precedence):
#
#   1. CLI `-r <file>` (today's explicit-override behavior).
#   2. Declared `[tool.pyve.testenvs.<name>].requirements = ["a","b",...]`
#      → `pip install -r a -r b ...`.
#   3. Declared `[tool.pyve.testenvs.<name>].extra = "<extra>"`
#      → resolve `[project.optional-dependencies].<extra>` via the
#      Python helper, `pip install <pkg1> <pkg2> ...`.
#   4. Auto-detected `requirements-dev.txt` in CWD → `pip install -r requirements-dev.txt`.
#   5. Bare `pytest` fallback (pre-M.l default).
#
# Mutex enforcement (`requirements ⊕ extra ⊕ manifest`) lives in the
# M.g Python helper at config-read time, so by the time we get here
# at most one of (2) and (3) is non-empty.
#------------------------------------------------------------

_testenv_install_venv() {
    local name="$1"
    local env_path="$2"
    local cli_req_file="$3"

    if [[ ! -x "$env_path/bin/python" ]]; then
        log_error "Dev/test runner environment not initialized"
        log_error "Run: pyve testenv init $name"
        exit 1
    fi
    info "Installing dev/test dependencies into '$env_path'..."

    # Precedence 1: CLI `-r <file>` always wins.
    if [[ -n "$cli_req_file" ]]; then
        if [[ ! -f "$cli_req_file" ]]; then
            log_error "Requirements file not found: $cli_req_file"
            exit 1
        fi
        run_cmd "$env_path/bin/python" -m pip install -r "$cli_req_file"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 2: declared `requirements = [...]`.
    local -a declared_reqs=()
    _testenv_requirements_of "$name" declared_reqs 2>/dev/null || true
    if [[ "${#declared_reqs[@]}" -gt 0 ]]; then
        local r
        local -a r_args=()
        for r in "${declared_reqs[@]}"; do
            if [[ ! -f "$r" ]]; then
                log_error "Declared requirements file not found: $r"
                log_error "(declared as [tool.pyve.testenvs.$name].requirements)"
                exit 1
            fi
            r_args+=("-r" "$r")
        done
        run_cmd "$env_path/bin/python" -m pip install "${r_args[@]}"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 3: declared `extra = "<name>"`.
    local declared_extra
    declared_extra="$(_testenv_extra_of "$name" 2>/dev/null || printf '')"
    if [[ -n "$declared_extra" ]]; then
        local -a pkgs=()
        if ! _testenv_resolve_extra_packages "$declared_extra" pkgs; then
            exit 1
        fi
        if [[ "${#pkgs[@]}" -eq 0 ]]; then
            info "Extra '$declared_extra' has no packages — skipping install"
            return 0
        fi
        run_cmd "$env_path/bin/python" -m pip install "${pkgs[@]}"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 4: auto-detect requirements-dev.txt.
    if [[ -f "requirements-dev.txt" ]]; then
        run_cmd "$env_path/bin/python" -m pip install -r "requirements-dev.txt"
        success "Dev/test dependencies installed"
        return 0
    fi

    # Precedence 5: bare pytest fallback.
    run_cmd "$env_path/bin/python" -m pip install pytest
    success "Dev/test dependencies installed"
}

# Story M.l: invoke the Python helper's `--resolve-extra` mode to
# expand a declared `extra = "<name>"` into a concrete package list.
# Populates the caller-named array `<out_var>`. Returns non-zero
# (with helper's stderr already on the terminal) when the extra is
# not declared in `[project.optional-dependencies]` or pyproject.toml
# is missing.
_testenv_resolve_extra_packages() {
    local extra_name="$1"
    local out_var="$2"
    local py="${PYVE_PYTHON:-python}"
    local pyproject="${PYVE_PYPROJECT:-pyproject.toml}"
    local pkg_lines rc=0
    pkg_lines="$("$py" "$_PYVE_TESTENVS_HELPER" --resolve-extra "$pyproject" "$extra_name")" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        return "$rc"
    fi
    eval "$out_var=()"
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        eval "$out_var+=(\"\$line\")"
    done <<< "$pkg_lines"
    return 0
}

#------------------------------------------------------------
# Leaf: pyve testenv purge [<name>]
#
# Story M.i.4: accepts an optional <name>. With-arg removes that env;
# no-arg falls through to the dispatcher's iteration helper.
# Conda-backed envs are also purged (rm -rf is backend-agnostic).
#------------------------------------------------------------

testenv_purge() {
    local name="${1:-testenv}"
    purge_testenv_dir "$name"
}

#------------------------------------------------------------
# Leaf: pyve testenv run <command> [args...]
#
# `exec`s into the target command. The dispatcher emits no header/
# footer because exec replaces the shell — the called command owns
# the rest of the terminal.
#------------------------------------------------------------

testenv_run() {
    local testenv_venv="$1"
    shift

    if [[ $# -lt 1 ]]; then
        log_error "No command provided"
        log_error "Usage: pyve testenv run <command> [args...]"
        log_error "Example: pyve testenv run ruff check ."
        exit 1
    fi
    if [[ ! -x "$testenv_venv/bin/python" ]]; then
        log_error "Dev/test runner environment not initialized"
        log_error "Run: pyve testenv init"
        exit 1
    fi
    local cmd="$1"
    shift
    local testenv_bin="$testenv_venv/bin"
    local cmd_path="$testenv_bin/$cmd"
    if [[ -x "$cmd_path" ]]; then
        exec "$cmd_path" "$@"
    fi
    export VIRTUAL_ENV="$PWD/$testenv_venv"
    export PATH="$testenv_bin:$PATH"
    exec "$cmd" "$@"
}

#------------------------------------------------------------
# Story M.j: per-env install lock
#
# `mkdir`-based atomic lock at `.pyve/testenvs/<name>/.lock/`. The
# holding pid is written to `.lock/pid` so a waiting process can name
# who holds the lock. `flock(1)` is not on macOS by default — `mkdir`
# covers the same surface (atomic acquire, serialized wait, fast-fail
# on collision) with zero external-binary dependencies.
#
# Acquire is wait-by-default (1s sleep+retry, 10-minute cap). The
# `no-wait` mode fast-fails with a "(pid N)" message on collision.
# Stale-lock reclamation: if the holding pid no longer exists
# (`kill -0` fails), the lock dir is removed and re-acquired.
#
# Release only removes the lock dir when the caller is the recorded
# holder ($$ == pid file contents) so a stray release call cannot
# blow away another process's in-progress install.
#------------------------------------------------------------

_testenv_install_lock_dir() {
    printf '%s' ".pyve/testenvs/$1/.lock"
}

_testenv_acquire_install_lock() {
    local name="$1"
    local mode="${2:-wait}"
    local lock_dir
    lock_dir="$(_testenv_install_lock_dir "$name")"
    mkdir -p "$(dirname "$lock_dir")"

    local waited=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
        local holder_pid="?"
        if [[ -f "$lock_dir/pid" ]]; then
            holder_pid="$(cat "$lock_dir/pid" 2>/dev/null || printf '?')"
        fi

        # Stale-lock reclamation: holder pid no longer exists.
        if [[ "$holder_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
            warn "Stale install lock for '$name' (pid $holder_pid no longer exists); reclaiming."
            rm -rf "$lock_dir"
            continue
        fi

        if [[ "$mode" == "no-wait" ]]; then
            log_error "another pyve process is installing '$name' (pid $holder_pid)"
            return 1
        fi

        if [[ "$waited" -eq 0 ]]; then
            info "Waiting for install lock on '$name' (held by pid $holder_pid)..."
        fi
        sleep 1
        waited=$((waited + 1))
        if [[ "$waited" -gt 600 ]]; then
            log_error "timed out waiting for install lock on '$name' (held by pid $holder_pid)"
            return 1
        fi
    done

    printf '%s\n' "$$" > "$lock_dir/pid"
    return 0
}

_testenv_release_install_lock() {
    local name="$1"
    local lock_dir
    lock_dir="$(_testenv_install_lock_dir "$name")"
    if [[ -d "$lock_dir" && -f "$lock_dir/pid" ]]; then
        local holder
        holder="$(cat "$lock_dir/pid" 2>/dev/null || printf '')"
        if [[ "$holder" == "$$" ]]; then
            rm -rf "$lock_dir"
        fi
    fi
}

# Wraps a testenv install with acquire/release. A `trap` covers the
# `exit 1` paths inside the install helpers (existence checks, missing
# requirements file) and SIGINT/SIGTERM so the lock dir never strands
# the env. Story M.k: dispatches on the resolved backend so a
# conda-backed env goes through `_testenv_install_conda` (manifest-
# driven sync); Story M.l: venv backend goes through
# `_testenv_install_venv` (renamed from `testenv_install`), which
# itself dispatches on declared sources (`requirements`/`extra`/
# auto-detect/bare-pytest).
_testenv_install_with_lock() {
    local name="$1" env_path="$2" req_file="$3" lock_mode="${4:-wait}"
    _testenv_acquire_install_lock "$name" "$lock_mode" || return $?
    trap "_testenv_release_install_lock '$name'" EXIT INT TERM
    local rc=0
    local backend
    backend="$(_testenv_resolve_backend "$name")" || backend="venv"
    if [[ "$backend" == "micromamba" ]]; then
        local manifest
        manifest="$(_testenv_manifest_of "$name")" || manifest=""
        _testenv_install_conda "$name" "$env_path" "$manifest" || rc=$?
    else
        _testenv_install_venv "$name" "$env_path" "$req_file" || rc=$?
    fi
    _testenv_release_install_lock "$name"
    trap - EXIT INT TERM
    return "$rc"
}

#------------------------------------------------------------
# Story M.k: conda-backed init/install
#
# `_testenv_init_conda` creates the env from its declared `manifest`
# via `micromamba create -p <path> -f <manifest> -y`. This is conda's
# natural one-shot (create + install packages) — there is no "empty
# env" intermediate state for the conda backend.
#
# `_testenv_install_conda` syncs an *existing* env to its manifest via
# `micromamba install -p <path> -f <manifest> -y`. If the env does not
# exist, errors with a hint pointing at `pyve testenv init <name>`.
#
# Both require `manifest` to be declared in `[tool.pyve.testenvs.<name>]`
# — the conda backend has no implicit pip-style fallback.
#------------------------------------------------------------

_testenv_init_conda() {
    local name="$1"
    local env_path="$2"
    local manifest="$3"

    if [[ -z "$manifest" ]]; then
        log_error "conda-backed testenv '$name' requires 'manifest' to be declared in pyproject.toml"
        log_error "Add: [tool.pyve.testenvs.$name]"
        log_error "     manifest = \"<environment.yml path>\""
        return 1
    fi
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi

    if [[ -d "$env_path/conda-meta" ]]; then
        info "Conda-backed testenv '$name' already exists at '$env_path' — skipping create"
        return 0
    fi

    local micromamba_path
    micromamba_path="$(get_micromamba_path)" || micromamba_path=""
    if [[ -z "$micromamba_path" ]]; then
        log_error "micromamba not found — install it first (\`pyve init --backend micromamba\` bootstraps it)"
        return 1
    fi

    mkdir -p "$(dirname "$env_path")"
    info "Creating conda-backed testenv '$name' from $manifest..."
    if "$micromamba_path" create -p "$env_path" -f "$manifest" -y; then
        success "Created conda-backed testenv '$name'"
        return 0
    fi
    log_error "Failed to create conda-backed testenv '$name'"
    return 1
}

_testenv_install_conda() {
    local name="$1"
    local env_path="$2"
    local manifest="$3"

    if [[ -z "$manifest" ]]; then
        log_error "conda-backed testenv '$name' requires 'manifest' to be declared in pyproject.toml"
        return 1
    fi
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi
    if [[ ! -d "$env_path/conda-meta" ]]; then
        log_error "Conda-backed testenv '$name' is not initialized at '$env_path'"
        log_error "Run: pyve testenv init $name"
        return 1
    fi

    local micromamba_path
    micromamba_path="$(get_micromamba_path)" || micromamba_path=""
    if [[ -z "$micromamba_path" ]]; then
        log_error "micromamba not found"
        return 1
    fi

    info "Syncing conda-backed testenv '$name' from $manifest..."
    if "$micromamba_path" install -p "$env_path" -f "$manifest" -y; then
        success "Synced conda-backed testenv '$name'"
        return 0
    fi
    log_error "Failed to sync conda-backed testenv '$name'"
    return 1
}

#------------------------------------------------------------
# Story M.i.3: iterate `testenv install` over every non-lazy declared
# env. Returns the first install failure's status.
#
# Reads PYVE_TESTENVS_NAMES populated by read_testenv_config — caller
# must have loaded config (testenv_command does this in M.i.2).
#
# Story M.j: takes a `lock_mode` second arg (`wait` | `no-wait`) so
# the iteration honors `--no-wait` from the caller.
#
# Story M.k: conda-backed envs are no longer skipped — backend dispatch
# happens inside `_testenv_install_with_lock`, which calls
# `_testenv_install_conda` for `micromamba` (and `inherit` resolving
# to micromamba) and `testenv_install` for venv.
#------------------------------------------------------------

_testenv_install_all_nonlazy() {
    local requirements_file="$1"
    local lock_mode="${2:-wait}"
    local name installed_count=0 rc=0
    for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        if is_testenv_lazy "$name"; then
            continue
        fi
        info "Installing '$name' testenv..."
        local install_env_path
        install_env_path="$(resolve_testenv_path "$name")"
        _testenv_install_with_lock "$name" "$install_env_path" "$requirements_file" "$lock_mode" || rc=$?
        installed_count=$((installed_count + 1))
    done
    if [[ "$installed_count" -eq 0 ]]; then
        info "No non-lazy testenvs to install."
    fi
    return "$rc"
}

#------------------------------------------------------------
# Story M.i.4: iterate `testenv purge` over every declared env.
# Confirmation gate: prompt `y/N` only on an interactive stdin AND
# when --force is absent. CI / scripted invocations (non-TTY) skip
# the prompt and proceed — matches `pyve init`'s prompt pattern so
# `pyve testenv purge` stays scriptable. PYVE_FORCE_PROMPT=1 forces
# the prompt even on non-TTY stdin (used by the bats test that
# simulates the confirmation flow).
#
# Per-env failures are surfaced via warn() but do not halt the
# iteration — `rc` accumulates the worst exit code seen.
#------------------------------------------------------------

_testenv_purge_all_with_confirm() {
    local force="$1"
    local count="${#PYVE_TESTENVS_NAMES[@]}"
    if [[ "$count" -eq 0 ]]; then
        info "No declared testenvs to purge."
        return 0
    fi

    # Decide whether to prompt.
    local should_prompt=0
    if [[ "$force" != "1" ]]; then
        if [[ "${PYVE_FORCE_PROMPT:-0}" == "1" ]] || [[ -t 0 ]]; then
            should_prompt=1
        fi
    fi

    if [[ "$should_prompt" == "1" ]]; then
        printf "Remove all %d dev/test runner environment%s? [y/N]: " \
            "$count" "$([ "$count" -ne 1 ] && echo s)"
        local response
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Aborted; no testenvs were removed."
            return 0
        fi
    fi

    local name rc=0
    for name in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        if ! purge_testenv_dir "$name"; then
            warn "Failed to purge '$name' (continuing)"
            rc=1
        fi
    done
    return "$rc"
}

#------------------------------------------------------------
# Namespace dispatcher: pyve testenv <subcommand>
#
# Function-name note: this function is named `testenv_command` per
# the project-essentials "Function naming convention: verb_<operand>"
# rule — for namespace dispatchers the operand is the sub-command
# name that follows.
#------------------------------------------------------------

testenv_command() {
    local action=""
    local action_name=""           # Story M.i.2: optional positional <name>
    local requirements_file=""
    local purge_force=0            # Story M.i.4: --force skips the confirm prompt
    local install_no_wait=0        # Story M.j: --no-wait fast-fails on lock collision

    while [[ $# -gt 0 ]]; do
        case "$1" in
            # New subcommand grammar (H.d §4.4 D5) — silent.
            init)
                action="init"
                shift
                # Story M.i.2: optional positional <name> after `init`.
                if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
                    action_name="$1"
                    shift
                fi
                ;;
            install)
                action="install"
                shift
                # Story M.i.3: install accepts an optional positional
                # <name> and an optional -r <file>; both may appear in
                # either order. Sub-parse here so the order is flexible
                # without leaking into the rest of the dispatcher.
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        -r|--requirements)
                            if [[ -z "${2:-}" ]]; then
                                log_error "$1 requires a file path"
                                exit 1
                            fi
                            requirements_file="$2"
                            shift 2
                            ;;
                        --no-wait)
                            install_no_wait=1
                            shift
                            ;;
                        -*)
                            # Leave unknown flags to the outer loop
                            # (e.g. --help) so it can produce the
                            # canonical unknown_flag_error.
                            break
                            ;;
                        *)
                            if [[ -n "$action_name" ]]; then
                                log_error "testenv install: unexpected positional '$1' (already named '$action_name')"
                                exit 1
                            fi
                            action_name="$1"
                            shift
                            ;;
                    esac
                done
                ;;
            purge)
                action="purge"
                shift
                # Story M.i.4: sub-parser for optional <name> and --force.
                # Unrecognized flags break back to the outer loop.
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --force)
                            purge_force=1
                            shift
                            ;;
                        -*)
                            break
                            ;;
                        *)
                            if [[ -n "$action_name" ]]; then
                                log_error "testenv purge: unexpected positional '$1' (already named '$action_name')"
                                exit 1
                            fi
                            action_name="$1"
                            shift
                            ;;
                    esac
                done
                ;;
            # Story J.d (v2.3.0): Category A legacy flag forms
            # (`testenv --init|--install|--purge`) removed. Falls through
            # to the `-*)` arm below, which produces the standard
            # unknown-flag error.
            -r|--requirements)
                if [[ -z "${2:-}" ]]; then
                    log_error "$1 requires a file path"
                    exit 1
                fi
                requirements_file="$2"
                shift 2
                ;;
            run)
                action="run"
                shift
                break  # Remaining args are the [<name> --] command [args]
                ;;
            --help|-h)
                cat << 'EOF'
pyve testenv - Manage a dedicated dev/test runner environment

Usage:
  pyve testenv init [<name>]
  pyve testenv install [<name>] [-r requirements-dev.txt] [--no-wait]
  pyve testenv purge [<name>] [--force]
  pyve testenv run [<name> --] <command> [args...]

Notes:
  - Default `testenv` lives at .pyve/testenvs/testenv/venv
  - Named environments (Story M.i+) live at .pyve/testenvs/<name>/{venv,conda}/
    Declare them in [tool.pyve.testenvs.<name>] inside pyproject.toml.
  - `install` no-arg iterates over every non-lazy declared env. Conda-backed
    envs are skipped (M.k will provide provisioning). `install <name>` installs
    only into that env.
  - `install` acquires a per-env lock at .pyve/testenvs/<name>/.lock to
    serialize concurrent installs into the same env. Default is wait+retry;
    `--no-wait` fast-fails with "another pyve process is installing
    '<name>' (pid N)" instead of waiting.
  - `purge` no-arg iterates over every declared env (including lazy and
    conda-backed) and prompts `y/N` on interactive shells; `--force` skips
    the prompt. Non-TTY (CI) invocations skip the prompt automatically.
    `purge <name>` removes only that env's root, no prompt.
  - `run` requires the `--` separator when routing to a named env:
      pyve testenv run smoke -- pytest -v
    Without `--`, the first positional is the command (today's behavior preserved).
  - `testenv` and `root` are reserved names. `root` is selection-only
    (use `pyve test --env root`), not creatable as a testenv.
  - The testenv tree is preserved across `pyve init --force` and `pyve purge --keep-testenv`.
EOF
                exit 0
                ;;
            -*)
                unknown_flag_error "testenv" "$1" \
                    --requirements -r --help
                ;;
            *)
                log_error "Unknown testenv argument: $1"
                log_error "Usage: pyve testenv <init|install|purge|run> [options]"
                exit 1
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        log_error "No testenv action provided"
        log_error "Use: pyve testenv <init|install|purge|run <command>>"
        exit 1
    fi

    # Story M.i.2: load named-env config so `assert_testenv_*` gates can
    # validate non-default names. The no-pyproject.toml short-circuit
    # (M.i.1) keeps this cheap on bash-only projects.
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_testenv_config
    fi

    # Story M.i.2: `run` has its own arg shape — parse `[<name> --]
    # <cmd> [args]` from the leftover positional args. The `--`
    # separator is required when routing to a named env (no magic
    # detection of "the first arg is a name" — preserves today's
    # `pyve testenv run ruff check .` semantics).
    if [[ "$action" == "run" ]]; then
        local run_name="testenv"
        if [[ "${1:-}" == "--" ]]; then
            shift
        elif [[ "${2:-}" == "--" ]]; then
            run_name="$1"
            shift 2
        fi
        assert_testenv_name_actionable "$run_name" || exit 1
        assert_testenv_venv_backend     "$run_name" || exit 1
        local run_venv
        run_venv="$(resolve_testenv_path "$run_name")"
        testenv_run "$run_venv" "$@"
        return  # not reached on success (exec) but kept for clarity
    fi

    # Non-`run` actions: resolve path via the selected name (default
    # `testenv`). For `install`/`purge` the M.i.2 dispatcher still
    # hard-codes the default; M.i.3/M.i.4 will accept `<name>` here.
    local target_name="${action_name:-testenv}"
    if [[ "$action" == "init" ]]; then
        assert_testenv_name_actionable "$target_name" || exit 1
        # Backend stub is enforced inside testenv_init -> ensure_testenv_exists.
    fi
    local testenv_venv testenv_root
    testenv_venv="$(resolve_testenv_path "$target_name")"
    testenv_root="${testenv_venv%/venv}"

    header_box "pyve testenv"

    # Propagate leaf return codes (M.i.2). Without explicit handling,
    # bash uses the last command's status — which is footer_box's 0,
    # masking failures from the leaf functions.
    local leaf_rc=0
    case "$action" in
        init)
            testenv_init "$target_name" || leaf_rc=$?
            ;;
        install)
            # Story M.i.3: with-arg installs into a single named env;
            # no-arg iterates over every non-lazy declared env.
            # Story M.j: each install is wrapped with a per-env lock;
            # `--no-wait` switches the acquire from wait+retry to fast-fail.
            # Story M.k: backend dispatch happens inside
            # `_testenv_install_with_lock` — no caller-side venv/conda gate.
            local lock_mode="wait"
            [[ "$install_no_wait" == "1" ]] && lock_mode="no-wait"
            if [[ -n "$action_name" ]]; then
                if assert_testenv_name_actionable "$action_name"; then
                    local install_env_path
                    install_env_path="$(resolve_testenv_path "$action_name")"
                    _testenv_install_with_lock "$action_name" "$install_env_path" "$requirements_file" "$lock_mode" || leaf_rc=$?
                else
                    leaf_rc=1
                fi
            else
                _testenv_install_all_nonlazy "$requirements_file" "$lock_mode" || leaf_rc=$?
            fi
            ;;
        purge)
            # Story M.i.4: with-arg removes one env; no-arg iterates
            # over every declared env with a TTY-aware confirm gate.
            if [[ -n "$action_name" ]]; then
                if assert_testenv_name_actionable "$action_name"; then
                    testenv_purge "$action_name" || leaf_rc=$?
                else
                    leaf_rc=1
                fi
            else
                _testenv_purge_all_with_confirm "$purge_force" || leaf_rc=$?
            fi
            ;;
    esac

    footer_box
    return "$leaf_rc"
}
