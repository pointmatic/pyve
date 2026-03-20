# Pyve Improvement Proposals — Micromamba Backend

Derived from production use of Pyve v1.6.4 with a micromamba backend on Apple Silicon (M3),
running a scientific/ML Python project (HuggingFace, PyTorch, pandas, numpy) with pre-commit
hooks and an IDE (Windsurf/VS Code-compatible).

---

## Bug 1: `conda-lock.yml` incorrectly added to `.gitignore`

### Description

When `pyve --init` creates or updates `.gitignore`, it adds `conda-lock.yml` to the ignore
list. This is wrong. `conda-lock.yml` is an explicitly committed artifact — its entire purpose
is to provide a reproducible, shareable, deterministic environment definition for the project.
Ignoring it defeats its purpose entirely.

### Expected behavior

`conda-lock.yml` should never appear in Pyve-generated `.gitignore` entries. It belongs in
version control in the same way that `package-lock.json` belongs in a Node project or
`Cargo.lock` belongs in a Rust project.

### Correct `.gitignore` policy for micromamba backend

| File | Should be ignored? |
|---|---|
| `.pyve/envs/` | ✅ Yes — local environment, not portable |
| `.pyve/config` | ✅ No — committed by design (backend declaration) |
| `.envrc` | ✅ Yes — machine-specific activation |
| `.env` | ✅ Yes — secrets |
| `conda-lock.yml` | ❌ **No — must be committed** |
| `environment.yml` | ❌ No — obviously committed |

---

## Bug 2: `pyve doctor` does not detect duplicate dist-info directories

### Description

When iCloud Drive (or any cloud sync daemon) is active during `pyve --init`, the sync
process writes concurrently to the same directories that micromamba and pip are extracting
into. This produces duplicate `dist-info` directories for the same package, corrupted
standard library files, and macOS auto-renamed files with ` 2` suffixes. For example:

```
site-packages/sentiment_poc-1.5.0.dist-info/   ← corrupted, from earlier install
site-packages/sentiment_poc-1.8.0.dist-info/   ← current, correct
```

This causes intermittent and hard-to-diagnose `ModuleNotFoundError` failures, because
Python's import machinery behavior is undefined when two dist-info directories exist for
the same package. The failure appears random because it depends on filesystem enumeration
order, which can vary between runs.

In severe cases the corruption extends into the Python standard library itself. The
following was observed when iCloud sync ran concurrently with micromamba extraction:

```
.pyve/envs/sentiment-poc/lib/python3.12/zipfile/
    __init__.py  __main__.py  __pycache__  _path/   ← directory, should be _path.py
                                                        __pycache__  __pycache__ 2
```

`_path` was created as a directory instead of a file (`_path.py`), and `__pycache__ 2`
appeared due to macOS auto-renaming a directory when two processes attempted to create it
simultaneously. This rendered the entire environment unbootable:

```
ImportError: cannot import name 'Path' from 'zipfile._path' (unknown location)
```

The only resolution was a full `pyve --init --force` rebuild — after moving the project
out of the iCloud-synced directory.

### Expected behavior

`pyve doctor` should scan `site-packages` for duplicate dist-info directories and report
them explicitly:

```
✗ Duplicate dist-info detected: sentiment_poc
    sentiment_poc-1.5.0.dist-info (Mar 16 16:42)
    sentiment_poc-1.8.0.dist-info (Mar 17 07:12)
  Run 'pyve --init --force' to rebuild the environment cleanly.
```

`pyve doctor` should also scan for macOS collision artifacts (files or directories with
` 2` suffixes) inside the environment tree and report them as environment corruption.

### Notes

- The corrupted dist-info in the observed case contained a `licenses 2/` subdirectory
  with 65,535 entries — a consequence of iCloud sync racing against pip's license file
  extraction.
- This class of corruption is not recoverable by partial repair. A full rebuild is
  required, and must be performed outside a cloud-synced directory.

## Bug 3: `pyve --init --force` purges before asking about `conda-lock` on a stale environment

### Description

When `pyve --init --force` is run on a stale environment, it purges the environment
before asking about `conda-lock`. This is problematic because the user may want to
preserve the `conda-lock` file and only regenerate the environment or run conda-lock
to update it. The user should be asked if they want to preserve the `conda-lock` file
before the environment is purged. We should also review any other conditionals to see
if we can front-load all the potential abort conditions before any destructive operations.

### Expected behavior

`pyve --init --force` should ask about `conda-lock` (and other optional operations) before
purging the environment.

### Notes (example CLI output)

