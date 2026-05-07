<!--
This file captures must-know facts future LLMs need to avoid blunders when
working on this project. Entries use `###` subsections (never `##`) because
the rendered `go.md` wrapper provides the `## Project Essentials` heading.
Do NOT include a top-level `#` title.

New entries are appended (not reordered) by plan_phase at the end of each
phase. Refactoring or reorganizing this file is refactor_plan's job, not
plan_phase's.
-->

### File header conventions

Every new source file must begin with a copyright notice and license
identifier. Use the comment syntax for the file type:

| File type | Comment syntax |
|-----------|---------------|
| Python, YAML, shell, Makefile | `#` |
| JavaScript, TypeScript, Go, Java, C/C++ | `//` or `/* */` |
| HTML, Svelte, XML | `<!-- -->` |
| CSS, SCSS | `/* */` |

**This project's header:**

- **Copyright**: `Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)`
- **SPDX identifier**: `SPDX-License-Identifier: Apache-2.0`

Bash example (leading shebang preserved):
```bash
#!/usr/bin/env bash
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
```

Python example:
```python
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
```

### Deprecation removal policy — Category A vs Category B

When removing or renaming a CLI command or flag, prefer the **Category B** pattern (immediate hard-error with a named replacement) over the **Category A** pattern (silent delegation with a stderr warning).

- **Category A** = delegation-with-warning. Old form still runs by re-dispatching to the new form, plus a one-shot `delegation_warn` stderr message. Examples shipped in Phase H: `pyve testenv --init|--install|--purge`, `pyve python-version <ver>`. **Removed in Phase J** because the alias-mapping + re-dispatch + tests are non-trivial maintenance for behavior that hides the rename from users.
- **Category B** = hard-error catch via `legacy_flag_error()` in `pyve.sh`. Three lines per catch: match the old form in the dispatcher, print a precise "use X instead" message, exit non-zero. Examples kept indefinitely: `--init`, `--purge`, `--validate`, `--update`, `--doctor`, `--status`, `doctor` / `validate` subcommands.

**Why:** Category B costs ~3 lines and zero ongoing maintenance, but pays off every time a user (or LLM) invokes an old form from stale docs / blog posts / training data — they get a precise migration hint instead of "unknown command." Category A's cost (delegation logic + warning + tests) is real, and its only benefit (the old form keeps working) actively hides the rename from the user.

**How to apply:** When deprecating a CLI surface in a future phase, write the Category B catch from day one. Skip the Category A delegation step entirely. Don't resurrect Category A even if "users need a migration window" — the migration window is achieved by the precise error message, not by the old form continuing to silently work.

### `is_asdf_active()` is the single gate for asdf-aware behavior

Any code branch that needs to behave differently when asdf is the version manager **must** call `is_asdf_active()` (in `lib/env_detect.sh`) — never inline `[[ "$VERSION_MANAGER" == "asdf" ]]`.

**Why:** `is_asdf_active()` encapsulates two conditions: (1) asdf is detected as `$VERSION_MANAGER`, and (2) the user hasn't set `PYVE_NO_ASDF_COMPAT=1` to opt out. Inline checks bypass the opt-out and cause user-facing behavior to drift from the documented contract. Phase J introduced this helper alongside the asdf reshim guard in `.envrc` and `pyve run`; future asdf-aware features (e.g. diagnostics in `pyve check`, additional bootstrap heuristics) should reuse it.

**How to apply:** Before adding any `if asdf-is-active` branch, grep for `is_asdf_active`. If it doesn't exist or you find yourself tempted to write the inline check "just this once," update the helper instead — opt-out semantics need to live in one place.

### `lib/commands/<name>.sh` is for command implementations only

Files under `lib/commands/` own one top-level command apiece (`init`, `purge`, `update`, `check`, `status`, `lock`, `run`, `test`, `testenv`, `python`, `self`) plus that command's private helpers. Anything called from two or more commands belongs in `lib/<topic>.sh` (`lib/utils.sh`, `lib/env_detect.sh`, `lib/backend_detect.sh`, etc.) — not in a command file.

**Why:** A helper dropped into `lib/commands/init.sh` because "init uses it" works on day 1 but creates a hidden cross-file coupling once a second command needs it — by then untangling means a search-and-replace plus a sourcing-order audit. The whole point of the per-command split is isolation; sharing across command files defeats it. Command-private helpers carry the `_<command>_` prefix (`_init_write_envrc`, `_check_run_diagnostics`) as a visible reminder that they belong to that command alone.

