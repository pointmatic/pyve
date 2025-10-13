# Dependency and Version Management

This doc is the single source of truth for managing Python dependencies and versions.
It is optimized so an LLM can safely update packages while keeping environments reproducible.

## Choose the strategy by project type
- **Applications/services (deployable apps):** lock exact versions for repeatable builds.
- **Libraries (to be published/consumed by others):** specify version ranges; do not hard‑pin transitive deps for users.

## Applications: use pip‑tools with requirements.in → requirements.txt
- **Author intent in `requirements.in`** using ranges (PEP 440): prefer `~=` or bounded `<`.
  ```
  fastapi~=0.115
  uvicorn[standard]>=0.23,<0.32
  pydantic>=2.6,<3
  httpx>=0.27,<0.28
  ```
- **Compile locked pins (including transitives) to `requirements.txt`** with hashes:
  ```bash
  pip-compile --generate-hashes
  # update to latest within allowed ranges
  pip-compile --upgrade --generate-hashes
  ```
- **Install for dev/CI/prod** strictly from the compiled lockfile:
  ```bash
  python -m pip install -r requirements.txt
  ```
- **Multiple environments** (optional):
  - `base.in`, `dev.in`, `test.in`, `prod.in`. Compile each to `.txt`.
  - Share pins by referencing: put `-r base.txt` at the top of others.

## Libraries: declare ranges in pyproject.toml
- In `pyproject.toml`:
  ```toml
  [project]
  dependencies = [
    "pydantic>=2.6,<3",
    "httpx>=0.27,<0.28",
  ]
  ```
- Do not pin exact versions for consumers. Test with a periodically updated `constraints.txt` in CI:
  ```bash
  python -m pip install -c constraints.txt -e .[dev]
  ```

## Version spec guidance (PEP 440)
- **Prefer:**
  - Compatible release: `requests~=2.32` → `>=2.32,<3.0`.
  - Bounded ranges: `>=1.4,<2.0`.
- **Avoid:**
  - Unbounded `>=` with no upper cap.
  - Pinning direct deps in libraries.
- **Markers/extras:** `importlib-metadata>=6; python_version<"3.10"`, `uvicorn[standard]`.

## When and how to update
- **Check updates:** `pip list --outdated`, `pip index versions <pkg>`.
- **Automate PRs:** Dependabot/Renovate (optional).
- **Security:** `pip-audit` (or `uv audit`) regularly.
- **Routine cycle:**
  1. Update within allowed ranges: `pip-compile --upgrade`.
  2. `pip install -r requirements.txt`.
  3. Run tests and type checks; scan changelogs for notable changes.
  4. For breaking/major upgrades, widen ranges deliberately in `.in` (or `pyproject.toml`) and iterate on fixes.

## Extra safeguards
- Pin the Python runtime in CI and docs (e.g., 3.11/3.12) and test what you claim to support.
- Use a temporary `constraints.txt` to hot‑fix a bad upstream release across multiple lockfiles.
- Split `dev` tooling into a separate `dev.in` to keep production lean and deterministic.

## Quick recipes
- **Add a new package (app):**
  1. Add a bounded spec to `requirements.in`.
  2. Run `pip-compile --generate-hashes`.
  3. `pip install -r requirements.txt` and commit both files.
- **Bump everything allowed (app):** `pip-compile --upgrade --generate-hashes` then reinstall and test.
- **Library policy:** keep ranges narrow enough to be safe but broad enough to avoid dependency hell; use CI matrices to test min/max versions within your ranges.
