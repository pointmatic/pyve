# Pyve Improvement Proposals — conda-lock Integration

Derived from production use of Pyve v1.8.2 with a micromamba backend on Apple Silicon (M3).

---

## Feature 1: `pyve lock` command

### Description

Currently, regenerating `conda-lock.yml` requires the user to:

1. Know the correct conda platform string for their machine (`osx-arm64`, not `arm64`)
2. Remember the full command syntax (`conda-lock -f environment.yml -p osx-arm64`)
3. Ignore the misleading post-run message ("Install lock using: conda-lock install
   --name YOURENV conda-lock.yml") and know to use `pyve --init --force` instead

Pyve already knows all of this. A `pyve lock` command encapsulates the entire workflow
and presents the user with accurate, actionable output.

### Proposed command

```
pyve lock
```

### Behavior

1. **Detect platform** automatically using `uname -s` and `uname -m`, mapped to the
   correct conda platform string:

   | `uname -s` | `uname -m` | conda platform |
   |---|---|---|
   | Darwin | arm64 | osx-arm64 |
   | Darwin | x86_64 | osx-64 |
   | Linux | aarch64 | linux-aarch64 |
   | Linux | x86_64 | linux-64 |

2. **Run conda-lock** with the correct arguments:
   ```
   conda-lock -f environment.yml -p <platform>
   ```

3. **Handle the "spec hash already locked" case** — when conda-lock skips re-solving
   because the spec hash matches, surface this clearly rather than passing through
   conda-lock's terse output:
   ```
   ✓ conda-lock.yml is already up to date for osx-arm64. No changes made.
   ```

4. **Suppress the misleading install message** — conda-lock's post-run output suggests
   running `conda-lock install --name YOURENV conda-lock.yml`, which is not the correct
   workflow in a Pyve-managed project. Pyve should suppress this and replace it with:
   ```
   ✓ conda-lock.yml updated for osx-arm64.

   To rebuild the environment from the new lock file:
     pyve --init --force

   If the environment is already initialized and you only need to commit the updated
   lock file, rebuilding is optional.
   ```

5. **Verify conda-lock is available** — if `conda-lock` is not installed in the current
   environment, fail with a helpful message:
   ```
   ERROR: conda-lock is not available in the current environment.
   Add 'conda-lock' to environment.yml dependencies and run 'pyve --init --force'.
   ```

### Usage examples

```bash
# First-time lock generation
pyve lock

# After adding new packages to environment.yml
pyve lock

# Check if lock is up to date without modifying it (future enhancement)
pyve lock --check
```

### Relationship to `pyve --init`

Once `pyve lock` exists, all Pyve output that currently references raw `conda-lock`
commands should be updated to reference `pyve lock` instead. This includes:

- The stale lock file warning during `pyve --init`
- The missing lock file warning during `pyve --init`
- Any `pyve doctor` output related to lock file state

### Notes

- `pyve lock` should work regardless of whether the environment is currently initialized.
  Regenerating the lock file is independent of the environment lifecycle.
- The command name `lock` is preferred over `relock` because it serves both first-time
  and subsequent lock generation. The distinction between first-time and subsequent runs
  is an implementation detail, not a user-facing concern.
- A future `--check` flag could verify whether `conda-lock.yml` is up to date with
  `environment.yml` without modifying anything, useful for CI/CD pipelines.

---

## Environment context for reproduction

- Platform: macOS, Apple Silicon (M3)
- Pyve version: 1.8.2
- Backend: micromamba
- conda-lock version: 4.0.0
