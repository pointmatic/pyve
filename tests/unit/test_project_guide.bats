#!/usr/bin/env bats
#
# Unit tests for project-guide integration helpers in lib/utils.sh.
#
# Story G.c / FR-G2 — hook that installs project-guide during pyve init
# and optionally adds shell completion to the user's rc file.
#
# Helpers under test:
#   is_project_guide_installed(backend, env_path) → 0/1
#   install_project_guide(backend, env_path)       → 0/1
#   prompt_install_project_guide()                  → 0/1 (0=install, 1=skip)
#   detect_user_shell()                             → prints "zsh" | "bash" | "unknown"
#   get_shell_rc_path(shell)                        → prints "$HOME/.zshrc" | "$HOME/.bashrc" | ""
#   is_project_guide_completion_present(rc_path)    → 0/1
#   add_project_guide_completion(rc_path, shell)    → 0/1 (idempotent)
#   remove_project_guide_completion(rc_path)        → 0/1 (safe no-op if absent)
#   prompt_install_project_guide_completion()       → 0/1 (0=add, 1=skip;
#                                                    CI defaults to SKIP)
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir

    # Isolate $HOME so rc-file tests don't touch the real one.
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Clear env vars that would short-circuit prompts in CI.
    unset PYVE_PROJECT_GUIDE PYVE_NO_PROJECT_GUIDE
    unset PYVE_PROJECT_GUIDE_COMPLETION PYVE_NO_PROJECT_GUIDE_COMPLETION
    unset CI PYVE_FORCE_YES

    # Sentinel comments we test against — must match the real helper output.
    SENTINEL_OPEN="# >>> project-guide completion (added by pyve) >>>"
    SENTINEL_CLOSE="# <<< project-guide completion <<<"
}

teardown() {
    cleanup_test_dir
}

#============================================================
# prompt_install_project_guide — install flow trigger logic
#============================================================

@test "prompt_install_project_guide: PYVE_PROJECT_GUIDE=1 returns 0 (install)" {
    export PYVE_PROJECT_GUIDE=1
    run prompt_install_project_guide
    [ "$status" -eq 0 ]
}

@test "prompt_install_project_guide: PYVE_NO_PROJECT_GUIDE=1 returns 1 (skip)" {
    export PYVE_NO_PROJECT_GUIDE=1
    run prompt_install_project_guide
    [ "$status" -eq 1 ]
}

@test "prompt_install_project_guide: CI=1 returns 0 (install — CI default matches interactive default)" {
    export CI=1
    run prompt_install_project_guide
    [ "$status" -eq 0 ]
}

@test "prompt_install_project_guide: PYVE_FORCE_YES=1 returns 0 (install)" {
    export PYVE_FORCE_YES=1
    run prompt_install_project_guide
    [ "$status" -eq 0 ]
}

@test "prompt_install_project_guide: PYVE_NO_PROJECT_GUIDE=1 wins over PYVE_PROJECT_GUIDE=1" {
    export PYVE_PROJECT_GUIDE=1
    export PYVE_NO_PROJECT_GUIDE=1
    run prompt_install_project_guide
    [ "$status" -eq 1 ]
}

@test "prompt_install_project_guide: PYVE_NO_PROJECT_GUIDE=1 wins over CI=1" {
    export CI=1
    export PYVE_NO_PROJECT_GUIDE=1
    run prompt_install_project_guide
    [ "$status" -eq 1 ]
}

#============================================================
# prompt_install_project_guide_completion — CI-default asymmetry
#============================================================

@test "prompt_install_project_guide_completion: PYVE_PROJECT_GUIDE_COMPLETION=1 returns 0 (add)" {
    export PYVE_PROJECT_GUIDE_COMPLETION=1
    run prompt_install_project_guide_completion
    [ "$status" -eq 0 ]
}

@test "prompt_install_project_guide_completion: PYVE_NO_PROJECT_GUIDE_COMPLETION=1 returns 1 (skip)" {
    export PYVE_NO_PROJECT_GUIDE_COMPLETION=1
    run prompt_install_project_guide_completion
    [ "$status" -eq 1 ]
}

