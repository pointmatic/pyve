# tech_spec.md — Pyve (Bash)

This document defines **how** Pyve is built — architecture, module layout, dependencies, function signatures, and cross-cutting concerns. For requirements and scope, see `features.md`. For the implementation plan, see `stories.md`.

---

## Runtime & Tooling

| Item | Value |
|------|-------|
| **Language** | Bash (4.x+) |
| **Shell mode** | `set -euo pipefail` |
| **Platforms** | macOS (zsh default shell, BSD userland), Linux (Ubuntu, GNU userland) |
| **Package manager** | N/A (single script + sourced libraries, no package registry) |
| **Linter** | ShellCheck |
| **Test runners** | Bats (unit), pytest (integration) |
| **CI** | GitHub Actions |
| **Coverage** | Codecov (via pytest-cov) |

---

## Dependencies

### Runtime Dependencies (must be pre-installed)

| Dependency | Purpose | Required? |
|------------|---------|-----------|
| Bash 4.x+ | Script execution | Yes |
| asdf **or** pyenv | Python version management | One required |
| direnv | Auto-activation of environments | Required for `--init` (skip with `--no-direnv`) |
| micromamba | Conda-compatible environment backend | Only for micromamba backend |
| grep, sed, awk, mktemp, mv | Standard POSIX utilities | Yes |

### Development Dependencies (`requirements-dev.txt`)

| Package | Purpose |
|---------|---------|
| pytest | Integration test runner |
| pytest-cov | Coverage reporting |
| pytest-xdist | Parallel test execution |
| bats-core | Unit test runner (installed via brew/apt) |
| shellcheck | Shell script linter (installed via brew/apt) |
| black | Python code formatter (lint check) |
| flake8 | Python style checker (lint check) |

---

## Package Structure

```
pyve/
├── pyve.sh                          # Thin entry point — globals, sourcing, top-level dispatcher, legacy/unknown flag catches, main()
├── lib/
│   ├── utils.sh                     # Logging, prompts, .gitignore management, config parsing, validation
│   ├── ui.sh                        # Unified UX helpers (colors, symbols, prompts, run_cmd, banners) — backportable to gitbetter
│   ├── env_detect.sh                # Shell profile sourcing, version manager detection (asdf/pyenv), is_asdf_active gate, direnv check
│   ├── backend_detect.sh            # Backend auto-detection from project files, backend validation
│   ├── micromamba_core.sh           # Micromamba binary detection, version, location
│   ├── micromamba_env.sh            # Environment file parsing, naming, creation, lock file validation
│   ├── micromamba_bootstrap.sh      # Micromamba download and installation (interactive + auto)
│   ├── distutils_shim.sh            # Python 3.12+ distutils compatibility shim (sitecustomize.py)
│   ├── version.sh                   # Version comparison, installation validation, config writing
│   └── commands/                    # One file per top-level command; each defines a function with the same name as the file
│       ├── init.sh                  # init() — full project initialization (both backends)
│       ├── purge.sh                 # purge() — removal of pyve artifacts
│       ├── update.sh                # update() — non-destructive upgrade (config + managed files + project-guide)
│       ├── check.sh                 # check() — diagnostics with 0/1/2 exit codes
│       ├── status.sh                # status() — read-only project state dashboard
│       ├── lock.sh                  # lock() — conda-lock wrapper (micromamba only)
│       ├── run.sh                   # run() — execute command in project environment
│       ├── test.sh                  # test() — pytest in dev/test environment
│       ├── testenv.sh               # testenv() dispatcher + testenv_init/install/purge/run
│       ├── python.sh                # python() dispatcher + python_set/python_show
│       └── self.sh                  # self() dispatcher + self_install/self_uninstall
├── tests/
│   ├── unit/                        # Bats unit tests (white-box, one file per lib module)
│   │   ├── test_utils.bats
│   │   ├── test_backend_detect.bats
│   │   ├── test_config_parse.bats
│   │   ├── test_distutils_shim.bats
│   │   ├── test_env_naming.bats
│   │   ├── test_lock_validation.bats
│   │   ├── test_micromamba_bootstrap.bats
│   │   ├── test_micromamba_core.bats
│   │   ├── test_reinit.bats
│   │   └── test_version.bats
│   ├── integration/                 # pytest integration tests (black-box, one file per workflow)
│   │   ├── conftest.py              # Shared fixtures (temp dirs, pyve runner)
│   │   ├── test_venv_workflow.py
│   │   ├── test_micromamba_workflow.py
│   │   ├── test_auto_detection.py
│   │   ├── test_bootstrap.py
│   │   ├── test_cross_platform.py
│   │   ├── test_reinit.py
│   │   ├── test_run_command.py
│   │   └── test_testenv.py
│   ├── helpers/
│   │   ├── test_helper.bash         # Bats helper (setup, teardown, assertions, sources all lib modules)
│   │   └── pyve_test_helpers.py     # pytest helper (PyveRunner, temp project scaffolding)
│   └── fixtures/                    # Test data (sample environment.yml, conda-lock.yml, etc.)
├── docs/
│   ├── guides/
│   │   └── project_guide.md         # LLM-assisted project creation workflow
│   └── specs/
│       ├── features.md              # Requirements (what)
│       ├── tech_spec.md             # Architecture (how) — this file
│       ├── stories.md               # Implementation plan (when)
│       ├── testing_spec.md          # Testing strategy details
│       └── pyve-run-examples.md     # Usage examples for pyve run
├── .github/workflows/
│   └── test.yml                     # CI pipeline (unit, integration, micromamba, lint, coverage)
├── Makefile                         # Convenience targets (test, test-unit, test-integration, coverage)
├── pytest.ini                       # pytest configuration (markers, coverage, output)
├── requirements-dev.txt             # Python dev dependencies
├── LICENSE                          # Apache-2.0
├── README.md                        # User documentation
└── CONTRIBUTING.md                  # Contribution guidelines
```

---

## Key Component Design

### `pyve.sh` — Thin Entry Point

`pyve.sh` is a small, focused dispatcher (~200–300 lines target). It owns process-wide concerns and command routing; it does **not** own command implementations. Top-level command logic lives in `lib/commands/<name>.sh` (see next subsection).

**What lives in `pyve.sh`:**

- Shebang, copyright/SPDX header, `set -euo pipefail`.
- Process-wide globals (see table below).
- The library sourcing block (helpers first, then commands).
- Universal flag handling: `--help` / `-h`, `--version` / `-v`, `--config` / `-c`.
- The top-level `case`-block dispatcher that maps a subcommand name to its `lib/commands/*.sh` function.
- `legacy_flag_error()` — the Category B hard-error catcher for renamed/removed flags and subcommands. Three lines per catch arm; emits a precise migration error and exits non-zero.
- `unknown_flag_error()` — closest-match suggestion for typos within a valid subcommand (uses `_edit_distance()` from `lib/ui.sh`).
- `main()` — entry point that drives universal-flag handling, legacy/unknown-flag catches, and dispatcher invocation in that order.

**What does NOT live in `pyve.sh`:**

- Command implementations (`init`, `purge`, `update`, `check`, `status`, `lock`, `run`, `test`, `testenv`, `python`, `self`) — these live in `lib/commands/<name>.sh`.
- Cross-command helpers (`.gitignore` writing, config parsing, backend detection, etc.) — these live in their existing `lib/<helper>.sh` modules.

**Key globals:**

| Variable | Default | Purpose |
|----------|---------|---------|
| `VERSION` | `"2.3.2"` | Current Pyve version |
| `DEFAULT_PYTHON_VERSION` | `"3.14.3"` | Default Python version for new environments |
| `DEFAULT_VENV_DIR` | `".venv"` | Default venv directory name |
| `ENV_FILE_NAME` | `".env"` | Environment variables filename |
| `TESTENV_DIR_NAME` | `"testenv"` | Dev/test runner environment directory |

**Library sourcing order (helpers first, then commands).** Helpers: `utils.sh` → `ui.sh` → `env_detect.sh` → `backend_detect.sh` → `micromamba_core.sh` → `micromamba_env.sh` → `micromamba_bootstrap.sh` → `distutils_shim.sh` → `version.sh`. `ui.sh` is sourced early so later modules can use its color/symbol constants and banner helpers. Commands are sourced after all helpers, in alphabetical order: `commands/check.sh` → `commands/init.sh` → `commands/lock.sh` → `commands/purge.sh` → `commands/python.sh` → `commands/run.sh` → `commands/self.sh` → `commands/status.sh` → `commands/test.sh` → `commands/testenv.sh` → `commands/update.sh`. Sourcing is **explicit**, not glob-based, so dependency ordering is auditable. (The Phase-H-era `deprecation_warn` helper was removed in Story J.d when the last Category A delegation paths were ripped; see the Category B `legacy_flag_error` pattern above for the remaining hard-error form.)

Each library and command file guards against direct execution and is designed to be sourced only.

---

