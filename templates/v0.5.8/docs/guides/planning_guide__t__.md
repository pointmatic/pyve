# Planning Guide

This document explains how to plan versions and produce a technical design from v0.0.0 to v1.0.0.

## Goals
- Establish phased progression toward v1.0.0.
- Capture requirements per phase and map them to semantic versions.
- Keep `docs/specs/versions_spec.md` as the authoritative log of implemented work.
 - Ensure plans and designs align with the master codebase spec in `docs/specs/codebase_spec.md` and relevant language addenda in `docs/specs/lang/`.

## Phases and Versioning
- Version format: `v{major}.{minor}.{incremental}{micro}` where `{micro}` is optional `a|b|c|...`.
- Phase-driven minor versions:
  - Phase 0 → v0.0.x (setup, scaffolding, Hello World) until ready to begin working on actual features in Phase 1.
  - Phase 1 → v0.1.x implement the first major feature slice.
  - Phase 2 → v0.2.x implementing the second major feature slice.
  - Subsequent phases increment the minor version: v{major}.{minor+1}.0.
- Incremental (patch) increments as requirements are split into smaller deliverables within a phase.
- Microversions (`a/b/c/...`) to log quick bugfixes or small follow-ups requested by the human when not already captured in `docs/versions.md` (e.g., `v0.0.2a`).

## Creating a Technical Design (`docs/specs/technical_design_spec.md`)
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

## Q&A Phase Alignment with Version Phases

The LLM Q&A process (see `docs/guides/llm_qa/`) aligns naturally with version phases:

### Project Context Phase (Recommended for All)
| Q&A Phase | Version Phase | When | What Gets Filled |
|-----------|---------------|------|------------------|
| **Project Context** | Before v0.0.x | Before Phase 0 | Problem, stakeholders, constraints, ecosystem, scope, timeline, Quality level |

### Foundation Phases (All Projects)
| Q&A Phase | Version Phase | When | What Gets Filled |
|-----------|---------------|------|------------------|
| **Phase 0** | Before v0.0.x | After `pyve --init` | Project basics, Quality level, language/framework |
| **Phase 1** | Before v0.1.0 | Before first feature | Architecture, technical stack, development workflow |

### Production Readiness Phases (production/secure Quality)
| Q&A Phase | Version Phase | When | What Gets Filled |
|-----------|---------------|------|------------------|
| **Phase 2** | Before production | Before deploying | Infrastructure (hosting, scaling, monitoring) |
| **Phase 3** | Before production | Before deploying | Authentication & Authorization |
| **Phase 4** | Before production | Before deploying | Security Basics (secrets, encryption, input validation) |
| **Phase 5** | Before production | Before deploying | Operations (deployment, logging, incidents) |

### Feature-Specific Phases (As Needed)
| Q&A Phase | Version Phase | When | What Gets Filled |
|-----------|---------------|------|------------------|
| **Phase 6** | As needed | When designing data layer | Data & Persistence |
| **Phase 7** | As needed | When building UI | User Interface |
| **Phase 8** | As needed | When designing API | API Design |
| **Phase 9** | As needed | When adding workers | Background Jobs |
| **Phase 10** | As needed | When adding analytics | Analytics & Observability |

### Secure/Compliance Phases (secure Quality Only)
| Q&A Phase | Version Phase | When | What Gets Filled |
|-----------|---------------|------|------------------|
| **Phase 11** | For secure Quality | When compliance needed | Threat Modeling |
| **Phase 12** | For secure Quality | When compliance needed | Compliance Requirements (GDPR, HIPAA, etc.) |
| **Phase 13** | For secure Quality | When compliance needed | Advanced Security |
| **Phase 14** | For secure Quality | When compliance needed | Audit Logging |
| **Phase 15** | For secure Quality | When compliance needed | Incident Response |
| **Phase 16** | For secure Quality | When compliance needed | Security Governance |

**Workflow:**
1. **New project:** Conduct Project Context Q&A → establish "agreement to go and build" → `docs/context/project_context.md`
2. **Project setup:** Conduct Phase 0 Q&A → fill basic specs → implement v0.0.x (setup)
3. **Before first feature:** Conduct Phase 1 Q&A → fill technical specs → implement v0.1.x (first feature)
4. **Before production:** Conduct Phases 2-5 Q&A → fill production specs → deploy
5. **Feature-specific:** Conduct Phases 6-10 as needed → fill feature specs → implement
6. **If secure Quality:** Conduct Phases 11-16 Q&A → fill compliance specs → harden

This ensures specs are filled progressively as the project matures, avoiding overwhelming upfront documentation. Each phase takes 10-30 minutes, allowing for incremental progress. The Project Context phase establishes the "who, what, why, when, where" before diving into technical "how."

## Planning Workflow
1. **For new projects:** 
   - Start with Project Context Q&A to establish business/organizational context
   - Use Phase 0+ Q&A guides to fill technical specs
   - The Project Context informs Quality level and technical decisions
2. Draft or update `docs/specs/technical_design_spec.md` covering the above (Overview/Goals should summarize key points from Project Context).
3. Reconcile the design and component inventory with `docs/specs/codebase_spec.md` and applicable addenda in `docs/specs/lang/`.
4. Propose the next semantic version in `docs/specs/versions_spec.md` with `[Next]` if broader work is planned.
5. Break work into requirements under that version.
6. Review with human; revise as needed. When a design/scope decision is approved, add an entry to `docs/specs/decisions_spec.md` (date, context, decision, consequences).
7. Implement; log using the versions file (tick items, add Notes, mark `[Implemented]`). Reference any new decision log entries in the version's `### Notes`.
8. For bugfixes or unlogged changes, append microversions.
