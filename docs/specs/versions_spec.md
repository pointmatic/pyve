# Pyve Version History
See `docs/guide_versions_spec.md`

---

## v0.7.0 Backend Detection Foundation [Planned]
- [ ] Create `lib/backend_detect.sh` library
- [ ] Implement file-based backend detection logic (environment.yml, conda-lock.yml, pyproject.toml, requirements.txt)
- [ ] Add backend detection functions: `detect_backend_from_files()`, `get_backend_priority()`
- [ ] Add `--backend` CLI flag (venv, micromamba, auto)
- [ ] Default to venv backend (maintain backward compatibility)
- [ ] Update `--config` to show detected backend
- [ ] Add unit tests for backend detection logic

### Notes
**Goal:** Establish backend detection infrastructure without breaking existing venv functionality.

**Backend Priority Resolution:**
1. CLI flag: `--backend` (highest priority)
2. `.pyve/config` file (future - v0.7.1)
3. File-based detection (environment.yml → micromamba, pyproject.toml → venv)
4. Default to venv (lowest priority)

**File Detection Rules:**
- `environment.yml` or `conda-lock.yml` present → micromamba backend
- `pyproject.toml` or `requirements.txt` present → venv backend
- Both present → warn and use explicit config or CLI flag
- None present → default to venv

**Testing Requirements:**
- Existing venv workflows continue to work unchanged
- `--backend venv` explicitly selects venv
- `--backend auto` detects from files (defaults to venv if none)
- `--backend micromamba` errors if environment.yml missing (v0.7.4+)

**Implementation Reference:**
- See `docs/specs/implementation_plan.md` for complete v0.7.x roadmap
- See `docs/specs/design_decisions.md` for architectural decisions
- See `docs/specs/micromamba.md` for requirements

---
