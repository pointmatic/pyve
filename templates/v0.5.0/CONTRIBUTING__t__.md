# Contributing

Thank you for contributing! This guide explains how to work on this project, aligned with the docs in `docs/`.

- Project context: `docs/context/project_context.md` (business/organizational context, if exists)
- Building guide: `docs/guides/building_guide.md`
- Planning guide: `docs/guides/planning_guide.md`
- Testing guide: `docs/guides/testing_guide.md`
- Decision log: `docs/specs/decisions_spec.md`
- Codebase spec (master): `docs/specs/codebase_spec.md`

## Project Setup
- Ensure required runtimes and tools are installed for this codebase (see `docs/specs/codebase_spec.md`).
- Create/activate a local development environment appropriate to the stack (e.g., venv, Node version manager, language toolchains).
- Consider using Pyve to automatically set up your local Python environment (see https://github.com/pointmatic/pyve).
- Install dependencies per the dependency policy, then run the test suite using the project’s standard commands.

## Dependency Policy
- See `docs/guides/dependencies_guide.md` for the single source of truth on dependency and version management (apps vs libs, `requirements.in` → `requirements.txt`, update workflow).

## Command Policy
- **OK:** installing a single dependency at a time via your ecosystem tool, running tests, invoking documented entry points.
- **Not OK:** destructive commands like `rm`, `mv` without review. Ask before deleting/renaming files (prefer `git mv`).

## Versioning Workflow
- All work is tracked in `docs/specs/versions_spec.md`.
- Add a new version at the top with a checklist of requirements.
- Implementation should only address the listed requirements for the targeted version.
- Mark completed items `[x]`; append `[Implemented]` to the version title when everything is complete.
- Microversions `a/b/c/...` are used for quick bugfixes/error follow‑ups not already captured (e.g., `v0.0.2a`).
- Propose broader work as the next semantic version with `[Next]` for review.
- Record major decisions in `docs/specs/decisions_spec.md` and reference them in the current version's `### Notes`.
  - Example “Decision reference” bullet for Notes:
    - Decision: [2025-10-12: Switch to Service Account Auth](docs/specs/decisions_spec.md#2025-10-12-switch-to-service-account-auth) — requires sharing Sheet/Doc with the service account; update CI secrets.

## Planning
- For new projects, start with Project Context Q&A (see `docs/guides/llm_qa/project_context_questions.md`) to establish business/organizational context before technical planning.
- For significant features, update or create `docs/specs/technical_design_spec.md` (see `docs/guides/planning_guide.md` for structure).
- Add a `[Next]` version in `docs/specs/versions_spec.md` to outline upcoming work.

## README Checklist
When creating a minimal README for a new project stub, include:
- **Project summary**: one-sentence purpose and audience.
- **Prerequisites**: required runtimes/tools; environment setup expectations.
- **Installation**: how to install/build or a note that the repo is source-only.
- **Quickstart**: one or two commands to verify something runs.
- **Usage**: main CLI commands/flags or link to `docs/specs/technical_design_spec.md`.
- **Configuration**: primary env vars/flags/files.
- **Examples**: pointers to `examples/` and sample flows (if applicable).
- **Docs links**: `docs/guides/building_guide.md`, `docs/guides/planning_guide.md`, `docs/guides/testing_guide.md`, `docs/specs/decisions_spec.md`, `docs/specs/versions_spec.md`.
- **Contributing**: link to `CONTRIBUTING.md`.
- **Security**: don’t commit secrets; where to place local credentials (if any).
- **License**: if applicable.

## Testing
- Strategy levels: Minimal, Moderate, Complete (see `docs/guides/testing_guide.md`).
- Aim to keep the test suite green.
- Use sample data in `examples/` where applicable.

## Coding
- Follow language and style conventions for this codebase.
- Keep imports/includes at the top as appropriate for the language.
- Add clear, minimal code; avoid unnecessary abstractions.

## Commits and PRs
- Keep changes scoped to the current version requirements.
- Reference the version being implemented in the PR title/description (e.g., "Implement v0.0.2: Hello World").
- Summarize what changed, why, and any Notes relevant to the version.

## Security
- Do not commit secrets (credentials, tokens). Use environment variables and local files like `credentials.json`.
- Follow least-privilege principles for Google API scopes and sharing.

## Running the CLI
- Provide examples in the README and/or `docs/specs/technical_design_spec.md` matched to this project’s interfaces.
- Keep examples minimal and self‑verifying where possible.
