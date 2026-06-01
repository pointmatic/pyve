# pyve-environment-dependencies-repo_gitbetter.md

Concrete instance of `pyve-environment-dependencies-template.md` for the **gitbetter** repo.
It enumerates the root development environment and the test environment(s) required to
develop and completely test the codebase.

> **Related docs**
> - `features.md` — what gitbetter does (scope, requirements, behavior).
> - `tech-spec.md` — how gitbetter is built (architecture, dependencies, testing strategy).
> - `pyve-environment-dependencies-template.md` — the template this document instantiates.
> - Pyve backends reference: <https://pointmatic.github.io/pyve/backends/>

---

## 1. Document Metadata

| Field | Value |
|-------|-------|
| **Repo name** | `gitbetter` |
| **Primary language(s)** | Bash 4.0+ (product); Python 3.14 (tooling only) |
| **Pyve version** | `pyve 2.6.2` (`.pyve/config` records `2.4.0` — stale; the active CLI is 2.6.2) |
| **Doc status** | `Approved` |
| **Last updated** | 2026-05-31 |
| **Author / maintainer** | Pointmatic |

---

## 2. Conventions & Terminology

This document uses the terminology defined in `pyve-environment-dependencies-template.md` §2
(purpose surfaces `run`/`test`/`utility`/`temp`, backends, dependency source classes
`pip`/`conda`/`system`/`vendored`/`runtime`, and the structured attribute vocabularies).

**Repo-specific terms:**

- **Product code** — the Bash command scripts (`gitbetter.sh`, `git-push.sh`, `git-tag.sh`)
  and shared library (`lib/ui.sh`). gitbetter has **no pyve-managed `run` surface**: the
  product is distributed as Homebrew-installed Bash scripts that execute directly on the
  user's system, not inside any pyve environment.
- **Sandbox repo** — an ephemeral `mktemp -d` git repository (with optional bare remote)
  created per BATS test by `tests/test_helper/common-setup.bash`. See the `temp` surface.

---

## 3. Backend Catalog

| Backend | Status | Env location | Dependency manifest | Lock artifact | Init command |
|---------|--------|--------------|---------------------|---------------|--------------|
| `venv` | **canonical (default)** | `.venv/` (root), `.pyve/testenv/venv/` (testenv) | `requirements.txt` | `requirements.txt` w/ `--hash` (pip-tools) | `pyve init` / `pyve testenv init` |
| `micromamba` | canonical | `.pyve/envs/<hash>/` | `environment.yml` | `conda-lock.yml` (`pyve lock`) | `pyve init --backend micromamba` |
| `homebrew` | **proposed** | host PATH (not pyve-materialized) | `Brewfile` (none committed yet) | pinned versions in CI workflow | n/a — see §8 |
| `apt` | **proposed** | host PATH (not pyve-materialized) | apt package list (none committed yet) | pinned versions in CI workflow | n/a — see §8 |
| `none` | n/a (bare OS) | host filesystem / runtime | none | none | n/a — implicit default |

**Backend value convention:** values are specific mechanism names. `homebrew`/`apt` denote
the real (non-canonical, `proposed`) mechanisms that install gitbetter's test toolchain;
`none` means no formal configuration mechanism (bare OS), used here for the runtime-created
`sandbox` surface.

**Default-backend assumption holds:** both pyve-managed environments use `venv`. The
`homebrew`/`apt` rows are listed because gitbetter's *actual* test dependencies (`bats`,
`shellcheck`) are installed outside any pyve backend; this is the central finding of this
document and the driver for §8.

---

## 4. Environment Inventory

### 4.0 Environment Surface Enumeration