**How to apply:** Before adding a function inside `lib/commands/<name>.sh`, grep for callers. If any other `lib/commands/*.sh` file calls it, move it to the appropriate `lib/<topic>.sh` and drop the `_<command>_` prefix. If it's truly command-private, give it the prefix.

### Library sourcing in `pyve.sh` is explicit, not glob-based

`pyve.sh` lists each `source lib/foo.sh` and `source lib/commands/<name>.sh` on its own line. Never collapse this to `for f in lib/commands/*.sh; do source "$f"; done` or any equivalent glob.

**Why:** Glob-based sourcing depends on filesystem `readdir` order, which differs across macOS / Linux / case-insensitive HFS+ / case-sensitive APFS / network mounts. The day a command file references a constant defined at source-time in another command file, the order matters and the bug surfaces non-deterministically across machines. Explicit listing surfaces ordering bugs at code-review time and makes the dependency chain auditable in one place.

**How to apply:** When adding a new file under `lib/` or `lib/commands/`, add an explicit `source` line in `pyve.sh`'s sourcing block at the appropriate position (helpers before commands; commands in alphabetical order unless dependency forces otherwise). Even if the list grows long, do not replace it with a glob.

### Per-command help blocks live with their commands

Each per-command help function (`show_<cmd>_help` / `show_<cmd>_<sub>_help`) lives in the matching `lib/commands/<cmd>.sh` file alongside the command's implementation, NOT in `pyve.sh`. The three top-level help blocks (`show_help`, `show_version`, `show_config`) describe the CLI as a whole and stay in `pyve.sh`.

**Why:** help text is tightly coupled to the command it documents. Co-location puts the maintenance burden in the right place: when a command grows a flag, the help block update lands in the same diff. The dispatcher in `pyve.sh` calls the help functions by name; bash resolves them via the global function table at call time, so the file location is invisible from the dispatcher's POV.

**How to apply:** when adding a new top-level command, put its `show_<cmd>_help` function inside `lib/commands/<cmd>.sh` (not in `pyve.sh`). When adding a sub-command to a namespace, put its `show_<cmd>_<sub>_help` function inside the same `lib/commands/<cmd>.sh` namespace file (mirroring the leaf-function convention).

### Namespace commands are single files: dispatcher + leaves together

The three namespace commands (`testenv`, `python`, `self`) live in one file each (`lib/commands/testenv.sh`, `lib/commands/python.sh`, `lib/commands/self.sh`). Each file contains the namespace dispatcher AND every leaf function (`testenv_init`, `testenv_install`, `testenv_purge`, `testenv_run`, etc.).

**Why:** "One file per command" sounds like a clean rule, but applied to namespace leaves it would mean separate files for `testenv_init`, `testenv_install`, etc. — which forces the top-level dispatcher in `pyve.sh` to know about every leaf, defeats per-namespace cohesion, and proliferates near-empty files. The intentional rule is one file per **top-level command name registered in `pyve.sh`'s case dispatcher**; sub-namespace leaves share their namespace's file.

**How to apply:** When adding a new sub-command to a namespace (e.g., a hypothetical `testenv freeze`), add a `testenv_freeze()` function inside `lib/commands/testenv.sh` and a new arm in that file's namespace dispatcher. Do not create `lib/commands/testenv_freeze.sh`. Only the top-level namespace itself appears in `pyve.sh`'s case block.

### Uniform `.envrc` template — all backends share one activation shape

Every backend's `.envrc` is emitted by `write_envrc_template` in `lib/utils.sh` and conforms to the same four-line shape: a single `PATH_add "<rel_bin_dir>"`, one `export <BACKEND_SENTINEL>="$PWD/<rel_env_root>"` (`VIRTUAL_ENV` for venv / pip-derived backends, `CONDA_PREFIX` for micromamba / conda-like), plus `export PYVE_BACKEND`, `export PYVE_ENV_NAME`, and `export PYVE_PROMPT_PREFIX`. Hand-rolled `export PATH="$ENV_PATH/bin:$PATH"` in an `.envrc` is forbidden.

**Why:** `PATH_add` is direnv's canonical primitive for "add a directory to PATH, accept it may be relative to `.envrc`, export the absolute form." Hand-rolled `export PATH=` with a relative entry keeps that entry relative on PATH — which resolves against the caller's cwd, so `command -v project-guide` in a rc-file completion guard fails whenever the shell starts outside the project directory. This is the v2.3.2 bug and the whole reason the uniform template exists.

