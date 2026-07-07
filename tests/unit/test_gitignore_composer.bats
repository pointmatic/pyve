#!/usr/bin/env bats
# bats file_tags=init
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Composed `.gitignore` self-heal across plugins.
#
# Mirrors the `.envrc` composer (N.ae): `_compose_gitignore_body` enumerates
# active plugins, dispatches each plugin's `pyve_plugin_gitignore_entries`,
# validates each contribution through PC-1 (validate_gitignore_snippet),
# dedupes entries across plugins + composer-owned infra, and wraps them in
# the `# >>> pyve:managed:gitignore >>>` … `# <<< pyve:managed:gitignore <<<`
# envelope. `compose_gitignore <path>` writes atomically with a
# `.gitignore.prev` backup, preserving user-authored content ABOVE and BELOW
# the managed section. `compose_project_gitignore` reloads the manifest +
# registry first (the init/update entry point, mirroring N.ae.5).

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    source "$PYVE_ROOT/lib/gitignore_composer.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

_load_pure_python() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

_load_polyglot() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.python]
[plugins.node]
path = "src/frontend"
[env.root]
purpose = "utility"
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

# ════════════════════════════════════════════════════════════════════
# Body assembly.
# ════════════════════════════════════════════════════════════════════

@test "composer: _compose_gitignore_body is defined" {
    declare -F _compose_gitignore_body >/dev/null
}

@test "body (python-only): managed envelope + python entries + composer infra" {
    _load_pure_python
    run _compose_gitignore_body
    [ "$status" -eq 0 ]
    [[ "$output" == *"# >>> pyve:managed:gitignore >>>"* ]]
    [[ "$output" == *"# <<< pyve:managed:gitignore <<<"* ]]
    [[ "$output" == *"__pycache__"* ]]
    # Composer-owned infrastructure.
    [[ "$output" == *".DS_Store"* ]]
    [[ "$output" == *".pyve/"* ]]
    [[ "$output" == *".envrc"* ]]
    [[ "$output" == *".env"* ]]
}

@test "body (polyglot): carries both python and node entries (node path-prefixed)" {
    _load_polyglot
    run _compose_gitignore_body
    [ "$status" -eq 0 ]
    [[ "$output" == *"__pycache__"* ]]
    [[ "$output" == *"src/frontend/node_modules/"* ]]
}

@test "body: dedupes an entry contributed by more than one source (emit once)" {
    _load_polyglot
    # Make node also emit `.env` (already a composer-infra line).
    node_pyve_plugin_gitignore_entries() {
        printf '.env\nnode_modules/\n'
    }
    local body count
    body="$(_compose_gitignore_body)"
    count="$(printf '%s\n' "$body" | grep -cE '^\.env$' || true)"
    [ "$count" -eq 1 ]
}

@test "body: writes no file" {
    _load_pure_python
    rm -f .gitignore
    _compose_gitignore_body >/dev/null
    [ ! -f .gitignore ]
}

# ════════════════════════════════════════════════════════════════════
# Materialized-state coverage.
#
# Everything under `.pyve/` is materialized state, never config — so the
# composed `.gitignore` must ignore the WHOLE tree, not an enumerated set
# of top-level subdirs. The trap: a gitignore pattern carrying a
# non-trailing slash (`.pyve/testenvs`) is anchored to the path root, so
# it matches `.pyve/testenvs` but NOT `.pyve/.v2-legacy/testenvs/...` (the
# layout `pyve self migrate` creates) nor `.pyve/bin/...` (the micromamba
# bootstrap's download dir). Asserted behaviorally via `git check-ignore`
# because a literal-line grep would pass on the buggy enumerated form yet
# still miss the nested paths. Regression: a migrate run committed 1000+
# legacy-venv files because none of these paths were ignored.
# ════════════════════════════════════════════════════════════════════

