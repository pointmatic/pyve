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
| `pyve update` | the project | `update_project()` | Refreshes `.gitignore`, `.vscode/settings.json`, project-guide — all project-level (no longer touches `.pyve/config`, which v3 neither writes nor reads) |
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
- [lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh) — `python_plugin_is_active_in_project` (Story N.aj). **Story N.aw reversed this:** `.project-guide.yml` is **no longer a Python-active signal**. project-guide is now a Pyve-managed *global* tool — hosted once in the toolchain venv with a `~/.local/bin` shim (see "Host project-guide as a Pyve-managed global tool"), **not** installed per-project into a venv-backed `root` `utility` env — so its per-project marker no longer implies a project Python env. A Node-only project that accepts project-guide has no `.venv` to report, so the Python plugin's `check`/`status` stay **suppressed**. (The earlier "project-guide ⇒ Python utility root" provisioning, F2/F3, was retired with this re-approach.)

**`.project-guide.yml` is a load-bearing cross-repo dependency contract.** pyve keys real behavior off this exact filename, so a rename or shape change in upstream `project-guide` is a coordinated breaking change: the project-guide side of it must resolve the pyve contract (per the "Cross-repo coordination with project-guide" entry). Story N.ao formalizes the contract + rename protocol alongside the wizard project-guide-provisioning design.

