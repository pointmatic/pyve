"""
pytest fixtures for Pyve integration tests.
"""

import pytest
from pathlib import Path
import sys

# Add helpers to path
helpers_path = Path(__file__).parent.parent / 'helpers'
sys.path.insert(0, str(helpers_path))

from pyve_test_helpers import PyveRunner, ProjectBuilder


@pytest.fixture
def pyve_script():
    """Path to pyve.sh script."""
    return Path(__file__).parent.parent.parent / "pyve.sh"


@pytest.fixture
def test_project(tmp_path):
    """Create a temporary test project directory."""
    project_dir = tmp_path / "test_project"
    project_dir.mkdir()
    return project_dir


@pytest.fixture
def pyve(pyve_script, test_project):
    """Pyve runner fixture."""
    return PyveRunner(pyve_script, test_project)


@pytest.fixture
def project_builder(test_project):
    """Project builder fixture."""
    return ProjectBuilder(test_project)


@pytest.fixture
def clean_env(monkeypatch):
    """Clean environment variables."""
    # Remove any pyve-related env vars
    import os
    for key in list(os.environ.keys()):
        if key.startswith('PYVE_'):
            monkeypatch.delenv(key, raising=False)
    return monkeypatch
