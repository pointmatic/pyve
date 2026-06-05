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

**Documented exception — `pyve testenv *` (Story N.c, Phase N).** Phase N's CLI rename `testenv → env` reintroduces Category A delegation for the entire `pyve testenv <sub>` namespace: every invocation re-dispatches to `env_command` and emits one `deprecation_warn` per shell. The exception is justified because `pyve testenv` is high-traffic enough (LLM training data, blog posts, internal scripts) that a Category B hard error would block too many real workflows during the v3.x window. Hard-error replacement happens in v4.0 alongside the rest of the legacy surface. **Do not generalize this exception to other future renames** — the bar is "established enough that hard-error would meaningfully break the world," and most surfaces will not clear it.

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

Three consumers today:

- [lib/commands/update.sh:123](../../lib/commands/update.sh#L123) — `pyve update` refreshes project-guide artifacts only when `.project-guide.yml` is present.
- [lib/commands/init.sh](../../lib/commands/init.sh) — the wizard's project-guide prompt (Story L.k.5) renders "refresh (already installed)" iff `.project-guide.yml` is present, then defers to the post-env hook for the actual update.
- [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh) — `python_plugin_is_active_in_project` (Story N.aj, PC-4a) treats `.project-guide.yml` as a **Python-active signal**: project-guide is a Python package installed via `pip` into a venv-backed `root` `utility` env, so its presence means Python is legitimately part of the project (even a Node app), and the Python plugin's `check`/`status` must NOT be suppressed.

**`.project-guide.yml` is a load-bearing cross-repo dependency contract.** pyve keys real behavior off this exact filename, so a rename or shape change in upstream `project-guide` is a coordinated breaking change: the project-guide side of it must resolve the pyve contract (per the "Cross-repo coordination with project-guide" entry). Story N.ao formalizes the contract + rename protocol alongside the wizard project-guide-provisioning design.

**Why:** picking the directory as the signal looked simpler at first but creates two failure modes: (1) the directory exists for unrelated reasons (the user's own `docs/project-guide.md` file inside a vendored docs structure, an empty placeholder dir, etc.); (2) the user has relocated project-guide artifacts via `target_dir`, so the directory at the default path doesn't exist while project-guide is in fact installed and active.

**How to apply:** when adding a new pyve consumer that needs to know whether project-guide is installed, key off `[[ -f ".project-guide.yml" ]]`. Do not add a parallel `[[ -d "docs/project-guide" ]]` check. If you need the artifact directory's actual path, parse `target_dir` from `.project-guide.yml` (basic YAML: a plain `key: value` line), don't assume the default.

### `pyve.toml` is the canonical declaration; `.pyve/` holds state only

From v3.0 onward, every project's declaration lives at root-level `pyve.toml` (schema: `pyve_schema`, `[project]`, `[env.<name>]`). Everything under `.pyve/` is **materialized state** — environments, locks, sentinels, the `.v2-legacy/` backup tree — never configuration. The Python helper [`lib/pyve_toml_helper.py`](../../lib/pyve_toml_helper.py) is the only TOML reader; the Bash shim [`lib/manifest.sh`](../../lib/manifest.sh) exposes the parsed result through `manifest_load` + flat accessors (`manifest_get_purpose`, `manifest_resolve_purpose`, `manifest_get_backend`, etc.).

**Why:** the v2 model spread declaration across `.pyve/config` (YAML) and `[tool.pyve.testenvs.*]` (pyproject TOML). Two sources of truth was the root cause of every "but it works on my machine" bug in Phase M's testenv-DX bundle, and it forced consumers to keep two readers in sync. Consolidating onto one root-level file removes that whole class of failure and matches the Pyve visibility goal (root-level presence signals "this is a Pyve project" to humans and tools at a glance).

**How to apply:** when adding a new pyve consumer that needs a configuration value, route through `manifest_load` + an accessor. Do not parse `pyve.toml` directly. Do not introduce a new YAML / TOML / INI declaration file. If a value genuinely doesn't fit the `pyve.toml` schema (e.g., a per-user preference rather than per-project), it belongs in `~/.config/pyve/` or an env var — never under `.pyve/` (state) and never alongside `pyve.toml` (which is the schema-validated surface).

### `purpose:` vocabulary and the name-based default rule

Every `[env.<name>]` block carries a `purpose` attribute drawn from the closed set `{run, test, utility, temp}`. When `purpose` is omitted, the resolver [`manifest_resolve_purpose`](../../lib/manifest.sh) applies a name-based default: `testenv → test`, `root → utility`, everything else → `utility`. Explicit declaration always wins. The resolver is the **single** gate purpose-keyed selectors consult — `pyve test --env <name>` hard-errors when the resolved purpose is not `test`, and analogous gates ship in later subphases for `run` / `utility`.

**Why:** the v2 `testenvs` namespace overloaded "test environment" to mean "any env that isn't the main one" — utility envs (dev tooling, formatters) and ephemeral envs (one-shot tasks) all rode the same label. Phase N split them so each purpose can grow its own lifecycle (e.g., `temp` envs auto-prune; `utility` envs survive `pyve purge`). The name-based default keeps the common case (one main env + one test env) zero-config.

**How to apply:** when adding a new purpose-aware feature, call `manifest_resolve_purpose <name>` — never inline a `[[ "$name" == "testenv" ]]` check (that re-implements the default rule and silently drifts when the resolver changes). When introducing a fifth purpose value, the closed set in [`lib/pyve_toml_helper.py`'s](../../lib/pyve_toml_helper.py) `VALID_PURPOSES` is the canonical place; update accessors and gates from there.

### The v2 → v3 deprecation surface has exactly three layers

Phase N ships three coordinated surfaces for the v2 → v3 transition. Don't add a fourth ad-hoc nudge; don't conflate the layers.

1. **Deterministic migrator** — `pyve self migrate` ([`lib/commands/self.sh`](../../lib/commands/self.sh)). Writes `pyve.toml` from legacy sources, moves them into `.pyve/.v2-legacy/` for one release cycle, invokes `pyve init --force` to rebuild envs at the v3 state layout. Idempotent; `--dry-run` / `--no-rebuild` flags expose intermediate states.
2. **v3.0 soft banner** — pre-dispatch hook in [`pyve.sh`](../../pyve.sh)'s `main()` (`_pyve_maybe_show_v2_banner`). One-shot per `(PPID, cwd)` via a sentinel under `${XDG_STATE_HOME:-$HOME/.local/state}/pyve/`. Skips `--help` / `--version` / `--config` / `self` namespace. Suppressible via `PYVE_QUIET=1`.
3. **v3.1 hard interactive gate (Subphase N-10)** — replaces the soft banner with an interactive prompt that invokes `self_migrate()` on accept. Ships in `v3.1.0`. Removes the read-compat layer at the same time.

The v3.0 read-compat in [`lib/manifest.sh`](../../lib/manifest.sh) (`_manifest_synthesize_from_legacy`) is what lets users actually defer the migration during the v3.0 window — without it, the banner would only nag without the underlying command working.

**Why:** three layers cover three distinct user states — (a) ready to migrate (uses `self migrate`), (b) not yet migrated but using pyve every day (sees the banner once per shell, keeps working via read-compat), (c) holdout at v3.1 (forced to migrate via the hard gate). A fourth nudge inside any individual command (`pyve check`, `pyve status`, …) would either duplicate the banner's signal or fight its memoization.

**How to apply:** if a future change wants to surface a migration-related message, route it through the existing banner, not a new print site. If it's an error condition (`pyve self migrate` failed; user state is inconsistent), keep the error in the command that detected it — don't escalate to the banner. The `.pyve/.v2-legacy/` directory is the single deterministic backup location; no other rollback path is supported.

### `v3.0-only: remove in N-10` marker is the contract for the read-compat sweep

Every code path in [`lib/manifest.sh`](../../lib/manifest.sh) that exists solely to support v2-configured projects during the v3.0 window carries the literal comment `v3.0-only: remove in N-10`. The N-10 cleanup is mechanical: grep the marker, delete the matching helpers (and their callsites + tests), confirm `manifest_load` on a missing-pyve.toml project returns the empty-config baseline unconditionally. A bats test in [`tests/unit/test_n_i_read_compat.bats`](../../tests/unit/test_n_i_read_compat.bats) asserts the marker is grep-visible so accidental removal during unrelated refactors gets caught.

**Why:** the read-compat surface intentionally synthesizes a v3 shape from v2 sources (`.pyve/config` + `[tool.pyve.testenvs.*]`). Without the marker, an LLM or human refactoring `manifest.sh` for unrelated reasons (style, perf, accessor cleanup) can't tell which branches are load-bearing vs deprecation-window scaffolding. Tagging the boundary makes the N-10 sweep a 5-minute job; untagging would turn it into a full re-audit.

**How to apply:** when adding any new code path that exists only to bridge v2 → v3 (a fallback parser, a defensive normalization, a deprecation warning), open the change with `# v3.0-only: remove in N-10` on the function or block. If you find yourself wanting to make a v3.0-only path "permanent" (e.g., during a perf tune), that's a sign the v3 manifest schema is missing something — fix the schema, don't promote the read-compat.

### v3 state directory is `.pyve/envs/<name>/<backend>/`; route through helpers

All declared envs materialize at `.pyve/envs/<name>/<backend>/` (Story N.f). `<backend>` is `venv` for venv-backed, `conda` for micromamba-backed; future plugin backends pick their own subdir name. The reserved `root` env's micromamba prefix lands at `.pyve/envs/root/conda/` after `pyve self migrate` runs (pre-migration, it stays at `.pyve/envs/<configured_name>/` for compat). Path-construction goes through the helpers in [`lib/envs.sh`](../../lib/envs.sh):

- `state_path <name>` → `.pyve/envs/<name>/.state`
- `resolve_env_path <name>` → `.pyve/envs/<name>/{venv|conda}/`
- `migrate_legacy_env_layout` runs as a side effect of `resolve_env_path` to opportunistically catch v2.7 / v2.8 layouts.

A bats sweep in [`tests/unit/test_n_f_state_layout.bats`](../../tests/unit/test_n_f_state_layout.bats) greps `lib/commands/*.sh` and `pyve.sh` for forbidden `.pyve/testenvs/` literals and fails the build on regression. The migrator surfaces (`lib/envs.sh`, `lib/commands/self.sh`) are exempted by location since they legitimately reference the legacy path during migration.

**Why:** the v2 layout split env state across `.pyve/envs/` (micromamba main env) and `.pyve/testenvs/` (named testenvs). v3 consolidates both into one root so every backend plugin owns a uniform `<name>/<backend>/` slot. Hard-coding paths in command code recreates the v2 fragmentation: when N-3's Node plugin (or any future plugin) needs the env directory, it asks the helper and gets the right shape — not whatever literal the command author happened to type.

**How to apply:** when a command needs an env's on-disk path, call `resolve_env_path <name>` or `state_path <name>`. Do not construct `.pyve/envs/<name>/venv` (or any variant) by string concatenation. If you find yourself wanting to write the literal because "the helper does too much" (e.g., it triggers opportunistic migration as a side effect), that's a signal to factor the helper, not to inline the path. The sentinel test catches the literal regardless of intent.

### Pyve's toolchain Python is the hidden venv — route internal helper calls through `pyve_toolchain_python`

Pyve is implemented partly in Python: [`lib/pyve_toml_helper.py`](../../lib/pyve_toml_helper.py) (and the testenvs helper) parse `pyve.toml` / `pyproject.toml` via `tomllib`. The interpreter that runs those helpers is **Pyve's own toolchain Python**, not the developer's project Python. Any Pyve-internal callsite that shells out to run a Pyve Python helper **must** resolve the interpreter via `pyve_toolchain_python` (in [`lib/toolchain_python.sh`](../../lib/toolchain_python.sh)) — never inline `${PYVE_PYTHON:-python}`. The resolver's order is **`PYVE_PYTHON` → the hidden toolchain venv → bare `python`**; the venv lives at `${XDG_DATA_HOME:-$HOME/.local/share}/pyve/toolchain/<DEFAULT_PYTHON_VERSION>/venv`, is provisioned by `pyve self install`, version-keyed so a `DEFAULT_PYTHON_VERSION` bump lands a fresh tree, and removed by `pyve self uninstall`.

**The one exception is `assert_python_resolvable` ([`lib/env_detect.sh`](../../lib/env_detect.sh)).** It guards the *project* python — the developer's interpreter for `pyve run python`, version-manager activation, the project venv — which is a different concern and stays on `${PYVE_PYTHON:-python}`. The carved boundary is marked with a `BOUNDARY` comment in that function.

**Why:** caught by the N.at composed-init spike (Stories N.at, N.at.1–N.at.4). Before this, every callsite borrowed the developer's PATH `python` via `${PYVE_PYTHON:-python}`. On a clean non-Python stack — a version-manager shim with no pinned version, or no `python ≥ 3.11` at all — that resolution fails, `manifest_load` silently degrades, and a **Node-only project mis-enumerates as Python**. A Pyve-owned interpreter, independent of the developer's environment, removes that whole failure class. When the developer's environment already uses `DEFAULT_PYTHON_VERSION`, the version-manager shim points at the same binaries, so there's no duplication.

**How to apply:** when adding a Pyve-internal call that runs one of Pyve's Python helpers, write `local py; py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"` (the `local` is split from the assignment so the command-substitution exit status isn't masked; the `|| …` keeps the callsite self-sufficient when `lib/toolchain_python.sh` isn't sourced, e.g. piecemeal test subshells, while still honoring the override). The three reference callsites are `manifest_load` ([`lib/manifest.sh`](../../lib/manifest.sh)), `read_env_config` ([`lib/envs.sh`](../../lib/envs.sh)), and `_env_resolve_extra_packages` ([`lib/commands/env.sh`](../../lib/commands/env.sh)). Do **not** route `assert_python_resolvable` through the resolver — that is the project-python guard.
