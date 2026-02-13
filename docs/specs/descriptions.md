# descriptions.md — Pyve (Python)

Canonical source of truth for all descriptive language used across the project. All consumer files (README.md, docs/index.html, pyproject.toml, features.md) should draw from these definitions.

---

## Name

- Pyve (GitHub)
- Pyve (Homebrew)

## Tagline

Wrangle your virtual environments

## Long Tagline

Wrangle your Python virtual environments.

## One-liner

A single, easy entry point for Python virtual environments.

### Friendly Brief Description (follows one-liner)

Pyve orchestrates Python virtual environments (init, auto-activate, purge) — auto-detects and configures asdf/pyenv, venv/micromamba, and direnv.

## Two-clause Technical Description

A command-line tool that simplifies setting up and managing Python virtual environments on macOS and Linux, orchestrating Python version managers, venv and micromamba backends, and direnv in a single script.

## Benefits

- One-command environment setup (`pyve --init`)
- Dual backend support — venv (pip) and micromamba (conda-compatible)
- Automatic Python version management via asdf or pyenv
- direnv integration for seamless shell activation
- CI/CD-ready with `--no-direnv`, `--auto-bootstrap`, and `--strict` flags
- Clean teardown with `pyve --purge` — preserves your secrets
- Zero runtime dependencies — pure Bash, no daemons

## Technical Description

Pyve is a focused command-line tool that provides a single, deterministic entry point for setting up and managing Python virtual environments on macOS and Linux. It orchestrates Python version management (asdf or pyenv), virtual environments (venv or micromamba), and direnv integration in one script. It supports interactive workflows with auto-activation and non-interactive CI/CD pipelines with explicit execution via `pyve run`.

## Keywords

`python`, `virtual-environment`, `asdf`, `pyenv`, `venv`, `micromamba`, `conda`, `direnv`, `environment-manager`, `cli`, `bash`, `macos`, `linux`, `devtools`

---

## Feature Cards

Short blurbs for landing pages and feature grids. Each card has a title and a one-to-two sentence description.

| # | Title | Description |
|---|-------|-------------|
| 1 | One-Command Setup | Initialize Python version, virtual environment, direnv, and `.gitignore` in a single `pyve --init`. |
| 2 | Dual Backends | Choose venv for pure-Python projects or micromamba for scientific/ML stacks — auto-detected from project files. |
| 3 | Deterministic Execution | Run commands inside the project environment with `pyve run` — no manual activation, no shell state. |
| 4 | Clean Teardown | `pyve --purge` removes all artifacts while preserving your secrets and user data. |
| 5 | CI/CD Ready | Non-interactive flags (`--no-direnv`, `--auto-bootstrap`, `--strict`) for reproducible pipelines. |
| 6 | Environment Diagnostics | `pyve doctor` and `pyve --validate` report health, version compatibility, and lock file status. |
| 7 | Isolated Test Runner | `pyve test` runs pytest in a dedicated dev/test environment that survives force re-initialization. |
| 8 | Zero Dependencies | Pure Bash script — no runtime dependencies, no daemons, no background processes. |

---

## Usage Notes

| File | Which descriptions to use |
|------|--------------------------|
| `README.md` line 7 | Two-clause Technical Description |
| `README.md` line 13 | Benefits (inline) |
| `README.md` line 11 | Technical Description |
| `docs/index.html` hero `<h1>` | One-liner |
| `docs/index.html` hero `<p>` | Friendly Brief Description |
| `docs/index.html` feature grid | Feature Cards |
| `docs/specs/features.md` line 1 | One-liner + Long Tagline |
| (GitHub Repository) | One-liner + ":" + Long Tagline |