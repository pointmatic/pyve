# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Tests for test helpers (ProjectBuilder, PyveRunner) used by the bootstrap
integration tests. These certify the helper contracts relied on by
``tests/integration/test_bootstrap.py``.
"""

import subprocess
from pyve_test_helpers import PyveRunner


class TestInitMicromambaHelper:
    """ProjectBuilder.init_micromamba forwards bootstrap kwargs to pyve init."""

    def test_forwards_auto_bootstrap_flag(self, project_builder, monkeypatch):
        captured = {}

        def fake_run(self, *args, **kwargs):
            captured["args"] = list(args)
            return subprocess.CompletedProcess(args=list(args), returncode=0)

        monkeypatch.setattr(PyveRunner, "run", fake_run)

        project_builder.init_micromamba(auto_bootstrap=True)

        assert "--auto-bootstrap" in captured["args"]

    def test_forwards_bootstrap_to_value(self, project_builder, monkeypatch):
        captured = {}

        def fake_run(self, *args, **kwargs):
            captured["args"] = list(args)
            return subprocess.CompletedProcess(args=list(args), returncode=0)

        monkeypatch.setattr(PyveRunner, "run", fake_run)

        project_builder.init_micromamba(auto_bootstrap=True, bootstrap_to="project")

        args = captured["args"]
        idx = args.index("--bootstrap-to")
        assert args[idx + 1] == "project"


class TestCreateEnvironmentYml:
    """ProjectBuilder.create_environment_yml produces a valid environment file."""

    def test_default_structure(self, project_builder):
        env_path = project_builder.create_environment_yml(
            name="test-bootstrap-env",
            dependencies=["python=3.11", "pip"],
        )

        assert env_path.exists()
        content = env_path.read_text()
        assert "name: test-bootstrap-env" in content
        assert "channels:" in content
        assert "  - conda-forge" in content
        assert "dependencies:" in content
        assert "  - python=3.11" in content
        assert "  - pip" in content

    def test_custom_channels(self, project_builder):
        env_path = project_builder.create_environment_yml(
            name="custom-channels",
            channels=["conda-forge", "bioconda"],
            dependencies=["python=3.12"],
        )

        content = env_path.read_text()
        assert "  - conda-forge" in content
        assert "  - bioconda" in content
