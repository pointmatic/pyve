# Pyve Design Decisions

This document records key design decisions and overall architecture.

---

## Summary

All critical design questions resolved:

1. ✅ **Environment Naming:** Project-local, respect environment.yml name field
2. ✅ **Multiple Environments:** Phase 2 feature, hybrid activation model
3. ✅ **Lock Files:** Consume with validation warnings, don't generate
4. ✅ **Channels:** Respect environment.yml, error if missing
5. ✅ **Cross-Platform:** macOS, Linux, WSL only
6. ✅ **CI/CD:** Minimal approach via `pyve run` and `--no-direnv`
7. ✅ **Policy Rules:** Enforce best practices, prevent common mistakes
8. ✅ **Definition of Done:** All Phase 1 criteria met
9. ✅ **Testing Framework:** Hybrid Bats + pytest approach

Phase 1 (v0.7.x) implementation complete.
Phase 2 (v0.8.x) testing framework planned.

---

## 9. Testing Framework Strategy

**Decision Date:** 2026-01-06

### Strategy: Hybrid Bats + pytest

**Phase 2 (v0.8.x):** Implement comprehensive testing framework using hybrid approach.

**Framework Choice:**
- **Bats** for white-box unit testing of shell functions
- **pytest** for black-box integration and end-to-end testing

### Rationale

**Why hybrid approach:**
- Pyve is a Python virtual environment orchestrator, so Python dependency is reasonable
- Need both white-box (internal function testing) and black-box (user workflow testing)
- Each framework excels at different testing levels
- Comprehensive coverage requires multiple testing perspectives

**Why Bats for unit tests:**
- Native Bash testing environment
- Direct access to shell functions (white-box testing)
- Fast, focused tests
- Easy to test internal logic and edge cases
- No external dependencies beyond Bats itself

**Why pytest for integration tests:**
- Excellent fixtures and parametrization
- Rich assertion library and error messages
- Coverage reporting built-in
- Parallel execution support
- Cross-platform testing capabilities
- Mature ecosystem with plugins
- Realistic user workflow testing

### Division of Responsibilities

**Bats Tests (Unit/White-box):**
- Shell function unit tests
- Internal logic verification
- Module-level testing (`lib/*.sh`)
- Config parsing
- Backend detection logic
- Environment naming resolution
- Lock file validation
- Fast, focused tests with direct function access

**pytest Tests (Integration/Black-box):**
- End-to-end workflows
- CLI integration tests
- Complete user scenarios
- Cross-platform testing
- Backend comparison tests
- CI/CD workflow validation
- Realistic environment creation/management

### Test Structure

```
tests/
├── unit/                    # Bats tests (white-box)
├── integration/             # pytest tests (black-box)
├── helpers/                 # Shared test utilities
├── fixtures/                # Test data
├── pytest.ini
├── Makefile
└── README.md
```

### Implementation Plan

**Phase 1 (v0.8.0-v0.8.6):**
1. Test infrastructure setup
2. Bats unit tests for core modules
3. pytest integration tests for workflows
4. CI/CD integration
5. Coverage reporting
6. Documentation

**Coverage Goals:**
- Unit tests: Backend detection, config parsing, environment naming, lock validation
- Integration tests: Venv workflow, micromamba workflow, auto-detection, error handling
- Target: >80% code coverage

### Benefits

- **Comprehensive coverage:** White-box + black-box testing
- **Fast feedback:** Bats unit tests run quickly
- **Thorough validation:** pytest integration tests catch real issues
- **Multiple levels:** Unit, integration, E2E testing
- **Best tool for each job:** Leverage strengths of both frameworks
- **CI/CD ready:** Both frameworks integrate well with CI systems
- **Cross-platform:** Test on macOS and Linux
- **Maintainable:** Clear separation of concerns

### Alternatives Considered

**Bats only:**
- ❌ Limited to shell-level testing
- ❌ No rich assertion library
- ❌ No built-in coverage reporting
- ❌ Harder to test complex workflows

**pytest only:**
- ❌ Black-box testing only
- ❌ Cannot test internal shell functions directly
- ❌ Slower than native Bash tests
- ❌ Requires Python for all tests

