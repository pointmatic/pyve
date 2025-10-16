# Pyve Version History

## References
- Building Guide: `docs/guides/building_guide.md`
- Planning Guide: `docs/guides/planning_guide.md`
- Testing Guide: `docs/guides/testing_guide.md`
- Dependencies Guide: `docs/guides/dependencies_guide.md`
- Decision Log: `docs/specs/decisions_spec.md`
- Codebase Spec: `docs/specs/codebase_spec.md`

## v0.5.2 Deprecate --update Command [Next]
- [ ] Add deprecation warning to `--update` command
- [ ] Update help text to recommend `--install` instead
- [ ] Update documentation to remove `--update` references
- [ ] Plan for removal in v0.6.0

### Notes
- **Problem:** `--update` and `--install` have significant overlap, creating confusion about which to use
- **Analysis:**
  - `--install`: Copies pyve.sh + copies templates + records source path
  - `--update`: Only copies templates (requires source_path already recorded)
  - Both require access to source repo or recorded source_path
  - `--install` is idempotent, can be run repeatedly without harm
- **User confusion:**
  - When to use `--install` vs `--update`?
  - Answer: Just use `--install` for everything
- **Solution:** Deprecate `--update` in favor of `--install`
- **Implementation:**
  - Add deprecation warning when `--update` is called:
    ```bash
    echo "\nWARNING: 'pyve --update' is deprecated and will be removed in v0.6.0."
    echo "Use 'pyve --install' instead, which updates both the script and templates."
    echo "Continuing with template update..."
    ```
  - Update help text:
    ```bash
    # Remove or mark as deprecated:
    # echo "  --update:  Update documentation templates..."
    
    # Update --install description:
    echo "  --install: Install/update this script and templates to ~/.local/bin"
    echo "             Run this to get the latest pyve.sh and templates"
    echo "             Safe to run multiple times (idempotent)"
    ```
  - Update README and guides to only mention `--install`
  - Keep `--update` functional but warn users
  - Remove entirely in v0.6.0
- **Rationale:**
  - Simpler mental model: one command for installation and updates
  - Reduces maintenance burden (one code path instead of two)
  - `--install` already does everything users need
  - Only one user (you) affected, easy migration
- **Migration path:**
  - v0.5.2: Add deprecation warning, update docs
  - v0.6.0: Remove `--update` command entirely
- **Version bumped:** pyve.sh v0.5.1 → v0.5.2

## v0.5.1 Pyve-Owned Directories [Implemented]
- [x] Define `PYVE_OWNED_DIRS` array for directories Pyve controls
- [x] Update conflict detection to skip owned directories
- [x] Always overwrite files in Pyve-owned directories during init/upgrade
- [x] Update documentation to explain ownership model

### Notes
- **Problem:** Some directories should be Pyve-controlled (e.g., `docs/guides/`) but current logic treats all files equally, creating suffixed copies even when Pyve should just overwrite
- **User experience issue:**
  - User runs `--upgrade`
  - `docs/guides/building_guide.md` was modified locally
  - Creates `building_guide__t__v0.5.md` suffixed copy
  - But guides are process documentation that Pyve owns, not user specs
- **Solution:** Define directory ownership model
- **Implementation:**
  - **Pyve-owned directories** (always overwrite, no conflict detection):
    ```bash
    PYVE_OWNED_DIRS=(
        "docs/guides"
        "docs/context"
        "docs/guides/llm_qa"
    )
    ```
  - **User-owned directories** (preserve on conflict, create suffixed copies):
    ```bash
    # Everything else, including:
    # - docs/specs/
    # - docs/decisions/
    # - README.md
    # - CONTRIBUTING.md
    ```
  - **Conflict detection logic:**
    ```bash
    function is_pyve_owned() {
        local FILE="$1"
        for DIR in "${PYVE_OWNED_DIRS[@]}"; do
            if [[ "$FILE" == "$DIR"/* ]]; then
                return 0  # Pyve owns this
            fi
        done
        return 1  # User owns this
    }
    
    # In init_copy_templates and upgrade_templates:
    if is_pyve_owned "$DEST_REL"; then
        # Always overwrite, no conflict check
        cp "$FILE" "$DEST_ABS"
    else
        # Check for conflicts, create suffixed copy if needed
        if ! cmp -s "$FILE" "$DEST_ABS"; then
            # Create suffixed copy...
        fi
    fi
    ```
  - Update help text and docs to explain ownership model
- **Rationale:**
  - Process guides (building, planning, testing) are Pyve methodology, not project-specific
  - Technical specs (codebase, technical design) are project-specific, user-owned
  - Clear ownership prevents confusion about which files to edit
  - Users can still add their own files to any directory
- **Version bumped:** pyve.sh v0.5.0 → v0.5.1

## v0.5.0 Patch-Level Template Versioning [Implemented]
- [x] Store templates at patch level (e.g., `0.5.0/`, `0.5.1/`) instead of minor level (`0.5/`)
- [x] Update `find_latest_template_version()` to compare full semver versions
- [x] Update `--install` to create patch-level directories
- [x] Update `--update` to create patch-level directories
- [x] Update `--upgrade` to compare exact patch versions
- [x] Add migration logic to handle existing `0.4/` → `0.4.21/` on first run
- [x] Update `.pyve/version` format to store exact version

### Notes
- **Problem:** Templates stored at minor version level (e.g., `~/.pyve/templates/0.4/`) means all v0.4.x versions overwrite the same directory, making it impossible to upgrade from 0.4.20 → 0.4.21
- **Root cause:** Version granularity is too coarse
- **Current behavior:**
  - User has project at v0.4.20
  - Runs `pyve --update` (downloads v0.4.21)
  - Templates stored in `~/.pyve/templates/0.4/` (overwrites v0.4.20)
  - Runs `pyve --upgrade`
  - Compares `0.4` vs `0.4` → "already up to date"
  - Cannot upgrade to v0.4.21
- **Expected behavior:**
  - Templates stored at patch level: `~/.pyve/templates/0.4.21/`
  - Project version: `.pyve/version` contains `Version: 0.4.20`
  - `--upgrade` compares `0.4.20` < `0.4.21` → upgrade available
- **Solution:** Store templates at full semver patch level
- **Implementation:**
  - **Directory structure:**
    ```bash
    ~/.pyve/templates/
    ├── 0.4.20/
    ├── 0.4.21/
    ├── 0.5.0/
    └── 0.5.1/
    ```
  - **Version comparison:**
    ```bash
    function compare_semver() {
        # Compare two semver strings (e.g., "0.4.20" vs "0.4.21")
        # Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
        local v1="$1"
        local v2="$2"
        
        # Split into major.minor.patch
        local v1_major=$(echo "$v1" | cut -d. -f1)
        local v1_minor=$(echo "$v1" | cut -d. -f2)
        local v1_patch=$(echo "$v1" | cut -d. -f3)
        
        local v2_major=$(echo "$v2" | cut -d. -f1)
        local v2_minor=$(echo "$v2" | cut -d. -f2)
        local v2_patch=$(echo "$v2" | cut -d. -f3)
        
        # Compare major, then minor, then patch
        if [[ $v1_major -gt $v2_major ]]; then return 1; fi
        if [[ $v1_major -lt $v2_major ]]; then return 2; fi
        if [[ $v1_minor -gt $v2_minor ]]; then return 1; fi
        if [[ $v1_minor -lt $v2_minor ]]; then return 2; fi
        if [[ $v1_patch -gt $v2_patch ]]; then return 1; fi
        if [[ $v1_patch -lt $v2_patch ]]; then return 2; fi
        return 0
    }
    ```
  - **find_latest_template_version():**
    ```bash
    function find_latest_template_version() {
        local TEMPLATES_DIR="$1"
        local LATEST=""
        
        for DIR in "$TEMPLATES_DIR"/templates/*/; do
            [[ ! -d "$DIR" ]] && continue
            local VERSION=$(basename "$DIR")
            
            # Skip if not valid semver (e.g., .DS_Store)
            if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                continue
            fi
            
            if [[ -z "$LATEST" ]]; then
                LATEST="$VERSION"
            else
                compare_semver "$VERSION" "$LATEST"
                if [[ $? -eq 1 ]]; then
                    LATEST="$VERSION"
                fi
            fi
        done
        
        echo "$LATEST"
    }
    ```
  - **Migration logic:**
    ```bash
    # On first run of v0.5.0, migrate old 0.4/ to 0.4.21/
    if [[ -d ~/.pyve/templates/0.4 ]] && [[ ! -d ~/.pyve/templates/0.4.21 ]]; then
        echo "Migrating templates from 0.4/ to 0.4.21/..."
        mv ~/.pyve/templates/0.4 ~/.pyve/templates/0.4.21
    fi
    ```
  - **--install and --update:** Create directories like `0.5.0/` not `0.5/`
  - **--upgrade:** Compare full semver versions
- **Breaking change:** Existing installations with `0.4/` will be migrated to `0.4.21/`
- **Disk space:** Each patch version requires full template copy (~few MB per version)
- **Rationale:**
  - Enables patch-level upgrades (critical for bug fixes)
  - Clear version tracking and audit trail
  - Aligns with semantic versioning best practices
- **Version bumped:** pyve.sh v0.4.21 → v0.5.0 (breaking change)

## v0.4.21 Fix Status Blocking Logic [Implemented]
- [x] Update `upgrade_status_fail_if_any_present()` to only block when `action_needed` exists
- [x] Update `fail_if_status_present()` to only block when `action_needed` exists
- [x] Update `purge_status_fail_if_any_present()` to only block when `action_needed` exists
- [x] Allow normal status files from successful operations to coexist without blocking

### Notes
- **Problem:** Status files from successful operations (e.g., `.pyve/status/init`) block future operations even though nothing is wrong
- **Root cause:** `upgrade_status_fail_if_any_present()` checks if ANY files exist in `.pyve/status/`, treating all status files as blocking
- **Current behavior:**
  - User runs `pyve --init` → creates `.pyve/status/init` (success marker)
  - User runs `pyve --upgrade` → ERROR: "One or more status files exist"
  - User must run `pyve --clear-status init` even though init succeeded
- **Expected behavior:**
  - Status files from successful operations should NOT block future operations
  - Only block when `.pyve/action_needed` exists (indicating incomplete merge)
- **Solution:** Change blocking logic to check for `action_needed` file first
- **Implementation:**
  - Update `upgrade_status_fail_if_any_present()`:
    ```bash
    # Only block if action_needed exists (indicates incomplete merge)
    if [[ -f ./.pyve/action_needed ]]; then
        echo "\nERROR: Manual merge required."
        echo ""
        cat ./.pyve/action_needed
        exit 1
    fi
    # Status files without action_needed = successful operations, don't block
    ```
  - Update `init_status_fail_if_conflicts()` similarly
  - Status files remain as audit trail but don't block operations
  - `action_needed` file is the sole blocker
- **Rationale:**
  - Status files serve as audit trail (when operations ran)
  - Blocking should only happen when user action is required
  - Separates "operation history" from "operation incomplete"
- **Version bumped:** pyve.sh v0.4.20 → v0.4.21

## v0.4.20 Clear Status After Manual Merge [Implemented]
- [x] Add `--clear-status <operation>` command to mark manual merge complete
- [x] Create `.pyve/action_needed` file when suffixed files are created during init/upgrade
- [x] Update error messages to reference `.pyve/action_needed` file with clear instructions
- [x] Auto-clean `.pyve/action_needed` when status is cleared
- [x] Update `.pyve/version` when clearing upgrade status

### Notes
- **Problem:** When `--init` or `--upgrade` creates suffixed files (e.g., `filename__t__v0.4.md`) for manual merge, the status file blocks future operations with no clear way to signal "merge complete"
- **User experience issues:**
  - Status file remains after manual merge, blocking `--upgrade`
  - Error message "One or more status files exist" is cryptic
  - No guidance on how to clear the block
  - `.pyve/version` shows old version until upgrade completes
