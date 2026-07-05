#!/usr/bin/env bash
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Run the Bats unit suite — the entry point behind `make test-unit`.
#
# Parallelizes across test files via `bats --jobs` when GNU parallel is
# available (measured on a 14-core dev machine: ~4-6 min serial →
# under 2 min parallel; bats parallelizes across files, so the largest
# files bound the win). Falls back to a serial run otherwise —
# parallelism is a wall-clock optimization, never a semantic switch.
# PYVE_TEST_JOBS overrides the job count (default: CPU count).
# PYVE_TEST_TAGS=<tag> narrows the run to one subsystem tag
# (`bats --filter-tags`; the closed vocabulary lives in
# tests/unit/test_tags_guard.bats and docs/specs/testing-spec.md).
# Explicit test-file args narrow the run to those files (used by
# scripts/test-impact.sh); default is the whole tests/unit tree.
set -euo pipefail

cd "$(dirname "$0")/.."

declare -a files=("$@")
if [[ "${#files[@]}" -eq 0 ]]; then
    files=(tests/unit/*.bats)
fi

if ! command -v bats >/dev/null 2>&1; then
    echo "Error: Bats not installed. Install with:" >&2
    echo "  macOS: brew install bats-core" >&2
    echo "  Linux: sudo apt-get install bats" >&2
    exit 1
fi

jobs="${PYVE_TEST_JOBS:-}"
if [[ -z "$jobs" ]]; then
    jobs="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
fi

declare -a bats_args=()
if [[ -n "${PYVE_TEST_TAGS:-}" ]]; then
    bats_args+=(--filter-tags "$PYVE_TEST_TAGS")
fi

if command -v parallel >/dev/null 2>&1; then
    echo "Running Bats unit tests (--jobs $jobs; override with PYVE_TEST_JOBS=<n>)..."
    exec bats "${bats_args[@]+"${bats_args[@]}"}" --jobs "$jobs" "${files[@]}"
fi

echo "Running Bats unit tests serially (install GNU parallel for a ~3x faster suite: brew install parallel / apt-get install parallel)..."
exec bats "${bats_args[@]+"${bats_args[@]}"}" "${files[@]}"