**Manual scripts only:**
- ❌ No test discovery
- ❌ No reporting
- ❌ No CI/CD integration
- ❌ Hard to maintain

**ShellSpec:**
- ✅ Good BDD-style framework
- ❌ Less popular than Bats
- ❌ Steeper learning curve
- ❌ Hybrid approach with pytest still better

### Decision

**Adopt hybrid Bats + pytest testing strategy** for comprehensive coverage at multiple testing levels. This provides the best balance of speed, thoroughness, and maintainability.

---

## 8. Definition of Done

**Decision Date:** 2026-01-05

### Micromamba Support Completion Criteria

Micromamba support is complete when:

**1. Backend Selection**
- ✅ Pyve can deterministically select backend = micromamba
- ✅ Backend selection respects priority: CLI flag → config → files → default

**2. Tool Resolution**
- ✅ Pyve resolves micromamba via: sandbox → user → PATH
- ✅ Bootstrap installation works (interactive and auto)

**3. Environment Management**
- ✅ Create conda env from `environment.yml`
- ✅ Create conda env from `conda-lock.yml`
- ✅ Reuse existing environment if it exists
- ✅ Run commands inside environment without shell activation
- ✅ Environment naming resolution (4-level priority)

**4. Validation**
- ✅ Lock file staleness detection
- ✅ `pyve doctor` command for health checks
- ✅ Backend-specific validation

**5. Guardrails**
- ✅ Never activates base environment
- ✅ Never falls back to pip when conda spec exists
- ✅ Never mixes runtimes implicitly
- ✅ Errors are explicit and actionable when micromamba is missing

**6. Documentation**
- ✅ README.md updated with backend selection
- ✅ CLI help text updated
- ✅ CI/CD examples provided
- ✅ Troubleshooting section updated

**7. Testing**
- ✅ All commands work with venv backend
- ✅ All commands work with micromamba backend
- ✅ Auto-detection works correctly
- ✅ Bootstrap works (interactive and auto)

### Phase 1 (v0.7.x) Complete

All criteria above have been met as of v0.7.13.

---

## 7. Policy Rules and Guardrails

**Decision Date:** 2026-01-05

### Core Policies

Pyve enforces these policies to prevent common mistakes:

**1. Never activate base automatically**
- Micromamba's base environment is never activated
- All environments are project-local in `.pyve/envs/<name>`

**2. Never mix pip into conda environments (unless explicit)**
- Warn if pip is detected in a micromamba environment
- `pyve doctor` flags this as a warning
- Future: Add `--allow-pip-in-conda` flag if needed

**3. Deterministic backend selection**
- Backend selection is always deterministic via config/spec detection
- Never accidentally use micromamba just because it's installed
- Explicit is better than implicit

**4. Never fall back to pip when conda spec exists**
- If `environment.yml` exists, micromamba backend is required
- Error with clear instructions if micromamba is missing
- No silent fallback to venv

**5. No implicit runtime mixing**
- Each project has one active backend at a time
- `pyve run` always uses the configured backend
- Override requires explicit `--backend` flag

### Rationale

These policies prevent the most common environment management mistakes:
- Accidentally polluting conda environments with pip packages
- Using wrong Python interpreter
- Mixing package managers
- Global environment pollution

---

## 6. CI/CD Integration

**Decision Date:** 2026-01-05

### Strategy: Minimal, Documentation-Focused

**Phase 1 (Initial Release):**

**Core Principle:** `pyve run` is the CI primitive. No special CI features needed.

**Key Features for CI:**

1. **`--no-direnv` flag**
   ```bash
   pyve --init --backend venv --no-direnv
   # Skips .envrc creation (not needed in CI)
   ```

2. **`pyve run` for explicit execution**
   ```bash
   pyve run pytest
   pyve run python -m build
   pyve run mypy src/
   # Works in any CI system without shell state
   ```

3. **Documentation examples**
   - GitHub Actions workflow examples
   - GitLab CI examples
   - Show caching strategies
   - No code changes needed

