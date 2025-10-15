# Dependency and Version Management

This document is the single source of truth for managing dependencies and runtime versions across this codebase. Keep guidance language‑agnostic here; provide language‑specific details in `docs/guides/lang/`.

## Principles
- **Reproducibility:** lock exact versions where appropriate to ensure repeatable builds.
- **Clarity of intent:** express allowed ranges for libraries intended to be consumed by others.
- **Automation:** use tooling to consistently update, audit, and test dependency sets.

## Choose the strategy by project type
- **Applications/services (deployable apps):** lock dependencies via a generated lockfile appropriate to the ecosystem (e.g., Python: `requirements.txt` with hashes; Node: `package-lock.json`/`pnpm-lock.yaml`; Ruby: `Gemfile.lock`).
- **Libraries (published/consumed by others):** declare bounded version ranges; avoid hard‑pinning transitive dependencies for consumers; test against min/max ranges.

## Language‑specific guides
See `docs/guides/lang/` for concrete workflows, tools, and examples:
- Python: `docs/guides/lang/python_guide.md`
- Additional languages may add `docs/guides/lang/<language>_guide.md`.

## Update workflow (generic)
1. Assess updates using ecosystem tools (e.g., check outdated packages).
2. Update within allowed ranges; regenerate lockfiles as needed.
3. Install from lockfiles only in CI and production.
4. Run tests, type checks, and security audits.
5. For breaking changes, deliberately change declared ranges and iterate fixes.

## Security & Supply Chain
- Use ecosystem audit tools regularly.
- Prefer hashes/signatures where supported.
- Consider SBOM generation if applicable.

## CI Considerations
- Pin supported runtime versions in CI matrices.
- Test across supported OS/arch/runtime combinations where feasible.
