# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/envs.sh — testenv-DX config foundation (Story M.g)
#
# Reads [tool.pyve.testenvs] from a project's pyproject.toml via the
# Python tomllib helper (`lib/pyve_testenvs_helper.py`) and exposes a
# flat accessor surface for consumers (`pyve testenv`, `pyve test`,
# `pyve lock`). All state lives in parallel indexed arrays populated by
# `read_env_config`.
#
# Spike doc (decisions): docs/specs/spike-m-f-testenvs-config.md
#
# Reserved names:
#   - `root`    — the project's main `.venv/` (or conda env). NOT a
#                 testenv; selection-only. Cannot be redeclared.
#   - `testenv` — the well-known default at .pyve/envs/testenv/... (v3;
#                 v2.8 lived at .pyve/testenvs/testenv/...). MAY be
#                 redeclared.
#
# State populated by `read_env_config` (V3 wire format):
#   PYVE_TESTENVS_DEFAULT       — name of the default env
#   PYVE_TESTENVS_NAMES[]       — declared env names (indexed)
#   PYVE_TESTENV_BACKEND[]      — parallel: backend per env
#   PYVE_TESTENV_LAZY[]         — parallel: "0" / "1"
#   PYVE_TESTENV_EXTRA[]        — parallel: pyproject extra name or ""
#   PYVE_TESTENV_MANIFEST[]     — parallel: conda manifest path or ""
#   PYVE_TESTENV_REQUIREMENTS_Q[] — parallel: shell-quoted requirements list
#
# This file is sourced by pyve.sh's library-loading block. It must not
# be executed directly — see the guard immediately below.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

# Path to the Python helper. Resolves relative to this file so the
# library is testable independent of pyve.sh's SCRIPT_DIR.
_PYVE_TESTENVS_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pyve_testenvs_helper.py"

# Read [tool.pyve.testenvs] from <pyproject.toml> (default ./pyproject.toml)
# and populate the V3 array state. Missing file or missing block yields
# the implicit default (single venv `testenv`). Validation errors from
# the helper propagate via non-zero exit and stderr.
read_env_config() {
    local pyproject="${1:-pyproject.toml}"
    # Short-circuit: no pyproject.toml → synthesize the implicit-default
    # config (single venv `testenv`) in pure bash. The Python helper
    # would have returned the same shape, but invoking python would
    # require python to be on PATH — which is not a given on bash-only
    # or raw-requirements.txt projects. Same implicit-default contract
    # as documented in [spike-m-f-testenvs-config.md §Decision 5].
    if [[ ! -f "$pyproject" ]]; then
        PYVE_TESTENVS_DEFAULT="testenv"
        PYVE_TESTENVS_NAMES=("testenv")
        PYVE_TESTENV_BACKEND=("venv")
        PYVE_TESTENV_LAZY=("0")
        PYVE_TESTENV_EXTRA=("")
        PYVE_TESTENV_MANIFEST=("")
        PYVE_TESTENV_REQUIREMENTS_Q=("")
        return 0
    fi
    # Pyve toolchain python — see lib/manifest.sh's note
    # (incl. the self-sufficient fallback + the `local` split rationale).
    local py
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    local kv
    kv="$("$py" "$_PYVE_TESTENVS_HELPER" "$pyproject")" || return $?
    eval "$kv"
}

