#!/usr/bin/env bash
#
# Bats Test Helper Functions
# Shared utilities for Bats unit tests
#

# Setup function to source pyve modules
setup_pyve_env() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_DIR="$PYVE_ROOT"
    
    # Source all lib modules
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/env_detect.sh"
    source "$PYVE_ROOT/lib/backend_detect.sh"
    source "$PYVE_ROOT/lib/micromamba_core.sh"
    source "$PYVE_ROOT/lib/micromamba_bootstrap.sh"
    source "$PYVE_ROOT/lib/micromamba_env.sh"
    source "$PYVE_ROOT/lib/distutils_shim.sh"
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

# Set environment variable for test
set_test_env() {
    local var="$1"
    local value="$2"
    export "$var=$value"
}

# Unset environment variable
unset_test_env() {
    local var="$1"
    unset "$var"
}
