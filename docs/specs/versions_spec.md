# Pyve Version History

## References
- Building Guide: `docs/guides/building_guide.md`
- Planning Guide: `docs/guides/planning_guide.md`
- Testing Guide: `docs/guides/testing_guide.md`
- Dependencies Guide: `docs/guides/dependencies_guide.md`
- Decision Log: `docs/specs/decisions_spec.md`
- Codebase Spec: `docs/specs/codebase_spec.md`

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
