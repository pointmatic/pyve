# Migration guide — pyve v1.x → v2.0

pyve 2.0 rewires the top-level command surface for consistency. Most users will see zero disruption: the high-traffic commands (`init`, `purge`, `run`, `test`, `lock`) are unchanged. The changes cluster around diagnostics (`doctor` / `validate` merged into `check` + `status`) and a handful of flag-to-subcommand conversions.

For the full rationale, see [phase-H-cli-refactor-design.md](https://github.com/pointmatic/pyve/blob/main/docs/specs/phase-H-cli-refactor-design.md) and [phase-H-check-status-design.md](https://github.com/pointmatic/pyve/blob/main/docs/specs/phase-H-check-status-design.md). The canonical per-change record is [CHANGELOG.md](https://github.com/pointmatic/pyve/blob/main/CHANGELOG.md).

## What breaks immediately

Typing any of these in v2.0 prints a migration error and exits 1:

| v1.x form | v2.0 replacement |
|---|---|
| `pyve doctor` | `pyve check` |
| `pyve validate` | `pyve check` |
| `pyve init --update` | `pyve update` |
| `pyve --update` | `pyve update` |
| `pyve --doctor` | `pyve check` |
| `pyve --status` | `pyve status` |

The error messages point at the replacement form verbatim, so CI logs that grep for specific strings should update to match.

### `doctor` / `validate` → `check` + `status`

v1.x `doctor` mixed state-reporting with diagnostics. v2.0 splits them:

- **`pyve check`** — diagnoses problems and suggests one remediation per failure. Exit codes: `0` pass, `1` errors, `2` warnings-only (CI-safe). Use this in CI and when something looks wrong.
- **`pyve status`** — read-only "what is this project?" dashboard. Always exits 0 unless pyve itself errors.

If your CI scripts ran `pyve validate`, switch to `pyve check` — the 0/1/2 exit-code contract is preserved. If they parsed `pyve doctor` stdout, switch to `pyve status` (layout-stable sectioned output) or `pyve check` (findings).

### `init --update` → `update`

`init --update` bumped `pyve_version` in `.pyve/config`. `pyve update` does that **and** refreshes `.gitignore`, `.vscode/settings.json`, and the `project-guide` scaffolding (if installed). Run `pyve update` whenever you upgrade pyve itself — no more venv destruction via `init --force` just to pick up a config change.

## What still works, but warns

The following forms continue to work through v2.x. They emit a one-shot deprecation warning to stderr on first use (scripted loops stay readable — warnings don't repeat within a single invocation). All four are scheduled for hard removal in v3.0.

| Deprecated form | Replacement |
|---|---|
| `pyve testenv --init` | `pyve testenv init` |
| `pyve testenv --install [-r <file>]` | `pyve testenv install [-r <file>]` |
| `pyve testenv --purge` | `pyve testenv purge` |
| `pyve python-version <ver>` | `pyve python set <ver>` |

Migrating now is painless — the new forms accept the same arguments and produce the same exit codes.

## What didn't change

- `pyve init [--backend venv|micromamba] [...]` — same flags, same semantics.
- `pyve purge [--keep-testenv]` — unchanged.
- `pyve run <cmd>` / `pyve test [pytest args]` — unchanged.
- `pyve lock [--check]` — unchanged.
- `pyve self install | uninstall` — unchanged.
- Environment variables (`PYVE_NO_PROJECT_GUIDE`, `PYVE_ALLOW_SYNCED_DIR`, etc.) — unchanged.

## Quick migration recipe

For a repo migrating from v1.x:

1. Upgrade pyve (`brew upgrade pyve` or the equivalent for your install method).
2. Run `pyve update` in each project directory — refreshes config and managed files.
3. Update any CI scripts: `pyve doctor` → `pyve check`, `pyve validate` → `pyve check`, `pyve init --update` → `pyve update`.
4. Grep your scripts for `pyve testenv --` and `pyve python-version` — rename at your leisure (they still work until v3.0).
