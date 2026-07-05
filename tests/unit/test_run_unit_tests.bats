#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# scripts/run-unit-tests.sh — the unit-suite entry point behind
# `make test-unit`. Parallelizes across test files (`bats --jobs N`)
# when GNU parallel is available; falls back to a serial run otherwise;
# errors actionably when bats itself is missing. PYVE_TEST_JOBS
# overrides the job count (default: CPU count). The suite must behave
# the same either way — parallelism is a wall-clock optimization, never
# a semantic switch.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    RUNNER="$PYVE_ROOT/scripts/run-unit-tests.sh"
    STUB_DIR="$BATS_TEST_TMPDIR/stubs"
    STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
    mkdir -p "$STUB_DIR"
    # Baseline PATH for the script under test: system utilities only —
    # excludes homebrew/user dirs so the real bats/parallel never leak in.
    SYS_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
}

# A fake bats that records its argv (first few args carry the flags).
_stub_bats() {
    cat > "$STUB_DIR/bats" <<SH
#!/bin/bash
printf 'BATS_ARGS:%s %s %s\n' "\$1" "\$2" "\$3" >> "$STUB_LOG"
exit 0
SH
    chmod +x "$STUB_DIR/bats"
}

# A fake GNU parallel — only its presence on PATH matters.
_stub_parallel() {
    printf '#!/bin/bash\nexit 0\n' > "$STUB_DIR/parallel"
    chmod +x "$STUB_DIR/parallel"
}

@test "runner: with GNU parallel on PATH, bats gets --jobs <n>" {
    _stub_bats
    _stub_parallel
    run env PATH="$STUB_DIR:$SYS_PATH" PYVE_TEST_JOBS= "$RUNNER"
    [ "$status" -eq 0 ]
    grep -q "BATS_ARGS:--jobs " "$STUB_LOG"
}

@test "runner: PYVE_TEST_JOBS overrides the job count" {
    _stub_bats
    _stub_parallel
    run env PATH="$STUB_DIR:$SYS_PATH" PYVE_TEST_JOBS=7 "$RUNNER"
    [ "$status" -eq 0 ]
    grep -q "BATS_ARGS:--jobs 7 " "$STUB_LOG"
}

@test "runner: without GNU parallel, bats runs serially (no --jobs)" {
    _stub_bats
    run env PATH="$STUB_DIR:$SYS_PATH" PYVE_TEST_JOBS= "$RUNNER"
    [ "$status" -eq 0 ]
    ! grep -q -- "--jobs" "$STUB_LOG"
    # The fallback names the speed-up opportunity.
    [[ "$output" == *"parallel"* ]]
}

@test "runner: bats missing → actionable install error, non-zero exit" {
    # Stub dir intentionally has no bats.
    run env PATH="$STUB_DIR:$SYS_PATH" "$RUNNER"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bats-core"* ]]
}

@test "runner: PYVE_TEST_TAGS adds --filter-tags for targeted subsystem runs" {
    _stub_bats
    _stub_parallel
    run env PATH="$STUB_DIR:$SYS_PATH" PYVE_TEST_TAGS=env PYVE_TEST_JOBS=4 "$RUNNER"
    [ "$status" -eq 0 ]
    grep -q -- "--filter-tags env" "$STUB_LOG"
}

@test "runner: PYVE_TEST_TAGS works on the serial fallback too" {
    _stub_bats
    run env PATH="$STUB_DIR:$SYS_PATH" PYVE_TEST_TAGS=init "$RUNNER"
    [ "$status" -eq 0 ]
    grep -q -- "--filter-tags init" "$STUB_LOG"
    ! grep -q -- "--jobs" "$STUB_LOG"
}

@test "runner: explicit test-file args narrow the run to those files" {
    _stub_bats
    run env PATH="$STUB_DIR:$SYS_PATH" "$RUNNER" \
        tests/unit/test_manifest.bats tests/unit/test_utils.bats
    [ "$status" -eq 0 ]
    # Serial path (no parallel stub): the two files are argv 1-2, both
    # inside the stub's recorded window.
    grep -q "test_manifest.bats" "$STUB_LOG"
    ! grep -q "test_version.bats" "$STUB_LOG"
}
