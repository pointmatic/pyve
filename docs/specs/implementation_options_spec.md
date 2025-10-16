# Implementation Options

## Context and Constraints
- Business goals and success criteria
  - Streamline and standardize Python environment setup per repo.
  - Provide idempotent `--init`/`--purge` flows that are safe-by-default.
  - Ship and maintain documentation templates tied to tool versions.
  - Minimize dependencies and cognitive load; optimize developer experience (DX).
  - Ensure installs reflect latest repo source (robust handoff logic).
- Constraints
  - Platform: macOS + Z shell primary; Linux support planned; Windows/WSL not targeted yet.
  - Tooling prerequisites: user-installed `asdf` or `pyenv`, and `direnv`; script performs checks and guides user.
  - Safety: no destructive operations without clear messaging; prefer guardrails and skipping over failing silently.
  - Maintainability: maintained by a solo developer; prefer low-maintenance, single-file shell implementation over complex tooling.
  - Network/use constraints: avoid unnecessary external calls; operate locally where possible.
- Assumptions and out-of-scope
  - Out of scope (current): Windows/WSL; Bash; packaging to PyPI/homebrew; managing project application dependencies beyond policy docs.
  - Assumes repos are initialized at their root; user has standard POSIX tools available.
  - No telemetry/metrics; CLI output is the primary feedback channel.
- Success criteria
  - Smoke tests on macOS: `--install`, `--init` (fresh and re-run), `--purge`, `--version`, `--config`.
  - Docs updated per release: `README.md`, `docs/specs/versions_spec.md`, decisions in `docs/specs/decisions_spec.md`.
  - Syntax check passes: `zsh -n pyve.sh`; smoke tests cover main flows.
  - User-facing output is concise; final `direnv allow` message appears last; template copy noise is suppressed with logs in `./.pyve/status/init_copy.log`.

<!-- Phase 0: Project Basics -->
## Quality
- Quality Level: prototype
- Guidance (apply based on chosen level):
  - Experiment: speed over rigor; minimal tests; throwaway acceptable.
  - Prototype: validate function/UX; basic error handling; smoke tests.
  - Production: reliability, observability, CI/CD, SLOs, on-call readiness.
  - Secure: threat modeling, hardening, least-privilege, audits/compliance.
- Entry/Exit criteria:
  - Minimum gates for Prototype (Pyve):
    - Syntax check: `zsh -n pyve.sh` passes.
    - Basic tests: manual smoke tests for `--install`, `--init` (fresh/re-run), `--purge`, `--version`, `--config` on macOS (zsh).
    - Documentation: `README.md` usage up to date; `docs/specs/versions_spec.md` updated per release; decisions logged in `docs/specs/decisions_spec.md`.
    - Safety: no destructive operations without explicit prompts/messages; idempotent behavior for re-runs where applicable.
    - Release: bump `VERSION` in `pyve.sh`; install verifies expected version via `pyve --version`.
  - Promotion to Production would add: automated tests in CI, wider OS/arch matrix (macOS + Linux, x86_64/arm64), stricter error handling/observability, and release automation.

<!-- Phase 0: Project Basics -->
## Option Matrix
Evaluate candidates for each domain. Capture tradeoffs and selection rationale.

<!-- Phase 0: Project Basics -->
### Languages & Runtimes
- Implementation language: Z shell (zsh) script; no bash target at this time.
- Supported OS/arch: macOS (Apple Silicon and Intel) where zsh is the default shell.
- Python stance: version-agnostic. Pyve orchestrates local version via `asdf` (or `pyenv`) and `venv`; a practical default is provided (`DEFAULT_PYTHON_VERSION` in `pyve.sh`) but not enforced.
- Rationale: single-file shell approach minimizes dependencies and aligns with solo-maintainer constraints.

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
### Frameworks (web/CLI/worker)
- CLI model via single Z shell script; no external CLI frameworks.
- Rationale: minimal dependencies and straightforward installation.

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
### Packaging & Distribution
- Form factor: single Z shell script (`pyve.sh`) installed to `~/.local/bin` with a `pyve` symlink.
- Distribution: Git repository source; no Homebrew/PyPI package at this time.
- Versioning: `VERSION` constant in `pyve.sh`; changes logged in `docs/specs/versions_spec.md`.
- Install behavior: robust handoff to source repo when needed; identical-target copies are skipped but permissions/symlink ensured.

<!-- Phase 1: Core Technical -->
### Data & State
- No databases or services.
- Local filesystem state only:
  - Project: `./.pyve/version`, `./.pyve/status/*` (init/purge logs and markers).
  - User cache: `~/.pyve/templates/v{major.minor}` stored immutably per version; `~/.pyve/source_path` recorded.

<!-- Phase 0: Project Basics (deployment decision) | Phase 2: Production Readiness (details) -->
### Infrastructure & Hosting
- Not applicable; local CLI tool with no hosted components.

<!-- Phase 2: Production Readiness | Phase 3: Secure/Compliance -->
### Authentication & Security
- No auth flows. Security stance:
  - Avoid destructive actions without explicit messaging; skip or fail safe.
  - Do not handle secrets beyond encouraging `.env` usage; never exfiltrate.

<!-- Phase 2: Production Readiness -->
### Observability
- CLI output only; concise messages with the `direnv allow` reminder printed last on `--init`.
- Template copy runs quietly with details logged to `./.pyve/status/init_copy.log`.
- Exit codes indicate success/failure; no metrics or tracing.

<!-- Phase 1: Core Technical -->
### Protocols & Integration
- No network protocols or integrations.

<!-- Phase 1: Core Technical -->
### Tooling
- Syntax check: `zsh -n pyve.sh`.
- Smoke tests: exercise `--install`, `--init` (fresh/re-run), `--purge`, `--version`, `--config`.
- Docs: version history and notes in `docs/specs/versions_spec.md`; decisions in `docs/specs/decisions_spec.md`; project docs in `docs/guides/` and `docs/specs/`.
- Future CI: containerized tests (e.g., Podman + Alpine with zsh) to run targeted test scripts that exercise features/options.

<!-- Template: Copy/paste this section to evaluate specific options in detail -->
## Candidate Option (Template)
- Summary
- Pros
- Cons
- Risks & Mitigations
- Fit vs constraints
- Estimated effort
- References

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
## Decision
- Selected option(s) per domain with rationale
- Deferred choices and triggers to revisit

<!-- Phase 1: Core Technical -->
## Impact
- Consequences to code structure, operations, cost, and team processes
