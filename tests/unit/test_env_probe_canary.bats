#!/usr/bin/env bats
# bats file_tags=check
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Per-env runnability probe (canary): plugins own a minimal console-script
# probe `pyve check` executes against every declared + materialized env.
#
# The false green this closes: a relocated-unrepaired env keeps a valid
# `bin/python` symlink while every console-script wrapper carries a dead
# baked shebang — `python -c 'import pytest'` (and any `python -m …`)
# bypasses the wrappers, so check reported healthy for an env whose every
# entry point failed with `bad interpreter`. The canary executes a WRAPPER
# (`bin/pip --version`), classifies the failure, and check renders the
# verdict with a role-correct rebuild hint (root → `pyve init --force`,
# named → `pyve env init <name> --force`; never `pyve env purge root`).
#
# Verdict vocabulary (printed by the env_probe hook, consumed by check now
# and the heal mechanism later):
#   runnable [<ver>] | dead-shebang | dangling-symlink | missing-interpreter
#   | broken | not-materialized | advisory
# Orphans (materialized-but-undeclared, or declared-advisory-yet-
# materialized) come from a separate manifest↔disk reconciliation pass.

load ../helpers/test_helper

setup() {
    setup_pyve_env
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/envs.sh"
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/commands/env.sh"
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    create_test_dir

    export TESTENV_DIR_NAME="testenv"
    export DEFAULT_VENV_DIR=".venv"
}

teardown() {
    cleanup_test_dir
}

# ---------- fixtures ----------

# Healthy env at <dir>: runnable python + a pip wrapper answering --version.
_mk_env_healthy() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\necho "Python 3.12.0"\nexit 0\n' > "$1/bin/python"
    printf '#!/usr/bin/env bash\necho "pip 25.1 from /x/site-packages/pip (python 3.12)"\n' > "$1/bin/pip"
    chmod +x "$1/bin/python" "$1/bin/pip"
}

# The field shape: valid python, pip wrapper whose baked shebang points at
# a deleted interpreter (relocated-unrepaired env).
_mk_env_dead_pip() {
    mkdir -p "$1/bin"
    printf '#!/usr/bin/env bash\necho "Python 3.12.0"\nexit 0\n' > "$1/bin/python"
    chmod +x "$1/bin/python"
    printf '#!%s/gone/bin/python\n' "$PWD" > "$1/bin/pip"
    chmod +x "$1/bin/pip"
}

_manifest_with_smoke() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.smoke]
purpose = "test"
backend = "venv"
TOML
}

_manifest_root_venv() {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "venv"
TOML
}

# Capture the _check_* closure calls (mirrors test_env_root_routing.bats).
_stub_check_closures() {
    _check_pass() { printf 'PASS:%s\n' "$*"; }
    _check_warn() { printf 'WARN:%s\n' "$*"; }
    _check_fail() { printf 'FAIL:%s\n' "$*"; }
}

# ============================================================
# Contract: optional hook, silent no-op default
# ============================================================

@test "contract: pyve_plugin_default_env_probe exists, prints nothing, rc 0" {
    run pyve_plugin_default_env_probe anything
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "contract: plugin_dispatch falls back to the no-op default for a plugin without the hook" {
    run plugin_dispatch node env_probe smoke
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ============================================================
# Probe classification — named venv env
# ============================================================

@test "probe: healthy named env → 'runnable <ver>' (probes the pip wrapper)" {
    _manifest_with_smoke
    _mk_env_healthy .pyve/envs/smoke/venv
    run python_pyve_plugin_env_probe smoke
    [ "$status" -eq 0 ]
    [[ "$output" == "runnable 25.1" ]]
}

@test "probe: dead-shebang pip wrapper with a valid python → 'dead-shebang' (the false-green killer)" {
    _manifest_with_smoke
    _mk_env_dead_pip .pyve/envs/smoke/venv
    run python_pyve_plugin_env_probe smoke
    [ "$status" -ne 0 ]
    [[ "$output" == "dead-shebang" ]]
}

@test "probe: dangling python symlink → 'dangling-symlink'" {
    _manifest_with_smoke
    mkdir -p .pyve/envs/smoke/venv/bin
    ln -s "$PWD/gone/bin/python" .pyve/envs/smoke/venv/bin/python
    printf '#!/usr/bin/env bash\necho pip\n' > .pyve/envs/smoke/venv/bin/pip
    chmod +x .pyve/envs/smoke/venv/bin/pip
    run python_pyve_plugin_env_probe smoke
    [ "$status" -ne 0 ]
    [[ "$output" == "dangling-symlink" ]]
}

@test "probe: no interpreter in the env → 'missing-interpreter'" {
    _manifest_with_smoke
    mkdir -p .pyve/envs/smoke/venv/bin
    printf '#!/usr/bin/env bash\necho pip\n' > .pyve/envs/smoke/venv/bin/pip
    chmod +x .pyve/envs/smoke/venv/bin/pip
    run python_pyve_plugin_env_probe smoke
    [ "$status" -ne 0 ]
    [[ "$output" == "missing-interpreter" ]]
}

@test "probe: declared but not materialized → 'not-materialized' (no probe, rc 0)" {
    _manifest_with_smoke
    run python_pyve_plugin_env_probe smoke
    [ "$status" -eq 0 ]
    [[ "$output" == "not-materialized" ]]
}

@test "probe: advisory backend → 'advisory' (declarative-only, no probe)" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.tools]
purpose = "utility"
backend = "none"
TOML
    run python_pyve_plugin_env_probe tools
    [ "$status" -eq 0 ]
    [[ "$output" == "advisory" ]]
}

