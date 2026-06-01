# pyve-environment-dependencies-template.md

This is a **template**. It defines the *structure* of a pyve environment-dependencies
document. To produce the concrete document for a repository, copy this file to
`pyve-environment-dependencies-repo_<repo_name>.md` and fill in every `<placeholder>`,
replacing the instructional `<!-- HOW TO FILL -->` comments with real content.

The purpose of the concrete document is to formally enumerate:

1. The **root development environment** required to develop the repo (the environment a
   contributor or LLM must stand up before doing anything else).
2. One or more **named test environments** (the first defaults to `testenv`) required to
   *efficiently, effectively, and completely* test the codebase.

A secondary purpose is to surface **environment requirements that the current canonical
pyve backend set does not cleanly satisfy**, so the canonical backend list can grow over
time. See [§3 Backend Catalog](#3-backend-catalog) and [§8 Proposed Canonical Backend
Additions](#8-proposed-canonical-backend-additions).

> **Related docs**
> - `features.md` — what the project does (scope, requirements, behavior).
> - `tech-spec.md` — how the project is built (architecture, dependencies, testing strategy).
> - `pyve-environment-dependencies-repo_<repo_name>.md` — the filled-in instance of this template.
> - Pyve backends reference: <https://pointmatic.github.io/pyve/backends/>

---

## 0. How To Use This Template

<!-- HOW TO FILL: Remove this entire section from the concrete document. It is guidance only. -->

- Every section below is **required** unless explicitly marked *(optional)*.
- Replace `<placeholder>` tokens and resolve every `<!-- HOW TO FILL -->` comment.
- Keep section numbering and headings stable so instances are diffable against each other.
- Prefer **declarative facts** (pinned versions, exact commands, file paths) over prose.
- If a section does not apply, keep the heading and write `N/A — <one-line reason>`.
- The document is **source-controlled** and **change-controlled**: update §9 on every edit.

---

## 1. Document Metadata

| Field | Value |
|-------|-------|
| **Repo name** | `<repo_name>` |
| **Primary language(s)** | `<e.g. Bash 4.0+, Python 3.14>` |
| **Pyve version** | `<pyve version X.Y.Z>` |
| **Doc status** | `Draft` \| `In Review` \| `Approved` |
| **Last updated** | `<YYYY-MM-DD>` |
| **Author / maintainer** | `<name>` |

---

## 2. Conventions & Terminology

<!-- HOW TO FILL: This section is mostly boilerplate. Keep it verbatim unless the repo
     introduces new terms. Add repo-specific terms at the end. -->

- **Environment** — a named, isolated dependency space materialized by a backend. Every
  environment has exactly one **purpose** (surface), one **backend**, and a structured
  attribute set (`app_type`, `frameworks`, `languages`). Environments are enumerated
  machine-readably in [§4.0](#40-environment-surface-enumeration).
- **Purpose (surface)** — the single role an environment serves. Exactly one of:

  | `purpose` | Meaning |
  |-----------|---------|
  | `run` | Hosts the application/runtime itself (the thing that ships or executes in production). |
  | `test` | Hosts test runners and test-only dependencies; where a class of tests executes. |
  | `utility` | Hosts development/orchestration tooling (LLM/project-guide CLIs, formatters, generators, codegen). Not the app, not tests. |
  | `temp` | A **structured** ephemeral space that is a defined, reproducible part of a workflow (e.g. the `mktemp -d` sandboxes a test harness spins up per run). Enumerate these. Do **not** enumerate ad-hoc one-off spikes or "hello world" investigations. |

  One environment = one purpose. If a single backing directory genuinely serves two
  purposes, declare two environments. (Lists are intentionally **not** supported — forcing
  a single choice keeps each environment's intent unambiguous. Revisit only if real
  friction cases emerge.)
- **Root development environment** — the environment activated at the repo root (pyve's
  primary environment, e.g. `.venv/` for the `venv` backend). Its purpose is typically
  `utility` — it hosts tooling, not necessarily the app or the tests.
- **Named test environment** — a `purpose: test` environment. The first/default is named
  `testenv`. Additional environments use distinct names (e.g. `testenv-integration`,
  `testenv-min`). Each maps to exactly one backend.
- **Backend** — the environment-management mechanism pyve uses to materialize an
  environment. Values are **specific mechanism names** (e.g. `venv`, `micromamba`,
  `homebrew`, `apt`), never generic categories. The special value **`none`** means there is
  no formal configuration mechanism — the environment is the bare OS. Since every
  environment ultimately runs on a system, `none` is the implicit default for any surface
  that pyve does not materialize. See [§3](#3-backend-catalog).
- **Structured attributes** — fixed-vocabulary descriptors recorded per environment:

  | Attribute | Vocabulary (examples; use `none`/`N-A` when not applicable) |
  |-----------|-------------------------------------------------------------|
  | `app_type` | `api`, `cli`, `desktop`, `mobile`, `embedded`, `script`, `web`, `none` |
  | `frameworks` | `none`, `bats`, `shellcheck`, `shfmt`, `pytest`, `flask`, `fastapi`, `jinja2`, `jupyter`, `marimo`, `react`, `vue`, `sveltekit`, `ios_app`, `android_app`, `kotlin_multiplatform`, `spring`, `j2ee` |
  | `languages` | `bash`, `python`, `cpp`, `c`, `java`, `kotlin`, `typescript`, `swift`, `objective_c`, `c_sharp`, `rust`, `javascript`, `lua`, `ruby`, `sql` |
- **Dependency source class** — where a dependency comes from and how it is installed.
  This document recognizes the following classes (a single environment may mix several):

  | Class | Examples | Manifest / install mechanism |
  |-------|----------|------------------------------|
  | `pip` (PyPI) | `pytest`, `ruff`, `mypy` | `requirements.txt` / `requirements-dev.txt` |
  | `conda` (conda-forge) | `numpy`, `gdal` | `environment.yml` → `conda-lock.yml` |
  | `system` (OS / Homebrew / apt) | `shellcheck`, `bash`, `git` | `brew install` / `apt-get install` |
  | `vendored` (git-clone / submodule) | `bats-support`, `bats-assert` | `git clone` into a known path |
  | `runtime` (language interpreter) | `python`, `bash` | `.tool-versions` (asdf) / system |

- **Canonical backend** — a backend officially supported by pyve. **Currently `venv`
  (default) and `micromamba`.** Other mechanisms are *non-canonical* and must be documented
  in [§8](#8-proposed-canonical-backend-additions) as candidates for promotion.
- `<add repo-specific terms here, or write "None">`

---

## 3. Backend Catalog

<!-- HOW TO FILL: Keep the two canonical rows. Add a row for any non-canonical mechanism
     this repo actually relies on (e.g. "homebrew", "asdf-only"), marked status=proposed,
     and cross-reference §8. -->

| Backend | Status | Env location | Dependency manifest | Lock artifact | Init command |
|---------|--------|--------------|---------------------|---------------|--------------|
| `venv` | **canonical (default)** | `.venv/` (root), `.pyve/testenv/venv/` (testenv) | `requirements.txt` | `requirements.txt` w/ `--hash` (pip-tools) | `pyve init` / `pyve testenv init` |
| `micromamba` | **canonical** | `.pyve/envs/<hash>/` | `environment.yml` | `conda-lock.yml` (`pyve lock`) | `pyve init --backend micromamba` |
| `<proposed-id>` | `proposed` | `<path>` | `<manifest>` | `<lock>` | `<command>` — see §8 |

**Default-backend assumption:** any environment may benefit from the `venv` backend, since
Python is a general-purpose workhorse for scripting/automation even in non-Python repos.
Choose a non-`venv` backend only with a stated reason (recorded per environment in §5).

**On `none`:** an environment whose dependencies have no formal configuration mechanism
(installed ad-hoc on the host, or materialized at runtime) uses backend `none` — the bare
OS. Use a specific name (`homebrew`, `apt`, ...) instead whenever a real mechanism exists,
even if pyve does not yet treat it as canonical (record it as `proposed` and cross-ref §8).

---

## 4. Environment Inventory

### 4.0 Environment Surface Enumeration

<!-- HOW TO FILL: This machine-readable block is the spine of the document. Enumerate
     EVERY environment surface the repo exposes — run, test, utility, temp. The root dev
     env is usually `utility`. List each environment exactly once; the §4.1 table and §5
     specs expand these entries. Use `none`/`N-A` for attributes that do not apply. -->

```yaml
project: <repo_name>
description: <one-line description of the repo>
envs:
  <env_name>:                       # e.g. root, testenv, testenv-integration
    purpose: <run | test | utility | temp>
    backend: <venv | micromamba | proposed-id>
    default: <true | false>         # true only for the default test env
    app_type: <api | cli | desktop | mobile | embedded | script | web | none>
    frameworks: [<none | bats | pytest | ...>]
    languages: [<bash | python | ...>]
```

### 4.1 Inventory Table

<!-- HOW TO FILL: One row per environment from §4.0. The root env is always first. Justify
     the TOTAL COUNT of test environments below; the per-category mapping lives in §6. -->

| # | Environment name | Purpose | Backend | Default? | App type | Frameworks | Languages |
|---|------------------|---------|---------|----------|----------|------------|-----------|
| 0 | `<root / repo root>` | `utility` | `<backend>` | n/a | `<app_type>` | `<frameworks>` | `<languages>` |
| 1 | `testenv` | `test` | `<backend>` | yes | `<app_type>` | `<frameworks>` | `<languages>` |
| 2 | `<testenv-...>` | `<purpose>` | `<backend>` | no | `<app_type>` | `<frameworks>` | `<languages>` |

**Why this many test environments:** `<1–3 sentences justifying the count: which axes of
variation (dependency set, framework, integration vs unit, runtime version, OS) require
separation, and why fewer environments would be insufficient or more would be redundant.>`

---

## 5. Environment Specifications

<!-- HOW TO FILL: Duplicate the entire "### 5.x" block once per environment listed in §4,
     including the root environment. Keep every subsection; use "N/A — reason" when empty. -->

### 5.0 Environment: `<root / repo root>` (purpose: `utility`)

- **Purpose (surface):** `utility` — `<what tooling it hosts>`.
- **Attributes:** app_type `<...>`; frameworks `<...>`; languages `<...>`.
- **Backend & rationale:** `<backend>` — `<why this backend>`.
- **Language runtime / pins:** `<interpreter + version, source: .tool-versions / system>`.
- **Bootstrap (one-time):**
  ```bash
  <commands to create the env, e.g. `pyve init`>
  ```
- **Install dependencies:**
  ```bash
  <commands, e.g. `pyve run pip install -r requirements.txt`>
  ```
- **Managed dependencies (`pip` / `conda`):**

  | Package | Version pin | Source class | Purpose |
  |---------|-------------|--------------|---------|
  | `<pkg>` | `<==x.y.z>` | `<pip/conda>` | `<why>` |

- **System / external dependencies (`system` / `vendored` / `runtime`):**

  | Dependency | Version | Source class | Install method | Why not in the managed env |
  |------------|---------|--------------|----------------|----------------------------|
  | `<tool>` | `<x.y>` | `<system/vendored/runtime>` | `<brew/apt/git clone/asdf>` | `<reason>` |

- **Lock / reproducibility strategy:** `<how exact versions are frozen & committed>`.
- **Verification (smoke test):**
  ```bash
  <command(s) proving the env is correctly provisioned, e.g. `pyve run project-guide --version`>
  ```
- **CI parity notes:** `<how CI reproduces this env, or "not used in CI">`.

---

### 5.1 Environment: `testenv` (purpose: `test`)

- **Purpose (surface):** `test` — default test environment.
- **Attributes:** app_type `<...>`; frameworks `<...>`; languages `<...>`.
- **Backend & rationale:** `<backend>` — `<why>`.
- **Test categories covered:** `<e.g. unit, lint>` (see §6).
- **Language runtime / pins:** `<...>`.
- **Bootstrap (one-time):**
  ```bash
  <e.g. `pyve testenv init`>
  ```
- **Install dependencies:**
  ```bash
  <e.g. `pyve testenv install -r requirements-dev.txt`>
  ```
- **Managed dependencies (`pip` / `conda`):**

  | Package | Version pin | Source class | Purpose |
  |---------|-------------|--------------|---------|
  | `<pkg>` | `<==x.y.z>` | `<pip/conda>` | `<why>` |

- **System / external dependencies (`system` / `vendored` / `runtime`):**

  | Dependency | Version | Source class | Install method | Why not in the managed env |
  |------------|---------|--------------|----------------|----------------------------|
  | `<tool>` | `<x.y>` | `<system/vendored/runtime>` | `<brew/apt/git clone>` | `<reason>` |

- **Lock / reproducibility strategy:** `<...>`.
- **How to run the tests this env owns:**
  ```bash
  <e.g. `bats tests/` or `pyve test`>
  ```
- **Verification (smoke test):**
  ```bash
  <command proving the test tooling is present, e.g. `bats --version && shellcheck --version`>
  ```
- **CI parity notes:** `<how CI reproduces this env — link to workflow steps>`.

<!-- HOW TO FILL: copy the 5.1 block as 5.2, 5.3, ... for every additional test env. -->

---

## 6. Test Coverage Matrix

<!-- HOW TO FILL: Map each test CATEGORY to the environment that owns it. Every category
     the codebase needs must map to exactly one environment. This is the evidence that the
     environment set is COMPLETE (every category covered) and EFFICIENT (no category is
     split across redundant envs). -->

| Test category | Tooling | Owning environment | Covered? | Notes |
|---------------|---------|--------------------|----------|-------|
| Static analysis / lint | `<e.g. shellcheck>` | `<env>` | `<yes/no>` | `<...>` |
| Unit tests | `<e.g. bats>` | `<env>` | `<yes/no>` | `<...>` |
| Integration tests | `<...>` | `<env>` | `<yes/no/N-A>` | `<...>` |
| Formatting | `<e.g. shfmt>` | `<env>` | `<yes/no/N-A>` | `<...>` |
| Packaging / distribution | `<e.g. brew audit>` | `<env>` | `<yes/no/N-A>` | `<...>` |
| `<other category>` | `<...>` | `<env>` | `<...>` | `<...>` |

**Completeness statement:** `<assert that every category the codebase requires is covered
by exactly one environment, and that no required category is missing.>`

---

## 7. Reproducibility & Bootstrapping

<!-- HOW TO FILL: Provide the minimal, copy-pasteable command sequence that takes a fresh
     clone to a fully testable state. This should be derivable directly from §5. -->

```bash
# Fresh-clone → fully testable, from the repo root:
<step 1: root env>
<step 2: testenv init + install>
<step 3: system/vendored deps>
<step 4: run verification smoke tests>
```

- **Files that must be committed for reproducibility:** `<requirements*.txt, environment.yml,
  conda-lock.yml, .tool-versions, .envrc, ...>`.
- **Files that must NOT be committed:** `<.venv/, .pyve/envs/, .pyve/testenv/, .env, ...>`.

---

## 8. Proposed Canonical Backend Additions

<!-- HOW TO FILL: This is the feedback loop into pyve. If this repo needed a dependency
     mechanism that the canonical backends (venv, micromamba) do not cleanly support,
     describe it here as a candidate canonical backend. If none, write
     "None — canonical venv/micromamba cover all needs." -->

| Candidate backend | Driving need | Manifest format | Lock format | Canonicalization rationale |
|-------------------|--------------|-----------------|-------------|----------------------------|
| `<id>` | `<what requirement venv/micromamba can't meet>` | `<file>` | `<file>` | `<why pyve should adopt it>` |

---

## 9. Change Log & Approval

| Date | Version | Author | Change | Status |
|------|---------|--------|--------|--------|
| `<YYYY-MM-DD>` | `0.1` | `<name>` | Initial draft | `Draft` |
