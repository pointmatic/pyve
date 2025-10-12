# Decision Log

A lightweight log of key architectural, process, and tooling decisions. Each entry includes context, decision, and consequences. New decisions should be appended to the top.

## Template
Copy/paste this snippet when adding a new decision:

```markdown
## YYYY-MM-DD: Short Title of Decision
- Context: Brief background and alternatives considered.
- Decision: What we chose and why.
- Consequences: Immediate and long‑term effects, trade‑offs.
- Links: PR(s), discussion, related version(s) and Notes anchors.
```

## 2025-10-12: Dependency and Version Management Policy
- Context: Prior guidance pinned only top-level packages in `requirements.txt` without ranges and discouraged constraints/lock tooling. We want a reliable, updatable, and LLM-friendly workflow that preserves reproducibility.
- Decision: Adopt `docs/dependencies.md` as the single source of truth.
  - Applications: use `pip-tools` with `requirements.in` (ranges) → compiled `requirements.txt` (exact pins + hashes). Install strictly from the lockfile. Update via `pip-compile --upgrade` with tests and audits.
  - Libraries: declare bounded ranges in `pyproject.toml`; avoid hard pins for consumers; test with `constraints.txt`.
- Consequences: Clear policy for updates, fewer breakages from unbounded installs, deterministic deploys, and explicit separation between app and library practices.
- Links: See `docs/dependencies.md`.

## 2025-10-12: Documentation Split and Process Clarification
- Context: `docs/versions.md` was carrying process guidance that made it noisy.
- Decision: Create separate docs for process and keep `versions.md` focused on history.
  - `docs/building.md`: roles, workflow, dependencies, commands policy.
  - `docs/planning.md`: phases, versioning, how to author `technical_design.md`.
  - `docs/testing.md`: testing strategies and guidance.
- Consequences: Clearer responsibilities, easier onboarding; `versions.md` remains a concise history.

## 2025-10-12: Dependency Pinning Policy (Superseded by 2025-10-12: Dependency and Version Management Policy)
- Context: Need a stable, reproducible environment while avoiding over-pinning.
- Decision: Install top‑level packages via `pip install {package}` (no version), record the installed version, and pin only that package in `requirements.txt` with `=={version}`. Do not pin transitive dependencies or use ranges (`>=`, `<`).
- Consequences: Reproducible top-level set with flexibility for transitive updates; simpler upgrades.

## 2025-10-12: Command Safety Policy
- Context: Allow the LLM to run safe commands but avoid destructive operations.
- Decision: OK to run `pip install` (one package at a time), `pytest`, and program entry points. Not OK to run `rm` or `mv`; ask human first (prefer `git mv`).
- Consequences: Safer automation; human remains gatekeeper for destructive actions.

## 2025-10-12: Versioning and Microversions
- Context: Need structured logging of changes and bugfixes.
- Decision: Use semantic versions `v{major}.{minor}.{incremental}`; append microversions `a/b/c/...` for quick follow‑up bugfixes not already captured in `docs/versions.md` (e.g., `v0.0.2a`). Use `[Next]` tag to propose a future semantic version tied to a broader plan.
- Consequences: Transparent history; clear separation between planned work and immediate fixes.