@test "probe: interpreter-only env (no pip wrapper) → 'runnable' via the python fallback" {
    # Minimal fixture envs (and --without-pip venvs) carry no wrapper to
    # probe; a runnable interpreter is not condemned. The canary's target
    # class is a PRESENT-but-dead wrapper.
    _manifest_with_smoke
    mkdir -p .pyve/envs/smoke/venv/bin
    printf '#!/usr/bin/env bash\necho "Python 3.12.0"\nexit 0\n' > .pyve/envs/smoke/venv/bin/python
    chmod +x .pyve/envs/smoke/venv/bin/python
    run python_pyve_plugin_env_probe smoke
    [ "$status" -eq 0 ]
    [[ "$output" == "runnable" ]]
}

@test "probe: wedged wrapper is killed by the bounded runtime → 'broken' (no hang)" {
    _manifest_with_smoke
    mkdir -p .pyve/envs/smoke/venv/bin
    printf '#!/usr/bin/env bash\necho "Python 3.12.0"\nexit 0\n' > .pyve/envs/smoke/venv/bin/python
    printf '#!/usr/bin/env bash\nsleep 30\n' > .pyve/envs/smoke/venv/bin/pip
    chmod +x .pyve/envs/smoke/venv/bin/python .pyve/envs/smoke/venv/bin/pip
    export PYVE_PROBE_TIMEOUT=1
    local start end
    start=$SECONDS
    run python_pyve_plugin_env_probe smoke
    end=$SECONDS
    [ "$status" -ne 0 ]
    [[ "$output" == "broken" ]]
    # Bounded: nowhere near the wrapper's 30s sleep.
    [ $((end - start)) -lt 10 ]
}

# ============================================================
# Probe — root env, both backends
# ============================================================

@test "probe: healthy venv root → 'runnable <ver>'" {
    _manifest_root_venv
    _mk_env_healthy .venv
    run python_pyve_plugin_env_probe root
    [ "$status" -eq 0 ]
    [[ "$output" == "runnable 25.1" ]]
}

@test "probe: venv root with dead-shebang pip → 'dead-shebang'" {
    _manifest_root_venv
    _mk_env_dead_pip .venv
    run python_pyve_plugin_env_probe root
    [ "$status" -ne 0 ]
    [[ "$output" == "dead-shebang" ]]
}

@test "probe: micromamba root falls back to direct wrapper exec when micromamba is absent" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
TOML
    _mk_env_healthy .pyve/envs/root/conda
    get_micromamba_path() { return 1; }
    run python_pyve_plugin_env_probe root
    [ "$status" -eq 0 ]
    [[ "$output" == "runnable 25.1" ]]
}

@test "probe: micromamba root routes through 'micromamba run -p' when available" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "micromamba"
TOML
    _mk_env_healthy .pyve/envs/root/conda
    cat > fake-mm <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > mm-args.txt
echo "pip 25.1 from /conda (python 3.12)"
SH
    chmod +x fake-mm
    get_micromamba_path() { printf '%s' "$PWD/fake-mm"; }
    run python_pyve_plugin_env_probe root
    [ "$status" -eq 0 ]
    [[ "$output" == "runnable 25.1" ]]
    [[ -f mm-args.txt ]]
    grep -q "run -p .*conda pip --version" mm-args.txt
}

# ============================================================
# check rendering — _check_default_testenv routes by canary verdict
# ============================================================

@test "check testenv: dead-shebang pip → console-scripts-broken WARN + rebuild verb, never a pytest false green" {
    _manifest_with_smoke
    _mk_env_dead_pip .pyve/envs/testenv/venv
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"console scripts"* ]]
    [[ "$output" == *"pyve env init testenv --force"* ]]
    [[ "$output" != *"pytest installed"* ]]
}

@test "check testenv: healthy env with a pytest wrapper → pass" {
    _manifest_with_smoke
    _mk_env_healthy .pyve/envs/testenv/venv
    printf '#!/usr/bin/env bash\necho "pytest 8.0.0"\n' > .pyve/envs/testenv/venv/bin/pytest
    chmod +x .pyve/envs/testenv/venv/bin/pytest
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"PASS:"* ]]
    [[ "$output" == *"pytest installed"* ]]
}

