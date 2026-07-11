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
- **Env runnability, not just existence** — a per-env canary executes a console-script wrapper (`bin/pip --version`) in the root env and every declared + materialized named env, and classifies what it finds (see the verdict vocabulary below). A dangling `python` symlink or a relocated env with dead shebangs can no longer report green.
- **Manifest↔disk orphans** — a materialized `.pyve/envs/<name>/` tree with no `[env.<name>]` declaration, or a tree materialized under a root declared with a non-materializable backend, is flagged as a contradiction (the manifest is canonical)
- Python version matches the pinned source-of-truth (`.tool-versions` / `.python-version`)
- Venv path sanity (warns if project was relocated after creation)
- `.envrc` / `.env` presence
- `conda-lock.yml` presence and freshness (micromamba only)
- Duplicate `.dist-info` directories in `site-packages` (micromamba only)
- iCloud-Drive collision artifacts (macOS, micromamba only)
- conda/pip native-library conflicts (micromamba only)
- Env-spec drift — a non-empty diff between the planned env spec (§4 of `docs/specs/env-dependencies.md`, path read from `.project-guide.yml`'s `env_spec_path`) and `pyve.toml` warns with a "run `pyve env sync` to reconcile" hint (exit stays 0)
- An info-only `[defaults]` section reports when Pyve's built-in defaults changed since the project was created — reported, never applied retroactively
- **Resolution reasoning (`[resolution]`)** — where each managed command (`python`, `pip`, `project-guide`) actually resolves from and why (see below)
- **Update availability (`[pyve]`)** — info-only staleness hints for the hosted tools and pyve itself (see below)

### Runnability verdicts (the canary)

Health used to be an existence test — and a broken env passes those: a relocated env keeps a valid `bin/python` symlink while every console script carries a dead baked-in shebang, so `python -c 'import pytest'` succeeds while `pytest` itself fails with `bad interpreter`. The canary executes a **wrapper** (the artifact that actually breaks) and classifies the result:

| Verdict | Meaning | Repair (role-correct) |
|---|---|---|
| `runnable` | wrapper executed and answered | — |
| `dead shebang` | console scripts point at a deleted/relocated interpreter | root → `pyve init --force`; named env → `pyve env init <name> --force` |
| `dangling symlink` | the env's `python` symlink target is gone | same rebuild verbs |
| `missing interpreter` | no `python` in the env at all | same rebuild verbs |
| `orphan` / contradiction | materialized but not declared (or declared non-materializable, yet materialized) | remove the tree |
| *(silent)* | not materialized, or a declarative-only (`none`/advisory) backend | not findings — legitimate states |

Every broken verdict prints with the rebuild verb for its role — a broken **root** env always routes to `pyve init --force` (the `pyve env` namespace is selection-only for `root`), a broken **named** env to its own `pyve env init <name> --force`.

### Resolution reasoning (`[resolution]`)

For each managed command, one line names the winning PATH slot (`project env`, `~/.local/bin`, `version-manager shim`, `system PATH`) and its probed version; a finding line appears only when something is wrong, carrying a bracketed machine class: `[venv-pin-drift]` (the env was created on a different interpreter than the current pin), `[no-version-set]` (a version-manager shim rejects the command under the active pin), `[broken-winner]`, `[not-found]`. Run with `--verbose` for the full slot-by-slot PATH trace (every provider, winner marked, shadowed entries named).

**Worked example** — the incident this feature automates. A developer's `.venv` was created on Python 3.14.4; `.tool-versions` later moved to 3.12.13; `project-guide` wasn't installed under the pin. Untangling that by hand took a four-layer PATH/pin/shim trace. `check` now narrates it unprompted:

```
[resolution]
python → /Users/dev/proj/.venv/bin/python (project env, 3.14.4)
  ⚠ shadows the version-manager pin (3.12.13): the env was created on a
    different interpreter than the current pin [venv-pin-drift]
  → Rebuild toward the pin: pyve init --force
pip → /Users/dev/proj/.venv/bin/pip (project env)
project-guide → /Users/dev/.asdf/shims/project-guide (version-manager shim)
  ⚠ the version-manager shim rejects it under the active pin
    ("No version is set") [no-version-set]
  → Run: pyve self provision   (hosts project-guide outside the pin)
```

Resolution findings are diagnostic narrative: they contribute at most a *warning* and never flip the exit code to an error.

### Update hints (`[pyve]`)

The `[pyve]` section (toolchain + project-guide hosting state) also surfaces **info-only** update hints — `pyve X.Y.Z is available (installed: …)` with the upgrade command for your install source (`brew upgrade pointmatic/tap/pyve` vs. `git pull && pyve self install`; project-guide → `pyve self provision`). This is `check`'s only network touch and it is strictly bounded: results cache for 24h, the probe runs only for interactive human runs (CI, piped output, and `--offline` / `PYVE_NO_NETWORK=1` all suppress it), and a network failure degrades silently — the exit code can never depend on the network.

**Exit codes** (the composed contract, v3.0+):

- `0` — all checks passed, or warnings only (environment works but is drifting; the advisory text is still printed)
- `2` — one or more errors (environment is broken for `pyve run` / `pyve test`)

Safe for CI use.

### `check --fix` — self-healing

Check detects; `--fix` repairs. The fault classes it consumes are exactly the runnability verdicts, resolution findings, and orphan contradictions documented above — `pyve check --fix` runs the same diagnostics, then detects broken **Pyve-managed state** and repairs it. It is plan-then-confirm: the detected faults and intended repairs are always printed first, and nothing is repaired without assent (`--yes`, or an interactive confirmation). Two tiers:

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
- [Environments](../environments.md) — the per-env rebuild verb (`pyve env init <name> --force`) and deliberately-isolated test envs
- [Testing](../testing.md) — the silent-skip advisory and its declarative `isolated = true` opt-out
- [CI/CD Integration](../ci-cd.md) — using the exit-code contract in pipelines
- [Usage Guide](../usage.md) — command overview, universal flags, and the Environment Variables table (`PYVE_NO_NETWORK`)
