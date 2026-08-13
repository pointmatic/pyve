#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Consumption of the two capabilities project-guide 2.21.0 took ownership of,
# each replacing a guess pyve used to make on project-guide's behalf:
#
#   `completion install`  — pyve no longer hand-writes a Click completion
#                           snippet (and no longer models compdef/compinit).
#   `init --pyve-version` — pyve supplies its own version instead of letting
#                           project-guide probe a bare `pyve` on PATH, whose
#                           failure silently stripped the Pyve guidance from
#                           the rendered go.md.
#
# Both are version-gated, so both paths (new + fallback) are covered here.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir

    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    unset PYVE_PROJECT_GUIDE PYVE_NO_PROJECT_GUIDE
    unset PYVE_PROJECT_GUIDE_COMPLETION PYVE_NO_PROJECT_GUIDE_COMPLETION
    unset CI PYVE_FORCE_YES PYVE_PROJECT_GUIDE_BIN

    # Never let a test trigger real provisioning / network.
    pyve_project_guide_ensure() { return 0; }

    export SHELL=/bin/zsh
    PG_LOG="$TEST_DIR/pg.log"
    LEGACY_OPEN="# >>> project-guide completion (added by pyve) >>>"
    UPSTREAM_OPEN="# >>> project-guide completion >>>"
}

teardown() {
    cleanup_test_dir
}

# A hosted fake project-guide that reports <version> for --version and
# appends every other invocation's argv to the log. Version reporting has to
# be real: pyve_project_guide_version_at_least PROBES the artifact rather
# than trusting a recorded number.
_fake_pg() {
    local version="$1"
    # The gate memoizes per process; swapping the artifact under it is
    # exactly the case the reset seam exists for.
    pyve_project_guide_version_gate_reset
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/project-guide" << EOF
#!/bin/bash
if [[ "\$1" == "--version" ]]; then
    echo "project-guide, version $version"
    exit 0
fi
echo "\$@" >> "$PG_LOG"
exit 0
EOF
    chmod +x "$HOME/.local/bin/project-guide"
}

#============================================================
# Version gate
#============================================================

@test "version_at_least: true at the floor, above it, false below" {
    _fake_pg "2.21.0"
    run pyve_project_guide_version_at_least "2.21.0"
    [ "$status" -eq 0 ]

    _fake_pg "2.22.3"
    run pyve_project_guide_version_at_least "2.21.0"
    [ "$status" -eq 0 ]

    _fake_pg "2.18.1"
    run pyve_project_guide_version_at_least "2.21.0"
    [ "$status" -ne 0 ]
}

@test "version_at_least: false when project-guide cannot run at all" {
    # Existence is not runnability: an unrunnable artifact must read as
    # "too old" so callers fall back rather than invoking a subcommand
    # that may not exist.
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/bash\nexit 127\n' > "$HOME/.local/bin/project-guide"
    chmod +x "$HOME/.local/bin/project-guide"
    run pyve_project_guide_version_at_least "2.21.0"
    [ "$status" -ne 0 ]
}

#============================================================
# init --pyve-version handoff
#============================================================

@test "init: passes --pyve-version when project-guide is new enough" {
    _fake_pg "2.21.0"
    run_project_guide_init_in_env
    grep -qF -- "--pyve-version" "$PG_LOG"
    grep -qF -- "$VERSION" "$PG_LOG"
}

@test "init: omits --pyve-version on an older project-guide" {
    _fake_pg "2.18.1"
    run_project_guide_init_in_env
    grep -qF "init" "$PG_LOG"
    ! grep -qF -- "--pyve-version" "$PG_LOG"
}

@test "init: an empty arg is never passed when the flag is omitted" {
    # Regression on the bash 3.2 array-splat trap: "${arr[@]:-}" is the
    # idiom for READING a maybe-empty array, but as an argument splat it
    # expands to one empty string, which project-guide would see as a
    # bogus positional arg.
    _fake_pg "2.18.1"
    run_project_guide_init_in_env
    run cat "$PG_LOG"
    [[ "$output" == "init --no-input --quiet" ]]
}

#============================================================
# completion install delegation
#============================================================

@test "completion: delegates to 'completion install' with the stable shim path" {
    _fake_pg "2.21.0"
    _pg_completion_delegate "$HOME/.zshrc" zsh 1

    grep -qF "completion install" "$PG_LOG"
    grep -qF -- "--shell zsh" "$PG_LOG"
    # The shim, never the version-keyed toolchain console script — baking the
    # latter in is exactly the `stale` state upstream reports after a
    # DEFAULT_PYTHON_VERSION bump.
    grep -qF -- "--bin $HOME/.local/bin/project-guide" "$PG_LOG"
}

