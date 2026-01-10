# Pyve Version History
See `docs/guide_versions_spec.md`

---

## High-Level Feature Checklist

### Phase 3: Machine Learning Improvements
- [x] Python 3.12 distutils compatibility shim for TensorFlow/Keras

---

## v0.9.2: Pyve-managed local dev/test runner environment [Planned]
- [ ] Add first-class support for a dedicated dev/test runner environment that is separate from the Pyve-managed project environment
- [ ] Provide a command to provision/install test tooling without mutating or depending on the project environment
- [ ] Provide a command to run tests using the dedicated test runner environment
- [ ] Ensure `pyve --init --force` never deletes or corrupts the dev/test runner environment

#### Problem
Pyve intentionally creates/purges the project environment (commonly `.venv`) during initialization and re-initialization. If developers also install test tooling (e.g. `pytest`) into that same environment, running `pyve --init --force` can remove those dev/test dependencies, making local test execution brittle.

#### Goal
Allow developers to use Pyve on every Python project while still having a stable, reproducible way to install and run `pytest` (and other dev/test tools) that does not get clobbered by Pyve’s management of the project environment.

#### Proposed UX
- [ ] `pyve testenv --init` (or similar): Create/manage a dedicated dev/test runner environment (default directory: `.pyve/testenv/`)
- [ ] `pyve testenv --install -r requirements-dev.txt` (or similar): Install dev/test dependencies into the test runner environment
- [ ] `pyve test ...`: Run `pytest` (or other tools) via the test runner environment, independent of the project environment

#### Functional Requirements
1. Separation: The dev/test runner environment must be stored outside the managed project environment directory (e.g. not inside `.venv/`).
2. Idempotency: Re-running `pyve testenv --init` must be safe and not reinstall unless requested.
3. Non-clobbering: `pyve --init`, `pyve --init --force`, and `pyve --purge` must not delete the dev/test runner environment unless an explicit dev/test runner purge command is invoked.
4. Predictable interpreter: The dev/test runner environment must use an explicit Python version selection policy (documented) and must not unexpectedly change when the project environment changes.
5. Tooling access: `pytest` (and other tools) must be executed from the test runner environment, while running against the project directory under test.

#### Test Plan
- [ ] Integration test: initialize a project environment, install `pytest` into the dev/test runner environment, run `pyve test`, then run `pyve --init --force` and verify `pyve test` still works
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
