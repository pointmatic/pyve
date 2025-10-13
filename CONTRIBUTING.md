# Contributing

Thank you for contributing! This guide explains how to work on this project, aligned with the docs in `docs/`.

- Building guide: `docs/building.md`
- Planning guide: `docs/planning.md`
- Testing guide: `docs/testing.md`
- Decision log: `docs/decisions.md`
- Codebase spec (master): `docs/codebase_spec.md`

## Project Setup
- Python 3.11+
- Create/activate a virtualenv.
- Consider using Pyve to automatically set up your local Python environment (see https://github.com/pointmatic/pyve).
- Install top‑level packages one at a time (see Dependency Policy), then run tests:
  ```bash
  python -m pip install -r requirements.txt
  pytest -q
  ```

## Dependency Policy
- See `docs/dependencies.md` for the single source of truth on dependency and version management (apps vs libs, `requirements.in` → `requirements.txt`, update workflow).

## Command Policy
- OK: `pip install {package}` (one at a time), `pytest`, invoking program entry points (e.g., `python -m merge_docs.cli`).
- Not OK: destructive commands like `rm`, `mv`. Ask before deleting/renaming files (prefer `git mv`).

## Versioning Workflow
- All work is tracked in `docs/versions.md`.
- Add a new version at the top with a checklist of requirements.
- Implementation should only address the listed requirements for the targeted version.
- Mark completed items `[x]`; append `[Implemented]` to the version title when everything is complete.
- Microversions `a/b/c/...` are used for quick bugfixes/error follow‑ups not already captured (e.g., `v0.0.2a`).
- Propose broader work as the next semantic version with `[Next]` for review.
- Record major decisions in `docs/decisions.md` and reference them in the current version's `### Notes`.
  - Example “Decision reference” bullet for Notes:
    - Decision: [2025-10-12: Switch to Service Account Auth](docs/decisions.md#2025-10-12-switch-to-service-account-auth) — requires sharing Sheet/Doc with the service account; update CI secrets.

## Planning
- For significant features, update or create `docs/technical_design.md` (see `docs/planning.md` for structure).
- Add a `[Next]` version in `docs/versions.md` to outline upcoming work.

## README Checklist
When creating a minimal README for a new project stub, include:
- **Project summary**: One‑sentence purpose and audience.
- **Prerequisites**: Python version, virtualenv, credentials expectations.
- **Installation**: Install from `requirements.txt` per dependency policy.
- **Quickstart**: One or two commands to verify something runs (e.g., placeholder extraction).
- **Usage**: Main CLI commands/flags or a link to `docs/technical_design.md` for details.
- **Configuration**: Env vars/flags (e.g., `SHEET_ID`, `TEMPLATE_DOC_ID`, `OUTPUT_FOLDER_ID`).
- **Examples**: Pointers to `examples/` and sample flows.
- **Docs links**: `docs/building.md`, `docs/planning.md`, `docs/testing.md`, `docs/decisions.md`, `docs/versions.md`.
- **Contributing**: Link to `CONTRIBUTING.md`.
- **Security**: Don’t commit secrets; how to provide `credentials.json` locally.
- **License**: If applicable.

## Testing
- Strategy levels: Minimal, Moderate, Complete (see `docs/testing.md`).
- Aim to keep `pytest -q` green.
- Use sample data in `examples/` where applicable.

## Coding
- Language: Python 3.11+.
- Keep imports at the top of files.
- Add clear, minimal code; avoid unused abstractions.

## Commits and PRs
- Keep changes scoped to the current version requirements.
- Reference the version being implemented in the PR title/description (e.g., "Implement v0.0.2: Hello World").
- Summarize what changed, why, and any Notes relevant to the version.

## Security
- Do not commit secrets (credentials, tokens). Use environment variables and local files like `credentials.json`.
- Follow least-privilege principles for Google API scopes and sharing.

## Running the CLI
- Placeholder extraction example:
  ```bash
  python -m merge_docs.cli extract examples/template.txt
  ```
- Future commands will be documented in `docs/technical_design.md` and the README.
