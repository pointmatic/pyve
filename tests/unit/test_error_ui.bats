#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for the error-path consistency sweep (Story H.f.4).
#
# Every top-level pyve command that errors out should emit a message
# matching the unified contract: ✘ glyph prefix via the upgraded
# log_error helper, non-zero exit, and zero ANSI escape codes under
# NO_COLOR=1.
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"
    unset CI PYVE_FORCE_YES
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Error output uses the ✘ glyph (unified palette)
#============================================================

@test "error: 'init --backend foo' prints ✘ prefix on rejection" {
    run "$PYVE_SCRIPT" init --backend foo
    [ "$status" -ne 0 ]
    [[ "$output" == *"✘"*"Invalid backend: foo"* ]]
}

@test "error: 'testenv --unknown-flag' prints ✘ prefix via unknown_flag_error" {
    run "$PYVE_SCRIPT" testenv --not-a-real-flag
    [ "$status" -ne 0 ]
    [[ "$output" == *"✘"* ]]
}

@test "error: 'python set' (no arg) prints ✘ prefix" {
    run "$PYVE_SCRIPT" python set
    [ "$status" -ne 0 ]
    [[ "$output" == *"✘"*"requires a version argument"* ]]
}

#============================================================
# Error output stays on stderr (bats merges streams by default,
# but we can separate them to prove routing)
#============================================================

@test "error: 'init --backend foo' writes the rejection to stderr" {
    # `bats run --separate-stderr` is too new to rely on. Use a
    # plain shell redirect: capture stderr separately into a file.
    local err_file="$BATS_TEST_TMPDIR/err"
    "$PYVE_SCRIPT" init --backend foo 2>"$err_file" >/dev/null || true
    grep -q "Invalid backend: foo" "$err_file"
}

#============================================================
# NO_COLOR=1 strips ANSI from error output
#============================================================

@test "error: 'init --backend foo' under NO_COLOR=1 has no ANSI escapes" {
    NO_COLOR=1 run "$PYVE_SCRIPT" init --backend foo
    [ "$status" -ne 0 ]
    if printf '%s' "$output" | grep -q $'\033'; then
        echo "ANSI escapes leaked into error output under NO_COLOR=1:" >&2
        printf '%s\n' "$output" | cat -v >&2
        return 1
    fi
}

@test "error: 'testenv --not-a-real-flag' under NO_COLOR=1 has no ANSI escapes" {
    NO_COLOR=1 run "$PYVE_SCRIPT" testenv --not-a-real-flag
    [ "$status" -ne 0 ]
    if printf '%s' "$output" | grep -q $'\033'; then
        echo "ANSI escapes leaked into error output under NO_COLOR=1:" >&2
        printf '%s\n' "$output" | cat -v >&2
        return 1
    fi
}

#============================================================
# NO_COLOR audit: major error paths across commands
#============================================================

@test "success paths: NO_COLOR audit across diagnostic commands (check / status / update)" {
    # Diagnostic commands emit through the upgraded log_* helpers on
    # success. In a bare test dir, check reports missing config (exit
    # non-zero but clean output), status prints a read-only snapshot,
    # update errors out with a no-config message. All must be ANSI-clean
    # under NO_COLOR=1.
    local cmd
    local -a paths=("check" "status" "update")
    local failures=()
    for cmd in "${paths[@]}"; do
        local out
        out="$(NO_COLOR=1 "$PYVE_SCRIPT" "$cmd" 2>&1 || true)"
        if printf '%s' "$out" | grep -q $'\033'; then
            failures+=("$cmd")
        fi
    done
    if [[ ${#failures[@]} -gt 0 ]]; then
        echo "NO_COLOR=1 audit failures on diagnostic commands:" >&2
        printf '  - %s\n' "${failures[@]}" >&2
        return 1
    fi
}

@test "error: NO_COLOR audit across init / purge / testenv / python / check / status error paths" {
    local code cmd args
    local -a paths=(
        "init --backend foo"
        "init --python-version"
        "purge --not-a-real-flag"
        "testenv --not-a-real-flag"
        "python"
        "python set"
        "python set badversion"
        "python show extra-arg"
        "update --not-a-real-flag"
    )

    local failures=()
    for cmd in "${paths[@]}"; do
        IFS=' ' read -ra args <<< "$cmd"
        local out
        out="$(NO_COLOR=1 "$PYVE_SCRIPT" "${args[@]}" 2>&1 || true)"
        if printf '%s' "$out" | grep -q $'\033'; then
            failures+=("$cmd")
        fi
    done

    if [[ ${#failures[@]} -gt 0 ]]; then
        echo "NO_COLOR=1 audit failures:" >&2
        printf '  - %s\n' "${failures[@]}" >&2
        return 1
    fi
}