### `lib/commands/<name>.sh` — Command Implementations

One file per top-level command. Each file owns the implementation of its command and follows a uniform contract.

**File-to-function contract:**

- `lib/commands/<name>.sh` defines a top-level function named `<name>` that takes the subcommand's positional + flag arguments. The dispatcher in `pyve.sh` calls it with `"$@"` after stripping the subcommand token.
- **Namespace commands** (`testenv`, `python`, `self`) define the namespace dispatcher *and* the leaf functions in the same file. Leaf functions use the `<namespace>_<leaf>` naming convention:
  - `lib/commands/testenv.sh` → `testenv()`, `testenv_init()`, `testenv_install()`, `testenv_purge()`, `testenv_run()`
  - `lib/commands/python.sh` → `python()`, `python_set()`, `python_show()`
  - `lib/commands/self.sh` → `self()`, `self_install()`, `self_uninstall()`
- **Command-private helpers** stay inside the command file with a `_<command>_` prefix (e.g., `_init_write_envrc()`, `_check_run_diagnostics()`). They are not callable from other commands.
- **Cross-command helpers** (used by two or more commands) live in their existing `lib/<helper>.sh` home — they do NOT migrate into `lib/commands/`. Examples: `write_gitignore_template()` in `lib/utils.sh`, `is_asdf_active()` in `lib/env_detect.sh`, `get_backend_priority()` in `lib/backend_detect.sh`, `header_box()` in `lib/ui.sh`.

**Direct-execution guard.** Each command file ends (or begins) with the same guard the helper modules use, so a stray `bash lib/commands/init.sh` exits non-zero rather than running unsourced.

**Per-command function tables** are documented in this section as the extraction phase progresses — each story that extracts a command appends its function-signature table here, mirroring the `lib/utils.sh` / `lib/ui.sh` pattern.

#### `lib/commands/run.sh` (Story K.b — v2.4.0)

| Function | Signature | Description |
|---|---|---|
| `run_command` | `(<command> [args...])` | Execute the target command inside the active project environment. Auto-detects backend by probing `.pyve/envs/*` (micromamba) then `$DEFAULT_VENV_DIR` (venv); errors out if neither exists. Pass-through args via `exec` (preserves exit codes). Story J.c: when `is_asdf_active`, exports `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` before exec to prevent asdf reshim under `--no-direnv` / CI. Venv backend prefers `<venv>/bin/<cmd>` and falls back to `$PATH` after exporting `VIRTUAL_ENV` and prepending `<venv>/bin` to `PATH`. Micromamba backend uses `micromamba run -p <env_path>`. |

No private helpers — `run_command` is self-contained and calls only cross-command helpers (`source_shell_profiles`, `detect_version_manager`, `is_asdf_active`, `get_micromamba_path`, `log_error`).

#### `lib/commands/lock.sh` (Story K.c — v2.4.0)

| Function | Signature | Description |
|---|---|---|
| `lock_environment` | `([--check])` | Generate or verify `conda-lock.yml` (micromamba projects only). Default mode: invoke `conda-lock -f environment.yml -p <platform>`, filter the misleading "conda-lock install" post-run message, detect "spec hash already locked" → "already up to date" output, otherwise emit success + `pyve init --force` rebuild hint. `--check` mode: pure mtime comparison via `is_lock_file_stale`, never invokes `conda-lock`, suitable as a CI gate. Three guards run before `conda-lock`: (1) refuses venv backend, (2) requires `environment.yml`, (3) requires `conda-lock` on `$PATH`. |

No private helpers — `lock_environment` is self-contained and calls only cross-command helpers (`config_file_exists`, `read_config_value`, `unknown_flag_error`, `log_error`, `log_info`, `is_lock_file_stale`, `get_conda_platform`).

**Renamed from `run_lock`** in K.c. Final name `lock_environment()` adopted in the K.f follow-up under the project-essentials "Function naming convention: `<verb>_<operand>`" rule — `pyve lock` operates on the environment's dependency graph (`environment.yml` → `conda-lock.yml`). The K.c interim name `lock()` was a rule violation (no operand suffix) and was retired alongside K.e's `self()`. No external callers — only the dispatcher arm referenced the function name.

#### `lib/commands/python.sh` (Story K.d — v2.4.0)

First namespace extraction. Single-file convention per project-essentials F-9: dispatcher + leaves all live in `lib/commands/python.sh`.

| Function | Signature | Description |
|---|---|---|
| `python_command` | `(<sub> [args...])` | Namespace dispatcher. Sub-commands: `set`, `show`. Empty arg or unknown sub-command exits 1 with an actionable usage message. The `--help` intercept happens in `pyve.sh`'s case dispatcher (calls `show_python_help`); this function never sees `--help`. |
| `python_set` | `(<version>)` | Pin the Python version via the active version manager. Validates format (`X.Y.Z`); detects asdf/pyenv via `detect_version_manager`; ensures the version is installed (may invoke an asdf/pyenv install); writes to `.tool-versions` (asdf) or `.python-version` (pyenv) via `set_local_python_version`. Header/footer-boxed UI. |
| `python_show` | `()` | Read-only. Resolves the pinned version from (in priority order) `.tool-versions`, `.python-version`, `.pyve/config:python.version`. Prints `Python <ver> (from <source>)` or a "not pinned" message. Never installs or modifies anything. The `python show <extra-args>` rejection happens in the dispatcher, not here. |

**Renamed from `set_python_version_only` / `show_python_version`** in K.d so leaf names follow the `<namespace>_<leaf>` convention. The dispatcher **stays `python_command`** (NOT renamed to `python`) because `python` is the bare interpreter binary that pyve invokes internally for venv creation (`python -m venv .venv`, `python -c 'import sys; ...'`). A bash function named `python` would shadow the binary at those callsites — discovered the hard way during K.d's first attempt; the revert and the resulting "Function-name collision rule" in `project-essentials.md` are mandatory reading before naming any future top-level dispatcher (notably K.f, where `test_command` similarly stays unchanged to avoid shadowing the bash builtin).

#### `lib/commands/self.sh` (Story K.e — v2.4.0)

Single-file namespace per project-essentials F-9. Largest extraction so far (~458 lines) but every function is self-namespace-private — no cross-command coupling, no helpers move to `lib/utils.sh`. Resolves K.a.3 audit finding F-5: `install_prompt_hook` (and its `uninstall_prompt_hook` sibling) are **self-private**, not init-private; both move with K.e.

| Function | Signature | Description |
|---|---|---|
| `self_command` | `(<sub> [args...])` | Namespace dispatcher. Sub-commands: `install`, `uninstall`. No-arg invocation prints `show_self_help` and returns 0. Each sub-command honors `--help` (calls the matching help block) and `PYVE_DISPATCH_TRACE` (prints `DISPATCH:self-<sub>` and returns) before delegating to the leaf. Unknown sub-commands exit 1 after printing the namespace help. |
| `self_install` | `()` | Install pyve to `~/.local/bin`. Homebrew-managed installs short-circuit with brew-specific guidance (exit 0). Reinstall from the installed location re-execs the source pyve.sh to avoid rewriting the running script. Steps: copy `pyve.sh`, `lib/*.sh`, `lib/commands/*.sh` (Phase K), `lib/completion/*`; record `~/.local/.pyve_source`; create `~/.local/bin/pyve` symlink; wire PATH (`_self_install_update_path`); install prompt hook (`_self_install_prompt_hook`); create `~/.local/.env` template (`_self_install_local_env_template`). Idempotent (re-install is safe). |
| `self_uninstall` | `()` | Reverse of `self_install`. Homebrew-managed installs short-circuit. Removes the symlink, script, `lib/`, the source-dir record file. Preserves a non-empty `~/.local/.env` (warn-and-skip); removes it when empty. Calls `_self_uninstall_prompt_hook`, `_self_uninstall_clean_path`, `_self_uninstall_project_guide_completion` to clean rc files. |
| `_self_install_update_path` | `()` | Append the `export PATH="$HOME/.local/bin:$PATH" # Added by pyve installer` line to `~/.zprofile` (zsh) or `~/.bash_profile` (bash). No-ops if `~/.local/bin` is already on `$PATH` or the marker comment is already present in the profile. |
| `_self_install_prompt_hook` | `()` | Write `~/.local/.pyve_prompt.sh` (a zsh/bash-aware prompt customizer that honors `$PYVE_PROMPT_PREFIX`) and source it from `~/.zshrc` (zsh) or `~/.bashrc` (bash) via the SDKMan-aware insertion helper. Idempotent — strips any prior `source` line for the same hook file before re-inserting, so re-installs don't accumulate duplicates. |
| `_self_install_local_env_template` | `()` | Create an empty `~/.local/.env` with `chmod 600` if it doesn't exist. No-op if the file is already present (preserves user data). |
| `_self_uninstall_prompt_hook` | `()` | Strip the `source $PROMPT_HOOK_FILE` line from both `~/.zshrc` and `~/.bashrc` (covers users who switched shells post-install) using portable `sed -i` (macOS-vs-Linux dialect via `uname` check). Removes the prompt-hook file itself last. |
| `_self_uninstall_clean_path` | `()` | Strip the `# Added by pyve installer` PATH line from both `~/.zprofile` and `~/.bash_profile` using portable `sed -i`. |
| `_self_uninstall_project_guide_completion` | `()` | Remove the project-guide completion sentinel block from both `~/.zshrc` and `~/.bashrc` via the shared `remove_project_guide_completion` helper. Safe no-op when the block is absent. |