```yaml
project: gitbetter
description: Homebrew-installable Bash scripts that streamline repetitive git workflows (push, tag).
envs:
  root:
    purpose: utility
    backend: venv
    default: false
    app_type: cli              # hosts the project-guide tooling CLI
    frameworks: [none]
    languages: [python]
  testenv:
    purpose: test
    backend: venv
    default: true
    app_type: none             # a test harness, not an app
    frameworks: [bats, shellcheck]
    languages: [bash]
  sandbox:
    purpose: temp
    backend: none              # ephemeral mktemp -d git repos, not pyve-managed
    default: false
    app_type: none
    frameworks: [none]
    languages: [bash]
```

### 4.1 Inventory Table

| # | Environment name | Purpose | Backend | Default? | App type | Frameworks | Languages |
|---|------------------|---------|---------|----------|----------|------------|-----------|
| 0 | `root` (`.venv/`) | `utility` | `venv` | n/a | `cli` | `none` | `python` |
| 1 | `testenv` (`.pyve/testenv/venv/`) | `test` | `venv` | yes | `none` | `bats`, `shellcheck` | `bash` |
| 2 | `sandbox` (`mktemp -d`) | `temp` | `none` | no | `none` | `none` | `bash` |

**Why this many test environments:** **One** test environment (`testenv`) is sufficient and
complete. Every test category — ShellCheck static analysis, BATS unit tests, and BATS
integration tests — shares a single toolchain (`bash` + `git` + `bats` + `bats-support` +
`bats-assert` + `shellcheck`) with no divergent dependency sets, frameworks, or runtime
versions. Integration tests differ from unit tests only by spinning up ephemeral `sandbox`
git repos at runtime, not by requiring different installed dependencies, so splitting them
into a second environment would be redundant. The `sandbox` surface is enumerated for
completeness but is a runtime artifact of the test harness, not a provisioned environment.

---

## 5. Environment Specifications

### 5.0 Environment: `root` (purpose: `utility`)

- **Purpose (surface):** `utility` — hosts the `project-guide` LLM/spec tooling CLI used to
  develop this repo. It does **not** host the product (Bash scripts) or the test runners.
- **Attributes:** app_type `cli`; frameworks `none`; languages `python`.
- **Backend & rationale:** `venv` — pure-PyPI tooling, fast to create, no scientific/conda
  dependencies; matches the pyve default.
- **Language runtime / pins:** Python `3.14.4` (`.tool-versions` → `python 3.14.4`;
  `.pyve/config` → `python.version: 3.14.4`). Managed via `asdf`; activated by `.envrc`
  (direnv) which prepends `.venv/bin` and exports `VIRTUAL_ENV`.
- **Bootstrap (one-time):**
  ```bash
  pyve init                 # creates .venv/ with the pinned Python
  ```
- **Install dependencies:**
  ```bash
  # project-guide is the only tool currently present in .venv/bin.
  # No requirements.txt is committed; project-guide is installed into the venv directly.
  pyve run pip show project-guide
  ```
- **Managed dependencies (`pip` / `conda`):**

  | Package | Version pin | Source class | Purpose |
  |---------|-------------|--------------|---------|
  | `project-guide` | `2.10.2` (installed; not pinned in a committed manifest) | `pip` | Spec/story tooling for developing this repo |

- **System / external dependencies (`system` / `vendored` / `runtime`):**

  | Dependency | Version | Source class | Install method | Why not in the managed env |
  |------------|---------|--------------|----------------|----------------------------|
  | `python` | `3.14.4` | `runtime` | `asdf` (`.tool-versions`) | Interpreter that backs the venv |
  | `direnv` | any | `system` | `brew install direnv` | Activates `.envrc`; host-level shell integration |

- **Lock / reproducibility strategy:** **Gap** — there is no committed `requirements.txt`
  for the root env, so `project-guide`'s version is not reproducibly pinned. *Recommended:*
  add `requirements.txt` (or `requirements-dev.txt`) capturing `project-guide==2.10.2`.
- **Verification (smoke test):**
  ```bash
  pyve run project-guide --version    # expect: project-guide, version 2.10.2
  ```
