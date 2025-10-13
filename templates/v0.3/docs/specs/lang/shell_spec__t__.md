# Shell Addendum

## Scope
- Applies to components with `Language: shell` in `docs/codebase_spec.md`.

## Shell Targets
- Preferred shells: bash (>=5). zsh supported where needed.
- Aim for POSIX compatibility unless features require otherwise.

## Dependencies
- Document required system tools and versions (e.g., `coreutils`, `grep`, `awk`, `sed`, `readlink`).
- Package names per platform (brew/apt) when relevant.

## Safety & UX
- Default to non-destructive operations; require explicit flags for mutation.
- Dry-run modes for impactful actions.
- Clear `ERROR:` prefixed messages; exit codes meaningful.

## Testing
- Framework: `bats` (if available) or simple script-based checks.
- Commands: `bats tests/` or `./scripts/test.sh`.

## Linting & Formatting
- Tools: `shellcheck`, `shfmt`.
- Commands:
  - `shellcheck scripts/*.sh` (or explicit files)
  - `shfmt -d scripts`

## Security
- Quote variables; `set -euo pipefail` where appropriate.
- Avoid sourcing untrusted files.
- Prefer explicit paths; avoid globbing surprises.

## CI
- Run lint and tests on macOS/Linux matrices if scripts are cross-platform.