# Index lookup: print the 0-based position of <name> in PYVE_TESTENVS_NAMES,
# or return 1 (no output) if absent. Private helper.
#
# Defensive against unset PYVE_TESTENVS_NAMES: returns 1 cleanly under
# `set -u` if read_env_config has not yet been called. Callers like
# resolve_env_path then use their `|| fallback` arms (e.g. default
# backend = "venv") rather than crashing the script.
_envs_name_to_index() {
    local target="$1" i
    [[ -n "${PYVE_TESTENVS_NAMES+x}" ]] || return 1
    for ((i=0; i<${#PYVE_TESTENVS_NAMES[@]}; i++)); do
        if [[ "${PYVE_TESTENVS_NAMES[$i]}" == "$target" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

# Field accessors (used by tests and consumers; one per parallel array).
# Print empty string if name is unknown; bash-3.2-safe under set -u.
_env_backend_of() {
    local i; i="$(_envs_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_TESTENV_BACKEND[$i]}"
}
_env_extra_of() {
    local i; i="$(_envs_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_TESTENV_EXTRA[$i]}"
}
_env_manifest_of() {
    local i; i="$(_envs_name_to_index "$1")" || return 1
    printf '%s' "${PYVE_TESTENV_MANIFEST[$i]}"
}
# Populate a caller-named array with the env's requirements list.
# Usage: declare -a reqs; _env_requirements_of <name> reqs
_env_requirements_of() {
    local i out_var
    i="$(_envs_name_to_index "$1")" || return 1
    out_var="$2"
    eval "$out_var=( ${PYVE_TESTENV_REQUIREMENTS_Q[$i]} )"
}

# Predicate: 0 if <name> is one of the reserved names (`root`, `testenv`),
# 1 otherwise.
is_env_reserved() {
    case "$1" in
        root|testenv) return 0 ;;
        *) return 1 ;;
    esac
}

# Predicate: 0 if <name> appears in PYVE_TESTENVS_NAMES, 1 otherwise.
# Note: `root` is reserved-but-not-declared (never in PYVE_TESTENVS_NAMES).
is_env_declared() {
    _envs_name_to_index "$1" >/dev/null
}

# Predicate: 0 if <name> is declared with `lazy = true`, 1 otherwise
# (including: not declared at all).
is_env_lazy() {
    local i; i="$(_envs_name_to_index "$1")" || return 1
    [[ "${PYVE_TESTENV_LAZY[$i]}" == "1" ]]
}

# Print declared env names + reserved names, one per line. Reserved
# names that overlap with declared ones (i.e. `testenv`) print once.
list_env_names() {
    local n
    for n in "${PYVE_TESTENVS_NAMES[@]+"${PYVE_TESTENVS_NAMES[@]}"}"; do
        printf '%s\n' "$n"
    done
    # `root` is the one reserved name that is never in NAMES.
    if ! _envs_name_to_index root >/dev/null; then
        printf '%s\n' "root"
    fi
}

# Verify a name is usable: declared OR reserved. Print a helpful error
# to stderr and return 1 if not. Caller's job to log_error if it wants
# its own formatting; this prints the canonical message.
validate_env_decl() {
    local name="$1"
    if is_env_reserved "$name" || is_env_declared "$name"; then
        return 0
    fi
    printf "error: testenv '%s' is not declared and is not a reserved name (root, testenv)\n" "$name" >&2
    return 1
}

# Story M.i.1: gate for name-aware actions (testenv init / install /
# purge / run). Stricter than validate_env_decl — rejects `root`,
# which is selection-only (`pyve test --env root` works, but `pyve
# testenv init root` does not — `root` is the project's main env, not
# a testenv). Undeclared names get a hint pointing at the canonical
# config location.
assert_env_name_actionable() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        printf "error: testenv name is required\n" >&2
        return 1
    fi
    if [[ "$name" == "root" ]]; then
        printf "error: 'root' is selection-only (use 'pyve test --env root' to run pytest in the main project env). It is not a testenv and cannot be created/installed/purged.\n" >&2
        return 1
    fi
    if [[ "$name" == "testenv" ]] || is_env_declared "$name"; then
        return 0
    fi
    printf "error: testenv '%s' is not declared. Declare it under [tool.pyve.testenvs.%s] in pyproject.toml.\n" "$name" "$name" >&2
    return 1
}

# Story M.k: resolve <name>'s effective backend. Returns the concrete
# literal `venv` or `micromamba` — never `inherit`. For `inherit`, reads
# the main env's backend from `.pyve/config` via `read_config_value`;
# falls back to `venv` if no config (matches the bash-only / greenfield
# project case). For undeclared names, returns `venv`.
_env_resolve_backend() {
    local name="$1"
    local raw
    raw="$(_env_backend_of "$name")" || raw="venv"
    if [[ "$raw" != "inherit" ]]; then
        printf '%s' "$raw"
        return 0
    fi
    local main_backend
    main_backend="$(read_config_value backend 2>/dev/null || printf '')"
    if [[ "$main_backend" == "micromamba" ]]; then
        printf '%s' "micromamba"
    else
        printf '%s' "venv"
    fi
}

# Story N.bf.14: resolve the reserved `root` env's backend. `root` is
# never in PYVE_TESTENVS_NAMES, so the regular `_env_resolve_backend`
# can't see it; read it from `.pyve/config` (v3 read-compat) then the
# manifest, defaulting to `venv`. Defensive under `set -u` and when the
# config/manifest helpers aren't sourced (returns `venv`).
_env_resolve_root_backend() {
    local b=""
    b="$(read_config_value backend 2>/dev/null || true)"
    [[ -z "$b" ]] && b="$(manifest_get_backend root 2>/dev/null || true)"
    [[ -z "$b" ]] && b="venv"
    printf '%s' "$b"
}

# is <backend> a known-advisory backend? Routes through
# the Python classifier (the single source of the closed vocabulary) so the
# advisory set is never duplicated — and thus never drifts — on the shell
# side. Returns 0 when advisory, 1 otherwise (implemented, unknown, empty, or
# classifier unavailable — caller then proceeds with normal materialization).
_env_backend_is_advisory() {
    local backend="${1:-}"
    [[ -n "$backend" ]] || return 1
    local helper py cls
    helper="${_PYVE_MANIFEST_HELPER:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pyve_toml_helper.py}"
    py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"
    cls="$("$py" "$helper" classify backend "$backend" 2>/dev/null)" || return 1
    [[ "$cls" == "advisory" ]]
}

# Story M.i.1 / M.k: venv-only gate for `pyve testenv run`. Returns 0
# when the resolved backend is `venv`; 1 (with a stderr error) for
# `micromamba` (and `inherit` that resolves to micromamba). M.k landed
# conda-backed init/install, but `pyve testenv run` still uses PATH-only
# activation and does not set CONDA_PREFIX / CONDA_PYTHON_EXE, so it is
# kept venv-only for now. Use `micromamba run -p <path> <cmd>` for the
# conda case (manual workaround).
assert_env_venv_backend() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        printf "error: testenv name is required\n" >&2
        return 1
    fi
    local backend
    backend="$(_env_resolve_backend "$name")" || backend="venv"
    if [[ "$backend" == "venv" ]]; then
        return 0
    fi
    printf "error: 'pyve testenv run' does not yet support conda-backed testenv '%s' (resolved backend: %s). Workaround: 'micromamba run -p .pyve/envs/%s/conda <command>'.\n" "$name" "$backend" "$name" >&2
    return 1
}

# =====================================================================
# .state file helpers (Story M.h.1; N.f relocated to .pyve/envs/)
# =====================================================================
#
# Each named env has a sibling `.state` file at
# .pyve/envs/<name>/.state that records provisioning + usage data.
# Schema is plain key=value lines, sourceable:
#
#   backend=venv|micromamba|inherit
#   manifest=<relative path or empty>
#   manifest_sha256=<64-hex or empty>
#   provisioned_at=<unix epoch seconds>
#   last_used_at=<unix epoch seconds or 0>

# Print the .state file path for <name>.
state_path() {
    printf '%s' ".pyve/envs/$1/.state"
}

# Write/overwrite the .state file for <name>. Required: <name> <backend>.
# Optional keyword args (in any order):
#   manifest=<path>
#   manifest_sha256=<hex>
#   provisioned_at=<epoch>   (default: current epoch)
#   last_used_at=<epoch>     (default: 0)
# Unknown keys are a hard error.
state_write() {
    local name="${1:-}" backend="${2:-}"
    if [[ -z "$name" || -z "$backend" ]]; then
        printf "error: state_write: requires <name> <backend>\n" >&2
        return 1
    fi
    shift 2
    local manifest="" sha="" prov="" last="0"
    local arg key val
    for arg in "$@"; do
        key="${arg%%=*}"
        val="${arg#*=}"
        case "$key" in
            manifest)        manifest="$val" ;;
            manifest_sha256) sha="$val" ;;
            provisioned_at)  prov="$val" ;;
            last_used_at)    last="$val" ;;
            *)
                printf "error: state_write: unknown keyword arg '%s'\n" "$key" >&2
                return 1
                ;;
        esac
    done
    [[ -z "$prov" ]] && prov="$(date +%s)"
    local file; file="$(state_path "$name")"
    mkdir -p "$(dirname "$file")"
    {
        printf 'backend=%s\n'         "$backend"
        printf 'manifest=%s\n'        "$manifest"
        printf 'manifest_sha256=%s\n' "$sha"
        printf 'provisioned_at=%s\n'  "$prov"
        printf 'last_used_at=%s\n'    "$last"
    } > "$file"
}