**Renames in K.e** (audit-recommended, all callsites internal to the namespace):
- `install_self` → `self_install`, `uninstall_self` → `self_uninstall` (matches `<namespace>_<leaf>` convention).
- `self_command` was briefly renamed to `self()` in the K.e initial pass; **reverted back to `self_command()` in the K.f follow-up** under the project-essentials "Function naming convention: `<verb>_<operand>`" rule (namespace dispatchers use `<namespace>_command` because the operand is the sub-command name).
- 6 private helpers gain the `_self_` prefix per project-essentials F: `install_update_path`, `install_prompt_hook`, `install_local_env_template`, `uninstall_project_guide_completion`, `uninstall_clean_path`, `uninstall_prompt_hook` → `_self_install_*` / `_self_uninstall_*`.

**F-9 reminder:** the three help blocks (`show_self_help`, `show_self_install_help`, `show_self_uninstall_help`) stay in `pyve.sh` for v2.4.0 and are called from `self()` via cross-file lookup. Bash resolves these at call time, not at sourcing time, so the order (lib/commands sourced before help blocks are defined) is not a problem.

#### `lib/commands/test.sh` (Story K.f — v2.4.0)

| Function | Signature | Description |
|---|---|---|
| `test_tests` | `([pytest args...])` | Run pytest via the dev/test runner environment. Auto-creates the testenv (via `ensure_testenv_exists`) if missing. If pytest isn't yet installed: in CI / `PYVE_TEST_AUTO_INSTALL_PYTEST=1` mode, auto-installs it; on a TTY, prompts y/N (declining exits 1); non-TTY without auto-install, errors with the `pyve testenv install -r requirements-dev.txt` next-step. Finally `exec`s `<testenv>/bin/python -m pytest "$@"` so pytest's exit code propagates verbatim. |
| `_test_has_pytest` | `(<testenv_venv>)` → 0/1 | Probe whether the testenv at `<testenv_venv>` has pytest installed. Returns 1 if `bin/python` is missing, otherwise 0/1 from `python -c 'import pytest'`. |
| `_test_install_pytest_into_testenv` | `(<testenv_venv>)` | Pip-install pytest (or `requirements-dev.txt` if present) into the testenv via `<testenv_venv>/bin/python -m pip install ...`. |

**Function name `test_tests` (NOT `test` or `test_command`)** — applies the project-essentials "Function naming convention: `<verb>_<operand>`" rule: `pyve test [args]` operates on tests (whether the args explicitly select a subset or are absent, in which case the implicit operand is "all tests"). This naming also avoids the F-11 `test` shadowing trap (`test` is a bash builtin / `/usr/bin/test`); the K.f initial extraction used `test_command()` (also F-11-safe) but was renamed in the same K.f follow-up that aligned `lock_environment()` and reverted `self_command()`.

**Cross-file call (intentional, K.f → K.g window):** `test_command` calls `ensure_testenv_exists`, which still lives in `pyve.sh` between K.f and K.g. Bash resolves the call at runtime via the global function table, so the cross-file boundary is invisible. K.g moves `ensure_testenv_exists` to `lib/utils.sh`; no edit to `lib/commands/test.sh` is needed at that time.

**F-8 correction:** the K.f story's "Temporary cross-file call to `testenv_run`" caveat is stale — there is no `testenv_run` function in `pyve.sh`. `test_command` does NOT call `testenv_run`; it calls `ensure_testenv_exists`, the test-private helpers, and ends with `exec ... pytest`. The `testenv` namespace handles its own `run` action inline in the namespace dispatcher (see K.g).

#### `lib/commands/testenv.sh` (Story K.g — v2.4.0)

Largest namespace command — 4 leaves: `init`, `install`, `purge`, `run`. The K.g extraction also refactored the previous inline `case "$action" in` arms into named leaf functions per project-essentials F-9 (one function per sub-command, leaf names follow `<namespace>_<leaf>`).

| Function | Signature | Description |
|---|---|---|
| `testenv_command` | `(<sub> [args...])` | Namespace dispatcher. Sub-commands: `init`, `install [-r <file>]`, `purge`, `run <cmd> [args...]`. Pre-parses `-r`/`--requirements` and the action token, then calls the matching leaf. The `run` action skips the `header_box`/`footer_box` wrapper because exec replaces the shell — the called command owns the rest of the terminal. `--help` and unknown-flag/unknown-action paths exit before the leaf is reached. |
| `testenv_init` | `()` | Thin wrapper around `ensure_testenv_exists` (now in `lib/utils.sh`). |
| `testenv_install` | `(<testenv_venv> <requirements_file?>)` | Pip-install dependencies into the testenv. Without `<requirements_file>`, installs bare `pytest`. With `<requirements_file>`, validates the file exists, then `pip install -r <file>`. Errors with exit 1 if the testenv doesn't exist (caller must `pyve testenv init` first) or the requirements file is missing. |
| `testenv_purge` | `()` | Thin wrapper around `purge_testenv_dir` (now in `lib/utils.sh`). |
| `testenv_run` | `(<testenv_venv> [<cmd> args...])` | `exec` a command inside the testenv. Prefers `<testenv_venv>/bin/<cmd>` when present; otherwise falls back to `$PATH` after exporting `VIRTUAL_ENV` and prepending `<testenv_venv>/bin` to `PATH`. Errors with exit 1 if no command is provided or the testenv doesn't exist. |

**F-7 / F-8 helper moves (K.g performs):** `purge_testenv_dir`, `ensure_testenv_exists`, and `testenv_paths` move from `pyve.sh` to `lib/utils.sh` because they are each shared by 2+ commands (per project-essentials cross-command-helper rule):

- `ensure_testenv_exists` — used by `init` (still in pyve.sh), `testenv_init`, and `test_tests` (in `lib/commands/test.sh`).
- `purge_testenv_dir` — used by `purge` (still in pyve.sh) and `testenv_purge`.
- `testenv_paths` — only called by `ensure_testenv_exists`; moves alongside it as an implementation dependency.

After K.g, `lib/commands/test.sh::test_tests` no longer makes a cross-file call back into `pyve.sh` — the call to `ensure_testenv_exists` resolves through `lib/utils.sh` (already sourced by `pyve.sh` before the per-command files).

**Function name `testenv_command`** — applies the project-essentials "Function naming convention" rule: namespace dispatchers use `<namespace>_command` because the operand is the sub-command name that follows. No K.e-style `testenv()` rename — the rule was tightened during K.f follow-up.

#### `lib/commands/status.sh` (Story K.h — v2.4.0)

Read-only state dashboard. Three sections (Project / Environment / Integrations) plus a non-project fallback. By contract, never returns a non-zero exit code based on findings — that's `pyve check`'s job; `status` reports reality, where "not a pyve project" is also a valid reality. The orchestrator and 9 status-private helpers all move together.

| Function | Signature | Description |
|---|---|---|
| `show_status` | `()` | Orchestrator. Validates no flags / no positional args (errors out otherwise), prints title + divider, then either the non-project fallback or the three sections. Always returns 0 on a valid invocation. |
| `_status_row` | `(<label> <value>)` | Print one key/value row with a 17-char label column (matches the widest label `environment.yml:`) so all sections align visually. |
| `_status_header` | `(<text>)` | Print a BOLD section header. |
| `_status_section_project` | `()` | Project section: path, backend, recorded `pyve_version` (with drift comparison vs. running `$VERSION` via `compare_versions`), and configured Python. |
| `_status_configured_python` | `()` → string | Resolve and format the configured Python version source — `.tool-versions via asdf`, `.python-version via pyenv`, or `.pyve/config`. Returns `"not pinned"` when none are present. |
| `_status_section_environment` | `()` | Environment section header + dispatch to `_status_env_venv` or `_status_env_micromamba` based on configured backend. |
| `_status_env_venv` | `()` | Venv-backend rows: path, Python version, package count (via `_status_venv_package_count`), distutils shim status. |
| `_status_venv_package_count` | `(<venv_dir>)` → string | Count `*.dist-info` directories under `<venv_dir>/lib/python*/site-packages/`; returns "N installed" or "unknown". `find`-pipefail safe. |
| `_status_env_micromamba` | `()` | Micromamba-backend rows: name, path, Python, package count via `conda-meta`, `environment.yml` presence, `conda-lock.yml` freshness via `is_lock_file_stale`. |
| `_status_section_integrations` | `()` | Integrations section: `.envrc` presence, `.env` (with empty/non-empty distinction), `project-guide` (probes `<env>/bin/project-guide --version`), `testenv` (probes `<testenv>/bin/python -c 'import pytest'`). |