**How to apply:** When adding a new backend (uv, poetry, conda, etc.), do **not** write a new `init_direnv_<backend>` that emits its own template. Add a wrapper like `init_direnv_venv` that calls `write_envrc_template "<rel_bin_dir>" "<sentinel_var>" "<rel_env_root>" "<backend_name>" "<env_name>"` and nothing else. Callers pass paths relative to the project root; the helper handles `$PWD`-prefixing and the asdf compat guard.

### Function naming convention — `<verb>_<operand>` aligned with the CLI

Top-level command functions in `lib/commands/<name>.sh` are named `<verb>_<operand>` where the operand describes what the verb operates on, taken from the position immediately after the verb in the user's CLI invocation. Whether the operand is explicit (named sub-command) or implicit (unnamed args, or no args at all), the function name uses a stable noun for that position.

**Direct commands** (no namespace; user types `pyve <verb> [operand-args]`):

| CLI | Operand | Function | Notes |
|---|---|---|---|
| `pyve init [<dir>]` | the project | `init_project()` | Implicit operand: this project |
| `pyve purge [<dir>]` | the project | `purge_project()` | Implicit operand: this project |
| `pyve update` | the project | `update_project()` | Refreshes `.pyve/config`, `.gitignore`, `.vscode/settings.json`, project-guide — all project-level |
| `pyve check` | the environment | `check_environment()` | Diagnoses venv/python/.envrc health |
| `pyve status` | (status itself is the noun) | `show_status()` | `status` is a noun, not a verb — semantic alignment trumps spelling alignment here; `..._project` / `..._environment` suffixes are supportive but not mandatory |
| `pyve lock` | dependencies | `lock_environment()` | Locks the environment's dependency graph (`environment.yml` → `conda-lock.yml`) |
| `pyve run <cmd>` | a command | `run_command()` | Operand is what the user types as the next CLI token |
| `pyve test [args]` | tests | `test_tests()` | Args explicitly select tests; no args runs all tests; either way the operand is "tests" |

**Namespace dispatchers** (user types `pyve <namespace> <sub-command>`):

For namespace dispatchers the operand is the *sub-command name* itself, so the convention `<namespace>_command` reads correctly: `pyve <namespace> <command-name>` → `<namespace>_command()`.

| CLI | Function |
|---|---|
| `pyve python <sub>` | `python_command()` |
| `pyve self <sub>` | `self_command()` |
| `pyve testenv <sub>` | `testenv_command()` |

**Namespace leaves** (the actual handler reached after a namespace dispatch):

Leaves use `<namespace>_<leaf>` where `<leaf>` is the literal sub-command name from the CLI.

| CLI | Function |
|---|---|
| `pyve python set` / `pyve python show` | `python_set()` / `python_show()` |
| `pyve self install` / `pyve self uninstall` | `self_install()` / `self_uninstall()` |
| `pyve testenv {init\|install\|purge\|run}` | `testenv_init()` / `testenv_install()` / `testenv_purge()` / `testenv_run()` |

**Why:** the rule keeps the function name and the CLI form in 1:1 correspondence, so any reader can derive the function name from the user-facing command and vice versa without consulting a table. It also naturally avoids the F-11 binary/builtin shadow trap (`python`, `test`) — the operand suffix lifts every name into a non-colliding namespace. The earlier "rename to clean name" recommendations in K.a.3 (e.g. `run_lock` → `lock`, `self_command` → `self`) were rolled back because they violated this rule, were inconsistent with each other, and exposed F-11 traps for future maintainers who don't notice the collision.

**How to apply:**