# Read the .state file for <name> into PYVE_TESTENV_STATE_* shell vars.
# Returns 1 (no shell mutation) if the file is missing or unreadable.
state_read() {
    local name="$1"
    local file; file="$(state_path "$name")"
    [[ -r "$file" ]] || return 1
    # Source into local vars first (subshell isolation), then promote.
    # Use a clean associative read rather than a raw `source` so a
    # malformed .state cannot inject arbitrary shell.
    local backend="" manifest="" sha="" prov="" last="0"
    local line key val
    while IFS= read -r line || [[ -n "$line" ]]; do
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
            backend)         backend="$val" ;;
            manifest)        manifest="$val" ;;
            manifest_sha256) sha="$val" ;;
            provisioned_at)  prov="$val" ;;
            last_used_at)    last="$val" ;;
        esac
    done < "$file"
    PYVE_TESTENV_STATE_BACKEND="$backend"
    PYVE_TESTENV_STATE_MANIFEST="$manifest"
    PYVE_TESTENV_STATE_MANIFEST_SHA256="$sha"
    PYVE_TESTENV_STATE_PROVISIONED_AT="$prov"
    PYVE_TESTENV_STATE_LAST_USED_AT="$last"
}

# Update only `last_used_at` to the current epoch; preserve all other
# fields. Returns 1 if the .state file is missing.
state_touch_last_used() {
    local name="$1"
    state_read "$name" || return 1
    state_write "$name" "$PYVE_TESTENV_STATE_BACKEND" \
        manifest="$PYVE_TESTENV_STATE_MANIFEST" \
        manifest_sha256="$PYVE_TESTENV_STATE_MANIFEST_SHA256" \
        provisioned_at="$PYVE_TESTENV_STATE_PROVISIONED_AT" \
        last_used_at="$(date +%s)"
}

