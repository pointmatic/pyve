# Copyright (c) 2026 Pointmatic (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Integration tests for the interactive `pyve init` wizard (Story L.k.6).

The wizard's interactive (real-TTY) paths are not driven from these tests —
arrow-key prompts require a real PTY which subprocess.run can't supply (see
L.i / L.k.4 notes). Instead, these tests exercise:

  1. The flag-driven render path: `pyve init --backend venv ...` proceeds
     non-interactively and the wizard renders the flag-resolved backend.
  2. The auto-detect render path: `pyve init` in a directory containing
     `environment.yml` defaults the backend prompt to `micromamba` (the
     non-TTY/bypass branch is the closest faithful proxy for the
     "press enter on the suggested default" interactive case).
  3. The TTY guard path: `pyve init` with no flags AND `PYVE_INIT_NONINTERACTIVE`
     unset exits non-zero with an error pointing at `--backend`.

The PYVE_INIT_NONINTERACTIVE bypass is set to `1` by the bats / pytest test
harnesses by default (see tests/helpers/pyve_test_helpers.py); test 3 below
explicitly overrides it to exercise the guard path.
"""

import pytest


@pytest.mark.venv
class TestInitWizard:
    """End-to-end coverage of the L.k wizard's render paths via `pyve init`."""

    def test_wizard_with_backend_flag_renders_non_interactively(self, pyve, project_builder):
        """`pyve init --backend venv` proceeds without prompting; wizard renders the flag-resolved backend."""
        result = pyve.run(
            "init",
            "--backend", "venv",
            "--no-direnv",
            "--force",
            "--no-project-guide",
            check=False,
        )
        # The wizard's flag-driven render path must produce the canonical
        # "Backend: venv (--backend)" line.
        assert "Backend: venv (--backend)" in result.stdout, (
            f"Expected wizard backend render in stdout; got:\n{result.stdout!r}"
        )

    def test_wizard_environment_yml_defaults_to_micromamba(self, pyve, project_builder):
        """`pyve init` in a dir with environment.yml resolves the backend prompt to micromamba."""
        # Pre-populate environment.yml so the wizard's backend-default helper
        # picks micromamba. Don't pass --backend; the wizard's auto-detect path
        # (under PYVE_INIT_NONINTERACTIVE=1, which the test harness sets) is
        # the non-TTY proxy for the interactive "accept the default on enter"
        # case — same detection signal, same resolved value.
        (pyve.cwd / "environment.yml").write_text(
            "name: test\n"
            "channels:\n"
            "  - conda-forge\n"
            "dependencies:\n"
            "  - python=3.13\n"
            "  - pip\n"
        )
        result = pyve.run(
            "init",
            "--no-direnv",
            "--force",
            "--no-project-guide",
            check=False,
        )
        # Whether the downstream micromamba bootstrap succeeds is irrelevant —
        # the wizard runs first and must announce the auto-detected backend
        # before any backend-specific subprocess work begins.
        assert "Backend: micromamba (auto-detected)" in result.stdout, (
            f"Expected wizard auto-detect render in stdout; got:\n"
            f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
        )

    def test_wizard_tty_guard_fires_when_bypass_disabled_and_no_flags(self, pyve, monkeypatch):
        """`pyve init` (no flags, no bypass, non-TTY stdin) hard-fails with TTY guard error."""
        # The pytest harness sets PYVE_INIT_NONINTERACTIVE=1 by default; defeat
        # that here so the wizard's TTY guard surfaces. The subprocess inherits
        # this env var and PyveRunner's `setdefault` won't override it.
        monkeypatch.setenv("PYVE_INIT_NONINTERACTIVE", "0")
        result = pyve.run("init", check=False)
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        # Error message must surface both the TTY-guard reason and the flag
        # that would skip the most-load-bearing prompt (--backend), so users
        # can recover non-interactively.
        assert "stdin is not a TTY" in combined, (
            f"Expected TTY-guard reason; got:\nstdout={result.stdout!r}\nstderr={result.stderr!r}"
        )
        assert "--backend" in combined, (
            f"Expected --backend hint; got:\nstdout={result.stdout!r}\nstderr={result.stderr!r}"
        )