**Function name `show_status` (NOT `status_command`)** — applies the project-essentials "Function naming convention: `<verb>_<operand>`" rule. `status` is a noun, not a verb; the operation is "show the status". Semantic alignment trumps spelling alignment here.

**No private-helper rename** — all 9 helpers already follow the `_status_*` prefix convention from when they were inlined in `pyve.sh` (Story H.e.4). They stay named exactly as-is; only the orchestrator was renamed.

**Cross-command helpers (lib/) used:** `config_file_exists`, `read_config_value`, `is_file_empty` (lib/utils.sh); `compare_versions` (lib/version.sh); `is_lock_file_stale` (lib/micromamba_env.sh); `unknown_flag_error`, `log_error` (pyve.sh / lib/utils.sh). Reads `BOLD`, `DIM`, `RESET` color globals (defined in lib/ui.sh) and `PYVE_DISTUTILS_SHIM_MARKER` (defined in lib/distutils_shim.sh).

---

### `lib/utils.sh` — Core Utilities

Logging, user prompts, `.gitignore` management, config file parsing, and input validation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `log_info` | `(message)` | Print `INFO: <message>` to stdout |
| `log_warning` | `(message)` | Print `WARNING: <message>` to stderr |
| `log_error` | `(message)` | Print `ERROR: <message>` to stderr |
| `log_success` | `(message)` | Print `✓ <message>` to stdout |
| `prompt_yes_no` | `(prompt)` → 0/1 | Prompt user for y/n confirmation |
| `prompt_install_pip_dependencies` | `(backend?, env_path)` → 0/1 | Prompt to install pip dependencies from `pyproject.toml` or `requirements.txt`. `env_path` is required for both backends: venv uses `$env_path/bin/pip`; micromamba uses `micromamba run -p $env_path pip`. Returns 1 if `env_path` is missing or pip is not found. |
| `gitignore_has_pattern` | `(pattern)` → 0/1 | Check if exact line exists in `.gitignore` |
| `append_pattern_to_gitignore` | `(pattern)` | Append pattern if not already present |
| `insert_pattern_in_gitignore_section` | `(pattern, section_comment)` | Insert pattern after section comment; falls back to append |
| `remove_pattern_from_gitignore` | `(pattern)` | Remove exact line match from `.gitignore` |
| `write_gitignore_template` | `()` | Rebuild Pyve-managed template section, preserving user entries |
| `write_envrc_template` | `(rel_bin_dir, sentinel_var, rel_env_root, backend_name, env_name)` | Emit the uniform v2.3.2 `.envrc` template shared by every backend (v2.3.2 / Story K.a.2). Skips the write when `.envrc` already exists; always tops up the asdf reshim guard when `is_asdf_active`. See "Uniform `.envrc` template" under Cross-Cutting Concerns. |
| `read_config_value` | `(key)` → string | Read value from `.pyve/config` (supports dotted keys) |
| `config_file_exists` | `()` → 0/1 | Check if `.pyve/config` exists |
| `validate_venv_dir_name` | `(dirname)` → 0/1 | Reject empty, reserved names, invalid characters |
| `validate_python_version` | `(version)` → 0/1 | Validate `#.#.#` semver format |
| `is_file_empty` | `(filename)` → 0/1 | Returns 0 if file is empty or missing |
| `check_cloud_sync_path` | `()` | Hard fail if `$PWD` is inside a known cloud-synced directory; bypassed by `PYVE_ALLOW_SYNCED_DIR=1` |
| `write_vscode_settings` | `(env_name)` | Write `.vscode/settings.json` with interpreter path and IDE isolation settings; skips if exists unless `PYVE_REINIT_MODE=force` |
| `doctor_check_duplicate_dist_info` | `(env_path)` | Scan `site-packages` for duplicate `.dist-info` dirs; reports conflicting versions with mtimes. (Name retained for backport continuity; reused by `check_command` in v2.0.) |
| `doctor_check_collision_artifacts` | `(env_path)` | Scan environment tree for files/dirs with ` 2` suffix (iCloud Drive collision artifacts). Reused by `check_command`. |
| `doctor_check_native_lib_conflicts` | `(env_path)` | Detect conda/pip OpenMP conflicts: pip-bundled libs (torch/tf/jax) + conda-linked libs (numpy/scipy) + missing `libomp.dylib`/`libgomp.so`. Reused by `check_command`. |
| `doctor_check_venv_path` | `(env_path)` | Detect relocated venv: compare `pyvenv.cfg` creation path against actual venv location; warn with remediation if mismatched. Reused by `check_command`. |

**`.gitignore` template structure:**
```
# macOS only
.DS_Store

# Python build and test artifacts
__pycache__
*.egg-info
.coverage
coverage.xml
htmlcov/
.pytest_cache/

# Pyve virtual environment
<dynamically inserted entries: .venv, .env, .envrc, .pyve/testenv, .pyve/envs, .vscode/settings.json>
```

The template is written via heredoc. User entries below the template are preserved. Deduplication prevents template lines from appearing in the user section.

---

### `lib/env_detect.sh` — Environment Detection

Version manager detection, Python version management, and direnv checks.

| Function | Signature | Description |
|----------|-----------|-------------|
| `source_shell_profiles` | `()` | Initialize asdf/pyenv in non-interactive shells |
| `detect_version_manager` | `()` → sets `VERSION_MANAGER` | Detect asdf (preferred) or pyenv; sets global |
| `is_python_version_installed` | `(version)` → 0/1 | Check if version is installed via current manager |
| `is_python_version_available` | `(version)` → 0/1 | Check if version is available to install |
| `install_python_version` | `(version)` → 0/1 | Install Python version via asdf or pyenv |
| `ensure_python_version_installed` | `(version)` → 0/1 | Install if not present, verify after |
| `set_local_python_version` | `(version)` → 0/1 | Write `.tool-versions` (asdf) or `.python-version` (pyenv) |
| `get_version_file_name` | `()` → string | Returns `.tool-versions` or `.python-version` |
| `check_direnv_installed` | `()` → 0/1 | Check if direnv is in PATH |

---

### `lib/backend_detect.sh` — Backend Detection

Determine which environment backend to use based on CLI flags, config, and project files.

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_backend_from_files` | `()` → string | Returns `"venv"`, `"micromamba"`, or `"none"` from project files |
| `get_backend_priority` | `(cli_backend, skip_config?)` → string | Resolve backend using priority chain: CLI > config (skipped when `skip_config=true`) > files > default; prompts interactively in ambiguous cases (both conda and Python files present) |
| `validate_backend` | `(backend)` → 0/1 | Validate backend value is `venv`, `micromamba`, or `auto` |
| `validate_config_file` | `()` → 0/1 | Validate `.pyve/config` structure |

---

### `lib/micromamba_core.sh` — Micromamba Binary Management

Locate and query the micromamba binary.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get_micromamba_path` | `()` → string | Search: `.pyve/bin/` > `~/.pyve/bin/` > system PATH |
| `check_micromamba_available` | `()` → 0/1 | Check if micromamba is found anywhere |
| `get_micromamba_version` | `()` → string | Return version string (e.g., `"1.5.3"`) |
| `get_micromamba_location` | `()` → string | Return `"project"`, `"user"`, `"system"`, or `"not_found"` |
| `error_micromamba_not_found` | `(context)` | Print error with installation instructions |

---

### `lib/micromamba_env.sh` — Micromamba Environment Management

Environment file parsing, naming resolution, environment creation, and lock file validation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_environment_file` | `()` → string | Return `conda-lock.yml` or `environment.yml` path |
| `parse_environment_name` | `(env_file?)` → string | Extract `name:` field from environment.yml |
| `parse_environment_channels` | `(env_file?)` → string | Extract channels list |
| `validate_environment_file` | `()` → 0/1 | Check environment file exists and is readable |
| `is_lock_file_stale` | `()` → 0/1 | Compare mtimes of environment.yml vs conda-lock.yml |
| `validate_lock_file_status` | `(strict_mode)` → 0/1 | Full lock file validation with user prompts |
| `sanitize_environment_name` | `(raw_name)` → string | Lowercase, replace special chars, trim hyphens |
| `is_reserved_environment_name` | `(name)` → 0/1 | Check against reserved names list |
| `validate_environment_name` | `(name)` → 0/1 | Full name validation |
| `resolve_environment_name` | `(cli_name?)` → string | Priority: CLI > config > env file > directory basename |
| `scaffold_starter_environment_yml` | `(python_version, env_name_flag?, strict_mode)` → 0/1 | Write starter `environment.yml` when the current dir has neither an `environment.yml` nor a `conda-lock.yml` and `strict_mode` is `false`. Returns 0 on write, 1 on refusal (strict / env.yml already present / conda-lock.yml present). Called from `init()` before `check_micromamba_available` so the fresh-project path gets a scaffold-then-proceed flow instead of the H.f.6 hard-error. Template content: `name: <sanitized-basename or env_name_flag>`, `channels: [conda-forge]`, `dependencies: [python=<ver>, pip]`. H.f.7. |
| `check_micromamba_env_exists` | `(env_name)` → 0/1 | Check if `.pyve/envs/<name>` exists |
| `create_micromamba_env` | `(env_name, env_file?)` → 0/1 | Create environment from file |
| `verify_micromamba_env` | `(env_name)` → 0/1 | Verify environment is functional |
| `is_interactive` | `()` → 0/1 | Detect interactive vs CI/batch mode |

---

### `lib/micromamba_bootstrap.sh` — Micromamba Installation

Download and install micromamba binary.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get_micromamba_download_url` | `()` → string | Platform-specific download URL |
| `bootstrap_install_micromamba` | `(location)` → 0/1 | Download and install to `"project"` or `"user"` sandbox |
| `bootstrap_micromamba_interactive` | `(context?)` → 0/1 | Interactive prompt with 4 installation options |
| `bootstrap_micromamba_auto` | `(location?)` → 0/1 | Non-interactive install (default: user) |

