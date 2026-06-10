# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# audit_phasestory_refs.py — N-7 cleanup tooling (Stories N.bd.2 / N.bd.3 / N.bd.4).
#
# Detector for phase/story-ID references in code + comments. Emits a
# line-per-candidate "dirty" enumeration the developer reviews and iterates on.
# Same detector is the CI-guard candidate for the project-essentials rule
# "No story / phase IDs in code or comments".
#
# Output record format (one per matching line):
#     <relpath>:<lineno>{{{\t\t}}}<line-content-without-trailing-newline>
#
# The delimiter {{{\t\t}}} is visually distinct in an editor and won't collide
# with code content. Re-runnable; broaden/tighten the patterns across rounds.

import re
import sys
from pathlib import Path

DELIM = "{{{\t\t}}}"

ROOT = Path(__file__).resolve().parent
SCAN_DIRS = ["lib", "tests"]
SCAN_FILES = ["pyve.sh"]
# Only read text we care about; everything else (binaries, lockfiles) is skipped.
TEXT_SUFFIXES = {".sh", ".py", ".bats", ".bash", ""}  # "" → extensionless scripts (e.g. lib/completion/_pyve)

# A story/phase ID: phase letter(s) . story letter(s) [ . number [ trailing letter ] ]
# Matches N.x, M.i.1, H.e.9c, etc.
ID = r"[A-Z]{1,2}\.[a-z]{1,2}(?:\.[0-9]+[a-z]?)?"

# Candidate forms (a line is "dirty" if ANY matches):
RE_STORY = re.compile(rf"\b(?:Story|Stories)\s+{ID}")          # conspicuous: "Story N.x"
RE_BARE = re.compile(rf"\b{ID}\b")                              # bare inline: "the M.h.3 layout"
RE_PHASE = re.compile(r"\b(?:Phase|Subphase)\s+[A-Z][A-Za-z0-9]*(?:-[0-9]+)?")

# Load-bearing patterns — still enumerated (so the keep-decision is auditable),
# but tagged KEEP so N.bd.3's cleaner leaves them as clean == dirty.
RE_KEEP = re.compile(r"v3\.0-only: remove in N-|BOUNDARY|N\.i-pending")


def classify(line: str) -> str:
    """Return a short tag describing why the line is a candidate (for the report)."""
    if RE_KEEP.search(line):
        return "KEEP"            # load-bearing exception
    if RE_STORY.search(line):
        return "STORY"           # conspicuous "Story X.y" form (strong attractor)
    if RE_PHASE.search(line):
        return "PHASE"           # "Phase X" / "Subphase N-#"
    return "BARE"                # bare inline X.y ref (weak attractor)


def is_dirty(line: str) -> bool:
    return bool(RE_STORY.search(line) or RE_BARE.search(line) or RE_PHASE.search(line))


def iter_targets():
    for d in SCAN_DIRS:
        for p in sorted((ROOT / d).rglob("*")):
            if p.is_file() and p.suffix in TEXT_SUFFIXES:
                yield p
    for f in SCAN_FILES:
        p = ROOT / f
        if p.is_file():
            yield p


def main() -> int:
    records = []          # (relpath, lineno, tag, content)
    for path in iter_targets():
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        rel = path.relative_to(ROOT).as_posix()
        for i, line in enumerate(text.splitlines(), start=1):
            if is_dirty(line):
                records.append((rel, i, classify(line), line))

    out = ROOT / "lines_with_phasestory_nums_dirty.txt"
    with out.open("w", encoding="utf-8") as fh:
        for rel, lineno, _tag, content in records:
            fh.write(f"{rel}:{lineno}{DELIM}{content}\n")

    # ---- report to stderr/stdout (not part of the artifact) ----
    from collections import Counter
    by_tag = Counter(r[2] for r in records)
    by_phase = Counter(
        m.group(0)[0] for r in records for m in [re.search(ID, r[3])] if m
    )
    print(f"wrote {out.name}: {len(records)} candidate lines")
    print(f"  by form:  {dict(by_tag)}")
    print(f"  by phase: {dict(sorted(by_phase.items()))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
