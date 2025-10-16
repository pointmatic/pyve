# Decision Log

A lightweight log of key architectural, process, and tooling decisions. Each entry includes context, decision, and consequences. New decisions should be appended to the top.

## Template
Copy/paste this snippet when adding a new decision:

```markdown
## YYYY-MM-DD: Short Title of Decision
- Context: Brief background and alternatives considered.
- Decision: What we chose and why.
- Consequences: Immediate and long‑term effects, trade‑offs.
- Links: PR(s), discussion, related version(s) and Notes anchors.
```

## 2025-10-16: Deprecate --update Command in Favor of --install
- Context: `--update` and `--install` had significant overlap, creating confusion about which to use. `--install` copies pyve.sh + templates + records source path, while `--update` only copies templates. Both require access to source repo, and `--install` is idempotent.
- Decision: Deprecate `--update` in v0.5.2, remove entirely in v0.6.0:
  - Add deprecation warning when `--update` is called
  - Update help text to mark `--update` as deprecated and recommend `--install`
  - Improve `--install` description to emphasize it's safe to run multiple times
  - Keep `--update` functional but warn users
- Consequences: Simpler mental model (one command for installation and updates), reduced maintenance burden (one code path instead of two), clearer user experience. Only one user affected, easy migration.
- Links: [versions_spec.md v0.5.2](versions_spec.md), [pyve.sh update_templates()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:1639:0-1720:1)

## 2025-10-16: Pyve-Owned vs User-Owned Directory Model
- Context: Process guides (building, planning, testing) are Pyve methodology and should stay in sync, but technical specs (codebase, technical design) are project-specific and user-owned. Prior logic treated all files equally, creating unwanted suffixed copies for guides.
- Decision: Define explicit directory ownership model in v0.5.1:
  - **Pyve-owned** (always overwrite): `docs/guides/`, `docs/context/`, `docs/guides/llm_qa/`
  - **User-owned** (preserve on conflict): `docs/specs/`, `docs/decisions/`, `README.md`, `CONTRIBUTING.md`, everything else
  - Implement `is_pyve_owned()` function to check ownership
  - Skip conflict detection for Pyve-owned files during init/upgrade
  - Always overwrite Pyve-owned files without creating suffixed copies
- Consequences: Process guides stay in sync with Pyve methodology automatically, no more unwanted suffixed copies for guides, clear ownership model prevents confusion about which files to edit. Users can still add custom files anywhere.
- Links: [versions_spec.md v0.5.1](versions_spec.md), [pyve.sh PYVE_OWNED_DIRS](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:86:0-91:1), [pyve.sh is_pyve_owned()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:98:0-107:1)

## 2025-10-16: Patch-Level Template Versioning
- Context: Templates stored at minor version level (e.g., `~/.pyve/templates/v0.4/`) meant all v0.4.x versions overwrote the same directory, making it impossible to upgrade from 0.4.20 → 0.4.21. Version granularity was too coarse.
- Decision: Store templates at full semver patch level in v0.5.0:
  - Change directory structure: `v0.4/` → `v0.4.21/`, `v0.5.0/`, `v0.5.1/`
  - Implement `compare_semver()` function for proper version comparison
  - Update `find_latest_template_version()` to use semver comparison
  - Add automatic migration logic (`v0.4/` → `v0.4.21/` on first run)
  - Update all template operations (install, update, upgrade) to use patch-level dirs
- Consequences: Enables patch-level upgrades (critical for bug fixes), clear version tracking and audit trail, aligns with semantic versioning best practices. Breaking change but migration is automatic and transparent. Each patch version requires full template copy (~few MB per version).
- Links: [versions_spec.md v0.5.0](versions_spec.md), [pyve.sh compare_semver()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:106:0-118:1), [pyve.sh migrate_template_directories()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:109:0-122:1)