- When extracting a new direct command, name the function `<verb>_<operand>` where `<operand>` is the noun describing what the command operates on. If the operand is absent or genuinely an action-with-no-noun (`status` is the canonical example), prefer the semantically clearest name (`show_status()`) — alignment with the CLI is the goal, not literal spelling.
- When extracting a namespace, the dispatcher is `<namespace>_command()` and the leaves are `<namespace>_<sub-command>()`. Both are easy to derive.
- Command-private helpers (only called from inside one command's file) keep the `_<command>_` prefix per the existing project-essentials F: `_init_<helper>`, `_check_<helper>`, etc.
- For shared helpers (called by ≥2 commands), the convention does not apply — they live in `lib/<topic>.sh` and use whatever name fits the helper's responsibility.

### Function-name collision rule — never shadow a binary or builtin we use

When naming a top-level command function in `lib/commands/<name>.sh`, the function name must not collide with (a) an external binary that pyve invokes internally, or (b) a bash builtin/keyword. Bash function names take precedence over external commands and most builtins, so a collision silently shadows the original — with the failure surfacing only when that command path runs in CI.

**Concrete forbidden names (Phase K):**

- `python` — pyve invokes `python` directly during venv creation (`python -m venv .venv`, `python -c 'import sys; ...'`). The dispatcher function for `pyve python <sub>` MUST stay named `python_command`, not `python`.
- `test` — bash builtin (and legacy `/usr/bin/test`). Even though pyve currently uses `[[ ... ]]` exclusively, renaming `test_command` → `test` would shadow the builtin and create a footgun for any future contributor adding `test -f foo` or `if test ...` style checks. Stay with `test_command`.

**Safe (verified in K.b–K.e):**

- `lock`, `self`, `self_install`, `self_uninstall`, `run_command` — none are external binaries we invoke or bash builtins. The K.c (`run_lock` → `lock`) and K.e (`install_self` → `self_install`, etc.) renames stand.

**Why:** caught the hard way in K.d. The initial `python_command` → `python` rename passed every Bats unit test (725+) but broke `pyve init --backend venv` end-to-end (CI integration tests) because the function shadowed the binary at the venv-creation step. The unit tests didn't catch it because they invoke `pyve` as a subprocess (`bash pyve.sh ...`), not from inside an already-loaded function table. Lesson: name-collision regressions hide from any test that doesn't exercise the full `pyve init` flow.

**How to apply:** before renaming a command function in any future Phase K story (or any later refactor), grep for the proposed new name as a bare command in pyve.sh + lib/: `grep -nE '(\$\(|\`|^|\s|;|\|\|?)<name>\s' pyve.sh lib/*.sh lib/commands/*.sh`. If any non-comment line is found, do **not** rename — keep the `_command` suffix (or some other non-colliding form). The dispatcher arm calling `<name>_command` is fine; only the function name itself is the hazard.

### Cross-repo coordination with `project-guide` — request, don't work around

When pyve-side code interacts with `project-guide` (the sibling project at <https://pointmatic.github.io/project-guide/>) and the cleanest fix for a rough edge is upstream of pyve — e.g. `project-guide` is too chatty during a `pyve init` hook and the right answer is a `--quiet` flag in `project-guide` rather than output-suppression in pyve — write a focused change-request spec at `docs/specs/project-guide-requests/<short-name>.md` and ship the change in the `project-guide` repo. The pyve-side story that consumes the new behavior carries an explicit minimum-version dependency on `project-guide` (e.g. "requires project-guide ≥ vX.Y.Z").

Each spec is self-contained: problem statement, proposed change, motivation, suggested CLI/API shape, compatibility notes — droppable into the `project-guide` repo's planning workflow without further translation.

**Why:** working around an upstream rough edge in pyve adds permanent maintenance burden for a temporary problem and hides the issue from `project-guide`'s own maintainers (who may be the same person, but on a different release cadence). A targeted upstream fix removes the rough edge for all consumers, including any future tools built on top of `project-guide`.

**How to apply:** when you find a `project-guide`-integration rough edge (Phase L's Track-2 audit is the canonical example), decide locus first — pyve-side fix or upstream change request. For pyve-side fixes, normal pyve story workflow. For upstream, write the spec under `docs/specs/project-guide-requests/` (create the directory first if it doesn't exist yet), then ship the change in the `project-guide` repo on its own release cycle. The pyve-side L.* (or M.*, N.*, …) story that consumes the change waits until the corresponding `project-guide` release is available, then lands the consumption with a min-version guard if necessary.

### `lib/ui/` is the extractable UX boundary — pyve-agnostic with one exception

Modules under `lib/ui/` (`core.sh`, `run.sh`, `progress.sh`, `select.sh`, and any future siblings) must stay pyve-agnostic so the directory remains lift-and-shift extractable into a standalone bash UX library. Concretely: no pyve paths (`.pyve/`, `.venv/`), no pyve command names (`pyve init`, `pyve testenv`), no pyve config keys, no `PYVE_*`-prefixed identifiers — with one Phase-L-sanctioned exception: `PYVE_VERBOSE` may appear in `lib/ui/core.sh` because it is the single source-of-truth env var for the verbosity gate consumed by every UI primitive.

The verbosity check itself is centralized: every primitive that varies on verbose state calls the helper `is_verbose()` (defined in `lib/ui/core.sh` as `[[ "${PYVE_VERBOSE:-0}" == "1" ]]`) rather than inlining the env-var check. `--verbose` (parsed pre-subcommand in `pyve.sh`'s `main()`) and `PYVE_VERBOSE=1` are equivalent surfaces.

**Why:** the lib/ui/ layer was carved out in Phase L (story L.e) as the core of an eventually-extractable "calm CLI UX" library. Slipping pyve-specifics into a primitive ties the extraction roadmap to a future migration, and re-implementing the env-var check elsewhere creates drift the next time the gate's semantics shift (e.g. adding a `--super-verbose`, a `PYVE_QUIET` opt-out, or a verbosity tri-state). Centralizing it in `is_verbose()` means the gate's contract has exactly one place to evolve.

**How to apply:** when adding a new primitive under `lib/ui/`, the boundary-invariant bats tests (e.g. [tests/unit/test_ui_run.bats](../../tests/unit/test_ui_run.bats)) grep for forbidden tokens and fail the build on regressions — extend that test for any new module. When adding behavior that depends on verbose state, call `is_verbose()` from inside the primitive; never re-check `$PYVE_VERBOSE` directly. When evolving the gate (e.g. adding a new verbosity level), update only `is_verbose()` and its callers.

### Bash 3.2 empty-array reads must use the `:-` default

When reading an array with `"${arr[*]}"` or `"${arr[@]}"`, **always** provide a `:-` default if the array might be empty: `"${arr[*]:-}"`, `"${arr[@]:-}"`. Bash 3.2 (the macOS system bash, still the bash on every Apple-silicon and Intel Mac) treats reads of an empty array as **unbound variable** under `set -u` (which `pyve.sh` enables via `set -euo pipefail`), even though modern bash 4.4+ silently returns the empty string. The bug is invisible on dev macOS when the array happens to have entries from your installed tooling (asdf, pyenv, …) and surfaces only on the CI runner where the array is genuinely empty.

**Why:** caught the hard way in Story L.k.7. `_init_detect_version_managers_available` in `lib/commands/init.sh` returned `printf '%s' "${available[*]}"` — fine on dev (asdf installed → array non-empty), CI-fatal (no managers → empty array → `lib/commands/init.sh: line N: available[*]: unbound variable` → `pipefail` killed the whole `pyve init` mid-wizard, before `validate_backend` even ran). Tests sourcing init.sh into bats's shell didn't catch it because bats doesn't re-enable `set -u`; the bug only fires inside `pyve.sh`'s subprocess.

**How to apply:**

- Default form is `"${arr[*]:-}"` / `"${arr[@]:-}"` whenever the array could be empty — and unless you control every code path leading to the read, assume it could.
- The few cases where you've just appended to the array on the line above (e.g. `arr+=("foo"); printf '%s' "${arr[*]}"`) can skip the `:-` because the read is guaranteed-non-empty by construction. Most callsites are not in that shape.
- The regression test pattern is: source the helper from a fresh `/bin/bash -c "set -euo pipefail; ..."` shell with PATH cleaned, exercise the empty-array path, assert no `unbound variable` in stderr. See [tests/unit/test_init_wizard.bats](../../tests/unit/test_init_wizard.bats) "no 'unbound variable' under 'set -u'" for the canonical shape.

### `.project-guide.yml` is the canonical project-guide install marker

When pyve needs to detect "is project-guide installed in this project?", check **`.project-guide.yml`** in the project root — not the `docs/project-guide/` directory. The YAML file is project-guide's own state record (`installed_version`, `target_dir`, `current_mode`, `pyve_version`, etc.) and is the source-of-truth signal upstream `project-guide` writes on init / update. The `docs/project-guide/` directory is configurable via the YAML's `target_dir` field, so its presence at the default path is neither necessary nor sufficient.

Two consumers today:

- [lib/commands/update.sh:123](../../lib/commands/update.sh#L123) — `pyve update` refreshes project-guide artifacts only when `.project-guide.yml` is present.
- [lib/commands/init.sh](../../lib/commands/init.sh) — the wizard's project-guide prompt (Story L.k.5) renders "refresh (already installed)" iff `.project-guide.yml` is present, then defers to the post-env hook for the actual update.

**Why:** picking the directory as the signal looked simpler at first but creates two failure modes: (1) the directory exists for unrelated reasons (the user's own `docs/project-guide.md` file inside a vendored docs structure, an empty placeholder dir, etc.); (2) the user has relocated project-guide artifacts via `target_dir`, so the directory at the default path doesn't exist while project-guide is in fact installed and active.

**How to apply:** when adding a new pyve consumer that needs to know whether project-guide is installed, key off `[[ -f ".project-guide.yml" ]]`. Do not add a parallel `[[ -d "docs/project-guide" ]]` check. If you need the artifact directory's actual path, parse `target_dir` from `.project-guide.yml` (basic YAML: a plain `key: value` line), don't assume the default.