# =====================================================================
# Legacy-layout migration (Story M.h.2; N.f extends to v3)
# =====================================================================
#
# Three layout generations, three boundaries:
#
#   v2.7  →  .pyve/testenv/venv/                (singular, TESTENV_DIR_NAME)
#   v2.8  →  .pyve/testenvs/<name>/{venv,conda}/  (plural, name-keyed)
#   v3.0  →  .pyve/envs/<name>/{venv,conda}/      (env vocabulary)
#
# `migrate_legacy_env_layout` is the opportunistic mover for both
# boundaries. It runs as a side effect of `resolve_env_path` and as a
# pre-step in `pyve update`, so users on v2.7/v2.8 layouts pick up the
# move without explicit action. The deterministic, fully backed-up
# variant lives in `pyve self migrate`.
#
# Four-case shape preserved across both boundaries:
#   1. legacy only        → mv + write initial .state + info log
#   2. v3 already present → no-op (idempotent)
#   3. both exist         → no-op (preserve v3; leave legacy alone)
#   4. neither (greenfield) → no-op
migrate_legacy_env_layout() {
    # --- v2.7 → v3: .pyve/testenv/venv/ → .pyve/envs/testenv/venv/ ---
    _migrate_legacy_env_v27_to_v3
    # --- v2.8 → v3: .pyve/testenvs/<name>/* → .pyve/envs/<name>/* ---
    _migrate_legacy_env_v28_to_v3
    # --- v3-flat → v3-conda: .pyve/envs/<configured>/ → .pyve/envs/root/conda/
    #     (Story N.bf.14: the main micromamba env is the reserved `root`
    #     env; finish the physical move N.g left unreconciled). ---
    _migrate_main_micromamba_to_v3
}