**Why:** picking the directory as the signal looked simpler at first but creates two failure modes: (1) the directory exists for unrelated reasons (the user's own `docs/project-guide.md` file inside a vendored docs structure, an empty placeholder dir, etc.); (2) the user has relocated project-guide artifacts via `target_dir`, so the directory at the default path doesn't exist while project-guide is in fact installed and active.

**How to apply:** when adding a new pyve consumer that needs to know whether project-guide is installed, key off `[[ -f ".project-guide.yml" ]]`. Do not add a parallel `[[ -d "docs/project-guide" ]]` check. If you need the artifact directory's actual path, parse `target_dir` from `.project-guide.yml` (basic YAML: a plain `key: value` line), don't assume the default.

### `pyve.toml` is the canonical declaration; `.pyve/` holds state only

From v3.0 onward, every project's declaration lives at root-level `pyve.toml` (schema: `pyve_schema`, `[project]`, `[env.<name>]`). Everything under `.pyve/` is **materialized state** — environments, locks, sentinels, the `.v2-legacy/` backup tree — never configuration. The Python helper [`lib/pyve_toml_helper.py`](../../lib/pyve_toml_helper.py) is the only TOML reader; the Bash shim [`lib/manifest.sh`](../../lib/manifest.sh) exposes the parsed result through `manifest_load` + flat accessors (`manifest_get_purpose`, `manifest_resolve_purpose`, `manifest_get_backend`, etc.).

**As of v3.1 (Subphase P-1, the P.i bundle), the v2 `.pyve/config` file is fully retired: pyve neither writes nor reads it.** `manifest_load` on a project with no `pyve.toml` returns the empty-config baseline — a legacy `.pyve/config`-only (unmigrated v2) project is therefore *uninitialized* from pyve's point of view. **No code reads `.pyve/config` at all**: the read-compat synthesis went in P.i.13, and the v2 `self migrate` bridge — its parser, the `.pyve/.v2-legacy/` backup, and the soft banner — went in P.i.15 (along with the now-dead `read_config_value` / `config_file_exists` helpers). The single remaining mention in logic is `purge`'s opportunistic `rm -f .pyve/config` cleanup, which *deletes* a leftover legacy file rather than reading it. `pyve self migrate` is retained only as a **reserved stub** for a future schema migration (e.g. v3 → v4). A `pyve.toml`-only project is fully functional across `status` / `check` / `run` / `lock` / `env` (verified end-to-end in P.i.14).

**Why:** the v2 model spread declaration across `.pyve/config` (YAML) and `[tool.pyve.testenvs.*]` (pyproject TOML). Two sources of truth was the root cause of every "but it works on my machine" bug in Phase M's testenv-DX bundle, and it forced consumers to keep two readers in sync. Consolidating onto one root-level file removes that whole class of failure and matches the Pyve visibility goal (root-level presence signals "this is a Pyve project" to humans and tools at a glance).

**How to apply:** when adding a new pyve consumer that needs a configuration value, route through `manifest_load` + an accessor. Do not parse `pyve.toml` directly. Do not introduce a new YAML / TOML / INI declaration file. If a value genuinely doesn't fit the `pyve.toml` schema (e.g., a per-user preference rather than per-project), it belongs in `~/.config/pyve/` or an env var — never under `.pyve/` (state) and never alongside `pyve.toml` (which is the schema-validated surface).

### `purpose:` vocabulary and the name-based default rule

Every `[env.<name>]` block carries a `purpose` attribute drawn from the closed set `{run, test, utility, temp}`. When `purpose` is omitted, the resolver [`manifest_resolve_purpose`](../../lib/manifest.sh) applies a name-based default: `testenv → test`, `root → utility`, everything else → `utility`. Explicit declaration always wins. The resolver is the **single** gate purpose-keyed selectors consult — `pyve test --env <name>` hard-errors when the resolved purpose is not `test`, and analogous gates ship in later subphases for `run` / `utility`.

**Why:** the v2 `testenvs` namespace overloaded "test environment" to mean "any env that isn't the main one" — utility envs (dev tooling, formatters) and ephemeral envs (one-shot tasks) all rode the same label. Phase N split them so each purpose can grow its own lifecycle (e.g., `temp` envs auto-prune; `utility` envs survive `pyve purge`). The name-based default keeps the common case (one main env + one test env) zero-config.

**How to apply:** when adding a new purpose-aware feature, call `manifest_resolve_purpose <name>` — never inline a `[[ "$name" == "testenv" ]]` check (that re-implements the default rule and silently drifts when the resolver changes). When introducing a fifth purpose value, the closed set in [`lib/pyve_toml_helper.py`'s](../../lib/pyve_toml_helper.py) `VALID_PURPOSES` is the canonical place; update accessors and gates from there.

### v2 is fully retired — no migration bridge, no banner, no read-compat

v2 (`.pyve/config` + `[tool.pyve.testenvs.*]`) is no longer supported in any form. The transition passed through three shrinking stages and is now complete:

1. **v3.0** shipped three coordinated surfaces — a read-compat synthesis (`_manifest_synthesize_from_legacy`) that let an unmigrated project keep working, a soft banner that nudged toward migration, and a `pyve self migrate` bridge that converted legacy sources to `pyve.toml` + backed them up under `.pyve/.v2-legacy/`.
2. **P.i.13** removed the read-compat synthesis: an unmigrated `.pyve/config`-only project began reading as *uninitialized* (`manifest_load` returns the empty-config baseline).
3. **P.i.15** removed the `self migrate` v2 bridge (the `.pyve/config` / `[tool.pyve.testenvs.*]` parser, the `.pyve/.v2-legacy/` backup, and the `read_config_value` / `config_file_exists` helpers) **and** the soft banner (`_pyve_maybe_show_v2_banner` in [`pyve.sh`](../../pyve.sh), with its `PYVE_QUIET` gate and `$XDG_STATE_HOME` sentinel). `pyve self migrate` survives only as a **reserved stub** ([`lib/commands/self.sh`](../../lib/commands/self.sh)): it recognizes no legacy sources, writes nothing, and exits cleanly — a stable home for a future schema migration (e.g. v3 → v4).

**There is no automated path from a v2 project to v3 anymore.** A user with a legacy `.pyve/config` re-runs `pyve init`. Nothing in pyve reads `.pyve/config`; the only mention left in logic is `purge`'s opportunistic `rm -f .pyve/config` cleanup (a delete of a stray legacy file).

**Why (developer decision, 2026-07-03):** once read-compat was gone (P.i.13), the `self migrate` bridge + banner were the *only* remaining v2 investment — a `.pyve/config` parser, a `[tool.pyve.testenvs.*]` extractor, the `.v2-legacy` backup, and banner memoization, all maintained for a shrinking population of unmigrated projects. Removing them in the same release that made v3.1 the "v2 is done" line sharpens the break but ends the maintenance. The trade — an unmigrated v2 user gets no nudge and no auto-migrate — was accepted deliberately.

**How to apply:** do **not** re-introduce a `.pyve/config` reader, a v2 nudge/banner, or the removed helpers. If a *future* schema migration (v3 → v4) is needed, re-flesh the reserved `self_migrate` stub rather than adding a new command, and keep `.pyve/.v2-legacy/` as the single deterministic backup directory if you add backup behavior.

### v3 state directory is `.pyve/envs/<name>/<backend>/`; route through helpers

All declared envs materialize at `.pyve/envs/<name>/<backend>/` (Story N.f). `<backend>` is `venv` for venv-backed, `conda` for micromamba-backed; future plugin backends pick their own subdir name. The reserved `root` env's micromamba prefix lands at `.pyve/envs/root/conda/` on **fresh `pyve init`** (Story N.bf.14 finished the physical move N.g had left logical-only). The configured env name survives only as the conda env's metadata `name:` in `environment.yml`; it no longer keys the directory. Pre-N.bf.14 flat main envs (conda-meta directly inside `.pyve/envs/<configured>/`) are relocated by an opportunistic mover. Path-construction goes through the helpers in [`lib/envs.sh`](../../lib/envs.sh):

- `state_path <name>` → `.pyve/envs/<name>/.state`
- `resolve_env_path <name>` → `.pyve/envs/<name>/{venv|conda}/`; for `root` it is backend-aware (`venv` → `.venv`; `micromamba` → `.pyve/envs/root/conda/`) and **fires** the opportunistic move.
- `micromamba_root_prefix` → the single source of the `.pyve/envs/root/conda` literal (used by `create_micromamba_env` / `verify_micromamba_env` and `resolve_env_path root`).
- `resolve_main_micromamba_path [<name>]` → **non-mutating** tolerant resolver for read paths (`check` / `status` / `run`): returns the root slot if present, else the legacy flat path, without triggering the move.
- `migrate_legacy_env_layout` runs as a side effect of `resolve_env_path` to opportunistically catch v2.7 / v2.8 / v3-flat layouts.

A bats sweep in [`tests/unit/test_n_f_state_layout.bats`](../../tests/unit/test_n_f_state_layout.bats) greps `lib/commands/*.sh` and `pyve.sh` for forbidden `.pyve/testenvs/` literals and fails the build on regression. The migrator surfaces (`lib/envs.sh`, `lib/commands/self.sh`) are exempted by location since they legitimately reference the legacy path during migration.

**Why:** the v2 layout split env state across `.pyve/envs/` (micromamba main env) and `.pyve/testenvs/` (named testenvs). v3 consolidates both into one root so every backend plugin owns a uniform `<name>/<backend>/` slot. Hard-coding paths in command code recreates the v2 fragmentation: when N-3's Node plugin (or any future plugin) needs the env directory, it asks the helper and gets the right shape — not whatever literal the command author happened to type.

**How to apply:** when a command needs an env's on-disk path, call `resolve_env_path <name>` or `state_path <name>`. Do not construct `.pyve/envs/<name>/venv` (or any variant) by string concatenation. If you find yourself wanting to write the literal because "the helper does too much" (e.g., it triggers opportunistic migration as a side effect), that's a signal to factor the helper, not to inline the path. The sentinel test catches the literal regardless of intent.

### `pyve_file_sha256` is a true SHA-256 — never add a CRC/`cksum` fallback

`pyve_file_sha256` ([`lib/utils.sh`](../../lib/utils.sh)) hashes a file's contents via `sha256sum` (Linux) → `shasum -a 256` (macOS) and returns **non-zero with no output** when neither tool exists. It deliberately has **no `cksum`/CRC fallback**, even though one would make it "work" on more systems.

**Why:** the helper is shared by two callers with very different stakes. Story N.bf.15 (`environment.yml` drift detection) only needs "did the bytes change," so any deterministic digest would technically suffice there. But Story N.bh verifies the **micromamba bootstrap download** against a **published SHA-256 checksum** — a CRC value would never match the upstream digest, turning verification into a permanent false-fail or, worse, a false sense of security. A function named `…_sha256` that can silently return a non-SHA-256 value is a supply-chain footgun. Returning non-zero is the correct degrade for both callers: drift treats it as "can't tell → no nudge"; download verification treats it as "can't verify → hard error / abort."

**How to apply:** do not add a `cksum` / `md5` / CRC fallback "for portability" — macOS (`shasum`) and Linux (`sha256sum`) are already covered, and the security caller depends on the result being a genuine SHA-256. If a truly toolless platform ever appears, add another *real* SHA-256 implementation, never a weaker hash. Callers must handle the non-zero return (no-op for drift, hard error for verification), not assume the helper always prints a digest.

### Pyve's toolchain Python is the hidden venv — route internal helper calls through `pyve_toolchain_python`

Pyve is implemented partly in Python: [`lib/pyve_toml_helper.py`](../../lib/pyve_toml_helper.py) (and the testenvs helper) parse `pyve.toml` / `pyproject.toml` via `tomllib`. The interpreter that runs those helpers is **Pyve's own toolchain Python**, not the developer's project Python. Any Pyve-internal callsite that shells out to run a Pyve Python helper **must** resolve the interpreter via `pyve_toolchain_python` (in [`lib/toolchain_python.sh`](../../lib/toolchain_python.sh)) — never inline `${PYVE_PYTHON:-python}`. The resolver's order is **`PYVE_PYTHON` → the hidden toolchain venv → bare `python`**; the venv lives at `${XDG_DATA_HOME:-$HOME/.local/share}/pyve/toolchain/<DEFAULT_PYTHON_VERSION>/venv`, is provisioned by `pyve self install`, version-keyed so a `DEFAULT_PYTHON_VERSION` bump lands a fresh tree, and removed by `pyve self uninstall`.

**The one exception is `assert_python_resolvable` ([`lib/env_detect.sh`](../../lib/env_detect.sh)).** It guards the *project* python — the developer's interpreter for `pyve run python`, version-manager activation, the project venv — which is a different concern and stays on `${PYVE_PYTHON:-python}`. The carved boundary is marked with a `BOUNDARY` comment in that function.

**Why:** caught by the N.at composed-init spike (Stories N.at, N.at.1–N.at.4). Before this, every callsite borrowed the developer's PATH `python` via `${PYVE_PYTHON:-python}`. On a clean non-Python stack — a version-manager shim with no pinned version, or no `python ≥ 3.11` at all — that resolution fails, `manifest_load` silently degrades, and a **Node-only project mis-enumerates as Python**. A Pyve-owned interpreter, independent of the developer's environment, removes that whole failure class. When the developer's environment already uses `DEFAULT_PYTHON_VERSION`, the version-manager shim points at the same binaries, so there's no duplication.

**How to apply:** when adding a Pyve-internal call that runs one of Pyve's Python helpers, write `local py; py="$(pyve_toolchain_python 2>/dev/null)" || py="${PYVE_PYTHON:-python}"` (the `local` is split from the assignment so the command-substitution exit status isn't masked; the `|| …` keeps the callsite self-sufficient when `lib/toolchain_python.sh` isn't sourced, e.g. piecemeal test subshells, while still honoring the override). The three reference callsites are `manifest_load` ([`lib/manifest.sh`](../../lib/manifest.sh)), `read_env_config` ([`lib/envs.sh`](../../lib/envs.sh)), and `_env_resolve_extra_packages` ([`lib/commands/env.sh`](../../lib/commands/env.sh)). Do **not** route `assert_python_resolvable` through the resolver — that is the project-python guard.

### No story / phase IDs in code or comments — relocate the *why*

Code and comments in `lib/`, `pyve.sh`, and `tests/` must not cite a story/phase ID: no `# Story N.x:` / `(Story N.x)`, no bare `N.av.2` / `M.h.3` / `H.e.9c` cross-refs, no `Phase N` / `Subphase N-6` pointers used as narration. State the *why* in self-contained prose instead (`# Resolve <name> to a purpose`, not `# Story N.d: resolve …`). Story IDs are the durable narrative in [`stories.md`](stories.md); a code comment that points at one is redundant with it and rots when stories are renumbered/archived.

**Load-bearing exceptions (keep):** the `BOUNDARY` marker in `assert_python_resolvable`; the `N.i-pending` skip-reason strings in the test suite (functional markers cross-referenced from `lib/plugins/python/plugin.sh`); and feature labels like `F6` (drop only a trailing `/N.x`, keep the `F<n>`). (The `v3.0-only: remove in N-10` read-compat markers were a load-bearing exception during the v3.0 window; they and the synthesis they guarded were removed in Story P.i.13, so they no longer exist to except.)

**Why:** beyond rot, story-ref comments are a **behavioral attractor**. LLM contributors imitate local comment idiom (they are instructed to match surrounding density/naming/idiom), so every `# Story N.x:` left in the tree raises the prior that comments here are *supposed* to cite a story — and the next contributor emits more. The conspicuous leading `# Story X.y:` form is the strongest template; bare inline refs are weaker. Removing them is not cosmetic — it removes the seed. This rule is the durable guard that stops *new* ones regardless of how much historical cleanup has happened. (Phase N's `# Story N.x` refs were swept in N.bd/N.bd.1; the all-phase + bare-ref cleanup is audited in N.bd.2–N.bd.4.)

**How to apply:** when you'd write `# Story N.x: does Y`, write `# does Y` (or, if the *why* isn't derivable from the code, state it directly — never via a story number). If a ref is genuinely a contract (a removal trigger, a grep target, a functional skip reason), it is an exception above — keep it, and make its load-bearing role explicit in the comment. The detector in N.bd.2's audit script doubles as the enforcement grep if wired into CI.

### Installed `pyve` and the working-tree `./pyve.sh` can be different major versions — establish which is in play before reasoning

When debugging anything environment-shaped — where a tool lives, why a command resolves the way it does, what `pyve self <x>` supports — first establish **which pyve will execute**: the *installed* binary on PATH (`pyve`, often Homebrew at `/opt/homebrew/Cellar/pyve/<ver>`) versus the *working-tree dev code* (`./pyve.sh`, the repo you're editing). In this repo they routinely differ by a **major version**: you develop v3.x here while the installed daily driver may still be v2.x. `command -v pyve` + `pyve --version` versus `DEFAULT_PYTHON_VERSION` / `pyve_schema` in the tree reveals the skew.

The two versions disagree about real behavior. Canonical example (the trap that burned most of a debugging session): in **v3.x** project-guide's *binary* is globally hosted in Pyve's toolchain venv (`~/.local/share/pyve/toolchain/<DEFAULT_PYTHON_VERSION>/venv/bin/project-guide`) with a `~/.local/bin/project-guide` shim, provisioned by `./pyve.sh self provision`. In **v2.x** that subcommand doesn't exist and project-guide is pip-installed per-repo into the project `.venv`. Only the *scaffolding* (`.project-guide.yml`, `docs/project-guide/`) is per-repo in both.

**Why:** the LLM reads the working-tree (v3) code and confidently prescribes v3-only commands/paths on a machine whose installed pyve is v2 — `pyve self provision` → "Unknown subcommand", a `~/.local/share/pyve/toolchain` tree v2 never created, an asdf-coupled "fix" that inverts v3's design. Nearly every "pyve is behaving mystically" report in a dev checkout traces to v2-binary-driving-v3-state (or the reverse) skew that nothing currently detects. A second layer of the same trap: command resolution is **PATH-slot ordered** — a direnv-activated `.venv/bin` shadows the asdf `~/.asdf/shims` pin (so `python` can report a version that contradicts `.tool-versions`), and a `~/.local/bin` shim precedes the asdf shims (so a hosted tool there bypasses an asdf pin entirely). When version behavior looks impossible, trace which PATH slot the command resolves from before theorizing.

**How to apply:** before recommending or running any `pyve …` command as a fix, confirm the version that will run it and whether the user means the installed binary or `./pyve.sh`. When a repo is v3-shaped but the installed binary is v2, the coherent answer is to drive that repo with its own `./pyve.sh` and let v3 host its tools the v3 way — never bend v2's per-`.venv` model onto v3 state, and never "repair" by pointing a shim at a version-manager-owned interpreter (that recreates the coupling the toolchain design exists to remove). Repo↔binary version-skew *detection* is scoped into Subphase N-11 "Harden and heal Pyve"; until it ships, this is a manual check.

### Running the integration suite locally mutates your REAL `~/.local` and `~/.asdf`

The integration harness's `_isolate_home` ([tests/integration/test_project_guide_integration.py](../../tests/integration/test_project_guide_integration.py)) fakes `$HOME` but **symlinks the developer's real `~/.asdf`, `~/.pyenv`, `~/.local`, `.tool-versions`, and `.python-version` into the fake home** so version managers still resolve. Consequently any test that *provisions* Pyve hosting (`self install` / `self provision` / `pyve_project_guide_ensure`) or pip-installs through an asdf interpreter writes into your **real** `~/.local/share/pyve/toolchain`, `~/.local/bin`, and `~/.asdf` — and those artifacts dangle when the test's tmpdir is reaped (a toolchain venv whose `python` symlink now targets a deleted bootstrap interpreter; a `~/.local/bin/project-guide` shim pointing into a removed pytest dir).

**Why:** not hypothetical — this corrupted a developer's real project-guide hosting (dangling shim + dead-interpreter toolchain venv) and produced a cryptic `No version is set for command project-guide` that took a long manual trace to untangle. The leak also means project-guide PATH-stub tests are **not hermetic**: internal callsites resolve project-guide by **hosted absolute path** (`pyve_project_guide` → toolchain venv → `~/.local/bin` shim), which deliberately ignores PATH (the N.bf.22 anti-asdf-shim fix), so a stub injected only onto PATH is silently bypassed and the test exercises whatever real project-guide the machine has hosted — green for the wrong reason.

**How to apply:** treat a local `pytest tests/integration/` run as something that can write to your real home — expect to repair `~/.local/bin/project-guide` + the toolchain venv afterward (`./pyve.sh self provision` rebuilds them cleanly when *you* run it with a real `$HOME`). When a test needs Pyve to run a *stub* project-guide, set `PYVE_PROJECT_GUIDE_BIN=<stub>` (and `PYVE_PYTHON` for the interpreter) at top precedence — never rely on a PATH-only shadow, which the hosted-absolute-path resolver ignores. `PYVE_PROJECT_GUIDE_BIN` mirrors `PYVE_PYTHON`: both are honored first by every resolver/predicate (`pyve_project_guide` + `_available` / `_is_hosted` / `_ensure`). Closing the leak itself (a self-contained fake `$HOME`) is scoped into Subphase N-11.

### Never pipe a still-writing producer into `grep -q` under `set -o pipefail`

`<live-command> | grep -q <pat>` is a SIGPIPE trap under pyve's `set -euo pipefail`. `grep -q` exits on its first match and closes the pipe; the producer — still writing later lines — takes **SIGPIPE (141)**, and `pipefail` propagates that as the pipeline's exit status, a false negative. **Capture first, then grep a here-string:** `out="$(cmd 2>/dev/null || true)"; grep -q <pat> <<<"$out"`.

**Why:** caught twice — `detect_version_manager` (fixed N.bf.6) and `is_python_version_installed` (fixed N.bm). In N.bm a `pyenv versions --bare` list with the matched version *followed by* a later version (`3.12.13` then `3.14.5`) closed the pipe early → SIGPIPE → false "Python 3.12.13 is not installed", but **only** on the macOS CI runner in the full suite, where a second version happened to follow the match in the shared pyenv root. Invisible on a dev box whose list ends at the match; surfaces non-deterministically depending on installed versions and test order.

**How to apply:** grep the tree for live pipes into a short-circuiting grep (`| grep -q`, `| grep -qx`, `| grep -qE`) where the left side keeps writing after the first match (`pyenv versions`, `asdf list`, `asdf plugin list`, …) and convert each to capture-then-grep. A list already fully buffered into a variable is safe; a live pipe is not. Regression shape: a shim that emits the match followed by extra output, asserted green under `pipefail` (see [tests/unit/test_env_detect.bats](../../tests/unit/test_env_detect.bats)).

### Health checks must probe runnability, not just existence

A `[[ -x <path> ]]` / `[[ -f <path> ]]` / `[[ -d <path> ]]` test passes for a **dangling symlink or a script with a dead shebang** — the file exists and carries the executable bit, but it cannot run. Any health/diagnostic code that declares a managed artifact "provisioned/healthy" on an existence test alone can be fooled into reporting a broken install as good.

**Why:** `_compose_check_pyve_hosting` ([lib/check_composer.sh](../../lib/check_composer.sh)) reports `project-guide hosting: provisioned` on `[[ -x "$venv_dir/bin/python" ]]`, which stayed true for a toolchain venv whose `python` symlink pointed at a deleted interpreter — so `pyve check` would have rubber-stamped the exact corruption that broke a developer's environment. Existence ≠ runnability.

**How to apply:** for any "is this tool/interpreter healthy?" check that gates user-facing health output or a heal decision, **execute** the artifact and classify the failure (`"$py" --version`, `"$pg" --version`) rather than stat-ing it; reserve `-x`/`-f` for cheap pre-filters, not the final verdict. The systematic conversion plus a `pyve heal` is scoped into Subphase N-11 "Harden and heal Pyve" — but new health code should adopt the probe pattern now rather than add more existence-only checks to retrofit later.

### `pyve self provision --status [--json]` is the cross-repo hosting-readiness contract

`pyve self provision --status` is the stable, machine-readable query other tools (project-guide first) consult to learn whether Pyve's global hosting is **ready** — **without** a project context and **without** reaching into Pyve's version-keyed, `XDG_DATA_HOME`-relative internal paths. It is the read-only sibling of `pyve self provision` ([`self_provision_status`](../../lib/commands/self.sh)): no network, no provisioning, no state writes. The **exit-code contract** is the surface consumers pin against:

- `0` — hosting **ready**: toolchain venv **runnable** AND the hosted `project-guide` shim **runnable**.
- `1` — Pyve-**managed but not ready**: never provisioned, or provisioned-but-broken (dangling shim / dead-shebang interpreter).
- `2` — **not Pyve-managed** here: the project owns project-guide via a deps source (`pyproject.toml` / `requirements.txt` / `environment.yml`), so "not my department".

`--json` emits `{ pyve_managed, toolchain:{provisioned,runnable,version}, project_guide:{hosted,runnable,version,shim} }`. Classification probes **runnability**, not existence: it shares `pyve_toolchain_runnable` / `pyve_project_guide_runnable` (both built on `pyve_runnable_version`, all in [`lib/toolchain_python.sh`](../../lib/toolchain_python.sh)) with `_compose_check_pyve_hosting`, so the human `pyve check` and the machine query can **never disagree** about what "ready" means. Both honor the `PYVE_PROJECT_GUIDE_BIN` / `PYVE_PYTHON` override seams. This is a cross-repo contract: **project-guide ≥ 2.15.0** ships the readiness-gated local-install warning that consumes it (and degrades safe — never advises `pip uninstall` — when the query is absent or returns non-zero); the matching design lives in [project-guide-requests/local-install-warning-readiness-gate.md](project-guide-requests/local-install-warning-readiness-gate.md). The pyve-hosted project-guide install floor was bumped to `>=2.15.0` to match.

**Why:** before this, the only hosting surface was the human-formatted, project-scoped `pyve check`; a tool wanting "is hosting ready?" had to parse that output or stat Pyve's private layout. Worse, the `provision)` dispatcher only special-cased `--help` and **fell through to `self_provision` for anything else** — so a probe like `pyve self provision --status` against a Pyve too old to know `--status` silently **re-provisioned the whole toolchain and returned 0**, the live root cause of project-guide reading false "global is active" + emitting destructive `pip uninstall` advice. The dispatcher now rejects any unrecognized flag with a hard error; **bare `provision` (no args) is the only form that provisions** — making the fall-through impossible by construction.

**How to apply:** when a tool (CI gate, editor integration, future plugin) needs to know whether Pyve hosting is ready, shell out to `pyve self provision --status` and branch on the exit code — never stat the toolchain path or the shim. When adding a new hosting health/readiness check inside Pyve, reuse `pyve_toolchain_runnable` / `pyve_project_guide_runnable` (execute the artifact) rather than a fresh `[[ -x ]]`. Never add a new flag to the `provision)` arm by routing it through a fall-through; add an explicit `case` arm so the no-provision-by-accident invariant holds.

### A forced/refresh rebuild honors the manifest backend — `pyve.toml` outranks the filesystem heuristic

`pyve init` resolves the backend in this priority order: an explicit `--backend` flag, then the `root` env's `backend` declared in `pyve.toml` (`_init_manifest_root_backend` in [`lib/plugins/python/plugin.sh`](../../lib/plugins/python/plugin.sh)), then the filesystem heuristic (`environment.yml` → micromamba, else venv), then the venv default. The manifest read is the new middle tier: when `pyve.toml` declares a root backend and no `--backend` is given, the wizard seeds `backend_flag` from it, suppresses the interactive backend prompt, and the value flows into `get_backend_priority` as Priority 1 — so the manifest wins on both `--force` and non-force re-init. (In v3.1 there is no `.pyve/config` tier left to outrank: the P.i bundle removed `get_backend_priority`'s Priority-2 config tier and the now-vestigial `skip_config` param, so the declared manifest backend is simply the highest-priority source after an explicit `--backend` flag.)

A coupled invariant ships alongside it:

- **A forced rebuild never orphans a foreign-backend env.** `_init_backup_foreign_env` moves a stray env of a backend that differs from the manifest's target (a `.venv` alongside a micromamba manifest, or `.pyve/envs/root/conda` alongside a venv manifest) into `.pyve/.v2-legacy/` — recoverable, never deleted — before creating the new one.

**Why:** caught migrating a micromamba `root` project. `init_project` validated an existing `pyve.toml`'s *schema* but never read its *content*; a bare `pyve init --force` (which `self migrate` ran as its rebuild step) left `backend_flag` empty, so the wizard re-derived the backend from filesystem signals. When the signals disagreed with the manifest — a declared micromamba `root` with no `environment.yml` — the rebuild silently materialized a `.venv`, orphaned the intact conda env, and wrote a contradictory `.pyve/config`. Honoring the manifest content removes the conversion; dropping migrate's rebuild removes the most dangerous caller by construction; the foreign-env backup closes the orphan window for any pre-existing inconsistent state. (`pyve.toml`'s `[env.root]` carries no python field, so python/version-manager continue to come from `environment.yml` / `.tool-versions`, which the wizard already honors — only the backend needed a manifest read.)

**How to apply:** when adding any code path that re-derives a project attribute already declared in `pyve.toml` (backend today; a future python pin, packaging target, etc.), read the manifest as authoritative first and fall back to detection only for what the manifest leaves undeclared — never let a filesystem heuristic override a declared value. (The rebuild used to also emit a `.pyve/config` for v3.0 read-compat; that write, its ~64 read-sites, and the read-compat synthesis were all removed across the P.i bundle — `pyve.toml` is now the sole declaration. See [[`pyve.toml` is the canonical declaration; `.pyve/` holds state only]].)

### conda/venv environments are not relocatable — repair the baked prefix on move, and probe runnability (not existence) before trusting one

A conda/micromamba env (and a venv) bakes its **absolute prefix** into text artifacts at creation: console-script shebangs (`bin/*`), `conda-meta/*.json` package records, and site-packages `*.pth` files (venvs: the `bin/*` shebangs). A bare directory `mv` relocates the tree but rewrites none of that, so every console script is left with a **dead-shebang** pointing at the old, now-nonexistent prefix — `pip` and every entry point fail with "bad interpreter". The env's **python binary keeps running** (it is Mach-O/ELF, not a shebang script), so `[[ -x bin/python ]]` and `python --version` both pass and mask the breakage.

Two rules follow, both shipped in [`lib/envs.sh`](../../lib/envs.sh) / [`lib/micromamba_env.sh`](../../lib/micromamba_env.sh):

- **Never bare-`mv` an env prefix — move then repair.** Every relocation in the opportunistic layout mover (`migrate_legacy_env_layout` and its v2.7 / v2.8 / v3-flat sub-movers) calls `_env_repair_baked_prefix <old_abs> <new_abs> <env_dir>` immediately after the `mv`. It rewrites the old prefix → new prefix in `bin/*` (text files only — **binaries are skipped so a Mach-O/ELF is never `sed`'d**), `conda-meta/*.json`, and `*.pth`. Repair (a cheap local rewrite) is used here rather than recreate-from-`environment.yml` because the mover fires as a **side effect of `resolve_env_path`** on routine read commands (`check` / `status` / `run`) — a conda solve+download there would be an unacceptable surprise.
- **Health/skip decisions probe runnability, not existence.** `create_micromamba_env` no longer skips on "directory exists"; it calls `_micromamba_env_runnable` (executes `bin/pip --version`) and **rebuilds** a non-runnable env instead of rubber-stamping it. This is the recreate **backstop** for any baked-prefix location the repair didn't cover (compiled packages that embed the prefix in a binary, pkg-config `.pc` files, etc.) — repair handles the common path cheaply; the runnable probe + rebuild catches the residue on the explicit `pyve init --force`.

**Why:** caught migrating a micromamba `root` project — `pyve init --force` → "Install pip dependencies?" → `bad interpreter: No such file or directory` for `.pyve/envs/root/conda/bin/pip`. The v3 layout mover had `mv`'d the flat prefix `.pyve/envs/<configured>/` → `.pyve/envs/root/conda/`, leaving 23 dead-shebang console scripts; `pyve init --force` then saw the directory and printed "environment already exists, skipping creation", so nothing healed it. This is the canonical existence-≠-runnability trap, in the migration path; it is the companion to the manifest-honoring rebuild ([[A forced/refresh rebuild honors the manifest backend — `pyve.toml` outranks the filesystem heuristic]]) — together they were why migrating a micromamba project was unsafe.

**How to apply:** when you add or touch any code that **moves** a materialized env directory, call `_env_repair_baked_prefix` after the move — never ship a bare `mv` of a prefix. When you add any "is this env/tool healthy?" check that gates a skip or a heal, **execute** an artifact that carries the baked prefix (a console script — `pip --version`), never stat `bin/python` or test `[[ -x ]]` alone (this is the same runnability-probe pillar as [[Health checks must probe runnability, not just existence]]). If a future relocation needs a guaranteed-clean env rather than a repaired one, do the recreate-from-`environment.yml` in the **explicit** `pyve init --force` path where a solve is expected — not in the opportunistic mover.

### `backend = "none"` declares a runtime-less / non-Python root — init skips it, never crashes

`backend = "none"` on `[env.root]` (or any env) declares that the slot has **no Pyve-managed Python/virtualenv runtime** — it is for non-Python languages / backends / environments Pyve does **not yet materialize**: a Node root (npm/pnpm/yarn), Rust (cargo), Go, advisory cache-backed toolchains, or a polyglot coordination root. It lets a project use Pyve's declaration + `.envrc`/direnv wiring + named **purpose-driven** envs (e.g. a micromamba `test` env, advisory tool envs) **without a vestigial root `.venv` or a forced Python pin**. `none` is the canonical member of the **advisory** backend category (vs. the `implemented` `venv`/`micromamba`); the closed vocabulary lives in [`lib/pyve_toml_helper.py`](../../lib/pyve_toml_helper.py)'s `classify backend` (`implemented` / `advisory` / `unknown`).

`none` is **declarable and init-safe but not materializable**: `pyve init` on a `none`-root project **skips** root env creation, emits the same "declares backend '<x>', which pyve does not yet materialize; provision it manually" note the per-env install path uses, and still composes `.envrc` / `.gitignore`, writes the manifest, and runs project-guide + next-steps. Declared **concrete-backend** envs (a micromamba `testenv`) on the same project materialize normally via `pyve env init <name>` — the advisory root never gates them off. Actually *creating* non-Python root runtimes (npm install, cargo, …) is future per-plugin work. For a pure-Python project `none` gains nothing over `venv`; it exists specifically for the runtime-less / non-Python root.

**Why:** an advisory backend is intentionally **unregistered** in the backend registry (`bp_lookup` knows only `implemented` backends), so three gates each rejected `none` before they learned the advisory carve-out: the Python plugin's env-block validation (`python_pyve_plugin_validate_env_blocks`), `init`'s `validate_backend` (closed `venv|micromamba|auto` set), and the plugin's `.envrc` activate hook (`python_pyve_plugin_activate`'s backend `case`). A `none`-root + micromamba-testenv topology — a real field need — was un-buildable because the first gate aborted the whole init before anything materialized. Routing every gate through the single advisory classifier (`_env_backend_is_advisory`) means the skip-don't-crash policy lives in one place and a genuinely-unknown backend (`bogus`) still hard-errors.

**How to apply:** any new code path that branches on a backend value — a validation gate, a materializer, an activation/exec hook, a diagnostic — must, before rejecting an unregistered/unknown backend, ask `_env_backend_is_advisory "$backend"` (the shell front-end to the Python `classify` vocabulary; see [[`purpose:` vocabulary and the name-based default rule]] for the analogous single-classifier discipline). Advisory → skip-with-note and continue; only a truly `unknown` backend hard-errors. **Never inline a `[[ "$backend" == "none" ]]` check** — that re-implements the closed vocabulary on the shell side and drifts the day a second advisory backend is added. An **explicit `--backend`** stays strict (it must not silently accept an advisory or unknown value); the advisory skip applies only to a **manifest-declared** backend.

### `pyve init` materializes only what's declared; declared ≠ operable (empty-until-demand)

`pyve init`'s promise is a graduated **declared → materialized → operable** ladder — it materializes only what `pyve.toml` declares, and a declared env is not automatically an operable or dependency-populated one:

- The **run (`root`) env** materializes to its declared backend; an advisory `none` root is declarative-only (nothing built — see [[`backend = "none"` declares a runtime-less / non-Python root — init skips it, never crashes]]).
- The **default test env** materializes iff it is declared AND its resolved backend (`_init_testenv_to_materialize` in [`lib/plugins/python/plugin.sh`](../../lib/plugins/python/plugin.sh), via [[A no-backend testenv resolves `inherit` against the manifest root]]'s `_env_resolve_backend`) is `venv` — created **empty**. A conda-backed/advisory default, or any **non-default named env**, is **deferred to `pyve env init <name>`** (no implicit conda solve at init).
- **No test env declared → none created.** init never injects an undeclared `testenv`. A fresh `pyve init` still gets one only because the scaffold `_init_write_pyve_toml` declares `[env.testenv] default = true`.

**Empty-until-demand:** a materialized env comes up with no dependencies; they install on first `pyve test` / `pyve env install`. Declaration, materialization, and dependency-population are three distinct steps — a `[env.<name>]` block installs nothing by itself.

**`pyve test` default selection** (`_test_default_env`, no `--env`): an explicit `default = true` wins; else a **homogeneous** (all declared envs one backend) **Python-rooted** project with **exactly one** `purpose=test` env auto-promotes that sole env (no `default` needed); else — mixed backend, multiple test envs without a default, or a non-Python/`none` root — there is **no** default and `pyve test` requires an explicit `--env`. A *bare* project (no manifest) keeps the conventional reserved `testenv` as its implicit sole default. A `purpose="test"` env with no `default` on a non-promotable project is a **skeleton**: declared (selectors resolve) and materialized on demand, never autowired.

**Why:** init used to eagerly build a bare `testenv` venv regardless of declaration (it then read as "broken — pytest not installed" in `pyve check`), a no-backend testenv hard-coded `venv` instead of mirroring the root, and `pyve test` silently picked a default under ambiguity. Grounding everything in the declaration — and making "empty" the *intended* post-init state rather than a defect — gives "initialize" one clear meaning and stops the magic.

**How to apply:** route init's testenv decision through `_init_testenv_to_materialize` and `pyve test`'s default through `_test_default_env` — never re-add an eager undeclared-`testenv` path or a permissive `${PYVE_TESTENVS_DEFAULT:-testenv}` fallback. When adding a materializer, honor "empty-until-demand" (create the env; let `install`/`test` populate it) and defer conda solves to the explicit `pyve env init`. The deeper rework — making the declaration *fully* describe an env so one command reproduces it (a declarative `editable`/setup recipe, lifting the source mutex), and re-grounding the `purpose` lifecycle around which precious resource each env protects — is **Phase P**, seeded in [env-lifecycle-concept.md](env-lifecycle-concept.md); do not pre-empt it here.

### `pyve init`'s parameters are single-sourced from the decision-graph — never re-create the 4-site pattern

Every `pyve init` **parameter** (today: `backend`, `python-version`, `project-guide`, `direnv`, `env-name`) is defined **once** as a node in `_init_build_param_graph` ([`lib/plugins/python/plugin.sh`](../../lib/plugins/python/plugin.sh)), which builds the keystone parameter decision-graph via the engine [`lib/param_graph.sh`](../../lib/param_graph.sh). One node row carries the parameter's `name | owner | applicability | choices | default | flag(s) | env | required | label | help`. From that single definition the init surfaces are generated:

- **Valid-flag allow-list** — `_init_valid_flags` walks the graph (`pg_node_flags`) ⊕ the hand-listed operational toggles ⊕ `--help`, and feeds `unknown_flag_error`. Adding a parameter no longer means editing a separate allow-list.
- **Interactive wizard** — `_init_wizard` builds the graph and walks `pg_list_nodes` **in node-registration order**, dispatching each *interactive*, *applicable* node to its `_init_prompt_${name//-/_}` render callback. Prompt **order is graph data** (registration order), not source position.

Two distinctions matter. **Parameters vs. operational toggles:** only the ~5 decision-graph parameters live in the graph; the imperative toggles (`--force`, `--strict`, `--bootstrap-to`, `--node-path`, …) stay hand-parsed in the flag `case` loop — they are not parameters. **Interactivity is wizard-only:** `_init_node_is_interactive` (a predicate in the wizard layer, *not* a graph-schema field) decides which nodes are prompted; `direnv`/`env-name` are applicable to flag resolution but flag-only (never prompted). The engine is Bash-3.2-safe: indexed-array, pipe-delimited rows walked at runtime — **no `declare -A`** (see [[Bash 3.2 empty-array reads must use the `:-` default]] for the same constraint).

**Defaults are consumed from the graph; flag *parsing* deliberately is not.** `init_project` reads parameter defaults via `_init_param_default <name>` → `pg_resolve_default` (the graph node interpolates the underlying constant, e.g. `DEFAULT_PYTHON_VERSION`), so the graph is the **consumed** default channel — the live consumer the P.j manifest writer / P.k drift detector build on. But the flag **parser** stays the hand `case` loop: routing the 5 params' *resolution* through the engine would mean rewriting the load-bearing arg parser into a graph-driven tokenizer — high blast radius, modest gain — and was **dropped** (P.g.5), not deferred. Graph↔parser stay in sync via a drift-guard test (every graph param flag must have a `case` arm) plus mutual behavioral cross-checking (a flag in the graph but not the parser falls to the unknown-flag handler; a flag in the parser but not the graph is absent from the generated valid-list).

**Why:** before the keystone (Phase P / Subphase P-1), adding one `init` parameter touched ≥4 hand-synced sites — the wizard prompt, the flag `case` arm, the `unknown_flag_error` allow-list, and `show_init_help` — which silently drifted out of sync. Single-sourcing from the graph removes that whole drift class. The bespoke per-prompt rendering (ui_select interaction + side effects via dynamic scope) stays in the `_init_prompt_<name>` callbacks because it does not fit the engine's value-resolution contract (that contract serves the *non-interactive flag* surface); the graph drives node identity, order, and which nodes are prompted.

**How to apply:** to add or change an `init` parameter, edit its node in `_init_build_param_graph` — do **not** re-introduce a hand-maintained flag list, a hardcoded wizard prompt order, or a separate `--help`-only flag entry. If the parameter should be **prompted**, also (a) add a `_init_prompt_<name>` renderer (reading the wizard's `arg_*` locals, writing the caller's resolved variable via dynamic scope) and (b) add its name to `_init_node_is_interactive`; if it is **flag-only**, do neither. Keep imperative toggles out of the graph (they are not parameters). When the wizard builds the graph at runtime, any test harness that exercises `_init_wizard` / `_init_valid_flags` must source `lib/param_graph.sh` before the plugin — `setup_pyve_env` already does, mirroring `pyve.sh`'s sourcing order.

### `--yes` skips the prompt; `--force` overrides a refusal — one meaning each

Across every destructive/prompt-bearing command, the two flags mean exactly one thing each (Story P.l.1):

- **`--yes` / `-y`** = *"assent to the confirmation prompt"* — do what would happen anyway, no questions. This is the **uniform** prompt-skip flag.
- **`--force`** = *"override a safety refusal / escalate to a more destructive action."* It is **never** a prompt-skip synonym.

| Command | prompt-skip | `--force` |
|---|---|---|
| `pyve purge` | `--yes` / `-y` | deprecated prompt-skip alias (warns) |
| `pyve env purge` (no-arg sweep) | `--yes` / `-y` | deprecated prompt-skip alias (warns) |
| `pyve env prune` | `--yes` / `-y` | deprecated prompt-skip alias (warns) |
| `pyve env sync` | `--yes` / `-y` (non-destructive changes) | escalate — *also* apply destructive drops/backend flips |
| `pyve init` | — (never prompts on defaults; use `--yes` for the wizard, P.j) | override "already initialized" → purge-and-rebuild the **root** env |
| `pyve env init [<name>]` | `--yes` / `-y` (assents to the rebuild prompt) | escalate — one-shot purge-and-rebuild of that named env (P.l.5) |

The deprecated `--force`-as-prompt-skip on the purge family still works for one release, emitting `warn_force_prompt_skip_deprecated` ([lib/ui/core.sh](../../lib/ui/core.sh)); non-TTY / CI invocations skip the prompt automatically regardless. `--force` is **never required** to purge — it only skips a prompt you would otherwise answer.

**Why:** `--force` had drifted into two unrelated jobs — "skip the prompt" (purge/prune) and "override/escalate" (sync/init) — and `pyve purge` accepted `--yes` and `--force` as redundant synonyms. One flag with two meanings is unlearnable; a reader could not tell whether `--force` was consent or escalation without reading the code.

**How to apply:** when adding a command that can prompt before a destructive step, wire the prompt-skip to `--yes` / `-y` and route it through the shared confirm gate. Reserve `--force` for a genuinely *stronger* action than the default (one the tool would otherwise refuse), and document that difference in the same breath — never add `--force` as a second name for `--yes`.

### An `[env.<name>]` block is a composable setup recipe — one command reproduces the env

From v3.1 (Stories P.l.2–P.l.6), an `[env.<name>]` block declares **how the environment is set up**: a composable recipe of **setup directives** — `editable` (editable self-install + extras), `requirements` (files), `extra` (an optional-dependencies group), `manifest` (the conda base). The old `requirements ⊕ extra ⊕ manifest` mutex is **lifted** for `pyve.toml`; directives layer and materialize in one fixed order: conda `manifest` → `editable` → `requirements` → `extra`. Both materializers ([`_env_install_venv`](../../lib/commands/env.sh) and [`_env_install_conda`](../../lib/commands/env.sh)) validate the whole recipe up front (files exist, extra resolves) so a bad directive fails before any layer installs, then realize every declared directive. `pyve env init <name>` materializes the full recipe one-shot ("init installs what you declared, nothing you didn't" — no directives → empty env, and the `pyve env install` fallback chain never fires from init); `pyve env init <name> --force` is the single rebuild verb (purge + re-create + re-materialize). Role routing is fixed: `root` rebuilds via `pyve init --force` (root-only by contract), named envs via `pyve env init <name> --force` — and `assert_env_name_actionable` signposts the right verb on every `pyve env <verb> root` rejection.

**Why:** the field case (ml-datarefinery) needed four commands — two of them imperative — to rebuild a test env, because the declaration could not express an editable self-install and the mutex forbade layering it beside `requirements-dev.txt`. A declaration that fully describes the env collapses rebuild to one command and is the foundation Pillar-II state restore (P.n) and future heal actions build on. The v2 `[tool.pyve.testenvs.*]` surface intentionally keeps its historical pick-one rule — composition is a `pyve.toml` capability, not a v2 retrofit.

**How to apply:** when adding a new setup capability to env blocks, add it as a **declarative directive** (closed vocabulary in [`lib/pyve_toml_helper.py`](../../lib/pyve_toml_helper.py)'s `KNOWN_ENV_KEYS` + a `manifest.sh` accessor + a slot in the fixed order), never as a shell-step list or an imperative flag. When adding a materializer (new backend), follow the shape: validate the whole recipe first, then realize directives in the fixed order; CLI `-r` stays a pip-layer-only override. Do not re-introduce a source mutex, and do not make `pyve env init` install anything the block doesn't declare.