---

### `lib/distutils_shim.sh` — Python 3.12+ Compatibility

Install a `sitecustomize.py` shim to prevent `distutils` import failures.

| Function | Signature | Description |
|----------|-----------|-------------|
| `pyve_is_distutils_shim_disabled` | `()` → 0/1 | Check `PYVE_DISABLE_DISTUTILS_SHIM` env var |
| `pyve_get_python_major_minor` | `(python_path)` → string | Return `"3.12"` etc. |
| `pyve_get_site_packages_dir` | `(python_path)` → string | Return site-packages path |
| `pyve_write_sitecustomize_shim` | `(site_packages_dir)` | Write the shim file |
| `pyve_distutils_shim_probe` | `(python_path)` | Lightweight check if shim is needed |
| `pyve_ensure_venv_packaging_prereqs` | `(python_path)` | Ensure pip, setuptools, wheel in venv |
| `pyve_ensure_micromamba_packaging_prereqs` | `(micromamba_path, env_prefix)` | Ensure pip, setuptools, wheel in micromamba env |
| `pyve_install_distutils_shim_for_python` | `(python_path)` | Full shim installation for venv |
| `pyve_install_distutils_shim_for_micromamba_prefix` | `(micromamba_path, env_prefix)` | Full shim installation for micromamba |

---

### `lib/version.sh` — Version Tracking & Validation

Version comparison, installation validation, and config file management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `compare_versions` | `(v1, v2)` → string | Return `"equal"`, `"greater"`, or `"less"` |
| `validate_pyve_version` | `()` → 0/1 | Compare recorded version with current |
| `validate_installation_structure` | `()` → 0/1 | Check `.pyve/` directory and config |
| `validate_venv_structure` | `()` → 0/1 | Check venv directory exists |
| `validate_micromamba_structure` | `()` → 0/1 | Check environment.yml and env directory |
| `write_config_with_version` | `()` | Create `.pyve/config` with current version |
| `update_config_version` | `()` | Update version in existing config |

**Note:** `run_full_validation()` was removed in v2.0 (Story H.e.8a) along with the `pyve validate` command. Its 0/1/2 exit-code semantics live on in `check_command` (see [phase-H-check-status-design.md §3.2](phase-H-check-status-design.md)).

---

### `lib/ui.sh` — Unified UI Helpers (Phase H / v2.0+)

Standalone module providing the shared terminal UX primitives used across every pyve command. Introduced in H.e (first sub-story) and adopted during H.e and H.f.