- **CI parity notes:** Not used in CI. `project-guide` is a local development aid only; CI
  (`.github/workflows/ci.yml`) never invokes it.

---

### 5.1 Environment: `testenv` (purpose: `test`)

- **Purpose (surface):** `test` — the default test environment; owns all test execution.
- **Attributes:** app_type `none`; frameworks `bats`, `shellcheck`; languages `bash`.
- **Backend & rationale:** `venv` (pyve default; `.pyve/testenv/venv/` exists). **Important
  caveat:** gitbetter's test dependencies are **not** Python/PyPI packages, so the venv
  itself currently holds **no** test-relevant content. It is retained as the default
  backend and as a future home for any Python-based test helpers. The real toolchain is
  `system` + `vendored` (see below). This mismatch motivates §8.
- **Test categories covered:** static analysis (ShellCheck), unit (BATS), integration
  (BATS + `sandbox` repos). See §6.
- **Language runtime / pins:** Bash ≥ 4.0 required (`features.md`/`tech-spec.md`); local dev
  observed Bash `5.3.9`. Git ≥ 2.30 required; local observed `2.54.0`.
- **Bootstrap (one-time):**
  ```bash
  pyve testenv init        # creates .pyve/testenv/venv/ (does NOT auto-create on install/run)
  ```
- **Install dependencies:**
  ```bash
  # No pip dependencies. Provision the real toolchain via the host package manager:
  brew install bats-core shellcheck            # macOS
  # Vendored BATS helper libraries (gitignored; cloned, not checked in):
  git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
  git clone https://github.com/bats-core/bats-assert.git  tests/test_helper/bats-assert
  ```
- **Managed dependencies (`pip` / `conda`):**

  | Package | Version pin | Source class | Purpose |
  |---------|-------------|--------------|---------|
  | — | — | — | None — no PyPI/conda test dependencies |

- **System / external dependencies (`system` / `vendored` / `runtime`):**

  | Dependency | Version | Source class | Install method | Why not in the managed env |
  |------------|---------|--------------|----------------|----------------------------|
  | `bash` | ≥ 4.0 (local 5.3.9) | `runtime` | system / `brew install bash` | Script interpreter; not a Python package |
  | `git` | ≥ 2.30 (local 2.54.0) | `runtime` | system | Subject under test; not a Python package |
  | `bats` (bats-core) | local 1.13.0 / CI 1.11.0 | `system` | `brew install bats-core` / `bats-core/bats-action` | Bash test runner; not on PyPI/conda-forge |
  | `bats-support` | latest `main` | `vendored` | `git clone` → `tests/test_helper/bats-support/` | Helper lib; gitignored, cloned per environment |
  | `bats-assert` | latest `main` | `vendored` | `git clone` → `tests/test_helper/bats-assert/` | Helper lib; gitignored, cloned per environment |
  | `shellcheck` | local 0.11.0 / CI latest apt | `system` | `brew install shellcheck` / `apt-get install shellcheck` | Static analyzer; not a Python package |