# v2.7 (singular) → v3 mover. Handles the original M.h.2 case; the v3
# destination is `.pyve/envs/testenv/...` rather than v2.8's
# `.pyve/testenvs/testenv/...`.
_migrate_legacy_env_v27_to_v3() {
    local legacy=".pyve/testenv/venv"
    local new_root=".pyve/envs/testenv"
    local new_venv="$new_root/venv"

    # Case 2 + 3: v3 already present → no-op.
    if [[ -d "$new_venv" ]]; then
        return 0
    fi
    # Case 4: greenfield for this boundary.
    if [[ ! -d "$legacy" ]]; then
        return 0
    fi

    # Case 1: migrate. Capture legacy mtime so the new `.state` records
    # the original provisioning epoch (mv preserves mtime on most FSes,
    # but we read it explicitly).
    local legacy_mtime=""
    if [[ "$(uname)" == "Darwin" ]]; then
        legacy_mtime="$(stat -f %m "$legacy" 2>/dev/null || true)"
    else
        legacy_mtime="$(stat -c %Y "$legacy" 2>/dev/null || true)"
    fi

    mkdir -p "$new_root"
    mv "$legacy" "$new_venv"
    rmdir ".pyve/testenv" 2>/dev/null || true

    local state_args=("testenv" "venv")
    if [[ -n "$legacy_mtime" ]]; then
        state_args+=("provisioned_at=$legacy_mtime")
    fi
    state_write "${state_args[@]}"

    info "Migrated v2.7 testenv layout: .pyve/testenv/venv → .pyve/envs/testenv/venv"
}