**Example GitHub Actions Workflow:**

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Pyve
        run: |
          curl -fsSL https://raw.githubusercontent.com/pointmatic/pyve/main/install.sh | bash
          echo "$HOME/.local/bin" >> $GITHUB_PATH
      
      - name: Cache environment
        uses: actions/cache@v3
        with:
          path: .venv
          key: venv-${{ hashFiles('requirements.txt') }}
      
      - name: Setup environment
        run: pyve --init --backend venv --no-direnv
      
      - name: Run tests
        run: pyve run pytest
```

**What Pyve Does NOT Do:**

❌ Create a GitHub Action (`uses: pointmatic/setup-pyve@v1`)  
❌ Add CI-specific logic or auto-detection  
❌ Manage CI caching (that's the CI system's job)  
❌ Auto-bootstrap in CI (require explicit `--auto-bootstrap` flag)  

**Rationale:**
- `pyve run` already provides explicit, deterministic execution
- CI/CD is a secondary use case (local development is primary)
- Keep Pyve simple and general-purpose
- Documentation is sufficient for CI integration
- Avoid scope creep and maintenance burden

**Phase 2 (Future):** 
- Could create GitHub Action if user demand warrants it
- But manual installation is acceptable long-term

---

## 5. Cross-Platform Support

**Decision Date:** 2026-01-05

### Strategy: macOS, Linux, and WSL

**Phase 1 (Initial Release):**

**Officially supported platforms:**
- macOS (native)
- Linux (native)
- Windows via WSL2 (Linux environment)

**Implementation:** No changes needed. WSL2 is a full Linux environment where Pyve works as-is.

**Documentation:**
```markdown
## Requirements

- macOS, Linux, or Windows (via WSL2) with Bash
- Either asdf or pyenv for Python version management
- direnv for automatic environment activation
- micromamba (optional) for conda-compatible environments
```

**Rationale:**
- WSL2 is the standard path for Windows developers doing Python/ML work
- No additional implementation effort required
- Native Windows support (PowerShell/cmd) would require:
  - Complete script rewrite
  - Different path handling
  - Different shell profile management
  - Significant testing effort
- No current priority for native Windows support

**Phase 2 (Future):** Native Windows support only if user demand warrants it. Would likely require Python rewrite for true cross-platform portability.

---

## 4. Channel Configuration

**Decision Date:** 2026-01-05

### Strategy: Respect environment.yml, Error if Missing

**Phase 1 (Initial Release):**

**Use channels from environment.yml:**
```yaml
# environment.yml
name: myproject
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.11
  - numpy
```

Pyve passes this directly to micromamba without modification.

**If no environment.yml exists:**
```bash
$ pyve --init --backend micromamba

ERROR: Micromamba backend requires environment.yml or conda-lock.yml

Create environment.yml with:
  name: myproject
  channels:
    - conda-forge
  dependencies:
    - python=3.11
```

**Rationale:**
- `environment.yml` is the natural place for channel configuration
- Micromamba handles channels correctly by default
- Explicit is better than implicit - user should create their own environment.yml
- No override logic needed in Phase 1

**Phase 2 (Future):** Add CLI flag for channel override if user demand warrants it:
```bash
pyve --init --backend micromamba --channel conda-forge --channel pytorch
```

**Common Channels:**
- `conda-forge` - Community-maintained, most popular, free
- `defaults` - Anaconda's official channel (requires license for commercial use)
- `pytorch` - PyTorch-specific packages
- `nvidia` - NVIDIA CUDA packages

---

## 3. Lock File Management

**Decision Date:** 2026-01-05

### Strategy: Consume, Don't Generate

**Phase 1 (Initial Release):** Support consuming lock files, but don't generate them.

**File Detection Order:**
1. `conda-lock.yml` (highest priority - exact reproducibility)
2. `environment.yml` (fallback - loose specification)
3. Error if neither exists

**Implementation:**
```bash
# If conda-lock.yml exists
micromamba create -f conda-lock.yml

# If only environment.yml exists
micromamba create -f environment.yml
```

**User Workflow (Manual Lock Generation):**
```bash
# Development: use environment.yml directly
pyve --init --backend micromamba