- **Solution:** Add explicit workflow for resolving manual merge state
- **Implementation:**
  - **New command:** `pyve --clear-status <operation>` where operation is `init` or `upgrade`
  - **Action needed file:** `.pyve/action_needed` created when suffixed files are generated
  - **File contents:**
    ```
    Manual merge required for the following files:
      - docs/guides/building_guide__t__v0.4.md
      - docs/specs/codebase_spec__t__v0.4.md
    
    To complete:
    1. Review and merge changes from suffixed files
    2. Delete suffixed files when satisfied
    3. Run: pyve --clear-status init
    
    Until resolved, 'pyve --upgrade' is blocked.
    ```
  - **Enhanced error messages:**
    - When status files exist, check for `.pyve/action_needed`
    - If exists, display its contents
    - If not, show generic "Run 'pyve --clear-status <operation>' to clear"
  - **Clear status behavior:**
    - Removes `.pyve/status/<operation>` file
    - Removes `.pyve/action_needed` file
    - For `upgrade`: updates `.pyve/version` to current version
    - Confirms action: "Status cleared for <operation>. You can now run pyve --upgrade."
- **User workflow:**
  1. Run `pyve --init` or `pyve --upgrade`
  2. If conflicts: suffixed files created, `.pyve/action_needed` written
  3. User reviews and merges changes
  4. User deletes suffixed files
  5. User runs `pyve --clear-status init` (or `upgrade`)
  6. Status cleared, operations unblocked
- **Edge cases:**
  - If no `.pyve/action_needed` exists, `--clear-status` still works (manual override)
  - If suffixed files still exist, warn but allow clearing (user choice)
  - `--clear-status` without operation shows usage
- **Version bumped:** pyve.sh v0.4.19 → v0.4.20

## v0.4.19 Include Context, LLM Q&A in Foundation, various minor doc updates [Implemented]
- [x] Add `docs/context/` to foundation template files
- [x] Add `docs/guides/llm_qa/` to foundation template files
- [x] Exclude `llm_qa` from package-specific search to avoid duplication
- [x] Add missing phase comments to `implementation_options_spec__t__.md`
- [x] Update `CONTRIBUTING.md` to be language-agnostic
- [x] Add Configuration, Development, Security, and Acknowledgments sections to `README.md`

### Notes
- **Problem:** New directories added in v0.4.15 (`docs/context/` and `docs/guides/llm_qa/`) were not being copied during `--init`
- **Root cause:** `list_template_files()` function didn't include these directories in foundation search
- **Solution:** Explicitly add both directories to foundation template search
- **Implementation:**
  - Added `find "$SRC_DIR/docs/context" -type f -name "*__t__*.md"` to foundation search
  - Added `find "$SRC_DIR/docs/guides/llm_qa" -type f -name "*__t__*.md"` to foundation search
  - Excluded `llm_qa` from package wildcard search (line 1060: `! -path "*/llm_qa/*"`) to prevent duplication
- **Files now included in foundation:**
  - `docs/context/project_context__t__.md` (Project Context template)
  - `docs/guides/llm_qa/README__t__.md` (LLM Q&A overview)
  - `docs/guides/llm_qa/project_context_questions__t__.md` (Project Context Q&A)
  - `docs/guides/llm_qa/llm_qa_principles__t__.md` (Q&A principles)
  - All phase Q&A files (phase0-16)
- **Rationale:** Project Context and LLM Q&A are core to the pyve workflow, not optional packages
- **Phase comment consistency fixes:**
  - Added `<!-- Phase 0: Project Basics -->` before `## Option Matrix` heading
  - Added `<!-- Template: Copy/paste this section to evaluate specific options in detail -->` before `## Candidate Option (Template)`
  - Added `<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->` before `## Decision`
  - Added `<!-- Phase 1: Core Technical -->` before `## Impact`
  - Ensures all major sections have phase comments for LLM guidance
- **Documentation improvements:**
  - Updated `CONTRIBUTING.md` to be language-agnostic (removed Python-specific examples, generalized setup/testing instructions)
  - Added reference to Project Context Q&A in Planning section
  - Updated README stub guidance to be stack-agnostic
  - Added `README.md` sections to match template structure:
    - **Configuration**: Environment variables, configuration files, CLI flags
    - **Development**: Contributing guide, key documentation links, LLM collaboration guidance
    - **Security**: File safety (non-destructive behavior), secrets management, development safety
    - **Acknowledgments**: Credits to communities and methodologies
- **Version bumped:** pyve.sh v0.4.18 → v0.4.19

## v0.4.18 Auto-gitignore .pyve Directory [Implemented]
- [x] Add `.pyve` to `.gitignore` automatically during `--init`
- [x] Remove `.pyve` from `.gitignore` during `--purge`

### Notes
- **Problem:** `.pyve/` directory contains local state (version, status files, logs) that should never be committed to version control
- **Solution:** Automatically add `.pyve` to `.gitignore` during initialization
- **Implementation:**
  - `init_misc_artifacts()`: Adds `.pyve` pattern to `.gitignore` (or creates `.gitignore` if missing)
  - `purge_misc_artifacts()`: Removes `.pyve` pattern from `.gitignore` during cleanup
  - Uses existing `append_pattern_to_gitignore()` and `remove_pattern_from_gitignore()` infrastructure
- **Rationale:** `.pyve/` is purely local infrastructure:
  - `.pyve/version` - tracks which template version was installed locally
  - `.pyve/status/` - tracks init/upgrade/purge operations
  - `.pyve/packages.conf` - tracks which doc packages are installed
  - None of these should be shared across team members or repositories
- **Version bumped:** pyve.sh v0.4.17 → v0.4.18

## v0.4.17 Smart Init with Interactive Upgrade [Implemented]
- [x] Remove `--repair` command (superseded by smart init)
- [x] Update `init_copy_templates()` to use upgrade's smart copy logic when conflicts detected
- [x] Add interactive prompt when conflicts found:
  - [x] List all conflicting files
  - [x] Ask user to confirm continuation
  - [x] If yes: use smart copy (preserve modified, create suffixed copies)
  - [x] If no: abort gracefully
- [x] Update `--upgrade` error message to suggest `pyve --init`
- [x] Update help text to remove `--repair` references
- [x] Report results like upgrade does (upgraded/added/skipped counts)

### Notes
- **Problem:** v0.4.16's `--repair` created "fake state" - wrote current version to `.pyve/version` even though templates were old
- **Solution:** Make `--init` smart enough to handle all scenarios, eliminating need for separate `--repair` command
- **Implementation:**
  - `--init` now detects conflicts and prompts user interactively
  - Uses same smart copy logic as `--upgrade`:
    - Identical files → overwrite
    - Modified files → preserve original, create `__t__v0.4` suffixed copy
    - Missing files → add new
  - Reports results: "Copied/Added: X files, Preserved: Y files"
  - User can cancel if they don't want to proceed
- **Behavior changes:**
  - **Old behavior:** `--init` aborted with error if ANY file differed from template
  - **New behavior:** `--init` prompts user and offers smart copy
  - **Result:** Single command handles new projects, old projects, and partial upgrades
- **Error message simplified:**
  - `--upgrade` now suggests only `pyve --init` (not `--repair`)
  - Explains what `--init` will do (safe, preserves modified files)
- **Removed:**
  - `repair_project()` function
  - `--repair` command routing
  - All `--repair` references in help text
- **User experience:**
  - **New projects:** `pyve --init` → copies templates, no prompts
  - **Old projects:** `pyve --init` → detects conflicts, prompts, smart copy
  - **Existing projects:** `pyve --init` → detects previous init, skips
- **Version bumped:** pyve.sh v0.4.16 → v0.4.17

## v0.4.16 Repair Command for Old Projects [Superseded by v0.4.17]
- [x] Add `--repair` command to create missing infrastructure for old pyve projects
- [x] Implement `repair_project()` function that:
  - [x] Creates `.pyve/version` file if missing
  - [x] Creates `.pyve/status/` directory if missing
  - [x] Reports what was repaired
  - [x] Never touches existing files
- [x] Update `--upgrade` error message to suggest `--repair` or `--init`
- [x] Update help text to include `--repair` option
- [x] Add command routing for `--repair` flag

### Notes
- **Problem:** Old pyve projects (pre-v0.3.2) don't have `.pyve/version` file, causing `--upgrade` to fail
- **Solution:** New `--repair` command creates minimal infrastructure without touching existing files
- **Implementation:**
  - `repair_project()` function checks and creates:
    - `.pyve/version` file (with current pyve version)
    - `.pyve/status/` directory
  - Reports what was repaired vs what was already OK
  - Completely non-invasive: never modifies existing files
- **Error message improvement:**
  - `--upgrade` now provides clear guidance when `.pyve/version` is missing
  - Explains the difference between `--repair` (minimal) and `--init` (full)
  - Recommends trying `--repair` first for old projects
- **Help text updated:** Added `--repair` to usage string and description
- **Version bumped:** pyve.sh v0.3.14 → v0.4.16

## v0.4.15 Project Context Phase [Implemented]
- [x] Review and revise the project brief concept → renamed to "Project Context"
- [x] Build an LLM Q&A doc in the `llm_qa` document directory/package (in guides) that can be used before all the other Q&A to determine who, what, when, where, and why of a project before getting committed to the technical details.
- [x] As appropriate, integrate this option into the `llm_qa_principles__t__.md` doc and the `README__t__.md` doc in the same directory. 
- [x] Integrate the Project Context...
  - [x] into other spec docs as appropriate
  - [x] into the `planning_guide__t__.md`
  - [x] into the `llm_onramp_guide__t__.md`
  - [x] into root `README__t__.md`
  - [x] into `CONTRIBUTING__t__.md`

### Notes
- **Renamed:** "Project Brief" → "Project Context" (better reflects purpose: understanding context before technical decisions)
- **File structure:**
  - Created `templates/v0.4/docs/context/` directory for business/organizational context
  - Created `templates/v0.4/docs/context/project_context.md` template
  - Created `templates/v0.4/docs/guides/llm_qa/project_context_questions__t__.md` Q&A guide
  - Removed old `templates/v0.4/docs/specs/project_brief_spec__t__.md`
- **Design decisions:**
  - **Optional but recommended:** Project Context is optional for experiment Quality, recommended for all others
  - **Iterative updates:** Living document with changelog section for tracking evolution
  - **Quality level integration:** Project Context Q&A recommends Quality level based on constraints/compliance
  - **Relationship to technical_design_spec:** Overview/Goals sections should summarize key points from Project Context
  - **Terminology clarification:** "Components" in Project Context = external ecosystem; "Components" in technical_design_spec = internal architecture
- **Project Context Q&A (8 questions, 10-20 min):**
  1. Project vision & purpose (problem statement)
  2. Primary stakeholders (decision makers, users, maintainers)
  3. Success criteria & metrics (measurable outcomes)
  4. Constraints & requirements (timeline, budget, compliance, technical)
  5. Ecosystem & integration context (external systems to integrate with)
  6. Scope & boundaries (in/out of scope for v1.0)
  7. Timeline & milestones (target dates, flexibility)
  8. Quality level recommendation (based on previous answers)
- **Example Q&A sessions:** Two complete examples included
  - Example 1: Internal sales dashboard (production Quality)
  - Example 2: Personal expense tracker (experiment Quality)
- **Integration points updated:**
  - `llm_qa/README__t__.md`: Added Project Context Phase to structure and quick reference
  - `llm_qa_principles__t__.md`: Added Project Context Phase definition and updated workflow
  - `planning_guide__t__.md`: Added Project Context to Q&A alignment table and workflow
  - `llm_onramp_guide__t__.md`: Updated new project workflow to include Project Context first
  - `README__t__.md`: Added Project Context reference to Development section
  - `CONTRIBUTING__t__.md`: Added Project Context reference and planning guidance
  - `technical_design_spec__t__.md`: Added note about relationship to Project Context, guidance for Overview/Goals, clarified Components distinction
- **Philosophy:** Design thinking approach - understand "who, what, why, when, where" before diving into technical "how"
- **Outcome:** Creates "agreement to go and build" - foundation for all technical decisions
- **Token efficiency:** ~500 lines (~15K tokens) for Project Context Q&A, keeps sessions manageable

## v0.4.14 Local .env support [Implemented]
Focus: User-defined environment variable template
- [x] Support user-defined secrets file in `~/.local/.env`
- [x] Support copying `~/.local/.env` to project directory on init with `--local-env` flag
- [x] Create `~/.local/.env` (empty, chmod 600) during `--install`
- [x] Delete `~/.local/.env` (if empty) during `--uninstall`
- [x] Update help text and usage documentation
- [x] Update root README

### Notes
- **Feature**: `--local-env` flag for `pyve --init`
  - Default behavior: Creates empty `.env` file (chmod 600)
  - With `--local-env`: Copies from `~/.local/.env` if it exists
  - Falls back to empty file with warning if template not found
