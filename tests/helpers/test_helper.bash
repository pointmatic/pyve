#!/usr/bin/env bash
#
# Bats Test Helper Functions
# Shared utilities for Bats unit tests
#

# Setup function to source pyve modules
setup_pyve_env() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_DIR="$PYVE_ROOT"
    
    # Source all lib modules. ui/core.sh + ui/run.sh come first because
    # utils.sh now calls run_quiet() (Story L.j) for quiet-on-success
    # subprocess invocation.
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/ui/run.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    # tests that exercise selectors which consult the v3
    # manifest (e.g. lib/plugins/python/plugin.sh's purpose gate) need
    # manifest_resolve_purpose available. Adding to the default helper
    # so every test file inherits it without per-file source bloat.
    source "$PYVE_ROOT/lib/manifest.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    # manifest_load / read_env_config now resolve Pyve's
    # toolchain interpreter via pyve_toolchain_python. Source it here (after
    # env_detect, mirroring pyve.sh) so every helper-using suite has the
    # resolver defined; without it the rewired callsites hit "command not
    # found". The override path (PYVE_PYTHON) is unaffected.
    source "$PYVE_ROOT/lib/toolchain_python.sh"
    # backend_detect.sh's detect_backend_from_files now
    # delegates to the Python plugin's detect hook via plugin_dispatch.
    # Source the plugin chain before backend_detect so every existing
    # test that calls detect_backend_from_files inherits the new chain
    # without per-file source bloat (mirrors the N.d note for
    # manifest_resolve_purpose).
    source "$PYVE_ROOT/lib/plugins/contract.sh"
    source "$PYVE_ROOT/lib/plugins/registry.sh"
    source "$PYVE_ROOT/lib/plugins/backend_registry.sh"
    # the Python plugin's gitignore_entries output runs
    # through validate_gitignore_snippet, invoked by
    # the gitignore composer. Source envrc_safety.sh before the plugin so
    # the validator is available when the plugin file is sourced/called.
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    # init_project calls run_project_guide_orchestration
    # (lib/project_guide.sh). Source it before the Python plugin so tests
    # that drive init_project have the orchestration defined.
    source "$PYVE_ROOT/lib/project_guide.sh"
    # The Python plugin's init wizard / valid-flag list build the parameter
    # decision-graph (pg_* helpers). Source param_graph.sh before the plugin,
    # mirroring pyve.sh's sourcing order, so every helper-using suite has the
    # engine defined without per-file source bloat.
    source "$PYVE_ROOT/lib/param_graph.sh"
    source "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    source "$PYVE_ROOT/lib/backend_detect.sh"
    source "$PYVE_ROOT/lib/micromamba_core.sh"
    source "$PYVE_ROOT/lib/micromamba_bootstrap.sh"
    source "$PYVE_ROOT/lib/micromamba_env.sh"
    # envs.sh is now a core dependency: the Python plugin, utils.sh, and
    # micromamba_env.sh resolve the main micromamba env path through
    # envs.sh helpers (micromamba_root_prefix / resolve_main_micromamba_path
    # / resolve_env_path — Story N.bf.14). Source it so every helper-using
    # suite inherits them (mirrors pyve.sh, which sources envs.sh at L66).
    source "$PYVE_ROOT/lib/envs.sh"

    # Story L.k.2: bats fixtures invoke `pyve init` with various flag
    # subsets that pre-date the interactive wizard. Default the bypass
    # to 1 so the wizard's TTY guard does not hard-fail on bats's
    # non-TTY stdin. Tests that exercise the wizard's TTY guard unset
    # this locally.
    export PYVE_INIT_NONINTERACTIVE=1
}

