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
