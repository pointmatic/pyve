#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Lint regression guard (Story P.f.1). Asserts `pyve.sh` + every `lib/**/*.sh`
# is free of shellcheck **warning/error** findings, so the clean baseline can't
# silently rot: a new warning/error fails the suite, and intentional patterns
# must carry an explicit `# shellcheck disable=<code> # <reason>` directive.
#
# Scope is pyve.sh + lib/ only (the shipped runtime). tests/**/*.bats are out
# of scope — bats files trip SC1091/SC2329 by design. Info-level findings
# (SC1091 source-not-followed, etc.) are not gated; only warning/error are.

bats_require_minimum_version 1.5.0

setup() {
    PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "shellcheck: pyve.sh + lib/ have zero warning/error findings" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"

    local files=()
    local f
    while IFS= read -r f; do files+=("$f"); done < <(find "$PYVE_ROOT/lib" -name '*.sh' | sort)
    files+=("$PYVE_ROOT/pyve.sh")

    local findings
    findings="$(shellcheck -s bash -f gcc "${files[@]}" 2>&1 | grep -E 'warning:|error:' || true)"

    if [ -n "$findings" ]; then
        echo "Unexpected shellcheck warning/error findings (fix, or add a justified"
        echo "# shellcheck disable=<code> # <reason> directive):"
        echo "$findings"
        false
    fi
}