Designed for verbatim backport to the [`gitbetter`](https://github.com/pointmatic/gitbetter) project — the module contains **no pyve-specific identifiers** (no `pyve_`-prefixed names, no references to backends, `.pyve/config`, or any other pyve concept). Pyve-specific logic lives in the command scripts that call the helpers, not in the helpers themselves. The color palette and symbol set are synchronized with `gitbetter`'s `tech-spec.md` "Shared Constants & Helpers" section; changes to either side require a coordinated update.

**Module contents** (final v2.0 surface):

| Item | Signature | Description |
|------|-----------|-------------|
| Color constants | `R` `G` `Y` `B` `C` `M` `DIM` `BOLD` `RESET` | ANSI color codes; empty under `NO_COLOR=1` |
| Symbols | `CHECK` `CROSS` `ARROW` `WARN` | Pre-colorized status glyphs (`✔` `✘` `▸` `⚠`); plain glyphs under `NO_COLOR=1` |
| `banner` | `(title)` | Section banner in blue + bold |
| `info` | `(msg)` | Dimmed cyan-arrow line |
| `success` | `(msg)` | Green-check line |
| `warn` | `(msg)` | Yellow-warn line |
| `fail` | `(msg)` | Red-cross line; exits 1 |
| `confirm` | `(prompt)` → 0 on yes | `[Y/n]` prompt, default yes; clean-exits 0 on abort |
| `ask_yn` | `(prompt)` → 0/1 | `[y/N]` prompt, default no |
| `divider` | `()` | Dimmed horizontal rule |
| `run_cmd` | `(cmd args…)` | Echoes `$ cmd args…` dimmed, then executes; propagates exit code |
| `header_box` | `(title)` | Rounded-box cyan + bold header |
| `footer_box` | `()` | Rounded-box green + bold "✓ All done." footer |
| `_edit_distance` | `(s1, s2)` → int | Levenshtein distance on stdout. Consumer: `unknown_flag_error()` in `pyve.sh`. bash-3.2-safe flat-array DP. (H.e.9d.) |

**Sourcing.** `pyve.sh` sources `lib/ui.sh` alongside the other `lib/*.sh` modules so UI helpers are available before any command dispatcher runs.

**bash-3.2 compatibility guard.** `lib/ui.sh` must source cleanly under macOS's system `/bin/bash` (3.2.57). Specifically: no `declare -A` (associative arrays are bash 4+), no `${var^^}` / `${var,,}` case operators, no `readarray`. Locked in by the H.e.7a regression tests at [tests/unit/test_ui.bats](../../tests/unit/test_ui.bats) ("source contains no 'declare -A'" + `/bin/bash` sourcing test).

**Backport-discipline guard.** The module contains no pyve-specific identifiers — enforced by a grep test in `test_ui.bats`. (The colon-free rename-key invariant retired in Story J.d alongside `deprecation_warn`.)

**Delegation from existing `log_*` functions.** As of H.f.4, the `log_info` / `log_warning` / `log_error` / `log_success` helpers in `lib/utils.sh` emit the unified glyph palette (`▸` / `⚠` / `✘` / `✔`, two-space indent, stderr vs. stdout routing preserved). They do **not** currently delegate by calling `info` / `warn` / `fail` / `success` directly — `log_error` keeps its non-exiting contract (calling `fail` would change exit semantics for ~87 callers), and bats tests that source `lib/utils.sh` standalone (without `lib/ui.sh`) still need to work via `${CHECK:-✔}` / `${WARN:-⚠}` / `${CROSS:-✘}` / `${ARROW:-▸}` fallbacks. Future refactor (v3.x): collapse `log_*` to thin aliases once the non-exiting-error pattern is named and exported from `lib/ui.sh`.

**H.f backport-sync note.** H.f.1 – H.f.4 added no new helpers to `lib/ui.sh`; the retrofit consumed the palette already shipped in H.e.1. Nothing to backport to `gitbetter`'s copy from this phase.

---

## Configuration

### `.pyve/config` Format

```yaml
pyve_version: "1.1.3"
backend: venv | micromamba

micromamba:
  env_name: <name>
  env_file: environment.yml
  channels:
    - conda-forge
    - defaults
  prefix: .pyve/envs/<name>

python:
  version: "3.11"

venv:
  directory: .venv
```

Parsed by `read_config_value()` using simple `grep`/`sed` — not a full YAML parser. Supports top-level keys and one level of nesting via dotted notation (e.g., `micromamba.env_name`).

### Precedence

1. CLI flags
2. `.pyve/config`
3. Project files (`environment.yml`, `pyproject.toml`, etc.)
4. Hardcoded defaults in `pyve.sh`

---

## CLI Design

As of v1.11.0 (Story G.b.1 / FR-G1), Pyve uses a subcommand-style CLI consistent with modern developer tooling (`git`, `cargo`, `kubectl`, `gh`). The v2.0 cut (Phase H, Stories H.e.1 through H.e.9) completed the CLI-unification arc: every verb now has one canonical subcommand form; legacy flag forms error out via `legacy_flag_error` (hard error + targeted hint). Story J.d (v2.3.0) ripped the two remaining delegation-with-warning paths (`testenv --init|--install|--purge`, `python-version <ver>`); they now fall through to the standard unknown-flag / unknown-command paths. Universal flags (`--help`, `--version`, `--config`) remain as flags per CLI convention.

### Commands (v2.0 surface)

| Command | Description |
|---------|-------------|
| `pyve init [dir]` | Initialize Python virtual environment |
| `pyve purge [dir]` | Remove all Python environment artifacts |
| `pyve lock [--check]` | Generate/update `conda-lock.yml` for current platform (micromamba only) |
| `pyve run <cmd> [args]` | Execute command in project environment |
| `pyve test [args]` | Run pytest in dev/test environment |
| `pyve testenv init` | Initialize dev/test environment |
| `pyve testenv install [-r <file>]` | Install dev/test dependencies |
| `pyve testenv purge` | Remove dev/test environment |
| `pyve testenv run <cmd>` | Execute command in dev/test environment |
| `pyve check` | Diagnose environment problems (CI-safe 0/1/2 exit codes) |
| `pyve status` | Read-only project-state dashboard (always exit 0) |
| `pyve update` | Non-destructive upgrade: refresh config + managed files + project-guide; never rebuilds the venv |
| `pyve python set <ver>` | Pin the project Python version |
| `pyve python show` | Print the currently pinned Python version + its source |
| `pyve self install` | Install pyve to `~/.local/bin` |
| `pyve self uninstall` | Remove pyve from `~/.local/bin` |
| `pyve self` | Show `self` namespace help (no subcommand → namespace help only) |

**Check vs. status — invariant.** `check` and `status` are intentionally disjoint: `check` surfaces problems with severity-bearing exit codes (0/1/2) and emits one actionable remediation per failure; `status` is a read-only snapshot with always-zero exit (unless pyve itself errors). Each command's `--help` text mirrors this invariant verbatim — the help output is the user-facing contract. If a diagnostic would surface "something looks wrong", it belongs in `check`; if the answer is "what is this project?", it belongs in `status`. See [phase-H-check-status-design.md §2](phase-H-check-status-design.md) for the canonical statement.

**Removed subcommands.** `pyve doctor` and `pyve validate` were hard-removed in v2.0 (Story H.e.8a); typing either produces a migration error pointing at `pyve check`. `pyve testenv --init|--install|--purge` and `pyve python-version <ver>` were hard-removed in v2.3.0 (Story J.d); they fall through to the standard unknown-flag / unknown-command paths.

### Universal Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--version` | `-v` | Show version |
| `--config` | `-c` | Show configuration |

### Per-Subcommand Help (Story G.b.2 / FR-G4)

Every renamed subcommand responds to `--help` / `-h` with a focused, man-page-style help block:

```
pyve init --help
pyve purge --help
pyve check --help
pyve status --help
pyve update --help
pyve python --help
pyve python set --help
pyve self --help
pyve self install --help
pyve self uninstall --help
pyve testenv --help
pyve lock --help
```

The `--help` intercept fires **before** the real handler runs, so help is always fast and side-effect-free. `pyve --help` is reorganized into four categories: *Environment*, *Execution*, *Diagnostics*, *Self management*. Legacy `pyve doctor --help` / `pyve validate --help` error out like any other attempt to invoke the removed commands.

### `self` Namespace

The `self` subcommand namespace (Decision D4) groups commands that manage Pyve's own installation, mirroring `git remote` / `kubectl config`:

- `pyve self install` — copy script + lib to `~/.local/bin`, create symlink, add to PATH, create `~/.local/.env` template. Idempotent.
- `pyve self uninstall` — remove script, symlink, lib/, PATH entry. Preserve `~/.local/.env` if non-empty.
- `pyve self` (no subcommand) — print the namespace help only. Does **not** fall through to top-level help.

### Modifier Flags

All modifier flags keep their names from pre-v1.11.0 and attach to their renamed subcommands.

| Flag | Applies to | Description |
|------|-----------|-------------|
| `--backend <type>` | `pyve init` | Force backend selection |
| `--env-name <name>` | `pyve init` | Micromamba environment name |
| `--local-env` | `pyve init` | Copy `~/.local/.env` template |
| `--no-direnv` | `pyve init` | Skip `.envrc` creation |
| `--force` | `pyve init` | Purge and re-initialize |
| `--auto-bootstrap` | `pyve init` | Auto-install micromamba |
| `--bootstrap-to <loc>` | `pyve init` | Bootstrap location (project/user) |
| `--strict` | `pyve init` | Enforce lock file validation |
| `--no-lock` | `pyve init` | Bypass missing `conda-lock.yml` hard error |
| `--allow-synced-dir` | `pyve init` | Bypass cloud-synced directory check |
| `--keep-testenv` | `pyve purge` | Preserve dev/test environment |
| `--project-guide` | `pyve init` | Force project-guide hook (overrides auto-skip) |
| `--no-project-guide` | `pyve init` | Skip the project-guide hook |
| `--project-guide-completion` | `pyve init` | Force shell completion wiring |
| `--no-project-guide-completion` | `pyve init` | Skip shell completion wiring |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (missing dependency, invalid input, operation failure) |
| 2 | Warnings only (validation) |
| 127 | Command not found (`pyve run`) |

---

## Cross-Cutting Concerns

### project-guide rc-file Sentinel (v1.12.0+, Story G.c / FR-G2)

The `pyve init --project-guide-completion` hook inserts a sentinel-bracketed eval block into the user's `~/.zshrc` or `~/.bashrc`:

```bash
# >>> project-guide completion (added by pyve) >>>
command -v project-guide >/dev/null 2>&1 && \
  eval "$(_PROJECT_GUIDE_COMPLETE=zsh_source project-guide)"
# <<< project-guide completion <<<
```

The opening sentinel comment (`# >>> project-guide completion (added by pyve) >>>`) is the source of truth for idempotent insertion and removal:

- **Insertion** (`add_project_guide_completion` in `lib/utils.sh`): no-op if the sentinel is already present. Builds the eval block via an unquoted heredoc (a doubled `\\` followed by a real newline produces a proper shell line continuation in the output — see Story G.e for the v1.12.0 bug where a literal `\n` was emitted instead). Delegates the actual rc-file insertion to `insert_text_before_sdkman_marker_or_append`. Creates the rc file if missing.
- **SDKMan-aware insertion** (`insert_text_before_sdkman_marker_or_append` in `lib/utils.sh`, v1.13.1+, Story G.e): if the SDKMan end-of-file marker `#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!` is present in the rc file, the new block is inserted *immediately above* it via awk so SDKMan retains its required last-position. Otherwise the block is appended to the end. Always emits a leading blank line before the inserted block (unless the file is empty in the SDKMan-absent case), which gives `remove_project_guide_completion` a stable preceding-blank to consume and guarantees byte-identical add → remove round-trips. The same helper is used by `install_prompt_hook` (currently in `pyve.sh`; moves alongside `init`/project-guide integration during the command-module extraction phase) so the prompt hook and the completion block share one SDKMan-aware code path.
- **Removal** (`remove_project_guide_completion` in `lib/utils.sh`): removes only the sentinel-bracketed block plus one immediately-preceding blank line (so add → remove round-trips cleanly). Awk-based, BSD/GNU compatible.
- **Detection** (`is_project_guide_completion_present` in `lib/utils.sh`): a single `grep -qF` against the opening sentinel.

The sentinels must not change without a migration plan. Users who installed the block with an older sentinel would end up with orphaned blocks on uninstall.

`pyve self uninstall` calls `remove_project_guide_completion()` for both `~/.zshrc` and `~/.bashrc` to cover users who switched shells after installing the block.

### project-guide Helper Functions (v1.12.0+, Story G.c / FR-G2)

The following helpers in `lib/utils.sh` implement the three-step project-guide hook (FR-16):

| Function | Purpose |
|---|---|
| `prompt_install_project_guide` | Y/n prompt with default Y; honors `PYVE_PROJECT_GUIDE` / `PYVE_NO_PROJECT_GUIDE` / `CI` / `PYVE_FORCE_YES`. CI default = install. |
| `prompt_install_project_guide_completion` | Y/n prompt with default Y; honors `PYVE_PROJECT_GUIDE_COMPLETION` / `PYVE_NO_PROJECT_GUIDE_COMPLETION`. **CI default = SKIP** (deliberate asymmetry — editing rc files in CI is surprising). |
| `is_project_guide_installed(backend, env_path)` | Probes `<env_python> -c 'import project_guide'`. ~50ms. Returns 0 if importable. |
| `install_project_guide(backend, env_path)` | Step 1: runs `pip install --upgrade project-guide` against the project env. Always uses `--upgrade`. Failure-non-fatal. |
| `run_project_guide_init_in_env(backend, env_path)` | Step 2 (first-time): runs `<env>/bin/project-guide init --no-input`. Invoked by the orchestrator when `.project-guide.yml` is absent. Requires project-guide >= 2.2.3. Failure-non-fatal. |
| `run_project_guide_update_in_env(backend, env_path)` | Step 2 (reinit, v1.14.0+): runs `<env>/bin/project-guide update --no-input`. Invoked by the orchestrator when `.project-guide.yml` is present. Content-aware: hash-compares, skips matches, creates `.bak.<timestamp>` siblings for modified managed files, preserves `.project-guide.yml` state. Requires project-guide >= 2.4.0. Failure-non-fatal (including a future `SchemaVersionError`). |
| `project_guide_in_project_deps()` | Auto-skip safety: returns 0 if `project-guide` is declared in `pyproject.toml`, `requirements.txt`, or `environment.yml`. Word-boundary regex to avoid false matches with similar names like `project-guide-extras`. |
| `detect_user_shell()` | Reads `$SHELL`, prints `zsh` / `bash` / `unknown`. |
| `get_shell_rc_path(shell)` | Maps `zsh` → `$HOME/.zshrc`, `bash` → `$HOME/.bashrc`, anything else → empty string. |
| `is_project_guide_completion_present(rc_path)` | Detects the sentinel block. |
| `add_project_guide_completion(rc_path, shell)` | Step 3: builds the sentinel-bracketed block via heredoc and delegates insertion to `insert_text_before_sdkman_marker_or_append`. Idempotent. Creates rc file if missing. |
| `remove_project_guide_completion(rc_path)` | Removes the sentinel block. Safe no-op if absent. |
| `insert_text_before_sdkman_marker_or_append(rc_path, content)` | (v1.13.1+, Story G.e) Shared SDKMan-aware rc-file insertion. If `#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!` is present, inserts `content` immediately above it; otherwise appends. Always emits a leading blank line for round-trip symmetry with `remove_project_guide_completion`. Used by both `add_project_guide_completion` and `install_prompt_hook` (the latter currently in `pyve.sh`; moves with the `init` extraction). |

The orchestrator `run_project_guide_hooks(backend, env_path, pg_mode, comp_mode)` (currently in `pyve.sh`; moves to `lib/commands/init.sh` as a private `_init_run_project_guide_hooks` during the extraction phase, since `init()` is its only caller) calls these in priority order. Tri-state mode arguments (`""` / `"yes"` / `"no"`) come from CLI flag parsing in `init()`. The auto-skip safety mechanism fires between explicit flag overrides and the prompt/CI default path.

For step 2, the orchestrator branches on `.project-guide.yml` presence (v1.14.0+, Story G.h): when present, it calls `run_project_guide_update_in_env` (reinit refresh); when absent, it calls `run_project_guide_init_in_env` (first-time scaffold). Pyve never auto-runs `project-guide init --force` — that is destructive (wipes config state, no backups) and must remain user-initiated.

### Legacy-Flag Error Catch (v1.11.0+, Decision D3 — kept forever)

When a user invokes a removed legacy flag or subcommand form, the dispatcher in `main()` catches it and prints a precise migration error, then exits non-zero:

```
ERROR: 'pyve --init' is no longer supported. Use 'pyve init' instead.
ERROR: See: pyve --help
```

**Catches as of v2.0:**

| Tier | Added | Catches | Target |
|---|---|---|---|
| Flag forms | v1.11.0 (G.b.1) | `--init`, `--purge`, `--validate`, `--python-version`, `--install`, `--uninstall` | `init`, `purge`, `check`, `python set <ver>`, `self install`, `self uninstall` |
| Short aliases | v1.11.0 (D1) | `-i`, `-p` | `init`, `purge` |
| Subcommand forms | v2.0 (H.e.8a) | `doctor`, `validate` | `check` |
| v2.0 flag forms | v2.0 (H.e.9) | `--update`, `--doctor`, `--status` | `update`, `check`, `status` |
| `init --update` | v2.0 (H.e.9) | `init --update` | `update` (the separate subcommand) |

**Why kept forever:** Three lines of code per catch, great error message, zero cost. Users coming from old README snippets, blog posts, third-party tutorials, and LLM training data will hit them for years and get a precise hint instead of an opaque "unknown command" error. Implemented via `legacy_flag_error()` helper in `pyve.sh`, called from the top-level dispatcher `case` block before any subcommand dispatch runs.

**Unknown-flag closest-match (H.e.9d).** Distinct from the legacy-flag catches: when a user typos a flag *within* a valid subcommand (`pyve init --forse`), `unknown_flag_error()` in `pyve.sh` suggests the closest valid flag via `_edit_distance()` in `lib/ui.sh`. Suggestion fires only when edit distance ≤ 3; beyond that the error lists the valid-flag set without a "did you mean" line to avoid unrelated hints.

**No compat shim, no silent translation.** The legacy-flag catch list is always an immediate error — silent translation would hide the rename from users and build long-term tech debt. (The Category A delegate-with-warning paths — `testenv --init|--install|--purge`, `python-version <ver>` — shipped in Phase H were removed in Story J.d / v2.3.0.)

### Uniform `.envrc` template (v2.3.2 / Story K.a.2)

Every backend emits the same four-line shape via `write_envrc_template` in [lib/utils.sh](../../lib/utils.sh). `init_direnv_venv` and `init_direnv_micromamba` in [pyve.sh](../../pyve.sh) are thin wrappers that just fill in backend-specific arguments.

```bash
PATH_add "<rel_bin_dir>"                      # direnv stdlib: resolves relative → absolute
export <BACKEND_SENTINEL>="$PWD/<rel_env_root>"  # VIRTUAL_ENV (venv) or CONDA_PREFIX (conda-like)
export PYVE_BACKEND="<backend_name>"
export PYVE_ENV_NAME="<env_name>"
export PYVE_PROMPT_PREFIX="(<backend_name>:<env_name>) "
```

**Key properties.**

- **`PATH_add` is the only path-mutating primitive.** Hand-rolled `export PATH="$ENV_PATH/bin:$PATH"` is forbidden — relative entries stay relative in PATH, which resolves against the caller's cwd and silently breaks rc-file completion guards like `command -v project-guide` when the shell starts outside the project directory (the v2.3.2 bug).
- **Project-directory independence.** Relative paths are written literally in the file; `$PWD` in the sentinel export expands when direnv sources the `.envrc`, yielding the correct absolute path regardless of what the outer shell's cwd was at startup.
- **Backend-native sentinel** (`VIRTUAL_ENV` for venv/pip-derived backends, `CONDA_PREFIX` for micromamba/conda-like backends) is set explicitly instead of by `source`-ing an activate script. Tools that probe these env vars (pip, poetry, IDEs) continue to work.
- **Future backends** (uv, poetry) plug in by filling in `<rel_bin_dir> <sentinel_var> <rel_env_root> <backend_name> <env_name>` — no new activation machinery needed.
- Applies only to the direnv path. `--no-direnv` generates no `.envrc` and is unaffected.

### asdf/direnv Coexistence (Phase J / v2.3.0)

Implements FR-18. When pyve is run under asdf-managed Python, asdf's Python plugin reshims on `direnv allow`, so venv-installed CLIs resolve through `~/.asdf/shims/` instead of `.venv/bin/`. See [pyve-asdf-reshim-bug-brief.md](pyve-asdf-reshim-bug-brief.md) for the original repro and root-cause analysis. The fix sets `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` at two layers:

- **`.envrc` block** (emitted by `write_envrc_template` in [lib/utils.sh](../../lib/utils.sh), invoked from `init_direnv_venv` / `init_direnv_micromamba` in [pyve.sh](../../pyve.sh)): appends a three-line heredoc — sentinel comment `# Prevent asdf Python plugin from reshimming venv-installed CLIs.`, an override note referring to `PYVE_NO_ASDF_COMPAT=1`, and `export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1`. Guarded by `is_asdf_active && ! grep -qF <sentinel> "$envrc_file"` so (a) the block only fires when asdf is the active version manager and the user hasn't opted out, and (b) re-appending is impossible. Also fires on pre-existing `.envrc` files from pyve < v2.3.0, so the guard migrates onto legacy installs without `pyve init --force`.
- **`pyve run` wrapper** (`run_command` in [pyve.sh](../../pyve.sh)): probes the version manager silently (`source_shell_profiles >/dev/null 2>&1 || true; detect_version_manager >/dev/null 2>&1 || true`), then `export`s `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` once before the three backend-specific exec sites (venv-bin, venv-PATH-fallback, micromamba). Silent defense-in-depth — no info line per invocation.

**Helper.** `is_asdf_active()` in [lib/env_detect.sh](../../lib/env_detect.sh) is the single source of truth. Returns 0 iff `$VERSION_MANAGER == "asdf"` AND `PYVE_NO_ASDF_COMPAT` is unset/empty. Both call sites (`.envrc` generator + `pyve run`) use the same helper so the opt-out is consistent.

**Opt-out rationale.** `PYVE_NO_ASDF_COMPAT=1` exists for users who run pyve under asdf but install CLIs globally via `pip install --user`; those CLIs legitimately need asdf's default reshim. The env-var form is intentional — a CLI flag would commit to a permanent surface for a narrow defense-in-depth feature. `PYVE_ASDF_COMPAT=1` is reserved for symmetry but has no distinct behavior (the default state when asdf is detected).

### Platform Portability

- **macOS vs Linux `sed`**: All `sed` operations use portable shell loops with temp files instead of `sed -i` (which has incompatible syntax between BSD and GNU). See v1.1.2/v1.1.3 for history.
- **Shell profiles**: `source_shell_profiles()` initializes asdf/pyenv directly rather than sourcing full shell profiles (which may contain interactive elements).
- **`.DS_Store`**: Auto-added to `.gitignore` template for macOS.

### Atomic File Operations

- `.gitignore` writes use `mktemp` + `mv` to avoid partial writes.
- Config file updates use temp files with atomic `mv`.

### Idempotency

- `write_gitignore_template()` rebuilds the template section from scratch on every call, deduplicating against existing content.
- `insert_pattern_in_gitignore_section()` checks `gitignore_has_pattern()` before inserting.
- `--init` detects existing installations and offers update/force paths.

### Security

- `.env` files: `chmod 600` on creation.
- `.env` always added to `.gitignore`.
- Non-empty `.env` preserved during purge/uninstall.

### Logging

All user-facing output uses the `log_*` functions from `utils.sh`:
- `log_success` → `✓` prefix
- `log_warning` → `WARNING:` to stderr
- `log_error` → `ERROR:` to stderr
- `log_info` → `INFO:` to stdout

Deprecated at v2.0 in favor of `lib/ui.sh` helpers (see below). Removal scheduled for a future major release.

### UI Helper Policy (Phase H / v2.0+)

Once `lib/ui.sh` lands (H.e first sub-story), every user-facing output line in pyve commands **must** go through a `lib/ui.sh` helper. Raw `echo` / `printf` for user-facing text is a policy violation.

**Exceptions — do not route through `lib/ui.sh`:**

- Internal debug logs gated by `PYVE_DEBUG=1`.
- Test-fixture helpers in `tests/helpers/`.
- Pass-through of subprocess stdout/stderr (`pip install`, `micromamba create`, etc.). That stream is not pyve's own voice, so it keeps its upstream formatting. Policy locked in H.f.4: full pass-through, not `--quiet`; `run_cmd`'s dimmed `$ cmd` echo is the only pyve-owned line around a subprocess invocation.
- Subcommands emitting structured output intended for shell parsing (e.g. a future `pyve status --format json`) — these emit on stdout without UI chrome.
- Read-only `show` commands (`pyve python show`) — no `header_box` / `footer_box` wrapper; match `git status` / `gitbetter status` convention of quiet machine-friendly output.

**Why this matters.** Visual consistency is the user-facing contract H.e and H.f establish. A single `echo "WARNING: foo"` slipped into a new command regresses the contract silently. Visual-regression captures in H.f encode the expected output for each command; CI can be extended to enforce this if drift becomes a real problem.

**Backport discipline.** When modifying `lib/ui.sh`, preserve the "no pyve identifiers" invariant. If a helper needs something pyve-specific (e.g. a path into `.pyve/`), that logic goes in the calling command, not in the helper. Any signature or palette change requires a coordinated update to `gitbetter`'s copy of the module.

### Command Module Extraction Pattern

When extracting a top-level command from `pyve.sh` into `lib/commands/<name>.sh`, every extraction story follows the same five-step pattern. This is the contract for keeping `pyve.sh`'s decomposition safe.

1. **Inventory functionality.** List the command's responsibilities (what it does), the cross-command helpers it calls (which `lib/*.sh` functions), and any process-wide state it touches (env vars, globals, files in `.pyve/`).
2. **Audit existing test coverage.** Enumerate every integration test (pytest) and unit test (bats) that exercises the command. Note which behaviors from step 1 are *not* covered.
3. **Backfill characterization tests** against the current (pre-refactor) `pyve.sh`. These should pass immediately — they pin existing behavior, not aspirational behavior. If a backfill test is unexpectedly red, you have found a latent bug; carve it off into its own fix story before continuing the extraction.
4. **Extract** the command function (and any command-private helpers) to `lib/commands/<name>.sh`. Update the dispatcher in `pyve.sh` to source the new file and route to the extracted function. No behavior change.
5. **Re-run the full test suite.** Must be green with zero diff in observable behavior. Any user-visible change is a regression and blocks the story.

**Why this pattern matters.** The refactor's only safety net is test coverage of pre-refactor behavior. Coverage gaps discovered *after* the move can no longer distinguish "this never worked" from "the move broke it." Steps 2–3 close the gap before step 4 disturbs anything.

**Per-extraction-story structure.** Each story in the extraction phase carries the same task-list scaffolding: an inventory section, a coverage-audit table, a backfill-tests subtask, the extraction subtask, and a green-suite verification subtask. Boilerplate, but the discipline is the point.

---

## Testing Strategy

### Unit Tests (Bats)

White-box tests that source individual `lib/*.sh` modules and test functions directly. Command modules in `lib/commands/` are sourced and tested the same way (one `test_<command>.bats` per command file is permitted but not required — many commands are exercised end-to-end by integration tests, and a separate Bats file is justified only when there is command-private logic worth white-box testing in isolation).

| Test File | Module Under Test | Test Count |
|-----------|-------------------|------------|
| `test_utils.bats` | `lib/utils.sh` | — |
| `test_backend_detect.bats` | `lib/backend_detect.sh` | — |
| `test_config_parse.bats` | `lib/utils.sh` (config) | — |
| `test_distutils_shim.bats` | `lib/distutils_shim.sh` | — |
| `test_env_naming.bats` | `lib/micromamba_env.sh` | — |
| `test_lock_validation.bats` | `lib/micromamba_env.sh` | — |
| `test_micromamba_bootstrap.bats` | `lib/micromamba_bootstrap.sh` | — |
| `test_micromamba_core.bats` | `lib/micromamba_core.sh` | — |
| `test_reinit.bats` | `lib/version.sh` | — |
| `test_version.bats` | `lib/version.sh` | — |
| `test_env_detect.bats` | `lib/env_detect.sh` (Story I.j) | 33 |
| `test_distutils_shim_coverage.bats` | `lib/distutils_shim.sh` coverage gap-filler (Story I.k) | 17 |
| `test_asdf_compat.bats` | `is_asdf_active` + `.envrc` guard + `pyve run` guard (Phase J) | 15 |
| `test_bash32_compat.bats` | Grep-invariant over `pyve.sh` + `lib/*.sh` + `lib/completion/pyve.bash` — fails on any bash-4+ construct (declare/typeset/local `-A`, mapfile/readarray, case-mod/@-transform parameter expansions, `declare -n`, named `coproc`, `shopt -s globstar`). Scope excludes `lib/completion/_pyve` (zsh). Story J.e. | 10 |

### Integration Tests (pytest)

Black-box tests that invoke `pyve.sh` as a subprocess and verify outcomes.

| Test File | Workflow Tested |
|-----------|-----------------|
| `test_venv_workflow.py` | Full venv lifecycle (init, run, purge, .gitignore) |
| `test_micromamba_workflow.py` | Full micromamba lifecycle |
| `test_auto_detection.py` | Backend auto-detection from project files |
| `test_bootstrap.py` | Micromamba bootstrap (placeholder, not yet implemented) |
| `test_cross_platform.py` | macOS/Linux-specific behavior |
| `test_doctor.py` | Doctor diagnostics for both backends |
| `test_force_ambiguous_prompt.py` | Interactive backend prompt in `--force` + ambiguous cases |
| `test_force_backend_detection.py` | Backend detection during `--force` re-initialization |
| `test_lock_command.py` | `pyve lock` command (backend guard, prerequisite, platform detection, output filtering) |
| `test_pip_upgrade.py` | pip upgrade during `--init` |
| `test_reinit.py` | Re-initialization (update, force) |
| `test_run_command.py` | `pyve run` for both backends |
| `test_testenv.py` | Dev/test runner environment |
| `test_validate.py` | Installation validation |

**Markers**: `venv`, `micromamba`, `requires_micromamba`, `requires_asdf`, `requires_direnv`, `macos`, `linux`, `slow`

### CI Pipeline (`.github/workflows/test.yml`)

| Job | Runner | Matrix | What it runs |
|-----|--------|--------|-------------|
| Unit Tests | ubuntu + macos | — | `make test-unit` (Bats) |
| Integration Tests | ubuntu + macos | Python 3.10, 3.11, 3.12 | pytest venv tests |
| Micromamba Tests | ubuntu + macos | Python 3.11 | pytest micromamba tests |
| Lint | ubuntu | — | ShellCheck, black, flake8 |
| Bash Coverage (kcov) | ubuntu | — | Line coverage of `lib/*.sh` and `pyve.sh` via kcov; uploads to Codecov |
| Test Summary | ubuntu | — | Gate: fail if unit or integration fail |
