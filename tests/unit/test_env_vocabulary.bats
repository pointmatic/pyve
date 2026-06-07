#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# closed-vocabulary data + classifier + lockstep.
#
# lib/pyve_toml_helper.py carries the machine mirror of the Pyve-owned
# closed vocabulary (wizard-env-contract.md §B / env-dependencies-template.md
# §2), partitioned implemented-vs-advisory, plus the FRAMEWORK_KIND /
# BACKEND_CATEGORY registries and a `classify_value` helper. This sub-story
# is inert — no validation/behavior change; the lockstep test fails the
# build if the docs and code drift apart.
#
# Pure stdlib (no PyYAML/tomlkit) — runs on any interpreter.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$PYVE_ROOT/lib"
    CONTRACT="$PYVE_ROOT/docs/specs/project-guide-requests/wizard-env-contract.md"
    PY="$(python -c 'import sys; print(sys.executable)')"
}

# Run a python snippet with lib/ on the path (so `import pyve_toml_helper`).
_py() {
    PYTHONPATH="$LIB" "$PY" -c "$1"
}

@test "VALID_* are the implemented ∪ advisory unions per axis" {
    run _py '
import pyve_toml_helper as m
assert set(m.VALID_BACKENDS) == set(m.BACKENDS_IMPLEMENTED) | set(m.BACKENDS_ADVISORY)
assert set(m.VALID_LANGUAGES) == set(m.LANGUAGES_IMPLEMENTED) | set(m.LANGUAGES_ADVISORY)
assert set(m.VALID_FRAMEWORKS) == set(m.FRAMEWORKS_IMPLEMENTED) | set(m.FRAMEWORKS_ADVISORY)
assert set(m.VALID_PACKAGING) == set(m.PACKAGING_IMPLEMENTED) | set(m.PACKAGING_ADVISORY)
assert set(m.VALID_APP_TYPES) == set(m.APP_TYPES_IMPLEMENTED) | set(m.APP_TYPES_ADVISORY)
'
    [ "$status" -eq 0 ]
}

@test "implemented backends are the canonical materializable set" {
    run _py '
import pyve_toml_helper as m
assert set(m.BACKENDS_IMPLEMENTED) == {"venv","micromamba","pnpm","npm","yarn"}, m.BACKENDS_IMPLEMENTED
'
    [ "$status" -eq 0 ]
}

@test "implemented languages are python/javascript/typescript only" {
    run _py '
import pyve_toml_helper as m
assert set(m.LANGUAGES_IMPLEMENTED) == {"python","javascript","typescript"}, m.LANGUAGES_IMPLEMENTED
'
    [ "$status" -eq 0 ]
}

@test "classify_value: implemented / advisory / unknown" {
    run _py '
import pyve_toml_helper as m
assert m.classify_value("backend","venv") == "implemented"
assert m.classify_value("backend","homebrew") == "advisory"
assert m.classify_value("backend","made_up") == "unknown"
assert m.classify_value("languages","python") == "implemented"
assert m.classify_value("languages","rust") == "advisory"
assert m.classify_value("frameworks","sveltekit") == "implemented"
assert m.classify_value("frameworks","pytest") == "advisory"
assert m.classify_value("packaging","container") == "advisory"
assert m.classify_value("app_type","cli") == "advisory"
assert m.classify_value("purpose","test") == "implemented"
assert m.classify_value("purpose","bogus") == "unknown"
'
    [ "$status" -eq 0 ]
}

@test "classify_value: none is a recognized value on none-bearing axes" {
    run _py '
import pyve_toml_helper as m
for ax in ("backend","frameworks","packaging","app_type"):
    assert m.classify_value(ax,"none") != "unknown", ax
# languages has no none
assert m.classify_value("languages","none") == "unknown"
'
    [ "$status" -eq 0 ]
}

@test "FRAMEWORK_KIND maps every framework to app/test/lint/none" {
    run _py '
import pyve_toml_helper as m
allowed = {"app","test","lint","none"}
for fw in m.VALID_FRAMEWORKS:
    assert fw in m.FRAMEWORK_KIND, "missing kind for "+fw
    assert m.FRAMEWORK_KIND[fw] in allowed, (fw, m.FRAMEWORK_KIND[fw])
assert m.FRAMEWORK_KIND["sveltekit"] == "app"
assert m.FRAMEWORK_KIND["pytest"] == "test"
assert m.FRAMEWORK_KIND["ruff"] == "lint"
assert m.FRAMEWORK_KIND["none"] == "none"
'
    [ "$status" -eq 0 ]
}

@test "BACKEND_CATEGORY maps every backend to an S6 category" {
    run _py '
import pyve_toml_helper as m
allowed = {"project-virtualized","cache-backed","check-only","special"}
for b in m.VALID_BACKENDS:
    assert b in m.BACKEND_CATEGORY, "missing category for "+b
    assert m.BACKEND_CATEGORY[b] in allowed, (b, m.BACKEND_CATEGORY[b])
assert m.BACKEND_CATEGORY["venv"] == "project-virtualized"
assert m.BACKEND_CATEGORY["xcode"] == "cache-backed"   # S16
assert m.BACKEND_CATEGORY["homebrew"] == "check-only"
assert m.BACKEND_CATEGORY["none"] == "special"
'
    [ "$status" -eq 0 ]
}

@test "lockstep: VALID_* partition matches the contract §B closed-vocabulary table" {
    cat > "$BATS_TEST_TMPDIR/lockstep.py" <<'PY'
import re, sys
import pyve_toml_helper as m

contract = sys.argv[1]
text = open(contract, encoding="utf-8").read()

# Bound parsing to the "### Closed vocabulary" section so no stray table
# elsewhere in the doc can be mistaken for the vocabulary table. The contract
# table reproduces env-dependencies-template.md §2 verbatim (per the contract
# itself), so asserting against it keeps code ↔ docs in lockstep.
lines = text.splitlines()
start = next(i for i, l in enumerate(lines) if l.startswith("### Closed vocabulary"))
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("#")), len(lines))
region = lines[start:end]

axes = {ax: [set(), set()] for ax in m._AXES}
for line in region:
    if not line.startswith("|"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) != 3:
        continue
    mo = re.match(r"`([a-z_]+)`", cells[0])
    if not mo:
        continue
    axis = mo.group(1)
    if axis not in axes:
        continue
    axes[axis][0].update(re.findall(r"`([^`]+)`", cells[1]))
    axes[axis][1].update(re.findall(r"`([^`]+)`", cells[2]))

# Every axis must have been found in the table.
for ax in m._AXES:
    assert axes[ax][0] or axes[ax][1], "axis not found in contract table: " + ax

for ax, (impl, adv) in m._AXES.items():
    dimpl, dadv = axes[ax]
    assert dimpl == set(impl), "%s implemented drift: doc=%s code=%s" % (ax, dimpl, set(impl))
    assert dadv == set(adv), "%s advisory drift: doc=%s code=%s" % (ax, dadv, set(adv))
print("lockstep OK")
PY
    run env PYTHONPATH="$LIB" "$PY" "$BATS_TEST_TMPDIR/lockstep.py" "$CONTRACT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lockstep OK"* ]]
}
