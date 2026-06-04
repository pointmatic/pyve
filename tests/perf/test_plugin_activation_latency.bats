#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Story N.ak — PC-4b: per-plugin activation latency budget (≤ 50ms p95).
#
# The composed `.envrc` evaluates on every shell / direnv reload, so each
# plugin's `activate` contribution must stay fast. This regression benchmark
# drives `_compose_envrc_body` in bench mode (`PYVE_LATENCY_BENCH=1`), which
# emits one `# pyve:bench:<plugin>:activate_ms=<n>` trailer line per active
# plugin, against three canned fixtures (Python-only, Node-only, polyglot).
#
# Methodology (kept in the header so runner drift is debuggable):
#   - N = 20 timed runs per fixture.
#   - The FIRST 5 runs are discarded as warm-up (cold subshell / FS caches).
#   - p95 is the nearest-rank 95th percentile over the remaining 15 samples
#     (ceil(0.95 * 15) = 15 → the slowest of the 15, i.e. a strict bound).
#   - Budget: a plugin FAILS when its p95 > 50ms.
#
# Timing source (see `_pyve_bench_now_ms` in lib/envrc_composer.sh): bash 5
# `$EPOCHREALTIME` (subprocess-free) when available, else GNU `date +%s%N`.
# When neither is present (e.g. clean macOS bash 3.2 + BSD date), the bench
# lines carry `-1` and these tests SKIP rather than report false numbers —
# CI (Linux / bash 5) is the enforcement point.

bats_require_minimum_version 1.5.0

load ../helpers/test_helper

PERF_BUDGET_MS=50
PERF_RUNS=20
PERF_WARMUP=5

setup() {
    setup_pyve_env
    export PYVE_PYTHON="$(python -c 'import sys; print(sys.executable)')"
    source "$PYVE_ROOT/lib/envrc_safety.sh"
    source "$PYVE_ROOT/lib/plugins/node/plugin.sh"
    source "$PYVE_ROOT/lib/plugins/node/runtime_detect.sh"
    source "$PYVE_ROOT/lib/envrc_composer.sh"
    create_test_dir
    plugin_registry_reset
    bp_registry_reset
    python_pyve_plugin_register_backends
    node_pyve_plugin_register_backends
    export NO_COLOR=1
}

teardown() {
    cleanup_test_dir
}

# Skip the whole file when no precise timer is available.
_require_precise_timer() {
    local ms
    ms="$(_pyve_bench_now_ms)" || ms="-1"
    if [[ "$ms" == "-1" ]]; then
        skip "no precise timer (EPOCHREALTIME / GNU date) available"
    fi
}

_load_python_only() {
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.python]
path = "."
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

_load_node_only() {
    : > package.json
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.node]
path = "."
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

_load_polyglot() {
    mkdir -p src/frontend
    : > src/frontend/package.json
    cat > pyve.toml <<'EOF'
pyve_schema = "3.0"
[project]
name = "demo"
[plugins.python]
path = "."
[plugins.node]
path = "src/frontend"
[env.root]
purpose = "utility"
backend = "venv"
EOF
    manifest_load pyve.toml >/dev/null 2>&1 || true
    plugin_load_all_from_manifest >/dev/null 2>&1 || true
}

