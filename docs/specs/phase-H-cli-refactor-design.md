# Phase H Design — CLI Surface Refactor

**Status:** Draft for approval (Story H.d, 2026-04-18)
**Scope:** Define the v2.0 subcommand / flag surface — one obvious command per intent, consistent grammar between top-level and nested subcommands, no silent flag collisions. Design-only; implementation lives in Story H.e.
**Companion:** Story H.c (`pyve check` / `pyve status` design). Overlaps on the `pyve update` decision (H.c C3). This document is the final authority on that decision.

---

## 1. Observed friction in v1.x

Drawn from the story inventory and v1.x CHANGELOG:

1. **Flag vs. subcommand overlap for reinit/update.** `pyve init --force`, `pyve init --update`, `pyve purge`, `pyve purge --keep-testenv` cover overlapping territory. `--update` is a narrow config-version bump despite the broad-sounding name.
2. **No non-destructive upgrade path.** Upgrading pyve (brew) + bumping `.pyve/config` + refreshing `project-guide` + rewriting managed files requires `brew upgrade pyve` followed by `pyve init --force`, which destroys the venv.
3. **Silent flag collisions.** `pyve init --backend venv --purge` fails with a generic error ("--purge" is not an `init` flag — the user meant `--force`). No closest-match hint, no listing of valid flags.
4. **Two grammars for the same verbs.** Top-level uses subcommands (`pyve init`, `pyve purge`); `testenv` uses flags (`pyve testenv --init`, `pyve testenv --purge`). Inconsistent.
5. **`python-version` is hyphenated** while other subcommands are single words (`init`, `purge`, `lock`, `run`, `test`).
6. **`validate` and `doctor` overlap** — H.c addresses the semantic split; this document integrates the resulting `check` / `status` subcommands into the top-level surface.

---

## 2. Current surface inventory (v1.14.2)

### 2.1 Top-level subcommands

| Subcommand | Purpose | Notes |
|---|---|---|
| `init [<dir>]` | Initialize environment | Rich flag set (see §2.3) |
| `purge [<dir>]` | Remove artifacts | `--keep-testenv` flag |
| `python-version <ver>` | Set Python version only | Hyphenated outlier |
| `lock [--check]` | Generate/verify `conda-lock.yml` | micromamba-only |
| `run <command>` | Run command in env | |
| `test [pytest args]` | Run pytest via testenv | |
| `testenv <action>` | Manage testenv | Uses flag-style actions (see §2.2) |
| `doctor` | Health diagnostics | → becomes `check` per H.c |
| `validate` | CI pass/fail gate | → becomes `check` per H.c |
| `self install` / `self uninstall` | Manage pyve binary | Nested subcommand — already correct grammar |

### 2.2 `testenv` sub-surface (to be normalized)

Today: `pyve testenv --init`, `pyve testenv --install [-r <req>]`, `pyve testenv --purge`, `pyve testenv run <cmd>`. The `--init` / `--install` / `--purge` are flags masquerading as subcommands.

### 2.3 `init` flag inventory

| Flag | Kind | Replaceable? |
|---|---|---|
| `--python-version <ver>` | Common | Keep |
| `--backend <type>` | Common | Keep |
| `--auto-bootstrap` / `--bootstrap-to <where>` | micromamba | Keep |
| `--strict` / `--no-lock` | micromamba | Keep |
| `--env-name <name>` | micromamba | Keep |
| `--no-direnv` | Common | Keep |
| `--auto-install-deps` / `--no-install-deps` | Common | Keep |
| `--local-env` | Common | Keep |
| `--update` | Modal — conflicts with `--force` | **Remove** (promoted to `pyve update` subcommand per §4.1) |
| `--force` | Modal | Keep |
| `--allow-synced-dir` | Common | Keep |
| `--project-guide` / `--no-project-guide` | project-guide | Keep |
| `--project-guide-completion` / `--no-project-guide-completion` | project-guide | Keep |

### 2.4 Legacy-flag catch (kept forever — Decision D3 from v1.11.0)

Currently catches: `--init`, `--purge`, `--validate`, `--python-version`, `--install`, `--uninstall`, `-i`, `-p`. Pattern stays; list extends (§6).

---

## 3. Design goals (recap)

