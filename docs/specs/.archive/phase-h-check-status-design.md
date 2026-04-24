# Phase H Design — `pyve check` and `pyve status`

**Status:** Draft for approval (Story H.c, 2026-04-17)
**Scope:** Replace `pyve doctor` and `pyve validate` with two complementary commands for the v2.0 release. Design-only; implementation lives in Story H.e.
**Companion design:** Story H.d (CLI surface refactor). Where the two designs touch — most notably the `--update` flag semantics — H.d is the final authority; this document records the H.c position.

---

## 1. Rationale

`pyve doctor` and `pyve validate` overlap in scope. A user in v1.13.2 running `pyve doctor` against a stale project sees:

```
% pyve doctor
WARNING: Run 'pyve validate' to check compatibility    ← bounces to validate

% pyve validate
⚠ Pyve version: 0.9.9 (current: 1.13.2)
  Migration recommended. Run 'pyve init --update' to update.  ← second action
✗ Virtual environment: .venv (missing)
  Run 'pyve init' to create.                                  ← third action
```

Three different commands are referenced before the user reaches a working state. The goal for v2.0 is **one obvious command per intent, one actionable recommendation per problem**:

| Intent | v1.x command | v2.0 command |
|---|---|---|
| "Is anything broken? How do I fix it?" | `pyve doctor` (mostly) + `pyve validate` (for CI) | `pyve check` |
| "What is the current state of this project?" | scattered — partially `pyve doctor`, partially `pyve --config` | `pyve status` |

---

## 2. Command boundary

The semantic contract is enforced by the `--help` text of each command (section 8 drafts both). Violations of this boundary in the implementation are bugs.

| Property | `pyve check` | `pyve status` |
|---|---|---|
| Purpose | Diagnostic + remediation guidance | State dashboard |
| Output | Findings + one actionable command per finding | Observed facts only |
| Exit codes | `0` pass, `1` errors, `2` warnings only | `0` always (non-zero only on internal error) |
| CI use | Yes — gate on exit code | No — informational |
| Side effects | None (read-only) | None (read-only) |
| `--fix` flag | **Not in v2.0** (deferred — see §4.4) | N/A |

**Rule of thumb:** if the answer to "why is the user running this?" is _"something looks wrong"_, it goes in `check`. If the answer is _"I need to remember how this project is set up"_, it goes in `status`.

---

## 3. `pyve check` — design

### 3.1 Purpose

Run a fixed set of diagnostics against the current project. Every failure yields **one actionable command** — no chains ("run X, then Y"), no cross-references ("run `pyve validate`"), no read-and-decide prose.

### 3.2 Exit codes (Decision C1)

Keep `pyve validate`'s 0/1/2 semantics — CI pipelines already rely on this model, and per-category exit codes add complexity without a real use case surfacing in v1.x.

| Code | Meaning |
|---|---|
| `0` | All checks passed. |
| `1` | At least one **error** — the environment is broken for normal `pyve run` / `pyve test` usage. |
| `2` | At least one **warning** — environment works but is drifting (version mismatch, stale lock, missing `.env`). Never downgrades an error. |