```
% pyve --init --force
WARNING: Force re-initialization: This will purge the existing environment
WARNING:   Current backend: micromamba

Continue? [y/N]: y
INFO: Purging existing environment...

Purging Python environment artifacts...
INFO: No virtual environment found at '.venv'
✓ Removed .pyve directory contents (preserved .pyve/testenv)
✓ Removed .envrc
WARNING: .env preserved (contains data). Delete manually if desired.
✓ Cleaned .gitignore

✓ Python environment artifacts removed.
INFO: ✓ Environment purged

INFO: Proceeding with fresh initialization...
INFO: Detected files:
INFO:   • environment.yml (conda/micromamba)
INFO:   • pyproject.toml (Python project)

Initialize with micromamba backend? [Y/n]: Y

WARNING: Lock file may be stale
  environment.yml:  modified 2026-03-19 23:16:44
  conda-lock.yml:   modified 2026-03-17 12:22:55

Using conda-lock.yml for reproducibility.
To update lock file:
  conda-lock -f environment.yml -p arm64

Continue anyway? [y/n]: n
INFO: Aborted. Please update lock file and try again.
% conda-lock -f environment.yml -p arm64
zsh: command not found: conda-lock
% pyve doctor
Pyve Environment Diagnostics
=============================

✓ Pyve: v1.6.4 (homebrew: /opt/homebrew/Cellar/pyve/1.6.4/libexec)
✗ No environment found
  Run 'pyve --init' to create an environment
```

---

## Feature 1: Auto-generate `.vscode/settings.json` for micromamba backend

### Description

When Pyve initializes a micromamba backend environment, it should generate a
`.vscode/settings.json` file that establishes clean separation of concerns between Pyve
and VS Code-compatible IDEs (VS Code, Windsurf, Cursor, etc.).

Pyve manages the environment lifecycle — creation, activation, and execution — via
micromamba and direnv. The IDE should be a passive consumer of that environment, not an
active participant in its management. Without explicit settings, the IDE's Python extension
will attempt to participate: detecting `environment.yml`, probing for interpreters,
activating environments in new terminals, and potentially invoking conda or pip directly.
None of this is desirable when Pyve is in charge.

Pyve already knows the interpreter path at init time, so it has all the information needed
to generate this file without user input.

### Proposed generated content

```json
{
  "python.defaultInterpreterPath": ".pyve/envs/<env_name>/bin/python",
  "python.terminal.activateEnvironment": false,
  "python.condaPath": ""
}
```

Where `<env_name>` is read from `.pyve/config`.

**Per-setting rationale:**

- **`python.defaultInterpreterPath`** — tells the IDE exactly where the interpreter is,
  eliminating interpreter discovery probing on startup and ensuring language server
  features (type checking, autocomplete) use the correct environment immediately
- **`python.terminal.activateEnvironment: false`** — Pyve activates the environment via
  direnv; IDE activation in new terminals would produce double-activation conflicts or
  override direnv's PATH ordering
- **`python.condaPath: ""`** — prevents the IDE from ever invoking micromamba or conda
  directly on the user's behalf, keeping all environment management through Pyve

### `.gitignore` behavior

`.vscode/settings.json` should be added to `.gitignore` by default, as it is
machine-specific. `.vscode/extensions.json` is conventionally committed and should not
be ignored.

### Notes

Earlier investigation initially attributed environment corruption to IDE background
tooling running pip concurrently with user commands. This was incorrect — the confirmed
root cause was iCloud Drive syncing concurrently with micromamba extraction (see Feature
4). The `.vscode/settings.json` file remains valuable for IDE isolation, but should not
be framed as a corruption prevention measure.

---

## Feature 2: Enforce `conda-lock.yml` presence before `pyve --init`

### Description

Currently, `pyve --init` warns when no `conda-lock.yml` is present but proceeds anyway
after a confirmation prompt. This means environments are routinely created without a lock
file, leading to non-deterministic installs where package versions can change between
environment rebuilds.

### Expected behavior

For micromamba backends, `pyve --init` should treat a missing `conda-lock.yml` as a
blocking condition unless explicitly overridden:

```
ERROR: No conda-lock.yml found.

For reproducible builds, generate one first:
  conda-lock -f environment.yml -p <platform>

To proceed without a lock file (not recommended):
  pyve --init --no-lock
```

The `--no-lock` flag makes the bypass explicit and intentional rather than a casual
confirmation prompt that is easy to dismiss.

### Notes

- The `--no-lock` path is still valid for first-time environment setup before a lock file
  has been generated.
- CI/CD pipelines should always have a lock file and should not need `--no-lock`.

---

## Feature 3: `pyve doctor` checks for mixed conda/pip native library conflicts

### Description

When packages installed via conda-forge link against native libraries (e.g., `libopenblas`,
`libomp`), and other packages are installed via pip that bundle their own copies of those
same libraries (e.g., `torch`), runtime conflicts can occur. These manifest as intermittent
`ImportError` failures with `dlopen` / `Library not loaded` messages.

### Observed failure

```
ImportError: dlopen(...numpy/_core/_multiarray_umath.cpython-312-darwin.so):
  Library not loaded: @rpath/libomp.dylib
  Referenced from: .../libopenblas.0.dylib
```

Caused by: conda-forge numpy linked against `libopenblas` which requires `libomp.dylib`,
but pip-installed torch provided its own OpenMP in a non-standard location, leaving the
conda env's `lib/` directory without `libomp.dylib`.

### Expected behavior

`pyve doctor` should detect when:
1. pip-installed packages are present that are known to bundle native libraries (torch,
   tensorflow, etc.)
2. conda-forge packages are present that link against the same native libraries (numpy,
   scipy, etc.)
