# Diagnostics

Two complementary read-only commands: [`check`](#check) diagnoses problems with CI-safe exit codes; [`status`](#status) is the always-exit-0 state dashboard.

## `check`

Diagnose environment problems and suggest one actionable remediation per failure. Replaces the v1.x `pyve doctor` (diagnostics) and `pyve validate` (CI-safe exit codes) commands.

**Usage:**

```bash
pyve check
```

**What it checks:**

- `pyve.toml` presence and schema validity (the manifest is the declaration)
- Backend configured and implementation available (micromamba binary, when applicable)
- Environment path exists and has `bin/python`
- Python version matches the pinned source-of-truth (`.tool-versions` / `.python-version`)
- Venv path sanity (warns if project was relocated after creation)
- `.envrc` / `.env` presence
- `conda-lock.yml` presence and freshness (micromamba only)
- Duplicate `.dist-info` directories in `site-packages` (micromamba only)
- iCloud-Drive collision artifacts (macOS, micromamba only)
- conda/pip native-library conflicts (micromamba only)
- Named-env status (if the project uses `pyve test`)
- Env-spec drift — a non-empty diff between the planned env spec (§4 of `docs/specs/env-dependencies.md`, path read from `.project-guide.yml`'s `env_spec_path`) and `pyve.toml` warns with a "run `pyve env sync` to reconcile" hint (exit stays 0)
- An info-only `[defaults]` section reports when Pyve's built-in defaults changed since the project was created — reported, never applied retroactively

**Exit codes:**

- `0` — all checks passed
- `1` — one or more errors (environment is broken for `pyve run` / `pyve test`)
- `2` — warnings only (environment works but is drifting)

Safe for CI use.

**Example output:**

```
Pyve Environment Check
======================

✓ Configuration: pyve.toml
✓ Backend: venv
✗ Virtual environment: .venv (missing)
  → Run: pyve init --force
⚠ .env: missing
  → touch .env

1 error, 1 warning, 2 passed
```

Every failure points at exactly one command — no chains, no cross-references.

**Legacy forms removed in v2.0.** `pyve doctor` and `pyve validate` now error out with a migration message pointing at `pyve check`. Update CI scripts that grep for "Pyve Installation Validation" to match `Pyve Environment Check` or use `pyve status` for state snapshots.

---

## `status`

Read-only project-state dashboard. Companion to `pyve check`: state here, diagnostics there.

**Usage:**

```bash
pyve status
```

**Output sections:**

- **Project** — path, backend, declaration (`pyve.toml`), configured Python
- **Environment** — path, Python, package count, backend-specific rows (environment.yml + lock status for micromamba)
- **Integrations** — direnv, `.env`, project-guide, testenv

**Exit code:** always `0` unless pyve itself errors (e.g., unreadable config). Never signals problems via non-zero exit — for that contract use `pyve check`.

**Example output:**

```
Pyve project status
───────────────────

Project
  Path:           /Users/foo/Developer/bar
  Backend:        venv
  Declaration:    pyve.toml
  Python:         3.14.4 (.tool-versions via asdf)

Environment
  Path:           .venv
  Python:         3.14.4
  Packages:       127 installed

Integrations
  direnv:         .envrc present
  .env:           present
  project-guide:  installed (v2.4.1)
  testenv:        present, pytest installed
```

## See also

- [Project Lifecycle](lifecycle.md) — the remediation verbs `check` points at (`init --force`, `update`, `upgrade`)
- [CI/CD Integration](../ci-cd.md) — using the exit-code contract in pipelines
- [Usage Guide](../usage.md) — command overview and universal flags
