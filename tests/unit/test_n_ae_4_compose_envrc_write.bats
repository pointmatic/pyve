#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.ae.4 — PC-2 write safety: atomic write, `.envrc.prev` backup,
# user-content preservation.
#
# `compose_envrc <output_path>` wraps `_compose_envrc_body` (N.ae.3) with
# crash-safe write semantics: compose to `<path>.tmp`; on failure leave the
# existing file untouched; back the current file up to `<path>.prev`; promote
# with `mv -f`. User-authored content below the `# <<< pyve:managed:end <<<`
# marker round-trips verbatim. A fresh scaffold emits the managed section
# plus a trailing invitation comment below the end marker.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    source "$PYVE_ROOT/lib/envrc_composer.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    export NO_COLOR=1
    VERSION_MANAGER=""
}

teardown() {
    cleanup_test_dir
}

_config_venv() {
    mkdir -p .pyve
    printf 'backend: venv\nvenv:\n  directory: .venv\n' > .pyve/config
}

_load_pure_python() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[env.root]
purpose = "utility"
[env.testenv]
purpose = "test"
default = true
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
# Fresh scaffold.
# ════════════════════════════════════════════════════════════════════

@test "compose_envrc: is defined" {
    declare -F compose_envrc >/dev/null
}

@test "fresh scaffold: writes .envrc with managed section + plugin lines" {
    _config_venv
    _load_pure_python
    rm -f .envrc
    run compose_envrc .envrc
    [ "$status" -eq 0 ]
    [ -f .envrc ]
    grep -qF '# >>> pyve:managed:start >>>' .envrc
    grep -qF '# <<< pyve:managed:end <<<' .envrc
    grep -qF 'PATH_add ".venv/bin"' .envrc
}

@test "fresh scaffold: emits an invitation comment below the end marker" {
    _config_venv
    _load_pure_python
    rm -f .envrc
    compose_envrc .envrc
    # Content below the end marker is the user region.
    local below
    below="$(awk 'f{print} /# <<< pyve:managed:end <<</{f=1}' .envrc)"
    [[ "$below" == *"below"* ]] || [[ "$below" == *"your own"* ]] || [[ "$below" == *"Add"* ]]
}

@test "fresh scaffold: no .envrc.prev when there was no prior file" {
    _config_venv
    _load_pure_python
    rm -f .envrc .envrc.prev
    compose_envrc .envrc
    [ ! -f .envrc.prev ]
}

# ════════════════════════════════════════════════════════════════════
# User-content preservation + .prev backup.
# ════════════════════════════════════════════════════════════════════

@test "preservation: user content below the end marker round-trips verbatim" {
    _config_venv
    _load_pure_python
    # First compose to establish the managed shape.
    compose_envrc .envrc
    # User appends custom lines below the end marker.
    cat >> .envrc <<'EOF'
export MY_TOKEN="keepme"
source_env_if_exists .env.local
EOF
    # Re-compose; the user tail must survive.
    run compose_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF 'export MY_TOKEN="keepme"' .envrc
    grep -qF 'source_env_if_exists .env.local' .envrc
}

@test "backup: overwriting an existing .envrc creates .envrc.prev with the old content" {
    _config_venv
    _load_pure_python
    compose_envrc .envrc
    cat >> .envrc <<'EOF'
export SENTINEL_FOR_PREV="v1"
EOF
    local before
    before="$(cat .envrc)"
    compose_envrc .envrc
    [ -f .envrc.prev ]
    [ "$(cat .envrc.prev)" = "$before" ]
}

@test "rollback: mv .envrc.prev .envrc restores the prior state" {
    _config_venv
    _load_pure_python
    compose_envrc .envrc
    printf 'export ROLLBACK_ME="yes"\n' >> .envrc
    local before
    before="$(cat .envrc)"
    compose_envrc .envrc          # produces .prev = before
    mv -f .envrc.prev .envrc      # documented one-step rollback
    [ "$(cat .envrc)" = "$before" ]
}

@test "idempotence: composing twice is stable (no user additions)" {
    _config_venv
    _load_pure_python
    compose_envrc .envrc
    local first
    first="$(cat .envrc)"
    compose_envrc .envrc
    [ "$(cat .envrc)" = "$first" ]
}

# ════════════════════════════════════════════════════════════════════
# Atomic-write failure leaves the existing file untouched.
# ════════════════════════════════════════════════════════════════════

@test "atomic failure: a smuggling plugin section leaves the existing .envrc untouched" {
    _config_venv
    _load_polyglot
    # A valid existing .envrc.
    compose_envrc .envrc
    local before
    before="$(cat .envrc)"
    rm -f .envrc.prev .envrc.tmp

    # Now make node smuggle command substitution.
    _node_pyve_plugin_envrc_snippet() {
        printf '# >>> pyve:plugin:node:activate >>>\nPATH_add "$(whoami)"\n# <<< pyve:plugin:node:activate <<<\n'
    }
    run compose_envrc .envrc
    [ "$status" -ne 0 ]
    # Existing file unchanged; no half-written tmp or spurious backup left.
    [ "$(cat .envrc)" = "$before" ]
    [ ! -f .envrc.tmp ]
    [ ! -f .envrc.prev ]
}

# ════════════════════════════════════════════════════════════════════
# Legacy .envrc (no managed markers) — replaced, but backed up.
# ════════════════════════════════════════════════════════════════════

@test "legacy .envrc (no markers): replaced with managed section + backed up to .prev" {
    _config_venv
    _load_pure_python
    cat > .envrc <<'EOF'
# hand-written legacy .envrc
PATH_add ".venv/bin"
export LEGACY="1"
EOF
    local before
    before="$(cat .envrc)"
    run compose_envrc .envrc
    [ "$status" -eq 0 ]
    grep -qF '# >>> pyve:managed:start >>>' .envrc
    # The legacy content is preserved in the backup for recovery.
    [ -f .envrc.prev ]
    [ "$(cat .envrc.prev)" = "$before" ]
}