## 2025-10-16: Interactive Init for Conflict Resolution
- Context: Prior to v0.4.17, `--init` would abort with an error if ANY file differed from templates, leaving users stuck. Old projects (pre-v0.3.2) without `.pyve/version` couldn't use `--upgrade`. v0.4.16 introduced `--repair` but it created "fake state" (wrote current version even though templates were old).
- Decision: Make `--init` smart enough to handle all scenarios:
  - Detect conflicts and prompt user interactively
  - If user confirms: use smart copy logic (identical → overwrite, modified → preserve + create `__t__v0.X` copy, new → add)
  - If user declines: abort gracefully
  - Eliminate separate `--repair` command
- Consequences: Single command handles new projects, old projects, and partial upgrades. Better UX, no fake state, clearer intent. Users can safely run `--init` on any project.
- Links: [versions_spec.md v0.4.17](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:29:0-49:0), [pyve.sh init_copy_templates()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:1076:0-1229:1)

## 2025-10-16: Project Context as Pre-Technical Phase
- Context: Technical designs often started without understanding business context, stakeholders, constraints, or success criteria. This led to misaligned solutions and unclear Quality level selection.
- Decision: Introduce "Project Context Phase" before technical design:
  - 8-question Q&A session (10-20 min) covering: vision, stakeholders, success criteria, constraints, ecosystem, scope, timeline, Quality level
  - Creates `docs/context/project_context.md` as living document
  - Provides foundation for all technical decisions
  - Optional for experiment Quality, recommended for all others
- Consequences: Better alignment with business needs, informed Quality level selection, clearer scope boundaries. Creates "agreement to go and build" before diving into technical details. Design thinking approach: understand "who, what, why, when, where" before "how."
- Links: [versions_spec.md v0.4.15](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:38:0-95:0), [project_context_questions__t__.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/templates/v0.4/docs/guides/llm_qa/project_context_questions__t__.md:0:0-0:0), [project_context__t__.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/templates/v0.4/docs/context/project_context__t__.md:0:0-0:0)

## 2025-10-16: Smart Copy Logic for Template Upgrades
- Context: Need to upgrade templates across versions without destroying user modifications. Simple overwrite loses work; manual merge is error-prone.
- Decision: Implement three-way comparison algorithm:
  1. If destination file identical to old template version → safe to overwrite with new version
  2. If destination file modified by user → preserve original, create suffixed copy (`filename__t__v0.X.md`) for manual review
  3. If destination file doesn't exist → add new file
  - Used by both `--upgrade` and `--init` (when conflicts detected)
- Consequences: Safe upgrades with zero data loss. Users can review suffixed files and merge changes manually. Clear distinction between automated updates and manual review needed. Enables confident template evolution.
- Links: [pyve.sh upgrade_templates()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:1582:0-1708:1), [versions_spec.md v0.3.6](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:0:0-0:0)

## 2025-10-16: Foundation vs Package Architecture
- Context: Not all documentation should be copied by default. Some docs are domain-specific (web, persistence, infrastructure) while others are universal (specs, guides, lang).
- Decision: Two-tier template architecture:
  - **Foundation** (always copied): root docs, top-level guides, specs, lang guides, llm_qa, context
  - **Packages** (optional): web, persistence, infrastructure, analytics
  - `list_template_files()` function with mode parameter: "foundation", "all", or specific package name
  - Users can `--add` or `--remove` packages; tracked in `.pyve/packages.conf`
- Consequences: Lean default installs (~20 files vs ~40+), extensible without bloat. Clear separation of concerns. Package system enables domain-specific guidance without forcing it on everyone.
- Links: [pyve.sh list_template_files()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:1034:0-1068:1), [versions_spec.md v0.3.11](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:0:0-0:0)