Escalation follows the existing `_escalate()` helper in [lib/version.sh:177](../../lib/version.sh#L177) — warnings never overwrite errors.

### 3.3 Diagnostic surface

Every check is one of four severity levels: **pass** (`✓`), **info** (no symbol, one-line fact), **warn** (`⚠`), **error** (`✗`). Only `warn` and `error` affect the exit code.

Checks run in the order below. The command stops iterating after 20 findings (guardrail for pathological projects) and prints a footer summary (`3 errors, 2 warnings, 11 passed`).

| # | Check | Severity on failure | Actionable command on failure |
|---|---|---|---|
| 1 | `.pyve/config` present and parseable | error | `pyve init` |
| 2 | `pyve_version` in config vs. current `VERSION` | warn (drift) | `pyve update` (H.d subcommand) |
| 3 | Backend configured (`backend:` in `.pyve/config`) | error | `pyve init --backend venv\|micromamba` |
| 4 | Backend implementation available (micromamba binary exists when `backend: micromamba`) | error | `pyve init` (triggers bootstrap) |
| 5 | Environment path exists and has `bin/python` | error | `pyve init --force` |
| 6 | Python version in environment matches `.python-version` / `.tool-versions` / config | warn | `pyve init --force` |
| 7 | Venv path mismatch (relocated project) — venv `pyvenv.cfg` command line points elsewhere | error | `pyve init --force` |
| 8 | `distutils_shim.sh` installed for Python 3.12+ venv (only on 3.12+) | warn | `pyve init --force` |
| 9 | `.envrc` present when direnv is installed | warn | `direnv allow` |
| 10 | `.env` present | warn | `touch .env` |
| 11 | `conda-lock.yml` present (micromamba only) | warn | `pyve lock` |
| 12 | `conda-lock.yml` stale — `environment.yml` newer (micromamba only) | warn | `pyve lock` |
| 13 | Duplicate `dist-info` in site-packages (cloud-sync corruption) | error | `pyve init --force` |
| 14 | Cloud sync collision artifacts (`* 2` files) | error | `pyve init --force` (plus: move project out of synced dir) |
| 15 | Native library conflict (pip bundler + conda linker, missing shared lib) | warn | edit `environment.yml` + `pyve lock` |
| 16 | testenv exists, has `bin/python`, has `pytest` (if the project uses `pyve test`) | warn | `pyve test` (triggers testenv init) |

**Design notes on the table:**

- **Check 4** assumes bootstrap is implemented per Stories H.g–H.m. Until then, the message is `install micromamba: see docs/site/migration.md#micromamba`.
- **Check 6** uses the same Python-version source-of-truth logic that `pyve init` uses today (`lib/env_detect.sh`'s `detect_version_manager` + `.tool-versions`/`.python-version`).
- **Check 8** only runs when the active Python is 3.12+. The shim status is already inspectable via `sitecustomize.py` probe — reuse the existing probe from [lib/distutils_shim.sh](../../lib/distutils_shim.sh).
- **Checks 13–15** already exist as helpers in `lib/utils.sh` (`doctor_check_duplicate_dist_info`, `doctor_check_collision_artifacts`, `doctor_check_native_lib_conflicts`). Rename to `check_*` in H.e.
- **Check 16** is conditionally run — if `.pyve/testenv` does not exist, we do not warn ("testenv missing" is not a problem unless the user tries to use it; `pyve test` bootstraps on demand).

### 3.4 `--fix` auto-remediation (Decision C2)

**Out of scope for v2.0.** Deferred to a Phase I story (already tracked in `stories.md` under "Future — Story I.?: Auto-Remediation").

Rationale:
- `pyve init --force` is already the fix for ~half the checks. Wrapping it in `--fix` adds plumbing without reducing user effort.
- Some fixes are irreversible (`direnv allow` touches `.envrc.allow`); we want real usage data on `check` before deciding which fixes to automate.
- Shipping `check` without `--fix` in v2.0 keeps the breaking-change surface small.

### 3.5 `--update` flag semantics (Decision C3)

Referenced by both `doctor` and `validate` today (`Run 'pyve init --update' to update`). Options:

- **(a) Rename to `--config-only`** on `pyve init` — narrow: just bump `pyve_version` in `.pyve/config`. Status quo, just renamed for clarity.
- **(b) Broaden into a proper `pyve update` subcommand** — non-destructive upgrade: bump config version, refresh managed files (`.gitignore`, `.vscode/settings.json`), refresh `project-guide` scaffolding. Leaves the venv intact.

**Recommendation: (b).** Reason: the user is almost never asking for "just bump the config version" — they want the whole managed surface refreshed. A dedicated `pyve update` subcommand is discoverable, has a clear semantics boundary vs. `pyve init --force` (destroy + rebuild), and eliminates the ambiguous `--update` flag entirely.

This decision **must be confirmed by Story H.d** (CLI surface refactor). H.d is the final authority on subcommand boundaries; if H.d picks (a), this document's text for Check 2 above ("`pyve update`") becomes "`pyve init --config-only`".

### 3.6 Non-decisions / open questions

1. **Should `check` re-verify `.pyve/config` YAML schema (every key valid)?** Current thinking: no — that's what `pyve update` should enforce at write time. `check` only verifies presence + backend.
2. **Per-check output verbosity.** Default is one-line-per-check. A `--verbose` flag that expands every finding into "observed / expected / next-step" is tempting but not in this design; revisit after dogfooding.

---

## 4. `pyve status` — design

### 4.1 Purpose

At-a-glance "what is this project?" dashboard. Answers: which backend, which Python, where's the environment, is `project-guide` installed, does the testenv exist, what version of pyve wrote the config.

### 4.2 What it is NOT

- Not a health check (`check` does that).
- Not a remediation guide (no "Run X to fix Y" lines).
- Not actionable. Exit code is always `0` unless pyve itself errored (file read failed, config corrupt — in which case `status` prints what it can and exits `1`, but never for "the environment is broken").

### 4.3 Output format (Decision C4)

Sectioned single-screen layout (not compact). The user's eye should be able to find each piece of information in the same visual position on every run.

Target output (venv project):

```
Pyve project status
───────────────────

Project
  Path:           /Users/foo/Developer/bar
  Backend:        venv
  Pyve config:    v1.14.2 (current)
  Python:         3.14.4 (.tool-versions via asdf)

Environment
  Path:           .venv
  Python:         3.14.4
  Packages:       127 installed
  distutils shim: installed (Python 3.12+)

Integrations
  direnv:         .envrc present
  .env:           present
  project-guide:  installed (v2.4.1)
  testenv:        present, pytest installed

```

Target output (micromamba project):

```
Pyve project status
───────────────────

Project
  Path:           /Users/foo/Developer/baz
  Backend:        micromamba
  Pyve config:    v1.14.2 (current)
  Python:         3.12.10 (environment.yml)

Environment
  Name:           baz-env
  Path:           .pyve/envs/baz-env
  Packages:       203 installed
  environment.yml: present
  conda-lock.yml:  up to date

Integrations
  direnv:         .envrc present
  .env:           missing
  project-guide:  not installed
  testenv:        not present

```

The trailing blank line after each section is deliberate — spec-level, not a formatting accident.

### 4.4 Rendering

Implementation will use the `lib/ui.sh` helpers introduced in Story H.e's first sub-story. Specifically: the rounded-box `divider` / section banner for the `───────────────────` rule, `DIM` for label columns, `BOLD` for the top title. `NO_COLOR=1` strips escape codes without changing layout.

### 4.5 Section inventory

- **Project** — path, backend, config version, configured Python.
- **Environment** — path, Python, package count, plus backend-specific rows (distutils shim for venv; environment.yml + lock status for micromamba).
- **Integrations** — direnv, `.env`, `project-guide`, testenv.

Explicitly **not** surfaced:
- Test runner details beyond presence + pytest (don't duplicate `pyve test --verbose`).
- Cloud-sync / dist-info / native-lib issues — those are `check` territory.
- Micromamba binary path — `status` doesn't diagnose missing tools; `check` does.

### 4.6 Non-decisions

1. **`--json` flag.** Tempting for scripting. Deferred — wait for a concrete ask. Today nothing in pyve consumes its own output.
2. **Relative vs. absolute paths.** Output uses relative paths for directories inside the project (`.venv`, `.pyve/envs/...`) and absolute for the project root itself.

---

## 5. Mapping — old coverage to new commands

| Existing diagnostic (v1.x) | Source | New home | Notes |
|---|---|---|---|
| Pyve version compatibility | `doctor` + `validate` | `check` #2 + `status` "Pyve config" row | Both surfaces — `status` shows the state, `check` flags drift. |
| Backend detection | `doctor` | `check` #3–4 + `status` "Backend" row | Same. |
| Venv existence | both | `check` #5 + `status` "Environment Path" | Same. |
| Python executable in env | `doctor` | `check` #5 + `status` "Python" row | Same. |
| `.env` presence | both | `check` #10 + `status` "Integrations" | Same. |
| Micromamba binary/version | `doctor` | `check` #4 (binary only) + `status` omits version | Version belongs in `pyve --version` / `status`-at-install-level, not per-project. |
| Duplicate dist-info | `doctor` | `check` #13 | Keep — real bug-hunting value. |
| Cloud sync collision artifacts | `doctor` | `check` #14 | Keep. |
| Native lib conflicts | `doctor` | `check` #15 | Keep. |
| Venv path mismatch (relocated) | `doctor` | `check` #7 | Keep. |
| Test runner diagnostics | `doctor` | `check` #16 + `status` "testenv" row | Split: state in `status`, pytest-installed gate in `check`. |
| Package counts | `doctor` | `status` only | Informational; not a pass/fail signal. |
| Lock file staleness | `doctor` | `check` #11–12 + `status` lock row | Same. |
| `.pyve/config` structural validation | `validate` | `check` #1 | Same. |
| Structured exit codes for CI | `validate` | `check` §3.2 | Same semantics. |

**Dropped (not in either new command):**
- Version-manager string (asdf vs. pyenv) — was a "✓ Version file: .tool-versions (asdf)" info row. Redundant with the Python row.
- "Install source" (`brew` / `installed` / `source`) — belongs in `pyve --version`, not a project-level view.

**Gap — diagnostics not currently covered that probably should be:**
- **Active Python vs. configured Python mismatch** — `.tool-versions` says 3.12.10 but the venv's `bin/python` is 3.11.9 because the user manually rebuilt. Added as `check` #6.
- **distutils shim status on 3.12+** — today the shim is installed but never verified post-init. Added as `check` #8.

---

## 6. Deprecation plan

Coordinated with Story H.d (which decides the deprecation window for the entire flag/subcommand refactor). Current recommendation:

**At v2.0:**
- `pyve doctor` → emits `pyve doctor: renamed to 'pyve check'. Running 'pyve check' now...` and delegates. Exit code matches `check`.
- `pyve validate` → same pattern, delegates to `pyve check`. Exit code unchanged.
- `pyve init --update` → emits a legacy-flag error (per existing `legacy_flag_error` pattern in [pyve.sh:2620-2631](../../pyve.sh#L2620-L2631)) pointing at `pyve update` (assuming H.d picks C3b).

**At v3.0 (Phase I):**
- Remove the `doctor` / `validate` delegation; just emit the error.

Reason for the delegate-plus-warn approach over hard-break: `doctor` is commonly scripted into CI by users. A hard break at v2.0 turns every `pyve doctor` invocation into a red build with no grace period. The delegate path keeps builds green, surfaces the rename in the output, and gives users one release cycle to migrate.

---

## 7. Relationship to Story H.d

H.c decides **what `check` and `status` do**. H.d decides **how they fit into the overall CLI surface** — specifically:

- Whether `check` and `status` are top-level subcommands or nested (`pyve env check` / `pyve env status`). H.c assumes top-level; H.d can override.
- Whether `pyve update` exists as a subcommand (§3.5 C3 above). H.c's recommendation is (b); H.d ratifies.
- Deprecation window length across all renamed commands. H.c's recommendation is one minor release; H.d coordinates with the other renames.

Any H.d decision that conflicts with this document forces an edit here before H.e begins.

---

## 8. Draft `--help` text (user-facing contract)

### `pyve check --help`

```
pyve check - Diagnose environment problems and suggest fixes

Usage:
  pyve check

Description:
  Runs a set of read-only diagnostics against the current project and
  reports findings. Every failure includes exactly one command that
  will move the project toward a working state — no chains, no
  references to other commands.

  For a read-only snapshot of current state (no diagnostics), use
  'pyve status' instead.

Exit codes:
  0    All checks passed.
  1    One or more errors — environment is broken for 'pyve run' / 'pyve test'.
  2    Warnings only — environment works but is drifting.

Notes:
  - pyve check is safe to run in CI (no side effects, stable exit codes).
  - pyve check does not auto-remediate. For the auto-fix story, see the
    future 'pyve check --fix' (tracked in stories.md Phase I).

See also:
  pyve status            Read-only state dashboard
  pyve --help            Full command list
```

### `pyve status --help`

```
pyve status - Show a snapshot of the current project environment

Usage:
  pyve status

Description:
  Prints an at-a-glance summary of how this project is set up:
  backend, Python version, environment location, package count, and
  integration state (direnv, .env, project-guide, testenv).

  pyve status is read-only and never produces a non-zero exit code
  based on findings — if something looks wrong, use 'pyve check'.

See also:
  pyve check             Diagnose problems and suggest fixes
  pyve --help            Full command list
```

---

## 9. Summary of decisions (for approval)

| ID | Decision | Resolution |
|---|---|---|
| C1 | `pyve check` exit-code scheme | 0/1/2 (same as `validate`) |
| C2 | `pyve check --fix` in v2.0 | **No** — deferred to Phase I |
| C3 | `--update` flag semantics | Recommend **(b) new `pyve update` subcommand** — final call in H.d |
| C4 | `pyve status` output format | Sectioned single-screen (not compact); uses `lib/ui.sh` |
| C5 | Deprecation path for `doctor` / `validate` | Delegate-with-warning in v2.0; hard-remove in v3.0 |
| C6 | `pyve status --json` flag | Deferred; no concrete ask yet |
| C7 | New diagnostic coverage added | Active-vs-configured Python mismatch; distutils shim post-init status |
