# Copyright (c) 2026 Pointmatic (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Integration tests for the end-of-init "Next steps:" summary (Story L.l).

The bats unit test (tests/unit/test_init_next_steps.bats) covers the
helper's conditional branches in isolation. This file verifies the
summary appears at the end of a real `pyve init` run and that the
detection-driven items appear when their preconditions are met in a
fresh project.
"""

import pytest


@pytest.mark.venv
class TestInitNextSteps:
    """End-to-end coverage of the L.l Next-steps block."""

    def test_next_steps_block_renders_at_end_of_init(self, pyve, project_builder):
        """`pyve init` ends with a numbered 'Next steps' block."""
        result = pyve.init(backend="venv")
        assert result.returncode == 0
        # Section header is always rendered. The conditional items are
        # covered separately below — `pyve.init()` injects --no-direnv,
        # so the direnv-allow item won't appear in this test's stdout.
        assert "Next steps" in result.stdout

    def test_next_steps_skips_direnv_under_no_direnv(self, pyve, project_builder):
        """`pyve init --no-direnv` substitutes the pyve-run hint for direnv."""
        # Use pyve.run() (not pyve.init()) so the `timeout=300` kwarg is
        # treated as a subprocess timeout rather than a `--timeout` CLI
        # flag. Bumped to 300s to absorb cold-asdf-shim warmup.
        result = pyve.run(
            "init", "--no-direnv", "--force", "--backend", "venv", timeout=300
        )
        assert result.returncode == 0
        assert "pyve run <command>" in result.stdout
        # direnv-allow should not appear under --no-direnv.
        assert "direnv allow" not in result.stdout

    def test_next_steps_includes_testenv_install_when_requirements_dev_exists(
        self, pyve, project_builder
    ):
        """`requirements-dev.txt` in the project → testenv install hint shows up."""
        (pyve.cwd / "requirements-dev.txt").write_text("pytest\n")
        result = pyve.init(backend="venv")
        assert result.returncode == 0
        assert "pyve testenv install -r requirements-dev.txt" in result.stdout

    def test_next_steps_omits_testenv_install_when_no_requirements_dev(
        self, pyve, project_builder
    ):
        """No `requirements-dev.txt` → testenv install hint is omitted."""
        result = pyve.init(backend="venv")
        assert result.returncode == 0
        assert "requirements-dev.txt" not in result.stdout