# Nearest-rank p95 over stdin (one integer per line). Echoes the p95 value.
_p95() {
    local -a v=()
    local x
    while IFS= read -r x; do [[ -n "$x" ]] && v+=("$x"); done < <(sort -n)
    local n=${#v[@]}
    (( n == 0 )) && { printf '0'; return; }
    # nearest-rank: idx = ceil(0.95 * n), 1-based.
    local idx=$(( (95 * n + 99) / 100 ))
    (( idx < 1 )) && idx=1
    (( idx > n )) && idx=n
    printf '%s' "${v[idx-1]}"
}

# Drive the composer's bench mode in a CLEAN `bash -c` subprocess (NOT the
# bats-instrumented shell): bats wraps every command with framework
# bookkeeping that inflates subshell/fork costs ~5x, which would make the
# benchmark measure bats, not the plugin. The subprocess sources the libs
# once and loops internally, emitting `<run> <plugin> <ms>` lines.
_run_bench() {
    local runs="$1"
    PYVE_ROOT="$PYVE_ROOT" bash -c '
        set -uo pipefail
        for f in ui/core ui/run utils manifest env_detect \
                 plugins/contract plugins/registry plugins/backend_registry \
                 envrc_safety plugins/python/plugin backend_detect \
                 plugins/node/plugin plugins/node/runtime_detect envrc_composer; do
            source "$PYVE_ROOT/lib/$f.sh"
        done
        python_pyve_plugin_register_backends 2>/dev/null || true
        node_pyve_plugin_register_backends 2>/dev/null || true
        manifest_load pyve.toml >/dev/null 2>&1 || true
        plugin_load_all_from_manifest >/dev/null 2>&1 || true
        runs="$1"
        for (( r = 1; r <= runs; r++ )); do
            PYVE_LATENCY_BENCH=1 _compose_envrc_body 2>/dev/null \
              | grep "^# pyve:bench:" \
              | while IFS= read -r line; do
                    p="${line#\# pyve:bench:}"; p="${p%%:*}"
                    ms="${line##*=}"
                    printf "%s %s %s\n" "$r" "$p" "$ms"
                done
        done
    ' _ "$runs"
}

# Run the benchmark for the loaded fixture; assert every active plugin's p95
# is within budget.
_bench_and_assert() {
    local fixture="$1"
    local tmpd; tmpd="$(mktemp -d)"
    local run plugin ms

    while read -r run plugin ms; do
        [[ -z "$run" || -z "$plugin" ]] && continue
        (( run > PERF_WARMUP )) && printf '%s\n' "$ms" >> "$tmpd/$plugin"
    done < <(_run_bench "$PERF_RUNS")

    local f p95
    local saw_plugin=0
    for f in "$tmpd"/*; do
        [[ -e "$f" ]] || continue
        saw_plugin=1
        plugin="$(basename "$f")"
        p95="$(_p95 < "$f")"
        echo "[$fixture] $plugin p95=${p95}ms (budget ${PERF_BUDGET_MS}ms)" >&3
        [ "$p95" -le "$PERF_BUDGET_MS" ] || {
            echo "LATENCY BUDGET EXCEEDED: $fixture/$plugin p95=${p95}ms > ${PERF_BUDGET_MS}ms" >&2
            rm -rf "$tmpd"; return 1
        }
    done
    rm -rf "$tmpd"
    [ "$saw_plugin" -eq 1 ]   # the fixture must have produced at least one plugin sample
}

# ════════════════════════════════════════════════════════════════════
# Instrumentation contract.
# ════════════════════════════════════════════════════════════════════

@test "bench: PYVE_LATENCY_BENCH=1 emits a pyve:bench line per active plugin" {
    _load_polyglot
    export PYVE_LATENCY_BENCH=1
    run _compose_envrc_body
    unset PYVE_LATENCY_BENCH
    [ "$status" -eq 0 ]
    [[ "$output" == *"# pyve:bench:python:activate_ms="* ]]
    [[ "$output" == *"# pyve:bench:node:activate_ms="* ]]
}

@test "bench: bench lines are ABSENT without PYVE_LATENCY_BENCH" {
    _load_python_only
    run _compose_envrc_body
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"pyve:bench:"* ]]
}

# ════════════════════════════════════════════════════════════════════
# Latency budget — p95 ≤ 50ms per plugin, per fixture.
# ════════════════════════════════════════════════════════════════════

@test "latency: python-only activate p95 within budget" {
    _require_precise_timer
    _load_python_only
    _bench_and_assert "python-only"
}

@test "latency: node-only activate p95 within budget" {
    _require_precise_timer
    _load_node_only
    _bench_and_assert "node-only"
}

@test "latency: polyglot activate p95 within budget (both plugins)" {
    _require_precise_timer
    _load_polyglot
    _bench_and_assert "polyglot"
}
