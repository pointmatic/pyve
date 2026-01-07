# Guide for Versions Spec
(See ./docs/specs/versions_spec.md)

This document explains how the human, the LLM, and the development environment interact to implement versions.

## File Structure

```
<Header>
<Version_Plan>
<List_of_Versions>
```

### <Header> Format
```
# Pyve Version History
See `docs/guide_versions_spec.md`

```

### <Version_Plan> Format
If there is a clear big‑picture plan/technical design, list the important implementation components, features, dependencies, documentation, testing, etc. 

```
---

## High-Level Feature Checklist

### <Description_of_Feature_Set>

**<Aspect>:**
- [ ] <Element>
- [ ] <Element>

**<Aspect>:**
- [ ] <Element>
- [ ] <element>

```

### <List_of_Versions> Format
The version spec file is a markdown file with a specific structure. 

```
<Version>
<Version>
```

### <Version> Format

```
---

## <Version_Number>: <Title_of_Requirements> [Planned]
- [ ] <Requirement>
- [ ] <Requirement>
- [ ] <Requirement>

### Notes
* <Note>
* <Note>

```

## Roles
- **Human or LLM**
  - Add a new version at the top of the <List_of_Versions> section in `docs/specs/versions_spec.md`
  - Each <Version> is placed in reverse numerical order in the file (newest first).
  - Add a checklist of requirements under the version heading.
- **Human**
  - Trigger implementation (informally is fine). For new sessions, prefer: “Please implement v#.#.# in the @versions_spec.md file”.
  - Implement only the listed requirements for the targeted version.
  - Tick completed items `[x]`. If all are complete, append `[Implemented]` to the version title.
  - Use `### Notes` in the current version only to explain details, clarifications, partial work, or known issues. If correcting past guidance, reference the affected version (do not edit old versions).
  - Record major architectural/process/tooling decisions in `docs/specs/decisions_spec.md` (include date, context, decision, consequences) in reverse chronological order, newest at the top of the file. Link the entry in the current version's `### Notes` when applicable.
    - Example “Decision reference” for Notes:
      - Decision: [2025-10-12: Switch to Service Account Auth](docs/specs/decisions_spec.md#2025-10-12-switch-to-service-account-auth) — requires sharing Sheet/Doc with the service account; update CI secrets.

## Version Scope Hierarchy
- **Major Version Number**: Major paradigm change, next-level feature set, breaking changes, 0 to 99.
- **Minor Version Number**: New features, important bug fixes, non-breaking changes, 0 to 99.
- **Patch Version Number**: Incremental features/improvements, small bug fixes (all non-breaking), 0 to 99.
- **Mini Version Letter**: Use `a`, `b`, `c`, … when there is a bugfix/error follow-up that has no impact on the user (test cases, CI/CD, etc.). Example: `v0.0.2a`.

### <Version_Number> Pattern
- **v0.0.0 to v0.9.99z**: `v0.<major>.<minor><tiny>`. Examples: `v0.0.2`, `v0.0.2a`, `v0.1.14`, `v0.15.4`, etc.
- **v1.0.0+**: `v<major>.<minor>.<patch><tiny>`. Examples: `v1.1.9`, `v1.1.9a`, `v2.13.0`, `v11.4.19`, etc.

### Hello World
The first version in a project is the "Hello World" and is numbered v0.0.0. The "Hello World" is an end-to-end stack prototype with a "Hello" message or demo output for the first commit. Optionally, there can be "Hello Feature" or "Hello Framework" (etc.) versions after v0.0.0 when a key dependency is added. 

## Dependency Management
- See `docs/guides/dependencies_guide.md` for authoritative guidance (apps vs libs, `requirements.in` → compiled `requirements.txt`, update workflow, and safeguards).

## LLM Commands Policy
- OK: 
  - `pip install {package}` (one package at a time), `pytest`, invoking program entry points (e.g., `python -m merge_docs.cli`).
  - volatile testing file creation and deletion in the /tmp directory (clean up after)
- Not OK: 
  - destructive commands like `rm`, `mv` (except in the /tmp directory). Ask the human first for file deletes/renames 
- Prefer `git mv` instead of `mv` for files tracked in the Git repository.

## Testing Requirements
**CRITICAL: All tests must pass locally before committing.**

### Before Every Commit
Run the full test suite locally to catch errors before CI/CD:
```bash
# Run all tests (unit + integration)
make test

# Or run specific test suites
make test-unit          # Bats unit tests only
make test-integration   # pytest integration tests only
```

### What Tests Should Catch Locally
- ✅ Missing imports (`import os`, etc.)
- ✅ Syntax errors
- ✅ Undefined variables/functions
- ✅ Calling non-existent methods
- ✅ Basic logic errors
- ✅ Test collection errors

### What CI/CD Should Catch
- Platform-specific issues (macOS vs Linux)
- Python version compatibility (3.10, 3.11, 3.12)
- Integration issues across environments
- Edge cases on different platforms

### Mini Versions (a, b, c, ...)
Use mini version letters for test/CI/CD fixes that have **no user-facing impact**:
- Test infrastructure fixes (missing imports, setup issues)
- CI/CD configuration fixes
- Test helper method additions
- Documentation-only changes in test files

**Example:** If v0.8.9 is implemented but tests fail in CI/CD due to missing imports, create v0.8.9a for the test fixes. The application version stays at 0.8.9.

## Implementation Flow (Typical)
1. Human or LLM adds/updates `docs/specs/versions_spec.md` with a version definition: number, title, requirements, and notes. 
2. Human requests implementation "Please implement v#.#.# in the @versions_spec.md file".
3. LLM implements code and tests per the targeted version.
4. **LLM runs tests locally** (`make test`) to verify implementation before committing.
5. LLM updates the version checklist, appends `[Implemented]` if complete, and adds `### Notes`.
6. LLM logs major decisions in `docs/specs/decisions_spec.md`, newest at the top; reference the entry in the version's `### Notes`.
7. **LLM commits and pushes only after local tests pass.**
8. If CI/CD reveals test failures, add a mini version (a, b, c) for fixes.
9. If follow-up feature fixes are requested, add a new patch version.
10. If a larger plan is ready, add a new `[Planned]` version for review before implementation.
