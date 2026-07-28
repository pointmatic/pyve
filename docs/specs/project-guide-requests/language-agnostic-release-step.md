# Change request: Make the end-of-phase release step language-agnostic — retire `bump-version` from the guidance surfaces

**Target repo:** [`project-guide`](https://github.com/pointmatic/project-guide).
**Consumption:** No pyve-side code consumes `bump-version` programmatically, so there is no min-version dependency or coordinating pyve change. The blast surface is *instructional*: project-guide's installed guidance teaches every planning session to write a release step that is wrong for non-Python projects and references a command the maintainer regards as deprecated.

---

## Problem statement

`project-guide bump-version <X.Y.Z>` is a Python-era artifact: it mutates `pyproject.toml`, `<package>/version.py`, and seeds a `CHANGELOG.md` heading. Both project-guide and pyve have since transitioned to **generic, any-language tools** — and the maintainer considers the command deprecated. But two installed guidance surfaces still teach it:

1. **The `plan_production_phase` mode template** — step 10 ("End-of-phase release"): *"the developer invokes `project-guide bump-version <X.Y.Z>` to bump the version and seed a `## [X.Y.Z] - <date>` CHANGELOG entry."*
2. **`developer/best-practices-guide.md`** (§ production-readiness): *"End-of-phase, the developer ships via `project-guide bump-version <X.Y.Z>` (the deterministic helper that updates `pyproject.toml` / `<package>/version.py` / `CHANGELOG.md`)."*

**Why this propagates further than it looks:** planning modes are executed by LLMs, and LLMs transcribe the template's release step into the consumer repo's release story verbatim. The instruction then outlives the template — it sits in `stories.md`, is re-read by later working sessions (including ones running *other* modes, whose rendered `go.md` never contained the release step), and is finally echoed to the developer at release time as a confident handoff.

**Field evidence (pyve, a bash project — no `pyproject.toml` at all):** three consecutive release stories carried the instruction — v3.0.0 (N.bu), v3.1.0 (P.u), v3.2.0 (P.af) — each drafted by a separate `plan_production_phase` session faithfully mirroring the previous story's shape, which mirrored the template. At v3.2.0's execution the handoff finally collided with reality: the command would mutate files that don't exist in this repo, and the maintainer had believed it deprecated. The wrong instruction survived **three release cycles in a repo that could never run it**, because the template kept re-seeding it.

There is also a **role inversion**: the template assigns mechanical file edits (version stamp, CHANGELOG date) to the *developer via a helper command*, while the LLM that just finished the phase — with full knowledge of where the version lives — stages nothing. The developer's actual, non-delegable release actions are git and platform operations (commit, tag, push, release publishing, package-manager formula). Everything else is in-repo file editing, which is exactly what the LLM should have already staged.

---

## Proposed change

### 1. Rewrite the mode template's release step (plan-production-phase, step 10)

Replace the `bump-version` instruction with a language-agnostic, role-correct split:

> **10. End-of-phase release** (after all phase stories are marked `[Done]`):
> - **The LLM stages the release in-repo, as part of the release story:** update the project's **version source(s) of truth** to `<X.Y.Z>` (see below — e.g. a `VERSION=` constant in a shell CLI, `pyproject.toml`/`__version__` in Python, `package.json` in Node, `Cargo.toml` in Rust), retitle the staged CHANGELOG section to `## [X.Y.Z] - <date>`, and sweep docs that echo version output. After staging, the working tree is release-ready: nothing remains but git.
> - **The developer releases:** commit, tag `v<X.Y.Z>`, push, and any platform steps (GitHub release/CI, package-manager formula). These are developer-owned actions the LLM never performs.

### 2. Record the version source(s) of truth in `project-essentials.md`

The staging step is only mechanical if the LLM knows *where* the version lives. Add one line to the `project-essentials.md` template (seeded at init or at the first `plan_production_phase`):

```markdown
### Version source of truth
- <file>:<locator>   (e.g. `pyve.sh` — the `VERSION="…"` constant; plus docs that echo it)
```

Pyve's audit shape is a useful reference: the answer is rarely "one file" bit-for-bit — pyve has one *authoritative* site (`pyve.sh`'s `VERSION`) plus an echo in a docs example — and settling that once, in essentials, beats re-deriving it every release.

### 3. Retire `bump-version` itself, loudly

Per the deprecation pattern pyve and project-guide already share (pyve's "Category B" essentials rule: hard-error with a named replacement beats silent delegation): if the command is deprecated, make it **error precisely**, e.g.:

```
error: 'project-guide bump-version' is retired.
       Release staging is now done in-repo by your working session (see the
       plan_production_phase release step); release with git: commit, tag, push.
```

Leaving the command runnable-but-Python-only is the worst option — it works just often enough on Python projects to keep the stale instruction alive in templates, stories, and LLM priors.

### 4. Sweep the remaining guidance mentions

`developer/best-practices-guide.md` § "How project-guide enforces the switch" (the passage quoted above), plus any other template/guide text that names `bump-version`, updated to the step-10 language. Consumers pick the fixes up via `project-guide update`.

---

## Motivation

- **Generic-tools transition, completed.** This is one of the "original design decisions" (maintainer's words) that the Python-specific era baked in and the generic era must pull back: a release helper that assumes `pyproject.toml` cannot be the documented release path for a tool that now scaffolds bash, Node, and polyglot projects.
- **Templates are instruction amplifiers.** A wrong line in a mode template is transcribed into every consumer repo's roster and re-read for the life of the phase. The pyve evidence (three releases, zero valid executions) shows the propagation half-life is long — the fix belongs at the source, not in each consumer's stories file.
- **Role-correctness.** "LLM stages files, developer runs git" is already the established division everywhere else in project-guide's workflow (stories, docs, CHANGELOG are LLM-authored; commits are developer-owned via `git-push`). The release step is the one place the template still inverts it.

## Compatibility notes

- **Already-drafted release stories in consumer repos** still say `bump-version`. Harmless once §3 lands: the command errors with a precise pointer to the correct flow, which is exactly the Category B migration property. No coordinated cleanup needed.
- **No version gate:** pyve consumes nothing of `bump-version` programmatically; this is a docs/templates/CLI-error change on project-guide's own release cadence. Consumers refresh via `project-guide update`.
- **CHANGELOG seeding** (the one genuinely useful thing `bump-version` did) is preserved by the step-10 language: the LLM stages the dated heading as part of the release story instead.
