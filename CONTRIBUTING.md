# Contributing

Thank you for contributing! This guide explains how to work on this project.

## Documentation

- Building guide: `docs/guides/building_guide.md`
- Decision log: `docs/specs/decisions_spec.md`
- Version history: `docs/specs/versions_spec.md`
- Features spec: `docs/specs/features.md`

## Project Setup

Pyve is a Bash shell script project. To contribute:

1. Clone the repository
2. Make changes to `pyve.sh` or `lib/*.sh`
3. Test locally with `./pyve.sh --help`
4. Test `--init` and `--purge` in a temporary directory

## Versioning Workflow

All work is tracked in `docs/specs/versions_spec.md`:
- Add a new version at the top with a checklist of requirements
- Mark completed items `[x]`; append `[Implemented]` when complete
- Record major decisions in `docs/specs/decisions_spec.md`

## Code Style

- **Shell**: Bash 3.2+ compatible (no associative arrays, no `${var,,}`)
- **Modular**: Keep helper functions in `lib/*.sh`
- **Logging**: Use `log_info()`, `log_warning()`, `log_error()` from `lib/utils.sh`
- **Comments**: Minimal but clear function headers

## Testing

Test commands manually before submitting:
```bash
# In a temp directory
mkdir /tmp/pyve-test && cd /tmp/pyve-test
/path/to/pyve.sh --init
/path/to/pyve.sh --purge
```

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

## Security

- Do not commit secrets
- `.env` files should have `chmod 600` permissions

## Commits and PRs

- Keep changes scoped to the current version requirements
- Reference the version in PR title (e.g., "Implement v0.6.1")
- Summarize what changed and why

## Running the CLI
- Provide examples in the README and/or `docs/specs/technical_design_spec.md` matched to this project’s interfaces.
- Keep examples minimal and self‑verifying where possible.
