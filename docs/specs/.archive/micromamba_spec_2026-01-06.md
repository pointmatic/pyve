# ⚠️ DEPRECATED - See design_decisions.md

**This file has been superseded by `design_decisions.md`**
- **Archived:** 2026-01-06
- **Reason:** Redundant with design_decisions.md
- **Current Reference:** See `docs/specs/design_decisions.md` for all design decisions

This file is kept for historical reference only.

---

# Micromamba environment manager
This doc provides a clean decision model for adding support for micromamba environment manager to Pyve.

## Step 1: Decide the backend (what kind of env you're creating/running)
* Conda-style env → backend = conda (implemented via micromamba if available)
* Pip/venv-style env → use asdf/pyenv/system python

This decision can come from:
* explicit config (backend: micromamba)
* presence of `environment.yml` or `conda-lock.yml`
* presence of `pyproject.toml` or `requirements.txt`

## CLI Interface Specification

### Backend Selection Flags

```bash
pyve --init                           # Auto-detect or default to venv
pyve --init --backend venv            # Explicit venv
pyve --init --backend micromamba      # Explicit micromamba
pyve --init --backend auto            # Auto-detect from files
```

### Environment File Priority

When multiple indicators exist, use this precedence (highest to lowest):

1. **Explicit --backend flag** (highest priority)
2. **`.pyve/config`** (project configuration file)
3. **`environment.yml` / `conda-lock.yml`** (conda indicator)
4. **`pyproject.toml` / `requirements.txt`** (pip indicator)
5. **Default to venv** (lowest priority)

Examples:

```bash
# Both environment.yml and pyproject.toml exist
pyve --init --backend venv            # Uses venv (explicit flag wins)
pyve --init                           # Uses micromamba (environment.yml detected)

# Only pyproject.toml exists
pyve --init                           # Uses venv (auto-detected)

# No environment files
pyve --init                           # Uses venv (default)
```

### Execution Model

```bash
pyve run <cmd>                        # Runs in detected backend
pyve run --backend venv pip list      # Force specific backend
pyve run --backend micromamba conda list
pyve run python script.py             # Uses project's configured backend
```

## Step 2: Resolve the tool for that backend
1. If backend == conda (implemented via micromamba):
  1a. Prefer sandbox micromamba (project-local)
  1b. Else try micromamba on PATH
  1c. Else error (or optionally bootstrap it into sandbox)

2. If backend == venv (pip-based, poetry-compatible):
  2a. Prefer asdf Python (via .tool-versions)
  2b. Else try pyenv
  2c. Else try system python

## Bootstrap Strategy

When micromamba is required but not found, provide interactive installation:

```
ERROR: Backend 'micromamba' required but not found.

Detected: environment.yml
Required: micromamba

Installation options:
  1. Install to project sandbox: .pyve/bin/micromamba
  2. Install to user sandbox: ~/.pyve/bin/micromamba
  3. Install via system package manager (brew/apt)
  4. Abort and install manually

Choice [1]: _
```

Non-interactive mode (CI/automation):

```bash
pyve --init --backend micromamba --auto-bootstrap
pyve --init --backend micromamba --bootstrap-to project
pyve --init --backend micromamba --bootstrap-to user
```

## Configuration File Format

Project-specific configuration in `.pyve/config`:

```yaml
# .pyve/config
backend: micromamba

micromamba:
  env_name: myproject
  env_file: environment.yml
  channels:
    - conda-forge
    - defaults
  prefix: .pyve/envs/myproject

python:
  version: "3.11"

venv:
  directory: .venv
```

This file takes precedence over auto-detection but is overridden by explicit CLI flags.

## Simple "policy" rules Pyve can enforce
* Never run pip into a conda env unless explicitly allowed.
* Never "activate base" automatically.
* If conda spec exists and micromamba missing:
  * error with clear instructions
  * or auto-bootstrap micromamba

## Suggested UX behavior
pyve env create:
* if `environment.yml` exists → micromamba backend
* if `pyproject.toml` exists → poetry/pip backend
* if both exist → prefer explicit config, else warn

pyve run <cmd>:
* runs inside whichever env backend is configured
* no shell init required

## One extra guardrail (worth it)
When micromamba is present but the user is in a pip-based project, don’t accidentally use it just because it’s installed. Make backend selection deterministic via config/spec detection.

## “Definition of done” for micromamba support
Micromamba support is complete when:
1. Pyve can deterministically select backend = conda
2. Pyve resolves micromamba via sandbox → user → PATH
3. Pyve can:
  3a. create a conda env from environment.yml
  3b. reuse it if it exists
  3c. run commands inside it without shell activation
4. Pyve never:
  4a. activates base
  4b. falls back to pip when a conda spec exists
  4c. mixes runtimes implicitly
5. Errors are explicit and actionable when micromamba is missing

## Validation & Health Checks

Add diagnostic command for environment verification:

```bash
pyve doctor                          # Check environment health
pyve doctor --backend micromamba     # Check micromamba setup
pyve doctor --verbose                # Detailed diagnostics
```

Output example:

```
✓ Backend: micromamba
✓ Micromamba: /Users/user/.pyve/bin/micromamba (v1.5.3)
✓ Environment: .pyve/envs/myproject
✓ Python: 3.11.7
✓ Environment file: environment.yml
✓ Lock file: conda-lock.yml (up to date)
✗ Warning: pip installed in conda environment
```

## Future Requirements

### Migration Support

Convert between backends:

```bash
pyve migrate --from venv --to micromamba
pyve migrate --from micromamba --to venv
```

Migration should:
- Detect current backend
- Generate appropriate environment files
- Preserve dependencies where possible
- Warn about incompatibilities

### Advanced Features (Future)

1. **Multiple environments per project**
   ```bash
   pyve --init --env dev --backend venv
   pyve --init --env prod --backend micromamba
   pyve run --env dev pytest
   ```

2. **Lock file management**
   ```bash
   pyve lock                         # Generate conda-lock.yml
   pyve lock --update numpy          # Update specific package
   ```

3. **Channel configuration**
   ```bash
   pyve --init --backend micromamba --channel conda-forge
   ```

4. **Cross-platform considerations**
   - Windows support (PowerShell, cmd)
   - Platform-specific environment files
   - Binary compatibility checks

5. **CI/CD integration examples**
   - GitHub Actions workflow templates
   - GitLab CI examples
   - Docker integration

Next steps:
* Create a refactoring plan for the micromamba backend (interfaces + detection order + error modes)
* Detail how it avoids accidental cross-contamination between conda and asdf Python
* Implement the refactoring plan 
