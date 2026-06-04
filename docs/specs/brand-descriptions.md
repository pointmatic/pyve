# descriptions.md — Pyve (Python)

Canonical source of truth for all descriptive language used across the `pyve` project (including naming, taglines, and marketing phrasing). All consumer files (README.md, docs/index.html, pyproject.toml, features.md) should draw from these definitions. 

For project-specific must-know facts, see [`project-essentials.md`](project-essentials.md) (`plan_phase` appends new facts per phase). For the workflow steps tailored to the current mode (cycle steps, approval gates, conventions), see [`docs/project-guide/go.md`](../project-guide/go.md) — re-read it whenever the mode changes or after context compaction.

---

## Name

- Pyve (GitHub)
- Pyve (Homebrew)

## Tagline

Wrangle your virtual environments

## Long Tagline

Wrangle all your virtual environments.

## One-liner

A single, easy entry point for managing virtual environments.

### Friendly Brief Description (follows one-liner)

Pyve orchestrates virtual environments with any stack combo (init, auto-activate, purge) — auto-detects and configures asdf/pyenv, venv/micromamba/pnpm/docker/etc, and direnv.

## Two-clause Technical Description

A command-line tool that simplifies setting up and managing just about any stack combination in virtual environments on macOS and Linux, orchestrating many languages (Python, Node.js, Ruby, etc.) with a broad choice of backends (venv, micromamba, pnpm, Docker/Podman, Homebrew, apt, etc.) all activated seamlessly with direnv.

*N-3 note: the "polyglot orchestration" framing is now backed by **two implemented reference plugins** — Python (venv / micromamba) and Node / SvelteKit (pnpm / npm / yarn). The other languages/backends named above remain aspirational examples of the plugin contract's reach. Comprehensive narrative reflow deferred to N-6.*

## Benefits

*v3 baseline — comprehensive narrative reflow deferred to N-6.*

- One-command environment setup (`pyve init`)
- Pluggable backends — venv, micromamba, pnpm, and a contract for adding more
- Declarative `pyve.toml` with named envs (`run`, `test`, `utility`, `temp`)
- Language version management — plugin-owned (asdf / pyenv on the Python side)
- direnv integration for seamless shell activation
- CI/CD-ready with `--no-direnv`, `--auto-bootstrap`, and `--strict` flags
- Clean teardown with `pyve purge` — preserves your secrets
- Zero runtime dependencies — pure Bash, no daemons

## Technical Description

*v3 baseline — comprehensive narrative reflow deferred to N-6.*

Pyve is a focused command-line tool that provides a single, deterministic entry point for setting up and managing project environments across multiple language ecosystems on macOS and Linux. It orchestrates language-version management, environment materialization (per-project virtualized, shared cache-backed, or check-only via plugins), and direnv-driven activation in one script. It supports interactive workflows with auto-activation and non-interactive CI/CD pipelines with explicit execution via `pyve run`.

## Keywords

*v3 baseline — comprehensive narrative reflow deferred to N-6.*

`python`, `nodejs`, `sveltekit`, `virtual-environment`, `asdf`, `pyenv`, `venv`, `micromamba`, `conda`, `pnpm`, `direnv`, `environment-manager`, `plugin-architecture`, `polyglot`, `named-environments`, `cli`, `bash`, `macos`, `linux`, `devtools`

---

## Feature Cards

*v3 baseline — comprehensive narrative reflow deferred to N-6.*

Short blurbs for landing pages and feature grids. Each card has a title and a one-to-two sentence description.

| # | Title | Description |
|---|-------|-------------|
| 1 | One-Command Setup | Initialize the project environment, language version, direnv, and `.gitignore` in a single `pyve init`. |
| 2 | Pluggable Backends | Choose venv, micromamba, pnpm, or a plugin-contributed backend — auto-detected from project files. |
| 3 | Deterministic Execution | Run commands inside the project environment with `pyve run` — no manual activation, no shell state. |
| 4 | Clean Teardown | `pyve purge` removes all artifacts while preserving your secrets and user data. |
| 5 | CI/CD Ready | Non-interactive flags (`--no-direnv`, `--auto-bootstrap`, `--strict`) for reproducible pipelines. |
| 6 | Environment Diagnostics | `pyve check` and `pyve status` report health, version compatibility, and lock file status. |
| 7 | Named Test Environments | `pyve test` runs in a dedicated `[env.<name>]` with `purpose = "test"` that survives force re-initialization. |
| 8 | Declarative Manifest | One `pyve.toml` declares every env (`purpose`, `backend`, plugin-private attrs); migration from v2 via `pyve self migrate`. |
| 9 | Zero Dependencies | Pure Bash script — no runtime dependencies, no daemons, no background processes. |

---

## Usage Notes

| File | Which descriptions to use |
|------|--------------------------|
| `README.md` line 7 | Two-clause Technical Description |
| `README.md` line 13 | Benefits (inline) |
| `README.md` line 11 | Technical Description |
| `docs/site/index.html` hero `<h1>` | One-liner (MkDocs) |
| `docs/site/index.html` hero `<p>` | Friendly Brief Description (MkDocs) |
| `docs/site/index.html` feature grid | Feature Cards (MkDocs) |
| `docs/specs/features.md` line 1 | One-liner + Long Tagline |
| (GitHub Repository) | One-liner + ":" + Long Tagline |