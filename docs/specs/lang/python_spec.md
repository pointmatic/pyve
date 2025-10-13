# Python Addendum

## Scope
- Applies to components with `Language: python` in `docs/specs/codebase_spec.md`.

## Runtimes
- Supported versions: specify a matrix (e.g., 3.11, 3.12).
- Pin CI interpreters to what you support.

## Dependency Policy
- Authoritative doc: `docs/guides/dependencies_guide.md`.
- Applications: use `requirements.in` → `pip-compile --generate-hashes` → install from `requirements.txt`.
- Libraries: declare bounded ranges in `pyproject.toml`; test with `constraints.txt`.

## Build & Packaging
- Tools: none | setuptools | hatch | poetry | uv.
- Entrypoints: console_scripts or `python -m <pkg>.cli`.

## Testing
- Framework: `pytest`.
- Command: `pytest -q`.
- Coverage target: set if applicable.

## Linting & Formatting
- Tools: `ruff`, `black`, `mypy`.
- Commands:
  - `ruff check .`
  - `black --check .`
  - `mypy src/` or package path

## Security
- Audits: `pip-audit` cadence (e.g., biweekly).
- Secrets: no commits; env-var driven; `.env` for local only.

## CI
- Matrix: OS and Python versions.
- Stages: lint → test → (build/release where applicable).
