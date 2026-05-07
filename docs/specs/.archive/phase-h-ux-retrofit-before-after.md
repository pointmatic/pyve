<!--
Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
SPDX-License-Identifier: Apache-2.0
-->

# H.f unified-UX retrofit: before/after captures

Text captures of top-level pyve command output pre- and post-H.f. All captures taken under `NO_COLOR=1` for readability in this markdown file; the colored variants are visually identical aside from ANSI wrappers on the `╭`/`╰` header/footer frame (cyan + bold), the glyphs (`✔` green, `✘` red, `▸` cyan, `⚠` yellow), and `banner` titles (blue + bold).

The **before** captures reproduce the output produced by the last commit before Story H.f.1 (`0c1fbd1` on 2026-04-19). The **after** captures are from the H.f.5 release wrap (v2.0.1, 2026-04-20).

---

## 1. `pyve init --backend foo` — invalid backend

### Before (v2.0.0, pre-H.f)

```
ERROR: Invalid backend: foo
ERROR: Valid backends: venv, micromamba, auto
```

### After (v2.0.1, post-H.f)

```
  ╭─────────────────────────────────────────╮
  │  pyve init                              │
  ╰─────────────────────────────────────────╯
  ✘ Invalid backend: foo
  ✘ Valid backends: venv, micromamba, auto
```

Header frames the invocation. Error glyphs match the unified palette. Stderr routing preserved.

---

## 2. `pyve init --force` — user answers "n"

### Before (v2.0.0)

```
WARNING: Force re-initialization: This will purge the existing environment
WARNING:   Current backend: venv

  Purge:   existing venv environment
  Rebuild: fresh venv environment

Proceed? [y/N]: n
INFO: Cancelled — no changes made, existing environment preserved
```

### After (v2.0.1)

```
  ╭─────────────────────────────────────────╮
  │  pyve init                              │
  ╰─────────────────────────────────────────╯
  ⚠ Force re-initialization: this will purge the existing environment (venv)
  ▸ Purge:   existing venv environment
  ▸ Rebuild: fresh venv environment

  ▸ Cancelled — no changes made, existing environment preserved
```

The destructive prompt now fires through `ask_yn` (prompt text suppressed by bash's `read -rp` under piped stdin, but visible interactively). Five lines of duplicated WARNING/INFO prefix collapse into one warn + two info.

---

## 3. `pyve purge --yes` — full-sweep cleanup

### Before (v2.0.0)

```
Purging Python environment artifacts...
✓ Removed .tool-versions
✗ No virtual environment found at '.venv'  (emitted as log_info)
✗ No dev/test runner environment found at '.pyve/testenv'  (log_info)
✓ Removed .envrc

✓ Python environment artifacts removed.
```

### After (v2.0.1)

```
  ╭─────────────────────────────────────────╮
  │  pyve purge                             │
  ╰─────────────────────────────────────────╯
  ✔ Removed .tool-versions
  ▸ No virtual environment found at '.venv'
  ▸ No dev/test runner environment found at '.pyve/testenv'
  ✔ Removed .envrc
  ╭─────────────────────────────────────────╮
  │  ✔ All done.                            │
  ╰─────────────────────────────────────────╯
```

Header + rounded footer on a successful run. `✔` (success) and `▸` (info) now disambiguate "did something" from "nothing to do" at a glance.

Also new in v2.0.1: `--yes` / `-y` skips the destructive-confirmation prompt. Internal callers (e.g., `pyve init --force`, interactive option 2) pass this automatically to avoid double-prompting.

---

## 4. `pyve testenv purge` — clean dir (nothing to remove)

### Before (v2.0.0)

```
INFO: No dev/test runner environment found at '.pyve/testenv'
```

### After (v2.0.1)

```
  ╭─────────────────────────────────────────╮
  │  pyve testenv                           │
  ╰─────────────────────────────────────────╯
  ▸ No dev/test runner environment found at '.pyve/testenv'
  ╭─────────────────────────────────────────╮
  │  ✔ All done.                            │
  ╰─────────────────────────────────────────╯
```

`pyve testenv run <cmd>` deliberately does **not** get the wrapper — it `exec`s into the target command, so a footer would never close. All other testenv actions (`init`/`install`/`purge`) wrap cleanly.

---

## 5. `pyve python set badversion` — validation failure

### Before (v2.0.0)

```
ERROR: Invalid Python version format 'badversion'. Expected format: #.#.# (e.g., 3.13.7)
```

### After (v2.0.1)

```
  ╭─────────────────────────────────────────╮
  │  pyve python set                        │
  ╰─────────────────────────────────────────╯
  ✘ Invalid Python version format 'badversion'. Expected format: #.#.# (e.g., 3.13.7)
```

Header fires before `validate_python_version` so the user sees command context even on a rejected input.

`pyve python show` intentionally stays unwrapped — read-only commands match the `git status` / `gitbetter status` convention of quiet machine-friendly output.

---

## Policy decisions made during H.f

- **Pip / micromamba subprocess output: full pass-through.** `run_cmd`'s dimmed `$ cmd args…` echo is the only pyve-owned line around a subprocess invocation. The subprocess's own progress bars and error output stay visible both at the dev console and in CI logs. Documented in `docs/specs/features.md` FR-17 and `docs/specs/tech-spec.md` UI Helper Policy.
- **Read-only commands stay quiet.** No `header_box`/`footer_box` wrapper around `pyve python show` or other machine-parseable output.
- **`log_*` helpers upgraded in place.** Rather than rewrite ~257 call sites one at a time, H.f.4 upgraded `log_info` / `log_warning` / `log_error` / `log_success` in `lib/utils.sh` to emit the unified glyphs. All existing callers adopt the new style automatically; exit semantics for `log_error` preserved (no forced `exit 1`).

## No `lib/ui.sh` additions during H.f

H.f.1 – H.f.4 consumed the palette already shipped in H.e.1 (`header_box`, `footer_box`, `banner`, `info`, `success`, `warn`, `fail`, `confirm`, `ask_yn`, `divider`, `run_cmd`). Nothing new to backport to the sibling `gitbetter` project from this phase.
