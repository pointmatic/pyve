# UX Improvements - Pyve (Phase G)

## Pyve + project-guide
The `project-guide` CLI tool (https://pointmatic.github.io/project-guide/) has become central to all my development workflows. I want that to be more naturally integrated into Pyve (as a fundamental project setup tool). As `project-guide` is a fundamental precursor to doing any of my projects, it makes sense to have `project-guide` (optionally) prewired with every project. This increases the opinionated nature of Pyve, but we can mitigate that:
  - Default UI question in `pyve init`: "Install project-guide? (y/n) [y]"
  - `--project-guide` flag to install and skip the question
  - `--no-project-guide` flag to skip installation

## Pyve CLI Refactoring
Convert all flag-style commands to subcommands, keeping only the universal conventions (--help, --version, --config) as flags. The two self-management commands move under a self namespace.
  - `pyve --init` → `pyve init`
  - `pyve --purge` → `pyve purge`
  - `pyve --validate` → `pyve validate`
  - `pyve --python-version` → `pyve python-version`
  - `pyve --install` → `pyve self install`
  - `pyve --uninstall` → `pyve self uninstall`
  - `pyve lock` → unchanged
  - `pyve run` → unchanged
  - `pyve testenv` → unchanged
  - `pyve test` → unchanged
  - `pyve doctor` → unchanged
  - `pyve --help`, `--version`, `--config` → unchanged

## MkDocs `usage.md` Corrections
The website is significantly behind `--help`, which should be treated as the canonical source. Here are the specific gaps to fix:
  - `--python-version` description is wrong — says "Display Python version" but it sets it
  - `testenv` subcommand is missing entirely from the command reference
  - `--init` (now `init`) is missing several options: `--local-env`, `--auto-bootstrap`, `--bootstrap-to`, `--strict`, `--env-name`, `--no-direnv`, and the optional `<dir>` argument
  - `--purge` (now `purge`) is missing the optional `<dir>` argument and `--keep-testenv` flag