# Production: generate lock file first
conda-lock -f environment.yml -p osx-arm64 -p linux-64
pyve --init --backend micromamba  # Uses conda-lock.yml
```

**Rationale:**
- Don't reinvent the wheel - `conda-lock` tool already exists and works well
- Let users/teams choose their workflow (loose vs locked)
- Pyve supports both patterns without forcing one
- Reduces complexity in Phase 1
- Manual `conda-lock` workflow is acceptable long-term

**Note:** `conda-lock` is a standalone tool compatible with conda, mamba, and micromamba. It generates unified lock files that micromamba can consume natively.

### Lock File Validation (Phase 1)

**Warn on stale lock files (interactive mode only):**

```bash
$ pyve --init --backend micromamba

WARNING: Lock file may be stale
  environment.yml:  modified 2026-01-05 10:30:00
  conda-lock.yml:   modified 2025-12-15 14:20:00

Using conda-lock.yml for reproducibility.
To update lock file:
  conda-lock -f environment.yml -p osx-arm64

Continue anyway? [Y/n]: _
```

**Info on missing lock file (interactive mode only):**

```bash
$ pyve --init --backend micromamba

INFO: Using environment.yml without lock file.

For reproducible builds, consider generating a lock file:
  conda-lock -f environment.yml -p osx-arm64

This is especially important for CI/CD and production.

Continue anyway? [Y/n]: _
```

**Detection logic:**
- Compare modification times: `mtime(environment.yml) > mtime(conda-lock.yml)`
- Only warn in interactive mode (no prompts in CI)
- User can continue or abort to regenerate lock file

**Consequences of stale lock files:**
- **Version mismatch:** Dependencies don't match environment.yml (confusing but not critical)
- **Missing dependencies:** New packages in environment.yml not installed (fails fast)
- **CI/CD divergence:** Local uses environment.yml, CI uses stale lock file (dangerous - hard to debug)
- **Security issues:** Security patches in environment.yml not applied (rare but serious)

**Rationale:**
- Catches CI/CD divergence (the most dangerous case)
- Educates users about lock file best practices
- Doesn't force a workflow - respects user choice
- Silent in CI/CD (non-interactive mode)

**Phase 2 (Future):** 
- Add `pyve lock` command if user demand warrants it
- Add `--strict` flag to error on stale/missing lock files
- Add configuration option: `lock_file_policy: warn|strict|ignore`

---

## 2b. Multiple Environments Per Project

**Decision Date:** 2026-01-05

### Phase 1 (Initial Release): Single Environment

One environment per project. Keep it simple.

```bash
pyve --init --backend micromamba
# Creates: .pyve/envs/<project-name>
```

### Phase 2 (Future Feature): Named Environments

**Status:** Documented for future implementation. Not in MVP.

**Use Cases:**
- Development vs production environments
- Testing different Python versions
- Backend comparison (venv vs micromamba)
- ML experimentation (different CUDA versions, frameworks)

**Commands:**
```bash
pyve --init --env dev --backend venv
pyve --init --env prod --backend venv
pyve --init --env torch-gpu --backend micromamba

pyve envs                           # List all environments
pyve env list --verbose             # Detailed view
pyve env info dev                   # Single environment info

pyve activate torch-gpu             # Switch active environment
pyve run --env prod python main.py  # One-off command in specific env
```

**Directory Structure:**
```
.pyve/
  config                # Project-wide config
  envs/
    dev/                # Named environment
    prod/
    torch-gpu/
    .registry           # Environment metadata (JSON)
  current -> envs/dev/  # Symlink to active environment
```

**Activation Model (Hybrid):**

**Implicit (Happy Path):**
- direnv auto-activates default environment
- Shell prompt shows active: `(micromamba:dev) user@host project %`
- Normal commands use active environment

**Explicit Override:**
- `pyve activate <env>` - Switch active environment (persistent)
- `pyve run --env <env> <cmd>` - One-off command (temporary)
- CI/CD always uses explicit `--env` flag

**Environment Listing Output:**
```bash
$ pyve envs

