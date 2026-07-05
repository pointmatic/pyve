# Change request: Test cadence in code cycles — targeted per task, full suite at the gate

**Target repo:** [`project-guide`](https://github.com/pointmatic/project-guide)
**Consumption:** every project driving LLM-assisted work through a project-guide code mode (`code_test_first`, `code_direct`). The rendered `go.md` cycle instructs the LLM to run the **full** test suite after **every task** (code_test_first Cycle Step 3f: "Run full test suite — no regressions"). The cadence is baked into the mode template, so consumers cannot adjust it without overriding `go.md` — which forks them off the template update stream.

---

## Problem statement

- A code cycle's inner loop runs the full suite once per **task**, not per **story**. A story with 4 checklist tasks pays the full-suite cost 4+ times before it ever reaches the approval gate.
- The cost compounds with suite growth. Measured in `pyve` today: 2,126 Bats unit tests, ~4–6 min serial. A polyglot future (per-language plugins: Rust, Go, C++, C#, React) plausibly reaches 10–12k tests — a serial full-suite-per-task cadence then costs tens of minutes per iteration, which in practice pressures the LLM (or the developer) into silently skipping the beat instead of paying it.
- The full-suite-per-task beat also buys less than it appears to: most task-level regressions surface in the changed subsystem's own suites, while the genuinely cross-cutting failures (the reason full runs matter at all) are rare and are still caught by the gate-level full run and CI.

## Proposed change

Change the code-cycle test beats from *full suite per task* to a graduated cadence:

1. **Per task (inner loop):** run the tests **impacted by the change** — the changed subsystem's test files/groups, plus a small smoke set. Wording for the template: *"Run the tests impacted by this task's change (targeted suite, tag group, or impact selection); the full suite is not required per task."*
2. **Per story (the gate):** run the **full unit suite** once, as part of preparing the approval-gate presentation (alongside lint). Entering a gate without a green full suite stays out of contract — this beat is **not** weakened.
3. **CI stays the ultimate arbiter** for the whole matrix (integration, cross-platform), unchanged.

The mode template should state the rationale in one sentence so LLMs don't "optimize" the gate run away: targeted selection is an iteration heuristic, not proof of safety — cross-module tails are real.

## Motivation (measured, from pyve)

- Full suite: ~4–6 min serial; 1:37 parallel (`bats --jobs`, 14-core machine). Even parallelized, per-task full runs dominate iteration time on multi-task stories.
- Targeted runs: a subsystem tag group runs in seconds (e.g. `make test-tag TAG=purge` → 25 tests); an impact-mapped selection (`make test-impact`, derived from `git diff` + function-name references) typically selects a handful of files.
- Field evidence for keeping the gate-level full run mandatory: pyve's record includes a function-name shadow that passed 725 unit tests and broke only in CI, and a SIGPIPE bug that surfaced only on the macOS CI runner during a full run. The graduated cadence keeps exactly the runs that catch these (gate + CI) and drops only the redundant intermediate ones.

## Suggested template shape

In `code_test_first` (and the equivalent beat in `code_direct`):

```text
3f. Run the tests impacted by this task's change — the changed
    subsystem's suites plus a smoke set. (Targeted selection is an
    iteration heuristic; the story gate below still requires the
    full suite.)
...
9.  Present the completed story: ... verification results MUST include
    a green full-suite run performed after the story's last change.
```

Optionally, a `project-essentials`-style hook: if the project documents targeted-run tooling (make targets, tags, an impact script), the template names it; otherwise the per-task beat simply reads "run the relevant test files".

## Compatibility notes

- **Degrade-safe:** projects with no targeted-run tooling satisfy the per-task beat by running whatever subset they can name — or the full suite, which remains valid everywhere. Nothing breaks for existing consumers; the change only *permits* the cheaper inner loop.
- The story-gate contract ("full suite green before the gate") is unchanged, so approval-gate semantics and the git-push workflow are unaffected.
- No CLI/API change to `project-guide` itself — this is a mode-template wording change, delivered through the normal `project-guide update` refresh of `go.md`.
- Consumer-side reference implementation (tags + impact selection + parallel runner) ships in pyve (Subphase P-1, Stories P.l.8–P.l.10; see `docs/specs/testing-spec.md` § "Running the unit suite") and can be cribbed into the template's guidance if useful.
