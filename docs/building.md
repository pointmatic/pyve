# Building Guide

This document explains how the human, the LLM, and the development environment interact to implement versions.

## Roles
- **Human**
  - Add a new version at the top of `docs/versions.md`: `## v#.#.# _Title_of_Requirements_`.
  - Add a checklist of requirements under the version.
  - Trigger implementation (informally is fine). For new sessions, prefer: “Please implement v#.#.# in the @versions.md file”.
- **LLM**
  - Implement only the listed requirements for the targeted version.
  - Tick completed items `[x]`. If all are complete, append `[Implemented]` to the version title.
  - Use `### Notes` in the current version only to explain details, clarifications, partial work, or known issues. If correcting past guidance, reference the affected version (do not edit old versions).
    - Example “Decision reference” for Notes:
      - Decision: [2025-10-12: Switch to Service Account Auth](docs/decisions.md#2025-10-12-switch-to-service-account-auth) — requires sharing Sheet/Doc with the service account; update CI secrets.
  - Record major architectural/process/tooling decisions in `docs/decisions.md` (include date, context, decision, consequences). Link the entry in the current version's `### Notes` when applicable.
  - Do not modify prior versions or change requirement text other than ticking off items.

## Microversions and Next Versions
- **Microversions**: Use `a`, `b`, `c`, … when the human requests a bugfix/error follow-up that is not already captured in `docs/versions.md`. Example: `v0.0.2a`.
- **Next versions**: When there is a clear big‑picture plan/technical design, propose the next semantic version for review (e.g., `v0.1.0 [Next]`).

## Dependency Management
- See `docs/dependencies.md` for authoritative guidance (apps vs libs, `requirements.in` → compiled `requirements.txt`, update workflow, and safeguards).

## Commands Policy
- OK: `pip install {package}` (one package at a time), `pytest`, invoking program entry points (e.g., `python -m merge_docs.cli`).
- Not OK: destructive commands like `rm`, `mv`. Ask the human first for file deletes/renames (prefer `git mv`).

## Implementation Flow (Typical)
1. Human adds/updates `docs/versions.md` with requirements and requests implementation.
2. LLM implements code and tests per the targeted version.
3. LLM updates the version checklist, appends `[Implemented]` if complete, and adds `### Notes`.
4. Log major decisions in `docs/decisions.md`; reference the entry in the version's `### Notes`.
5. If follow-up fixes are requested, add a microversion and implement.
6. If a larger plan is ready, add a new `[Next]` semantic version for review before implementation.
