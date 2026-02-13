# Pyve Version History
See `docs/guide_versions_spec.md`

---

## High-Level Feature Checklist

### Phase 3: Machine Learning Improvements
- [x] Python 3.12 distutils compatibility shim for TensorFlow/Keras
- [x] Pyve-managed local dev/test runner environment
- [ ] Implement Bootstrap in integration tests

---

## v1.1.2: Fix Linux sed append in insert_pattern_in_gitignore_section [Implemented]
- [x] Fix: `insert_pattern_in_gitignore_section()` Linux `sed -i` append syntax missing literal newline — entries were concatenated without line breaks on Linux/CI
- [x] Bump pyve version to 1.1.2

### Notes
* Root cause: the Linux branch of `sed -i` used `a\\${pattern}` on a single line, which concatenated entries without newlines. The macOS branch already used a literal newline after `a\\`. Fixed by matching the macOS syntax on Linux.
* Caught by `test_gitignore_updated_for_micromamba` on GitHub Actions (macOS `sed` worked locally, GNU `sed` on Linux did not).

---

## v1.1.1: License migration from MPL-2.0 to Apache-2.0 [Implemented]
- [x] Replace `LICENSE` file with Apache License 2.0 full text
- [x] Update license header in all shell source files (`pyve.sh`, `lib/*.sh`)
- [x] Update `README.md` license badge and license section
- [x] Bump pyve version to 1.1.1

---

## v1.1.0: Testing and spec updates for v1.0.0 .gitignore changes [Implemented]

### Bats unit tests (`tests/unit/test_utils.bats`)
- [x] `gitignore_has_pattern`: exact match found, not found, special characters, partial line
- [x] `insert_pattern_in_gitignore_section`: inserts after section comment, skips if already present, falls back to append when section missing, creates file if missing
- [x] `write_gitignore_template`: fresh file (no existing `.gitignore`), produces correct template
- [x] `write_gitignore_template`: existing `.gitignore` with user entries — template at top, user entries preserved below
- [x] `write_gitignore_template`: idempotent — running twice produces identical output
- [x] `write_gitignore_template`: self-healing — removes duplicate template entries from user section
- [x] `write_gitignore_template`: preserves user section comments
- [x] `remove_pattern_from_gitignore`: existing tests still pass with exact-match behavior

### Integration tests (`tests/integration/`)
- [x] Strengthen `test_gitignore_updated` (venv) — verify template sections, all expected entries
- [x] Strengthen `test_gitignore_updated_for_micromamba` — verify template entries, `.pyve/envs` present, env name NOT present
- [x] New: `test_gitignore_idempotent` — `pyve --init` twice produces identical `.gitignore`
- [x] New: `test_gitignore_self_healing` — user entries preserved, template entries restored at top
- [x] New: `test_gitignore_purge_preserves_permanent_entries` — purge removes only `.venv`/`.env`/`.envrc`

### Spec updates
- [x] Update `features.md` — stale version references (`3.13.7` → `3.14.3`, `0.5.10` → `1.1.0`), `.gitignore` feature description updated
- [x] Bump pyve version to 1.1.0

### Notes
* Idempotency test caught a real bug in `write_gitignore_template()`: comment lines and blank lines from the existing file were not being deduplicated against the template, causing accumulation on repeated runs. Fixed by including comment lines in the template dedup set and collapsing consecutive blank lines.
* All 233 Bats unit tests pass (56 in `test_utils.bats`)

---

## v1.0.0: Improvements to .gitignore management [Implemented]
- [x] Add Python build artifacts to `.gitignore` template (`__pycache__`, `*.egg-info`)
- [x] Add pytest artifacts to `.gitignore` template (`.pytest_cache/`)
- [x] Add coverage artifacts to `.gitignore` template (`.coverage`, `coverage.xml`, `htmlcov/`)
- [x] Add Pyve internal dev/test runner environment to `.gitignore` (`.pyve/testenv`)
- [x] Self-healing `.gitignore` via `write_gitignore_template`: Pyve-managed entries at top, user entries preserved below
- [x] Target virtual environment additions (`.venv`, `.env`, `.envrc`) to the `# Pyve virtual environment` section via `insert_pattern_in_gitignore_section`
- [x] Fix: remove inline comments from `.gitignore` — git only recognizes `#` as a comment at the start of a line
- [x] `pyve --purge` still removes `.venv`, `.env`, `.envrc`; permanent hygiene entries are preserved
- [x] Bump pyve version to 1.0.0