@test "check testenv: healthy env without pytest → 'pyve test' route (unchanged)" {
    _manifest_with_smoke
    _mk_env_healthy .pyve/envs/testenv/venv
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"pyve test"* ]]
    [[ "$output" != *"--force"* ]]
}

@test "check testenv: DEAD pytest wrapper is not 'installed' — routed to the rebuild verb" {
    _manifest_with_smoke
    _mk_env_healthy .pyve/envs/testenv/venv
    printf '#!%s/gone/bin/python\n' "$PWD" > .pyve/envs/testenv/venv/bin/pytest
    chmod +x .pyve/envs/testenv/venv/bin/pytest
    _stub_check_closures
    run _check_default_testenv
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"pyve env init testenv --force"* ]]
    [[ "$output" != *"pytest installed"* ]]
}

# ============================================================
# check rendering — root canary is role-correct
# ============================================================

@test "check root: dead-shebang pip in .venv → console-scripts-broken FAIL + 'pyve init --force', never 'pyve env purge root'" {
    _manifest_root_venv
    _mk_env_dead_pip .venv
    cat > .venv/pyvenv.cfg <<EOF
home = $PWD/.venv/bin
EOF
    _stub_check_closures
    doctor_check_venv_path() { :; }
    doctor_check_duplicate_dist_info() { :; }
    doctor_check_collision_artifacts() { :; }
    run _check_venv_backend .venv
    [[ "$output" == *"FAIL:"* ]]
    [[ "$output" == *"console scripts"* ]]
    [[ "$output" == *"pyve init --force"* ]]
    [[ "$output" != *"pyve env purge root"* ]]
}

@test "check root: healthy .venv → canary pass line" {
    _manifest_root_venv
    _mk_env_healthy .venv
    _stub_check_closures
    doctor_check_venv_path() { :; }
    doctor_check_duplicate_dist_info() { :; }
    doctor_check_collision_artifacts() { :; }
    run _check_venv_backend .venv
    [[ "$output" == *"PASS:"* ]]
    [[ "$output" == *"runnable"* ]]
    [[ "$output" != *"FAIL:"* ]]
}

# ============================================================
# check rendering — declared named envs beyond testenv
# ============================================================

@test "check named envs: broken declared env is probed and routed to its own rebuild verb" {
    _manifest_with_smoke
    _mk_env_dead_pip .pyve/envs/smoke/venv
    _stub_check_closures
    run _check_declared_envs
    [[ "$output" == *"smoke"* ]]
    [[ "$output" == *"console scripts"* ]]
    [[ "$output" == *"pyve env init smoke --force"* ]]
}

@test "check named envs: declared-but-not-materialized stays silent (empty-until-demand)" {
    _manifest_with_smoke
    _stub_check_closures
    run _check_declared_envs
    [ -z "$output" ]
}

# ============================================================
# Orphan reconciliation — manifest↔disk contradictions
# ============================================================

@test "orphans: materialized env with no declaration → flagged with its name" {
    _manifest_root_venv
    _mk_env_healthy .pyve/envs/stray/venv
    manifest_load
    _stub_check_closures
    run _check_env_orphans
    [[ "$output" == *"stray"* ]]
    [[ "$output" == *"orphan"* ]]
}

@test "orphans: a state-only env dir (no backend subdir) is not an orphan" {
    _manifest_root_venv
    mkdir -p .pyve/envs/bookkeeping
    printf 'provisioned_at=1\n' > .pyve/envs/bookkeeping/.state
    manifest_load
    _stub_check_closures
    run _check_env_orphans
    [ -z "$output" ]
}

@test "orphans: declared advisory root that is nonetheless materialized → contradiction flagged" {
    cat > pyve.toml <<'TOML'
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
backend = "none"
TOML
    _mk_env_healthy .pyve/envs/root/conda
    manifest_load
    _stub_check_closures
    run _check_env_orphans
    [[ "$output" == *"root"* ]]
    [[ "$output" == *"none"* ]]
    [[ "$output" == *"materialized"* ]]
}

@test "orphans: fully declared project → silent" {
    _manifest_with_smoke
    _mk_env_healthy .pyve/envs/smoke/venv
    manifest_load
    _stub_check_closures
    run _check_env_orphans
    [ -z "$output" ]
}

# ============================================================
# list_materialized_env_names (lib/envs.sh)
# ============================================================

@test "list_materialized_env_names: names envs with a backend subdir, skips state-only dirs" {
    mkdir -p .pyve/envs/a/venv .pyve/envs/b/conda .pyve/envs/c
    printf 'x\n' > .pyve/envs/c/.state
    run list_materialized_env_names
    [ "$status" -eq 0 ]
    [[ "$output" == *"a"* ]]
    [[ "$output" == *"b"* ]]
    [[ "$output" != *"c"* ]]
}

@test "list_materialized_env_names: empty when .pyve/envs is absent" {
    run list_materialized_env_names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
