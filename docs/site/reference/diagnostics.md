# Diagnostics

Two complementary read-only commands: [`check`](#check) diagnoses problems with CI-safe exit codes; [`status`](#status) is the always-exit-0 state dashboard.

## `check`

Diagnose environment problems and suggest one actionable remediation per failure. Replaces the v1.x `pyve doctor` (diagnostics) and `pyve validate` (CI-safe exit codes) commands.

**Usage:**

```bash
pyve check [--fix [--yes]]
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

**Exit codes** (the composed contract, v3.0+):

- `0` — all checks passed, or warnings only (environment works but is drifting; the advisory text is still printed)
- `2` — one or more errors (environment is broken for `pyve run` / `pyve test`)

Safe for CI use.

### `check --fix` — self-healing

`pyve check --fix` runs the same diagnostics, then detects broken **Pyve-managed state** and repairs it. It is plan-then-confirm: the detected faults and intended repairs are always printed first, and nothing is repaired without assent (`--yes`, or an interactive confirmation). Two tiers:

- **Non-destructive (hosting)** — Pyve-owned, deterministically rebuildable state: a toolchain venv or hosted `project-guide` that exists but cannot run (dead interpreter symlink, dead shebang), a dangling `~/.local/bin/project-guide` shim. Repaired via the `self provision` machinery / a shim re-link. Applied on batch assent.
- **Destructive (project envs)** — repairs that destroy a materialized tree before recreating it: a broken root env (`pyve init --force`), a broken named env (`pyve env init <name> --force`), a root venv whose interpreter drifted off the declared pin (rebuild toward the pin), an orphaned tree the manifest doesn't declare (removed — the manifest is canonical). Each is **individually confirmed** in an interactive run; `--yes` assents to those prompts too.

Ground rules:

- A **non-interactive run never applies destructive repairs** — even with `--yes` they are reported and skipped, so `pyve check --fix --yes` is safe in CI (you get the non-destructive tier only).
- Without `--yes`, a non-interactive run is fully report-only; an interactive run prompts.
- Declining one repair skips only that repair.
- Idempotent: the plan is recomputed from live probes, so a re-run after success reports "Nothing to heal." and a re-run after a partial failure retries only what is still broken.
- The exit code reflects the **pre-repair** diagnostics; a healed system goes green on the next run. What was never provisioned, healthy-but-stale, or project-managed is not a fault — heal repairs broken state, it never installs-from-nothing or upgrades.

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
  testenv:        present, pytest installed

[project-guide]
  pyve-hosted (toolchain) v2.15.1
```

(project-guide reports in its own `[project-guide]` section — one readout naming *how* it is present: `pyve-hosted (toolchain)`, `local pip`, or `not installed`, with the runnability-probed version.)

## See also

- [Project Lifecycle](lifecycle.md) — the remediation verbs `check` points at (`init --force`, `update`, `upgrade`)
- [CI/CD Integration](../ci-cd.md) — using the exit-code contract in pipelines
- [Usage Guide](../usage.md) — command overview and universal flags