### Notes
* `.gitignore` does not support inline comments — a line like `.env  # comment` is treated as a literal pattern, not `.env` with a comment. All comments are now on their own line (section headers only).
* `write_gitignore_template()` rebuilds `.gitignore` on every `pyve --init` via a temp file: writes the Pyve-managed template at the top, then passes through all non-template lines from the existing file verbatim. This makes the file self-healing and idempotent — repeated runs converge to a stable layout without unnecessary git diffs.
* New `insert_pattern_in_gitignore_section()` inserts entries after a section comment (e.g. `# Pyve virtual environment`), falling back to append if the section is not found
* `gitignore_has_pattern()` and `remove_pattern_from_gitignore()` use exact line matching (no inline comment handling needed)
* Both venv and micromamba init paths use the same template + section-aware insertion approach

---

## v0.9.9: Gitignore hygiene on init [Implemented]
- [x] Add `__pycache__` and `.pyve/testenv` to `.gitignore` on `pyve --init` (venv backend)
- [x] Add `__pycache__` and `.pyve/testenv` to `.gitignore` on `pyve --init` (micromamba backend)
- [x] Intentionally leave these entries on `pyve --purge` (permanent hygiene, not tied to env lifecycle)
- [x] Bump pyve version to 0.9.9

### Notes
* `__pycache__` is a Python build artifact that should never be committed
* `.pyve/testenv` contains the dev/test runner virtual environment
* Both are "permanent hygiene" entries — `purge_gitignore()` does not remove them since they remain useful even without an active Pyve environment

## v0.9.8a: Local integration test reliability (no user-facing changes) [Implemented]
- [x] Auto-pin Python version under pytest locally (not just CI) to prevent tests from triggering a slow Python build when the default version isn't installed
- [x] Add `python3 --version` fallback to `_detect_version_manager_python_version` for tmp directories with no `.tool-versions`/`.python-version`
- [x] Add default timeout (120s) to `PyveRunner.run()` so tests fail with a clear `TimeoutError` instead of hanging indefinitely

### Notes
This is a test-only miniversion. It does not change Pyve runtime behavior for end users and does not require a `pyve.sh` version bump.
* Root cause: `asdf current python` returns exit 126 in tmp test directories (no `.tool-versions`), so version pinning silently failed and tests tried to build the new default Python from source.

---

## v0.9.8: Python 3.14.3 default update [Implemented]
- [x] Update default Python version to 3.14.3
- [x] Update documentation to reflect the new default version
- [x] Bump pyve version to 0.9.8

### Notes
* Updated `DEFAULT_PYTHON_VERSION` from `3.14.2` to `3.14.3` in `pyve.sh`
* Updated `VERSION` from `0.9.7` to `0.9.8` in `pyve.sh`
* Updated default Python version reference in `README.md`

---

## v0.9.7a: Local integration test reliability (no user-facing changes) [Implemented]
- [x] Ensure pytest integration harness sets `PYVE_TEST_AUTO_INSTALL_PYTEST=1` under pytest so `pyve test` can bootstrap pytest in the dev/test runner env
- [x] Allow `PyveRunner.init()` to forward stdin `input` for commands that prompt (e.g. `--init --force` confirmation)
- [x] Update integration tests that call `--init --force` to send confirmation input locally (avoid relying on `PYVE_FORCE_YES`)

#### Notes
This is a test-only miniversion. It does not change Pyve runtime behavior for end users and does not require a `pyve.sh` version bump.

---

## v0.9.7: Re-init UX reliability + corrupted config hardening [Implemented]
- [x] Ensure interactive `pyve --init` re-init prompt shows recorded/current version info in stdout
- [x] Make `pyve --init --update` fail with non-zero exit when `.pyve/config` is corrupted/unparseable
- [x] Prevent prompt-bypass leakage across integration tests (autouse cleanup of `PYVE_*` env vars)
- [x] Make integration harness non-interactive only in CI (avoid forcing `PYVE_FORCE_YES` locally)
- [x] Bump pyve version to 0.9.7

#### Problem
Interactive re-init flows and update mode could behave unexpectedly under test harness conditions (prompts skipped due to leaked env vars) and in real projects with corrupted `.pyve/config` (update reporting success when config cannot be safely updated).

#### Goal
Improve reliability of re-initialization UX and ensure update mode fails fast when project configuration is corrupted.

---

