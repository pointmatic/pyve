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

## 2025-10-13: Install Handoff and Idempotency Policies
- Context: Version mismatches and noisy failures during install/init.
- Decision:
  - Install handoff: delegate to recorded source or local ./pyve.sh when appropriate; guard with PYVE_SKIP_HANDOFF.
  - Idempotent init: treat `./.pyve/status/init` (and benign files) as safe; skip copy; fail on unexpected status files.
  - Identical-target install: skip copy if identical; ensure executable and symlink.
  - Noise suppression: disable tracing in [init_copy_templates()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:628:0-698:1), log to `./.pyve/status/init_copy.log`.
  - Direnv guidance ordering: print last in `--init`.
- Consequences: Reliable installs, repeatable init, cleaner UX.
- Links: [pyve.sh](cci:7://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:0:0-0:0), [docs/specs/versions_spec.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:0:0-0:0) (v0.3.2a and v0.3.3 Notes), `docs/guides/building_guide.md`.

## 2025-10-12: Dependency and Version Management Policy
- Context: Prior guidance pinned only top-level packages in `requirements.txt` without ranges and discouraged constraints/lock tooling. We want a reliable, updatable, and LLM-friendly workflow that preserves reproducibility.
- Decision: Adopt `docs/guides/dependencies_guide.md` as the single source of truth.
  - Applications: use `pip-tools` with `requirements.in` (ranges) → compiled `requirements.txt` (exact pins + hashes). Install strictly from the lockfile. Update via `pip-compile --upgrade` with tests and audits.
  - Libraries: declare bounded ranges in `pyproject.toml`; avoid hard pins for consumers; test with `constraints.txt`.
- Consequences: Clear policy for updates, fewer breakages from unbounded installs, deterministic deploys, and explicit separation between app and library practices.
- Links: See `docs/guides/dependencies_guide.md`.

## 2025-10-12: Documentation Split and Process Clarification
- Context: `docs/versions.md` was carrying process guidance that made it noisy.
- Decision: Create separate docs for process and keep versions history in `docs/specs/versions_spec.md`.
  - `docs/guides/building_guide.md`: roles, workflow, dependencies, commands policy.
  - `docs/guides/planning_guide.md`: phases, versioning, how to author `technical_design_spec.md`.
  - `docs/guides/testing_guide.md`: testing strategies and guidance.
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
- Decision: Use semantic versions `v{major}.{minor}.{incremental}`; append microversions `a/b/c/...` for quick follow‑up bugfixes not already captured in `docs/specs/versions_spec.md` (e.g., `v0.0.2a`). Use `[Next]` tag to propose a future semantic version tied to a broader plan.
- Consequences: Transparent history; clear separation between planned work and immediate fixes.
