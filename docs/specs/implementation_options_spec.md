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
  - Shell quality gates pass: `shellcheck` clean; `shfmt` consistent formatting.
  - User-facing output is concise; final `direnv allow` message appears last; template copy noise is suppressed with logs in `./.pyve/status/init_copy.log`.

## Quality
- Quality Level: prototype
- Guidance (apply based on chosen level):
  - Experiment: speed over rigor; minimal tests; throwaway acceptable.
  - Prototype: validate function/UX; basic error handling; smoke tests.
  - Production: reliability, observability, CI/CD, SLOs, on-call readiness.
  - Secure: threat modeling, hardening, least-privilege, audits/compliance.
- Entry/Exit criteria:
  - Minimum gates for Prototype (Pyve):
    - Shell lint/format: `shellcheck` clean for `pyve.sh`; `shfmt` consistent formatting.
    - Basic tests: manual smoke tests for `--install`, `--init` (fresh/re-run), `--purge`, `--version`, `--config` on macOS (zsh).
    - Documentation: `README.md` usage up to date; `docs/specs/versions_spec.md` updated per release; decisions logged in `docs/specs/decisions_spec.md`.
    - Safety: no destructive operations without explicit prompts/messages; idempotent behavior for re-runs where applicable.
    - Release: bump `VERSION` in `pyve.sh`; install verifies expected version via `pyve --version`.
  - Promotion to Production would add: automated tests in CI, wider OS/arch matrix (macOS + Linux, x86_64/arm64), stricter error handling/observability, and release automation.

## Option Matrix
Evaluate candidates for each domain. Capture tradeoffs and selection rationale.

### Languages & Runtimes
- Implementation language: Z shell (zsh) script; no bash target at this time.
- Supported OS/arch: macOS (Apple Silicon and Intel) where zsh is the default shell.
- Python stance: version-agnostic. Pyve orchestrates local version via `asdf` (or `pyenv`) and `venv`; a practical default is provided (`DEFAULT_PYTHON_VERSION` in `pyve.sh`) but not enforced.
- Rationale: single-file shell approach minimizes dependencies and aligns with solo-maintainer constraints.

### Frameworks (web/CLI/worker)
- CLI model via single Z shell script; no external CLI frameworks.
- Rationale: minimal dependencies and straightforward installation.

### Packaging & Distribution
- Form factor: single Z shell script (`pyve.sh`) installed to `~/.local/bin` with a `pyve` symlink.
- Distribution: Git repository source; no Homebrew/PyPI package at this time.
- Versioning: `VERSION` constant in `pyve.sh`; changes logged in `docs/specs/versions_spec.md`.
- Install behavior: robust handoff to source repo when needed; identical-target copies are skipped but permissions/symlink ensured.

### Data & State
- No databases or services.
- Local filesystem state only:
  - Project: `./.pyve/version`, `./.pyve/status/*` (init/purge logs and markers).
  - User cache: `~/.pyve/templates/v{major.minor}` stored immutably per version; `~/.pyve/source_path` recorded.

### Infrastructure & Hosting
- Not applicable; local CLI tool with no hosted components.

### Authentication & Security
- No auth flows. Security stance:
  - Avoid destructive actions without explicit messaging; skip or fail safe.
  - Do not handle secrets beyond encouraging `.env` usage; never exfiltrate.

### Observability
- CLI output only; concise messages with the `direnv allow` reminder printed last on `--init`.
- Template copy runs quietly with details logged to `./.pyve/status/init_copy.log`.
- Exit codes indicate success/failure; no metrics or tracing.

### Protocols & Integration
- No network protocols or integrations.

### Tooling
- Lint/format: `shellcheck` (lint), `shfmt` (format) for `pyve.sh`.
- Docs: version history and notes in `docs/specs/versions_spec.md`; decisions in `docs/specs/decisions_spec.md`; project docs in `docs/guides/` and `docs/specs/`.
- Hooks (optional): pre-commit with `shellcheck`/`shfmt` recipes later.
- CI: deferred until Production; aim for smoke tests on macOS runners.

Commands (local):

```bash
# Lint
shellcheck pyve.sh

# Format (in-place)
shfmt -w -i 2 -bn -ci pyve.sh
```

Optional pre-commit snippet: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/codespell-project/codespell
    rev: v2.3.0
    hooks:
      - id: codespell
        args: ["-L", "teh"]
  - repo: https://github.com/jumanjihouse/pre-commit-hooks
    rev: 3.0.0
    hooks:
      - id: shfmt
        args: ["-i", "2", "-bn", "-ci"]
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck
        files: ^pyve\.sh$
```

## Candidate Option (Template)
- Summary
- Pros
- Cons
- Risks & Mitigations
- Fit vs constraints
- Estimated effort
- References

## Decision
- Selected option(s) per domain with rationale
- Deferred choices and triggers to revisit

## Impact
- Consequences to code structure, operations, cost, and team processes