# v2.8 (plural) → v3 mover. Walks every `.pyve/testenvs/<name>/` entry
# and moves its inner `venv/`, `conda/`, and sibling `.state` to the
# matching `.pyve/envs/<name>/` location. Per-env idempotent.
_migrate_legacy_env_v28_to_v3() {
    local legacy_root=".pyve/testenvs"
    # Case 4: greenfield for this boundary.
    if [[ ! -d "$legacy_root" ]]; then
        return 0
    fi

    local moved_any=0
    local entry name new_dir
    for entry in "$legacy_root"/*/; do
        # `*/` literal stays when nothing matched the glob.
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"
        new_dir=".pyve/envs/$name"

        # Per-env case 2 + 3: v3 inner dirs already present → leave
        # legacy entry alone (preserve v3; silent deletion of user
        # state is the wrong default).
        if [[ -d "$new_dir/venv" || -d "$new_dir/conda" ]]; then
            continue
        fi

        # Per-env case 1: at least one inner artifact (venv/, conda/,
        # or .state) exists under legacy and the v3 dest is empty.
        mkdir -p "$new_dir"
        [[ -d "$entry/venv"  ]] && mv "$entry/venv"  "$new_dir/venv"
        [[ -d "$entry/conda" ]] && mv "$entry/conda" "$new_dir/conda"
        [[ -f "$entry/.state" ]] && mv "$entry/.state" "$new_dir/.state"
        # Drop the now-empty legacy entry; leave it alone if anything
        # else (lock dirs, future contrib state) was tucked inside.
        rmdir "$entry" 2>/dev/null || true
        moved_any=1
    done

    # Clean up the now-empty `.pyve/testenvs/` parent if every entry
    # moved cleanly. Leave it alone otherwise.
    rmdir "$legacy_root" 2>/dev/null || true

    if [[ "$moved_any" == "1" ]]; then
        info "Migrated v2.8 testenv layout: .pyve/testenvs/<name>/ → .pyve/envs/<name>/"
    fi
}

# Story N.bf.14: the main micromamba env is the reserved `root` env; its
# canonical v3 slot is `.pyve/envs/root/conda/` (uniform `<name>/<backend>/`
# shape), with a sibling `.pyve/envs/root/.state`. Single source of the
# slot literal — consumed by `resolve_env_path root` here and by
# `create_micromamba_env` / `verify_micromamba_env` in lib/micromamba_env.sh.
micromamba_root_prefix() {
    printf '%s' ".pyve/envs/root/conda"
}

# Story N.bf.14: non-mutating resolver for the main micromamba env path.
# Returns the v3 root slot (`.pyve/envs/root/conda`) if it exists, else
# the legacy flat path (`.pyve/envs/<configured>/`) derived from the
# passed name or `.pyve/config:micromamba.env_name`, else the canonical
# root slot (so a caller's existence check reports "missing" against the
# right path). Unlike `resolve_env_path root`, this does NOT trigger the
# opportunistic move — read paths (`check` / `status` / `run`) use it to
# tolerate both layouts during the transition window without mutating the
# tree on a diagnostic; the move fires on the write paths (`init` /
# `update` / `test` / `env *`).
resolve_main_micromamba_path() {
    local root
    root="$(micromamba_root_prefix)"
    if [[ -d "$root" ]]; then
        printf '%s' "$root"
        return 0
    fi
    local name="${1:-}"
    [[ -z "$name" ]] && name="$(read_config_value micromamba.env_name 2>/dev/null || true)"
    if [[ -n "$name" && "$name" != "root" && -d ".pyve/envs/$name" ]]; then
        printf '%s' ".pyve/envs/$name"
        return 0
    fi
    printf '%s' "$root"
}

# v3-flat (main micromamba env) → v3-conda(root) mover. Pre-N.bf.14, the
# main micromamba env materialized FLAT at `.pyve/envs/<configured>/`
# (conda-meta directly inside, no `conda/` subdir, no `.state`). This
# moves it to `.pyve/envs/root/conda/` and writes the sibling `.state`.
#
# Discriminator: a flat main env has `conda-meta` DIRECTLY inside
# `.pyve/envs/<name>/`. Named micromamba testenvs nest it one level
# deeper (`.pyve/envs/<name>/conda/conda-meta`), so they are never
# matched. Idempotent: if `.pyve/envs/root/conda/` already exists the
# v3 env is preserved and any stray flat dir is left untouched.
_migrate_main_micromamba_to_v3() {
    local dest_root=".pyve/envs/root"
    local dest="$dest_root/conda"

    # Case 2 + 3: v3 root/conda already present → preserve it, no-op.
    if [[ -d "$dest" ]]; then
        return 0
    fi

    # Locate the flat main env. Prefer the configured name from
    # `.pyve/config` (micromamba backend); fall back to a scan for a
    # `.pyve/envs/*/conda-meta` directory that is not `root`.
    local name="" flat=""
    if config_file_exists 2>/dev/null \
       && [[ "$(read_config_value backend 2>/dev/null || true)" == "micromamba" ]]; then
        name="$(read_config_value micromamba.env_name 2>/dev/null || true)"
    fi
    if [[ -n "$name" && "$name" != "root" && -d ".pyve/envs/$name/conda-meta" ]]; then
        flat=".pyve/envs/$name"
    else
        local d
        for d in .pyve/envs/*/; do
            [[ -d "${d}conda-meta" ]] || continue
            [[ "$(basename "$d")" == "root" ]] && continue
            flat="${d%/}"
            break
        done
    fi

    # Case 4: greenfield for this boundary (no flat main env).
    [[ -n "$flat" && -d "$flat/conda-meta" ]] || return 0

    # Capture legacy mtime so the new `.state` records the original
    # provisioning epoch (mirrors the v2.7 mover).
    local legacy_mtime=""
    if [[ "$(uname)" == "Darwin" ]]; then
        legacy_mtime="$(stat -f %m "$flat" 2>/dev/null || true)"
    else
        legacy_mtime="$(stat -c %Y "$flat" 2>/dev/null || true)"
    fi

    mkdir -p "$dest_root"
    mv "$flat" "$dest"

    local state_args=("root" "micromamba" "manifest=environment.yml")
    if [[ -n "$legacy_mtime" ]]; then
        state_args+=("provisioned_at=$legacy_mtime")
    fi
    state_write "${state_args[@]}"

    info "Migrated flat micromamba main env: $flat → $dest"
}