## v0.9.6: Config-aware purge/doctor for custom venv directories [Implemented]
- [x] Update `pyve doctor` to honor `.pyve/config` (`venv.directory`) when detecting venv environments
- [x] Update `pyve --purge` to honor `.pyve/config` (`venv.directory`) when removing venv environments
- [x] Bump pyve version to 0.9.6

#### Problem
Projects can initialize with a custom venv directory (e.g. `pyve --init my_venv`). Historically, `pyve doctor` and `pyve --purge` assumed the venv lives at `.venv`, which can cause incorrect diagnostics or leave the custom venv behind.

#### Goal
Make diagnostics and purge behavior follow the project configuration by default while preserving backward compatibility.

---

## v0.9.5: CI hotfix for custom venv dirs + doctor config awareness [Implemented]
- [x] Fix integration harness to pass custom venv directory as a positional argument to `pyve --init` (no unsupported `--venv-dir` flag)
- [x] Update `pyve doctor` to honor `.pyve/config` (`venv.directory`) when detecting venv environments
- [x] Bump pyve version to 0.9.5

#### Problem
CI integration tests that initialize with a custom venv directory (`venv_dir=...`) can fail if the test harness passes an unsupported flag or if `pyve doctor` assumes the venv is always at `.venv`.

#### Goal
Keep integration tests and diagnostics reliable across environments while preserving backward compatibility.

---

## v0.9.4: `pyve doctor` reports dev/test runner environment status
- [x] Report the presence and basic health of the dev/test runner environment (`.pyve/testenv/venv`)
- [x] Show test runner Python version (when present)
- [x] Detect whether `pytest` is installed in the dev/test runner environment
- [x] Decide UX: always show test runner status vs only with an explicit flag (e.g. `pyve doctor --testenv`) (Decision: always show)
- [x] Keep the behavior non-invasive (no installs, no network access, no creation)
- [x] Add integration tests for doctor output covering test runner present/missing
- [x] Bump pyve version to 0.9.4

#### Problem
`pyve doctor` currently only reports on the project runtime environment (venv or micromamba). Pyve now has a dedicated dev/test runner environment, but there is no built-in diagnostic for whether it exists or whether `pytest` is available there.

#### Goal
Make it easy to understand test tooling readiness without changing state:
1) `pyve doctor` should help explain test failures caused by a missing or broken dev/test runner environment.
2) Diagnostics should remain non-invasive and should never create or mutate environments.

#### Proposed UX
`pyve doctor` (or `pyve doctor --testenv`, depending on the UX decision):
- `✓ Test runner: .pyve/testenv/venv` (or `⚠ Test runner: not found`)
- `✓ Test runner Python: X.Y.Z` (when available)
- `✓ pytest: installed` / `⚠ pytest: missing` (with a suggestion: `pyve testenv --install -r requirements-dev.txt` or `pyve test`)

---

## v0.9.3: Gentle test tooling guidance + Pyve philosophy alignment [Implemented]
- [x] Ensure `pyve test` and test tooling flows feel “easy and natural” while staying non-invasive by default
- [x] Auto-create/upgrade the dev/test runner environment when needed (upgrade-friendly)
- [x] Add gentle interactive prompt to install `pytest` when missing (opt-in)
- [x] Clarify and align purge semantics with the “Pyve manages what it creates” principle
- [x] Update documentation to reflect the philosophy and workflows (README, tests/README.md, CONTRIBUTING.md)
- [x] Bump pyve version to 0.9.3

#### Problem
v0.9.2 introduces a separate dev/test runner environment, but the workflow can still feel “manual” (users may need to explicitly initialize a test environment before running `pyve test`). Additionally, Pyve must avoid becoming “bossy” by silently installing tools like `pytest` without consent.

#### Goal
Make test workflows feel first-class:
1) The first time a developer runs tests, Pyve should guide them smoothly.
2) Pyve should remain respectful: it should not install networked dependencies without explicit user intent.

#### Proposed UX
1. `pyve test [pytest args...]`
   - If `.pyve/testenv/venv` is missing, create it automatically.
   - If `pytest` is missing in the test runner env, prompt:
     - "pytest is not installed in the dev/test runner environment. Install now? [y/N]"
     - If yes: install either from a discovered requirements file (e.g. `requirements-dev.txt`) or fall back to `pip install pytest`.
     - If no: exit with a clear message explaining how to install.

2. `pyve --init` / `pyve --init --force`
   - Ensure the project environment is created/recreated as usual.
   - Ensure the dev/test runner environment can be upgraded/created without clobbering the project environment.