## 2025-10-16: Template Suffix Convention
- Context: Need to distinguish template files from actual project files in the repository. Templates should be clearly marked and easy to find/process programmatically.
- Decision: Use `__t__` suffix for all template files:
  - Template: `README__t__.md` → Destination: `README.md`
  - Version-specific templates: `README__t__v0.4.md` (for manual review during upgrades)
  - Suffix stripped during copy via `target_path_for_source()` function
  - All template searches use `find ... -name "*__t__*.md"`
- Consequences: Clear visual distinction, simple sed/find operations, enables version-specific suffixes for upgrade conflicts. Convention is self-documenting. Easy to identify which files are templates vs actual project files.
- Links: [pyve.sh target_path_for_source()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:1070:0-1074:1), [pyve.sh list_template_files()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:1034:0-1068:1)

## 2025-10-16: Local State in .pyve Directory
- Context: Need to track template versions and operation history per project/developer. This state is machine-specific and should never be shared across team members.
- Decision: Store all local pyve state in `.pyve/` directory:
  - `.pyve/version` - tracks which template version was installed (e.g., "Version: 0.4.19")
  - `.pyve/status/` - operation logs (init, upgrade, purge timestamps)
  - `.pyve/packages.conf` - which optional doc packages are installed
  - Automatically added to `.gitignore` during `--init`
  - Never committed to version control
- Consequences: Each developer can be on different pyve versions independently. Template version mismatches are explicit. Operation history aids debugging. Clean separation between shared templates (in `docs/`) and local state (in `.pyve/`).
- Links: [versions_spec.md v0.4.18](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:33:0-50:0), [pyve.sh ensure_project_pyve_dirs()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:629:0-631:1)

## 2025-10-16: Quality Levels Drive Requirements
- Context: Projects have different needs for rigor, testing, and process. Over-engineering experiments wastes time; under-engineering production systems creates risk.
- Decision: Define four explicit Quality levels with different entry/exit criteria:
  - **Experiment**: Speed over rigor, minimal tests, throwaway acceptable
  - **Prototype**: Validate function/UX, basic error handling, smoke tests
  - **Production**: Reliability, observability, CI/CD, SLOs, on-call readiness
  - **Secure**: Threat modeling, hardening, least-privilege, audits/compliance
  - Quality level declared in `technical_design_spec.md` and `codebase_spec.md`
  - Drives testing requirements, review processes, deployment rigor
- Consequences: Right-sized processes, clear expectations, no ambiguity about "how much is enough." Teams can move fast on experiments while maintaining rigor on production systems. Quality level can evolve as project matures.
- Links: [technical_design_spec__t__.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/templates/v0.4/docs/specs/technical_design_spec__t__.md:0:0-0:0), [planning_guide__t__.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/templates/v0.4/docs/guides/planning_guide__t__.md:0:0-0:0)

## 2025-10-16: LLM Q&A Phase Structure
- Context: Need structured approach for LLM-assisted development that's token-efficient and progressively detailed. Ad-hoc conversations waste tokens and miss critical details.
- Decision: Phase-based Q&A workflow with dedicated question files:
  - **Project Context Phase**: 8 questions (who, what, why, when, where) before technical details
  - **Phase 0**: Project basics (repository, quality, components, runtime)
  - **Phases 1-16**: Progressive detail (core technical → deployment → operations → optimization)
  - Each phase has dedicated `llm_qa_phaseX_questions__t__.md` file
  - Principles documented in `llm_qa_principles__t__.md`
  - LLMs offer appropriate phase based on project state
- Consequences: Consistent onboarding experience, token-efficient sessions (focused questions per phase), progressive detail prevents overwhelm. Clear handoff points between phases. Reusable across projects.
- Links: [versions_spec.md v0.4.15](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:38:0-95:0), [llm_qa/README__t__.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/templates/v0.4/docs/guides/llm_qa/README__t__.md:0:0-0:0), [llm_qa_principles__t__.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/templates/v0.4/docs/guides/llm_qa/llm_qa_principles__t__.md:0:0-0:0)

