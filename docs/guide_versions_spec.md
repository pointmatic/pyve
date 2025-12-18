# Guide for Versions Spec
(See ./docs/specs/versions_spec.md)

This document explains how the human, the LLM, and the development environment interact to implement versions.

## Roles
- **Human or LLM**
  - Add a new version at the top of `docs/specs/versions_spec.md`: `## v#.#.# _Title_of_Requirements_`.
  - Add a checklist of requirements under the version.
- **Human**
  - Trigger implementation (informally is fine). For new sessions, prefer: “Please implement v#.#.# in the @versions.md file”.
- **LLM**
  - Implement only the listed requirements for the targeted version.
  - Tick completed items `[x]`. If all are complete, append `[Implemented]` to the version title.
  - Use `### Notes` in the current version only to explain details, clarifications, partial work, or known issues. If correcting past guidance, reference the affected version (do not edit old versions).
    - Example “Decision reference” for Notes:
      - Decision: [2025-10-12: Switch to Service Account Auth](docs/specs/decisions_spec.md#2025-10-12-switch-to-service-account-auth) — requires sharing Sheet/Doc with the service account; update CI secrets.
  - Record major architectural/process/tooling decisions in `docs/specs/decisions_spec.md` (include date, context, decision, consequences). Link the entry in the current version's `### Notes` when applicable.
  - Do not modify prior versions or change requirement text other than ticking off items.

## Microversions and Next Versions
- **Microversions**: Use `a`, `b`, `c`, … when the human requests a bugfix/error follow-up that is not already captured in `docs/specs/versions_spec.md`. Example: `v0.0.2a`.
- **Next versions**: When there is a clear big‑picture plan/technical design, propose the next semantic version for review (e.g., `v0.1.0 [Planned]`).

## Dependency Management
- See `docs/guides/dependencies_guide.md` for authoritative guidance (apps vs libs, `requirements.in` → compiled `requirements.txt`, update workflow, and safeguards).

## LLM Commands Policy
- OK: 
  - `pip install {package}` (one package at a time), `pytest`, invoking program entry points (e.g., `python -m merge_docs.cli`).
  - volatile testing file creation and deletion in the /tmp directory (clean up after)
- Not OK: 
  - destructive commands like `rm`, `mv` (except in the /tmp directory). Ask the human first for file deletes/renames 
- Prefer `git mv` instead of `mv` for tracked files.

## Implementation Flow (Typical)
1. Human or LLM adds/updates `docs/specs/versions_spec.md` with requirements and requests implementation.
2. LLM implements code and tests per the targeted version.
3. LLM updates the version checklist, appends `[Implemented]` if complete, and adds `### Notes`.
4. LLM logs major decisions in `docs/specs/decisions_spec.md`; reference the entry in the version's `### Notes`.
5. If follow-up fixes are requested, add a microversion and implement.
6. If a larger plan is ready, add a new `[Planned]` version for review before implementation.
