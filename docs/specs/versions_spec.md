# Pyve Version History

## References
- Building Guide: `docs/guides/building_guide.md`
- Planning Guide: `docs/guides/planning_guide.md`
- Testing Guide: `docs/guides/testing_guide.md`
- Dependencies Guide: `docs/guides/dependencies_guide.md`
- Decision Log: `docs/specs/decisions_spec.md`
- Codebase Spec: `docs/specs/codebase_spec.md`

## v0.2.9 
This version will help facilitate collaborative, LLM-friendly, and industry-standard development practices in any codebase when the programmer uses Pyve. The templates directory contains meta documents that Pyve will use to initialize documentation stubs in local git repository. 
- [ ] Copy the generic guides into any project for any language(s).
- [ ] Copy blank spec docs so the repository is ready for collaborative development with LLMs. 
- [ ] In a new project, pyve.sh will copy files in the same structure in the templates directory as if it were root.
- [ ] Review all the templates directory documents to confirm the are generalized
  - [ ] No Python-specific language details (unless it's just an example, and except of course `/templates/docs/specs/lang/{lang}_spec.md`)
  - [ ] No project-specific details. 
  - [ ] Do not change the anchors or references, since when Pyve copies the files, they will have the correct anchors and references.

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