1. **One obvious command per intent.** No user should need to decide between `--update` and `update`.
2. **Consistent grammar.** If `pyve init` is a subcommand, `pyve testenv init` is too — not `testenv --init`.
3. **Non-destructive upgrade path.** Refresh managed files + `project-guide` without destroying the venv.
4. **Helpful errors.** Unknown flag on a subcommand surfaces "did you mean X?" and the valid flag list.
5. **Backward compatibility window.** No user's muscle memory breaks silently — every rename either delegates or emits a migration error pointing at the new form.

---

## 4. The v2.0 subcommand surface

### 4.1 Top-level subcommands

| v1.x | v2.0 | Status | Notes |
|---|---|---|---|
| `init [<dir>]` | `init [<dir>]` | Unchanged | Minus the `--update` flag (§4.2) |
| `purge [<dir>]` | `purge [<dir>]` | Unchanged | |
| `python-version <ver>` | `python <ver>` (or `python set <ver>`) | **Renamed** | See Decision D1 below |
| `lock [--check]` | `lock [--check]` | Unchanged | |
| `run <cmd>` | `run <cmd>` | Unchanged | |
| `test [args]` | `test [args]` | Unchanged | |
| `testenv --init` / `--install` / `--purge` / `run` | `testenv init` / `install` / `purge` / `run` | **Normalized** | Flags become nested subcommands |
| `doctor` | `check` | **Renamed** (per H.c) | `doctor` still works in v2.0 via delegate-with-warning |
| `validate` | `check` | **Replaced** (per H.c) | `validate` still works in v2.0 via delegate-with-warning |
| (none) | `status` | **New** (per H.c) | Read-only state dashboard |
| (none) | `update` | **New** | Non-destructive upgrade path — resolves Decision C3 from H.c |
| `self install` / `self uninstall` | `self install` / `self uninstall` | Unchanged | Already correct grammar |

### 4.2 Decision D1 — `python-version` rename

Three options:

- **(a) Keep as `python-version`** — only inconsistency in the top-level surface. Minimum churn.
- **(b) Rename to `python <ver>`** — single word, matches `init`, `purge`, `lock`. But `python` is also the name of the underlying tool, so `pyve python` is ambiguous: does it mean "the Python interpreter under pyve management" or "pyve's python-version command"?
- **(c) Promote to `pyve python set <ver>`** (nested). Disambiguates by adding an action verb; leaves room for `pyve python show` (read the pinned version), `pyve python list` (installed versions), etc.

**Recommendation: (c) `pyve python set <version>` / `pyve python show`.** Reasons:
- Grammar consistent with `pyve self install` / `pyve self uninstall`.
- Disambiguation of the `python` namespace via required action verb.
- Leaves room for `pyve python list` / `pyve python available` later without another rename.
- `python-version` stays in the legacy-flag catch list forever.

Deprecation: v2.0 ships `python-version <ver>` as a delegate-with-warning (maps to `python set <ver>`). Removed in v3.0.

### 4.3 `pyve update` subcommand (ratifies H.c Decision C3)

**Ratified.** `pyve update` is the non-destructive upgrade path.

**Semantics:**

```
pyve update [--no-project-guide]
```

Behavior:
1. Read `.pyve/config` and determine current `pyve_version`.
2. Rewrite `.pyve/config` with the running `VERSION` as `pyve_version`.
3. Refresh the Pyve-managed sections of `.gitignore` (via `write_gitignore_template`, already idempotent).
4. Refresh `.vscode/settings.json` (only if file exists — never create on update).
5. Refresh `.pyve/` layout (bootstrap scaffolding if missing — e.g., testenv paths).
6. Refresh `project-guide` scaffolding via `project-guide update --no-input` (unless `--no-project-guide` or auto-skip condition applies — same gate as `pyve init --force` in v1.14.0).

**Non-behavior (spec-level):**
- **Never** rebuilds the venv. Use `pyve init --force` for that.
- **Never** creates a `.env` or `.envrc` that doesn't exist. Those are user state.
- **Never** re-prompts for backend. The backend recorded in `.pyve/config` is preserved.
- **Never** prompts. `pyve update` is intended for CI and for one-command upgrades — all gating is via flags / env vars that already exist for `pyve init` (`PYVE_NO_PROJECT_GUIDE`, etc.).

**Exit codes:**
- `0` on success (including no-op when already at current version).
- `1` on failure (unwritable config, corrupt YAML, etc.).

