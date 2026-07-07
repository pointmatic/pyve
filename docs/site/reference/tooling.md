# Tooling

Day-to-day execution and toolchain commands: [`run`](#run-command-args), [`test`](#test-pytest-args), [`lock`](#lock-check-env-name-all), [`package`](#package), [`python set` / `python show`](#python-set-ver-python-show), and the [`self`](#self) namespace.

## `run <command> [args...]`

Execute a command within the project's virtual environment.

**Usage:**

```bash
pyve run <command> [args...]
```

**Arguments:**

- `<command>`: Command to execute
- `args`: Arguments to pass to the command

**Examples:**

```bash
# Run a Python script
pyve run python script.py

# Run the Python version check
pyve run python --version

# Run an installed CLI tool
pyve run pytest tests/ -v

# Chain commands
pyve run python -m pip install requests
```

**Notes:**

- Activates the virtual environment before running the command
- Useful for CI/CD, Docker, and `--no-direnv` setups
- Exit code matches the executed command

---

## `test [pytest args...]`

Run tests via the dev/test runner environment.

**Usage:**

```bash
pyve test [--env <name>[,<name>...]] [pytest args...]
```

**Arguments:**

- `--env <name>[,<name>...]` (optional): which environment(s) to run pytest in.
    - **No `--env`:** routes to the declared default test env (`default = true` in its `[env.<name>]` block). A homogeneous Python project with exactly one `purpose = "test"` env auto-promotes it; a bare (no-manifest) project uses the conventional `testenv` at `.pyve/envs/testenv/venv/`. Otherwise — mixed backends, or several test envs with no default — `pyve test` requires an explicit `--env`.
    - **Reserved `root`:** routes pytest to the project's root env (equivalent to `pyve run python -m pytest`) — the first-class form of the `pyve run python -m pytest` workaround for bundled-env setups.
    - **Reserved `testenv`:** explicit selection of the implicit-default testenv.
    - **`<declared-name>`:** any name declared as `[env.<name>]` in `pyve.toml` — venv-backed only (conda-backed envs hard-error; use `--env root` or `micromamba run` as a fallback). Lazy envs (`lazy = true`) auto-provision on first targeted use; suppress with `PYVE_NO_AUTO_PROVISION=1`.
    - **Comma-separated list (matrix mode):** `--env a,b,c` runs pytest against each named env sequentially with `=== Env: <name> ===` headers; exit code is the worst-case aggregate; iteration never halts on a failing env. `--parallel` is out of scope.
    - **Legacy `--env main`** now hard-errors with the rename hint (renamed to `--env root` in v2.7.1; Category-B deprecation-removal policy).
- `pytest args` (optional): Arguments passed directly to pytest.

**Examples:**

```bash
# Run all tests (default env)
pyve test

# Run specific test file
pyve test tests/test_module.py

# Run with verbose output
pyve test -v

# Run quiet
pyve test -q

# Run with coverage
pyve test --cov=mypackage

# Run a specific test
pyve test tests/test_module.py::test_function

# Run against the ROOT env (for envs that bundle pytest + the stack
# under test in the root env — see the trap note below)
pyve test --env root tests/integration/test_e2e.py -m hardware

# Run against a declared named env (requires [env.smoke] in pyve.toml)
pyve test --env smoke

# Matrix: run against two envs sequentially
pyve test --env smoke,integration
```

**What it does:**

1. Resolves `--env` per the rules above. Comma in the value triggers matrix mode.
2. For each target env: auto-installs pytest if `PYVE_TEST_AUTO_INSTALL_PYTEST=1` (CI mode) or prompts (interactive); lazy envs auto-provision on first use (unless `PYVE_NO_AUTO_PROVISION=1`).
3. Runs pytest with the provided arguments. `.state.last_used_at` is touched per env on the success path so `pyve env list` / `prune --unused-since` can see it.

**Notes:**

- Default routing uses the dev/test runner environment, not the project environment — keeps test tools isolated from the project's dependency graph.
- Set `PYVE_TEST_AUTO_INSTALL_PYTEST=1` for CI environments.
- Exit code matches pytest's (single env) or the worst-case aggregate (matrix mode).
- Default routing is equivalent to `pyve env run python -m pytest [args...]` with auto-install support; `--env root` is equivalent to `pyve run python -m pytest [args...]`.
- The silent-skip advisory scans every other env (`root` + declared names) for pytest-importability and prints a one-line hint listing alternatives. Suppress with `PYVE_NO_TESTENV_ADVISORY=1` (matrix mode sets it automatically).

!!! warning "The bundled-env trap — when to use `--env root`"

    `pyve test` routes to the **testenv** by default, which is correct for a normal repo checkout (the root env holds only runtime deps; pytest lives in the testenv). But if you built your environment from an `environment.yml` that bundles **both** pytest **and** the stack your tests import (e.g. a micromamba smoke env with `tensorflow`/`torch` *and* `pytest` in the root env), the default testenv won't have that stack. Tests that `pytest.importorskip("…")` will then **silently SKIP** and look green.

    When another env carries pytest, `pyve test` prints an advisory pointing at it. Use `pyve test --env root` (or `--env <named-env>`) to run pytest against the stack you actually need. See [Testing → Choosing which environment runs your tests](../testing.md#choosing-which-environment-runs-your-tests).

    *Renamed in v2.7.1:* the previous value `--env main` was renamed to `--env root`. The legacy form now hard-errors with the rename hint per the Category-B deprecation-removal policy.

---

## `lock [--check] [--env <name>|--all]`

Generate or update lock files. Without arguments, locks the main env (`environment.yml` → `conda-lock.yml`). With `--env <name>` or `--all`, also locks conda-backed named envs declared in `pyve.toml`'s `[env.<name>]` blocks.

**Usage:**

```bash
pyve lock                   # generate / update conda-lock.yml (main env)
pyve lock --check           # verify conda-lock.yml is current (exit 0) or stale/missing (exit 1)
pyve lock --env <name>      # lock one conda-backed named env → <manifest>-lock.yml
pyve lock --all             # main env + every conda-backed named env
```

`--env <name>` writes the lock file sibling to the env's `manifest` (`tests/env.yml` → `tests/env-lock.yml`). Hard-errors for venv-backed names, undeclared names, the reserved `root`, and missing `manifest` declarations / files. `--all` iterates: locks the main env first (in a subshell so its exit-paths don't halt the loop), then every micromamba-backed env; venv-backed envs are silently skipped; per-env failures `warn` and accumulate into a non-zero exit.

**Prerequisites:**

- `conda-lock` must be available on PATH. Add it to `environment.yml` dependencies:
  ```yaml
  dependencies:
    - conda-lock
  ```
  Then run `pyve init --force` to install it, after which `pyve lock` is available.
- `environment.yml` must exist in the current directory.
- Project must use the micromamba backend.

**What it does:**

1. Checks that the project uses the micromamba backend (fails with a clear message for venv projects)
2. Verifies `conda-lock` is on PATH
3. Verifies `environment.yml` exists
4. Detects the current platform automatically (`osx-arm64`, `osx-64`, `linux-64`, `linux-aarch64`)
5. Runs `conda-lock -f environment.yml -p <platform>`
6. If the spec hasn't changed, prints an up-to-date message and exits without modifying the file
7. On success, suppresses the misleading `conda-lock install` post-run message and prints actionable next steps

**Example output (file updated):**

```
  ▸ Generating conda-lock.yml for osx-arm64...

✓ conda-lock.yml updated for osx-arm64.

To rebuild the environment from the new lock file:
  pyve init --force

If the environment is already initialized and you only need to commit the updated
lock file, rebuilding is optional.
```

**Example output (already up to date):**

```
  ▸ Generating conda-lock.yml for osx-arm64...

✓ conda-lock.yml is already up to date for osx-arm64. No changes made.
```

**`--check` flag:**

Compares `environment.yml` and `conda-lock.yml` modification times without
invoking `conda-lock`. Useful as a CI gate to catch `environment.yml` changes
that weren't accompanied by a `pyve lock` run. Does not require `conda-lock`
to be installed.

```
# Up to date:
✓ conda-lock.yml is up to date.

# Stale (exit 1):
✗ conda-lock.yml is stale — environment.yml has been modified since the lock was generated. Run: pyve lock

# Missing (exit 1):
✗ conda-lock.yml not found. Run: pyve lock
```

**Workflow:**

```bash
# After adding a new package to environment.yml
pyve lock               # regenerate conda-lock.yml
git add conda-lock.yml
git commit -m "Add numpy to environment"
pyve init --force       # rebuild environment from new lock file
```

---

## `package`

Reserved artifact-materialization verb — prints an advisory until a packaging provider ships. Declared packaging intent (`packaging = "<kind>"` on an `[env.<name>]` block) is recorded in the manifest today; materialization is future per-provider work. See the [Packaging workflow](../packaging.md) page for the current guidance.

---

## `python set <ver>` / `python show`

Manage the project Python-version pin without creating an environment.

**Usage:**

```bash
pyve python set <version>    # Pin a version (writes .tool-versions or .python-version)
pyve python show             # Print the current pin + its source
```

**Arguments:**

- `<version>`: Python version in `#.#.#` form (e.g., `3.13.7`)

**Description:**

`pyve python set <ver>` writes the version to `.tool-versions` (asdf) or
`.python-version` (pyenv) so subsequent `pyve init` invocations pick it up.
Does not create or modify any virtual environment.

`pyve python show` reads the currently pinned version from `.tool-versions` →
`.python-version` (first match wins) and prints it along with its source.
Read-only; never installs or modifies anything.

**Examples:**

```bash
# Pin the project to Python 3.13.7
pyve python set 3.13.7

# Confirm what pyve will use
pyve python show
# → Python 3.13.7 (from .tool-versions)
```

**Legacy form (removed in v3.0).**

`pyve python-version <ver>` hard-errors with a hint pointing at
`pyve python set <ver>`. Update any scripts still using the old form.

---

## `self install`

Install pyve to `~/.local/bin` for manual installations.

**Usage:**

```bash
# From a cloned pyve checkout
./pyve.sh self install

# After the first install, from anywhere
pyve self install
```

**What it does:**

Copies the pyve script and `lib/` modules to `~/.local/bin` and adds
`~/.local/bin` to `PATH` (via `~/.zshrc` or `~/.bashrc`) if not already
present. Idempotent — safe to run multiple times.

**Notes:**

- Only for git-clone installations
- Homebrew-managed installations show a warning
- Requires `~/.local/bin` to be in `PATH`

---

## `self uninstall`

Remove pyve from `~/.local/bin`.

**Usage:**

```bash
pyve self uninstall
```

**What it does:**

Removes the pyve script and `lib/` modules from `~/.local/bin`, plus:

- The `PATH` entry added by the installer (from `~/.zprofile` / `~/.bash_profile`)
- The pyve prompt hook (from `~/.zshrc` / `~/.bashrc`)
- The project-guide shell completion block (from `~/.zshrc` / `~/.bashrc`), if one was added by `pyve init --project-guide-completion`

Non-empty `~/.local/.env` is preserved (warn, don't delete).

**Notes:**

- Only for manual (git-clone) installations
- Homebrew-managed installations should use `brew uninstall pyve`
- Does not affect project virtual environments

---

## `self`

Show the self-namespace help (mirrors `git remote`, `kubectl config`).

**Usage:**

```bash
pyve self
pyve self --help
```

## See also

- [Testing](../testing.md) — the concept and how-to companion for `pyve test`
- [Packaging](../packaging.md) — the packaging workflow behind the reserved `package` verb
- [Environments (`env`)](env.md) — provisioning the envs these commands run in
- [Usage Guide](../usage.md) — command overview, universal flags, environment variables