3. The required shared library (e.g., `libomp.dylib`, `libgomp.so`) is not present in the
   conda env's `lib/` directory

And warn:

```
⚠ Potential native library conflict detected:
    pip-installed: torch (bundles its own OpenMP)
    conda-installed: numpy (requires libomp.dylib via libopenblas)
    libomp.dylib not found in .pyve/envs/<env>/lib/

  Fix: add 'llvm-openmp' to environment.yml conda dependencies
```

---

## Feature 4: Hard fail when project is inside a cloud-synced directory

### Description

Cloud sync daemons (iCloud Drive, Dropbox, Google Drive, OneDrive) watch the filesystem
in real time and write concurrently to directories they are syncing. When a project
containing a micromamba environment lives inside a synced directory, the sync daemon races
against micromamba's package extraction and pip's dist-info writes. This produces
environment corruption that is intermittent, non-deterministic, and extremely difficult to
diagnose. The corruption can affect pip dist-info directories, Python bytecode caches, and
— in the worst observed case — the Python standard library itself.

This is not a recoverable situation. There is no good outcome when a micromamba environment
is created inside a cloud-synced directory. Every `pyve --init` is a gamble on whether the
sync daemon happens to be idle at that moment.

### Root cause confirmed

All environment corruption in the production case that generated this document was
ultimately caused by the project residing in `~/Documents/`, which is synced to iCloud
Drive by default on macOS. The issues were initially attributed to IDE background tooling
(Windsurf/Cascade) and pre-commit hooks, but systematic elimination of those factors
confirmed the sync daemon as the true cause. The developer had previously moved all active
development repos to `~/Developer/` for exactly this reason, but started a new project in
`~/Documents/` and did not initially connect the location to the failures.

### Expected behavior

`pyve --init` should hard fail when the project directory is inside a known cloud-synced
path, with a clear explanation and an explicit override flag for users who have disabled
sync for that path:

```
ERROR: Project is inside a cloud-synced directory.

  Path: /Users/michaelsmith/Documents/Education/WGU/.../d803-natural-language-processing
  Sync root: ~/Documents (iCloud Drive)

  Cloud sync daemons write concurrently to synced directories, which corrupts
  micromamba environments during extraction. This causes non-deterministic
  import failures and can damage the Python standard library itself.

  Recommended fix: move your project outside the synced directory.
    mv ~/Documents/.../my-project ~/Developer/my-project

  If you have disabled iCloud sync for this directory and understand the risk:
    pyve --init --allow-synced-dir
```

### Detection strategy

Two complementary checks, both fast and dependency-free:

**1. Known path heuristic (primary)**

Hard fail if `$PWD` is inside any of these prefixes:

```bash
KNOWN_SYNCED_PATHS=(
    "$HOME/Documents"
    "$HOME/Desktop"
    "$HOME/Library/Mobile Documents"
    "$HOME/Dropbox"
    "$HOME/Google Drive"
    "$HOME/OneDrive"
)
```

This catches the default configuration for all major sync providers on macOS. It produces
false positives only for users who have explicitly disabled sync on those directories —
which is exactly the population served by `--allow-synced-dir`.

**2. Extended attribute check (secondary)**

iCloud Drive, Dropbox, and Google Drive stamp synced directories with extended attributes:

```bash
xattr -l "$PWD" | grep -i "com.apple.cloud\|com.dropbox\|com.google.drive\|com.microsoft.onedrive"
```

This catches cases where sync is enabled on a non-standard directory path, and serves as
a cross-check when the path heuristic does not match.

### Why `--allow-synced-dir` instead of a warning

A warning is insufficient because:

- The failure mode is silent and delayed — corruption may not manifest until hours or days
  later, during a `git commit` or routine test run
- The symptoms (`ImportError`, `ModuleNotFoundError`, `__pycache__ 2` directories,
  unbootable standard library) do not point back to the root cause without significant
  debugging effort
- By the time the problem is diagnosed, multiple corrupted `pyve --init --force` cycles
  may have occurred, each wasting significant time
- There is no partial mitigation — either the directory is safe for concurrent writes or
  it isn't

A hard fail with a clear message and a documented override is the correct UX. The user
loses 30 seconds reading the error. The alternative is losing hours debugging.

---

## Summary of proposed changes

| Type | Item | Priority |
|---|---|---|
| Bug | Remove `conda-lock.yml` from `.gitignore` | High |
| Bug | `pyve doctor` detects duplicate dist-info directories and ` 2` artifacts | High |
| Feature | Hard fail when project is inside a cloud-synced directory | High |
| Feature | Auto-generate `.vscode/settings.json` at init | High |
| Feature | Enforce `conda-lock.yml` presence (blocking, not warning) | Medium |
| Feature | `pyve doctor` detects conda/pip native library conflicts | Medium |

---

## Environment context for reproduction

- Platform: macOS, Apple Silicon (M3)
- Pyve version: 1.6.4
- Backend: micromamba
- Python: 3.12.13
- Key packages: numpy, torch (pip), transformers, pandas, scikit-learn
- IDE: Windsurf (VS Code-compatible)
- Pre-commit hooks: ruff, pytest