@test "infra: composed .gitignore ignores every materialized-state path under .pyve/" {
    _load_pure_python
    compose_gitignore .gitignore
    git init -q .
    # Nested paths created by the migrator / bootstrap / env provisioning —
    # exactly the ones an anchored top-level subdir pattern silently misses.
    local p
    for p in \
        .pyve/.v2-legacy/testenvs/testenv/venv/bin/pytest \
        .pyve/bin/micromamba \
        .pyve/envs/root/conda/conda-meta/history; do
        run git -c core.excludesFile=/dev/null check-ignore "$p"
        [ "$status" -eq 0 ] || { echo "NOT ignored: $p"; false; }
    done
}

# ════════════════════════════════════════════════════════════════════
# PC-1 boundary.
# ════════════════════════════════════════════════════════════════════

@test "body: a plugin emitting a shell-interpolation entry is rejected" {
    _load_polyglot
    node_pyve_plugin_gitignore_entries() {
        printf 'node_modules/\n$(rm -rf /)\n'
    }
    run _compose_gitignore_body
    [ "$status" -ne 0 ]
}

# ════════════════════════════════════════════════════════════════════
# compose_gitignore — write safety + preservation.
# ════════════════════════════════════════════════════════════════════

@test "compose_gitignore: is defined" {
    declare -F compose_gitignore >/dev/null
}

@test "fresh: writes .gitignore with the managed section" {
    _load_pure_python
    rm -f .gitignore
    run compose_gitignore .gitignore
    [ "$status" -eq 0 ]
    [ -f .gitignore ]
    grep -qF '# >>> pyve:managed:gitignore >>>' .gitignore
    grep -qF '__pycache__' .gitignore
}

@test "fresh: no .gitignore.prev when there was no prior file" {
    _load_pure_python
    rm -f .gitignore .gitignore.prev
    compose_gitignore .gitignore
    [ ! -f .gitignore.prev ]
}

@test "preservation: user content above and below the managed section round-trips" {
    _load_pure_python
    compose_gitignore .gitignore
    # User adds content above the start marker and below the end marker.
    {
        printf '# my header\nsecrets.txt\n'
        cat .gitignore
        printf 'my-scratch/\n'
    } > .gitignore.user && mv .gitignore.user .gitignore
    run compose_gitignore .gitignore
    [ "$status" -eq 0 ]
    grep -qF 'secrets.txt' .gitignore
    grep -qF 'my-scratch/' .gitignore
    grep -qF '# my header' .gitignore
}

@test "backup: overwriting an existing .gitignore creates .gitignore.prev" {
    _load_pure_python
    compose_gitignore .gitignore
    printf 'user-line\n' >> .gitignore
    local before
    before="$(cat .gitignore)"
    compose_gitignore .gitignore
    [ -f .gitignore.prev ]
    [ "$(cat .gitignore.prev)" = "$before" ]
}

@test "legacy (no markers): user ignores preserved, managed dups not duplicated, backed up" {
    _load_pure_python
    cat > .gitignore <<'EOF'
# my project ignores
secrets.env
__pycache__
build-artifacts/
EOF
    run compose_gitignore .gitignore
    [ "$status" -eq 0 ]
    grep -qF '# >>> pyve:managed:gitignore >>>' .gitignore
    # User's unique entries survive.
    grep -qF 'secrets.env' .gitignore
    grep -qF 'build-artifacts/' .gitignore
    # __pycache__ is pyve-managed; must appear exactly once (no dup carried below).
    [ "$(grep -cxF '__pycache__' .gitignore)" -eq 1 ]
    # Legacy file backed up.
    [ -f .gitignore.prev ]
}

@test "idempotence: composing twice is stable" {
    _load_pure_python
    compose_gitignore .gitignore
    local first
    first="$(cat .gitignore)"
    compose_gitignore .gitignore
    [ "$(cat .gitignore)" = "$first" ]
}

# ════════════════════════════════════════════════════════════════════
# Reload entry point (mirrors compose_project_envrc).
# ════════════════════════════════════════════════════════════════════

@test "compose_project_gitignore: reloads the manifest then composes" {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.python]
[plugins.node]
path = "src/frontend"
[env.root]
purpose = "utility"
EOF
    plugin_registry_reset   # stale/empty registry
    run compose_project_gitignore .gitignore
    [ "$status" -eq 0 ]
    grep -qF 'src/frontend/node_modules/' .gitignore
}