## 2025-10-13: Install Handoff and Idempotency Policies
- Context: Version mismatches and noisy failures during install/init.
- Decision:
  - Install handoff: delegate to recorded source or local ./pyve.sh when appropriate; guard with PYVE_SKIP_HANDOFF.
  - Idempotent init: treat `./.pyve/status/init` (and benign files) as safe; skip copy; fail on unexpected status files.
  - Identical-target install: skip copy if identical; ensure executable and symlink.
  - Noise suppression: disable tracing in [init_copy_templates()](cci:1://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:628:0-698:1), log to `./.pyve/status/init_copy.log`.
  - Direnv guidance ordering: print last in `--init`.
- Consequences: Reliable installs, repeatable init, cleaner UX.
- Links: [pyve.sh](cci:7://file:///Users/pointmatic/Documents/Code/pyve/pyve.sh:0:0-0:0), [docs/specs/versions_spec.md](cci:7://file:///Users/pointmatic/Documents/Code/pyve/docs/specs/versions_spec.md:0:0-0:0) (v0.3.2a and v0.3.3 Notes), `docs/guides/building_guide.md`.

## 2025-10-12: Dependency and Version Management Policy
- Context: Prior guidance pinned only top-level packages in `requirements.txt` without ranges and discouraged constraints/lock tooling. We want a reliable, updatable, and LLM-friendly workflow that preserves reproducibility.
- Decision: Adopt `docs/guides/dependencies_guide.md` as the single source of truth.
  - Applications: use `pip-tools` with `requirements.in` (ranges) → compiled `requirements.txt` (exact pins + hashes). Install strictly from the lockfile. Update via `pip-compile --upgrade` with tests and audits.
  - Libraries: declare bounded ranges in `pyproject.toml`; avoid hard pins for consumers; test with `constraints.txt`.
- Consequences: Clear policy for updates, fewer breakages from unbounded installs, deterministic deploys, and explicit separation between app and library practices.
- Links: See `docs/guides/dependencies_guide.md`.

## 2025-10-12: Documentation Split and Process Clarification
- Context: `docs/versions.md` was carrying process guidance that made it noisy.
- Decision: Create separate docs for process and keep versions history in `docs/specs/versions_spec.md`.
  - `docs/guides/building_guide.md`: roles, workflow, dependencies, commands policy.
  - `docs/guides/planning_guide.md`: phases, versioning, how to author `technical_design_spec.md`.
  - `docs/guides/testing_guide.md`: testing strategies and guidance.
- Consequences: Clearer responsibilities, easier onboarding; `versions.md` remains a concise history.

## 2025-10-12: Dependency Pinning Policy (Superseded by 2025-10-12: Dependency and Version Management Policy)
- Context: Need a stable, reproducible environment while avoiding over-pinning.
- Decision: Install top‑level packages via `pip install {package}` (no version), record the installed version, and pin only that package in `requirements.txt` with `=={version}`. Do not pin transitive dependencies or use ranges (`>=`, `<`).
- Consequences: Reproducible top-level set with flexibility for transitive updates; simpler upgrades.

## 2025-10-12: Command Safety Policy
- Context: Allow the LLM to run safe commands but avoid destructive operations.
- Decision: OK to run `pip install` (one package at a time), `pytest`, and program entry points. Not OK to run `rm` or `mv`; ask human first (prefer `git mv`).
- Consequences: Safer automation; human remains gatekeeper for destructive actions.

## 2025-10-12: Versioning and Microversions
- Context: Need structured logging of changes and bugfixes.
- Decision: Use semantic versions `v{major}.{minor}.{incremental}`; append microversions `a/b/c/...` for quick follow‑up bugfixes not already captured in `docs/specs/versions_spec.md` (e.g., `v0.0.2a`). Use `[Next]` tag to propose a future semantic version tied to a broader plan.
- Consequences: Transparent history; clear separation between planned work and immediate fixes.
