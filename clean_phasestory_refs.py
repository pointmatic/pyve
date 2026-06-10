# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# clean_phasestory_refs.py — N-7 cleanup tooling (Story N.bd.3).
#
# Reads lines_with_phasestory_nums_dirty.txt and writes
# lines_with_phasestory_nums_clean.txt, line-for-line aligned.
#
# PASS 1 (this script): auto-strip the mechanically-SAFE conspicuous
# `Story X.y` forms only (leading `# Story X.y:`, trailing `(Story X.y)`,
# `F<n>/X.y`, and the comma / em-dash variants validated in N.bd). Everything
# else — bare inline refs, load-bearing KEEP lines, structural cases — is left
# byte-identical (clean == dirty) for the per-line LLM-judgement passes that
# follow. The clean file is then hand-edited (overrides) where a strip isn't
# the right call (rephrase / [implementation story] / <<<DELETE>>>).

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DELIM = "{{{\t\t}}}"
DIRTY = ROOT / "lines_with_phasestory_nums_dirty.txt"
CLEAN = ROOT / "lines_with_phasestory_nums_clean.txt"

ID = r"[A-Z]{1,2}\.[a-z]{1,2}(?:\.[0-9]+[a-z]?)?"
EMDASH = "—"
ENDASH = "–"

RE_KEEP = re.compile(r"v3\.0-only: remove in N-|BOUNDARY|N\.i-pending")

# First edit, before all others (developer decision, 2026-06-06): a pair of
# story numbers joined by `+` or `/`, parentheses optional — "(N.av.3 / N.av.4)",
# "N.ae.2 / N.y", "M.h.3 / N.f". Replaced with the visible marker XXXX (not
# deleted) so every match site is easy to find in clean.txt for review; the
# final per-line decision (delete / rephrase) happens against the XXXX marks.
# The (?<!Story ) lookbehinds skip "Story X.y / X.z" pairs so those go through
# RE_SAFE_PAREN intact (which deletes the full "(Story …)").
RE_PAIR = re.compile(rf"(?<!Story )(?<!Stories ){ID}\s*[+/]\s*{ID}")
MARK = "XXXX"

# The ONLY safe automatic removal (developer decision, 2026-06-06): a
# parenthetical aside whose entire content is story refs — "(Story X.y)",
# "(Stories X.y and X.z)", "(Story X.y / X.z)". These are grammatically
# isolated, so deleting the whole paren leaves the sentence intact with no
# dangling punctuation and no dropped prose. Anything else — leading
# "# Story X.y:", mid-sentence refs, comma-parens carrying extra prose
# ("(Story N.f, env vocabulary)"), "(Story N.au — F1)" (drops the F-label),
# bare refs — is NOT auto-removed; it stays clean==dirty for per-line judgement.
# A parenthetical whose ENTIRE content is storynum(s) — "(N.az.2)",
# "(N.ae/N.af)", "(Story X.y)", "(Story M.i.1 / M.k)", "(N.s.1 + N.s.2)" — is a
# grammatically isolated aside; deleting the whole paren is safe. The "Story"
# word is optional (so bare "(N.az.2)" is caught); connectors include + / , and
# the dashes. Parens carrying extra prose ("(Story N.f, env vocabulary)") do
# NOT match (content must be only ids/connectors) and stay for judgement.
RE_SAFE_PAREN = re.compile(
    rf"\s*\((?:(?:Story|Stories) )?{ID}(?:\s*(?:,|and|/|\+|{EMDASH}|{ENDASH})\s*{ID})*\)"
)

# Second safe form (developer decision, 2026-06-06): the "Story X.y:" label
# prefix — the colon delimits the label, so the content after it stands alone.
# Matches leading ("# Story M.i.2: accepts…" → "# accepts…") and mid-line
# ("…config. Story N.j.1: post…" → "…config. post…"). The colon is required;
# the em-dash leading form is left for per-line judgement. An optional
# " landed" is absorbed too ("Story M.k landed: conda…" → "conda…").
RE_SAFE_PREFIX = re.compile(rf"\b(?:Story|Stories) {ID}(?: landed)?:[ \t]*")

# Third safe form (developer decision, 2026-06-06): a ref suffixed with
# " landed" — delete the ref token, keep "landed". Some results are a little
# awkward but still intelligible ("M.m landed `.state` writes" → "landed
# `.state` writes"). Runs after the prefix rule so "X.y landed:" is handled
# cleanly there first.
RE_LANDED = re.compile(rf"\b(?:Story |Stories )?{ID} (?=landed\b)")


# A cleaned line is "degenerate" when the removal left an empty comment or a
# comment that now opens with orphan punctuation (e.g. "#.", "#. Reads") —
# happens when the removed (Story X.y) paren was the whole/leading content.
RE_DEGENERATE = re.compile(r"^\s*#\s*$|^\s*#\s*[.,;:)]")


def clean_content(content: str) -> str:
    if RE_KEEP.search(content):
        return content          # load-bearing — keep verbatim
    # 1. Delete whole-storynum parens (single or pair) — clean asides.
    s = RE_SAFE_PAREN.sub("", content)
    # 2. Mark remaining mid-text storynum pairs with XXXX (visible review marker).
    s = RE_PAIR.sub(MARK, s)
    # 3. Approved clean strips (final content).
    s = RE_SAFE_PREFIX.sub("", s)
    s = RE_LANDED.sub("", s)
    if s != content and RE_DEGENERATE.match(s):
        return content          # don't auto-mangle — leave for per-line judgement
    return s


def main() -> int:
    changed = unchanged = 0
    out_lines = []
    for raw in DIRTY.read_text(encoding="utf-8").splitlines():
        if DELIM not in raw:
            out_lines.append(raw)
            continue
        head, content = raw.split(DELIM, 1)
        cleaned = clean_content(content)
        if cleaned != content:
            changed += 1
        else:
            unchanged += 1
        out_lines.append(f"{head}{DELIM}{cleaned}")
    CLEAN.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    print(f"wrote {CLEAN.name}: {changed} auto-cleaned, {unchanged} left as clean==dirty")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