@test "prompt_install_project_guide_completion: CI=1 returns 1 (SKIP — deliberate asymmetry with install flow)" {
    export CI=1
    run prompt_install_project_guide_completion
    [ "$status" -eq 1 ]
}

@test "prompt_install_project_guide_completion: PYVE_FORCE_YES=1 returns 1 (SKIP — asymmetry)" {
    export PYVE_FORCE_YES=1
    run prompt_install_project_guide_completion
    [ "$status" -eq 1 ]
}

@test "prompt_install_project_guide_completion: PYVE_NO_PROJECT_GUIDE_COMPLETION wins over PYVE_PROJECT_GUIDE_COMPLETION" {
    export PYVE_PROJECT_GUIDE_COMPLETION=1
    export PYVE_NO_PROJECT_GUIDE_COMPLETION=1
    run prompt_install_project_guide_completion
    [ "$status" -eq 1 ]
}

#============================================================
# detect_user_shell — reads $SHELL, defaults to unknown
#============================================================

@test "detect_user_shell: SHELL=/bin/zsh returns 'zsh'" {
    SHELL="/bin/zsh" run detect_user_shell
    [ "$status" -eq 0 ]
    [[ "$output" == "zsh" ]]
}

@test "detect_user_shell: SHELL=/usr/bin/zsh returns 'zsh'" {
    SHELL="/usr/bin/zsh" run detect_user_shell
    [ "$status" -eq 0 ]
    [[ "$output" == "zsh" ]]
}

@test "detect_user_shell: SHELL=/bin/bash returns 'bash'" {
    SHELL="/bin/bash" run detect_user_shell
    [ "$status" -eq 0 ]
    [[ "$output" == "bash" ]]
}

@test "detect_user_shell: SHELL=/opt/homebrew/bin/bash returns 'bash'" {
    SHELL="/opt/homebrew/bin/bash" run detect_user_shell
    [ "$status" -eq 0 ]
    [[ "$output" == "bash" ]]
}

@test "detect_user_shell: SHELL=/usr/bin/fish returns 'unknown'" {
    SHELL="/usr/bin/fish" run detect_user_shell
    [ "$status" -eq 0 ]
    [[ "$output" == "unknown" ]]
}

@test "detect_user_shell: empty SHELL returns 'unknown'" {
    SHELL="" run detect_user_shell
    [ "$status" -eq 0 ]
    [[ "$output" == "unknown" ]]
}

#============================================================
# get_shell_rc_path — maps shell name to rc file
#============================================================

@test "get_shell_rc_path: 'zsh' returns \$HOME/.zshrc" {
    run get_shell_rc_path zsh
    [ "$status" -eq 0 ]
    [[ "$output" == "$HOME/.zshrc" ]]
}

@test "get_shell_rc_path: 'bash' returns \$HOME/.bashrc" {
    run get_shell_rc_path bash
    [ "$status" -eq 0 ]
    [[ "$output" == "$HOME/.bashrc" ]]
}