3. `pyve --purge`
   - Default behavior should remove Pyve-managed artifacts, including `.pyve/testenv`, unless an explicit keep flag is provided.

#### Documentation updates (Pyve vibe/philosophy)
- README.md: add a short “Testing” section that frames Pyve’s philosophy (easy + reproducible + non-invasive), and document `pyve test` and the interactive prompt behavior.
- tests/README.md: explain how Pyve’s own integration tests avoid clobbering developer environments and how to use `pyve test` / testenv.
- CONTRIBUTING.md: document contributor workflow for running tests, including the separation between Pyve-managed project env and the dev/test runner env.

#### Notes
This version is explicitly about UX and philosophy alignment: Pyve should manage what it creates, guide gently, and avoid unprompted network installs.

---

## v0.9.2: Pyve-managed local dev/test runner environment [Implemented]
- [x] Add first-class support for a dedicated dev/test runner environment that is separate from the Pyve-managed project environment
- [x] Provide a command to provision/install test tooling without mutating or depending on the project environment
- [x] Provide a command to run tests using the dedicated test runner environment
- [x] Ensure `pyve --init --force` never deletes or corrupts the dev/test runner environment
- [x] Bump pyve version to 0.9.2

#### Problem
Pyve intentionally creates/purges the project environment (commonly `.venv`) during initialization and re-initialization. If developers also install test tooling (e.g. `pytest`) into that same environment, running `pyve --init --force` can remove those dev/test dependencies, making local test execution brittle.

#### Goal
Allow developers to use Pyve on every Python project while still having a stable, reproducible way to install and run `pytest` (and other dev/test tools) that does not get clobbered by Pyve’s management of the project environment.

#### Proposed UX
- [x] `pyve testenv --init`: Create/manage a dedicated dev/test runner environment (default directory: `.pyve/testenv/`)
- [x] `pyve testenv --install -r requirements-dev.txt` (or similar): Install dev/test dependencies into the test runner environment
- [x] `pyve test ...`: Run `pytest` (or other tools) via the test runner environment, independent of the project environment

#### Functional Requirements
1. Separation: The dev/test runner environment must be stored outside the managed project environment directory (e.g. not inside `.venv/`).
2. Idempotency: Re-running `pyve testenv --init` must be safe and not reinstall unless requested.
3. Non-clobbering: `pyve --init`, `pyve --init --force`, and `pyve --purge` must not delete the dev/test runner environment unless an explicit dev/test runner purge command is invoked.
4. Predictable interpreter: The dev/test runner environment must use an explicit Python version selection policy (documented) and must not unexpectedly change when the project environment changes.
5. Tooling access: `pytest` (and other tools) must be executed from the test runner environment, while running against the project directory under test.

#### Test Plan
- [x] Integration test: initialize a project environment, install `pytest` into the dev/test runner environment, run `pyve test`, then run `pyve --init --force` and verify `pyve test` still works
- [ ] Integration test: verify `pyve run` continues to execute within the project environment and does not depend on the dev/test runner environment

---

## v0.9.1c: Local integration test reliability + `pyve run` venv behavior [Implemented]
- [x] Make pytest integration tests non-interactive for `pyve --init --force` by setting `PYVE_FORCE_YES=1` in the test runner environment
- [x] Allow local test runs to pin `pyve --init` to the runner-installed Python version (test harness sets `PYVE_TEST_PIN_PYTHON=1` when running under pytest)
- [x] Fix `pyve run` for venv backend to allow executing commands not located in `.venv/bin/` (e.g. `bash`), while still preferring venv-provided executables
- [x] Fix `test_force_purges_existing_venv` to assert the force warning message from stderr (warnings are emitted on stderr)

#### Problem
Local integration tests can fail when `pyve --init --force` prompts for confirmation (stdin is EOF under subprocess capture), and when `pyve run` is asked to run non-venv executables such as `bash`.

#### Notes
Mix of test-harness changes and runtime behavior change.

---

## v0.9.1b: CI stability improvements for venv integration tests [Implemented]
- [x] Pin venv/auto `pyve --init` integration tests to the runner-installed Python version in CI (avoids flaky attempts to install the default Pyve Python version)
- [x] Re-enable venv integration tests previously skipped in CI due to "complex pyenv setup" (CI now provisions pyenv)

#### Notes
Test-only change. No changes to runtime behavior and no `pyve.sh` version bump.

---

