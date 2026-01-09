#!/usr/bin/env bats

load ../helpers/test_helper.bash

setup() {
    setup_pyve_env
    create_test_dir

    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    unset -f curl 2>/dev/null || true
    export HOME="$ORIGINAL_HOME"
    cleanup_test_dir
}

@test "bootstrap_install_micromamba: installs to user sandbox and binary is executable" {
    local tar_source_dir="$TEST_DIR/tar_source"
    mkdir -p "$tar_source_dir/bin"

    cat > "$tar_source_dir/bin/micromamba" << 'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "micromamba 2.5.0"
  exit 0
fi
exit 0
EOF
    chmod +x "$tar_source_dir/bin/micromamba"

    local tarball="$TEST_DIR/micromamba.tar.gz"
    tar -czf "$tarball" -C "$tar_source_dir" .

    curl() {
        local out_file=""
        local i=1
        while [[ $i -le $# ]]; do
            if [[ "${!i}" == "-o" ]]; then
                i=$((i + 1))
                out_file="${!i}"
            fi
            i=$((i + 1))
        done

        if [[ -z "$out_file" ]]; then
            echo "mock curl: missing -o" >&2
            return 1
        fi

        cp "$tarball" "$out_file"
        return 0
    }

    run bootstrap_install_micromamba "user"
    assert_status_equals 0

    assert_file_exists "$HOME/.pyve/bin/micromamba"
    [[ -x "$HOME/.pyve/bin/micromamba" ]]

    run "$HOME/.pyve/bin/micromamba" --version
    assert_status_equals 0
    assert_output_contains "2.5.0"
}
