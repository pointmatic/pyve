# LLM On-Ramp Guide

This short guide is the single entrypoint you can paste to an LLM so it orients to this codebase and follows the agreed workflow.

## Purpose
- Provide the minimal, authoritative context and rules for the LLM.
- Point to canonical specs and guides. Avoid noisy or redundant context.

## Reading Order (Links)
1. docs/specs/versions_spec.md — active work, checklists, and Notes.
2. docs/specs/decisions_spec.md — approved decisions (date, context, decision, consequences).
3. docs/specs/codebase_spec.md — structure, components, dependencies, quality level.
4. docs/specs/implementation_options_spec.md — options, tradeoffs, selection rationale.
5. docs/specs/technical_design_spec.md — goals, architecture, quality level, interfaces.
6. docs/guides/dependencies_guide.md — policy (language-agnostic). See docs/guides/lang/* for language specifics.
7. docs/guides/infrastructure_guide.md — infrastructure patterns, deployment, scaling, monitoring (if deployed).
8. docs/guides/building_guide.md — roles, implementation rules, ticking checklists, Notes.
9. docs/guides/planning_guide.md — planning flow and relationship to versions.
10. docs/guides/testing_guide.md — testing strategy and expectations.

## Operating Rules for the LLM
- Implement only the targeted version’s checklist in docs/specs/versions_spec.md.
- Tick completed items `[x]`; when all are complete, append `[Implemented]` to the version title.
- Use `### Notes` only in the active version to describe clarifications, partial work, or known issues.
- Do not modify prior versions’ text except ticking items.
- Record major decisions in docs/specs/decisions_spec.md and reference them in the current version’s `### Notes`.

## Commands & Safety
- Follow the Commands Policy in docs/guides/building_guide.md.
- Destructive operations (deletes/moves) require explicit approval.

## Dependency Policy
- docs/guides/dependencies_guide.md is the source of truth. For language-specific details, see docs/guides/lang/*.

## Quality Level
- Honor the `## Quality` section in docs/specs/technical_design_spec.md and docs/specs/codebase_spec.md (experiment | prototype | production | secure) and its gates.

## Minimal Prompt to Start a Session
Paste this to the LLM at session start:
```
Please read the following in order and then implement only the current version in docs/specs/versions_spec.md:
- docs/specs/versions_spec.md
- docs/specs/decisions_spec.md
- docs/specs/codebase_spec.md
- docs/specs/implementation_options_spec.md
- docs/specs/technical_design_spec.md
- docs/guides/dependencies_guide.md (+ docs/guides/lang/*)
- docs/guides/infrastructure_guide.md (if deployed)
- docs/guides/building_guide.md
- docs/guides/planning_guide.md
- docs/guides/testing_guide.md

Then follow the Building Guide rules (tick checklists, add Notes, log decisions) and honor the Quality level.
```

## Clarifications
- If context is missing or conflicting, ask questions and capture outcomes in the current version’s `### Notes` and/or the decisions log.
