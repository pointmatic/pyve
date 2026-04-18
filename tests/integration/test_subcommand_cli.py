# Copyright (c) 2025-2026 Pointmatic (https://www.pointmatic.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Integration tests for the v1.11.0 subcommand-style CLI surface (Story G.b.1).

Black-box invocation of every renamed subcommand against a temp project.
The bats unit test (tests/unit/test_cli_dispatch.bats) covers routing in
isolation via the PYVE_DISPATCH_TRACE hook; this file exercises the real
handlers end-to-end and the legacy-flag catch (Decision D3 — kept forever).
"""

import os
import pytest


class TestNewSubcommandRouting:
    """Each renamed subcommand executes its real handler."""

    @pytest.mark.venv
    def test_init_subcommand_creates_venv(self, pyve, project_builder):
        """`pyve init` (no flags) creates a venv project."""
        result = pyve.run("init", "--no-direnv", "--force")
        assert result.returncode == 0
        assert (pyve.cwd / ".venv").is_dir()
        assert (pyve.cwd / ".pyve" / "config").exists()

    @pytest.mark.venv
    def test_init_with_backend_flag(self, pyve, project_builder):
        """Modifier flags still attach to the renamed init subcommand."""
        result = pyve.run("init", "--backend", "venv", "--no-direnv", "--force")
        assert result.returncode == 0
        config = (pyve.cwd / ".pyve" / "config").read_text()
        assert "backend: venv" in config

    @pytest.mark.venv
    def test_purge_subcommand_removes_venv(self, pyve, project_builder):
        """`pyve purge` removes the .pyve directory and venv."""
        pyve.init(backend="venv")
        assert (pyve.cwd / ".pyve").exists()

        result = pyve.run("purge", input="y\n")
        assert result.returncode == 0
        assert not (pyve.cwd / ".pyve").exists()

    @pytest.mark.venv
    def test_purge_with_keep_testenv_flag(self, pyve, project_builder):
        """`pyve purge --keep-testenv` preserves the dev/test runner env."""
        pyve.init(backend="venv")
        pyve.run("testenv", "--init")
        assert (pyve.cwd / ".pyve" / "testenv").exists()

        result = pyve.run("purge", "--keep-testenv", input="y\n")
        assert result.returncode == 0
        assert (pyve.cwd / ".pyve" / "testenv").exists()

    @pytest.mark.venv
    def test_validate_subcommand_runs(self, pyve, project_builder):
        """`pyve validate` executes the validation report."""
        pyve.init(backend="venv")
        result = pyve.run("validate", check=False)
        # validate exits 0 on pass, 1 on errors, 2 on warnings — all acceptable
        # here; we only assert the dispatcher reached the handler.
        assert result.returncode in (0, 1, 2)
        combined = (result.stdout or "") + (result.stderr or "")
        assert "validation" in combined.lower() or "backend" in combined.lower()

    def test_validate_subcommand_no_project(self, pyve, test_project):
        """`pyve validate` on an uninitialized project reports a clean failure."""
        result = pyve.run("validate", check=False)
        assert result.returncode == 1
        combined = (result.stdout or "") + (result.stderr or "")
        assert "not configured" in combined or "missing" in combined.lower()

    def test_python_version_subcommand_sets_version(self, pyve, test_project):
        """`pyve python-version <ver>` writes a .python-version file."""
        result = pyve.run("python-version", "3.13.7", check=False)
        # The handler may succeed (writes .python-version) or fail if pyenv/asdf
        # are unavailable. Either way, the dispatcher must reach the handler —
        # an "unknown command" exit would mean dispatch broke.
        combined = (result.stdout or "") + (result.stderr or "")
        assert "Unknown command" not in combined


class TestSelfNamespace:
    """`pyve self` namespace dispatcher."""

    def test_self_with_no_arg_prints_namespace_help(self, pyve, test_project):
        """`pyve self` with no subcommand prints the self-namespace help only."""
        result = pyve.run("self", check=False)
        assert result.returncode == 0
        combined = (result.stdout or "") + (result.stderr or "")
        # Strict marker line — appears ONLY in the self-namespace help block.
        assert "Usage: pyve self <subcommand>" in combined
        assert "pyve self install" in combined
        assert "pyve self uninstall" in combined

    def test_self_unknown_subcommand_errors(self, pyve, test_project):
        """`pyve self bogus` exits non-zero with a clear error."""
        result = pyve.run("self", "bogus", check=False)
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "Unknown 'pyve self' subcommand" in combined or "bogus" in combined


class TestLegacyFlagCatch:
    """Decision D3: legacy flags print a precise migration error forever."""

    @pytest.mark.parametrize(
        "old_flag,expected_new",
        [
            ("--init", "pyve init"),
            ("--purge", "pyve purge"),
            ("--validate", "pyve validate"),
            ("--python-version", "pyve python-version"),
            ("--install", "pyve self install"),
            ("--uninstall", "pyve self uninstall"),
        ],
    )
    def test_legacy_flag_prints_migration_error(
        self, pyve, test_project, old_flag, expected_new
    ):
        """Each removed flag form prints the migration error and exits non-zero."""
        result = pyve.run(old_flag, check=False)
        assert result.returncode != 0, f"{old_flag} should exit non-zero"
        combined = (result.stdout or "") + (result.stderr or "")
        assert f"'pyve {old_flag}' is no longer supported" in combined
        assert expected_new in combined
        assert "pyve --help" in combined

    @pytest.mark.parametrize("short_alias", ["-i", "-p"])
    def test_short_aliases_no_longer_recognized(
        self, pyve, test_project, short_alias
    ):
        """Removed short flag aliases (-i, -p) exit non-zero."""
        result = pyve.run(short_alias, check=False)
        assert result.returncode != 0


class TestPerSubcommandHelp:
    """Story G.b.2 / FR-G4: every renamed subcommand responds to --help."""

    @pytest.mark.parametrize(
        "args,marker",
        [
            (["init", "--help"], "pyve init - Initialize"),
            (["init", "-h"], "pyve init - Initialize"),
            (["purge", "--help"], "pyve purge - Remove"),
            (["purge", "-h"], "pyve purge - Remove"),
            (["validate", "--help"], "pyve validate - Validate"),
            (["validate", "-h"], "pyve validate - Validate"),
            (["python-version", "--help"], "pyve python-version - Set Python version"),
            (["python-version", "-h"], "pyve python-version - Set Python version"),
            (["self", "--help"], "Usage: pyve self <subcommand>"),
            (["self", "-h"], "Usage: pyve self <subcommand>"),
            (["self", "install", "--help"], "pyve self install - Install pyve"),
            (["self", "install", "-h"], "pyve self install - Install pyve"),
            (["self", "uninstall", "--help"], "pyve self uninstall - Remove pyve"),
            (["self", "uninstall", "-h"], "pyve self uninstall - Remove pyve"),
        ],
    )
    def test_subcommand_help_prints_marker_and_exits_zero(
        self, pyve, test_project, args, marker
    ):
        """Each subcommand --help prints its strict marker and exits 0."""
        result = pyve.run(*args)
        assert result.returncode == 0, f"{' '.join(args)} should exit 0"
        combined = (result.stdout or "") + (result.stderr or "")
        assert marker in combined, (
            f"{' '.join(args)} output missing marker {marker!r}\n"
            f"Got:\n{combined}"
        )

    def test_init_help_does_not_create_venv(self, pyve, test_project):
        """`pyve init --help` must not invoke the real init handler."""
        result = pyve.run("init", "--help")
        assert result.returncode == 0
        assert not (pyve.cwd / ".venv").exists()
        assert not (pyve.cwd / ".pyve").exists()


class TestTopLevelHelpSections:
    """Story G.b.2 / FR-G4: pyve --help is grouped into four sections."""

    @pytest.mark.parametrize(
        "section_header",
        ["Environment:", "Execution:", "Diagnostics:", "Self management:"],
    )
    def test_top_level_help_contains_section_header(
        self, pyve, test_project, section_header
    ):
        result = pyve.run("--help")
        assert result.returncode == 0
        assert section_header in result.stdout, (
            f"Top-level --help missing section header {section_header!r}"
        )


class TestUniversalFlagsRegression:
    """Regression guard: --help / --version / --config still work."""

    def test_help_flag(self, pyve, test_project):
        result = pyve.run("--help")
        assert result.returncode == 0
        assert "pyve" in result.stdout

    def test_version_flag(self, pyve, test_project):
        result = pyve.run("--version")
        assert result.returncode == 0
        assert "pyve" in result.stdout.lower()

    def test_no_args_prints_help_and_exits_nonzero(self, pyve, test_project):
        result = pyve.run(check=False)
        assert result.returncode != 0
