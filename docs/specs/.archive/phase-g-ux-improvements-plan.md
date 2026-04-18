# Phase G Plan — UX Improvements (remaining work)

> Phase plan for the remaining items in Phase G. Story G.a (`pyve testenv run`, v1.10.0) is already shipped and `concept.md` has been drafted. This document covers the three remaining bullets: project-guide integration, CLI subcommand refactor, and `usage.md` corrections.

## Phase Summary

| Field | Value |
|---|---|
| **Phase** | G — UX Improvements |
| **Phase goal** | Modernize Pyve's developer-facing surface: subcommand-style CLI, opinionated `project-guide` integration, and accurate landing-page documentation. |
| **Drives** | Pyve's "calm the chaos" promise. The flag-based CLI is a footgun for users coming from modern tools (`git`, `cargo`, `kubectl`, `gh`); `project-guide` is now the developer's standard project bootstrap and should be wired in by default; `usage.md` has drifted behind `--help` and is misleading new users. |
| **Backwards compatibility** | **None.** Clean break. The old `--init`/`--purge`/`--install`/`--uninstall`/`--validate`/`--python-version` flag forms are removed, not deprecated. |
| **Target version range** | v1.11.0 → v1.13.0 (one minor per code story) |

---

## Gap Analysis

### What exists today
- **CLI parsing**: `pyve.sh` dispatches commands as a mix of long flags (`--init`, `--purge`, `--validate`, `--install`, `--uninstall`, `--python-version`) and bare subcommands (`run`, `lock`, `doctor`, `test`, `testenv`). Modifier flags (`--backend`, `--force`, `--no-direnv`, etc.) attach to `--init`. Argument parsing lives in the top-level `case` block around [pyve.sh:2179](pyve.sh#L2179) and a second pre-pass around [pyve.sh:1189](pyve.sh#L1189).
- **`pyve init` flow**: After environment creation, `prompt_install_pip_dependencies()` ([lib/utils.sh](lib/utils.sh)) optionally installs pip deps. There is no equivalent integration point for any other tooling.
- **`usage.md`**: Lives at [docs/site/usage.md](docs/site/usage.md). Documents an older snapshot of the CLI — incorrect `--python-version` description, missing `testenv` subcommand entirely, missing several `--init`/`--purge` modifier flags, missing positional `<dir>` argument.
- **`pyve --help`**: Authoritative source for the CLI surface today (already updated in v1.10.0 for `testenv run`).

### What's missing
- A subcommand-style CLI consistent with modern developer tooling.
- A first-class hook to install `project-guide` during `pyve init` (interactive prompt + flags + env vars).
- Documentation in `usage.md` that matches `--help` and the new subcommand layout.

### What stays the same
- All library modules (`lib/*.sh`) — only the **dispatcher** in `pyve.sh` changes; per-command logic is untouched.
- All FR-* numbered functional requirements in `features.md` — **the *behavior* of init/purge/validate/etc. is unchanged**, only their invocation syntax.
- `pyve run`, `pyve lock`, `pyve doctor`, `pyve test`, `pyve testenv` — already subcommands, no rename.
- Universal flags: `--help` / `-h`, `--version` / `-v`, `--config` / `-c` remain as flags (CLI convention).

---

## Feature Requirements (mini features.md)

### FR-G1: Subcommand-Style CLI

Replace flag-style top-level commands with subcommands. The new surface:

| Old (removed) | New |
|---|---|
| `pyve --init [dir]` | `pyve init [dir]` |
| `pyve --purge [dir]` | `pyve purge [dir]` |
| `pyve --validate` | `pyve validate` |
| `pyve --python-version <ver>` | `pyve python-version <ver>` |
| `pyve --install` | `pyve self install` |
| `pyve --uninstall` | `pyve self uninstall` |

Unchanged: `pyve run`, `pyve lock`, `pyve doctor`, `pyve test`, `pyve testenv [...]`, `pyve --help`, `pyve --version`, `pyve --config`.

- Modifier flags (`--backend`, `--force`, `--update`, `--no-direnv`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--no-lock`, `--allow-synced-dir`, `--env-name`, `--local-env`, `--keep-testenv`) keep their names and continue to attach to their respective subcommands.
- **Short flag aliases dropped**: `-i`, `-p` etc. are removed. Subcommands are already short; users who want fewer keystrokes can write a shell alias.
- **Help reorganization**: `pyve --help` regrouped into categories: *Environment*, *Execution*, *Diagnostics*, *Self management*. Each subcommand's help string is reviewed for consistency.
- **Error on legacy flags**: Invoking `pyve --init` (or any other removed flag form) prints a clear error pointing to the new form, e.g.:
  ```
  ERROR: 'pyve --init' is no longer supported. Use 'pyve init' instead.
  See: pyve --help
  ```
  This is a one-line catch in the dispatcher; no compat shim, no silent translation. **Why deliberate**: silent translation hides the rename from users and builds long-term tech debt; an explicit error is one keystroke to fix and zero confusion.

### FR-G2: `project-guide` Integration in `pyve init`

Add an opinionated, opt-out hook to install [`project-guide`](https://pointmatic.github.io/project-guide/) during `pyve init`.

**Install target — the project environment.** `project-guide` is installed via `pip install project-guide` into whichever environment `pyve init` just created, regardless of backend:

| Backend | Install command |
|---|---|
| `venv` | `<venv>/bin/pip install project-guide` |
| `micromamba` | `micromamba run -p <prefix> pip install project-guide` |

This matches Pyve's "self-contained microcosm" philosophy: no dependence on global pipx, no dependence on the user's system Python, and the resulting `.project-guide.yml` + `docs/project-guide/` artifacts get committed alongside `.pyve/config` so a fresh clone on another machine reproduces the same setup. This is the same install pathway already used by `prompt_install_pip_dependencies()` ([lib/utils.sh](lib/utils.sh)) for `pyproject.toml` / `requirements.txt` deps.

**When the hook runs.** After environment creation and after the existing pip-deps prompt, as the final step of `pyve init` before the success summary.

**Trigger logic** (in priority order):

| Input | Behavior |
|---|---|
| `--no-project-guide` flag | Skip install, no prompt |
| `--project-guide` flag | Install, no prompt |
| `PYVE_NO_PROJECT_GUIDE=1` env var | Skip install, no prompt |
| `PYVE_PROJECT_GUIDE=1` env var | Install, no prompt |
| Non-interactive (`CI=1` or `PYVE_FORCE_YES=1`) | Install (default — see CI Mode note below) |
| Interactive (default) | Prompt: `Install project-guide? (Y/n) [Y]` |

`--project-guide` and `--no-project-guide` are mutually exclusive; using both is a hard error.

**CI Mode default = install.** When Pyve runs non-interactively (no human at the keyboard), it picks the same default a developer would pick by hitting Enter at the prompt. Since the interactive default is **Y**, the CI default is also **install**. This makes local-vs-CI behavior identical and gives reproducible artifacts everywhere. Override with `PYVE_NO_PROJECT_GUIDE=1` for CI jobs that don't want the project-guide files.

**Idempotency.** If `project-guide` is already importable from the project env's Python, the hook is a no-op success — it does not re-run `pip install`.

**Failure handling.** A failed `pip install project-guide` **does not fail `pyve init`** — it logs a warning with the underlying pip stderr and a "skip with `--no-project-guide`" hint, then continues. Pyve's job is environment setup; project-guide is a value-add.

**Sub-feature: shell completion wiring.** After `project-guide` is successfully installed, Pyve also offers to add the shell completion eval line to the user's shell rc file (`~/.zshrc` or `~/.bashrc`). This is **user-global**, not per-project — done once and survives.

- **Why not direnv `.envrc`?** direnv only propagates *environment variables* from a bash subprocess into the parent shell. Shell completions are internal builtin state (`compdef`/`_comps` in zsh, `complete` in bash), not env vars, and have to live in the user's interactive shell config to take effect.
- **Inserted block** is bracketed by sentinel comments (`# >>> project-guide completion (added by pyve) >>>` / `# <<< project-guide completion <<<`) for safe idempotent insertion and removal. The block uses a `command -v` guard so it's a no-op when `project-guide` isn't on PATH.
- **Trigger logic** mirrors the install flow but with a deliberate asymmetry: `--project-guide-completion` / `--no-project-guide-completion` flags, `PYVE_PROJECT_GUIDE_COMPLETION` / `PYVE_NO_PROJECT_GUIDE_COMPLETION` env vars, prompt-with-default-Y interactively. **CI mode defaults to *skip*, not install** — modifying user rc files in unattended environments is the kind of surprise Pyve avoids.
- **Removal**: `pyve self uninstall` removes the completion block from both `~/.zshrc` and `~/.bashrc`, mirroring how it removes the `~/.local/bin` PATH entry today.
- **Failure is non-fatal**: unknown shell (fish, etc.), unwritable rc file, etc. → warn with manual setup hint, continue.

### FR-G3: `usage.md` Corrections

Bring [docs/site/usage.md](docs/site/usage.md) in line with `pyve --help` after the FR-G1 refactor lands. Specific gaps from `ux-improvements.md`:

- **Fix**: `python-version` description (currently says "Display Python version" — it sets it).
- **Add**: `testenv` subcommand reference (currently entirely missing): `--init`, `--install [-r]`, `--purge`, `run <command>`.
- **Add to `init`**: `--local-env`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--env-name`, `--no-direnv`, `--project-guide`, `--no-project-guide`, optional `<dir>` positional, `--allow-synced-dir`, `--no-lock`.
- **Add to `purge`**: optional `<dir>` positional, `--keep-testenv`.
- **Replace** all flag-form examples (`pyve --init`) with subcommand form (`pyve init`).
- **Add** a "Migration from flag-style CLI" callout near the top for users coming from <1.11.

### FR-G4 (recommended addition): Subcommand Help Plumbing

While we're touching the dispatcher, add `pyve <subcommand> --help` for every subcommand (some already have it, some don't). Each subcommand's `--help` should print a focused man-page-style block, and `pyve --help` should be the index. **Why**: discoverability — users today have to scroll one giant `--help` and grep mentally.

---

## Technical Changes (mini tech-spec.md)

### Files modified

| File | Change |
|---|---|
| [pyve.sh](pyve.sh) | Rewrite top-level argument dispatcher. Replace flag-form `case` arms with subcommand arms. Add `self` namespace dispatcher. Add legacy-flag error catch. Add `--project-guide` / `--no-project-guide` flag parsing inside `init_command()`. Reorganize `print_help()`. Bump `VERSION`. |
| [lib/utils.sh](lib/utils.sh) | Add `prompt_install_project_guide()` (mirrors `prompt_install_pip_dependencies()` shape). Add `install_project_guide()` helper that detects whether `project-guide` is already installed and shells out to `pip install project-guide` (target TBD — see open question Q2). |
| [docs/site/usage.md](docs/site/usage.md) | Full rewrite of command reference section against new subcommand surface; add `testenv`, `project-guide` flags, missing `init`/`purge` options, fix `python-version` description, add migration callout. |
| [docs/specs/features.md](docs/specs/features.md) | Update the **Inputs > Required** section: remove `--init`/`--purge`/`--validate`/`--install`/`--uninstall`/`--python-version` from the flag list and add the new subcommand list. Update FR-1 / FR-2 / FR-3 / FR-7 invocation syntax. Add new FR-16: `project-guide` integration. |
| [docs/specs/tech-spec.md](docs/specs/tech-spec.md) | Update **CLI Design > Commands** table to reflect the subcommand surface and `self` namespace. Document new helper functions in `lib/utils.sh`. |
| [README.md](README.md) | Update front-matter examples from flag-form to subcommand form. |
| [CHANGELOG.md](CHANGELOG.md) | Three entries (one per code story). |

### Files NOT modified

- All `lib/*.sh` modules other than `utils.sh`. Backend detection, micromamba lifecycle, env detection, version tracking, distutils shim — all unchanged.
- All `tests/unit/*.bats` modules. Their target functions are unchanged.

### New helper functions (in `lib/utils.sh`)

| Function | Signature | Purpose |
|---|---|---|
| `prompt_install_project_guide` | `()` → 0/1 | Y/n prompt with default Y; honors `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` / `CI` / `PYVE_FORCE_YES` |
| `install_project_guide` | `(backend, env_path)` → 0/1 | Run `pip install project-guide` against the project env. For `venv`, calls `<env_path>/bin/pip`. For `micromamba`, calls `micromamba run -p <env_path> pip`. Idempotent (no-op if already installed). Warn (don't fail) on error. |
| `is_project_guide_installed` | `(backend, env_path)` → 0/1 | Detect whether `project-guide` is importable from the env's Python |

### Test changes

- **Bats** unit tests for the dispatcher: a new `tests/unit/test_cli_dispatch.bats` exercising:
  - Each new subcommand resolves to the right handler
  - `pyve self install` / `pyve self uninstall` route correctly
  - Legacy flags (`pyve --init`) print the expected error and exit non-zero
  - Mutually exclusive `--project-guide` / `--no-project-guide` errors
- **pytest** integration tests:
  - `tests/integration/test_subcommand_cli.py` — black-box invocation of every renamed subcommand against a temp project
  - `tests/integration/test_project_guide_integration.py` — verify install / no-install / env var paths
  - Update existing integration tests that invoke `pyve --init` etc. to use `pyve init` (mechanical sweep)

### Documentation site coverage check

After `usage.md` is updated, do a one-time grep across `docs/site/` for any remaining `pyve --init` / `pyve --purge` / `pyve --validate` / `pyve --install` / `pyve --uninstall` / `pyve --python-version` strings and fix them.

---

## Out of Scope (deferred)

- **Bash/Zsh completion scripts** for the new subcommand layout. Worth doing, but a separate phase — touches different code paths and benefits from being designed against a stable subcommand surface.
- **`pyve self update`** — self-updating via `git pull` or homebrew formula refresh. Compelling but orthogonal to UX cleanup; defer to a future "self-management" phase.
- **Color/Unicode polish in `--help` output** — not blocking the refactor.
- **Restructuring `pyve.sh` into smaller files** — pyve.sh is large but the refactor is intentionally minimally invasive: only the dispatcher changes.
- **Telemetry / opt-in usage metrics** — out of scope (and arguably anti-Pyve).
- **`pyve doctor` reporting whether project-guide is installed** — nice future addition once the integration ships.

---

## Design Decisions (resolved)

### D1: Short-flag aliases for top-level subcommands → **Dropped**
No `-i`, `-p`, etc. for top-level subcommands. Subcommands are already short; users who want fewer keystrokes can write a shell alias. Keeps the CLI surface minimal and discoverable.

### D2: `project-guide` install target → **Project environment, via `pip`**
`project-guide` is installed via `pip install project-guide` into whichever environment `pyve init` just created — `<venv>/bin/pip` for the `venv` backend, `micromamba run -p <prefix> pip` for the `micromamba` backend. Pyve's "self-contained microcosm" philosophy: no global pipx, no system Python dependence. The resulting `.project-guide.yml` and `docs/project-guide/` artifacts get committed alongside `.pyve/config`, so a fresh clone reproduces the same setup on any machine or container.

### D3: Legacy-flag error catch lifetime → **Forever**
Three lines of code, great error message, zero cost. Users coming from old README snippets, blog posts, or LLM training data will hit it for years and get a precise hint instead of a confusing "unknown option" error.

### D4: `pyve self` with no subcommand → **Show namespace help only**
Mirrors `git remote`, `git stash`, `kubectl config`. `pyve self` prints just the `self install | uninstall` summary, not the full help.

---

## Story Breakdown (preview — to be written into `stories.md` after plan approval)

Three code stories + one doc story, in a deliberate order so each builds cleanly on the previous:

1. **G.b — v1.11.0: CLI subcommand refactor (FR-G1, FR-G4)**
   First because every other story builds on the new dispatcher. No new behavior — pure rename + restructure + legacy-flag error + per-subcommand `--help`. Ships as a minor bump because it's a breaking surface change (justified by "no backwards compat needed").

2. **G.c — v1.12.0: `project-guide` integration in `pyve init` (FR-G2)**
   Adds the prompt, flags, env vars, and installer helper. Slots cleanly into the new `init` subcommand from G.b. Resolves Q2 before implementation.

3. **G.d — v1.13.0: `usage.md` overhaul + spec sync (FR-G3)**
   Rewrite the landing-page command reference against the now-stable surface from G.b + G.c. Sweep `docs/site/` for legacy flag references. Sync `features.md` + `tech-spec.md` text that wasn't already updated by G.b/G.c.

   *(Whether this story gets a version bump is a judgment call — it's pure docs, so per `stories.md` convention it could be unversioned. My recommendation: bump anyway because `usage.md` is published to the docs site and shipping it under a version makes the rollout legible.)*

A spike story is **not** needed — there are no new integration boundaries. `project-guide` is already a known PyPI tool that the developer uses daily.

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Integration tests across the repo invoke `pyve --init` everywhere; mass-rename could miss a path. | Do a grep sweep as part of G.b's test step; CI will catch any miss because the legacy-flag error catch will exit non-zero. |
| `project-guide` install fails on a user's machine and they blame Pyve. | Failure is non-fatal: warn and continue. Error message includes the underlying `pip install` stderr and a "skip with `--no-project-guide`" hint. |
| Users with shell aliases / scripts that wrap `pyve --init`. | Out-of-scope to fix their scripts, but the legacy-flag error message tells them exactly what to change. |
| Doc-site rebuild lags behind the release. | G.d ships `usage.md` and includes a CI check (already exists?) that the docs build. |