**Relationship to `pyve init --force`:**
- `init --force` = destroy + rebuild (venv + all managed files).
- `update` = refresh managed files only; preserve venv and user state.

**Relationship to the removed `init --update` flag:**
- v1.x `init --update` bumped `pyve_version` only. v2.0 `update` does that PLUS refreshes managed files + project-guide. Broadened as recommended in H.c.

### 4.4 `testenv` normalization

| v1.x | v2.0 |
|---|---|
| `pyve testenv --init` | `pyve testenv init` |
| `pyve testenv --install [-r <req>]` | `pyve testenv install [-r <req>]` |
| `pyve testenv --purge` | `pyve testenv purge` |
| `pyve testenv run <cmd>` | `pyve testenv run <cmd>` (unchanged) |

Old flag forms emit a **deprecation warning** (not an error) and delegate. This preserves script compatibility while nudging users toward the new grammar. Removed in v3.0.

### 4.5 Error-message improvements (Decision D2)

**Unknown-flag-for-subcommand error.** When `pyve init --purge` (or any mistyped flag) is encountered:

```
ERROR: 'pyve init' does not accept '--purge'.
  Did you mean: '--force'?
  Valid flags for 'pyve init': --python-version, --backend, --force, ...
  See: pyve init --help
```

Implementation approach (for H.e):
- Every subcommand handler keeps a canonical flag list (literal array at the top of the function).
- On unknown flag, the dispatcher runs a Levenshtein-like proximity check (bash-only, no external tools) across the canonical list and picks the single closest match.
- Suggestion threshold: only show "did you mean X?" when edit distance ≤ 3.

---

## 5. Deprecation plan (Decision D3)

**Coordinated single window for all renames in H.e:**

| Rename | v2.0 behavior | v3.0 behavior |
|---|---|---|
| `doctor` → `check` | Delegate; print `pyve doctor: renamed to 'pyve check'. Running 'pyve check'...` once. Exit code matches. | Legacy-flag error. |
| `validate` → `check` | Delegate; same warning pattern. Exit code matches. | Legacy-flag error. |
| `python-version` → `python set` | Delegate; same warning pattern. | Legacy-flag error. |
| `testenv --init` / `--install` / `--purge` → `testenv init` / `install` / `purge` | **Deprecation warning**, not error — delegate. | Legacy-flag error. |
| `init --update` → `pyve update` | **Legacy-flag error** (not delegate). Rationale below. | Legacy-flag error (unchanged). |

**Why `init --update` is a hard error in v2.0, not a delegate:**

The new `pyve update` has broader semantics than the old `--update` flag (refreshes managed files + `project-guide`, not just `pyve_version`). Silently delegating would surprise users who scripted `pyve init --update` expecting the narrow behavior. A hard error forces the migration to be deliberate.

**Why everything else is delegate-with-warning:**

`doctor`, `validate`, `python-version`, and the `testenv` flags have the same semantics after the rename. Silent delegation preserves green CI builds while the warning text steers users toward the new form. One release cycle (v2.0 → v3.0) gives enough migration window.