@test "get_shell_rc_path: 'unknown' returns empty string" {
    run get_shell_rc_path unknown
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "get_shell_rc_path: 'fish' returns empty string" {
    run get_shell_rc_path fish
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

#============================================================
# is_project_guide_completion_present — sentinel detection
#============================================================

@test "is_project_guide_completion_present: returns 1 for missing file" {
    run is_project_guide_completion_present "$HOME/.zshrc"
    [ "$status" -eq 1 ]
}

@test "is_project_guide_completion_present: returns 1 for file without sentinel" {
    cat > "$HOME/.zshrc" << 'EOF'
# My zsh config
alias ll='ls -lah'
export PATH="$HOME/bin:$PATH"
EOF
    run is_project_guide_completion_present "$HOME/.zshrc"
    [ "$status" -eq 1 ]
}

@test "is_project_guide_completion_present: returns 0 when sentinel is present" {
    cat > "$HOME/.zshrc" << EOF
# My zsh config
alias ll='ls -lah'

$SENTINEL_OPEN
command -v project-guide >/dev/null 2>&1 && \\
  eval "\$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
$SENTINEL_CLOSE
EOF
    run is_project_guide_completion_present "$HOME/.zshrc"
    [ "$status" -eq 0 ]
}

#============================================================
# add_project_guide_completion — idempotent, safe for missing files
#============================================================

@test "add_project_guide_completion: creates rc file if it does not exist" {
    [ ! -f "$HOME/.zshrc" ]
    run add_project_guide_completion "$HOME/.zshrc" zsh
    [ "$status" -eq 0 ]
    [ -f "$HOME/.zshrc" ]
    grep -qF "$SENTINEL_OPEN" "$HOME/.zshrc"
    grep -qF "$SENTINEL_CLOSE" "$HOME/.zshrc"
}

@test "add_project_guide_completion: inserts sentinel block with command -v guard (zsh)" {
    add_project_guide_completion "$HOME/.zshrc" zsh
    grep -qF "command -v project-guide" "$HOME/.zshrc"
    grep -qF "_PROJECT_GUIDE_COMPLETE=zsh_source" "$HOME/.zshrc"
}

@test "add_project_guide_completion: inserts sentinel block with command -v guard (bash)" {
    add_project_guide_completion "$HOME/.bashrc" bash
    grep -qF "command -v project-guide" "$HOME/.bashrc"
    grep -qF "_PROJECT_GUIDE_COMPLETE=bash_source" "$HOME/.bashrc"
}

@test "add_project_guide_completion: preserves existing content above and below" {
    cat > "$HOME/.zshrc" << 'EOF'
# Line 1
alias ll='ls -lah'
# Line 3
EOF
    add_project_guide_completion "$HOME/.zshrc" zsh
    grep -qxF "# Line 1" "$HOME/.zshrc"
    grep -qxF "alias ll='ls -lah'" "$HOME/.zshrc"
    grep -qxF "# Line 3" "$HOME/.zshrc"
    grep -qF "$SENTINEL_OPEN" "$HOME/.zshrc"
}

@test "add_project_guide_completion: idempotent — running twice produces one block" {
    add_project_guide_completion "$HOME/.zshrc" zsh
    add_project_guide_completion "$HOME/.zshrc" zsh

    local open_count
    open_count=$(grep -cF "$SENTINEL_OPEN" "$HOME/.zshrc")
    [ "$open_count" -eq 1 ]

    local close_count
    close_count=$(grep -cF "$SENTINEL_CLOSE" "$HOME/.zshrc")
    [ "$close_count" -eq 1 ]
}

#============================================================
# add_project_guide_completion — Story G.e regression tests
# Bug 1: literal '\n' instead of newline + line continuation
# Bug 2: SDKMan-blind append breaks SDKMan load order
#============================================================

@test "add_project_guide_completion: emits a real newline + backslash, not literal '\\n' (G.e bug 2)" {
    add_project_guide_completion "$HOME/.zshrc" zsh

    # The pre-G.e bug emitted the 2-char sequence (backslash + 'n')
    # in place of a real newline. Assert no literal backslash-n
    # appears anywhere in the file.
    ! grep -qF '\n' "$HOME/.zshrc"

    # The continuation line and the eval line must both exist as
    # SEPARATE lines. Use grep -nE to confirm the eval is on its
    # own line (not joined onto the &&\\ line).
    grep -qE '&& \\$' "$HOME/.zshrc"
    grep -qE '^  eval ' "$HOME/.zshrc"
}

@test "add_project_guide_completion: emitted block is syntactically valid zsh (G.e bug 2)" {
    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh not on PATH"
    fi
    add_project_guide_completion "$HOME/.zshrc" zsh
    zsh -n "$HOME/.zshrc"
}

@test "add_project_guide_completion: emitted block is syntactically valid bash (G.e bug 2)" {
    add_project_guide_completion "$HOME/.bashrc" bash
    bash -n "$HOME/.bashrc"
}

@test "add_project_guide_completion: SDKMan absent — block appended to end (G.e bug 1)" {
    cat > "$HOME/.zshrc" << 'EOF'
export PATH="/usr/local/bin:$PATH"
alias ll='ls -lah'
EOF
    add_project_guide_completion "$HOME/.zshrc" zsh

    # Sentinel block must be present and below the existing content.
    grep -qF "$SENTINEL_OPEN" "$HOME/.zshrc"
    local user_line sentinel_line
    user_line=$(grep -nF "alias ll=" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    sentinel_line=$(grep -nF "$SENTINEL_OPEN" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    [ "$user_line" -lt "$sentinel_line" ]
}

@test "add_project_guide_completion: SDKMan present — block inserted BEFORE the marker (G.e bug 1)" {
    cat > "$HOME/.zshrc" << 'EOF'
export PATH="/usr/local/bin:$PATH"
alias ll='ls -lah'

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
EOF
    add_project_guide_completion "$HOME/.zshrc" zsh

    # Sentinel must precede the SDKMan marker line.
    local sentinel_line sdkman_line
    sentinel_line=$(grep -nF "$SENTINEL_OPEN" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    sdkman_line=$(grep -nF "THIS MUST BE AT THE END" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    [ -n "$sentinel_line" ]
    [ -n "$sdkman_line" ]
    [ "$sentinel_line" -lt "$sdkman_line" ]
}

@test "add_project_guide_completion: SDKMan present — SDKMan section unchanged (G.e bug 1)" {
    cat > "$HOME/.zshrc" << 'EOF'
alias ll='ls -lah'

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
EOF
    add_project_guide_completion "$HOME/.zshrc" zsh

    # SDKMan marker and the two SDKMan lines below it must still be
    # present, in order, and the second SDKMan line must remain the
    # last non-blank line in the file.
    grep -qF "THIS MUST BE AT THE END" "$HOME/.zshrc"
    grep -qF 'SDKMAN_DIR="$HOME/.sdkman"' "$HOME/.zshrc"
    grep -qF "sdkman-init.sh" "$HOME/.zshrc"

    local last_nonblank
    last_nonblank=$(grep -v '^$' "$HOME/.zshrc" | tail -n 1)
    [[ "$last_nonblank" == *"sdkman-init.sh"* ]]
}

@test "add_project_guide_completion: SDKMan present — round-trip add+remove is byte-identical (G.e bug 1)" {
    cat > "$HOME/.zshrc" << 'EOF'
export PATH="/usr/local/bin:$PATH"
alias ll='ls -lah'

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
EOF
    local before
    before="$(cat "$HOME/.zshrc")"

    add_project_guide_completion "$HOME/.zshrc" zsh
    remove_project_guide_completion "$HOME/.zshrc"

    local after
    after="$(cat "$HOME/.zshrc")"
    [[ "$before" == "$after" ]]
}

#============================================================
# insert_text_before_sdkman_marker_or_append — Story G.e helper
# Shared SDKMan-aware insertion used by both install_prompt_hook
# and add_project_guide_completion.
#============================================================

@test "insert_text_before_sdkman_marker_or_append: SDKMan absent — appends to end" {
    cat > "$HOME/.zshrc" << 'EOF'
existing_line
EOF
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "new_line"

    grep -qxF "existing_line" "$HOME/.zshrc"
    grep -qxF "new_line" "$HOME/.zshrc"
    local last
    last=$(tail -n 1 "$HOME/.zshrc")
    [[ "$last" == "new_line" ]]
}

@test "insert_text_before_sdkman_marker_or_append: SDKMan present — inserts above marker" {
    cat > "$HOME/.zshrc" << 'EOF'
line_a
line_b

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
sdkman_payload
EOF
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "inserted_line"

    grep -qxF "inserted_line" "$HOME/.zshrc"
    local inserted_lineno marker_lineno
    inserted_lineno=$(grep -nF "inserted_line" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    marker_lineno=$(grep -nF "THIS MUST BE AT THE END" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    [ "$inserted_lineno" -lt "$marker_lineno" ]

    # SDKMan payload must remain after the marker.
    grep -qxF "sdkman_payload" "$HOME/.zshrc"
}

@test "insert_text_before_sdkman_marker_or_append: empty file — content becomes the only content" {
    : > "$HOME/.zshrc"
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "only_line"

    grep -qxF "only_line" "$HOME/.zshrc"
    [ "$(wc -l < "$HOME/.zshrc")" -eq 1 ]
}

@test "insert_text_before_sdkman_marker_or_append: missing file — creates it" {
    [ ! -f "$HOME/.zshrc" ]
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "fresh_line"
    [ -f "$HOME/.zshrc" ]
    grep -qxF "fresh_line" "$HOME/.zshrc"
}

@test "insert_text_before_sdkman_marker_or_append: multi-line content preserved verbatim" {
    cat > "$HOME/.zshrc" << 'EOF'
existing
EOF
    local block
    block="$(printf 'line_one\nline_two\nline_three\n')"
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "$block"

    grep -qxF "line_one" "$HOME/.zshrc"
    grep -qxF "line_two" "$HOME/.zshrc"
    grep -qxF "line_three" "$HOME/.zshrc"

    # Order: existing → line_one → line_two → line_three
    local existing_n one_n two_n three_n
    existing_n=$(grep -nxF "existing" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    one_n=$(grep -nxF "line_one" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    two_n=$(grep -nxF "line_two" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    three_n=$(grep -nxF "line_three" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    [ "$existing_n" -lt "$one_n" ]
    [ "$one_n" -lt "$two_n" ]
    [ "$two_n" -lt "$three_n" ]
}

@test "insert_text_before_sdkman_marker_or_append: SDKMan present — multi-line block lands above marker" {
    cat > "$HOME/.zshrc" << 'EOF'
user_line
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
sdkman_init
EOF
    local block
    block="$(printf 'block_a\nblock_b\nblock_c\n')"
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "$block"

    local a_n marker_n
    a_n=$(grep -nxF "block_a" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    marker_n=$(grep -nF "THIS MUST BE AT THE END" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    [ "$a_n" -lt "$marker_n" ]
    grep -qxF "sdkman_init" "$HOME/.zshrc"
}

@test "insert_text_before_sdkman_marker_or_append: SDKMan present — blank line precedes marker (H.a bug 3)" {
    # Story H.a bug 3: the inserted block must be separated from the SDKMan
    # marker by a blank line so the two aren't visually cramped.
    cat > "$HOME/.zshrc" << 'EOF'
alias ll='ls -lah'

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
EOF
    insert_text_before_sdkman_marker_or_append "$HOME/.zshrc" "inserted_line"

    # The line immediately before the SDKMan marker must be blank.
    local marker_lineno prev_line
    marker_lineno=$(grep -nF "THIS MUST BE AT THE END" "$HOME/.zshrc" | head -1 | cut -d: -f1)
    prev_line=$(sed -n "$((marker_lineno - 1))p" "$HOME/.zshrc")
    [ -z "$prev_line" ]
}

#============================================================
# remove_project_guide_completion — surgical removal
#============================================================

@test "remove_project_guide_completion: safe no-op for missing file" {
    [ ! -f "$HOME/.zshrc" ]
    run remove_project_guide_completion "$HOME/.zshrc"
    [ "$status" -eq 0 ]
}

@test "remove_project_guide_completion: safe no-op for file without sentinel" {
    cat > "$HOME/.zshrc" << 'EOF'
# My zsh config
alias ll='ls -lah'
EOF
    run remove_project_guide_completion "$HOME/.zshrc"
    [ "$status" -eq 0 ]
    grep -qxF "# My zsh config" "$HOME/.zshrc"
    grep -qxF "alias ll='ls -lah'" "$HOME/.zshrc"
}

@test "remove_project_guide_completion: removes only the sentinel block, preserves other lines" {
    cat > "$HOME/.zshrc" << EOF
# Line before
alias ll='ls -lah'

$SENTINEL_OPEN
command -v project-guide >/dev/null 2>&1 && \\
  eval "\$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
$SENTINEL_CLOSE

# Line after
export FOO=bar
EOF
    run remove_project_guide_completion "$HOME/.zshrc"
    [ "$status" -eq 0 ]

    grep -qxF "# Line before" "$HOME/.zshrc"
    grep -qxF "alias ll='ls -lah'" "$HOME/.zshrc"
    grep -qxF "# Line after" "$HOME/.zshrc"
    grep -qxF "export FOO=bar" "$HOME/.zshrc"

    # Sentinel block and its contents must be gone.
    ! grep -qF "$SENTINEL_OPEN" "$HOME/.zshrc"
    ! grep -qF "$SENTINEL_CLOSE" "$HOME/.zshrc"
    ! grep -qF "_PROJECT_GUIDE_COMPLETE" "$HOME/.zshrc"
}

@test "remove_project_guide_completion: add then remove restores original content" {
    cat > "$HOME/.zshrc" << 'EOF'
# Line 1
alias ll='ls -lah'
EOF
    local before
    before="$(cat "$HOME/.zshrc")"

    add_project_guide_completion "$HOME/.zshrc" zsh
    remove_project_guide_completion "$HOME/.zshrc"

    local after
    after="$(cat "$HOME/.zshrc")"
    [[ "$before" == "$after" ]]
}

#============================================================
# is_project_guide_installed — probe via env's python
#============================================================

@test "is_project_guide_installed: returns 1 for nonexistent env path (venv)" {
    run is_project_guide_installed "venv" "$TEST_DIR/nonexistent-venv"
    [ "$status" -eq 1 ]
}

@test "is_project_guide_installed: returns 1 for venv without python binary" {
    mkdir -p "$TEST_DIR/fake-venv/bin"
    run is_project_guide_installed "venv" "$TEST_DIR/fake-venv"
    [ "$status" -eq 1 ]
}

#============================================================
# project_guide_in_project_deps — auto-skip detection
#============================================================

@test "project_guide_in_project_deps: returns 1 with no dep files" {
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: detects pyproject.toml [project] dependencies" {
    cat > pyproject.toml << 'EOF'
[project]
name = "myapp"
dependencies = [
    "requests",
    "project-guide==2.0.20",
]
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: detects pyproject.toml without version pin" {
    cat > pyproject.toml << 'EOF'
[project]
dependencies = ["project-guide"]
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: detects pyproject.toml [tool.poetry.dependencies]" {
    cat > pyproject.toml << 'EOF'
[tool.poetry.dependencies]
python = "^3.10"
project-guide = "^2.0"
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: pyproject.toml without project-guide returns 1" {
    cat > pyproject.toml << 'EOF'
[project]
name = "myapp"
dependencies = ["requests", "click"]
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: pyproject.toml with similar-named package returns 1" {
    cat > pyproject.toml << 'EOF'
[project]
dependencies = ["project-guide-extras"]
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: pyproject.toml comment-only line returns 1" {
    cat > pyproject.toml << 'EOF'
# project-guide==2.0.20  is something we considered but rejected
[project]
dependencies = ["requests"]
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: detects requirements.txt with version" {
    cat > requirements.txt << 'EOF'
requests>=2.28
project-guide==2.0.20
flask
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: detects requirements.txt without version" {
    cat > requirements.txt << 'EOF'
project-guide
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: requirements.txt with similar-named package returns 1" {
    cat > requirements.txt << 'EOF'
project-guide-extras
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: requirements.txt comment-only line returns 1" {
    cat > requirements.txt << 'EOF'
# project-guide==2.0.20
requests
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: detects environment.yml conda dep" {
    cat > environment.yml << 'EOF'
name: myenv
channels:
  - conda-forge
dependencies:
  - python=3.11
  - project-guide
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: detects environment.yml pip nested dep" {
    cat > environment.yml << 'EOF'
name: myenv
dependencies:
  - python=3.11
  - pip
  - pip:
    - project-guide==2.0.20
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 0 ]
}

@test "project_guide_in_project_deps: environment.yml without project-guide returns 1" {
    cat > environment.yml << 'EOF'
name: myenv
dependencies:
  - python=3.11
  - numpy
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

@test "project_guide_in_project_deps: environment.yml comment-only line returns 1" {
    cat > environment.yml << 'EOF'
# project-guide considered but not added yet
name: myenv
dependencies:
  - python=3.11
EOF
    run project_guide_in_project_deps
    [ "$status" -eq 1 ]
}

#============================================================
# install_project_guide — uses --upgrade
#============================================================

@test "install_project_guide: passes --upgrade to pip" {
    # Build a fake venv with a fake pip that records its arguments.
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"

    cat > "$fake_venv/bin/pip" << EOF
#!/bin/bash
echo "\$@" > "$TEST_DIR/pip-args.log"
exit 0
EOF
    chmod +x "$fake_venv/bin/pip"

    # Stub python so is_project_guide_installed returns 1 (not installed),
    # so install_project_guide proceeds to call pip.
    cat > "$fake_venv/bin/python" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$fake_venv/bin/python"

    run install_project_guide "venv" "$fake_venv"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/pip-args.log" ]
    grep -qF "install --upgrade project-guide" "$TEST_DIR/pip-args.log"
}

#============================================================
# run_project_guide_init_in_env — invokes project-guide init --no-input
#============================================================

@test "run_project_guide_init_in_env: passes --no-input to project-guide init" {
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"

    cat > "$fake_venv/bin/project-guide" << EOF
#!/bin/bash
echo "\$@" > "$TEST_DIR/pg-args.log"
exit 0
EOF
    chmod +x "$fake_venv/bin/project-guide"

    run run_project_guide_init_in_env "venv" "$fake_venv"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/pg-args.log" ]
    grep -qF "init --no-input" "$TEST_DIR/pg-args.log"
}

@test "run_project_guide_init_in_env: safe no-op when binary missing" {
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"
    # No project-guide binary

    run run_project_guide_init_in_env "venv" "$fake_venv"
    [ "$status" -eq 0 ]  # Always returns 0 (failure non-fatal)
}

@test "run_project_guide_init_in_env: failure-non-fatal when binary fails" {
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"

    cat > "$fake_venv/bin/project-guide" << 'EOF'
#!/bin/bash
exit 17
EOF
    chmod +x "$fake_venv/bin/project-guide"

    run run_project_guide_init_in_env "venv" "$fake_venv"
    [ "$status" -eq 0 ]  # Returns 0 even when project-guide exits non-zero
}

#============================================================
# run_project_guide_update_in_env — invokes project-guide update --no-input
#============================================================

@test "run_project_guide_update_in_env: passes --no-input to project-guide update" {
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"

    cat > "$fake_venv/bin/project-guide" << EOF
#!/bin/bash
echo "\$@" > "$TEST_DIR/pg-update-args.log"
exit 0
EOF
    chmod +x "$fake_venv/bin/project-guide"

    run run_project_guide_update_in_env "venv" "$fake_venv"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/pg-update-args.log" ]
    grep -qF "update --no-input" "$TEST_DIR/pg-update-args.log"
}

@test "run_project_guide_update_in_env: safe no-op when binary missing" {
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"
    # No project-guide binary

    run run_project_guide_update_in_env "venv" "$fake_venv"
    [ "$status" -eq 0 ]  # Always returns 0 (failure non-fatal)
}

@test "run_project_guide_update_in_env: failure-non-fatal when binary fails" {
    local fake_venv="$TEST_DIR/fake-venv"
    mkdir -p "$fake_venv/bin"

    cat > "$fake_venv/bin/project-guide" << 'EOF'
#!/bin/bash
exit 3
EOF
    chmod +x "$fake_venv/bin/project-guide"

    run run_project_guide_update_in_env "venv" "$fake_venv"
    [ "$status" -eq 0 ]  # Non-fatal: exits 0 even on update failure (incl. future SchemaVersionError)
}
