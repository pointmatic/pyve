# Python Dependency and Version Management

This guide defines policies and workflows for managing Python dependencies and versions. It is intended for Python codebases.

## Choose the strategy by project type
- Applications/services: lock exact versions for repeatable builds.
- Libraries: specify version ranges; do not hard‑pin transitive deps for users.

## Applications: use pip‑tools with requirements.in → requirements.txt
- Author intent in `requirements.in` using ranges (PEP 440). Prefer `~=` or bounded `<`.
```
fastapi~=0.115
uvicorn[standard]>=0.23,<0.32
pydantic>=2.6,<3
httpx>=0.27,<0.28
```
- Compile locked pins (including transitives) to `requirements.txt` with hashes:
```
pip-compile --generate-hashes
# update to latest within allowed ranges
pip-compile --upgrade --generate-hashes
```
- Install strictly from the compiled lockfile:
```
python -m pip install -r requirements.txt
```
- Multiple environments (optional): maintain `base.in`, `dev.in`, `test.in`, `prod.in`; compile each; share pins via `-r base.txt`.

## Libraries: declare ranges in pyproject.toml
In `pyproject.toml`:
```toml
[project]
dependencies = [
  "pydantic>=2.6,<3",
  "httpx>=0.27,<0.28",
]
```
Do not pin exact versions for consumers. Test with a periodically updated `constraints.txt` in CI:
```
python -m pip install -c constraints.txt -e .[dev]
```

## Version spec guidance (PEP 440)
- Prefer:
  - Compatible release: `requests~=2.32` → `>=2.32,<3.0`.
  - Bounded ranges: `>=1.4,<2.0`.
- Avoid:
  - Unbounded `>=` with no upper cap.
  - Pinning direct deps in libraries.
- Markers/extras examples: `importlib-metadata>=6; python_version<"3.10"`, `uvicorn[standard]`.

## When and how to update
- Check updates: `pip list --outdated`, `pip index versions <pkg>`.
- Automate PRs: Dependabot/Renovate (optional).
- Security: `pip-audit` (or `uv audit`) regularly.
- Routine cycle:
  1. Update within ranges: `pip-compile --upgrade`.
  2. `pip install -r requirements.txt`.
  3. Run tests and type checks; scan changelogs.
  4. For breaking/major upgrades, widen ranges deliberately in `.in` (or `pyproject.toml`) and iterate.

## Extra safeguards
- Pin the Python runtime in CI and docs (e.g., 3.11/3.12) and test what you claim to support.
- Use a temporary `constraints.txt` to hot‑fix a bad upstream release across multiple lockfiles.
- Split dev tooling into `dev.in` to keep production lean/deterministic.

## Quick recipes
- Add a new package (app):
  1. Add a bounded spec to `requirements.in`.
  2. Run `pip-compile --generate-hashes`.
  3. `pip install -r requirements.txt` and commit both files.
- Bump everything allowed (app): `pip-compile --upgrade --generate-hashes`, reinstall, and test.
- Library policy: keep ranges safe yet broad enough; use CI matrices to test min/max within your ranges.