**Deprecation output guardrails:**
- Warnings write to stderr (never stdout — scripts parsing stdout stay clean).
- Warnings print once per invocation (not once per call — a CI script calling `pyve doctor` in a loop shouldn't flood logs).
- Warnings include the exact replacement command, not a `--help` reference.

---

## 6. Legacy-flag catch extensions

The existing `legacy_flag_error` list ([pyve.sh:2620-2631](../../pyve.sh#L2620-L2631)) grows by:

```
--update                → "init --update is no longer supported. Use 'pyve update' instead."
--doctor                → "'pyve --doctor' is no longer supported. Use 'pyve check' instead."
--status                → "'pyve --status' is no longer supported. Use 'pyve status' instead."
```

(The `--doctor` / `--status` entries guard against users who pre-emptively tried the flag form after reading the v2.0 CHANGELOG.)

---

## 7. Backend preference preservation

Today, `pyve init --force` re-prompts for backend unless `--backend` is passed (see [pyve.sh:1173](../../pyve.sh#L1173) region). For H.e:

- **`pyve update`:** Reads `.pyve/config`'s `backend:` field. Never prompts. Never changes it.
- **`pyve init --force`:** Current behavior preserved — re-prompts unless `--backend` is passed. If the config has a recorded backend, pre-select it as the default in the prompt.

No change needed for `pyve init` (fresh init with no config). Remains "auto-detect from files, fall back to prompt".

---

## 8. Migration matrix (user-facing)

| Old command | New command | v2.0 behavior |
|---|---|---|
| `pyve doctor` | `pyve check` | Works; prints rename warning |
| `pyve validate` | `pyve check` | Works; prints rename warning |
| `pyve init --update` | `pyve update` | **Hard error** with migration message |
| `pyve python-version 3.13.7` | `pyve python set 3.13.7` | Works; prints rename warning |
| `pyve testenv --init` | `pyve testenv init` | Works; prints deprecation warning |
| `pyve testenv --install` | `pyve testenv install` | Works; prints deprecation warning |
| `pyve testenv --purge` | `pyve testenv purge` | Works; prints deprecation warning |

---

## 9. Out of scope (deferred to Phase I or beyond)

1. **Remove deprecated flags** — Phase I / v3.0. Captured as "Future Story I.?: Remove Deprecated Flags Introduced as Warnings in H.e" in `stories.md`.
2. **`pyve check --fix`** — Phase I. (From H.c C2.)
3. **`pyve status --json`** — deferred; no concrete ask. (From H.c C6.)
4. **`pyve python list` / `pyve python available`** — deferred; only `set` / `show` in v2.0.
5. **Interactive wizards** — out of scope. v2.0 stays strictly non-interactive-by-default for CI ergonomics.
6. **Rich / curses UI** — not happening. ANSI only (consistent with Story H.f scope).

---

## 10. Open questions / non-decisions

1. **Should `pyve check` run as part of `pyve update`?** Tempting — "do the safe refresh and verify everything's still OK". But `check` has a non-zero exit code for warnings (C1), which would make `pyve update` non-zero whenever the project has any warning. Current call: **no**, keep them separate. User can chain `pyve update && pyve check`.
2. **Short-form subcommand aliases.** v1.11.0 removed `-i` / `-p`. No plans to reintroduce; users who want shortcuts should shell-alias.
3. **Machine-readable status output.** §9 defers `--json` to a future story. If approved, `pyve status --json` AND `pyve check --json` both ship together to keep the contract consistent.

---

## 11. Summary of decisions (for approval)

| ID | Decision | Resolution |
|---|---|---|
| D1 | `python-version` rename | **`pyve python set <ver>` / `pyve python show`** (nested subcommand with action verb) |
| D2 | Unknown-flag errors | Closest-match suggestion + valid-flag list + help pointer |
| D3 | Deprecation window | Single coordinated window: v2.0 delegates-with-warning (or hard error for `init --update`); v3.0 hard-removes |
| D4 (ratifies H.c C3) | `pyve update` subcommand | **Implemented** — broadened semantics: config bump + managed-files refresh + project-guide refresh, never touches the venv |
| D5 | `testenv` grammar | Flags (`--init`/`--install`/`--purge`) → nested subcommands (`init`/`install`/`purge`); flag forms delegate-with-warning in v2.0 |
| D6 | `pyve update` prompting | Never prompts. All gating via flags / env vars that already exist for `init` |
| D7 | `pyve update` vs `init --force` boundary | `update` refreshes managed state; `init --force` destroys + rebuilds venv. Spec-level invariant — no overlap. |

---

## 12. Impact on Story H.e

H.e's sub-story list (currently placeholder in `stories.md`) now concretizes:

1. **Port `lib/ui.sh`** (unchanged — first sub-story, already defined).
2. **Implement `pyve update` subcommand** (new).
3. **Implement `pyve check`** (from H.c).
4. **Implement `pyve status`** (from H.c).
5. **Normalize `testenv --init|--install|--purge` → `testenv init|install|purge`** with delegation.
6. **Rename `pyve python-version` → `pyve python set`** with delegation.
7. **Add closest-match unknown-flag errors** (D2).
8. **Add deprecation warnings** for every renamed flag/subcommand (D3, D5).
9. **Extend legacy-flag catch** (§6) for `--update`, `--doctor`, `--status`.
10. **Update shell completion** (`lib/completion/*`) for the new surface.
11. **Update tests** for every changed command + new commands.

Each of these is a candidate for splitting into its own sub-story as H.e kicks off.