- **Lock / reproducibility strategy:** Versions are pinned **only in CI**: BATS `1.11.0` via
  `bats-core/bats-action@3.0.0`; ShellCheck is `apt-get`'s latest. **Gap:** local and CI
  versions drift (BATS 1.13.0 vs 1.11.0; ShellCheck 0.11.0 vs apt latest), and the vendored
  helper libs track `main` (unpinned). *Recommended:* pin a ShellCheck version in CI and
  pin the helper-lib commit SHAs (or use the action's pinned versions) for reproducibility.
- **How to run the tests this env owns:**
  ```bash
  shellcheck gitbetter.sh git-push.sh git-tag.sh lib/ui.sh   # static analysis
  bats tests/                                                # all unit + integration tests
  ```
- **Verification (smoke test):**
  ```bash
  bats --version && shellcheck --version
  ```
- **CI parity notes:** `.github/workflows/ci.yml` (`ubuntu-latest`) reproduces this env:
  installs ShellCheck via apt, installs BATS 1.11.0 + support + assert via
  `bats-core/bats-action@3.0.0`, then runs `shellcheck ...` and `bats tests/`.

---

### 5.2 Environment: `sandbox` (purpose: `temp`)

- **Purpose (surface):** `temp` — ephemeral, per-test git repositories created and torn down
  by the BATS harness; the execution substrate for integration tests.
- **Attributes:** app_type `none`; frameworks `none`; languages `bash`.
- **Backend & rationale:** `none` — not a pyve-managed environment. Materialized at runtime
  via `mktemp -d` inside `tests/test_helper/common-setup.bash`.
- **Language runtime / pins:** inherits `bash`/`git` from `testenv`.
- **Bootstrap (one-time):** N/A — created automatically by `setup_temp_repo` /
  `setup_bare_remote` at the start of each test.
- **Install dependencies:** N/A — no dependencies beyond the inherited `git`/`bash`.
- **Managed dependencies (`pip` / `conda`):** N/A.
- **System / external dependencies:** inherits `git` and `bash` from `testenv`.
- **Lock / reproducibility strategy:** N/A — each sandbox is freshly created from a fixed
  setup script and removed by `teardown_temp_repo`; isolation guarantees reproducibility.
- **How tests use it:** `setup_temp_repo` (isolated working repo), `setup_bare_remote`
  (local bare `origin`), `make_remote_ahead`, `block_pushes_to_remote`, `tag_on_remote`.
- **Verification (smoke test):** N/A — exercised implicitly by the integration suite.
- **CI parity notes:** Identical behavior in CI; sandboxes are created on the runner's
  filesystem and removed on teardown.

---

## 6. Test Coverage Matrix

| Test category | Tooling | Owning environment | Covered? | Notes |
|---------------|---------|--------------------|----------|-------|
| Static analysis / lint | `shellcheck` | `testenv` | yes | `gitbetter.sh git-push.sh git-tag.sh lib/ui.sh` |
| Unit tests | `bats` | `testenv` | yes | `tests/ui.bats`, `tests/gitbetter.bats`, arg-parsing/validation tests |
| Integration tests | `bats` + `sandbox` | `testenv` (runs in `sandbox`) | yes | `tests/git-push.bats`, `tests/git-tag.bats` (temp repos + bare remotes, hooks, force-push) |
| Formatting | `shfmt` | — | N-A | Not currently adopted; `shfmt` not installed. Optional future addition. |
| Packaging / distribution | `brew audit` / `brew test` | — | N-A (out of repo) | Formula + `test do` block live in `pointmatic/homebrew-tap`, not this repo |

**Completeness statement:** Every test category the codebase requires (lint, unit,
integration) is covered by the single `testenv` environment, executing against ephemeral
`sandbox` repos for integration. No required category is missing. Formatting and packaging
are intentionally out of scope for `testenv` (formatting unadopted; packaging lives in the
tap repo).

---

## 7. Reproducibility & Bootstrapping

```bash
# Fresh-clone → fully testable, from the repo root:

# 1. Root utility env (optional — only needed for project-guide tooling)
pyve init
pyve run pip install project-guide==2.10.2     # (recommend committing this to requirements.txt)

# 2. Test env scaffold (default backend) + real toolchain
pyve testenv init
brew install bats-core shellcheck              # macOS (Linux: apt-get install shellcheck + bats)
git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert.git  tests/test_helper/bats-assert

# 3. Verify
bats --version && shellcheck --version

# 4. Run the suite
shellcheck gitbetter.sh git-push.sh git-tag.sh lib/ui.sh
bats tests/
```

- **Files that must be committed for reproducibility:** `.tool-versions`, `.pyve/config`,
  `.github/workflows/ci.yml` (pins the CI toolchain), `tests/test_helper/common-setup.bash`.
  *Recommended additions:* `requirements.txt` (root tooling pin), and pinned helper-lib SHAs.
- **Files that must NOT be committed (gitignored):** `.venv/`, `.pyve/envs/`,
  `.pyve/testenv/`, `.envrc`, `.env`, `tests/test_helper/bats-support/`,
  `tests/test_helper/bats-assert/`.

---

## 8. Proposed Canonical Backend Additions

| Candidate backend | Driving need | Manifest format | Lock format | Canonicalization rationale |
|-------------------|--------------|-----------------|-------------|----------------------------|
| `homebrew` | gitbetter's test dependencies (`bats-core`, `shellcheck`) are CLI tools available via Homebrew — **not** on PyPI or conda-forge, so neither `venv` nor `micromamba` can install them. The `testenv` venv is therefore empty while the real toolchain lives unmanaged on the host PATH. | `Brewfile` | Pinned versions + checksums per package; reuse `brew bundle` lockfile semantics | A large class of repos (Bash/CLI/polyglot projects) test with host-level tools. A first-class `homebrew` backend would let pyve declare, install, and pin non-language-runtime test dependencies the same way it manages `venv`/`micromamba`, closing the gap this repo exposes. |
| `apt` | The same dependencies on Debian/Ubuntu hosts (incl. CI) come from `apt`, not Homebrew. A sibling `apt` backend would give Linux parity with `homebrew`. | apt package list | Pinned `pkg=version` entries | Cross-platform parity: macOS dev uses `homebrew`, Linux/CI uses `apt`; both are specific, declarable mechanisms. |
| `docker` | `homebrew`/`apt` install the test toolchain **unreproducibly** (local↔CI drift: bats 1.13.0 vs 1.11.0, etc.). A pinned image freezes bash/git/bats/shellcheck + vendored helpers at exact versions, giving true CI parity. | `Dockerfile` / `compose.yaml` (shared with `podman`) | image digest `@sha256:...` + inner lockfiles | Expands pyve from Python-env manager to general env manager; OS-level reproducibility. Containers can *nest* other backends, so this is an isolation-level mechanism as well as a dependency one. |
| `podman` | Same shared image as `docker`, but rootless/daemonless with SELinux (`:z`/`:Z`), `--userns=keep-id`, distinct socket path, and `podman compose` provider semantics that differ enough to warrant a first-class flavor rather than docker-with-workarounds. | `Dockerfile` (shared with `docker`) | image digest `@sha256:...` + inner lockfiles | Explicit flavor codifies rootless/mount/socket/compose/build-engine (Buildah) deltas once, instead of scattering per-repo patches — consistent with the `homebrew`/`apt` (not generic `system`) naming convention. |

**Container-flavor note:** `docker` and `podman` are **distinct backends that share a single
OCI `Dockerfile`** — the divergence is *runtime behavior* (socket, mount flags, rootless/
userns, compose, BuildKit vs Buildah), not the manifest. The shared `Dockerfile` requires
discipline to avoid engine-specific features that build on one but not the other; pyve's
per-flavor build adapter is the right place to validate this.

**Secondary note (vendored deps):** `bats-support`/`bats-assert` are git-cloned helper
libraries. A canonical `homebrew`/`apt` backend (or a complementary `vendored` mechanism)
should also be able to pin these by commit SHA for reproducibility.

---

## 9. Change Log & Approval

| Date | Version | Author | Change | Status |
|------|---------|--------|--------|--------|
| 2026-05-31 | `0.1` | Pointmatic | Initial draft for gitbetter | `In Review` |
| 2026-05-31 | `1.0` | Pointmatic | Backend naming (`homebrew`/`apt`/`none`), structured `temp` surface | `Approved` |
| 2026-05-31 | `1.1` | Pointmatic | Add `docker`/`podman` candidate backends (distinct flavors, shared OCI manifest) | `Approved` |