Environments in /Users/user/projects/ml-pipeline:

  * dev              (venv)       Python 3.11.7    [active]
    prod             (venv)       Python 3.11.7
    torch-gpu        (micromamba) Python 3.11.6
    torch-cpu        (micromamba) Python 3.11.6

Active: dev (via .pyve/current)
Default: dev (via .pyve/config)
```

**Configuration:**
```yaml
# .pyve/config
default_env: dev

environments:
  dev:
    backend: venv
    python_version: "3.11"
    
  prod:
    backend: venv
    python_version: "3.11"
    requirements: requirements-prod.txt
    
  torch-gpu:
    backend: micromamba
    env_file: environment-gpu.yml
```

**Rationale:**
- Solves real ML/data science workflow problems
- Keeps Phase 1 simple (90% of use cases)
- Hybrid activation model balances convenience and explicitness
- No shared dependency caches (avoid complexity, maintain conda's reproducibility guarantees)
- Shared micromamba binary is acceptable (tool vs packages)

---

## 2a. Shell Prompt Configuration

**Decision Date:** 2026-01-05

### Format

Show backend and environment name: `({backend}:{env_name})`

**Examples:**
```bash
(venv:codoc) pointmatic@Michaels-MB-Pro-M3 codoc %
(micromamba:ml-pipeline) pointmatic@Michaels-MB-Pro-M3 ml-pipeline %
```

### Rationale

- **Explicit backend visibility:** Clear which backend is active (venv vs micromamba)
- **Debugging aid:** Useful when mixing backend types across projects
- **Prevents mistakes:** Visual confirmation of active environment and backend
- **Matches conventions:** Similar to conda/venv prompt modifications

### Implementation

Via `.envrc` generated by `pyve --init`:

```bash
# .envrc (venv backend)
VENV_DIR=".venv"
if [[ -d "$VENV_DIR" ]]; then
    source "$VENV_DIR/bin/activate"
    export PS1="(venv:${PWD##*/}) $PS1"
fi

# .envrc (micromamba backend)
ENV_NAME="ml-pipeline"
export PS1="(micromamba:$ENV_NAME) $PS1"
```

### Configuration

Make it configurable in `.pyve/config`:

```yaml
prompt:
  show: true                        # Show environment in prompt
  format: "({backend}:{env_name})"  # Customizable format
  # Alternative formats:
  # format: "({env_name})"          # Environment name only
  # format: "[{backend}]"           # Backend only
```

---

## 1. Environment Naming Strategy

**Decision Date:** 2026-01-05

### Default Behavior

**Storage Location:** Project-local (`.pyve/envs/<name>`)

**Naming Resolution Order:**
1. CLI flag: `--env-name` (highest priority)
2. `.pyve/config` → `micromamba.env_name`
3. `environment.yml` → `name:` field
4. Project directory basename (sanitized, fallback)

### Example

```bash
# Project: /Users/alice/projects/ml-pipeline
# environment.yml contains: name: ml-dev

pyve --init --backend micromamba
# Creates: /Users/alice/projects/ml-pipeline/.pyve/envs/ml-dev
```

### Rationale

**Why project-local:**
- Isolation: each project owns its environment
- No global namespace pollution
- Easy cleanup with `pyve --purge`
- Portable: can move/copy project directory
- Avoids conflicts between projects with same name

**Why respect `environment.yml` name field:**
- Team compatibility (honors existing conda conventions)
- No collisions due to project-local storage
- Override capability via CLI flag or config

**Why allow override:**
- Multiple environments per project (future feature)
- Team conventions
- Legacy compatibility

### Name Sanitization Rules

- Convert to lowercase
- Replace spaces and special characters with hyphens
- Must start with letter or underscore
- Only alphanumeric, hyphens, underscores allowed
- Max 255 characters
- Reserved names: base, root, default

### Edge Cases

**Multiple projects with same environment.yml name:**
```bash
# Project A: /Users/alice/work/project-a/.pyve/envs/shared-ml-env
# Project B: /Users/alice/work/project-b/.pyve/envs/shared-ml-env
# No conflict - different paths
```