@test "completion: pyve's legacy block is removed and migrated without re-prompting" {
    _fake_pg "2.21.0"
    cat > "$HOME/.zshrc" << EOF
# user content
$LEGACY_OPEN
command -v project-guide >/dev/null 2>&1 && true
# <<< project-guide completion <<<
EOF
    # A prompt here would be a bug: the legacy block IS prior consent.
    prompt_install_project_guide_completion() { touch "$TEST_DIR/prompted"; return 1; }

    _pg_completion_delegate "$HOME/.zshrc" zsh 0

    [ ! -f "$TEST_DIR/prompted" ]
    ! grep -qF "$LEGACY_OPEN" "$HOME/.zshrc"
    grep -qF "# user content" "$HOME/.zshrc"
    grep -qF "completion install" "$PG_LOG"
}

@test "completion: already installed upstream → no prompt, no re-install" {
    _fake_pg "2.21.0"
    cat > "$HOME/.zshrc" << EOF
$UPSTREAM_OPEN
autoload -Uz _project-guide
# <<< project-guide completion <<<
EOF
    prompt_install_project_guide_completion() { touch "$TEST_DIR/prompted"; return 0; }

    _pg_completion_delegate "$HOME/.zshrc" zsh 0

    [ ! -f "$TEST_DIR/prompted" ]
    [ ! -f "$PG_LOG" ]
}

@test "completion: upstream sentinel and pyve's legacy sentinel never cross-match" {
    # The upstream open marker is NOT a substring of pyve's legacy one
    # (pyve's inserts "(added by pyve) " before the closing >>>), so a
    # legacy-only rc must not read as already-installed-by-upstream.
    printf '%s\n' "$LEGACY_OPEN" > "$HOME/.zshrc"
    run grep -qF "$UPSTREAM_OPEN" "$HOME/.zshrc"
    [ "$status" -ne 0 ]
}

@test "completion: declined at the prompt → nothing written, nothing invoked" {
    _fake_pg "2.21.0"
    prompt_install_project_guide_completion() { return 1; }

    _pg_completion_delegate "$HOME/.zshrc" zsh 0

    [ ! -f "$PG_LOG" ]
}

@test "completion: unknown shell degrades with manual guidance, no invocation" {
    _fake_pg "2.21.0"
    run _pg_completion_delegate "" unknown 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"project-guide completion install"* ]]
    [ ! -f "$PG_LOG" ]
}

@test "completion: falls back to pyve's own block on an older project-guide" {
    _fake_pg "2.18.1"
    run _pg_completion_upstream_available
    [ "$status" -ne 0 ]

    # The interim block stays available for that path.
    add_project_guide_completion "$HOME/.zshrc" zsh
    grep -qF "$LEGACY_OPEN" "$HOME/.zshrc"
}

@test "completion bin: prefers the shim, falls back to the resolver when absent" {
    _fake_pg "2.21.0"
    run _pg_completion_bin
    [ "$output" == "$HOME/.local/bin/project-guide" ]

    rm -f "$HOME/.local/bin/project-guide"
    run _pg_completion_bin
    [ -n "$output" ]
    [ "$output" != "$HOME/.local/bin/project-guide" ]
}

@test "version gate: probes once per process, then answers from cache" {
    # The probe forks (bounded-probe watchdog) and the gate sits on the
    # `pyve init` path, consulted for both completion wiring and the version
    # handoff. Re-probing per call buys nothing — the hosted project-guide
    # cannot change mid-invocation — and feeds CI fork pressure.
    local probe_log="$TEST_DIR/probes.log"
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/project-guide" << EOF2
#!/bin/bash
if [[ "\$1" == "--version" ]]; then
    echo probe >> "$probe_log"
    echo "project-guide, version 2.21.0"
    exit 0
fi
exit 0
EOF2
    chmod +x "$HOME/.local/bin/project-guide"
    pyve_project_guide_version_gate_reset

    pyve_project_guide_version_at_least "2.21.0"
    pyve_project_guide_version_at_least "2.21.0"
    pyve_project_guide_version_at_least "2.21.0"

    [ "$(wc -l < "$probe_log" | tr -d ' ')" -eq 1 ]
}
