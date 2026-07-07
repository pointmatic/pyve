#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Guard: no stale `.pyve/config` narration remains in the tree.
#
# v2's `.pyve/config` is fully retired — pyve neither writes nor reads it.
# The only sanctioned mentions left in `lib/` + `pyve.sh` are:
#   - lib/commands/self.sh — the reserved-stub comment that accurately
#     explains the removed v2 migration bridge.
#   - lib/manifest.sh — the accurate statement that a `.pyve/config`-only
#     project is uninitialized.
#   - the `purge` cleanup line that DELETES a stray legacy `.pyve/config`
#     (`rm -rf ".pyve/config"`) — code, not narration.
# Everything else describing a write/read/synthesis of `.pyve/config` is
# stale and must be swept.

load ../helpers/test_helper

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "no stale .pyve/config references remain in lib/ or pyve.sh" {
    run bash -c "
        grep -rn '\.pyve/config' '$PYVE_ROOT/lib' '$PYVE_ROOT/pyve.sh' \
          | grep -vE '/(commands/self|manifest)\.sh:[0-9]+:' \
          | grep -v 'rm -rf \".pyve/config\"'
    "
    if [ "$status" -eq 0 ]; then
        echo "Stale .pyve/config references still present:"
        echo "$output"
    fi
    # grep finds nothing after the sweep → non-zero exit → test passes.
    [ "$status" -ne 0 ]
}