- **Install behavior**: Creates empty `~/.local/.env` (chmod 600) if it doesn't exist
- **Uninstall behavior**: Removes `~/.local/.env` only if empty, keeps non-empty files
- **Use case**: Developers can maintain a master `.env` template with common secrets/environment variables
- **Security**: All `.env` files created with chmod 600 (owner read/write only)
- **Version**: Added in pyve.sh v0.3.14 (internal version tracking)

## v0.4.13 LLM Q&A Phase 16 (Security Governance) [Implemented]
Focus: Security governance for secure Quality
- [x] Split from archived Phase 3 (llm_qa_phase11-16_archive__t__.md)
- [x] Create `docs/guides/llm_qa/llm_qa_phase16_questions__t__.md`:
  - [x] Security policies questions (formal policies, review process)
  - [x] Risk assessment questions (methodology, frequency, documentation)
  - [x] Third-party security questions (vendor assessment, contracts, monitoring)
  - [x] Security metrics questions (KPIs, tracking, reporting)
- [x] `llm_qa` directory README already includes Phase 16 in structure (completed in v0.4.4)
- [x] root README updated with latest features and benefits. 

### Notes
- **Phase 16 Questions File** (~280 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase16_questions__t__.md`
  - Security policies: Information Security, Acceptable Use, Access Control, Data Classification, Incident Response, Change Management, Vendor Management, BC/DR. Annual review, executive approval, employee acknowledgment
  - Risk assessment: Methodology (identify, analyze likelihood × impact, prioritize, treat), frequency (annual comprehensive, quarterly review, ad-hoc), documentation (risk register, treatment plans, acceptance)
  - Third-party security: Pre-contract assessment (questionnaire, SOC 2), risk categorization (critical/high/low), contract requirements (DPA, BAA, SLA, breach notification), ongoing monitoring (annual review, SOC 2 reports), offboarding
  - Security metrics: Vulnerabilities (open by severity, MTTR, scan coverage, patch compliance), Incidents (count, MTTD, MTTR, recurrence), Access (MFA %, least privilege %, access reviews), Compliance (policy reviews, training, vendor assessments), Awareness (training completion, phishing rate)
  - Tracking and reporting: Dashboards (Grafana, Datadog), reports (weekly, monthly, quarterly, annual)
  - Resources: NIST Cybersecurity Framework, ISO 27001, CIS Controls, OWASP
- **Design decisions:**
  - 4 comprehensive questions covering security governance
  - Required only for secure Quality level
  - Sixth and final secure/compliance phase (11-16)
  - Provides framework for maintaining and improving security program
  - Emphasis on continuous improvement and measurement
- **Milestone:** ALL 17 PHASES (0-16) NOW COMPLETE! 🎉

## v0.4.12 LLM Q&A Phase 15 (Incident Response) [Implemented]
Focus: Formal incident response procedures for secure Quality
- [x] Split from archived Phase 3 (llm_qa_phase11-16_archive__t__.md)
- [x] Create `docs/guides/llm_qa/llm_qa_phase15_questions__t__.md`:
  - [x] Incident response team questions (roles, on-call, escalation)
  - [x] Incident classification questions (severity levels, response times)
  - [x] IR procedures questions (detection, containment, investigation, eradication, recovery, postmortem)
  - [x] Breach notification questions (internal, users, regulatory, public)
- [x] README already includes Phase 15 in structure (completed in v0.4.4)

### Notes
- **Phase 15 Questions File** (~270 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase15_questions__t__.md`
  - IR team: Roles (Incident Commander, Technical Lead, Communications Lead, Security Analyst, Legal/Compliance), on-call rotation (primary/secondary, 24/7), escalation path (L1-L4)
  - Incident classification: Severity levels (P0 Critical, P1 High, P2 Medium, P3 Low), response times (immediate, 15 min, 1 hour, next day), notification methods, escalation triggers
  - IR procedures: Detection (monitoring, alerts, reports), Containment (isolate, block, disable), Investigation (logs, root cause, evidence), Eradication (remove threat, patch), Recovery (restore, verify, monitor), Postmortem (blameless, document, improve)
  - Breach notification: Internal (IR team, executives, legal, board), User (GDPR 72h, HIPAA 60d, email/in-app), Regulatory (supervisory authority, HHS, state AGs), Public (press release, blog, media)
  - Notification templates and timelines
  - Resources: NIST SP 800-61, SANS, PagerDuty, Atlassian
- **Design decisions:**
  - 4 comprehensive questions covering formal incident response
  - Required only for secure Quality level
  - Fifth of six secure/compliance phases (11-16)
  - Builds on basic incident response from Phase 5
  - Critical for compliance and trust
  - Emphasis on blameless postmortems and continuous improvement

## v0.4.11 LLM Q&A Phase 14 (Audit Logging) [Implemented]
Focus: Comprehensive audit logging for secure Quality
- [x] Split from archived Phase 3 (llm_qa_phase11-16_archive__t__.md)
- [x] Create `docs/guides/llm_qa/llm_qa_phase14_questions__t__.md`:
  - [x] Audit log requirements questions (events to log, log format, immutability)
  - [x] Audit log retention questions (retention period, storage, access, review)
- [x] README already includes Phase 14 in structure (completed in v0.4.4)

### Notes
- **Phase 14 Questions File** (~190 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase14_questions__t__.md`
  - Audit log requirements: Authentication events (login, logout, password changes, MFA), authorization events (permission changes, access denials), data access events (PII/PHI access, exports, modifications), administrative events (user management, config changes), security events (failed auth, suspicious activity)
  - Log format: Structured JSON with required fields (timestamp, event_type, actor, action, resource, result, IP, user_agent, request_id)
  - Immutability: Write-once storage, cryptographic signing, separate storage, access controls
  - Retention: Compliance-driven (HIPAA 6 years, GDPR 1-7 years, SOC 2 1 year, PCI DSS 1 year) or risk-based (7+ years for high-risk)
  - Storage: Hot storage (90 days), cold storage (archive), separate backup
  - Access controls: Security/compliance team only, MFA required, all access logged
  - Review: Automated monitoring, weekly/monthly/quarterly manual review, compliance audits
  - Best practices: Log before/after, don't log secrets/PII, centralize, separate from app logs, test integrity
- **Design decisions:**
  - 2 focused questions covering audit logging comprehensively
  - Required only for secure Quality level
  - Fourth of six secure/compliance phases (11-16)
  - Builds on basic logging from Phase 5
  - Critical for compliance (HIPAA, SOC 2, PCI DSS)

## v0.4.10 LLM Q&A Phase 13 (Advanced Security) [Implemented]
Focus: Advanced security controls for secure Quality
- [x] Split from archived Phase 3 (llm_qa_phase11-16_archive__t__.md)
- [x] Create `docs/guides/llm_qa/llm_qa_phase13_questions__t__.md`:
  - [x] Advanced encryption questions (detailed specifications, key management)
  - [x] Secrets rotation questions (policies, automation, frequency)
  - [x] Vulnerability management questions (scanning, remediation SLAs)
  - [x] Penetration testing questions (frequency, scope, providers)
  - [x] Security training questions (onboarding, ongoing, role-specific)
- [x] README already includes Phase 13 in structure (completed in v0.4.4)

### Notes
- **Phase 13 Questions File** (~270 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase13_questions__t__.md`
  - Advanced encryption: Database encryption (AES-256-GCM), file storage encryption, application-level encryption, TLS 1.3, mTLS, key management (KMS, HSM, Vault), key rotation (90 days)
  - Secrets rotation: Rotation frequency (30-180 days by criticality), rotation process (manual, semi-automated, fully automated), zero-downtime rotation
  - Vulnerability management: Dependency scanning (pip-audit, Snyk), container scanning (Trivy), infrastructure scanning (AWS Security Hub), code scanning (Bandit), remediation SLAs (Critical 24h, High 7d, Medium 30d, Low 90d)
  - Penetration testing: Frequency (annual minimum), scope (web app, infrastructure, mobile), type (black/gray/white box), providers (external firms, bug bounty), process
  - Security training: Onboarding (4-hour workshop), ongoing (quarterly), role-specific (backend, frontend, DevOps), content (OWASP Top 10, secure coding), verification
- **Design decisions:**
  - 5 comprehensive questions covering advanced security practices
  - Required only for secure Quality level
  - Third of six secure/compliance phases (11-16)
  - Builds on basic security from Phase 4
  - Practical guidance with specific tools and timelines

## v0.4.9 LLM Q&A Phase 12 (Compliance Requirements) [Implemented]
Focus: Regulatory compliance for secure Quality
- [x] Split from archived Phase 3 (llm_qa_phase11-16_archive__t__.md)
- [x] Create `docs/guides/llm_qa/llm_qa_phase12_questions__t__.md`:
  - [x] Applicable regulations questions (GDPR, HIPAA, PCI DSS, SOC 2, CCPA, FERPA)
  - [x] GDPR compliance questions (consent, right to access, deletion, portability, breach notification)
  - [x] HIPAA compliance questions (PHI protection, access controls, audit logs, BAAs, breach notification)
  - [x] PCI DSS compliance questions (card data storage, payment processors, SAQ, scanning)
  - [x] SOC 2 compliance questions (Trust Service Criteria, controls)
- [x] README already includes Phase 12 in structure (completed in v0.4.4)

### Notes
- **Phase 12 Questions File** (~280 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase12_questions__t__.md`
  - Applicable regulations: GDPR, HIPAA, PCI DSS, SOC 2, CCPA, FERPA - when each applies
  - GDPR compliance: Consent mechanisms, data subject rights (access, deletion, portability, rectification), breach notification (72 hours), DPAs
  - HIPAA compliance: PHI protection (encryption, de-identification), access controls (RBAC, MFA), audit logs (6-year retention), BAAs, breach notification (60 days), Security Officer
  - PCI DSS compliance: Card data handling (never store CVV), payment processors (Stripe, Square), SAQ levels (A, A-EP, D), network security, quarterly scanning
  - SOC 2 compliance: Trust Service Criteria (Security, Availability, Confidentiality, Processing Integrity, Privacy), Type I vs Type II, audit process
  - Compliance resources and links provided
- **Design decisions:**
  - 5 comprehensive questions covering major regulations
  - Required only for secure Quality level
  - Second of six secure/compliance phases (11-16)
  - Practical guidance for each regulation
  - Emphasis on using third-party services to reduce compliance burden (e.g., Stripe for PCI)

## v0.4.8 LLM Q&A Phase 11 (Threat Modeling) [Implemented]
Focus: Threat modeling for secure Quality
- [x] Split from archived Phase 3 (llm_qa_phase11-16_archive__t__.md)
- [x] Create `docs/guides/llm_qa/llm_qa_phase11_questions__t__.md`:
  - [x] Threat identification questions (critical threats to application)
  - [x] Attack surface questions (entry points, vulnerabilities)
  - [x] Threat mitigation questions (controls, defenses)
- [x] README already includes Phase 11 in structure (completed in v0.4.4)

### Notes
- **Phase 11 Questions File** (~180 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase11_questions__t__.md`
  - Threat identification questions: Data breach, account takeover, denial of service, data tampering, privilege escalation, supply chain attacks
  - Attack surface questions: Web UI, API endpoints, database, file uploads, third-party integrations, infrastructure, authentication
  - Threat mitigation questions: Specific mitigations for each threat type (encryption, MFA, rate limiting, input validation, audit logging, dependency scanning)
  - Reference to threat modeling frameworks: STRIDE, PASTA, VAST, Attack Trees
- **Design decisions:**
  - 3 focused questions covering threat modeling fundamentals
  - Required only for secure Quality level
  - First of six secure/compliance phases (11-16)
  - Comprehensive coverage of common threats and mitigations
  - Practical examples for each threat category

## v0.4.7 LLM Q&A Phase 10 (Analytics & Observability) [Implemented]
Focus: Analytics and observability for production/secure Quality
- [x] Create `docs/guides/llm_qa/llm_qa_phase10_questions__t__.md`:
  - [x] Business analytics questions (metrics, dashboards, reporting)
  - [x] Application metrics questions (custom metrics, instrumentation)
  - [x] Distributed tracing questions (tracing strategy, tools)
  - [x] Alerting strategy questions (alert rules, notification channels)
  - [x] Dashboard design questions (key metrics, visualization)
- [x] README already includes Phase 10 in structure (completed in v0.4.4)

### Notes
- **Phase 10 Questions File** (~210 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase10_questions__t__.md`
  - Business analytics questions: User metrics (DAU/MAU), engagement, revenue, product metrics, analytics tools (Mixpanel, Amplitude, Google Analytics)
  - Application metrics questions: Request metrics, database metrics, cache metrics, business events, instrumentation (Prometheus, APM tools, OpenTelemetry)
  - Distributed tracing questions: Use cases (microservices, performance debugging), tools (Jaeger, Zipkin, Datadog, X-Ray), sampling strategy
  - Alerting strategy questions: Alert categories (P0-P3), alert rules, notification channels (PagerDuty, Slack, email), response times
  - Dashboard design questions: Dashboard types (service health, infrastructure, business), tools (Grafana, Datadog), key metrics, visualization best practices
- **Design decisions:**
  - 5 questions covering analytics and advanced observability
  - Optional phase (builds on basic monitoring from Phases 2 and 5)
  - Comprehensive coverage of business and technical metrics
  - Practical alerting strategy with severity levels
  - Focus on actionable dashboards and insights

## v0.4.6 LLM Q&A Phase 9 (Background Jobs) [Implemented]
Focus: Background job processing for production/secure Quality
- [x] Create `docs/guides/llm_qa/llm_qa_phase9_questions__t__.md`:
  - [x] Job queue questions (queue technology, message broker)
  - [x] Worker architecture questions (worker processes, scaling)
  - [x] Job scheduling questions (cron, recurring jobs)
  - [x] Retry logic questions (failure handling, exponential backoff)
  - [x] Job monitoring questions (job status, failed jobs, alerting)
- [x] README already includes Phase 9 in structure (completed in v0.4.4)

### Notes
- **Phase 9 Questions File** (~200 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase9_questions__t__.md`
  - Job queue questions: Redis+Celery, Redis+RQ, PostgreSQL+pg_boss, RabbitMQ, AWS SQS, Kafka - pros/cons/use cases
  - Worker architecture questions: Number of workers, concurrency, queue routing, scaling strategy, resource limits
  - Job scheduling questions: Cron jobs, recurring jobs, one-time delayed, scheduling tools (Celery Beat, APScheduler, cloud schedulers)
  - Retry logic questions: Max retries, exponential backoff, retry conditions, dead letter queue, idempotency
  - Job monitoring questions: Queue depth, job duration, success/failure rate, worker health, monitoring tools (Flower, Grafana, Datadog)
- **Design decisions:**
  - 5 questions covering all background job concerns
  - Optional phase (can skip for synchronous-only applications)
  - Comprehensive coverage of popular job queue technologies
  - Practical examples for worker configuration and monitoring
  - Focus on reliability and observability

## v0.4.5 LLM Q&A Phase 8 (API Design) [Implemented]
Focus: API design for production/secure Quality
- [x] Create `docs/guides/llm_qa/llm_qa_phase8_questions__t__.md`:
  - [x] API style questions (REST, GraphQL, gRPC)
  - [x] API versioning questions (versioning strategy, deprecation)
  - [x] API documentation questions (OpenAPI/Swagger, examples)
  - [x] Rate limiting questions (per-user, per-IP, burst limits)
  - [x] Webhooks questions (event notifications, retry logic)
- [x] README already includes Phase 8 in structure (completed in v0.4.4)

### Notes
- **Phase 8 Questions File** (~180 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase8_questions__t__.md`
  - API style questions: REST vs GraphQL vs gRPC, pros/cons, use cases
  - API versioning questions: URL path, header, query parameter strategies, deprecation policy
  - API documentation questions: OpenAPI/Swagger, Postman, Markdown, content requirements
  - Rate limiting questions: Per-user, per-IP, per-endpoint, tiered limits, burst handling
  - Webhooks questions: Events, payload, security (HMAC), retry logic, management
- **Design decisions:**
  - 5 questions covering all API design concerns
  - Optional phase (can skip for CLI-only or UI-only projects)
  - Comprehensive coverage of REST, GraphQL, and gRPC
  - Practical examples for each approach
  - Integration with rate limiting from Phase 4 (Security Basics)

## v0.4.4 LLM Q&A Phase Restructuring (Phases 2-7) [Implemented]
Focus: Split Phase 2 into focused phases and add feature-specific phases
- [x] Rename current Phase 2 file: `llm_qa_phase2_questions__t__.md` → `llm_qa_phase2-5_archive__t__.md`
- [x] Create `docs/guides/llm_qa/llm_qa_phase2_questions__t__.md` (Infrastructure):
  - [x] Hosting platform questions (6 questions)
  - [x] Regions/availability, scaling, monitoring, cost, IaC questions
- [x] Create `docs/guides/llm_qa/llm_qa_phase3_questions__t__.md` (Authentication & Authorization):
  - [x] Authentication method questions (OAuth, passwords, magic links, API keys)
  - [x] Session management questions (cookies, timeouts, security)
  - [x] MFA questions (basic implementation, not advanced secure-level)
  - [x] Authorization questions (RBAC, permissions, resource-level)
- [x] Create `docs/guides/llm_qa/llm_qa_phase4_questions__t__.md` (Security Basics):
  - [x] Secrets management questions (development, production)
  - [x] Data encryption questions (at rest, in transit, basic application-level)
  - [x] Input validation questions (SQL injection, XSS, CSRF prevention)
  - [x] Rate limiting questions (brute force prevention, API abuse)
  - [x] Basic security audit questions (dependency scanning, code scanning)
- [x] Create `docs/guides/llm_qa/llm_qa_phase5_questions__t__.md` (Operations):
  - [x] Deployment process questions (8 questions)
  - [x] Health checks, rollback, logging, incidents, backup, config, performance questions
- [x] Create `docs/guides/llm_qa/llm_qa_phase6_questions__t__.md` (Data & Persistence):
  - [x] Database design questions (schema, relationships, normalization)
  - [x] Data migration questions (migration strategy, rollback)
  - [x] Backup strategy questions (frequency, retention, testing)
  - [x] Caching strategy questions (cache layers, invalidation)
  - [x] Data modeling questions (entities, validation, constraints)
- [x] Create `docs/guides/llm_qa/llm_qa_phase7_questions__t__.md` (User Interface):
  - [x] Frontend framework questions (React, Vue, Svelte, vanilla)
  - [x] Component architecture questions (component library, design system)
  - [x] State management questions (Redux, Zustand, Context API)
  - [x] Accessibility questions (WCAG compliance, screen readers, keyboard navigation)
  - [x] Responsive design questions (mobile-first, breakpoints, testing)
  - [x] UI performance questions (lazy loading, code splitting, bundle size)
- [x] Rename current Phase 3 file: `llm_qa_phase3_questions__t__.md` → `llm_qa_phase11-16_archive__t__.md`
- [x] Update README with new phase structure (Phases 0-16)
- [x] Update planning guide with new phase alignment table

### Notes
- **Breaking change:** Phase numbering changes from 0-3 to 0-16
- **Migration path:** Old Phase 2 → New Phases 2-5, Old Phase 3 → New Phases 11-16
- **New phases created:**
  - Phase 2: Infrastructure (6 questions, ~200 lines)
  - Phase 3: Authentication & Authorization (6 questions, ~200 lines)
  - Phase 4: Security Basics (5 questions, ~180 lines)
  - Phase 5: Operations (8 questions, ~220 lines)
  - Phase 6: Data & Persistence (5 questions, ~180 lines)
  - Phase 7: User Interface (6 questions, ~200 lines)
- **Archived files:**
  - `llm_qa_phase2-5_archive__t__.md` (old Phase 2, 750 lines)
  - `llm_qa_phase11-16_archive__t__.md` (old Phase 3, 1000+ lines)
- **Token efficiency:** Each new phase ~6-10K tokens vs 23-30K for old Phase 2
- **Time per phase:** 10-25 minutes vs 30-60 minutes for old Phase 2
- **Quality mapping:**
  - experiment: Phases 0-1
  - prototype: Phases 0-1, 6-7 (as needed)
  - production: Phases 0-7 (core), 8-10 (as needed)
  - secure: Phases 0-16 (all)
- **README updated:** New phase structure with 4 categories (Foundation, Production Readiness, Feature-Specific, Secure/Compliance)
- **Planning guide updated:** Comprehensive phase alignment tables for all 17 phases

## v0.4.3 LLM Q&A Phase 3 (Secure/Compliance) [Implemented]
Focus: Add questions for secure/compliance requirements
- [x] Add Phase 3 question templates to `docs/guides/llm_qa/llm_qa_phase3_questions__t__.md`:
  - [x] Advanced security questions (threat modeling, MFA, encryption, vulnerabilities, pen testing, training)
  - [x] Compliance questions (GDPR, HIPAA, PCI DSS, SOC 2)
  - [x] Audit logging and incident response questions (formal procedures)
  - [x] Security governance questions (policies, risk assessment, vendor management, metrics)
- [x] Phase 3 sections already marked in `templates/v0.4/docs/specs/security_spec__t__.md` (completed in v0.4.2)
- [x] Add fourth example Q&A session (secure-level healthcare platform)

### Notes
- **Phase 3 Questions File** (1000+ lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase3_questions__t__.md`
  - Threat modeling questions (3): Threat identification, attack surfaces, mitigations
  - Compliance questions (5): Applicable regulations, GDPR, HIPAA, PCI DSS, SOC 2
  - Advanced security questions (7): MFA, encryption details, secrets rotation, vulnerability management, penetration testing, security training
  - Audit logging questions (2): Audit log requirements, retention policy
  - Incident response questions (4): IR team, incident classification, IR procedures, breach notification
  - Security governance questions (4): Security policies, risk assessment, third-party security, security metrics
  - Complete example Q&A session: Secure-level healthcare platform (HIPAA + GDPR compliant) with comprehensive dialogue
  - 24 total questions covering all secure Quality requirements
- **Phase 3 Tags**: Already added in v0.4.2 to `security_spec__t__.md` (9 major sections tagged)
- **Design decisions:**
  - 24 questions for Phase 3 (most comprehensive, only for secure Quality)
  - Compliance-focused: Covers GDPR, HIPAA, PCI DSS, SOC 2, CCPA, FERPA
  - Example shows real-world healthcare scenario with specific compliance requirements
  - Questions ensure formal security governance and incident response procedures
  - Only required for secure Quality level (experiment/prototype/production can skip)

## v0.4.2 LLM Q&A Phase 2 (Production Readiness) [Implemented]
Focus: Add questions for production-grade projects
- [x] Add Phase 2 question templates to `docs/guides/llm_qa/llm_qa_phase2_questions__t__.md`:
  - [x] Infrastructure questions (6 questions: hosting, regions, scaling, monitoring, cost, IaC)
  - [x] Security basics questions (6 questions: authentication, authorization, secrets, encryption, input validation, audits)
  - [x] Operations questions (8 questions: deployment, health checks, rollback, logging, incidents, backup, config, performance)
- [x] Add phase tags to remaining spec templates:
  - [x] `templates/v0.4/docs/specs/implementation_options_spec__t__.md` (11 sections tagged)
  - [x] `templates/v0.4/docs/specs/security_spec__t__.md` (9 major sections tagged Phase 2 vs Phase 3)
- [x] Add third example Q&A session (production-level web API)
- [x] Update `templates/v0.4/docs/guides/planning_guide__t__.md` to explain Q&A phase alignment with version phases

### Notes
- **Phase 2 Questions File** (750 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase2_questions__t__.md`
  - Infrastructure questions: Hosting platform, regions/availability, scaling strategy, monitoring/alerting, cost management, IaC
  - Security basics questions: Authentication (OAuth, passwords), authorization (RBAC), secrets management, data encryption, input validation, security audits
  - Operations questions: Deployment process, health checks, rollback strategy, logging, incident response, backup/recovery, configuration management, performance monitoring
  - Complete example Q&A session: Production-level web API (Fly.io + PostgreSQL + OAuth + monitoring) with full dialogue
  - 20 total questions covering all production readiness concerns
- **Phase Tags Added**:
  - `implementation_options_spec__t__.md`: Tagged 11 sections (Languages, Frameworks, Packaging, Data, Infrastructure, Auth, Observability, Protocols, Tooling)
  - `security_spec__t__.md`: Tagged 9 major sections distinguishing Phase 2 (basic production security) from Phase 3 (compliance/advanced)
  - Tags clarify when to fill each section: Phase 2 for production Quality, Phase 3 for secure Quality
- **Planning Guide Updated**:
  - Added "Q&A Phase Alignment with Version Phases" section with table showing Phase 0→v0.0.x, Phase 1→v0.1.x, Phase 2→production, Phase 3→secure
  - Workflow explanation showing progressive spec filling as project matures
  - Integration with existing planning workflow
- **Design decisions:**
  - 20 questions for Phase 2 (vs 13 for Phase 1, 10 for Phase 0) reflecting production complexity
  - Security split: Phase 2 covers basics (auth, secrets, encryption), Phase 3 covers compliance (GDPR, HIPAA, audits)
  - Example shows realistic production deployment with specific tools (Fly.io, Sentry, OAuth)
  - Questions map to multiple spec files (codebase, technical_design, security, implementation_options)

## v0.4.1 LLM Q&A Phase 1 (Core Technical) [Implemented]
Focus: Add questions for filling out core technical specs
- [x] Add Phase 1 question templates to `docs/guides/llm_qa/llm_qa_phase1_questions__t__.md`:
  - [x] Architecture questions (5 questions: system boundaries, components, data flow, dependencies, scalability)
  - [x] Technical stack questions (4 questions: libraries, database, API type, build tools)
  - [x] Development workflow questions (4 questions: testing, code quality, dependencies, CI/CD)
- [x] Add phase tags to spec templates:
  - [x] `templates/v0.4/docs/specs/technical_design_spec__t__.md` (mark Phase 0 vs Phase 1 vs Phase 2 sections)
  - [x] `templates/v0.4/docs/specs/codebase_spec__t__.md` (mark Phase 0 vs Phase 1 vs Phase 2 sections)
- [x] Add second example Q&A session (prototype-level web app)

### Notes
- **Phase 1 Questions File** (450 lines): `templates/v0.4/docs/guides/llm_qa/llm_qa_phase1_questions__t__.md`
  - Architecture questions: System boundaries, key components, data flow, external dependencies, scalability needs
  - Technical stack questions: Key libraries, database/storage, API/interface type, build/package tools
  - Development workflow questions: Testing approach, code quality tools, dependency management, CI/CD
  - Complete example Q&A session: Prototype-level web app (React + FastAPI + PostgreSQL) with full dialogue
  - Quality-aware questioning: Experiment skips most questions, prototype gets basics, production/secure get comprehensive coverage
- **Phase Tags Added**:
  - `technical_design_spec__t__.md`: Tagged 14 sections with Phase 0, Phase 1, or Phase 2 markers
  - `codebase_spec__t__.md`: Tagged 13 sections with Phase 0, Phase 1, or Phase 2 markers
  - Tags use HTML comments (invisible to users, visible to LLMs): `<!-- Phase X: Description -->`
  - Multi-phase sections noted: e.g., `<!-- Phase 1 (production/secure) | Phase 2 -->`
- **Design decisions:**
  - 13 total questions for Phase 1 (vs 10 in Phase 0), adjustable by Quality level
  - Questions map directly to spec sections for clear traceability
  - Example dialogue shows realistic back-and-forth with clarifications and confirmations
  - Phase tags enable LLMs to understand which sections to fill during each Q&A phase

## v0.4.0 LLM Q&A Foundation [Implemented]
We need to edit the metadocuments in `templates/v0.4/docs/` to make it easier for LLMs to ask questions about a new project. When a developer sets up a new git repo, they run `pyve --init` which copies the metadocuments (that have already been "installed" from `templates/v0.4/docs/` into their home directory) to `docs/` in their git repo, current directory. The foundation documents for working on a project are in `docs/guides/` and `docs/runbooks/` (as references) and then `docs/specs/` is a custom specification for the developer to get from zero to v1.0.

Focus: Create the core Q&A guide and establish the framework
- [x] Create `templates/v0.4/docs/guides/llm_qa_guide__t__.md` with:
  - [x] Q&A principles and workflow explanation
  - [x] Phase-based approach (Phase 0, 1, 2, 3) definition
  - [x] Quality-level intensity matrix
  - [x] Instructions for LLMs on conducting Q&A sessions
- [x] Create Phase 0 question templates (project basics only):
  - [x] Project overview questions (5-8 questions)
  - [x] Quality level selection questions
  - [x] Primary language/framework questions
- [x] Add one complete example Q&A session (experiment-level CLI tool)
- [x] Update `templates/v0.4/docs/guides/llm_onramp_guide__t__.md` to reference the Q&A guide

### Notes
- **LLM Q&A Guides** (refactored into subdirectory for token efficiency):
  - `templates/v0.4/docs/guides/llm_qa/README__t__.md` (150 lines) - Overview and reading flow
  - `templates/v0.4/docs/guides/llm_qa/llm_qa_principles__t__.md` (280 lines) - Q&A methodology
  - `templates/v0.4/docs/guides/llm_qa/llm_qa_phase0_questions__t__.md` (370 lines) - Phase 0 questions
  - Q&A principles: Progressive disclosure, quality-aware questioning, context/examples, confirmation, iteration support
  - Phase definitions: Phase 0 (project basics), Phase 1 (core technical), Phase 2 (production), Phase 3 (secure/compliance)
  - Quality-level intensity matrix: Question counts vary from 5 (experiment) to 80+ (secure compliance)
  - Instructions for LLMs: Starting sessions, conducting Q&A, filling specs, completing sessions
  - Phase 0 question templates: Quality level selection, project overview, language/framework, component structure, repository basics
  - Complete example Q&A session: Experiment-level CLI tool (merge-docs) with full dialogue
  - Special case handling: "I don't know yet", "use defaults", vague answers, scope creep, Quality upgrades
  - Integration guidance: Relationship to Planning, Building, and Onramp guides
  - Tips for effective Q&A: Do's and don'ts for LLM facilitators
- **Updated LLM Onramp Guide**: `templates/v0.4/docs/guides/llm_onramp_guide__t__.md`
  - Added "New Projects vs Existing Projects" section distinguishing Q&A workflow from direct implementation
  - Added llm_qa/ subdirectory as first item in reading order for new projects
  - Split minimal prompt into two versions: new projects (Q&A first) vs existing projects (direct implementation)
  - Updated references to point to new subdirectory structure
- **Design decisions:**
  - **Subdirectory structure for token efficiency:** Split monolithic guide (650+ lines) into focused files (150-370 lines each)
    - LLMs load only what they need: principles + current phase (~400-700 lines vs 1600-2000 for all phases)
    - Token savings: 60-70% reduction per Q&A session
  - Progressive disclosure over upfront information gathering (reduces user fatigue)
  - Quality-aware questioning intensity (experiment needs 5-10 questions, secure needs 40-80)
  - Phase-based approach aligns with existing version phase system (Phase 0 → v0.0.x, Phase 1 → v0.1.x, etc.)
  - Real-time spec filling (don't wait until end) for better feedback loop
  - Support for "I don't know yet" and "use defaults" to avoid blocking on uncertain decisions

## v0.3.13 Authentication & Authorization in Templates [Implemented]
Authentication & Authorization guide `docs/guides/web/web_auth_guide__t__.md`
- [x] General guide on authentication & authorization
- [x] Auth runbooks for each framework
- [x] Coverage in the foundation specs docs

### Notes
- **Main Auth Guide** (600+ lines): `docs/guides/web/web_auth_guide__t__.md`
  - Authentication strategies: Session-based, JWT tokens, OAuth 2.0, Passwordless
  - Authorization patterns: RBAC, Permission-based, Resource-level
  - Security best practices: Password security, MFA, Rate limiting, CSRF, Session security
  - Secrets management: Environment variables, AWS/GCP secret managers
  - Production considerations: HTTPS/TLS, Audit logging, GDPR compliance
  - Decision framework by use case and security requirements
  
- **Flask Auth Runbook** (550+ lines): `docs/runbooks/web/flask_auth_runbook__t__.md`
  - **Google OAuth setup** - Complete walkthrough from Google Cloud Console to production
  - Complete Flask app with Google OAuth, session management, RBAC
  - **HTMX security patterns** - CSRF protection, protected endpoints, authentication state
  - User management CRUD with authorization checks
  - Audit logging implementation
  - Production deployment guide
  - Testing examples
  - Security checklist
  
- **FastAPI Auth Runbook** (400+ lines): `docs/runbooks/web/fastapi_auth_runbook__t__.md`
  - JWT token authentication (access + refresh tokens)
  - OAuth2 with Google integration
  - Dependency injection for auth
  - Role-based access control
  - API key authentication
  - Rate limiting with slowapi
  - Complete CRUD example with permissions
  - Testing with TestClient
  
- **Reflex Auth Runbook** (350+ lines): `docs/runbooks/web/reflex_auth_runbook__t__.md`
  - Pure Python authentication
  - State-based auth management
  - Database integration with SQLAlchemy
  - Google OAuth for Reflex
  - Protected routes and role guards
  - Session persistence with browser storage
  - User management CRUD
  
- **Streamlit Auth Expansion** (500+ lines): Enhanced `docs/runbooks/web/streamlit_runbook__t__.md`
  - Simple password protection
  - Multi-user auth with streamlit-authenticator
  - Role-based access control
  - Google OAuth integration
  - Database-backed authentication
  - Secrets management with st.secrets
  - Session timeout implementation
  - Security best practices and password validation
  
- **Security Spec** (400+ lines): `docs/specs/security_spec__t__.md`
  - Authentication requirements (passwords, OAuth, sessions, MFA)
  - Authorization requirements (RBAC, permissions)
  - Data protection (encryption at rest/transit, data minimization)
  - Secrets management (development and production)
  - Input validation (SQL injection, XSS, CSRF prevention)
  - Rate limiting patterns
  - Monitoring and logging requirements
  - Incident response procedures
  - Compliance (GDPR, HIPAA, PCI DSS)
  - Security checklist by phase (dev, testing, staging, production)
  - Security headers configuration
  
**Total documentation: ~2,800 lines**

**Key focus:** Flask + HTMX + Google OAuth for CRUD applications (as requested)

## v0.3.12b Tweaks for Web UI [Implemented]
- [x] Add references for React, Vue, and Svelte

## v0.3.12 UI Design Patterns & Architecture in Templates [Implemented]
UI architecture guide `docs/guides/web/web_ui_architecture_guide__t__.md`
- [x] Architectural patterns (MVC, MVVM, MVP, Component-based)
- [x] State management patterns (local, global, reactive, immutable)
- [x] Common UI patterns (forms, navigation, data tables, modals, notifications, loading states, infinite scroll)
- [x] Design principles (separation of concerns, composition, single responsibility, DRY)
- [x] Best practices (accessibility, performance, responsive design, error handling, security)

### Notes
- **Architectural Patterns** (900+ lines total):
  - **MVC** - Traditional server-side pattern for Flask/FastAPI apps
  - **MVVM** - Reactive pattern for Streamlit, Reflex, Dash
  - **MVP** - Testing-focused pattern with passive views
  - **Component-based** - Modern composable architecture
- **State Management**:
  - **Local state** - Component-specific data
  - **Global state** - App-wide shared data
  - **Reactive state** - Auto-updating UI patterns
  - **Immutable state** - Predictable updates with frozen dataclasses
- **Common UI Patterns**:
  - Forms with validation and feedback
  - Navigation and routing
  - Data tables with pagination and sorting
  - Modals and dialogs
  - Notifications and toasts
  - Loading states and progress indicators
  - Infinite scroll with HTMX
- **Design Principles**:
  - Separation of concerns (data/business/presentation)
  - Composition over inheritance
  - Single responsibility per component
  - DRY (Don't Repeat Yourself)
- **Best Practices**:
  - **Accessibility** - Semantic HTML, ARIA labels, keyboard navigation, screen reader support
  - **Performance** - Lazy loading, caching, pagination, debouncing
  - **Responsive Design** - Mobile-first, breakpoints, flexible layouts
  - **Error Handling** - Try-catch with feedback, fallback UI, validation
  - **Security** - Input sanitization, CSRF protection, authentication, environment variables
- **Architecture Decision Framework** - When to use each pattern and state management approach
- **Resources** - Tools (Figma, DevTools, Lighthouse), learning materials, testing frameworks 

## v0.3.11b Doc Packages Enhancements [Implemented]
- [x] Add package metadata file `templates/v0.3/docs/.packages.json` with descriptions, file counts, and categories
- [x] Enhance `--list` to show package descriptions from metadata
- [x] Support bulk operations with space-separated packages: `pyve --add web persistence infrastructure`
- [x] Support bulk operations with space-separated packages: `pyve --remove web persistence`
- [x] Add `--init --packages <pkg1> <pkg2>` to initialize with specific packages
- [x] Update help text to reflect space-separated syntax

### Notes
- **Package metadata**: Created `.packages.json` with descriptions, categories, and file lists for each package
- **Metadata reading**: Uses Python 3 (fallback to jq) to parse JSON metadata
- **Enhanced --list**: Shows package descriptions and usage examples
  ```
  Available documentation packages:
  
    ✓ web
        Web UI frameworks and APIs - Streamlit, Gradio, Reflex, Marimo, Dash, Flask, FastAPI, Vue, Svelte
      persistence
        Databases and data storage - PostgreSQL, MySQL, MongoDB, Redis, data warehouses, cloud databases
  ```
- **Bulk add**: `pyve --add web persistence infrastructure` validates all packages first, then adds them
- **Bulk remove**: `pyve --remove web persistence` removes multiple packages at once
- **Init with packages**: `pyve --init --packages web persistence` initializes and installs packages in one command
- **Space-separated syntax**: Consistent Unix-style parameter handling throughout
- **Version**: Bumped to 0.3.11b

## v0.3.11 Doc Packages [Implemented]
We're getting way too much documentation in Pyve to blindly install/init all docs for every project. 
- [x] Change `pyve.sh` to only copy the foundation docs in the first level directories on `--init` or `--upgrade`
- [x] Add a config file to define which doc packages to include besides the foundation docs, which `--upgrade` will honor
- [x] Add an `--add` and `--remove` flag to `pyve.sh` to add or remove doc packages (by directory name) and in the config file
  - Example: `pyve.sh --add web` or `pyve.sh --remove web` adds or removes all the files in the `web` subdirectories under `docs/guides` and `docs/runbooks`
- [x] Add a `--list` flag to `pyve.sh` to list all available doc packages

### Notes
- **Foundation docs** (always copied on `--init`):
  - Top-level guides: `building_guide`, `planning_guide`, `testing_guide`, `dependencies_guide`, `llm_onramp_guide`
  - All specs: `docs/specs/*.md`
  - Language-specific: `docs/guides/lang/*` and `docs/specs/lang/*`
- **Doc packages** (opt-in via `--add`):
  - `web` - Web UI frameworks and APIs (Streamlit, Flask, FastAPI, Vue, etc.)
  - `persistence` - Databases and data storage (PostgreSQL, MongoDB, Redis, data warehouses)
  - `infrastructure` - Cloud platforms and deployment (AWS, GCP, Kubernetes, Fly.io)
  - `analytics` - BI tools (Looker, Metabase, Superset, Tableau)
  - `mobile` - Mobile development (placeholder for future)
- **Config file**: `.pyve/packages.conf` tracks selected packages
- **Commands**:
  - `pyve --list` - Show available and installed packages
  - `pyve --add <package>` - Add package and copy its files
  - `pyve --remove <package>` - Remove package and delete unmodified files
- **Upgrade behavior**: `--upgrade` now respects `.pyve/packages.conf` and only upgrades foundation + installed packages
- **Version**: Bumped to 0.3.11

## v0.3.10 Python-Friendly Web UI in Templates [Implemented]
- [x] General UI guide `docs/guides/ui_guide__t__.md`
  - [x] Decision framework by use case (prototype, dashboard, internal tool, customer-facing app)
  - [x] Python-native frameworks (Streamlit, Gradio, Reflex, Marimo, Dash, NiceGUI)
  - [x] Jupyter-based solutions (Marimo, Solara, Voila)
  - [x] Python web frameworks + templating (Flask, FastAPI, Django brief mention)
  - [x] HTMX pattern (server-driven interactivity with Python backends)
  - [x] When to use modern JS frameworks (Vue, Svelte)
  - [x] Styling approaches (Tailwind, Pico CSS, DaisyUI, component libraries)
  - [x] Design tools (Figma, Excalidraw, Balsamiq, Penpot)
  - [x] Common UI patterns (forms, auth flows, state management, routing)      d
- [x] UI runbooks `docs/runbooks/ui/`
  - [x] Streamlit runbook (components, state, deployment, authentication)
  - [x] Gradio runbook (interfaces, blocks, deployment, sharing)
  - [x] Reflex runbook (components, state management, events, deployment)
  - [x] Marimo runbook (reactive notebooks, UI elements, deployment)
  - [x] Dash runbook (callbacks, components, deployment)
  - [x] Flask + HTMX runbook (templates, HTMX patterns, deployment)
  - [x] FastAPI + Jinja2 runbook (templates, async patterns, deployment)
  - [x] Vue/Svelte runbook (brief, for when Python isn't enough)
- [x] Create README for UI runbooks directory

### Notes
- Created `ui_guide__t__.md` (850+ lines) covering:
  - Decision framework by use case (prototype → dashboard → internal tool → customer app)
  - Python-native frameworks: Streamlit (data apps), Gradio (ML demos), Reflex (full apps), Marimo (reactive notebooks), Dash (analytics), NiceGUI (simple tools)
  - Jupyter-based solutions: Marimo, Solara, Voila
  - Python web frameworks: Flask + Jinja2, FastAPI + Jinja2, Django (brief mention)
  - HTMX pattern for server-driven interactivity without heavy JS
  - Modern JS frameworks (Vue, Svelte) - when to reach for them
  - Styling approaches: Tailwind CSS, Pico CSS, DaisyUI, component libraries
  - Design tools: Figma, Excalidraw, Balsamiq, Penpot
  - Common UI patterns: forms, authentication, state management, routing, data tables, real-time updates
  - Deployment considerations for each framework type
- Created 8 UI runbooks (2,400+ lines total):
  - **Streamlit Runbook** (600+ lines): Components, state management, layouts, forms, caching, multi-page apps, authentication, deployment (Community Cloud, Docker)
  - **Gradio Runbook** (250+ lines): Interface API, Blocks API, ML model examples, sharing, deployment (Hugging Face Spaces)
  - **Reflex Runbook** (250+ lines): State management, components, forms, routing, deployment
  - **Marimo Runbook** (200+ lines): Reactive notebooks, UI elements, dataframes, deployment as app
  - **Dash Runbook** (250+ lines): Callbacks, components, multi-page apps, deployment
  - **Flask + HTMX Runbook** (400+ lines): HTMX integration, forms, delete with confirmation, search with debounce, infinite scroll, authentication, deployment (Gunicorn, Docker)
  - **FastAPI + Jinja2 Runbook** (350+ lines): Templates, forms, HTMX integration, API endpoints, authentication, WebSockets, background tasks, deployment (Uvicorn, Docker)
  - **Vue/Svelte Runbook** (300+ lines): Brief coverage for when Python isn't enough, basic components, integration with Python backends, state management, routing, deployment
- Created README (70+ lines) explaining runbook structure and quick selection guide
- Focus on Python-first solutions, minimal JavaScript complexity
- Practical, working examples throughout

## v0.3.9 Analytics & BI in Doc Templates [Implemented]
- [x] General guidelines for analytics `docs/guides/analytics_guide__t__.md`
  - [x] Choosing BI tools (self-hosted vs cloud, open-source vs commercial)
  - [x] Architecture patterns (embedded analytics, self-service, centralized)
  - [x] Data modeling for analytics (metrics, dimensions, semantic layers)
  - [x] Performance considerations (caching, pre-aggregation, query optimization)
- [x] Analytics runbooks `docs/runbooks/analytics/`
  - [x] Looker runbook (LookML, explores, dashboards, deployment)
  - [x] Metabase runbook (setup, questions, dashboards, embedding)
  - [x] Superset runbook (installation, charts, dashboards, SQL Lab)
  - [x] Tableau runbook (workbooks, data sources, publishing)
- [x] Create README for analytics runbooks directory

### Notes
- Created `analytics_guide__t__.md` (650+ lines) covering:
  - BI tool selection criteria (team size, technical expertise, use case, budget)
  - Decision matrix comparing self-hosted open-source, cloud open-source, and commercial cloud options
  - Architecture patterns: Centralized, self-service, embedded, hybrid (data mesh)
  - Semantic layer concepts (metrics, dimensions, LookML examples)
  - Data modeling for analytics (star schema, metrics vs dimensions)
  - Performance optimization (caching strategies, pre-aggregation, query optimization)
  - Embedding analytics (iframe, JavaScript SDK, API-based, multi-tenancy)
  - Self-service enablement (data catalog, training, governance)
  - Security & governance (access control, RLS, audit logging)
  - Cost optimization strategies
- Created 4 comprehensive analytics runbooks (2,850+ lines total):
  - **Looker Runbook** (700+ lines): LookML syntax, models/views/explores, PDTs, embedding (signed URLs, SSO), user management, RLS, performance optimization, administration
  - **Metabase Runbook** (550+ lines): Docker/JAR installation, visual query builder, SQL queries, dashboards, embedding (public sharing, signed embedding), user management, sandboxing, caching, administration
  - **Superset Runbook** (650+ lines): Docker/Kubernetes/pip installation, SQL Lab, 40+ chart types, native filters, cross-filtering, semantic layer, embedding (guest tokens), RLS, async queries, Celery configuration
  - **Tableau Runbook** (650+ lines): Desktop/Server/Cloud setup, data sources, calculated fields, parameters, dashboards, publishing, embedding (JavaScript API, trusted auth), RLS, extracts, TSM administration
- Created README (50+ lines) explaining runbook structure and tool selection guidance
- Complements existing persistence documentation with analytics/visualization layer
- Provides clear separation: persistence (data storage) → analytics (data presentation)

## v0.3.8c Data Warehouse Runbook [Implemented]
- [x] Create data warehouse runbook covering OLAP databases
- [x] ClickHouse operations (table engines, partitioning, materialized views, distributed tables)
- [x] BigQuery operations (partitioning, clustering, cost optimization, scheduled queries)
- [x] Redshift operations (distribution styles, sort keys, VACUUM/ANALYZE, Spectrum)
- [x] Snowflake operations (virtual warehouses, time travel, cloning, Snowpipe)

### Notes
- Created `data_warehouse_runbook__t__.md` (650+ lines) covering:
  - **ClickHouse**: Installation, table engines (MergeTree, ReplacingMergeTree, Distributed), data loading, materialized views, query optimization, monitoring
  - **BigQuery**: Dataset/table creation, partitioning, clustering, query optimization, cost optimization, scheduled queries
  - **Redshift**: Cluster creation, distribution styles (KEY, ALL, EVEN), sort keys (compound, interleaved), COPY from S3, VACUUM/ANALYZE, Redshift Spectrum
  - **Snowflake**: Database/warehouse creation, clustering, external tables, data loading, Snowpipe, time travel, zero-copy cloning, cost optimization
  - Common patterns: ETL/ELT, incremental loads, data modeling (star schema)
- Complements existing OLTP database runbooks with OLAP-specific operations
- Updated persistence runbooks README to include data warehouse category

## v0.3.8b Generalize/Split Persistence Ops [Implemented]
- [x] Generalize the persistence operations guide
- [x] Split the platform/product-specific details into runbooks

### Notes
- Refactored `persistence_operations_guide__t__.md` from 913 lines to 848 lines (7% reduction)
- Removed all platform-specific commands and configurations
- Replaced with general concepts, strategies, and references to runbooks
- Created 5 comprehensive persistence runbooks (4,822 lines total):
  - **PostgreSQL Runbook** (987 lines): Installation, backup/recovery, replication, performance tuning, monitoring, troubleshooting, security, upgrades
  - **MySQL Runbook** (1,053 lines): Installation, backup/recovery (mysqldump, XtraBackup, binary logs), replication, performance tuning, monitoring, troubleshooting, security, upgrades
  - **MongoDB Runbook** (922 lines): Installation, backup/recovery (mongodump, oplog, snapshots), replica sets, sharding, performance tuning, monitoring, troubleshooting, security, upgrades
  - **Redis Runbook** (969 lines): Installation, backup/recovery (RDB, AOF), replication, Sentinel, clustering, performance tuning, monitoring, troubleshooting, security, upgrades
  - **Cloud Databases Runbook** (891 lines): AWS (RDS, Aurora, DynamoDB, ElastiCache), GCP (Cloud SQL, Spanner, Firestore, Memorystore), Azure (Azure Database, Cosmos DB, Azure Cache)
- Created README (56 lines) explaining runbook structure and usage
- Benefits of separation:
  - **Operations guide:** General strategies, concepts, decision-making (what and when)
  - **Runbooks:** Platform-specific commands, configurations, procedures (how to implement)
  - **Easier maintenance:** Update platform-specific details without changing general guide
  - **Better discoverability:** Users can jump directly to their platform's runbook
  - **Reduced cognitive load:** Focused documentation for specific use cases

## v0.3.8 Persistence in Templates [Implemented]
- [x] General guidelines for persistence `docs/guides/persistence_guide__t__.md`
  - [x] Coverage of architectures: OLTP, OLAP, NoSQL, caching, object storage, time-series, search, message queues
  - [x] Decision framework for choosing storage technologies
  - [x] Data modeling and schema design (normalization, indexing, migrations)
- [x] Production operations for persistence `docs/guides/persistence_operations_guide__t__.md`
  - [x] Backup/recovery strategies (RTO/RPO, tools, testing)
  - [x] Data migration (big bang, phased, parallel run, strangler pattern)
  - [x] Performance optimization (query tuning, database config, caching, sharding/partitioning)
  - [x] Scalability strategies (vertical/horizontal scaling, auto-scaling)
  - [x] High availability (replication, failover, multi-region)
  - [x] Security & governance (encryption, access control, audit logging, compliance)
  - [x] Data lifecycle management (storage tiers, lifecycle policies, deletion strategies)
  - [x] Cost management (optimization, pricing models)
- [x] Move infrastructure runbooks to make room for other runbooks

### Notes
- Created `templates/v0.3/docs/guides/persistence_guide__t__.md` (500+ lines) covering:
  - Decision matrix for choosing storage technologies (8 factors: data structure, access patterns, consistency, scale, query complexity, latency, durability, cost)
  - Common architecture patterns (web app, analytics, real-time/event-driven, microservices)
  - Data storage patterns:
    - Relational databases (PostgreSQL, MySQL, SQLite, CockroachDB)
    - NoSQL: Key-value stores (Redis, Memcached, DynamoDB), Document stores (MongoDB, Firestore), Graph databases (Neo4j, Neptune), Wide-column stores (Cassandra, ScyllaDB)
    - Caching (Redis, Memcached, Varnish, CDN) with strategies (cache-aside, write-through, write-behind, refresh-ahead)
    - Object storage (S3, GCS, Azure Blob, MinIO, Tigris)
    - Data warehouses & lakes (BigQuery, Snowflake, Redshift, Databricks, ClickHouse)
    - Time-series databases (Prometheus, InfluxDB, TimescaleDB)
    - Search engines (Elasticsearch, Meilisearch, Typesense, Algolia)
    - Message queues & event streams (Kafka, RabbitMQ, SQS, Redis Streams, Pulsar)
  - Data modeling & schema design:
    - Relational design (normalization, indexing strategies, data types, constraints)
    - NoSQL patterns (embed vs reference, key design, data structures)
    - Schema versioning & migrations (expand-contract, dual writes, tools: Flyway, Liquibase, Alembic)
- Created `templates/v0.3/docs/guides/persistence_operations_guide__t__.md` (900+ lines) covering:
  - Backup & recovery:
    - Backup types (full, incremental, differential, continuous) with frequency and retention policies
    - Tools for relational (PostgreSQL, MySQL, RDS), NoSQL (MongoDB, Redis, Cassandra), object storage (S3)
    - Recovery procedures (RTO/RPO tiers, recovery steps, testing backups)
  - Data migration:
    - Strategies (big bang, phased, parallel run, strangler pattern) with pros/cons
    - Tools (AWS DMS, GCP Database Migration Service, Flyway, Liquibase, dbt)
    - Best practices (pre/during/post-migration)
  - Performance optimization:
    - Query optimization (identifying slow queries, EXPLAIN analysis, indexing, query rewriting)
    - Database tuning (PostgreSQL/MySQL configuration, connection pooling with PgBouncer/ProxySQL)
    - Caching strategies (application-level with Redis, database-level with materialized views)
    - Sharding & partitioning (range/hash partitioning, application-level sharding)
  - Scalability strategies:
    - Vertical scaling (scale up) vs horizontal scaling (scale out)
    - Read replicas (setup, routing, replication lag considerations)
    - Auto-scaling (managed services, self-managed monitoring)
  - High availability:
    - Replication (synchronous vs asynchronous, configuration)
    - Failover (automatic tools: Patroni, MHA; failover process; split-brain prevention)
    - Multi-region deployments (active-passive, active-active, read replicas)
  - Security & governance:
    - Encryption (at rest: TDE, column-level, application-level; in transit: SSL/TLS, VPN)
    - Access control (authentication methods, RBAC, row-level security)
    - Audit logging (what to log, tools: pgaudit, managed services)
    - Compliance (GDPR, HIPAA, PCI DSS, SOC 2)
  - Data lifecycle management:
    - Storage tiers (hot, warm, cold, glacier/archive)
    - Lifecycle policies (automatic transitions, S3 lifecycle, database partitioning)
    - Data deletion (soft delete, hard delete, anonymization)
  - Cost management:
    - Optimization strategies (right-sizing, reserved capacity, storage optimization, query optimization)
    - Pricing models (instance-based, serverless, storage+compute)
    - Cost comparison (managed vs self-managed vs serverless)
- Separation of concerns (Option B):
  - `persistence_guide.md`: Patterns, architectures, decision-making, data modeling (what and when)
  - `persistence_operations_guide.md`: Production operations, procedures, commands (how to operate)
  - Designed to avoid token limit issues for LLMs while maintaining comprehensive coverage
  - Cross-references between guides for easy navigation

## v0.3.7 Infrastructure in Templates [Implemented]
- [x] Add infrastructure templates to the Pyve repo
- [x] Add mentions of Podman, Alpine Linux, `ash` shell
- [x] Add operational runbooks for major platforms

### Notes
- Created comprehensive `templates/v0.3/docs/guides/infrastructure_guide__t__.md` (400+ lines) covering:
  - Infrastructure as Code (IaC): principles, tool selection, directory structure, state management
  - Configuration Management: 12-factor app principles, env vars, platform-specific config
  - Secrets Management: principles, strategies (platform stores, external managers), rotation
  - Deployment Strategies: rolling, blue-green, canary, feature flags, health checks, rollback
  - Scaling: horizontal/vertical scaling, auto-scaling configuration, platform-specific guidance
  - Monitoring & Observability: logs, metrics, traces, alerting best practices
  - Cost Management: optimization strategies, tracking, budgets
  - Disaster Recovery: backup strategy, RTO/RPO, high availability patterns
  - Security: network security, access control, compliance
  - Platform-Specific Guidance: when to use Fly.io, AWS, GCP, Azure, Heroku, Kubernetes
  - Runbooks: structure for vendor-specific operational procedures
  - Infrastructure Readiness Checklist
- Enhanced `templates/v0.3/docs/specs/implementation_options_spec__t__.md`:
  - Expanded "Infrastructure & Hosting" section with detailed considerations (deployment, configuration, secrets, scaling, monitoring, cost, governance, operations, developer experience)
  - Expanded "Packaging & Distribution" section with container runtime comparison (Docker vs Podman), base image options (Alpine Linux vs Ubuntu/Debian), and deployment considerations
- Enhanced `templates/v0.3/docs/specs/technical_design_spec__t__.md`:
  - Added IaC, platform-specific config (Dockerfile/Containerfile, docker-compose.yml/podman-compose.yml), and environment parity to Configuration section
  - Added deployment mechanism, health checks, monitoring during rollout, and zero-downtime strategies to Rollout & Migration section
- Enhanced `templates/v0.3/docs/specs/codebase_spec__t__.md`:
  - Added Docker/Podman clarification to Build & Packaging section
  - Added new "Infrastructure (if deployed)" section with provider, regions, IaC, platform config, container runtime (Docker vs Podman), base images (Alpine Linux with `ash` shell), secrets, scaling, monitoring, cost tracking, disaster recovery, and access control
- Updated `templates/v0.3/docs/guides/llm_onramp_guide__t__.md`:
  - Added infrastructure_guide.md to reading order (position #7)
  - Updated minimal prompt to include infrastructure guide
- Podman mentions throughout:
  - Consistently referenced as "Podman (free and open alternative)" or "Podman (a free and open alternative)"
  - Noted as daemonless and rootless in implementation_options_spec
  - Containerfile mentioned alongside Dockerfile
  - podman-compose.yml mentioned alongside docker-compose.yml
- Alpine Linux and `ash` shell mentions:
  - Specifically called out as minimal base image option
  - Noted in codebase_spec Infrastructure section: "Alpine Linux (minimal, uses `ash` shell)"
  - Included in implementation_options_spec considerations for container size optimization
- Created operational runbooks in `templates/v0.3/docs/runbooks/`:
  - `README__t__.md`: Overview, best practices, runbook structure, integration with other docs, quick reference commands
  - `fly_io_runbook__t__.md`: Complete operational procedures for Fly.io (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - `aws_runbook__t__.md`: Complete operational procedures for AWS ECS/Fargate (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - `gcp_runbook__t__.md`: Complete operational procedures for GCP Cloud Run/GKE (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - `kubernetes_runbook__t__.md`: Complete operational procedures for Kubernetes (setup, deploy, scale, monitor, debug, rollback, secrets, backup, destroy, cost optimization)
  - Each runbook includes platform-specific commands, configuration examples, troubleshooting guides, and cost optimization tips
  - Runbooks complement infrastructure_guide.md by providing concrete, executable procedures vs general patterns

## v0.3.6 Template Upgrade [Implemented]
Change `pyve.sh` to upgrade the local git repository from the user's home directory on `--upgrade` flag (similar to `--init`)
- [x] Read the `{old_version}` (e.g., `v0.3.0`) from the local git repo `./.pyve/version` file
- [x] Check if there is a newer version (e.g., `v0.3.1`) in `~/.pyve/templates/` directory. If so:
  - [x] Compare and conditionally copy any files that would normally be copied by `--init`, but don't fail if any files are not identical.
    - [x] Identical to older version: copy the new file and overwrite the old file
    - [x] Not identical to older version: copy the new file and suffix it with `__t__{newer_version}` and warn the user that the newer version was not applied for that file.
- [x] Track whether the upgrade process completed 
  - [x] Use some status file and write the arguments that were passed to `pyve.sh` script.
  - [x] The status file should be named `./.pyve/status/upgrade`
  - [x] At the beginning of the upgrade operation, if any file is already present in the `./.pyve/status` directory, something might be broken, so fail...don't make it worse.
- [x] Change the version in `./.pyve/version` file to the new version.

### Notes
- Perform guarded copy/compare; never overwrite non-identical files silently.
- Use `./.pyve/status/upgrade` to ensure idempotency and to fail fast if a previous run left state.
- Implemented `upgrade_templates()` function that reads the current project version and compares with available templates.
- Uses `upgrade_status_fail_if_any_present()` to enforce status cleanliness before starting.
- For each template file:
  - If the local file is identical to the old template version, it overwrites with the new version.
  - If the local file has been modified, it creates a new file with suffix `__t__{newer_version}` and warns the user.
  - If the file doesn't exist locally, it adds it.
- Updates `./.pyve/version` file to the new version after successful upgrade.
- Writes status to `./.pyve/status/upgrade` with timestamp and arguments.
- Provides clear summary of upgraded/added files and skipped modified files.

## v0.3.5 Template Update [Implemented]
Change `pyve.sh` to perform an update from of Pyve repo template documents into the user's home directory on `--update` flag (similar to `--install`).
- [x] Read the source path from `~/.pyve/source_path` file
- [x] Check if there is a newer version in Pyve `{source_path}/templates/` than is in the home directory `~/.pyve/templates/` directory. If so, copy the newer version to `~/.pyve/templates/{newer_version}`, which could have multiple versions.
- [x] Change the version in `./.pyve/version` file to the new version.

### Notes
- Keep `~/.pyve/templates/{version}` immutable once written; add newer versions side-by-side.
- Reuse install-time copy logic; do not mutate `source_path` here.
- Implemented `update_templates()` function that reads source path, compares versions, and copies newer templates.
- Version comparison uses string comparison which works for v0.X format.
- Templates are kept immutable; if a version already exists in `~/.pyve/templates/`, it won't be overwritten.
- Updates `~/.pyve/version` file to track the pyve version that performed the update.

## v0.3.4 Documentation Revision [Implemented]
With all the new documentation templates, I updated Pyve's documents to be in line with its templates. 
- [x] Added missing docs (`implementation_options_spec.md`, `python_guide.md`)
- [x] Filled in Pyve-specific details in other docs
- [x] Updated README

## v0.3.3 Template Purge [Implemented]
Change `pyve.sh` to remove the special Pyve documents in local git repo on --purge flag
- [x] Obtain the version from the local git repo `./.pyve/version` file
- [x] Remove only documents that are identical to the files in `~/.pyve/templates/{version}/*`
- [x] Warn with file names not identical, but don't remove those. 
- [x] Track whether the purge process completed 
  - [x] Use some status file and write the arguments that were passed to `pyve.sh` script.
  - [x] The status file should be named `./.pyve/status/purge`
  - [x] At the beginning of the purge operation, if any file is already present in the `./.pyve/status` directory, something might be broken, so fail...don't make it worse.

### Notes
- Only delete files that are byte-for-byte identical to the corresponding template for the recorded version.
- Use `./.pyve/status/purge` to track and guard runs; never remove modified files.
- Init message ordering: the `direnv allow` reminder is printed last in `--init` for visibility.
- Template copy noise suppression during `--init`:
  - Disables shell tracing within copy routine.
  - Avoids subshell/process substitution in loops.
  - Redirects detailed copy logs to `./.pyve/status/init_copy.log`.
- Idempotent re-init behavior:
  - If `./.pyve/status/init` exists (and only benign files like `init_copy.log`/`.DS_Store`), template copy is skipped with a clear message.
  - Unexpected extra files under `./.pyve/status/` still trigger a safe abort.
- Robust install handoff logic:
  - Outside the source repo, `--install` hands off to the recorded source path (`~/.pyve/source_path`).
  - Inside the source repo but invoked via the installed binary, `--install` hands off to local `./pyve.sh` to ensure the latest source and `VERSION` are used.
- Install identical-target handling: if `~/.local/bin/pyve.sh` is identical, skip copying without error but ensure the executable bit and symlink are correct.

## v0.3.2a Bugfixes [Implemented]
- [x] Several rounds of fixes and tests to remove noisy template copying, skip gracefully on re-init. `--install` and `--init` tested. `--init` fresh and re-installs work correctly. 

## v0.3.2 Template Initialization [Implemented]
Change `pyve.sh` so the initialization process copies the latest version of certain templates from the user's `~/.pyve/templates/{version}/*` directory into the user's local git repo (current user directory, invoked at the root of a codebase project) when the `--init` flag is used.  
- [x] Check first to see if any files in the local git repo would be overwritten by the template files and are not identical to the template files. If so, fail the init process with a message.
- [x] Record the now current version of the Pyve command in a version config file in the local git repo: (e.g., `~/pyve.sh --version > ./.pyve/version`)
- [x] Track whether the init process completed 
  - [x] Use some status file and write the arguments that were passed to `pyve.sh` script.
  - [x] The status file should be named `./.pyve/status/init`
  - [x] At the beginning of the init operation, if any file is already present in the `./.pyve/status` directory, something might be broken, so fail...don't make it worse.
- [x] When copying template files (all of which have a suffix `__t__*.md`, where `*` is any characters or no characters), copy files to the local git repo with the suffix removed, but retain the file extension. (e.g., `my_template__t__1234abc.md` -> `my_template.md`)
- [x] Root Docs: `~/.pyve/templates/{version}/*` to `.`
- [x] Guides: `~/.pyve/templates/{version}/docs/guides/*` to `./docs/guides/`
- [x] Specs: `~/.pyve/templates/{version}/docs/specs/*` to `./docs/specs/`
- [x] Languages: `~/.pyve/templates/{version}/docs/specs/lang/{lang}_spec.md` to `./docs/specs/lang/` (depending on which languages are initialized with asdf) 
- [x] Change the version in `./.pyve/version` file to the new version.

### Notes
- Preflight: if any target file would be overwritten and is not identical, abort with a clear message.
- Record run state in `./.pyve/status/init` and the active template version in `./.pyve/version`.

## v0.3.1 Template Installation [Implemented]
- [x] Change `pyve.sh` so that on the `--install` flag (which must be run from the git repo root of the Pyve codebase), it records the current path (`pwd`) in a new `~/.pyve/source_path` file. 
- [x] Change `pyve.sh` so that if the `~/.pyve/source_path` file already exists, handoff control (`{source_path}/pyve.sh --install`) so the newer version can replace the existing `~/.local/bin/pyve.sh`.
- [x] Change `pyve.sh` to install the latest version of templates from this codebase directory structure `templates` directory in the user's home directory (e.g., `~/.pyve/templates/`) when the `--install` flag is used. So if `v0.3` is the latest version, it will copy the template files as-is from `./templates/v0.3` into `~/.pyve/templates/v0.3/`.
- [x] Change `pyve.sh` to remove the `~/.pyve` directory when the `--uninstall` flag is used.

### Notes
- Record `pwd` to `~/.pyve/source_path` on `--install`.
- Copy current latest templates to `~/.pyve/templates/{latest}` on `--install`.
- `--uninstall` should remove `~/.pyve` cleanly.

## v0.3.0 Template Generalization [Implemented]
This is a complex change, so please ask questions if there are any ambiguities. 
The `templates` directory contains versioned meta documents that Pyve will use when developers need to initialize or upgrade documentation stubs in a local git repository. It will help them create a consistent codebase structure with ideal, industry standard documentation and instructions. And an LLM can help support those standards and policies. Currently, the `templates` directory contains the `v0.3` directory, which will be a release of Pyve documentation templates accompanying any v0.3.x of Pyve. 
- [x] Let's first make sure all the templates in `./templates/v0.3` are generic:
  - [x] No Python-specific language details (unless it's just an example, and except of course `/templates/v0.3/docs/specs/lang/python_spec.md`)
  - [x] No project-specific details. (e.g., anything about "Pyve" or "Data Merge")
  - [x] Do not change the anchors or references. Since when Pyve copies the files to another location, they will have the correct anchors and references in an initialized project.
- [x] Add a quality model to give context to the codebase spec and the technical design spec
- [x] Add an implementation options spec to bridge the gap between the codebase spec and the technical design spec
- [x] Add an LLM on-ramp guide to give an LLM a single point of entry to the codebase. 

### Notes
- `templates/v0.3/` inventory confirmed (e.g., `README__t__.md`, `CONTRIBUTING__t__.md`, `docs/guides/*_guide__t__.md`, `docs/specs/*__t__.md`).
- Allowed mention retained: `templates/v0.3/CONTRIBUTING__t__.md` includes “Consider using Pyve…”.
- Completed genericization work:
  - `templates/v0.3/docs/specs/technical_design_spec__t__.md`: replaced project-specific content with a neutral technical design template (structure preserved).
  - `templates/v0.3/docs/guides/dependencies_guide__t__.md`: rewritten to be language-agnostic and to reference `docs/guides/lang/`.
  - `templates/v0.3/docs/guides/lang/python_guide__t__.md`: created; moved Python dependency/version guidance here.
  - `templates/v0.3/docs/specs/codebase_spec__t__.md`: neutralized repository name/summary and genericized paths/entrypoints examples.
  - `templates/v0.3/README__t__.md`: rewritten to a framework‑neutral README template; includes a recommendation to consider using Pyve for Python environment setup.
  - Quality model: added `## Quality` section with level selector and entry/exit gates to `templates/v0.3/docs/specs/technical_design_spec__t__.md` (after `## Architecture`) and to `templates/v0.3/docs/specs/codebase_spec__t__.md` (after `## Repository`).
  - Implementation options: added `templates/v0.3/docs/specs/implementation_options_spec__t__.md` to bridge between high-level design and detailed codebase spec.
  - LLM on‑ramp: added `templates/v0.3/docs/guides/llm_onramp_guide__t__.md` and cross‑linked from `templates/v0.3/README__t__.md` (Getting Started, Development).
- Remaining to genericize in v0.3.0:
- Constraints:
  - Preserve all anchors and relative links; only change copy to be generic and relocate language-specific docs under `docs/guides/lang/`.
- Decision references: none yet.

## v0.2.8 Documentation Templates [Implemented]
Note that the directory structure in `docs` directory has changed,
- [x] Re-read all those `doc` directory documents and root documents (README.md, CONTRIBUTING.md)
- [x] Update any anchors, links, and references to reflect the new structure and doc names. 

### Notes
- Updated references in specs and guides to use `docs/guides/*_guide.md` and `docs/specs/*_spec.md` paths.
- Fixed links to versions spec, decisions spec, and technical design spec where applicable.

## v0.2.7 Tweak doc directories [Implemented]
- [x] Move Guides to `docs/guides/`(typically read only files)
- [x] Move Specs to `docs/specs/` (edited as the codebase evolves)
- [x] Suffix the filenames with `_guide` or `_spec` for easy identification of the purpose and use of the file.

### Notes
- Implemented manually

## v0.2.6 Codebase Specification [Implemented]
Provide a generic way to specify any codebase's structure and dependencies in a language-neutral way. This will help Pyve to generate the appropriate files for any codebase.
- [x] Implement `docs/specs/codebase_spec.md` (general doc)
- [x] Implement `docs/specs/lang/<lang>.md` (language-specific docs) for Python and Shell
- [x] Update the format of this file. 

### Notes
- Implemented manually

## v0.2.5 Requirements [Implemented]
Add an --install flag to the pyve.sh script that will... 
- [x] create a $HOME/.local/bin directory (if not already created)
- [x] add $HOME/.local/bin to the PATH (if not already in the PATH)
- [x] copy pyve.sh from the current directory to $HOME/.local/bin
- [x] make pyve.sh executable ($HOME/.local/bin/pyve.sh)
- [x] update the README.md to include the --install flag
- [x] create a symlink from $HOME/.local/bin/pyve to $HOME/.local/bin/pyve.sh
- [x] update the README.md to mention the easy usage of the pyve symlink (without the .sh extension)

### Notes
- Implemented `--install` with idempotent operations:
  - Created `$HOME/.local/bin` when missing.
  - Ensured `$HOME/.local/bin` is on PATH by appending an export line to `~/.zprofile` if needed, and sourcing it in the current shell for immediate availability.
  - Copied the running script to `$HOME/.local/bin/pyve.sh` and set executable bit.
  - Created/updated symlink `$HOME/.local/bin/pyve` -> `$HOME/.local/bin/pyve.sh`.
- Nuances:
  - PATH persistence is applied via `~/.zprofile` (Z shell on macOS). If users rely on different startup files, they may need to adjust accordingly.
  - Script path resolution uses `$0` with a fallback to `readlink -f` (or `greadlink -f` if available). If invoked in a way where `$0` is not a file path, the installer will prompt with an ERROR.
  - README updated to document `--install` and examples using the `pyve` symlink.
  - Added a complementary `--uninstall` command that removes `$HOME/.local/bin/pyve` and `$HOME/.local/bin/pyve.sh` without modifying PATH automatically.

## v0.2.4 Requirements [Implemented]
- [x] Change --pythonversion to --python-version
- [x] Remove the -pv parameter abbreviation since it is a non-standard abbreviation
- [x] Change default Python version 3.11.11 to 3.13.7
- [x] If the prescribed --python-version is not installed (by asdf or pyenv), check to see if it is available to install. If so, install it in asdf or pyenv and try again. If not, exit with an error message.
- [x] Add support for setting the --python-version without the --init flag. This will set the Python version in the current directory without creating a virtual environment.

### Notes
- Implemented the requirements for 0.2.4 as follows:
  - Switched to `--python-version` (removed `-pv`) across comments, help, and argument parsing.
  - Added standalone `--python-version <ver>` command to set only the local Python version (no venv/direnv changes).
  - Introduced helpers to detect version manager and auto-install the requested Python version if available (asdf: `asdf install python <ver>`, pyenv: `pyenv install -s <ver>`), preserving the existing asdf shims PATH check.
  - Updated usage text to show the new forms.
  - Bumped `VERSION` to `0.2.4` and `DEFAULT_PYTHON_VERSION` to `3.13.7`.
  - Kept ERROR message style (`ERROR:`) consistent with current codebase.
  - Maintained the requirement for `direnv` in the `--init` flow; not required for standalone `--python-version`.
  - Updated `README.md` examples and version references to reflect these changes.
  - Refactored `init_ready()` into helper functions (`source_shell_profiles`, `check_homebrew_warning`, `detect_version_manager`, `ensure_python_version_installed`, `check_direnv_installed`) to improve readability.

## v0.2.3 [Implemented]
- [x] Initial documented release