# Resolve the on-disk path for <name>. Does NOT check existence; that is
# the caller's responsibility. Path shape (N.f / N.bf.14):
#   root      → .venv                   (venv backend — the project main venv)
#             → .pyve/envs/root/conda/  (micromamba backend — uniform slot)
#   <name>    → .pyve/envs/<name>/{venv|conda}/  (per declared backend)
resolve_env_path() {
    local name="$1"
    if [[ "$name" == "root" ]]; then
        # Main project env (Story N.bf.14). venv → .venv; micromamba →
        # the uniform `.pyve/envs/root/conda/` slot. Fire the opportunistic
        # flat→conda(root) move so a pre-N.bf.14 flat main env is relocated
        # before any consumer reads the path.
        local root_backend
        root_backend="$(_env_resolve_root_backend)"
        if [[ "$root_backend" == "micromamba" ]]; then
            # Redirect the migrator's progress output to stderr: this
            # function is command-substituted by callers (env_path="$(...)"),
            # so its stdout must carry ONLY the resolved path.
            migrate_legacy_env_layout >&2
            printf '%s' "$(micromamba_root_prefix)"
        else
            printf '%s' ".venv"
        fi
        return 0
    fi
    # Opportunistic-migration fallback. Two trigger conditions:
    #   (a) v2.7 legacy at `.pyve/testenv/venv/` (only when asking for
    #       reserved `testenv`)
    #   (b) v2.8 legacy at `.pyve/testenvs/<name>/...` for the env being
    #       asked for
    # Either trigger fires the full migrator (it's a cheap pair of dir
    # checks per branch); the migrator is internally idempotent. Its
    # progress output is redirected to stderr because this function is
    # command-substituted by callers — stdout must carry ONLY the path.
    local v3_venv=".pyve/envs/${name}/venv"
    local v3_conda=".pyve/envs/${name}/conda"
    if [[ "$name" == "testenv" ]] \
       && [[ ! -d "$v3_venv" ]] \
       && [[ -d ".pyve/testenv/venv" ]]; then
        migrate_legacy_env_layout >&2
    elif [[ ! -d "$v3_venv" ]] \
         && [[ ! -d "$v3_conda" ]] \
         && [[ -d ".pyve/testenvs/${name}" ]]; then
        migrate_legacy_env_layout >&2
    fi
    local backend
    # Story M.k: dispatch on the *resolved* backend so `inherit` produces
    # a venv-shaped path when main is venv (and a conda-shaped path when
    # main is micromamba).
    backend="$(_env_resolve_backend "$name")" || backend="venv"
    if [[ "$backend" == "micromamba" ]]; then
        printf '%s' ".pyve/envs/${name}/conda"
    else
        printf '%s' ".pyve/envs/${name}/venv"
    fi
}
