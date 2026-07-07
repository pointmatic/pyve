# brand-descriptions.md — Pyve

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

A single, easy entry point for managing all your virtual environments.

### Friendly Brief Description (follows one-liner)

Pyve orchestrates virtual environments across any stack combo (init, auto-activate, upgrade, purge) — auto-detects and configures asdf/pyenv/nvm, venv/micromamba/pnpm, and direnv.

## Two-clause Technical Description

A command-line tool that simplifies setting up and managing just about any stack combination in virtual environments on macOS and Linux, orchestrating multiple languages (Python and Node.js / SvelteKit) across a choice of backends (venv, micromamba, pnpm) all activated seamlessly with direnv and LLM-assisted by Project-Guide.

**Note:**
- Polyglot orchestration: two reference plugins — Python (venv / micromamba) and Node / SvelteKit (pnpm / npm / yarn).
- Seamless activation: `pyve init` / `check` / `status` / `purge` compose across every declared plugin into one `.envrc` / `.gitignore` / report (failure-safe, atomic writes).

**Future (roadmap — not yet shipped):** additional language plugins (e.g. Ruby) and backends (Docker / Podman, Homebrew, apt) are under consideration through the same plugin contract.

## Benefits

- One command for any stack — `pyve init` detects your project and materializes every environment it declares.
- Declarative `pyve.toml` — each environment is named, given a purpose (`run`, `test`, `utility`, `temp`), and carries a composable setup recipe, all in a single manifest.
- Pluggable backends — venv, micromamba, and pnpm today, with a stable contract for adding more.
- Polyglot by composition — Python and Node/SvelteKit activate together through one `.envrc`, one `.gitignore`, and one health report.
- Seamless shell activation via direnv — no manual `activate`, no stale shell state.
- Plugin-owned language versions — asdf / pyenv on the Python side, nvm / fnm / volta on the Node side.
- CI/CD-ready — `--no-direnv`, `--auto-bootstrap`, and `--strict` for reproducible, non-interactive pipelines.
- Clean teardown — `pyve purge` removes generated artifacts while preserving your secrets and user data.
- Reproducible by declaration — one `pyve env init <name>` materializes an env's full setup recipe; a forced rebuild restores its recorded state.
- In-place dependency upgrades — `pyve upgrade` re-resolves to newest-within-constraints, keeps the env, and re-locks.
- Zero runtime dependencies — pure Bash, no daemons, no background processes.

## Technical Description

Pyve is a focused command-line tool that gives every project a single, declarative entry point for setting up and running its environments across multiple language ecosystems on macOS and Linux. A root-level `pyve.toml` manifest names each environment and its purpose; language plugins (Python, Node/SvelteKit) materialize those environments through their own backends — per-project virtualized (venv, micromamba), cache-backed (pnpm), or check-only — and compose into one direnv-driven activation, one `.gitignore`, and one health report. It supports interactive workflows with auto-activation and non-interactive CI/CD pipelines with explicit execution via `pyve run`.

## Keywords

`python`, `nodejs`, `sveltekit`, `polyglot`, `declarative`, `pyve.toml`, `named-environments`, `plugin-architecture`, `virtual-environment`, `asdf`, `pyenv`, `venv`, `micromamba`, `conda`, `pnpm`, `direnv`, `environment-manager`, `cli`, `bash`, `macos`, `linux`, `devtools`

---

## Feature Cards

Short blurbs for landing pages and feature grids. Each card has a title and a one-to-two sentence description.

| # | Title | Description |
|---|-------|-------------|
| 1 | One-Command Setup | Initialize the project's environments, language versions, direnv, and `.gitignore` in a single `pyve init`. |
| 2 | Declarative Manifest | One `pyve.toml` declares every environment — its `purpose`, `backend`, and a composable setup recipe that one command reproduces. |
| 3 | Pluggable Backends | Choose venv, micromamba, pnpm, or a plugin-contributed backend — auto-detected from project files. |
| 4 | Polyglot Composition | Python and Node/SvelteKit live side by side — Pyve composes every plugin into one `.envrc`, `.gitignore`, and health report. |
| 5 | Deterministic Execution | Run commands inside the project environment with `pyve run` — no manual activation, no shell state. |
| 6 | Named Test Environments | `pyve test` runs in a dedicated `[env.<name>]` with `purpose = "test"` that survives force re-initialization. |
| 7 | Environment Diagnostics | `pyve check` and `pyve status` report health, version compatibility, and lock file status. |
| 8 | Clean Teardown | `pyve purge` removes generated artifacts while preserving your secrets and user data. |
| 9 | Upgrade & Rebuild | `pyve upgrade` re-resolves dependencies without touching the env; `pyve init --force` rebuilds from the declaration and restores recorded state. |
| 10 | Zero Dependencies | Pure Bash script — no runtime dependencies, no daemons, no background processes. |

---

## Usage Notes

| File | Which descriptions to use |
|------|--------------------------|
| `README.md` H1 title | One-liner |
| `README.md` intro paragraph | Technical Description |
| `README.md` "Why Pyve?" bullets | Benefits |
| `docs/site/index.html` hero `<h1>` | One-liner (MkDocs) |
| `docs/site/index.html` hero `<p>` | Friendly Brief Description (MkDocs) |
| `docs/site/index.html` feature grid | Feature Cards (MkDocs) |
| `docs/specs/features.md` line 1 | One-liner + Long Tagline |
| (GitHub Repository) | One-liner + ":" + Long Tagline |