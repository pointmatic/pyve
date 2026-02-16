#!/usr/bin/env bash
#
# kcov wrapper for Pyve integration tests
#
# When PYVE_KCOV_OUTDIR is set, this script runs pyve.sh under kcov
# to collect Bash line coverage during pytest integration tests.
#
# Usage:
#   Set PYVE_KCOV_OUTDIR to the kcov output directory, then point
#   PYVE_SCRIPT at this wrapper instead of pyve.sh directly.
#
#   PYVE_KCOV_OUTDIR=/tmp/kcov-out PYVE_SCRIPT=tests/helpers/kcov-wrapper.sh \
#       pytest tests/integration/ -v
#
# The wrapper resolves the real pyve.sh location relative to itself
# and passes all arguments through.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYVE_REAL="${SCRIPT_DIR}/../../pyve.sh"

if [[ -z "${PYVE_KCOV_OUTDIR:-}" ]]; then
    # No kcov output dir — run pyve.sh directly (fallback)
    exec "$PYVE_REAL" "$@"
fi

# Resolve absolute path for --include-path
PYVE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec kcov \
    --include-path="${PYVE_ROOT}/lib/,${PYVE_ROOT}/pyve.sh" \
    --bash-dont-parse-binary-dir \
    "$PYVE_KCOV_OUTDIR" \
    "$PYVE_REAL" "$@"