# Create a temporary test directory
create_test_dir() {
    export TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

# Clean up temporary test directory
cleanup_test_dir() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Skip a test when running under kcov coverage instrumentation.
#
# kcov instruments every bash subprocess it spawns by enabling xtrace
# (it sets BASH_XTRACEFD + PS4="kcov@...") — including the nested
# `run bash -c 'set -euo pipefail; ...'` subshells that some regression
# tests use to reproduce errexit/pipefail behavior faithfully. Under that
# instrumentation the nested `set -e` shell exits non-zero regardless of its
# body, so a test that asserts the subshell's status == 0 fails for a tooling
# reason, not a code reason. Detection keys off kcov's own env markers, which
# are present in the instrumented shell.
#
# STANDBY UTILITY (not currently called): the CI "Bash Coverage (kcov)" job's
# bats step is non-gating (`|| true`) precisely because this false-failure
# class is broad and not worth chasing per-test — coverage is informational;
# correctness is gated by the regular "Bats" job. Kept as an opt-in for any
# future test that wants to skip cleanly under kcov rather than false-fail.
skip_if_kcov() {
    if [[ -n "${KCOV_BASH_XTRACEFD:-}${KCOV_BASH_COMMAND:-}" ]]; then
        skip "kcov instruments the nested 'set -euo pipefail' subshell, perturbing its exit status"
    fi
}

# Create a requirements.txt file
create_requirements_txt() {
    local packages=("$@")
    cat > requirements.txt << EOF
$(printf '%s\n' "${packages[@]}")
EOF
}

# Create an environment.yml file
create_environment_yml() {
    local name="${1:-test-env}"
    shift
    local deps=("$@")
    
    cat > environment.yml << EOF
name: $name
channels:
  - conda-forge
dependencies:
$(printf '  - %s\n' "${deps[@]}")
EOF
}

# Create a .pyve/config file
create_pyve_config() {
    mkdir -p .pyve
    if [[ $# -eq 0 ]]; then
        touch .pyve/config
    else
        printf '%s\n' "$@" > .pyve/config
    fi
    # Opt-in v3 scaffold: a suite that sets PYVE_TEST_AUTOSCAFFOLD_TOML=1 also
    # gets a minimal pyve.toml, so a project scaffolded the v2 way is recognized
    # under v3 (pyve.toml is the sole declaration). The root backend mirrors the
    # config's `backend:` line; a config with no backend yields a backend-less
    # root (which exercises the "backend not configured" paths). The guard skips
    # when the test already wrote its own pyve.toml.
    if [[ "${PYVE_TEST_AUTOSCAFFOLD_TOML:-0}" == "1" ]] && [[ ! -f pyve.toml ]]; then
        local _b
        _b="$(sed -n 's/^backend:[[:space:]]*//p' .pyve/config | head -1)"
        if [[ -n "$_b" ]]; then
            create_pyve_toml "$_b"
        else
            cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "demo"

[env.root]
purpose = "utility"
EOF
        fi
    fi
}

# Create a minimal v3 pyve.toml declaring a single `root` env.
# Usage: create_pyve_toml [backend] [project-name]   (backend default: venv)
# This is the v3-native replacement for scaffolding a project with
# `create_pyve_config "backend: <x>"` — pyve.toml is the sole declaration.
create_pyve_toml() {
    local backend="${1:-venv}"
    local name="${2:-demo}"
    cat > pyve.toml <<EOF
pyve_schema = "3.0"

[project]
name = "${name}"

[env.root]
purpose = "utility"
backend = "${backend}"
EOF
}

# Create a pyproject.toml file
create_pyproject_toml() {
    cat > pyproject.toml << EOF
[project]
name = "test-project"
version = "0.1.0"
dependencies = [
    "requests",
]
EOF
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || {
        echo "Expected file to exist: $file" >&2
        return 1
    }
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]] || {
        echo "Expected directory to exist: $dir" >&2
        return 1
    }
}

# Assert file contains text
assert_file_contains() {
    local file="$1"
    local text="$2"
    grep -q "$text" "$file" || {
        echo "Expected file '$file' to contain: $text" >&2
        echo "Actual contents:" >&2
        cat "$file" >&2
        return 1
    }
}

# Last line of `run` output — the single-line RESULT of a probe-backed
# helper. `run` merges stderr into $output, so transient harness noise
# (e.g. bash's "fork: retry: Resource temporarily unavailable" under
# parallel-suite load) can precede an otherwise-correct result line and
# break a whole-output match. Tests asserting a machine-parseable
# single-line result compare this instead of "$output".
result_line() {
    local n="${#lines[@]}"
    [[ "$n" -gt 0 ]] || return 0
    printf '%s' "${lines[$((n - 1))]}"
}

# Assert output contains text
assert_output_contains() {
    local text="$1"
    echo "$output" | grep -q "$text" || {
        echo "Expected output to contain: $text" >&2
        echo "Actual output: $output" >&2
        return 1
    }
}

# Assert output equals text
assert_output_equals() {
    local expected="$1"
    [[ "$output" == "$expected" ]] || {
        echo "Expected output: $expected" >&2
        echo "Actual output: $output" >&2
        return 1
    }
}

# Assert status equals expected
assert_status_equals() {
    local expected="$1"
    [[ "$status" -eq "$expected" ]] || {
        echo "Expected status: $expected" >&2
        echo "Actual status: $status" >&2
        return 1
    }
}

# Mock command by creating a function
mock_command() {
    local cmd="$1"
    local return_value="${2:-0}"
    local output_text="${3:-}"
    
    eval "$cmd() {
        if [[ -n '$output_text' ]]; then
            echo '$output_text'
        fi
        return $return_value
    }"
}

# Unmock command
unmock_command() {
    local cmd="$1"
    unset -f "$cmd"
}
