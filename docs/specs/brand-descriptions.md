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

## Benefits

**NEEDS REVISION for Pyve 3.0**

- One-command environment setup (`pyve init`)
- Dual backend support — venv (pip) and micromamba (conda-compatible)
- Automatic Python version management via asdf or pyenv
- direnv integration for seamless shell activation
- CI/CD-ready with `--no-direnv`, `--auto-bootstrap`, and `--strict` flags
- Clean teardown with `pyve purge` — preserves your secrets
- Zero runtime dependencies — pure Bash, no daemons

## Technical Description

**NEEDS REVISION for Pyve 3.0**

Pyve is a focused command-line tool that provides a single, deterministic entry point for setting up and managing Python virtual environments on macOS and Linux. It orchestrates Python version management (asdf or pyenv), virtual environments (venv or micromamba), and direnv integration in one script. It supports interactive workflows with auto-activation and non-interactive CI/CD pipelines with explicit execution via `pyve run`.

## Keywords

**NEEDS REVISION for Pyve 3.0**

`python`, `virtual-environment`, `asdf`, `pyenv`, `venv`, `micromamba`, `conda`, `direnv`, `environment-manager`, `cli`, `bash`, `macos`, `linux`, `devtools`

---

## Feature Cards

**NEEDS REVISION for Pyve 3.0**

Short blurbs for landing pages and feature grids. Each card has a title and a one-to-two sentence description.

| # | Title | Description |
|---|-------|-------------|
| 1 | One-Command Setup | Initialize Python version, virtual environment, direnv, and `.gitignore` in a single `pyve init`. |
| 2 | Dual Backends | Choose venv for pure-Python projects or micromamba for scientific/ML stacks — auto-detected from project files. |
| 3 | Deterministic Execution | Run commands inside the project environment with `pyve run` — no manual activation, no shell state. |
| 4 | Clean Teardown | `pyve purge` removes all artifacts while preserving your secrets and user data. |
| 5 | CI/CD Ready | Non-interactive flags (`--no-direnv`, `--auto-bootstrap`, `--strict`) for reproducible pipelines. |
| 6 | Environment Diagnostics | `pyve doctor` and `pyve validate` report health, version compatibility, and lock file status. |
| 7 | Isolated Test Runner | `pyve test` runs pytest in a dedicated dev/test environment that survives force re-initialization. |
| 8 | Zero Dependencies | Pure Bash script — no runtime dependencies, no daemons, no background processes. |

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