## v0.9.1a: Documentation clarifications [Implemented]
- [x] Update README default Python version to match current default
- [x] Document Python 3.12+ distutils shim behavior and escape hatch (PYVE_DISABLE_DISTUTILS_SHIM=1)

#### Notes
Documentation-only change. No changes to runtime behavior and no `pyve.sh` version bump.

---

## v0.9.1: Prevent unit tests from deleting user micromamba [Implemented]
- [x] Sandbox HOME in unit tests that create/remove user-sandbox micromamba (prevents accidental deletion of ~/.pyve/bin/micromamba)
- [x] Bump pyve version to 0.9.1

#### Problem
Some unit tests in `tests/unit/test_micromamba_core.bats` create and remove `"$HOME/.pyve/bin/micromamba"` as part of their setup/cleanup. When those tests run with the developer’s real `HOME`, they can delete the real micromamba binary in `~/.pyve/bin/`.

#### Fix
Sandbox `HOME` to a temporary test directory in `tests/unit/test_micromamba_core.bats` (and restore it in `teardown`) so tests cannot mutate the developer’s real `~/.pyve` directory.

#### Notes
If `~/.pyve/bin/micromamba` was deleted previously, reinstall micromamba to the user sandbox (e.g. via `pyve --init --backend micromamba --auto-bootstrap --bootstrap-to user`).

## v0.9.0: Support Tensorflow/Keras for Python 3.12+ [Implemented]
- [x] Add Python 3.12+ distutils compatibility shim via sitecustomize.py in env site-packages (idempotent)
- [x] Ensure packaging prerequisites are installed in the environment (setuptools, wheel)
- [x] Add escape hatch (PYVE_DISABLE_DISTUTILS_SHIM=1) and light probe + tests/smoke coverage (terminal + Jupyter)
- [x] Bump pyve version to 0.9.0

#### Problem
On Python 3.12+, the standard library module distutils is removed. Some TensorFlow/Keras distributions (notably certain conda-forge builds) still import distutils at runtime (during import tensorflow / import keras), causing ModuleNotFoundError: No module named 'distutils'.

#### Goal
When Pyve provisions a Python 3.12 environment intended for ML workloads, Pyve must ensure that importing TensorFlow/Keras does not fail due to missing distutils.

#### Functional Requirements
1. Detect Python 3.12+ environments: If the environment Python version is >= 3.12, enable compatibility measures.
2. Install packaging prerequisites: Ensure setuptools and wheel are installed in the environment.
3. Enable setuptools distutils shim at interpreter startup: 
  - Pyve must install a startup-time shim that runs before user code and sets:
    - SETUPTOOLS_USE_DISTUTILS=local (unless already set)
    - imports setuptools early to activate its vendored distutils implementation.

### Notes
1. Idempotency / ownership: Prefer writing a Pyve-managed sitecustomize.py only when it does not exist, or update it only when it contains a clear Pyve marker header.
2. Locating site-packages: Use the environment interpreter to resolve the correct site-packages directory (not hardcoded paths).
3. Backend parity: Apply the shim consistently for both venv and micromamba provisioned environments.
4. Testing approach: If TensorFlow/Keras installation is too heavy for CI, validate that sitecustomize runs (env var set, setuptools importable) and that the escape hatch prevents creation.

#### Recommended mechanism
Write a sitecustomize.py into the environment’s site-packages directory:
```python
import os
os.environ.setdefault("SETUPTOOLS_USE_DISTUTILS", "local")
import setuptools  # noqa: F401
```
The shim must be created only if it does not already exist or if Pyve manages it idempotently.

#### Provide an escape hatch
Pyve must allow disabling the shim (e.g., env var PYVE_DISABLE_DISTUTILS_SHIM=1 or config flag).

#### Verification / Acceptance Criteria
In a freshly provisioned Pyve Python 3.12 environment:
- `python -c "import tensorflow"` succeeds (when TensorFlow is installed).
- `python -c "import keras"` succeeds (when Keras is installed).
- `python -c "import distutils"` succeeds (or at least does not break TensorFlow/Keras imports).

A quick smoke test should pass under both:
- terminal Python execution
- Jupyter kernel execution

#### Scope: When this helps
Helps in both Jupyter and normal applications

This is not “Jupyter-only.” If TensorFlow imports distutils, it will fail anywhere: scripts, CLIs, services, notebooks. A sitecustomize.py shim helps globally for that environment because it runs at interpreter startup for all entrypoints.
