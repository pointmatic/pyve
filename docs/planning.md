# Planning Guide

This document explains how to plan versions and produce a technical design from v0.0.0 to v1.0.0.

## Goals
- Establish phased progression toward v1.0.0.
- Capture requirements per phase and map them to semantic versions.
- Keep `docs/versions.md` as the authoritative log of implemented work.

## Phases and Versioning
- Version format: `v{major}.{minor}.{incremental}{micro}` where `{micro}` is optional `a|b|c|...`.
- Phase-driven minor versions:
  - Phase 0 → v0.x.0 (setup, scaffolding, Hello World) until ready to begin Phase 1.
  - Phase 1 → v1.x.0 (or continue under v0.x if still pre-release) implementing the first major feature slice.
  - Subsequent phases increment the minor version: v{major}.{minor+1}.0.
- Incremental (patch) increments as requirements are split into smaller deliverables within a phase.
- Microversions (`a/b/c/...`) to log quick bugfixes or small follow-ups requested by the human when not already captured in `docs/versions.md` (e.g., `v0.0.2a`).

## Creating a Technical Design (`docs/technical_design.md`)
Include:
- Overview: scope, problem to solve, constraints.
- Stack: languages, libraries, tools.
- Resources: IDs/URLs for external services (e.g., Google Docs/Sheets).
- Authentication: flows, scopes, secrets handling.
- Configuration: env vars/flags and meanings.
- Data/Placeholder Conventions: formats, normalization, mappings.
- Algorithms/Workflow: end-to-end sequence with key API calls.
- Error Handling, Performance, Logging, Security.
- CLI/Interface Sketch: commands, flags, examples.
- Next Steps: actionable backlog aligned to phases.

## Planning Workflow
1. Draft or update `docs/technical_design.md` covering the above.
2. Propose the next semantic version in `docs/versions.md` with `[Next]` if broader work is planned.
3. Break work into requirements under that version.
4. Review with human; revise as needed. When a design/scope decision is approved, add an entry to `docs/decisions.md` (date, context, decision, consequences).
5. Implement; log using the versions file (tick items, add Notes, mark `[Implemented]`). Reference any new decision log entries in the version's `### Notes`.
6. For bugfixes or unlogged changes, append microversions.
