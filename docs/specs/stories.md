# stories.md — pyve

This document breaks the `pyve` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

---

## Phase G: UX Improvements
- add `pyve testenv run <command>` subcommand
- draft a `concept.md` file to capture the core ideas and value proposition
- integrate `project-guide` as a default tool (see `ux-improvements.md`)
- refactor pyve CLI to use subcommands instead of flags (see `ux-improvements.md`)
- landing page (usage.md) updates (see `ux-improvements.md`)

### Story G.a: v1.10.0 `pyve testenv run <command>` — Run Dev Tools in the Test Environment [Done]

Today `pyve testenv` can `--init`, `--install`, and `--purge` the dev/test runner environment (`.pyve/testenv/venv`), and `pyve test` executes `pytest` inside it. But there is no general-purpose way to run other dev tools (ruff, mypy, black, pre-commit, etc.) that are installed in the testenv.

Users must either invoke the hidden path directly (`.pyve/testenv/venv/bin/ruff check .`) or pollute the project venv with dev-only dependencies (`pyve run pip install ruff`). Neither is discoverable or consistent with Pyve's design.

**Motivation:** Dev/lint/type-check tools belong in the testenv, not the project venv. The testenv already survives `pyve --init --force` and `pyve --purge`, making it the right home for tools whose versions shouldn't drift with environment rebuilds. A `pyve testenv run` subcommand completes the lifecycle: install once, run anywhere, survive rebuilds.

**Command behavior**

```
pyve testenv run <command> [args...]
```

- Executes `<command>` inside `.pyve/testenv/venv` by prepending its `bin/` to PATH — same pattern as `pyve run` uses for the project venv.
- If the testenv doesn't exist, fail with: `ERROR: Dev/test runner environment not initialized. Run: pyve testenv --init`
- If `<command>` is found in `.pyve/testenv/venv/bin/`, exec it directly.
- Otherwise, export `VIRTUAL_ENV` and prepend `bin/` to PATH, then exec `<command>` (allows system commands that need the testenv's Python on PATH).
- Propagate the command's exit code.
- No arguments → error with usage hint.

**Examples**

```bash
pyve testenv --install -r requirements-dev.txt   # install ruff, mypy, etc.
pyve testenv run ruff check .                    # run ruff from testenv
pyve testenv run mypy src/                       # run mypy from testenv
pyve testenv run python -m pytest --co -q        # alternative to pyve test
```

**Implementation checklist**

- [x] Add `run` action to `testenv_command()` in `pyve.sh`
  - [x] Parse `run` as a new action; `break` to collect remaining args as the command
  - [x] Verify testenv exists (`.pyve/testenv/venv/bin/python`); error if missing
  - [x] If command binary exists in testenv `bin/`, exec it directly
  - [x] Otherwise, export `VIRTUAL_ENV` and prepend testenv `bin/` to PATH, then exec
  - [x] No command → error with usage
- [x] Update `pyve --help` output
  - [x] Usage line: `pyve testenv --init | --install [-r <req.txt>] | --purge | run <command> [args...]`
  - [x] Commands section: add `run` to the testenv description
  - [x] Examples: added `pyve testenv run ruff check .` and `pyve testenv run mypy src/`
- [x] Update `pyve testenv --help` output to document `run`
- [x] Update `docs/site/usage.md`: added `testenv` entries to command overview table and full `testenv` reference section

**Spec updates**

- [x] `docs/specs/features.md`: updated FR-11 to include `testenv run`
- [x] `docs/specs/tech-spec.md`: added `testenv --install`, `testenv --purge`, `testenv run` to Commands table

**Tests**

- [x] Integration test: `pyve testenv run` with no command → error with usage
- [x] Integration test: `pyve testenv run` before `--init` → error with init hint
- [x] Integration test: `pyve testenv run python --version` → succeeds, prints version
- [x] Integration test: `pyve testenv run` propagates non-zero exit code (exit 42)

- [x] Update CHANGELOG.md with v1.10.0 entry
- [x] Bump VERSION to 1.10.0

### Story G.b: v1.11.0 Actively support project-guides [Planned]

Publish the package under the new name `project-guide` on PyPI. This is the minimal change needed to secure the name. The old `project-guides` CLI command continues to work — no regressions for existing users.

- [ ] TBD


